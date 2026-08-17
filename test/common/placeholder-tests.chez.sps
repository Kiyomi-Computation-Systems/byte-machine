;;; Chez wrapper for the placeholder tests. Runtime-specific only in its imports.

(import (rnrs)
        (byte-machine test harness)
        (byte-machine placeholder)
        (only (chezscheme) include))

(harness-begin "portability.placeholder")

(include "placeholder-tests.scm")

(harness-finish)
