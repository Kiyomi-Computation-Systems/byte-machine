;;; (byte-machine test machine-corrupt): the corruption catalogue. Given a
;;; verified machine, an ENTRY produces a machine differing in exactly one
;;; decision -- the corruption -- and a TWIN differing in the closest LEGAL way,
;;; so the catalogue's positive half (the corruption emits the entry's
;;; diagnostic) and its negative half (the twin verifies and does not) are two
;;; edits of one machine, not two machines.
;;;
;;; A FUNCTIONAL CORE (as machine-gen and machine-print are): every entry
;;; returns machines and datums and asserts NOTHING -- no `check`, no harness
;;; import, no I/O. The drive (positive containment, negative over the twin, the
;;; per-entry counts, the two totality rows) is the rejections PROGRAM's.
;;;
;;; THE CORRUPTION MECHANISM IS DATUM SURGERY. machine-print's `print-machine`
;;; returns a datum of `(byte-machine graph)` constructor calls; an entry LOCATES
;;; the one form a fault lives in and SUBSTITUTES one operand, then `eval`s the
;;; datum in `(environment '(rnrs) '(byte-machine graph))` -- the same environment
;;; the fixture round-trip uses. So "exactly one decision" is a located
;;; substitution, and a fault the constructors REFUSE (the `constructor-refusals`
;;; table) surfaces as a raise out of `eval`, asserted rather than described.
;;;
;;; THE EDIT KIT'S CONTRACT IS EXACTLY ONE. `locate`/`edit` match forms
;;; whose car is in a family and whose operand at `match-pos` equals a literal, and
;;; raise unless exactly one form matches -- so an entry that stops locating its
;;; site is loud rather than silently a no-op. Callers match by a NAME (unique in a
;;; valid machine) at `match-pos` and edit a possibly-different `edit-pos`.
;;;
;;; THE ENTRY TABLE AND THE REFUSAL TABLE ARE HAND-WRITTEN AND EXPORTED, as
;;; machine-gen's draw tables and machine-print's arm tables are: a row read out of
;;; the artifact at run time would compare the artifact to itself and close nothing.
;;; Every row carries a `bullet` label -- a symbol such as `:884` naming the
;;; verifier rule it exercises -- which the rejections program prints in its
;;; check labels; rows sharing a rule share a label.
(library (byte-machine test machine-corrupt)
  (export corruption-entry? make-corruption-entry
          corruption-entry-name corruption-entry-bullet corruption-entry-applies?
          corruption-entry-corrupt corruption-entry-twin corruption-entry-expected
          corruption-entries
          refusal? make-refusal refusal-bullet refusal-name refusal-thunk refusal-reason
          constructor-refusals unconstructible-codes
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

  ;; ---- machine <-> datum ----------------------------------------------------
  (define eval-env (environment '(rnrs) '(byte-machine graph)))
  (define (->d m) (print-machine m))
  (define (build datum) (eval datum eval-env))

  ;; ---- reading a machine's parts (for choosing edit sites) ------------------
  (define (node-names m) (map node-name (machine-nodes m)))
  (define (nodes-of m pred) (filter pred (machine-nodes m)))
  (define (first-node-of m pred)
    (let ((ns (nodes-of m pred))) (and (pair? ns) (car ns))))
  (define (first-branching-cb-node m)
    (find (lambda (nd) (and (callback-node? nd) (pair? (callback-node-branch-targets nd))))
          (machine-nodes m)))
  (define (optional-decision-with-default m)
    (find (lambda (c) (and (eq? (callback-declaration-kind c) 'decision)
                           (not (callback-declaration-required? c))
                           (callback-declaration-default-branch c)))
          (machine-callbacks m)))
  (define (first-decision-with-keys m)
    (find (lambda (c) (and (eq? (callback-declaration-kind c) 'decision)
                           (pair? (callback-declaration-branch-keys c))))
          (machine-callbacks m)))
  (define (span-with-data m)
    (find (lambda (s) (span-declaration-data-callback s)) (machine-spans m)))
  (define (bd-with-cases m k)
    (find (lambda (nd) (and (byte-dispatch-node? nd)
                            (>= (length (byte-dispatch-node-cases nd)) k)))
          (machine-nodes m)))
  (define (bd-with-no-eof m)
    (find (lambda (nd) (and (byte-dispatch-node? nd) (not (byte-dispatch-node-eof-target nd))))
          (machine-nodes m)))
  (define (two-spans? m) (>= (length (machine-spans m)) 2))
  (define (other-span-name m this)
    (let ((n (find (lambda (s) (not (eq? (span-declaration-name s) this))) (machine-spans m))))
      (and n (span-declaration-name n))))

  ;; ---- list-operand edits (extend / duplicate an element) -------------------
  (define (list-operand form pos)
    (let ((o (list-ref form pos)))
      (unless (and (pair? o) (eq? (car o) 'list))
        (assertion-violation 'list-operand "operand is not a (list ...)" pos o))
      o))
  ;; Append `new-form` (a raw constructor datum) to the (list ...) operand at
  ;; edit-pos of the one matching form.
  (define (extend datum family match-pos match-val edit-pos new-form)
    (let ((old (list-operand (locate datum family match-pos match-val) edit-pos)))
      (edit datum family match-pos match-val edit-pos (append old (list new-form)))))
  ;; Duplicate the first element of the (list ...) operand at edit-pos.
  (define (dup-first datum family match-pos match-val edit-pos)
    (let* ((old (list-operand (locate datum family match-pos match-val) edit-pos))
           (elts (cdr old)))
      (when (null? elts) (assertion-violation 'dup-first "empty list operand" edit-pos))
      (edit datum family match-pos match-val edit-pos (append old (list (car elts))))))

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
  ;; would DANGLE its references (a different fault) rather than verify. The
  ;; closest legal shape is the machine that lacks exactly this fault; here that
  ;; is the accepted machine. (Structural entries below get specific non-identity
  ;; twins, where identity would not isolate the fault.)
  (define (identity-twin m) m)

  ;; ---- the entry table -----------------------------------------------------
  ;; expected pairs are derived from the verifier rule and confirmed against the
  ;; drive; the positive half is CONTAINMENT (collateral diagnostics are expected).
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
     ;; An exact duplicate keyword. dup-first duplicates the first
     ;; keyword entry in the keyword-table's entries (list ...) operand (position 2).
     (make-corruption-entry
      'dup-keyword ':894
      (lambda (m) (and (first-node-of m keyword-table-node?) #t))
      (lambda (m) (let ((n (first-node-of m keyword-table-node?)))
                    (build (dup-first (->d m) '(make-keyword-table-node) 1
                                      (keyword-table-node-name n) 2))))
      identity-twin
      (lambda (m) (list (cons 'duplicate-keyword
                              (keyword-table-node-name (first-node-of m keyword-table-node?))))))
     ;; A case-insensitive fold collision. Flip the keyword-table's case-insensitive? flag (operand 5) to #t
     ;; and append two byte-DISTINCT case variants -- A (65) and a (97) -- both
     ;; routed to the first entry's EXISTING target, so no missing-target or
     ;; unreachable collateral is introduced. Under folding the two are equal, so
     ;; the table is refused with case-insensitive-keyword-collision. The twin is
     ;; the accepted machine (case-sensitive, distinct entries), which verifies.
     (make-corruption-entry
      'ci-keyword-collision ':894
      (lambda (m) (and (first-node-of m keyword-table-node?) #t))
      (lambda (m) (let* ((n (first-node-of m keyword-table-node?))
                         (nm (keyword-table-node-name n))
                         (tgt (keyword-entry-target (car (keyword-table-node-entries n))))
                         (var (lambda (b) (list 'make-keyword-entry (list 'quote (list b))
                                                (list 'quote tgt) #f))))
                    (build (extend (extend (edit (->d m) '(make-keyword-table-node) 1 nm 5 #t)
                                           '(make-keyword-table-node) 1 nm 2 (var 65))
                                   '(make-keyword-table-node) 1 nm 2 (var 97)))))
      identity-twin
      (lambda (m) (list (cons 'case-insensitive-keyword-collision
                              (keyword-table-node-name (first-node-of m keyword-table-node?))))))
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
      (lambda (m) (list (cons 'missing-span-declaration (span-start-node-name (first-node-of m span-start-node?))))))
     ;; :901 duplicate branch key -- a callback node lists one key twice.
     (make-corruption-entry
      'duplicate-branch-key ':901
      (lambda (m) (first-branching-cb-node m))
      (lambda (m) (let ((n (first-branching-cb-node m)))
                    (build (edit (->d m) '(make-callback-node) 1 (callback-node-name n) 4
                                 (q (let ((ts (callback-node-branch-targets n))) (list (car ts) (car ts))))))))
      (lambda (m) m)
      (lambda (m) (list (cons 'duplicate-branch-key (callback-node-name (first-branching-cb-node m))))))
     ;; :902 reserved branch key -- a decision callback declaration lists `continue`.
     (make-corruption-entry
      'reserved-branch-key ':902
      (lambda (m) (first-decision-with-keys m))
      (lambda (m) (let ((c (first-decision-with-keys m)))
                    (build (edit (->d m) '(make-callback-declaration) 1 (callback-declaration-name c) 4
                                 (q (cons 'continue (callback-declaration-branch-keys c)))))))
      (lambda (m) m)
      (lambda (m) (list (cons 'reserved-branch-key (callback-declaration-name (first-decision-with-keys m))))))
     ;; :901 invalid callback invocation -- a callback node names an undeclared key.
     (make-corruption-entry
      'invalid-callback-invocation ':901
      (lambda (m) (first-branching-cb-node m))
      (lambda (m) (let ((n (first-branching-cb-node m)))
                    (build (edit (->d m) '(make-callback-node) 1 (callback-node-name n) 4
                                 (q (let ((ts (callback-node-branch-targets n)))
                                      (cons (cons 'zz-bad-key (cdr (car ts))) (cdr ts))))))))
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-callback-invocation (callback-node-name (first-branching-cb-node m))))))
     ;; :891 invalid callback declaration -- clear an optional decision callback's default.
     (make-corruption-entry
      'invalid-callback-declaration ':891
      (lambda (m) (optional-decision-with-default m))
      (lambda (m) (let ((c (optional-decision-with-default m)))
                    (build (edit (->d m) '(make-callback-declaration) 1 (callback-declaration-name c) 5 #f))))
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-callback-declaration (callback-declaration-name (optional-decision-with-default m))))))
     ;; :892 invalid span callback -- a span's data callback is declared a non-span kind.
     (make-corruption-entry
      'invalid-span-callback ':892
      (lambda (m) (span-with-data m))
      (lambda (m) (let ((cb (span-declaration-data-callback (span-with-data m))))
                    (build (edit (->d m) '(make-callback-declaration) 1 cb 2 (q 'event)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-span-callback (span-declaration-name (span-with-data m))))))
     ;; beside :890 unreferenced callback declaration -- INSERT a span-data callback
     ;; no span names.
     (make-corruption-entry
      'unreferenced-callback-declaration ':890
      (lambda (m) #t)
      (lambda (m) (build (extend (->d m) '(make-machine) 1 (machine-name m) 4
                                 '(make-callback-declaration (quote zz-unref) (quote span-data) #t (quote ()) #f #f))))
      (lambda (m) m)
      (lambda (m) (list (cons 'unreferenced-callback-declaration 'zz-unref))))
     ;; :897 unreachable node -- INSERT an orphan finish node (no in-edge). The twin
     ;; inserts the SAME node but makes it reachable, by pointing
     ;; a byte-dispatch node's free (#f) eof-target at it -- an EOF accept into a
     ;; finish, legal -- so the isolated fault is reachability, not the node's
     ;; presence. Gated on a node with a free eof-target so the twin can wire it.
     (make-corruption-entry
      'unreachable-node ':897
      (lambda (m) (bd-with-no-eof m))
      (lambda (m) (build (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                 '(make-finish-node (quote zz-orphan) #f))))
      (lambda (m) (let* ((bd (bd-with-no-eof m))
                         (d1 (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                     '(make-finish-node (quote zz-orphan) #f))))
                    (build (edit d1 '(make-byte-dispatch-node) 1 (byte-dispatch-node-name bd) 4 (q 'zz-orphan)))))
      (lambda (m) (list (cons 'unreachable-node 'zz-orphan))))
     ;; :893 overlapping cases -- duplicate a byte-dispatch node's first case.
     (make-corruption-entry
      'overlapping-cases ':893
      (lambda (m) (bd-with-cases m 1))
      (lambda (m) (let ((n (bd-with-cases m 1)))
                    (build (dup-first (->d m) '(make-byte-dispatch-node) 1 (byte-dispatch-node-name n) 2))))
      (lambda (m) m)
      (lambda (m) (list (cons 'overlapping-cases (byte-dispatch-node-name (bd-with-cases m 1))))))
     ;; :894 ambiguous sequence prefix -- duplicate a sequence-dispatch node's case.
     (make-corruption-entry
      'ambiguous-sequence-prefix ':894
      (lambda (m) (first-node-of m sequence-dispatch-node?))
      (lambda (m) (let ((n (first-node-of m sequence-dispatch-node?)))
                    (build (dup-first (->d m) '(make-sequence-dispatch-node) 1 (sequence-dispatch-node-name n) 2))))
      (lambda (m) m)
      (lambda (m) (list (cons 'ambiguous-sequence-prefix (sequence-dispatch-node-name (first-node-of m sequence-dispatch-node?))))))
     ;; :898 zero-progress cycle -- a byte-dispatch node reexecutes to itself on fallback.
     (make-corruption-entry
      'zero-progress-cycle ':898
      (lambda (m) (first-node-of m byte-dispatch-node?))
      (lambda (m) (let* ((n (first-node-of m byte-dispatch-node?)) (nm (byte-dispatch-node-name n)))
                    (build (edit (->d m) '(make-byte-dispatch-node) 1 nm 3
                                 (list 'make-edge (q nm) (q 'reexecute))))))
      (lambda (m) m)
      (lambda (m) (list (cons 'zero-progress-cycle (byte-dispatch-node-name (first-node-of m byte-dispatch-node?))))))
     ;; :908 non-EOF control flow into a finish -- a byte edge (fallback) into a finish.
     (make-corruption-entry
      'non-eof-into-finish ':908
      (lambda (m) (and (first-node-of m byte-dispatch-node?) (first-node-of m finish-node?)))
      (lambda (m) (let ((n (first-node-of m byte-dispatch-node?)) (f (first-node-of m finish-node?)))
                    (build (edit (->d m) '(make-byte-dispatch-node) 1 (byte-dispatch-node-name n) 3
                                 (list 'make-edge (q (finish-node-name f)) (q 'advance))))))
      ;; twin: the same finish reached by an EOF-only edge (the
      ;; node's eof-target) rather than a byte edge -- a legal accept.
      (lambda (m) (let ((n (first-node-of m byte-dispatch-node?)) (f (first-node-of m finish-node?)))
                    (build (edit (->d m) '(make-byte-dispatch-node) 1 (byte-dispatch-node-name n) 4
                                 (q (finish-node-name f))))))
      (lambda (m) (list (cons 'non-eof-into-finish (byte-dispatch-node-name (first-node-of m byte-dispatch-node?))))))
     ;; :908 EOF-only zero-progress cycle -- a byte-dispatch node's eof-target is itself.
     (make-corruption-entry
      'eof-zero-progress-cycle ':908
      (lambda (m) (first-node-of m byte-dispatch-node?))
      (lambda (m) (let* ((n (first-node-of m byte-dispatch-node?)) (nm (byte-dispatch-node-name n)))
                    (build (edit (->d m) '(make-byte-dispatch-node) 1 nm 4 (q nm)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'eof-zero-progress-cycle (byte-dispatch-node-name (first-node-of m byte-dispatch-node?))))))
     ;; :909 EOF-reachable stop -- point a byte-dispatch node's FREE (#f) eof-target
     ;; at a stop, so an EOF route reaches a stop terminal. The twin points the same
     ;; free eof route at a fresh finish instead (below), so neither half orphans an
     ;; existing eof-target.
     (make-corruption-entry
      'eof-reachable-stop ':909
      (lambda (m) (and (bd-with-no-eof m) (first-node-of m stop-node?)))
      (lambda (m) (let ((n (bd-with-no-eof m)) (s (first-node-of m stop-node?)))
                    (build (edit (->d m) '(make-byte-dispatch-node) 1 (byte-dispatch-node-name n) 4
                                 (q (stop-node-name s))))))
      ;; twin: the same free EOF route reaching a FRESH finish -- a legal EOF accept
      ;; with a single in-edge, so it carries no span-state entanglement (an existing
      ;; error node would, and route to it reads as inconsistent-span-state instead).
      (lambda (m) (let* ((n (bd-with-no-eof m))
                         (d1 (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                     '(make-finish-node (quote zz-eof-ok) #f))))
                    (build (edit d1 '(make-byte-dispatch-node) 1 (byte-dispatch-node-name n) 4 (q 'zz-eof-ok)))))
      (lambda (m) (list (cons 'eof-reachable-stop (byte-dispatch-node-name (bd-with-no-eof m))))))
     ;; :899 invalid span state -- a span-end node names a different span.
     (make-corruption-entry
      'invalid-span-state ':899
      (lambda (m) (and (first-node-of m span-end-node?) (two-spans? m)))
      (lambda (m) (let* ((n (first-node-of m span-end-node?))
                         (other (other-span-name m (span-end-node-span n))))
                    (build (edit (->d m) '(make-span-end-node) 1 (span-end-node-name n) 2 (q other)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'invalid-span-state (span-end-node-name (first-node-of m span-end-node?))))))
     ;; :900 span active at pause -- INTERPOSE a fresh pause on the span's own path
     ;; (span-start -> new pause -> the start's old successor), so the pause is
     ;; reached with the span open and has a single, span-active in-edge.
     (make-corruption-entry
      'span-active-at-pause ':900
      (lambda (m) (first-node-of m span-start-node?))
      (lambda (m) (let* ((s (first-node-of m span-start-node?))
                         (nm (span-start-node-name s))
                         (old-next (span-start-node-next s))
                         (d1 (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                     (list 'make-pause-node (q 'zz-inspan-pause) (q old-next) #f))))
                    (build (edit d1 '(make-span-start-node) 1 nm 3 (q 'zz-inspan-pause)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'span-active-at-pause 'zz-inspan-pause))))
     ;; :907 span active at exit -- INTERPOSE a fresh finish on the span's own path,
     ;; so a successful EOF exit is reached with the span still open (one in-edge).
     (make-corruption-entry
      'span-active-at-exit ':907
      (lambda (m) (first-node-of m span-start-node?))
      (lambda (m) (let* ((s (first-node-of m span-start-node?))
                         (nm (span-start-node-name s))
                         (d1 (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                     (list 'make-finish-node (q 'zz-exit-finish) #f))))
                    (build (edit d1 '(make-span-start-node) 1 nm 3 (q 'zz-exit-finish)))))
      (lambda (m) m)
      (lambda (m) (list (cons 'span-active-at-exit 'zz-exit-finish))))
     ;; :899 inconsistent span state -- a span-start jumps to an EXISTING pause that
     ;; keeps its own (span-closed) in-edge, so the pause is reached with two
     ;; different active-span sets (the merge disagreement).
     (make-corruption-entry
      'inconsistent-span-state ':899
      (lambda (m) (and (first-node-of m span-start-node?) (first-node-of m pause-node?)))
      (lambda (m) (let ((s (first-node-of m span-start-node?)) (p (first-node-of m pause-node?)))
                    (build (edit (->d m) '(make-span-start-node) 1 (span-start-node-name s) 3
                                 (q (pause-node-name p))))))
      (lambda (m) m)
      (lambda (m) (list (cons 'inconsistent-span-state (pause-node-name (first-node-of m pause-node?))))))))

  ;; ---- the refusal table ---------------------------------------------------
  ;; Faults the PUBLIC constructors refuse, so no machine can carry them and the
  ;; catalogue reaches them only as a raise. Each thunk performs the refused
  ;; construction by evaluating a `(byte-machine graph)` call in `eval-env` (graph
  ;; re-exports ir.sls's validated constructors, which raise a contract violation
  ;; whose `who` is the constructor). `:906` has NO thunk: terminal constructors
  ;; take name and source-label only -- there is no out-edge slot to give -- so the
  ;; row records the reason and the program asserts it structurally against ir.sls.
  (define constructor-refusals
    (list
     (make-refusal ':895 'byte-dispatch-no-fallback
       (lambda () (eval '(make-byte-dispatch-node 'zz (list) #f #f #f) eval-env))
       "make-byte-dispatch-node requires an edge fallback (§16.2:895)")
     (make-refusal ':895 'sequence-dispatch-no-fallback
       (lambda () (eval '(make-sequence-dispatch-node 'zz (list (make-sequence-case '(65) 'x #f)) #f #f #f) eval-env))
       "make-sequence-dispatch-node requires an edge mismatch fallback (§16.2:895)")
     (make-refusal ':896 'edge-mode-outside-closed-set
       (lambda () (eval '(make-edge 'x 'not-a-mode) eval-env))
       "make-edge's mode must be advance or reexecute (§16.2:896)")
     (make-refusal ':889 'uint-field-bad-width
       (lambda () (eval '(make-uint-field 'f 7 0 #f) eval-env))
       "make-uint-field's width must be 8/16/32/64 (§16.2:889 width half)")
     (make-refusal ':889 'uint-field-bad-initial
       (lambda () (eval '(make-uint-field 'f 8 999 #f) eval-env))
       "make-uint-field's initial must fit the width (§16.2:889 initial half)")
     (make-refusal ':889 'field-action-bad-operation
       (lambda () (eval '(make-field-action-node 'fa 'not-an-op '() 'nx #f #f) eval-env))
       "make-field-action-node rejects arbitrary operation names (§16.2:889 operation half)")
     (make-refusal ':904 'integer-accumulate-bad-base
       (lambda () (eval '(make-integer-accumulate-node 'a 'fld 7 'd (make-edge 'x 'advance) 'err 'e #f) eval-env))
       "make-integer-accumulate-node's base must be 10 or 16 (§16.2:904 base half)")
     (make-refusal ':906 'terminal-out-edge #f
       "terminal node constructors (make-stop-node/make-finish-node/make-error-node) take name and source-label only -- there is no out-edge slot to give")))

  ;; ---- the unconstructible list -------------------------------------------
  ;; Census codes reachable neither by a catalogue entry nor by a constructor
  ;; refusal, so this corruption catalogue -- which corrupts ACCEPTED machines --
  ;; never produces them. Two members:
  ;;   - `invalid-shape` via its unsupported-version half --
  ;;     `verify-tests.sps` forges such a descriptor with a test-only vector, and
  ;;     this catalogue does not. Its NOT-a-machine half IS an entry
  ;;     (`shape-not-a-machine`).
  ;;   - `settable-consume-counter`: a settable
  ;;     field used as a counted-consume counter. It IS constructible through the
  ;;     public API, but no corruption of an accepted machine makes a field
  ;;     settable, so the catalogue cannot reach it; `diagnostic-census-tests.sps`
  ;;     and `verify-tests.sps` cover it directly.
  ;; The code sentinel adds these codes to the entry codes' union.
  (define unconstructible-codes '(invalid-shape settable-consume-counter)))
