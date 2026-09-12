;;; Milestone 8 Slice ①: interpreter ≡ generated over the request line
;;; (§25:1648, "interpreter and generated traces match"). This is the lane every
;;; later slice extends; Slice ① drives the request-line grammar.
;;;
;;; Agreement alone cannot carry the lane — both executors read the same source
;;; IR (http-version-interpret-tests.sps's reason) — so the ABSOLUTE tuples and
;;; the absolute events live in http-request-line-tests.sps. Here the claim is
;;; that the two executors AGREE on the result tuple AND the event trace, for
;;; every feed schedule, well-formed and malformed, plus §22.5's split points:
;;; identical fragment boundaries for the same schedule (§22.5:1285), and the
;;; coalesced event skeleton invariant across schedules while the raw fragment
;;; trace is deliberately not (§22.5:1287).
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine test http-machine)
        (byte-machine test http-event-order)
        (byte-machine test prng)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.http")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-http "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (bytes s) (map char->integer (string->list s)))
(define (frag bv from to)
  (let loop ((i (- to 1)) (acc '()))
    (if (< i from) (list->string acc)
        (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc)))))
(define (recorder)
  (let ((tr '()))
    (define (ev name) (lambda (ps ux) (set! tr (cons name tr)) callback-continue))
    (define (dv name) (lambda (ps ux bv from to)
                        (set! tr (cons (list name (frag bv from to)) tr)) callback-continue))
    (cons (list (list 'message-begin (ev 'message-begin))
                (list 'method-data (dv 'method-data))
                (list 'method-complete (ev 'method-complete))
                (list 'target-data (dv 'target-data))
                (list 'target-complete (ev 'target-complete))
                (list 'version-complete (ev 'version-complete))
                ;; Slice ②: bind the header events so the trace comparison
                ;; between the executors covers them too.
                (list 'header-name-data (dv 'header-name-data))
                (list 'header-name-complete (ev 'header-name-complete))
                (list 'header-value-data (dv 'header-value-data))
                (list 'header-value-complete (ev 'header-value-complete))
                (list 'headers-complete (ev 'headers-complete))
                (list 'message-complete (ev 'message-complete)))
          (lambda () (reverse tr)))))

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (project-error (parser-result-error r))))

;; Feed a schedule (list of (bv start len)); optionally finish!. Return
;; (list result-tuple raw-trace).
(define (run cm slices finish?)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss)
          (let ((r (if finish? (parser-finish! p) last)))
            (list (rfields r) ((cdr rc))))
          (loop (cdr ss)
                (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss))))))))

(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (drop-n l k) (if (= k 0) l (drop-n (cdr l) (- k 1))))
(define (slices-for bs cuts)
  (let loop ((start 0) (cs (append cuts (list (length bs)))) (out '()))
    (if (null? cs) (reverse out)
        (let* ((end (car cs)) (run (head-n (drop-n bs start) (- end start))))
          (loop end (cdr cs)
                (cons (list (u8-list->bytevector run) 0 (length run)) out))))))
(define (schedule->string cuts)
  (string-append "(" (fold-left (lambda (a c) (string-append a (if (string=? a "") "" " ")
                                                             (number->string c))) "" cuts) ")"))

(define ref (make-interpreted-machine (verify-machine (make-http-machine))))
(define gen (generated-machine 'httpreq (make-http-machine)))
(define canon (bytes "GET /index HTTP/1.1\r\n\r\n"))   ; 23 bytes, a complete no-body message

(harness-group "the fixture verifies clean before it is driven (§22.6:1297)"
  (lambda ()
    (harness-case "no diagnostics"
      (lambda ()
        (check-equal "diagnostics"
                     (map (lambda (d) #t) (verification-diagnostics (verify-machine (make-http-machine))))
                     '())))))

(harness-group "interpreter and generated agree at every single-cut split of a no-body message"
  (lambda ()
    (harness-case "all interior cuts plus the uncut message agree on tuple AND trace, and reach idle"
      (lambda ()
        ;; Fed without finish!, a complete no-body message ends at idle
        ;; (message-complete looped back), so both executors return need-input.
        (let ((bad 'none) (compared 0) (idles 0))
          (let loop ((k 0))
            (when (<= k 23)
              (let* ((cuts (if (or (= k 0) (= k 23)) '() (list k)))
                     (ss (slices-for canon cuts))
                     (ri (run ref ss #f)) (rg (run gen ss #f)))
                (set! compared (+ compared 1))
                (unless (equal? ri rg)
                  (when (eq? bad 'none) (set! bad (list 'disagree k ri rg))))
                (when (and (equal? ri rg) (eq? (caar rg) 'need-input))
                  (set! idles (+ idles 1))))
              (loop (+ k 1))))
          (check-equal "nothing disagreed" bad 'none)
          (check-equal "24 iterations ran (k = 0..23)" compared 24)
          (check-equal "every run reached idle, observed from the executors" idles 24))))))

(harness-group "interpreter and generated agree on malformed request lines and their positions"
  (lambda ()
    (harness-case "each §21.4 request-line error agrees in category and absolute position across executors"
      (lambda ()
        (for-each
         (lambda (s)
           (let ((ri (run ref (slices-for (bytes s) '()) #f))
                 (rg (run gen (slices-for (bytes s) '()) #f)))
             (check-equal (string-append "agree: " s) ri rg)))
         (list "@" "GE@ x HTTP/1.1\r\n" "GET \x01;;" "GET /a\x01; HTTP/1.1\r\n"
               "GET /x XTTP/1.1\r\n" "GET /x HTTP/1.1X" "GET /x HTTP/1.1\rX"
               ;; Slice ②: header-region errors agree too.
               "GET / HTTP/1.1\r\n@bad\r\n" "GET / HTTP/1.1\r\nHost\r\n"
               "GET / HTTP/1.1\r\nHost: a\x01;b\r\n" "GET / HTTP/1.1\r\nHost: v\rX"
               "GET / HTTP/1.1\r\n\rX"))))))

(harness-group "interpreter and generated agree on messages with headers and on the loop"
  (lambda ()
    (harness-case "single- and multi-header messages, an all-OWS value, and two pipelined requests agree on tuple AND trace"
      (lambda ()
        (for-each
         (lambda (s)
           (let ((ri (run ref (slices-for (bytes s) '()) #t))
                 (rg (run gen (slices-for (bytes s) '()) #t)))
             (check-equal (string-append "finish-agree: " s) ri rg)))
         (list "GET / HTTP/1.0\r\n\r\n"
               "GET /index HTTP/1.1\r\nHost: example.com\r\nAccept: */*\r\n\r\n"
               "GET / HTTP/1.1\r\nX-Empty:  \r\n\r\n"
               "GET /a HTTP/1.1\r\n\r\nPOST /b HTTP/1.0\r\nH: v\r\n\r\n"))))
    (harness-case "every header split of a two-header message agrees on tuple AND trace"
      (lambda ()
        (let* ((m (bytes "GET / HTTP/1.1\r\nHost: x\r\nAccept: y\r\n\r\n"))
               (bad 'none))
          (let loop ((k 1))
            (when (< k (length m))
              (let ((ri (run ref (slices-for m (list k)) #t))
                    (rg (run gen (slices-for m (list k)) #t)))
                (unless (equal? ri rg)
                  (when (eq? bad 'none) (set! bad (list 'disagree k)))))
              (loop (+ k 1))))
          (check-equal "no header split disagreed" bad 'none))))))

(harness-group "interpreter and generated agree at end of stream (parser-finish!)"
  (lambda ()
    (harness-case "clean idle EOF and unexpected-eof from every non-idle region agree"
      (lambda ()
        (for-each
         (lambda (s)
           (let ((ri (run ref (slices-for (bytes s) '()) #t))
                 (rg (run gen (slices-for (bytes s) '()) #t)))
             (check-equal (string-append "finish agree: '" s "'") ri rg)))
         (list "" "GET" "GET " "GET /ind" "GET /ind " "GET /ind HTTP/1."
               "GET /ind HTTP/1.1" "GET /ind HTTP/1.1\r"))))))

(harness-group "seeded multi-split schedules agree on tuple and trace"
  (lambda ()
    (harness-case "32 draws over interior cuts agree, with at least one genuine multi-split"
      (lambda ()
        (define seed 20260912)
        (let loop ((i 0) (s (make-prng seed)) (multi 0) (bad 'none))
          (if (>= i 32)
              (begin
                (check-equal "no schedule disagreed" bad 'none)
                (check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0)))
              (let*-values (((d1 s1) (prng-next s 2)) ((d2 s2) (prng-next s1 2))
                            ((d3 s3) (prng-next s2 2)) ((d4 s4) (prng-next s3 2)))
                (let* ((cuts (append (if (= d1 1) '(3) '()) (if (= d2 1) '(11) '())
                                     (if (= d3 1) '(19) '()) (if (= d4 1) '(21) '())))
                       (ss (slices-for canon cuts))
                       (ri (run ref ss #f)) (rg (run gen ss #f)))
                  (loop (+ i 1) s4 (+ multi (if (>= (length cuts) 2) 1 0))
                        (if (and (eq? bad 'none) (not (equal? ri rg)))
                            (schedule->string cuts) bad))))))))))

(harness-group "across schedules: the event skeleton is invariant, the raw trace is not (§22.5:1287)"
  (lambda ()
    (harness-case "every split's coalesced skeleton equals the uncut one; raw fragment traces differ"
      (lambda ()
        (let* ((canon-sk (trace-skeleton (cadr (run gen (slices-for canon '()) #f))))
               (bad 'none) (raws '()))
          (let loop ((k 1))
            (when (<= k 22)
              (let* ((rg (run gen (slices-for canon (list k)) #f))
                     (sk (trace-skeleton (cadr rg))))
                (set! raws (cons (cadr rg) raws))
                (unless (equal? sk canon-sk)
                  (when (eq? bad 'none) (set! bad (list 'skeleton-differs k sk)))))
              (loop (+ k 1))))
          (check-equal "the coalesced skeleton is invariant across all splits" bad 'none)
          (check "the skeleton is a complete §21.3 no-body message"
                 (event-sequence-matches? http-request-grammar canon-sk))
          (check "the raw fragment trace is NOT invariant"
                 (> (length (let dedup ((xs raws) (seen '()))
                              (cond ((null? xs) seen)
                                    ((member (car xs) seen) (dedup (cdr xs) seen))
                                    (else (dedup (cdr xs) (cons (car xs) seen))))))
                    1)))))))

(harness-finish)
