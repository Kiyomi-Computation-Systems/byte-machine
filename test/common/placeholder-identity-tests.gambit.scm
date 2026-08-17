;;; Gambit wrapper for the cross-library identity tests. Runtime-specific only
;;; in its imports. Both libraries are imported here, never included: importing
;;; the owner is the claim under test.

(import (scheme base)
        (scheme write)
        (byte-machine test harness)
        (byte-machine placeholder)
        (byte-machine placeholder-consumer))

(harness-begin "portability.placeholder-identity")

(include "placeholder-identity-tests.scm")

(harness-finish)
