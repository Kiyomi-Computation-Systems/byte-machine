;;; Milestone 8 Slice ④: the chunked body, extensions, the zero chunk, and
;;; trailers (§25:1639-1640), through the reference interpreter with ABSOLUTE
;;; outcomes. Agreement between the executors is differential-http-tests.sps's.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine test http-event-order)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-chunked")

(define (bytes s) (map char->integer (string->list s)))
(define (frag bv from to)
  (let loop ((i (- to 1)) (acc '()))
    (if (< i from) (list->string acc)
        (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc)))))
(define all-callbacks
  '(message-begin method-data method-complete target-data target-complete version-complete
    header-name-data header-name-complete header-value-data header-value-complete
    headers-complete message-complete body-data chunk-header chunk-complete
    chunk-extension-name-data chunk-extension-name-complete
    chunk-extension-value-data chunk-extension-value-complete
    trailer-name-data trailer-name-complete trailer-value-data trailer-value-complete))
(define data-callbacks
  '(method-data target-data header-name-data header-value-data body-data
    chunk-extension-name-data chunk-extension-value-data trailer-name-data trailer-value-data))
(define (recorder)
  (let ((tr '()))
    (define (ev name) (lambda (ps ux) (set! tr (cons name tr)) callback-continue))
    (define (dv name) (lambda (ps ux bv from to)
                        (set! tr (cons (list name (frag bv from to)) tr)) callback-continue))
    (cons (map (lambda (n) (list n (if (memq n data-callbacks) (dv n) (ev n)))) all-callbacks)
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
      (list (parser-result-status r) (err-triple r) ((cdr rc))))))
(define (err s) (cadr (feed-finish s)))
(define (trace-of s) (caddr (feed-finish s)))
(define (has? e tr) (and (member e tr) #t))
(define pre "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n")   ; 46 bytes

;; --- the chunked body's events, in order (§21.3) ------------------------------

(harness-group "chunk-header, body-data, chunk-complete, the zero chunk, and message-complete"
  (lambda ()
    (harness-case "one chunk then the zero chunk: framing octets are never body data"
      (lambda ()
        (let ((r (feed-finish (string-append pre "5\r\nHELLO\r\n0\r\n\r\n"))))
          (check-equal "finished" (car r) 'finished)
          (check-equal "the chunked trace"
                       (caddr r)
                       '(message-begin (method-data "GET") method-complete
                         (target-data "/") target-complete version-complete
                         (header-name-data "Transfer-Encoding") header-name-complete
                         (header-value-data "chunked") header-value-complete headers-complete
                         chunk-header (body-data "HELLO") chunk-complete
                         chunk-header message-complete))
          (check "the skeleton matches the event grammar"
                 (event-sequence-matches? http-request-grammar (trace-skeleton (caddr r)))))))
    (harness-case "two chunks each get a fresh body span and a chunk-complete"
      (lambda ()
        (let ((tr (trace-of (string-append pre "3\r\nabc\r\n2\r\nde\r\n0\r\n\r\n"))))
          (check "first chunk body" (has? '(body-data "abc") tr))
          (check "second chunk body" (has? '(body-data "de") tr))
          (check-equal "three chunk-headers (two nonzero + the zero chunk)"
                       (length (filter (lambda (e) (eq? e 'chunk-header)) tr)) 3)
          (check-equal "two chunk-completes (nonzero chunks only)"
                       (length (filter (lambda (e) (eq? e 'chunk-complete)) tr)) 2))))
    (harness-case "a chunk size with leading zeroes is accepted (§21.2:1108)"
      (lambda ()
        (check-equal "05 is 5 octets" (car (feed-finish (string-append pre "05\r\nHELLO\r\n0\r\n\r\n"))) 'finished)))))

;; --- chunk extensions (§21.3:1147) --------------------------------------------

(harness-group "chunk extensions are token spans excluding their delimiters"
  (lambda ()
    (harness-case "a ;name=value extension delivers name and value as spans"
      (lambda ()
        (let ((tr (trace-of (string-append pre "5;foo=bar\r\nHELLO\r\n0\r\n\r\n"))))
          (check "extension name" (has? '(chunk-extension-name-data "foo") tr))
          (check "extension value" (has? '(chunk-extension-value-data "bar") tr)))))
    (harness-case "a malformed extension is invalid-chunk-extension (quoted values are excluded)"
      (lambda ()
        (check-equal "an empty extension name (;=) at its byte"
                     (err (string-append pre "5;=x\r\nHELLO\r\n")) '(invalid-chunk-extension byte 48))))))

;; --- the checked chunk size (§21.2:1108, §12.7:773) ---------------------------

(harness-group "chunk sizes are base-16 checked accumulation"
  (lambda ()
    (harness-case "a non-HEXDIG size is invalid-chunk-size at the offending byte"
      (lambda ()
        (check-equal "XYZ" (err (string-append pre "XYZ\r\n")) '(invalid-chunk-size byte 46))))
    (harness-case "a size past u64 overflows at the offending digit"
      (lambda ()
        (check-equal "seventeen f's" (err (string-append pre "fffffffffffffffff\r\n"))
                     '(chunk-size-overflow byte 62))))
    (harness-case "chunk data not followed by CRLF is invalid-chunk-ending"
      (lambda ()
        (check-equal "5\\r\\nHELLOX" (err (string-append pre "5\r\nHELLOX\r\n"))
                     '(invalid-chunk-ending byte 54))))))

;; --- the trailer section (§21.2:1110) -----------------------------------------

(harness-group "trailers reuse the header grammar; Content-Length/Transfer-Encoding are forbidden"
  (lambda ()
    (harness-case "a permitted trailer delivers name and value"
      (lambda ()
        (let ((tr (trace-of (string-append pre "0\r\nX-Trace: on\r\n\r\n"))))
          (check "trailer name" (has? '(trailer-name-data "X-Trace") tr))
          (check "trailer value" (has? '(trailer-value-data "on") tr)))))
    (harness-case "a Content-Length or Transfer-Encoding trailer is forbidden at the colon (byte)"
      (lambda ()
        (check-equal "Content-Length trailer"
                     (err (string-append pre "0\r\nContent-Length: 5\r\n\r\n")) '(forbidden-trailer byte 63))
        (check-equal "Transfer-Encoding trailer"
                     (err (string-append pre "0\r\nTransfer-Encoding: x\r\n\r\n")) '(forbidden-trailer byte 66))))
    (harness-case "a name that only shares the forbidden prefix is allowed (opaque)"
      (lambda ()
        (check-equal "Content-Lengthy is a permitted trailer"
                     (car (feed-finish (string-append pre "0\r\nContent-Lengthy: v\r\n\r\n"))) 'finished)))))

;; --- split points (§22.5) -----------------------------------------------------

(harness-group "a chunked message coalesces identically across every split (§22.5)"
  (lambda ()
    (harness-case "every split finishes with the same event skeleton"
      (lambda ()
        (let* ((s (string-append pre "3;a=b\r\nabc\r\n2\r\nde\r\n0\r\nX-T: v\r\n\r\n"))
               (canon (trace-skeleton (trace-of s))) (bad 'none) (n 0))
          (let loop ((k 1))
            (when (< k (string-length s))
              (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)) (bs (bytes s))
                     (lo (let t ((i 0) (a '())) (if (>= i k) (reverse a) (t (+ i 1) (cons (list-ref bs i) a)))))
                     (hi (let d ((i k) (a '())) (if (>= i (length bs)) (reverse a) (d (+ i 1) (cons (list-ref bs i) a))))))
                (parser-feed! p (u8-list->bytevector lo) 0 (length lo))
                (parser-feed! p (u8-list->bytevector hi) 0 (length hi))
                (let ((r (parser-finish! p)))
                  (set! n (+ n 1))
                  (unless (and (eq? (parser-result-status r) 'finished)
                               (equal? (trace-skeleton ((cdr rc))) canon))
                    (when (eq? bad 'none) (set! bad k)))))
              (loop (+ k 1))))
          (check-equal "no split disagreed" bad 'none)
          (check "the canonical skeleton matches the grammar"
                 (event-sequence-matches? http-request-grammar canon)))))))

(harness-finish)
