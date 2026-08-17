;;; Report the identity of this Gambit runtime for build-time validation.
;;;
;;; Printed as key=value lines so CMake can parse without a shell. The leading
;;; `gambit=yes` is the only thing that distinguishes a real answer from another
;;; program that happens to answer to a similar name: Ghostscript's `gsc`, given
;;; this file, prints its own banner and exits 0, so an exit status proves
;;; nothing here.
;;;
;;; Run through the interpreter as `gsi -f gambit-probe.scm` and through the
;;; compiler as `gsc -f -i gambit-probe.scm`. `-f` skips .gambini initialisation
;;; files, so a developer's personal setup cannot change the answer.

(display "gambit=yes") (newline)
(display "version=") (display (system-version-string)) (newline)
(display "target=") (display (system-type-string)) (newline)
(display "stamp=") (display (system-stamp)) (newline)
