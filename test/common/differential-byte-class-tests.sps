;;; interpreter ≡ generated over all 256 byte values, for every class matcher
;;; kind (parent §18, §22.4, §22.7:1301). Each machine's library is emitted at
;;; run time, loaded, and its compiled-machine obtained by environment/eval; both
;;; executors run through the shared make-parser/parser-feed! API and every
;;; parser-result field is compared.
;;;
;;; The complement fixture is the one that proves the emitter needed no change:
;;; it renders 254 sibling arms inside the single `(case b ...)`, which is
;;; §19.2:1009's "canonical membership code selected for simplicity".
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test class-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.byte-class")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; Emit, load and eval one fixture's generated library. The binding,
;; <machine-name>-parser, is derived from this function's own `name` argument.
;; The library name, (generated <machine-name>), is NOT: emit-machine draws it
;; from the compiled machine's own `machine-name` field, set inside
;; class-machine.sls at construction time. The two agree today only because
;; every class-machines entry reuses the identical symbol for both its list
;; label and the name passed to class-machine -- an invariant held by
;; convention, asserted nowhere, and enforced only by `load` failing loudly
;; with a library-not-found error if a future fixture's label and
;; machine-name ever diverge.
(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (rfields cm b)
  (let ((r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1)))
    (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
          (parser-result-stream-offset r) (parser-result-error r))))

;; The group below drives its per-fixture cases (and every generated-machine
;; emission) from a for-each over (class-machines): if a future edit dropped a
;; fixture, the for-each body would simply run fewer times, registering fewer
;; harness-cases -- an empty list would register none at all -- and the group
;; would still report a clean 0 failures. Pin the count once, up front, the
;; same way byte-class-interpret-tests.sps pins it for its own for-each.
(harness-group "the shared class fixture list is complete"
  (lambda ()
    (harness-case "class-machines yields all five fixtures"
      (lambda ()
        (check-equal "fixture count" (length (class-machines)) 5)))))

(harness-group "interpreter and generated agree on every byte, for every class"
  (lambda ()
    (for-each
     (lambda (entry)
       (let* ((name (car entry))
              (machine (cadr entry))
              (accepted (caddr entry))
              (cm-ref (make-interpreted-machine (verify-machine machine)))
              (cm-gen (generated-machine name machine)))
         (harness-case (string-append (symbol->string name) " agrees on all 256 bytes")
           (lambda ()
             (let ((bad 'none) (last-byte 'unset))
               (let loop ((b 0))
                 (when (< b 256)
                   (unless (equal? (rfields cm-ref b) (rfields cm-gen b))
                     (when (eq? bad 'none) (set! bad b)))
                   (set! last-byte b)
                   (loop (+ b 1))))
               (check-equal "no byte disagreed" bad 'none)
               (check-equal "loop ran all 256 bytes" last-byte 255))))
         ;; Agreement alone cannot see a defect both executors share, so the
         ;; generated side is also checked against the class ABSOLUTELY, here
         ;; at the class's own lowest byte, for all five fixtures. A byte just
         ;; outside the class is checked absolutely too, but only for two of
         ;; the five (ascii-set and byte-complement) -- see the next
         ;; harness-group, "a byte outside the class errors in both, at
         ;; offset 0".
         (harness-case (string-append (symbol->string name) " generated stops on a class byte")
           (lambda ()
             (check-equal "stopped" (car (rfields cm-gen (car accepted))) 'stopped)
             (check-equal "consumed" (caddr (rfields cm-gen (car accepted))) 1)))))
     (class-machines))))

(harness-group "a byte outside the class errors in both, at offset 0"
  (lambda ()
    (harness-case "the ASCII machine rejects byte 0 in both executors"
      (lambda ()
        (let* ((m (make-ascii-machine))
               (cm-ref (make-interpreted-machine (verify-machine m)))
               (cm-gen (generated-machine 'ascii-set m)))
          (check-equal "match" (rfields cm-gen 0) (rfields cm-ref 0))
          (check-equal "generated errors" (car (rfields cm-gen 0)) 'error)
          (check-equal "at offset 0" (list-ref (rfields cm-gen 0) 3) 0))))
    (harness-case "the complement machine rejects byte 10 in both executors"
      (lambda ()
        (let* ((m (make-byte-complement-machine))
               (cm-ref (make-interpreted-machine (verify-machine m)))
               (cm-gen (generated-machine 'byte-complement m)))
          (check-equal "match" (rfields cm-gen 10) (rfields cm-ref 10))
          (check-equal "generated errors" (car (rfields cm-gen 10)) 'error))))))

(harness-finish)
