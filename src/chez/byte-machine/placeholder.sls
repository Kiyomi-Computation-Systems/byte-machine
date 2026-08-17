;;; Chez owner library for the placeholder body.
;;;
;;; A library form, imports, exports, and the include. Nothing else: any
;;; semantics here would be semantics the shared body no longer owns, and the
;;; body mutations in SchemeMutationSuite.cmake exist to catch exactly that.
;;;
;;; The body is included by bare filename and resolved through Chez's
;;; source-directories, which the launcher sets. That keeps absolute paths out
;;; of the source tree and keeps the include independent of the working
;;; directory.

(library (byte-machine placeholder)
  (export make-placeholder placeholder? placeholder-value placeholder-marker)
  (import (rnrs) (only (chezscheme) include))
  (include "placeholder.scm"))
