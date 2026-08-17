;;; Chez wrapper for the failing body. Runtime-specific only in its imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.failing")

(include "harness-failing.scm")

(harness-finish)
