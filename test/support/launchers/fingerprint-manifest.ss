;;; Compute the expected combined fingerprint of a manifest, at build time.
;;;
;;; Usage:
;;;   fingerprint-manifest.ss <shared-dir> <output> <body>...
;;;
;;; A lane prints the combined fingerprint of the bodies it executed. Until
;;; something reads that value back it is a claim, not a check: two lanes can
;;; print different digests for text both say they ran, and a suite that only
;;; prints stays green. This produces the value each lane must agree with,
;;; computed by the build from the repository sources before anything is
;;; compiled from them.
;;;
;;; THE ALGORITHM IS NOT REIMPLEMENTED HERE
;;;
;;; fingerprint.scm is loaded verbatim, so this program and the runner cannot
;;; drift apart. A second implementation agreeing with the first is the kind of
;;; proof that proves nothing -- and when it stopped agreeing, the disagreement
;;; would look exactly like the defect this file exists to detect.
;;;
;;; Consequence, recorded because it is not obvious: this runs under Chez, so a
;;; Chez lane compares Chez's output against a Chez computation and agrees with
;;; itself by construction. With Chez as the only runtime, every lane's
;;; comparison has this shape; see section 6.1 of the slice-5a design for what
;;; that does and does not prove.

;;; Status 2 is the harness's "harness, configuration, or registration error",
;;; the same meaning the Chez source launcher gives it.
(define (die message)
  (display "byte-machine-fingerprint: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define args (command-line-arguments))

(if (< (length args) 3)
    (die "usage: fingerprint-manifest.ss <shared-dir> <output> <body>..."))

(define shared-dir (list-ref args 0))
(define output (list-ref args 1))
(define bodies (list-tail args 2))

;; The adapter protocol's one member this program needs. Defined before the
;; load, because the loaded body calls it.
(define (adapter-file-bytes path)
  (if (not (file-exists? path))
      (die (string-append "manifest body does not exist: " path)))
  (let* ((port (open-file-input-port path))
         (bytes (get-bytevector-all port)))
    (close-port port)
    (if (eof-object? bytes) (make-bytevector 0) bytes)))

(load (string-append shared-dir "/fingerprint.scm"))

(define combined
  (harness-fingerprint->string
   (harness-fingerprint-combine (map harness-fingerprint-file bodies))))

;; No trailing newline. The reader trims whitespace anyway, but writing exactly
;; the value keeps the file's bytes equal to the string it represents.
(let ((port (open-file-output-port output (file-options no-fail))))
  (put-bytevector port (string->utf8 combined))
  (close-port port))

(display "byte-machine-fingerprint: ")
(display combined)
(newline)
(exit 0)
