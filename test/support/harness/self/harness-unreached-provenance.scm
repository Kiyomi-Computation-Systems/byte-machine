;;; A suite that was given a manifest and never verified it.
;;;
;;; PORTABILITY: a shared body, included verbatim by each runtime's thin
;;; wrapper. Common R6RS/R7RS subset only.
;;;
;;; Every other body in this tree reaches harness-verify-provenance! through
;;; harness-begin. This one deliberately does not call harness-begin at all, so
;;; the check is never reached -- and its lane is registered with a real
;;; manifest, so the build did declare text this run was supposed to verify.
;;; That combination is the defect: provenance configured and not performed.
;;;
;;; It still reaches harness-summary, which is where the guard lives. A body
;;; that reached neither could not be caught this way, which is stated at the
;;; guard itself.

(harness-case "a case runs, so the suite is not empty"
  (lambda ()
    (check "this assertion is beside the point; reaching the summary is not" #t)))

(harness-finish)
