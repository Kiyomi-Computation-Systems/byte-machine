;;; Issue #139 / decision 0054: the keyword walk, timed and weighed alone.
;;;
;;; Drives `byte-machine-keyword-step/v1` over the five header names
;;; chez-httparse reads by name (case-insensitive), on a 17-byte field name whose
;;; first k bytes are `Transfer-Encoding` and whose rest is `x` -- the issue's k
;;; table -- beside the pre-0054 walk that copied its prefix on every byte. It
;;; prints Chez's `time` report per (k, walk): cpu time and bytes allocated.
;;;
;;; Not a gating lane and not §23 instrument output: single runs, for the
;;; figures decision 0054 cites. The gated property -- allocation flat in k --
;;; is asserted by test/common/allocation-audit-tests.sps, which carries the
;;; same control walk. Run from the repository root:
;;;   chez --libdirs src --script bench/runner/keyword-walk.sps
;;; optionally with BYTE_MACHINE_BENCH_INNER (walks per cell, default 200000).
(import (rnrs) (only (chezscheme) time collect getenv) (byte-machine runtime))

(define (bytes s) (map char->integer (string->list s)))
(define kw-entries
  (let loop ((ns '("connection" "content-length" "proxy-connection"
                   "transfer-encoding" "upgrade"))
             (id 0) (acc '()))
    (if (null? ns) (reverse acc)
        (loop (cdr ns) (+ id 1) (cons (cons (bytes (car ns)) id) acc)))))
(define kw-no-match '(99 . reexecute))
(define (kw-field k)
  (u8-list->bytevector
   (bytes (string-append (substring "Transfer-Encoding" 0 k)
                         (make-string (- 17 k) #\x) ":"))))

;; The walk as it stood before issue #139 (kept verbatim in the allocation lane).
(define (copying-keyword-step entries no-match ci? path bv pos end)
  (define (fold b) (if (and ci? (>= b 65) (<= b 90)) (+ b 32) b))
  (define (prefix? p bs)
    (cond ((null? p) #t)
          ((null? bs) #f)
          ((= (fold (car p)) (fold (car bs))) (prefix? (cdr p) (cdr bs)))
          (else #f)))
  (let walk ((p path) (i pos))
    (if (>= i end)
        (list 'need p i)
        (let ((np (append p (list (bytevector-u8-ref bv i)))))
          (if (exists (lambda (e) (prefix? np (car e))) entries)
              (walk np (+ i 1))
              (let ((term (find (lambda (e) (and (= (length (car e)) (length p))
                                                 (prefix? p (car e))))
                                entries)))
                (cond (term (list 'jump (cdr term) i 'byte))
                      ((eq? (cdr no-match) 'advance)
                       (list 'jump (car no-match) (+ i 1) 'boundary))
                      (else (list 'jump (car no-match) i 'byte)))))))))

(define reps
  (let ((s (getenv "BYTE_MACHINE_BENCH_INNER")))
    (or (and s (string->number s)) 200000)))

(define (bench name step k)
  (let ((bv (kw-field k)))
    (display (list 'k k name 'walks reps)) (newline)
    (collect)
    (time (do ((i 0 (+ i 1))) ((= i reps))
            (step kw-entries kw-no-match #t '() bv 0 (bytevector-length bv))))))

(for-each (lambda (k)
            (bench 'copying copying-keyword-step k)
            (bench 'in-place byte-machine-keyword-step/v1 k))
          '(0 4 10 17))
