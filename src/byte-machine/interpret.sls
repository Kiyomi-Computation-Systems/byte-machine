;;; (byte-machine interpret): the reference interpreter — the semantic oracle.
;;; It turns a *verification* (which carries its machine, §9.2) into a
;;; runtime-compatible compiled-machine by closing an `op` over the verified IR.
;;; It refuses an unverified/failed machine (§16.1) and never touches the
;;; normalizer or generated code (§18). Error references are symbolic names,
;;; resolved here against the machine's error declarations.
(library (byte-machine interpret)
  (export make-interpreted-machine)
  (import (rnrs)
          (byte-machine private ir)
          (byte-machine private conditions)
          (byte-machine verify)
          (byte-machine runtime))

  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (lookup-error errors name)
    (cond ((null? errors) #f)
          ((eq? (error-declaration-name (car errors)) name) (car errors))
          (else (lookup-error (cdr errors) name))))

  (define (make-interpreted-machine verification)
    (unless (verification-ok? verification)
      (byte-machine-contract-violation 'make-interpreted-machine
                                       'unverified-machine
                                       (verification-diagnostics verification)))
    (let* ((m (verification-machine verification))
           (nodes (machine-nodes m))
           (errors (machine-errors m)))
      ;; `current` is either a declared node NAME or, inside a sequence, the
      ;; compound (name . path) where path is the byte list consumed so far.
      ;; The PATH -- not a bare position index -- is what keeps alternatives that
      ;; diverge at position 0 apart: with AB and XY, after consuming A a
      ;; position index would find Y at position 1 in SOME alternative and follow
      ;; XY. Derived independently of the normalizer (§18:970-972, decision 0015
      ;; point 3): this library imports no normalizer library and shares no
      ;; prefix walker with one. That independence is what lets the
      ;; interpreter≡generated differential catch a lowering defect at all, so a
      ;; proposal to factor "the shared prefix walker" into a common library is a
      ;; change to decision 0015, not a refactor.
      (define (prefix? p bs)
        (cond ((null? p) #t)
              ((null? bs) #f)
              ((= (car p) (car bs)) (prefix? (cdr p) (cdr bs)))
              (else #f)))
      (define (seq-step n path byte)
        (let* ((k (length path))
               (new (append path (list byte)))
               (hit (filter (lambda (c)
                              (let ((bs (sequence-case-bytes c)))
                                (and (> (length bs) k) (prefix? new bs))))
                            (sequence-dispatch-node-cases n)))
               (ends (filter (lambda (c) (= (length (sequence-case-bytes c)) (length new))) hit))
               (conts (filter (lambda (c) (> (length (sequence-case-bytes c)) (length new))) hit)))
          (cond ((null? hit)
                 ;; §10.6:546 -- already consumed prefix bytes remain consumed,
                 ;; and the declared mismatch edge decides whether the mismatching
                 ;; byte advances or is reexecuted.
                 (let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))
                ;; The same two internal invariants the normalizer's trie asserts,
                ;; for the same reason (decision 0015 point 2): a prefix position
                ;; that both accepts and continues has no representation here
                ;; either. Slice ③ rejects it as a diagnostic before this point.
                ((and (pair? ends) (pair? conts))
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))
                ((> (length ends) 1)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))
                ;; A successful alternative consumes every byte in it, so the last
                ;; step always advances into the declared target.
                ((pair? ends) (cons (sequence-case-target (car ends)) 'advance))
                (else (cons (cons (sequence-dispatch-node-name n) new) 'advance)))))
      (define (kind name)
        (if (pair? name)
            'dispatch                   ; mid-sequence: always reading a byte
            (let ((n (lookup nodes name)))
              (cond ((byte-dispatch-node? n) 'dispatch)
                    ((sequence-dispatch-node? n) 'dispatch)
                    ((stop-node? n) 'stop)
                    ((error-node? n) 'error)
                    ((finish-node? n) 'finish)
                    ((pause-node? n) 'pause)
                    (else (byte-machine-contract-violation 'interpret 'internal name))))))
      (define (dispatch name byte)
        (if (pair? name)
            (seq-step (lookup nodes (car name)) (cdr name) byte)
            (let ((n (lookup nodes name)))
              (if (sequence-dispatch-node? n)
                  (seq-step n '() byte)
                  (let loop ((cs (byte-dispatch-node-cases n)))
                    (cond ((null? cs)
                           (let ((e (byte-dispatch-node-fallback n)))
                             (cons (edge-target e) (edge-mode e))))
                          ((memv byte (matcher-bytes (byte-case-matcher (car cs))))
                           (let ((e (byte-case-edge (car cs))))
                             (cons (edge-target e) (edge-mode e))))
                          (else (loop (cdr cs)))))))))
      (define (error-value name)
        (error-declaration-code
         (lookup-error errors (error-node-error-name (lookup nodes name)))))
      (define (default-eof-value)
        (error-declaration-code (lookup-error errors (machine-default-eof-error m))))
      ;; Every lowered prefix state inherits the source node's EOF edge
      ;; (§12.4:727), so a compound current answers with its own node's.
      (define (eof-target-of cur)
        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))
          (if (sequence-dispatch-node? n)
              (sequence-dispatch-node-eof-target n)
              (byte-dispatch-node-eof-target n))))
      (make-compiled-machine
       (lambda (msg . args)
         (case msg
           ((entry) (machine-entry m))
           ((kind) (kind (car args)))
           ((dispatch) (dispatch (car args) (cadr args)))
           ((error-value) (error-value (car args)))
           ((eof-target) (eof-target-of (car args)))
           ((pause-target) (pause-node-continuation (lookup nodes (car args))))
           ((default-eof-value) (default-eof-value))
           (else (byte-machine-contract-violation 'interpret 'internal msg))))))))
