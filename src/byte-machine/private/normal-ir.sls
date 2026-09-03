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
          normal-error-code normal-error-reason normal-dispatch-eof normal-pause-target
          normal-machine-debug-map normal-machine-fields)
  (import (rnrs)
          (only (byte-machine private ir)
                machine-nodes machine-entry machine-errors machine-default-eof-error
                byte-dispatch-node? byte-dispatch-node-cases byte-dispatch-node-fallback
                byte-dispatch-node-eof-target
                byte-case-matcher byte-case-edge matcher-bytes
                edge-target edge-mode stop-node? error-node? error-node-error-name
                finish-node? pause-node? pause-node-continuation
                error-declaration-name error-declaration-code error-declaration-reason
                node-name
                sequence-dispatch-node? sequence-dispatch-node-cases
                sequence-dispatch-node-mismatch sequence-dispatch-node-eof-target
                sequence-case-bytes sequence-case-target
                machine-fields uint-field-name uint-field-width uint-field-initial))

  (define nm-tag (vector 'byte-machine-normal-machine))
  ;; The debug map is APPENDED after fp, never inserted before it:
  ;; normal-machine-fingerprint is slot 3 and the emitter reads it, so putting the
  ;; map ahead of fp would silently renumber that slot and render a debug map
  ;; where the IR fingerprint belongs in the emitted constructor call.
  (define (make-normal-machine entry states fp debug-map fields)
    (vector nm-tag entry states fp debug-map fields))
  (define (normal-machine? x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) nm-tag)))
  (define (normal-machine-entry m) (vector-ref m 1))
  (define (normal-machine-states m) (vector-ref m 2))
  (define (normal-machine-fingerprint m) (vector-ref m 3))
  ;; §17:963's state-ID-to-source-name map, total over internal prefix states.
  ;; It is what makes parser-error-node-name answerable in the generated lane,
  ;; where the emitter needs each state's public name as an emission-time
  ;; literal. It cannot perturb the fingerprint: the debug map is not among
  ;; encode-normal's arguments, so nothing it holds can reach the encoding.
  ;;
  ;; It used to say "encode-normal is called as (encode-normal entry states) and
  ;; never sees names", which stopped being true in Slice ①b: the call takes a
  ;; third argument now, and the field table it carries DOES contain names, which
  ;; are encoded on purpose -- a field name is observable to a generated parser
  ;; through parser-field-ref, so two machines differing only in one must differ
  ;; in fingerprint. Node names remain absent; that is the narrower claim, and it
  ;; is the one that was load-bearing here all along.
  (define (normal-machine-debug-map m) (vector-ref m 4))
  ;; §17:962's field slot assignment, appended for the same reason the debug map
  ;; is: normal-machine-fingerprint is slot 3 and the emitter reads it by index.
  ;; A list of (name width initial slot), slot ascending from 0 and equal to the
  ;; list position -- redundant by construction. NO consumer in this slice reads
  ;; the slot element: the encoder writes the records in order and omits it, the
  ;; emitter renders (name . initial) pairs, and parser-field-ref resolves a name
  ;; against the pair vector by position. It is carried because Slice ②'s field
  ;; operands reference a field BY SLOT and will read it, and because a table
  ;; that states its own slot can be asserted whole in a test -- which is what
  ;; witnesses the numbering, since no fingerprint can (the slot is not encoded).
  ;; An earlier version of this comment claimed "every consumer downstream indexes
  ;; BY SLOT"; none does yet.
  (define (normal-machine-fields m) (vector-ref m 5))

  (define ns-tag (vector 'byte-machine-normal-state))
  ;; (vector ns-tag kind id transitions fallback code eof reason) ; unused slots #f.
  ;; `reason` (slot 7, Milestone 4 Slice ①a) is the error declaration's static
  ;; reason STRING, added as its own slot rather than by widening slot 5 or the
  ;; eof pair: both of those are read by compile.sls through symbol->string, and
  ;; the eof pair is additionally asserted by whole value in normal-ir-tests.sps,
  ;; so widening either is three breakages for one slot. An error state carries
  ;; its own declaration's reason; a dispatch state carries the machine
  ;; default-eof declaration's when its eof routing is (default . code), and #f
  ;; when it routes to a node.
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
  (define (normal-error-reason s) (vector-ref s 7))
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
  ;; Field initials are encoded at a FIXED 64 bits regardless of the declared
  ;; width, so the record layout does not vary with the value it carries. A
  ;; width-sized initial would make two declarations of different widths share a
  ;; byte string whenever the narrower one's value fits, which is the collision
  ;; the width byte exists to prevent.
  (define (put-u64be p n)
    (let loop ((shift 56))
      (when (>= shift 0)
        (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n shift)))
        (loop (- shift 8)))))
  (define (put-u32be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 24)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 16)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  ;; A reason is a STRING, so put-symbol cannot carry it -- that helper calls
  ;; symbol->string, which raises on one. Same wire shape as put-symbol
  ;; (u16be byte-length then UTF-8 bytes), different input type. NOT named
  ;; put-string: (rnrs) exports that, and a second definition in this body is a
  ;; duplicate-definition error at expand time.
  (define (put-reason p str)
    (let ((bs (string->utf8 str)))
      (put-u16be p (bytevector-length bs))
      (put-bytevector p bs)))
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

  ;; Lowering: verified machine -> (values entry states-vector debug-map).
  ;; No encoding.
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
           ;; A sibling rather than a widening of errcode: a mutation FINDs
           ;; errcode's tail verbatim, and returning a pair from it would take
           ;; that FIND to zero sites and fail the suite at declaration.
           (errreason (lambda (nm)
                        (let walk ((es (machine-errors machine)))
                          (if (eq? (error-declaration-name (car es)) nm)
                              (error-declaration-reason (car es)) (walk (cdr es))))))
           ;; A dispatch node's eof-target is a node NAME (resolved to its id) or
           ;; #f (route to the machine default-eof error, resolved to its code).
           (default-eof-code (errcode (machine-default-eof-error machine)))
           (default-eof-reason (errreason (machine-default-eof-error machine)))
           ;; A dispatch state's reason slot mirrors its eof routing: the machine
           ;; default-eof declaration's reason when the routing is (default . code),
           ;; and #f when it continues to a node, which carries no error of its own.
           (eof-reason-of (lambda (eof) (if (eq? (car eof) 'node) #f default-eof-reason)))
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
                        (seq-eof-of n) (eof-reason-of (seq-eof-of n))))))
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
                                           ;; canonical set (decision 0014): the encoding
                                           ;; and its tag bytes are unchanged, and every
                                           ;; machine expressible before Milestone 3
                                           ;; encodes identically to it. The format
                                           ;; VERSION byte is no longer part of that
                                           ;; claim -- it is 2 from Milestone 4 Slice ①a
                                           ;; and every fingerprint moved with it
                                           ;; (decision 0019). What 0014 fixes is the
                                           ;; per-byte expansion, not the file format.
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
                                        (eof-of n) (eof-reason-of (eof-of n)))))
                             ((sequence-dispatch-node? n)
                              (let ((blk (block-of n)))
                                (seq-state n (cadr blk) (caddr blk) i)))
                             ((stop-node? n) (vector ns-tag 'stop i #f #f #f #f #f))
                             ((error-node? n)
                              (vector ns-tag 'error i #f #f
                                      (errcode (error-node-error-name n)) #f
                                      (errreason (error-node-error-name n))))
                             ((finish-node? n) (vector ns-tag 'finish i #f #f #f #f #f))
                             ((pause-node? n)
                              (vector ns-tag 'pause i #f #f #f
                                      (cons 'node (id-of (pause-node-continuation n))) #f))
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
           (states (list->vector (append declared internal)))
           ;; §17:963's debug map, built in its OWN walk rather than inside the
           ;; `internal` map above: that line is pinned verbatim by a mutation,
           ;; and folding the map into it would take the FIND to zero sites.
           ;; Total over internal prefix states -- name->id covers declared nodes
           ;; only, and every prefix state answers with its DECLARING node's
           ;; public name, which is what a default-EOF error reports.
           (debug-map
            (append (map (lambda (kv) (cons (cdr kv) (car kv))) name->id)
                    (apply append
                           (map (lambda (blk)
                                  (let ((n (car blk)) (ids (caddr blk)))
                                    (map (lambda (kv) (cons (cdr kv) (node-name n))) ids)))
                                prefix-blocks)))))
      (values entry states debug-map)))

  ;; Encoding: (entry, states) -> canonical bytes (decision 0009 layout).
  (define (encode-normal entry states fields)
    (call-with-bytevector-output-port
     (lambda (p)
       ;; Format version 2 (decision 0019). Header layout:
       ;;   [version u8][entry u32be][state-count u32be][field-count u16be]
       ;;   [field records...][state records...]
       ;; Each field record is
       ;;   [name-length u16be][name UTF-8][width u8][initial u64be]
       ;; in SLOT ORDER. The slot itself is not written: it is the record's
       ;; position, and writing it too would let the stream express a table whose
       ;; slots disagree with their order.
       ;;
       ;; ①a wrote this count as a literal zero with no records, and Slice ①b
       ;; fills it. Its POSITION was fixed there rather than here: the byte
       ;; stream has no self-description and nothing in the tree decodes it, so a
       ;; disagreement about where the table sits would have been a second
       ;; unbudgeted re-baseline. Decision 0019 item 5 is the other half of that
       ;; bargain and holds -- a zero-field machine encodes byte-identically to
       ;; ①a's, which normal-ir-tests.sps asserts at ①a's own measured value
       ;; rather than leaving it to the goldens to notice.
       (put-u8 p 2)
       (put-u32be p entry)
       (put-u32be p (vector-length states))
       (put-u16be p (length fields))
       (for-each (lambda (f)
                   (put-symbol p (car f))
                   (put-u8 p (cadr f))
                   (put-u64be p (caddr f)))
                 fields)
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
                      (begin (put-u8 p 1) (put-symbol p (cdr eof))
                             (put-reason p (normal-error-reason s))))))
               ((stop) (put-u8 p 1))
               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s))
                        (put-reason p (normal-error-reason s)))
               ((finish) (put-u8 p 3))
               ;; pause: tag 4 + u32be continuation state id (D5).
               ((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))
               (else (assertion-violation 'normalize-machine "unknown state kind"
                                          (normal-state-kind s)))))
           (loop (+ i 1)))))))

  ;; Slot = declaration index (design §6 task 5). `machine-fields` is the
  ;; declaration list in declaration order, so the slot is the position and this
  ;; is a numbering, not a choice.
  (define (field-table machine)
    (let loop ((fs (machine-fields machine)) (slot 0) (out '()))
      (if (null? fs) (reverse out)
          (loop (cdr fs) (+ slot 1)
                (cons (list (uint-field-name (car fs))
                            (uint-field-width (car fs))
                            (uint-field-initial (car fs))
                            slot)
                      out)))))

  (define (normalize-machine machine)
    (let-values (((entry states debug-map) (lower-machine machine)))
      (let ((fields (field-table machine)))
        (make-normal-machine entry states
                             (fnv1a-64 (encode-normal entry states fields))
                             debug-map fields)))))
