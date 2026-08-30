;;; (byte-machine graph): the public construction API. It re-exports the source-IR
;;; constructors from the private ir library so grammar authors build machines
;;; without touching internals. Constructors validate local shape only;
;;; verification is (byte-machine verify)'s job (parent §9.1).
;;;
;;; Milestone 3 Slice ① adds the three class matchers and `ascii-bytes`
;;; (§9.1:292-294, :299) together with the matcher predicates and accessors, so a
;;; grammar author can test what they built. `matcher-bytes` -- the internal
;;; canonicalization spine the verifier, normalizer and interpreter share -- is
;;; deliberately NOT re-exported: §9.1's construction list does not contain it.
(library (byte-machine graph)
  (export make-machine make-byte-dispatch-node make-byte-case
          make-exact-byte-matcher make-edge make-stop-node make-finish-node
          make-pause-node make-error-node make-error-declaration
          make-byte-set-matcher make-byte-range-matcher
          make-byte-complement-matcher ascii-bytes
          matcher? exact-byte-matcher? exact-byte-matcher-byte
          byte-set-matcher? byte-set-matcher-bytes
          byte-range-matcher? byte-range-matcher-low byte-range-matcher-high
          byte-complement-matcher? byte-complement-matcher-matcher
          make-sequence-dispatch-node make-sequence-case
          sequence-dispatch-node? sequence-dispatch-node-name
          sequence-dispatch-node-cases sequence-dispatch-node-mismatch
          sequence-dispatch-node-eof-target
          sequence-case? sequence-case-bytes sequence-case-target)
  (import (only (byte-machine private ir)
                make-machine make-byte-dispatch-node make-byte-case
                make-exact-byte-matcher make-edge make-stop-node make-finish-node
                make-pause-node make-error-node make-error-declaration
                make-byte-set-matcher make-byte-range-matcher
                make-byte-complement-matcher ascii-bytes
                matcher? exact-byte-matcher? exact-byte-matcher-byte
                byte-set-matcher? byte-set-matcher-bytes
                byte-range-matcher? byte-range-matcher-low byte-range-matcher-high
                byte-complement-matcher? byte-complement-matcher-matcher
                make-sequence-dispatch-node make-sequence-case
                sequence-dispatch-node? sequence-dispatch-node-name
                sequence-dispatch-node-cases sequence-dispatch-node-mismatch
                sequence-dispatch-node-eof-target
                sequence-case? sequence-case-bytes sequence-case-target)))
