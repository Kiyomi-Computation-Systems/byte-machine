;;; (byte-machine compile): the offline emitter (parent §9.2, §19, §20;
;;; decisions 0008, 0009, 0010). compile-machine re-verifies internally and
;;; normalizes; render-machine renders the normalized IR to a complete importable
;;; R6RS .sls as a canonical UTF-8/LF bytevector (no implementation `write`);
;;; emit-machine writes those bytes to the supplied binary port only. The
;;; generated library imports only (rnrs) and (byte-machine runtime), owns the
;;; derived library name (generated <machine-name>), and defines the single
;;; caller-named compiled-machine binding through the one unversioned
;;; byte-machine-make-compiled-machine (decision 0018), whose first action is the
;;; ABI version check and whose trailing quoted vector is the growable payload.
;;; Pure but for emit-machine's port write.
(library (byte-machine compile)
  (export compile-machine compilation-ok? compilation-diagnostics
          render-machine emit-machine
          reserved-member-2 reserved-member-3) ; test-support: the drift guards read them
  (import (rnrs)
          (byte-machine verify)
          (only (byte-machine private ir) machine-name machine-errors
                error-declaration-code error-declaration-reason)
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
      byte-machine-make-compiled-machine/v1 byte-machine-make-compiled-machine/v2
      byte-machine-make-feed-outcome/v1
      make-parser parser? parser-feed! parser-finish! parser-resume!
      parser-lifecycle parser-reset!
      parser-result? parser-result-status parser-result-next
      parser-result-consumed parser-result-stream-offset parser-result-error
      byte-machine-make-parser-error/v1 parser-error?
      parser-error-domain parser-error-code parser-error-reason
      parser-error-detail parser-error-node-name parser-error-state-id
      parser-error-offset parser-error-position-kind
      byte-machine-make-compiled-machine
      parser-field-ref
      callback-continue callback-pause))
  ;; Every identifier the emitted body binds, so a caller-chosen output binding
  ;; cannot collide with one. `fieldv` is emitted `exec`'s seventh parameter,
  ;; reserved empty here and filled in Slice ② (decision 0019 item 3(c)); it is
  ;; deliberately not spelled `fields`, which `(rnrs)` binds as
  ;; define-record-type's auxiliary keyword and which the drift guard's own
  ;; `(rnrs)` subtraction would therefore swallow.
  (define reserved-member-3
    '(exec loop pos st off b bv start end state offset finish? fieldv errs pk))
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
  ;; §20:1039's explicit escaping, for the one class of author-controlled text the
  ;; emitter writes into generated source: an error declaration's static reason,
  ;; carried by decision 0022 item 7's per-library `errs` table. `pass-names-valid`
  ;; refuses any reason outside printable ASCII plus LF (§10.1:480), so exactly
  ;; three characters can reach here needing an escape and the set is closed
  ;; rather than defensive. Its one caller is the `errs` table below.
  (define (escape-string s)
    (let loop ((i 0) (acc '()))
      (if (>= i (string-length s))
          (list->string (reverse acc))
          (let ((c (string-ref s i)))
            (loop (+ i 1)
                  (cond ((char=? c #\") (cons #\" (cons #\\ acc)))
                        ((char=? c #\\) (cons #\\ (cons #\\ acc)))
                        ((char=? c #\newline) (cons #\n (cons #\\ acc)))
                        (else (cons c acc))))))))

  ;; Each transition/fallback lowers to a loop tail: advance bumps pos and off,
  ;; reexecute keeps both. Rendered as one string with explicit, counted parens.
  ;;
  ;; The fourth argument is the POSITION KIND (decision 0022 item 5). It is a
  ;; property of the transition that ARRIVED, not of the error state: one error
  ;; node reached by a reexecute edge reports `byte` and the same node reached by
  ;; an advance edge reports `boundary`, and the emitted arm is keyed on state id
  ;; alone, so it cannot be a per-site literal there. Each jump therefore carries
  ;; its own kind forward.
  (define (loop-tail target mode)
    (if (eq? mode 'advance)
        (string-append "(loop (+ pos 1) " (number->string target) " (+ off 1) (quote boundary))")
        (string-append "(loop pos " (number->string target) " off (quote byte))")))

  (define (render-transition-arm tr)
    ;; tr = (byte target mode) -> "((<byte>) <loop-tail>)"
    ;; Milestone 3 Slice ① changed nothing here, and that is a decision rather
    ;; than an oversight: byte classes lower to one transition per byte
    ;; (decision 0014), so a complement renders up to 256 sibling arms inside the
    ;; single `(case b ...)` below. §19.2:1009 asks for "canonical membership
    ;; code selected for simplicity, not speculative density optimization", and a
    ;; grouped datum list or a membership table is the optimization §29:1743
    ;; defers and §23.3:1369 gates behind compiled benchmarks that cannot exist
    ;; yet (`bench/` holds two .gitkeep files).
    (string-append "               ((" (number->string (car tr)) ") "
                   (loop-tail (cadr tr) (caddr tr)) ")\n"))

  ;; An exhausted dispatch (finish? #t) routes eof: to a named node's loop
  ;; (continue the eof-target chain) or to the machine default-eof error.
  ;; The node case is the EOF-chain hop and carries `eof` forward. The default
  ;; case is a terminal construction reached by no jump at all, so it takes a
  ;; per-site (quote eof) literal rather than the loop variable -- §12.7:771
  ;; fixes `eof` whether or not a prior hop ran. Its node-name is the DISPATCH
  ;; node's, which is where truncation was detected: a default-EOF error has no
  ;; error node of its own (decision 0022 item 9).
  (define (render-eof-branch eof id name reason index-of)
    (if (eq? (car eof) 'node)
        (string-append "(loop pos " (number->string (cdr eof)) " off (quote eof))")
        (string-append "(byte-machine-make-feed-outcome/v1 (quote error) pos "
                       "(byte-machine-make-parser-error/v1 (vector-ref errs "
                       (number->string (index-of (cdr eof) reason)) ") (quote " (symbol->string name)
                       ") " id " off (quote eof)) " id " off)")))

  ;; Milestone 3 Slice ② changed nothing here either, and that is decision 0015
  ;; point 1 rather than an oversight: a lowered sequence-prefix state IS an
  ;; ordinary normalized dispatch state, so it renders through this same arm, the
  ;; encoding gains no tag, and the need-input
  ;; resume point below gives cross-feed resumability with no new mechanism. No
  ;; new emitted local means reserved-member-3 (decision 0012 item 4) is
  ;; unchanged. That was true through Milestone 3 and is not true here: Slice ①a
  ;; adds `fieldv`, `errs` and `pk`, and the gap the second half of this sentence
  ;; named -- "no automated drift guard" -- is closed by
  ;; member3-drift-tests.sps, which walks the emitted datum for every symbol
  ;; outside a quote form and asserts the remainder is a subset of this list.
  ;; `names` maps a state id to its public source-node name (§17:963's debug
  ;; map, normalizer output) and `index-of` a (code, reason) pair to that
  ;; declaration's position in the errs table. The name is not recoverable from a
  ;; normalized state at all, and the declaration is not recoverable from its
  ;; code alone -- codes need not be unique -- so both are threaded in from
  ;; render-machine rather than derived here.
  (define (render-state-arm s names index-of)
    (let ((id (number->string (normal-state-id s)))
          ;; Total by construction: the debug map and the internal state list
          ;; are built from the same prefix-block id alists, so every id in
          ;; `states` has an entry. Loud rather than trusting that, because a
          ;; missing key would otherwise surface as `(cdr #f)` deep inside a
          ;; string-append with nothing naming the state.
          (nm (lambda (i)
                (let ((hit (assv i names)))
                  (unless hit
                    (assertion-violation 'render-machine
                                         "no source name for normalized state" i))
                  (symbol->string (cdr hit))))))
      (case (normal-state-kind s)
        ((stop)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f " id " off))\n"))
        ((error)
         ;; The record's five call-site arguments: the errs entry (code and
         ;; reason together), the public source-node name, the state id, the
         ;; absolute offset, and the loop's position-kind variable. Reading `pk`
         ;; rather than a literal is what lets one error node report `byte` when
         ;; a reexecute edge arrives and `boundary` when an advance edge does.
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote error) pos "
                        "(byte-machine-make-parser-error/v1 (vector-ref errs "
                        (number->string (index-of (normal-error-code s)
                                                  (normal-error-reason s))) ") (quote "
                        (nm (normal-state-id s)) ") " id " off pk) " id " off))\n"))
        ((finish)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote finished) pos #f " id " off))\n"))
        ((pause)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
                        (number->string (normal-pause-target s)) " off))\n"))
        ((dispatch)
         (let ((fb (normal-dispatch-fallback s)))
           (string-append
            "      ((" id ")\n"
            "       (if (>= pos end)\n"
            "           (if finish?\n"
            "               " (render-eof-branch (normal-dispatch-eof s) id
                                                   (string->symbol (nm (normal-state-id s)))
                                                   (normal-error-reason s) index-of) "\n"
            "               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off))\n"
            "           (let ((b (bytevector-u8-ref bv pos)))\n"
            "             (case b\n"
            (apply string-append (map render-transition-arm (normal-dispatch-transitions s)))
            "               (else " (loop-tail (car fb) (cdr fb)) ")))))\n")))
        ;; Unreachable today -- this case already covers every kind
        ;; normal-state-kind can produce (dispatch/stop/error/finish/pause);
        ;; verified by inspection, not mutation (same convention as
        ;; normal-ir.sls's own else guards).
        (else (assertion-violation 'render-machine "unknown state kind"
                                   (normal-state-kind s))))))

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
           (names (normal-machine-debug-map normal))
           ;; One entry per error DECLARATION, in declaration order -- the order
           ;; errcode already walks. Per-SITE literals would repeat each reason
           ;; once per error site, and the default-eof arm alone renders at every
           ;; dispatch state: the http-version machine has nine error sites over
           ;; two declarations. This is §19.1:996's "immutable field/callback/debug
           ;; metadata", carried as one quoted vector.
           ;; Only the declarations the NORMALIZED graph reaches. The encoding
           ;; writes a reason at exactly two sites -- an error state's, and a
           ;; dispatch state's default-eof routing -- so a declaration no node
           ;; names and that is not the machine default-eof never reaches the IR
           ;; fingerprint. Emitting it anyway made two machines the fingerprint
           ;; calls identical emit DIFFERENT bytes, which is the converse of the
           ;; property decision 0019 item 2 states and the one nothing asserted.
           ;; Narrowing here rather than widening the encoding is what keeps
           ;; every shipped fingerprint where Slice ①a measured it, which
           ;; decision 0019 point 5 requires of every later slice.
           (reached (let walk ((i 0) (acc '()))
                      (if (>= i (vector-length states)) (reverse acc)
                          (let* ((st (vector-ref states i))
                                 (r (normal-error-reason st))
                                 (c (cond ((eq? (normal-state-kind st) 'error)
                                           (normal-error-code st))
                                          ((and (eq? (normal-state-kind st) 'dispatch)
                                                (eq? (car (normal-dispatch-eof st)) 'default))
                                           (cdr (normal-dispatch-eof st)))
                                          (else #f))))
                            (walk (+ i 1)
                                  (if (and c (not (member (cons c r) acc)))
                                      (cons (cons c r) acc) acc))))))
           (decls (let keep ((ds (machine-errors (compilation-machine compilation))) (acc '()))
                    (if (null? ds) (reverse acc)
                        (keep (cdr ds)
                              (if (member (cons (error-declaration-code (car ds))
                                                (error-declaration-reason (car ds)))
                                          reached)
                                  (cons (car ds) acc) acc)))))
           ;; Keyed on code AND reason, not on code alone. Two declarations may
           ;; share a code -- pass-names rejects duplicate declaration NAMES and
           ;; nothing rejects duplicate codes, and §16.2's required-check list
           ;; does not ask for uniqueness -- and the normalizer has already
           ;; collapsed the node's declaration name to its resolved code by the
           ;; time the emitter sees it. Keying on the code alone therefore
           ;; returned the FIRST declaration carrying it, so a generated parser
           ;; reported a different declaration's reason than the interpreter,
           ;; on a machine the verifier accepts with zero diagnostics. The
           ;; normalized state has carried the right reason in its own slot
           ;; since format 2, which is what makes this recoverable without a new
           ;; slot: (code, reason) selects the entry the SITE produced, and when
           ;; two declarations agree on both, their errs entries are identical
           ;; and either index yields the same record -- so this is total.
           (index-of (lambda (code reason)
                       (let walk ((ds decls) (i 0))
                         (cond ((null? ds)
                                ;; Unreachable: every code/reason pair the
                                ;; emitter asks about was resolved FROM this
                                ;; same list by the normalizer. Loud rather than
                                ;; a silent fallback to 0, which is what the
                                ;; first version of this walk would have done.
                                (assertion-violation
                                 'render-machine "no error declaration for code"
                                 code reason))
                               ((and (eq? (error-declaration-code (car ds)) code)
                                     (string=? (error-declaration-reason (car ds)) reason))
                                i)
                               (else (walk (cdr ds) (+ i 1)))))))
           (errs (let join ((ds decls) (acc ""))
                   (if (null? ds) acc
                       (join (cdr ds)
                             (string-append acc (if (string=? acc "") "" " ")
                                            "#(" (symbol->string (error-declaration-code (car ds)))
                                            " \"" (escape-string (error-declaration-reason (car ds)))
                                            "\")")))))
           ;; Decision 0019 item 3(b)'s member 0, filled by Slice ①b. It renders
           ;; the field DECLARATIONS as (name . initial) pairs in slot order,
           ;; not bare initials: the parser needs the initials AND the
           ;; name-to-slot resolution parser-field-ref answers by, the slot is
           ;; the pair's position, so one member determines both and a second
           ;; member would be a second ABI growth for data the first already
           ;; carries. With no fields this is the empty string, so the member
           ;; renders `#()` and the payload `#(#())` -- byte-identical to ①a,
           ;; which is decision 0019 item 5 and the reason no golden moves.
           ;;
           ;; Rendered from the NORMALIZED table rather than from machine-fields,
           ;; so the emitted slot order is the same object the IR fingerprint was
           ;; computed over. Reading the source machine again would let the two
           ;; disagree with nothing to notice.
           (fields (let loop ((fs (normal-machine-fields normal)) (acc ""))
                     (if (null? fs) acc
                         (loop (cdr fs)
                               (string-append
                                acc (if (string=? acc "") "" " ")
                                "(" (symbol->string (car (car fs)))
                                " . " (number->string (caddr (car fs))) ")")))))
           (bstr (symbol->string binding)))
      (string->utf8
       (string-append
        "(library (generated " mname ")\n"
        "  (export " bstr ")\n"
        "  (import (rnrs) (byte-machine runtime))\n"
        "  (define errs (quote #(" errs ")))\n"
        "  (define (exec state offset bv start end finish? fieldv)\n"
        ;; The kind is initialized `boundary` UNCONDITIONALLY, with no finish?
        ;; key: nothing has been consumed since either kind of call began, so an
        ;; error state reached with no jump taken reports a boundary at the
        ;; current stream offset regardless of which call observes it. Keying
        ;; this on finish? made both lanes report `eof` at the default-EOF arm
        ;; and made that arm's own literal observationally identical to the
        ;; inherited variable -- agreement bought by making the difference
        ;; unobservable, which is the repair AGENTS.md warns disarms its own test.
        "    (let loop ((pos start) (st state) (off offset) (pk (quote boundary)))\n"
        "      (case st\n"
        (let loop ((i 0) (acc ""))
          (if (>= i (vector-length states)) acc
              (loop (+ i 1) (string-append acc (render-state-arm (vector-ref states i)
                                                                 names index-of)))))
        "      (else (assertion-violation (quote exec) \"unknown state\" st)))))\n"
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine 3 " (number->string fp) " "
        (number->string entry) " exec (quote #(#(" fields "))))))\n"))))

  (define (emit-machine compilation binding port)
    (let ((bytes (render-machine compilation binding)))
      (put-bytevector port bytes)
      (vector 'emission-metadata
              (normal-machine-fingerprint (compilation-normal compilation))
              (bytevector-length bytes)))))
