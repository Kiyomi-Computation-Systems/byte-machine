;;; verify-machine over the one-byte machine and its broken variants. Tests
;;; compare diagnostic codes, never rendered text.
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
;; A one-byte machine carrying a caller-supplied field list.
(define (machine-with-fields fs)
  (make-machine 'one-byte 'start fs '() '() errs
                (one-byte-nodes (make-edge 'reject 'reexecute)) 'default-eof #f))
;; A one-byte machine carrying a caller-supplied error-declaration list, so a
;; reason can be varied without touching the shared `errs`.
(define (machine-errs* ds nodes . eof-name)
  (make-machine 'one-byte 'start '() '() '() ds nodes
                (if (null? eof-name) 'default-eof (car eof-name)) #f))
(define (machine-with-reason r)
  (machine-errs* (list (make-error-declaration 'default-eof 'eof r #f) rej-decl)
                 (one-byte-nodes (make-edge 'reject 'reexecute))))

(define (codes m) (map diagnostic-code (verification-diagnostics (verify-machine m))))
;; The `node` slot of each diagnostic, so WHICH name a diagnostic carries can be
;; asserted rather than described. `codes` alone is blind to it.
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
    (harness-case "a pause node naming an undeclared reason is missing-error-declaration (M12)"
      (lambda ()
        ;; The optional pause reason resolves exactly as an error node's error
        ;; name does -- an undeclared one is missing-error-declaration, no new code.
        (check "missing-error-declaration"
               (has-code? (machine (list (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                                         (make-edge 'p 'advance) #f))
                                                   (make-edge 'reject 'reexecute))
                                         (make-pause-node 'p 'stop 'ghost #f)  ; 'ghost undeclared
                                         (make-stop-node 'stop #f)
                                         (make-error-node 'reject 'rejected #f)))
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
    ;; Error reasons are portability-checked alongside names and codes, but
    ;; restricted to printable ASCII plus LF -- a DIFFERENT repertoire from
    ;; valid-name?'s [a-z][a-z0-9-]*, and over a string rather than a symbol, so
    ;; the reason clause is its own predicate reusing the invalid-name CODE. The
    ;; emitter writes each reason into generated source, which is what makes the
    ;; restriction load-bearing.
    (harness-case "a reason outside printable ASCII is rejected"
      (lambda ()
        (let ((ds 'seed))
          (set! ds (codes (machine-with-reason (string #\a #\tab #\b))))
          (check-equal "one finding" (length ds) 1)
          (check-equal "invalid-name" (car ds) 'invalid-name))))
    (harness-case "a reason may carry quote backslash and newline"
      (lambda ()
        (let ((ds 'seed))
          ;; The three characters the emitter must escape. All are inside the
          ;; reason repertoire, so the VERIFIER must accept them -- escaping is
          ;; the writer's job, not a rejection.
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
    ;; pass-fields, declaration half. It carries the RELATIONAL checks the
    ;; verifier owns -- duplicate field names and portable field names -- and
    ;; nothing else. Widths and initial ranges are closed at construction, so a
    ;; machine whose field failed them never exists and a verifier arm for
    ;; either would be dead code (each rule has exactly one rejection site).
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
        ;; The field name goes in the diagnostic's existing `node` slot,
        ;; following duplicate-error-declaration and missing-target, which also
        ;; put non-node symbols there. Asserted here because `codes` cannot see
        ;; it.
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
        ;; at two fields the mutant's whole record set would be a SUBSET of the
        ;; "reason repertoire rejects every reason" mutant's, which reddens the
        ;; same case with the same 0-versus-2: no record would separate them, in
        ;; either direction. A third field separates the two by construction (3
        ;; against 2) and is the smallest change that does.
        (let ((ds 'seed))
          (set! ds (codes (machine-with-fields
                           (list (make-uint-field 'count 8 0 #f)
                                 (make-uint-field 'limit 16 3 #f)
                                 (make-uint-field 'seen 32 0 #f)))))
          (check-equal "no diagnostics" (length ds) 0))))
    ;; The unsupported-IR-version half of the shape check.
    ;;
    ;; machine-tag is an unexported vector compared with eq?, but descriptors
    ;; are bare R6RS vectors with no opacity, so (vector-ref m 0) yields the tag
    ;; using an (rnrs) primitive and no private import -- a machine? object CAN
    ;; be forged.
    ;;
    ;; This is a TEST-ONLY device. It reaches through the representation on
    ;; purpose, because make-machine stamps the version as a constant and its
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
        ;; is mutated: every fixture becomes unsupported at once.
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
    ;; A BYTE edge into a finish terminal is rejected.
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
    ;; An eof-target chain reaching a STOP terminal is rejected.
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
          ;; (three mutants share that record). These two name the diagnostic
          ;; that must be ABSENT, so
          ;; each of those mutants fails a different check:
          ;;   'unreachable-node -- node-out-targets' pause arm is what keeps
          ;;     p's continuation s1 (and pe's continuation done) on the
          ;;     reachability walk; dropping it strands them.
          ;;   'non-eof-into-finish -- pe is EOF-only-reachable and continues
          ;;     into a finish node, which is legal; only the
          ;;     non-eof-into-finish check's byte-reachability gate keeps it
          ;;     legal.
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
          (check "and NOT zero-progress-cycle: :898's gate excludes them"
                 ;; `pa` and `pb` are reachable only through `e0`'s eof-target,
                 ;; so they are not byte-reachable and the zero-progress check's
                 ;; byte-reachability gate excludes them. The machine is still
                 ;; rejected -- by `eof-zero-progress-cycle`, whose owner is
                 ;; `eof-terminal`. The gate reads `byte-reached` alone rather
                 ;; than a composite reachability relation precisely so the two
                 ;; checks do NOT overlap, and this line asserts that they do not
                 ;; both fire on an EOF-only pause cycle.
                 (not (exists (lambda (d) (eq? (diagnostic-code d) 'zero-progress-cycle))
                              (verification-diagnostics v))))
          ;; Attribution, not just verdict: the eof-zero-progress-cycle above is
          ;; the entry dispatch node e0's own eof-target-chain walk (its target
          ;; is 'pa, which cycles). It must NOT also be raised on 'pa itself --
          ;; that would only happen if the byte-reachability gate at the
          ;; eof-terminal-chain call site stopped filtering pa/pb out (neither
          ;; is byte-reached; both are eof-only-reachable), which produces a
          ;; redundant same-code diagnostic no verdict-based check can see (see
          ;; the mutation's own comment).
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
    ;; byte-reachable-pause continuation checks are out of the picture and the
    ;; count belongs to the dispatch-node walk alone.
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
        ;; After feed pauses at p, current = stop and resume returns to ready,
        ;; where finish! would begin EOF processing AT the stop.
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

;; Overlap is a property of canonical byte SETS, so it must be found across
;; mixed matcher kinds, and reported once per colliding PAIR of cases -- not
;; once per shared byte: a set and a complement can share 200 bytes.
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
    ;; the pair enumeration, so the three pair-enumeration mutations have
    ;; distinct first failures and distinct failure SETS -- without the
    ;; first-and-third fixture, "collisions after the first are dropped" is
    ;; subsumed by "only the first case is compared" and no pin can separate
    ;; them.
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

;; The sequence-dispatch node kind, at the verify.sls sites that must handle
;; it. The RULE that reproduces the site count is stated here because the rule
;; is what a later reader re-derives from: not "every site in verify.sls that
;; dispatches on node KIND", which yields twelve, and not a grep for
;; byte-dispatch-node?, which cannot see a cond dispatching through OTHER kind
;; predicates and so cannot find its own omission. It is
;;
;;   every kind dispatch with a PERMISSIVE FALL-THROUGH that a sequence node's
;;   own data could pass through unexamined
;;
;; -- a site whose non-matching branch quietly yields '() or #f while the
;; sequence kind carries exactly the data the site exists to inspect. That rule
;; gives EIGHT sites, SEVEN extended and ONE permanently not.
;;
;; The four kind-dispatching sites the looser wording sweeps in, and why the
;; rule excludes each: pass-names' error-node? filter (a sequence node has no
;; error name to leave undeclared); pass-eof-execution's TWO byte-reachability
;; gates for byte-reachable pauses, which select pause nodes to inspect a
;; CONTINUATION a sequence node does not have -- these are NOT the pass's
;; non-eof-into-finish and eof-reachable-stop filters, which are in the eight
;; and are extended; and pass-sequence-ambiguity, excluded for its own separate
;; reason below. Each positively selects one kind rather than falling through
;; past another's data.
;;
;; The set is easy to miscount by inspection, so derive it from the rule rather
;; than inheriting the number.
;;
;; The seven extended, each with an arm here: node-out-targets;
;; node-eof-target, exercised by arms 2 and 4 below through two different
;; callers, `eof-step` (the reachability and pass-7 walk) and pass-eof;
;; reexec-targets; eof-terminal; pass-eof-execution's two filters
;; (non-eof-into-finish and eof-reachable-stop); and pass-zero-progress's
;; REPORT guard -- covered by the two zero-progress cases below, "a sequence
;; node whose reexecute mismatch edge targets itself ..." and its advance-mode
;; twin, which sit between arms 3 and 4.
;;
;; The eighth, pass-overlap, is the one site deliberately NOT extended, and
;; PERMANENTLY so: byte-class overlap and sequence-prefix ambiguity are two
;; entries with two checks and two codes, and ambiguity is
;; pass-sequence-ambiguity's, not this pass's. It has no arm here.
;; pass-sequence-ambiguity is itself a ninth kind-dispatching site but is NOT in
;; the census above: it is sequence-only by construction, not a permissive
;; fall-through that has to be taught the kind. Its own group is at
;; the end of this file.
;;
;; A sequence node added to ir.sls but NOT to verify.sls VERIFIES CLEAN --
;; targets never resolution-checked, cycles never detected, EOF chain never
;; walked -- and only crashes later in the normalizer. That is why a node kind
;; and its verifier sites must land together.
(define (seq-node cases mismatch eof-target)
  (make-sequence-dispatch-node 'seq cases mismatch eof-target #f))
(define (one-alt bytes target) (list (make-sequence-case bytes target #f)))
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
    ;; arm 2 -- the reachability walk (`eof-step`): a node reachable ONLY
    ;; through the sequence eof-target
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
    ;; A sequence node on a reexecute cycle is itself REPORTED, not only seen
    ;; through by reexec-targets. Without the report, the first fixture
    ;; verifies ok #t with ZERO diagnostics and HANGS both executors, while the
    ;; byte-identical shape built from a byte-dispatch node reports
    ;; zero-progress-cycle.
    (harness-case "a sequence node whose reexecute mismatch edge targets itself is a zero-progress cycle"
      (lambda ()
        (let ((m (make-machine 'selfseq 'seq '() '() '() errs
                   (list (seq-node (one-alt '(65 66) 'stop) (make-edge 'seq 'reexecute) #f)
                         (make-stop-node 'stop #f))
                   'default-eof #f)))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "zero-progress-cycle" (has-code? m 'zero-progress-cycle)))))
    ;; The other half. The mismatch edge's MODE is the whole decision:
    ;; an advance edge consumes the mismatching byte, so the loop makes
    ;; progress and must verify clean. reexec-targets' sequence arm is what
    ;; discriminates on mode; this case is what stops the report guard from
    ;; being widened past it.
    ;;
    ;; The third check is an ATTRIBUTION check. "ok" and "diagnostic count" are
    ;; unattributed: they say the machine verified clean, not WHICH diagnostic
    ;; would have been wrong. Three different Pass 33 mutants redden both of
    ;; them here with three different diagnostics -- the mode test deleted
    ;; (zero-progress-cycle on 'seq), node-out-targets' sequence arm deleted
    ;; (unreachable-node on 'stop), and the sequence-alternative self-comparison
    ;; (ambiguous-sequence-prefix) -- so a count of 1 is reached three ways and
    ;; the mode decision would own no FAIL record of its own. Naming the code that
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
    ;; arm 5 -- eof-terminal: the chain is walked THROUGH a sequence node.
    ;; The sequence node's eof-target is itself, not 'start: the file's
    ;; `dispatch` helper hard-wires 'start's own eof-target to #f, so a chain
    ;; through 'start terminates at 'default-error on its first step and never
    ;; revisits a node, let alone cycles. A self-targeting eof-target makes
    ;; the sequence node genuinely revisit itself, which is what exercises
    ;; eof-terminal's sequence-dispatch-node? branch (arm 5) rather than
    ;; terminating before ever reaching it.
    (harness-case "an eof chain that cycles through a sequence node is an EOF cycle"
      (lambda ()
        (check "eof-zero-progress-cycle"
               (has-code?
                (make-machine 'eofcyc 'start '() '() '() errs
                  ;; `seq` needs an inbound BYTE case: the EOF walk starts only
                  ;; from states a parser can be parked on, so without one
                  ;; `seq`'s self-cycling eof-target is unreachable and
                  ;; correctly not reported. Byte 7 makes the sequence node
                  ;; reachable, so what this case catches is a cycle THROUGH A
                  ;; SEQUENCE NODE.
                  (list (dispatch (list accept-case
                                        (make-byte-case (make-exact-byte-matcher 7)
                                                        (make-edge 'seq 'advance) #f))
                                  (make-edge 'reject 'reexecute))
                        (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) 'seq)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)
                'eof-zero-progress-cycle))))
    ;; Second arm-5 witness: the self-loop fixture above is caught not only by
    ;; removing arm 5 (the
    ;; sequence-dispatch-node? branch INSIDE eof-terminal) but also by
    ;; removing arm 7's own OUTER filter disjunct in pass-eof-execution --
    ;; with 'seq excluded from that map, eof-terminal is never even called
    ;; starting from 'seq, so its own inner branch is moot and both mutants
    ;; produce byte-identical FAIL output on that one case (see the mutation
    ;; suite's arm 5 pin comment). A genuine two-node cycle entered
    ;; from a BYTE-DISPATCH node separates them: 'start's own eof-target
    ;; check (arm 7 never touches byte-dispatch-node? entries) drives the
    ;; walk INTO 'seq, and only arm 5's branch lets the walk continue back
    ;; out through 'seq's own eof-target to close the cycle. Arm 5's mutant
    ;; fails this case (the walk reads 'unknown at 'seq and stops
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
    ;; arm 6 -- non-eof-into-finish: a sequence BYTE edge into a finish terminal
    (harness-case "a sequence case targeting a finish terminal is non-eof-into-finish"
      (lambda ()
        (check "non-eof-into-finish"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'done)
                                           (make-edge 'reject 'reexecute) #f)
                                 (make-error-node 'reject 'rejected #f)
                                 (make-finish-node 'done #f)))
                          'non-eof-into-finish))))
    ;; arm 7 -- eof-reachable-stop: the sequence node's own eof chain reaching
    ;; a stop
    (harness-case "a sequence eof path reaching a stop terminal is eof-reachable-stop"
      (lambda ()
        (check "eof-reachable-stop"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'reject 'reexecute) 'stop)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'eof-reachable-stop))))
    ;; Count-don't-witness for arms 3, 5 and 6. Against the arm cases above
    ;; alone, each arm's mutant has a failure set that is a full subset of a
    ;; broader sibling's -- which a subset test reports as subsumed even when a
    ;; better fixture could separate them. This is the same remedy as the
    ;; "both EOF terminals reported" and "three pairs" checks above. Each case
    ;; below puts at least TWO independent occurrences
    ;; of one decision in a single machine -- one on a byte-dispatch node
    ;; (which the competing broader mutation ALSO breaks, so the count drops
    ;; by the byte-dispatch contribution too) and one on a sequence node
    ;; reached only through the arm's own mechanism (which only the arm's
    ;; narrower mutation breaks) -- so the two mutations report different
    ;; "got" values on the same check; see SchemeMutationSuite.cmake's arms
    ;; 3/5/6. The first case below carries a THIRD occurrence -- 'seq itself,
    ;; which the REPORT set includes -- so that one separates three mutations
    ;; rather than two; its own table says which.
    (harness-case "a byte-dispatch self-loop, a dispatch-through-sequence cycle and the sequence node itself are three zero-progress cycles"
      (lambda ()
        ;; Count-don't-witness, four ways. Against this one check:
        ;;   correct code                                       -> 3
        ;;   PASS 5's REPORT guard loses its sequence clause     -> 2
        ;;   reexec-targets loses its sequence arm (arm 3)       -> 1
        ;;   PASS 5's report conditional replaced by (if #f      -> 0
        ;; 'x's case and fallback both reexecute into itself, a decision only
        ;; the last of those touches; 'start -> 'seq -> 'start is the cycle the
        ;; walk must see THROUGH; and 'seq itself is in the REPORTED set.
        (check-equal "zero-progress-cycle count"
                     (length (filter (lambda (c) (eq? c 'zero-progress-cycle))
                                     (codes
                                      (make-machine 'combined3 'x '() '() '() errs
                                        ;; Byte 1 ADVANCES into 'start: the
                                        ;; zero-progress gate reports a cycle
                                        ;; only on a BYTE-REACHABLE node, and
                                        ;; without this edge 'start and 'seq
                                        ;; are reachable from nowhere.
                                        (list (make-byte-dispatch-node 'x
                                                (list (make-byte-case (make-exact-byte-matcher 0)
                                                                      (make-edge 'x 'reexecute) #f)
                                                      (make-byte-case (make-exact-byte-matcher 1)
                                                                      (make-edge 'start 'advance) #f))
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
        ;; cycle is classified as a finish terminal": 'x's own
        ;; eof-target chain cycles through itself without ever touching a
        ;; sequence node, a decision arm 5 never reaches. 'start <-> 'seq is
        ;; the SAME two-node cycle as arm 5's own "an eof chain that cycles
        ;; from a dispatch node through a sequence node's own eof-target"
        ;; case above; under correct code BOTH nodes' own eof-target-chain
        ;; walks find the cycle, so this pair alone contributes 2. A
        ;; self-loop entirely at the sequence node (arm 5's OTHER own case,
        ;; and arm 7's fixture) would not do here: it does not separate arm 5
        ;; from arm 7, because a walk that starts AND ends at the sequence
        ;; node without ever passing through a byte-dispatch node is killed
        ;; identically by either mutation (both report "got 1" on that
        ;; shape). The 'start/'seq pair is entered
        ;; from a byte-dispatch node's own eof-target, which only arm 5's
        ;; inner eof-terminal change touches -- arm 7's outer-filter change
        ;; is irrelevant to a chain that never STARTS at the sequence node.
        ;; Correct code reports 3; the cycle-classification mutant disables
        ;; eof-terminal's cycle guard globally, reporting 0; arm 5 still finds
        ;; 'x's own cycle but every walk that must pass through 'seq returns
        ;; 'unknown, reporting 1; arm 7 still finds 'x's cycle and 'start's
        ;; own eof-target-chain walk (arm 7 never touches eof-terminal, and
        ;; 'start stays in the EOF-chain outer filter under arm 7's
        ;; mutation), losing only 'seq's own
        ;; entry, reporting 2 -- three distinct "got" values, so this check
        ;; also happens to separate arm 5 from arm 7 as a byproduct.
        (check-equal "eof-zero-progress-cycle count"
                     (length (filter (lambda (c) (eq? c 'eof-zero-progress-cycle))
                                     (codes
                                      (make-machine 'combined5 'start '() '() '() errs
                                        (list (make-byte-dispatch-node 'x '()
                                                (make-edge 'reject 'reexecute) 'x #f)
                                              ;; `x` and `seq` need inbound BYTE cases: the EOF
                                              ;; walk starts only from states a parser can be
                                              ;; parked on. Without them `x` is reachable from
                                              ;; nowhere and `seq` only as an eof-target, so
                                              ;; neither starts a walk and the count is 1.
                                              ;; Making both byte-reachable keeps all THREE
                                              ;; findings and the case's full discriminating
                                              ;; power.
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
        ;; arm 6 (the non-eof-into-finish outer filter's sequence disjunct)
        ;; vs "verify: a byte edge into a finish terminal is accepted": 's0's
        ;; own byte case into 'done is the decision that mutation's own case
        ;; above witnesses by existence and arm 6 never touches (byte-dispatch
        ;; nodes stay in the filter under arm 6's mutation); 'seq's own case
        ;; into 'done is arm 6's own case above. Correct code reports 2; that
        ;; mutation disables the shared finish-check for every node kind,
        ;; reporting 0; arm 6 narrows the filter to byte-dispatch only, so
        ;; 's0 still reports but 'seq does not, reporting 1.
        ;;
        ;; This does NOT separate arm 6 from "verify: a sequence node's
        ;; case and mismatch targets are not out-targets" (arm 1): arm 1
        ;; empties node-out-targets for every sequence node, which starves
        ;; THIS check's loop identically to arm 6's own narrower filter
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
                                                      ;; `seq` needs its own inbound byte case:
                                                      ;; non-eof-into-finish is gated on
                                                      ;; byte-reachability, so without one `seq`'s
                                                      ;; edge into `done` is untakeable and correctly
                                                      ;; not reported. This case's INTENT is two
                                                      ;; findings from two different source nodes, so
                                                      ;; the second source must be real.
                                                      (make-byte-case (make-exact-byte-matcher 2) (make-edge 'seq 'advance) #f))
                                                (make-edge 'reject 'reexecute) #f #f)
                                              (seq-node (one-alt '(1 2) 'done) (make-edge 'reject 'reexecute) #f)
                                              (make-finish-node 'done #f)
                                              (make-error-node 'reject 'rejected #f))
                                        'default-eof #f))))
                     2)))))

;; Sequence ambiguity. One alternative being a terminal prefix of another is
;; UNREPRESENTABLE (a prefix state has no "accept here" slot), so it is
;; rejected here rather than left to the normalizer's internal guard. Duplicate
;; alternatives are the maximal case of the same relation -- `AB` is a terminal
;; prefix of `AB` -- so both shapes carry the one code. Reported once per
;; colliding PAIR, like pass-overlap.
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
    ;; mutation's whole failure set inside the never-run mutation's -- a
    ;; subsumed shape. The sum separates them (6 / 3 / 0).
    (harness-case "the prefix test asks both directions, counted over both declaration orders"
      (lambda ()
        (check-equal "ambiguity count over both orderings"
                     (+ (ambiguity-count nested-short-first)
                        (ambiguity-count nested-long-first))
                     6)))
    ;; The over-rejection direction, which nothing else in this file tests: a
    ;; SHARED first byte is not ambiguity (shared nonterminal prefixes are
    ;; permitted; the trie merges them), and a check that cannot tell the two
    ;; apart would reject every branching sequence machine.
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


;; eof-terminal over multi-successor zero-width nodes. Only a multi-successor
;; kind such as a field branch can witness a join, a re-converging diamond, or
;; the completed-set; a SINGLE-successor kind cannot.
;;
;; Each machine routes its entry dispatch's eof-target into a field branch, so
;; the EOF-chain walk reaches the multi-successor node. These machines declare
;; no fields and may carry unrelated diagnostics, so every assertion is about
;; the PRESENCE or ABSENCE of one code, never about a total count.
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
        ;; A walk with one shared `seen` across arms reports 'cycle for a
        ;; diamond that merely re-converges. Both arms reach the SAME finish
        ;; node here, so the walk meets `f1` twice.
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
        ;; The ONE verdict ordering pinned in the source, and the only place two
        ;; verdicts can meet.
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


;; The verifier census for the two zero-width kinds: every site that switches
;; on node kind and must handle them.
;;
;; *** The byte-reachable-pause stop check is DELIBERATELY NOT EXTENDED to
;; zero-width nodes, and the last case here is what holds that decision. *** A
;; byte-reachability-gated sibling block "same shape" as the pause one would
;; turn `dispatch --advance--> field-action --next--> stop` into a false
;; eof-reachable-stop. A pause IS an EOF start -- parser-feed-op!'s pause arm
;; commits `current` PAST it, so a later finish begins at the continuation --
;; whereas a zero-width node never becomes `current`, because the dispatch arm
;; returns need-input without moving it. eof-terminal's zero-width arms plus
;; the pause block already cover every real EOF start.
(define (fields1) (list (make-uint-field 'count 8 0 #f)))
(define (zw-machine nodes entry)
  (make-machine 'm entry (fields1) '() '() (list eof-decl rej-decl) nodes 'default-eof #f))

(harness-group "the zero-width census (Slice ② task 3)"
  (lambda ()
    (harness-case "a zero-width self-cycle is a zero-progress cycle"
      (lambda ()
        ;; The failure this closes: without BOTH the walk and the REPORT set,
        ;; a `store`-into-itself machine verifies clean and then hangs in both
        ;; lanes. The walk alone is a half-fix.
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
          (check "nothing unreachable" (not (memq 'unreachable-node cs))))
        ;; *** A SECOND MACHINE, because the first one cannot witness this
        ;; arm. *** `act` above is the ENTRY, which makes it a parked node, and
        ;; `eof-step` reads `zero-width-edges` DIRECTLY rather than through
        ;; `node-out-targets` --
        ;; the entry's EOF walk therefore visits `after` and `oops` even when
        ;; the arm under test yields nothing. Here `act` is reached by a BYTE
        ;; edge from the entry instead, so nothing is parked but the entry
        ;; (whose own EOF route is #f), no EOF walk runs, and `after` -- a stop
        ;; nothing else names -- is occupiable only through the zero-width edge
        ;; this arm supplies. Asserted as the whole (code . node) list so the
        ;; mutant's record can be pinned rather than described.
        (check-equal "and reachable through a zero-width node the entry only reaches by a byte edge"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (zw-machine
                             (list (make-byte-dispatch-node 'start
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 'act 'advance) #f))
                                     (make-edge 'oops 'reexecute) #f #f)
                                   (make-field-action-node 'act 'increment '(count)
                                                           'after 'oops #f)
                                   (make-stop-node 'after #f)
                                   (make-error-node 'oops 'rejected #f))
                             'start))))
                     '())))
    (harness-case "a byte-reachable zero-width node into a finish is non-eof-into-finish"
      (lambda ()
        ;; Non-EOF control flow into a finish terminal is forbidden, and a byte
        ;; path that runs dispatch -> field-action -> finish is exactly that. A
        ;; check filtering on dispatch kinds alone cannot see it: the finish
        ;; sits one hop further than it looks.
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
        ;; emit identical records.
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
        ;; The pause kind's rule, applied here: only NON-EOF control flow into a
        ;; finish is forbidden, so a zero-width node reached only along an EOF
        ;; path legally continues into one. This is what the
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
        ;; *** The case that holds the decision not to extend the pause stop
        ;; check. *** A sibling block written "same shape" as the pause one
        ;; would report eof-reachable-stop here -- a diagnostic and message
        ;; about EOF, for a machine whose only path to that stop is a byte
        ;; path. If that block is added, this case fails, which is the point.
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


;; pass-fields' OPERAND half. Everything here needs a SECOND object -- the
;; field declaration -- which is exactly why none of it is a constructor
;; contract, and why the constructor accepts every one of these nodes.
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
        ;; The check the CONSTRUCTOR deliberately does not make: nothing can be
        ;; read out of `arguments` before arity is known.
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
        ;; This looks like a constructor contract and is not: the constructor
        ;; accepts it -- asserted in ir-tests.sps -- and the verifier is where it
        ;; is caught.
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

;; A settable field may not be a counted-consume counter -- its
;; embedder-chosen initial would falsify the
;; EOF-execution pass's reasoning that an entry counter holds its declared
;; initial. A settable field used as a field-branch SELECTOR stays legal.
(define (counter-machine field)
  (make-machine 'm 'consume (list field) '() '() (list eof-decl rej-decl)
                (list (make-counted-consume-node 'consume (uint-field-name field) 'next 'next #f)
                      (make-stop-node 'next #f) (make-error-node 'oops 'rejected #f))
                'default-eof #f))
(harness-group "settable-consume-counter (Milestone 13, §16.3)"
  (lambda ()
    (harness-case "a SETTABLE field used as a counted-consume counter is refused"
      (lambda ()
        (check "the code appears"
               (and (memq 'settable-consume-counter
                          (codes (counter-machine (make-uint-field 'n 8 0 #t #f)))) #t))))
    (harness-case "a NON-settable counter is not flagged"
      (lambda ()
        (check "clean"
               (not (memq 'settable-consume-counter
                          (codes (counter-machine (make-uint-field 'n 8 0 #f #f))))))))
    (harness-case "a settable field used as a field-branch SELECTOR is legal"
      (lambda ()
        (let ((m (make-machine 'm 'br (list (make-uint-field 'mode 8 0 #t #f)) '() '()
                               (list eof-decl rej-decl)
                               (list (make-field-branch-node 'br 'equal '(mode 1) 'next 'next #f)
                                     (make-stop-node 'next #f))
                               'default-eof #f)))
          (check "not flagged as a settable counter"
                 (not (memq 'settable-consume-counter (codes m)))))))))


;; The verifier census for the INPUT-READING kind (integer-accumulate).
;;
;; *** The two self-cycles need SEPARATE fixtures. *** `nondigit-edge` is not
;; the only edge that can loop without consuming: overflow is non-consuming and
;; leaves the field unchanged, so an `overflow-error` naming its own node
;; re-reads the same byte forever with no cycle guard in either runtime loop. A
;; walk that takes only the nondigit disjunct verifies a self-targeting overflow
;; edge with ZERO diagnostics.
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
        ;; The overflow edge consumes nothing, so this loops forever -- and a
        ;; walk taking only the
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
        ;; The digit edge always advances, so an accumulate node
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
        ;; Reported under the NODE's name, matching the operand walk's own
        ;; convention.
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

;; *** THREE kind filters beyond the shared accessors. *** Teaching
;; `node-eof-target` and `node-out-targets` about the accumulate kind is not
;; enough: `eof-terminal`'s `classify` and both of `pass-eof-execution`'s
;; filters enumerate their kinds by hand, so a kind missing from them is
;; invisible to all three -- and every fixture above misses that by
;; construction, because each declares `eof-target #f` and makes `acc` the
;; entry, so no EOF chain in those cases walks into one.
;;
;; A pin sweep re-judges the pins that exist and cannot notice a decision no
;; pin names. The group below is one case per filter, each a machine both
;; executors run correctly and which a filter missing the kind would make the
;; verifier either raise on or wave through.
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
        ;; The `classify` arm. Without it, this RAISES out of verification --
        ;; `verify-machine` never returns, so the machine has no verdict rather
        ;; than a bad one, and `compile-machine` raises with it. Asserted as a
        ;; clean verdict because the machine IS legal: both lanes run it.
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
        ;; This is the worst of the three: `parser-finish-op!` says in its own
        ;; comment that it carries no local cycle guard because it relies on
        ;; this check, so without it this machine verifies with ZERO diagnostics
        ;; and then loops forever in BOTH executors.
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
        ;; The third filter. `node-out-targets` yields the accumulate node's
        ;; three byte out-targets; this filter is what inspects them. The digit
        ;; target is used here because it is the arm a digit takes on
        ;; every accepted byte -- the least exotic of the three.
        (let ((cs (codes (acc-eof-machine #f 'fin (list (make-finish-node 'fin #f))))))
          (check "non-eof-into-finish" (memq 'non-eof-into-finish cs)))))))

;; The site that reports an EOF zero-progress cycle for a PAUSE continuation.
;;
;; It is the only site that can see a cycle which BEGINS at a pause
;; continuation and involves no dispatch eof-target at all; without this group,
;; deleting its `((cycle) ...)` clause leaves every other program in the tree
;; byte-identical. The other `eof-zero-progress-cycle` site attributes such a
;; cycle to a DISPATCH node; this one attributes it to the pause.
;;
;; That matters beyond bookkeeping: `parser-finish-op!` records in its own
;; comment that it carries no local cycle guard because it relies on these
;; checks. A machine of this shape verifying clean is a machine that loops
;; forever in both executors.
;;
;; The assertion is written on the PAIR (code, node-kind), not on the count, so
;; it survives any de-duplication of findings per decision: the pair
;; `eof-zero-progress-cycle` AT A PAUSE NODE is what only this site can produce.
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
        ;; Stated separately so that a change making this shape UNBUILDABLE fails
        ;; here and says so, rather than silently emptying the case below.
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

;; non-eof-into-finish is a rule about BYTE-REACHABILITY, for every kind. A node
;; reachable ONLY as an eof-target carries byte edges no byte can traverse, so
;; its edge into a finish is untakeable and is accepted, whatever its kind.
;;
;; The ungated reading is wrong: the machine it refuses is
;; `make-pause-machine` -- the canonical legal shape, an EOF-only pause
;; continuing into a finish node, named in that fixture's own header.
;;
;; Splitting the kinds by "reads input" versus "zero-width", on the reasoning
;; that an input-reading node is always on the feed path, is wrong too. These
;; sixteen machines are the counterexample: every input-reading kind can be
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
    ;; The callback's PAUSE CONTINUATION is the error node and not the stop: a
    ;; byte-reachable callback is a parked state whose EOF walk starts on that
    ;; one edge, so a stop there is an eof-reachable-stop finding and this row
    ;; would stop being about non-eof-into-finish.
    ((callback) (make-callback-node 'hop 'cb 'fin '() 'rej #f))
    ;; A #f eof-target keeps the counted consume out of the parked set, and in
    ;; the eof-only variant the entry's walk classifies it as the join of
    ;; default-error and finish -- tier 0 -- so the row still isolates
    ;; non-eof-into-finish.
    ((counted-consume) (make-counted-consume-node 'hop 'n 'fin #f #f))
    (else (assertion-violation 't2-hop "no such kind" kind))))

(define (t2-machine kind eof-only?)
  ;; Byte 9 always reaches `stop`, so `stop` is reachable in both variants and no
  ;; incidental unreachable-node muddies the record.
  ;; The callback declaration is present for EVERY kind, not only the callback
  ;; one: a declaration no node invokes is not a diagnostic (only a SPAN-kind
  ;; one is), and a table that varied per kind would make the other rows
  ;; compare against a different machine.
  (make-machine 'x 'start (list (make-uint-field 'n 8 0 #f))
                (list (make-callback-declaration 'cb 'event #t '() #f #f)) '()
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

;; *** A HAND-WRITTEN PER-KIND CENSUS. *** It is derived from nothing, so a new
;; kind joins it only because someone remembers. When listing the per-kind
;; sites a new node kind must reach, search `test/` as well as `src/`: this is
;; one of the `test/` sites.
(define t2-kinds
  '(byte-dispatch sequence-dispatch integer-accumulate pause field-action
    field-branch callback counted-consume))

;; *** THE TWO SPAN KINDS ARE EXCLUDED, and the reason is a property rather than
;; a fixture problem. *** This row isolates non-eof-into-finish -- a byte edge
;; into a finish terminal -- by placing one node of each kind with such an edge
;; and asserting the verdict is that finding and nothing else. Neither span kind
;; can sit here without a SECOND, unrelated finding:
;;
;;   - a span START whose byte edge reaches `fin` carries the span it just
;;     opened into a successful terminal, which the span rules reject. There is
;;     nowhere to close it: the edge under test is the one that reaches `fin`,
;;     so any closing node would have to sit on it.
;;   - a span END reached with nothing open is an unmatched end, whatever its
;;     successor is.
;;
;; So the exclusion is derived, not convenient, and the non-eof-into-finish
;; verdict for both kinds is asserted where it CAN be isolated: the kind x
;; position matrix's
;; `finish` column, where every position is driven for every kind and the
;; expectation carries the span rules explicitly.

(harness-group "§16.2:908 is gated on byte-reachability, for every kind (Slice ⓪b)"
  (lambda ()
    (harness-case "an EOF-only-reachable byte edge into a finish is accepted"
      (lambda ()
        ;; The EOF-only half. The edge is untakeable: once an execution takes an
        ;; eof-target it can never feed again, so no byte ever traverses it.
        ;;
        ;; The property this case owns -- no kind reports `non-eof-into-finish`
        ;; for an edge no byte can traverse -- is its own check, total over
        ;; `t2-kinds` so it cannot pass by not running. The third check is a
        ;; SECOND fact about the same machines: `pass-reachability` walks the
        ;; occupiable relation, so for the three kinds whose byte edges are dead
        ;; at EOF -- byte-dispatch, sequence-dispatch, integer-accumulate, whose
        ;; `hop` carries no EOF route of its own and therefore no EOF successor
        ;; -- `fin` sits behind that dead edge and is an unreachable node. The
        ;; other five keep `fin` occupiable: a pause, a field-action and a
        ;; field-branch continue into it zero-width, a callback's outcome
        ;; reaches it, and a counted consume's `next` is an EOF successor.
        (let ((seen 0) (bad '()) (into-finish '()))
          (for-each (lambda (k)
                      (set! seen (+ seen 1))
                      (let ((ds (map (lambda (d) (cons (diagnostic-code d)
                                                       (diagnostic-node d)))
                                     (verification-diagnostics
                                      (verify-machine (t2-machine k #t))))))
                        (set! into-finish
                              (cons (cons k (and (assq 'non-eof-into-finish ds) #t))
                                    into-finish))
                        (unless (null? ds) (set! bad (cons (cons k ds) bad)))))
                    t2-kinds)
          (check-equal "all eight kinds driven" seen 8)
          ;; The non-eof-into-finish property, asserted per kind rather than as
          ;; an empty list: a total answer over `t2-kinds` fails if the loop
          ;; stops early as well as if a verdict flips.
          (check-equal "no kind reports non-eof-into-finish for the untakeable edge"
                       (reverse into-finish)
                       '((byte-dispatch . #f) (sequence-dispatch . #f)
                         (integer-accumulate . #f) (pause . #f)
                         (field-action . #f) (field-branch . #f)
                         (callback . #f) (counted-consume . #f)))
          (check-equal "the finish behind a dead byte edge is unreachable for the three input-reading kinds, and nothing else is reported"
                       (reverse bad)
                       '((byte-dispatch (unreachable-node . fin))
                         (sequence-dispatch (unreachable-node . fin))
                         (integer-accumulate (unreachable-node . fin)))))))
    (harness-case "a BYTE-reachable byte edge into a finish is rejected at its source node"
      (lambda ()
        ;; The reverse-direction pin: the gate must not become vacuous. Asserted
        ;; on the (code . node) pair, because the node slot is the half that says
        ;; WHICH edge to fix, and a check reporting at the finish node instead
        ;; would merge findings from different sources.
        (let ((seen 0) (bad '()))
          (for-each (lambda (k)
                      (set! seen (+ seen 1))
                      (let ((ds (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                                     (verification-diagnostics
                                      (verify-machine (t2-machine k #f))))))
                        (unless (equal? ds '((non-eof-into-finish . hop)))
                          (set! bad (cons (cons k ds) bad)))))
                    t2-kinds)
          (check-equal "all eight kinds driven" seen 8)
          (check-equal "each rejected exactly once, at `hop`" bad '()))))))

;; The ENTRY may not be a finish terminal.
;;
;; Non-EOF control flow INTO a finish terminal is forbidden, and the same rule
;; holds over REACHING: a `finish` node may be reached only while processing
;; `parser-finish!`. The entry is reached by `parser-feed!`, so zero hops is
;; still reaching.
;;
;; Without the clause, `entry = finish` verifies with ZERO diagnostics, and
;; `parser-feed!` returns `finished` for an EMPTY slice and for a one-byte slice
;; alike, consuming 0 -- yet an empty slice may produce only a callback, stop,
;; or error, and `finished` is not a status a feed from `ready` may reach.
;;
;; That runtime behaviour cannot be asserted as a live test: once the verifier
;; rejects the machine, no executor will build it. The case below asserts what
;; remains observable -- the verdict.
;;
;; NO NEW CODE: this reuses `non-eof-into-finish`, as `invalid-field-operand`
;; carries a second meaning rather than spending a code.
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
        ;; The shape people actually want: a stream-idle entry may route EOF to
        ;; a successful `finished`, as `eof-machine.sls` does. Asserted here so
        ;; the clause above cannot be widened into it.
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

;; The EOF-chain walk starts from the states a parser can be PARKED on --
;; which includes the ENTRY, since `parser-finish!` on a fresh or reset parser
;; starts precisely there.
;;
;; A walk that omits the entry verifies `entry = a stop node` with ZERO
;; diagnostics, and `parser-finish!` then returns `stopped`, while the
;; identical property one hop away -- a dispatch whose eof-target is that stop,
;; or a pause whose continuation is -- is rejected with `eof-reachable-stop`.
;;
;; Bolting a second walk start onto the entry DOUBLE-REPORTS wherever the entry
;; is already a start, and the only filter that suppresses that is a per-kind
;; census of the entry -- a construct that silently misses new kinds. The walk
;; starts instead from a SET of parkable states, so the entry appears exactly
;; once by construction. The two one-hop controls below are the
;; anti-duplication pin: they must stay at exactly ONE finding.
(define (t4-machine entry-kind)
  (let ((nodes
         (case entry-kind
           ;; The entry itself terminates an EOF path badly.
           ((stop) (list (make-stop-node 'e #f)))
           ((field-action)
            (list (make-field-action-node 'e 'clear '(n) 'stop #f #f) (make-stop-node 'stop #f)))
           ((field-branch)
            (list (make-field-branch-node 'e 'zero '(n) 'stop 'stop #f) (make-stop-node 'stop #f)))
           ;; The two one-hop controls.
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
        ;; The anti-duplication pin. The risk in starting a walk at the entry is
        ;; reporting these TWICE, once for the entry start and once for the
        ;; node's own. A set of parkable states cannot.
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

;; A diagnostic's edge/source label.
;;
;; A diagnostic CONTAINS a code, severity, machine name, "node and edge/source
;; label where applicable", message, declaration names and graph path. *** There
;; is NO cardinality rule. *** Two findings from one node are fine; two findings
;; from one node that are the IDENTICAL record are not.
;;
;; A non-eof-into-finish finding carries the edge ROLE that produced it, and the
;; two machines below are what makes that observable: each has a node with two
;; byte edges into the same finish terminal, differing only in role.
;;
;; A ROLE, not an index. verify.sls declines elsewhere to promise the order of
;; two diagnostics from one node, and an index would newly promise it.
(harness-group "a :908 finding carries the edge role that produced it (Slice ⓪b)"
  (lambda ()
    (harness-case "a byte-dispatch's case and fallback into one finish are two distinguishable findings"
      (lambda ()
        ;; Without the label, both are `(non-eof-into-finish . d)` -- same code,
        ;; same node, indistinguishable. The count is 2 either way; the label is
        ;; what tells WHICH edge each one is about.
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
    (harness-case "every other kind labels its edges too"
      (lambda ()
        ;; The dispatch and sequence cases above cover four role labels; this
        ;; table covers the rest. A role that is never asserted is a slot that
        ;; can be wired to the wrong accessor, or to a constant, without
        ;; anything failing -- which is the same shape as a label that is always
        ;; present.
        ;;
        ;; This is the ONLY census of `diagnostic-edge` in the tree, so every
        ;; kind `zero-width-edges` labels needs a row here: otherwise a span arm
        ;; wired to an existing role -- `case` instead of `next` -- would ship a
        ;; wrong label with nothing red.
        ;;
        ;; Each machine points EVERY byte out-edge of one kind at a finish
        ;; terminal, so the full role set for that kind is asserted at once, as a
        ;; multiset rather than a membership test. The span and callback rows
        ;; carry their DECLARATIONS too, and their expected lists carry the
        ;; findings that come with pointing a span at a finish -- the span
        ;; successful-exit rule fires as well, and a row hiding that would be
        ;; asserting a subset.
        (let ((seen 0) (bad '()))
          (for-each
           (lambda (row)
             (set! seen (+ seen 1))
             (let* ((nm (car row)) (nodes (cadr row)) (want (caddr row))
                    (cbs (if (> (length row) 3) (list-ref row 3) '()))
                    (sps (if (> (length row) 4) (list-ref row 4) '()))
                    (got (map (lambda (d) (list (diagnostic-code d) (diagnostic-node d)
                                                (diagnostic-edge d)))
                              (verification-diagnostics
                               (verify-machine
                                (make-machine 'roles3 'd (list (make-uint-field 'n 8 0 #f))
                                              cbs sps (list eof-decl rej-decl)
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
                  '((non-eof-into-finish p continuation)))
            ;; A DECISION callback so the branch-key roles are reachable at all --
            ;; an event callback declares none, and the two branch edges are two
            ;; of the four labels this row exists for.
            (list 'cb (list (make-callback-node 'cb 'pick 'fin
                                                '((keep fin) (skip fin)) 'fin #f))
                  ;; BOTH branch edges carry the bare role `branch`, not the
                  ;; key. The label is "the edge role where applicable" and a
                  ;; role is what this answers; the KEY is in the node's own
                  ;; declaration, and two findings differing only by a key are
                  ;; told apart by nothing here. Stated explicitly because it is
                  ;; the one place in this table where the label is not
                  ;; injective over the edges.
                  '((non-eof-into-finish cb continue)
                    (non-eof-into-finish cb branch)
                    (non-eof-into-finish cb branch)
                    (non-eof-into-finish cb pause))
                  (list (make-callback-declaration 'pick 'decision #t '(keep skip) #f #f)))
            ;; The two span kinds. Both reuse `next` rather than minting a role,
            ;; which is the thing this row pins: a span arm wired to `case` or to
            ;; a constant would still produce a finding and still be caught only
            ;; here. The span successful-exit rule fires alongside, because a
            ;; span open at a finish is a successful exit with a span active.
            (list 'ss (list (make-span-start-node 'ss 'body 'fin #f))
                  '((span-active-at-exit fin #f)
                    (non-eof-into-finish ss next))
                  (list (make-callback-declaration 'on-data 'span-data #t '() #f #f))
                  (list (make-span-declaration 'body 'on-data #f #f)))
            (list 'se (list (make-span-end-node 'se 'body 'fin #f))
                  '((invalid-span-state se #f)
                    (non-eof-into-finish se next))
                  (list (make-callback-declaration 'on-data 'span-data #t '() #f #f))
                  (list (make-span-declaration 'body 'on-data #f #f)))
            ;; The counted consume: one byte edge, the existing `next` role.
            (list 'cc (list (make-counted-consume-node 'cc 'n 'fin #f #f))
                  '((non-eof-into-finish cc next)))))
          (check-equal "eight kinds driven" seen 8)
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

;; The EOF verdict order is THREE TIERS, not a flat six.
;;
;; `eof-verdict-join` takes the max, so the ORDER decides which of two sibling
;; verdicts survives a join. Beyond `cycle > eof-reachable-stop` the order is
;; not free: six of the fifteen verdict pairs are undecidable by any machine,
;; and all six sit inside {finish, unresolved, error, default-error}.
;;
;; *** Four of those six are ACCEPTANCE HOLES. *** With `default-error` ranked
;; above `cycle`, a field-branch machine verifies ok=#t with ZERO diagnostics and
;; `parser-finish!` never returns. So a flat ranking has 720 orderings of which
;; 24 are observationally identical and some of the rest silently accept
;; non-terminating machines -- and an unwitnessable ordering cannot be a
;; decision.
;;
;; Three tiers make the 24-permutation survivor UNWRITABLE rather than an
;; EXPECT_SURVIVES, and turn each tier assignment into a single-token mutation
;; caught by a failed comparison. All six symbols are KEPT: the span check
;; needs `finish` distinguished from `error` at `classify`, and the loud-else
;; discipline forbids merging arms.
(define (t6-join-machine x-nodes x-name)
  ;; A field-branch is the only shape whose join is observable: one arm reaches
  ;; X, the other a stop, and whatever X's own verdict the join must be the stop
  ;; -- `eof-reachable-stop` is tier 1 and every benign verdict tier 0.
  ;;
  ;; *** The branch sits ONE HOP from the entry, not at it. *** Placed at the
  ;; entry, these fixtures would depend on the entry being a walk start -- a
  ;; separate decision, pinned by the walk-starts-at-the-entry group above --
  ;; and the tier pins would nest inside that group's. Reached instead as a
  ;; dispatch's
  ;; eof-target, the join is still exercised (and reported at the dispatch),
  ;; while the entry disjunct is irrelevant to it: `s0` starts a walk through
  ;; the OTHER disjunct, its own EOF route.
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
        ;; `default-error` -- the verdict whose promotion above `cycle` accepts
        ;; a machine that never terminates.
        ;;
        ;; `rj2` is reachable only through `x`'s dead fallback edge -- `x` is
        ;; itself EOF-only-reachable and carries no EOF route, so no execution
        ;; can take that edge -- and `pass-reachability` reports it. The join
        ;; this case owns is separate: `eof-reachable-stop` survives it, and the
        ;; order is `verify-machine`'s `append` order, pass 4 before pass 6.
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
                     '((unreachable-node . rj2) (eof-reachable-stop . s0)))))
    (harness-case "an UNRESOLVED sibling does not mask the stop"
      (lambda ()
        ;; The sixth verdict. `classify` answers `'unresolved` for an EOF
        ;; successor naming no node; the machine is rejected either way (the
        ;; dangling name is its own finding), but the eof-reachable-stop
        ;; violation is reported ONLY because `unresolved` sits in the benign
        ;; tier and loses the join. Move it up one tier and the stop is
        ;; silently masked.
        (check-equal "both findings: the dangling name AND the stop"
                     (list-sort (lambda (a b) (string<? (symbol->string a)
                                                        (symbol->string b)))
                                (map diagnostic-code
                                     (verification-diagnostics
                                      (verify-machine (t6-join-machine '() 'nowhere)))))
                     '(eof-reachable-stop missing-target))))
    (harness-case "a `finish` sibling does not mask the stop either"
      (lambda ()
        ;; With the branch off the entry, `br` is EOF-only-reachable, so its arm
        ;; into a finish is NOT a non-eof-into-finish violation and the join is
        ;; the only thing asserted.
        (check-equal "the stop, and nothing else"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (t6-join-machine (list (make-finish-node 'x #f)) 'x))))
                     '((eof-reachable-stop . s0)))))))

;; --- callback decision branches: the NODE half --------------------------------
;; "callback decision branches that are missing, duplicated, or undeclared."
;; The declaration half is checked elsewhere; this is the invoking node's.
;; Every fixture below is otherwise valid, so the codes
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
                      ;; terminal and eof-reachable-stop would report that
                      ;; instead.
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
        ;; The SAME code a span naming no declaration reports, reused
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
        ;; A callback node invokes one named event or decision callback; a span
        ;; callback is reached only through a span declaration.
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
        ;; Enforced statically: an event callback declares no keys, so every
        ;; key on its node is undeclared. This is why
        ;; the rule needs no arm of its own.
        (check-equal "one finding"
                     (codes (cb-machine (make-callback-declaration 'note 'event #t
                                                                   '() #f #f)
                                        '((keep stop)) 'note))
                     '(invalid-callback-invocation))))
    (harness-case "a declared key the node gives no target for is MISSING"
      (lambda ()
        ;; A decision selects only among statically declared branch keys, so a
        ;; declared key with no target is a result the machine cannot route.
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
        ;; The check that makes `normalize-machine`'s own raise unreachable: an
        ;; absent optional callback takes the default branch with no callback
        ;; to ask, so a node with no target for it has nothing to lower.
        (check-equal "the missing key is reported"
                     (codes (cb-machine (make-callback-declaration 'decide 'decision #f
                                                                   '(keep skip) 'skip #f)
                                        '((keep stop)) 'decide))
                     '(invalid-callback-invocation))))))

;; --- PASS 7: the span-state lattice --------------------------------------------
;;
;; The five span-state rejections, the span-active-at-pause rule and the
;; span-active-at-exit rule, each driven from one machine that is otherwise valid --
;; so the codes asserted are the WHOLE verification result and not a subset of a
;; machine that was broken three ways.
(define sd-decl (make-callback-declaration 'on-data 'span-data #t '() #f #f))
(define (span-machine nodes)
  (make-machine 'spanm 'start '()
                (list sd-decl)
                (list (make-span-declaration 'body 'on-data #f #f)
                      (make-span-declaration 'other 'on-data #f #f))
                errs nodes 'default-eof #f))
(define (case-to target) (make-byte-case (make-exact-byte-matcher 0)
                                         (make-edge target 'advance) #f))
(define (entry-to target . eof)
  (make-byte-dispatch-node 'start (list (case-to target))
                           (make-edge 'reject 'reexecute)
                           (if (null? eof) #f (car eof)) #f))
(define (span-tail) (list (make-stop-node 'done #f)
                          (make-error-node 'reject 'rejected #f)))
;; *** THE TAIL A CLOSING SPAN NEEDS. *** A span end is a PARKED state: its data
;; callback's pause parks the parser on that node's completion substep, so the
;; EOF walk starts at the node's SUCCESSOR. With `cl` continuing straight into a
;; stop, a fixture that closes a span is a machine `parser-finish!` could answer
;; `stopped` from after a span-data pause -- which eof-reachable-stop forbids.
;; The stop keeps its place behind a dispatch whose own EOF route reaches a
;; finish, which is also the only legal way to reach a finish.
;;
;; Kept SEPARATE from `span-tail` rather than replacing it: a fixture whose span
;; path never reaches `exit` would report `unreachable-node` for it and for the
;; finish, and the case would then be measuring the tail instead of its own span
;; shape.
(define (span-tail/exit) (list (make-byte-dispatch-node 'exit (list (case-to 'done))
                                                        (make-edge 'reject 'reexecute) 'fin #f)
                               (make-stop-node 'done #f)
                               (make-finish-node 'fin #f)
                               (make-error-node 'reject 'rejected #f)))
;; A second entry shape and a second error sink, for the fixtures whose span
;; path must reach a node NOTHING ELSE reaches: the shared `reject` is also the
;; entry's fallback, so a span arriving there would join with `none` and the
;; case would be measuring a merge it did not mean to build.
(define (entry-fork a b)
  (make-byte-dispatch-node 'start
    (list (case-to a) (make-byte-case (make-exact-byte-matcher 1)
                                      (make-edge b 'advance) #f))
    (make-edge 'rej2 'reexecute) #f #f))
(define (span-tail2) (list (make-stop-node 'done #f)
                           (make-error-node 'reject 'rejected #f)
                           (make-error-node 'rej2 'rejected #f)))


(harness-group "the span-state lattice (§16.2:899, :900, :907)"
  (lambda ()
    (harness-case "a machine that opens and closes one span verifies clean"
      (lambda ()
        ;; Stated first: every rejection below is satisfiable by a pass that
        ;; rejects every machine containing a span node.
        (check-equal "no diagnostics"
                     (codes (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'body 'cl #f)
                                           (make-span-end-node 'cl 'body 'exit #f))
                                     (span-tail/exit))))
                     '())))
    ;; --- a closing span's EOF tail, and the span-name cross-reference --------
    (harness-case "a span end continuing into a STOP is rejected (§16.2:909)"
      (lambda ()
        ;; *** THE REASON `span-tail/exit` EXISTS, stated as a rejection so the
        ;; tail above cannot be mistaken for cosmetics. *** A span end is a
        ;; PARKED state: its data callback's pause parks the parser on that
        ;; node's completion substep, and a `parser-finish!` from there resumes
        ;; past the span end. Reaching a stop that way is what
        ;; eof-reachable-stop forbids, and it is reachable: without the check
        ;; this machine verifies CLEAN and then answers `stopped` from
        ;; `parser-finish!`.
        ;;
        ;; The diagnostic is reported at `cl`, not at `done`: the parked node is
        ;; what a caller can be sitting on, and `parked-eof-start` is where its
        ;; start differs from its name.
        (check-equal "one finding, at the span end"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'body 'cl #f)
                                           (make-span-end-node 'cl 'body 'done #f))
                                     (span-tail))))))
                     ;; *** AND EXACTLY ONE FINDING. *** A span START is not a
                     ;; parked state: it
                     ;; calls nothing, so nothing can pause there, and it stays
                     ;; flow-through like a field action. `op` reaches the same
                     ;; stop, so a parked set widened to BOTH span kinds would
                     ;; report `(eof-reachable-stop . op)` here too -- the list,
                     ;; not the membership, is what says which half moved.
                     '((eof-reachable-stop . cl)))))
    (harness-case "a span node naming an UNDECLARED span is rejected (§16.2:901)"
      (lambda ()
        ;; `make-span-start-node` stores its span as a bare symbol and its own
        ;; comment assigns the cross-reference to the verifier. Without the
        ;; check this machine verifies CLEAN and then raises
        ;; `assertion-violation` out of `normalize-machine` -- a verified
        ;; machine crashing the normalizer, which must never happen.
        ;;
        ;; BOTH kinds, because each carries its own accessor and a fix reaching
        ;; only one would be invisible to a single-node fixture.
        (check-equal "one finding per node"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'nosuch 'cl #f)
                                           (make-span-end-node 'cl 'nosuch 'exit #f))
                                     (span-tail/exit))))))
                     '((missing-span-declaration . op) (missing-span-declaration . cl)))))
    (harness-case "and a span node naming a DECLARED span is not"
      (lambda ()
        ;; The negative control: the check must not reject every span node.
        ;; `other` is declared and never opened, which is legal -- only the
        ;; cross-reference is checked here.
        (check-equal "no diagnostics"
                     (codes (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'other 'cl #f)
                                           (make-span-end-node 'cl 'other 'exit #f))
                                     (span-tail/exit))))
                     '())))
    (harness-case "span RE-ENTRY: a second start for the same span"
      (lambda ()
        (check-equal "one finding, at the second start"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'body 'op2 #f)
                                           (make-span-start-node 'op2 'body 'cl #f)
                                           (make-span-end-node 'cl 'body 'exit #f))
                                     (span-tail/exit))))))
                     '((invalid-span-state . op2)))))
    (harness-case "span OVERLAP: a start for a different span while one is open"
      (lambda ()
        ;; Nesting gets no row of its own: with one span permitted active,
        ;; nesting IS a start on (active t).
        (check-equal "one finding, at the second start"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'body 'op2 #f)
                                           (make-span-start-node 'op2 'other 'cl #f)
                                           (make-span-end-node 'cl 'other 'exit #f))
                                     (span-tail/exit))))))
                     '((invalid-span-state . op2)))))
    (harness-case "WRONG END: closing a span that is not the one open"
      (lambda ()
        (check-equal "one finding, at the end"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'body 'cl #f)
                                           (make-span-end-node 'cl 'other 'exit #f))
                                     (span-tail/exit))))))
                     '((invalid-span-state . cl)))))
    (harness-case "UNMATCHED END: closing with nothing open"
      (lambda ()
        (check-equal "one finding, at the end"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'cl)
                                           (make-span-end-node 'cl 'body 'exit #f))
                                     (span-tail/exit))))))
                     '((invalid-span-state . cl)))))
    (harness-case "INCONSISTENT: two branches disagree at a merge"
      (lambda ()
        ;; The row that makes the flat lattice the right domain rather than the
        ;; powerset: the two branches AGREE that
        ;; the machine is well formed under a path-existential reading, and
        ;; disagree about the state at `mrg`. Reported where it arises.
        (check-equal "one finding, at the merge"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-fork 'op 'mrg)
                                           (make-span-start-node 'op 'body 'mrg #f)
                                           (make-byte-dispatch-node 'mrg
                                             (list (case-to 'done))
                                             (make-edge 'reject 'reexecute) #f #f))
                                     (span-tail2))))))
                     '((inconsistent-span-state . mrg)))))
    (harness-case "a span open at an ERROR terminal is ACCEPTED"
      (lambda ()
        ;; Errors do not flush a final fragment or synthesize a completion, so a
        ;; span may be open at one. Only the SUCCESSFUL terminals are rejected,
        ;; which is why `finish` stays distinguished from `error`.
        (check-equal "no diagnostics"
                     (codes (span-machine
                             (append (list (entry-fork 'op 'done)
                                           (make-span-start-node 'op 'body 'reject #f))
                                     (span-tail2))))
                     '())))
    (harness-case "a span open at a STOP terminal is rejected (§16.2:907)"
      (lambda ()
        (check-equal "one finding, at the terminal"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'op)
                                           (make-span-start-node 'op 'body 'done #f))
                                     (span-tail))))))
                     '((span-active-at-exit . done)))))
    (harness-case "a span open at an EOF-ONLY finish is rejected too"
      (lambda ()
        ;; *** The pass's EDGE set must include eof-targets. *** A dataflow over
        ;; `node-out-targets` alone never arrives at a finish node that is only
        ;; EOF-reachable, because that accessor excludes eof-targets by
        ;; construction. This machine has no byte path to `fin` at all.
        (check-equal "one finding, at the finish"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             (append (list (entry-to 'done 'op)
                                           (make-span-start-node 'op 'body 'fin #f)
                                           (make-finish-node 'fin #f))
                                     (span-tail))))))
                     '((span-active-at-exit . fin)))))
    (harness-case "a PAUSE reachable with a span active is rejected (§16.2:900)"
      (lambda ()
        (check-equal "one finding, at the pause"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (span-machine
                             ;; `cl` continues to the ERROR node and not the
                             ;; stop: a byte-reachable pause is a parked state,
                             ;; so its own EOF walk runs, and a stop on that
                             ;; chain is an eof-reachable-stop -- a second
                             ;; finding this case is not about.
                             (append (list (entry-fork 'op 'done)
                                           (make-span-start-node 'op 'body 'p #f)
                                           (make-pause-node 'p 'cl #f)
                                           (make-span-end-node 'cl 'body 'reject #f))
                                     (span-tail2))))))
                     '((span-active-at-pause . p)))))
    (harness-case "a CALLBACK invocation reachable with a span active is the same finding"
      (lambda ()
        ;; The one exception -- only the active span's own data callback may
        ;; pause before the span closes -- cannot apply to a NODE: a callback
        ;; node admits only `event` and `decision` callbacks, and a
        ;; span-data callback is reached through a span declaration and the
        ;; runtime's flush, never through a callback node.
        (check-equal "one finding, at the invocation"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (make-machine 'spanm 'start '()
                                          (list sd-decl
                                                (make-callback-declaration 'note 'event #t
                                                                           '() #f #f))
                                          (list (make-span-declaration 'body 'on-data #f #f))
                                          errs
                                          (append (list (entry-fork 'op 'done)
                                                        (make-span-start-node 'op 'body 'inv #f)
                                                        (make-callback-node 'inv 'note 'cl
                                                                            '() 'cl #f)
                                                        (make-span-end-node 'cl 'body 'reject #f))
                                                  (span-tail2))
                                          'default-eof #f))))
                     '((span-active-at-pause . inv)))))
    (harness-case "a node no execution can occupy contributes no state (0029 item 3)"
      (lambda ()
        ;; *** The only shape that separates the two relations. *** The entry's
        ;; byte edges go
        ;; to the error node and its EOF route goes to `t`; `t` is reachable ONLY
        ;; that way, and `cl` -- an unmatched span end -- hangs off `t`'s BYTE
        ;; edge. No execution can occupy `cl`: once an execution takes an
        ;; eof-target it can never feed again, so `cl`'s byte edge is
        ;; untakeable and pass 7 must not report its unmatched end.
        ;;
        ;; `pass-reachability` walks the occupiable relation, so `cl` and
        ;; everything behind it -- `exit`, `done`, `fin` -- are reported
        ;; `unreachable-node`, in machine-node order. The property this case
        ;; owns is the OTHER half: whatever pass 4 says about the node domain,
        ;; pass 7 must not report an unmatched end there. The second check below
        ;; asserts that half on its own, so a span code appearing here fails a
        ;; check whose label says span.
        ;;
        ;; An orphan with no in-edges at all does NOT test this -- it receives
        ;; no state under either relation, so a mutation of the relation
        ;; survives it.
        (let ((ds (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                       (verification-diagnostics
                        (verify-machine
                         (span-machine
                          (append (list (make-byte-dispatch-node 'start
                                          (list (case-to 'reject))
                                          (make-edge 'reject 'reexecute) 't #f)
                                        (make-byte-dispatch-node 't
                                          (list (case-to 'cl))
                                          (make-edge 'reject 'reexecute) 'reject #f)
                                        (make-span-end-node 'cl 'body 'exit #f))
                                  (span-tail/exit))))))))
          (check-equal "the span end on the untakeable byte edge is not reported"
                       ds
                       '((unreachable-node . cl) (unreachable-node . exit)
                         (unreachable-node . done) (unreachable-node . fin)))
          ;; Derived, not a literal census of span codes: anything pass 7 (or
          ;; any other pass) had to say about this machine would appear here.
          ;; Seeded so it cannot pass by never being computed.
          (let ((others 'seed))
            (set! others (filter (lambda (c) (not (eq? c 'unreachable-node)))
                                 (map car ds)))
            (check-equal "and pass 7 says nothing about the span: pass 4 is the only reporter here"
                         others '())))))))

;; --- the label clause of the portability check ---------------------------------
;;
;; The verifier rejects "nonportable names, codes, branch keys, labels, or
;; reasons". These cases cover declaration labels, and the two declaration NAME
;; arms the label fixtures share.
(define (label-machine cb-label sp-label)
  (make-machine 'labm 'start '()
                (list (make-callback-declaration 'on-data 'span-data #t '() #f cb-label))
                (list (make-span-declaration 'body 'on-data #f sp-label))
                errs
                (list (make-byte-dispatch-node 'start (list (case-to 'done))
                                               (make-edge 'reject 'reexecute) #f #f)
                      (make-stop-node 'done #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f))

(define (named-machine cb-name sp-name)
  (make-machine 'labm 'start '()
                (list (make-callback-declaration cb-name 'span-data #t '() #f #f))
                (list (make-span-declaration sp-name cb-name #f #f))
                errs
                (list (make-byte-dispatch-node 'start (list (case-to 'done))
                                               (make-edge 'reject 'reexecute) #f #f)
                      (make-stop-node 'done #f)
                      (make-error-node 'reject 'rejected #f))
                'default-eof #f))

(harness-group "declaration labels are checked against §10.1:480 (§16.2:886)"
  (lambda ()
    (harness-case "THE NEGATIVE CONTROL: absent and portable labels are accepted"
      (lambda ()
        ;; First, deliberately. Without it every rejection below is satisfied by
        ;; an arm that rejects every declaration -- and `#f` is the label every
        ;; fixture in the tree actually carries, so an arm that rejected absence
        ;; would redden the whole suite instead of this case, and the diagnosis
        ;; would start somewhere else.
        (check-equal "both absent" (codes (label-machine #f #f)) '())
        (check-equal "both portable symbols"
                     (codes (label-machine 'the-label 'other-label)) '())
        (check-equal "a portable STRING is accepted too"
                     (codes (label-machine "Span: body (outer)" #f)) '())
        ;; The repertoire says nothing about length, and the empty reason is
        ;; accepted on that ground already.
        (check-equal "and the empty string" (codes (label-machine "" #f)) '())))
    (harness-case "a nonportable CALLBACK label is rejected"
      (lambda ()
        ;; A tab is the sharp case: it is ASCII, it is invisible, and it is
        ;; outside the "printable ASCII plus LF" repertoire -- `reason-char?`'s
        ;; range starts at space (0x20), so 0x09 fails. A test using a
        ;; non-ASCII character would pass against a mutant that only checked the
        ;; high bit.
        (check-equal "one finding, on the callback"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (label-machine (string->symbol "a\tb") #f))))
                     '((invalid-name . on-data)))))
    (harness-case "a nonportable SPAN label is rejected, and separately"
      (lambda ()
        ;; BOTH families, because each reads its own accessor and a fix reaching
        ;; only one would be invisible to a single-family fixture -- the same
        ;; argument the undeclared-span case makes.
        (check-equal "one finding, on the span"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (label-machine #f (string->symbol "a\tb")))))
                     '((invalid-name . body)))))
    (harness-case "DEL and a non-ASCII character are both rejected"
      (lambda ()
        ;; The two ends of the repertoire. `reason-char?` bounds at `#\~` (0x7E),
        ;; so DEL (0x7F) is out -- a mutant widening the bound to 0x7F passes a
        ;; high-bit test and fails this one.
        (check-equal "DEL"
                     (codes (label-machine (string->symbol (string (integer->char 127))) #f))
                     '(invalid-name))
        (check-equal "U+00E9"
                     (codes (label-machine (string->symbol "caf\xe9;") #f))
                     '(invalid-name))))
    (harness-case "a nonportable STRING label is rejected too"
      (lambda ()
        ;; The string arm's rejecting direction; the negative control asserts
        ;; it ACCEPTS a portable string. Both directions are needed: either
        ;; alone is satisfied by a constant.
        (check-equal "a tab in a string label"
                     (codes (label-machine "a\tb" #f)) '(invalid-name))))
    (harness-case "a label of the wrong SHAPE is rejected, not ignored"
      (lambda ()
        ;; No constructor validates this field, and its only stated type is
        ;; "optional diagnostic label". A label the diagnostic reporter cannot
        ;; render is not a machine that verified clean, so it is reported; why it
        ;; is reported under a PORTABILITY code is recorded at the predicate.
        (check-equal "an integer on the callback"
                     (codes (label-machine 42 #f)) '(invalid-name))
        ;; *** BOTH FAMILIES, and this one is load-bearing for the PINS. *** The
        ;; shape arm is the only label check the reason mutants cannot reach --
        ;; `valid-label?`'s `(else #f)` rejects an integer without consulting the
        ;; repertoire at all -- so it is the case that gives a per-family
        ;; conjunct mutant a record of its own. With the integer only on the
        ;; callback, a mutant dropping the SPAN family's label conjunct would be
        ;; wholly nested inside the permissive-`reason-char?` mutant and could
        ;; not be pinned; this line separates them.
        (check-equal "an integer on the span"
                     (codes (label-machine #f 42)) '(invalid-name))))
    (harness-case "a declaration bad in BOTH name and label reports ONCE"
      (lambda ()
        ;; The fold's own assertion, and the reason the label clause went into
        ;; the name clause's `and` rather than into an arm of its own -- the
        ;; same shape as the reason clause, witnessed by "one declaration bad in
        ;; every field still yields a single finding". Two arms would report
        ;; this declaration twice.
        (check-equal "one finding, not two"
                     (codes (make-machine 'labm 'start '()
                              (list (make-callback-declaration
                                     'Bad 'span-data #t '() #f (string->symbol "a\tb")))
                              (list (make-span-declaration 'body 'Bad #f #f))
                              errs
                              (list (make-byte-dispatch-node 'start (list (case-to 'done))
                                                             (make-edge 'reject 'reexecute) #f #f)
                                    (make-stop-node 'done #f)
                                    (make-error-node 'reject 'rejected #f))
                              'default-eof #f))
                     '(invalid-name))))))

;; --- every label carrier -------------------------------------------------------
;;
;; Nineteen constructors take a `source-label`. The two declaration families are
;; checked in the group above; the other SEVENTEEN are driven here from one
;; table, each built with the label under test and nothing else wrong, each
;; asserted in BOTH directions -- an integer label is rejected
;; under the carrier's own name (a byte case's or sequence case's under the
;; OWNING NODE, because a case has no name), and a portable symbol and a portable
;; string are accepted -- so an arm rejecting every carrier fails as loudly as
;; one rejecting none.
;;
;; The rejection fixture is a wrong-SHAPE label, not a bad character, and that is
;; a constraint the pins impose: every label conjunct is nested inside the
;; permissive-`reason-char?` mutant unless the fixture carries a value that
;; mutant cannot accept, and `valid-label?`'s `(else #f)` rejects an integer
;; without consulting the repertoire (the span-family pin's own reason, one
;; group up).
(define (labelled-machine name fields cbs sps errors nodes)
  (make-machine name 'start fields cbs sps errors nodes 'default-eof #f))
(define (plain-entry . eof)
  (make-byte-dispatch-node 'start (list (case-to 'done)) (make-edge 'reject 'reexecute)
                           (if (null? eof) #f (car eof)) #f))
;; Byte 0 into the node under test, byte 1 into the stop, so `done` stays
;; byte-reachable in every row -- a parked node's continuation cannot be the
;; stop (eof-reachable-stop), so the stop is reached from the entry instead.
(define (entry-into target)
  (make-byte-dispatch-node 'start
                           (list (case-to target)
                                 (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'done 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f))
(define done (make-stop-node 'done #f))
(define reject (make-error-node 'reject 'rejected #f))
(define count-field (make-uint-field 'count 8 0 #f))
(define (with-nodes . ns) (labelled-machine 'labm '() '() '() errs ns))
;; The span rows carry member3-drift-tests.sps's span shape: a
;; consuming node INSIDE the span with its own EOF terminal (the shared `reject`
;; is reached with no span open, and merging `(active sp)` with `none` at one
;; node is a rejection), and a DISPATCH after the span end, never the stop,
;; because a span end is a parked state.
(define span-chain-cbs (list (make-callback-declaration 'on-data 'span-data #t '() #f #f)))
(define span-chain-sps (list (make-span-declaration 'sp 'on-data #f #f)))
(define (span-nodes start-label end-label)
  (list (entry-into 'ss)
        (make-span-start-node 'ss 'sp 'sread start-label)
        (make-byte-dispatch-node 'sread
          (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'se 'reexecute) #f))
          (make-edge 'sread 'advance) 'rej2 #f)
        (make-error-node 'rej2 'rejected #f)
        (make-span-end-node 'se 'sp 'after end-label)
        (make-byte-dispatch-node 'after (list (case-to 'done)) (make-edge 'reject 'reexecute) #f #f)
        done reject))

;; (carrier expected-node build), build: label -> machine
(define label-carrier-rows
  (list
   (list 'machine 'labm
         (lambda (l) (make-machine 'labm 'start '() '() '() errs
                                   (list (plain-entry) done reject) 'default-eof l)))
   (list 'uint-field 'count
         (lambda (l) (labelled-machine 'labm (list (make-uint-field 'count 8 0 l)) '() '() errs
                                       (list (plain-entry) done reject))))
   (list 'error-declaration 'rejected
         (lambda (l) (labelled-machine 'labm '() '() '()
                                       (list eof-decl
                                             (make-error-declaration 'rejected 'unexpected-byte
                                                                     "unexpected byte" l))
                                       (list (plain-entry) done reject))))
   (list 'byte-case 'start
         (lambda (l) (with-nodes (make-byte-dispatch-node
                                  'start
                                  (list (make-byte-case (make-exact-byte-matcher 0)
                                                        (make-edge 'done 'advance) l))
                                  (make-edge 'reject 'reexecute) #f #f)
                                 done reject)))
   (list 'sequence-case 'start
         (lambda (l) (with-nodes (make-sequence-dispatch-node
                                  'start (list (make-sequence-case '(1) 'done l))
                                  (make-edge 'reject 'reexecute) #f #f)
                                 done reject)))
   (list 'byte-dispatch 'start
         (lambda (l) (with-nodes (make-byte-dispatch-node
                                  'start (list (case-to 'done))
                                  (make-edge 'reject 'reexecute) #f l)
                                 done reject)))
   (list 'sequence-dispatch 'start
         (lambda (l) (with-nodes (make-sequence-dispatch-node
                                  'start (list (make-sequence-case '(1) 'done #f))
                                  (make-edge 'reject 'reexecute) #f l)
                                 done reject)))
   (list 'stop 'done
         (lambda (l) (with-nodes (plain-entry) (make-stop-node 'done l) reject)))
   (list 'error 'reject
         (lambda (l) (with-nodes (plain-entry) done (make-error-node 'reject 'rejected l))))
   (list 'finish 'fin
         (lambda (l) (with-nodes (plain-entry 'fin) done reject (make-finish-node 'fin l))))
   ;; A pause's continuation is the ERROR node and not the stop: a parser parked
   ;; there resumes on that one edge, so a stop there is an eof-reachable-stop
   ;; finding.
   (list 'pause 'p
         (lambda (l) (with-nodes (entry-into 'p) (make-pause-node 'p 'reject l) done reject)))
   (list 'field-action 'fa
         (lambda (l) (labelled-machine 'labm (list count-field) '() '() errs
                                       (list (entry-into 'fa)
                                             (make-field-action-node 'fa 'clear '(count) 'done #f l)
                                             done reject))))
   (list 'field-branch 'fb
         (lambda (l) (labelled-machine 'labm (list count-field) '() '() errs
                                       (list (entry-into 'fb)
                                             (make-field-branch-node 'fb 'zero '(count)
                                                                     'done 'reject l)
                                             done reject))))
   (list 'integer-accumulate 'acc
         (lambda (l) (labelled-machine 'labm (list count-field) '() '() errs
                                       (list (entry-into 'acc)
                                             (make-integer-accumulate-node
                                              'acc 'count 10 'acc (make-edge 'done 'advance)
                                              'reject #f l)
                                             done reject))))
   ;; The pause continuation is the ERROR node and not the stop: a byte-reachable
   ;; callback is a parked state whose walk starts on that one edge, and a stop
   ;; there is an eof-reachable-stop finding -- the t2-hop row records the same
   ;; choice.
   (list 'callback 'cn
         (lambda (l) (labelled-machine 'labm '()
                                       (list (make-callback-declaration 'cb 'event #t '() #f #f))
                                       '() errs
                                       (list (entry-into 'cn)
                                             (make-callback-node 'cn 'cb 'done '() 'reject l)
                                             done reject))))
   (list 'span-start 'ss
         (lambda (l) (labelled-machine 'labm '() span-chain-cbs span-chain-sps errs
                                       (span-nodes l #f))))
   (list 'span-end 'se
         (lambda (l) (labelled-machine 'labm '() span-chain-cbs span-chain-sps errs
                                       (span-nodes #f l))))))

(define (code+node m)
  (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
       (verification-diagnostics (verify-machine m))))

(harness-group "every label carrier is checked (§16.2:886, Milestone 6 Slice ⓪)"
  (lambda ()
    (harness-case "an integer label is rejected under the carrier's own name"
      (lambda ()
        ;; One check per row, LABELLED BY CARRIER, so a mutant dropping one arm's
        ;; conjunct has a (case, check) pair of its own to be pinned on.
        (let ((driven 0))
          (for-each
           (lambda (row)
             (set! driven (+ driven 1))
             (let ((carrier (car row)) (node (cadr row)) (build (caddr row)))
               ;; `pass-fields` owns the field arm and reports under ITS code;
               ;; the other three arms are `pass-names-valid`'s.
               (check-equal (string-append (symbol->string carrier) ": integer label")
                            (code+node (build 42))
                            (list (cons (if (eq? carrier 'uint-field)
                                            'invalid-field-declaration
                                            'invalid-name)
                                        node)))))
           label-carrier-rows)
          (check-equal "seventeen carriers driven" driven 17)
          (check-equal "and the table has seventeen rows" (length label-carrier-rows) 17))))
    (harness-case "a portable symbol and a portable string are accepted"
      (lambda ()
        ;; THE NEGATIVE CONTROL, per carrier: without it every rejection above is
        ;; satisfied by an arm that rejects every label. The `#f` every fixture
        ;; in the tree carries is asserted too, since an arm rejecting absence
        ;; would redden the whole suite instead of this case.
        (let ((driven 0))
          (for-each
           (lambda (row)
             (set! driven (+ driven 1))
             (let ((carrier (car row)) (build (caddr row)))
               (check-equal (string-append (symbol->string carrier) ": portable labels")
                            (append (codes (build #f))
                                    (codes (build 'the-label))
                                    (codes (build "Body: outer (bytes)")))
                            '())))
           label-carrier-rows)
          (check-equal "seventeen carriers driven both ways" driven 17))))
    (harness-case "a node bad in name, label AND a case label reports ONCE"
      (lambda ()
        ;; The fold's own assertion, and the reason the label clause and the
        ;; case-label clause went into the name clause's `and` rather than into
        ;; arms of their own: three faults on one node, one finding.
        (check-equal "one finding, not three"
                     (codes (make-machine 'labm 'Bad '() '() '() errs
                              (list (make-byte-dispatch-node
                                     'Bad
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 'done 'advance) 42))
                                     (make-edge 'reject 'reexecute) #f 42)
                                    done reject)
                              'default-eof #f))
                     '(invalid-name))))))

(harness-group "declaration NAMES are checked too, which nothing witnessed (§16.2:886)"
  (lambda ()
    (harness-case "a nonportable callback name and a nonportable span name"
      (lambda ()
        ;; Uppercase is the grammar's own boundary: `valid-name?` requires
        ;; `[a-z]` first.
        (check-equal "the callback"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (named-machine 'Bad 'body))))
                     '((invalid-name . Bad)))
        (check-equal "the span"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine (named-machine 'on-data 'Body))))
                     '((invalid-name . Body)))))
    (harness-case "and portable names on their own are clean"
      (lambda ()
        (check-equal "no diagnostics" (codes (named-machine 'on-data 'body)) '())))))

;; *** Gating zero-progress cycles on byte-reachability is a RELAXATION, and
;; `unreachable-node` does not make it benign. *** The machine below is not
;; rejected by `unreachable-node`: `t` is the entry's eof-target, so it is
;; OCCUPIABLE -- the EOF walk starts at the parked entry and visits it. What no
;; execution can take here is an EDGE, `t`'s own self-loop, and
;; `unreachable-node` quantifies over nodes. This is a COLLAPSED variant of the
;; `E ->(eof) T ->(byte) Z` family in the occupiable-relation group below: here
;; `t` plays both T and Z, its case edge the self-loop. That is exactly why
;; `unreachable-node` does not fire: the family needs a `Z` the walk cannot
;; reach, and this fixture has none. It is asserted BOTH ways -- the cycle is
;; real, and no execution can enter it.

(harness-group "zero-progress cycles are gated on byte-reachability (§16.2:898)"
  (lambda ()
    (harness-case "a BYTE-reachable pause cycle is still a zero-progress cycle"
      (lambda ()
        ;; *** The REPORT set's pause clause needs a BYTE-reachable cycle to be
        ;; witnessed at all, *** because the gate excludes an EOF-ONLY pause
        ;; cycle on purpose. `pa` and `pb` are entered by a byte edge and cycle
        ;; through each other's continuations.
        (check "zero-progress-cycle is reported"
               (memq 'zero-progress-cycle
                     (codes (machine*
                             'bpause
                             (list (make-byte-dispatch-node 'start
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 'pa 'advance) #f))
                                     (make-edge 'reject 'reexecute) #f #f)
                                   (make-pause-node 'pa 'pb #f)
                                   (make-pause-node 'pb 'pa #f)
                                   (make-error-node 'reject 'rejected #f))
                             'default-eof))))))
    (harness-case "an unoccupiable zero-progress cycle is accepted"
      (lambda ()
        ;; `e`'s byte edges all reach the error node and its EOF route reaches
        ;; `t`; `t` is a byte-dispatch reachable only that way, holding a
        ;; reexecute self-loop. Once an execution takes an eof-target it can
        ;; never feed again, so `t`'s self-loop is untakeable.
        (check-equal "no diagnostics at all"
                     (codes (machine*
                             'gated
                             (list (make-byte-dispatch-node 'start
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 'reject 'advance) #f))
                                     (make-edge 'reject 'reexecute) 't #f)
                                   (make-byte-dispatch-node 't
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 't 'reexecute) #f))
                                     (make-edge 'reject 'reexecute) 'reject #f)
                                   (make-error-node 'reject 'rejected #f))
                             'default-eof))
                     '())))
    (harness-case "and `unreachable-node` does NOT catch it, which is why the gate is not benign"
      (lambda ()
        ;; Asserted rather than argued: the very same machine passes
        ;; `pass-reachability` too, so an ungated cycle check would be the ONLY
        ;; thing rejecting it.
        (check "t is not reported unreachable"
               (not (memq 'unreachable-node
                          (codes (machine*
                                  'gated
                                  (list (make-byte-dispatch-node 'start
                                          (list (make-byte-case (make-exact-byte-matcher 0)
                                                                (make-edge 'reject 'advance) #f))
                                          (make-edge 'reject 'reexecute) 't #f)
                                        (make-byte-dispatch-node 't
                                          (list (make-byte-case (make-exact-byte-matcher 0)
                                                                (make-edge 't 'reexecute) #f))
                                          (make-edge 'reject 'reexecute) 'reject #f)
                                        (make-error-node 'reject 'rejected #f))
                                  'default-eof)))))))
    (harness-case "the SAME cycle on a byte-reachable node is still rejected"
      (lambda ()
        ;; The reverse direction, without which the gate could be vacuous: one
        ;; byte edge from the entry into `t` and the finding comes back.
        (check-equal "zero-progress-cycle, at t"
                     (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
                          (verification-diagnostics
                           (verify-machine
                            (machine*
                             'gated
                             (list (make-byte-dispatch-node 'start
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 't 'advance) #f))
                                     (make-edge 'reject 'reexecute) 't #f)
                                   (make-byte-dispatch-node 't
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 't 'reexecute) #f))
                                     (make-edge 'reject 'reexecute) 'reject #f)
                                   (make-error-node 'reject 'rejected #f))
                             'default-eof))))
                     '((zero-progress-cycle . t)))))))

;; --- reachability is the occupiable relation -----------------------------------
;;
;; `pass-reachability` walks byte-reached ∪ the EOF walk from the parked set --
;; the relation the EOF checks and pass 7 use -- not a walk that crosses an
;; eof-target and then keeps taking byte edges. The family that separates the
;; two is `E ->(eof) T ->(byte) Z`: T
;; reachable only through an EOF route and one of the three kinds whose byte
;; edges are dead at EOF, Z distinct from T and reachable only through such an
;; edge. Each kind is asserted BOTH ways -- Z dead, rejected by name; the same
;; machine with Z also byte-reachable from the entry, accepted -- and the two
;; shapes a reader will try are ACCEPTED controls: Z = T (a self-loop; T is
;; occupiable through the EOF route) and T a counted consume (its `next` is an
;; EOF successor).

;; Z: a byte-dispatch whose case and fallback edges land on the error node and
;; which carries NO EOF route of its own. It has no finding of its own under
;; either relation -- `unreachable-node` when only T's dead byte edge reaches
;; it, nothing when the entry also reaches it by a byte edge -- so what the
;; cases below read is the RELATION and not a second property of Z.
(define occ-z
  (make-byte-dispatch-node 'z (list (case-to 'reject))
                           (make-edge 'reject 'reexecute) #f #f))

;; T: the node the entry reaches ONLY as its eof-target, in each of the three
;; kinds whose byte edges are dead at EOF. Each carries its own EOF route (to
;; the error node), so the EOF walk leaves T by that route and never by the
;; edge to Z -- which is the whole of why Z is unoccupiable.
(define (occ-t kind)
  (case kind
    ((byte-dispatch)
     (make-byte-dispatch-node 't
       (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'z 'advance) #f))
       (make-edge 'reject 'reexecute) 'reject #f))
    ((sequence-dispatch)
     (make-sequence-dispatch-node 't (list (make-sequence-case '(1) 'z #f))
       (make-edge 'reject 'reexecute) 'reject #f))
    ((integer-accumulate)
     (make-integer-accumulate-node 't 'n 10 'z (make-edge 'reject 'advance)
                                   'reject 'reject #f))
    (else (assertion-violation 'occ-t "no such kind" kind))))

;; The entry: byte edges to the error node, EOF route to T. The ACCEPTED twin
;; adds ONE byte case reaching Z directly -- the only difference between the two
;; halves of every pair below, so the pair isolates "Z is byte-reachable".
(define (occ-entry z-byte-reachable?)
  (make-byte-dispatch-node 'start
    (cons (case-to 'reject)
          (if z-byte-reachable?
              (list (make-byte-case (make-exact-byte-matcher 1)
                                    (make-edge 'z 'advance) #f))
              '()))
    (make-edge 'reject 'reexecute) 't #f))

(define (occ-machine nodes)
  (make-machine 'occ 'start (list (make-uint-field 'n 8 0 #f)) '() '() errs
                nodes 'default-eof #f))

(define (occ-findings m)
  (map (lambda (d) (cons (diagnostic-code d) (diagnostic-node d)))
       (verification-diagnostics (verify-machine m))))

(define occ-reject (make-error-node 'reject 'rejected #f))

(harness-group "reachability is the occupiable relation (decision 0031)"
  (lambda ()
    (harness-case "per input-reading kind, both ways"
      (lambda ()
        ;; The labels are built from the kind's own name, so the three pairs are
        ;; six distinct (case, check) records and a pin can name one of them.
        (let ((driven 0))
          (for-each
           (lambda (k)
             (set! driven (+ driven 1))
             (let ((name (symbol->string k)))
               (check-equal (string-append name ": Z reachable only through T's dead byte edge is unreachable")
                            (occ-findings
                             (occ-machine (list (occ-entry #f) (occ-t k)
                                                occ-z occ-reject)))
                            '((unreachable-node . z)))
               (check-equal (string-append name ": the same machine with Z byte-reachable from the entry verifies clean")
                            (occ-findings
                             (occ-machine (list (occ-entry #t) (occ-t k)
                                                occ-z occ-reject)))
                            '())))
           '(byte-dispatch sequence-dispatch integer-accumulate))
          ;; The sentinel reads the loop's own counter, not the expectation: a
          ;; kind dropped from the list above takes this check red.
          (check-equal "all three input-reading kinds driven" driven 3))))
    (harness-case "and transitively, through Z's own EOF route"
      (lambda ()
        ;; Z here carries an EOF route to a finish nothing else names. A walk
        ;; that crosses an eof-target and keeps taking byte edges reaches both;
        ;; the occupiable relation reaches neither, and they are reported in
        ;; machine-node order.
        (check-equal "Z and the finish behind its EOF route are both unreachable"
                     (occ-findings
                      (occ-machine
                       (list (occ-entry #f) (occ-t 'byte-dispatch)
                             (make-byte-dispatch-node 'z (list (case-to 'reject))
                                                      (make-edge 'reject 'reexecute) 'fin #f)
                             (make-finish-node 'fin #f)
                             occ-reject)))
                     '((unreachable-node . z) (unreachable-node . fin)))))
    (harness-case "an orphan beside the family, so the two ways of breaking pass 4 differ"
      (lambda ()
        ;; *** COUNT, DON'T WITNESS. *** Every check above that expects a
        ;; FINDING -- the three REJECTED halves and the transitive case; not the
        ;; three ACCEPTED twins, which answer `()` under both, nor the sentinel
        ;; -- is reddened by "verify: pass 4 walks the retired relation instead
        ;; of the occupiable one" AND by "verify: reachability never reports an
        ;; unreachable node", with the identical `got ()` --
        ;; the second mutant suppresses a SUPERSET of what the first suppresses,
        ;; on every machine, so no check whose expectation is a family finding
        ;; alone can tell them apart. This machine carries BOTH kinds of
        ;; unoccupiable node: `z`, dead only under the narrowing, and `orphan`,
        ;; an error node with no in-edge at all, dead under either relation. The
        ;; eof-crossing walk therefore leaves `orphan` reported and the suppressed
        ;; emission leaves nothing, and the two mutants produce different `got`
        ;; lists from this one check.
        (check-equal "both unoccupiable nodes, the family's and the orphan's"
                     (occ-findings
                      (occ-machine
                       (list (occ-entry #f) (occ-t 'byte-dispatch) occ-z
                             (make-error-node 'orphan 'rejected #f)
                             occ-reject)))
                     '((unreachable-node . z) (unreachable-node . orphan)))))
    (harness-case "control: Z is T itself"
      (lambda ()
        ;; The first shape a reader will try, and it is NOT the family: T is
        ;; occupiable through the entry's EOF route, so an edge back to itself
        ;; reaches nothing new. The zero-progress gate fixture above has exactly
        ;; this shape, which is why `unreachable-node` does not fire on it.
        (check-equal "T's self-loop reaches nothing the EOF walk has not visited"
                     (occ-findings
                      (occ-machine
                       (list (occ-entry #f)
                             (make-byte-dispatch-node 't
                               (list (make-byte-case (make-exact-byte-matcher 1)
                                                     (make-edge 't 'advance) #f))
                               (make-edge 'reject 'reexecute) 'reject #f)
                             occ-reject)))
                     '())))
    (harness-case "control: a counted consume as T"
      (lambda ()
        ;; The fourth input-reading kind is NOT in the family: a counted
        ;; consume's `next` is an EOF successor, so the walk
        ;; from the entry visits Z through it. Z stays a dispatch with a #f EOF
        ;; route -- `default-error`, tier 0 -- because a STOP there would be
        ;; `eof-reachable-stop` at the entry and this control would stop being
        ;; about reachability.
        (check-equal "the counted consume's next is visited on the EOF walk"
                     (occ-findings
                      (occ-machine
                       (list (occ-entry #f)
                             (make-counted-consume-node 't 'n 'z 'reject #f)
                             occ-z occ-reject)))
                     '())))))

;; --- the counted-consume kind in the verifier census ---------------------------
;;
;; Fixtures by shape. `done` and `reject` are the shared stop
;; and error nodes defined for the label group above; `entry-into` reaches the
;; node under test on byte 0 and the stop on byte 1, so every node is reachable.
(define len-field (list (make-uint-field 'len 8 0 #f)))
(define (cc-machine entry fields nodes)
  (make-machine 'ccm entry fields '() '() errs nodes 'default-eof #f))

(harness-group "the thirteenth kind in the verifier census (Milestone 6 Slice ①)"
  (lambda ()
    (harness-case "the flow-through zero-count stop at the ENTRY is rejected (0030 item 5)"
      (lambda ()
        ;; A fresh parser is parked at the entry with the field's initial, 0; a
        ;; zero count transitions to `next` at finish, and `next` is a stop --
        ;; the eof-reachable-stop prohibition. A dispatch-shaped classify arm
        ;; never sees `next`, and this machine verifies clean under one.
        (let ((m (cc-machine 'body len-field
                             (list (make-counted-consume-node 'body 'len 'done #f #f) done))))
          (check-equal "eof-reachable-stop, at the entry"
                       (map cons (codes m) (nodes-of m))
                       '((eof-reachable-stop . body))))))
    (harness-case "the same through a pause continuation is rejected at the pause"
      (lambda ()
        (let ((m (cc-machine 'start len-field
                             (list (entry-to 'p)
                                   (make-pause-node 'p 'body #f)
                                   (make-counted-consume-node 'body 'len 'done #f #f)
                                   done reject))))
          (check-equal "eof-reachable-stop, at the pause"
                       (map cons (codes m) (nodes-of m))
                       '((eof-reachable-stop . p))))))
    (harness-case "the one-shot length, body, stop grammar is ACCEPTED (0030 item 6)"
      (lambda ()
        ;; A parser parked on `body` by need-input holds a positive count and
        ;; takes the error at EOF; no EOF path reaches the stop. Parking the
        ;; kind by kind, rather than by need-input, would reject this machine.
        (let ((m (cc-machine 'start len-field
                             (list (entry-to 'body)
                                   (make-counted-consume-node 'body 'len 'done 'reject #f)
                                   done reject))))
          (check-equal "no diagnostics" (codes m) '()))))
    (harness-case "a self-targeting next is a zero-progress cycle, and nothing else (0030 item 7)"
      (lambda ()
        (let ((m (cc-machine 'start len-field
                             (list (entry-into 'body)
                                   (make-counted-consume-node 'body 'len 'body #f #f)
                                   done reject))))
          (check-equal "zero-progress-cycle alone, at the node"
                       (map cons (codes m) (nodes-of m))
                       '((zero-progress-cycle . body))))))
    (harness-case "a self-targeting eof-target is an EOF zero-progress cycle"
      (lambda ()
        (let ((m (cc-machine 'start len-field
                             (list (entry-into 'body)
                                   (make-counted-consume-node 'body 'len 'done 'body #f)
                                   done reject))))
          (check-equal "eof-zero-progress-cycle, at the node"
                       (map cons (codes m) (nodes-of m))
                       '((eof-zero-progress-cycle . body))))))
    (harness-case "an undeclared field is invalid-field-operand under the node's name (§16.2:903)"
      (lambda ()
        (let ((bad (cc-machine 'start '()
                               (list (entry-into 'body)
                                     (make-counted-consume-node 'body 'nosuch 'done #f #f)
                                     done reject)))
              (good (cc-machine 'start len-field
                                (list (entry-into 'body)
                                      (make-counted-consume-node 'body 'len 'done #f #f)
                                      done reject))))
          (check-equal "undeclared: reported under the node"
                       (map cons (codes bad) (nodes-of bad))
                       '((invalid-field-operand . body)))
          (check-equal "declared: clean" (codes good) '()))))
    (harness-case "the priced over-rejection: a value-terminated loop is rejected, the same loop with a byte dispatch in it is accepted (0030 item 7)"
      (lambda ()
        ;; records := 3, size := 2. `[branch zero? records -> done] -> consume(size)
        ;; -> decrement records -> branch` terminates whenever `records` does,
        ;; and the verifier cannot see that it does; the over-rejection is
        ;; bounded to loops with no consuming node. The loop sits behind a byte
        ;; dispatch so the entry, not the branch, is the parked node, and the
        ;; finding is the zero-progress cycle alone.
        (let* ((fields (list (make-uint-field 'records 8 3 #f) (make-uint-field 'size 8 2 #f)))
               (branch (make-field-branch-node 'br 'zero '(records) 'done 'body #f))
               (dec (make-field-action-node 'dec 'decrement '(records) 'br 'reject #f))
               (rejected (cc-machine 'start fields
                                     (list (entry-to 'br) branch
                                           (make-counted-consume-node 'body 'size 'dec #f #f)
                                           dec done reject)))
               (accepted (cc-machine 'start fields
                                     (list (entry-to 'br) branch
                                           (make-counted-consume-node 'body 'size 'sep #f #f)
                                           (make-byte-dispatch-node 'sep (list (case-to 'dec))
                                                                    (make-edge 'reject 'reexecute)
                                                                    #f #f)
                                           dec done reject))))
          (check-equal "rejected: the three nodes of the loop"
                       (map cons (codes rejected) (nodes-of rejected))
                       '((zero-progress-cycle . br) (zero-progress-cycle . body)
                         (zero-progress-cycle . dec)))
          (check-equal "accepted with a consuming node in the loop" (codes accepted) '()))))
    (harness-case "a counted consume inside a span verifies clean (§10.6:604)"
      (lambda ()
        ;; `span-transfer` is the identity for the kind and `span-node-diagnostics`
        ;; answers nothing; the body's own EOF route gets its own error node, on
        ;; the member3-drift precedent (the shared `reject` is reached with no
        ;; span open, and merging the two states at one node is a rejection).
        (let ((m (make-machine 'ccm 'start len-field
                               (list (make-callback-declaration 'on-data 'span-data #t '() #f #f))
                               (list (make-span-declaration 'sp 'on-data #f #f))
                               errs
                               (list (entry-into 'ss)
                                     (make-span-start-node 'ss 'sp 'body #f)
                                     (make-counted-consume-node 'body 'len 'se 'rej2 #f)
                                     (make-error-node 'rej2 'rejected #f)
                                     (make-span-end-node 'se 'sp 'after #f)
                                     (make-byte-dispatch-node 'after (list (case-to 'done))
                                                              (make-edge 'reject 'reexecute) #f #f)
                                     done reject)
                               'default-eof #f)))
          (check-equal "no diagnostics" (codes m) '()))))))

;; ============================================================================
;; The diagnostic record's severity, machine, declarations and path fields
;; ============================================================================
;; A diagnostic's seven fields live in nine slots. These groups witness the
;; four fields the code/node/edge reads above never touch -- severity, machine,
;; declarations, path. Paths are compared by SHAPE only -- first element, last
;; element, membership, never as a whole list -- through #f-tolerant guards, so
;; an absent path fails by comparison (`got #f`) rather than raising in `car`;
;; that is what makes the empty-path mutants comparison catches too.
(define (s1-diags m) (verification-diagnostics (verify-machine m)))
(define (s1-diag m code)
  (let loop ((ds (s1-diags m)))
    (cond ((null? ds) #f)
          ((eq? (diagnostic-code (car ds)) code) (car ds))
          (else (loop (cdr ds))))))
(define (s1-diag-at m code node)
  (let loop ((ds (s1-diags m)))
    (cond ((null? ds) #f)
          ((and (eq? (diagnostic-code (car ds)) code)
                (eq? (diagnostic-node (car ds)) node)) (car ds))
          (else (loop (cdr ds))))))
(define (path-first d) (let ((p (diagnostic-path d))) (and (pair? p) (car p))))
(define (path-last  d) (let ((p (diagnostic-path d))) (and (pair? p) (car (reverse p)))))
(define (path-has?  d n) (let ((p (diagnostic-path d))) (and (pair? p) (memq n p) #t)))

;; Fixtures of their own, so these groups share no fixture with the groups above.
(define (s1-error n) (make-error-node n 'rejected #f))
(define (s1-one-case name target mode eof-target)
  (make-byte-dispatch-node name
    (list (make-byte-case (make-exact-byte-matcher 0) (make-edge target mode) #f))
    (make-edge 'rej 'reexecute) eof-target #f))
(define (s1-mach name entry fields nodes)
  (make-machine name entry fields '() '() errs nodes 'default-eof #f))

(harness-group "the widened record stamps severity and the machine name (0032 item 2)"
  (lambda ()
    (harness-case "every diagnostic of a machine carries error and the machine's name"
      (lambda ()
        ;; Three findings from three passes -- overlap, duplicate name, and an
        ;; unreachable orphan -- all stamped once in `verify-machine`.
        (let* ((m (s1-mach 'multi 'start '()
                           (list (make-byte-dispatch-node 'start
                                   (list (make-byte-case (make-byte-range-matcher 0 10)
                                                         (make-edge 'stop 'advance) #f)
                                         (make-byte-case (make-byte-range-matcher 5 20)
                                                         (make-edge 'stop 'advance) #f))
                                   (make-edge 'reject 'reexecute) #f #f)
                                 (make-stop-node 'stop #f) (make-stop-node 'stop #f)
                                 (make-stop-node 'orphan #f) (s1-error 'reject))))
               (ds (s1-diags m))
               (observed 0))
          ;; check-equal, not a boolean check, so the three stamping mutations
          ;; separate by their got: the dropped map gives `#f`, a wrong constant
          ;; gives that constant, a warning severity gives `warning`.
          (for-each (lambda (d)
                      (set! observed (+ observed 1))
                      (check-equal "diagnostic severity" (diagnostic-severity d) 'error)
                      (check-equal "diagnostic machine stamp" (diagnostic-machine d) 'multi))
                    ds)
          ;; The sentinel reads the count it actually drove, never the fixture's
          ;; own expectation, and asserts at least the three passes' findings.
          (check-equal "the loop drove every diagnostic" observed (length ds))
          (check "at least three findings from three passes" (>= observed 3)))))
    (harness-case "a not-a-machine diagnostic carries error and machine #f (F5)"
      (lambda ()
        ;; `#f` here is the RULE, not a placeholder: `verify-machine` runs every
        ;; pass but `pass-schema` only under `(machine? machine)`, so a diagnostic
        ;; with no machine name is exactly one about a non-machine. `pass-schema`'s
        ;; version arm is unconstructible through the public API, so its own
        ;; machine-name answer is right by construction, not by a fixture.
        (let ((d (s1-diag 'not-a-machine 'invalid-shape)))
          (check "one shape finding for a non-machine" (and d #t))
          (check-equal "non-machine severity" (diagnostic-severity d) 'error)
          (check-equal "non-machine has no machine stamp" (diagnostic-machine d) #f))))
    (harness-case "a single-finding machine stamps that one diagnostic once"
      (lambda ()
        ;; One finding, so each stamp assertion fires EXACTLY ONCE -- the single
        ;; record the machine-stamp (got a wrong constant) and severity (got a
        ;; warning) mutations each need to pin without matching the multi-fault
        ;; loop's several identical records.
        (let ((d (s1-diag (s1-mach 'solo 'start '()
                                   (list (s1-one-case 'start 'stop 'advance #f)
                                         (make-stop-node 'stop #f) (make-stop-node 'stop #f)
                                         (s1-error 'rej)))
                          'duplicate-name)))
          (check "one duplicate-name finding" (and d #t))
          (check-equal "single severity" (diagnostic-severity d) 'error)
          (check-equal "single machine stamp" (diagnostic-machine d) 'solo))))))

;; --- declarations, one per family ----------------------------------------------
(define (s1-cb name kind req keys default) (make-callback-declaration name kind req keys default #f))
(define (s1-sp name data complete) (make-span-declaration name data complete #f))
(define (s1-ok-nodes) (list (s1-one-case 'start 'stop 'advance #f)
                            (make-stop-node 'stop #f) (s1-error 'rej)))
(define (s1-decls name cbs sps ds nodes) (make-machine name 'start '() cbs sps ds nodes 'default-eof #f))

(harness-group "each site's declarations list names its declaration (0032 item 3, F12)"
  (lambda ()
    (harness-case "the callback / span / error / field families each carry (list subject)"
      (lambda ()
        (check-equal "callback: invalid-callback-declaration names the callback"
                     (diagnostic-declarations
                      (s1-diag (s1-decls 'a (list (s1-cb 'cbx 'decision #f '(keep skip) #f))
                                         '() errs (s1-ok-nodes))
                               'invalid-callback-declaration))
                     '(cbx))
        (check-equal "span: duplicate-span-declaration names the span"
                     (diagnostic-declarations
                      (s1-diag (s1-decls 'a (list (s1-cb 'ond 'span-data #f '() #f))
                                         (list (s1-sp 'body 'ond #f) (s1-sp 'body 'ond #f))
                                         errs (s1-ok-nodes))
                               'duplicate-span-declaration))
                     '(body))
        ;; Label carries no diagnostic-code token, so no pin's output-match
        ;; resolves onto this case's FAIL line.
        (check-equal "the error family names its duplicated declaration"
                     (diagnostic-declarations
                      (s1-diag (make-machine 'a 'start '() '() '() (list eof-decl rej-decl rej-decl)
                                             (s1-ok-nodes) 'default-eof #f)
                               'duplicate-error-declaration))
                     '(rejected))
        (check-equal "field: invalid-field-declaration names the field"
                     (diagnostic-declarations
                      (s1-diag (make-machine 'a 'start
                                             (list (make-uint-field 'n 8 0 #f)
                                                   (make-uint-field 'n 8 0 #f))
                                             '() '() errs (s1-ok-nodes) 'default-eof #f)
                               'invalid-field-declaration))
                     '(n))))
    (harness-case "invalid-span-callback carries the span AND the callback (two names)"
      (lambda ()
        (check-equal "span then callback"
                     (diagnostic-declarations
                      (s1-diag (s1-decls 'a (list (s1-cb 'ondata 'event #f '() #f))
                                         (list (s1-sp 'body 'ondata #f)) errs (s1-ok-nodes))
                               'invalid-span-callback))
                     '(body ondata))))
    (harness-case "F12: the two span missing-callback-declaration sites name their callback"
      (lambda ()
        ;; The span sites carry two names, matching the callback node's
        ;; missing-callback-declaration, which also names its callback.
        (check-equal "span data callback: span then the undeclared name"
                     (diagnostic-declarations
                      (s1-diag (s1-decls 'a '() (list (s1-sp 'body 'nosuch #f)) errs (s1-ok-nodes))
                               'missing-callback-declaration))
                     '(body nosuch))))
    (harness-case "the duplicate-branch-key PAIR: a list at the declaration, '() at the node"
      (lambda ()
        ;; The case that makes the per-site policy visible rather than
        ;; accidental: the declaration's key list is the subject there, while
        ;; at the callback NODE the fault is the node's own key list and the
        ;; callback resolved, so it carries no declaration.
        (check-equal "declaration site names the callback"
                     (diagnostic-declarations
                      (s1-diag (s1-decls 'a (list (s1-cb 'cbx 'decision #t '(dup dup) #f))
                                         '() errs (s1-ok-nodes))
                               'duplicate-branch-key))
                     '(cbx))
        (check-equal "node site carries the empty list"
                     (diagnostic-declarations
                      (s1-diag-at (s1-decls 'a (list (s1-cb 'cbx 'decision #t '(keep) #f)) '()
                                            errs (list (s1-one-case 'start 'inv 'advance #f)
                                                       (make-callback-node 'inv 'cbx 'stop
                                                         '((dup a1) (dup a2)) 'rej #f)
                                                       (make-stop-node 'stop #f) (s1-error 'rej)))
                                  'duplicate-branch-key 'inv))
                     '())))))

;; --- the eight path-bearing codes, one loop with an observed-count sentinel --
;; Each row: (label code fixture expected-first expected-last expected-member
;;            expected-count). Compared by shape only, and the finding COUNT
;; rides beside the path so an empty-path mutant (same count, `#f` path) is told
;; apart from an emission-deleting one (one fewer) -- the widening mutant
;; nesting inside the deleting one.
(define s1-path-table
  (list
   (list "zero-progress-cycle" 'zero-progress-cycle
         (s1-mach 'a 'start '() (list (s1-one-case 'start 'start 'reexecute #f) (s1-error 'rej)))
         'start 'start 'start 1)
   (list "eof-reachable-stop" 'eof-reachable-stop
         (s1-mach 'a 'start '() (list (s1-one-case 'start 'stop 'advance 'stop)
                                      (make-stop-node 'stop #f) (s1-error 'rej)))
         'start 'stop 'stop 1)
   (list "eof-zero-progress-cycle" 'eof-zero-progress-cycle
         (s1-mach 'a 'start '() (list (s1-one-case 'start 'stop 'advance 'x)
                                      (s1-one-case 'x 'stop 'advance 'y)
                                      (s1-one-case 'y 'stop 'advance 'x)
                                      (make-stop-node 'stop #f) (s1-error 'rej)))
         'start 'x 'y 1)
   ;; TWO hops (entry -> mid -> fin), so the byte-edge path is not the trivial
   ;; one the entry already carries: this is what catches "a byte parent is not
   ;; recorded", which leaves a source==entry fixture unchanged.
   (list "non-eof-into-finish (edge)" 'non-eof-into-finish
         (s1-mach 'a 'start '() (list (s1-one-case 'start 'mid 'advance #f)
                                      (s1-one-case 'mid 'fin 'advance #f)
                                      (make-finish-node 'fin #f) (s1-error 'rej)))
         'start 'fin 'mid 1)
   (list "invalid-span-state" 'invalid-span-state
         (span-machine (append (list (entry-to 'op) (make-span-start-node 'op 'body 'op2 #f)
                                     (make-span-start-node 'op2 'body 'cl #f)
                                     (make-span-end-node 'cl 'body 'exit #f)) (span-tail/exit)))
         'start 'op2 'op2 1)
   (list "inconsistent-span-state" 'inconsistent-span-state
         (span-machine (append (list (entry-fork 'op 'mrg) (make-span-start-node 'op 'body 'mrg #f)
                                     (make-byte-dispatch-node 'mrg (list (case-to 'done))
                                       (make-edge 'reject 'reexecute) #f #f)) (span-tail2)))
         'start 'mrg 'mrg 1)
   (list "span-active-at-pause" 'span-active-at-pause
         (span-machine (append (list (entry-to 'op) (make-span-start-node 'op 'body 'p #f)
                                     (make-pause-node 'p 'cl #f)
                                     (make-span-end-node 'cl 'body 'exit #f)) (span-tail/exit)))
         'start 'p 'p 1)
   (list "span-active-at-exit" 'span-active-at-exit
         (span-machine (append (list (entry-to 'op) (make-span-start-node 'op 'body 'done #f))
                               (span-tail)))
         'start 'done 'op 1)))

(harness-group "each path-bearing code carries a path of the right shape (0032 items 4-5)"
  (lambda ()
    (harness-case "first, last and membership per code, with the finding count beside it"
      (lambda ()
        (let ((driven 0))
          (for-each
           (lambda (row)
             (let* ((label (list-ref row 0)) (code (list-ref row 1)) (m (list-ref row 2))
                    (efirst (list-ref row 3)) (elast (list-ref row 4))
                    (emember (list-ref row 5)) (ecount (list-ref row 6))
                    (d (s1-diag m code)) (ds (s1-diags m)))
               (set! driven (+ driven 1))
               (check (string-append label ": is emitted") (and d #t))
               (check-equal (string-append label ": path starts at the walk start")
                            (path-first d) efirst)
               (check-equal (string-append label ": path ends at the reporting target")
                            (path-last d) elast)
               (check (string-append label ": the expected node is on the path")
                      (path-has? d emember))
               (check-equal (string-append label ": finding count") (length ds) ecount)))
           s1-path-table)
          ;; The sentinel reads the rows it drove, and the table's length is
          ;; checked against it, so dropping a row cannot shrink the group silently.
          (check-equal "drove eight path codes" driven 8)
          (check-equal "the table has eight rows" (length s1-path-table) driven))))
    (harness-case "a parked callback's path starts at its pause continuation, not the node"
      (lambda ()
        ;; For a parked callback the walk starts at `parked-eof-start`'s answer
        ;; -- the pause continuation -- and NOT at the reporting node. A test
        ;; asserting the reporting node would pass for a dispatch and fail here.
        (let ((d (s1-diag
                  (make-machine 'a 'start '()
                    (list (make-callback-declaration 'ev 'event #f '() #f #f)) '() errs
                    (list (s1-one-case 'start 'cbn 'advance #f)
                          (make-callback-node 'cbn 'ev 'k '() 'pc #f)
                          (make-stop-node 'k #f) (make-stop-node 'pc #f) (s1-error 'rej))
                    'default-eof #f)
                  'eof-reachable-stop)))
          (check "reported at the callback node" (eq? (diagnostic-node d) 'cbn))
          (check-equal "path starts at the pause continuation" (path-first d) 'pc))))
    (harness-case "a parked counted consume's path starts at its eof-target, not the node"
      (lambda ()
        ;; The second kind whose walk start differs from its name.
        (let ((d (s1-diag
                  (make-machine 'a 'start (list (make-uint-field 'n 8 0 #f)) '() '() errs
                    (list (s1-one-case 'start 'cc 'advance #f)
                          (make-counted-consume-node 'cc 'n 'nx 'et #f)
                          (make-stop-node 'nx #f) (make-stop-node 'et #f) (s1-error 'rej))
                    'default-eof #f)
                  'eof-reachable-stop)))
          (check "reported at the counted consume node" (eq? (diagnostic-node d) 'cc))
          (check-equal "path starts at the eof-target" (path-first d) 'et))))
    (harness-case "the zero-hop non-eof-into-finish path is the entry alone"
      (lambda ()
        (let ((d (s1-diag (make-machine 'a 'fin '() '() '() errs
                                        (list (make-finish-node 'fin #f)) 'default-eof #f)
                          'non-eof-into-finish)))
          (check "reported at the entry" (eq? (diagnostic-node d) 'fin))
          (check-equal "path first is the entry" (path-first d) 'fin)
          (check-equal "path last is the entry" (path-last d) 'fin))))))

(harness-group "a code no fixture emits has no path assertion passing vacuously (0032, negatives)"
  (lambda ()
    (harness-case "each path code is ABSENT one edit away from the fault"
      (lambda ()
        (let ((driven 0))
          (for-each
           (lambda (row)
             (let ((label (car row)) (code (cadr row)) (m (caddr row)))
               (set! driven (+ driven 1))
               (check (string-append label ": absent") (not (has-code? m code)))))
           (list
            (list "zero-progress-cycle" 'zero-progress-cycle
                  (s1-mach 'a 'start '() (list (s1-one-case 'start 'start 'advance #f)
                                               (s1-error 'rej))))
            (list "eof-reachable-stop" 'eof-reachable-stop
                  (s1-mach 'a 'start '() (list (s1-one-case 'start 'stop 'advance 'fin)
                                               (make-stop-node 'stop #f)
                                               (make-finish-node 'fin #f) (s1-error 'rej))))
            (list "eof-zero-progress-cycle" 'eof-zero-progress-cycle
                  (s1-mach 'a 'start '() (list (s1-one-case 'start 'stop 'advance 'x)
                                               (s1-one-case 'x 'stop 'advance 'stop)
                                               (make-stop-node 'stop #f) (s1-error 'rej))))
            (list "non-eof-into-finish" 'non-eof-into-finish
                  (s1-mach 'a 'start '() (list (s1-one-case 'start 'stop 'advance #f)
                                               (make-stop-node 'stop #f) (s1-error 'rej))))
            (list "invalid-span-state" 'invalid-span-state
                  (span-machine (append (list (entry-to 'op)
                                              (make-span-start-node 'op 'body 'cl #f)
                                              (make-span-end-node 'cl 'body 'exit #f))
                                        (span-tail/exit))))
            (list "inconsistent-span-state" 'inconsistent-span-state
                  (span-machine (append (list (entry-to 'op)
                                              (make-span-start-node 'op 'body 'cl #f)
                                              (make-span-end-node 'cl 'body 'exit #f))
                                        (span-tail/exit))))
            (list "span-active-at-pause" 'span-active-at-pause
                  (span-machine (append (list (entry-to 'p) (make-pause-node 'p 'done #f))
                                        (span-tail))))
            (list "span-active-at-exit" 'span-active-at-exit
                  (span-machine (append (list (entry-to 'op)
                                              (make-span-start-node 'op 'body 'cl #f)
                                              (make-span-end-node 'cl 'body 'done #f))
                                        (span-tail))))))
          (check-equal "drove eight negatives" driven 8))))))

(harness-group "the EOF join tie-break returns the left operand's path (0032 item 5, F10)"
  (lambda ()
    (harness-case "a tie within tier 1 keeps the LEFT branch's path"
      (lambda ()
        ;; A `t6-join-machine` variant whose field branch reaches TWO DISTINCT
        ;; stop nodes: the distinctness is the whole fixture -- one shared stop
        ;; makes the second branch a memo hit that returns the first's path, and
        ;; `>=` vs `>` become uncatchable. `s1`(true) is the LEFT operand of the
        ;; join, so `>=` reports the path through it; `>` would report the path
        ;; through `s2`. This is the witness for the join's deterministic
        ;; tie-break.
        (let ((d (s1-diag
                  (make-machine 'j 's0 (list (make-uint-field 'n 8 0 #f)) '() '()
                    (list eof-decl rej-decl)
                    (list (make-byte-dispatch-node 's0
                            (list (make-byte-case (make-exact-byte-matcher 0)
                                                  (make-edge 's1 'advance) #f))
                            (make-edge 'rj 'reexecute) 'br #f)
                          (make-field-branch-node 'br 'zero '(n) 's1 's2 #f)
                          (make-stop-node 's1 #f) (make-stop-node 's2 #f)
                          (make-error-node 'rj 'rejected #f))
                    'default-eof #f)
                  'eof-reachable-stop)))
          (check "reported at the entry dispatch" (eq? (diagnostic-node d) 's0))
          (check-equal "path first is the entry" (path-first d) 's0)
          (check-equal "path last is the LEFT branch's stop" (path-last d) 's1)
          (check "the left stop is on the path" (path-has? d 's1)))))))

(harness-finish)
