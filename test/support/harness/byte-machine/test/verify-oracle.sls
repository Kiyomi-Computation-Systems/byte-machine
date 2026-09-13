;;; (byte-machine test verify-oracle): the independent oracle (Milestone 7 Slice ④,
;;; design §4.6). A SECOND implementation of the verifier's graph rules, written
;;; from the plan's sentence and the decision record each rule cites, WITH
;;; verify.sls CLOSED. Its job is to disagree with `verify.sls` when one of them is
;;; wrong: the rejections program compares, per rule, the oracle's `(code . node)`
;;; set against the verifier's set for that rule's codes, and a difference is a
;;; finding (§4.6). On the committed seed's drawn, rejected and corrupted machines
;;; the two agree exactly (the program's zero-differences check).
;;;
;;; A FUNCTIONAL CORE (F18): every rule returns a list of `(code . node)` and
;;; asserts NOTHING. Reads a machine through `(byte-machine private ir)`'s
;;; accessors and NEVER through `verify.sls`; the reachability walks, the byte-set
;;; overlap and the EOF walk are re-derived here from the decision records.
;;;
;;; SCOPE (design §4.6 / Task 4 Step 3). Codes OUTSIDE the rule table are not
;;; compared, and each is left out for a stated reason: pass 7's span-state lattice
;;; (decision 0029 is a definition, and a second implementation of a lattice is the
;;; lattice); the EOF verdict tiers (0023 item 5 -- a ranking, not a graph fact);
;;; the declaration cross-references `:890-:892`/`:901-:902` (table lookups the
;;; catalogue covers exactly); and the field-operand rules `:889`/`:903`/`:904`
;;; (arithmetic on declared widths). The catalogue covers those by edit.
;;;
;;; THE RULE TABLE IS HAND-WRITTEN AND EXPORTED (S2/F4): `oracle-rules`, one row per
;;; §4.6 rule, `(name codes comparison fn)`. `matcher-bytes` is NEVER read (§4.6,
;;; pinned Task 9 Step 3): the `:893` row computes byte sets from the four matcher
;;; accessors alone.
(library (byte-machine test verify-oracle)
  (export oracle-rules oracle-rule-name oracle-rule-codes oracle-rule-comparison
          oracle-rule-fn oracle-rule-reach? oracle-eval nodes-unique?)
  (import (rnrs) (byte-machine private ir))

  ;; ---- small set helpers ----------------------------------------------------
  (define (uniq xs) (fold-left (lambda (a x) (if (member x a) a (cons x a))) '() xs))
  (define (dups xs)  ; the values that occur more than once, once each
    (let loop ((xs xs) (seen '()) (out '()))
      (cond ((null? xs) (reverse out))
            ((member (car xs) seen)
             (loop (cdr xs) seen (if (member (car xs) out) out (cons (car xs) out))))
            (else (loop (cdr xs) (cons (car xs) seen) out)))))
  (define (node-set m) (map node-name (machine-nodes m)))
  (define (declared? m name) (and (memq name (node-set m)) #t))
  (define (find-node m name) (find (lambda (n) (eq? (node-name n) name)) (machine-nodes m)))

  ;; ---- out-target classification (re-derived per kind) ----------------------
  ;; `sym` keeps only symbol targets (drops #f, which means "the machine default").
  (define (sym x) (if (symbol? x) (list x) '()))
  ;; All the NON-EOF node targets a node references (what pass-names resolves): byte
  ;; edges, zero-width successors, error targets, branch/continuation targets.
  ;; EOF targets are the EOF pass's business and are gathered separately.
  (define (non-eof-targets n)
    (cond
     ((byte-dispatch-node? n)
      (append (map (lambda (c) (edge-target (byte-case-edge c))) (byte-dispatch-node-cases n))
              (list (edge-target (byte-dispatch-node-fallback n)))))
     ((sequence-dispatch-node? n)
      (append (map sequence-case-target (sequence-dispatch-node-cases n))
              (list (edge-target (sequence-dispatch-node-mismatch n)))))
     ((keyword-table-node? n)
      (append (map keyword-entry-target (keyword-table-node-entries n))
              (list (edge-target (keyword-table-node-no-match n)))))
     ((pause-node? n) (list (pause-node-continuation n)))
     ((field-action-node? n)
      (append (list (field-action-node-next n)) (sym (field-action-node-error n))))
     ((field-branch-node? n)
      (list (field-branch-node-true-target n) (field-branch-node-false-target n)))
     ((integer-accumulate-node? n)
      (append (list (integer-accumulate-node-digit-target n)
                    (edge-target (integer-accumulate-node-nondigit-edge n)))
              (sym (integer-accumulate-node-overflow-error n))))
     ((callback-node? n)
      (append (list (callback-node-continue-target n))
              (map cadr (callback-node-branch-targets n))
              (sym (callback-node-pause-continuation n))))
     ((span-start-node? n) (list (span-start-node-next n)))
     ((span-end-node? n) (list (span-end-node-next n)))
     ((counted-consume-node? n) (list (counted-consume-node-next n)))
     (else '())))            ; stop, error, finish -- terminals
  (define (eof-target-of n)
    (cond ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
          ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
          ((keyword-table-node? n) (keyword-table-node-eof-target n))
          ((integer-accumulate-node? n) (integer-accumulate-node-eof-target n))
          ((counted-consume-node? n) (counted-consume-node-eof-target n))
          (else #f)))
  ;; every node target (non-eof plus eof) -- the occupiable relation's edges.
  (define (all-targets n) (append (non-eof-targets n) (sym (eof-target-of n))))

  ;; input-reading nodes CONSUME a byte to advance; a parser can be PARKED on one
  ;; at EOF (0023). The zero-width kinds and terminals cannot be parked.
  (define (input-reading? n)
    (or (byte-dispatch-node? n) (sequence-dispatch-node? n) (keyword-table-node? n)
        (integer-accumulate-node? n) (counted-consume-node? n)))

  ;; ---- reachability walks ---------------------------------------------------
  ;; every target of every node bearing a name -- robust to duplicate names, which
  ;; a corrupted machine can carry: the occupiable relation follows the flow out of
  ;; each node with that name, not an arbitrary first (§4.6, matching the verifier
  ;; on the duplicate-name catalogue entries).
  (define (targets-of-name m x)
    (let ((n (node-of-name m x))) (if n (all-targets n) '())))
  ;; byte-reached (0027 item 3): feed can arrive. DFS from the entry over NON-eof
  ;; targets only -- once an execution takes an eof-target it can never feed again
  ;; (0023's decision 1), so feed-reachable follows byte edges and zero-width
  ;; successors but not eof routes. :908 and :898 gate on this census (0030 item 7).
  ;; the node named x. Reachability is defined over a graph whose node names are
  ;; UNIQUE (a well-formed IR); on a duplicate-name graph -- which only the
  ;; dup-node-name catalogue entry produces -- reachability is ill-defined, and the
  ;; rejections program excludes such machines from the reachability rules'
  ;; comparison (they are compared on the :885 duplicate rule, which is their point).
  ;; So this first-match lookup is exact on every machine the reachability rules are
  ;; compared on. `nodes-unique?` is exported for that guard.
  (define (node-of-name m x)
    (find (lambda (n) (eq? (node-name n) x)) (machine-nodes m)))
  (define (nodes-unique? m)
    (let ((ns (map node-name (machine-nodes m)))) (= (length ns) (length (uniq ns)))))
  (define (byte-targets-of-name m x)
    (let ((n (node-of-name m x))) (if n (non-eof-targets n) '())))
  (define (byte-reached m)
    (let ((nodes (node-set m)))
      (let walk ((frontier (if (declared? m (machine-entry m)) (list (machine-entry m)) '()))
                 (seen '()))
        (if (null? frontier) seen
            (let ((x (car frontier)))
              (if (member x seen) (walk (cdr frontier) seen)
                  (walk (append (filter (lambda (t) (memq t nodes)) (byte-targets-of-name m x))
                                (cdr frontier))
                        (cons x seen))))))))
  ;; occupiable (0027 item 1): DFS from the entry over ALL targets that name a node.
  (define (reachable m)
    (let ((nodes (node-set m)))
      (let walk ((frontier (if (declared? m (machine-entry m)) (list (machine-entry m)) '()))
                 (seen '()))
        (if (null? frontier) seen
            (let ((x (car frontier)))
              (if (member x seen) (walk (cdr frontier) seen)
                  (walk (append (filter (lambda (t) (memq t nodes)) (targets-of-name m x))
                                (cdr frontier))
                        (cons x seen))))))))

  ;; ---- rule implementations --------------------------------------------------
  ;; :885 duplicate declaration names -- one code per namespace.
  (define (rule-duplicates m)
    (append
     (map (lambda (nm) (cons 'duplicate-name nm)) (dups (node-set m)))
     (map (lambda (nm) (cons 'duplicate-error-declaration nm))
          (dups (map error-declaration-name (machine-errors m))))
     (map (lambda (nm) (cons 'duplicate-callback-declaration nm))
          (dups (map callback-declaration-name (machine-callbacks m))))
     (map (lambda (nm) (cons 'duplicate-span-declaration nm))
          (dups (map span-declaration-name (machine-spans m))))))

  ;; :885 non-duplicate arms -- the two :885 codes that are NOT a bare name clash:
  ;; a duplicate uint-field name (invalid-field-declaration's dup arm) and a
  ;; duplicate branch key in a callback node's targets (duplicate-branch-key).
  ;; Compared by CONTAINMENT (oracle ⊆ verifier): the verifier reports these codes
  ;; for other faults too (a field's width/operand, a declaration's keys), which the
  ;; oracle does not model, so the oracle finds a subset and never a superset.
  (define (rule-885-nondup m)
    (append
     (map (lambda (nm) (cons 'invalid-field-declaration nm))
          (dups (map uint-field-name (machine-fields m))))
     (apply append
       (map (lambda (n)
              (if (callback-node? n)
                  (map (lambda (k) (cons 'duplicate-branch-key (node-name n)))
                       (dups (map car (callback-node-branch-targets n))))
                  '()))
            (machine-nodes m)))))

  ;; :887/:905 missing targets -- a NON-EOF target that names no node (pass-names,
  ;; through node-out-targets, plus the entry). Attributed to the missing target.
  (define (rule-missing-target m)
    (let* ((nodes (node-set m))
           (refs (uniq (append (if (symbol? (machine-entry m)) (list (machine-entry m)) '())
                               (apply append (map non-eof-targets (machine-nodes m)))))))
      (map (lambda (t) (cons 'missing-target t))
           (filter (lambda (t) (and (symbol? t) (not (memq t nodes)))) refs))))

  ;; :893 overlapping byte cases -- two cases in one dispatch whose canonical byte
  ;; sets meet. Byte sets from the FOUR matcher accessors, NEVER matcher-bytes.
  (define (matcher-set mt)
    (cond ((exact-byte-matcher? mt) (list (exact-byte-matcher-byte mt)))
          ((byte-set-matcher? mt) (byte-set-matcher-bytes mt))
          ((byte-range-matcher? mt)
           (let loop ((b (byte-range-matcher-low mt)) (out '()))
             (if (> b (byte-range-matcher-high mt)) (reverse out) (loop (+ b 1) (cons b out)))))
          ((byte-complement-matcher? mt)
           (let ((inner (matcher-set (byte-complement-matcher-matcher mt))))
             (let loop ((b 0) (out '()))
               (if (> b 255) (reverse out) (loop (+ b 1) (if (memv b inner) out (cons b out)))))))
          (else '())))
  (define (any-meet? sets)
    ;; do any two of the byte sets share a member?
    (let loop ((ss sets) (seen '()))
      (cond ((null? ss) #f)
            ((exists (lambda (b) (memv b seen)) (car ss)) #t)
            (else (loop (cdr ss) (append (car ss) seen))))))
  (define (rule-overlap m)
    (filter-map-nodes m
      (lambda (n)
        (and (byte-dispatch-node? n)
             (any-meet? (map (lambda (c) (matcher-set (byte-case-matcher c)))
                             (byte-dispatch-node-cases n)))
             (cons 'overlapping-cases (byte-dispatch-node-name n))))))

  ;; :894 ambiguous sequence prefix -- one alternative a (proper or equal) prefix
  ;; of another, in one sequence-dispatch node.
  (define (prefix? a b)  ; is a a prefix of b (a shorter-or-equal)?
    (cond ((null? a) #t)
          ((null? b) #f)
          ((equal? (car a) (car b)) (prefix? (cdr a) (cdr b)))
          (else #f)))
  (define (rule-prefix m)
    (filter-map-nodes m
      (lambda (n)
        (and (sequence-dispatch-node? n)
             (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
               (and (pairwise-prefix? alts)
                    (cons 'ambiguous-sequence-prefix (sequence-dispatch-node-name n))))))))
  (define (pairwise-prefix? alts)
    (let loop ((xs alts))
      (cond ((null? xs) #f)
            ((exists (lambda (y) (prefix? (car xs) y)) (cdr xs)) #t)
            ((exists (lambda (y) (prefix? y (car xs))) (cdr xs)) #t)
            (else (loop (cdr xs))))))

  ;; :897 unreachable nodes -- declared nodes the occupiable walk does not reach.
  (define (rule-unreachable m)
    (let ((r (reachable m)))
      (map (lambda (nm) (cons 'unreachable-node nm))
           (filter (lambda (nm) (not (member nm r))) (node-set m)))))

  ;; :908 non-EOF control flow into a finish -- a node reached by the byte-edge walk
  ;; from the entry (entry included, 0023 item 2) whose flow enters a finish over a
  ;; NON-eof edge, reported at the SOURCE node (0023 item 4).
  (define (finish-name? m t)
    (let ((n (find-node m t))) (and n (finish-node? n))))
  (define (rule-non-eof-into-finish m)
    (let ((r (byte-reached m)))
      (uniq
       (filter-map-nodes m
         (lambda (n)
           (and (member (node-name n) r)
                (exists (lambda (t) (finish-name? m t)) (non-eof-targets n))
                (cons 'non-eof-into-finish (node-name n))))))))

  ;; :898 zero-progress cycle -- a cycle among byte-reached nodes over NON-consuming
  ;; edges (reexecute, zero-width successors, accumulate overflow, counted next;
  ;; digit edges excluded), decision 0030 item 7. Attributed to each node on a cycle.
  (define (nonconsuming-targets n)
    (cond
     ((byte-dispatch-node? n)
      (append (map (lambda (c) (edge-target (byte-case-edge c)))
                   (filter (lambda (c) (eq? (edge-mode (byte-case-edge c)) 'reexecute))
                           (byte-dispatch-node-cases n)))
              (if (eq? (edge-mode (byte-dispatch-node-fallback n)) 'reexecute)
                  (list (edge-target (byte-dispatch-node-fallback n))) '())))
     ((sequence-dispatch-node? n)
      (if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
          (list (edge-target (sequence-dispatch-node-mismatch n))) '()))
     ((keyword-table-node? n)
      ;; only the no-match edge can be reexecute; a keyword-take consumes the
      ;; keyword's bytes first, so those targets make progress (sequence's rule).
      (if (eq? (edge-mode (keyword-table-node-no-match n)) 'reexecute)
          (list (edge-target (keyword-table-node-no-match n))) '()))
     ((pause-node? n) (list (pause-node-continuation n)))
     ((field-action-node? n) (append (list (field-action-node-next n)) (sym (field-action-node-error n))))
     ((field-branch-node? n) (list (field-branch-node-true-target n) (field-branch-node-false-target n)))
     ((integer-accumulate-node? n)
      ;; the nondigit edge if it reexecutes, and the overflow error; the DIGIT edge
      ;; consumes and is excluded (§10.6:566).
      (append (if (eq? (edge-mode (integer-accumulate-node-nondigit-edge n)) 'reexecute)
                  (list (edge-target (integer-accumulate-node-nondigit-edge n))) '())
              (sym (integer-accumulate-node-overflow-error n))))
     ((callback-node? n)
      (append (list (callback-node-continue-target n)) (map cadr (callback-node-branch-targets n))
              (sym (callback-node-pause-continuation n))))
     ((span-start-node? n) (list (span-start-node-next n)))
     ((span-end-node? n) (list (span-end-node-next n)))
     ((counted-consume-node? n) (list (counted-consume-node-next n)))
     (else '())))
  (define (rule-zero-progress m)
    (let* ((br (byte-reached m))                     ; 0030 item 7: byte-reached only
           (nodes (filter (lambda (nm) (member nm br)) (node-set m)))
           (on-cycle (nodes-on-nonconsuming-cycle m nodes)))
      (map (lambda (nm) (cons 'zero-progress-cycle nm)) on-cycle)))
  ;; a node is on a zero-progress cycle if it can reach itself over non-consuming
  ;; edges (restricted to the byte-reached census).
  (define (nodes-on-nonconsuming-cycle m census)
    (define (nc-targets nm)
      (let ((n (find-node m nm)))
        (if n (filter (lambda (t) (member t census)) (nonconsuming-targets n)) '())))
    (filter (lambda (start)
              (let walk ((frontier (nc-targets start)) (seen '()))
                (cond ((null? frontier) #f)
                      ((eq? (car frontier) start) #t)
                      ((member (car frontier) seen) (walk (cdr frontier) seen))
                      (else (walk (append (nc-targets (car frontier)) (cdr frontier))
                                  (cons (car frontier) seen))))))
            census))

  ;; :909 EOF-reachable stop / EOF zero-progress cycle -- the EOF walk (0023 item 3,
  ;; 0030 item 6). The PARKED SET (states an execution can be parked on): the entry,
  ;; every byte-reached pause, and every byte-reached node carrying its own EOF route
  ;; (a symbol eof-target). Each parked node is classified as ITSELF; its walk BEGINS
  ;; at `parked-eof-start`'s answer (a pause at its continuation, a non-entry counted
  ;; consume at its eof-target, else itself). The walk follows EOF successors, JOINS
  ;; verdicts (benign < stop < cycle, item 5), and the parked node reports the join.
  (define (stop-name? m t) (let ((n (find-node m t))) (and n (stop-node? n))))
  ;; EOF successors of a node the walk ARRIVES at (a list; empty = a benign EOF
  ;; terminus such as the default EOF error or a finish/error terminal).
  (define (eof-succs m n)
    (cond
     ((stop-node? n) '())            ; classified by stop-name? before we get here
     ((finish-node? n) '())          ; benign
     ((error-node? n) '())           ; benign (an EOF error)
     ((pause-node? n) (list (pause-node-continuation n)))
     ((field-action-node? n) (append (list (field-action-node-next n)) (sym (field-action-node-error n))))
     ((field-branch-node? n) (list (field-branch-node-true-target n) (field-branch-node-false-target n)))
     ;; a callback the walk ARRIVES at is flowed through: parser-finish! invokes it
     ;; and all three §13:803-808 outcomes are live -- continue, every branch, and
     ;; the pause continuation (this is NOT which edge a parser PARKED here resumes
     ;; on, which parked-eof-start answers).
     ((callback-node? n)
      (append (list (callback-node-continue-target n))
              (map cadr (callback-node-branch-targets n))
              (list (callback-node-pause-continuation n))))
     ((span-start-node? n) (list (span-start-node-next n)))
     ((span-end-node? n) (list (span-end-node-next n)))
     ;; a counted consume the walk ARRIVES at has an unknown count, so BOTH its
     ;; positive-count EOF route and its zero-count `next` are live (0030 item 5).
     ((counted-consume-node? n)
      (append (sym (counted-consume-node-eof-target n)) (list (counted-consume-node-next n))))
     ((input-reading? n) (sym (eof-target-of n)))   ; byte/sequence dispatch, accumulate
     (else '())))
  ;; the verdict of the EOF walk arriving at node name `cur`.
  (define (eof-verdict m cur seen)
    (cond ((not (symbol? cur)) 'benign)
          ((member cur seen) 'cycle)
          (else
           (let ((n (find-node m cur)))
             (cond ((not n) 'benign)
                   ((stop-node? n) 'stop)
                   (else
                    (let ((succs (eof-succs m n)))
                      (if (null? succs) 'benign
                          (join-verdicts (map (lambda (s) (eof-verdict m s (cons cur seen))) succs))))))))))
  (define (join-verdicts vs)
    (cond ((memq 'cycle vs) 'cycle) ((memq 'stop vs) 'stop) (else 'benign)))
  ;; where a parked node's walk begins (0023 note; 0030 item 6). A non-entry
  ;; callback resumes at its pause continuation and a non-entry counted consume at
  ;; its eof-target (a parser parked there by need-input holds a positive count);
  ;; everything else -- entry, pause, and every eof-route node -- starts at itself.
  (define (parked-eof-start m n)
    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (callback-node-pause-continuation n))
          ((and (counted-consume-node? n) (not (eq? (node-name n) (machine-entry m))))
           (counted-consume-node-eof-target n))
          (else (node-name n))))
  ;; the parked set: byte-reached nodes an execution can be parked on -- the entry,
  ;; pauses (parked awaiting resume), callbacks (parked having just returned),
  ;; span-ends (resume point is the successor), and every node carrying an EOF route.
  (define (parked-set m)
    (let ((br (byte-reached m)))
      (filter (lambda (n)
                (and (member (node-name n) br)
                     (or (eq? (node-name n) (machine-entry m))
                         (pause-node? n)
                         (callback-node? n)
                         (span-end-node? n)
                         (symbol? (eof-target-of n)))))
              (machine-nodes m))))
  (define (rule-eof m)
    (uniq
     (apply append
       (map (lambda (start)
              (let ((v (eof-verdict m (parked-eof-start m start) '())))
                (cond ((eq? v 'stop) (list (cons 'eof-reachable-stop (node-name start))))
                      ((eq? v 'cycle) (list (cons 'eof-zero-progress-cycle (node-name start))))
                      (else '()))))
            (parked-set m)))))

  ;; a tiny map-filter over nodes returning the non-#f results.
  (define (filter-map-nodes m f)
    (let loop ((ns (machine-nodes m)) (out '()))
      (cond ((null? ns) (reverse out))
            ((f (car ns)) => (lambda (r) (loop (cdr ns) (cons r out))))
            (else (loop (cdr ns) out)))))

  ;; ---- the hand-written rule table (design §4.6) ----------------------------
  ;; comparison: 'exact (set-equal to the verifier's set for these codes) or
  ;; 'subset (oracle's set ⊆ the verifier's).
  ;; reach? = the rule walks the graph from the entry, so it needs a well-formed
  ;; graph (unique node names). The program does not compare a reach? rule on a
  ;; machine whose node names are not unique (only the dup-node-name entry).
  (define-record-type oracle-rule (fields name codes comparison fn reach?))
  (define oracle-rules
    (list
     (make-oracle-rule ':885-duplicates
       '(duplicate-name duplicate-error-declaration duplicate-callback-declaration duplicate-span-declaration)
       'exact rule-duplicates #f)
     (make-oracle-rule ':885-nondup '(invalid-field-declaration duplicate-branch-key)
       'subset rule-885-nondup #f)
     (make-oracle-rule ':887-905-missing-target '(missing-target) 'exact rule-missing-target #f)
     (make-oracle-rule ':893-overlap '(overlapping-cases) 'exact rule-overlap #f)
     (make-oracle-rule ':894-prefix '(ambiguous-sequence-prefix) 'exact rule-prefix #f)
     (make-oracle-rule ':897-unreachable '(unreachable-node) 'exact rule-unreachable #t)
     (make-oracle-rule ':908-non-eof-into-finish '(non-eof-into-finish) 'exact rule-non-eof-into-finish #t)
     (make-oracle-rule ':909-eof '(eof-reachable-stop eof-zero-progress-cycle) 'exact rule-eof #t)
     (make-oracle-rule ':898-zero-progress '(zero-progress-cycle) 'exact rule-zero-progress #t)))

  ;; run one rule on a machine, returning its (code . node) set. A non-machine
  ;; (the catalogue's shape-not-a-machine output) has no graph, so no graph rule
  ;; fires -- the verifier's invalid-shape is outside every oracle rule's codes.
  (define (oracle-eval rule m)
    (if (machine? m) ((oracle-rule-fn rule) m) '())))
