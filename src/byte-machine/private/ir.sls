;;; SPDX-License-Identifier: BSD-3-Clause
;;; Immutable source-IR descriptors: the machine, its node kinds, matchers,
;;; edges, field/callback/span/error declarations, and the verification-result
;;; value. Tagged vectors behind accessors; the tag is a freshly allocated
;;; vector so a second copy gets a second identity. Constructors validate only
;;; local shape; graph/cross-reference checks live in verify.
;;; Error references (error nodes, the machine default eof error) are symbolic
;;; NAMES resolved by verify against the error declarations.
(library (byte-machine private ir)
  (export make-machine machine? machine-name machine-entry machine-fields
          machine-callbacks machine-spans machine-errors machine-nodes
          machine-default-eof-error machine-source-label
          make-byte-dispatch-node byte-dispatch-node? byte-dispatch-node-name
          byte-dispatch-node-cases byte-dispatch-node-fallback
          byte-dispatch-node-eof-target byte-dispatch-node-source-label
          make-byte-case byte-case? byte-case-matcher byte-case-edge
          byte-case-source-label
          make-exact-byte-matcher exact-byte-matcher? exact-byte-matcher-byte
          make-byte-set-matcher byte-set-matcher? byte-set-matcher-bytes
          make-byte-range-matcher byte-range-matcher?
          byte-range-matcher-low byte-range-matcher-high
          make-byte-complement-matcher byte-complement-matcher?
          byte-complement-matcher-matcher
          matcher? matcher-bytes ascii-bytes
          make-edge edge? edge-target edge-mode
          make-stop-node stop-node? stop-node-name stop-node-source-label
          make-finish-node finish-node? finish-node-name finish-node-source-label
          make-pause-node pause-node? pause-node-name pause-node-continuation
          pause-node-reason pause-node-source-label
          make-error-node error-node? error-node-name error-node-error-name
          error-node-source-label
          machine-ir-version-of supported-ir-version
          make-uint-field uint-field? uint-field-name uint-field-width
          uint-field-initial uint-field-settable? uint-field-source-label
          make-error-declaration error-declaration? error-declaration-name
          error-declaration-code error-declaration-reason
          error-declaration-source-label
          make-callback-declaration callback-declaration?
          callback-declaration-name callback-declaration-kind
          callback-declaration-required? callback-declaration-branch-keys
          callback-declaration-default-branch callback-declaration-source-label
          make-span-declaration span-declaration? span-declaration-name
          span-declaration-data-callback span-declaration-complete-callback
          span-declaration-source-label
          make-sequence-dispatch-node sequence-dispatch-node?
          sequence-dispatch-node-name sequence-dispatch-node-cases
          sequence-dispatch-node-mismatch sequence-dispatch-node-eof-target
          sequence-dispatch-node-source-label
          make-sequence-case sequence-case? sequence-case-bytes sequence-case-target
          sequence-case-source-label
          make-keyword-table-node keyword-table-node?
          keyword-table-node-name keyword-table-node-entries
          keyword-table-node-no-match keyword-table-node-eof-target
          keyword-table-node-case-insensitive? keyword-table-node-source-label
          make-keyword-entry keyword-entry? keyword-entry-bytes
          keyword-entry-target keyword-entry-source-label
          make-field-action-node field-action-node?
          field-action-node-name field-action-node-operation
          field-action-node-arguments field-action-node-next
          field-action-node-error field-action-node-source-label
          make-field-branch-node field-branch-node?
          field-branch-node-name field-branch-node-predicate
          field-branch-node-arguments field-branch-node-true-target
          field-branch-node-false-target field-branch-node-source-label
          field-operations field-predicates
          make-integer-accumulate-node integer-accumulate-node?
          integer-accumulate-node-name integer-accumulate-node-field
          integer-accumulate-node-base integer-accumulate-node-digit-target
          integer-accumulate-node-nondigit-edge integer-accumulate-node-overflow-error
          integer-accumulate-node-eof-target integer-accumulate-node-source-label
          accumulate-bases
          make-span-start-node span-start-node?
          span-start-node-name span-start-node-span
          span-start-node-next span-start-node-source-label
          make-span-end-node span-end-node?
          span-end-node-name span-end-node-span
          span-end-node-next span-end-node-source-label
          make-callback-node callback-node?
          callback-node-name callback-node-callback
          callback-node-continue-target callback-node-branch-targets
          callback-node-pause-continuation callback-node-reason
          callback-node-source-label
          make-counted-consume-node counted-consume-node?
          counted-consume-node-name counted-consume-node-field
          counted-consume-node-next counted-consume-node-eof-target
          counted-consume-node-source-label
          node? node-name node-source-label
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
  ;; make-exact-byte-matcher : byte:Byte -> ExactByteMatcher
  (define (make-exact-byte-matcher byte)
    (require-byte 'make-exact-byte-matcher 'byte byte)
    (vector exact-byte-matcher-tag byte))
  ;; exact-byte-matcher? : Any -> Boolean
  (define (exact-byte-matcher? x) (tagged? exact-byte-matcher-tag x))
  ;; Tag-guarded: an unguarded (vector-ref m 1) on a matcher of another kind
  ;; pulls a byte LIST out of the wrong slot and fails far away, inside
  ;; arithmetic or a sort predicate, rather than at the contract boundary.
  ;; exact-byte-matcher-byte : ExactByteMatcher -> Byte
  (define (exact-byte-matcher-byte m)
    (unless (exact-byte-matcher? m)
      (byte-machine-contract-violation 'exact-byte-matcher-byte 'invalid-argument 'matcher))
    (vector-ref m 1))

  ;; --- byte-set matcher ---
  ;; The caller's element order and duplicates are stored verbatim -- sorting
  ;; or de-duplicating here would be a construction-time semantic transform,
  ;; which the descriptor contract forbids; matcher-bytes does both, once, at
  ;; canonicalization. The list is copied on BOTH sides of the descriptor,
  ;; with `(append bytes '())` rather than `list-copy` (unbound under a bare
  ;; `(rnrs)` import): once at construction, and again below in
  ;; byte-set-matcher-bytes -- so the "immutable-by-API descriptor" holds
  ;; in both directions. A caller who mutates the list they passed in
  ;; (set-car!, etc.) cannot reach back into an already-built matcher, and a
  ;; caller who mutates the list this accessor just handed them cannot reach
  ;; the matcher's own storage either. Copying is not the forbidden
  ;; transform -- it changes the list's identity, not its
  ;; order or membership; the copy byte-set-matcher-bytes returns is unsorted
  ;; and undeduplicated, same as the stored list. The degenerate `(append '()
  ;; z)` case (which would return `z` itself, aliasing it) cannot occur on
  ;; either side: `make-byte-set-matcher` requires `(pair? bytes)`, so the
  ;; stored list -- and therefore the accessor's `(vector-ref m 1)` -- is
  ;; always a non-empty proper list.
  ;;
  ;; byte-complement-matcher-matcher below does NOT copy: it hands back the
  ;; nested matcher object itself (a tagged vector), so `vector-set!` can
  ;; overwrite that matcher's slots in place. Closing that would mean
  ;; deep-copying an arbitrarily nested matcher tree on every read.
  (define byte-set-matcher-tag (tag 'byte-machine-byte-set-matcher))
  ;; make-byte-set-matcher : bytes:(Listof Byte) -> ByteSetMatcher
  (define (make-byte-set-matcher bytes)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-byte-set-matcher 'invalid-argument 'bytes))
    (vector byte-set-matcher-tag (append bytes '())))
  ;; byte-set-matcher? : Any -> Boolean
  (define (byte-set-matcher? x) (tagged? byte-set-matcher-tag x))
  ;; byte-set-matcher-bytes : ByteSetMatcher -> (Listof Byte) -- fresh copy
  (define (byte-set-matcher-bytes m)
    (unless (byte-set-matcher? m)
      (byte-machine-contract-violation 'byte-set-matcher-bytes 'invalid-argument 'matcher))
    (append (vector-ref m 1) '()))

  ;; --- byte-range matcher ---
  ;; low = high is legal: a redundant but well-formed exact byte.
  (define byte-range-matcher-tag (tag 'byte-machine-byte-range-matcher))
  ;; make-byte-range-matcher : low:Byte high:Byte -> ByteRangeMatcher
  (define (make-byte-range-matcher low high)
    (require-byte 'make-byte-range-matcher 'low low)
    (require-byte 'make-byte-range-matcher 'high high)
    (unless (<= low high)
      (byte-machine-contract-violation 'make-byte-range-matcher 'invalid-argument 'range))
    (vector byte-range-matcher-tag low high))
  ;; byte-range-matcher? : Any -> Boolean
  (define (byte-range-matcher? x) (tagged? byte-range-matcher-tag x))
  ;; byte-range-matcher-low : ByteRangeMatcher -> Byte
  (define (byte-range-matcher-low m)
    (unless (byte-range-matcher? m)
      (byte-machine-contract-violation 'byte-range-matcher-low 'invalid-argument 'matcher))
    (vector-ref m 1))
  ;; byte-range-matcher-high : ByteRangeMatcher -> Byte
  (define (byte-range-matcher-high m)
    (unless (byte-range-matcher? m)
      (byte-machine-contract-violation 'byte-range-matcher-high 'invalid-argument 'matcher))
    (vector-ref m 2))

  ;; --- byte-complement matcher ---
  ;; It complements a MATCHER, not a byte list, so complements nest and
  ;; canonicalization is recursive. The complement of a full-universe matcher is
  ;; the empty set of transitions on a node whose fallback then takes every byte
  ;; -- vacuous, not malformed.
  (define byte-complement-matcher-tag (tag 'byte-machine-byte-complement-matcher))
  ;; make-byte-complement-matcher : matcher:Matcher -> ByteComplementMatcher
  (define (make-byte-complement-matcher matcher)
    (unless (matcher? matcher)
      (byte-machine-contract-violation 'make-byte-complement-matcher 'invalid-argument 'matcher))
    (vector byte-complement-matcher-tag matcher))
  ;; byte-complement-matcher? : Any -> Boolean
  (define (byte-complement-matcher? x) (tagged? byte-complement-matcher-tag x))
  ;; byte-complement-matcher-matcher : ByteComplementMatcher -> Matcher
  (define (byte-complement-matcher-matcher m)
    (unless (byte-complement-matcher? m)
      (byte-machine-contract-violation 'byte-complement-matcher-matcher
                                       'invalid-argument 'matcher))
    (vector-ref m 1))

  ;; matcher? : Any -> Boolean
  (define (matcher? x)
    (or (exact-byte-matcher? x) (byte-set-matcher? x)
        (byte-range-matcher? x) (byte-complement-matcher? x)))

  ;; ascii-bytes: a string's code points as a proper list of exact integers, in
  ;; string order, with no de-duplication -- `bytes` is a proper list, so this
  ;; composes directly with make-byte-set-matcher. It is a helper, not a matcher
  ;; constructor, so the empty string is legal and yields '();
  ;; make-byte-set-matcher is where that becomes a contract violation.
  ;; ascii-bytes : String -> (Listof Byte)
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

  ;; --- matcher canonicalization ---
  ;; Every matcher denotes a subset of the closed byte universe 0..255. This is
  ;; the one place that subset is computed: the verifier's overlap analysis, the
  ;; normalizer's per-byte lowering and the interpreter's membership test all
  ;; call it, so a matcher kind taught here is understood by all three at once.
  ;; The result is a proper list of exact integers, ascending and duplicate-free
  ;; -- ordering and de-duplication are what keep the normalizer's
  ;; ascending-by-byte transition sort a TOTAL order.
  (define (byte-set-canonical bs)
    (let loop ((s (list-sort < bs)) (acc '()))
      (cond ((null? s) (reverse acc))
            ((and (pair? acc) (= (car s) (car acc))) (loop (cdr s) acc))
            (else (loop (cdr s) (cons (car s) acc))))))
  ;; matcher-bytes : Matcher -> (Listof Byte) -- ascending, duplicate-free
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
  ;; make-edge : target:NodeName mode:EdgeMode -> Edge
  (define (make-edge target mode)
    (require-symbol 'make-edge 'target target)
    (unless (memq mode '(advance reexecute))
      (byte-machine-contract-violation 'make-edge 'invalid-argument 'mode))
    (vector edge-tag target mode))
  ;; edge? : Any -> Boolean
  (define (edge? x) (tagged? edge-tag x))
  ;; edge-target : Edge -> NodeName
  (define (edge-target e) (vector-ref e 1))
  ;; edge-mode : Edge -> EdgeMode
  (define (edge-mode e) (vector-ref e 2))

  ;; --- byte case ---
  (define byte-case-tag (tag 'byte-machine-byte-case))
  ;; make-byte-case : matcher:Matcher edge:Edge source-label:Label -> ByteCase
  (define (make-byte-case matcher edge source-label)
    (unless (matcher? matcher)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'matcher))
    (unless (edge? edge)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'edge))
    (vector byte-case-tag matcher edge source-label))
  ;; byte-case? : Any -> Boolean
  (define (byte-case? x) (tagged? byte-case-tag x))
  ;; byte-case-matcher : ByteCase -> Matcher
  (define (byte-case-matcher c) (vector-ref c 1))
  ;; byte-case-edge : ByteCase -> Edge
  (define (byte-case-edge c) (vector-ref c 2))
  ;; A case has no name of its own; the verifier reports its label under the
  ;; owning node.
  ;; byte-case-source-label : ByteCase -> Label
  (define (byte-case-source-label c) (vector-ref c 3))

  ;; --- byte-dispatch node ---
  (define byte-dispatch-node-tag (tag 'byte-machine-byte-dispatch-node))
  ;; make-byte-dispatch-node : name:Symbol cases:(Listof ByteCase) fallback:Edge eof-target:(Option NodeName) source-label:Label -> ByteDispatchNode
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
  ;; byte-dispatch-node? : Any -> Boolean
  (define (byte-dispatch-node? x) (tagged? byte-dispatch-node-tag x))
  ;; byte-dispatch-node-name : ByteDispatchNode -> Symbol
  (define (byte-dispatch-node-name n) (vector-ref n 1))
  ;; byte-dispatch-node-cases : ByteDispatchNode -> (Listof ByteCase)
  (define (byte-dispatch-node-cases n) (vector-ref n 2))
  ;; byte-dispatch-node-fallback : ByteDispatchNode -> Edge
  (define (byte-dispatch-node-fallback n) (vector-ref n 3))
  ;; byte-dispatch-node-eof-target : ByteDispatchNode -> (Option NodeName)
  (define (byte-dispatch-node-eof-target n) (vector-ref n 4))
  ;; byte-dispatch-node-source-label : ByteDispatchNode -> Label
  (define (byte-dispatch-node-source-label n) (vector-ref n 5))

  ;; --- stop node ---
  (define stop-node-tag (tag 'byte-machine-stop-node))
  ;; make-stop-node : name:Symbol source-label:Label -> StopNode
  (define (make-stop-node name source-label)
    (require-symbol 'make-stop-node 'name name)
    (vector stop-node-tag name source-label))
  ;; stop-node? : Any -> Boolean
  (define (stop-node? x) (tagged? stop-node-tag x))
  ;; stop-node-name : StopNode -> Symbol
  (define (stop-node-name n) (vector-ref n 1))
  ;; stop-node-source-label : StopNode -> Label
  (define (stop-node-source-label n) (vector-ref n 2))

  ;; --- finish node (EOF-only successful terminal, returns finished) ---
  (define finish-node-tag (tag 'byte-machine-finish-node))
  ;; make-finish-node : name:Symbol source-label:Label -> FinishNode
  (define (make-finish-node name source-label)
    (require-symbol 'make-finish-node 'name name)
    (vector finish-node-tag name source-label))
  ;; finish-node? : Any -> Boolean
  (define (finish-node? x) (tagged? finish-node-tag x))
  ;; finish-node-name : FinishNode -> Symbol
  (define (finish-node-name n) (vector-ref n 1))
  ;; finish-node-source-label : FinishNode -> Label
  (define (finish-node-source-label n) (vector-ref n 2))

  ;; --- pause node (explicit continuation; returns paused) ---
  ;; One zero-width out-edge to `continuation`: pause reads no byte, so it has
  ;; no advance/reexecute mode (modes are defined only for byte reads).
  (define pause-node-tag (tag 'byte-machine-pause-node))
  ;; make-pause-node : name:Symbol continuation:NodeName [reason:(Option ErrorName)] source-label:Label -> PauseNode
  ;; The OPTIONAL reason is a declared error-declaration NAME, or #f (the
  ;; 3-argument form). The reason is a leaf datum the verifier resolves and the
  ;; normalizer carries -- it is NOT a node target, so it never enters
  ;; `node-out-targets`, exactly as an error node's error name does not.
  (define make-pause-node
    (case-lambda
      ((name continuation source-label)
       (make-pause-node name continuation #f source-label))
      ((name continuation reason source-label)
       (require-symbol 'make-pause-node 'name name)
       (require-symbol 'make-pause-node 'continuation continuation)
       (unless (or (eq? reason #f) (symbol? reason))
         (byte-machine-contract-violation 'make-pause-node 'invalid-argument 'reason))
       (vector pause-node-tag name continuation reason source-label))))
  ;; pause-node? : Any -> Boolean
  (define (pause-node? x) (tagged? pause-node-tag x))
  ;; pause-node-name : PauseNode -> Symbol
  (define (pause-node-name n) (vector-ref n 1))
  ;; pause-node-continuation : PauseNode -> NodeName
  (define (pause-node-continuation n) (vector-ref n 2))
  ;; pause-node-reason : PauseNode -> (Option ErrorName)
  (define (pause-node-reason n) (vector-ref n 3))
  ;; pause-node-source-label : PauseNode -> Label
  (define (pause-node-source-label n) (vector-ref n 4))

  ;; --- zero-width field nodes ---
  ;; Both are ZERO-WIDTH: they consume no byte.
  ;;
  ;; This constructor checks `arguments` as a proper list AND NO FURTHER.
  ;; Everything needing the argument schema -- which position holds the field,
  ;; how many positions there are, what each means -- is the verifier's,
  ;; because exact arity is assigned there and nothing can be read out of
  ;; `arguments` before arity is known. So `low <= high` for a `range` predicate
  ;; is the VERIFIER's, even though `make-byte-range-matcher` rejects
  ;; `low > high`: there they are named parameters, here they are the second and
  ;; third elements of a list whose length this constructor is not entitled to
  ;; assume.
  ;;
  ;; What IS closed here is evaluable from the one node being built: the
  ;; operation and predicate sets (it rejects arbitrary operation names), the
  ;; symbols, and the error slot's rule below.
  ;; field-operations : (Listof FieldOperation)
  (define field-operations '(store clear increment decrement add set-mask clear-mask))
  ;; field-predicates : (Listof FieldPredicate)
  (define field-predicates '(equal zero nonzero range mask-any mask-all mask-none))
  ;; The four operations that provably cannot fail once their constant or mask is
  ;; range-checked against the field width -- which is the verifier's check, not
  ;; this one. `increment`, `decrement` and `add` can fail.
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
  ;; place that can. Precedent for a target-or-#f slot: `eof-target`.
  ;; make-field-action-node : name:Symbol operation:FieldOperation arguments:(Listof (U Symbol ExactInteger)) next:NodeName error:(Option NodeName) source-label:Label -> FieldActionNode
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
  ;; field-action-node? : Any -> Boolean
  (define (field-action-node? x) (tagged? field-action-node-tag x))
  ;; field-action-node-name : FieldActionNode -> Symbol
  (define (field-action-node-name n) (vector-ref n 1))
  ;; field-action-node-operation : FieldActionNode -> FieldOperation
  (define (field-action-node-operation n) (vector-ref n 2))
  ;; field-action-node-arguments : FieldActionNode -> (Listof (U Symbol ExactInteger))
  (define (field-action-node-arguments n) (vector-ref n 3))
  ;; field-action-node-next : FieldActionNode -> NodeName
  (define (field-action-node-next n) (vector-ref n 4))
  ;; field-action-node-error : FieldActionNode -> (Option NodeName)
  (define (field-action-node-error n) (vector-ref n 5))
  ;; field-action-node-source-label : FieldActionNode -> Label
  (define (field-action-node-source-label n) (vector-ref n 6))

  (define field-branch-node-tag (tag 'byte-machine-field-branch-node))
  ;; An explicit target is required for every possible result, so both targets
  ;; are mandatory symbols -- there is no #f arm and no fallthrough. This is the
  ;; kind that makes the EOF walk multi-successor.
  ;; make-field-branch-node : name:Symbol predicate:FieldPredicate arguments:(Listof (U Symbol ExactInteger)) true-target:NodeName false-target:NodeName source-label:Label -> FieldBranchNode
  (define (make-field-branch-node name predicate arguments true-target false-target source-label)
    (require-symbol 'make-field-branch-node 'name name)
    (unless (memq predicate field-predicates)
      (byte-machine-contract-violation 'make-field-branch-node 'invalid-argument 'predicate))
    (require-proper-list 'make-field-branch-node 'arguments arguments)
    (require-symbol 'make-field-branch-node 'true-target true-target)
    (require-symbol 'make-field-branch-node 'false-target false-target)
    (vector field-branch-node-tag name predicate arguments true-target false-target source-label))
  ;; field-branch-node? : Any -> Boolean
  (define (field-branch-node? x) (tagged? field-branch-node-tag x))
  ;; field-branch-node-name : FieldBranchNode -> Symbol
  (define (field-branch-node-name n) (vector-ref n 1))
  ;; field-branch-node-predicate : FieldBranchNode -> FieldPredicate
  (define (field-branch-node-predicate n) (vector-ref n 2))
  ;; field-branch-node-arguments : FieldBranchNode -> (Listof (U Symbol ExactInteger))
  (define (field-branch-node-arguments n) (vector-ref n 3))
  ;; field-branch-node-true-target : FieldBranchNode -> NodeName
  (define (field-branch-node-true-target n) (vector-ref n 4))
  ;; field-branch-node-false-target : FieldBranchNode -> NodeName
  (define (field-branch-node-false-target n) (vector-ref n 5))
  ;; field-branch-node-source-label : FieldBranchNode -> Label
  (define (field-branch-node-source-label n) (vector-ref n 6))

  ;; --- integer accumulate ---
  ;; The only INPUT-READING field-related kind: it consumes a byte and makes
  ;; progress, which separates it from the two zero-width field kinds at every
  ;; verifier site. It must NOT join `zero-width-successors`.
  ;;
  ;; Unlike the field-action/branch kinds, this one has no `arguments` list: its
  ;; operands are NAMED PARAMETERS. So `base` is closed here (validated at
  ;; construction), and only the FIELD REFERENCE, which needs the declaration
  ;; list to evaluate, is the verifier's.
  ;; accumulate-bases : (Listof AccumulateBase)
  (define accumulate-bases '(10 16))
  (define integer-accumulate-node-tag (tag 'byte-machine-integer-accumulate-node))
  ;; make-integer-accumulate-node : name:Symbol field:Symbol base:AccumulateBase digit-target:NodeName nondigit-edge:Edge overflow-error:NodeName eof-target:(Option NodeName) source-label:Label -> IntegerAccumulateNode
  (define (make-integer-accumulate-node name field base digit-target nondigit-edge
                                        overflow-error eof-target source-label)
    (require-symbol 'make-integer-accumulate-node 'name name)
    (require-symbol 'make-integer-accumulate-node 'field field)
    (unless (memv base accumulate-bases)
      (byte-machine-contract-violation 'make-integer-accumulate-node 'invalid-argument 'base))
    (require-symbol 'make-integer-accumulate-node 'digit-target digit-target)
    ;; An EDGE, not a bare target: the non-digit takes an explicit fallback
    ;; edge, normally reexecuting the delimiter, so the MODE is the whole point
    ;; and a bare symbol could not carry one.
    (unless (edge? nondigit-edge)
      (byte-machine-contract-violation 'make-integer-accumulate-node
                                       'invalid-argument 'nondigit-edge))
    ;; Never #f, unlike a field action's `error`: overflow takes an explicit
    ;; error edge, and accumulation can ALWAYS overflow -- there is no base or
    ;; width at which it cannot, so there is nothing for the can-it-fail rule to
    ;; decide.
    (require-symbol 'make-integer-accumulate-node 'overflow-error overflow-error)
    ;; #f means the machine default-eof error, the byte-dispatch convention.
    (unless (or (eq? eof-target #f) (symbol? eof-target))
      (byte-machine-contract-violation 'make-integer-accumulate-node
                                       'invalid-argument 'eof-target))
    (vector integer-accumulate-node-tag name field base digit-target nondigit-edge
            overflow-error eof-target source-label))
  ;; integer-accumulate-node? : Any -> Boolean
  (define (integer-accumulate-node? x) (tagged? integer-accumulate-node-tag x))
  ;; integer-accumulate-node-name : IntegerAccumulateNode -> Symbol
  (define (integer-accumulate-node-name n) (vector-ref n 1))
  ;; integer-accumulate-node-field : IntegerAccumulateNode -> Symbol
  (define (integer-accumulate-node-field n) (vector-ref n 2))
  ;; integer-accumulate-node-base : IntegerAccumulateNode -> AccumulateBase
  (define (integer-accumulate-node-base n) (vector-ref n 3))
  ;; integer-accumulate-node-digit-target : IntegerAccumulateNode -> NodeName
  (define (integer-accumulate-node-digit-target n) (vector-ref n 4))
  ;; integer-accumulate-node-nondigit-edge : IntegerAccumulateNode -> Edge
  (define (integer-accumulate-node-nondigit-edge n) (vector-ref n 5))
  ;; integer-accumulate-node-overflow-error : IntegerAccumulateNode -> NodeName
  (define (integer-accumulate-node-overflow-error n) (vector-ref n 6))
  ;; integer-accumulate-node-eof-target : IntegerAccumulateNode -> (Option NodeName)
  (define (integer-accumulate-node-eof-target n) (vector-ref n 7))
  ;; integer-accumulate-node-source-label : IntegerAccumulateNode -> Label
  (define (integer-accumulate-node-source-label n) (vector-ref n 8))

  ;; --- error node (references a declaration by NAME) ---
  (define error-node-tag (tag 'byte-machine-error-node))
  ;; make-error-node : name:Symbol error-declaration:ErrorName source-label:Label -> ErrorNode
  (define (make-error-node name error-declaration source-label)
    (require-symbol 'make-error-node 'name name)
    (require-symbol 'make-error-node 'error-declaration error-declaration)
    (vector error-node-tag name error-declaration source-label))
  ;; error-node? : Any -> Boolean
  (define (error-node? x) (tagged? error-node-tag x))
  ;; error-node-name : ErrorNode -> Symbol
  (define (error-node-name n) (vector-ref n 1))
  ;; error-node-error-name : ErrorNode -> ErrorName
  (define (error-node-error-name n) (vector-ref n 2))
  ;; error-node-source-label : ErrorNode -> Label
  (define (error-node-source-label n) (vector-ref n 3))

  ;; --- error declaration ---
  (define error-declaration-tag (tag 'byte-machine-error-declaration))
  ;; make-error-declaration : name:Symbol code:Symbol reason:String source-label:Label -> ErrorDeclaration
  (define (make-error-declaration name code reason source-label)
    (require-symbol 'make-error-declaration 'name name)
    (require-symbol 'make-error-declaration 'code code)
    (unless (string? reason)
      (byte-machine-contract-violation 'make-error-declaration 'invalid-argument 'reason))
    (vector error-declaration-tag name code reason source-label))
  ;; error-declaration? : Any -> Boolean
  (define (error-declaration? x) (tagged? error-declaration-tag x))
  ;; error-declaration-name : ErrorDeclaration -> Symbol
  (define (error-declaration-name d) (vector-ref d 1))
  ;; error-declaration-code : ErrorDeclaration -> Symbol
  (define (error-declaration-code d) (vector-ref d 2))
  ;; error-declaration-reason : ErrorDeclaration -> String
  (define (error-declaration-reason d) (vector-ref d 3))
  ;; error-declaration-source-label : ErrorDeclaration -> Label
  (define (error-declaration-source-label d) (vector-ref d 4))

  ;; --- sequence case ---
  ;; A byte list and a bare TARGET, with no mode. A successful sequence consumes
  ;; every byte in it, so giving a case an advance/reexecute mode would
  ;; reintroduce the lookahead that consuming forbids. The mismatch EDGE on the
  ;; node below carries the only mode a sequence has. The accessor copies for
  ;; the same reason byte-set-matcher-bytes does: constructors return
  ;; immutable-by-API descriptors, and a copy preserves order and duplicates, so
  ;; it is not a forbidden semantic transform.
  (define sequence-case-tag (tag 'byte-machine-sequence-case))
  ;; make-sequence-case : bytes:(Listof Byte) target:NodeName source-label:Label -> SequenceCase
  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-sequence-case 'invalid-argument 'bytes))
    (require-symbol 'make-sequence-case 'target target)
    (vector sequence-case-tag (append bytes '()) target source-label))
  ;; sequence-case? : Any -> Boolean
  (define (sequence-case? x) (tagged? sequence-case-tag x))
  ;; sequence-case-bytes : SequenceCase -> (Listof Byte) -- fresh copy
  (define (sequence-case-bytes c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-bytes 'invalid-argument 'case))
    (append (vector-ref c 1) '()))
  ;; sequence-case-target : SequenceCase -> NodeName
  (define (sequence-case-target c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-target 'invalid-argument 'case))
    (vector-ref c 2))
  ;; Tag-guarded like its two siblings above, and reported under the owning node
  ;; by the verifier, as a byte case's label is.
  ;; sequence-case-source-label : SequenceCase -> Label
  (define (sequence-case-source-label c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-source-label 'invalid-argument 'case))
    (vector-ref c 3))

  ;; --- sequence-dispatch node ---
  ;; Matches one of a finite set of exact byte sequences without backtracking;
  ;; alternatives may share nonterminal prefixes. Whether two alternatives
  ;; collide is a cross-case property, so it is verification's job, not this
  ;; constructor's.
  (define sequence-dispatch-node-tag (tag 'byte-machine-sequence-dispatch-node))
  ;; make-sequence-dispatch-node : name:Symbol cases:(Listof SequenceCase) mismatch:Edge eof-target:(Option NodeName) source-label:Label -> SequenceDispatchNode
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
  ;; sequence-dispatch-node? : Any -> Boolean
  (define (sequence-dispatch-node? x) (tagged? sequence-dispatch-node-tag x))
  ;; sequence-dispatch-node-name : SequenceDispatchNode -> Symbol
  (define (sequence-dispatch-node-name n) (vector-ref n 1))
  ;; sequence-dispatch-node-cases : SequenceDispatchNode -> (Listof SequenceCase)
  (define (sequence-dispatch-node-cases n) (vector-ref n 2))
  ;; sequence-dispatch-node-mismatch : SequenceDispatchNode -> Edge
  (define (sequence-dispatch-node-mismatch n) (vector-ref n 3))
  ;; sequence-dispatch-node-eof-target : SequenceDispatchNode -> (Option NodeName)
  (define (sequence-dispatch-node-eof-target n) (vector-ref n 4))
  ;; sequence-dispatch-node-source-label : SequenceDispatchNode -> Label
  (define (sequence-dispatch-node-source-label n) (vector-ref n 5))

  ;; --- keyword entry ---
  ;; A byte list and a bare TARGET, with no mode -- the keyword-table node's
  ;; no-match EDGE carries the only mode a table has, exactly as a sequence
  ;; case's target carries none. Kept distinct from sequence-case so the two node
  ;; kinds' opposite cross-entry rules -- a sequence rejects shared terminal
  ;; prefixes, a keyword table permits them -- never share a record. The accessor
  ;; copies for the same reason sequence-case-bytes does.
  (define keyword-entry-tag (tag 'byte-machine-keyword-entry))
  ;; make-keyword-entry : bytes:(Listof Byte) target:NodeName source-label:Label -> KeywordEntry
  (define (make-keyword-entry bytes target source-label)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-keyword-entry 'invalid-argument 'bytes))
    (require-symbol 'make-keyword-entry 'target target)
    (vector keyword-entry-tag (append bytes '()) target source-label))
  ;; keyword-entry? : Any -> Boolean
  (define (keyword-entry? x) (tagged? keyword-entry-tag x))
  ;; keyword-entry-bytes : KeywordEntry -> (Listof Byte) -- fresh copy
  (define (keyword-entry-bytes e)
    (unless (keyword-entry? e)
      (byte-machine-contract-violation 'keyword-entry-bytes 'invalid-argument 'entry))
    (append (vector-ref e 1) '()))
  ;; keyword-entry-target : KeywordEntry -> NodeName
  (define (keyword-entry-target e)
    (unless (keyword-entry? e)
      (byte-machine-contract-violation 'keyword-entry-target 'invalid-argument 'entry))
    (vector-ref e 2))
  ;; keyword-entry-source-label : KeywordEntry -> Label
  (define (keyword-entry-source-label e)
    (unless (keyword-entry? e)
      (byte-machine-contract-violation 'keyword-entry-source-label 'invalid-argument 'entry))
    (vector-ref e 3))

  ;; --- keyword-table node ---
  ;; Matches one of a set of keywords, tolerating proper prefixes (GET vs
  ;; GET-PARAMETER) that make-sequence-dispatch-node rejects, and -- optionally,
  ;; per table -- case-insensitively. Whether two keywords collide (an exact
  ;; duplicate, or a fold collision in a case-insensitive table) is a cross-entry
  ;; property, so it is verification's job, not this constructor's.
  (define keyword-table-node-tag (tag 'byte-machine-keyword-table-node))
  ;; make-keyword-table-node : name:Symbol entries:(Listof KeywordEntry) no-match:Edge eof-target:(Option NodeName) case-insensitive?:Boolean source-label:Label -> KeywordTableNode
  (define (make-keyword-table-node name entries no-match eof-target case-insensitive? source-label)
    (require-symbol 'make-keyword-table-node 'name name)
    (unless (and (list? entries) (pair? entries) (for-all keyword-entry? entries))
      (byte-machine-contract-violation 'make-keyword-table-node 'invalid-argument 'entries))
    (unless (edge? no-match)
      (byte-machine-contract-violation 'make-keyword-table-node 'invalid-argument 'no-match))
    ;; eof-target is a node name, or #f for the machine default eof error.
    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-keyword-table-node 'invalid-argument 'eof-target))
    (unless (boolean? case-insensitive?)
      (byte-machine-contract-violation 'make-keyword-table-node 'invalid-argument 'case-insensitive?))
    (vector keyword-table-node-tag name entries no-match eof-target case-insensitive? source-label))
  ;; keyword-table-node? : Any -> Boolean
  (define (keyword-table-node? x) (tagged? keyword-table-node-tag x))
  ;; keyword-table-node-name : KeywordTableNode -> Symbol
  (define (keyword-table-node-name n) (vector-ref n 1))
  ;; keyword-table-node-entries : KeywordTableNode -> (Listof KeywordEntry)
  (define (keyword-table-node-entries n) (vector-ref n 2))
  ;; keyword-table-node-no-match : KeywordTableNode -> Edge
  (define (keyword-table-node-no-match n) (vector-ref n 3))
  ;; keyword-table-node-eof-target : KeywordTableNode -> (Option NodeName)
  (define (keyword-table-node-eof-target n) (vector-ref n 4))
  ;; keyword-table-node-case-insensitive? : KeywordTableNode -> Boolean
  (define (keyword-table-node-case-insensitive? n) (vector-ref n 5))
  ;; keyword-table-node-source-label : KeywordTableNode -> Label
  (define (keyword-table-node-source-label n) (vector-ref n 6))

  ;; --- callback-invocation node ---
  ;; Zero-width: a callback invocation does not consume input, so it joins the
  ;; verifier's `zero-width-edges` census and never the input-reading arms
  ;; beside it.
  ;;
  ;; This constructor checks only local shape. `branch-targets` is checked for
  ;; the shape every branch map uses -- two-element lists (key target), not
  ;; implementation hash tables, the same convention used for callback bindings
  ;; -- and for nothing else. Whether `callback` names a declared callback,
  ;; whether that declaration is an `event` or a `decision`, and whether these
  ;; keys are the keys it declared are three CROSS-REFERENCES against the
  ;; machine's callback table, which this constructor cannot see at all; the
  ;; verifier owns all three, and the comment on make-uint-field above states
  ;; what moving one of them here would cost.
  (define callback-node-tag (tag 'byte-machine-callback-node))
  ;; make-callback-node : name:Symbol callback:Symbol continue-target:NodeName branch-targets:(Listof (List Symbol NodeName)) pause-continuation:NodeName [reason:(Option ErrorName)] source-label:Label -> CallbackNode
  ;; The OPTIONAL reason is a declared error-declaration NAME, or #f (the
  ;; 6-argument form), carried on the SECOND author-facing pause path: when this
  ;; node's callback returns `callback-pause`, the runtime reports this reason.
  (define make-callback-node
    (case-lambda
      ((name callback continue-target branch-targets pause-continuation source-label)
       (make-callback-node name callback continue-target branch-targets
                           pause-continuation #f source-label))
      ((name callback continue-target branch-targets pause-continuation reason source-label)
       (require-symbol 'make-callback-node 'name name)
       (require-symbol 'make-callback-node 'callback callback)
       ;; Every invocation declares a continue target and a pause continuation.
       ;; Both are mandatory symbols with no #f arm -- the field-branch precedent
       ;; (an explicit target for every possible result), not the byte-dispatch
       ;; eof-target one where #f means a default.
       (require-symbol 'make-callback-node 'continue-target continue-target)
       (require-symbol 'make-callback-node 'pause-continuation pause-continuation)
       (unless (or (eq? reason #f) (symbol? reason))
         (byte-machine-contract-violation 'make-callback-node 'invalid-argument 'reason))
       ;; An EMPTY branch list is legal here and is the ordinary event-callback
       ;; shape: a callback node invokes one named event or decision callback, and
       ;; only a decision has branch keys at all. Rejecting `'()` would make every
       ;; event invocation unbuildable.
       (unless (and (list? branch-targets)
                    (for-all (lambda (b)
                               (and (list? b) (= (length b) 2)
                                    (symbol? (car b)) (symbol? (cadr b))))
                             branch-targets))
         (byte-machine-contract-violation 'make-callback-node
                                          'invalid-argument 'branch-targets))
       (vector callback-node-tag name callback continue-target
               (map (lambda (b) (list (car b) (cadr b))) branch-targets)
               pause-continuation reason source-label))))
  ;; callback-node? : Any -> Boolean
  (define (callback-node? x) (tagged? callback-node-tag x))
  ;; callback-node-name : CallbackNode -> Symbol
  (define (callback-node-name n) (vector-ref n 1))
  ;; callback-node-callback : CallbackNode -> Symbol
  (define (callback-node-callback n) (vector-ref n 2))
  ;; callback-node-continue-target : CallbackNode -> NodeName
  (define (callback-node-continue-target n) (vector-ref n 3))
  ;; callback-node-branch-targets : CallbackNode -> (Listof (List Symbol NodeName))
  (define (callback-node-branch-targets n) (vector-ref n 4))
  ;; callback-node-pause-continuation : CallbackNode -> NodeName
  (define (callback-node-pause-continuation n) (vector-ref n 5))
  ;; callback-node-reason : CallbackNode -> (Option ErrorName)
  (define (callback-node-reason n) (vector-ref n 6))
  ;; callback-node-source-label : CallbackNode -> Label
  (define (callback-node-source-label n) (vector-ref n 7))

  ;; --- span nodes ---
  ;; The pair that makes the machine hand out ranges of input it has already
  ;; seen. Both are ZERO-WIDTH: neither consumes input, so both join the
  ;; verifier's `zero-width-edges` census and never the input-reading arms.
  ;;
  ;; This constructor checks only local shape. `span` is a symbol and nothing
  ;; more: whether it names a DECLARED span, whether that span is the one
  ;; currently open, and whether any reachable path opens two at once are all
  ;; judgements that need the machine's span table and its whole graph, which
  ;; this constructor cannot see.
  ;;
  ;; Those three span judgements do not share one owner. DECLAREDNESS -- whether
  ;; `span` names a declared span -- is `pass-declarations`' (it raises
  ;; `missing-span-declaration`); a lattice over span STATE is well defined for
  ;; any symbol and so cannot tell a declared name from an undeclared one. Which
  ;; span is open, and whether two are open at once, are the verifier's
  ;; span-state lattice.
  ;;
  ;; One mandatory successor each, on the field-action precedent rather than the
  ;; byte-dispatch eof-target one: neither span kind is given a route of its own
  ;; for anything, so there is no case for a #f arm.
  (define span-start-node-tag (tag 'byte-machine-span-start-node))
  ;; make-span-start-node : name:Symbol span:Symbol next:NodeName source-label:Label -> SpanStartNode
  (define (make-span-start-node name span next source-label)
    (require-symbol 'make-span-start-node 'name name)
    (require-symbol 'make-span-start-node 'span span)
    (require-symbol 'make-span-start-node 'next next)
    (vector span-start-node-tag name span next source-label))
  ;; span-start-node? : Any -> Boolean
  (define (span-start-node? x) (tagged? span-start-node-tag x))
  ;; span-start-node-name : SpanStartNode -> Symbol
  (define (span-start-node-name n) (vector-ref n 1))
  ;; span-start-node-span : SpanStartNode -> Symbol
  (define (span-start-node-span n) (vector-ref n 2))
  ;; span-start-node-next : SpanStartNode -> NodeName
  (define (span-start-node-next n) (vector-ref n 3))
  ;; span-start-node-source-label : SpanStartNode -> Label
  (define (span-start-node-source-label n) (vector-ref n 4))

  ;; A span END is one node HERE and several states after lowering: resumption
  ;; happens at the next undelivered substep, so lowering gives it one internal
  ;; state per substep. None of that is visible at construction -- the lattice
  ;; runs over the declared graph, where a span end is one node to this
  ;; analysis, whatever it lowers to afterwards.
  (define span-end-node-tag (tag 'byte-machine-span-end-node))
  ;; make-span-end-node : name:Symbol span:Symbol next:NodeName source-label:Label -> SpanEndNode
  (define (make-span-end-node name span next source-label)
    (require-symbol 'make-span-end-node 'name name)
    (require-symbol 'make-span-end-node 'span span)
    (require-symbol 'make-span-end-node 'next next)
    (vector span-end-node-tag name span next source-label))
  ;; span-end-node? : Any -> Boolean
  (define (span-end-node? x) (tagged? span-end-node-tag x))
  ;; span-end-node-name : SpanEndNode -> Symbol
  (define (span-end-node-name n) (vector-ref n 1))
  ;; span-end-node-span : SpanEndNode -> Symbol
  (define (span-end-node-span n) (vector-ref n 2))
  ;; span-end-node-next : SpanEndNode -> NodeName
  (define (span-end-node-next n) (vector-ref n 3))
  ;; span-end-node-source-label : SpanEndNode -> Label
  (define (span-end-node-source-label n) (vector-ref n 4))

  ;; --- counted consume ---
  ;; INPUT-READING, but also has a route taken with no input present at all: a
  ;; zero count transitions to `next` immediately, at EOF and on an empty feed
  ;; -- where accumulate's non-consuming overflow edge still needs a byte to
  ;; examine. `next` is mandatory -- a count that reaches zero always has
  ;; somewhere to go -- and `eof-target` follows the byte-dispatch convention,
  ;; #f meaning the machine default EOF error. No `error` slot, unlike a field
  ;; action's: the subtraction cannot underflow, because the committed count
  ;; never exceeds the field's value, so there is nothing for an error edge to
  ;; carry. The FIELD REFERENCE is the verifier's (checked by
  ;; pass-field-operands), as accumulate's is.
  (define counted-consume-node-tag (tag 'byte-machine-counted-consume-node))
  ;; make-counted-consume-node : name:Symbol field:Symbol next:NodeName eof-target:(Option NodeName) source-label:Label -> CountedConsumeNode
  (define (make-counted-consume-node name field next eof-target source-label)
    (require-symbol 'make-counted-consume-node 'name name)
    (require-symbol 'make-counted-consume-node 'field field)
    (require-symbol 'make-counted-consume-node 'next next)
    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-counted-consume-node
                                       'invalid-argument 'eof-target))
    (vector counted-consume-node-tag name field next eof-target source-label))
  ;; counted-consume-node? : Any -> Boolean
  (define (counted-consume-node? x) (tagged? counted-consume-node-tag x))
  ;; counted-consume-node-name : CountedConsumeNode -> Symbol
  (define (counted-consume-node-name n) (vector-ref n 1))
  ;; counted-consume-node-field : CountedConsumeNode -> Symbol
  (define (counted-consume-node-field n) (vector-ref n 2))
  ;; counted-consume-node-next : CountedConsumeNode -> NodeName
  (define (counted-consume-node-next n) (vector-ref n 3))
  ;; counted-consume-node-eof-target : CountedConsumeNode -> (Option NodeName)
  (define (counted-consume-node-eof-target n) (vector-ref n 4))
  ;; counted-consume-node-source-label : CountedConsumeNode -> Label
  (define (counted-consume-node-source-label n) (vector-ref n 5))

  ;; --- node dispatch ---
  ;; node? : Any -> Boolean
  (define (node? x)
    (or (byte-dispatch-node? x) (sequence-dispatch-node? x)
        (keyword-table-node? x) (stop-node? x)
        (error-node? x) (finish-node? x) (pause-node? x)
        (field-action-node? x) (field-branch-node? x)
        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))
  ;; node-name : Node -> Symbol
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((sequence-dispatch-node? x) (sequence-dispatch-node-name x))
          ((keyword-table-node? x) (keyword-table-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          ((finish-node? x) (finish-node-name x))
          ((pause-node? x) (pause-node-name x))
          ((field-action-node? x) (field-action-node-name x))
          ((field-branch-node? x) (field-branch-node-name x))
          ((integer-accumulate-node? x) (integer-accumulate-node-name x))
          ((callback-node? x) (callback-node-name x))
          ((span-start-node? x) (span-start-node-name x))
          ((span-end-node? x) (span-end-node-name x))
          ((counted-consume-node? x) (counted-consume-node-name x))
          (else (byte-machine-contract-violation 'node-name 'invalid-argument 'node))))
  ;; `node-source-label` mirrors `node-name`'s shape -- one arm per kind above a
  ;; raising `else` -- for the one other field every node kind carries, so the
  ;; verifier's label clause is total over the node kinds from one accessor
  ;; rather than one per kind. A new node kind owes this cond an arm.
  ;; node-source-label : Node -> Label
  (define (node-source-label x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-source-label x))
          ((sequence-dispatch-node? x) (sequence-dispatch-node-source-label x))
          ((keyword-table-node? x) (keyword-table-node-source-label x))
          ((stop-node? x) (stop-node-source-label x))
          ((error-node? x) (error-node-source-label x))
          ((finish-node? x) (finish-node-source-label x))
          ((pause-node? x) (pause-node-source-label x))
          ((field-action-node? x) (field-action-node-source-label x))
          ((field-branch-node? x) (field-branch-node-source-label x))
          ((integer-accumulate-node? x) (integer-accumulate-node-source-label x))
          ((callback-node? x) (callback-node-source-label x))
          ((span-start-node? x) (span-start-node-source-label x))
          ((span-end-node? x) (span-end-node-source-label x))
          ((counted-consume-node? x) (counted-consume-node-source-label x))
          (else (byte-machine-contract-violation 'node-source-label 'invalid-argument 'node))))

  ;; --- uint field descriptor ---
  ;; The four parts of a field: a symbolic name, an unsigned width of 8, 16, 32
  ;; or 64 bits, an initial exact-integer value within that width, and an
  ;; optional diagnostic label.
  ;;
  ;; Every check here is the constructor's local half -- closed-set membership
  ;; and the local shape of the one value being built -- on the make-edge
  ;; precedent above, which memq-checks `mode` at construction even though
  ;; advancement modes are otherwise the verifier's. A contract violation is not
  ;; a diagnostic, so none of these carries a code, and no verifier pass
  ;; re-checks them: a machine whose field failed construction never exists, so
  ;; such an arm would be unreachable through any public API.
  ;;
  ;; Unsigned integer is the only field TYPE.
  (define uint-field-tag (tag 'byte-machine-uint-field))
  ;; make-uint-field : name:Symbol width:UintWidth initial:ExactInteger [settable?:Boolean] source-label:Label -> UintField
  ;; The OPTIONAL `settable?` (default `#f`, the 4-argument form) marks a field
  ;; whose INITIAL an embedder may override at `make-parser`, so a grammar with
  ;; an embedder-chosen mode (llhttp's request/response `type`, its
  ;; `lenient_flags` bitset) needs no entry nodes to write it. The flag is a
  ;; leaf datum: local shape (a boolean) is checked here, and that a settable
  ;; field is used LEGALLY -- never as a counted-consume counter, whose
  ;; entry-value the verifier reasons about -- is the verifier's.
  (define make-uint-field
    (case-lambda
      ((name width initial source-label)
       (make-uint-field name width initial #f source-label))
      ((name width initial settable? source-label)
       (require-symbol 'make-uint-field 'name name)
       (unless (memq width '(8 16 32 64))
         (byte-machine-contract-violation 'make-uint-field 'invalid-argument 'width))
       ;; `exact-integer?` is not R6RS; the pair below is what (rnrs) gives, and
       ;; the range is inclusive at both ends. The u64 upper bound is a bignum on
       ;; every supported runtime -- (greatest-fixnum) is 2^60-1 -- so this
       ;; comparison must not be narrowed to fixnum arithmetic.
       (unless (and (integer? initial) (exact? initial)
                    (<= 0 initial (- (expt 2 width) 1)))
         (byte-machine-contract-violation 'make-uint-field 'invalid-argument 'initial))
       (unless (boolean? settable?)
         (byte-machine-contract-violation 'make-uint-field 'invalid-argument 'settable?))
       (vector uint-field-tag name width initial settable? source-label))))
  ;; uint-field? : Any -> Boolean
  (define (uint-field? x) (tagged? uint-field-tag x))
  ;; uint-field-name : UintField -> Symbol
  (define (uint-field-name f) (vector-ref f 1))
  ;; uint-field-width : UintField -> UintWidth
  (define (uint-field-width f) (vector-ref f 2))
  ;; uint-field-initial : UintField -> ExactInteger
  (define (uint-field-initial f) (vector-ref f 3))
  ;; uint-field-settable? : UintField -> Boolean
  (define (uint-field-settable? f) (vector-ref f 4))
  ;; uint-field-source-label : UintField -> Label
  (define (uint-field-source-label f) (vector-ref f 5))

  ;; --- callback declaration ---
  ;; The six parts of a callback declaration: a symbolic name, a kind from a
  ;; closed set, a required?/optional flag, the branch keys an optional decision
  ;; callback may return, the default branch for one, and an optional diagnostic
  ;; label.
  ;;
  ;; What is deliberately NOT checked here, and why. Three checks are locally
  ;; evaluable from these six arguments yet all three belong to the verifier:
  ;;   - an optional DECISION callback without a valid declared default branch
  ;;     -- `kind`, `required?`, `branch-keys` and `default-branch` are all
  ;;     right here, and it is still the verifier's;
  ;;   - a branch key colliding with the reserved `continue` or `pause`;
  ;;   - the grammar over `name` and the branch keys.
  ;; The comment on make-uint-field above states the consequence of moving one
  ;; of them here, and it is not a style point: a machine whose construction
  ;; failed never exists, so the verifier arm becomes unreachable through the
  ;; public API. Local SHAPE is this constructor's; every judgement about the
  ;; declaration's CONTENT is the verifier's.
  (define callback-declaration-tag (tag 'byte-machine-callback-declaration))
  ;; make-callback-declaration : name:Symbol kind:CallbackKind required?:Boolean branch-keys:(Listof Symbol) default-branch:(Option Symbol) source-label:Label -> CallbackDeclaration
  (define (make-callback-declaration name kind required? branch-keys
                                     default-branch source-label)
    (require-symbol 'make-callback-declaration 'name name)
    (unless (memq kind '(event decision span-data span-complete))
      (byte-machine-contract-violation 'make-callback-declaration
                                       'invalid-argument 'kind))
    (unless (boolean? required?)
      (byte-machine-contract-violation 'make-callback-declaration
                                       'invalid-argument 'required?))
    ;; Shape only: that the keys are a proper list of symbols. WHICH keys are
    ;; admissible, and whether `default-branch` is among them, is the verifier's.
    (unless (and (list? branch-keys) (for-all symbol? branch-keys))
      (byte-machine-contract-violation 'make-callback-declaration
                                       'invalid-argument 'branch-keys))
    (unless (or (eq? default-branch #f) (symbol? default-branch))
      (byte-machine-contract-violation 'make-callback-declaration
                                       'invalid-argument 'default-branch))
    (vector callback-declaration-tag name kind required? branch-keys
            default-branch source-label))
  ;; callback-declaration? : Any -> Boolean
  (define (callback-declaration? x) (tagged? callback-declaration-tag x))
  ;; callback-declaration-name : CallbackDeclaration -> Symbol
  (define (callback-declaration-name d) (vector-ref d 1))
  ;; callback-declaration-kind : CallbackDeclaration -> CallbackKind
  (define (callback-declaration-kind d) (vector-ref d 2))
  ;; callback-declaration-required? : CallbackDeclaration -> Boolean
  (define (callback-declaration-required? d) (vector-ref d 3))
  ;; callback-declaration-branch-keys : CallbackDeclaration -> (Listof Symbol)
  (define (callback-declaration-branch-keys d) (vector-ref d 4))
  ;; callback-declaration-default-branch : CallbackDeclaration -> (Option Symbol)
  (define (callback-declaration-default-branch d) (vector-ref d 5))
  ;; callback-declaration-source-label : CallbackDeclaration -> Label
  (define (callback-declaration-source-label d) (vector-ref d 6))

  ;; --- span declaration ---
  ;; The four parts of a span declaration. Both callback slots are declaration
  ;; NAMES, not declarations: the verifier is what resolves them and checks
  ;; their kinds (a cross-reference), and this constructor cannot see the
  ;; callback table at all.
  (define span-declaration-tag (tag 'byte-machine-span-declaration))
  ;; make-span-declaration : name:Symbol data-callback:Symbol complete-callback:(Option Symbol) source-label:Label -> SpanDeclaration
  (define (make-span-declaration name data-callback complete-callback
                                 source-label)
    (require-symbol 'make-span-declaration 'name name)
    (require-symbol 'make-span-declaration 'data-callback data-callback)
    ;; The completion callback is optional; #f is its absence, on the
    ;; byte-dispatch eof-target convention.
    (unless (or (eq? complete-callback #f) (symbol? complete-callback))
      (byte-machine-contract-violation 'make-span-declaration
                                       'invalid-argument 'complete-callback))
    (vector span-declaration-tag name data-callback complete-callback
            source-label))
  ;; span-declaration? : Any -> Boolean
  (define (span-declaration? x) (tagged? span-declaration-tag x))
  ;; span-declaration-name : SpanDeclaration -> Symbol
  (define (span-declaration-name d) (vector-ref d 1))
  ;; span-declaration-data-callback : SpanDeclaration -> Symbol
  (define (span-declaration-data-callback d) (vector-ref d 2))
  ;; span-declaration-complete-callback : SpanDeclaration -> (Option Symbol)
  (define (span-declaration-complete-callback d) (vector-ref d 3))
  ;; span-declaration-source-label : SpanDeclaration -> Label
  (define (span-declaration-source-label d) (vector-ref d 4))

  ;; --- machine (default-eof-error is a declared error NAME) ---
  (define machine-tag (tag 'byte-machine-machine))
  (define machine-ir-version 1)     ; stamped; no argument overrides it
  ;; The version pass-schema accepts. Named separately from the stamp so the two
  ;; are distinct: the stamp is what is built, this is what is accepted, and only
  ;; the second is a verifier decision.
  ;; supported-ir-version : ExactInteger
  (define supported-ir-version 1)
  ;; make-machine : name:Symbol entry:NodeName fields:(Listof UintField) callbacks:(Listof CallbackDeclaration) spans:(Listof SpanDeclaration) errors:(Listof ErrorDeclaration) nodes:(Listof Node) default-eof-error:ErrorName source-label:Label -> Machine
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
    ;; The collection loop above checks only `list?`; without this guard any
    ;; proper list -- (junk 42 "string") -- would be accepted as `fields`.
    (unless (for-all uint-field? fields)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'fields))
    ;; The same as the fields guard above and for the same reason: a proper list
    ;; of junk would otherwise be a valid callbacks or spans table.
    (unless (for-all callback-declaration? callbacks)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'callbacks))
    (unless (for-all span-declaration? spans)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'spans))
    (vector machine-tag machine-ir-version name entry fields callbacks spans
            errors nodes default-eof-error source-label))
  ;; machine? : Any -> Boolean
  (define (machine? x) (tagged? machine-tag x))
  ;; Slot 1, stamped as the constant above and never taken from an argument.
  ;; pass-schema reads it for the unsupported-IR-version check.
  ;; machine-ir-version-of : Machine -> ExactInteger
  (define (machine-ir-version-of m) (vector-ref m 1))
  ;; machine-name : Machine -> Symbol
  (define (machine-name m) (vector-ref m 2))
  ;; machine-entry : Machine -> NodeName
  (define (machine-entry m) (vector-ref m 3))
  ;; machine-fields : Machine -> (Listof UintField)
  (define (machine-fields m) (vector-ref m 4))
  ;; machine-callbacks : Machine -> (Listof CallbackDeclaration)
  (define (machine-callbacks m) (vector-ref m 5))
  ;; machine-spans : Machine -> (Listof SpanDeclaration)
  (define (machine-spans m) (vector-ref m 6))
  ;; machine-errors : Machine -> (Listof ErrorDeclaration)
  (define (machine-errors m) (vector-ref m 7))
  ;; machine-nodes : Machine -> (Listof Node)
  (define (machine-nodes m) (vector-ref m 8))
  ;; machine-default-eof-error : Machine -> ErrorName
  (define (machine-default-eof-error m) (vector-ref m 9))
  ;; machine-source-label : Machine -> Label
  (define (machine-source-label m) (vector-ref m 10))

  ;; --- verification result (carries the machine) ---
  (define verification-result-tag (tag 'byte-machine-verification-result))
  ;; make-verification-result : ok?:Boolean diagnostics:(Listof Diagnostic) machine:Machine -> VerificationResult
  (define (make-verification-result ok? diagnostics machine)
    (vector verification-result-tag ok? diagnostics machine))
  ;; verification-result? : Any -> Boolean
  (define (verification-result? x) (tagged? verification-result-tag x))
  ;; verification-result-ok? : VerificationResult -> Boolean
  (define (verification-result-ok? v) (vector-ref v 1))
  ;; verification-result-diagnostics : VerificationResult -> (Listof Diagnostic)
  (define (verification-result-diagnostics v) (vector-ref v 2))
  ;; verification-result-machine : VerificationResult -> Machine
  (define (verification-result-machine v) (vector-ref v 3)))
