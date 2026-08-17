;;; Chez wrapper for the unreached-provenance body. Runtime-specific only in
;;; its imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(include "harness-unreached-provenance.scm")
