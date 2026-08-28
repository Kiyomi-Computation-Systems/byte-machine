;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile (parent §7.2). Two executor variants share this one parser API and
;;; the one parser-result contract: the reference interpreter builds an `op`
;;; message closure over the source IR; generated code (Phase 3, decision 0010)
;;; is a direct resumable executor constructed through
;;; byte-machine-make-compiled-machine/v1. The two are deliberately different
;;; implementations, which is what lets the interpreter≡generated differential
;;; catch lowering defects (parent §18, §22.4).
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
          byte-machine-make-compiled-machine/v1 byte-machine-make-compiled-machine/v2
          byte-machine-make-feed-outcome/v1
          make-parser parser?
          parser-feed! parser-finish! parser-lifecycle parser-reset!
          parser-result? parser-result-status parser-result-next
          parser-result-consumed parser-result-stream-offset parser-result-error
          callback-continue callback-pause)
  (import (rnrs)
          (byte-machine private conditions))

  (define (tag sym) (vector sym))
  (define (tagged? t x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))

  ;; Allocation-free outcome singletons (parent §13). M1 exercises neither;
  ;; they fix the contract so interpreter and generated callbacks return the
  ;; same objects once callbacks land.
  (define callback-continue (vector 'byte-machine-callback-continue))
  (define callback-pause (vector 'byte-machine-callback-pause))

  ;; --- compiled machine: three variants behind one type ---
  ;; op:  (vector tag 'op op-closure)                    -- the reference interpreter
  ;; v1:  (vector tag 'v1 feed entry-state fingerprint)  -- the pre-②b-2 feed-only
  ;;      ABI, kept only so a stale v1 file (declaring abi 1) is refused cleanly.
  ;; v2:  (vector tag 'v2 exec entry-state fingerprint)  -- generated code, one
  ;;      unified `exec` closure carrying a finish? flag (Slice ②b-2). This is the
  ;;      ABI the emitter now emits (Task 2 flipped generation).
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag 'op op))
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-variant cm) (vector-ref cm 1))

  ;; The ABI version the emitter currently emits. Bumped to 2 when generation
  ;; flipped to the unified /v2 `exec` (Slice ②b-2); the /v1 constructor checks
  ;; it, so a stale generated file (which declared abi 1) is now refused cleanly.
  (define current-abi-version 2)
  (define (byte-machine-make-compiled-machine/v1 abi-version ir-fingerprint entry-state feed)
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine/v1
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? feed)
      (assertion-violation 'byte-machine-make-compiled-machine/v1 "feed must be a procedure" feed))
    (vector compiled-machine-tag 'v1 feed entry-state ir-fingerprint))
  (define (compiled-machine-v1-feed cm) (vector-ref cm 2))
  (define (compiled-machine-v1-entry-state cm) (vector-ref cm 3))

  ;; The /v2 constructor (Slice ②b-2). Same shape as /v1, but the executor is a
  ;; finish?-aware `exec` -- (state offset bv start end finish?) -> feed-outcome --
  ;; so one closure serves both parser-feed! (finish? #f) and parser-finish!
  ;; (finish? #t). It checks the literal 2, matching what the emitter now emits;
  ;; Task 2's current-abi-version bump made this the live generated ABI.
  (define (byte-machine-make-compiled-machine/v2 abi-version ir-fingerprint entry-state exec)
    (unless (and (integer? abi-version) (= abi-version 2))
      (assertion-violation 'byte-machine-make-compiled-machine/v2
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine/v2 "exec must be a procedure" exec))
    (vector compiled-machine-tag 'v2 exec entry-state ir-fingerprint))
  (define (compiled-machine-v2-exec cm) (vector-ref cm 2))
  (define (compiled-machine-v2-entry-state cm) (vector-ref cm 3))
  (define empty-bv (make-bytevector 0))

  ;; --- feed outcome (the runtime<-generated seam; accessors private) ---
  (define feed-outcome-tag (tag 'byte-machine-feed-outcome))
  (define (byte-machine-make-feed-outcome/v1 status next error next-state offset)
    (vector feed-outcome-tag status next error next-state offset))
  (define (feed-outcome-status o) (vector-ref o 1))
  (define (feed-outcome-next o) (vector-ref o 2))
  (define (feed-outcome-error o) (vector-ref o 3))
  (define (feed-outcome-next-state o) (vector-ref o 4))
  (define (feed-outcome-offset o) (vector-ref o 5))

  ;; --- parser result (immutable snapshot) ---
  (define parser-result-tag (tag 'byte-machine-parser-result))
  (define (make-parser-result status next consumed stream-offset error)
    (vector parser-result-tag status next consumed stream-offset error))
  (define (parser-result? x) (tagged? parser-result-tag x))
  (define (parser-result-status r) (vector-ref r 1))
  (define (parser-result-next r) (vector-ref r 2))
  (define (parser-result-consumed r) (vector-ref r 3))
  (define (parser-result-stream-offset r) (vector-ref r 4))
  (define (parser-result-error r) (vector-ref r 5))

  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor entry current offset lifecycle)
  ;; lifecycle: ready | stopped | error | finished   (paused/finish-ready arrive in
  ;; Slice ③). There is no cached "sticky" result: a repeat feed on a terminal
  ;; parser re-runs the executor, which is idempotent for stop/error (and, in ②b,
  ;; finish) and returns the §12.2 sticky-repeat tuple by construction. A stored-
  ;; result short-circuit returns at M5, when callbacks make re-execution
  ;; non-idempotent (design milestone-2-design.md §5).
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (cond
      ((eq? (compiled-machine-variant compiled-machine) 'op)
       (let* ((op (vector-ref compiled-machine 2)) (entry (op 'entry)))
         (vector parser-tag 'op op entry entry 0 'ready)))
      ((eq? (compiled-machine-variant compiled-machine) 'v2)
       (let ((exec (compiled-machine-v2-exec compiled-machine))
             (entry-state (compiled-machine-v2-entry-state compiled-machine)))
         (vector parser-tag 'v2 exec entry-state entry-state 0 'ready)))
      (else
       (let ((feed (compiled-machine-v1-feed compiled-machine))
             (entry-state (compiled-machine-v1-entry-state compiled-machine)))
         (vector parser-tag 'v1 feed entry-state entry-state 0 'ready)))))
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-variant p) (vector-ref p 1))
  (define (parser-executor p) (vector-ref p 2))
  (define (parser-entry p) (vector-ref p 3))
  (define (parser-current p) (vector-ref p 4))
  (define (parser-set-current! p v) (vector-set! p 4 v))
  (define (parser-offset p) (vector-ref p 5))
  (define (parser-set-offset! p v) (vector-set! p 5 v))
  (define (parser-lifecycle p) (vector-ref p 6))
  (define (parser-set-lifecycle! p v) (vector-set! p 6 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    (let ((r (case (parser-variant parser)
               ((op) (parser-feed-op! parser bv start end))
               ((v2) (parser-feed-v2! parser bv start end))
               (else (parser-feed-v1! parser bv start end)))))
      (case (parser-result-status r)
        ((stopped) (parser-set-lifecycle! parser 'stopped))
        ((error) (parser-set-lifecycle! parser 'error))
        ((finished) (parser-set-lifecycle! parser 'finished)))
      r))

  ;; The interpreter path. stop/error return a fresh result each call — no cache —
  ;; so a repeat feed on a terminal parser re-runs here and returns (status, next=
  ;; start, consumed=0, stored offset) by construction (§12.2).
  (define (parser-feed-op! parser bv start end)
    (let ((op (parser-executor parser)))
      (let loop ((pos start))
        (let ((node (parser-current parser)))
          (case (op 'kind node)
            ((stop)
             (make-parser-result 'stopped pos (- pos start) (parser-offset parser) #f))
            ((error)
             (make-parser-result 'error pos (- pos start) (parser-offset parser)
                                 (op 'error-value node)))
            ((finish)
             (make-parser-result 'finished pos (- pos start) (parser-offset parser) #f))
            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f)
                 (let* ((byte (bytevector-u8-ref bv pos))
                        (trans (op 'dispatch node byte))
                        (target (car trans))
                        (mode (cdr trans)))
                   (parser-set-current! parser target)
                   (if (eq? mode 'advance)
                       (begin
                         (parser-set-offset! parser (+ 1 (parser-offset parser)))
                         (loop (+ pos 1)))
                       (loop pos)))))
            (else (assertion-violation 'parser-feed! "unknown node kind" (op 'kind node))))))))

  ;; The generated path: the feed owns the dispatch loop and returns one outcome;
  ;; the runtime commits resume state and builds the result. No cache (see above).
  (define (parser-feed-v1! parser bv start end)
    (let* ((feed (parser-executor parser))
           (o (feed (parser-current parser) (parser-offset parser) bv start end))
           (status (feed-outcome-status o))
           (next (feed-outcome-next o)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (make-parser-result status next (- next start)
                          (feed-outcome-offset o) (feed-outcome-error o))))

  ;; The generated /v2 path: exec owns the dispatch loop; finish? = #f for feed.
  (define (parser-feed-v2! parser bv start end)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) bv start end #f)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (make-parser-result (feed-outcome-status o) (feed-outcome-next o)
                          (- (feed-outcome-next o) start)
                          (feed-outcome-offset o) (feed-outcome-error o))))

  ;; parser-finish! (§12.4): run the executor with input exhausted. From the
  ;; current state, an exhausted dispatch takes its eof-target (a named node, else
  ;; the machine default-eof-error); execution continues to a finish node
  ;; (-> finished), an error node (-> error), or a stop node reached this way is
  ;; verifier-rejected so it never occurs. No slice, so next/consumed mirror the
  ;; stream offset / 0. The generated /v2 finish path runs the same `exec` with
  ;; finish? #t (Slice ②b-2); v1 never supported finish, so its else arm stays an
  ;; assertion violation.
  (define (parser-finish! parser)
    (case (parser-variant parser)
      ((op) (parser-finish-op! parser))
      ((v2) (parser-finish-v2! parser))
      (else (assertion-violation 'parser-finish! "v1 has no finish path" (parser-variant parser)))))

  ;; The generated /v2 finish path: run exec over the empty slice with finish? #t.
  ;; exec owns the eof-target chain internally (Task 2 lowers it); the runtime just
  ;; commits resume state, records the terminal lifecycle, and snapshots the result
  ;; (no slice, so next/consumed mirror the stream offset / 0).
  (define (parser-finish-v2! parser)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (case (feed-outcome-status o)
        ((finished) (parser-set-lifecycle! parser 'finished))
        ((error) (parser-set-lifecycle! parser 'error))
        ((stopped) (parser-set-lifecycle! parser 'stopped)))
      (make-parser-result (feed-outcome-status o) (feed-outcome-offset o) 0
                          (feed-outcome-offset o) (feed-outcome-error o))))

  (define (parser-finish-op! parser)
    ;; No local cycle guard: termination relies on the verifier's
    ;; eof-zero-progress-cycle/eof-reachable-stop checks having already rejected
    ;; non-terminating and stop-terminating EOF chains, so this loop terminates
    ;; only for verified machines -- relevant once Slice ②b-2's generated v1
    ;; finish path arrives, since it does not re-verify at runtime.
    (let ((op (parser-executor parser))
          (off (parser-offset parser)))
      (let loop ((node (parser-current parser)))
        (case (op 'kind node)
          ((finish)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'finished)
           (make-parser-result 'finished off 0 off #f))
          ((stop)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'stopped)
           (make-parser-result 'stopped off 0 off #f))
          ((error)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'error)
           (make-parser-result 'error off 0 off (op 'error-value node)))
          ((dispatch)
           (let ((t (op 'eof-target node)))
             (if t
                 (begin (parser-set-current! parser t) (loop t))
                 (begin (parser-set-lifecycle! parser 'error)
                        (make-parser-result 'error off 0 off (op 'default-eof-value))))))
          (else (assertion-violation 'parser-finish! "unknown node kind" (op 'kind node)))))))

  ;; Full reset (§12.5), M2 subset: entry state, offset 0, lifecycle ready. Field,
  ;; span, pause, finish, poison, and stored-error state do not exist yet (Slice
  ;; ②b / M4 / M5). Returns unspecified.
  (define (parser-reset! parser)
    (parser-set-current! parser (parser-entry parser))
    (parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready)))
