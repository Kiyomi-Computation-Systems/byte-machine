;;; The idle-vs-truncation proving machine, built only through
;;; (byte-machine graph). Accepts the two-byte sequence 1 2 (feed ->
;;; stopped). At entry s0, EOF is idle completion (eof-target -> finish 'done ->
;;; finished); after one byte at s1, EOF is truncation (eof-target -> error
;;; 'trunc -> error). Shared by the interpreter tests and the
;;; interpreter≡generated differential so the graph is written once.
(library (byte-machine test eof-machine)
  (export make-eof-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-eof-machine)
    (make-machine 'eofm 's0 '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'truncated 'truncated-input "truncated input" #f))
      (list (make-byte-dispatch-node 's0
              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
              (make-edge 'reject 'reexecute) 'done #f)
            (make-byte-dispatch-node 's1
              (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
              (make-edge 'reject 'reexecute) 'trunc #f)
            (make-stop-node 'stop #f)
            (make-finish-node 'done #f)
            (make-error-node 'trunc 'truncated #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))
