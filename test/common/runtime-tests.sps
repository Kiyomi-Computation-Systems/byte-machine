;;; Runtime parser lifecycle over a hand-built compiled-machine stub, so the
;;; loop is witnessed independently of the interpreter (Task 5 supplies the real
;;; op). The stub encodes the one-byte machine: byte 0 advances to stop; any
;;; other byte reexecutes into the error node.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine runtime))

(harness-begin "unit.runtime")

(define (one-byte-op msg . args)
  (case msg
    ((entry) 'start)
    ((kind) (case (car args) ((start) 'dispatch) ((stop) 'stop) ((reject) 'error)))
    ((dispatch)
     (let ((byte (cadr args)))
       (if (= byte 0) (cons 'stop 'advance) (cons 'reject 'reexecute))))
    ((error-value) 'unexpected-byte)
    (else (assertion-violation 'one-byte-op "bad message" msg))))

(define (feed-byte b)
  (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
    (parser-feed! p (make-bytevector 1 b) 0 1)))

(harness-group "callback outcome singletons"
  (lambda ()
    (harness-case "continue and pause are stable, distinct singletons"
      (lambda ()
        (check "continue is itself" (eq? callback-continue callback-continue))
        (check "pause is itself" (eq? callback-pause callback-pause))
        (check "continue is not pause" (not (eq? callback-continue callback-pause)))))))

(harness-group "one-byte parser lifecycle"
  (lambda ()
    (harness-case "the accepted byte stops after consuming one byte"
      (lambda ()
        (let ((r (feed-byte 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "next" (parser-result-next r) 1)
          ;; The advance path is the only one that increments the stream offset;
          ;; the reject case below pins it at 0, so this is where the increment
          ;; itself is observed.
          (check-equal "stream offset" (parser-result-stream-offset r) 1))))
    (harness-case "a rejected byte errors at position 0 without consuming"
      (lambda ()
        (let ((r (feed-byte 65)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "stream offset" (parser-result-stream-offset r) 0)
          (check-equal "error value" (parser-result-error r) 'unexpected-byte))))
    (harness-case "an empty slice needs input and reports no result yet"
      (lambda ()
        (let* ((p (make-parser (make-compiled-machine one-byte-op) '() #f))
               (returned 'not-yet-run))
          (set! returned (parser-result-status (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" returned 'need-input))))))

;; The direct-executor ABI. A hand-built feed encodes the one-byte machine over
;; numeric states (0 dispatch, 1 stop, 2 error), so the v1 path is witnessed
;; independently of the emitter.
(define (stub-feed state offset bv start end)
  (let loop ((pos start) (st state) (off offset))
    (case st
      ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 'error pos 'unexpected-byte 2 off))
      (else
       (if (>= pos end)
           (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off)
           (let ((b (bytevector-u8-ref bv pos)))
             (if (= b 0) (loop (+ pos 1) 1 (+ off 1)) (loop pos 2 off))))))))
(define (v1-machine) (byte-machine-make-compiled-machine/v1 1 42 0 stub-feed))
(define (v1-feed-byte b)
  (parser-feed! (make-parser (v1-machine) '() #f) (make-bytevector 1 b) 0 1))

(harness-group "generated-code ABI (/v1)"
  (lambda ()
    (harness-case "the accepted byte stops after consuming one byte"
      (lambda ()
        (let ((r (v1-feed-byte 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "stream offset" (parser-result-stream-offset r) 1))))
    (harness-case "a rejected byte errors at position 0 with the code"
      (lambda ()
        (let ((r (v1-feed-byte 65)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "stream offset" (parser-result-stream-offset r) 0)
          (check-equal "error value" (parser-result-error r) 'unexpected-byte))))
    (harness-case "an empty slice needs input"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (got 'not-yet))
          (set! got (parser-result-status (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" got 'need-input))))
    (harness-case "a repeat feed on a terminal parser reports a fresh empty result (§12.2)"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (r1 (parser-feed! p (make-bytevector 1 0) 0 1))
               (r2 (parser-feed! p (make-bytevector 1 0) 0 1)))
          (check-equal "first stopped" (parser-result-status r1) 'stopped)
          (check-equal "second still stopped" (parser-result-status r2) 'stopped)
          (check-equal "second next is the new slice start" (parser-result-next r2) 0)
          (check-equal "second consumed is zero" (parser-result-consumed r2) 0)
          (check-equal "second stream offset unchanged"
                       (parser-result-stream-offset r2) (parser-result-stream-offset r1)))))
    (harness-case "parser-lifecycle tracks ready -> terminal"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
          (check-equal "starts ready" (parser-lifecycle p) 'ready)
          (parser-feed! p (make-bytevector 1 0) 0 1)
          (check-equal "stopped after accept" (parser-lifecycle p) 'stopped)
          (let ((q (make-parser (v1-machine) '() #f)))
            (parser-feed! q (make-bytevector 1 65) 0 1)
            (check-equal "error after reject" (parser-lifecycle q) 'error)))))
    (harness-case "a mismatched ABI version is refused"
      (lambda ()
        (check-raises "refused"
                      (lambda (e) #t)
                      (lambda () (byte-machine-make-compiled-machine/v1 2 42 0 stub-feed)))))))

(harness-group "invalid feed slices"
  (lambda ()
    (harness-case "a slice past the bytevector end raises a coded contract condition"
      (lambda ()
        (check-raises "invalid slice"
          (lambda (e)
            (and (byte-machine-contract-condition? e)
                 (eq? (byte-machine-contract-condition-code e) 'invalid-slice)
                 (eq? (byte-machine-contract-condition-who e) 'parser-feed!)))
          (lambda ()
            (parser-feed! (make-parser (make-compiled-machine one-byte-op) '() #f)
                          (make-bytevector 1 0) 0 5)))))))

(harness-finish)
