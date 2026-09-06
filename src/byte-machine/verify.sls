;;; (byte-machine verify): structural verification of a source machine into a
;;; verification-result carrying diagnostics and the machine (parent §16). M1
;;; subset of §16.2/§16.3: schema, name resolution (nodes + error references),
;;; overlap over canonical matcher byte sets, reachability, zero-progress
;;; cycles, terminal/EOF shape, and generated-name safety (reserved-set
;;; member 1 — Gate 0 §3.3). Error references are symbolic names resolved
;;; against the error declarations.
;;; Milestone 3 Slice ② added the sixth node kind, sequence-dispatch (§9.1:297,
;;; §10.6:542-546), to every one of these passes EXCEPT overlap: its case
;;; targets and mismatch edge are out-targets and eof-targets for name
;;; resolution and reachability, its mismatch edge's reexecute mode joins the
;;; zero-progress walk, and its eof-target joins the EOF-shape and :908/:909
;;; terminal checks. Milestone 3 Slice ③ added pass-sequence-ambiguity
;;; (§16.2:894) and taught pass-zero-progress's REPORT set the sixth kind
;;; (§25:1533), so a sequence node whose reexecute mismatch edge reaches itself
;;; is now a zero-progress cycle rather than a hang. Cross-alternative sequence
;;; collision stays out of pass-overlap permanently -- it is :894's, not
;;; :893's; see pass-overlap's own filter.
;;; Diagnostics are compared by code, never by text.
(library (byte-machine verify)
  (export verify-machine verification-ok? verification-diagnostics
          verification-machine
          diagnostic? diagnostic-code diagnostic-node diagnostic-message
          diagnostic-edge)
  (import (rnrs)
          (byte-machine private ir)
          (byte-machine private names))

  ;; --- diagnostics ---
  (define diagnostic-tag (vector 'byte-machine-diagnostic))
  ;; §16.4:940 asks for "node and edge/source label where applicable". The label
  ;; half was implemented nowhere: three arguments at every call site. The record
  ;; now carries it, `#f` when it does not apply, so two findings from one node --
  ;; a `case` edge and a `fallback` edge into the same finish terminal -- stop
  ;; being the identical record.
  (define (make-diagnostic code node message) (vector diagnostic-tag code node message #f))
  (define (make-diagnostic/edge code node message edge)
    (vector diagnostic-tag code node message edge))
  (define (diagnostic? x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) diagnostic-tag)))
  (define (diagnostic-code d) (vector-ref d 1))
  (define (diagnostic-node d) (vector-ref d 2))
  (define (diagnostic-message d) (vector-ref d 3))
  (define (diagnostic-edge d) (vector-ref d 4))

  ;; --- name grammar [a-z][a-z0-9-]* and reserved-set member 1 ---
  ;; The grammar is (byte-machine private names)' `portable-name?` since
  ;; Milestone 6 Slice ⓪ -- one body shared with compile.sls's binding check and
  ;; runtime.sls's callback-code check, where this file's copy was one of two
  ;; textually identical bodies through Milestone 5. Member 1 stays here: which
  ;; reserved set applies is a property of the site, and a declared NAME is
  ;; barred from the R6RS syntactic keywords only.
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  (define (valid-name? sym)
    (and (portable-name? sym)
         (not (memq sym reserved-member-1))))
  ;; §10.1:480 restricts an error declaration's static reason to printable ASCII
  ;; plus LF. That is a DIFFERENT repertoire from valid-name?'s, over a string
  ;; rather than a symbol, so this cannot reuse that predicate -- it reuses the
  ;; invalid-name CODE, which §16.2:886 licenses by putting reasons in one
  ;; portability bullet with names and codes, so Milestone 4's two-new-codes
  ;; budget holds. The check was inert until Slice ①a, because the emitter had
  ;; never written a user-controlled string; now a nonportable reason is an
  ;; unparseable generated library, not a cosmetic defect. An EMPTY reason is
  ;; accepted: :480 says nothing about length, "" renders as a legal string
  ;; literal, and make-error-declaration already refuses a non-string.
  (define (reason-char? c)
    (or (and (char>=? c #\space) (char<=? c #\~)) (char=? c #\newline)))
  (define (valid-reason? s)
    (let loop ((i 0))
      (or (>= i (string-length s))
          (and (reason-char? (string-ref s i)) (loop (+ i 1))))))
  ;; §16.2:886's LABEL clause. Milestone 5 Slice ④ built it for its two new
  ;; declaration families only (design §4.12 item 2, 2026-09-04); Milestone 6
  ;; Slice ⓪ made it TOTAL over every `source-label` in the tree -- nineteen
  ;; carriers, checked at four arms in two passes: `pass-names-valid`'s machine
  ;; arm, its node arm (the node's own label AND its byte or sequence cases'
  ;; labels, reported under the owning node because a case has no name), its
  ;; error-declaration arm, and `pass-fields`' field arm, beside the two
  ;; declaration arms in `pass-declarations`. It is a second CALL SITE of
  ;; `valid-reason?` rather than a second predicate: §10.1:480 puts labels and
  ;; reasons in ONE sentence under ONE repertoire, and a duplicated
  ;; `reason-char?` would be two textually identical bodies -- the twinned-FIND
  ;; trap this file already records.
  ;;
  ;; *** THE WARRANT IS §16.2:886, NOT §10.1:480'S STATED PURPOSE. *** :480
  ;; qualifies itself -- "labels and reasons embedded in GENERATED OUTPUT" --
  ;; and measured, a label is embedded in nothing: `compile.sls` reads no
  ;; source-label at all, so unlike a nonportable reason (which since Slice ①a
  ;; is an unparseable generated library) a nonportable label cannot corrupt
  ;; emission today. What it can corrupt is §16.4:940's diagnostic report -- "node
  ;; and edge/source label where applicable" -- and THAT REPORT DOES NOT EXIST
  ;; YET: measured, nothing in `src/` reads a declaration's source-label except
  ;; this pass, so today the field is carried and never consumed.
  ;; :886 requires the rejection either way and that is the reason this ships;
  ;; saying so here keeps the next reader from inheriting a stronger claim than
  ;; the tree supports.
  ;;
  ;; THREE VALUE SHAPES, and the plan settles only the first. §10.3:506 and
  ;; §10.4:517 say "optional diagnostic label" and give no type, and no
  ;; constructor validates the field. Every label that PREDATES this check is a
  ;; symbol (`ir-tests.sps`'s `the-label`) -- but "every label in the tree is a
  ;; symbol" is not true and was written here once: this check's own fixtures
  ;; carry string labels, which is what made the string arm worth asserting in
  ;; both directions rather than leaving hypothetical. `#f` is absence and passes. A symbol or a
  ;; string is checked against the repertoire. Anything else is REJECTED here
  ;; rather than ignored -- a label the diagnostic reporter cannot render is not
  ;; a machine that verified clean -- but that is a shape fault reported under a
  ;; portability code, which is the one judgment §4.12 item 2 does not settle.
  (define (valid-label? l)
    (cond ((eq? l #f) #t)
          ((symbol? l) (valid-reason? (symbol->string l)))
          ((string? l) (valid-reason? l))
          (else #f)))

  ;; --- helpers ---
  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (error-names m) (map error-declaration-name (machine-errors m)))
  ;; The successors of a ZERO-WIDTH node -- one fact, three consumers
  ;; (`node-out-targets`, `reexec-targets` and `eof-successors`), defined once.
  ;; Triplicating it is not an option: the arms are textually identical, so a
  ;; mutation pinning one resolves to three sites and the suite hard-fails at
  ;; declaration -- measured, and it is the SITES-fails-both-directions trap
  ;; AGENTS.md names. Factoring it does NOT collapse three decisions into one:
  ;; each caller's arm -- whether it consults this at all -- stays its own
  ;; mutable line, and only the shared fact, "what does a zero-width node
  ;; continue to", lives here.
  ;; Slice ⓪b task 5 carries §16.4:940's edge ROLE alongside each target. The
  ;; census stays here, singular: `zero-width-edges` is the fact, and both
  ;; `zero-width-successors` and `node-out-edges` are views of it. Attaching the
  ;; roles in `node-out-edges` instead would have recomputed a field action's
  ;; successors in a second place -- the duplication this comment already forbids.
  (define (zero-width-edges n)
    (cond ((pause-node? n) (list (cons 'continuation (pause-node-continuation n))))
          ;; A field action's `error` is a successor exactly when it has one:
          ;; the constructor makes it #f precisely when the operation cannot
          ;; fail, so this never yields a node no failure can reach.
          ((field-action-node? n)
           (let ((e (field-action-node-error n)))
             (if (symbol? e)
                 (list (cons 'next (field-action-node-next n)) (cons 'error e))
                 (list (cons 'next (field-action-node-next n))))))
          ((field-branch-node? n)
           (list (cons 'true (field-branch-node-true-target n))
                 (cons 'false (field-branch-node-false-target n))))
          ;; The tenth kind (Slice ②). Zero-width by §11.4:652, and the first
          ;; with a VARIABLE number of out-edges: §10.6:584-586 gives it a
          ;; continue target, a pause continuation, and one target per declared
          ;; decision branch. All three roles are successors on the byte side --
          ;; a resumed pause continues during feed exactly as a continue does --
          ;; so all three belong to this one census.
          ;;
          ;; The three roles are named for §13:803-808's three non-failing
          ;; OUTCOMES, which is what selects among them at run time. The branch
          ;; role is deliberately not the branch KEY: a role is §16.4:940's edge
          ;; label and this file's roles are a closed vocabulary the kind x
          ;; position matrix maps (axis A'), so keying it by an
          ;; application-chosen symbol would make that vocabulary open and the
          ;; matrix underivable.
          ;; The eleventh and twelfth kinds (Slice ③). Both are zero-width
          ;; (§10.6:590, :594, "without consuming input") and both have exactly
          ;; ONE successor, so both reuse the `next` role a field action already
          ;; carries rather than minting two roles that would say the same thing.
          ;; A diagnostic naming a node AND the role `next` is unambiguous; the
          ;; role vocabulary this file keeps is closed on purpose, and the kind x
          ;; position matrix maps it (axis A').
          ((span-start-node? n) (list (cons 'next (span-start-node-next n))))
          ((span-end-node? n) (list (cons 'next (span-end-node-next n))))
          ((callback-node? n)
           (append (list (cons 'continue (callback-node-continue-target n)))
                   (map (lambda (b) (cons 'branch (cadr b)))
                        (callback-node-branch-targets n))
                   (list (cons 'pause (callback-node-pause-continuation n)))))
          (else '())))

  (define (zero-width-successors n) (map cdr (zero-width-edges n)))

  ;; *** ONE census, two views (Slice ⓪b task 5). *** `node-out-edges` is the
  ;; census -- every byte out-edge as a `(role . target)` pair -- and
  ;; `node-out-targets` is a derived view of it. Duplicating the cond to attach
  ;; roles would have made a second census of exactly the kind this slice spent
  ;; two tasks removing.
  ;;
  ;; The role is §16.4:940's "edge/source label where applicable", which
  ;; `make-diagnostic`'s three arguments implemented nowhere. It is a ROLE, not
  ;; an index: verify.sls declines elsewhere to promise the order of two
  ;; diagnostics from one node, and an index would newly promise it.
  (define (node-out-edges n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (cons 'case (edge-target (byte-case-edge c))))
                        (byte-dispatch-node-cases n))
                   (list (cons 'fallback (edge-target (byte-dispatch-node-fallback n))))))
          ;; A pause's single zero-width out-edge (§10.6): resolution-checked by
          ;; PASS 2 (a malformed continuation is 'missing-target, §16.2:905) and
          ;; walked by reachability. Since Slice ⓪b the §16.2:908 check is gated
          ;; on byte-reachability rather than on a source-kind filter, so this arm
          ;; DOES feed it -- a byte-reachable pause continuing into a finish is
          ;; rejected, and an EOF-only one is not.
          ((pause-node? n) (zero-width-edges n))
          ((sequence-dispatch-node? n)
           (append (map (lambda (c) (cons 'alternative (sequence-case-target c)))
                        (sequence-dispatch-node-cases n))
                   (list (cons 'mismatch
                               (edge-target (sequence-dispatch-node-mismatch n))))))
          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (zero-width-edges n))
          ;; Integer accumulate (Slice ③). Three of its four explicit targets are
          ;; BYTE out-targets; the fourth, `eof-target`, is not -- it belongs to
          ;; node-eof-target below.
          ((integer-accumulate-node? n)
           (list (cons 'digit (integer-accumulate-node-digit-target n))
                 (cons 'nondigit
                       (edge-target (integer-accumulate-node-nondigit-edge n)))
                 (cons 'overflow (integer-accumulate-node-overflow-error n))))
          ;; Counted consume (Milestone 6 Slice ①). Its one explicit target is
          ;; the byte edge taken after a commit, role `next`; its eof-target is
          ;; node-eof-target's, as accumulate's is. A zero count reaches `next`
          ;; without a byte as well -- that route is `eof-successors`' and
          ;; `reexec-targets`' (decision 0030 items 5 and 7), not this one's.
          ((counted-consume-node? n)
           (list (cons 'next (counted-consume-node-next n))))
          (else '())))

  (define (node-out-targets n) (map cdr (node-out-edges n)))
  ;; A dispatch/sequence node's stored eof-target (a symbol, or #f meaning
  ;; "the machine default eof error"), or #f for any other node kind. Fix
  ;; wave 1 (Important 3): the single source of "node kind -> eof-target
  ;; accessor" for the three sites below that were previously independent,
  ;; byte-identical or near-identical copies of the same cond. eof-terminal's
  ;; two parallel cond arms (below) are left as their own arms, not routed
  ;; through this helper -- see the comment there for why.
  (define (node-eof-target n)
    (cond ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
          ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
          ;; Slice ③: an accumulate node declares its own EOF edge (§10.6:569),
          ;; with #f meaning the machine default -- the byte-dispatch convention.
          ((integer-accumulate-node? n) (integer-accumulate-node-eof-target n))
          ;; Milestone 6 Slice ①: the fourth input-reading kind, same convention.
          ((counted-consume-node? n) (counted-consume-node-eof-target n))
          (else #f)))
  ;; byte out-targets PLUS a dispatch/sequence node's eof-target (for
  ;; reachability only).
  (define (all-out-targets n)
    (append (node-out-targets n)
            (let ((t (node-eof-target n)))
              (if (symbol? t) (list t) '()))))

  ;; Visited-set DFS from the machine's entry, following whatever edge
  ;; function `targets` selects (node-out-targets, all-out-targets, ...).
  ;; Returns the reached node names. Shared by pass-reachability and
  ;; byte-reached, which differ only in which edge function they walk.
  (define (reach-from m targets)
    (let ((nodes (machine-nodes m)) (reached '()))
      (let visit ((name (machine-entry m)))
        (let ((n (lookup nodes name)))
          (when (and n (not (memq name reached)))
            (set! reached (cons name reached))
            (for-each visit (targets n)))))
      reached))

  ;; PASS 1: schema.
  ;; PASS 1: §16.2:884 — invalid descriptor shapes AND unsupported IR versions.
  ;; The version half was listed and unimplemented through Milestone 3 because
  ;; the version had no accessor; Slice ①b gives it one. Both halves report
  ;; `invalid-shape`: §16.2:884 states them as one bullet, and §4.6's
  ;; two-new-codes budget for this milestone is spent on the field codes.
  (define (pass-schema m)
    (cond ((not (machine? m))
           (list (make-diagnostic 'invalid-shape #f "not a machine")))
          ((not (= (machine-ir-version-of m) supported-ir-version))
           (list (make-diagnostic 'invalid-shape #f "unsupported IR version")))
          (else '())))

  ;; PASS 2: name resolution — duplicate node names; duplicate error names; every
  ;; transition target and error reference resolves.
  (define (pass-names m)
    (let ((nodes (machine-nodes m)) (enames (error-names m)))
      (append
       (let loop ((ns nodes) (seen '()) (out '()))
         (if (null? ns) (reverse out)
             (let ((nm (node-name (car ns))))
               (loop (cdr ns) (cons nm seen)
                     (if (memq nm seen)
                         (cons (make-diagnostic 'duplicate-name nm "duplicate node name") out)
                         out)))))
       (let loop ((es enames) (seen '()) (out '()))
         (if (null? es) (reverse out)
             (loop (cdr es) (cons (car es) seen)
                   (if (memq (car es) seen)
                       (cons (make-diagnostic 'duplicate-error-declaration (car es)
                                              "duplicate error declaration name") out)
                       out))))
       (apply append
              (map (lambda (n)
                     (filter values
                             (map (lambda (t)
                                    (if (lookup nodes t) #f
                                        (make-diagnostic 'missing-target t "no such node")))
                                  (node-out-targets n))))
                   nodes))
       (if (lookup nodes (machine-entry m)) '()
           (list (make-diagnostic 'missing-target (machine-entry m) "entry names no node")))
       (apply append
              (map (lambda (n)
                     (if (and (error-node? n) (not (memq (error-node-error-name n) enames)))
                         (list (make-diagnostic 'missing-error-declaration (node-name n)
                                                "error node names an undeclared error"))
                         '()))
                   nodes)))))

  ;; PASS 6a (DECLARATION HALF ONLY): field declarations — §16.3:924 item 6,
  ;; carrying exactly the checks decision 0020 assigns to the verifier. A field's
  ;; WIDTH and its INITIAL's range are constructor contracts, rejected at
  ;; `make-uint-field` and unrepresentable thereafter (0020's one-rejection-site
  ;; rule), so an arm here for either would be unreachable code that no test
  ;; could redden. What is left is RELATIONAL and therefore cannot live in a
  ;; constructor that sees one field at a time: two fields sharing a name, and a
  ;; name outside §10.1:480's portable repertoire.
  ;;
  ;; Both report `invalid-field-declaration` (§4.6's two-code budget for this
  ;; milestone; the second, `invalid-field-operand`, is Slice ②'s) with the
  ;; offending FIELD name in the diagnostic's `node` slot — the slot is the
  ;; identifying name of whatever the diagnostic is about, which for a field
  ;; diagnostic is the field.
  ;;
  ;; This is a pass of its own rather than two more arms on `pass-names` and
  ;; `pass-names-valid`, so that those two keep the pin-visible shape they were
  ;; measured with, and so Slice ② has one place to add the operand half.
  ;; `valid-name?` is reused exactly as `pass-names-valid` uses it: fields sit in
  ;; the same generated namespace as nodes and errors and get the same grammar,
  ;; not a parallel one that could drift.
  (define (pass-fields m)
    (let ((fs (machine-fields m)))
      (append
       ;; The loop variables are named apart from `pass-names`' node-duplicate
       ;; loop on purpose: the two walks are the same shape, and cloning its
       ;; identifiers would give this file two textually identical `(memq nm
       ;; seen)` lines, which is one FIND that this suite's mutations resolve to
       ;; TWO sites -- measured, and it silently mutates the node check too.
       (let scan ((rest fs) (fseen '()) (out '()))
         (if (null? rest) (reverse out)
             (let ((fname (uint-field-name (car rest))))
               (scan (cdr rest) (cons fname fseen)
                     (if (memq fname fseen)
                         (cons (make-diagnostic 'invalid-field-declaration fname
                                                "duplicate field name") out)
                         out)))))
       ;; Milestone 6 Slice ⓪ folds §16.2:886's label clause into this arm's
       ;; test, the shape the error-declaration arm of `pass-names-valid` set:
       ;; one finding for a field bad in name or label, and no new emission site.
       (filter values
               (map (lambda (f)
                      (if (and (valid-name? (uint-field-name f))
                               (valid-label? (uint-field-source-label f)))
                          #f
                          (make-diagnostic 'invalid-field-declaration (uint-field-name f)
                                           "field name or label is not portable")))
                    fs))
       (pass-field-operands m fs))))

  ;; --- the OPERAND half (Milestone 4 Slice ②; §16.3:924 item 6, decision 0020
  ;; item 3). Everything here needs a SECOND object -- the field declaration --
  ;; to evaluate at all, which is precisely why none of it is a constructor
  ;; contract. The constructor closed what one node can answer: the operation and
  ;; predicate sets, and `arguments` being a proper list. Everything below is
  ;; relational.
  ;;
  ;; It lives INSIDE pass-fields rather than in a pass of its own. Slice ①b built
  ;; this pass for it and records that in the tree; a sibling pass would duplicate
  ;; an indentation-anchored line that `verify: pass-fields is never run` pins at
  ;; SITES=1, and would leave Slice ③'s accumulate share two candidate homes.
  ;;
  ;; ONE code, `invalid-field-operand`, which spends §4.6's two-new-codes budget
  ;; for this milestone. *** Slice ③'s accumulate share reuses it with NO NEW
  ;; CODE and extends THIS pass -- there is deliberately one candidate home, not
  ;; two, and `field-operand-schemas` below is where its rows go. ***
  (define field-operand-schemas
    ;; (name arity . operand-kinds-after-the-field), tabulated from §9.1:328-334
    ;; and :336-346. Position 0 is the `field` in every one of the fourteen, which
    ;; is why it is not repeated per row.
    '((store 2 constant) (clear 1) (increment 1) (decrement 1) (add 2 constant)
      (set-mask 2 mask) (clear-mask 2 mask)
      (equal 2 constant) (zero 1) (nonzero 1) (range 3 low high)
      (mask-any 2 mask) (mask-all 2 mask) (mask-none 2 mask)))

  (define (field-width-of fs name)
    (let loop ((fs fs))
      (cond ((null? fs) #f)
            ((eq? (uint-field-name (car fs)) name) (uint-field-width (car fs)))
            (else (loop (cdr fs))))))

  (define (operand-in-width? v width)
    (and (integer? v) (exact? v) (<= 0 v (- (expt 2 width) 1))))

  ;; One node's operands. Reported under the node's OWN name, not the field's:
  ;; an operand fault is a property of the site that wrote it, and the field it
  ;; names may not exist.
  (define (field-operand-diagnostics fs name selector args)
    (let ((row (assq selector field-operand-schemas)))
      (cond
       ;; Unreachable through the public API -- the constructor closed both
       ;; enumerations -- and answered rather than raised, because a verifier
       ;; that raises cannot accumulate.
       ((not row)
        (list (make-diagnostic 'invalid-field-operand name "unknown operation or predicate")))
       ((not (= (length args) (cadr row)))
        ;; §9.1:348's "exact arity ... it rejects extra arguments". Reported
        ;; alone: nothing can be read out of `arguments` before arity is known,
        ;; which is the same sentence that put this check here rather than in the
        ;; constructor.
        (list (make-diagnostic 'invalid-field-operand name "wrong number of operands")))
       (else
        (let ((width (field-width-of fs (car args))))
          (cond
           ((not width)
            (list (make-diagnostic 'invalid-field-operand name
                                   "operand names no declared field")))
           (else
            (append
             (filter values
                     (map (lambda (v)
                            (if (operand-in-width? v width) #f
                                (make-diagnostic 'invalid-field-operand name
                                                 "operand is outside the field's declared width")))
                          (cdr args)))
             ;; `low <= high` for `range` -- decision 0020 item 2 names this as
             ;; the consequence that looks wrong to a reader of 0017, which
             ;; rejects `low > high` inside make-byte-range-matcher. There they
             ;; are named parameters; here they are list positions the
             ;; constructor may not read before arity is known.
             (if (and (eq? selector 'range)
                      (operand-in-width? (cadr args) width)
                      (operand-in-width? (caddr args) width)
                      (> (cadr args) (caddr args)))
                 (list (make-diagnostic 'invalid-field-operand name
                                        "range low exceeds high"))
                 '())))))))))

  ;; Slice ③'s accumulate share (D3). A SIBLING ARM, not a
  ;; `field-operand-schemas` row: that table is keyed on a SELECTOR and an ARITY,
  ;; and an accumulate node has `field` and `base` and neither. Slice ②'s promise
  ;; of one home is kept -- this lives in `pass-fields` and reuses
  ;; `invalid-field-operand`, so §4.6's spent two-code budget holds.
  ;;
  ;; Only the FIELD REFERENCE: the base is closed at construction (§16.2:904's
  ;; base half), so an arm for it here would be dead code whose permissive
  ;; mutation survives. Reported under the NODE's name, matching the convention
  ;; the operand walk above already states -- design §8 prescribes the field
  ;; name, which would put two conventions under one code.
  (define (accumulate-operand-diagnostics fs n)
    (if (field-width-of fs (integer-accumulate-node-field n))
        '()
        (list (make-diagnostic 'invalid-field-operand (node-name n)
                               "accumulate names no declared field"))))

  ;; §16.2:903, Milestone 6 Slice ①: "counted consume using an incompatible
  ;; field". Its own arm beside accumulate's and not folded into it -- Milestone
  ;; 4's design drew that boundary (":903 arrives with its own construct and its
  ;; own check, and inherits nothing") -- reusing the CODE, which is the
  ;; precedent accumulate set. Only the field reference: one field type exists
  ;; (§10.2:489) and §29:1754 defers more, so every declared field is a count a
  ;; consume can draw from and "incompatible" reduces to "undeclared" (design
  ;; §4.3). When a second field type arrives, this arm is where :903 gains
  ;; content. Reported under the NODE's name, on the operand walk's convention.
  (define (counted-operand-diagnostics fs n)
    (if (field-width-of fs (counted-consume-node-field n))
        '()
        (list (make-diagnostic 'invalid-field-operand (node-name n)
                               "counted consume names no declared field"))))

  (define (pass-field-operands m fs)
    (apply append
           (map (lambda (n)
                  (cond ((integer-accumulate-node? n)
                         (accumulate-operand-diagnostics fs n))
                        ((counted-consume-node? n)
                         (counted-operand-diagnostics fs n))
                        ((field-action-node? n)
                         (field-operand-diagnostics fs (node-name n)
                                                    (field-action-node-operation n)
                                                    (field-action-node-arguments n)))
                        ((field-branch-node? n)
                         (field-operand-diagnostics fs (node-name n)
                                                    (field-branch-node-predicate n)
                                                    (field-branch-node-arguments n)))
                        (else '())))
                (machine-nodes m))))

  ;; PASS 3: overlap within a dispatch node, over canonical matcher byte sets
  ;; (§16.2:893, §16.3:921). Two cases overlap when their canonical sets share
  ;; any byte; an exact-byte matcher is the one-element case of the same rule.
  (define (byte-sets-overlap? a b)
    (and (pair? a) (or (and (memv (car a) b) #t) (byte-sets-overlap? (cdr a) b))))
  ;; One diagnostic per COLLIDING PAIR of cases, not one per shared byte. A
  ;; complement and a set can share 200 bytes, and a naive per-byte expansion
  ;; would turn one decision into 200 identical diagnostics against
  ;; §16.4:937-943. Pairs are enumerated i < j so a pair is reported once, and
  ;; the pass never inspects the lowered graph: canonical byte sets are a
  ;; source-level property (§17:951 verify-before-normalize). Every diagnostic
  ;; a node contributes shares that node's (code, node, message) triple, so no
  ;; pair carries an identity of its own: the relative order between two
  ;; diagnostics from the same node is not observable (by anything short of
  ;; object identity) and is not promised.
  (define (node-overlaps n)
    (let ((sets (map (lambda (c) (matcher-bytes (byte-case-matcher c)))
                     (byte-dispatch-node-cases n))))
      (let outer ((ss sets) (out '()))
        (if (null? ss)
            out
            (outer (cdr ss)
                   (let inner ((rest (cdr ss)) (out out))
                     (if (null? rest)
                         out
                         (inner (cdr rest)
                                (if (byte-sets-overlap? (car ss) (car rest))
                                    (cons (make-diagnostic 'overlapping-cases (node-name n)
                                                           "two cases match the same byte or bytes")
                                          out)
                                    out)))))))))
  ;; NOT extended to sequence-dispatch-node?, and not deferred either: whether
  ;; two sequence ALTERNATIVES collide is §16.2:894 ambiguity, which
  ;; pass-sequence-ambiguity below owns. Decision 0017 point 4 keeps :893 and
  ;; :894 as two entries with two checks and two codes, and the predicates
  ;; genuinely differ -- this pass compares canonical matcher byte SETS within
  ;; one byte-dispatch node; that one compares the prefix relation between byte
  ;; STRINGS. A sequence node is invisible to this pass permanently.
  (define (pass-overlap m)
    (apply append
           (map (lambda (n) (if (byte-dispatch-node? n) (node-overlaps n) '()))
                (machine-nodes m))))

  ;; Sequence ambiguity (§16.2:894), an unnumbered pass beside PASS 3 because
  ;; §16.2 lists :893 and :894 adjacently and because renumbering PASS 4-7 would
  ;; stale every existing reference to those numbers for nothing. The count
  ;; carries its scope, because it has been three different numbers under three
  ;; different scopes and the argument does not depend on which: FOURTEEN
  ;; occurrences of `PASS <n>` for n in 4..7 across the live tree (`src/` and
  ;; `test/`), excluding this comment block, measured at the whole-branch
  ;; review fix wave -- this file's own pass headers, verify-tests.sps, and
  ;; SchemeMutationSuite.cmake's Pass 33 commentary -- plus the plan documents
  ;; under `docs/` that quote them, which is a different and larger set.
  ;; pass-eof-execution below is the shipped precedent for an unnumbered pass.
  ;;
  ;; "After prefix analysis" is what the pairwise test below IS: one alternative
  ;; being a terminal prefix of another is decidable from the source byte lists
  ;; alone, so this pass never inspects the lowered graph and §17:951's
  ;; verify-before-normalize ordering is preserved. Measured equivalent to the
  ;; normalizer's three trie guards (normal-ir.sls:103-117) over all 469
  ;; nonempty alternative-sets of size <= 3 drawn from the 14 binary strings of
  ;; length 1..3: zero disagreements.
  ;;
  ;; Duplicate alternatives are the MAXIMAL case of the same relation (`AB` is a
  ;; terminal prefix of `AB`), so both shapes carry the one new code design §4.5
  ;; allows. Alternatives that merely SHARE a nonterminal prefix -- `AB` and
  ;; `AC` -- are explicitly legal (§10.6:544); the trie merges them, and a check
  ;; that could not tell the two apart would reject every branching machine.
  (define (byte-prefix? a b)
    (cond ((null? a) #t)
          ((null? b) #f)
          ((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b)))
          (else #f)))
  ;; One diagnostic per COLLIDING PAIR, enumerated i < j so a pair is reported
  ;; once -- pass-overlap's convention above, and §16.4:937-943's one finding
  ;; per decision. Every diagnostic a node contributes shares that node's
  ;; (code, node, message) triple, so no pair carries an identity of its own and
  ;; the relative order of two diagnostics from one node is not promised.
  ;;
  ;; The bindings are deliberately NOT node-overlaps' (`ss`/`outer`/`rest`/
  ;; `inner`/`out`): three shipped mutations pin single lines of that skeleton,
  ;; and a structural clone takes each from one occurrence to two, failing the
  ;; suite with "pattern occurs 2 times ... expected 1" (§0 D8b).
  (define (node-ambiguities n)
    (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
      (let scan ((as alts) (found '()))
        (if (null? as)
            found
            (scan (cdr as)
                  (let against ((others (cdr as)) (found found))
                    (if (null? others)
                        found
                        (against (cdr others)
                                 (if (or (byte-prefix? (car as) (car others))
                                         (byte-prefix? (car others) (car as)))
                                     (cons (make-diagnostic 'ambiguous-sequence-prefix (node-name n)
                                                            "one alternative is a terminal prefix of another")
                                           found)
                                     found)))))))))
  (define (pass-sequence-ambiguity m)
    (apply append
           (map (lambda (n) (if (sequence-dispatch-node? n) (node-ambiguities n) '()))
                (machine-nodes m))))

  ;; PASS 4: reachability from entry.
  ;; *** THIS PASS OVER-APPROXIMATES, and until now that was recorded in four
  ;; documents and no source file. *** It walks `all-out-targets`, which crosses
  ;; an eof-target and then keeps taking byte edges, so a node reachable only
  ;; through an EOF edge no execution can take still counts as reached and
  ;; `unreachable-node` does not fire. Recorded in decisions 0023 and 0027,
  ;; design §4.5, and the parent plan's §16.2 disposition; decision 0027 says it
  ;; is "handed to nobody" and that "item 3's verdict change is the first thing
  ;; that depends on the answer" -- and Milestone 5 shipped that verdict change.
  ;;
  ;; Written here by Milestone 5's completeness check (2026-09-06) because a
  ;; relaxation known to four documents and to no reader of this procedure is
  ;; the failure mode this milestone added a standard against. Owed by whoever
  ;; next narrows reachability, and failing that by Milestone 6's close-out.
  (define (pass-reachability m)
    (let ((nodes (machine-nodes m)) (reached (reach-from m all-out-targets)))
      (filter values
              (map (lambda (n)
                     (if (memq (node-name n) reached) #f
                         (make-diagnostic 'unreachable-node (node-name n) "node is unreachable")))
                   nodes))))

  ;; PASS 5: zero-progress cycles — a reexecute-only cycle consumes no byte.
  ;;
  ;; *** THE GATE §16.2:898 ASKS FOR, added by Milestone 5 Slice ③ (decision
  ;; 0027 item 3). *** The bullet reads "reachable zero-progress cycles" and
  ;; this pass applied NO relation: measured by 0027 against the shipped file,
  ;; neither `reached` nor `byte-reached` occurred as an identifier anywhere in
  ;; it.
  ;;
  ;; The gate is `byte-reached` ALONE, not decision 0027 item 1's composite,
  ;; because §16.2 states the two halves as two separate bullets: `:898`
  ;; "reachable zero-progress cycles" and `:908` "EOF-only zero-progress cycles
  ;; and non-EOF control flow into a finish terminal". The second half already
  ;; has an owner -- `eof-terminal`'s `walk` answers `cycle` on `(memq name
  ;; path)` and `pass-eof-execution` reports it as `eof-zero-progress-cycle` --
  ;; so an EOF-only zero-progress cycle stays rejected after this gate, by the
  ;; check whose bullet it is. Gating on the composite would make the two checks
  ;; overlap on exactly the machines `:908` was written for.
  ;;
  ;; *** It is a RELAXATION, and the ground the design gave for calling it
  ;; benign does not hold. *** Design §3.2 item 4 said such a machine "is
  ;; rejected by `unreachable-node` regardless"; 0027 records that it is not,
  ;; because `pass-reachability` walks `all-out-targets`, which crosses an
  ;; eof-target and then keeps taking byte edges. The fixture in verify-tests
  ;; asserts the machine both ways.
  (define (pass-zero-progress m)
    (let ((nodes (machine-nodes m)) (br898 (byte-reached m)))
      (define (reexec-targets n)
        (cond ((byte-dispatch-node? n)
               (append (map (lambda (c) (edge-target (byte-case-edge c)))
                            (filter (lambda (c) (eq? (edge-mode (byte-case-edge c)) 'reexecute))
                                    (byte-dispatch-node-cases n)))
                       (if (eq? (edge-mode (byte-dispatch-node-fallback n)) 'reexecute)
                           (list (edge-target (byte-dispatch-node-fallback n))) '())))
              ;; A pause consumes no input (§12.4, design §6): its continuation
              ;; is a zero-width edge, so a reexecute/pause-only cycle with no
              ;; advance is a zero-progress cycle.
              ((pause-node? n) (list (pause-node-continuation n)))
              ;; Only the mismatch edge can be reexecute; every case edge
              ;; advances by construction (§10.6:546). This teaches the WALK to
              ;; see through a sequence node, and Milestone 3 Slice ③ added the
              ;; sixth kind to the REPORTED set below (§25:1533), so a
              ;; self-targeting reexecute mismatch edge is now flagged.
              ;;
              ;; Why the source-level walk is exact enough at lowered
              ;; granularity: NO ZERO-WIDTH EDGE CAN ENTER A POSITION->=1 PREFIX
              ;; STATE. Every trie edge advances, so a prefix state at position
              ;; k >= 1 is reached only by consuming a byte; the only zero-width
              ;; edge out of any sequence-derived state is the shared mismatch
              ;; edge this arm returns. The lowered zero-width cycle set is
              ;; therefore exactly the source-level one and no position->=1
              ;; state can be a cycle MEMBER -- which is why verification never
              ;; needs the lowered graph (§17:951). Design §7's phrasing
              ;; ("positions >=1 reach position 0 only after an advance") is
              ;; about the path INTO the state, not the edge out of it, and is
              ;; not the load-bearing property.
              ;;
              ;; KNOWN, DELIBERATE OVER-REJECTION, inherited not introduced:
              ;; reaches-self? is a pure edge walk and never asks whether the
              ;; arm closing the cycle is reachable for any byte. A sequence
              ;; node whose alternatives' first bytes cover all 256 values has a
              ;; dead root fallback and cannot loop, yet is reported. Measured:
              ;; 256 alternatives (b 0) -> stop, mismatch reexecute -> itself,
              ;; terminates on every input. The incumbent byte-dispatch
              ;; analysis is already exactly this conservative -- a node whose
              ;; single case is (make-byte-range-matcher 0 255) with a
              ;; reexecute self-fallback reports zero-progress-cycle today,
              ;; measured -- so this preserves a uniform shipped conservatism.
              ;; Making it exact would need the same reachability refinement for
              ;; byte-dispatch fallbacks and would change existing verdicts.
              ;;
              ;; Fix wave 2 (Important 1), measured 2026-08-30 under Slice ②,
              ;; preserved as the record of what was true then: a sequence node
              ;; whose mismatch edge reexecutes into itself -- one alternative,
              ;; no other nodes -- verified with ok #t and zero diagnostics,
              ;; where the byte-identical shape built from a byte-dispatch node
              ;; reported zero-progress-cycle. Feeding it one byte that does not
              ;; match the alternative's first byte did not return: reproduced
              ;; under a timeout in both the interpreted lane
              ;; (parser-feed-op!'s `(loop pos)`, runtime.sls:200) and the
              ;; generated lane (compile.sls's emitted `(loop pos <target>
              ;; off)` fallback), since neither has a local cycle guard and both
              ;; rely on this REPORT set. CLOSED by Slice ③'s extension above.
              ((sequence-dispatch-node? n)
               (if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
                   (list (edge-target (sequence-dispatch-node-mismatch n))) '()))
              ;; *** Slice ③ (integer accumulate) joins THIS arm and the REPORT
              ;; guard below, and must join both in one commit for the reason
              ;; recorded there. *** Its kind is input-reading rather than
              ;; zero-width, so it does NOT belong in `zero-width-successors`
              ;; -- it consumes a byte and makes progress. Recorded here because
              ;; a ③ implementer reads this file, not Slice ②'s plan.
              ;;
              ;; Slice ②'s two kinds are ZERO-WIDTH, exactly like a pause: every
              ;; edge out of them makes no progress, so every one is a
              ;; reexecute-equivalent and all of them join this walk. A
              ;; `store`-into-itself machine verifies clean and then hangs in
              ;; BOTH lanes without this -- the precise failure M3 Slice ②
              ;; shipped by extending the walk and not the REPORT set.
              ;; The callback node joins for the same reason and in the same
              ;; commit as the REPORT guard below: every one of its three edges
              ;; is zero-width, so a callback that continues, branches or
              ;; resumes into itself invokes its callback forever without
              ;; reading a byte, and neither runtime loop guards against it.
              ((or (field-action-node? n) (field-branch-node? n)
                   (callback-node? n)
                   (span-start-node? n) (span-end-node? n))
               (zero-width-successors n))
              ;; *** Integer accumulate contributes TWO edges, not one. Design §8
              ;; says only `nondigit-edge` can be `reexecute`, "since the
              ;; overflow edge is non-consuming but TERMINAL-DIRECTED". It is not
              ;; terminal-directed -- §8 contradicts itself sixteen lines later,
              ;; declining to extend pass-names' error-node? filter "since
              ;; overflow-error names a target NODE" -- and nothing anywhere
              ;; constrains that target's kind. ***
              ;;
              ;; So the overflow edge joins unconditionally: §12.7:772 makes it
              ;; NON-CONSUMING and §15:870 leaves the field unchanged, so an
              ;; overflow-error naming its own accumulate node re-reads the same
              ;; byte forever. Neither runtime loop guards against that. The
              ;; digit edge stays out -- it always advances (§10.6:566).
              ;;
              ;; Measured before this arm was written: cutting Slice ②'s
              ;; field-action arm back to one disjunct makes a self-targeting
              ;; error edge verify with ZERO diagnostics. The two self-cycles
              ;; need SEPARATE fixtures -- neither distinguishes the other's
              ;; mutant, and the REPORT guard below has the same blind spot.
              ((integer-accumulate-node? n)
               (append
                (if (eq? (edge-mode (integer-accumulate-node-nondigit-edge n)) 'reexecute)
                    (list (edge-target (integer-accumulate-node-nondigit-edge n)))
                    '())
                (list (integer-accumulate-node-overflow-error n))))
              ;; Counted consume (Milestone 6 Slice ①): `next` is taken without
              ;; consuming exactly when the count is zero, which this pass cannot
              ;; see, so it joins unconditionally -- the overflow edge's shape
              ;; above. A self-targeting `next` hangs both executors the first
              ;; time its count is zero. Decision 0030 item 7 prices the
              ;; over-rejection this brings (a loop terminated by a field value
              ;; is rejected, §11.4:654) and bounds it (§16.2:913: a loop with a
              ;; byte dispatch in it is untouched).
              ((counted-consume-node? n) (list (counted-consume-node-next n)))
              (else '())))
      (define (reaches-self? start)
        (let loop ((frontier (reexec-targets (lookup nodes start))) (seen '()))
          (cond ((null? frontier) #f)
                ((eq? (car frontier) start) #t)
                ((memq (car frontier) seen) (loop (cdr frontier) seen))
                (else (let ((n (lookup nodes (car frontier))))
                        (loop (append (if n (reexec-targets n) '()) (cdr frontier))
                              (cons (car frontier) seen)))))))
      (filter values
              (map (lambda (n)
                     ;; The REPORT set, extended in the SAME commit as the walk
                     ;; above. Extending one without the other is the half-fix
                     ;; M3 Slice ② shipped and Slice ③ closed: the walk finds the
                     ;; cycle, nothing reports it, verify returns ok with zero
                     ;; diagnostics, and the machine fails to terminate in both
                     ;; lanes.
                     (if (and (memq (node-name n) br898)
                              (or (byte-dispatch-node? n) (pause-node? n)
                                  (sequence-dispatch-node? n)
                                  (field-action-node? n) (field-branch-node? n)
                                  (integer-accumulate-node? n)
                                  (callback-node? n)
                                  (span-start-node? n) (span-end-node? n)
                                  (counted-consume-node? n))
                              (reaches-self? (node-name n)))
                         (make-diagnostic 'zero-progress-cycle (node-name n)
                                          "a zero-progress cycle (reexecute edges, pause continuations, field actions and branches, accumulate overflow edges) makes no progress")
                         #f))
                   nodes))))

  ;; PASS 6: EOF shape — the machine default eof error names a declared error;
  ;; a dispatch eof-target (when a symbol) resolves to a node.
  (define (pass-eof m)
    (let ((nodes (machine-nodes m)))
      (append
       (if (memq (machine-default-eof-error m) (error-names m)) '()
           (list (make-diagnostic 'invalid-eof-target (machine-default-eof-error m)
                                  "machine default eof error names no declared error")))
       (apply append
              (map (lambda (n)
                     (let ((t (node-eof-target n)))
                       (if (or (eq? t #f) (lookup nodes t)) '()
                           (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                  "eof-target names no node")))))
                   nodes)))))

  ;; Classify the EOF continuation of `start` (§16.2:909). Rewritten in
  ;; Milestone 4 Slice ② to answer over a SET of successors, because a field
  ;; branch has two targets and a field action has `next` plus `error`.
  ;;
  ;; *** The algorithm is §4.4's and decision 0021's, NOT design §7 Task 1's. ***
  ;; §7 opens "§4.4 leaves two choices open that the implementer must not
  ;; improvise" and then makes both the other way; §4.4 settles them 900 lines
  ;; earlier in the same commit, and 0021 item 2 names §7's per-path `seen` as a
  ;; REJECTED algorithm -- "one structure doing both jobs and pays 2^k paths for
  ;; k branch nodes". §7's bullets are struck in the design and the correction is
  ;; marked at the site.
  ;;
  ;; TWO structures, each doing one job:
  ;;   `path` is the current DFS stack -- re-entering it is a cycle, and this is
  ;;          per-path because a cycle is a property of the path.
  ;;   `done` is a GLOBAL completed-set -- a node whose verdict is settled is not
  ;;          re-explored, so a diamond whose arms re-converge costs one visit
  ;;          rather than two, and 2^k paths never arise.
  ;; A verdict memoized in `done` may have been reached while other nodes were on
  ;; the path, which is sound here because the only path-dependent answer is
  ;; `cycle`, and `cycle` means "a cycle is reachable from here" -- true from
  ;; every path that reaches this node, not just the one that found it.
  ;;
  ;; `'unknown` is DELETED, not ranked least (0021 item 3: it "leaves the answer
  ;; set rather than becoming its least element ... a residual arm may not
  ;; reintroduce one"). Every kind `ir.sls` can construct has its own arm, so the
  ;; residual `else` is unreachable and raises, matching the loud-else convention
  ;; in normal-ir.sls, compile.sls and runtime.sls.
  ;; *** THREE TIERS, not a flat six (Slice ⓪b, OQ-5). ***
  ;;
  ;; The join takes the max, so the order decides which sibling verdict survives.
  ;; A flat list of six has 720 orderings; measured, only THREE equivalence
  ;; classes are observable, and 24 of the orderings are indistinguishable by any
  ;; machine. Under this project's rules an unwitnessable ordering is not a
  ;; decision -- and worse, four of the six undecidable pairs are ACCEPTANCE
  ;; HOLES: with `default-error` ranked above `cycle`, a field-branch machine
  ;; verifies with zero diagnostics and `parser-finish!` never returns.
  ;;
  ;; Tiers make the 24-permutation survivor unwritable rather than something to
  ;; declare EXPECT_SURVIVES, and turn each tier assignment into a single-token
  ;; mutation caught by a failed comparison rather than by a raise.
  ;;
  ;; All six symbols are KEPT. Milestone 5's span check needs `finish`
  ;; distinguished from `error` at `classify`, and 0021 item 3's loud-else
  ;; discipline forbids merging arms.
  ;;
  ;; *** CORRECTED 2026-09-03, whole-branch review: this said `unresolved` is
  ;; UNPRODUCIBLE. It is not. *** `classify`'s `((not n) 'unresolved)` arm below
  ;; still answers it, for any EOF successor naming no node -- reached today, by
  ;; two routes (a dispatch's dangling eof-target, and a zero-width arm naming
  ;; nothing). What became a loud raise is `join-over`'s EMPTY join, a different
  ;; site; I generalised from one to the other without checking.
  ;;
  ;; So `unresolved`'s tier is load-bearing: a machine whose EOF chain reaches a
  ;; dangling name AND a stop must still report the stop, which happens only
  ;; because `unresolved` loses the join. That is now a fixture and a pin --
  ;; without them the claim two paragraphs up, that tiers make every assignment a
  ;; single-token mutation caught by a failed comparison, was false for one of
  ;; the six.
  (define eof-verdict-tiers
    '((finish unresolved error default-error)   ; the chain terminates
      (eof-reachable-stop)                      ; §16.2:909
      (cycle)))                                 ; 0021 item 1
  (define (eof-verdict-rank v)
    (let loop ((ts eof-verdict-tiers) (i 0))
      (cond ((null? ts) (assertion-violation 'eof-terminal "unranked verdict" v))
            ((memq v (car ts)) i)
            (else (loop (cdr ts) (+ i 1))))))
  ;; Sibling answers join by max. 0021 item 1 pins only `cycle >
  ;; eof-reachable-stop` -- a cycle is the non-termination neither runtime loop
  ;; guards against, so it must survive a join -- and leaves the rest unfixed;
  ;; the order above is this slice's call within that constraint.
  (define (eof-verdict-join a b)
    (if (>= (eof-verdict-rank a) (eof-verdict-rank b)) a b))

  ;; The nodes an EOF walk continues to. Empty at a terminal; one for a pause or
  ;; a dispatch with a symbolic eof-target; TWO for the zero-width field kinds,
  ;; which is the whole reason this walk became multi-successor. A field action's
  ;; `error` is a successor exactly when it has one -- the constructor makes that
  ;; `#f` precisely when the operation cannot fail.
  ;;
  ;; Counted consume (Milestone 6 Slice ①) is the one INPUT-READING kind with an
  ;; EOF successor of its own: a zero count takes `next` at EOF (§10.6:600), and
  ;; at a node the walk ARRIVES at the count is unknown, so `next` is a successor
  ;; unconditionally (decision 0030 item 5). One fact, two consumers --
  ;; `classify`'s counted arm and pass 7's `eof-step` both read this and cannot
  ;; disagree -- which is `zero-width-edges`' rule applied a kind later.
  (define (eof-successors n)
    (cond ((counted-consume-node? n) (list (counted-consume-node-next n)))
          (else (zero-width-successors n))))

  (define (eof-terminal m start)
    (let ((nodes (machine-nodes m)) (done '()))
      (define (walk name path)
        (cond ((memq name path) 'cycle)
              ((assq name done) => cdr)
              (else
               (let ((v (classify name (cons name path))))
                 (set! done (cons (cons name v) done))
                 v))))
      (define (dispatch-arm t path)
        (if (symbol? t) (walk t path) 'default-error))
      (define (join-over names path)
        (let loop ((ns names) (acc #f))
          (if (null? ns)
              ;; A zero-width node with no successors cannot occur -- both kinds
              ;; have mandatory targets. This was answered with `'unresolved`
              ;; rather than raised, on the reasoning that an empty join has an
              ;; obvious identity. *** Slice ⓪b makes it LOUD: measured, the arm
              ;; is dead, and answering an impossible input quietly is how a
              ;; verdict nothing produces stayed in a six-element ranking that
              ;; four mutations could permute undetected. *** An impossible input
              ;; made loud is not a gap being closed; it is a gap being refused.
              (or acc (assertion-violation 'eof-terminal
                                           "empty zero-width join" names))
              (loop (cdr ns)
                    (let ((v (walk (car ns) path)))
                      (if acc (eof-verdict-join acc v) v))))))
      (define (classify name path)
        (let ((n (lookup nodes name)))
          (cond ((not n) 'unresolved)             ; pass-eof reports missing target
                ((finish-node? n) 'finish)
                ((error-node? n) 'error)
                ((stop-node? n) 'eof-reachable-stop)
                ;; Kept as two arms rather than routed through node-eof-target:
                ;; every other arm here is one predicate per kind, and merging
                ;; these two would be the only merged arm in an otherwise
                ;; exhaustive per-kind analysis -- obscuring that the decision is
                ;; made independently per kind even though the bodies coincide.
                ((byte-dispatch-node? n)
                 (dispatch-arm (byte-dispatch-node-eof-target n) path))
                ((sequence-dispatch-node? n)
                 (dispatch-arm (sequence-dispatch-node-eof-target n) path))
                ;; A callback node classified HERE is being flowed through: the
                ;; EOF walk arrived at it, so `parser-finish!` will invoke the
                ;; callback and every one of §13:803-808's outcomes is live.
                ;; That is why the join is over all three edges, and it is NOT
                ;; the same question as which edge a parser PARKED at this node
                ;; resumes on -- see `parked-eof-start` below, the one place
                ;; those two come apart.
                ((or (pause-node? n) (field-action-node? n) (field-branch-node? n)
                     (callback-node? n)
                     (span-start-node? n) (span-end-node? n))
                 (join-over (eof-successors n) path))
                ;; Counted consume (Milestone 6 Slice ①): BOTH families' answer,
                ;; joined (decision 0030 item 5). The walk ARRIVED here, so the
                ;; count is unknown -- a positive count takes the eof-target (the
                ;; dispatch half) and a zero count takes `next` (the zero-width
                ;; half, read through `eof-successors` so pass 7 cannot disagree).
                ;; A stop behind `next` is `eof-reachable-stop`: the machine whose
                ;; entry is a counted consume with initial 0, a #f route and a
                ;; stop for `next` verified clean under a dispatch-shaped arm and
                ;; answered `stopped` from `parser-finish!`. `join-over` raises on
                ;; an empty list; the list here is always the one name.
                ((counted-consume-node? n)
                 (eof-verdict-join (dispatch-arm (counted-consume-node-eof-target n) path)
                                   (join-over (eof-successors n) path)))
                ;; *** Slice ③, added by the whole-branch review. *** An
                ;; integer-accumulate node is a legal EOF target -- this slice
                ;; taught `node-eof-target` to read one -- and it carries its own
                ;; eof-target, so it classifies exactly as a dispatch does: hop,
                ;; and let the walk decide. Without this arm every EOF chain that
                ;; reached one fell into the `else` below and `verify-machine`
                ;; RAISED instead of returning a verification result, on machines
                ;; both executors already ran correctly.
                ((integer-accumulate-node? n)
                 (dispatch-arm (integer-accumulate-node-eof-target n) path))
                (else (assertion-violation 'eof-terminal
                                           "no EOF classification for node kind" name)))))
      (walk start '())))

  ;; Byte-flow reachability (feed can arrive): entry DFS over node-out-targets
  ;; -- dispatch case/fallback edges plus reached-pause continuations --
  ;; excluding eof-targets. An eof-only-reachable pause legally continues into
  ;; a finish node (decision 0011); a byte-reachable one must not (§16.2:908).
  (define (byte-reached m) (reach-from m node-out-targets))

  ;; *** "A state an execution can be parked on" and "the name the EOF walk
  ;; starts at" are two different questions, and the callback node is the first
  ;; kind where they come apart. *** For all nine older kinds they coincide, so
  ;; the parked block below classifies the parked node itself and lets
  ;; `classify` hop: a dispatch follows its eof-target, a pause joins over its
  ;; continuation.
  ;;
  ;; A parser parked at a callback node is parked because that callback RETURNED
  ;; pause, and §13:812 resumes "at that invocation's declared pause
  ;; continuation" -- ONE edge, not three. Classifying the callback itself would
  ;; join over its continue and branch targets as well and report
  ;; `eof-reachable-stop` for a stop terminal only a FEED-time `continue`
  ;; reaches; that is a legal `stopped` feed result and not an EOF path. The
  ;; flow-through case, where the walk ARRIVES at a callback and every outcome
  ;; is live, is `classify`'s and is unaffected.
  ;;
  ;; The entry is the exception to the exception: a fresh or reset parser is
  ;; parked at the entry WITHOUT having executed it, so `parser-finish!` runs an
  ;; entry callback and all three outcomes are live -- flow-through again.
  ;; *** A SPAN END IS A PARKED STATE, and Slice ③ said here that it was not.
  ;; *** The claim was that "§14:837 and §14:838 park on the span-data or
  ;; completion CALLBACK's own pause, whose continuation belongs to that callback
  ;; node" -- and a span-data callback has no callback node. It is reached
  ;; through a SPAN declaration and the span-end node itself, so its pause parks
  ;; on that node's internal completion substep, whose source name (§13:820, the
  ;; debug map) is the span-end node's own.
  ;;
  ;; Found by Slice ③'s own census reconciliation, and it was reachable: a
  ;; machine whose span end continues to a stop verified clean and then answered
  ;; `stopped` from `parser-finish!` after a span-data pause -- exactly what
  ;; §16.2:909 exists to forbid, and what the pause-node control below is
  ;; rejected for.
  ;;
  ;; *** AND IT NEEDS NO ARM HERE, which is measured rather than assumed. *** A
  ;; span end's resume point is its SUCCESSOR -- by the time anything is parked
  ;; there the fragment is delivered (§14:837) and only the completion callback
  ;; and the jump remain -- but starting the walk at the node gives the same
  ;; answer, because a span end is pure flow-through: it is no terminal, so
  ;; `classify` above joins over its `next` and nothing else. An arm answering
  ;; `(span-end-node-next n)` was written here first and its mutation SURVIVED,
  ;; which is what a line that cannot change an outcome looks like. The whole of
  ;; the change is the MEMBERSHIP below.
  ;;
  ;; A span START stays out of that membership: it calls nothing, so nothing can
  ;; pause there, and it is flow-through like a field action.
  (define (parked-eof-start m n)
    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (callback-node-pause-continuation n))
          ;; Counted consume (Milestone 6 Slice ①, decision 0030 item 6): a
          ;; parser parked here by `need-input` holds a POSITIVE count -- rows 2
          ;; and 3-partial of 0030's table are the only returns that leave
          ;; `current` on the node, and both leave the field positive -- so at
          ;; finish it takes its EOF route, never `next`, and the walk starts
          ;; there. That route is a symbol whenever this arm is reached:
          ;; `pass-eof-execution` asks only for nodes in the parked set, and a
          ;; non-entry counted consume is in that set only through its
          ;; `(symbol? (node-eof-target n))` clause. The ENTRY falls through: a
          ;; fresh parser is parked there without having executed it, its count
          ;; is the field's initial and may be zero, so it starts at itself and
          ;; takes `classify`'s join. The first draft of the design parked the
          ;; kind by kind instead; that rejected the one-shot "length, body,
          ;; stop" grammar, and 0030 records why it was withdrawn.
          ((and (counted-consume-node? n) (not (eq? (node-name n) (machine-entry m))))
           (counted-consume-node-eof-target n))
          (else (node-name n))))

  ;; §16.2:908/:909 and the separate EOF zero-progress-cycle check.
  (define (pass-eof-execution m)
    (let ((nodes (machine-nodes m)))
      (append
       ;; :908 — ONE derived block, replacing three hand-written ones (Slice ⓪b).
       ;;
       ;; §16.2:908 forbids "non-EOF control flow into a finish terminal", and
       ;; decision 0011 item 4(b) states the same rule over REACHING. So the
       ;; question is not what KIND the source node is; it is whether the source
       ;; is byte-reachable. The three shipped blocks answered it three ways --
       ;; one unconditional and kind-filtered, two gated on byte-reachability --
       ;; and therefore disagreed: a node reachable ONLY as an eof-target was
       ;; accepted when it was a pause, a field-action or a field-branch, and
       ;; rejected when it was a byte-dispatch, a sequence-dispatch or an
       ;; accumulate. The byte edge is untakeable in all six.
       ;;
       ;; *** The gated reading is correct, measured in both directions. ***
       ;; Applying the unconditional reading uniformly breaks five shipped
       ;; programs, and the machine it refuses is `make-pause-machine`: an
       ;; EOF-only pause continuing into a finish node, which is decision 0011's
       ;; canonical LEGAL shape, named in that fixture's own header. Decision
       ;; 0021 item 5 split the kinds by "reads input" versus "zero-width"; all
       ;; three input-reading kinds can be EOF-only-reachable, so the split's
       ;; stated reason is false and its verdict wrong. See decision 0023.
       ;;
       ;; The gate is SOUND, not merely convenient: once an execution takes an
       ;; eof-target it can never feed again (`parser-feed!` prohibits the
       ;; `finish-ready` row), so feed-reachable is a subset of `byte-reached`
       ;; and gating on it cannot miss a real violation.
       ;;
       ;; Reported once per offending edge AT ITS SOURCE NODE. The alternative --
       ;; reporting at the finish node -- measures identical accept/reject sets
       ;; but merges findings from two different sources into one, and the source
       ;; is the half that says which edge to fix (§16.4:940).
       ;;
       ;; `node-out-targets` is now the single census this rule consults, and it
       ;; already owns that job -- the direct antidote to the failure mode Slice
       ;; ③ shipped three times: a kind taught to the accessors and not to the
       ;; hand-written filters reading them.
       ;; The ZERO-HOP case (Slice ⓪b, OQ-2): the entry itself being a finish
       ;; terminal. Decision 0011 item 4(b) and §10.6:616 both state the rule over
       ;; REACHING, and the entry is reached by `parser-feed!`. Measured before
       ;; this clause: such a machine verified clean and `parser-feed!` returned
       ;; `finished` for an EMPTY slice, which §11.1:638's closed list ("a
       ;; callback, stop, or error") does not permit. Reuses the code rather than
       ;; spending a new one, on the Slice ③ precedent.
       ;;
       ;; Multiplicity 1 by construction: one entry, and a finish node has no
       ;; out-targets, so the per-edge loop below cannot also fire on it.
       (let ((en (lookup nodes (machine-entry m))))
         (if (and en (finish-node? en))
             (list (make-diagnostic 'non-eof-into-finish (machine-entry m)
                                    "the entry is a finish terminal"))
             '()))
       (let ((br908 (byte-reached m)))
         (apply append
                (map (lambda (n)
                       (if (memq (node-name n) br908)
                           (filter values
                                   (map (lambda (re)
                                          (let ((tn (lookup nodes (cdr re))))
                                            (if (and tn (finish-node? tn))
                                                (make-diagnostic/edge
                                                 'non-eof-into-finish (node-name n)
                                                 "a byte edge targets a finish terminal"
                                                 (car re))
                                                #f)))
                                        (node-out-edges n)))
                           '()))
                     nodes)))
       ;; :909 + the EOF-cycle check — walk each INPUT-READING node's eof-target
       ;; chain. Slice ③ adds `integer-accumulate-node?` here too, and this is the
       ;; arm whose absence was worst: `parser-finish-op!` says in its own words
       ;; that it carries no local cycle guard because it relies on these two
       ;; checks, so an accumulate node whose eof-target was itself verified with
       ;; zero diagnostics and then looped FOREVER in both executors, and one
       ;; whose EOF chain reached a stop terminal was accepted although
       ;; `eof-reachable-stop` exists to reject exactly that. Found by the
       ;; whole-branch review; both shapes are now fixtures.
       ;; *** Slice ⓪b: the start set is the PARKED set, derived. ***
       ;;
       ;; The old shape enumerated source KINDS and classified each one's
       ;; eof-TARGET, and `machine-entry` was in no kind's list -- so the EOF path
       ;; that begins at the entry was never classified, though `parser-finish!`
       ;; on a fresh or reset parser starts precisely there. Measured: `entry = a
       ;; stop node` verified with ZERO diagnostics and returned `stopped`, while
       ;; the identical property one hop away was correctly rejected.
       ;;
       ;; The set below is the states an execution can be parked on: the entry,
       ;; every byte-reachable pause (whose continuation `current` is left on),
       ;; and every byte-reachable node carrying its own EOF route. Because it is
       ;; a SET, the entry appears exactly once -- so a machine whose entry is
       ;; also a dispatch with an eof-target reports ONE finding, not two. The
       ;; naive fix, a second walk start bolted onto the entry, double-reports
       ;; there, and the only filter that suppresses it is a per-kind census of
       ;; the entry: the construct that shipped three Slice ③ defects.
       ;;
       ;; Each node is classified as ITSELF rather than by its eof-target, which
       ;; unifies the two old blocks -- `classify` on a dispatch already follows
       ;; its eof-target and on a pause already joins over its continuation -- so
       ;; the reported node stays where it was and no shipped `diagnostic-node`
       ;; assertion moves.
       ;;
       ;; This NARROWS decision 0011 item 4(a)'s literal "reachable from any
       ;; state": a graph node no execution can occupy is not a state that
       ;; originates a traversal. Recorded in decision 0023 rather than left for
       ;; a later slice to re-derive.
       (let ((br909 (byte-reached m)))
         (apply append
                (map (lambda (n)
                       (if (and (memq (node-name n) br909)
                                (or (eq? (node-name n) (machine-entry m))
                                    (pause-node? n)
                                    ;; Slice ②: a callback that returned pause
                                    ;; parks the parser exactly as a pause node
                                    ;; does. `parked-eof-start` above is where
                                    ;; its start differs from its name.
                                    (callback-node? n)
                                    ;; Slice ③, and NOT in its first shape: a
                                    ;; span end's data callback parks the parser
                                    ;; on that node's completion substep, so it
                                    ;; belongs in this set for the same reason
                                    ;; the callback node does. `parked-eof-start`
                                    ;; carries the difference again.
                                    (span-end-node? n)
                                    (symbol? (node-eof-target n))))
                           (case (eof-terminal m (parked-eof-start m n))
                             ((eof-reachable-stop)
                              (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                     "an EOF path reaches a stop terminal")))
                             ((cycle)
                              (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                     "an EOF path cycles without reaching a terminal")))
                             (else '()))
                           '()))
                     nodes)))
       ;; The D4(b)/(d) pause blocks that stood here are SUBSUMED (Slice ⓪b):
       ;; the :908 half by the derived byte-reachability block above, and the
       ;; :909 half by the parked set, which includes every byte-reachable pause
       ;; and classifies it through the same `eof-terminal` call. Both were gated
       ;; on `byte-reached` already; the gate is now the whole rule rather than
       ;; one kind's special case.
       )))

  ;; The labels a node carries BESIDE its own: its byte cases' or sequence cases'.
  ;; A case has no name (§9.1:290, :298), so its label is checked under the
  ;; owning node, inside that node's one finding. A per-kind `cond` -- a census
  ;; a new kind must answer, with "no cases" being an answer -- built with `map`
  ;; and no `(cons 'x ...)` form, because the kind x position census collects
  ;; every quoted-symbol `cons` in this file as an edge role.
  (define (node-case-labels n)
    (cond ((byte-dispatch-node? n)
           (map byte-case-source-label (byte-dispatch-node-cases n)))
          ((sequence-dispatch-node? n)
           (map sequence-case-source-label (sequence-dispatch-node-cases n)))
          (else '())))

  ;; PASS 7: generated-name safety (member 1) — machine, node, error names/codes.
  ;; Milestone 6 Slice ⓪ folds §16.2:886's label clause into each arm's `and`:
  ;; the machine's label, every node's own label and its case labels through
  ;; `node-source-label` and `node-case-labels`, and every error declaration's
  ;; label. One finding per carrier however many ways it is bad -- the shape the
  ;; error-declaration arm already had -- and no new emission site, so the
  ;; diagnostic census reads the same six `invalid-name` sites it read before.
  (define (pass-names-valid m)
    (append
     (if (and (valid-name? (machine-name m))
              (valid-label? (machine-source-label m)))
         '()
         (list (make-diagnostic 'invalid-name (machine-name m)
                                "machine name or label is not portable")))
     (filter values
             (map (lambda (n)
                    (if (and (valid-name? (node-name n))
                             (valid-label? (node-source-label n))
                             (for-all valid-label? (node-case-labels n)))
                        #f
                        (make-diagnostic 'invalid-name (node-name n)
                                         "node name, label or case label is not portable")))
                  (machine-nodes m)))
     (filter values
             (map (lambda (e)
                    (if (and (valid-name? (error-declaration-name e))
                             (valid-name? (error-declaration-code e))
                             (valid-reason? (error-declaration-reason e))
                             (valid-label? (error-declaration-source-label e)))
                        #f
                        (make-diagnostic 'invalid-name (error-declaration-name e)
                                         "error name, code, reason or label is not portable")))
                  (machine-errors m)))))

  ;; --- PASS 6b: callback and span DECLARATIONS (Milestone 5 Slice ①b) ---------
  ;;
  ;; A PASS OF ITS OWN, and the reason is mechanical rather than aesthetic.
  ;; `pass-fields`' tail line -- seven leading spaces, four trailing parens --
  ;; is the verbatim FIND of the mutation that pins `pass-field-operands` being
  ;; run at all, at exactly one site. Appending a declaration arm inside that
  ;; `append` moves the line and takes the pin to zero occurrences, which fails
  ;; at CMake CONFIGURE time and does not look like a test failure. Slice ③ paid
  ;; for that lesson on `pass-names`; this pass avoids re-paying it.
  ;;
  ;; NO `(cons 'SYMBOL ...)` FORM APPEARS BELOW, and that is a constraint, not a
  ;; coincidence. `edge-roles-in-source` in the kind x position census collects
  ;; the quoted symbol from EVERY such form in this file -- not only edge-role
  ;; ones, despite what its own comment says -- and compares the result against a
  ;; declared mapping. A `(cons 'callback name)` here would add a SIXTEENTH
  ;; "role", fail `derived roles equal the mapped roles`, and take that pass's
  ;; BASELINE red. RE-MEASURED at Slice ③ task 8: 18 occurrences in CODE and 22
  ;; textual, the four extra being the two mentions in this comment and two in
  ;; pass 7's own. It was 13 before Slice ②'s pass, 13 after, and 16 once the
  ;; callback node's three genuine roles landed; Slice ③'s two span kinds reuse
  ;; `next` rather than minting roles, so the two added occurrences are the span
  ;; arms of `zero-width-edges` and its views, not two new roles.
  ;; Count with `read`, or exclude comment lines -- the two mentions in this
  ;; very comment are why a bare textual count answers more and is the same
  ;; class of mistake as the substring sweep that once undercounted a pin.
  ;;
  ;; Every loop variable is named apart from `pass-names`' and `pass-fields`'.
  ;; Three of those loops' inner lines are each a one-site FIND, so a copied
  ;; duplicate-scan would twin a pin and fail configure in the other direction.
  ;; §9.3:421, quoted: "The symbols `continue` and `pause` are reserved and may
  ;; not be callback decision branch keys." §16.2:902's content is fixed there,
  ;; so this list is a transcription and not a decision of this slice's.
  (define reserved-outcomes '(continue pause))

  (define (pass-declarations m)
    (let ((cbs (machine-callbacks m)) (sps (machine-spans m)))
      (append
       ;; §16.2:885, callbacks. `cseen`/`cout` rather than `seen`/`out`.
       (let cloop ((cs cbs) (cseen '()) (cout '()))
         (if (null? cs) (reverse cout)
             (let ((cn (callback-declaration-name (car cs))))
               (cloop (cdr cs) (cons cn cseen)
                      (if (memq cn cseen)
                          (cons (make-diagnostic 'duplicate-callback-declaration cn
                                                 "duplicate callback declaration name")
                                cout)
                          cout)))))
       ;; §16.2:885, spans. `pseen`/`pout`.
       (let ploop ((ps sps) (pseen '()) (pout '()))
         (if (null? ps) (reverse pout)
             (let ((pn (span-declaration-name (car ps))))
               (ploop (cdr ps) (cons pn pseen)
                      (if (memq pn pseen)
                          (cons (make-diagnostic 'duplicate-span-declaration pn
                                                 "duplicate span declaration name")
                                pout)
                          pout)))))
       ;; §16.2:886's name clause, both families. Before this slice, callback and
       ;; span names sat outside every grammar check in the tree: `pass-names`
       ;; and `pass-names-valid` read node names and error declarations only.
       ;; *** THE LABEL CLAUSE IS FOLDED INTO THE NAME CLAUSE'S `and`, not added
       ;; as its own arm. *** That is Milestone 4's shipped shape for the same
       ;; bullet: `pass-names-valid`'s error-declaration arm tests name, code AND
       ;; reason in one `and` so a declaration bad in three ways reports ONCE,
       ;; and `verify-tests.sps` witnesses it ("one declaration bad in every
       ;; field still yields a single finding"). Folding also leaves the
       ;; diagnostic census unmoved, which is a measurement to RUN rather than an
       ;; absence to assume: `(invalid-name 6)` stays 6.
       ;;
       ;; The counter-argument, declined rather than unnoticed: Slice ③ refused
       ;; to reuse `missing-callback-declaration` for spans because a reader
       ;; tracing a report back would look in the callback table for a name that
       ;; was never there. Here the subject does not move: the diagnostic names
       ;; the DECLARATION, which is in the right table either way, and that alone
       ;; is the disanalogy.
       ;;
       ;; It does NOT name which field failed, and an earlier version of this
       ;; comment claimed it did. The message is a static disjunction, so a
       ;; label-only failure reports a node slot holding a perfectly PORTABLE
       ;; name with the offending label nowhere in the record -- the same
       ;; imprecision Milestone 4's "error name, code or reason is not portable"
       ;; already carries. The fold is still right; that was a false reason.
       ;;
       ;; These two arms check the two DECLARATION families' labels, and they are
       ;; no longer the only label checks in the file. Through Milestone 5 they
       ;; were: that milestone's §4.12 item 2 authorised the two new families
       ;; only, and every other carrier -- the machine, every uint field, every
       ;; error declaration, both case kinds, and all twelve node kinds -- stored a
       ;; label nothing read (nine of them had no accessor at all). Milestone 6
       ;; Slice ⓪ closed that gap where each carrier's NAME is already checked:
       ;; `pass-names-valid` (machine, node with its cases, error declaration) and
       ;; `pass-fields` (field), each as a conjunct of the existing `and`, so the
       ;; diagnostic census did not move. The parent plan's dated disposition
       ;; "§16.2:886 and §9.3:423 -- Milestone 6 Slice ⓪, delivered" records the
       ;; closure; its Milestone 5 close note records the gap.
       (filter values
               (map (lambda (cd)
                      (if (and (valid-name? (callback-declaration-name cd))
                               (valid-label? (callback-declaration-source-label cd)))
                          #f
                          (make-diagnostic 'invalid-name (callback-declaration-name cd)
                                           "callback declaration name or label is not portable")))
                    cbs))
       (filter values
               (map (lambda (sd)
                      (if (and (valid-name? (span-declaration-name sd))
                               (valid-label? (span-declaration-source-label sd)))
                          #f
                          (make-diagnostic 'invalid-name (span-declaration-name sd)
                                           "span declaration name or label is not portable")))
                    sps))
       ;; §16.2:886's branch-key clause and §16.2:901's declaration share:
       ;; a key that is not portable, or declared twice on one callback.
       (apply append
              (map (lambda (cd)
                     (let kloop ((ks (callback-declaration-branch-keys cd))
                                 (kseen '()) (kout '()))
                       (if (null? ks) (reverse kout)
                           (let ((k (car ks)))
                             (kloop (cdr ks) (cons k kseen)
                                    (cond
                                     ((memq k kseen)
                                      (cons (make-diagnostic 'duplicate-branch-key
                                                             (callback-declaration-name cd)
                                                             "branch key declared twice")
                                            kout))
                                     ((not (valid-name? k))
                                      (cons (make-diagnostic 'invalid-name
                                                             (callback-declaration-name cd)
                                                             "branch key is not portable")
                                            kout))
                                     (else kout)))))))
                   cbs))
       ;; §16.2:902. Its content is §9.3:421's, transcribed above.
       (apply append
              (map (lambda (cd)
                     (filter values
                             (map (lambda (k)
                                    (if (memq k reserved-outcomes)
                                        (make-diagnostic 'reserved-branch-key
                                                         (callback-declaration-name cd)
                                                         "branch key collides with a reserved outcome")
                                        #f))
                                  (callback-declaration-branch-keys cd))))
                   cbs))
       ;; §16.2:891. Derived from §9.3:419, not invented here: "An optional
       ;; decision callback must declare `default-branch`". A REQUIRED decision
       ;; callback needs none -- it is always bound, so no default is reached.
       (filter values
               (map (lambda (cd)
                      (let ((k (callback-declaration-kind cd))
                            (req (callback-declaration-required? cd))
                            (db (callback-declaration-default-branch cd)))
                        (if (and (eq? k 'decision) (not req)
                                 (not (and (symbol? db)
                                           (memq db (callback-declaration-branch-keys cd)))))
                            (make-diagnostic 'invalid-callback-declaration
                                             (callback-declaration-name cd)
                                             "optional decision callback has no valid default branch")
                            #f)))
                    cbs))
       ;; A non-decision callback declaring branch keys or a default branch:
       ;; §10.3:504 gives branch keys to DECISION callbacks only, so any key on
       ;; another kind is undeclared by construction (§16.2:901's "undeclared").
       (filter values
               (map (lambda (cd)
                      (if (and (not (eq? (callback-declaration-kind cd) 'decision))
                               (or (pair? (callback-declaration-branch-keys cd))
                                   (symbol? (callback-declaration-default-branch cd))))
                          (make-diagnostic 'invalid-callback-declaration
                                           (callback-declaration-name cd)
                                           "only a decision callback may declare branch keys")
                          #f))
                    cbs))
       ;; §16.2:890 and §16.2:892. A span names its two callbacks BY NAME, so
       ;; resolution and kind are cross-references and therefore the verifier's
       ;; (decision 0020 item 1) -- `make-span-declaration` cannot see this table.
       ;; §10.4:515-516 fixes the two kinds; a span naming an event callback is
       ;; what §16.2:892 calls an invalid span callback declaration.
       (apply append
              (map (lambda (sd)
                     (let* ((dn (span-declaration-data-callback sd))
                            (cn (span-declaration-complete-callback sd))
                            (dd (find-callback cbs dn))
                            (cc (if (symbol? cn) (find-callback cbs cn) #f)))
                       (append
                        (if dd '()
                            (list (make-diagnostic 'missing-callback-declaration
                                                   (span-declaration-name sd)
                                                   "span data callback names no declaration")))
                        (if (or (not dd) (eq? (callback-declaration-kind dd) 'span-data))
                            '()
                            (list (make-diagnostic 'invalid-span-callback
                                                   (span-declaration-name sd)
                                                   "span data callback is not of kind span-data")))
                        (if (or (not (symbol? cn)) cc) '()
                            (list (make-diagnostic 'missing-callback-declaration
                                                   (span-declaration-name sd)
                                                   "span completion callback names no declaration")))
                        (if (or (not cc) (eq? (callback-declaration-kind cc) 'span-complete))
                            '()
                            (list (make-diagnostic 'invalid-span-callback
                                                   (span-declaration-name sd)
                                                   "span completion callback is not of kind span-complete"))))))
                   sps))
       ;; A callback of a span kind that no span names is unreachable: nothing
       ;; can ever invoke it, because only a span declaration reaches one.
       (filter values
               (map (lambda (cd)
                      (if (and (memq (callback-declaration-kind cd) '(span-data span-complete))
                               (not (span-referencing sps (callback-declaration-name cd))))
                          (make-diagnostic 'unreferenced-callback-declaration
                                           (callback-declaration-name cd)
                                           "span callback is named by no span")
                          #f))
                    cbs))
       ;; *** §16.2:901's NODE half (Milestone 5 Slice ②). *** ①b shipped the
       ;; declaration share -- "callback decision keys that collide with
       ;; reserved control outcomes" (:902) and the declaration's own shape --
       ;; and left this, which needs a node kind that did not exist.
       ;;
       ;; ONE code for the four faults, on §4.6's budget and on the precedent
       ;; `invalid-callback-declaration` set one slice earlier by covering two.
       ;; The MESSAGE separates them; diagnostics are compared by code, and a
       ;; code per fault would spend four on one plan bullet. The two faults
       ;; that already have codes reuse them: a node naming no declaration is
       ;; `missing-callback-declaration`, the code a SPAN naming no declaration
       ;; already reports, and a key listed twice is `duplicate-branch-key`.
       ;;
       ;; Decision 0020 item 1 is why all of this is here: every one of these
       ;; judgements needs the machine's callback table beside the node, and
       ;; `make-callback-node` cannot see it.
       (apply append
              (map (lambda (n)
                     (cond ((callback-node? n) (callback-node-diagnostics cbs n))
                           ;; *** THE OTHER HALF OF THE SAME BOUNDARY, and it was
                           ;; missing until Slice ③'s census reconciliation found
                           ;; it. *** `make-span-start-node` stores its span as a
                           ;; bare symbol and says so in its own comment --
                           ;; "whether it names a DECLARED span ... needs the
                           ;; machine's span table", assigned to §16.2:899 and
                           ;; pass 7. Pass 7 does not do it: it treats the symbol
                           ;; opaquely, because the LATTICE is well defined over
                           ;; any symbol.
                           ;;
                           ;; It was reachable, not theoretical: a machine whose
                           ;; span nodes named an undeclared span verified CLEAN
                           ;; and then raised `assertion-violation` out of
                           ;; `normalize-machine`'s `span-slot-of` -- a verified
                           ;; machine crashing the normalizer, which §9.2:368
                           ;; forbids in as many words.
                           ((or (span-start-node? n) (span-end-node? n))
                            (span-node-declaration-diagnostics sps n))
                           (else '())))
                   (machine-nodes m))))))

  ;; The span half of §16.2:901's "undeclared", written beside
  ;; `callback-node-diagnostics` and answering the same shape of question. There
  ;; is only ONE fault here where a callback node has four: a span node carries
  ;; no branch keys, no kind and no arity, so naming a declaration it can find is
  ;; the whole of its cross-reference.
  (define (span-node-declaration-diagnostics sps n)
    (let ((s (if (span-start-node? n) (span-start-node-span n) (span-end-node-span n))))
      (if (find-span sps s) '()
          (list (make-diagnostic 'missing-span-declaration (node-name n)
                                 "span node names an undeclared span")))))
  (define (find-span sps nm)
    (cond ((null? sps) #f)
          ((eq? (span-declaration-name (car sps)) nm) (car sps))
          (else (find-span (cdr sps) nm))))

  ;; The four faults, in the order §16.2:901 names them plus the invocation's
  ;; own precondition. Split out of `pass-declarations` rather than inlined
  ;; because it is the only block there that walks NODES, and because its five
  ;; arms would otherwise make one `map` body longer than the whole pass.
  (define (callback-node-diagnostics cbs n)
    (let* ((nm (callback-node-name n))
           (cn (callback-node-callback n))
           (cd (find-callback cbs cn))
           (keys (map car (callback-node-branch-targets n))))
      (cond
        ;; UNDECLARED, the resolution case: nothing else can be judged without
        ;; the declaration, so this arm answers alone rather than reporting four
        ;; findings about a name that resolves to nothing.
        ((not cd)
         (list (make-diagnostic 'missing-callback-declaration nm
                                "callback node names no declaration")))
        ;; §10.6:584 invokes "one named event or decision callback". A span
        ;; callback is reached only through a span declaration (§10.4:515-516),
        ;; never through a node, so naming one here is an invocation that can
        ;; never be what it says.
        ((not (memq (callback-declaration-kind cd) '(event decision)))
         (list (make-diagnostic 'invalid-callback-invocation nm
                                "callback node invokes a span callback")))
        (else
         (append
          ;; DUPLICATED. Before the undeclared/missing arms below, so a key
          ;; listed twice reports once as a duplicate rather than twice as
          ;; whatever else it is.
          (let kloop ((ks keys) (kseen '()) (kout '()))
            (if (null? ks) (reverse kout)
                (kloop (cdr ks) (cons (car ks) kseen)
                       (if (memq (car ks) kseen)
                           (cons (make-diagnostic 'duplicate-branch-key nm
                                                  "branch key listed twice on one node")
                                 kout)
                           kout))))
          ;; UNDECLARED keys. An EVENT callback declares none, so every key on
          ;; an event node lands here -- which is §13:812's first sentence
          ;; ("Event and span callbacks accept only continue, pause, or
          ;; failure") enforced statically rather than left to the runtime's
          ;; out-of-contract path.
          (filter values
                  (map (lambda (k)
                         (if (memq k (callback-declaration-branch-keys cd)) #f
                             (make-diagnostic 'invalid-callback-invocation nm
                                              "branch key is not declared by the callback")))
                       keys))
          ;; MISSING. §10.6:585 lets a decision "select only among statically
          ;; declared branch keys", so a declared key with no target on this
          ;; node is a result the machine cannot route -- and for an OPTIONAL
          ;; decision callback it is worse than that: §9.3:419's default branch
          ;; is taken with no callback to ask, so `normalize-machine` has
          ;; nothing to lower and raises. This check is what makes that raise
          ;; unreachable.
          (filter values
                  (map (lambda (k)
                         (if (memq k keys) #f
                             (make-diagnostic 'invalid-callback-invocation nm
                                              "callback declares a branch key this node gives no target")))
                       (callback-declaration-branch-keys cd))))))))

  ;; --- PASS 7: span-state dataflow (§16.3:925, decision 0029) ---------------
  ;;
  ;; *** A FIXPOINT, NOT AN ENUMERATION, and 0029 says why in one sentence: ***
  ;; §16.2:913 makes "normal consuming cycles, including the main HTTP message
  ;; loop" valid, so the set of reachable paths §14:843 quantifies over is
  ;; infinite on the very machine the plan names as its motivating example. A
  ;; walk over a finite domain terminates; an enumeration of paths does not.
  ;;
  ;; The abstract domain is 0029 item 1's FLAT lattice, of height two:
  ;;   #f            -- bottom: no state has reached this node yet
  ;;   none          -- no span is active
  ;;   (active . s)  -- span `s` is open, one element per declared span
  ;;   top           -- incoming edges disagree
  ;; so the join is `#f ⊔ x = x`, `x ⊔ x = x`, and `top` otherwise, and a value
  ;; can rise at most twice.
  (define (span-join a b)
    (cond ((not a) b)
          ((not b) a)
          ((equal? a b) a)
          (else 'top)))

  ;; *** TWO DIFFERENT QUESTIONS, and decision 0029 answers only the first. ***
  ;; Item 3 fixes the NODE DOMAIN -- 0027's relation, byte-reachability plus the
  ;; EOF walk -- and says nothing about which EDGES the transfer function
  ;; follows. The gap is load-bearing: §16.2:907 is "successful EOF with an
  ;; active span", and a dataflow over `node-out-targets` alone never reaches a
  ;; finish node that is only EOF-reachable, because that accessor excludes
  ;; eof-targets by construction.
  ;;
  ;; So the edge relation here is the one whose transitive closure IS 0027's
  ;; relation: byte edges while input can still arrive, then eof routes and
  ;; zero-width continuations, and never a byte edge after an eof-target. It is
  ;; deliberately not `all-out-targets`, which crosses an eof-target and then
  ;; keeps taking byte edges -- 0027 rejects that walk by name.
  ;;
  ;; A node's EOF successors: its own eof route when it has one (the four
  ;; input-reading kinds), and its zero-width continuations otherwise. Both
  ;; halves in one expression. They were disjoint by construction through
  ;; Milestone 5 -- `node-eof-target` answers #f for every zero-width kind and
  ;; `eof-successors` answered '() for every input-reading one -- and counted
  ;; consume (Milestone 6 Slice ①) is where they meet: its `next` is an EOF
  ;; successor too (decision 0030 item 5), so a counted consume with a symbolic
  ;; route contributes BOTH, which is exactly the join `classify` computes for
  ;; it. The `append` stays right.
  (define (eof-step n)
    (let ((t (node-eof-target n)))
      (append (if (symbol? t) (list t) '()) (eof-successors n))))

  ;; The parked set, in the shape §16.2:909's own block uses: the entry, every
  ;; byte-reachable pause, every byte-reachable callback (Slice ②), and every
  ;; byte-reachable node carrying its own EOF route.
  ;;
  ;; *** THIS IS THE SECOND HAND-WRITTEN COPY OF THAT DISJUNCTION, and the two
  ;; already differ. *** `pass-eof-execution`'s membership also lists
  ;; `span-end-node?` -- a span-data callback's pause parks the parser on that
  ;; node's completion substep -- and this one does not, because it was written
  ;; while the slice still believed a span end was not a parked state and only
  ;; the other site was corrected.
  ;;
  ;; The difference is INERT, and that is a derivation rather than luck: a
  ;; byte-reachable span end's `next` is already a byte out-edge, so `span-flow`'s
  ;; byte half carries it and seeding an EOF walk there would add a duplicate
  ;; edge to a relation that is joined, not counted. It is written down because
  ;; the next kind that can pause has to be added to BOTH, and a reader who
  ;; "fixes" this omission should know they changed nothing.
  (define (parked? m n br)
    (and (memq (node-name n) br)
         (or (eq? (node-name n) (machine-entry m))
             (pause-node? n)
             (callback-node? n)
             (symbol? (node-eof-target n)))))

  ;; 0027 item 1's relation, as its EDGE LIST. The occupiable set is this list's
  ;; closure from the entry, so the pass needs no separate node filter: a node no
  ;; execution can occupy is one nothing here points at, and it receives no state
  ;; for that reason rather than by being screened out (0029 item 3).
  (define (span-flow m)
    (let* ((nodes (machine-nodes m))
           (br (byte-reached m))
           (byte-edges
            (apply append
                   (map (lambda (n)
                          (if (memq (node-name n) br)
                              (map (lambda (t) (cons (node-name n) t))
                                   (node-out-targets n))
                              '()))
                        nodes)))
           (eof-nodes
            ;; A DFS over eof routes from the parked set, never taking a byte
            ;; edge: once an execution takes an eof-target it can never feed
            ;; again (§12.2's finish-ready row), which is the sentence
            ;; `pass-eof-execution` already records at its own gate.
            (let walk ((frontier (apply append
                                        (map (lambda (n)
                                               (if (parked? m n br) (eof-step n) '()))
                                             nodes)))
                       (seen '()))
              (cond ((null? frontier) seen)
                    ((memq (car frontier) seen) (walk (cdr frontier) seen))
                    (else
                     (let ((n (lookup nodes (car frontier))))
                       (walk (append (if n (eof-step n) '()) (cdr frontier))
                             (cons (car frontier) seen)))))))
           (eof-edges
            (apply append
                   (map (lambda (n)
                          (if (or (parked? m n br) (memq (node-name n) eof-nodes))
                              (map (lambda (t) (cons (node-name n) t)) (eof-step n))
                              '()))
                        nodes))))
      (append byte-edges eof-edges)))

  ;; The transfer function. `state` is the joined in-state; the answer is the
  ;; out-state, and any diagnostic is reported by the caller so that this stays
  ;; one decision per line.
  ;; `(list 'active s)` and NOT `(cons 'active s)`, and the reason is this
  ;; file's own rule: `edge-roles-in-source` collects the quoted symbol from
  ;; EVERY `(cons 'SYM ...)` form here, so a pair built that way would enter the
  ;; edge-role vocabulary as a thirteenth "role" and take the kind x position
  ;; matrix's A' row red on its BASELINE. Measured -- it did, on the first draft.
  (define (span-transfer n state)
    (cond ((span-start-node? n) (list 'active (span-start-node-span n)))
          ((span-end-node? n) 'none)
          (else state)))

  ;; 0029's Consequences table, transcribed rather than re-derived. `top` never
  ;; reaches here: the caller reports it at the merge and stops propagating,
  ;; which is what keeps this total.
  (define (span-node-diagnostics n state)
    (cond
      ((span-start-node? n)
       (let ((s (span-start-node-span n)))
         (cond ((eq? state 'none) '())
               ((and (pair? state) (eq? (cadr state) s))
                (list (make-diagnostic 'invalid-span-state (node-name n)
                                       "span re-entry: this span is already open")))
               ((pair? state)
                (list (make-diagnostic 'invalid-span-state (node-name n)
                                       "span overlap: another span is already open")))
               (else '()))))
      ((span-end-node? n)
       (let ((s (span-end-node-span n)))
         (cond ((and (pair? state) (eq? (cadr state) s)) '())
               ((pair? state)
                (list (make-diagnostic 'invalid-span-state (node-name n)
                                       "wrong end: a different span is open")))
               ((eq? state 'none)
                (list (make-diagnostic 'invalid-span-state (node-name n)
                                       "unmatched end: no span is open")))
               (else '()))))
      ;; §16.2:900. §13:826's exception -- "Only the active span's own data
      ;; callback may pause before the span closes" -- cannot apply to a NODE:
      ;; §16.2:901's node half admits only `event` and `decision` callbacks
      ;; there, and a span-data callback is reached through a span declaration
      ;; and the runtime's flush, never through a callback node. So every pause
      ;; node and every callback node is rejected with a span open.
      ((and (pair? state) (or (pause-node? n) (callback-node? n)))
       (list (make-diagnostic 'span-active-at-pause (node-name n)
                              "a pause or callback invocation is reachable with a span active")))
      ;; §16.2:907's span half and 0029 item 4. Only the SUCCESSFUL terminals:
      ;; §14:839 contemplates a span still open at an error terminal, which is
      ;; why decision 0023 item 5 kept `finish` distinguished from `error`.
      ((and (pair? state) (or (stop-node? n) (finish-node? n)))
       (list (make-diagnostic 'span-active-at-exit (node-name n)
                              "a successful terminal is reachable with a span active")))
      (else '())))

  (define (pass-spans m)
    (let* ((nodes (machine-nodes m))
           (edges (span-flow m))
           ;; The in-state map, as an association list rebuilt each round. A
           ;; node no execution can occupy contributes no state to a join and
           ;; receives none (0029 item 3), so it never appears here at all.
           (initial (list (cons (machine-entry m) 'none))))
      ;; Fixpoint. The domain has height two and `live` is finite, so a value
      ;; can rise at most twice per node and this terminates. The round counter
      ;; is a guard against a transfer function that is not monotone -- a
      ;; defect, not an input -- and raises rather than looping forever.
      (let round ((in initial) (fuel (* 3 (+ 1 (length nodes)))))
        (when (< fuel 0)
          (assertion-violation 'pass-spans "span dataflow did not converge" fuel))
        (let ((next
               (let step ((es edges) (acc in))
                 (if (null? es) acc
                     (let* ((e (car es))
                            (from (car e)) (to (cdr e))
                            (fs (cond ((assq from acc) => cdr) (else #f)))
                            (fn (lookup nodes from)))
                       (step (cdr es)
                             ;; No `live` filter here, and its absence is the
                             ;; point: `live` is the CLOSURE of this very edge
                             ;; relation, so every edge's target is in it by
                             ;; construction and a filter would never fire. 0029
                             ;; item 3 is satisfied by the relation, not by a
                             ;; guard -- and a guard that cannot guard is what
                             ;; this project deletes rather than documents.
                             ;; Measured: written as a filter first, its
                             ;; mutation shipped UNCAUGHT and said so.
                             ;; `(not fn)` stood here as a third disjunct and
                             ;; was DELETED: every edge's `from` is some node's
                             ;; own name, so `lookup` cannot miss, and the final
                             ;; review found it three lines under the comment
                             ;; below forbidding exactly this. The fourth dead
                             ;; guard this slice removed.
                             (if (or (not fs) (eq? fs 'top))
                                 ;; `top` does not flow onward (0029 item 2).
                                 acc
                                 (let* ((out (span-transfer fn fs))
                                        (old (cond ((assq to acc) => cdr) (else #f)))
                                        (j (span-join old out)))
                                   (if (equal? j old) acc
                                       (cons (cons to j)
                                             (remp (lambda (kv) (eq? (car kv) to)) acc)))))))))))
          (if (equal? (list-sort (lambda (a b) (string<? (symbol->string (car a))
                                                         (symbol->string (car b))))
                                 next)
                      (list-sort (lambda (a b) (string<? (symbol->string (car a))
                                                         (symbol->string (car b))))
                                 in))
              ;; Converged: report.
              (apply append
                     (map (lambda (n)
                            (let ((st (cond ((assq (node-name n) next) => cdr) (else #f))))
                              (cond ((not st) '())
                                    ;; 0029 item 2: a join yielding `top` is
                                    ;; itself a diagnostic, reported where it
                                    ;; arises. Reporting downstream would blame
                                    ;; an innocent node and falling silent would
                                    ;; be unsound.
                                    ((eq? st 'top)
                                     (list (make-diagnostic 'inconsistent-span-state
                                                            (node-name n)
                                                            "incoming edges disagree about the active span")))
                                    (else (span-node-diagnostics n st)))))
                          nodes))
              (round next (- fuel 1)))))))

  ;; Helpers, deliberately not named `lookup`: that one is over NODES and is
  ;; itself pin-visible.
  (define (find-callback cbs nm)
    (let floop ((cs cbs))
      (cond ((null? cs) #f)
            ((eq? (callback-declaration-name (car cs)) nm) (car cs))
            (else (floop (cdr cs))))))

  (define (span-referencing sps nm)
    (let sloop ((ps sps))
      (cond ((null? ps) #f)
            ((eq? (span-declaration-data-callback (car ps)) nm) #t)
            ((eq? (span-declaration-complete-callback (car ps)) nm) #t)
            (else (sloop (cdr ps))))))

  (define (verify-machine machine)
    (let ((ds (append (pass-schema machine)
                      (if (machine? machine)
                          (append (pass-names machine)
                                  (pass-fields machine)
                                  (pass-declarations machine)
                                  (pass-spans machine)
                                  (pass-overlap machine)
                                  (pass-sequence-ambiguity machine)
                                  (pass-reachability machine)
                                  (pass-zero-progress machine)
                                  (pass-eof machine)
                                  (pass-eof-execution machine)
                                  (pass-names-valid machine))
                          '()))))
      (make-verification-result (null? ds) ds machine)))

  (define (verification-ok? v) (verification-result-ok? v))
  (define (verification-diagnostics v) (verification-result-diagnostics v))
  (define (verification-machine v) (verification-result-machine v)))
