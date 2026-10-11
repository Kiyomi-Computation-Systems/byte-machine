;;; The fixture lane. Registered as byte-machine.property.fixture.chez.{source,aot}
;;; under label `property`. It carries:
;;;   - the PRINTER's proof: the derived totality rows over `node?` and
;;;     `matcher?`, and the round trip byte-identical over every accepted machine
;;;     of the committed seed set;
;;;   - the deliberate-failure PROBE: a lying compiled lane driven through
;;;     the saver and the minimizer, the raw fixture asserted to FAIL and the
;;;     minimized one strictly smaller and still failing, a passing pair writing
;;;     nothing.
;;; The printer's success groups and the probe's failure groups are kept in
;;; SEPARATE harness-groups with distinct labels so the mutation pass can
;;; assert each pin's failure SIGNATURE rather than a bare nonzero exit.
;;;
;;; The printer's tests are folded here rather than into a separate
;;; machine-print-tests.sps: one program and one lane pair keep the fingerprint
;;; and CMake surface small, and the failure signatures stay clean through
;;; group/label separation, not through a second program.
(import (rnrs) (rnrs eval)
        (only (chezscheme) command-line-arguments)
        (byte-machine test harness)
        (byte-machine test machine-gen)
        (byte-machine test property-driver)
        (byte-machine test prng)
        (byte-machine test machine-print)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

;; The committed seed: the registrations pass nothing, so this governs. The
;; same integer the differential lane commits.
(define seed 20260823)
(define machine-count 64)
(define floor-literal 32)   ; half of machine-count; 36 measured at this seed.

;; ---- the totality rows read ir.sls AS A DATUM. The readers replicate the
;; differential program's shape (property-differential-tests.sps) rather than
;; import them -- they live in .sps programs, not libraries.
;; BYTE_MACHINE_SOURCE_ROOT is loud when unset (a census that silently read the
;; wrong tree would compare nothing and report the arm table load-bearing for no
;; reason).
(define source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r ""))) r
        (assertion-violation 'fixture "BYTE_MACHINE_SOURCE_ROOT is unset" r))))
(define ir-datum
  (call-with-input-file (string-append source-root "/byte-machine/private/ir.sls") read))
(define (sortsym l)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) l))
(define (strip-suffix sym suf)          ; 'byte-dispatch-node? "-node?" -> 'byte-dispatch
  (let* ((s (symbol->string sym)) (n (string-length s)))
    (string->symbol (substring s 0 (- n (string-length suf))))))
;; the disjunct predicate names of `(define (HEAD x) (or (p1? x) …))`, each stripped
;; of SUFFIX and sorted -- ir.sls's closed set for a kind family.
(define (disjuncts-of datum head suffix)
  (let loop ((x datum))
    (cond ((not (pair? x)) #f)
          ((and (pair? (car x)) (eq? (caar x) 'define) (pair? (cdar x)) (pair? (cadar x))
                (eq? (car (cadar x)) head))
           (let ((body (caddar x)))
             (and (pair? body) (eq? (car body) 'or)
                  (sortsym (map (lambda (p) (strip-suffix (car p) suffix)) (cdr body))))))
          (else (or (loop (car x)) (loop (cdr x)))))))

;; ---- the round trip's proof: IR fingerprint, not structural equality. This is
;; exactly the differential program's machine->bytes -- render-machine of
;; compile-machine is a total function of the IR, so byte-identity of the rendered
;; bytes is IR identity. The reprinted machine is `eval` of the printer's datum in
;; an environment that imports (byte-machine graph); nothing under src/ is touched.
(define graph-env (environment '(rnrs) '(byte-machine graph)))
(define (reprint m) (eval (print-machine m) graph-env))
(define (machine->bytes m) (render-machine (compile-machine m '()) 'gen-parser))

(harness-begin "property.fixture")

(harness-group "printer"
 (lambda ()
   ;; (a) the derived totality rows: the hand-written arm tables' kinds set-
   ;; equal to ir.sls's node?/matcher? disjuncts. A node kind added to ir.sls
   ;; with no printer arm fails HERE (and print-node's own no-arm raise).
   (harness-case "totality"
    (lambda ()
      (check-equal "the node arm table has fourteen kinds"
                   (length node-print-arm-table) 14)
      (check-equal "the matcher arm table has four kinds"
                   (length matcher-print-arm-table) 4)
      (check-equal "the node arm table's kinds are node?'s fourteen disjuncts"
                   (sortsym (map car node-print-arm-table))
                   (disjuncts-of ir-datum 'node? "-node?"))
      (check-equal "the matcher arm table's kinds are matcher?'s four disjuncts"
                   (sortsym (map car matcher-print-arm-table))
                   (disjuncts-of ir-datum 'matcher? "-matcher?"))))
   ;; (b) the round trip byte-identical over EVERY accepted machine of the committed
   ;; seed set, not a hand-picked few. reset-draw-state! once before the
   ;; loop makes this a fresh-process draw (the coverage cycles are module-level);
   ;; the 64 are then drawn sequentially, exactly as the differential drive does.
   (harness-case "round trip byte-identical over the seed set"
    (lambda ()
      (reset-draw-state!)
      (let loop ((i 0) (s (make-prng seed)) (drawn 0) (accepted 0) (ok 0))
        (if (= i machine-count)
            (begin
              (check-equal "drew the whole committed seed set" drawn machine-count)
              (check "accepted count is at or above the 0033 item 2 floor"
                     (>= accepted floor-literal))
              ;; derived total reads OBSERVED per-machine results (ok), not the
              ;; test's expectation: every accepted machine round-tripped.
              (check-equal "every accepted machine round-tripped byte-identical"
                           ok accepted)
              (display "property-fixture-tests: round-tripped ")
              (display accepted) (display " of ") (display drawn)
              (display " drawn machines") (newline))
            (let-values (((m mani s2) (gen-machine s (property-steering))))
              (let ((v (verify-machine m)))
                (if (verification-ok? v)
                    (let ((same (bytevector=? (machine->bytes (reprint m))
                                              (machine->bytes m))))
                      (check (string-append "round trip byte-identical: machine "
                                            (number->string i))
                             same)
                      (loop (+ i 1) s2 (+ drawn 1) (+ accepted 1) (if same (+ ok 1) ok)))
                    (loop (+ i 1) s2 (+ drawn 1) accepted ok))))))))))

;; ---- run-one-trial: the single-trial entry the fixture asserts on
;; and the minimizer uses as a boolean oracle. ----
(harness-group "run-one-trial"
 (lambda ()
   (define (interp m) (make-interpreted-machine (verify-machine m)))
   (define (u8 . bs) (u8-list->bytevector bs))
   ;; two one-byte machines (class-machine shape) that disagree on 0x41: one
   ;; accepts it (advance -> stop), the other rejects it (reexecute -> error).
   ;; Named 'gen so both are portable; no fields, callbacks or spans.
   (define (one-byte b)
     (make-machine 'gen 'start '() '() '()
       (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
             (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
       (list (make-byte-dispatch-node 'start
               (list (make-byte-case (make-exact-byte-matcher b) (make-edge 'stop 'advance) #f))
               (make-edge 'reject 'reexecute) #f #f)
             (make-stop-node 'stop #f)
             (make-error-node 'reject 'rejected #f))
       'default-eof #f))
   (define mA (one-byte 65))
   (define mB (one-byte 66))
   (harness-case "agreeing lanes return 'none"
    (lambda ()
      (check-equal "identical lanes agree on 0x41 -> none"
                   (run-one-trial mA (interp mA) (interp mA) '() (list (list (u8 65) 0 1)) (u8 65))
                   'none)))
   (harness-case "a deliberately different second lane returns a non-'none verdict"
    (lambda ()
      (let ((v (run-one-trial mA (interp mA) (interp mB) '() (list (list (u8 65) 0 1)) (u8 65))))
        (check "a different second lane disagrees on 0x41" (not (eq? v 'none)))
        ;; the same shape run-machine folds: a disagreement descriptor whose car is
        ;; a run-schedule phase (feed / feed-ack / finish / finish-ack).
        (check "the verdict is a well-formed disagreement descriptor"
               (and (pair? v) (memq (car v) '(feed feed-ack finish finish-ack)))))))
   ;; run-one-trial's verdict is what run-machine folds for the same
   ;; schedule. Over every accepted machine of the committed seed set, an honest
   ;; identical lane pair on a single-byte schedule the byte-sweep covers agrees:
   ;; both 'none. This also proves run-one-trial's agreement-gated Layer-3 arm is
   ;; quiet on every valid accepted machine.
   (harness-case "run-one-trial agrees with run-machine (both 'none) over the seed set"
    (lambda ()
      (reset-draw-state!)
      (let loop ((i 0) (s (make-prng seed)) (accepted 0) (agreed 0))
        (if (= i machine-count)
            (begin
              (check "accepted count is at or above the floor" (>= accepted floor-literal))
              (check-equal "run-one-trial returned 'none for every accepted machine"
                           agreed accepted))
            (let-values (((m mani s2) (gen-machine s (property-steering))))
              (if (verification-ok? (verify-machine m))
                  (let* ((ref (interp m))
                         (none? (eq? (run-one-trial m ref ref '() (list (list (u8 0) 0 1)) (u8 0))
                                     'none)))
                    (check (string-append "run-one-trial 'none on accepted machine "
                                          (number->string i))
                           none?)
                    (loop (+ i 1) s2 (+ accepted 1) (if none? (+ agreed 1) agreed)))
                  (loop (+ i 1) s2 accepted agreed)))))))))

;; ---- the deliberate-failure probe. The lane cannot wait for a real
;; interpreter/generated disagreement, so it ships a machine and a WRONG second lane
;; -- a compiled machine whose op is wrapped to lie about one member -- drives
;; it through the saver and the minimizer, and asserts the saved fixture fails, the
;; minimized one is smaller and still fails, and a passing pair writes nothing. ----

(define (u8 . bs) (u8-list->bytevector bs))
(define (whole bv) (list (list bv 0 (bytevector-length bv))))
(define (interp m) (make-interpreted-machine (verify-machine m)))
;; Where save-fixture writes the probe fixtures. Unlike the differential lane, which
;; is LOUD on an unset BYTE_MACHINE_TEST_TMPDIR (it must emit a generated lane per
;; machine), this program degrades to "." deliberately: it must also run under the
;; Scheme mutation runner, whose verify command sets no tmpdir, and its saver writes
;; are throwaway probe fixtures. The registered CTest lanes set the var, so a normal
;; run writes into the per-lane tmp directory, never the source tree.
(define (tmpdir-or-dot)
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d ".")))
(define (write-file! path text)
  (call-with-port (open-file-output-port path (file-options no-fail))
    (lambda (p) (put-bytevector p (string->utf8 text)))))
(define (file-exists-nonempty? path)
  (guard (e (#t #f)) (> (bytevector-length (adapter-file-bytes path)) 0)))

;; The chosen reducible lie: perturb the compiled
;; op's accumulate-step so the digit loop-back target 'acc becomes 'stopped. As a
;; LIVE procedure for the in-lane trial/minimizer, and as DATUMS for the fixture the
;; saver writes (there it wraps the emitted `gen-honest`; here it wraps the interp op
;; -- the same accumulate-step result either way, since the lanes agree honestly).
(define (perturb msg r)
  (if (and (eq? msg 'accumulate-step) (pair? r) (eq? (car r) 'acc)) (cons 'stopped (cdr r)) r))
(define (lie-of m)
  (let ((honest-op (vector-ref (interp m) 2)))          ; reach slot 2 knowingly
    (make-compiled-machine (lambda (msg . args) (perturb msg (apply honest-op msg args))))))
(define lie-preamble
  '((define (perturb msg r)
      (if (and (eq? msg 'accumulate-step) (pair? r) (eq? (car r) 'acc)) (cons 'stopped (cdr r)) r))))
(define lie-gen-expr
  '(make-compiled-machine (lambda (msg . args) (perturb msg (apply (vector-ref ref 2) msg args)))))

;; The fixture header: reconstruct the exact provenance-unset launcher command from
;; (command-line-arguments) -- the two --library-root values, the --object-guard,
;; the launcher (derived from the src root), and --program <this fixture>.
(define (flag-values cla flag)
  (let loop ((r cla) (acc '()))
    (cond ((or (null? r) (null? (cdr r))) (reverse acc))
          ((string=? (car r) flag) (loop (cddr r) (cons (cadr r) acc)))
          (else (loop (cddr r) acc)))))
(define (strip-str-suffix s suf)
  (let ((n (string-length s)) (k (string-length suf)))
    (if (and (>= n k) (string=? (substring s (- n k) n) suf)) (substring s 0 (- n k)) s)))
(define (invocation-header fixture-path)
  (let* ((cla (command-line-arguments))
         (roots (flag-values cla "--library-root"))
         (guard (let ((g (flag-values cla "--object-guard"))) (if (pair? g) (car g) "<object-guard>")))
         (src (let loop ((rs roots)) (cond ((null? rs) "<src>")
                                           ((>= (string-length (car rs)) 4)
                                            (if (string=? (substring (car rs) (- (string-length (car rs)) 4) (string-length (car rs))) "/src")
                                                (car rs) (loop (cdr rs))))
                                           (else (loop (cdr rs))))))
         (tree (strip-str-suffix src "/src"))
         (launcher (string-append tree "/test/support/launchers/chez-source.ss")))
    (string-append
     ";; A reproducible failure fixture (Milestone 7 Slice 3, 25:1627). Self-contained:\n"
     ";; it builds both lanes from the interpreter and writes nothing. Run it with the\n"
     ";; shipped launcher (provenance unset, so a hand run skips the fingerprint check):\n"
     ";;\n"
     ";;   env -u BYTE_MACHINE_FINGERPRINT_FILES -u BYTE_MACHINE_EXPECT_FINGERPRINT_FILE \\\n"
     ";;     chez --script " launcher " \\\n"
     (apply string-append (map (lambda (r) (string-append ";;       --library-root " r " \\\n")) roots))
     ";;       --object-guard " guard " \\\n"
     ";;       --program " fixture-path "\n"
     ";;\n"
     ";; It exits 1 while the two lanes disagree, and 0 once the disagreement is fixed.\n\n")))

;; The direct saver: build the fixture text (driver's fixture-text) with the lie
;; baked, write it, return its path. Used for the raw and the minimized fixtures --
;; one writer, two calls.
(define (save-fixture tag m script schedule input)
  (let* ((path (string-append (tmpdir-or-dot) "/probe-fixture-" tag ".sps"))
         (text (fixture-text (print-machine m) script schedule input
                             (invocation-header path) lie-preamble lie-gen-expr)))
    (write-file! path text)
    path))

;; Re-read a saved fixture in-process and run its trial exactly as the fixture would,
;; through eval: evaluate the
;; fixture's own top-level (define …) forms -- machine, script, schedule, input, ref,
;; the perturb definition, and gen (the EMBEDDED lie) -- in dependency order, then
;; run-one-trial over them. Because it evaluates the fixture's OWN gen wiring, a
;; mutation to the saver that writes a non-reproducing fixture (e.g. gen := ref) is
;; caught here, not only by a by-hand standalone run.
(define fx-env (environment '(rnrs) '(byte-machine graph) '(byte-machine verify)
                            '(byte-machine interpret) '(byte-machine runtime)
                            '(byte-machine test property-driver)))
(define (fixture-define-forms path)
  (let ((port (open-string-input-port (utf8->string (adapter-file-bytes path)))))
    (let loop ((acc '()))
      (let ((form (get-datum port)))
        (cond ((eof-object? form) (reverse acc))
              ((and (pair? form) (eq? (car form) 'define)) (loop (cons form acc)))
              (else (loop acc)))))))
(define (reruns-disagree? path)
  (not (eq? (eval `(let () ,@(fixture-define-forms path)
                     (run-one-trial machine ref gen script schedule input))
                  fx-env)
            'none)))

(harness-group "saver"
 (lambda ()
   ;; on-first-disagreement fires AT MOST ONCE per machine when the lanes
   ;; disagree, and NOT AT ALL when they agree (a passing pair writes nothing). Driven through run-machine, which needs a manifest -- so a
   ;; DRAWN accepted machine with a field, and the field-initials +1 lie (measured
   ;; 8/8: it disagrees on the very first byte-sweep byte, which is all this wiring
   ;; test needs). A counting sentinel closure stands in for the file write.
   (harness-case "run-machine calls on-first-disagreement once on disagreement, never on agreement"
    (lambda ()
      (reset-draw-state!)
      (let loop ((i 0) (s (make-prng seed)))
        (if (= i machine-count)
            (check-fail "no accepted drawn machine with a field in the seed set" "unexpected")
            (let-values (((m mani s2) (gen-machine s (property-steering))))
              (if (and (verification-ok? (verify-machine m)) (pair? (manifest-fields mani)))
                  (let* ((v (verify-machine m))
                         (ref (make-interpreted-machine v))
                         (honest-op (vector-ref ref 2))
                         (gen-lie (make-compiled-machine
                                   (lambda (msg . args)
                                     (let ((r (apply honest-op msg args)))
                                       (if (and (eq? msg 'field-initials) (> (vector-length r) 0))
                                           (let ((v2 (list->vector (vector->list r))))
                                             (vector-set! v2 0 (cons (car (vector-ref v2 0))
                                                                     (+ 1 (cdr (vector-ref v2 0)))))
                                             v2)
                                           r)))))
                         (fires 0)
                         (closer (lambda (mm sc sch inp vd) (set! fires (+ fires 1)) "fired")))
                    ;; disagreeing: gen lies -> fires exactly once, fixture-path non-#f
                    (let-values (((c1 v1 iv1 fp1 st1)
                                  (run-machine m ref gen-lie mani '() (make-prng (+ seed i 7))
                                               (make-counter-set) closer)))
                      (check-equal "fired exactly once on the disagreeing machine" fires 1)
                      (check "fixture-path threaded from the saver's return" (equal? fp1 "fired")))
                    ;; agreeing: gen = ref (honest) -> never fires, fixture-path #f
                    (set! fires 0)
                    (let-values (((c2 v2 iv2 fp2 st2)
                                  (run-machine m ref ref mani '() (make-prng (+ seed i 7))
                                               (make-counter-set) closer)))
                      (check-equal "did not fire on the agreeing machine" fires 0)
                      (check "fixture-path is #f when the lanes agree" (eq? fp2 #f))))
                  (loop (+ i 1) s2)))))))))

;; The probe machine: the accumulate-machine's shape (a uint field, an
;; integer-accumulate node reached only after '#'), but NAMED 'gen so the emitted
;; library is `(generated gen)` -- the name the fixture (and every drawn machine)
;; loads. The name is a label, not behaviour, and the minimizer preserves it, so
;; the raw and minimized fixtures both emit `(generated gen)`.
(define (make-probe-machine)
  (let ((errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                    (make-error-declaration 'too-big 'unexpected-byte "field overflow" #f)
                    (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))))
    (make-machine 'gen 'start
      (list (make-uint-field 'value 16 0 #f))
      '() '() errs
      (list (make-byte-dispatch-node 'start
              (list (make-byte-case (make-exact-byte-matcher 35) (make-edge 'acc 'advance) #f))
              (make-edge 'reject 'reexecute) #f #f)
            (make-integer-accumulate-node 'acc 'value 16 'acc (make-edge 'stopped 'advance)
                                          'over 'done #f)
            (make-finish-node 'done #f)
            (make-stop-node 'stopped #f)
            (make-error-node 'over 'too-big #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))

(harness-group "reproduction and the minimizer"
 (lambda ()
   (define m (make-probe-machine))
   (define script '())
   (define input (u8 35 48 65))              ; "#0A": '#' opens, '0'/'A' accumulate -> the lie
                                             ; bites; the minimizer shrinks it to "#0" (dropping
                                             ; 'A' still disagrees; dropping a digit agrees)
   (define schedule (whole input))
   (harness-case "the lying trial disagrees in memory (run-one-trial)"
    (lambda ()
      (check "run-one-trial reports the disagreement"
             (not (eq? (run-one-trial m (interp m) (lie-of m) script schedule input) 'none)))))
   (harness-case "the saved RAW fixture reproduces the disagreement"
    (lambda ()
      (let ((path (save-fixture "raw" m script schedule input)))
        (check "the raw fixture file was written" (file-exists-nonempty? path))
        (check "the raw fixture's saved trial still disagrees when re-read and re-run"
               (reruns-disagree? path)))))
   (harness-case "the minimizer shrinks the trial and preserves the disagreement"
    (lambda ()
      (let ((fail-oracle (lambda (m2 s2 i2 sch2) (run-one-trial m2 (interp m2) (lie-of m2) s2 sch2 i2))))
        (let-values (((m2 s2 i2 sch2) (minimize m script input schedule fail-oracle 64)))
          ;; strictly smaller: fewer nodes OR a shorter input.
          (check "the minimized trial is strictly smaller"
                 (or (< (machine-node-count m2) (machine-node-count m))
                     (< (bytevector-length i2) (bytevector-length input))))
          (check "the minimized trial still disagrees"
                 (not (eq? (run-one-trial m2 (interp m2) (lie-of m2) s2 sch2 i2) 'none)))
          (let ((path (save-fixture "min" m2 s2 sch2 i2)))
            (check "the minimized fixture file was written" (file-exists-nonempty? path))
            (check "the minimized fixture's saved trial still disagrees when re-read and re-run"
                   (reruns-disagree? path)))))))
   (harness-case "a PASSING pair reproduces nothing (honest gen agrees)"
    (lambda ()
      ;; the honest generated lane agrees with the reference, so run-one-trial is
      ;; 'none and the saver's on-first-disagreement would never fire.
      (check-equal "run-one-trial is 'none for an honest pair"
                   (run-one-trial m (interp m) (interp m) script schedule input)
                   'none)))))

(harness-finish)
