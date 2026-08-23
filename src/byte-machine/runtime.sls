;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile (parent §7.2). The interpreter (Task 5) and, later, generated code
;;; both produce a compiled-machine whose `op` closure answers the messages
;;; make-parser drives, so the two executors are identical by construction.
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
          make-parser parser?
          parser-feed!
          parser-result? parser-result-status parser-result-next
          parser-result-consumed parser-result-stream-offset parser-result-error
          callback-continue callback-pause)
  (import (rnrs))

  (define (tag sym) (vector sym))
  (define (tagged? t x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))

  ;; Allocation-free outcome singletons (parent §13). M1 exercises neither;
  ;; they fix the contract so interpreter and generated callbacks return the
  ;; same objects once callbacks land.
  (define callback-continue (vector 'byte-machine-callback-continue))
  (define callback-pause (vector 'byte-machine-callback-pause))

  ;; --- compiled machine (the ABI the executor implements) ---
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag op))
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-op cm) (vector-ref cm 1))

  ;; --- parser result (immutable snapshot) ---
  (define parser-result-tag (tag 'byte-machine-parser-result))
  (define (make-parser-result status next consumed stream-offset error)
    (vector parser-result-tag status next consumed stream-offset error))
  (define (parser-result? x) (tagged? parser-result-tag x))
  (define (parser-result-status r) (vector-ref r 1))
  (define (parser-result-next r) (vector-ref r 2))
  (define (parser-result-consumed r) (vector-ref r 3))
  (define (parser-result-stream-offset r) (vector-ref r 4))
  (define (parser-result-error r) (vector-ref r 5))

  ;; --- parser (mutable state behind procedures) ---
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (let ((op (compiled-machine-op compiled-machine)))
      (vector parser-tag op (op 'entry) 0 #f)))
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-op p) (vector-ref p 1))
  (define (parser-current p) (vector-ref p 2))
  (define (parser-set-current! p v) (vector-set! p 2 v))
  (define (parser-offset p) (vector-ref p 3))
  (define (parser-set-offset! p v) (vector-set! p 3 v))
  (define (parser-sticky p) (vector-ref p 4))
  (define (parser-set-sticky! p v) (vector-set! p 4 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (assertion-violation 'parser-feed! "invalid slice" (list start end)))
    (or (parser-sticky parser)
        (let ((op (parser-op parser)))
          (let loop ((pos start))
            (let ((node (parser-current parser)))
              (case (op 'kind node)
                ((stop)
                 (let ((r (make-parser-result 'stopped pos (- pos start)
                                              (parser-offset parser) #f)))
                   (parser-set-sticky! parser r) r))
                ((error)
                 (let ((r (make-parser-result 'error pos (- pos start)
                                              (parser-offset parser)
                                              (op 'error-value node))))
                   (parser-set-sticky! parser r) r))
                ((dispatch)
                 (if (>= pos end)
                     (make-parser-result 'need-input pos (- pos start)
                                         (parser-offset parser) #f)
                     (let* ((byte (bytevector-u8-ref bv pos))
                            (trans (op 'dispatch node byte))
                            (target (car trans))
                            (mode (cdr trans)))
                       (parser-set-current! parser target)
                       (if (eq? mode 'advance)
                           (begin
                             (parser-set-offset! parser (+ 1 (parser-offset parser)))
                             (loop (+ pos 1)))
                           (loop pos)))))
                (else (assertion-violation 'parser-feed! "unknown node kind"
                                           (op 'kind node))))))))))
