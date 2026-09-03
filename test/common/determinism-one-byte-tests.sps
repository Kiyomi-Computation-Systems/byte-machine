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
        (byte-machine verify)
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

;; Whole-branch review of Slice ①b, CRITICAL. The `spare` declaration above
;; carries a DISTINCT code and distinct reasons, so the reached-declaration
;; filter drops it from both machines and the case above passes. The filter does
;; not test declaration identity -- the normalizer has already discarded the
;; declaration NAME, so it tests whether the declaration's (code . reason) pair
;; appears among the reached ones -- and an unreached declaration that DUPLICATES
;; a reached pair therefore passes the filter and is emitted. Nothing rejects
;; duplicate codes or duplicate reasons; both machines below verify clean.
;;
;; This is the same defect commit 51fd5f3 was written to close, reached by a
;; second construction that commit's own regression case cannot see. The
;; difference is a declaration COUNT, not a reason string, so the two machines
;; here differ only in whether the third declaration exists at all.
(define (one-byte/dup extra)
  (make-machine 'one-byte 'start '() '() '()
    (append (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                  (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
            (if extra
                ;; Named by no node, so unreached -- but its code AND reason both
                ;; duplicate `rejected`'s, which IS reached.
                (list (make-error-declaration 'spare 'unexpected-byte "unexpected byte" #f))
                '()))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0)
                                  (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(harness-group "the IR fingerprint identifies the emitted output"
  (lambda ()
    (harness-case "an unreached declaration duplicating a reached pair is not emitted"
      (lambda ()
        (let ((a (one-byte/dup #t)) (b (one-byte/dup #f)))
          ;; Both premises asserted: without them the byte check could pass
          ;; because one machine failed to verify, or because the fingerprints
          ;; had stopped agreeing for an unrelated reason.
          (check "a verifies" (verification-ok? (verify-machine a)))
          (check "b verifies" (verification-ok? (verify-machine b)))
          (check-equal "the fingerprints agree"
                       (normal-machine-fingerprint (normalize-machine a))
                       (normal-machine-fingerprint (normalize-machine b)))
          (check "and so do the emitted bytes"
                 (equal? (render-machine (compile-machine a '()) 'one-byte-parser)
                         (render-machine (compile-machine b '()) 'one-byte-parser))))))
    (harness-case "the emitted errs table carries no duplicate entry"
      (lambda ()
        ;; Stated separately from the byte comparison because the two machines
        ;; could be made equal by emitting the duplicate in BOTH -- agreement
        ;; bought by making the difference unobservable, which is the repair this
        ;; project has recorded as disarming its own test.
        (check "one entry per reached pair"
               (harness-string-contains?
                (utf8->string (render-machine (compile-machine (one-byte/dup #t) '())
                                              'one-byte-parser))
                "(define errs (quote #(#(eof \"unexpected end of input\") #(unexpected-byte \"unexpected byte\"))))"))))
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
