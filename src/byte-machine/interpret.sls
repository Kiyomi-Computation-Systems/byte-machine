;;; (byte-machine interpret): the reference interpreter — the semantic oracle.
;;; It turns a *verification* (which carries its machine, §9.2) into a
;;; runtime-compatible compiled-machine by closing an `op` over the verified IR.
;;; It refuses an unverified/failed machine (§16.1) and never touches the
;;; normalizer or generated code (§18). Error references are symbolic names,
;;; resolved here against the machine's error declarations.
(library (byte-machine interpret)
  (export make-interpreted-machine)
  (import (rnrs)
          (byte-machine private ir)
          (byte-machine private conditions)
          (byte-machine verify)
          (byte-machine runtime))

  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (lookup-error errors name)
    (cond ((null? errors) #f)
          ((eq? (error-declaration-name (car errors)) name) (car errors))
          (else (lookup-error (cdr errors) name))))

  (define (make-interpreted-machine verification)
    (unless (verification-ok? verification)
      (byte-machine-contract-violation 'make-interpreted-machine
                                       'unverified-machine
                                       (verification-diagnostics verification)))
    (let* ((m (verification-machine verification))
           (nodes (machine-nodes m))
           (errors (machine-errors m)))
      ;; `current` is either a declared node NAME or, inside a sequence, the
      ;; compound (name . path) where path is the byte list consumed so far.
      ;; The PATH -- not a bare position index -- is what keeps alternatives that
      ;; diverge at position 0 apart: with AB and XY, after consuming A a
      ;; position index would find Y at position 1 in SOME alternative and follow
      ;; XY. Derived independently of the normalizer (§18:970-972, decision 0015
      ;; point 3): this library imports no normalizer library and shares no
      ;; prefix walker with one. That independence is what lets the
      ;; interpreter≡generated differential catch a lowering defect at all, so a
      ;; proposal to factor "the shared prefix walker" into a common library is a
      ;; change to decision 0015, not a refactor.
      (define (prefix? p bs)
        (cond ((null? p) #t)
              ((null? bs) #f)
              ((= (car p) (car bs)) (prefix? (cdr p) (cdr bs)))
              (else #f)))
      (define (seq-step n path byte)
        (let* ((k (length path))
               (new (append path (list byte)))
               (hit (filter (lambda (c)
                              (let ((bs (sequence-case-bytes c)))
                                (and (> (length bs) k) (prefix? new bs))))
                            (sequence-dispatch-node-cases n)))
               (ends (filter (lambda (c) (= (length (sequence-case-bytes c)) (length new))) hit))
               (conts (filter (lambda (c) (> (length (sequence-case-bytes c)) (length new))) hit)))
          (cond ((null? hit)
                 ;; §10.6:546 -- already consumed prefix bytes remain consumed,
                 ;; and the declared mismatch edge decides whether the mismatching
                 ;; byte advances or is reexecuted.
                 (let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))
                ;; The same two internal invariants the normalizer's trie asserts,
                ;; for the same reason (decision 0015 point 2): a prefix position
                ;; that both accepts and continues has no representation here
                ;; either. Slice ③'s §16.2:894 pass rejects both shapes before
                ;; this point, and make-interpreted-machine refuses an unverified
                ;; machine -- so these are unreachable through the public path and
                ;; kept as defense-in-depth, exactly as normal-ir.sls's are.
                ((and (pair? ends) (pair? conts))
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))
                ((> (length ends) 1)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))
                ;; A successful alternative consumes every byte in it, so the last
                ;; step always advances into the declared target.
                ((pair? ends) (cons (sequence-case-target (car ends)) 'advance))
                (else (cons (cons (sequence-dispatch-node-name n) new) 'advance)))))
      ;; *** THE INTERPRETER'S OWN SUBSTEP REPRESENTATION, and §18:972 requires
      ;; it to be its own. *** "Interpreter-private state may track progress
      ;; inside a high-level source node ... but that representation must be
      ;; derived independently from the production normalizer." The normalizer
      ;; answers with a NUMBERED internal state (§14:841's `completion-pending`,
      ;; lowered to its own id); this answers with the compound
      ;; `(span-end-name . completion-pending)` -- a symbol cdr, where a
      ;; mid-sequence compound's cdr is a non-empty list of consumed bytes, so
      ;; the two compounds are told apart structurally and neither had to change
      ;; to admit the other.
      ;;
      ;; Sharing the normalizer's numbering instead would be a change to decision
      ;; 0015, not a refactor: it is precisely this independence that lets the
      ;; differential catch a lowering defect in the substep chain.
      (define (completion-state n) (cons (node-name n) 'completion-pending))
      (define (completion? name) (and (pair? name) (symbol? (cdr name))))
      (define (kind name)
        (if (pair? name)
            (if (completion? name) 'span-completion 'dispatch)
            (let ((n (lookup nodes name)))
              (cond ((byte-dispatch-node? n) 'dispatch)
                    ((sequence-dispatch-node? n) 'dispatch)
                    ((stop-node? n) 'stop)
                    ((error-node? n) 'error)
                    ((finish-node? n) 'finish)
                    ((pause-node? n) 'pause)
                    ((field-action-node? n) 'field-action)
                    ((field-branch-node? n) 'field-branch)
                    ((integer-accumulate-node? n) 'accumulate)
                    ((callback-node? n) 'callback)
                    ((span-start-node? n) 'span-start)
                    ((span-end-node? n) 'span-end)
                    ((counted-consume-node? n) 'counted-consume)
                    (else (byte-machine-contract-violation 'interpret 'internal name))))))
      (define (dispatch name byte)
        (if (pair? name)
            (seq-step (lookup nodes (car name)) (cdr name) byte)
            (let ((n (lookup nodes name)))
              (if (sequence-dispatch-node? n)
                  (seq-step n '() byte)
                  (let loop ((cs (byte-dispatch-node-cases n)))
                    (cond ((null? cs)
                           (let ((e (byte-dispatch-node-fallback n)))
                             (cons (edge-target e) (edge-mode e))))
                          ((memv byte (matcher-bytes (byte-case-matcher (car cs))))
                           (let ((e (byte-case-edge (car cs))))
                             (cons (edge-target e) (edge-mode e))))
                          (else (loop (cdr cs)))))))))
      ;; §12.7:777 makes source-node name, domain, code, offset and position
      ;; kind semantic and required to match across executors, and excludes the
      ;; internal state id. This lane answers with the node's DECLARATION INDEX
      ;; -- its position in machine-nodes, the same mapping lower-machine builds
      ;; as name->id -- which is this executor's own deterministic choice, not a
      ;; requirement that it equal the generated lane's.
      (define (declaration-index name)
        (let walk ((ns nodes) (i 0))
          (cond ((null? ns)
                 ;; LOUD, not 0. Zero is the entry state's own id, so falling
                 ;; back to it reports a plausible, wrong state id rather than a
                 ;; defect -- and §12.7:777 makes the id a value both lanes must
                 ;; report. Unreachable through the public API: every name handed
                 ;; here came from a node the verifier already resolved.
                 (byte-machine-contract-violation 'interpret 'internal name))
                ((eq? (node-name (car ns)) name) i)
                (else (walk (cdr ns) (+ i 1))))))
      ;; Both producers hand the runtime the record's inputs rather than a bare
      ;; code, so the two executors build the SAME record from the same parts.
      ;; The runtime supplies the offset and the position kind, which only the
      ;; loop knows.
      (define (error-parts name)
        (let ((d (lookup-error errors (error-node-error-name (lookup nodes name)))))
          (list (error-declaration-code d) (error-declaration-reason d)
                name (declaration-index name))))
      ;; A default-EOF error has no error node, so its node-name is the DISPATCH
      ;; node's -- the one whose EOF-target chain was exhausted, which is where
      ;; truncation was detected. `node` must be unwrapped first: for a lowered
      ;; sequence prefix state it is the compound (node-name . consumed-bytes)
      ;; pair, and that is the common case rather than the exception.
      (define (default-eof-parts node)
        (let ((nm (if (pair? node) (car node) node))
              (d (lookup-error errors (machine-default-eof-error m))))
          (list (error-declaration-code d) (error-declaration-reason d)
                nm (declaration-index nm))))
      ;; Every lowered prefix state inherits the source node's EOF edge
      ;; (§12.4:727), so a compound current answers with its own node's.
      ;; *** §4.7 item 4's hazard, and it was LIVE. *** This was a two-way `if`
      ;; with no else arm, so any kind that is not a sequence node fell through
      ;; into `byte-dispatch-node-eof-target` -- a bare `(vector-ref n 4)` with no
      ;; tag guard. On an integer-accumulate node slot 4 is `digit-target`, a
      ;; SYMBOL, so it would have returned a plausible-looking node name and
      ;; silently routed EOF into the digit path. Measured against the shipped
      ;; accessor before this was rewritten.
      ;;
      ;; A `cond` with an arm per kind and a LOUD else, matching the convention
      ;; every other per-kind analysis in this project uses: a kind that reaches
      ;; here without an arm must crash, not answer.
      (define (eof-target-of cur)
        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))
          (cond ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
                ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
                ((integer-accumulate-node? n) (integer-accumulate-node-eof-target n))
                ;; Milestone 6 Slice ①: without this arm a parked counted consume
                ;; raises out of parser-finish!, which is the loud else doing
                ;; its job.
                ((counted-consume-node? n) (counted-consume-node-eof-target n))
                (else (byte-machine-contract-violation 'interpret 'internal
                                                       (node-name n))))))
      ;; --- Milestone 5 Slice ②: the callback node, interpreter side ---------
      ;; The slot IS the declaration position (§17:962, §10.3:508), which is what
      ;; the normalizer's own `callback-slot-of` resolves in the other lane --
      ;; the two are separate walks over the same list by decision 0015 point 3,
      ;; not a shared helper.
      (define (callback-slot nm)
        (let walk ((cs (machine-callbacks m)) (i 0))
          (cond ((null? cs) (byte-machine-contract-violation 'interpret 'internal nm))
                ((eq? (callback-declaration-name (car cs)) nm) i)
                (else (walk (cdr cs) (+ i 1))))))
      (define (callback-decl nm)
        (let walk ((cs (machine-callbacks m)))
          (cond ((null? cs) (byte-machine-contract-violation 'interpret 'internal nm))
                ((eq? (callback-declaration-name (car cs)) nm) (car cs))
                (else (walk (cdr cs))))))
      ;; §9.3:419: "An optional decision callback must declare `default-branch`;
      ;; other optional callbacks default to `continue`." Resolved to a TARGET
      ;; here so the invocation site is one jump and carries no rule -- decision
      ;; 0028 item 3's short circuit reads it and never calls a closure.
      ;;
      ;; #f for a REQUIRED callback: its slot can never hold the sentinel, so
      ;; there is no default to take, and #f is what says so rather than a
      ;; plausible target no execution reaches.
      (define (callback-default n)
        (let ((d (callback-decl (callback-node-callback n))))
          (cond ((callback-declaration-required? d) #f)
                ((eq? (callback-declaration-kind d) 'decision)
                 (let ((hit (assq (callback-declaration-default-branch d)
                                  (map (lambda (b) (cons (car b) (cadr b)))
                                       (callback-node-branch-targets n)))))
                   ;; Unreachable once §16.2:901's node half runs: it requires an
                   ;; optional decision callback's node to declare a target for
                   ;; the default branch. Loud rather than #f, which would look
                   ;; like a required callback here.
                   (unless hit
                     (byte-machine-contract-violation 'interpret 'internal
                                                      (callback-node-name n)))
                   (cdr hit)))
                (else (callback-node-continue-target n)))))
      (define (callback-parts n)
        (list (callback-slot (callback-node-callback n))
              (callback-node-continue-target n)
              (map (lambda (b) (cons (car b) (cadr b)))
                   (callback-node-branch-targets n))
              (callback-node-pause-continuation n)
              (callback-default n)
              (declaration-index (callback-node-name n))))
      ;; --- Slice ③'s span parts, interpreter side ---
      ;; Resolved the same way `callback-parts` resolves a callback node's, and
      ;; separately from the normalizer's `span-slot-of`/`cb-slot` for decision
      ;; 0015 point 3's reason: two walks over one list, not one shared helper.
      ;;
      ;; A span's DATA callback is required by the declaration (§10.4:516 makes
      ;; only the completion one optional), but the callback DECLARATION it names
      ;; may itself be optional -- so both slots can hold the unbound sentinel and
      ;; both invocation paths short-circuit on it.
      (define (span-decl nm)
        (let walk ((sp (machine-spans m)))
          (cond ((null? sp) (byte-machine-contract-violation 'interpret 'internal nm))
                ((eq? (span-declaration-name (car sp)) nm) (car sp))
                (else (walk (cdr sp))))))
      (define (span-slot nm)
        (let walk ((sp (machine-spans m)) (i 0))
          (cond ((null? sp) (byte-machine-contract-violation 'interpret 'internal nm))
                ((eq? (span-declaration-name (car sp)) nm) i)
                (else (walk (cdr sp) (+ i 1))))))
      (define (span-start-parts n)
        (list (span-start-node-span n)
              (callback-slot (span-declaration-data-callback
                              (span-decl (span-start-node-span n))))
              (span-start-node-next n)))
      ;; The span END's parts stop at the completion substep: §14:838 resumes "at
      ;; the next undelivered substep", so the fragment step's continuation is
      ;; the substep and never the node's own successor -- that successor belongs
      ;; to `span-completion-parts` below and is unreachable from here.
      (define (span-end-parts n)
        (list (callback-slot (span-declaration-data-callback
                              (span-decl (span-end-node-span n))))
              (completion-state n)
              (span-slot (span-end-node-span n))
              (node-name n)))
      ;; The completion callback is OPTIONAL (§10.4:516). `#f` reaches the slot
      ;; lookup as no lookup at all: `-1` would index, and a plausible slot is
      ;; worse than none. The runtime arm reads this and skips the invocation.
      (define (span-completion-parts name)
        (let* ((n (lookup nodes (car name)))
               (c (span-declaration-complete-callback (span-decl (span-end-node-span n)))))
          (list (and c (callback-slot c))
                (span-end-node-next n)
                (span-slot (span-end-node-span n))
                (car name))))
      ;; --- Slice ②'s field semantics, interpreter side ---
      ;; Slot = declaration index (§17:962), so the slot and the width come from
      ;; the same walk over machine-fields and cannot disagree.
      (define (field-slot-and-width fname)
        (let loop ((fs (machine-fields m)) (i 0))
          (cond ((null? fs) (byte-machine-contract-violation 'interpret 'internal fname))
                ((eq? (uint-field-name (car fs)) fname) (cons i (uint-field-width (car fs))))
                (else (loop (cdr fs) (+ i 1))))))
      (define (field-max width) (- (expt 2 width) 1))
      ;; §25:1569 and §10.6:568: a failed operation leaves the prior value
      ;; UNCHANGED. That is why every arm computes first and commits last -- there
      ;; is no partial write to undo, because there is no partial write.
      (define (field-action-step n fv)
        (let* ((args (field-action-node-arguments n))
               (sw (field-slot-and-width (car args)))
               (slot (car sw)) (m* (field-max (cdr sw)))
               (v (vector-ref fv slot))
               (k (and (pair? (cdr args)) (cadr args)))
               (r (case (field-action-node-operation n)
                    ((store) k)
                    ((clear) 0)
                    ((increment) (+ v 1))
                    ((decrement) (- v 1))
                    ((add) (+ v k))
                    ((set-mask) (bitwise-ior v k))
                    ((clear-mask) (bitwise-and v (bitwise-not k)))
                    (else (byte-machine-contract-violation 'interpret 'internal 'operation)))))
          (if (<= 0 r m*)
              (begin (vector-set! fv slot r) (field-action-node-next n))
              ;; Overflow or underflow. The value is not written, and the target
              ;; is the declared error node -- which the constructor guarantees
              ;; exists, because it is #f exactly when the operation cannot fail.
              (field-action-node-error n))))
      (define (field-branch-step n fv)
        (let* ((args (field-branch-node-arguments n))
               (sw (field-slot-and-width (car args)))
               (v (vector-ref fv (car sw)))
               (a (and (pair? (cdr args)) (cadr args)))
               (b (and (pair? (cdr args)) (pair? (cddr args)) (caddr args)))
               (yes (case (field-branch-node-predicate n)
                      ((equal) (= v a))
                      ((zero) (= v 0))
                      ((nonzero) (not (= v 0)))
                      ((range) (and (<= a v) (<= v b)))
                      ((mask-any) (not (= 0 (bitwise-and v a))))
                      ((mask-all) (= a (bitwise-and v a)))
                      ((mask-none) (= 0 (bitwise-and v a)))
                      (else (byte-machine-contract-violation 'interpret 'internal 'predicate)))))
          (if yes (field-branch-node-true-target n) (field-branch-node-false-target n))))

      ;; --- Slice ③: the checked multiply-add, interpreter side ---
      ;; §15:864-868 gives the inequality, and gives it as a check BEFORE the
      ;; operation, not a compute-then-check:
      ;;     current <= floor((maximum - digit) / base)
      ;; That shape is the spec's, and §15:856 says why -- "must not rely on host
      ;; fixnum width or silent wrapping". Computing `cur * base + d` first and
      ;; testing the product is safe under Chez's bignums and would NOT be safe
      ;; under a host that wraps, so the pre-check is what gets written.
      ;; When `d` exceeds the maximum the numerator goes negative and the
      ;; comparison fails for every non-negative `cur`, which is correct.
      (define (digit-value byte base)
        (let ((v (cond ((and (>= byte 48) (<= byte 57)) (- byte 48))
                       ((and (>= byte 97) (<= byte 102)) (+ 10 (- byte 97)))
                       ((and (>= byte 65) (<= byte 70)) (+ 10 (- byte 65)))
                       (else #f))))
          (and v (< v base) v)))
      ;; Counted consume (Milestone 6 Slice ①; decision 0030 items 1 and 4). The
      ;; op RECEIVES the parser's field vector and COMMITS into it; the runtime
      ;; only routes the target it answers. THE ZERO-COUNT TEST COMES FIRST: a
      ;; zero count transitions immediately (§10.6:600) before `pos` and `end`
      ;; are looked at, so a zero count over an empty slice answers `(0 . next)`
      ;; and only a positive count over an empty slice answers `(0 . #f)`, the
      ;; EOF route. Count completion wins by construction: `k = v` continues at
      ;; `next` whether or not `pos + k = end` (§10.6:603). The subtraction is
      ;; exact and cannot underflow -- `k` never exceeds `v` (§15:872) -- and it
      ;; is bignum arithmetic on a u64 count above the fixnum range (§15:856).
      (define (count-step n fv pos end)
        (let* ((slot (car (field-slot-and-width (counted-consume-node-field n))))
               (v (vector-ref fv slot)))
          (if (= v 0)
              (cons 0 (counted-consume-node-next n))
              (let ((k (min v (- end pos))))
                (vector-set! fv slot (- v k))
                (cons k (if (= k v) (counted-consume-node-next n) #f))))))
      (define (accumulate-step n fv byte)
        (let* ((fname (integer-accumulate-node-field n))
               (sw (field-slot-and-width fname))
               (slot (car sw)) (m* (field-max (cdr sw)))
               (base (integer-accumulate-node-base n))
               (d (digit-value byte base)))
          (cond
           ((not d)
            ;; §10.6:567: the non-digit takes its explicit fallback edge, whose
            ;; own mode decides whether the delimiter is re-read.
            (let ((e (integer-accumulate-node-nondigit-edge n)))
              (cons (edge-target e) (edge-mode e))))
           ((<= (vector-ref fv slot) (div (- m* d) base))
            (vector-set! fv slot (+ (* (vector-ref fv slot) base) d))
            (cons (integer-accumulate-node-digit-target n) 'advance))
           (else
            ;; §10.6:568, §15:870 and §12.7:772-773: the value is unchanged AND
            ;; the offending digit is not consumed, so the mode is reexecute and
            ;; the position kind the runtime reports is `byte`.
            (cons (integer-accumulate-node-overflow-error n) 'reexecute)))))

      (make-compiled-machine
       (lambda (msg . args)
         (case msg
           ((entry) (machine-entry m))
           ;; Slice ①b task 6. The interpreter answers from the verified source
           ;; machine; the generated lane reads the same shape out of the ABI
           ;; payload's member 0. Pairs, in declaration order, which IS slot
           ;; order (§17:962, design §6 task 5).
           ;; *** Slice ②'s checked arithmetic and predicate evaluation. The op
           ;; RECEIVES the parser's field vector and COMMITS into it; the runtime
           ;; only routes the target it answers. ***
           ;;
           ;; That shape is forced, and design §7's "the interpreter gains its
           ;; own field storage" is unbuildable: this closure is built once per
           ;; compiled machine and has no parser in scope, and runtime.sls
           ;; records the prohibition verbatim because Slice ①b hit it. There is
           ;; ONE store, parser slot 8, shared by both lanes.
           ;;
           ;; It is also the shape Slice ③ needs. If the op returned a VALUE for
           ;; the runtime to store, ③'s accumulate would force the runtime to
           ;; decide overflow-versus-digit, which puts §15:858-870's inequality
           ;; in runtime.sls where the generated library can reach it -- and a
           ;; lowering bug in overflow checking would stop being visible to the
           ;; differential, the single class of defect this milestone introduces.
           ;;
           ;; The arithmetic is written TWICE on purpose (§18:970-972, decision
           ;; 0015 point 3): this library derives field semantics from the source
           ;; IR and shares no helper with the emitter. Widths are read here from
           ;; `machine-fields`; the emitter reads them from the normalized table.
           ;; *** Slice ③'s accumulate step. A SEPARATE message from `field-step`,
           ;; returning `(target . mode)` rather than a bare target. ***
           ;;
           ;; The mode is unavoidable here -- a digit advances, a non-digit takes
           ;; its edge's own mode, and an overflow consumes nothing (§12.7:772) --
           ;; and widening `field-step`'s return to a pair would change every
           ;; zero-width arm Slice ② shipped for no gain, since those kinds have
           ;; no mode to carry. One message per shape.
           ((accumulate-step)
            (let* ((name (car args)) (fv (cadr args)) (byte (caddr args)))
              (accumulate-step (lookup nodes name) fv byte)))
           ;; Counted consume (Milestone 6 Slice ①; decision 0030 item 4). One
           ;; message per shape: `(count-step node fv pos end)` answers
           ;; `(committed . target)`, and the finish path asks it over an empty
           ;; slice and reads only the target -- `(0 . next)` is the zero-count
           ;; transition, `(0 . #f)` means take the EOF route.
           ((count-step)
            (let* ((name (car args)) (fv (cadr args)) (pos (caddr args)) (end (cadddr args)))
              (count-step (lookup nodes name) fv pos end)))
           ;; *** OWED HERE TOO, AND THIS IS THE HARDER END. *** `§12.7:770`'s
           ;; machine-action half is still wrong (the emitted arms carry the
           ;; other end of this note, at `compile.sls`'s `field-action`). The
           ;; obstacle is right here: this shared arm cannot tell a SUCCESS jump
           ;; from a FAILURE jump, so `field-step` has to say which route it
           ;; took. That is a widened return -- exactly what the `accumulate-step`
           ;; comment above declines to do for its own reason -- or a new
           ;; executor message. Whoever takes it should read both comments
           ;; together, because the argument for one message per shape is what
           ;; makes the widened return the wrong first instinct.
           ;;
           ;; Deferred by Milestone 5's close-out (Slice ④, 2026-09-06); the
           ;; adjudication is the §12.7 disposition in the parent plan, and this
           ;; note exists because the receiver is a role, not a step.
           ((field-step)
            (let* ((name (car args)) (fv (cadr args))
                   (n (lookup nodes name)))
              (if (field-action-node? n)
                  (field-action-step n fv)
                  (field-branch-step n fv))))
           ((field-initials)
            (list->vector (map (lambda (f) (cons (uint-field-name f)
                                                 (uint-field-initial f)))
                               (machine-fields m))))
           ;; Milestone 5 Slice ①b. The same per-lane asymmetry the field table
           ;; established: this lane holds the verified source machine and is
           ;; asked, the generated lane reads the equivalent shape out of ABI
           ;; payload member 1. Four parts per callback, which is everything
           ;; §9.3:419's resolution needs and nothing more -- the branch KEYS are
           ;; a verifier concern (§16.2:901/:902, pass-declarations) and are not
           ;; carried across the seam.
           ((callback-decls)
            (list->vector
             (map (lambda (c) (vector (callback-declaration-name c)
                                      (callback-declaration-kind c)
                                      (callback-declaration-required? c)
                                      (callback-declaration-default-branch c)))
                  (machine-callbacks m))))
           ;; Milestone 5 Slice ②. Six parts -- slot, continue target, branch
           ;; map, pause continuation, default target, declaration index -- and
           ;; the generated lane renders the same six as literals into its own
           ;; arm. The runtime routes them through one shared
           ;; `byte-machine-callback-step/v1`, so the OUTCOME vocabulary is
           ;; identical in both lanes while the targets stay each lane's own.
           ((callback-parts) (callback-parts (lookup nodes (car args))))
           ;; Slice ③'s three span messages. Each answers what its arm needs and
           ;; nothing more, in the shape `callback-parts` established: slots and
           ;; targets resolved here, outcome vocabulary owned by the runtime.
           ((span-start-parts) (span-start-parts (lookup nodes (car args))))
           ((span-end-parts) (span-end-parts (lookup nodes (car args))))
           ((span-completion-parts) (span-completion-parts (car args)))
           ;; §9.3:408 / §13:820, Milestone 5 Slice ②. A bare SOURCE node name,
           ;; always: `current` is a declared node name, or the compound
           ;; (name . consumed-bytes) inside a lowered sequence, and §13:820
           ;; wants "the current source input node" in both cases. The generated
           ;; lane answers from ABI payload member 2's table, which is total over
           ;; its internal prefix states for exactly this reason.
           ((state-name) (let ((c (car args))) (if (pair? c) (car c) c)))
           ((kind) (kind (car args)))
           ((dispatch) (dispatch (car args) (cadr args)))
           ((error-value) (error-parts (car args)))
           ((eof-target) (eof-target-of (car args)))
           ((pause-target) (pause-node-continuation (lookup nodes (car args))))
           ((default-eof-value) (default-eof-parts (car args)))
           (else (byte-machine-contract-violation 'interpret 'internal msg))))))))
