;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile. Two executor variants share this one parser API and the one
;;; parser-result contract: the reference interpreter builds an `op` message
;;; closure over the source IR; generated code is a direct resumable executor
;;; constructed through the one unversioned byte-machine-make-compiled-machine
;;; (/v1 and /v2 survive only as tombstones that refuse every version). The two
;;; are deliberately different implementations, which is what lets the
;;; interpreter≡generated differential catch lowering defects.
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
          byte-machine-make-compiled-machine
          byte-machine-make-compiled-machine/v1 byte-machine-make-compiled-machine/v2
          byte-machine-make-feed-outcome/v1
          make-parser parser?
          parser-feed! parser-finish! parser-resume! parser-lifecycle parser-reset!
          parser-result? parser-result-status parser-result-next
          parser-result-consumed parser-result-stream-offset parser-result-error
          parser-result-pause
          byte-machine-make-parser-error/v1 parser-error?
          parser-error-domain parser-error-code parser-error-reason
          parser-error-detail parser-error-node-name parser-error-state-id
          parser-error-offset parser-error-position-kind
          parser-field-ref
          callback-continue callback-pause
          ;; `parser-state-name` must name a source node, not a generated
          ;; internal state, so it needs the id->name table the generated lane
          ;; carries as ABI payload member 2.
          parser-stream-offset parser-user-context parser-active-span
          parser-state-name
          make-callback-failure callback-failure?
          callback-failure-code callback-failure-detail
          ;; Both are called from EMITTED code, which is why they carry the /v1
          ;; seam suffix and why they are exported at all -- the generated library
          ;; imports (byte-machine runtime) and nothing else.
          byte-machine-callback-step/v1 byte-machine-make-callback-error/v1
          ;; The span machinery both lanes call, every one called from EMITTED
          ;; code. `parser-active-span` is NOT one of them: no emitted text names
          ;; it.
          byte-machine-span-open/v1 byte-machine-span-fragment-step/v1
          byte-machine-span-close/v1
          byte-machine-keyword-step/v1)
  (import (rnrs)
          (byte-machine private conditions)
          (byte-machine private names))

  (define (tag sym) (vector sym))
  (define (tagged? t x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))

  ;; Allocation-free outcome singletons. They fix the contract so interpreter
  ;; and generated callbacks return the same objects.
  ;; callback-continue : CallbackOutcome
  (define callback-continue (vector 'byte-machine-callback-continue))
  ;; callback-pause : CallbackOutcome
  (define callback-pause (vector 'byte-machine-callback-pause))

  ;; --- compiled machine: two variants behind one type ---
  ;; op:  (vector tag 'op op-closure)                    -- the reference interpreter
  ;; v2:  (vector tag 'v2 exec entry-state fingerprint fields) -- generated code, one
  ;;      unified `exec` closure carrying a finish? flag. Built by the ONE
  ;;      unversioned constructor below; the variant tag is an internal shape
  ;;      label, not an ABI version.
  ;; The 'v1 feed-only variant is gone: once /v1 refuses every version nothing
  ;; can construct one, and an arm no public API can reach is dead code.
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  ;; make-compiled-machine : Procedure -> CompiledMachine
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag 'op op))
  ;; compiled-machine? : Any -> Boolean
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-variant cm) (vector-ref cm 1))

  ;; The ABI version the emitter emits. The version CHECK below stays
  ;; load-bearing for a reason specific to this project: Chez prefers a compiled
  ;; object over source and staleness is transitive across imports, so a stale
  ;; object of a generated library really can meet a newer runtime inside this
  ;; repository's own build. The strict equality below is what enforces the
  ;; version; the metadata length check further down enforces nothing about it.
  ;;
  ;; The payload's state-id to source-name table is what makes `parser-state-name`
  ;; answerable in the generated lane at all, and there is no other transport for
  ;; it: the emitted library exports one name and the constructor's arguments are
  ;; the only channel.
  ;; 6 since Milestone 11 (decision 0044): the keyword-table node lowers to a new
  ;; normalized state whose emitted arm calls `byte-machine-keyword-step` here, a
  ;; runtime binding generated code did not depend on at ABI 5. A generated
  ;; library that calls it must be refused by an older runtime with the clean
  ;; ABI-mismatch condition rather than an unbound-identifier error, so the
  ;; contract change is a version bump -- §9.5:444.
  ;; 7 since Milestone 12 (decision 0046): a paused outcome's error slot may now
  ;; carry a reason record where it was always #f, so a consumer decoding a v7
  ;; generated parser must know the moved payload contract -- another version bump.
  (define current-abi-version 8)
  ;; How many payload members the current ABI defines AS REQUIRED: field
  ;; declarations, the callback declaration table, and the state-id to
  ;; source-name table. The keyword-table op adds no payload member -- its table
  ;; rides the emitted state datum, not the compiled-machine metadata. The
  ;; Milestone 13 settable table is an OPTIONAL fourth member (read below only
  ;; when present), so this REQUIRED minimum stays 3 while the version moves to 8
  ;; -- a machine with no settable field emits exactly three members and is
  ;; byte-identical to its ABI-7 self but for the version literal. Named beside
  ;; the version because the two move together -- growing the payload is a
  ;; version bump -- and read by the single length guard below.
  (define current-abi-members 3)
  ;; ABI payload member 1: the callback declaration table the generated lane
  ;; resolves bindings against. `#()` for a machine declaring none.
  (define (compiled-machine-v2-callbacks cm) (vector-ref cm 6))
  ;; ABI payload member 2: a vector of SOURCE node names indexed by state id,
  ;; total over internal prefix states.
  (define (compiled-machine-v2-state-names cm) (vector-ref cm 7))

  ;; The one unversioned constructor. Its FIRST action is the version check, so a
  ;; mismatch is reported before any part of the payload is interpreted -- which
  ;; is what makes the payload safe to grow. `metadata` is one quoted vector
  ;; rather than a rest-arg: a rest-arg would let the payload grow WITHOUT a
  ;; version bump, and the version check is the only thing standing between a
  ;; stale object and silent wrong answers, so the vector keeps growth and the
  ;; check coupled. Member 0 is the field declarations, `#()` for a machine that
  ;; declares none, which is why a zero-field machine renders identically whatever
  ;; the ABI.
  ;;
  ;; The field declarations are (name . initial) pairs in SLOT ORDER: the slot is
  ;; the pair's POSITION, so one member determines both the values a fresh parser
  ;; starts from and the name-to-slot resolution parser-field-ref answers by, and
  ;; a second member would be a second ABI growth for data the first already
  ;; fixes.
  ;; byte-machine-make-compiled-machine : ExactInteger ExactInteger StateId Procedure (Vectorof Any) -> CompiledMachine
  (define (byte-machine-make-compiled-machine abi-version ir-fingerprint entry-state exec metadata)
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))
    ;; ONE length guard. A later minimum SUBSUMES every earlier one, so a chain
    ;; of per-member length guards is redundant -- only the LAST is
    ;; discriminating. `vector?` is NOT subsumed and stays in the same guard: it
    ;; must be refused before `vector-length` is applied at all.
    (unless (and (vector? metadata)
                 (>= (vector-length metadata) current-abi-members))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "metadata must carry every member this ABI defines"
                           metadata))
    (vector compiled-machine-tag 'v2 exec entry-state ir-fingerprint
            (vector-ref metadata 0) (vector-ref metadata 1)
            (vector-ref metadata 2)
            ;; The OPTIONAL fourth member: the settable table `#((name width) ...)`
            ;; a generated `make-parser` range-checks an override against
            ;; (Milestone 13). Present only when some field is settable, so absent
            ;; here means no field is settable and every override is refused; read
            ;; behind the length guard, not the required-member minimum above, so
            ;; a three-member payload stays legal.
            (if (>= (vector-length metadata) 4) (vector-ref metadata 3) '#())))

  ;; Tombstones. /v1 and /v2 stay exported so a stale generated file fails with a
  ;; clean ABI-mismatch assertion instead of an unbound-identifier import error,
  ;; and both refuse EVERY version rather than the one they are named for -- a
  ;; tombstone that still accepts a number is a hole.
  ;; byte-machine-make-compiled-machine/v1 : ExactInteger Any ... -> Void
  (define (byte-machine-make-compiled-machine/v1 abi-version . rest)
    (assertion-violation 'byte-machine-make-compiled-machine/v1
                         "retired generated-runtime ABI" abi-version))
  ;; byte-machine-make-compiled-machine/v2 : ExactInteger Any ... -> Void
  (define (byte-machine-make-compiled-machine/v2 abi-version . ignored)
    (assertion-violation 'byte-machine-make-compiled-machine/v2
                         "retired generated-runtime ABI (superseded by the unversioned constructor)"
                         abi-version))
  (define (compiled-machine-v2-exec cm) (vector-ref cm 2))
  (define (compiled-machine-v2-entry-state cm) (vector-ref cm 3))
  (define (compiled-machine-v2-fields cm) (vector-ref cm 5))
  ;; The optional fourth payload member: `#((name width) ...)` for the settable
  ;; fields, or `#()` when none (Milestone 13). What the generated lane's
  ;; make-parser resolves an embedder override against.
  (define (compiled-machine-v2-settable cm) (vector-ref cm 8))
  (define empty-bv (make-bytevector 0))

  ;; --- feed outcome (the runtime<-generated seam; accessors private) ---
  (define feed-outcome-tag (tag 'byte-machine-feed-outcome))
  ;; byte-machine-make-feed-outcome/v1 : FeedStatus ExactInteger (Option ParserError) StateId ExactInteger -> FeedOutcome
  (define (byte-machine-make-feed-outcome/v1 status next error next-state offset)
    (vector feed-outcome-tag status next error next-state offset))
  (define (feed-outcome-status o) (vector-ref o 1))
  (define (feed-outcome-next o) (vector-ref o 2))
  (define (feed-outcome-error o) (vector-ref o 3))
  (define (feed-outcome-next-state o) (vector-ref o 4))
  (define (feed-outcome-offset o) (vector-ref o 5))

  ;; --- parser result (immutable snapshot) ---
  (define parser-result-tag (tag 'byte-machine-parser-result))
  ;; `parser-result-next` and `parser-result-consumed` are meaningful for
  ;; feed-originated results only, and nothing enforces that: `parser-finish!`'s
  ;; paths call this constructor with `next` repeating the absolute stream offset
  ;; and `consumed` exactly 0. The record is opaque, so an internal origin slot
  ;; would not be a public change; distinguishing finish-originated results was
  ;; deferred on cost, since enforcing it re-baselines a tuple in most of the
  ;; differential programs.
  ;; The OPTIONAL `pause` slot (Milestone 12) carries a parser-error-shaped reason
  ;; for a paused result, and is #f otherwise; the error slot stays #f for a pause,
  ;; so a consumer that checks only the error slot still reads "not failed" (brief
  ;; §6). `case-lambda` keeps the 5-arg arity, so the many non-pause construction
  ;; sites -- including the span-callback pause arms and the flush -- are unchanged
  ;; and get `#f`.
  (define make-parser-result
    (case-lambda
      ((status next consumed stream-offset error)
       (make-parser-result status next consumed stream-offset error #f))
      ((status next consumed stream-offset error pause)
       (vector parser-result-tag status next consumed stream-offset error pause))))
  ;; parser-result? : Any -> Boolean
  (define (parser-result? x) (tagged? parser-result-tag x))
  ;; parser-result-status : ParserResult -> FeedStatus
  (define (parser-result-status r) (vector-ref r 1))
  ;; parser-result-next : ParserResult -> ExactInteger
  (define (parser-result-next r) (vector-ref r 2))
  ;; parser-result-consumed : ParserResult -> ExactInteger
  (define (parser-result-consumed r) (vector-ref r 3))
  ;; parser-result-stream-offset : ParserResult -> ExactInteger
  (define (parser-result-stream-offset r) (vector-ref r 4))
  ;; parser-result-error : ParserResult -> (Option ParserError)
  (define (parser-result-error r) (vector-ref r 5))
  ;; parser-result-pause : ParserResult -> (Option ParserError) -- the pause
  ;; reason (Milestone 12), #f for a non-pause result or a pause declaring none.
  ;; Length-guarded: a 6-element result predates the pause slot and has none, so
  ;; a value built before this ABI reads back #f rather than raising.
  (define (parser-result-pause r)
    (if (> (vector-length r) 6) (vector-ref r 6) #f))

  ;; --- parser error ---
  ;; Eight members, opaque.
  (define parser-error-tag (tag 'byte-machine-parser-error))
  ;; The reserved constructor generated code calls takes FIVE arguments, not
  ;; eight: an errs-table entry packing this declaration's code and reason, the
  ;; public source-node name, the state id, the absolute offset, and the position
  ;; kind. `domain` and `detail` are fixed here rather than passed, so no emitted
  ;; site ever writes them -- `machine` because these are machine errors, and #f
  ;; because detail is `#f` for machine errors. Their other values have exactly
  ;; one producer: the callback failure below.
  ;; byte-machine-make-parser-error/v1 : (Vector Symbol String) NodeName (U ExactInteger Symbol) ExactInteger PositionKind -> ParserError
  (define (byte-machine-make-parser-error/v1 entry node-name state-id offset position-kind)
    (vector parser-error-tag 'machine (vector-ref entry 0) (vector-ref entry 1) #f
            node-name state-id offset position-kind))
  ;; --- the callback domain ---------------------------------------------------
  ;; Two producers: an explicit callback failure, whose code and detail are the
  ;; APPLICATION's and pass through, and a return outside the declared outcomes,
  ;; for which the runtime mints the code below and whose detail is #f -- no
  ;; make-callback-failure call happened on that path, so nothing was
  ;; application-provided.
  ;;
  ;; `domain` is fixed HERE, exactly as `machine` is fixed in the constructor
  ;; above: no emitted site and no interpreter site writes it, so the two lanes
  ;; cannot disagree on it. The teeth are on code, node name, offset and position
  ;; kind.
  ;;
  ;; The REASON is one fixed printable-ASCII constant, identical in both lanes.
  ;; It is not derived from the code: on one of the two paths the code is the
  ;; application's, so a derived reason would put a symbol's external
  ;; representation into a behavioural contract.
  (define callback-error-reason "callback failure")
  (define callback-contract-code 'callback-contract-violation)
  ;; A zero-width machine action or callback failure reports `boundary` at the
  ;; current stream offset, always -- NOT the loop's carried-through `pk`, which
  ;; is `byte` whenever the invoking node was reached over a REEXECUTE edge. A
  ;; callback failure is not an error node: it has no author-chosen
  ;; advance/reexecute edge, so the position kind is fixed here rather than
  ;; carried.
  ;;
  ;; A NAME rather than a bare quoted symbol at its several sites: this is one
  ;; decision, and repeating the literal is a chance for a later change to miss a
  ;; site.
  (define callback-failure-position 'boundary)

  ;; byte-machine-make-callback-error/v1 : Symbol (Option Any) NodeName (U ExactInteger Symbol) ExactInteger PositionKind -> ParserError
  (define (byte-machine-make-callback-error/v1 code detail node-name state-id
                                               offset position-kind)
    (vector parser-error-tag 'callback code callback-error-reason detail
            node-name state-id offset position-kind))
  ;; parser-error? : Any -> Boolean
  (define (parser-error? x) (tagged? parser-error-tag x))
  ;; The interpreter's executor hands back (code reason node-name state-id); the
  ;; loop supplies the offset and the position kind, which only it knows. Both
  ;; lanes therefore build the same record from the same parts -- the generated
  ;; one through byte-machine-make-parser-error/v1 at each emitted site, this one
  ;; here.
  (define (parts->parser-error parts off kind)
    (byte-machine-make-parser-error/v1
     (vector (car parts) (cadr parts)) (caddr parts) (cadddr parts) off kind))
  ;; parser-error-domain : ParserError -> ErrorDomain
  (define (parser-error-domain e) (vector-ref e 1))
  ;; parser-error-code : ParserError -> Symbol
  (define (parser-error-code e) (vector-ref e 2))
  ;; parser-error-reason : ParserError -> String
  (define (parser-error-reason e) (vector-ref e 3))
  ;; parser-error-detail : ParserError -> (Option Any)
  (define (parser-error-detail e) (vector-ref e 4))
  ;; parser-error-node-name : ParserError -> NodeName
  (define (parser-error-node-name e) (vector-ref e 5))
  ;; parser-error-state-id : ParserError -> (U ExactInteger Symbol)
  (define (parser-error-state-id e) (vector-ref e 6))
  ;; parser-error-offset : ParserError -> ExactInteger
  (define (parser-error-offset e) (vector-ref e 7))
  ;; parser-error-position-kind : ParserError -> PositionKind
  (define (parser-error-position-kind e) (vector-ref e 8))

  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor entry current offset lifecycle stored-error
  ;;         field-values field-decls callbacks user-context active-span
  ;;         state-names span-mark span-data-slot span-delivered? field-initials)
  ;; lifecycle: ready | paused-feed | paused-finish | finish-ready | stopped |
  ;; error | finished | poisoned | busy. Sticky rows short-circuit at the
  ;; operation entry and synthesize the result tuple (next = the new call's start
  ;; for feed, the stream offset for finish; consumed = 0; stored offset/error)
  ;; without re-running the executor: idempotent re-execution broke on
  ;; default-EOF truncation, which parks `current` on a dispatch node.
  ;; stored-error (slot 7) is the error value the error row returns; #f
  ;; otherwise.
  ;;
  ;; field-values (slot 8) is a MUTABLE vector of exact integers indexed by slot;
  ;; field-decls (slot 9) is the IMMUTABLE (name . initial) vector the compiled
  ;; machine carries, in slot order; field-initials (slot 17, Milestone 13) is
  ;; the IMMUTABLE canonical merged initials -- the declared initials with the
  ;; make-parser embedder overrides applied, the source parser-reset! restores
  ;; slot 8 FROM. Three slots rather than one: they have different lifetimes and
  ;; owners -- the decls are per compiled machine and never written, the merged
  ;; initials per parser and never written after construction, the values per
  ;; parser and written constantly -- and parser-reset! restores slot 8 from slot
  ;; 17 (not slot 9), so an embedder-chosen mode survives a reset.
  ;;
  ;; The storage cannot live in the shared op/exec closure. That closure is built
  ;; once per compiled machine and every parser from it copies the same reference
  ;; into slot 2, and many parsers are built per compiled machine inside per-byte
  ;; loops, so closure-held storage would let one parser's writes be read by
  ;; another. Slot 9 is where the initials RIDE, because once a parser is built it
  ;; holds a reference to nothing else.
  (define parser-tag (tag 'byte-machine-parser))
  ;; --- callback binding resolution ------------------------------------------
  ;; "Callbacks are resolved once into indexed slots when the parser is
  ;; constructed. Generated hot paths never perform symbolic or alist lookup."
  ;; The slot vector is built HERE, once, and indexed thereafter.
  ;;
  ;; An UNBOUND OPTIONAL callback's slot holds `unbound-callback`, a sentinel the
  ;; invocation site short-circuits -- chosen on cost rather than observability,
  ;; because no witness distinguishes it from an installed closure (an unbound
  ;; callback has no application closure to record with).
  (define unbound-callback (vector 'byte-machine-unbound-callback))
  (define (unbound-callback? x) (eq? x unbound-callback))

  ;; `callback-bindings` is a proper list of two-element lists `(name
  ;; procedure)` -- TWO-ELEMENT LISTS, not pairs, so `(cadr b)` is the procedure.
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
    ;; Duplicate-binding rejection, before any resolution: a name bound twice is
    ;; a caller error whichever slot would have won.
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

  ;; --- embedder-chosen field initials (Milestone 13) ------------------------
  ;; A fresh copy of an integer vector. R6RS base has no `vector-copy`; the field
  ;; VALUES vector (slot 8) must be a copy of the canonical merged initials (slot
  ;; 17) so a parser's field writes never reach the restore source
  ;; `parser-reset!` reads.
  (define (copy-values v)
    (let* ((n (vector-length v)) (out (make-vector n 0)))
      (let loop ((i 0))
        (if (= i n) out (begin (vector-set! out i (vector-ref v i)) (loop (+ i 1)))))))
  ;; The slot of `name` in the `(name . initial)` decls, or #f -- the same
  ;; name->slot walk `parser-field-ref` does, so "unknown field" here means the
  ;; same thing it does there.
  (define (field-slot-of decls name)
    (let ((n (vector-length decls)))
      (let loop ((i 0))
        (cond ((>= i n) #f)
              ((eq? (car (vector-ref decls i)) name) i)
              (else (loop (+ i 1)))))))
  ;; The declared width of settable field `name`, or #f when `name` is not
  ;; settable. `settable` is the per-lane settable table -- a list of `(name
  ;; width)`; both lanes hand the same shape (the op lane asks the source
  ;; machine, the v2 lane reads ABI payload member 3).
  (define (settable-width settable name)
    (let loop ((s settable))
      (cond ((null? s) #f)
            ((eq? (car (car s)) name) (cadr (car s)))
            (else (loop (cdr s))))))
  ;; The merged initials: the declared initials, then each override applied to
  ;; its slot. An override naming an UNKNOWN field, a KNOWN-BUT-NOT-SETTABLE
  ;; field, a DUPLICATE name, or a value OUTSIDE the field's declared width is a
  ;; caller error -- each with a distinct code -- refused at CONSTRUCTION, so it
  ;; can never apply mid-parse (decision 0047 item 2, the reason a general
  ;; `parser-field-set!` is refused).
  (define (resolve-field-initials decls settable overrides)
    (unless (list? overrides)
      (byte-machine-contract-violation 'make-parser 'invalid-argument 'field-initials))
    (let ((values (initial-values decls)))
      (let loop ((os overrides) (seen '()))
        (cond
          ((null? os) values)
          (else
           (let ((o (car os)))
             (unless (and (pair? o) (symbol? (car o))
                          (integer? (cdr o)) (exact? (cdr o)))
               (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                'field-initials))
             (let ((name (car o)) (val (cdr o)))
               (when (memq name seen)
                 (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                  'duplicate-field-initial))
               (let ((slot (field-slot-of decls name)))
                 (unless slot
                   (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                    'unknown-field))
                 (let ((w (settable-width settable name)))
                   (unless w
                     (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                      'non-settable-field))
                   (unless (and (<= 0 val) (<= val (- (expt 2 w) 1)))
                     (byte-machine-contract-violation 'make-parser 'invalid-argument
                                                      'field-initial-out-of-range))
                   (vector-set! values slot val)))
               (loop (cdr os) (cons name seen)))))))))

  ;; make-parser : CompiledMachine (Listof (List Symbol Procedure)) Any [(Listof (Pair Symbol ExactInteger))] -> Parser
  ;; The OPTIONAL fourth argument overrides the DECLARED initials of SETTABLE
  ;; fields (Milestone 13), so two parsers from one machine can start in two
  ;; modes. `case-lambda` keeps the 3-arg arity, so no existing caller changes.
  ;; The merged initials are stored canonically in slot 17, a COPY is the working
  ;; field-values (slot 8), and `parser-reset!` restores slot 8 from slot 17 --
  ;; so a reset returns the parser to its just-constructed state INCLUDING the
  ;; embedder's mode (decision 0047 item 3).
  (define make-parser
    (case-lambda
      ((compiled-machine callback-bindings user-context)
       (make-parser compiled-machine callback-bindings user-context '()))
      ((compiled-machine callback-bindings user-context field-initials)
       (unless (compiled-machine? compiled-machine)
         (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
       (cond
         ;; The two arms reach the declarations AND the settable table by the
         ;; SHIPPED per-lane asymmetry: the interpreter holds the verified source
         ;; machine and is asked (`field-initials`, `settable-fields`); the
         ;; generated lane holds only what the ABI payload carried and reads
         ;; member 0 and the optional member 3. There is nothing both could
         ;; consult.
         ((eq? (compiled-machine-variant compiled-machine) 'op)
          (let* ((op (vector-ref compiled-machine 2)) (entry (op 'entry))
                 (decls (op 'field-initials))
                 (merged (resolve-field-initials decls (op 'settable-fields)
                                                 field-initials)))
            (vector parser-tag 'op op entry entry 0 'ready #f
                    (copy-values merged) decls
                    (resolve-callbacks (op 'callback-decls) callback-bindings)
                    user-context #f #f 0 #f #f merged)))
         ((eq? (compiled-machine-variant compiled-machine) 'v2)
          (let* ((exec (compiled-machine-v2-exec compiled-machine))
                 (entry-state (compiled-machine-v2-entry-state compiled-machine))
                 (decls (compiled-machine-v2-fields compiled-machine))
                 (merged (resolve-field-initials
                          decls
                          (vector->list (compiled-machine-v2-settable compiled-machine))
                          field-initials)))
            (vector parser-tag 'v2 exec entry-state entry-state 0 'ready #f
                    (copy-values merged) decls
                    (resolve-callbacks (compiled-machine-v2-callbacks compiled-machine)
                                       callback-bindings)
                    user-context #f
                    (compiled-machine-v2-state-names compiled-machine) 0 #f #f merged)))
         ;; Unreachable through the public API: the only two constructors build
         ;; 'op and 'v2. Kept LOUD rather than deleted, the same convention as
         ;; compile.sls's and normal-ir.sls's own unreachable else arms.
         (else (assertion-violation 'make-parser "unknown compiled-machine variant"
                                    (compiled-machine-variant compiled-machine)))))))
  ;; parser? : Any -> Boolean
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-variant p) (vector-ref p 1))
  (define (parser-executor p) (vector-ref p 2))
  (define (parser-entry p) (vector-ref p 3))
  (define (parser-current p) (vector-ref p 4))
  (define (parser-set-current! p v) (vector-set! p 4 v))
  (define (parser-offset p) (vector-ref p 5))
  (define (parser-set-offset! p v) (vector-set! p 5 v))
  ;; parser-lifecycle : Parser -> LifecycleState
  (define (parser-lifecycle p) (vector-ref p 6))
  (define (parser-set-lifecycle! p v) (vector-set! p 6 v))
  (define (parser-stored-error p) (vector-ref p 7))
  (define (parser-set-stored-error! p v) (vector-set! p 7 v))
  (define (parser-field-values p) (vector-ref p 8))
  (define (parser-field-decls p) (vector-ref p 9))
  ;; Slots 10-12: the callback slot vector, the application's opaque context
  ;; (application-owned and may be mutable, so the runtime neither copies nor
  ;; interprets it), and the active span's name or #f. `parser-active-span`
  ;; answers in BOTH lanes because a span is bookkeeping the runtime owns, not a
  ;; generated state -- unlike `parser-state-name`, which must name a source node
  ;; and so needs the id->name table the generated lane carries in slot 13.
  (define (parser-callbacks p) (vector-ref p 10))
  ;; parser-user-context : Parser -> Any
  (define (parser-user-context p) (vector-ref p 11))
  ;; parser-active-span : Parser -> (Option Symbol)
  (define (parser-active-span p) (vector-ref p 12))
  ;; Slot 13: ABI payload member 2's state-id to source-name vector, or #f in the
  ;; interpreted lane, which is ASKED instead. The same per-lane asymmetry the
  ;; field table and the callback declarations use -- the interpreter holds the
  ;; verified source machine, the generated lane holds only what the payload
  ;; carried.
  (define (parser-state-names p) (vector-ref p 13))
  ;; Slots 14 and 15, beside slot 12. The three are one piece of span state and
  ;; are named apart because they have different lifetimes -- the NAME is what
  ;; `parser-active-span` answers, the MARK is a slice offset re-anchored every
  ;; feed, and the SLOT is what the boundary flush needs to reach the data
  ;; callback without consulting the machine, which it cannot do: the flush runs
  ;; in `parser-feed!` and the two lanes reach their declarations by different
  ;; routes.
  (define (parser-span-mark p) (vector-ref p 14))
  (define (parser-set-span-mark! p v) (vector-set! p 14 v))
  (define (parser-span-data-slot p) (vector-ref p 15))
  (define (parser-set-span-data-slot! p v) (vector-set! p 15 v))
  (define (parser-set-active-span! p v) (vector-set! p 12 v))
  ;; Slot 16, the fourth piece of span state: whether the active span has
  ;; delivered ANY fragment yet. Inited #f by make-parser, reset #f by
  ;; span-close beside slots 12/14/15, set on every delivery. A span END reads it to decide whether an
  ;; empty final fragment is the span's ONLY fragment (deliver once) or the empty
  ;; tail of a span whose bytes already went (suppress) -- decision 0042.
  (define (parser-span-delivered? p) (vector-ref p 16))
  (define (parser-set-span-delivered?! p v) (vector-set! p 16 v))
  ;; Slot 17 (Milestone 13): the CANONICAL merged field initials -- the declared
  ;; initials with the `make-parser` embedder overrides applied. Immutable: the
  ;; working field-values (slot 8) is a COPY of it, and `parser-reset!` restores
  ;; slot 8 from it, so a reset returns the parser to its just-constructed state
  ;; INCLUDING the embedder's mode. Equals the declared initials when no override
  ;; was given, so a reset with no override is exactly the pre-M13 behaviour.
  (define (parser-field-initials p) (vector-ref p 17))
  ;; The absolute offset, which the parser already tracks; this is the public
  ;; name for it, and it is one of the values committed before a callback sees
  ;; the parser.
  ;; parser-stream-offset : Parser -> ExactInteger
  (define (parser-stream-offset p) (parser-offset p))
  ;; Requires the SOURCE node name, "not a generated internal continuation", so
  ;; the generated lane reads member 2's table -- which is total over internal
  ;; prefix states, each answering with its declaring node's public name.
  ;;
  ;; A bare symbol, always: this is deliberately not widened to a compound for
  ;; the feed-boundary case, because no caller can predict which calls would
  ;; return the compound. The active span is `parser-active-span`.
  ;; parser-state-name : Parser -> NodeName
  (define (parser-state-name parser)
    (unless (parser? parser)
      (byte-machine-contract-violation 'parser-state-name 'invalid-argument parser))
    (case (parser-variant parser)
      ((op) ((parser-executor parser) 'state-name (parser-current parser)))
      ;; `current` is a state id, or the compound (state-id . path) while a parser
      ;; is parked mid keyword-table (decision 0044); index by the id either way,
      ;; as the interpreter's own `state-name` message unwraps the pair.
      ((v2) (let ((c (parser-current parser)))
              (vector-ref (parser-state-names parser) (if (pair? c) (car c) c))))
      ;; Unreachable for the same reason make-parser's own else arm is.
      (else (assertion-violation 'parser-state-name "unknown parser variant"
                                 (parser-variant parser)))))

  ;; --- callback failure ------------------------------------------------------
  ;; An explicit callback failure containing an application code and optional
  ;; detail. The code must satisfy the same portable ASCII name grammar as
  ;; everything else symbolic; the detail is opaque application data and is never
  ;; emitted.
  ;;
  ;; Allocation here is deliberate and licensed: the SUCCESSFUL outcomes are
  ;; allocation-free singletons, but error detail allocation is allowed on the
  ;; exceptional path.
  (define callback-failure-tag (tag 'byte-machine-callback-failure))
  ;; TYPE AND GRAMMAR both checked here. The code must satisfy the portable ASCII
  ;; name grammar, checked with `portable-name?` from (byte-machine private
  ;; names) -- the one body verify.sls and compile.sls check declared names and
  ;; output bindings against. The runtime is downstream of verification and must
  ;; not import verify.sls, so the shared predicate lives in the names library.
  ;; No reserved set applies here -- a callback code is never emitted as an
  ;; identifier (the detail stays unemitted and the code travels as a datum), so
  ;; the grammar is the whole of the requirement at this site.
  ;; make-callback-failure : Symbol (Option Any) -> CallbackFailure
  (define (make-callback-failure code detail)
    (unless (and (symbol? code) (portable-name? code))
      (byte-machine-contract-violation 'make-callback-failure 'invalid-argument 'code))
    (vector callback-failure-tag code detail))
  ;; callback-failure? : Any -> Boolean
  (define (callback-failure? x) (tagged? callback-failure-tag x))
  ;; callback-failure-code : CallbackFailure -> Symbol
  (define (callback-failure-code f) (vector-ref f 1))
  ;; callback-failure-detail : CallbackFailure -> (Option Any)
  (define (callback-failure-detail f) (vector-ref f 2))

  ;; --- the callback seam, shared by both lanes -------------------------------
  ;; The callback outcomes, classified in one place. The emitted arm and
  ;; `parser-feed-op!`'s arm both call this, so neither lane can invent its own
  ;; vocabulary. The lanes differ only in what a TARGET is (a node name here, a
  ;; state id there), and this procedure never looks inside one.
  ;;
  ;; Event and span callbacks accept only continue, pause, or failure; decision
  ;; callbacks may additionally return their declared branch keys. An event node
  ;; declares no branch targets at all, and a decision node declares exactly its
  ;; admissible keys -- so "does the returned symbol name a declared branch of
  ;; THIS node" answers both, out of data both lanes already carry, and no
  ;; callback KIND has to cross the seam.
  ;;
  ;; The unbound-optional short circuit reads the sentinel installed at
  ;; resolution and the closure is NEVER called.
  ;;
  ;; Answers one of:
  ;;   (goto TARGET)          -- continue, a declared branch, or the default
  ;;   (pause)                -- park on the node's pause continuation
  ;;   (failure CODE DETAIL)  -- the stored callback-domain error
  ;;
  ;; A span-data callback takes five arguments where every other kind takes two,
  ;; so the invocation cannot be shared -- but the CLASSIFICATION can and must,
  ;; since callback results are compared across lanes and must be produced by
  ;; both lanes from the same construction. A widened rest-arg was rejected: it
  ;; would put the arity decision inside the classifier, where neither lane can
  ;; see which kind it holds.
  (define (classify-callback-result r branches continue)
    (cond ((eq? r callback-continue) (list 'goto continue))
          ((eq? r callback-pause) (list 'pause))
          ((callback-failure? r)
           (list 'failure (callback-failure-code r) (callback-failure-detail r)))
          ((and (symbol? r) (assq r branches))
           => (lambda (hit) (list 'goto (cdr hit))))
          (else (list 'failure callback-contract-code #f))))

  ;; Commits `current` and the offset BEFORE invoking, because at callback entry
  ;; both lanes must expose identical committed parser state: the stream offset
  ;; includes every byte committed before the callback, and the public parser
  ;; state names the source callback/span node. In the interpreted lane both are
  ;; already true when this is called. In the GENERATED lane neither is: `exec`
  ;; owns its own `pos`/`off`/`st` locals and the parser's slots are only written
  ;; when `exec` RETURNS, so without these two lines `parser-stream-offset`
  ;; answers the offset at the start of the feed and `parser-state-name` answers
  ;; the state the feed started in. The emitted arm passes its own `st` and
  ;; `off`; the interpreted arm passes the values already there, so the writes
  ;; are no-ops on that side. Both entry points call this rather than writing the
  ;; two lines themselves.
  (define (callback-commit! parser state offset)
    (parser-set-current! parser state)
    (parser-set-offset! parser offset))

  ;; byte-machine-callback-step/v1 : Parser (U NodeName StateId) ExactInteger (U Procedure Unbound) (Listof (Pair Symbol (U NodeName StateId))) (U NodeName StateId) (U NodeName StateId) -> (U (List 'goto (U NodeName StateId)) (List 'pause) (List 'failure Symbol (Option Any)))
  (define (byte-machine-callback-step/v1 parser state offset f branches continue default)
    (callback-commit! parser state offset)
    (if (unbound-callback? f)
        ;; An optional decision callback must declare `default-branch`; other
        ;; optional callbacks default to `continue`. Both are resolved to a
        ;; TARGET at lowering time, so this arm is one jump and carries no rule of
        ;; its own.
        (list 'goto default)
        (classify-callback-result (f parser (parser-user-context parser))
                                  branches continue)))

  ;; --- the span runtime ------------------------------------------------------
  ;;
  ;; Span state is a NAME, a MARK and the data callback's SLOT -- never a
  ;; bytevector. The mark is re-anchored at every feed boundary, so it is a SLICE
  ;; offset and never has to mean anything between feeds; that is what keeps "no
  ;; bytevector field in parser storage" structurally true rather than merely
  ;; observed.
  ;; byte-machine-span-open/v1 : Parser Symbol ExactInteger ExactInteger -> Void
  (define (byte-machine-span-open/v1 parser name mark data-slot)
    (parser-set-active-span! parser name)
    (parser-set-span-mark! parser mark)
    (parser-set-span-data-slot! parser data-slot))

  ;; byte-machine-span-close/v1 : Parser -> Void
  (define (byte-machine-span-close/v1 parser)
    (parser-set-active-span! parser #f)
    (parser-set-span-mark! parser 0)
    (parser-set-span-data-slot! parser #f)
    ;; The delivered? flag resets to #f beside the other three span slots, so a
    ;; prior span's "has delivered" state cannot leak into the next span opened on
    ;; the same parser (decision 0042). This is the flag's ONLY reset -- span-open
    ;; does not touch it, so a mutation deleting this line leaves the flag stale
    ;; across spans, caught where two spans run on one parser (the property
    ;; coverage machine's covx→covy). make-parser inits the slot to #f, so the
    ;; first span needs no reset; and it transitively covers parser-reset! and both
    ;; completion arms exactly as slots 12/14/15 are covered.
    (parser-set-span-delivered?! parser #f))

  ;; TWO ENTRY POINTS DELIVER EVERY SPAN FRAGMENT, over ONE delivery helper, and
  ;; the difference between them is the whole of Milestone 10 (decision 0042).
  ;; Every span END goes through `byte-machine-span-fragment-step/v1` -- the
  ;; feed-loop span-end, the emitted arm, AND the EOF-side span end. The generated
  ;; lane reaches all three through that one emitted arm, because
  ;; `parser-finish-v2!` runs `exec` with `finish?` at cursor 0, so the
  ;; interpreter matches by routing its EOF span-end here too rather than to a
  ;; suppress-only path -- keeping the emitted text unchanged. The feed-boundary
  ;; FLUSH, and only it, goes through `span-fragment-suppress-empty`. Both deliver
  ;; a NONEMPTY `[from,to)` identically; they differ only on an EMPTY one.
  ;;
  ;; A span END delivers an empty fragment ONCE, when the span has delivered
  ;; nothing at all (`from == to`, flag clear) -- so a span that opens and closes
  ;; having produced no bytes is observable, its data callback firing once with an
  ;; empty range (§14:831 as amended by decision 0042). It SUPPRESSES an empty
  ;; fragment in two shapes. `from == to` with the flag SET: the empty FINAL
  ;; fragment of a span that already delivered -- a span split across feeds, whose
  ;; bytes were flushed and whose mark was re-anchored to the next slice's `start`,
  ;; then ends on that slice's first byte -- where announcing "empty" would be a
  ;; lie. (`from > to` is not reachable: a feed span end has mark <= cursor, and an
  ;; EOF span end has mark 0 because `parser-finish!` re-anchors it there -- so
  ;; EVERY empty span, whether it opens on the EOF chain or is carried from a feed,
  ;; ends with `from == to` and is announced once, uniformly (decision 0042
  ;; item 4). The `else` still guards `from > to` as defence.) Emptiness is a
  ;; property of the SPAN, not the fragment; `parser-span-delivered?` (slot 16,
  ;; inited #f and reset by
  ;; span-close, set on every delivery) is the per-span state that tells the deliver-once case
  ;; from the split-span suppression, and it survives pause/resume because it is
  ;; set BEFORE the callback runs and resume parks on the substep PAST the delivery.
  ;;
  ;; The FLUSH suppresses every empty fragment unconditionally: it is not a span
  ;; end -- an empty flush means "no new bytes this slice" and the span stays open,
  ;; so a delivery there would announce empty for a span still being built.
  ;;
  ;; NEITHER ENTRY POINT ADVANCES THE MARK, and that is measured rather than
  ;; assumed. The data callback is specified to see "its mark advanced to the
  ;; current cursor", and an advance was written here first; deleting it fails
  ;; nothing, in either lane. The reason is a construction: every path out of a
  ;; delivery either CLOSES the span (the completion substep sets the mark to 0)
  ;; or crosses a feed boundary, where the re-anchor overwrites the mark with the
  ;; next slice's `start`. There is no third path, and no public accessor reads the
  ;; mark, so nothing can observe the value between the two -- the "mark advanced"
  ;; sentence is discharged by the feed-boundary re-anchor, which is where the
  ;; re-anchoring lives entirely.
  ;;
  ;; The five-argument application is the ONLY thing `span-fragment-deliver!` does
  ;; differently from the two-argument entry point above. `branches` is '() because
  ;; a span callback gets only continue, pause and failure -- the branch arm is dead
  ;; for spans rather than absent, which is what keeps ONE classifier.
  (define (span-fragment-deliver! parser state offset f bv from to continue)
    (parser-set-span-delivered?! parser #t)
    (callback-commit! parser state offset)
    (classify-callback-result
     (f parser (parser-user-context parser) bv from to)
     '() continue))

  ;; byte-machine-span-fragment-step/v1 : Parser (U NodeName StateId) ExactInteger (U Procedure Unbound) Bytevector ExactInteger (U NodeName StateId) -> (U (List 'goto (U NodeName StateId)) (List 'pause) (List 'failure Symbol (Option Any)))
  (define (byte-machine-span-fragment-step/v1 parser state offset f bv to continue)
    (let ((from (parser-span-mark parser)))
      (cond ((unbound-callback? f) (list 'goto continue))
            ;; Real bytes.
            ((< from to)
             (span-fragment-deliver! parser state offset f bv from to continue))
            ;; The span's ONLY fragment, empty (`from == to`, nothing delivered
            ;; yet): deliver it once so the empty span is observable.
            ((and (= from to) (not (parser-span-delivered? parser)))
             (span-fragment-deliver! parser state offset f bv from to continue))
            ;; Suppress. Two shapes reach here: `from == to` with the flag SET --
            ;; the empty FINAL fragment of a span that already delivered (a span
            ;; split across feeds, its bytes flushed and the mark re-anchored). The
            ;; `from > to` case is not reachable -- feed marks are <= the cursor and
            ;; `parser-finish!` re-anchors EOF marks to 0 (decision 0042 item 4) --
            ;; so this arm suppresses only the flag-set final fragment; guarding the
            ;; backwards range is defence, not a live path.
            (else (list 'goto continue)))))

  ;; The feed-boundary flush -- and only it. A nonempty fragment is delivered
  ;; exactly as above; an empty one is ALWAYS suppressed, because the flush is not
  ;; a span end and the span stays open. Not emitted -- generated code only ever
  ;; reaches the span-end entry point above (its own boundary flush lives in
  ;; `parser-feed!`, this runtime, not in `exec`).
  (define (span-fragment-suppress-empty parser state offset f bv to continue)
    (let ((from (parser-span-mark parser)))
      (if (or (>= from to) (unbound-callback? f))
          (list 'goto continue)
          (span-fragment-deliver! parser state offset f bv from to continue))))

  ;; The resumable keyword-table walk (decision 0044). The keyword-table node
  ;; lowers to ONE emitted arm that embeds its entries as data and calls this,
  ;; rather than to a trie of dispatch states -- which is what makes 47 keywords a
  ;; table, not 242 states, and is the whole point of the construct.
  ;;
  ;; `entries` is a list of (byte-list . target-id) with proper prefixes
  ;; permitted; `no-match` a (target-id . mode) pair; `path` the bytes already
  ;; consumed -- empty on fresh entry, the parked prefix on resume from a compound
  ;; `current`. It walks [pos,end) greedily forward with NO backtracking: while the
  ;; next byte extends toward some keyword it is consumed; at the first byte that
  ;; does not, PATH's keyword is taken if PATH is one (the delimiter left unread,
  ;; so a span closes at the keyword's length), else the no-match route. Answers
  ;;   (jump target new-pos pk)  -- a decision reached; the arm loops to `target`
  ;;   (need new-path new-pos)   -- the feed ran out mid-table; the arm parks the
  ;;                                compound (state-id . new-path) and returns
  ;;                                need-input, or takes the eof route under finish?.
  ;; `ci?` folds ASCII case per table (decision 0045). Written twice on purpose --
  ;; the interpreter's own fold is separate, so a fold defect is a differential
  ;; result rather than a hidden agreement.
  (define (kw-fold b ci?) (if (and ci? (>= b 65) (<= b 90)) (+ b 32) b))
  (define (kw-prefix? ci? p bs)
    (cond ((null? p) #t)
          ((null? bs) #f)
          ((= (kw-fold (car p) ci?) (kw-fold (car bs) ci?)) (kw-prefix? ci? (cdr p) (cdr bs)))
          (else #f)))
  ;; byte-machine-keyword-step/v1 : (Listof (Pair (Listof Byte) StateId)) (Pair StateId EdgeMode) Boolean (Listof Byte) Bytevector ExactInteger ExactInteger -> (U (List 'jump StateId ExactInteger Symbol) (List 'need (Listof Byte) ExactInteger))
  (define (byte-machine-keyword-step/v1 entries no-match ci? path bv pos end)
    (let walk ((p path) (i pos))
      (if (>= i end)
          (list 'need p i)
          (let ((np (append p (list (bytevector-u8-ref bv i)))))
            (if (exists (lambda (e) (kw-prefix? ci? np (car e))) entries)
                (walk np (+ i 1))
                (let ((term (let seek ((es entries))
                              (cond ((null? es) #f)
                                    ((and (= (length (car (car es))) (length p))
                                          (kw-prefix? ci? p (car (car es))))
                                     (car es))
                                    (else (seek (cdr es)))))))
                  (cond (term (list 'jump (cdr term) i (quote byte)))
                        ((eq? (cdr no-match) (quote advance))
                         (list 'jump (car no-match) (+ i 1) (quote boundary)))
                        (else (list 'jump (car no-match) i (quote byte))))))))))

  ;; The boundary flush. It runs at the ONE seam both lanes cross -- after the
  ;; executor has answered and before `parser-feed!` records the lifecycle --
  ;; because the emitted `exec` has nowhere to put it: its `need-input` return is
  ;; rendered inline and returns immediately.
  ;;
  ;; *** ONLY ON `need-input`, and every other status has a reason rather than an
  ;; omission. ***
  ;;   error     -- a final partial fragment is forbidden outright.
  ;;   stopped   -- reaching either with a span active is a VERIFIER rejection
  ;;   finished     (`span-active-at-exit`), so neither is reachable.
  ;;   paused    -- a feed that exits `paused` leaves the span active with the
  ;;                fragment the span end has just delivered; nothing advances the
  ;;                mark (see the fragment step above), so an arm here would not
  ;;                be inert -- it would DELIVER THAT FRAGMENT A SECOND TIME,
  ;;                against "it is never delivered twice". The row is omitted
  ;;                because a flush there is WRONG, not because it would do
  ;;                nothing -- and the difference matters, because "a guard that
  ;;                cannot fire" is this project's standing invitation to add the
  ;;                guard.
  (define (span-boundary-flush! parser bv r)
    (if (and (eq? (parser-result-status r) 'need-input)
             (parser-active-span parser))
        (let ((o (span-fragment-suppress-empty
                  parser (parser-current parser) (parser-offset parser)
                  (vector-ref (parser-callbacks parser)
                              (parser-span-data-slot parser))
                  bv (parser-result-next r)
                  ;; No target: a flush is not a machine step. The span stays
                  ;; open and the parser parked exactly where the executor left
                  ;; it, so the `goto` payload is discarded below.
                  #f)))
          (case (car o)
            ((goto) r)
            ;; The fragment is committed, the span remains open, and resume
            ;; begins with the next supplied input. Committed means not delivered
            ;; again, which the re-anchor on the NEXT feed guarantees; this arm
            ;; only changes what the feed REPORTS, keeping the resume state the
            ;; executor chose.
            ((pause) (make-parser-result 'paused (parser-result-next r)
                                         (parser-result-consumed r)
                                         (parser-offset parser) #f))
            ;; The node name is asked for rather than passed: `parser-state-name`
            ;; answers the source node in BOTH lanes (member 2's table on one
            ;; side, the executor on the other), and a flush has no state id of
            ;; its own -- the id is excluded from the comparison but an integer is
            ;; still required, and the data callback's slot is the integer that
            ;; actually identifies this invocation.
            ;;
            ;; `boundary`: the flush happens with the slice exhausted, which is a
            ;; byte boundary by definition.
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

  ;; parser-feed! : Parser Bytevector ExactInteger ExactInteger -> ParserResult
  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    ;; The three sticky arms below, and parser-finish!'s, are deliberately not
    ;; factored into a shared helper even though each pair is near-identical:
    ;; each arm is a distinct row of the operation matrix with its own decision,
    ;; and a shared helper would collapse them onto one site.
    (case (parser-lifecycle parser)
      ((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation
                                        (list (parser-lifecycle parser) 'feed)))
      ((stopped) (make-parser-result 'stopped start 0 (parser-offset parser) #f))
      ((error) (make-parser-result 'error start 0 (parser-offset parser)
                                   (parser-stored-error parser)))
      ((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))
      ;; The busy and poisoned rows. THREE distinct codes -- lifecycle violation,
      ;; reentrancy, poisoned parser: a caller who fed a paused parser made a
      ;; sequencing mistake, a callback that fed the parser it is running inside
      ;; made a reentrancy mistake, and a caller who fed a parser an escaped
      ;; callback left behind is holding something only reset can reuse.
      ((busy)
       (byte-machine-contract-violation 'parser-feed! 'reentrancy
                                        (list (parser-lifecycle parser) 'feed)))
      ((poisoned)
       (byte-machine-contract-violation 'parser-feed! 'poisoned-parser
                                        (list (parser-lifecycle parser) 'feed)))
      ;; `ready` is an explicit arm and the else is LOUD. If `ready` were the
      ;; `else`, every lifecycle value this case did not name would execute input
      ;; -- so a lifecycle value added later (a poisoned parser, say) would
      ;; silently RE-EXECUTE instead of raising, with no exhaustiveness check to
      ;; catch it.
      ((ready)
       ;; `busy` is an internal guard while feed, finish, or a callback is
       ;; executing. Set BEFORE the executor runs, which is what makes the
       ;; reentrancy arm above reachable at all -- a callback calling back into
       ;; this parser meets it -- and what makes the lifecycle a callback observes
       ;; `busy`.
       ;; An open span begins its next possible fragment at the next feed's
       ;; `start`. The mark is a SLICE offset, so it means nothing in a slice it
       ;; did not come from -- re-anchoring HERE is what lets it be one, and a
       ;; slice offset is what keeps "no bytevector field in parser storage"
       ;; structurally true rather than merely observed.
       (parser-set-lifecycle! parser 'busy)
       (when (parser-active-span parser)
         (parser-set-span-mark! parser start))
       (let ((completed #f))
         (dynamic-wind
           (lambda () #t)
           (lambda ()
             ;; The flush is INSIDE the wind: it runs application code, so a
             ;; callback that escapes from it must poison the parser exactly as
             ;; one escaping from the executor does.
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
                 ;; arm rather than a fall-through: a fall-through would leave the
                 ;; lifecycle at `busy` forever.
                 ((need-input) (parser-set-lifecycle! parser 'ready))
                 (else (assertion-violation 'parser-feed! "unknown result status"
                                            (parser-result-status r))))
               (set! completed #t)
               r))
           ;; If a callback raises an unexpected condition or performs a nonlocal
           ;; escape, the condition/escape propagates and `dynamic-wind` marks the
           ;; parser poisoned. The flag is what tells the two apart -- this thunk
           ;; runs on BOTH exits, and only the abnormal one leaves it false.
           ;; Nothing is caught here: the condition propagates.
           (lambda ()
             (unless completed (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-feed! "unknown lifecycle"
                                 (parser-lifecycle parser)))))

  ;; The interpreter path. Sticky rows short-circuit one level up in
  ;; parser-feed!, so this loop no longer serves repeat feeds on a terminal
  ;; parser -- it is reached only while the lifecycle is 'ready, and runs a
  ;; single live dispatch walk from `current` to its next stop/error/finish/
  ;; pause.
  (define (parser-feed-op! parser bv start end)

      ;; Route a byte-consuming step: park `current` on the target, then either
      ;; consume the byte and continue at a boundary, or leave it for whatever
      ;; comes next and report `byte` -- AT the offending byte, which is what
      ;; makes an overflow report where it happened.
      ;;
      ;; Shared by the dispatch arm and the accumulate arm: once the op has
      ;; answered the two arms genuinely do the same thing. Each arm's CALL stays
      ;; its own line, and what differs between them -- which op message, and what
      ;; it is given -- stays there.
      (define (route-byte-step! target mode pos loop)
        (parser-set-current! parser target)
        (if (eq? mode 'advance)
            (begin
              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop (+ pos 1) 'boundary))
            (loop pos 'byte)))
    (let ((op (parser-executor parser)))
      ;; The position kind is a loop variable, set from a literal at each jump,
      ;; initialized `boundary` unconditionally with no finish? key: nothing has
      ;; been consumed since the call began, so an error state reached with no
      ;; jump taken is a boundary at the current offset.
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
             ;; Commit current PAST the pause -- the resumed feed re-enters at the
             ;; continuation, mirroring the generated next-state.
             ;; The OPTIONAL reason (M12) rides the PAUSE slot, built from the same
             ;; parts (code reason node-name state-id) an error node produces, over
             ;; the loop's `pk`; the error slot stays #f. #f when the pause declares
             ;; no reason.
             (parser-set-current! parser (op 'pause-target node))
             (make-parser-result 'paused pos (- pos start) (parser-offset parser) #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))
            ;; ZERO-WIDTH kinds. They consume no byte, so the loop re-enters at
            ;; the SAME `pos` with the same offset, and the only state that moves
            ;; is `current` plus whatever the op committed into the field vector.
            ;; The op does the bound check and the write; this arm only routes.
            ;;
            ;; `pk` is carried THROUGH unchanged rather than reset. Position kind
            ;; describes where in the input stream the parser is, and a zero-width
            ;; step does not move it -- so a failure reached after one reports the
            ;; same kind it would have reported without it. Position kind is
            ;; differential-compared, so the two lanes must agree on this and the
            ;; emitter carries the same rule.
            ((field-action field-branch)
             (let ((t (op 'field-step node (parser-field-values parser))))
               (parser-set-current! parser t)
               (loop pos pk)))
            ;; The callback kind, the first arm in this loop that runs
            ;; APPLICATION code. Zero-width like the two above, so `pos` and the
            ;; offset are carried through unchanged, and `pk` is carried for the
            ;; LOOP but is NOT what the error records: the failure arm below
            ;; records `callback-failure-position` (a boundary at the current
            ;; stream offset) rather than `pk`, which would be `byte` whenever
            ;; this node was entered over a REEXECUTE edge. See the note beside
            ;; `byte-machine-make-callback-error/v1`.
            ;;
            ;; The parts are (slot continue branches pause default state-id) and
            ;; the vocabulary lives in `byte-machine-callback-step/v1`, which the
            ;; emitted arm calls too.
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
                 ;; A callback-requested pause occurs after the callback's
                 ;; delivered event has been committed. Resume continues after
                 ;; that event; it is never delivered twice. So `current` is
                 ;; parked PAST the invocation, on the declared pause continuation.
                 ((pause)
                  (parser-set-current! parser (cadddr parts))
                  ;; The OPTIONAL callback-pause reason (M12), the SECOND
                  ;; author-facing pause path. Built with `callback-failure-position`
                  ;; (boundary) -- a callback outcome reports boundary, as the
                  ;; failure arm below does -- and routed to the PAUSE slot, not the
                  ;; error slot. #f when the callback node declares no reason.
                  (make-parser-result 'paused pos (- pos start)
                                      (parser-offset parser) #f
                    (let ((rp (op 'pause-reason node)))
                      (and rp (parts->parser-error rp (parser-offset parser)
                                                   callback-failure-position)))))
                 (else
                  (make-parser-result 'error pos (- pos start) (parser-offset parser)
                                      (byte-machine-make-callback-error/v1
                                       (cadr o) (caddr o) node (list-ref parts 5)
                                       (parser-offset parser) callback-failure-position))))))
            ;; The span kinds, and the interpreter's own arm for the completion
            ;; substep. All three are zero-width, so `pos`, the offset and `pk`
            ;; carry through unchanged, exactly as the callback arm's do.
            ((span-start)
             ;; Starting a span records the current cursor. `pos` is the slice
             ;; index, which is what a mark IS.
             (let ((parts (op 'span-start-parts node)))
               (byte-machine-span-open/v1 parser (car parts) pos (cadr parts))
               (parser-set-current! parser (caddr parts))
               (loop pos pk)))
            ((span-end)
             ;; The remaining fragment, with the mark advanced to the cursor first
             ;; and the empty one suppressed -- all inside the step, so this arm
             ;; only routes.
             ;;
             ;; TWO substeps, not one: resume is "at the next undelivered
             ;; substep", so the fragment's continuation is the substep below and
             ;; never the node's own successor.
             (let* ((parts (op 'span-end-parts node))
                    (o (byte-machine-span-fragment-step/v1
                        parser node (parser-offset parser)
                        (vector-ref (parser-callbacks parser) (car parts))
                        bv pos (cadr parts))))
               (case (car o)
                 ((goto)
                  (parser-set-current! parser (cadr o))
                  (loop pos pk))
                 ;; The never-delivered-twice rule again, and the fragment is
                 ;; committed: the park is PAST the delivery, on the substep that
                 ;; has not run.
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
             ;; Before invoking the completion callback, execution makes the span
             ;; inactive. BEFORE -- a completion callback asking
             ;; `parser-active-span` must see #f, and this is the only place the
             ;; ordering is written.
             (let ((parts (op 'span-completion-parts node)))
               (byte-machine-span-close/v1 parser)
               (if (not (car parts))
                   ;; An absent completion callback: no invocation, no slot
                   ;; lookup, straight to the node's successor.
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
            ;; An INPUT-READING kind. It needs a byte, so it yields `need-input`
            ;; at the end of a slice and resumes at the same node on the next
            ;; feed -- its whole split-point behaviour, inherited from the dispatch
            ;; shape rather than invented. The op answers `(target . mode)`
            ;; because a step has three outcomes with two different consumption
            ;; behaviours.
            ((accumulate)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f)
                 (let ((r (op 'accumulate-step node (parser-field-values parser)
                              (bytevector-u8-ref bv pos))))
                   (route-byte-step! (car r) (cdr r) pos loop))))
            ;; Counted consume. The op decides -- this arm never tests
            ;; `(>= pos end)` before asking, because a zero count transitions
            ;; before exhaustion is looked at and only the op sees the count.
            ;; Three answers: a zero count transitions to `next` with nothing
            ;; consumed and the position kind CARRIED THROUGH (a zero-width step,
            ;; the field-action arm's convention); a positive count over exhausted
            ;; input parks here with need-input; a commit of n >= 1 bytes advances
            ;; cursor and offset by n and then continues at `next` when the count
            ;; reached zero -- count completion wins by construction -- or parks
            ;; here with need-input at the new cursor, `current` still this node.
            ;; There is no bulk primitive to share: route-byte-step! advances one
            ;; byte.
            ((counted-consume)
             (let* ((r (op 'count-step node (parser-field-values parser) pos end))
                    (n (car r)) (target (cdr r)))
               (cond ((and (= n 0) target)
                      (parser-set-current! parser target)
                      (loop pos pk))
                     ((= n 0)
                      (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f))
                     (else
                      (parser-set-offset! parser (+ n (parser-offset parser)))
                      (if target
                          (begin (parser-set-current! parser target)
                                 (loop (+ pos n) 'boundary))
                          (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                              (parser-offset parser) #f))))))
            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f)
                 (let ((trans (op 'dispatch node (bytevector-u8-ref bv pos))))
                   (route-byte-step! (car trans) (cdr trans) pos loop))))
            (else (assertion-violation 'parser-feed! "unknown node kind" (op 'kind node))))))))

  ;; The generated /v2 path: exec owns the dispatch loop; finish? = #f for feed.
  (define (parser-feed-v2! parser bv start end)
    (let* ((exec (parser-executor parser))
           ;; The PARSER's own field vector, not a shared sentinel: the generated
           ;; arms write through it, so a shared empty vector would make every
           ;; generated field machine index out of bounds.
           ;; The PARSER's own callback slot vector, not a shared sentinel: the
           ;; generated arm indexes it, so a shared empty vector would make every
           ;; generated callback machine index out of bounds.
           (o (exec (parser-current parser) (parser-offset parser) bv start end #f
                    (parser-field-values parser) parser (parser-callbacks parser))))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      ;; The generated outcome carries its reason record in slot 3 for BOTH an
      ;; error and a (M12) pause; route it by status -- error slot for 'error, the
      ;; new pause slot for 'paused, #f otherwise -- so the error slot stays #f for
      ;; a pause (brief §6). One outcome has one status, and slot 3 is #f for every
      ;; non-error/non-pause status, so this is total and cannot leak.
      (let ((st (feed-outcome-status o)) (e (feed-outcome-error o)))
        (make-parser-result st (feed-outcome-next o)
                            (- (feed-outcome-next o) start)
                            (feed-outcome-offset o)
                            (if (eq? st 'paused) #f e)
                            (if (eq? st 'paused) e #f)))))

  ;; parser-finish!: the paused rows are a prohibited cell and the sticky rows
  ;; (stopped/error/finished) short-circuit here without running anything;
  ;; otherwise (ready | finish-ready) it runs the executor with input exhausted.
  ;; From the current state, an exhausted dispatch takes its eof-target (a named
  ;; node, else the machine default-eof-error); execution continues to a finish
  ;; node (-> finished), a pause node (-> paused), an error node (-> error), or a
  ;; stop node reached this way is verifier-rejected so it never occurs. No slice,
  ;; so next/consumed mirror the stream offset / 0. The generated finish path
  ;; runs the same `exec` with finish? #t; the else arm is unreachable through
  ;; the public API now that only 'op and 'v2 can be constructed, and stays an
  ;; assertion violation for that reason.
  ;; parser-finish! : Parser -> ParserResult
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
      ;; The same two rows and the same three codes as `parser-feed!`'s.
      ;; Deliberately not shared with them: this file's own comment above
      ;; `parser-feed!` records why near-identical arms here stay separate, and
      ;; each of these is its own row of the operation matrix.
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
       ;; RE-ANCHOR THE MARK TO 0, mirroring the feed path's re-anchor to the next
       ;; slice's `start`: the finish path runs over `empty-bv 0 0`, so 0 IS the
       ;; slice `start` here. This makes an EOF-side span end see `[0,0)` -- a
       ;; coherent empty range -- for EVERY active span, whether it opened ON the
       ;; EOF chain (its mark is already 0) or was CARRIED from a feed (its mark
       ;; still held that feed's `start`). So every empty span closing at EOF
       ;; delivers its one empty fragment exactly once, uniformly; a NON-empty span
       ;; carried here suppresses because its `delivered?` flag is set (decision
       ;; 0042 item 4). Without this line the carried empty case would deliver only
       ;; when the last feed happened to start at 0 -- a slicing-dependent
       ;; inconsistency the whole-branch review found. `from > to` is therefore no
       ;; longer reachable at any span end (feed marks are <= the cursor, EOF marks
       ;; are 0), so the step's guard suppresses only the flag-set final fragment;
       ;; the `from > to` arm is kept as defence. The EOF side still needs no
       ;; bytevector and there is no boundary flush after EOF.
       (when (parser-active-span parser)
         (parser-set-span-mark! parser 0))
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
  ;; exec owns the eof-target chain internally; the runtime just commits resume
  ;; state, records the terminal lifecycle, and snapshots the result (no slice, so
  ;; next/consumed mirror the stream offset / 0).
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
      ;; Route slot 3 by status, as the feed boundary does: pause reason to the
      ;; pause slot, error to the error slot, #f otherwise.
      (let ((st (feed-outcome-status o)) (e (feed-outcome-error o)))
        (make-parser-result st (feed-outcome-offset o) 0
                            (feed-outcome-offset o)
                            (if (eq? st 'paused) #f e)
                            (if (eq? st 'paused) e #f)))))

  (define (parser-finish-op! parser)
    ;; No local cycle guard: termination relies on the verifier's
    ;; eof-zero-progress-cycle/eof-reachable-stop checks having already rejected
    ;; non-terminating and stop-terminating EOF chains, so this loop terminates
    ;; only for verified machines -- the same reliance the generated /v2 finish
    ;; path (parser-finish-v2!) has, since it does not re-verify at runtime
    ;; either.
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
      ;; The EOF route an input-reading node takes at finish: hop to a named
      ;; eof-target carrying `eof`, or terminate at the machine default-EOF
      ;; error. Factored because the counted-consume arm needs this body after
      ;; its zero-count test; each arm's CALL stays its own line, as
      ;; route-byte-step! does in the feed loop.
      (define (take-eof-route! node loop)
        (let ((t (op 'eof-target node)))
          (if t
              (begin (parser-set-current! parser t) (loop t 'eof))
              (begin (parser-set-lifecycle! parser 'error)
                     (let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'error off 0 off e))))))
      (let loop ((node (parser-current parser)) (pk 'boundary))
        (case (op 'kind node)
          ((finish)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'finished)
           (make-parser-result 'finished off 0 off #f))
          ((pause)
           (parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f
             (let ((rp (op 'pause-reason node)))
               (and rp (parts->parser-error rp off pk)))))
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
          ;; EOF processing may invoke callbacks and may pause. A pause during
          ;; EOF produces `paused-finish`. The same invocation as the feed loop's,
          ;; deliberately written out rather than shared with it: the two arms
          ;; differ in what they build and in the lifecycle they record, and this
          ;; file's own comment above `parser-feed!` states why near-identical
          ;; arms here stay separate.
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
                (make-parser-result 'paused off 0 off #f
                  (let ((rp (op 'pause-reason node)))
                    (and rp (parts->parser-error rp off callback-failure-position)))))
               (else
                (parser-set-current! parser node)
                (parser-set-lifecycle! parser 'error)
                (let ((e (byte-machine-make-callback-error/v1
                          (cadr o) (caddr o) node (list-ref parts 5) off
                          callback-failure-position)))
                  (parser-set-stored-error! parser e)
                  (make-parser-result 'error off 0 off e))))))
          ;; The span kinds on the EOF side. The SAME three arms as the feed
          ;; loop's -- including the SAME public span-end step -- written out for
          ;; the reason this file's own comment above `parser-feed!` gives (each
          ;; records its own lifecycle) and over `empty-bv` at cursor 0. Routing
          ;; the span end through the public step, not a suppress-only path, is
          ;; what keeps the generated lane in step: `parser-finish-v2!` reaches
          ;; this same behaviour through the emitted arm. The `ready` arm above
          ;; re-anchored the mark to 0, so EVERY active span here has `from == to`:
          ;; an empty span (flag clear) delivers its one empty fragment, a carried
          ;; non-empty span (flag set) suppresses -- both lanes identically
          ;; (decision 0042 item 4).
          ;;
          ;; THE CURSOR IS WHY NO BYTEVECTOR IS NEEDED HERE: the cursor passed
          ;; below is the literal 0, and the mark is 0 (re-anchored), so `from ==
          ;; to` and `parser-span-delivered?` decides -- deliver an empty fragment
          ;; once, or suppress a flag-set span. `empty-bv` is passed because the
          ;; step's signature takes one, never because a byte of it is read.
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
          ;; declared EOF edge exactly as a dispatch node does.
          ((accumulate dispatch) (take-eof-route! node loop))
          ;; Counted consume: the same message over an empty slice, reading only
          ;; the target. A zero count transitions to `next` -- the entry of a
          ;; fresh parser with a zero initial, a pause continuation, a node on an
          ;; EOF chain -- with the position kind carried; a positive count is a
          ;; truncation and takes the EOF route (a parser parked here by
          ;; need-input always holds one).
          ((counted-consume)
           (let ((r (op 'count-step node (parser-field-values parser) 0 0)))
             (if (cdr r)
                 (begin (parser-set-current! parser (cdr r)) (loop (cdr r) pk))
                 (take-eof-route! node loop))))
          (else (assertion-violation 'parser-finish! "unknown node kind" (op 'kind node)))))))

  ;; resume changes lifecycle only -- no callback, no input, no executor run.
  ;; paused-feed -> ready ('feed-ready ack); paused-finish -> finish-ready
  ;; ('finish-ready ack, which is also the state awaiting the next finish!).
  ;; Every other row of the resume! column is a prohibited cell.
  ;; parser-resume! : Parser -> Symbol
  (define (parser-resume! parser)
    (case (parser-lifecycle parser)
      ((paused-feed) (parser-set-lifecycle! parser 'ready) 'feed-ready)
      ((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'finish-ready)
      ;; The poisoned row gives `parser-poisoned` and the busy row the reentrancy
      ;; condition, and all three codes are distinct. The else keeps its own row
      ;; -- resuming a `ready` or terminal parser is a sequencing mistake and
      ;; nothing else.
      ((busy)
       (byte-machine-contract-violation 'parser-resume! 'reentrancy
                                        (list (parser-lifecycle parser) 'resume)))
      ((poisoned)
       (byte-machine-contract-violation 'parser-resume! 'poisoned-parser
                                        (list (parser-lifecycle parser) 'resume)))
      (else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))))

  ;; READ-ONLY, with no mutating sibling, and that is a design decision rather
  ;; than an omission: machine-field access from a callback is read-only, and
  ;; allowing callbacks to mutate fields would bypass the closed IR and
  ;; invalidate interpreter/generated equivalence.
  ;;
  ;; An undeclared name is a caller mistake, not a machine outcome, so it raises
  ;; a CONTRACT VIOLATION rather than producing a parser-error: parser-error is
  ;; the record describing what the parsed INPUT did, and answering a misspelled
  ;; field name with one would put a programming error into the same channel as a
  ;; rejected byte. `accessor-misuse` is the code for exactly that: reaching an
  ;; accessor with something the machine never declared.
  ;; parser-field-ref : Parser Symbol -> ExactInteger
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

  ;; Full reset: entry state, offset 0, lifecycle ready, and the stored error
  ;; cleared. `current := entry` is also what clears the pause continuation under
  ;; this representation -- it is parked on `current` with no separate
  ;; saved-continuation field, so restoring `current` restores both. FIELD state
  ;; is restored here, to the CANONICAL merged initials (slot 17) rather than to
  ;; zero OR the declared initials: reset returns the parser to its
  ;; just-constructed state, and a just-constructed parser holds the declared
  ;; initials WITH the `make-parser` embedder overrides applied (Milestone 13).
  ;; Restoring the declared initials would silently drop the embedder's mode on
  ;; the first reset -- the same bug as a wrong default arriving later (decision
  ;; 0047 item 3); with no override slot 17 equals the declared initials, so this
  ;; is exactly the pre-M13 behaviour. Zeroing would silently make `u8 count = 3`
  ;; mean 3 before the first reset and 0 after it. SPAN state is cleared through
  ;; the same procedure the span-end arms call, so "inactive" has exactly one
  ;; definition. `busy` and `poisoned` are not reset state at all: the guard
  ;; below rejects the first, and reset is the operation that clears the second,
  ;; which the lifecycle write already does. Returns unspecified.
  ;;
  ;; It writes slot 8 and never slot 9 or 17: the declarations and the canonical
  ;; merged initials belong to the compiled machine and to construction, and
  ;; outlive every reset.
  ;; parser-reset! : Parser -> Void
  (define (parser-reset! parser)
    ;; THE ONLY OPERATION THAT LETS A POISONED PARSER RUN. Every operation's
    ;; `busy` cell differs from its `poisoned` cell -- the two rows name different
    ;; codes throughout -- but reset is the one whose poisoned cell is not a raise
    ;; at all: it RESETS a poisoned parser, because "only full reset may reuse it"
    ;; is a permission and not a prohibition, while reset while busy raises
    ;; reentrancy -- a callback may not reset the parser it is running inside.
    ;;
    ;; The raise goes "before further mutation", so the guard is the first thing
    ;; here and nothing above it can move.
    (when (eq? (parser-lifecycle parser) 'busy)
      (byte-machine-contract-violation 'parser-reset! 'reentrancy
                                       (list (parser-lifecycle parser) 'reset)))
    (parser-set-current! parser (parser-entry parser))
    (parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready)
    (parser-set-stored-error! parser #f)
    (byte-machine-span-close/v1 parser)
    (vector-set! parser 8 (copy-values (parser-field-initials parser)))))
