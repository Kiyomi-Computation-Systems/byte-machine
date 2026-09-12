;;; Milestone 8 Slice ③: framing recognition and the fixed body (§25:1637-1638),
;;; through the reference interpreter with ABSOLUTE outcomes. This is the slice
;;; decision 0035/§4.2 exists for: case-insensitive Content-Length /
;;; Transfer-Encoding recognition that keeps the opaque path's bytes, checked
;;; Content-Length accumulation, the counted fixed body, and the framing refusals
;;; at the boundary after the later header line's LF. Agreement between the
;;; executors is differential-http-tests.sps's.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine test http-event-order)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-framing")

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
    (cons (map (lambda (p) (list (car p) ((cdr p) (car p))))
               (list (cons 'message-begin ev) (cons 'method-data dv) (cons 'method-complete ev)
                     (cons 'target-data dv) (cons 'target-complete ev) (cons 'version-complete ev)
                     (cons 'header-name-data dv) (cons 'header-name-complete ev)
                     (cons 'header-value-data dv) (cons 'header-value-complete ev)
                     (cons 'headers-complete ev) (cons 'message-complete ev) (cons 'body-data dv)))
          (lambda () (reverse tr)))))
(define cm (make-interpreted-machine (verify-machine (make-http-machine))))
(define (err-triple r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e)
         (list (parser-error-code e) (parser-error-position-kind e) (parser-error-offset e)))))
(define (feed-finish s)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)) (bv (u8-list->bytevector (bytes s))))
    (parser-feed! p bv 0 (bytevector-length bv))
    (let ((r (parser-finish! p)))
      (list (parser-result-status r) (parser-result-stream-offset r) (err-triple r) ((cdr rc))))))
(define (err s) (caddr (feed-finish s)))
(define (status s) (car (feed-finish s)))
(define (trace-of s) (cadddr (feed-finish s)))
(define (has-entry? e tr) (and (member e tr) #t))
(define (rl s) (string-append "GET / HTTP/1.1\r\n" s))   ; a valid request line prefix

;; --- the recognizer: hit/miss, and the name delivered on both paths (§4.2) ----

(harness-group "case-insensitive framing recognition keeps the opaque path's bytes (decision 0035)"
  (lambda ()
    ;; A recognized Content-Length with a value of 5 expects a 5-octet body, so a
    ;; body-less feed truncates as unexpected-eof; an unrecognized (opaque) name
    ;; has an empty body and finishes. That is the hit/miss discriminator.
    (harness-case "canonical, lowercase and mixed case all HIT; prefix, extension and near-miss MISS"
      (lambda ()
        (for-each
         (lambda (name)
           (check-equal (string-append "hit: " name)
                        (status (rl (string-append name ": 5\r\n\r\n"))) 'error))
         '("Content-Length" "content-length" "CoNtEnT-lEnGtH"))
        (for-each
         (lambda (name)
           (check-equal (string-append "miss: " name)
                        (status (rl (string-append name ": 5\r\n\r\n"))) 'finished))
         '("Content-Leng" "Content-Lengthy" "Content_Length"))))
    (harness-case "every name — recognized or opaque — delivers its whole self as header-name-data"
      (lambda ()
        (for-each
         (lambda (name)
           (check (string-append name " delivered whole")
                  (has-entry? (list 'header-name-data name)
                              (trace-of (rl (string-append name ": 5\r\n\r\nHELLO"))))))
         '("Content-Length" "content-length" "Content-Lengthy" "Conx" "Content_Length"))))
    (harness-case "Transfer-Encoding is recognized: a non-chunked value is unsupported"
      (lambda ()
        ;; A recognized `chunked` reaches the chunked body (Slice ④'s), which a
        ;; body-less feed truncates as unexpected-eof — proving it was recognized
        ;; (reached the body path) rather than rejected as unsupported.
        (check-equal "chunked is recognized (reaches the chunked body, truncated here)"
                     (let ((e (err (rl "Transfer-Encoding: chunked\r\n\r\n")))) (and e (car e)))
                     'unexpected-eof)
        (check-equal "gzip is unsupported-transfer-encoding"
                     (err (rl "Transfer-Encoding: gzip\r\n\r\n")) '(unsupported-transfer-encoding byte 35))))))

;; --- Content-Length's value and the fixed body (§21.3:1145) -------------------

(harness-group "checked Content-Length and the counted fixed body"
  (lambda ()
    (harness-case "the value is delivered as header-value-data AND drives a fixed body of that length"
      (lambda ()
        (let ((r (feed-finish "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\nHELLO")))
          (check-equal "finished" (car r) 'finished)
          (check-equal "the full trace: the value span, then one body span, no body-complete"
                       (cadddr r)
                       '(message-begin (method-data "POST") method-complete
                         (target-data "/x") target-complete version-complete
                         (header-name-data "Content-Length") header-name-complete
                         (header-value-data "5") header-value-complete
                         headers-complete (body-data "HELLO") message-complete))
          (check "the skeleton matches the event grammar"
                 (event-sequence-matches? http-request-grammar (trace-skeleton (cadddr r)))))))
    (harness-case "Content-Length: 0 is an empty body — no body-data, straight to completion"
      (lambda ()
        (let ((tr (trace-of "GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n")))
          (check "no body-data" (not (has-entry? '(body-data "") tr)))
          (check "message-complete fires" (has-entry? 'message-complete tr)))))
    (harness-case "invalid and overflowing Content-Length reject at the offending byte (§12.7:773)"
      (lambda ()
        (check-equal "a non-digit value is invalid-content-length"
                     (err (rl "Content-Length: abc\r\n\r\n")) '(invalid-content-length byte 32))
        (check-equal "a value past u64 overflows at the offending digit"
                     (err (rl "Content-Length: 99999999999999999999999999\r\n\r\n"))
                     '(content-length-overflow byte 51))))))

;; --- the framing refusals, at the boundary after the later line's LF (P2) -----

(harness-group "framing refusals at the between-byte boundary (§21.4:1175, decision 0035)"
  (lambda ()
    (harness-case "a second Content-Length is a duplicate at the boundary"
      (lambda ()
        (check-equal "duplicate-content-length"
                     (err "GET / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n")
                     '(duplicate-content-length boundary 54))))
    (harness-case "a second Transfer-Encoding is a duplicate at the boundary"
      (lambda ()
        (check-equal "duplicate-transfer-encoding"
                     (err "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n\r\n")
                     '(duplicate-transfer-encoding boundary 72))))
    (harness-case "both framing headers conflict, in either order, at the later line's boundary"
      (lambda ()
        (check-equal "Content-Length then Transfer-Encoding"
                     (err "GET / HTTP/1.1\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n")
                     '(framing-conflict boundary 63))
        (check-equal "Transfer-Encoding then Content-Length"
                     (err "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nContent-Length: 1\r\n\r\n")
                     '(framing-conflict boundary 63))))))

;; --- the body across split points (§22.5) -------------------------------------

(harness-group "the fixed body coalesces identically across every split (§22.5)"
  (lambda ()
    (harness-case "a Content-Length message split at every point delivers the same body and finishes"
      (lambda ()
        (let* ((s "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\nHELLO")
               (canon (trace-skeleton (trace-of s)))
               (bad 'none) (n 0))
          (let loop ((k 1))
            (when (< k (string-length s))
              (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)) (bs (bytes s))
                     (lo (let take ((i 0) (a '())) (if (>= i k) (reverse a) (take (+ i 1) (cons (list-ref bs i) a)))))
                     (hi (let drop ((i k) (a '())) (if (>= i (length bs)) (reverse a) (drop (+ i 1) (cons (list-ref bs i) a))))))
                (parser-feed! p (u8-list->bytevector lo) 0 (length lo))
                (parser-feed! p (u8-list->bytevector hi) 0 (length hi))
                (let* ((r (parser-finish! p)) (sk (trace-skeleton ((cdr rc)))))
                  (set! n (+ n 1))
                  (unless (eq? (parser-result-status r) 'finished)
                    (when (eq? bad 'none) (set! bad (list 'not-finished k))))
                  (unless (equal? sk canon)
                    (when (eq? bad 'none) (set! bad (list 'skeleton-differs k sk))))))
              (loop (+ k 1))))
          (check-equal "every split finished with the same event skeleton" bad 'none)
          (check "the body coalesces to one HELLO in the uncut trace"
                 (has-entry? '(body-data "HELLO") (trace-of s))))))))

(harness-finish)
