;;; Deterministic emission of the HTTP fixture (§22.9, §20), on the shipped
;;; determinism goldens' shape. Milestone 8 Slice ⑤ shipped byte-identical
;;; rendering across two emissions and the load-and-run agreement, and DEFERRED
;;; the committed-golden variant "to a hardening slice or M9". Milestone 9
;;; Slice ① adds it (decision 0039, obligation 2): the HTTP fixture is the sixth
;;; committed golden, the largest machine in the tree at 196 682 bytes, compared
;;; byte-for-byte exactly as the other five are — the cross-process/cross-lane/
;;; cross-cell leg §24.2 stage 7 needs, proved transitively through the golden
;;; rather than a cross-job artefact comparison.
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
(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_HTTP_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism-http "BYTE_MACHINE_HTTP_GOLDEN_FILE is unset" f))))
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

;; The sixth committed golden (Milestone 9 Slice ①, decision 0039, obligation 2).
;; Byte-identity within this process (above) PLUS equality to a committed golden
;; every cell and lane compares against gives cross-process, cross-lane and
;; cross-cell identity transitively — the golden is the fixed point (§24.2 stage
;; 7). With no CI this milestone (decision 0041) the cross-CELL width is one cell
;; (macOS arm64, local); the mechanism is total, the coverage is one cell.
(harness-group "the committed golden (§24.2 stage 7, transitive)"
  (lambda ()
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'httpreq)
                     (adapter-file-bytes golden-file))))))

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
