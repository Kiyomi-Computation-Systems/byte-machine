;;; The fixed one-byte proving machine, shared by the differential and example
;;; lanes so the graph descriptor is written once. Built only
;;; through (byte-machine graph).
(library (byte-machine test one-byte-machine)
  (export make-one-byte-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-one-byte-machine)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
        (list (make-byte-dispatch-node 'start
                (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))))
