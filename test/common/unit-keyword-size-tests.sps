;;; The emitted-size measurement for the keyword table. The 47 llhttp methods
;;; built as ONE keyword-table node emit far less than the equivalent trie of
;;; byte-dispatch nodes (one per distinct prefix). Both are rendered through the
;;; real emitter here; the win is asserted structurally (the trie's node count
;;; and the compact table's single state) and by a robust byte ratio, with the
;;; exact measured bytes recorded beside the assertion -- measured through this
;;; lane.
;;;
;;; MEASURED (this lane, both modes -- emitter output is mode-independent):
;;; trie 245 source nodes / 242 byte-dispatch prefix nodes / 96169 emitted
;;; bytes; keyword table 1 state / 2795 emitted bytes -- a 34.4x reduction.
;;; Re-derive the bytes with:
;;;   chez --libdirs "src:test/support/harness" --script - <<< '(import (rnrs)
;;;     (byte-machine test keyword-method-table) (byte-machine compile))
;;;     (for-each (lambda (m n) (display (bytevector-length
;;;       (render-machine (compile-machine m (quote ())) n))) (newline))
;;;       (list (make-method-trie-machine) (make-method-keyword-machine))
;;;       (quote (methodtrie methodkw)))'
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test keyword-method-table)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine private ir))

(harness-begin "unit.keyword-size")

(define trie (make-method-trie-machine))
(define kwt (make-method-keyword-machine))
(define (emitted m name) (bytevector-length (render-machine (compile-machine m '()) name)))

(harness-group "the 47-method table verifies both ways"
  (lambda ()
    (harness-case "the trie and the keyword table both verify"
      (lambda ()
        (check "the trie verifies" (verification-ok? (verify-machine trie)))
        (check "the keyword table verifies" (verification-ok? (verify-machine kwt)))
        (check-equal "there are forty-seven methods" (length method-names) 47)))))

(harness-group "the compact table replaces one-node-per-prefix"
  (lambda ()
    (harness-case "the trie is one byte-dispatch node per distinct prefix (measured off the built machine)"
      (lambda ()
        ;; read off the BUILT machine, not the prefix list it was built from
        (check-equal "the trie has 242 byte-dispatch prefix nodes"
                     (length (filter byte-dispatch-node? (machine-nodes trie))) 242)))
    (harness-case "the keyword table is a single state"
      (lambda ()
        (check-equal "one keyword-table node"
                     (length (filter keyword-table-node? (machine-nodes kwt))) 1)
        (check-equal "and no byte-dispatch nodes"
                     (length (filter byte-dispatch-node? (machine-nodes kwt))) 0)))))

(harness-group "the compact table emits far less than the trie (criterion 7)"
  (lambda ()
    (harness-case "the keyword table emits under a tenth of the trie's bytes"
      (lambda ()
        (let ((trie-bytes (emitted trie 'methodtrie))
              (kwt-bytes (emitted kwt 'methodkw)))
          ;; recorded measurement (both modes): 96169 vs 2795 (34.4x).
          ;; The assertion is a robust floor, not the exact bytes (those are not a
          ;; golden), so an unrelated emitter tweak does not redden the size win.
          (check "the trie emits more than ten times the compact table"
                 (> trie-bytes (* 10 kwt-bytes)))
          (check "the compact table emits at least 20x fewer bytes than the trie"
                 (> trie-bytes (* 20 kwt-bytes)))
          (check "both emit a nonzero, plausible number of bytes"
                 (and (> kwt-bytes 500) (> trie-bytes 50000))))))))

(harness-finish)
