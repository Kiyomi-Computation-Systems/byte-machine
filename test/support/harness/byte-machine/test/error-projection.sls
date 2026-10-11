;;; The cross-lane error projection, with ONE owner.
;;;
;;; The differential compares error domain, code, public source-node name,
;;; absolute position, and position kind -- five members, to which this library
;;; adds three (see `projected-members` below). It does NOT compare
;;; parser-error-state-id: generated state IDs are deterministic for a given
;;; normalized graph, but an independently interpreted machine need not report
;;; the same ID, so differential tests do not compare that accessor across
;;; executor kinds. Both lanes must still REPORT one; only the comparison omits
;;; it.
;;;
;;; This lives in one library rather than in each differential program because
;;; eight local copies of that reading is eight places for it to drift, and
;;; because the positive exclusion check needs something to assert against.
;;; The trap it exists to prevent: with the error slot holding a record, a
;;; whole-value tuple comparison goes red -- correctly, since the state id is
;;; lane-local -- and the obvious repair is to compare (parser-error-code e)
;;; instead, which restores green while narrowing the comparison to one symbol
;;; and leaving the other comparable members with no differential behind them.
(library (byte-machine test error-projection)
  (export project-error projected-members error-state-id)
  (import (rnrs) (byte-machine runtime))

  ;; #f in, #f out: parser-result-error is #f on every non-error result, and
  ;; keeping that shape means the non-error tuples in the differential programs
  ;; carry a plain #f.
  (define (project-error e)
    (if (parser-error? e)
        (list (parser-error-domain e)
              (parser-error-code e)
              (parser-error-reason e)
              (parser-error-node-name e)
              (parser-error-offset e)
              (parser-error-position-kind e)
              (parser-error-span e)
              (parser-error-span-offset e))
        e))

  ;; What project-error yields, named so a test can assert the width rather than
  ;; counting a literal list. Eight, not five: the five above, plus `reason`,
  ;; plus the span an error abandoned and the offset of its withheld bytes.
  ;;
  ;; `reason` is a member the contract neither requires to match nor licenses
  ;; to differ. It is compared here rather than left as an orphan: if the two
  ;; lanes resolve the declaration by different keys -- the interpreter by name,
  ;; the emitter by resolved code -- `reason` is the only member that divergence
  ;; moves. Do not narrow this list on the argument that both lanes "build it
  ;; from the same declaration"; how each lane FINDS that declaration is what
  ;; this member checks.
  ;;
  ;; The span an error abandoned and the stream offset where its withheld bytes
  ;; begin are comparable for the same reason the position kind is -- each lane
  ;; reaches them through its OWN span-open, at its own cursor -- so they are
  ;; compared, not left as two more orphans.
  (define projected-members 8)

  ;; The deliberately excluded member. Exposed so a lane can assert that both
  ;; executors REPORT a state id while the comparison omits it -- positively,
  ;; rather than by the omission being invisible.
  (define (error-state-id e)
    (and (parser-error? e) (parser-error-state-id e))))
