;;; The normalizer lowers a verified machine to numeric-state normalized IR and a
;;; deterministic IR fingerprint. The one-byte machine pins the fingerprint
;;; algorithm (a golden value); a second, out-of-order machine pins the entry
;;; assignment and transition sort, which one dispatch case cannot witness.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test eof-machine)
        (byte-machine test pause-machine)
        (byte-machine test sequence-node-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine private normal-ir))

(harness-begin "unit.normal-ir")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define (normalize m) (normalize-machine (verification-machine (verify-machine m))))
(define n1 (normalize one-byte))

;; Slice ①a task 4 helpers. `one-byte/reason` varies the reason of the
;; default-eof declaration, which IS referenced (it is the machine's
;; default-eof error); `one-byte/spare-reason` varies a third declaration that
;; no node names, so nothing resolves it and it never reaches the encoder.
(define (one-byte-parts r spare)
  (make-machine 'one-byte 'start '() '() '()
                (append (list (make-error-declaration 'default-eof 'eof r #f)
                              (make-error-declaration 'rejected 'unexpected-byte
                                                      "unexpected byte" #f))
                        (if spare
                            (list (make-error-declaration 'spare 'spare-code spare #f))
                            '()))
                (list (make-byte-dispatch-node
                       'start
                       (list (make-byte-case (make-exact-byte-matcher 0)
                                             (make-edge 'stop 'advance) #f))
                       (make-edge 'reject 'reexecute) #f #f)
                      (make-stop-node 'stop #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f))
(define (one-byte/reason r) (one-byte-parts r #f))
(define (one-byte/spare-reason r) (one-byte-parts "unexpected end of input" r))

(harness-group "the one-byte machine"
  (lambda ()
    (harness-case "entry is the first node's id"
      (lambda () (check-equal "entry" (normal-machine-entry n1) 0)))
    (harness-case "three states, in declaration order"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "count" (vector-length s) 3)
          (check-equal "state 0 kind" (normal-state-kind (vector-ref s 0)) 'dispatch)
          (check-equal "state 1 kind" (normal-state-kind (vector-ref s 1)) 'stop)
          (check-equal "state 2 kind" (normal-state-kind (vector-ref s 2)) 'error))))
    ;; Decision 0016 point 1: a DECLARED node keeps its declaration index; only
    ;; internal prefix states break the old coincidence, and they append after
    ;; the entire declared block. The one-byte machine has no sequence node, so
    ;; its ids are unchanged -- which is decision 0016 point 2 in one assertion.
    (harness-case "declared nodes keep their declaration indices (decision 0016)"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "id 0" (normal-state-id (vector-ref s 0)) 0)
          (check-equal "id 1" (normal-state-id (vector-ref s 1)) 1)
          (check-equal "id 2" (normal-state-id (vector-ref s 2)) 2)
          (check-equal "no internal states in a sequence-free machine"
                       (vector-length s) 3))))
    (harness-case "the dispatch state lowers its case and fallback to ids"
      (lambda ()
        (let ((d (vector-ref (normal-machine-states n1) 0)))
          (check-equal "transitions" (normal-dispatch-transitions d) '((0 1 advance)))
          (check-equal "fallback" (normal-dispatch-fallback d) '(2 . reexecute)))))
    (harness-case "the error state carries the resolved error CODE, not its name"
      (lambda ()
        (check-equal "code" (normal-error-code (vector-ref (normal-machine-states n1) 2))
                     'unexpected-byte)))
    ;; Golden value: measured against this exact encoding (FORMAT TAG 2 since
    ;; Milestone 4 Slice ①a; entry and state-count as u32be; then a u16be
    ;; reserved field count, zero until Slice ①b; per dispatch state u16be
    ;; transition count then each (u8 byte, u32be target, u8 mode) ascending by
    ;; byte, then u32be fallback target + u8 mode, then eof routing (tag 0 +
    ;; u32be node id, or tag 1 + u16be code-length + UTF-8 default-eof code bytes
    ;; + u16be reason-length + UTF-8 reason bytes); stop = one tag byte; error =
    ;; tag byte + u16be code-length + UTF-8 code bytes + u16be reason-length +
    ;; UTF-8 reason bytes; finish = one tag byte) run through FNV-1a. A change to any FNV constant, the XOR/multiply,
    ;; or the field layout (eof routing included) moves this number.
    (harness-case "the IR fingerprint is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (normal-machine-fingerprint n1)
                     14095574568398596535)))
    (harness-case "normalization is deterministic"
      (lambda ()
        (check-equal "same fingerprint twice"
                     (normal-machine-fingerprint (normalize one-byte))
                     (normal-machine-fingerprint n1))))
    ;; Milestone 4 Slice ①a task 4 (decision 0019 item 2). The reason must enter
    ;; the ENCODING, not merely be readable from the source machine: decision
    ;; 0009 point 2 computes the fingerprint over the canonical normalized IR and
    ;; §20:1043 makes that the object the determinism checks compare, so two
    ;; machines differing only in a reason must differ in fingerprint or the
    ;; fingerprint stops identifying what was emitted.
    (harness-case "two machines differing only in a reason differ in fingerprint"
      (lambda ()
        (check "different"
               (not (= (normal-machine-fingerprint (normalize (one-byte/reason "first")))
                       (normal-machine-fingerprint (normalize (one-byte/reason "second"))))))))
    (harness-case "an unreferenced declaration's reason does not reach the encoding"
      (lambda ()
        ;; The gate above only holds because the varied declaration is REACHED --
        ;; errcode resolves a name from the machine's default-eof error and from
        ;; each error node's target, and nothing else walks machine-errors. A
        ;; declaration no node names and that is not the default-eof error never
        ;; reaches the encoder, so this pair must be EQUAL. Stated as its own case
        ;; because a reader who varies an unreferenced reason and sees no
        ;; fingerprint move would otherwise read it as the slice failing.
        (check-equal "equal"
                     (normal-machine-fingerprint (normalize (one-byte/spare-reason "first")))
                     (normal-machine-fingerprint (normalize (one-byte/spare-reason "second"))))))))

;; Milestone 4 Slice ①b task 5: slot assignment and the field table (§17:962,
;; "assign field, callback, and span slots"; decision 0019 item 3(a)).
;;
;; SLOT = DECLARATION INDEX. Decision 0016 point 1's two-phase append applied to
;; fields, of which fields have only the first phase: nothing synthesizes a
;; field, so there is no internal-state append to follow the declared ones, and
;; §10.1:482 already makes declaration order the source of stable IDs.
(define (one-byte/fields fs)
  (make-machine 'one-byte 'start fs '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(harness-group "the field table (§17:962)"
  (lambda ()
    (harness-case "slots are declaration indices, and the table carries name, width and initial"
      (lambda ()
        (let ((t (normal-machine-fields
                  (normalize (one-byte/fields
                              (list (make-uint-field 'count 8 0 #f)
                                    (make-uint-field 'limit 16 65535 #f)))))))
          (check-equal "two entries" (length t) 2)
          (check-equal "first" (car t) '(count 8 0 0))
          (check-equal "second" (cadr t) '(limit 16 65535 1)))))
    (harness-case "a zero-field machine has an empty table"
      (lambda ()
        (check-equal "empty" (normal-machine-fields n1) '())))
    ;; The three cases below are the reason the table is ENCODED rather than
    ;; merely carried. Decision 0009 point 2 computes the fingerprint over the
    ;; canonical normalized IR and §20:1043 makes that the object the determinism
    ;; checks compare, so any part of a declaration the generated parser can
    ;; observe must move the fingerprint, or the fingerprint stops identifying
    ;; what was emitted. The NAME is observable now, through parser-field-ref;
    ;; the INITIAL is, through a read before any write. The WIDTH is not yet --
    ;; nothing in this slice writes a field, so no value can exceed its declared
    ;; range and the width has no runtime effect. It is encoded anyway because
    ;; Slice ②'s field writes make it observable, and a width that entered the
    ;; encoding later would move every field-declaring fingerprint at that point.
    ;; (This comment claimed all three were observable today; two are.) One case per component, because a
    ;; single "two different field lists differ" case passes with two of the
    ;; three unencoded.
    (harness-case "two machines differing only in a field NAME differ in fingerprint"
      (lambda ()
        (check "different"
               (not (= (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'count 8 0 #f)))))
                       (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'total 8 0 #f))))))))))
    (harness-case "two machines differing only in a field WIDTH differ in fingerprint"
      (lambda ()
        (check "different"
               (not (= (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'count 8 0 #f)))))
                       (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'count 16 0 #f))))))))))
    (harness-case "two machines differing only in a field INITIAL differ in fingerprint"
      (lambda ()
        (check "different"
               (not (= (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'count 8 0 #f)))))
                       (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'count 8 1 #f))))))))))
    ;; Declaration ORDER is the slot assignment, so it must be encoded too: the
    ;; same two fields swapped are a different machine, and without this case a
    ;; per-field encoding that summed or sorted would pass every case above.
    (harness-case "the same two fields in the other order differ in fingerprint"
      (lambda ()
        (check "different"
               (not (= (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'count 8 0 #f)
                                                          (make-uint-field 'limit 8 0 #f)))))
                       (normal-machine-fingerprint
                        (normalize (one-byte/fields (list (make-uint-field 'limit 8 0 #f)
                                                          (make-uint-field 'count 8 0 #f))))))))))
    ;; Decision 0019 item 5, asserted rather than assumed: ①a reserved the count
    ;; slot so that a zero-field machine encodes IDENTICALLY once ①b fills it.
    ;; The golden case above is that assertion for the one-byte machine; this one
    ;; states it as the invariant it is, at the value ①a measured.
    ;; The slice's own field-declaring golden (design §6 task 5). The inequality
    ;; cases above cannot replace it: dropping the COUNT while still writing the
    ;; records leaves every one of those pairs unequal, so the count byte has no
    ;; witness among them. Only an exact value pins the whole record layout --
    ;; the count, the name/width/initial order within a record, and the record
    ;; order between them.
    (harness-case "the IR fingerprint of a two-field machine is the measured golden value"
      (lambda ()
        (check-equal "fingerprint"
                     (normal-machine-fingerprint
                      (normalize (one-byte/fields (list (make-uint-field 'count 8 0 #f)
                                                        (make-uint-field 'limit 16 65535 #f)))))
                     5570336114768739383)))
    (harness-case "filling the reservation does not move a zero-field fingerprint"
      (lambda ()
        (check-equal "unmoved" (normal-machine-fingerprint (normalize (one-byte/fields '())))
                     14095574568398596535)))))

;; Entry is the second node; the dispatch node lists byte 5 before byte 2.
(define two
  (make-machine 'two 'go '() '() '() (list eof-decl rej-decl)
    (list (make-stop-node 'halt #f)
          (make-byte-dispatch-node 'go
            (list (make-byte-case (make-exact-byte-matcher 5) (make-edge 'halt 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 2) (make-edge 'halt 'advance) #f))
            (make-edge 'bad 'reexecute) #f #f)
          (make-error-node 'bad 'rejected #f))
    'default-eof #f))
(define n2 (normalize two))

(harness-group "entry and transition order"
  (lambda ()
    (harness-case "entry is the id of the entry node, not node 0"
      (lambda () (check-equal "entry" (normal-machine-entry n2) 1)))
    (harness-case "transitions are sorted ascending by byte"
      (lambda ()
        (check-equal "bytes"
                     (map car (normal-dispatch-transitions (vector-ref (normal-machine-states n2) 1)))
                     '(2 5))))))

;; The one-byte machine's eof routes to the machine default-eof error (encode
;; tag 1 + code symbol), so its fingerprint cannot witness the NODE-eof arm
;; (tag 0 + u32be node id). The shared eof-machine's two dispatch states BOTH
;; route eof to named nodes -- s0 -> finish 'done, s1 -> error 'trunc -- so its
;; fingerprint is the only golden that moves when the node-routing payload is
;; dropped from the canonical encoding. Same measured-golden discipline as the
;; one-byte case above; normalized identically through `normalize`.
(define eofm (make-eof-machine))
(define n-eof (normalize eofm))

(harness-group "node-routing eof encoding"
  (lambda ()
    (harness-case "both dispatch states route eof to a node, not the default error"
      (lambda ()
        (let ((s (normal-machine-states n-eof)))
          (check-equal "s0 eof" (car (normal-dispatch-eof (vector-ref s 0))) 'node)
          (check-equal "s1 eof" (car (normal-dispatch-eof (vector-ref s 1))) 'node))))
    (harness-case "the IR fingerprint of the node-routing machine is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (normal-machine-fingerprint n-eof)
                     13828870821654800916)))))

;; The pause tag (4) plus its u32be continuation id (D5) is not exercised by
;; the one-byte or node-routing goldens above -- neither fixture has a pause
;; node -- so this is the only golden that moves when the pause encode arm's
;; bytes change. Same measured-golden discipline as those two cases; node
;; order s0 p1 s1 pe stop done trunc reject -> ids 0..7, normalized
;; identically through `normalize`.
(define pausem (make-pause-machine))
(define n-pause (normalize pausem))

(harness-group "pause normalization (Slice 3)"
  (lambda ()
    (harness-case "pause states lower to kind pause with the continuation id"
      (lambda ()
        (let* ((states (normal-machine-states n-pause))
               (p1 (vector-ref states 1))
               (pe (vector-ref states 3)))
          (check-equal "p1 kind" (normal-state-kind p1) 'pause)
          (check-equal "p1 target" (normal-pause-target p1) 2)
          (check-equal "pe kind" (normal-state-kind pe) 'pause)
          (check-equal "pe target" (normal-pause-target pe) 5))))
    (harness-case "the pause encoding is pinned by a fingerprint golden"
      (lambda ()
        (check-equal "pause fingerprint" (normal-machine-fingerprint n-pause)
                     17903327606435836645)))))

;; Milestone 3 Slice ① Task 4 (decision 0014): a byte set, range or complement
;; lowers to ONE normalized transition per byte. Normalized IR gains no grouped
;; or set-valued transition and its encoding gains no new arm -- so these cases
;; check the transition LIST, and the three fingerprint goldens above (which no
;; class machine touches) are what proves the encoding did not move.
(define (class-machine name cases)
  (make-machine name 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start cases (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define (accepts matcher) (make-byte-case matcher (make-edge 'stop 'advance) #f))
(define (transitions-of m)
  (normal-dispatch-transitions (vector-ref (normal-machine-states (normalize m)) 0)))

(harness-group "byte classes lower to one transition per byte (decision 0014)"
  (lambda ()
    (harness-case "a range lowers to one transition per byte, ascending"
      (lambda ()
        (let ((trs (transitions-of (class-machine 'ranged (list (accepts (make-byte-range-matcher 48 51)))))))
          (check-equal "transitions" trs '((48 1 advance) (49 1 advance)
                                           (50 1 advance) (51 1 advance))))))
    (harness-case "an unsorted, duplicated byte set lowers ascending and de-duplicated"
      (lambda ()
        (check-equal "bytes"
                     (map car (transitions-of
                               (class-machine 'setm (list (accepts (make-byte-set-matcher '(5 2 5 9)))))))
                     '(2 5 9))))
    (harness-case "a complement lowers to 254 transitions covering the universe minus two"
      (lambda ()
        (let ((bs (map car (transitions-of
                            (class-machine 'compl
                              (list (accepts (make-byte-complement-matcher
                                              (make-byte-set-matcher '(10 13))))))))))
          (check-equal "count" (length bs) 254)
          (check-equal "first" (car bs) 0)
          (check "10 absent" (not (memv 10 bs)))
          (check "13 absent" (not (memv 13 bs))))))
    (harness-case "two disjoint classes on one node interleave into one ascending list"
      (lambda ()
        (check-equal "bytes"
                     (map car (transitions-of
                               (class-machine 'two
                                 (list (accepts (make-byte-set-matcher '(9 1)))
                                       (accepts (make-byte-range-matcher 4 5))))))
                     '(1 4 5 9))))
    (harness-case "a vacuous complement lowers to zero transitions (decision 0017 point 2)"
      (lambda ()
        (check-equal "none"
                     (transitions-of (class-machine 'vacuous
                                       (list (accepts (make-byte-complement-matcher
                                                       (make-byte-range-matcher 0 255))))))
                     '())))
    (harness-case "a full complement lowers to all 256 transitions"
      (lambda ()
        (let ((bs (map car (transitions-of
                            (class-machine 'full
                              (list (accepts (make-byte-complement-matcher
                                              (make-byte-complement-matcher
                                               (make-byte-range-matcher 0 255))))))))))
          (check-equal "count" (length bs) 256)
          (check-equal "first" (car bs) 0)
          (check-equal "last" (list-ref bs 255) 255))))))

;; Milestone 3 Slice ② Task 2 (decisions 0015 and 0016). A sequence node lowers
;; to ORDINARY dispatch states -- no new state kind, no new encoding arm -- with
;; alternatives merged into a trie so no prefix state can offer the same byte
;; twice, which is what keeps the ascending-by-byte sort a total order.
(define (seq-alt bytes target) (make-sequence-case bytes target #f))
(define (seq-machine name alts extra-nodes)
  (make-machine name 'seq '() '() '() (list eof-decl rej-decl)
    (append (list (make-sequence-dispatch-node
                   'seq (map (lambda (a) (seq-alt (car a) (cdr a))) alts)
                   (make-edge 'reject 'reexecute) #f #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            extra-nodes)
    'default-eof #f))
(define (state-of m i) (vector-ref (normal-machine-states (normalize m)) i))
(define (state-count m) (vector-length (normal-machine-states (normalize m))))
(define (kinds-of m)
  (let ((s (normal-machine-states (normalize m))))
    (let loop ((i 0) (a '()))
      (if (= i (vector-length s)) (reverse a)
          (loop (+ i 1) (cons (normal-state-kind (vector-ref s i)) a))))))
(define (trs-of m i) (normal-dispatch-transitions (state-of m i)))

(define four-byte (seq-machine 'seqnode '(((1 2 3 4) . stop)) '()))

(harness-group "a single-alternative sequence lowers to a chain of dispatch states"
  (lambda ()
    (harness-case "three declared nodes plus three internal prefix states"
      (lambda () (check-equal "count" (state-count four-byte) 6)))
    (harness-case "every lowered prefix state is an ordinary dispatch state"
      (lambda ()
        (check-equal "kinds" (kinds-of four-byte)
                     '(dispatch stop error dispatch dispatch dispatch))))
    (harness-case "the declared node keeps its declaration index and the prefix states append"
      (lambda ()
        (check-equal "root" (trs-of four-byte 0) '((1 3 advance)))
        (check-equal "prefix 1" (trs-of four-byte 3) '((2 4 advance)))
        (check-equal "prefix 2" (trs-of four-byte 4) '((3 5 advance)))
        (check-equal "prefix 3 targets the alternative's declared target"
                     (trs-of four-byte 5) '((4 1 advance)))))
    ;; Every other check here reaches a prefix state through its VECTOR
    ;; POSITION (state-of); none reads the state's own `id` field, so a lowered
    ;; state carrying the wrong id passes every check above unnoticed. This is
    ;; the one place that field is asserted for an internal (non-declared)
    ;; state at all.
    (harness-case "internal prefix states carry their own id, not a placeholder"
      (lambda ()
        (check-equal "id 3" (normal-state-id (state-of four-byte 3)) 3)
        (check-equal "id 4" (normal-state-id (state-of four-byte 4)) 4)
        (check-equal "id 5" (normal-state-id (state-of four-byte 5)) 5)))
    (harness-case "every prefix state inherits the mismatch edge as its fallback"
      (lambda ()
        (for-each (lambda (i)
                    (check-equal (string-append "fallback " (number->string i))
                                 (normal-dispatch-fallback (state-of four-byte i))
                                 '(2 . reexecute)))
                  '(0 3 4 5))))
    (harness-case "every prefix state inherits the source node's EOF edge (§12.4:727)"
      (lambda ()
        (for-each (lambda (i)
                    (check-equal (string-append "eof " (number->string i))
                                 (normal-dispatch-eof (state-of four-byte i))
                                 '(default . eof)))
                  '(0 3 4 5))))))

(harness-group "alternatives share prefix states wherever they agree"
  (lambda ()
    (define shared (seq-machine 'shared '(((65 66) . stop) ((65 67) . halt))
                                (list (make-stop-node 'halt #f))))
    (harness-case "a shared first byte becomes ONE transition into ONE state"
      (lambda ()
        (check-equal "root has a single transition" (trs-of shared 0) '((65 4 advance)))))
    (harness-case "the shared state branches to both alternatives' targets"
      (lambda ()
        (check-equal "branch" (trs-of shared 4) '((66 1 advance) (67 3 advance)))))
    (harness-case "caller order does not change the canonical result"
      (lambda ()
        (check-equal "same fingerprint"
                     (normal-machine-fingerprint
                      (normalize (seq-machine 'shared '(((65 66) . stop) ((65 67) . halt))
                                              (list (make-stop-node 'halt #f)))))
                     (normal-machine-fingerprint
                      (normalize (seq-machine 'shared '(((65 67) . halt) ((65 66) . stop))
                                              (list (make-stop-node 'halt #f))))))))
    (harness-case "alternatives that diverge at position 0 get separate states"
      (lambda ()
        (let ((d (seq-machine 'disjoint '(((65 66) . stop) ((88 89) . halt))
                              (list (make-stop-node 'halt #f)))))
          (check-equal "root" (trs-of d 0) '((65 4 advance) (88 5 advance)))
          (check-equal "A branch" (trs-of d 4) '((66 1 advance)))
          (check-equal "X branch" (trs-of d 5) '((89 3 advance))))))))

(harness-group "internal ids are depth-first pre-order, children ascending (decision 0016)"
  (lambda ()
    ;; A -> {B terminal, C -> D}, X -> Y. Depth-first gives 5,6,7; breadth-first
    ;; would give 5,7,6 -- so this fixture is what pins the traversal.
    (define ordered
      (make-machine 'order 'seq '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node 'seq
                (list (seq-alt '(65 66) 'stop) (seq-alt '(65 67 68) 'halt)
                      (seq-alt '(88 89) 'done))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f) (make-error-node 'reject 'rejected #f)
              (make-stop-node 'halt #f) (make-stop-node 'done #f))
        'default-eof #f))
    (harness-case "depth-first pre-order, not breadth-first"
      (lambda ()
        (check-equal "root" (trs-of ordered 0) '((65 5 advance) (88 7 advance)))
        (check-equal "A's child is 5" (trs-of ordered 5) '((66 1 advance) (67 6 advance)))
        (check-equal "C's child is 6, nested under 5" (trs-of ordered 6) '((68 3 advance)))
        (check-equal "X's child is 7, after the whole A subtree" (trs-of ordered 7)
                     '((89 4 advance)))))
    ;; Same gap as the four-byte fixture above: this is the ordering-sensitive
    ;; fixture, so it is also the strongest witness that each internal state's
    ;; own `id` field -- not just its position in the states vector -- matches
    ;; the depth-first allocation order.
    (harness-case "internal prefix states' own ids match the depth-first allocation"
      (lambda ()
        (check-equal "A's id" (normal-state-id (state-of ordered 5)) 5)
        (check-equal "C's id" (normal-state-id (state-of ordered 6)) 6)
        (check-equal "X's id" (normal-state-id (state-of ordered 7)) 7)))))

(harness-group "two sequence nodes never share prefix states (decision 0016 point 3)"
  (lambda ()
    (define two
      (make-machine 'two 'sa '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node 'sa (list (seq-alt '(1 2 3) 'sb))
                (make-edge 'reject 'reexecute) #f #f)
              (make-sequence-dispatch-node 'sb (list (seq-alt '(1 2 3) 'stop))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f) (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (harness-case "identical byte runs in two nodes get disjoint states, in declaring order"
      (lambda ()
        (check-equal "sa root" (trs-of two 0) '((1 4 advance)))
        (check-equal "sb root" (trs-of two 1) '((1 6 advance)))
        (check-equal "sa prefix states are 4,5" (trs-of two 4) '((2 5 advance)))
        (check-equal "sb prefix states are 6,7" (trs-of two 6) '((2 7 advance)))
        (check-equal "state count" (state-count two) 8)))))

;; Milestone 3 Slice ③ Task 3: the §21.2:1065 `version` production lowered.
;; Two alternatives sharing the seven-byte prefix `HTTP/1.` descend into ONE
;; chain and part at ONE state -- §10.6:544's shared nonterminal prefixes, and
;; the property that makes decision 0014's ascending-by-byte sort a total order
;; (no prefix state can offer the same byte twice). This is where "each
;; alternative reaches its OWN declared node" is observable at all: both
;; targets are stop nodes, so the two accepts are behaviourally identical.
(harness-group "two alternatives over a shared prefix lower to one trie"
  (lambda ()
    (define httpver
      (seq-machine 'httpver
                   (list (cons '(72 84 84 80 47 49 46 48) 'stop)    ; HTTP/1.0
                         (cons '(72 84 84 80 47 49 46 49) 'halt))   ; HTTP/1.1
                   (list (make-stop-node 'halt #f))))
    (harness-case "the shared prefix is not duplicated"
      (lambda ()
        ;; Two eight-byte alternatives lowered as separate chains would need
        ;; fourteen internal states; merged, they need seven.
        (check-equal "state count" (state-count httpver) 11)))
    (harness-case "the chain is linear until the distinguishing byte"
      (lambda ()
        (check-equal "root"     (trs-of httpver 0)  '((72 4 advance)))
        (check-equal "state 4"  (trs-of httpver 4)  '((84 5 advance)))
        (check-equal "state 5"  (trs-of httpver 5)  '((84 6 advance)))
        (check-equal "state 6"  (trs-of httpver 6)  '((80 7 advance)))
        (check-equal "state 7"  (trs-of httpver 7)  '((47 8 advance)))
        (check-equal "state 8"  (trs-of httpver 8)  '((49 9 advance)))
        (check-equal "state 9"  (trs-of httpver 9)  '((46 10 advance)))))
    (harness-case "the branch state routes each alternative to its OWN declared node"
      (lambda ()
        ;; 48 -> state 1 ('stop), 49 -> state 3 ('halt): ascending by byte, two
        ;; transitions, two different declared targets. A lowering that dropped
        ;; an alternative would show one transition here -- and this file is
        ;; where that has to be caught, because http-version-interpret-tests.sps
        ;; drives the same two alternatives through the reference interpreter,
        ;; which never touches the normalizer (interpret.sls's header, §18) and
        ;; so cannot see a lowering defect at all. The AB/AC group above makes
        ;; the same claim over a one-byte prefix; this one carries the seven-byte
        ;; chain with it.
        (check-equal "branch transitions" (trs-of httpver 10)
                     '((48 1 advance) (49 3 advance)))))))

;; house convention (conditions.sls header, and ir-tests.sps's own
;; contract-violation? helper): tests compare the condition's structured
;; fields, never rendered text. These two guards raise a plain R6RS assertion
;; violation (not the byte-machine contract condition), so the predicate
;; asserts assertion-violation?, that `who` is normalize-machine's own name,
;; and which of the two messages it carries -- (lambda (e) #t) would pass on
;; ANY raise, including one from the two messages swapped between the guards,
;; or from an unrelated later pass rejecting the same fixture outright.
(define (raises-normalize-assertion? message)
  (lambda (e)
    (and (assertion-violation? e)
         (eq? (condition-who e) 'normalize-machine)
         (equal? (condition-message e) message))))

(harness-group "the two unrepresentable trie shapes fail loudly (decision 0015 point 2)"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (raises-normalize-assertion? "ambiguous terminal prefix")
                      (lambda () (normalize (seq-machine 'amb '(((65 66) . stop)
                                                                ((65 66 67) . halt))
                                                         (list (make-stop-node 'halt #f))))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (raises-normalize-assertion? "duplicate sequence alternative")
                      (lambda () (normalize (seq-machine 'dup '(((65 66) . stop)
                                                                ((65 66) . halt))
                                                         (list (make-stop-node 'halt #f))))))))
    ;; Minor 3 (Fix wave 1): trie-insert's bs-NULL branch carries a THIRD guard
    ;; -- (when (trie-interior? t) ...) -- distinct from the bs-non-null-branch
    ;; guard the "AB|ABC" case above witnesses. It fires only when a LONGER
    ;; alternative is inserted BEFORE its own prefix (every fixture above
    ;; inserts short-first). Reversing the order is what reaches it.
    (harness-case "an ambiguous terminal prefix inserted in reverse order is also caught"
      (lambda ()
        (check-raises "ABC|AB" (raises-normalize-assertion? "ambiguous terminal prefix")
                      (lambda () (normalize (seq-machine 'amb-rev '(((65 66 67) . halt)
                                                                    ((65 66) . stop))
                                                         (list (make-stop-node 'halt #f))))))))))


;; Milestone 4 Slice ② task 5: the two zero-width kinds lower 1:1 and encode at
;; tags 5 and 6. Each new encode arm gets its OWN exact-value golden, which is
;; this file's shipped discipline -- an inequality pair cannot see a dropped
;; count or a transposed pair, only a wrong VALUE can.
(define s2-eof (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define s2-rej (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define (s2-machine nodes)
  (make-machine 'm 'act (list (make-uint-field 'count 8 0 #f)) '() '()
                (list s2-eof s2-rej) nodes 'default-eof #f))
(define (s2-fp m) (normal-machine-fingerprint (normalize m)))
(define (action-machine args)
  (s2-machine (list (make-field-action-node 'act 'add args 'next 'oops #f)
                    (make-stop-node 'next #f) (make-error-node 'oops 'rejected #f))))
(define (branch-machine args)
  (s2-machine (list (make-field-branch-node 'act 'range args 'next 'next #f)
                    (make-stop-node 'next #f))))

(harness-group "the zero-width kinds in the normalized IR (Slice ②)"
  (lambda ()
    (harness-case "a field-action machine's IR fingerprint is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (s2-fp (action-machine '(count 7))) 1386504585301950044)))
    (harness-case "a field-branch machine's IR fingerprint is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (s2-fp (branch-machine '(count 2 9))) 13536979658827033743)))
    (harness-case "the two kinds do not share an encoding"
      (lambda ()
        ;; Tags 5 and 6. Two machines identical but for the kind must differ, or
        ;; the tag byte is not doing its job.
        (check "different" (not (= (s2-fp (action-machine '(count 7)))
                                   (s2-fp (branch-machine '(count 2 9))))))))
    (harness-case "an operand VALUE reaches the encoding"
      (lambda ()
        (check "different" (not (= (s2-fp (action-machine '(count 7)))
                                   (s2-fp (action-machine '(count 8))))))))
    (harness-case "an operand's POSITION reaches the encoding"
      (lambda ()
        ;; Swapping low and high is a different machine -- and one the verifier
        ;; rejects, which is why this compares fingerprints of the NORMALIZED
        ;; form rather than going through verify-machine.
        (check "different" (not (= (s2-fp (branch-machine '(count 2 9)))
                                   (s2-fp (branch-machine '(count 9 2))))))))
    (harness-case "the selector reaches the encoding"
      (lambda ()
        (let ((a (s2-machine (list (make-field-action-node 'act 'increment '(count) 'next 'oops #f)
                                   (make-stop-node 'next #f)
                                   (make-error-node 'oops 'rejected #f))))
              (b (s2-machine (list (make-field-action-node 'act 'decrement '(count) 'next 'oops #f)
                                   (make-stop-node 'next #f)
                                   (make-error-node 'oops 'rejected #f)))))
          (check "different" (not (= (s2-fp a) (s2-fp b)))))))
    (harness-case "an absent error target is not the same as targeting state zero"
      (lambda ()
        ;; The reason the error target is written with a PRESENCE TAG rather than
        ;; a sentinel id: `clear` cannot fail and carries no target, and state 0
        ;; is a perfectly ordinary state id.
        (let ((safe (s2-machine (list (make-field-action-node 'act 'clear '(count) 'next #f #f)
                                      (make-stop-node 'next #f))))
              (fallible (s2-machine (list (make-field-action-node 'act 'increment '(count) 'next 'act #f)
                                          (make-stop-node 'next #f)))))
          (check "different" (not (= (s2-fp safe) (s2-fp fallible)))))))
    (harness-case "widening the state vector moved no existing fingerprint"
      (lambda ()
        ;; Design §0 D3's whole cost argument: ② pays the six-literal edit and
        ;; existing machines encode identically, because the new slots are #f for
        ;; every shipped kind and none of them is written. Asserted at ①a's own
        ;; measured value rather than left to the goldens to notice.
        (check-equal "unmoved" (normal-machine-fingerprint n1) 14095574568398596535)))))


;; *** Whole-branch review of Slice ②: every normalized state must be the LENGTH
;; THIS FILE'S LAYOUT DECLARES, and one kind was not. ***
;;
;; Slice ② widened the vector from eight slots to eleven and missed `seq-state`,
;; which builds every sequence-dispatch node's state. Sequence states carry kind
;; `dispatch`, and the only readers of slots 8-10 are kind-guarded, so nothing
;; reached one and all 92 lanes stayed green -- while four of the six states in
;; the sequence-node fixture were three slots short of the declared layout.
;;
;; This case is TOTAL over the state kinds a fixture can produce, deliberately:
;; a case naming one kind would have passed the whole time. It is the check that
;; makes "the vector was widened" a fact rather than a claim, and the reason a
;; later slice adding a kind cannot repeat the miss.
(define (state-lengths m)
  (let* ((ss (normal-machine-states (normalize m))))
    (let loop ((i 0) (acc '()))
      (if (>= i (vector-length ss)) (reverse acc)
          (loop (+ i 1) (cons (vector-length (vector-ref ss i)) acc))))))

(harness-group "every normalized state has the declared layout length"
  (lambda ()
    (harness-case "across every fixture and every state kind"
      (lambda ()
        ;; A sentinel over the OBSERVED count of states inspected, not over the
        ;; number of fixtures: a fixture that lowered to zero states would
        ;; otherwise contribute nothing and pass.
        (let ((seen 0) (bad '()))
          (for-each
           (lambda (m)
             (for-each (lambda (len)
                         (set! seen (+ seen 1))
                         (unless (= len 11) (set! bad (cons len bad))))
                       (state-lengths m)))
           (list one-byte two (make-eof-machine) (make-pause-machine)
                 (make-sequence-node-machine)
                 (action-machine '(count 7)) (branch-machine '(count 2 9))))
          (check-equal "no state is the wrong length" bad '())
          (check "every fixture contributed states" (> seen 20)))))))

(harness-finish)
