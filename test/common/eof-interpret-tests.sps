;;; Exhaustive interpreter EOF lane over the shared idle-vs-truncation proving
;;; machine (Milestone 2 Slice ②b-1, `(byte-machine test eof-machine)`). Proves
;;; parser-finish! and eof-target execution hold not just for the one byte that
;;; advances each state but for every other byte value fed there, and that the
;;; §12.2 finish-after-terminal stickiness holds for both terminal statuses.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test eof-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.eof-interpret")

;; A fresh parser over a freshly-verified eof-machine. Task 1's §16.2 checks
;; (entry eof-target -> finish is legal; s1 eof-target -> error is legal) must
;; hold for this exact machine, or verify-machine below raises and every case
;; in this file fails to even construct its fixture.
(define (fresh)
  (make-parser (make-interpreted-machine (verify-machine (make-eof-machine))) '() #f))

(define (feed1 p b) (parser-feed! p (make-bytevector 1 b) 0 1))

(harness-group "the idle-vs-truncation machine verifies"
  (lambda ()
    (harness-case "verify-machine accepts it with no diagnostics"
      (lambda ()
        (let ((v (verify-machine (make-eof-machine))))
          (check-equal "ok" (verification-ok? v) #t)
          (check-equal "no diagnostics" (verification-diagnostics v) '()))))))

(harness-group "idle completion at entry (s0)"
  (lambda ()
    (harness-case "finish on a fresh parser is idle completion -> finished"
      (lambda ()
        (let ((r (parser-finish! (fresh))))
          (check-equal "status" (parser-result-status r) 'finished)
          (check-equal "next is the entry offset" (parser-result-next r) 0)
          (check-equal "consumed is zero" (parser-result-consumed r) 0)
          (check-equal "stream-offset is zero" (parser-result-stream-offset r) 0)
          (check-equal "no error" (parser-result-error r) #f))))
    (harness-case "every byte b != 1 fed at s0 errors at offset 0 with unexpected-byte"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (unless (= b 1)
                (let ((r (feed1 (fresh) b)))
                  (when (or (not (eq? (parser-result-status r) 'error))
                            (not (= (parser-result-stream-offset r) 0))
                            (not (eq? (parser-result-error r) 'unexpected-byte)))
                    (set! bad b))))
              (loop (+ b 1))))
          (check-equal "no byte in 0..255 (excl. 1) misbehaved" bad 'none))))
    (harness-case "after the sweep, a fresh parser's finish is still idle -> finished"
      (lambda ()
        (check-equal "finished" (parser-result-status (parser-finish! (fresh))) 'finished)))))

(harness-group "truncation after one byte (s1)"
  (lambda ()
    (harness-case "feed 1 then finish is truncation -> error/truncated-input at offset 1"
      (lambda ()
        (let ((p (fresh)))
          (feed1 p 1)
          (let ((r (parser-finish! p)))
            (check-equal "status" (parser-result-status r) 'error)
            (check-equal "error code" (parser-result-error r) 'truncated-input)
            (check-equal "next is the s1 offset" (parser-result-next r) 1)
            (check-equal "consumed is zero" (parser-result-consumed r) 0)
            (check-equal "stream-offset" (parser-result-stream-offset r) 1)))))
    (harness-case "feed 1 then 2 stops"
      (lambda ()
        (let ((p (fresh)))
          (feed1 p 1)
          (let ((r (feed1 p 2)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "stream-offset" (parser-result-stream-offset r) 2)))))
    (harness-case "feed 1 then every byte b != 2 errors at offset 1 with unexpected-byte"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (unless (= b 2)
                (let ((p (fresh)))
                  (feed1 p 1)
                  (let ((r (feed1 p b)))
                    (when (or (not (eq? (parser-result-status r) 'error))
                              (not (= (parser-result-stream-offset r) 1))
                              (not (eq? (parser-result-error r) 'unexpected-byte)))
                      (set! bad b)))))
              (loop (+ b 1))))
          (check-equal "no byte in 0..255 (excl. 2) misbehaved" bad 'none))))))

(harness-group "section 12.2 finish-after-terminal stickiness"
  (lambda ()
    (harness-case "finish after stopped stays stopped"
      (lambda ()
        (let ((p (fresh)))
          (feed1 p 1)
          (feed1 p 2)
          (check-equal "lifecycle stopped" (parser-lifecycle p) 'stopped)
          (check-equal "finish after stop stays stopped"
                       (parser-result-status (parser-finish! p)) 'stopped))))
    (harness-case "finish after finished stays finished"
      (lambda ()
        (let ((p (fresh)))
          (parser-finish! p)
          (check-equal "lifecycle finished" (parser-lifecycle p) 'finished)
          (check-equal "again finished" (parser-result-status (parser-finish! p)) 'finished))))))

(harness-finish)
