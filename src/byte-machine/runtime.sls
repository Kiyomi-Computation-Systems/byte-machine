;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile (parent §7.2). Two executor variants share this one parser API and
;;; the one parser-result contract: the reference interpreter builds an `op`
;;; message closure over the source IR; generated code (Phase 3, decision 0010)
;;; is a direct resumable executor constructed through the one unversioned
;;; byte-machine-make-compiled-machine (decision 0018; /v1 and /v2 survive only
;;; as tombstones that refuse every version). The two are deliberately different
;;; implementations, which is what lets the interpreter≡generated differential
;;; catch lowering defects (parent §18, §22.4).
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
          byte-machine-make-compiled-machine
          byte-machine-make-compiled-machine/v1 byte-machine-make-compiled-machine/v2
          byte-machine-make-feed-outcome/v1
          make-parser parser?
          parser-feed! parser-finish! parser-resume! parser-lifecycle parser-reset!
          parser-result? parser-result-status parser-result-next
          parser-result-consumed parser-result-stream-offset parser-result-error
          byte-machine-make-parser-error/v1 parser-error?
          parser-error-domain parser-error-code parser-error-reason
          parser-error-detail parser-error-node-name parser-error-state-id
          parser-error-offset parser-error-position-kind
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

  ;; --- compiled machine: two variants behind one type ---
  ;; op:  (vector tag 'op op-closure)                    -- the reference interpreter
  ;; v2:  (vector tag 'v2 exec entry-state fingerprint)  -- generated code, one
  ;;      unified `exec` closure carrying a finish? flag. Built by the ONE
  ;;      unversioned constructor below; the variant tag outlived the /vN name
  ;;      (decision 0018) and is now an internal shape label, not an ABI version.
  ;; The 'v1 feed-only variant is gone (Milestone 4 Slice ①a): once /v1 refuses
  ;; every version nothing can construct one, and an arm no public API can reach
  ;; cannot be witnessed -- it would ship dead owing an EXPECT_SURVIVES.
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag 'op op))
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-variant cm) (vector-ref cm 1))

  ;; The ABI version the emitter emits. Bumped to 3 by Milestone 4 Slice ①a,
  ;; which retired the versioned constructor NAME and kept the version CHECK
  ;; (decision 0018). The check stays load-bearing for a reason specific to this
  ;; project: Chez prefers a compiled object over source and staleness is
  ;; transitive across imports, so a stale object of a generated library really
  ;; can meet a newer runtime inside this repository's own build.
  (define current-abi-version 3)

  ;; The one unversioned constructor. Its FIRST action is the version check, so a
  ;; mismatch is reported before any part of the payload is interpreted -- which
  ;; is what makes the payload safe to grow. `metadata` is one quoted vector
  ;; rather than a rest-arg: a rest-arg would let the payload grow WITHOUT a
  ;; version bump, and the version check is the only thing standing between a
  ;; stale object and silent wrong answers, so the vector keeps growth and the
  ;; check coupled. Member 0 is the field-initials vector, empty until Slice ①b
  ;; fills it, so a zero-field machine renders identically across ①a, ①b, ② and ③.
  (define (byte-machine-make-compiled-machine abi-version ir-fingerprint entry-state exec metadata)
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))
    (unless (and (vector? metadata) (>= (vector-length metadata) 1))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "metadata must be a vector with at least one member" metadata))
    (vector compiled-machine-tag 'v2 exec entry-state ir-fingerprint))

  ;; Tombstones. /v1 and /v2 stay exported so a stale generated file fails with a
  ;; clean ABI-mismatch assertion instead of an unbound-identifier import error,
  ;; and both now refuse EVERY version rather than the one they are named for --
  ;; a tombstone that still accepts a number is a hole, and after the bump to 3
  ;; /v2's old literal-2 guard would have accepted exactly the stale files it was
  ;; added to refuse. The three guards are written in three textually distinct
  ;; forms on purpose: every mutation runs at the default SITES of 1, asserted
  ;; exactly, so two identical guard lines would take one FIND from one site to
  ;; two and fail the suite at declaration.
  (define (byte-machine-make-compiled-machine/v1 abi-version . rest)
    (assertion-violation 'byte-machine-make-compiled-machine/v1
                         "retired generated-runtime ABI" abi-version))
  (define (byte-machine-make-compiled-machine/v2 abi-version . ignored)
    (assertion-violation 'byte-machine-make-compiled-machine/v2
                         "retired generated-runtime ABI" abi-version))
  (define (compiled-machine-v2-exec cm) (vector-ref cm 2))
  (define (compiled-machine-v2-entry-state cm) (vector-ref cm 3))
  (define empty-bv (make-bytevector 0))
  ;; Emitted `exec`'s seventh parameter, reserved empty by decision 0019 item
  ;; 3(c). It is dead weight in this slice and in ①b, and it is the whole reason
  ;; Slice ②'s field store moves no golden: adding the parameter LATER would
  ;; change the emitted text of every machine, including the zero-field ones.
  (define empty-fields (vector))

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

  ;; --- parser error (§9.3:397-405; decision 0022) ---
  ;; Eight members in §9.3:398-405's order, opaque per §9.3:425. The whole family
  ;; ships at once: milestone-2-design.md:343-344 forbids populating one field of
  ;; an otherwise-deferred accessor family, which is why this is not two members
  ;; now and six later. Nothing constructs one until both executors do, in the
  ;; same commit -- the lanes compare by value, so a split leaves the differential
  ;; red in between.
  (define parser-error-tag (tag 'byte-machine-parser-error))
  ;; The reserved constructor generated code calls takes FIVE arguments, not
  ;; eight (decision 0022 item 1): an errs-table entry packing this
  ;; declaration's code and reason, the public source-node name, the state id,
  ;; the absolute offset, and the position kind. `domain` and `detail` are fixed
  ;; here rather than passed, so no emitted site ever writes them -- `machine`
  ;; because §12.7 calls these machine errors, and #f because §9.3:401 annotates
  ;; detail "#f for machine errors". Their other enumerated values have exactly
  ;; one producer in the plan, §13:808's callback failure, which is Milestone 5.
  (define (byte-machine-make-parser-error/v1 entry node-name state-id offset position-kind)
    (vector parser-error-tag 'machine (vector-ref entry 0) (vector-ref entry 1) #f
            node-name state-id offset position-kind))
  (define (parser-error? x) (tagged? parser-error-tag x))
  ;; The interpreter's executor hands back (code reason node-name state-id); the
  ;; loop supplies the offset and the position kind, which only it knows. Both
  ;; lanes therefore build the same record from the same parts -- the generated
  ;; one through byte-machine-make-parser-error/v1 at each emitted site, this one
  ;; here.
  (define (parts->parser-error parts off kind)
    (byte-machine-make-parser-error/v1
     (vector (car parts) (cadr parts)) (caddr parts) (cadddr parts) off kind))
  (define (parser-error-domain e) (vector-ref e 1))
  (define (parser-error-code e) (vector-ref e 2))
  (define (parser-error-reason e) (vector-ref e 3))
  (define (parser-error-detail e) (vector-ref e 4))
  (define (parser-error-node-name e) (vector-ref e 5))
  (define (parser-error-state-id e) (vector-ref e 6))
  (define (parser-error-offset e) (vector-ref e 7))
  (define (parser-error-position-kind e) (vector-ref e 8))

  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor entry current offset lifecycle stored-error)
  ;; lifecycle: ready | paused-feed | paused-finish | finish-ready | stopped |
  ;; error | finished (§12.1; poisoned/busy are M5 rows). Sticky rows
  ;; short-circuit at the operation entry and synthesize the §12.2 tuple
  ;; (next = the new call's start for feed, the stream offset for finish;
  ;; consumed = 0; stored offset/error) without re-running the executor: ②a's
  ;; idempotent re-execution broke on default-EOF truncation, which parks
  ;; `current` on a dispatch node (②b-2 final review).
  ;; stored-error (slot 7) is the error value the error row returns; #f
  ;; otherwise. M5's full stored-result short-circuit (callbacks) stays deferred.
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (cond
      ((eq? (compiled-machine-variant compiled-machine) 'op)
       (let* ((op (vector-ref compiled-machine 2)) (entry (op 'entry)))
         (vector parser-tag 'op op entry entry 0 'ready #f)))
      ((eq? (compiled-machine-variant compiled-machine) 'v2)
       (let ((exec (compiled-machine-v2-exec compiled-machine))
             (entry-state (compiled-machine-v2-entry-state compiled-machine)))
         (vector parser-tag 'v2 exec entry-state entry-state 0 'ready #f)))
      ;; Unreachable through the public API: the only two constructors build 'op
      ;; and 'v2. Kept LOUD rather than deleted, the same convention as
      ;; compile.sls's and normal-ir.sls's own unreachable else arms.
      (else (assertion-violation 'make-parser "unknown compiled-machine variant"
                                 (compiled-machine-variant compiled-machine)))))
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
  (define (parser-stored-error p) (vector-ref p 7))
  (define (parser-set-stored-error! p v) (vector-set! p 7 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    ;; The three sticky arms below, and parser-finish!'s below, are
    ;; deliberately not factored into a shared helper even though each pair
    ;; is near-identical: Pass 32 anchors a mutation on each arm's own text,
    ;; and a shared helper would collapse several distinct decisions onto one
    ;; FIND site, silently dropping their independent witnesses.
    (case (parser-lifecycle parser)
      ((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation
                                        (list (parser-lifecycle parser) 'feed)))
      ((stopped) (make-parser-result 'stopped start 0 (parser-offset parser) #f))
      ((error) (make-parser-result 'error start 0 (parser-offset parser)
                                   (parser-stored-error parser)))
      ((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))
      (else
       (let ((r (case (parser-variant parser)
                  ((op) (parser-feed-op! parser bv start end))
                  ((v2) (parser-feed-v2! parser bv start end))
                  (else (assertion-violation 'parser-feed! "unknown parser variant"
                                             (parser-variant parser))))))
         (case (parser-result-status r)
           ((stopped) (parser-set-lifecycle! parser 'stopped))
           ((error) (parser-set-lifecycle! parser 'error)
                    (parser-set-stored-error! parser (parser-result-error r)))
           ((finished) (parser-set-lifecycle! parser 'finished))
           ((paused) (parser-set-lifecycle! parser 'paused-feed)))
         r))))

  ;; The interpreter path. Sticky rows short-circuit one level up in
  ;; parser-feed! (D1), so this loop no longer serves repeat feeds on a
  ;; terminal parser -- it is reached only while the lifecycle is 'ready, and
  ;; runs a single live dispatch walk from `current` to its next stop/error/
  ;; finish/pause.
  (define (parser-feed-op! parser bv start end)
    (let ((op (parser-executor parser)))
      ;; The position kind is a loop variable, set from a literal at each jump
      ;; (decision 0022 item 5), initialized `boundary` unconditionally with no
      ;; finish? key: nothing has been consumed since the call began, so an error
      ;; state reached with no jump taken is a boundary at the current offset.
      (let loop ((pos start) (pk 'boundary))
        (let ((node (parser-current parser)))
          (case (op 'kind node)
            ((stop)
             (make-parser-result 'stopped pos (- pos start) (parser-offset parser) #f))
            ((error)
             (make-parser-result 'error pos (- pos start) (parser-offset parser)
                                 (parts->parser-error (op 'error-value node)
                                                      (parser-offset parser) pk)))
            ((finish)
             (make-parser-result 'finished pos (- pos start) (parser-offset parser) #f))
            ((pause)
             ;; D3: commit current PAST the pause -- the resumed feed re-enters
             ;; at the continuation, mirroring the generated next-state.
             (parser-set-current! parser (op 'pause-target node))
             (make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))
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
                         (loop (+ pos 1) 'boundary))
                       (loop pos 'byte)))))
            (else (assertion-violation 'parser-feed! "unknown node kind" (op 'kind node))))))))

  ;; The generated /v2 path: exec owns the dispatch loop; finish? = #f for feed.
  (define (parser-feed-v2! parser bv start end)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) bv start end #f empty-fields)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (make-parser-result (feed-outcome-status o) (feed-outcome-next o)
                          (- (feed-outcome-next o) start)
                          (feed-outcome-offset o) (feed-outcome-error o))))

  ;; parser-finish! (§12.4): the paused rows are a prohibited cell (§12.2) and
  ;; the sticky rows (stopped/error/finished) short-circuit here without
  ;; running anything (D1); otherwise (ready | finish-ready) it runs the
  ;; executor with input exhausted. From the current state, an exhausted
  ;; dispatch takes its eof-target (a named node, else the machine
  ;; default-eof-error); execution continues to a finish node (-> finished), a
  ;; pause node (-> paused, §12.1), an error node (-> error), or a stop node
  ;; reached this way is verifier-rejected so it never occurs. No slice, so
  ;; next/consumed mirror the stream offset / 0. The generated finish path runs
  ;; the same `exec` with finish? #t; the else arm is unreachable through the
  ;; public API now that only 'op and 'v2 can be constructed, and stays an
  ;; assertion violation for that reason rather than for v1's.
  (define (parser-finish! parser)
    ;; Sticky arms deliberately not shared with parser-feed!'s -- see the
    ;; comment there.
    (case (parser-lifecycle parser)
      ((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation
                                        (list (parser-lifecycle parser) 'finish)))
      ((stopped) (make-parser-result 'stopped (parser-offset parser) 0
                                     (parser-offset parser) #f))
      ((error) (make-parser-result 'error (parser-offset parser) 0
                                   (parser-offset parser) (parser-stored-error parser)))
      ((finished) (make-parser-result 'finished (parser-offset parser) 0
                                      (parser-offset parser) #f))
      (else                             ; ready | finish-ready
       (case (parser-variant parser)
         ((op) (parser-finish-op! parser))
         ((v2) (parser-finish-v2! parser))
         ;; Unreachable for the same reason as make-parser's else above.
         (else (assertion-violation 'parser-finish! "unknown parser variant"
                                    (parser-variant parser)))))))

  ;; The generated /v2 finish path: run exec over the empty slice with finish? #t.
  ;; exec owns the eof-target chain internally (Task 2 lowers it); the runtime just
  ;; commits resume state, records the terminal lifecycle, and snapshots the result
  ;; (no slice, so next/consumed mirror the stream offset / 0).
  (define (parser-finish-v2! parser)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t empty-fields)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (case (feed-outcome-status o)
        ((finished) (parser-set-lifecycle! parser 'finished))
        ((error) (parser-set-lifecycle! parser 'error)
                 (parser-set-stored-error! parser (feed-outcome-error o)))
        ((stopped) (parser-set-lifecycle! parser 'stopped))
        ((paused) (parser-set-lifecycle! parser 'paused-finish)))
      (make-parser-result (feed-outcome-status o) (feed-outcome-offset o) 0
                          (feed-outcome-offset o) (feed-outcome-error o))))

  (define (parser-finish-op! parser)
    ;; No local cycle guard: termination relies on the verifier's
    ;; eof-zero-progress-cycle/eof-reachable-stop checks having already rejected
    ;; non-terminating and stop-terminating EOF chains, so this loop terminates
    ;; only for verified machines -- the same reliance the generated /v2 finish
    ;; path (parser-finish-v2!, Slice ②b-2) has, since it does not re-verify at
    ;; runtime either.
    (let ((op (parser-executor parser))
          (off (parser-offset parser)))
      ;; The same loop variable as parser-feed-op!, and for the same reason: an
      ;; error node a prior feed parked on is reached here by NO jump, and
      ;; nothing is truncated by a finish! call that merely observes it, so it
      ;; reports the boundary a feed resuming onto it already reports. `eof` is
      ;; reserved for where truncation actually occurs or is inherited along the
      ;; EOF-target chain -- the hop below, and the default-EOF terminal, which
      ;; is reached by no jump at all once the chain is exhausted and so takes
      ;; its own constant.
      (let loop ((node (parser-current parser)) (pk 'boundary))
        (case (op 'kind node)
          ((finish)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'finished)
           (make-parser-result 'finished off 0 off #f))
          ((pause)
           (parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f))
          ((stop)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'stopped)
           (make-parser-result 'stopped off 0 off #f))
          ((error)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'error)
           (let ((e (parts->parser-error (op 'error-value node) off pk)))
             (parser-set-stored-error! parser e)
             (make-parser-result 'error off 0 off e)))
          ((dispatch)
           (let ((t (op 'eof-target node)))
             (if t
                 (begin (parser-set-current! parser t) (loop t 'eof))
                 (begin (parser-set-lifecycle! parser 'error)
                        (let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                          (parser-set-stored-error! parser e)
                          (make-parser-result 'error off 0 off e))))))
          (else (assertion-violation 'parser-finish! "unknown node kind" (op 'kind node)))))))

  ;; §12.1: resume changes lifecycle only -- no callback, no input, no executor
  ;; run. paused-feed -> ready ('feed-ready ack); paused-finish -> finish-ready
  ;; ('finish-ready ack, which is also the state awaiting the next finish!).
  ;; Every other row of §12.2's resume! column is a prohibited cell.
  (define (parser-resume! parser)
    (case (parser-lifecycle parser)
      ((paused-feed) (parser-set-lifecycle! parser 'ready) 'feed-ready)
      ((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'finish-ready)
      (else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))))

  ;; Full reset (§12.5), M2 subset: entry state, offset 0, lifecycle ready, and
  ;; the stored error cleared. `current := entry` is also what clears the pause
  ;; continuation under this representation -- D3 parks it on `current` with no
  ;; separate saved-continuation field, so restoring `current` restores both.
  ;; Field, span, and poisoned/busy state do not exist yet (M4/M5). Returns
  ;; unspecified.
  (define (parser-reset! parser)
    (parser-set-current! parser (parser-entry parser))
    (parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready)
    (parser-set-stored-error! parser #f)))
