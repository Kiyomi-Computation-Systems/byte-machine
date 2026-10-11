;;; Step 1, at build time: verify the machine and write the generated parser
;;; to generated/words.sls, the library (generated words). Run from this
;;; directory:
;;;
;;;   chez --libdirs ../../src:. --program generate.sps
(import (rnrs)
        (only (chezscheme) mkdir)
        (byte-machine compile)
        (words))

(define compilation (compile-machine words '()))
(unless (compilation-ok? compilation)
  (error 'generate "the machine did not verify"
         (compilation-diagnostics compilation)))

(unless (file-exists? "generated") (mkdir "generated"))
(when (file-exists? "generated/words.sls") (delete-file "generated/words.sls"))
(call-with-port (open-file-output-port "generated/words.sls")
  (lambda (port) (emit-machine compilation 'words-parser port)))
(display "wrote generated/words.sls\n")
