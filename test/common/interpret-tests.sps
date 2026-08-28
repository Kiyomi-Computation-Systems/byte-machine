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

(harness-group "EOF execution through the interpreter"
  (lambda ()
    (define (m)
      (make-machine 'eofm 's0 '() '() '()
        (list (make-error-declaration 'default-eof 'eof "eof" #f)
              (make-error-declaration 'rejected 'unexpected-byte "bad" #f)
              (make-error-declaration 'truncated 'truncated-input "trunc" #f))
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
                (make-edge 'reject 'reexecute) 'done #f)          ; idle: eof -> finish
              (make-byte-dispatch-node 's1
                (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) 'trunc #f)         ; truncation: eof -> error
              (make-stop-node 'stop #f)
              (make-finish-node 'done #f)
              (make-error-node 'trunc 'truncated #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (define (fresh) (make-parser (make-interpreted-machine (verify-machine (m))) '() #f))
    (harness-case "finish with no input is idle completion -> finished"
      (lambda ()
        (let ((r (parser-finish! (fresh))))
          (check-equal "finished" (parser-result-status r) 'finished))))
    (harness-case "finish after one byte is truncation -> error with the code"
      (lambda ()
        (let ((p (fresh)))
          (parser-feed! p (make-bytevector 1 1) 0 1)              ; at s1, offset 1
          (let ((r (parser-finish! p)))
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "truncation code" (parser-result-error r) 'truncated-input)
            (check-equal "eof at offset 1" (parser-result-stream-offset r) 1)))))
    (harness-case "feeding both bytes stops; finishing a stopped parser stays stopped (§12.2)"
      (lambda ()
        (let ((p (fresh)))
          (parser-feed! p (make-bytevector 2 0) 0 0)              ; empty feed, still ready
          (parser-feed! p (let ((v (make-bytevector 2))) (bytevector-u8-set! v 0 1)
                            (bytevector-u8-set! v 1 2) v) 0 2)    ; -> stopped
          (check-equal "stopped" (parser-lifecycle p) 'stopped)
          (check-equal "finish after stop stays stopped" (parser-result-status (parser-finish! p)) 'stopped))))
    (harness-case "finishing a finished parser stays finished; lifecycle tracks it"
      (lambda ()
        (let ((p (fresh)))
          (parser-finish! p)
          (check-equal "lifecycle finished" (parser-lifecycle p) 'finished)
          (check-equal "again finished" (parser-result-status (parser-finish! p)) 'finished))))
    (harness-case "a dispatch with eof-target #f routes EOF to the default-eof error"
      (lambda ()
        (let ((p (make-parser
                  (make-interpreted-machine
                   (verify-machine
                    (make-machine 'dm 's0 '() '() '()
                      (list (make-error-declaration 'default-eof 'eof "eof" #f))
                      (list (make-byte-dispatch-node 's0
                              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                              (make-edge 'stop 'reexecute) #f #f)   ; eof-target #f -> default
                            (make-stop-node 'stop #f))
                      'default-eof #f)))
                  '() #f)))
          (let ((r (parser-finish! p)))
            (check-equal "default-eof error" (parser-result-status r) 'error)
            (check-equal "default-eof code" (parser-result-error r) 'eof)))))))

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
