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
          (check-equal "a difference fails" (probe-failures p) 1))))

    (harness-case "check-equal reports both values"
      (lambda ()
        (let* ((p (harness-probe (lambda () (check-equal "differ" 1 2))))
               (records (probe-failure-records p))
               (detail (failure-record-detail (car records))))
          (check "the expected value appears" (harness-string-contains? detail "2"))
          (check "the actual value appears" (harness-string-contains? detail "1"))
          (check-equal "the label is kept" (failure-record-what (car records)) "differ"))))

    (harness-case "check-not-equal is the inverse"
      (lambda ()
        (let ((p (harness-probe (lambda () (check-not-equal "differ" 1 2)))))
          (check-equal "different values pass" (probe-failures p) 0))
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
          (check-equal "a matching raise passes" (probe-failures p) 0))
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
          (check-equal "one failed case" (probe-failed-cases p) 1))))

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
                       "after"))))))

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
                       (probe-cleanup-failures p) 1))))))

(harness-group "probe"
  (lambda ()

    (harness-case "a probe leaves the enclosing state untouched"
      (lambda ()
        (let ((before (harness-counters)))
          (harness-probe (lambda () (check "inside" #f) (check "inside" #f)))
          (check-equal "the enclosing counters are unchanged"
                       (harness-counters) before))))

    (harness-case "a probe reports whether its thunk raised"
      (lambda ()
        (check "a raising thunk is reported"
               (probe-raised? (harness-probe (lambda () (raise 'boom)))))
        (check "a normal thunk is not"
               (not (probe-raised? (harness-probe (lambda () 'fine)))))))

    (harness-case "a probe clears the ambient filter"
      (lambda ()
        (harness-set-filter! "no-such-case")
        (let ((p (harness-probe
                  (lambda () (harness-case "inner" (lambda () (check "x" #t)))))))
          (harness-set-filter! #f)
          (check-equal "the inner case was not skipped" (probe-cases p) 1))))))

(harness-group "filtering"
  (lambda ()

    (harness-case "a filter selects by substring and counts the rest as skipped"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-set-filter! "keep")
                    (harness-case "keep-me" (lambda () (check "x" #t)))
                    (harness-case "drop-me" (lambda () (check "y" #t)))))))
          (check-equal "one selected" (probe-cases p) 1)
          (check-equal "one skipped" (probe-skipped p) 1))))))

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
        (check-equal "the launcher declared the mode"
                     (adapter-execution-mode) "source")))

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

    (harness-case "output can be flushed"
      (lambda ()
        (adapter-flush-output)
        (check "flushing does not raise" #t)))

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
