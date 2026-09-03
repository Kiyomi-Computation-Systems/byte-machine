;;; Property differential (parent §22.4, §22.6, M2 Slice 3): generated valid
;;; machines, the interpreter oracle vs the emitted executor, all 256
;;; single-byte feeds each. Each byte gets its own fresh parser pair, fed
;;; once and, whenever both sides agree they paused, resumed and re-fed from
;;; `next` until the feed settles; a pair still `ready` afterward is then
;;; finished the same way (a finish pause resumes to finish-ready and
;;; finishes again), so a Slice 3 machine's pause/resume and idle-completion
;;; routes are walked to a real terminal, not just fed one byte and dropped.
;;; The seed is fixed and printed; a disagreement tags the byte and which
;;; phase diverged, and prints the machine index, so the case replays.
;;; Generated .sls are test-time artifacts in the tmp root.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
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
;;
;; Slice ③ appends the FIELD VALUES. Without them an accumulate draw compares
;; nothing about what the node computed: every member above is a parser result or
;; a lifecycle, and two lanes that accumulated to different numbers agree on all
;; of them. `fnames` comes from gen-machine (which knows, since it declared the
;; field) rather than from the machine, because (byte-machine graph) exports no
;; `machine-fields`. It is the empty list for every machine that drew no
;; accumulate node, and then this is exactly the shipped tuple.
(define (rfields r p fnames)
  (append
   (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
         (parser-result-stream-offset r) (project-error (parser-result-error r))
         (parser-lifecycle p))
   (map (lambda (nm) (parser-field-ref p nm)) fnames)))

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
;; is already a disagreement the rfields compare in this function's own first
;; cond clause has already caught, and must not be driven through
;; parser-resume!, which raises on anything but a paused-feed parser -- so
;; resume is only ever reached once both sides agree. Returns (values bad
;; paused?): bad is 'none or a tagged description of the first disagreement
;; (untagged with the byte number here -- byte-trial adds that, since this
;; loop does not know which byte its caller is trying); paused? is #t iff a
;; pause was observed.
(define (feed-loop! pr pg bv start end fnames)
  (let ((rr (parser-feed! pr bv start end)) (rg (parser-feed! pg bv start end)))
    ;; Read BEFORE the disagreement check, and reported separately: the mutual
    ;; `paused?` below is the one the pause protocol is about, but it is zeroed by
    ;; any mutation that makes the lanes diverge at all, which the whole-pass
    ;; sweep showed leaves the pause DRAW's own pin with no record of its own.
    ;; This half says the interpreter paused, whatever the other lane did.
    (let ((ref-paused? (eq? (parser-result-status rr) 'paused)))
      (cond
        ((not (equal? (rfields rr pr fnames) (rfields rg pg fnames)))
         (values (list 'feed start) #f ref-paused?))
        ((and (eq? (parser-result-status rr) 'paused) (eq? (parser-result-status rg) 'paused))
         (let ((acks (resume-pair! pr pg)))
           (if (not (equal? (car acks) (cadr acks)))
               (values (list 'feed-ack start) #t #t)
               (let-values (((bad _paused? _ref?)
                             (feed-loop! pr pg bv (parser-result-next rr) end fnames)))
                 (values bad #t #t)))))
        (else (values 'none #f ref-paused?))))))

;; parser-finish! both sides, honouring the same pause protocol as
;; feed-loop! -- a finish pause (D4(d)'s idle-completion route) resumes to
;; finish-ready and finishes again, which falls through to the real executor
;; rather than a sticky short-circuit: finish-ready is not one of
;; parser-finish!'s sticky rows. This branch is unexercised by THIS lane's
;; own generated machines today: a byte-reachable pausep's continuation is
;; always 'start (never a finish-only route), so parser-finish! can only ever
;; resolve directly to finished/error for a property-generated machine, never
;; through a pause of its own -- kept for parity with the general operation
;; matrix and differential-pause-tests.sps's own finish-pause handling.
;; Returns (values bad paused? finished?): bad/paused? as feed-loop!;
;; finished? is #t iff both sides agreed on a 'finished status (the eof
;; draw's idle-completion route -- see the finished-count anti-vacuity guard
;; below).
(define (finish-loop! pr pg fnames)
  (let ((rr (parser-finish! pr)) (rg (parser-finish! pg)))
    (let ((ref-paused? (eq? (parser-result-status rr) 'paused)))
      (cond
        ((not (equal? (rfields rr pr fnames) (rfields rg pg fnames)))
         (values (list 'finish) #f #f ref-paused?))
        ((and (eq? (parser-result-status rr) 'paused) (eq? (parser-result-status rg) 'paused))
         (let ((acks (resume-pair! pr pg)))
           (if (not (equal? (car acks) (cadr acks)))
               (values (list 'finish-ack) #t #f #t)
               (let-values (((bad _paused? finished? _ref?) (finish-loop! pr pg fnames)))
                 (values bad #t finished? #t)))))
        (else (values 'none #f (eq? (parser-result-status rr) 'finished) ref-paused?))))))

;; One byte's trial: a fresh parser pair, fed the single byte and driven
;; through feed-loop!'s pause protocol, then -- only when both sides are
;; still `ready` afterward -- finished the same way. A pair that already
;; reached stopped/error via feed is deliberately NOT finished: parser-
;; finish! on a sticky lifecycle short-circuits inside the shared runtime.sls
;; wrapper before reaching either executor (D1), so that comparison would
;; only check the wrapper against itself and prove nothing about either
;; side. Returns (values bad paused? finished?): bad is 'none or (cons b
;; <feed-loop!/finish-loop! tag>) -- the byte number wrapped around whatever
;; phase tag the sub-loop reported, so a disagreement replays without also
;; having to grep for which of the 256 bytes it was.
;;
;; Slice ③ adds two more flags, both read from the parsers AFTER the trial has
;; settled and both requiring BOTH lanes to show the same thing -- a flag one
;; lane raised alone is a disagreement `bad` has already recorded, and must not
;; also count as a witness.
;;
;; A parser already in `error` answers a zero-length feed with its stored result
;; (the sticky rows in runtime.sls), which is how the reason is recovered here
;; without threading results back out of the loops.
;;
;; Each returns a PAIR: (agreed? . interpreter-only?). The agreed half is the one
;; that matters for the property -- a flag one lane raised alone is a
;; disagreement `bad` has already recorded, and must not also count as a witness.
;; The interpreter-only half exists for ATTRIBUTION, and the whole-pass sweep is
;; what showed it was needed: with only the agreed half, every one of these
;; counters is zeroed by ANY mutation that makes the two lanes diverge, so the
;; sweep found the accumulate pins nesting inside the byte-test inversion -- they
;; produced no record it did not also produce. The interpreter-only counters
;; separate "the arm never ran" from "the lanes disagreed about it", and the
;; second is not this draw's business.
(define (accumulated? pr pg fnames)
  ;; 25 is the accumulate draw's initial (machine-gen.sls). A value other than it
  ;; means the digit arm ran its multiply-add and committed.
  (if (null? fnames)
      '(#f . #f)
      (let ((a (parser-field-ref pr (car fnames))) (g (parser-field-ref pg (car fnames))))
        (cons (and (equal? a g) (not (= a 25))) (not (= a 25))))))

(define (overflow-reason? p)
  (and (eq? (parser-lifecycle p) 'error)
       (let ((e (parser-result-error (parser-feed! p (make-bytevector 0) 0 0))))
         ;; The overflow declaration's own reason. It exists precisely so this is
         ;; distinguishable from the fallback `rejected` terminal, which every
         ;; machine reaches on most of its 256 bytes.
         (and e (string=? (parser-error-reason e) "field overflow")))))

(define (overflowed? pr pg fnames)
  (if (null? fnames)
      '(#f . #f)
      (let ((r (overflow-reason? pr)))
        (cons (and r (overflow-reason? pg)) r))))

(define (byte-trial cm-ref cm-gen b fnames)
  (let ((pr (make-parser cm-ref '() #f)) (pg (make-parser cm-gen '() #f)))
    (let-values (((bad paused? finished? ref-paused?)
                  (let-values (((bad paused? rp) (feed-loop! pr pg (make-bytevector 1 b) 0 1 fnames)))
                    (cond
                      ((not (eq? bad 'none)) (values (cons b bad) paused? #f rp))
                      ((and (eq? (parser-lifecycle pr) 'ready) (eq? (parser-lifecycle pg) 'ready))
                       (let-values (((fbad fpaused? fin? frp) (finish-loop! pr pg fnames)))
                         (values (if (eq? fbad 'none) fbad (cons b fbad))
                                 (or paused? fpaused?) fin? (or rp frp))))
                      (else (values bad paused? #f rp))))))
      (values (cons paused? ref-paused?) bad finished?
              (accumulated? pr pg fnames)
              (overflowed? pr pg fnames)))))

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
        ;; paused-count / finished-count are the anti-vacuity guards for the
        ;; Slice 3 pause and eof draws (machine-gen.sls): a seed set where a
        ;; draw never fires, or fires but is never actually observed by a
        ;; real 256-byte trial, would make every pause/finish check below
        ;; vacuous, so this asserts the property lane actually drove at
        ;; least one generated machine through a real pause, and at least
        ;; one through a real idle-completion finish.
        ;;
        ;; finished-count is a CONJUNCTION its name does not show: byte-trial
        ;; only finishes a pair still `ready` after its feed, so reaching
        ;; 'finished needs the eof draw to have routed the entry's eof-target
        ;; to `done` AND at least one of that machine's 256 bytes to leave
        ;; both parsers ready -- a free byte case targeting `start` or
        ;; `pausep` rather than a terminal. That makes the assertion stronger
        ;; than it reads, not weaker.
        ;;
        ;; *** Re-measured for Slice ③ (2026-09-03). *** The accumulate draw
        ;; takes two numbers from the same stream, so the whole seeded sequence
        ;; re-rolled and every count below moved: of the 40 machines, 8 finish
        ;; (was 14) and 4 pause (was 7), while 25 declare a field, 13 commit a
        ;; digit and 13 overflow. The margins are thinner than they were and are
        ;; stated so a future draw that thins them further is visible as a
        ;; change to this number rather than as a mutation quietly losing its
        ;; witness. But
        ;; a future seed or vocabulary change could zero the byte-case half of
        ;; the conjunction while the eof draw still fires, and that would
        ;; present as the eof draw's own mutation losing its witness -- for a
        ;; reason nobody would find without this sentence.
        (let loop ((i 0) (s (make-prng seed)) (paused-count 0) (finished-count 0)
                   (field-count 0) (acc-count 0) (over-count 0)
                   (acc-ref-count 0) (over-ref-count 0) (paused-ref-count 0))
          (if (< i machine-count)
              (let-values (((m fnames s2) (gen-machine s)))
                (let ((v (verify-machine m)))
                  (check (string-append "machine " (number->string i) " verifies")
                         (verification-ok? v))
                  (if (verification-ok? v)
                      (let ((cm-ref (make-interpreted-machine v))
                            (cm-gen (emit-and-load m i)))
                        (let bl ((b 0) (bad 'none) (paused? '(#f . #f)) (finished? #f)
                                 (acc? '(#f . #f)) (over? '(#f . #f)))
                          (if (< b 256)
                              (let-values (((b-paused b-bad b-finished? b-acc b-over)
                                            (byte-trial cm-ref cm-gen b fnames)))
                                (bl (+ b 1)
                                    (if (eq? bad 'none) b-bad bad)
                                    (cons (or (car paused?) (car b-paused))
                                          (or (cdr paused?) (cdr b-paused)))
                                    (or finished? b-finished?)
                                    (cons (or (car acc?) (car b-acc)) (or (cdr acc?) (cdr b-acc)))
                                    (cons (or (car over?) (car b-over)) (or (cdr over?) (cdr b-over)))))
                              (begin
                                (check-equal
                                 (string-append "machine " (number->string i)
                                                " (seed " (number->string seed) ") byte agreement")
                                 bad 'none)
                                (loop (+ i 1) s2
                                      (if (car paused?) (+ paused-count 1) paused-count)
                                      (if finished? (+ finished-count 1) finished-count)
                                      (if (pair? fnames) (+ field-count 1) field-count)
                                      (if (car acc?) (+ acc-count 1) acc-count)
                                      (if (car over?) (+ over-count 1) over-count)
                                      (if (cdr acc?) (+ acc-ref-count 1) acc-ref-count)
                                      (if (cdr over?) (+ over-ref-count 1) over-ref-count)
                                      (if (cdr paused?) (+ paused-ref-count 1) paused-ref-count))))))
                      (loop (+ i 1) s2 paused-count finished-count
                            field-count acc-count over-count
                            acc-ref-count over-ref-count paused-ref-count))))
              (begin
                (check (string-append "at least one of the " (number->string machine-count)
                                      " generated machines' 256-byte trial observes a pause")
                       (>= paused-count 1))
                (check (string-append "at least one of the " (number->string machine-count)
                                      " generated machines' 256-byte trial observes an"
                                      " idle-completion finish")
                       (>= finished-count 1))
                ;; Slice ③'s accumulate draw. THREE guards, not one, because the
                ;; node has three arms and drawing it proves only that it was
                ;; constructed. The non-digit arm needs no guard of its own: it is
                ;; what every non-digit byte routed to `accp` takes, and the
                ;; machines counted below all have such bytes.
                (check "at least one generated machine declares a field"
                       (>= field-count 1))
                (check "at least one generated machine's trial commits a digit"
                       (>= acc-count 1))
                ;; The overflow arm is reachable only because the pinned case's
                ;; digit is drawn from all ten and the initial is 25: digits 6-9
                ;; overflow a u8 in a single byte, digits 0-5 do not. A change to
                ;; either constant can zero this without zeroing the one above.
                (check "at least one generated machine's trial overflows the field"
                       (>= over-count 1))
                ;; The interpreter-only halves. They are what attributes a dead
                ;; arm to the DRAW rather than to a divergence between the lanes:
                ;; a mutation that breaks the emitter zeroes the two above and
                ;; leaves these standing, and a mutation that makes the arm
                ;; unreachable fails these too. Without them the sweep found both
                ;; accumulate pins nesting inside the byte-test inversion.
                (check "the interpreter alone commits a digit"
                       (>= acc-ref-count 1))
                (check "the interpreter alone overflows the field"
                       (>= over-ref-count 1))
                ;; The same separation for the PAUSE draw, whose pin the sweep
                ;; found nesting for exactly the same reason -- it predates
                ;; Slice ③ and is closed here because the fix is the one already
                ;; being written two lines up, not because ③ introduced it.
                (check "the interpreter alone observes a pause"
                       (>= paused-ref-count 1)))))))))

(harness-finish)
