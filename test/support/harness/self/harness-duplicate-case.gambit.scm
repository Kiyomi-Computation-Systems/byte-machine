;;; Gambit wrapper for the duplicate-case body. Runtime-specific only in imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.duplicate-case")

(include "harness-duplicate-case.scm")

(harness-finish)
