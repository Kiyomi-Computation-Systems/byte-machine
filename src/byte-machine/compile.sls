;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine compile): the offline emitter. compile-machine re-verifies
;;; internally and normalizes; render-machine renders the normalized IR to a
;;; complete importable R6RS .sls as a canonical UTF-8/LF bytevector (no
;;; implementation `write`); emit-machine writes those bytes to the supplied
;;; binary port only. The generated library imports only (rnrs) and
;;; (byte-machine runtime), owns the derived library name (generated
;;; <machine-name>), and defines the single caller-named compiled-machine
;;; binding through the one unversioned byte-machine-make-compiled-machine,
;;; whose first action is the ABI version check and whose trailing quoted
;;; vector is the growable payload. Pure but for emit-machine's port write.
(library (byte-machine compile)
  (export compile-machine compilation-ok? compilation-diagnostics
          render-machine emit-machine
          reserved-member-2 reserved-member-3) ; exported for test support only
  (import (rnrs)
          (byte-machine verify)
          (only (byte-machine private ir) machine-name machine-errors
                error-declaration-code error-declaration-reason)
          (byte-machine private normal-ir)
          (byte-machine private names))

  (define c-tag (vector 'byte-machine-compilation))
  ;; (vector c-tag ok? diagnostics machine normal) ; normal #f when not ok
  (define (make-compilation ok? diags machine normal) (vector c-tag ok? diags machine normal))
  ;; compilation-ok? : Compilation -> Boolean
  (define (compilation-ok? c) (vector-ref c 1))
  ;; compilation-diagnostics : Compilation -> (Listof Diagnostic)
  (define (compilation-diagnostics c) (vector-ref c 2))
  (define (compilation-machine c) (vector-ref c 3))
  (define (compilation-normal c) (vector-ref c 4))

  ;; compile-machine : Machine (Listof Any) -> Compilation
  (define (compile-machine machine options)
    (unless (null? options)
      (assertion-violation 'compile-machine "v0.1 accepts only the empty option list" options))
    (let ((v (verify-machine machine)))
      (if (verification-ok? v)
          (make-compilation #t '() (verification-machine v)
                            (normalize-machine (verification-machine v)))
          (make-compilation #f (verification-diagnostics v) (verification-machine v) #f))))

  ;; --- reserved-output-binding set ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  ;; The hand-maintained mirror of (byte-machine runtime)'s exports: it must list
  ;; exactly the runtime's live exports, because a new runtime export not added
  ;; here would let the emitter accept an output binding that collides with it.
  ;; Checked by set-equality against the runtime's live exports, so it fails in
  ;; BOTH directions and must change whenever the exports do.
  ;; reserved-member-2 : (Listof Symbol)
  (define reserved-member-2
    '(make-compiled-machine compiled-machine?
      byte-machine-make-compiled-machine/v1 byte-machine-make-compiled-machine/v2
      byte-machine-make-feed-outcome/v1
      make-parser parser? parser-feed! parser-finish! parser-resume!
      parser-lifecycle parser-reset!
      parser-result? parser-result-status parser-result-next
      parser-result-consumed parser-result-stream-offset parser-result-error
      parser-result-pause
      byte-machine-make-parser-error/v1 parser-error?
      parser-error-domain parser-error-code parser-error-reason
      parser-error-detail parser-error-node-name parser-error-state-id
      parser-error-offset parser-error-position-kind
      parser-error-span parser-error-span-offset
      byte-machine-make-compiled-machine
      parser-field-ref
      callback-continue callback-pause
      parser-stream-offset parser-user-context parser-active-span
      make-callback-failure callback-failure?
      callback-failure-code callback-failure-detail
      byte-machine-callback-step/v1 byte-machine-callback-step/v2
      byte-machine-make-callback-error/v1
      parser-state-name
      byte-machine-span-open/v1
      byte-machine-span-fragment-step/v1 byte-machine-span-fragment-step/v2
      byte-machine-span-close/v1
      byte-machine-keyword-step/v1))
  ;; Every identifier the emitted body binds, so a caller-chosen output binding
  ;; cannot collide with one. `fieldv` is emitted `exec`'s field-value vector
  ;; parameter; it is deliberately not spelled `fields`, which `(rnrs)` binds as
  ;; define-record-type's auxiliary keyword and which the member-3 drift guard's
  ;; own `(rnrs)` subtraction would therefore swallow -- so a real output-binding
  ;; collision on that name would go unguarded. `psr` is the parser a callback
  ;; receives as its first argument, `cbv` the resolved callback slot vector, and
  ;; `o` the outcome binding an emitted callback/span arm reads. The callback and
  ;; span arms index `cbv` with a literal slot and hand `psr` to the invocation.
  ;; THE STATE PROCEDURES AND THEIR DISPATCHER ARE NOT IN THIS LIST, AND CANNOT
  ;; BE. The emitted body also binds one procedure per state and one dispatcher,
  ;; and there is no bound on how many states a machine has -- so enumerating
  ;; them here is not possible and a growing list would be the wrong shape
  ;; anyway. They are spelled `%s<id>` and `%dispatch` instead: `portable-name?`
  ;; admits `[a-z][a-z0-9-]*` and nothing else, so no output binding and no
  ;; declared name can begin with `%`, and the collision this list exists to
  ;; prevent is impossible by construction rather than by enumeration. The
  ;; member-3 drift guard asserts that prefix rather than trusting this comment.
  ;; reserved-member-3 : (Listof Symbol)
  (define reserved-member-3
    '(exec loop pos st off b bv start end state offset finish? fieldv errs pk
      v r d o psr cbv n kpath))
  ;; The grammar half is (byte-machine private names)' `portable-name?`: one
  ;; body shared with verify.sls's name check and runtime.sls's callback-code
  ;; check. The three reserved sets stay here -- an output BINDING is barred from
  ;; all three, a declared name from member 1 alone, and that difference is this
  ;; site's.
  (define (valid-binding? sym)
    (and (portable-name? sym)
         (not (memq sym reserved-member-1))
         (not (memq sym reserved-member-2))
         (not (memq sym reserved-member-3))))

  (define (validate-binding binding)
    (unless (symbol? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding))
    (unless (valid-binding? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding)))

  ;; --- canonical source writer ---
  ;; Explicit escaping, for the one class of author-controlled text the emitter
  ;; writes into generated source: an error declaration's static reason, carried
  ;; by the per-library `errs` table. `pass-names-valid` refuses any reason
  ;; outside printable ASCII plus LF, so exactly three characters can reach here
  ;; needing an escape and the set is closed rather than defensive. Its one caller
  ;; is the `errs` table below.
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
  ;; The fourth argument is the POSITION KIND. It is a property of the transition
  ;; that ARRIVED, not of the error state: one error node reached by a reexecute
  ;; edge reports `byte` and the same node reached by an advance edge reports
  ;; `boundary`, and the emitted arm is keyed on state id alone, so it cannot be a
  ;; per-site literal there. Each jump therefore carries its own kind forward.
  (define (loop-tail target mode)
    (if (eq? mode 'advance)
        (string-append "(%s" (number->string target) " (+ pos 1) " (number->string target)
                       " (+ off 1) (quote boundary))")
        (string-append "(%s" (number->string target) " pos " (number->string target)
                       " off (quote byte))")))

  ;; A BYTE CLASS IS A RANGE, AND A LINEAR SCAN OF ITS MEMBERS IS NOT.
  ;;
  ;; Byte classes lower to one transition per byte, so a token set renders ~90
  ;; of them and a complement up to 256. Emitted as sibling `(case b ...)` arms
  ;; that cost what Chez charges for a large `case`, which is a LINEAR SCAN:
  ;; measured on Chez 10.4.1 over a 94-byte set, the first arm dispatches in
  ;; 0.95ns and a byte in the middle -- a lowercase letter, which is what HTTP
  ;; is mostly made of -- in 21.60ns.
  ;;
  ;; The transitions arrive sorted ascending by byte, so a maximal run of
  ;; consecutive bytes sharing a target and a mode is exactly what the source
  ;; byte class said before lowering flattened it. Rendered back as one range
  ;; test per run, the same dispatch costs **1.25ns**.
  ;;
  ;; Two other shapes were measured and rejected, and one of them is worse
  ;; than the plain `case`: a grouped datum list
  ;; (`((97 98 99 ...) target)`) costs 57.40ns, because `memv` over 94 elements
  ;; loses to the nested-if expansion `case` already gets. A 256-entry
  ;; membership bytevector is 1.75ns -- fine, but it answers only "is b in the
  ;; class", so a state with several classes needs several tables and a target
  ;; per table, where ranges carry the target in the clause.
  ;;
  ;; `fx` comparisons rather than generic: `b` is `bytevector-u8-ref`'s result
  ;; and a fixnum by construction, `(rnrs)` exports them, and the pair measured
  ;; 1.25ns against 1.40ns.
  ;;
  ;; render-byte-clauses : (Listof (byte target mode)) -> String
  (define (render-byte-clauses trs)
    (define (clause lo hi target mode)
      (string-append
       "               ("
       (if (= lo hi)
           (string-append "(fx=? b " (num lo) ")")
           (string-append "(and (fx>=? b " (num lo) ") (fx<=? b " (num hi) "))"))
       " " (loop-tail target mode) ")\n"))
    ;; One pass, carrying the open run. A new transition extends it when it is
    ;; the next byte with the same destination; otherwise the open run is
    ;; flushed and it starts a new one. Clauses stay in ascending byte order,
    ;; which is the order the transitions came in: the runs partition the byte
    ;; space, so no clause can shadow another and the order is free to be the
    ;; deterministic one rather than a chosen one.
    (let walk ((ts trs) (lo #f) (hi #f) (tgt #f) (mode #f) (acc ""))
      (if (null? ts)
          (if lo (string-append acc (clause lo hi tgt mode)) acc)
          (let ((b (car (car ts))) (t (cadr (car ts))) (m (caddr (car ts))))
            (if (and lo (= b (+ hi 1)) (= t tgt) (eq? m mode))
                (walk (cdr ts) lo b tgt mode acc)
                (walk (cdr ts) b b t m
                      (if lo (string-append acc (clause lo hi tgt mode)) acc)))))))

  ;; An exhausted dispatch (finish? #t) routes eof: to a named node's loop
  ;; (continue the eof-target chain) or to the machine default-eof error.
  ;; The node case is the EOF-chain hop and carries `eof` forward. The default
  ;; case is a terminal construction reached by no jump at all, so it takes a
  ;; per-site (quote eof) literal rather than the loop variable, fixing `eof`
  ;; whether or not a prior hop ran. Its node-name is the DISPATCH node's, which
  ;; is where truncation was detected: a default-EOF error has no error node of
  ;; its own.
  (define (render-eof-branch eof id name reason index-of)
    (if (eq? (car eof) 'node)
        (string-append "(%s" (number->string (cdr eof)) " pos " (number->string (cdr eof))
                       " off (quote eof))")
        (string-append "(byte-machine-make-feed-outcome/v1 (quote error) pos "
                       "(byte-machine-make-parser-error/v1 (vector-ref errs "
                       (number->string (index-of (cdr eof) reason)) ") (quote " (symbol->string name)
                       ") " id " off (quote eof)) " id " off)")))

  ;; A lowered sequence-prefix state IS an ordinary normalized dispatch state, so
  ;; it renders through this same arm, the encoding gains no tag, and the
  ;; need-input resume point below gives cross-feed resumability with no new
  ;; mechanism.
  ;;
  ;; `names` maps a state id to its public source-node name (the debug map,
  ;; normalizer output) and `index-of` a (code, reason) pair to that
  ;; declaration's position in the errs table. The name is not recoverable from a
  ;; normalized state at all, and the declaration is not recoverable from its
  ;; code alone -- codes need not be unique -- so both are threaded in from
  ;; render-machine rather than derived here.
  ;; The field arithmetic is written TWICE on purpose: this is the emitter's copy
  ;; and it shares no helper with interpret.sls. Widths come from the NORMALIZED
  ;; table here and from `machine-fields` there, so a lowering bug in overflow
  ;; checking stays visible to the differential.
  ;;
  ;; `render-state-arm` does not see the declarations, so `fields` is threaded
  ;; in: the normalized (name width initial slot) table.
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
  ;; input, which makes the two lanes' answers comparable.
  (define (zero-width-jump target)
    (string-append "(%s" (num target) " pos " (num target) " off pk)"))

  ;; A GOTO TARGET IS CHOSEN AT RUN TIME FROM A SET FIXED AT EMIT TIME.
  ;;
  ;; The three arms that call application code -- callback, span fragment, span
  ;; completion -- could answer `goto` through `%dispatch`, the search over
  ;; every state id, but that search would then run on every crossing, and an
  ;; HTTP grammar crosses one about four times per header. "Once per callback,
  ;; never once per byte" does not make that cost invisible.
  ;;
  ;; What the arm knows is stronger than the target. The runtime's classifier can
  ;; answer only the node's continue target, one of its declared branch targets,
  ;; or its default -- and the emitter renders all three as literals INTO that
  ;; very call, two lines above. So the arm tests the literals it already wrote
  ;; and jumps directly, which is the same move `render-byte-clauses` makes one
  ;; level down: a set known here does not need a search there.
  ;;
  ;; CONTINUE IS RENDERED FIRST. The clauses are a linear scan, so their order is
  ;; the optimization, and a bound callback answering `continue` is the outcome
  ;; that actually happens.
  ;;
  ;; `%dispatch` STAYS as the final clause. Dropping it would turn an
  ;; optimization of a total function into a claim about what the runtime can
  ;; return -- checkable only by reading runtime.sls, and silently wrong the day
  ;; a fourth outcome is added. It costs one comparison on a path no construction
  ;; reaches.
  ;;
  ;; Targets repeat (a default-branch resolves to a branch target) and may be
  ;; absent (`#f`, a required callback's default), so the walk dedupes and skips.
  ;; The clauses ALONE: each arm opens the `cond`, puts its pause and failure
  ;; clauses after these, and closes with `render-dispatch-else`. The order is
  ;; that and not the reverse because the outcome cases are disjoint by type and
  ;; the target clauses are the ones that run.
  ;; render-goto-clauses : String (Listof (U ExactInteger #f)) -> String
  (define (render-goto-clauses expr targets)
    (let loop ((ts targets) (seen '()) (acc ""))
      (cond ((null? ts) acc)
            ((or (not (car ts)) (memv (car ts) seen)) (loop (cdr ts) seen acc))
            (else
             (loop (cdr ts) (cons (car ts) seen)
                   (string-append acc (if (string=? acc "") "" " ")
                                  "((eqv? " expr " " (num (car ts)) ") "
                                  (zero-width-jump (car ts)) ")"))))))
  (define (render-dispatch-else expr)
    (string-append "(else (%dispatch pos " expr " off pk))"))

  ;; THE FEED ENTRY IS A SEARCH, NOT A SCAN.
  ;;
  ;; `%dispatch` answers the one target that genuinely cannot be a literal: the
  ;; state comes from the parser, so `render-goto-clauses`' trick does not
  ;; apply. What it CAN stop being is linear. A `case` over N state ids costs
  ;; about 0.31ns per arm skipped, so on a 530-state machine the mean entry
  ;; costs ~48ns -- once per `parser-feed!` call and once per keyword-table
  ;; jump. A whole-buffer parse pays it twice and does not care; a parse fed a
  ;; byte at a time pays it once per byte, and measured on that grammar it was
  ;; **37% of the parse**.
  ;;
  ;; A balanced binary search over the ids is ceil(log2 N) comparisons -- ten
  ;; where the scan averaged 265 -- and costs nothing structurally: the leaves
  ;; are the same tail calls, so the state procedures still never escape and
  ;; the direct jumps between states are untouched.
  ;;
  ;; A JUMP TABLE WAS REJECTED, and not on taste. A vector of the state
  ;; procedures indexed by id is O(1), but storing them makes every one of them
  ;; ESCAPE, and they close over `exec`'s `bv`, `end`, `finish?`, `fieldv`,
  ;; `psr` and `cbv` -- so Chez would have to build N closures on every `exec`
  ;; entry, which is the per-feed path. The fast shape is the one that keeps
  ;; them local.
  ;;
  ;; The leaves carry no test of their own, which requires the ids to be
  ;; exactly 0..N-1 -- checked in `render-machine` rather than assumed, because
  ;; a lowering that ever skipped an id would otherwise route a live state to
  ;; its neighbour, silently, with no fixture obliged to notice.
  ;;
  ;; render-dispatch-tree : String ExactInteger ExactInteger ExactInteger -> String
  (define (render-dispatch-tree key lo hi ind)
    (let ((p (make-string ind #\space)))
      (if (= (- hi lo) 1)
          (string-append p "(%s" (num lo) " pos st off pk)")
          (let ((mid (div (+ lo hi) 2)))
            (string-append
             p "(if (fx<? " key " " (num mid) ")\n"
             (render-dispatch-tree key lo mid (+ ind 2)) "\n"
             (render-dispatch-tree key mid hi (+ ind 2)) ")")))))
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
  ;; otherwise. Shared by the dispatch arm and the accumulate arm, which render it
  ;; identically rather than duplicating these lines.
  (define (render-exhausted-preamble s id names index-of nm)
    (string-append
     "      (define (%s" id " pos st off pk)\n"
     "       (if (>= pos end)\n"
     "           (if finish?\n"
     "               " (render-eof-branch (normal-dispatch-eof s) id
                                          (string->symbol (nm (normal-state-id s)))
                                          (normal-error-reason s) index-of) "\n"
     "               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off))\n"))

  ;; `spans` is threaded in for the same reason `fields` above it is, and for one
  ;; more: a lowered span state carries the SPAN slot, but the arm it renders
  ;; indexes `cbv`. The normalizer publishes the crossing as
  ;; `normal-machine-span-decls` -- (name data-slot complete-slot) in span-slot
  ;; order -- rather than leaving the emitter to re-walk the declarations, which
  ;; would put a second copy of that resolution in the lane being checked.
  ;; The keyword-table entries as a quoted datum: ((byte-list . target-id) ...),
  ;; the same list the encoder folds into the fingerprint. Rendering it inline (a
  ;; handful of short byte lists) rather than as hundreds of dispatch state arms is
  ;; what makes the keyword-table lowering compact.
  (define (render-kw-entries es)
    (string-append
     "("
     (apply string-append
            (map (lambda (e)
                   (string-append
                    "(("
                    (let bl ((bs (car e)) (acc ""))
                      (if (null? bs) acc
                          (bl (cdr bs) (string-append acc (if (string=? acc "") "" " ")
                                                      (num (car bs))))))
                    ") . " (num (cdr e)) ")"))
                 es))
     ")"))

  ;; EVERY RUNTIME NAME AN ARM WRITES IS A CENSUS ENTRY. The allocation audit
  ;; (test/common/allocation-audit-tests.sps) derives the set of
  ;; `(byte-machine runtime)` procedures emitted code can call from this file's
  ;; string literals, and fails until an input whose allocation it asserts runs
  ;; each one. An arm that calls a runtime op no arm called before therefore
  ;; owes that lane a witness in the same change. Write the op's name as one
  ;; literal: a name assembled from pieces is invisible to the derivation.
  (define (render-state-arm s names index-of fields spans)
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
         (string-append "      (define (%s" id " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f " id " off))\n"))
        ((error)
         ;; The record's five call-site arguments: the errs entry (code and
         ;; reason together), the public source-node name, the state id, the
         ;; absolute offset, and the loop's position-kind variable. Reading `pk`
         ;; rather than a literal is what lets one error node report `byte` when
         ;; a reexecute edge arrives and `boundary` when an advance edge does.
         (string-append "      (define (%s" id " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote error) pos "
                        "(byte-machine-make-parser-error/v1 (vector-ref errs "
                        (number->string (index-of (normal-error-code s)
                                                  (normal-error-reason s))) ") (quote "
                        (nm (normal-state-id s)) ") " id " off pk) " id " off))\n"))
        ((finish)
         (string-append "      (define (%s" id " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote finished) pos #f " id " off))\n"))
        ;; A pause with an OPTIONAL reason builds a parser-error-shaped record
        ;; into the outcome's error slot -- the SAME construction the error arm
        ;; above makes, over the same errs table and the loop's `pk`. The
        ;; feed-outcome→result boundary routes it to the result's PAUSE slot for a
        ;; paused status, never the error slot. A reason-less pause renders `#f`.
        ((pause)
         (string-append "      (define (%s" id " pos st off pk) (byte-machine-make-feed-outcome/v1 (quote paused) pos "
                        (let ((code (normal-error-code s)))
                          (if code
                              (string-append "(byte-machine-make-parser-error/v1 (vector-ref errs "
                                             (number->string (index-of code (normal-error-reason s)))
                                             ") (quote " (nm (normal-state-id s)) ") " id " off pk)")
                              "#f"))
                        " " (number->string (normal-pause-target s)) " off))\n"))
        ;; The INPUT-READING kind. The digit test is rendered as a range
        ;; comparison per base rather than a `case` over literal bytes: base 16
        ;; has three disjoint ASCII ranges, so one `case` group with one `d`
        ;; cannot express it. The inequality is rendered as a check BEFORE the
        ;; multiply-add, not a compute-then-check, because relying on host fixnum
        ;; width is forbidden.
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
                                    (string-append "(%s" (num (car nd)) " (+ pos 1) " (num (car nd)) " (+ off 1) (quote boundary))")
                                    (string-append "(%s" (num (car nd)) " pos " (num (car nd)) " off (quote byte))")) "\n"
            "                 (let ((v (vector-ref fieldv " (num slot) ")))\n"
            "                   (if (<= v (div (- " (num mx) " d) " (num base) "))\n"
            "                       (begin (vector-set! fieldv " (num slot)
                                     " (+ (* v " (num base) ") d))\n"
            "                              (%s" (num digit) " (+ pos 1) " (num digit) " (+ off 1) (quote boundary)))\n"
            "                       (%s" (num over) " pos " (num over) " off (quote byte))))))))\n")))
        ;; KNOWN LIMITATION: the machine-action half of the zero-width
        ;; position-kind rule is not implemented correctly. The rule wants
        ;; `boundary` at the current stream offset for a zero-width machine
        ;; action or callback failure; the callback half is correct, but a
        ;; field-action operation that fails -- e.g. an increment that
        ;; overflows a `u8` -- reached over a reexecute edge answers
        ;; position-kind `byte` where it should answer `boundary`. The
        ;; accumulate OVERFLOW render two lines above emits `(quote byte)` for
        ;; the same reason (this is distinct from the non-digit
        ;; reexecute render ten lines above it, which is a different rule). Fixing
        ;; it is a one-line change in this lane and more in the interpreted one --
        ;; see the matching note at `interpret.sls`'s `field-step`, the other end
        ;; of the differential. The counted-consume kind does not inherit this: it
        ;; invokes no callback and takes no error edge of its own, so it can
        ;; produce neither half of the row.
        ((field-action)
         (let* ((args (normal-field-arguments s))
                (sw (field-slot-width fields (car args)))
                (slot (car sw)) (width (cdr sw))
                (k (and (pair? (cdr args)) (cadr args)))
                (tg (normal-field-targets s))
                (expr (render-operation (normal-field-selector s) k)))
           (if (cdr tg)
               ;; A fallible operation. The bound check is emitted, and on
               ;; failure NOTHING is written: a failed operation leaves the prior
               ;; value unchanged, not saturated.
               (string-append
                "      (define (%s" id " pos st off pk)\n"
                "       (let* ((v (vector-ref fieldv " (num slot) ")) (r " expr "))\n"
                "         (if (and (>= r 0) (<= r " (num (- (expt 2 width) 1)) "))\n"
                "             (begin (vector-set! fieldv " (num slot) " r) "
                (zero-width-jump (car tg)) ")\n"
                "             " (zero-width-jump (cdr tg)) ")))\n")
               ;; An operation the constructor proved cannot fail, so no check is
               ;; emitted. Emitting one anyway would be a branch no input can
               ;; take.
               (string-append
                "      (define (%s" id " pos st off pk)\n"
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
            "      (define (%s" id " pos st off pk)\n"
            "       (let ((v (vector-ref fieldv " (num (car sw)) ")))\n"
            "         (if " (render-predicate (normal-field-selector s) a b) "\n"
            "             " (zero-width-jump (car tg)) "\n"
            "             " (zero-width-jump (cdr tg)) ")))\n")))
        ;; This arm calls APPLICATION code. Three arms do: this one, the
        ;; span-completion arm (which renders this very procedure), and the
        ;; span-end arm (which renders `byte-machine-span-fragment-step/v2`,
        ;; applying the caller's data callback). The invocation and the outcome
        ;; vocabulary are the RUNTIME's -- `byte-machine-callback-step/v2`, the
        ;; same procedure `parser-feed-op!` calls -- so this arm renders only the
        ;; literals the node carries and the routing they select, keeping the
        ;; classification out of the emitted lane so both lanes classify from the
        ;; same construction.
        ;;
        ;; `cbv` is read here: the slot is a literal, so the hot path is one
        ;; `vector-ref` and never a symbolic lookup.
        ;;
        ;; Zero-width, so the `goto` arm is `zero-width-jump`'s rule with a
        ;; computed target -- same `pos`, same `off`, same `pk`.
        ;;
        ;; The error arm renders the LITERAL `boundary`, not `pk`: a callback
        ;; failure is on the `boundary at the current stream offset` row
        ;; unconditionally. Rendering `pk` would give `byte` whenever the
        ;; invoking node was reached over a reexecute edge -- and if both lanes
        ;; did that, the differential would agree on the wrong value. The
        ;; runtime's own arms apply the same rule under the name
        ;; `callback-failure-position`.
        ((callback)
         (let ((tg (normal-field-targets s)))
           (string-append
            "      (define (%s" id " pos st off pk)\n"
            "       (let ((o (byte-machine-callback-step/v2 psr " id " off (vector-ref cbv "
            (num (normal-field-selector s)) ") (quote ("
            (let join ((bs (normal-field-arguments s)) (acc ""))
              (if (null? bs) acc
                  (join (cdr bs)
                        (string-append acc (if (string=? acc "") "" " ")
                                       "(" (symbol->string (car (car bs)))
                                       " . " (num (cdr (car bs))) ")"))))
            ")) " (num (car tg)) " "
            (let ((d (caddr tg))) (if d (num d) "#f")) ")))\n"
            "         (cond " (render-goto-clauses
                              "o"
                              (cons (car tg)
                                    (append (map cdr (normal-field-arguments s))
                                            (list (caddr tg))))) "\n"
            ;; The OPTIONAL callback-pause reason rides the outcome's error slot,
            ;; built like the pause node arm but with `boundary` -- a callback
            ;; outcome reports boundary, as its error arm below does
            ;; (callback-failure-position). The boundary routes it to the pause
            ;; slot. A reason-less callback renders `#f`.
            "               ((eq? o callback-pause) (byte-machine-make-feed-outcome/v1 (quote paused) pos "
            (let ((code (normal-error-code s)))
              (if code
                  (string-append "(byte-machine-make-parser-error/v1 (vector-ref errs "
                                 (number->string (index-of code (normal-error-reason s)))
                                 ") (quote " (nm (normal-state-id s)) ") " id " off (quote boundary))")
                  "#f"))
            " " (num (cadr tg)) " off))\n"
            "               ((callback-failure? o) (byte-machine-make-feed-outcome/v1 (quote error) pos "
            "(byte-machine-make-callback-error/v1 (callback-failure-code o) (callback-failure-detail o) (quote "
            (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))\n"
            "               " (render-dispatch-else "o") ")))\n")))
        ;; --- the three span arms -------------------------------------------
        ;; All three are ZERO-WIDTH and end in `zero-width-jump`'s rule -- same
        ;; `pos`, same `off`, same `pk` -- literally so where the target is static
        ;; and inline where it comes from `(cadr o)`, exactly as the callback arm
        ;; above does.
        ;;
        ;; None of them binds a local beyond `o`, and that is deliberate: the mark
        ;; lives in the parser and `byte-machine-span-fragment-step/v2` reads it,
        ;; so no rendered `let` introduces a name `reserved-member-3` would have to
        ;; grow to cover.
        ((span-start)
         ;; Records the current cursor -- `pos`, the slice index.
         (let ((d (list-ref spans (normal-field-selector s))))
           (string-append
            "      (define (%s" id " pos st off pk)\n"
            "       (begin (byte-machine-span-open/v1 psr (quote "
            (symbol->string (car d)) ") pos " (num (cadr d)) ")\n"
            "              " (zero-width-jump (normal-field-targets s)) "))\n")))
        ;; The FIRST of the two substeps: the remaining fragment. Its continuation
        ;; is the substep state -- `arguments`, which no other span kind uses --
        ;; and never the node's own successor, because resuming happens at the next
        ;; undelivered substep.
        ((span-end)
         (let ((d (list-ref spans (normal-field-selector s)))
               (cid (num (normal-field-arguments s))))
           (string-append
            "      (define (%s" id " pos st off pk)\n"
            "       (let ((o (byte-machine-span-fragment-step/v2 psr " id
            " off (vector-ref cbv " (num (cadr d)) ") bv pos " cid ")))\n"
            "         (cond " (render-goto-clauses
                               "o" (list (normal-field-arguments s))) "\n"
            "               ((eq? o callback-pause) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
            cid " off))\n"
            "               ((callback-failure? o) (byte-machine-make-feed-outcome/v1 (quote error) pos "
            "(byte-machine-make-callback-error/v1 (callback-failure-code o) (callback-failure-detail o) (quote "
            (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))\n"
            "               " (render-dispatch-else "o") ")))\n")))
        ;; The SECOND substep. The close comes BEFORE the invocation, so it is the
        ;; first thing rendered here in both shapes -- a completion callback that
        ;; asks `parser-active-span` must see #f.
        ((span-completion)
         (let* ((d (list-ref spans (normal-field-selector s)))
                (c (caddr d))
                (tgt (num (normal-field-targets s))))
           (if (not c)
               ;; The optional completion callback, absent: the substep still
               ;; exists -- it is what makes the span inactive -- and is simply
               ;; not an invocation.
               (string-append
                "      (define (%s" id " pos st off pk)\n"
                "       (begin (byte-machine-span-close/v1 psr)\n"
                "              " (zero-width-jump (normal-field-targets s)) "))\n")
               (string-append
                "      (define (%s" id " pos st off pk)\n"
                "       (begin (byte-machine-span-close/v1 psr)\n"
                "         (let ((o (byte-machine-callback-step/v2 psr " id
                " off (vector-ref cbv " (num c) ") (quote ()) " tgt " " tgt ")))\n"
                "           (cond " (render-goto-clauses
                                     "o" (list (normal-field-targets s))) "\n"
                "                 ((eq? o callback-pause) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
                tgt " off))\n"
                "                 ((callback-failure? o) (byte-machine-make-feed-outcome/v1 (quote error) pos "
                "(byte-machine-make-callback-error/v1 (callback-failure-code o) (callback-failure-detail o) (quote "
                (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))\n"
                "                 " (render-dispatch-else "o") "))))\n"))))
        ;; Counted consume. A three-clause `cond` -- zero count, exhausted, commit
        ;; -- and NOT the shared exhausted-input preamble, because the zero-count
        ;; test comes first and the preamble opens with exhaustion. The zero-count
        ;; clause is `zero-width-jump`, a call, carrying the position kind
        ;; through. `n` is the committed count, the one local this arm adds to
        ;; reserved-member-3; the subtraction is exact and count completion wins by
        ;; construction -- `n = v` continues whether or not input remains.
        ((counted-consume)
         (let* ((fname (car (normal-field-arguments s)))
                (slot (num (car (field-slot-width fields fname))))
                (next-id (car (normal-field-targets s))))
           (string-append
            "      (define (%s" id " pos st off pk)" "\n"
            "       (let ((v (vector-ref fieldv " slot ")))\n"
            "         (cond ((= v 0) " (zero-width-jump next-id) ")\n"
            "               ((>= pos end)\n"
            "                (if finish?\n"
            "                    " (render-eof-branch (normal-dispatch-eof s) id
                                                     (string->symbol (nm (normal-state-id s)))
                                                     (normal-error-reason s) index-of) "\n"
            "                    (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off)))\n"
            "               (else\n"
            "                (let ((n (min v (- end pos))))\n"
            "                  (vector-set! fieldv " slot " (- v n))\n"
            "                  (if (= n v)\n"
            "                      (%s" (num next-id) " (+ pos n) " (num next-id) " (+ off n) (quote boundary))\n"
            "                      (byte-machine-make-feed-outcome/v1 (quote need-input) (+ pos n) #f " id " (+ off n))))))))\n")))
        ((dispatch)
         (let ((fb (normal-dispatch-fallback s)))
           (string-append
            (render-exhausted-preamble s id names index-of nm)
            "           (let ((b (bytevector-u8-ref bv pos)))\n"
            "             (cond\n"
            (render-byte-clauses (normal-dispatch-transitions s))
            "               (else " (loop-tail (car fb) (cdr fb)) ")))))\n")))
        ;; Keyword table. ONE arm: it reads the parked prefix from a compound
        ;; `st` (empty on fresh entry), calls the runtime walk over its embedded
        ;; entries, and either jumps to the walk's chosen target, parks the
        ;; grown prefix as the compound (id . path) and yields need-input, or --
        ;; under finish? -- takes the eof route. `off` advances by the bytes THIS
        ;; feed consumed, `(- (caddr r) pos)`; the delimiter is left unread (a jump
        ;; carries `pk` `byte` for a taken keyword). `%dispatch` extracts the id
        ;; from the compound (render-machine emits that extraction only when a
        ;; machine has a keyword table).
        ((keyword-table)
         (let ((kwid (number->string (normal-state-id s)))
               (nomatch (normal-keyword-no-match s)))
           (string-append
            "      (define (%s" id " pos st off pk)\n"
            "       (let* ((kpath (if (pair? st) (cdr st) (quote ())))\n"
            "              (r (byte-machine-keyword-step/v1 (quote "
            (render-kw-entries (normal-keyword-entries s)) ") (quote ("
            (num (car nomatch)) " . " (symbol->string (cdr nomatch)) ")) "
            (if (normal-keyword-ci? s) "#t" "#f") " kpath bv pos end)))\n"
            "         (if (eq? (car r) (quote jump))\n"
            "             (%dispatch (caddr r) (cadr r) (+ off (- (caddr r) pos)) (cadddr r))\n"
            "             (if finish?\n"
            "                 " (render-eof-branch (normal-dispatch-eof s) id
                                                  (string->symbol (nm (normal-state-id s)))
                                                  (normal-error-reason s) index-of) "\n"
            "                 (byte-machine-make-feed-outcome/v1 (quote need-input) (caddr r) #f (cons "
            kwid " (cadr r)) (+ off (- (caddr r) pos)))))))\n")))
        ;; Unreachable -- this case covers every kind
        ;; normal-state-kind can produce: dispatch, keyword-table, stop, error,
        ;; finish, pause, field-action, field-branch, accumulate, callback,
        ;; span-start, span-end, span-completion, and counted-consume -- FOURTEEN.
        ;; Verified by inspection (same convention as normal-ir.sls's own else).
        (else (assertion-violation 'render-machine "unknown state kind"
                                   (normal-state-kind s))))))

  ;; render-machine : Compilation Symbol -> Bytevector
  (define (render-machine compilation binding)
    (unless (compilation-ok? compilation)
      (assertion-violation 'render-machine "cannot render an unverified machine"
                           (compilation-diagnostics compilation)))
    (validate-binding binding)
    (let* ((normal (compilation-normal compilation))
           (mname (symbol->string (machine-name (compilation-machine compilation))))
           (states (normal-machine-states normal))
           ;; `%dispatch` is a binary search whose leaves carry no test of their
           ;; own, which is sound only if the ids are exactly 0..N-1 in order.
           ;; Lowering assigns them that way (one per node, then one per
           ;; synthesised state), but this renderer would answer the WRONG state
           ;; for a gap rather than fail -- a live state routed to its
           ;; neighbour, which no fixture is obliged to notice. So it is checked
           ;; here, at emit time, where the failure is loud and local.
           (ignore-id-check
            (let idloop ((i 0))
              (cond ((>= i (vector-length states)) #t)
                    ((= (normal-state-id (vector-ref states i)) i) (idloop (+ i 1)))
                    (else (assertion-violation
                           'render-machine
                           "state ids must be 0..N-1 in order for the dispatch search"
                           i (normal-state-id (vector-ref states i)))))))
           (entry (normal-machine-entry normal))
           (fp (normal-machine-fingerprint normal))
           (names (normal-machine-debug-map normal))
           ;; One entry per error DECLARATION, in declaration order -- the order
           ;; errcode already walks. Per-SITE literals would repeat each reason
           ;; once per error site, and the default-eof arm alone renders at every
           ;; dispatch state: the http-version machine has nine error sites over
           ;; two declarations. This is immutable field/callback/debug metadata,
           ;; carried as one quoted vector.
           ;; Only the declarations the NORMALIZED graph reaches. The encoding
           ;; writes a reason at exactly two sites -- an error state's, and a
           ;; dispatch state's default-eof routing -- so a declaration no node
           ;; names and that is not the machine default-eof never reaches the IR
           ;; fingerprint. Emitting it anyway would make two machines the
           ;; fingerprint calls identical emit DIFFERENT bytes. Narrowing here,
           ;; rather than widening the encoding, leaves the fingerprint encoding
           ;; as it is.
           (reached (let walk ((i 0) (acc '()))
                      (if (>= i (vector-length states)) (reverse acc)
                          (let* ((st (vector-ref states i))
                                 (r (normal-error-reason st))
                                 (c (cond ((eq? (normal-state-kind st) 'error)
                                           (normal-error-code st))
                                          ;; `accumulate` belongs here too: it
                                          ;; is the other INPUT-READING kind, it
                                          ;; carries an eof route in the same
                                          ;; slot, and render-exhausted-preamble
                                          ;; renders that route for both kinds
                                          ;; through the same code -- so an
                                          ;; accumulate node whose eof-target is
                                          ;; #f asks index-of for the machine
                                          ;; default declaration exactly as a
                                          ;; dispatch does. Testing only for
                                          ;; `dispatch` would leave that
                                          ;; declaration out of the reached set,
                                          ;; the filter below would drop it from
                                          ;; the errs table, and index-of would
                                          ;; then raise "no error declaration for
                                          ;; code" while rendering a machine the
                                          ;; verifier had just accepted.
                                          ((and (memq (normal-state-kind st)
                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))
                                                (eq? (car (normal-dispatch-eof st)) 'default))
                                           (cdr (normal-dispatch-eof st)))
                                          ;; A pause/callback state's OPTIONAL
                                          ;; reason carries its code in slot 5
                                          ;; and reason in slot 7 -- the error
                                          ;; state's slots -- so a pause-only code
                                          ;; (named by no error node) reaches the
                                          ;; errs table and index-of finds it
                                          ;; instead of raising at emit time. #f
                                          ;; in slot 5 means no reason and
                                          ;; contributes nothing.
                                          ((and (memq (normal-state-kind st)
                                                      '(pause callback))
                                                (normal-error-code st))
                                           (normal-error-code st))
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
           ;; duplicate codes or duplicate reasons and nothing requires uniqueness
           ;; -- so an UNREACHED declaration duplicating a reached one would pass
           ;; the membership test and be emitted, giving two machines with the
           ;; same IR fingerprint different emitted bytes.
           ;;
           ;; The LATER duplicate is dropped, so the surviving entry keeps its
           ;; declaration-order POSITION and a machine with no duplicate pair
           ;; gets the same table and indices as an unfiltered walk. The two
           ;; entries would be textually identical in any case -- an errs entry
           ;; is (code, reason) and nothing else -- so no site loses a reason it
           ;; could have rendered, which is what makes the drop safe rather than
           ;; merely convenient.
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
           ;; share a code -- pass-names rejects duplicate declaration NAMES,
           ;; nothing rejects duplicate codes, and nothing requires uniqueness --
           ;; and the normalizer has already collapsed the node's declaration name
           ;; to its resolved code by the time the emitter sees it. Keying on the
           ;; code alone would return the FIRST declaration carrying it, so a
           ;; generated parser would report a different declaration's reason than
           ;; the interpreter, on a machine the verifier accepts with zero
           ;; diagnostics. The normalized state carries the right reason in its
           ;; own slot, so (code, reason) selects the entry the SITE produced, and
           ;; when two declarations agree on both, their errs entries are identical
           ;; and either index yields the same record -- so this is total.
           (index-of (lambda (code reason)
                       (let walk ((ds decls) (i 0))
                         (cond ((null? ds)
                                ;; Unreachable: every code/reason pair the
                                ;; emitter asks about was resolved FROM this
                                ;; same list by the normalizer. Loud rather than
                                ;; a silent fallback to 0.
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
           ;; Member 0 renders the field DECLARATIONS as (name . initial) pairs in
           ;; slot order, not bare initials: the parser needs the initials AND the
           ;; name-to-slot resolution parser-field-ref answers by, the slot is the
           ;; pair's position, so one member determines both.
           ;;
           ;; Rendered from the NORMALIZED table rather than from machine-fields,
           ;; so the emitted slot order is the same object the IR fingerprint was
           ;; computed over. Reading the source machine again would let the two
           ;; disagree with nothing to notice.
           ;; Member 1. Four parts per callback -- name, kind, required?,
           ;; default-branch -- which is everything binding resolution needs and
           ;; nothing more. Branch KEYS stay behind: they are settled before a
           ;; parser exists, so carrying them across the seam would ship data no
           ;; runtime reads. Empty for a machine that declares no callback.
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
           ;; ABI payload member 3: the settable table, `(name width)` per
           ;; SETTABLE field. Member 0 carries `(name . initial)` with no width,
           ;; so the generated `make-parser` cannot range-check an embedder
           ;; override without this. It is an OPTIONAL member, emitted only when
           ;; some field is settable (`settable?` is the field record's 5th
           ;; element, `list-ref 4`; `cadr` is the width) -- a machine with none
           ;; emits members 0-2 only.
           (settable (let loop ((fs (normal-machine-fields normal)) (acc ""))
                       (if (null? fs) acc
                           (loop (cdr fs)
                                 (if (list-ref (car fs) 4)
                                     (string-append
                                      acc (if (string=? acc "") "" " ")
                                      "(" (symbol->string (car (car fs)))
                                      " " (number->string (cadr (car fs))) ")")
                                     acc)))))
           ;; ABI payload member 2: the state-id to SOURCE-NAME table, as a vector
           ;; indexed by state id. It is what makes `parser-state-name` answerable
           ;; in the generated lane; the debug map is otherwise read at exactly one
           ;; site, at emission time, and never crosses the seam.
           ;;
           ;; Rendered here rather than as a separate top-level `define`: the
           ;; emitted library exports ONE name and the compiled-machine
           ;; constructor's five arguments are the only channel to the runtime, so
           ;; a top-level definition would still have to be passed in. It is a
           ;; rendering choice, not a third transport: the payload carries the
           ;; table either way.
           ;;
           ;; Total over internal prefix states, so a lowered sequence position
           ;; answers with its DECLARING node's public name.
           (snames (let sloop ((i 0) (acc ""))
                     (if (>= i (vector-length states)) acc
                         (sloop (+ i 1)
                                (string-append
                                 acc (if (string=? acc "") "" " ")
                                 (symbol->string
                                  (let ((hit (assv i names)))
                                    (unless hit
                                      (assertion-violation
                                       'render-machine
                                       "no source name for normalized state" i))
                                    (cdr hit))))))))
           ;; True when any state is a keyword table. Only then does `%dispatch`
           ;; need to extract the state id from a compound `st` (a keyword
           ;; table's cross-feed resume) -- a machine without one dispatches on
           ;; `st` directly.
           (has-kw (let hk ((i 0))
                     (cond ((>= i (vector-length states)) #f)
                           ((eq? (normal-state-kind (vector-ref states i)) 'keyword-table) #t)
                           (else (hk (+ i 1))))))
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
        ;; current stream offset regardless of which call observes it. Keying this
        ;; on finish? would make both lanes report `eof` at the default-EOF arm
        ;; and make that arm's own literal observationally identical to the
        ;; inherited variable -- agreement bought by making the difference
        ;; unobservable.
        ;; EVERY STATE IS A PROCEDURE, AND A TRANSITION IS A DIRECT TAIL CALL.
        ;; One `(case st ...)` re-entered per transition is what Chez compiles
        ;; as a LINEAR SCAN: measured on Chez 10.4.1 over a 530-arm case, the arm
        ;; at index 5 dispatches in 1.90ns and the arm at index 295 in 93.15ns --
        ;; about 0.31ns per arm skipped, the total arm count irrelevant,
        ;; identical at optimize-level 0, 2 and 3. A machine's cost would then
        ;; depend on where normalization happened to number its hot states,
        ;; which is not a property anyone chose. As mutually tail-calling
        ;; procedures that never escape, a transition to a target known at emit
        ;; time is a direct jump: 0.80ns against 185.85ns for the same arm, and
        ;; independent of the state's id. Bucketing the case into nested range
        ;; tests plateaus near 11.65ns, so it is not what this emits.
        (let loop ((i 0) (acc ""))
          (if (>= i (vector-length states)) acc
              (loop (+ i 1) (string-append acc (render-state-arm (vector-ref states i)
                                                                 names index-of
                                                                 (normal-machine-fields normal)
                                                                 (normal-machine-span-decls normal))))))
        ;; The one search over state ids, and the two places that enter it: the
        ;; entry into a feed, and a keyword table's jump. A callback answering
        ;; `goto` does not: `render-goto-clauses` above tests the literals that
        ;; arm already wrote, and reaches this only on a target no construction
        ;; produces.
        ;;
        ;; The feed entry is once per `parser-feed!` call and genuinely cannot be
        ;; a literal -- the state comes from the parser. The keyword jump's target
        ;; set IS known here (the table's entries and its no-match edge), so the
        ;; literal-clause treatment could apply to it too; it is not used, and
        ;; the jump pays the ceil(log2 N) search below instead.
        "      (define (%dispatch pos st off pk)\n"
        ;; A machine with no keyword table binds nothing: its key IS `st`, and
        ;; the `let` would be a name in the emitted text for no reason. The
        ;; keyword shape binds `n` -- already in reserved-member-3, so the set
        ;; of legal output bindings does not narrow for this.
        (let ((key (if has-kw "n" "st"))
              (count (vector-length states)))
          (string-append
           (if has-kw "        (let ((n (if (pair? st) (car st) st)))\n" "")
           (if has-kw "  " "")
           "        (if (and (fixnum? " key ") (fx>=? " key " 0) (fx<? " key " "
           (num count) "))\n"
           (render-dispatch-tree key 0 count (if has-kw 14 12)) "\n"
           (if has-kw "  " "")
           "            (assertion-violation (quote exec) \"unknown state\" st))"
           (if has-kw ")" "") ")\n"))
        "      (%dispatch start state offset (quote boundary)))\n"
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine 9 " (number->string fp) " "
        (number->string entry) " exec (quote #(#(" fields ") #(" cbs ") #("
        snames ")"
        ;; The optional fourth member: emitted only when a field is settable, so
        ;; a machine with none renders three-member metadata -- the same
        ;; present-only rule as the fingerprint's tag-10 trailing section. The
        ;; runtime decoder length-guards it (absent => no settable field =>
        ;; every override refused).
        (if (string=? settable "") "" (string-append " #(" settable ")"))
        ")))))\n"))))

  ;; emit-machine : Compilation Symbol Port -> Any
  ;; Writes the rendered bytes to the binary output port; returns an
  ;; emission-metadata vector carrying the fingerprint and byte length.
  (define (emit-machine compilation binding port)
    (let ((bytes (render-machine compilation binding)))
      (put-bytevector port bytes)
      (vector 'emission-metadata
              (normal-machine-fingerprint (compilation-normal compilation))
              (bytevector-length bytes)))))
