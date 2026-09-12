;;; Milestone 8 Slice ②: headers, the empty line, and the no-body message loop
;;; (§25:1635-1636), through the reference interpreter with ABSOLUTE outcomes.
;;; The request-line events are http-request-line-tests.sps's; this file pins the
;;; header block, headers-complete/message-complete, the all-OWS value
;;; (§21.2:1097), the message loop (§21.3:1150), and the header error rows of
;;; Slice ⓪'s table. Agreement between the executors is differential-http-tests's.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine test http-event-order)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-message")

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
                (list 'method-data (dv 'method-data)) (list 'method-complete (ev 'method-complete))
                (list 'target-data (dv 'target-data)) (list 'target-complete (ev 'target-complete))
                (list 'version-complete (ev 'version-complete))
                (list 'header-name-data (dv 'header-name-data)) (list 'header-name-complete (ev 'header-name-complete))
                (list 'header-value-data (dv 'header-value-data)) (list 'header-value-complete (ev 'header-value-complete))
                (list 'headers-complete (ev 'headers-complete)) (list 'message-complete (ev 'message-complete)))
          (lambda () (reverse tr)))))

(define cm (make-interpreted-machine (verify-machine (make-http-machine))))
(define (err-triple r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e)
         (list (parser-error-code e) (parser-error-position-kind e) (parser-error-offset e)))))
(define (feed-whole s)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)) (bv (u8-list->bytevector (bytes s)))
         (r (parser-feed! p bv 0 (bytevector-length bv))))
    (list (parser-result-status r) (parser-result-stream-offset r) (err-triple r) ((cdr rc)))))
(define (feed-finish s)
  (let* ((rc (recorder)) (p (make-parser cm (car rc) #f)) (bv (u8-list->bytevector (bytes s))))
    (parser-feed! p bv 0 (bytevector-length bv))
    (let ((r (parser-finish! p)))
      (list (parser-result-status r) (parser-result-stream-offset r) (err-triple r) ((cdr rc))))))
(define (count-of x xs) (length (filter (lambda (e) (equal? e x)) xs)))

;; --- the header block's events, in order --------------------------------------

(harness-group "the header block fires §21.3's header events, then headers-complete and message-complete"
  (lambda ()
    (harness-case "two headers, values delivered as span data, complete in order"
      (lambda ()
        (let ((r (feed-finish "GET /index HTTP/1.1\r\nHost: example.com\r\nAccept: */*\r\n\r\n")))
          (check-equal "finished" (car r) 'finished)
          (check-equal "the full trace, headers included"
                       (cadddr r)
                       '(message-begin (method-data "GET") method-complete
                         (target-data "/index") target-complete version-complete
                         (header-name-data "Host") header-name-complete
                         (header-value-data "example.com") header-value-complete
                         (header-name-data "Accept") header-name-complete
                         (header-value-data "*/*") header-value-complete
                         headers-complete message-complete))
          (check "the skeleton matches the event grammar"
                 (event-sequence-matches? http-request-grammar (trace-skeleton (cadddr r)))))))
    (harness-case "headers-complete fires only AFTER the empty-line CRLF is consumed (§21.3:1144)"
      (lambda ()
        ;; Fed up to and including the empty line's CR but not its LF: the value
        ;; events are in, but headers-complete has not fired yet.
        (let ((tr (cadddr (feed-whole "GET / HTTP/1.1\r\nH: v\r\n\r"))))
          (check "header-value-complete is present" (and (memq 'header-value-complete tr) #t))
          (check "headers-complete is NOT present before the empty line's LF"
                 (not (memq 'headers-complete tr))))))
    (harness-case "a message with no headers goes straight to headers-complete"
      (lambda ()
        (check-equal "trace"
                     (cadddr (feed-finish "GET /a HTTP/1.0\r\n\r\n"))
                     '(message-begin (method-data "GET") method-complete
                       (target-data "/a") target-complete version-complete
                       headers-complete message-complete))))))

;; --- the all-OWS value (§21.2:1097) -------------------------------------------

(harness-group "OWS handling and the all-OWS value (§21.2:1097)"
  (lambda ()
    (harness-case "leading OWS after the colon is not span data; internal/trailing OWS is"
      (lambda ()
        ;; "X:  a b \r\n": the two leading spaces are skipped; the value span is
        ;; "a b " with its internal and trailing space kept.
        (let ((tr (cadddr (feed-finish "GET / HTTP/1.1\r\nX:  a b \r\n\r\n"))))
          (check "the value span is 'a b ' (leading OWS skipped, trailing kept)"
                 (and (member '(header-value-data "a b ") tr) #t)))))
    (harness-case "an all-OWS value produces an empty value span followed by completion"
      (lambda ()
        ;; "X-Empty:  \r\n": leading OWS consumes both spaces, the value span
        ;; opens and closes empty -- header-value-complete with no data.
        (let ((tr (cadddr (feed-finish "GET / HTTP/1.1\r\nX-Empty:  \r\n\r\n"))))
          (check "no header-value-data for the empty value" (= (count-of 'header-value-data
                    (map (lambda (e) (if (pair? e) (car e) e)) tr)) 0))
          (check "header-value-complete still fires" (and (memq 'header-value-complete tr) #t)))))))

;; --- the no-body message loop (§21.3:1150) ------------------------------------

(harness-group "two requests in one feed each produce a complete message (§21.3:1150)"
  (lambda ()
    (harness-case "one message-begin each, and the stream offset is not reset between them"
      (lambda ()
        (let* ((r (feed-finish "GET /a HTTP/1.1\r\n\r\nPOST /b HTTP/1.0\r\nH: v\r\n\r\n")))
          (check-equal "finished at the absolute end of the second message"
                       (list (car r) (cadr r)) '(finished 45))
          (let ((tr (cadddr r)))
            (check-equal "exactly two message-begin events" (count-of 'message-begin tr) 2)
            (check-equal "exactly two message-complete events" (count-of 'message-complete tr) 2)
            (check-equal "the full two-message trace"
                         tr
                         '(message-begin (method-data "GET") method-complete
                           (target-data "/a") target-complete version-complete
                           headers-complete message-complete
                           message-begin (method-data "POST") method-complete
                           (target-data "/b") target-complete version-complete
                           (header-name-data "H") header-name-complete
                           (header-value-data "v") header-value-complete
                           headers-complete message-complete))))))))

;; --- the header error rows of Slice ⓪'s table ---------------------------------

(harness-group "header errors at their §21.4:1175 positions"
  (lambda ()
    (define (err s) (caddr (feed-whole s)))
    (harness-case "invalid-header-name: a non-tchar where a field-name must begin, and a missing colon"
      (lambda ()
        (check-equal "at the line start (offset 16)"
                     (err "GET / HTTP/1.1\r\n@bad\r\n\r\n") '(invalid-header-name byte 16))
        (check-equal "a name not terminated by a colon (offset 20)"
                     (err "GET / HTTP/1.1\r\nHost\r\n") '(invalid-header-name byte 20))))
    (harness-case "invalid-header-value: a non-field-value, non-CR byte after the value"
      (lambda ()
        (check-equal "at offset 23 (a control byte after the value)"
                     (err "GET / HTTP/1.1\r\nHost: a\x01;b\r\n") '(invalid-header-value byte 23))))
    (harness-case "invalid-line-ending: a value's CR not followed by LF, and the empty line's"
      (lambda ()
        (check-equal "after a value (offset 24)"
                     (err "GET / HTTP/1.1\r\nHost: v\rX") '(invalid-line-ending byte 24))
        (check-equal "the empty line's CR not followed by LF (offset 17)"
                     (err "GET / HTTP/1.1\r\n\rX") '(invalid-line-ending byte 17))))
    (harness-case "unexpected-eof from every header region (position-kind eof, final offset)"
      (lambda ()
        (define (eofn s) (let* ((rc (recorder)) (p (make-parser cm (car rc) #f))
                                (bv (u8-list->bytevector (bytes s))))
                           (parser-feed! p bv 0 (bytevector-length bv))
                           (err-triple (parser-finish! p))))
        (check-equal "in a header name (offset 19)"
                     (eofn "GET / HTTP/1.1\r\nHos") '(unexpected-eof eof 19))
        (check-equal "in a header value (offset 20)"
                     (eofn "GET / HTTP/1.1\r\nH: v") '(unexpected-eof eof 20))
        (check-equal "at a header line start (offset 16)"
                     (eofn "GET / HTTP/1.1\r\n") '(unexpected-eof eof 16))))))

(harness-finish)
