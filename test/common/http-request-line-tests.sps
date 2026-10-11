;;; The HTTP request line, through the reference interpreter with ABSOLUTE
;;; expected outcomes — the events in the order the machine emits them, and the
;;; request-line error positions, byte for byte.
;;;
;;; Absolute, not differential, on purpose (http-version-interpret-tests.sps's
;;; reason): both executors are built from the same source IR, so a defect there
;;; is wrong in both and a comparison stays green. differential-http-tests.sps
;;; proves the two executors AGREE and folds in split points; this file
;;; pins what the request line MEANS.
;;;
;;; The recorded trace is validated against the shared event-order oracle
;;; as well as asserted absolutely, so a reordering the oracle's
;;; grammar forbids is caught by the grammar and not only by a hand-written
;;; expected list.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine test http-event-order)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-request-line")

(define (bytes s) (map char->integer (string->list s)))
(define (frag bv from to)
  (let loop ((i (- to 1)) (acc '()))
    (if (< i from) (list->string acc)
        (loop (- i 1) (cons (integer->char (bytevector-u8-ref bv i)) acc)))))

;; A fresh recorder per parser: a trace list, its bindings, and a reader.
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
                ;; The fixture fires these too; bind them so a
                ;; complete no-body message's full trace is recorded.
                (list 'header-name-data (dv 'header-name-data))
                (list 'header-name-complete (ev 'header-name-complete))
                (list 'header-value-data (dv 'header-value-data))
                (list 'header-value-complete (ev 'header-value-complete))
                (list 'headers-complete (ev 'headers-complete))
                (list 'message-complete (ev 'message-complete)))
          (lambda () (reverse tr)))))

(define cm (make-interpreted-machine (verify-machine (make-http-machine))))

(define (err-triple r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e)
         (list (parser-error-code e) (parser-error-position-kind e) (parser-error-offset e)))))

;; Feed the whole string in one bytevector; return (status offset error-triple trace).
(define (feed-whole s)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f))
         (bv (u8-list->bytevector (bytes s)))
         (r (parser-feed! p bv 0 (bytevector-length bv))))
    (list (parser-result-status r) (parser-result-stream-offset r)
          (err-triple r) ((cdr rc)))))
;; Feed then signal end of stream; return (status offset error-triple).
(define (feed-then-finish s)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f))
         (bv (u8-list->bytevector (bytes s))))
    (parser-feed! p bv 0 (bytevector-length bv))
    (let ((r (parser-finish! p)))
      (list (parser-result-status r) (parser-result-stream-offset r) (err-triple r)))))
;; Feed then finish, keeping the trace; return (status offset error-triple trace).
(define (feed-finish s)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f))
         (bv (u8-list->bytevector (bytes s))))
    (parser-feed! p bv 0 (bytevector-length bv))
    (let ((r (parser-finish! p)))
      (list (parser-result-status r) (parser-result-stream-offset r) (err-triple r) ((cdr rc))))))
;; Feed a string split at ASCENDING interior cuts; return (status . trace).
(define (feed-cuts s cuts)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)) (bs (bytes s)))
    (let loop ((start 0) (cs (append cuts (list (string-length s)))) (last #f))
      (if (null? cs) (cons (parser-result-status last) ((cdr rc)))
          (let* ((end (car cs))
                 (run (let take ((i start) (acc '()))
                        (if (>= i end) (reverse acc)
                            (take (+ i 1) (cons (list-ref bs i) acc)))))
                 (bv (u8-list->bytevector run)))
            (loop end (cdr cs)
                  (parser-feed! p bv 0 (bytevector-length bv))))))))

;; --- the machine is valid (an invalid graph is never driven) ----------------

(harness-group "the fixture verifies clean"
  (lambda ()
    (harness-case "no diagnostics"
      (lambda ()
        (let ((v (verify-machine (make-http-machine))))
          (check "ok" (verification-ok? v))
          (check-equal "diagnostic count" (length (verification-diagnostics v)) 0))))))

;; --- the request-line events, absolutely and by the oracle -----------------

(harness-group "a well-formed request line fires §21.3's events in order"
  (lambda ()
    (harness-case "the request-line events fire in order, then the machine awaits the header section"
      (lambda ()
        ;; The request-line CRLF leads into the header section
        ;; rather than stopping, so a bare request line reaches need-input at the
        ;; header line start with the request-line event PREFIX delivered.
        (let ((r (feed-whole "GET /index HTTP/1.1\r\n")))
          (check-equal "status/offset/error -- awaiting headers"
                       (list (car r) (cadr r) (caddr r)) '(need-input 21 #f))
          (check-equal "the request-line event prefix, in order"
                       (cadddr r)
                       '(message-begin (method-data "GET") method-complete
                         (target-data "/index") target-complete version-complete)))))
    (harness-case "a complete no-body message finishes and matches the event grammar"
      (lambda ()
        (let ((r (feed-finish "GET /index HTTP/1.1\r\n\r\n")))
          (check-equal "finished, no error" (list (car r) (caddr r)) '(finished #f))
          (check-equal "the full no-body event trace"
                       (cadddr r)
                       '(message-begin (method-data "GET") method-complete
                         (target-data "/index") target-complete version-complete
                         headers-complete message-complete))
          (check "the skeleton matches http-request-grammar"
                 (event-sequence-matches? http-request-grammar (trace-skeleton (cadddr r)))))))
    (harness-case "HTTP/1.0 is accepted identically (both version alternatives reach version-complete)"
      (lambda ()
        (let ((r (feed-finish "POST /a HTTP/1.0\r\n\r\n")))
          (check-equal "HTTP/1.0 finishes too" (car r) 'finished)
          (check-equal "trace prefix through version-complete"
                       (harness-take (cadddr r) 6)
                       '(message-begin (method-data "POST") method-complete
                         (target-data "/a") target-complete version-complete)))))
    (harness-case "the oracle REJECTS a scrambled order (a negative self-test)"
      (lambda ()
        (check "target before method is rejected"
               (not (event-sequence-matches?
                     http-request-grammar
                     '(message-begin target-data target-complete
                       method-data method-complete version-complete))))
        (check "a missing version-complete is rejected"
               (not (event-sequence-matches?
                     http-request-grammar
                     '(message-begin method-data method-complete
                       target-data target-complete))))))))

;; --- the request-line error rows, byte for byte ----------------------------

(harness-group "lexical errors at the first offending unconsumed byte (§21.4:1175)"
  (lambda ()
    (harness-case "invalid-method: a non-tchar where the method begins, and inside it"
      (lambda ()
        (check-equal "at offset 0 (empty method)" (caddr (feed-whole "@")) '(invalid-method byte 0))
        (check-equal "at offset 2 (non-tchar ends the token, no SP)"
                     (caddr (feed-whole "GE@ x HTTP/1.1\r\n")) '(invalid-method byte 2))))
    (harness-case "invalid-target: an empty target and a bad byte inside the target"
      (lambda ()
        (check-equal "at offset 4 (SP then non-target-byte)"
                     (caddr (feed-whole "GET \x01;;")) '(invalid-target byte 4))
        (check-equal "at offset 6 (bad byte inside the target)"
                     (caddr (feed-whole "GET /a\x01; HTTP/1.1\r\n")) '(invalid-target byte 6))))
    (harness-case "invalid-version: a version that is neither HTTP/1.0 nor HTTP/1.1"
      (lambda ()
        (check-equal "at offset 7 (first mismatch byte)"
                     (caddr (feed-whole "GET /x XTTP/1.1\r\n")) '(invalid-version byte 7))))
    (harness-case "invalid-line-ending: a bare LF, and a CR not followed by LF"
      (lambda ()
        (check-equal "at offset 15 (no CR after the version)"
                     (caddr (feed-whole "GET /x HTTP/1.1X")) '(invalid-line-ending byte 15))
        (check-equal "at offset 16 (CR not followed by LF)"
                     (caddr (feed-whole "GET /x HTTP/1.1\rX")) '(invalid-line-ending byte 16))))))

;; --- EOF: clean while idle, unexpected-eof at the final offset otherwise ------

(harness-group "EOF is clean only while idle (decision 0037), unexpected-eof otherwise"
  (lambda ()
    (harness-case "an empty stream finishes clean"
      (lambda ()
        (check-equal "finished, no error" (feed-then-finish "") '(finished 0 #f))))
    (harness-case "unexpected-eof reports position-kind eof at the final stream offset (§12.7:771)"
      (lambda ()
        (check-equal "in the method span (offset 3)"
                     (feed-then-finish "GET") '(error 3 (unexpected-eof eof 3)))
        (check-equal "after the method, awaiting the target (offset 4)"
                     (feed-then-finish "GET ") '(error 4 (unexpected-eof eof 4)))
        (check-equal "in the target span (offset 8)"
                     (feed-then-finish "GET /ind") '(error 8 (unexpected-eof eof 8)))
        (check-equal "in the version (offset 16)"
                     (feed-then-finish "GET /ind HTTP/1.") '(error 16 (unexpected-eof eof 16)))
        (check-equal "at the CR of the CRLF (offset 17)"
                     (feed-then-finish "GET /ind HTTP/1.1") '(error 17 (unexpected-eof eof 17)))
        (check-equal "at the LF of the CRLF (offset 18)"
                     (feed-then-finish "GET /ind HTTP/1.1\r") '(error 18 (unexpected-eof eof 18)))))))

;; --- split points: the event skeleton is invariant, the raw trace is not ------

(harness-group "every split point of a complete no-body message preserves the event order (§22.5)"
  (lambda ()
    (harness-case "the coalesced skeleton is invariant across all 22 single-cut splits"
      (lambda ()
        ;; A complete no-body message (request line + empty header line). All
        ;; events fire during the feed; message-complete loops to idle, so the
        ;; final status is need-input (at idle), invariant across splits.
        (let* ((s "GET /index HTTP/1.1\r\n\r\n")
               (canon (trace-skeleton (cadddr (feed-whole s))))
               (bad 'none) (n 0) (raws '()))
          (let loop ((k 1))
            (when (<= k 22)
              (let* ((rt (feed-cuts s (list k)))
                     (sk (trace-skeleton (cdr rt))))
                (set! n (+ n 1))
                (set! raws (cons (cdr rt) raws))
                (unless (eq? (car rt) 'need-input)
                  (when (eq? bad 'none) (set! bad (list 'not-idle k (car rt)))))
                (unless (equal? sk canon)
                  (when (eq? bad 'none) (set! bad (list 'skeleton-differs k sk)))))
              (loop (+ k 1))))
          (check-equal "no split changed the skeleton or the idle terminal" bad 'none)
          (check-equal "all 22 single-cut splits ran" n 22)
          ;; The negative sentinel: the RAW fragment trace is NOT
          ;; invariant — a split inside `/index` splits the target-data delivery,
          ;; so at least two of the raw traces differ. Without this, "the
          ;; skeleton is invariant" could hold vacuously if every split produced
          ;; the same raw trace (it does not).
          (check "the raw fragment trace is NOT invariant across splits"
                 (> (length (let dedup ((xs raws) (seen '()))
                              (cond ((null? xs) seen)
                                    ((member (car xs) seen) (dedup (cdr xs) seen))
                                    (else (dedup (cdr xs) (cons (car xs) seen))))))
                    1)))))))

(harness-finish)
