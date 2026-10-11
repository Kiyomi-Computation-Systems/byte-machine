;;; Step 2, at run time: import the generated parser and feed it bytes. It
;;; needs (byte-machine runtime) and nothing else from byte-machine. Run from
;;; this directory, after generate.sps:
;;;
;;;   chez --libdirs ../../src:. --program run.sps
(import (rnrs) (generated words) (byte-machine runtime))

;; The bytes in [from, to) are yours only while the callback runs: copy them.
(define (text bv from to)
  (let ((copy (make-bytevector (- to from))))
    (bytevector-copy! bv from copy 0 (- to from))
    (utf8->string copy)))

(define parser
  (make-parser words-parser
    (list (list 'on-word
                (lambda (parser context bv from to)
                  (display "on-word ") (write (text bv from to)) (newline)
                  callback-continue))
          (list 'on-word-end
                (lambda (parser context)
                  (display "on-word-end\n")
                  callback-continue)))
    #f))

(define (feed! string)
  (let* ((bv (string->utf8 string))
         (result (parser-feed! parser bv 0 (bytevector-length bv))))
    (display "feed ") (write string)
    (display " -> ") (display (parser-result-status result))
    (display ", consumed ") (display (parser-result-consumed result))
    (newline)))

;; One line, split across two reads in the middle of a word.
(feed! "hello wor")
(feed! "ld\n")
