;;; (byte-machine compile): the offline emitter (parent §9.2, §19, §20;
;;; decisions 0008, 0009, 0010). compile-machine re-verifies internally and
;;; normalizes; render-machine renders the normalized IR to a complete importable
;;; R6RS .sls as a canonical UTF-8/LF bytevector (no implementation `write`);
;;; emit-machine writes those bytes to the supplied binary port only. The
;;; generated library imports only (rnrs) and (byte-machine runtime), owns the
;;; derived library name (generated <machine-name>), and defines the single
;;; caller-named compiled-machine binding via the v1 ABI. Pure but for
;;; emit-machine's port write.
(library (byte-machine compile)
  (export compile-machine compilation-ok? compilation-diagnostics
          render-machine emit-machine
          reserved-member-2)          ; test-support: the drift guard (§3.4) reads it
  (import (rnrs)
          (byte-machine verify)
          (only (byte-machine private ir) machine-name)
          (byte-machine private normal-ir))

  (define c-tag (vector 'byte-machine-compilation))
  ;; (vector c-tag ok? diagnostics machine normal) ; normal #f when not ok
  (define (make-compilation ok? diags machine normal) (vector c-tag ok? diags machine normal))
  (define (compilation-ok? c) (vector-ref c 1))
  (define (compilation-diagnostics c) (vector-ref c 2))
  (define (compilation-machine c) (vector-ref c 3))
  (define (compilation-normal c) (vector-ref c 4))

  (define (compile-machine machine options)
    (unless (null? options)
      (assertion-violation 'compile-machine "v0.1 accepts only the empty option list" options))
    (let ((v (verify-machine machine)))
      (if (verification-ok? v)
          (make-compilation #t '() (verification-machine v)
                            (normalize-machine (verification-machine v)))
          (make-compilation #f (verification-diagnostics v) (verification-machine v) #f))))

  ;; --- reserved-output-binding set (all three members now exist, design §3.3) ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  ;; The hand-maintained mirror of (byte-machine runtime)'s exports. Exported
  ;; solely so reserved-drift-tests.sps can assert it against the runtime's actual
  ;; environment-symbols: a new runtime export not added here would let the emitter
  ;; accept a binding that collides with it (Slice B; Slice A design §6).
  (define reserved-member-2
    '(make-compiled-machine compiled-machine?
      byte-machine-make-compiled-machine/v1 byte-machine-make-feed-outcome/v1
      make-parser parser? parser-feed! parser-lifecycle
      parser-result? parser-result-status parser-result-next
      parser-result-consumed parser-result-stream-offset parser-result-error
      callback-continue callback-pause))
  (define reserved-member-3 '(feed loop pos st off b bv start end state offset))
  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-binding? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0) (lower-alpha? (string-ref s 0))
           (let loop ((i 1)) (or (>= i (string-length s))
                                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))
           (not (memq sym reserved-member-1))
           (not (memq sym reserved-member-2))
           (not (memq sym reserved-member-3)))))

  (define (validate-binding binding)
    (unless (symbol? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding))
    (unless (valid-binding? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding)))

  ;; --- canonical source writer ---
  ;; Each transition/fallback lowers to a loop tail: advance bumps pos and off,
  ;; reexecute keeps both. Rendered as one string with explicit, counted parens.
  (define (loop-tail target mode)
    (if (eq? mode 'advance)
        (string-append "(loop (+ pos 1) " (number->string target) " (+ off 1))")
        (string-append "(loop pos " (number->string target) " off)")))

  (define (render-transition-arm tr)
    ;; tr = (byte target mode) -> "((<byte>) <loop-tail>)"
    (string-append "               ((" (number->string (car tr)) ") "
                   (loop-tail (cadr tr) (caddr tr)) ")\n"))

  (define (render-state-arm s)
    (let ((id (number->string (normal-state-id s))))
      (case (normal-state-kind s)
        ((stop)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f " id " off))\n"))
        ((error)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote error) pos (quote "
                        (symbol->string (normal-error-code s)) ") " id " off))\n"))
        ((dispatch)
         (let ((fb (normal-dispatch-fallback s)))
           (string-append
            "      ((" id ")\n"
            "       (if (>= pos end)\n"
            "           (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off)\n"
            "           (let ((b (bytevector-u8-ref bv pos)))\n"
            "             (case b\n"
            (apply string-append (map render-transition-arm (normal-dispatch-transitions s)))
            "               (else " (loop-tail (car fb) (cdr fb)) ")))))\n"))))))

  (define (render-machine compilation binding)
    (unless (compilation-ok? compilation)
      (assertion-violation 'render-machine "cannot render an unverified machine"
                           (compilation-diagnostics compilation)))
    (validate-binding binding)
    (let* ((normal (compilation-normal compilation))
           (mname (symbol->string (machine-name (compilation-machine compilation))))
           (states (normal-machine-states normal))
           (entry (normal-machine-entry normal))
           (fp (normal-machine-fingerprint normal))
           (bstr (symbol->string binding)))
      (string->utf8
       (string-append
        "(library (generated " mname ")\n"
        "  (export " bstr ")\n"
        "  (import (rnrs) (byte-machine runtime))\n"
        "  (define (feed state offset bv start end)\n"
        "    (let loop ((pos start) (st state) (off offset))\n"
        "      (case st\n"
        (let loop ((i 0) (acc ""))
          (if (>= i (vector-length states)) acc
              (loop (+ i 1) (string-append acc (render-state-arm (vector-ref states i))))))
        "      (else (assertion-violation (quote feed) \"unknown state\" st)))))\n"
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine/v1 1 " (number->string fp) " "
        (number->string entry) " feed)))\n"))))

  (define (emit-machine compilation binding port)
    (let ((bytes (render-machine compilation binding)))
      (put-bytevector port bytes)
      (vector 'emission-metadata
              (normal-machine-fingerprint (compilation-normal compilation))
              (bytevector-length bytes)))))
