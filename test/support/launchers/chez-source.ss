;;; Chez source-mode launcher.
;;;
;;; Arguments: <library-root> <shared-dir> <object-guard-dir> <program>
;;;
;;; THE OBJECT GUARD
;;;
;;; Chez looks for a library's compiled object only in the object half of a
;;; library-directories pair. Pairing the library root with a directory the
;;; build keeps empty therefore makes a .so left beside the sources impossible
;;; to load, which is what lets this lane call itself "source" honestly.
;;; Pointing library-directories at the source root alone would do the opposite:
;;; the object would be looked for next to the source and silently preferred.
;;;
;;; WHAT THIS LAUNCHER DELIBERATELY DOES NOT CHECK
;;;
;;; Petite, and whether the build is threaded. Discovery rejects Petite at
;;; configure time and re-probes the exact binary registered here, and decision
;;; 0001 refused to gate on threading because byte-machine has no threads. A
;;; second copy of either rule would be a requirement inherited rather than
;;; owned.

(define (path-directory path)
  (let loop ((i (- (string-length path) 1)))
    (cond ((< i 0) ".")
          ((or (char=? (string-ref path i) #\/)
               (char=? (string-ref path i) #\\))
           (substring path 0 i))
          (else (loop (- i 1))))))

;; Status 2 is the harness's "harness, configuration, or registration error".
;; A launcher that could not set up the lane has not run a test at all, and must
;; not be mistaken for one that ran and failed.
(define (die message)
  (display "byte-machine-launcher: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define args (command-line-arguments))

(if (not (= (length args) 4))
    (die "usage: chez-source.ss <library-root> <shared-dir> <object-guard-dir> <program>"))

(define library-root (list-ref args 0))
(define shared-dir (list-ref args 1))
(define object-guard-dir (list-ref args 2))
(define program (list-ref args 3))

(if (not (file-directory? object-guard-dir))
    (die (string-append "object guard directory does not exist: " object-guard-dir)))

;; Asserted, not assumed. A guard directory that has acquired a file is no
;; longer a guard, and the lane would go on reporting "source" while loading
;; whatever was put there.
(if (not (null? (directory-list object-guard-dir)))
    (die (string-append "object guard directory must be empty but is not: "
                        object-guard-dir)))

(compile-imported-libraries #f)

;; A program may include bodies that live beside it, so its own directory joins
;; the shared directory on the source path. Both are explicit: nothing resolves
;; against the current working directory.
(source-directories (list shared-dir (path-directory program)))
(library-directories (list (cons library-root object-guard-dir)))

(load-program program)
