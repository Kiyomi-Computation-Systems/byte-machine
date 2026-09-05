;;; Runtime parser lifecycle over a hand-built compiled-machine stub, so the
;;; loop is witnessed independently of the interpreter (Task 5 supplies the real
;;; op). The stub encodes the one-byte machine: byte 0 advances to stop; any
;;; other byte reexecutes into the error node.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine runtime))

(harness-begin "unit.runtime")

;; Slice ①a whole-branch review: a predicate that names WHICH guard fired.
;; assertion-violation? alone cannot -- every guard in the constructor raises the
;; same condition type with the same `who` -- so a case asserting an ORDERING
;; needs the irritant, which is the only thing that differs between them.
(define (irritant-is v)
  (lambda (e)
    (and (assertion-violation? e)
         (irritants-condition? e)
         (let walk ((xs (condition-irritants e)))
           (and (pair? xs) (or (equal? (car xs) v) (walk (cdr xs))))))))

;; Slice ①a task 5: the error slot holds a parser-error record and is #f on
;; every non-error result. These cases assert the CODE; the record's own shape
;; is pinned by the dedicated parser-error group below.
(define (error-code-of r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e) (parser-error-code e))))

(define (one-byte-op msg . args)
  (case msg
    ;; Slice ①b task 6: make-parser asks every op closure for the field
    ;; declarations, so every hand-written stub answers it. These stubs declare
    ;; no fields, which is what keeps their parsers byte-for-byte what they were.
    ((field-initials) (vector))
    ;; Slice ①b: the op interface gained `callback-decls`. A stub standing in
    ;; for the interpreter must answer it, and a missing arm is LOUD by design.
    ((callback-decls) (vector))
    ((entry) 'start)
    ((kind) (case (car args) ((start) 'dispatch) ((stop) 'stop) ((reject) 'error)))
    ((dispatch)
     (let ((byte (cadr args)))
       (if (= byte 0) (cons 'stop 'advance) (cons 'reject 'reexecute))))
    ;; Slice ①a task 5: the op protocol answers with the record's PARTS --
    ;; (code reason node-name state-id) -- and the runtime supplies the offset
    ;; and the position kind, which only its loop knows. These stubs implement
    ;; the protocol independently of interpret.sls, so they do not redden when
    ;; it changes; they are updated by hand, deliberately.
    ((error-value) (list 'unexpected-byte "unexpected byte" 'reject 2))
    (else (assertion-violation 'one-byte-op "bad message" msg))))

(define (feed-byte b)
  (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
    (parser-feed! p (make-bytevector 1 b) 0 1)))

(harness-group "callback outcome singletons"
  (lambda ()
    (harness-case "continue and pause are stable, distinct singletons"
      (lambda ()
        (check "continue is itself" (eq? callback-continue callback-continue))
        (check "pause is itself" (eq? callback-pause callback-pause))
        (check "continue is not pause" (not (eq? callback-continue callback-pause)))))))

(harness-group "one-byte parser lifecycle"
  (lambda ()
    (harness-case "the accepted byte stops after consuming one byte"
      (lambda ()
        (let ((r (feed-byte 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "next" (parser-result-next r) 1)
          ;; The advance path is the only one that increments the stream offset;
          ;; the reject case below pins it at 0, so this is where the increment
          ;; itself is observed.
          (check-equal "stream offset" (parser-result-stream-offset r) 1))))
    (harness-case "a rejected byte errors at position 0 without consuming"
      (lambda ()
        (let ((r (feed-byte 65)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "stream offset" (parser-result-stream-offset r) 0)
          (check-equal "error value" (error-code-of r) 'unexpected-byte))))
    (harness-case "an empty slice needs input and reports no result yet"
      (lambda ()
        (let* ((p (make-parser (make-compiled-machine one-byte-op) '() #f))
               (returned 'not-yet-run))
          (set! returned (parser-result-status (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" returned 'need-input))))
    (harness-case "a repeat feed on a terminal parser reports a fresh empty result (§12.2)"
      (lambda ()
        (let* ((p (make-parser (make-compiled-machine one-byte-op) '() #f))
               (r1 (parser-feed! p (make-bytevector 1 0) 0 1))
               (r2 (parser-feed! p (make-bytevector 1 0) 0 1)))
          (check-equal "first stopped" (parser-result-status r1) 'stopped)
          (check-equal "second still stopped" (parser-result-status r2) 'stopped)
          (check-equal "second next is the new slice start" (parser-result-next r2) 0)
          (check-equal "second consumed is zero" (parser-result-consumed r2) 0)
          (check-equal "second stream offset unchanged"
                       (parser-result-stream-offset r2) (parser-result-stream-offset r1)))))))

;; parser-finish! (§12.4) over hand-built op stubs, independent of the
;; interpreter -- interpret-tests.sps exercises the full eofm machine through
;; the real op; these stubs isolate parser-finish-op!'s own two decisions.
;; eof-target-op's entry node has a truthy eof-target (a finish node);
;; default-eof-op's has none (#f), which must route to the machine's default-
;; eof error instead. finish-feed-op starts already parked at a finish node,
;; witnessing parser-feed-op!'s finish arm (§12.2: finished x feed!).
(define (eof-target-op msg . args)
  (case msg
    ;; Slice ①b task 6: make-parser asks every op closure for the field
    ;; declarations, so every hand-written stub answers it. These stubs declare
    ;; no fields, which is what keeps their parsers byte-for-byte what they were.
    ((field-initials) (vector))
    ;; Slice ①b: the op interface gained `callback-decls`. A stub standing in
    ;; for the interpreter must answer it, and a missing arm is LOUD by design.
    ((callback-decls) (vector))
    ((entry) 's0)
    ((kind) (case (car args) ((s0) 'dispatch) ((done) 'finish)
              (else (assertion-violation 'eof-target-op "bad node" (car args)))))
    ((eof-target) (case (car args) ((s0) 'done) (else #f)))
    ((default-eof-value) (list 'eof "unexpected end of input" 's0 0))
    (else (assertion-violation 'eof-target-op "bad message" msg))))

(define (default-eof-op msg . args)
  (case msg
    ;; Slice ①b task 6: make-parser asks every op closure for the field
    ;; declarations, so every hand-written stub answers it. These stubs declare
    ;; no fields, which is what keeps their parsers byte-for-byte what they were.
    ((field-initials) (vector))
    ;; Slice ①b: the op interface gained `callback-decls`. A stub standing in
    ;; for the interpreter must answer it, and a missing arm is LOUD by design.
    ((callback-decls) (vector))
    ((entry) 's0)
    ((kind) (case (car args) ((s0) 'dispatch)
              (else (assertion-violation 'default-eof-op "bad node" (car args)))))
    ((eof-target) #f)
    ((default-eof-value) (list 'eof "unexpected end of input" 's0 0))
    (else (assertion-violation 'default-eof-op "bad message" msg))))

(define (finish-feed-op msg . args)
  (case msg
    ;; Slice ①b task 6: make-parser asks every op closure for the field
    ;; declarations, so every hand-written stub answers it. These stubs declare
    ;; no fields, which is what keeps their parsers byte-for-byte what they were.
    ((field-initials) (vector))
    ;; Slice ①b: the op interface gained `callback-decls`. A stub standing in
    ;; for the interpreter must answer it, and a missing arm is LOUD by design.
    ((callback-decls) (vector))
    ((entry) 'done)
    ((kind) (case (car args) ((done) 'finish)
              (else (assertion-violation 'finish-feed-op "bad node" (car args)))))
    (else (assertion-violation 'finish-feed-op "bad message" msg))))

;; Fourth op stub, whole-branch review Critical 2: s0 advances on byte 1 to
;; s1; s1's eof-target is a pause (continuation a finish node). Isolates
;; parser-finish-op!'s own pause arm (off/0/off) from every existing pause-op
;; fixture, none of which reaches an EOF pause after consuming any bytes
;; (pause-op's own s1 eof-target is the error node 'trunc, not a pause) -- so
;; `off` was always already 0 there and a hard-coded 0 was indistinguishable.
;;
;; Extended for the T8 re-review's Critical-1 residual: s1 ALSO advances on
;; byte 2 to a second, byte-reachable pause p2 (continuation the stop node
;; s2, not the fp/done finish pair above, so the two pause routes stay
;; independent). This witnesses a decision the single-call nonzero-start case
;; below cannot: on any ONE feed call from a fresh parser, consumed and
;; stream-offset are equal by construction (offset starts at 0, so the
;; cross-call total equals this call's own count) -- only a SECOND feed call
;; separates them.
(define (finish-pause-op msg . args)
  (case msg
    ;; Slice ①b task 6: make-parser asks every op closure for the field
    ;; declarations, so every hand-written stub answers it. These stubs declare
    ;; no fields, which is what keeps their parsers byte-for-byte what they were.
    ((field-initials) (vector))
    ;; Slice ①b: the op interface gained `callback-decls`. A stub standing in
    ;; for the interpreter must answer it, and a missing arm is LOUD by design.
    ((callback-decls) (vector))
    ((entry) 's0)
    ((kind) (case (car args)
              ((s0 s1) 'dispatch) ((fp p2) 'pause) ((done) 'finish) ((s2) 'stop)
              (else (assertion-violation 'finish-pause-op "bad node" (car args)))))
    ((dispatch)
     (let ((node (car args)) (byte (cadr args)))
       (case node
         ((s0) (cons 's1 'advance))
         ((s1) (if (= byte 2) (cons 'p2 'advance)
                   (assertion-violation 'finish-pause-op "unexpected byte at s1" byte)))
         (else (assertion-violation 'finish-pause-op "unexpected dispatch" args)))))
    ((eof-target) (case (car args) ((s1) 'fp) (else #f)))
    ((pause-target) (case (car args) ((fp) 'done) ((p2) 's2)))
    ((default-eof-value) (list 'eof "unexpected end of input" 's0 0))
    (else (assertion-violation 'finish-pause-op "bad message" msg))))

(harness-group "parser-finish!"
  (lambda ()
    (harness-case "an exhausted dispatch with a truthy eof-target continues to it -> finished"
      (lambda ()
        (let ((p (make-parser (make-compiled-machine eof-target-op) '() #f)))
          (check-equal "finished" (parser-result-status (parser-finish! p)) 'finished)
          ;; Self-review, Task 7 close-out: a second finish! call here is D1's
          ;; sticky arm (parser-finish!'s own ((finished) ...) case clause)
          ;; rather than the executor's finish arm the first call exercised --
          ;; no test had reached it before (finished x feed! was covered
          ;; below; finished x finish! was not).
          (let ((r2 (parser-finish! p)))
            (check-equal "sticky status" (parser-result-status r2) 'finished)
            (check-equal "sticky consumed zero" (parser-result-consumed r2) 0)))))
    (harness-case "an exhausted dispatch with no eof-target routes to the default-eof error"
      (lambda ()
        (let ((r (parser-finish! (make-parser (make-compiled-machine default-eof-op) '() #f))))
          (check-equal "default-eof status" (parser-result-status r) 'error)
          (check-equal "default-eof code" (error-code-of r) 'eof))))
    (harness-case "a parser parked at a finish node re-feeds to finished, consuming zero (§12.2)"
      (lambda ()
        (let* ((p (make-parser (make-compiled-machine finish-feed-op) '() #f))
               (r (parser-feed! p (make-bytevector 1 0) 0 1)))
          (check-equal "status" (parser-result-status r) 'finished)
          (check-equal "consumed" (parser-result-consumed r) 0)
          ;; Second feed: lifecycle is already 'finished, so this one is
          ;; sticky (parser-feed!'s own finished arm) rather than the
          ;; executor's finish arm the first feed above exercised -- no test
          ;; reached that sticky arm before. Nonzero start so `next` cannot be
          ;; confused with a stale/hardcoded 0.
          (let ((r2 (parser-feed! p (make-bytevector 3 0) 2 3)))
            (check-equal "sticky status" (parser-result-status r2) 'finished)
            (check-equal "sticky next is the new start" (parser-result-next r2) 2)
            (check-equal "sticky consumed zero" (parser-result-consumed r2) 0)))))
    (harness-case "an EOF pause after consuming bytes reports the persisted offset, not zero"
      (lambda ()
        (let ((p (make-parser (make-compiled-machine finish-pause-op) '() #f)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (let ((r (parser-finish! p)))
            (check-equal "status" (parser-result-status r) 'paused)
            (check-equal "next" (parser-result-next r) 1)
            (check-equal "consumed" (parser-result-consumed r) 0)
            (check-equal "stream offset" (parser-result-stream-offset r) 1)))))))

;; The unified-executor ABI (/v2, Slice ②b-2). One `exec` closure carries the
;; whole dispatch loop and a `finish?` flag: feed calls it with #f over the real
;; slice, parser-finish! with #t over the empty slice. This stub encodes the
;; one-byte machine over numeric states (0 dispatch, 1 stop, 2 error); state 0's
;; exhausted-with-finish? path routes to the machine's default-eof error 'eof,
;; witnessing the /v2 finish arm independently of the emitter. State 3 is a
;; pause (Slice 3): unconditional, regardless of finish?, continuation state 1
;; (stop) -- mirroring D5's unconditional generated pause arm and letting
;; v2-pause-machine below witness parser-finish-v2!'s own paused arm, which no
;; other /v2 fixture reaches.
;; Milestone 5 Slice ①a: `psr` and `cbv` are emitted `exec`'s eighth and ninth
;; parameters (decision 0025 point 3), reserved and ignored. This stub stands in
;; for generated code, so its arity must track the emitted one -- and nothing
;; but a call checks that: the arity mismatch surfaced as "incorrect number of
;; arguments 9" from every /v2 group at once, not as a signature assertion.
(define (stub-exec state offset bv start end finish? fieldv psr cbv)
  (let loop ((pos start) (st state) (off offset))
    (case st
      ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
      ;; Slice ①a task 5: generated code now puts a parser-error record in the
      ;; error slot, built through the reserved constructor from an errs-table
      ;; entry plus the site's own literals and the loop's variables. This stub
      ;; emulates that, by hand, exactly as it emulates the rest of exec.
      ((2) (byte-machine-make-feed-outcome/v1
            'error pos
            (byte-machine-make-parser-error/v1
             (vector 'unexpected-byte "unexpected byte") 'reject 2 off 'byte)
            2 off))
      ((3) (byte-machine-make-feed-outcome/v1 'paused pos #f 1 off))
      (else
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1
                'error pos
                (byte-machine-make-parser-error/v1
                 (vector 'eof "unexpected end of input") 's0 0 off 'eof)
                0 off)                    ; eof-target #f -> default
               (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (if (= b 0) (loop (+ pos 1) 1 (+ off 1)) (loop pos 2 off))))))))
;; Milestone 5 Slice ②: ABI 5, and member 2 is the state-id to source-name
;; table `parser-state-name` reads. The stub exec's four states are named after
;; what they do, so a lane asserting the accessor names something checkable.
(define stub-names (vector 's0 's1 's2 's3))
(define (v2-machine)
  (byte-machine-make-compiled-machine 5 99 0 stub-exec
                                      (vector (vector) (vector) stub-names)))
(define (v2-pause-machine)
  (byte-machine-make-compiled-machine 5 99 3 stub-exec
                                      (vector (vector) (vector) stub-names)))

;; Milestone 4 Slice ①a task 3 retired the whole 'v1 feed-only executor path.
;; Once /v1 refuses every version nothing can construct one, so make-parser's
;; 'v1 arm, parser-feed!'s v1 else, parser-feed-v1! and parser-finish!'s "v1 has
;; no finish path" arm lost their only witness -- and an arm no public API can
;; reach cannot be witnessed at all, so it would ship dead owing an
;; EXPECT_SURVIVES (decision 0018's Consequences delegates this disposition to
;; the slice that lands it). The stub feed and its eight cases went with the
;; code; the two mutations that witnessed them were deleted from the suite in
;; the same commit rather than left to report UNCAUGHT. What replaces them is
;; the tombstone contract below, which is the only thing /v1 and /v2 still owe.
(harness-group "the retired constructors are tombstones"
  (lambda ()
    ;; Both refuse EVERY version, not the one they are named for. Refusing only
    ;; the mismatched number is what made /v2 a hole the moment the constant
    ;; moved to 3: its old guard checked the literal 2, so it would have accepted
    ;; exactly the stale files it was added to refuse, and a stale object then
    ;; loads and runs with nothing raising until an accessor meets a bare symbol
    ;; an arbitrary distance away.
    (harness-case "the retired constructors refuse every version"
      (lambda ()
        (let ((seen 'none) (n 0))
          (for-each
           (lambda (v)
             (set! n (+ n 1))
             (unless (and (guard (e (#t #t))
                            (byte-machine-make-compiled-machine/v1 v 42 0 stub-exec)
                            #f)
                          (guard (e (#t #t))
                            (byte-machine-make-compiled-machine/v2 v 99 0 stub-exec)
                            #f))
               (set! seen v)))
           '(0 1 2 3 4))
          ;; A sentinel over the loop itself: five versions were actually driven,
          ;; counted from the loop rather than from the list this case wrote.
          (check-equal "versions driven" n 5)
          (check-equal "none accepted" seen 'none))))
    (harness-case "the retired constructors raise assertion-violation"
      (lambda ()
        (check-raises "v1" assertion-violation?
                      (lambda () (byte-machine-make-compiled-machine/v1 3 42 0 stub-exec)))
        (check-raises "v2" assertion-violation?
                      (lambda () (byte-machine-make-compiled-machine/v2 3 99 0 stub-exec)))))))

;; Slice ①b: the same three-field assertion ir-tests.sps uses -- who, code and
;; detail -- because a check-raises stopping at the condition type alone would
;; not notice a copy-pasted `who` or `detail`.
(define (contract-violation? who detail)
  (lambda (e)
    (and (byte-machine-contract-condition? e)
         (eq? (byte-machine-contract-condition-code e) 'invalid-argument)
         (eq? (byte-machine-contract-condition-who e) who)
         (eq? (byte-machine-contract-condition-detail e) detail))))

(harness-group "callback binding resolution (§9.3:419, Slice ①b)"
  (lambda ()
    ;; A stub whose callback table is declared per case, so resolution is driven
    ;; rather than read. Four parts per decl: name, kind, required?, default.
    (define (cb-op decls)
      (lambda (msg . args)
        (case msg
          ((entry) 'start)
          ((field-initials) (vector))
          ((callback-decls) decls)
          (else (assertion-violation 'cb-op "bad message" msg)))))
    (define (cm decls) (make-compiled-machine (cb-op decls)))
    (define (noop . _) 'ignored)
    (harness-case "a bound callback lands in its declared slot"
      (lambda ()
        ;; The slot VECTOR is what §9.3:419 resolves to, and the case must read
        ;; it -- an earlier version checked only that a parser was built, which
        ;; would pass with every slot left unbound. The parser is a plain vector
        ;; and the slots are index 10, so the test reaches them without widening
        ;; any export.
        (let* ((one (lambda args 'one)) (two (lambda args 'two))
               (decls (vector (vector 'a 'event #t #f) (vector 'b 'event #t #f)))
               (p (make-parser (cm decls) (list (list 'b two) (list 'a one)) 'ctx))
               (slots (vector-ref p 10)))
          (check "a parser was built" (parser? p))
          ;; Bound in DECLARATION order, not binding order: the list above is
          ;; reversed on purpose, so a resolver that indexed by binding position
          ;; would swap these two.
          (check-equal "slot 0 is the first DECLARED callback" (vector-ref slots 0) one)
          (check-equal "slot 1 is the second" (vector-ref slots 1) two)
          (check-equal "and the context is held verbatim"
                       (parser-user-context p) 'ctx))))
    (harness-case "an unbound OPTIONAL callback is permitted"
      (lambda ()
        ;; §9.3:419: resolution installs default behaviour only where declared.
        ;; Decision 0028 makes the slot a sentinel; nothing invokes it in this
        ;; slice, so what is asserted is that construction SUCCEEDS.
        (let ((decls (vector (vector 'opt 'event #f #f))))
          (check "built with no binding at all"
                 (parser? (make-parser (cm decls) '() #f))))))
    (harness-case "a missing REQUIRED callback is refused"
      (lambda ()
        (let ((decls (vector (vector 'req 'event #t #f))))
          (check-raises "refused"
                        (contract-violation? 'make-parser 'missing-required-callback)
                        (lambda () (make-parser (cm decls) '() #f))))))
    (harness-case "a duplicate binding is refused, whichever slot would have won"
      (lambda ()
        (let ((decls (vector (vector 'a 'event #t #f))))
          (check-raises "refused"
                        (contract-violation? 'make-parser 'duplicate-callback-binding)
                        (lambda () (make-parser (cm decls)
                                                (list (list 'a noop) (list 'a noop)) #f))))))
    (harness-case "a binding naming no declaration is refused, not ignored"
      (lambda ()
        ;; Silently ignoring it would let a typo disable a callback the machine
        ;; requires, and the machine would run with the default instead.
        (let ((decls (vector (vector 'a 'event #t #f))))
          (check-raises "refused"
                        (contract-violation? 'make-parser 'unknown-callback-binding)
                        (lambda () (make-parser (cm decls)
                                                (list (list 'a noop) (list 'typo noop)) #f))))))
    (harness-case "a malformed binding list is refused"
      (lambda ()
        (let ((decls (vector)))
          (check-raises "not a list"
                        (contract-violation? 'make-parser 'callback-bindings)
                        (lambda () (make-parser (cm decls) 'nope #f)))
          (check-raises "not a (name . procedure) pair"
                        (contract-violation? 'make-parser 'callback-bindings)
                        (lambda () (make-parser (cm decls) (list (list 'a 'not-a-proc)) #f))))))
    (harness-case "the active span is #f on a fresh parser, in both lanes"
      (lambda ()
        ;; `parser-active-span` ships in this slice and `parser-state-name` does
        ;; not: a span is runtime bookkeeping (§10.2:495) and answers in either
        ;; lane, where a source-node name cannot be answered by the generated one.
        (check-equal "no span is active" (parser-active-span (make-parser (cm (vector)) '() #f)) #f)))
    (harness-case "the stream offset is the public name for the tracked offset"
      (lambda ()
        (check-equal "starts at zero"
                     (parser-stream-offset (make-parser (cm (vector)) '() #f)) 0)))))

(harness-group "the ABI payload must carry every member this version defines"
  (lambda ()
    (harness-case "a payload short of the current minimum is refused"
      (lambda ()
        ;; Slice ①b's final review found this guard shipped with NO witness --
        ;; no test reached its raise and no mutation pinned it.
        ;;
        ;; Discriminated by WHO, and it took two tries to get right. A short
        ;; payload raises either way: the guard names it, and without the guard
        ;; `(vector-ref metadata 2)` raises an index error two lines later. A
        ;; bare `assertion-violation?` passes on both -- and so does
        ;; `irritant-is`, because vector-ref's own error carries the offending
        ;; vector as an irritant too. Both readings left the guard's mutation
        ;; UNCAUGHT and the suite said so, twice. Only `who` separates them.
        ;;
        ;; *** ONE case for one guard, and Slice ② collapsed two into it. ***
        ;; The shipped shape was a CHAIN of minimums, one per ABI version, on
        ;; the reading that each should name the member a short payload lacks.
        ;; Adding member 2's made the defect visible: a later minimum subsumes
        ;; every earlier one, so the earlier guard's removal changes nothing any
        ;; input can observe and its mutation went UNCAUGHT the moment the third
        ;; guard landed. Both lengths below now witness the same, last, guard.
        (let ((short-refused
               (lambda (payload)
                 (check-raises "refused BY THE CONSTRUCTOR, not by vector-ref"
                               (lambda (e)
                                 (and (assertion-violation? e) (who-condition? e)
                                      (eq? (condition-who e)
                                           'byte-machine-make-compiled-machine)))
                               (lambda () (byte-machine-make-compiled-machine
                                           5 99 0 stub-exec payload))))))
          (short-refused (vector (vector)))
          (short-refused (vector (vector) (vector))))
        (check "and a three-member payload is accepted"
               (compiled-machine? (byte-machine-make-compiled-machine
                                   5 99 0 stub-exec
                                   (vector (vector) (vector) stub-names))))))))

(harness-group "callback failure values (§13:808, decision 0024)"
  (lambda ()
    (harness-case "a failure carries an application code and an optional detail"
      (lambda ()
        (let ((f (make-callback-failure 'too-long "128 bytes")))
          (check "predicate" (callback-failure? f))
          (check-equal "code" (callback-failure-code f) 'too-long)
          (check-equal "detail" (callback-failure-detail f) "128 bytes"))))
    (harness-case "the detail is optional and opaque"
      (lambda ()
        (check-equal "absent" (callback-failure-detail (make-callback-failure 'e #f)) #f)))
    (harness-case "the code must be symbolic (§9.3:423)"
      (lambda ()
        (check-raises "refused" (contract-violation? 'make-callback-failure 'code)
                      (lambda () (make-callback-failure "too-long" #f)))))
    (harness-case "a failure is not one of the singletons, and they are not it"
      (lambda ()
        ;; §13:810 makes the successful outcomes allocation-free singletons and
        ;; licenses allocation here; the three must stay distinguishable.
        (let ((f (make-callback-failure 'e #f)))
          (check "not continue" (not (eq? f callback-continue)))
          (check "not pause" (not (eq? f callback-pause)))
          (check "the singletons are not failures"
                 (and (not (callback-failure? callback-continue))
                      (not (callback-failure? callback-pause)))))))))

(harness-group "the unversioned constructor checks the version first"
  (lambda ()
    (harness-case "the superseded version is refused and the current one accepted"
      (lambda ()
        (check-raises "abi 4 refused" assertion-violation?
                      (lambda () (byte-machine-make-compiled-machine
                                  4 99 0 stub-exec
                                  (vector (vector) (vector) stub-names))))
        (check "abi 5 accepted"
               (compiled-machine? (byte-machine-make-compiled-machine
                                   5 99 0 stub-exec
                                   (vector (vector) (vector) stub-names))))))
    (harness-case "the version check precedes every other guard"
      (lambda ()
        ;; Decision 0018 item 1: the check is FIRST, so a mismatch is reported
        ;; before any part of the payload is interpreted -- which is what makes
        ;; the payload safe to grow. Handed a wrong version AND a payload that
        ;; would fail the later guards, it must still be the version that is
        ;; named, or a stale file reports whichever slot happened to be read.
        ;; Discriminated by the IRRITANT, not by the condition type. All three
        ;; guards raise assertion-violation with the same `who`, so a bare
        ;; assertion-violation? predicate passes whichever one fired and this
        ;; case could not observe the ordering it is named for -- it would stay
        ;; green with the version check moved last, which is the single thing
        ;; decision 0018 item 1 exists to fix.
        (check-raises "the VERSION is named, not the payload"
                      (irritant-is 2)
                      (lambda () (byte-machine-make-compiled-machine 2 99 0 'not-a-procedure #f)))
        (check-raises "a non-vector payload is refused at the current version"
                      (irritant-is #f)
                      (lambda () (byte-machine-make-compiled-machine 5 99 0 stub-exec #f)))
        (check-raises "an empty payload has no member 0"
                      (irritant-is (vector))
                      (lambda () (byte-machine-make-compiled-machine
                                  5 99 0 stub-exec (vector))))))))

;; Milestone 5 Slice ②: the member-2 guard, on the ABI-4 guard's own precedent.
;; Each states the minimum ONE version introduced, so a payload short by one
;; member names the member it is short of rather than the first one missing.
(harness-group "generated-code ABI (/v2): feed and finish"
  (lambda ()
    (harness-case "a fed accepted byte stops"
      (lambda ()
        (let ((r (parser-feed! (make-parser (v2-machine) '() #f) (make-bytevector 1 0) 0 1)))
          (check-equal "stopped" (parser-result-status r) 'stopped))))
    (harness-case "finish with no input routes to the default-eof error"
      (lambda ()
        (let ((r (parser-finish! (make-parser (v2-machine) '() #f))))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "default-eof code" (error-code-of r) 'eof))))
    ;; Restored in Slice ①a task 3 when the retired /v1 group was deleted: no
    ;; other surviving case asserts the lifecycle a FEED records, and two shipped
    ;; mutations name exactly that decision. The stub encodes the same one-byte
    ;; machine, so the coverage is the same and only the executor variant moved.
    (harness-case "parser-lifecycle tracks ready -> terminal"
      (lambda ()
        (let ((p (make-parser (v2-machine) '() #f)))
          (check-equal "starts ready" (parser-lifecycle p) 'ready)
          (parser-feed! p (make-bytevector 1 0) 0 1)
          (check-equal "stopped after accept" (parser-lifecycle p) 'stopped)
          (let ((q (make-parser (v2-machine) '() #f)))
            (parser-feed! q (make-bytevector 1 65) 0 1)
            (check-equal "error after reject" (parser-lifecycle q) 'error)))))
    (harness-case "a mismatched ABI version is refused"
      (lambda ()
        ;; The live guard, distinct from the tombstone cases above: this one
        ;; refuses a number, they refuse every number.
        ;;
        ;; *** The payload must be OTHERWISE VALID, and Slice ② found out why.
        ;; *** It was a two-member vector, which the ABI-4 payload guard also
        ;; refuses; once Slice ② made the current minimum three, disarming the
        ;; version check left this case still raising -- from the payload guard
        ;; -- and the version check's own mutation reported CAUGHT FOR THE WRONG
        ;; REASON. `(lambda (e) #t)` accepts any raise, so only the payload can
        ;; make this case about the version.
        (check-raises "refused" (lambda (e) #t)
                      (lambda () (byte-machine-make-compiled-machine
                                  1 99 0 stub-exec
                                  (vector (vector) (vector) stub-names))))))
    (harness-case "a /v2 finish error is stored and repeated on the next call"
      (lambda ()
        ;; Witnesses parser-finish-v2!'s own store -- a separate site from the
        ;; op-path stores above and below, distinct code with no other witness.
        (let ((p (make-parser (v2-machine) '() #f)))
          (parser-finish! p)                                    ; -> error, stores 'eof
          (check-equal "lifecycle" (parser-lifecycle p) 'error)
          (check-equal "finish repeats the stored /v2 error"
                       (error-code-of (parser-finish! p)) 'eof))))
    (harness-case "a /v2 finish reaching a pause state sets paused-finish"
      (lambda ()
        ;; Witnesses parser-finish-v2!'s own paused arm -- distinct code from
        ;; the shared parser-feed! wrapper's paused arm (op-witnessed above)
        ;; and from parser-finish-op!'s pause arm (also op-witnessed): no other
        ;; /v2 fixture reaches a pause state.
        (let* ((p (make-parser (v2-pause-machine) '() #f))
               (r (parser-finish! p)))
          (check-equal "status" (parser-result-status r) 'paused)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-finish))))))

(harness-group "invalid feed slices"
  (lambda ()
    (harness-case "a slice past the bytevector end raises a coded contract condition"
      (lambda ()
        (check-raises "invalid slice"
          (lambda (e)
            (and (byte-machine-contract-condition? e)
                 (eq? (byte-machine-contract-condition-code e) 'invalid-slice)
                 (eq? (byte-machine-contract-condition-who e) 'parser-feed!)))
          (lambda ()
            (parser-feed! (make-parser (make-compiled-machine one-byte-op) '() #f)
                          (make-bytevector 1 0) 0 5)))))))

(harness-group "parser-reset!"
  (lambda ()
    ;; Witness current-restoration via a status CHANGE: reach the error terminal,
    ;; reset, then feed byte 0. From the entry state byte 0 is ACCEPTED (stopped);
    ;; if reset failed to restore `current`, the parser would still be at the error
    ;; node and the result would stay 'error. (For an accept-then-accept sequence,
    ;; both entry and the stop terminal yield 'stopped, so only the offset would
    ;; differ -- which would witness the wrong decision. Hence error-then-accept.)
    (harness-case "reset returns to ready and re-parses from the entry state"
      (lambda ()
        (let ((p (make-parser (v2-machine) '() #f)))
          (parser-feed! p (make-bytevector 1 65) 0 1)         ; -> error, parked at the error node
          (check-equal "error before reset" (parser-lifecycle p) 'error)
          (parser-reset! p)
          (check-equal "ready after reset" (parser-lifecycle p) 'ready)
          (check-equal "re-parses from entry"
                       (parser-result-status (parser-feed! p (make-bytevector 1 0) 0 1))
                       'stopped))))
    (harness-case "reset zeroes the stream offset"
      (lambda ()
        (let ((p (make-parser (v2-machine) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)          ; advance -> offset 1, stopped
          (parser-reset! p)
          (check-equal "offset zeroed then advanced by one"
                       (parser-result-stream-offset (parser-feed! p (make-bytevector 1 0) 0 1))
                       1))))))

;; Slice 3: pause/resume + the full §12.2 operation matrix. This stub encodes a
;; two-pause machine: entry s0 dispatches byte 1 to a pause (continuation s1,
;; the post-pause dispatch state), s1 dispatches byte 2 to stop, and s0's own
;; eof-target is a second pause (pe, continuation done -- a finish node) so
;; parser-finish! also exercises the pause arm. Any other byte at either
;; dispatch state reexecutes into the error node (trunc when reached via s1's
;; eof-target, reject otherwise).
(define (pause-op msg . args)
  (case msg
    ;; Slice ①b task 6: make-parser asks every op closure for the field
    ;; declarations, so every hand-written stub answers it. These stubs declare
    ;; no fields, which is what keeps their parsers byte-for-byte what they were.
    ((field-initials) (vector))
    ;; Slice ①b: the op interface gained `callback-decls`. A stub standing in
    ;; for the interpreter must answer it, and a missing arm is LOUD by design.
    ((callback-decls) (vector))
    ((entry) 's0)
    ((kind) (case (car args)
              ((s0 s1) 'dispatch) ((p pe) 'pause) ((stop) 'stop)
              ((done) 'finish) ((trunc reject) 'error)))
    ((dispatch)
     (let ((node (car args)) (byte (cadr args)))
       (case node
         ((s0) (if (= byte 1) (cons 'p 'advance) (cons 'reject 'reexecute)))
         ((s1) (if (= byte 2) (cons 'stop 'advance) (cons 'reject 'reexecute))))))
    ((pause-target) (case (car args) ((p) 's1) ((pe) 'done)))
    ((eof-target) (case (car args) ((s0) 'pe) ((s1) 'trunc)))
    ((error-value) (case (car args)
                     ((trunc) (list 'truncated-input "truncated input" 'trunc 4))
                     (else (list 'unexpected-byte "unexpected byte" 'reject 7))))
    (else (assertion-violation 'pause-op "bad message" msg))))

(define (pause-parser) (make-parser (make-compiled-machine pause-op) '() #f))
(define (lifecycle-violation? who state op)
  ;; D2: detail is (list <state> <op>) -- both are asserted, so a condition
  ;; reporting the right op but the wrong offending row does not pass.
  (lambda (e)
    (and (byte-machine-contract-condition? e)
         (eq? (byte-machine-contract-condition-code e) 'lifecycle-violation)
         (eq? (byte-machine-contract-condition-who e) who)
         (eq? (car (byte-machine-contract-condition-detail e)) state)
         (eq? (cadr (byte-machine-contract-condition-detail e)) op))))

(harness-group "pause + resume (§12.1)"
  (lambda ()
    (harness-case "feed pauses at the pause node with the first unconsumed index"
      (lambda ()
        (let* ((p (pause-parser))
               (r (parser-feed! p (make-bytevector 2 1) 0 2)))   ; bytes 1 1
          (check-equal "status" (parser-result-status r) 'paused)
          (check-equal "next" (parser-result-next r) 1)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-feed))))
    (harness-case "a nonzero-start feed pause separates next, consumed, and stream offset"
      (lambda ()
        ;; Whole-branch review Critical 1: every OTHER pause case in this file
        ;; feeds from start 0, where next, consumed, and stream-offset are
        ;; numerically identical (all 1) and cannot separate "computed
        ;; correctly" from "all three hard-wired to next" -- the same trap
        ;; already closed for the sticky error arm's `next` field (see the
        ;; "error row's next mirrors the new call's start" mutation below).
        ;; Feeding from a nonzero start breaks the coincidence between next
        ;; and the other two: next is the absolute position (2), while
        ;; consumed and stream-offset both stay 1. It does NOT separate
        ;; consumed from stream-offset -- on any single feed call from a
        ;; fresh parser those two are equal by construction (the offset
        ;; starts at 0, so the cross-call total equals this call's own
        ;; count); see the next case for that.
        (let* ((p (pause-parser))
               (r (parser-feed! p (u8-list->bytevector (list 9 1 2)) 1 3)))
          (check-equal "status" (parser-result-status r) 'paused)
          (check-equal "next" (parser-result-next r) 2)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "stream offset" (parser-result-stream-offset r) 1))))
    (harness-case "a second feed call separates consumed from stream offset"
      (lambda ()
        ;; T8 re-review residual: no start offset can separate consumed from
        ;; stream-offset on a single call (see the previous case's comment).
        ;; Only a second feed call can -- this one consumes a byte at s0
        ;; first (offset 0->1), then a second call consumes another at s1
        ;; before pausing (offset 1->2), so consumed (this call's own 1
        ;; byte) and stream-offset (the persisted total, 2) diverge.
        (let ((p (make-parser (make-compiled-machine finish-pause-op) '() #f)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (let ((r (parser-feed! p (make-bytevector 1 2) 0 1)))
            (check-equal "status" (parser-result-status r) 'paused)
            (check-equal "next" (parser-result-next r) 1)
            (check-equal "consumed" (parser-result-consumed r) 1)
            (check-equal "stream offset" (parser-result-stream-offset r) 2)))))
    (harness-case "resume from a feed pause acks feed-ready and reopens feed"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (check-equal "ack" (parser-resume! p) 'feed-ready)
          (check-equal "lifecycle" (parser-lifecycle p) 'ready)
          (let ((r (parser-feed! p (make-bytevector 1 2) 0 1)))
            (check-equal "continues past the pause" (parser-result-status r) 'stopped)))))
    (harness-case "finish! pauses on the EOF path and resumes to finish-ready"
      (lambda ()
        (let* ((p (pause-parser))
               (r (parser-finish! p)))
          (check-equal "status" (parser-result-status r) 'paused)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-finish)
          (check-equal "ack" (parser-resume! p) 'finish-ready)
          (check-equal "lifecycle now" (parser-lifecycle p) 'finish-ready)
          (let ((r2 (parser-finish! p)))
            (check-equal "continues to finished" (parser-result-status r2) 'finished)
            (check-equal "lifecycle final" (parser-lifecycle p) 'finished)))))))

(harness-group "operation matrix (§12.2)"
  (lambda ()
    (harness-case "feed is prohibited in paused-feed, paused-finish, and finish-ready"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)             ; -> paused-feed
          (check-raises "feed on paused-feed" (lifecycle-violation? 'parser-feed! 'paused-feed 'feed)
            (lambda () (parser-feed! p (make-bytevector 1 2) 0 1))))
        (let ((p (pause-parser)))
          (parser-finish! p)                                     ; -> paused-finish
          (check-raises "feed on paused-finish" (lifecycle-violation? 'parser-feed! 'paused-finish 'feed)
            (lambda () (parser-feed! p (make-bytevector 1 2) 0 1)))
          (parser-resume! p)                                     ; -> finish-ready
          (check-raises "feed on finish-ready" (lifecycle-violation? 'parser-feed! 'finish-ready 'feed)
            (lambda () (parser-feed! p (make-bytevector 1 2) 0 1))))))
    (harness-case "finish is prohibited while paused"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (check-raises "finish on paused-feed" (lifecycle-violation? 'parser-finish! 'paused-feed 'finish)
            (lambda () (parser-finish! p))))
        (let ((p (pause-parser)))
          (parser-finish! p)
          (check-raises "finish on paused-finish" (lifecycle-violation? 'parser-finish! 'paused-finish 'finish)
            (lambda () (parser-finish! p))))))
    (harness-case "resume is prohibited outside the paused rows"
      (lambda ()
        (check-raises "resume on ready" (lifecycle-violation? 'parser-resume! 'ready 'resume)
          (lambda () (parser-resume! (pause-parser))))
        (let ((p (pause-parser)))
          (parser-finish! p) (parser-resume! p)                  ; -> finish-ready
          (check-raises "resume on finish-ready" (lifecycle-violation? 'parser-resume! 'finish-ready 'resume)
            (lambda () (parser-resume! p))))
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)             ; -> stopped
          (check-raises "resume on stopped" (lifecycle-violation? 'parser-resume! 'stopped 'resume)
            (lambda () (parser-resume! p))))
        ;; Review (Task 7 close-out): the two rows above and the v1 case below
        ;; left error/finished x resume! -- both prohibited (§12.2:696-697)
        ;; -- with no direct witness. A mutation admitting only error/finished
        ;; (leaving ready/stopped/finish-ready correctly refused) would have
        ;; survived undetected.
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 65) 0 1)            ; -> error
          (check-raises "resume on error" (lifecycle-violation? 'parser-resume! 'error 'resume)
            (lambda () (parser-resume! p))))
        (let ((p (pause-parser)))
          (parser-finish! p) (parser-resume! p) (parser-finish! p) ; -> finished
          (check-raises "resume on finished" (lifecycle-violation? 'parser-resume! 'finished 'resume)
            (lambda () (parser-resume! p))))
        ;; D7: v1 can never reach a *paused* row (the v1 ABI predates
        ;; `paused`), so resume! on a v1 parser is always refused -- the
        ;; guard is variant-agnostic (it reads only lifecycle). This witnesses
        ;; it through 'ready, the state right after construction; v1 can also
        ;; reach 'stopped and 'error, and resume! is refused from those too, by
        ;; the same variant-agnostic guard the error/finished cases just above
        ;; already exercise -- the generated variant adds no row the guard
        ;; treats differently. (Was written against the retired /v1 variant.)
        (check-raises "resume on a generated parser"
          (lifecycle-violation? 'parser-resume! 'ready 'resume)
          (lambda () (parser-resume! (make-parser (v2-machine) '() #f))))))
    (harness-case "sticky rows short-circuit: stopped feed/finish return the tuple"
      (lambda ()
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)
          (let ((r (parser-feed! p (make-bytevector 3 0) 1 3)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "next is the new start" (parser-result-next r) 1)
            (check-equal "consumed zero" (parser-result-consumed r) 0))
          (check-equal "finish on stopped returns stopped"
                       (parser-result-status (parser-finish! p)) 'stopped))))
    (harness-case "the error row returns the stored error after a feed error"
      (lambda ()
        ;; Witnesses parser-feed!'s own store (the finish-path store below is a
        ;; separate site with its own mutation).
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 65) 0 1)            ; -> error
          ;; Nonzero start: with the prior zero-start read-back, `start`,
          ;; the literal 0, and (parser-offset parser) (also 0 here) were
          ;; indistinguishable, so a next-field regression had no witness.
          (let ((r (parser-feed! p (make-bytevector 3 0) 1 3)))
            (check-equal "sticky status" (parser-result-status r) 'error)
            (check-equal "next is the new start" (parser-result-next r) 1)
            (check-equal "feed-stored error value" (error-code-of r) 'unexpected-byte))
          (check-equal "finish repeats the feed-stored error"
                       (error-code-of (parser-finish! p)) 'unexpected-byte))))
    (harness-case "the error row returns the stored error after a default-EOF truncation"
      (lambda ()
        ;; Closes the ②b-2 carry: with default-eof-op (eof-target #f), finish!
        ;; errors via the machine default while current stays on the dispatch node;
        ;; the old re-execution mechanism would re-run dispatch and consume bytes.
        (let ((p (make-parser (make-compiled-machine default-eof-op) '() #f)))
          (parser-finish! p)
          (let ((r (parser-feed! p (make-bytevector 1 0) 0 1)))
            (check-equal "status stays error" (parser-result-status r) 'error)
            (check-equal "consumed zero" (parser-result-consumed r) 0)
            (check-equal "stored error value" (error-code-of r) 'eof))
          (check-equal "finish repeats the stored error"
                       (error-code-of (parser-finish! p)) 'eof))))
    (harness-case "finish reaches a named error node via the eof-target chain and stores it"
      (lambda ()
        ;; Witnesses parser-finish-op!'s own plain error arm -- distinct from
        ;; both the feed-side store above and the default-eof arm above: s1's
        ;; eof-target is a NAMED error node ('trunc), reached only after a
        ;; pause+resume moves current past s0's own pause. No other case in
        ;; this file drives an eof-target chain into a named (non-default)
        ;; error node.
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)             ; -> paused-feed at p
          (parser-resume! p)                                     ; -> ready, current = s1
          (let ((r (parser-finish! p)))
            (check-equal "status" (parser-result-status r) 'error)
            (check-equal "error value" (error-code-of r) 'truncated-input)
            (check-equal "lifecycle" (parser-lifecycle p) 'error))
          (check-equal "finish repeats the finish-stored error"
                       (error-code-of (parser-finish! p)) 'truncated-input))))
    ;; stopped and error are already covered by the pre-existing
    ;; "parser-reset!" group above; ready is trivial (reset is idempotent on
    ;; it). The four rows below are the ones this task's own lifecycle adds.
    (harness-case "reset recovers every reachable row to ready"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)             ; paused-feed
          (parser-reset! p)
          (check-equal "from paused-feed" (parser-lifecycle p) 'ready))
        (let ((p (pause-parser)))
          (parser-finish! p)                                     ; paused-finish
          (parser-reset! p)
          (check-equal "from paused-finish" (parser-lifecycle p) 'ready))
        (let ((p (pause-parser)))
          (parser-finish! p) (parser-resume! p)                  ; finish-ready
          (parser-reset! p)
          (check-equal "from finish-ready" (parser-lifecycle p) 'ready)
          (check-equal "re-feeds from entry"
                       (parser-result-status (parser-feed! p (make-bytevector 1 1) 0 1))
                       'paused))
        (let ((p (pause-parser)))
          (parser-finish! p) (parser-resume! p) (parser-finish! p) ; finished
          (parser-reset! p)
          (check-equal "from finished" (parser-lifecycle p) 'ready))))))

;; Milestone 4 Slice ①a task 2: the §9.3:397-405 parser-error family, shipped
;; whole and inert. Nothing constructs one outside this file until task 5 wires
;; both executors; these cases exist so the record's shape is pinned before
;; anything depends on it. milestone-2-design.md:343-344 is why the family lands
;; at once rather than a member at a time.
(harness-group "the parser-error record"
  (lambda ()
    ;; Decision 0022 item 1: the reserved constructor takes FIVE arguments, not
    ;; eight -- an errs-table entry packing code and reason, the public source
    ;; node name, the state id, the absolute offset, and the position kind.
    (define (err) (byte-machine-make-parser-error/v1
                   (vector 'unexpected-byte "unexpected byte") 'reject 2 7 'byte))
    (harness-case "the predicate accepts it and rejects everything else"
      (lambda ()
        (check "record" (parser-error? (err)))
        (check "not a symbol" (not (parser-error? 'unexpected-byte)))
        ;; A parser-result must not answer the parser-error predicate: the two
        ;; tags sit side by side and both are vectors.
        (check "not a parser-result"
               (not (parser-error?
                     (parser-feed! (make-parser (make-compiled-machine one-byte-op) '() #f)
                                   (make-bytevector 1 7) 0 1))))))
    (harness-case "the five call-site members read back"
      (lambda ()
        (check-equal "code" (parser-error-code (err)) 'unexpected-byte)
        (check-equal "reason" (parser-error-reason (err)) "unexpected byte")
        (check-equal "node-name" (parser-error-node-name (err)) 'reject)
        (check-equal "state-id" (parser-error-state-id (err)) 2)
        (check-equal "offset" (parser-error-offset (err)) 7)
        (check-equal "position-kind" (parser-error-position-kind (err)) 'byte)))
    (harness-case "domain and detail are fixed by the constructor"
      (lambda ()
        ;; Decision 0022 item 2: domain and detail are NOT call-site arguments.
        ;; #f is not a placeholder -- §9.3:401 annotates detail "#f for machine
        ;; errors" -- and `callback` has no producer until Milestone 5, which is
        ;; the ordinary condition of a closed enumeration mid-plan.
        (check-equal "domain" (parser-error-domain (err)) 'machine)
        (check-equal "detail" (parser-error-detail (err)) #f)))))

(harness-finish)
