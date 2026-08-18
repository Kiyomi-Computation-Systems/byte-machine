;;; Chez ahead-of-time compilation step.
;;;
;;; Usage:
;;;   chez-compile.ss --library-root <dir> [--library-root <dir> ...]
;;;                   --object-dir <dir>   [--object-dir <dir> ...]
;;;                   --source-dir <dir>   [--source-dir <dir> ...]
;;;                   --program <path> --output <path>
;;;
;;; The nth --object-dir pairs with the nth --library-root. The pairing is
;;; positional because library-directories is a list of pairs and there is no
;;; flag spelling of a pair; the counts are asserted equal below, because a
;;; silent mismatch would compile some libraries into a directory the AOT
;;; launcher never puts on its library path, and that lane would then fail at
;;; run time with an unbound library rather than here with a sentence.
;;;
;;; WHY THE FLAG BLOCK BELOW IS A THIRD COPY
;;;
;;; known-flags, required-flags, single-valued-flags and the three loops under
;;; them are the same code chez-source.ss carries. The duplication is
;;; deliberate and it is not a candidate for extraction. A Chez --script
;;; program runs standalone with no library path and no source-directories, so
;;; the only way to share this block is to `load` it from an absolute path --
;;; and that path would have to arrive as a command-line argument, read before
;;; the code that reads command-line arguments exists. The bootstrap argument
;;; that buys costs every launcher and every call site a positional they must
;;; agree on, whose failure mode is a `load` of the wrong file rather than a
;;; named refusal.
;;;
;;; The cost of the copy is that a flag-vocabulary decision fixed in one
;;; launcher is not fixed in the others. Each copy is mutated separately for
;;; that reason: the copies are independent decisions, not one decision spelled
;;; three times.
;;;
;;; WHY compile-imported-libraries IS ON HERE AND OFF THERE
;;;
;;; This step exists to produce the objects; the run must never produce one.
;;; A run that compiled would be doing at run time what this step claims to
;;; have done at build time, and the lane would pass having proved nothing
;;; about the artifact.

(define (path-directory path)
  (let loop ((i (- (string-length path) 1)))
    (cond ((< i 0) ".")
          ((or (char=? (string-ref path i) #\/)
               (char=? (string-ref path i) #\\))
           (substring path 0 i))
          (else (loop (- i 1))))))

(define (die message)
  (display "byte-machine-launcher: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define known-flags
  (list "--library-root" "--object-dir" "--source-dir" "--program" "--output"))

;; One per line, in a different order from known-flags, so each entry is unique
;; text that a mutation can remove on its own.
(define required-flags
  (list "--output"
        "--program"
        "--object-dir"
        "--library-root"
        "--source-dir"))

(define single-valued-flags
  (list "--program" "--output"))

(define args (command-line-arguments))

(let loop ((rest args))
  (cond ((null? rest) #t)
        ((not (member (car rest) known-flags))
         (die (string-append "unknown flag: " (car rest))))
        ((null? (cdr rest))
         (die (string-append "flag has no value: " (car rest))))
        (else (loop (cddr rest)))))

(define (flag-values flag)
  (let loop ((rest args) (found (list)))
    (cond ((null? rest) (reverse found))
          ((string=? (car rest) flag) (loop (cddr rest) (cons (cadr rest) found)))
          (else (loop (cddr rest) found)))))

(for-each
 (lambda (flag)
   (if (null? (flag-values flag))
       (die (string-append "missing required flag: " flag))))
 required-flags)

(for-each
 (lambda (flag)
   (if (> (length (flag-values flag)) 1)
       (die (string-append "flag given more than once: " flag))))
 single-valued-flags)

(define library-roots (flag-values "--library-root"))
(define object-dirs (flag-values "--object-dir"))
(define source-dirs (flag-values "--source-dir"))
(define program (car (flag-values "--program")))
(define output (car (flag-values "--output")))

(if (not (= (length library-roots) (length object-dirs)))
    (die (string-append "each --library-root needs one --object-dir, but there are "
                        (number->string (length library-roots))
                        " roots and "
                        (number->string (length object-dirs))
                        " object directories")))

(compile-imported-libraries #t)
(generate-wpo-files #f)

(source-directories (append source-dirs (list (path-directory program))))
(library-directories (map cons library-roots object-dirs))

(compile-program program output)

(display "byte-machine-launcher: compiled ")
(display output)
(newline)
(flush-output-port (current-output-port))
(exit 0)
