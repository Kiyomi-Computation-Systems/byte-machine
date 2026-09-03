;;; parser-field-ref across both executors (§9.3:410, §13:801; Milestone 4 Slice
;;; ①b tasks 6 and 7). The generated library is emitted at run time, loaded, and
;;; its compiled machine obtained by environment/eval, exactly as the
;;; differential lanes do — because the two executors reach the field
;;; declarations by DIFFERENT routes and only running both proves they agree.
;;; The interpreter asks its op closure a 'field-initials message; the generated
;;; lane reads member 0 of the ABI payload it was emitted with. Nothing is shared
;;; between those two paths, so an interpreter-only lane would leave the emitted
;;; half untested and a generated-only lane the reverse.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load greatest-fixnum)
        (rnrs bytevectors)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine private normal-ir)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.field")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'field-access "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/generated-field-access.sls"))

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))

;; *** The fixture the design asks for (milestone-4-design.md:1208-1218), which
;; Slice ①b first shipped without and the whole-branch review restored. ***
;;
;; A DISTINCT NON-ZERO INITIAL PER WIDTH, so a lane that zero-fills, reads the
;; wrong slot or transposes two slots gives a wrong answer rather than a
;; coincidentally right one -- an all-zero fixture passes under every one of
;; those defects, and the first version of this file had a zero among its three.
;;
;; A U64 INITIAL AT OR ABOVE 2^60, which is exactly the bignum boundary on this
;; host: under the project's Chez, (fixnum-width) is 61 and (greatest-fixnum) is
;; 2^60 - 1, so 2^60 is the first non-fixnum while u32's own maximum 4294967295
;; is still a fixnum. Without it all four widths exercise the FIXNUM path only
;; and §15:856's "must not rely on host fixnum width" is untested end to end --
;; the initial has to survive make-uint-field, the normalizer's field table,
;; put-u64be in the encoding, number->string in the emitter, the reader on the
;; way back in, and parser-field-ref.
(define decls   ; NOT `fields`: (rnrs) binds it as define-record-type's
                ; auxiliary keyword, and a top-level define of it is a
                ; "multiple definitions" error at expand time.
  (list (make-uint-field 'count 8 7 #f)
        (make-uint-field 'limit 16 65535 #f)
        (make-uint-field 'seen 32 4294967295 #f)
        (make-uint-field 'total 64 1152921504606846976 #f)))   ; 2^60

(define expected-initials
  (list (cons 'count 7) (cons 'limit 65535)
        (cons 'seen 4294967295) (cons 'total 1152921504606846976)))

(define (one-byte-nodes)
  (list (make-byte-dispatch-node 'start
          (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
          (make-edge 'reject 'reexecute) #f #f)
        (make-stop-node 'stop #f)
        (make-error-node 'reject 'rejected #f)))

(define (machine-with nm fs)
  (make-machine nm 'start fs '() '() (list eof-decl rej-decl)
                (one-byte-nodes) 'default-eof #f))

(define m (machine-with 'field-access decls))
;; A DIFFERENT machine name, because the emitted library is named after the
;; machine: two zero-argument fixtures both called `field-access` would emit two
;; `(generated field-access)` libraries into one process, and the second `load`
;; would win silently.
(define zero (machine-with 'field-access-zero '()))

(define (emit-and-load mach mname binding file)
  (call-with-port (open-file-output-port file (file-options no-fail))
    (lambda (p) (emit-machine (compile-machine mach '()) binding p)))
  (load file)
  (eval binding (environment (list 'generated mname))))

(define cm-ref (make-interpreted-machine (verify-machine m)))
(define cm-gen (emit-and-load m 'field-access 'field-access-parser genfile))

;; --- Slice ② task 6+7: a machine that WRITES fields ---
;; Byte 0 increments `count` and stops; byte 1 runs `count` up against its u8
;; ceiling through a branch. This is the first fixture in the tree whose fields
;; a parse actually changes, which is what makes the two obligations Slice ①b
;; deferred witnessable at last.
(define wm
  (make-machine 'writer 'start
    (list (make-uint-field 'count 8 254 #f) (make-uint-field 'seen 16 0 #f))
    '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'bump 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 1) (make-edge 'big 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          ;; increment can fail, so it carries an error target -- the constructor
          ;; makes that mandatory.
          (make-field-action-node 'bump 'increment '(count) 'note 'over #f)
          (make-field-action-node 'note 'add '(seen 1) 'chk 'over #f)
          ;; A field BRANCH, so the emitted branch arm is exercised too. Without
          ;; one, mutations of that arm survive the whole lane -- measured.
          (make-field-branch-node 'chk 'zero '(count) 'odd 'start #f)
          (make-field-action-node 'odd 'add '(seen 100) 'start 'over #f)
          ;; Overflows from BELOW the ceiling: 254 + 10 = 264 > 255. Without this
          ;; the only overflow in the fixture starts AT 255, where "leaves the
          ;; prior value unchanged" and "clamps to the maximum" coincide -- and a
          ;; mutant that clamps survives. Measured: it did.
          (make-field-action-node 'big 'add '(count 10) 'start 'over #f)
          (make-error-node 'over 'rejected #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define wm-ref (make-interpreted-machine (verify-machine wm)))
(define wm-gen
  (emit-and-load wm 'writer 'writer-parser (string-append tmpdir "/generated-writer.sls")))

(define (feed-bytes cm bs)
  (let ((p (make-parser cm '() #f)))
    (parser-feed! p (u8-list->bytevector bs) 0 (length bs))
    p))

(harness-group "fields a parse actually writes (Slice ②)"
  (lambda ()
    (harness-case "an increment commits into the parser's own storage"
      (lambda ()
        (let ((p (feed-bytes wm-ref '(0))))
          (check-equal "count" (parser-field-ref p 'count) 255)
          (check-equal "seen" (parser-field-ref p 'seen) 1))))
    (harness-case "a failed operation leaves the prior value unchanged (§25:1569)"
      (lambda ()
        ;; 254 -> 255 on the first byte; the second increment overflows a u8 and
        ;; must route to the error target WITHOUT writing. §10.6:568 and
        ;; §15:870: overflow leaves the prior value alone.
        (let ((p (feed-bytes wm-ref '(0 0))))
          (check-equal "count held at its maximum" (parser-field-ref p 'count) 255)
          (check-equal "lifecycle" (parser-lifecycle p) 'error))))
    (harness-case "an overflow from BELOW the ceiling does not clamp"
      (lambda ()
        ;; §10.6:568 and §15:870 say the prior value is unchanged -- not
        ;; saturated. 254 + 10 overflows a u8, and `count` must still read 254.
        (let ((p (feed-bytes wm-ref '(1))))
          (check-equal "unchanged, not clamped" (parser-field-ref p 'count) 254)
          (check-equal "lifecycle" (parser-lifecycle p) 'error))))
    (harness-case "the failure routes to the declared error target"
      (lambda ()
        (let* ((p (feed-bytes wm-ref '(0 0)))
               (r (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" (parser-result-status r) 'error))))
    (harness-case "a failure after a zero-width hop on an EOF chain reports eof, not boundary"
      (lambda ()
        ;; *** H7: the design never poses this, and §12.7:777 makes position kind
        ;; differential-compared, so the two lanes disagreeing is a lane failure
        ;; rather than a cosmetic one. *** The ruling: a zero-width step does not
        ;; move the parser in the input, so `pk` is carried THROUGH. On an EOF
        ;; chain it is already 'eof by the time the hop happens, and a failure
        ;; reached one hop later is still at end of input -- resetting it to
        ;; 'boundary would claim the parser is between bytes when there are none.
        (let* ((m (make-machine 'eofw 'start (list (make-uint-field 'count 8 255 #f))
                    '() '() (list eof-decl rej-decl)
                    (list (make-byte-dispatch-node 'start
                            (list (make-byte-case (make-exact-byte-matcher 0)
                                                  (make-edge 'start 'advance) #f))
                            (make-edge 'reject 'reexecute) 'bump #f)
                          ;; `next` must NOT return to the chain: routed back to
                          ;; `start` this is an EOF cycle, and the verifier
                          ;; rejects it -- which is task 2 and task 3 working.
                          (make-field-action-node 'bump 'increment '(count) 'done 'over #f)
                          (make-finish-node 'done #f)
                          (make-error-node 'over 'rejected #f)
                          (make-error-node 'reject 'rejected #f))
                    'default-eof #f))
               (p (make-parser (make-interpreted-machine (verify-machine m)) '() #f))
               (r (parser-finish! p)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "position kind"
                       (parser-error-position-kind (parser-result-error r)) 'eof))))
    ;; *** Slice ①b's DEFERRED isolation case, now writable. *** ①b declined it
    ;; with a written reason -- parser-field-ref was read-only and nothing wrote
    ;; a field, so two parsers sharing one vector and two holding their own were
    ;; observationally identical. A writer exists now, so the case can fail.
    (harness-case "two parsers from one compiled machine do not share field storage"
      (lambda ()
        (let ((a (feed-bytes wm-ref '(0))) (b (make-parser wm-ref '() #f)))
          (check-equal "the one that fed" (parser-field-ref a 'count) 255)
          (check-equal "the one that did not" (parser-field-ref b 'count) 254))))
    ;; *** Slice ①b's parser-reset! EXPECT_SURVIVES, now closable. *** Its own
    ;; reason names this exact condition: the restore becomes witnessable the
    ;; moment a writer exists, and the mutation must be re-pinned in that commit.
    ;; *** The GENERATED lane runs the same schedule. *** Everything above drives
    ;; the interpreter; these drive the emitted library, and the last case
    ;; compares them. Without this the emitter's arms -- a separate
    ;; implementation of the same arithmetic, written twice on purpose -- would
    ;; be entirely unexercised.
    (harness-case "the generated lane writes, checks and routes identically"
      (lambda ()
        (let ((a (feed-bytes wm-ref '(0))) (b (feed-bytes wm-gen '(0))))
          (check-equal "count" (parser-field-ref b 'count) (parser-field-ref a 'count))
          (check-equal "seen" (parser-field-ref b 'seen) (parser-field-ref a 'seen))
          (check-equal "and the value itself" (parser-field-ref b 'count) 255))))
    (harness-case "the generated lane leaves a failed operation's value unchanged"
      (lambda ()
        (let ((a (feed-bytes wm-ref '(1))) (b (feed-bytes wm-gen '(1))))
          (check-equal "both unchanged" (parser-field-ref b 'count) (parser-field-ref a 'count))
          (check-equal "and not clamped" (parser-field-ref b 'count) 254)
          (check-equal "lifecycle" (parser-lifecycle b) 'error))))
    (harness-case "both lanes agree over every input the fixture can take"
      (lambda ()
        ;; A loop with a sentinel reading the OBSERVED count: the two lanes must
        ;; agree on the field values AND the status for each byte, not merely on
        ;; the one byte a hand-written case happens to name.
        (let ((seen 0))
          (for-each
           (lambda (bs)
             (set! seen (+ seen 1))
             ;; The check label names the WHOLE schedule, not just its first
             ;; byte. With `(0)` and `(0 0)` both labelled "0", two different
             ;; mutants produced byte-identical FAIL records and no pin could
             ;; tell them apart -- measured by this task's own sweep.
             (let ((a (feed-bytes wm-ref bs)) (b (feed-bytes wm-gen bs))
                   (nm (apply string-append (map number->string bs))))
               (check-equal (string-append "count [" nm "]")
                            (parser-field-ref b 'count) (parser-field-ref a 'count))
               (check-equal (string-append "seen [" nm "]")
                            (parser-field-ref b 'seen) (parser-field-ref a 'seen))
               (check-equal (string-append "lifecycle [" nm "]")
                            (parser-lifecycle b) (parser-lifecycle a))))
           '((0) (1) (2) (0 0) (0 1) (1 0)))
          (check-equal "every schedule compared" seen 6))))
    (harness-case "parser-reset! restores a field a parse has CHANGED"
      (lambda ()
        (let ((p (feed-bytes wm-ref '(0))))
          (check-equal "changed by the parse" (parser-field-ref p 'count) 255)
          (parser-reset! p)
          (check-equal "restored to the declared initial" (parser-field-ref p 'count) 254)
          (check-equal "and the other field too" (parser-field-ref p 'seen) 0))))))

;; The zero-field control exists PER LANE. It was one interpreted machine shared
;; by both groups, so the case inside "parser-field-ref (generated)" ran the
;; interpreter and the v2 arm's empty-member-0 path was never executed anywhere
;; in the tree -- measured by the whole-branch review, which made the two lanes
;; disagree on a §9.3:410 accessor while the whole suite stayed green.
(define cm-zero-ref (make-interpreted-machine (verify-machine zero)))
(define cm-zero-gen
  (emit-and-load zero 'field-access-zero 'field-access-zero-parser
                 (string-append tmpdir "/generated-field-access-zero.sls")))

(define (caught thunk)
  (call/cc (lambda (k)
             (with-exception-handler
              (lambda (e) (k (and (byte-machine-contract-condition? e)
                                  (byte-machine-contract-condition-code e))))
              (lambda () (thunk) 'no-raise)))))

(define (per-executor name cm cm-zero)
  (harness-group (string-append "parser-field-ref (" name ")")
    (lambda ()
      (harness-case "a fresh parser reads the declared initial at every width"
        (lambda ()
          ;; A LOOP over all four widths, carrying a completion sentinel that
          ;; reads the OBSERVED count rather than the test's own expectation
          ;; (AGENTS.md:188-196). No suite here declares an expected case count,
          ;; so an exhaustive loop that never executes otherwise passes
          ;; vacuously -- and a sentinel computed from the expectation asserts
          ;; nothing, which is why `seen` counts what the loop actually did.
          (let ((p (make-parser cm '() #f)) (seen 0))
            (for-each (lambda (kv)
                        (set! seen (+ seen 1))
                        (check-equal (symbol->string (car kv))
                                     (parser-field-ref p (car kv)) (cdr kv)))
                      expected-initials)
            (check-equal "every declared width was read" seen 4))))
      (harness-case "the u64 initial crosses the bignum boundary intact"
        (lambda ()
          ;; Stated as its own case because the loop above would still pass if
          ;; the u64 value were silently truncated to a fixnum on BOTH sides --
          ;; agreement bought by making the difference unobservable. This asserts
          ;; the value against the literal, and asserts it is not a fixnum, so a
          ;; host whose fixnum range grows past 2^60 fails here loudly rather
          ;; than quietly stopping to test what the case exists to test.
          (let ((v (parser-field-ref (make-parser cm '() #f) 'total)))
            (check-equal "exact value" v 1152921504606846976)
            (check "above greatest-fixnum" (> v (greatest-fixnum))))))
      (harness-case "an undeclared field name is accessor-misuse"
        (lambda ()
          ;; A caller mistake, not a machine outcome: it must not arrive as a
          ;; parser-error, which is §9.3's record describing what the INPUT did.
          ;; Not §13:801 -- that line makes field access READ-ONLY and says
          ;; nothing about how a bad name is reported; the earlier version of
          ;; this comment cited it for a claim it does not make. The reporting
          ;; channel follows the existing contract-violation convention
          ;; (`invalid-slice`, `lifecycle-violation`), under a new
          ;; `accessor-misuse` code.
          (check-equal "code" (caught (lambda () (parser-field-ref (make-parser cm '() #f)
                                                                   'nosuch)))
                       'accessor-misuse)))
      (harness-case "a non-parser is invalid-argument"
        (lambda ()
          (check-equal "code" (caught (lambda () (parser-field-ref 'not-a-parser 'count)))
                       'invalid-argument)))
      ;; *** Per-parser ISOLATION of the value storage has no witness in this
      ;; slice, and no test is written for it. *** The reason the values are a
      ;; parser slot rather than closure state is that the op/exec closure is
      ;; built once per compiled machine and every parser copies the same
      ;; reference into slot 2 -- but parser-field-ref is read-only (§13:801) and
      ;; nothing in ①b ever writes a field, so two parsers sharing one vector and
      ;; two parsers holding their own are observationally identical through the
      ;; whole public API. A case here could only assert vector identity through
      ;; a probe the library does not export, or assert equality of two values
      ;; that are equal either way. Slice ② adds the writer, and the isolation
      ;; case belongs in the same commit as that writer, where it can fail.
      (harness-case "two parsers from one compiled machine each read the initials"
        (lambda ()
          (let ((a (make-parser cm '() #f)) (b (make-parser cm '() #f)))
            (check-equal "a" (parser-field-ref a 'count) 7)
            (check-equal "b" (parser-field-ref b 'count) 7))))
      (harness-case "parser-reset! restores the declared initials, not zero"
        (lambda ()
          ;; §12.5:738 returns the parser to its just-constructed state, and a
          ;; just-constructed parser holds the DECLARED initials. Zeroing would
          ;; make `u8 count = 7` mean 7 before the first reset and 0 after it.
          (let ((p (make-parser cm '() #f)))
            (parser-feed! p (make-bytevector 1 0) 0 1)
            (parser-reset! p)
            (check-equal "count" (parser-field-ref p 'count) 7)
            (check-equal "total" (parser-field-ref p 'total) 1152921504606846976)
            (check-equal "lifecycle" (parser-lifecycle p) 'ready))))
      (harness-case "a zero-field machine answers every name with accessor-misuse"
        (lambda ()
          (check-equal "code" (caught (lambda () (parser-field-ref (make-parser cm-zero '() #f)
                                                                   'count)))
                       'accessor-misuse))))))

;; The zero-field control. Its parser must still be constructible and still
;; refuse every name -- the empty table is a table, not a missing one.
(per-executor "interpreter" cm-ref cm-zero-ref)
(per-executor "generated" cm-gen cm-zero-gen)

;; The two executors are asked the same questions above, but nothing yet asserts
;; they AGREE -- each group could pass against a different wrong answer.
(harness-group "interpreter and generated agree on the field table"
  (lambda ()
    (harness-case "every declared name reads the same through both"
      (lambda ()
        (let ((a (make-parser cm-ref '() #f)) (b (make-parser cm-gen '() #f)) (seen 0))
          (for-each (lambda (kv)
                      (set! seen (+ seen 1))
                      (check-equal (symbol->string (car kv))
                                   (parser-field-ref a (car kv))
                                   (parser-field-ref b (car kv))))
                    expected-initials)
          (check-equal "every declared name was compared" seen 4))))
    ;; *** Name-keyed reads are BLIND to slot order. *** Each lane resolves a
    ;; name against its OWN declarations vector, so if the two vectors were
    ;; ordered differently both would still answer correctly for every name and
    ;; the case above would pass. The two orders come from different sources --
    ;; interpret.sls builds from `machine-fields` (the source machine),
    ;; compile.sls renders member 0 from `normal-machine-fields` (the normalized
    ;; table) -- so agreement between them is a claim, not a construction, and
    ;; this is what checks it.
    (harness-case "the emitted field table is in declaration order"
      (lambda ()
        (check "member 0 lists all four in order"
               (harness-string-contains?
                (utf8->string (render-machine (compile-machine m '()) 'field-access-parser))
                "(quote #(#((count . 7) (limit . 65535) (seen . 4294967295) (total . 1152921504606846976))))"))))
    (harness-case "the normalizer's slot order is the declaration order"
      (lambda ()
        (check-equal "names by slot"
                     (map car (normal-machine-fields
                               (normalize-machine (verification-machine (verify-machine m)))))
                     '(count limit seen total))))))


;; Milestone 4 Slice ② task 9: the OPERATION MATRIX (§25:1568's operation share,
;; §25:1569 whole). Underflow at `decrement` from 0, overflow at `increment` and
;; `add` from each width's maximum, at ALL FOUR widths, through BOTH executors.
;;
;; One machine per width rather than one per (width, operation): each carries a
;; field at its maximum and a field at zero, and the byte chooses the operation.
;; That keeps the emitted-and-loaded library count at four.
(define (matrix-machine nm width)
  (let ((mx (- (expt 2 width) 1)))
    (make-machine nm 'start
      (list (make-uint-field 'hi width mx #f) (make-uint-field 'lo width 0 #f))
      '() '() (list eof-decl rej-decl)
      (list (make-byte-dispatch-node 'start
              (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'inc 'advance) #f)
                    (make-byte-case (make-exact-byte-matcher 1) (make-edge 'plus 'advance) #f)
                    (make-byte-case (make-exact-byte-matcher 2) (make-edge 'dec 'advance) #f)
                    (make-byte-case (make-exact-byte-matcher 3) (make-edge 'good 'advance) #f))
              (make-edge 'reject 'reexecute) #f #f)
            (make-field-action-node 'inc 'increment '(hi) 'start 'over #f)
            (make-field-action-node 'plus 'add (list 'hi 1) 'start 'over #f)
            (make-field-action-node 'dec 'decrement '(lo) 'start 'over #f)
            (make-field-action-node 'good 'increment '(lo) 'start 'over #f)
            (make-error-node 'over 'rejected #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))

(define matrix-widths '(8 16 32 64))
(define matrix-lanes
  (map (lambda (w)
         (let* ((nm (string->symbol (string-append "mx" (number->string w))))
                (m (matrix-machine nm w)))
           (list w
                 (make-interpreted-machine (verify-machine m))
                 (emit-and-load m nm (string->symbol (string-append (symbol->string nm) "-parser"))
                                (string-append tmpdir "/generated-" (symbol->string nm) ".sls")))))
       matrix-widths))

(harness-group "the operation matrix over every width (§25:1568, §25:1569)"
  (lambda ()
    (harness-case "overflow, underflow and success agree across widths and lanes"
      (lambda ()
        ;; A loop with a sentinel reading the OBSERVED count, over widths AND
        ;; over the schedules within each -- AGENTS.md's rule, and the reason an
        ;; exhaustive loop that never executes cannot pass here.
        (let ((widths 0) (checks 0))
          (for-each
           (lambda (row)
             (set! widths (+ widths 1))
             (let* ((w (car row)) (ref (cadr row)) (gen (caddr row))
                    (mx (- (expt 2 w) 1))
                    (tag (lambda (t sched)
                           (string-append t " u" (number->string w) " ["
                                          (apply string-append (map number->string sched))
                                          "]"))))
               (for-each
                (lambda (spec)
                  (set! checks (+ checks 1))
                  (let* ((bs (car spec)) (fld (cadr spec)) (want (caddr spec)) (life (cadddr spec))
                         (a (feed-bytes ref bs)) (b (feed-bytes gen bs)))
                    ;; The value, in BOTH lanes, and the lifecycle -- a failed
                    ;; operation must both leave the value alone (§25:1569) and
                    ;; route to its error target.
                    (check-equal (tag (string-append "interp " (symbol->string fld)) bs)
                                 (parser-field-ref a fld) want)
                    (check-equal (tag (string-append "gen " (symbol->string fld)) bs)
                                 (parser-field-ref b fld) want)
                    (check-equal (tag "lifecycle" bs) (parser-lifecycle b) (parser-lifecycle a))
                    (check-equal (tag "expected lifecycle" bs) (parser-lifecycle a) life)))
                (list
                 ;; increment at the maximum: overflow, value unchanged.
                 (list '(0) 'hi mx 'error)
                 ;; add 1 at the maximum: overflow, value unchanged.
                 (list '(1) 'hi mx 'error)
                 ;; decrement at zero: UNDERFLOW, value unchanged.
                 (list '(2) 'lo 0 'error)
                 ;; and the success control, without which every row above
                 ;; passes on a machine that simply never writes.
                 (list '(3) 'lo 1 'ready)))))
           matrix-lanes)
          (check-equal "every width was exercised" widths 4)
          (check-equal "every schedule was exercised" checks 16))))
    (harness-case "the u64 maximum is a bignum, so the matrix is not fixnum-only"
      (lambda ()
        ;; §15:856's "must not rely on host fixnum width", asserted rather than
        ;; assumed: without this the u64 row could silently be a fixnum row on a
        ;; host with a wider fixnum, and would stop testing what it exists for.
        (check "above greatest-fixnum" (> (- (expt 2 64) 1) (greatest-fixnum)))
        (let ((ref (cadr (assv 64 matrix-lanes))))
          (check-equal "and it is the declared initial"
                       (parser-field-ref (make-parser ref '() #f) 'hi)
                       18446744073709551615))))))

(harness-finish)
