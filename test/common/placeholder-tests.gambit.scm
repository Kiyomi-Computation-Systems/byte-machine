;;; Gambit wrapper for the placeholder tests. Runtime-specific only in its imports.

(import (scheme base)
        (scheme write)
        (byte-machine test harness)
        (byte-machine placeholder))

(harness-begin "portability.placeholder")

(include "placeholder-tests.scm")

(harness-finish)
