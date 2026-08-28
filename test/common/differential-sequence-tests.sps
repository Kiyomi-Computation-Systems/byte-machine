;;; interpreter ≡ generated over the four-byte accept-sequence machine (parent
;;; §22.4, §22.7). Whole-input accept/reject, all 256 byte values at each of the
;;; four sequence positions, fragmentation schedules, and nonzero-offset slices.
;;; The generated library is emitted at run time, loaded, and compared
;;; field-for-field. This slice never re-feeds a terminal parser (the §12.2
;;; sticky-repeat path is Milestone 2 Slice ②).
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test sequence-machine)
        (byte-machine test prng)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.sequence")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-sequence "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/generated-sequence.sls"))

(define seq (make-sequence-machine))
(define cm-ref (make-interpreted-machine (verify-machine seq)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine seq '()) 'seq-parser p)))
(load genfile)
(define cm-gen (eval 'seq-parser (environment '(generated seq))))

;; --- helpers ---
(define (u8 b) (make-bytevector 1 b))
;; u8-list->bytevector is a standard (rnrs) procedure.
(define (u8v . bs) (u8-list->bytevector bs))
(define (list-head-n lst n)
  (if (= n 0) '() (cons (car lst) (list-head-n (cdr lst) (- n 1)))))
(define (schedule->string cuts)
  (string-append
   "("
   (fold-left (lambda (acc c)
                (string-append acc (if (string=? acc "") "" " ") (number->string c)))
              "" cuts)
   ")"))

;; Feed a list of (bv start end) slices through ONE fresh parser; return the
;; final parser-result as (status next consumed stream-offset error). Schedules
;; here never continue past a terminal.
(define (run-slices cm slices)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss) last
          (let ((r (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))))
            (loop (cdr ss)
                  (list (parser-result-status r) (parser-result-next r)
                        (parser-result-consumed r) (parser-result-stream-offset r)
                        (parser-result-error r))))))))

;; Feed each byte of `prefix` (as its own [0,1) slice) then the test byte `b`.
(define (drive cm prefix b)
  (run-slices cm (append (map (lambda (x) (list (u8 x) 0 1)) prefix)
                         (list (list (u8 b) 0 1)))))

;; --- Task 1: whole-input + all-256-per-position ---
(harness-group "whole-input accept and per-position reject agree in both lanes"
  (lambda ()
    (harness-case "the full sequence 1 2 3 4 stops after four bytes in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))
        (check-equal "generated"   (run-slices cm-gen (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))))
    (harness-case "a wrong byte at each position errors at that between-byte offset in both"
      (lambda ()
        (for-each
         (lambda (k)
           (let ((prefix (list-head-n sequence-bytes k))
                 (expect (list 'error 0 0 k 'unexpected-byte)))
             (check-equal (string-append "interpreter pos " (number->string k))
                          (drive cm-ref prefix 200) expect)
             (check-equal (string-append "generated pos " (number->string k))
                          (drive cm-gen prefix 200) expect)))
         '(0 1 2 3))))))

(harness-group "interpreter and generated agree on all 256 bytes at every position"
  (lambda ()
    (harness-case "256 x 4 positions match"
      (lambda ()
        (let ((bad 'none))
          (for-each
           (lambda (k)
             (let ((prefix (list-head-n sequence-bytes k)))
               (let loop ((b 0))
                 (when (< b 256)
                   (unless (equal? (drive cm-ref prefix b) (drive cm-gen prefix b))
                     (when (eq? bad 'none) (set! bad (cons k b))))
                   (loop (+ b 1))))))
           '(0 1 2 3))
          (check-equal "no (position . byte) disagreed" bad 'none))))))

;; --- Task 2: fragmentation ---
(define seq-input (u8v 1 2 3 4))
(define (slices-for cuts)
  (let ((bounds (append '(0) cuts '(4))))
    (let loop ((bs bounds) (acc '()))
      (if (null? (cdr bs)) (reverse acc)
          (loop (cdr bs) (cons (list seq-input (car bs) (cadr bs)) acc))))))
(define (with-empties slices)
  (define e (list seq-input 0 0))
  (let loop ((ss slices) (acc (list e)))
    (cond ((null? ss) (reverse acc))
          ((null? (cdr ss)) (loop '() (cons (car ss) (cons e acc))))
          (else (loop (cdr ss) (cons e (cons (car ss) acc)))))))

(harness-group "every fragmentation of 1 2 3 4 reaches stopped in both lanes"
  (lambda ()
    (define all-cut-sets '(() (1) (2) (3) (1 2) (1 3) (2 3) (1 2 3)))
    (harness-case "each split (and each split-point pair) stops at offset 4"
      (lambda ()
        (for-each
         (lambda (cuts)
           (let ((ri (run-slices cm-ref (slices-for cuts)))
                 (rg (run-slices cm-gen (slices-for cuts))))
             (check-equal (string-append "interpreter cuts " (schedule->string cuts))
                          (car ri) 'stopped)
             (check-equal (string-append "generated cuts " (schedule->string cuts))
                          (car rg) 'stopped)
             (check-equal (string-append "interpreter stream-offset " (schedule->string cuts))
                          (cadddr ri) 4)
             (check-equal (string-append "generated stream-offset " (schedule->string cuts))
                          (cadddr rg) 4)))
         all-cut-sets)))
    (harness-case "interpreter and generated agree on every fragmentation"
      (lambda ()
        (let ((bad 'none))
          (for-each
           (lambda (cuts)
             (unless (equal? (run-slices cm-ref (slices-for cuts))
                             (run-slices cm-gen (slices-for cuts)))
               (when (eq? bad 'none) (set! bad cuts))))
           all-cut-sets)
          (check-equal "no split disagreed" bad 'none))))
    (harness-case "leading / intermediate / trailing-before-completion empty feeds still accept"
      (lambda ()
        (check-equal "interpreter with empties"
                     (car (run-slices cm-ref (with-empties (slices-for '(1 2 3))))) 'stopped)
        (check-equal "generated with empties"
                     (car (run-slices cm-gen (with-empties (slices-for '(1 2 3))))) 'stopped)
        (check-equal "empties do not change agreement"
                     (run-slices cm-ref (with-empties (slices-for '(1 2 3))))
                     (run-slices cm-gen (with-empties (slices-for '(1 2 3)))))))
    (harness-case "a deterministic random multi-split schedule accepts and agrees"
      (lambda ()
        (define seed 20260828)
        (let loop ((i 0) (s (make-prng seed)) (multi 0))
          (if (>= i 32)
              ;; the case name promises multi-split; assert the seed actually
              ;; produced at least one draw with >= 2 cuts rather than assuming it.
              (check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0))
              (let*-values (((d1 s1) (prng-next s 2))
                            ((d2 s2) (prng-next s1 2))
                            ((d3 s3) (prng-next s2 2)))
                (let ((cuts (append (if (= d1 1) '(1) '())
                                    (if (= d2 1) '(2) '())
                                    (if (= d3 1) '(3) '()))))
                  (check-equal (string-append "schedule " (number->string i)
                                              " (seed " (number->string seed) ")")
                               (run-slices cm-ref (slices-for cuts))
                               (run-slices cm-gen (slices-for cuts)))
                  (check-equal (string-append "schedule " (number->string i) " stops")
                               (car (run-slices cm-gen (slices-for cuts))) 'stopped)
                  (loop (+ i 1) s3 (+ multi (if (>= (length cuts) 2) 1 0)))))))))))

;; --- Task 3: nonzero-offset slices ---
(harness-group "nonzero-offset slices report exact next / consumed / stream-offset"
  (lambda ()
    (define padded (u8v 9 1 2 3 4 9))
    (harness-case "one nonzero-offset slice [1,5) accepts with exact fields in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))
        (check-equal "generated"   (run-slices cm-gen (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))))
    (harness-case "a nonzero-offset slice split mid-sequence resumes with exact fields"
      (lambda ()
        (check-equal "interpreter"
                     (run-slices cm-ref (list (list padded 1 3) (list padded 3 5)))
                     '(stopped 5 2 4 #f))
        (check-equal "generated"
                     (run-slices cm-gen (list (list padded 1 3) (list padded 3 5)))
                     '(stopped 5 2 4 #f))))
    (harness-case "an empty nonzero-offset slice consumes nothing and needs input"
      (lambda ()
        (check-equal "interpreter"
                     (run-slices cm-ref (list (list padded 1 3) (list padded 3 3)))
                     '(need-input 3 0 2 #f))
        (check-equal "generated"
                     (run-slices cm-gen (list (list padded 1 3) (list padded 3 3)))
                     '(need-input 3 0 2 #f))))))

(harness-finish)
