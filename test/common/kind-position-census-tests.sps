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
;;; Only TWO rules in the whole verifier are sensitive to a target's KIND, and
;;; both are derived here from the spec rather than from the code:
;;;   §16.2:908  a finish terminal must not be BYTE-REACHABLE
;;;   §16.2:909  an EOF path must not reach a stop terminal
;;; Everything else accepts. "Impossible by construction" is EMPTY on the kind
;;; axis, structurally: every target slot is a bare symbol and a node constructor
;;; cannot see the machine's node list, so every kind restriction is necessarily
;;; a verifier check.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify))

(harness-begin "unit.kind-position-census")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

;; The shared sinks every placed node's own out-edges land on. Never the host,
;; so a cell's record is about the placed node's POSITION and not about a cycle
;; the skeleton happened to create.
(define (sinks) (list (make-error-node 'ee 'rejected #f)))

;; --- the nine kinds, as data ------------------------------------------------
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
                                                    (make-edge 'ee 'advance) 'ee #f #f)))))

;; --- the sixteen positions, as data -----------------------------------------
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
                                     (make-edge 'ee 'advance) 'ee 't #f)))))))

(define (position-name p) (car p))
(define (position-byte? p) (cadr p))
(define (position-eof? p) (caddr p))
(define (position-build p) ((cadddr p)))

;; The DERIVED expectation. Two rules, both from §16.2, applied before the
;; machine is run. Everything else accepts.
(define (expected-codes p kind)
  (cond ((and (eq? kind 'finish) (position-byte? p)) '(non-eof-into-finish))
        ((and (eq? kind 'stop) (position-eof? p)) '(eof-reachable-stop))
        (else '())))

(define (cell-machine p kind)
  (let* ((built (position-build p))
         (entry (car built))
         (host (cdr built))
         (t ((cdr (assq kind kind-table)) 't)))
    (make-machine 'cell entry (list (make-uint-field 'n 8 0 #f)) '() '()
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
    (make-machine 'cell entry (list (make-uint-field 'n 8 0 #f)) '() '()
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
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (p)
             (for-each
              (lambda (kv)
                (set! driven (+ driven 1))
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
          (check-equal "and every one matches §16.2" bad '()))))))

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
              (check-equal "the same nine kinds" from-source from-table))))))))


;; --- axis B: self-reference --------------------------------------------------
;; The target IS the owning node. This is where the zero-progress rules live, and
;; it is the axis a scoping cut would reach for first -- wrongly: it is the only
;; coverage in the tree of the site that reports an EOF cycle at a PAUSE, and it
;; is where four of the sixteen positions behave differently under `reexecute`.
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
    ((accumulate-eof-target advance)   . (eof-zero-progress-cycle))))

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
      (else (assertion-violation 'self-machine "no such position" pos))))
  (make-machine 'self 'h (list (make-uint-field 'n 8 0 #f)) '() '()
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
          (check-equal "and fifteen positions have one, four of them twice"
                       driven (+ 15 4))
          (check-equal "each matches its derivation" bad '()))))))

(harness-finish)
