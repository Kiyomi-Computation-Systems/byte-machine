;;; The public graph façade builds the one-byte machine with no private import.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (only (byte-machine private ir) machine? machine-entry machine-default-eof-error))

(harness-begin "unit.graph")

(harness-group "graph façade"
  (lambda ()
    (harness-case "the one-byte machine is constructible through (byte-machine graph)"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'one-byte 'start '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-byte-dispatch-node
                          'start
                          (list (make-byte-case (make-exact-byte-matcher 0)
                                                (make-edge 'stop 'advance) #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'start)
          (check-equal "default eof name" (machine-default-eof-error m) 'default-eof))))))

(harness-finish)
