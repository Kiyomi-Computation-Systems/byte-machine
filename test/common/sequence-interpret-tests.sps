;;; All-byte sequence-dispatch coverage (parent §22.7; Milestone 3 exit §25:1538)
;;; through the reference interpreter, with ABSOLUTE expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors are built from the same
;;; source IR, so a defect there makes them wrong IDENTICALLY and leaves a
;;; comparison green. This program is what a prefix-tracking mutation reddens;
;;; differential-sequence-node-tests.sps is what proves the two executors agree.
;;;
;;; Every byte is fed as its own [0,1) slice through ONE parser, which is the
;;; shape that makes the between-byte stream-offset observable at every position
;;; -- and the shape in which the two mismatch modes differ visibly (§11.5:664).
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test sequence-node-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.sequence-node")

;; Slice ①a task 5: the error slot holds a parser-error record, and is #f on
;; every non-error result. These are single-executor lanes, so they compare the
;; CODE rather than the §22.4:1271 projection the differential lanes use --
;; but they must stay #f-tolerant, because the same accessor is read on results
;; that carry no error at all.
(define (error-code-of r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e) (parser-error-code e))))

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (error-code-of r)))
(define (feed-bytes cm bs)
  (let ((p (make-parser cm '() #f)))
    (let loop ((l bs) (r #f))
      (if (null? l) r
          (loop (cdr l) (rfields (parser-feed! p (make-bytevector 1 (car l)) 0 1)))))))
(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (interp m) (make-interpreted-machine (verify-machine m)))
(define seq-bytes (sequence-node-bytes))
(define machines
  (list (list 'seqnode (make-sequence-node-machine))
        (list 'advseq (make-advance-mismatch-machine))))

;; §22.6 forbids using an invalid graph to test executor behaviour, so both
;; fixtures are proved clean before any behavioural case runs.
(harness-group "both sequence fixtures verify clean"
  (lambda ()
    (harness-case "the fixture list holds both mismatch modes"
      (lambda () (check-equal "fixture count" (length machines) 2)))
    (for-each
     (lambda (e)
       (harness-case (string-append (symbol->string (car e)) " verifies with no diagnostics")
         (lambda ()
           (let ((v (verify-machine (cadr e))))
             (check "ok" (verification-ok? v))
             (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)))))
     machines)))

(harness-group "a single-alternative sequence accepts its four bytes"
  (lambda ()
    (define one (interp (make-sequence-node-machine)))
    (harness-case "the full sequence stops at stream-offset 4"
      (lambda ()
        (check-equal "stopped" (feed-bytes one seq-bytes) '(stopped 1 1 4 #f))))
    (harness-case "every proper prefix is need-input, never paused (decision 0015 point 5)"
      (lambda ()
        ;; `bad` alone proves no prefix MISBEHAVED, not that the loop ran; `seen`
        ;; counts what the parser actually returned, so a machine that reached a
        ;; terminal early cannot pass by leaving no counterexample.
        (let ((bad 'none) (seen 0))
          (for-each
           (lambda (k)
             (let ((r (feed-bytes one (head-n seq-bytes k))))
               (when (eq? (car r) 'need-input) (set! seen (+ seen 1)))
               (unless (equal? r (list 'need-input 1 1 k #f))
                 (when (eq? bad 'none) (set! bad k)))))
           '(1 2 3))
          (check-equal "no prefix misbehaved" bad 'none)
          (check-equal "all three prefixes returned need-input" seen 3))))))

(harness-group "all 256 byte values at every sequence position"
  (lambda ()
    (for-each
     (lambda (e)
       (let* ((name (car e))
              (cm (interp (cadr e)))
              (advance? (eq? name 'advseq)))
         (harness-case (string-append (symbol->string name)
                                      " accepts only its own byte at each position")
           (lambda ()
             ;; last-byte and positions are set from the loops themselves, so a
             ;; loop that never ran cannot pass; accepted is counted from the
             ;; parser's OWN status, never from the expectation.
             (let ((bad 'none) (last-byte 'unset) (positions 0) (accepted 0))
               (for-each
                (lambda (k)
                  (set! positions (+ positions 1))
                  (let ((prefix (head-n seq-bytes k))
                        (want (list-ref seq-bytes k)))
                    (let loop ((b 0))
                      (when (< b 256)
                        (let ((r (feed-bytes cm (append prefix (list b)))))
                          (if (= b want)
                              (begin
                                (unless (memq (car r) '(need-input stopped))
                                  (when (eq? bad 'none) (set! bad (cons k b))))
                                (when (memq (car r) '(need-input stopped))
                                  (set! accepted (+ accepted 1))))
                              (unless (equal? r (if advance?
                                                    (list 'error 1 1 (+ k 1) 'unexpected-byte)
                                                    (list 'error 0 0 k 'unexpected-byte)))
                                (when (eq? bad 'none) (set! bad (cons k b))))))
                        (set! last-byte b)
                        (loop (+ b 1))))))
                '(0 1 2 3))
               (check-equal "no (position . byte) misbehaved" bad 'none)
               (check-equal "the byte loop ran all 256 values" last-byte 255)
               (check-equal "the position loop ran all four positions" positions 4)
               (check-equal "exactly one byte per position continued" accepted 4))))))
     machines)))

;; §11.5:664 -- authors may deliberately choose either mismatch mode and "tests
;; must make that choice explicit". Every shipped fixture in this tree uses
;; reexecute, so before this slice the advance path had no coverage anywhere; an
;; advance-mode mismatch shifts every reported position by one and no existing
;; test would look obviously wrong.
(harness-group "the two mismatch modes report different positions, explicitly"
  (lambda ()
    (define re (interp (make-sequence-node-machine)))
    (define ad (interp (make-advance-mismatch-machine)))
    (harness-case "reexecute leaves next and consumed at zero and the offset at the prefix"
      (lambda ()
        (check-equal "k=0" (feed-bytes re '(200)) '(error 0 0 0 unexpected-byte))
        (check-equal "k=1" (feed-bytes re '(1 200)) '(error 0 0 1 unexpected-byte))
        (check-equal "k=2" (feed-bytes re '(1 2 200)) '(error 0 0 2 unexpected-byte))
        (check-equal "k=3" (feed-bytes re '(1 2 3 200)) '(error 0 0 3 unexpected-byte))))
    (harness-case "advance consumes the offending byte and shifts every position by one"
      (lambda ()
        (check-equal "k=0" (feed-bytes ad '(200)) '(error 1 1 1 unexpected-byte))
        (check-equal "k=1" (feed-bytes ad '(1 200)) '(error 1 1 2 unexpected-byte))
        (check-equal "k=2" (feed-bytes ad '(1 2 200)) '(error 1 1 3 unexpected-byte))
        (check-equal "k=3" (feed-bytes ad '(1 2 3 200)) '(error 1 1 4 unexpected-byte))))
    (harness-case "the two modes agree on a successful sequence"
      (lambda ()
        (check-equal "same accept" (feed-bytes re seq-bytes) (feed-bytes ad seq-bytes))))))

(harness-finish)
