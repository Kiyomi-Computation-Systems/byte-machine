;;; interpreter ≡ generated over the pause/resume proving machine. Proves the
;;; generated /v2 pause arm and its post-resume continuation equal the
;;; interpreter's parser-feed!/parser-finish!/parser-resume! walk over the
;;; shared pause machine, for feed (byte 1 pauses into p1, continuation s1; resume; byte 2
;;; stops), finish (EOF at entry pauses into pe, continuation done; resume;
;;; finish -> finished), truncation after a resumed pause (s1's eof-target ->
;;; trunc), and every one of the 256 first bytes (byte 1 pauses; every other
;;; byte rejects at offset 0). The interpreter is the reference; a
;;; disagreement here is a real lowering defect in the pause encoding /
;;; pause-target arm.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection) (byte-machine test pause-machine)
        (byte-machine graph)
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
;; pause-continuation comparison is observable as identical post-resume
;; continuation behavior, which only parser-lifecycle plus a
;; following operation's result can show.
(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (project-error (parser-result-error r))
        ;; The pause reason is projected too, so a lowering defect
        ;; in the pause identity (wrong code/reason, or leaked into the error
        ;; slot) shows as a cross-lane disagreement. project-error handles the
        ;; parser-error-shaped pause value and #f alike.
        (project-error (parser-result-pause r))
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
        ;; runtime-tests.sps's own nonzero-start case witnesses the
        ;; interpreter's pause arm directly; the same fixture here makes a
        ;; divergence also show up as a ref/gen disagreement (the generated
        ;; side is unmutated, so an interpreter-only regression separates the
        ;; two here too).
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

;; --- the pause reason, interpreter ≡ generated -------------------------------
;; A local machine is emitted, loaded and eval'd the same way the shared pause
;; machine is above; `gen-of` returns its compiled generated form so a reason
;; defect that hit both lanes identically cannot pass by agreement.
(define (gen-of m mname bind)
  (let ((f (string-append tmpdir "/gen-" (symbol->string mname) ".sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) bind p)))
    (load f)
    (eval bind (environment (list 'generated mname)))))
(define (pcode r) (let ((v (parser-result-pause r))) (and v (parser-error-code v))))
(define (preason r) (let ((v (parser-result-pause r))) (and v (parser-error-reason v))))

(harness-group "a pause reports its declared reason, error slot #f (both lanes)"
  (lambda ()
    ;; The shared pause machine's p1 (feed pause) carries paused-continue and pe
    ;; (EOF pause) carries paused-at-eof -- two different nodes, two different
    ;; reasons, so each of the feed and finish paths must report its own.
    (harness-case "feed pause p1 reports paused-continue with error slot #f"
      (lambda ()
        (let* ((pr (fresh-ref)) (pg (fresh-gen)) (bv (make-bytevector 1 1))
               (rr (parser-feed! pr bv 0 1)) (rg (parser-feed! pg bv 0 1)))
          (check-equal "fields agree (incl pause reason)" (rfields rg pg) (rfields rr pr))
          (check-equal "status paused" (parser-result-status rr) 'paused)
          (check-equal "error slot #f (a pause is not an error)" (parser-result-error rr) #f)
          (check-equal "pause code" (pcode rr) 'paused-continue)
          (check-equal "pause reason" (preason rr) "paused mid-feed"))))
    (harness-case "EOF pause pe reports paused-at-eof, a DIFFERENT reason"
      (lambda ()
        (let* ((pr (fresh-ref)) (pg (fresh-gen))
               (rr (parser-finish! pr)) (rg (parser-finish! pg)))
          (check-equal "fields agree" (rfields rg pg) (rfields rr pr))
          (check-equal "paused" (parser-result-status rr) 'paused)
          (check-equal "error slot #f" (parser-result-error rr) #f)
          (check-equal "pause code" (pcode rr) 'paused-at-eof))))))

(harness-group "the reason survives a resume and a re-pause (criterion 4)"
  (lambda ()
    ;; s0 --1--> p1(paused-a --> s1); s1 --2--> p2(paused-b --> s2); s2 --3--> stop.
    (define (chain)
      (make-machine 'pchain 's0 '() '() '()
        (list (make-error-declaration 'default-eof 'eof "eof" #f)
              (make-error-declaration 'rej 'unexpected-byte "rej" #f)
              (make-error-declaration 'ra 'paused-a "Pause A" #f)
              (make-error-declaration 'rb 'paused-b "Pause B" #f))
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'p1 'advance) #f))
                (make-edge 'r 'reexecute) #f #f)
              (make-pause-node 'p1 's1 'ra #f)
              (make-byte-dispatch-node 's1
                (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'p2 'advance) #f))
                (make-edge 'r 'reexecute) #f #f)
              (make-pause-node 'p2 's2 'rb #f)
              (make-byte-dispatch-node 's2
                (list (make-byte-case (make-exact-byte-matcher 3) (make-edge 'stop 'advance) #f))
                (make-edge 'r 'reexecute) #f #f)
              (make-stop-node 'stop #f) (make-error-node 'r 'rej #f))
        'default-eof #f))
    (harness-case "pause A, resume, pause B reports B (not A twice), both lanes"
      (lambda ()
        (let ((ref (make-interpreted-machine (verify-machine (chain))))
              (gen (gen-of (chain) 'pchain 'pchain-parser)))
          (let ((pr (make-parser ref '() #f)) (pg (make-parser gen '() #f)))
            (let ((r1r (parser-feed! pr (make-bytevector 1 1) 0 1))
                  (r1g (parser-feed! pg (make-bytevector 1 1) 0 1)))
              (check-equal "pause 1 fields agree" (rfields r1g pg) (rfields r1r pr))
              (check-equal "pause 1 code A" (pcode r1r) 'paused-a))
            (parser-resume! pr) (parser-resume! pg)
            (let ((r2r (parser-feed! pr (make-bytevector 1 2) 0 1))
                  (r2g (parser-feed! pg (make-bytevector 1 2) 0 1)))
              (check-equal "re-pause fields agree" (rfields r2g pg) (rfields r2r pr))
              (check-equal "re-pause reports B, NOT A" (pcode r2r) 'paused-b)
              (check-equal "re-pause error slot still #f" (parser-result-error r2r) #f))
            (parser-resume! pr) (parser-resume! pg)
            (let ((r3r (parser-feed! pr (make-bytevector 1 3) 0 1))
                  (r3g (parser-feed! pg (make-bytevector 1 3) 0 1)))
              (check-equal "final fields agree" (rfields r3g pg) (rfields r3r pr))
              (check-equal "final stops" (parser-result-status r3r) 'stopped)
              (check-equal "stop has no pause reason" (parser-result-pause r3r) #f))))))))

(harness-group "the SECOND author-facing pause path: a callback pause carries a reason"
  (lambda ()
    ;; s0 --1--> c(callback ev; pause -> kp; reason 'up); the callback returns
    ;; callback-pause, so the parser pauses on kp and reports the callback node's
    ;; reason. kp/k1 are dispatch nodes that finish at EOF so the machine verifies.
    (define (cbm)
      (make-machine 'pcb 's0 '()
        (list (make-callback-declaration 'ev 'event #t '() #f #f)) '()
        (list (make-error-declaration 'default-eof 'eof "eof" #f)
              (make-error-declaration 'rej 'unexpected-byte "rej" #f)
              (make-error-declaration 'up 'paused-upgrade "Pause on CONNECT/Upgrade" #f))
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'c 'advance) #f))
                (make-edge 'r 'reexecute) #f #f)
              (make-callback-node 'c 'ev 'k1 '() 'kp 'up #f)
              (make-byte-dispatch-node 'k1
                (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'st 'advance) #f))
                (make-edge 'r 'reexecute) 'fin #f)
              (make-byte-dispatch-node 'kp
                (list (make-byte-case (make-exact-byte-matcher 3) (make-edge 'st 'advance) #f))
                (make-edge 'r 'reexecute) 'fin #f)
              (make-stop-node 'st #f) (make-finish-node 'fin #f) (make-error-node 'r 'rej #f))
        'default-eof #f))
    ;; the callback returns callback-pause, bound at the declared 'ev slot;
    ;; invoked as (f parser user-context).
    (define (pausing-cb parser ctx) callback-pause)
    (harness-case "callback-pause reports the callback node's reason, both lanes"
      (lambda ()
        (let ((ref (make-interpreted-machine (verify-machine (cbm))))
              (gen (gen-of (cbm) 'pcb 'pcb-parser)))
          (let ((pr (make-parser ref (list (list 'ev pausing-cb)) #f))
                (pg (make-parser gen (list (list 'ev pausing-cb)) #f)))
            (let ((rr (parser-feed! pr (make-bytevector 1 1) 0 1))
                  (rg (parser-feed! pg (make-bytevector 1 1) 0 1)))
              (check-equal "callback-pause fields agree" (rfields rg pg) (rfields rr pr))
              (check-equal "paused" (parser-result-status rr) 'paused)
              (check-equal "error slot #f" (parser-result-error rr) #f)
              (check-equal "reason = paused-upgrade" (pcode rr) 'paused-upgrade))))))))

(harness-finish)
