;;; Triggers a harness error so the process exits with status 2.
;;;
;;; A duplicate case id means one registration silently became unreachable,
;;; which is a defect in the suite rather than a failing assertion. It must
;;; therefore produce status 2 and stay distinguishable from the status 1 that
;;; harness-failing.scm produces.

(harness-case "duplicated" (lambda () (check "this one runs" #t)))
(harness-case "duplicated" (lambda () (check "this one never runs" #t)))
