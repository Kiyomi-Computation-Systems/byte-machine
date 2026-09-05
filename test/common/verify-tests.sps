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
                  ;; *** Slice ⓪b: `seq` needs an inbound BYTE case. *** The EOF
                  ;; walk now starts only from states a parser can be parked on,
                  ;; and `seq` was reachable from nowhere -- so its self-cycling
                  ;; eof-target is unreachable and correctly no longer reported.
                  ;; The case's intent is that a cycle THROUGH A SEQUENCE NODE is
                  ;; caught, so the sequence node is made reachable rather than
                  ;; the expectation weakened.
                  (list (dispatch (list accept-case
                                        (make-byte-case (make-exact-byte-matcher 7)
                                                        (make-edge 'seq 'advance) #f))
                                  (make-edge 'reject 'reexecute))
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
                                              ;; *** Slice ⓪b: `x` and `seq` need inbound BYTE
                                              ;; cases. *** The EOF walk now starts only from
                                              ;; states a parser can be parked on. `x` was
                                              ;; reachable from nowhere and `seq` only as an
                                              ;; eof-target, so neither started a walk and the
                                              ;; count fell to 1. Both are made byte-reachable,
                                              ;; which keeps all THREE findings and the case's
                                              ;; full discriminating power, rather than lowering
                                              ;; the expectation to match the new rule.
                                              (make-byte-dispatch-node 'start
                                                (list accept-case
                                                      (make-byte-case (make-exact-byte-matcher 7)
                                                                      (make-edge 'x 'advance) #f)
                                                      (make-byte-case (make-exact-byte-matcher 8)
                                                                      (make-edge 'seq 'advance) #f))
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
                                                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'done 'advance) #f)
                                                      ;; *** Slice ⓪b: `seq` needs its own inbound
                                                      ;; byte case. *** §16.2:908 is now gated on
                                                      ;; byte-reachability, and `seq` was reachable
                                                      ;; from nowhere -- so its edge into `done` is
                                                      ;; untakeable and correctly no longer reported.
                                                      ;; This case's INTENT is two findings from two
                                                      ;; different source nodes, and that intent is
                                                      ;; preserved by making the second source real
                                                      ;; rather than by lowering the expected count.
                                                      (make-byte-case (make-exact-byte-matcher 2) (make-edge 'seq 'advance) #f))
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


;; Milestone 4 Slice ② task 2: the eof-terminal rewrite (§4.4, decision 0021).
;;
;; *** These cases could not have been written before task 1. *** Every kind
;; shipped before this slice is SINGLE-successor, so none can witness a join, a
;; re-converging diamond, or the completed-set. That is why tasks 1 and 2 are
;; swapped relative to the plan, which ordered the rewrite first "so its own
;; tests are written against shipped kinds".
;;
;; Each machine routes its entry dispatch's eof-target into a field branch, so
;; the :909 walk reaches the multi-successor node. The field kinds are not yet
;; taught to the other passes (that is task 3), so these machines carry unrelated
;; diagnostics too -- every assertion is therefore about the PRESENCE or ABSENCE
;; of one code, never about a total count.
(define (eof-into fa-nodes)
  (make-machine 'm 'start '() '() '() (list eof-decl rej-decl)
    (append (list (make-byte-dispatch-node 'start
                    (list (make-byte-case (make-exact-byte-matcher 0)
                                          (make-edge 'stop 'advance) #f))
                    (make-edge 'reject 'reexecute) 'br #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            fa-nodes)
    'default-eof #f))

(harness-group "the EOF walk over multi-successor zero-width nodes (§4.4, 0021)"
  (lambda ()
    (harness-case "both arms reaching a finish is not a cycle and not a stop"
      (lambda ()
        (let ((cs (codes (eof-into (list (make-field-branch-node 'br 'zero '(count) 'f1 'f2 #f)
                                         (make-finish-node 'f1 #f)
                                         (make-finish-node 'f2 #f))))))
          (check "no cycle" (not (memq 'eof-zero-progress-cycle cs)))
          (check "no reachable stop" (not (memq 'eof-reachable-stop cs))))))
    (harness-case "a DIAMOND that re-converges is not a cycle"
      (lambda ()
        ;; The defect the rejected algorithm has: one shared `seen` that
        ;; tolerates re-visits reports 'cycle for a diamond that merely
        ;; re-converges. Both arms reach the SAME finish node here, so the walk
        ;; meets `f1` twice.
        (let ((cs (codes (eof-into (list (make-field-branch-node 'br 'zero '(count) 'a 'b #f)
                                         (make-field-action-node 'a 'clear '(count) 'f1 #f #f)
                                         (make-field-action-node 'b 'clear '(count) 'f1 #f #f)
                                         (make-finish-node 'f1 #f))))))
          (check "no cycle" (not (memq 'eof-zero-progress-cycle cs))))))
    (harness-case "one arm cycling is a cycle even though the other finishes"
      (lambda ()
        ;; The join has to be `max`, not "first answer" and not "all arms agree":
        ;; a branch one of whose arms genuinely cycles cannot report nothing.
        (let ((cs (codes (eof-into (list (make-field-branch-node 'br 'zero '(count) 'f1 'loop #f)
                                         (make-finish-node 'f1 #f)
                                         (make-field-action-node 'loop 'clear '(count) 'br #f #f))))))
          (check "cycle" (memq 'eof-zero-progress-cycle cs)))))
    (harness-case "cycle outranks eof-reachable-stop when the arms differ"
      (lambda ()
        ;; The ONE relation decision 0021 item 1 pins in the source, and the only
        ;; place two verdicts can now meet.
        (let ((cs (codes (eof-into (list (make-field-branch-node 'br 'zero '(count) 'stop 'loop #f)
                                         (make-field-action-node 'loop 'clear '(count) 'br #f #f))))))
          (check "cycle" (memq 'eof-zero-progress-cycle cs))
          (check "and not the stop" (not (memq 'eof-reachable-stop cs))))))
    (harness-case "cycle outranks eof-reachable-stop in the OTHER arm order too"
      (lambda ()
        ;; The mirror of the case above, and not redundant with it: a mutant that
        ;; walks only the TRUE arm answers correctly here (the cycle IS the true
        ;; arm) and wrongly there, so this pair is what separates "the join uses
        ;; the wrong order" from "the second arm is never walked at all". Without
        ;; it those two mutants are indistinguishable.
        (let ((cs (codes (eof-into (list (make-field-branch-node 'br 'zero '(count) 'loop 'stop #f)
                                         (make-field-action-node 'loop 'clear '(count) 'br #f #f))))))
          (check "cycle" (memq 'eof-zero-progress-cycle cs))
          (check "and not the stop" (not (memq 'eof-reachable-stop cs))))))
    (harness-case "an arm reaching a stop is eof-reachable-stop when no arm cycles"
      (lambda ()
        ;; The premise for the case above: without it, "not the stop" would pass
        ;; because this walk never reports a stop through a branch at all.
        (let ((cs (codes (eof-into (list (make-field-branch-node 'br 'zero '(count) 'stop 'f1 #f)
                                         (make-finish-node 'f1 #f))))))
          (check "reachable stop" (memq 'eof-reachable-stop cs)))))
    (harness-case "a field action's error target is walked too"
      (lambda ()
        ;; `next` PLUS `error` -- a field action is multi-successor as well, and
        ;; a walk that followed only `next` would miss a stop behind a failure.
        (let ((cs (codes (eof-into (list (make-field-action-node 'br 'increment '(count) 'f1 'stop #f)
                                         (make-finish-node 'f1 #f))))))
          (check "reachable stop" (memq 'eof-reachable-stop cs)))))))


;; Milestone 4 Slice ② task 3: the verifier census. Every site that switches on
;; node kind and must learn the two zero-width kinds.
;;
;; *** Census row 14 (D4(d)) is DELIBERATELY NOT EXTENDED, and the last case
;; here is what holds that decision. *** The design prescribed a
;; byte-reachability-gated sibling block "same shape" as the pause one. Written
;; that way it turns `dispatch --advance--> field-action --next--> stop` into a
;; false eof-reachable-stop. A pause IS an EOF start -- parser-feed-op!'s pause
;; arm commits `current` PAST it, so a later finish begins at the continuation --
;; whereas a zero-width node never becomes `current`, because the dispatch arm
;; returns need-input without moving it. Row 10's eof-terminal extension plus
;; the shipped pause block already cover every real EOF start. The one stated,
;; witnessed gap is "the machine ENTRY is a zero-width node", which no shipped
;; fixture can reach today.
(define (fields1) (list (make-uint-field 'count 8 0 #f)))
(define (zw-machine nodes entry)
  (make-machine 'm entry (fields1) '() '() (list eof-decl rej-decl) nodes 'default-eof #f))

(harness-group "the zero-width census (Slice ② task 3)"
  (lambda ()
    (harness-case "a zero-width self-cycle is a zero-progress cycle"
      (lambda ()
        ;; The failure this closes: without BOTH the walk and the REPORT set,
        ;; a `store`-into-itself machine verifies clean and then hangs in both
        ;; lanes. The walk alone is the half-fix M3 Slice ② shipped.
        (let ((cs (codes (zw-machine
                          (list (make-field-action-node 'loop 'clear '(count) 'loop #f #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'reject 'rejected #f))
                          'loop))))
          (check "zero-progress-cycle" (memq 'zero-progress-cycle cs)))))
    (harness-case "a two-node zero-width cycle through a branch is reported too"
      (lambda ()
        (let ((cs (codes (zw-machine
                          (list (make-field-branch-node 'br 'zero '(count) 'act 'act #f)
                                (make-field-action-node 'act 'clear '(count) 'br #f #f)
                                (make-error-node 'reject 'rejected #f))
                          'br))))
          (check "zero-progress-cycle" (memq 'zero-progress-cycle cs)))))
    (harness-case "a zero-width node's targets are out-targets, so they are reachable"
      (lambda ()
        ;; node-out-targets feeds name resolution AND reachability. Without the
        ;; arm, `after` is unreached and `oops` is unreached, and the machine is
        ;; rejected for a defect it does not have.
        (let ((cs (codes (zw-machine
                          ;; No spare node: an error node nothing names is
                          ;; unreachable on its own account and would make this
                          ;; case pass for the wrong reason.
                          (list (make-field-action-node 'act 'increment '(count) 'after 'oops #f)
                                (make-stop-node 'after #f)
                                (make-error-node 'oops 'rejected #f))
                          'act))))
          (check "nothing unreachable" (not (memq 'unreachable-node cs))))))
    (harness-case "a byte-reachable zero-width node into a finish is non-eof-into-finish"
      (lambda ()
        ;; §16.2:908 forbids non-EOF control flow into a finish terminal, and a
        ;; byte path that runs dispatch -> field-action -> finish is exactly
        ;; that. The shipped :908 check cannot see it: it filters on dispatch
        ;; kinds, so the finish sits one hop further than it looks.
        (let ((cs (codes (zw-machine
                          (list (make-byte-dispatch-node 'start
                                  (list (make-byte-case (make-exact-byte-matcher 0)
                                                        (make-edge 'act 'advance) #f))
                                  (make-edge 'reject 'reexecute) #f #f)
                                (make-field-action-node 'act 'clear '(count) 'done #f #f)
                                (make-finish-node 'done #f)
                                (make-error-node 'reject 'rejected #f))
                          'start))))
          (check "non-eof-into-finish" (memq 'non-eof-into-finish cs)))))
    (harness-case "a cycle running THROUGH a zero-width node is attributed to the dispatch"
      (lambda ()
        ;; This fixture is what separates "the WALK does not follow a zero-width
        ;; node" from "the REPORT set does not include one". The cycle's reported
        ;; member is the byte-dispatch node, which is in the report set either
        ;; way -- so narrowing the report set leaves this diagnostic standing,
        ;; while narrowing the walk removes it. Without this case the two mutants
        ;; emit identical records, which is the half-fix M3 Slice ② shipped and
        ;; Slice ③ closed.
        (let ((ds (verification-diagnostics
                   (verify-machine
                    (zw-machine
                     (list (make-byte-dispatch-node 'start
                             (list (make-byte-case (make-exact-byte-matcher 0)
                                                   (make-edge 'stop 'advance) #f))
                             (make-edge 'act 'reexecute) #f #f)
                           (make-field-action-node 'act 'clear '(count) 'start #f #f)
                           (make-stop-node 'stop #f))
                     'start)))))
          (check "attributed to start"
                 (memq 'start (map diagnostic-node
                                   (filter (lambda (d)
                                             (eq? (diagnostic-code d) 'zero-progress-cycle))
                                           ds)))))))
    (harness-case "an EOF-only-reachable zero-width node may continue into a finish"
      (lambda ()
        ;; Decision 0011 for the pause kind, applied here: §16.2:908 forbids
        ;; NON-EOF control flow into a finish, so a zero-width node reached only
        ;; along an EOF path legally continues into one. This is what the
        ;; byte-reachability GATE buys -- without the gate the check fires on
        ;; every zero-width node regardless of how it is reached, and this
        ;; machine is rejected for a defect it does not have.
        (let ((cs (codes (zw-machine
                          (list (make-byte-dispatch-node 'start
                                  (list (make-byte-case (make-exact-byte-matcher 0)
                                                        (make-edge 'stop 'advance) #f))
                                  (make-edge 'reject 'reexecute) 'act #f)
                                (make-field-action-node 'act 'clear '(count) 'done #f #f)
                                (make-finish-node 'done #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'reject 'rejected #f))
                          'start))))
          (check "no non-eof-into-finish" (not (memq 'non-eof-into-finish cs))))))
    (harness-case "a byte path through a zero-width node into a STOP verifies clean"
      (lambda ()
        ;; *** The case that holds row 14's drop. *** Written "same shape" as the
        ;; pause block, the prescribed sibling would report eof-reachable-stop
        ;; here -- on a diagnostic and message about EOF, for a machine whose
        ;; only path to that stop is a byte path. If a later slice adds that
        ;; block, this case fails, which is the point.
        (let ((cs (codes (zw-machine
                          (list (make-byte-dispatch-node 'start
                                  (list (make-byte-case (make-exact-byte-matcher 0)
                                                        (make-edge 'act 'advance) #f))
                                  (make-edge 'reject 'reexecute) #f #f)
                                (make-field-action-node 'act 'clear '(count) 'stop #f #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'reject 'rejected #f))
                          'start))))
          (check "no eof-reachable-stop" (not (memq 'eof-reachable-stop cs)))
          (check "no eof cycle" (not (memq 'eof-zero-progress-cycle cs)))
          (check "no non-eof-into-finish" (not (memq 'non-eof-into-finish cs))))))))


;; Milestone 4 Slice ② task 4: pass-fields' OPERAND half (§16.3:924 item 6,
;; decision 0020 item 3). Everything here needs a SECOND object -- the field
;; declaration -- which is exactly why none of it is a constructor contract, and
;; why the constructor accepts every one of these nodes.
(define (operand-machine node)
  (make-machine 'm 'act (list (make-uint-field 'count 8 0 #f)) '() '()
                (list eof-decl rej-decl)
                (list node (make-stop-node 'next #f) (make-error-node 'oops 'rejected #f))
                'default-eof #f))
(define (operand-codes node)
  (filter (lambda (c) (eq? c 'invalid-field-operand)) (codes (operand-machine node))))

(harness-group "field operands (§16.3:924 item 6, operand half)"
  (lambda ()
    (harness-case "a well-formed operand list is clean"
      (lambda ()
        ;; The premise for every case below: without it they could all pass
        ;; because ANY field node reports an operand fault.
        (check-equal "none" (length (operand-codes
                                     (make-field-action-node 'act 'store '(count 255) 'next #f #f)))
                     0)))
    (harness-case "wrong arity is invalid-field-operand"
      (lambda ()
        ;; The check the CONSTRUCTOR deliberately does not make -- 0020 item 2:
        ;; nothing can be read out of `arguments` before arity is known.
        (check-equal "too few" (length (operand-codes
                                        (make-field-action-node 'act 'store '(count) 'next #f #f)))
                     1)
        (check-equal "too many" (length (operand-codes
                                         (make-field-action-node 'act 'clear '(count 1) 'next #f #f)))
                     1)))
    (harness-case "an undeclared field is invalid-field-operand"
      (lambda ()
        (check-equal "one" (length (operand-codes
                                    (make-field-action-node 'act 'clear '(nosuch) 'next #f #f)))
                     1)))
    (harness-case "a constant above the field's declared width is invalid-field-operand"
      (lambda ()
        ;; 255 is the u8 maximum and is accepted by the premise case above; 256
        ;; is the first value that is not, so this pins the BOUNDARY and not
        ;; merely that some large number is refused.
        (check-equal "256" (length (operand-codes
                                    (make-field-action-node 'act 'store '(count 256) 'next #f #f)))
                     1)))
    (harness-case "a mask above the declared width is invalid-field-operand"
      (lambda ()
        (check-equal "one" (length (operand-codes
                                    (make-field-action-node 'act 'set-mask '(count 256) 'next #f #f)))
                     1)))
    (harness-case "the width checked is the REFERENCED field's, not some other field's"
      (lambda ()
        ;; Two fields of different widths: 256 is legal for `wide` and not for
        ;; `count`. A check that used the first declaration, or any fixed width,
        ;; passes the cases above and fails here.
        (let* ((m (make-machine 'm 'act
                                (list (make-uint-field 'count 8 0 #f)
                                      (make-uint-field 'wide 16 0 #f))
                                '() '() (list eof-decl rej-decl)
                                (list (make-field-action-node 'act 'store '(wide 256) 'next #f #f)
                                      (make-stop-node 'next #f))
                                'default-eof #f))
               (cs (filter (lambda (c) (eq? c 'invalid-field-operand)) (codes m))))
          (check-equal "legal for the wide field" (length cs) 0))))
    (harness-case "low > high for range is invalid-field-operand"
      (lambda ()
        ;; Decision 0020 item 2 names this as the consequence that will look
        ;; wrong to a reader of 0017. The constructor accepts it -- asserted in
        ;; ir-tests.sps -- and the verifier is where it is caught.
        (check-equal "one" (length (operand-codes
                                    (make-field-branch-node 'act 'range '(count 9 2) 'next 'next #f)))
                     1)))
    (harness-case "low = high for range is legal"
      (lambda ()
        ;; The boundary: the check is `low > high`, not `low >= high`.
        (check-equal "none" (length (operand-codes
                                     (make-field-branch-node 'act 'range '(count 5 5) 'next 'next #f)))
                     0)))
    (harness-case "an out-of-width range operand does not also report low > high"
      (lambda ()
        ;; A range whose operands are out of width would compare garbage; the
        ;; low/high check is guarded on both being in range, so this reports the
        ;; width fault once per bad operand and nothing else.
        (check-equal "two width faults only"
                     (length (operand-codes
                              (make-field-branch-node 'act 'range '(count 300 299) 'next 'next #f)))
                     2)))
    (harness-case "every predicate's arity is enforced"
      (lambda ()
        ;; A loop with a sentinel over the observed count: the schema table is a
        ;; closed enumeration, and naming three rows does not assert fourteen.
        (let ((seen 0))
          (for-each (lambda (row)
                      (set! seen (+ seen 1))
                      (check-equal (symbol->string (car row))
                                   (length (operand-codes
                                            (make-field-branch-node 'act (car row) (cadr row)
                                                                    'next 'next #f)))
                                   1))
                    '((equal (count)) (zero (count 1)) (nonzero (count 1))
                      (range (count 1)) (mask-any (count)) (mask-all (count))
                      (mask-none (count))))
          (check-equal "all seven predicates" seen 7))))))


;; Milestone 4 Slice ③ task 2: the verifier census for the INPUT-READING kind.
;;
;; *** The two self-cycles need SEPARATE fixtures. *** Design §8 says only
;; `nondigit-edge` can be `reexecute` "since the overflow edge is non-consuming
;; but terminal-directed" -- it is not, and §8 contradicts itself sixteen lines
;; later. §12.7:772 makes the overflow non-consuming and §15:870 leaves the field
;; unchanged, so an `overflow-error` naming its own node re-reads the same byte
;; forever with no cycle guard in either runtime loop. Measured before this was
;; written: cutting Slice ②'s field-action arm to one disjunct makes a
;; self-targeting error edge verify with ZERO diagnostics.
;;
;; Neither fixture distinguishes the other's mutant, which is exactly why there
;; are two: a walk that takes only the nondigit disjunct passes the first and
;; fails the second, and the REPORT-guard bullet has the same blind spot.
(define (acc-machine nodes entry)
  (make-machine 'm entry (list (make-uint-field 'count 8 0 #f)) '() '()
                (list eof-decl rej-decl) nodes 'default-eof #f))

(harness-group "the input-reading kind in the verifier census (Slice ③)"
  (lambda ()
    (harness-case "an accumulate whose NONDIGIT edge reexecutes into itself is a zero-progress cycle"
      (lambda ()
        (let ((cs (codes (acc-machine
                          (list (make-integer-accumulate-node 'acc 'count 10 'stop
                                                              (make-edge 'acc 'reexecute)
                                                              'over #f #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'over 'rejected #f))
                          'acc))))
          (check "zero-progress-cycle" (memq 'zero-progress-cycle cs)))))
    (harness-case "an accumulate whose OVERFLOW edge targets itself is a zero-progress cycle"
      (lambda ()
        ;; The fixture design §8 would have shipped without. The overflow edge
        ;; consumes nothing, so this loops forever -- and a walk taking only the
        ;; nondigit disjunct reports NOTHING here while passing the case above.
        (let ((cs (codes (acc-machine
                          (list (make-integer-accumulate-node 'acc 'count 10 'stop
                                                              (make-edge 'stop 'advance)
                                                              'acc #f #f)
                                (make-stop-node 'stop #f))
                          'acc))))
          (check "zero-progress-cycle" (memq 'zero-progress-cycle cs)))))
    (harness-case "an accumulate whose nondigit edge ADVANCES out is not a cycle"
      (lambda ()
        ;; The premise for both: without it they could pass because ANY
        ;; accumulate machine reports a cycle.
        (let ((cs (codes (acc-machine
                          (list (make-integer-accumulate-node 'acc 'count 10 'acc
                                                              (make-edge 'stop 'advance)
                                                              'over #f #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'over 'rejected #f))
                          'acc))))
          (check "no cycle" (not (memq 'zero-progress-cycle cs))))))
    (harness-case "the DIGIT edge self-targeting is not a cycle -- it advances"
      (lambda ()
        ;; §10.6:566: the digit edge always advances, so an accumulate node
        ;; looping on digits makes progress and must not be reported. The case
        ;; above already has digit-target = acc; this states it as the decision
        ;; it is, so a walk that wrongly added the digit disjunct fails here.
        (let ((cs (codes (acc-machine
                          (list (make-integer-accumulate-node 'acc 'count 10 'acc
                                                              (make-edge 'stop 'reexecute)
                                                              'over #f #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'over 'rejected #f))
                          'acc))))
          (check "no cycle" (not (memq 'zero-progress-cycle cs))))))
    (harness-case "an accumulate's three byte targets are out-targets, so they are reachable"
      (lambda ()
        (let ((cs (codes (acc-machine
                          (list (make-integer-accumulate-node 'acc 'count 10 'more
                                                              (make-edge 'stop 'advance)
                                                              'over #f #f)
                                (make-stop-node 'more #f) (make-stop-node 'stop #f)
                                (make-error-node 'over 'rejected #f))
                          'acc))))
          (check "nothing unreachable" (not (memq 'unreachable-node cs))))))
    (harness-case "an accumulate naming no declared field is invalid-field-operand"
      (lambda ()
        ;; D3's sibling arm. Reported under the NODE's name, matching the
        ;; operand walk's own convention.
        (let ((ds (verification-diagnostics
                   (verify-machine
                    (acc-machine
                     (list (make-integer-accumulate-node 'acc 'nosuch 10 'stop
                                                         (make-edge 'stop 'advance)
                                                         'over #f #f)
                           (make-stop-node 'stop #f)
                           (make-error-node 'over 'rejected #f))
                     'acc)))))
          (check "invalid-field-operand"
                 (memq 'invalid-field-operand (map diagnostic-code ds)))
          (check "named by the NODE"
                 (memq 'acc (map diagnostic-node
                                 (filter (lambda (d)
                                           (eq? (diagnostic-code d) 'invalid-field-operand))
                                         ds)))))))
    (harness-case "an accumulate naming a declared field is clean"
      (lambda ()
        (let ((cs (codes (acc-machine
                          (list (make-integer-accumulate-node 'acc 'count 10 'stop
                                                              (make-edge 'stop 'advance)
                                                              'over #f #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'over 'rejected #f))
                          'acc))))
          (check "no operand fault" (not (memq 'invalid-field-operand cs))))))))

;; *** Whole-branch review, 2026-09-03: THREE kind filters Slice ③ did not widen.
;; *** The slice taught `node-eof-target` and `node-out-targets` about the
;; accumulate kind and stopped there. `eof-terminal`'s `classify` and both of
;; `pass-eof-execution`'s filters still enumerated their kinds by hand, so an
;; accumulate node was invisible to all three -- and every fixture above misses
;; it by construction, because each declares `eof-target #f` and makes `acc` the
;; entry, so no EOF chain in this file ever walks into one.
;;
;; This is the milestone's own lesson arriving a third time: a sweep re-judges
;; the pins that exist and cannot notice a decision no pin names. The group below
;; is one case per filter, and each is a machine both executors already ran
;; correctly while the verifier either raised or waved it through.
(define (acc-eof-machine acc-eof digit-target extra-nodes)
  ;; The entry dispatch declares NO eof-target, so the accumulate node's own is
  ;; the only one in the machine -- which is what makes these cases about the
  ;; accumulate arm rather than about the dispatch arm beside it.
  (acc-machine
   (append
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 35)
                                  (make-edge 'acc 'advance) #f))
            (make-edge 'over 'reexecute) #f #f)
          (make-integer-accumulate-node 'acc 'count 10 digit-target
                                        (make-edge 'stop 'advance)
                                        'over acc-eof #f)
          (make-stop-node 'stop #f)
          (make-error-node 'over 'rejected #f))
    extra-nodes)
   'start))

(harness-group "the three kind filters an accumulate node was invisible to (Slice ③)"
  (lambda ()
    (harness-case "an EOF chain may reach an accumulate node at all"
      (lambda ()
        ;; The `classify` arm. Before it, this RAISED out of verification --
        ;; `verify-machine` never returned, so the machine had no verdict rather
        ;; than a bad one, and `compile-machine` raised with it. Asserted as a
        ;; clean verdict because the machine IS legal: both lanes already ran it.
        (let* ((m (acc-machine
                   (list (make-byte-dispatch-node 'start
                           (list (make-byte-case (make-exact-byte-matcher 35)
                                                 (make-edge 'acc 'advance) #f))
                           (make-edge 'over 'reexecute) 'acc #f)
                         (make-integer-accumulate-node 'acc 'count 10 'acc
                                                       (make-edge 'stop 'advance)
                                                       'over 'fin #f)
                         (make-finish-node 'fin #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'over 'rejected #f))
                   'start))
               (v (verify-machine m)))
          (check "returns a verdict rather than raising" (verification-ok? v))
          (check-equal "with no diagnostics" (length (verification-diagnostics v)) 0))))
    (harness-case "an accumulate whose own EOF target is itself is an EOF zero-progress cycle"
      (lambda ()
        ;; §16.2:909. This is the worst of the three: `parser-finish-op!` says in
        ;; its own comment that it carries no local cycle guard because it relies
        ;; on this check, so before the fix this machine verified with ZERO
        ;; diagnostics and then looped forever in BOTH executors.
        (let ((cs (codes (acc-eof-machine 'acc 'acc '()))))
          (check "eof-zero-progress-cycle" (memq 'eof-zero-progress-cycle cs)))))
    (harness-case "an accumulate whose own EOF chain reaches a stop terminal is rejected"
      (lambda ()
        ;; The other half of the same filter, and a different verdict: the walk
        ;; must classify the chain, not merely detect that it cycles.
        (let ((cs (codes (acc-eof-machine 'stop 'acc '()))))
          (check "eof-reachable-stop" (memq 'eof-reachable-stop cs)))))
    (harness-case "an accumulate BYTE edge into a finish terminal is rejected"
      (lambda ()
        ;; §16.2:908, and the third filter. `node-out-targets` already yielded
        ;; the accumulate node's three byte out-targets; nothing looked at them.
        ;; The digit target is used here because it is the arm a digit takes on
        ;; every accepted byte -- the least exotic of the three.
        (let ((cs (codes (acc-eof-machine #f 'fin (list (make-finish-node 'fin #f))))))
          (check "non-eof-into-finish" (memq 'non-eof-into-finish cs)))))))

;; Milestone 5 Slice ⓪ task 1: the site that reports an EOF zero-progress cycle
;; for a PAUSE continuation.
;;
;; *** Measured before this group existed: deleting that site's `((cycle) ...)`
;; clause left every runnable program in the tree byte-identical. *** It was dead
;; in the suite while being live in the code -- the only site that can see a
;; cycle which BEGINS at a pause continuation and involves no dispatch
;; eof-target at all. The other `eof-zero-progress-cycle` site attributes such a
;; cycle to a DISPATCH node; this one attributes it to the pause.
;;
;; That matters beyond bookkeeping: `parser-finish-op!` records in its own
;; comment that it carries no local cycle guard because it relies on these
;; checks. A machine of this shape verifying clean is a machine that loops
;; forever in both executors -- the same consequence Milestone 4 Slice ③'s
;; second Critical had.
;;
;; The assertion is written on the PAIR (code, node-kind), not on the count.
;; Four diagnostics are emitted today, and Slice ⓪b may reduce that: §16.4's
;; one-finding-per-decision is an open question (the §16.2:908 sites emit two or
;; three findings for one decision, and this pass may follow). The pair
;; `eof-zero-progress-cycle` AT A PAUSE NODE is what only this site can produce,
;; and it survives any de-duplication ⓪b chooses.
(define (pause-cycle-machine)
  ;; entry --advance--> p (pause) -> q (pause) -> p, and the ENTRY's own eof
  ;; route is a finish, so the dispatch arm of this check has nothing to say
  ;; and cannot be the source of the records below.
  (make-machine 'pcyc 'start '() '() '() (list eof-decl rej-decl)
                (list (make-byte-dispatch-node 'start
                        (list (make-byte-case (make-exact-byte-matcher 0)
                                              (make-edge 'p 'advance) #f))
                        (make-edge 'rej 'reexecute) 'fin #f)
                      (make-pause-node 'p 'q #f)
                      (make-pause-node 'q 'p #f)
                      (make-finish-node 'fin #f)
                      (make-error-node 'rej 'rejected #f))
                'default-eof #f))

(harness-group "an EOF cycle through pause continuations is attributed to the pause (Slice ⓪)"
  (lambda ()
    (harness-case "the machine is rejected"
      (lambda ()
        ;; Stated separately so that a later slice making this shape UNBUILDABLE
        ;; fails here and says so, rather than silently emptying the case below.
        (let ((v (verify-machine (pause-cycle-machine))))
          (check "rejected" (not (verification-ok? v)))
          (check "some diagnostic" (> (length (verification-diagnostics v)) 0)))))
    (harness-case "an eof-zero-progress-cycle is reported AT A PAUSE NODE"
      (lambda ()
        ;; The pair only this site can produce. A sentinel counts the pairs it
        ;; OBSERVES rather than trusting the diagnostic list's length, so a walk
        ;; that returned nothing cannot satisfy this vacuously.
        (let ((ds (verification-diagnostics (verify-machine (pause-cycle-machine))))
              (pause-names '(p q))
              (seen '()))
          (for-each (lambda (d)
                      (when (and (eq? (diagnostic-code d) 'eof-zero-progress-cycle)
                                 (memq (diagnostic-node d) pause-names))
                        (set! seen (cons (diagnostic-node d) seen))))
                    ds)
          (check "at least one, at a pause" (>= (length seen) 1))
          ;; And the OTHER site's attribution is absent: no dispatch node carries
          ;; this code here, which is what makes the record above this site's own.
          (check "not attributed to the dispatch"
                 (not (memq 'start
                            (map diagnostic-node
                                 (filter (lambda (d)
                                           (eq? (diagnostic-code d)
                                                'eof-zero-progress-cycle))
                                         ds))))))))))

;; Milestone 5 Slice ⓪b task 2: §16.2:908 is a rule about BYTE-REACHABILITY, and
;; the shipped verifier states it two ways that contradict each other.
;;
;; The check lives at three sites under two gating rules -- one unconditional,
;; two gated on byte-reachability. So a node reachable ONLY as an eof-target is
;; accepted when it is a pause, a field-action or a field-branch, and rejected
;; when it is a byte-dispatch, a sequence-dispatch or an integer-accumulate. The
;; byte edge is untakeable in all six.
;;
;; *** The gated reading is the correct one, and the evidence runs both ways. ***
;; Applying the unconditional reading uniformly breaks five shipped programs, and
;; the machine it refuses is `make-pause-machine` -- decision 0011's canonical
;; legal shape, an EOF-only pause continuing into a finish node, named in that
;; fixture's own header. The rule that rejects the fixture 0011 was written to
;; permit is the wrong rule.
;;
;; Decision 0021 item 5 split the kinds by "reads input" versus "zero-width", on
;; the reasoning that an input-reading node is always on the feed path. These
;; twelve machines are the counterexample: all three input-reading kinds can be
;; EOF-only-reachable.
(define (t2-hop kind)
  ;; The offender: a node of `kind` carrying a BYTE edge into the finish `fin`.
  (case kind
    ((byte-dispatch)
     (make-byte-dispatch-node 'hop
       (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'fin 'advance) #f))
       (make-edge 'rej 'reexecute) #f #f))
    ((sequence-dispatch)
     (make-sequence-dispatch-node 'hop (list (make-sequence-case '(1) 'fin #f))
       (make-edge 'rej 'reexecute) #f #f))
    ((integer-accumulate)
     (make-integer-accumulate-node 'hop 'n 10 'fin (make-edge 'stop 'advance) 'rej #f #f))
    ((pause) (make-pause-node 'hop 'fin #f))
    ((field-action) (make-field-action-node 'hop 'clear '(n) 'fin #f #f))
    ((field-branch) (make-field-branch-node 'hop 'zero '(n) 'fin 'rej #f))
    (else (assertion-violation 't2-hop "no such kind" kind))))

(define (t2-machine kind eof-only?)
  ;; Byte 9 always reaches `stop`, so `stop` is reachable in both variants and no
  ;; incidental unreachable-node muddies the record.
  (make-machine 'x 'start (list (make-uint-field 'n 8 0 #f)) '() '()
                (list eof-decl rej-decl)
                (list (make-byte-dispatch-node 'start
                        (list (make-byte-case (make-exact-byte-matcher 0)
                                              (make-edge (if eof-only? 'stop 'hop) 'advance) #f)
                              (make-byte-case (make-exact-byte-matcher 9)
                                              (make-edge 'stop 'advance) #f))
                        (make-edge 'rej 'reexecute) (if eof-only? 'hop #f) #f)
                      (t2-hop kind) (make-finish-node 'fin #f)
                      (make-stop-node 'stop #f) (make-error-node 'rej 'rejected #f))
                'default-eof #f))

(define t2-kinds
  '(byte-dispatch sequence-dispatch integer-accumulate pause field-action field-branch))

(harness-group "§16.2:908 is gated on byte-reachability, for every kind (Slice ⓪b)"
  (lambda ()
    (harness-case "an EOF-only-reachable byte edge into a finish is accepted"
      (lambda ()
        ;; The half that fails today for the three input-reading kinds. The edge
        ;; is untakeable: once an execution takes an eof-target it can never feed
        ;; again, so no byte ever traverses it.
        (let ((seen 0) (bad '()))
          (for-each (lambda (k)
                      (set! seen (+ seen 1))
                      (let ((ds (map diagnostic-code
                                     (verification-diagnostics
                                      (verify-machine (t2-machine k #t))))))
                        (unless (null? ds) (set! bad (cons (cons k ds) bad)))))
                    t2-kinds)
          (check-equal "all six kinds driven" seen 6)
          (check-equal "none rejected" bad '()))))
    (harness-case "a BYTE-reachable byte edge into a finish is rejected at its source node"
      (lambda ()
        ;; The reverse-direction pin: the gate must not become vacuous. Asserted
        ;; on the (code . node) pair, because the node slot is the half that says
        ;; WHICH edge to fix, and one candidate shape for this check reported at
        ;; the finish node instead -- merging findings from different sources.
        (let ((seen 0) (bad '()))
          (for-each (lambda (k)
                      (set! seen (+ seen 1))
                      (let ((ds (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                                     (verification-diagnostics
                                      (verify-machine (t2-machine k #f))))))
                        (unless (equal? ds '((non-eof-into-finish . hop)))
                          (set! bad (cons (cons k ds) bad)))))
                    t2-kinds)
          (check-equal "all six kinds driven" seen 6)
          (check-equal "each rejected exactly once, at `hop`" bad '()))))))

;; Milestone 5 Slice ⓪b task 3: the ENTRY may not be a finish terminal (OQ-2).
;;
;; §16.2:908 forbids "non-EOF control flow INTO a finish terminal", and decision
;; 0011 item 4(b) states the same rule over REACHING: "a `finish` node reached by
;; non-EOF (byte) control flow is rejected". §10.6:616 agrees -- "may be reached
;; only while processing `parser-finish!`". The entry is reached by
;; `parser-feed!`, so zero hops is still reaching.
;;
;; *** Measured before the clause below existed: `entry = finish` verified with
;; ZERO diagnostics, and `parser-feed!` returned `finished` for an EMPTY slice
;; and for a one-byte slice alike, consuming 0. *** §11.1:638's closed list of
;; what an empty slice may produce is "a callback, stop, or error" -- `finished`
;; is not in it, and §12.1:671's `ready --feed-->` target set does not contain it
;; either. Three independent sentences forbid the shape.
;;
;; The runtime half of that measurement cannot be re-asserted as a live test:
;; once the verifier rejects the machine, no executor will build it. So it is
;; recorded here as the measurement that justified the rule, and the case below
;; asserts what remains observable -- the verdict.
;;
;; NO NEW CODE: this reuses `non-eof-into-finish`, on the Slice ③ precedent where
;; `invalid-field-operand` took a second meaning rather than spending a code. A
;; new code would need a new §16.2 bullet, and the parent plan is append-only, so
;; its anchor would land nine hundred lines from its siblings.
(harness-group "the entry may not be a finish terminal (Slice ⓪b)"
  (lambda ()
    (harness-case "a machine whose entry IS a finish node is rejected, once, at the entry"
      (lambda ()
        ;; Multiplicity 1 by construction: there is exactly one entry, and a
        ;; finish node has no out-targets, so the per-edge clause cannot also
        ;; fire on it.
        (let ((ds (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                       (verification-diagnostics
                        (verify-machine
                         (make-machine 'ef 'fin '() '() '() (list eof-decl rej-decl)
                                       (list (make-finish-node 'fin #f))
                                       'default-eof #f))))))
          (check-equal "exactly one finding, at the entry"
                       ds '((non-eof-into-finish . fin))))))
    (harness-case "an entry that ROUTES eof to a finish is still legal"
      (lambda ()
        ;; The shape people actually want, and the one §12.4:725 describes: a
        ;; stream-idle entry may route EOF to a successful `finished`. The tree
        ;; already ships it as `eof-machine.sls`. Asserted here so the clause
        ;; above cannot be widened into it by a later slice.
        (let ((v (verify-machine
                  (make-machine 'ok 'start '() '() '() (list eof-decl rej-decl)
                                (list (make-byte-dispatch-node 'start
                                        (list (make-byte-case (make-exact-byte-matcher 0)
                                                              (make-edge 'stop 'advance) #f))
                                        (make-edge 'rej 'reexecute) 'fin #f)
                                      (make-finish-node 'fin #f)
                                      (make-stop-node 'stop #f)
                                      (make-error-node 'rej 'rejected #f))
                                'default-eof #f))))
          (check "accepted" (verification-ok? v))
          (check-equal "no diagnostics" (length (verification-diagnostics v)) 0))))))

;; Milestone 5 Slice ⓪b task 4: the §16.2:909 walk starts from the states a
;; parser can be PARKED on -- which includes the ENTRY, and did not (D-1).
;;
;; `eof-terminal` was called from exactly two sites, and `machine-entry` was
;; neither, although `parser-finish!` on a fresh or reset parser starts precisely
;; there. So the EOF path that begins AT the entry was never classified.
;;
;; *** Measured before the fix: `entry = a stop node` verified with ZERO
;; diagnostics and `parser-finish!` returned `stopped`. *** The identical
;; property one hop away -- a dispatch whose eof-target is that stop, or a pause
;; whose continuation is -- was correctly rejected with `eof-reachable-stop`.
;; §16.2:909 forbids the first by name.
;;
;; The naive fix (bolt a second walk start onto the entry) DOUBLE-REPORTS
;; wherever the entry is already a start, and the only filter that suppresses
;; that is a per-kind census of the entry -- the construct that shipped three
;; Slice ③ defects. The shape used instead is a SET of parkable states, so the
;; entry appears exactly once by construction. The two one-hop controls below are
;; the anti-duplication pin: they must stay at exactly ONE finding.
(define (t4-machine entry-kind)
  (let ((nodes
         (case entry-kind
           ;; D-1's four cells: the entry itself terminates an EOF path badly.
           ((stop) (list (make-stop-node 'e #f)))
           ((field-action)
            (list (make-field-action-node 'e 'clear '(n) 'stop #f #f) (make-stop-node 'stop #f)))
           ((field-branch)
            (list (make-field-branch-node 'e 'zero '(n) 'stop 'stop #f) (make-stop-node 'stop #f)))
           ;; The two one-hop controls, already correct today.
           ((dispatch-eof)
            (list (make-byte-dispatch-node 'e
                    (list (make-byte-case (make-exact-byte-matcher 0)
                                          (make-edge 'stop 'advance) #f))
                    (make-edge 'rej 'reexecute) 'stop #f)
                  (make-stop-node 'stop #f) (make-error-node 'rej 'rejected #f)))
           ((pause-cont)
            (list (make-pause-node 'e 'stop #f) (make-stop-node 'stop #f)))
           (else (assertion-violation 't4-machine "no such entry kind" entry-kind)))))
    (make-machine 'x 'e (list (make-uint-field 'n 8 0 #f)) '() '()
                  (list eof-decl rej-decl) nodes 'default-eof #f)))

(harness-group "the §16.2:909 walk starts at the entry too (Slice ⓪b)"
  (lambda ()
    (harness-case "an entry whose own EOF path reaches a stop is rejected"
      (lambda ()
        ;; The four D-1 cells. Each verified CLEAN before this task.
        (let ((seen 0) (bad '()))
          (for-each (lambda (k)
                      (set! seen (+ seen 1))
                      (let ((ds (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                                     (verification-diagnostics
                                      (verify-machine (t4-machine k))))))
                        (unless (equal? ds '((eof-reachable-stop . e)))
                          (set! bad (cons (cons k ds) bad)))))
                    '(stop field-action field-branch))
          (check-equal "three entry kinds driven" seen 3)
          (check-equal "each rejected exactly once, at the entry" bad '()))))
    (harness-case "the one-hop controls still report exactly ONE finding"
      (lambda ()
        ;; The anti-duplication pin. Both of these were already correct; the risk
        ;; the fix introduces is reporting them TWICE, once for the entry start
        ;; and once for the node's own. A set of parkable states cannot.
        (let ((seen 0) (bad '()))
          (for-each (lambda (k)
                      (set! seen (+ seen 1))
                      (let ((ds (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                                     (verification-diagnostics
                                      (verify-machine (t4-machine k))))))
                        (unless (equal? ds '((eof-reachable-stop . e)))
                          (set! bad (cons (cons k ds) bad)))))
                    '(dispatch-eof pause-cont))
          (check-equal "both controls driven" seen 2)
          (check-equal "each reports once, not twice" bad '()))))))

;; Milestone 5 Slice ⓪b task 5: §16.4:940's edge/source label (OQ-4).
;;
;; §16.4:937-943 lists what a diagnostic CONTAINS -- code, severity, machine
;; name, "node and edge/source label where applicable", message, declaration
;; names, graph path. *** It carries NO cardinality rule. *** The
;; "one finding per decision" gloss that has been cited against these checks
;; entered at a Milestone 3 plan and propagated; it is not in the spec. So the
;; problem was never too many findings -- it is that two findings from one node
;; were the IDENTICAL record.
;;
;; The label half was implemented nowhere: three arguments at every call site.
;; Now a :908 finding carries the edge ROLE that produced it, and the two
;; machines below are what makes that observable: each has a node with two byte
;; edges into the same finish terminal, differing only in role.
;;
;; A ROLE, not an index. verify.sls declines elsewhere to promise the order of
;; two diagnostics from one node, and an index would newly promise it.
(harness-group "a :908 finding carries the edge role that produced it (Slice ⓪b)"
  (lambda ()
    (harness-case "a byte-dispatch's case and fallback into one finish are two distinguishable findings"
      (lambda ()
        ;; Before the label, both were `(non-eof-into-finish . d)` -- same code,
        ;; same node, indistinguishable. The count was already 2; what was
        ;; missing was being able to tell WHICH edge each one is about.
        (let ((ds (map (lambda (x) (list (diagnostic-code x) (diagnostic-node x)
                                         (diagnostic-edge x)))
                       (verification-diagnostics
                        (verify-machine
                         (make-machine 'roles 'd '() '() '() (list eof-decl rej-decl)
                           (list (make-byte-dispatch-node 'd
                                   (list (make-byte-case (make-exact-byte-matcher 65)
                                                         (make-edge 'stop 'advance) #f)
                                         (make-byte-case (make-exact-byte-matcher 66)
                                                         (make-edge 'fin 'advance) #f))
                                   (make-edge 'fin 'reexecute) #f #f)
                                 (make-finish-node 'fin #f)
                                 (make-stop-node 'stop #f))
                           'default-eof #f))))))
          (check-equal "two findings, one per offending edge, each labelled"
                       ds '((non-eof-into-finish d case)
                            (non-eof-into-finish d fallback))))))
    (harness-case "a sequence node's alternative and mismatch are likewise distinguishable"
      (lambda ()
        (let ((ds (map (lambda (x) (list (diagnostic-code x) (diagnostic-node x)
                                         (diagnostic-edge x)))
                       (verification-diagnostics
                        (verify-machine
                         (make-machine 'roles2 's '() '() '() (list eof-decl rej-decl)
                           (list (make-sequence-dispatch-node 's
                                   (list (make-sequence-case '(1) 'fin #f))
                                   (make-edge 'fin 'reexecute) #f #f)
                                 (make-finish-node 'fin #f))
                           'default-eof #f))))))
          (check-equal "alternative and mismatch, labelled"
                       ds '((non-eof-into-finish s alternative)
                            (non-eof-into-finish s mismatch))))))
    (harness-case "the other four kinds label their edges too"
      (lambda ()
        ;; *** Added by the whole-branch review: nine of the thirteen role labels
        ;; had no test and no pin. *** The dispatch and sequence cases above
        ;; covered four; a role that is never asserted is a slot that can be
        ;; wired to the wrong accessor, or to a constant, without anything
        ;; failing -- which is the same shape as a label that is always present.
        ;;
        ;; Each machine points EVERY byte out-edge of one kind at a finish
        ;; terminal, so the full role set for that kind is asserted at once, as a
        ;; multiset rather than a membership test.
        (let ((seen 0) (bad '()))
          (for-each
           (lambda (row)
             (set! seen (+ seen 1))
             (let* ((nm (car row)) (nodes (cadr row)) (want (caddr row))
                    (got (map (lambda (d) (list (diagnostic-code d) (diagnostic-node d)
                                                (diagnostic-edge d)))
                              (verification-diagnostics
                               (verify-machine
                                (make-machine 'roles3 'd (list (make-uint-field 'n 8 0 #f))
                                              '() '() (list eof-decl rej-decl)
                                              (append
                                               (list (make-byte-dispatch-node 'd
                                                       (list (make-byte-case
                                                              (make-exact-byte-matcher 0)
                                                              (make-edge nm 'advance) #f))
                                                       (make-edge 'rj 'reexecute) #f #f)
                                                     (make-finish-node 'fin #f)
                                                     (make-error-node 'rj 'rejected #f))
                                               nodes)
                                              'default-eof #f))))))
               (unless (equal? want got) (set! bad (cons (list nm 'want want 'got got) bad)))))
           (list
            (list 'ac (list (make-integer-accumulate-node 'ac 'n 10 'fin
                                                          (make-edge 'fin 'advance) 'fin #f #f))
                  '((non-eof-into-finish ac digit)
                    (non-eof-into-finish ac nondigit)
                    (non-eof-into-finish ac overflow)))
            (list 'fa (list (make-field-action-node 'fa 'increment '(n) 'fin 'fin #f))
                  '((non-eof-into-finish fa next)
                    (non-eof-into-finish fa error)))
            (list 'fb (list (make-field-branch-node 'fb 'zero '(n) 'fin 'fin #f))
                  '((non-eof-into-finish fb true)
                    (non-eof-into-finish fb false)))
            (list 'p (list (make-pause-node 'p 'fin #f))
                  '((non-eof-into-finish p continuation)))))
          (check-equal "four kinds driven" seen 4)
          (check-equal "every role label is the accessor's own" bad '()))))
    (harness-case "a diagnostic with no applicable edge carries #f"
      (lambda ()
        ;; "Where applicable" is half the requirement. A finding that is about a
        ;; NODE rather than an edge must not invent a label.
        (let ((ds (verification-diagnostics
                   (verify-machine
                    (make-machine 'noedge 'fin '() '() '() (list eof-decl rej-decl)
                                  (list (make-finish-node 'fin #f)) 'default-eof #f)))))
          (check-equal "one finding" (length ds) 1)
          (check-equal "and it carries no edge label" (diagnostic-edge (car ds)) #f))))))

;; Milestone 5 Slice ⓪b task 6: the EOF verdict order is THREE TIERS, not a flat
;; six (OQ-5).
;;
;; `eof-verdict-join` takes the max, so the ORDER decides which of two sibling
;; verdicts survives a join. Decision 0021 item 1 pins only `cycle >
;; eof-reachable-stop` and calls the rest "this slice's call" -- but the rest is
;; not free. Measured: six of the fifteen verdict pairs are undecidable by any
;; machine, and all six sit inside {finish, unresolved, error, default-error}.
;;
;; *** Four of those six are ACCEPTANCE HOLES. *** With `default-error` ranked
;; above `cycle`, a field-branch machine verifies ok=#t with ZERO diagnostics and
;; `parser-finish!` never returns. So a flat ranking has 720 orderings of which
;; 24 are observationally identical and some of the rest silently accept
;; non-terminating machines -- and an unwitnessable ordering cannot be a
;; decision under this project's own rules.
;;
;; Three tiers make the 24-permutation survivor UNWRITABLE rather than an
;; EXPECT_SURVIVES, and turn each tier assignment into a single-token mutation
;; caught by a failed comparison. All six symbols are KEPT: Milestone 5's span
;; check needs `finish` distinguished from `error` at `classify`, and 0021 item
;; 3's loud-else discipline forbids merging arms.
(define (t6-join-machine x-nodes x-name)
  ;; A field-branch is the only shape whose join is observable: one arm reaches
  ;; X, the other a stop, and whatever X's own verdict the join must be the stop
  ;; -- `eof-reachable-stop` is tier 1 and every benign verdict tier 0.
  ;;
  ;; *** The branch sits ONE HOP from the entry, not at it. *** Placed at the
  ;; entry, these fixtures depend on the entry being a walk start -- which is
  ;; task 4's decision, not this one -- and the whole-pass sweep duly found the
  ;; tier pins nesting inside task 4's. Reached instead as a dispatch's
  ;; eof-target, the join is still exercised (and reported at the dispatch),
  ;; while task 4's entry disjunct is irrelevant to it: `s0` starts a walk
  ;; through the OTHER disjunct, its own EOF route.
  (make-machine 'j 's0 (list (make-uint-field 'n 8 0 #f)) '() '()
                (list eof-decl rej-decl)
                (append (list (make-byte-dispatch-node 's0
                                (list (make-byte-case (make-exact-byte-matcher 0)
                                                      (make-edge 'stop 'advance) #f))
                                (make-edge 'rj 'reexecute) 'br #f)
                              (make-field-branch-node 'br 'zero '(n) x-name 'stop #f)
                              (make-stop-node 'stop #f)
                              (make-error-node 'rj 'rejected #f))
                        x-nodes)
                'default-eof #f))

(harness-group "a benign EOF verdict never outranks a stop in a join (Slice ⓪b)"
  (lambda ()
    (harness-case "an `error` sibling does not mask the stop"
      (lambda ()
        (check-equal "eof-reachable-stop survives the join"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (t6-join-machine (list (make-error-node 'x 'rejected #f)) 'x))))
                     '((eof-reachable-stop . s0)))))
    (harness-case "a `default-error` sibling does not mask the stop"
      (lambda ()
        ;; X is a dispatch with NO eof-target, so `dispatch-arm` answers
        ;; `default-error` -- the verdict whose promotion above `cycle` was
        ;; measured to accept a machine that never terminates.
        (check-equal "eof-reachable-stop survives the join"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (t6-join-machine
                             ;; `rj2`, not `rj`: the skeleton already declares an
                             ;; error node called `rj`, and a second one is a
                             ;; duplicate-name finding that has nothing to do
                             ;; with the join under test.
                             (list (make-byte-dispatch-node 'x '()
                                     (make-edge 'rj2 'reexecute) #f #f)
                                   (make-error-node 'rj2 'rejected #f))
                             'x))))
                     '((eof-reachable-stop . s0)))))
    (harness-case "an UNRESOLVED sibling does not mask the stop"
      (lambda ()
        ;; The sixth verdict, and the one the tier group did not cover until the
        ;; whole-branch review found it. `classify` answers `'unresolved` for an
        ;; EOF successor naming no node; the machine is rejected either way (the
        ;; dangling name is its own finding), but the §16.2:909 violation is
        ;; reported ONLY because `unresolved` sits in the benign tier and loses
        ;; the join. Move it up one tier and the stop is silently masked.
        (check-equal "both findings: the dangling name AND the stop"
                     (list-sort (lambda (a b) (string<? (symbol->string a)
                                                        (symbol->string b)))
                                (map diagnostic-code
                                     (verification-diagnostics
                                      (verify-machine (t6-join-machine '() 'nowhere)))))
                     '(eof-reachable-stop missing-target))))
    (harness-case "a `finish` sibling does not mask the stop either"
      (lambda ()
        ;; Moving the branch off the entry made this case cleaner as well as
        ;; better-anchored: `br` is EOF-only-reachable, so its arm into a finish
        ;; is NOT a §16.2:908 violation and the join is the only thing asserted.
        (check-equal "the stop, and nothing else"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (t6-join-machine (list (make-finish-node 'x #f)) 'x))))
                     '((eof-reachable-stop . s0)))))))

;; --- §16.2:901's NODE half (Milestone 5 Slice ②) -----------------------------
;; "callback decision branches that are missing, duplicated, or undeclared."
;; Slice ①b shipped the declaration share and left this, which needed a node
;; kind that did not exist. Every fixture below is otherwise valid, so the codes
;; asserted are the whole verification result rather than a subset of it -- and
;; the `node` slot is asserted with them, because each of these findings is
;; about the INVOKING NODE and not about the declaration it names.
(define (cb-machine decl node-branches node-callback)
  (make-machine 'cbm 'start '()
                (if decl (list decl) '()) '()
                errs
                (list (make-byte-dispatch-node 'start
                        (list (make-byte-case (make-exact-byte-matcher 0)
                                              (make-edge 'inv 'advance) #f))
                        (make-edge 'reject 'reexecute) #f #f)
                      ;; The pause continuation is the ERROR node, never the
                      ;; stop: a parser parked at a callback resumes on that one
                      ;; edge, so a stop there is an EOF path reaching a stop
                      ;; terminal and §16.2:909 would report that instead.
                      (make-callback-node 'inv node-callback 'stop
                                          node-branches 'reject #f)
                      (make-stop-node 'stop #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f))
(define (decided keys) (make-callback-declaration 'decide 'decision #t keys #f #f))

(harness-group "a callback node's branches against its declaration (§16.2:901)"
  (lambda ()
    (harness-case "a node whose keys match its declaration verifies clean"
      (lambda ()
        ;; The positive case first: without it every rejection below could be
        ;; satisfied by a verifier that rejects every callback node.
        (check-equal "no diagnostics"
                     (codes (cb-machine (decided '(keep skip))
                                        '((keep stop) (skip reject)) 'decide))
                     '())))
    (harness-case "an event callback's node may declare no branches at all"
      (lambda ()
        (check-equal "no diagnostics"
                     (codes (cb-machine (make-callback-declaration 'note 'event #t
                                                                   '() #f #f)
                                        '() 'note))
                     '())))
    (harness-case "a node naming no declaration reports missing-callback-declaration"
      (lambda ()
        ;; The SAME code a span naming no declaration reports (§16.2:890), reused
        ;; rather than minted: the fault is identical and only the subject moves.
        (check-equal "one finding, at the node"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (cb-machine (decided '(keep)) '((keep stop))
                                                       'nosuch))))
                     '((missing-callback-declaration . inv)))))
    (harness-case "the resolution arm answers ALONE"
      (lambda ()
        ;; Asserted, not assumed: with the name unresolved there is nothing to
        ;; judge the keys against, so a machine whose keys are also wrong must
        ;; still report exactly one finding. Without the short circuit this
        ;; would raise inside the key arms rather than report.
        (check-equal "still one finding"
                     (length (verification-diagnostics
                              (verify-machine (cb-machine (decided '(keep))
                                                          '((nosuch stop) (nosuch reject))
                                                          'nosuch))))
                     1)))
    (harness-case "a node invoking a span-kind callback is an invalid invocation"
      (lambda ()
        ;; §10.6:584 invokes "one named event or decision callback"; a span
        ;; callback is reached only through a span declaration (§10.4:515-516).
        ;; The span declaration this needs to exist is what keeps
        ;; `unreferenced-callback-declaration` out of the result.
        (check-equal "the invocation, and nothing about keys"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (make-machine 'cbm 'start '()
                                          (list (make-callback-declaration 'on-d 'span-data
                                                                           #t '() #f #f))
                                          (list (make-span-declaration 'body 'on-d #f #f))
                                          errs
                                          (list (make-byte-dispatch-node 'start
                                                  (list (make-byte-case
                                                         (make-exact-byte-matcher 0)
                                                         (make-edge 'inv 'advance) #f))
                                                  (make-edge 'reject 'reexecute) #f #f)
                                                (make-callback-node 'inv 'on-d 'stop
                                                                    '() 'reject #f)
                                                (make-stop-node 'stop #f)
                                                (make-error-node 'reject 'rejected #f))
                                          'default-eof #f))))
                     '((invalid-callback-invocation . inv)))))
    (harness-case "a key the declaration never declared is UNDECLARED"
      (lambda ()
        (check-equal "one finding, at the node"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (cb-machine (decided '(keep))
                                                       '((keep stop) (nosuch reject))
                                                       'decide))))
                     '((invalid-callback-invocation . inv)))))
    (harness-case "an EVENT callback's node declaring a branch is the same fault"
      (lambda ()
        ;; §13:812's first sentence, enforced statically: an event callback
        ;; declares no keys, so every key on its node is undeclared. This is why
        ;; the rule needs no arm of its own.
        (check-equal "one finding"
                     (codes (cb-machine (make-callback-declaration 'note 'event #t
                                                                   '() #f #f)
                                        '((keep stop)) 'note))
                     '(invalid-callback-invocation))))
    (harness-case "a declared key the node gives no target for is MISSING"
      (lambda ()
        ;; §10.6:585 lets a decision "select only among statically declared
        ;; branch keys", so a declared key with no target is a result the
        ;; machine cannot route.
        (check-equal "one finding, at the node"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (cb-machine (decided '(keep skip))
                                                       '((keep stop)) 'decide))))
                     '((invalid-callback-invocation . inv)))))
    (harness-case "a key listed twice is DUPLICATED, and reports once"
      (lambda ()
        ;; `duplicate-branch-key` reused from the declaration half for the same
        ;; reason `missing-callback-declaration` is: same fault, different
        ;; subject. It is reported BEFORE the undeclared/missing arms so a key
        ;; listed twice reports once as a duplicate rather than twice as
        ;; whatever else it is -- asserted here, since the arm order is the only
        ;; thing that makes it true.
        (check-equal "exactly one finding, and it is the duplicate"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (cb-machine (decided '(keep))
                                                       '((keep stop) (keep reject))
                                                       'decide))))
                     '((duplicate-branch-key . inv)))))
    (harness-case "an optional decision callback's node must give the default branch a target"
      (lambda ()
        ;; The check that makes `normalize-machine`'s own raise unreachable:
        ;; §9.3:419 takes the default branch with no callback to ask, so a node
        ;; with no target for it has nothing to lower.
        (check-equal "the missing key is reported"
                     (codes (cb-machine (make-callback-declaration 'decide 'decision #f
                                                                   '(keep skip) 'skip #f)
                                        '((keep stop)) 'decide))
                     '(invalid-callback-invocation))))))

(harness-finish)
