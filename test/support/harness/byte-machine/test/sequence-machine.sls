;;; A four-byte accept-sequence proving machine for Milestone 2 Slice ①
;;; (incremental execution): s0 reads 1 -> s1 reads 2 -> s2 reads 3 -> s3 reads
;;; 4 -> stop; every fallback REEXECUTES into the reject error, so a wrong byte's
;;; `next` points AT the offending byte (parent §11.5). Built only through
;;; (byte-machine graph). Four dispatch nodes give three interior split points,
;;; so §22.5 split-point pairs and multi-split schedules are satisfiable, and it
;;; is the first machine with MULTIPLE dispatch nodes to go through both
;;; executors (new lowering coverage vs the one-byte and single-dispatch property
;;; machines).
(library (byte-machine test sequence-machine)
  (export make-sequence-machine sequence-bytes)
  (import (rnrs) (byte-machine graph))
  (define sequence-bytes '(1 2 3 4))
  (define (make-sequence-machine)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine 'seq 's0 '() '() '() (list eof-decl rej-decl)
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-byte-dispatch-node 's1
                (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 's2 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-byte-dispatch-node 's2
                (list (make-byte-case (make-exact-byte-matcher 3) (make-edge 's3 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-byte-dispatch-node 's3
                (list (make-byte-case (make-exact-byte-matcher 4) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))))
