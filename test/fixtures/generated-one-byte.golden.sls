(library (generated one-byte)
  (export one-byte-parser)
  (import (rnrs) (byte-machine runtime))
  (define errs (quote #(#(eof "unexpected end of input") #(unexpected-byte "unexpected byte"))))
  (define (exec state offset bv start end finish? fieldv)
    (let loop ((pos start) (st state) (off offset) (pk (quote boundary)))
      (case st
      ((0)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote start) 0 off (quote eof)) 0 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((0) (loop (+ pos 1) 1 (+ off 1) (quote boundary)))
               (else (loop pos 2 off (quote byte)))))))
      ((1) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 1) (quote reject) 2 off pk) 2 off))
      (else (assertion-violation (quote exec) "unknown state" st)))))
  (define one-byte-parser
    (byte-machine-make-compiled-machine 3 14095574568398596535 0 exec (quote #(#())))))
