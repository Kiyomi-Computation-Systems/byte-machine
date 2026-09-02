;;; All three §12.7 position kinds, in both executors, asserted by value.
;;;
;;; This is what makes the parser-error family front-loadable: every kind the
;;; table can produce today is reachable with byte-dispatch and error nodes
;;; alone, both shipped in Milestone 1, so the whole family is proved in a slice
;;; that adds no field and no node kind.
;;;
;;;   §12.7:768  `byte`      a reexecute mismatch, AT the offending byte
;;;   §12.7:769  `boundary`  an error edge after an advance, AFTER the byte
;;;   §12.7:771  `eof`       truncated input during finish!
;;;
;;; Two rows of that table are NOT producible here and this lane does not
;;; pretend otherwise: :770's zero-width action is Slice ②, its callback half is
;;; Milestone 5 and never producible in M4 at all, and :768's rejected-digit
;;; half needs Slice ③'s accumulate node.
(import (rnrs)
        (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test error-projection)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine test http-version-machine)
        (byte-machine test eof-machine))

(harness-begin "differential.position-kind")

(define tmpdir (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR"))

(define (generated m binding libname file)
  (let ((path (string-append tmpdir "/" file)))
    (call-with-port (open-file-output-port path (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) binding p)))
    (load path)
    (eval binding (environment (list 'generated libname)))))

(define (interpreted m) (make-interpreted-machine (verify-machine m)))

;; --- the three producers -----------------------------------------------------
;; reexecute mismatch -> `byte`; the same machine in advance mode -> `boundary`.
(define rx (make-http-version-machine))
(define ad (make-http-version-advance-machine))
;; feed one byte then finish! over exhausted input -> `eof`.
(define eofm (make-eof-machine))

(define (feed-then-error cm bytes)
  (let* ((p (make-parser cm '() #f))
         (r (parser-feed! p (u8-list->bytevector bytes) 0 (length bytes))))
    (parser-result-error r)))

(define (finish-error cm bytes)
  (let ((p (make-parser cm '() #f)))
    (parser-feed! p (u8-list->bytevector bytes) 0 (length bytes))
    (parser-result-error (parser-finish! p))))

;; HTTP/1.2 -- the branch byte is wrong, so the mismatch lands at offset 7.
(define bad-version '(72 84 84 80 47 49 46 50))

(define cases
  (list
   ;; (name interpreter-error generated-error expected-kind expected-offset)
   (list "reexecute mismatch reports byte at the offending byte"
         (lambda (cm) (feed-then-error cm bad-version)) 'byte 7
         (lambda () (interpreted rx))
         (lambda () (generated rx 'http-version-parser 'http-version "pk-rx.sls")))
   (list "an advance-mode mismatch reports boundary after the committed byte"
         (lambda (cm) (feed-then-error cm bad-version)) 'boundary 8
         (lambda () (interpreted ad))
         (lambda () (generated ad 'http-version-advance-parser 'http-version-advance
                               "pk-ad.sls")))
   (list "truncation during finish reports eof"
         (lambda (cm) (finish-error cm '(1))) 'eof 1
         (lambda () (interpreted eofm))
         (lambda () (generated eofm 'eofm-parser 'eofm "pk-eof.sls")))))

(harness-group "every position kind, in both executors"
  (lambda ()
    (harness-case "each kind is reported by value, and the two lanes agree"
      (lambda ()
        ;; Sentinels read OBSERVED drives, never the driving list's own length:
        ;; the outer count proves every case ran, the inner one that each ran in
        ;; both executors. Six per process -- three kinds x two executors. The
        ;; x2 for source/AOT is discharged by the lane PAIR both passing, which
        ;; CTest reports; no in-process counter can see it, because the two are
        ;; two registrations of this same program under different launchers.
        (let ((drives 0) (cases-run 0))
          (for-each
           (lambda (c)
             (set! cases-run (+ cases-run 1))
             (let* ((name (car c)) (drive (cadr c))
                    (kind (caddr c)) (offset (cadddr c))
                    (ie (drive ((list-ref c 4))))
                    (ge (drive ((list-ref c 5)))))
               (for-each (lambda (e)
                           (set! drives (+ drives 1))
                           (check (string-append name ": is a record") (parser-error? e))
                           (check-equal (string-append name ": kind")
                                        (parser-error-position-kind e) kind)
                           (check-equal (string-append name ": offset")
                                        (parser-error-offset e) offset)
                           (check-equal (string-append name ": domain")
                                        (parser-error-domain e) 'machine))
                         (list ie ge))
               (check-equal (string-append name ": the lanes agree on the projection")
                            (project-error ie) (project-error ge))))
           cases)
          (check-equal "three cases ran" cases-run 3)
          (check-equal "six drives observed" drives 6))))))

;; A pause whose CONTINUATION is an error node. Feed to the pause, resume, then
;; finish!: the finish loop reaches that error state on its first dispatch, by no
;; jump at all, so what it reports is the loop's INITIALIZATION -- the only case
;; that can observe it. Decision 0022 item 5 spends three paragraphs on this
;; shape, and without it the initialization is unwitnessable: every other route
;; into a finish-time error either hops (setting `eof`) or lands on the
;; default-EOF terminal, which takes its own constant.
;;
;; Verifier-legal: for a byte-reachable pause the verifier rejects only a
;; `finish` continuation and eof-reachable-stop/cycle, and eof-terminal
;; classifies an error continuation as 'error.
(define parked
  (let ((errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                    (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))))
    (make-machine 'parked 's0 '() '() '() errs
                  (list (make-byte-dispatch-node
                         's0
                         (list (make-byte-case (make-exact-byte-matcher 1)
                                               (make-edge 'p1 'advance) #f))
                         (make-edge 'reject 'reexecute) #f #f)
                        (make-pause-node 'p1 'reject #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)))

(define (parked-finish-error cm)
  (let ((p (make-parser cm '() #f)))
    (parser-feed! p (u8-list->bytevector '(1)) 0 1)   ; -> paused, parked on reject
    (parser-resume! p)
    (parser-result-error (parser-finish! p))))

(harness-group "a finish that observes a parked error state reports the initialization"
  (lambda ()
    (harness-case "both lanes report boundary, not eof"
      (lambda ()
        ;; Nothing is truncated by a finish! that merely observes an error state
        ;; a prior feed already reached, so it reports the same `boundary` a feed
        ;; resuming onto it would. This is the case that makes the finish loop's
        ;; unconditional `boundary` initialization observable at all.
        (let ((ie (parked-finish-error (interpreted parked)))
              (ge (parked-finish-error
                   (generated parked 'parked-parser 'parked "pk-parked.sls"))))
          (check-equal "interpreter" (parser-error-position-kind ie) 'boundary)
          (check-equal "generated" (parser-error-position-kind ge) 'boundary)
          (check-equal "the lanes agree" (project-error ie) (project-error ge)))))))

(harness-group "the state id is reported by both lanes and excluded from the comparison"
  (lambda ()
    (harness-case "both report one, and the projection omits it"
      (lambda ()
        ;; Asserted POSITIVELY, per §12.7:777: generated ids "are deterministic
        ;; for a given normalized graph, but an independently interpreted machine
        ;; need not report the same ID." The exclusion is invisible by
        ;; construction, so what is checked is that both lanes REPORT one and
        ;; that the projection's width is the agreed one -- a check that fails if
        ;; the exclusion is ever widened to drop a comparable member.
        (let* ((ie (feed-then-error (interpreted rx) bad-version))
               (ge (feed-then-error (generated rx 'http-version-parser 'http-version
                                               "pk-id.sls")
                                    bad-version)))
          (check "interpreter reports a state id" (integer? (error-state-id ie)))
          (check "generated reports a state id" (integer? (error-state-id ge)))
          (check-equal "the projection is the agreed width"
                       (length (project-error ie)) projected-members)
          (check-equal "and both lanes project identically"
                       (project-error ie) (project-error ge)))))
    (harness-case "reason and detail are compared rather than left as orphans"
      (lambda ()
        ;; §9.3 ships eight accessors, §22.4:1271 names five, §12.7:777 excludes
        ;; one -- leaving `reason` and `detail` neither required to match nor
        ;; licensed to differ. Both lanes build them from the same declaration,
        ;; so the agreement is real and is asserted here rather than left for a
        ;; later slice to re-derive.
        (let ((ie (feed-then-error (interpreted rx) bad-version))
              (ge (feed-then-error (generated rx 'http-version-parser 'http-version
                                              "pk-rd.sls")
                                   bad-version)))
          (check-equal "reason agrees"
                       (parser-error-reason ie) (parser-error-reason ge))
          (check-equal "detail is #f in the machine domain"
                       (parser-error-detail ie) #f)
          (check-equal "and agrees across lanes"
                       (parser-error-detail ie) (parser-error-detail ge)))))))

(harness-finish)
