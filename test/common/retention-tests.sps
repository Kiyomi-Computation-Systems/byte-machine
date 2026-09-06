;;; `§25:1591` — the input-retention oracle (Milestone 5 Slice ④; design §9).
;;;
;;; "parser input-retention tests demonstrate no bytevector reference is stored
;;; by the runtime after return."
;;;
;;; *** THE PARSER IS HELD ALIVE AND ONLY THE BYTEVECTOR IS DROPPED. *** That is
;;; the whole design of this lane. A probe that let the parser die too would
;;; report `bwp` about a runtime that stored the bytevector in every slot it has,
;;; because the storage would have died with it -- and every arm below would pass.
;;; `parser-held` is what keeps that from being what this file measures.
;;;
;;; Design §9 asks for three layers and says layer 1 "asserts nothing" without
;;; layer 2:
;;;
;;;   1. LIVENESS -- a weak reference to a fed bytevector reads `bwp` once the
;;;      test drops its own and collects.
;;;   2. THE NEGATIVE CONTROL -- a deliberately retaining fixture the oracle must
;;;      FAIL on. Without it, layer 1 is satisfied by a probe that always answers
;;;      "gone".
;;;   3. THE EXEMPTION BOUNDARY -- `§13:799` names three application-owned
;;;      carriers outside the guarantee, and all three are exercised here: user
;;;      context, a callback CLOSURE that captured the input, and callback error
;;;      detail. The closure arm was missing from the first version of this file,
;;;      which called it unreached; it is one line, and three surfaces had
;;;      already claimed all three were covered.
;;;
;;; It is REACHABILITY-BASED, not a slot walk. The parser was ten slots at
;;; Milestone 5's Gate 0 and is sixteen now; a census of slots is a thing that
;;; goes stale, and slot 2 -- the executor closure -- is on neither `§13:799`'s
;;; exempt list nor the list of things that could retain, so a slot walk would
;;; have to argue about it. A weak reference covers every path, including the
;;; ones nobody enumerated.
;;;
;;; The instrument itself was measured in both lanes by Slice ③ task 7,
;;; `liveness-probe-tests.sps`. Three findings from that lane are load-bearing
;;; here and are marked at their sites: allocate inside a procedure that returns
;;; only the weak pair; hold the strong reference at module level and clear it by
;;; assignment; assert both directions.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load weak-cons bwp-object? collect
              collect-maximum-generation)
        (byte-machine test harness)
        (byte-machine graph) (byte-machine verify)
        (byte-machine interpret) (byte-machine compile) (byte-machine runtime))

(harness-begin "unit.retention")

;; No silent fallback to "/tmp": every other lane in `test/common` that emits a
;; generated library raises here, and for a reason this lane would feel worse
;; than most -- the source and AOT lanes would both write
;; `/tmp/generated-retention.sls` and race, and the failure would surface as a
;; lowering mismatch rather than as a missing environment.
(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'retention-tests
                                        "BYTE_MACHINE_TEST_TMPDIR is not set")))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define trunc-decl (make-error-declaration 'truncated 'eof "span truncated" #f))

;; `A` opens, everything up to `Z` is the payload, `Z` closes and stops. The same
;; shape the span differential uses, written out here so this lane is readable on
;; its own -- what it asserts has nothing to do with fragment boundaries and
;; everything to do with what survives the return.
(define retention-machine
  (make-machine 'retm 'start '()
    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
    (list (make-span-declaration 'payload 'ondata 'ondone #f))
    (list eof-decl rej-decl trunc-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'sopen 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
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

(define v-ret (verify-machine retention-machine))
(define cm-ref (make-interpreted-machine v-ret))
(define cm-gen
  (let ((f (string-append tmpdir "/generated-retention.sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine retention-machine '()) 'ret-parser p)))
    (load f)
    (eval 'ret-parser (environment '(generated retm)))))

(define (full-collect) (collect (collect-maximum-generation)))

;; *** MODULE LEVEL, BOTH OF THEM, AND CLEARED BY ASSIGNMENT. *** A `harness-case`
;; thunk closing over either would keep it alive through the collection whatever
;; the runtime did, and the case would report "retained" about its own closure.
;; This is `liveness-probe-tests.sps`'s second finding, and it applies twice here
;; because this lane has two things to hold: the PARSER, deliberately, and the
;; negative control's stash.
(define parser-held #f)
(define stash #f)

;; A fresh five-byte payload per probe. Allocated behind a procedure so no
;; literal in this file is the object under test -- a module-level constant would
;; be immortal and every arm would read "retained".
(define (fresh-payload)
  (let ((bv (make-bytevector 5 0)))
    (bytevector-u8-set! bv 0 65)                       ; A -- opens
    (bytevector-u8-set! bv 1 98)                       ; b
    (bytevector-u8-set! bv 2 99)                       ; c
    (bytevector-u8-set! bv 3 100)                      ; d
    (bytevector-u8-set! bv 4 90)                       ; Z -- closes
    bv))

;; The recording callbacks. `§13:799` says the range is valid only for the
;; callback's dynamic extent and that an application wanting the bytes afterwards
;; must COPY -- so the trace holds fresh bytevectors, never `(bv from to)`.
(define (recording-bindings rec)
  (list (list 'ondata
              (lambda (ps ux bv from to)
                (let ((out (make-bytevector (- to from))))
                  (let loop ((i from))
                    (if (>= i to)
                        (rec out)
                        (begin (bytevector-u8-set! out (- i from)
                                                   (bytevector-u8-ref bv i))
                               (loop (+ i 1))))))
                callback-continue))
        (list 'ondone (lambda (ps ux) (rec 'complete) callback-continue))))

;; The negative control's callbacks: the data callback keeps the bytevector it
;; was handed instead of copying out of it. Design §9 calls this "a deliberately
;; retaining fixture the oracle must FAIL on", and without it layer 1 is
;; satisfied by a probe that answers "gone" unconditionally.
;; The split probe's control needs a different fixture from the one above: a
;; callback that stashes on EVERY invocation keeps whatever it was handed LAST,
;; which is the second buffer, and the first buffer's flush would go unwitnessed.
;; This one keeps only what it sees FIRST -- the fragment the boundary flush
;; delivers out of the first bytevector.
(define (stashing-first-bindings rec)
  (list (list 'ondata
              (lambda (ps ux bv from to)
                (unless stash (set! stash bv))
                (rec 'stashed)
                callback-continue))
        (list 'ondone (lambda (ps ux) (rec 'complete) callback-continue))))

(define (stashing-bindings rec)
  (list (list 'ondata
              (lambda (ps ux bv from to)
                (set! stash bv)
                (rec 'stashed)
                callback-continue))
        (list 'ondone (lambda (ps ux) (rec 'complete) callback-continue))))

;; Layer 3's second carrier: an explicit callback failure whose DETAIL is the
;; bytevector the callback was handed. Decision `0024` item 4 gave the
;; explicit-failure path a detail slot, and `§13:799` puts "callback error
;; detail" among the three application-owned carriers outside the guarantee, so
;; the parser's stored error transitively -- and legitimately -- holds the input.
;;
;; `§12.7:777` does NOT compare detail across lanes ("the internal state ID is an
;; executor-local debugging aid ... Differential tests do not compare that
;; accessor across executor kinds" is the neighbouring rule; detail is excluded
;; from the projection for the same reason it is opaque application data). So the
;; arms below assert REACHABILITY per lane and never agreement between them --
;; `each-lane` returns a per-lane answer and the expected value names both, which
;; is a different thing from comparing one lane's detail to the other's.
(define (failing-with-detail-bindings rec)
  (list (list 'ondata
              (lambda (ps ux bv from to)
                (rec 'failed)
                (make-callback-failure 'app-kept-it bv)))
        (list 'ondone (lambda (ps ux) (rec 'complete) callback-continue))))

;; `§13:799`'s THIRD carrier, and the one the first version of this lane left
;; unexercised: a callback CLOSURE that captured the input. The closure lives in
;; the parser's callback slot vector, so the parser reaches the bytevector
;; through it -- application-owned, and outside the guarantee like the other two.
(define (closure-holds-bindings rec captured)
  (list (list 'ondata
              (lambda (ps ux bv from to)
                ;; `captured` is referenced, not merely closed over, so no
                ;; compiler is entitled to drop it from the closure.
                (rec (if (eq? bv captured) 'same 'different))
                callback-continue))
        (list 'ondone (lambda (ps ux) (rec 'complete) callback-continue))))

;; A data callback that PAUSES. Used by the boundary-flush probe below: a pause
;; during the flush is `§14:837`, and `§14:841` says what the park retains --
;; "an internal `completion-pending` continuation, never the input bytevector".
;; That sentence is a retention claim and had nothing asserting it.
(define (pausing-bindings rec)
  (list (list 'ondata (lambda (ps ux bv from to) (rec 'paused) callback-pause))
        (list 'ondone (lambda (ps ux) (rec 'complete) callback-continue))))

;; *** THE ALLOCATION HAPPENS INSIDE A PROCEDURE THAT RETURNS ONLY THE WEAK PAIR
;; AND THE TRACE. *** `liveness-probe-tests.sps`'s first finding: a `let`-bound
;; temporary in the same frame as the `collect` call can still be live at the
;; collection point, and the collection below happens in the CALLER.
;;
;; `make-p` receives the payload so an arm can put it somewhere exempt --
;; `user-context`, say -- without this procedure knowing which arm it is running.
(define (make-recorder)
  ;; A closure rather than a mutable pair: `(rnrs)` does not export
  ;; `(rnrs mutable-pairs)`, so `set-car!` is not available here at all.
  (let ((trace '()))
    (list (lambda (x) (set! trace (cons x trace)))
          (lambda () (reverse trace)))))

(define (probe cm make-p)
  (let* ((bv (fresh-payload))
         (r (make-recorder)))
    (set! parser-held (make-p cm bv (car r)))
    (parser-feed! parser-held bv 0 5)
    (list (weak-cons bv '()) ((cadr r)))))

;; Reads the probe, then clears BOTH module-level holds. Leaving either set would
;; make every later arm in this lane collect with one live bytevector more than
;; it thinks -- the failure `liveness-probe-tests.sps` guards with its own
;; "nothing is held" case, and this lane repeats at the foot.
(define (retained? cm make-p)
  (let* ((r (probe cm make-p))
         (w (car r))
         (trace (cadr r)))
    (full-collect)
    (let ((answer (not (bwp-object? (car w)))))
      (set! parser-held #f)
      (set! stash #f)
      (list answer trace))))

;; *** THE ONE-FEED PROBE ABOVE CANNOT REACH HALF THE RETENTION SURFACE. ***
;; `parser-feed!` is the whole surface -- `parser-finish!` and `parser-resume!`
;; take no bytevector -- and every probe above feeds all five bytes at once and
;; ends at a terminal status. Two shipped paths are therefore never executed by
;; it, and BOTH are paths where `bv` is in scope at a return:
;;
;;   - `span-boundary-flush!`, gated on `need-input` AND an active span
;;     (`runtime.sls`, "if (and (eq? (parser-result-status r) 'need-input)");
;;   - `§14:833`'s mark re-anchor in `parser-feed!`, gated on a span left open by
;;     a PREVIOUS feed -- the very line design §9 cites as the reason "nothing has
;;     to be retained to interpret it".
;;
;; So this probe splits the payload across two feeds of two DIFFERENT
;; bytevectors and weakens both. The first feed leaves the span open and its
;; flush delivers a fragment out of the first bytevector; the second re-anchors
;; the mark and finishes the span. A runtime that stored either buffer is caught.
(define (fresh-head)                                   ; `A b` -- opens, then need-input
  (let ((bv (make-bytevector 2 0)))
    (bytevector-u8-set! bv 0 65)
    (bytevector-u8-set! bv 1 98)
    bv))
(define (fresh-tail)                                   ; `c d Z` -- closes and stops
  (let ((bv (make-bytevector 3 0)))
    (bytevector-u8-set! bv 0 99)
    (bytevector-u8-set! bv 1 100)
    (bytevector-u8-set! bv 2 90)
    bv))

(define (probe-split cm make-p)
  (let* ((head (fresh-head))
         (tail (fresh-tail))
         (r (make-recorder)))
    (set! parser-held (make-p cm head (car r)))
    (parser-feed! parser-held head 0 2)
    (parser-feed! parser-held tail 0 3)
    (list (weak-cons head '()) (weak-cons tail '()) ((cadr r)))))

;; The paused variant: one feed, the flush's data callback answers `pause`, and
;; the parser is left PARKED with the span open when the collection happens.
(define (probe-paused cm make-p)
  (let* ((head (fresh-head))
         (r (make-recorder)))
    (set! parser-held (make-p cm head (car r)))
    (parser-feed! parser-held head 0 2)
    (list (weak-cons head '()) ((cadr r)))))

(define (retained-split? cm make-p)
  (let* ((x (probe-split cm make-p)))
    (full-collect)
    (let ((answer (list (not (bwp-object? (car (car x))))
                        (not (bwp-object? (car (cadr x))))
                        (caddr x))))
      (set! parser-held #f)
      (set! stash #f)
      answer)))

(define (retained-paused? cm make-p)
  (let* ((x (probe-paused cm make-p)))
    (full-collect)
    (let ((answer (list (not (bwp-object? (car (car x))))
                        (cadr x)
                        (parser-lifecycle parser-held)
                        (parser-active-span parser-held))))
      (set! parser-held #f)
      (set! stash #f)
      answer)))

(define (plain cm bv rec) (make-parser cm (recording-bindings rec) 'ctx))
(define (stashing cm bv rec) (make-parser cm (stashing-bindings rec) 'ctx))
(define (stashing-first cm bv rec)
  (make-parser cm (stashing-first-bindings rec) 'ctx))
(define (ctx-holds cm bv rec) (make-parser cm (recording-bindings rec) bv))
(define (detail-holds cm bv rec)
  (make-parser cm (failing-with-detail-bindings rec) 'ctx))
(define (closure-holds cm bv rec)
  (make-parser cm (closure-holds-bindings rec bv) 'ctx))
(define (pausing cm bv rec) (make-parser cm (pausing-bindings rec) 'ctx))

;; Milestone 6 Slice ②'s body-shaped arm: the same protocol -- `A` opens, `Z`
;; follows the span end -- with the body a COUNTED CONSUME of three instead of a
;; byte dispatch looping to `Z`. It consumes the same five bytes under both
;; probes: the split probe leaves the span open after `b` with a count of two,
;; the flush delivers `b` out of the first buffer, and the second feed completes
;; the count, closes the span and stops on `Z`. A bulk copy is the shape most
;; likely to tempt a runtime into holding a range; this arm is what says it does
;; not. Layers 1 and 2 only: layer 3's carriers are application-owned and
;; machine-independent, so they are not repeated here.
(define retention-counted-machine
  (make-machine 'retcm 'start (list (make-uint-field 'len 8 3 #f))
    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
    (list (make-span-declaration 'payload 'ondata 'ondone #f))
    (list eof-decl rej-decl trunc-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'sopen 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'sopen 'payload 'body #f)
          (make-counted-consume-node 'body 'len 'sclose 'trunc #f)
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

(define v-cret (verify-machine retention-counted-machine))
(define cm-cref (make-interpreted-machine v-cret))
(define cm-cgen
  (let ((f (string-append tmpdir "/generated-retention-counted.sls")))
    (call-with-port (open-file-output-port f (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine retention-counted-machine '()) 'cret-parser p)))
    (load f)
    (eval 'cret-parser (environment '(generated retcm)))))

(define both-lanes (list (list 'interpreted cm-ref) (list 'generated cm-gen)))
(define both-counted-lanes (list (list 'interpreted cm-cref) (list 'generated cm-cgen)))
(define (each-counted-lane f)
  (map (lambda (l) (cons (car l) (f (cadr l)))) both-counted-lanes))

(define (each-lane f)
  (map (lambda (l) (cons (car l) (f (cadr l)))) both-lanes))

(harness-group "the machine verifies clean, and the span actually runs"
  (lambda ()
    (harness-case "no diagnostics"
      (lambda ()
        (check-equal "clean" (map diagnostic-code (verification-diagnostics v-ret)) '())))
    (harness-case "a fragment IS delivered, in both lanes"
      (lambda ()
        ;; *** THE VACUITY GUARD. *** "No bytevector is retained" is trivially
        ;; true of a run in which the span never opened and no callback ever saw
        ;; the input. Every arm below reads its trace for that reason, and this
        ;; case states the expected trace once.
        (check-equal "the payload, then the completion"
                     (each-lane (lambda (cm) (cadr (retained? cm plain))))
                     (let ((f (u8-list->bytevector '(98 99 100))))
                       (list (cons 'interpreted (list f 'complete))
                             (cons 'generated (list f 'complete)))))))))

(harness-group "layer 1 — no bytevector reference survives the return (§25:1591)"
  (lambda ()
    (harness-case "the fed bytevector is gone while the parser is still alive"
      (lambda ()
        ;; The parser is `parser-held` throughout the collection. What this
        ;; measures is therefore the RUNTIME's retention and not the parser's own
        ;; reachability.
        (check-equal "gone in both lanes"
                     (each-lane (lambda (cm) (car (retained? cm plain))))
                     '((interpreted . #f) (generated . #f)))))))

(harness-group "layer 2 — the negative control the oracle must FAIL on (design §9)"
  (lambda ()
    (harness-case "a fixture that keeps the bytevector reads RETAINED"
      (lambda ()
        ;; Without this arm, layer 1 above is satisfied by a probe that answers
        ;; "gone" unconditionally -- which is exactly what a retention test
        ;; written against a runtime that stored everything would look like.
        (check-equal "retained in both lanes"
                     (each-lane (lambda (cm) (car (retained? cm stashing))))
                     '((interpreted . #t) (generated . #t)))))
    (harness-case "and the retaining fixture really ran the span"
      (lambda ()
        (check-equal "the data callback fired"
                     (each-lane (lambda (cm) (cadr (retained? cm stashing))))
                     '((interpreted stashed complete) (generated stashed complete)))))))

(harness-group "layer 1, the OTHER half of the feed surface (§14:833, §14:837)"
  (lambda ()
    (harness-case "a span left open across a feed boundary retains neither buffer"
      (lambda ()
        ;; *** THE FIRST VERSION OF THIS LANE COULD NOT SEE THIS. *** Every probe
        ;; in the group above feeds all five bytes at once and ends at a terminal
        ;; status, so `span-boundary-flush!` -- gated on `need-input` AND an
        ;; active span -- never ran, and neither did `§14:833`'s mark re-anchor.
        ;; Both are places where the caller's bytevector is in scope at a return,
        ;; and a runtime that stored it in either would have passed every arm.
        ;;
        ;; Two feeds of two DIFFERENT bytevectors, so the answer says WHICH
        ;; buffer leaked rather than that one did.
        (check-equal "neither, in both lanes"
                     (each-lane (lambda (cm)
                                  (let ((r (retained-split? cm plain)))
                                    (list (car r) (cadr r)))))
                     '((interpreted #f #f) (generated #f #f)))))
    (harness-case "and the flush really delivered out of the first buffer"
      (lambda ()
        ;; The vacuity guard for the case above, and the thing that proves the
        ;; boundary flush ran at all: `b` can only come from the first feed's
        ;; flush, and `cd` only from the span end after the mark was re-anchored.
        (check-equal "b from the flush, cd after the re-anchor, one completion"
                     (each-lane (lambda (cm) (caddr (retained-split? cm plain))))
                     (let ((b (u8-list->bytevector '(98)))
                           (cd (u8-list->bytevector '(99 100))))
                       (list (cons 'interpreted (list b cd 'complete))
                             (cons 'generated (list b cd 'complete)))))))
    (harness-case "a parser PARKED mid-span holds no buffer either (§14:841)"
      (lambda ()
        ;; `§14:841`: a pause after the data fragment "retains only an internal
        ;; `completion-pending` continuation, never the input bytevector". That
        ;; sentence is a retention claim, and the reference document repeats it
        ;; to readers who cannot check it. Here the parser is parked with the
        ;; span still OPEN at the moment of collection -- the state in which a
        ;; runtime most plausibly would keep the buffer, since it has been told
        ;; it will be resumed.
        (check-equal "gone, while parked, span still open, in both lanes"
                     (each-lane (lambda (cm) (retained-paused? cm pausing)))
                     '((interpreted #f (paused) paused-feed payload)
                       (generated #f (paused) paused-feed payload)))))
    (harness-case "the split negative control reads RETAINED for the FLUSH's buffer"
      (lambda ()
        ;; Layer 2 for this half of the surface, and the fixture is `stashing-first`
        ;; rather than `stashing` for a measured reason: a callback that stashes on
        ;; every invocation keeps the LAST buffer, so it witnesses the span end and
        ;; not the flush. Keeping only the first is what makes this arm about the
        ;; boundary-flush path -- without it, "neither is retained" above is
        ;; satisfied by a probe that cannot see through that path at all.
        (check-equal "the first buffer is held, the second is not"
                     (each-lane (lambda (cm)
                                  (let ((r (retained-split? cm stashing-first)))
                                    (list (car r) (cadr r)))))
                     '((interpreted #t #f) (generated #t #f)))))
    (harness-case "and stashing on EVERY fragment keeps the last one, not the first"
      (lambda ()
        ;; The measurement that produced the case above, kept as an assertion
        ;; rather than as a comment: two fixtures differing only in when they stop
        ;; stashing retain different buffers, which is what makes "which buffer"
        ;; a real question and the two-bytevector probe worth its cost.
        (check-equal "head gone, tail held"
                     (each-lane (lambda (cm)
                                  (let ((r (retained-split? cm stashing)))
                                    (list (car r) (cadr r)))))
                     '((interpreted #f #t) (generated #f #t)))))))

(harness-group "a counted body inside the span retains nothing either (Milestone 6 Slice ②)"
  (lambda ()
    (harness-case "the counted machine verifies clean"
      (lambda ()
        (check-equal "no diagnostics" (map diagnostic-code (verification-diagnostics v-cret)) '())))
    (harness-case "counted: the one-feed probe with the parser still alive"
      (lambda ()
        (check-equal "counted: one-feed buffer released, interpreted and generated"
                     (each-counted-lane (lambda (cm) (car (retained? cm plain))))
                     '((interpreted . #f) (generated . #f)))
        (check-equal "counted: and the span really ran"
                     (each-counted-lane (lambda (cm) (cadr (retained? cm plain))))
                     (let ((bcd (u8-list->bytevector '(98 99 100))))
                       (list (cons 'interpreted (list bcd 'complete))
                             (cons 'generated (list bcd 'complete)))))))
    (harness-case "counted: a span left open across a feed boundary retains neither buffer"
      (lambda ()
        (check-equal "counted: split probe, both buffers released"
                     (each-counted-lane (lambda (cm)
                                          (let ((r (retained-split? cm plain)))
                                            (list (car r) (cadr r)))))
                     '((interpreted #f #f) (generated #f #f)))
        (check-equal "counted: b from the flush, cd from the span end, one completion"
                     (each-counted-lane (lambda (cm) (caddr (retained-split? cm plain))))
                     (let ((b (u8-list->bytevector '(98)))
                           (cd (u8-list->bytevector '(99 100))))
                       (list (cons 'interpreted (list b cd 'complete))
                             (cons 'generated (list b cd 'complete)))))))
    (harness-case "counted: the negative controls read RETAINED, so the arm can fail"
      (lambda ()
        (check-equal "counted: stashing on the one-feed probe"
                     (each-counted-lane (lambda (cm) (car (retained? cm stashing))))
                     '((interpreted . #t) (generated . #t)))
        ;; The control's trace, as layer 2 asserts for the plain machine: a
        ;; fixture that answers RETAINED without having run the span would make
        ;; the control vacuous.
        (check-equal "counted: the stashing control really ran the span"
                     (each-counted-lane (lambda (cm) (cadr (retained? cm stashing))))
                     '((interpreted stashed complete) (generated stashed complete)))
        (check-equal "counted: the split control holds the flush's buffer and not the second"
                     (each-counted-lane (lambda (cm)
                                          (let ((r (retained-split? cm stashing-first)))
                                            (list (car r) (cadr r)))))
                     '((interpreted #t #f) (generated #t #f)))))
    (harness-case "two counted lanes were driven"
      (lambda ()
        (check-equal "both" (length both-counted-lanes) 2)))))

(harness-group "layer 3 — the exemption boundary (§13:799, decision 0024)"
  (lambda ()
    (harness-case "user context may retain it, and does"
      (lambda ()
        ;; The first of `§13:799`'s three carriers. An application that hands the
        ;; parser its own input as context has retained it BY ITS OWN POLICY, and
        ;; the guarantee does not reach there.
        (check-equal "retained, and permitted"
                     (each-lane (lambda (cm) (car (retained? cm ctx-holds))))
                     '((interpreted . #t) (generated . #t)))))
    (harness-case "and the user-context arm really ran the span"
      (lambda ()
        ;; The vacuity guard the ctx arm needs and did not have: its retention
        ;; comes from `make-parser` alone, so it would read RETAINED unchanged if
        ;; the span never opened or the feed never happened, and the arm would be
        ;; asserting something else's #t.
        (check-equal "the payload, then the completion"
                     (each-lane (lambda (cm) (cadr (retained? cm ctx-holds))))
                     (let ((f (u8-list->bytevector '(98 99 100))))
                       (list (cons 'interpreted (list f 'complete))
                             (cons 'generated (list f 'complete)))))))
    (harness-case "a callback CLOSURE may retain it — §13:799's third carrier"
      (lambda ()
        ;; The carrier the first version of this lane named and did not exercise.
        ;; The parser holds the closure in its callback slot vector, so it
        ;; reaches the bytevector THROUGH application code -- which is exactly
        ;; what `§13:799` puts outside the guarantee. All three carriers are now
        ;; asserted rather than two of three with a note.
        (check-equal "retained, and permitted"
                     (each-lane (lambda (cm) (car (retained? cm closure-holds))))
                     '((interpreted . #t) (generated . #t)))))
    (harness-case "and the closure arm saw the very bytevector it captured"
      (lambda ()
        ;; Not merely "a bytevector": the callback compares identity, so this
        ;; fails if the runtime ever handed the callback a copy -- which would
        ;; make the retention above a fact about the fixture, not about `bv`.
        (check-equal "same object"
                     (each-lane (lambda (cm) (cadr (retained? cm closure-holds))))
                     '((interpreted same complete) (generated same complete)))))
    (harness-case "callback error detail may retain it too — the one a slot walk misses"
      (lambda ()
        ;; *** THIS IS THE ARM DESIGN §9 SAYS AN ORACLE GETS WRONG. *** "An
        ;; oracle that excludes only the user-context slot will report a false
        ;; violation the first time a fixture callback fails with a detail
        ;; holding its own slice." The detail here IS the fed bytevector, the
        ;; parser's stored error holds it, and `§13:799` permits exactly that.
        (check-equal "retained, and permitted"
                     (each-lane (lambda (cm) (car (retained? cm detail-holds))))
                     '((interpreted . #t) (generated . #t)))))
    (harness-case "the failing arm really failed, rather than retaining by accident"
      (lambda ()
        ;; A callback that never ran would leave no detail and no retention, and
        ;; the case above would then be asserting something else's #t.
        (check-equal "the data callback failed, and no completion followed"
                     (each-lane (lambda (cm) (cadr (retained? cm detail-holds))))
                     '((interpreted failed) (generated failed)))))
    (harness-case "and it is the detail doing it, not the failure"
      (lambda ()
        ;; The discriminator. Same failing path, same stored error, detail `#f`:
        ;; if this read RETAINED, the case above would be about the error record
        ;; rather than about `§13:799`'s third carrier.
        (check-equal "a failure with no detail retains nothing"
                     (each-lane
                      (lambda (cm)
                        (car (retained?
                              cm
                              (lambda (cm2 bv rec)
                                (make-parser
                                 cm2
                                 (list (list 'ondata
                                             (lambda (ps ux b f t)
                                               (rec 'failed)
                                               (make-callback-failure 'app-said-no #f)))
                                       (list 'ondone
                                             (lambda (ps ux) callback-continue)))
                                 'ctx))))))
                     '((interpreted . #f) (generated . #f)))))))

(harness-group "the enabling condition, asserted rather than assumed (§13:826)"
  (lambda ()
    (harness-case "a pause reachable inside this span is REJECTED"
      (lambda ()
        ;; *** §25:1590 AND §25:1591 ARE NOT INDEPENDENT, AND THIS IS THE LINK.
        ;; *** §13:826 says the verifier's restriction on pausing while a span is
        ;; active is "what makes the no-retention contract possible without
        ;; invoking unrelated callbacks after a pause request". So the guarantee
        ;; layer 1 measures rests on a check that lives in another file, and a
        ;; lane that only measured retention would go on passing if that check
        ;; were weakened or deferred -- it would be testing a weaker claim than
        ;; the plan makes, with nothing to say so.
        ;;
        ;; The same machine as above with one node changed: an explicit pause
        ;; between the span start and the span end.
        (let* ((m (make-machine 'retpause 'start '()
                    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
                          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
                    (list (make-span-declaration 'payload 'ondata 'ondone #f))
                    (list eof-decl rej-decl trunc-decl)
                    (list (make-byte-dispatch-node 'start
                            (list (make-byte-case (make-exact-byte-matcher 65)
                                                  (make-edge 'sopen 'advance) #f))
                            (make-edge 'reject 'reexecute) 'fin #f)
                          (make-span-start-node 'sopen 'payload 'hold #f)
                          (make-pause-node 'hold 'body #f)
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
               (codes (map diagnostic-code (verification-diagnostics (verify-machine m)))))
          (check-equal "span-active-at-pause, and nothing else"
                       codes '(span-active-at-pause)))))
    (harness-case "a successful exit reachable with this span open is REJECTED too"
      (lambda ()
        ;; The SIBLING restriction, and it is a different rule with a different
        ;; citation: `span-active-at-pause` is `§13:826`'s, and
        ;; `span-active-at-exit` is `§14:843`'s ("no reachable path ... reaches
        ;; successful stop/finish with a span active"). The reference document
        ;; named both as enforcing `§13:826`, which is one diagnostic too many.
        ;;
        ;; It belongs in THIS lane and not only in the topology table because the
        ;; retention argument needs it: a span still open at a successful finish
        ;; is a span whose data callback may never be called again, and the
        ;; boundary flush's "the span remains open" contract would then be a
        ;; promise about a parser that has already finished.
        (let* ((m (make-machine 'retexit 'start '()
                    (list (make-callback-declaration 'ondone 'span-complete #f '() #f #f)
                          (make-callback-declaration 'ondata 'span-data #t '() #f #f))
                    (list (make-span-declaration 'payload 'ondata 'ondone #f))
                    (list eof-decl rej-decl trunc-decl)
                    (list (make-byte-dispatch-node 'start
                            (list (make-byte-case (make-exact-byte-matcher 65)
                                                  (make-edge 'sopen 'advance) #f))
                            (make-edge 'reject 'reexecute) 'fin #f)
                          (make-span-start-node 'sopen 'payload 'body #f)
                          ;; The eof-target is a FINISH terminal reached with the
                          ;; span still open -- exactly what §14:843 forbids.
                          ;;
                          ;; *** ITS OWN TERMINAL, NOT `fin`. *** Pointing it at
                          ;; the shared `fin` makes that node reachable with the
                          ;; span both active and inactive, and pass 7 answers
                          ;; `inconsistent-span-state` -- a different diagnostic,
                          ;; and the case would then be about the lattice meeting
                          ;; rather than about §14:843. Measured, not guessed:
                          ;; the first version of this fixture did exactly that.
                          (make-byte-dispatch-node 'body
                            (list (make-byte-case (make-exact-byte-matcher 90)
                                                  (make-edge 'sclose 'reexecute) #f))
                            (make-edge 'body 'advance) 'inspan-fin #f)
                          (make-finish-node 'inspan-fin #f)
                          (make-span-end-node 'sclose 'payload 'after #f)
                          (make-byte-dispatch-node 'after
                            (list (make-byte-case (make-exact-byte-matcher 90)
                                                  (make-edge 'done 'advance) #f))
                            (make-edge 'reject 'reexecute) 'fin #f)
                          (make-stop-node 'done #f)
                          (make-finish-node 'fin #f)
                          (make-error-node 'reject 'rejected #f))
                    'default-eof #f))
               (codes (map diagnostic-code (verification-diagnostics (verify-machine m)))))
          (check-equal "span-active-at-exit, and nothing else"
                       codes '(span-active-at-exit)))))
    (harness-case "and the oracle's own machine satisfies it"
      (lambda ()
        ;; The other direction: the machine every arm above drives has no pause
        ;; inside its span, so the guarantee it demonstrates is one the verifier
        ;; actually permits it to make. Without this, the case above is about
        ;; some other machine.
        (check-equal "clean" (map diagnostic-code (verification-diagnostics v-ret)) '())))))

(harness-group "the lane leaves nothing held"
  (lambda ()
    (harness-case "both module-level references are clear"
      (lambda ()
        ;; Every arm above clears them on the way out. If one stopped, every
        ;; later collection in this lane would run with a live parser or a live
        ;; bytevector nobody declared, and the failure would surface somewhere
        ;; else entirely.
        (check-equal "no parser held" parser-held #f)
        (check-equal "no stash held" stash #f)))))

(harness-finish)
