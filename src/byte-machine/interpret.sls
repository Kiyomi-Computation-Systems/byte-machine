#!r6rs
;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine interpret): the reference interpreter — the semantic oracle.
;;; It turns a *verification* (which carries its machine) into a
;;; runtime-compatible compiled-machine by closing an `op` over the verified IR.
;;; It refuses an unverified/failed machine and never touches the normalizer or
;;; generated code. Error references are symbolic names, resolved here against
;;; the machine's error declarations.
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

  ;; make-interpreted-machine : VerificationResult -> CompiledMachine
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
      ;; XY. Derived independently of the normalizer: this library imports no
      ;; normalizer library and shares no prefix walker with one. That
      ;; independence is what lets the interpreter≡generated differential catch a
      ;; lowering defect at all, so this prefix walker is kept separate rather
      ;; than factored into a shared library.
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
                 ;; Already consumed prefix bytes remain consumed, and the
                 ;; declared mismatch edge decides whether the mismatching byte
                 ;; advances or is reexecuted.
                 (let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))
                ;; The same two internal invariants the normalizer's trie asserts,
                ;; for the same reason: a prefix position that both accepts and
                ;; continues has no representation here either. The verifier's
                ;; structural pass rejects both shapes before this point, and
                ;; make-interpreted-machine refuses an unverified machine -- so
                ;; these are unreachable through the public path and kept as
                ;; defense-in-depth, exactly as normal-ir.sls's are.
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
      ;; --- the keyword-table walk, interpreter side ---
      ;; Derived independently of the normalizer, like the sequence walker
      ;; above: the keyword table lowers to a compact table walked by a runtime
      ;; op, and this walker is the oracle that catches a lowering defect, so it
      ;; shares no helper with it. `current` inside a table is the compound
      ;; (name . path), path the bytes consumed so far -- the same shape
      ;; seq-step uses, so `kind`/`state-name`/`default-eof-parts` need no
      ;; keyword-table arm.
      ;;
      ;; Unlike a sequence, a position may be BOTH a complete keyword AND the
      ;; interior of a longer one (GET vs GET-PARAMETER). The rule: if the next
      ;; byte extends toward any keyword, consume it and go deeper;
      ;; otherwise take PATH's keyword if PATH is one (delimiter reexecuted, so a
      ;; span closes at the keyword's length), else the no-match edge. Greedy
      ;; forward, no backtracking: a byte consumed toward a longer keyword is
      ;; never returned.
      ;;
      ;; Case folding is per table: in a case-insensitive table an ASCII letter
      ;; matches either case, a byte with no case only itself. Written twice
      ;; (here and in the runtime op) on purpose -- shared nothing with the
      ;; emitter, so a fold defect in one lane is a differential result, not a
      ;; hidden agreement.
      (define (kw-fold b ci) (if (and ci (>= b 65) (<= b 90)) (+ b 32) b))
      (define (kw-prefix? ci p bs)      ; p a (folded) prefix of bs
        (cond ((null? p) #t)
              ((null? bs) #f)
              ((= (kw-fold (car p) ci) (kw-fold (car bs) ci)) (kw-prefix? ci (cdr p) (cdr bs)))
              (else #f)))
      (define (kw-terminal n ci path)   ; the entry whose bytes fold-equal `path`
        (let loop ((es (keyword-table-node-entries n)))
          (cond ((null? es) #f)
                ((let ((bs (keyword-entry-bytes (car es))))
                   (and (= (length bs) (length path)) (kw-prefix? ci path bs)))
                 (car es))
                (else (loop (cdr es))))))
      (define (kw-step n path byte)
        (let* ((ci (keyword-table-node-case-insensitive? n))
               (new (append path (list byte)))
               (continues (exists (lambda (e) (kw-prefix? ci new (keyword-entry-bytes e)))
                                  (keyword-table-node-entries n))))
          (if continues
              (cons (cons (keyword-table-node-name n) new) 'advance)
              (let ((term (kw-terminal n ci path)))
                (if term
                    ;; take the keyword; the delimiter is left unread.
                    (cons (keyword-entry-target term) 'reexecute)
                    (let ((mm (keyword-table-node-no-match n)))
                      (cons (edge-target mm) (edge-mode mm))))))))
      ;; The interpreter's own substep representation, derived independently from
      ;; the production normalizer. The normalizer answers with a NUMBERED
      ;; internal state (`completion-pending`, lowered to its own id); this
      ;; answers with the compound `(span-end-name . completion-pending)` -- a
      ;; symbol cdr, where a mid-sequence compound's cdr is a non-empty list of
      ;; consumed bytes, so the two compounds are told apart structurally and
      ;; neither had to change to admit the other.
      ;;
      ;; Keeping this numbering separate from the normalizer's is what lets the
      ;; differential catch a lowering defect in the substep chain.
      (define (completion-state n) (cons (node-name n) 'completion-pending))
      (define (completion? name) (and (pair? name) (symbol? (cdr name))))
      (define (kind name)
        (if (pair? name)
            (if (completion? name) 'span-completion 'dispatch)
            (let ((n (lookup nodes name)))
              (cond ((byte-dispatch-node? n) 'dispatch)
                    ((sequence-dispatch-node? n) 'dispatch)
                    ((keyword-table-node? n) 'dispatch)
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
            (let ((n (lookup nodes (car name))))
              (if (keyword-table-node? n)
                  (kw-step n (cdr name) byte)
                  (seq-step n (cdr name) byte)))
            (let ((n (lookup nodes name)))
              (cond
               ((keyword-table-node? n) (kw-step n '() byte))
               ((sequence-dispatch-node? n) (seq-step n '() byte))
               (else
                  (let loop ((cs (byte-dispatch-node-cases n)))
                    (cond ((null? cs)
                           (let ((e (byte-dispatch-node-fallback n)))
                             (cons (edge-target e) (edge-mode e))))
                          ((memv byte (matcher-bytes (byte-case-matcher (car cs))))
                           (let ((e (byte-case-edge (car cs))))
                             (cons (edge-target e) (edge-mode e))))
                          (else (loop (cdr cs))))))))))
      ;; Source-node name, domain, code, offset and position kind are semantic
      ;; and required to match across executors; the internal state id is
      ;; excluded. This lane answers with the node's DECLARATION INDEX -- its
      ;; position in machine-nodes, the same mapping lower-machine builds as
      ;; name->id -- which is this executor's own deterministic choice, not a
      ;; requirement that it equal the generated lane's.
      (define (declaration-index name)
        (let walk ((ns nodes) (i 0))
          (cond ((null? ns)
                 ;; LOUD, not 0. Zero is the entry state's own id, so falling
                 ;; back to it reports a plausible, wrong state id rather than a
                 ;; defect -- and the id is a value both lanes must report.
                 ;; Unreachable through the public API: every name handed here
                 ;; came from a node the verifier already resolved.
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
      ;; The OPTIONAL pause reason, for BOTH author-facing pause paths: a
      ;; `pause` node's own reason and a `callback` node's (reported when its
      ;; callback returns `callback-pause`). Same parts an error node's reason
      ;; produces -- (code reason node-name state-id) -- resolved from the node's
      ;; declared reason NAME, or #f when the node declares none. A
      ;; span-data/span-complete callback pause is NOT covered here: those are
      ;; internal fragment-resumption steps, not author-declared pause points,
      ;; and reach this only through a span node that has no reason -- so
      ;; `node-reason` returns #f for them.
      (define (node-reason node)
        (cond ((pause-node? node) (pause-node-reason node))
              ((callback-node? node) (callback-node-reason node))
              (else #f)))
      (define (pause-reason-parts name)
        (let ((rname (node-reason (lookup nodes name))))
          (and rname
               (let ((d (lookup-error errors rname)))
                 (list (error-declaration-code d) (error-declaration-reason d)
                       name (declaration-index name))))))
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
      ;; Every lowered prefix state inherits the source node's EOF edge, so a
      ;; compound current answers with its own node's. A `cond` with an arm per
      ;; kind and a LOUD else, matching the convention every other per-kind
      ;; analysis in this project uses: a kind that reaches here without an arm
      ;; must crash, not answer. A bare untagged slot read would instead return a
      ;; plausible-looking wrong node name -- e.g. an accumulate node's
      ;; `digit-target` symbol -- and silently route EOF into the wrong path.
      (define (eof-target-of cur)
        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))
          (cond ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
                ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
                ;; A keyword table is input-reading: a parser parked mid-table (a
                ;; compound `cur`) or on the bare node takes its own eof-target.
                ((keyword-table-node? n) (keyword-table-node-eof-target n))
                ((integer-accumulate-node? n) (integer-accumulate-node-eof-target n))
                ;; Without this arm a parked counted consume raises out of
                ;; parser-finish!, which is the loud else doing its job.
                ((counted-consume-node? n) (counted-consume-node-eof-target n))
                (else (byte-machine-contract-violation 'interpret 'internal
                                                       (node-name n))))))
      ;; --- the callback node, interpreter side ---
      ;; The slot IS the declaration position, which is what the normalizer's own
      ;; `callback-slot-of` resolves in the other lane -- the two are separate
      ;; walks over the same list, not a shared helper.
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
      ;; An optional decision callback must declare `default-branch`; other
      ;; optional callbacks default to `continue`. Resolved to a TARGET here so
      ;; the invocation site is one jump and carries no rule -- the short circuit
      ;; reads it and never calls a closure.
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
                   ;; Unreachable once the verifier's node check runs: it requires
                   ;; an optional decision callback's node to declare a target for
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
      ;; --- the span parts, interpreter side ---
      ;; Resolved the same way `callback-parts` resolves a callback node's, and
      ;; separately from the normalizer's `span-slot-of`/`cb-slot`, for the same
      ;; reason: two walks over one list, not one shared helper.
      ;;
      ;; A span's DATA callback is required by the declaration (only the
      ;; completion one is optional), but the callback DECLARATION it names may
      ;; itself be optional -- so both slots can hold the unbound sentinel and
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
      ;; The span END's parts stop at the completion substep: resumption is at
      ;; the next undelivered substep, so the fragment step's continuation is the
      ;; substep and never the node's own successor -- that successor belongs to
      ;; `span-completion-parts` below and is unreachable from here.
      (define (span-end-parts n)
        (list (callback-slot (span-declaration-data-callback
                              (span-decl (span-end-node-span n))))
              (completion-state n)
              (span-slot (span-end-node-span n))
              (node-name n)))
      ;; The completion callback is OPTIONAL. `#f` reaches the slot lookup as no
      ;; lookup at all: `-1` would index, and a plausible slot is worse than
      ;; none. The runtime arm reads this and skips the invocation.
      (define (span-completion-parts name)
        (let* ((n (lookup nodes (car name)))
               (c (span-declaration-complete-callback (span-decl (span-end-node-span n)))))
          (list (and c (callback-slot c))
                (span-end-node-next n)
                (span-slot (span-end-node-span n))
                (car name))))
      ;; --- the field semantics, interpreter side ---
      ;; Slot = declaration index, so the slot and the width come from the same
      ;; walk over machine-fields and cannot disagree.
      (define (field-slot-and-width fname)
        (let loop ((fs (machine-fields m)) (i 0))
          (cond ((null? fs) (byte-machine-contract-violation 'interpret 'internal fname))
                ((eq? (uint-field-name (car fs)) fname) (cons i (uint-field-width (car fs))))
                (else (loop (cdr fs) (+ i 1))))))
      (define (field-max width) (- (expt 2 width) 1))
      ;; A failed operation leaves the prior value UNCHANGED. That is why every
      ;; arm computes first and commits last -- there is no partial write to
      ;; undo, because there is no partial write.
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

      ;; --- the checked multiply-add, interpreter side ---
      ;; The inequality is a check BEFORE the operation, not a compute-then-check:
      ;;     current <= floor((maximum - digit) / base)
      ;; That shape must not rely on host fixnum width or silent wrapping.
      ;; Computing `cur * base + d` first and testing the product is safe under
      ;; Chez's bignums and would NOT be safe under a host that wraps, so the
      ;; pre-check is what gets written. When `d` exceeds the maximum the
      ;; numerator goes negative and the comparison fails for every non-negative
      ;; `cur`, which is correct. The emitter compares against the same bound
      ;; divided out into a quotient and remainder at emit time, so the two
      ;; lanes reach one answer by different arithmetic.
      (define (digit-value byte base)
        (let ((v (cond ((and (>= byte 48) (<= byte 57)) (- byte 48))
                       ((and (>= byte 97) (<= byte 102)) (+ 10 (- byte 97)))
                       ((and (>= byte 65) (<= byte 70)) (+ 10 (- byte 65)))
                       (else #f))))
          (and v (< v base) v)))
      ;; Counted consume. The op RECEIVES the parser's field vector and COMMITS
      ;; into it; the runtime only routes the target it answers. THE ZERO-COUNT
      ;; TEST COMES FIRST: a zero count transitions immediately before `pos` and
      ;; `end` are looked at, so a zero count over an empty slice answers
      ;; `(0 . next)` and only a positive count over an empty slice answers
      ;; `(0 . #f)`, the EOF route. Count completion wins by construction: `k = v`
      ;; continues at `next` whether or not `pos + k = end`. The subtraction is
      ;; exact and cannot underflow -- `k` never exceeds `v` -- and it is bignum
      ;; arithmetic on a u64 count above the fixnum range.
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
            ;; The non-digit takes its explicit fallback edge, whose own mode
            ;; decides whether the delimiter is re-read.
            (let ((e (integer-accumulate-node-nondigit-edge n)))
              (cons (edge-target e) (edge-mode e))))
           ((<= (vector-ref fv slot) (div (- m* d) base))
            (vector-set! fv slot (+ (* (vector-ref fv slot) base) d))
            (cons (integer-accumulate-node-digit-target n) 'advance))
           (else
            ;; The value is unchanged AND the offending digit is not consumed, so
            ;; the mode is reexecute and the position kind the runtime reports is
            ;; `byte`.
            (cons (integer-accumulate-node-overflow-error n) 'reexecute)))))

      (make-compiled-machine
       (lambda (msg . args)
         (case msg
           ((entry) (machine-entry m))
           ;; The interpreter answers from the verified source machine; the
           ;; generated lane reads the same shape out of the ABI payload's member
           ;; 0. Pairs, in declaration order, which IS slot order.
           ;;
           ;; The op RECEIVES the parser's field vector and COMMITS into it; the
           ;; runtime only routes the target it answers. That shape is forced: the
           ;; interpreter cannot gain its own field storage, because this closure
           ;; is built once per compiled machine and has no parser in scope. There
           ;; is ONE store, parser slot 8, shared by both lanes.
           ;;
           ;; If the op returned a VALUE for the runtime to store, accumulate
           ;; would force the runtime to decide overflow-versus-digit, which puts
           ;; the overflow inequality in runtime.sls where the generated library
           ;; can reach it -- and a lowering bug in overflow checking would stop
           ;; being visible to the differential.
           ;;
           ;; The arithmetic is written TWICE on purpose: this library derives
           ;; field semantics from the source IR and shares no helper with the
           ;; emitter. Widths are read here from `machine-fields`; the emitter
           ;; reads them from the normalized table.
           ;;
           ;; The accumulate step is a SEPARATE message from `field-step`,
           ;; returning `(target . mode)` rather than a bare target. The mode is
           ;; unavoidable here -- a digit advances, a non-digit takes its edge's
           ;; own mode, and an overflow consumes nothing -- and widening
           ;; `field-step`'s return to a pair would change every zero-width arm
           ;; for no gain, since those kinds have no mode to carry. One message
           ;; per shape.
           ((accumulate-step)
            (let* ((name (car args)) (fv (cadr args)) (byte (caddr args)))
              (accumulate-step (lookup nodes name) fv byte)))
           ;; Counted consume. One message per shape: `(count-step node fv pos
           ;; end)` answers `(committed . target)`, and the finish path asks it
           ;; over an empty slice and reads only the target -- `(0 . next)` is the
           ;; zero-count transition, `(0 . #f)` means take the EOF route.
           ((count-step)
            (let* ((name (car args)) (fv (cadr args)) (pos (caddr args)) (end (cadddr args)))
              (count-step (lookup nodes name) fv pos end)))
           ;; KNOWN LIMITATION, shared with `compile.sls`'s `field-action` arm
           ;; (the two must change together): a field-action operation that fails
           ;; over a reexecute edge reports position kind `byte` where the
           ;; zero-width rule wants `boundary`. This shared arm cannot tell a
           ;; SUCCESS jump from a FAILURE jump, so distinguishing them would need
           ;; `field-step` to say which route it took -- a widened return
           ;; (exactly what the `accumulate-step` comment above declines to do
           ;; for its own reason) or a new executor message. The "one message per
           ;; shape" argument is what makes the widened return the wrong first
           ;; instinct.
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
           ;; The settable table: `(name width)` per SETTABLE field, what
           ;; make-parser range-checks an embedder override against.
           ;; This lane answers from the source machine; the generated lane reads
           ;; the equivalent ABI payload member 3. A list here, a vector there --
           ;; make-parser converts the v2 vector to a list, so the two shapes meet.
           ((settable-fields)
            (let loop ((fs (machine-fields m)) (acc '()))
              (cond ((null? fs) (reverse acc))
                    ((uint-field-settable? (car fs))
                     (loop (cdr fs) (cons (list (uint-field-name (car fs))
                                                (uint-field-width (car fs)))
                                          acc)))
                    (else (loop (cdr fs) acc)))))
           ;; The same per-lane asymmetry the field table established: this lane
           ;; holds the verified source machine and is asked, the generated lane
           ;; reads the equivalent shape out of ABI payload member 1. Four parts
           ;; per callback, which is everything the resolution needs and nothing
           ;; more -- the branch KEYS are a verifier concern and are not carried
           ;; across the seam.
           ((callback-decls)
            (list->vector
             (map (lambda (c) (vector (callback-declaration-name c)
                                      (callback-declaration-kind c)
                                      (callback-declaration-required? c)
                                      (callback-declaration-default-branch c)))
                  (machine-callbacks m))))
           ;; Six parts -- slot, continue target, branch map, pause continuation,
           ;; default target, declaration index -- and the generated lane renders
           ;; the same six as literals into its own arm. The runtime routes them
           ;; through one shared `byte-machine-callback-step/v1`, so the OUTCOME
           ;; vocabulary is identical in both lanes while the targets stay each
           ;; lane's own.
           ((callback-parts) (callback-parts (lookup nodes (car args))))
           ;; The three span messages. Each answers what its arm needs and nothing
           ;; more, in the shape `callback-parts` established: slots and targets
           ;; resolved here, outcome vocabulary owned by the runtime.
           ((span-start-parts) (span-start-parts (lookup nodes (car args))))
           ((span-end-parts) (span-end-parts (lookup nodes (car args))))
           ((span-completion-parts) (span-completion-parts (car args)))
           ;; A bare SOURCE node name, always: `current` is a declared node name,
           ;; or the compound (name . consumed-bytes) inside a lowered sequence,
           ;; and the current source input node is wanted in both cases. The
           ;; generated lane answers from ABI payload member 2's table, which is
           ;; total over its internal prefix states for exactly this reason.
           ((state-name) (let ((c (car args))) (if (pair? c) (car c) c)))
           ((kind) (kind (car args)))
           ((dispatch) (dispatch (car args) (cadr args)))
           ((error-value) (error-parts (car args)))
           ((eof-target) (eof-target-of (car args)))
           ((pause-target) (pause-node-continuation (lookup nodes (car args))))
           ((pause-reason) (pause-reason-parts (car args)))
           ((default-eof-value) (default-eof-parts (car args)))
           (else (byte-machine-contract-violation 'interpret 'internal msg))))))))
