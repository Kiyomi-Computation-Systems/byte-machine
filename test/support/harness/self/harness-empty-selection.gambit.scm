;;; Gambit wrapper for the empty-selection body. Runtime-specific only in imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.empty-selection")

(include "harness-empty-selection.scm")

(harness-finish)
