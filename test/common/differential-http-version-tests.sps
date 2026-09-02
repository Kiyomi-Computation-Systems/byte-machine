;;; interpreter ≡ generated over a MULTI-ALTERNATIVE sequence node (parent §18,
;;; §22.4, §22.5). Slice ② pinned the trie merge structurally (normal-ir-tests)
;;; and executed it through the interpreter (interpret-tests), but its
;;; DIFFERENTIAL drove a single alternative -- so no lane has compared the two
;;; EXECUTORS across a branch: two alternatives sharing `HTTP/1.` descend into
;;; one chain and part at one state, and a lowering that LOSES one of them --
;;; leaving the interpreter accepting what the emitted library rejects -- is
;;; caught here and not by the single-alternative differential, where a one-arm
;;; state and a truncated one-arm state are the same state. Measured, not
;;; assumed: SchemeMutationSuite Pass 48's two mutants leave
;;; differential-sequence-node-tests.sps at failures=0 status=0.
;;; The narrower claim is deliberate. A lowering defect that resumed into the
;;; wrong prefix state across a feed boundary is NOT this lane's alone -- an
;;; earlier draft of this header said it was, and measurement says otherwise:
;;; rendering the need-input resume id as the entry state instead of the
;;; current one reddens differential-sequence-node-tests.sps as well
;;; (failed-cases=9 failures=10), because a single-alternative chain has prefix
;;; states to resume into too. What needs a BRANCH is losing an alternative.
;;;
;;; Agreement alone cannot carry the lane -- both executors read the same source
;;; IR -- so the absolute tuples live in http-version-interpret-tests.sps and the
;;; groups below assert AGREEMENT, plus one generated-side absolute per mismatch
;;; mode. The exhaustive group's own value is 256 bytes at all eight prefix
;;; positions in both modes, which no fixed set of literal tuples could replace.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine test http-version-machine)
        (byte-machine test prng)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

;; Slice ①a task 5: the tuple carries the §22.4:1271 projection. A reexecute
;; mismatch reports `byte` AT the offending byte; an advance mismatch reports
;; `boundary` after the committed one. Same error node, different arriving
;; transition, different position kind -- which is decision 0022's whole point.
(define (reject-at k) (list 'machine 'unexpected-byte "unexpected byte" 'reject k 'byte))
(define (advance-reject-at k)
  (list 'machine 'unexpected-byte "unexpected byte" 'reject k 'boundary))

(harness-begin "differential.http-version")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-http-version
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; The binding is derived from `name`; the LIBRARY name is not -- emit-machine
;; draws it from the compiled machine's own machine-name field, so this call
;; only works while the fixture passes the same symbol to make-machine.
;; (environment (list 'generated name)) is what fails loudly if they diverge.
(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (project-error (parser-result-error r))))
(define (u8 b) (make-bytevector 1 b))
(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (drop-n l k) (if (= k 0) l (drop-n (cdr l) (- k 1))))
(define (run-slices cm slices)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss) last
          (loop (cdr ss)
                (rfields (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))))))))
(define (drive cm prefix b)
  (run-slices cm (append (map (lambda (x) (list (u8 x) 0 1)) prefix)
                         (list (list (u8 b) 0 1)))))
;; One slice per run of bytes between consecutive cuts. `cuts` is ascending and
;; strictly inside (0, length).
(define (slices-for bs cuts)
  (let loop ((start 0) (cs (append cuts (list (length bs)))) (out '()))
    (if (null? cs) (reverse out)
        (let* ((end (car cs))
               (run (head-n (drop-n bs start) (- end start))))
          (loop end (cdr cs)
                (cons (list (u8-list->bytevector run) 0 (length run)) out))))))
(define (schedule->string cuts)
  (string-append "("
                 (fold-left (lambda (acc c)
                              (string-append acc (if (string=? acc "") "" " ")
                                             (number->string c)))
                            "" cuts)
                 ")"))

(define zero-bytes (http-version-bytes 'zero))
(define one-bytes (http-version-bytes 'one))
(define shared (http-version-shared-prefix))
(define re-machine (make-http-version-machine))
(define ad-machine (make-http-version-advance-machine))
(define cm-ref (make-interpreted-machine (verify-machine re-machine)))
(define cm-gen (generated-machine 'http-version re-machine))
(define ad-ref (make-interpreted-machine (verify-machine ad-machine)))
(define ad-gen (generated-machine 'http-version-advance ad-machine))

(harness-group "both alternatives agree at every single-cut split"
  (lambda ()
    (harness-case "seven interior cuts plus the uncut sequence at both ends all agree and accept"
      (lambda ()
        ;; The loop runs k = 0..8, but k=0 and k=8 both take the `'()` branch
        ;; and build the identical single whole-sequence slice, so the nine
        ;; iterations cover EIGHT distinct schedules: seven interior cuts
        ;; (k = 1..7) plus the uncut sequence, driven twice. The counter below
        ;; stays 36 because it counts iterations, not schedules.
        ;;
        ;; SENTINELS: `compared` counts runs the LOOP performed, `accepts`
        ;; counts what the executors RETURNED. A loop that never ran, or an
        ;; executor that stopped accepting, is caught by a different one.
        (let ((bad 'none) (compared 0) (accepts 0))
          (for-each
           (lambda (alt)
             (for-each
              (lambda (cm-pair)
                (let loop ((k 0))
                  (when (<= k 8)
                    (let* ((cuts (if (or (= k 0) (= k 8)) '() (list k)))
                           (ss (slices-for alt cuts))
                           (ri (run-slices (car cm-pair) ss))
                           (rg (run-slices (cdr cm-pair) ss)))
                      (set! compared (+ compared 1))
                      (when (and (equal? ri rg) (eq? (car rg) 'stopped))
                        (set! accepts (+ accepts 1)))
                      (unless (equal? ri rg)
                        (when (eq? bad 'none) (set! bad (list 'disagree k))))
                      (unless (eq? (car rg) 'stopped)
                        (when (eq? bad 'none) (set! bad (list 'not-stopped k)))))
                    (loop (+ k 1)))))
              (list (cons cm-ref cm-gen) (cons ad-ref ad-gen))))
           (list zero-bytes one-bytes))
          (check-equal "nothing disagreed or failed to accept" bad 'none)
          (check-equal "the loop ran 2 alternatives x 2 modes x 9 iterations" compared 36)
          (check-equal "every run accepted, observed from the executors" accepts 36))))
    (harness-case "the cut at the branch boundary is one of them, and is asserted by name"
      (lambda ()
        ;; A cut at offset 7 lands exactly between the shared prefix and the
        ;; distinguishing byte: the resume point a wrong prefix state would
        ;; corrupt. Asserted separately so it is visibly covered, not
        ;; incidentally covered.
        (check-equal "shared prefix is seven bytes" (length shared) 7)
        (check-equal "HTTP/1.0 interpreter"
                     (run-slices cm-ref (slices-for zero-bytes '(7)))
                     (run-slices cm-gen (slices-for zero-bytes '(7))))
        (check-equal "HTTP/1.1 interpreter"
                     (run-slices cm-ref (slices-for one-bytes '(7)))
                     (run-slices cm-gen (slices-for one-bytes '(7))))
        (check-equal "HTTP/1.1 accepts across that cut"
                     (car (run-slices cm-gen (slices-for one-bytes '(7))))
                     'stopped)))))

(harness-group "seeded multi-split schedules agree"
  (lambda ()
    (harness-case "32 draws over both alternatives agree, with at least one genuine multi-split"
      (lambda ()
        (define seed 20260830)
        (let loop ((i 0) (s (make-prng seed)) (multi 0) (bad 'none))
          (if (>= i 32)
              (begin
                (check-equal "no schedule disagreed" bad 'none)
                (check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0)))
              (let*-values (((d1 s1) (prng-next s 2))
                            ((d2 s2) (prng-next s1 2))
                            ((d3 s3) (prng-next s2 2))
                            ((alt s4) (prng-next s3 2)))
                (let* ((cuts (append (if (= d1 1) '(2) '())
                                     (if (= d2 1) '(5) '())
                                     (if (= d3 1) '(7) '())))
                       (bs (if (= alt 0) zero-bytes one-bytes))
                       (ss (slices-for bs cuts))
                       (ri (run-slices cm-ref ss))
                       (rg (run-slices cm-gen ss)))
                  (loop (+ i 1) s4 (+ multi (if (>= (length cuts) 2) 1 0))
                        (if (and (eq? bad 'none)
                                 (or (not (equal? ri rg)) (not (eq? (car rg) 'stopped))))
                            (schedule->string cuts) bad))))))))))

(harness-group "nonzero-offset and empty slices agree"
  (lambda ()
    (define padded (u8-list->bytevector (append '(9) zero-bytes '(9))))
    (harness-case "one nonzero-offset slice accepts identically in both"
      (lambda ()
        (check-equal "agree"
                     (run-slices cm-ref (list (list padded 1 9)))
                     (run-slices cm-gen (list (list padded 1 9))))
        (check-equal "accepted" (car (run-slices cm-gen (list (list padded 1 9)))) 'stopped)))
    (harness-case "an empty slice mid-sequence changes nothing in either"
      (lambda ()
        (let ((ss (list (list (u8-list->bytevector (head-n zero-bytes 4)) 0 4)
                        (list (make-bytevector 0) 0 0)
                        (list (u8-list->bytevector (drop-n zero-bytes 4)) 0 4))))
          (check-equal "agree" (run-slices cm-ref ss) (run-slices cm-gen ss))
          (check-equal "accepted" (car (run-slices cm-gen ss)) 'stopped))))))

(harness-group "interpreter and generated agree on all 256 bytes at every prefix position"
  (lambda ()
    (harness-case "256 x 8 positions match, in both mismatch modes"
      (lambda ()
        ;; SENTINEL: ONE counter over both loops, not one per loop. A byte
        ;; counter and a position counter share a single mutable slot across
        ;; the eight positions, so (last-byte 255, positions 8) is equally
        ;; true of "256 bytes at all eight positions" and of "256 bytes at one
        ;; position and none at the other seven" -- it catches a loop that
        ;; never ran and not a partial inner skip. Counting (position byte)
        ;; drives closes that: 8 x 256 = 2048 is exactly what the group name
        ;; claims, and no partial run reaches it.
        (let ((bad 'none) (drives 0))
          (let pos ((k 0))
            (when (< k 8)
              (let ((prefix (head-n zero-bytes k)))
                (let loop ((b 0))
                  (when (< b 256)
                    (unless (equal? (drive cm-ref prefix b) (drive cm-gen prefix b))
                      (when (eq? bad 'none) (set! bad (list 'reexecute k b))))
                    (unless (equal? (drive ad-ref prefix b) (drive ad-gen prefix b))
                      (when (eq? bad 'none) (set! bad (list 'advance k b))))
                    (set! drives (+ drives 1))
                    (loop (+ b 1)))))
              (pos (+ k 1))))
          (check-equal "no (mode position byte) disagreed" bad 'none)
          (check-equal "the loops ran all 8 x 256 (position byte) drives" drives 2048))))))

;; §11.5:664, asserted ABSOLUTELY on the generated side rather than as agreement:
;; the branch byte is where the two modes visibly differ on a multi-alternative
;; node, and agreement between two wrong executors would look identical.
(harness-group "both mismatch modes at the branch, absolutely, on the generated executor"
  (lambda ()
    (harness-case "reexecute keeps next and consumed at zero and points at the branch byte"
      (lambda ()
        (check-equal "branch" (drive cm-gen shared 50) (list 'error 0 0 7 (reject-at 7)))
        (check-equal "position 0" (drive cm-gen '() 88) (list 'error 0 0 0 (reject-at 0)))))
    (harness-case "advance consumes the offending byte and shifts the offset by one"
      (lambda ()
        (check-equal "branch" (drive ad-gen shared 50) (list 'error 1 1 8 (advance-reject-at 8)))
        (check-equal "position 0" (drive ad-gen '() 88) (list 'error 1 1 1 (advance-reject-at 1)))))))

(harness-finish)
