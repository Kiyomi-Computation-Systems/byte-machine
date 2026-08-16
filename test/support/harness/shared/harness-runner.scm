;;; byte-machine private portable test runner.
;;;
;;; PORTABILITY CONTRACT
;;;
;;; This file is included verbatim by both the R6RS and the R7RS wrapper. It may
;;; use only identifiers common to both standards, and must never name Chez or
;;; Gambit. Everything a runtime does differently arrives through the adapter
;;; protocol, documented in
;;; docs/plans/milestone-0-slice-2-test-harness.md section 6.
;;;
;;; Notable exclusions, each of which differs between the two standards:
;;; define-record-type, string ports, error, condition accessors, hash tables,
;;; and sorting. Records are plain lists behind accessors for the same reason.
;;;
;;; PROCESS STATUS (spec section 5.2)
;;;
;;;   0  every selected case passed
;;;   1  one or more assertions failed
;;;   2  harness, configuration, or registration error
;;;   3  reserved: the run could not confirm it executed the intended text
;;;
;;; Status is computed once, at the end, rather than chosen at each throw site,
;;; so a new error path cannot forget to change it.

(define harness-status-pass 0)
(define harness-status-failed 1)
(define harness-status-harness-error 2)
(define harness-status-provenance 3)

;; ---------------------------------------------------------------------------
;; Pure helpers
;; ---------------------------------------------------------------------------

(define (harness-join parts separator)
  (if (null? parts)
      ""
      (let loop ((rest (cdr parts)) (acc (car parts)))
        (if (null? rest)
            acc
            (loop (cdr rest) (string-append acc separator (car rest)))))))

(define (harness-string-contains? haystack needle)
  (let ((hn (string-length haystack))
        (nn (string-length needle)))
    (let outer ((start 0))
      (cond ((> (+ start nn) hn) #f)
            ((let inner ((i 0))
               (cond ((= i nn) #t)
                     ((char=? (string-ref haystack (+ start i))
                              (string-ref needle i))
                      (inner (+ i 1)))
                     (else #f)))
             #t)
            (else (outer (+ start 1)))))))

;; A trailing separator yields a trailing empty field, deliberately: dropping it
;; would make "a." and "a" split alike, and a filter written against the
;; difference would silently stop distinguishing them.
(define (harness-split text separator)
  (let ((n (string-length text)))
    (let loop ((i 0) (start 0) (acc '()))
      (cond ((= i n) (reverse (cons (substring text start n) acc)))
            ((char=? (string-ref text i) separator)
             (loop (+ i 1) (+ i 1) (cons (substring text start i) acc)))
            (else (loop (+ i 1) start acc))))))

(define (harness-take lst count)
  (if (or (= count 0) (null? lst))
      '()
      (cons (car lst) (harness-take (cdr lst) (- count 1)))))

(define (harness-member? x lst)
  (cond ((null? lst) #f)
        ((equal? x (car lst)) #t)
        (else (harness-member? x (cdr lst)))))

;; Exported so the bootstrap can observe a deliberate failure and undo it
;; without depending on harness-probe, which is itself one of the things the
;; bootstrap exists to check.
(define (harness-counters)
  (list harness-failure-count harness-check-count))

(define (harness-restore-counters! saved)
  (set! harness-failure-count (car saved))
  (set! harness-check-count (car (cdr saved)))
  (set! harness-current-case-failed #f))

;; ---------------------------------------------------------------------------
;; Mutable result state (the imperative shell of the runner)
;; ---------------------------------------------------------------------------

(define harness-suite-name "(none)")
(define harness-group-stack '())
(define harness-case-ids '())
(define harness-current-case #f)
(define harness-current-case-failed #f)
(define harness-case-count 0)
(define harness-failed-case-count 0)
(define harness-check-count 0)
(define harness-failure-count 0)
(define harness-error-count 0)
(define harness-skipped-count 0)
(define harness-cleanup-failure-count 0)
(define harness-failures '())
(define harness-filter #f)
(define harness-verbose #f)
(define harness-probe-depth 0)

(define (harness-quiet?) (> harness-probe-depth 0))

;; Flushed per line rather than at the summary. Standard output is block
;; buffered when it is not a terminal, so a process killed by a supervisor loses
;; everything it had written -- and the run whose output matters most is the one
;; that was killed before it could finish.
(define (harness-say line)
  (if (not (harness-quiet?))
      (begin (display line) (newline) (adapter-flush-output))))

(define (harness-say-always line)
  (display line) (newline) (adapter-flush-output))

;; ---------------------------------------------------------------------------
;; Failure and error recording
;; ---------------------------------------------------------------------------

;; Emitted per failure rather than once per run, because a log is usually read
;; at the failure rather than from the top. The id and the artifact path are
;; quoted because a case name and a filesystem path may both contain spaces,
;; which would otherwise make a key=value line ambiguous to parse.
(define (harness-failure-context id)
  (string-append
   "byte-machine-harness: FAIL-CONTEXT id=\"" id "\""
   " test=" (let ((t (adapter-environment-variable "BYTE_MACHINE_TEST_NAME")))
              (if t t "(unregistered)"))
   " backend=" (adapter-runtime-name)
   " mode=" (adapter-execution-mode)
   " os=" (adapter-os)
   " architecture=" (adapter-architecture)
   " runtime-version=" (adapter-runtime-version)
   " machine-type=" (adapter-machine-type)
   " artifacts=\"" (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
                     (if d d "(none)"))
   "\""))

(define (harness-record-failure! what detail)
  (set! harness-failure-count (+ harness-failure-count 1))
  (set! harness-current-case-failed #t)
  (let ((id (if harness-current-case harness-current-case "(no case)")))
    (set! harness-failures (cons (list id what detail) harness-failures))
    (harness-say (string-append "byte-machine-harness: FAIL " id ": " what
                                (if (string=? detail "")
                                    ""
                                    (string-append " -- " detail))))
    (harness-say (harness-failure-context id))))

(define (harness-record-error! detail)
  (set! harness-error-count (+ harness-error-count 1))
  (harness-say (string-append "byte-machine-harness: HARNESS-ERROR " detail)))

;; ---------------------------------------------------------------------------
;; Assertions
;; ---------------------------------------------------------------------------

(define (harness-count-check!)
  (set! harness-check-count (+ harness-check-count 1)))

(define (check what value)
  (harness-count-check!)
  (if value
      #t
      (begin (harness-record-failure! what "expected a true value") #f)))

;; ---------------------------------------------------------------------------
;; Groups and cases
;; ---------------------------------------------------------------------------

(define (harness-current-prefix)
  (if (null? harness-group-stack)
      ""
      (string-append (harness-join (reverse harness-group-stack) ".") ".")))

(define (harness-group name thunk)
  (set! harness-group-stack (cons name harness-group-stack))
  (let ((outcome (guard (e (#t (list 'raised e)))
                   (list 'value (thunk)))))
    (set! harness-group-stack (cdr harness-group-stack))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))
        (car (cdr outcome)))))

;; A raise inside a case is that case's failure, not the suite's death.
;; Otherwise the first broken case hides every case after it, and the log names
;; one defect where there may be five.
(define (harness-case name thunk)
  (let ((id (string-append (harness-current-prefix) name)))
    (cond
      ;; A duplicate id means one registration silently became unreachable:
      ;; coverage lost with no signal at all. That is a defect in the suite, not
      ;; a failing assertion, so it is an error and not a failure.
      ((harness-member? id harness-case-ids)
       (harness-record-error! (string-append "duplicate case id " id)))
      (else
       (set! harness-case-ids (cons id harness-case-ids))
       (set! harness-case-count (+ harness-case-count 1))
       (set! harness-current-case id)
       (set! harness-current-case-failed #f)
       (let ((outcome (guard (e (#t (list 'raised e)))
                        (list 'value (thunk)))))
         (if (eq? (car outcome) 'raised)
             (harness-record-failure!
              "case raised"
              (adapter-describe-condition (car (cdr outcome))))))
       (if harness-current-case-failed
           (set! harness-failed-case-count (+ harness-failed-case-count 1))
           (if harness-verbose
               (harness-say (string-append "byte-machine-harness: pass " id))))
       (set! harness-current-case #f)))))

;; ---------------------------------------------------------------------------
;; Suite lifecycle
;; ---------------------------------------------------------------------------

(define (harness-clear-state!)
  (set! harness-group-stack '())
  (set! harness-case-ids '())
  (set! harness-current-case #f)
  (set! harness-current-case-failed #f)
  (set! harness-case-count 0)
  (set! harness-failed-case-count 0)
  (set! harness-check-count 0)
  (set! harness-failure-count 0)
  (set! harness-error-count 0)
  (set! harness-skipped-count 0)
  (set! harness-cleanup-failure-count 0)
  (set! harness-failures '())
  (set! harness-filter #f))

(define (harness-banner)
  (harness-say-always
   (string-append "byte-machine-harness: suite=" harness-suite-name))
  (harness-say-always
   (string-append "byte-machine-harness: runtime=" (adapter-runtime-name)
                  " version=" (adapter-runtime-version)
                  " machine=" (adapter-machine-type)
                  " mode=" (adapter-execution-mode)
                  " os=" (adapter-os)
                  " architecture=" (adapter-architecture))))

(define (harness-begin suite-name)
  (set! harness-suite-name suite-name)
  (harness-clear-state!)
  ;; An empty value means unset, matching adapter-execution-mode: the same
  ;; variable emptied by a shell (BYTE_MACHINE_TEST_VERBOSE=) must not mean
  ;; opposite things in the same harness.
  (let ((v (adapter-environment-variable "BYTE_MACHINE_TEST_VERBOSE")))
    (set! harness-verbose (if (and v (not (string=? v ""))) #t #f)))
  (harness-banner))

(define (harness-exit-status)
  (cond ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)
        (else harness-status-pass)))

(define (harness-summary)
  (let ((status (harness-exit-status)))
    (harness-say-always
     (string-append
      "byte-machine-harness: summary suite=" harness-suite-name
      " runtime=" (adapter-runtime-name)
      " mode=" (adapter-execution-mode)
      " cases=" (number->string harness-case-count)
      " failed-cases=" (number->string harness-failed-case-count)
      " checks=" (number->string harness-check-count)
      " failures=" (number->string harness-failure-count)
      " cleanup-failures=" (number->string harness-cleanup-failure-count)
      " skipped=" (number->string harness-skipped-count)
      " errors=" (number->string harness-error-count)
      " status=" (number->string status)))
    (adapter-flush-output)
    status))

;; Print the summary and exit with the status it reports.
(define (harness-finish)
  (adapter-exit (harness-summary)))
