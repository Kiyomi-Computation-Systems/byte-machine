;;; Property differential (parent §22.4, §22.6, M2 Slice 3): generated valid
;;; machines, the interpreter oracle vs the emitted executor, all 256
;;; single-byte feeds each. Each byte gets its own fresh parser pair, fed
;;; once and, whenever both sides agree they paused, resumed and re-fed from
;;; `next` until the feed settles; a pair still `ready` afterward is then
;;; finished the same way (a finish pause resumes to finish-ready and
;;; finishes again), so a Slice 3 machine's pause/resume and idle-completion
;;; routes are walked to a real terminal, not just fed one byte and dropped.
;;; The seed is fixed and printed; a disagreement tags which phase diverged
;;; and prints the machine index so the case replays. Generated .sls are
;;; test-time artifacts in the tmp root.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test prng)
        (byte-machine test machine-gen)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "property.differential")

(define seed 20260823)
(define machine-count 40)
(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'property "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; Every field the operation matrix defines, plus parser-lifecycle: a pause's
;; observable effect (D3's continuation-parking) only shows up as the NEXT
;; operation's behavior, which only lifecycle plus that operation's own
;; result can show (mirrors differential-pause-tests.sps's own rfields).
(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (parser-result-error r) (parser-lifecycle p)))

;; Emit `m` to a fresh file, load it, and return its compiled-machine. The
;; library name is (generated gen) for every machine, so each emission gets its
;; own file and a fresh eval environment.
(define (emit-and-load m i)
  (let ((genfile (string-append tmpdir "/prop-" (number->string i) ".sls")))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) 'gen-parser p)))
    (load genfile)
    (eval 'gen-parser (environment '(generated gen)))))

;; Resume both sides -- the caller has already confirmed they agree on being
;; paused -- and return their acks as a 2-list. The one place either side's
;; resume happens, shared by the feed-pause and finish-pause loops below.
(define (resume-pair! pr pg)
  (list (parser-resume! pr) (parser-resume! pg)))

;; Feed bv[start,end) to both sides, honouring the pause protocol: whenever
;; BOTH sides report paused, resume both (§12.1 -- lifecycle only, no input
;; consumed) and re-feed the remainder from `next`. A side that paused alone
;; is already a disagreement caught by the tuple compare below, and must not
;; be driven through parser-resume!, which raises on anything but a
;; paused-feed parser -- so resume is only ever reached once both sides
;; agree. Returns (values bad paused?): bad is 'none or a tagged description
;; of the first disagreement; paused? is #t iff a pause was observed.
(define (feed-loop! pr pg bv start end)
  (let ((rr (parser-feed! pr bv start end)) (rg (parser-feed! pg bv start end)))
    (cond
      ((not (equal? (rfields rr pr) (rfields rg pg)))
       (values (list 'feed start) #f))
      ((and (eq? (parser-result-status rr) 'paused) (eq? (parser-result-status rg) 'paused))
       (let ((acks (resume-pair! pr pg)))
         (if (not (equal? (car acks) (cadr acks)))
             (values (list 'feed-ack start) #t)
             (let-values (((bad _paused?) (feed-loop! pr pg bv (parser-result-next rr) end)))
               (values bad #t)))))
      (else (values 'none #f)))))

;; parser-finish! both sides, honouring the same pause protocol as
;; feed-loop! -- a finish pause (D4(d)'s idle-completion route) resumes to
;; finish-ready and finishes again, which falls through to the real executor
;; rather than a sticky short-circuit: finish-ready is not one of
;; parser-finish!'s sticky rows. Returns (values bad paused?), the same
;; shape as feed-loop!.
(define (finish-loop! pr pg)
  (let ((rr (parser-finish! pr)) (rg (parser-finish! pg)))
    (cond
      ((not (equal? (rfields rr pr) (rfields rg pg))) (values (list 'finish) #f))
      ((and (eq? (parser-result-status rr) 'paused) (eq? (parser-result-status rg) 'paused))
       (let ((acks (resume-pair! pr pg)))
         (if (not (equal? (car acks) (cadr acks)))
             (values (list 'finish-ack) #t)
             (let-values (((bad _paused?) (finish-loop! pr pg)))
               (values bad #t)))))
      (else (values 'none #f)))))

;; One byte's trial: a fresh parser pair, fed the single byte and driven
;; through feed-loop!'s pause protocol, then -- only when both sides are
;; still `ready` afterward -- finished the same way. A pair that already
;; reached stopped/error via feed is deliberately NOT finished: parser-
;; finish! on a sticky lifecycle short-circuits inside the shared runtime.sls
;; wrapper before reaching either executor (D1), so that comparison would
;; only check the wrapper against itself and prove nothing about either
;; side. Returns (values bad paused?), the same shape as feed-loop!.
(define (byte-trial cm-ref cm-gen b)
  (let ((pr (make-parser cm-ref '() #f)) (pg (make-parser cm-gen '() #f)))
    (let-values (((bad paused?) (feed-loop! pr pg (make-bytevector 1 b) 0 1)))
      (cond
        ((not (eq? bad 'none)) (values bad paused?))
        ((and (eq? (parser-lifecycle pr) 'ready) (eq? (parser-lifecycle pg) 'ready))
         (let-values (((fbad fpaused?) (finish-loop! pr pg)))
           (values fbad (or paused? fpaused?))))
        (else (values 'none paused?))))))

(harness-group "the PRNG is reproducible"
  (lambda ()
    (harness-case "the same seed yields the same first draw"
      (lambda ()
        (let-values (((a _sa) (prng-next (make-prng seed) 256))
                     ((b _sb) (prng-next (make-prng seed) 256)))
          (check-equal "same" a b))))))

(harness-group "interpreter and generated agree on every generated machine"
  (lambda ()
    (harness-case "all generated machines verify and agree on all 256 bytes"
      (lambda ()
        ;; paused-count is the anti-vacuity guard for the Slice 3 pause draw
        ;; (machine-gen.sls): a seed set where it never actually fires (or
        ;; fires but no case ever lands on `pausep`) would make every pause
        ;; check below vacuous, so this asserts the property lane actually
        ;; drove at least one generated machine through a real pause.
        (let loop ((i 0) (s (make-prng seed)) (paused-count 0))
          (if (< i machine-count)
              (let-values (((m s2) (gen-machine s)))
                (let ((v (verify-machine m)))
                  (check (string-append "machine " (number->string i) " verifies")
                         (verification-ok? v))
                  (if (verification-ok? v)
                      (let ((cm-ref (make-interpreted-machine v))
                            (cm-gen (emit-and-load m i)))
                        (let bl ((b 0) (bad 'none) (paused? #f))
                          (if (< b 256)
                              (let-values (((b-bad b-paused?) (byte-trial cm-ref cm-gen b)))
                                (bl (+ b 1) (if (eq? bad 'none) b-bad bad) (or paused? b-paused?)))
                              (begin
                                (check-equal
                                 (string-append "machine " (number->string i)
                                                " (seed " (number->string seed) ") byte agreement")
                                 bad 'none)
                                (loop (+ i 1) s2 (if paused? (+ paused-count 1) paused-count))))))
                      (loop (+ i 1) s2 paused-count))))
              (check (string-append "at least one of the " (number->string machine-count)
                                    " generated machines' 256-byte trial observes a pause")
                     (>= paused-count 1))))))))

(harness-finish)
