;;; Immutable source-IR descriptors (parent §9.1, §10), M1 subset: the machine,
;;; byte-dispatch/stop/error nodes, exact-byte matcher, edge, error
;;; declaration, and the verification-result value. Tagged vectors behind
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
          make-edge edge? edge-target edge-mode
          make-stop-node stop-node? stop-node-name
          make-finish-node finish-node? finish-node-name
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

  ;; --- exact-byte matcher ---
  (define exact-byte-matcher-tag (tag 'byte-machine-exact-byte-matcher))
  (define (make-exact-byte-matcher byte)
    (unless (and (integer? byte) (exact? byte) (<= 0 byte 255))
      (byte-machine-contract-violation 'make-exact-byte-matcher 'invalid-argument 'byte))
    (vector exact-byte-matcher-tag byte))
  (define (exact-byte-matcher? x) (tagged? exact-byte-matcher-tag x))
  (define (exact-byte-matcher-byte m) (vector-ref m 1))

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
    (unless (exact-byte-matcher? matcher)
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
    (or (byte-dispatch-node? x) (stop-node? x) (error-node? x) (finish-node? x)))
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          ((finish-node? x) (finish-node-name x))
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
