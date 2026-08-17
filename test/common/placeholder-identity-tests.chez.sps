;;; Chez wrapper for the cross-library identity tests. Runtime-specific only in
;;; its imports. Both libraries are imported here, never included: importing the
;;; owner is the claim under test.

(import (rnrs)
        (byte-machine test harness)
        (byte-machine placeholder)
        (byte-machine placeholder-consumer)
        (only (chezscheme) include))

(harness-begin "portability.placeholder-identity")

(include "placeholder-identity-tests.scm")

(harness-finish)
