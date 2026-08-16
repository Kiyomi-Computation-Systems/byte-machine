;;; Bootstrap verification of the runner's primitives.
;;;
;;; PORTABILITY: a shared body, included verbatim by each runtime's thin
;;; wrapper. Common R6RS/R7RS subset only.
;;;
;;; The runner cannot be the only witness to its own correctness, so this
;;; program judges it with raw conditionals and its own counter. It uses no
;;; assertion, case, group, or summary facility from the runner; it calls the
;;; primitives under test and inspects what they return. It answers "does check
;;; actually check?" without using check to ask.
;;;
;;; It exits 1 on any failure and 0 otherwise, by hand, because harness-finish
;;; is one of the things it is not allowed to trust.

(define bootstrap-failures 0)

(define (bootstrap-assert name value)
  (if value
      (begin (display "bootstrap: ok   ") (display name) (newline))
      (begin
        (set! bootstrap-failures (+ bootstrap-failures 1))
        (display "bootstrap: FAIL ") (display name) (newline))))

;; --- pure helpers ----------------------------------------------------------

(bootstrap-assert "contains: middle" (harness-string-contains? "abcdef" "cd"))
(bootstrap-assert "contains: prefix" (harness-string-contains? "abcdef" "abc"))
(bootstrap-assert "contains: suffix" (harness-string-contains? "abcdef" "def"))
(bootstrap-assert "contains: absent" (not (harness-string-contains? "abcdef" "z")))
(bootstrap-assert "contains: empty needle" (harness-string-contains? "abc" ""))
(bootstrap-assert "contains: needle longer than haystack"
                  (not (harness-string-contains? "ab" "abc")))

(bootstrap-assert "join: several" (string=? (harness-join '("a" "b" "c") ".") "a.b.c"))
(bootstrap-assert "join: one" (string=? (harness-join '("x") ".") "x"))
(bootstrap-assert "join: none" (string=? (harness-join '() ".") ""))

(bootstrap-assert "split: several"
                  (equal? (harness-split "a.b.c" #\.) '("a" "b" "c")))
(bootstrap-assert "split: no separator"
                  (equal? (harness-split "abc" #\.) '("abc")))
(bootstrap-assert "split: trailing separator keeps the empty field"
                  (equal? (harness-split "a." #\.) '("a" "")))

(bootstrap-assert "take: fewer than available"
                  (equal? (harness-take '(1 2 3 4) 2) '(1 2)))
(bootstrap-assert "take: all" (equal? (harness-take '(1 2) 2) '(1 2)))
(bootstrap-assert "take: none" (equal? (harness-take '(1 2) 0) '()))
(bootstrap-assert "take: more than available"
                  (equal? (harness-take '(1 2) 5) '(1 2)))

(bootstrap-assert "member: present" (harness-member? "b" '("a" "b")))
(bootstrap-assert "member: absent" (not (harness-member? "z" '("a" "b"))))
(bootstrap-assert "member: empty" (not (harness-member? "a" '())))

;; --- the assertion primitive ------------------------------------------------
;;
;; The point of this file. A `check` that always returned a true value would
;; make every test in every later milestone pass, and no test written with
;; `check` could notice.

(bootstrap-assert "check: a true value returns true" (eq? (check "true" #t) #t))
(bootstrap-assert "check: a non-#f value returns true" (eq? (check "zero" 0) #t))

;; A deliberately failing check must be observed without it counting against
;; anything. harness-probe would do this, but the probe is itself part of what
;; the bootstrap is not allowed to trust, so the counters are saved and restored
;; by hand. What is asserted is the return value, nothing the runner counted.
(bootstrap-assert "check: a false value returns false"
                  (let* ((saved (harness-counters))
                         (result (check "deliberate" #f)))
                    (harness-restore-counters! saved)
                    (eq? result #f)))

;; --- adapter protocol -------------------------------------------------------
;;
;; Every adapter procedure is called, so a name missing from one runtime's
;; export list is a load failure on that runtime rather than a silent gap.

(bootstrap-assert "adapter: runtime name is one of the two"
                  (or (string=? (adapter-runtime-name) "chez")
                      (string=? (adapter-runtime-name) "gambit")))
(bootstrap-assert "adapter: version is non-empty"
                  (> (string-length (adapter-runtime-version)) 0))
(bootstrap-assert "adapter: machine type is non-empty"
                  (> (string-length (adapter-machine-type)) 0))
(bootstrap-assert "adapter: os is known"
                  (not (string=? (adapter-os) "unknown")))
(bootstrap-assert "adapter: architecture is known"
                  (not (string=? (adapter-architecture) "unknown")))
(bootstrap-assert "adapter: execution mode is declared by the launcher"
                  (string=? (adapter-execution-mode) "source"))
(bootstrap-assert "adapter: an unset variable reads as false"
                  (not (adapter-environment-variable "BYTE_MACHINE_NOT_SET_ANYWHERE")))
(bootstrap-assert "adapter: value->string writes readably"
                  (string=? (adapter-value->string (list 1 2)) "(1 2)"))
(bootstrap-assert "adapter: a condition describes as a non-empty single line"
                  (let ((text (adapter-describe-condition
                               (guard (e (#t e)) (car '())))))
                    (and (> (string-length text) 0)
                         (not (harness-string-contains? text "\n")))))
(bootstrap-assert "adapter: r5rs arithmetic is reachable"
                  (and (= (quotient 7 2) 3)
                       (= (remainder 7 2) 1)
                       (= (modulo -7 2) 1)))

(adapter-flush-output)

(display "bootstrap: failures=")
(display bootstrap-failures)
(newline)

(adapter-exit (if (= bootstrap-failures 0) 0 1))
