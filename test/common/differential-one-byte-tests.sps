;;; interpreter ≡ generated across all 256 byte values (parent §22.4). The
;;; generated library is emitted at run time, loaded, and its compiled-machine
;;; obtained by environment/eval; both executors run through the shared
;;; make-parser/parser-feed! API and their parser-result fields are compared.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine test one-byte-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.one-byte")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/generated-one-byte.sls"))

(define one-byte (make-one-byte-machine))

(define cm-ref (make-interpreted-machine (verify-machine one-byte)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine one-byte '()) 'one-byte-parser p)))
(load genfile)
(define cm-gen (eval 'one-byte-parser (environment '(generated one-byte))))

(define (rfields cm b)
  (let ((r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1)))
    (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
          (parser-result-stream-offset r) (project-error (parser-result-error r)))))

(harness-group "interpreter and generated agree on every byte"
  (lambda ()
    (harness-case "all 256 byte values match"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (unless (equal? (rfields cm-ref b) (rfields cm-gen b))
                (if (eq? bad 'none) (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte disagreed" bad 'none))))
    (harness-case "the accepted byte stops after one byte in both"
      (lambda ()
        (check-equal "match" (rfields cm-gen 0) (rfields cm-ref 0))
        (check-equal "generated stops" (car (rfields cm-gen 0)) 'stopped)))
    (harness-case "a rejected byte errors at position 0 in both"
      (lambda ()
        (check-equal "match" (rfields cm-gen 7) (rfields cm-ref 7))
        (check-equal "generated errors" (car (rfields cm-gen 7)) 'error)))))

(harness-finish)
