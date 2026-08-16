;;; Chez wrapper for the bootstrap body. Runtime-specific only in its imports.
;;;
;;; harness-begin is deliberately not called: the bootstrap judges the runner
;;; without using its suite lifecycle.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(include "harness-bootstrap.scm")
