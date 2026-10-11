;;; The counted body INSIDE A SPAN, in both lanes -- the fragment trace with
;;; per-feed event placement over every schedule. Every rule here runs at the
;;; parser-feed! seam or in the span-end substeps; this lane is the oracle: six
;;; span rules over a counted body (the "rule N" groups: 2, 4, 5, 8, 9, 10), the
;;; PLACEMENT of the completion event asserted as a value per feed against a
;;; table derived from the schedule before the run (the one value lane agreement
;;; cannot see -- a symmetric wrong reading puts the completion in the
;;; delimiter's feed in both lanes), the schedule alphabet with same-schedule
;;; exactness and cross-schedule coalesced invariance, the error path, and both
;;; machine variants (with and without the completion callback).
;;;
;;; Every feed is driven by an explicit left-to-right loop, never `map` (R6RS
;;; leaves map's order unspecified). One recorder per lane, each with its own
;;; accumulator.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test counted-machine)
        (byte-machine graph) (byte-machine verify)
        (byte-machine interpret) (byte-machine compile) (byte-machine runtime))

(harness-begin "differential.counted-span")

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-counted-span "no tmpdir" #f)))

(define (generated m name binding libname)
  (let ((f (string-append tmpdir "/generated-" name ".sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) binding p)))
    (load f)
    (eval binding (environment (list 'generated libname)))))

(define m-full (make-counted-span-machine #t))
(define m-bare (make-counted-span-machine #f))
(define v-full (verify-machine m-full))
(define v-bare (verify-machine m-bare))

(harness-group "the machine verifies clean in both variants"
  (lambda ()
    (harness-case "with and without the completion callback"
      (lambda ()
        (check-equal "full: no diagnostics" (map diagnostic-code (verification-diagnostics v-full)) '())
        (check-equal "bare: no diagnostics" (map diagnostic-code (verification-diagnostics v-bare)) '())))))

(define cm-full-ref (make-interpreted-machine v-full))
(define cm-full-gen (generated m-full "counted-span-full" 'spanfull-parser 'spanfull))
(define cm-bare-ref (make-interpreted-machine v-bare))
(define cm-bare-gen (generated m-bare "counted-span-bare" 'spanbare-parser 'spanbare))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (bytes . bs) (u8-list->bytevector bs))

;; A recorder per lane. Events are `(data n)` -- the fragment's LENGTH, which is
;; what placement and coalescing need -- and `complete`. `answers` is consumed one
;; element per data invocation, so a case can say "pause on the second fragment";
;; exhausted, it continues. `events` returns what was recorded since the last
;; call and clears it, so a caller reads per feed; `trace` returns everything.
(define (recorder answers done-answer)
  (let ((since '()) (all '()) (pending answers))
    (define (note e) (set! since (cons e since)) (set! all (cons e all)))
    (list
     (lambda (ps ux bv from to)
       (note (list 'data (- to from)))
       (if (null? pending) callback-continue
           (let ((a (car pending))) (set! pending (cdr pending)) a)))
     (lambda (ps ux) (note 'complete) done-answer)
     (lambda () (let ((t (reverse since))) (set! since '()) t))
     (lambda () (reverse all)))))

(define (make-lane cm answers done-answer with-complete)
  (let* ((r (recorder answers done-answer))
         (p (make-parser cm
                         (cons (list 'on-data (car r))
                               (if with-complete (list (list 'on-done (cadr r))) '()))
                         'ctx)))
    (list p (caddr r) (cadddr r))))

;; One step's observation: the result's status, consumed and offset, the error
;; code (or #f), the lifecycle, the parked node, the active span, the count, and
;; the events recorded DURING the step.
(define (observe r p events)
  (list (and r (parser-result-status r))
        (and r (parser-result-consumed r))
        (and r (parser-result-stream-offset r))
        (and r (parser-result-error r) (parser-error-code (parser-result-error r)))
        (parser-lifecycle p)
        (parser-state-name p)
        (parser-active-span p)
        (parser-field-ref p 'len)
        (events)))

;; A script is a list of steps: (feed "str") | (slice bv start end) | (finish) | (resume).
(define (run lane script)
  (let ((p (car lane)) (events (cadr lane)))
    (let loop ((ss script) (out '()))
      (if (null? ss) (reverse out)
          (let* ((s (car ss))
                 (r (case (car s)
                      ((feed) (let ((bv (str->bv (cadr s)))) (parser-feed! p bv 0 (bytevector-length bv))))
                      ((slice) (parser-feed! p (cadr s) (caddr s) (cadddr s)))
                      ((finish) (parser-finish! p))
                      ((resume) (parser-resume! p) #f)
                      (else (assertion-violation 'run "unknown step" s)))))
            (loop (cdr ss) (cons (observe r p events) out)))))))

;; Drive both lanes of a variant; assert `expected` (one observation per step)
;; against EACH lane by name, then the lanes against each other.
(define (both label variant script answers done-answer expected)
  (let* ((full? (eq? variant 'full))
         (ref (if full? cm-full-ref cm-bare-ref))
         (gen (if full? cm-full-gen cm-bare-gen))
         (a (run (make-lane ref answers done-answer full?) script))
         (b (run (make-lane gen answers done-answer full?) script)))
    (check-equal (string-append "interpreter: " label) a expected)
    (check-equal (string-append "generated: " label) b expected)
    (check-equal (string-append "the lanes agree: " label) a b)))

;; (status consumed offset code lifecycle state span len events)
(define (obs status consumed offset code lifecycle state span len events)
  (list status consumed offset code lifecycle state span len events))

(harness-group "the span end delivers the body after a bulk commit"
  (lambda ()
    (harness-case "3:abc, in one feed: one fragment of three, then the completion, then idle"
      (lambda ()
        (both "one message" 'full '((feed "3:abc,")) '() callback-continue
              (list (obs 'need-input 6 6 #f 'ready 'idle #f 0 '((data 3) complete))))))
    (harness-case "the bare variant delivers the fragment and closes the span with no completion event"
      (lambda ()
        (both "one message, no completion callback" 'bare '((feed "3:abc,")) '() callback-continue
              (list (obs 'need-input 6 6 #f 'ready 'idle #f 0 '((data 3)))))))))

(harness-group "a feed boundary flushes and the span stays open"
  (lambda ()
    (harness-case "3:ab then c,: the flush delivers ab, the span stays open with the count remaining, c completes it"
      (lambda ()
        (both "partial then remainder" 'full '((feed "3:ab") (feed "c,")) '() callback-continue
              (list (obs 'need-input 4 4 #f 'ready 'body 'sp 1 '((data 2)))
                    (obs 'need-input 2 6 #f 'ready 'idle #f 0 '((data 1) complete))))))))

(harness-group "an empty span delivers one empty fragment"
  (lambda ()
    (harness-case "0:, in one feed delivers one empty fragment (data 0) then the completion"
      (lambda ()
        (both "zero body, one feed" 'full '((feed "0:,")) '() callback-continue
              (list (obs 'need-input 3 3 #f 'ready 'idle #f 0 '((data 0) complete))))))
    (harness-case "0:, byte at a time: the empty fragment and completion land in the : feed, the , feed records nothing"
      (lambda ()
        ;; The zero count takes its route at once: the `:` feed opens the span,
        ;; transitions, and the span END delivers the one empty fragment (the
        ;; body delivered nothing, so the empty fragment is the span's only
        ;; fragment) before firing the completion and parking on the delimiter
        ;; dispatch.
        (both "zero body, byte at a time" 'full '((feed "0") (feed ":") (feed ",")) '() callback-continue
              (list (obs 'need-input 1 1 #f 'ready 'len #f 0 '())
                    (obs 'need-input 1 2 #f 'ready 'comma #f 0 '((data 0) complete))
                    (obs 'need-input 1 3 #f 'ready 'idle #f 0 '())))))))

(harness-group "a pause DURING the flush commits the fragment and the count survives"
  (lambda ()
    (harness-case "3:ab with the data callback pausing: paused at the boundary, count 1, span open; resume; c, completes"
      (lambda ()
        ;; The flush is not a machine step: cursor and offset are the need-input
        ;; tuple's, the field is untouched (only the counted op writes it), and the
        ;; committed fragment is never re-delivered after the re-anchor.
        (both "pause in the flush" 'full '((feed "3:ab") (resume) (feed "c,"))
              (list callback-pause) callback-continue
              (list (obs 'paused 4 4 #f 'paused-feed 'body 'sp 1 '((data 2)))
                    (obs #f #f #f #f 'ready 'body 'sp 1 '())
                    (obs 'need-input 2 6 #f 'ready 'idle #f 0 '((data 1) complete))))))))

(harness-group "a pause at the span-end fragment resumes into the completion"
  (lambda ()
    (harness-case "3:abc with the data callback pausing on the span end's fragment: resume, then , delivers the completion only"
      (lambda ()
        (both "pause between the substeps" 'full '((feed "3:abc") (resume) (feed ","))
              (list callback-pause) callback-continue
              (list (obs 'paused 5 5 #f 'paused-feed 'close 'sp 0 '((data 3)))
                    (obs #f #f #f #f 'ready 'close 'sp 0 '())
                    (obs 'need-input 1 6 #f 'ready 'idle #f 0 '(complete))))))))

(harness-group "EOF with the span open truncates -- no final fragment, no completion"
  (lambda ()
    (harness-case "3:ab then finish: the body's own truncation, eof at offset 4, the flush's fragment still in the trace"
      (lambda ()
        (both "truncation with the span open" 'full '((feed "3:ab") (finish)) '() callback-continue
              (list (obs 'need-input 4 4 #f 'ready 'body 'sp 1 '((data 2)))
                    (obs 'error 0 4 'eof 'error 'trunc2 'sp 1 '())))))))

(harness-group "the span variant: two messages in one feed, two completions in one trace"
  (lambda ()
    (harness-case "3:abc,0:, in one feed"
      (lambda ()
        (both "two messages, two completions" 'full '((feed "3:abc,0:,")) '() callback-continue
              ;; The second message's body is empty, so its span delivers one
              ;; empty fragment (data 0) before its completion.
              (list (obs 'need-input 9 9 #f 'ready 'idle #f 0 '((data 3) complete (data 0) complete))))))))

;; --- the placement oracle, per schedule ------------------------------------------
;;
;; The payload is `3:abc,` -- stream offsets 0..5, the body at 2, 3 and 4. For a
;; schedule (a list of (bv start end) slices) the expected per-feed record is
;; DERIVED from cumulative slice lengths before the run: a feed whose stream range
;; ends inside the body flushes the body bytes it delivered; the feed whose range
;; covers offset 4 delivers the last fragment through the span end and then the
;; completion; a feed that delivers no body byte records nothing; and the count
;; after a feed is 3 less the body bytes delivered so far, 0 after the delimiter.
(define pay (str->bv "3:abc,"))
(define padded (bytes 200 201 51 58 97 98 99 44 202))   ; XX3:abc,Y
(define nothing (make-bytevector 0))

(define (splits)
  (let loop ((k 0) (acc '()))
    (if (> k 6) (reverse acc)
        (loop (+ k 1) (cons (list (list pay 0 k) (list pay k 6)) acc)))))
(define (pairs)
  (let outer ((i 0) (acc '()))
    (if (> i 6) (reverse acc)
        (outer (+ i 1)
               (let inner ((j i) (a acc))
                 (if (> j 6) a
                     (inner (+ j 1) (cons (list (list pay 0 i) (list pay i j) (list pay j 6)) a))))))))
(define others
  (list
   (list (list pay 0 6))
   (list (list nothing 0 0) (list pay 0 6))
   (list (list pay 0 2) (list nothing 0 0) (list pay 2 6))
   (list (list pay 0 6) (list nothing 0 0))
   (list (list pay 0 3) (list pay 3 3) (list pay 3 6))
   (list (list padded 2 8))
   (list (list padded 2 5) (list padded 5 8))
   (list (list padded 2 4) (list padded 4 6) (list padded 6 8))
   (list (list pay 0 1) (list pay 1 2) (list pay 2 3) (list pay 3 4) (list pay 4 5) (list pay 5 6))
   (list (list pay 0 0) (list pay 0 2) (list nothing 0 0) (list pay 2 2) (list pay 2 6))))
(define (all-schedules) (append (splits) (pairs) others))

;; The derived table: for each slice, (events-with-completion events-bare len span).
(define (expected-per-feed slices with-complete)
  (let loop ((ss slices) (cum 0) (out '()))
    (if (null? ss) (reverse out)
        (let* ((sl (car ss)) (n (- (caddr sl) (cadr sl))) (from cum) (to (+ cum n))
               ;; body bytes delivered by this feed: offsets in [from,to) ∩ [2,5)
               (body-from (max from 2)) (body-to (min to 5))
               (delivered (max 0 (- body-to body-from)))
               (completes (and (> to 4) (<= from 4)))          ; offset 4 in [from,to)
               (data (if (> delivered 0) (list (list 'data delivered)) '()))
               (events (append data (if (and completes with-complete) '(complete) '())))
               (len (cond ((<= to 0) 0) ((<= to 2) 3) ((<= to 5) (- 3 (- to 2))) (else 0)))
               (span (if (and (>= to 2) (< to 5)) 'sp #f)))
          (loop (cdr ss) to (cons (list events len span) out))))))

(define (drive-per-feed cm slices with-complete)
  (let* ((lane (make-lane cm '() callback-continue with-complete))
         (p (car lane)) (events (cadr lane)))
    (let loop ((ss slices) (out '()))
      (if (null? ss) (reverse out)
          (begin
            (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))
            (loop (cdr ss) (cons (list (events) (parser-field-ref p 'len) (parser-active-span p)) out)))))))

(harness-group "the completion lands in the feed that delivered the last body byte, under every schedule"
  (lambda ()
    (harness-case "the byte-at-a-time schedule, per feed, in each lane"
      (lambda ()
        ;; The schedule that separates the placement rule from its misreading,
        ;; spelled out: a wrong reading puts the completion in the `,` feed in
        ;; BOTH lanes.
        (let ((sched (list (list pay 0 1) (list pay 1 2) (list pay 2 3) (list pay 3 4) (list pay 4 5) (list pay 5 6)))
              (want '((() 3 #f) (() 3 sp) (((data 1)) 2 sp) (((data 1)) 1 sp) (((data 1) complete) 0 #f) (() 0 #f))))
          (check-equal "derived table" (expected-per-feed sched #t) want)
          (check-equal "interpreter: byte-at-a-time per-feed events, count and span"
                       (drive-per-feed cm-full-ref sched #t) want)
          (check-equal "generated: byte-at-a-time per-feed events, count and span"
                       (drive-per-feed cm-full-gen sched #t) want))))
    (harness-case "every schedule, both variants, both lanes, against the derived table"
      (lambda ()
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each
              (lambda (variant)
                (let* ((full? (eq? variant 'full))
                       (want (expected-per-feed sl full?))
                       (a (drive-per-feed (if full? cm-full-ref cm-bare-ref) sl full?))
                       (b (drive-per-feed (if full? cm-full-gen cm-bare-gen) sl full?)))
                  (unless (equal? a want) (set! bad (cons (list driven variant 'interpreter a want) bad)))
                  (unless (equal? b want) (set! bad (cons (list driven variant 'generated b want) bad)))))
              '(full bare)))
           (all-schedules))
          (check-equal "forty-five schedules driven" driven 45)
          (check-equal "and the generator's length agrees" driven (length (all-schedules)))
          (check-equal "every feed of every schedule matches its derived record" bad '()))))))

;; --- schedules: same-schedule exactness, coalesced invariance, the error path ---
(define (record-span cm slices with-complete)
  (let* ((lane (make-lane cm '() callback-continue with-complete)) (p (car lane)))
    (for-each (lambda (sl) (parser-feed! p (car sl) (cadr sl) (caddr sl))) slices)
    (let ((r (parser-finish! p)))
      (list ((caddr lane))
            (parser-result-status r)
            (parser-result-stream-offset r)
            (and (parser-result-error r) (parser-error-code (parser-result-error r)))))))

(define (coalesce trace)
  ;; Data lengths between completions are summed; completions are kept.
  (let loop ((t trace) (acc 0) (out '()))
    (cond ((null? t) (reverse (if (> acc 0) (cons (list 'data acc) out) out)))
          ((eq? (car t) 'complete) (loop (cdr t) 0 (cons 'complete (cons (list 'data acc) out))))
          (else (loop (cdr t) (+ acc (cadr (car t))) out)))))

(harness-group "same schedule: the two lanes agree exactly"
  (lambda ()
    (harness-case "every schedule produces the identical trace and finish in both lanes"
      (lambda ()
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (let ((a (record-span cm-full-ref sl #t)) (b (record-span cm-full-gen sl #t)))
               (unless (equal? a b) (set! bad (cons (list driven a b) bad)))))
           (all-schedules))
          (check-equal "forty-five schedules driven" driven 45)
          (check-equal "every schedule agrees across the lanes" bad '()))))))

(harness-group "across schedules: coalesced is invariant, raw is not"
  (lambda ()
    (harness-case "the coalesced trace equals the one-feed baseline under every schedule"
      (lambda ()
        (let ((baseline (coalesce (car (record-span cm-full-ref (list (list pay 0 6)) #t))))
              (differing '()) (raws '()) (driven 0))
          (check-equal "the baseline" baseline '((data 3) complete))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each (lambda (cm)
                         (let ((raw (car (record-span cm sl #t))))
                           (unless (member raw raws) (set! raws (cons raw raws)))
                           (unless (equal? (coalesce raw) baseline)
                             (set! differing (cons (list driven raw) differing)))))
                       (list cm-full-ref cm-full-gen)))
           (all-schedules))
          (check-equal "forty-five schedules driven" driven 45)
          (check-equal "no schedule's coalesced trace differs" differing '())
          (check "the raw traces are schedule-dependent" (> (length raws) 1)))))))

(harness-group "the error path, per lane and across schedules"
  (lambda ()
    (harness-case "a truncated body delivers no completion and one (error 4 eof) under every schedule"
      (lambda ()
        (let* ((t (str->bv "3:ab"))
               (schedules (list (list (list t 0 4))
                                (list (list t 0 1) (list t 1 4))
                                (list (list t 0 2) (list t 2 4))
                                (list (list t 0 3) (list t 3 4))
                                (list (list t 0 1) (list t 1 2) (list t 2 3) (list t 3 4))
                                (list (list t 0 2) (list nothing 0 0) (list t 2 4))))
               (driven 0) (seen '()) (completed '()))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each (lambda (cm)
                         (let ((r (record-span cm sl #t)))
                           (when (memq 'complete (car r)) (set! completed (cons driven completed)))
                           (let ((k (list (cadr r) (caddr r) (cadddr r))))
                             (unless (member k seen) (set! seen (cons k seen))))))
                       (list cm-full-ref cm-full-gen)))
           schedules)
          (check-equal "six schedules driven" driven 6)
          (check-equal "no schedule synthesizes a completion" completed '())
          (check-equal "one acceptance/offset/code triple across all of them" seen '((error 4 eof))))))
    (harness-case "the prefix is compared exactly between lanes on one schedule"
      (lambda ()
        (let ((t (str->bv "3:ab")))
          (check-equal "the same trace on the split schedule"
                       (record-span cm-full-ref (list (list t 0 3) (list t 3 4)) #t)
                       (record-span cm-full-gen (list (list t 0 3) (list t 3 4)) #t))
          (check-equal "and it is the flush's one fragment"
                       (car (record-span cm-full-ref (list (list t 0 3) (list t 3 4)) #t))
                       '((data 1) (data 1))))))))

(harness-finish)
