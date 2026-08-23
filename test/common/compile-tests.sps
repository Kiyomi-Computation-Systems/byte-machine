;;; The emitter compiles, renders, and emits the one-byte machine, and validates
;;; its options and output binding. Structure of the rendered text is asserted by
;;; substring (the generated parser's behaviour is proven end-to-end in the
;;; differential and example lanes). Rendered bytes are decoded with utf8->string
;;; only to search them — never to compare against implementation `write` output.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine compile))

(harness-begin "unit.compile")

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
;; An invalid machine: 'unused is unreachable from the entry (verify emits
;; unreachable-node). Every declared name still resolves -- unlike an invalid
;; entry, this does not make normalize-machine itself raise when a mutation
;; skips the verification-ok? branch in compile-machine, so the mutation
;; suite's "reported as compiled ok" pass observes the wrong answer instead of
;; an unrelated crash (Pass 36, task-3 self-review).
(define broken
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f)
          (make-stop-node 'unused #f))
    'default-eof #f))

(define ok (compile-machine one-byte '()))
(define (text) (utf8->string (render-machine ok 'one-byte-parser)))
(define (has? needle) (harness-string-contains? (text) needle))

(harness-group "compilation"
  (lambda ()
    (harness-case "a valid machine compiles ok"
      (lambda () (check "ok" (compilation-ok? ok))))
    (harness-case "an invalid machine does not compile and carries diagnostics"
      (lambda ()
        (let ((c (compile-machine broken '())))
          (check "not ok" (not (compilation-ok? c)))
          (check "has diagnostics" (not (null? (compilation-diagnostics c)))))))
    ;; render-machine's own unless-compilation-ok? guard: the only path in this
    ;; file that ever calls render-machine on a compilation that failed
    ;; verification. Distinguished from render-machine's downstream crash on
    ;; a #f normal (which any mutation to this fixture's compilation would
    ;; still raise through) by checking that the raised condition is the
    ;; named 'render-machine assertion-violation, not an unrelated one.
    (harness-case "render refuses a compilation that failed verification"
      (lambda ()
        (check-raises "not ok"
                      (lambda (e) (and (who-condition? e) (eq? (condition-who e) 'render-machine)))
                      (lambda () (render-machine (compile-machine broken '()) 'irrelevant)))))
    (harness-case "a non-empty option list is refused"
      (lambda ()
        (check-raises "refused" (lambda (e) #t)
                      (lambda () (compile-machine one-byte '(fast))))))))

(harness-group "rendered library structure"
  (lambda ()
    (harness-case "it is a library that exports the binding and imports the runtime"
      (lambda ()
        (check "library form" (has? "(library (generated one-byte)"))
        (check "export" (has? "(export one-byte-parser)"))
        (check "import" (has? "(import (rnrs) (byte-machine runtime))"))))
    (harness-case "it constructs the compiled machine through the v1 ABI with the fingerprint"
      (lambda ()
        (check "v1 call" (has? "(byte-machine-make-compiled-machine/v1 1 11963406767470843108 0 feed)"))))
    (harness-case "the accepted byte advances and the fallback reexecutes"
      (lambda ()
        (check "advance arm" (has? "((0) (loop (+ pos 1) 1 (+ off 1)))"))
        (check "fallback"    (has? "(else (loop pos 2 off))"))))
    (harness-case "the error state emits the resolved code"
      (lambda ()
        (check "error arm" (has? "(byte-machine-make-feed-outcome/v1 (quote error) pos (quote unexpected-byte) 2 off)"))))))

(harness-group "binding validation"
  (lambda ()
    (harness-case "an uppercase or punctuated binding is refused"
      (lambda ()
        (check-raises "grammar" (lambda (e) #t) (lambda () (render-machine ok 'Bad)))))
    (harness-case "an R6RS keyword binding is refused (reserved member 1)"
      (lambda ()
        (check-raises "member 1" (lambda (e) #t) (lambda () (render-machine ok 'define)))))
    ;; make-compiled-machine, not parser-feed!: the latter's trailing "!" is
    ;; already refused by the name grammar, so it cannot witness the
    ;; reserved-member-2 membership check specifically (Pass 36 self-review).
    (harness-case "a runtime export binding is refused (reserved member 2)"
      (lambda ()
        (check-raises "member 2" (lambda (e) #t) (lambda () (render-machine ok 'make-compiled-machine)))))
    (harness-case "a template identifier binding is refused (reserved member 3)"
      (lambda ()
        (check-raises "member 3" (lambda (e) #t) (lambda () (render-machine ok 'feed)))))))

(harness-group "emission"
  (lambda ()
    (harness-case "emit writes render's bytes and reports the fingerprint and count"
      (lambda ()
        (let-values (((port get) (open-bytevector-output-port)))
          (let ((meta (emit-machine ok 'one-byte-parser port)))
            (check-equal "fingerprint" (vector-ref meta 1) 11963406767470843108)
            (check-equal "byte count matches render"
                         (vector-ref meta 2) (bytevector-length (render-machine ok 'one-byte-parser)))
            (check-equal "bytes written match render"
                         (get) (render-machine ok 'one-byte-parser))))))))

(harness-finish)
