;;; reserved-member-3 against the symbols the emitter actually binds.
;;;
;;; reserved-member-2 has had a drift guard since reserved-drift-tests.sps;
;;; member-3 has had none, and compile.sls said so in its own words ("checked,
;;; not assumed, since it has no automated drift guard"). Slice ①a adds three
;;; entries to it, so the gap is demonstrated rather than theoretical: a new
;;; emitted local that nobody adds to the list lets render-machine accept a
;;; caller binding that collides with it, and the collision surfaces as a
;;; generated library that shadows its own loop variable.
;;;
;;; This is NEW construction, not a copy of reserved-drift-tests.sps: that file
;;; sorts two lists and asserts one check-equal. Nothing in the tree walked a
;;; read datum before this.
(import (rnrs)
        (rnrs eval)
        ;; environment-symbols is a Chez extension, not R6RS -- the same import
        ;; reserved-drift-tests.sps needs, and its header records that the AOT
        ;; lane needs it statically rather than through the launcher.
        (only (chezscheme) environment-symbols)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine compile)
        ;; Statically imported although nothing here calls it: the AOT lane
        ;; compiles only the program's static import closure and loads
        ;; exclusively from compiled objects, so a library reached solely
        ;; through (environment '(byte-machine runtime)) below is never
        ;; compiled and `environment` raises "library not found" under aot only.
        ;; reserved-drift-tests.sps:9-21 records the same surprise.
        (byte-machine runtime)
        (byte-machine test pause-machine))

(harness-begin "unit.member3-drift")

;; The pause machine exercises every state kind the emitter can render --
;; dispatch, stop, error, finish and pause -- so every arm of render-state-arm
;; contributes its locals to the walk.
(define binding 'pausem)
;; *** The fixture is the pause machine PLUS two field nodes, added by Slice ②.
;; *** The pause machine alone declares no fields, so the emitted body binds
;; neither `v` nor `r` and both would sit in reserved-member-3 as reservations
;; nothing exercises -- the guard would stop guarding the thing ② added to it.
;; The two field arms are what put those locals in the rendered text.
;;
;; *** Slice ③ extends the same fixture again, with an integer-accumulate node.
;; *** Its arm binds `b`, `d` and `v`; `b` and `v` come from arms already here,
;; but `d` does not, and without this node `d` would sit in reserved-member-3 as
;; a reservation nothing exercises -- the same gap ② closed for `v` and `r`,
;; reopened by ③'s own addition to the list.
(define (make-field-drift-machine)
  (make-machine 'pausem 'start (list (make-uint-field 'count 8 0 #f))
    ;; *** Milestone 5 Slice ② extends the fixture once more, with a callback
    ;; node. *** Its arm binds `o`, which no other arm does, so without this
    ;; declaration and the node below `o` would sit in reserved-member-3 as a
    ;; reservation nothing exercises -- the gap ② closed for `v` and `r`, and ③
    ;; for `d`, reopened by this slice's own addition to the list.
    ;; *** AND SLICE ③ EXTENDS IT A SECOND TIME, with a span and a pause. ***
    ;; Its census reconciliation found the fixture rendering only part of
    ;; `render-state-arm`, and the FINAL REVIEW corrected the number: SEVEN of
    ;; the twelve arms, not the nine first written here. Measured both ways by
    ;; rendering this fixture and probing the emitted text -- stop, error,
    ;; accumulate, field-action, field-branch, callback and dispatch were
    ;; rendered; finish, pause, span-start, span-end and span-completion were
    ;; not. All five are added here, so the row the design Appendix carries for
    ;; this fixture -- "must render EVERY emitted arm" -- is literally true at
    ;; twelve of twelve rather than nearly true. Milestone 6 Slice ① made it
    ;; thirteen of thirteen: `cbody` below renders the counted-consume arm.
    ;;
    ;; The span arms are not inert: two render a `let` binding `o`, and
    ;; compile.sls's stated property that none of them binds a local beyond `o`
    ;; was prose in the file under test rather than a check here. The pause arm
    ;; binds nothing at all, which is exactly why it went unnoticed -- and is
    ;; also why it is worth rendering: an arm that binds nothing TODAY is one
    ;; nobody re-checks when it starts to.
    (list (make-callback-declaration 'note 'event #t '() #f #f)
          (make-callback-declaration 'on-data 'span-data #t '() #f #f)
          (make-callback-declaration 'on-done 'span-complete #t '() #f #f))
    ;; The completion callback is DECLARED, so the span-completion arm renders
    ;; its calling shape. The other shape -- the substep with no callback -- is
    ;; witnessed by differential-span-tests.sps's second machine; this fixture
    ;; can only render one of the two, and the calling one is the one that binds.
    (list (make-span-declaration 'body 'on-data 'on-done #f))
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'bump 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          ;; A FALLIBLE action, so the emitted arm binds `r` as well as `v`; a
          ;; safe one emits no bound check and would leave `r` unwitnessed.
          (make-field-action-node 'bump 'increment '(count) 'test 'reject #f)
          ;; Its true leg went straight to `done` until Milestone 5 Slice ②
          ;; threaded the callback node in front of it. `done` is a STOP and not
          ;; a finish for the reason that predates both: §16.2:908 rejects a
          ;; byte-reachable zero-width node targeting a finish terminal, which
          ;; this fixture ran into on its first draft.
          (make-field-branch-node 'test 'zero '(count) 'note-it 'acc #f)
          ;; A REQUIRED event callback, so the emitted arm renders `#f` for the
          ;; default target and an empty branch map -- the ordinary event shape.
          ;; Its pause continuation is the ERROR node and not the stop: a parser
          ;; parked at a callback resumes on that one edge (§13:812), so a stop
          ;; there is an EOF path reaching a stop terminal and §16.2:909 rejects
          ;; it. Found by building this fixture.
          (make-callback-node 'note-it 'note 'done '() 'reject #f)
          ;; Slice ③'s INPUT-READING arm. Reached from the branch's false leg so
          ;; the fixture keeps a single entry; base 16 because that arm renders
          ;; the three-range `cond`, which is where `d` is bound.
          (make-integer-accumulate-node 'acc 'count 16 'acc
                                        (make-edge 'done 'advance) 'sopen #f #f)
          ;; The span sits on the accumulate's overflow leg, which is the only
          ;; edge in this fixture with nothing else on it. `sread` consumes so
          ;; the span has a nonempty payload to close over; `send`'s successor is
          ;; a DISPATCH and not the stop, because a span end is a parked state
          ;; (§16.2:909) and continuing it straight into a stop is exactly the
          ;; shape this slice taught the verifier to reject.
          (make-span-start-node 'sopen 'body 'sread #f)
          (make-byte-dispatch-node 'sread
            (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'send 'reexecute) #f))
            ;; Its OWN error terminal. The shared `reject` is reached from
            ;; outside the span with no span open, so routing this EOF there
            ;; joins `(active body)` with `none` and the machine is rejected for
            ;; an inconsistent merge -- found by building it.
            (make-edge 'sread 'advance) 'rej2 #f)
          (make-span-end-node 'send 'body 'sdone #f)
          ;; The twelfth arm, on `sdone`'s fallback. Its continuation is the
          ;; ERROR node and not the stop, for the reason the callback node above
          ;; records: a parser parked at a pause resumes on that one edge, so a
          ;; stop there is an EOF path reaching a stop terminal (§16.2:909).
          (make-byte-dispatch-node 'sdone
            (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'cbody 'advance) #f))
            (make-edge 'pz 'reexecute) 'fin #f)
          ;; The thirteenth arm (Milestone 6 Slice ①), on `sdone`'s byte, after
          ;; the span has closed: it consumes `count` bytes in bulk and is the one
          ;; arm that binds `n`, the local this slice adds to reserved-member-3.
          (make-counted-consume-node 'cbody 'count 'done #f #f)
          (make-pause-node 'pz 'reject #f)
          (make-finish-node 'fin #f)
          (make-stop-node 'done #f)
          (make-error-node 'reject 'rejected #f)
          (make-error-node 'rej2 'rejected #f))
    'default-eof #f))
(define rendered (utf8->string (render-machine (compile-machine (make-field-drift-machine) '())
                                               binding)))
;; R6RS has no with-input-from-string; open-string-input-port is the portable
;; form and is what the shipped determinism programs use.
(define datum (read (open-string-input-port rendered)))

;; Every symbol outside a quote form. Skipping quoted data is what keeps error
;; codes, reasons, node names and the metadata vector out of the measurement:
;; those are DATA the emitted body carries, not identifiers it binds, and a
;; caller binding may legitimately equal one of them.
;;
;; *** `case` CLAUSE DATUMS are skipped too, and Milestone 5 Slice ② is what
;; found it. *** They are data by exactly the argument the paragraph above
;; makes: `case` compares them with `eqv?` against literals and binds nothing,
;; so a clause datum equal to a caller's name cannot capture it. They are
;; skipped explicitly rather than by the quote rule only because `case` does not
;; write them inside a `quote`. Before this, the emitted `case` over numeric
;; state ids and bytes made the gap invisible -- numbers are not symbols -- and
;; the callback arm's `(case (car o) ((goto) ...) ((pause) ...))` is the first
;; emitted `case` whose datums are symbols. (Measured on the pre-slice goldens:
;; every emitted `case` was over NUMBERS -- state ids and byte values.)
;;
;; Reserving `goto` and `pause` instead would have forbidden two perfectly good
;; OUTPUT BINDINGS -- reserved-member-3 is checked by `validate-binding` against
;; the caller's binding symbol and against nothing else; an earlier draft of this
;; paragraph said "machine names", which no reserved-member list gates.
;;
;; The KEY expression and every clause BODY are still walked, which is what
;; keeps that arm's own `o` in the measurement: it appears only inside
;; `(car o)` and `(cadr o)`.
(define (symbols-outside-quote x acc)
  (cond ((symbol? x) (if (memq x acc) acc (cons x acc)))
        ((pair? x)
         (cond ((eq? (car x) 'quote) acc)
               ((and (eq? (car x) 'case) (pair? (cdr x)))
                (let cloop ((cs (cddr x)) (a (symbols-outside-quote (cadr x) acc)))
                  (if (not (pair? cs)) a
                      (cloop (cdr cs) (symbols-outside-quote (cdr (car cs)) a)))))
               (else
                (symbols-outside-quote (cdr x) (symbols-outside-quote (car x) acc)))))
        ((vector? x) (symbols-outside-quote (vector->list x) acc))
        (else acc)))

(define observed (symbols-outside-quote datum '()))

;; Three subtractions the design names, and a fourth it does not.
;;
;; MEASURED, not assumed: (rnrs) does NOT bind `library`, `import` or `export`
;; as identifiers -- they survive the first subtraction. Neither does it bind
;; the derived library name's parts. Those are the emitted file's STRUCTURE, not
;; locals the body binds, so they are subtracted by name with the reason stated
;; rather than by hoping the (rnrs) environment covers them. The machine name is
;; among them and is NOT the caller's binding: this fixture happens to render
;; both as `pausem`, but the one-byte machine is `one-byte` with binding
;; `one-byte-parser`, so both are subtracted.
(define structural '(library import export generated rnrs byte-machine runtime))
(define machine-name-sym 'pausem)

(define (subtract xs ys) (filter (lambda (x) (not (memq x ys))) xs))

(define leftover
  (subtract (subtract (subtract (subtract observed (environment-symbols (environment '(rnrs))))
                                (environment-symbols (environment '(byte-machine runtime))))
                      (list binding machine-name-sym))
            structural))

(harness-group "reserved member 3 covers every emitted local"
  (lambda ()
    (harness-case "the walk reaches the emitted body at all"
      (lambda ()
        ;; A sentinel over the measurement itself, read from what the walk
        ;; RETURNED rather than from the list this file expects. Without it a
        ;; walk that silently returned '() would satisfy the subset assertion
        ;; below vacuously -- the whole failure mode a subset test invites.
        (let ((n 'seed))
          (set! n (length observed))
          (check "the emitted body binds symbols" (> n 20)))))
    (harness-case "every symbol left after the subtractions is a declared member"
      (lambda ()
        (let ((extra 'seed))
          (set! extra (subtract leftover reserved-member-3))
          (check-equal "no undeclared emitted local" extra '()))))
    (harness-case "every local a slice added to the list is actually exercised"
      (lambda ()
        ;; Named individually rather than counted: a count passes when one entry
        ;; is swapped for another, and `fieldv` in particular is reachable only
        ;; because it is spelled that way -- (rnrs) binds `fields`, so had the
        ;; parameter been named that, the first subtraction above would have
        ;; swallowed it and its membership could never be exercised.
        ;;
        ;; *** The list grows with the slices, and Slice ③ found it had not. ***
        ;; It said "the three locals THIS SLICE added" and still named Slice ①a's
        ;; three; ② added `v` and `r` to reserved-member-3 and made the fixture
        ;; render them, but never named them here, so nothing failed when a
        ;; later edit could have dropped either. ③ adds `d` and names all six,
        ;; and the case is renamed so the next slice inherits the obligation
        ;; rather than a claim about one slice.
        ;; Milestone 5 Slice ①a adds `psr` and `cbv`, emitted `exec`'s eighth and
        ;; ninth parameters (decision 0025 point 3), and inherits that obligation
        ;; as intended: eight names, and the sentinel counts what it iterates.
        ;; Milestone 5 Slice ② adds `o`, the callback arm's outcome binding, and
        ;; the fixture gains a callback node so it is actually rendered: nine.
        (let ((seen 'seed) (n 0))
          (set! seen '())
          (for-each (lambda (s)
                      (set! n (+ n 1))
                      (when (memq s observed) (set! seen (cons s seen))))
                    '(fieldv errs pk v r d o psr cbv n))
          (check-equal "ten checked" n 10)
          (check-equal "all ten emitted" (length seen) 10))))))

(harness-finish)
