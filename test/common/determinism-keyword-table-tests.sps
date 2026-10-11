;;; Deterministic emission of the keyword-table machine, proved against a
;;; committed golden, and the emitted library's keyword walks proved directly.
;;; A keyword-table node renders an arm no other golden contains -- the compact
;;; table datum (encoder tag 15) walked by `byte-machine-keyword-step/v1`, with
;;; the resumable compound `current` and the per-table fold byte -- so a
;;; determinism claim about emission that excluded it would be a claim about the
;;; other machines only.
;;;
;;; The case-INSENSITIVE fixture is the golden, because it is the strictly richer
;;; render: it carries the fold datum the case-sensitive table omits, and its
;;; walks exercise the fold as well as the longest-match, no-match and EOF arms.
;;;
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test keyword-table-machine)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.keyword-table")

(define ok (compile-machine (make-keyword-table-ci-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_KEYWORD_TABLE_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism
                             "BYTE_MACHINE_KEYWORD_TABLE_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'kwtableci) (render-machine ok 'kwtableci))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'kwtableci)
                     (adapter-file-bytes golden-file))))))

(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'determinism-keyword-table "no tmpdir" #f)))
(define genfile (string-append tmpdir "/determinism-keyword-table.sls"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine ok 'kwtableci p)))
(load genfile)
(define cm (eval 'kwtableci (environment '(generated kwtableci))))

(define (str->bv s) (u8-list->bytevector (map char->integer (string->list s))))
(define (feed p s) (parser-feed! p (str->bv s) 0 (string-length s)))

(harness-group "the golden output compiles and executes the keyword walks"
  (lambda ()
    ;; Each walk drives the arm the golden's rendered text is FOR.
    (harness-case "a folded casing matches the same target as the canonical form"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p "GeT ")))
          (check-equal "stopped" (parser-result-status r) 'stopped)
          (check-equal "span closes at the keyword, not the delimiter" (parser-result-consumed r) 3)
          (check-equal "the matched keyword's target" (parser-state-name p) 'got-get))))
    (harness-case "the longer keyword wins when the input extends to it"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p "get-parameter ")))
          (check-equal "stopped" (parser-result-status r) 'stopped)
          (check-equal "thirteen consumed" (parser-result-consumed r) 13)
          (check-equal "the long target" (parser-state-name p) 'got-gp))))
    (harness-case "close and closed are distinguished"
      (lambda ()
        (let ((p (make-parser cm '() #f)))
          (feed p "closed ")
          (check-equal "closed" (parser-state-name p) 'got-closed))
        (let ((p (make-parser cm '() #f)))
          (feed p "close ")
          (check-equal "close" (parser-state-name p) 'got-close))))
    (harness-case "the walk resumes across a feed boundary"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (bv (str->bv "get-parameter ")))
          (parser-feed! p bv 0 4)               ; "get-"
          (let ((r (parser-feed! p bv 4 14)))   ; "parameter "
            (check-equal "stopped after the split" (parser-result-status r) 'stopped)
            (check-equal "the long target" (parser-state-name p) 'got-gp)))))
    (harness-case "a non-keyword first byte is the no-match error, consuming nothing"
      (lambda ()
        (let* ((p (make-parser cm '() #f)) (r (feed p "xyz")))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "nothing consumed" (parser-result-consumed r) 0)
          (check-equal "reason" (parser-error-reason (parser-result-error r)) "unexpected byte"))))
    (harness-case "EOF mid-table takes the eof-target, never a keyword"
      (lambda ()
        (let ((p (make-parser cm '() #f)))
          (feed p "GET")
          (let ((r (parser-finish! p)))
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "reason" (parser-error-reason (parser-result-error r))
                         "incomplete keyword at end of input")
            (check-equal "position kind" (parser-error-position-kind (parser-result-error r)) 'eof)
            (check-equal "at the final offset" (parser-error-offset (parser-result-error r)) 3)))))))

(harness-finish)
