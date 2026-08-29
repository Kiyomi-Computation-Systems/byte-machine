;;; The pause/resume proving machine for Milestone 2 Slice ③, built only
;;; through (byte-machine graph). Feed: byte 1 advances into pause p1
;;; (continuation s1); after resume, byte 2 stops. EOF at entry routes to the
;;; eof-path pause pe (continuation done/finish): finish! pauses, resume,
;;; finish! -> finished. EOF after byte 1 (at s1) is truncation ('trunc ->
;;; error). Shared by the Slice ③ interpreter tests, the pause differential,
;;; and the pause determinism golden so the graph is written once.
(library (byte-machine test pause-machine)
  (export make-pause-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-pause-machine)
    (make-machine 'pausem 's0 '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'truncated 'truncated-input "truncated input" #f))
      (list (make-byte-dispatch-node 's0
              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'p1 'advance) #f))
              (make-edge 'reject 'reexecute) 'pe #f)
            (make-pause-node 'p1 's1 #f)
            (make-byte-dispatch-node 's1
              (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
              (make-edge 'reject 'reexecute) 'trunc #f)
            (make-pause-node 'pe 'done #f)
            (make-stop-node 'stop #f)
            (make-finish-node 'done #f)
            (make-error-node 'trunc 'truncated #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))
