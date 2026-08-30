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

  ;; --- helpers ---
  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (error-names m) (map error-declaration-name (machine-errors m)))
  (define (node-out-targets n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (edge-target (byte-case-edge c)))
                        (byte-dispatch-node-cases n))
                   (list (edge-target (byte-dispatch-node-fallback n)))))
          ;; A pause's single zero-width out-edge (§10.6): resolution-checked by
          ;; PASS 2 (a malformed continuation is 'missing-target, §16.2:905) and
          ;; walked by reachability. The §16.2:908 dispatch check below filters
          ;; on byte-dispatch-node?, so this arm does not feed it.
          ((pause-node? n) (list (pause-node-continuation n)))
          ;; A sequence node's byte out-edges: every alternative's target plus
          ;; the mismatch edge's. Feeding this arm also repairs pass-names'
          ;; target resolution and byte-reached, which both walk this function.
          ((sequence-dispatch-node? n)
           (append (map sequence-case-target (sequence-dispatch-node-cases n))
                   (list (edge-target (sequence-dispatch-node-mismatch n)))))
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
  (define (pass-schema m)
    (if (machine? m) '() (list (make-diagnostic 'invalid-shape #f "not a machine"))))

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
  ;; stale thirteen comment references for nothing. pass-eof-execution below is
  ;; the shipped precedent for an unnumbered pass.
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
                     (if (and (or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))
                              (reaches-self? (node-name n)))
                         (make-diagnostic 'zero-progress-cycle (node-name n)
                                          "a zero-width cycle (reexecute edges/pause continuations) makes no progress")
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

  ;; Walk the eof-target chain from `start`, classifying its terminal.
  (define (eof-terminal m start)
    (let ((nodes (machine-nodes m)))
      (let loop ((name start) (seen '()))
        (if (memq name seen) 'cycle
            (let ((n (lookup nodes name)))
              (cond ((not n) 'unresolved)             ; pass-eof reports missing target
                    ((finish-node? n) 'finish)
                    ((error-node? n) 'error)
                    ((stop-node? n) 'eof-reachable-stop)
                    ((pause-node? n) (loop (pause-node-continuation n) (cons name seen)))
                    ;; Fix wave 1 (Important 3): kept as two separate arms rather
                    ;; than routed through node-eof-target above. Every other arm
                    ;; in this cond is one node predicate per arm, so this is the
                    ;; only place a reader scanning "what does eof-terminal do for
                    ;; a sequence node" finds its own clause; merging it with the
                    ;; byte-dispatch arm via `(or (byte-dispatch-node? n)
                    ;; (sequence-dispatch-node? n))` would be the only merged arm
                    ;; in an otherwise exhaustive per-kind case analysis, and
                    ;; would obscure that this walk's per-kind decision (loop
                    ;; through the eof-target, or answer 'default-error) is made
                    ;; independently for each kind even though the two bodies
                    ;; happen to coincide today.
                    ((byte-dispatch-node? n)
                     (let ((t (byte-dispatch-node-eof-target n)))
                       (if (symbol? t) (loop t (cons name seen)) 'default-error)))
                    ((sequence-dispatch-node? n)
                     (let ((t (sequence-dispatch-node-eof-target n)))
                       (if (symbol? t) (loop t (cons name seen)) 'default-error)))
                    (else 'unknown)))))))

  ;; Byte-flow reachability (feed can arrive): entry DFS over node-out-targets
  ;; -- dispatch case/fallback edges plus reached-pause continuations --
  ;; excluding eof-targets. An eof-only-reachable pause legally continues into
  ;; a finish node (decision 0011); a byte-reachable one must not (§16.2:908).
  (define (byte-reached m) (reach-from m node-out-targets))

  ;; §16.2:908/:909 and the separate EOF zero-progress-cycle check.
  (define (pass-eof-execution m)
    (let ((nodes (machine-nodes m)))
      (append
       ;; :908 — a byte edge (case or fallback) into a finish terminal.
       (apply append
              (map (lambda (n)
                     (if (or (byte-dispatch-node? n) (sequence-dispatch-node? n))
                         (filter values
                                 (map (lambda (t)
                                        (let ((tn (lookup nodes t)))
                                          (if (and tn (finish-node? tn))
                                              (make-diagnostic 'non-eof-into-finish (node-name n)
                                                               "a byte edge targets a finish terminal")
                                              #f)))
                                      (node-out-targets n)))
                         '()))
                   nodes))
       ;; :909 + the EOF-cycle check — walk each dispatch node's eof-target chain.
       (apply append
              (map (lambda (n)
                     (if (or (byte-dispatch-node? n) (sequence-dispatch-node? n))
                         (let ((t (node-eof-target n)))
                           (if (symbol? t)
                               (case (eof-terminal m t)
                                 ((eof-reachable-stop)
                                  (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                         "an EOF path reaches a stop terminal")))
                                 ((cycle)
                                  (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                         "an EOF path cycles without reaching a terminal")))
                                 (else '()))
                               '()))
                         '()))
                   nodes))
       ;; D4(b)/(d): checks keyed on byte-reachability. A feed pause parks
       ;; current on its continuation and resume returns the row to ready, so
       ;; every byte-reachable pause's continuation is both a feed re-entry
       ;; point (:908 -- it must not be a finish terminal) and a possible EOF-
       ;; processing start (:909 -- its chain must reach finish or error,
       ;; never a stop, never a cycle).
       (let ((br (byte-reached m)))
         (append
          (apply append
                 (map (lambda (n)
                        (if (and (pause-node? n) (memq (node-name n) br))
                            (let ((cn (lookup nodes (pause-node-continuation n))))
                              (if (and cn (finish-node? cn))
                                  (list (make-diagnostic 'non-eof-into-finish (node-name n)
                                                         "a pause continuation byte-reaches a finish terminal"))
                                  '()))
                            '()))
                      nodes))
          (apply append
                 (map (lambda (n)
                        (if (and (pause-node? n) (memq (node-name n) br))
                            (case (eof-terminal m (pause-node-continuation n))
                              ((eof-reachable-stop)
                               (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                      "an EOF path reaches a stop terminal")))
                              ((cycle)
                               (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                      "an EOF path cycles without reaching a terminal")))
                              (else '()))
                            '()))
                      nodes)))))))

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
                             (valid-name? (error-declaration-code e)))
                        #f
                        (make-diagnostic 'invalid-name (error-declaration-name e)
                                         "error name or code is not portable")))
                  (machine-errors m)))))

  (define (verify-machine machine)
    (let ((ds (append (pass-schema machine)
                      (if (machine? machine)
                          (append (pass-names machine)
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
