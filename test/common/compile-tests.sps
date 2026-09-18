;;; The emitter compiles, renders, and emits the one-byte machine, and validates
;;; its options and output binding. Structure of the rendered text is asserted by
;;; substring (the generated parser's behaviour is proven end-to-end in the
;;; differential and example lanes). Rendered bytes are decoded with utf8->string
;;; only to search them — never to compare against implementation `write` output.
(import (rnrs)
        (rnrs eval)
        ;; environment-symbols is a Chez extension (member3-drift-tests.sps's import);
        ;; the §16.2:910 witness below subtracts the (rnrs) and (byte-machine runtime)
        ;; environments from the emitted identifiers. (byte-machine runtime) is
        ;; imported statically so the AOT lane compiles it (reserved-drift's surprise).
        (only (chezscheme) environment-symbols)
        (only (byte-machine private names) portable-name?)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine runtime)
        ;; ir's reading accessors graph does not re-export -- the §16.2:910 witness
        ;; walks the witness machine's nodes. The names graph DOES re-export (e.g.
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

;; Slice ①b task 6: the same one-byte machine with two field declarations.
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
  (let ((head (string-append "(define (%s" (number->string st)
                             " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote ")))
    (let loop ((lines (harness-split (pause-text) #\newline)))
      (cond
        ((null? lines) "no such arm")
        ((harness-string-contains? (car lines) head)
         ;; ("(define" "(%s1" "pos" "st" "off" "pk)"
         ;;  "(byte-machine-make-feed-outcome/v1" "(quote" "paused)" "pos" "#f"
         ;;  "2" "off))") -- the six-field define header precedes what used to
         ;; be the whole line, so the status is field 8 and the next state is
         ;; field 11, still the one before "off))". Any other shape is reported
         ;; whole rather than indexed into, so a mutation that changes the
         ;; arm's arity fails the comparison instead of raising.
         (let ((fields (pause-arm-fields (car lines))))
           (if (= (length fields) 13)
               (string-append (substring (list-ref fields 8) 0
                                         (- (string-length (list-ref fields 8)) 1))
                              " " (list-ref fields 11))
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
        ;; Decision 0018: the versioned NAME is retired and the version NUMBER
        ;; survives; 0018 moved it to 3. The trailing quoted vector is the
        ;; growable payload. The payload is a vector OF members rather than a
        ;; bare #() because an empty vector has no member 0 -- Milestone 4 ①b
        ;; would have had to add one, moving every golden in the slice whose
        ;; headline invariant is that none moves.
        ;;
        ;; Milestone 5 Slice ①a (decision 0025 point 2) moves the version to 4
        ;; and grows the payload with a second member, reserved empty. Slice ②
        ;; moves it to 5 and adds member 2, §17:963's state-id to source-name
        ;; table -- which is not reservable-empty, because it is what
        ;; `parser-state-name` reads. The version literal has since moved to 6
        ;; (Milestone 11, the keyword-step op) and to 7 (Milestone 12, the pause
        ;; reason in the outcome), while the 3-member payload is unchanged -- so
        ;; the literal reads 7 and a zero-field machine renders
        ;; #(#() #() #(<its state names>)).
        (check "unversioned call"
               (has? "(byte-machine-make-compiled-machine 8 14095574568398596535 0 exec (quote #(#() #() #(start stop reject))))"))
        (check "no versioned name survives"
               (not (has? "byte-machine-make-compiled-machine/v")))))
    ;; Milestone 4 Slice ①b task 6 (decision 0019 item 3(b)). Member 0 stops
    ;; being empty for a machine that DECLARES fields, and stays exactly `#()`
    ;; for one that does not -- which is the whole content of ①a's reservation
    ;; and the reason the case above still passes verbatim.
    ;;
    ;; It carries (name . initial) PAIRS rather than bare initials, though the
    ;; member is named for the initials. The parser needs two things from the
    ;; declarations -- the initial values, and the name-to-slot resolution
    ;; `parser-field-ref` answers by -- and the slot is the pair's POSITION, so
    ;; one member carries both and still renders `#()` when there are no fields.
    ;; A second member would have been a second ABI growth for data the first
    ;; already determines. That argument is about FIELD data and is NOT a
    ;; prohibition on further members: Milestone 5 Slice ①a adds member 1,
    ;; reserved empty (decision 0025 point 2), and it is the trailing `#()` in
    ;; the expectation below.
    (harness-case "a field-declaring machine renders its declarations in member 0"
      (lambda ()
        (check "pairs in slot order"
               (harness-string-contains?
                (utf8->string (render-machine (compile-machine with-fields '())
                                              'field-parser))
                "exec (quote #(#((count . 0) (limit . 65535)) #() #(start stop reject)))"))))
    (harness-case "exec carries its three reserved parameters"
      (lambda ()
        ;; `fieldv` was reserved empty by decision 0019 item 3(c) and filled in
        ;; Milestone 4 Slice ②. `psr` and `cbv` are Milestone 5 Slice ①a's, by
        ;; decision 0025 point 3, and are reserved the same way and for the same
        ;; reason: a parameter added LATER changes the emitted text of every
        ;; machine, including the ones the feature never touches, so the
        ;; widening is paid once before any arm needs it.
        ;;
        ;; This is the only assertion that names the parameter list as TEXT, and
        ;; the only witness that runs in the SPEC lane of the mutation that pins
        ;; it. It is NOT the only thing in the tree that would notice a change:
        ;; measured 2026-09-04, all four committed goldens carry the same line at
        ;; `:5`, and the determinism lanes compare them byte for byte. An earlier
        ;; draft of this comment claimed tree-wide uniqueness and was wrong --
        ;; the standing rule is that a novelty claim needs measuring, and the
        ;; measurement that produced it had searched the MUTATION declarations
        ;; only.
        (check "the full parameter list"
               (has? "(define (exec state offset bv start end finish? fieldv psr cbv)"))))
    (harness-case "the accepted byte advances and the fallback reexecutes"
      (lambda ()
        ;; A transition is a direct tail call to the target state's procedure,
        ;; so the target appears TWICE: once as the callee and once as the `st`
        ;; it is called with. Both are checked -- a mutation that changed only
        ;; the callee would otherwise leave a well-formed call to the wrong
        ;; state carrying the right id.
        ;; A byte class is rendered as range clauses now, so a single accepted
        ;; byte is an equality clause rather than a `case` datum.
        (check "advance arm" (has? "((fx=? b 0) (%s1 (+ pos 1) 1 (+ off 1) (quote boundary)))"))
        (check "fallback"    (has? "(else (%s2 pos 2 off (quote byte)))"))
        (check "the state is a procedure, not a case arm"
               (has? "(define (%s0 pos st off pk)"))))
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


;; --- Milestone 6 Slice ①: the structural witness for §25:1607 (design §4.7) -----
;;
;; "counted consume does not dispatch once per body byte" is a claim about the
;; emitted STRUCTURE, and no behavioural lane can see it: a per-byte self-loop
;; consumes the same bytes, reads the same field and returns the same tuple. So
;; the rendered library is read back as a datum (the technique member3-drift
;; ships), the counted state's `case` arm is located by its id, and the arm is
;; asserted to contain exactly one `min` application and no `(+ pos 1)` form.
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

(harness-group "the counted arm consumes in bulk (§25:1607, a structural witness)"
  (lambda ()
    (harness-case "the emitted arm applies min exactly once and never advances by one"
      (lambda ()
        (let ((arm (find-state-arm cc-datum 1)))
          (check "the counted state's arm was found" (and arm #t))
          (when arm
            (check-equal "exactly one min" (count-forms arm (lambda (f) (eq? (car f) 'min))) 1)
            (check-equal "no per-byte advance"
                         (count-forms arm (lambda (f) (equal? f '(+ pos 1)))) 0)))))))

;; --- Milestone 7 Slice ④: the §16.2:910 structural witness (design §4.8, F10) --
;;
;; §25:1617's discharge and §4.12 item 1's witness: NO declared name becomes a
;; generated identifier. Over an every-construct machine (all fourteen node kinds,
;; a span with a complete callback so the span-completion arm fires) hand-built in
;; this file's style, because the compile lane has neither the generator nor the
;; printer (F10). Its totality is a DERIVED row against the emitter's arms.
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

;; --- reading compile.sls's render-state-arm keys (Step 2, derived) ---
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
;; the hand-written key -> "the witness exercises this arm" map (S2/F4: the operand
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

;; --- the identifier-position walk (Step 3, member3-drift's technique) ---
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

(harness-group "the every-construct witness exercises every emitter arm (§16.2:910 totality, F10)"
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

(harness-group "no declared name reaches identifier position (§16.2:910, §25:1617)"
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
        ;; vacuous for the error names (§4.8). A found-it guard: some declared name
        ;; occurs somewhere in the datum (under quote), so this is not vacuous.
        (let ((occurring (filter (lambda (nm) (w910-occurs? nm w910-lib)) w910-declared)))
          (check "at least one declared name occurs in the emitted datum" (pair? occurring))
          (check "no occurring declared name is in identifier position"
                 (for-all (lambda (nm) (not (memq nm w910-identifiers))) occurring)))))))

(harness-finish)
