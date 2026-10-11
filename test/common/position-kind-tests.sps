;;; Every position kind, in both executors, asserted by value.
;;;
;;;   `byte`      a reexecute mismatch, AT the offending byte
;;;   `boundary`  an error edge after an advance, AFTER the byte
;;;   `eof`       truncated input during finish!
;;;
;;; Position kind is a value the two lanes are differential-compared on, so a row
;;; added here must be added for BOTH lanes. A lane-to-lane projection alone is
;;; satisfied by two lanes reporting the same wrong kind, so every row asserts the
;;; VALUE: the kind, the offset and the domain in each lane, then the whole
;;; projection across lanes. field-access-tests.sps asserts the KIND for the
;;; accumulate-overflow shape; what it cannot assert is the offset and the
;;; cross-lane projection, which is what this table is for.
;;;
;;; The table indexes PRODUCERS, not kinds: besides the three rows above it holds
;;; an accumulate overflow (a second producer of `byte`), the three emitted arms
;;; that call application code (a callback node, a span's data callback, a span's
;;; completion callback -- each a producer of the zero-width rule's `boundary`),
;;; and three counted-consume rows.

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
;; An accumulate node whose next digit would overflow the field. The offending
;; byte is NOT consumed, which is exactly what makes the kind `byte` rather than
;; `boundary` -- and the offset it asserts is the discriminator: a consuming
;; overflow would report 3.
;;
;; Built here rather than pulled from a fixture library because the three
;; machines further down this file are built here too; a library would exist for
;; one caller. A u8 field reaches 99 on "99" and the third `9` cannot be taken.
(define overflow
  (let ((errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                    (make-error-declaration 'too-big 'unexpected-byte "field overflow" #f))))
    (make-machine 'overflow 'start (list (make-uint-field 'n 8 0 #f)) '() '() errs
                  (list (make-byte-dispatch-node
                         'start
                         (list (make-byte-case (make-byte-range-matcher 0 255)
                                               (make-edge 'acc 'reexecute) #f))
                         (make-edge 'acc 'reexecute) #f #f)
                        (make-integer-accumulate-node 'acc 'n 10 'acc
                                                      (make-edge 'done 'advance)
                                                      'over #f #f)
                        (make-stop-node 'done #f)
                        (make-error-node 'over 'too-big #f))
                  'default-eof #f)))

;; The zero-width rule's CALLBACK half: a failing callback reports `boundary` at
;; the current stream offset. Each machine is the smallest that reaches one: a
;; byte to commit, so the offset under test is not zero, and then the
;; invocation.
(define cb-errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                      (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
(define cbfail
  (make-machine 'cbfail 'start '()
    (list (make-callback-declaration 'decide 'event #t '() #f #f))
    '() cb-errs
    ;; *** THE CALLBACK IS REACHED BY A REEXECUTE EDGE, and that is the whole
    ;; point of the row. *** Reached by an ADVANCE the loop's `pk` is already
    ;; `boundary`, so the literal and the variable agree and the fixture proves
    ;; nothing. Over a reexecute edge `pk` is `byte`, which a callback failure
    ;; must not report.
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'mid 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-byte-dispatch-node 'mid
            (list (make-byte-case (make-exact-byte-matcher 66)
                                  (make-edge 'inv 'reexecute) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-callback-node 'inv 'decide 'done '() 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 66)
                                  (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
;; The span's DATA callback fails at the span end, which is
;; a different emitted arm and a different runtime entry point from the callback
;; node above -- so a lane getting one right and the other wrong is invisible to
;; the row above it.
(define spfail
  (make-machine 'spfail 'start '()
    (list (make-callback-declaration 'on-data 'span-data #t '() #f #f))
    (list (make-span-declaration 'body 'on-data #f #f))
    cb-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'op 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'op 'body 'body-d #f)
          (make-byte-dispatch-node 'body-d
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'cl 'reexecute) #f))
            ;; Its OWN error terminal: the shared `reject` is reached from
            ;; outside the span with nothing open, so routing this EOF there
            ;; joins `(active body)` with `none` and pass 7 rejects the machine
            ;; for a merge this fixture never meant to build.
            (make-edge 'body-d 'advance) 'trunc #f)
          (make-span-end-node 'cl 'body 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f)
          (make-error-node 'trunc 'rejected #f))
    'default-eof #f))

;; The THIRD emitted arm that calls out, and the one neither row above reaches:
;; a span end's COMPLETION callback. Its declaration is what separates this
;; machine from `spfail`.
(define spdone
  (make-machine 'spdone 'start '()
    (list (make-callback-declaration 'on-data 'span-data #t '() #f #f)
          (make-callback-declaration 'on-done 'span-complete #t '() #f #f))
    (list (make-span-declaration 'body 'on-data 'on-done #f))
    cb-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 65)
                                  (make-edge 'op 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-span-start-node 'op 'body 'body-d #f)
          (make-byte-dispatch-node 'body-d
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'cl 'reexecute) #f))
            (make-edge 'body-d 'advance) 'trunc #f)
          (make-span-end-node 'cl 'body 'after #f)
          (make-byte-dispatch-node 'after
            (list (make-byte-case (make-exact-byte-matcher 90)
                                  (make-edge 'done 'advance) #f))
            (make-edge 'reject 'reexecute) 'fin #f)
          (make-stop-node 'done #f)
          (make-finish-node 'fin #f)
          (make-error-node 'reject 'rejected #f)
          (make-error-node 'trunc 'rejected #f))
    'default-eof #f))

;; The counted-consume rows. There are three because the third separates the
;; counted arm's ORDER (a zero count transitions before exhaustion is tested)
;; from its carried position kind, which one row cannot do: a reexecute
;; edge leaves a byte unconsumed, so the node is never reached at the end of a
;; slice, and an advance edge at the end of a slice carries `boundary` whatever
;; the arm does. Each machine is the smallest that reaches the counted consume
;; the way its row needs.
(define cc-errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                      (make-error-declaration 'truncated 'eof "truncated body" #f)
                      (make-error-declaration 'bad-body 'unexpected-byte "bad body" #f)))
;; Row 1: a body of three, one byte fed, then finish -- truncation at a PARKED
;; counted consume is `eof` at the final offset. The offset catches
;; an arm that does not advance it; the error's node catches an arm that parks
;; `current` on the successor (which would finish through the stop instead).
(define cc-trunc
  (make-machine 'cctrunc 'start (list (make-uint-field 'len 8 3 #f)) '() '() cc-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'body 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-counted-consume-node 'body 'len 'done 'trunc #f)
          (make-stop-node 'done #f)
          (make-error-node 'trunc 'truncated #f)
          (make-error-node 'reject 'bad-body #f))
    'default-eof #f))
;; Row 2: a zero count reached over a REEXECUTE edge transitions into an error
;; node with the position kind CARRIED: `byte` at the unconsumed byte, exactly
;; as through a field branch.
(define cc-zero-reexec
  (make-machine 'cczero 'start (list (make-uint-field 'len 8 0 #f)) '() '() cc-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'body 'reexecute) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-counted-consume-node 'body 'len 'bad #f #f)
          (make-error-node 'bad 'bad-body #f)
          (make-error-node 'reject 'bad-body #f))
    'default-eof #f))
;; Row 3: the same zero count reached at the END of the slice over an advance
;; edge. An arm that tests exhaustion before asking the op returns need-input
;; here and reports no error at all; the correct arm transitions and reports
;; `boundary`, carried from the advance, at offset 1.
(define cc-zero-end
  (make-machine 'cczeroend 'start (list (make-uint-field 'len 8 0 #f)) '() '() cc-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'body 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-counted-consume-node 'body 'len 'bad #f #f)
          (make-error-node 'bad 'bad-body #f)
          (make-error-node 'reject 'bad-body #f))
    'default-eof #f))

(define (feed-then-error cm bytes)
  (let* ((p (make-parser cm '() #f))
         (r (parser-feed! p (u8-list->bytevector bytes) 0 (length bytes))))
    (parser-result-error r)))
;; The same drive with BINDINGS, for the two callback-domain rows. A separate
;; helper rather than a widened one: every other row here builds its parser with
;; no bindings at all, and threading an always-empty list through them would put
;; the callback vocabulary into rows that have none.
(define (feed-then-callback-error cm bindings bytes)
  (let* ((p (make-parser cm bindings 'ctx))
         (r (parser-feed! p (u8-list->bytevector bytes) 0 (length bytes))))
    (parser-result-error r)))
(define (fails name) (list (list name (lambda args (make-callback-failure 'said-no #f)))))

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
         (lambda () (generated eofm 'eofm-parser 'eofm "pk-eof.sls")))
   ;; 57 is `9`. The third one overflows a u8 already holding 99, and because
   ;; an overflowing digit is not consumed the offset is 2 -- the offending byte itself,
   ;; not the position after it.
   (list "an accumulate overflow reports byte at the unconsumed digit"
         (lambda (cm) (feed-then-error cm '(57 57 57))) 'byte 2
         (lambda () (interpreted overflow))
         (lambda () (generated overflow 'overflow-parser 'overflow "pk-over.sls")))
   ;; The zero-width rule's callback half, `boundary` at the current stream offset: the
   ;; invocation is zero-width, so the offset is the one byte already committed
   ;; and the position is a byte boundary -- which is why the offset assertion
   ;; is 1 and not 0. Domain `callback`, which is what makes these two rows the
   ;; first in this table not to be `machine`.
   (list "a callback failure reports boundary at the committed offset"
         (lambda (cm) (feed-then-callback-error cm (fails 'decide) '(65 66))) 'boundary 1
         (lambda () (interpreted cbfail))
         (lambda () (generated cbfail 'cbfail-parser 'cbfail "pk-cb.sls"))
         'callback)
   ;; The SPAN data callback's failure, at the span end: two bytes committed, so
   ;; the discriminator is the offset 2. A lane that reported the span start's
   ;; offset, or the slice position rather than the stream one, differs here and
   ;; nowhere else in this file.
   (list "a span data callback failure reports boundary at the committed offset"
         (lambda (cm) (feed-then-callback-error cm (fails 'on-data) '(65 98 90))) 'boundary 2
         (lambda () (interpreted spfail))
         (lambda () (generated spfail 'spfail-parser 'spfail "pk-sp.sls"))
         'callback)
   ;; The completion substep's own failure. The data callback continues, so the
   ;; fragment is delivered and the span is already inactive when this runs --
   ;; and the offset is still 2, because span substeps consume nothing.
   ;; This is the third emitted arm that calls out, and the only row that
   ;; reaches it.
   (list "a span completion callback failure reports boundary too"
         (lambda (cm)
           (feed-then-callback-error
            cm (cons (list 'on-data (lambda args callback-continue)) (fails 'on-done))
            '(65 98 90)))
         'boundary 2
         (lambda () (interpreted spdone))
         (lambda () (generated spdone 'spdone-parser 'spdone "pk-spd.sls"))
         'callback)
   ;; --- counted consume ---
   (list "truncation at a parked counted consume reports eof at the final offset"
         (lambda (cm) (finish-error cm '(0 65))) 'eof 2
         (lambda () (interpreted cc-trunc))
         (lambda () (generated cc-trunc 'cctrunc-parser 'cctrunc "pk-cctrunc.sls")))
   (list "a zero-count transition over a reexecute edge carries byte at the unconsumed byte"
         (lambda (cm) (feed-then-error cm '(0))) 'byte 0
         (lambda () (interpreted cc-zero-reexec))
         (lambda () (generated cc-zero-reexec 'cczero-parser 'cczero "pk-cczero.sls")))
   (list "a zero count at the end of a slice transitions before exhaustion is tested"
         (lambda (cm) (feed-then-error cm '(0))) 'boundary 1
         (lambda () (interpreted cc-zero-end))
         (lambda () (generated cc-zero-end 'cczeroend-parser 'cczeroend "pk-cczeroend.sls")))))

(harness-group "every position kind, in both executors"
  (lambda ()
    (harness-case "each kind is reported by value, and the two lanes agree"
      (lambda ()
        ;; Sentinels read OBSERVED drives, never the driving list's own length:
        ;; the outer count proves every case ran, the inner one that each ran in
        ;; both executors. TWENTY per process -- ten rows x two executors; both
        ;; literals move when a row is added. Ten rows for three kinds, because
        ;; this table indexes PRODUCERS and not kinds (see the file header). The
        ;; x2 for source/AOT is discharged by the lane PAIR both passing, which
        ;; CTest reports; no in-process counter can see it, because the two are
        ;; two registrations of this same program under different launchers.
        (let ((drives 0) (cases-run 0))
          (for-each
           (lambda (c)
             (set! cases-run (+ cases-run 1))
             (let* ((name (car c)) (drive (cadr c))
                    (kind (caddr c)) (offset (cadddr c))
                    (domain (if (> (length c) 6) (list-ref c 6) 'machine))
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
                                        (parser-error-domain e) domain))
                         (list ie ge))
               (check-equal (string-append name ": the lanes agree on the projection")
                            (project-error ie) (project-error ge))))
           cases)
          (check-equal "ten cases ran" cases-run 10)
          (check-equal "twenty drives observed" drives 20))))))

;; A pause whose CONTINUATION is an error node. Feed to the pause, resume, then
;; finish!: the finish loop reaches that error state on its first dispatch, by
;; no jump at all, so what it reports is the loop's INITIALIZATION -- the only
;; case that can observe it. Without this shape the initialization is
;; unwitnessable: every other route into a finish-time error either hops
;; (setting `eof`) or lands on the default-EOF terminal, which takes its own
;; constant.
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

;; Two declarations may share a CODE. Nothing rejects that -- pass-names checks
;; duplicate declaration NAMES only, and the verifier does not require code
;; uniqueness. An executor that resolved the declaration by code (first match)
;; rather than by the declaration the node names would report a different
;; declaration's REASON, which is one of the members the projection compares.
;; The shape is reachable through the public (byte-machine graph) builder on a
;; machine the verifier accepts with zero diagnostics, and invisible to every
;; other lane: each other fixture uses distinct codes, and machine-gen.sls fixes
;; two declarations with distinct codes for the property lane.
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

;; escape-string's witness. Every other reason in the test tree is plain
;; lowercase ASCII plus space, so nothing else distinguishes escape-string from
;; the identity function.
;;
;; valid-reason? deliberately ADMITS the three characters that need escaping
;; (they are inside the printable-ASCII-plus-LF reason repertoire), so
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
        ;; The reason repertoire admits all three, so a rejection here would be the
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
        ;; because the machine became unbuildable. If codes are ever required to
        ;; be unique, THIS is the case that should fail first and say so.
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
        ;; Asserted POSITIVELY: generated ids are deterministic for a given
        ;; normalized graph, but an independently interpreted machine need not
        ;; report the same id, so the projection omits it. The exclusion is invisible by
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
          ;; self-consistency check that one edit satisfies in both places. Eight
          ;; is the five required members (domain, code, node name, offset,
          ;; position kind) plus `reason` plus the two abandoned-span members (the
          ;; span an error abandoned and where its withheld bytes begin); a
          ;; different count means the exclusion was widened or narrowed and this
          ;; must be re-derived from the comparison rules, not from the code.
          (check-equal "the projection is §22.4:1271's five plus reason plus the abandoned span"
                       (length (project-error ie)) 8)
          (check-equal "and the library agrees with the spec" projected-members 8)
          (check-equal "and both lanes project identically"
                       (project-error ie) (project-error ge)))))
    (harness-case "reason and detail are compared rather than left as orphans"
      (lambda ()
        ;; The parser-error family has ten accessors. Five are required to
        ;; match, the state id is excluded, and the two abandoned-span members
        ;; are compared -- leaving `reason` and `detail` neither required to
        ;; match nor licensed to differ. Both lanes build them from the same
        ;; declaration, so the agreement is real and is asserted here.
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
