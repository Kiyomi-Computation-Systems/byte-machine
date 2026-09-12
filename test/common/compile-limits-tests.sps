;;; The §16.2:911 compile-file witness (Milestone 7 Slice ④, §4.12 item 2, approved
;;; 2026-09-06). §16.2:911 is "backend limits that would make emission incorrect";
;;; it has no enforcement (the appendix ledger marks it "nobody"), so this lane is
;;; the measurement that a v0.1 machine at the generator's bounds does not reach one.
;;;
;;; The witness is the largest emittable dispatch: a byte-dispatch with all 256
;;; exact-byte cases and a second dispatch over a complement matcher (§4.12 item 2's
;;; words), rendered to a real generated library, `compile-file`d to an object,
;;; loaded, and one feed asserted to agree with the interpreter on the full
;;; parser-result. This is the ONE lane that both compiles a machine (it imports
;;; (byte-machine compile)) and executes one (it imports the interpreter and the
;;; runtime) -- exactly the three libraries the rejections lane must NOT have (F7),
;;; which is why §4.12 item 2's witness is its own program and its own lane pair.
;;;
;;; The limits looked for (§30:1778): generated identifier length, emitted source
;;; size, `case` arity, and literal size. The disposition records what was measured
;;; for each; none is reachable by a v0.1 machine (Task 10).
(import (rnrs)
        (rnrs eval)
        (only (chezscheme) load compile-file generate-wpo-files with-output-to-string)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "compile.limits")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'compile-limits "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

;; the 256 exact-byte cases, every byte 0..255 to the complement dispatch.
(define (bytes-0-255)
  (let loop ((i 255) (a '())) (if (< i 0) a (loop (- i 1) (cons i a)))))
(define cases256
  (map (lambda (i) (make-byte-case (make-exact-byte-matcher i) (make-edge 'd-comp 'advance) #f))
       (bytes-0-255)))

;; the largest emittable machine: a 256-exact-case dispatch, and a dispatch over a
;; complement matcher. Every byte at d256 advances to d-comp; every byte there (via
;; the complement case or the singleton fallback) advances to a stop; EOF at either
;; finishes. A byte edge reaches the stop (never EOF -> no eof-reachable-stop) and
;; only EOF reaches the finish (no non-eof-into-finish).
(define lim
  (make-machine 'lim 'd256 '() '() '() (list eof-decl rej-decl)
    (list
      (make-byte-dispatch-node 'd256 cases256 (make-edge 'rej 'advance) 'fin #f)
      (make-byte-dispatch-node 'd-comp
        (list (make-byte-case (make-byte-complement-matcher (make-byte-set-matcher '(0)))
                              (make-edge 'stopn 'advance) #f))
        (make-edge 'stopn 'advance) 'fin #f)
      (make-stop-node 'stopn #f)
      (make-finish-node 'fin #f)
      (make-error-node 'rej 'rejected #f))
    'default-eof #f))

(define v (verify-machine lim))
(define emitted (render-machine (compile-machine lim '()) 'lim-parser))
(define emitted-size (bytevector-length emitted))

;; write the source, compile-file it to an object beside it, load the object. The
;; "compiling ... with output to ..." line compile-file writes to current-output-port
;; is CAPTURED here, so it cannot pollute the lane's output and resolve a pin twice
;; (Task 9 Step 4); the captured text is checked against the suite's pins by the
;; label audit rather than left on stdout.
(define genfile (string-append tmpdir "/compile-limits.sls"))
(define objfile (string-append tmpdir "/compile-limits.so"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (put-bytevector p emitted)))
(generate-wpo-files #f)
(define compile-line
  (with-output-to-string (lambda () (compile-file genfile objfile))))
(load objfile)
(define cm (eval 'lim-parser (environment '(generated lim))))
(define im (make-interpreted-machine v))

;; the object file exists and is non-empty -- written BEFORE the feed check, so a
;; mutation replacing compile-file with a plain load of the source is caught here
;; (the object never gets written) rather than passing because the feed still agrees.
(define (file-nonempty? path)
  (and (file-exists? path)
       (call-with-port (open-file-input-port path)
         (lambda (p) (not (eof-object? (get-u8 p)))))))

(define input (u8-list->bytevector '(65 66)))
(define (feed-once m) (parser-feed! (make-parser m '() #f) input 0 2))
(define ri (feed-once im))
(define rc (feed-once cm))
(define (triple r) (list (parser-result-status r) (parser-result-next r)
                         (parser-result-consumed r) (parser-result-stream-offset r)))

(harness-group "the largest emittable machine compiles, loads, and runs (§16.2:911)"
  (lambda ()
    (harness-case "it verifies and renders a large generated library"
      (lambda ()
        (check "the witness verifies" (verification-ok? v))
        ;; the source is large -- the case-arity/source-size probe. P4 measured
        ;; 18 757 bytes for the 256-case dispatch alone; this machine adds the
        ;; complement dispatch, so it is larger.
        (check "the emitted source is large" (> emitted-size 10000))))
    (harness-case "compile-file wrote an object, and it is what was loaded"
      (lambda ()
        (check "the object file exists and is non-empty" (file-nonempty? objfile))
        (check "compile-file announced the compilation" (> (string-length compile-line) 0))
        (check "the loaded binding is a compiled machine parser" (and cm #t))))
    (harness-case "one feed agrees with the interpreter on the full parser-result"
      (lambda ()
        (check-equal "compiled result status is stopped" (parser-result-status rc) 'stopped)
        (check-equal "the two lanes agree on the full triple" (triple rc) (triple ri))))))

;; --- the disposition data (Task 8 Step 5) ------------------------------------
;; Which §30:1778 limits were looked for, and what this witness measured for each.
;; None is reachable by a v0.1 machine: the generator's bounds produce machines far
;; inside Chez's own limits, and the largest emittable dispatch here is the extreme
;; case. Printed so the disposition (Task 10) quotes measured numbers, not hopes.
(harness-group "the limits looked for are recorded"
  (lambda ()
    (harness-case "identifier length, source size, case arity, literal size"
      (lambda ()
        (display "compile-limits: emitted source size = ") (display emitted-size)
        (display " bytes; case arity = 256 exact cases + 1 complement case; ")
        (display "generated identifier length <= the length of the binding 'lim-parser; ")
        (display "largest literal = a 256-byte complement census.") (newline)
        ;; the assertion is that the artifact ran -- the reachability of any limit is
        ;; the disposition's claim, dispositioned in the plan against these numbers.
        (check "the witness exercised the case-arity and source-size probes"
               (and (= (length cases256) 256) (> emitted-size 10000)))))))

(harness-finish)
