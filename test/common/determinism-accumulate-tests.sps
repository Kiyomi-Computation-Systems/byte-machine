;;; Deterministic emission of the accumulate machine, proved against a committed
;;; golden, and the emitted library's accumulate walks proved directly.
;;; Byte-identity in this process AND equality to the golden give cross-process,
;;; cross-lane and cross-cell identity transitively, exactly as the other
;;; determinism lanes do.
;;;
;;; An INPUT-READING node renders an arm no other golden contains, so a
;;; determinism claim about emission that excluded it would be a claim about the
;;; other node kinds only; this golden carries it.
;;;
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test accumulate-machine)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.accumulate")

(define ok (compile-machine (make-accumulate-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_ACCUMULATE_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism
                             "BYTE_MACHINE_ACCUMULATE_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'accm) (render-machine ok 'accm))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'accm)
                     (adapter-file-bytes golden-file))))))

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'determinism-accumulate "no tmpdir" #f)))
(define genfile (string-append tmpdir "/determinism-accumulate.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine ok 'accm p)))
(load genfile)
(define cm (eval 'accm (environment '(generated accm))))

(define (bytes . bs) (u8-list->bytevector bs))

(harness-group "the golden output compiles and executes the accumulate walks"
  (lambda ()
    ;; Each walk drives the arm the golden's rendered text is FOR. A golden that
    ;; is merely byte-stable proves reproducibility and nothing about meaning;
    ;; these are what make it a golden of a working machine.
    (harness-case "the three base-16 digit ranges all accumulate"
      (lambda ()
        ;; #1aF -> 0x1aF. One byte from each of the emitter's three rendered
        ;; ranges: 49 is `1`, 97 is `a`, 70 is `F`.
        (let ((p (make-parser cm '() #f)))
          (parser-feed! p (bytes 35 49 97 70) 0 4)
          (check-equal "value" (parser-field-ref p 'value) #x1aF))))
    (harness-case "a non-digit takes the fallback edge and stops"
      (lambda ()
        (let* ((p (make-parser cm '() #f))
               (r (parser-feed! p (bytes 35 49 33) 0 3)))
          (check-equal "stopped" (parser-result-status r) 'stopped)
          (check-equal "value" (parser-field-ref p 'value) 1))))
    (harness-case "a fifth hex digit overflows the u16 and names its declaration"
      (lambda ()
        ;; 0xFFFF is the u16 ceiling, so a fifth `F` cannot be taken.
        (let* ((p (make-parser cm '() #f))
               (r (parser-feed! p (bytes 35 70 70 70 70 70) 0 6)))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "the ceiling was reached first"
                       (parser-field-ref p 'value) #xFFFF)
          (check-equal "reason" (parser-error-reason (parser-result-error r))
                       "field overflow")
          (check-equal "position kind"
                       (parser-error-position-kind (parser-result-error r)) 'byte))))
    (harness-case "the accumulate node's own eof route finishes"
      (lambda ()
        ;; `acc` names `done` explicitly: input ending mid-number is a complete
        ;; number, not a truncation.
        (let ((p (make-parser cm '() #f)))
          (parser-feed! p (bytes 35 49) 0 2)
          (check-equal "finished" (parser-result-status (parser-finish! p)) 'finished))))
    (harness-case "while the entry's eof route takes the machine default"
      (lambda ()
        ;; The other route, and the one whose declaration the emitter's
        ;; reached-declaration filter has to keep. The entry names no eof-target.
        (let* ((p (make-parser cm '() #f))
               (r (parser-finish! p)))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "reason" (parser-error-reason (parser-result-error r))
                       "unexpected end of input"))))))

(harness-finish)
