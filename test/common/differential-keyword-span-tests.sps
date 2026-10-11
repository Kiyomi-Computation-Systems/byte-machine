;;; Span composition over a keyword table. A method span opened before the
;;; keyword table closes at the MATCHED keyword's length -- span[method]="MKCOL"
;;; from the six-byte input MKCOLA, and the whole "GET-PARAMETER" when the input
;;; reaches it. interpreter ≡ generated, with the delivered span DATA asserted
;;; ABSOLUTELY on the generated side (agreement alone cannot carry it).
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test keyword-span-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.keyword-span")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-keyword-span
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (frag bv from to)
  (let ((out (make-bytevector (- to from))))
    (let loop ((i from)) (if (>= i to) out
      (begin (bytevector-u8-set! out (- i from) (bytevector-u8-ref bv i)) (loop (+ i 1)))))))

;; Feed s on cm, capturing the delivered span data (as strings). Returns
;; (status consumed (span-fragment …)).
(define (run cm s)
  (let* ((trace '())
         (p (make-parser cm (list (list 'ondata
               (lambda (ps ux bv from to)
                 (set! trace (cons (utf8->string (frag bv from to)) trace))
                 callback-continue))) 'ctx))
         (bv (str->bv s))
         (r (parser-feed! p bv 0 (bytevector-length bv))))
    (list (parser-result-status r) (parser-result-consumed r) (reverse trace))))

(define ref (make-interpreted-machine (verify-machine (make-keyword-span-machine))))
(define gen (generated-machine 'kwspan (make-keyword-span-machine)))

;; --- the span closes at the matched keyword's length -------------------------
(harness-group "a span opened before a keyword table closes at the matched keyword length"
  (lambda ()
    (define cases
      ;; input . expected (status consumed (span))
      (list (cons "MKCOLA"         '(stopped 6 ("MKCOL")))
            (cons "GET-PARAMETER " '(stopped 14 ("GET-PARAMETER")))
            (cons "GET "           '(stopped 4 ("GET")))))
    (harness-case "the generated span data is the matched keyword and the interpreter agrees"
      (lambda ()
        (let ((bad 'none) (ran 0))
          (for-each
           (lambda (c)
             (set! ran (+ ran 1))
             (let ((g (run gen (car c))) (i (run ref (car c))))
               (when (eq? bad 'none)
                 (cond ((not (equal? g (cdr c))) (set! bad (list 'gen (car c) g)))
                       ((not (equal? i g)) (set! bad (list 'disagree (car c) i g)))))))
           cases)
          (check-equal "no case misbehaved" bad 'none)
          (check-equal "all three span cases ran" ran 3))))
    (harness-case "MKCOLA closes the method span at MKCOL (five bytes from six of input)"
      (lambda ()
        ;; the headline case, asserted on the generated side directly
        (check-equal "generated span is MKCOL" (caddr (run gen "MKCOLA")) '("MKCOL"))
        (check-equal "and the interpreter agrees" (caddr (run ref "MKCOLA")) '("MKCOL"))))))

(harness-finish)
