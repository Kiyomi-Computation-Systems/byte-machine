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
          parser-field-ref
          callback-continue callback-pause
          ;; Milestone 5 Slice ①b. `parser-state-name` was NOT here: it must name
          ;; a source node (§13:820) and the generated lane held an integer state
          ;; id with no id->name table, so shipping it would have answered in one
          ;; lane and not the other. Deferred whole to Slice ② by the owner,
          ;; 2026-09-04 -- and ② carries the table, as ABI payload member 2.
          parser-stream-offset parser-user-context parser-active-span
          ;; Milestone 5 Slice ②: the sixth accessor decision 0028 item 1 is
          ;; written for, and the one ①b could not build.
          parser-state-name
          make-callback-failure callback-failure?
          callback-failure-code callback-failure-detail
          ;; Milestone 5 Slice ②. Both are called from EMITTED code, which is
          ;; why they carry the /v1 seam suffix and why they are exported at all
          ;; -- the generated library imports (byte-machine runtime) and nothing
          ;; else (decision 0025).
          byte-machine-callback-step/v1 byte-machine-make-callback-error/v1
          ;; Milestone 5 Slice ③. THREE names, and the count is stated because
          ;; the first version of this comment said "these four" over a list of
          ;; three. They are the span machinery both lanes call, and every one is
          ;; called from EMITTED code -- which is what puts them in
          ;; `reserved-member-2`. `parser-active-span` shipped in ①b and is NOT
          ;; one of them: no emitted text names it.
          byte-machine-span-open/v1 byte-machine-span-fragment-step/v1
          byte-machine-span-close/v1)
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
  ;; v2:  (vector tag 'v2 exec entry-state fingerprint fields) -- generated code, one
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
  ;;
  ;; Bumped to 4 by Milestone 5 Slice ①a (decision 0025 point 2), which grew the
  ;; ABI payload with a second member -- empty here, filled by ①b. §9.5:444 is
  ;; what forces the bump; the strict equality below is what enforces it. The
  ;; `>= 1` metadata check further down is a LENGTH minimum and enforces nothing
  ;; about the version: a two-member payload satisfies it unchanged, which is
  ;; the freedom the quoted vector was chosen for.
  ;;
  ;; Bumped to 5 by Milestone 5 Slice ② (§9.5:444), which grew the payload with
  ;; member 2: §17:963's state-id to source-name table. That table is what makes
  ;; `parser-state-name` answerable in the generated lane at all -- Slice ①b
  ;; deferred the accessor whole rather than ship it answering in one lane -- and
  ;; there is no third transport to put it on: the emitted library exports one
  ;; name and the constructor's five arguments are the only channel.
  (define current-abi-version 5)
  ;; How many payload members ABI 5 defines: field declarations, the callback
  ;; declaration table, and the state-id to source-name table. Named beside the
  ;; version because the two move together -- §9.5:444 makes growing the payload
  ;; a version bump -- and read by the single length guard below.
  (define current-abi-members 3)
  ;; ABI payload member 1, Milestone 5 Slice ①b: the callback declaration table
  ;; the generated lane resolves bindings against. `#()` for a machine declaring
  ;; none, which is every committed golden.
  (define (compiled-machine-v2-callbacks cm) (vector-ref cm 6))
  ;; ABI payload member 2, Milestone 5 Slice ②: a vector of SOURCE node names
  ;; indexed by state id, total over internal prefix states.
  (define (compiled-machine-v2-state-names cm) (vector-ref cm 7))

  ;; The one unversioned constructor. Its FIRST action is the version check, so a
  ;; mismatch is reported before any part of the payload is interpreted -- which
  ;; is what makes the payload safe to grow. `metadata` is one quoted vector
  ;; rather than a rest-arg: a rest-arg would let the payload grow WITHOUT a
  ;; version bump, and the version check is the only thing standing between a
  ;; stale object and silent wrong answers, so the vector keeps growth and the
  ;; check coupled. Member 0 is the field declarations, `#()` for a machine that
  ;; declares none, which is why a zero-field machine renders identically across
  ;; ①a, ①b, ② and ③.
  ;;
  ;; Slice ①b fills it, as (name . initial) pairs in SLOT ORDER. The member is
  ;; named for the initials and carries the names too because the slot is the
  ;; pair's POSITION: one member determines both the values a fresh parser starts
  ;; from and the name-to-slot resolution parser-field-ref answers by, and a
  ;; second member would be a second ABI growth for data the first already fixes.
  (define (byte-machine-make-compiled-machine abi-version ir-fingerprint entry-state exec metadata)
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))
    ;; *** ONE length guard, and Milestone 5 Slice ② collapsed two into it. ***
    ;; The shipped shape was a chain -- at least one member, then at least two
    ;; at ABI 4 -- on the reading that each should name the member a short
    ;; payload is missing. Adding member 2's guard made the defect visible: a
    ;; later minimum SUBSUMES every earlier one, so the earlier guard's removal
    ;; changes nothing any input can observe, and its mutation went UNCAUGHT the
    ;; moment the third guard landed. Only the LAST guard in such a chain is
    ;; discriminating; the rest are prose with a raise attached.
    ;;
    ;; `vector?` is NOT subsumed and stays in the same guard: it must be refused
    ;; before `vector-length` is applied at all.
    (unless (and (vector? metadata)
                 (>= (vector-length metadata) current-abi-members))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "metadata must carry every member this ABI defines"
                           metadata))
    (vector compiled-machine-tag 'v2 exec entry-state ir-fingerprint
            (vector-ref metadata 0) (vector-ref metadata 1)
            (vector-ref metadata 2)))

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
    ;; Deliberately worded differently from /v1's body above, not only named
    ;; differently: every mutation runs at the default SITES of 1, asserted
    ;; exactly, so a FIND anchored on a shared line would report two sites and
    ;; fail the suite at declaration. Distinctness has to hold for the whole
    ;; body, which is what the first version of these two tombstones missed.
    (assertion-violation 'byte-machine-make-compiled-machine/v2
                         "retired generated-runtime ABI (superseded by the unversioned constructor)"
                         abi-version))
  (define (compiled-machine-v2-exec cm) (vector-ref cm 2))
  (define (compiled-machine-v2-entry-state cm) (vector-ref cm 3))
  (define (compiled-machine-v2-fields cm) (vector-ref cm 5))
  (define empty-bv (make-bytevector 0))
  ;; Emitted `exec`'s seventh parameter, reserved empty by decision 0019 item
  ;; 3(c). It is dead weight in this slice and in ①b, and it is the whole reason
  ;; Slice ②'s field store moves no golden: adding the parameter LATER would
  ;; change the emitted text of every machine, including the zero-field ones.
  ;; *** ITS STATED REASON FOR EXISTING IS FALSE, and Milestone 5 Slice ①a's
  ;; final review measured it. *** The line here read "Retained for the mutation
  ;; that pins the seventh parameter's presence ... Deleting it would take that
  ;; pin with it." No mutation references this binding: searched the whole tree,
  ;; and the only `empty-fields` outside this file's own comments is prose in
  ;; `milestone-4-slice-2-implementation-plan.md`. Slice ② gave both call sites
  ;; the parser's own vector and re-anchored that pin onto
  ;; `(parser-field-values parser)` in the same commit, which is what actually
  ;; retired this binding.
  ;;
  ;; Kept rather than deleted, because deleting it is not a seam slice's work and
  ;; the milestone's boundary is stated. What is corrected is the REASON: it is
  ;; dead weight with no pin depending on it, and the slice that next touches
  ;; this region should remove it.
  ;; *** BOTH SENTINELS ARE GONE (Milestone 5 Slice ②). *** The paragraph above
  ;; said the slice that next touches this region should remove `empty-fields`,
  ;; and the `empty-callbacks` note below it said the slice that gives the
  ;; callback vector contents owns replacing the sentinel. This is that slice
  ;; for both: `parser-feed-v2!` and `parser-finish-v2!` now pass the parser's
  ;; own field vector and its own callback slot vector, and nothing else in the
  ;; CODE named either binding -- measured; two mutation-suite comments mention
  ;; them by name, and the suite's one FIND on the `empty-callbacks` call site
  ;; moved with it.

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
  ;; *** IF YOU ARE CHANGING THIS RECORD'S SHAPE, YOU HAVE INHERITED AN
  ;; OBLIGATION. *** `§9.3:392-393` annotates `parser-result-next` and
  ;; `parser-result-consumed` "feed-originated results only", and nothing
  ;; enforces that: `parser-finish!`'s paths call this constructor with `next`
  ;; repeating the absolute stream offset and `consumed` exactly 0. The record is
  ;; opaque (`§9.3:425`), so an internal origin slot would not be a public
  ;; change -- the reason this was deferred is COST, RE-MEASURED here 2026-09-05
  ;; rather than copied: `rg -l parser-result-next test/ --glob '*.sps'` returns
  ;; **17** programs and `rg -o '\(parser-finish!' test/common/` returns **73**
  ;; call sites across **16** files. (The parent plan's own paragraph says
  ;; "sixteen programs" and "83 sites"; neither number is reproducible against
  ;; the tree, at this commit or at the one that wrote them. The conclusion --
  ;; enforcing this re-baselines a tuple in most of the differential programs --
  ;; is unaffected, and is why it was deferred.)
  ;;
  ;; Milestone 5's close-out (Slice ④, 2026-09-05) disposed it as DEFERRED with
  ;; the receiver named as "the next slice that changes this record's shape".
  ;; The adjudication is in `docs/plans/byte-machine-implementation-plan.md`
  ;; under the `### §12.3:711` disposition -- NOT under §12.7, which is the
  ;; other close-out obligation. The note is here rather than only there because
  ;; that receiver opens this constructor.
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
  ;; --- the callback domain (decision 0024, Milestone 5 Slice ②) -------------
  ;; The two producers 0024 item 4 names: §13:808's explicit callback failure,
  ;; whose code and detail are the APPLICATION's and pass through, and a return
  ;; outside the declared outcomes, for which the runtime mints the code below
  ;; and whose detail is #f -- no make-callback-failure call happened on that
  ;; path, so nothing was application-provided (§12.7:757 calls the member
  ;; "optional callback-provided detail").
  ;;
  ;; `domain` is fixed HERE, exactly as `machine` is fixed in the constructor
  ;; above, and for the reason 0024's Consequences give: no emitted site and no
  ;; interpreter site writes it, so the two lanes cannot disagree by
  ;; construction -- and a differential that only compared domain would pass
  ;; vacuously. The teeth are on code, node name, offset and position kind.
  ;;
  ;; The REASON is one fixed printable-ASCII constant (0024 item 5), identical
  ;; in both lanes. It is not derived from the code: on one of the two paths the
  ;; code is the application's, so a derived reason would stop being static in
  ;; §12.7:757's sense and would put a symbol's external representation into a
  ;; behavioural contract.
  (define callback-error-reason "callback failure")
  (define callback-contract-code 'callback-contract-violation)
  ;; *** §12.7:770's ROW, AS A CONSTANT, and it was a variable until Slice ③'s
  ;; census reconciliation. *** "Zero-width machine action or callback failure |
  ;; `boundary` at the current stream offset." Every site building a
  ;; callback-domain error passed the loop's `pk` instead, and Slice ②'s own
  ;; comment claimed that carrying `pk` through "is the rule the carried-through
  ;; `pk` already implements" -- true only when the invoking node happened to be
  ;; reached by an ADVANCE edge. Reached over a REEXECUTE edge, `pk` is `byte`,
  ;; and the two lanes then AGREED on the wrong value, which is why no
  ;; differential could see it: measured through a span end on a reexecute edge,
  ;; both lanes reported `byte`.
  ;;
  ;; §12.7:773's "Error nodes reached through other byte edges retain the
  ;; author's explicit advance/reexecute choice" does not reach here: a callback
  ;; failure is not an error node, it has no author-chosen edge, and §12.7's
  ;; table is total over error sources with exactly one row for this one.
  ;;
  ;; A NAME rather than a bare quoted symbol at six sites: this is one decision,
  ;; and six literals are six chances for a later slice to change five of them.
  (define callback-failure-position 'boundary)

  (define (byte-machine-make-callback-error/v1 code detail node-name state-id
                                               offset position-kind)
    (vector parser-error-tag 'callback code callback-error-reason detail
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
  ;; (vector tag variant executor entry current offset lifecycle stored-error
  ;;         field-values field-decls)
  ;; lifecycle: ready | paused-feed | paused-finish | finish-ready | stopped |
  ;; error | finished (§12.1; poisoned/busy are M5 rows). Sticky rows
  ;; short-circuit at the operation entry and synthesize the §12.2 tuple
  ;; (next = the new call's start for feed, the stream offset for finish;
  ;; consumed = 0; stored offset/error) without re-running the executor: ②a's
  ;; idempotent re-execution broke on default-EOF truncation, which parks
  ;; `current` on a dispatch node (②b-2 final review).
  ;; stored-error (slot 7) is the error value the error row returns; #f
  ;; otherwise. M5's full stored-result short-circuit (callbacks) stays deferred.
  ;;
  ;; field-values (slot 8, Milestone 4 Slice ①b) is a MUTABLE vector of exact
  ;; integers indexed by slot; field-decls (slot 9) is the IMMUTABLE (name .
  ;; initial) vector the compiled machine carries, in slot order. Two slots
  ;; rather than one pair: they have different lifetimes and different owners --
  ;; the decls are per compiled machine and never written, the values per parser
  ;; and written constantly -- and parser-reset! must restore exactly one of them
  ;; FROM the other.
  ;;
  ;; The storage cannot live in the shared op/exec closure. That closure is built
  ;; once per compiled machine and every parser from it copies the same reference
  ;; into slot 2, and the tree already builds many parsers per compiled machine
  ;; inside per-byte loops (byte-class-interpret-tests.sps,
  ;; differential-one-byte-tests.sps, determinism-http-version-tests.sps), so
  ;; closure-held storage would let one parser's writes be read by another. Slot
  ;; 9 is where the initials RIDE, because once a parser is built it holds a
  ;; reference to nothing else.
  (define parser-tag (tag 'byte-machine-parser))
  ;; --- callback binding resolution (§9.3:419, decision 0028) ----------------
  ;; "Callbacks are resolved once into indexed slots when the parser is
  ;; constructed. Generated hot paths never perform symbolic or alist lookup"
  ;; (§10.3:508). The slot vector is built HERE, once, and indexed thereafter.
  ;;
  ;; An UNBOUND OPTIONAL callback's slot holds `unbound-callback`, a sentinel the
  ;; invocation site short-circuits -- decision 0028, taken on cost rather than on
  ;; observability, because no witness distinguishes it from an installed closure
  ;; (an unbound callback has no application closure to record with). Nothing
  ;; invokes anything in this slice; what ships is the table and its resolution.
  (define unbound-callback (vector 'byte-machine-unbound-callback))
  (define (unbound-callback? x) (eq? x unbound-callback))

  ;; §9.3:419, verbatim: "`callback-bindings` is a proper list of two-element
  ;; lists `(name procedure)`." TWO-ELEMENT LISTS, not pairs -- the first version
  ;; of this resolver took `(name . procedure)` and the slice's final review
  ;; caught it against the sentence. `(cadr b)` is the procedure.
  (define (binding-for bindings nm)
    (let bloop ((bs bindings))
      (cond ((null? bs) #f)
            ((eq? (car (car bs)) nm) (car bs))
            (else (bloop (cdr bs))))))

  ;; Each decl is #(name kind required? default-branch) in slot order -- the op
  ;; lane answers it, the generated lane carries it in ABI payload member 1, and
  ;; the two shapes are identical on purpose so this resolver is lane-blind.
  (define (resolve-callbacks decls bindings)
    (unless (list? bindings)
      (byte-machine-contract-violation 'make-parser 'invalid-argument 'callback-bindings))
    ;; §9.3:419's duplicate-binding rejection, before any resolution: a name bound
    ;; twice is a caller error whichever slot would have won.
    (let dloop ((bs bindings) (seen '()))
      (unless (null? bs)
        (let ((b (car bs)))
          (unless (and (list? b) (= (length b) 2)
                       (symbol? (car b)) (procedure? (cadr b)))
            (byte-machine-contract-violation 'make-parser 'invalid-argument
                                             'callback-bindings))
          (when (memq (car b) seen)
            (byte-machine-contract-violation 'make-parser 'invalid-argument
                                             'duplicate-callback-binding))
          (dloop (cdr bs) (cons (car b) seen)))))
    ;; And a binding naming no declaration: silently ignoring it would let a
    ;; typo disable a callback the machine requires.
    (for-each (lambda (b)
                (let ((nm (car b)))
                  (let sloop ((i 0))
                    (cond ((>= i (vector-length decls))
                           (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                            'unknown-callback-binding))
                          ((eq? (vector-ref (vector-ref decls i) 0) nm) #t)
                          (else (sloop (+ i 1)))))))
              bindings)
    (let ((slots (make-vector (vector-length decls) unbound-callback)))
      (let rloop ((i 0))
        (if (>= i (vector-length decls)) slots
            (let* ((d (vector-ref decls i))
                   (nm (vector-ref d 0))
                   (required? (vector-ref d 2))
                   (b (binding-for bindings nm)))
              (cond (b (vector-set! slots i (cadr b)))
                    (required?
                     (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                      'missing-required-callback))
                    (else #t))
              (rloop (+ i 1)))))))

  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (cond
      ;; The two arms reach the declarations by the SHIPPED per-lane asymmetry
      ;; rather than a uniform mechanism: the interpreter holds the verified
      ;; source machine and is asked, the generated lane holds only what the ABI
      ;; payload carried and reads member 0. There is nothing both could consult.
      ((eq? (compiled-machine-variant compiled-machine) 'op)
       (let* ((op (vector-ref compiled-machine 2)) (entry (op 'entry))
              (decls (op 'field-initials)))
         (vector parser-tag 'op op entry entry 0 'ready #f
                 (initial-values decls) decls
                 (resolve-callbacks (op 'callback-decls) callback-bindings)
                 user-context #f #f 0 #f)))
      ((eq? (compiled-machine-variant compiled-machine) 'v2)
       (let ((exec (compiled-machine-v2-exec compiled-machine))
             (entry-state (compiled-machine-v2-entry-state compiled-machine))
             (decls (compiled-machine-v2-fields compiled-machine)))
         (vector parser-tag 'v2 exec entry-state entry-state 0 'ready #f
                 (initial-values decls) decls
                 (resolve-callbacks (compiled-machine-v2-callbacks compiled-machine)
                                    callback-bindings)
                 user-context #f
                 (compiled-machine-v2-state-names compiled-machine) 0 #f)))
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
  (define (parser-field-values p) (vector-ref p 8))
  (define (parser-field-decls p) (vector-ref p 9))
  ;; Milestone 5 Slice ①b: slots 10-12. The callback slot vector (§9.3:419), the
  ;; application's opaque context (§13:801 -- application-owned and may be
  ;; mutable, so the runtime neither copies nor interprets it), and the active
  ;; span's name or #f. `parser-active-span` answers in BOTH lanes because a span
  ;; is bookkeeping the runtime owns (§10.2:495), not a generated state -- which
  ;; is why `parser-state-name` was NOT here: it must name a source node, and the
  ;; generated lane held an integer state id with no id->name table. Slice ②
  ;; carries that table across the seam and slot 13 below holds it.
  (define (parser-callbacks p) (vector-ref p 10))
  (define (parser-user-context p) (vector-ref p 11))
  (define (parser-active-span p) (vector-ref p 12))
  ;; Slot 13, Milestone 5 Slice ②: ABI payload member 2's state-id to
  ;; source-name vector, or #f in the interpreted lane, which is ASKED instead.
  ;; The same per-lane asymmetry the field table and the callback declarations
  ;; established -- the interpreter holds the verified source machine, the
  ;; generated lane holds only what the payload carried.
  (define (parser-state-names p) (vector-ref p 13))
  ;; Milestone 5 Slice ③: slots 14 and 15, beside ①b's slot 12. The three are one
  ;; piece of state and are named apart because they have different lifetimes --
  ;; the NAME is what `parser-active-span` answers and what §14:843 quantifies
  ;; over, the MARK is a slice offset re-anchored every feed (§14:833), and the
  ;; SLOT is what the boundary flush needs to reach the data callback without
  ;; consulting the machine, which it cannot do: the flush runs in `parser-feed!`
  ;; and the two lanes reach their declarations by different routes.
  (define (parser-span-mark p) (vector-ref p 14))
  (define (parser-set-span-mark! p v) (vector-set! p 14 v))
  (define (parser-span-data-slot p) (vector-ref p 15))
  (define (parser-set-span-data-slot! p v) (vector-set! p 15 v))
  (define (parser-set-active-span! p v) (vector-set! p 12 v))
  ;; §9.3:409. The absolute offset, which the parser already tracks; this is the
  ;; public name for it, and §13:819 makes it one of the values committed before
  ;; a callback sees the parser.
  (define (parser-stream-offset p) (parser-offset p))
  ;; §9.3:408, and the accessor Slice ①b deferred whole rather than ship
  ;; answering in one lane. §13:820 requires the SOURCE node name, "not a
  ;; generated internal continuation", so the generated lane reads member 2's
  ;; table -- which is total over internal prefix states, each answering with its
  ;; declaring node's public name.
  ;;
  ;; A bare symbol, always: decision 0028 item 2 rejected widening this to a
  ;; compound for the feed-boundary case, and the parent plan's dated
  ;; disposition gives the reason -- "no caller can predict which calls return
  ;; the compound". The active span is `parser-active-span`, shipped in ①b.
  (define (parser-state-name parser)
    (unless (parser? parser)
      (byte-machine-contract-violation 'parser-state-name 'invalid-argument parser))
    (case (parser-variant parser)
      ((op) ((parser-executor parser) 'state-name (parser-current parser)))
      ((v2) (vector-ref (parser-state-names parser) (parser-current parser)))
      ;; Unreachable for the same reason make-parser's own else arm is.
      (else (assertion-violation 'parser-state-name "unknown parser variant"
                                 (parser-variant parser)))))

  ;; --- callback failure (§13:808, §9.3:415-416, decision 0024) ---------------
  ;; "an explicit callback failure containing an application code and optional
  ;; detail". §9.3:423 requires the code to satisfy the same portable ASCII name
  ;; grammar as everything else symbolic; the detail is opaque application data
  ;; and is never emitted (§10.1:480's last sentence).
  ;;
  ;; Allocation here is deliberate and licensed: §13:810 makes the SUCCESSFUL
  ;; outcomes allocation-free singletons and says in the same breath that "error
  ;; detail allocation is allowed on the exceptional path".
  (define callback-failure-tag (tag 'byte-machine-callback-failure))
  ;; TYPE ONLY HERE, AND THE GRAMMAR HALF IS ENFORCED NOWHERE. §9.3:423 requires
  ;; the code to satisfy the portable ASCII name grammar; `symbol?` is the house
  ;; constructor-side check and `valid-name?` lives in verify.sls, which this
  ;; library does not import and must not -- the runtime is downstream of
  ;; verification. An application's callback code is not a machine declaration
  ;; and reaches no verifier pass, so nothing in the tree checks the grammar
  ;; half. Recorded rather than silently narrowed: closing it means either
  ;; duplicating the grammar here or routing application codes through a check
  ;; that does not exist, and neither is this slice's to choose.
  (define (make-callback-failure code detail)
    (unless (symbol? code)
      (byte-machine-contract-violation 'make-callback-failure 'invalid-argument 'code))
    (vector callback-failure-tag code detail))
  (define (callback-failure? x) (tagged? callback-failure-tag x))
  (define (callback-failure-code f) (vector-ref f 1))
  (define (callback-failure-detail f) (vector-ref f 2))

  ;; --- the callback seam, shared by both lanes (Slice ②, split in Slice ③) ---
  ;; §13:803-808's outcomes, classified in one place. The emitted arm and
  ;; `parser-feed-op!`'s arm both call this, so neither lane can invent its own
  ;; vocabulary -- which §22.4:1268 compares and decision 0024's Consequences
  ;; require be produced "by both lanes from the same construction". The lanes
  ;; differ only in what a TARGET is (a node name here, a state id there), and
  ;; this procedure never looks inside one.
  ;;
  ;; *** §13:812's two sentences are ONE test, deliberately. *** "Event and span
  ;; callbacks accept only continue, pause, or failure. Decision callbacks may
  ;; additionally return their declared branch keys." An event node declares no
  ;; branch targets at all, and a decision node declares exactly the keys
  ;; §16.2:901's node half admits -- so "does the returned symbol name a
  ;; declared branch of THIS node" answers both, out of data both lanes already
  ;; carry, and no callback KIND has to cross the seam.
  ;;
  ;; The unbound-optional short circuit is decision 0028 item 3's other end:
  ;; ①b installed the sentinel, this reads it, and the closure is NEVER called
  ;; -- which is what keeps 0028's constraint on §18:981's trace true.
  ;;
  ;; Answers one of:
  ;;   (goto TARGET)          -- continue, a declared branch, or the default
  ;;   (pause)                -- park on the node's pause continuation
  ;;   (failure CODE DETAIL)  -- decision 0024's stored callback-domain error
  ;;
  ;; *** THE SPLIT SLICE ③ NEEDED, and only one line of the shipped procedure
  ;; was arity-dependent. *** §13:790 gives a span-data callback five arguments
  ;; where every other kind takes two, so the invocation cannot be shared -- but
  ;; the CLASSIFICATION can, and must: §22.4:1268 compares callback results
  ;; across lanes and decision 0024's Consequences require both codes to be
  ;; produced "by both lanes from the same construction".
  ;;
  ;; A widened rest-arg was rejected: it would put the arity decision inside the
  ;; classifier, where neither lane can see which kind it holds.
  (define (classify-callback-result r branches continue)
    (cond ((eq? r callback-continue) (list 'goto continue))
          ((eq? r callback-pause) (list 'pause))
          ((callback-failure? r)
           (list 'failure (callback-failure-code r) (callback-failure-detail r)))
          ((and (symbol? r) (assq r branches))
           => (lambda (hit) (list 'goto (cdr hit))))
          (else (list 'failure callback-contract-code #f))))

  ;; *** IT COMMITS `current` AND THE OFFSET BEFORE INVOKING, and that is not
  ;; bookkeeping -- it is §13:816-821. *** "At callback entry, the interpreter
  ;; and generated executor expose identical committed parser state": the stream
  ;; offset "includes every byte committed before the callback" (§13:819) and
  ;; the public parser state "names the source callback/span node" (§13:820).
  ;; In the interpreted lane both are already true when this is called. In the
  ;; GENERATED lane neither is: `exec` owns its own `pos`/`off`/`st` locals and
  ;; the parser's slots are only written when `exec` RETURNS, so without these
  ;; two lines `parser-stream-offset` answers the offset at the start of the
  ;; feed and `parser-state-name` answers the state the feed started in. The
  ;; emitted arm passes its own `st` and `off`; the interpreted arm passes the
  ;; values already there, so the writes are no-ops on that side.
  ;;
  ;; Both entry points call this rather than writing the two lines themselves.
  ;; That is not only taste: each line carries a one-site mutation FIND of its
  ;; own and the suite declares no SITES anywhere, so a second copy is a
  ;; configure-TIME failure, not a test failure.
  (define (callback-commit! parser state offset)
    (parser-set-current! parser state)
    (parser-set-offset! parser offset))

  (define (byte-machine-callback-step/v1 parser state offset f branches continue default)
    (callback-commit! parser state offset)
    (if (unbound-callback? f)
        ;; §9.3:419: "An optional decision callback must declare
        ;; `default-branch`; other optional callbacks default to `continue`."
        ;; Both are resolved to a TARGET at lowering time, so this arm is one
        ;; jump and carries no rule of its own.
        (list 'goto default)
        (classify-callback-result (f parser (parser-user-context parser))
                                  branches continue)))

  ;; --- the span runtime (§19.3:1024, Milestone 5 Slice ③) --------------------
  ;;
  ;; Span state is a NAME, a MARK and the data callback's SLOT -- never a
  ;; bytevector. §14:833 re-anchors the mark at every feed boundary, so it is a
  ;; SLICE offset and never has to mean anything between feeds; that is what
  ;; keeps §28:1725's "no bytevector field in parser storage" structurally true
  ;; rather than merely observed.
  (define (byte-machine-span-open/v1 parser name mark data-slot)
    (parser-set-active-span! parser name)
    (parser-set-span-mark! parser mark)
    (parser-set-span-data-slot! parser data-slot))

  (define (byte-machine-span-close/v1 parser)
    (parser-set-active-span! parser #f)
    (parser-set-span-mark! parser 0)
    (parser-set-span-data-slot! parser #f))

  ;; *** ONE PROCEDURE DELIVERS EVERY SPAN FRAGMENT, and §14:834's suppression
  ;; is inside it. *** A fragment is delivered in exactly three places -- a span
  ;; end, the feed-boundary flush, and the emitted arms for both -- and every one
  ;; of them owes §14:834 the same empty check. Written out per caller it would
  ;; be three chances to get it wrong and three mutation sites saying one thing.
  ;;
  ;; It also keeps the emitted arm free of a mark local: `reserved-member-3` is
  ;; the exact set of identifiers the generated body binds, so a rendered
  ;; `(let ((m (byte-machine-span-mark/v1 psr))) ...)` would move that list, both
  ;; of its FINDs, and member3-drift-tests.sps's twice-asserted nine.
  ;;
  ;; *** IT DOES NOT ADVANCE THE MARK, and that is measured rather than assumed.
  ;; *** §14:841 says the data callback sees "its mark advanced to the current
  ;; cursor", and an advance was written here first. Measured: deleting it fails
  ;; nothing, in either lane. The reason is a construction, not a coverage gap --
  ;; every path out of a delivery either CLOSES the span (the completion substep
  ;; sets the mark to 0) or crosses a feed boundary, where §14:833's re-anchor
  ;; overwrites the mark with the next slice's `start`. There is no third path,
  ;; and no public accessor reads the mark, so nothing can observe the value
  ;; between the two. Keeping both would be one rule written twice with only one
  ;; of them load-bearing; §14:841's sentence is discharged by §14:833's
  ;; re-anchor, which is where the re-anchoring now lives entirely.
  ;;
  ;; §13:790's five-argument application is the ONLY thing here that the
  ;; two-argument entry point above does differently. `branches` is '() because
  ;; §13:812 gives a span callback only continue, pause and failure -- the branch
  ;; arm is dead for spans rather than absent, which is what keeps ONE
  ;; classifier and satisfies decision 0024's "from the same construction".
  (define (byte-machine-span-fragment-step/v1 parser state offset f bv to continue)
    (let ((from (parser-span-mark parser)))
      (if (or (>= from to) (unbound-callback? f))
          (list 'goto continue)
          (begin
            (callback-commit! parser state offset)
            (classify-callback-result
             (f parser (parser-user-context parser) bv from to)
             '() continue)))))

  ;; §19.3:1024's boundary flush, and §14:833-834. It runs at the ONE seam both
  ;; lanes cross -- after the executor has answered and before `parser-feed!`
  ;; records the lifecycle -- because the emitted `exec` has nowhere to put it:
  ;; its `need-input` return is rendered inside `render-exhausted-preamble` and
  ;; returns immediately.
  ;;
  ;; *** ONLY ON `need-input`, and every other status has a reason rather than an
  ;; omission. ***
  ;;   error     -- §14:839 forbids a final partial fragment outright.
  ;;   stopped   -- §14:843 makes reaching either with a span active a VERIFIER
  ;;   finished     rejection (`span-active-at-exit`), so neither is reachable.
  ;;   paused    -- *** AND THE REASON IS THE OPPOSITE OF THE ONE FIRST WRITTEN
  ;;                HERE. *** That comment said the fragment on this row is
  ;;                "empty BY CONSTRUCTION" because the invoker advances the mark
  ;;                first -- which is false twice over: nothing advances the mark
  ;;                (see the fragment step above, which says so in capitals), and
  ;;                MEASURED on the branch's own span machine with a pausing data
  ;;                callback, a feed that exits `paused` leaves the span active
  ;;                with mark 1 and `next` 4. `[1,4)` is not empty -- it is
  ;;                byte-for-byte the fragment the span end has just delivered.
  ;;
  ;;                So an arm here would not be inert: it would DELIVER THAT
  ;;                FRAGMENT A SECOND TIME, against §13:814's "it is never
  ;;                delivered twice". The row is omitted because a flush there is
  ;;                WRONG, not because it would do nothing -- and the difference
  ;;                matters, because "a guard that cannot fire" is this project's
  ;;                standing invitation to add the guard.
  (define (span-boundary-flush! parser bv r)
    (if (and (eq? (parser-result-status r) 'need-input)
             (parser-active-span parser))
        (let ((o (byte-machine-span-fragment-step/v1
                  parser (parser-current parser) (parser-offset parser)
                  (vector-ref (parser-callbacks parser)
                              (parser-span-data-slot parser))
                  bv (parser-result-next r)
                  ;; No target: a flush is not a machine step. §14:833 keeps the
                  ;; span open and the parser parked exactly where the executor
                  ;; left it, so the `goto` payload is discarded below.
                  #f)))
          (case (car o)
            ((goto) r)
            ;; §14:837: "the fragment is committed, the span remains open, and
            ;; resume begins with the next supplied input." Committed means not
            ;; delivered again, which §14:833's re-anchor on the NEXT feed is what
            ;; guarantees; this arm only changes what the feed REPORTS, keeping
            ;; the resume state the executor chose.
            ((pause) (make-parser-result 'paused (parser-result-next r)
                                         (parser-result-consumed r)
                                         (parser-offset parser) #f))
            ;; The node name is asked for rather than passed: `parser-state-name`
            ;; answers the source node in BOTH lanes (member 2's table on one
            ;; side, the executor on the other), and a flush has no state id of
            ;; its own -- §12.7:777 excludes the id from the comparison but still
            ;; requires an integer, and the data callback's slot is the integer
            ;; that actually identifies this invocation.
            ;;
            ;; `boundary`: the flush happens with the slice exhausted, which is a
            ;; byte boundary by definition (§12.7:768).
            (else
             (make-parser-result 'error (parser-result-next r)
                                 (parser-result-consumed r) (parser-offset parser)
                                 (byte-machine-make-callback-error/v1
                                  (cadr o) (caddr o) (parser-state-name parser)
                                  (parser-span-data-slot parser)
                                  (parser-offset parser) 'boundary)))))
        r))

  ;; A FRESH vector every call, never a shared one: two parsers from one compiled
  ;; machine must not share storage, and parser-reset! must not hand back a
  ;; vector an earlier reset also handed out.
  (define (initial-values decls)
    (let ((v (make-vector (vector-length decls) 0)))
      (let loop ((i 0))
        (if (>= i (vector-length decls)) v
            (begin (vector-set! v i (cdr (vector-ref decls i)))
                   (loop (+ i 1)))))))

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
      ;; §12.2:698-699's two Milestone 5 rows. THREE distinct codes, because
      ;; §9.4:438 lists "lifecycle violation, reentrancy, poisoned parser" as
      ;; three: a caller who fed a paused parser made a sequencing mistake, a
      ;; callback that fed the parser it is running inside made a reentrancy
      ;; mistake, and a caller who fed a parser an escaped callback left behind
      ;; is holding something only reset can reuse (§12.6:749).
      ((busy)
       (byte-machine-contract-violation 'parser-feed! 'reentrancy
                                        (list (parser-lifecycle parser) 'feed)))
      ((poisoned)
       (byte-machine-contract-violation 'parser-feed! 'poisoned-parser
                                        (list (parser-lifecycle parser) 'feed)))
      ;; *** `ready` IS AN ARM NOW, AND THE ELSE IS LOUD. *** It was the `else`,
      ;; which meant every lifecycle value this case did not name executed input
      ;; -- so adding `busy` or `poisoned` to the lifecycle vocabulary without
      ;; adding these arms would have made a poisoned parser silently RE-EXECUTE
      ;; instead of raising, with no exhaustiveness check anywhere and no test
      ;; able to notice, because nothing could produce those states yet.
      ((ready)
       ;; §12.1:679: "`busy` is an internal guard while feed, finish, or a
       ;; callback is executing." Set BEFORE the executor runs, which is what
       ;; makes the reentrancy arm above reachable at all -- a callback calling
       ;; back into this parser meets it -- and what makes §13:821's "lifecycle
       ;; is `busy`" true of what a callback observes.
       (parser-set-lifecycle! parser 'busy)
       ;; §14:833: an open span "begins its next possible fragment at the next
       ;; feed's `start`". The mark is a SLICE offset, so it means nothing in a
       ;; slice it did not come from -- re-anchoring HERE is what lets it be one,
       ;; and a slice offset is what keeps §28:1725's "no bytevector field in
       ;; parser storage" structurally true rather than merely observed.
       (when (parser-active-span parser)
         (parser-set-span-mark! parser start))
       (let ((completed #f))
         (dynamic-wind
           (lambda () #t)
           (lambda ()
             ;; The flush is INSIDE the wind: it runs application code, so a
             ;; callback that escapes from it must poison the parser exactly as
             ;; one escaping from the executor does (§12.6:749).
             (let ((r (span-boundary-flush!
                       parser bv
                       (case (parser-variant parser)
                        ((op) (parser-feed-op! parser bv start end))
                        ((v2) (parser-feed-v2! parser bv start end))
                        (else (assertion-violation 'parser-feed! "unknown parser variant"
                                                   (parser-variant parser)))))))
               (case (parser-result-status r)
                 ((stopped) (parser-set-lifecycle! parser 'stopped))
                 ((error) (parser-set-lifecycle! parser 'error)
                          (parser-set-stored-error! parser (parser-result-error r)))
                 ((finished) (parser-set-lifecycle! parser 'finished))
                 ((paused) (parser-set-lifecycle! parser 'paused-feed))
                 ;; `need-input` returns the parser to `ready`, and it is its own
                 ;; arm rather than a fall-through: before `busy` existed a
                 ;; fall-through left the lifecycle alone and that was correct;
                 ;; now it would leave the parser BUSY forever.
                 ((need-input) (parser-set-lifecycle! parser 'ready))
                 (else (assertion-violation 'parser-feed! "unknown result status"
                                            (parser-result-status r))))
               (set! completed #t)
               r))
           ;; §12.6:749: "If a callback raises an unexpected condition or
           ;; performs a nonlocal escape, the condition/escape propagates and
           ;; `dynamic-wind` marks the parser poisoned." The flag is what tells
           ;; the two apart -- this thunk runs on BOTH exits, and only the
           ;; abnormal one leaves it false. Nothing is caught here: the
           ;; condition propagates, which is the sentence's first clause.
           (lambda ()
             (unless completed (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-feed! "unknown lifecycle"
                                 (parser-lifecycle parser)))))

  ;; The interpreter path. Sticky rows short-circuit one level up in
  ;; parser-feed! (D1), so this loop no longer serves repeat feeds on a
  ;; terminal parser -- it is reached only while the lifecycle is 'ready, and
  ;; runs a single live dispatch walk from `current` to its next stop/error/
  ;; finish/pause.
  (define (parser-feed-op! parser bv start end)

      ;; Route a byte-consuming step: park `current` on the target, then either
      ;; consume the byte and continue at a boundary, or leave it for whatever
      ;; comes next and report §12.7:768's `byte` -- AT the offending byte, which
      ;; is what makes an overflow report where it happened.
      ;;
      ;; Shared by the dispatch arm and Slice ③'s accumulate arm. Written out
      ;; twice the two are textually IDENTICAL, so three shipped mutations
      ;; anchored on this tail resolved to two sites and the suite hard-failed at
      ;; declaration -- and no longer anchor could separate them, because once the
      ;; op has answered the two arms genuinely do the same thing. Factoring is
      ;; the honest fix; each arm's CALL stays its own line, and what differs
      ;; between them -- which op message, and what it is given -- stays there.
      (define (route-byte-step! target mode pos loop)
        (parser-set-current! parser target)
        (if (eq? mode 'advance)
            (begin
              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop (+ pos 1) 'boundary))
            (loop pos 'byte)))
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
            ;; *** Slice ②'s ZERO-WIDTH kinds. *** They consume no byte, so the
            ;; loop re-enters at the SAME `pos` with the same offset, and the
            ;; only state that moves is `current` plus whatever the op committed
            ;; into the field vector. The op does the bound check and the write;
            ;; this arm only routes.
            ;;
            ;; `pk` is carried THROUGH unchanged rather than reset. Position kind
            ;; describes where in the input stream the parser is, and a
            ;; zero-width step does not move it -- so a failure reached after one
            ;; reports the same kind it would have reported without it. §12.7:777
            ;; makes position kind differential-compared, so the two lanes must
            ;; agree on this and the emitter carries the same rule.
            ((field-action field-branch)
             (let ((t (op 'field-step node (parser-field-values parser))))
               (parser-set-current! parser t)
               (loop pos pk)))
            ;; *** The tenth kind, and the first arm in this loop that runs
            ;; APPLICATION code. *** Zero-width like the two above (§11.4:652),
            ;; so `pos` and the offset are carried through unchanged, and `pk`
            ;; is carried for the LOOP but is NOT what the error records.
            ;;
            ;; *** This comment said the carried-through `pk` "already
            ;; implements" §12.7:770, and it does not. *** That row is "zero-width
            ;; machine action or callback failure | `boundary` at the current
            ;; stream offset", flatly; `pk` is `byte` whenever this node was
            ;; entered over a REEXECUTE edge, and BOTH LANES reported it, so the
            ;; cross-lane comparison could not see it. The failure arm below
            ;; records `callback-failure-position` -- see its own note beside
            ;; `byte-machine-make-callback-error/v1`.
            ;;
            ;; The parts are (slot continue branches pause default state-id) and
            ;; the vocabulary lives in `byte-machine-callback-step/v1`, which
            ;; the emitted arm calls too.
            ((callback)
             (let* ((parts (op 'callback-parts node))
                    (o (byte-machine-callback-step/v1
                        parser node (parser-offset parser)
                        (vector-ref (parser-callbacks parser) (car parts))
                        (caddr parts) (cadr parts) (list-ref parts 4))))
               (case (car o)
                 ((goto)
                  (parser-set-current! parser (cadr o))
                  (loop pos pk))
                 ;; §13:814: "A callback-requested pause occurs after the
                 ;; callback's delivered event has been committed. Resume
                 ;; continues after that event; it is never delivered twice." So
                 ;; `current` is parked PAST the invocation, on the declared
                 ;; pause continuation -- the pause node's own arm above, one
                 ;; kind later.
                 ((pause)
                  (parser-set-current! parser (cadddr parts))
                  (make-parser-result 'paused pos (- pos start)
                                      (parser-offset parser) #f))
                 (else
                  (make-parser-result 'error pos (- pos start) (parser-offset parser)
                                      (byte-machine-make-callback-error/v1
                                       (cadr o) (caddr o) node (list-ref parts 5)
                                       (parser-offset parser) callback-failure-position))))))
            ;; *** Slice ③'s ELEVENTH AND TWELFTH kinds, and the interpreter's
            ;; own thirteenth arm for §14:841's substep. *** All three are
            ;; zero-width (§10.6:590), so `pos`, the offset and `pk` carry
            ;; through unchanged, exactly as the callback arm's do.
            ((span-start)
             ;; §14:830: "Starting a span records the current cursor." `pos` is
             ;; the slice index, which is what a mark IS (§14:833).
             (let ((parts (op 'span-start-parts node)))
               (byte-machine-span-open/v1 parser (car parts) pos (cadr parts))
               (parser-set-current! parser (caddr parts))
               (loop pos pk)))
            ((span-end)
             ;; §14:831 and §14:841: the remaining fragment, with the mark
             ;; advanced to the cursor first and the empty one suppressed --
             ;; all three rules inside the step, so this arm only routes.
             ;;
             ;; TWO substeps, not one: §14:838 resumes "at the next undelivered
             ;; substep", so the fragment's continuation is the substep below
             ;; and never the node's own successor.
             (let* ((parts (op 'span-end-parts node))
                    (o (byte-machine-span-fragment-step/v1
                        parser node (parser-offset parser)
                        (vector-ref (parser-callbacks parser) (car parts))
                        bv pos (cadr parts))))
               (case (car o)
                 ((goto)
                  (parser-set-current! parser (cadr o))
                  (loop pos pk))
                 ;; §13:814's rule again, and §14:837's "the fragment is
                 ;; committed": the park is PAST the delivery, on the substep
                 ;; that has not run.
                 ((pause)
                  (parser-set-current! parser (cadr parts))
                  (make-parser-result 'paused pos (- pos start)
                                      (parser-offset parser) #f))
                 (else
                  (make-parser-result 'error pos (- pos start) (parser-offset parser)
                                      (byte-machine-make-callback-error/v1
                                       (cadr o) (caddr o) (cadddr parts)
                                       (caddr parts) (parser-offset parser)
                                       callback-failure-position))))))
            ((span-completion)
             ;; §14:841: "Before invoking the completion callback, execution
             ;; makes the span inactive." BEFORE -- a completion callback asking
             ;; `parser-active-span` must see #f, and this is the only place the
             ;; ordering is written.
             (let ((parts (op 'span-completion-parts node)))
               (byte-machine-span-close/v1 parser)
               (if (not (car parts))
                   ;; §10.4:516's absent completion callback: no invocation, no
                   ;; slot lookup, straight to the node's successor.
                   (begin (parser-set-current! parser (cadr parts))
                          (loop pos pk))
                   (let ((o (byte-machine-callback-step/v1
                             parser node (parser-offset parser)
                             (vector-ref (parser-callbacks parser) (car parts))
                             '() (cadr parts) (cadr parts))))
                     (case (car o)
                       ((goto)
                        (parser-set-current! parser (cadr o))
                        (loop pos pk))
                       ((pause)
                        (parser-set-current! parser (cadr parts))
                        (make-parser-result 'paused pos (- pos start)
                                            (parser-offset parser) #f))
                       (else
                        (make-parser-result 'error pos (- pos start)
                                            (parser-offset parser)
                                            (byte-machine-make-callback-error/v1
                                             (cadr o) (caddr o) (cadddr parts)
                                             (caddr parts) (parser-offset parser)
                                             callback-failure-position))))))))
            ;; Slice ③'s INPUT-READING kind. It needs a byte, so it yields
            ;; `need-input` at the end of a slice and resumes at the same node on
            ;; the next feed -- its whole split-point behaviour, inherited from
            ;; the dispatch shape rather than invented. The op answers
            ;; `(target . mode)` because a step has three outcomes with two
            ;; different consumption behaviours.
            ((accumulate)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f)
                 (let ((r (op 'accumulate-step node (parser-field-values parser)
                              (bytevector-u8-ref bv pos))))
                   (route-byte-step! (car r) (cdr r) pos loop))))
            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f)
                 (let ((trans (op 'dispatch node (bytevector-u8-ref bv pos))))
                   (route-byte-step! (car trans) (cdr trans) pos loop))))
            (else (assertion-violation 'parser-feed! "unknown node kind" (op 'kind node))))))))

  ;; The generated /v2 path: exec owns the dispatch loop; finish? = #f for feed.
  (define (parser-feed-v2! parser bv start end)
    (let* ((exec (parser-executor parser))
           ;; The PARSER's own field vector, not the shared sentinel. Slice ①a
           ;; reserved this parameter and both call sites passed `empty-fields`
           ;; through ①a and ①b, which was correct while nothing read it; Slice
           ;; ② emits arms that write through it, and a shared empty vector
           ;; would make every generated field machine index out of bounds --
           ;; measured, before this line changed.
           ;; The PARSER's own callback slot vector, not the shared sentinel.
           ;; Slice ①a reserved this parameter, ①b filled the slots and nothing
           ;; read them, and Slice ② emits an arm that indexes it -- so a shared
           ;; empty vector would make every generated callback machine index out
           ;; of bounds. The same correction Slice ② of the last milestone made
           ;; to `empty-fields`, one parameter later.
           (o (exec (parser-current parser) (parser-offset parser) bv start end #f
                    (parser-field-values parser) parser (parser-callbacks parser))))
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
      ;; §12.2:698-699, the same two rows and the same three codes as
      ;; `parser-feed!`'s. Deliberately not shared with them: this file's own
      ;; comment above `parser-feed!` records why near-identical arms here stay
      ;; separate, and each of these is its own row of the operation matrix.
      ((busy)
       (byte-machine-contract-violation 'parser-finish! 'reentrancy
                                        (list (parser-lifecycle parser) 'finish)))
      ((poisoned)
       (byte-machine-contract-violation 'parser-finish! 'poisoned-parser
                                        (list (parser-lifecycle parser) 'finish)))
      ;; The two states that RUN, named rather than left to an else, for the
      ;; reason `parser-feed!`'s arm records: an else meaning "ready" swallows
      ;; every lifecycle value added after it.
      ((ready finish-ready)
       (parser-set-lifecycle! parser 'busy)
       ;; *** NO MARK RE-ANCHOR HERE, and its absence is a derivation rather than
       ;; an omission. *** The feed path re-anchors because the next slice has its
       ;; own coordinates; the finish path runs over `empty-bv 0 0` in both lanes,
       ;; so an EOF-side span end delivers `[mark,0)` -- and `from >= to` holds
       ;; for EVERY mark, a mark never being negative. §14:834 suppresses that
       ;; fragment whatever the mark says, which is also why the EOF side needs
       ;; no bytevector and why there is no boundary flush after EOF. A
       ;; `(parser-set-span-mark! parser 0)` was written here first and deleted:
       ;; it could not change an outcome, and a guard that cannot fire reads as
       ;; one that does.
       (let ((completed #f))
         (dynamic-wind
           (lambda () #t)
           (lambda ()
             (let ((r (case (parser-variant parser)
                        ((op) (parser-finish-op! parser))
                        ((v2) (parser-finish-v2! parser))
                        ;; Unreachable for the same reason as make-parser's else.
                        (else (assertion-violation 'parser-finish! "unknown parser variant"
                                                   (parser-variant parser))))))
               ;; Unlike the feed path, BOTH finish paths record their own
               ;; terminal lifecycle before returning -- and every EOF outcome is
               ;; terminal or paused, so there is no `need-input` arm to restore.
               ;; The `busy` written above is therefore always overwritten by the
               ;; time this returns, which is asserted rather than assumed.
               (when (eq? (parser-lifecycle parser) 'busy)
                 (assertion-violation 'parser-finish!
                                      "the finish path left the parser busy"
                                      (parser-result-status r)))
               (set! completed #t)
               r))
           (lambda ()
             (unless completed (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-finish! "unknown lifecycle"
                                 (parser-lifecycle parser)))))

  ;; The generated /v2 finish path: run exec over the empty slice with finish? #t.
  ;; exec owns the eof-target chain internally (Task 2 lowers it); the runtime just
  ;; commits resume state, records the terminal lifecycle, and snapshots the result
  ;; (no slice, so next/consumed mirror the stream offset / 0).
  (define (parser-finish-v2! parser)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t
                    (parser-field-values parser) parser (parser-callbacks parser))))
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
          ;; The same zero-width routing on the EOF side. `pk` is carried
          ;; through here too: on an EOF chain it is already 'eof, and a
          ;; zero-width hop does not make the position a boundary again.
          ((field-action field-branch)
           (let ((t (op 'field-step node (parser-field-values parser))))
             (parser-set-current! parser t)
             (loop t pk)))
          ;; §12.4:729: "EOF processing may invoke callbacks and may pause. A
          ;; pause during EOF produces `paused-finish`." The same invocation as
          ;; the feed loop's, deliberately written out rather than shared with
          ;; it: the two arms differ in what they build and in the lifecycle
          ;; they record, and this file's own comment above `parser-feed!`
          ;; states why near-identical arms here stay separate.
          ((callback)
           (let* ((parts (op 'callback-parts node))
                  (o (byte-machine-callback-step/v1
                      parser node (parser-offset parser)
                      (vector-ref (parser-callbacks parser) (car parts))
                      (caddr parts) (cadr parts) (list-ref parts 4))))
             (case (car o)
               ((goto)
                (parser-set-current! parser (cadr o))
                (loop (cadr o) pk))
               ((pause)
                (parser-set-current! parser (cadddr parts))
                (parser-set-lifecycle! parser 'paused-finish)
                (make-parser-result 'paused off 0 off #f))
               (else
                (parser-set-current! parser node)
                (parser-set-lifecycle! parser 'error)
                (let ((e (byte-machine-make-callback-error/v1
                          (cadr o) (caddr o) node (list-ref parts 5) off
                          callback-failure-position)))
                  (parser-set-stored-error! parser e)
                  (make-parser-result 'error off 0 off e))))))
          ;; Slice ③'s span kinds on the EOF side. The SAME three arms as the
          ;; feed loop's, written out for the reason this file's own comment
          ;; above `parser-feed!` gives -- each records its own lifecycle -- and
          ;; over `empty-bv` at cursor 0.
          ;;
          ;; *** THE CURSOR IS WHY NO BYTEVECTOR IS NEEDED HERE, and the first
          ;; version of this comment got the reason wrong. *** It said
          ;; `parser-finish!` "re-anchored the mark to 0 before this ran" -- and
          ;; `parser-finish!` says, in as many words 130 lines above, that the
          ;; line doing that was written and DELETED. The derivation does not
          ;; need it: the cursor passed below is the literal 0, a mark is never
          ;; negative, so `from >= to` holds for EVERY mark and §14:834
          ;; suppresses the fragment whatever the mark says. `empty-bv` is passed
          ;; because the step's signature takes one, never because a byte of it
          ;; is read.
          ((span-start)
           (let ((parts (op 'span-start-parts node)))
             (byte-machine-span-open/v1 parser (car parts) 0 (cadr parts))
             (parser-set-current! parser (caddr parts))
             (loop (caddr parts) pk)))
          ((span-end)
           (let* ((parts (op 'span-end-parts node))
                  (o (byte-machine-span-fragment-step/v1
                      parser node off
                      (vector-ref (parser-callbacks parser) (car parts))
                      empty-bv 0 (cadr parts))))
             (case (car o)
               ((goto)
                (parser-set-current! parser (cadr o))
                (loop (cadr o) pk))
               ((pause)
                (parser-set-current! parser (cadr parts))
                (parser-set-lifecycle! parser 'paused-finish)
                (make-parser-result 'paused off 0 off #f))
               (else
                (parser-set-current! parser node)
                (parser-set-lifecycle! parser 'error)
                (let ((e (byte-machine-make-callback-error/v1
                          (cadr o) (caddr o) (cadddr parts) (caddr parts) off
                          callback-failure-position)))
                  (parser-set-stored-error! parser e)
                  (make-parser-result 'error off 0 off e))))))
          ((span-completion)
           (let ((parts (op 'span-completion-parts node)))
             (byte-machine-span-close/v1 parser)
             (if (not (car parts))
                 (begin (parser-set-current! parser (cadr parts))
                        (loop (cadr parts) pk))
                 (let ((o (byte-machine-callback-step/v1
                           parser node off
                           (vector-ref (parser-callbacks parser) (car parts))
                           '() (cadr parts) (cadr parts))))
                   (case (car o)
                     ((goto)
                      (parser-set-current! parser (cadr o))
                      (loop (cadr o) pk))
                     ((pause)
                      (parser-set-current! parser (cadr parts))
                      (parser-set-lifecycle! parser 'paused-finish)
                      (make-parser-result 'paused off 0 off #f))
                     (else
                      (parser-set-current! parser node)
                      (parser-set-lifecycle! parser 'error)
                      (let ((e (byte-machine-make-callback-error/v1
                                (cadr o) (caddr o) (cadddr parts) (caddr parts)
                                off callback-failure-position)))
                        (parser-set-stored-error! parser e)
                        (make-parser-result 'error off 0 off e))))))))
          ;; At finish there is no input, so an accumulate node takes its own
          ;; declared EOF edge exactly as a dispatch node does (§10.6:569).
          ((accumulate dispatch)
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
      ;; §12.2:698-699. The shipped else answered `lifecycle-violation` for
      ;; every non-paused row, which was right while `poisoned` and `busy` did
      ;; not exist and is wrong now: §12.2 gives the poisoned row `parser-poisoned`
      ;; and the busy row the reentrancy condition, and §9.4:438 makes all three
      ;; codes distinct. The else keeps its own row -- resuming a `ready` or
      ;; terminal parser is still a sequencing mistake and nothing else.
      ((busy)
       (byte-machine-contract-violation 'parser-resume! 'reentrancy
                                        (list (parser-lifecycle parser) 'resume)))
      ((poisoned)
       (byte-machine-contract-violation 'parser-resume! 'poisoned-parser
                                        (list (parser-lifecycle parser) 'resume)))
      (else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))))

  ;; §9.3:410. READ-ONLY, with no mutating sibling, and that is a design
  ;; decision rather than an omission: §13:801 -- "Machine-field access from a
  ;; callback is read-only. Allowing callbacks to mutate fields would bypass the
  ;; closed IR and invalidate interpreter/generated equivalence."
  ;;
  ;; An undeclared name is a caller mistake, not a machine outcome, so it raises
  ;; a CONTRACT VIOLATION rather than producing a parser-error: parser-error is
  ;; the §9.3 record describing what the parsed INPUT did, and answering a
  ;; misspelled field name with one would put a programming error into the same
  ;; channel as a rejected byte. `accessor-misuse` is a new code for exactly
  ;; that: reaching an accessor with something the machine never declared.
  (define (parser-field-ref parser field-name)
    (unless (parser? parser)
      (byte-machine-contract-violation 'parser-field-ref 'invalid-argument parser))
    (let* ((decls (parser-field-decls parser))
           (n (vector-length decls)))
      (let loop ((i 0))
        (cond ((>= i n)
               (byte-machine-contract-violation 'parser-field-ref 'accessor-misuse
                                                field-name))
              ((eq? (car (vector-ref decls i)) field-name)
               (vector-ref (parser-field-values parser) i))
              (else (loop (+ i 1)))))))

  ;; Full reset (§12.5), M2 subset: entry state, offset 0, lifecycle ready, and
  ;; the stored error cleared. `current := entry` is also what clears the pause
  ;; continuation under this representation -- D3 parks it on `current` with no
  ;; separate saved-continuation field, so restoring `current` restores both.
  ;; FIELD state exists as of Milestone 4 Slice ①b and is restored here, to the
  ;; DECLARED initials rather than to zero: §12.5:738 returns the parser to its
  ;; just-constructed state, and a just-constructed parser holds the declared
  ;; initials. Zeroing would silently make `u8 count = 3` mean 3 before the first
  ;; reset and 0 after it. SPAN state joins them in Slice ③ -- §12.5:739 lists it
  ;; first -- and is cleared through the same procedure the span-end arms call,
  ;; so "inactive" has exactly one definition. `busy` and `poisoned` are not
  ;; reset state at all: the guard below rejects the first, and §12.2:698 makes
  ;; the second the row this operation exists to clear, which the lifecycle write
  ;; already does. Returns unspecified.
  ;;
  ;; It writes slot 8 and never slot 9: the declarations belong to the compiled
  ;; machine and outlive every reset.
  (define (parser-reset! parser)
    ;; *** THE ONLY OPERATION §12.2 LETS A POISONED PARSER RUN. *** Every
    ;; operation's `busy` cell differs from its `poisoned` cell -- the two rows
    ;; name different codes throughout -- but reset is the one whose poisoned
    ;; cell is not a raise at all: §12.2:698 RESETS a poisoned parser, because
    ;; §12.6:749's "Only full reset may reuse it" is a permission and not a
    ;; prohibition, while §12.2:699 raises reentrancy for reset while busy -- a
    ;; callback may not reset the parser it is running inside. Before this the
    ;; procedure had no lifecycle guard at all: five unconditional mutations.
    ;;
    ;; §12.6:747 puts the raise "before further mutation", so the guard is the
    ;; first thing here and nothing above it can move.
    (when (eq? (parser-lifecycle parser) 'busy)
      (byte-machine-contract-violation 'parser-reset! 'reentrancy
                                       (list (parser-lifecycle parser) 'reset)))
    (parser-set-current! parser (parser-entry parser))
    (parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready)
    (parser-set-stored-error! parser #f)
    (byte-machine-span-close/v1 parser)
    (vector-set! parser 8 (initial-values (parser-field-decls parser)))))
