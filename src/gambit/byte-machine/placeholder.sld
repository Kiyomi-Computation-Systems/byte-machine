;;; Gambit owner library for the placeholder body.
;;;
;;; A library form, imports, exports, and the include. Nothing else, for the
;;; reason given in the Chez counterpart.
;;;
;;; The body is included by a path relative to this file, which is how Gambit
;;; resolves include inside define-library. Chez resolves the same body by bare
;;; filename through its launcher's source-directories. That difference is the
;;; one place the two mechanisms are visibly not the same, and it is why a
;;; staged copy for mutation testing must preserve this relative layout rather
;;; than flatten it.

(define-library (byte-machine placeholder)
  (export make-placeholder placeholder? placeholder-value placeholder-marker)
  (import (scheme base))
  (include "../../common/byte-machine/placeholder.scm"))
