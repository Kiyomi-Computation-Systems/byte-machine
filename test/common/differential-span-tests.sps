;;; interpreter ≡ generated over the two span kinds (Milestone 5 Slice ③;
;;; parent §14:831-843, §19.3:1024, §22.4:1268-1271).
;;;
;;; Slice ② compared what a callback ANSWERS. A span callback answers the same
;;; three things (§13:812), so what is new here is what it is HANDED: a range of
;;; the caller's bytevector, chosen by rules that live in three different places
;;; -- the span end (§14:832), the feed boundary (§14:834) and the empty-fragment
;;; suppression that governs both (§14:835). Every one of those rules can be
;;; wrong in one lane and right in the other, and none of them is visible in a
;;; parser result: two lanes can agree on `(stopped 5 5 5 #f stopped)` while
;;; delivering different bytes to the application.
;;;
;;; So the compared object here is the FRAGMENT TRACE -- one recording closure
;;; per lane, each with its own accumulator, each copying the slice inside the
;;; callback's dynamic extent (§13:799 permits exactly that, and §28:1725
;;; forbids the runtime from retaining the bytevector, so a trace that did not
;;; copy would be reading whatever the next feed put there).
;;;
;;; Task 5's six rules, one group each:
;;;   a nonempty fragment at the span end          §14:832
;;;   an empty one suppressed                      §14:835
;;;   a flush at a feed boundary, span still open  §14:833-834
;;;   a pause DURING the flush                     §14:837
;;;   a pause between the span-end substeps        §14:838, §14:841-842
;;;   an error with a span open                    §14:839
;;;
;;; The oracle over §22.5's schedule list is Task 6's. This file is the
;;; both-lanes fixture the plan puts BEFORE it: without it, a lowering defect
;;; would first be seen by a test whose own schedule table is the thing under
;;; construction.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine graph) (byte-machine verify)
        (byte-machine interpret) (byte-machine compile) (byte-machine runtime))

(harness-begin "differential.span")

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-span "no tmpdir" #f)))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define trunc-decl (make-error-declaration 'truncated 'eof "span truncated" #f))

;; `A` opens, everything up to `Z` is the payload, `Z` closes it and stops.
;;
;; Four verifier rules shaped this graph, and each was found by building it:
;;
;;   - `body`'s Z case REEXECUTES. A span end emits `[mark,cursor)` (§14:832), so
;;     consuming Z on the way in would put the delimiter inside the payload.
;;   - `body`'s eof-target is an ERROR and not `fin`: §14:843 rejects reaching a
;;     successful finish with a span active, and this is pass 7's
;;     `span-active-at-exit`. That the error terminal is ACCEPTED there is
;;     decision 0023 item 5's kept distinction doing work.
;;   - nothing between `sopen` and `sclose` may pause or invoke an event or
;;     decision callback (§13:826) -- only the span's own data callback may --
;;     so `body` is a bare dispatch node.
;;   - `fin` is on the EOF side only (§16.2:908).
(define (span-machine complete-cb)
  (make-machine 'spanm 'start '()
    (cons (make-callback-declaration 'ondata 'span-data #t '() #f #f)
          (if complete-cb
              (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f))
              '()))
    (list (make-span-declaration 'payload 'ondata complete-cb #f))
    (list eof-decl rej-decl trunc-decl)
    ;; `start`'s EOF route is a WHOLE SPAN on the EOF chain, and it is there so
    ;; that the interpreter's three finish-path arms are executed by something.
    ;; They are written out separately from the feed loop's -- each records its
    ;; own lifecycle -- so a fixture reaching spans only through `parser-feed!`
    ;; leaves half the interpreted span implementation unrun. It also witnesses
    ;; the EOF side's own theorem: the fragment there is `[mark,0)`, which is
    ;; empty for every mark.
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'sopen 'advance) #f))
            (make-edge 'reject 'reexecute) 'eopen #f)
          (make-span-start-node 'eopen 'payload 'eclose #f)
          (make-span-end-node 'eclose 'payload 'fin #f)
          (make-span-start-node 'sopen 'payload 'body #f)
          (make-byte-dispatch-node 'body
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'sclose 'reexecute) #f))
            (make-edge 'body 'advance) 'trunc #f)
          (make-span-end-node 'sclose 'payload 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'trunc 'truncated #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

;; TWO machines, because the emitter renders TWO span-completion arms and only
;; one of them is a call. §10.4:516 makes the completion callback optional at the
;; DECLARATION, and an absent one lowers to a substep that closes the span and
;; jumps -- a shape no test would otherwise load, which is the failure mode
;; Slice ② named: an emitted arm nothing executes.
(define m-full (span-machine 'ondone))
(define m-bare (span-machine #f))
(define v-full (verify-machine m-full))
(define v-bare (verify-machine m-bare))

(define (generated m v name binding libname)
  (let ((f (string-append tmpdir "/generated-" name ".sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) binding p)))
    (load f)
    (eval binding (environment (list 'generated libname)))))

(define cm-full-ref (make-interpreted-machine v-full))
(define cm-full-gen (generated m-full v-full "span-full" 'span-parser 'spanm))
(define cm-bare-ref (make-interpreted-machine v-bare))
;; A DIFFERENT binding and file: `load` twice into one library name would leave
;; whichever ran last resident under both.
(define cm-bare-gen (generated m-bare v-bare "span-bare" 'span-bare-parser 'spanm))

(define (bytes . bs) (u8-list->bytevector bs))
(define (frag bv from to)
  ;; §13:799: the callback may copy within its dynamic extent, and must if it
  ;; wants the bytes afterwards. THIS is that copy -- the trace is a list of
  ;; fresh bytevectors, never of (bv from to) triples, because a triple would
  ;; still be describing storage the runtime is forbidden to keep (§28:1725).
  (let ((out (make-bytevector (- to from))))
    (let loop ((i from))
      (if (>= i to) out
          (begin (bytevector-u8-set! out (- i from) (bytevector-u8-ref bv i))
                 (loop (+ i 1)))))))

;; `answers` is a list consumed one element per DATA invocation, so a case can
;; say "continue, then pause on the second fragment" without counting
;; invocations from outside. Exhausted, it continues -- a shorter list means
;; "and continue from there", not "stop being defined".
(define (recorder answers done-answer)
  (let ((trace '()) (pending answers))
    (list
     (lambda (ps ux bv from to)
       (set! trace (cons (frag bv from to) trace))
       (if (null? pending) callback-continue
           (let ((a (car pending))) (set! pending (cdr pending)) a)))
     (lambda (ps ux)
       (set! trace (cons 'complete trace))
       done-answer)
     (lambda () (reverse trace)))))

;; Each lane gets its OWN recorder: Slice ②'s plan asked for one closure shared
;; by both parsers, which yields one interleaved list with nothing to compare it
;; to. The correction is carried forward here rather than rediscovered.
(define (make-lane cm answers done-answer with-complete)
  (let* ((r (recorder answers done-answer))
         (p (make-parser cm
                         (cons (list 'ondata (car r))
                               (if with-complete (list (list 'ondone (cadr r))) '()))
                         'ctx)))
    (list p (caddr r))))

(define (rfields r p)
  (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
        (parser-result-stream-offset r) (project-error (parser-result-error r))
        (parser-lifecycle p)))

;; A SCRIPT of feeds, so a case states its schedule as data. Each step is
;; `(feed BYTES...)`, `(finish)` or `(resume)`; the answer is the list of result
;; tuples plus the fragment trace and the parser's final active span.
(define (run lane script)
  (let ((p (car lane)) (trace-of (cadr lane)))
    (let loop ((ss script) (out '()) (n 0))
      (if (or (null? ss) (> n 12))
          (list (reverse out) (trace-of) (parser-active-span p))
          (let* ((s (car ss))
                 (r (case (car s)
                      ((feed) (let ((b (cadr s)))
                                (parser-feed! p b 0 (bytevector-length b))))
                      ;; A SUB-slice, so `start` is not always 0. §14:833 makes
                      ;; the mark a slice offset and §14:834 re-anchors it to the
                      ;; next feed's `start`; with every feed starting at 0, that
                      ;; re-anchor and a bare `0` are the same program.
                      ((feed-slice) (parser-feed! p (cadr s) (caddr s) (cadddr s)))
                      ((finish) (parser-finish! p))
                      ((resume) (parser-resume! p) #f)
                      (else (assertion-violation 'run "unknown step" s)))))
            (loop (cdr ss) (if r (cons (rfields r p) out) out) (+ n 1)))))))

;; The comparison, in one place: drive the same script down both lanes and answer
;; the disagreement rather than a boolean. `n` bounds `run`'s own loop -- the
;; mutation suite has no per-mutant timeout, and a mutant that makes a feed
;; return `need-input` forever would otherwise hang the whole suite rather than
;; fail this case.
(define (both script answers done-answer)
  (let ((a (run (make-lane cm-full-ref answers done-answer #t) script))
        (b (run (make-lane cm-full-gen answers done-answer #t) script)))
    (list a b (equal? a b))))

(harness-group "the machine verifies clean in both shapes"
  (lambda ()
    (harness-case "no diagnostics, with and without a completion callback"
      (lambda ()
        ;; First, because every comparison below is vacuous on a machine the
        ;; verifier rejected: neither lane would have been built.
        (check-equal "with" (map diagnostic-code (verification-diagnostics v-full)) '())
        (check-equal "without" (map diagnostic-code (verification-diagnostics v-bare)) '())))))

(harness-group "a span end delivers [mark,cursor) and exactly one completion (§14:832)"
  (lambda ()
    (harness-case "one feed, one nonempty fragment, then the completion"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 98 99 100 90)))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "one fragment then one completion"
                       (cadr (car r)) (list (bytes 98 99 100) 'complete))
          (check-equal "and the span is inactive afterwards" (caddr (car r)) #f)
          ;; The GENERATED lane's own trace and span, as values. Agreement alone
          ;; cannot separate three different emitter defects -- a span start that
          ;; marks 0, a span end that slices to `end`, and a completion substep
          ;; that never closes -- because all three show up only as "the lanes
          ;; disagree". These two checks are what tell them apart.
          (check-equal "the generated lane's own fragment"
                       (cadr (cadr r)) (list (bytes 98 99 100) 'complete))
          (check-equal "and its span is inactive too" (caddr (cadr r)) #f)
          (check-equal "the feed stopped on the delimiter"
                       (car (car (car r))) '(stopped 5 5 5 #f stopped)))))
    (harness-case "the fragment is the payload and not the whole slice"
      (lambda ()
        ;; Without this, a lane that delivered `[0,end)` -- the whole slice, mark
        ;; ignored -- would still deliver ONE fragment and still agree with a
        ;; sibling that did the same. The bytes are the assertion.
        (let ((r (both (list (list 'feed (bytes 65 98 99 100 90)))
                       '() callback-continue)))
          (check "the fragment excludes the opener and the delimiter"
                 (not (equal? (car (cadr (car r))) (bytes 65 98 99 100 90)))))))))

(harness-group "an empty fragment is suppressed (§14:835)"
  (lambda ()
    (harness-case "AZ delivers no data callback at all, only the completion"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 90))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "completion only" (cadr (car r)) '(complete)))))))

(harness-group "a feed boundary flushes and the span stays open (§14:833-834)"
  (lambda ()
    (harness-case "two feeds, two fragments, one completion"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 98 99))
                             (list 'feed (bytes 100 90)))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "flushed, then the remainder, then the completion"
                       (cadr (car r)) (list (bytes 98 99) (bytes 100) 'complete))
          (check-equal "the first feed asked for input"
                       (car (car (car r))) '(need-input 3 3 3 #f ready)))))
    (harness-case "the span is still active between the two feeds"
      (lambda ()
        ;; §14:834's "remains logically open", asserted where it is observable:
        ;; after the flush and before the close. A lane that closed the span at
        ;; the boundary would still produce the same two fragments.
        (let* ((lane (make-lane cm-full-ref '() callback-continue #t))
               (mid (run lane (list (list 'feed (bytes 65 98 99))))))
          (check-equal "interpreted" (caddr mid) 'payload))
        (let* ((lane (make-lane cm-full-gen '() callback-continue #t))
               (mid (run lane (list (list 'feed (bytes 65 98 99))))))
          (check-equal "generated" (caddr mid) 'payload))))
    (harness-case "a fragment is never delivered twice across the boundary"
      (lambda ()
        ;; The mark re-anchor (§14:834) is what makes this true, and a count
        ;; cannot see it: re-delivering `bc` would give three fragments, but so
        ;; would splitting `bcd` differently. The SEQUENCE is the oracle.
        (let ((r (both (list (list 'feed (bytes 65 98 99))
                             (list 'feed (bytes 100 101 90)))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "bc then de, never bc twice"
                       (cadr (car r))
                       (list (bytes 98 99) (bytes 100 101) 'complete)))))))

(harness-group "the mark is a SLICE offset (§14:833)"
  (lambda ()
    (harness-case "two sub-slices, neither starting at 0"
      (lambda ()
        ;; Both feeds carry padding the span must not see. A lane re-anchoring
        ;; the mark to a bare 0 instead of to `start` would hand the callback
        ;; the padding, and every case above would still pass -- they all feed
        ;; whole bytevectors, where the two are indistinguishable.
        (let ((r (both (list (list 'feed-slice (bytes 7 65 98 99) 1 4)
                             (list 'feed-slice (bytes 7 7 100 90) 2 4))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the padding is in neither fragment"
                       (cadr (car r)) (list (bytes 98 99) (bytes 100) 'complete)))))))

(harness-group "a pause DURING the flush commits the fragment (§14:837)"
  (lambda ()
    (harness-case "the feed reports paused, the span stays open, resume continues"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 98 99))
                             (list 'resume)
                             (list 'feed (bytes 100 90)))
                       (list callback-pause) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          ;; The whole slice was consumed BEFORE the flush ran -- the flush is
          ;; not a machine step and moves neither cursor nor offset -- so the
          ;; tuple is the need-input tuple with its status rewritten.
          (check-equal "paused at the boundary, not at a byte"
                       (car (car (car r))) '(paused 3 3 3 #f paused-feed))
          (check-equal "the fragment was committed anyway"
                       (cadr (car r)) (list (bytes 98 99) (bytes 100) 'complete)))))
    (harness-case "the paused feed reports the boundary, not a byte"
      (lambda ()
        ;; The status alone, with no `resume` in the script, so a lane that
        ;; reported `need-input` for a flush pause is caught HERE by a value
        ;; rather than three cases later by a lifecycle violation the harness
        ;; reports as a bare raise.
        (let ((r (both (list (list 'feed (bytes 65 98 99)))
                       (list callback-pause) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "paused, and parked where the executor left it"
                       (car (car (car r))) '(paused 3 3 3 #f paused-feed)))))
    (harness-case "the flush pause is not re-delivered on the next feed"
      (lambda ()
        ;; §14:837's "resume begins with the next supplied input". A lane that
        ;; re-anchored the mark to the OLD slice's offset would re-emit `bc`, or
        ;; emit a slice of the new bytevector nobody asked for.
        (let ((r (both (list (list 'feed (bytes 65 98 99))
                             (list 'resume)
                             (list 'feed (bytes 100 90)))
                       (list callback-pause) callback-continue)))
          (check-equal "two fragments, in order"
                       (map (lambda (f) (if (bytevector? f) (bytevector->u8-list f) f))
                            (cadr (car r)))
                       (list '(98 99) '(100) 'complete)))))))

(harness-group "a pause between the span-end substeps (§14:838, §14:841-842)"
  (lambda ()
    (harness-case "the data substep pauses; resume delivers only the completion"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 98 99 100 90))
                             (list 'resume)
                             (list 'feed (bytes 90)))
                       (list callback-pause) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the fragment, then the completion -- each once"
                       (cadr (car r)) (list (bytes 98 99 100) 'complete))
          (check-equal "the pause is reported at the delimiter"
                       (car (car (car r))) '(paused 4 4 4 #f paused-feed)))))
    (harness-case "the span is STILL ACTIVE while parked between the substeps"
      (lambda ()
        ;; §14:842 makes the span inactive *before* the completion callback and
        ;; not before the pause, so this is the one moment a paused parser
        ;; answers a span name. Both lanes, because the two park on different
        ;; things -- a compound name here, a numbered internal state there.
        (let* ((la (make-lane cm-full-ref (list callback-pause) callback-continue #t))
               (a (run la (list (list 'feed (bytes 65 98 99 100 90)))))
               (lb (make-lane cm-full-gen (list callback-pause) callback-continue #t))
               (b (run lb (list (list 'feed (bytes 65 98 99 100 90))))))
          (check-equal "interpreted" (caddr a) 'payload)
          (check-equal "generated" (caddr b) 'payload))))
    (harness-case "the completion substep pauses, and the span is already inactive"
      (lambda ()
        ;; §14:842: "Before invoking the completion callback, execution makes the
        ;; span inactive." A lane that closed the span AFTER the callback would
        ;; be caught only here -- every fragment and every tuple is identical.
        (let* ((la (make-lane cm-full-ref '() callback-pause #t))
               (a (run la (list (list 'feed (bytes 65 98 99 100 90)))))
               (lb (make-lane cm-full-gen '() callback-pause #t))
               (b (run lb (list (list 'feed (bytes 65 98 99 100 90))))))
          (check-equal "the lanes agree" a b)
          (check-equal "inactive at the completion pause" (caddr a) #f)
          (check-equal "and the fragment was already delivered"
                       (cadr a) (list (bytes 98 99 100) 'complete)))))))

(harness-group "an error with a span open (§14:839)"
  (lambda ()
    (harness-case "no final fragment, no completion, earlier fragments observable"
      (lambda ()
        ;; All three clauses of §14:839 in one script: `bc` flushed at the feed
        ;; boundary, then EOF with the span still open takes `body`'s eof-target
        ;; into the error terminal.
        (let ((r (both (list (list 'feed (bytes 65 98 99)) (list 'finish))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "only the flushed fragment" (cadr (car r)) (list (bytes 98 99)))
          ;; §12.7:768's `eof` position kind, and the node named is the ERROR
          ;; terminal the EOF chain reached -- `body` routed there rather than
          ;; raising there. The projection carries the declaration's CATEGORY
          ;; (§9.4), not its name, which is why `truncated` appears only as the
          ;; reason text.
          (check-equal "the finish is the truncation error"
                       (cadr (car (car r)))
                       '(error 3 0 3 (machine eof "span truncated" trunc 3 eof) error)))))
    (harness-case "an error mid-slice flushes nothing either"
      (lambda ()
        ;; The other error shape: the span never opens, so there is nothing to
        ;; flush. Present so the group's first case cannot pass by a lane that
        ;; suppresses ALL fragments on any error path.
        (let ((r (both (list (list 'feed (bytes 66))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "no fragments at all" (cadr (car r)) '()))))))

(harness-group "a span declaring no completion callback (§10.4:516)"
  (lambda ()
    (harness-case "the substep still closes the span, and calls nothing"
      (lambda ()
        (let* ((la (make-lane cm-bare-ref '() callback-continue #f))
               (a (run la (list (list 'feed (bytes 65 98 99 100 90)))))
               (lb (make-lane cm-bare-gen '() callback-continue #f))
               (b (run lb (list (list 'feed (bytes 65 98 99 100 90))))))
          (check-equal "the lanes agree" a b)
          (check-equal "the fragment, and no completion marker"
                       (cadr a) (list (bytes 98 99 100)))
          (check-equal "the span is inactive" (caddr a) #f)
          (check-equal "and the walk still reached the stop"
                       (car (car a)) '(stopped 5 5 5 #f stopped)))))))

(harness-group "a span on the EOF chain (§12.4:729, §14:835)"
  (lambda ()
    (harness-case "finish opens and closes a span, delivering no fragment"
      (lambda ()
        ;; Nothing is consumed at finish, so `[mark,0)` is empty for every mark
        ;; and §14:835 suppresses it -- which is exactly why `parser-finish-op!`
        ;; takes no bytevector. A lane that delivered a fragment here would have
        ;; had to slice something, and there is nothing to slice.
        (let ((r (both (list (list 'finish)) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "completion only, no data" (cadr (car r)) '(complete))
          (check-equal "and the walk finished"
                       (car (car (car r))) '(finished 0 0 0 #f finished))
          (check-equal "with the span inactive" (caddr (car r)) #f))))
    (harness-case "a completion callback may pause during EOF (§12.4:729)"
      (lambda ()
        (let ((r (both (list (list 'finish) (list 'resume) (list 'finish))
                       '() callback-pause)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "paused-finish, then finished"
                       (map car (car (car r))) '(paused finished))
          ;; §13:814: the completion event was committed before the pause, so
          ;; resuming must not deliver it again.
          (check-equal "the completion is delivered exactly once"
                       (cadr (car r)) '(complete)))))))

(harness-group "reset clears span state (§12.5:739)"
  (lambda ()
    (harness-case "a parser parked mid-span answers #f after a reset, in both lanes"
      (lambda ()
        ;; F2: the reset comment said span state "still does not exist". It does
        ;; now, and §12.5:739 lists it FIRST among what a full reset clears.
        (let* ((la (make-lane cm-full-ref '() callback-continue #t))
               (a (run la (list (list 'feed (bytes 65 98 99)))))
               (lb (make-lane cm-full-gen '() callback-continue #t))
               (b (run lb (list (list 'feed (bytes 65 98 99))))))
          (check-equal "active before" (list (caddr a) (caddr b)) '(payload payload))
          (parser-reset! (car la))
          (parser-reset! (car lb))
          (check-equal "inactive after"
                       (list (parser-active-span (car la)) (parser-active-span (car lb)))
                       '(#f #f))
          ;; And the reset parser parses again from the top -- a cleared name
          ;; with a stale mark would deliver the wrong bytes here, which no
          ;; accessor can see.
          (let ((a2 (run la (list (list 'feed (bytes 65 98 99 100 90)))))
                (b2 (run lb (list (list 'feed (bytes 65 98 99 100 90))))))
            (check-equal "and re-parses identically" a2 b2)
            ;; The recorder outlives the reset, so index 0 is still the `bc`
            ;; the pre-reset flush delivered. What follows it is the whole
            ;; assertion: ONE fragment carrying the entire payload. A reset that
            ;; cleared the name but kept the mark would split it here, and
            ;; `parser-active-span` cannot see that.
            (check-equal "with the whole payload in one fragment"
                         (list-tail (cadr a2) 1)
                         (list (bytes 98 99 100) 'complete))))))))

(harness-finish)
