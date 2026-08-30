;;; interpreter ≡ generated over a single-alternative SEQUENCE NODE (parent §18,
;;; §22.4, §22.5). This lane is the slice's independent oracle: the construct is
;;; new, but the expected behaviour is not. Milestone 2's sequence-machine.sls
;;; built the same four-byte accept from four CHAINED DISPATCH NODES, and the
;;; tuples below were measured against it before this node kind existed
;;; (test/common/differential-sequence-tests.sps).
;;;
;;; Agreement alone cannot carry the lane -- both executors read the same source
;;; IR -- so every group also asserts the GENERATED side absolutely.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test sequence-node-machine)
        (byte-machine test prng)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.sequence-node")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-sequence-node
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (parser-result-error r)))
(define (u8 b) (make-bytevector 1 b))
(define (u8v . bs) (u8-list->bytevector bs))
(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (run-slices cm slices)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss) last
          (loop (cdr ss)
                (rfields (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))))))))
(define (drive cm prefix b)
  (run-slices cm (append (map (lambda (x) (list (u8 x) 0 1)) prefix)
                         (list (list (u8 b) 0 1)))))
(define (schedule->string cuts)
  (string-append "("
                 (fold-left (lambda (acc c)
                              (string-append acc (if (string=? acc "") "" " ")
                                             (number->string c)))
                            "" cuts)
                 ")"))

(define seq-bytes (sequence-node-bytes))
(define seq-machine (make-sequence-node-machine))
(define adv-machine (make-advance-mismatch-machine))
(define cm-ref (make-interpreted-machine (verify-machine seq-machine)))
(define cm-gen (generated-machine 'seqnode seq-machine))
(define ad-ref (make-interpreted-machine (verify-machine adv-machine)))
(define ad-gen (generated-machine 'advseq adv-machine))

;; --- the Milestone 2 tuples, reproduced by a sequence node ---
(harness-group "the M2 chained-dispatch tuples are reproduced exactly"
  (lambda ()
    (harness-case "the full sequence in one slice stops after four bytes in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))
        (check-equal "generated" (run-slices cm-gen (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))))
    (harness-case "a wrong byte at each position errors at that between-byte offset in both"
      (lambda ()
        (let ((bad 'none) (positions 0))
          (for-each
           (lambda (k)
             (set! positions (+ positions 1))
             (let ((expect (list 'error 0 0 k 'unexpected-byte)))
               (unless (equal? (drive cm-ref (head-n seq-bytes k) 200) expect)
                 (when (eq? bad 'none) (set! bad (cons 'ref k))))
               (unless (equal? (drive cm-gen (head-n seq-bytes k) 200) expect)
                 (when (eq? bad 'none) (set! bad (cons 'gen k))))))
           '(0 1 2 3))
          (check-equal "no position misbehaved" bad 'none)
          (check-equal "the position loop ran all four" positions 4))))))

(harness-group "nonzero-offset slices report exact next / consumed / stream-offset"
  (lambda ()
    (define padded (u8v 9 1 2 3 4 9))
    (harness-case "one nonzero-offset slice accepts with exact fields in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))
        (check-equal "generated" (run-slices cm-gen (list (list padded 1 5)))
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

;; --- fragmentation (§22.5) ---
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

(harness-group "every fragmentation of the sequence reaches stopped in both lanes"
  (lambda ()
    (define all-cut-sets '(() (1) (2) (3) (1 2) (1 3) (2 3) (1 2 3)))
    (harness-case "each of the eight split sets stops at offset 4 in both"
      (lambda ()
        (let ((bad 'none) (sets 0))
          (for-each
           (lambda (cuts)
             (set! sets (+ sets 1))
             (let ((ri (run-slices cm-ref (slices-for cuts)))
                   (rg (run-slices cm-gen (slices-for cuts))))
               (unless (and (eq? (car ri) 'stopped) (= (cadddr ri) 4)
                            (eq? (car rg) 'stopped) (= (cadddr rg) 4)
                            (equal? ri rg))
                 (when (eq? bad 'none) (set! bad (schedule->string cuts))))))
           all-cut-sets)
          (check-equal "no split misbehaved" bad 'none)
          (check-equal "all eight cut-sets ran" sets 8))))
    (harness-case "leading / intermediate / trailing empty feeds still accept"
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
        (define seed 20260830)
        (let loop ((i 0) (s (make-prng seed)) (multi 0) (bad 'none))
          (if (>= i 32)
              (begin
                (check-equal "no schedule disagreed" bad 'none)
                ;; the case name promises multi-split: assert the seed actually
                ;; produced a draw with >= 2 cuts rather than assuming it.
                (check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0)))
              (let*-values (((d1 s1) (prng-next s 2))
                            ((d2 s2) (prng-next s1 2))
                            ((d3 s3) (prng-next s2 2)))
                (let* ((cuts (append (if (= d1 1) '(1) '())
                                     (if (= d2 1) '(2) '())
                                     (if (= d3 1) '(3) '())))
                       (ri (run-slices cm-ref (slices-for cuts)))
                       (rg (run-slices cm-gen (slices-for cuts))))
                  (loop (+ i 1) s3 (+ multi (if (>= (length cuts) 2) 1 0))
                        (if (and (eq? bad 'none)
                                 (or (not (equal? ri rg)) (not (eq? (car rg) 'stopped))))
                            (schedule->string cuts) bad))))))))))

(harness-group "interpreter and generated agree on all 256 bytes at every position"
  (lambda ()
    (harness-case "256 x 4 positions match, in both mismatch modes"
      (lambda ()
        (let ((bad 'none) (last-byte 'unset) (positions 0))
          (for-each
           (lambda (k)
             (set! positions (+ positions 1))
             (let ((prefix (head-n seq-bytes k)))
               (let loop ((b 0))
                 (when (< b 256)
                   (unless (equal? (drive cm-ref prefix b) (drive cm-gen prefix b))
                     (when (eq? bad 'none) (set! bad (list 'reexecute k b))))
                   (unless (equal? (drive ad-ref prefix b) (drive ad-gen prefix b))
                     (when (eq? bad 'none) (set! bad (list 'advance k b))))
                   (set! last-byte b)
                   (loop (+ b 1))))))
           '(0 1 2 3))
          (check-equal "no (mode position byte) disagreed" bad 'none)
          (check-equal "the byte loop ran all 256 values" last-byte 255)
          (check-equal "the position loop ran all four" positions 4))))))

;; §11.5:664 -- the advance path had no coverage anywhere in this tree before
;; Slice ②, and an advance-mode mismatch shifts every reported position by one.
;; Asserted absolutely on the GENERATED side, not only as agreement.
(harness-group "both mismatch modes, absolutely, on the generated executor"
  (lambda ()
    (harness-case "reexecute keeps next and consumed at zero"
      (lambda ()
        (check-equal "k=0" (drive cm-gen '() 200) '(error 0 0 0 unexpected-byte))
        (check-equal "k=3" (drive cm-gen '(1 2 3) 200) '(error 0 0 3 unexpected-byte))))
    (harness-case "advance consumes the offending byte and shifts the offset"
      (lambda ()
        (check-equal "k=0" (drive ad-gen '() 200) '(error 1 1 1 unexpected-byte))
        (check-equal "k=3" (drive ad-gen '(1 2 3) 200) '(error 1 1 4 unexpected-byte))))
    (harness-case "both modes accept the sequence identically"
      (lambda ()
        (check-equal "same accept"
                     (run-slices cm-gen (list (list (u8v 1 2 3 4) 0 4)))
                     (run-slices ad-gen (list (list (u8v 1 2 3 4) 0 4))))))))

(harness-finish)
