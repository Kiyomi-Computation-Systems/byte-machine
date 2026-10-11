;;; interpreter ≡ generated over the two span kinds.
;;;
;;; The callback differential compares what a callback ANSWERS. A span callback
;;; answers the same three things, so what is new here is what it is HANDED: a
;;; range of the caller's bytevector, chosen by rules that live in three
;;; different places -- the span end (which delivers even an empty fragment
;;; once), the feed boundary, and the empty-fragment suppression that governs
;;; the flush. Every one of those rules can be wrong in one lane and right in
;;; the other, and none of them is visible in a parser result: two lanes can
;;; agree on `(stopped 5 5 5 #f stopped)` while delivering different bytes to
;;; the application.
;;;
;;; So the compared object here is the FRAGMENT TRACE -- one recording closure
;;; per lane, each with its own accumulator, each copying the slice inside the
;;; callback's dynamic extent (the callback contract permits exactly that, and
;;; forbids the runtime from retaining the bytevector, so a trace that did not
;;; copy would be reading whatever the next feed put there).
;;;
;;; Six rules, one group each:
;;;   a nonempty fragment at the span end
;;;   an empty one delivered once
;;;   a flush at a feed boundary, span still open
;;;   a pause DURING the flush
;;;   a pause between the span-end substeps
;;;   an error with a span open
;;;
;;; The oracle over the schedule list follows them. The fixed-schedule groups
;;; come first so that a lowering defect is seen against one literal schedule,
;;; not first by a test whose own schedule table is also under test.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        ;; `error-state-id` too: the projection leaves the id out and an id is
        ;; still required, so the only way to assert it is beside.
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
;;   - `body`'s Z case REEXECUTES. A span end emits `[mark,cursor)`, so
;;     consuming Z on the way in would put the delimiter inside the payload.
;;   - `body`'s eof-target is an ERROR and not `fin`: reaching a successful
;;     finish with a span active is rejected, and this is pass 7's
;;     `span-active-at-exit`. That the error terminal is ACCEPTED there is the
;;     verifier keeping finish distinct from error.
;;   - nothing between `sopen` and `sclose` may pause or invoke an event or
;;     decision callback -- only the span's own data callback may -- so `body`
;;     is a bare dispatch node.
;;   - `fin` is on the EOF side only.
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
    ;; leaves half the interpreted span implementation unrun. This span opens ON
    ;; the EOF chain, so its mark is 0 and its span end delivers one empty `[0,0)`
    ;; fragment; `parser-finish!`'s re-anchor to 0 makes a carried
    ;; span reach the same `from == to == 0`.
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
;; one of them is a call. The completion callback is optional at the
;; DECLARATION, and an absent one lowers to a substep that closes the span and
;; jumps -- a shape no test would otherwise load: an emitted arm nothing
;; executes.
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
  ;; The callback may copy within its dynamic extent, and must if it wants the
  ;; bytes afterwards. THIS is that copy -- the trace is a list of fresh
  ;; bytevectors, never of (bv from to) triples, because a triple would still
  ;; be describing storage the runtime is forbidden to keep.
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

;; Each lane gets its OWN recorder: one closure shared by both parsers would
;; yield one interleaved list with nothing to compare it to.
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
    ;; No step bound: every script in this file is a literal of at most three
    ;; steps, and a mutant that hangs does so INSIDE `parser-feed!`, which no
    ;; counter out here can interrupt.
    (let loop ((ss script) (out '()))
      (if (null? ss)
          (list (reverse out) (trace-of) (parser-active-span p))
          (let* ((s (car ss))
                 (r (case (car s)
                      ((feed) (let ((b (cadr s)))
                                (parser-feed! p b 0 (bytevector-length b))))
                      ;; A SUB-slice, so `start` is not always 0. The mark is a
                      ;; slice offset, re-anchored to the next feed's `start`;
                      ;; with every feed starting at 0, that re-anchor and a
                      ;; bare `0` are the same program.
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

(harness-group "a span end delivers [mark,cursor) and exactly one completion"
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

;; A span that opens and closes having delivered nothing is OBSERVABLE -- its
;; data callback fires once with an
;; empty range -- so a consumer can tell "an optional field was present and
;; empty" from "this field never happened". The suppression is kept only at the
;; flush and the EOF-side span end (the groups below and "a span on the EOF
;; chain").
(harness-group "an empty span delivers one empty fragment then the completion"
  (lambda ()
    (harness-case "AZ opens and closes having delivered nothing"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 90))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "one empty fragment, then the completion"
                       (cadr (car r)) (list (bytes) 'complete))
          ;; The generated lane's OWN trace, as a value: agreement alone cannot
          ;; tell an empty delivery from a suppression when both lanes do the same.
          (check-equal "the generated lane's own trace"
                       (cadr (cadr r)) (list (bytes) 'complete))
          (check-equal "and the span is inactive afterwards" (caddr (car r)) #f))))))

;; Two hazards of empty-span delivery, both by value: an empty FINAL fragment
;; of a NONEMPTY span is suppressed (the naive `> from to` fix would announce it),
;; and a flush that finds nothing accumulated delivers nothing (and does not set
;; the delivered flag, so a genuinely empty span split across the boundary still
;; delivers once).
(harness-group "an empty final fragment vs an empty span across a feed boundary"
  (lambda ()
    (harness-case "a nonempty span whose final fragment is empty delivers only its real bytes"
      (lambda ()
        ;; feed 1 flushes `bc`; feed 2 closes the span on its first byte with
        ;; from==to, but the span has delivered, so the empty final fragment is
        ;; suppressed.
        (let ((r (both (list (list 'feed (bytes 65 98 99)) (list 'feed (bytes 90)))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the flushed bytes, then the completion -- no empty tail"
                       (cadr (car r)) (list (bytes 98 99) 'complete)))))
    (harness-case "a flush that finds nothing delivers nothing, and the empty span still delivers once"
      (lambda ()
        ;; feed 1 opens the span and ends with nothing accumulated: the flush
        ;; finds from==to and delivers nothing and must NOT set the
        ;; delivered flag. feed 2 closes the still-empty span, so the span END
        ;; delivers the one empty fragment -- a genuinely empty span split across
        ;; the boundary.
        (let* ((lane (make-lane cm-full-ref '() callback-continue #t))
               (mid (run lane (list (list 'feed (bytes 65))))))
          (check-equal "the flush delivered nothing" (cadr mid) '()))
        (let ((r (both (list (list 'feed (bytes 65)) (list 'feed (bytes 90)))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "one empty fragment at the close, nothing before"
                       (cadr (car r)) (list (bytes) 'complete)))))))

(harness-group "a pause on the EMPTY span-end delivery"
  (lambda ()
    (harness-case "the empty fragment pauses; resume delivers only the completion, each once"
      (lambda ()
        (let ((r (both (list (list 'feed (bytes 65 90))
                             (list 'resume)
                             (list 'feed (bytes 90)))
                       (list callback-pause) callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the empty fragment, then the completion -- each once"
                       (cadr (car r)) (list (bytes) 'complete))
          (check-equal "the pause is reported at the delimiter"
                       (car (car (car r))) '(paused 1 1 1 #f paused-feed)))))))

(harness-group "a feed boundary flushes and the span stays open"
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
        ;; The span "remains logically open", asserted where it is observable:
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
        ;; The mark re-anchor is what makes this true, and a count
        ;; cannot see it: re-delivering `bc` would give three fragments, but so
        ;; would splitting `bcd` differently. The SEQUENCE is the oracle.
        (let ((r (both (list (list 'feed (bytes 65 98 99))
                             (list 'feed (bytes 100 101 90)))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "bc then de, never bc twice"
                       (cadr (car r))
                       (list (bytes 98 99) (bytes 100 101) 'complete)))))))

(harness-group "the mark is a SLICE offset"
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
        ;; *** THE THIRD OUTCOME OF THE FLUSH. *** `span-boundary-flush!` has
        ;; goto, pause and failure arms; the two above drive the first two, and
        ;; without this case the failure arm could be deleted with the suite
        ;; green.
        ;;
        ;; It is the ONE callback-domain error in the tree that no machine node
        ;; produces -- the flush is not a machine step -- so the node name comes
        ;; from `parser-state-name` and the state id from the data callback's
        ;; SLOT. The error projection carries domain, code, reason, node, OFFSET
        ;; and kind, so the slot is not in it; what this row pins is that the
        ;; parked node's own name and the `boundary` position kind survive a
        ;; flush, and the state id is asserted per lane below.
        (let ((r (both (list (list 'feed (bytes 65 98 99)))
                       (list (make-callback-failure 'flush-said-no #f))
                       callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "the fragment was delivered before the failure"
                       (cadr (car r)) (list (bytes 98 99)))
          (check-equal "and the feed is an error at the boundary"
                       (car (car (car r)))
                       ;; The failure leaves `payload` open, and the flush HANDED
                       ;; `bc` to the callback that failed -- so the error names
                       ;; the span with nothing withheld, [3,3).
                       '(error 3 3 3 (callback flush-said-no "callback failure"
                                      body 3 boundary payload 3)
                         error)))))
    (harness-case "the state id it carries is the DATA callback's slot, in both lanes"
      (lambda ()
        ;; The projection excludes the id from the cross-lane comparison, and
        ;; the id must still be an integer. Here it is a value: slot 1, because this lane's
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

(harness-group "a pause DURING the flush commits the fragment"
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
        ;; attribute the catch. The two part on the FRAGMENT: a flush that ran and mis-reported its
        ;; status still delivered `bc`, and one that never ran delivered nothing.
        (let* ((lane (make-lane cm-full-ref (list callback-pause) callback-continue #t))
               (r (run lane (list (list 'feed (bytes 65 98 99))))))
          (check-equal "delivered, and reported as a pause"
                       (list (cadr r) (car (car r)))
                       (list (list (bytes 98 99)) '(paused 3 3 3 #f paused-feed))))))
    (harness-case "the flush pause is not re-delivered on the next feed"
      (lambda ()
        ;; After a flush pause, resume begins with the next supplied input. A lane that
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

(harness-group "a pause between the span-end substeps"
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
        ;; The span becomes inactive *before* the completion callback and not
        ;; before the pause, so this is the one moment a paused parser
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
        ;; Before invoking the completion callback, execution makes the span
        ;; inactive. A lane that closed the span AFTER the callback would
        ;; be caught only here -- every fragment and every tuple is identical.
        (let* ((la (make-lane cm-full-ref '() callback-pause #t))
               (a (run la (list (list 'feed (bytes 65 98 99 100 90)))))
               (lb (make-lane cm-full-gen '() callback-pause #t))
               (b (run lb (list (list 'feed (bytes 65 98 99 100 90))))))
          (check-equal "the lanes agree" a b)
          (check-equal "inactive at the completion pause" (caddr a) #f)
          (check-equal "and the fragment was already delivered"
                       (cadr a) (list (bytes 98 99 100) 'complete)))))))

(harness-group "an error with a span open"
  (lambda ()
    (harness-case "no final fragment, no completion, earlier fragments observable"
      (lambda ()
        ;; All three clauses of the error-with-a-span-open rule in one script:
        ;; `bc` flushed at the feed boundary, then EOF with the span still open
        ;; takes `body`'s eof-target into the error terminal.
        (let ((r (both (list (list 'feed (bytes 65 98 99)) (list 'finish))
                       '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "only the flushed fragment" (cadr (car r)) (list (bytes 98 99)))
          ;; The `eof` position kind, and the node named is the ERROR terminal
          ;; the EOF chain reached -- `body` routed there rather than raising
          ;; there. The projection carries the declaration's CATEGORY, not its
          ;; name, which is why `truncated` appears only as the reason text.
          (check-equal "the finish is the truncation error"
                       (cadr (car (car r)))
                       ;; The error abandons `payload`, whose bytes the flush
                       ;; already handed over -- nothing withheld, [3,3).
                       '(error 3 0 3 (machine eof "span truncated" trunc 3 eof payload 3)
                         error)))))
    (harness-case "an error mid-slice flushes nothing either"
      (lambda ()
        ;; The other error shape: the span never opens, so there is nothing to
        ;; flush. Present so the group's first case cannot pass by a lane that
        ;; suppresses ALL fragments on any error path.
        (let ((r (both (list (list 'feed (bytes 66))) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "no fragments at all" (cadr (car r)) '()))))))

(harness-group "a span declaring no completion callback"
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

(harness-group "a span on the EOF chain"
  (lambda ()
    (harness-case "finish opens and closes a span: one empty fragment, then completion"
      (lambda ()
        ;; The span opens ON the EOF chain, so its mark is 0, and finish runs over
        ;; cursor 0 -- `[0,0)` is a COHERENT empty range, so the span END delivers
        ;; it once, exactly as a feed-side empty span does. The generated lane
        ;; reaches this through the SAME emitted span-end arm it uses in a feed
        ;; (parser-finish-v2! runs `exec` with finish? and cursor 0), so both
        ;; lanes deliver here without any emitted-text change. A span CARRIED from a feed into finish is the different shape:
        ;; its mark is uncoordinated, so `from > to` and the step's `from == to`
        ;; guard suppresses -- not reachable in this machine, whose only EOF-chain
        ;; span opens at finish.
        (let ((r (both (list (list 'finish)) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "one empty fragment, then the completion"
                       (cadr (car r)) (list (bytes) 'complete))
          (check-equal "and the walk finished"
                       (car (car (car r))) '(finished 0 0 0 #f finished))
          (check-equal "with the span inactive" (caddr (car r)) #f))))
    (harness-case "a completion callback may pause during EOF"
      (lambda ()
        (let ((r (both (list (list 'finish) (list 'resume) (list 'finish))
                       '() callback-pause)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "paused-finish, then finished"
                       (map car (car (car r))) '(paused finished))
          ;; The completion event was committed before the pause, so
          ;; resuming must not deliver it again; the empty data fragment was
          ;; delivered on the first finish and is not re-delivered either.
          (check-equal "the empty fragment then the completion, each once"
                       (cadr (car r)) (list (bytes) 'complete)))))))

(harness-group "reset clears span state"
  (lambda ()
    (harness-case "a parser parked mid-span answers #f after a reset, in both lanes"
      (lambda ()
        ;; Span state is the first thing a full reset clears.
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



;; --- the schedule oracle -----------------------------------------------------
;;
;; The groups above assert what ONE schedule does. Two further questions pull
;; in opposite directions:
;;
;;   - for the SAME schedule, the two lanes must have identical fragment
;;     boundaries -- exact ranges and contents;
;;   - ACROSS schedules, they must not. Fragment boundaries are intentionally
;;     schedule-dependent, and consumers are told not to read meaning into
;;     them. What is invariant is the trace COALESCED per logical span.
;;
;; So a test that pinned raw boundaries across schedules would assert the
;; opposite of the contract. This file asserts the coalesced trace is invariant
;; AND that the raw one is not -- the second is what keeps the first from being
;; a statement about a constant.

(define pay (bytes 65 98 99 100 90))
(define padded (bytes 200 201 65 98 99 100 90 202))
(define nothing (make-bytevector 0))

;; The schedule list, over the same five logical bytes. The shape is
;; `differential-callback-tests.sps`'s, deliberately: a second,
;; differently-written schedule table would be a second thing to keep in step
;; with the schedule list rather than one.
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
   ;; bytes: the schedule that catches a lane reading from index 0 regardless
   ;; of `start`
   (list (list padded 2 7))
   (list (list padded 2 4) (list padded 4 7))
   (list (list padded 2 3) (list padded 3 5) (list padded 5 7))
   ;; deterministic multi-split schedules, written out: a "deterministic
   ;; random" schedule is about reproducibility, and a literal is the most
   ;; reproducible form there is.
   (list (list pay 0 1) (list pay 1 2) (list pay 2 3) (list pay 3 4) (list pay 4 5))
   (list (list pay 0 0) (list pay 0 2) (list nothing 0 0) (list pay 2 2) (list pay 2 5))))
(define (all-schedules) (append (span-splits) (span-pairs) span-others))

;; One recording closure per lane, each with its own accumulator -- not
;; optional here: the drivers below alternate the two
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

;; The normalized semantic trace, coalescing fragments belonging to the same
;; logical span. One concatenation per logical span, emitted even when
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

(harness-group "same schedule: the two lanes agree exactly"
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

(harness-group "across schedules: coalesced is invariant, raw is not"
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
        ;; Without this, "coalesced is invariant" would
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


;; --- every invalid span topology, enumerated as data ------------------------
;;
;; "Every invalid span topology is rejected" is a UNIVERSAL over a set nothing
;; else enumerates. A matrix is the honest shape for that: write the set down,
;; DERIVE each verdict from the span rules before running, and let the count be
;; the sentinel.
;;
;; The bounded invalid-machine generator (the corruption catalogue and the
;; independent oracle in property-rejections-tests.sps) is a different job: it
;; corrupts DRAWN machines one decision at a time, its oracle re-derives the
;; graph rules, and it keeps pass 7's span-state lattice outside that oracle.
;; This table is a HAND-DERIVED census of span topologies with per-row verdicts
;; derived before running, and is the nearest thing to the universal.
;;
;; Every row shares one skeleton so the graph plumbing cannot differ between
;; them: a one-byte dispatch consuming `A` into the row's head, a reject
;; terminal, and an `exit` dispatch whose EOF route is the finish -- which is
;; where a finish belongs, and keeps the rows differing only in their span
;; shape.
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
    ;; check.
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
;; written from the rule stated in the derivation, not from a run.
(define topologies
  (list
   (list 'reentry one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'op2 #f)
               (make-span-start-node 'op2 'payload 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(invalid-span-state)
         "no reachable path starts a second span while one is active.")
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
         "a second span starts while one is active, and the outer end is then unmatched.")
   (list 'wrong-end two-spans
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'cl #f)
               (make-span-end-node 'cl 'other 'exit #f)
               (d1 'exit 'exit 'fin))
         '(invalid-span-state)
         "ends the wrong span.")
   (list 'unmatched-end one-span
         (list (d1 'start 'cl 'fin)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(invalid-span-state)
         "ends with no active span.")
   (list 'pause-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'pz #f)
               (make-pause-node 'pz 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(span-active-at-pause)
         "an explicit pause node is invalid where a span is active.")
   (list 'callback-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'cb #f)
               (make-callback-node 'cb 'note 'cl '() 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '(span-active-at-pause)
         "an event or decision callback invocation is invalid where a span is active.")
   (list 'stop-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'st #f)
               (make-stop-node 'st #f))
         '(span-active-at-exit)
         "no reachable path reaches a successful stop with a span active.")
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
         "no reachable path reaches a successful finish with a span active.")
   (list 'join-disagree one-span
         ;; Two byte edges into `mrg`: one through the span, one around it. The
         ;; lattice joins `(active payload)` with `none` and answers `top`,
         ;; which is reported as a diagnostic at the join itself.
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
         "incoming edges disagree, the join is `top`, and `top` is reported where it arises.")
   ;; --- the two VALID rows, and they are what keep the table from being a
   ;; list of things that happen to be rejected ---
   (list 'error-inside one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'err #f)
               (make-error-node 'err 'rejected #f))
         '()
         "a span open at an ERROR terminal is valid, which is why finish is kept distinguished from error.")
   (list 'well-formed one-span
         (list (d1 'start 'op1 'fin)
               (make-span-start-node 'op1 'payload 'cl #f)
               (make-span-end-node 'cl 'payload 'exit #f)
               (d1 'exit 'exit 'fin))
         '()
         "The shape every rejected row above is a perturbation of.")))

(harness-group "every invalid span topology is rejected, and only those"
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
        ;; The four span codes as a set. A table exercising three of them
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

;; --- the error path ----------------------------------------------------------

(harness-group "the error path, per lane and across schedules"
  (lambda ()
    (harness-case "a truncated span delivers no completion, under every schedule"
      (lambda ()
        ;; An error with a span open delivers no completion. The COMPLETION is
        ;; the thing that must not appear -- fragments flushed at earlier
        ;; boundaries stay observable, and how many of them there are is
        ;; schedule-dependent, so counting them across schedules would assert
        ;; the opposite of the contract.
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
        ;; For malformed inputs these THREE are compared
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
                       ;; parser error carries is its CATEGORY.
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
    (harness-case "the success path delivers exactly one completion"
      (lambda ()
        ;; The positive half of the error-path rule: what the error path
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

;; --- EOF and reset: the shapes the groups above do not reach -----------------
;;
;; Fragment tests cover six legs: boundaries, pause, completion, error, EOF and
;; reset. `record-span` drives `parser-finish!` on all thirty-seven schedules,
;; and the groups above include an EOF group and a reset group, but three SHAPES
;; of those two legs are reached by nothing above:
;;
;;   1. A span OPEN when `parser-finish!` is called, closed on the EOF chain.
;;      Every EOF case above opens AND closes inside finish, so none has a span
;;      whose fragments come from `parser-feed!` and whose completion comes
;;      from `parser-finish!`. It is legal: the verifier forbids REACHING a
;;      successful stop/finish with a span active, not entering finish with one
;;      open.
;;   2. Reset while parked BETWEEN the span-end substeps. That park retains an
;;      internal completion-pending continuation; the "reset clears span state"
;;      case parks mid-span, which is a different state and a different
;;      continuation.
;;   3. Reset of a POISONED parser with a span open. Reset is the one operation
;;      a poisoned parser may run, and `parser-reset!` reaches
;;      `byte-machine-span-close/v1` only after its `busy` guard.
;;
;; *** WHERE EACH OF THE SIX LEGS LIVES. ***
;;
;;   boundaries  "a feed boundary flushes and the span stays open"
;;               "the mark is a SLICE offset"
;;   pause       "a pause DURING the flush commits the fragment"
;;               "a pause between the span-end substeps"
;;   completion  "a span end delivers [mark,cursor) and exactly one completion"
;;               "an empty span delivers one empty fragment then the completion"
;;               "an empty final fragment vs an empty span across a feed boundary"
;;               "a pause on the EMPTY span-end delivery"
;;               "a span declaring no completion callback"
;;   error       "an error with a span open"
;;               "a FAILURE during the flush is a callback-domain error"
;;               "the error path, per lane and across schedules"
;;   EOF         "a span on the EOF chain (§12.4:729, §14:831 amended)"
;;               "a span open at finish, closed on the EOF chain"
;;               "an empty span carried into finish delivers once"
;;   reset       "reset clears span state"
;;               "reset while parked BETWEEN the span-end substeps"
;;               "reset of a POISONED parser with a span open"

;; Shape 1 needs its own machine. `body`'s eof-target above is the `trunc` ERROR
;; -- which is what makes the truncated-span cases work -- so it cannot also be
;; a span end. Written out rather than parameterised because the difference is a
;; NODE, not a value: `span-machine`'s parameter is one optional callback and
;; everything else is shared, whereas this graph replaces an error terminal with
;; a span end and adds a node.
;;
;; The only difference from `span-machine` that matters is `body`'s eof-target:
;; `bclose`, a span end whose next is `fin`. Pass 7 accepts it because the span
;; is closed BEFORE the finish terminal, and `fin` is reached with the span
;; inactive down every one of its three routes -- which is the lattice meeting at
;; a merge point, not an accident of this graph.

;; ---------------------------------------------------------------------------
;; The escape catcher, in the shape `differential-callback-tests.sps` uses: on a
;; poisoning escape neither lane RETURNS a result, so nothing a differential
;; normally compares exists. What is compared is the condition that escaped and
;; the state the parser was left in.
(define (escaping-span thunk)
  (call/cc (lambda (k)
             (with-exception-handler (lambda (e) (k (list 'raised e)))
               (lambda () (list 'returned (thunk)))))))

(define eof-close-machine
  (make-machine 'eofspan 'start '()
    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
    (list (make-span-declaration 'payload 'ondata 'ondone #f))
    (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'sopen 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'sopen 'payload 'body #f)
          (make-byte-dispatch-node 'body
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'sclose 'reexecute) #f))
            (make-edge 'body 'advance) 'bclose #f)
          ;; *** THE LEG UNDER TEST. *** Reached only by entering finish with the
          ;; span open.
          (make-span-end-node 'bclose 'payload 'fin #f)
          (make-span-end-node 'sclose 'payload 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define v-eof (verify-machine eof-close-machine))
(define cm-eof-ref (make-interpreted-machine v-eof))
(define cm-eof-gen
  (generated eof-close-machine v-eof "span-eofclose" 'eof-span-parser 'eofspan))

(define (both-eof script answers done-answer)
  (let ((a (run (make-lane cm-eof-ref answers done-answer #t) script))
        (b (run (make-lane cm-eof-gen answers done-answer #t) script)))
    (list a b (equal? a b))))

(harness-group "a span open at finish, closed on the EOF chain"
  (lambda ()
    (harness-case "the machine verifies clean"
      (lambda ()
        ;; Stated first: the verifier rejects a span active at a successful finish,
        ;; and the whole point of this fixture is that closing it ON the EOF
        ;; chain is not that. A machine that failed here would make every case
        ;; below vacuous rather than red.
        (check-equal "no diagnostics"
                     (map diagnostic-code (verification-diagnostics v-eof)) '())))
    (harness-case "the fragment comes from the feed and the completion from finish"
      (lambda ()
        ;; The shape nothing above reaches. `A b c` opens the span and leaves it
        ;; open at the end of the feed, so the boundary flush delivers
        ;; `bc` and sets the span's delivered flag; `parser-finish!` then runs
        ;; `bclose`, whose own fragment is `[0,0)` (the mark re-anchored to 0) but
        ;; is suppressed because the flag is set (a non-empty span carried to
        ;; EOF has no empty tail to announce), and the completion is the
        ;; only thing EOF adds.
        ;; *** THE FRAGMENT IS OBSERVED BETWEEN THE TWO STEPS, not only at the
        ;; end. *** `run` returns the trace after the whole script, so a lane
        ;; that suppressed the boundary flush and delivered `[1,3)` from the EOF
        ;; span end instead would produce an identical final trace, identical
        ;; tuples and an identical inactive span -- every assertion below would
        ;; pass. Driving the feed on its own first is what witnesses the "from
        ;; the FEED" half of this case's name.
        (let* ((la (make-lane cm-eof-ref '() callback-continue #t))
               (mid (run la (list (list 'feed (bytes 65 98 99))))))
          (check-equal "after the FEED alone, the fragment is already delivered"
                       (cadr mid) (list (bytes 98 99)))
          (check-equal "and the span is still open" (caddr mid) 'payload))
        (let ((r (both-eof (list (list 'feed (bytes 65 98 99)) (list 'finish))
                           '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "one fragment, from the FEED, then one completion"
                       (cadr (car r)) (list (bytes 98 99) 'complete))
          (check-equal "need-input, then finished"
                       (map car (car (car r))) '(need-input finished))
          (check-equal "and the span is inactive at the end" (caddr (car r)) #f))))
    (harness-case "the EOF span end delivers NO second fragment"
      (lambda ()
        ;; A non-empty span carried into finish: the flush already delivered `bc`
        ;; and set the span's delivered flag, so the EOF span end -- over the
        ;; re-anchored `[0,0)` -- suppresses (the empty tail of a span that
        ;; already delivered). A lane that re-delivered `[mark,end)`
        ;; here would hand the application `bc` twice, and every result tuple would
        ;; still agree.
        (let* ((r (both-eof (list (list 'feed (bytes 65 98 99)) (list 'finish))
                            '() callback-continue))
               (frags (filter bytevector? (cadr (car r)))))
          (check-equal "exactly one fragment in the whole run" (length frags) 1)
          (check-equal "and it is the boundary flush's" (car frags) (bytes 98 99)))))
    (harness-case "with no feed at all NO span opens, and finish is clean"
      (lambda ()
        ;; `start`'s own eof-target is `fin`, so a bare finish never opens a
        ;; span. The contrast is what shows the case above is about the OPEN
        ;; span and not about finish in general.
        (let ((r (both-eof (list (list 'finish)) '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "nothing delivered" (cadr (car r)) '())
          (check-equal "and it finished" (map car (car (car r))) '(finished)))))))

;; TWO spans in one stream: the first opens and closes inside the feed, the
;; second opens at the feed's end and is closed on the EOF chain. The other
;; cases in the group below each carry ONE empty span, so a runtime that
;; suppresses every empty span and one that only skips parser-finish!'s re-anchor
;; fail them with identical records. One trace holding an empty span of each kind
;; is where they part: the first loses both empty fragments, the second only the
;; one carried into finish.
(define twice-machine
  (make-machine 'twicespan 'start '()
    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
    (list (make-span-declaration 'payload 'ondata 'ondone #f))
    (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'sopen 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'sopen 'payload 'body #f)
          (make-byte-dispatch-node 'body
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'sclose 'reexecute) #f))
            (make-edge 'body 'advance) 'bclose #f)
          (make-span-end-node 'bclose 'payload 'fin #f)
          (make-span-end-node 'sclose 'payload 'after #f)
          ;; Past the delimiter and back to `start`, so a second span can open.
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'start 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define v-twice (verify-machine twice-machine))
(define cm-twice-ref (make-interpreted-machine v-twice))
(define cm-twice-gen
  (generated twice-machine v-twice "span-twice" 'twice-span-parser 'twicespan))

(harness-group "an empty span carried into finish delivers once, regardless of slicing"
  (lambda ()
    ;; A span opens in a feed, stays EMPTY, and closes on the EOF chain (bclose).
    ;; parser-finish! re-anchors the mark to 0, so the EOF span end sees from==to
    ;; and delivers the one empty fragment -- and the result does NOT depend on
    ;; the opening feed's slice `start`. Without the finish re-anchor the
    ;; carried empty span would be announced only when an intervening feed had
    ;; re-anchored the mark to 0, which depends on slicing; the two cases below,
    ;; opened at start 0 and at a nonzero start, must agree.
    (harness-case "opened by a whole-bytevector feed (start 0)"
      (lambda ()
        (let ((r (both-eof (list (list 'feed (bytes 65)) (list 'finish))
                           '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "one empty fragment, then the completion"
                       (cadr (car r)) (list (bytes) 'complete))
          (check-equal "the generated lane's own trace"
                       (cadr (cadr r)) (list (bytes) 'complete)))))
    (harness-case "opened by a sub-slice feed (nonzero start) -- same result"
      (lambda ()
        (let ((r (both-eof (list (list 'feed-slice (bytes 7 65) 1 2) (list 'finish))
                           '() callback-continue)))
          (check-equal "the lanes agree" (caddr r) #t)
          (check-equal "slicing-independent: one empty fragment, then the completion"
                       (cadr (car r)) (list (bytes) 'complete)))))
    (harness-case "an empty span closed in the feed, then one carried into finish"
      (lambda ()
        ;; `AZ` opens and closes the first span at cursor 1, so from == to there
        ;; without any re-anchor; the second `A` opens one at the slice's end,
        ;; which only parser-finish!'s re-anchor brings to from == to.
        ;; Both lanes' traces in ONE value: a span close skipped in either lane
        ;; leaves the delivered flag set and silences the second span too, so a
        ;; single lane's trace cannot tell that defect from the missing re-anchor,
        ;; which is shared code and moves both lanes at once.
        (check-equal "the two-span machine verifies clean"
                     (map diagnostic-code (verification-diagnostics v-twice)) '())
        (let* ((script (list (list 'feed (bytes 65 90 65)) (list 'finish)))
               (a (run (make-lane cm-twice-ref '() callback-continue #t) script))
               (b (run (make-lane cm-twice-gen '() callback-continue #t) script))
               (each-once (list (bytes) 'complete (bytes) 'complete)))
          (check-equal "each empty span delivers once, in both lanes"
                       (list (cadr a) (cadr b)) (list each-once each-once)))))))

(harness-group "reset while parked BETWEEN the span-end substeps"
  (lambda ()
    (harness-case "completion-pending is cleared, and the parser re-parses whole"
      (lambda ()
        ;; The "reset clears span state" case parks MID-SPAN. This one parks
        ;; after the data substep committed its fragment, where the only thing
        ;; retained is an internal completion-pending continuation -- a compound name in
        ;; one lane and a numbered internal state in the other, which is why both
        ;; are driven rather than one.
        (let loop ((cms (list cm-full-ref cm-full-gen)) (seen '()))
          (if (null? cms)
              (check-equal "both lanes agree on all of it"
                           (car seen) (cadr seen))
              (let* ((la (make-lane (car cms) (list callback-pause)
                                    callback-continue #t))
                     (p (car la))
                     (a (run la (list (list 'feed (bytes 65 98 99 100 90))))))
                (let ((parked (list (map car (car a)) (caddr a))))
                  (parser-reset! p)
                  (let ((cleared (list (parser-active-span p) (parser-lifecycle p))))
                    (let ((a2 (run la (list (list 'feed (bytes 65 98 99 100 90))))))
                      (loop (cdr cms)
                            (cons (list parked cleared
                                        ;; The recorder outlives the reset, so
                                        ;; index 0 is the pre-reset fragment. What
                                        ;; follows is the assertion: a completion
                                        ;; the reset must NOT have left pending,
                                        ;; and one whole fragment rather than a
                                        ;; split one.
                                        (list-tail (cadr a2) 1)
                                        (map car (car a2)))
                                  seen))))))))))
    (harness-case "and the observable values, stated once"
      (lambda ()
        (let* ((la (make-lane cm-full-ref (list callback-pause) callback-continue #t))
               (p (car la))
               (a (run la (list (list 'feed (bytes 65 98 99 100 90))))))
          (check-equal "parked, span still active" (caddr a) 'payload)
          ;; Two different values: `rfields` puts the result STATUS at index 0
          ;; and the parser's LIFECYCLE at index 5.
          (check-equal "the result status is paused" (map car (car a)) '(paused))
          (check-equal "and the lifecycle is paused-feed"
                       (list-tail (car (car a)) 5) '(paused-feed))
          (parser-reset! p)
          (check-equal "span cleared" (parser-active-span p) #f)
          (check-equal "lifecycle ready" (parser-lifecycle p) 'ready)
          (let ((a2 (run la (list (list 'feed (bytes 65 98 99 100 90))))))
            (check-equal "no orphan completion, one whole fragment"
                         (list-tail (cadr a2) 1)
                         (list (bytes 98 99 100) 'complete))
            (check-equal "and it ran to the stop" (map car (car a2)) '(stopped))))))))

(harness-group "reset of a POISONED parser with a span open"
  (lambda ()
    (harness-case "reset is accepted, clears the span, and the parser is reusable"
      (lambda ()
        ;; The one operation a poisoned parser may run, driven in the one state
        ;; that makes reset's clearing of span state observable. The
        ;; data callback raises ONCE: after the reset it records normally, so the
        ;; case asserts reuse and not merely that reset did not raise.
        (let ((go (lambda (cm)
                    (let* ((trace '())
                           (fired #f)
                           (p (make-parser
                               cm
                               (list (list 'ondata
                                           (lambda (ps ux bv from to)
                                             (if fired
                                                 (begin (set! trace
                                                              (cons (frag bv from to)
                                                                    trace))
                                                        callback-continue)
                                                 (begin (set! fired #t)
                                                        (raise 'boom)))))
                                     (list 'ondone
                                           (lambda (ps ux)
                                             (set! trace (cons 'complete trace))
                                             callback-continue)))
                               'ctx))
                           (escape (escaping-span
                                    (lambda ()
                                      (parser-feed! p (bytes 65 98 99 100 90) 0 5)))))
                      (let ((poisoned (list escape
                                            (parser-lifecycle p)
                                            (parser-active-span p))))
                        (parser-reset! p)
                        (let ((after (list (parser-lifecycle p)
                                           (parser-active-span p))))
                          (parser-feed! p (bytes 65 98 99 100 90) 0 5)
                          (list poisoned after (reverse trace))))))))
          (check-equal "the lanes agree on every part"
                       (go cm-full-ref) (go cm-full-gen))
          (check-equal "poisoned, with the span still open"
                       (car (go cm-full-ref)) '((raised boom) poisoned payload))
          (check-equal "reset clears both"
                       (cadr (go cm-full-ref)) '(ready #f))
          (check-equal "and the reused parser delivers the whole span"
                       (caddr (go cm-full-ref))
                       (list (bytes 98 99 100) 'complete)))))))

(harness-finish)
