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
          diagnostic? diagnostic-code diagnostic-node diagnostic-message)
  (import (rnrs)
          (byte-machine private ir))

  ;; --- diagnostics ---
  (define diagnostic-tag (vector 'byte-machine-diagnostic))
  (define (make-diagnostic code node message) (vector diagnostic-tag code node message))
  (define (diagnostic? x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) diagnostic-tag)))
  (define (diagnostic-code d) (vector-ref d 1))
  (define (diagnostic-node d) (vector-ref d 2))
  (define (diagnostic-message d) (vector-ref d 3))

  ;; --- name grammar [a-z][a-z0-9-]* and reserved-set member 1 ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-name? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0)
           (lower-alpha? (string-ref s 0))
           (let loop ((i 1))
             (or (>= i (string-length s))
                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))
           (not (memq sym reserved-member-1)))))
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
  (define (zero-width-successors n)
    (cond ((pause-node? n) (list (pause-node-continuation n)))
          ;; A field action's `error` is a successor exactly when it has one:
          ;; the constructor makes it #f precisely when the operation cannot
          ;; fail, so this never yields a node no failure can reach.
          ((field-action-node? n)
           (let ((e (field-action-node-error n)))
             (if (symbol? e)
                 (list (field-action-node-next n) e)
                 (list (field-action-node-next n)))))
          ((field-branch-node? n)
           (list (field-branch-node-true-target n)
                 (field-branch-node-false-target n)))
          (else '())))

  (define (node-out-targets n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (edge-target (byte-case-edge c)))
                        (byte-dispatch-node-cases n))
                   (list (edge-target (byte-dispatch-node-fallback n)))))
          ;; A pause's single zero-width out-edge (§10.6): resolution-checked by
          ;; PASS 2 (a malformed continuation is 'missing-target, §16.2:905) and
          ;; walked by reachability. The §16.2:908 check below filters on
          ;; byte-dispatch-node?, sequence-dispatch-node? AND
          ;; integer-accumulate-node?; a pause is in none of them, so this arm
          ;; does not feed it. (The conclusion has always held. The stated REASON
          ;; named one predicate and went stale twice -- most recently when this
          ;; slice's own fix widened that filter, eight hundred lines below.)
          ((pause-node? n) (list (pause-node-continuation n)))
          ;; A sequence node's byte out-edges: every alternative's target plus
          ;; the mismatch edge's. Feeding this arm also repairs pass-names'
          ;; target resolution and byte-reached, which both walk this function.
          ((sequence-dispatch-node? n)
           (append (map sequence-case-target (sequence-dispatch-node-cases n))
                   (list (edge-target (sequence-dispatch-node-mismatch n)))))
          ;; The two zero-width kinds (Slice ②), which feed name resolution,
          ;; reachability and the :908 check below.
          ((or (field-action-node? n) (field-branch-node? n))
           (zero-width-successors n))
          ;; Integer accumulate (Slice ③). Three of its four explicit targets are
          ;; BYTE out-targets; the fourth, `eof-target`, is not -- it belongs to
          ;; node-eof-target below, exactly as a dispatch node's does, so that
          ;; `all-out-targets` adds it for reachability and the :908 filter does
          ;; not see it.
          ((integer-accumulate-node? n)
           (list (integer-accumulate-node-digit-target n)
                 (edge-target (integer-accumulate-node-nondigit-edge n))
                 (integer-accumulate-node-overflow-error n)))
          (else '())))
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
       (filter values
               (map (lambda (f)
                      (if (valid-name? (uint-field-name f)) #f
                          (make-diagnostic 'invalid-field-declaration (uint-field-name f)
                                           "field name is not portable")))
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

  (define (pass-field-operands m fs)
    (apply append
           (map (lambda (n)
                  (cond ((integer-accumulate-node? n)
                         (accumulate-operand-diagnostics fs n))
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
  (define (pass-reachability m)
    (let ((nodes (machine-nodes m)) (reached (reach-from m all-out-targets)))
      (filter values
              (map (lambda (n)
                     (if (memq (node-name n) reached) #f
                         (make-diagnostic 'unreachable-node (node-name n) "node is unreachable")))
                   nodes))))

  ;; PASS 5: zero-progress cycles — a reexecute-only cycle consumes no byte.
  (define (pass-zero-progress m)
    (let ((nodes (machine-nodes m)))
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
              ((or (field-action-node? n) (field-branch-node? n))
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
                     (if (and (or (byte-dispatch-node? n) (pause-node? n)
                                  (sequence-dispatch-node? n)
                                  (field-action-node? n) (field-branch-node? n)
                                  (integer-accumulate-node? n))
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
  (define eof-verdict-ranking
    '(finish unresolved error default-error eof-reachable-stop cycle))
  (define (eof-verdict-rank v)
    (let loop ((vs eof-verdict-ranking) (i 0))
      (cond ((null? vs) (assertion-violation 'eof-terminal "unranked verdict" v))
            ((eq? (car vs) v) i)
            (else (loop (cdr vs) (+ i 1))))))
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
  (define (eof-successors n) (zero-width-successors n))

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
              ;; have mandatory targets -- so this is the same unreachable shape
              ;; as the else below, answered rather than raised because an empty
              ;; join has an obvious identity and a missing kind does not.
              (or acc 'unresolved)
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
                ((or (pause-node? n) (field-action-node? n) (field-branch-node? n))
                 (join-over (eof-successors n) path))
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
                                   (map (lambda (t)
                                          (let ((tn (lookup nodes t)))
                                            (if (and tn (finish-node? tn))
                                                (make-diagnostic 'non-eof-into-finish (node-name n)
                                                                 "a byte edge targets a finish terminal")
                                                #f)))
                                        (node-out-targets n)))
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
                                    (symbol? (node-eof-target n))))
                           (case (eof-terminal m (node-name n))
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

  ;; PASS 7: generated-name safety (member 1) — machine, node, error names/codes.
  (define (pass-names-valid m)
    (append
     (if (valid-name? (machine-name m)) '()
         (list (make-diagnostic 'invalid-name (machine-name m) "machine name is not portable")))
     (filter values
             (map (lambda (n)
                    (if (valid-name? (node-name n)) #f
                        (make-diagnostic 'invalid-name (node-name n) "node name is not portable")))
                  (machine-nodes m)))
     (filter values
             (map (lambda (e)
                    (if (and (valid-name? (error-declaration-name e))
                             (valid-name? (error-declaration-code e))
                             (valid-reason? (error-declaration-reason e)))
                        #f
                        (make-diagnostic 'invalid-name (error-declaration-name e)
                                         "error name, code or reason is not portable")))
                  (machine-errors m)))))

  (define (verify-machine machine)
    (let ((ds (append (pass-schema machine)
                      (if (machine? machine)
                          (append (pass-names machine)
                                  (pass-fields machine)
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
