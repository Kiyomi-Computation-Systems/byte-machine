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
  (make-machine 'pausem 'start (list (make-uint-field 'count 8 0 #f)) '() '()
    (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'bump 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          ;; A FALLIBLE action, so the emitted arm binds `r` as well as `v`; a
          ;; safe one emits no bound check and would leave `r` unwitnessed.
          (make-field-action-node 'bump 'increment '(count) 'test 'reject #f)
          ;; A STOP, not a finish: Slice ②'s own :908 check rejects a
          ;; byte-reachable zero-width node targeting a finish terminal, which
          ;; this fixture ran into on its first draft.
          (make-field-branch-node 'test 'zero '(count) 'done 'acc #f)
          ;; Slice ③'s INPUT-READING arm. Reached from the branch's false leg so
          ;; the fixture keeps a single entry; base 16 because that arm renders
          ;; the three-range `cond`, which is where `d` is bound.
          (make-integer-accumulate-node 'acc 'count 16 'acc
                                        (make-edge 'done 'advance) 'reject #f #f)
          (make-stop-node 'done #f)
          (make-error-node 'reject 'rejected #f))
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
(define (symbols-outside-quote x acc)
  (cond ((symbol? x) (if (memq x acc) acc (cons x acc)))
        ((pair? x) (if (eq? (car x) 'quote)
                       acc
                       (symbols-outside-quote (cdr x) (symbols-outside-quote (car x) acc))))
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
        (let ((seen 'seed) (n 0))
          (set! seen '())
          (for-each (lambda (s)
                      (set! n (+ n 1))
                      (when (memq s observed) (set! seen (cons s seen))))
                    '(fieldv errs pk v r d))
          (check-equal "six checked" n 6)
          (check-equal "all six emitted" (length seen) 6))))))

(harness-finish)
