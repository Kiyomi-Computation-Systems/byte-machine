;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine verify): structural verification of a source machine into a
;;; verification-result carrying diagnostics and the machine. The checks are:
;;; schema, name resolution (nodes + error references), overlap over canonical
;;; matcher byte sets, sequence-alternative ambiguity, reachability from entry,
;;; zero-progress cycles, terminal/EOF shape, span-state dataflow, and
;;; generated-name safety. Error references are symbolic names resolved against
;;; the error declarations. Cross-alternative sequence collision is checked by
;;; pass-sequence-ambiguity, not by pass-overlap (which compares canonical byte
;;; sets within one byte-dispatch node); see pass-overlap's own filter.
;;; Diagnostics are compared by code, never by text.
(library (byte-machine verify)
  (export verify-machine verification-ok? verification-diagnostics
          verification-machine
          diagnostic? diagnostic-code diagnostic-node diagnostic-message
          diagnostic-edge diagnostic-severity diagnostic-machine
          diagnostic-declarations diagnostic-path)
  (import (rnrs)
          (byte-machine private ir)
          (byte-machine private names))

  ;; --- diagnostics ---
  ;; Seven fields in nine slots: tag, code, node, message, edge, severity,
  ;; machine, declarations, path. `edge` is the "edge/source label where
  ;; applicable", `#f` when it does not apply, so two findings from one node --
  ;; a `case` edge and a `fallback` edge into the same finish terminal -- stop
  ;; being the identical record. `severity`, `machine`, `declarations` and
  ;; `path` fill the remaining slots.
  (define diagnostic-tag (vector 'byte-machine-diagnostic))
  ;; ONE builder for all four constructors and `stamp-diagnostic`, folding four
  ;; near-identical nine-slot literals into one. Its name deliberately does NOT
  ;; begin `make-diagnostic`: the diagnostic-census test collects every
  ;; `(define (make-diagnostic...) ...)` header as an emission site, so a shared
  ;; builder in that family would be miscounted. None of the four constructors
  ;; -- nor this builder -- may be renamed into that family.
  (define (diagnostic-vector code node message edge severity machine declarations path)
    (vector diagnostic-tag code node message edge severity machine declarations path))
  ;; The four constructors, each a `(define (name ...) ...)` form -- NOT
  ;; `(define name (lambda ...))`, which the constructor census does not
  ;; collect, so a site under it would drop out of the per-code census silently.
  ;; Unfilled slots are `#f` (edge, severity, machine, path) or `'()`
  ;; (declarations); severity and machine are stamped once in `verify-machine`,
  ;; so no constructor fills them.
  (define (make-diagnostic code node message)
    (diagnostic-vector code node message #f #f #f '() #f))
  ;; Carries an edge label and a path: its one call site, the per-edge
  ;; byte-into-finish block, is a path site, so a four-argument arity would
  ;; leave it dead.
  (define (make-diagnostic/edge code node message edge path)
    (diagnostic-vector code node message edge #f #f '() path))
  (define (make-diagnostic/declarations code node message declarations)
    (diagnostic-vector code node message #f #f #f declarations #f))
  (define (make-diagnostic/path code node message path)
    (diagnostic-vector code node message #f #f #f '() path))
  ;; diagnostic? : Any -> Boolean
  (define (diagnostic? x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) diagnostic-tag)))
  ;; diagnostic-code : Diagnostic -> Symbol
  (define (diagnostic-code d) (vector-ref d 1))
  ;; diagnostic-node : Diagnostic -> (Option Symbol)
  (define (diagnostic-node d) (vector-ref d 2))
  ;; diagnostic-message : Diagnostic -> String
  (define (diagnostic-message d) (vector-ref d 3))
  ;; diagnostic-edge : Diagnostic -> (Option Symbol)
  (define (diagnostic-edge d) (vector-ref d 4))
  ;; diagnostic-severity : Diagnostic -> Severity
  (define (diagnostic-severity d) (vector-ref d 5))
  ;; diagnostic-machine : Diagnostic -> (Option Symbol)
  (define (diagnostic-machine d) (vector-ref d 6))
  ;; diagnostic-declarations : Diagnostic -> (Listof Symbol)
  (define (diagnostic-declarations d) (vector-ref d 7))
  ;; diagnostic-path : Diagnostic -> (Option (Listof Symbol))
  (define (diagnostic-path d) (vector-ref d 8))
  ;; Stamp severity and machine name onto a diagnostic, ONCE, in
  ;; `verify-machine`. Severity is the constant `error` -- warnings are deferred,
  ;; and a record that carries the field is what makes adding one a change to one
  ;; constant. The machine name is a single value `(and (machine? machine)
  ;; (machine-name machine))`, applied to the whole list: `#f` exactly for
  ;; `pass-schema`'s not-a-machine arm, because `verify-machine` runs every other
  ;; pass only under `(machine? machine)`, so a diagnostic with no machine name
  ;; is exactly one about something that is not a machine (including
  ;; `pass-schema`'s version arm, reached only when `(machine? machine)` already
  ;; holds). Its name is NOT a `make-diagnostic…`, or the constructor census
  ;; would count every stamp as an emission site; it routes through
  ;; `diagnostic-vector` for the same reason the constructors do.
  (define (stamp-diagnostic d machine-name)
    (diagnostic-vector (diagnostic-code d) (diagnostic-node d) (diagnostic-message d)
                       (diagnostic-edge d) 'error machine-name
                       (diagnostic-declarations d) (diagnostic-path d)))

  ;; --- name grammar [a-z][a-z0-9-]* and reserved-set member 1 ---
  ;; The grammar is (byte-machine private names)' `portable-name?` -- one body
  ;; shared with compile.sls's binding check and runtime.sls's callback-code
  ;; check. The reserved set (member 1) stays here: which reserved set applies is
  ;; a property of the site, and a declared NAME is barred from the R6RS
  ;; syntactic keywords only.
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  (define (valid-name? sym)
    (and (portable-name? sym)
         (not (memq sym reserved-member-1))))
  ;; reserved-member-1's exclusion of the R6RS syntactic keywords from a declared
  ;; NAME is kept even though it is arguably unwarranted: portability does not
  ;; require it (`if` is a portable symbol) and no declared name becomes a
  ;; generated identifier (a declared name reaches the emitted library only under
  ;; `quote`, as data). It is kept because relaxing it would move a verdict for no
  ;; consumer's benefit -- no machine anyone writes needs a node named `if`.
  ;;
  ;; An error declaration's static reason is restricted to printable ASCII plus
  ;; LF. That is a DIFFERENT repertoire from valid-name?'s, over a string rather
  ;; than a symbol, so this cannot reuse that predicate -- it reuses the
  ;; invalid-name CODE, since names, codes and reasons share one portability
  ;; rule. The check matters because a nonportable reason renders an unparseable
  ;; generated library, not a cosmetic defect. An EMPTY reason is accepted:
  ;; length is unconstrained, "" renders as a legal string literal, and
  ;; make-error-declaration already refuses a non-string.
  (define (reason-char? c)
    (or (and (char>=? c #\space) (char<=? c #\~)) (char=? c #\newline)))
  (define (valid-reason? s)
    (let loop ((i 0))
      (or (>= i (string-length s))
          (and (reason-char? (string-ref s i)) (loop (+ i 1))))))
  ;; The LABEL clause, total over every `source-label` in the tree: checked at
  ;; four arms in two passes -- `pass-names-valid`'s machine arm, its node arm
  ;; (the node's own label AND its byte or sequence cases' labels, reported under
  ;; the owning node because a case has no name), and its error-declaration arm,
  ;; and `pass-fields`' field arm -- beside the two declaration arms in
  ;; `pass-declarations`. It is a second CALL SITE of `valid-reason?` rather than
  ;; a second predicate: labels and reasons share one repertoire, and a
  ;; duplicated `reason-char?` would be two textually identical bodies (the
  ;; twinned-FIND trap this file already records).
  ;;
  ;; A label is embedded in no generated output today -- compile.sls reads no
  ;; source-label -- so unlike a nonportable reason (which renders an unparseable
  ;; generated library) a nonportable label cannot corrupt emission. What it
  ;; could corrupt is the diagnostic report, which does not consume the field
  ;; yet; the rejection is required either way.
  ;;
  ;; THREE VALUE SHAPES. The field type is unspecified and no constructor
  ;; validates it. `#f` is absence and passes. A symbol or a string is checked
  ;; against the repertoire. Anything else is REJECTED here rather than ignored
  ;; -- a label the diagnostic reporter cannot render is not a machine that
  ;; verified clean -- reported under the portability code.
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
  ;; mutation pinning one would resolve to three sites and the suite would
  ;; hard-fail at declaration (the SITES-fails-both-directions trap). Factoring
  ;; it does NOT collapse three decisions into one: each caller's arm -- whether
  ;; it consults this at all -- stays its own line, and only the shared fact,
  ;; "what does a zero-width node continue to", lives here.
  ;; Each target carries its edge ROLE alongside it. `zero-width-edges` is the
  ;; fact, and both `zero-width-successors` and `node-out-edges` are views of it;
  ;; attaching the roles in `node-out-edges` instead would recompute a field
  ;; action's successors in a second place -- the duplication this comment
  ;; forbids.
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
          ;; The callback node is zero-width, and the first with a VARIABLE
          ;; number of out-edges: a continue target, a pause continuation, and
          ;; one target per declared decision branch. All three roles are
          ;; successors on the byte side -- a resumed pause continues during feed
          ;; exactly as a continue does -- so all three belong to this census.
          ;;
          ;; The three roles are named for the three non-failing OUTCOMES, which
          ;; is what selects among them at run time. The branch role is
          ;; deliberately not the branch KEY: a role is an edge label and this
          ;; file's roles are a closed vocabulary the kind x position matrix maps,
          ;; so keying it by an application-chosen symbol would make that
          ;; vocabulary open and the matrix underivable.
          ;; The span-start and span-end kinds. Both are zero-width ("without
          ;; consuming input") and both have exactly ONE successor, so both reuse
          ;; the `next` role a field action already carries rather than minting
          ;; two roles that would say the same thing. A diagnostic naming a node
          ;; AND the role `next` is unambiguous; the role vocabulary this file
          ;; keeps is closed on purpose, and the kind x position matrix maps it.
          ((span-start-node? n) (list (cons 'next (span-start-node-next n))))
          ((span-end-node? n) (list (cons 'next (span-end-node-next n))))
          ((callback-node? n)
           (append (list (cons 'continue (callback-node-continue-target n)))
                   (map (lambda (b) (cons 'branch (cadr b)))
                        (callback-node-branch-targets n))
                   (list (cons 'pause (callback-node-pause-continuation n)))))
          (else '())))

  (define (zero-width-successors n) (map cdr (zero-width-edges n)))

  ;; ONE census, two views. `node-out-edges` is the census -- every byte
  ;; out-edge as a `(role . target)` pair -- and `node-out-targets` is a derived
  ;; view of it. Duplicating the cond to attach roles would make a second census.
  ;;
  ;; The role is the "edge/source label where applicable". It is a ROLE, not an
  ;; index: verify.sls declines elsewhere to promise the order of two diagnostics
  ;; from one node, and an index would newly promise it.
  (define (node-out-edges n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (cons 'case (edge-target (byte-case-edge c))))
                        (byte-dispatch-node-cases n))
                   (list (cons 'fallback (edge-target (byte-dispatch-node-fallback n))))))
          ;; A pause's single zero-width out-edge: resolution-checked by PASS 2
          ;; (a malformed continuation is 'missing-target) and walked by
          ;; reachability. The byte-into-finish check is gated on
          ;; byte-reachability rather than on a source-kind filter, so this arm
          ;; DOES feed it -- a byte-reachable pause continuing into a finish is
          ;; rejected, and an EOF-only one is not.
          ((pause-node? n) (zero-width-edges n))
          ((sequence-dispatch-node? n)
           (append (map (lambda (c) (cons 'alternative (sequence-case-target c)))
                        (sequence-dispatch-node-cases n))
                   (list (cons 'mismatch
                               (edge-target (sequence-dispatch-node-mismatch n))))))
          ;; Keyword table: one byte out-target per keyword entry (role
          ;; `keyword`) plus the no-match edge's target; its eof-target belongs to
          ;; node-eof-target below, as a sequence node's does.
          ((keyword-table-node? n)
           (append (map (lambda (e) (cons 'keyword (keyword-entry-target e)))
                        (keyword-table-node-entries n))
                   (list (cons 'no-match
                               (edge-target (keyword-table-node-no-match n))))))
          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (zero-width-edges n))
          ;; Integer accumulate: three of its four explicit targets are BYTE
          ;; out-targets; the fourth, `eof-target`, is not -- it belongs to
          ;; node-eof-target below.
          ((integer-accumulate-node? n)
           (list (cons 'digit (integer-accumulate-node-digit-target n))
                 (cons 'nondigit
                       (edge-target (integer-accumulate-node-nondigit-edge n)))
                 (cons 'overflow (integer-accumulate-node-overflow-error n))))
          ;; Counted consume: its one explicit target is the byte edge taken
          ;; after a commit, role `next`; its eof-target is node-eof-target's, as
          ;; accumulate's is. A zero count reaches `next` without a byte as well
          ;; -- that route is `eof-successors`' and `reexec-targets`', not this
          ;; one's.
          ((counted-consume-node? n)
           (list (cons 'next (counted-consume-node-next n))))
          (else '())))

  (define (node-out-targets n) (map cdr (node-out-edges n)))
  ;; A dispatch/sequence node's stored eof-target (a symbol, or #f meaning
  ;; "the machine default eof error"), or #f for any other node kind. The single
  ;; source of "node kind -> eof-target accessor" for the sites below that were
  ;; previously independent copies of the same cond. eof-terminal's two parallel
  ;; cond arms (below) are left as their own arms, not routed through this helper
  ;; -- see the comment there for why.
  (define (node-eof-target n)
    (cond ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
          ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
          ;; A keyword table is input-reading and declares its own EOF edge, the
          ;; byte-dispatch convention -- #f means the machine default.
          ((keyword-table-node? n) (keyword-table-node-eof-target n))
          ;; An accumulate node declares its own EOF edge, with #f meaning the
          ;; machine default -- the byte-dispatch convention.
          ((integer-accumulate-node? n) (integer-accumulate-node-eof-target n))
          ;; Counted consume, the fourth input-reading kind, same convention.
          ((counted-consume-node? n) (counted-consume-node-eof-target n))
          (else #f)))
  ;; Visited-set DFS from the machine's entry, following whatever edge function
  ;; `targets` selects. Returns a `(name . parent)` alist -- the DFS tree, `#f`
  ;; the parent at the entry -- so `byte-reached` reads the keys and the
  ;; byte-into-finish block reads a path back to the entry from it. It has TWO
  ;; callers, `byte-reached` and that block; the parameter stays because it is
  ;; what names the walk -- a DFS over an edge function, with the edge function
  ;; at the call site rather than inlined here -- and because the EOF half of
  ;; occupiability is a different shape of walk (`eof-visited`, seeded from a SET
  ;; of parked nodes rather than from the entry).
  (define (reach-from m targets)
    (let ((nodes (machine-nodes m)) (parents '()))
      (let visit ((name (machine-entry m)) (parent #f))
        (let ((n (lookup nodes name)))
          (when (and n (not (assq name parents)))
            (set! parents (cons (cons name parent) parents))
            (for-each (lambda (t) (visit t name)) (targets n)))))
      parents))
  ;; The path from the entry to `name` over `reach-from`'s alist, entry first.
  ;; `name` is a key by construction -- the byte-into-finish block passes only
  ;; `br908` members, which are exactly `reach-from`'s keys -- so the walk
  ;; terminates at the entry (parent `#f`); a guard for a non-member would be a
  ;; guard that cannot guard, which this file deletes rather than documents.
  (define (parent-path parents name)
    (let loop ((name name) (acc '()))
      (let ((parent (cond ((assq name parents) => cdr) (else #f))))
        (if parent (loop parent (cons name acc)) (cons name acc)))))

  ;; PASS 1: schema — invalid descriptor shapes AND unsupported IR versions.
  ;; Both halves report `invalid-shape`.
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
                       (cons (make-diagnostic/declarations 'duplicate-error-declaration (car es)
                                              "duplicate error declaration name" (list (car es))) out)
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
                         (list (make-diagnostic/declarations 'missing-error-declaration (node-name n)
                                                "error node names an undeclared error" (list (error-node-error-name n))))
                         '()))
                   nodes)))))

  ;; PASS 6a (DECLARATION HALF ONLY): field declarations, carrying exactly the
  ;; checks assigned to the verifier. A field's WIDTH and its INITIAL's range are
  ;; constructor contracts, rejected at `make-uint-field` and unrepresentable
  ;; thereafter, so an arm here for either would be unreachable code that no test
  ;; could redden. What is left is RELATIONAL and therefore cannot live in a
  ;; constructor that sees one field at a time: two fields sharing a name, and a
  ;; name outside the portable repertoire.
  ;;
  ;; Both report `invalid-field-declaration` with the offending FIELD name in the
  ;; diagnostic's `node` slot -- the slot is the identifying name of whatever the
  ;; diagnostic is about, which for a field diagnostic is the field.
  ;;
  ;; This is a pass of its own rather than two more arms on `pass-names` and
  ;; `pass-names-valid`, so that those two keep the pin-visible shape they were
  ;; measured with, and so the operand half has one place to live. `valid-name?`
  ;; is reused exactly as `pass-names-valid` uses it: fields sit in the same
  ;; generated namespace as nodes and errors and get the same grammar, not a
  ;; parallel one that could drift.
  (define (pass-fields m)
    (let ((fs (machine-fields m)))
      (append
       ;; The loop variables are named apart from `pass-names`' node-duplicate
       ;; loop on purpose: the two walks are the same shape, and cloning its
       ;; identifiers would give this file two textually identical `(memq nm
       ;; seen)` lines -- one FIND the mutation suite resolves to TWO sites, which
       ;; silently mutates the node check too.
       (let scan ((rest fs) (fseen '()) (out '()))
         (if (null? rest) (reverse out)
             (let ((fname (uint-field-name (car rest))))
               (scan (cdr rest) (cons fname fseen)
                     (if (memq fname fseen)
                         (cons (make-diagnostic/declarations 'invalid-field-declaration fname
                                                "duplicate field name" (list fname)) out)
                         out)))))
       ;; The label clause is folded into this arm's test, the shape the
       ;; error-declaration arm of `pass-names-valid` set: one finding for a
       ;; field bad in name or label, and no new emission site.
       (filter values
               (map (lambda (f)
                      (if (and (valid-name? (uint-field-name f))
                               (valid-label? (uint-field-source-label f)))
                          #f
                          (make-diagnostic/declarations 'invalid-field-declaration (uint-field-name f)
                                           "field name or label is not portable" (list (uint-field-name f)))))
                    fs))
       (pass-field-operands m fs))))

  ;; --- the OPERAND half. Everything here needs a SECOND object -- the field
  ;; declaration -- to evaluate at all, which is precisely why none of it is a
  ;; constructor contract. The constructor closed what one node can answer: the
  ;; operation and predicate sets, and `arguments` being a proper list.
  ;; Everything below is relational.
  ;;
  ;; It lives INSIDE pass-fields rather than in a pass of its own: a sibling pass
  ;; would duplicate an indentation-anchored line that `verify: pass-fields is
  ;; never run` pins at SITES=1, and would leave the accumulate share two
  ;; candidate homes.
  ;;
  ;; ONE code, `invalid-field-operand`. The accumulate share reuses it with NO
  ;; NEW CODE and extends THIS pass -- there is deliberately one candidate home,
  ;; not two, and `field-operand-schemas` below is where its rows go.
  (define field-operand-schemas
    ;; (name arity . operand-kinds-after-the-field). Position 0 is the `field`
    ;; in every one of the fourteen, which is why it is not repeated per row.
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
        ;; Exact arity: it rejects extra arguments. Reported alone: nothing can
        ;; be read out of `arguments` before arity is known, which is why this
        ;; check is here rather than in the constructor.
        (list (make-diagnostic 'invalid-field-operand name "wrong number of operands")))
       (else
        (let ((width (field-width-of fs (car args))))
          (cond
           ((not width)
            (list (make-diagnostic/declarations 'invalid-field-operand name
                                   "operand names no declared field" (list (car args)))))
           (else
            (append
             (filter values
                     (map (lambda (v)
                            (if (operand-in-width? v width) #f
                                (make-diagnostic/declarations 'invalid-field-operand name
                                                 "operand is outside the field's declared width" (list (car args)))))
                          (cdr args)))
             ;; `low <= high` for `range`. make-byte-range-matcher rejects
             ;; `low > high` there as named parameters; here they are list
             ;; positions the constructor may not read before arity is known.
             (if (and (eq? selector 'range)
                      (operand-in-width? (cadr args) width)
                      (operand-in-width? (caddr args) width)
                      (> (cadr args) (caddr args)))
                 (list (make-diagnostic/declarations 'invalid-field-operand name
                                        "range low exceeds high" (list (car args))))
                 '())))))))))

  ;; The accumulate share is a SIBLING ARM, not a `field-operand-schemas` row:
  ;; that table is keyed on a SELECTOR and an ARITY, and an accumulate node has
  ;; `field` and `base` and neither. It lives in `pass-fields` and reuses
  ;; `invalid-field-operand`, keeping the one-home promise.
  ;;
  ;; Only the FIELD REFERENCE: the base is closed at construction, so an arm for
  ;; it here would be dead code whose permissive mutation survives. Reported
  ;; under the NODE's name, matching the convention the operand walk above states
  ;; -- prescribing the field name instead would put two conventions under one
  ;; code.
  (define (accumulate-operand-diagnostics fs n)
    (if (field-width-of fs (integer-accumulate-node-field n))
        '()
        (list (make-diagnostic/declarations 'invalid-field-operand (node-name n)
                               "accumulate names no declared field" (list (integer-accumulate-node-field n))))))

  ;; "Counted consume using an incompatible field". Its own arm beside
  ;; accumulate's and not folded into it -- each construct arrives with its own
  ;; check and inherits nothing -- reusing the CODE, the precedent accumulate
  ;; set. Only the field reference: one field type exists and more is deferred,
  ;; so every declared field is a count a consume can draw from and
  ;; "incompatible" reduces to "undeclared". When a second field type arrives,
  ;; this arm is where the incompatibility check gains content. Reported under
  ;; the NODE's name, on the operand walk's convention.
  (define (counted-operand-diagnostics fs n)
    (if (field-width-of fs (counted-consume-node-field n))
        '()
        (list (make-diagnostic/declarations 'invalid-field-operand (node-name n)
                               "counted consume names no declared field" (list (counted-consume-node-field n))))))

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

  ;; PASS 3: overlap within a dispatch node, over canonical matcher byte sets.
  ;; Two cases overlap when their canonical sets share any byte; an exact-byte
  ;; matcher is the one-element case of the same rule.
  (define (byte-sets-overlap? a b)
    (and (pair? a) (or (and (memv (car a) b) #t) (byte-sets-overlap? (cdr a) b))))
  ;; One diagnostic per COLLIDING PAIR of cases, not one per shared byte. A
  ;; complement and a set can share 200 bytes, and a naive per-byte expansion
  ;; would turn one decision into 200 identical diagnostics. Pairs are enumerated
  ;; i < j so a pair is reported once, and the pass never inspects the lowered
  ;; graph: canonical byte sets are a source-level property
  ;; (verify-before-normalize). Every diagnostic a node contributes shares that
  ;; node's (code, node, message) triple, so no pair carries an identity of its
  ;; own: the relative order between two diagnostics from the same node is not
  ;; observable (by anything short of object identity) and is not promised.
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
  ;; two sequence ALTERNATIVES collide is ambiguity, which pass-sequence-ambiguity
  ;; below owns. Overlap and ambiguity stay two checks with two codes, and the
  ;; predicates genuinely differ -- this pass compares canonical matcher byte
  ;; SETS within one byte-dispatch node; that one compares the prefix relation
  ;; between byte STRINGS. A sequence node is invisible to this pass permanently.
  (define (pass-overlap m)
    (apply append
           (map (lambda (n) (if (byte-dispatch-node? n) (node-overlaps n) '()))
                (machine-nodes m))))

  ;; Sequence ambiguity, an unnumbered pass beside PASS 3 because renumbering
  ;; PASS 4-7 would stale every existing reference to those numbers for nothing.
  ;; pass-eof-execution below is the precedent for an unnumbered pass.
  ;;
  ;; "After prefix analysis" is what the pairwise test below IS: one alternative
  ;; being a terminal prefix of another is decidable from the source byte lists
  ;; alone, so this pass never inspects the lowered graph and the
  ;; verify-before-normalize ordering is preserved. It is equivalent to the
  ;; normalizer's three trie guards.
  ;;
  ;; Duplicate alternatives are the MAXIMAL case of the same relation (`AB` is a
  ;; terminal prefix of `AB`), so both shapes carry the one code. Alternatives
  ;; that merely SHARE a nonterminal prefix -- `AB` and `AC` -- are explicitly
  ;; legal; the trie merges them, and a check that could not tell the two apart
  ;; would reject every branching machine.
  (define (byte-prefix? a b)
    (cond ((null? a) #t)
          ((null? b) #f)
          ((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b)))
          (else #f)))
  ;; One diagnostic per COLLIDING PAIR, enumerated i < j so a pair is reported
  ;; once -- pass-overlap's convention above, one finding per decision. Every
  ;; diagnostic a node contributes shares that node's (code, node, message)
  ;; triple, so no pair carries an identity of its own and the relative order of
  ;; two diagnostics from one node is not promised.
  ;;
  ;; The bindings are deliberately NOT node-overlaps' (`ss`/`outer`/`rest`/
  ;; `inner`/`out`): three shipped mutations pin single lines of that skeleton,
  ;; and a structural clone takes each from one occurrence to two, failing the
  ;; suite with "pattern occurs 2 times ... expected 1".
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

  ;; Keyword-table validity, an unnumbered pass beside pass-sequence-ambiguity and
  ;; the INVERSE of it. Proper prefixes are the whole point of a keyword table
  ;; (GET vs GET-PARAMETER), so they are permitted; the only cross-entry defect
  ;; this slice rejects is an EXACT duplicate -- two entries with identical bytes,
  ;; which would make the trie's terminal choice at that keyword ambiguous. A
  ;; case-insensitive table's FOLD collision (two entries equal after folding) is
  ;; the same defect one fold up and is Slice ②'s (decision 0045).
  ;;
  ;; The bindings are this pass's own (`kws`/`rest`/`others`/`dups`), never
  ;; node-overlaps' or node-ambiguities', so no shipped mutation's single-line
  ;; FIND doubles (AGENTS.md, "SITES fails in BOTH directions").
  (define (node-keyword-defects n)
    (let ((kws (map keyword-entry-bytes (keyword-table-node-entries n))))
      (let scan ((rest kws) (dups '()))
        (if (null? rest)
            dups
            (scan (cdr rest)
                  (let probe ((others (cdr rest)) (dups dups))
                    (if (null? others)
                        dups
                        (probe (cdr others)
                               (if (equal? (car rest) (car others))
                                   (cons (make-diagnostic 'duplicate-keyword (node-name n)
                                                          "two keyword entries have the same bytes")
                                         dups)
                                   dups)))))))))
  (define (pass-keyword-table m)
    (apply append
           (map (lambda (n) (if (keyword-table-node? n) (node-keyword-defects n) '()))
                (machine-nodes m))))

  ;; PASS 4: reachability from entry.
  ;; "UNREACHABLE" QUANTIFIES OVER WHAT AN EXECUTION CAN OCCUPY. The pass walks
  ;; `occupiable` -- byte-reached plus the EOF walk from the parked set, the
  ;; relation the EOF checks and pass 7 already read -- so a node reachable only
  ;; through an edge no execution can take is reported here.
  ;;
  ;; The family this handles is `E ->(eof) T ->(byte) Z`: T reachable only as an
  ;; eof-target and one of the three kinds whose byte edges are dead at EOF --
  ;; byte-dispatch, sequence-dispatch, integer-accumulate, the kinds with no EOF
  ;; successor of their own -- and Z distinct from T behind such an edge. A
  ;; counted consume as T is NOT in it: its `next` is an EOF successor.
  (define (pass-reachability m)
    (let ((nodes (machine-nodes m)) (reached (occupiable m)))
      (filter values
              (map (lambda (n)
                     (if (memq (node-name n) reached) #f
                         (make-diagnostic 'unreachable-node (node-name n) "node is unreachable")))
                   nodes))))

  ;; PASS 5: zero-progress cycles — a reexecute-only cycle consumes no byte.
  ;;
  ;; THE GATE IS `byte-reached` ALONE, not the occupiable composite, because the
  ;; two halves are two separate checks: "reachable zero-progress cycles" here,
  ;; and "EOF-only zero-progress cycles" owned by `eof-terminal`'s `walk` (which
  ;; answers `cycle` on `(memq name path)`) and reported by `pass-eof-execution`
  ;; as `eof-zero-progress-cycle`. So an EOF-only zero-progress cycle stays
  ;; rejected after this gate, by the check whose job it is; gating on the
  ;; composite would make the two checks overlap on exactly the machines the EOF
  ;; check was written for.
  ;;
  ;; This gate is a RELAXATION, and such a machine is NOT caught by
  ;; `unreachable-node`: where `t` is the entry's eof-target it is OCCUPIABLE
  ;; (the EOF walk starts at the parked entry and visits it), and its self-loop
  ;; is the only edge no execution can take -- narrowing reachability does not
  ;; reach this shape, because the unreachable thing here is an edge and not a
  ;; node. The fixture in verify-tests asserts the machine both ways.
  (define (pass-zero-progress m)
    (let ((nodes (machine-nodes m)) (br898 (byte-reached m)))
      (define (reexec-targets n)
        (cond ((byte-dispatch-node? n)
               (append (map (lambda (c) (edge-target (byte-case-edge c)))
                            (filter (lambda (c) (eq? (edge-mode (byte-case-edge c)) 'reexecute))
                                    (byte-dispatch-node-cases n)))
                       (if (eq? (edge-mode (byte-dispatch-node-fallback n)) 'reexecute)
                           (list (edge-target (byte-dispatch-node-fallback n))) '())))
              ;; A pause consumes no input: its continuation is a zero-width
              ;; edge, so a reexecute/pause-only cycle with no advance is a
              ;; zero-progress cycle.
              ((pause-node? n) (list (pause-node-continuation n)))
              ;; Only the mismatch edge can be reexecute; every case edge
              ;; advances by construction. This teaches the WALK to see through a
              ;; sequence node, so a self-targeting reexecute mismatch edge is
              ;; flagged.
              ;;
              ;; Why the source-level walk is exact enough at lowered
              ;; granularity: NO ZERO-WIDTH EDGE CAN ENTER A POSITION->=1 PREFIX
              ;; STATE. Every trie edge advances, so a prefix state at position
              ;; k >= 1 is reached only by consuming a byte; the only zero-width
              ;; edge out of any sequence-derived state is the shared mismatch
              ;; edge this arm returns. The lowered zero-width cycle set is
              ;; therefore exactly the source-level one and no position->=1
              ;; state can be a cycle MEMBER -- which is why verification never
              ;; needs the lowered graph.
              ;;
              ;; KNOWN, DELIBERATE OVER-REJECTION: self-cycle is a pure edge walk
              ;; and never asks whether the arm closing the cycle is reachable
              ;; for any byte. A sequence node whose alternatives' first bytes
              ;; cover all 256 values has a dead root fallback and cannot loop,
              ;; yet is reported (256 alternatives (b 0) -> stop, mismatch
              ;; reexecute -> itself, terminates on every input). The
              ;; byte-dispatch analysis is already exactly this conservative -- a
              ;; node whose single case is (make-byte-range-matcher 0 255) with a
              ;; reexecute self-fallback reports zero-progress-cycle -- so this
              ;; preserves a uniform conservatism. Making it exact would need the
              ;; same reachability refinement for byte-dispatch fallbacks and
              ;; would change existing verdicts.
              ((sequence-dispatch-node? n)
               (if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
                   (list (edge-target (sequence-dispatch-node-mismatch n))) '()))
              ;; Keyword table: like a sequence, only the NO-MATCH edge can be
              ;; reexecute and thus zero-progress. Every keyword target is reached
              ;; only after consuming that keyword's bytes (a non-empty entry, so
              ;; >= 1 byte), so those targets make progress and stay out -- the
              ;; sequence-alternative reasoning above.
              ((keyword-table-node? n)
               (if (eq? (edge-mode (keyword-table-node-no-match n)) 'reexecute)
                   (list (edge-target (keyword-table-node-no-match n))) '()))
              ;; The field-action and field-branch kinds are ZERO-WIDTH, exactly
              ;; like a pause: every edge out of them makes no progress, so each
              ;; is a reexecute-equivalent and joins this walk. A
              ;; `store`-into-itself machine verifies clean and then hangs in
              ;; BOTH lanes without this. (Integer accumulate is input-reading,
              ;; not zero-width, so it does NOT belong in `zero-width-successors`
              ;; -- it consumes a byte and makes progress; its own arm is below.)
              ;;
              ;; The callback node joins for the same reason: every one of its
              ;; three edges is zero-width, so a callback that continues,
              ;; branches or resumes into itself invokes its callback forever
              ;; without reading a byte, and neither runtime loop guards against
              ;; it. Extending this walk requires extending the REPORT guard
              ;; below in step: the walk alone finds the cycle but nothing
              ;; reports it, and verify returns ok with zero diagnostics.
              ((or (field-action-node? n) (field-branch-node? n)
                   (callback-node? n)
                   (span-start-node? n) (span-end-node? n))
               (zero-width-successors n))
              ;; Integer accumulate contributes TWO edges, not one. Only the
              ;; `nondigit-edge` can be `reexecute` (the digit edge always
              ;; advances, so it stays out). The overflow edge joins
              ;; unconditionally: it is NON-CONSUMING and leaves the field
              ;; unchanged, so an overflow-error naming its own accumulate node
              ;; re-reads the same byte forever, and neither runtime loop guards
              ;; against that. Its target's kind is unconstrained -- overflow
              ;; names a target NODE, not necessarily an error terminal.
              ;;
              ;; The overflow and nondigit self-cycles need SEPARATE fixtures --
              ;; neither distinguishes the other's mutant, and the REPORT guard
              ;; below has the same blind spot.
              ((integer-accumulate-node? n)
               (append
                (if (eq? (edge-mode (integer-accumulate-node-nondigit-edge n)) 'reexecute)
                    (list (edge-target (integer-accumulate-node-nondigit-edge n)))
                    '())
                (list (integer-accumulate-node-overflow-error n))))
              ;; Counted consume: `next` is taken without consuming exactly when
              ;; the count is zero, which this pass cannot see, so it joins
              ;; unconditionally -- the overflow edge's shape above. A
              ;; self-targeting `next` hangs both executors the first time its
              ;; count is zero. This over-rejects (a loop terminated by a field
              ;; value is rejected) but is bounded (a loop with a byte dispatch
              ;; in it is untouched).
              ((counted-consume-node? n) (list (counted-consume-node-next n)))
              (else '())))
      ;; The cycle from `start` back to itself, or #f: a frontier walk that
      ;; carries parent routes, so a finding can report the cycle rather than
      ;; only a yes/no. Each frontier entry is `(name . route)` -- a VARIABLE
      ;; car, so it does not trip the `(cons 'SYM …)` edge-role census -- with
      ;; `route` the reexecute path from a first hop to `name`, most-recent-first.
      ;; Reaching `start` again closes the cycle with `start` at both ends; a
      ;; self-loop is the two-element `(start start)`. A name ending in `?` that
      ;; answers a list would be a comment that lies, hence the name.
      (define (self-cycle start)
        (let loop ((frontier (map (lambda (t) (cons t (list t)))
                                  (reexec-targets (lookup nodes start))))
                   (seen '()))
          (cond ((null? frontier) #f)
                ((eq? (caar frontier) start) (cons start (reverse (cdar frontier))))
                ((memq (caar frontier) seen) (loop (cdr frontier) seen))
                (else
                 (let ((route (cdar frontier)) (n (lookup nodes (caar frontier))))
                   (loop (append (map (lambda (t) (cons t (cons t route)))
                                      (if n (reexec-targets n) '()))
                                 (cdr frontier))
                         (cons (caar frontier) seen)))))))
      (filter values
              (map (lambda (n)
                     ;; The REPORT set, which must be extended together with the
                     ;; walk above. Extending one without the other is a half-fix:
                     ;; the walk finds the cycle, nothing reports it, verify
                     ;; returns ok with zero diagnostics, and the machine fails to
                     ;; terminate in both lanes. `self-cycle`'s returned cycle is
                     ;; bound here and rides into the diagnostic as its path.
                     (let ((cyc (and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))))
                       (if cyc
                           (make-diagnostic/path 'zero-progress-cycle (node-name n)
                                                 "a zero-progress cycle (reexecute edges, pause continuations, field actions and branches, accumulate overflow edges) makes no progress"
                                                 cyc)
                           #f)))
                   nodes))))

  ;; PASS 6: EOF shape — the machine default eof error names a declared error;
  ;; a dispatch eof-target (when a symbol) resolves to a node.
  (define (pass-eof m)
    (let ((nodes (machine-nodes m)))
      (append
       (if (memq (machine-default-eof-error m) (error-names m)) '()
           (list (make-diagnostic/declarations 'invalid-eof-target (machine-default-eof-error m)
                                  "machine default eof error names no declared error" (list (machine-default-eof-error m)))))
       (apply append
              (map (lambda (n)
                     (let ((t (node-eof-target n)))
                       (if (or (eq? t #f) (lookup nodes t)) '()
                           (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                  "eof-target names no node")))))
                   nodes)))))

  ;; Classify the EOF continuation of `start`. Answers over a SET of successors,
  ;; because a field branch has two targets and a field action has `next` plus
  ;; `error`.
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
  ;; `'unknown` is DELETED, not ranked least: a residual arm may not reintroduce
  ;; an answer that has left the answer set. Every kind `ir.sls` can construct
  ;; has its own arm, so the residual `else` is unreachable and raises, matching
  ;; the loud-else convention in normal-ir.sls, compile.sls and runtime.sls.
  ;; THREE TIERS, not a flat six.
  ;;
  ;; The join takes the max, so the order decides which sibling verdict survives.
  ;; A flat list of six has 720 orderings, but only THREE equivalence classes are
  ;; observable and 24 of the orderings are indistinguishable by any machine. An
  ;; unwitnessable ordering is not a decision -- and worse, four of the six
  ;; undecidable pairs are ACCEPTANCE HOLES: with `default-error` ranked above
  ;; `cycle`, a field-branch machine verifies with zero diagnostics and
  ;; `parser-finish!` never returns.
  ;;
  ;; Tiers make the 24-permutation survivor unwritable, and turn each tier
  ;; assignment into a single-token mutation caught by a failed comparison rather
  ;; than by a raise.
  ;;
  ;; All six symbols are KEPT. The span check needs `finish` distinguished from
  ;; `error` at `classify`, and the loud-else discipline forbids merging arms.
  ;;
  ;; `unresolved` is PRODUCIBLE: `classify`'s `((not n) 'unresolved)` arm answers
  ;; it for any EOF successor naming no node -- reached by two routes (a
  ;; dispatch's dangling eof-target, and a zero-width arm naming nothing). So
  ;; `unresolved`'s tier is load-bearing: a machine whose EOF chain reaches a
  ;; dangling name AND a stop must still report the stop, which happens only
  ;; because `unresolved` loses the join. That is a fixture and a pin.
  (define eof-verdict-tiers
    ;; Verdict tiers, worst first: the finish chain terminates; a stop is
    ;; EOF-reachable; a cycle outranks a reachable stop.
    '((finish unresolved error default-error)
      (eof-reachable-stop)
      (cycle)))
  (define (eof-verdict-rank v)
    (let loop ((ts eof-verdict-tiers) (i 0))
      (cond ((null? ts) (assertion-violation 'eof-terminal "unranked verdict" v))
            ((memq v (car ts)) i)
            (else (loop (cdr ts) (+ i 1))))))
  ;; Sibling answers join by max. Only `cycle > eof-reachable-stop` is pinned --
  ;; a cycle is the non-termination neither runtime loop guards against, so it
  ;; must survive a join -- and the rest of the order is a free choice within
  ;; that constraint.
  ;;
  ;; Each operand is a `(verdict path)` pair, so the rank reads its `car` and the
  ;; whole surviving pair is returned -- keeping the path beside its verdict. The
  ;; pair handling lives HERE, not at the call sites, so `join-over` and the
  ;; counted-consume join keep their FINDs. `>=` keeps the LEFT operand on a tie.
  ;; `>=` vs `>` matters only because tier 0 has four members (`finish`
  ;; `unresolved` `error` `default-error`), so a rank-0 tie can hold two
  ;; DIFFERENT symbols -- yet every rank-0 verdict is silent, since
  ;; `pass-eof-execution`'s `case` acts only on `eof-reachable-stop` and `cycle`.
  ;; A tie inside a SINGLETON tier -- two `eof-reachable-stop`s via distinct
  ;; nodes -- returns the same symbol with a different PATH, which a comparison
  ;; over the widened pair catches.
  (define (eof-verdict-join a b)
    (if (>= (eof-verdict-rank (car a)) (eof-verdict-rank (car b))) a b))

  ;; The nodes an EOF walk continues to. Empty at a terminal; one for a pause or
  ;; a dispatch with a symbolic eof-target; TWO for the zero-width field kinds,
  ;; which is the whole reason this walk became multi-successor. A field action's
  ;; `error` is a successor exactly when it has one -- the constructor makes that
  ;; `#f` precisely when the operation cannot fail.
  ;;
  ;; Counted consume is the one INPUT-READING kind with an EOF successor of its
  ;; own: a zero count takes `next` at EOF, and at a node the walk ARRIVES at the
  ;; count is unknown, so `next` is a successor unconditionally. One fact, two
  ;; consumers -- `classify`'s counted arm and pass 7's `eof-step` both read this
  ;; and cannot disagree -- which is `zero-width-edges`' rule applied a kind
  ;; later.
  (define (eof-successors n)
    (cond ((counted-consume-node? n) (list (counted-consume-node-next n)))
          (else (zero-width-successors n))))

  (define (eof-terminal m start)
    (let ((nodes (machine-nodes m)) (done '()))
      ;; Every verdict travels beside its path as a two-element `list` -- never a
      ;; `(cons 'verdict …)` pair, which `edge-roles-in-source` would collect as
      ;; a role and redden the kind x position matrix on its baseline. The path
      ;; runs from the walk's `start` (its tail) to the verdict's node.
      ;; `(reverse path)` occurs ONCE, here, so the "the path is not reversed"
      ;; mutation is a single site (SITES=1): all six verdict-producing sites --
      ;; this walk's `cycle`, `dispatch-arm`'s `default-error`, and `classify`'s
      ;; `unresolved`/`finish`/`error`/`eof-reachable-stop` -- route through it.
      (define (verdict v path) (list v (reverse path)))
      (define (walk name path)
        (cond ((memq name path) (verdict 'cycle (cons name path)))
              ((assq name done) => cdr)
              (else
               (let ((v (classify name (cons name path))))
                 (set! done (cons (cons name v) done))
                 v))))
      (define (dispatch-arm t path)
        (if (symbol? t) (walk t path) (verdict 'default-error path)))
      (define (join-over names path)
        (let loop ((ns names) (acc #f))
          (if (null? ns)
              ;; A zero-width node with no successors cannot occur -- both kinds
              ;; have mandatory targets. This arm is dead, and it raises rather
              ;; than answering quietly: answering an impossible input quietly is
              ;; how a verdict nothing produces could stay in the ranking
              ;; undetected. An impossible input made loud is a gap refused, not
              ;; a gap closed.
              (or acc (assertion-violation 'eof-terminal
                                           "empty zero-width join" names))
              (loop (cdr ns)
                    (let ((v (walk (car ns) path)))
                      (if acc (eof-verdict-join acc v) v))))))
      (define (classify name path)
        (let ((n (lookup nodes name)))
          (cond ((not n) (verdict 'unresolved path)) ; pass-eof reports missing target
                ((finish-node? n) (verdict 'finish path))
                ((error-node? n) (verdict 'error path))
                ((stop-node? n) (verdict 'eof-reachable-stop path))
                ;; Kept as two arms rather than routed through node-eof-target:
                ;; every other arm here is one predicate per kind, and merging
                ;; these two would be the only merged arm in an otherwise
                ;; exhaustive per-kind analysis -- obscuring that the decision is
                ;; made independently per kind even though the bodies coincide.
                ((byte-dispatch-node? n)
                 (dispatch-arm (byte-dispatch-node-eof-target n) path))
                ((sequence-dispatch-node? n)
                 (dispatch-arm (sequence-dispatch-node-eof-target n) path))
                ;; A keyword table is input-reading with its own eof-target, so it
                ;; hops exactly as the two arms above do.
                ((keyword-table-node? n)
                 (dispatch-arm (keyword-table-node-eof-target n) path))
                ;; A callback node classified HERE is being flowed through: the
                ;; EOF walk arrived at it, so `parser-finish!` will invoke the
                ;; callback and every one of its outcomes is live. That is why
                ;; the join is over all three edges, and it is NOT the same
                ;; question as which edge a parser PARKED at this node resumes on
                ;; -- see `parked-eof-start` below, the one place those two come
                ;; apart.
                ((or (pause-node? n) (field-action-node? n) (field-branch-node? n)
                     (callback-node? n)
                     (span-start-node? n) (span-end-node? n))
                 (join-over (eof-successors n) path))
                ;; Counted consume: BOTH families' answer, joined. The walk
                ;; ARRIVED here, so the count is unknown -- a positive count takes
                ;; the eof-target (the dispatch half) and a zero count takes
                ;; `next` (the zero-width half, read through `eof-successors` so
                ;; pass 7 cannot disagree). A stop behind `next` is
                ;; `eof-reachable-stop`: a machine whose entry is a counted
                ;; consume with initial 0, a #f route and a stop for `next` would
                ;; otherwise verify clean and answer `stopped` from
                ;; `parser-finish!`. `join-over` raises on an empty list; the list
                ;; here is always the one name.
                ((counted-consume-node? n)
                 (eof-verdict-join (dispatch-arm (counted-consume-node-eof-target n) path)
                                   (join-over (eof-successors n) path)))
                ;; An integer-accumulate node is a legal EOF target and carries
                ;; its own eof-target, so it classifies exactly as a dispatch
                ;; does: hop, and let the walk decide. Without this arm every EOF
                ;; chain that reached one falls into the `else` below and
                ;; `verify-machine` RAISES instead of returning a verification
                ;; result, on machines both executors already run correctly.
                ((integer-accumulate-node? n)
                 (dispatch-arm (integer-accumulate-node-eof-target n) path))
                (else (assertion-violation 'eof-terminal
                                           "no EOF classification for node kind" name)))))
      (walk start '())))

  ;; Byte-flow reachability (feed can arrive): entry DFS over node-out-targets
  ;; -- dispatch case/fallback edges plus reached-pause continuations --
  ;; excluding eof-targets. An eof-only-reachable pause legally continues into
  ;; a finish node; a byte-reachable one must not.
  (define (byte-reached m) (map car (reach-from m node-out-targets)))

  ;; "A state an execution can be parked on" and "the name the EOF walk starts
  ;; at" are two different questions, and the callback node is the first kind
  ;; where they come apart. For all nine older kinds they coincide, so the parked
  ;; block below classifies the parked node itself and lets `classify` hop: a
  ;; dispatch follows its eof-target, a pause joins over its continuation.
  ;;
  ;; A parser parked at a callback node is parked because that callback RETURNED
  ;; pause, and resumes at that invocation's declared pause continuation -- ONE
  ;; edge, not three. Classifying the callback itself would join over its
  ;; continue and branch targets as well and report `eof-reachable-stop` for a
  ;; stop terminal only a FEED-time `continue` reaches; that is a legal `stopped`
  ;; feed result and not an EOF path. The flow-through case, where the walk
  ;; ARRIVES at a callback and every outcome is live, is `classify`'s and is
  ;; unaffected.
  ;;
  ;; The entry is the exception to the exception: a fresh or reset parser is
  ;; parked at the entry WITHOUT having executed it, so `parser-finish!` runs an
  ;; entry callback and all three outcomes are live -- flow-through again.
  ;;
  ;; A SPAN END IS A PARKED STATE. A span-data callback has no callback node: it
  ;; is reached through a SPAN declaration and the span-end node itself, so its
  ;; pause parks on that node's internal completion substep, whose source name is
  ;; the span-end node's own. It is reachable -- a machine whose span end
  ;; continues to a stop would verify clean and then answer `stopped` from
  ;; `parser-finish!` after a span-data pause, exactly what the
  ;; EOF-reachable-stop check exists to forbid.
  ;;
  ;; AND IT NEEDS NO ARM HERE: a span end's resume point is its SUCCESSOR, but
  ;; starting the walk at the node gives the same answer, because a span end is
  ;; pure flow-through -- it is no terminal, so `classify` above joins over its
  ;; `next` and nothing else. An explicit arm answering `(span-end-node-next n)`
  ;; would be inert. The whole of the change is the MEMBERSHIP below.
  ;;
  ;; A span START stays out of that membership: it calls nothing, so nothing can
  ;; pause there, and it is flow-through like a field action.
  (define (parked-eof-start m n)
    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (callback-node-pause-continuation n))
          ;; Counted consume: a parser parked here by `need-input` holds a
          ;; POSITIVE count -- the only returns that leave `current` on the node
          ;; leave the field positive -- so at finish it takes its EOF route,
          ;; never `next`, and the walk starts there. That route is a symbol
          ;; whenever this arm is reached: `pass-eof-execution` asks only for
          ;; nodes in the parked set, and a non-entry counted consume is in that
          ;; set only through its `(symbol? (node-eof-target n))` clause. The
          ;; ENTRY falls through: a fresh parser is parked there without having
          ;; executed it, its count is the field's initial and may be zero, so it
          ;; starts at itself and takes `classify`'s join.
          ((and (counted-consume-node? n) (not (eq? (node-name n) (machine-entry m))))
           (counted-consume-node-eof-target n))
          (else (node-name n))))

  ;; The byte-into-finish and EOF-shape checks, and the separate EOF
  ;; zero-progress-cycle check.
  (define (pass-eof-execution m)
    (let ((nodes (machine-nodes m)))
      (append
       ;; The byte-into-finish half — ONE derived block, replacing three
       ;; hand-written ones.
       ;;
       ;; The rule forbids "non-EOF control flow into a finish terminal", stated
       ;; over REACHING. So the question is not what KIND the source node is; it
       ;; is whether the source is byte-reachable. The three earlier blocks
       ;; answered it three ways -- one unconditional and kind-filtered, two
       ;; gated on byte-reachability -- and therefore disagreed: a node reachable
       ;; ONLY as an eof-target was accepted when it was a pause, a field-action
       ;; or a field-branch, and rejected when it was a byte-dispatch, a
       ;; sequence-dispatch or an accumulate. The byte edge is untakeable in all
       ;; six.
       ;;
       ;; The gated reading is correct, in both directions. Applying the
       ;; unconditional reading uniformly breaks legal programs, the canonical
       ;; one being `make-pause-machine`: an EOF-only pause continuing into a
       ;; finish node, a legal shape. All three input-reading kinds can be
       ;; EOF-only-reachable.
       ;;
       ;; The gate is SOUND, not merely convenient: once an execution takes an
       ;; eof-target it can never feed again (`parser-feed!` prohibits the
       ;; `finish-ready` row), so feed-reachable is a subset of `byte-reached`
       ;; and gating on it cannot miss a real violation.
       ;;
       ;; Reported once per offending edge AT ITS SOURCE NODE. The alternative --
       ;; reporting at the finish node -- measures identical accept/reject sets
       ;; but merges findings from two different sources into one, and the source
       ;; is the half that says which edge to fix.
       ;;
       ;; `node-out-targets` is now the single census this rule consults, and it
       ;; already owns that job -- the direct antidote to the failure mode of a
       ;; kind taught to the accessors and not to the hand-written filters
       ;; reading them.
       ;; The ZERO-HOP case: the entry itself being a finish terminal. The rule
       ;; is stated over REACHING, and the entry is reached by `parser-feed!`.
       ;; Without this clause such a machine verifies clean and `parser-feed!`
       ;; returns `finished` for an EMPTY slice, which the closed list of feed
       ;; results ("a callback, stop, or error") does not permit. Reuses the code
       ;; rather than spending a new one.
       ;;
       ;; Multiplicity 1 by construction: one entry, and a finish node has no
       ;; out-targets, so the per-edge loop below cannot also fire on it.
       (let ((en (lookup nodes (machine-entry m))))
         (if (and en (finish-node? en))
             ;; The zero-hop path is the entry alone.
             (list (make-diagnostic/path 'non-eof-into-finish (machine-entry m)
                                         "the entry is a finish terminal"
                                         (list (machine-entry m))))
             '()))
       ;; `reach-from` is called ONCE and both halves are derived from its parent
       ;; alist: `br908` is its key set (`byte-reached`), and the offending edge's
       ;; path is entry → source → target over the same alist. `rp` binds as a
       ;; `let*` sibling of `br908`, adding no nesting level, so the body's
       ;; indentation -- and the two byte-into-finish gate pins -- do not move.
       (let* ((rp (reach-from m node-out-targets)) (br908 (map car rp)))
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
                                                 (car re)
                                                 (append (parent-path rp (node-name n))
                                                         (list (cdr re))))
                                                #f)))
                                        (node-out-edges n)))
                           '()))
                     nodes)))
       ;; The EOF-shape and EOF-cycle check — walk each parked node's eof-target
       ;; chain. `parser-finish-op!` carries no local cycle guard because it
       ;; relies on these two checks, so an accumulate node whose eof-target is
       ;; itself would verify clean and then loop FOREVER in both executors, and
       ;; one whose EOF chain reaches a stop terminal would be accepted although
       ;; `eof-reachable-stop` exists to reject exactly that.
       ;;
       ;; The start set is the PARKED set, derived. An earlier shape enumerated
       ;; source KINDS and classified each one's eof-TARGET, and `machine-entry`
       ;; was in no kind's list -- so the EOF path that begins at the entry was
       ;; never classified, though `parser-finish!` on a fresh or reset parser
       ;; starts precisely there (`entry = a stop node` verified with ZERO
       ;; diagnostics and returned `stopped`, while the identical property one hop
       ;; away was correctly rejected).
       ;;
       ;; The set below is the states an execution can be parked on: the entry,
       ;; every byte-reachable pause (whose continuation `current` is left on),
       ;; and every byte-reachable node carrying its own EOF route. Because it is
       ;; a SET, the entry appears exactly once -- so a machine whose entry is
       ;; also a dispatch with an eof-target reports ONE finding, not two. The
       ;; naive fix, a second walk start bolted onto the entry, double-reports
       ;; there, and the only filter that suppresses it is a per-kind census of
       ;; the entry.
       ;;
       ;; Each node is classified as ITSELF rather than by its eof-target, which
       ;; unifies the two old blocks -- `classify` on a dispatch already follows
       ;; its eof-target and on a pause already joins over its continuation -- so
       ;; the reported node stays where it was and no shipped `diagnostic-node`
       ;; assertion moves.
       ;;
       ;; This NARROWS the literal "reachable from any state": a graph node no
       ;; execution can occupy is not a state that originates a traversal.
       (let ((br909 (byte-reached m)))
         (apply append
                (map (lambda (n)
                       ;; `eof-terminal` answers a `(verdict path)` pair; the
                       ;; verdict `case`s and the path rides into the diagnostic.
                       (if (parked? m n br909)
                           (let* ((r (eof-terminal m (parked-eof-start m n)))
                                  (path (cadr r)))
                             (case (car r)
                               ((eof-reachable-stop)
                                (list (make-diagnostic/path 'eof-reachable-stop (node-name n)
                                                            "an EOF path reaches a stop terminal"
                                                            path)))
                               ((cycle)
                                (list (make-diagnostic/path 'eof-zero-progress-cycle (node-name n)
                                                            "an EOF path cycles without reaching a terminal"
                                                            path)))
                               (else '())))
                           '()))
                     nodes)))
       ;; The pause cases need no block of their own: the byte-into-finish half
       ;; is handled by the derived byte-reachability block above, and the
       ;; EOF-shape half by the parked set, which includes every byte-reachable
       ;; pause and classifies it through the same `eof-terminal` call.
       )))

  ;; The labels a node carries BESIDE its own: its byte cases' or sequence cases'.
  ;; A case has no name, so its label is checked under the owning node, inside
  ;; that node's one finding. A per-kind `cond` -- a census a new kind must
  ;; answer, with "no cases" being an answer -- built with `map` and no
  ;; `(cons 'x ...)` form, because the kind x position census collects every
  ;; quoted-symbol `cons` in this file as an edge role.
  (define (node-case-labels n)
    (cond ((byte-dispatch-node? n)
           (map byte-case-source-label (byte-dispatch-node-cases n)))
          ((sequence-dispatch-node? n)
           (map sequence-case-source-label (sequence-dispatch-node-cases n)))
          ((keyword-table-node? n)
           (map keyword-entry-source-label (keyword-table-node-entries n)))
          (else '())))

  ;; PASS 7: generated-name safety (member 1) — machine, node, error names/codes.
  ;; The label clause is folded into each arm's `and`: the machine's label,
  ;; every node's own label and its case labels through `node-source-label` and
  ;; `node-case-labels`, and every error declaration's label. One finding per
  ;; carrier however many ways it is bad -- the shape the error-declaration arm
  ;; already had -- and no new emission site, so the diagnostic census reads the
  ;; same six `invalid-name` sites as before.
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
                        (make-diagnostic/declarations 'invalid-name (error-declaration-name e)
                                         "error name, code, reason or label is not portable" (list (error-declaration-name e)))))
                  (machine-errors m)))))

  ;; --- PASS 6b: callback and span DECLARATIONS --------------------------------
  ;;
  ;; A PASS OF ITS OWN, and the reason is mechanical rather than aesthetic.
  ;; `pass-fields`' tail line -- seven leading spaces, four trailing parens --
  ;; is the verbatim FIND of the mutation that pins `pass-field-operands` being
  ;; run at all, at exactly one site. Appending a declaration arm inside that
  ;; `append` moves the line and takes the pin to zero occurrences, which fails
  ;; at CMake CONFIGURE time and does not look like a test failure.
  ;;
  ;; NO `(cons 'SYMBOL ...)` FORM APPEARS BELOW, and that is a constraint, not a
  ;; coincidence. `edge-roles-in-source` in the kind x position census collects
  ;; the quoted symbol from EVERY such form in this file -- not only edge-role
  ;; ones, despite what its own comment says -- and compares the result against a
  ;; declared mapping. A `(cons 'callback name)` here would add a spurious
  ;; "role", fail `derived roles equal the mapped roles`, and take that pass's
  ;; BASELINE red. Count with `read`, or exclude comment lines -- the two
  ;; mentions in this very comment are why a bare textual count answers more, the
  ;; same class of mistake as the substring sweep that once undercounted a pin.
  ;;
  ;; Every loop variable is named apart from `pass-names`' and `pass-fields`'.
  ;; Three of those loops' inner lines are each a one-site FIND, so a copied
  ;; duplicate-scan would twin a pin and fail configure in the other direction.
  ;; The symbols `continue` and `pause` are reserved and may not be callback
  ;; decision branch keys; this list is a transcription of that rule.
  (define reserved-outcomes '(continue pause))

  (define (pass-declarations m)
    (let ((cbs (machine-callbacks m)) (sps (machine-spans m)))
      (append
       ;; Duplicate callback names. `cseen`/`cout` rather than `seen`/`out`.
       (let cloop ((cs cbs) (cseen '()) (cout '()))
         (if (null? cs) (reverse cout)
             (let ((cn (callback-declaration-name (car cs))))
               (cloop (cdr cs) (cons cn cseen)
                      (if (memq cn cseen)
                          (cons (make-diagnostic/declarations 'duplicate-callback-declaration cn
                                                 "duplicate callback declaration name" (list cn))
                                cout)
                          cout)))))
       ;; Duplicate span names. `pseen`/`pout`.
       (let ploop ((ps sps) (pseen '()) (pout '()))
         (if (null? ps) (reverse pout)
             (let ((pn (span-declaration-name (car ps))))
               (ploop (cdr ps) (cons pn pseen)
                      (if (memq pn pseen)
                          (cons (make-diagnostic/declarations 'duplicate-span-declaration pn
                                                 "duplicate span declaration name" (list pn))
                                pout)
                          pout)))))
       ;; The name clause, both families. Callback and span names would otherwise
       ;; sit outside every grammar check: `pass-names` and `pass-names-valid`
       ;; read node names and error declarations only.
       ;;
       ;; THE LABEL CLAUSE IS FOLDED INTO THE NAME CLAUSE'S `and`, not added as
       ;; its own arm. That matches `pass-names-valid`'s error-declaration arm,
       ;; which tests name, code AND reason in one `and` so a declaration bad in
       ;; three ways reports ONCE. Folding also leaves the diagnostic census
       ;; unmoved: `(invalid-name 6)` stays 6.
       ;;
       ;; The counter-argument, declined: reusing `missing-callback-declaration`
       ;; for spans was refused elsewhere because a reader tracing a report back
       ;; would look in the callback table for a name that was never there. Here
       ;; the subject does not move: the diagnostic names the DECLARATION, which
       ;; is in the right table either way, and that alone is the disanalogy.
       ;;
       ;; It does NOT name which field failed. The message is a static
       ;; disjunction, so a label-only failure reports a node slot holding a
       ;; perfectly PORTABLE name with the offending label nowhere in the record
       ;; -- the same imprecision "error name, code or reason is not portable"
       ;; already carries.
       ;;
       ;; These two arms check the two DECLARATION families' labels; every other
       ;; carrier's label is checked where its NAME already is -- `pass-names-valid`
       ;; (machine, node with its cases, error declaration) and `pass-fields`
       ;; (field), each as a conjunct of the existing `and`.
       (filter values
               (map (lambda (cd)
                      (if (and (valid-name? (callback-declaration-name cd))
                               (valid-label? (callback-declaration-source-label cd)))
                          #f
                          (make-diagnostic/declarations 'invalid-name (callback-declaration-name cd)
                                           "callback declaration name or label is not portable" (list (callback-declaration-name cd)))))
                    cbs))
       (filter values
               (map (lambda (sd)
                      (if (and (valid-name? (span-declaration-name sd))
                               (valid-label? (span-declaration-source-label sd)))
                          #f
                          (make-diagnostic/declarations 'invalid-name (span-declaration-name sd)
                                           "span declaration name or label is not portable" (list (span-declaration-name sd)))))
                    sps))
       ;; The branch-key clause and the declaration share: a key that is not
       ;; portable, or declared twice on one callback.
       (apply append
              (map (lambda (cd)
                     (let kloop ((ks (callback-declaration-branch-keys cd))
                                 (kseen '()) (kout '()))
                       (if (null? ks) (reverse kout)
                           (let ((k (car ks)))
                             (kloop (cdr ks) (cons k kseen)
                                    (cond
                                     ((memq k kseen)
                                      (cons (make-diagnostic/declarations 'duplicate-branch-key
                                                             (callback-declaration-name cd)
                                                             "branch key declared twice" (list (callback-declaration-name cd)))
                                            kout))
                                     ((not (valid-name? k))
                                      (cons (make-diagnostic/declarations 'invalid-name
                                                             (callback-declaration-name cd)
                                                             "branch key is not portable" (list (callback-declaration-name cd)))
                                            kout))
                                     (else kout)))))))
                   cbs))
       ;; Reserved branch keys, transcribed above.
       (apply append
              (map (lambda (cd)
                     (filter values
                             (map (lambda (k)
                                    (if (memq k reserved-outcomes)
                                        (make-diagnostic/declarations 'reserved-branch-key
                                                         (callback-declaration-name cd)
                                                         "branch key collides with a reserved outcome" (list (callback-declaration-name cd)))
                                        #f))
                                  (callback-declaration-branch-keys cd))))
                   cbs))
       ;; An optional decision callback must declare `default-branch`. A REQUIRED
       ;; decision callback needs none -- it is always bound, so no default is
       ;; reached.
       (filter values
               (map (lambda (cd)
                      (let ((k (callback-declaration-kind cd))
                            (req (callback-declaration-required? cd))
                            (db (callback-declaration-default-branch cd)))
                        (if (and (eq? k 'decision) (not req)
                                 (not (and (symbol? db)
                                           (memq db (callback-declaration-branch-keys cd)))))
                            (make-diagnostic/declarations 'invalid-callback-declaration
                                             (callback-declaration-name cd)
                                             "optional decision callback has no valid default branch" (list (callback-declaration-name cd)))
                            #f)))
                    cbs))
       ;; A non-decision callback declaring branch keys or a default branch:
       ;; branch keys belong to DECISION callbacks only, so any key on another
       ;; kind is undeclared by construction.
       (filter values
               (map (lambda (cd)
                      (if (and (not (eq? (callback-declaration-kind cd) 'decision))
                               (or (pair? (callback-declaration-branch-keys cd))
                                   (symbol? (callback-declaration-default-branch cd))))
                          (make-diagnostic/declarations 'invalid-callback-declaration
                                           (callback-declaration-name cd)
                                           "only a decision callback may declare branch keys" (list (callback-declaration-name cd)))
                          #f))
                    cbs))
       ;; A span names its two callbacks BY NAME, so resolution and kind are
       ;; cross-references and therefore the verifier's -- `make-span-declaration`
       ;; cannot see this table. The two callback kinds are fixed (span-data,
       ;; span-complete); a span naming an event callback is an invalid span
       ;; callback declaration.
       (apply append
              (map (lambda (sd)
                     (let* ((dn (span-declaration-data-callback sd))
                            (cn (span-declaration-complete-callback sd))
                            (dd (find-callback cbs dn))
                            (cc (if (symbol? cn) (find-callback cbs cn) #f)))
                       (append
                        (if dd '()
                            (list (make-diagnostic/declarations 'missing-callback-declaration
                                                   (span-declaration-name sd)
                                                   "span data callback names no declaration" (list (span-declaration-name sd) dn))))
                        (if (or (not dd) (eq? (callback-declaration-kind dd) 'span-data))
                            '()
                            (list (make-diagnostic/declarations 'invalid-span-callback
                                                   (span-declaration-name sd)
                                                   "span data callback is not of kind span-data" (list (span-declaration-name sd) dn))))
                        (if (or (not (symbol? cn)) cc) '()
                            (list (make-diagnostic/declarations 'missing-callback-declaration
                                                   (span-declaration-name sd)
                                                   "span completion callback names no declaration" (list (span-declaration-name sd) cn))))
                        (if (or (not cc) (eq? (callback-declaration-kind cc) 'span-complete))
                            '()
                            (list (make-diagnostic/declarations 'invalid-span-callback
                                                   (span-declaration-name sd)
                                                   "span completion callback is not of kind span-complete" (list (span-declaration-name sd) cn)))))))
                   sps))
       ;; A callback of a span kind that no span names is unreachable: nothing
       ;; can ever invoke it, because only a span declaration reaches one.
       (filter values
               (map (lambda (cd)
                      (if (and (memq (callback-declaration-kind cd) '(span-data span-complete))
                               (not (span-referencing sps (callback-declaration-name cd))))
                          (make-diagnostic/declarations 'unreferenced-callback-declaration
                                           (callback-declaration-name cd)
                                           "span callback is named by no span" (list (callback-declaration-name cd)))
                          #f))
                    cbs))
       ;; The NODE half of callback-declaration cross-referencing.
       ;;
       ;; ONE code for the four faults, on the precedent
       ;; `invalid-callback-declaration` set by covering two. The MESSAGE
       ;; separates them; diagnostics are compared by code, and a code per fault
       ;; would spend four on one rule. The two faults that already have codes
       ;; reuse them: a node naming no declaration is `missing-callback-declaration`,
       ;; the code a SPAN naming no declaration already reports, and a key listed
       ;; twice is `duplicate-branch-key`.
       ;;
       ;; All of this is here because every one of these judgements needs the
       ;; machine's callback table beside the node, and `make-callback-node`
       ;; cannot see it.
       (apply append
              (map (lambda (n)
                     (cond ((callback-node? n) (callback-node-diagnostics cbs n))
                           ;; THE OTHER HALF OF THE SAME BOUNDARY.
                           ;; `make-span-start-node` stores its span as a bare
                           ;; symbol: whether it names a DECLARED span needs the
                           ;; machine's span table, so pass 7 cannot do it (it
                           ;; treats the symbol opaquely, because the span-state
                           ;; lattice is well defined over any symbol).
                           ;;
                           ;; It is reachable, not theoretical: a machine whose
                           ;; span nodes named an undeclared span would verify
                           ;; CLEAN and then raise `assertion-violation` out of
                           ;; `normalize-machine`'s `span-slot-of` -- a verified
                           ;; machine crashing the normalizer, which is forbidden.
                           ((or (span-start-node? n) (span-end-node? n))
                            (span-node-declaration-diagnostics sps n))
                           (else '())))
                   (machine-nodes m))))))

  ;; The span half of the "undeclared" node check, written beside
  ;; `callback-node-diagnostics` and answering the same shape of question. There
  ;; is only ONE fault here where a callback node has four: a span node carries
  ;; no branch keys, no kind and no arity, so naming a declaration it can find is
  ;; the whole of its cross-reference.
  (define (span-node-declaration-diagnostics sps n)
    (let ((s (if (span-start-node? n) (span-start-node-span n) (span-end-node-span n))))
      (if (find-span sps s) '()
          (list (make-diagnostic/declarations 'missing-span-declaration (node-name n)
                                 "span node names an undeclared span" (list s))))))
  (define (find-span sps nm)
    (cond ((null? sps) #f)
          ((eq? (span-declaration-name (car sps)) nm) (car sps))
          (else (find-span (cdr sps) nm))))

  ;; The four faults, in order, plus the invocation's own precondition. Split out
  ;; of `pass-declarations` rather than inlined because it is the only block
  ;; there that walks NODES, and because its five arms would otherwise make one
  ;; `map` body longer than the whole pass.
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
         (list (make-diagnostic/declarations 'missing-callback-declaration nm
                                "callback node names no declaration" (list cn))))
        ;; A callback node invokes one named event or decision callback. A span
        ;; callback is reached only through a span declaration, never through a
        ;; node, so naming one here is an invocation that can never be what it
        ;; says.
        ((not (memq (callback-declaration-kind cd) '(event decision)))
         (list (make-diagnostic/declarations 'invalid-callback-invocation nm
                                "callback node invokes a span callback" (list cn))))
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
          ;; an event node lands here -- event and span callbacks accept only
          ;; continue, pause, or failure, enforced statically rather than left to
          ;; the runtime's out-of-contract path.
          (filter values
                  (map (lambda (k)
                         (if (memq k (callback-declaration-branch-keys cd)) #f
                             (make-diagnostic/declarations 'invalid-callback-invocation nm
                                              "branch key is not declared by the callback" (list cn))))
                       keys))
          ;; MISSING. A decision selects only among statically declared branch
          ;; keys, so a declared key with no target on this node is a result the
          ;; machine cannot route -- and for an OPTIONAL decision callback it is
          ;; worse than that: the default branch is taken with no callback to
          ;; ask, so `normalize-machine` has nothing to lower and raises. This
          ;; check is what makes that raise unreachable.
          (filter values
                  (map (lambda (k)
                         (if (memq k keys) #f
                             (make-diagnostic/declarations 'invalid-callback-invocation nm
                                              "callback declares a branch key this node gives no target" (list cn))))
                       (callback-declaration-branch-keys cd))))))))

  ;; --- PASS 7: span-state dataflow -------------------------------------------
  ;;
  ;; A FIXPOINT, NOT AN ENUMERATION. Normal consuming cycles, including the main
  ;; HTTP message loop, are valid, so the set of reachable paths is infinite on
  ;; the motivating example. A walk over a finite domain terminates; an
  ;; enumeration of paths does not.
  ;;
  ;; The abstract domain is a FLAT lattice, of height two:
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

  ;; TWO DIFFERENT QUESTIONS. The NODE DOMAIN -- byte-reachability plus the EOF
  ;; walk -- is fixed, but which EDGES the transfer function follows is a
  ;; separate question. The gap is load-bearing: "successful EOF with an active
  ;; span" needs a dataflow that reaches a finish node that is only EOF-reachable,
  ;; which a dataflow over `node-out-targets` alone never reaches, because that
  ;; accessor excludes eof-targets by construction.
  ;;
  ;; So the edge relation here is the one whose transitive closure IS the
  ;; occupiable relation: byte edges while input can still arrive, then eof
  ;; routes and zero-width continuations, and never a byte edge after an
  ;; eof-target. It is deliberately not the retired walk that crossed an
  ;; eof-target and then kept taking byte edges. `pass-reachability` reads this
  ;; relation too, through `eof-visited` and `occupiable`.
  ;;
  ;; A node's EOF successors: its own eof route when it has one (the four
  ;; input-reading kinds), and its zero-width continuations otherwise. Both
  ;; halves in one expression. They were disjoint by construction -- `node-eof-target`
  ;; answers #f for every zero-width kind and `eof-successors` answered '() for
  ;; every input-reading one -- and counted consume is where they meet: its
  ;; `next` is an EOF successor too, so a counted consume with a symbolic route
  ;; contributes BOTH, which is exactly the join `classify` computes for it. The
  ;; `append` stays right.
  (define (eof-step n)
    (let ((t (node-eof-target n)))
      (append (if (symbol? t) (list t) '()) (eof-successors n))))

  ;; THE parked set: the "states an execution can be PARKED on", in ONE procedure
  ;; with three consumers -- `pass-eof-execution` (which nodes start a walk),
  ;; `span-flow` (which nodes seed pass 7's EOF edges) and `occupiable` (which
  ;; nodes an execution can occupy). Byte-reachable, and one of: the entry (a
  ;; fresh parser sits here without having executed it); a pause; a callback (its
  ;; pause outcome parks the parser -- `parked-eof-start` says where its walk
  ;; starts); a span end (its data callback's pause parks the parser on the
  ;; completion substep); or a node carrying its own EOF route -- the derived
  ;; `symbol?` test over `node-eof-target`, which every input-reading kind
  ;; satisfies.
  ;; The next kind that can pause joins the SET here and nowhere else -- but if
  ;; its walk starts somewhere other than its own name, `parked-eof-start` above
  ;; needs an arm too, as the callback and the counted consume each did.
  (define (parked? m n br)
    (and (memq (node-name n) br)
         (or (eq? (node-name n) (machine-entry m))
             (pause-node? n)
             (callback-node? n)
             (span-end-node? n)
             (symbol? (node-eof-target n)))))

  ;; The EOF half of the occupiable relation as a VISITED SET: a DFS over eof
  ;; routes from the parked set, never taking a byte edge -- once an execution
  ;; takes an eof-target it can never feed again (the finish-ready row).
  ;; Factored out of `span-flow` so that pass 7 and `pass-reachability` read one
  ;; walk: one census, two views.
  (define (eof-visited m nodes br)
    (let walk ((frontier (apply append
                                (map (lambda (n) (if (parked? m n br) (eof-step n) '()))
                                     nodes)))
               (seen '()))
      (cond ((null? frontier) seen)
            ((memq (car frontier) seen) (walk (cdr frontier) seen))
            (else
             (let ((n (lookup nodes (car frontier))))
               (walk (append (if n (eof-step n) '()) (cdr frontier))
                     (cons (car frontier) seen)))))))

  ;; The nodes an execution can OCCUPY -- byte-reached, plus every node the EOF
  ;; walk from the parked set visits. `pass-reachability` reads it, and
  ;; "unreachable" means "unoccupiable".
  (define (occupiable m)
    (let* ((nodes (machine-nodes m)) (br (byte-reached m)))
      (append br (eof-visited m nodes br))))

  ;; The occupiable relation, as its EDGE LIST. The occupiable set is this list's
  ;; closure from the entry, so the pass needs no separate node filter: a node no
  ;; execution can occupy is one nothing here points at, and it receives no state
  ;; for that reason rather than by being screened out.
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
           (eof-nodes (eof-visited m nodes br))
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
  ;; edge-role vocabulary as a spurious "role" and take the kind x position
  ;; matrix's A' row red on its BASELINE.
  (define (span-transfer n state)
    (cond ((span-start-node? n) (list 'active (span-start-node-span n)))
          ((span-end-node? n) 'none)
          (else state)))

  ;; The span-state Consequences table. `top` never reaches here: the caller
  ;; reports it at the merge and stops propagating, which is what keeps this
  ;; total. `path` is the entry→node path the caller computed once from the
  ;; span-flow parent map; every finding here rides it.
  (define (span-node-diagnostics n state path)
    (cond
      ((span-start-node? n)
       (let ((s (span-start-node-span n)))
         (cond ((eq? state 'none) '())
               ((and (pair? state) (eq? (cadr state) s))
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span re-entry: this span is already open"
                                            path)))
               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span overlap: another span is already open"
                                            path)))
               (else '()))))
      ((span-end-node? n)
       (let ((s (span-end-node-span n)))
         (cond ((and (pair? state) (eq? (cadr state) s)) '())
               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "wrong end: a different span is open"
                                            path)))
               ((eq? state 'none)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "unmatched end: no span is open"
                                            path)))
               (else '()))))
      ;; The exception -- "only the active span's own data callback may pause
      ;; before the span closes" -- cannot apply to a NODE: a callback node
      ;; admits only `event` and `decision` callbacks, and a span-data callback
      ;; is reached through a span declaration and the runtime's flush, never
      ;; through a callback node. So every pause node and every callback node is
      ;; rejected with a span open.
      ((and (pair? state) (or (pause-node? n) (callback-node? n)))
       (list (make-diagnostic/path 'span-active-at-pause (node-name n)
                                   "a pause or callback invocation is reachable with a span active"
                                   path)))
      ;; Only the SUCCESSFUL terminals: a span may still be open at an error
      ;; terminal, which is why `finish` is kept distinguished from `error`.
      ((and (pair? state) (or (stop-node? n) (finish-node? n)))
       (list (make-diagnostic/path 'span-active-at-exit (node-name n)
                                   "a successful terminal is reachable with a span active"
                                   path)))
      (else '())))

  ;; A parent map over an edge list, BFS from the entry, `#f` at the entry.
  ;; `pass-spans` seeds its in-state at the entry and propagates only along
  ;; `edges`, so a node that carries any state is reachable from the entry over
  ;; exactly this relation -- it is therefore a key, and a node with no path here
  ;; can produce no span finding. `span-flow` is not touched: this reads the edge
  ;; list it already returns.
  (define (edge-parents entry edges)
    (let loop ((frontier (list entry)) (parents (list (cons entry #f))))
      (if (null? frontier) parents
          (let across ((succ (map cdr (filter (lambda (e) (eq? (car e) (car frontier)))
                                               edges)))
                       (rest (cdr frontier)) (parents parents))
            (cond ((null? succ) (loop rest parents))
                  ((assq (car succ) parents) (across (cdr succ) rest parents))
                  (else (across (cdr succ) (append rest (list (car succ)))
                                (cons (cons (car succ) (car frontier)) parents))))))))

  (define (pass-spans m)
    (let* ((nodes (machine-nodes m))
           (edges (span-flow m))
           ;; The entry→node path for every span finding, over `edges`.
           (parents (edge-parents (machine-entry m) edges))
           ;; The in-state map, as an association list rebuilt each round. A
           ;; node no execution can occupy contributes no state to a join and
           ;; receives none, so it never appears here at all.
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
                             ;; construction and a filter would never fire. It is
                             ;; satisfied by the relation, not by a guard -- and a
                             ;; guard that cannot guard is what this project
                             ;; deletes rather than documents. `(not fn)` stood
                             ;; here as a third disjunct and was DELETED: every
                             ;; edge's `from` is some node's own name, so `lookup`
                             ;; cannot miss.
                             (if (or (not fs) (eq? fs 'top))
                                 ;; `top` does not flow onward.
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
                                    ;; A join yielding `top` is itself a
                                    ;; diagnostic, reported where it arises.
                                    ;; Reporting downstream would blame an
                                    ;; innocent node and falling silent would be
                                    ;; unsound.
                                    ((eq? st 'top)
                                     (list (make-diagnostic/path 'inconsistent-span-state
                                                                 (node-name n)
                                                                 "incoming edges disagree about the active span"
                                                                 (parent-path parents (node-name n)))))
                                    (else (span-node-diagnostics
                                           n st (parent-path parents (node-name n)))))))
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

  ;; `nm` binds as a SIBLING of `ds`, not a `let*` step above it: reading only
  ;; `machine`, it re-indents no line of the `append`, so the four
  ;; `verify: pass-X is never run` pins that anchor on `(pass-fields machine)`
  ;; and its siblings keep their single-line FINDs. `(null? ds)` is computed on
  ;; the UNSTAMPED list -- stamping fills severity/machine and cannot change
  ;; emptiness -- and the one `map` stamps every diagnostic with the machine
  ;; name.
  ;; verify-machine : Machine -> VerificationResult
  (define (verify-machine machine)
    (let ((ds (append (pass-schema machine)
                      (if (machine? machine)
                          (append (pass-names machine)
                                  (pass-fields machine)
                                  (pass-declarations machine)
                                  (pass-spans machine)
                                  (pass-overlap machine)
                                  (pass-sequence-ambiguity machine)
                                  (pass-keyword-table machine)
                                  (pass-reachability machine)
                                  (pass-zero-progress machine)
                                  (pass-eof machine)
                                  (pass-eof-execution machine)
                                  (pass-names-valid machine))
                          '())))
          (nm (and (machine? machine) (machine-name machine))))
      (make-verification-result (null? ds)
                                (map (lambda (d) (stamp-diagnostic d nm)) ds)
                                machine)))

  ;; verification-ok? : VerificationResult -> Boolean
  (define (verification-ok? v) (verification-result-ok? v))
  ;; verification-diagnostics : VerificationResult -> (Listof Diagnostic)
  (define (verification-diagnostics v) (verification-result-diagnostics v))
  ;; verification-machine : VerificationResult -> Machine
  (define (verification-machine v) (verification-result-machine v)))
