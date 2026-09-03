;;; All three §12.7 position kinds, in both executors, asserted by value.
;;;
;;; This is what makes the parser-error family front-loadable: every kind the
;;; table can produce today is reachable with byte-dispatch and error nodes
;;; alone, both shipped in Milestone 1, so the whole family is proved in a slice
;;; that adds no field and no node kind.
;;;
;;;   §12.7:768  `byte`      a reexecute mismatch, AT the offending byte
;;;   §12.7:769  `boundary`  an error edge after an advance, AFTER the byte
;;;
;;; Milestone 4 splits the remaining rows between slices, and each is a ROW in
;;; this shipped table rather than a new mechanism: Slice ② owns `boundary`
;;; after a zero-width hop, and Slice ③ owns `byte` for the input-reading
;;; accumulate kind. §12.7:777 makes position kind differential-compared, so a
;;; slice adding its row must add it for BOTH lanes.
;;;
;;; *** CORRECTED 2026-09-03. This paragraph said Slice ②'s row was "(added, and
;;; pinned in both lanes)". IT WAS NOT. *** Slice ② changed only this comment --
;;; `git diff f3b5558..14c4f30 -- test/common/position-kind-tests.sps` is six
;;; lines and none of them is code. The `cases` table below still holds its
;;; original three rows and the sentinels still read 3 and 6. ②'s only
;;; position-kind assertion anywhere is in field-access-tests.sps, and it asserts
;;; `eof` rather than `boundary` and drives the INTERPRETER ONLY.
;;;
;;; So Slice ③ is the first Milestone 4 slice to touch this table, and it has no
;;; precedent here to copy -- it inherits a task, not a pattern. Left as a
;;; correction rather than silently rewritten, because the false claim would
;;; otherwise have been read as evidence that the work was done.
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

;; Whole-branch review, 2026-09-02: two declarations may share a CODE. Nothing
;; rejects that -- pass-names checks duplicate declaration NAMES only, and
;; §16.2's required-check list does not ask for code uniqueness -- and the two
;; executors resolved the declaration by DIFFERENT keys: the interpreter by
;; name, the emitter by resolved code, first match. So the generated lane
;; reported a different declaration's REASON, which is one of the six members
;; the projection compares. Reachable through the public (byte-machine graph)
;; builder on a machine the verifier accepts with zero diagnostics; invisible to
;; every existing lane because each fixture uses distinct codes, and to the
;; property lane because machine-gen.sls fixes two declarations with distinct
;; codes.
(define dup-code
  (let ((errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                    (make-error-declaration 'first-decl 'unexpected-byte "REASON-A" #f)
                    (make-error-declaration 'second-decl 'unexpected-byte "REASON-B" #f))))
    (make-machine 'dup-code 'start '() '() '() errs
                  (list (make-byte-dispatch-node
                         'start
                         (list (make-byte-case (make-exact-byte-matcher 0)
                                               (make-edge 'stop 'advance) #f)
                               (make-byte-case (make-exact-byte-matcher 1)
                                               (make-edge 'other 'reexecute) #f))
                         (make-edge 'reject 'reexecute) #f #f)
                        (make-stop-node 'stop #f)
                        ;; BOTH same-code declarations are named, by different
                        ;; nodes. Naming only one lets the emitted table's
                        ;; reached-declaration filter drop the other, which
                        ;; masks the defect: the lookup then has a single
                        ;; candidate and code-alone and (code, reason) agree.
                        ;; Two reached declarations sharing a code is the shape
                        ;; that actually separates them.
                        (make-error-node 'reject 'second-decl #f)
                        (make-error-node 'other 'first-decl #f))
                  'default-eof #f)))

;; Whole-branch review, 2026-09-02: the writer half of Task 1 shipped with NO
;; witness. valid-reason? got three verify cases and two mutations; escape-string
;; got neither, and every reason in the whole test tree is plain lowercase ASCII
;; plus space, so nothing distinguished it from the identity function. Task 1's
;; own amendment deferred this fixture to Task 5, and Task 5 recorded no
;; amendment and never created it -- a deferral that closed nothing.
;;
;; valid-reason? deliberately ADMITS the three characters that need escaping
;; (they are inside §10.1:480's printable-ASCII-plus-LF repertoire), so
;; escape-string is the only thing between an author-supplied reason and a
;; generated library that does not parse.
(define quoted-reason
  (string-append "a " (string #\") "q" (string #\") " b "
                 (string #\\) " c" (string #\newline) "d"))

(define escaping
  (let ((errs (list (make-error-declaration 'default-eof 'eof quoted-reason #f)
                    (make-error-declaration 'rejected 'unexpected-byte quoted-reason #f))))
    (make-machine 'escaping 'start '() '() '() errs
                  (list (make-byte-dispatch-node
                         'start
                         (list (make-byte-case (make-exact-byte-matcher 0)
                                               (make-edge 'stop 'advance) #f))
                         (make-edge 'reject 'reexecute) #f #f)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)))

(harness-group "a reason carrying quote backslash and newline survives emission"
  (lambda ()
    (harness-case "the verifier accepts it"
      (lambda ()
        ;; §10.1:480 admits all three, so a rejection here would be the
        ;; verifier's defect, not the writer's.
        (let ((v (verify-machine escaping)))
          (check "accepted" (verification-ok? v))
          (check-equal "no diagnostics" (length (verification-diagnostics v)) 0))))
    (harness-case "the emitted library loads and reports the reason unchanged"
      (lambda ()
        ;; The load is the real assertion: an unescaped quote or backslash makes
        ;; the generated file a Chez READER error, which is what this whole
        ;; mechanism exists to prevent. Comparing the reason back proves the
        ;; escaping is lossless rather than merely parseable -- escaping to the
        ;; empty string would also load.
        (let ((ie (feed-then-error (interpreted escaping) '(65)))
              (ge (feed-then-error
                   (generated escaping 'escaping-parser 'escaping "pk-esc.sls") '(65))))
          (check-equal "generated round-trips the reason"
                       (parser-error-reason ge) quoted-reason)
          (check-equal "interpreter agrees" (parser-error-reason ie) quoted-reason)
          (check-equal "the lanes agree" (project-error ie) (project-error ge)))))))

;; The eof-target CHAIN and the default-EOF TERMINAL are different sites with
;; different mechanisms: the chain hop carries the loop variable forward, while
;; the terminal is reached by no jump and takes a per-site literal. The `eof`
;; case above drives the hop (eof-machine routes s1 -> trunc); this one drives
;; the terminal, which nothing else in the tree reaches with an assertion on the
;; kind. `escaping` declares eof-target #f, so an exhausted dispatch routes to
;; the machine default-eof error.
(harness-group "the default-EOF terminal reports eof"
  (lambda ()
    (harness-case "both lanes report eof at the terminal, not at a hop"
      (lambda ()
        (let ((ie (finish-error (interpreted escaping) '()))
              (ge (finish-error
                   (generated escaping 'escaping-parser 'escaping "pk-esc2.sls") '())))
          (check-equal "interpreter" (parser-error-position-kind ie) 'eof)
          (check-equal "generated" (parser-error-position-kind ge) 'eof)
          (check-equal "the lanes agree" (project-error ie) (project-error ge)))))))


(harness-group "an error declaration is resolved by declaration, not by code"
  (lambda ()
    (harness-case "the verifier accepts two declarations sharing a code"
      (lambda ()
        ;; Stated as its own check so the test does not silently start passing
        ;; because the machine became unbuildable. If a later slice decides codes
        ;; must be unique, THIS is the case that should fail first and say so.
        (let ((v (verify-machine dup-code)))
          (check "accepted" (verification-ok? v))
          (check-equal "no diagnostics" (length (verification-diagnostics v)) 0))))
    (harness-case "both lanes report the reason of the declaration the node names"
      (lambda ()
        (let ((ie (feed-then-error (interpreted dup-code) '(65)))
              (ge (feed-then-error
                   (generated dup-code 'dup-parser 'dup-code "pk-dup.sls") '(65))))
          (check-equal "interpreter" (parser-error-reason ie) "REASON-B")
          (check-equal "generated" (parser-error-reason ge) "REASON-B")
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
          ;; Against a LITERAL, not against projected-members: comparing the
          ;; library's output to the library's own constant five lines away is a
          ;; self-consistency check that one edit satisfies in both places. Six
          ;; is §22.4:1271's five plus `reason`; a seventh member appearing here
          ;; means the exclusion was widened or narrowed and this must be
          ;; re-derived from the spec, not from the code.
          (check-equal "the projection is §22.4:1271's five plus reason"
                       (length (project-error ie)) 6)
          (check-equal "and the library agrees with the spec" projected-members 6)
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
