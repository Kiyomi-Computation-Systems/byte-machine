;;; (byte-machine graph): the public construction API. It re-exports the M1
;;; source-IR constructors from the private ir library so grammar authors build
;;; machines without touching internals. Constructors validate local shape only;
;;; verification is (byte-machine verify)'s job (parent §9.1).
(library (byte-machine graph)
  (export make-machine make-byte-dispatch-node make-byte-case
          make-exact-byte-matcher make-edge make-stop-node make-error-node
          make-error-declaration)
  (import (only (byte-machine private ir)
                make-machine make-byte-dispatch-node make-byte-case
                make-exact-byte-matcher make-edge make-stop-node make-error-node
                make-error-declaration)))
