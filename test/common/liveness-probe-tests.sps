;;; The retention oracle's LIVENESS PROBE, measured through the real harness
;;; (Milestone 5 Slice ③ task 7; parent §25:1591, design §9).
;;;
;;; *** THIS LANE TESTS AN INSTRUMENT, NOT THE PARSER. *** Slice ④ has to show
;;; that no bytevector reference survives a `parser-feed!` return, and design §9
;;; builds that on a weak reference that must read `bwp` once the test drops its
;;; own. It also says, in its own words, that the measurement behind it "was
;;; taken in a throwaway scratch driver and does not count" -- so what is
;;; asserted here is the probe's DISCRIMINATION, in both lanes, before any
;;; oracle rests on it.
;;;
;;; Brought forward from Slice ④ deliberately. If the probe does not
;;; discriminate under AOT compilation, §9's oracle needs redesigning, and that
;;; is much cheaper to learn while ③ is in flight than after it ships.
;;;
;;; It needs no spans and no machine, which is the point: this is the negative
;;; control in miniature, and a probe that cannot tell a retained object from a
;;; dropped one would report "no retention" about a runtime that retained
;;; everything.
(import (rnrs)
        ;; Chez extensions, all four named by design §9. `bytevector` itself is
        ;; a Chez extension too and is deliberately not used -- `make-bytevector`
        ;; is R6RS and is all this needs.
        (only (chezscheme) weak-cons bwp-object? collect collect-maximum-generation
              make-guardian)
        (byte-machine test harness))

(harness-begin "unit.liveness-probe")

;; *** MODULE LEVEL, NOT A LET. *** A `harness-case` thunk closing over the
;; bytevector would keep it alive through the collection whatever the collector
;; does, and the case would then report "retained" about its own closure. The
;; retained arm below needs a reference the test can drop ON PURPOSE, so the
;; strong one lives here and is cleared by assignment.
(define held #f)

;; Allocation happens inside a procedure that RETURNS the weak pair and nothing
;; else, so the only strong reference the caller could have had is gone when it
;; returns. Written this way rather than inline for a reason a scratch driver
;; would not have found: a `let`-bound temporary in the same frame as the
;; `collect` call can still be live at the collection point.
(define (weak-of-fresh)
  (weak-cons (make-bytevector 8 7) '()))

(define (full-collect) (collect (collect-maximum-generation)))

;; The two arms of the discrimination, each answering "is the referent gone?".
(define (dropped-is-gone?)
  (let ((w (weak-of-fresh)))
    (full-collect)
    (bwp-object? (car w))))

(define (retained-is-gone?)
  (set! held (make-bytevector 8 7))
  (let ((w (weak-cons held '())))
    (full-collect)
    (let ((answer (bwp-object? (car w))))
      ;; Cleared AFTER the reading, and before returning: leaving it set would
      ;; make every later case in this lane collect with one live bytevector
      ;; more than it thinks.
      (set! held #f)
      answer)))

;; The second mechanism §9 names. A guardian is the one that answers "was it
;; collected" without a weak pair at all, so the two are independent readings of
;; the same fact -- and if they disagree, §9 needs to know which one it has.
(define (guarded-dropped-is-gone?)
  (let ((g (make-guardian)))
    (g (make-bytevector 8 7))
    (full-collect)
    (and (g) #t)))

(define (guarded-retained-is-gone?)
  (let ((g (make-guardian)))
    (set! held (make-bytevector 8 7))
    (g held)
    (full-collect)
    (let ((answer (and (g) #t)))
      (set! held #f)
      answer)))

(harness-group "the four Chez primitives design §9 rests on are bound"
  (lambda ()
    (harness-case "weak-cons, bwp-object?, collect and make-guardian"
      (lambda ()
        ;; Stated first and as VALUES: an unbound identifier in a Chez library
        ;; kills it at import whether or not anything calls it, so a lane that
        ;; ran at all has already proved binding. What this adds is that each is
        ;; the KIND of thing §9 assumes -- three procedures and a predicate --
        ;; rather than something that merely exists under the name.
        (check "weak-cons is a procedure" (procedure? weak-cons))
        (check "bwp-object? is a procedure" (procedure? bwp-object?))
        (check "collect is a procedure" (procedure? collect))
        (check "make-guardian is a procedure" (procedure? make-guardian))
        (check "a fresh guardian is a procedure too" (procedure? (make-guardian)))
        (check "and bwp-object? says no about an ordinary object"
               (not (bwp-object? (make-bytevector 1 0))))))))

(harness-group "the weak-pair probe DISCRIMINATES (design §9 layer 1)"
  (lambda ()
    (harness-case "a dropped bytevector reads bwp, a retained one does not"
      (lambda ()
        ;; *** BOTH DIRECTIONS, IN ONE CASE. *** Either alone is satisfied by a
        ;; constant: a probe that always answered #t would pass the dropped arm,
        ;; and one that always answered #f would pass the retained arm. §9's
        ;; layer 2 calls the second arm the negative control and says layer 1
        ;; "asserts nothing" without it.
        (check-equal "dropped is gone" (dropped-is-gone?) #t)
        (check-equal "retained is not" (retained-is-gone?) #f)))
    (harness-case "and it is repeatable, not a first-collection artefact"
      (lambda ()
        ;; Slice ④ will run this probe once per fixture. A probe that answered
        ;; correctly only on the first collection of a process would pass the
        ;; case above and then report retention on every fixture after the first.
        (let ((drops '()) (keeps '()))
          (let loop ((i 0))
            (when (< i 5)
              (set! drops (cons (dropped-is-gone?) drops))
              (set! keeps (cons (retained-is-gone?) keeps))
              (loop (+ i 1))))
          (check-equal "five drops, all gone" drops '(#t #t #t #t #t))
          (check-equal "five keeps, none gone" keeps '(#f #f #f #f #f)))))))

(harness-group "the guardian probe agrees with the weak pair"
  (lambda ()
    (harness-case "a guardian reports a dropped object and withholds a retained one"
      (lambda ()
        ;; The independent reading. If these two ever disagree, design §9 has to
        ;; choose, and the lane that made it choose is this one.
        (check-equal "dropped is reported" (guarded-dropped-is-gone?) #t)
        (check-equal "retained is withheld" (guarded-retained-is-gone?) #f)))
    (harness-case "the module-level strong reference is clear at the end"
      (lambda ()
        ;; The arms above set and clear `held`. If one ever stopped clearing it,
        ;; every later collection in the lane would run with a live bytevector
        ;; nobody declared, and the failure would show up somewhere else.
        (check-equal "nothing is held" held #f)))))

(harness-finish)
