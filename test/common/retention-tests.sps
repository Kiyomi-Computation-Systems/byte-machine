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
;;;      carriers outside the guarantee, and two of them are exercised here.
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

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (adapter-environment-variable "TMPDIR")
                   "/tmp"))

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
(define (failing-with-detail-bindings rec)
  (list (list 'ondata
              (lambda (ps ux bv from to)
                (rec 'failed)
                (make-callback-failure 'app-kept-it bv)))
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

(define (plain cm bv rec) (make-parser cm (recording-bindings rec) 'ctx))
(define (stashing cm bv rec) (make-parser cm (stashing-bindings rec) 'ctx))
(define (ctx-holds cm bv rec) (make-parser cm (recording-bindings rec) bv))
(define (detail-holds cm bv rec)
  (make-parser cm (failing-with-detail-bindings rec) 'ctx))

(define both-lanes (list (list 'interpreted cm-ref) (list 'generated cm-gen)))

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
