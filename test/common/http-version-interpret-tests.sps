;;; Multi-alternative sequence dispatch (§25:1529's multi-alternative half;
;;; exit §25:1538-1540) through the reference interpreter, with ABSOLUTE
;;; expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors are built from the
;;; same source IR, so a defect there makes them wrong IDENTICALLY and leaves a
;;; comparison green. This program is what a trie-branching defect reddens.
;;; Proving the two executors AGREE is a different lane's job, and it is the
;;; interpreter≡generated differential this slice adds next -- named here as
;;; intent, not as a file that exists yet.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-version-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-version")

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (parser-result-error r)))
(define (feed-one-at-a-time cm bs)
  (let ((p (make-parser cm '() #f)))
    (let loop ((l bs) (r #f))
      (if (null? l) r
          (loop (cdr l) (rfields (parser-feed! p (make-bytevector 1 (car l)) 0 1)))))))
(define (feed-whole cm bs)
  (let ((p (make-parser cm '() #f)) (bv (u8-list->bytevector bs)))
    (rfields (parser-feed! p bv 0 (bytevector-length bv)))))
(define (interp m) (make-interpreted-machine (verify-machine m)))
(define (bytes s) (map char->integer (string->list s)))

(define machines
  (list (list 'reexecute (make-http-version-machine))
        (list 'advance (make-http-version-advance-machine))))

;; §22.6 forbids using an invalid graph to test executor behaviour, so both
;; fixtures are proved clean before any behavioural case runs -- and after
;; Slice ③'s §16.2:894 pass that is a real check, not a formality: two
;; alternatives sharing `HTTP/1.` are exactly the shape a broken ambiguity
;; test would refuse.
(harness-group "both fixtures verify clean under the §16.2:894 pass"
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

(harness-group "each alternative reaches its OWN target through the shared prefix"
  (lambda ()
    (define re (interp (make-http-version-machine)))
    ;; Both alternatives accept with the identical tuple -- both targets are
    ;; stop nodes, so `next` does NOT distinguish them and no check here can.
    ;; What these cases DO catch is an alternative that stopped accepting at
    ;; all, which is how a dropped or mis-merged trie branch shows up. The
    ;; structural claim lives in normal-ir-tests.sps instead, for the reason
    ;; spelled out below.
    (harness-case "HTTP/1.0 stops at the zero target"
      (lambda ()
        (check-equal "one byte at a time" (feed-one-at-a-time re (bytes "HTTP/1.0"))
                     '(stopped 1 1 8 #f))))
    (harness-case "HTTP/1.1 stops at the one target"
      (lambda ()
        (check-equal "one byte at a time" (feed-one-at-a-time re (bytes "HTTP/1.1"))
                     '(stopped 1 1 8 #f))))
    ;; NOT asserted here, deliberately: that the two alternatives reach
    ;; DIFFERENT declared nodes. Both targets are stop nodes, so the two accepts
    ;; are behaviourally identical through the public accessors and no check in
    ;; this program can separate them -- a check claiming to would be asserting
    ;; something it cannot see. The distinction is structural, and it is
    ;; asserted where it is observable: normal-ir-tests.sps's "two alternatives
    ;; over a shared prefix lower to one trie" group, over the branching prefix
    ;; state's own transition list.
    (harness-case "a whole-buffer feed of each alternative consumes all eight bytes"
      (lambda ()
        (check-equal "HTTP/1.0" (feed-whole re (bytes "HTTP/1.0")) '(stopped 8 8 8 #f))
        (check-equal "HTTP/1.1" (feed-whole re (bytes "HTTP/1.1")) '(stopped 8 8 8 #f))))))

;; Every input below is TRUNCATED at (and including) the mismatching byte, so
;; each tuple is the mismatch's OWN result. Feeding the rest of the string and
;; reading the last tuple is a trap this plan fell into once while measuring:
;; after the error the parser is parked, further feeds are no-ops, and the
;; final tuple silently reports the parked state instead of the mismatch. The
;; two agree only when the mismatch happens to be on the last byte -- which is
;; true of `HTTP/1.2` and false of a position-0 mismatch, so a fixture set that
;; used whole strings would have been right in one case and quietly wrong in
;; the other.
(harness-group "mismatch positioning, at the branch and before it (§11.5:664)"
  (lambda ()
    (define re (interp (make-http-version-machine)))
    (define ad (interp (make-http-version-advance-machine)))
    (harness-case "reexecute mode points AT the distinguishing byte after the shared prefix"
      (lambda ()
        ;; `HTTP/1.` is seven bytes, so the distinguishing byte sits at
        ;; stream-offset 7 and a reexecute mismatch reports that offset having
        ;; consumed nothing of it.
        (check-equal "HTTP/1.2" (feed-one-at-a-time re (bytes "HTTP/1.2"))
                     '(error 0 0 7 unexpected-byte))))
    (harness-case "advance mode shifts the same mismatch by exactly one"
      (lambda ()
        (check-equal "HTTP/1.2" (feed-one-at-a-time ad (bytes "HTTP/1.2"))
                     '(error 1 1 8 unexpected-byte))))
    (harness-case "a mismatch INSIDE the shared prefix reports its own position, both modes"
      (lambda ()
        ;; `HTTP/` is five bytes, so the offending `2` is at offset 5.
        (check-equal "HTTP/2 reexecute" (feed-one-at-a-time re (bytes "HTTP/2"))
                     '(error 0 0 5 unexpected-byte))
        (check-equal "HTTP/2 advance" (feed-one-at-a-time ad (bytes "HTTP/2"))
                     '(error 1 1 6 unexpected-byte))))
    (harness-case "a mismatch at prefix position 0 reports offset 0, both modes"
      (lambda ()
        (check-equal "X reexecute" (feed-one-at-a-time re (bytes "X"))
                     '(error 0 0 0 unexpected-byte))
        (check-equal "X advance" (feed-one-at-a-time ad (bytes "X"))
                     '(error 1 1 1 unexpected-byte))))))

(harness-group "every proper prefix is need-input, never paused (decision 0015 point 5)"
  (lambda ()
    (define re (interp (make-http-version-machine)))
    (harness-case "all seven proper prefixes of HTTP/1.0 return need-input"
      (lambda ()
        ;; SENTINELS, both levels. `seen` counts what the PARSER returned, not
        ;; what the fixture expects, so a loop that never runs cannot pass; and
        ;; the outer length assertion is what catches a shortened prefix list.
        (let ((full (bytes "HTTP/1.0")))
          (check-equal "the fixture is eight bytes long" (length full) 8)
          (let loop ((k 1) (seen 0) (bad 'none))
            (if (> k 7)
                (begin
                  (check-equal "need-input results observed" seen 7)
                  (check-equal "no prefix misbehaved" bad 'none))
                (let* ((pre (let take ((l full) (n k)) (if (= n 0) '() (cons (car l) (take (cdr l) (- n 1))))))
                       (r (feed-one-at-a-time re pre)))
                  (loop (+ k 1)
                        (if (eq? (car r) 'need-input) (+ seen 1) seen)
                        (if (eq? (car r) 'need-input) bad k))))))))
    (harness-case "the seven-byte shared prefix is one of them"
      (lambda ()
        (check-equal "HTTP/1." (feed-one-at-a-time re (http-version-shared-prefix))
                     '(need-input 1 1 7 #f))))))

(harness-finish)
