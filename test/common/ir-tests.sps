;;; Round-trip tests for the private descriptor IR: construct the pieces of the
;;; one-byte machine and read every field back. A name missing from
;;; (byte-machine private ir) is a load failure, not a silent gap.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private ir)
        (byte-machine private conditions))

(harness-begin "unit.ir")

(harness-group "matchers and edges"
  (lambda ()
    (harness-case "an exact-byte matcher carries its byte"
      (lambda ()
        (check-equal "byte" (exact-byte-matcher-byte (make-exact-byte-matcher 0)) 0)))
    (harness-case "an edge carries its target and mode"
      (lambda ()
        (let ((e (make-edge 'stop 'advance)))
          (check-equal "target" (edge-target e) 'stop)
          (check-equal "mode" (edge-mode e) 'advance))))))

(harness-group "constructor local-shape validation"
  (lambda ()
    (harness-case "a byte above 255 is rejected"
      (lambda ()
        (check-raises "out of range"
                      byte-machine-contract-condition?
                      (lambda () (make-exact-byte-matcher 256)))))
    (harness-case "an unknown edge mode is rejected"
      (lambda ()
        (check-raises "bad mode"
                      byte-machine-contract-condition?
                      (lambda () (make-edge 'stop 'teleport)))))
    (harness-case "a dispatch node cannot be built without an edge fallback"
      (lambda ()
        (check-raises "no fallback"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-dispatch-node 'start '() 'not-an-edge #f #f)))))))

(harness-group "the one-byte machine descriptor"
  (lambda ()
    (harness-case "the machine reads back its entry, nodes, and default eof error name"
      (lambda ()
        (let* ((accept-edge (make-edge 'stop 'advance))
               (accept-case (make-byte-case (make-exact-byte-matcher 0) accept-edge #f))
               (reject-edge (make-edge 'reject 'reexecute))
               (start (make-byte-dispatch-node 'start (list accept-case) reject-edge #f #f))
               (stop (make-stop-node 'stop #f))
               (eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (reject (make-error-node 'reject 'rejected #f))
               (m (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
                                (list start stop reject) 'default-eof #f)))
          (check-equal "entry" (machine-entry m) 'start)
          (check-equal "node count" (length (machine-nodes m)) 3)
          (check-equal "default eof error name" (machine-default-eof-error m) 'default-eof)
          (check-equal "error node references the reject declaration by name"
                       (error-node-error-name reject) 'rejected)
          (check-equal "start fallback target"
                       (edge-target (byte-dispatch-node-fallback start)) 'reject))))))

(harness-finish)
