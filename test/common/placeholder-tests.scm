;;; Shared tests for (byte-machine placeholder).
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only. This file is run
;;; unchanged on both runtimes through the two wrappers beside it, which is what
;;; makes it a parity proof rather than two similar test suites: a name missing
;;; from either owner library is a load failure on that runtime, not a silent
;;; gap.
;;;
;;; Cross-library identity is slice 4's proof and is not attempted here. What
;;; this body asserts about the marker is only that it is one object, which is
;;; what a fresh allocation buys and an interned symbol would have given for
;;; free.

(harness-group "placeholder"
  (lambda ()

    (harness-case "a constructed placeholder round-trips its value"
      (lambda ()
        (check-equal "value survives construction"
                     (placeholder-value (make-placeholder 7))
                     7)))

    (harness-case "placeholder? recognises what make-placeholder built"
      (lambda ()
        (check "recognised" (placeholder? (make-placeholder 7)))))

    (harness-case "placeholder? rejects a value that is not a vector"
      (lambda ()
        (check "an integer is not a placeholder" (not (placeholder? 7)))))

    (harness-case "placeholder? rejects a same-shaped vector with a symbol tag"
      (lambda ()
        ;; The executable form of the rule in placeholder.scm's header. The tag
        ;; is a freshly allocated vector precisely so that a symbol spelled like
        ;; it is not it; if the tag ever becomes a symbol, this case fails, and
        ;; with it the representation slice 4's identity test depends on.
        (check "a symbol spelled like the tag is not the tag"
               (not (placeholder? (vector 'byte-machine-placeholder 7))))))

    (harness-case "placeholder? rejects a mis-sized vector carrying the real tag"
      (lambda ()
        ;; The tag is private, but it is not out of reach: a legitimately built
        ;; placeholder hands it over through ordinary vector-ref. So the length
        ;; check is witnessable from outside the library after all, and deleting
        ;; it outright -- not merely perturbing its constant -- is a mutation
        ;; this body catches.
        (let ((real-tag (vector-ref (make-placeholder 0) 0)))
          (check "a length-3 vector carrying the real tag is not a placeholder"
                 (not (placeholder? (vector real-tag 1 2)))))))

    (harness-case "the marker is one object"
      (lambda ()
        (check "eq? to itself across two calls"
               (eq? (placeholder-marker) (placeholder-marker)))))))
