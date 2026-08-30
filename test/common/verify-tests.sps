;;; verify-machine over the one-byte machine and its broken variants. Tests
;;; compare diagnostic codes, never rendered text (parent §16.4).
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify))

(harness-begin "verify.rejections")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define errs (list eof-decl rej-decl))
(define accept-case
  (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
(define (dispatch cases fallback) (make-byte-dispatch-node 'start cases fallback #f #f))
(define (one-byte-nodes fallback)
  (list (dispatch (list accept-case) fallback)
        (make-stop-node 'stop #f)
        (make-error-node 'reject 'rejected #f)))
(define (machine* name nodes eof-name)
  (make-machine name 'start '() '() '() errs nodes eof-name #f))
(define (machine nodes) (machine* 'one-byte nodes 'default-eof))

(define (codes m) (map diagnostic-code (verification-diagnostics (verify-machine m))))
(define (has-code? m code) (and (memq code (codes m)) #t))

(harness-group "the valid one-byte machine"
  (lambda ()
    (harness-case "verifies with no diagnostics"
      (lambda ()
        (let ((v (verify-machine (machine (one-byte-nodes (make-edge 'reject 'reexecute))))))
          (check "ok" (verification-ok? v))
          (let ((ds 'seed))
            (set! ds (verification-diagnostics v))
            (check "no diagnostics" (null? ds))))))))

(harness-group "rejections, one per decision"
  (lambda ()
    (harness-case "a fallback target that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code? (machine (one-byte-nodes (make-edge 'nowhere 'reexecute)))
                          'missing-target))))
    (harness-case "two exact cases on the same byte overlap"
      (lambda ()
        (let ((dup (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f)))
          (check "overlapping-cases"
                 (has-code? (machine (list (dispatch (list accept-case dup)
                                                     (make-edge 'reject 'reexecute))
                                           (make-stop-node 'stop #f)
                                           (make-error-node 'reject 'rejected #f)))
                            'overlapping-cases)))))
    (harness-case "an unreachable node is rejected"
      (lambda ()
        (check "unreachable-node"
               (has-code? (machine (append (one-byte-nodes (make-edge 'reject 'reexecute))
                                           (list (make-stop-node 'orphan #f))))
                          'unreachable-node))))
    (harness-case "a reexecute self-loop is a zero-progress cycle"
      (lambda ()
        (check "zero-progress-cycle"
               (has-code?
                (machine (list (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                               (make-edge 'start 'reexecute) #f))
                                         (make-edge 'start 'reexecute))
                               (make-stop-node 'stop #f)
                               (make-error-node 'reject 'rejected #f)))
                'zero-progress-cycle))))
    (harness-case "two nodes sharing a name is duplicate-name"
      (lambda ()
        (check "duplicate-name"
               (has-code? (machine (list (dispatch (list accept-case)
                                                   (make-edge 'reject 'reexecute))
                                         (make-stop-node 'stop #f)
                                         (make-stop-node 'stop #f)   ; duplicate 'stop
                                         (make-error-node 'reject 'rejected #f)))
                          'duplicate-name))))
    (harness-case "an error node naming an undeclared error is missing-error-declaration"
      (lambda ()
        (check "missing-error-declaration"
               (has-code? (machine (list (dispatch (list accept-case)
                                                   (make-edge 'reject 'reexecute))
                                         (make-stop-node 'stop #f)
                                         (make-error-node 'reject 'ghost #f)))  ; no 'ghost decl
                          'missing-error-declaration))))
    (harness-case "a default-eof-error naming no declared error is invalid-eof-target"
      (lambda ()
        (check "invalid-eof-target"
               (has-code? (machine* 'one-byte (one-byte-nodes (make-edge 'reject 'reexecute))
                                    'ghost-eof)
                          'invalid-eof-target))))
    (harness-case "an uppercase machine name is invalid-name"
      (lambda ()
        (check "invalid-name"
               (has-code? (machine* 'One-Byte (one-byte-nodes (make-edge 'reject 'reexecute))
                                    'default-eof)
                          'invalid-name))))
    (harness-case "two error declarations sharing a name is duplicate-error-declaration"
      (lambda ()
        (check "duplicate-error-declaration"
               (has-code?
                (make-machine 'one-byte 'start '() '() '()
                              (list eof-decl rej-decl
                                    (make-error-declaration 'rejected 'unexpected-byte
                                                            "unexpected byte" #f))
                              (one-byte-nodes (make-edge 'reject 'reexecute))
                              'default-eof #f)
                'duplicate-error-declaration))))
    (harness-case "a non-machine handed to verify-machine is invalid-shape"
      (lambda ()
        (check "invalid-shape" (has-code? 'not-a-machine 'invalid-shape))))
    (harness-case "an uppercase node name is invalid-name"
      (lambda ()
        (check "invalid-name"
               (has-code?
                (make-machine 'one-byte 'start '() '() '() errs
                              (list (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                                    (make-edge 'S1 'advance) #f))
                                              (make-edge 'reject 'reexecute))
                                    (make-stop-node 'S1 #f)
                                    (make-error-node 'reject 'rejected #f))
                              'default-eof #f)
                'invalid-name))))
    (harness-case "an uppercase error code is invalid-name"
      (lambda ()
        (check "invalid-name"
               (has-code?
                (make-machine 'one-byte 'start '() '() '()
                              (list eof-decl
                                    (make-error-declaration 'rejected 'Unexpected
                                                            "unexpected byte" #f))
                              (one-byte-nodes (make-edge 'reject 'reexecute))
                              'default-eof #f)
                'invalid-name))))
    (harness-case "an entry that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code?
                (make-machine 'one-byte 'ghost-entry '() '() '() errs
                              (one-byte-nodes (make-edge 'reject 'reexecute))
                              'default-eof #f)
                'missing-target))))))

(harness-group "EOF terminals and eof-target verification (§16.2)"
  (lambda ()
    ;; A valid EOF machine: entry reads byte 1 (advance to stop); its eof-target
    ;; is a FINISH node (idle completion). Fallback -> reject error.
    (define (eof-ok)
      (make-machine 'eofok 's0 '() '() '()
        (list (make-error-declaration 'default-eof 'eof "eof" #f)
              (make-error-declaration 'rejected 'unexpected-byte "bad" #f))
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) 'done #f)   ; eof-target -> finish node 'done
              (make-stop-node 'stop #f)
              (make-finish-node 'done #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (harness-case "a finish node reachable only via an eof-target verifies"
      (lambda ()
        (check "verifies" (verification-ok? (verify-machine (eof-ok))))))
    ;; §16.2:908 — a BYTE edge into a finish terminal is rejected.
    (harness-case "a byte case targeting a finish node is rejected (non-eof-into-finish)"
      (lambda ()
        (let ((m (make-machine 'bad1 's0 '() '() '()
                   (list (make-error-declaration 'default-eof 'eof "eof" #f))
                   (list (make-byte-dispatch-node 's0
                           (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'done 'advance) #f))
                           (make-edge 'done 'reexecute) #f #f)   ; byte edges -> finish node
                         (make-finish-node 'done #f))
                   'default-eof #f)))
          (check "has non-eof-into-finish"
                 (memq 'non-eof-into-finish
                       (map diagnostic-code (verification-diagnostics (verify-machine m))))))))
    ;; §16.2:909 — an eof-target chain reaching a STOP terminal is rejected.
    (harness-case "an eof-target reaching a stop terminal is rejected (eof-reachable-stop)"
      (lambda ()
        (let ((m (make-machine 'bad2 's0 '() '() '()
                   (list (make-error-declaration 'default-eof 'eof "eof" #f))
                   (list (make-byte-dispatch-node 's0
                           (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                           (make-edge 'stop 'reexecute) 'stop #f)   ; eof-target -> stop
                         (make-stop-node 'stop #f))
                   'default-eof #f)))
          (check "has eof-reachable-stop"
                 (memq 'eof-reachable-stop
                       (map diagnostic-code (verification-diagnostics (verify-machine m))))))))
    ;; EOF zero-progress cycle — s0 eof-target s1, s1 eof-target s0.
    (harness-case "an eof-target cycle is rejected (eof-zero-progress-cycle)"
      (lambda ()
        (let ((m (make-machine 'bad3 's0 '() '() '()
                   (list (make-error-declaration 'default-eof 'eof "eof" #f))
                   (list (make-byte-dispatch-node 's0
                           (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
                           (make-edge 's1 'advance) 's1 #f)
                         (make-byte-dispatch-node 's1
                           (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 's0 'advance) #f))
                           (make-edge 's0 'advance) 's0 #f))
                   'default-eof #f)))
          (check "has eof-zero-progress-cycle"
                 (memq 'eof-zero-progress-cycle
                       (map diagnostic-code (verification-diagnostics (verify-machine m))))))))))

;; Shared helper for this group: a machine over nodes with entry 'e0 and the
;; standard three error declarations, matching the group's other fixtures.
(define (pause-fixture nodes)
  (make-machine 'pm 'e0 '() '() '()
    (list (make-error-declaration 'default-eof 'eof "eof" #f)
          (make-error-declaration 'rejected 'unexpected-byte "bad byte" #f)
          (make-error-declaration 'truncated 'truncated-input "truncated" #f))
    nodes 'default-eof #f))

(harness-group "pause nodes (Slice 3)"
  (lambda ()
    (harness-case "a well-formed pause machine verifies"
      (lambda ()
        ;; e0 --byte 1/advance--> p (pause) --> s1 --byte 2/advance--> stop;
        ;; e0's eof-target pauses (pe) into a finish node.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) 'pe #f)
                         (make-pause-node 'p 's1 #f)
                         (make-byte-dispatch-node 's1
                           (list (make-byte-case (make-exact-byte-matcher 2)
                                                 (make-edge 'stop 'advance) #f))
                           (make-edge 'reject 'reexecute) 'trunc #f)
                         (make-pause-node 'pe 'done #f)
                         (make-stop-node 'stop #f)
                         (make-finish-node 'done #f)
                         (make-error-node 'trunc 'truncated #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "accepted" (verification-ok? v))
          ;; ATTRIBUTION, not verdict. "accepted" is one boolean that ANY
          ;; diagnostic reddens, so every mutation that wrongly rejects this
          ;; fixture fails the same check and no pin can say which one did it
          ;; (the pin sweep measured exactly that: three mutants shared this
          ;; record). These two name the diagnostic that must be ABSENT, so
          ;; each of those mutants fails a different check:
          ;;   'unreachable-node -- node-out-targets' pause arm is what keeps
          ;;     p's continuation s1 (and pe's continuation done) on the
          ;;     reachability walk; dropping it strands them.
          ;;   'non-eof-into-finish -- pe is EOF-only-reachable and continues
          ;;     into a finish node, which is legal (decision 0011); only the
          ;;     :908 site's byte-reachability gate keeps it legal.
          (let ((cs (map diagnostic-code (verification-diagnostics v))))
            (check "no unreachable-node" (not (memq 'unreachable-node cs)))
            (check "no non-eof-into-finish"
                   (not (memq 'non-eof-into-finish cs)))))))
    (harness-case "a pause continuation naming no node is malformed (§16.2:905)"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'nowhere #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "missing-target diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'missing-target))
                         (verification-diagnostics v))))))
    (harness-case "a byte-reachable pause into a finish node is non-EOF flow (§16.2:908)"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'done #f)
                         (make-finish-node 'done #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "non-eof-into-finish diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'non-eof-into-finish))
                         (verification-diagnostics v))))))
    (harness-case "an EOF chain of pauses that cycles is a zero-progress EOF cycle"
      (lambda ()
        ;; e0's eof-target enters pa; pa -> pb -> pa never reaches a terminal.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'stop 'advance) #f))
                           (make-edge 'reject 'reexecute) 'pa #f)
                         (make-pause-node 'pa 'pb #f)
                         (make-pause-node 'pb 'pa #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "eof-zero-progress-cycle diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-zero-progress-cycle))
                         (verification-diagnostics v)))
          (check "zero-progress-cycle diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'zero-progress-cycle))
                         (verification-diagnostics v)))
          ;; Attribution, not just verdict: the eof-zero-progress-cycle above is
          ;; the entry dispatch node e0's own :909 eof-target-chain walk (its
          ;; target is 'pa, which cycles). It must NOT also be raised on 'pa
          ;; itself -- that would only happen if the D4(d) byte-reachability
          ;; gate at the eof-terminal-chain call site stopped filtering pa/pb
          ;; out (neither is byte-reached; both are eof-only-reachable), which
          ;; produces a redundant same-code diagnostic no verdict-based check
          ;; can see (whole-branch review; see the mutation's own comment).
          (check "eof-zero-progress-cycle attributed to e0"
                 (exists (lambda (d) (and (eq? (diagnostic-code d) 'eof-zero-progress-cycle)
                                           (eq? (diagnostic-node d) 'e0)))
                         (verification-diagnostics v)))
          (check "no eof-zero-progress-cycle attributed to pa"
                 (not (exists (lambda (d) (and (eq? (diagnostic-code d) 'eof-zero-progress-cycle)
                                                (eq? (diagnostic-node d) 'pa)))
                              (verification-diagnostics v)))))))
    (harness-case "an EOF chain through a pause into a stop is rejected (§16.2:909)"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'stop 'advance) #f))
                           (make-edge 'reject 'reexecute) 'pa #f)
                         (make-pause-node 'pa 'stop #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "eof-reachable-stop diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-reachable-stop))
                         (verification-diagnostics v))))))
    ;; Both terminal kinds an EOF walk can reach THROUGH a pause, in one
    ;; machine, counted rather than merely witnessed. Every case above reaches
    ;; exactly one of them, so each is satisfied by a walk that stops AT the
    ;; pause for the other kind's reason; counting both at once is what
    ;; separates "the pause arm walks on" from "stop is classified" and "a
    ;; cycle is classified": against the correct 2, the pause-arm edit reports
    ;; 0 and the other two report 1 each, so the 0 belongs to the pause arm
    ;; alone -- which no single-terminal fixture can say.
    ;;   e0 --eof--> pa (pause) --> stop        : eof-reachable-stop on e0
    ;;   e1 --eof--> pb (pause) --> e1 --eof--> : eof-zero-progress-cycle on e1
    ;; Neither pause is byte-reachable (each is only an eof-target), so the
    ;; D4(b)/(d) pause checks are out of the picture and the count belongs to
    ;; the dispatch-node walk alone.
    (harness-case "an EOF walk crosses a pause for both terminal kinds (§16.2:909)"
      (lambda ()
        (let* ((v (verify-machine
                   (pause-fixture
                    (list (make-byte-dispatch-node 'e0
                            (list (make-byte-case (make-exact-byte-matcher 1)
                                                  (make-edge 'e1 'advance) #f))
                            (make-edge 'reject 'reexecute) 'pa #f)
                          (make-pause-node 'pa 'stop #f)
                          (make-byte-dispatch-node 'e1
                            (list (make-byte-case (make-exact-byte-matcher 2)
                                                  (make-edge 'stop 'advance) #f))
                            (make-edge 'reject 'reexecute) 'pb #f)
                          (make-pause-node 'pb 'e1 #f)
                          (make-stop-node 'stop #f)
                          (make-error-node 'reject 'rejected #f)))))
               (cs (map diagnostic-code (verification-diagnostics v))))
          (check "rejected" (not (verification-ok? v)))
          (check-equal "both EOF terminals reported"
                       (length (filter (lambda (c)
                                         (or (eq? c 'eof-reachable-stop)
                                             (eq? c 'eof-zero-progress-cycle)))
                                       cs))
                       2))))
    (harness-case "a byte-reachable pause into a stop would leak stopped through EOF (§16.2:909)"
      (lambda ()
        ;; D4(d): after feed pauses at p, current = stop and resume returns to
        ;; ready, where finish! would begin EOF processing AT the stop.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'stop #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "eof-reachable-stop diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-reachable-stop))
                         (verification-diagnostics v))))))
    (harness-case "an entry pause is byte-reachable, so its chain is walked too"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-pause-node 'e0 'stop #f)
                         (make-stop-node 'stop #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "entry eof-reachable-stop diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-reachable-stop))
                         (verification-diagnostics v))))))
    (harness-case "a reexecute/pause-only cycle with no advance makes no progress"
      (lambda ()
        ;; e0 --byte 1/reexecute--> p (pause) --> e0: no byte is ever consumed.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'reexecute) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'e0 #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "zero-progress-cycle diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'zero-progress-cycle))
                         (verification-diagnostics v))))))))

;; Milestone 3 Slice ① Task 3: overlap is a property of canonical byte SETS, so
;; it must be found across mixed matcher kinds, and reported once per colliding
;; PAIR of cases -- not once per shared byte. A set and a complement can share
;; 200 bytes, and §16.4:937-943 wants one finding per decision.
(define (dispatch-node-machine cases)
  (machine (list (dispatch cases (make-edge 'reject 'reexecute))
                 (make-stop-node 'stop #f)
                 (make-error-node 'reject 'rejected #f))))
(define (overlap-count m)
  (length (filter (lambda (c) (eq? c 'overlapping-cases)) (codes m))))
(define (to-stop matcher) (make-byte-case matcher (make-edge 'stop 'advance) #f))

(harness-group "byte-class overlap (§16.2:893)"
  (lambda ()
    (harness-case "a range and an exact byte inside it overlap"
      (lambda ()
        (check "overlapping-cases"
               (has-code? (dispatch-node-machine
                           (list (to-stop (make-byte-range-matcher 48 57))
                                 (to-stop (make-exact-byte-matcher 50))))
                          'overlapping-cases))))
    (harness-case "a set and a complement that share a byte overlap"
      (lambda ()
        (check "overlapping-cases"
               (has-code? (dispatch-node-machine
                           (list (to-stop (make-byte-set-matcher '(200 201)))
                                 (to-stop (make-byte-complement-matcher
                                           (make-byte-range-matcher 0 199)))))
                          'overlapping-cases))))
    (harness-case "disjoint classes do not overlap"
      (lambda ()
        (check-equal "none"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 48 57))
                                           (to-stop (make-byte-range-matcher 65 90))
                                           (to-stop (make-byte-set-matcher '(10 13))))))
                     0)))
    (harness-case "a vacuous complement collides with nothing"
      (lambda ()
        (check-equal "none"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-complement-matcher
                                                     (make-byte-range-matcher 0 255)))
                                           (to-stop (make-byte-range-matcher 48 57)))))
                     0)))
    (harness-case "two classes sharing 200 bytes are one diagnostic, not 200"
      (lambda ()
        (check-equal "exactly one"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 199))
                                           (to-stop (make-byte-range-matcher 0 255)))))
                     1)))
    ;; These three fixtures are ordered deliberately. Each isolates one half of
    ;; the pair enumeration, so the three Task 3 mutations below have distinct
    ;; first failures and distinct failure SETS -- without the first-and-third
    ;; fixture, "collisions after the first are dropped" is subsumed by "only the
    ;; first case is compared" and no pin can separate them.
    (harness-case "a collision between the first and third cases is found"
      (lambda ()
        (check-equal "one pair"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 10))
                                           (to-stop (make-byte-range-matcher 100 110))
                                           (to-stop (make-byte-range-matcher 5 8)))))
                     1)))
    (harness-case "a collision between the second and third cases is found"
      (lambda ()
        (check-equal "one pair"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-set-matcher '(1)))
                                           (to-stop (make-byte-range-matcher 100 110))
                                           (to-stop (make-byte-set-matcher '(105))))))
                     1)))
    (harness-case "three mutually colliding cases are three diagnostics, one per pair"
      (lambda ()
        (check-equal "three pairs"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 10))
                                           (to-stop (make-byte-range-matcher 5 15))
                                           (to-stop (make-byte-range-matcher 8 20)))))
                     3)))
    ;; A collision graph deliberately NOT symmetric under the two ways the
    ;; enumeration can be truncated. The three fixtures above cannot separate
    ;; those two edits from the one that disables the disjointness test
    ;; outright: on the mutually colliding triple both truncations report 2,
    ;; and on each isolating pair the one truncation that misses it reports 0
    ;; -- the same 0 the disabled test reports. Here the colliding pairs are
    ;; (1,2), (2,3), (2,4):
    ;;   c1 0-10, c2 5-105, c3 100-110, c4 exactly 50.
    ;;   correct (every i<j)              -> 3
    ;;   first case only, vs the rest     -> 1   ((1,2))
    ;;   each case vs its successor only  -> 2   ((1,2), (2,3))
    ;;   the disjointness test always #f  -> 0
    ;;   each case also compared to ITSELF-> 7   (3 + four self-pairs)
    ;; Four distinct wrong counts, so each way of breaking the enumeration
    ;; carries its own detail.
    (harness-case "an asymmetric collision graph counts every pair, once"
      (lambda ()
        (check-equal "three pairs"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 10))
                                           (to-stop (make-byte-range-matcher 5 105))
                                           (to-stop (make-byte-range-matcher 100 110))
                                           (to-stop (make-exact-byte-matcher 50)))))
                     3)))))

;; Milestone 3 Slice ② Task 1: the sixth node kind, at the six verify.sls sites
;; it is actually extended to (design §6's dated disposition). Arms 2 and 4
;; below both exercise node-eof-target -- the site Task 1's own fix wave
;; collapsed three near-duplicate accessors into -- through its two different
;; callers, all-out-targets and pass-eof, respectively. pass-overlap and
;; pass-zero-progress's report guard are the two sites deliberately left
;; unextended until Slice ③, and are not covered by an arm here. A sequence
;; node added to ir.sls but NOT to verify.sls VERIFIES CLEAN -- targets never
;; resolution-checked, cycles never detected, EOF chain never walked -- and
;; only crashes later in the normalizer. That is why the six live sites land
;; in the same commit as the node kind.
(define (seq-node cases mismatch eof-target)
  (make-sequence-dispatch-node 'seq cases mismatch eof-target #f))
(define (one-alt bytes target) (list (make-sequence-case bytes target #f)))
;; Fix wave 1 (Minor 3): seq-machine* took a name/eof-name pair no caller ever
;; varied -- one caller (seq-machine), always 'seqnode/'default-eof. Inlined.
(define (seq-machine nodes)
  (make-machine 'seqnode 'seq '() '() '() errs nodes 'default-eof #f))
(define (well-formed-seq-nodes)
  (list (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) #f)
        (make-stop-node 'stop #f)
        (make-error-node 'reject 'rejected #f)))

(harness-group "sequence dispatch reaches every verifier arm"
  (lambda ()
    (harness-case "a well-formed sequence machine verifies with no diagnostics"
      (lambda ()
        (let ((v (verify-machine (seq-machine (well-formed-seq-nodes)))))
          (check "ok" (verification-ok? v))
          (check-equal "diagnostic count" (length (verification-diagnostics v)) 0))))
    ;; arm 1 -- node-out-targets: a case target
    (harness-case "a case target that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'nowhere)
                                           (make-edge 'reject 'reexecute) #f)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'missing-target))))
    ;; arm 1 -- node-out-targets: the mismatch edge target
    (harness-case "a mismatch target that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'nowhere 'reexecute) #f)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'missing-target))))
    ;; arm 2 -- all-out-targets: a node reachable ONLY through the sequence eof-target
    (harness-case "a node reached only through the sequence eof-target is reachable"
      (lambda ()
        (check-equal "no unreachable-node"
                     (length (filter (lambda (c) (eq? c 'unreachable-node))
                                     (codes (seq-machine
                                             (list (seq-node (one-alt '(1 2) 'stop)
                                                             (make-edge 'reject 'reexecute)
                                                             'done)
                                                   (make-stop-node 'stop #f)
                                                   (make-error-node 'reject 'rejected #f)
                                                   (make-finish-node 'done #f))))))
                     0)))
    ;; arm 3 -- reexec-targets: a dispatch node whose cycle runs through a sequence
    (harness-case "a reexecute cycle through a sequence node's mismatch edge is found"
      (lambda ()
        (check "zero-progress-cycle"
               (has-code?
                (make-machine 'cyc 'start '() '() '() errs
                  (list (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                        (make-edge 'seq 'reexecute) #f))
                                  (make-edge 'seq 'reexecute))
                        (seq-node (one-alt '(1 2) 'stop) (make-edge 'start 'reexecute) #f)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)
                'zero-progress-cycle))))
    ;; arm 4 -- pass-eof: eof-target resolution
    (harness-case "a sequence eof-target that names no node is invalid-eof-target"
      (lambda ()
        (check "invalid-eof-target"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'reject 'reexecute) 'ghost)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'invalid-eof-target))))
    ;; arm 5 -- eof-terminal: the chain is walked THROUGH a sequence node
    ;; Measured plan defect (brief §6): the literal fixture pointed the
    ;; sequence node's eof-target at 'start, but the file's `dispatch` helper
    ;; (line 15) hard-wires 'start's own eof-target to #f, so the walk
    ;; terminates at 'default-error on its first step and never even revisits
    ;; a node, let alone cycles -- confirmed by hand-tracing eof-terminal and
    ;; by the measured Step 7 red not clearing until this fixture changed. A
    ;; self-targeting eof-target ('seq instead of 'start) makes the sequence
    ;; node genuinely revisit itself, which is what exercises eof-terminal's
    ;; new sequence-dispatch-node? branch (arm 5) rather than terminating
    ;; before ever reaching it.
    (harness-case "an eof chain that cycles through a sequence node is an EOF cycle"
      (lambda ()
        (check "eof-zero-progress-cycle"
               (has-code?
                (make-machine 'eofcyc 'start '() '() '() errs
                  (list (dispatch (list accept-case) (make-edge 'reject 'reexecute))
                        (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) 'seq)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)
                'eof-zero-progress-cycle))))
    ;; Second arm-5 witness, added during mutation measurement (Step 11/12):
    ;; the self-loop fixture above is caught not only by removing arm 5 (the
    ;; sequence-dispatch-node? branch INSIDE eof-terminal) but also by
    ;; removing arm 7's own OUTER filter disjunct in pass-eof-execution --
    ;; with 'seq excluded from that map, eof-terminal is never even called
    ;; starting from 'seq, so its own inner branch is moot and both mutants
    ;; produce byte-identical FAIL output on that one case (measured; see the
    ;; mutation suite's arm 5 pin comment). A genuine two-node cycle entered
    ;; from a BYTE-DISPATCH node separates them: 'start's own eof-target
    ;; check (arm 7 never touches byte-dispatch-node? entries) drives the
    ;; walk INTO 'seq, and only arm 5's branch lets the walk continue back
    ;; out through 'seq's own eof-target to close the cycle. Measured: arm
    ;; 5's mutant fails this case (the walk reads 'unknown at 'seq and stops
    ;; short of the cycle); arm 7's mutant still finds the cycle via 'start's
    ;; independent check and leaves this case green.
    (harness-case "an eof chain that cycles from a dispatch node through a sequence node's own eof-target is an EOF cycle"
      (lambda ()
        (check "eof-zero-progress-cycle"
               (has-code?
                (make-machine 'eofcyc2 'start '() '() '() errs
                  (list (make-byte-dispatch-node 'start (list accept-case)
                                                  (make-edge 'reject 'reexecute) 'seq #f)
                        (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) 'start)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)
                'eof-zero-progress-cycle))))
    ;; arm 6 -- :908, a sequence BYTE edge into a finish terminal
    (harness-case "a sequence case targeting a finish terminal is non-eof-into-finish"
      (lambda ()
        (check "non-eof-into-finish"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'done)
                                           (make-edge 'reject 'reexecute) #f)
                                 (make-error-node 'reject 'rejected #f)
                                 (make-finish-node 'done #f)))
                          'non-eof-into-finish))))
    ;; arm 7 -- :909, the sequence node's own eof chain reaching a stop
    (harness-case "a sequence eof path reaching a stop terminal is eof-reachable-stop"
      (lambda ()
        (check "eof-reachable-stop"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'reject 'reexecute) 'stop)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'eof-reachable-stop))))))

(harness-finish)
