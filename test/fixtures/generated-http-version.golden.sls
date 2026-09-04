(library (generated http-version)
  (export http-version-parser)
  (import (rnrs) (byte-machine runtime))
  (define errs (quote #(#(eof "unexpected end of input") #(unexpected-byte "unexpected byte"))))
  (define (exec state offset bv start end finish? fieldv psr cbv)
    (let loop ((pos start) (st state) (off offset) (pk (quote boundary)))
      (case st
      ((0)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 0 off (quote eof)) 0 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((72) (loop (+ pos 1) 4 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((1) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 2 off))
      ((3) (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 1) (quote reject) 3 off pk) 3 off))
      ((4)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 4 off (quote eof)) 4 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 4 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((84) (loop (+ pos 1) 5 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((5)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 5 off (quote eof)) 5 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 5 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((84) (loop (+ pos 1) 6 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((6)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 6 off (quote eof)) 6 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 6 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((80) (loop (+ pos 1) 7 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((7)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 7 off (quote eof)) 7 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 7 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((47) (loop (+ pos 1) 8 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((8)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 8 off (quote eof)) 8 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 8 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((49) (loop (+ pos 1) 9 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((9)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 9 off (quote eof)) 9 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 9 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((46) (loop (+ pos 1) 10 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      ((10)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (byte-machine-make-parser-error/v1 (vector-ref errs 0) (quote ver) 10 off (quote eof)) 10 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 10 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((48) (loop (+ pos 1) 1 (+ off 1) (quote boundary)))
               ((49) (loop (+ pos 1) 2 (+ off 1) (quote boundary)))
               (else (loop pos 3 off (quote byte)))))))
      (else (assertion-violation (quote exec) "unknown state" st)))))
  (define http-version-parser
    (byte-machine-make-compiled-machine 4 16999772257989587335 0 exec (quote #(#() #())))))
