;;; Property differential (parent §22.4, §22.6): generated valid machines, the
;;; interpreter oracle vs the emitted executor, all 256 single-byte feeds each.
;;; The seed is fixed and printed; a disagreement prints the machine index so the
;;; case replays. Generated .sls are test-time artifacts in the tmp root.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test prng)
        (byte-machine test machine-gen)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "property.differential")

(define seed 20260823)
(define machine-count 40)
(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'property "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (rfields cm b)
  (let ((r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1)))
    (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
          (parser-result-stream-offset r) (parser-result-error r))))

;; Emit `m` to a fresh file, load it, and return its compiled-machine. The
;; library name is (generated gen) for every machine, so each emission gets its
;; own file and a fresh eval environment.
(define (emit-and-load m i)
  (let ((genfile (string-append tmpdir "/prop-" (number->string i) ".sls")))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) 'gen-parser p)))
    (load genfile)
    (eval 'gen-parser (environment '(generated gen)))))

(harness-group "the PRNG is reproducible"
  (lambda ()
    (harness-case "the same seed yields the same first draw"
      (lambda ()
        (let-values (((a _sa) (prng-next (make-prng seed) 256))
                     ((b _sb) (prng-next (make-prng seed) 256)))
          (check-equal "same" a b))))))

(harness-group "interpreter and generated agree on every generated machine"
  (lambda ()
    (harness-case "all generated machines verify and agree on all 256 bytes"
      (lambda ()
        (let loop ((i 0) (s (make-prng seed)))
          (when (< i machine-count)
            (let-values (((m s2) (gen-machine s)))
              (let ((v (verify-machine m)))
                (check (string-append "machine " (number->string i) " verifies")
                       (verification-ok? v))
                (when (verification-ok? v)
                  (let ((cm-ref (make-interpreted-machine v))
                        (cm-gen (emit-and-load m i)))
                    (let ((bad 'none))
                      (let bl ((b 0))
                        (when (< b 256)
                          (unless (equal? (rfields cm-ref b) (rfields cm-gen b))
                            (if (eq? bad 'none) (set! bad b)))
                          (bl (+ b 1))))
                      (check-equal
                       (string-append "machine " (number->string i)
                                      " (seed " (number->string seed) ") byte agreement")
                       bad 'none)))))
              (loop (+ i 1) s2))))))))

(harness-finish)
