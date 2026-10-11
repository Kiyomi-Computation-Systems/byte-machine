;;; The emitter compiles, renders, and emits the one-byte machine, and validates
;;; its options and output binding. Structure of the rendered text is asserted by
;;; substring (the generated parser's behaviour is proven end-to-end in the
;;; differential and example lanes). Rendered bytes are decoded with utf8->string
;;; only to search them — never to compare against implementation `write` output.
(import (rnrs)
        (rnrs eval)
        ;; environment-symbols is a Chez extension; the no-declared-name witness
        ;; below subtracts the (rnrs) and (byte-machine runtime) environments
        ;; from the emitted identifiers. (byte-machine runtime) is imported
        ;; statically so the AOT lane compiles it.
        (only (chezscheme) environment-symbols)
        (only (byte-machine private names) portable-name?)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine runtime)
        ;; ir's reading accessors graph does not re-export -- the no-declared-name
        ;; witness walks the witness machine's nodes. The names graph DOES re-export (e.g.
        ;; sequence-dispatch-node?) are the same bindings, so importing both is legal.
        (only (byte-machine private ir)
              machine-nodes machine-spans node-name
              byte-dispatch-node? sequence-dispatch-node? stop-node? error-node?
              finish-node? pause-node? field-action-node? field-branch-node?
              integer-accumulate-node? callback-node? span-start-node? span-end-node?
              counted-consume-node? keyword-table-node? span-end-node-span span-declaration-name
              span-declaration-complete-callback)
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
;; an unrelated crash (Pass 36).
(define broken
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f)
          (make-stop-node 'unused #f))
    'default-eof #f))

;; The same one-byte machine with two field declarations.
(define with-fields
  (make-machine 'one-byte 'start
    (list (make-uint-field 'count 8 0 #f) (make-uint-field 'limit 16 65535 #f))
    '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
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

;; A third machine exercising the pause kind: byte 1 -> pause p1
;; (continuation s1); byte 2 at s1 -> stop. EOF at entry -> pause pe
;; (continuation done, a finish node). Inlined rather than imported --
;; (byte-machine test pause-machine) is the source of truth for this graph
;; (kept in sync by hand); the compile lanes carry no fixture libraries
;; (as with eof-fin above), and this file's charter is the rendered
;; TEXT (see the header), not execution -- the CORE_COMPILE manifest carries no
;; runtime.sls, so a compile+eval case cannot even load the generated library
;; here. The pause/resume execution walks live in the CORE_EMIT lanes.
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
;; Both emitter decisions -- which status a pause arm emits, and which
;; state it parks on -- live in that ONE line, and a `check` over a substring
;; probe reports the same content-blind "expected a true value" for either, so
;; the mutation suite could not tell the two mutations apart. Splitting the
;; probe in two does not separate them either: a pause
;; continuation is a dispatch node whose own need-input arm parks on that same
;; state id, so the " pos #f 2 off))" tail survives the next-state mutation
;; elsewhere in the rendered text and a target-only probe would be vacuous.
;; Comparing the two extracted fields with check-equal puts them in the
;; failure detail instead, so each decision has its own signature. This is
;; still search-only over the rendered text (see the header): two tokens read out
;; of one known line, never a re-parse of the emitted library.
(define (pause-arm-fields line)
  (let loop ((fs (harness-split line #\space)) (acc '()))
    (cond ((null? fs) (reverse acc))
          ((string=? (car fs) "") (loop (cdr fs) acc))
          (else (loop (cdr fs) (cons (car fs) acc))))))
(define (pause-arm st)
  (let ((head (string-append "(define (%s" (number->string st)
                             " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote ")))
    (let loop ((lines (harness-split (pause-text) #\newline)))
      (cond
        ((null? lines) "no such arm")
        ((harness-string-contains? (car lines) head)
         ;; ("(define" "(%s1" "pos" "st" "off" "pk)"
         ;;  "(byte-machine-make-feed-outcome/v1" "(quote" "paused)" "pos" "#f"
         ;;  "2" "off))") -- the six-field define header precedes the outcome
         ;; call, so the status is field 8 and the next state is field 11, the
         ;; one before "off))". Any other shape is reported
         ;; whole rather than indexed into, so a mutation that changes the
         ;; arm's arity fails the comparison instead of raising.
         (let ((fields (pause-arm-fields (car lines))))
           (if (= (length fields) 13)
               (string-append (substring (list-ref fields 8) 0
                                         (- (string-length (list-ref fields 8)) 1))
                              " " (list-ref fields 11))
               (harness-join fields " "))))
        (else (loop (cdr lines)))))))

;; The rest of a rendered error arm's line after its fixed head, which ends at
;; the errs index -- "1) (quote reject) 2 off pk) 2 off))" for
;;   (define (%s2 pos st off pk) (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 1) (quote reject) 2 off pk) 2 off))
;;
;; Two emitter decisions live in that tail: which errs entry the arm indexes,
;; and that the source-node name is rendered under quote. A `check` over a
;; substring probe reports the same content-blind "expected a true value" for a
;; wrong index and for an unquoted name, so the mutation suite could not tell
;; the two apart. Comparing the tail with check-equal puts the arm's own text
;; in the failure detail. The head is matched whole, so the comparison covers
;; every token the substring probe did. Search-only, like `pause-arm`: one
;; known line, never a re-parse of the emitted library.
(define (string-index-of s needle)
  (let ((n (string-length s)) (m (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring s i (+ i m)) needle) i)
            (else (loop (+ i 1)))))))
(define (error-arm st)
  (let ((head (string-append "(define (%s" (number->string st)
                             " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote error) pos"
                             " (byte-machine-make-parser-error/v1 (vector-ref errs ")))
    (let loop ((lines (harness-split (text) #\newline)))
      (cond
        ((null? lines) "no such arm")
        ((string-index-of (car lines) head)
         => (lambda (at)
              (substring (car lines) (+ at (string-length head)) (string-length (car lines)))))
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
        ;; The constructor's name carries no version; the ABI version NUMBER is
        ;; its first argument. The trailing quoted vector is the growable
        ;; payload: a vector OF members rather than a bare #(), because an
        ;; empty vector has no member 0, so a member can be filled without
        ;; changing the payload's shape. Member 0 is the field table, member 1
        ;; the callback table, both empty here; member 2 is the state-id to
        ;; source-name table `parser-state-name` reads, which is never empty. So
        ;; a zero-field machine renders #(#() #() #(<its state names>)).
        (check "unversioned call"
               (has? "(byte-machine-make-compiled-machine 9 14095574568398596535 0 exec (quote #(#() #() #(start stop reject))))"))
        (check "no versioned name survives"
               (not (has? "byte-machine-make-compiled-machine/v")))))
    ;; Member 0 is non-empty for a machine that DECLARES fields, and exactly
    ;; `#()` for one that does not -- which is why the case above passes for
    ;; the zero-field machine.
    ;;
    ;; It carries (name . initial) PAIRS rather than bare initials, though the
    ;; member is named for the initials. The parser needs two things from the
    ;; declarations -- the initial values, and the name-to-slot resolution
    ;; `parser-field-ref` answers by -- and the slot is the pair's POSITION, so
    ;; one member carries both and still renders `#()` when there are no fields.
    ;; A second member for field data would be a second ABI growth for data the
    ;; first already determines. Member 1 (the callback table, empty here) is
    ;; the `#()` that follows member 0 in the expectation below.
    (harness-case "a field-declaring machine renders its declarations in member 0"
      (lambda ()
        (check "pairs in slot order"
               (harness-string-contains?
                (utf8->string (render-machine (compile-machine with-fields '())
                                              'field-parser))
                "exec (quote #(#((count . 0) (limit . 65535)) #() #(start stop reject)))"))))
    (harness-case "exec carries its three reserved parameters"
      (lambda ()
        ;; `fieldv`, `psr` and `cbv` are part of every machine's exec signature,
        ;; including machines that declare no fields or callbacks: a parameter
        ;; added to some machines only would change the emitted text of every
        ;; machine the feature never touches.
        ;;
        ;; This is the only assertion in this lane that names the parameter
        ;; list as TEXT, and the witness that runs in the SPEC lane of the
        ;; mutation that pins it. The committed goldens carry the same line,
        ;; and the determinism lanes compare them byte for byte.
        (check "the full parameter list"
               (has? "(define (exec state offset bv start end finish? fieldv psr cbv)"))))
    (harness-case "the accepted byte advances and the fallback reexecutes"
      (lambda ()
        ;; A transition is a direct tail call to the target state's procedure,
        ;; so the target appears TWICE: once as the callee and once as the `st`
        ;; it is called with. Both are checked -- a mutation that changed only
        ;; the callee would otherwise leave a well-formed call to the wrong
        ;; state carrying the right id.
        ;; A byte class is rendered as range clauses, so a single accepted
        ;; byte is an equality clause rather than a `case` datum.
        (check "advance arm" (has? "((fx=? b 0) (%s1 (+ pos 1) 1 (+ off 1) (quote boundary)))"))
        (check "fallback"    (has? "(else (%s2 pos 2 off (quote byte)))"))
        (check "the state is a procedure, not a case arm"
               (has? "(define (%s0 pos st off pk)"))))
    (harness-case "the error state emits the resolved code"
      (lambda ()
        (check-equal "error arm" (error-arm 2) "1) (quote reject) 2 off pk) 2 off))")
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
    ;; reserved-member-2 membership check specifically (Pass 36).
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


;; --- the structural witness for the counted consume's bulk read -------------
;;
;; "counted consume does not dispatch once per body byte" is a claim about the
;; emitted STRUCTURE, and no behavioural lane can see it: a per-byte self-loop
;; consumes the same bytes, reads the same field and returns the same tuple. So
;; the rendered library is read back as a datum (the technique
;; member3-drift-tests.sps uses), the counted state's arm is located by its
;; id, and the arm is asserted to contain exactly one `min` application and no
;; `(+ pos 1)` form.
(define cc-witness
  (make-machine 'ccw 'start (list (make-uint-field 'len 8 3 #f)) '() '()
                (list eof-decl rej-decl)
                (list (make-byte-dispatch-node 'start
                        (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'body 'advance) #f))
                        (make-edge 'reject 'reexecute) #f #f)
                      (make-counted-consume-node 'body 'len 'stop #f #f)
                      (make-stop-node 'stop #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f))
(define cc-datum
  (read (open-string-input-port
         (utf8->string (render-machine (compile-machine cc-witness '()) 'ccw-parser)))))

;; The emitted exec defines one procedure per state; find `(define (%s<id> ...))`.
;; Node order is state order, so `body` is state 1. The `%dispatch` procedure
;; CALLS every `%s<id>` but defines none of them, so keying on the define form
;; cannot match there -- which matters, since a call site would otherwise be
;; returned as though it were the arm and every count below would read zero.
(define (find-state-arm x id)
  (let ((want (string->symbol (string-append "%s" (number->string id)))))
    (let walk ((x x))
      (cond ((not (pair? x)) #f)
            ((and (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                  (eq? (car (cadr x)) want))
             x)
            (else (or (walk (car x)) (walk (cdr x))))))))
(define (count-forms x pred)
  (cond ((not (pair? x)) 0)
        (else (+ (if (pred x) 1 0) (count-forms (car x) pred) (count-forms (cdr x) pred)))))
;; An emitted arm's outcome `cond`, as its list of clauses: the first `cond`
;; whose first clause tests `eqv?`, which is a target test and nothing else in
;; the emitted text is. #f when the arm has no such cond, which is what the
;; caller's found-it guard reports.
(define (find-goto-clauses arm)
  (let walk ((x arm))
    (cond ((not (pair? x)) #f)
          ((and (eq? (car x) 'cond) (pair? (cdr x)) (pair? (cadr x))
                (pair? (car (cadr x))) (eq? (car (car (cadr x))) 'eqv?))
           (cdr x))
          (else (or (walk (car x)) (walk (cdr x)))))))

(harness-group "the counted arm consumes in bulk (a structural witness)"
  (lambda ()
    (harness-case "the emitted arm applies min exactly once and never advances by one"
      (lambda ()
        (let ((arm (find-state-arm cc-datum 1)))
          (check "the counted state's arm was found" (and arm #t))
          (when arm
            (check-equal "exactly one min" (count-forms arm (lambda (f) (eq? (car f) 'min))) 1)
            (check-equal "no per-byte advance"
                         (count-forms arm (lambda (f) (equal? f '(+ pos 1)))) 0)))))))

;; --- a callback's goto target is drawn from a known set ---------------------
;;
;; A callback answers `goto TARGET`. Handing that target to `%dispatch` would
;; pay a search over every state id. The target is not known until the
;; callback returns, but the SET it
;; is drawn from is: the runtime's seam can only answer the node's continue
;; target, one of its declared branch targets, or its default, and the emitter
;; renders all three as literals into that very call. So the arm can test the
;; literals it already wrote and call the state procedure directly.
;;
;; The witness declares three DISTINCT goto targets -- a continue, and two
;; branches, the second of which is also the unbound default -- so the
;; assertion is over a set and not over one id repeated three times. Its pause
;; continuation is a fourth state that is NOT a goto target, so a clause for it
;; would be wrong rather than merely redundant.
(define (gt-one-byte-node name)
  (make-byte-dispatch-node name
    (list (make-byte-case (make-exact-byte-matcher 65) (make-edge 'gt-done 'advance) #f))
    (make-edge 'gt-reject 'reexecute) #f #f))
;; Node order is state order: start 0, go-cont 1, go-a 2, go-b 3, go-pause 4.
(define gt-witness
  (make-machine 'gtw 'start '()
    (list (make-callback-declaration 'pick 'decision #f '(a b) 'b #f))
    '()
    (list eof-decl rej-decl)
    (list (make-callback-node 'start 'pick 'go-cont '((a go-a) (b go-b)) 'go-pause #f)
          (gt-one-byte-node 'go-cont)
          (gt-one-byte-node 'go-a)
          (gt-one-byte-node 'go-b)
          (gt-one-byte-node 'go-pause)
          (make-stop-node 'gt-done #f)
          (make-error-node 'gt-reject 'rejected #f))
    'default-eof #f))
(define gt-datum
  (read (open-string-input-port
         (utf8->string (render-machine (compile-machine gt-witness '()) 'gtw-parser)))))
;; A direct jump to state `id`: the zero-width shape every arm of this kind
;; renders -- same pos, same off, same pk, with the id as the new state.
(define (gt-direct-jump id)
  (list (string->symbol (string-append "%s" (number->string id)))
        'pos id 'off 'pk))
(define (gt-count-jumps arm id)
  (count-forms arm (lambda (f) (equal? f (gt-direct-jump id)))))

(harness-group "a callback's goto target is chosen from a set known at emit time"
  (lambda ()
    (harness-case "the arm jumps directly to every target the node declares"
      (lambda ()
        (let ((arm (find-state-arm gt-datum 0)))
          (check "the callback state's arm was found" (and arm #t))
          (when arm
            ;; continue, and the two branch targets. The default resolves to
            ;; branch `b`, so the SET has three members and not four.
            (check-equal "one direct jump to the continue target" (gt-count-jumps arm 1) 1)
            (check-equal "one direct jump to branch a" (gt-count-jumps arm 2) 1)
            (check-equal "one direct jump to branch b, which is also the default"
                         (gt-count-jumps arm 3) 1)))))
    (harness-case "the pause continuation is not a goto clause"
      (lambda ()
        ;; State 4 is reachable only by parking on a pause, which leaves the
        ;; feed rather than jumping. A clause for it would route a `goto` the
        ;; runtime cannot answer.
        (let ((arm (find-state-arm gt-datum 0)))
          (when arm
            (check-equal "no direct jump to the pause continuation"
                         (gt-count-jumps arm 4) 0)))))
    (harness-case "the continue target is tested first"
      (lambda ()
        ;; The clauses are a linear scan, so their ORDER is the optimization:
        ;; a bound callback answering `continue` is the overwhelmingly common
        ;; outcome and must not pay for the branch keys ahead of it.
        (let* ((arm (find-state-arm gt-datum 0))
               (cl (and arm (find-goto-clauses arm))))
          (check "the goto arm renders a clause list" (pair? cl))
          (when (pair? cl)
            (check-equal "the first clause jumps to the continue target"
                         (cadr (car cl)) (gt-direct-jump 1))))))
    (harness-case "%dispatch survives as the clause no construction reaches"
      (lambda ()
        ;; Kept, not deleted: the fallback is what makes the clause list an
        ;; optimization of a total function rather than a claim about which
        ;; targets the runtime can answer.
        (let ((arm (find-state-arm gt-datum 0)))
          (when arm
            (check-equal "exactly one %dispatch in the arm"
                         (count-forms arm (lambda (f) (eq? (car f) '%dispatch))) 1)))))))

;; --- the no-declared-name structural witness --------------------------------
;;
;; NO declared name becomes a generated identifier. Over an every-construct
;; machine (all fourteen node kinds, a span with a complete callback so the
;; span-completion arm fires) hand-built in this file's style, because the
;; compile lane has neither the generator nor the printer. Its totality is a
;; DERIVED row against the emitter's arms.
(define w910-source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r ""))) r
        (assertion-violation 'compile-910 "BYTE_MACHINE_SOURCE_ROOT is unset" r))))
(define w910
  (make-machine 'ecw 'n-fa
    (list (make-uint-field 'fld 8 0 #f))
    (list (make-callback-declaration 'dc 'decision #t '(a b) #f #f)
          (make-callback-declaration 'sd 'span-data #t '() #f #f)
          (make-callback-declaration 'sc 'span-complete #t '() #f #f))
    (list (make-span-declaration 'sp 'sd 'sc #f))
    (list eof-decl rej-decl)
    (list
      (make-field-action-node 'n-fa 'store '(fld 1) 'n-fb #f #f)
      (make-field-branch-node 'n-fb 'zero '(fld) 'n-ss 'n-ss #f)
      (make-span-start-node 'n-ss 'sp 'n-bd #f)
      (make-byte-dispatch-node 'n-bd
        (list (make-byte-case (make-exact-byte-matcher 65) (make-edge 'n-se 'advance) #f))
        (make-edge 'n-se 'advance) #f #f)
      (make-span-end-node 'n-se 'sp 'n-sd #f)
      (make-sequence-dispatch-node 'n-sd
        (list (make-sequence-case '(66 67) 'n-cc #f))
        (make-edge 'n-stop 'advance) 'n-fin #f)
      (make-counted-consume-node 'n-cc 'fld 'n-kw 'n-fin #f)
      (make-keyword-table-node 'n-kw
        (list (make-keyword-entry '(68) 'n-acc #f))
        (make-edge 'n-err 'reexecute) 'n-fin #f #f)
      (make-integer-accumulate-node 'n-acc 'fld 10 'n-acc (make-edge 'n-pause 'reexecute) 'n-err 'n-fin #f)
      (make-pause-node 'n-pause 'n-cb #f)
      (make-callback-node 'n-cb 'dc 'n-err '((a n-err) (b n-err)) 'n-err #f)
      (make-stop-node 'n-stop #f)
      (make-finish-node 'n-fin #f)
      (make-error-node 'n-err 'rejected #f))
    'default-eof #f))
(define w910-binding 'ecw-parser)
(define w910-name 'ecw)                 ; the machine's own name -> the library name element
(define w910-lib
  (read (open-string-input-port
         (utf8->string (render-machine (compile-machine w910 '()) w910-binding)))))
(define (w910-occurs? nm x)
  (cond ((pair? x) (or (w910-occurs? nm (car x)) (w910-occurs? nm (cdr x))))
        ((vector? x) (w910-occurs? nm (vector->list x)))
        (else (eq? x nm))))
(define (w910-any-node? pred) (exists pred (machine-nodes w910)))
;; a span-end whose span declares a complete callback -> the span-completion arm.
(define (w910-has-span-completion?)
  (exists (lambda (n)
            (and (span-end-node? n)
                 (exists (lambda (s) (and (eq? (span-declaration-name s) (span-end-node-span n))
                                          (span-declaration-complete-callback s)))
                         (machine-spans w910))))
          (machine-nodes w910)))
;; the declared names of the witness (node/field/callback/span/error names).
(define w910-declared
  (append (map node-name (machine-nodes w910))
          '(fld dc sd sc sp default-eof rejected)))

;; --- reading compile.sls's render-state-arm keys (derived) ---
(define compile-src
  (call-with-input-file (string-append w910-source-root "/byte-machine/compile.sls") read))
(define (find-defn x name)
  (cond ((and (pair? x) (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x)) (eq? (car (cadr x)) name)) x)
        ((pair? x) (or (find-defn (car x) name) (find-defn (cdr x) name)))
        (else #f)))
(define (find-kind-case x)
  (cond ((and (pair? x) (eq? (car x) 'case) (pair? (cdr x)) (equal? (cadr x) '(normal-state-kind s))) x)
        ((pair? x) (or (find-kind-case (car x)) (find-kind-case (cdr x))))
        (else #f)))
(define emitter-keys
  (let* ((rsa (find-defn compile-src 'render-state-arm))
         (kc (and rsa (find-kind-case rsa))))
    (if kc (apply append (map car (filter (lambda (cl) (pair? (car cl))) (cddr kc)))) '())))
;; the hand-written key -> "the witness exercises this arm" map (the operand
;; a derived row compares against; a table read from the artifact would compare it
;; to itself). Set-equal to emitter-keys, so a fourteenth emitter arm reddens.
(define key->present
  (list (cons 'stop            (lambda () (w910-any-node? stop-node?)))
        (cons 'error           (lambda () (w910-any-node? error-node?)))
        (cons 'finish          (lambda () (w910-any-node? finish-node?)))
        (cons 'pause           (lambda () (w910-any-node? pause-node?)))
        (cons 'accumulate      (lambda () (w910-any-node? integer-accumulate-node?)))
        (cons 'field-action    (lambda () (w910-any-node? field-action-node?)))
        (cons 'field-branch    (lambda () (w910-any-node? field-branch-node?)))
        (cons 'callback        (lambda () (w910-any-node? callback-node?)))
        (cons 'span-start      (lambda () (w910-any-node? span-start-node?)))
        (cons 'span-end        (lambda () (w910-any-node? span-end-node?)))
        (cons 'span-completion  w910-has-span-completion?)
        (cons 'counted-consume (lambda () (w910-any-node? counted-consume-node?)))
        (cons 'keyword-table   (lambda () (w910-any-node? keyword-table-node?)))
        (cons 'dispatch        (lambda () (or (w910-any-node? byte-dispatch-node?)
                                              (w910-any-node? sequence-dispatch-node?))))))

;; --- the identifier-position walk (member3-drift-tests.sps's technique) ---
(define (symbols-outside-quote x acc)
  (cond ((symbol? x) (if (memq x acc) acc (cons x acc)))
        ((pair? x)
         (cond ((eq? (car x) 'quote) acc)
               ((and (eq? (car x) 'case) (pair? (cdr x)))
                (let cloop ((cs (cddr x)) (a (symbols-outside-quote (cadr x) acc)))
                  (if (not (pair? cs)) a
                      (cloop (cdr cs) (symbols-outside-quote (cdr (car cs)) a)))))
               (else (symbols-outside-quote (cdr x) (symbols-outside-quote (car x) acc)))))
        ((vector? x) (symbols-outside-quote (vector->list x) acc))
        (else acc)))
(define w910-identifiers (symbols-outside-quote w910-lib '()))
(define w910-structural '(library import export generated rnrs byte-machine runtime))
(define (subtract xs ys) (filter (lambda (x) (not (memq x ys))) xs))
;; Subtract the TEMPLATE only -- the (rnrs) and (byte-machine runtime) environments,
;; reserved-member-3 (the exec's own locals), and the library-form words -- leaving
;; exactly the output binding and the machine name, and NO declared name.

;; THE STATE PROCEDURES AND THEIR DISPATCHER CARRY AN UNFORGEABLE PREFIX.
;; The emitted body binds `%s<id>` for every state and one `%dispatch`, and
;; they are deliberately NOT in reserved-member-3: a machine's state count has
;; no bound, so the list could not enumerate them. What keeps them safe is the
;; prefix. `portable-name?` admits `[a-z][a-z0-9-]*` and nothing else, so no
;; output binding and no declared name can begin with `%`, and the collision
;; reserved-member-3 exists to prevent is impossible by construction rather
;; than by enumeration.
;;
;; Subtracting them is therefore sound -- but subtracting a whole PREFIX is a
;; hole in a guard whose entire job is to notice new emitter locals, so the
;; case below closes it: every name subtracted here is asserted to be one the
;; emitter is known to emit AND to be unforgeable. A future local introduced
;; without the prefix lands in the leftover and still fails; one introduced
;; WITH the prefix but under a new spelling fails the shape check.
(define (emitter-private? sym)
  (let ((s (symbol->string sym)))
    (and (> (string-length s) 0) (char=? (string-ref s 0) #\%))))
(define (state-procedure-name? sym)
  (let ((s (symbol->string sym)))
    (and (> (string-length s) 2)
         (char=? (string-ref s 0) #\%)
         (char=? (string-ref s 1) #\s)
         (let loop ((i 2))
           (or (>= i (string-length s))
               (and (char<=? #\0 (string-ref s i)) (char<=? (string-ref s i) #\9)
                    (loop (+ i 1))))))))

(define w910-private (filter emitter-private? w910-identifiers))
(define w910-leftover
  (filter (lambda (sym) (not (emitter-private? sym)))
          (subtract (subtract (subtract (subtract w910-identifiers
                                                  (environment-symbols (environment '(rnrs))))
                                        (environment-symbols (environment '(byte-machine runtime))))
                              reserved-member-3)
                    w910-structural)))

(harness-group "the every-construct witness exercises every emitter arm"
  (lambda ()
    (harness-case "the derived row: render-state-arm's keys equal the covered kinds"
      (lambda ()
        ;; found-it guards first: a reader returning #f would compare two empties.
        (check "render-state-arm's kind case was found in compile.sls" (pair? emitter-keys))
        (check-equal "the emitter has fourteen state-kind arms" (length emitter-keys) 14)
        (check "the witness rendered to a generated library form"
               (and (pair? w910-lib) (eq? (car w910-lib) 'library)))
        ;; the hand-written map's keys set-equal the emitter's keys.
        (check "every emitter key is in the hand-written coverage map"
               (for-all (lambda (k) (assq k key->present)) emitter-keys))
        (check "the coverage map names no key the emitter lacks"
               (for-all (lambda (kv) (memq (car kv) emitter-keys)) key->present))
        ;; and the witness exercises each.
        (check "the witness exercises every emitter arm"
               (for-all (lambda (kv) ((cdr kv))) key->present))))))

(harness-group "no declared name reaches identifier position"
  (lambda ()
    (harness-case "the subtracted emitter-private names are unforgeable, and only the two known shapes"
      (lambda ()
        ;; A found-it guard first: with no private names the two checks below
        ;; would pass over an empty list and say nothing at all.
        (check "the emitted body binds emitter-private names" (pair? w910-private))
        (check "every one of them is a state procedure or the dispatcher"
               (for-all (lambda (sym)
                          (or (state-procedure-name? sym) (eq? sym (quote %dispatch))))
                        w910-private))
        ;; The safety property itself, not a restatement of the spelling: none
        ;; of these can be written as a declared name or an output binding.
        (check "no declared name or output binding could collide with one"
               (for-all (lambda (sym) (not (portable-name? sym))) w910-private))))
    (harness-case "the identifier-position set is exactly the output binding and the machine name"
      (lambda ()
        (check "the emitted library binds identifiers at all" (> (length w910-identifiers) 20))
        (check-equal "after subtracting the template, only the binding and the machine name remain"
                     (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) w910-leftover)
                     (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                                (list w910-binding w910-name)))))
    (harness-case "every declared name that occurs, occurs only under quote"
      (lambda ()
        ;; the walk is over the names that OCCUR, not over all declared names: an
        ;; error-declaration name never reaches the emitted text (only its code and
        ;; reason do), so an occurrence check over all declared names would be
        ;; vacuous for the error names. A found-it guard: some declared name
        ;; occurs somewhere in the datum (under quote), so this is not vacuous.
        (let ((occurring (filter (lambda (nm) (w910-occurs? nm w910-lib)) w910-declared)))
          (check "at least one declared name occurs in the emitted datum" (pair? occurring))
          (check "no occurring declared name is in identifier position"
                 (for-all (lambda (nm) (not (memq nm w910-identifiers))) occurring)))))))

;; --- the feed entry is a search, not a scan ---------------------------------
;;
;; `%dispatch`'s target is the one that genuinely cannot be a literal: the
;; state comes from the parser. What it need not be is linear. A
;; byte-at-a-time parse re-enters it once per feed and a keyword table jumps
;; through it, so on a large machine a linear scan here would be the single
;; largest per-feed cost.
;;
;; The assertion is the PROPERTY, not the shape: no state is reached by more
;; comparisons than a balanced tree over the state count needs. A scan would
;; put the last state at N tests and fail this at any N above the bound; a tree
;; that grew lopsided -- a midpoint computed wrongly, say -- would fail it too,
;; which a shape check on the emitted text would not catch.
;;
;; Measured over the every-construct witness (14 states) and the counted
;; witness (4), because the bound is a function of the state count and a single
;; size cannot tell `<= ceil(log2 N) + 1` from a constant that happens to fit.
(define (ceil-log2 n)
  (let loop ((bits 0) (v 1)) (if (>= v n) bits (loop (+ bits 1) (* v 2)))))
;; Every `(%s<id> pos st off pk)` call in `x`, with the number of enclosing
;; `if` tests on the path to it. `%dispatch`'s body is all `if`, so counting
;; them IS counting comparisons.
(define (dispatch-depths x)
  (let walk ((x x) (d 0) (acc '()))
    (cond ((not (pair? x)) acc)
          ((and (symbol? (car x)) (state-procedure-name? (car x))
                (equal? (cdr x) '(pos st off pk)))
           (cons (cons (car x) d) acc))
          ((eq? (car x) 'if)
           ;; the test contributes no depth; the two arms are one test deeper.
           (walk (cadddr x) (+ d 1) (walk (caddr x) (+ d 1) (walk (cadr x) d acc))))
          (else (walk (cdr x) d (walk (car x) d acc))))))
(define (find-dispatch x)
  (let walk ((x x))
    (cond ((not (pair? x)) #f)
          ((and (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                (eq? (car (cadr x)) '%dispatch))
           x)
          (else (or (walk (car x)) (walk (cdr x)))))))
(define (count-states x)
  (let walk ((x x) (n 0))
    (cond ((not (pair? x)) n)
          ((and (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                (symbol? (car (cadr x))) (state-procedure-name? (car (cadr x))))
           (+ n 1))
          (else (walk (cdr x) (walk (car x) n))))))

(harness-group "the feed entry dispatch is a search, not a scan"
  (lambda ()
    (harness-case "every state is reachable from the dispatch, exactly once"
      (lambda ()
        ;; A tree that dropped or duplicated a leaf would route a live state to
        ;; its neighbour, which no fixture need notice; this is what makes the
        ;; depth bound below a statement about a TOTAL function.
        (for-each
         (lambda (lib)
           (let* ((d (find-dispatch lib))
                  (ds (and d (dispatch-depths d)))
                  (n (count-states lib)))
             (check "the dispatch was found" (and d #t))
             (when d
               (check-equal "one leaf per state" (length ds) n)
               (check "no state appears twice"
                      (let dup ((xs (map car ds)))
                        (cond ((null? xs) #t)
                              ((memq (car xs) (cdr xs)) #f)
                              (else (dup (cdr xs)))))))))
         (list w910-lib cc-datum))))
    (harness-case "no state is more than a balanced tree deep"
      (lambda ()
        ;; ceil(log2 N) for the tree, plus one for the in-range guard.
        (for-each
         (lambda (lib)
           (let* ((d (find-dispatch lib))
                  (ds (and d (dispatch-depths d)))
                  (n (count-states lib))
                  (bound (+ (ceil-log2 n) 1)))
             (when (and d (pair? ds))
               (check-equal (string-append "deepest leaf within the bound for "
                                           (adapter-value->string n) " states")
                            (apply max (map cdr ds)) bound))))
         (list w910-lib cc-datum))))
    (harness-case "an unknown state is still refused"
      (lambda ()
        ;; The in-range guard. A search with no bound check answers SOME state
        ;; for every integer, which is worse than a linear scan with an
        ;; else arm.
        (let ((d (find-dispatch w910-lib)))
          (when d
            (check-equal "exactly one unknown-state refusal"
                         (count-forms d (lambda (f)
                                          (and (eq? (car f) 'assertion-violation)
                                               (member "unknown state" f))))
                         1)))))))

(harness-finish)
