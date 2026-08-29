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
      (define (kind name)
        (let ((n (lookup nodes name)))
          (cond ((byte-dispatch-node? n) 'dispatch)
                ((stop-node? n) 'stop)
                ((error-node? n) 'error)
                ((finish-node? n) 'finish)
                ((pause-node? n) 'pause)
                (else (byte-machine-contract-violation 'interpret 'internal name)))))
      (define (dispatch name byte)
        (let ((n (lookup nodes name)))
          (let loop ((cs (byte-dispatch-node-cases n)))
            (cond ((null? cs)
                   (let ((e (byte-dispatch-node-fallback n)))
                     (cons (edge-target e) (edge-mode e))))
                  ((memv byte (matcher-bytes (byte-case-matcher (car cs))))
                   (let ((e (byte-case-edge (car cs))))
                     (cons (edge-target e) (edge-mode e))))
                  (else (loop (cdr cs)))))))
      (define (error-value name)
        (error-declaration-code
         (lookup-error errors (error-node-error-name (lookup nodes name)))))
      (define (default-eof-value)
        (error-declaration-code (lookup-error errors (machine-default-eof-error m))))
      (make-compiled-machine
       (lambda (msg . args)
         (case msg
           ((entry) (machine-entry m))
           ((kind) (kind (car args)))
           ((dispatch) (dispatch (car args) (cadr args)))
           ((error-value) (error-value (car args)))
           ((eof-target) (byte-dispatch-node-eof-target (lookup nodes (car args))))
           ((pause-target) (pause-node-continuation (lookup nodes (car args))))
           ((default-eof-value) (default-eof-value))
           (else (byte-machine-contract-violation 'interpret 'internal msg))))))))
