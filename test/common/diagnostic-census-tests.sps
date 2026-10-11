;;; The verifier's diagnostic census: what codes exist, where they are emitted,
;;; and which of them any fixture actually produces.
;;;
;;; *** This is a RATCHET, not a discovery. *** A change that adds a diagnostic
;;; code, or a new emission site under an existing code, fails here until it is
;;; accounted for. It cannot see an EXISTING code going unemitted for a NEW node
;;; kind, from a site another kind already fires; the kind x position matrix is
;;; the half that does. The two are complements on disjoint axes, and neither
;;; subsumes the other.
;;;
;;; THE SET IS DERIVED FROM THE ARTIFACT, NEVER DECLARED HERE. A hardcoded list
;;; of codes in a test is itself a census that goes stale. So `verify.sls` is
;;; READ AS A DATUM and walked. The technique is
;;; member3-drift-tests.sps's, applied to a source file rather than an emitted
;;; one.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify))

(harness-begin "unit.diagnostic-census")

(define source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r "")))
        r
        ;; Loud, not defaulted. A census that silently reads the wrong tree is
        ;; worse than no census: under the mutation suite it would read the
        ;; PRISTINE source while running the MUTATED object, and every
        ;; source-side mutation would report as caught for no reason at all.
        (assertion-violation 'diagnostic-census
                             "BYTE_MACHINE_SOURCE_ROOT is unset" r))))

(define (read-library path)
  ;; A .sls file is exactly one datum. The second value is the guard: anything
  ;; after the library form would be walked past in silence.
  (call-with-input-file path
    (lambda (p)
      (let* ((d (read p)) (clean (eof-object? (read p))))
        (cons d clean)))))

(define verify-src (read-library (string-append source-root "/byte-machine/verify.sls")))
(define ir-src (read-library (string-append source-root "/byte-machine/private/ir.sls")))

;; Every `(make-diagnostic <x> ...)` form. Returns (codes . total): `codes` are
;; the QUOTED first arguments in source order, `total` counts every form whose
;; car is a diagnostic constructor whether or not its code is quoted. The two
;; differ by one per constructor -- its own `(define (make-diagnostic... ) ...)`
;; header -- and those are subtracted BY NAME below rather than by hoping the
;; arithmetic works out.
;; *** The constructor NAMES are derived, not hardcoded. *** With names written
;; into this walk, a further constructor -- and every code emitted through it --
;; would go unpinned and untested while the census stayed green. The set is
;; instead every `(define
;; (make-diagnostic... ) ...)` in the file, so adding one puts its sites in scope
;; automatically and its own header into the subtraction below.
(define (make-diagnostic-name? sym)
  (and (symbol? sym)
       (let ((nm (symbol->string sym)) (pre "make-diagnostic"))
         (and (>= (string-length nm) (string-length pre))
              (string=? (substring nm 0 (string-length pre)) pre)))))

(define diagnostic-constructors
  (let loop ((x (car verify-src)) (acc '()))
    (cond ((pair? x)
           (let ((acc (if (and (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                               (make-diagnostic-name? (car (cadr x)))
                               (not (memq (car (cadr x)) acc)))
                          (cons (car (cadr x)) acc)
                          acc)))
             (loop (cdr x) (loop (car x) acc))))
          ((vector? x) (loop (vector->list x) acc))
          (else acc))))

(define (walk-diagnostics x)
  ;; Every constructor counts -- four (`make-diagnostic`, `/edge`,
  ;; `/declarations`, `/path`), all in the derived `diagnostic-constructors`
  ;; set. `make-diagnostic/edge` carries the diagnostic's edge label; it is an
  ;; emission site exactly as much as the three-argument form, and a census
  ;; that missed any constructor would under-count the moment the tree started
  ;; using it -- which is the failure this file exists to prevent, one level up.
  (let loop ((x x) (codes '()) (total 0))
    (cond ((pair? x)
           (if (memq (car x) diagnostic-constructors)
               (let* ((a (and (pair? (cdr x)) (cadr x)))
                      (q (and (pair? a) (eq? (car a) 'quote) (cadr a))))
                 (let-values (((c t) (loop (cdr x) codes (+ total 1))))
                   (values (if q (cons q c) c) t)))
               (let-values (((c1 t1) (loop (car x) codes total)))
                 (loop (cdr x) c1 t1))))
          ((vector? x) (loop (vector->list x) codes total))
          (else (values codes total)))))

(define-record-type census (fields codes total))
(define the-census
  (let-values (((codes total) (walk-diagnostics (car verify-src))))
    (make-census (reverse codes) total)))

(define (distinct xs)
  (let loop ((xs xs) (acc '()))
    (cond ((null? xs) (reverse acc))
          ((memq (car xs) acc) (loop (cdr xs) acc))
          (else (loop (cdr xs) (cons (car xs) acc))))))

(define (count-of c) (length (filter (lambda (x) (eq? x c)) (census-codes the-census))))

;; The pinned table. MEASURED from the walk above, and re-baselined in the
;; commit that moves it: a census re-baselined in a separate tidying commit is a
;; census nobody checked. Its total is asserted separately so that two rows
;; moving in opposite directions cannot cancel.
(define pinned-sites
  '((invalid-shape 2) (duplicate-name 1) (duplicate-error-declaration 1)
    (missing-target 2) (missing-error-declaration 2) (invalid-field-declaration 2)
    (invalid-field-operand 7) (overlapping-cases 1) (ambiguous-sequence-prefix 1)
    (unreachable-node 1) (zero-progress-cycle 1) (invalid-eof-target 2)
    (non-eof-into-finish 2) (eof-reachable-stop 1) (eof-zero-progress-cycle 1)
    (invalid-name 6)
    ;; `pass-declarations`: callback, span and branch-key declarations.
    ;; Callback names, span names and branch keys are subjects of the name
    ;; grammar too, which is three of `invalid-name`'s six sites.
    (duplicate-callback-declaration 1) (duplicate-span-declaration 1)
    (duplicate-branch-key 2) (reserved-branch-key 1)
    (invalid-callback-declaration 2) (missing-callback-declaration 3)
    (invalid-span-callback 2) (unreferenced-callback-declaration 1)
    ;; The callback NODE checks. ONE code over three sites -- a span callback
    ;; invoked from a node, an undeclared branch key, and a declared key the
    ;; node gives no target. The two node faults that have codes of their own
    ;; REUSE them, which is one site each of `missing-callback-declaration` and
    ;; `duplicate-branch-key`: a callback node naming no declaration is the
    ;; same fault a span naming no declaration reports, and a key listed twice
    ;; is the same fault whether the list is a declaration's or a node's.
    (invalid-callback-invocation 3)
    ;; Pass 7, the span-state lattice. FOUR codes over SEVEN sites. The four
    ;; TRANSFER faults share one code because they are one question -- the
    ;; state at this node is wrong for what the node does -- while the merge
    ;; disagreement gets its own, because it is a different fault and not a
    ;; paraphrase. A span active at a pause and a span active at exit are one
    ;; code each.
    (invalid-span-state 4) (inconsistent-span-state 1)
    (span-active-at-pause 1) (span-active-at-exit 1)
    ;; A span NODE naming a span the machine never declared, emitted by
    ;; `pass-declarations` rather than pass 7. It is the mirror of
    ;; `missing-callback-declaration`, which is why it does not reuse it --
    ;; that code's subject is a CALLBACK name, and a reader tracing a report
    ;; back would look in the callback table for a name that is not in it.
    ;; Without it such a machine would verify clean and then raise out of
    ;; `normalize-machine`, which a verified machine must never do.
    (missing-span-declaration 1)
    ;; `pass-keyword-table`. Two codes, two sites -- an exact duplicate
    ;; keyword, and a fold collision in a case-insensitive table.
    (duplicate-keyword 1) (case-insensitive-keyword-collision 1)
    ;; `counted-operand-diagnostics`. ONE code, ONE site -- a counted-consume
    ;; node whose counter is a SETTABLE field, whose embedder-chosen initial
    ;; would falsify `parked-eof-start`'s entry reasoning. A
    ;; make-diagnostic/declarations site.
    (settable-consume-counter 1)))

(harness-group "the diagnostic code set is derived from verify.sls, not declared here"
  (lambda ()
    (harness-case "the source file is one datum and the walk consumed all of it"
      (lambda ()
        ;; Both guards, stated first: a second top-level datum would be silently
        ;; skipped, and a walk that found nothing would satisfy every subset
        ;; assertion below vacuously.
        (check "verify.sls is exactly one datum" (cdr verify-src))
        (check "ir.sls is exactly one datum" (cdr ir-src))
        (check "the walk found emission sites" (> (census-total the-census) 20))))
    (harness-case "every emitted code is a quoted symbol"
      (lambda ()
        ;; The forms whose code is not quoted are the constructors' own
        ;; definition headers. Subtracted BY NAME and BY COUNT: if a site
        ;; computes its code dynamically, this goes red rather than the site
        ;; slipping out of the census unnoticed. One header per constructor,
        ;; counted from the DERIVED set rather than from a literal.
        (check "at least two diagnostic constructors were found"
               (>= (length diagnostic-constructors) 2))
        (check-equal "quoted sites plus one header per constructor"
                     (+ (length (census-codes the-census))
                        (length diagnostic-constructors))
                     (census-total the-census))))
    (harness-case "the code set and the per-site counts match the pinned table"
      (lambda ()
        ;; A sentinel over the OBSERVED rows, not over the pinned table's length.
        (let ((observed 0))
          (for-each (lambda (row)
                      (set! observed (+ observed 1))
                      (check-equal (symbol->string (car row))
                                   (count-of (car row)) (cadr row)))
                    pinned-sites)
          (check-equal "every pinned row was checked" observed (length pinned-sites))
          (check-equal "and the code set is exactly the pinned set"
                       (list-sort (lambda (a b) (string<? (symbol->string a)
                                                          (symbol->string b)))
                                  (distinct (census-codes the-census)))
                       (list-sort (lambda (a b) (string<? (symbol->string a)
                                                          (symbol->string b)))
                                  (map car pinned-sites)))
          (check-equal "and the site total agrees"
                       (length (census-codes the-census))
                       (apply + (map cadr pinned-sites))))))))

;; --- the operand-table drift row -------------------------------------------
;; `ir.sls` names the seven operations and seven predicates a field node may
;; carry; `verify.sls` tabulates the arity and operand kinds of all fourteen. The
;; two lists are written in different files by different rules, and this row
;; pins their agreement. verify.sls's own comment at the lookup calls a mismatch
;; unreachable through the public API -- a closed-set claim in prose, which
;; needs a check behind it.
(define (defined-list datum name)
  ;; Find `(define <name> '(...))` and return the quoted list.
  (let loop ((x datum))
    (cond ((not (pair? x)) #f)
          ((and (pair? (car x)) (eq? (caar x) 'define)
                (pair? (cdar x)) (eq? (cadar x) name)
                (pair? (cddar x)) (pair? (caddar x))
                (eq? (car (caddar x)) 'quote))
           (cadr (caddar x)))
          (else (or (loop (car x)) (loop (cdr x)))))))

(harness-group "the operand schema table covers exactly the declared operations"
  (lambda ()
    (harness-case "both tables were found in their own source files"
      (lambda ()
        ;; Seeded and read back: a lookup that returned #f would make the
        ;; comparison below compare two empties and pass.
        (check "field-operations found" (pair? (defined-list (car ir-src) 'field-operations)))
        (check "field-predicates found" (pair? (defined-list (car ir-src) 'field-predicates)))
        (check "field-operand-schemas found"
               (pair? (defined-list (car verify-src) 'field-operand-schemas)))))
    (harness-case "the fourteen names agree across the two files"
      (lambda ()
        (let* ((ops (defined-list (car ir-src) 'field-operations))
               (preds (defined-list (car ir-src) 'field-predicates))
               (schema (map car (defined-list (car verify-src) 'field-operand-schemas)))
               (sortsym (lambda (l) (list-sort (lambda (a b) (string<? (symbol->string a)
                                                                      (symbol->string b)))
                                               l))))
          (check-equal "declared names equal tabulated names"
                       (sortsym (append ops preds)) (sortsym schema))
          ;; The size is asserted too: two tables that both lost the same name
          ;; would still agree with each other.
          (check-equal "and there are fourteen of them" (length schema) 14))))))

;; --- fixture coverage ------------------------------------------------------
;; One machine per code. The loop is over the SOURCE-DERIVED key set, not over
;; this table's own keys -- that is the whole ratchet. A code added to verify.sls
;; with no row here fails "no code lacks a fixture" by name; a row here for a
;; code the source does not emit is caught by the pinned code-set row above.
;;
;; The discriminator is the CODE plus the machine's shape, never the diagnostic's
;; message text: verify.sls's own header forbids comparing rendered text, and
;; the texts are not unique anyway -- two pairs of sites share one.
(define ed (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rd (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define (an-error n) (make-error-node n 'rejected #f))
(define (one-case-dispatch name target mode eof-target)
  (make-byte-dispatch-node name
    (list (make-byte-case (make-exact-byte-matcher 0) (make-edge target mode) #f))
    (make-edge 'rej 'reexecute) eof-target #f))
(define (mach name entry fields errs nodes default-eof)
  (make-machine name entry fields '() '() errs nodes default-eof #f))
;; The same machine with declaration tables. Every fixture
;; below that exercises `pass-declarations` is otherwise VALID, so the code it
;; drives is the only one its verification produces for a declaration reason.
(define (mach/decls name cbs sps errs nodes default-eof)
  (make-machine name 'start '() cbs sps errs nodes default-eof #f))
(define (ok-nodes) (list (one-case-dispatch 'start 'stop 'advance #f)
                         (make-stop-node 'stop #f) (an-error 'rej)))
(define (cb name kind req keys default)
  (make-callback-declaration name kind req keys default #f))
(define (sp name data complete) (make-span-declaration name data complete #f))
(define (verify-of m) (lambda () (verify-machine m)))
;; A machine carrying the span declaration chain, so a span-node fixture
;; drives pass 7 rather than the declaration-resolution checks.
(define (span-entry target)
  (make-byte-dispatch-node 'start
    (list (make-byte-case (make-exact-byte-matcher 0) (make-edge target 'advance) #f))
    (make-edge 'rej 'reexecute) #f #f))
(define (span-fixture nodes)
  (make-machine 'a 'start '()
                (list (cb 'on-data 'span-data #t '() #f))
                (list (sp 'body 'on-data #f))
                (list ed rd)
                (append nodes (list (make-stop-node 'stop #f) (an-error 'rej)))
                'default-eof #f))

(define code-fixtures
  (list
   ;; pass-schema's first half: the argument is not a machine at all.
   (cons 'invalid-shape (lambda () (verify-machine 'not-a-machine)))
   (cons 'duplicate-name
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (make-stop-node 'stop #f)
                                (an-error 'rej)) 'default-eof)))
   (cons 'duplicate-error-declaration
         (verify-of (mach 'a 'start '() (list ed rd rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   (cons 'missing-target
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'nowhere 'advance #f)
                                (an-error 'rej)) 'default-eof)))
   (cons 'missing-error-declaration
         (verify-of (mach 'a 'start '() (list ed)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f)
                                (make-error-node 'rej 'undeclared #f)) 'default-eof)))
   (cons 'invalid-field-declaration
         (verify-of (mach 'a 'start (list (make-uint-field 'n 8 0 #f)
                                          (make-uint-field 'n 8 0 #f))
                          (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   ;; A `range` operand wider than the field it names.
   (cons 'invalid-field-operand
         (verify-of (mach 'a 'start (list (make-uint-field 'n 8 0 #f)) (list ed rd)
                          (list (one-case-dispatch 'start 'br 'advance #f)
                                (make-field-branch-node 'br 'equal '(n 9999) 'stop 'stop #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   (cons 'overlapping-cases
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (make-byte-dispatch-node 'start
                                  (list (make-byte-case (make-byte-range-matcher 0 10)
                                                        (make-edge 'stop 'advance) #f)
                                        (make-byte-case (make-byte-range-matcher 5 20)
                                                        (make-edge 'stop 'advance) #f))
                                  (make-edge 'rej 'reexecute) #f #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   ;; One alternative is a proper prefix of another.
   (cons 'ambiguous-sequence-prefix
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (make-sequence-dispatch-node 'start
                                  (list (make-sequence-case '(1 2) 'stop #f)
                                        (make-sequence-case '(1 2 3) 'stop #f))
                                  (make-edge 'rej 'reexecute) #f #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   ;; Two keyword-table entries with the same bytes (proper
   ;; prefixes would be legal; an exact duplicate is not).
   (cons 'duplicate-keyword
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (make-keyword-table-node 'start
                                  (list (make-keyword-entry '(1) 'stop #f)
                                        (make-keyword-entry '(1) 'stop #f))
                                  (make-edge 'rej 'reexecute) #f #f #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   ;; A case-insensitive table whose entries collide after folding -- A (65)
   ;; and a (97), byte-distinct so not a duplicate-keyword; the fold makes their
   ;; terminal choice ambiguous.
   (cons 'case-insensitive-keyword-collision
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (make-keyword-table-node 'start
                                  (list (make-keyword-entry '(65) 'stop #f)
                                        (make-keyword-entry '(97) 'stop #f))
                                  (make-edge 'rej 'reexecute) #f #t #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   ;; A counted-consume node whose counter is a SETTABLE field -- its
   ;; embedder-chosen initial would falsify parked-eof-start's entry reasoning.
   (cons 'settable-consume-counter
         (verify-of (mach 'a 'start (list (make-uint-field 'n 8 0 #t #f)) (list ed rd)
                          (list (make-counted-consume-node 'start 'n 'stop 'stop #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   (cons 'unreachable-node
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (make-stop-node 'orphan #f)
                                (an-error 'rej)) 'default-eof)))
   (cons 'zero-progress-cycle
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'start 'reexecute #f)
                                (an-error 'rej)) 'default-eof)))
   ;; The machine default names no declared error.
   (cons 'invalid-eof-target
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'nosuch)))
   (cons 'non-eof-into-finish
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'fin 'advance #f)
                                (make-finish-node 'fin #f) (an-error 'rej)) 'default-eof)))
   (cons 'eof-reachable-stop
         (verify-of (mach 'a 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance 'stop)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))
   ;; The cycle begins at a pause continuation and the entry's
   ;; own EOF route is a finish, so the dispatch site cannot be its source.
   (cons 'eof-zero-progress-cycle
         (verify-of (mach 'pcyc 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'p 'advance 'fin)
                                (make-pause-node 'p 'q #f) (make-pause-node 'q 'p #f)
                                (make-finish-node 'fin #f) (an-error 'rej)) 'default-eof)))
   ;; --- pass-declarations ----------------------------------------------------
   ;; Each machine below is otherwise valid, so the declaration code it drives is
   ;; the reason its verification fails.
   (cons 'duplicate-callback-declaration
         (verify-of (mach/decls 'a (list (cb 'on-x 'event #f '() #f)
                                         (cb 'on-x 'event #f '() #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   (cons 'duplicate-span-declaration
         (verify-of (mach/decls 'a (list (cb 'on-d 'span-data #f '() #f))
                                (list (sp 'body 'on-d #f) (sp 'body 'on-d #f))
                                (list ed rd) (ok-nodes) 'default-eof)))
   (cons 'duplicate-branch-key
         (verify-of (mach/decls 'a (list (cb 'on-x 'decision #t '(keep keep) #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   ;; `continue` and `pause` are reserved and may not be branch keys.
   (cons 'reserved-branch-key
         (verify-of (mach/decls 'a (list (cb 'on-x 'decision #t '(continue) #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   ;; An optional decision callback with no valid default branch.
   (cons 'invalid-callback-declaration
         (verify-of (mach/decls 'a (list (cb 'on-x 'decision #f '(keep skip) #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   ;; A span names a callback that does not exist.
   (cons 'missing-callback-declaration
         (verify-of (mach/decls 'a '() (list (sp 'body 'nosuch #f))
                                (list ed rd) (ok-nodes) 'default-eof)))
   ;; The named callback exists and is the wrong KIND. This is the
   ;; cross-reference `make-span-declaration` structurally cannot check -- it
   ;; never sees the callback table.
   (cons 'invalid-span-callback
         (verify-of (mach/decls 'a (list (cb 'on-d 'event #f '() #f))
                                (list (sp 'body 'on-d #f))
                                (list ed rd) (ok-nodes) 'default-eof)))
   ;; A span-kind callback no span names: nothing can ever invoke it, because
   ;; only a span declaration reaches one.
   (cons 'unreferenced-callback-declaration
         (verify-of (mach/decls 'a (list (cb 'on-d 'span-data #f '() #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   ;; --- callback-node invocation ----------------------------------------------
   ;; The node lists a key the declaration never declared AND omits a target for
   ;; the one it did, so this fixture drives two of the code's three sites. The
   ;; third -- a node invoking a span-kind callback -- cannot be reached from
   ;; the same machine: it short-circuits before the key arms run, on purpose,
   ;; so a node naming the wrong kind reports that and not three findings about
   ;; keys it was never going to be asked for.
   (cons 'invalid-callback-invocation
         (verify-of (mach/decls 'a (list (cb 'on-x 'decision #t '(keep) #f)) '()
                                (list ed rd)
                                (list (one-case-dispatch 'start 'inv 'advance #f)
                                      (make-callback-node 'inv 'on-x 'stop
                                                          '((nosuch stop)) 'rej #f)
                                      (make-stop-node 'stop #f) (an-error 'rej))
                                'default-eof)))
   ;; --- pass 7: the span-state lattice ----------------------------------------
   ;; One fixture per code. The four transfer faults share a code, so one of
   ;; them stands for the row here; verify-tests drives all four separately and
   ;; asserts the NODE each is reported at, which this census does not.
   (cons 'invalid-span-state
         (verify-of (span-fixture (list (span-entry 'cl)
                                        (make-span-end-node 'cl 'body 'stop #f)))))
   (cons 'inconsistent-span-state
         (verify-of (span-fixture
                     (list (make-byte-dispatch-node 'start
                             (list (make-byte-case (make-exact-byte-matcher 0)
                                                   (make-edge 'op 'advance) #f)
                                   (make-byte-case (make-exact-byte-matcher 1)
                                                   (make-edge 'mrg 'advance) #f))
                             (make-edge 'rej 'reexecute) #f #f)
                           (make-span-start-node 'op 'body 'mrg #f)
                           (make-byte-dispatch-node 'mrg
                             (list (make-byte-case (make-exact-byte-matcher 0)
                                                   (make-edge 'stop 'advance) #f))
                             (make-edge 'rej 'reexecute) #f #f)))))
   (cons 'span-active-at-exit
         (verify-of (span-fixture (list (span-entry 'op)
                                        (make-span-start-node 'op 'body 'stop #f)))))
   (cons 'span-active-at-pause
         (verify-of (span-fixture (list (span-entry 'op)
                                        (make-span-start-node 'op 'body 'p #f)
                                        (make-pause-node 'p 'cl #f)
                                        (make-span-end-node 'cl 'body 'rej #f)))))
   ;; The undeclared-span cross-reference, which is `pass-declarations`' and not
   ;; pass 7's: the lattice is well defined over ANY symbol, so it treats the
   ;; name opaquely and can never notice. Built on `mach/decls` rather than
   ;; `span-fixture` because the point is a machine whose span table does NOT
   ;; contain the name the node uses.
   (cons 'missing-span-declaration
         (verify-of (mach/decls 'a (list (cb 'on-data 'span-data #t '() #f))
                                (list (sp 'body 'on-data #f))
                                (list ed rd)
                                (list (span-entry 'op)
                                      (make-span-start-node 'op 'nosuch 'cl #f)
                                      (make-span-end-node 'cl 'nosuch 'stop #f)
                                      (make-stop-node 'stop #f) (an-error 'rej))
                                'default-eof)))
   ;; A machine name outside the portable repertoire.
   (cons 'invalid-name
         (verify-of (mach 'BadName 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))))

(harness-group "every code the source can emit is produced by a fixture"
  (lambda ()
    (harness-case "each source-derived code has a machine that emits it"
      (lambda ()
        ;; `driven` counts rows asserted INSIDE the loop and is compared
        ;; against the SOURCE-DERIVED total -- never against code-fixtures'
        ;; own length, which would let a missing row and a missing code cancel.
        (let ((driven 0) (missing '()))
          (for-each
           (lambda (code)
             (let ((row (assq code code-fixtures)))
               (if (not row)
                   (set! missing (cons code missing))
                   (begin
                     (set! driven (+ driven 1))
                     (check (string-append (symbol->string code) " is emitted")
                            (and (memq code
                                       (map diagnostic-code
                                            (verification-diagnostics ((cdr row)))))
                                 #t))))))
           (distinct (census-codes the-census)))
          (check-equal "no source code lacks a fixture" missing '())
          (check-equal "and every source code was driven"
                       driven (length (distinct (census-codes the-census)))))))))

;; --- the path row -----------------------------------------------------------
;; Derived on both halves it can derive, the way the code census is: the
;; path-carrying CONSTRUCTOR set from each constructor's own parameter list, and
;; the per-constructor SITE table from the same datum walk. Only the path-bearing
;; CODE set is DECLARED, because it is a policy and not a property of the source
;; -- so this row goes red under both kinds of census mutation: a path site made
;; pathless (the site table moves) and a path site relabelled out of the set
;; (the code set moves).
(define (form-count-of ctor)
  ;; Every form whose car is `ctor`: its N call sites plus the ONE `(define
  ;; (ctor …) …)` header, which is subtracted by name below exactly as the
  ;; `quoted sites plus one header per constructor` identity subtracts it.
  (let loop ((x (car verify-src)) (n 0))
    (cond ((pair? x) (loop (cdr x) (loop (car x) (if (eq? (car x) ctor) (+ n 1) n))))
          ((vector? x) (loop (vector->list x) n))
          (else n))))
(define (site-count-of ctor) (- (form-count-of ctor) 1))
(define (constructor-formals name)
  ;; The formals of `(define (name . formals) …)`, or #f. A constructor written
  ;; `(define name (lambda …))` would return #f here and drop out of the
  ;; path-carrying set silently -- which is why every constructor uses the
  ;; `(define (name …) …)` form.
  (let loop ((x (car verify-src)))
    (cond ((not (pair? x)) #f)
          ((and (eq? (car x) 'define) (pair? (cdr x)) (pair? (cadr x))
                (eq? (car (cadr x)) name))
           (cdr (cadr x)))
          (else (or (loop (car x)) (loop (cdr x)))))))
(define path-carrying-constructors
  (filter (lambda (c) (let ((fs (constructor-formals c))) (and fs (memq 'path fs) #t)))
          diagnostic-constructors))
(define (codes-under ctors)
  ;; The quoted codes of every emission site whose constructor is in `ctors`.
  (let loop ((x (car verify-src)) (acc '()))
    (cond ((pair? x)
           (if (memq (car x) ctors)
               (let ((q (and (pair? (cdr x)) (pair? (cadr x))
                             (eq? (car (cadr x)) 'quote) (cadr (cadr x)))))
                 (loop (cdr x) (if q (cons q acc) acc)))
               (loop (cdr x) (loop (car x) acc))))
          ((vector? x) (loop (vector->list x) acc))
          (else acc))))
;; The path policy, declared rather than derived: the eight codes a path is
;; carried for, and #f everywhere else.
(define path-bearing-codes-declared
  '(eof-reachable-stop eof-zero-progress-cycle zero-progress-cycle non-eof-into-finish
    invalid-span-state inconsistent-span-state span-active-at-pause span-active-at-exit))

(harness-group "the path row is total over the census"
  (lambda ()
    (harness-case "four constructors, and the path-carrying pair derived from their arglists"
      (lambda ()
        (check-equal "four diagnostic constructors" (length diagnostic-constructors) 4)
        (check-equal "the path-carrying constructors are /edge and /path"
                     (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                                path-carrying-constructors)
                     '(make-diagnostic/edge make-diagnostic/path))))
    (harness-case "the per-constructor site table sums to the fifty-nine sites"
      (lambda ()
        (check-equal "make-diagnostic sites" (site-count-of 'make-diagnostic) 16)
        (check-equal "make-diagnostic/declarations sites"
                     (site-count-of 'make-diagnostic/declarations) 32)
        (check-equal "make-diagnostic/path sites" (site-count-of 'make-diagnostic/path) 11)
        (check-equal "make-diagnostic/edge sites" (site-count-of 'make-diagnostic/edge) 1)
        (check-equal "the site total is sixty"
                     (apply + (map site-count-of diagnostic-constructors)) 60)
        (check-equal "twelve path-carrying sites"
                     (apply + (map site-count-of path-carrying-constructors)) 12)))
    (harness-case "the path-bearing code set is exactly the declared eight codes"
      (lambda ()
        (let ((sortsym (lambda (l) (list-sort (lambda (a b) (string<? (symbol->string a)
                                                                      (symbol->string b)))
                                              l))))
          (check-equal "the codes emitted through a path constructor equal the declared policy"
                       (sortsym (distinct (codes-under path-carrying-constructors)))
                       (sortsym path-bearing-codes-declared)))))))

;; --- the committed catalog matches the census ------------------------------
;; .reference/verifier-diagnostic-catalog.md is DERIVED from THIS census. It
;; lists the code set as `- `code` — …` bullets; assert that set equals the
;; census code set, so the catalog is not one more place for the code set
;; to drift. Keyed on BYTE_MACHINE_REPO_ROOT, which the ordinary ctest lane sets
;; and the mutation suite does not — under mutation the catalog is not staged, and a
;; doc-vs-code check does not belong in a verify.sls mutation run (it would fire
;; alongside the census pins and muddy their per-pin accounting).
(define catalog-repo (adapter-environment-variable "BYTE_MACHINE_REPO_ROOT"))
(define (file->text path)
  (let ((bv (adapter-file-bytes path)))
    (let loop ((i (- (bytevector-length bv) 1)) (acc '()))
      (if (< i 0) (list->string acc)
          (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc))))))
(define (catalog-codes path)
  ;; every line "- `code` — …": the token between the first pair of backticks.
  (let loop ((ls (harness-split (file->text path) #\newline)) (acc '()))
    (cond ((null? ls) (reverse acc))
          ((and (>= (string-length (car ls)) 3)
                (string=? (substring (car ls) 0 3) "- `"))
           (let* ((rest (substring (car ls) 3 (string-length (car ls))))
                  (end (let find ((i 0))
                         (cond ((= i (string-length rest)) #f)
                               ((char=? (string-ref rest i) #\`) i)
                               (else (find (+ i 1)))))))
             (loop (cdr ls) (if end (cons (substring rest 0 end) acc) acc))))
          (else (loop (cdr ls) acc)))))

(when (and catalog-repo (not (string=? catalog-repo "")))
  (harness-group "the committed diagnostic catalog matches the census"
    (lambda ()
      (harness-case "verifier-diagnostic-catalog.md lists exactly the census codes"
        (lambda ()
          (let ((doc (list-sort string<?
                       (catalog-codes
                        (string-append catalog-repo
                          "/.reference/verifier-diagnostic-catalog.md"))))
                (census (list-sort string<?
                          (map symbol->string (distinct (census-codes the-census))))))
            (check "the catalog lists codes" (pair? doc))
            (check-equal "catalog code set = census code set" doc census)))))))

(harness-finish)
