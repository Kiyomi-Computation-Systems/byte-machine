;;; Consumer library for the Milestone 0 cross-library identity proof.
;;;
;;; Inline R6RS (decision 0006): the library owns its own text; nothing is
;;; included.
;;;
;;; placeholder?, placeholder-value and placeholder-marker come from this
;;; library's import of (byte-machine placeholder) -- imported, never copied.
;;; Redefining them here inline is the surviving form of the ownership
;;; defect decisions 0002/0003 guarded in the include era: the consumer
;;; would carry its own tag and its own marker, both identity cases would
;;; answer wrongly, nothing would raise, and every lane that imports only
;;; the owner would still pass. SchemeMutationSuite.cmake makes exactly that
;;; edit and requires the identity lane to fail.
;;;
;;; This is also the mechanism Milestone 1 runs on, where the verifier calls
;;; graph procedures it does not define and gets them by importing
;;; (byte-machine graph).
;;;
;;; This carries no byte-machine semantics and is deleted in Milestone 1
;;; (milestone-0-portability-spike.md, decision D4).

;;; The reject branch, not the accept branch, carries the singleton. That is
;;; deliberate: it means the identity assertion needs no placeholder constructed
;;; in order to be made, so the identity claim does not silently depend on the
;;; recognition claim already working. See section 5.2 of
;;; milestone-0-slice-4-cross-library-identity.md.
;;;
;;; This models section 7.2's rule that interpreted callbacks must return the
;;; runtime's own singleton outcome values rather than lookalikes.
(library (byte-machine placeholder-consumer)
  (export consume)
  (import (rnrs) (byte-machine placeholder))
(define (consume p)
  (if (placeholder? p)
      (placeholder-value p)
      (placeholder-marker)))
)
