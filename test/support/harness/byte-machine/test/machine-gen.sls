;;; A bounded generator of VALID machines (parent §22.6, M2 Slice ③): entry is
;;; a byte-dispatch node whose cases are distinct bytes (non-overlapping by
;;; construction) targeting stop/error/self/pausep, plus a fallback; the two
;;; fixed terminals (stop, reject) plus two optional Slice ③ additions -- an
;;; idle-completion finish node and an explicit pause. It never emits an
;;; invalid graph -- verifier rejection has its own tests (verify-tests.sps).
;;; State is threaded from (byte-machine test prng).
;;;
;;; Two constraints were added over the first-draft "draw everything freely"
;;; shape after Step 5 (running the property lane against the reference
;;; verifier) showed real verify-machine rejections across the seed's 40
;;; machines:
;;;
;;;   - a case that targets `start` is forced to mode `advance`. `reexecute`
;;;     would make `start` a reexecute-only self-loop -- a zero-progress
;;;     cycle that (byte-machine verify)'s pass-zero-progress rejects, since a
;;;     case with (target . start) is by itself enough to make `reaches-self?`
;;;     true for the entry node (`reaches-self?` in `pass-zero-progress`,
;;;     verify.sls -- named rather than cited by line, because the two line
;;;     ranges this comment used to carry had both drifted onto `pass-names`).
;;;   - the FIRST generated case always targets `stop` (with `advance`, so it
;;;     also proves an accepting path exists). Without this, a machine whose
;;;     every case happens to draw {reject, start} leaves `stop` unreachable
;;;     from the entry, which `pass-reachability` (verify.sls) rejects.
;;;     `reject` needs no equivalent guarantee: the node's fixed fallback edge
;;;     `(make-edge 'reject 'reexecute)` always reaches it regardless of what
;;;     the cases draw.
;;;
;;; M2 Slice ③ adds two more draws (gen-machine) and a third constraint beside
;;; them, for the same reason as the two above: an unreachable or unsafe node
;;; is a verify-machine rejection, and the property lane's whole point is that
;;; it never manufactures one.
;;;
;;;   - the eof draw adds a finish node `done` as the entry's eof-target in
;;;     half the draws (else the eof-target stays #f, as before Slice ③).
;;;   - the pause draw extends the free cases' target vocabulary with
;;;     `pausep` in half the draws, independently of the eof draw. See the
;;;     by-construction safety argument above gen-machine for what makes a
;;;     BYTE-REACHABLE pausep safe.
;;; Milestone 4 Slice ③ adds a third draw on the same terms: an
;;; integer-accumulate node `accp`, the milestone's only INPUT-READING kind, and
;;; with it the generator's first declared field.
;;;
;;;   - the case that reaches `accp` for real is pinned to mode `reexecute`, the
;;;     opposite of the rule for `start` and `pausep`, for a reason particular to
;;;     how the property lane drives: byte-trial builds a FRESH parser pair and
;;;     feeds EXACTLY ONE byte. An `advance` inbound edge would consume that byte
;;;     at the dispatch, leaving the accumulate node nothing to read, and the
;;;     draw would exercise only the EOF path -- a node reached but never run.
;;;     `reexecute` re-presents the same byte to `accp`, which is what makes the
;;;     digit and overflow arms reachable at all here.
;;;
;;;     That pin lives on the PINNED case in gen-machine, not in gen-case. Free
;;;     cases that happen to draw `accp` draw their mode freely: pinning them too
;;;     was tried, and the mutant that unpinned them survived the whole release
;;;     selection, because with the digit case pinned those cases only decide
;;;     which arm an arbitrary non-digit byte takes.
;;;
;;;     That does not reintroduce the zero-progress cycle the `start` rule
;;;     avoids. `accp` ADVANCES on its digit edge (its digit-target is itself),
;;;     its non-digit edge advances to `stop`, and its only zero-width successor
;;;     is the overflow error node -- a terminal. So no cycle of zero-width steps
;;;     can pass through it, whatever the cases draw.
;;;
;;;   - the field's initial is 25, and 25 is the ONLY value that makes both of
;;;     `accp`'s interesting arms reachable within the single byte this lane
;;;     feeds. A u8 caps at 255. At 25, `5` accumulates to 255 and `9` overflows;
;;;     at 24 no digit overflows (249 fits), and at 26 every digit does (260
;;;     does not), so either neighbour makes one arm dead. Stated because it
;;;     looks like an arbitrary constant and is not.
;;;
;;;   - one case is PINNED to a drawn ASCII digit targeting `accp`, the same way
;;;     the first case is pinned to `stop`, and for a reason the `reexecute` rule
;;;     above creates: a reexecute inbound edge means `accp` only ever sees the
;;;     case byte that routed to it. Left to the free draw, that byte is a digit
;;;     about ten times in 256, so across a whole seed set the digit and overflow
;;;     arms would almost never run -- the node would be reached, and only its
;;;     NON-digit arm exercised. Pinning one digit case makes all three arms
;;;     reachable and makes which one runs a function of the drawn digit: with
;;;     the initial at 25, digits 0-5 accumulate and 6-9 overflow.
;;;
;;;     Free cases may still target `accp` and are still forced to `reexecute`;
;;;     those carry arbitrary bytes and exercise the non-digit arm. The pinned
;;;     case also removes the reachability question `pausep` has: `accp` is
;;;     reachable whenever it is drawn, so it needs no was-it-actually-used
;;;     report.
;;;
;;;   - overflow routes to its OWN error node and declaration, reason "field
;;;     overflow", rather than sharing the `rejected` terminal. Sharing would
;;;     make an overflow indistinguishable from an ordinary fallback rejection in
;;;     both the differential's projected reason and the property lane's
;;;     anti-vacuity counters, and the overflow arm would have no witness that it
;;;     ran at all. Both are added only alongside `accp`.
;;;
;;;   - the third constraint is reachability itself. Unlike `stop` (pinned to
;;;     the first case) and `start` (the entry, always reached before any
;;;     edge is followed), nothing guarantees a free case ever draws
;;;     `pausep`: a machine with zero free cases (ncell = 0), or one whose
;;;     free cases all happen to draw {stop, reject, start}, offers `pausep`
;;;     no inbound edge at all, and pass-reachability rejects an unreached
;;;     node regardless of why it is unreached. So gen-cases reports back
;;;     whether any case actually drew `pausep`, and gen-machine adds the
;;;     `pausep` node ONLY when that is true -- an unreachable pausep is
;;;     never constructed, rather than constructed and hoped against.
(library (byte-machine test machine-gen)
  (export gen-machine)
  (import (rnrs)
          (byte-machine test prng)
          (byte-machine graph))

  (define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
  (define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
  ;; Slice ③: overflow's own declaration, so an overflow is distinguishable from
  ;; an ordinary fallback rejection in the compared projection. Declared only on
  ;; machines that draw the accumulate node -- an unreached declaration would sit
  ;; in the source errs table but not in the encoding's reached-declaration
  ;; table, which is decision 0022 item 7's open question and not something this
  ;; generator should be exercising by accident.
  (define over-decl (make-error-declaration 'overflowed 'unexpected-byte "field overflow" #f))
  ;; targets a dispatch case may point at: the two terminals, back to entry,
  ;; or (pause-targets only) the Slice ③ pause -- see gen-machine.
  (define base-targets '#(stop reject start))
  (define pause-targets '#(stop reject start pausep))
  (define modes '#(advance reexecute))

  ;; The four draw combinations, built rather than tabulated. With the
  ;; accumulate draw off these are exactly base-targets and pause-targets, and
  ;; the vector LENGTHS are what the draw reads, so a machine drawn without the
  ;; accumulate node draws its cases from the same distribution as before.
  (define (targets-for pause? acc?)
    (list->vector (append '(stop reject start)
                          (if pause? '(pausep) '())
                          (if acc? '(accp) '()))))

  ;; Draw n DISTINCT bytes in [0,256), avoiding anything in `taken`. The
  ;; exclusion is Slice ③'s: the pinned accumulate case reserves a digit before
  ;; these are drawn, and a dispatch whose cases repeated a byte would be a
  ;; generated INVALID machine -- the one thing this generator must never do.
  (define (distinct-bytes s n taken)
    (let loop ((s s) (need n) (acc '()))
      (if (= need 0) (values (reverse acc) s)
          (let-values (((b s2) (prng-next s 256)))
            (if (or (memv b acc) (memv b taken)) (loop s2 need acc)
                (loop s2 (- need 1) (cons b acc)))))))

  ;; Draw a target/mode pair for one byte from `targets`, forcing `advance`
  ;; whenever the drawn target is `start` (see the zero-progress-cycle note
  ;; above) or `pausep` (same rule, extended by Slice ③ -- see the
  ;; by-construction argument above gen-machine). Also returns whether this
  ;; case drew `pausep`, threaded back through gen-cases so gen-machine knows
  ;; whether including the pause node would actually be reachable.
  (define (gen-case s b targets)
    (let*-values (((ti s1) (prng-next s (vector-length targets)))
                  ((mi s2) (prng-next s1 (vector-length modes))))
      (let* ((target (vector-ref targets ti))
             (mode (if (or (eq? target 'start) (eq? target 'pausep))
                       'advance
                       ;; Slice ③ deliberately does NOT pin `accp` here. A free
                       ;; case's mode was pinned to `reexecute` in a first
                       ;; version and the mutant that unpinned it SURVIVED the
                       ;; whole release selection -- the pin that carries the
                       ;; behaviour is on the constructed digit case in
                       ;; gen-machine, and this one only decided which arm
                       ;; arbitrary non-digit bytes take. An unwitnessed pin
                       ;; reads as a load-bearing constraint and is not one, so
                       ;; it is gone and the mode is drawn. Zero-progress is
                       ;; unaffected either way: `accp`'s only zero-width
                       ;; successor is its overflow terminal.
                       (vector-ref modes mi))))
        (values (make-byte-case (make-exact-byte-matcher b) (make-edge target mode) #f)
                (eq? target 'pausep)
                s2))))

  ;; The first byte's case is pinned to (stop . advance), guaranteeing `stop`
  ;; is reachable (see the reachability note above); every other case draws
  ;; freely via gen-case, from `targets`. Returns (values cases pausep-used?
  ;; state) -- pausep-used? is #t iff some non-pinned case drew `pausep`.
  (define (gen-cases s bytes targets)
    (let loop ((s s) (bs bytes) (first? #t) (pausep-used? #f) (acc '()))
      (cond
        ((null? bs) (values (reverse acc) pausep-used? s))
        (first?
         (let ((c (make-byte-case (make-exact-byte-matcher (car bs))
                                  (make-edge 'stop 'advance) #f)))
           (loop s (cdr bs) #f pausep-used? (cons c acc))))
        (else
         (let-values (((c pused? s2) (gen-case s (car bs) targets)))
           (loop s2 (cdr bs) #f (or pausep-used? pused?) (cons c acc)))))))

  ;; Slice ③ draws: an idle-completion eof route and an explicit pause.
  ;; done (finish) joins the graph only when drawn as the entry eof-target,
  ;; so it is never byte-reachable (§16.2:908 holds by construction).
  ;; pausep's continuation is 'start: the walk from a byte-reachable pause's
  ;; continuation (D4(d)) lands on the entry dispatch, whose eof route is a
  ;; finish, an error, or the machine default -- never a stop -- so §16.2:909
  ;; holds by construction (a continuation of 'stop would be rejected).
  ;; Every case targeting pausep is forced to advance (same rule as
  ;; target-'start), so no zero-width cycle can form through it.
  ;;
  ;; 1..4 dispatch cases; a reexecute fallback to the error terminal. The eof
  ;; and pause draws are independent of each other and of ncell/bytes below;
  ;; `pausep` itself is added only when gen-cases reports it was actually
  ;; drawn by some case (the third constraint in the header comment above).
  ;; Returns (values machine field-names state). The field-name list is new in
  ;; Slice ③ and is not decoration: the property lane's oracle compares parser
  ;; results, and a field value is not one of them, so an accumulate draw would
  ;; otherwise compare nothing about what the node actually computed. The names
  ;; travel with the machine because (byte-machine graph) does not export
  ;; `machine-fields`, so the lane cannot recover them from the machine itself.
  (define (gen-machine s)
    (let*-values (((eofi s1) (prng-next s 2))
                  ((pausei s2) (prng-next s1 2))
                  ((acci s2b) (prng-next s2 2))
                  ;; Drawn unconditionally, so the accumulate draw costs the same
                  ;; two numbers whichever way it lands and the state after this
                  ;; point does not depend on it. The digit only reaches the
                  ;; machine when `acc-drawn?`.
                  ((digit s2c) (prng-next s2b 10))
                  ((ncell s3) (prng-next s2c 4))
                  ((bytes s4) (distinct-bytes s3 (+ 1 ncell)
                                              (if (= acci 0) (list (+ 48 digit)) '()))))
      (let* ((eof? (= eofi 0))
             (pause-drawn? (= pausei 0))
             (acc-drawn? (= acci 0)))
        (let-values (((cases pausep-used? s5)
                      (gen-cases s4 bytes (targets-for pause-drawn? acc-drawn?))))
          (values
           (make-machine 'gen 'start
             (if acc-drawn? (list (make-uint-field 'n 8 25 #f)) '())
             '() '()
             (if acc-drawn? (list eof-decl rej-decl over-decl) (list eof-decl rej-decl))
             (append
              (list (make-byte-dispatch-node 'start
                      ;; The pinned digit case is appended, not prepended: the
                      ;; FIRST case is `stop`'s and that pin is load-bearing for
                      ;; reachability (see the header). Order within the case
                      ;; list is otherwise immaterial -- the bytes are distinct,
                      ;; so the cases are non-overlapping by construction.
                      (if acc-drawn?
                          (append cases
                                  (list (make-byte-case
                                         (make-exact-byte-matcher (+ 48 digit))
                                         (make-edge 'accp 'reexecute) #f)))
                          cases)
                      (make-edge 'reject 'reexecute)
                      (if eof? 'done #f) #f)
                    (make-stop-node 'stop #f)
                    (make-error-node 'reject 'rejected #f))
              (if eof? (list (make-finish-node 'done #f)) '())
              (if pausep-used? (list (make-pause-node 'pausep 'start #f)) '())
              ;; Digit-target is itself and advances; the non-digit edge advances
              ;; to `stop`; overflow routes to its own error terminal. The only
              ;; zero-width successor is that terminal, which is what makes the
              ;; `reexecute` inbound edge safe -- see the header comment.
              (if acc-drawn?
                  (list (make-integer-accumulate-node 'accp 'n 10 'accp
                                                      (make-edge 'stop 'advance)
                                                      'accover #f #f)
                        (make-error-node 'accover 'overflowed #f))
                  '()))
             'default-eof #f)
           (if acc-drawn? '(n) '())
           s5))))))
