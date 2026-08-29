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
          (check "accepted" (verification-ok? v)))))
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
                         (verification-diagnostics v))))))
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

(harness-finish)
