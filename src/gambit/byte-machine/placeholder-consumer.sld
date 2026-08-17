;;; Gambit owner library for the consumer body.
;;;
;;; A library form, imports, exports, and the include. Nothing else, for the
;;; reason given in the Chez counterpart.
;;;
;;; The body is included by a path relative to this file, which is how Gambit
;;; resolves include inside define-library; Chez resolves the same body by bare
;;; filename through its launcher's source-directories. As with the owner pair,
;;; that difference is why a staged copy for mutation testing must preserve this
;;; relative layout rather than flatten it.
;;;
;;; The second import is the subject of slice 4; pass 27 in
;;; SchemeMutationSuite.cmake replaces it with an include and requires the
;;; identity lane to fail.

(define-library (byte-machine placeholder-consumer)
  (export consume)
  (import (scheme base) (byte-machine placeholder))
  (include "../../common/byte-machine/placeholder-consumer.scm"))
