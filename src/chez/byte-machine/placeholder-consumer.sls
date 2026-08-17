;;; Chez owner library for the consumer body.
;;;
;;; A library form, imports, exports, and the include. Nothing else: any
;;; semantics here would be semantics the shared body no longer owns.
;;;
;;; The second import is the whole subject of slice 4. (byte-machine placeholder)
;;; is imported, never included -- including it would make this library a second
;;; owner of that body, giving it its own tag and its own marker. Pass 26 in
;;; SchemeMutationSuite.cmake makes exactly that edit and requires the identity
;;; lane to fail.

(library (byte-machine placeholder-consumer)
  (export consume)
  (import (rnrs) (byte-machine placeholder) (only (chezscheme) include))
  (include "placeholder-consumer.scm"))
