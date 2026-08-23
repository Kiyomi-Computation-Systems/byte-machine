;;; A bounded generator of VALID M1-shaped machines (parent §22.6): entry is a
;;; byte-dispatch node whose cases are distinct bytes (non-overlapping by
;;; construction) targeting stop/error/self, plus a fallback; two terminals. It
;;; never emits an invalid graph — verifier rejection has its own tests
;;; (verify-tests.sps). State is threaded from (byte-machine test prng).
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
;;;     true for the entry node (verify.sls:134-141).
;;;   - the FIRST generated case always targets `stop` (with `advance`, so it
;;;     also proves an accepting path exists). Without this, a machine whose
;;;     every case happens to draw {reject, start} leaves `stop` unreachable
;;;     from the entry, which pass-reachability rejects (verify.sls:110-121).
;;;     `reject` needs no equivalent guarantee: the node's fixed fallback edge
;;;     `(make-edge 'reject 'reexecute)` always reaches it regardless of what
;;;     the cases draw.
(library (byte-machine test machine-gen)
  (export gen-machine)
  (import (rnrs)
          (byte-machine test prng)
          (byte-machine graph))

  (define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
  (define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
  ;; targets a dispatch case may point at: the two terminals or back to entry.
  (define targets '#(stop reject start))
  (define modes '#(advance reexecute))

  ;; Draw n DISTINCT bytes in [0,256).
  (define (distinct-bytes s n)
    (let loop ((s s) (need n) (acc '()))
      (if (= need 0) (values (reverse acc) s)
          (let-values (((b s2) (prng-next s 256)))
            (if (memv b acc) (loop s2 need acc)
                (loop s2 (- need 1) (cons b acc)))))))

  ;; Draw a target/mode pair for one byte, forcing `advance` whenever the
  ;; drawn target is `start` (see the zero-progress-cycle note above).
  (define (gen-case s b)
    (let*-values (((ti s1) (prng-next s (vector-length targets)))
                  ((mi s2) (prng-next s1 (vector-length modes))))
      (let* ((target (vector-ref targets ti))
             (mode (if (eq? target 'start) 'advance (vector-ref modes mi))))
        (values (make-byte-case (make-exact-byte-matcher b) (make-edge target mode) #f)
                s2))))

  ;; The first byte's case is pinned to (stop . advance), guaranteeing `stop`
  ;; is reachable (see the reachability note above); every other case draws
  ;; freely via gen-case.
  (define (gen-cases s bytes)
    (let loop ((s s) (bs bytes) (first? #t) (acc '()))
      (cond
        ((null? bs) (values (reverse acc) s))
        (first?
         (let ((c (make-byte-case (make-exact-byte-matcher (car bs))
                                  (make-edge 'stop 'advance) #f)))
           (loop s (cdr bs) #f (cons c acc))))
        (else
         (let-values (((c s2) (gen-case s (car bs))))
           (loop s2 (cdr bs) #f (cons c acc)))))))

  ;; 1..4 dispatch cases; a reexecute fallback to the error terminal.
  (define (gen-machine s)
    (let*-values (((ncell s1) (prng-next s 4))
                  ((bytes s2) (distinct-bytes s1 (+ 1 ncell)))
                  ((cases s3) (gen-cases s2 bytes)))
      (values
       (make-machine 'gen 'start '() '() '() (list eof-decl rej-decl)
         (list (make-byte-dispatch-node 'start cases
                 (make-edge 'reject 'reexecute) #f #f)
               (make-stop-node 'stop #f)
               (make-error-node 'reject 'rejected #f))
         'default-eof #f)
       s3))))
