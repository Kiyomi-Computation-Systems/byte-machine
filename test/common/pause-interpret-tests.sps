;;; The shared pause machine driven end-to-end through the interpreter: the
;;; feed pause/resume walk, the EOF pause/resume walk, truncation after resume,
;;; and all-256 first-byte coverage of the paused-vs-rejected split.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test pause-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.pause-interpret")

;; Slice ①a task 5: the error slot holds a parser-error record, and is #f on
;; every non-error result. These are single-executor lanes, so they compare the
;; CODE rather than the §22.4:1271 projection the differential lanes use --
;; but they must stay #f-tolerant, because the same accessor is read on results
;; that carry no error at all.
(define (error-code-of r)
  (let ((e (parser-result-error r)))
    (and (parser-error? e) (parser-error-code e))))

(define (fresh-parser)
  (make-parser (make-interpreted-machine (verify-machine (make-pause-machine))) '() #f))

(harness-group "feed pause walk"
  (lambda ()
    (harness-case "byte 1 pauses with one byte consumed; resume; byte 2 stops"
      (lambda ()
        (let* ((p (fresh-parser))
               (r1 (parser-feed! p (u8-list->bytevector '(1 2)) 0 2)))
          (check-equal "paused" (parser-result-status r1) 'paused)
          (check-equal "next" (parser-result-next r1) 1)
          (check-equal "consumed" (parser-result-consumed r1) 1)
          (check-equal "offset" (parser-result-stream-offset r1) 1)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-feed)
          (check-equal "ack" (parser-resume! p) 'feed-ready)
          (let ((r2 (parser-feed! p (u8-list->bytevector '(1 2)) 1 2)))
            (check-equal "stopped" (parser-result-status r2) 'stopped)
            (check-equal "offset 2" (parser-result-stream-offset r2) 2)))))))

(harness-group "EOF pause walk"
  (lambda ()
    (harness-case "finish pauses, resumes to finish-ready, finishes"
      (lambda ()
        (let* ((p (fresh-parser))
               (r1 (parser-finish! p)))
          (check-equal "paused" (parser-result-status r1) 'paused)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-finish)
          (check-equal "ack" (parser-resume! p) 'finish-ready)
          (let ((r2 (parser-finish! p)))
            (check-equal "finished" (parser-result-status r2) 'finished)
            (check-equal "sticky finished feed"
                         (parser-result-status (parser-feed! p (make-bytevector 1 1) 0 1))
                         'finished)))))
    (harness-case "truncation after a resumed pause carries the eof offset"
      (lambda ()
        (let ((p (fresh-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)   ; paused at p1
          (parser-resume! p)
          (let ((r (parser-finish! p)))                ; s1's eof-target -> trunc
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "code" (error-code-of r) 'truncated-input)
            (check-equal "offset" (parser-result-stream-offset r) 1)))))))

(harness-group "all-256 first bytes"
  (lambda ()
    (harness-case "byte 1 pauses; every other byte rejects at offset 0"
      (lambda ()
        (let loop ((b 0))
          (when (< b 256)
            (let* ((p (fresh-parser))
                   (r (parser-feed! p (make-bytevector 1 b) 0 1)))
              (if (= b 1)
                  (check-equal "paused" (parser-result-status r) 'paused)
                  (begin
                    (check-equal "error" (parser-result-status r) 'error)
                    (check-equal "code" (error-code-of r) 'unexpected-byte)
                    (check-equal "offset" (parser-result-stream-offset r) 0))))
            (loop (+ b 1))))))))

(harness-finish)
