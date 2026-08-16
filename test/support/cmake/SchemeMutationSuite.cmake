# Proof that the Scheme harness's self-tests are not vacuous.
#
# The harness is the instrument every later milestone is measured with. If
# `check-equal` silently always returned true, the whole project would go green
# and stay green, and no test written with `check-equal` could notice. So each
# decision in the runner is broken in turn on a staged copy, and the self-tests
# must fail.
#
# EIGHT PASSES, BECAUSE EIGHT DIFFERENT WITNESSES ARE NEEDED
#
# Pass 1 runs the Chez self-tests lane against the shared runner body. That body
# is identical text on both runtimes, so verifying it on a second runtime would
# re-prove the same mutation at double the cost.
#
# Pass 2 runs the Gambit self-tests lane, for the one thing that is per-runtime
# by definition: an adapter's export list. A Chez lane cannot notice a name
# missing from the Gambit library.
#
# Pass 3 runs the Chez empty-selection lane through the exact-status helper, for
# the one decision in the runner that no in-process assertion can reach --
# harness-begin reading BYTE_MACHINE_TEST_FILTER out of the environment. A suite
# cannot set its own environment from inside the portable subset, and the
# harness exports no reader for the filter that read produces, so the only
# witness is a whole process that was supposed to select nothing and exit 2.
#
# Pass 4 runs the Chez bootstrap lane, for the defect that disarms the
# self-tests as it commits them: a failure counter that stops counting. Every
# assertion in every suite reports through the counter, so with it broken a
# failing suite prints its FAIL lines and still exits 0. The bootstrap counts
# its own failures with raw conditionals and exits by hand, which is exactly why
# it exists and why it is the only lane whose verdict survives.
#
# Passes 5 to 7 run the Chez launcher's three refusals, one per pass, each
# through the exact-status helper. A refusal cannot be witnessed by a lane that
# is set up correctly, because a correctly set-up lane never reaches one: each
# needs its own deliberately wrong command line, and a verify command is fixed
# for the whole pass.
#
# Pass 8 is the launcher's `compile-imported-libraries` call, and it is the one
# mutation in this file that no single process can catch. See its recorded
# reason.
#
# WHAT THIS SUITE NEEDS FROM ITS ENVIRONMENT
#
# The self-tests assert that the lane declared its execution mode and that the
# registration's test name is visible, so BYTE_MACHINE_EXECUTION_MODE=source and
# BYTE_MACHINE_TEST_NAME must be set in this process; CTest supplies both. Run
# by hand without them, the baseline fails before any mutation is tried -- which
# is the designed behaviour, not a bug: an unverifiable baseline makes every
# mutation look caught.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")

get_filename_component(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(WORK_DIR "$ENV{BYTE_MACHINE_TEST_TMPDIR}")
else()
  set(WORK_DIR "${SOURCE_ROOT}/build/scheme-mutation")
endif()
set(STAGE_DIR "${WORK_DIR}/stage")

# The object guard the Chez launcher requires. It lives outside the stage
# because the stage is removed and rebuilt on every run, and the launcher
# refuses to start if the guard is missing.
set(GUARD_DIR "${WORK_DIR}/guard")
file(REMOVE_RECURSE "${GUARD_DIR}")
file(MAKE_DIRECTORY "${GUARD_DIR}")

# Two more guards, for the two refusals that need a guard directory in a state
# the build never otherwise produces. The absent one is named and deliberately
# not created.
set(DIRTY_GUARD_DIR "${WORK_DIR}/guard-dirty")
file(REMOVE_RECURSE "${DIRTY_GUARD_DIR}")
file(MAKE_DIRECTORY "${DIRTY_GUARD_DIR}")
file(WRITE "${DIRTY_GUARD_DIR}/stray-object.so"
  "Not a compiled library. Its only job is to stop this directory being empty.\n")

set(ABSENT_GUARD_DIR "${WORK_DIR}/guard-absent")
file(REMOVE_RECURSE "${ABSENT_GUARD_DIR}")

if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
  message(FATAL_ERROR
    "byte-machine-mutation: BYTE_MACHINE_CHEZ_EXECUTABLE was not passed in. "
    "This suite runs a real execution lane, so it cannot be verified under the "
    "no-scheme preset; the registration must forward the discovered path.")
endif()

set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(RUNNER test/support/harness/shared/harness-runner.scm)
set(CHEZ_ADAPTER test/support/harness/chez/byte-machine/test/harness.sls)
set(LAUNCHER test/support/launchers/chez-source.ss)

# --- Assertions ------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check passes whatever it is given"
  FIND [[(define (check what value)
  (harness-count-check!)
  (if value]]
  REPLACE [[(define (check what value)
  (harness-count-check!)
  (if #t]])

# Narrower than the mutation above, and not covered by it: `check` still returns
# #f and still counts the check, but the failure is never recorded. A suite
# built on this would print no FAIL line, count no failure, and exit 0 while
# every assertion in it "failed".
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a false check counts but records no failure"
  FIND [[      (begin (harness-record-failure! what "expected a true value") #f)))]]
  REPLACE [[      #f))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-equal compares identity instead of structure"
  FIND [[  (if (equal? actual expected)]]
  REPLACE [[  (if (eq? actual expected)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-not-equal is no longer the inverse"
  FIND [[  (if (equal? actual unexpected)]]
  REPLACE [[  (if (not (equal? actual unexpected))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-fail records nothing"
  FIND [[  (harness-record-failure! what detail)
  #f)]]
  REPLACE [[  #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-raises accepts a thunk that returned normally"
  FIND [[      ((eq? (car outcome) 'returned)]]
  REPLACE [[      ((eq? (car outcome) 'never-happens)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a failure never marks its case as failed"
  FIND [[  (set! harness-current-case-failed #t)]]
  REPLACE [[  (set! harness-current-case-failed #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a duplicate case id is silently accepted, making one registration unreachable"
  FIND [[      ((harness-member? id harness-case-ids)]]
  REPLACE [[      (#f]])

# harness-record-error! takes one argument where harness-record-failure! takes
# two, so the "case raised" label goes with the call it belongs to: keeping it
# would mutate the arity rather than the classification, and the arity violation
# is caught by a different assertion than the one this line claims to exercise.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a raise inside a case is recorded as an error rather than that case's failure"
  FIND [[                   (harness-record-failure!
                    "case raised"
                    (adapter-describe-condition (car (cdr outcome))))]]
  REPLACE [[                   (harness-record-error!
                    (adapter-describe-condition (car (cdr outcome))))]])

# harness-group and with-cleanup re-raise through identical text, so each of the
# two mutations below anchors on the line above the `if` -- the group-stack pop
# for one, the tail of the cleanup report for the other. They were one SITES 2
# mutation until a review showed what that concealed: a multi-site mutation is
# "caught" as soon as any one site is caught, and only the cleanup site was.
# harness-group pops its name off the stack *before* it re-raises, so deleting
# the re-raise still leaves every prefix correct; the group merely returns the
# condition instead of throwing it, and the one self-test that raises inside a
# group asserted only that no prefix was left behind. Split, each re-raise has
# to be witnessed on its own, and the group one stayed uncaught until
# "a group re-raises its body's condition" was added to the self-tests.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a group swallows its body's condition instead of re-raising it"
  FIND [[    (set! harness-group-stack (cdr harness-group-stack))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[    (set! harness-group-stack (cdr harness-group-stack))
    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: with-cleanup swallows its body's condition instead of re-raising it"
  FIND [[             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: cleanup never runs"
  FIND [[    (let ((cleanup-outcome (guard (e (#t (list 'raised e)))
                             (list 'value (cleanup)))))]]
  REPLACE [[    (let ((cleanup-outcome (list 'value #f)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a failure outranks a harness error in the exit status"
  FIND [[  (cond ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)]]
  REPLACE [[  (cond ((> harness-failure-count 0) harness-status-failed)
        ((> harness-error-count 0) harness-status-harness-error)]])

# --- Probes ----------------------------------------------------------------

# The FIND consumes the whole line, its trailing newline included, so the
# replacement carries a newline of its own; without one it would swallow the
# following line as well and delete more than it names. An inert comment rather
# than an empty replacement, because an explicitly empty single-value argument
# is left undefined by cmake_parse_arguments at the 3.26 floor this project
# declares (CMP0174 is 3.31+), and REPLACE is required.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a probe does not restore the state it displaced"
  FIND [[        (harness-restore-state! saved)
]]
  REPLACE [[        ;; deleted
]])

# Anchored on the preceding line so the pattern is pinned to the tail of
# harness-clear-state! rather than to any future assignment of the same
# variable: harness-set-filter! and harness-begin both assign harness-filter,
# and a bare pattern would start matching one of them after an innocuous edit.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a probe inherits the ambient filter and skips its own cases"
  FIND [[  (set! harness-failures '())
  (set! harness-filter #f))]]
  REPLACE [[  (set! harness-failures '()))]])

# --- Empty selection -------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: an empty selection is not diagnosed"
  FIND [[    ((> case-count 0) #f)]]
  REPLACE [[    ((> case-count -1) #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a filtered-out run is diagnosed as having registered nothing"
  FIND [[    ((> skipped-count 0)]]
  REPLACE [[    (#f]])

# --- Output ----------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: probe output suppression is removed"
  FIND [[(define (harness-quiet?) (> harness-probe-depth 0))]]
  REPLACE [[(define (harness-quiet?) #f)]]
  EXPECT_SURVIVES
    "suppression changes only what is printed, never a counter or a status, so no assertion can observe it from inside the process; it is covered by the manual check in the implementation plan's Task 5 step 9, and its real cost -- a log that teaches readers to ignore FAIL lines -- is not machine-checkable")

# The other two print-only decisions, and the same argument. The harness has no
# portable way to read back what it printed -- string ports are outside the
# common R6RS/R7RS subset -- and this suite judges a mutation by the verify
# command's exit status, so an output difference is invisible to it whatever
# lane it runs. byte-machine.harness.verbose.chez.source closes the half that
# can be closed: it runs a real body with the variable set, so the path is
# executed and a break that raises is caught. What no layer checks is that the
# line was printed. Spec section 5.3 records the manual check that does.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: BYTE_MACHINE_TEST_VERBOSE is never read"
  FIND [[    (set! harness-verbose (if (and v (not (string=? v ""))) #t #f)))]]
  REPLACE [[    (set! harness-verbose #f))]]
  EXPECT_SURVIVES
    "with verbose forced off, a run prints one line per passing case fewer and reports the identical counters, cases, failures and status; nothing this suite can run tells the two apart. byte-machine.harness.verbose.chez.source proves the read happens and does not raise; that the value read is honoured is covered by the manual check recorded in spec section 5.3 -- either self-tests lane with BYTE_MACHINE_TEST_VERBOSE=1 prints one pass line per case and none without it")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a passing case is never announced under verbose"
  FIND [[                 (if harness-verbose
                     (harness-say (string-append "byte-machine-harness: pass " id))))]]
  REPLACE [[                 #f)]]
  EXPECT_SURVIVES
    "the pass line is the only thing this branch produces, and a line that is not printed changes no counter and no status; byte-machine.harness.verbose.chez.source still proves the branch is reached and does not raise, but only a reader of the log can see the line itself, which is the manual check recorded in spec section 5.3")

# --- The Chez launcher's source path ---------------------------------------
#
# Both entries are load-bearing and neither is visible in a passing run. The
# shared directory is how the library resolves the runner body it includes by
# bare filename; the program's own directory is how a wrapper resolves the body
# beside it. Dropping either leaves the self-tests lane unable to load at all,
# which is why these two belong to this pass rather than to one of the
# exact-status passes below, where a refusal is the passing outcome.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC harness-self-tests.chez.sps
  LABEL "launcher: the shared body directory is off the source path"
  FIND [[(source-directories (list shared-dir (path-directory program)))]]
  REPLACE [[(source-directories (list (path-directory program)))]])

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC harness-self-tests.chez.sps
  LABEL "launcher: the program's own directory is off the source path"
  FIND [[(source-directories (list shared-dir (path-directory program)))]]
  REPLACE [[(source-directories (list shared-dir))]])

# --- The Chez adapter's export list ----------------------------------------

byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.chez.sps
  LABEL "chez adapter: an exported adapter name is dropped"
  FIND [[    adapter-os adapter-architecture adapter-execution-mode]]
  REPLACE [[    adapter-architecture adapter-execution-mode]])

# Not every export is load-bearing, and pretending otherwise would be the more
# comfortable lie. harness-summary, harness-empty-selection-error, and
# harness-failure-context are used only from inside harness-runner.scm, which is
# spliced into each adapter's library body by `include`; an internal reference
# resolves against the body, never through the export list. Dropping any of the
# three therefore changes nothing any lane can observe -- the parity argument for
# these names rests on the two export lists being read side by side, not on this
# suite. Recorded here so the blind spot is asserted rather than remembered, and
# so the day one of them acquires a caller outside the library, this line fails.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.chez.sps
  LABEL "chez adapter: an export used only inside the spliced body is dropped"
  FIND [[    harness-begin harness-finish harness-summary harness-exit-status]]
  REPLACE [[    harness-begin harness-finish harness-exit-status]]
  EXPECT_SURVIVES
    "harness-summary, harness-empty-selection-error, and harness-failure-context are referenced only from harness-runner.scm, which `include` splices into the library body, so those references resolve inside the library whatever the export list says; no lane imports the three, so no lane can notice one going missing")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Second pass: the Gambit adapter's export list -------------------------
#
# Per-runtime by definition. One mutation, one process; the runner mutations
# above are not repeated.

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  byte_machine_mutation_reset()

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit"
    "-f"
    "${STAGE_DIR}/test/support/harness/self/harness-self-tests.gambit.scm")

  byte_machine_mutation(
    FILE test/support/harness/gambit/byte-machine/test/harness.sld
    SPEC harness-self-tests.gambit.scm
    LABEL "gambit adapter: an exported adapter name is dropped"
    FIND [[    adapter-os adapter-architecture adapter-execution-mode]]
    REPLACE [[    adapter-architecture adapter-execution-mode]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
else()
  message(STATUS
    "byte-machine-mutation: no Gambit was passed in, so the Gambit adapter's "
    "export list is not covered by this run.")
endif()

# --- Third pass: harness-begin's read of the environment filter ------------
#
# The self-tests cannot witness this one. They check the normalisation rule
# directly, on the pure function, but the read itself only matters to a process
# whose ambient filter came from outside it -- and a suite cannot set its own
# environment from inside the portable subset, nor read back the filter the
# runner stored. The empty-selection lane is that process: it registers one case
# its filter cannot select and must exit 2. Break the read and the case runs, the
# suite exits 0, and the exact-status helper says so.
#
# The helper is what makes exit 2 the passing outcome here, which the mutation
# runner requires: it judges "caught" as a nonzero result from the verify
# command, so the verify command must be one that exits 0 when the lane is
# healthy.

byte_machine_mutation_reset()

string(JOIN "|" EMPTY_SELECTION_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-empty-selection.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" -E env
  "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name"
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${EMPTY_SELECTION_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-empty-selection.chez.sps
  LABEL "runner: harness-begin ignores BYTE_MACHINE_TEST_FILTER"
  FIND [[  (set! harness-filter
        (harness-normalize-filter
         (adapter-environment-variable "BYTE_MACHINE_TEST_FILTER")))]]
  REPLACE [[  (set! harness-filter #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Fourth pass: the failure counter itself -------------------------------
#
# Declared under the self-tests lane first, and observed UNCAUGHT there: with
# harness-record-failure! no longer counting, a self-test that fails prints its
# FAIL line, marks its case failed, and leaves the exit status at 0. The
# mutation disarms the mechanism every assertion reports through as it commits
# the defect, so no suite written with `check` can witness it -- which is
# precisely the argument the bootstrap lane exists to answer. It judges the
# primitives with raw conditionals, counts its own failures, and exits by hand.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-bootstrap.chez.sps
  LABEL "runner: a recorded failure is never counted, so a failing suite exits 0"
  FIND [[  (set! harness-failure-count (+ harness-failure-count 1))]]
  REPLACE [[  (set! harness-failure-count harness-failure-count)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 5 to 7: the launcher's three refusals --------------------------
#
# The launcher decides whether a lane runs at all, and its object guard is the
# sole mechanism that makes `mode=source` an honest claim. None of its three
# refusals can be reached by a lane that was set up correctly, so each gets a
# deliberately wrong command line of its own, run through the exact-status
# helper so that exit 2 -- the refusal -- is what a healthy launcher scores.
#
# SPEC names the registered lane rather than a body basename, because the
# witness is a whole invocation and not a program: with the argument count
# wrong there is no program at all, and for the other two "passing" means the
# named body never ran.

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_USAGE_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${GUARD_DIR}")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_USAGE_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-usage.chez.source
  LABEL "launcher: the argument count is not checked"
  FIND [[(if (not (= (length args) 4))]]
  REPLACE [[(if #f]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_ABSENT_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${ABSENT_GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_ABSENT_GUARD_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-absent-guard.chez.source
  LABEL "launcher: a guard directory that does not exist is assumed rather than checked"
  FIND [[(if (not (file-directory? object-guard-dir))]]
  REPLACE [[(if #f]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_DIRTY_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${DIRTY_GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_DIRTY_GUARD_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

# The one that matters most: a guard directory that has acquired a file is no
# longer a guard, and the lane would go on reporting mode=source while loading
# whatever was put there.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-dirty-guard.chez.source
  LABEL "launcher: a guard directory with a file in it is accepted as a guard"
  FIND [[(if (not (null? (directory-list object-guard-dir)))]]
  REPLACE [[(if #f]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Eighth pass: a source lane that compiles what it imports --------------
#
# Its own guard directory, because this is the one mutation here whose effect is
# to write into one.

byte_machine_mutation_reset()

set(COMPILE_GUARD_DIR "${WORK_DIR}/guard-compile")
file(REMOVE_RECURSE "${COMPILE_GUARD_DIR}")
file(MAKE_DIRECTORY "${COMPILE_GUARD_DIR}")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${COMPILE_GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.bootstrap.chez.source
  LABEL "launcher: a source lane is allowed to compile what it imports"
  FIND [[(compile-imported-libraries #f)]]
  REPLACE [[(compile-imported-libraries #t)]]
  EXPECT_SURVIVES
    "deleting the call is provably unobservable -- Chez's own default for compile-imported-libraries is already #f -- so the only mutation with an effect is turning it on, and its entire effect is a file: Chez writes byte-machine/test/harness.so into the object half of the library-directories pair, which is the guard, and it does so after the launcher has already asserted the guard was empty. No single process can see it. The registered lanes can, and do: with compilation on, the first Chez lane to run pollutes the shared object guard and three of the harness preset's tests fail. This suite runs one process per mutation, so what it can prove about this line is only that the line is still there")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

message(STATUS "byte-machine-spec: scheme mutation suite complete")
