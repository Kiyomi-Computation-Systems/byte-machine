;;; The reference interpreter runs the verified one-byte machine over all 256
;;; byte values through the runtime parser API.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test eof-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine private conditions)
        (only (byte-machine private ir) make-verification-result)
        (only (chezscheme) greatest-fixnum))

(harness-begin "unit.interpret")

;; The error slot holds a parser-error record, and is #f on every non-error
;; result. These are single-executor lanes, so they compare the CODE rather
;; than the error projection the differential lanes use --
;; but they must stay #f-tolerant, because the same accessor is read on results
;; that carry no error at all.
(define (error-code-of r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e) (parser-error-code e))))

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
            (check-equal "truncation code" (error-code-of r) 'truncated-input)
            (check-equal "eof at offset 1" (parser-result-stream-offset r) 1)))))
    (harness-case "feeding both bytes stops; finishing a stopped parser stays stopped"
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
            (check-equal "default-eof code" (error-code-of r) 'eof)))))))

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
                          (not (eq? (error-code-of r) 'unexpected-byte)))
                  (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte in 1..255 misbehaved" bad 'none))))))

;; Prefix progress lives in the parser's own `current` as (name . path), where
;; path is the byte list consumed so far inside the sequence -- NOT a bare
;; position index. A (node . position) pair is insufficient: see the AB/XY case
;; below.
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
                        (error-code-of x))))))))
(define (interp m) (make-interpreted-machine (verify-machine m)))

(harness-group "sequence prefix tracking through the interpreter"
  (lambda ()
    (define one (interp (seq-m 'one '(((1 2 3 4) . stop)) 'reexecute '())))
    (harness-case "the full sequence stops after four bytes"
      (lambda ()
        (check-equal "stopped" (feed-bytes one '(1 2 3 4)) '(stopped 1 1 4 #f))))
    (harness-case "a mid-sequence feed boundary is need-input, never paused"
      (lambda ()
        (check-equal "need-input" (car (feed-bytes one '(1 2))) 'need-input)))
    (harness-case "a wrong byte at each position errors at that between-byte offset"
      (lambda ()
        (check-equal "pos 0" (feed-bytes one '(200)) '(error 0 0 0 unexpected-byte))
        (check-equal "pos 1" (feed-bytes one '(1 200)) '(error 0 0 1 unexpected-byte))
        (check-equal "pos 2" (feed-bytes one '(1 2 200)) '(error 0 0 2 unexpected-byte))
        (check-equal "pos 3" (feed-bytes one '(1 2 3 200)) '(error 0 0 3 unexpected-byte))))))

(harness-group "the compound current is a PATH, not a position index"
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

;; verify-machine rejects both unrepresentable shapes, and
;; make-interpreted-machine refuses an unverified machine -- so `interp` cannot
;; carry one this far. The guards below are NOT thereby dead: normalize-machine and make-interpreted-
;; machine both remain reachable by a caller that skips verification, and
;; (byte-machine private ir) exports make-verification-result, so that caller is
;; expressible here. Forging an ok? verification the verifier would never
;; produce is precisely the shape the guards exist to catch, and witnessing them
;; that way is what catches SchemeMutationSuite.cmake's two Pass 34 guard
;; mutations.
(define (unverified m) (make-verification-result #t '() m))
(define (interp-unverified m) (make-interpreted-machine (unverified m)))

(harness-group "the verifier rejects both unrepresentable shapes before the interpreter"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is a verification diagnostic"
      (lambda ()
        (let ((v (verify-machine (seq-m 'amb '(((65 66) . stop) ((65 66 67) . halt))
                                        'reexecute (list (make-stop-node 'halt #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "ambiguous-sequence-prefix"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'ambiguous-sequence-prefix))
                         (verification-diagnostics v))))))
    (harness-case "two identical alternatives are the same diagnostic"
      (lambda ()
        (let ((v (verify-machine (seq-m 'dup '(((65 66) . stop) ((65 66) . halt))
                                        'reexecute (list (make-stop-node 'halt #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "ambiguous-sequence-prefix"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'ambiguous-sequence-prefix))
                         (verification-diagnostics v))))))
    (harness-case "handing the rejected machine to the interpreter is a contract violation"
      (lambda ()
        (check-raises "unverified-machine"
                      (lambda (e)
                        (and (byte-machine-contract-condition? e)
                             (eq? (byte-machine-contract-condition-code e) 'unverified-machine)
                             (eq? (byte-machine-contract-condition-who e) 'make-interpreted-machine)))
                      (lambda ()
                        (interp (seq-m 'amb2 '(((65 66) . stop) ((65 66 67) . halt))
                                       'reexecute (list (make-stop-node 'halt #f))))))))))

(harness-group "the interpreter's own guards still fire for a caller that skips verification"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (raises-interpret-assertion? "ambiguous terminal prefix")
                      (lambda ()
                        (feed-bytes (interp-unverified
                                     (seq-m 'amb '(((65 66) . stop) ((65 66 67) . halt))
                                            'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (raises-interpret-assertion? "duplicate sequence alternative")
                      (lambda ()
                        (feed-bytes (interp-unverified
                                     (seq-m 'dup '(((65 66) . stop) ((65 66) . halt))
                                            'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))))

(harness-group "advance-mode mismatch shifts every reported position by one"
  (lambda ()
    (define adv (interp (seq-m 'adv '(((1 2 3 4) . stop)) 'advance '())))
    (harness-case "the offending byte is consumed and the offset advances past it"
      (lambda ()
        (check-equal "pos 0" (feed-bytes adv '(200)) '(error 1 1 1 unexpected-byte))
        (check-equal "pos 1" (feed-bytes adv '(1 200)) '(error 1 1 2 unexpected-byte))
        (check-equal "pos 2" (feed-bytes adv '(1 2 200)) '(error 1 1 3 unexpected-byte))
        (check-equal "pos 3" (feed-bytes adv '(1 2 3 200)) '(error 1 1 4 unexpected-byte))))))

;; None of the fixtures above calls parser-finish! while `current` is a
;; compound, so this group is the witness for eof-target-of's (car cur)
;; extraction (interpret.sls's own comment says a compound answers with ITS
;; SOURCE NODE'S eof-target). Mirrors (byte-machine test eof-machine)'s
;; s1 -> 'trunc pattern: the sequence node's eof-target names an error node
;; directly, reusing the SAME 'reject node the mismatch edge already uses, so no
;; new error declaration is needed and the machine stays well-formed by the same
;; shape verify-tests.sps's arm-4 fixture already establishes as legal.
(harness-group "EOF through a compound current reads the sequence node's own eof-target"
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
                         (error-code-of r) 'unexpected-byte)))))))

;; --- the counted-consume op, driven directly --------------------------------
;;
;; `count-step` is the op's counted-consume message, driven through the op
;; closure a compiled machine wraps (slot 2 of its tagged vector -- the shipped
;; practice for a test that needs an internal). The cases are the counted
;; consume's outcome table (zero count, empty slice, partial, exact, surplus
;; input), read off the op's answer and the field vector it commits into.
(define (op-of cm) (vector-ref cm 2))
(define (cc-interp eof)
  (make-machine 'ccint 'start (list (make-uint-field 'len 64 3 #f)) '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'body 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-counted-consume-node 'body 'len 'done eof #f)
          (make-stop-node 'done #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define cc-op (op-of (make-interpreted-machine (verify-machine (cc-interp #f)))))
(define (fresh-fields v) (let ((fv (cc-op 'field-initials))) (vector-set! fv 0 v) fv))

(harness-group "count-step's outcome table"
  (lambda ()
    (harness-case "the kind and the EOF route are the op's own arms"
      (lambda ()
        (check-equal "kind" (cc-op 'kind 'body) 'counted-consume)
        (check-equal "absent eof-target" (cc-op 'eof-target 'body) #f)
        (check-equal "a named eof-target"
                     ((op-of (make-interpreted-machine (verify-machine (cc-interp 'reject))))
                      'eof-target 'body)
                     'reject)))
    (harness-case "a zero count over an empty slice transitions -- the zero-count test comes first"
      (lambda ()
        (let ((fv (fresh-fields 0)))
          (check-equal "(0 . next)" (cc-op 'count-step 'body fv 5 5) '(0 . done))
          (check-equal "nothing committed" (vector-ref fv 0) 0))))
    (harness-case "a positive count over an empty slice takes the EOF route"
      (lambda ()
        (let ((fv (fresh-fields 3)))
          (check-equal "(0 . #f)" (cc-op 'count-step 'body fv 5 5) '(0 . #f))
          (check-equal "the count is untouched" (vector-ref fv 0) 3))))
    (harness-case "partial input commits what is available and does not continue"
      (lambda ()
        (let ((fv (fresh-fields 3)))
          (check-equal "(2 . #f)" (cc-op 'count-step 'body fv 0 2) '(2 . #f))
          (check-equal "the count is reduced by the commit" (vector-ref fv 0) 1))))
    (harness-case "exact input completes the count and continues -- count completion wins"
      (lambda ()
        (let ((fv (fresh-fields 3)))
          (check-equal "(3 . next)" (cc-op 'count-step 'body fv 0 3) '(3 . done))
          (check-equal "the count reaches zero" (vector-ref fv 0) 0))))
    (harness-case "surplus input commits the count only and continues"
      (lambda ()
        (let ((fv (fresh-fields 3)))
          (check-equal "(3 . next)" (cc-op 'count-step 'body fv 0 5) '(3 . done))
          (check-equal "the count reaches zero" (vector-ref fv 0) 0))))
    (harness-case "a nonzero cursor commits from the cursor"
      (lambda ()
        (let ((fv (fresh-fields 2)))
          (check-equal "(1 . #f)" (cc-op 'count-step 'body fv 4 5) '(1 . #f))
          (check-equal "one committed" (vector-ref fv 0) 1))))
    (harness-case "a u64 count above the fixnum range subtracts exactly"
      (lambda ()
        (let* ((big (+ (greatest-fixnum) 5)) (fv (fresh-fields big)))
          (check-equal "(3 . #f)" (cc-op 'count-step 'body fv 0 3) '(3 . #f))
          (check "bignum arithmetic" (= (vector-ref fv 0) (- big 3))))))))

(harness-finish)
