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
  ;; targets a dispatch case may point at: the two terminals, back to entry,
  ;; or (pause-targets only) the Slice ③ pause -- see gen-machine.
  (define base-targets '#(stop reject start))
  (define pause-targets '#(stop reject start pausep))
  (define modes '#(advance reexecute))

  ;; Draw n DISTINCT bytes in [0,256).
  (define (distinct-bytes s n)
    (let loop ((s s) (need n) (acc '()))
      (if (= need 0) (values (reverse acc) s)
          (let-values (((b s2) (prng-next s 256)))
            (if (memv b acc) (loop s2 need acc)
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
         (let-values (((c used? s2) (gen-case s (car bs) targets)))
           (loop s2 (cdr bs) #f (or pausep-used? used?) (cons c acc)))))))

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
  (define (gen-machine s)
    (let*-values (((eofi s1) (prng-next s 2))
                  ((pausei s2) (prng-next s1 2))
                  ((ncell s3) (prng-next s2 4))
                  ((bytes s4) (distinct-bytes s3 (+ 1 ncell))))
      (let* ((eof? (= eofi 0))
             (pause-drawn? (= pausei 0)))
        (let-values (((cases pausep-used? s5)
                      (gen-cases s4 bytes (if pause-drawn? pause-targets base-targets))))
          (values
           (make-machine 'gen 'start '() '() '() (list eof-decl rej-decl)
             (append
              (list (make-byte-dispatch-node 'start cases
                      (make-edge 'reject 'reexecute)
                      (if eof? 'done #f) #f)
                    (make-stop-node 'stop #f)
                    (make-error-node 'reject 'rejected #f))
              (if eof? (list (make-finish-node 'done #f)) '())
              (if pausep-used? (list (make-pause-node 'pausep 'start #f)) '()))
             'default-eof #f)
           s5))))))
