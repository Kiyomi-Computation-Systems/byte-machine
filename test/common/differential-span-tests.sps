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
        ;; `error-state-id` too: §12.7:777 keeps the id out of the projection and
        ;; still requires one, so the only way to assert it is beside.
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
    ;; *** THE COMPLETION CALLBACK IS DECLARED FIRST, and that ordering is the
    ;; assertion. *** Four sites resolve a span to its DATA callback's slot --
    ;; the interpreter's two `*-parts` procedures and the emitter's span-start
    ;; and span-end arms -- and with `ondata` declared first every one of them is
    ;; satisfied by the constant 0. Declaring `ondone` first puts `ondata` at
    ;; slot 1, so a lane that hard-coded 0 would invoke the COMPLETION callback
    ;; where a fragment belongs and the trace would say so.
    (if complete-cb
        (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
              (make-callback-declaration 'ondata 'span-data #t '() #f #f))
        (list (make-callback-declaration 'ondata 'span-data #t '() #f #f)))
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
    ;; No step bound. One stood here as `(> n 12)` with a comment saying it
    ;; guarded the mutation suite against a hanging mutant; the final review
    ;; found it could not fire -- every script in this file is a literal of at
    ;; most three steps -- and could not do the job either, since a mutant that
    ;; hangs does so INSIDE `parser-feed!`, which no counter out here can
    ;; interrupt.
    (let loop ((ss script) (out '()))
      (if (null? ss)
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
            (loop (cdr ss) (if r (cons (rfields r p) out) out)))))))

;; The comparison, in one place: drive the same script down both lanes and answer
;; the disagreement rather than a boolean.
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

(harness-group "a FAILURE during the flush is a callback-domain error"
  (lambda ()
    (harness-case "the feed reports error, and the flush's own arm builds it"
      (lambda ()
        ;; *** THE THIRD OUTCOME OF THE FLUSH, and nothing in the tree executed
        ;; it until the final review said so. *** `span-boundary-flush!` has
        ;; goto, pause and failure arms; the two above drive the first two, and
        ;; the failure arm could be deleted with the suite green.
        ;;
        ;; It is the ONE callback-domain error in the tree that no machine node
        ;; produces -- the flush is not a machine step -- so the node name comes
        ;; from `parser-state-name` and the state id from the data callback's
        ;; SLOT. The §22.4:1271 projection carries domain, code, reason, node,
        ;; OFFSET and kind, so the slot is not in it; what this row pins is that
        ;; the parked node's own name and §12.7:770's `boundary` survive a flush,
        ;; and the state id is asserted per lane below.
        (let ((r (both (list (list 'feed (bytes 65 98 99)))
                       (list (make-callback-failure 'flush-said-no #f))
                       callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the fragment was delivered before the failure"
                       (cadr (car r)) (list (bytes 98 99)))
          (check-equal "and the feed is an error at the boundary"
                       (car (car (car r)))
                       '(error 3 3 3 (callback flush-said-no "callback failure"
                                      body 3 boundary)
                         error)))))
    (harness-case "the state id it carries is the DATA callback's slot, in both lanes"
      (lambda ()
        ;; §12.7:777 excludes the id from the cross-lane comparison and still
        ;; requires an integer. Here it is a value: slot 1, because this lane's
        ;; machine declares the COMPLETION callback first -- so a lane hard-coding
        ;; 0 answers the wrong integer and this is the only check that sees it.
        (let ((ids (map (lambda (cm)
                          (let ((lane (make-lane cm (list (make-callback-failure 'x #f))
                                                 callback-continue #t)))
                            (parser-feed! (car lane) (bytes 65 98 99) 0 3)
                            (error-state-id
                             (parser-result-error
                              (parser-feed! (car lane) (bytes 98) 0 1)))))
                        (list cm-full-ref cm-full-gen))))
          (check-equal "both lanes report the data callback's slot" ids '(1 1)))))))

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
    (harness-case "the fragment and the status TOGETHER, which is what separates two mutants"
      (lambda ()
        ;; *** THE PAIR, NOT EITHER HALF. *** The status assertion above is
        ;; printed byte-for-byte by a DIFFERENT defect -- a flush that never runs
        ;; at all also reports `need-input` here -- so on its own it does not
        ;; attribute the catch. Measured, and it is what the final review found.
        ;; The two part on the FRAGMENT: a flush that ran and mis-reported its
        ;; status still delivered `bc`, and one that never ran delivered nothing.
        (let* ((lane (make-lane cm-full-ref (list callback-pause) callback-continue #t))
               (r (run lane (list (list 'feed (bytes 65 98 99))))))
          (check-equal "delivered, and reported as a pause"
                       (list (cadr r) (car (car r)))
                       (list (list (bytes 98 99)) '(paused 3 3 3 #f paused-feed))))))
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



;; --- Task 6: the oracle (§22.4:1269, §22.5:1286-1289, §25:1590) -------------
;;
;; The groups above assert what ONE schedule does. §22.5 asks two further
;; questions, and they pull in opposite directions:
;;
;;   - for the SAME schedule, the two lanes must have identical fragment
;;     boundaries (§22.5:1285) -- exact ranges and contents (§22.4:1269);
;;   - ACROSS schedules, they must not. §22.5:1287 calls fragment boundaries
;;     "intentionally schedule-dependent" and §14:836 tells consumers not to read
;;     meaning into them. What is invariant is the trace COALESCED per logical
;;     span.
;;
;; So a test that pinned raw boundaries across schedules would assert the
;; opposite of the contract. This file asserts the coalesced trace is invariant
;; AND that the raw one is not -- the second is what keeps the first from being
;; a statement about a constant.

(define pay (bytes 65 98 99 100 90))
(define padded (bytes 200 201 65 98 99 100 90 202))
(define nothing (make-bytevector 0))

;; §22.5's list, over the same five logical bytes. The shape is Slice ②'s, which
;; is deliberate: a second, differently-written schedule table would be a second
;; thing to keep in step with §22.5 rather than one.
(define (span-splits)
  (let loop ((k 0) (acc '()))
    (if (> k 5) (reverse acc)
        (loop (+ k 1) (cons (list (list pay 0 k) (list pay k 5)) acc)))))
(define (span-pairs)
  (let outer ((i 0) (acc '()))
    (if (> i 5) (reverse acc)
        (outer (+ i 1)
               (let inner ((j i) (a acc))
                 (if (> j 5) a
                     (inner (+ j 1)
                            (cons (list (list pay 0 i) (list pay i j) (list pay j 5)) a))))))))
(define span-others
  (list
   (list (list pay 0 5))
   ;; leading, intermediate and trailing EMPTY feeds
   (list (list nothing 0 0) (list pay 0 5))
   (list (list pay 0 2) (list nothing 0 0) (list pay 2 5))
   (list (list pay 0 5) (list nothing 0 0))
   ;; an empty slice from the MIDDLE of the real bytevector -- a different shape
   ;; from a zero-length one, and the one that lands a flush on `[k,k)`
   (list (list pay 0 3) (list pay 3 3) (list pay 3 5))
   ;; nonzero start/end into a bytevector carrying unrelated prefix and suffix
   ;; bytes: §22.5's fourth bullet, and the schedule that catches a lane reading
   ;; from index 0 regardless of `start`
   (list (list padded 2 7))
   (list (list padded 2 4) (list padded 4 7))
   (list (list padded 2 3) (list padded 3 5) (list padded 5 7))
   ;; deterministic multi-split schedules, written out: §22.5's "deterministic
   ;; random" bullet is about reproducibility, and a literal is the most
   ;; reproducible form there is.
   (list (list pay 0 1) (list pay 1 2) (list pay 2 3) (list pay 3 4) (list pay 4 5))
   (list (list pay 0 0) (list pay 0 2) (list nothing 0 0) (list pay 2 2) (list pay 2 5))))
(define (all-schedules) (append (span-splits) (span-pairs) span-others))

;; One recording closure per lane, each with its own accumulator -- Slice ②'s
;; correction, which is not optional here: the drivers below alternate the two
;; parsers, so a shared accumulator would interleave them and a lane-swap defect
;; would be invisible.
(define (record-span cm slices answers done-answer)
  (let* ((lane (make-lane cm answers done-answer #t))
         (p (car lane)))
    (for-each (lambda (sl) (parser-feed! p (car sl) (cadr sl) (caddr sl))) slices)
    (let ((r (parser-finish! p)))
      (list ((cadr lane))
            (parser-result-status r)
            (parser-result-stream-offset r)
            (and (parser-result-error r) (parser-error-code (parser-result-error r)))))))

;; §22.5:1286's "normalized semantic trace that coalesces fragments belonging to
;; the same logical span". One concatenation per logical span, emitted even when
;; it is empty -- the normalized form has to be TOTAL, or a span that produced
;; no fragment in one schedule and one empty fragment in another would normalize
;; to two different shapes and the invariance below would be about nothing.
(define (concat bs)
  (let* ((n (let add ((l bs) (k 0)) (if (null? l) k (add (cdr l) (+ k (bytevector-length (car l)))))))
         (out (make-bytevector n)))
    (let put ((l bs) (at 0))
      (if (null? l) out
          (let copy ((i 0))
            (if (>= i (bytevector-length (car l)))
                (put (cdr l) (+ at (bytevector-length (car l))))
                (begin (bytevector-u8-set! out (+ at i) (bytevector-u8-ref (car l) i))
                       (copy (+ i 1)))))))))
(define (coalesce trace)
  (let loop ((t trace) (cur '()) (out '()))
    (cond ((null? t)
           (reverse (if (null? cur) out (cons (concat (reverse cur)) out))))
          ((eq? (car t) 'complete)
           (loop (cdr t) '() (cons 'complete (cons (concat (reverse cur)) out))))
          (else (loop (cdr t) (cons (car t) cur) out)))))

(harness-group "same schedule: the two lanes agree exactly (§22.4:1269, §22.5:1285)"
  (lambda ()
    (harness-case "every schedule produces the identical fragment trace in both lanes"
      (lambda ()
        ;; A sentinel over the schedules DRIVEN, read from the loop, and the
        ;; disagreeing schedule recorded rather than a bare boolean.
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (let ((a (record-span cm-full-ref sl '() callback-continue))
                   (b (record-span cm-full-gen sl '() callback-continue)))
               (unless (equal? a b) (set! bad (cons (list driven a b) bad)))))
           (all-schedules))
          ;; 6 single splits + 21 pairs + 10 others. Counted from the loop AND
          ;; compared against a separately computed total: the literal catches a
          ;; schedule list that silently shrank, the derived total catches a loop
          ;; that stopped early, and neither catches the other.
          (check-equal "thirty-seven schedules driven" driven 37)
          (check-equal "and the length agrees" driven (length (all-schedules)))
          (check-equal "every schedule agrees across the lanes" bad '()))))))

(harness-group "across schedules: coalesced is invariant, raw is not (§22.5:1287)"
  (lambda ()
    (harness-case "the coalesced trace is the same under every schedule"
      (lambda ()
        (let ((baseline (coalesce (car (record-span cm-full-ref (list (list pay 0 5))
                                                    '() callback-continue))))
              (differing '()) (driven 0))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each
              (lambda (cm)
                (let ((c (coalesce (car (record-span cm sl '() callback-continue)))))
                  (unless (equal? c baseline) (set! differing (cons (list driven c) differing)))))
              (list cm-full-ref cm-full-gen)))
           (all-schedules))
          (check-equal "thirty-seven schedules driven" driven 37)
          (check-equal "no schedule changes the coalesced trace" differing '())
          ;; And by VALUE, so the invariance is not invariance around the wrong
          ;; sequence: the payload, whole, then exactly one completion.
          (check-equal "and it is the payload followed by one completion"
                       baseline (list (bytes 98 99 100) 'complete)))))
    (harness-case "the RAW trace is schedule-dependent, which is the contract"
      (lambda ()
        ;; §22.5:1287 and §14:836. Without this, "coalesced is invariant" would
        ;; also hold of an implementation that never split a fragment at all --
        ;; and a test asserting raw boundaries across schedules would be
        ;; asserting the opposite of what the spec says.
        (let ((raws '()))
          (for-each
           (lambda (sl)
             (let ((t (car (record-span cm-full-ref sl '() callback-continue))))
               (unless (member t raws) (set! raws (cons t raws)))))
           (all-schedules))
          (check "the schedules do not all produce one raw trace" (> (length raws) 1))
          (check-equal "one feed gives one fragment"
                       (car (record-span cm-full-ref (list (list pay 0 5))
                                         '() callback-continue))
                       (list (bytes 98 99 100) 'complete))
          (check-equal "and a split mid-payload gives two"
                       (car (record-span cm-full-ref (list (list pay 0 3) (list pay 3 5))
                                         '() callback-continue))
                       (list (bytes 98 99) (bytes 100) 'complete)))))))


;; --- Task 6 step 3: every invalid span topology, enumerated as data ---------
;;
;; §25:1590's exit criterion is "every invalid span topology is rejected" -- a
;; UNIVERSAL over a set the parent plan never enumerates. Slice ⓪'s matrix is
;; the honest shape for that: write the set down, DERIVE each verdict from
;; §14:843 and §16.2:899 before running, and let the count be the sentinel. The
;; bounded invalid-machine generator is Milestone 7's, and this must not quietly
;; become it.
;;
;; Every row shares one skeleton so the graph plumbing cannot differ between
;; them: a one-byte dispatch consuming `A` into the row's head, a reject
;; terminal, and an `exit` dispatch whose EOF route is the finish -- which is
;; where §16.2:908 wants a finish, and keeps the rows differing only in their
;; span shape.
(define (d1 name target eof-target)
  (make-byte-dispatch-node name
    (list (make-byte-case (make-exact-byte-matcher 65) (make-edge target 'advance) #f))
    (make-edge 'reject 'reexecute) eof-target #f))
(define (topo-machine spans nodes)
  (make-machine 'topom 'start '()
    (list (make-callback-declaration 'ondata 'span-data #t '() #f #f)
          (make-callback-declaration 'note 'event #t '() #f #f))
    spans (list eof-decl rej-decl)
    ;; Only the two TERMINALS are shared. `exit` -- the dispatch whose EOF route
    ;; reaches the finish -- is per row: a row whose span ends at a stop or an
    ;; error never routes through it, and appending it anyway made those rows
    ;; report `unreachable-node` on top of the span verdict they were written to
    ;; check. Measured, then narrowed.
    (append nodes (list (make-finish-node 'fin #f)
                        (make-error-node 'reject 'rejected #f)))
    'default-eof #f))
(define one-span (list (make-span-declaration 'payload 'ondata #f #f)))
(define two-spans (list (make-span-declaration 'payload 'ondata #f #f)
                        (make-span-declaration 'other 'ondata #f #f)))
(define (topo-codes spans nodes)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
             (map diagnostic-code
                  (verification-diagnostics (verify-machine (topo-machine spans nodes))))))

;; Each row is (NAME SPANS NODES EXPECTED-CODES DERIVATION). The expectation is
;; written from the section named in the derivation, not from a run.
(define topologies
  (list
   (list 'reentry one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'op2 #f)
               (make-span-start-node 'op2 'payload 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(invalid-span-state)
         "§14:843: no reachable path starts a second span while one is active.")
   (list 'overlap two-spans
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'op2 #f)
               (make-span-start-node 'op2 'other 'cl2 #f)
               (make-span-end-node 'cl2 'other 'cl1 #f)
               (make-span-end-node 'cl1 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         ;; TWO: the overlapping start, and then `cl1` -- the state after `cl2`
         ;; is `none`, so closing `payload` there is an unmatched end. One
         ;; malformed shape, two rejections, and the row says so rather than
         ;; expecting the first and being surprised by the second.
         '(invalid-span-state invalid-span-state)
         "§14:843: a second span starts while one is active, and the outer end is then unmatched.")
   (list 'wrong-end two-spans
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'cl #f)
               (make-span-end-node 'cl 'other 'exit #f)
               (d1 'exit 'exit 'fin))
         '(invalid-span-state)
         "§14:843: ends the wrong span.")
   (list 'unmatched-end one-span
         (list (d1 'start 'cl 'fin)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(invalid-span-state)
         "§14:843: ends with no active span.")
   (list 'pause-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'pz #f)
               (make-pause-node 'pz 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(span-active-at-pause)
         "§13:826: an explicit pause node is invalid where a span is active.")
   (list 'callback-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'cb #f)
               (make-callback-node 'cb 'note 'cl '() 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(span-active-at-pause)
         "§13:826: an event or decision callback invocation is invalid where a span is active.")
   (list 'stop-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'st #f)
               (make-stop-node 'st #f))
         '(span-active-at-exit)
         "§14:843: no reachable path reaches a successful stop with a span active.")
   (list 'finish-inside one-span
         ;; The one row whose plumbing had to be written out, and both
         ;; departures are the lattice's doing rather than taste. `start`'s EOF
         ;; route is the ERROR terminal, because with both routes reaching `fin`
         ;; the join sees `none` from one and `(active payload)` from the other
         ;; and answers `top`. And the in-span dispatch swallows every byte
         ;; rather than falling back to the shared `reject`, for the same reason
         ;; one edge later. One rule per row is the whole point of the table, and
         ;; a row reporting two is a row that checks neither.
         (list (d1 'start 'op1 'reject)
               (make-span-start-node 'op1 'payload 'spin #f)
               (make-byte-dispatch-node 'spin
                 (list (make-byte-case (make-exact-byte-matcher 65)
                                       (make-edge 'spin 'advance) #f))
                 (make-edge 'spin 'advance) 'fin #f))
         '(span-active-at-exit)
         "§14:843: no reachable path reaches a successful finish with a span active.")
   (list 'join-disagree one-span
         ;; Two byte edges into `mrg`: one through the span, one around it. The
         ;; lattice joins `(active payload)` with `none` and answers `top`,
         ;; which decision 0029 item 2 makes a diagnostic at the join itself.
         (list (make-byte-dispatch-node 'start
                 (list (make-byte-case (make-exact-byte-matcher 65)
                                       (make-edge 'op1 'advance) #f)
                       (make-byte-case (make-exact-byte-matcher 66)
                                       (make-edge 'mrg 'advance) #f))
                 (make-edge 'reject 'reexecute) 'fin #f)
               (make-span-start-node 'op1 'payload 'mrg #f)
               (d1 'mrg 'cl 'fin)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(inconsistent-span-state)
         "0029 item 2: incoming edges disagree, the join is `top`, and `top` is reported where it arises.")
   ;; --- the two VALID rows, and they are what keep the table from being a
   ;; list of things that happen to be rejected ---
   (list 'error-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'err #f)
               (make-error-node 'err 'rejected #f))
         '()
         "§14:839 contemplates a span open at an ERROR terminal, which is why decision 0023 item 5 kept finish distinguished from error.")
   (list 'well-formed one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '()
         "The shape every rejected row above is a perturbation of.")))

(harness-group "every invalid span topology is rejected, and only those (§25:1590)"
  (lambda ()
    (harness-case "the enumerated table, row by row"
      (lambda ()
        ;; The count is the sentinel: a row silently dropped from the list would
        ;; otherwise leave this case green while covering less.
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (row)
             (set! driven (+ driven 1))
             (let ((got (topo-codes (cadr row) (caddr row))))
               (unless (equal? got (list-sort (lambda (a b) (string<? (symbol->string a)
                                                                     (symbol->string b)))
                                              (cadddr row)))
                 (set! bad (cons (list (car row) 'want (cadddr row) 'got got) bad)))))
           topologies)
          (check-equal "eleven topologies driven" driven 11)
          (check-equal "and the table's own length agrees" driven (length topologies))
          (check-equal "every row's verdict is the derived one" bad '()))))
    (harness-case "the table is not all-reject or all-accept"
      (lambda ()
        ;; Without this the row loop would pass on a verifier that rejected
        ;; everything, and on one that rejected nothing.
        (let ((verdicts (map (lambda (r) (null? (cadddr r))) topologies)))
          (check "some rows are expected to verify" (memq #t verdicts))
          (check "and some are expected to be rejected" (memq #f verdicts)))))
    (harness-case "all four span codes appear, and each is derived from its own rule"
      (lambda ()
        ;; §16.2:899's four codes as a set. A table exercising three of them
        ;; would satisfy every check above.
        (let ((codes '()))
          (for-each (lambda (r)
                      (for-each (lambda (c) (unless (memq c codes) (set! codes (cons c codes))))
                                (cadddr r)))
                    topologies)
          (check-equal "four distinct rejection codes"
                       (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                                  codes)
                       '(inconsistent-span-state invalid-span-state span-active-at-exit
                         span-active-at-pause)))))))

;; --- Task 6 step 4: the error path (§14:839, §22.5:1289) --------------------

(harness-group "the error path, per lane and across schedules (§14:839, §22.5:1289)"
  (lambda ()
    (harness-case "a truncated span delivers no completion, under every schedule"
      (lambda ()
        ;; §14:839's second clause. The COMPLETION is the thing that must not
        ;; appear -- fragments flushed at earlier boundaries stay observable, and
        ;; how many of them there are is schedule-dependent, so counting them
        ;; across schedules would assert the opposite of §22.5:1287.
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each
              (lambda (cm)
                (let ((r (record-span cm sl '() callback-continue)))
                  (when (memq 'complete (car r))
                    (set! bad (cons (list driven (car r)) bad)))))
              (list cm-full-ref cm-full-gen)))
           ;; The same schedule shapes, over a payload with NO delimiter, so
           ;; every one of them ends at `body`'s EOF route.
           (let ((t (bytes 65 98 99 100)))
             (list (list (list t 0 4))
                   (list (list t 0 1) (list t 1 4))
                   (list (list t 0 2) (list t 2 4))
                   (list (list t 0 3) (list t 3 4))
                   (list (list t 0 1) (list t 1 2) (list t 2 3) (list t 3 4))
                   (list (list t 0 2) (list nothing 0 0) (list t 2 4))
                   (list (list padded 2 6)))))
          (check-equal "seven schedules driven" driven 7)
          (check-equal "no schedule synthesizes a completion" bad '()))))
    (harness-case "acceptance, error category and absolute position agree across schedules"
      (lambda ()
        ;; §22.5:1289 exactly: for malformed inputs these THREE are compared
        ;; across schedules, and the callback prefix is not -- a partial span may
        ;; have been flushed at a boundary in one schedule and not another.
        (let ((seen '()) (driven 0))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each
              (lambda (cm)
                (let ((r (record-span cm sl '() callback-continue)))
                  ;; status, absolute offset, error code -- the trace omitted
                  (let ((k (list (cadr r) (caddr r) (cadddr r))))
                    (unless (member k seen) (set! seen (cons k seen))))))
              (list cm-full-ref cm-full-gen)))
           (let ((t (bytes 65 98 99 100)))
             (list (list (list t 0 4))
                   (list (list t 0 1) (list t 1 4))
                   (list (list t 0 2) (list t 2 4))
                   (list (list t 0 1) (list t 1 2) (list t 2 3) (list t 3 4))
                   (list (list padded 2 6)))))
          (check-equal "five schedules driven" driven 5)
          (check-equal "one acceptance/category/position triple across all of them"
                       ;; `truncated` is the DECLARATION's name; the code a
                       ;; parser error carries is its §9.4 CATEGORY, which is
                       ;; what §22.5:1289 calls the error category.
                       seen '((error 4 eof))))))
    (harness-case "and the callback PREFIX is schedule-dependent, which is why it is not compared"
      (lambda ()
        ;; The sentinel for the case above: if the fragment prefixes happened to
        ;; be schedule-independent too, comparing only three fields would be a
        ;; restriction that costs nothing and proves nothing.
        (let ((t (bytes 65 98 99 100)))
          (check-equal "one feed flushes once"
                       (car (record-span cm-full-ref (list (list t 0 4)) '() callback-continue))
                       (list (bytes 98 99 100)))
          (check-equal "three feeds flush three times"
                       (car (record-span cm-full-ref
                                         (list (list t 0 2) (list t 2 3) (list t 3 4))
                                         '() callback-continue))
                       (list (bytes 98) (bytes 99) (bytes 100))))))
    (harness-case "the success path delivers exactly one completion (§14:835)"
      (lambda ()
        ;; The positive half of §14:839's first two clauses: what the error path
        ;; must NOT do, the success path must do exactly once, under every
        ;; schedule.
        (let ((driven 0) (bad '()))
          (for-each
           (lambda (sl)
             (set! driven (+ driven 1))
             (for-each
              (lambda (cm)
                (let* ((tr (car (record-span cm sl '() callback-continue)))
                       (n (length (filter (lambda (x) (eq? x 'complete)) tr))))
                  (unless (= n 1) (set! bad (cons (list driven n tr) bad)))))
              (list cm-full-ref cm-full-gen)))
           (all-schedules))
          (check-equal "thirty-seven schedules driven" driven 37)
          (check-equal "exactly one completion in every one" bad '()))))))

(harness-finish)
