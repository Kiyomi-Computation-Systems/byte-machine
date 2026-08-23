;;; The reference interpreter runs the verified one-byte machine over all 256
;;; byte values through the runtime parser API.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine private conditions))

(harness-begin "unit.interpret")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node
           'start
           (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
           (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define cm (make-interpreted-machine (verify-machine one-byte)))
(define (run b)
  (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1))

(harness-group "interpreter refuses an unverified machine"
  (lambda ()
    (harness-case "a failed verification is rejected"
      (lambda ()
        (check-raises "refused"
                      byte-machine-contract-condition?
                      (lambda ()
                        (make-interpreted-machine
                         (verify-machine
                          (make-machine 'one-byte 'nowhere '() '() '() (list eof-decl rej-decl)
                                        (list (make-stop-node 'stop #f)) 'default-eof #f)))))))))

(harness-group "all 256 byte values"
  (lambda ()
    (harness-case "byte 0 is accepted and stops after one byte"
      (lambda ()
        (let ((r (run 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1))))
    (harness-case "every other byte is rejected at position 0 with the error code"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 1))
            (when (< b 256)
              (let ((r (run b)))
                (when (or (not (eq? (parser-result-status r) 'error))
                          (not (= (parser-result-stream-offset r) 0))
                          (not (eq? (parser-result-error r) 'unexpected-byte)))
                  (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte in 1..255 misbehaved" bad 'none))))))

(harness-finish)
