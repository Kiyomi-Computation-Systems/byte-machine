;;; D6 (parent §22.9, §20) over the pause/resume proving machine (Milestone 2
;;; Slice 3): deterministic emission proved against a committed golden, and
;;; the emitted library's pause/resume walks proved directly. Byte-identity in
;;; this process AND equality to the golden (which every cell and lane
;;; compares against) give cross-process, cross-lane, and cross-cell identity
;;; transitively; M9 completes the four-cell matrix with the same golden.
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test pause-machine)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.pause")

(define ok (compile-machine (make-pause-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_PAUSE_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism "BYTE_MACHINE_PAUSE_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'pausem)
                     (render-machine ok 'pausem))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'pausem)
                     (adapter-file-bytes golden-file))))))

;; Load the emitted library once; each walk below drives a fresh parser off
;; the one loaded compiled-machine binding (compiled machines are immutable,
;; so sharing it across parsers is safe).
(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'determinism-pause "no tmpdir" #f)))
(define genfile (string-append tmpdir "/determinism-pause.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine ok 'pausem p)))
(load genfile)
(define cm (eval 'pausem (environment '(generated pausem))))

(harness-group "the golden output compiles and executes the pause/resume walks"
  (lambda ()
    (harness-case "feed: byte 1 pauses, resumes feed-ready, byte 2 stops"
      (lambda ()
        (let* ((p (make-parser cm '() #f))
               (r1 (parser-feed! p (make-bytevector 1 1) 0 1)))
          (check-equal "paused" (parser-result-status r1) 'paused)
          (check-equal "ack" (parser-resume! p) 'feed-ready)
          (let ((r2 (parser-feed! p (make-bytevector 1 2) 0 1)))
            (check-equal "stopped" (parser-result-status r2) 'stopped)))))
    (harness-case "finish: EOF at entry pauses, resumes finish-ready, finish finishes"
      (lambda ()
        (let* ((p (make-parser cm '() #f))
               (r1 (parser-finish! p)))
          (check-equal "paused" (parser-result-status r1) 'paused)
          (check-equal "ack" (parser-resume! p) 'finish-ready)
          (let ((r2 (parser-finish! p)))
            (check-equal "finished" (parser-result-status r2) 'finished)))))))

(harness-finish)
