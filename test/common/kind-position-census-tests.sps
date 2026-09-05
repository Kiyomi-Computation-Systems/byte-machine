;;; The kind x position matrix: every node kind, in every structural position
;;; that can hold a node reference.
;;;
;;; *** This is the instrument Milestone 4 Slice ③ did not have. *** That slice
;;; shipped three verifier defects -- two Critical -- of one shape: a new node
;;; kind was taught the shared accessors and NOT the hand-written per-kind
;;; filters that read them, where a missing kind is silent. Every fixture missed
;;; all three by construction, because no fixture put the new kind in the old
;;; positions. 368 mutations and a clean whole-pass sweep were blind to it.
;;;
;;; That is a CENSUS failure, and the instrument for a census is exhaustive and
;;; deterministic. Validated before being built: 38 single-kind omissions
;;; injected into a copy of verify.sls are distinguished 34 times by this matrix,
;;; including all three of Slice ③'s defects.
;;;
;;; EXPECTED VERDICTS ARE DERIVED FROM §16.2, NEVER OBSERVED. Recording what the
;;; verifier happens to return would freeze today's defects into an artifact that
;;; reads as authoritative -- which is exactly what nearly happened: four cells
;;; in the entry column contradicted §16.2:909 until Slice ⓪b fixed them. A cell
;;; whose observation differs from its derivation is a FINDING, not a baseline.
;;;
;;; THREE families of rule in the verifier are sensitive to a target's KIND, and
;;; all three are derived here from the spec rather than from the code:
;;;   §16.2:908  a finish terminal must not be BYTE-REACHABLE
;;;   §16.2:909  an EOF path must not reach a stop terminal
;;;   §16.2:899/:900/:907  the span-state lattice (Milestone 5 Slice ③,
;;;              decision 0029) -- see `expected-codes`, which states what this
;;;              skeleton does with a span and derives each verdict from it.
;;; The third arrived with the eleventh and twelfth kinds; before them this
;;; header said there were only two, and it was true when written.
;;; Everything else accepts. "Impossible by construction" is EMPTY on the kind
;;; axis, structurally: every target slot is a bare symbol and a node constructor
;;; cannot see the machine's node list, so every kind restriction is necessarily
;;; a verifier check.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        ;; The kind PREDICATES, for the row-key check below. They come from the
        ;; private library rather than from `(byte-machine graph)`, whose header
        ;; states that reading a built machine back is deliberately not part of
        ;; the construction surface -- widening that for a test would be trading
        ;; a documented contract for a convenience. Importing a private library
        ;; is the shipped practice for tests that need internals
        ;; (field-access-tests.sps does it for `normal-ir` and `conditions`).
        (only (byte-machine private ir)
              byte-dispatch-node? sequence-dispatch-node? stop-node? error-node?
              finish-node? pause-node? field-action-node? field-branch-node?
              integer-accumulate-node? callback-node?
              span-start-node? span-end-node?)
        (byte-machine verify))

(harness-begin "unit.kind-position-census")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
;; Declared in EVERY cell machine, including the ones that place no callback
;; node. §16.2:901's node half resolves a callback node's `callback` and its
;; branch keys against this table, and a matrix cell must record the placed
;; node's POSITION -- an undeclared-callback diagnostic in every callback cell
;; would be measuring the fixture. Uniform across all five machine builders on
;; purpose: a declaration present in some and absent in others is exactly the
;; divergence this instrument exists to make visible.
(define cb-decl (make-callback-declaration 'cb 'decision #t '(yes) #f #f))
;; Slice ③: the same reasoning one kind later. A span node names a span, a span
;; names a span-data callback, and §16.2:890/:892 resolve both -- so the cell
;; machines declare the whole chain or every span cell reports a fixture defect
;; instead of a position.
(define sd-decl (make-callback-declaration 'on-data 'span-data #t '() #f #f))
(define sp-decl (make-span-declaration 'sp 'on-data #f #f))

;; The shared sinks every placed node's own out-edges land on. Never the host,
;; so a cell's record is about the placed node's POSITION and not about a cycle
;; the skeleton happened to create.
(define (sinks) (list (make-error-node 'ee 'rejected #f)))

;; --- the twelve kinds, as data ----------------------------------------------
;; Each builder returns the node named `t`. Its own out-edges go to the sinks.
(define kind-table
  (list
   (cons 'byte-dispatch
         (lambda (nm) (make-byte-dispatch-node nm
                        (list (make-byte-case (make-exact-byte-matcher 1)
                                              (make-edge 'ee 'advance) #f))
                        (make-edge 'ee 'reexecute) #f #f)))
   (cons 'sequence-dispatch
         (lambda (nm) (make-sequence-dispatch-node nm
                        (list (make-sequence-case '(1) 'ee #f))
                        (make-edge 'ee 'reexecute) #f #f)))
   (cons 'stop (lambda (nm) (make-stop-node nm #f)))
   (cons 'error (lambda (nm) (make-error-node nm 'rejected #f)))
   (cons 'finish (lambda (nm) (make-finish-node nm #f)))
   (cons 'pause (lambda (nm) (make-pause-node nm 'ee #f)))
   (cons 'field-action
         (lambda (nm) (make-field-action-node nm 'clear '(n) 'ee #f #f)))
   (cons 'field-branch
         (lambda (nm) (make-field-branch-node nm 'zero '(n) 'ee 'ee #f)))
   (cons 'integer-accumulate
         (lambda (nm) (make-integer-accumulate-node nm 'n 10 'ee
                                                    (make-edge 'ee 'advance) 'ee #f #f)))
   ;; The tenth kind (Milestone 5 Slice ②). Its three out-edges -- continue, one
   ;; declared branch, and the pause continuation -- all land on the shared sink,
   ;; so the cell records the placed node's POSITION and not its own wiring. The
   ;; callback name and branch key are `cb-decl`'s, so §16.2:901's
   ;; cross-reference resolves and the cell keeps measuring position.
   (cons 'callback
         (lambda (nm) (make-callback-node nm 'cb 'ee '((yes ee)) 'ee #f)))
   ;; The eleventh and twelfth (Milestone 5 Slice ③). One successor each, on the
   ;; shared sink, so the cell records the placed node's POSITION.
   (cons 'span-start (lambda (nm) (make-span-start-node nm 'sp 'ee #f)))
   (cons 'span-end (lambda (nm) (make-span-end-node nm 'sp 'ee #f)))))

;; --- the twenty-one positions, as data --------------------------------------
;; Each builder returns (entry . host-nodes) with the placed node `t` wired into
;; that one position. Every host is byte-reachable from the entry, so no cell
;; carries an incidental unreachable-node and the byte-reachability gate that
;; §16.2:908 and :909 both use is satisfied for the host.
;;
;; `byte?` says whether the position is a BYTE out-edge of its host (which is
;; what §16.2:908 is about); `eof?` whether it is an EOF route (§16.2:909).
(define (dispatch-to target) (make-byte-dispatch-node 'h
                               (list (make-byte-case (make-exact-byte-matcher 0)
                                                     (make-edge target 'advance) #f))
                               (make-edge 'ee 'reexecute) #f #f))
(define position-table
  (list
   ;;   name                       byte? eof?  builder
   (list 'machine-entry             #t   #t   (lambda () (cons 't '())))
   (list 'dispatch-case             #t   #f   (lambda () (cons 'h (list (dispatch-to 't)))))
   (list 'dispatch-fallback         #t   #f
         (lambda () (cons 'h (list (make-byte-dispatch-node 'h
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 'ee 'advance) #f))
                                     (make-edge 't 'reexecute) #f #f)))))
   (list 'dispatch-eof-target       #f   #t
         (lambda () (cons 'h (list (make-byte-dispatch-node 'h
                                     (list (make-byte-case (make-exact-byte-matcher 0)
                                                           (make-edge 'ee 'advance) #f))
                                     (make-edge 'ee 'reexecute) 't #f)))))
   (list 'sequence-case             #t   #f
         (lambda () (cons 'h (list (make-sequence-dispatch-node 'h
                                     (list (make-sequence-case '(1) 't #f))
                                     (make-edge 'ee 'reexecute) #f #f)))))
   (list 'sequence-mismatch         #t   #f
         (lambda () (cons 'h (list (make-sequence-dispatch-node 'h
                                     (list (make-sequence-case '(1) 'ee #f))
                                     (make-edge 't 'reexecute) #f #f)))))
   (list 'sequence-eof-target       #f   #t
         (lambda () (cons 'h (list (make-sequence-dispatch-node 'h
                                     (list (make-sequence-case '(1) 'ee #f))
                                     (make-edge 'ee 'reexecute) 't #f)))))
   (list 'pause-continuation        #t   #t
         (lambda () (cons 'h (list (dispatch-to 'p) (make-pause-node 'p 't #f)))))
   (list 'field-action-next         #t   #f
         (lambda () (cons 'h (list (dispatch-to 'fa)
                                   (make-field-action-node 'fa 'clear '(n) 't #f #f)))))
   (list 'field-action-error        #t   #f
         (lambda () (cons 'h (list (dispatch-to 'fa)
                                   (make-field-action-node 'fa 'increment '(n) 'ee 't #f)))))
   (list 'field-branch-true         #t   #f
         (lambda () (cons 'h (list (dispatch-to 'fb)
                                   (make-field-branch-node 'fb 'zero '(n) 't 'ee #f)))))
   (list 'field-branch-false        #t   #f
         (lambda () (cons 'h (list (dispatch-to 'fb)
                                   (make-field-branch-node 'fb 'zero '(n) 'ee 't #f)))))
   (list 'accumulate-digit          #t   #f
         (lambda () (cons 'h (list (dispatch-to 'ac)
                                   (make-integer-accumulate-node 'ac 'n 10 't
                                     (make-edge 'ee 'advance) 'ee #f #f)))))
   (list 'accumulate-nondigit       #t   #f
         (lambda () (cons 'h (list (dispatch-to 'ac)
                                   (make-integer-accumulate-node 'ac 'n 10 'ac
                                     (make-edge 't 'advance) 'ee #f #f)))))
   (list 'accumulate-overflow       #t   #f
         (lambda () (cons 'h (list (dispatch-to 'ac)
                                   (make-integer-accumulate-node 'ac 'n 10 'ac
                                     (make-edge 'ee 'advance) 't #f #f)))))
   (list 'accumulate-eof-target     #f   #t
         (lambda () (cons 'h (list (dispatch-to 'ac)
                                   (make-integer-accumulate-node 'ac 'n 10 'ac
                                     (make-edge 'ee 'advance) 'ee 't #f)))))
   ;; --- the callback node's three out-edges (Milestone 5 Slice ②) ---
   ;; All three are BYTE routes: the node is zero-width, so whatever byte edge
   ;; reaches the host reaches them, and §16.2:908's gate is byte-reachability.
   ;; Only the PAUSE CONTINUATION is an EOF route. A parser parked at a callback
   ;; node is parked because that callback returned pause, and §13:812 resumes
   ;; "at that invocation's declared pause continuation" -- one edge. The
   ;; continue and branch targets become EOF-reachable only when the walk flows
   ;; THROUGH the callback, which this host's #f eof-target prevents.
   (list 'callback-continue          #t   #f
         (lambda () (cons 'h (list (dispatch-to 'cn)
                                   (make-callback-node 'cn 'cb 't '((yes ee)) 'ee #f)))))
   (list 'callback-branch            #t   #f
         (lambda () (cons 'h (list (dispatch-to 'cn)
                                   (make-callback-node 'cn 'cb 'ee '((yes t)) 'ee #f)))))
   (list 'callback-pause-continuation #t  #t
         (lambda () (cons 'h (list (dispatch-to 'cn)
                                   (make-callback-node 'cn 'cb 'ee '((yes ee)) 't #f)))))
   ;; --- the span kinds' single successors (Milestone 5 Slice ③) ---
   ;; BYTE routes, like a field action's `next`: both kinds are zero-width, so
   ;; whatever byte edge reaches the host reaches them. NOT eof routes -- the
   ;; host's #f eof-target means the EOF walk never flows through the host.
   ;;
   ;; *** A SPAN END IS A PARKED STATE, and this comment said the opposite until
   ;; the final review. *** The claim was that "§14:837-838 park on the
   ;; CALLBACK", and a span-data callback has no callback node: its pause parks
   ;; the parser on the span end's own completion substep. That is why
   ;; `span-end-next` is the one non-EOF position whose `stop` cell reports
   ;; `eof-reachable-stop` and whose self-loop reports `eof-zero-progress-cycle`
   ;; -- both derived in `expected-codes` and `self-expectations` below. A span
   ;; START is still not parked: it calls nothing.
   (list 'span-start-next           #t   #f
         (lambda () (cons 'h (list (dispatch-to 'ss)
                                   (make-span-start-node 'ss 'sp 't #f)))))
   (list 'span-end-next             #t   #f
         (lambda () (cons 'h (list (dispatch-to 'se)
                                   (make-span-end-node 'se 'sp 't #f)))))))

;; *** Every row must BUILD the kind it is keyed by. *** Found by the
;; whole-branch review: without this, swapping one builder for another kind's
;; leaves the whole suite green while nineteen cells silently test the wrong kind
;; and the kind they claim to test disappears from the matrix entirely. A table
;; keyed by a name nothing checks is a census with no census.
(define kind-predicates
  (list (cons 'byte-dispatch byte-dispatch-node?)
        (cons 'sequence-dispatch sequence-dispatch-node?)
        (cons 'stop stop-node?)
        (cons 'error error-node?)
        (cons 'finish finish-node?)
        (cons 'pause pause-node?)
        (cons 'field-action field-action-node?)
        (cons 'field-branch field-branch-node?)
        (cons 'integer-accumulate integer-accumulate-node?)
        (cons 'callback callback-node?)
        (cons 'span-start span-start-node?)
        (cons 'span-end span-end-node?)))

(define (position-name p) (car p))
(define (position-byte? p) (cadr p))
(define (position-eof? p) (caddr p))
(define (position-build p) ((cadddr p)))

;; The DERIVED expectation. Two rules, both from §16.2, applied before the
;; machine is run. Everything else accepts.
;; *** Milestone 5 Slice ③ adds a THIRD kind-sensitive family, and the header's
;; claim that there are only two is corrected there rather than here. *** Pass 7
;; (decision 0029) makes span state a dataflow over the whole graph, so a placed
;; span node's verdict depends on the SKELETON and not only on the position. The
;; skeleton is fixed, so the derivation is still a derivation -- it is written
;; out below rather than observed, and every cell that disagrees is a FINDING.
;;
;; What the skeleton does with a span, stated once:
;;   - NOTHING in it opens a span except a placed span-start or the host of the
;;     two span POSITIONS, so a placed span-end is normally `unmatched end`.
;;   - a placed span-start leaves the span open on its own out-edge, which lands
;;     on the SHARED SINK -- which the host also reaches with no span open. Two
;;     disagreeing edges is `top`, reported at the sink. `machine-entry` has no
;;     host, so nothing disagrees there.
;;   - the three TERMINAL kinds have no out-edges, so they never carry a span to
;;     the sink and never produce that disagreement.
;;   - at `span-start-next` the host opens the span, so the placed node is
;;     reached WITH it active: a pause or callback is §16.2:900, a stop or finish
;;     is §16.2:907, a second start is re-entry, and a span-end closes it.
;;   - at `span-end-next` the host's own span-end is unmatched, so every cell
;;     there carries that one finding and the placed node still sees `none`.
;;   - and `span-end-next` is the one non-EOF position that STARTS an EOF walk.
;;     A span end is a parked state (§16.2:909): its data callback's pause parks
;;     the parser on that node's completion substep, so the walk begins at the
;;     node's successor -- which at this position is the placed node. A stop
;;     there is `eof-reachable-stop`, exactly as it is at a real EOF position.
;;     Slice ③ shipped without this and the matrix is what found it.
(define terminal-kinds '(stop error finish))
(define (expected-codes p kind)
  (let* ((pos (position-name p))
         (host-opens? (eq? pos 'span-start-next))
         (host-unmatched? (eq? pos 'span-end-next))
         (entry? (eq? pos 'machine-entry)))
    (append
     (if (and (eq? kind 'finish) (position-byte? p)) '(non-eof-into-finish) '())
     (if (and (eq? kind 'stop) (or (position-eof? p) host-unmatched?))
         '(eof-reachable-stop) '())
     (if host-unmatched? '(invalid-span-state) '())
     (cond
       ((eq? kind 'span-end) (if host-opens? '() '(invalid-span-state)))
       ((eq? kind 'span-start)
        (append (if host-opens? '(invalid-span-state) '())
                (if entry? '() '(inconsistent-span-state))))
       (host-opens?
        (append (if (memq kind '(pause callback)) '(span-active-at-pause) '())
                (if (memq kind '(stop finish)) '(span-active-at-exit) '())
                (if (memq kind terminal-kinds) '() '(inconsistent-span-state))))
       (else '())))))

(define (cell-machine p kind)
  (let* ((built (position-build p))
         (entry (car built))
         (host (cdr built))
         (t ((cdr (assq kind kind-table)) 't)))
    (make-machine 'cell entry (list (make-uint-field 'n 8 0 #f)) (list cb-decl sd-decl) (list sp-decl)
                  (list eof-decl rej-decl)
                  (append host (list t) (sinks))
                  'default-eof #f)))

;; *** The skeleton is PRUNED, and the pruning uses the verifier's own answer. ***
;; A fixed skeleton puts `unreachable-node` in nearly every cell and swamps the
;; signal; the plan's §3.1 resolves that by pruning. Computing reachability here
;; would mean re-implementing `node-out-targets` -- a second census, the very
;; thing this instrument exists to catch. So the cell is built WITH the shared
;; error sink, and if the verifier reports that sink unreachable it is rebuilt
;; without it. One ingredient, one question, and the verifier answers it.
;;
;; The sink set that survives is part of the cell's recorded value below, so a
;; skeleton that shifts is a failed comparison rather than a silent re-shaping.
(define (build p kind with-sink?)
  (let* ((built (position-build p))
         (entry (car built))
         (host (cdr built))
         (t ((cdr (assq kind kind-table)) 't)))
    (make-machine 'cell entry (list (make-uint-field 'n 8 0 #f)) (list cb-decl sd-decl) (list sp-decl)
                  (list eof-decl rej-decl)
                  (append host (list t) (if with-sink? (sinks) '()))
                  'default-eof #f)))

(define (codes-of m)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
             (map diagnostic-code (verification-diagnostics (verify-machine m)))))

;; Returns (codes . sinks-kept?) -- both halves are the cell's record.
(define (observe p kind)
  (let* ((m (build p kind #t))
         (ds (verification-diagnostics (verify-machine m)))
         (sink-dead? (memq 'ee (map diagnostic-node
                                    (filter (lambda (d)
                                              (eq? (diagnostic-code d) 'unreachable-node))
                                            ds)))))
    (if sink-dead?
        (cons (codes-of (build p kind #f)) #f)
        (cons (codes-of m) #t))))

(harness-group "every kind in every position agrees with §16.2 (axis A)"
  (lambda ()
    (harness-case "the product is driven and every cell matches its derived verdict"
      (lambda ()
        ;; S1: the count is read from the loop as it runs, and compared against a
        ;; product computed in a SEPARATE expression. A cell that never ran
        ;; cannot satisfy the comparison below vacuously.
        (let ((driven 0) (bad '()) (pruned 0))
          (for-each
           (lambda (p)
             (for-each
              (lambda (kv)
                (set! driven (+ driven 1))
                (unless (cdr (observe p (car kv))) (set! pruned (+ pruned 1)))
                (let ((want (list-sort (lambda (a b) (string<? (symbol->string a)
                                                               (symbol->string b)))
                                       (expected-codes p (car kv))))
                      (got (car (observe p (car kv)))))
                  (unless (equal? want got)
                    (set! bad (cons (list (position-name p) (car kv) 'want want 'got got)
                                    bad)))))
              kind-table))
           position-table)
          (check-equal "every cell was driven"
                       driven (* (length position-table) (length kind-table)))
          (check-equal "and every one matches §16.2" bad '())
          ;; *** The pruned skeleton is ASSERTED, not merely computed. *** The
          ;; comment above claimed the surviving sink set was part of each cell's
          ;; recorded value; the whole-branch review found it was computed and
          ;; thrown away, so a change that stopped pruning altogether left the
          ;; matrix green. This is an OBSERVED count: three cells drop the sink,
          ;; and they are exactly the three terminal kinds placed AT THE ENTRY,
          ;; where nothing else in the machine can reference it.
          (check-equal "exactly three cells prune the sink" pruned 3))))))

;; S2: the closed-set drift row. `node?`'s disjunct list in ir.sls IS the set of
;; kinds; the table above must cover it exactly. THIS is the row that goes red
;; when Milestone 5 adds a callback node kind -- before any fixture does.
(define source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r "")))
        r
        (assertion-violation 'kind-position-census
                             "BYTE_MACHINE_SOURCE_ROOT is unset" r))))

(define (kind-predicates-in-source)
  ;; Find `(define (node? x) (or (p1? x) ...))` and return the predicate names.
  (let ((datum (call-with-input-file
                   (string-append source-root "/byte-machine/private/ir.sls")
                 read)))
    (let loop ((x datum))
      (cond ((not (pair? x)) #f)
            ((and (pair? (car x)) (eq? (caar x) 'define)
                  (pair? (cdar x)) (pair? (cadar x))
                  (eq? (car (cadar x)) 'node?))
             (let ((body (caddar x)))
               (if (and (pair? body) (eq? (car body) 'or))
                   (map car (cdr body))
                   #f)))
            (else (or (loop (car x)) (loop (cdr x))))))))

(harness-group "each kind row builds the kind it is keyed by"
  (lambda ()
    (harness-case "the builder's product satisfies its key's predicate"
      (lambda ()
        ;; The predicate table is keyed the same way as the builder table, and S2
        ;; below checks that key set against ir.sls -- so a kind cannot be missing
        ;; from BOTH without S2 noticing.
        (let ((checked 0) (bad '()))
          (for-each
           (lambda (kv)
             (let ((pred (assq (car kv) kind-predicates)))
               (if (not pred)
                   (set! bad (cons (list (car kv) 'no-predicate) bad))
                   (begin
                     (set! checked (+ checked 1))
                     (unless ((cdr pred) ((cdr kv) 't))
                       (set! bad (cons (list (car kv) 'wrong-kind) bad)))))))
           kind-table)
          (check-equal "every builder was checked" checked (length kind-table))
          (check-equal "and each builds its own kind" bad '()))))))

(harness-group "the kind table covers exactly ir.sls's closed set (S2)"
  (lambda ()
    (harness-case "node?'s disjuncts and the table's keys are the same set"
      (lambda ()
        (let ((preds (kind-predicates-in-source)))
          (check "node?'s disjunct list was found" (and preds (pair? preds)))
          (when (and preds (pair? preds))
            (let ((from-source
                   (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                              (map (lambda (p)
                                     ;; `byte-dispatch-node?` -> `byte-dispatch`
                                     (let* ((s (symbol->string p))
                                            (n (string-length s)))
                                       (string->symbol
                                        (substring s 0 (- n (string-length "-node?"))))))
                                   preds)))
                  (from-table
                   (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                              (map car kind-table))))
              (check-equal "the same twelve kinds" from-source from-table))))))))


;; --- axis A': the POSITION drift row (Milestone 5 Slice ①a task 5) -----------
;;
;; *** THIS ROW RATCHETS AGAINST DRIFT; IT CANNOT CERTIFY COMPLETENESS. *** S2
;; above derives its set from `ir.sls`, a file INDEPENDENT of the census's
;; subject. There is no equivalent source for POSITIONS: decision 0025 point 4
;; and the design both said to derive them "from the IR", and measured
;; 2026-09-04, `ir.sls` has no position vocabulary to derive from -- the only
;; enumeration with the right cardinality is in `verify.sls`, the file this
;; census exists to test. So the POSITION side is a hand-written fixture table,
;; not a second derivation, and no assertion here can say the nineteen rows are
;; the right nineteen.
;;
;; *** A CLAIM MADE HERE ON FIRST WRITING WAS BACKWARDS, and the correction is
;; worth more than the original point. *** It said the row is BLIND under the
;; mutation suite, reasoning that the census reads the STAGED tree
;; (`SchemeMutationSuite.cmake:1157`) so a mutation deleting an edge role deletes
;; it from the code AND from the set derived here. The first half is true and the
;; conclusion does not follow: the derived set is compared against
;; `role->positions` BELOW, which lives in this file and is DECLARED. A mutation
;; whose FILE is `verify.sls` stages a mutated `verify.sls` and an unmutated copy
;; of this test, so the two sides disagree and the row goes RED. The row is a
;; mutation witness. It is unwitnessed only in the sense that nothing has yet
;; declared a mutation pointing at it.
;;
;; What it catches, then, is any edit -- by hand or by mutation -- that adds or
;; removes an edge role in `verify.sls` without a matching position. That is the
;; Milestone 4 defect shape one level up. `position-table` was already read by
;; the axis-A driver and the dangling-target group before this row; what none of
;; them did was compare it against anything OUTSIDE this file.
;;
;; The role-to-position MAPPING below is declared, not derived, and that is
;; deliberate: the two vocabularies genuinely disagree (see `alternative`), so a
;; derivation would have to encode the disagreement silently. Declaring it makes
;; the mismatch the artifact. The ROLE SET is derived, so a new role with no
;; mapping entry reddens.

(define (edge-roles-in-source)
  ;; Every `(cons 'ROLE ...)` inside verify.sls, which is how `zero-width-edges`
  ;; and `node-out-edges` -- the one census, two views -- label an out-edge.
  (let ((datum (call-with-input-file
                   (string-append source-root "/byte-machine/verify.sls")
                 read))
        (acc '()))
    (let loop ((x datum))
      (when (pair? x)
        (when (and (eq? (car x) 'cons)
                   (pair? (cdr x))
                   (pair? (cadr x))
                   (eq? (car (cadr x)) 'quote)
                   (symbol? (cadr (cadr x))))
          (let ((r (cadr (cadr x))))
            (unless (memq r acc) (set! acc (cons r acc)))))
        (loop (car x))
        (loop (cdr x))))
    acc))

;; role (as verify.sls spells it) -> the position-table names that carry it.
;; `alternative` is the mismatch this row exists to make visible: verify.sls
;; labels a sequence alternative's edge `alternative`, the matrix calls that
;; position `sequence-case`. Neither is wrong; nothing connected them until now.
(define role->positions
  '((case          dispatch-case)
    (fallback      dispatch-fallback)
    (alternative   sequence-case)
    (mismatch      sequence-mismatch)
    (continuation  pause-continuation)
    ;; Slice ③ adds two positions under the SAME role: both span kinds have one
    ;; successor and reuse `next` rather than minting roles that would say the
    ;; same thing. The mapping's value is a LIST for exactly this case.
    (next          field-action-next span-start-next span-end-next)
    (error         field-action-error)
    (true          field-branch-true)
    (false         field-branch-false)
    (digit         accumulate-digit)
    (nondigit      accumulate-nondigit)
    (overflow      accumulate-overflow)
    ;; Slice ②. verify.sls names these three for §13:803-808's outcomes; the
    ;; matrix names the positions after the node and the slot. `pause` here is
    ;; the callback's pause continuation and is a different edge from the pause
    ;; NODE's `continuation` above -- two kinds, two roles, no reuse.
    (continue      callback-continue)
    (branch        callback-branch)
    (pause         callback-pause-continuation)))

(harness-group "every edge role verify.sls labels has a matrix position (A')"
  (lambda ()
    (harness-case "the derived role set is exactly the mapping's keys"
      (lambda ()
        (let ((roles (edge-roles-in-source)))
          (check "roles were found in verify.sls" (> (length roles) 0))
          (let ((sorted (lambda (l) (list-sort (lambda (a b)
                                                 (string<? (symbol->string a)
                                                           (symbol->string b)))
                                               l))))
            (check-equal "derived roles equal the mapped roles"
                         (sorted roles)
                         (sorted (map car role->positions)))))))
    (harness-case "every mapped position exists in position-table"
      (lambda ()
        ;; Sentinel reads the OBSERVED count, not the mapping's length: a loop
        ;; that never runs cannot satisfy it.
        (let ((names (map car position-table)) (checked 0) (missing '()))
          (for-each
           (lambda (entry)
             (for-each (lambda (pos)
                         (set! checked (+ checked 1))
                         (unless (memq pos names)
                           (set! missing (cons pos missing))))
                       (cdr entry)))
           role->positions)
          (check-equal "every mapped position was looked up" checked 17)
          (check-equal "and each one exists" missing '()))))
    (harness-case "the four EOF and entry positions are accounted for outside the role map"
      (lambda ()
        ;; `node-eof-target` and the machine entry carry no `(cons 'role ...)`
        ;; label, so they cannot appear in the derived set. They are named here so
        ;; that position-table's 21 rows are 17 mapped + these 4, and a row added
        ;; with neither a role nor a place here reddens the count below.
        (let ((names (map car position-table)))
          (for-each (lambda (p) (check (symbol->string p) (memq p names)))
                    '(machine-entry dispatch-eof-target sequence-eof-target
                      accumulate-eof-target))
          (check-equal "position-table is exactly 17 role-carrying + 4 unlabelled"
                       (length position-table) 21))))))


;; --- axis B: self-reference --------------------------------------------------
;; The target IS the owning node. This is where the zero-progress rules live, and
;; it is the axis a scoping cut would reach for first -- wrongly: it is the only
;; coverage in the tree of the site that reports an EOF cycle at a PAUSE, and it
;; is where four of the nineteen positions behave differently under `reexecute`.
;;
;; `machine-entry` has no self variant: the machine is not a node. Recorded as
;; not-driven rather than as a verdict.
;;
;; Each expectation is DERIVED and its derivation stated, not observed:
;;   §16.2 zero-progress -- a cycle of steps that consume no input
;;   §16.2:909           -- an EOF path that never reaches a terminal
;; A byte edge that ADVANCES makes progress, so a self-loop through it is legal;
;; the same edge under `reexecute` is not. A sequence case always consumes its
;; bytes (§10.6:546) and an accumulate digit edge advances (§10.6:566), so both
;; are legal self-loops by design.
(define self-expectations
  ;; (position mode . expected-codes)
  '(((dispatch-case         advance)   . ())
    ((dispatch-case         reexecute) . (zero-progress-cycle))
    ((dispatch-fallback     advance)   . ())
    ((dispatch-fallback     reexecute) . (zero-progress-cycle))
    ((dispatch-eof-target   advance)   . (eof-zero-progress-cycle))
    ((sequence-case         advance)   . ())
    ((sequence-mismatch     advance)   . ())
    ((sequence-mismatch     reexecute) . (zero-progress-cycle))
    ((sequence-eof-target   advance)   . (eof-zero-progress-cycle))
    ((pause-continuation    advance)   . (eof-zero-progress-cycle zero-progress-cycle))
    ((field-action-next     advance)   . (zero-progress-cycle))
    ((field-action-error    advance)   . (zero-progress-cycle))
    ((field-branch-true     advance)   . (zero-progress-cycle))
    ((field-branch-false    advance)   . (zero-progress-cycle))
    ((accumulate-digit      advance)   . ())
    ((accumulate-nondigit   advance)   . ())
    ((accumulate-nondigit   reexecute) . (zero-progress-cycle))
    ((accumulate-overflow   advance)   . (zero-progress-cycle))
    ((accumulate-eof-target advance)   . (eof-zero-progress-cycle))
    ;; Slice ②. Every callback edge is zero-width, so all three self-loops are
    ;; zero-progress cycles. Only the PAUSE CONTINUATION is also an EOF cycle,
    ;; and for the reason the position table states: a parser parked at this
    ;; node resumes on that one edge, so a self-targeting pause continuation is
    ;; an EOF path that never terminates -- while a self-targeting continue or
    ;; branch target hangs during FEED, which `zero-progress-cycle` is what
    ;; reports.
    ((callback-continue     advance)   . (zero-progress-cycle))
    ((callback-branch       advance)   . (zero-progress-cycle))
    ((callback-pause-continuation advance)
                                       . (eof-zero-progress-cycle zero-progress-cycle))
    ;; Slice ③. Both kinds are zero-width, so a self-targeting `next` is a
    ;; feed-time hang. They DIVIDE on the EOF cycle, and Slice ③ first recorded
    ;; here that neither is a parked state -- which was true of the span start
    ;; and false of the span end. A span end's data callback pause parks the
    ;; parser on that node's completion substep (§16.2:909, `parked-eof-start`),
    ;; so the walk starts at its successor, which here is itself: an EOF cycle as
    ;; well as a feed-time one, exactly like the callback pause continuation
    ;; above. A span start calls nothing and nothing can pause there.
    ;;
    ;; The span state at a SELF-loop, derived: `ss` opens and flows to itself,
    ;; so its own in-state joins `none` (from the host) with `(active sp)` (from
    ;; itself) -- `top`, reported at `ss`, and `top` does not flow onward, so no
    ;; re-entry check runs. `se` closes on `none`, which is unmatched, and its
    ;; out-state stays `none`, so the loop agrees with itself.
    ((span-start-next       advance)   . (inconsistent-span-state zero-progress-cycle))
    ((span-end-next         advance)   . (eof-zero-progress-cycle invalid-span-state
                                          zero-progress-cycle))))

;; The self machine: the host points the position under test at ITSELF.
(define (self-machine pos mode)
  (define (dsp cases fb eof) (make-byte-dispatch-node 'h cases fb eof #f))
  (define (one-case tgt m) (list (make-byte-case (make-exact-byte-matcher 0)
                                                 (make-edge tgt m) #f)))
  (define nodes
    (case pos
      ((dispatch-case)     (list (dsp (one-case 'h mode) (make-edge 'ee 'reexecute) #f)))
      ((dispatch-fallback) (list (dsp (one-case 'ee 'advance) (make-edge 'h mode) #f)))
      ((dispatch-eof-target) (list (dsp (one-case 'ee 'advance) (make-edge 'ee 'reexecute) 'h)))
      ((sequence-case)     (list (make-sequence-dispatch-node 'h
                                   (list (make-sequence-case '(1) 'h #f))
                                   (make-edge 'ee 'reexecute) #f #f)))
      ((sequence-mismatch) (list (make-sequence-dispatch-node 'h
                                   (list (make-sequence-case '(1) 'ee #f))
                                   (make-edge 'h mode) #f #f)))
      ((sequence-eof-target) (list (make-sequence-dispatch-node 'h
                                     (list (make-sequence-case '(1) 'ee #f))
                                     (make-edge 'ee 'reexecute) 'h #f)))
      ((pause-continuation) (list (dsp (one-case 'p 'advance) (make-edge 'ee 'reexecute) #f)
                                  (make-pause-node 'p 'p #f)))
      ((field-action-next) (list (dsp (one-case 'fa 'advance) (make-edge 'ee 'reexecute) #f)
                                 (make-field-action-node 'fa 'clear '(n) 'fa #f #f)))
      ((field-action-error) (list (dsp (one-case 'fa 'advance) (make-edge 'ee 'reexecute) #f)
                                  (make-field-action-node 'fa 'increment '(n) 'ee 'fa #f)))
      ((field-branch-true) (list (dsp (one-case 'fb 'advance) (make-edge 'ee 'reexecute) #f)
                                 (make-field-branch-node 'fb 'zero '(n) 'fb 'ee #f)))
      ((field-branch-false) (list (dsp (one-case 'fb 'advance) (make-edge 'ee 'reexecute) #f)
                                  (make-field-branch-node 'fb 'zero '(n) 'ee 'fb #f)))
      ((accumulate-digit) (list (dsp (one-case 'ac 'advance) (make-edge 'ee 'reexecute) #f)
                                (make-integer-accumulate-node 'ac 'n 10 'ac
                                  (make-edge 'ee 'advance) 'ee #f #f)))
      ((accumulate-nondigit) (list (dsp (one-case 'ac 'advance) (make-edge 'ee 'reexecute) #f)
                                   (make-integer-accumulate-node 'ac 'n 10 'ee
                                     (make-edge 'ac mode) 'ee #f #f)))
      ((accumulate-overflow) (list (dsp (one-case 'ac 'advance) (make-edge 'ee 'reexecute) #f)
                                   (make-integer-accumulate-node 'ac 'n 10 'ee
                                     (make-edge 'ee 'advance) 'ac #f #f)))
      ((accumulate-eof-target) (list (dsp (one-case 'ac 'advance) (make-edge 'ee 'reexecute) #f)
                                     (make-integer-accumulate-node 'ac 'n 10 'ee
                                       (make-edge 'ee 'advance) 'ee 'ac #f)))
      ((callback-continue) (list (dsp (one-case 'cn 'advance) (make-edge 'ee 'reexecute) #f)
                                 (make-callback-node 'cn 'cb 'cn '((yes ee)) 'ee #f)))
      ((callback-branch) (list (dsp (one-case 'cn 'advance) (make-edge 'ee 'reexecute) #f)
                               (make-callback-node 'cn 'cb 'ee '((yes cn)) 'ee #f)))
      ((callback-pause-continuation)
       (list (dsp (one-case 'cn 'advance) (make-edge 'ee 'reexecute) #f)
             (make-callback-node 'cn 'cb 'ee '((yes ee)) 'cn #f)))
      ((span-start-next) (list (dsp (one-case 'ss 'advance) (make-edge 'ee 'reexecute) #f)
                               (make-span-start-node 'ss 'sp 'ss #f)))
      ((span-end-next) (list (dsp (one-case 'se 'advance) (make-edge 'ee 'reexecute) #f)
                             (make-span-end-node 'se 'sp 'se #f)))
      (else (assertion-violation 'self-machine "no such position" pos))))
  (make-machine 'self 'h (list (make-uint-field 'n 8 0 #f)) (list cb-decl sd-decl) (list sp-decl)
                (list eof-decl rej-decl)
                (append nodes (sinks)) 'default-eof #f))

(harness-group "every position pointed at itself (axis B)"
  (lambda ()
    (harness-case "each self-reference matches its derived verdict"
      (lambda ()
        ;; A sentinel over the rows DRIVEN, compared against the table's length
        ;; computed separately -- and, separately again, against the count of
        ;; positions that can have a self variant at all (all but the entry).
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (row)
             (set! driven (+ driven 1))
             (let* ((pos (caar row)) (mode (cadar row))
                    (want (list-sort (lambda (a b) (string<? (symbol->string a)
                                                             (symbol->string b)))
                                     (cdr row)))
                    (got (codes-of (self-machine pos mode))))
               (unless (equal? want got)
                 (set! bad (cons (list pos mode 'want want 'got got) bad)))))
           self-expectations)
          (check-equal "every self row was driven" driven (length self-expectations))
          (check-equal "and twenty positions have one, four of them twice"
                       driven (+ 20 4))
          (check-equal "each matches its derivation" bad '()))))))


;; --- axis C: the dangling name, and the absence census -----------------------
;; A target naming no node at all. This is the shape of Slice ③'s second
;; Critical one level up -- an accessor taught a kind, a consumer not taught it --
;; and it is where `missing-target` and `invalid-eof-target` become
;; matrix-shaped rather than hand-written.
;;
;; DERIVED: §16.2:905 makes an unresolvable target `missing-target`; the three
;; EOF routes carry `invalid-eof-target` instead, because a #f there is legal and
;; means "the machine default", so a SYMBOL that resolves to nothing is a
;; different fault from a missing edge.
(define eof-positions '(dispatch-eof-target sequence-eof-target accumulate-eof-target))

;; Rebuilt directly rather than reusing axis A's builder: a dangling cell has no
;; `t` node at all, and threading "omit t" through the shared builder would make
;; that builder answer two questions.
(define (dangle pos)
  (let* ((p (assq pos (map (lambda (q) (cons (position-name q) q)) position-table)))
         (built (position-build (cdr p)))
         (entry (car built))
         (host (cdr built)))
    (make-machine 'dangle entry (list (make-uint-field 'n 8 0 #f)) (list cb-decl sd-decl) (list sp-decl)
                  (list eof-decl rej-decl)
                  (append host (sinks)) 'default-eof #f)))

(harness-group "a target naming no node (axis C)"
  (lambda ()
    (harness-case "every position reports the resolution fault its route calls for"
      (lambda ()
        ;; machine-entry is excluded: an entry naming no node is `missing-target`
        ;; too, but its host list is empty so there is nothing to build.
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (q)
             (let ((pos (position-name q)))
               (unless (eq? pos 'machine-entry)
                 (set! driven (+ driven 1))
                 ;; Slice ③: `span-end-next`'s host is an unmatched span end
                 ;; whatever the placed node is, and a dangling cell has no
                 ;; placed node at all -- so that one finding rides along. Its
                 ;; sibling `span-start-next` does not: the host opens a span
                 ;; that reaches only the sink, which nothing else reaches with
                 ;; a different state once the placed node is gone.
                 (let ((want (cond ((memq pos eof-positions) '(invalid-eof-target))
                                   ((eq? pos 'span-end-next)
                                    '(invalid-span-state missing-target))
                                   (else '(missing-target))))
                       (got (codes-of (dangle pos))))
                   (unless (equal? want got)
                     (set! bad (cons (list pos 'want want 'got got) bad)))))))
           position-table)
          (check-equal "twenty dangling cells driven" driven 20)
          (check-equal "each reports its derived fault" bad '()))))))

;; --- the absence census ------------------------------------------------------
;; Where "impossible by construction" actually lives. The KIND axis has no
;; constructor refusals at all -- every target slot is a bare symbol and a node
;; constructor cannot see the machine's node list -- but the ABSENCE axis does:
;; seventeen positions reject #f outright, three accept it (the EOF routes,
;; where #f means the machine default), and one is CONDITIONAL.
(define (raises? thunk)
  (call/cc (lambda (k)
             (with-exception-handler (lambda (e) (k #t))
               (lambda () (thunk) #f)))))

(harness-group "which positions may be absent (the absence census)"
  (lambda ()
    (harness-case "the three EOF routes accept #f and the rest refuse it"
      (lambda ()
        (let ((refused 0) (accepted 0))
          ;; A representative of each refusing family, by constructor.
          (for-each (lambda (th) (when (raises? th) (set! refused (+ refused 1))))
                    (list (lambda () (make-edge #f 'advance))
                          (lambda () (make-sequence-case '(1) #f #f))
                          (lambda () (make-pause-node 'p #f #f))
                          (lambda () (make-field-action-node 'fa 'clear '(n) #f #f #f))
                          (lambda () (make-field-branch-node 'fb 'zero '(n) #f 'ee #f))
                          (lambda () (make-field-branch-node 'fb 'zero '(n) 'ee #f #f))
                          (lambda () (make-integer-accumulate-node 'ac 'n 10 #f
                                       (make-edge 'ee 'advance) 'ee #f #f))
                          (lambda () (make-integer-accumulate-node 'ac 'n 10 'ee
                                       (make-edge 'ee 'advance) #f #f #f))
                          ;; Slice ②. §10.6:586 makes BOTH the continue target
                          ;; and the pause continuation mandatory, and §9.1:318
                          ;; makes a branch entry a two-element list of a key
                          ;; and a target -- so a #f in any of the three is a
                          ;; construction refusal, not a verifier diagnostic.
                          (lambda () (make-callback-node 'cn 'cb #f '((yes ee)) 'ee #f))
                          (lambda () (make-callback-node 'cn 'cb 'ee '((yes ee)) #f #f))
                          (lambda () (make-callback-node 'cn 'cb 'ee '((yes #f)) 'ee #f))
                          ;; Slice ③. §10.6:590 and :594 give each span kind one
                          ;; successor and no route of its own, so #f there is a
                          ;; construction refusal on the field-action precedent.
                          (lambda () (make-span-start-node 'ss 'sp #f #f))
                          (lambda () (make-span-end-node 'se 'sp #f #f))))
          (check-equal "thirteen constructor refusals" refused 13)
          ;; The three EOF routes, built rather than refused.
          (for-each (lambda (th) (unless (raises? th) (set! accepted (+ accepted 1))))
                    (list (lambda () (make-byte-dispatch-node 'h
                                       (list (make-byte-case (make-exact-byte-matcher 0)
                                                             (make-edge 'ee 'advance) #f))
                                       (make-edge 'ee 'reexecute) #f #f))
                          (lambda () (make-sequence-dispatch-node 'h
                                       (list (make-sequence-case '(1) 'ee #f))
                                       (make-edge 'ee 'reexecute) #f #f))
                          (lambda () (make-integer-accumulate-node 'ac 'n 10 'ee
                                       (make-edge 'ee 'advance) 'ee #f #f))))
          (check-equal "three legally-absent EOF routes" accepted 3))))
    (harness-case "the field action's error slot is the one CONDITIONAL position"
      (lambda ()
        ;; Its existence is gated on the operation's fallibility (ir.sls's
        ;; `infallible-field-operations`): mandatory exactly when the operation
        ;; can fail, forbidden exactly when it cannot. The only cell in the whole
        ;; matrix whose EXISTENCE is conditional, so it is asserted all four ways.
        (check "an infallible op with an error target is refused"
               (raises? (lambda () (make-field-action-node 'fa 'clear '(n) 'ee 'ee #f))))
        (check "a fallible op with no error target is refused"
               (raises? (lambda () (make-field-action-node 'fa 'increment '(n) 'ee #f #f))))
        (check "an infallible op with no error target builds"
               (not (raises? (lambda () (make-field-action-node 'fa 'clear '(n) 'ee #f #f)))))
        (check "a fallible op with an error target builds"
               (not (raises? (lambda () (make-field-action-node 'fa 'increment '(n) 'ee 'ee #f)))))))))


;; --- axis D: the EOF verdict lattice ----------------------------------------
;; A field-branch is the only shape whose JOIN is observable: two arms, two
;; verdicts, one answer. Twenty-five cells, and the expectation is derived from
;; Slice ⓪b's three tiers rather than from the join's code:
;;
;;   tier 0  finish, error, default-error   the chain terminates
;;   tier 1  eof-reachable-stop             §16.2:909
;;   tier 2  cycle                          decision 0021 item 1
;;
;; The join takes the higher tier, and only tiers 1 and 2 produce a diagnostic.
;; The branch sits one hop from the entry, reached as the entry's eof-target, so
;; its arms are NOT byte edges -- otherwise a `finish` arm would also be a
;; §16.2:908 violation and the cell would stop being about the join.
(define verdict-producers
  ;; name . (tier . nodes reached by an arm pointing at `name`)
  (list (cons 'finish        (cons 0 (lambda () (list (make-finish-node 'vf #f)))))
        (cons 'error         (cons 0 (lambda () (list (make-error-node 've 'rejected #f)))))
        (cons 'default-error (cons 0 (lambda () (list (make-byte-dispatch-node 'vd '()
                                                       (make-edge 'ee 'reexecute) #f #f)))))
        (cons 'stop          (cons 1 (lambda () (list (make-stop-node 'vs #f)))))
        (cons 'cycle         (cons 2 (lambda () (list (make-byte-dispatch-node 'vc '()
                                                       (make-edge 'ee 'reexecute) 'vc #f)))))))
(define (producer-node v)
  (case v ((finish) 'vf) ((error) 've) ((default-error) 'vd)
          ((stop) 'vs) ((cycle) 'vc)
          (else (assertion-violation 'producer-node "no such verdict" v))))
(define (producer-tier v) (car (cdr (assq v verdict-producers))))
(define (producer-nodes v) ((cdr (cdr (assq v verdict-producers)))))

(define (lattice-machine a b)
  (make-machine 'lat 's0 (list (make-uint-field 'n 8 0 #f)) (list cb-decl sd-decl) (list sp-decl)
                (list eof-decl rej-decl)
                (append (list (make-byte-dispatch-node 's0
                                (list (make-byte-case (make-exact-byte-matcher 0)
                                                      (make-edge 'ee 'advance) #f))
                                (make-edge 'ee 'reexecute) 'br #f)
                              (make-field-branch-node 'br 'zero '(n)
                                                      (producer-node a) (producer-node b) #f))
                        (producer-nodes a)
                        (if (eq? a b) '() (producer-nodes b))
                        (sinks))
                'default-eof #f))

(define (lattice-expect a b)
  (let ((t (max (producer-tier a) (producer-tier b))))
    (cond ((= t 2) '(eof-zero-progress-cycle))
          ((= t 1) '(eof-reachable-stop))
          (else '()))))

(harness-group "the EOF verdict join takes the higher tier (axis D)"
  (lambda ()
    (harness-case "all twenty-five sibling pairs match the tier derivation"
      (lambda ()
        (let ((driven 0) (bad '()) (vs '(finish error default-error stop cycle)))
          (for-each
           (lambda (a)
             (for-each
              (lambda (b)
                (set! driven (+ driven 1))
                (let ((want (lattice-expect a b))
                      (got (codes-of (lattice-machine a b))))
                  (unless (equal? want got)
                    (set! bad (cons (list a b 'want want 'got got) bad)))))
              vs))
           vs)
          (check-equal "twenty-five pairs driven" driven 25)
          (check-equal "and the join is the higher tier every time" bad '()))))))

(harness-finish)
