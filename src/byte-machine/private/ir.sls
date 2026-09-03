;;; Immutable source-IR descriptors (parent §9.1, §10), M1 subset: the machine,
;;; byte-dispatch/stop/error/finish/pause nodes, exact-byte matcher, edge,
;;; error declaration, and the verification-result value. Tagged vectors behind
;;; accessors; the tag is a freshly allocated vector so a second copy gets a
;;; second identity. Constructors validate only local shape; graph/cross-
;;; reference checks live in verify.
;;; Error references (error nodes, the machine default eof error) are symbolic
;;; NAMES resolved by verify against the error declarations (parent §10.1).
(library (byte-machine private ir)
  (export make-machine machine? machine-name machine-entry machine-fields
          machine-callbacks machine-spans machine-errors machine-nodes
          machine-default-eof-error machine-source-label
          make-byte-dispatch-node byte-dispatch-node? byte-dispatch-node-name
          byte-dispatch-node-cases byte-dispatch-node-fallback
          byte-dispatch-node-eof-target
          make-byte-case byte-case? byte-case-matcher byte-case-edge
          make-exact-byte-matcher exact-byte-matcher? exact-byte-matcher-byte
          make-byte-set-matcher byte-set-matcher? byte-set-matcher-bytes
          make-byte-range-matcher byte-range-matcher?
          byte-range-matcher-low byte-range-matcher-high
          make-byte-complement-matcher byte-complement-matcher?
          byte-complement-matcher-matcher
          matcher? matcher-bytes ascii-bytes
          make-edge edge? edge-target edge-mode
          make-stop-node stop-node? stop-node-name
          make-finish-node finish-node? finish-node-name
          make-pause-node pause-node? pause-node-name pause-node-continuation
          make-error-node error-node? error-node-name error-node-error-name
          machine-ir-version-of supported-ir-version
          make-uint-field uint-field? uint-field-name uint-field-width
          uint-field-initial uint-field-source-label
          make-error-declaration error-declaration? error-declaration-name
          error-declaration-code error-declaration-reason
          make-sequence-dispatch-node sequence-dispatch-node?
          sequence-dispatch-node-name sequence-dispatch-node-cases
          sequence-dispatch-node-mismatch sequence-dispatch-node-eof-target
          make-sequence-case sequence-case? sequence-case-bytes sequence-case-target
          make-field-action-node field-action-node?
          field-action-node-name field-action-node-operation
          field-action-node-arguments field-action-node-next
          field-action-node-error field-action-node-source-label
          make-field-branch-node field-branch-node?
          field-branch-node-name field-branch-node-predicate
          field-branch-node-arguments field-branch-node-true-target
          field-branch-node-false-target field-branch-node-source-label
          field-operations field-predicates
          node? node-name
          make-verification-result verification-result? verification-result-ok?
          verification-result-diagnostics verification-result-machine)
  (import (rnrs)
          (byte-machine private conditions))

  (define (tag sym) (vector sym))
  (define (tagged? t x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))
  (define (require-symbol who what v)
    (unless (symbol? v)
      (byte-machine-contract-violation who 'invalid-argument what))
    v)
  ;; A byte is an exact integer in 0..255; this shape is checked at four call
  ;; sites (a lone byte, a byte inside a set, a range's low, a range's high),
  ;; so it is a pure predicate (byte-value?, reused by the for-all below) plus
  ;; a require-symbol sibling (require-byte) that threads who/what the same
  ;; way.
  (define (byte-value? x) (and (integer? x) (exact? x) (<= 0 x 255)))
  (define (require-byte who what v)
    (unless (byte-value? v)
      (byte-machine-contract-violation who 'invalid-argument what))
    v)

  ;; --- exact-byte matcher ---
  (define exact-byte-matcher-tag (tag 'byte-machine-exact-byte-matcher))
  (define (make-exact-byte-matcher byte)
    (require-byte 'make-exact-byte-matcher 'byte byte)
    (vector exact-byte-matcher-tag byte))
  (define (exact-byte-matcher? x) (tagged? exact-byte-matcher-tag x))
  ;; Tag-guarded: an unguarded (vector-ref m 1) on a matcher of another kind
  ;; pulls a byte LIST out of the wrong slot and fails far away, inside
  ;; arithmetic or a sort predicate, rather than at the contract boundary.
  (define (exact-byte-matcher-byte m)
    (unless (exact-byte-matcher? m)
      (byte-machine-contract-violation 'exact-byte-matcher-byte 'invalid-argument 'matcher))
    (vector-ref m 1))

  ;; --- byte-set matcher (§9.1:292; decision 0017 points 1 and 3) ---
  ;; The caller's element order and duplicates are stored verbatim -- sorting
  ;; or de-duplicating here would be a construction-time semantic transform,
  ;; which §9.1:322 forbids; matcher-bytes does both, once, at
  ;; canonicalization. The list is copied on BOTH sides of the descriptor,
  ;; with `(append bytes '())` rather than `list-copy` (unbound under a bare
  ;; `(rnrs)` import): once at construction, and again below in
  ;; byte-set-matcher-bytes -- so §9.1's "immutable-by-API descriptor" holds
  ;; in both directions. A caller who mutates the list they passed in
  ;; (set-car!, etc.) cannot reach back into an already-built matcher, and a
  ;; caller who mutates the list this accessor just handed them cannot reach
  ;; the matcher's own storage either -- both routes go through `(rnrs
  ;; mutable-pairs)` and this closes both. Copying is not the transform
  ;; decision 0017 point 3 forbids -- it changes the list's identity, not its
  ;; order or membership; the copy byte-set-matcher-bytes returns is unsorted
  ;; and undeduplicated, same as the stored list. The degenerate `(append '()
  ;; z)` case (which would return `z` itself, aliasing it) cannot occur on
  ;; either side: `make-byte-set-matcher` requires `(pair? bytes)`, so the
  ;; stored list -- and therefore the accessor's `(vector-ref m 1)` -- is
  ;; always a non-empty proper list.
  ;;
  ;; byte-complement-matcher-matcher below does NOT get the same treatment --
  ;; it hands back the nested matcher object itself (a tagged vector), not a
  ;; copy. That is a real, separate exposure (`vector-set!` can overwrite a
  ;; nested matcher's own slots in place), but it is a different route
  ;; through a different mutable primitive than the one this fix closes, and
  ;; closing it would mean deep-copying an arbitrarily nested matcher tree on
  ;; every read -- out of scope here.
  (define byte-set-matcher-tag (tag 'byte-machine-byte-set-matcher))
  (define (make-byte-set-matcher bytes)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-byte-set-matcher 'invalid-argument 'bytes))
    (vector byte-set-matcher-tag (append bytes '())))
  (define (byte-set-matcher? x) (tagged? byte-set-matcher-tag x))
  (define (byte-set-matcher-bytes m)
    (unless (byte-set-matcher? m)
      (byte-machine-contract-violation 'byte-set-matcher-bytes 'invalid-argument 'matcher))
    (append (vector-ref m 1) '()))

  ;; --- byte-range matcher (§9.1:293; decision 0017 points 1 and 2) ---
  ;; low = high is legal: a redundant but well-formed exact byte.
  (define byte-range-matcher-tag (tag 'byte-machine-byte-range-matcher))
  (define (make-byte-range-matcher low high)
    (require-byte 'make-byte-range-matcher 'low low)
    (require-byte 'make-byte-range-matcher 'high high)
    (unless (<= low high)
      (byte-machine-contract-violation 'make-byte-range-matcher 'invalid-argument 'range))
    (vector byte-range-matcher-tag low high))
  (define (byte-range-matcher? x) (tagged? byte-range-matcher-tag x))
  (define (byte-range-matcher-low m)
    (unless (byte-range-matcher? m)
      (byte-machine-contract-violation 'byte-range-matcher-low 'invalid-argument 'matcher))
    (vector-ref m 1))
  (define (byte-range-matcher-high m)
    (unless (byte-range-matcher? m)
      (byte-machine-contract-violation 'byte-range-matcher-high 'invalid-argument 'matcher))
    (vector-ref m 2))

  ;; --- byte-complement matcher (§9.1:294) ---
  ;; It complements a MATCHER, not a byte list, so complements nest and
  ;; canonicalization is recursive. The complement of a full-universe matcher is
  ;; the empty set of transitions on a node whose fallback then takes every byte
  ;; -- vacuous, not malformed (decision 0017 point 2).
  (define byte-complement-matcher-tag (tag 'byte-machine-byte-complement-matcher))
  (define (make-byte-complement-matcher matcher)
    (unless (matcher? matcher)
      (byte-machine-contract-violation 'make-byte-complement-matcher 'invalid-argument 'matcher))
    (vector byte-complement-matcher-tag matcher))
  (define (byte-complement-matcher? x) (tagged? byte-complement-matcher-tag x))
  (define (byte-complement-matcher-matcher m)
    (unless (byte-complement-matcher? m)
      (byte-machine-contract-violation 'byte-complement-matcher-matcher
                                       'invalid-argument 'matcher))
    (vector-ref m 1))

  (define (matcher? x)
    (or (exact-byte-matcher? x) (byte-set-matcher? x)
        (byte-range-matcher? x) (byte-complement-matcher? x)))

  ;; ascii-bytes (§9.1:299): a string's code points as a proper list of exact
  ;; integers, in string order, with no de-duplication -- §9.1:318 names `bytes`
  ;; a proper list, so this composes directly with make-byte-set-matcher. It is a
  ;; helper, not a matcher constructor, so the empty string is legal and yields
  ;; '(); make-byte-set-matcher is where that becomes a contract violation.
  (define (ascii-bytes s)
    (unless (string? s)
      (byte-machine-contract-violation 'ascii-bytes 'invalid-argument 'string))
    (let loop ((i (- (string-length s) 1)) (acc '()))
      (if (< i 0)
          acc
          (let ((c (char->integer (string-ref s i))))
            (unless (<= 0 c 127)
              (byte-machine-contract-violation 'ascii-bytes 'invalid-argument 'non-ascii))
            (loop (- i 1) (cons c acc))))))

  ;; --- matcher canonicalization (parent §10.6:538, §16.3:921; decision 0014) ---
  ;; Every matcher denotes a subset of the closed byte universe 0..255. This is
  ;; the one place that subset is computed: the verifier's overlap analysis, the
  ;; normalizer's per-byte lowering and the interpreter's membership test all
  ;; call it, so a matcher kind taught here is understood by all three at once.
  ;; The result is a proper list of exact integers, ascending and duplicate-free
  ;; -- ordering and de-duplication are what keep the normalizer's
  ;; ascending-by-byte transition sort a TOTAL order (decision 0014).
  (define (byte-set-canonical bs)
    (let loop ((s (list-sort < bs)) (acc '()))
      (cond ((null? s) (reverse acc))
            ((and (pair? acc) (= (car s) (car acc))) (loop (cdr s) acc))
            (else (loop (cdr s) (cons (car s) acc))))))
  (define (matcher-bytes m)
    (cond ((exact-byte-matcher? m) (list (exact-byte-matcher-byte m)))
          ((byte-set-matcher? m) (byte-set-canonical (byte-set-matcher-bytes m)))
          ((byte-range-matcher? m)
           (let loop ((b (byte-range-matcher-high m)) (acc '()))
             (if (< b (byte-range-matcher-low m))
                 acc
                 (loop (- b 1) (cons b acc)))))
          ((byte-complement-matcher? m)
           (let ((inner (matcher-bytes (byte-complement-matcher-matcher m))))
             (let loop ((b 255) (acc '()))
               (cond ((< b 0) acc)
                     ((memv b inner) (loop (- b 1) acc))
                     (else (loop (- b 1) (cons b acc)))))))
          (else (byte-machine-contract-violation 'matcher-bytes
                                                 'invalid-argument 'matcher))))

  ;; --- edge ---
  (define edge-tag (tag 'byte-machine-edge))
  (define (make-edge target mode)
    (require-symbol 'make-edge 'target target)
    (unless (memq mode '(advance reexecute))
      (byte-machine-contract-violation 'make-edge 'invalid-argument 'mode))
    (vector edge-tag target mode))
  (define (edge? x) (tagged? edge-tag x))
  (define (edge-target e) (vector-ref e 1))
  (define (edge-mode e) (vector-ref e 2))

  ;; --- byte case ---
  (define byte-case-tag (tag 'byte-machine-byte-case))
  (define (make-byte-case matcher edge source-label)
    (unless (matcher? matcher)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'matcher))
    (unless (edge? edge)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'edge))
    (vector byte-case-tag matcher edge source-label))
  (define (byte-case? x) (tagged? byte-case-tag x))
  (define (byte-case-matcher c) (vector-ref c 1))
  (define (byte-case-edge c) (vector-ref c 2))

  ;; --- byte-dispatch node ---
  (define byte-dispatch-node-tag (tag 'byte-machine-byte-dispatch-node))
  (define (make-byte-dispatch-node name cases fallback eof-target source-label)
    (require-symbol 'make-byte-dispatch-node 'name name)
    (unless (and (list? cases) (for-all byte-case? cases))
      (byte-machine-contract-violation 'make-byte-dispatch-node 'invalid-argument 'cases))
    (unless (edge? fallback)
      (byte-machine-contract-violation 'make-byte-dispatch-node 'invalid-argument 'fallback))
    ;; eof-target is a symbol (a node name) or #f (machine default eof error).
    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-byte-dispatch-node 'invalid-argument 'eof-target))
    (vector byte-dispatch-node-tag name cases fallback eof-target source-label))
  (define (byte-dispatch-node? x) (tagged? byte-dispatch-node-tag x))
  (define (byte-dispatch-node-name n) (vector-ref n 1))
  (define (byte-dispatch-node-cases n) (vector-ref n 2))
  (define (byte-dispatch-node-fallback n) (vector-ref n 3))
  (define (byte-dispatch-node-eof-target n) (vector-ref n 4))

  ;; --- stop node ---
  (define stop-node-tag (tag 'byte-machine-stop-node))
  (define (make-stop-node name source-label)
    (require-symbol 'make-stop-node 'name name)
    (vector stop-node-tag name source-label))
  (define (stop-node? x) (tagged? stop-node-tag x))
  (define (stop-node-name n) (vector-ref n 1))

  ;; --- finish node (EOF-only successful terminal, returns finished) ---
  (define finish-node-tag (tag 'byte-machine-finish-node))
  (define (make-finish-node name source-label)
    (require-symbol 'make-finish-node 'name name)
    (vector finish-node-tag name source-label))
  (define (finish-node? x) (tagged? finish-node-tag x))
  (define (finish-node-name n) (vector-ref n 1))

  ;; --- pause node (explicit continuation; returns paused -- parent §10.6) ---
  ;; One zero-width out-edge to `continuation`: pause reads no byte, so it has
  ;; no advance/reexecute mode (§11.2 defines modes only for byte reads).
  (define pause-node-tag (tag 'byte-machine-pause-node))
  (define (make-pause-node name continuation source-label)
    (require-symbol 'make-pause-node 'name name)
    (require-symbol 'make-pause-node 'continuation continuation)
    (vector pause-node-tag name continuation source-label))
  (define (pause-node? x) (tagged? pause-node-tag x))
  (define (pause-node-name n) (vector-ref n 1))
  (define (pause-node-continuation n) (vector-ref n 2))

  ;; --- zero-width field nodes (Milestone 4 Slice ②; §9.1:301-306, §10.6:550,
  ;; :575). Both are ZERO-WIDTH: they consume no byte, which is what every
  ;; verifier extension in ② turns on.
  ;;
  ;; *** The constructor/verifier boundary is decision 0020's, and item 2 fixes
  ;; the whole of it in one line: `arguments` is checked as a proper list AND NO
  ;; FURTHER. *** Everything needing the §9.1:326-346 schema -- which position
  ;; holds the field, how many positions there are, what each means -- is the
  ;; verifier's, because §9.1:348 assigns exact arity there and nothing can be
  ;; read out of `arguments` before arity is known. So `low <= high` for `range`
  ;; is the VERIFIER's, even though 0017 rejects `low > high` inside
  ;; `make-byte-range-matcher`: there they are named parameters, here they are
  ;; the second and third elements of a list whose length this constructor is not
  ;; entitled to assume. 0020 item 2 flags that as the consequence a reader of
  ;; 0017 will think is wrong.
  ;;
  ;; What IS closed here is evaluable from the one node being built: the
  ;; operation and predicate sets (§9.1:348's "it rejects arbitrary operation
  ;; names" -- the one clause of that sentence pass 6a does not carry), the
  ;; symbols, and the error slot's rule below.
  (define field-operations '(store clear increment decrement add set-mask clear-mask))
  (define field-predicates '(equal zero nonzero range mask-any mask-all mask-none))
  ;; The four operations that provably cannot fail once their constant or mask is
  ;; range-checked against the field width -- which is pass 6a's check, not this
  ;; one. `increment`, `decrement` and `add` can fail.
  (define infallible-field-operations '(store clear set-mask clear-mask))

  (define (require-proper-list who what v)
    (unless (list? v)
      (byte-machine-contract-violation who 'invalid-argument what))
    v)

  (define field-action-node-tag (tag 'byte-machine-field-action-node))
  ;; The `error` slot names a TARGET NODE and must be #f EXACTLY when the
  ;; operation cannot fail. Permitting a target on a safe operation would not
  ;; fail loudly anywhere downstream: node-out-targets feeds `error` into the
  ;; reachability walk unconditionally, so the target is reached and no pass
  ;; checks whether the operation can actually fail. This constructor is the only
  ;; place that can. Precedent for a target-or-#f slot: `eof-target` (§9.1:318).
  (define (make-field-action-node name operation arguments next error source-label)
    (require-symbol 'make-field-action-node 'name name)
    (unless (memq operation field-operations)
      (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'operation))
    (require-proper-list 'make-field-action-node 'arguments arguments)
    (require-symbol 'make-field-action-node 'next next)
    (let ((safe (and (memq operation infallible-field-operations) #t)))
      (when (eq? safe (and (symbol? error) #t))
        (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'error))
      (unless (or (eq? error #f) (symbol? error))
        (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'error)))
    (vector field-action-node-tag name operation arguments next error source-label))
  (define (field-action-node? x) (tagged? field-action-node-tag x))
  (define (field-action-node-name n) (vector-ref n 1))
  (define (field-action-node-operation n) (vector-ref n 2))
  (define (field-action-node-arguments n) (vector-ref n 3))
  (define (field-action-node-next n) (vector-ref n 4))
  (define (field-action-node-error n) (vector-ref n 5))
  (define (field-action-node-source-label n) (vector-ref n 6))

  (define field-branch-node-tag (tag 'byte-machine-field-branch-node))
  ;; §9.1:305 requires "an explicit target for every possible result", so both
  ;; targets are mandatory symbols -- there is no #f arm and no fallthrough.
  ;; This is the kind that makes the EOF walk multi-successor.
  (define (make-field-branch-node name predicate arguments true-target false-target source-label)
    (require-symbol 'make-field-branch-node 'name name)
    (unless (memq predicate field-predicates)
      (byte-machine-contract-violation 'make-field-branch-node 'invalid-argument 'predicate))
    (require-proper-list 'make-field-branch-node 'arguments arguments)
    (require-symbol 'make-field-branch-node 'true-target true-target)
    (require-symbol 'make-field-branch-node 'false-target false-target)
    (vector field-branch-node-tag name predicate arguments true-target false-target source-label))
  (define (field-branch-node? x) (tagged? field-branch-node-tag x))
  (define (field-branch-node-name n) (vector-ref n 1))
  (define (field-branch-node-predicate n) (vector-ref n 2))
  (define (field-branch-node-arguments n) (vector-ref n 3))
  (define (field-branch-node-true-target n) (vector-ref n 4))
  (define (field-branch-node-false-target n) (vector-ref n 5))
  (define (field-branch-node-source-label n) (vector-ref n 6))

  ;; --- error node (references a declaration by NAME) ---
  (define error-node-tag (tag 'byte-machine-error-node))
  (define (make-error-node name error-declaration source-label)
    (require-symbol 'make-error-node 'name name)
    (require-symbol 'make-error-node 'error-declaration error-declaration)
    (vector error-node-tag name error-declaration source-label))
  (define (error-node? x) (tagged? error-node-tag x))
  (define (error-node-name n) (vector-ref n 1))
  (define (error-node-error-name n) (vector-ref n 2))

  ;; --- error declaration ---
  (define error-declaration-tag (tag 'byte-machine-error-declaration))
  (define (make-error-declaration name code reason source-label)
    (require-symbol 'make-error-declaration 'name name)
    (require-symbol 'make-error-declaration 'code code)
    (unless (string? reason)
      (byte-machine-contract-violation 'make-error-declaration 'invalid-argument 'reason))
    (vector error-declaration-tag name code reason source-label))
  (define (error-declaration? x) (tagged? error-declaration-tag x))
  (define (error-declaration-name d) (vector-ref d 1))
  (define (error-declaration-code d) (vector-ref d 2))
  (define (error-declaration-reason d) (vector-ref d 3))

  ;; --- sequence case (§9.1:298) ---
  ;; A byte list and a bare TARGET, with no mode. A successful sequence consumes
  ;; every byte in it (§10.6:546), so giving a case an advance/reexecute mode
  ;; would reintroduce the lookahead :546 forbids. The mismatch EDGE on the node
  ;; below carries the only mode a sequence has. The accessor copies for the same
  ;; reason byte-set-matcher-bytes does: §9.1 says constructors return
  ;; immutable-by-API descriptors, and a copy preserves order and duplicates, so
  ;; it is not the semantic transform §9.1:322 forbids.
  (define sequence-case-tag (tag 'byte-machine-sequence-case))
  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-sequence-case 'invalid-argument 'bytes))
    (require-symbol 'make-sequence-case 'target target)
    (vector sequence-case-tag (append bytes '()) target source-label))
  (define (sequence-case? x) (tagged? sequence-case-tag x))
  (define (sequence-case-bytes c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-bytes 'invalid-argument 'case))
    (append (vector-ref c 1) '()))
  (define (sequence-case-target c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-target 'invalid-argument 'case))
    (vector-ref c 2))

  ;; --- sequence-dispatch node (§9.1:297, §10.6:542-546) ---
  ;; The sixth node kind. Matches one of a finite set of exact byte sequences
  ;; without backtracking; alternatives may share nonterminal prefixes. Whether
  ;; two alternatives collide is a cross-case property, so it is verification's
  ;; job, not this constructor's (decision 0017 point 4).
  (define sequence-dispatch-node-tag (tag 'byte-machine-sequence-dispatch-node))
  (define (make-sequence-dispatch-node name cases mismatch eof-target source-label)
    (require-symbol 'make-sequence-dispatch-node 'name name)
    (unless (and (list? cases) (pair? cases) (for-all sequence-case? cases))
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'cases))
    (unless (edge? mismatch)
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'mismatch))
    ;; eof-target is a node name, or #f for the machine default eof error.
    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'eof-target))
    (vector sequence-dispatch-node-tag name cases mismatch eof-target source-label))
  (define (sequence-dispatch-node? x) (tagged? sequence-dispatch-node-tag x))
  (define (sequence-dispatch-node-name n) (vector-ref n 1))
  (define (sequence-dispatch-node-cases n) (vector-ref n 2))
  (define (sequence-dispatch-node-mismatch n) (vector-ref n 3))
  (define (sequence-dispatch-node-eof-target n) (vector-ref n 4))

  ;; --- node dispatch ---
  (define (node? x)
    (or (byte-dispatch-node? x) (sequence-dispatch-node? x) (stop-node? x)
        (error-node? x) (finish-node? x) (pause-node? x)
        (field-action-node? x) (field-branch-node? x)))
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((sequence-dispatch-node? x) (sequence-dispatch-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          ((finish-node? x) (finish-node-name x))
          ((pause-node? x) (pause-node-name x))
          ((field-action-node? x) (field-action-node-name x))
          ((field-branch-node? x) (field-branch-node-name x))
          (else (byte-machine-contract-violation 'node-name 'invalid-argument 'node))))

  ;; --- uint field descriptor (§9.1:283, §10.2:488-491) ---
  ;; The four parts §10.2 names: a symbolic name, an unsigned width of 8, 16, 32
  ;; or 64 bits, an initial exact-integer value within that width, and an
  ;; optional diagnostic label.
  ;;
  ;; Every check here is decision 0020's CONSTRUCTOR half -- closed-set
  ;; membership and the local shape of the one value being built -- on the
  ;; make-edge precedent above, which memq-checks `mode` at construction even
  ;; though §16.2:896 assigns advancement modes to the verifier. A contract
  ;; violation is not a diagnostic (§4.6), so none of these carries a code, and
  ;; NO verifier pass re-checks them: a machine whose field failed construction
  ;; never exists, so the arm would be unreachable through any public API and
  ;; its permissive mutation would survive while the suite reported it caught.
  ;;
  ;; There is exactly one field TYPE in v0.1; §29:1754 defers additional ones.
  (define uint-field-tag (tag 'byte-machine-uint-field))
  (define (make-uint-field name width initial source-label)
    (require-symbol 'make-uint-field 'name name)
    (unless (memq width '(8 16 32 64))
      (byte-machine-contract-violation 'make-uint-field 'invalid-argument 'width))
    ;; `exact-integer?` is not R6RS; the pair below is what (rnrs) gives, and
    ;; the range is inclusive at both ends per §10.2:490. The u64 upper bound is
    ;; a bignum on every supported runtime -- (greatest-fixnum) is 2^60-1 -- so
    ;; this comparison must not be narrowed to fixnum arithmetic.
    (unless (and (integer? initial) (exact? initial)
                 (<= 0 initial (- (expt 2 width) 1)))
      (byte-machine-contract-violation 'make-uint-field 'invalid-argument 'initial))
    (vector uint-field-tag name width initial source-label))
  (define (uint-field? x) (tagged? uint-field-tag x))
  (define (uint-field-name f) (vector-ref f 1))
  (define (uint-field-width f) (vector-ref f 2))
  (define (uint-field-initial f) (vector-ref f 3))
  (define (uint-field-source-label f) (vector-ref f 4))

  ;; --- machine (default-eof-error is a declared error NAME) ---
  (define machine-tag (tag 'byte-machine-machine))
  (define machine-ir-version 1)     ; stamped; v0.1 callers do not override (§9.1)
  ;; The version pass-schema accepts. Named separately from the stamp so the two
  ;; can be told apart by a mutation: forcing the stamp changes what is built,
  ;; forcing this changes what is accepted, and only the second is a verifier
  ;; decision.
  (define supported-ir-version 1)
  (define (make-machine name entry fields callbacks spans errors nodes
                        default-eof-error source-label)
    (require-symbol 'make-machine 'name name)
    (require-symbol 'make-machine 'entry entry)
    (require-symbol 'make-machine 'default-eof-error default-eof-error)
    (for-each (lambda (l) (unless (list? l)
                            (byte-machine-contract-violation 'make-machine
                                                             'invalid-argument 'collection)))
              (list fields callbacks spans errors nodes))
    (unless (for-all node? nodes)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'nodes))
    (unless (for-all error-declaration? errors)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'errors))
    ;; What makes the descriptor load-bearing. Before this guard the collection
    ;; loop above checked only `list?`, so any proper list passed as `fields` --
    ;; measured, a machine could carry (junk 42 "string") and nothing read it.
    (unless (for-all uint-field? fields)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'fields))
    (vector machine-tag machine-ir-version name entry fields callbacks spans
            errors nodes default-eof-error source-label))
  (define (machine? x) (tagged? machine-tag x))
  ;; Slot 1, stamped as the constant above and never taken from an argument.
  ;; It had no accessor until Milestone 4 Slice ①b, which is why §16.2:884's
  ;; unsupported-IR-version half was listed and unimplemented: pass-schema could
  ;; not read what it was meant to check.
  (define (machine-ir-version-of m) (vector-ref m 1))
  (define (machine-name m) (vector-ref m 2))
  (define (machine-entry m) (vector-ref m 3))
  (define (machine-fields m) (vector-ref m 4))
  (define (machine-callbacks m) (vector-ref m 5))
  (define (machine-spans m) (vector-ref m 6))
  (define (machine-errors m) (vector-ref m 7))
  (define (machine-nodes m) (vector-ref m 8))
  (define (machine-default-eof-error m) (vector-ref m 9))
  (define (machine-source-label m) (vector-ref m 10))

  ;; --- verification result (carries the machine, per §9.2) ---
  (define verification-result-tag (tag 'byte-machine-verification-result))
  (define (make-verification-result ok? diagnostics machine)
    (vector verification-result-tag ok? diagnostics machine))
  (define (verification-result? x) (tagged? verification-result-tag x))
  (define (verification-result-ok? v) (vector-ref v 1))
  (define (verification-result-diagnostics v) (vector-ref v 2))
  (define (verification-result-machine v) (vector-ref v 3)))
