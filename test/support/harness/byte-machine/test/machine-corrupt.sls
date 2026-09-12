;;; (byte-machine test machine-corrupt): the corruption catalogue (Milestone 7
;;; Slice ④, design §4.5). Given a verified machine, an ENTRY produces a machine
;;; differing in exactly one decision -- the corruption -- and a TWIN differing in
;;; the closest LEGAL way, so the catalogue's positive half (the corruption emits
;;; the entry's diagnostic) and its negative half (the twin verifies and does not)
;;; are two edits of one machine, not two machines.
;;;
;;; A FUNCTIONAL CORE (F18, as machine-gen and machine-print are): every entry
;;; returns machines and datums and asserts NOTHING -- no `check`, no harness
;;; import, no I/O. The drive (positive containment, negative over the twin, the
;;; per-entry counts, the two totality rows) is the rejections PROGRAM's.
;;;
;;; THE CORRUPTION MECHANISM IS DATUM SURGERY (F3). Slice ③'s `print-machine`
;;; returns a datum of `(byte-machine graph)` constructor calls; an entry LOCATES
;;; the one form a fault lives in and SUBSTITUTES one operand, then `eval`s the
;;; datum in `(environment '(rnrs) '(byte-machine graph))` -- the same environment
;;; the fixture round-trip uses. So "exactly one decision" is a located
;;; substitution, and a fault the constructors REFUSE (the `constructor-refusals`
;;; table) surfaces as a raise out of `eval`, asserted rather than described (F5).
;;;
;;; THE EDIT KIT'S CONTRACT IS EXACTLY ONE (Step 3). `locate`/`edit` match forms
;;; whose car is in a family and whose operand at `match-pos` equals a literal, and
;;; raise unless exactly one form matches -- so an entry that stops locating its
;;; site is loud rather than silently a no-op. Callers match by a NAME (unique in a
;;; valid machine) at `match-pos` and edit a possibly-different `edit-pos`.
;;;
;;; THE ENTRY TABLE AND THE REFUSAL TABLE ARE HAND-WRITTEN AND EXPORTED (S2/F4), as
;;; machine-gen's draw tables and machine-print's arm tables are: a row read out of
;;; the artifact at run time would compare the artifact to itself and close nothing.
;;; `corruption-entries` is worked from the design appendix's `§16.2` ledger row by
;;; row; `constructor-refusals` is keyed by `§16.2` bullet.
(library (byte-machine test machine-corrupt)
  (export corruption-entry? make-corruption-entry
          corruption-entry-name corruption-entry-bullet corruption-entry-applies?
          corruption-entry-corrupt corruption-entry-twin corruption-entry-expected
          corruption-entries
          refusal? make-refusal refusal-bullet refusal-name refusal-thunk refusal-reason
          constructor-refusals
          ;; the edit kit, exported so the program can pin it and a reader can test it
          operand-value q locate edit all-node-ctors)
  (import (rnrs)
          (rnrs eval)
          (byte-machine private ir)
          (byte-machine test machine-print))

  ;; ---- the edit kit ---------------------------------------------------------
  ;; The literal an operand encodes: `(quote x)` -> x; a self-quoting leaf -> itself.
  (define (operand-value o)
    (if (and (pair? o) (pair? (cdr o)) (null? (cddr o)) (eq? (car o) 'quote))
        (cadr o) o))
  ;; Encode a literal as an operand datum -- machine-print's `lit`, re-derived here
  ;; so a new operand spliced in is quoted exactly as the printer would have.
  (define (q x)
    (cond ((symbol? x) (list 'quote x))
          ((or (pair? x) (null? x)) (list 'quote x))
          (else x)))

  (define all-node-ctors
    '(make-byte-dispatch-node make-sequence-dispatch-node make-stop-node
      make-error-node make-finish-node make-pause-node make-field-action-node
      make-field-branch-node make-integer-accumulate-node make-callback-node
      make-span-start-node make-span-end-node make-counted-consume-node))

  (define (form-match? d family match-pos match-val)
    (and (pair? d) (list? d) (memq (car d) family)
         (> (length d) match-pos)
         (equal? (operand-value (list-ref d match-pos)) match-val)))

  ;; Return the single matching form; raise unless exactly one.
  (define (locate datum family match-pos match-val)
    (let ((found '()))
      (let walk ((d datum))
        (when (form-match? d family match-pos match-val) (set! found (cons d found)))
        (when (pair? d) (walk (car d)) (walk (cdr d))))
      (cond ((null? found)
             (assertion-violation 'locate "no form matched" family match-pos match-val))
            ((not (null? (cdr found)))
             (assertion-violation 'locate "more than one form matched"
                                  family match-pos match-val (length found)))
            (else (car found)))))

  ;; Substitute operand `edit-pos` of the one matching form with `new` (a RAW
  ;; datum -- use `q` for a literal). Raise unless exactly one form matches.
  (define (edit datum family match-pos match-val edit-pos new)
    (let ((n 0))
      (define (sub form)
        (let loop ((i 0) (xs form))
          (cond ((null? xs) '())
                ((= i edit-pos) (cons new (loop (+ i 1) (cdr xs))))
                (else (cons (walk (car xs)) (loop (+ i 1) (cdr xs)))))))
      (define (walk d)
        (cond ((form-match? d family match-pos match-val)
               (set! n (+ n 1)) (sub d))
              ((pair? d) (cons (walk (car d)) (walk (cdr d))))
              (else d)))
      (let ((out (walk datum)))
        (unless (= n 1)
          (assertion-violation 'edit "expected exactly one match" family match-pos match-val n))
        out)))

  ;; Read the current operand at `operand-pos` of the one matching form (for edits
  ;; that extend a list rather than replace a leaf).
  (define (read-operand datum family match-pos match-val operand-pos)
    (list-ref (locate datum family match-pos match-val) operand-pos))

  ;; ---- machine <-> datum ----------------------------------------------------
  (define eval-env (environment '(rnrs) '(byte-machine graph)))
  (define (->d m) (print-machine m))
  (define (build datum) (eval datum eval-env))

  ;; ---- reading a machine's parts (for choosing edit sites) ------------------
  (define (node-names m) (map node-name (machine-nodes m)))
  (define (nodes-of m pred) (filter pred (machine-nodes m)))
  (define (first-node-of m pred)
    (let ((ns (nodes-of m pred))) (and (pair? ns) (car ns))))

  ;; ---- the entry record -----------------------------------------------------
  (define-record-type corruption-entry
    (fields name bullet applies? corrupt twin expected))
  ;; A refusal row: a thunk that must raise (`:906` has no thunk -- it records the
  ;; reason "no slot", asserted structurally by the program against ir.sls).
  (define-record-type refusal (fields bullet name thunk reason))

  ;; ---- entry constructors (private helpers over the kit) --------------------
  ;; rename declaration/node B to A (a collision) or to a fresh name (the twin).
  (define (rename-to m family names new-name)
    ;; names: the machine's names in that family; rename the SECOND to new-name.
    (build (edit (->d m) family 1 (cadr names) 1 (q new-name))))
  ;; A `dup-*` entry's twin is the pre-corruption machine itself (identity): the
  ;; closest LEGAL shape to "give two declarations one name" is the machine with
  ;; distinct names, and renaming a referenced declaration to a fresh name instead
  ;; would DANGLE its references (a different fault) rather than verify. §4.5's
  ;; "closest legal shape" is the machine that lacks exactly this fault; here that
  ;; is the accepted machine. (Structural entries in later batches get the specific
  ;; non-identity twins §4.5 names, where identity would not isolate the fault.)
  (define (identity-twin m) m)

  ;; ---- the entry table (worked from the appendix ledger, in ledger order) ---
  ;; expected pairs are derived from the bullet and confirmed against the drive;
  ;; the positive half is CONTAINMENT (collateral diagnostics are expected, F4).
  (define corruption-entries
    (list
     ;; :884 shape -- the not-a-machine half is an entry; the version half is
     ;; unconstructible (constructor-refusals / the program's unconstructible row).
     (make-corruption-entry
      'shape-not-a-machine ':884
      (lambda (m) #t)
      (lambda (m) 'not-a-machine)
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-shape #f))))
     ;; :885 duplicate declaration names -- one per namespace.
     (make-corruption-entry
      'dup-node-name ':885
      (lambda (m) (>= (length (machine-nodes m)) 2))
      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))
      identity-twin
      (lambda (m) (list (cons 'duplicate-name (car (node-names m))))))
     (make-corruption-entry
      'dup-error-declaration ':885
      (lambda (m) (>= (length (machine-errors m)) 2))
      (lambda (m) (let ((ns (map error-declaration-name (machine-errors m))))
                    (build (edit (->d m) '(make-error-declaration) 1 (cadr ns) 1 (q (car ns))))))
      identity-twin
      (lambda (m) (list (cons 'duplicate-error-declaration (car (map error-declaration-name (machine-errors m)))))))
     (make-corruption-entry
      'dup-field-name ':885
      (lambda (m) (>= (length (machine-fields m)) 2))
      (lambda (m) (let ((ns (map uint-field-name (machine-fields m))))
                    (build (edit (->d m) '(make-uint-field) 1 (cadr ns) 1 (q (car ns))))))
      identity-twin
      (lambda (m) (list (cons 'invalid-field-declaration (car (map uint-field-name (machine-fields m)))))))
     (make-corruption-entry
      'dup-callback-declaration ':885
      (lambda (m) (>= (length (machine-callbacks m)) 2))
      (lambda (m) (let ((ns (map callback-declaration-name (machine-callbacks m))))
                    (build (edit (->d m) '(make-callback-declaration) 1 (cadr ns) 1 (q (car ns))))))
      identity-twin
      (lambda (m) (list (cons 'duplicate-callback-declaration (car (map callback-declaration-name (machine-callbacks m)))))))
     (make-corruption-entry
      'dup-span-declaration ':885
      (lambda (m) (>= (length (machine-spans m)) 2))
      (lambda (m) (let ((ns (map span-declaration-name (machine-spans m))))
                    (build (edit (->d m) '(make-span-declaration) 1 (cadr ns) 1 (q (car ns))))))
      identity-twin
      (lambda (m) (list (cons 'duplicate-span-declaration (car (map span-declaration-name (machine-spans m)))))))
     ;; :886 nonportable names -- rename a node to an R6RS keyword.
     (make-corruption-entry
      'nonportable-node-name ':886
      (lambda (m) (>= (length (machine-nodes m)) 1))
      (lambda (m) (let ((ns (node-names m)))
                    (build (edit (->d m) all-node-ctors 1 (car ns) 1 (q 'if)))))
      identity-twin
      (lambda (m) (list (cons 'invalid-name 'if))))
     ;; :887 missing targets -- retarget the entry to a fresh symbol.
     (make-corruption-entry
      'missing-target-entry ':887
      (lambda (m) #t)
      (lambda (m) (build (edit (->d m) '(make-machine) 1 (machine-name m) 2 (q 'zz-ghost-entry))))
      (lambda (m) m)
      (lambda (m) (list (cons 'missing-target 'zz-ghost-entry))))
     ;; :888 missing error declaration -- an error node names an undeclared error.
     (make-corruption-entry
      'missing-error-declaration ':888
      (lambda (m) (first-node-of m error-node?))
      (lambda (m) (let ((e (first-node-of m error-node?)))
                    (build (edit (->d m) '(make-error-node) 1 (error-node-name e) 2 (q 'zz-ghost-error)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'missing-error-declaration (error-node-name (first-node-of m error-node?))))))
     ;; :907 invalid EOF target -- dangle a byte-dispatch node's eof-target.
     (make-corruption-entry
      'invalid-eof-target ':907
      (lambda (m) (first-node-of m byte-dispatch-node?))
      (lambda (m) (let ((n (first-node-of m byte-dispatch-node?)))
                    (build (edit (->d m) '(make-byte-dispatch-node) 1 (byte-dispatch-node-name n) 4 (q 'zz-ghost-eof)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-eof-target (byte-dispatch-node-name (first-node-of m byte-dispatch-node?))))))
     ;; :904 accumulation using an undeclared field.
     (make-corruption-entry
      'accumulate-field ':904
      (lambda (m) (first-node-of m integer-accumulate-node?))
      (lambda (m) (let ((n (first-node-of m integer-accumulate-node?)))
                    (build (edit (->d m) '(make-integer-accumulate-node) 1 (integer-accumulate-node-name n) 2 (q 'zz-ghost-field)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-field-operand (integer-accumulate-node-name (first-node-of m integer-accumulate-node?))))))
     ;; :890 missing callback declaration -- a callback node names an undeclared callback.
     (make-corruption-entry
      'missing-callback-declaration ':890
      (lambda (m) (first-node-of m callback-node?))
      (lambda (m) (let ((n (first-node-of m callback-node?)))
                    (build (edit (->d m) '(make-callback-node) 1 (callback-node-name n) 2 (q 'zz-ghost-cb)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'missing-callback-declaration (callback-node-name (first-node-of m callback-node?))))))
     ;; beside :901 -- a span node names an undeclared span.
     (make-corruption-entry
      'missing-span-declaration ':901
      (lambda (m) (first-node-of m span-start-node?))
      (lambda (m) (let ((n (first-node-of m span-start-node?)))
                    (build (edit (->d m) '(make-span-start-node) 1 (span-start-node-name n) 2 (q 'zz-ghost-span)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'missing-span-declaration (span-start-node-name (first-node-of m span-start-node?))))))))

  ;; ---- the refusal table (F5 row 2) -- filled in a later batch --------------
  (define constructor-refusals '()))
