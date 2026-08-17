;;; Self-tests for the byte-machine private test runner.
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only.
;;;
;;; Every deliberate failure below runs inside harness-probe, which gives it a
;;; fresh isolated result state and suppresses its output. Without that, a
;;; self-test that proves failures are recorded would itself fail the run, and
;;; the log would teach readers to ignore FAIL lines.
;;;
;;; Every exported adapter name is referenced here. That is what makes running
;;; this one body on both runtimes a parity proof rather than a coincidence:
;;; a name in one adapter's export list and not the other is a load failure on
;;; that runtime, not a silent gap (spec section 9.1).

;; Construct a bytevector from a length and a list of byte values. Written by
;; hand because the two standards disagree about every convenient constructor:
;; R7RS has (bytevector 97 98 99), R6RS has (u8-list->bytevector '(97 98 99)),
;; and a shared body may name neither.
(define (harness-bytes length bytes)
  (let ((bv (make-bytevector length 0)))
    (let loop ((i 0) (rest bytes))
      (if (null? rest)
          bv
          (begin (bytevector-u8-set! bv i (car rest))
                 (loop (+ i 1) (cdr rest)))))))

(harness-group "assertions"
  (lambda ()

    (harness-case "check counts and passes a true value"
      (lambda ()
        (let ((p (harness-probe (lambda () (check "t" #t)))))
          (check-equal "one check counted" (probe-checks p) 1)
          (check-equal "no failure recorded" (probe-failures p) 0))))

    (harness-case "check records a failure for a false value"
      (lambda ()
        (let ((p (harness-probe (lambda () (check "f" #f)))))
          (check-equal "one check counted" (probe-checks p) 1)
          (check-equal "one failure recorded" (probe-failures p) 1))))

    (harness-case "check-equal compares with equal?"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (check-equal "lists" (list 1 2) (list 1 2))
                    (check-equal "strings" "a" "a")))))
          (check-equal "structural equality passes" (probe-failures p) 0))
        (let ((p (harness-probe (lambda () (check-equal "differ" 1 2)))))
          (check-equal "a difference fails" (probe-failures p) 1)
          (check-equal "still counted as a check" (probe-checks p) 1))))

    (harness-case "check-equal reports both values"
      (lambda ()
        (let* ((p (harness-probe (lambda () (check-equal "differ" 1 2))))
               (records (probe-failure-records p))
               (detail (failure-record-detail (car records))))
          (check "the expected value appears" (harness-string-contains? detail "2"))
          (check "the actual value appears" (harness-string-contains? detail "1"))
          (check-equal "the label is kept" (failure-record-what (car records)) "differ"))))

    ;; The five assertion procedures are documented as returning a boolean,
    ;; and nothing above reads one -- every probe above is inspected only
    ;; through its summary. A check-equal mutated to always return #f (or
    ;; always #t) would still fail (or pass) exactly the right cases and
    ;; leave every assertion above green. This is the one case that actually
    ;; looks at what the call handed back.
    (harness-case "check-equal returns a boolean for pass and fail"
      (lambda ()
        (check "a passing comparison returns #t"
               (check-equal "return true" 1 1))
        (let ((returned 'not-yet-run))
          (harness-probe
           (lambda ()
             (set! returned (check-equal "return false" 1 2))))
          (check-equal "a failing comparison returns #f" returned #f))))

    (harness-case "check-not-equal is the inverse"
      (lambda ()
        (let ((p (harness-probe (lambda () (check-not-equal "differ" 1 2)))))
          (check-equal "different values pass" (probe-failures p) 0)
          (check-equal "counted as a check" (probe-checks p) 1))
        (let ((p (harness-probe (lambda () (check-not-equal "same" 1 1)))))
          (check-equal "equal values fail" (probe-failures p) 1))))

    (harness-case "check-fail always fails and counts as a check"
      (lambda ()
        (let ((p (harness-probe (lambda () (check-fail "unreachable" "why")))))
          (check-equal "counted" (probe-checks p) 1)
          (check-equal "failed" (probe-failures p) 1))))

    (harness-case "check-raises passes only on a matching raise"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (check-raises "raises a symbol"
                                  (lambda (e) (eq? e 'boom))
                                  (lambda () (raise 'boom)))))))
          (check-equal "a matching raise passes" (probe-failures p) 0)
          (check-equal "counted as a check" (probe-checks p) 1))
        (let ((p (harness-probe
                  (lambda ()
                    (check-raises "returns instead"
                                  (lambda (e) #t)
                                  (lambda () 'no-raise))))))
          (check-equal "returning normally fails" (probe-failures p) 1))
        (let ((p (harness-probe
                  (lambda ()
                    (check-raises "wrong object"
                                  (lambda (e) (eq? e 'expected))
                                  (lambda () (raise 'other)))))))
          (check-equal "the wrong raise fails" (probe-failures p) 1))))))

(harness-group "cases"
  (lambda ()

    (harness-case "a raise inside a case is that case's failure"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "raiser" (lambda () (raise 'boom)))
                    (harness-case "later" (lambda () (check "still runs" #t)))))))
          (check-equal "both cases ran" (probe-cases p) 2)
          (check-equal "one case failed" (probe-failed-cases p) 1)
          (check "the suite did not die" (not (probe-raised? p))))))

    (harness-case "a duplicate case id is an error, not a failure"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "same" (lambda () (check "a" #t)))
                    (harness-case "same" (lambda () (check "b" #t)))))))
          (check-equal "the second registration did not run" (probe-cases p) 1)
          (check-equal "recorded as an error" (probe-errors p) 1)
          (check-equal "not recorded as a failure" (probe-failures p) 0))))

    (harness-case "a failing case is counted once however many checks fail"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "two failures"
                      (lambda ()
                        (check "one" #f)
                        (check "two" #f)))))))
          (check-equal "two failures" (probe-failures p) 2)
          (check-equal "one failed case" (probe-failed-cases p) 1)
          ;; "one" and "two" differ only in which ran first: (car records) is
          ;; the same element whether or not harness-probe's `reverse` is
          ;; there unless order is actually checked against it.
          (check-equal "records come back oldest first"
                       (failure-record-what (car (probe-failure-records p)))
                       "one"))))

    (harness-case "groups prefix case ids"
      (lambda ()
        (let* ((p (harness-probe
                   (lambda ()
                     (harness-group "outer"
                       (lambda ()
                         (harness-group "inner"
                           (lambda ()
                             (harness-case "leaf" (lambda () (check "x" #f))))))))))
               (records (probe-failure-records p)))
          (check-equal "dotted from outermost in"
                       (failure-record-id (car records))
                       "outer.inner.leaf"))))

    (harness-case "a group unwinds its name when its body raises"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (guard (e (#t #t))
                      (harness-group "doomed" (lambda () (raise 'boom))))
                    (harness-case "after" (lambda () (check "x" #f)))))))
          (check-equal "the failed group left no prefix behind"
                       (failure-record-id (car (probe-failure-records p)))
                       "after"))))

    ;; A separate decision from the unwinding above, and not implied by it:
    ;; harness-group pops its name off the stack *before* it re-raises, so a
    ;; group that swallowed its body's condition outright would still leave no
    ;; prefix behind and still let "after" register at the top level. The case
    ;; above would pass unchanged -- its guard would simply never fire, which
    ;; nothing there can observe. Escaping is asserted here instead, by
    ;; recording which way harness-group returned rather than by catching the
    ;; raise and hoping the catch ran: a swallowed condition comes back as
    ;; 'returned and the comparison names the defect, where an unguarded (car
    ;; outcome) would only crash on a non-pair.
    (harness-case "a group re-raises its body's condition"
      (lambda ()
        (let ((outcome
               (guard (e (#t (list 'raised e)))
                 (list 'returned
                       (harness-group "doomed" (lambda () (raise 'boom)))))))
          (check-equal "the condition escaped the group"
                       (car outcome) 'raised)
          (check-equal "and it is the original condition, unchanged"
                       (car (cdr outcome)) 'boom))))))

(harness-group "cleanup"
  (lambda ()

    (harness-case "with-cleanup runs cleanup after a normal body"
      (lambda ()
        (let ((ran #f))
          (let ((value (with-cleanup (lambda () 'body)
                                     (lambda () (set! ran #t)))))
            (check-equal "the body's value is returned" value 'body)
            (check "cleanup ran" ran)))))

    (harness-case "with-cleanup runs cleanup after a raise and re-raises"
      (lambda ()
        (let ((ran #f))
          (let ((outcome (guard (e (#t (list 'raised e)))
                           (with-cleanup (lambda () (raise 'boom))
                                         (lambda () (set! ran #t))))))
            (check "cleanup ran" ran)
            (check "the original condition survives"
                   (and (eq? (car outcome) 'raised)
                        (eq? (car (cdr outcome)) 'boom)))))))

    (harness-case "a raising cleanup is recorded separately"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "c"
                      (lambda ()
                        (with-cleanup (lambda () 'body)
                                      (lambda () (raise 'cleanup-boom)))))))))
          (check-equal "counted as a cleanup failure"
                       (probe-cleanup-failures p) 1)
          ;; harness-cleanup-failure-count is a side channel. What actually
          ;; fails the enclosing case -- the FAIL line, the FAIL-CONTEXT line,
          ;; and exit status 1 -- is with-cleanup also calling
          ;; harness-record-failure!, which neither counter proves by itself.
          (check-equal "also recorded as an ordinary failure"
                       (probe-failures p) 1)
          (check-equal "the enclosing case is marked failed"
                       (probe-failed-cases p) 1))))))

(harness-group "probe"
  (lambda ()

    ;; harness-restore-state! puts back thirteen fields; harness-counters
    ;; (used below for the bootstrap's own benefit) only observes three of
    ;; them. Comparing the full captured state closes that gap. The probed
    ;; thunk deliberately fails three cases, skips three cases, raises
    ;; inside two cleanups, and re-registers an already-used id three more
    ;; times -- an error, not a failure, per "a duplicate case id is an
    ;; error, not a failure" above -- and the ambient filter is set to a
    ;; real value beforehand, so that every field harness-clear-state!
    ;; would otherwise reset to the same default it already has ends up
    ;; somewhere else instead. Three-or-more is deliberate, not decorative:
    ;; every other probe in this file registers at most two inner cases or
    ;; one duplicate id, so a leaked, unrestored count from any of them
    ;; cannot coincidentally match this probe's own total the way a
    ;; smaller, more "natural" count could. The duplicates reuse
    ;; "inside-failing-1" instead of a fresh id so that only
    ;; harness-error-count moves: the duplicate branch of harness-case
    ;; never runs the thunk it is given and never touches harness-case-ids,
    ;; so case-count and check-count are exactly as they were already.
    (harness-case "a probe leaves the enclosing state untouched"
      (lambda ()
        (harness-set-filter! "ambient-marker")
        (with-cleanup
         (lambda ()
           (let ((before (harness-capture-state)))
             (harness-probe
              (lambda ()
                (harness-case "inside-failing-1" (lambda () (check "a" #f)))
                (harness-case "inside-failing-2" (lambda () (check "b" #f)))
                (harness-case "inside-failing-3" (lambda () (check "c" #f)))
                (harness-case "inside-passing" (lambda () (check "d" #t)))
                (harness-set-filter! "keep-only")
                (harness-case "keep-only" (lambda () (check "e" #t)))
                (harness-case "dropped-1" (lambda () (check "f" #t)))
                (harness-case "dropped-2" (lambda () (check "g" #t)))
                (harness-case "dropped-3" (lambda () (check "h" #t)))
                (harness-case "inside-failing-1" (lambda () (check "unreachable" #t)))
                (harness-case "inside-failing-1" (lambda () (check "unreachable" #t)))
                (harness-case "inside-failing-1" (lambda () (check "unreachable" #t)))
                (with-cleanup (lambda () 'body) (lambda () (raise 'cleanup-boom-1)))
                (with-cleanup (lambda () 'body) (lambda () (raise 'cleanup-boom-2)))))
             (check-equal "the enclosing state is unchanged"
                          (harness-capture-state) before)))
         (lambda () (harness-set-filter! #f)))))

    (harness-case "a probe reports whether its thunk raised"
      (lambda ()
        (check "a raising thunk is reported"
               (probe-raised? (harness-probe (lambda () (raise 'boom)))))
        (check "a normal thunk is not"
               (not (probe-raised? (harness-probe (lambda () 'fine)))))))

    ;; Unprotected, this would be exactly the silent-under-run risk this suite
    ;; exists to catch: if anything between setting the filter and resetting
    ;; it raised, "no-such-case" would stay the ambient filter for the rest of
    ;; the run, silently skipping every later case while the run still exited
    ;; 0. Restoration of the ambient filter across a probe boundary is
    ;; asserted separately, by "a probe leaves the enclosing state untouched";
    ;; this reset is a different concern -- not leaking this case's own
    ;; fixture filter into the rest of the suite -- so it stays, but guarded.
    (harness-case "a probe clears the ambient filter"
      (lambda ()
        (harness-set-filter! "no-such-case")
        (with-cleanup
         (lambda ()
           (let ((p (harness-probe
                     (lambda () (harness-case "inner" (lambda () (check "x" #t)))))))
             (check-equal "the inner case was not skipped" (probe-cases p) 1)))
         (lambda () (harness-set-filter! #f)))))))

(harness-group "filtering"
  (lambda ()

    (harness-case "a filter selects by substring and counts the rest as skipped"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-set-filter! "keep")
                    (harness-case "keep-me" (lambda () (check "x" #t)))
                    (harness-case "drop-me" (lambda () (check "y" #t)))
                    ;; A filtered-out case still reserves its id before the
                    ;; selection check runs, so registering "drop-me" again is
                    ;; a harness error even though the first registration
                    ;; never ran its body.
                    (harness-case "drop-me" (lambda () (check "z" #t)))))))
          (check-equal "one selected" (probe-cases p) 1)
          (check-equal "one skipped" (probe-skipped p) 1)
          (check-equal "a filtered-out duplicate is still an error"
                       (probe-errors p) 1))))

    ;; harness-begin's BYTE_MACHINE_TEST_FILTER handling is exercised
    ;; end-to-end by the empty-selection lane, but only for a non-empty value.
    ;; The empty-string branch has no observable effect on selection to check
    ;; instead -- harness-string-contains? treats an empty needle as matching
    ;; every id, so an empty filter and a normalised-away one select
    ;; identically either way -- so the normalisation rule is checked directly
    ;; here, on the pure function, rather than through a selection outcome.
    (harness-case "the environment filter is normalised"
      (lambda ()
        (check-equal "an empty string means no filter"
                     (harness-normalize-filter "") #f)
        (check-equal "an absent variable means no filter"
                     (harness-normalize-filter #f) #f)
        (check-equal "a real value passes through unchanged"
                     (harness-normalize-filter "keep") "keep")))))

(harness-group "adapter"
  (lambda ()

    (harness-case "the adapter reports this runtime"
      (lambda ()
        (check "the runtime names itself"
               (or (string=? (adapter-runtime-name) "chez")
                   (string=? (adapter-runtime-name) "gambit")))
        (check "the version is bare and non-empty"
               (and (> (string-length (adapter-runtime-version)) 0)
                    (not (harness-string-contains? (adapter-runtime-version) "v"))))
        (check "the machine type is reported"
               (> (string-length (adapter-machine-type)) 0))
        (check-not-equal "the os is identified" (adapter-os) "unknown")
        (check-not-equal "the architecture is identified"
                         (adapter-architecture) "unknown")
        (check-equal "the mode is declared by the lane registration"
                     (adapter-execution-mode) "source")))

    ;; adapter-exit ends the process, so no assertion may call it. Naming it is
    ;; still load-bearing: the parity argument in spec section 9.1 rests on this
    ;; body referencing every adapter name, and until this case existed
    ;; adapter-exit was the one name it missed -- its only other uses are inside
    ;; harness-runner.scm, which `include` splices into the library, so they
    ;; resolve whatever the export list says. Dropping it from one adapter left
    ;; this body loading and passing on that runtime.
    (harness-case "the adapter can end the process"
      (lambda ()
        (check "adapter-exit is reachable" (procedure? adapter-exit))))

    (harness-case "the adapter reaches the process environment"
      (lambda ()
        (check "the registration's test name is visible"
               (adapter-environment-variable "BYTE_MACHINE_TEST_NAME"))
        (check "an unset variable reads as false"
               (not (adapter-environment-variable "BYTE_MACHINE_NOT_SET_ANYWHERE")))))

    (harness-case "the adapter renders values and conditions"
      (lambda ()
        (check-equal "a list writes readably"
                     (adapter-value->string (list 1 2)) "(1 2)")
        (check-equal "a string writes with its quotes"
                     (adapter-value->string "a") "\"a\"")
        (let ((text (adapter-describe-condition (guard (e (#t e)) (car '())))))
          (check "a condition describes non-empty" (> (string-length text) 0))
          ;; Single-line, because it is appended to a one-line FAIL record.
          (check "on one line" (not (harness-string-contains? text "\n"))))))

    (harness-case "the shared subset's arithmetic is reachable"
      (lambda ()
        (check-equal "quotient" (quotient 7 2) 3)
        (check-equal "remainder" (remainder 7 2) 1)
        (check-equal "modulo" (modulo -7 2) 1)))

    ;; A literal #t can never fail, so the old body only "passed" because a
    ;; raise would have unwound past the check entirely, not because the
    ;; check evaluated anything. Wrapping the flush in a probe makes the
    ;; assertion depend on what adapter-flush-output actually does.
    (harness-case "output can be flushed"
      (lambda ()
        (let ((p (harness-probe (lambda () (adapter-flush-output)))))
          (check "flushing does not raise" (not (probe-raised? p))))))

    (harness-case "the status vocabulary is what the build expects"
      (lambda ()
        (check-equal "pass" harness-status-pass 0)
        (check-equal "failed" harness-status-failed 1)
        (check-equal "harness error" harness-status-harness-error 2)
        (check-equal "provenance, reserved" harness-status-provenance 3)))

    (harness-case "exit status follows error over failure"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "d" (lambda () (check "x" #f)))
                    (harness-case "d" (lambda () (check "y" #t)))))))
          (check-equal "a failure was recorded" (probe-failures p) 1)
          (check-equal "an error was recorded" (probe-errors p) 1))
        ;; The precedence itself, read from the live accessor rather than
        ;; inferred: a harness error outranks a failure because a suite that
        ;; mis-registered cannot be trusted about what it did run.
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "e" (lambda () (check "x" #f)))
                    (check-equal "failure alone yields 1" (harness-exit-status) 1)
                    (harness-case "f" (lambda () (check "y" #t)))
                    (harness-case "f" (lambda () (check "z" #t)))
                    (check-equal "an error outranks it" (harness-exit-status) 2)))))
          (check-equal "the inner assertions held" (probe-failures p) 1))))))

(harness-group "empty selection"
  (lambda ()

    (harness-case "an empty selection is diagnosed from the counts"
      (lambda ()
        (check "a run that executed cases is fine"
               (not (harness-empty-selection-diagnosis 3 0)))
        ;; case-count=1 is exactly where (> case-count 0) flips from #f to
        ;; #t; 3 sits well clear of that boundary and cannot tell the real
        ;; predicate apart from a mutant such as (> case-count 1), which
        ;; agrees with it everywhere except at 1.
        (check "a single case is also fine, at the case-count boundary"
               (not (harness-empty-selection-diagnosis 1 0)))
        ;; (string? ...) is satisfied by any diagnosis text, including the
        ;; filter-skipped wording a mutant would produce here if
        ;; (> skipped-count 0) were loosened to (>= skipped-count 0) --
        ;; skipped-count=0 is that predicate's own boundary. Pin the exact
        ;; wording so that mutant is forced to disagree.
        (check-equal "no cases at all says exactly that"
                     (harness-empty-selection-diagnosis 0 0)
                     "the suite registered no cases")
        (check "a fully filtered run says the filter did it"
               (harness-string-contains?
                (harness-empty-selection-diagnosis 0 4) "filter"))
        (check "and says how many it skipped"
               (harness-string-contains?
                (harness-empty-selection-diagnosis 0 4) "4"))
        ;; The two empty states must not report the same thing: one is a typo in
        ;; the invocation, the other a body that failed to load.
        (check-not-equal "the two empty states read differently"
                         (harness-empty-selection-diagnosis 0 0)
                         (harness-empty-selection-diagnosis 0 4))))))

;; --- the content fingerprint ------------------------------------------------
;;
;; Every value below was measured on Chez 10.4.1 and Gambit 4.9.8 on
;; 2026-08-17 and was identical on both. They are literals rather than
;; recomputations because a test that recomputes the thing under test with the
;; thing under test asserts only that it is deterministic.

(harness-group "fingerprint"
  (lambda ()

    (harness-case "an empty bytevector folds to the seed"
      (lambda ()
        (check-equal "empty"
                     (harness-fingerprint->string
                      (harness-fingerprint-bytevector (harness-bytes 0 '())))
                     "3435eab979e3e0")))

    (harness-case "three ASCII bytes"
      (lambda ()
        (check-equal "abc"
                     (harness-fingerprint->string
                      (harness-fingerprint-bytevector (harness-bytes 3 '(97 98 99))))
                     "60b8174578c282d")))

    ;; The +1 on each byte exists for exactly this: without it a leading NUL is
    ;; absorbed and these three values collapse into one.
    (harness-case "leading zero bytes are significant"
      (lambda ()
        (let ((abc (harness-fingerprint->string
                    (harness-fingerprint-bytevector (harness-bytes 3 '(97 98 99)))))
              (one (harness-fingerprint->string
                    (harness-fingerprint-bytevector (harness-bytes 4 '(0 97 98 99)))))
              (two (harness-fingerprint->string
                    (harness-fingerprint-bytevector
                     (harness-bytes 5 '(0 0 97 98 99))))))
          (check-equal "one leading NUL" one "bac4261bdc123")
          (check-equal "two leading NULs" two "1b3297b7cc8f592c")
          (check-not-equal "one NUL differs from none" one abc)
          (check-not-equal "two NULs differ from one" two one))))

    (harness-case "combining is order sensitive"
      (lambda ()
        (check-equal "(1 2)"
                     (harness-fingerprint->string (harness-fingerprint-combine '(1 2)))
                     "3cabbf7defc450d")
        (check-equal "(2 1)"
                     (harness-fingerprint->string (harness-fingerprint-combine '(2 1)))
                     "3cabbf7df0b874f")))

    ;; Chez renders FF where Gambit renders ff for (number->string 255 16), so
    ;; the rendering cannot go through a radix conversion. This case is what
    ;; notices if someone ever changes it back.
    (harness-case "hex digits are lowercase on every runtime"
      (lambda ()
        (check-equal "255" (harness-fingerprint->string 255) "ff")
        (check-equal "3735928559" (harness-fingerprint->string 3735928559) "deadbeef")
        (check-equal "zero" (harness-fingerprint->string 0) "0")))))
