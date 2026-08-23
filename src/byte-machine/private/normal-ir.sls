;;; (byte-machine private normal-ir): the normalizer (parent §17). Lowers a
;;; VERIFIED source machine to a canonical normalized IR in deterministic order
;;; — nodes numbered by declaration order, dispatch cases sorted ascending by
;;; byte, error references resolved to their codes — and computes the IR
;;; fingerprint (decision 0009): 64-bit FNV-1a over a canonical byte encoding of
;;; the normalized IR. Pure; runs only after verification (parent §16.3).
(library (byte-machine private normal-ir)
  (export normalize-machine
          normal-machine? normal-machine-entry normal-machine-states
          normal-machine-fingerprint
          normal-state-kind normal-state-id
          normal-dispatch-transitions normal-dispatch-fallback
          normal-error-code)
  (import (rnrs)
          (only (byte-machine private ir)
                machine-nodes machine-entry machine-errors
                byte-dispatch-node? byte-dispatch-node-cases byte-dispatch-node-fallback
                byte-case-matcher byte-case-edge exact-byte-matcher-byte
                edge-target edge-mode stop-node? error-node? error-node-error-name
                error-declaration-name error-declaration-code node-name))

  (define nm-tag (vector 'byte-machine-normal-machine))
  (define (make-normal-machine entry states fp) (vector nm-tag entry states fp))
  (define (normal-machine? x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) nm-tag)))
  (define (normal-machine-entry m) (vector-ref m 1))
  (define (normal-machine-states m) (vector-ref m 2))
  (define (normal-machine-fingerprint m) (vector-ref m 3))

  (define ns-tag (vector 'byte-machine-normal-state))
  ;; (vector ns-tag kind id transitions fallback code) ; unused slots #f
  (define (normal-state-kind s) (vector-ref s 1))
  (define (normal-state-id s) (vector-ref s 2))
  (define (normal-dispatch-transitions s) (vector-ref s 3))
  (define (normal-dispatch-fallback s) (vector-ref s 4))
  (define (normal-error-code s) (vector-ref s 5))

  ;; --- FNV-1a 64-bit over a canonical byte encoding (decision 0009) ---
  (define mask64 (- (expt 2 64) 1))
  (define fnv-offset 14695981039346656037)
  (define fnv-prime  1099511628211)
  (define (fnv1a-64 bv)
    (let loop ((i 0) (h fnv-offset))
      (if (= i (bytevector-length bv)) h
          (loop (+ i 1)
                (bitwise-and mask64 (* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime))))))

  (define (put-u16be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  (define (put-u32be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 24)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 16)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  (define (put-symbol p sym)
    (let ((b (string->utf8 (symbol->string sym))))
      (put-u16be p (bytevector-length b)) (put-bytevector p b)))
  (define (mode->byte m) (if (eq? m 'advance) 0 1))

  (define (normalize-machine machine)
    (let* ((nodes (machine-nodes machine))
           (name->id (let loop ((ns nodes) (i 0) (acc '()))
                       (if (null? ns) (reverse acc)
                           (loop (cdr ns) (+ i 1) (cons (cons (node-name (car ns)) i) acc)))))
           (id-of (lambda (nm) (cdr (assq nm name->id))))
           (errcode (lambda (nm)
                      (let loop ((es (machine-errors machine)))
                        (if (eq? (error-declaration-name (car es)) nm)
                            (error-declaration-code (car es)) (loop (cdr es))))))
           (entry (id-of (machine-entry machine)))
           (states (list->vector
                    (let loop ((ns nodes) (i 0) (acc '()))
                      (if (null? ns) (reverse acc)
                          (let ((n (car ns)))
                            (loop (cdr ns) (+ i 1)
                                  (cons
                                   (cond
                                     ((byte-dispatch-node? n)
                                      (let ((trs (list-sort (lambda (a b) (< (car a) (car b)))
                                                   (map (lambda (c)
                                                          (let ((b (exact-byte-matcher-byte (byte-case-matcher c)))
                                                                (e (byte-case-edge c)))
                                                            (list b (id-of (edge-target e)) (edge-mode e))))
                                                        (byte-dispatch-node-cases n))))
                                            (fb (byte-dispatch-node-fallback n)))
                                        (vector ns-tag 'dispatch i trs
                                                (cons (id-of (edge-target fb)) (edge-mode fb)) #f)))
                                     ((stop-node? n) (vector ns-tag 'stop i #f #f #f))
                                     ((error-node? n) (vector ns-tag 'error i #f #f (errcode (error-node-error-name n)))))
                                   acc))))))))
      (let ((fp (fnv1a-64
                 (call-with-bytevector-output-port
                  (lambda (p)
                    (put-u8 p 1)
                    (put-u32be p entry)
                    (put-u32be p (vector-length states))
                    (let loop ((i 0))
                      (when (< i (vector-length states))
                        (let ((s (vector-ref states i)))
                          (case (normal-state-kind s)
                            ((dispatch)
                             (put-u8 p 0)
                             (let ((trs (normal-dispatch-transitions s)))
                               (put-u16be p (length trs))
                               (for-each (lambda (tr)
                                           (put-u8 p (car tr)) (put-u32be p (cadr tr))
                                           (put-u8 p (mode->byte (caddr tr)))) trs))
                             (let ((fb (normal-dispatch-fallback s)))
                               (put-u32be p (car fb)) (put-u8 p (mode->byte (cdr fb)))))
                            ((stop) (put-u8 p 1))
                            ((error) (put-u8 p 2) (put-symbol p (normal-error-code s)))))
                        (loop (+ i 1)))))))))
        (make-normal-machine entry states fp)))))
