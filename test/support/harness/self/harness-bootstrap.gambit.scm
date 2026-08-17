;;; Gambit wrapper for the bootstrap body. Runtime-specific only in its imports.
;;;
;;; harness-begin is deliberately not called: the bootstrap judges the runner
;;; without using its suite lifecycle.

(import (scheme base) (scheme write) (byte-machine test harness))

(include "harness-bootstrap.scm")
