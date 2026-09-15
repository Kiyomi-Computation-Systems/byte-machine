;;; The property differential DRIVER (Milestone 7 Slice ②; design §4.3/§4.4/§7).
;;;
;;; A FUNCTIONAL CORE (F18): it returns values and asserts NOTHING -- no `check`,
;;; no harness import. The property lane asserts over 64 machines and 96 counters;
;;; Slice ③'s fixture asserts one trial; the minimizer asserts nothing and needs a
;;; boolean oracle. All three read THIS library, so the disagreement rule, the
;;; "at most once per machine" rule and the counters live here, not in the lane.
;;; The one seam that does I/O is `emit-and-load` in the LANE (and, in Slice ③,
;;; the saver); the compiled machines are handed to run-machine.
;;;
;;; THE BLIND SPOT (Task 5 Step 5 / Task 7 Step 8): all three layers are blind to
;;; an agreed-wrong value that satisfies every invariant, and one is in the tree
;;; today -- §12.7:770's zero-width-machine-action half, the position kind of a
;;; FAILED zero-width action reached over a REEXECUTE edge, which the row fixes at
;;; `boundary` and which BOTH lanes report as `byte`. This generator draws that
;;; shape and drives it many times per seed set; every trial passes, because Layers
;;; 1 and 2 compare the lanes against each other (they agree) and Layer 3 reads
;;; statuses, cursors, offsets, fields and span bytes and NO position kind. Drawing
;;; the shape does not make this slice the receiver: the receivers are compile.sls's
;;; field-action arm and interpret.sls's field-step (design §4.11 item 7), and
;;; §4.9's gate proves this slice touched neither.
;;;
;;; THE PAUSE PROTOCOL'S GUARD is the rule that turns a bug into a crash: resume is
;;; reached only once BOTH sides agree they paused. A driver that resumes on
;;; `(or ref-paused? gen-paused?)` converts every lane divergence at a pause into a
;;; lifecycle-violation raise (measured on a first prototype: 941 raises over 10240
;;; trials). ~9% of single-byte trials on freely drawn machines end paused.
;;;
;;; ONE recording closure per lane, never shared (a shared closure yields one
;;; interleaved list with nothing to compare it to). A fragment is copied inside
;;; the callback's dynamic extent (§13:799): the trace is fresh bytevectors.

(library (byte-machine test property-driver)
  (export schedules-for schedules-per-input
          run-machine run-machine-verdict run-one-trial
          fixture-text minimize machine-node-count
          make-counter-set observe-counters counter-ref counter-keys counter-labels family-members
          counter-agreed-label counter-interp-label
          make-rejection* rejection? rejection-index rejection-machine
          rejection-diagnostics rejection-codes rejection-code-sites
          disagreement->detail
          coalesce-fragments distinct distinct-count
          observe-fixture fx-steps fx-coalesced fx-cbtrace fx-raws fx-span fx-final3
          check-invariants invariant-rows)
  (import (rnrs)
          (rnrs mutable-pairs)
          (only (chezscheme) load)
          (rnrs eval)
          (byte-machine graph)
          (byte-machine verify)
          (byte-machine interpret)
          (byte-machine compile)
          (byte-machine runtime)
          (byte-machine private ir)
          (byte-machine private conditions)
          (byte-machine test error-projection)
          (byte-machine test rejection-ledger)
          (byte-machine test prng)
          (byte-machine test machine-gen))

  ;; ============ 1. The schedule alphabet (§22.5:1278-1283) ====================
  (define (schedule-whole bv) (list (list (list bv 0 (bytevector-length bv)))))
  (define (schedule-splits bv)
    (let ((len (bytevector-length bv)))
      (let loop ((k 0) (acc '()))
        (if (> k len) (reverse acc)
            (loop (+ k 1) (cons (list (list bv 0 k) (list bv k len)) acc))))))
  (define (schedule-pairs bv)
    (let ((len (bytevector-length bv)))
      (let outer ((i 0) (acc '()))
        (if (> i len) (reverse acc)
            (outer (+ i 1)
                   (let inner ((j i) (a acc))
                     (if (> j len) a
                         (inner (+ j 1)
                                (cons (list (list bv 0 i) (list bv i j) (list bv j len)) a)))))))))
  (define (schedule-empties bv)
    (let* ((len (bytevector-length bv)) (nothing (make-bytevector 0)) (mid (div len 2)))
      (list (list (list nothing 0 0) (list bv 0 len))
            (list (list bv 0 mid) (list nothing 0 0) (list bv mid len))
            (list (list bv 0 len) (list nothing 0 0)))))
  (define (schedule-sub-slice bv)
    (let* ((len (bytevector-length bv)) (mid (div len 2)))
      (list (list (list bv 0 mid) (list bv mid mid) (list bv mid len)))))
  (define (schedule-padded bv)
    (let* ((len (bytevector-length bv)) (padded (make-bytevector (+ len 3) 200)))
      (do ((i 0 (+ i 1))) ((= i len)) (bytevector-u8-set! padded (+ i 2) (bytevector-u8-ref bv i)))
      (list (list (list padded 2 (+ 2 len))))))
  (define (schedule-multi-split bv state)
    (let ((len (bytevector-length bv)))
      (let loop ((n 0) (s state) (acc '()))
        (if (= n 4) (values (reverse acc) s)
            (let-values (((cuts s2) (draw-cuts len s)))
              (loop (+ n 1) s2 (cons (cuts->schedule bv len cuts) acc)))))))
  (define (draw-cuts len s)
    (let loop ((i 1) (s s) (acc '()))
      (if (>= i len) (values (reverse acc) s)
          (let-values (((k s2) (prng-next s 2)))
            (loop (+ i 1) s2 (if (= k 1) (cons i acc) acc))))))
  (define (cuts->schedule bv len cuts)
    (let loop ((start 0) (cs (append cuts (list len))) (acc '()))
      (if (null? cs) (reverse acc)
          (loop (car cs) (cdr cs) (cons (list bv start (car cs)) acc)))))
  (define (schedules-for bv state)
    (let-values (((multi s2) (schedule-multi-split bv state)))
      (values (append (schedule-splits bv) (schedule-pairs bv)
                      (schedule-whole bv) (schedule-empties bv)
                      (schedule-sub-slice bv) (schedule-padded bv) multi)
              s2)))
  ;; (L+1) splits + (L+1)(L+2)/2 pairs + 10 others (1 whole + 3 empties + 1
  ;; sub-slice + 1 padded + 4 multi), reproducing the three shipped triples:
  ;; span (L=5) 6+21+10=37, callback (L=4) 5+15+10=30, counted-span (L=6) 7+28+10=45.
  (define (schedules-per-input len)
    (+ (+ len 1) (div (* (+ len 1) (+ len 2)) 2) 10))

  ;; ============ 2. The Layer-1 tuple (§22.4:1264-1272 + §22.5:1285) ===========
  ;; All nine members: status, next/consumed, offset, error projection (NOT
  ;; narrowed -- the assumption the defect broke), final state name AND fields
  ;; (:1267), and parser-active-span (decision 0028's warrant).
  (define (rfields r p fnames)
    (list (parser-result-status r)
          (parser-result-next r)
          (parser-result-consumed r)
          (parser-result-stream-offset r)
          (let ((e (parser-result-error r))) (if e (project-error e) #f))
          (parser-state-name p)
          (parser-active-span p)
          (map (lambda (nm) (parser-field-ref p nm)) fnames)))
  (define (tup-status t) (car t))
  (define (tup-next t) (cadr t))
  (define (tup-consumed t) (caddr t))
  (define (tup-offset t) (list-ref t 3))
  (define (tup-error t) (list-ref t 4))
  (define (tup-state t) (list-ref t 5))
  (define (tup-span t) (list-ref t 6))
  (define (tup-fields t) (list-ref t 7))

  ;; ============ 3. The trial ==================================================
  ;; A lane: its parser, the Layer-1/2 data trace (fresh fragments + 'complete),
  ;; the callback-answer trace, and a RICH span trace for Layer 3 row 6 (each
  ;; fragment tagged with ABSOLUTE offsets and each completion with the stream
  ;; offset read inside the callback). One recorder per lane; a per-feed CTX box
  ;; (offset-before . feed-start | #f during finish) lets the data callback
  ;; re-anchor its SLICE offsets to absolute ones (§14:833, the driver's own
  ;; bookkeeping -- there is no public observation of a span's start offset).
  (define-record-type lane (fields parser dreader creader sreader ctx))
  (define (open-lane cm cbs bound script-alist)
    (let ((box (list (map (lambda (c) (cons (car c) (cdr c))) script-alist)))  ; per-lane script copy
          (dtrace '()) (cbtrace '()) (strace '()) (ctx (list #f)))
      (define (data-cb ps ux bv from to)
        (let ((frag (make-bytevector (- to from))))
          (do ((i from (+ i 1)) (j 0 (+ j 1))) ((= i to)) (bytevector-u8-set! frag j (bytevector-u8-ref bv i)))
          (set! dtrace (cons frag dtrace))
          (let ((c (car ctx)))                 ; abs = offset-before + (slice-off - feed-start)
            (let ((af (if c (+ (car c) (- from (cdr c))) from))
                  (at (if c (+ (car c) (- to (cdr c))) to)))
              ;; tag with the ACTIVE span (§13:799 -- the span is open inside its own
              ;; data callback), so row 6 can judge completion PER SPAN: one machine
              ;; may carry spans with a completion callback and spans without.
              (set! strace (cons (list 'frag af at frag (parser-active-span ps)) strace)))))
        callback-continue)
      (define (complete-cb ps ux)
        (set! dtrace (cons 'complete dtrace))
        (set! strace (cons (list 'complete (parser-stream-offset ps)) strace))  ; §14:831 end anchor
        callback-continue)
      (define (node-cb-for name)
        (lambda (ps ux)
          (let ((ans (script-answer box name)))
            (set! cbtrace (cons (list name (parser-state-name ps) (parser-stream-offset ps) ans) cbtrace))
            (cond ((eq? ans 'pause) callback-pause)
                  ((eq? ans 'continue) callback-continue)
                  ((symbol? ans) ans)                            ; a declared branch key
                  ((pair? ans) (make-callback-failure (car ans) (cdr ans)))
                  (else callback-continue)))))
      (make-lane (build-parser cm cbs bound data-cb complete-cb node-cb-for)
                 (lambda () (reverse dtrace)) (lambda () (reverse cbtrace))
                 (lambda () (reverse strace)) ctx)))
  (define (script-answer box name)
    (let ((cell (assq name (car box))))
      (if (and cell (pair? (cdr cell)))
          (let ((a (cadr cell))) (set-cdr! cell (cddr cell)) a)
          'continue)))
  ;; `cbs` is a list of callback-declaration records (a manifest's or a machine's).
  (define (build-parser cm cbs bound data-cb complete-cb node-cb-for)
    (make-parser cm
      (append
       (map (lambda (cd) (list (callback-declaration-name cd) (node-cb-for (callback-declaration-name cd))))
            (cbs-of cbs '(event decision) bound))
       (map (lambda (cd) (list (callback-declaration-name cd) data-cb)) (cbs-of cbs '(span-data) bound))
       (map (lambda (cd) (list (callback-declaration-name cd) complete-cb)) (cbs-of cbs '(span-complete) bound)))
      #f))
  (define (cbs-of cbs kinds bound)
    (filter (lambda (cd) (and (memq (callback-declaration-kind cd) kinds)
                              (memq (callback-declaration-name cd) bound)))
            cbs))

  ;; A recorded step: the operation that produced it (feed | finish), the slice
  ;; START it was fed at (#f for finish), the lifecycle BEFORE the call, and the
  ;; Layer-1 tuple. Layers 1/2 and the counters read only the tuple; Layer 3 reads
  ;; the op/start/life too. op/start/life are identical across lanes by
  ;; construction (same schedule, same calls), so Layer 1 compares only the tuple.
  (define (mk-step op start life tuple) (vector op start life tuple))
  (define (step-op s) (vector-ref s 0))
  (define (step-start s) (vector-ref s 1))
  (define (step-life s) (vector-ref s 2))
  (define (step-tuple s) (vector-ref s 3))

  ;; The pause protocol: resume only once BOTH sides agree paused. Single resume
  ;; site (Pass 39 LABEL 2's re-anchor target; the SITES constraint of F17(c)).
  ;; Records a step per call. Returns (values steps-r steps-g bad).
  (define (feed-loop! rl gl bv start end fnames sr sg)
    (let ((pr (lane-parser rl)) (pg (lane-parser gl)))
      (let ((lr (parser-lifecycle pr)) (lg (parser-lifecycle pg)))
        (set-car! (lane-ctx rl) (cons (parser-stream-offset pr) start))
        (set-car! (lane-ctx gl) (cons (parser-stream-offset pg) start))
        (let ((rr (parser-feed! pr bv start end)) (rg (parser-feed! pg bv start end)))
          (let ((fr (rfields rr pr fnames)) (fg (rfields rg pg fnames)))
            (let ((sr2 (cons (mk-step 'feed start lr fr) sr)) (sg2 (cons (mk-step 'feed start lg fg) sg)))
              (cond
               ((not (equal? fr fg)) (values sr2 sg2 (list 'feed start)))
               ((and (eq? (car fr) 'paused) (eq? (car fg) 'paused))
                (let ((acks (resume-pair! pr pg)))
                  (if (not (equal? (car acks) (cadr acks)))
                      (values sr2 sg2 (list 'feed-ack start))
                      (feed-loop! rl gl bv (cadr fr) end fnames sr2 sg2))))
               (else (values sr2 sg2 'none)))))))))
  (define (resume-pair! pr pg) (list (parser-resume! pr) (parser-resume! pg)))
  (define (finish-loop! rl gl fnames sr sg)
    (let ((pr (lane-parser rl)) (pg (lane-parser gl)))
      (set-car! (lane-ctx rl) #f) (set-car! (lane-ctx gl) #f)
      (let ((lr (parser-lifecycle pr)) (lg (parser-lifecycle pg)))
        (let ((rr (parser-finish! pr)) (rg (parser-finish! pg)))
          (let ((fr (rfields rr pr fnames)) (fg (rfields rg pg fnames)))
            (let ((sr2 (cons (mk-step 'finish #f lr fr) sr)) (sg2 (cons (mk-step 'finish #f lg fg) sg)))
              (cond
               ((not (equal? fr fg)) (values sr2 sg2 (list 'finish)))
               ((and (eq? (car fr) 'paused) (eq? (car fg) 'paused))
                (let ((acks (resume-pair! pr pg)))
                  (if (not (equal? (car acks) (cadr acks)))
                      (values sr2 sg2 (list 'finish-ack))
                      (finish-loop! rl gl fnames sr2 sg2))))
               (else (values sr2 sg2 'none)))))))))

  ;; Run one schedule on a fresh lane pair. A pair already at stopped/error is
  ;; deliberately not finished (the sticky lifecycle short-circuits in the shared
  ;; wrapper before reaching either executor). Returns (values rl gl steps-r steps-g bad).
  (define (run-schedule ref-cm gen-cm cbs schedule fnames bound script)
    (let ((rl (open-lane ref-cm cbs bound script))
          (gl (open-lane gen-cm cbs bound script)))
      (let loop ((sch schedule) (sr '()) (sg '()))
        (if (null? sch)
            (if (and (eq? (parser-lifecycle (lane-parser rl)) 'ready)
                     (eq? (parser-lifecycle (lane-parser gl)) 'ready))
                (let-values (((sr2 sg2 bad) (finish-loop! rl gl fnames sr sg)))
                  (values rl gl (reverse sr2) (reverse sg2) bad))
                (values rl gl (reverse sr) (reverse sg) 'none))
            (let* ((slice (car sch)) (bv (car slice)) (st (cadr slice)) (en (caddr slice)))
              (let-values (((sr2 sg2 bad) (feed-loop! rl gl bv st en fnames sr sg)))
                (if (not (eq? bad 'none))
                    (values rl gl (reverse sr2) (reverse sg2) bad)
                    (loop (cdr sch) sr2 sg2))))))))

  ;; ============ 4. Counters (F9/F10): 48 keys, both halves ====================
  (define (make-counter-set) (let ((v (make-vector (length counter-specs)))) (do ((i 0 (+ i 1))) ((= i (vector-length v)) v) (vector-set! v i (cons #f #f)))))
  (define (counter-keys) (map counter-spec-key counter-specs))
  ;; The member symbols of one counter FAMILY (F18 totality rows: the callback-
  ;; outcome / span-event / schedule-shape families have no source list to read, so
  ;; a totality row compares the driver's own family against the spec's declared
  ;; closed set). Families: node-kind matcher operation predicate callback-outcome
  ;; span-event schedule-shape declaration.
  (define (family-members fam)
    (fold-right (lambda (cs acc) (if (eq? (counter-spec-family cs) fam) (cons (counter-spec-member cs) acc) acc))
                '() counter-specs))
  (define (counter-labels) (apply append (map (lambda (cs) (list (counter-spec-agreed cs) (counter-spec-interp cs))) counter-specs)))
  (define (spec-of key) (let loop ((cs counter-specs)) (cond ((null? cs) #f) ((eq? (counter-spec-key (car cs)) key) (car cs)) (else (loop (cdr cs))))))
  (define (counter-agreed-label key) (counter-spec-agreed (spec-of key)))
  (define (counter-interp-label key) (counter-spec-interp (spec-of key)))
  (define (key-index key) (let loop ((cs counter-specs) (i 0)) (cond ((null? cs) #f) ((eq? (counter-spec-key (car cs)) key) i) (else (loop (cdr cs) (+ i 1))))))
  (define (counter-ref counters key half)
    (let ((cell (vector-ref counters (key-index key)))) (if (eq? half 'agreed) (car cell) (cdr cell))))
  ;; observe-counters folds one machine's OBSERVED key-sets (ref/gen) into the set:
  ;; agreed |= key in BOTH; interpreter-only |= key in ref.
  (define (observe-counters counters ref-keys gen-keys)
    (let loop ((cs counter-specs) (i 0))
      (if (null? cs) counters
          (let* ((k (counter-spec-key (car cs))) (cell (vector-ref counters i))
                 (rk (and (memq k ref-keys) #t)) (gk (and (memq k gen-keys) #t)))
            (vector-set! counters i (cons (or (car cell) (and rk gk)) (or (cdr cell) rk)))
            (loop (cdr cs) (+ i 1))))))

  (define-record-type counter-spec (fields key family member agreed interp))
  (define (nk-spec member verb)
    (make-counter-spec member 'node-kind member
                       (string-append "at least one agreed trial " verb " node kind " (symbol->string member))
                       (string-append "the interpreter alone " verb " node kind " (symbol->string member))))
  (define (fam-spec key family word member verb)
    (make-counter-spec key family member
                       (string-append "at least one agreed trial " verb " " word " " (symbol->string member))
                       (string-append "the interpreter alone " verb " " word " " (symbol->string member))))
  (define counter-specs
    (append
     (list (nk-spec 'byte-dispatch "reaches") (nk-spec 'sequence-dispatch "reaches")
           (nk-spec 'keyword-table "reaches")
           (nk-spec 'stop "reaches") (nk-spec 'error "reaches")
           (nk-spec 'field-action "reaches") (nk-spec 'field-branch "reaches")
           (nk-spec 'callback "reaches") (nk-spec 'span-start "reaches")
           (nk-spec 'span-end "reaches") (nk-spec 'counted-consume "reaches")
           ;; the SHIPPED labels (Task 7 Step 3: the shipped label IS the member's counter)
           (make-counter-spec 'pause 'node-kind 'pause
                              "at least one agreed trial observes a pause"
                              "the interpreter alone observes a pause")
           (make-counter-spec 'finish 'node-kind 'finish
                              "at least one agreed trial observes an idle-completion finish"
                              "the interpreter alone observes an idle-completion finish")
           (make-counter-spec 'integer-accumulate 'node-kind 'integer-accumulate
                              "at least one generated machine's trial commits a digit"
                              "the interpreter alone commits a digit")
           ;; the accumulate node's SECOND arm (+2, F10)
           (make-counter-spec 'accumulate-overflow 'node-kind 'integer-accumulate
                              "at least one generated machine's trial overflows the field"
                              "the interpreter alone overflows the field")
           ;; the declares-a-field pair (+2, F10 row 3): now an OBSERVED witness + a twin
           (make-counter-spec 'declares-field 'declaration 'field
                              "at least one generated machine declares a field"
                              "the interpreter alone changes a declared field"))
     ;; FIXED literal member lists, NOT the imported draw tables: the counter set
     ;; is what we CHECK, the draw table is what the generator produces. A mutation
     ;; that removes a matcher/operation/predicate from the DRAW table must leave
     ;; its counter CHECK standing so it reads zero and the pin catches -- if the
     ;; counter were built from the draw table, removing the member would delete
     ;; the check instead. (These match the draw tables' normal values; the totality
     ;; rows are what assert the two agree with ir.sls.)
     (map (lambda (m) (fam-spec m 'matcher "matcher" m "matches"))
          '(exact-byte byte-set byte-range byte-complement))
     (map (lambda (o) (fam-spec o 'operation "field operation" o "runs"))
          '(store clear increment decrement add set-mask clear-mask))
     (map (lambda (p) (fam-spec p 'predicate "field predicate" p "evaluates"))
          '(equal zero nonzero range mask-any mask-all mask-none))
     (map (lambda (c) (fam-spec (string->symbol (string-append "cb-" (symbol->string c)))
                                'callback-outcome "callback outcome" c "observes"))
          '(continue pause declared-branch-key explicit-failure))
     (map (lambda (e) (fam-spec (string->symbol (string-append "span-" (symbol->string e)))
                                'span-event "span event" e "observes"))
          '(span-open boundary-fragment end-fragment completion empty-fragment))
     (map (lambda (s) (fam-spec (string->symbol (string-append "sched-" (symbol->string s)))
                                'schedule-shape "schedule shape" s "drives"))
          '(every-split-point split-point-pair random-multi-split empty-feeds nonzero-slice padded-bytevector))))

  ;; ============ 5. Observation ================================================
  ;; Read OBSERVED keys from one lane's step tuples + final parser + traces + the
  ;; IR machine (via ir; the decoder only says what a reached name was drawn as).
  (define (node-by-name m nm) (find (lambda (n) (eq? (node-name n) nm)) (machine-nodes m)))
  (define (matcher-kind-of mch)
    (cond ((exact-byte-matcher? mch) 'exact-byte) ((byte-set-matcher? mch) 'byte-set)
          ((byte-range-matcher? mch) 'byte-range) ((byte-complement-matcher? mch) 'byte-complement)))
  (define (entry-dispatch m)                ; the free byte-dispatch after the coverage prefix
    (let ((covmt (node-by-name m 'covmt)))
      (and covmt (field-action-node? covmt) (node-by-name m (field-action-node-next covmt)))))

  ;; observe-lane! : add observed keys for one lane to the accumulator via note!.
  (define (observe-lane! m manifest lane steps note!)
    (let ((p (lane-parser lane)) (decoder (manifest-node-kinds manifest))
          ;; A pause NODE, when it pauses, leaves parser-state-name at its
          ;; CONTINUATION (not the pause node itself), so its observed witness is a
          ;; paused step whose state-name is one of the machine's pause-node
          ;; continuations -- which also distinguishes it from a callback pause
          ;; (whose state-name is the callback's own pause continuation).
          (pause-conts (map pause-node-continuation (filter pause-node? (machine-nodes m)))))
      ;; status- and state-name-based node kinds
      (for-each
       (lambda (s)
         (let ((t (step-tuple s)))
           (case (tup-status t)
             ((finished) (note! 'finish)) ((stopped) (note! 'stop)) ((error) (note! 'error))
             ((paused) (when (memq (tup-state t) pause-conts) (note! 'pause)))
             (else #f))
           (when (tup-span t) (note! 'span-span-open) (note! 'span-start))
           (let ((sn (tup-state t)))            ; the current node after this step
             (let ((k (assq sn decoder)))
               (when k (case (cdr k)
                         ((byte-dispatch sequence-dispatch keyword-table counted-consume span-start span-end callback field-branch field-action) (note! (cdr k)))
                         (else #f)))))
           (let ((e (tup-error t)))             ; overflow: error node-name = an accumulate node's overflow error
             (when (and e (pair? e)) (when (memq (list-ref e 3) (accumulate-overflow-nodes m)) (note! 'accumulate-overflow))))))
       steps)
      ;; field-based witnesses read from the final parser (op / field-action / declares-field)
      (for-each (lambda (w)                    ; w = (fa-node field op init)
                  (let ((v (parser-field-ref p (cadr w))))
                    (unless (= v (cadddr w)) (note! (caddr w)) (note! 'field-action) (note! 'declares-field))))
                (manifest-witnesses manifest))
      (for-each (lambda (mk)                   ; mk = (fb-node field pred (true.1)(false.2))
                  (let ((v (parser-field-ref p (cadr mk))))
                    (unless (= v 0) (note! (caddr mk)) (note! 'field-branch))))
                (manifest-markers manifest))
      ;; integer-accumulate "commits a digit": an accumulate node's field != its declared initial
      (for-each (lambda (an)
                  (let ((fld (integer-accumulate-node-field an)))
                    (unless (= (parser-field-ref p fld) (field-initial manifest fld)) (note! 'integer-accumulate))))
                (accumulate-nodes m))
      ;; callback outcomes from the cb trace
      (for-each (lambda (e)                    ; e = (name state offset answer)
                  (let ((ans (list-ref e 3)))
                    (cond ((eq? ans 'continue) (note! 'cb-continue))
                          ((eq? ans 'pause) (note! 'cb-pause))
                          ((and (symbol? ans)) (note! 'cb-declared-branch-key))
                          ((pair? ans) (note! 'cb-explicit-failure)))))
                ((lane-creader lane)))
      ;; span events from the data trace. A fragment or completion also witnesses
      ;; the span-start/span-end NODE KINDS, which are zero-width and so are never
      ;; named at a park (parser-state-name never names them) -- their observed
      ;; witness IS the span event. A delivered fragment of length 0 witnesses
      ;; `empty-fragment` (decision 0042: an empty span delivers one empty fragment,
      ;; so the observable is a zero-length delivery, not the old suppression).
      (let loop ((tr ((lane-dreader lane))) (since 0) (prev-frag #f))
        (cond ((null? tr)
               (when prev-frag (note! 'span-end-fragment) (note! 'span-end)))
              ((eq? (car tr) 'complete)
               (note! 'span-completion) (note! 'span-end)
               (when (> since 0) (note! 'span-end-fragment))
               (loop (cdr tr) 0 #f))
              (else (note! 'span-boundary-fragment) (note! 'span-start)
                    (when (and (bytevector? (car tr)) (= 0 (bytevector-length (car tr))))
                      (note! 'span-empty-fragment))
                    (loop (cdr tr) (+ since 1) #t))))))

  (define (accumulate-nodes m) (filter integer-accumulate-node? (machine-nodes m)))
  (define (accumulate-overflow-nodes m) (map integer-accumulate-node-overflow-error (accumulate-nodes m)))
  (define (field-initial manifest fld)
    (let loop ((fs (manifest-fields manifest)))
      (cond ((null? fs) 0) ((eq? (uint-field-name (car fs)) fld) (uint-field-initial (car fs))) (else (loop (cdr fs))))))

  ;; matcher observation over the 256-byte sweep: for a byte b whose trial agreed,
  ;; the entry dispatch's first case whose matcher matches b fired; note its kind.
  (define (observe-matcher! ed b note!)
    (when (and ed (byte-dispatch-node? ed))
      (let loop ((cs (byte-dispatch-node-cases ed)))
        (cond ((null? cs) #f)
              ((memv b (matcher-bytes (byte-case-matcher (car cs)))) (note! (matcher-kind-of (byte-case-matcher (car cs)))))
              (else (loop (cdr cs)))))))

  ;; schedule shapes, observed from the result sequence (never the schedule spec).
  (define (note-schedule-shape! kind steps note!)
    (let ((nfeeds (length (filter (lambda (s) (memq (tup-status (step-tuple s)) '(need-input paused finished stopped error))) steps))))
      (case kind
        ((splits) (when (>= nfeeds 2) (note! 'sched-every-split-point)))
        ((pairs) (when (>= nfeeds 3) (note! 'sched-split-point-pair)))
        ((multi) (when (>= nfeeds 2) (note! 'sched-random-multi-split)))
        ((empties) (note! 'sched-empty-feeds))
        ((sub) (note! 'sched-nonzero-slice))
        ((padded) (note! 'sched-padded-bytevector))
        (else #f))))

  ;; ============ 6. run-machine ================================================
  ;; (run-machine m ref-cm gen-cm manifest inputs state counters on-first-disagreement)
  ;;   -> (values counters verdict inv-verdict fixture-path state)
  ;; `verdict` is the FIRST Layer-1 CROSS-LANE disagreement (the per-machine "byte
  ;; agreement"); `inv-verdict` is the FIRST Layer-3 ORACLE violation on the ref lane
  ;; -- kept SEPARATE, because a Layer-3 violation is not a lane disagreement and
  ;; must not redden an agreement label. Both are "at most once per machine".
  ;; on-first-disagreement is the SAVER (Slice ③, 0033 item 4): when non-#f,
  ;; run-machine calls it ONCE, at the first Layer-1 disagreement per machine, as
  ;; (on-first-disagreement m script schedule input verdict), and threads its return
  ;; into the `fixture-path` value. #f stays legal and is what run-machine-verdict
  ;; and any caller wanting no fixture passes; fixture-path is then #f. Slice ③
  ;; added only this call site -- the argument list and the five return values are
  ;; unchanged (F1), so a caller that passes #f folds byte-identically to before.
  (define (run-machine m ref-cm gen-cm manifest inputs state counters on-first-disagreement)
    (let ((fnames (map uint-field-name (manifest-fields manifest)))
          (bound (all-bound manifest))
          (ed (entry-dispatch m))
          (ref-keys '()) (gen-keys '()) (verdict 'none) (inv-verdict 'none) (fixture-path #f))
      (define (note-ref! k) (unless (memq k ref-keys) (set! ref-keys (cons k ref-keys))))
      (define (note-gen! k) (unless (memq k gen-keys) (set! gen-keys (cons k gen-keys))))
      (define (fail! phase idx bad) (when (eq? verdict 'none) (set! verdict (list phase idx bad))))
      (define (inv-fail! idx v) (when (eq? inv-verdict 'none) (set! inv-verdict (list 'invariant idx v))))
      ;; one schedule: draw a script, run it, observe both lanes, note shape, fold
      ;; the FIRST Layer-1 disagreement into `verdict`, then -- only when the lanes
      ;; agreed -- run the Layer-3 oracle (check-invariants) on the ref lane and fold
      ;; its first violation into `inv-verdict`. `input` is the logical bytevector for
      ;; row 6's content check. Returns (values bad new-state).
      (define (one-schedule schedule shape phase idx input s)
        (let-values (((script s2) (draw-script manifest s)))
          (let-values (((bad inv-v rl gl sr sg)
                        (schedule-outcome m ref-cm gen-cm (manifest-callbacks manifest)
                                          fnames bound script schedule input)))
            (observe-lane! m manifest rl sr note-ref!)
            (observe-lane! m manifest gl sg note-gen!)
            (when shape (note-schedule-shape! shape sr note-ref!) (note-schedule-shape! shape sg note-gen!))
            (if (not (eq? bad 'none))
                ;; The saver fires HERE, at the first Layer-1 disagreement per
                ;; machine -- `first?` reads fail!'s own "only when verdict is 'none"
                ;; rule (Task 4 Step 7), so on-first-disagreement is called at most
                ;; once per machine and writes at most one file, whatever later
                ;; schedules do. Its return (a fixture path, or whatever the closure
                ;; yields) is threaded into run-machine's fixture-path value (F1).
                (let ((first? (eq? verdict 'none)))
                  (fail! phase idx bad)
                  (when (and first? on-first-disagreement)
                    (set! fixture-path
                          (on-first-disagreement m script schedule input verdict))))
                (unless (eq? inv-v 'none) (inv-fail! idx inv-v)))
            (values bad s2))))
      (define (byte-sweep s)
        (let loop ((b 0) (s s))
          (if (= b 256) s
              (let ((in (make-bytevector 1 b)))
                (let-values (((bad s2) (one-schedule (list (list in 0 1)) #f 'byte b in s)))
                  (when (eq? bad 'none) (observe-matcher! ed b note-ref!) (observe-matcher! ed b note-gen!))
                  (loop (+ b 1) s2))))))
      (define (input-sweep bv s)
        (let-values (((multi ms) (schedule-multi-split bv s)))
          (let ((groups (list (cons 'splits (schedule-splits bv)) (cons 'pairs (schedule-pairs bv))
                              (cons 'whole (schedule-whole bv)) (cons 'empties (schedule-empties bv))
                              (cons 'sub (schedule-sub-slice bv)) (cons 'padded (schedule-padded bv))
                              (cons 'multi multi))))
            (let gloop ((gs groups) (idx 0) (s ms))
              (if (null? gs) s
                  (let sloop ((scs (cdar gs)) (idx idx) (s s))
                    (if (null? scs) (gloop (cdr gs) idx s)
                        (let-values (((bad s2) (one-schedule (car scs) (caar gs) 'schedule idx bv s)))
                          (sloop (cdr scs) (+ idx 1) s2)))))))))
      (let* ((s1 (byte-sweep state))
             (s2 (let iloop ((ins inputs) (s s1)) (if (null? ins) s (iloop (cdr ins) (input-sweep (car ins) s))))))
        (observe-counters counters ref-keys gen-keys)
        (values counters verdict inv-verdict fixture-path s2))))
  (define (run-machine-verdict m ref-cm gen-cm manifest inputs state)
    (let-values (((c v iv fp s) (run-machine m ref-cm gen-cm manifest inputs state (make-counter-set) #f))) v))

  ;; The shared single-schedule body (Task 3 Step 3: ONE body, and its consumers
  ;; are run-machine's one-schedule and run-one-trial). Runs ONE schedule on a
  ;; fresh lane pair and returns
  ;;   (values bad inv-v rl gl sr sg)
  ;; bad   = the FIRST Layer-1 cross-lane disagreement descriptor (run-schedule's
  ;;         own `bad`), 'none if the lanes agreed through the whole schedule;
  ;; inv-v = the Layer-3 oracle verdict on the ref lane, computed ONLY when the
  ;;         lanes agreed -- a disagreement short-circuits it, exactly as the lane's
  ;;         fold does -- and 'none otherwise;
  ;; rl gl sr sg = the lanes and their step lists, for the caller's observation.
  ;; The disagreement rule (Layer 1) and the agreement-gated Layer-3 oracle live
  ;; HERE and nowhere else, so the lane and the fixture cannot drift (F2 / Task 3
  ;; Step 5: run-one-trial and run-machine fold the identical (bad, inv-v) for any
  ;; schedule, so their verdicts agree by construction rather than by coincidence).
  (define (schedule-outcome m ref-cm gen-cm cbs fnames bound script schedule input)
    (let-values (((rl gl sr sg bad)
                  (run-schedule ref-cm gen-cm cbs schedule fnames bound script)))
      (if (not (eq? bad 'none))
          (values bad 'none rl gl sr sg)
          (let-values (((v3 app) (check-invariants m sr input ((lane-sreader rl)))))
            (values 'none v3 rl gl sr sg)))))

  ;; run-one-trial (Slice ③, F2): the single-trial entry the fixture asserts on and
  ;; the minimizer uses as a boolean oracle. ONE machine, ONE script, ONE schedule,
  ;; ONE input; the field names and callback declarations come from the MACHINE
  ;; through `ir`, NOT from a manifest -- the fixture asserts one trial and no
  ;; counter, so it needs no decoder, so it needs no manifest, so `make-manifest`
  ;; stays unexported and this is a NEW export rather than a changed run-machine
  ;; signature (F1's instruction). Returns the trial's disagreement verdict: the
  ;; Layer-1 cross-lane `bad` when the lanes disagree (the probe's case -- a lying
  ;; compiled lane against an honest reference), else the Layer-3 oracle verdict on
  ;; agreement, 'none when neither fires. It shares schedule-outcome with the lane,
  ;; so for the same schedule its verdict is what run-machine folds (Task 3 Step 5).
  ;; `input` is the logical bytevector the schedule was sliced from: the Layer-3
  ;; content/anchor row reads it, and the minimizer shrinks it and re-derives the
  ;; schedule from it before each call.
  (define (run-one-trial m ref-cm gen-cm script schedule input)
    (let ((fnames (map uint-field-name (machine-fields m)))
          (cbs (machine-callbacks m)))
      (let-values (((bad inv-v rl gl sr sg)
                    (schedule-outcome m ref-cm gen-cm cbs fnames
                                      (map callback-declaration-name cbs) script schedule input)))
        (if (not (eq? bad 'none)) bad inv-v))))

  ;; fixture-text (Slice ③ saver, F1/F5/F6): the PURE core of the saver. It returns
  ;; the fixture PROGRAM as a string and does no I/O (F18: the driver is a functional
  ;; core); the LANE's closure writes the string to a file and returns its path,
  ;; which run-machine threads into fixture-path. It takes an already-printed
  ;; `machine-datum` (the lane calls (byte-machine test machine-print)'s print-machine
  ;; and passes the result) so the driver does not import machine-print -- that keeps
  ;; machine-print out of the differential lane's SOURCES and in only the fixture
  ;; lane's (Task 7 Step 1). The single case asserts the
  ;; two lanes AGREE, so the fixture FAILS -- exit 1 -- exactly when the disagreement
  ;; is present, and exits 0 once it is fixed (§4.7's "exits 1 on the disagreement
  ;; and 0 when fixed"; the polarity P3 measured as "FAIL … the lanes agree").
  ;;   m script schedule input : the trial to reproduce.
  ;;   invocation : the F5 header comment (already ";;"-prefixed, newline-terminated)
  ;;                the lane computed from (command-line-arguments): the exact
  ;;                provenance-unset `chez … chez-source.ss … --program <this file>`.
  ;;   preamble   : extra top-level forms ('() honest; the probe's `perturb` def).
  ;;   gen-expr   : the datum bound to `gen`, with `ref` in scope -- `ref` itself for
  ;;                an honest fixture (which then agrees and exits 0), or the lying
  ;;                slot-2 wrapper of REF's op for the probe (F7).
  ;;
  ;; The fixture builds BOTH lanes from the interpreter and EMITS NOTHING. F7's lie
  ;; can only wrap the message-dispatch op, which is the INTERPRETER variant's -- the
  ;; generated variant's slot 2 is a step function of a different arity (measured:
  ;; wrapping it raises "incorrect number of arguments"). So the deliberate-failure
  ;; probe needs no generated lane and no writable directory: F6's "the fixture emits
  ;; a generated lane" does not hold for it (Task 12 corrects F6), and "without
  ;; external tooling" (§25:1627) is the stronger for it -- chez, the launcher, the
  ;; tree, and not one byte written. A fixture reproducing a REAL interpreter/generated
  ;; disagreement would instead build one lane by emission; that is not this probe.
  (define (fixture-text machine-datum script schedule input invocation preamble gen-expr)
    (let ((forms
           (append
            (list
             '(import (rnrs)
                      (byte-machine test harness) (byte-machine test property-driver)
                      (byte-machine graph) (byte-machine verify) (byte-machine interpret)
                      (byte-machine runtime))
             (list 'define 'machine machine-datum)
             (list 'define 'script (list 'quote script))
             (list 'define 'schedule (list 'quote schedule))
             (list 'define 'input input)
             '(define ref (make-interpreted-machine (verify-machine machine))))
            preamble
            (list
             (list 'define 'gen gen-expr)
             '(harness-begin "fixture")
             '(harness-group "reproduction"
                (lambda ()
                  (harness-case "the saved trial reproduces the disagreement"
                    (lambda ()
                      (check-equal "the two lanes agree on this trial"
                                   (run-one-trial machine ref gen script schedule input)
                                   'none)))))
             '(harness-finish)))))
      (call-with-string-output-port
       (lambda (port)
         (put-string port invocation)
         (for-each (lambda (f) (write f port) (newline port) (newline port)) forms)))))

  ;; ============ the minimizer (Slice ③, §4.7) =================================
  ;; A PURE greedy reducer over (machine script input schedule): a fixed sequence of
  ;; reductions, each candidate accepted iff the reduced machine VERIFIES (validity
  ;; oracle: the shipped verify-machine) AND the reduced trial STILL DISAGREES
  ;; (failure oracle: `fail-oracle`, injected by the lane because only the lane knows
  ;; how the gen lane was built -- honest, or the probe's lie). Deterministic (fixed
  ;; candidate order, first accepted wins, restart), bounded to `bound` failure-oracle
  ;; calls (each rebuilds/emits a gen lane), and TERMINATING because every accepted
  ;; reduction strictly decreases `tuple-size`, which is bounded below by zero. Its
  ;; output is (values machine script input schedule) -- the minimized trial, which
  ;; the lane saves through the SAME saver (fixture-text) as the raw one.
  ;;
  ;; It introduces no third notion of validity or failure (§4.7): validity is the
  ;; verifier's verdict, failure is run-one-trial's (via fail-oracle).

  ;; -- structural size: a node's weight reflects its content, so replacing a rich
  ;; node with a fresh error sink (remove-node, below) strictly shrinks the machine
  ;; even though the node COUNT is unchanged; a trivial node replaced by a sink does
  ;; not shrink, and the loop's `(< (apply tuple-size c) cur-size)` guard then skips
  ;; that no-progress removal.
  (define (node-weight n)
    (cond ((byte-dispatch-node? n) (+ 1 (length (byte-dispatch-node-cases n))))
          ((sequence-dispatch-node? n) (+ 1 (length (sequence-dispatch-node-cases n))))
          ((callback-node? n) (+ 1 (length (callback-node-branch-targets n))))
          (else 1)))
  (define (machine-node-count m) (length (machine-nodes m)))
  (define (tuple-size m script input schedule)
    (+ (apply + (map node-weight (machine-nodes m)))
       (length (machine-fields m)) (length (machine-callbacks m))
       (length (machine-spans m)) (length (machine-errors m))
       (bytevector-length input) (length schedule)))

  ;; -- target renaming, per node kind (mirrors the printer's arm structure): every
  ;; NODE-target slot passes through `rename`; declaration/field/callback/span name
  ;; references (error-node's declaration, a field/callback/span reference) are NOT
  ;; node targets and are left alone. field-action's `error` and integer-accumulate's
  ;; `overflow-error` ARE node targets (ir.sls says both name a target node).
  (define (rename-edge e rename) (make-edge (rename (edge-target e)) (edge-mode e)))
  (define (rt rename t) (if (symbol? t) (rename t) t))     ; target-or-#f
  (define (rename-targets n rename)
    (cond
      ((byte-dispatch-node? n)
       (make-byte-dispatch-node (byte-dispatch-node-name n)
         (map (lambda (c) (make-byte-case (byte-case-matcher c)
                            (rename-edge (byte-case-edge c) rename) (byte-case-source-label c)))
              (byte-dispatch-node-cases n))
         (rename-edge (byte-dispatch-node-fallback n) rename)
         (rt rename (byte-dispatch-node-eof-target n)) (byte-dispatch-node-source-label n)))
      ((sequence-dispatch-node? n)
       (make-sequence-dispatch-node (sequence-dispatch-node-name n)
         (map (lambda (c) (make-sequence-case (sequence-case-bytes c)
                            (rename (sequence-case-target c)) (sequence-case-source-label c)))
              (sequence-dispatch-node-cases n))
         (rename-edge (sequence-dispatch-node-mismatch n) rename)
         (rt rename (sequence-dispatch-node-eof-target n)) (sequence-dispatch-node-source-label n)))
      ((pause-node? n)
       (make-pause-node (pause-node-name n) (rename (pause-node-continuation n))
                        (pause-node-reason n) (pause-node-source-label n)))
      ((field-action-node? n)
       (make-field-action-node (field-action-node-name n) (field-action-node-operation n)
         (field-action-node-arguments n) (rename (field-action-node-next n))
         (rt rename (field-action-node-error n)) (field-action-node-source-label n)))
      ((field-branch-node? n)
       (make-field-branch-node (field-branch-node-name n) (field-branch-node-predicate n)
         (field-branch-node-arguments n) (rename (field-branch-node-true-target n))
         (rename (field-branch-node-false-target n)) (field-branch-node-source-label n)))
      ((integer-accumulate-node? n)
       (make-integer-accumulate-node (integer-accumulate-node-name n)
         (integer-accumulate-node-field n) (integer-accumulate-node-base n)
         (rename (integer-accumulate-node-digit-target n))
         (rename-edge (integer-accumulate-node-nondigit-edge n) rename)
         (rename (integer-accumulate-node-overflow-error n))
         (rt rename (integer-accumulate-node-eof-target n)) (integer-accumulate-node-source-label n)))
      ((callback-node? n)
       (make-callback-node (callback-node-name n) (callback-node-callback n)
         (rename (callback-node-continue-target n))
         (map (lambda (b) (list (car b) (rename (cadr b)))) (callback-node-branch-targets n))
         (rename (callback-node-pause-continuation n)) (callback-node-reason n)
         (callback-node-source-label n)))
      ((span-start-node? n)
       (make-span-start-node (span-start-node-name n) (span-start-node-span n)
         (rename (span-start-node-next n)) (span-start-node-source-label n)))
      ((span-end-node? n)
       (make-span-end-node (span-end-node-name n) (span-end-node-span n)
         (rename (span-end-node-next n)) (span-end-node-source-label n)))
      ((counted-consume-node? n)
       (make-counted-consume-node (counted-consume-node-name n) (counted-consume-node-field n)
         (rename (counted-consume-node-next n)) (rt rename (counted-consume-node-eof-target n))
         (counted-consume-node-source-label n)))
      (else n)))            ; stop / finish / error: no node targets

  (define (rebuild-machine m nodes)
    (make-machine (machine-name m) (machine-entry m) (machine-fields m) (machine-callbacks m)
      (machine-spans m) (machine-errors m) nodes (machine-default-eof-error m)
      (machine-source-label m)))
  (define (replace-node m name n2)
    (rebuild-machine m (map (lambda (n) (if (eq? (node-name n) name) n2 n)) (machine-nodes m))))

  ;; remove NODE victim: every in-edge is retargeted to a FRESH error node OF ITS OWN
  ;; (Task 5 Step 4). Never a shared sink -- a shared sink joins `none` with (active s)
  ;; inside a span and stops every subsequent reduction at inconsistent-span-state
  ;; (decision 0029 item 2). The sink references the machine's first declared error,
  ;; and its name is portable (lowercase/hyphen), so the verifier accepts the name.
  (define (remove-node m victim)
    (let* ((errname (if (pair? (machine-errors m))
                        (error-declaration-name (car (machine-errors m)))
                        (machine-default-eof-error m)))
           (fresh (string->symbol (string-append "min-sink-" (symbol->string victim))))
           (rename (lambda (t) (if (eq? t victim) fresh t)))
           (kept (filter (lambda (n) (not (eq? (node-name n) victim))) (machine-nodes m)))
           (renamed (map (lambda (n) (rename-targets n rename)) kept)))
      (rebuild-machine m (append renamed (list (make-error-node fresh errname #f))))))

  (define (indices xs) (let loop ((i 0) (xs xs)) (if (null? xs) '() (cons i (loop (+ i 1) (cdr xs))))))
  (define (list-head xs k) (if (= k 0) '() (cons (car xs) (list-head (cdr xs) (- k 1)))))  ; not in (rnrs)
  (define (drop-index xs i)
    (let loop ((j 0) (xs xs)) (cond ((null? xs) '()) ((= j i) (cdr xs)) (else (cons (car xs) (loop (+ j 1) (cdr xs)))))))
  (define (bytevector-drop bv i)
    (let ((n (bytevector-length bv)))
      (let ((out (make-bytevector (- n 1))))
        (do ((k 0 (+ k 1)) (o 0 (if (= k i) o (+ o 1))))
            ((= k n) out)
          (unless (= k i) (bytevector-u8-set! out o (bytevector-u8-ref bv k)))))))

  ;; The reductions, in §4.7's order. Each maps the current trial to a list of
  ;; candidate trials (m script input schedule); the driver's verify+fail-oracle
  ;; guards decide which are kept. Reductions that need no graph surgery (input and
  ;; schedule shrinks) are pure list edits.
  (define (red-remove-node m s i sch)
    (map (lambda (n) (list (remove-node m (node-name n)) s i sch))
         (filter (lambda (n) (not (eq? (node-name n) (machine-entry m)))) (machine-nodes m))))
  (define (red-remove-case m s i sch)
    (apply append
      (map (lambda (N)
             (cond
               ((byte-dispatch-node? N)
                (map (lambda (k)
                       (list (replace-node m (node-name N)
                               (make-byte-dispatch-node (byte-dispatch-node-name N)
                                 (drop-index (byte-dispatch-node-cases N) k)
                                 (byte-dispatch-node-fallback N) (byte-dispatch-node-eof-target N)
                                 (byte-dispatch-node-source-label N)))
                             s i sch))
                     (indices (byte-dispatch-node-cases N))))
               ;; a sequence-dispatch needs >=1 case (make-sequence-dispatch-node), so
               ;; only drop when more than one remains.
               ((and (sequence-dispatch-node? N) (> (length (sequence-dispatch-node-cases N)) 1))
                (map (lambda (k)
                       (list (replace-node m (node-name N)
                               (make-sequence-dispatch-node (sequence-dispatch-node-name N)
                                 (drop-index (sequence-dispatch-node-cases N) k)
                                 (sequence-dispatch-node-mismatch N) (sequence-dispatch-node-eof-target N)
                                 (sequence-dispatch-node-source-label N)))
                             s i sch))
                     (indices (sequence-dispatch-node-cases N))))
               (else '())))
           (machine-nodes m))))
  ;; remove a declaration (a field / callback / span / error). §4.7's "unnamed
  ;; declaration": rather than re-derive referencedness, offer each and let the
  ;; verifier reject a referenced one -- a removable declaration is exactly one whose
  ;; removal still verifies.
  (define (red-remove-declaration m s i sch)
    (append
     (map (lambda (k) (list (rebuild-with m 'fields (drop-index (machine-fields m) k)) s i sch)) (indices (machine-fields m)))
     (map (lambda (k) (list (rebuild-with m 'callbacks (drop-index (machine-callbacks m) k)) s i sch)) (indices (machine-callbacks m)))
     (map (lambda (k) (list (rebuild-with m 'spans (drop-index (machine-spans m) k)) s i sch)) (indices (machine-spans m)))
     (map (lambda (k) (list (rebuild-with m 'errors (drop-index (machine-errors m) k)) s i sch)) (indices (machine-errors m)))))
  (define (rebuild-with m which coll)
    (make-machine (machine-name m) (machine-entry m)
      (if (eq? which 'fields) coll (machine-fields m))
      (if (eq? which 'callbacks) coll (machine-callbacks m))
      (if (eq? which 'spans) coll (machine-spans m))
      (if (eq? which 'errors) coll (machine-errors m))
      (machine-nodes m) (machine-default-eof-error m) (machine-source-label m)))
  (define (red-drop-input-byte m s i sch)
    (map (lambda (k)
           (let ((i2 (bytevector-drop i k)))
             (list m s i2 (list (list i2 0 (bytevector-length i2))))))
         (indices (bytevector->u8-list i))))
  ;; merge two ADJACENT contiguous slices of the same bytevector into one feed.
  (define (red-merge-feeds m s i sch)
    (let loop ((k 0) (acc '()))
      (if (>= k (- (length sch) 1)) (reverse acc)
          (let ((a (list-ref sch k)) (b (list-ref sch (+ k 1))))
            (loop (+ k 1)
                  (if (and (eq? (car a) (car b)) (= (caddr a) (cadr b)))   ; same bv, a.end = b.start
                      (cons (list m s i
                                  (append (list-head sch k)
                                          (list (list (car a) (cadr a) (caddr b)))
                                          (list-tail sch (+ k 2))))
                            acc)
                      acc))))))
  ;; drop the trailing feed (§4.7's "drop a resume or the finish": shortening the
  ;; schedule ends the trial earlier; a dropped resume tends to make both lanes hit
  ;; the same contract condition, i.e. AGREEMENT, so the oracle usually rejects it).
  (define (red-drop-trailing-feed m s i sch)
    (if (> (length sch) 1) (list (list m s i (list-head sch (- (length sch) 1)))) '()))

  (define (minimize machine script input schedule fail-oracle bound)
    (let ((emissions 0))
      (define (verifies? m) (verification-ok? (verify-machine m)))
      (define (still-fails? m s i sch)
        (and (< emissions bound)
             (begin (set! emissions (+ emissions 1))
                    (not (eq? (fail-oracle m s i sch) 'none)))))
      (define (candidates cur)
        (let ((m (car cur)) (s (cadr cur)) (i (caddr cur)) (sch (cadddr cur)))
          (append (red-remove-node m s i sch) (red-remove-case m s i sch)
                  (red-remove-declaration m s i sch) (red-drop-input-byte m s i sch)
                  (red-merge-feeds m s i sch) (red-drop-trailing-feed m s i sch))))
      (let loop ((cur (list machine script input schedule)))
        (let ((cur-size (apply tuple-size cur)))
          (let try ((cs (candidates cur)))
            (cond
             ((or (null? cs) (>= emissions bound))
              (values (car cur) (cadr cur) (caddr cur) (cadddr cur)))
             (else
              (let* ((c (car cs)) (cm (car c)) (cs2 (cadr c)) (ci (caddr c)) (csch (cadddr c)))
                (if (and (< (apply tuple-size c) cur-size)
                         (verifies? cm)
                         (still-fails? cm cs2 ci csch))
                    (loop c)
                    (try (cdr cs)))))))))))
  ;; Bind every declared callback (required ones MUST be bound; optionals MAY be).
  ;; §4.4's "optional callbacks bound in half the draws" governs which PATHS run,
  ;; not the 96 counters, so binding all is valid here; the coverage segment's
  ;; required callbacks (covd/covc/covdec) are bound by this.
  (define (all-bound manifest) (map callback-declaration-name (manifest-callbacks manifest)))
  ;; draw-script : per node callback, a list of outcomes cycling continue / pause /
  ;; a declared branch key / an explicit failure, so all four callback outcomes are
  ;; observable. Identical in both lanes (drawn once per trial).
  (define (draw-script manifest s)
    (let loop ((cds (filter (lambda (cd) (memq (callback-declaration-kind cd) '(event decision))) (manifest-callbacks manifest)))
               (s s) (acc '()))
      (if (null? cds) (values (reverse acc) s)
          (let* ((cd (car cds)) (keys (callback-declaration-branch-keys cd)))
            (let-values (((k s2) (prng-next s 4)))
              (let ((outcome (case k
                               ((0) 'continue) ((1) 'pause)
                               ((2) (if (pair? keys) (car keys) 'continue))
                               (else (cons 'boom #f)))))     ; explicit failure
                (loop (cdr cds) s2 (cons (cons (callback-declaration-name cd) (list outcome 'continue 'continue)) acc))))))))

  ;; ============ 7. disagreement ===============================================
  ;; Exported for Slice ③ (0033 item 4): the caller-chosen `check-fail` detail the
  ;; saver will render. Not called in this slice's lane, which asserts agreement
  ;; per machine with `check-equal` and needs no free-text detail.
  (define (disagreement->detail verdict)
    (if (eq? verdict 'none) "expected none, got none"
        (string-append "expected none, got " (write-to-string verdict))))
  (define (write-to-string v) (call-with-string-output-port (lambda (p) (write v p))))

  ;; ============ 8. rejection ledger ===========================================
  ;; MOVED (Slice ④, F13): the record, `make-rejection*` and the accessors now live
  ;; in the executor-free `(byte-machine test rejection-ledger)`, imported above and
  ;; RE-EXPORTED from this library (the export list is unchanged, so nothing that
  ;; reads the driver moves). It moved because Slice ④'s rejections program must have
  ;; no executor in scope (§4.5 / §22.6:1297) and THIS driver imports all three
  ;; executors; a ledger left here would drag them into that program's manifest. Its
  ;; receiver, decision 0033 item 1 -- "rejected draws are counted by code and kept"
  ;; -- is `property-rejections-tests.sps`, which imports the small library directly.

  ;; ============ 9. Layer 2 -- the normalized-form comparators (§22.5:1287/:1289)
  (define (coalesce-fragments trace)
    ;; ONE coalescer, TOTAL: one concatenation per logical span, emitted even when
    ;; empty. Trace elements are fresh bytevectors + 'complete markers. The tree's
    ;; OTHER coalescer (the counted-span one) drops a trailing zero-length run; this
    ;; one does not -- so a span that produced no fragment in one schedule and one
    ;; empty fragment in another still normalizes to the SAME shape, or the
    ;; invariance below would be about nothing.
    (let loop ((t trace) (cur '()) (out '()))
      (cond ((null? t) (reverse (if (null? cur) out (cons (concat (reverse cur)) out))))
            ((eq? (car t) 'complete) (loop (cdr t) '() (cons 'complete (cons (concat (reverse cur)) out))))
            (else (loop (cdr t) (cons (car t) cur) out)))))
  (define (concat bs)
    (let* ((n (fold-left (lambda (k b) (+ k (bytevector-length b))) 0 bs)) (out (make-bytevector n)))
      (let put ((l bs) (at 0))
        (if (null? l) out
            (begin (bytevector-copy! (car l) 0 out at (bytevector-length (car l)))
                   (put (cdr l) (+ at (bytevector-length (car l)))))))))
  ;; The two combinators the negative sentinels are asserted with: a normalized
  ;; form INVARIANT across schedules is `(= (distinct-count …) 1)`; the raw trace
  ;; NOT invariant is `(> (distinct-count …) 1)`.
  (define (distinct xs) (reverse (fold-left (lambda (a x) (if (member x a) a (cons x a))) '() xs)))
  (define (distinct-count xs) (length (distinct xs)))

  ;; Drive a fixture (both "lanes" the SAME executor, so they agree by
  ;; construction) through EVERY schedule of one input, with the callbacks bound
  ;; and no drawn outcomes (all continue). Returns one record per schedule:
  ;;   #(steps coalesced cbtrace raws span-trace)
  ;; -- the substrate the lane's Layer-2/3 fixture assertions read.
  (define (observe-fixture cm cbs fnames input)
    (let-values (((scheds _s) (schedules-for input (make-prng 1))))
      (map (lambda (sch)
             (let-values (((rl gl sr sg bad)
                           (run-schedule cm cm cbs sch fnames (map callback-declaration-name cbs) '())))
               (let ((raws ((lane-dreader rl))))
                 (vector sr (coalesce-fragments raws) ((lane-creader rl)) raws ((lane-sreader rl))))))
           scheds)))
  (define (fx-steps r) (vector-ref r 0))
  (define (fx-coalesced r) (vector-ref r 1))
  (define (fx-cbtrace r) (vector-ref r 2))
  (define (fx-raws r) (vector-ref r 3))
  (define (fx-span r) (vector-ref r 4))
  ;; The malformed-input Layer-2 tuple: (status, absolute-offset, error-code) from
  ;; the LAST step -- §22.5:1289's "error category is parser-error-code, not the
  ;; declaration name", the reading that matters for a machine whose declaration
  ;; names are drawn and whose codes are not. The full trace is deliberately OMITTED.
  (define (fx-final3 r)
    (let* ((t (step-tuple (last-elt (fx-steps r)))) (e (tup-error t)))
      (list (tup-status t) (tup-offset t) (and (pair? e) (cadr e)))))

  ;; ============ 10. Layer 3 -- the six invariant rows (F23, §12.2/§16.2/§14) ===
  ;; check-invariants reads ONE lane's step sequence (the oracle is a single-lane
  ;; property; Layer 1 already proved the lanes agree), plus the logical input
  ;; (row 6 content) and the rich span trace (row 6 anchors). It returns
  ;;   (values verdict applicable)
  ;; where verdict is 'none or (rowN . detail) -- the FIRST violation in row order
  ;; -- and applicable is the subset of `invariant-rows` this trial exercised, so a
  ;; totality sentinel can tell "held" from "never driven". Each row reads the
  ;; tuple independently, so inverting one row's comparison reddens EXACTLY itself.
  (define invariant-rows '(row1 row2 row3 row4 row5 row6))
  (define (last-elt xs) (if (null? (cdr xs)) (car xs) (last-elt (cdr xs))))
  (define (check-invariants m steps input span-trace)
    ;; row 1 (§12.2 + §16.2:909): a sticky life (stopped|error|finished) returns
    ;; that same status; a finish! from ready|finish-ready never returns `stopped`
    ;; (the verifier's :908/:909 completeness, not a runtime property). poisoned /
    ;; busy / the paused cells are NOT driven by the schedule alphabet and are not
    ;; asserted vacuously.
    (define (row1)
      (let loop ((ss steps) (app #f) (v #f))
        (if (or v (null? ss)) (values app v)
            (let* ((s (car ss)) (life (step-life s)) (op (step-op s)) (st (tup-status (step-tuple s))))
              (cond
               ((memq life '(stopped error finished))
                (loop (cdr ss) #t (if (eq? st life) #f (list 'sticky life op st))))
               ((and (eq? op 'finish) (memq life '(ready finish-ready)))
                (loop (cdr ss) #t (if (eq? st 'stopped) (list 'finish-reached-stop life) #f)))
               (else (loop (cdr ss) app #f)))))))
    ;; row 2 (§9.3 cursor arithmetic, feed- vs finish-originated): a feed consumes
    ;; (next - start); a finish reports consumed 0 and next = the stream offset. The
    ;; `finished next 5 consumed 0 offset 5` digest is DROPPED, not repeated (F23).
    (define (row2)
      (let loop ((ss steps) (app #f) (v #f))
        (if (or v (null? ss)) (values app v)
            (let* ((s (car ss)) (t (step-tuple s)) (nx (tup-next t)) (cn (tup-consumed t)) (off (tup-offset t)))
              (if (eq? (step-op s) 'feed)
                  (loop (cdr ss) #t (if (= cn (- nx (step-start s))) #f (list 'feed-cursor (step-start s) nx cn)))
                  (loop (cdr ss) #t (if (and (= cn 0) (= nx off)) #f (list 'finish-cursor nx cn off))))))))
    ;; row 3 (sticky feeds): a feed on a terminal returns consumed 0, next = start,
    ;; offset unchanged. The schedule alphabet issues feeds at NONZERO starts
    ;; (sub-slice, padded), so next = start is distinguishable from next = 0.
    (define (row3)
      (let loop ((ss steps) (prev-off #f) (app #f) (v #f))
        (if (or v (null? ss)) (values app v)
            (let* ((s (car ss)) (t (step-tuple s)) (off (tup-offset t)))
              (if (and (eq? (step-op s) 'feed) (memq (step-life s) '(stopped error finished)))
                  (loop (cdr ss) off #t
                        (if (and (= (tup-consumed t) 0) (= (tup-next t) (step-start s))
                                 (or (not prev-off) (= off prev-off)))
                            #f (list 'sticky-feed (step-start s) (tup-next t) (tup-consumed t))))
                  (loop (cdr ss) off app #f))))))
    ;; row 4 ([0, 2^width)): every field value stays inside its declared width at
    ;; every step. The tuple's field list is in machine-fields order (fnames =
    ;; (map uint-field-name (manifest-fields …)) = the same map over the same specs).
    (define (row4)
      (let* ((flds (machine-fields m)) (widths (map uint-field-width flds)))
        (if (or (null? flds) (null? steps)) (values #f #f)
            (let loop ((ss steps) (v #f))
              (if (or v (null? ss)) (values #t v)
                  (let scan ((vs (tup-fields (step-tuple (car ss)))) (ws widths))
                    (cond ((or (null? vs) (null? ws)) (loop (cdr ss) v))
                          ((let ((x (car vs)) (w (car ws))) (or (< x 0) (>= x (expt 2 w))))
                           (loop (cdr ss) (list 'field-range (car vs) (car ws))))
                          (else (scan (cdr vs) (cdr ws))))))))))
    ;; row 5 (§16.2:908): a `finished` status from parser-feed! is legal only when
    ;; the lifecycle before was already finished (a sticky feed). A live feed
    ;; reaching a finish node is the :908 hole -- kept out by the verifier, not the
    ;; runtime, which is why this is a completeness property.
    (define (row5)
      (let loop ((ss steps) (app #f) (v #f))
        (if (or v (null? ss)) (values app v)
            (let* ((s (car ss)) (st (tup-status (step-tuple s))))
              (if (eq? st 'finished)
                  (loop (cdr ss) #t
                        (if (and (eq? (step-op s) 'feed) (not (eq? (step-life s) 'finished)))
                            (list 'feed-finished (step-life s)) #f))
                  (loop (cdr ss) app #f))))))
    ;; row 6 (F23, the span row): (i) content at absolute offsets; (ii) contiguity
    ;; and order within one logical span; (iii) the end anchor = parser-stream-offset
    ;; inside the span-complete callback. THREE inapplicability conditions: not at an
    ;; error (§14:839); not when the fragment step short-circuits (no frag recorded --
    ;; an unbound data callback; since decision 0042 an empty span DELIVERS a
    ;; zero-length fragment, so it is now IN scope for row 6 -- af==at at the span's
    ;; offset, and the end anchor still holds); and -- this plan's own addition --
    ;; not when no span-complete callback is bound, in which case (iii) is dropped
    ;; and (i)+(ii) stand.
    (define (row6)
      (let* ((last-tup (and (pair? steps) (step-tuple (last-elt steps))))
             (final (and last-tup (tup-status last-tup)))
             (span-open? (and last-tup (tup-span last-tup) #t))  ; a span still open at trial end
             (frags? (exists (lambda (e) (eq? (car e) 'frag)) span-trace)))
        (if (or (eq? final 'error) (not frags?))
            (values #f #f)
            (let loop ((gs (span-groups span-trace)) (v #f))
              (if (or v (null? gs)) (values #t v)
                  (loop (cdr gs) (check-group input m (car gs) span-open?)))))))
    (let-values (((a1 v1) (row1)) ((a2 v2) (row2)) ((a3 v3) (row3))
                 ((a4 v4) (row4)) ((a5 v5) (row5)) ((a6 v6) (row6)))
      (values (cond (v1 (cons 'row1 v1)) (v2 (cons 'row2 v2)) (v3 (cons 'row3 v3))
                    (v4 (cons 'row4 v4)) (v5 (cons 'row5 v5)) (v6 (cons 'row6 v6)) (else 'none))
              (append (if a1 '(row1) '()) (if a2 '(row2) '()) (if a3 '(row3) '())
                      (if a4 '(row4) '()) (if a5 '(row5) '()) (if a6 '(row6) '())))))
  ;; group the rich span trace into (#(frags span-name coff) …). frags are
  ;; (abs-from abs-to bytes) in emission order, from ONE span; span-name is which
  ;; span they came from; coff is the completion offset when the group ended in a
  ;; 'complete, else #f (a span with no completion callback -- e.g. spanbare -- or
  ;; one still open). A span-name change with no intervening 'complete also closes
  ;; a group, so fragments of a callback-less span are never merged with the next.
  (define (span-groups tr)
    (let loop ((tr tr) (cur '()) (sp #f) (out '()))
      (define (flush coff) (if (null? cur) out (cons (vector (reverse cur) sp coff) out)))
      (cond
       ((null? tr) (reverse (flush #f)))
       ((eq? (car (car tr)) 'complete) (loop (cdr tr) '() #f (flush (cadr (car tr)))))
       (else
        (let* ((rec (car tr)) (s (list-ref rec 4)) (payload (list (cadr rec) (caddr rec) (cadddr rec))))
          (if (or (null? cur) (eq? s sp))
              (loop (cdr tr) (cons payload cur) s out)
              (loop (cdr tr) (list payload) s (flush #f))))))))
  (define (span-has-complete? m name)
    (let loop ((ss (machine-spans m)))
      (cond ((null? ss) #f)
            ((eq? (span-declaration-name (car ss)) name) (and (span-declaration-complete-callback (car ss)) #t))
            (else (loop (cdr ss))))))
  ;; g = #(frags span-name coff); span-open? = a span was still active at trial end.
  (define (check-group input m g span-open?)
    (let ((frags (vector-ref g 0)) (span-name (vector-ref g 1)) (coff (vector-ref g 2)))
      (if (null? frags) #f
          (or
           ;; (i) content = input[abs-from, abs-to)
           (let iloop ((fs frags))
             (cond ((null? fs) #f)
                   ((not (bytes=at? input (caar fs) (cadar fs) (caddar fs)))
                    (list 'span-content (caar fs) (cadar fs)))
                   (else (iloop (cdr fs)))))
           ;; (ii) contiguity: each fragment's abs-from = the previous fragment's abs-to
           (let cloop ((fs (cdr frags)) (prev (cadr (car frags))))
             (cond ((null? fs) #f)
                   ((not (= (car (car fs)) prev)) (list 'span-gap prev (car (car fs))))
                   (else (cloop (cdr fs) (cadr (car fs))))))
           ;; (iii) end anchor -- DROPPED when THIS span has no completion callback
           ;; (this plan's third inapplicability condition, judged per span). With one
           ;; bound: a group that ended in a completion anchors its last fragment at
           ;; the completion offset; a group that ended WITHOUT one is a span that
           ;; CLOSED with no completion -- the violation -- but only when no span is
           ;; still open (a span abandoned open at a non-error terminal legitimately
           ;; fires none). Dropping the per-span guard reddens spanbare.
           (and (span-has-complete? m span-name)
                (if coff
                    (and (not (= (cadr (last-elt frags)) coff))
                         (list 'span-end-anchor coff (cadr (last-elt frags))))
                    (and (not span-open?) (list 'span-not-completed (caar frags)))))))))
  (define (bytes=at? input af at bytes)
    (and (>= af 0) (<= at (bytevector-length input)) (= (- at af) (bytevector-length bytes))
         (let bl ((i 0))
           (or (= i (bytevector-length bytes))
               (and (= (bytevector-u8-ref bytes i) (bytevector-u8-ref input (+ af i))) (bl (+ i 1))))))))
