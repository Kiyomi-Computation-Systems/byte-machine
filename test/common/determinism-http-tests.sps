;;; Milestone 8 Slice ⑤: deterministic emission of the HTTP fixture (§22.9, §20),
;;; on the five shipped determinism goldens' shape. The committed-golden-file
;;; variant is DEFERRED (the interpreter≡generated differential and the mutation
;;; suite already guard the emitter's output; a large committed golden is
;;; additive regression-detection, named for a hardening slice or M9). Here:
;;; byte-identical rendering across two emissions, and the emitted library loads
;;; and runs, agreeing with the interpreter on a representative request.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "determinism.http")

(define ok (compile-machine (make-http-machine) '()))
(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'determinism-http "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define (emit-to file)
  (call-with-port (open-file-output-port file (file-options no-fail))
    (lambda (p) (emit-machine ok 'httpreq p)))
  (adapter-file-bytes file))

(harness-group "deterministic emission (§22.9)"
  (lambda ()
    (harness-case "rendering twice yields byte-identical output"
      (lambda ()
        (check-equal "twice"
                     (emit-to (string-append tmpdir "/http-a.sls"))
                     (emit-to (string-append tmpdir "/http-b.sls")))))))

(load (string-append tmpdir "/http-a.sls"))
(define gen (eval 'httpreq (environment '(generated httpreq))))
(define ref (make-interpreted-machine (verify-machine (make-http-machine))))
(define (bytes s) (map char->integer (string->list s)))
(define (rfields cm s finish?)
  (let* ((p (make-parser cm '() #f)) (bv (u8-list->bytevector (bytes s)))
         (r0 (parser-feed! p bv 0 (bytevector-length bv)))
         (r (if finish? (parser-finish! p) r0)))
    (list (parser-result-status r) (parser-result-consumed r) (parser-result-stream-offset r))))

(harness-group "the emitted library loads and runs, agreeing with the interpreter"
  (lambda ()
    (harness-case "a fixed-body and a chunked request agree across the two executors"
      (lambda ()
        (for-each
         (lambda (s)
           (check-equal (string-append "agree: " s)
                        (rfields ref s #t) (rfields gen s #t)))
         (list "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\nHELLO"
               "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n0\r\n\r\n"))))))

(harness-finish)
