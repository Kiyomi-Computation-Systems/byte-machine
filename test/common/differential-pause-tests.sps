;;; interpreter ≡ generated over the pause/resume proving machine (Milestone 2
;;; Slice 3, parent §22.4 "pause continuations"). Proves the generated /v2
;;; pause arm and its post-resume continuation equal the interpreter's
;;; parser-feed!/parser-finish!/parser-resume! walk over the shared pause
;;; machine, for feed (byte 1 pauses into p1, continuation s1; resume; byte 2
;;; stops), finish (EOF at entry pauses into pe, continuation done; resume;
;;; finish -> finished), truncation after a resumed pause (s1's eof-target ->
;;; trunc), and every one of the 256 first bytes (byte 1 pauses; every other
;;; byte rejects at offset 0). The interpreter is the reference; a
;;; disagreement here is a real lowering defect in the pause encoding /
;;; pause-target arm.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection) (byte-machine test pause-machine)
        (byte-machine verify) (byte-machine interpret)
        (byte-machine runtime) (byte-machine compile))
(harness-begin "differential.pause")
(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-pause "no tmpdir" #f)))
(define genfile (string-append tmpdir "/generated-pause.sls"))
(define m (make-pause-machine))
(define cm-ref (make-interpreted-machine (verify-machine m)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine m '()) 'pause-parser p)))
(load genfile)
(define cm-gen (eval 'pause-parser (environment '(generated pausem))))

;; Every field the operation matrix defines, plus parser-lifecycle: the
;; §22.4 "pause continuations" comparison is observable as identical
;; post-resume continuation behavior, which only parser-lifecycle plus a
;; following operation's result can show.
(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (project-error (parser-result-error r))
        (parser-lifecycle p)))

(define (fresh-ref) (make-parser cm-ref '() #f))
(define (fresh-gen) (make-parser cm-gen '() #f))

(harness-group "feed pause/resume walk over all 256 first bytes"
  (lambda ()
    (harness-case "byte 1 pauses and its post-resume continuation agrees; other bytes reject alike"
      (lambda ()
        (let ((bad 'none) (b1-final 'unset))
          (let loop ((b 0))
            (when (< b 256)
              (let* ((pr (fresh-ref)) (pg (fresh-gen))
                     (bv (make-bytevector 1 b))
                     (rr (parser-feed! pr bv 0 1))
                     (rg (parser-feed! pg bv 0 1)))
                (unless (equal? (rfields rr pr) (rfields rg pg))
                  (when (eq? bad 'none) (set! bad (list 'feed b))))
                ;; Only descend into resume + the post-resume feed when BOTH
                ;; sides actually paused -- a side that disagreed above must
                ;; not be driven through parser-resume!, which raises a
                ;; lifecycle-violation on anything but a paused-feed parser.
                ;; The mismatch is already captured by the check above.
                (when (and (eq? (parser-result-status rr) 'paused)
                           (eq? (parser-result-status rg) 'paused))
                  (let ((ar (parser-resume! pr)) (ag (parser-resume! pg)))
                    (unless (equal? ar ag)
                      (when (eq? bad 'none) (set! bad (list 'ack b))))
                    (let* ((bv2 (make-bytevector 1 2))
                           (r2r (parser-feed! pr bv2 0 1))
                           (r2g (parser-feed! pg bv2 0 1)))
                      (unless (equal? (rfields r2r pr) (rfields r2g pg))
                        (when (eq? bad 'none) (set! bad (list 'post-resume b))))
                      (when (= b 1) (set! b1-final (parser-result-status r2r)))))))
              (loop (+ b 1))))
          (check-equal "no byte disagreed across the schedule" bad 'none)
          (check-equal "byte 1's post-resume continuation stops on byte 2"
                       b1-final 'stopped))))))

(harness-group "nonzero-start feed pause"
  (lambda ()
    (harness-case "a pause fed from a nonzero start agrees on next, consumed, and stream offset"
      (lambda ()
        ;; Whole-branch review Critical 1: runtime-tests.sps's own nonzero-
        ;; start case witnesses the interpreter's pause arm directly; this
        ;; adds the same fixture here so a divergence would also show up as
        ;; a ref/gen disagreement (the generated side is unmutated, so an
        ;; interpreter-only regression separates the two here too).
        (let* ((pr (fresh-ref)) (pg (fresh-gen))
               (bv (u8-list->bytevector (list 9 1 2)))
               (rr (parser-feed! pr bv 1 3)) (rg (parser-feed! pg bv 1 3)))
          (check-equal "fields agree" (rfields rg pg) (rfields rr pr))
          (check-equal "next" (parser-result-next rr) 2)
          (check-equal "consumed" (parser-result-consumed rr) 1)
          (check-equal "stream offset" (parser-result-stream-offset rr) 1))))))

(harness-group "EOF pause/resume walk"
  (lambda ()
    (harness-case "finish pauses at entry, resumes to finish-ready, finish finishes"
      (lambda ()
        (let* ((pr (fresh-ref)) (pg (fresh-gen))
               (r1r (parser-finish! pr)) (r1g (parser-finish! pg)))
          (check-equal "paused fields agree" (rfields r1g pg) (rfields r1r pr))
          (check-equal "paused" (parser-result-status r1r) 'paused)
          (let ((ar (parser-resume! pr)) (ag (parser-resume! pg)))
            (check-equal "acks agree" ag ar)
            (check-equal "finish-ready ack" ar 'finish-ready))
          (let ((r2r (parser-finish! pr)) (r2g (parser-finish! pg)))
            (check-equal "finished fields agree" (rfields r2g pg) (rfields r2r pr))
            (check-equal "finished" (parser-result-status r2r) 'finished)))))
    (harness-case "truncation after a resumed pause carries the eof offset"
      (lambda ()
        (let* ((pr (fresh-ref)) (pg (fresh-gen)))
          (parser-feed! pr (make-bytevector 1 1) 0 1)
          (parser-feed! pg (make-bytevector 1 1) 0 1)
          (parser-resume! pr)
          (parser-resume! pg)
          (let ((rr (parser-finish! pr)) (rg (parser-finish! pg)))
            (check-equal "fields agree" (rfields rg pg) (rfields rr pr))
            (check-equal "error code" (parser-error-code (parser-result-error rr)) 'truncated-input)
            (check-equal "offset" (parser-result-stream-offset rr) 1)))))))

(harness-finish)
