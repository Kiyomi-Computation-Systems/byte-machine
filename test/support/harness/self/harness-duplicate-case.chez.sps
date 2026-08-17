;;; Chez wrapper for the duplicate-case body. Runtime-specific only in imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.duplicate-case")

(include "harness-duplicate-case.scm")

(harness-finish)
