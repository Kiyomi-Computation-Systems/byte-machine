;;; (byte-machine private normal-ir): the normalizer (parent §17). Lowers a
;;; VERIFIED source machine to a canonical normalized IR in deterministic order
;;; — nodes numbered by declaration order, dispatch cases sorted ascending by
;;; byte, error references resolved to their codes — and computes the IR
;;; fingerprint (decision 0009): 64-bit FNV-1a over a canonical byte encoding of
;;; the normalized IR. Pure; runs only after verification (parent §16.3).
(library (byte-machine private normal-ir)
  (export normalize-machine
          normal-machine? normal-machine-entry normal-machine-states
          normal-machine-fingerprint
          normal-state-kind normal-state-id
          normal-dispatch-transitions normal-dispatch-fallback
          normal-error-code normal-dispatch-eof normal-pause-target)
  (import (rnrs)
          (only (byte-machine private ir)
                machine-nodes machine-entry machine-errors machine-default-eof-error
                byte-dispatch-node? byte-dispatch-node-cases byte-dispatch-node-fallback
                byte-dispatch-node-eof-target
                byte-case-matcher byte-case-edge matcher-bytes
                edge-target edge-mode stop-node? error-node? error-node-error-name
                finish-node? pause-node? pause-node-continuation
                error-declaration-name error-declaration-code node-name
                sequence-dispatch-node? sequence-dispatch-node-cases
                sequence-dispatch-node-mismatch sequence-dispatch-node-eof-target
                sequence-case-bytes sequence-case-target))

  (define nm-tag (vector 'byte-machine-normal-machine))
  (define (make-normal-machine entry states fp) (vector nm-tag entry states fp))
  (define (normal-machine? x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) nm-tag)))
  (define (normal-machine-entry m) (vector-ref m 1))
  (define (normal-machine-states m) (vector-ref m 2))
  (define (normal-machine-fingerprint m) (vector-ref m 3))

  (define ns-tag (vector 'byte-machine-normal-state))
  ;; (vector ns-tag kind id transitions fallback code eof) ; unused slots #f.
  ;; eof (slot 6) is a dispatch state's resolved eof routing:
  ;;   (node . <id>)             -- an exhausted dispatch continues to node <id>
  ;;   (default . <code-symbol>) -- it routes to the machine default-eof error.
  ;;   pause states carry (node . <continuation-id>) there (Slice ③).
  ;; Other non-dispatch states carry #f there.
  (define (normal-state-kind s) (vector-ref s 1))
  (define (normal-state-id s) (vector-ref s 2))
  (define (normal-dispatch-transitions s) (vector-ref s 3))
  (define (normal-dispatch-fallback s) (vector-ref s 4))
  (define (normal-error-code s) (vector-ref s 5))
  (define (normal-dispatch-eof s) (vector-ref s 6))
  (define (normal-pause-target s) (cdr (vector-ref s 6)))

  ;; --- FNV-1a 64-bit over a canonical byte encoding (decision 0009) ---
  (define mask64 (- (expt 2 64) 1))
  (define fnv-offset 14695981039346656037)
  (define fnv-prime  1099511628211)
  (define (fnv1a-64 bv)
    (let loop ((i 0) (h fnv-offset))
      (if (= i (bytevector-length bv)) h
          (loop (+ i 1)
                (bitwise-and mask64 (* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime))))))

  (define (put-u16be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  (define (put-u32be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 24)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 16)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  (define (put-symbol p sym)
    (let ((b (string->utf8 (symbol->string sym))))
      (put-u16be p (bytevector-length b)) (put-bytevector p b)))
  (define (mode->byte m) (if (eq? m 'advance) 0 1))

  ;; The `else` guards below are unreachable-today safety for a SEVENTH
  ;; node/state kind beyond the six now handled -- dispatch/stop/error/finish/
  ;; pause/sequence (sequence lowers to ordinary dispatch states, decision
  ;; 0015 point 1, so it adds no new case of its own); verified by inspection,
  ;; not mutation.

  ;; --- sequence prefix trie (decisions 0015, 0016) ---
  ;; A trie node is (children . terminal); children is an alist (byte . node)
  ;; kept ASCENDING by byte, which is what makes decision 0016 point 1's
  ;; pre-order total. Alternatives that agree on a byte descend into ONE shared
  ;; child, so no prefix state can offer the same byte twice -- the property
  ;; decision 0014 rests the ascending sort on, and which pass-overlap cannot
  ;; supply here because it walks source byte-cases and never sees these states.
  (define (empty-trie) (cons '() #f))
  (define (trie-children t) (car t))
  (define (trie-terminal t) (cdr t))
  (define (trie-interior? t) (pair? (trie-children t)))
  (define (trie-put cs b child)
    (cond ((null? cs) (list (cons b child)))
          ((= b (caar cs)) (cons (cons b child) (cdr cs)))
          ((< b (caar cs)) (cons (cons b child) cs))
          (else (cons (car cs) (trie-put (cdr cs) b child)))))
  ;; The two guards below are internal invariants, not user diagnostics. Decision
  ;; 0015 point 2: a prefix state has no "accept here" slot, so a trie node that
  ;; is both terminal and interior is UNREPRESENTABLE rather than merely
  ;; unwanted. Milestone 3 Slice ③'s pass-sequence-ambiguity (§16.2:894) now
  ;; rejects both shapes at verify-machine, so a verified machine cannot reach
  ;; them. They are KEPT as defense-in-depth because normalize-machine is a
  ;; public entry point that does not itself verify: a caller who skips
  ;; verification must fail loudly here rather than silently lose an
  ;; alternative. (byte-machine interpret)'s seq-step carries the same two.
  (define (trie-insert t bs target)
    (if (null? bs)
        (begin
          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "duplicate sequence alternative" target))
          (when (trie-interior? t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
          (cons (trie-children t) target))
        (begin
          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
          (let* ((b (car bs))
                 (hit (assv b (trie-children t)))
                 (child (trie-insert (if hit (cdr hit) (empty-trie)) (cdr bs) target)))
            (cons (trie-put (trie-children t) b child) (trie-terminal t))))))
  (define (build-trie cases)
    (let loop ((cs cases) (t (empty-trie)))
      (if (null? cs) t
          (loop (cdr cs) (trie-insert t (sequence-case-bytes (car cs))
                                      (sequence-case-target (car cs)))))))
  ;; Ids for every INTERIOR non-root node, depth-first pre-order with children
  ;; ascending by byte (decision 0016 point 1). The root is the declared node's
  ;; own state, and a TERMINAL child consumes no id -- its byte routes straight
  ;; to that alternative's declared target. Returns (alist next-id), keyed by
  ;; trie-node identity.
  (define (allocate-prefix-ids t next)
    (let walk ((cs (trie-children t)) (acc '()) (next next))
      (if (null? cs) (values (reverse acc) next)
          (let ((child (cdar cs)))
            (if (trie-interior? child)
                (let-values (((sub next2) (allocate-prefix-ids child (+ next 1))))
                  (walk (cdr cs) (append (reverse sub) (cons (cons child next) acc)) next2))
                (walk (cdr cs) acc next))))))

  ;; Lowering: verified machine -> (values entry states-vector). No encoding.
  (define (lower-machine machine)
    (let* ((nodes (machine-nodes machine))
           (name->id (let loop ((ns nodes) (i 0) (acc '()))
                       (if (null? ns) (reverse acc)
                           (loop (cdr ns) (+ i 1) (cons (cons (node-name (car ns)) i) acc)))))
           (id-of (lambda (nm) (cdr (assq nm name->id))))
           (errcode (lambda (nm)
                      (let loop ((es (machine-errors machine)))
                        (if (eq? (error-declaration-name (car es)) nm)
                            (error-declaration-code (car es)) (loop (cdr es))))))
           ;; A dispatch node's eof-target is a node NAME (resolved to its id) or
           ;; #f (route to the machine default-eof error, resolved to its code).
           (default-eof-code (errcode (machine-default-eof-error machine)))
           (eof-of (lambda (n)
                     (let ((t (byte-dispatch-node-eof-target n)))
                       (if (symbol? t)
                           (cons 'node (id-of t))
                           (cons 'default default-eof-code)))))
           (entry (id-of (machine-entry machine)))
           (declared-count (length nodes))
           ;; Decision 0016: declared nodes keep their declaration index; every
           ;; internal prefix state appends after the whole declared block, in
           ;; declaring-node order. Interleaving would renumber every later node
           ;; and move the fingerprint of every machine containing a sequence.
           (seq-eof-of (lambda (n)
                         (let ((t (sequence-dispatch-node-eof-target n)))
                           (if (symbol? t) (cons 'node (id-of t))
                               (cons 'default default-eof-code)))))
           (prefix-blocks
            (let loop ((ns nodes) (next declared-count) (acc '()))
              (if (null? ns) (reverse acc)
                  (let ((n (car ns)))
                    (if (sequence-dispatch-node? n)
                        (let ((t (build-trie (sequence-dispatch-node-cases n))))
                          (let-values (((ids next2) (allocate-prefix-ids t next)))
                            (loop (cdr ns) next2 (cons (list n t ids) acc))))
                        (loop (cdr ns) next acc))))))
           (block-of (lambda (n)
                       (let loop ((bs prefix-blocks))
                         (cond ((null? bs)
                                (assertion-violation 'normalize-machine
                                  "sequence node has no prefix block" n))
                               ((eq? (car (car bs)) n) (car bs))
                               (else (loop (cdr bs)))))))
           (trie-transitions
            (lambda (t ids)
              (map (lambda (kv)
                     (let ((b (car kv)) (child (cdr kv)))
                       (list b
                             (if (trie-interior? child)
                                 (cdr (assq child ids))
                                 (id-of (trie-terminal child)))
                             'advance)))
                   (trie-children t))))
           ;; Every prefix state carries the source node's mismatch edge as its
           ;; fallback and inherits its EOF edge (§12.4:727).
           (seq-state
            (lambda (n t ids id)
              (let ((mm (sequence-dispatch-node-mismatch n)))
                (vector ns-tag 'dispatch id (trie-transitions t ids)
                        (cons (id-of (edge-target mm)) (edge-mode mm)) #f
                        (seq-eof-of n)))))
           (declared
            (let loop ((ns nodes) (i 0) (acc '()))
              (if (null? ns) (reverse acc)
                  (let ((n (car ns)))
                    (loop (cdr ns) (+ i 1)
                          (cons
                           (cond
                             ((byte-dispatch-node? n)
                              (let ((trs (list-sort (lambda (a b) (< (car a) (car b)))
                                           ;; One transition per byte of each case's
                                           ;; canonical set (decision 0014): the encoding,
                                           ;; its tag bytes and its format version byte are
                                           ;; unchanged, and every machine expressible
                                           ;; before Milestone 3 encodes identically.
                                           (apply append
                                             (map (lambda (c)
                                                    (let ((e (byte-case-edge c))
                                                          (bs (matcher-bytes (byte-case-matcher c))))
                                                      (map (lambda (b)
                                                             (list b (id-of (edge-target e))
                                                                   (edge-mode e)))
                                                           bs)))
                                                  (byte-dispatch-node-cases n)))))
                                    (fb (byte-dispatch-node-fallback n)))
                                (vector ns-tag 'dispatch i trs
                                        (cons (id-of (edge-target fb)) (edge-mode fb)) #f
                                        (eof-of n))))
                             ((sequence-dispatch-node? n)
                              (let ((blk (block-of n)))
                                (seq-state n (cadr blk) (caddr blk) i)))
                             ((stop-node? n) (vector ns-tag 'stop i #f #f #f #f))
                             ((error-node? n) (vector ns-tag 'error i #f #f (errcode (error-node-error-name n)) #f))
                             ((finish-node? n) (vector ns-tag 'finish i #f #f #f #f))
                             ((pause-node? n)
                              (vector ns-tag 'pause i #f #f #f
                                      (cons 'node (id-of (pause-node-continuation n)))))
                             ;; The repertoire is now these six kinds. A future
                             ;; kind reaching here must fail loudly, not lower to
                             ;; nothing.
                             (else (assertion-violation 'normalize-machine "unknown node kind" n)))
                           acc))))))
           (internal
            (apply append
                   (map (lambda (blk)
                          (let ((n (car blk)) (ids (caddr blk)))
                            (map (lambda (kv) (seq-state n (car kv) ids (cdr kv))) ids)))
                        prefix-blocks)))
           (states (list->vector (append declared internal))))
      (values entry states)))

  ;; Encoding: (entry, states) -> canonical bytes (decision 0009 layout).
  (define (encode-normal entry states)
    (call-with-bytevector-output-port
     (lambda (p)
       (put-u8 p 1)
       (put-u32be p entry)
       (put-u32be p (vector-length states))
       (let loop ((i 0))
         (when (< i (vector-length states))
           (let ((s (vector-ref states i)))
             (case (normal-state-kind s)
               ((dispatch)
                (put-u8 p 0)
                (let ((trs (normal-dispatch-transitions s)))
                  (put-u16be p (length trs))
                  (for-each (lambda (tr)
                              (put-u8 p (car tr)) (put-u32be p (cadr tr))
                              (put-u8 p (mode->byte (caddr tr)))) trs))
                (let ((fb (normal-dispatch-fallback s)))
                  (put-u32be p (car fb)) (put-u8 p (mode->byte (cdr fb))))
                ;; eof routing: tag 0 + u32be node id, or tag 1 + default-eof code.
                (let ((eof (normal-dispatch-eof s)))
                  (if (eq? (car eof) 'node)
                      (begin (put-u8 p 0) (put-u32be p (cdr eof)))
                      (begin (put-u8 p 1) (put-symbol p (cdr eof))))))
               ((stop) (put-u8 p 1))
               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s)))
               ((finish) (put-u8 p 3))
               ;; pause: tag 4 + u32be continuation state id (D5).
               ((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))
               (else (assertion-violation 'normalize-machine "unknown state kind"
                                          (normal-state-kind s)))))
           (loop (+ i 1)))))))

  (define (normalize-machine machine)
    (let-values (((entry states) (lower-machine machine)))
      (make-normal-machine entry states (fnv1a-64 (encode-normal entry states))))))
