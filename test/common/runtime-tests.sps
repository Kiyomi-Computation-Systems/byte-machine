;;; Runtime parser lifecycle over a hand-built compiled-machine stub, so the
;;; loop is witnessed independently of the interpreter (Task 5 supplies the real
;;; op). The stub encodes the one-byte machine: byte 0 advances to stop; any
;;; other byte reexecutes into the error node.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine runtime))

(harness-begin "unit.runtime")

(define (one-byte-op msg . args)
  (case msg
    ((entry) 'start)
    ((kind) (case (car args) ((start) 'dispatch) ((stop) 'stop) ((reject) 'error)))
    ((dispatch)
     (let ((byte (cadr args)))
       (if (= byte 0) (cons 'stop 'advance) (cons 'reject 'reexecute))))
    ((error-value) 'unexpected-byte)
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
          (check-equal "error value" (parser-result-error r) 'unexpected-byte))))
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
    ((entry) 's0)
    ((kind) (case (car args) ((s0) 'dispatch) ((done) 'finish)
              (else (assertion-violation 'eof-target-op "bad node" (car args)))))
    ((eof-target) (case (car args) ((s0) 'done) (else #f)))
    ((default-eof-value) 'eof)
    (else (assertion-violation 'eof-target-op "bad message" msg))))

(define (default-eof-op msg . args)
  (case msg
    ((entry) 's0)
    ((kind) (case (car args) ((s0) 'dispatch)
              (else (assertion-violation 'default-eof-op "bad node" (car args)))))
    ((eof-target) #f)
    ((default-eof-value) 'eof)
    (else (assertion-violation 'default-eof-op "bad message" msg))))

(define (finish-feed-op msg . args)
  (case msg
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
    ((default-eof-value) 'eof)
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
          (check-equal "default-eof code" (parser-result-error r) 'eof))))
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

;; The direct-executor ABI. A hand-built feed encodes the one-byte machine over
;; numeric states (0 dispatch, 1 stop, 2 error), so the v1 (feed-only) path is
;; witnessed independently of the emitter. It declares abi 2 -- the current ABI
;; version -- because /v1's guard checks (= abi current-abi-version): after the
;; Slice ②b-2 bump, abi 1 is a stale-file mismatch (witnessed by the dedicated
;; refusal case below), so exercising the v1 code path needs the matching 2.
(define (stub-feed state offset bv start end)
  (let loop ((pos start) (st state) (off offset))
    (case st
      ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 'error pos 'unexpected-byte 2 off))
      (else
       (if (>= pos end)
           (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off)
           (let ((b (bytevector-u8-ref bv pos)))
             (if (= b 0) (loop (+ pos 1) 1 (+ off 1)) (loop pos 2 off))))))))
(define (v1-machine) (byte-machine-make-compiled-machine/v1 2 42 0 stub-feed))
(define (v1-feed-byte b)
  (parser-feed! (make-parser (v1-machine) '() #f) (make-bytevector 1 b) 0 1))

(harness-group "generated-code ABI (/v1)"
  (lambda ()
    (harness-case "the accepted byte stops after consuming one byte"
      (lambda ()
        (let ((r (v1-feed-byte 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "stream offset" (parser-result-stream-offset r) 1))))
    (harness-case "a rejected byte errors at position 0 with the code"
      (lambda ()
        (let ((r (v1-feed-byte 65)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "stream offset" (parser-result-stream-offset r) 0)
          (check-equal "error value" (parser-result-error r) 'unexpected-byte))))
    (harness-case "an empty slice needs input"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (got 'not-yet))
          (set! got (parser-result-status (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" got 'need-input))))
    (harness-case "a repeat feed on a terminal parser reports a fresh empty result (§12.2)"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (r1 (parser-feed! p (make-bytevector 1 0) 0 1))
               (r2 (parser-feed! p (make-bytevector 1 0) 0 1)))
          (check-equal "first stopped" (parser-result-status r1) 'stopped)
          (check-equal "second still stopped" (parser-result-status r2) 'stopped)
          (check-equal "second next is the new slice start" (parser-result-next r2) 0)
          (check-equal "second consumed is zero" (parser-result-consumed r2) 0)
          (check-equal "second stream offset unchanged"
                       (parser-result-stream-offset r2) (parser-result-stream-offset r1)))))
    (harness-case "parser-lifecycle tracks ready -> terminal"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
          (check-equal "starts ready" (parser-lifecycle p) 'ready)
          (parser-feed! p (make-bytevector 1 0) 0 1)
          (check-equal "stopped after accept" (parser-lifecycle p) 'stopped)
          (let ((q (make-parser (v1-machine) '() #f)))
            (parser-feed! q (make-bytevector 1 65) 0 1)
            (check-equal "error after reject" (parser-lifecycle q) 'error)))))
    ;; A stale v1 file declares abi 1; after the ②b-2 bump current-abi-version is
    ;; 2, so /v1 with abi 1 is refused as a clean version mismatch (1 =/= 2).
    (harness-case "a mismatched ABI version is refused"
      (lambda ()
        (check-raises "refused"
                      (lambda (e) #t)
                      (lambda () (byte-machine-make-compiled-machine/v1 1 42 0 stub-feed)))))
    ;; D7: v1 can never pause, so parser-finish!'s v1 else arm (runtime.sls,
    ;; "v1 has no finish path") is reachable only from a still-`ready` v1
    ;; parser -- a fresh one, or one fed only empty/need-input slices (the
    ;; "an empty slice needs input" case above is exactly that: it returns
    ;; 'need-input and lifecycle stays 'ready).
    (harness-case "finish on a still-ready v1 parser raises: v1 has no finish path"
      (lambda ()
        (check-raises "v1 has no finish path"
                      assertion-violation?
                      (lambda () (parser-finish! (make-parser (v1-machine) '() #f))))))
    ;; Once fed to a terminal row, D1's sticky short-circuit checks lifecycle
    ;; before variant -- parser-finish! never reaches the v1 else arm above,
    ;; so a v1 parser already stopped/errored returns the ordinary sticky
    ;; tuple instead of raising, unlike before this task.
    (harness-case "finish on a terminal v1 parser returns the sticky tuple instead"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)             ; -> stopped
          (check-equal "sticky status" (parser-result-status (parser-finish! p)) 'stopped))))))

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
(define (stub-exec state offset bv start end finish?)
  (let loop ((pos start) (st state) (off offset))
    (case st
      ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 'error pos 'unexpected-byte 2 off))
      ((3) (byte-machine-make-feed-outcome/v1 'paused pos #f 1 off))
      (else
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 'error pos 'eof 0 off)   ; eof-target #f -> default
               (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (if (= b 0) (loop (+ pos 1) 1 (+ off 1)) (loop pos 2 off))))))))
(define (v2-machine) (byte-machine-make-compiled-machine/v2 2 99 0 stub-exec))
(define (v2-pause-machine) (byte-machine-make-compiled-machine/v2 2 99 3 stub-exec))

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
          (check-equal "default-eof code" (parser-result-error r) 'eof))))
    (harness-case "a mismatched /v2 ABI version is refused"
      (lambda ()
        (check-raises "refused" (lambda (e) #t)
                      (lambda () (byte-machine-make-compiled-machine/v2 1 99 0 stub-exec)))))
    (harness-case "a /v2 finish error is stored and repeated on the next call"
      (lambda ()
        ;; Witnesses parser-finish-v2!'s own store -- a separate site from the
        ;; op-path stores above and below, distinct code with no other witness.
        (let ((p (make-parser (v2-machine) '() #f)))
          (parser-finish! p)                                    ; -> error, stores 'eof
          (check-equal "lifecycle" (parser-lifecycle p) 'error)
          (check-equal "finish repeats the stored /v2 error"
                       (parser-result-error (parser-finish! p)) 'eof))))
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
        (let ((p (make-parser (v1-machine) '() #f)))
          (parser-feed! p (make-bytevector 1 65) 0 1)         ; -> error, parked at the error node
          (check-equal "error before reset" (parser-lifecycle p) 'error)
          (parser-reset! p)
          (check-equal "ready after reset" (parser-lifecycle p) 'ready)
          (check-equal "re-parses from entry"
                       (parser-result-status (parser-feed! p (make-bytevector 1 0) 0 1))
                       'stopped))))
    (harness-case "reset zeroes the stream offset"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
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
    ((error-value) (case (car args) ((trunc) 'truncated-input) (else 'unexpected-byte)))
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
        ;; reach 'stopped and 'error (the "generated-code ABI (/v1)" cases
        ;; above show both), and resume! is refused from those too, by the
        ;; same variant-agnostic guard the error/finished cases just above
        ;; already exercise -- v1 adds no row the guard treats differently.
        (check-raises "resume on a v1 parser" (lifecycle-violation? 'parser-resume! 'ready 'resume)
          (lambda () (parser-resume! (make-parser (v1-machine) '() #f))))))
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
            (check-equal "feed-stored error value" (parser-result-error r) 'unexpected-byte))
          (check-equal "finish repeats the feed-stored error"
                       (parser-result-error (parser-finish! p)) 'unexpected-byte))))
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
            (check-equal "stored error value" (parser-result-error r) 'eof))
          (check-equal "finish repeats the stored error"
                       (parser-result-error (parser-finish! p)) 'eof))))
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
            (check-equal "error value" (parser-result-error r) 'truncated-input)
            (check-equal "lifecycle" (parser-lifecycle p) 'error))
          (check-equal "finish repeats the finish-stored error"
                       (parser-result-error (parser-finish! p)) 'truncated-input))))
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
