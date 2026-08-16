;;; Chez wrapper for the runner's self-tests. Runtime-specific only in imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.self")

(include "harness-self-tests.scm")

(harness-finish)
