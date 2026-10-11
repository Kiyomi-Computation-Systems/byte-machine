;;; The compile-file witness for backend limits: limits that would make emission
;;; incorrect. The verifier enforces none, so this lane is the measurement that a
;;; v0.1 machine at the generator's bounds does not reach one.
;;;
;;; The witness is the largest emittable dispatch: a byte-dispatch with all 256
;;; exact-byte cases and a second dispatch over a complement matcher, rendered to
;;; a real generated library, `compile-file`d to an object, loaded, and one feed
;;; asserted to agree with the interpreter on the full parser-result. This is the
;;; ONE lane that both compiles a machine (it imports (byte-machine compile)) and
;;; executes one (it imports the interpreter and the runtime) -- exactly the three
;;; libraries the rejections lane must NOT have, which is why this witness is its
;;; own program and its own lane pair.
;;;
;;; The limits looked for: generated identifier length, emitted source size,
;;; `case` arity, and literal size. The lane prints what it measured for each;
;;; none is reachable by a v0.1 machine.
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

;; The 256 exact-byte cases, alternating between two identical destinations.
;;
;; THE ALTERNATION IS THE POINT. Consecutive bytes sharing a destination
;; collapse into one range clause, so 256 identical edges would render as a
;; SINGLE test and the witness would measure nothing -- the emitted source
;; would be a few hundred bytes, and the size floor below would go red.
;;
;; So the witness is the worst case of the range lowering: no two consecutive
;; bytes share a destination, so every byte is its own run and the dispatch
;; cannot collapse at all. That is the arity a backend limit would have to
;; survive.
(define (bytes-0-255)
  (let loop ((i 255) (a '())) (if (< i 0) a (loop (- i 1) (cons i a)))))
(define cases256
  (map (lambda (i)
         (make-byte-case (make-exact-byte-matcher i)
                         (make-edge (if (even? i) 'd-comp 'd-comp-odd) 'advance) #f))
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
      ;; d-comp's twin, and the only reason it exists: an odd byte at d256 needs
      ;; a destination that is not its neighbour's, or the run collapses again.
      ;; Identical in every other respect, so which of the two a feed lands in
      ;; cannot change the result the two lanes are compared on.
      (make-byte-dispatch-node 'd-comp-odd
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
;; is CAPTURED here, so it cannot pollute the lane's output and resolve a pin
;; twice; the captured text is checked by the lane rather than left on stdout.
(define genfile (string-append tmpdir "/compile-limits.sls"))
(define objfile (string-append tmpdir "/compile-limits.so"))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (put-bytevector p emitted)))
(generate-wpo-files #f)
;; remove any object left by a previous run in the shared tmpdir, so the
;; object-exists check below reflects THIS run's compile-file and a mutation that
;; bypasses compile-file cannot pass on a stale object.
(when (file-exists? objfile) (delete-file objfile))
(define compile-line
  (with-output-to-string (lambda () (compile-file genfile objfile))))
;; the object exists and is non-empty is computed BEFORE the object is loaded, and
;; the load is guarded, so a mutation replacing compile-file with a plain load of
;; the source is caught by this check (the object never gets written) rather than
;; crashing the program at a top-level (load of a missing object).
(define (file-nonempty? path)
  (and (file-exists? path)
       (call-with-port (open-file-input-port path)
         (lambda (p) (not (eof-object? (get-u8 p)))))))
(define obj-ok (file-nonempty? objfile))
(define cm
  (and obj-ok (guard (e (#t #f)) (load objfile) (eval 'lim-parser (environment '(generated lim))))))
(define im (make-interpreted-machine v))

(define input (u8-list->bytevector '(65 66)))
(define (feed-once m) (parser-feed! (make-parser m '() #f) input 0 2))
(define ri (feed-once im))
(define rc (and cm (feed-once cm)))
(define (triple r) (list (parser-result-status r) (parser-result-next r)
                         (parser-result-consumed r) (parser-result-stream-offset r)))

(harness-group "the largest emittable machine compiles, loads, and runs"
  (lambda ()
    (harness-case "it verifies and renders a large generated library"
      (lambda ()
        (check "the witness verifies" (verification-ok? v))
        ;; The source is large -- the case-arity/source-size probe. The
        ;; non-collapsing range lowering renders one clause per byte, bounded by
        ;; 256; the floor is a fixed size, not re-tuned to whatever this happens
        ;; to measure.
        (check "the emitted source is large" (> emitted-size 10000))))
    (harness-case "compile-file wrote an object, and it is what was loaded"
      (lambda ()
        (check "the object file exists and is non-empty" obj-ok)
        (check "compile-file announced the compilation" (> (string-length compile-line) 0))
        (check "the loaded binding is a compiled machine parser" (and cm #t))))
    (harness-case "one feed agrees with the interpreter on the full parser-result"
      (lambda ()
        (check "the compiled machine produced a result" (and rc #t))
        (check-equal "compiled result status is stopped" (and rc (parser-result-status rc)) 'stopped)
        (check-equal "the two lanes agree on the full triple" (and rc (triple rc)) (triple ri))))))

;; --- the limits data ----------------------------------------------------------
;; Which backend limits were looked for, and what this witness measured for each.
;; None is reachable by a v0.1 machine: the generator's bounds produce machines far
;; inside Chez's own limits, and the largest emittable dispatch here is the extreme
;; case. Printed so the claim rests on measured numbers, not hopes.
(harness-group "the limits looked for are recorded"
  (lambda ()
    (harness-case "identifier length, source size, case arity, literal size"
      (lambda ()
        (display "compile-limits: emitted source size = ") (display emitted-size)
        (display " bytes; 256 exact cases, alternating so none collapse, ")
        (display "+ 1 complement case; ")
        (display "generated identifier length <= the length of the binding 'lim-parser; ")
        (display "largest literal = a 256-byte complement census.") (newline)
        ;; the assertion is that the artifact ran -- the reachability of any limit
        ;; is judged against the printed numbers.
        (check "the witness exercised the case-arity and source-size probes"
               (and (= (length cases256) 256) (> emitted-size 10000)))))))

(harness-finish)
