;;; Property differential. Sixty-four generated machines drawn over EVERY IR
;;; construct, the interpreter oracle against the emitted executor, compared at
;;; three layers. Only VERIFIED machines reach an executor; rejected draws are
;;; normal and are counted, not failed. The floor requires at least half the
;;; machine count accepted; the counters require every construct OBSERVED in
;;; both halves. The floor does not measure what it is for on its own -- a draw
;;; steered to a single error node per machine would clear it while every counter
;;; read zero -- so what stops the degenerate case is the counters, not the floor.
;;;
;;; THE BLIND SPOT: all three layers are blind to an agreed-wrong value that
;;; satisfies every invariant, and one is in the tree -- the machine-action half
;;; of the zero-width position-kind rule. A FAILED zero-width action reached over
;;; a REEXECUTE edge should report `boundary`, and BOTH lanes report `byte`. This
;;; lane DRAWS that shape thousands of times per seed set and every trial passes,
;;; because the layers compare the lanes against each other (they agree) and read
;;; no position kind. The fix belongs in compile.sls's field-action arm and
;;; interpret.sls's field-step, which both carry the KNOWN LIMITATION note.
;;;
;;; The driver ((byte-machine test property-driver)) owns the trial, the pause
;;; protocol, the counters and the comparison layers; the fixture saver and the
;;; minimizer read the same library. This program is the imperative shell: it draws
;;; the machines, verifies them, hands the accepted ones over, and asserts.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test property-driver)
        (byte-machine test machine-gen)
        (byte-machine test counted-machine)
        (byte-machine test prng)
        (byte-machine graph)
        (byte-machine private ir)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile)
        (byte-machine private conditions))

;; ---- the seed ----
;; Read BYTE_MACHINE_PROPERTY_SEED; unset is LEGAL (the committed default) and
;; malformed is LOUD -- the opposite polarity from BYTE_MACHINE_TEST_TMPDIR, whose
;; unset is the loud case. `(rnrs)` has no string-trim, so the whitespace set is
;; replicated from harness-whitespace-byte? (32/9/10/13) so the two agree; the
;; radix is passed explicitly because bare string->number accepts #x1f, 1/2, 1e3.
(define committed-seed 20260823)
(define (ws-char? c) (let ((b (char->integer c))) (or (= b 32) (= b 9) (= b 10) (= b 13))))
(define (trim s)
  (let* ((cs (string->list s))
         (a (let drop ((l cs)) (if (and (pair? l) (ws-char? (car l))) (drop (cdr l)) l)))
         (b (reverse (let drop ((l (reverse a))) (if (and (pair? l) (ws-char? (car l))) (drop (cdr l)) l)))))
    (list->string b)))
(define seed
  (let ((raw (adapter-environment-variable "BYTE_MACHINE_PROPERTY_SEED")))
    (if (not raw) committed-seed
        (let ((t (trim raw)))
          (if (string=? t "") committed-seed
              (let ((n (string->number t 10)))
                (if (and n (integer? n) (exact? n) (>= n 0)) n
                    (assertion-violation 'property
                      "BYTE_MACHINE_PROPERTY_SEED is not a nonnegative decimal integer" raw))))))))

;; Printed once at the suite's start, so a run's output names its seed. The
;; text introduces no token any pin of this SPEC matches (checked against every
;; Pass 39 pin).
(display "property-differential-tests: drawing seed ") (display seed) (newline)

(harness-begin "property.differential")

(define machine-count 64)
(define floor-literal 32)   ; no lower than half the machine count;
                            ; measured through this lane and this generator = 41
(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'property "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (emit-and-load m i)
  (let ((genfile (string-append tmpdir "/prop-" (number->string i) ".sls")))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) 'gen-parser p)))
    (load genfile)
    (eval 'gen-parser (environment '(generated gen)))))

;; Fingerprint a drawn machine by its deterministic rendering (machine objects
;; carry no printable form, but the compiled rendering is a total function of the
;; IR). Used by the reproducibility case.
(define (machine->bytes m) (render-machine (compile-machine m '()) 'gen-parser))

;; Eight drawn inputs of length 0-6 per machine, from the machine's own
;; TRIAL stream -- separate from the machine-drawing stream so the accepted count
;; is a function of the generator and the seed alone, not of the trial machinery.
(define (draw-inputs s)
  (let loop ((n 0) (s s) (acc '()))
    (if (= n 8) (values (reverse acc) s)
        (let-values (((len s2) (prng-next s 7)))
          (let bl ((j 0) (s s2) (bs '()))
            (if (= j len) (loop (+ n 1) s (cons (u8-list->bytevector (reverse bs)) acc))
                (let-values (((b s3) (prng-next s 256))) (bl (+ j 1) s3 (cons b bs)))))))))

;; ---- the drive ----
(define counters (make-counter-set))
(define accepted-count 0)
(define rejected-count 0)
(define interpreted-count 0)
(define generated-count 0)
(define fed-unverified 0)
(define verdicts '())          ; (index . verdict) L1 cross-lane, for accepted machines
(define inv-verdicts '())      ; (index . inv-verdict) L3 oracle, for accepted machines
(define machines-loop-ran 0)   ; L1 sentinel: the machine loop ran machine-count times
(define trials-loop-ran 0)     ; sentinel: run-machine returned for every accepted machine

(define floor-held? #f)
;; The drive runs INSIDE the accounting case (below), so a raise from the trials
;; -- e.g. a mutation that stops the driver resuming, which trips runtime.sls's
;; lifecycle-violation guard -- aborts that case as "case raised" (status 1) with
;; the condition's detail in the output, rather than escaping the top level as an
;; uncaught exception (which would exit 255, a "wrong reason" for the mutation
;; suite). It also means such a mutant never reaches the floor or the counter
;; case, so it produces no per-member label.
(define (drive!)
 (let loop ((i 0) (s (make-prng seed)))
  (when (< i machine-count)
    (set! machines-loop-ran (+ machines-loop-ran 1))
    (let-values (((m mani s2) (gen-machine s (property-steering))))
      (let ((v (verify-machine m)))
        (if (verification-ok? v)
            (begin
              (set! accepted-count (+ accepted-count 1))
              ;; The guard reads the EXECUTOR's own refusal: if the verdict filter
              ;; is mutated away, a rejected draw reaches make-interpreted-machine
              ;; and it raises unverified-machine before any counter runs; the guard
              ;; turns that raise into TWO comparisons that name the decision
              ;; (interpreted-count < accepted-count, and fed-unverified > 0) rather
              ;; than a raw condition. make-interpreted-machine refuses a rejected
              ;; RESULT correctly; handed a machine it raises a raw vector-ref with
              ;; no who, so the structural count -- not the API's refusal -- is the
              ;; real guard, and this comment says which.
              (guard (e ((and (byte-machine-contract-condition? e)
                              (eq? (byte-machine-contract-condition-code e) 'unverified-machine))
                         (set! fed-unverified (+ fed-unverified 1)) #f)
                        (#t (raise e)))
                (let ((ref (make-interpreted-machine v)))
                  (set! interpreted-count (+ interpreted-count 1))
                  (let ((gen (emit-and-load m i)))
                    (set! generated-count (+ generated-count 1))
                    (let-values (((inputs ts2) (draw-inputs (make-prng (+ seed i 1)))))
                      (let-values (((c verdict inv-v fp ts3)
                                    (run-machine m ref gen mani inputs ts2 counters #f)))
                        (set! trials-loop-ran (+ trials-loop-ran 1))
                        (set! verdicts (cons (cons i verdict) verdicts))
                        (set! inv-verdicts (cons (cons i inv-v) inv-verdicts))))))))
            (set! rejected-count (+ rejected-count 1)))
        (loop (+ i 1) s2)))))
 (set! verdicts (reverse verdicts))
 (set! inv-verdicts (reverse inv-verdicts))
 (set! floor-held? (>= accepted-count floor-literal)))

;; ---- the totality rows read ir.sls AS A DATUM. The readers replicate the
;; census readers' shape (diagnostic-census's defined-list,
;; kind-position-census's node?/matcher? disjunct walk) rather than import
;; them -- they live in .sps programs, not libraries. BYTE_MACHINE_SOURCE_ROOT
;; is loud when unset, for the diagnostic census's reason: a census that silently
;; read the wrong tree would report every source-side mutation caught for nothing.
(define source-root
  (let ((r (adapter-environment-variable "BYTE_MACHINE_SOURCE_ROOT")))
    (if (and r (not (string=? r ""))) r
        (assertion-violation 'property "BYTE_MACHINE_SOURCE_ROOT is unset" r))))
(define ir-datum
  (call-with-input-file (string-append source-root "/byte-machine/private/ir.sls") read))
(define (sortsym l) (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) l))
(define (strip-suffix sym suf)      ; 'byte-dispatch-node? "-node?" -> 'byte-dispatch
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
;; the quoted list of `(define NAME '(…))` (diagnostic-census's defined-list shape).
(define (defined-list datum name)
  (let loop ((x datum))
    (cond ((not (pair? x)) #f)
          ((and (pair? (car x)) (eq? (caar x) 'define) (pair? (cdar x)) (eq? (cadar x) name)
                (pair? (cddar x)) (pair? (caddar x)) (eq? (car (caddar x)) 'quote))
           (cadr (caddar x)))
          (else (or (loop (car x)) (loop (cdr x)))))))
;; Walk to `(define (FN …) …)` and return the first `(memq VAR '(…))`'s list --
;; make-callback-declaration's kind guard, the closed set no other mechanism reads.
(define (memq-closed-set datum fn)
  (let ((body (let loop ((x datum))
                (cond ((not (pair? x)) #f)
                      ((and (pair? (car x)) (eq? (caar x) 'define) (pair? (cdar x)) (pair? (cadar x))
                            (eq? (car (cadar x)) fn)) (cdar x))
                      (else (or (loop (car x)) (loop (cdr x))))))))
    (and body
         (let find ((x body))
           (cond ((not (pair? x)) #f)
                 ((and (eq? (car x) 'memq) (pair? (cddr x)) (pair? (caddr x)) (eq? (car (caddr x)) 'quote))
                  (cadr (caddr x)))
                 (else (or (find (car x)) (find (cdr x)))))))))

;; ---- FIRST harness-case: run the drive, then the floor, the structural
;; equality, the per-machine agreement, and the skip sentinel that witnesses the
;; second case ran. ----
(harness-group "property.differential"
 (lambda ()
  (harness-case "accounting"
   (lambda ()
     (drive!)
     ;; Layer 1: the two lanes agree exactly, per machine. The label is per machine so a divergence names which one replays.
     (for-each
      (lambda (iv)
        (check-equal (string-append "machine " (number->string (car iv))
                                    " (seed " (number->string seed) ") byte agreement")
                     (cdr iv) 'none))
      verdicts)
     ;; Layer 3: the single-lane ORACLE over the SAME drawn trials -- kept
     ;; distinct from the agreement checks above, since a Layer-3 violation is not a
     ;; lane disagreement. One check over the accepted machines' first violations, so
     ;; each row-inversion mutation's pin reddens exactly this record and its
     ;; detail names the row. 'none unless a row's comparison is inverted.
     (check-equal "no accepted machine's trial violated a Layer-3 invariant"
                  (let scan ((vs inv-verdicts))
                    (cond ((null? vs) 'none)
                          ((not (eq? (cdar vs) 'none)) (cdar vs))
                          (else (scan (cdr vs)))))
                  'none)
     ;; the floor. It takes no EXPECT_SURVIVES: its witness is a mutant that
     ;; rejects everything.
     (check "the accepted count is at least the floor" floor-held?)
     ;; the structural equality, by COMPARISON not by a raise.
     (check-equal "no draw reached an executor unverified" fed-unverified 0)
     (check-equal "every accepted machine reached the interpreter" interpreted-count accepted-count)
     (check-equal "every accepted machine reached the generated lane" generated-count accepted-count)
     (check-equal "every draw was accounted for" (+ accepted-count rejected-count) machine-count)
     ;; loop sentinels: a literal AND a derived total; neither catches the other.
     (check-equal "the machine loop ran machine-count times" machines-loop-ran machine-count)
     (check-equal "the machine loop ran the literal count" machines-loop-ran 64)
     (check-equal "the trial pass ran over every accepted machine" trials-loop-ran accepted-count)
     ;; the SKIP SENTINEL: read from what the drive produced,
     ;; NEVER from the counter table's length, and registered in THIS case so it
     ;; fails under the floor mutant (in the second case it would be skipped by the
     ;; very condition it exists to witness).
     (check-equal "the counter pass ran over the measured accepted machines" accepted-count 41)))

  ;; ---- SECOND harness-case: the 98 counter checks, entered only when the floor
  ;; held. A rejects-everything mutant fails the floor and this case emits
  ;; NONE of the member labels, so every per-member pin resolves to one record. ----
  (harness-case "counters"
   (lambda ()
     (when floor-held?
       (let ((asserted 0))
         (for-each
          (lambda (k)
            (check (counter-agreed-label k) (counter-ref counters k 'agreed))
            (check (counter-interp-label k) (counter-ref counters k 'interp))
            (set! asserted (+ asserted 2)))
          (counter-keys))
         ;; both needed, neither catches the other: the literal catches a table
         ;; that silently shrank, the derived total a loop that stopped early.
         (check-equal "the counter pass asserted ninety-eight checks" asserted 98)
         (check-equal "and the counter table's length agrees" asserted (* 2 (length (counter-keys))))))))

  ;; ---- Layer 2/3 fixture validation. The three comparison
  ;; layers are the DRIVER's; here each is asserted as a BOOLEAN on a named fixture.
  ;; spanfull and spanbare are counted-machine's make-counted-span-machine, which
  ;; differ in exactly the completion declaration. The "1:A," one-byte span stands
  ;; in for differential-span-tests.sps's eopen/eclose pair (a span that never
  ;; straddles a boundary): that program is not a library and cannot be imported,
  ;; and a one-byte span is unsplittable by construction. ----
  (harness-case "layers"
   (lambda ()
     (define spanfull (make-counted-span-machine #t))
     (define spanbare (make-counted-span-machine #f))
     (define (interp fx) (make-interpreted-machine (verify-machine fx)))
     (define (fnames-of m) (map uint-field-name (machine-fields m)))
     (define (obs fx cm input) (observe-fixture cm (machine-callbacks fx) (fnames-of fx) input))
     (define (bs . xs) (u8-list->bytevector xs))
     (define cm-full (interp spanfull))
     (define cm-bare (interp spanbare))
     ;; Layer 2, comparator 1 (the coalescer): spanfull's 37 schedules of
     ;; "2:AB," coalesce to one span, equal? across all 37; the raw trace does not.
     (let ((rs (obs spanfull cm-full (bs 50 58 65 66 44))))
       (check-equal "spanfull drives thirty-seven schedules" (length rs) 37)
       (check-equal "the coalesced span is invariant across all thirty-seven schedules" (distinct-count (map fx-coalesced rs)) 1)
       (check "the raw fragment trace is not invariant across schedules (the negative sentinel)" (> (distinct-count (map fx-raws rs)) 1)))
     ;; Layer 2, the non-straddling case (the eopen/eclose analog): raw distinct is 1.
     (let ((rs (obs spanfull cm-full (bs 49 58 65 44))))
       (check-equal "a one-byte span never straddles a boundary" (distinct-count (map fx-raws rs)) 1))
     ;; Layer 2, comparator 3 (malformed input): the (status, absolute
     ;; offset, error-code) tuple is invariant across schedules while the callback
     ;; prefix is schedule-dependent -- both asserted, so "compare only three fields"
     ;; is a restriction that costs something.
     (let ((rs (obs spanfull cm-full (bs 51 58 65 66))))
       (check "the error tuple is invariant across schedules of a malformed input" (= 1 (distinct-count (map fx-final3 rs))))
       (check "the callback prefix is schedule-dependent (the negative sentinel)" (> (distinct-count (map fx-raws rs)) 1)))
     ;; Layer 3: check-invariants holds on both fixtures, and every row is
     ;; applicable at least once across the drive set (a valid message exercises
     ;; rows 1/2/4/5/6; a feed error "ZZ" exercises the sticky rows 1/3). spanbare's
     ;; row 6 is applicable with conjunct (iii) DROPPED (no span-complete callback).
     (check-equal "invariant-rows has six members" (length invariant-rows) 6)
     ;; first-violation captures check-invariants' own (rowN . detail), not a bare
     ;; boolean, so a row inversion caught here NAMES its row (the accepted-machine
     ;; check above may not exercise every row -- which draws reach a completing
     ;; span is seed- and draw-table-dependent -- but these fixed fixtures always
     ;; do, so every row-inversion pin has a deterministic, row-naming witness).
     (let ((covered '()) (first-violation 'none))
       (define (drive fx cm input)
         (for-each
          (lambda (r)
            (let-values (((v app) (check-invariants fx (fx-steps r) input (fx-span r))))
              (when (and (eq? first-violation 'none) (not (eq? v 'none))) (set! first-violation v))
              (for-each (lambda (row) (unless (memq row covered) (set! covered (cons row covered)))) app)))
          (obs fx cm input)))
       (drive spanfull cm-full (bs 50 58 65 66 44))
       (drive spanfull cm-full (bs 90 90))
       (drive spanbare cm-bare (bs 50 58 65 66 44))
       (check-equal "check-invariants holds on every fixture schedule" first-violation 'none)
       (for-each (lambda (row)
                   (check (string-append "layer-3 " (symbol->string row) " is applicable at least once")
                          (and (memq row covered) #t)))
                 invariant-rows)
       (check-equal "the layer-3 applicability pass covered all six rows" (length covered) 6))))

  ;; ---- the totality rows: every family the generator
  ;; draws from, and every family the driver counts, covers EXACTLY its closed set.
  ;; Five families read that set from ir.sls (node? / matcher? disjuncts, the two
  ;; field lists, make-callback-declaration's kind guard) and compare it to the
  ;; generator's DRAW TABLE; three families (callback outcomes, span events,
  ;; schedule shapes) have no source list, so the driver's own family is compared to
  ;; a DECLARED closed set. Each has a "found it" guard first: a
  ;; reader that returned #f would compare two empties and pass. ----
  (harness-case "totality"
   (lambda ()
     (let ((node-src (disjuncts-of ir-datum 'node? "-node?"))
           (matcher-src (disjuncts-of ir-datum 'matcher? "-matcher?"))
           (ops-src (defined-list ir-datum 'field-operations))
           (preds-src (defined-list ir-datum 'field-predicates))
           (cbkind-src (memq-closed-set ir-datum 'make-callback-declaration)))
       ;; found-it guards
       (check "node?'s disjunct list was found in ir.sls" (and node-src (pair? node-src)))
       (check "matcher?'s disjunct list was found in ir.sls" (and matcher-src (pair? matcher-src)))
       (check "field-operations was found in ir.sls" (and ops-src (pair? ops-src)))
       (check "field-predicates was found in ir.sls" (and preds-src (pair? preds-src)))
       (check "make-callback-declaration's kind guard was found in ir.sls" (and cbkind-src (pair? cbkind-src)))
       ;; ir.sls's closed set == the generator's draw table, and the count literal
       ;; (both needed: the set-equal catches a member swap, the count catches a
       ;; co-drift where source and table drop the same member together).
       (check-equal "the node-kind draw table covers exactly ir.sls's node? kinds" node-src (sortsym node-kind-draw-table))
       (check-equal "ir.sls declares fourteen node kinds" (length node-src) 14)
       (check-equal "the matcher draw table covers exactly ir.sls's matcher kinds" matcher-src (sortsym matcher-kind-draw-table))
       (check-equal "ir.sls declares four matcher kinds" (length matcher-src) 4)
       (check-equal "the field-operation draw table covers exactly ir.sls's field-operations" (sortsym ops-src) (sortsym field-operation-draw-table))
       (check-equal "ir.sls declares seven field operations" (length ops-src) 7)
       (check-equal "the field-predicate draw table covers exactly ir.sls's field-predicates" (sortsym preds-src) (sortsym field-predicate-draw-table))
       (check-equal "ir.sls declares seven field predicates" (length preds-src) 7)
       (check-equal "the callback-kind draw table covers exactly make-callback-declaration's kinds" (sortsym cbkind-src) (sortsym callback-kind-draw-table))
       (check-equal "ir.sls declares four callback kinds" (length cbkind-src) 4)
       ;; the three families with no source list, against a DECLARED closed set:
       (check-equal "the callback-outcome family is the four outcomes"
                    (sortsym (family-members 'callback-outcome))
                    (sortsym '(continue pause declared-branch-key explicit-failure)))
       (check-equal "the span-event family is the five events"
                    (sortsym (family-members 'span-event))
                    (sortsym '(span-open boundary-fragment end-fragment completion empty-fragment)))
       (check-equal "the schedule-shape family is the six shapes"
                    (sortsym (family-members 'schedule-shape))
                    (sortsym '(every-split-point split-point-pair random-multi-split empty-feeds nonzero-slice padded-bytevector))))))

  ;; ---- reproducibility: the same seed in two processes yields the same drawn
  ;; machines. Raised one level up from the PRNG's own reproducibility case, and compared by IR fingerprint through harness-fingerprint-*. ----
  (harness-case "reproducibility"
   (lambda ()
     ;; The generator's coverage cycles are module-level, so the draw is
     ;; reproducible ACROSS processes (each starts them at 0); a within-process
     ;; check resets to that fresh state before each draw. A fresh process is a
     ;; fresh module state, so this witnesses the two-process property.
     (define (first-draw)
       (reset-draw-state!)
       (let-values (((m mani s2) (gen-machine (make-prng seed) (property-steering))))
         (harness-fingerprint-bytevector (machine->bytes m))))
     (check "the same seed yields the same first draw" (= (first-draw) (first-draw)))))))

(harness-finish)
