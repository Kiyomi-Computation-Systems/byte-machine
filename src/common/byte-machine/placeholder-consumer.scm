;;; Consumer body for the Milestone 0 cross-library identity proof.
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only. No library form, no
;;; include, no runtime-specific identifier. Included by exactly one owner
;;; library per runtime, one such library living in each runtime's own source
;;; tree.
;;;
;;; EVERY IDENTIFIER THIS BODY USES BUT DOES NOT DEFINE COMES FROM ITS OWNER
;;; WRAPPER'S IMPORT LIST
;;;
;;; placeholder?, placeholder-value and placeholder-marker are free here. They
;;; are supplied by (byte-machine placeholder), which each wrapper imports --
;;; never by a second include of that library's body. Replacing the import with
;;; an include is the defect byte-machine-implementation-plan.md's section 7.2
;;; forbids, and it is silent: both identity cases simply answer wrongly,
;;; nothing raises, and every lane that imports only the owner still passes.
;;;
;;; This is also the mechanism Milestone 1 runs on, where verify.scm calls graph
;;; procedures it does not define and verify.sls supplies them by importing
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
(define (consume p)
  (if (placeholder? p)
      (placeholder-value p)
      (placeholder-marker)))
