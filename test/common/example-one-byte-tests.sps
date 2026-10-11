;;; The end-to-end example, run as one program in both lanes:
;;; construct only through (byte-machine graph); verify; compile without runtime
;;; evaluation; emit the .sls to a binary file port; the consumer imports the
;;; generated library (by import, never include) and only (byte-machine runtime),
;;; constructs a parser, feeds the exact [0,1) slice, and inspects the result.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test one-byte-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "example.one-byte")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'example "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/example-one-byte.sls"))

(define one-byte (make-one-byte-machine))

(harness-group "construct, verify, compile, emit, import, run"
  (lambda ()
    (harness-case "the emitted parser accepts the exact byte across the library boundary"
      (lambda ()
        (let ((comp (compile-machine one-byte '())))
          (check "verified and compiled" (compilation-ok? comp))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine comp 'one-byte-parser p)))
          (load genfile)
          (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
                 (input (make-bytevector 1 0))
                 (r (parser-feed! (make-parser cm '() #f) input 0 1)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "consumed one byte" (parser-result-consumed r) 1)))))
    (harness-case "the emitted parser accepts the exact byte in a nonzero-offset slice"
      (lambda ()
        (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
               (padded (let ((v (make-bytevector 3 9))) (bytevector-u8-set! v 1 0) v))
               (r (parser-feed! (make-parser cm '() #f) padded 1 2)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "next is the absolute index past the consumed byte"
                       (parser-result-next r) 2)
          (check-equal "consumed one byte" (parser-result-consumed r) 1)
          (check-equal "stream offset advanced by one" (parser-result-stream-offset r) 1))))))

(harness-finish)
