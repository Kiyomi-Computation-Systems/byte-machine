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
;; Slice ①b task 4: a one-byte machine carrying a caller-supplied field list.
(define (machine-with-fields fs)
  (make-machine 'one-byte 'start fs '() '() errs
                (one-byte-nodes (make-edge 'reject 'reexecute)) 'default-eof #f))
;; Slice ①a task 1: a one-byte machine carrying a caller-supplied error-declaration
;; list, so a reason can be varied without touching the shipped `errs`.
(define (machine-errs* ds nodes . eof-name)
  (make-machine 'one-byte 'start '() '() '() ds nodes
                (if (null? eof-name) 'default-eof (car eof-name)) #f))
(define (machine-with-reason r)
  (machine-errs* (list (make-error-declaration 'default-eof 'eof r #f) rej-decl)
                 (one-byte-nodes (make-edge 'reject 'reexecute))))

(define (codes m) (map diagnostic-code (verification-diagnostics (verify-machine m))))
;; Slice ①b: the `node` slot of each diagnostic, so a decision that says WHICH
;; name a diagnostic carries can be asserted rather than described. `codes`
;; alone is blind to it, which is how both field diagnostics shipped with their
;; "carries the offending field name" decision unwitnessed.
(define (nodes-of m) (map diagnostic-node (verification-diagnostics (verify-machine m))))
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
    ;; Milestone 4 Slice ①a task 1: §16.2:886 puts "reasons" in one portability
    ;; bullet with names and codes, and §10.1:480 restricts them to printable
    ;; ASCII plus LF -- a DIFFERENT repertoire from valid-name?'s [a-z][a-z0-9-]*,
    ;; and over a string rather than a symbol, so the reason clause is its own
    ;; predicate reusing the invalid-name CODE (decision 0022's Consequences).
    ;; The gap was inert until the emitter began writing a reason into generated
    ;; source; these three cases are what make it live.
    (harness-case "a reason outside printable ASCII is rejected"
      (lambda ()
        (let ((ds 'seed))
          (set! ds (codes (machine-with-reason (string #\a #\tab #\b))))
          (check-equal "one finding" (length ds) 1)
          (check-equal "invalid-name" (car ds) 'invalid-name))))
    (harness-case "a reason may carry quote backslash and newline"
      (lambda ()
        (let ((ds 'seed))
          ;; The three characters the emitter must escape (§20:1039). All are
          ;; inside §10.1:480's repertoire, so the VERIFIER must accept them --
          ;; escaping is the writer's job, not a rejection.
          (set! ds (codes (machine-with-reason (string #\a #\" #\\ #\newline #\b))))
          (check-equal "no diagnostics" (length ds) 0))))
    (harness-case "one declaration bad in every field still yields a single finding"
      (lambda ()
        ;; The reason clause extends the EXISTING machine-errors arm rather than
        ;; adding a fourth, so a declaration whose name, code and reason are all
        ;; nonportable reports once, not three times.
        (let ((ds 'seed))
          ;; eof-name follows the declaration's name, so the ONLY thing wrong
          ;; here is the declaration itself -- an unresolvable eof target would
          ;; add an invalid-eof-target finding and mask what this case measures.
          (set! ds (codes (machine-errs*
                           (list (make-error-declaration 'Default-Eof 'Eof (string #\tab) #f)
                                 rej-decl)
                           (one-byte-nodes (make-edge 'reject 'reexecute))
                           'Default-Eof)))
          (check-equal "one finding" (length ds) 1)
          (check-equal "invalid-name" (car ds) 'invalid-name))))
    ;; Milestone 4 Slice ①b task 4: pass-fields, declaration half (§16.3:924
    ;; item 6). It carries the RELATIONAL checks decision 0020 assigns to the
    ;; verifier -- duplicate field names and portable field names -- and nothing
    ;; else. Widths and initial ranges are closed at construction, so a machine
    ;; whose field failed them never exists and a verifier arm for either would
    ;; be dead code (0020's one-rejection-site rule).
    (harness-case "two fields sharing a name is invalid-field-declaration"
      (lambda ()
        ;; This is the defect the pass exists to close, and it verifies CLEAN
        ;; without the pass: slot = declaration index, so two `count` fields take
        ;; slots 0 and 1, after which parser-field-ref resolves the name through
        ;; one map, answers with whichever it finds first, and orphans the other
        ;; slot and its initial.
        (let ((ds 'seed))
          (set! ds (codes (machine-with-fields
                           (list (make-uint-field 'count 8 0 #f)
                                 (make-uint-field 'count 16 3 #f)))))
          (check-equal "one finding" (length ds) 1)
          (check-equal "invalid-field-declaration" (car ds) 'invalid-field-declaration))))
    (harness-case "the duplicate diagnostic names the offending FIELD"
      (lambda ()
        ;; §0 D2 and verify.sls's own comment make this a decision -- the field
        ;; name goes in the diagnostic's existing `node` slot, following
        ;; duplicate-error-declaration and missing-target, which already put
        ;; non-node symbols there. Asserted here because `codes` cannot see it.
        (let ((ns 'seed))
          (set! ns (nodes-of (machine-with-fields
                              (list (make-uint-field 'count 8 0 #f)
                                    (make-uint-field 'count 16 3 #f)))))
          (check-equal "the field name" ns '(count)))))
    (harness-case "a nonportable field name is invalid-field-declaration"
      (lambda ()
        (let ((ds 'seed))
          (set! ds (codes (machine-with-fields (list (make-uint-field 'Count 8 0 #f)))))
          (check-equal "one finding" (length ds) 1)
          (check-equal "invalid-field-declaration" (car ds) 'invalid-field-declaration))))
    (harness-case "the nonportable diagnostic names the offending FIELD"
      (lambda ()
        (let ((ns 'seed))
          (set! ns (nodes-of (machine-with-fields (list (make-uint-field 'Count 8 0 #f)))))
          (check-equal "the field name" ns '(Count)))))
    (harness-case "distinct portable field names verify clean"
      (lambda ()
        ;; The premise for both cases above: without it they could pass because
        ;; ANY field machine reddens.
        ;;
        ;; THREE fields, not two, and the count is load-bearing. The restrictive
        ;; mutant of the portable check reports one diagnostic per field here,
        ;; and this machine carries `errs` -- two declarations, two reasons -- so
        ;; at two fields the mutant's whole record set was a SUBSET of the
        ;; "reason repertoire rejects every reason" mutant's, which reddens the
        ;; same case with the same 0-versus-2. Not a loose pin but a subsumed
        ;; one: no record separated them, in either direction. A third field
        ;; separates the two by construction (3 against 2) and is the smallest
        ;; change that does. Measured, in both directions, by Task 4's Pass 33
        ;; sweep.
        (let ((ds 'seed))
          (set! ds (codes (machine-with-fields
                           (list (make-uint-field 'count 8 0 #f)
                                 (make-uint-field 'limit 16 3 #f)
                                 (make-uint-field 'seen 32 0 #f)))))
          (check-equal "no diagnostics" (length ds) 0))))
    ;; Milestone 4 Slice ①b task 3: §16.2:884's unsupported-IR-version half,
    ;; listed since Milestone 1 and unimplemented until now.
    ;;
    ;; The design (§6 task 3) said no external test could reach this arm --
    ;; "machine-tag is a freshly allocated, unexported vector compared with eq?,
    ;; so a test cannot forge a machine? object" -- and on that ground told the
    ;; implementer to declare the permissive direction EXPECT_SURVIVES. That was
    ;; measured false before this slice began. Descriptors are bare R6RS vectors
    ;; with no opacity, so (vector-ref m 0) yields the tag using an (rnrs)
    ;; primitive and no private import.
    ;;
    ;; This is a TEST-ONLY device. It reaches through the representation on
    ;; purpose, because make-machine stamps the version as a constant and §9.1's
    ;; fixed arity gives the public API no way to produce a wrong one -- so this
    ;; is the only thing that can witness the check. Confined to these two cases.
    (harness-case "a machine carrying an unsupported IR version is invalid-shape"
      (lambda ()
        (let* ((good (machine (one-byte-nodes (make-edge 'reject 'reexecute))))
               (forged (vector (vector-ref good 0) 99
                               (vector-ref good 2) (vector-ref good 3)
                               (vector-ref good 4) (vector-ref good 5)
                               (vector-ref good 6) (vector-ref good 7)
                               (vector-ref good 8) (vector-ref good 9)
                               (vector-ref good 10))))
          ;; The premise, asserted: if the representation ever changes so that
          ;; the tag cannot be copied or the version leaves slot 1, the case
          ;; below would pass vacuously -- reporting invalid-shape for "not a
          ;; machine" rather than for the version -- instead of telling anyone
          ;; the device broke. (machine? itself is private and does not come
          ;; through the façade, so the premise is asserted structurally.)
          (check "the tag was copied" (eq? (vector-ref forged 0) (vector-ref good 0)))
          (check-equal "and the version is not the supported one"
                       (vector-ref forged 1) 99)
          (check "unsupported version is reported" (has-code? forged 'invalid-shape)))))
    (harness-case "a machine at the supported IR version is not reported"
      (lambda ()
        ;; The other direction, and the one that fails if the supported constant
        ;; is mutated: every shipped fixture becomes unsupported at once.
        (let ((ds 'seed))
          (set! ds (codes (machine (one-byte-nodes (make-edge 'reject 'reexecute)))))
          (check-equal "no diagnostics" (length ds) 0))))
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

;; Milestone 3 Slice ② Task 1: the sixth node kind, at the verify.sls sites it
;; is actually extended to. Slice ③ Task 2 added the seventh. RECOUNTED at
;; Milestone 3's close, and the RULE that reproduces the number is stated here
;; because the rule is what a later reader re-derives from: not "every site in
;; verify.sls that dispatches on node KIND", which yields TWELVE at HEAD, and
;; not a grep for byte-dispatch-node?, which cannot see a cond dispatching
;; through OTHER kind predicates and so cannot find its own omission. It is
;;
;;   every kind dispatch with a PERMISSIVE FALL-THROUGH that a sequence node's
;;   own data could pass through unexamined
;;
;; -- a site whose non-matching branch quietly yields '() or #f while the sixth
;; kind carries exactly the data the site exists to inspect. That rule gives
;; EIGHT sites, SEVEN extended and ONE permanently not.
;;
;; The four kind-dispatching sites the looser wording sweeps in, and why the
;; rule excludes each: pass-names' error-node? filter (a sequence node has no
;; error name to leave undeclared); pass-eof-execution's TWO byte-reachability
;; gates for D4(b)/(d), which select pause nodes to inspect a CONTINUATION a
;; sequence node does not have -- these are NOT the pass's two :908/:909
;; filters, which are in the eight and were extended; and
;; pass-sequence-ambiguity, excluded for its own separate reason below. Each
;; positively selects one kind rather than falling through past another's data.
;;
;; This project has miscounted this set twice (design §6 said six and
;; enumerated seven; a later audit found the eighth), so the number is derived,
;; not inherited.
;;
;; The seven extended, each with an arm here: node-out-targets; node-eof-target
;; -- the site Task 1's own fix wave collapsed three near-duplicate accessors
;; into, exercised by arms 2 and 4 below through its two different callers,
;; all-out-targets and pass-eof respectively; reexec-targets; eof-terminal;
;; pass-eof-execution's two filters (§16.2:908 and :909); and
;; pass-zero-progress's REPORT guard, which Slice ② deliberately left out and
;; Slice ③ added (§25:1533) -- covered by the two zero-progress cases below,
;; "a sequence node whose reexecute mismatch edge targets itself ..." and its
;; advance-mode twin, which sit between arms 3 and 4.
;;
;; The eighth, pass-overlap, is the one site deliberately NOT extended, and
;; PERMANENTLY so rather than deferred: decision 0017 point 4 keeps §16.2:893
;; and :894 as two entries with two checks and two codes, and :894 is
;; pass-sequence-ambiguity's, not this pass's. It has no arm here and will not
;; get one. pass-sequence-ambiguity is itself a ninth kind-dispatching site but
;; is NOT in the census above: it is sequence-only by construction, born in
;; Slice ③ already knowing the sixth kind, and was never a permissive
;; fall-through that had to be taught it. Its own group is at the end of this
;; file.
;;
;; A sequence node added to ir.sls but NOT to verify.sls VERIFIES CLEAN --
;; targets never resolution-checked, cycles never detected, EOF chain never
;; walked -- and only crashes later in the normalizer. That is why Slice ②'s
;; six live sites landed in the same commit as the node kind.
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
    ;; Milestone 3 Slice ③ Task 2: §25:1533's cycle extension, and BOTH halves
    ;; of exit criterion §25:1540. Slice ② taught reexec-targets to see THROUGH
    ;; a sequence node while deliberately leaving it out of the REPORTED set;
    ;; this is the report. Measured on `main` before the extension: the first
    ;; fixture verified ok #t with ZERO diagnostics and HUNG both executors
    ;; (exit 124 under timeout), while the byte-identical shape built from a
    ;; byte-dispatch node reported zero-progress-cycle.
    (harness-case "a sequence node whose reexecute mismatch edge targets itself is a zero-progress cycle"
      (lambda ()
        (let ((m (make-machine 'selfseq 'seq '() '() '() errs
                   (list (seq-node (one-alt '(65 66) 'stop) (make-edge 'seq 'reexecute) #f)
                         (make-stop-node 'stop #f))
                   'default-eof #f)))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "zero-progress-cycle" (has-code? m 'zero-progress-cycle)))))
    ;; The other half of :1540. The mismatch edge's MODE is the whole decision:
    ;; an advance edge consumes the mismatching byte, so the loop makes
    ;; progress and must verify clean. reexec-targets' sequence arm is what
    ;; discriminates on mode; this case is what stops the report guard from
    ;; being widened past it.
    ;;
    ;; The third check is an ATTRIBUTION check, and the whole-branch review fix
    ;; wave added it on a measurement rather than on a reading. "ok" and
    ;; "diagnostic count" are unattributed: they say the machine verified
    ;; clean, not WHICH diagnostic would have been wrong. Measured at 42
    ;; mutations, three different Pass 33 mutants redden both of them here with
    ;; three different diagnostics -- the mode test deleted (zero-progress-cycle
    ;; on 'seq), node-out-targets' sequence arm deleted (unreachable-node on
    ;; 'stop), and the sequence-alternative self-comparison
    ;; (ambiguous-sequence-prefix) -- so a count of 1 is reached three ways and
    ;; the mode decision owned no FAIL record of its own. Naming the code that
    ;; must be ABSENT splits them: only losing the mode test can put a
    ;; zero-progress-cycle on a machine whose mismatch edge consumes a byte.
    ;; This is the same remedy the pause group's "no unreachable-node" /
    ;; "no non-eof-into-finish" checks above use, for the same reason.
    (harness-case "the same self-target with an advance mismatch edge is a consuming cycle and passes"
      (lambda ()
        (let ((v (verify-machine
                  (make-machine 'advseq 'seq '() '() '() errs
                    (list (seq-node (one-alt '(65 66) 'stop) (make-edge 'seq 'advance) #f)
                          (make-stop-node 'stop #f))
                    'default-eof #f))))
          (check "ok" (verification-ok? v))
          (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)
          (check "no zero-progress-cycle"
                 (not (memq 'zero-progress-cycle
                            (map diagnostic-code
                                 (verification-diagnostics v))))))))
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
                          'eof-reachable-stop))))
    ;; Review fix wave (Critical): arm 3, arm 5, and arm 6 above were each
    ;; classified SUBSUMED by a whole-FAIL-record subset test alone (a
    ;; mutant's failure set was a full subset of a sibling's), which AGENTS.md
    ;; warns reports "separable but deliberately declined" as clean too --
    ;; count-not-witness is the fix that shape needs, precedented by
    ;; verify-tests.sps's own "both EOF terminals reported" and "three pairs"
    ;; checks above. Each case below puts at least TWO independent occurrences
    ;; of one decision in a single machine -- one on a byte-dispatch node
    ;; (which the competing broader mutation ALSO breaks, so the count drops
    ;; by the byte-dispatch contribution too) and one on a sequence node
    ;; reached only through the arm's own mechanism (which only the arm's
    ;; narrower mutation breaks) -- so the two mutations report different
    ;; "got" values on the same check. Measured directly against both mutants,
    ;; not predicted; see SchemeMutationSuite.cmake's arms 3/5/6 for the
    ;; sweep. Slice ③ Task 2 added a THIRD occurrence to the first case below
    ;; -- 'seq itself, once the REPORT set saw it (§25:1533) -- so that one
    ;; separates three mutations rather than two; its own table says which.
    (harness-case "a byte-dispatch self-loop, a dispatch-through-sequence cycle and the sequence node itself are three zero-progress cycles"
      (lambda ()
        ;; Count-don't-witness, and Slice ③ makes it four-way. Measured against
        ;; this one check:
        ;;   correct code                                       -> 3
        ;;   PASS 5's REPORT guard loses its sequence clause     -> 2
        ;;   reexec-targets loses its sequence arm (arm 3)       -> 1
        ;;   PASS 5's report conditional replaced by (if #f      -> 0
        ;; 'x's case and fallback both reexecute into itself, a decision only
        ;; the last of those touches; 'start -> 'seq -> 'start is the cycle the
        ;; walk must see THROUGH; and 'seq itself is what Slice ③ added to the
        ;; REPORTED set.
        (check-equal "zero-progress-cycle count"
                     (length (filter (lambda (c) (eq? c 'zero-progress-cycle))
                                     (codes
                                      (make-machine 'combined3 'x '() '() '() errs
                                        (list (make-byte-dispatch-node 'x
                                                (list (make-byte-case (make-exact-byte-matcher 0)
                                                                      (make-edge 'x 'reexecute) #f))
                                                (make-edge 'x 'reexecute) #f #f)
                                              (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                                              (make-edge 'seq 'reexecute) #f))
                                                        (make-edge 'seq 'reexecute))
                                              (seq-node (one-alt '(1 2) 'stop) (make-edge 'start 'reexecute) #f)
                                              (make-stop-node 'stop #f)
                                              (make-error-node 'reject 'rejected #f))
                                        'default-eof #f))))
                     3)))
    (harness-case "a byte-dispatch eof self-loop and a two-node dispatch/sequence eof cycle are three eof-zero-progress cycles"
      (lambda ()
        ;; arm 5 (eof-terminal's sequence clause) vs "verify: an eof-target
        ;; cycle is classified as a finish terminal" (mut19): 'x's own
        ;; eof-target chain cycles through itself without ever touching a
        ;; sequence node, a decision arm 5 never reaches. 'start <-> 'seq is
        ;; the SAME two-node cycle as arm 5's own "an eof chain that cycles
        ;; from a dispatch node through a sequence node's own eof-target"
        ;; case above; under correct code BOTH nodes' own eof-target-chain
        ;; walks find the cycle, so this pair alone contributes 2. A
        ;; self-loop entirely at the sequence node (arm 5's OTHER own case,
        ;; and arm 7's fixture) was tried here first and rejected: it does
        ;; not separate arm 5 from arm 7, because a walk that starts AND ends
        ;; at the sequence node without ever passing through a byte-dispatch
        ;; node is killed identically by either mutation (measured: both
        ;; reported "got 1" on that design). The 'start/'seq pair is entered
        ;; from a byte-dispatch node's own eof-target, which only arm 5's
        ;; inner eof-terminal change touches -- arm 7's outer-filter change
        ;; is irrelevant to a chain that never STARTS at the sequence node.
        ;; Measured: correct code reports 3; mut19 disables eof-terminal's
        ;; cycle guard globally, reporting 0; arm 5 still finds 'x's own
        ;; cycle but every walk that must pass through 'seq now returns
        ;; 'unknown, reporting 1; arm 7 (measured as a control, not just
        ;; mut19) still finds 'x's cycle and 'start's own eof-target-chain
        ;; walk (arm 7 never touches eof-terminal, and 'start stays in the
        ;; :909 outer filter under arm 7's mutation), losing only 'seq's own
        ;; entry, reporting 2 -- three distinct "got" values, so this check
        ;; also happens to separate arm 5 from arm 7 as a byproduct.
        (check-equal "eof-zero-progress-cycle count"
                     (length (filter (lambda (c) (eq? c 'eof-zero-progress-cycle))
                                     (codes
                                      (make-machine 'combined5 'start '() '() '() errs
                                        (list (make-byte-dispatch-node 'x '()
                                                (make-edge 'reject 'reexecute) 'x #f)
                                              (make-byte-dispatch-node 'start (list accept-case)
                                                (make-edge 'reject 'reexecute) 'seq #f)
                                              (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) 'start)
                                              (make-stop-node 'stop #f)
                                              (make-error-node 'reject 'rejected #f))
                                        'default-eof #f))))
                     3)))
    (harness-case "a byte case and a sequence case both into a finish terminal are two non-eof-into-finish diagnostics"
      (lambda ()
        ;; arm 6 (the :908 outer filter's sequence disjunct) vs "verify: a
        ;; byte edge into a finish terminal is accepted" (mut17): 's0's own
        ;; byte case into 'done is the decision mut17's own case above
        ;; witnesses by existence and arm 6 never touches (byte-dispatch
        ;; nodes stay in the :908 filter under arm 6's mutation); 'seq's own
        ;; case into 'done is arm 6's own case above. Correct code reports 2;
        ;; mut17 disables the shared finish-check for every node kind,
        ;; reporting 0; arm 6 narrows the filter to byte-dispatch only, so
        ;; 's0 still reports but 'seq no longer does, reporting 1.
        ;;
        ;; Measured NOT to separate arm 6 from "verify: a sequence node's
        ;; case and mismatch targets are not out-targets" (arm 1): arm 1
        ;; empties node-out-targets for every sequence node, which starves
        ;; THIS check's :908 loop identically to arm 6's own narrower filter
        ;; -- both report 1 here, and every other record this case's fixture
        ;; could produce is one arm 6 never reaches either (arm 1's own extra
        ;; failures -- the well-formed-machine, both missing-target, and the
        ;; unreachable-node checks above -- come from node-out-targets being
        ;; used elsewhere in the pass, which arm 6 does not touch). Left
        ;; genuinely subsumed on that side; see the mutation suite's arm 6
        ;; comment for the exhaustive measurement.
        (check-equal "non-eof-into-finish count"
                     (length (filter (lambda (c) (eq? c 'non-eof-into-finish))
                                     (codes
                                      (make-machine 'combined6 's0 '() '() '() errs
                                        (list (make-byte-dispatch-node 's0
                                                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'done 'advance) #f))
                                                (make-edge 'reject 'reexecute) #f #f)
                                              (seq-node (one-alt '(1 2) 'done) (make-edge 'reject 'reexecute) #f)
                                              (make-finish-node 'done #f)
                                              (make-error-node 'reject 'rejected #f))
                                        'default-eof #f))))
                     2)))))

;; Milestone 3 Slice ③ Task 1: §16.2:894 sequence ambiguity. One alternative
;; being a terminal prefix of another is UNREPRESENTABLE (decision 0015 point
;; 2: a prefix state has no "accept here" slot), so it is rejected here rather
;; than left to the normalizer's internal guard. Duplicate alternatives are the
;; maximal case of the same relation -- `AB` is a terminal prefix of `AB` -- so
;; both shapes carry the one code design §4.5 allows. Reported once per
;; colliding PAIR, like pass-overlap (§16.4:937-943).
(define (amb-machine name alts extra-nodes)
  (make-machine name 'seq '() '() '() errs
    (append (list (make-sequence-dispatch-node 'seq
                    (map (lambda (a) (make-sequence-case (car a) (cdr a) #f)) alts)
                    (make-edge 'reject 'reexecute) #f #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            extra-nodes)
    'default-eof #f))
(define two-more (list (make-stop-node 'halt #f) (make-stop-node 'done #f)))
(define three-more (append two-more (list (make-stop-node 'more #f))))
;; Counters read the OBSERVED diagnostic list, never the fixture's own shape.
(define (ambiguity-count m)
  (length (filter (lambda (c) (eq? c 'ambiguous-sequence-prefix)) (codes m))))
(define nested-short-first
  (amb-machine 'nest '(((65) . stop) ((65 66) . halt) ((65 66 67) . done)) two-more))
(define nested-long-first
  (amb-machine 'nest-rev '(((65 66 67) . done) ((65 66) . halt) ((65) . stop)) two-more))

(harness-group "sequence ambiguity (§16.2:894)"
  (lambda ()
    (harness-case "an alternative that is a terminal prefix of another is rejected"
      (lambda ()
        (let ((m (amb-machine 'amb '(((65 66) . stop) ((65 66 67) . halt))
                              (list (make-stop-node 'halt #f)))))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "ambiguous-sequence-prefix" (has-code? m 'ambiguous-sequence-prefix)))))
    (harness-case "two identical alternatives are the maximal case of the same relation"
      (lambda ()
        (let ((m (amb-machine 'dup '(((65 66) . stop) ((65 66) . halt))
                              (list (make-stop-node 'halt #f)))))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "ambiguous-sequence-prefix" (has-code? m 'ambiguous-sequence-prefix)))))
    ;; The count fixtures. SUMMED over both declaration orders, deliberately:
    ;; a short-first list is caught by a one-directional test as well as by a
    ;; correct one, so a per-ordering check leaves the one-directional
    ;; mutation's whole failure set inside the never-run mutation's -- the
    ;; subsumed shape AGENTS.md names. The sum separates them (6 / 3 / 0).
    (harness-case "the prefix test asks both directions, counted over both declaration orders"
      (lambda ()
        (check-equal "ambiguity count over both orderings"
                     (+ (ambiguity-count nested-short-first)
                        (ambiguity-count nested-long-first))
                     6)))
    ;; The over-rejection direction, which nothing else in this file tests: a
    ;; SHARED first byte is not ambiguity (§10.6:544 permits shared nonterminal
    ;; prefixes; the trie merges them), and a check that cannot tell the two
    ;; apart would reject every branching machine this slice ships.
    (harness-case "alternatives that merely share a prefix are not ambiguous"
      (lambda ()
        (check-equal "ambiguity count"
                     (ambiguity-count
                      (amb-machine 'ok '(((65 66) . stop) ((65 67) . halt) ((88 89) . done))
                                   two-more))
                     0)))
    ;; The pair ENUMERATION, mirroring pass-overlap's own three enumeration
    ;; mutations. A nested family of three (3 pairs) plus a disjoint pair
    ;; (1 pair) = 4; the three ways to break the walk give 2, 3 and 9, all
    ;; distinct and all distinct from the two mutations above.
    (harness-case "every pair is enumerated once, across a nested family and a disjoint one"
      (lambda ()
        (check-equal "ambiguity count"
                     (ambiguity-count
                      (amb-machine 'fam '(((65) . stop) ((65 66) . halt) ((65 66 67) . done)
                                          ((88) . more) ((88 89) . stop))
                                   three-more))
                     4)))
    (harness-case "a byte-dispatch machine contributes no sequence ambiguity"
      (lambda ()
        (check-equal "ambiguity count"
                     (ambiguity-count (machine (one-byte-nodes (make-edge 'reject 'reexecute))))
                     0)))))

(harness-finish)
