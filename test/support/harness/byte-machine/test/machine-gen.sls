;;; A bounded generator of machines over EVERY §10.6 construct, for the property
;;; differential lane (parent §22.6; Milestone 7 design §4.4; decision 0033).
;;;
;;; This is the Slice ② rewrite. The Milestone-2/3/4 generator drew a single
;;; byte-dispatch entry over distinct-byte cases into a tiny fixed target
;;; vocabulary; it produced ONE construct and its acceptance was 100% by
;;; construction, which is exactly what decision 0033 item 1 removes. The draw
;;; below is a worklist over open slots that draws from all thirteen node kinds,
;;; all four matcher kinds, all seven field operations and all seven field
;;; predicates, and it is `verify-machine` -- not this file -- that decides which
;;; draws are valid. Acceptance is MEASURED (Task 2 / Task 7), not asserted.
;;;
;;; STEERING IS A PARAMETER, not baked in (design §4.6, F18). `gen-machine` takes
;;; a `steering` record. The property lane runs `property-steering`; Slice ④'s
;;; independent-oracle drive is "§4.4's generator with its structural steering
;;; off" (design §4.6), which it selects by handing a different record. Whatever
;;; the property lane steers around, the free mode still produces.
;;;
;;; THE STEERING SET, decided in Task 2 (measured through this generator's
;;; prototype, committed seed 20260823, and re-measured through this lane in
;;; Task 7), each member classified against decision 0033 item 1 by the measured
;;; discriminator "does the code it targets stay NONZERO in the rejection
;;; histogram" (a rule is validity steering when it takes its target code to
;;; zero, structural when the verifier still decides):
;;;
;;;   placed?      STRUCTURAL. A finish node is drawn only at an eof-target slot,
;;;                a stop node only at a byte-and-not-eof slot that is not a
;;;                span-end successor. §16.2:908/:909 make a uniform kind draw
;;;                unconstructible-in-context for those two kinds. Discriminator:
;;;                eof-reachable-stop survives (~85/2000 with placed on), so the
;;;                verifier still decides. Price -44.5/+22.0 pts.
;;;   back-prog?   STRUCTURAL. A back-edge is drawn only over a slot reached by
;;;                consuming a byte; a back-edge over a zero-width slot closes a
;;;                zero-progress cycle by construction. Both cycle codes stay
;;;                nonzero. Price -20.2/+2.3.
;;;   few-cases?   A BOUND, not a steering (§4.10's list): a dispatch draws 1-2
;;;                cases, not 1-4. Keeps all four matcher kinds alive. -25.6/+1.2.
;;;   entry-bd?    COVERAGE, which §4.4 presupposes: the entry is a byte dispatch,
;;;                so the 256 single-byte trials give §22.7's all-byte coverage of
;;;                the entry dispatch. Costs points in both directions (+17.1/-8.4)
;;;                and buys the entire §22.7 trial.
;;;   span-pair? + span-body?  COVERAGE, and §4.4 declares the span steering so.
;;;                A span is drawn as start -> one advancing one-case byte dispatch
;;;                carrying its OWN private EOF error node -> end. Without the body
;;;                the span covers [mark,mark), §14:834 suppresses the empty
;;;                fragment, and the span-data callback NEVER runs (measured 0 of
;;;                40) -- so decision 0033 item 2's span-event counters would read
;;;                zero forever (F5). span-body is +1.6 pts, i.e. free.
;;;   cbdefault    VALIDITY -- DECLINED (F4). Forcing an optional decision
;;;                callback's default-branch to a declared key takes
;;;                §16.2:891's invalid-callback-declaration to zero, reproducing
;;;                one layer out the very check make-callback-declaration's header
;;;                defers to the verifier. Instead `default-branch` is DRAWN from
;;;                (cons #f declared-keys) -- a draw over one slot among the values
;;;                the slot already admits (the same class as the EOF-route draw),
;;;                which leaves :891 firing whenever it lands #f on an optional
;;;                decision callback. Measured: invalid-callback-declaration stays
;;;                ~297/2000 (nonzero), and acceptance 46.1% (bare refusal) ->
;;;                51.2% (this draw) at 2000.
;;;
;;; The FLOOR is 32 (decision 0033 item 2: no lower than half of 64) -- a bound,
;;; not the measured acceptance. Measured acceptance at 64 draws under the
;;; committed seed is 33 through gen-machine alone and 36 through the lane's trial
;;; (its coverage segment lifts a few more over the verifier); both are >= 32. The
;;; floor does not measure what it is for on its own: a draw steered to a single
;;; error node per machine would clear it while every counter of item 2 read
;;; zero. What stops that is the counters (Task 7 Step 4).
;;;
;;;   dangling-prob (p) / orphan-prob (q)  The F8 draws: with probability p a
;;;                slot names a symbol that is never built (a dangling target);
;;;                with probability q an allocated node is attached to nothing (an
;;;                orphan). They WIDEN the draw (0033 item 1's permission is not
;;;                engaged) and exist to make design §4.6's :885/:887/:905/:897
;;;                rows FIRE. §4.6 is Slice ④'s section and its drive is this
;;;                generator with structural steering off, so THE PROPERTY LANE'S
;;;                VALUES ARE 0 -- they cost the acceptance gate nothing. Slice ④
;;;                inherits the chosen pair (see property-differential-tests.sps's
;;;                header / Task 12 Step 7).
;;;
;;; SEED-STABILITY DISCIPLINE (X3, inherited): every conditional draw takes the
;;; same number of values from the PRNG stream on both arms, so the state after a
;;; draw does not depend on which way it landed.
;;;
;;; NINE by-construction validity arguments the previous generator's comments
;;; named are GONE with the previous draw (H1 distinct case bytes; H2 a case
;;; targeting start forced to advance; H3 the same for pausep; H4 the first case
;;; pinned to stop; H5 reject reachable via the fixed fallback; H6 pausep added
;;; only when a case drew it; H7 done never byte-reachable; H8 pausep's
;;; continuation 'start; H9 accp's cycle-free shape). Decision 0033 and design §2
;;; count THREE; the file named nine. TWO of the nine are RE-ANCHORED rather than
;;; deleted, under `placed`, as a vocabulary per slot class: H7 (§16.2:908 holds
;;; by construction -- a finish is drawn only at an eof-target slot) and H8
;;; (§16.2:909 -- a stop is never drawn at an eof or span-end-successor slot).
;;; Measured, those two are worth ~20 points of acceptance between them.
;;;
;;; Slice ⓪ / decision 0031 made this generator's oracle STRICTER (a pure
;;; narrowing: occupiable ⊆ R_old, so unreachable-node fires on strictly more
;;; nodes; nothing became accepted). The acceptance rate Slice ② measures is
;;; measured against the stricter verifier.

(library (byte-machine test machine-gen)
  (export gen-machine
          make-steering steering? property-steering free-steering
          steering-placed? steering-back-prog? steering-few-cases?
          steering-entry-bd? steering-span-pair? steering-span-body?
          steering-fin-kind? steering-stop-on? steering-default-branch-mode
          steering-dangling-prob steering-orphan-prob steering-coverage?
          manifest? manifest-fields manifest-callbacks manifest-spans
          manifest-node-kinds manifest-key->node manifest-cb-targets
          manifest-witnesses manifest-markers manifest-script
          node-kind-draw-table matcher-kind-draw-table
          field-operation-draw-table field-predicate-draw-table
          callback-kind-draw-table
          reset-draw-state!)
  (import (rnrs)
          (byte-machine test prng)
          (byte-machine graph))

  ;; ---- The exported draw tables (F18) -----------------------------------
  ;; HAND-WRITTEN here and exported. The property program's totality rows derive
  ;; ir.sls's closed set and compare it against these keys (design §4.10's
  ;; placement, the S2 technique): if the generator drew from ir.sls's own
  ;; runtime-read list the row would compare ir.sls against ir.sls and close
  ;; nothing. A fourteenth kind in ir.sls reddens the row here.
  (define node-kind-draw-table
    '(byte-dispatch sequence-dispatch keyword-table stop error finish pause
      field-action field-branch integer-accumulate callback
      span-start span-end counted-consume))          ; 14, matches node?
  (define matcher-kind-draw-table
    '(exact-byte byte-set byte-range byte-complement)) ; 4, matches matcher?
  (define field-operation-draw-table
    '(store clear increment decrement add set-mask clear-mask))   ; 7
  (define field-predicate-draw-table
    '(equal zero nonzero range mask-any mask-all mask-none))      ; 7
  (define callback-kind-draw-table
    '(event decision span-data span-complete))         ; 4
  ;; Re-derived, because ir.sls does NOT export it (Task 6 Step 4):
  (define infallible-field-operations '(store clear set-mask clear-mask))

  ;; GLOBAL round-robin over the four vocabulary families. This is what makes the
  ;; coverage of node kinds, matcher kinds, operations and predicates satisfiable
  ;; at ANY machine count (Task 6 Step 4). A per-machine draw -- uniform OR a
  ;; per-machine round-robin phase -- leaves the committed seed's 64 machines
  ;; covering only 3-4 of 7 operations, because most machines draw at most one
  ;; field-action node, so the op it draws is a near-coin over the phase. A single
  ;; cycle that ADVANCES across every draw in the whole run instead sweeps every
  ;; member deterministically: the union over the accepted machines' field-action
  ;; nodes is a contiguous slice of the cycle, so it covers all seven as soon as
  ;; seven such nodes are drawn. It consumes NO value off the PRNG stream, so the
  ;; acceptance rate is a function of the steering and the seed alone (§4.4 says
  ;; "drawn uniformly"; Task 12 Step 1 writes this rule and its measured reason
  ;; back into it -- it changes no totality row and encodes no validity, the sets
  ;; are still read from ir.sls by the program's own rows).
  ;;
  ;; It is module-level mutable state, and that is a deliberate, documented
  ;; departure from a pure generator: it is deterministic and reproducible under
  ;; identical call order (two processes drawing the same seed call gen-machine in
  ;; the same order, so the cycles progress identically and the machines are
  ;; byte-identical -- the two-process fingerprint case relies on exactly this).
  (define rr-kind-i 0)
  (define rr-matcher-i 0)
  (define rr-op-i 0)
  (define rr-pred-i 0)
  ;; (length ...), not a hardcoded modulus: a mutation that removes a member from
  ;; a draw table (Task 10's per-kind / per-matcher pins) must leave the cycle over
  ;; the SHORTER list -- never draw the removed member and never index out of range
  ;; -- so the member's counter cleanly reads zero (caught by comparison) instead
  ;; of raising (caught by the wrong reason).
  (define (rr-kind) (let ((x (list-ref node-kind-draw-table (mod rr-kind-i (length node-kind-draw-table))))) (set! rr-kind-i (+ rr-kind-i 1)) x))
  (define (rr-matcher) (let ((x (list-ref matcher-kind-draw-table (mod rr-matcher-i (length matcher-kind-draw-table))))) (set! rr-matcher-i (+ rr-matcher-i 1)) x))
  (define (rr-op) (let ((x (list-ref field-operation-draw-table (mod rr-op-i (length field-operation-draw-table))))) (set! rr-op-i (+ rr-op-i 1)) x))
  (define (rr-pred) (let ((x (list-ref field-predicate-draw-table (mod rr-pred-i (length field-predicate-draw-table))))) (set! rr-pred-i (+ rr-pred-i 1)) x))
  ;; Reset the global cycles to their fresh-process state. The draw is reproducible
  ;; ACROSS processes because each starts these at 0 and draws in the same order;
  ;; a within-process check of that property must reset first (a fresh process is a
  ;; fresh module state). Used only by the reproducibility case.
  (define (reset-draw-state!) (set! rr-kind-i 0) (set! rr-matcher-i 0) (set! rr-op-i 0) (set! rr-pred-i 0))

  ;; ---- The steering record (F18) ----------------------------------------
  (define-record-type steering
    (fields placed? back-prog? few-cases? entry-bd? span-pair? span-body?
            fin-kind? stop-on? default-branch-mode dangling-prob orphan-prob coverage?))
  ;; The property lane: structural + coverage steering on, F8 draws off, and the
  ;; COVERAGE SEGMENT on (see build-cov-segment!): the free draw reaches spans,
  ;; pause nodes and decision-callback branches too rarely to satisfy decision
  ;; 0033 item 2 at the committed seed (measured 1 of 33 machines fires a span
  ;; fragment), so a segment woven on the entry dispatch's fallback exercises them
  ;; deterministically. It is coverage steering of the class §4.4 licenses for
  ;; spans, and §22.7's all-byte coverage of the entry dispatch is preserved
  ;; because the fallback REEXECUTES the byte into the segment.
  (define (property-steering)
    (make-steering #t #t #t #t #t #t #f #f 'draw 0 0 #t))
  ;; Slice ④'s independent-oracle drive: structural steering OFF; finish/stop
  ;; drawn uniformly (so §16.2:908/:909 fire); the F8 draws on at Task 2 Step 9's
  ;; chosen pair, 1/16 each; NO coverage segment (§4.6 measures the free draw).
  (define (free-steering)
    (make-steering #f #f #f #f #t #t #t #t 'draw 1/16 1/16 #f))

  ;; ---- The draw manifest (F18) ------------------------------------------
  ;; Everything the driver/lane needs that (byte-machine graph) will not expose,
  ;; PLUS a decoder. The manifest is a DECODER, not an observation: the trial
  ;; observes that a name was reached; the decoder only says what that name was
  ;; drawn as. It becomes the forbidden shape the moment a counter increments
  ;; without a trial having produced the name.
  (define-record-type manifest
    (fields fields         ; list of uint-field records (name + width via graph)
            callbacks      ; list of callback-declaration records
            spans          ; list of span-declaration records
            node-kinds     ; alist node-name -> kind symbol (node? disjunct stem)
            key->node      ; alist cb-node-name -> ((key . target-node-name) ...)
            cb-targets     ; alist cb-node-name -> (continue-target . pause-continuation)
            witnesses      ; alist fa-node-name -> (field-name operation initial)
            markers        ; alist fb-node-name -> (field-name predicate (arm . bits) ...)
            script))       ; alist callback-name -> list of outcomes (draw; replay only)

  ;; =======================================================================
  ;; gen-machine : (values machine manifest state)
  ;; =======================================================================
  (define (gen-machine s0 st)
    (define s s0)
    (define (d! bound) (let-values (((k s2) (prng-next s bound))) (set! s s2) k))
    (define (coin!) (= 0 (d! 2)))
    (define (chance! p)                         ; #t with probability p (p a rational in [0,1])
      ;; When p = 0 the draw does not exist in this configuration and consumes
      ;; NOTHING, so the property lane's PRNG stream matches a generator without
      ;; the F8 draws at all; when p > 0 the (d! den) always takes exactly one
      ;; value whichever way it lands (X3 seed stability).
      (and (rational? p) (> p 0)
           (let ((den (denominator p)) (num (numerator p)))
             (< (d! den) num))))
    (define (pickv! v) (vector-ref v (d! (vector-length v))))
    (define (pickl! l) (list-ref l (d! (length l))))

    ;; (The four vocabulary families draw from the module-level GLOBAL round-robin
    ;; cycles above -- rr-kind / rr-matcher / rr-op / rr-pred.)
    ;; ---- fields (the base 1-2 uint fields, §4.4) ----
    (define nfields (+ 1 (d! 2)))
    (define base-field-specs
      (let loop ((i 0) (acc '()))
        (if (= i nfields) (reverse acc)
            (loop (+ i 1)
                  (cons (list (if (= i 0) 'fa 'fb)
                              (pickv! '#(8 16 32 64))
                              (pickv! '#(0 1 25)))
                        acc)))))
    (define base-field-names (map car base-field-specs))
    (define (field-width-of specs nm)
      (cond ((null? specs) 8)
            ((eq? (caar specs) nm) (cadar specs))
            (else (field-width-of (cdr specs) nm))))
    ;; Witness / marker fields accumulate as field-action / field-branch nodes
    ;; are drawn; collected here and appended to the field list at the end.
    (define extra-field-specs '())
    (define witnesses '())          ; fa-node -> (field op initial)
    (define markers '())            ; fb-node -> (field pred (arm . bits) ...)
    (define (add-field! nm w init) (set! extra-field-specs (cons (list nm w init) extra-field-specs)))

    ;; ---- callback declarations (§4.4, F4) ----
    (define ncb (+ 1 (d! 2)))
    (define cb-specs
      (let loop ((i 0) (acc '()))
        (if (= i ncb) (reverse acc)
            (let* ((nm (if (= i 0) 'ca 'cb))
                   (kind (pickv! '#(event decision)))     ; node-invocable kinds only
                   (req (coin!))
                   (keys (if (eq? kind 'decision) (if (coin!) '(yes) '(yes no)) '()))
                   ;; F4(a): draw default-branch from (cons #f declared-keys) for
                   ;; optional decision callbacks -- one slot, values it admits.
                   (def (cond ((not (eq? kind 'decision)) #f)
                              (req #f)
                              ((eq? (steering-default-branch-mode st) 'force)
                               (car keys))                ; cbdefault (declined; here for §4.6)
                               (else (pickl! (cons #f keys))))))
              (loop (+ i 1) (cons (list nm kind req keys def) acc))))))
    (define node-cbs (filter (lambda (c) (memq (cadr c) '(event decision))) cb-specs))

    ;; ---- span declarations (§4.4): one or two; a SINGLE machine-level coin
    ;; decides the completion callback, named on every span or on none. A
    ;; span-complete declaration no span names is unreferenced-callback-declaration,
    ;; and §4.4's "in half the draws" read per span would produce exactly that
    ;; (the shipped counted-machine.sls `complete?` flag is the precedent). ----
    (define complete? (coin!))
    (define nspans (+ 1 (d! 2)))
    (define span-names (if (= nspans 1) '(sa) '(sa sb)))
    (define span-decls
      (map (lambda (nm) (make-span-declaration nm 'cd (if complete? 'cc #f) #f)) span-names))
    ;; Optional callbacks are bound in half the draws (§4.4) -- drawn per
    ;; declaration. The F4(a) default-branch is observable ONLY through the
    ;; unbound-optional-decision path, so this coin is what exercises the slot.
    (define span-data-req (coin!))
    (define span-complete-req (coin!))
    (define span-cb-decls
      (cons (make-callback-declaration 'cd 'span-data span-data-req '() #f #f)
            (if complete?
                (list (make-callback-declaration 'cc 'span-complete span-complete-req '() #f #f))
                '())))

    ;; ---- error declarations (machine default + one or two) ----
    (define extra-err? (coin!))
    (define err-decls
      (append (list (make-error-declaration 'edef 'eof "unexpected end of input" #f)
                    (make-error-declaration 'erej 'unexpected-byte "rejected" #f))
              (if extra-err?
                  (list (make-error-declaration 'eov 'unexpected-byte "field overflow" #f))
                  '())))
    (define err-names (if extra-err? '(edef erej eov) '(edef erej)))

    ;; ---- worklist machinery (ported from Task 2's prototype) ----
    (define budget 8)                   ; §4.10: node budget of eight fresh nodes
    (define counter 0)
    (define queue '())                  ; (name . class) still to build, in order
    (define scheduled '())              ; (name . class) for every allocated node
    (define built '())                  ; built node objects
    (define terms '())                  ; referenced fixed terminals
    (define node-kinds-map '())         ; name -> kind (decoder)
    (define key->node '())              ; cb-node -> ((key . target) ...)
    (define cb-targets '())             ; cb-node -> (continue . pause-continuation)
    (define (record-kind! nm k) (set! node-kinds-map (cons (cons nm k) node-kinds-map)))
    (define (use-term! t)
      (if (not (memq t terms)) (set! terms (cons t terms)))
      t)
    (define (fresh!)
      (set! counter (+ counter 1))
      (string->symbol (string-append "n" (number->string counter))))
    (define (schedule! cls)
      (let ((nm (fresh!)))
        (set! queue (append queue (list (cons nm cls))))
        (set! scheduled (cons (cons nm cls) scheduled))
        nm))
    (define (spend!) (if (> budget 0) (set! budget (- budget 1))))

    ;; A referenced fixed terminal, respecting `placed`: a finish only at an eof
    ;; slot, a stop only at a byte slot.
    (define (terminal! cls)
      (use-term!
       (if (steering-placed? st)
           (case cls ((eofonly) (pickv! '#(tfin terr)))
                     ((byte) (pickv! '#(tstop terr)))
                     (else 'terr))
           (let ((v (if (steering-stop-on? st)
                        (if (steering-fin-kind? st) '#(tstop tfin terr) '#(tstop terr))
                        (if (steering-fin-kind? st) '#(tfin terr) '#(terr)))))
             (pickv! v)))))
    ;; A back-edge only to a node of the SAME class when `placed`; joining a
    ;; byte-only node onto an EOF path is what makes :909 fire late.
    (define (back-edge cls)
      (let ((pool (if (steering-placed? st)
                      (filter (lambda (p) (eq? (cdr p) cls)) scheduled)
                      scheduled)))
        (if (pair? pool) (car (pickl! pool)) #f)))
    ;; `prog?` says whether reaching this slot consumed a byte. A back-edge over
    ;; a slot that did NOT consume closes a zero-progress cycle by construction.
    ;; The F8 dangling draw (prob p) names a symbol never built.
    (define (target* cls prog?)
      (cond ((chance! (steering-dangling-prob st)) (fresh!)) ; dangling: names nothing
            (else
             (let ((r (d! 100)))
               (cond ((and (> budget 0) (< r 55)) (spend!) (schedule! cls))
                     ((and (< r 75) (not (steering-back-prog? st))) ; back-edge unconditionally
                      (let ((b (back-edge cls))) (if b b (terminal! cls))))
                     ((and (< r 75) prog?)                          ; back-prog: only over consumed
                      (let ((b (back-edge cls))) (if b b (terminal! cls))))
                     (else (terminal! cls)))))))
    (define (target! cls) (target* cls #f))
    (define (nonterminal-target! cls)
      (cond ((> budget 0) (spend!) (schedule! cls))
            ((back-edge cls) => (lambda (b) b))
            (else (use-term! 'terr))))
    (define (eof-route!)
      (let ((r (d! 4)))
        (cond ((= r 0) #f)
              ((= r 1) (use-term! 'tfin))       ; the only accepted producer of a reachable finish
              ((= r 2) (use-term! 'terr))
              (else (let ((b (back-edge 'eofonly))) (if b b #f))))))

    ;; ---- matchers ----
    (define (simple-matcher!)
      (case (d! 3)
        ((0) (make-exact-byte-matcher (d! 256)))
        ((1) (make-byte-set-matcher (list (d! 256))))
        (else (let* ((a (d! 256)) (b (d! 256))) (make-byte-range-matcher (min a b) (max a b))))))
    (define (matcher!)
      (case (rr-matcher)
        ((exact-byte) (make-exact-byte-matcher (d! 256)))
        ((byte-set) (let ((n (+ 1 (d! 3))))
                      (make-byte-set-matcher
                       (let loop ((i 0) (acc '())) (if (= i n) acc (loop (+ i 1) (cons (d! 256) acc)))))))
        ((byte-range) (let* ((a (d! 256)) (b (d! 256))) (make-byte-range-matcher (min a b) (max a b))))
        (else (make-byte-complement-matcher (simple-matcher!)))))
    (define (operand! w) (pickv! (vector 0 1 (min 7 (- (expt 2 w) 1)))))

    ;; ---- the coverage steerings of F9 (Task 6 Step 7) ----
    ;; A witness field per drawn field-action node, its initial + operand drawn so
    ;; the operation makes a VISIBLE change (a store constant != initial, a clear
    ;; on a nonzero field, an increment below the bound, a set-mask with a bit the
    ;; value lacks, a clear-mask with a bit it has). parser-state-name never names
    ;; a zero-width node, so the FIELD value is the witness. The operand separates
    ;; a member from its siblings (the field-access-tests.sps cov-machine precedent
    ;; records mask-all 12 surviving and mask-all 14 catching).
    (define (field-action-witness! nm cls)
      (let* ((op (rr-op))
             (wf (string->symbol (string-append "w" (symbol->string nm))))
             ;; initial + args chosen per operation for a VISIBLE change: clear,
             ;; clear-mask and decrement need a nonzero start to move.
             (init (case op ((clear clear-mask decrement) 1) (else 0)))
             (args (case op
                     ((store) (list wf 3))
                     ((add) (list wf 5))
                     ((set-mask) (list wf 2))
                     ((clear-mask) (list wf 1))
                     (else (list wf)))))    ; clear (1->0), increment (0->1), decrement (1->0)
        (add-field! wf 8 init)
        (set! witnesses (cons (list nm wf op init) witnesses))
        (let ((safe (and (memq op infallible-field-operations) #t)))
          (make-field-action-node nm op args (target! cls) (if safe #f (target! cls)) #f))))

    ;; A marker field-action node on each field-branch arm writing distinct bits
    ;; into one marker field; the predicate is observed by the marker field being
    ;; nonzero (an arm ran) and the decoder giving the predicate. The operand
    ;; separates a member from its siblings (field-access-tests.sps cov-machine).
    (define (field-branch-witness! nm cls)
      (let* ((p (rr-pred))
             (mf (string->symbol (string-append "m" (symbol->string nm))))
             (f (pickl! base-field-names))
             (w (field-width-of base-field-specs f))
             (args (case p
                     ((zero nonzero) (list f))
                     ((range) (let* ((a (operand! w)) (b (operand! w))) (list f (min a b) (max a b))))
                     (else (list f (operand! w)))))
             (tnm (fresh!)) (fnm (fresh!)))
        (add-field! mf 8 0)
        ;; a marker node per arm, setting distinct bits, then continuing:
        (set! built (cons (make-field-action-node tnm 'set-mask (list mf 1) (target! cls) #f #f) built))
        (set! built (cons (make-field-action-node fnm 'set-mask (list mf 2) (target! cls) #f #f) built))
        (set! markers (cons (list nm mf p (cons 'true 1) (cons 'false 2)) markers))
        (make-field-branch-node nm p args tnm fnm #f)))

    ;; ---- per-kind construction ----
    (define (draw-byte-cases n)
      (let loop ((i 0) (acc '()))
        (if (= i n) (reverse acc)
            (let* ((m (matcher!)) (md (pickv! '#(advance reexecute))))
              (loop (+ i 1)
                    (cons (make-byte-case m (make-edge (target* 'byte (eq? md 'advance)) md) #f) acc))))))
    (define (build! nm kind cls)
      (record-kind! nm kind)
      (case kind
        ((byte-dispatch)
         (let* ((n (if (steering-few-cases? st) (+ 1 (d! 2)) (+ 1 (d! 4))))
                (cases (draw-byte-cases n)))
           (let ((fm (pickv! '#(advance reexecute))))
             (make-byte-dispatch-node nm cases
                                      (make-edge (target* 'byte (eq? fm 'advance)) fm)
                                      (eof-route!) #f))))
        ((sequence-dispatch)
         (let* ((n (+ 1 (d! 3)))
                (cases (let loop ((i 0) (acc '()))
                         (if (= i n) (reverse acc)
                             (let* ((len (+ 1 (d! 3)))
                                    (bs (let bl ((j 0) (b '())) (if (= j len) (reverse b) (bl (+ j 1) (cons (d! 256) b))))))
                               (loop (+ i 1) (cons (make-sequence-case bs (target* 'byte #t) #f) acc)))))))
           (let ((mm (pickv! '#(advance reexecute))))
             (make-sequence-dispatch-node nm cases
                                          (make-edge (target* 'byte (eq? mm 'advance)) mm)
                                          (eof-route!) #f))))
        ;; Keyword table: like a sequence, random byte-list entries -- proper
        ;; prefixes and exact duplicates both arise and the verifier decides
        ;; (prefixes accepted, duplicates rejected), so the differential covers
        ;; both. `case-insensitive?` is #f here so the machine-drawing PRNG stream
        ;; is unperturbed; the CI fold is exercised by the dedicated keyword-table
        ;; lane (decision 0045).
        ((keyword-table)
         (let* ((n (+ 1 (d! 3)))
                (entries (let loop ((i 0) (acc '()))
                           (if (= i n) (reverse acc)
                               (let* ((len (+ 1 (d! 3)))
                                      (bs (let bl ((j 0) (b '()))
                                            (if (= j len) (reverse b) (bl (+ j 1) (cons (d! 256) b))))))
                                 (loop (+ i 1)
                                       (cons (make-keyword-entry bs (target* 'byte #t) #f) acc)))))))
           (let ((nmm (pickv! '#(advance reexecute))))
             (make-keyword-table-node nm entries
                                      (make-edge (target* 'byte (eq? nmm 'advance)) nmm)
                                      (eof-route!) #f #f))))
        ((stop) (make-stop-node nm #f))
        ((error) (make-error-node nm (pickl! err-names) #f))
        ((finish) (make-finish-node nm #f))
        ((pause) (make-pause-node nm (target! 'both) #f))
        ((field-action) (field-action-witness! nm cls))
        ((field-branch) (field-branch-witness! nm cls))
        ((integer-accumulate)
         (let ((nd (pickv! '#(advance reexecute)))
               (f (pickl! base-field-names)))
           (make-integer-accumulate-node nm f (pickv! '#(10 16))
                                         (target* 'byte #t)
                                         (make-edge (target* 'byte (eq? nd 'advance)) nd)
                                         (target* 'byte #f) (eof-route!) #f)))
        ((callback)
         (let ((c (if (pair? node-cbs) (pickl! node-cbs) #f)))
           (if (not c)
               (begin (record-kind! nm 'error) (make-error-node nm (pickl! err-names) #f))
               (let* ((cont (target! 'byte))
                      (pause-cont (target! 'both))
                      (branch (map (lambda (k) (list k (target! 'byte))) (cadddr c))))
                 (set! key->node (cons (cons nm (map (lambda (b) (cons (car b) (cadr b))) branch)) key->node))
                 (set! cb-targets (cons (cons nm (cons cont pause-cont)) cb-targets))
                 (make-callback-node nm (car c) cont branch pause-cont #f)))))
        ((span-start)
         (let ((sp (pickl! span-names)))
           (cond
            ((steering-span-body? st)
             ;; start -> a one-case advancing byte dispatch carrying its OWN
             ;; private EOF error node -> end. The body's EOF route is its own
             ;; truncation node: a shared sink joins `none` with (active s), and
             ;; pass 7 rejects one node carrying both states (counted-machine.sls's
             ;; precedent). §4.4's "private error sink" names a slot
             ;; make-span-end-node does NOT have (F6) -- the sink belongs on the
             ;; body node, which is the only node in the construct with an
             ;; eof-target, and §4.4's own decision-0029 warrant already implies it.
             (let* ((bodynm (begin (spend!) (fresh!)))
                    (endnm (begin (spend!) (fresh!)))
                    (truncnm (begin (spend!) (fresh!))))
               (set! scheduled (cons (cons endnm cls) scheduled))
               (record-kind! endnm 'span-end)
               (record-kind! bodynm 'byte-dispatch)
               (record-kind! truncnm 'error)
               (set! built (cons (make-span-end-node endnm sp (nonterminal-target! 'both) #f) built))
               (set! built (cons (make-error-node truncnm (car err-names) #f) built))
               (set! built (cons (make-byte-dispatch-node bodynm
                                   (list (make-byte-case (make-byte-range-matcher 0 255) (make-edge endnm 'advance) #f))
                                   (make-edge endnm 'advance) truncnm #f) built))
               (make-span-start-node nm sp bodynm #f)))
            ((steering-span-pair? st)
             (let ((endnm (begin (spend!) (fresh!))))
               (set! scheduled (cons (cons endnm cls) scheduled))
               (record-kind! endnm 'span-end)
               (set! built (cons (make-span-end-node endnm sp (nonterminal-target! 'both) #f) built))
               (make-span-start-node nm sp endnm #f)))
            (else (make-span-start-node nm sp (target! cls) #f)))))
        ((span-end)
         ;; A bare span-end draw is turned into a start/(body)/end pair too, so a
         ;; span-end is never emitted without a matching start (pass 7 rejects a
         ;; lone end).
         (if (or (steering-span-pair? st) (steering-span-body? st))
             (build! nm 'span-start cls)
             (make-span-end-node nm (pickl! span-names) (target! 'both) #f)))
        ((counted-consume)
         (make-counted-consume-node nm (pickl! base-field-names) (target! 'byte) (eof-route!) #f))
        (else (assertion-violation 'build! "unknown kind" kind))))

    (define (suppressed? k cls)
      (if (steering-placed? st)
          (or (and (eq? k 'finish) (not (eq? cls 'eofonly)))
              (and (eq? k 'stop) (not (eq? cls 'byte))))
          (or (and (eq? k 'finish) (not (steering-fin-kind? st)))
              (and (eq? k 'stop) (not (steering-stop-on? st))))))
    (define (draw-kind! cls)
      (let loop ((tries 0))
        (let ((k (rr-kind)))
          (cond ((not (suppressed? k cls)) k)
                ((< tries 20) (loop (+ tries 1)))
                (else 'error)))))

    ;; The coverage segment's gating (each stage present iff its kind is in the
    ;; draw table) and the name the entry dispatch's fallback routes to. Computed
    ;; up front so build-entry! can reference it; the nodes are built at the tail.
    (define (kind-drawn? k) (and (memq k node-kind-draw-table) #t))
    (define cov-span? (and (steering-coverage? st) (kind-drawn? 'span-start)))
    (define cov-pause? (and (steering-coverage? st) (kind-drawn? 'pause)))
    (define cov-cb? (and (steering-coverage? st) (kind-drawn? 'callback)))
    (define cov-acc? (and (steering-coverage? st) (kind-drawn? 'integer-accumulate)))
    (define seg-entry-name
      (cond ((not (steering-coverage? st)) #f)
            (cov-acc? 'covacc) (cov-span? 'covx1) (cov-pause? 'covx5) (cov-cb? 'covx6) (else 'covx9)))
    ;; The matcher coverage: a PEEK dispatch (covmd) with one non-overlapping case
    ;; per matcher kind in the draw table -- exact 65, set {66,67}, range [68,70],
    ;; and complement of {65..70} (everything else). All cases REEXECUTE, so the
    ;; byte is re-presented to the free entry (§22.7 preserved) and covmd only
    ;; observes which matcher kind a byte fired. Gated per matcher: removing a
    ;; matcher from matcher-kind-draw-table drops its case, its bytes fall through
    ;; to the (reexecuting) fallback, and observe never sees that kind -- so the
    ;; matcher counter reads zero cleanly, without the fragile free draw shifting a
    ;; different counter. Without it, the coverage span bodies' fixed range matchers
    ;; leave byte-range always observed and matcher removals uncatchable.
    (define cov-matchers
      (if (steering-coverage? st)
          (filter values
            (list (and (memq 'exact-byte matcher-kind-draw-table) (cons 'exact-byte (make-exact-byte-matcher 65)))
                  (and (memq 'byte-set matcher-kind-draw-table) (cons 'byte-set (make-byte-set-matcher '(66 67))))
                  (and (memq 'byte-range matcher-kind-draw-table) (cons 'byte-range (make-byte-range-matcher 68 70)))
                  (and (memq 'byte-complement matcher-kind-draw-table)
                       (cons 'byte-complement (make-byte-complement-matcher (make-byte-set-matcher '(65 66 67 68 69 70)))))))
          '()))
    (define cov-matcher? (and (steering-coverage? st) (pair? cov-matchers)))
    ;; The entry dispatch, whose fallback routes into the coverage segment
    ;; (reexecute, so §22.7's all-byte coverage of the entry dispatch is preserved
    ;; -- the byte is re-presented to the segment, not consumed here).
    (define (build-entry! nm cls)
      (record-kind! nm 'byte-dispatch)
      (let* ((n (if (steering-few-cases? st) (+ 1 (d! 2)) (+ 1 (d! 4))))
             (cases (draw-byte-cases n))
             (fb (if (steering-coverage? st)
                     (make-edge seg-entry-name 'reexecute)
                     (let ((fm (pickv! '#(advance reexecute)))) (make-edge (target* 'byte (eq? fm 'advance)) fm)))))
        (make-byte-dispatch-node nm cases fb (eof-route!) #f)))
    ;; §16.2's census flags machine-entry an EOF position: an empty feed reaches it.
    (let ((entry (schedule! 'both)))
      (let loop ((first #t))
        (if (null? queue) #t
            (let* ((p (car queue)) (nm (car p)) (cls (cdr p)))
              (set! queue (cdr queue))
              (set! built (cons (if (and first (steering-entry-bd? st))
                                    (build-entry! nm cls)
                                    (build! nm (draw-kind! cls) cls))
                                built))
              (loop #f))))
      ;; The F8 orphan draw (prob q): with probability q an already-allocated node
      ;; is attached to nothing -- an extra node referenced by no slot. In the
      ;; property lane q = 0.
      (when (chance! (steering-orphan-prob st))
        (let ((onm (fresh!)))
          (record-kind! onm 'stop)
          (set! built (cons (make-stop-node onm #f) built))))
      ;; The coverage prefix (F9 / Task 6 Step 7). Every machine BEGINS with a
      ;; field-action node (cova) and a field-branch node (covb), so EVERY accepted
      ;; machine observes exactly one field operation and one field predicate,
      ;; globally cycled. parser-state-name never names a zero-width node, so the
      ;; witness is the FIELD value (the operation's visible change on cova's own
      ;; witness field) and the MARKER field (an arm of covb ran). Without it a
      ;; member drawn only into rejected machines reads zero forever (measured:
      ;; clear-mask 0 of 5 accepted at 64 with a free draw alone). The prefix is a
      ;; chain of zero-width nodes to the free entry's dispatch, so §22.7's all-byte
      ;; coverage of that dispatch is preserved and no zero-progress CYCLE forms
      ;; (it is acyclic). The operand separates a member from its siblings.
      (let* ((op (rr-op))
             (cov-init (case op ((clear clear-mask decrement) 1) (else 0)))
             (cov-args (case op ((store) (list 'covw 3)) ((add) (list 'covw 5))
                                ((set-mask) (list 'covw 2)) ((clear-mask) (list 'covw 1))
                                (else (list 'covw))))
             (cov-safe (and (memq op infallible-field-operations) #t))
             (pred (rr-pred))
             (pf (car base-field-names))
             (pw (field-width-of base-field-specs pf))
             (pred-args (case pred
                          ((zero nonzero) (list pf))
                          ((range) (let* ((a (operand! pw)) (b (operand! pw))) (list pf (min a b) (max a b))))
                          (else (list pf (operand! pw))))))
        (add-field! 'covw 8 cov-init)
        (add-field! 'covm 8 0)
        (set! witnesses (cons (list 'cova 'covw op cov-init) witnesses))
        (set! markers (cons (list 'covb 'covm pred (cons 'true 1) (cons 'false 2)) markers))
        (record-kind! 'cova 'field-action)
        (record-kind! 'covb 'field-branch)
        ;; The markers route to the matcher peek dispatch covmd (which reexecutes
        ;; on to the free entry), or straight to the free entry if matcher coverage
        ;; is off. covmd's cases all reexecute, so the byte reaches the free entry.
        (let ((post-marker (if cov-matcher? 'covmd entry)))
          (set! built (cons (make-field-action-node 'covmt 'set-mask (list 'covm 1) post-marker #f #f) built))
          (set! built (cons (make-field-action-node 'covmf 'set-mask (list 'covm 2) post-marker #f #f) built)))
        (set! built (cons (make-field-branch-node 'covb pred pred-args 'covmt 'covmf #f) built))
        (set! built (cons (make-field-action-node 'cova op cov-args 'covb (if cov-safe #f 'covb) #f) built))
        (when cov-matcher?
          (record-kind! 'covmd 'byte-dispatch)
          (set! built (cons (make-byte-dispatch-node 'covmd
                             (map (lambda (km) (make-byte-case (cdr km) (make-edge entry 'reexecute) #f)) cov-matchers)
                             (make-edge entry 'reexecute) #f #f) built))))
      ;; The coverage SEGMENT (Task 6 Steps 6-8). Reached from the entry dispatch's
      ;; fallback (reexecute), so on most bytes the parser runs: covx1 opens span
      ;; covx -> covx2/covx3 consume two bytes (covx3 PARKS with the span open after
      ;; one byte -> span-open observed) -> covx4 closes covx (boundary + end
      ;; fragments) -> covx5 pauses (node kind pause) -> covx6 a decision callback
      ;; whose script the driver cycles (cb-continue / -pause / -declared-branch-key
      ;; / -explicit-failure) -> covx7/covx8 an EMPTY span covy (suppressed-empty
      ;; completion) -> covx9 consumes and routes to the error terminal. The free
      ;; draw reaches spans/pauses/branches too rarely to satisfy 0033 item 2 at the
      ;; committed seed, so this segment exercises them deterministically. It is
      ;; coverage steering of the class §4.4 licenses. covxt is the span body's OWN
      ;; EOF sink (F6: a shared sink joins none with (active s)).
      ;; Each stage of the segment is GATED on its kind's membership in
      ;; node-kind-draw-table, and the stages are chained tail-first so a removed
      ;; stage is rerouted around. This is what makes the "remove kind K from the
      ;; draw table" mutation zero K's counter: with the stage gated, both the free
      ;; draw (rr-kind, which reads the same table) AND the coverage segment stop
      ;; producing K, so the counter reads zero and the pin catches. A normal run
      ;; has every kind in the table, so every stage is present and coverage holds.
      (when (steering-coverage? st)
              (use-term! 'terr)
              (record-kind! 'covx9 'byte-dispatch)
              (set! built (cons (make-byte-dispatch-node 'covx9 (list (make-byte-case (make-byte-range-matcher 0 255) (make-edge 'terr 'advance) #f)) (make-edge 'terr 'advance) 'terr #f) built))
              (let* ((nxt 'covx9)
                     (nxt (if cov-span?      ; empty span covy -> suppressed-empty
                              (begin (record-kind! 'covx7 'span-start) (record-kind! 'covx8 'span-end)
                                     (set! built (cons (make-span-end-node 'covx8 'covy nxt #f) built))
                                     (set! built (cons (make-span-start-node 'covx7 'covy 'covx8 #f) built))
                                     'covx7) nxt))
                     (nxt (if cov-cb?        ; a decision callback (scripted outcomes)
                              (begin (record-kind! 'covx6 'callback)
                                     (set! key->node (cons (cons 'covx6 (list (cons 'yes nxt) (cons 'no nxt))) key->node))
                                     (set! cb-targets (cons (cons 'covx6 (cons nxt nxt)) cb-targets))
                                     (set! built (cons (make-callback-node 'covx6 'covdec nxt (list (list 'yes nxt) (list 'no nxt)) nxt #f) built))
                                     'covx6) nxt))
                     (nxt (if cov-pause?     ; a pause node
                              (begin (record-kind! 'covx5 'pause)
                                     (set! built (cons (make-pause-node 'covx5 nxt #f) built))
                                     'covx5) nxt))
                     (nxt (if cov-span?      ; the consuming span covx: open -> 2-byte body -> close
                              (begin (record-kind! 'covx1 'span-start) (record-kind! 'covx2 'byte-dispatch)
                                     (record-kind! 'covx3 'byte-dispatch) (record-kind! 'covxt 'error) (record-kind! 'covx4 'span-end)
                                     (set! built (cons (make-span-end-node 'covx4 'covx nxt #f) built))
                                     (set! built (cons (make-error-node 'covxt 'edef #f) built))
                                     (set! built (cons (make-byte-dispatch-node 'covx3 (list (make-byte-case (make-byte-range-matcher 0 255) (make-edge 'covx4 'advance) #f)) (make-edge 'covx4 'advance) 'covxt #f) built))
                                     (set! built (cons (make-byte-dispatch-node 'covx2 (list (make-byte-case (make-byte-range-matcher 0 255) (make-edge 'covx3 'advance) #f)) (make-edge 'covx3 'advance) 'covxt #f) built))
                                     (set! built (cons (make-span-start-node 'covx1 'covx 'covx2 #f) built))
                                     'covx1) nxt))
                     (nxt (if cov-acc?       ; a coverage accumulate: a digit byte on
                                             ; the fallback path commits (covaf 0 -> d);
                                             ; consecutive digits overflow -> covaov.
                                             ; Non-digit bytes reexecute on to the span.
                              (begin (record-kind! 'covacc 'integer-accumulate) (record-kind! 'covaov 'error)
                                     (add-field! 'covaf 8 0)
                                     (set! built (cons (make-error-node 'covaov 'edef #f) built))
                                     (set! built (cons (make-integer-accumulate-node 'covacc 'covaf 10 'covacc
                                                        (make-edge nxt 'reexecute) 'covaov nxt #f) built))
                                     'covacc) nxt)))
                nxt))
      (let* ((cov-span-decls (if cov-span?
                                 (list (make-span-declaration 'covx 'covd 'covc #f)
                                       (make-span-declaration 'covy 'covd 'covc #f)) '()))
             (cov-cb-decls (append (if cov-span?
                                       (list (make-callback-declaration 'covd 'span-data #t '() #f #f)
                                             (make-callback-declaration 'covc 'span-complete #t '() #f #f)) '())
                                   (if cov-cb?
                                       (list (make-callback-declaration 'covdec 'decision #t '(yes no) #f #f)) '())))
             (term-nodes
              (map (lambda (t)
                     (case t
                       ((tstop) (make-stop-node 'tstop #f))
                       ((tfin) (make-finish-node 'tfin #f))
                       (else (make-error-node 'terr 'erej #f))))
                   terms))
             (all-field-specs (append base-field-specs (reverse extra-field-specs)))
             (all-cb-decls (append (map (lambda (c)
                                          (make-callback-declaration (car c) (cadr c) (caddr c)
                                                                     (cadddr c) (car (cddddr c)) #f))
                                        cb-specs)
                                   span-cb-decls cov-cb-decls))
             (all-span-decls (append span-decls cov-span-decls))
             (m (make-machine 'gen 'cova
                              (map (lambda (f) (make-uint-field (car f) (cadr f) (caddr f) #f)) all-field-specs)
                              all-cb-decls all-span-decls err-decls
                              (append (reverse built) term-nodes)
                              'edef #f))
             (mani (make-manifest
                    (map (lambda (f) (make-uint-field (car f) (cadr f) (caddr f) #f)) all-field-specs)
                    all-cb-decls
                    all-span-decls
                    node-kinds-map
                    key->node
                    cb-targets
                    (reverse witnesses)
                    (reverse markers)
                    '())))          ; script: filled by the driver per trial
        (values m mani s)))))
