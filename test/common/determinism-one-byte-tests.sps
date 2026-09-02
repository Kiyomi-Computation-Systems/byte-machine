;;; D6 (parent §22.9, §20): deterministic emission proved against a committed
;;; golden. Byte-identity in this process AND equality to the golden (which every
;;; cell and lane compares against) give cross-process, cross-lane, and cross-cell
;;; identity transitively; M9 completes the four-cell matrix with the same golden.
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine private normal-ir)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.one-byte")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define ok (compile-machine one-byte '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism "BYTE_MACHINE_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'one-byte-parser)
                     (render-machine ok 'one-byte-parser))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'one-byte-parser)
                     (adapter-file-bytes golden-file))))))

(harness-group "the golden output compiles and executes"
  (lambda ()
    (harness-case "loading the emitted library and feeding byte 0 stops after one byte"
      (lambda ()
        (let* ((tmpdir (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR"))
               (genfile (string-append tmpdir "/determinism-one-byte.sls")))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine ok 'one-byte-parser p)))
          (load genfile)
          (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
                 (r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 0) 0 1)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "consumed" (parser-result-consumed r) 1)))))))

;; Milestone 4, resolving decision 0022 item 7's open question. The IR
;; fingerprint is what §20:1043 makes the determinism checks compare, and
;; decision 0019 item 2 states the property it has to carry: "two machines
;; differing only in a reason must differ in fingerprint, or the fingerprint
;; stops identifying what was emitted." The converse is the half that was never
;; asserted -- two machines the fingerprint calls IDENTICAL must emit identical
;; bytes -- and it was false: the encoding carries only reasons the graph
;; reaches, while the emitted errs table carried every declaration.
(define (one-byte/spare spare)
  (make-machine 'one-byte 'start '() '() '()
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
          ;; Named by no node and not the machine default-eof, so nothing
          ;; resolves it and it never reaches the encoder.
          (make-error-declaration 'spare 'spare-code spare #f))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0)
                                  (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(harness-group "the IR fingerprint identifies the emitted output"
  (lambda ()
    (harness-case "equal fingerprints emit equal bytes"
      (lambda ()
        (let* ((a (one-byte/spare "SPARE-A"))
               (b (one-byte/spare "SPARE-B"))
               (fa (normal-machine-fingerprint (normalize-machine a)))
               (fb (normal-machine-fingerprint (normalize-machine b))))
          ;; Stated as two checks rather than one implication: if the
          ;; fingerprints ever stop being equal the premise is gone and the
          ;; second check would pass vacuously, so the premise is asserted.
          (check-equal "the fingerprints agree" fa fb)
          ;; A boolean, not check-equal: these are ~900-byte bytevectors and a
          ;; mismatch dumps both in full, which buries the one differing byte.
          (check "and so do the emitted bytes"
                 (equal? (render-machine (compile-machine a '()) 'one-byte-parser)
                         (render-machine (compile-machine b '()) 'one-byte-parser))))))))

(harness-finish)
