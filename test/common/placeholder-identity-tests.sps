;;; The cross-library identity tests, as a program. Merged from its
;;; .chez.sps wrapper by the include collapse (decision 0006). Both
;;; libraries are imported here, never copied: importing the owner is the
;;; claim under test.

(import (rnrs)
        (byte-machine test harness)
        (byte-machine placeholder)
        (byte-machine placeholder-consumer))

(harness-begin "portability.placeholder-identity")

;;; Cross-library identity tests. Milestone 0 slice 4, deliverable D3.
;;;
;;; SHARED BODY: included verbatim by placeholder-identity-tests.chez.sps, its
;;; sole owner wrapper (decisions 0002/0003), which imports BOTH libraries --
;;; the owner for make-placeholder and placeholder-marker, the consumer for
;;; consume. Needing both names in scope at once is exactly why these cases
;;; cannot live in placeholder-tests.scm, whose header says cross-library
;;; identity is this slice's proof and is not attempted there.
;;;
;;; Under a consumer that included the owner's body instead of importing it,
;;; both cases below answer wrongly and nothing raises. Every other lane in this
;;; tree still passes, because every other lane imports only the owner. That is
;;; the whole reason this file exists.

(harness-group "placeholder-identity"
  (lambda ()

    (harness-case "recognition crosses a library boundary"
      (lambda ()
        ;; Built through the owner, read through the consumer. A second copy of
        ;; the body would give the consumer its own tag, so the owner's value
        ;; would stop matching and consume would return the consumer's marker
        ;; instead of 7.
        (check-equal "the owner built it and the consumer read it"
                     (consume (make-placeholder 7))
                     7)))

    (harness-case "the singleton crosses both imports"
      (lambda ()
        ;; Deliberately a non-placeholder: this drives consume down the branch
        ;; that yields the owner's singleton, so the identity claim does not
        ;; silently depend on the recognition claim above already holding.
        (check "the consumer's outcome is the owner's own object"
               (eq? (consume 7) (placeholder-marker)))))))

(harness-finish)
