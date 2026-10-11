;;; reserved-member-3 against the symbols the emitter actually binds.
;;;
;;; reserved-member-2's drift guard is reserved-drift-tests.sps; this is
;;; member-3's. Without it, a new emitted local that nobody adds to the list
;;; lets render-machine accept a caller binding that collides with it, and the
;;; collision surfaces as a generated library that shadows its own loop
;;; variable.
;;;
;;; Unlike reserved-drift-tests.sps, which sorts two lists and asserts one
;;; check-equal, this walks the rendered library as a read datum.
(import (rnrs)
        (only (byte-machine private names) portable-name?)
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
;; *** The fixture is the pause machine PLUS the nodes whose arms bind locals
;; the pause machine's do not. *** A local in reserved-member-3 that no rendered
;; arm binds is a reservation nothing exercises. The pause machine declares no
;; fields, so its emitted body binds neither `v` nor `r`; the two field nodes
;; put them in the rendered text. The integer-accumulate node's arm binds `b`,
;; `d` and `v`, and `d` is bound by no other arm.
(define (make-field-drift-machine)
  (make-machine 'pausem 'start (list (make-uint-field 'count 8 0 #f))
    ;; The callback node's arm binds `o`, which no other arm does, so without
    ;; this declaration and the node below `o` would sit in reserved-member-3
    ;; as a reservation nothing exercises.
    ;;
    ;; The fixture renders thirteen of `render-state-arm`'s arms: stop, error,
    ;; accumulate, field-action, field-branch, callback, dispatch, finish,
    ;; pause, span-start, span-end, span-completion and counted-consume
    ;; (`cbody` below). It has no keyword-table node.
    ;;
    ;; The span arms are not inert: two render a `let` binding `o`, and
    ;; compile.sls's stated property that none of them binds a local beyond `o`
    ;; would otherwise be prose in the file under test rather than a check
    ;; here. The pause arm binds nothing at all, which is also why it is worth
    ;; rendering: an arm that binds nothing is one nobody re-checks when it
    ;; starts to.
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
          ;; Its true leg reaches `done` through the callback node. `done` is a
          ;; STOP and not a finish because the verifier rejects a
          ;; byte-reachable zero-width node targeting a finish terminal.
          (make-field-branch-node 'test 'zero '(count) 'note-it 'acc #f)
          ;; A REQUIRED event callback, so the emitted arm renders `#f` for the
          ;; default target and an empty branch map -- the ordinary event shape.
          ;; Its pause continuation is the ERROR node and not the stop: a parser
          ;; parked at a callback resumes on that one edge, so a stop there is
          ;; an EOF path reaching a stop terminal, which the verifier rejects.
          (make-callback-node 'note-it 'note 'done '() 'reject #f)
          ;; The INPUT-READING arm. Reached from the branch's false leg so
          ;; the fixture keeps a single entry; base 16 because that arm renders
          ;; the three-range `cond`, which is where `d` is bound.
          (make-integer-accumulate-node 'acc 'count 16 'acc
                                        (make-edge 'done 'advance) 'sopen #f #f)
          ;; The span sits on the accumulate's overflow leg, which is the only
          ;; edge in this fixture with nothing else on it. `sread` consumes so
          ;; the span has a nonempty payload to close over; `send`'s successor is
          ;; a DISPATCH and not the stop, because a span end is a parked state
          ;; and continuing it straight into a stop is a shape the verifier
          ;; rejects.
          (make-span-start-node 'sopen 'body 'sread #f)
          (make-byte-dispatch-node 'sread
            (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'send 'reexecute) #f))
            ;; Its OWN error terminal. The shared `reject` is reached from
            ;; outside the span with no span open, so routing this EOF there
            ;; joins `(active body)` with `none` and the machine is rejected for
            ;; an inconsistent merge.
            (make-edge 'sread 'advance) 'rej2 #f)
          (make-span-end-node 'send 'body 'sdone #f)
          ;; The pause arm, on `sdone`'s fallback. Its continuation is the
          ;; ERROR node and not the stop, for the reason the callback node above
          ;; records: a parser parked at a pause resumes on that one edge, so a
          ;; stop there is an EOF path reaching a stop terminal.
          (make-byte-dispatch-node 'sdone
            (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'cbody 'advance) #f))
            (make-edge 'pz 'reexecute) 'fin #f)
          ;; The counted-consume arm, on `sdone`'s byte, after the span has
          ;; closed: it consumes `count` bytes in bulk and is the one arm that
          ;; binds `n`.
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
;; *** `case` CLAUSE DATUMS are skipped too. *** They are data by exactly the
;; argument the paragraph above makes: `case` compares them with `eqv?` against
;; literals and binds nothing, so a clause datum equal to a caller's name cannot
;; capture it. They are skipped explicitly rather than by the quote rule only
;; because `case` does not write them inside a `quote`. An emitted `case` over
;; numeric state ids and bytes cannot show the gap -- numbers are not symbols
;; -- but the callback arm's `(case (car o) ((goto) ...) ((pause) ...))` has
;; symbol datums.
;;
;; Reserving `goto` and `pause` instead would forbid two perfectly good OUTPUT
;; BINDINGS -- reserved-member-3 is checked by `validate-binding` against the
;; caller's binding symbol and against nothing else.
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

;; The subtractions: the (rnrs) environment, the runtime environment, the
;; binding and machine name, and the emitted file's structural names.
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


;; THE STATE PROCEDURES AND THEIR DISPATCHER CARRY AN UNFORGEABLE PREFIX.
;; The emitted body binds `%s<id>` for every state and one `%dispatch`, and
;; they are deliberately NOT in reserved-member-3: a machine's state count has
;; no bound, so the list could not enumerate them. What keeps them safe is the
;; prefix. `portable-name?` admits `[a-z][a-z0-9-]*` and nothing else, so no
;; output binding and no declared name can begin with `%`, and the collision
;; reserved-member-3 exists to prevent is impossible by construction rather
;; than by enumeration.
;;
;; Subtracting them is therefore sound -- but subtracting a whole PREFIX is a
;; hole in a guard whose entire job is to notice new emitter locals, so the
;; case below closes it: every name subtracted here is asserted to be one the
;; emitter is known to emit AND to be unforgeable. A future local introduced
;; without the prefix lands in the leftover and still fails; one introduced
;; WITH the prefix but under a new spelling fails the shape check.
(define (emitter-private? sym)
  (let ((s (symbol->string sym)))
    (and (> (string-length s) 0) (char=? (string-ref s 0) #\%))))
(define (state-procedure-name? sym)
  (let ((s (symbol->string sym)))
    (and (> (string-length s) 2)
         (char=? (string-ref s 0) #\%)
         (char=? (string-ref s 1) #\s)
         (let loop ((i 2))
           (or (>= i (string-length s))
               (and (char<=? #\0 (string-ref s i)) (char<=? (string-ref s i) #\9)
                    (loop (+ i 1))))))))

(define observed-private (filter emitter-private? observed))
(define leftover
  (filter (lambda (sym) (not (emitter-private? sym)))
          (subtract (subtract (subtract (subtract observed (environment-symbols (environment '(rnrs))))
                                        (environment-symbols (environment '(byte-machine runtime))))
                              (list binding machine-name-sym))
                    structural)))

(harness-group "reserved member 3 covers every emitted local"
  (lambda ()
    (harness-case "the subtracted emitter-private names are unforgeable, and only the two known shapes"
      (lambda ()
        ;; A found-it guard first: with no private names the two checks below
        ;; would pass over an empty list and say nothing at all.
        (check "the emitted body binds emitter-private names" (pair? observed-private))
        (check "every one of them is a state procedure or the dispatcher"
               (for-all (lambda (sym)
                          (or (state-procedure-name? sym) (eq? sym (quote %dispatch))))
                        observed-private))
        ;; The safety property itself, not a restatement of the spelling: none
        ;; of these can be written as a declared name or an output binding.
        (check "no declared name or output binding could collide with one"
               (for-all (lambda (sym) (not (portable-name? sym))) observed-private))))
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
        ;; The list names reserved-member-3's arm- and parameter-specific
        ;; locals: `fieldv`, `errs`, `pk`; `v` and `r` (the field arms); `d` (the
        ;; accumulate arm); `o` (the callback arm's outcome binding); `psr` and
        ;; `cbv` (emitted `exec`'s eighth and ninth parameters); `n` (the
        ;; counted-consume arm). A local added to reserved-member-3 is added
        ;; here too, and the fixture made to render it; the sentinel counts
        ;; what it iterates.
        (let ((seen 'seed) (n 0))
          (set! seen '())
          (for-each (lambda (s)
                      (set! n (+ n 1))
                      (when (memq s observed) (set! seen (cons s seen))))
                    '(fieldv errs pk v r d o psr cbv n))
          (check-equal "ten checked" n 10)
          (check-equal "all ten emitted" (length seen) 10))))))

(harness-finish)
