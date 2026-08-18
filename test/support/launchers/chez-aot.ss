;;; Chez ahead-of-time launcher.
;;;
;;; Usage:
;;;   chez-aot.ss --object-dir <dir> [--object-dir <dir> ...] --program <compiled>
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
;;; WHY source-directories IS EMPTIED
;;;
;;; This is the whole of the lane's honesty, and it is the AOT counterpart of
;;; the source lane's object guard. Only the object directories go on the
;;; library path and none of them holds Scheme source, so this process cannot
;;; expand a library: either the compiled objects are used or the run fails.
;;; Protium records that Chez otherwise treats an object whose recorded include
;;; dependencies cannot be located as out of date and quietly loads the source
;;; instead -- which would make this a second source lane reporting `mode=aot`.
;;; That claim has not been reproduced in this repository; see section 5.3 of
;;; the slice design and whatever task 5 recorded there.
;;;
;;; No object guard is needed and none is taken: this lane's library path is
;;; object directories, so there is no source half of a pair for an object to
;;; be preferred over.

(define (die message)
  (display "byte-machine-launcher: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define known-flags (list "--object-dir" "--program"))

;; One per line, in a different order from known-flags, so each entry is unique
;; text that a mutation can remove on its own.
(define required-flags
  (list "--program"
        "--object-dir"))

(define single-valued-flags (list "--program"))

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

(define object-dirs (flag-values "--object-dir"))
(define program (car (flag-values "--program")))

;; Asserted, not assumed. Without the object this lane cannot run at all, and
;; the failure Chez gives for a missing program file says nothing about which
;; build step should have produced it.
(if (not (file-exists? program))
    (die (string-append "compiled program does not exist: " program)))

(compile-imported-libraries #f)
(source-directories '())
(library-directories object-dirs)

(load-program program)
