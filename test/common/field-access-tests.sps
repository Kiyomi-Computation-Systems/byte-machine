;;; parser-field-ref across both executors (§9.3:410, §13:801; Milestone 4 Slice
;;; ①b tasks 6 and 7). The generated library is emitted at run time, loaded, and
;;; its compiled machine obtained by environment/eval, exactly as the
;;; differential lanes do — because the two executors reach the field
;;; declarations by DIFFERENT routes and only running both proves they agree.
;;; The interpreter asks its op closure a 'field-initials message; the generated
;;; lane reads member 0 of the ABI payload it was emitted with. Nothing is shared
;;; between those two paths, so an interpreter-only lane would leave the emitted
;;; half untested and a generated-only lane the reverse.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "unit.field-access")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'field-access "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/generated-field-access.sls"))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

;; Non-zero initials on purpose, and DIFFERENT from each other: an initials
;; vector that is all zeros passes whether the initials were carried or the
;; storage was merely allocated, and two equal initials pass whether the slots
;; are ordered or swapped.
(define decls   ; NOT `fields`: (rnrs) binds it as define-record-type's
                ; auxiliary keyword, and a top-level define of it is a
                ; "multiple definitions" error at expand time.
  (list (make-uint-field 'count 8 7 #f)
        (make-uint-field 'limit 16 65535 #f)
        (make-uint-field 'seen 32 0 #f)))

(define m
  (make-machine 'field-access 'start decls '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define cm-ref (make-interpreted-machine (verify-machine m)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine m '()) 'field-access-parser p)))
(load genfile)
(define cm-gen (eval 'field-access-parser (environment '(generated field-access))))

(define (caught thunk)
  (call/cc (lambda (k)
             (with-exception-handler
              (lambda (e) (k (and (byte-machine-contract-condition? e)
                                  (byte-machine-contract-condition-code e))))
              (lambda () (thunk) 'no-raise)))))

(define (per-executor name cm)
  (harness-group (string-append "parser-field-ref (" name ")")
    (lambda ()
      (harness-case "a fresh parser reads the declared initials"
        (lambda ()
          (let ((p (make-parser cm '() #f)))
            (check-equal "count" (parser-field-ref p 'count) 7)
            (check-equal "limit" (parser-field-ref p 'limit) 65535)
            (check-equal "seen" (parser-field-ref p 'seen) 0))))
      (harness-case "an undeclared field name is accessor-misuse"
        (lambda ()
          ;; A caller mistake, not a machine outcome (§13:801): it must not
          ;; arrive as a parser-error, which is the record describing what the
          ;; INPUT did.
          (check-equal "code" (caught (lambda () (parser-field-ref (make-parser cm '() #f)
                                                                   'nosuch)))
                       'accessor-misuse)))
      (harness-case "a non-parser is invalid-argument"
        (lambda ()
          (check-equal "code" (caught (lambda () (parser-field-ref 'not-a-parser 'count)))
                       'invalid-argument)))
      ;; *** Per-parser ISOLATION of the value storage has no witness in this
      ;; slice, and no test is written for it. *** The reason the values are a
      ;; parser slot rather than closure state is that the op/exec closure is
      ;; built once per compiled machine and every parser copies the same
      ;; reference into slot 2 -- but parser-field-ref is read-only (§13:801) and
      ;; nothing in ①b ever writes a field, so two parsers sharing one vector and
      ;; two parsers holding their own are observationally identical through the
      ;; whole public API. A case here could only assert vector identity through
      ;; a probe the library does not export, or assert equality of two values
      ;; that are equal either way. Slice ② adds the writer, and the isolation
      ;; case belongs in the same commit as that writer, where it can fail.
      (harness-case "two parsers from one compiled machine each read the initials"
        (lambda ()
          (let ((a (make-parser cm '() #f)) (b (make-parser cm '() #f)))
            (check-equal "a" (parser-field-ref a 'count) 7)
            (check-equal "b" (parser-field-ref b 'count) 7))))
      (harness-case "parser-reset! restores the declared initials, not zero"
        (lambda ()
          ;; §12.5:738 returns the parser to its just-constructed state, and a
          ;; just-constructed parser holds the DECLARED initials. Zeroing would
          ;; make `u8 count = 7` mean 7 before the first reset and 0 after it.
          (let ((p (make-parser cm '() #f)))
            (parser-feed! p (make-bytevector 1 0) 0 1)
            (parser-reset! p)
            (check-equal "count" (parser-field-ref p 'count) 7)
            (check-equal "limit" (parser-field-ref p 'limit) 65535)
            (check-equal "lifecycle" (parser-lifecycle p) 'ready))))
      (harness-case "a zero-field machine answers every name with accessor-misuse"
        (lambda ()
          (check-equal "code" (caught (lambda () (parser-field-ref (make-parser cm-zero '() #f)
                                                                   'count)))
                       'accessor-misuse))))))

;; The zero-field control. Its parser must still be constructible and still
;; refuse every name -- the empty table is a table, not a missing one.
(define zero
  (make-machine 'field-access 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define cm-zero (make-interpreted-machine (verify-machine zero)))

(per-executor "interpreter" cm-ref)
(per-executor "generated" cm-gen)

;; The two executors are asked the same questions above, but nothing yet asserts
;; they AGREE -- each group could pass against a different wrong answer.
(harness-group "interpreter and generated agree on the field table"
  (lambda ()
    (harness-case "every declared name reads the same through both"
      (lambda ()
        (let ((a (make-parser cm-ref '() #f)) (b (make-parser cm-gen '() #f)))
          (for-each (lambda (n)
                      (check-equal (symbol->string n)
                                   (parser-field-ref a n) (parser-field-ref b n)))
                    '(count limit seen)))))))

(harness-finish)
