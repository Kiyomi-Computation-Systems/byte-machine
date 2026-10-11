;;; interpreter ≡ generated over the idle-vs-truncation EOF machine. Proves the
;;; generated finish path — the exec closure's finish? EOF branch — equals the
;;; interpreter's parser-finish!/eof-target execution for BOTH feed and finish: idle completion at entry
;;; (finish -> finished), one-byte truncation (feed 1 then finish -> error/
;;; truncated-input), the full sequence (feed 1 2 -> stopped), and every one of
;;; the 256 first bytes fed then finished. The interpreter is the reference; a
;;; disagreement here is a real lowering defect in the eof encoding / finish arm.
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection) (byte-machine test eof-machine)
        (byte-machine graph) (byte-machine verify) (byte-machine interpret)
        (byte-machine runtime) (byte-machine compile))
(harness-begin "differential.eof")
(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-eof "no tmpdir" #f)))
(define genfile (string-append tmpdir "/generated-eof.sls"))
(define m (make-eof-machine))
(define cm-ref (make-interpreted-machine (verify-machine m)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine m '()) 'eof-parser p)))
(load genfile)
(define cm-gen (eval 'eof-parser (environment '(generated eofm))))
;; feed the prefix, then finish; return the finish (status stream-offset error).
(define (rfields cm bytes)
  (let ((p (make-parser cm '() #f)))
    (for-each (lambda (b) (parser-feed! p (make-bytevector 1 b) 0 1)) bytes)
    (let ((rf (parser-finish! p)))
      (list (parser-result-status rf) (parser-result-stream-offset rf)
            (project-error (parser-result-error rf))))))
(harness-group "interpreter and generated agree on finish after every prefix"
  (lambda ()
    (harness-case "idle, one-byte truncation, and full sequence agree"
      (lambda ()
        (check-equal "idle" (rfields cm-gen '()) (rfields cm-ref '()))
        (check-equal "trunc" (rfields cm-gen '(1)) (rfields cm-ref '(1)))
        (check-equal "full+finish" (rfields cm-gen '(1 2)) (rfields cm-ref '(1 2)))
        (check-equal "idle is finished" (car (rfields cm-gen '())) 'finished)
        (check-equal "trunc is error" (car (rfields cm-gen '(1))) 'error)))
    (harness-case "all 256 first bytes: op and gen agree on feed-then-finish"
      (lambda ()
        ;; `bad` alone proves no DISAGREEMENT was seen, not that the loop ran --
        ;; a loop that silently never executed would leave `bad` at its seeded
        ;; 'none too. last-byte is set on every iteration regardless of outcome,
        ;; so it reaches its final value 255 only if all 256 iterations ran.
        (let ((bad 'none) (last-byte 'unset))
          (let loop ((b 0))
            (when (< b 256)
              (unless (equal? (rfields cm-ref (list b)) (rfields cm-gen (list b)))
                (when (eq? bad 'none) (set! bad b)))
              (set! last-byte b)
              (loop (+ b 1))))
          (check-equal "no byte disagreed" bad 'none)
          (check-equal "loop ran all 256 bytes" last-byte 255))))))
(harness-finish)
