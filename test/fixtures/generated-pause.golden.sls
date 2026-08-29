(library (generated pausem)
  (export pausem)
  (import (rnrs) (byte-machine runtime))
  (define (exec state offset bv start end finish?)
    (let loop ((pos start) (st state) (off offset))
      (case st
      ((0)
       (if (>= pos end)
           (if finish?
               (loop pos 3 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((1) (loop (+ pos 1) 1 (+ off 1)))
               (else (loop pos 7 off))))))
      ((1) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 2 off))
      ((2)
       (if (>= pos end)
           (if finish?
               (loop pos 6 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 2 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((2) (loop (+ pos 1) 4 (+ off 1)))
               (else (loop pos 7 off))))))
      ((3) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 5 off))
      ((4) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 4 off))
      ((5) (byte-machine-make-feed-outcome/v1 (quote finished) pos #f 5 off))
      ((6) (byte-machine-make-feed-outcome/v1 (quote error) pos (quote truncated-input) 6 off))
      ((7) (byte-machine-make-feed-outcome/v1 (quote error) pos (quote unexpected-byte) 7 off))
      (else (assertion-violation (quote exec) "unknown state" st)))))
  (define pausem
    (byte-machine-make-compiled-machine/v2 2 15725897457025557005 0 exec)))
