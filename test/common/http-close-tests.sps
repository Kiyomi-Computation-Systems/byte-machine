;;; Milestone 8 Slice ⑤: the malformed sweep, pipelining, and the EOF rules
;;; (§25:1641-1642). Every §21.4 code is produced at the position Slice ⓪'s table
;;; states; pipelined requests each complete; EOF is clean only while idle.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-machine)
        (byte-machine test http-error-table)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-close")

(define (bytes s) (map char->integer (string->list s)))
(define cm (make-interpreted-machine (verify-machine (make-http-machine))))
(define (err-triple r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e)
         (list (parser-error-code e) (parser-error-position-kind e) (parser-error-offset e)))))
(define (mb-count tr) (length (filter (lambda (e) (eq? e 'message-begin)) tr)))
(define (mc-count tr) (length (filter (lambda (e) (eq? e 'message-complete)) tr)))
;; a counting recorder for message-begin/message-complete only (pipelining)
(define (count-run s)
  (let* ((tr '())
         (b (list (list 'message-begin (lambda (ps ux) (set! tr (cons 'message-begin tr)) callback-continue))
                  (list 'message-complete (lambda (ps ux) (set! tr (cons 'message-complete tr)) callback-continue))))
         (p (make-parser cm b #f)) (bv (u8-list->bytevector (bytes s))))
    (parser-feed! p bv 0 (bytevector-length bv))
    (let ((r (parser-finish! p)))
      (list (parser-result-status r) (reverse tr)))))
(define (finish-code s)
  (let* ((p (make-parser cm '() #f)) (bv (u8-list->bytevector (bytes s))))
    (parser-feed! p bv 0 (bytevector-length bv))
    (err-triple (parser-finish! p))))
(define (feed-code s)   ; feed only (a lexical error shows without finish)
  (let* ((p (make-parser cm '() #f)) (bv (u8-list->bytevector (bytes s))))
    (err-triple (parser-feed! p bv 0 (bytevector-length bv)))))
(define (code-of triple) (and triple (car triple)))
(define (sortsym l) (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) l))
(define (distinct xs) (let loop ((xs xs) (acc '())) (cond ((null? xs) (reverse acc)) ((member (car xs) acc) (loop (cdr xs) acc)) (else (loop (cdr xs) (cons (car xs) acc))))))

;; --- the malformed sweep: every §21.4 code produced at its stated position ----

;; (input use code position offset) — `use` is 'feed (lexical, no finish needed)
;; or 'finish (EOF). Positions match Slice ⓪'s table and the per-region lanes.
(define cpre "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n")
(define sweep
  (list
   (list "@"                                            'feed 'invalid-method 'byte 0)
   (list "GET \x01;"                                    'feed 'invalid-target 'byte 4)
   (list "GET /x XTTP/1.1\r\n"                          'feed 'invalid-version 'byte 7)
   (list "GET /x HTTP/1.1X"                             'feed 'invalid-line-ending 'byte 15)
   (list "GET / HTTP/1.1\r\n@bad\r\n"                   'feed 'invalid-header-name 'byte 16)
   (list "GET / HTTP/1.1\r\nHost: a\x01;b\r\n"          'feed 'invalid-header-value 'byte 23)
   (list "GET / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n" 'feed 'duplicate-content-length 'boundary 54)
   (list "GET / HTTP/1.1\r\nContent-Length: abc\r\n\r\n" 'feed 'invalid-content-length 'byte 32)
   (list "GET / HTTP/1.1\r\nContent-Length: 99999999999999999999999999\r\n\r\n" 'feed 'content-length-overflow 'byte 51)
   (list "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n\r\n" 'feed 'duplicate-transfer-encoding 'boundary 72)
   (list "GET / HTTP/1.1\r\nTransfer-Encoding: gzip\r\n\r\n" 'feed 'unsupported-transfer-encoding 'byte 35)
   (list "GET / HTTP/1.1\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n" 'feed 'framing-conflict 'boundary 63)
   (list (string-append cpre "XYZ\r\n")                 'feed 'invalid-chunk-size 'byte 46)
   (list (string-append cpre "fffffffffffffffff\r\n")   'feed 'chunk-size-overflow 'byte 62)
   (list (string-append cpre "5;=x\r\nHELLO\r\n")       'feed 'invalid-chunk-extension 'byte 48)
   (list (string-append cpre "5\r\nHELLOX\r\n")         'feed 'invalid-chunk-ending 'byte 54)
   (list (string-append cpre "0\r\nContent-Length: 5\r\n\r\n") 'feed 'forbidden-trailer 'byte 63)
   (list "GET"                                          'finish 'unexpected-eof 'eof 3)))

(harness-group "the malformed sweep: every §21.4 code at its Slice ⓪ position"
  (lambda ()
    (harness-case "each row produces exactly its code, kind and offset"
      (lambda ()
        (for-each
         (lambda (row)
           (let* ((s (car row)) (use (cadr row))
                  (got ((if (eq? use 'finish) finish-code feed-code) s)))
             (check-equal (symbol->string (caddr row))
                          got (list (caddr row) (cadddr row) (car (cddddr row))))))
         sweep)))
    (harness-case "the sweep covers exactly Slice ⓪'s eighteen codes (§21.4 floor)"
      (lambda ()
        (check-equal "the sweep's code set equals the table's code set"
                     (sortsym (distinct (map caddr sweep)))
                     (sortsym (distinct (map (lambda (r) (caddr r)) http-error-rows))))))))

;; --- pipelining: several complete requests in one feed (§25:1642) -------------

(harness-group "pipelined requests each complete, in every framing combination"
  (lambda ()
    (harness-case "no-body, fixed, and chunked requests back to back finish with one message each"
      (lambda ()
        (let ((r (count-run
                  (string-append
                   "GET /a HTTP/1.1\r\n\r\n"
                   "POST /b HTTP/1.1\r\nContent-Length: 3\r\n\r\nabc"
                   "PUT /c HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n0\r\n\r\n"))))
          (check-equal "finished after the third" (car r) 'finished)
          (check-equal "three message-begins" (mb-count (cadr r)) 3)
          (check-equal "three message-completes" (mc-count (cadr r)) 3))))
    (harness-case "the same request pipelined twice yields two complete messages"
      (lambda ()
        (let ((r (count-run "GET / HTTP/1.1\r\n\r\nGET / HTTP/1.1\r\n\r\n")))
          (check-equal "finished" (car r) 'finished)
          (check-equal "two of each" (list (mb-count (cadr r)) (mc-count (cadr r))) '(2 2)))))))

;; --- EOF: clean only while idle (decision 0037) -------------------------------

(harness-group "clean EOF only while idle; unexpected-eof from every non-idle region"
  (lambda ()
    (harness-case "an empty feed and a clean inter-message boundary finish"
      (lambda ()
        (check-equal "empty" (car (count-run "")) 'finished)))
    (harness-case "unexpected-eof from a representative of every non-idle region"
      (lambda ()
        (for-each
         (lambda (s)
           (check-equal (string-append "eof: " s) (code-of (finish-code s)) 'unexpected-eof))
         (list "GET" "GET /ind" "GET /ind HTTP/1." "GET /ind HTTP/1.1"
               "GET / HTTP/1.1\r\nHos" "GET / HTTP/1.1\r\nH: v"
               "GET / HTTP/1.1\r\nContent-Length: 1"
               "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\nHE"           ; fixed body truncated
               (string-append cpre "5\r\nHE")                              ; chunk data truncated
               (string-append cpre "5;na")                                 ; chunk ext name truncated
               (string-append cpre "0\r\nX-T")                             ; trailer name truncated
               (string-append cpre "0\r\nX-T: v")))))))                    ; trailer value truncated

(harness-finish)
