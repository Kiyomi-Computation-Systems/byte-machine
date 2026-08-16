;;; Gambit wrapper for the runner's self-tests. Runtime-specific only in imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.self")

(include "harness-self-tests.scm")

(harness-finish)
