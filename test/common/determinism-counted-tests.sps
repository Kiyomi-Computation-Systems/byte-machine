;;; D6 (parent §22.9, §20) over the Milestone 6 Slice ① counted machine: deterministic
;;; emission proved against a committed golden, and the emitted library's counted
;;; walks proved directly. The FIFTH golden, on the accumulate lane's reasoning: a
;;; counted-consume node renders an arm no other golden contains -- a zero-count
;;; jump, a bulk commit through `min`, and an exhausted clause that is not the
;;; shared preamble -- so a determinism claim that excluded it would be a claim
;;; about the other four machines.
;;;
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test counted-machine)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.counted")

(define ok (compile-machine (make-counted-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_COUNTED_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism
                             "BYTE_MACHINE_COUNTED_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'countedm) (render-machine ok 'countedm))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'countedm)
                     (adapter-file-bytes golden-file))))))

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'determinism-counted "no tmpdir" #f)))
(define genfile (string-append tmpdir "/determinism-counted.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine ok 'countedm p)))
(load genfile)
(define cm (eval 'countedm (environment '(generated countedm))))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (feed p s) (parser-feed! p (str->bv s) 0 (string-length s)))

(harness-group "the golden output compiles and executes the counted walks"
  (lambda ()
    ;; Each walk drives the arm the golden's rendered text is FOR.
    (harness-case "one message: the body is consumed in bulk and the loop returns to idle"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p "3:abc,")))
          (check-equal "need-input at the end" (parser-result-status r) 'need-input)
          (check-equal "six consumed" (parser-result-consumed r) 6)
          (check-equal "back at idle" (parser-state-name p) 'idle)
          (check-equal "the count is cleared" (parser-field-ref p 'len) 0))))
    (harness-case "a zero-length body transitions without consuming (§10.6:600)"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p "0:")))
          (check-equal "need-input" (parser-result-status r) 'need-input)
          (check-equal "parked on the delimiter dispatch, not the body" (parser-state-name p) 'comma))))
    (harness-case "EOF between messages is finished; EOF mid-body is the truncation error"
      (lambda ()
        (let ((p (make-parser cm '() #f)))
          (check-equal "fresh parser finishes" (parser-result-status (parser-finish! p)) 'finished))
        (let* ((p (make-parser cm '() #f)))
          (feed p "3:ab")
          (let ((r (parser-finish! p)))
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "reason" (parser-error-reason (parser-result-error r)) "truncated message")
            (check-equal "position kind" (parser-error-position-kind (parser-result-error r)) 'eof)
            (check-equal "at the final offset" (parser-error-offset (parser-result-error r)) 4)))))
    (harness-case "a non-digit at idle is rejected"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p "x")))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "reason" (parser-error-reason (parser-result-error r)) "unexpected byte"))))))

(harness-finish)
