;;; The verifier's diagnostic census: what codes exist, where they are emitted,
;;; and (Task 6b) which of them any fixture actually produces.
;;;
;;; *** This is a RATCHET, not a discovery. *** It ships green: the tree already
;;; emits all sixteen codes and the operand tables already agree. Its whole value
;;; is in the future -- a Milestone 5 or 6 slice that adds a diagnostic code, or a
;;; new emission site under an existing code, fails here until it is accounted
;;; for. Milestone 4 Slice ③ shipped three defects in which an EXISTING code went
;;; unemitted for a NEW node kind, from a site another kind already fired; this
;;; census would not have caught any of them, and the kind x position matrix is
;;; the half that does. The two are complements on disjoint axes, and neither
;;; subsumes the other.
;;;
;;; THE SET IS DERIVED FROM THE ARTIFACT, NEVER DECLARED HERE. A hardcoded list
;;; of codes in a test is itself a census that goes stale -- the exact failure
;;; this project has paid for four times (a FORTY-EIGHT PASSES banner against
;;; forty-nine, a "six state literals" census that was eight, a five-kind
;;; enumeration where there are eight, and a sweep tool that undercounted its own
;;; pins). So `verify.sls` is READ AS A DATUM and walked. The technique is
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
;; car is `make-diagnostic` whether or not its code is quoted. The two differ by
;; exactly one today -- `make-diagnostic`'s own `(define (make-diagnostic code
;; node message) ...)` header -- and that one is subtracted BY NAME below rather
;; than by hoping the arithmetic works out.
;; *** The constructor NAMES are derived, not hardcoded. *** Found by the
;; whole-branch review: with two names written into this walk, a third
;; constructor -- and every code emitted through it -- would ship unpinned and
;; untested while the census stayed green. The set is instead every `(define
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
  ;; Both constructors count. `make-diagnostic/edge` (Slice ⓪b task 5) carries
  ;; §16.4:940's edge label; it is an emission site exactly as much as the
  ;; three-argument form, and a census that missed it would under-count the
  ;; moment the tree started using it -- which is the failure this file exists
  ;; to prevent, one level up.
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

;; The pinned table. MEASURED from the walk above, not transcribed from a design
;; document, and re-measured whenever it moves. Its total is asserted separately
;; so that two rows moving in opposite directions cannot cancel.
(define pinned-sites
  '((invalid-shape 2) (duplicate-name 1) (duplicate-error-declaration 1)
    (missing-target 2) (missing-error-declaration 1) (invalid-field-declaration 2)
    (invalid-field-operand 6) (overlapping-cases 1) (ambiguous-sequence-prefix 1)
    (unreachable-node 1) (zero-progress-cycle 1) (invalid-eof-target 2)
    (non-eof-into-finish 2) (eof-reachable-stop 1) (eof-zero-progress-cycle 1)
    (invalid-name 6)
    ;; Milestone 5 Slice ①b: `pass-declarations`. Eight new codes, and
    ;; `invalid-name` goes 3 -> 6 because callback names, span names and branch
    ;; keys are all new subjects of §16.2:886 -- before this slice they sat
    ;; outside every grammar check in the tree.
    (duplicate-callback-declaration 1) (duplicate-span-declaration 1)
    (duplicate-branch-key 1) (reserved-branch-key 1)
    (invalid-callback-declaration 2) (missing-callback-declaration 2)
    (invalid-span-callback 2) (unreferenced-callback-declaration 1)))

;; *** RE-MEASURED 2026-09-03, Slice ⓪b task 2: `non-eof-into-finish` went 3 -> 1
;; and the total 31 -> 29. *** This is the ratchet FIRING, not a regression: ⓪b
;; collapsed §16.2:908's three hand-written sites -- one unconditional and
;; kind-filtered, two gated on byte-reachability, which is why they disagreed --
;; into one derived block keyed on byte-reachability. The census went red on the
;; commit that did it, which is exactly what a pinned site table is for. Slice
;; ⓪'s own plan predicted this move and named it as expected.
;;
;; Then 29 -> 30 at task 3, which ADDS a site: the zero-hop clause for an entry
;; that is itself a finish terminal. Two moves, two commits, two red runs -- the
;; table is doing its job in both directions.
;;
;; Then 28 -> 42 at Milestone 5 Slice ①b task 2, the largest single move this
;; table has taken: `pass-declarations` lands eight new codes and three new
;; `invalid-name` sites. Re-baselined in the commit that moved it, which is the
;; rule -- a census re-baselined in a separate tidying commit is a census nobody
;; checked. The site TOTAL is asserted separately from the rows precisely so a
;; move this size cannot hide two rows cancelling.
;;
;; Then 30 -> 28 at task 4, which collapses the two §16.2:909 blocks into one
;; walk over the parked set: `eof-reachable-stop` and `eof-zero-progress-cycle`
;; each go 2 -> 1. THREE re-baselines in three commits, each caught on the commit
;; that caused it. A site table that never moves is a table nobody is editing
;; underneath; one that moves silently is the defect this file exists to prevent.

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
        ;; The forms whose code is not quoted are the two constructors' own
        ;; definition headers -- `make-diagnostic` and, since Slice ⓪b task 5,
        ;; `make-diagnostic/edge`. Subtracted BY NAME and BY COUNT: if a future
        ;; site computes its code dynamically, this goes red rather than the site
        ;; slipping out of the census unnoticed.
        ;; One header per constructor, counted from the DERIVED set rather than
        ;; from the literal 2 this used to carry.
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
;; two lists are written in different files by different rules and NOTHING pinned
;; their agreement until now. verify.sls's own comment at the lookup calls a
;; mismatch "unreachable through the public API" -- which is verbatim the shape
;; of Slice ③'s first Critical, a closed-set claim in prose with no check.
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

;; --- layer 3: fixture coverage ---------------------------------------------
;; One machine per code. The loop is over the SOURCE-DERIVED key set, not over
;; this table's own keys -- that is the whole ratchet. A code added to verify.sls
;; with no row here fails "no code lacks a fixture" by name; a row here for a
;; code the source no longer emits is caught by the count row in layer 2.
;;
;; The discriminator is the CODE plus the machine's shape, never the diagnostic's
;; message text: §16.4 and verify.sls's own header forbid comparing rendered
;; text, and the texts are not unique anyway -- two pairs of sites share one, and
;; one of those pairs is where a hole was found.
(define ed (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rd (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define (an-error n) (make-error-node n 'rejected #f))
(define (one-case-dispatch name target mode eof-target)
  (make-byte-dispatch-node name
    (list (make-byte-case (make-exact-byte-matcher 0) (make-edge target mode) #f))
    (make-edge 'rej 'reexecute) eof-target #f))
(define (mach name entry fields errs nodes default-eof)
  (make-machine name entry fields '() '() errs nodes default-eof #f))
;; Milestone 5 Slice ①b: the same machine with declaration tables. Every fixture
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
   ;; Task 1's shape: the cycle begins at a pause continuation and the entry's
   ;; own EOF route is a finish, so the dispatch site cannot be its source.
   (cons 'eof-zero-progress-cycle
         (verify-of (mach 'pcyc 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'p 'advance 'fin)
                                (make-pause-node 'p 'q #f) (make-pause-node 'q 'p #f)
                                (make-finish-node 'fin #f) (an-error 'rej)) 'default-eof)))
   ;; --- Milestone 5 Slice ①b: pass-declarations -------------------------------
   ;; Each machine below is otherwise valid, so the declaration code it drives is
   ;; the reason its verification fails. Task 1 left four of these shapes as
   ;; positive CONSTRUCTION cases; here they become the rejections they were
   ;; always meant to be.
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
   ;; §16.2:902, whose content §9.3:421 fixes: `continue` and `pause` are
   ;; reserved and may not be branch keys.
   (cons 'reserved-branch-key
         (verify-of (mach/decls 'a (list (cb 'on-x 'decision #t '(continue) #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   ;; §16.2:891: optional + decision + no valid default branch.
   (cons 'invalid-callback-declaration
         (verify-of (mach/decls 'a (list (cb 'on-x 'decision #f '(keep skip) #f))
                                '() (list ed rd) (ok-nodes) 'default-eof)))
   ;; §16.2:890: a span names a callback that does not exist.
   (cons 'missing-callback-declaration
         (verify-of (mach/decls 'a '() (list (sp 'body 'nosuch #f))
                                (list ed rd) (ok-nodes) 'default-eof)))
   ;; §16.2:892: the named callback exists and is the wrong KIND. This is the
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
   ;; A machine name outside the portable repertoire.
   (cons 'invalid-name
         (verify-of (mach 'BadName 'start '() (list ed rd)
                          (list (one-case-dispatch 'start 'stop 'advance #f)
                                (make-stop-node 'stop #f) (an-error 'rej)) 'default-eof)))))

(harness-group "every code the source can emit is produced by a fixture"
  (lambda ()
    (harness-case "each source-derived code has a machine that emits it"
      (lambda ()
        ;; S4: `driven` counts rows asserted INSIDE the loop and is compared
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

(harness-finish)
