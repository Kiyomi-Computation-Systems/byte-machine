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
(define (walk-diagnostics x)
  (let loop ((x x) (codes '()) (total 0))
    (cond ((pair? x)
           (if (eq? (car x) 'make-diagnostic)
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
    (non-eof-into-finish 3) (eof-reachable-stop 2) (eof-zero-progress-cycle 2)
    (invalid-name 3)))

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
        ;; The one form whose code is not quoted is `make-diagnostic`'s own
        ;; definition header. Subtracted BY NAME: if a future site computes its
        ;; code dynamically, this goes red rather than the site slipping out of
        ;; the census unnoticed.
        (check-equal "quoted sites plus the definition header"
                     (+ (length (census-codes the-census)) 1)
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

(harness-finish)
