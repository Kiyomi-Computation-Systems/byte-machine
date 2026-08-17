;;; Content fingerprint for shared test bodies.
;;;
;;; A run reports the digest of the bodies it executed so that a stale
;;; artifact, a copied backend-specific variant, or a basename collision is
;;; detectable rather than merely unlikely. Chez and Gambit must report the
;;; same value for the same text; that agreement is the claim, and everything
;;; below is chosen to keep it from depending on anything unspecified.
;;;
;;; This is a change detector, not a cryptographic digest. It is a polynomial
;;; rolling hash modulo the Mersenne prime 2^61-1. Do not use it for anything
;;; security relevant.
;;;
;;; PORTABILITY CONTRACT
;;;
;;; Included verbatim by both adapters, like harness-runner.scm. Only the
;;; common R6RS/R7RS subset plus the adapter protocol. The arithmetic is
;;; deliberately not bitwise: neither standard's base library guarantees
;;; bitwise operations, and both guarantee exact integers of unbounded range,
;;; so arithmetic is the portable choice. Intermediate products exceed 64 bits,
;;; which is what makes exact bignums load-bearing rather than incidental.
;;;
;;; WHAT THIS CANNOT PROVE
;;;
;;; The manifest is declared, not observed. Scheme cannot portably report which
;;; files an `include` spliced in, so a matching fingerprint means the declared
;;; text is unchanged and both runtimes read it identically -- not that the run
;;; included exactly those files. See section 5.3 of the slice-5a design.

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

;; harness-fingerprint-file is not defined in this file, even though the
;; slice-5a Task 1 plan shows it here and Task 2 is written expecting it to
;; already exist. Reason, measured directly against this Chez 10.4.1: an
;; R6RS library body is elaborated as one unit, so a `define` anywhere in it
;; that references a free identifier bound nowhere in the library -- not
;; "not yet, by this point" but genuinely absent -- fails library
;; construction immediately, whether or not the identifier is exported and
;; whether or not anything calls the procedure that names it. (A forward
;; reference to a name defined *later in this same file* is fine, by
;; letrec*-like rules, exactly as the plan expected -- verified separately.
;; The difference is "bound later in this body" versus "bound nowhere in
;; it.") adapter-file-bytes is the second case until Task 2 defines it, so
;; the definition below would break every Chez lane that imports this
;; library -- bootstrap, duplicate-case, empty-selection, and so on, not
;; only the fingerprint self-tests. Gambit's source-mode loader does not
;; enforce the same simultaneity, so this asymmetry is invisible from the
;; Gambit side alone. Task 2, which supplies adapter-file-bytes, should add
;; here:
;;
;;   (define (harness-fingerprint-file path)
;;     (harness-fingerprint-bytevector (adapter-file-bytes path)))
;;
;; and add harness-fingerprint-file to both adapters' export lists at the
;; same time it adds adapter-file-bytes.

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
;; radix. Measured 2026-08-17: Chez yields "FF" and Gambit yields "ff" for
;; (number->string 255 16). Neither is wrong -- the standards do not fix the
;; case -- so a radix conversion would make the one claim this file exists to
;; establish depend on a detail these two runtimes already answer differently.
;; Comparing case-insensitively later would be worse: it would hide exactly the
;; class of divergence this file exists to expose.
(define harness-hex-digits "0123456789abcdef")

(define (harness-fingerprint->string h)
  (if (= h 0)
      "0"
      (let loop ((n h) (acc (list)))
        (if (= n 0)
            (list->string acc)
            (loop (quotient n 16)
                  (cons (string-ref harness-hex-digits (remainder n 16)) acc))))))
