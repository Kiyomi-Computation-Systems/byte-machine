(library (generated pausem)
  (export pausem)
  (import (rnrs) (byte-machine runtime))
  (define errs (quote #(#(unexpected-byte "unexpected byte") #(truncated-input "truncated input"))))
  (define (exec state offset bv start end finish? fieldv psr cbv)
    (let loop ((pos start) (st state) (off offset) (pk (quote boundary)))
      (case st
      ((0)
       (if (>= pos end)
           (if finish?
               (loop pos 3 off (quote eof))
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((1) (loop (+ pos 1) 1 (+ off 1) (quote boundary)))
               (else (loop pos 7 off (quote byte)))))))
      ((1) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 2 off))
      ((2)
       (if (>= pos end)
           (if finish?
               (loop pos 6 off (quote eof))
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 2 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((2) (loop (+ pos 1) 4 (+ off 1) (quote boundary)))
               (else (loop pos 7 off (quote byte)))))))
      ((3) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 5 off))
      ((4) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 4 off))
      ((5) (byte-machine-make-feed-outcome/v1 (quote finished) pos #f 5 off))
      ((6) (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 1) (quote trunc) 6 off pk) 6 off))
      ((7) (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote reject) 7 off pk) 7 off))
      (else (assertion-violation (quote exec) "unknown state" st)))))
  (define pausem
    (byte-machine-make-compiled-machine 5 17903327606435836645 0 exec (quote #(#() #() #(s0 p1 s1 pe stop done trunc reject))))))
