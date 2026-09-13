;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine private normal-ir): the normalizer. Lowers a
;;; VERIFIED source machine to a canonical normalized IR in deterministic order
;;; — nodes numbered by declaration order, dispatch cases sorted ascending by
;;; byte, error references resolved to their codes — and computes the IR
;;; fingerprint: 64-bit FNV-1a over a canonical byte encoding of
;;; the normalized IR. Pure; runs only after verification.
(library (byte-machine private normal-ir)
  (export normalize-machine
          normal-machine? normal-machine-entry normal-machine-states
          normal-machine-fingerprint
          normal-state-kind normal-state-id
          normal-dispatch-transitions normal-dispatch-fallback
          normal-error-code normal-error-reason normal-dispatch-eof normal-pause-target
          normal-machine-debug-map normal-machine-fields
          normal-machine-callbacks normal-machine-spans
          normal-machine-callback-decls normal-machine-span-decls
          normal-field-selector normal-field-arguments normal-field-targets)
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
                machine-fields uint-field-name uint-field-width uint-field-initial
                machine-callbacks machine-spans
                callback-declaration-name span-declaration-name
                callback-declaration-kind callback-declaration-required?
                callback-declaration-default-branch
                span-declaration-data-callback span-declaration-complete-callback
                integer-accumulate-node? integer-accumulate-node-name
                integer-accumulate-node-field integer-accumulate-node-base
                integer-accumulate-node-digit-target integer-accumulate-node-nondigit-edge
                integer-accumulate-node-overflow-error integer-accumulate-node-eof-target
                field-action-node? field-action-node-name field-action-node-operation
                field-action-node-arguments field-action-node-next field-action-node-error
                field-branch-node? field-branch-node-name field-branch-node-predicate
                field-branch-node-arguments field-branch-node-true-target
                field-branch-node-false-target
                callback-node? callback-node-name callback-node-callback
                callback-node-continue-target callback-node-branch-targets
                callback-node-pause-continuation
                span-start-node? span-start-node-span span-start-node-next
                span-end-node? span-end-node-span span-end-node-next
                counted-consume-node? counted-consume-node-field counted-consume-node-next
                counted-consume-node-eof-target))

  (define nm-tag (vector 'byte-machine-normal-machine))
  ;; The debug map is APPENDED after fp, never inserted before it:
  ;; normal-machine-fingerprint is slot 3 and the emitter reads it, so putting the
  ;; map ahead of fp would silently renumber that slot and render a debug map
  ;; where the IR fingerprint belongs in the emitted constructor call.
  (define (make-normal-machine entry states fp debug-map fields callbacks spans
                               callback-decls span-decls)
    (vector nm-tag entry states fp debug-map fields callbacks spans callback-decls
            span-decls))
  ;; normal-machine? : Any -> Boolean
  (define (normal-machine? x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) nm-tag)))
  ;; normal-machine-entry : NormalMachine -> StateId
  (define (normal-machine-entry m) (vector-ref m 1))
  ;; normal-machine-states : NormalMachine -> (Vectorof NormalState)
  (define (normal-machine-states m) (vector-ref m 2))
  ;; normal-machine-fingerprint : NormalMachine -> ExactInteger
  (define (normal-machine-fingerprint m) (vector-ref m 3))
  ;; The state-ID-to-source-name map, total over internal prefix states.
  ;; It is what makes parser-error-node-name answerable in the generated lane,
  ;; where the emitter needs each state's public name as an emission-time
  ;; literal. It cannot perturb the fingerprint: the debug map is not among
  ;; encode-normal's arguments, so nothing it holds can reach the encoding.
  ;; Node names stay absent from the encoding; field names, by contrast, ARE
  ;; encoded on purpose -- a field name is observable to a generated parser
  ;; through parser-field-ref, so two machines differing only in one must differ
  ;; in fingerprint. That node names are absent is the narrower, load-bearing
  ;; claim here.
  ;; normal-machine-debug-map : NormalMachine -> (Listof (Pair StateId Symbol))
  (define (normal-machine-debug-map m) (vector-ref m 4))
  ;; The field slot assignment, appended for the same reason the debug map is:
  ;; normal-machine-fingerprint is slot 3 and the emitter reads it by index, so
  ;; nothing may be inserted ahead of it. A list of (name width initial slot),
  ;; slot ascending from 0 and equal to the list position -- redundant by
  ;; construction. The slot is carried, not encoded, so that field operands can
  ;; reference a field BY SLOT and so a table stating its own slot can be
  ;; asserted whole in a test -- which is what witnesses the numbering, since no
  ;; fingerprint can.
  ;; normal-machine-fields : NormalMachine -> FieldSlotTable
  (define (normal-machine-fields m) (vector-ref m 5))
  ;; The callback and span slot assignment, appended after fields for the same
  ;; reason fields were appended after the debug map: normal-machine-fingerprint
  ;; is slot 3 and the emitter reads it by index, so nothing may be inserted
  ;; ahead of it. Each is a list of (name slot) with slot ascending from 0 and
  ;; equal to the list position -- redundant by construction, and carried for the
  ;; same reason the field table carries it.
  ;; normal-machine-callbacks : NormalMachine -> NameSlotTable
  (define (normal-machine-callbacks m) (vector-ref m 6))
  ;; The four parts the generated lane's binding resolution needs, in slot order.
  ;; Separate from the slot table above: that one is what the ENCODING walks and
  ;; carries names only, this one is what the EMITTER renders into ABI member 1.
  ;; normal-machine-callback-decls : NormalMachine -> (Listof (List Symbol CallbackKind Boolean (Option Symbol)))
  (define (normal-machine-callback-decls m) (vector-ref m 8))
  ;; The span half of exactly the split above: the table at slot 7 carries NAMES,
  ;; which is what the fingerprint's span section walks, and this one carries
  ;; what the EMITTER needs -- the span's name plus its two callbacks RESOLVED TO
  ;; CALLBACK SLOTS, in span-slot order.
  ;;
  ;; The resolution belongs here and not in the emitter. A lowered span state
  ;; carries the SPAN slot, but the arm it renders indexes `cbv`, so something
  ;; has to cross from one numbering to the other; doing it in compile.sls would
  ;; put a second, independently-written copy of the declaration walk in the lane
  ;; that is supposed to be checked against this one. Entries are (name data-slot
  ;; complete-slot), complete-slot #f when the optional completion callback is
  ;; absent.
  ;; normal-machine-span-decls : NormalMachine -> (Listof (List Symbol (Option ExactInteger) (Option ExactInteger)))
  (define (normal-machine-span-decls m) (vector-ref m 9))
  ;; normal-machine-spans : NormalMachine -> NameSlotTable
  (define (normal-machine-spans m) (vector-ref m 7))

  (define ns-tag (vector 'byte-machine-normal-state))
  ;; (vector ns-tag kind id transitions fallback code eof reason
  ;;         selector arguments targets)                        ; unused slots #f.
  ;;
  ;; `selector` (slot 8) is the operation or predicate symbol; `arguments`
  ;; (slot 9) the operand list as written; `targets` (slot 10) the kind's own
  ;; successor list -- (next . error-or-#f) for a field action, (true . false)
  ;; for a field branch. Accumulate reuses slot 6's (node . id) /
  ;; (default . code) convention for its EOF routing rather than adding another.
  ;; `reason` (slot 7) is the error declaration's static reason STRING, added as
  ;; its own slot rather than by widening slot 5 or the eof pair: both of those
  ;; are read by compile.sls through symbol->string, so a reason STRING could not
  ;; ride either. An error state carries its own declaration's reason; a dispatch
  ;; state carries the machine default-eof declaration's when its eof routing is
  ;; (default . code), and #f when it routes to a node.
  ;; eof (slot 6) is a dispatch state's resolved eof routing:
  ;;   (node . <id>)             -- an exhausted dispatch continues to node <id>
  ;;   (default . <code-symbol>) -- it routes to the machine default-eof error.
  ;;   pause states carry (node . <continuation-id>) there.
  ;; Other non-dispatch states carry #f there.
  ;; normal-state-kind : NormalState -> NormalStateKind
  (define (normal-state-kind s) (vector-ref s 1))
  ;; normal-state-id : NormalState -> StateId
  (define (normal-state-id s) (vector-ref s 2))
  ;; normal-dispatch-transitions : NormalState -> (Listof (List Byte StateId EdgeMode))
  (define (normal-dispatch-transitions s) (vector-ref s 3))
  ;; normal-dispatch-fallback : NormalState -> (Pair StateId EdgeMode)
  (define (normal-dispatch-fallback s) (vector-ref s 4))
  ;; normal-error-code : NormalState -> Symbol
  (define (normal-error-code s) (vector-ref s 5))
  ;; normal-error-reason : NormalState -> (Option String)
  (define (normal-error-reason s) (vector-ref s 7))
  ;; normal-dispatch-eof : NormalState -> (U (Pair 'node StateId) (Pair 'default Symbol))
  (define (normal-dispatch-eof s) (vector-ref s 6))
  ;; normal-pause-target : NormalState -> StateId
  (define (normal-pause-target s) (cdr (vector-ref s 6)))
  ;; normal-field-selector : NormalState -> Any
  (define (normal-field-selector s) (vector-ref s 8))
  ;; normal-field-arguments : NormalState -> Any
  (define (normal-field-arguments s) (vector-ref s 9))
  ;; normal-field-targets : NormalState -> Any
  (define (normal-field-targets s) (vector-ref s 10))

  ;; --- FNV-1a 64-bit over a canonical byte encoding ---
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
  ;; A field node's operand list: a u16be count, then each operand -- a symbol
  ;; (the field name, always first) or an exact integer, distinguished by a tag
  ;; byte so a field literally named `7` could never share bytes with the
  ;; constant 7. Integers ride 64 bits for the same reason field initials do:
  ;; the record layout must not vary with the value it carries.
  (define (put-operands p args)
    (put-u16be p (length args))
    (for-each (lambda (a)
                (cond ((symbol? a) (put-u8 p 0) (put-symbol p a))
                      (else (put-u8 p 1) (put-u64be p a))))
              args))

  ;; The `else` guards below are unreachable-today safety for the kind AFTER the
  ;; ones this file handles. Thirteen node kinds lower here -- the closed set,
  ;; complete with counted consume -- and THIRTEEN normalized state kinds come
  ;; out: the same thirteen less `sequence`, which lowers to ordinary dispatch
  ;; states (so it adds no case of its own), plus `span-completion`, which has no
  ;; source node at all. So the guards protect against a FOURTEENTH node kind,
  ;; not a seventh.

  ;; --- sequence prefix trie ---
  ;; A trie node is (children . terminal); children is an alist (byte . node)
  ;; kept ASCENDING by byte, which is what makes the pre-order walk total.
  ;; Alternatives that agree on a byte descend into ONE shared child, so no
  ;; prefix state can offer the same byte twice -- the property the ascending
  ;; sort rests on.
  (define (empty-trie) (cons '() #f))
  (define (trie-children t) (car t))
  (define (trie-terminal t) (cdr t))
  (define (trie-interior? t) (pair? (trie-children t)))
  (define (trie-put cs b child)
    (cond ((null? cs) (list (cons b child)))
          ((= b (caar cs)) (cons (cons b child) (cdr cs)))
          ((< b (caar cs)) (cons (cons b child) cs))
          (else (cons (car cs) (trie-put (cdr cs) b child)))))
  ;; The two guards below are internal invariants, not user diagnostics. A prefix
  ;; state has no "accept here" slot, so a trie node that is both terminal and
  ;; interior is UNREPRESENTABLE rather than merely unwanted. pass-sequence-
  ;; ambiguity now rejects both shapes at verify-machine, so a verified machine
  ;; cannot reach them. They are KEPT as defense-in-depth because
  ;; normalize-machine is a public entry point that does not itself verify: a
  ;; caller who skips verification must fail loudly here rather than silently
  ;; lose an alternative. (byte-machine interpret)'s seq-step carries the same
  ;; two.
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
  ;; ascending by byte. The root is the declared node's own state, and a TERMINAL
  ;; child consumes no id -- its byte routes straight to that alternative's
  ;; declared target. Returns (alist next-id), keyed by trie-node identity.
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
           ;; A callback node names its callback by NAME, and the generated lane
           ;; holds an indexed slot vector. The slot IS the declaration position
           ;; -- `name-table` below builds the same numbering for
           ;; `normal-machine-callbacks`, and declaration order carries no
           ;; semantic priority precisely so it can give stable ids. Resolved
           ;; HERE rather than at emission: the fingerprint must cover what the
           ;; ABI carries, and what the ABI carries is the slot.
           (callback-slot-of
            (lambda (nm)
              (let loop ((cs (machine-callbacks machine)) (i 0))
                (cond ((null? cs)
                       (assertion-violation 'normalize-machine
                                            "callback node names no declaration" nm))
                      ((eq? (callback-declaration-name (car cs)) nm) i)
                      (else (loop (cdr cs) (+ i 1)))))))
           (callback-decl-of
            (lambda (nm)
              (let loop ((cs (machine-callbacks machine)))
                (cond ((null? cs)
                       (assertion-violation 'normalize-machine
                                            "callback node names no declaration" nm))
                      ((eq? (callback-declaration-name (car cs)) nm) (car cs))
                      (else (loop (cdr cs)))))))
           ;; An optional decision callback must declare `default-branch`; other
           ;; optional callbacks default to `continue`. Resolved to a TARGET ID
           ;; here, so the invocation site -- the short circuit over the
           ;; unbound-callback sentinel -- is one jump and carries no rule of its
           ;; own.
           ;;
           ;; #f for a REQUIRED callback: its slot can never hold the sentinel,
           ;; so there is no default to take, and #f says exactly that where a
           ;; plausible target would say something false.
           (callback-default-of
            (lambda (n)
              (let ((d (callback-decl-of (callback-node-callback n))))
                (cond ((callback-declaration-required? d) #f)
                      ((eq? (callback-declaration-kind d) 'decision)
                       (let ((hit (assq (callback-declaration-default-branch d)
                                        (callback-node-branch-targets n))))
                         ;; Unreachable once verify's node-half check runs: it
                         ;; requires an optional decision callback's node to
                         ;; declare a target for the default branch. Loud rather
                         ;; than #f, which here means "required".
                         (unless hit
                           (assertion-violation 'normalize-machine
                                                "no target for the default branch"
                                                (callback-node-name n)))
                         (id-of (cadr hit))))
                      (else (id-of (callback-node-continue-target n)))))))
           (entry (id-of (machine-entry machine)))
           (declared-count (length nodes))
           ;; Declared nodes keep their declaration index; every internal prefix
           ;; state appends after the whole declared block, in declaring-node
           ;; order. Interleaving would renumber every later node and move the
           ;; fingerprint of every machine containing a sequence.
           ;; An accumulate node's own EOF edge, a separate lambda rather than a
           ;; widened `eof-of`: `eof-of` reads `byte-dispatch-node-eof-target`, a
           ;; bare slot read with no tag guard, so handing it another kind would
           ;; return a plausible-looking value from the wrong slot.
           (acc-eof-of (lambda (n)
                         (let ((t (integer-accumulate-node-eof-target n)))
                           (if (symbol? t)
                               (cons 'node (id-of t))
                               (cons 'default default-eof-code)))))
           (seq-eof-of (lambda (n)
                         (let ((t (sequence-dispatch-node-eof-target n)))
                           (if (symbol? t) (cons 'node (id-of t))
                               (cons 'default default-eof-code)))))
           ;; The FOURTH such resolver, for the same reason acc-eof-of is
           ;; separate: each reads its own kind's accessor, and a shared one
           ;; would be a bare slot read from the wrong kind's vector.
           (count-eof-of (lambda (n)
                           (let ((t (counted-consume-node-eof-target n)))
                             (if (symbol? t) (cons 'node (id-of t))
                                 (cons 'default default-eof-code)))))
           ;; The walk that orders internal states. A declaring node contributes
           ;; ALL of its internal states at its own position in declaring-node
           ;; order. There are two families of internal state -- a sequence
           ;; node's prefix states and a span END's continuation -- and this loop
           ;; is where they interleave: it walks the declared nodes ONCE and
           ;; allocates whatever the node in hand needs, so a span-end's
           ;; continuation sits ahead of a LATER sequence node's prefix states
           ;; rather than in a family block of its own.
           ;;
           ;; Phase one is untouched -- every declared node keeps its
           ;; declaration index -- and this is phase two, which begins at
           ;; `declared-count`. Internal states never interleave with declared
           ;; ones.
           ;;
           ;; A block is `(node kind payload ids)`: for a sequence node the
           ;; payload is its trie and `ids` the prefix-state alist; for a span
           ;; end the payload is #f and `ids` is the one continuation id called
           ;; `completion-pending`.
           (internal-blocks
            (let loop ((ns nodes) (next declared-count) (acc '()))
              (if (null? ns) (reverse acc)
                  (let ((n (car ns)))
                    (cond
                      ((sequence-dispatch-node? n)
                       (let ((t (build-trie (sequence-dispatch-node-cases n))))
                         (let-values (((ids next2) (allocate-prefix-ids t next)))
                           (loop (cdr ns) next2 (cons (list n 'prefix t ids) acc)))))
                      ;; ONE internal state per resumable substep, not a fused
                      ;; state: resumption is "at the next undelivered substep",
                      ;; which a fused state cannot express. A span end delivers
                      ;; two -- the remaining fragment, then the completion
                      ;; callback -- so the DECLARED node is the first substep
                      ;; and this is the second.
                      ((span-end-node? n)
                       (loop (cdr ns) (+ next 1) (cons (list n 'span-end #f next) acc)))
                      (else (loop (cdr ns) next acc)))))))
           (prefix-blocks (filter (lambda (b) (eq? (cadr b) 'prefix)) internal-blocks))
           (span-end-blocks (filter (lambda (b) (eq? (cadr b) 'span-end)) internal-blocks))
           (completion-id-of
            (lambda (n)
              (let loop ((bs span-end-blocks))
                (cond ((null? bs)
                       (assertion-violation 'normalize-machine
                                            "span end has no continuation state" n))
                      ((eq? (car (car bs)) n) (cadddr (car bs)))
                      (else (loop (cdr bs)))))))
           (block-of (lambda (n)
                       (let loop ((bs prefix-blocks))
                         (cond ((null? bs)
                                (assertion-violation 'normalize-machine
                                  "sequence node has no prefix block" n))
                               ((eq? (car (car bs)) n) (car bs))
                               (else (loop (cdr bs)))))))
           ;; The declared span table's position, exactly as `callback-slot-of`
           ;; resolves a callback's: the slot IS the declaration index, and
           ;; declaration order carries no semantic priority precisely so it can
           ;; give stable ids.
           (span-slot-of
            (lambda (nm)
              (let loop ((sp (machine-spans machine)) (i 0))
                (cond ((null? sp)
                       (assertion-violation 'normalize-machine
                                            "span node names no declaration" nm))
                      ((eq? (span-declaration-name (car sp)) nm) i)
                      (else (loop (cdr sp) (+ i 1)))))))
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
           ;; fallback and inherits its EOF edge.
           (seq-state
            (lambda (n t ids id)
              (let ((mm (sequence-dispatch-node-mismatch n)))
                ;; The three payload slots (8-10) are #f here, like every other
                ;; kind that does not use them: sequence states carry kind
                ;; `dispatch`, whose readers never touch those slots.
                (vector ns-tag 'dispatch id (trie-transitions t ids)
                        (cons (id-of (edge-target mm)) (edge-mode mm)) #f
                        (seq-eof-of n) (eof-reason-of (seq-eof-of n))
                        #f #f #f))))
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
                                           ;; canonical set.
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
                                        (eof-of n) (eof-reason-of (eof-of n))
                                        #f #f #f)))
                             ((sequence-dispatch-node? n)
                              (let ((blk (block-of n)))
                                (seq-state n (caddr blk) (cadddr blk) i)))
                             ((stop-node? n) (vector ns-tag 'stop i #f #f #f #f #f #f #f #f))
                             ((error-node? n)
                              (vector ns-tag 'error i #f #f
                                      (errcode (error-node-error-name n)) #f
                                      (errreason (error-node-error-name n)) #f #f #f))
                             ((finish-node? n) (vector ns-tag 'finish i #f #f #f #f #f #f #f #f))
                             ((pause-node? n)
                              (vector ns-tag 'pause i #f #f #f
                                      (cons 'node (id-of (pause-node-continuation n))) #f
                                      #f #f #f))
                             ;; The two ZERO-WIDTH kinds. The lowering is 1:1 --
                             ;; neither allocates an internal state -- so each is
                             ;; one source node becoming one normalized state, and
                             ;; `prefix-blocks` correctly skips them.
                             ((field-action-node? n)
                              (vector ns-tag 'field-action i #f #f #f #f #f
                                      (field-action-node-operation n)
                                      (field-action-node-arguments n)
                                      (cons (id-of (field-action-node-next n))
                                            (let ((e (field-action-node-error n)))
                                              (and (symbol? e) (id-of e))))))
                             ((field-branch-node? n)
                              (vector ns-tag 'field-branch i #f #f #f #f #f
                                      (field-branch-node-predicate n)
                                      (field-branch-node-arguments n)
                                      (cons (id-of (field-branch-node-true-target n))
                                            (id-of (field-branch-node-false-target n)))))
                             ;; Integer accumulate, an INPUT-READING kind. 1:1
                             ;; like the two zero-width kinds above, so it
                             ;; allocates no internal state and prefix-blocks
                             ;; correctly skips it.
                             ;;
                             ;; It needs FIVE payload values -- field, base, and
                             ;; three byte targets -- plus its EOF routing, which
                             ;; rides slot 6 in the (node . id) /
                             ;; (default . code) convention, and the `reason`
                             ;; slot 7 that convention requires when the routing
                             ;; is (default . code). `selector` carries the base,
                             ;; `arguments` the field name, `targets` the three.
                             ((integer-accumulate-node? n)
                              (let ((nd (integer-accumulate-node-nondigit-edge n))
                                    (eof (acc-eof-of n)))
                                (vector ns-tag 'accumulate i #f #f #f
                                        eof (eof-reason-of eof)
                                        (integer-accumulate-node-base n)
                                        (list (integer-accumulate-node-field n))
                                        (list (id-of (integer-accumulate-node-digit-target n))
                                              (cons (id-of (edge-target nd)) (edge-mode nd))
                                              (id-of (integer-accumulate-node-overflow-error n))))))
                             ;; Counted consume, the fourth INPUT-READING kind
                             ;; with an EOF route of its own (after both dispatch
                             ;; kinds and accumulate), and 1:1 like accumulate:
                             ;; `arguments` the field NAME (the emitter resolves
                             ;; name to slot), `targets` the one successor id,
                             ;; slot 6 the EOF routing in the usual convention
                             ;; through its own resolver, slot 7 the reason when
                             ;; that routing is the default. No selector.
                             ((counted-consume-node? n)
                              (let ((eof (count-eof-of n)))
                                (vector ns-tag 'counted-consume i #f #f #f
                                        eof (eof-reason-of eof)
                                        #f
                                        (list (counted-consume-node-field n))
                                        (list (id-of (counted-consume-node-next n))))))
                             ;; Callback invocation, the first kind that reaches
                             ;; OUT of the machine. 1:1 like the three zero-width
                             ;; kinds above, so it allocates no internal state and
                             ;; prefix-blocks correctly skips it.
                             ;;
                             ;; Its five payload values ride the three payload
                             ;; slots rather than widening the vector: `selector`
                             ;; carries the resolved callback SLOT, `arguments`
                             ;; the branch map as (key . target-id) pairs, and
                             ;; `targets` the list (continue-id pause-id
                             ;; default-id).
                             ;;
                             ;; The branch map's own order is the source list's,
                             ;; fixed as proper lists in deterministic caller
                             ;; order -- so two machines whose branches differ
                             ;; only in order are two machines, and the encoder
                             ;; below writes the order.
                             ((callback-node? n)
                              (vector ns-tag 'callback i #f #f #f #f #f
                                      (callback-slot-of (callback-node-callback n))
                                      (map (lambda (b)
                                             (cons (car b) (id-of (cadr b))))
                                           (callback-node-branch-targets n))
                                      (list (id-of (callback-node-continue-target n))
                                            (id-of (callback-node-pause-continuation n))
                                            (callback-default-of n))))
                             ;; The two span kinds. `selector` carries the
                             ;; resolved span SLOT and `targets` the single
                             ;; successor -- the same three payload slots the
                             ;; other zero-width kinds ride, so the vector is not
                             ;; widened again.
                             ;;
                             ;; A span END also carries its continuation id,
                             ;; because the declared node is only the FIRST of its
                             ;; two substeps. It rides `arguments`, which no span
                             ;; kind otherwise uses.
                             ((span-start-node? n)
                              (vector ns-tag 'span-start i #f #f #f #f #f
                                      (span-slot-of (span-start-node-span n))
                                      #f
                                      (id-of (span-start-node-next n))))
                             ((span-end-node? n)
                              (vector ns-tag 'span-end i #f #f #f #f #f
                                      (span-slot-of (span-end-node-span n))
                                      (completion-id-of n)
                                      (id-of (span-end-node-next n))))
                             ;; The repertoire is now these THIRTEEN kinds. A future
                             ;; kind reaching here must fail loudly, not lower to
                             ;; nothing.
                             (else (assertion-violation 'normalize-machine "unknown node kind" n)))
                           acc))))))
           ;; Phase two's states, in `internal-blocks` order -- which IS
           ;; declaring-node order across both families.
           (internal
            (apply append
                   (map (lambda (blk)
                          (let ((n (car blk)) (ids (cadddr blk)))
                            (if (eq? (cadr blk) 'prefix)
                                (map (lambda (kv) (seq-state n (car kv) ids (cdr kv))) ids)
                                ;; The `completion-pending` state: the span is
                                ;; already inactive when this runs, so it carries
                                ;; only the completion callback's slot and the
                                ;; node's successor.
                                (list (vector ns-tag 'span-completion ids #f #f #f #f #f
                                              (span-slot-of (span-end-node-span n))
                                              #f
                                              (id-of (span-end-node-next n)))))))
                        internal-blocks)))
           (states (list->vector (append declared internal)))
           ;; The debug map, built in its OWN walk rather than inside the
           ;; `internal` map above. Total over internal prefix states -- name->id
           ;; covers declared nodes only, and every prefix state answers with its
           ;; DECLARING node's public name, which is what a default-EOF error
           ;; reports.
           (debug-map
            (append (map (lambda (kv) (cons (cdr kv) (car kv))) name->id)
                    (apply append
                           (map (lambda (blk)
                                  (let ((n (car blk)) (ids (cadddr blk)))
                                    (if (eq? (cadr blk) 'prefix)
                                        (map (lambda (kv) (cons (cdr kv) (node-name n))) ids)
                                        ;; The public parser state must name the
                                        ;; source callback/span node, not a
                                        ;; generated internal continuation, so a
                                        ;; span end's continuation answers with
                                        ;; the span-end node's own name. An
                                        ;; incomplete map is an INDEX ERROR in the
                                        ;; generated lane rather than a missing
                                        ;; debug string -- the map crosses the
                                        ;; seam, as ABI payload member 2.
                                        (list (cons ids (node-name n))))))
                                internal-blocks)))))
      (values entry states debug-map)))

  ;; Encoding: (entry, states) -> canonical bytes.
  ;; Shared EOF routing, written identically by the dispatch, accumulate, and
  ;; counted-consume arms. Factored into one helper so the arms cannot drift;
  ;; each caller's CALL stays its own line.
  (define (put-eof-routing p eof reason)
    (if (eq? (car eof) 'node)
        (begin (put-u8 p 0) (put-u32be p (cdr eof)))
        (begin (put-u8 p 1) (put-symbol p (cdr eof))
               (put-reason p reason))))

  (define (encode-normal entry states fields callbacks spans)
    (call-with-bytevector-output-port
     (lambda (p)
       ;; Format version 2. Header layout:
       ;;   [version u8][entry u32be][state-count u32be][field-count u16be]
       ;;   [field records...][state records...]
       ;; Each field record is
       ;;   [name-length u16be][name UTF-8][width u8][initial u64be]
       ;; in SLOT ORDER. The slot itself is not written: it is the record's
       ;; position, and writing it too would let the stream express a table whose
       ;; slots disagree with their order.
       ;;
       ;; The callback and span tables are OPTIONAL TRAILING SECTIONS at the foot
       ;; of this procedure, present only when nonempty, with the header
       ;; unchanged. A trailing section that writes ZERO bytes for a machine
       ;; declaring neither leaves the stream, and therefore the fingerprint,
       ;; byte-identical to a machine that has no such declarations -- so it costs
       ;; nothing on machines that do not use it. The full shape is:
       ;;   [... state records...][callback table?][span table?]
       ;; each table wholly inside its own emptiness guard, the count included,
       ;; because an unconditional count would be two bytes on every machine in
       ;; the tree.
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
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((stop) (put-u8 p 1))
               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s))
                        (put-reason p (normal-error-reason s)))
               ((finish) (put-u8 p 3))
               ;; pause: tag 4 + u32be continuation state id.
               ((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))
               ;; field action: tag 5 + selector + operands + next + error tag.
               ;; field branch: tag 6 + selector + operands + both targets.
               ;; The operand list is encoded because every part of it is
               ;; observable to a generated parser -- a different constant is a
               ;; different machine -- and the ERROR target is written with a
               ;; presence tag rather than a sentinel id, so "no error target"
               ;; and "the error target is state 0" cannot collide.
               ((field-action)
                (put-u8 p 5)
                (put-symbol p (normal-field-selector s))
                (put-operands p (normal-field-arguments s))
                (put-u32be p (car (normal-field-targets s)))
                (let ((e (cdr (normal-field-targets s))))
                  (if e (begin (put-u8 p 1) (put-u32be p e)) (put-u8 p 0))))
               ;; accumulate: tag 7 + base + field name + digit target +
               ;; nondigit (target, mode) + overflow target + eof routing. Every
               ;; part is observable to a generated parser -- a different base is
               ;; a different machine -- so every part is encoded.
               ((accumulate)
                (put-u8 p 7)
                (put-u8 p (normal-field-selector s))
                (put-symbol p (car (normal-field-arguments s)))
                (let ((tg (normal-field-targets s)))
                  (put-u32be p (car tg))
                  (put-u32be p (car (cadr tg)))
                  (put-u8 p (mode->byte (cdr (cadr tg))))
                  (put-u32be p (caddr tg)))
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ;; counted consume: tag, field name, successor id, eof routing --
               ;; every part, because each is observable to a generated parser.
               ;; The tag is the next free literal above the earlier kinds.
               ((counted-consume)
                (put-u8 p 14)
                (put-symbol p (car (normal-field-arguments s)))
                (put-u32be p (car (normal-field-targets s)))
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)
                (put-u8 p 6)
                (put-symbol p (normal-field-selector s))
                (put-operands p (normal-field-arguments s))
                (put-u32be p (car (normal-field-targets s)))
                (put-u32be p (cdr (normal-field-targets s))))
               ;; callback invocation: the tag, then the resolved callback slot,
               ;; the continue target, the pause continuation, and the branch
               ;; map as a count followed by (key, target) records.
               ;;
               ;; THE TAG IS TEN, not the eight the state-kind run would reach
               ;; next: tags eight and nine are the two trailing slot-table
               ;; sections below, and a reader walking this stream linearly
               ;; could not tell a state record from a section by position alone
               ;; once a machine carried both.
               ;;
               ;; EVERY PART IS ENCODED: a different slot is a different
               ;; callback, a different key selects a different target, and a
               ;; different branch ORDER is a different machine (the list is
               ;; deterministic caller order). Machines differing in any of them
               ;; emit different libraries, so they must differ in fingerprint.
               ((callback)
                (put-u8 p 10)
                (put-u16be p (normal-field-selector s))
                (let ((tg (normal-field-targets s)))
                  (put-u32be p (car tg))
                  (put-u32be p (cadr tg))
                  ;; The default target, written with a PRESENCE TAG rather than
                  ;; a sentinel id -- the field action's error-target rule -- so
                  ;; "this callback is required and has no default" and "the
                  ;; default is state 0" cannot collide.
                  (let ((d (caddr tg)))
                    (if d (begin (put-u8 p 1) (put-u32be p d)) (put-u8 p 0))))
                (let ((bs (normal-field-arguments s)))
                  (put-u16be p (length bs))
                  (for-each (lambda (b)
                              (put-symbol p (car b))
                              (put-u32be p (cdr b)))
                            bs)))
               ;; The two span kinds and the internal substep. Tags ELEVEN,
               ;; TWELVE and THIRTEEN: the state-kind run holds 0-7 and 10, and
               ;; 8 and 9 are the trailing slot-table SECTION discriminators, so
               ;; a reader walking this stream linearly could not tell a state
               ;; record from a section by position alone once a machine carried
               ;; both.
               ;;
               ;; EVERY PART IS ENCODED: a different span slot is a different
               ;; span, a different successor is a different machine, and a span
               ;; end's continuation id is what the emitted lane resumes at, so
               ;; all three enter the fingerprint.
               ((span-start)
                (put-u8 p 11)
                (put-u16be p (normal-field-selector s))
                (put-u32be p (normal-field-targets s)))
               ((span-end)
                (put-u8 p 12)
                (put-u16be p (normal-field-selector s))
                (put-u32be p (normal-field-arguments s))
                (put-u32be p (normal-field-targets s)))
               ((span-completion)
                (put-u8 p 13)
                (put-u16be p (normal-field-selector s))
                (put-u32be p (normal-field-targets s)))
               (else (assertion-violation 'normalize-machine "unknown state kind"
                                          (normal-state-kind s)))))
           (loop (+ i 1))))
       ;; --- the optional trailing slot-table sections -------------------------
       ;;
       ;; EVERY BYTE BELOW IS INSIDE A GUARD, THE COUNT AND THE TAG INCLUDED. A
       ;; machine declaring neither a callback nor a span writes ZERO bytes here
       ;; and therefore encodes byte-identically to one with no such
       ;; declarations, which is what keeps every pinned fingerprint still. An
       ;; unconditional count would be two bytes on every machine in the tree and
       ;; would move all of them.
       ;;
       ;; THE TAG IS WHY THERE IS A TAG. Two guarded tables with no discriminator
       ;; are ambiguous: one callback and no spans, versus no callbacks and one
       ;; span, both emit [count][one record]. Both record kinds are
       ;; symbol-shaped, so they can collide, and a collision would falsify the
       ;; claim that declaration identity is fingerprint-visible. Tags 8 and 9:
       ;; the state-kind tags run 0-7.
       ;;
       ;; EVERY PART THAT REACHES THE ABI IS ENCODED. A datum must enter the
       ;; ENCODING, not merely be read from the source machine: two machines
       ;; differing only in a reason must differ in fingerprint, or the
       ;; fingerprint stops identifying what was emitted. So a callback's
       ;; `required?`, `kind`, and `default-branch`, and a span's two callback
       ;; NAMES, are all encoded -- machines differing only in one of them emit
       ;; different libraries.
       ;;
       ;; The slot is still not written: it is the record's position, and writing
       ;; it too would let the stream express a table whose slots disagree with
       ;; their order -- the field table's rule, restated.
       (unless (null? callbacks)
         (put-u8 p 8)
         (put-u16be p (length callbacks))
         (for-each (lambda (c)
                     (put-symbol p (callback-declaration-name c))
                     (put-symbol p (callback-declaration-kind c))
                     (put-u8 p (if (callback-declaration-required? c) 1 0))
                     (let ((d (callback-declaration-default-branch c)))
                       (if (symbol? d)
                           (begin (put-u8 p 1) (put-symbol p d))
                           (put-u8 p 0))))
                   callbacks))
       (unless (null? spans)
         (put-u8 p 9)
         (put-u16be p (length spans))
         (for-each (lambda (sd)
                     (put-symbol p (span-declaration-name sd))
                     (put-symbol p (span-declaration-data-callback sd))
                     (let ((c (span-declaration-complete-callback sd)))
                       (if (symbol? c)
                           (begin (put-u8 p 1) (put-symbol p c))
                           (put-u8 p 0))))
                   spans)))))

  ;; Slot = declaration index. `machine-fields` is the declaration list in
  ;; declaration order, so the slot is the position and this is a numbering, not
  ;; a choice.
  (define (field-table machine)
    (let loop ((fs (machine-fields machine)) (slot 0) (out '()))
      (if (null? fs) (reverse out)
          (loop (cdr fs) (+ slot 1)
                (cons (list (uint-field-name (car fs))
                            (uint-field-width (car fs))
                            (uint-field-initial (car fs))
                            slot)
                      out)))))

  ;; The callback and span halves. Slot IS the position, so these are the
  ;; declaration names in declaration order; declaration order carries no
  ;; semantic priority and exists precisely to give stable ids.
  (define (name-table decls name-of)
    (let tloop ((ds decls) (slot 0) (out '()))
      (if (null? ds) (reverse out)
          (tloop (cdr ds) (+ slot 1)
                 (cons (list (name-of (car ds)) slot) out)))))

  ;; normalize-machine : Machine -> NormalMachine
  (define (normalize-machine machine)
    (let-values (((entry states debug-map) (lower-machine machine)))
      (let* ((fields (field-table machine))
             (callbacks (name-table (machine-callbacks machine)
                                    callback-declaration-name))
             (spans (name-table (machine-spans machine) span-declaration-name))
             ;; Name -> CALLBACK slot, read off the table just built rather than
             ;; re-walking the declarations: the slot IS the list position, and
             ;; reading it back is what keeps the span table's numbering the same
             ;; object the callback table published.
             ;;
             ;; A MISS ANSWERS #f AND DOES NOT RAISE, which is the one place this
             ;; table differs from `span-slot-of` above. `normalize-machine` is
             ;; reachable for an unverified machine, and a span naming no callback
             ;; declaration is exactly what verify rejects as
             ;; `missing-callback-declaration`. Raising here would move that
             ;; rejection out of the verifier and into the normalizer for every
             ;; caller. The #f cannot reach an emitted arm: `render-machine`
             ;; refuses an unverified compilation before it reads this table, so a
             ;; guard on the emitter side would be one that cannot fire.
             (cb-slot (lambda (nm)
                        (let loop ((cs callbacks))
                          (cond ((null? cs) #f)
                                ((eq? (car (car cs)) nm) (cadr (car cs)))
                                (else (loop (cdr cs))))))))
        (make-normal-machine entry states
                             ;; The DECLARATIONS reach the encoder, not the slot
                             ;; tables: every part the ABI carries must be in the
                             ;; fingerprint, and a slot table holds only names.
                             (fnv1a-64 (encode-normal entry states fields
                                                      (machine-callbacks machine)
                                                      (machine-spans machine)))
                             debug-map fields callbacks spans
                             (map (lambda (c)
                                    (list (callback-declaration-name c)
                                          (callback-declaration-kind c)
                                          (callback-declaration-required? c)
                                          (callback-declaration-default-branch c)))
                                  (machine-callbacks machine))
                             (map (lambda (d)
                                    (list (span-declaration-name d)
                                          (cb-slot (span-declaration-data-callback d))
                                          (let ((c (span-declaration-complete-callback d)))
                                            (and c (cb-slot c)))))
                                  (machine-spans machine)))))))
