(library (generated http-version)
  (export http-version-parser)
  (import (rnrs) (byte-machine runtime))
  (define (exec state offset bv start end finish? fieldv)
    (let loop ((pos start) (st state) (off offset))
      (case st
      ((0)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 0 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((72) (loop (+ pos 1) 4 (+ off 1)))
               (else (loop pos 3 off))))))
      ((1) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f 2 off))
      ((3) (byte-machine-make-feed-outcome/v1 (quote error) pos (quote unexpected-byte) 3 off))
      ((4)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 4 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 4 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((84) (loop (+ pos 1) 5 (+ off 1)))
               (else (loop pos 3 off))))))
      ((5)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 5 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 5 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((84) (loop (+ pos 1) 6 (+ off 1)))
               (else (loop pos 3 off))))))
      ((6)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 6 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 6 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((80) (loop (+ pos 1) 7 (+ off 1)))
               (else (loop pos 3 off))))))
      ((7)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 7 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 7 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((47) (loop (+ pos 1) 8 (+ off 1)))
               (else (loop pos 3 off))))))
      ((8)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 8 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 8 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((49) (loop (+ pos 1) 9 (+ off 1)))
               (else (loop pos 3 off))))))
      ((9)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 9 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 9 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((46) (loop (+ pos 1) 10 (+ off 1)))
               (else (loop pos 3 off))))))
      ((10)
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 (quote error) pos (quote eof) 10 off)
               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 10 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (case b
               ((48) (loop (+ pos 1) 1 (+ off 1)))
               ((49) (loop (+ pos 1) 2 (+ off 1)))
               (else (loop pos 3 off))))))
      (else (assertion-violation (quote exec) "unknown state" st)))))
  (define http-version-parser
    (byte-machine-make-compiled-machine 3 16999772257989587335 0 exec (quote #(#())))))
