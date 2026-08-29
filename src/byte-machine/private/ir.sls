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
          make-error-declaration error-declaration? error-declaration-name
          error-declaration-code error-declaration-reason
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
  ;; canonicalization. The list itself IS copied at construction, with
  ;; `(append bytes '())` rather than `list-copy` (unbound under a bare
  ;; `(rnrs)` import) -- so §9.1's "immutable-by-API descriptor" holds: a
  ;; caller who later mutates the list they passed in (set-car!, etc.) cannot
  ;; reach back into an already-built matcher. Copying is not the transform
  ;; decision 0017 point 3 forbids -- it changes the list's identity, not its
  ;; order or membership, and byte-set-matcher-bytes below still returns
  ;; exactly that copy, unsorted and undeduplicated.
  (define byte-set-matcher-tag (tag 'byte-machine-byte-set-matcher))
  (define (make-byte-set-matcher bytes)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-byte-set-matcher 'invalid-argument 'bytes))
    (vector byte-set-matcher-tag (append bytes '())))
  (define (byte-set-matcher? x) (tagged? byte-set-matcher-tag x))
  (define (byte-set-matcher-bytes m)
    (unless (byte-set-matcher? m)
      (byte-machine-contract-violation 'byte-set-matcher-bytes 'invalid-argument 'matcher))
    (vector-ref m 1))

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

  ;; --- node dispatch ---
  (define (node? x)
    (or (byte-dispatch-node? x) (stop-node? x) (error-node? x) (finish-node? x) (pause-node? x)))
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          ((finish-node? x) (finish-node-name x))
          ((pause-node? x) (pause-node-name x))
          (else (byte-machine-contract-violation 'node-name 'invalid-argument 'node))))

  ;; --- machine (default-eof-error is a declared error NAME) ---
  (define machine-tag (tag 'byte-machine-machine))
  (define machine-ir-version 1)     ; stamped; v0.1 callers do not override (§9.1)
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
    (vector machine-tag machine-ir-version name entry fields callbacks spans
            errors nodes default-eof-error source-label))
  (define (machine? x) (tagged? machine-tag x))
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
