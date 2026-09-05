;;; (byte-machine compile): the offline emitter (parent §9.2, §19, §20;
;;; decisions 0008, 0009, 0010). compile-machine re-verifies internally and
;;; normalizes; render-machine renders the normalized IR to a complete importable
;;; R6RS .sls as a canonical UTF-8/LF bytevector (no implementation `write`);
;;; emit-machine writes those bytes to the supplied binary port only. The
;;; generated library imports only (rnrs) and (byte-machine runtime), owns the
;;; derived library name (generated <machine-name>), and defines the single
;;; caller-named compiled-machine binding through the one unversioned
;;; byte-machine-make-compiled-machine (decision 0018), whose first action is the
;;; ABI version check and whose trailing quoted vector is the growable payload.
;;; Pure but for emit-machine's port write.
(library (byte-machine compile)
  (export compile-machine compilation-ok? compilation-diagnostics
          render-machine emit-machine
          reserved-member-2 reserved-member-3) ; test-support: the drift guards read them
  (import (rnrs)
          (byte-machine verify)
          (only (byte-machine private ir) machine-name machine-errors
                error-declaration-code error-declaration-reason)
          (byte-machine private normal-ir))

  (define c-tag (vector 'byte-machine-compilation))
  ;; (vector c-tag ok? diagnostics machine normal) ; normal #f when not ok
  (define (make-compilation ok? diags machine normal) (vector c-tag ok? diags machine normal))
  (define (compilation-ok? c) (vector-ref c 1))
  (define (compilation-diagnostics c) (vector-ref c 2))
  (define (compilation-machine c) (vector-ref c 3))
  (define (compilation-normal c) (vector-ref c 4))

  (define (compile-machine machine options)
    (unless (null? options)
      (assertion-violation 'compile-machine "v0.1 accepts only the empty option list" options))
    (let ((v (verify-machine machine)))
      (if (verification-ok? v)
          (make-compilation #t '() (verification-machine v)
                            (normalize-machine (verification-machine v)))
          (make-compilation #f (verification-diagnostics v) (verification-machine v) #f))))

  ;; --- reserved-output-binding set (all three members now exist, design §3.3) ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  ;; The hand-maintained mirror of (byte-machine runtime)'s exports. Exported
  ;; solely so reserved-drift-tests.sps can assert it against the runtime's actual
  ;; environment-symbols: a new runtime export not added here would let the emitter
  ;; accept a binding that collides with it (Slice B; Slice A design §6).
  (define reserved-member-2
    '(make-compiled-machine compiled-machine?
      byte-machine-make-compiled-machine/v1 byte-machine-make-compiled-machine/v2
      byte-machine-make-feed-outcome/v1
      make-parser parser? parser-feed! parser-finish! parser-resume!
      parser-lifecycle parser-reset!
      parser-result? parser-result-status parser-result-next
      parser-result-consumed parser-result-stream-offset parser-result-error
      byte-machine-make-parser-error/v1 parser-error?
      parser-error-domain parser-error-code parser-error-reason
      parser-error-detail parser-error-node-name parser-error-state-id
      parser-error-offset parser-error-position-kind
      byte-machine-make-compiled-machine
      parser-field-ref
      callback-continue callback-pause
      ;; Milestone 5 Slice ①b's SEVEN new names: the five §9.3 owes -- design §6's
      ;; six minus `parser-state-name`, deferred whole to Slice ② -- plus
      ;; `callback-failure-code` and `callback-failure-detail`, which §9.3:415-416
      ;; does not list. Those two are accessors for a record §13:808 defines and
      ;; §9.3 gives a constructor and a predicate but no readers, so an
      ;; application could build a failure and never read it back. Recorded here
      ;; rather than exported silently; if the owner would rather §9.3 grow an
      ;; appended disposition naming them, that is the alternative.
      ;; This mirror is asserted by SET EQUALITY
      ;; against (byte-machine runtime)'s live exports, so it reddens in BOTH
      ;; directions and must move in the same commit the exports do -- the
      ;; obligation Slice ①a recorded for exactly this moment.
      parser-stream-offset parser-user-context parser-active-span
      make-callback-failure callback-failure?
      callback-failure-code callback-failure-detail))
  ;; Every identifier the emitted body binds, so a caller-chosen output binding
  ;; cannot collide with one. `fieldv` is emitted `exec`'s seventh parameter,
  ;; reserved empty by Milestone 4 Slice ①a and filled by its Slice ② (decision
  ;; 0019 item 3(c)); it is deliberately not spelled `fields`, which `(rnrs)`
  ;; binds as define-record-type's auxiliary keyword and which the drift guard's
  ;; own `(rnrs)` subtraction would therefore swallow.
  ;;
  ;; `psr` and `cbv` are the eighth and ninth, added by Milestone 5 Slice ①a
  ;; (decision 0025 point 3) and reserved the same way: the emitted body ignores
  ;; both, and Slice ② emits the arms that read them. `psr` is the parser a
  ;; callback receives as its first argument (§13:784) and BOTH call sites
  ;; already pass the real one -- there is no sentinel, because the value exists
  ;; and passing it now spares ② a second call-site edit. `cbv` is the resolved
  ;; callback slot vector and passes `empty-callbacks` until ①b binds one.
  (define reserved-member-3
    '(exec loop pos st off b bv start end state offset finish? fieldv errs pk
      v r d psr cbv))
  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-binding? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0) (lower-alpha? (string-ref s 0))
           (let loop ((i 1)) (or (>= i (string-length s))
                                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))
           (not (memq sym reserved-member-1))
           (not (memq sym reserved-member-2))
           (not (memq sym reserved-member-3)))))

  (define (validate-binding binding)
    (unless (symbol? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding))
    (unless (valid-binding? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding)))

  ;; --- canonical source writer ---
  ;; §20:1039's explicit escaping, for the one class of author-controlled text the
  ;; emitter writes into generated source: an error declaration's static reason,
  ;; carried by decision 0022 item 7's per-library `errs` table. `pass-names-valid`
  ;; refuses any reason outside printable ASCII plus LF (§10.1:480), so exactly
  ;; three characters can reach here needing an escape and the set is closed
  ;; rather than defensive. Its one caller is the `errs` table below.
  (define (escape-string s)
    (let loop ((i 0) (acc '()))
      (if (>= i (string-length s))
          (list->string (reverse acc))
          (let ((c (string-ref s i)))
            (loop (+ i 1)
                  (cond ((char=? c #\") (cons #\" (cons #\\ acc)))
                        ((char=? c #\\) (cons #\\ (cons #\\ acc)))
                        ((char=? c #\newline) (cons #\n (cons #\\ acc)))
                        (else (cons c acc))))))))

  ;; Each transition/fallback lowers to a loop tail: advance bumps pos and off,
  ;; reexecute keeps both. Rendered as one string with explicit, counted parens.
  ;;
  ;; The fourth argument is the POSITION KIND (decision 0022 item 5). It is a
  ;; property of the transition that ARRIVED, not of the error state: one error
  ;; node reached by a reexecute edge reports `byte` and the same node reached by
  ;; an advance edge reports `boundary`, and the emitted arm is keyed on state id
  ;; alone, so it cannot be a per-site literal there. Each jump therefore carries
  ;; its own kind forward.
  ;; *** Hazard for Slice ③: this helper's two rendered strings are each pinned
  ;; at SITES=1 across three shipped mutations. Re-inlining the tail, or
  ;; changing either string's text, is a CONFIGURE-TIME failure of the mutation
  ;; suite rather than a test failure -- "pattern occurs 0 times ... expected
  ;; 1". ③'s overflow tail wants to look like this one; extend it here rather
  ;; than writing a parallel renderer. ***
  (define (loop-tail target mode)
    (if (eq? mode 'advance)
        (string-append "(loop (+ pos 1) " (number->string target) " (+ off 1) (quote boundary))")
        (string-append "(loop pos " (number->string target) " off (quote byte))")))

  (define (render-transition-arm tr)
    ;; tr = (byte target mode) -> "((<byte>) <loop-tail>)"
    ;; Milestone 3 Slice ① changed nothing here, and that is a decision rather
    ;; than an oversight: byte classes lower to one transition per byte
    ;; (decision 0014), so a complement renders up to 256 sibling arms inside the
    ;; single `(case b ...)` below. §19.2:1009 asks for "canonical membership
    ;; code selected for simplicity, not speculative density optimization", and a
    ;; grouped datum list or a membership table is the optimization §29:1743
    ;; defers and §23.3:1369 gates behind compiled benchmarks that cannot exist
    ;; yet (`bench/` holds two .gitkeep files).
    (string-append "               ((" (number->string (car tr)) ") "
                   (loop-tail (cadr tr) (caddr tr)) ")\n"))

  ;; An exhausted dispatch (finish? #t) routes eof: to a named node's loop
  ;; (continue the eof-target chain) or to the machine default-eof error.
  ;; The node case is the EOF-chain hop and carries `eof` forward. The default
  ;; case is a terminal construction reached by no jump at all, so it takes a
  ;; per-site (quote eof) literal rather than the loop variable -- §12.7:771
  ;; fixes `eof` whether or not a prior hop ran. Its node-name is the DISPATCH
  ;; node's, which is where truncation was detected: a default-EOF error has no
  ;; error node of its own (decision 0022 item 9).
  (define (render-eof-branch eof id name reason index-of)
    (if (eq? (car eof) 'node)
        (string-append "(loop pos " (number->string (cdr eof)) " off (quote eof))")
        (string-append "(byte-machine-make-feed-outcome/v1 (quote error) pos "
                       "(byte-machine-make-parser-error/v1 (vector-ref errs "
                       (number->string (index-of (cdr eof) reason)) ") (quote " (symbol->string name)
                       ") " id " off (quote eof)) " id " off)")))

  ;; Milestone 3 Slice ② changed nothing here either, and that is decision 0015
  ;; point 1 rather than an oversight: a lowered sequence-prefix state IS an
  ;; ordinary normalized dispatch state, so it renders through this same arm, the
  ;; encoding gains no tag, and the need-input
  ;; resume point below gives cross-feed resumability with no new mechanism. No
  ;; new emitted local means reserved-member-3 (decision 0012 item 4) is
  ;; unchanged. That was true through Milestone 3 and is not true here: Slice ①a
  ;; adds `fieldv`, `errs` and `pk`, and the gap the second half of this sentence
  ;; named -- "no automated drift guard" -- is closed by
  ;; member3-drift-tests.sps, which walks the emitted datum for every symbol
  ;; outside a quote form and asserts the remainder is a subset of this list.
  ;; `names` maps a state id to its public source-node name (§17:963's debug
  ;; map, normalizer output) and `index-of` a (code, reason) pair to that
  ;; declaration's position in the errs table. The name is not recoverable from a
  ;; normalized state at all, and the declaration is not recoverable from its
  ;; code alone -- codes need not be unique -- so both are threaded in from
  ;; render-machine rather than derived here.
  ;; --- Slice ②'s two emitted arms ---
  ;; The arithmetic is written TWICE on purpose (§18:970-972, decision 0015
  ;; point 3): this is the emitter's copy and it shares no helper with
  ;; interpret.sls. Widths come from the NORMALIZED table here and from
  ;; `machine-fields` there, so a lowering bug in overflow checking stays visible
  ;; to the differential -- the single class of defect this milestone introduces.
  ;;
  ;; `render-state-arm` could not see the declarations at all, so `fields` is
  ;; threaded in: the normalized (name width initial slot) table.
  (define (field-slot-width fields name)
    (let loop ((fs fields))
      (cond ((null? fs)
             ;; Unreachable: pass 6a rejects an operand naming no declared field
             ;; before the emitter runs. Loud rather than a silent slot 0.
             (assertion-violation 'render-machine "no declared field for operand" name))
            ((eq? (car (car fs)) name) (cons (cadddr (car fs)) (cadr (car fs))))
            (else (loop (cdr fs))))))
  (define (num n) (number->string n))
  ;; A jump that consumes nothing: same `pos`, same `off`, same `pk`. The
  ;; position kind is carried THROUGH for the reason runtime.sls records at its
  ;; own zero-width arms -- a zero-width step does not move the parser in the
  ;; input, and §12.7:777 makes the two lanes' answers comparable.
  (define (zero-width-jump target)
    (string-append "(loop pos " (num target) " off pk)"))
  (define (render-operation op k)
    (case op
      ((store) (num k))
      ((clear) "0")
      ((increment) "(+ v 1)")
      ((decrement) "(- v 1)")
      ((add) (string-append "(+ v " (num k) ")"))
      ((set-mask) (string-append "(bitwise-ior v " (num k) ")"))
      ((clear-mask) (string-append "(bitwise-and v (bitwise-not " (num k) "))"))
      (else (assertion-violation 'render-machine "unknown field operation" op))))
  (define (render-predicate pred a b)
    (case pred
      ((equal) (string-append "(= v " (num a) ")"))
      ((zero) "(= v 0)")
      ((nonzero) "(not (= v 0))")
      ((range) (string-append "(and (<= " (num a) " v) (<= v " (num b) "))"))
      ((mask-any) (string-append "(not (= 0 (bitwise-and v " (num a) ")))"))
      ((mask-all) (string-append "(= " (num a) " (bitwise-and v " (num a) "))"))
      ((mask-none) (string-append "(= 0 (bitwise-and v " (num a) "))"))
      (else (assertion-violation 'render-machine "unknown field predicate" pred))))

  ;; The exhausted-input preamble every BYTE-CONSUMING emitted arm opens with:
  ;; at end of slice, take the EOF branch under finish? and yield need-input
  ;; otherwise. Shared by the dispatch arm and Slice ③'s accumulate arm, which
  ;; render it identically -- written out twice it takes every pin on it to two
  ;; sites, and no anchor separates them because the two preambles ARE the same
  ;; decision. Each arm's call stays its own line.
  (define (render-exhausted-preamble s id names index-of nm)
    (string-append
     "      ((" id ")\n"
     "       (if (>= pos end)\n"
     "           (if finish?\n"
     "               " (render-eof-branch (normal-dispatch-eof s) id
                                          (string->symbol (nm (normal-state-id s)))
                                          (normal-error-reason s) index-of) "\n"
     "               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off))\n"))

  (define (render-state-arm s names index-of fields)
    (let ((id (number->string (normal-state-id s)))
          ;; Total by construction: the debug map and the internal state list
          ;; are built from the same prefix-block id alists, so every id in
          ;; `states` has an entry. Loud rather than trusting that, because a
          ;; missing key would otherwise surface as `(cdr #f)` deep inside a
          ;; string-append with nothing naming the state.
          (nm (lambda (i)
                (let ((hit (assv i names)))
                  (unless hit
                    (assertion-violation 'render-machine
                                         "no source name for normalized state" i))
                  (symbol->string (cdr hit))))))
      (case (normal-state-kind s)
        ((stop)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f " id " off))\n"))
        ((error)
         ;; The record's five call-site arguments: the errs entry (code and
         ;; reason together), the public source-node name, the state id, the
         ;; absolute offset, and the loop's position-kind variable. Reading `pk`
         ;; rather than a literal is what lets one error node report `byte` when
         ;; a reexecute edge arrives and `boundary` when an advance edge does.
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote error) pos "
                        "(byte-machine-make-parser-error/v1 (vector-ref errs "
                        (number->string (index-of (normal-error-code s)
                                                  (normal-error-reason s))) ") (quote "
                        (nm (normal-state-id s)) ") " id " off pk) " id " off))\n"))
        ((finish)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote finished) pos #f " id " off))\n"))
        ((pause)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
                        (number->string (normal-pause-target s)) " off))\n"))
        ;; Slice ③'s INPUT-READING kind. The digit test is rendered as a range
        ;; comparison per base rather than a `case` over literal bytes: base 16
        ;; has three disjoint ASCII ranges, so one `case` group with one `d`
        ;; cannot express it (§8's own example contradicts its following
        ;; sentence). §15:864-868's inequality is rendered as the spec writes it
        ;; -- a check BEFORE the multiply-add, not a compute-then-check, because
        ;; §15:856 forbids relying on host fixnum width.
        ((accumulate)
         (let* ((base (normal-field-selector s))
                (fname (car (normal-field-arguments s)))
                (sw (field-slot-width fields fname))
                (slot (car sw)) (mx (- (expt 2 (cdr sw)) 1))
                (tg (normal-field-targets s))
                (digit (car tg)) (nd (cadr tg)) (over (caddr tg))
                (dexpr (if (= base 10)
                           "(and (>= b 48) (<= b 57) (- b 48))"
                           (string-append
                            "(cond ((and (>= b 48) (<= b 57)) (- b 48))"
                            " ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"
                            " ((and (>= b 65) (<= b 70)) (+ 10 (- b 65)))"
                            " (else #f))"))))
           (string-append
            (render-exhausted-preamble s id names index-of nm)
            "           (let* ((b (bytevector-u8-ref bv pos)) (d " dexpr "))\n"
            "             (if (not d)\n"
            "                 " (if (eq? (cdr nd) 'advance)
                                    (string-append "(loop (+ pos 1) " (num (car nd)) " (+ off 1) (quote boundary))")
                                    (string-append "(loop pos " (num (car nd)) " off (quote byte))")) "\n"
            "                 (let ((v (vector-ref fieldv " (num slot) ")))\n"
            "                   (if (<= v (div (- " (num mx) " d) " (num base) "))\n"
            "                       (begin (vector-set! fieldv " (num slot)
                                     " (+ (* v " (num base) ") d))\n"
            "                              (loop (+ pos 1) " (num digit) " (+ off 1) (quote boundary)))\n"
            "                       (loop pos " (num over) " off (quote byte))))))))\n")))
        ((field-action)
         (let* ((args (normal-field-arguments s))
                (sw (field-slot-width fields (car args)))
                (slot (car sw)) (width (cdr sw))
                (k (and (pair? (cdr args)) (cadr args)))
                (tg (normal-field-targets s))
                (expr (render-operation (normal-field-selector s) k)))
           (if (cdr tg)
               ;; A fallible operation. The bound check is emitted, and on
               ;; failure NOTHING is written -- §25:1569 and §10.6:568: a failed
               ;; operation leaves the prior value unchanged, not saturated.
               (string-append
                "      ((" id ")\n"
                "       (let* ((v (vector-ref fieldv " (num slot) ")) (r " expr "))\n"
                "         (if (and (>= r 0) (<= r " (num (- (expt 2 width) 1)) "))\n"
                "             (begin (vector-set! fieldv " (num slot) " r) "
                (zero-width-jump (car tg)) ")\n"
                "             " (zero-width-jump (cdr tg)) ")))\n")
               ;; An operation the constructor proved cannot fail, so no check is
               ;; emitted. Emitting one anyway would be a branch no input can
               ;; take, and a mutation of it would survive.
               (string-append
                "      ((" id ")\n"
                "       (let ((v (vector-ref fieldv " (num slot) ")))\n"
                "         (vector-set! fieldv " (num slot) " " expr ")\n"
                "         " (zero-width-jump (car tg)) "))\n"))))
        ((field-branch)
         (let* ((args (normal-field-arguments s))
                (sw (field-slot-width fields (car args)))
                (a (and (pair? (cdr args)) (cadr args)))
                (b (and (pair? (cdr args)) (pair? (cddr args)) (caddr args)))
                (tg (normal-field-targets s)))
           (string-append
            "      ((" id ")\n"
            "       (let ((v (vector-ref fieldv " (num (car sw)) ")))\n"
            "         (if " (render-predicate (normal-field-selector s) a b) "\n"
            "             " (zero-width-jump (car tg)) "\n"
            "             " (zero-width-jump (cdr tg)) ")))\n")))
        ((dispatch)
         (let ((fb (normal-dispatch-fallback s)))
           (string-append
            (render-exhausted-preamble s id names index-of nm)
            "           (let ((b (bytevector-u8-ref bv pos)))\n"
            "             (case b\n"
            (apply string-append (map render-transition-arm (normal-dispatch-transitions s)))
            "               (else " (loop-tail (car fb) (cdr fb)) ")))))\n")))
        ;; Unreachable today -- this case already covers every kind
        ;; normal-state-kind can produce: dispatch, stop, error, finish, pause,
        ;; field-action, field-branch (Slice ②) and accumulate (Slice ③).
        ;; *** The parenthetical here listed only the first five until
        ;; 2026-09-03, having survived both slices that widened the set --
        ;; including the one eleven lines above this comment. A comment that
        ;; enumerates a closed set is a census, and this milestone shipped three
        ;; defects from exactly that shape; ***
        ;; verified by inspection, not mutation (same convention as
        ;; normal-ir.sls's own else guards).
        (else (assertion-violation 'render-machine "unknown state kind"
                                   (normal-state-kind s))))))

  (define (render-machine compilation binding)
    (unless (compilation-ok? compilation)
      (assertion-violation 'render-machine "cannot render an unverified machine"
                           (compilation-diagnostics compilation)))
    (validate-binding binding)
    (let* ((normal (compilation-normal compilation))
           (mname (symbol->string (machine-name (compilation-machine compilation))))
           (states (normal-machine-states normal))
           (entry (normal-machine-entry normal))
           (fp (normal-machine-fingerprint normal))
           (names (normal-machine-debug-map normal))
           ;; One entry per error DECLARATION, in declaration order -- the order
           ;; errcode already walks. Per-SITE literals would repeat each reason
           ;; once per error site, and the default-eof arm alone renders at every
           ;; dispatch state: the http-version machine has nine error sites over
           ;; two declarations. This is §19.1:996's "immutable field/callback/debug
           ;; metadata", carried as one quoted vector.
           ;; Only the declarations the NORMALIZED graph reaches. The encoding
           ;; writes a reason at exactly two sites -- an error state's, and a
           ;; dispatch state's default-eof routing -- so a declaration no node
           ;; names and that is not the machine default-eof never reaches the IR
           ;; fingerprint. Emitting it anyway made two machines the fingerprint
           ;; calls identical emit DIFFERENT bytes, which is the converse of the
           ;; property decision 0019 item 2 states and the one nothing asserted.
           ;; Narrowing here rather than widening the encoding is what keeps
           ;; every shipped fingerprint where Slice ①a measured it, which
           ;; decision 0019 point 5 requires of every later slice.
           (reached (let walk ((i 0) (acc '()))
                      (if (>= i (vector-length states)) (reverse acc)
                          (let* ((st (vector-ref states i))
                                 (r (normal-error-reason st))
                                 (c (cond ((eq? (normal-state-kind st) 'error)
                                           (normal-error-code st))
                                          ;; *** Slice ③: `accumulate` belongs
                                          ;; here too. *** It is the milestone's
                                          ;; other INPUT-READING kind, it carries
                                          ;; an eof route in the same slot, and
                                          ;; render-exhausted-preamble renders
                                          ;; that route for both kinds through
                                          ;; the same code -- so an accumulate
                                          ;; node whose eof-target is #f asks
                                          ;; index-of for the machine default
                                          ;; declaration exactly as a dispatch
                                          ;; does. Testing only for `dispatch`
                                          ;; left that declaration out of the
                                          ;; reached set, the filter below
                                          ;; dropped it from the errs table, and
                                          ;; index-of then raised "no error
                                          ;; declaration for code" while
                                          ;; rendering a machine the verifier had
                                          ;; just accepted.
                                          ;;
                                          ;; Invisible to every shipped
                                          ;; accumulate fixture: each has an
                                          ;; entry dispatch that ALSO defaults
                                          ;; its eof route, so the pair was in
                                          ;; the set for another state's sake.
                                          ;; It takes a machine whose only
                                          ;; default-eof consumer is the
                                          ;; accumulate node -- which is what the
                                          ;; property generator drew as soon as
                                          ;; it could route the entry's eof to a
                                          ;; finish node instead.
                                          ((and (memq (normal-state-kind st)
                                                      '(dispatch accumulate))
                                                (eq? (car (normal-dispatch-eof st)) 'default))
                                           (cdr (normal-dispatch-eof st)))
                                          (else #f))))
                            (walk (+ i 1)
                                  (if (and c (not (member (cons c r) acc)))
                                      (cons (cons c r) acc) acc))))))
           ;; ONE entry per reached (code . reason) PAIR, not one per declaration
           ;; whose pair is reached. The filter cannot test declaration identity:
           ;; the normalizer resolved each site's declaration NAME to its code and
           ;; reason (normal-ir.sls's errcode/errreason) before the emitter sees
           ;; it, so `reached` is a set of pairs and membership is all there is to
           ;; test. Two declarations may agree on both -- nothing rejects
           ;; duplicate codes or duplicate reasons, and §16.2's required-check
           ;; list does not ask for uniqueness -- so an UNREACHED declaration
           ;; duplicating a reached one passed the membership test and was
           ;; emitted, giving two machines with the same IR fingerprint different
           ;; emitted bytes.
           ;;
           ;; That is the same defect commit 51fd5f3 was written to close, and
           ;; that commit did not close it: its filter fixed the case where the
           ;; unreached declaration's pair is ABSENT from `reached` and left the
           ;; case where it is present under another declaration's name.
           ;; determinism-one-byte-tests.sps now carries both constructions.
           ;;
           ;; Dropping the later duplicate rather than keeping it is what leaves
           ;; every shipped golden where it is: a machine with no duplicate pair
           ;; emits exactly what it emitted before, and the surviving entry keeps
           ;; its declaration-order POSITION, so no index moves either. The two
           ;; entries would have been textually identical in any case -- an errs
           ;; entry is (code, reason) and nothing else -- so no site loses a
           ;; reason it could have rendered, which is what makes the drop safe
           ;; rather than merely convenient.
           (decls (let keep ((ds (machine-errors (compilation-machine compilation))) (acc '()))
                    (if (null? ds) (reverse acc)
                        (let ((pair (cons (error-declaration-code (car ds))
                                          (error-declaration-reason (car ds)))))
                          (keep (cdr ds)
                                (if (and (member pair reached)
                                         (not (member pair
                                                      (map (lambda (d)
                                                             (cons (error-declaration-code d)
                                                                   (error-declaration-reason d)))
                                                           acc))))
                                    (cons (car ds) acc) acc))))))
           ;; Keyed on code AND reason, not on code alone. Two declarations may
           ;; share a code -- pass-names rejects duplicate declaration NAMES and
           ;; nothing rejects duplicate codes, and §16.2's required-check list
           ;; does not ask for uniqueness -- and the normalizer has already
           ;; collapsed the node's declaration name to its resolved code by the
           ;; time the emitter sees it. Keying on the code alone therefore
           ;; returned the FIRST declaration carrying it, so a generated parser
           ;; reported a different declaration's reason than the interpreter,
           ;; on a machine the verifier accepts with zero diagnostics. The
           ;; normalized state has carried the right reason in its own slot
           ;; since format 2, which is what makes this recoverable without a new
           ;; slot: (code, reason) selects the entry the SITE produced, and when
           ;; two declarations agree on both, their errs entries are identical
           ;; and either index yields the same record -- so this is total.
           (index-of (lambda (code reason)
                       (let walk ((ds decls) (i 0))
                         (cond ((null? ds)
                                ;; Unreachable: every code/reason pair the
                                ;; emitter asks about was resolved FROM this
                                ;; same list by the normalizer. Loud rather than
                                ;; a silent fallback to 0, which is what the
                                ;; first version of this walk would have done.
                                (assertion-violation
                                 'render-machine "no error declaration for code"
                                 code reason))
                               ((and (eq? (error-declaration-code (car ds)) code)
                                     (string=? (error-declaration-reason (car ds)) reason))
                                i)
                               (else (walk (cdr ds) (+ i 1)))))))
           (errs (let join ((ds decls) (acc ""))
                   (if (null? ds) acc
                       (join (cdr ds)
                             (string-append acc (if (string=? acc "") "" " ")
                                            "#(" (symbol->string (error-declaration-code (car ds)))
                                            " \"" (escape-string (error-declaration-reason (car ds)))
                                            "\")")))))
           ;; Decision 0019 item 3(b)'s member 0, filled by Milestone 4 Slice
           ;; ①b. It renders the field DECLARATIONS as (name . initial) pairs in
           ;; slot order, not bare initials: the parser needs the initials AND
           ;; the name-to-slot resolution parser-field-ref answers by, the slot
           ;; is the pair's position, so one member determines both. That
           ;; argument is about FIELD data and is NOT a prohibition on further
           ;; members -- Milestone 5 Slice ①a adds member 1, reserved empty.
           ;; Decision 0025 POINT 2 is what grants it; point 3 is the `exec`
           ;; parameters, and 0025 explicitly declines to allocate member 1's
           ;; contents, so this comment does not either. Rendered as a bare `#()`
           ;; here and filled by whichever slice needs it. With no fields the payload is now
           ;; `#(#() #())`.
           ;;
           ;; Rendered from the NORMALIZED table rather than from machine-fields,
           ;; so the emitted slot order is the same object the IR fingerprint was
           ;; computed over. Reading the source machine again would let the two
           ;; disagree with nothing to notice.
           ;; Member 1, Milestone 5 Slice ①b. Four parts per callback --
           ;; name, kind, required?, default-branch -- which is everything
           ;; §9.3:419's binding resolution needs and nothing more. Branch KEYS
           ;; stay behind: §16.2:901 and :902 are pass-declarations' and are
           ;; settled before a parser exists, so carrying them across the seam
           ;; would ship data no runtime reads. Empty for a machine that
           ;; declares no callback, which is what keeps every golden still.
           (cbs (let cloop ((cs (normal-machine-callback-decls normal)) (acc ""))
                  (if (null? cs) acc
                      (cloop (cdr cs)
                             (string-append
                              acc (if (string=? acc "") "" " ")
                              "#(" (symbol->string (car (car cs)))
                              " " (symbol->string (cadr (car cs)))
                              " " (if (caddr (car cs)) "#t" "#f")
                              " " (let ((d (cadddr (car cs))))
                                    (if (symbol? d) (symbol->string d) "#f"))
                              ")")))))
           (fields (let loop ((fs (normal-machine-fields normal)) (acc ""))
                     (if (null? fs) acc
                         (loop (cdr fs)
                               (string-append
                                acc (if (string=? acc "") "" " ")
                                "(" (symbol->string (car (car fs)))
                                " . " (number->string (caddr (car fs))) ")")))))
           (bstr (symbol->string binding)))
      (string->utf8
       (string-append
        "(library (generated " mname ")\n"
        "  (export " bstr ")\n"
        "  (import (rnrs) (byte-machine runtime))\n"
        "  (define errs (quote #(" errs ")))\n"
        "  (define (exec state offset bv start end finish? fieldv psr cbv)\n"
        ;; The kind is initialized `boundary` UNCONDITIONALLY, with no finish?
        ;; key: nothing has been consumed since either kind of call began, so an
        ;; error state reached with no jump taken reports a boundary at the
        ;; current stream offset regardless of which call observes it. Keying
        ;; this on finish? made both lanes report `eof` at the default-EOF arm
        ;; and made that arm's own literal observationally identical to the
        ;; inherited variable -- agreement bought by making the difference
        ;; unobservable, which is the repair AGENTS.md warns disarms its own test.
        "    (let loop ((pos start) (st state) (off offset) (pk (quote boundary)))\n"
        "      (case st\n"
        (let loop ((i 0) (acc ""))
          (if (>= i (vector-length states)) acc
              (loop (+ i 1) (string-append acc (render-state-arm (vector-ref states i)
                                                                 names index-of
                                                                 (normal-machine-fields normal))))))
        "      (else (assertion-violation (quote exec) \"unknown state\" st)))))\n"
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine 4 " (number->string fp) " "
        (number->string entry) " exec (quote #(#(" fields ") #(" cbs "))))))\n"))))

  (define (emit-machine compilation binding port)
    (let ((bytes (render-machine compilation binding)))
      (put-bytevector port bytes)
      (vector 'emission-metadata
              (normal-machine-fingerprint (compilation-normal compilation))
              (bytevector-length bytes)))))
