;;; The pause/resume proving machine for Milestone 2 Slice ③, built only
;;; through (byte-machine graph). Feed: byte 1 advances into pause p1
;;; (continuation s1); after resume, byte 2 stops. EOF at entry routes to the
;;; eof-path pause pe (continuation done/finish): finish! pauses, resume,
;;; finish! -> finished. EOF after byte 1 (at s1) is truncation ('trunc ->
;;; error). Shared by the Slice ③ interpreter tests, the pause differential,
;;; and the pause determinism golden so the graph is written once.
;;;
;;; Milestone 12: p1 and pe carry DISTINCT optional reason declarations
;;; (`paused-cont` on the feed pause, `paused-eofr` on the EOF pause) so the pause
;;; lanes prove a pause reports its own (code, reason) -- two different nodes, two
;;; different reasons, the error slot still #f. Adding the reasons does not change
;;; the graph shape, so the existing pause-interpret assertions (which read only
;;; status/offset/lifecycle, not the pause slot) are unaffected; the differential
;;; lane gains the pause-slot projection, and the determinism golden re-baselines.
(library (byte-machine test pause-machine)
  (export make-pause-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-pause-machine)
    (make-machine 'pausem 's0 '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'truncated 'truncated-input "truncated input" #f)
            (make-error-declaration 'paused-cont 'paused-continue "paused mid-feed" #f)
            (make-error-declaration 'paused-eofr 'paused-at-eof "paused at end of input" #f))
      (list (make-byte-dispatch-node 's0
              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'p1 'advance) #f))
              (make-edge 'reject 'reexecute) 'pe #f)
            (make-pause-node 'p1 's1 'paused-cont #f)
            (make-byte-dispatch-node 's1
              (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
              (make-edge 'reject 'reexecute) 'trunc #f)
            (make-pause-node 'pe 'done 'paused-eofr #f)
            (make-stop-node 'stop #f)
            (make-finish-node 'done #f)
            (make-error-node 'trunc 'truncated #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))
