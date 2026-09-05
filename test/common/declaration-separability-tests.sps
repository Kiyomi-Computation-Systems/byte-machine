;;; Milestone 5 Slice ①b's oracle: a machine that DECLARES callbacks and spans
;;; and contains no callback or span NODE must verify, normalize, emit and run
;;; identically in both lanes, with the differential's existing value tuple
;;; unchanged.
;;;
;;; *** NO LATER SLICE CAN ESTABLISH THIS. *** Once a callback-invocation node
;;; exists, a declaration is no longer separable from its use by construction,
;;; and a test asserting they are separable would be asserting something about
;;; the fixture rather than about the design. Slice ①b is the only slice in which
;;; "declared but unused" is the ONLY thing a declaration can be.
;;;
;;; The tuple is asserted UNCHANGED rather than merely equal across lanes: two
;;; lanes that both moved the same way agree, and a differential comparing only
;;; the two would pass while the contract moved underneath it.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (rnrs bytevectors)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.declaration-separability")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'declaration-separability
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

;; One machine, twice: identical nodes, differing only in whether the
;; declaration tables are populated. Byte 0 stops; anything else errors.
(define (one-byte nm cbs sps)
  (make-machine nm 'start '() cbs sps (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0)
                                  (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

;; Distinct machine NAMES because the emitted library is `(generated <name>)`:
;; two machines sharing a name would emit two libraries with one identity and
;; the second `load` would silently win.
(define (decls)
  (list (make-callback-declaration 'on-x 'event #f '() #f #f)
        (make-callback-declaration 'on-data 'span-data #f '() #f #f)
        (make-callback-declaration 'on-done 'span-complete #f '() #f #f)))
(define (spans) (list (make-span-declaration 'body 'on-data 'on-done #f)))
(define bare (one-byte 'sepbare '() '()))
(define declaring (one-byte 'sepdecl (decls) (spans)))
(define declaring2 (one-byte 'sepdecl2 (decls) (spans)))
(define declaring3 (one-byte 'sepdecl3 (decls) (spans)))
(define (emit-and-load mach mname binding file)
  (call-with-port (open-file-output-port file (file-options no-fail))
    (lambda (p) (emit-machine (compile-machine mach '()) binding p)))
  (load file)
  (eval binding (environment (list 'generated mname))))

(define (feed-one cm b)
  (let ((p (make-parser cm '() #f)))
    (let ((r (parser-feed! p (u8-list->bytevector (list b)) 0 1)))
      (list (parser-result-status r)
            (parser-result-next r)
            (parser-result-consumed r)
            (parser-result-stream-offset r)
            (parser-lifecycle p)))))

(harness-group "a declaring machine verifies exactly as the bare one does"
  (lambda ()
    (harness-case "both verify clean"
      (lambda ()
        ;; The declarations are well-formed and unused: pass-declarations has
        ;; nothing to say, and no other pass can see them.
        (check "bare" (verification-ok? (verify-machine bare)))
        (check "declaring" (verification-ok? (verify-machine declaring)))))))

(harness-group "declarations are observable in the IR and nowhere else"
  (lambda ()
    (harness-case "the emitted text differs, so the declarations are really carried"
      (lambda ()
        ;; Without this the rest of the file would pass on an encoder that
        ;; dropped the declaration tables entirely, and on an emitter that
        ;; rendered member 1 empty regardless. The emitted bytes carry BOTH the
        ;; IR fingerprint and the ABI payload, so one comparison covers both.
        (check "distinct"
               (not (equal? (render-machine (compile-machine bare '()) 'p)
                            (render-machine (compile-machine declaring '()) 'p))))))))

(harness-group "the value tuple is UNCHANGED, in both lanes, declared or not"
  (lambda ()
    (harness-case "four lanes agree with the shipped answer"
      (lambda ()
        ;; The literal is the point. Comparing the two lanes to each other would
        ;; pass if both moved together; comparing them to a value written down
        ;; before this slice is what makes "unchanged" mean something.
        (let* ((expected '(stopped 1 1 1 stopped))
               (ref-bare (make-interpreted-machine (verify-machine bare)))
               (ref-decl (make-interpreted-machine (verify-machine declaring)))
               (gen-bare (emit-and-load bare 'sepbare 'sep-bare-parser
                                        (string-append tmpdir "/generated-sep-bare.sls")))
               (gen-decl (emit-and-load declaring 'sepdecl 'sep-decl-parser
                                        (string-append tmpdir "/generated-sep-decl.sls")))
               (lanes (list (list "interpreted, bare" ref-bare)
                            (list "interpreted, declaring" ref-decl)
                            (list "generated, bare" gen-bare)
                            (list "generated, declaring" gen-decl)))
               (driven 0))
          (for-each (lambda (lane)
                      (set! driven (+ driven 1))
                      (check-equal (car lane) (feed-one (cadr lane) 0) expected))
                    lanes)
          ;; Sentinel over what was DRIVEN, not over the list's length.
          (check-equal "all four lanes were driven" driven 4))))
    (harness-case "and the rejecting path agrees too"
      (lambda ()
        (let ((ref (make-interpreted-machine (verify-machine declaring2)))
              (gen (emit-and-load declaring2 'sepdecl2 'sep-decl2-parser
                                  (string-append tmpdir "/generated-sep-decl2.sls"))))
          (check-equal "same error status across lanes"
                       (car (feed-one ref 9)) (car (feed-one gen 9))))))))

(harness-group "binding resolution reaches the generated lane too"
  (lambda ()
    (harness-case "an optional declared callback needs no binding, in either lane"
      (lambda ()
        ;; §9.3:419's defaulting, witnessed by observed behaviour: every
        ;; declaration above is optional, so a parser must build with NO
        ;; bindings at all -- and the generated lane resolves against ABI member
        ;; 1 rather than against the source machine.
        (let ((gen (emit-and-load declaring3 'sepdecl3 'sep-decl3-parser
                                  (string-append tmpdir "/generated-sep-decl3.sls"))))
          (check "generated" (parser? (make-parser gen '() #f)))
          (check "interpreted"
                 (parser? (make-parser (make-interpreted-machine (verify-machine declaring3))
                                       '() #f))))))
    (harness-case "a required callback is refused in the generated lane as well"
      (lambda ()
        ;; The resolver is lane-blind, and this is what proves member 1 actually
        ;; carries `required?` rather than the generated lane defaulting to #f.
        (let* ((req (one-byte 'sepreq
                              (list (make-callback-declaration 'must 'event #t '() #f #f)) '()))
               (gen (emit-and-load req 'sepreq 'sep-req-parser
                                   (string-append tmpdir "/generated-sep-req.sls"))))
          ;; who + code + detail, not merely "something raised": a bare
          ;; raise-catcher would pass on ANY failure, including the generated
          ;; library failing to load at all, and would prove nothing about
          ;; member 1 carrying `required?`.
          (check-raises "generated refuses, naming the missing required callback"
                        (lambda (e)
                          (and (byte-machine-contract-condition? e)
                               (eq? (byte-machine-contract-condition-who e) 'make-parser)
                               (eq? (byte-machine-contract-condition-detail e)
                                    'missing-required-callback)))
                        (lambda () (make-parser gen '() #f)))
          ;; And the same machine with the binding supplied builds, so the
          ;; refusal above is about the BINDING and not about the machine.
          (check "and builds once bound"
                 (parser? (make-parser gen (list (list 'must (lambda args 'ignored))) #f))))))))

(harness-finish)
