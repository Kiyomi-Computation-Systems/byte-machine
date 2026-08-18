;;; Content fingerprint for shared test bodies.
;;;
;;; A run reports the digest of the bodies it executed so that a stale
;;; artifact, a copied backend-specific variant, or a basename collision is
;;; detectable rather than merely unlikely. Every runtime must report the same
;;; value for the same text; that agreement is the claim, and everything below
;;; is chosen to keep it from depending on anything unspecified.
;;;
;;; This is a change detector, not a cryptographic digest. It is a polynomial
;;; rolling hash modulo the Mersenne prime 2^61-1. Do not use it for anything
;;; security relevant.
;;;
;;; SHARED BODY CONTRACT
;;;
;;; Included verbatim by the Chez adapter, like harness-runner.scm, through the
;;; same source-directories include -- plain R6RS plus the adapter protocol,
;;; no library or include form of its own. The arithmetic is deliberately not
;;; bitwise -- not because bitwise operations are unavailable (R6RS's `(rnrs)`
;;; composite guarantees them the same as everything else the owner library
;;; imports), but because the algorithm needs nothing beyond exact integers of
;;; unbounded range, which plain R6RS also guarantees. Intermediate products
;;; exceed 64 bits, which is what makes exact bignums load-bearing rather than
;;; incidental.
;;;
;;; WHAT THIS CANNOT PROVE
;;;
;;; The manifest is declared, not observed. Scheme cannot portably report which
;;; files an `include` spliced in, so a matching fingerprint means the declared
;;; text is unchanged -- not that the run included exactly those files. See
;;; section 5.3 of the slice-5a design.

(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1
(define harness-fingerprint-multiplier 1000003)
(define harness-fingerprint-seed 14695981039346656)

;; Fold one byte at a time. The +1 keeps leading zero bytes significant: without
;; it a NUL contributes nothing and two files differing only by a run of leading
;; NULs fingerprint identically.
(define (harness-fingerprint-bytevector bv)
  (let ((n (bytevector-length bv)))
    (let loop ((i 0)
               (h (modulo harness-fingerprint-seed harness-fingerprint-modulus)))
      (if (= i n)
          h
          (loop (+ i 1)
                (modulo (+ (* h harness-fingerprint-multiplier)
                           (+ (bytevector-u8-ref bv i) 1))
                        harness-fingerprint-modulus))))))

;; Fingerprints a file's exact bytes, read through adapter-file-bytes (binary
;; -- see the Chez adapter's definition) and folded through
;; harness-fingerprint-bytevector, so the same file fingerprints identically
;; on every run. The adapter-file-bytes dependency is structural, not stylistic:
;; R6RS requires every free identifier in a library body to be bound, so this
;; procedure cannot be separated from whatever defines adapter-file-bytes
;; without failing Chez library construction immediately, whether or not it
;; is exported or ever called.
(define (harness-fingerprint-file path)
  (harness-fingerprint-bytevector (adapter-file-bytes path)))

;; Combine per-file fingerprints in the order given. Order is significant, so a
;; reordered manifest is a different combined value: the result identifies a
;; sequence of bodies, not a set of them.
(define (harness-fingerprint-combine fingerprints)
  (let loop ((rest fingerprints)
             (h (modulo harness-fingerprint-seed harness-fingerprint-modulus)))
    (if (null? rest)
        h
        (loop (cdr rest)
              (modulo (+ (* h harness-fingerprint-multiplier) (+ (car rest) 1))
                      harness-fingerprint-modulus)))))

;; Lowercase hex from an explicit digit table, never number->string with a
;; radix. Measured 2026-08-17: Chez yields "FF" for (number->string 255 16).
;; That is not wrong -- the standards do not fix the case -- so a radix
;; conversion would make the one claim this file exists to establish depend on
;; a detail an implementation is free to answer differently. Comparing
;; case-insensitively later would be worse: it would hide exactly the class of
;; divergence this file exists to expose.
(define harness-hex-digits "0123456789abcdef")

(define (harness-fingerprint->string h)
  (if (= h 0)
      "0"
      (let loop ((n h) (acc (list)))
        (if (= n 0)
            (list->string acc)
            (loop (quotient n 16)
                  (cons (string-ref harness-hex-digits (remainder n 16)) acc))))))
