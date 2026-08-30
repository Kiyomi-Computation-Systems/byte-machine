;;; The reference interpreter runs the verified one-byte machine over all 256
;;; byte values through the runtime parser API.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test eof-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine private conditions))

(harness-begin "unit.interpret")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node
           'start
           (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
           (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define cm (make-interpreted-machine (verify-machine one-byte)))
(define (run b)
  (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1))

(harness-group "interpreter refuses an unverified machine"
  (lambda ()
    (harness-case "a failed verification is rejected"
      (lambda ()
        (check-raises "refused"
                      byte-machine-contract-condition?
                      (lambda ()
                        (make-interpreted-machine
                         (verify-machine
                          (make-machine 'one-byte 'nowhere '() '() '() (list eof-decl rej-decl)
                                        (list (make-stop-node 'stop #f)) 'default-eof #f)))))))))

(harness-group "EOF execution through the interpreter"
  (lambda ()
    (define (fresh) (make-parser (make-interpreted-machine (verify-machine (make-eof-machine))) '() #f))
    (harness-case "finish with no input is idle completion -> finished"
      (lambda ()
        (let ((r (parser-finish! (fresh))))
          (check-equal "finished" (parser-result-status r) 'finished))))
    (harness-case "finish after one byte is truncation -> error with the code"
      (lambda ()
        (let ((p (fresh)))
          (parser-feed! p (make-bytevector 1 1) 0 1)              ; at s1, offset 1
          (let ((r (parser-finish! p)))
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "truncation code" (parser-result-error r) 'truncated-input)
            (check-equal "eof at offset 1" (parser-result-stream-offset r) 1)))))
    (harness-case "feeding both bytes stops; finishing a stopped parser stays stopped (§12.2)"
      (lambda ()
        (let ((p (fresh)))
          (parser-feed! p (make-bytevector 2 0) 0 0)              ; empty feed, still ready
          (parser-feed! p (let ((v (make-bytevector 2))) (bytevector-u8-set! v 0 1)
                            (bytevector-u8-set! v 1 2) v) 0 2)    ; -> stopped
          (check-equal "stopped" (parser-lifecycle p) 'stopped)
          (check-equal "finish after stop stays stopped" (parser-result-status (parser-finish! p)) 'stopped))))
    (harness-case "finishing a finished parser stays finished; lifecycle tracks it"
      (lambda ()
        (let ((p (fresh)))
          (parser-finish! p)
          (check-equal "lifecycle finished" (parser-lifecycle p) 'finished)
          (check-equal "again finished" (parser-result-status (parser-finish! p)) 'finished))))
    (harness-case "a dispatch with eof-target #f routes EOF to the default-eof error"
      (lambda ()
        (let ((p (make-parser
                  (make-interpreted-machine
                   (verify-machine
                    (make-machine 'dm 's0 '() '() '()
                      (list (make-error-declaration 'default-eof 'eof "eof" #f))
                      (list (make-byte-dispatch-node 's0
                              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                              (make-edge 'stop 'reexecute) #f #f)   ; eof-target #f -> default
                            (make-stop-node 'stop #f))
                      'default-eof #f)))
                  '() #f)))
          (let ((r (parser-finish! p)))
            (check-equal "default-eof error" (parser-result-status r) 'error)
            (check-equal "default-eof code" (parser-result-error r) 'eof)))))))

(harness-group "all 256 byte values"
  (lambda ()
    (harness-case "byte 0 is accepted and stops after one byte"
      (lambda ()
        (let ((r (run 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1))))
    (harness-case "every other byte is rejected at position 0 with the error code"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 1))
            (when (< b 256)
              (let ((r (run b)))
                (when (or (not (eq? (parser-result-status r) 'error))
                          (not (= (parser-result-stream-offset r) 0))
                          (not (eq? (parser-result-error r) 'unexpected-byte)))
                  (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte in 1..255 misbehaved" bad 'none))))))

;; Milestone 3 Slice ② Task 3 (decision 0015 points 3-5). Prefix progress lives
;; in the parser's own `current` as (name . path), where path is the byte list
;; consumed so far inside the sequence -- NOT a bare position index. Design
;; §4.2's (s . k) is insufficient: see the AB/XY case below.
(define (seq-alt* bytes target) (make-sequence-case bytes target #f))
(define (seq-m name alts mode extra)
  (make-machine name 'seq '() '() '() (list eof-decl rej-decl)
    (append (list (make-sequence-dispatch-node
                   'seq (map (lambda (a) (seq-alt* (car a) (cdr a))) alts)
                   (make-edge 'reject mode) #f #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            extra)
    'default-eof #f))
(define (feed-bytes cm bs)
  (let ((p (make-parser cm '() #f)))
    (let loop ((l bs) (r #f))
      (if (null? l) r
          (loop (cdr l)
                (let ((x (parser-feed! p (make-bytevector 1 (car l)) 0 1)))
                  (list (parser-result-status x) (parser-result-next x)
                        (parser-result-consumed x) (parser-result-stream-offset x)
                        (parser-result-error x))))))))
(define (interp m) (make-interpreted-machine (verify-machine m)))

(harness-group "sequence prefix tracking through the interpreter"
  (lambda ()
    (define one (interp (seq-m 'one '(((1 2 3 4) . stop)) 'reexecute '())))
    (harness-case "the full sequence stops after four bytes"
      (lambda ()
        (check-equal "stopped" (feed-bytes one '(1 2 3 4)) '(stopped 1 1 4 #f))))
    (harness-case "a mid-sequence feed boundary is need-input, never paused (decision 0015 point 5)"
      (lambda ()
        (check-equal "need-input" (car (feed-bytes one '(1 2))) 'need-input)))
    (harness-case "a wrong byte at each position errors at that between-byte offset"
      (lambda ()
        (check-equal "pos 0" (feed-bytes one '(200)) '(error 0 0 0 unexpected-byte))
        (check-equal "pos 1" (feed-bytes one '(1 200)) '(error 0 0 1 unexpected-byte))
        (check-equal "pos 2" (feed-bytes one '(1 2 200)) '(error 0 0 2 unexpected-byte))
        (check-equal "pos 3" (feed-bytes one '(1 2 3 200)) '(error 0 0 3 unexpected-byte))))))

(harness-group "the compound current is a PATH, not a position index (§0 D1)"
  (lambda ()
    ;; AB and XY diverge at position 0. After consuming A, a position index would
    ;; find that SOME alternative has Y at position 1 and follow XY -- accepting a
    ;; sequence that was never on the input. This case is what makes the
    ;; representation observable.
    (define d (interp (seq-m 'diverge '(((65 66) . stop) ((88 89) . halt))
                             'reexecute (list (make-stop-node 'halt #f)))))
    (harness-case "A then Y mismatches rather than following the XY alternative"
      (lambda ()
        (check-equal "mismatch" (car (feed-bytes d '(65 89))) 'error)
        (check-equal "at offset 1" (cadddr (feed-bytes d '(65 89))) 1)))
    (harness-case "each alternative still accepts on its own bytes"
      (lambda ()
        (check-equal "AB" (car (feed-bytes d '(65 66))) 'stopped)
        (check-equal "XY" (car (feed-bytes d '(88 89))) 'stopped)))
    (harness-case "alternatives sharing a first byte both remain live through it"
      (lambda ()
        (let ((s (interp (seq-m 'shared '(((65 66) . stop) ((65 67) . halt))
                                'reexecute (list (make-stop-node 'halt #f))))))
          (check-equal "AB" (car (feed-bytes s '(65 66))) 'stopped)
          (check-equal "AC" (car (feed-bytes s '(65 67))) 'stopped)
          (check-equal "AD mismatches" (car (feed-bytes s '(65 68))) 'error))))))

;; house convention (conditions.sls header, and normal-ir-tests.sps's own
;; raises-normalize-assertion? helper): tests compare the condition's
;; structured fields, never rendered text. seq-step's two guards raise a plain
;; R6RS assertion violation (not the byte-machine contract condition), so the
;; predicate asserts assertion-violation?, that `who` is interpret's own name,
;; and which of the two messages it carries -- (lambda (e) #t) would pass on
;; ANY raise, including one from the two messages swapped between the guards.
(define (raises-interpret-assertion? message)
  (lambda (e)
    (and (assertion-violation? e)
         (eq? (condition-who e) 'interpret)
         (equal? (condition-message e) message))))

(harness-group "the interpreter carries the same two internal guards as the normalizer"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (raises-interpret-assertion? "ambiguous terminal prefix")
                      (lambda ()
                        (feed-bytes (interp (seq-m 'amb '(((65 66) . stop) ((65 66 67) . halt))
                                                   'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (raises-interpret-assertion? "duplicate sequence alternative")
                      (lambda ()
                        (feed-bytes (interp (seq-m 'dup '(((65 66) . stop) ((65 66) . halt))
                                                   'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))))

(harness-group "advance-mode mismatch shifts every reported position by one (§11.5:664)"
  (lambda ()
    (define adv (interp (seq-m 'adv '(((1 2 3 4) . stop)) 'advance '())))
    (harness-case "the offending byte is consumed and the offset advances past it"
      (lambda ()
        (check-equal "pos 0" (feed-bytes adv '(200)) '(error 1 1 1 unexpected-byte))
        (check-equal "pos 1" (feed-bytes adv '(1 200)) '(error 1 1 2 unexpected-byte))
        (check-equal "pos 2" (feed-bytes adv '(1 2 200)) '(error 1 1 3 unexpected-byte))
        (check-equal "pos 3" (feed-bytes adv '(1 2 3 200)) '(error 1 1 4 unexpected-byte))))))

;; Task 3 coverage gap closed here, not in the brief's own Step 1 block: none of
;; the fixtures above ever calls parser-finish! while `current` is a compound, so
;; eof-target-of's (car cur) extraction has no witness even though it is a value
;; the code produces (interpret.sls's own comment says a compound answers with
;; ITS SOURCE NODE'S eof-target). Mirrors (byte-machine test eof-machine)'s
;; s1 -> 'trunc pattern: the sequence node's eof-target names an error node
;; directly, reusing the SAME 'reject node the mismatch edge already uses, so no
;; new error declaration is needed and the machine stays well-formed by the same
;; shape verify-tests.sps's arm-4 fixture already establishes as legal.
(harness-group "EOF through a compound current reads the sequence node's own eof-target (§12.4:727)"
  (lambda ()
    (define eofseq
      (interp (make-machine 'eofseq 'seq '() '() '() (list eof-decl rej-decl)
                (list (make-sequence-dispatch-node
                       'seq (list (seq-alt* '(1 2 3 4) 'stop))
                       (make-edge 'reject 'reexecute) 'reject #f)
                      (make-stop-node 'stop #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f)))
    (harness-case "EOF mid-sequence routes through the sequence node's own eof-target, not the machine default"
      (lambda ()
        (let ((p (make-parser eofseq '() #f)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (let ((r (parser-finish! p)))
            (check-equal "status" (parser-result-status r) 'error)
            (check-equal "the sequence node's own eof-target code, not default-eof"
                         (parser-result-error r) 'unexpected-byte)))))))

(harness-finish)
