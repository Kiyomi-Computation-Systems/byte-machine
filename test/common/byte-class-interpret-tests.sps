;;; All-byte class tests (parent §22.7:1299-1301; Milestone 3 exit :1537) run
;;; through the reference interpreter with ABSOLUTE expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors canonicalize through
;;; the same `matcher-bytes`, so a defect there would make interpreter and
;;; generated wrong IDENTICALLY and leave a comparison green. This program is
;;; what a canonicalization mutation reddens; differential-byte-class-tests.sps
;;; is what proves the two executors agree.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test class-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.byte-class")

(define (feed cm b)
  (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1))

;; Every machine must VERIFY clean first: a fixture that fails verification would
;; make every behavioural case below meaningless, and §22.6 forbids using an
;; invalid graph to test executor behaviour.
(harness-group "every class fixture verifies clean"
  (lambda ()
    (for-each
     (lambda (entry)
       (harness-case (string-append (symbol->string (car entry)) " verifies with no diagnostics")
         (lambda ()
           (let ((v (verify-machine (cadr entry))))
             (check "ok" (verification-ok? v))
             (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)))))
     (class-machines))))

(harness-group "all 256 byte values, per class"
  (lambda ()
    (for-each
     (lambda (entry)
       (let* ((name (car entry))
              (cm (make-interpreted-machine (verify-machine (cadr entry))))
              (accepted (caddr entry)))
         (harness-case (string-append (symbol->string name) " accepts exactly its class")
           (lambda ()
             ;; `bad` alone proves no byte MISBEHAVED, not that the loop ran: a
             ;; loop that never executed leaves it at its seeded 'none. last-byte
             ;; is set every iteration, so it reaches 255 only if all 256 ran, and
             ;; `hits` counts acceptances so a matcher that accepts nothing at all
             ;; cannot pass by having no counterexample.
             (let ((bad 'none) (last-byte 'unset) (hits 0))
               (let loop ((b 0))
                 (when (< b 256)
                   (let ((r (feed cm b)))
                     (if (memv b accepted)
                         (begin
                           (set! hits (+ hits 1))
                           (unless (and (eq? (parser-result-status r) 'stopped)
                                        (= (parser-result-consumed r) 1))
                             (when (eq? bad 'none) (set! bad b))))
                         (unless (and (eq? (parser-result-status r) 'error)
                                      (eq? (parser-result-error r) 'unexpected-byte)
                                      (= (parser-result-stream-offset r) 0))
                           (when (eq? bad 'none) (set! bad b)))))
                   (set! last-byte b)
                   (loop (+ b 1))))
               (check-equal "no byte misbehaved" bad 'none)
               (check-equal "loop ran all 256 bytes" last-byte 255)
               (check-equal "accepted exactly the class size" hits (length accepted)))))))
     (class-machines))))

;; §22.7 and design §5 item 6: ascii-bytes cannot supply the high half of the
;; universe -- that is make-byte-range-matcher's job -- so its all-byte test
;; asserts REJECTION across 0x80-0xFF rather than acceptance anywhere in it.
(harness-group "the ASCII helper rejects the high half"
  (lambda ()
    (harness-case "every byte from 128 to 255 is rejected by the ascii machine"
      (lambda ()
        (let ((cm (make-interpreted-machine (verify-machine (make-ascii-machine))))
              (bad 'none) (last-byte 'unset) (checked 0))
          (let loop ((b 128))
            (when (< b 256)
              (let ((r (feed cm b)))
                (set! checked (+ checked 1))
                (unless (and (eq? (parser-result-status r) 'error)
                             (eq? (parser-result-error r) 'unexpected-byte))
                  (when (eq? bad 'none) (set! bad b))))
              (set! last-byte b)
              (loop (+ b 1))))
          (check-equal "no high byte was accepted" bad 'none)
          (check-equal "loop ran the whole high half" last-byte 255)
          (check-equal "checked 128 bytes" checked 128))))))

(harness-finish)
