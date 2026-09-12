;;; byte-machine example: generate, compile, and run a simple parser.
;;;
;;; Milestone 9 Slice ④ (§26:1682, §27:1703, parent §9.6). A standalone program
;;; that demonstrates the whole v0.1 flow end to end, using ONLY the public
;;; procedural API — never the private tagged-vector constructors:
;;;
;;;   1. construct a machine through (byte-machine graph);
;;;   2. compile it offline with (byte-machine compile) — verification is
;;;      mandatory and cannot be bypassed;
;;;   3. emit the generated Scheme library to a file;
;;;   4. load that library, which depends only on (byte-machine runtime);
;;;   5. build a parser and feed it bytes, inspecting the result.
;;;
;;; The machine accepts exactly one byte, the ASCII 'A' (0x41), then stops; any
;;; other first byte is rejected with `unexpected-byte`, and end of input before
;;; the byte is `unexpected-eof`.
;;;
;;; Run from the repository root (a clean checkout needs nothing built first):
;;;
;;;   chez --libdirs src --program examples/generate-simple-machine/generate.sps
;;;
;;; It writes the generated library to `example-simple.generated.sls` in the
;;; current directory (git-ignored) and prints each step. See the README.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load getenv)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine runtime))

;; --- 1. construct, through the public (byte-machine graph) API only ----------
(define simple-machine
  (let ((eof-decl (make-error-declaration 'eof 'unexpected-eof "unexpected end of input" #f))
        (rej-decl (make-error-declaration 'rejected 'unexpected-byte "expected the byte 0x41" #f)))
    (make-machine 'simple 'start '() '() '() (list eof-decl rej-decl)
      (list (make-byte-dispatch-node 'start
              ;; one case: the exact byte 0x41 ('A') advances to the stop node.
              (list (make-byte-case (make-exact-byte-matcher #x41)
                                    (make-edge 'accept 'advance) #f))
              ;; the fallback re-executes the offending byte into the error node,
              ;; so the reported offset is the first unexpected byte.
              (make-edge 'reject 'reexecute)
              ;; EOF while waiting for the first byte is unexpected-eof.
              'eof-stop #f)
            (make-stop-node 'accept #f)
            (make-error-node 'reject 'rejected #f)
            (make-error-node 'eof-stop 'eof #f))
      'eof #f)))

;; --- 2. compile (verification is mandatory and unbypassable) -----------------
(define compiled (compile-machine simple-machine '()))
(unless (compilation-ok? compiled)
  (error 'example "the machine did not verify" compiled))
(display "1. constructed and verified: simple\n")

;; --- 3. emit the generated library to a file ---------------------------------
(define out
  (let ((e (getenv "BYTE_MACHINE_EXAMPLE_OUT")))
    (if (and e (not (string=? e ""))) e "example-simple.generated.sls")))
(when (file-exists? out) (delete-file out))
(call-with-port (open-file-output-port out (file-options no-fail))
  (lambda (p) (emit-machine compiled 'simple-parser p)))
(display (string-append "2. emitted generated library to " out "\n"))

;; --- 4. load the generated library (it imports only (byte-machine runtime)) --
(load out)
(define parser-machine (eval 'simple-parser (environment '(generated simple))))
(display "3. loaded the generated parser (depends only on (byte-machine runtime))\n")

;; --- 5. build a parser and feed it bytes -------------------------------------
(define (bytes . bs) (u8-list->bytevector bs))
(define (run input)
  (let* ((p (make-parser parser-machine '() #f))
         (r (parser-feed! p input 0 (bytevector-length input))))
    (list (parser-result-status r) (parser-result-consumed r))))

(display "4. results:\n")
(display (string-append "   feed 'A' (0x41)  -> " (let ((r (run (bytes #x41))))
           (string-append (symbol->string (car r)) ", consumed "
                          (number->string (cadr r)))) "\n"))
(let* ((p (make-parser parser-machine '() #f))
       (r (parser-feed! p (bytes #x42) 0 1))
       (e (parser-result-error r)))
  (display (string-append "   feed 'B' (0x42)  -> "
             (symbol->string (parser-result-status r))
             (if (parser-error? e)
                 (string-append ", code " (symbol->string (parser-error-code e))
                                " at offset " (number->string (parser-error-offset e)))
                 "") "\n")))
(display "done.\n")
(exit 0)
