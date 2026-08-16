;;; Chez wrapper for the empty-selection body. Runtime-specific only in imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.empty-selection")

(include "harness-empty-selection.scm")

(harness-finish)
