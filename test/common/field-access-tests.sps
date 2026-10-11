;;; parser-field-ref across both executors, and the field operations, predicates
;;; and checked multiply-add that write fields. The generated library is emitted
;;; at run time, loaded, and
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

;; A DISTINCT NON-ZERO INITIAL PER WIDTH, so a lane that zero-fills, reads the
;; wrong slot or transposes two slots gives a wrong answer rather than a
;; coincidentally right one -- an all-zero fixture passes under every one of
;; those defects.
;;
;; A U64 INITIAL AT OR ABOVE 2^60, which is exactly the bignum boundary on this
;; host: under the project's Chez, (fixnum-width) is 61 and (greatest-fixnum) is
;; 2^60 - 1, so 2^60 is the first non-fixnum while u32's own maximum 4294967295
;; is still a fixnum. Without it all four widths exercise the FIXNUM path only
;; and the rule that field arithmetic must not rely on host fixnum width is
;; untested end to end --
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

;; --- A machine that WRITES fields ---
;; Byte 0 increments `count` and stops; byte 1 runs `count` up against its u8
;; ceiling through a branch. Because a parse changes its fields, per-parser
;; storage isolation and parser-reset!'s restore are witnessable here.
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
          ;; one, mutations of that arm survive the whole lane.
          (make-field-branch-node 'chk 'zero '(count) 'odd 'start #f)
          (make-field-action-node 'odd 'add '(seen 100) 'start 'over #f)
          ;; Overflows from BELOW the ceiling: 254 + 10 = 264 > 255. Without this
          ;; the only overflow in the fixture starts AT 255, where "leaves the
          ;; prior value unchanged" and "clamps to the maximum" coincide -- and a
          ;; mutant that clamps survives.
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

(harness-group "fields a parse actually writes"
  (lambda ()
    (harness-case "an increment commits into the parser's own storage"
      (lambda ()
        (let ((p (feed-bytes wm-ref '(0))))
          (check-equal "count" (parser-field-ref p 'count) 255)
          (check-equal "seen" (parser-field-ref p 'seen) 1))))
    (harness-case "a failed operation leaves the prior value unchanged"
      (lambda ()
        ;; 254 -> 255 on the first byte; the second increment overflows a u8 and
        ;; must route to the error target WITHOUT writing: overflow leaves the
        ;; prior value alone.
        (let ((p (feed-bytes wm-ref '(0 0))))
          (check-equal "count held at its maximum" (parser-field-ref p 'count) 255)
          (check-equal "lifecycle" (parser-lifecycle p) 'error))))
    (harness-case "an overflow from BELOW the ceiling does not clamp"
      (lambda ()
        ;; A failed operation leaves the prior value unchanged -- not
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
        ;; Position kind is differential-compared, so the two lanes disagreeing
        ;; here is a lane failure rather than a cosmetic one. The rule: a
        ;; zero-width step does not move the parser in the input, so `pk` is
        ;; carried THROUGH. On an EOF
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
                          ;; rejects it.
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
    ;; Per-parser isolation of field storage. Without a write, two parsers
    ;; sharing one vector and two holding their own are observationally
    ;; identical; feeding one of them is what lets this case fail.
    (harness-case "two parsers from one compiled machine do not share field storage"
      (lambda ()
        (let ((a (feed-bytes wm-ref '(0))) (b (make-parser wm-ref '() #f)))
          (check-equal "the one that fed" (parser-field-ref a 'count) 255)
          (check-equal "the one that did not" (parser-field-ref b 'count) 254))))
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
        ;;
        ;; *** Each lane is also asserted against an EXPECTED value, not only
        ;; against the other lane. *** Agreement is symmetric, so breaking
        ;; either implementation of the same decision produces the SAME record,
        ;; and a mutant of the emitter would nest inside the matching mutant of
        ;; the interpreter with no record of its own. Per-lane expected values
        ;; separate them. The table is MEASURED from the green tree: `count` is
        ;; a u8 declared at 254, byte 0 increments it to 255 and byte 1 runs it
        ;; up against the ceiling until the failure branch fires.
        (let ((seen 0))
          (for-each
           (lambda (row)
             (set! seen (+ seen 1))
             ;; The check label names the WHOLE schedule, not just its first
             ;; byte. With `(0)` and `(0 0)` both labelled "0", two different
             ;; mutants would produce byte-identical FAIL records and no pin
             ;; could tell them apart.
             (let* ((bs (car row)) (want-count (cadr row))
                    (want-seen (caddr row)) (want-life (cadddr row))
                    (a (feed-bytes wm-ref bs)) (b (feed-bytes wm-gen bs))
                    (nm (apply string-append (map number->string bs))))
               (check-equal (string-append "count [" nm "]")
                            (parser-field-ref b 'count) (parser-field-ref a 'count))
               (check-equal (string-append "seen [" nm "]")
                            (parser-field-ref b 'seen) (parser-field-ref a 'seen))
               (check-equal (string-append "lifecycle [" nm "]")
                            (parser-lifecycle b) (parser-lifecycle a))
               (check-equal (string-append "interpreter count [" nm "]")
                            (parser-field-ref a 'count) want-count)
               (check-equal (string-append "generated count [" nm "]")
                            (parser-field-ref b 'count) want-count)
               (check-equal (string-append "interpreter seen [" nm "]")
                            (parser-field-ref a 'seen) want-seen)
               (check-equal (string-append "generated seen [" nm "]")
                            (parser-field-ref b 'seen) want-seen)
               (check-equal (string-append "interpreter lifecycle [" nm "]")
                            (parser-lifecycle a) want-life)
               (check-equal (string-append "generated lifecycle [" nm "]")
                            (parser-lifecycle b) want-life)))
           '(((0)   255 1 ready)
             ((1)   254 0 error)
             ((2)   254 0 error)
             ((0 0) 255 1 error)
             ((0 1) 255 1 error)
             ((1 0) 254 0 error)))
          (check-equal "every schedule compared" seen 6))))
    (harness-case "parser-reset! restores a field a parse has CHANGED"
      (lambda ()
        (let ((p (feed-bytes wm-ref '(0))))
          (check-equal "changed by the parse" (parser-field-ref p 'count) 255)
          (parser-reset! p)
          (check-equal "restored to the declared initial" (parser-field-ref p 'count) 254)
          (check-equal "and the other field too" (parser-field-ref p 'seen) 0))))))

;; The zero-field control exists PER LANE. With one interpreted machine shared
;; by both groups, the case inside "parser-field-ref (generated)" would run the
;; interpreter, and the generated lane's empty-member-0 path would execute
;; nowhere: the two lanes could disagree on parser-field-ref with the suite
;; green.
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
          ;; reads the OBSERVED count rather than the test's own expectation.
          ;; No suite here declares an expected case count,
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
          ;; parser-error, which is the record describing what the INPUT did.
          ;; The reporting channel follows the contract-violation convention
          ;; (`invalid-slice`, `lifecycle-violation`), under the
          ;; `accessor-misuse` code.
          (check-equal "code" (caught (lambda () (parser-field-ref (make-parser cm '() #f)
                                                                   'nosuch)))
                       'accessor-misuse)))
      (harness-case "a non-parser is invalid-argument"
        (lambda ()
          (check-equal "code" (caught (lambda () (parser-field-ref 'not-a-parser 'count)))
                       'invalid-argument)))
      ;; The values are a parser slot rather than closure state because the
      ;; op/exec closure is built once per compiled machine and every parser
      ;; copies the same reference into slot 2. This machine never writes a
      ;; field, so isolation is not observable here; the writer group above
      ;; witnesses it.
      (harness-case "two parsers from one compiled machine each read the initials"
        (lambda ()
          (let ((a (make-parser cm '() #f)) (b (make-parser cm '() #f)))
            (check-equal "a" (parser-field-ref a 'count) 7)
            (check-equal "b" (parser-field-ref b 'count) 7))))
      (harness-case "parser-reset! restores the declared initials, not zero"
        (lambda ()
          ;; parser-reset! returns the parser to its just-constructed state, and a
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
                "(quote #(#((count . 7) (limit . 65535) (seen . 4294967295) (total . 1152921504606846976)) #() #(start stop reject)))"))))
    (harness-case "the normalizer's slot order is the declaration order"
      (lambda ()
        (check-equal "names by slot"
                     (map car (normal-machine-fields
                               (normalize-machine (verification-machine (verify-machine m)))))
                     '(count limit seen total))))))


;; The OPERATION MATRIX. Underflow at `decrement` from 0, overflow at
;; `increment` and `add` from each width's maximum, at ALL FOUR widths, through
;; BOTH executors.
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

(harness-group "the operation matrix over every width"
  (lambda ()
    (harness-case "overflow, underflow and success agree across widths and lanes"
      (lambda ()
        ;; A loop with a sentinel reading the OBSERVED count, over widths AND
        ;; over the schedules within each, so an exhaustive loop that never
        ;; executes cannot pass here.
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
                    ;; operation must both leave the value alone and route to
                    ;; its error target.
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
                 (list '(3) 'lo 1 'ready)))
               ;; Both ends of the bound as one value per lane. Each row above
               ;; reads one end, so a lane that loosens one end of the bound and
               ;; a lane that drops the whole check fail the same rows with
               ;; identical records; only a value spanning the overflow AND the
               ;; underflow tells the three apart. Outside the `checks` count:
               ;; that sentinel counts the rows, and this is not one.
               (check-equal (tag "interp both ends" '(0 2))
                            (list (parser-field-ref (feed-bytes ref '(0)) 'hi)
                                  (parser-field-ref (feed-bytes ref '(2)) 'lo))
                            (list mx 0))
               (check-equal (tag "gen both ends" '(0 2))
                            (list (parser-field-ref (feed-bytes gen '(0)) 'hi)
                                  (parser-field-ref (feed-bytes gen '(2)) 'lo))
                            (list mx 0))))
           matrix-lanes)
          (check-equal "every width was exercised" widths 4)
          (check-equal "every schedule was exercised" checks 16))))
    (harness-case "the u64 maximum is a bignum, so the matrix is not fixnum-only"
      (lambda ()
        ;; "Must not rely on host fixnum width", asserted rather than
        ;; assumed: without this the u64 row could silently be a fixnum row on a
        ;; host with a wider fixnum, and would stop testing what it exists for.
        (check "above greatest-fixnum" (> (- (expt 2 64) 1) (greatest-fixnum)))
        (let ((ref (cadr (assv 64 matrix-lanes))))
          (check-equal "and it is the declared initial"
                       (parser-field-ref (make-parser ref '() #f) 'hi)
                       18446744073709551615))))))


;; The seven operations and seven predicates are written TWICE on purpose, once
;; per executor, and the interpreter≡generated differential is what catches a
;; divergence. But a differential only compares what a fixture EXERCISES: with
;; no fixture reaching `mask-none`, inverting the EMITTER's `mask-none` alone
;; leaves the two lanes silently disagreeing with every lane green. This group
;; reaches all fourteen.
;;
;; One byte per operation and one per predicate, all fourteen, driven through
;; BOTH executors. The values are chosen so that no operation overflows: this
;; group is about AGREEMENT, and the bound checks are the matrix group's job.
(define cov-initial 12)
(define (cov-marker nm k) (make-field-action-node nm 'set-mask (list 'seen k) 'start #f #f))
(define cov-machine
  (make-machine 'cov 'start
    (list (make-uint-field 'f 8 cov-initial #f) (make-uint-field 'seen 8 0 #f))
    '() '() (list eof-decl rej-decl)
    (append
     (list (make-byte-dispatch-node 'start
             (map (lambda (i n)
                    (make-byte-case (make-exact-byte-matcher i) (make-edge n 'advance) #f))
                  '(0 1 2 3 4 5 6 7 8 9 10 11 12 13)
                  '(o-store o-clear o-inc o-dec o-add o-set o-clr
                    p-eq p-zero p-nz p-rng p-many p-mall p-mnone))
             (make-edge 'reject 'reexecute) #f #f)
           ;; The seven operations. store/clear/set-mask/clear-mask cannot fail,
           ;; so the constructor forbids an error target on them; the other three
           ;; require one.
           (make-field-action-node 'o-store 'store '(f 200) 'start #f #f)
           (make-field-action-node 'o-clear 'clear '(f) 'start #f #f)
           (make-field-action-node 'o-inc 'increment '(f) 'start 'over #f)
           (make-field-action-node 'o-dec 'decrement '(f) 'start 'over #f)
           (make-field-action-node 'o-add 'add '(f 5) 'start 'over #f)
           (make-field-action-node 'o-set 'set-mask '(f 129) 'start #f #f)
           (make-field-action-node 'o-clr 'clear-mask '(f 8) 'start #f #f)
           ;; The seven predicates, each routing to a shared pair of markers so
           ;; the ARM TAKEN is observable as a value: true writes 1, false 2.
           ;; *** The operands are chosen so each predicate is distinguishable
           ;; from its SIBLINGS, not merely exercised. *** With `equal 12` on
           ;; f=12 the answer is true, and an implementation that computed
           ;; `nonzero` instead would also answer true -- the case would pass on
           ;; the wrong predicate. `equal 99` is false where `nonzero` is true,
           ;; so the two are separated. Same reasoning for `mask-all 14` below,
           ;; which an implementation computing `mask-any` gets wrong;
           ;; `mask-all 12` on f=12 does not separate them.
           (make-field-branch-node 'p-eq 'equal '(f 99) 'yes 'no #f)
           (make-field-branch-node 'p-zero 'zero '(f) 'yes 'no #f)
           (make-field-branch-node 'p-nz 'nonzero '(f) 'yes 'no #f)
           (make-field-branch-node 'p-rng 'range '(f 10 20) 'yes 'no #f)
           (make-field-branch-node 'p-many 'mask-any '(f 4) 'yes 'no #f)
           (make-field-branch-node 'p-mall 'mask-all '(f 14) 'yes 'no #f)
           (make-field-branch-node 'p-mnone 'mask-none '(f 3) 'yes 'no #f)
           (cov-marker 'yes 1)
           (cov-marker 'no 2)
           (make-error-node 'over 'rejected #f)
           (make-error-node 'reject 'rejected #f)))
    'default-eof #f))
(define cov-ref (make-interpreted-machine (verify-machine cov-machine)))
(define cov-gen (emit-and-load cov-machine 'cov 'cov-parser
                               (string-append tmpdir "/generated-cov.sls")))

(harness-group "all seven operations and all seven predicates, both lanes"
  (lambda ()
    (harness-case "every operation computes the same value in both lanes"
      (lambda ()
        ;; The expected values are stated, not merely compared across lanes: two
        ;; lanes that are wrong in the SAME way would agree, and agreement bought
        ;; that way is what this project has recorded as disarming its own test.
        (let ((seen 0))
          (for-each
           (lambda (row)
             (set! seen (+ seen 1))
             (let* ((b (car row)) (want (cadr row)) (nm (caddr row))
                    (a (feed-bytes cov-ref (list b))) (g (feed-bytes cov-gen (list b))))
               (check-equal (string-append "interp " nm) (parser-field-ref a 'f) want)
               (check-equal (string-append "gen " nm) (parser-field-ref g 'f) want)))
           ;; f starts at 12.
           '((0 200 "store") (1 0 "clear") (2 13 "increment") (3 11 "decrement")
             (4 17 "add") (5 141 "set-mask") (6 4 "clear-mask")))
          (check-equal "all seven operations" seen 7))))
    (harness-case "every predicate takes the same arm in both lanes"
      (lambda ()
        ;; `seen` is 1 when the true arm ran and 2 when the false arm did, so an
        ;; inverted predicate in EITHER lane is a different number here.
        (let ((seen 0))
          (for-each
           (lambda (row)
             (set! seen (+ seen 1))
             (let* ((b (car row)) (want (cadr row)) (nm (caddr row))
                    (a (feed-bytes cov-ref (list b))) (g (feed-bytes cov-gen (list b))))
               (check-equal (string-append "interp " nm) (parser-field-ref a 'seen) want)
               (check-equal (string-append "gen " nm) (parser-field-ref g 'seen) want)))
           ;; f = 12 = #b1100.
           '((7 2 "equal 99") (8 2 "zero") (9 1 "nonzero") (10 1 "range 10-20")
             (11 1 "mask-any 4") (12 2 "mask-all 14") (13 1 "mask-none 3")))
          (check-equal "all seven predicates" seen 7))))))


;; The checked multiply-add, BOTH lanes.
;;
;; The inequality is a check BEFORE the multiply-add, not a compute-then-check,
;; because field arithmetic must not rely on host fixnum width or silent
;; wrapping. Computing the product first is safe under Chez's bignums and would
;; not be safe under a host that wraps, so both lanes render the pre-check. They
;; render it by different arithmetic: the interpreter tests
;; `current <= floor((maximum - digit) / base)` on every digit, and the
;; generated lane compares `current` against the quotient and remainder of
;; `maximum / base`, divided out when the arm is emitted.
(define (acc-mach nm base width)
  (make-machine nm 'start (list (make-uint-field 'n width 0 #f)) '() '()
    (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-byte-range-matcher 0 255)
                                  (make-edge 'acc 'reexecute) #f))
            (make-edge 'acc 'reexecute) #f #f)
          (make-integer-accumulate-node 'acc 'n base 'acc
                                        (make-edge 'done 'advance) 'over #f #f)
          (make-stop-node 'done #f)
          ;; No spare `reject` node: the range matcher covers all 256 bytes, so
          ;; the fallback is unreachable and an error node nothing names is
          ;; itself unreachable.
          (make-error-node 'over 'rejected #f))
    'default-eof #f))
(define (acc-lanes nm base width)
  (let ((m (acc-mach nm base width)))
    (cons (make-interpreted-machine (verify-machine m))
          (emit-and-load m nm (string->symbol (string-append (symbol->string nm) "-parser"))
                         (string-append tmpdir "/generated-" (symbol->string nm) ".sls")))))
(define acc10 (acc-lanes 'acc10 10 32))
(define acc16 (acc-lanes 'acc16 16 32))
(define acc8bit (acc-lanes 'acc8 10 8))
(define (str->bytes str) (u8-list->bytevector (map char->integer (string->list str))))
(define (run-acc cm str)
  (let ((p (make-parser cm '() #f)))
    (parser-feed! p (str->bytes str) 0 (string-length str))
    p))

(harness-group "the checked multiply-add, both lanes"
  (lambda ()
    (harness-case "base 10 accumulates across a run of digits"
      (lambda ()
        (let ((a (run-acc (car acc10) "12345x")) (g (run-acc (cdr acc10) "12345x")))
          (check-equal "interpreter" (parser-field-ref a 'n) 12345)
          (check-equal "generated" (parser-field-ref g 'n) 12345))))
    (harness-case "base 16 accepts all three ASCII digit ranges"
      (lambda ()
        ;; The reason the digit test is not one `case` group with one `d`: base
        ;; 16's digits are three DISJOINT ranges, and a fixture using only 0-9
        ;; would pass against an implementation that handled no letters at all.
        (let ((a (run-acc (car acc16) "1aF!")) (g (run-acc (cdr acc16) "1aF!")))
          (check-equal "interpreter" (parser-field-ref a 'n) 431)
          (check-equal "generated" (parser-field-ref g 'n) 431))))
    (harness-case "a base-10 machine does not accept a hex letter as a digit"
      (lambda ()
        ;; The converse, without which "base reaches the arithmetic" is unwitnessed.
        (let ((a (run-acc (car acc10) "1a")) (g (run-acc (cdr acc10) "1a")))
          (check-equal "interpreter" (parser-field-ref a 'n) 1)
          (check-equal "generated" (parser-field-ref g 'n) 1))))
    (harness-case "overflow leaves the value unchanged and does not consume the digit"
      (lambda ()
        ;; Overflow leaves the value unchanged and does not consume the
        ;; offending digit. A u8 field reaches 25,
        ;; and the next digit would make 255 -- legal -- while a further one
        ;; would not. "999" therefore overflows at the third byte with n = 99.
        (let ((a (run-acc (car acc8bit) "999")) (g (run-acc (cdr acc8bit) "999")))
          (check-equal "interpreter holds 99" (parser-field-ref a 'n) 99)
          (check-equal "generated holds 99" (parser-field-ref g 'n) 99)
          (check-equal "both errored" (parser-lifecycle g) (parser-lifecycle a))
          (check-equal "lifecycle" (parser-lifecycle a) 'error))))
    (harness-case "an overflow reports position kind BYTE, at the offending digit"
      (lambda ()
        ;; "Does not consume" made observable: the kind is `byte` rather than
        ;; `boundary` precisely because the offending byte was not consumed.
        ;; Position kind is compared across lanes.
        (let* ((a (run-acc (car acc8bit) "999")) (g (run-acc (cdr acc8bit) "999"))
               (ra (parser-feed! a (make-bytevector 0) 0 0))
               (rg (parser-feed! g (make-bytevector 0) 0 0)))
          (check-equal "interpreter" (parser-error-position-kind (parser-result-error ra)) 'byte)
          (check-equal "generated" (parser-error-position-kind (parser-result-error rg)) 'byte))))
    (harness-case "the boundary digit is accepted, one below the overflow"
      (lambda ()
        ;; Without this the overflow case passes against an implementation that
        ;; rejects one digit too early. 255 is the u8 maximum and must be reached.
        (let ((a (run-acc (car acc8bit) "255x")) (g (run-acc (cdr acc8bit) "255x")))
          (check-equal "interpreter" (parser-field-ref a 'n) 255)
          (check-equal "generated" (parser-field-ref g 'n) 255)
          (check-equal "not an error" (parser-lifecycle a) 'stopped))))
    (harness-case "the bound's quotient rows, at u8 and at u64"
      (lambda ()
        ;; 255 is 25 * 10 + 5: a digit after 25 is accepted up to 5 and refused
        ;; from 6, a digit after 24 is accepted whatever it is, and after 26
        ;; none is. 2^64 - 1 is 1844674407370955161 * 10 + 5, the same row
        ;; with a quotient above the fixnum range. Each lane's answers are ONE
        ;; value holding both rows, so each way of mis-splitting the bound
        ;; reports its own value: refusing every value equal to the quotient,
        ;; testing the remainder strictly, taking the wrong remainder, admitting
        ;; the quotient whatever the digit, or comparing with an equality that
        ;; holds only for fixnums, which leaves the u8 row right.
        (let* ((u64 (acc-lanes 'acc64row 10 64))
               (q64 1844674407370955161)
               (u8-row '("249x" "250x" "254x" "255x" "256x" "260x"))
               (u64-row '("18446744073709551609x" "18446744073709551610x"
                          "18446744073709551615x" "18446744073709551616x"
                          "18446744073709551620x"))
               (want (list '(249 250 254 255 25 26)
                           (list 18446744073709551609 18446744073709551610
                                 18446744073709551615 q64 (+ q64 1))))
               (answers (lambda (cm row)
                          (map (lambda (str) (parser-field-ref (run-acc cm str) 'n)) row)))
               (rows (lambda (u8 wide) (list (answers u8 u8-row) (answers wide u64-row)))))
          (check "the u64 quotient is above greatest-fixnum" (> q64 (greatest-fixnum)))
          (check-equal "interpreter quotient rows" (rows (car acc8bit) (car u64)) want)
          (check-equal "generated quotient rows" (rows (cdr acc8bit) (cdr u64)) want))))
    (harness-case "the u64 path crosses the bignum boundary in both lanes"
      (lambda ()
        ;; "Must not rely on host fixnum width", end to end: 2^60 has
        ;; nineteen decimal digits and the accumulated value passes
        ;; (greatest-fixnum) partway through.
        (let* ((l (acc-lanes 'acc64 10 64))
               (a (run-acc (car l) "1152921504606846976x"))
               (g (run-acc (cdr l) "1152921504606846976x")))
          (check-equal "interpreter" (parser-field-ref a 'n) 1152921504606846976)
          (check-equal "generated" (parser-field-ref g 'n) 1152921504606846976)
          (check "above greatest-fixnum" (> (parser-field-ref a 'n) (greatest-fixnum))))))))


;; Need-input resumption and split-point fragmentation.
;;
;; *** An accumulate node needs NO state of its own across a feed boundary. ***
;; The partially-consumed-digits state is the field itself: the accumulated
;; value IS the field, which is parser slot 8 and
;; already survives a feed, and `current` stays parked on the accumulate node
;; because the arm returns `need-input` without moving it -- exactly what the
;; dispatch arm does. The split-point behaviour is INHERITED, not invented, and
;; these cases are what makes that a fact rather than an assumption.
(define (feed-split cm str at)
  ;; Feed `str` in two slices, split after `at` bytes.
  (let ((p (make-parser cm '() #f)) (bs (str->bytes str)))
    (parser-feed! p bs 0 at)
    (parser-feed! p bs at (bytevector-length bs))
    p))

(harness-group "split-point fragmentation"
  (lambda ()
    (harness-case "a number split across a feed boundary accumulates whole"
      (lambda ()
        (let ((a (feed-split (car acc10) "12345x" 2))
              (g (feed-split (cdr acc10) "12345x" 2)))
          (check-equal "interpreter" (parser-field-ref a 'n) 12345)
          (check-equal "generated" (parser-field-ref g 'n) 12345))))
    (harness-case "every split point of the same input gives the same answer"
      (lambda ()
        ;; EVERY split, not one: the split-point idiom elsewhere in the
        ;; tree is hardcoded for a four-byte input, and a single split cannot see
        ;; a defect that only appears when the boundary lands on the first or
        ;; last byte. A sentinel reads the OBSERVED count of splits.
        (let* ((str "12345x") (n (string-length str)) (seen 0))
          (let loop ((at 0))
            (when (<= at n)
              (set! seen (+ seen 1))
              (let ((a (feed-split (car acc10) str at))
                    (g (feed-split (cdr acc10) str at)))
                (check-equal (string-append "interpreter split " (number->string at))
                             (parser-field-ref a 'n) 12345)
                (check-equal (string-append "generated split " (number->string at))
                             (parser-field-ref g 'n) 12345))
              (loop (+ at 1))))
          (check-equal "every split point was tried" seen 7))))
    (harness-case "an empty slice mid-number yields need-input and changes nothing"
      (lambda ()
        ;; The degenerate boundary: a feed with no bytes must not advance, must
        ;; not lose the partial value, and must leave the parser resumable.
        (let* ((p (make-parser (car acc10) '() #f))
               (bs (str->bytes "12345x")))
          (parser-feed! p bs 0 3)
          (let ((mid (parser-field-ref p 'n))
                (r (parser-feed! p (make-bytevector 0) 0 0)))
            (check-equal "partial value" mid 123)
            (check-equal "need-input" (parser-result-status r) 'need-input)
            (check-equal "unchanged by the empty slice" (parser-field-ref p 'n) 123)
            (parser-feed! p bs 3 6)
            (check-equal "resumes and completes" (parser-field-ref p 'n) 12345)))))
    (harness-case "an overflow split across a boundary still reports at the offending byte"
      (lambda ()
        ;; The interaction the two features have with each other: a
        ;; non-consuming overflow whose digit arrives in the SECOND slice must
        ;; still report `byte`, not `boundary`.
        (let* ((a (feed-split (car acc8bit) "999" 2))
               (r (parser-feed! a (make-bytevector 0) 0 0)))
          (check-equal "held at 99" (parser-field-ref a 'n) 99)
          (check-equal "position kind"
                       (parser-error-position-kind (parser-result-error r)) 'byte))))))


;; Bases 10 and 16 over ALL 256 byte values, both lanes. The partition is the
;; point -- every byte is either a digit for that base or it is not, and the two
;; lanes must agree on which, byte by byte, with no byte untested. A fixture
;; naming a handful of digits and a handful of delimiters cannot see a boundary
;; error at `/`, `:`, `@`, `G`, backtick or `g` -- the SIX ASCII neighbours of
;; the three digit ranges, two per range.
(define (byte-answer cm b)
  ;; Feed exactly one byte and report (field . lifecycle): a digit accumulates
  ;; and leaves the parser ready, a non-digit takes the fallback to `done`.
  (let ((p (make-parser cm '() #f)))
    (parser-feed! p (make-bytevector 1 b) 0 1)
    (cons (parser-field-ref p 'n) (parser-lifecycle p))))

(harness-group "all 256 bytes, both bases, both lanes"
  (lambda ()
    (harness-case "base 10 partitions every byte identically in both lanes"
      (lambda ()
        ;; A sentinel over the OBSERVED count of bytes compared, and a single
        ;; first-divergence report rather than 256 failures -- the
        ;; all-256 lanes' own idiom.
        (let ((seen 0) (bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (set! seen (+ seen 1))
              (let ((a (byte-answer (car acc10) b)) (g (byte-answer (cdr acc10) b)))
                (when (and (eq? bad 'none) (not (equal? a g))) (set! bad (list b a g))))
              (loop (+ b 1))))
          (check-equal "every byte compared" seen 256)
          (check-equal "no divergence" bad 'none))))
    (harness-case "base 16 partitions every byte identically in both lanes"
      (lambda ()
        (let ((seen 0) (bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (set! seen (+ seen 1))
              (let ((a (byte-answer (car acc16) b)) (g (byte-answer (cdr acc16) b)))
                (when (and (eq? bad 'none) (not (equal? a g))) (set! bad (list b a g))))
              (loop (+ b 1))))
          (check-equal "every byte compared" seen 256)
          (check-equal "no divergence" bad 'none))))
    (harness-case "base 10 accepts exactly ten bytes, base 16 exactly twenty-two"
      (lambda ()
        ;; The partition's SIZE, which cross-lane agreement cannot see: two lanes
        ;; that both accepted no bytes at all would agree perfectly. Counted
        ;; PER LANE rather than once, because an emitter-only range error leaves
        ;; the interpreter's count right -- so a single count would attribute
        ;; every partition defect to the interpreter.
        (let ((n10 0) (n16 0) (g10 0) (g16 0))
          (let loop ((b 0))
            (when (< b 256)
              (when (eq? (cdr (byte-answer (car acc10) b)) 'ready) (set! n10 (+ n10 1)))
              (when (eq? (cdr (byte-answer (car acc16) b)) 'ready) (set! n16 (+ n16 1)))
              (when (eq? (cdr (byte-answer (cdr acc10) b)) 'ready) (set! g10 (+ g10 1)))
              (when (eq? (cdr (byte-answer (cdr acc16) b)) 'ready) (set! g16 (+ g16 1)))
              (loop (+ b 1))))
          (check-equal "interpreter base 10" n10 10)
          (check-equal "interpreter base 16" n16 22)
          (check-equal "generated base 10" g10 10)
          (check-equal "generated base 16" g16 22))))
    (harness-case "every digit range endpoint decodes to its own value, in both lanes"
      (lambda ()
        ;; The six ENDPOINTS of the three ASCII ranges, asserted as decoded
        ;; VALUES rather than as a lifecycle. That is what separates an off-by-one
        ;; at a bound from every other way the arm can break: a mutation that
        ;; stops the whole node from running leaves these unread, while a
        ;; mutation that moves one bound by one changes exactly one of these
        ;; numbers. Asserted as lifecycles instead, the `f` bound's mutation
        ;; would own no FAIL record of its own.
        (let ((seen 0))
          (for-each
           (lambda (spec)
             (set! seen (+ seen 1))
             (let ((b (cadr spec)) (want (caddr spec)))
               (check-equal (string-append "interpreter " (car spec))
                            (car (byte-answer (car acc16) b)) want)
               (check-equal (string-append "generated " (car spec))
                            (car (byte-answer (cdr acc16) b)) want)))
           '(("zero" 48 0) ("nine" 57 9) ("A" 65 10) ("F" 70 15)
             ("a" 97 10) ("f" 102 15)))
          (check-equal "all six endpoints" seen 6))))
    (harness-case "the six ASCII neighbours of the digit ranges are not digits"
      (lambda ()
        ;; `/` and `:` bracket 0-9; `@` and `G` bracket A-F; backtick and `g`
        ;; bracket a-f. An off-by-one that widens a range moves exactly one of
        ;; these, and the all-256 comparison cannot see it when both lanes move
        ;; together -- which they would, being written from the same reading.
        ;; Asserted as a VALUE too: a non-digit leaves the field at its initial.
        (let ((seen 0))
          (for-each (lambda (spec)
                      (set! seen (+ seen 1))
                      (check-equal (string-append "interpreter " (car spec))
                                   (byte-answer (car acc16) (cadr spec)) '(0 . stopped))
                      (check-equal (string-append "generated " (car spec))
                                   (byte-answer (cdr acc16) (cadr spec)) '(0 . stopped)))
                    '(("slash" 47) ("colon" 58) ("at" 64) ("G" 71) ("backtick" 96) ("g" 103)))
          (check-equal "all six neighbours" seen 6))))))


;; An accumulate node is a default-EOF consumer. The emitter's
;; reached-declaration walk must credit it with the default-EOF route: if only
;; `dispatch` states were credited, a machine whose ONLY default-eof consumer is
;; an accumulate node would have that declaration filtered out of the emitted
;; errs table, and index-of would raise "no error declaration for code" while
;; rendering a machine the verifier accepts with zero diagnostics.
;;
;; Every other accumulate fixture in this file misses it by construction: each
;; has an entry dispatch that also defaults its eof route, so the pair is in the
;; reached set for another state's sake. Separating them takes an entry whose
;; eof goes somewhere ELSE -- here a finish node. The property generator reaches
;; this shape when its eof draw and accumulate draw fire together.
;;
;; Kept as a fixed fixture rather than left to the property lane: the generated
;; sequence re-rolls whenever any draw changes, and a defect whose only witness
;; is a seeded draw has a witness that can vanish without anyone editing it.
(define acc-eof-only
  (let ((errs (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
                    (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))))
    (make-machine 'acc-eof-only 'start (list (make-uint-field 'n 8 0 #f)) '() '() errs
                  (list (make-byte-dispatch-node
                         'start
                         (list (make-byte-case (make-byte-range-matcher 0 255)
                                               (make-edge 'acc 'reexecute) #f))
                         (make-edge 'over 'reexecute)
                         ;; The entry's own eof goes to a FINISH, so the entry
                         ;; needs no default-eof declaration. The accumulate node
                         ;; below declares eof-target #f and is the only state
                         ;; left that can reach the machine default.
                         'done #f)
                        (make-integer-accumulate-node 'acc 'n 10 'acc
                                                      (make-edge 'stopped 'advance)
                                                      'over #f #f)
                        (make-finish-node 'done #f)
                        (make-stop-node 'stopped #f)
                        (make-error-node 'over 'rejected #f))
                  'default-eof #f)))

;; Emitted ONCE and shared by the cases below -- the generated library name is
;; (generated <machine-name>), so two emissions of the same machine would load
;; two libraries under one name into the same process -- but LAZILY, inside a
;; case rather than at top level. The defect this fixture pins makes emission
;; RAISE, and a raise at top level kills the program before the harness can
;; record anything: the lane exits 255 with no case named, where the same raise
;; inside a case is recorded against that case and exits 1. The difference is
;; what a reader sees when it regresses -- and the mutation suite reads the
;; status, so 255 is reported as caught for the WRONG REASON.
(define acc-eof-cache #f)
(define (acc-eof-pair)
  (unless acc-eof-cache
    (set! acc-eof-cache
          (cons (make-interpreted-machine (verify-machine acc-eof-only))
                (emit-and-load acc-eof-only 'acc-eof-only 'acc-eof-only-parser
                               (string-append tmpdir "/generated-acc-eof-only.sls")))))
  acc-eof-cache)

(harness-group "an accumulate node is a default-EOF consumer"
  (lambda ()
    (harness-case "the verifier accepts a machine whose only default-eof consumer is the accumulate node"
      (lambda ()
        ;; Stated first and separately: if this shape is ever made
        ;; illegal, THIS is the check that should fail and say so, rather than
        ;; the emission below failing for a reason that reads like an emitter
        ;; defect.
        (let ((v (verify-machine acc-eof-only)))
          (check "accepted" (verification-ok? v))
          (check-equal "no diagnostics" (length (verification-diagnostics v)) 0))))
    (harness-case "the accumulate node's own eof route resolves the default declaration"
      (lambda ()
        ;; The route that actually asks index-of for the default-eof declaration,
        ;; and the reason a missing declaration makes emission RAISE rather than
        ;; fail a comparison. A digit leaves the parser parked on `acc`, whose eof-target
        ;; is #f; finishing there takes the machine default.
        (let* ((pair (acc-eof-pair)) (a (car pair)) (g (cdr pair))
               (pa (make-parser a '() #f)) (pg (make-parser g '() #f)))
          (parser-feed! pa (str->bytes "7") 0 1)
          (parser-feed! pg (str->bytes "7") 0 1)
          (check-equal "interpreter accumulated" (parser-field-ref pa 'n) 7)
          (check-equal "generated accumulated" (parser-field-ref pg 'n) 7)
          (let ((ra (parser-finish! pa)) (rg (parser-finish! pg)))
            (check-equal "interpreter errors at eof" (parser-result-status ra) 'error)
            (check-equal "the lanes agree on the status"
                         (parser-result-status rg) (parser-result-status ra))
            ;; The reason is the assertion the filter defect was about: the
            ;; declaration must still be IN the emitted table to be named here.
            (check-equal "interpreter names the default-eof declaration"
                         (parser-error-reason (parser-result-error ra))
                         "unexpected end of input")
            (check-equal "generated names the same declaration"
                         (parser-error-reason (parser-result-error rg))
                         "unexpected end of input")
            (check-equal "position kind"
                         (parser-error-position-kind (parser-result-error rg)) 'eof)))))
    (harness-case "while the entry's own eof route still reaches its finish node"
      (lambda ()
        ;; The other half of the separation, and what makes the fixture's shape
        ;; load-bearing rather than incidental: the entry does NOT default its eof
        ;; route, which is precisely why the accumulate node was the only consumer
        ;; of the default declaration and why the filter dropped it.
        (let* ((pair (acc-eof-pair)) (a (car pair)) (g (cdr pair))
               (ra (parser-finish! (make-parser a '() #f)))
               (rg (parser-finish! (make-parser g '() #f))))
          (check-equal "interpreter finishes" (parser-result-status ra) 'finished)
          (check-equal "the lanes agree" (parser-result-status rg)
                       (parser-result-status ra)))))))


;; *** FOUR operands of the accumulate node that the fixtures above leave
;; unwitnessed. *** Each of them declares exactly ONE field (so the slot is
;; always 0 and the width always the only width), names ITSELF as its
;; digit-target (so nothing checks the operand is read at all), gives its
;; non-digit edge mode `advance` (so the NORMAL case, reexecuting the delimiter,
;; runs nowhere), and overflows only in base 10 (so `base` in the bound's
;; divisor is indistinguishable from the literal 10 here).
;;
;; determinism-accumulate-tests.sps drives a base 16 overflow, but only through
;; the GENERATED lane, so it cannot catch an interpreter-side divisor mutation.
;;
;; One machine separates all four, because they are four operands of one node and
;; a fixture per operand would share every other operand's blind spot:
;;
;;   fields (pad n)   -- `n` is SLOT 1. A lane reading slot 0 reads `pad`.
;;   base 16          -- and the overflow case below is a u16 ceiling in base 16.
;;   digit-target     -- `bump`, a separate node, not `acc` itself.
;;   nondigit-edge    -- `(tail . reexecute)`, so the delimiter is RE-READ.
(define drift-errs (list eof-decl rej-decl))
(define two-field-acc
  (make-machine 'twofield 'start
    (list (make-uint-field 'pad 8 0 #f) (make-uint-field 'n 16 0 #f))
    '() '() drift-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 35)
                                  (make-edge 'acc 'advance) #f))
            (make-edge 'over 'reexecute) #f #f)
          (make-integer-accumulate-node 'acc 'n 16 'bump
                                        (make-edge 'tail 'reexecute)
                                        'over #f #f)
          ;; The digit target: a zero-width action that counts digits into the
          ;; OTHER field. It witnesses two things at once -- that the digit edge
          ;; goes where the node says, and that the accumulate commits into slot
          ;; 1 while this commits into slot 0.
          (make-field-action-node 'bump 'increment '(pad) 'acc 'over #f)
          ;; Reached only by the non-digit edge, and only because that edge
          ;; REEXECUTES: the delimiter must still be in hand for this dispatch to
          ;; match it. With mode `advance` the byte is consumed at `acc` and this
          ;; node sees the next one instead -- which is what makes the mode
          ;; observable rather than merely declared.
          (make-byte-dispatch-node 'tail
            (list (make-byte-case (make-exact-byte-matcher 120)
                                  (make-edge 'sawx 'advance) #f))
            (make-edge 'over 'reexecute) #f #f)
          (make-stop-node 'sawx #f)
          (make-error-node 'over 'rejected #f))
    'default-eof #f))

(define tf-pair
  (cons (make-interpreted-machine (verify-machine two-field-acc))
        (emit-and-load two-field-acc 'twofield 'twofield-parser
                       (string-append tmpdir "/generated-twofield.sls"))))

(define (tf-run-on cm str)
  (let ((p (make-parser cm '() #f)))
    (cons (parser-feed! p (str->bytes str) 0 (string-length str)) p)))
(define tf-run tf-run-on)

(harness-group "the accumulate node's four unreached operands"
  (lambda ()
    (harness-case "the machine verifies clean"
      (lambda ()
        ;; First and separately: if this shape is ever made illegal,
        ;; THIS is the check that should fail and say so, rather than the four
        ;; below failing for a reason that reads like an executor defect.
        (let ((v (verify-machine two-field-acc)))
          (check "accepted" (verification-ok? v))
          (check-equal "no diagnostics" (length (verification-diagnostics v)) 0))))
    (harness-case "the accumulate commits into the field it NAMES, not into slot zero"
      (lambda ()
        ;; `n` is slot 1 and `pad` slot 0. A lane that reads or writes slot 0
        ;; accumulates into `pad` -- an 8-bit field, which would also overflow at
        ;; the third hex digit -- so this separates the slot lookup from the
        ;; width lookup as well.
        (let* ((a (cdr (tf-run (car tf-pair) "#1aF")))
               (g (cdr (tf-run (cdr tf-pair) "#1aF"))))
          (check-equal "interpreter n" (parser-field-ref a 'n) #x1aF)
          (check-equal "generated n" (parser-field-ref g 'n) #x1aF)
          ;; And the OTHER field is untouched by the accumulate itself: `pad`
          ;; holds the digit count the action wrote, three, not a partial sum.
          (check-equal "interpreter pad" (parser-field-ref a 'pad) 3)
          (check-equal "generated pad" (parser-field-ref g 'pad) 3))))
    (harness-case "the digit edge goes to the DECLARED target, not back to the node"
      (lambda ()
        ;; `pad` is 3 above only because each accepted digit routed through
        ;; `bump`. A lane that ignored digit-target and self-looped would leave
        ;; `pad` at 0 while `n` still reached 0x1aF -- which is why the count is
        ;; asserted rather than merely the accumulated value.
        (let* ((a (cdr (tf-run (car tf-pair) "#1")))
               (g (cdr (tf-run (cdr tf-pair) "#1"))))
          (check-equal "interpreter one digit, one hop" (parser-field-ref a 'pad) 1)
          (check-equal "generated one digit, one hop" (parser-field-ref g 'pad) 1))))
    (harness-case "the non-digit edge REEXECUTES, so the delimiter is read again"
      (lambda ()
        ;; The normal case for a non-digit edge. `tail` matches only `x`. Reaching `sawx` means `x` was still in hand
        ;; when the fallback edge was taken; under mode `advance` it would have
        ;; been consumed at `acc` and `tail` would have run out of input.
        (let* ((ra (car (tf-run (car tf-pair) "#1aFx")))
               (rg (car (tf-run (cdr tf-pair) "#1aFx"))))
          (check-equal "interpreter stopped at sawx" (parser-result-status ra) 'stopped)
          (check-equal "generated stopped at sawx" (parser-result-status rg) 'stopped)
          ;; The consumed count is the direct evidence: five bytes fed, five
          ;; consumed, which only holds if `x` was consumed by `tail` rather than
          ;; by `acc`.
          (check-equal "interpreter consumed" (parser-result-consumed ra) 5)
          (check-equal "generated consumed" (parser-result-consumed rg) 5))))
    (harness-case "the overflow bound divides by the node's OWN base, at base 16"
      (lambda ()
        ;; `#FFFFF` does not separate a divisor of 16 from a divisor of 10: at
        ;; the fourth digit 0xFFF = 4095 passes both bounds ((65535-15)/16 = 4095
        ;; and /10 = 6552), and at the fifth 0xFFFF = 65535 fails both. A mutant
        ;; dividing by 10 survives it.
        ;;
        ;; The separating value has to land BETWEEN the two bounds, so
        ;; `#1000F` is the case: after four digits n = 0x1000 = 4096, which is
        ;; above 4095 and below 6552. The correct bound refuses the `F` and
        ;; errors with n unchanged; a bound dividing by 10 accepts it and writes
        ;; 4096*16+15 = 65551 -- a value OUTSIDE the u16 the field declares,
        ;; which is the whole point of a checked multiply-add.
        (let* ((rb (car (tf-run (car tf-pair) "#1000F")))
               (b (cdr (tf-run (car tf-pair) "#1000F")))
               (rbg (car (tf-run (cdr tf-pair) "#1000F")))
               (bg (cdr (tf-run (cdr tf-pair) "#1000F"))))
          (check-equal "interpreter refuses the fifth digit" (parser-result-status rb) 'error)
          (check-equal "generated refuses the fifth digit" (parser-result-status rbg) 'error)
          (check-equal "interpreter leaves 0x1000" (parser-field-ref b 'n) #x1000)
          (check-equal "generated leaves 0x1000" (parser-field-ref bg 'n) #x1000))
        ;; The ceiling case as well: four F's fit exactly, the fifth cannot.
        (let* ((ra (car (tf-run (car tf-pair) "#FFFFF")))
               (a (cdr (tf-run (car tf-pair) "#FFFFF")))
               (rg (car (tf-run (cdr tf-pair) "#FFFFF")))
               (g (cdr (tf-run (cdr tf-pair) "#FFFFF"))))
          (check-equal "interpreter reached the u16 ceiling" (parser-field-ref a 'n) #xFFFF)
          (check-equal "generated reached the u16 ceiling" (parser-field-ref g 'n) #xFFFF)
          (check-equal "interpreter errored" (parser-result-status ra) 'error)
          (check-equal "generated errored" (parser-result-status rg) 'error)
          (check-equal "position kind"
                       (parser-error-position-kind (parser-result-error ra)) 'byte)
          (check-equal "the lanes agree on the error"
                       (parser-error-reason (parser-result-error rg))
                       (parser-error-reason (parser-result-error ra))))))))

;; The same two claims again on a machine with NO zero-width node, because the
;; fixture above cannot attribute them. Its evidence for the digit-target hop is
;; a count `bump` writes, and its evidence for the reexecute mode is a consumed
;; count `bump` also affects -- so every mutant that breaks a zero-width action
;; or an increment breaks those cases too, and the accumulate mutants' pins
;; would nest inside mutants that have nothing to do with accumulation. Here the
;; digit target is a STOP node and the delimiter path
;; carries no action at all, so the only machinery either case can blame is the
;; accumulate arm itself.
(define lone-acc
  (make-machine 'lone 'start (list (make-uint-field 'n 16 0 #f)) '() '() drift-errs
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 35)
                                  (make-edge 'acc 'advance) #f))
            (make-edge 'over 'reexecute) #f #f)
          ;; digit-target is `halt`, so ONE digit is taken and the machine stops.
          ;; A lane that self-looped instead would ask for more input.
          (make-integer-accumulate-node 'acc 'n 16 'halt
                                        (make-edge 'tail 'reexecute)
                                        'over #f #f)
          (make-stop-node 'halt #f)
          (make-byte-dispatch-node 'tail
            (list (make-byte-case (make-exact-byte-matcher 120)
                                  (make-edge 'sawx 'advance) #f))
            (make-edge 'over 'reexecute) #f #f)
          (make-stop-node 'sawx #f)
          (make-error-node 'over 'rejected #f))
    'default-eof #f))

(define lone-pair
  (cons (make-interpreted-machine (verify-machine lone-acc))
        (emit-and-load lone-acc 'lone 'lone-parser
                       (string-append tmpdir "/generated-lone.sls"))))

(harness-group "the same two operands, on a machine with no zero-width node"
  (lambda ()
    (harness-case "the machine verifies clean"
      (lambda ()
        (let ((v (verify-machine lone-acc)))
          (check "accepted" (verification-ok? v))
          (check-equal "no diagnostics" (length (verification-diagnostics v)) 0))))
    (harness-case "one digit is taken and the DECLARED digit-target stops the parse"
      (lambda ()
        ;; A self-loop would leave the parser asking for input instead.
        (let ((ra (car (tf-run-on (car lone-pair) "#1")))
              (rg (car (tf-run-on (cdr lone-pair) "#1"))))
          (check-equal "interpreter stopped" (parser-result-status ra) 'stopped)
          (check-equal "generated stopped" (parser-result-status rg) 'stopped))))
    (harness-case "the delimiter is re-read with no action anywhere in the path"
      (lambda ()
        (let* ((ra (car (tf-run-on (car lone-pair) "#x")))
               (rg (car (tf-run-on (cdr lone-pair) "#x"))))
          (check-equal "interpreter consumed both" (parser-result-consumed ra) 2)
          (check-equal "generated consumed both" (parser-result-consumed rg) 2)
          (check-equal "interpreter stopped at sawx" (parser-result-status ra) 'stopped)
          (check-equal "generated stopped at sawx" (parser-result-status rg) 'stopped))))))

(harness-finish)
