;;; The keyword-table node through the reference interpreter, with ABSOLUTE
;;; expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors are built from the
;;; same source IR, so a defect there makes them wrong IDENTICALLY and leaves a
;;; comparison green. This program is what a walk-logic mutation in the
;;; interpreter's own kw-step reddens; differential-keyword-table-tests.sps is
;;; what proves the interpreter and the generated table agree. The interpreter's
;;; kw-step is derived independently of the normalizer, so this
;;; lane's expectations are an independent statement of the semantics, not a
;;; readback of the lowering.
;;;
;;; Each keyword routes to a distinct stop node, so `parser-state-name` at the
;;; terminal is the WHICH-keyword witness -- the field that separates a GET match
;;; from a GET-PARAMETER match and a close from a closed.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test keyword-table-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.keyword-table")

(define (interp m) (make-interpreted-machine (verify-machine m)))
(define cs (interp (make-keyword-table-machine)))
(define ci (interp (make-keyword-table-ci-machine)))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (error-code-of r)
  (let ((e (parser-result-error r))) (and (parser-error? e) (parser-error-code e))))
(define (error-off-of r)
  (let ((e (parser-result-error r))) (and (parser-error? e) (parser-error-offset e))))

;; One whole-string feed. The tuple carries every field the cases constrain:
;; status, the span length (consumed) that must close at the keyword and not the
;; delimiter, next / stream-offset, the terminal node name, and the error code
;; and offset (#f on an accept).
(define (feed1 cm s)
  (let* ((bv (str->bv s)) (p (make-parser cm '() #f))
         (r (parser-feed! p bv 0 (bytevector-length bv))))
    (list (parser-result-status r) (parser-result-consumed r)
          (parser-result-next r) (parser-result-stream-offset r)
          (parser-state-name p) (error-code-of r) (error-off-of r))))

;; Feed then finish!, for the EOF cases.
(define (feed-finish cm s)
  (let ((p (make-parser cm '() #f)))
    (unless (= 0 (string-length s)) (parser-feed! p (str->bv s) 0 (string-length s)))
    (let ((r (parser-finish! p)))
      (list (parser-result-status r) (parser-result-consumed r)
            (parser-state-name p) (error-code-of r) (error-off-of r)))))

(harness-group "both keyword fixtures verify clean (§22.6: no behaviour on an invalid graph)"
  (lambda ()
    (for-each
     (lambda (e)
       (harness-case (string-append (symbol->string (car e)) " verifies with no diagnostics")
         (lambda ()
           (let ((v (verify-machine (cadr e))))
             (check "ok" (verification-ok? v))
             (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)))))
     (list (list 'kwtable (make-keyword-table-machine))
           (list 'kwtableci (make-keyword-table-ci-machine))))))

;; GET and GET-PARAMETER both live; the longer wins when present,
;; the shorter when the next byte cannot extend it, and a byte that leaves the
;; longer keyword mid-way with no shorter terminal at that point is a no-match --
;; NOT a rewind to GET (no backtracking).
(harness-group "proper-prefix keywords: longest match, no backtracking"
  (lambda ()
    (harness-case "GET-PARAMETER takes the long keyword"
      (lambda () (check-equal "gp" (feed1 cs "GET-PARAMETER ") '(stopped 13 13 13 got-gp #f #f))))
    (harness-case "GET + space takes the short keyword, span closes at 3 (delimiter not consumed)"
      (lambda () (check-equal "get" (feed1 cs "GET ") '(stopped 3 3 3 got-get #f #f))))
    (harness-case "GETX takes GET and leaves X (criterion 2: span 3, X reexecuted)"
      (lambda () (check-equal "getx" (feed1 cs "GETX") '(stopped 3 3 3 got-get #f #f))))
    (harness-case "GET-X commits down the GET-PARAMETER path and no-matches at X, never rewinding to GET"
      (lambda () (check-equal "get-x" (feed1 cs "GET-X") '(error 4 4 4 reject unexpected-byte 4))))))

;; close and closed are distinguished -- closed reaches got-closed,
;; and close + a non-extending byte reaches got-close, each at its own span.
(harness-group "close / closed are distinguished"
  (lambda ()
    (harness-case "closed takes the six-byte keyword"
      (lambda () (check-equal "closed" (feed1 cs "closed ") '(stopped 6 6 6 got-closed #f #f))))
    (harness-case "close + non-letter takes the five-byte keyword"
      (lambda () (check-equal "close" (feed1 cs "close ") '(stopped 5 5 5 got-close #f #f))))
    (harness-case "closex takes close and leaves x"
      (lambda () (check-equal "closex" (feed1 cs "closex") '(stopped 5 5 5 got-close #f #f))))))

;; A byte that matches no keyword at the entry is the no-match route: reexecute,
;; so nothing is consumed and the offset is 0.
(harness-group "no-match at the entry"
  (lambda ()
    (harness-case "a non-keyword first byte routes to the no-match error, consuming nothing"
      (lambda () (check-equal "xyz" (feed1 cs "xyz") '(error 0 0 0 reject unexpected-byte 0))))))

;; The per-table fold. The case-sensitive table refuses a
;; lowercased method; the case-insensitive one accepts every casing to the same
;; target, folds letters only (the hyphen still matches only itself), and keeps
;; the proper-prefix structure (get vs get-parameter do not collide under fold).
(harness-group "case-sensitivity is a per-table fold"
  (lambda ()
    (harness-case "the case-sensitive table refuses a lowercase method"
      (lambda () (check-equal "cs get" (feed1 cs "get ") '(error 0 0 0 reject unexpected-byte 0))))
    (harness-case "the case-insensitive table accepts every casing to the same target"
      (lambda ()
        (check-equal "GET" (feed1 ci "GET ") '(stopped 3 3 3 got-get #f #f))
        (check-equal "get" (feed1 ci "get ") '(stopped 3 3 3 got-get #f #f))
        (check-equal "GeT" (feed1 ci "GeT ") '(stopped 3 3 3 got-get #f #f))))
    (harness-case "the fold preserves the long keyword and folds letters only"
      (lambda ()
        (check-equal "get-parameter" (feed1 ci "get-parameter ") '(stopped 13 13 13 got-gp #f #f))
        (check-equal "CLOSE" (feed1 ci "CLOSE ") '(stopped 5 5 5 got-close #f #f))
        (check-equal "Closed" (feed1 ci "Closed ") '(stopped 6 6 6 got-closed #f #f))
        (check-equal "getx folds and leaves x" (feed1 ci "getx") '(stopped 3 3 3 got-get #f #f))))
    (harness-case "a mismatch inside a folded prefix no-matches at that offset"
      (lambda () (check-equal "gExY" (feed1 ci "gExY") '(error 2 2 2 reject unexpected-byte 2))))))

;; EOF inside a table. Acceptance requires a byte that closes the keyword; EOF
;; closes nothing, so a parked table -- at the entry, mid-keyword, OR sitting on
;; a complete-but-prefix keyword like GET, or even a complete non-prefix keyword
;; -- always takes the eof-target, never a keyword.
(harness-group "EOF mid-table routes to the eof-target, never a keyword"
  (lambda ()
    ;; The drive runs INSIDE the case so that a mutation dropping the
    ;; keyword-table arm of the interpreter's `eof-target-of` -- which sends a
    ;; parked table to the raising `else` -- is reported as "case raised ...
    ;; code: internal" rather than crashing the group setup uncaught.
    (harness-case "each of six EOF inputs takes the eof-target at its own offset"
      (lambda ()
        (let ((bad 'none) (seen 0))
          (for-each
           (lambda (pair)
             (set! seen (+ seen 1))
             (let ((got (feed-finish cs (car pair)))
                   (want (list 'error 0 'eof-incomplete 'truncated-keyword (cdr pair))))
               (unless (equal? got want)
                 (when (eq? bad 'none) (set! bad (list (car pair) got))))))
           ;; input . expected eof offset
           '(("" . 0) ("GE" . 2) ("GET" . 3) ("GET-" . 4) ("closed" . 6) ("GET-PARAMETER" . 13)))
          (check-equal "no EOF input misbehaved" bad 'none)
          (check-equal "all six EOF inputs ran" seen 6))))))

(harness-finish)
