;;; The normalizer lowers a verified machine to numeric-state normalized IR and a
;;; deterministic IR fingerprint. The one-byte machine pins the fingerprint
;;; algorithm (a golden value); a second, out-of-order machine pins the entry
;;; assignment and transition sort, which one dispatch case cannot witness.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test eof-machine)
        (byte-machine test pause-machine)
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
    ;; Golden value: measured against this exact encoding (format tag 1; entry and
    ;; state-count as u32be; per dispatch state u16be transition count then each
    ;; (u8 byte, u32be target, u8 mode) ascending by byte, then u32be fallback
    ;; target + u8 mode, then eof routing (tag 0 + u32be node id, or tag 1 +
    ;; u16be code-length + UTF-8 default-eof code bytes); stop = one tag byte;
    ;; error = tag byte + u16be code-length + UTF-8 code bytes; finish = one tag
    ;; byte) run through FNV-1a. A change to any FNV constant, the XOR/multiply,
    ;; or the field layout (eof routing included) moves this number.
    (harness-case "the IR fingerprint is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (normal-machine-fingerprint n1)
                     4236938459847922092)))
    (harness-case "normalization is deterministic"
      (lambda ()
        (check-equal "same fingerprint twice"
                     (normal-machine-fingerprint (normalize one-byte))
                     (normal-machine-fingerprint n1))))))

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
                     9098559711816935340)))))

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
                     15725897457025557005)))))

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
                     '((89 4 advance)))))))

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

(harness-group "the two unrepresentable trie shapes fail loudly (decision 0015 point 2)"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (lambda (e) #t)
                      (lambda () (normalize (seq-machine 'amb '(((65 66) . stop)
                                                                ((65 66 67) . halt))
                                                         (list (make-stop-node 'halt #f))))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (lambda (e) #t)
                      (lambda () (normalize (seq-machine 'dup '(((65 66) . stop)
                                                                ((65 66) . halt))
                                                         (list (make-stop-node 'halt #f))))))))))

(harness-finish)
