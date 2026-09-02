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

;; A second machine whose entry dispatch routes EOF to a finish node ('done),
;; so the emitter renders the finish terminal arm -- absent from the one-byte
;; machine, whose eof routes to the default error. Byte 1 -> stop; EOF at entry
;; -> finish 'done -> finished. It verifies (finish is EOF-only, not byte-reached).
(define eof-fin
  (make-machine 'eofm 's0 '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 's0
            (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) 'done #f)
          (make-stop-node 'stop #f)
          (make-finish-node 'done #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define eof-ok (compile-machine eof-fin '()))
(define (eof-text) (utf8->string (render-machine eof-ok 'eof-parser)))
(define (eof-has? needle) (harness-string-contains? (eof-text) needle))

;; A third machine exercising the pause kind (Slice 3): byte 1 -> pause p1
;; (continuation s1); byte 2 at s1 -> stop. EOF at entry -> pause pe
;; (continuation done, a finish node). Inlined rather than imported --
;; (byte-machine test pause-machine) is the source of truth for this graph
;; (kept in sync by hand); the compile lanes carry no fixture libraries today
;; (the eof-fin precedent above), and this file's charter is the rendered
;; TEXT (header :1-5), not execution -- the CORE_COMPILE manifest carries no
;; runtime.sls, so a compile+eval case cannot even load the generated library
;; here. The pause/resume execution walks are Task 5's, in the CORE_EMIT lanes.
(define pausem
  (make-machine 'pausem 's0 '() '() '()
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
          (make-error-declaration 'truncated 'truncated-input "truncated input" #f))
    (list (make-byte-dispatch-node 's0
            (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'p1 'advance) #f))
            (make-edge 'reject 'reexecute) 'pe #f)
          (make-pause-node 'p1 's1 #f)
          (make-byte-dispatch-node 's1
            (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) 'trunc #f)
          (make-pause-node 'pe 'done #f)
          (make-stop-node 'stop #f)
          (make-finish-node 'done #f)
          (make-error-node 'trunc 'truncated #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define pause-ok (compile-machine pausem '()))
(define (pause-text) (utf8->string (render-machine pause-ok 'pause-parser)))

;; The status token and the next state a pause arm renders, as one short
;; string -- "paused 2" for
;;   ((1) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 2 off))
;;
;; Both Slice 3 emitter decisions -- which status a pause arm emits, and which
;; state it parks on -- live in that ONE line, and a `check` over a substring
;; probe reports the same content-blind "expected a true value" for either, so
;; the mutation suite could not tell the two mutations apart (Slice 3 pin
;; audit). Splitting the probe in two does not separate them either: a pause
;; continuation is a dispatch node whose own need-input arm parks on that same
;; state id, so the " pos #f 2 off))" tail survives the next-state mutation
;; elsewhere in the rendered text and a target-only probe would be vacuous.
;; Comparing the two extracted fields with check-equal puts them in the
;; failure detail instead, so each decision has its own signature. This is
;; still search-only over the rendered text (header :1-5): two tokens read out
;; of one known line, never a re-parse of the emitted library.
(define (pause-arm-fields line)
  (let loop ((fs (harness-split line #\space)) (acc '()))
    (cond ((null? fs) (reverse acc))
          ((string=? (car fs) "") (loop (cdr fs) acc))
          (else (loop (cdr fs) (cons (car fs) acc))))))
(define (pause-arm st)
  (let ((head (string-append "((" (number->string st)
                             ") (byte-machine-make-feed-outcome/v1 (quote ")))
    (let loop ((lines (harness-split (pause-text) #\newline)))
      (cond
        ((null? lines) "no such arm")
        ((harness-string-contains? (car lines) head)
         ;; ("((1)" "(byte-machine-make-feed-outcome/v1" "(quote" "paused)"
         ;;  "pos" "#f" "2" "off))") -- the status loses its closing paren, and
         ;; the next state is the field before "off))". Any other shape is
         ;; reported whole rather than indexed into, so a mutation that
         ;; changes the arm's arity fails the comparison instead of raising.
         (let ((fields (pause-arm-fields (car lines))))
           (if (= (length fields) 8)
               (string-append (substring (list-ref fields 3) 0
                                         (- (string-length (list-ref fields 3)) 1))
                              " " (list-ref fields 6))
               (harness-join fields " "))))
        (else (loop (cdr lines)))))))

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
    (harness-case "it constructs the compiled machine through one unversioned call"
      (lambda ()
        ;; Decision 0018: the versioned NAME is retired, the version NUMBER
        ;; survives and moves to 3, and the trailing quoted vector is the
        ;; growable payload whose member 0 is the empty field-initials vector.
        ;; It renders as #(#()) rather than #() because an empty vector has no
        ;; member 0 -- ①b would have to add one, moving every golden in the
        ;; slice whose headline invariant is that none moves.
        (check "unversioned call"
               (has? "(byte-machine-make-compiled-machine 3 14095574568398596535 0 exec (quote #(#())))"))
        (check "no versioned name survives"
               (not (has? "byte-machine-make-compiled-machine/v")))))
    (harness-case "exec carries the reserved seventh parameter"
      (lambda ()
        ;; Reserved empty by decision 0019 item 3(c) and filled in Slice ②. The
        ;; parameter lands NOW so that ②'s field store changes no emitted text
        ;; for a zero-field machine.
        (check "seventh parameter"
               (has? "(define (exec state offset bv start end finish? fieldv)"))))
    (harness-case "the accepted byte advances and the fallback reexecutes"
      (lambda ()
        (check "advance arm" (has? "((0) (loop (+ pos 1) 1 (+ off 1) (quote boundary)))"))
        (check "fallback"    (has? "(else (loop pos 2 off (quote byte)))"))))
    (harness-case "the error state emits the resolved code"
      (lambda ()
        (check "error arm"
               (has? "(byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 1) (quote reject) 2 off pk) 2 off)"))
        ;; The errs table is per DECLARATION, not per site: the default-eof arm
        ;; alone renders at every dispatch state.
        (check "errs table"
               (has? "(define errs (quote #(#(eof \"unexpected end of input\") #(unexpected-byte \"unexpected byte\"))))"))))
    (harness-case "an exhausted dispatch branches on finish? and routes eof to the default error"
      (lambda ()
        (check "finish eof guard" (has? "(if finish?"))
        (check "eof routes to the default-eof error"
               (has? "(byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote start) 0 off (quote eof)) 0 off)"))))
    (harness-case "a finish node renders the finished terminal arm"
      (lambda ()
        (check "finish machine compiles" (compilation-ok? eof-ok))
        (check "finish arm" (eof-has? "(byte-machine-make-feed-outcome/v1 (quote finished) pos #f"))))
    (harness-case "a pause node renders the paused terminal arm with its continuation target"
      (lambda ()
        (check "pause machine compiles" (compilation-ok? pause-ok))
        (check-equal "pause arm p1" (pause-arm 1) "paused 2")
        (check-equal "pause arm pe" (pause-arm 3) "paused 5")))))

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
        (check-raises "member 3" (lambda (e) #t) (lambda () (render-machine ok 'exec)))))))

(harness-group "emission"
  (lambda ()
    (harness-case "emit writes render's bytes and reports the fingerprint and count"
      (lambda ()
        (let-values (((port get) (open-bytevector-output-port)))
          (let ((meta (emit-machine ok 'one-byte-parser port)))
            (check-equal "fingerprint" (vector-ref meta 1) 14095574568398596535)
            (check-equal "byte count matches render"
                         (vector-ref meta 2) (bytevector-length (render-machine ok 'one-byte-parser)))
            (check-equal "bytes written match render"
                         (get) (render-machine ok 'one-byte-parser))))))))

(harness-finish)
