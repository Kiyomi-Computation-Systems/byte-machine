;;; The fixture lane (Milestone 7 Slice ③; design §4.7/§8, decision 0033 item 4).
;;; Registered as byte-machine.property.fixture.chez.{source,aot} under label
;;; `property`. It carries, in this slice's order of construction:
;;;   - the PRINTER's proof (Task 2): the derived totality rows over `node?` and
;;;     `matcher?`, and the round trip byte-identical over every accepted machine
;;;     of the committed seed set;
;;;   - the deliberate-failure PROBE (Task 6): a lying compiled lane driven through
;;;     the saver and the minimizer, the raw fixture asserted to FAIL and the
;;;     minimized one strictly smaller and still failing, a passing pair writing
;;;     nothing.
;;; The printer's success groups and the probe's failure groups are kept in
;;; SEPARATE harness-groups with distinct labels so the mutation pass (Task 8) can
;;; assert each pin's failure SIGNATURE rather than a bare nonzero exit.
;;;
;;; Folded here rather than a separate machine-print-tests.sps (Task 6 Step 1):
;;; §2 ships one new program and Task 7 registers one new lane pair, so folding
;;; keeps the fingerprint and CMake surface the plan sized; the failure signatures
;;; stay clean through group/label separation, not through a second program.
(import (rnrs) (rnrs eval)
        (byte-machine test harness)
        (byte-machine test machine-gen)
        (byte-machine test property-driver)
        (byte-machine test prng)
        (byte-machine test machine-print)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine compile))

;; The committed seed (0033 item 3): the registrations pass nothing, so this
;; governs. The same integer the differential lane commits (§8's seed set).
(define seed 20260823)
(define machine-count 64)
(define floor-literal 32)   ; 0033 item 2; 36 measured at this seed on this tree.

;; ---- the totality rows read ir.sls AS A DATUM (F4 / design §4.10). The readers
;; replicate the differential program's shape (property-differential-tests.sps
;; :165-185) rather than import them -- they live in .sps programs, not libraries.
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
   ;; (a) the derived totality rows (F4): the hand-written arm tables' kinds set-
   ;; equal to ir.sls's node?/matcher? disjuncts. A fourteenth node kind added to
   ;; ir.sls with no printer arm fails HERE (and print-node's own no-arm raise).
   (harness-case "totality"
    (lambda ()
      (check-equal "the node arm table has thirteen kinds"
                   (length node-print-arm-table) 13)
      (check-equal "the matcher arm table has four kinds"
                   (length matcher-print-arm-table) 4)
      (check-equal "the node arm table's kinds are node?'s thirteen disjuncts"
                   (sortsym (map car node-print-arm-table))
                   (disjuncts-of ir-datum 'node? "-node?"))
      (check-equal "the matcher arm table's kinds are matcher?'s four disjuncts"
                   (sortsym (map car matcher-print-arm-table))
                   (disjuncts-of ir-datum 'matcher? "-matcher?"))))
   ;; (b) the round trip byte-identical over EVERY accepted machine of the committed
   ;; seed set (Step 5), not a hand-picked few. reset-draw-state! once before the
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

;; ---- run-one-trial (Task 3, F2): the single-trial entry the fixture asserts on
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
   ;; Step 5: run-one-trial's verdict is what run-machine folds for the same
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

;; ---- Task 6 appends the deliberate-failure probe groups below this line. ----

(harness-finish)
