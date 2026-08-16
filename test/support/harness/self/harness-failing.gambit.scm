;;; Gambit wrapper for the failing body. Runtime-specific only in its imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.failing")

(include "harness-failing.scm")

(harness-finish)
