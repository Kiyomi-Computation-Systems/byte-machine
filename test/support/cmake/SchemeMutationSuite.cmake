# Proof that the Scheme harness's self-tests are not vacuous.
#
# The harness is the instrument every later milestone is measured with. If
# `check-equal` silently always returned true, the whole project would go green
# and stay green, and no test written with `check-equal` could notice. So each
# decision in the runner is broken in turn on a staged copy, and the self-tests
# must fail.
#
# TWENTY-NINE PASSES, BECAUSE TWENTY-NINE DIFFERENT WITNESSES ARE NEEDED
#
# EXPECTED_PASSES and EXPECTED_MUTATIONS are declared below; checked against
# byte_machine_mutation_totals' accumulated count once every pass below has
# run: that check is what a whole-branch review found nothing else could do --
# deleting the three matrix passes (21 to 23 in the numbering of the tree
# where this happened; today's passes 19 to 21) by hand left this file's own
# suite reporting 37/37 elsewhere, with the mutation count silently dropping
# from 56 to 53 and nothing anywhere noticing.
#
# Pass 1 runs the Chez self-tests lane against the shared runner body.
#
# Pass 2 runs the Chez empty-selection lane through the exact-status helper, for
# the one decision in the runner that no in-process assertion can reach --
# harness-begin reading BYTE_MACHINE_TEST_FILTER out of the environment. A suite
# cannot set its own environment from inside the portable subset, and the
# harness exports no reader for the filter that read produces, so the only
# witness is a whole process that was supposed to select nothing and exit 2.
#
# Pass 3 runs the Chez bootstrap lane, for the defect that disarms the
# self-tests as it commits them: a failure counter that stops counting. Every
# assertion in every suite reports through the counter, so with it broken a
# failing suite prints its FAIL lines and still exits 0. The bootstrap counts
# its own failures with raw conditionals and exits by hand, which is exactly why
# it exists and why it is the only lane whose verdict survives.
#
# Passes 4 to 5 run the Chez launcher's two guard-directory refusals, one per
# pass, each through the exact-status helper. A refusal cannot be witnessed by a
# lane that is set up correctly, because a correctly set-up lane never reaches
# one: each needs its own deliberately wrong command line, and a verify command
# is fixed for the whole pass.
#
# Pass 6 is the launcher's `compile-imported-libraries` call, and it is the one
# mutation in this file that no single process can catch. See its recorded
# reason.
#
# Pass 7 is the library-directories pairing, the mechanism that makes
# `mode=source` an honest claim. No library root in this tree has a compiled
# object in it, so unpairing the root from the guard changes nothing anywhere
# else; the pass therefore builds a root that does have one, and runs the
# self-tests lane against it.
#
# Pass 8 is the placeholder body's own decisions -- tag, length, vector-ness,
# symbol-vs-fresh-allocation identity.
#
# Passes 9 to 18 are the launcher's parse decisions: an unknown flag, a flag
# with no value, a single-valued flag repeated, a required flag unchecked in
# general, one entry dropped from each of required-flags' four members, and one
# entry dropped from each of single-valued-flags' two members. Each gets its
# own pass because each needs its own deliberately wrong invocation and a
# verify command fixed for the whole pass, the same constraint passes 4 to 5
# already established -- generalised here from two decisions to ten.
#
# Passes 19 to 21 are the working-directory matrix: one mutation -- the
# launcher resolving shared bodies against the working directory instead of its
# declared source directories -- run from three different launch directories.
# One mutation needs three passes because what it asserts is that the launch
# directory does not matter, a claim no single fixed launch directory can make.
# Two of the three fail as expected (nothing to include; the wrong answer, on
# content); the third -- launched from a directory holding a faithful copy of
# every body the lane includes -- passes, and is declared EXPECT_SURVIVES with
# its reason recorded. That survivor is deliberate: it is what turns "the
# identical lane is the vacuous working-directory test someone writes by
# default" from a claim this file's comments make into something the suite
# itself demonstrates on every run, and it is what makes the decoy lane's
# failure attributable to content rather than to the mere presence of a
# same-named file.
#
# Pass 22 is the consumer body's three decisions. All three are now caught by a
# failed comparison. The first used to be caught by an induced raise instead
# -- weaker, and weighed and accepted -- before a comparison-based witness
# replaced it.
#
# Pass 23 is the slice's reason for existing: the consumer wrapper made a
# second owner of the placeholder body. Unlike every other mutation in this
# file, the mutant raises nothing -- it is caught by an ordinary
# check/check-equal mismatch that exits 1, and it answers both identity claims
# wrongly while every lane that imports only the owner still passes.
#
# Pass 24 is the fingerprint algorithm's own decisions -- the +1 that keeps a
# leading zero byte significant, the seed, the multiplier, the modulus, and
# combine's order sensitivity.
#
# Pass 25 is the hex digit table. It sets no manifest, so provenance is
# skipped here exactly as it is for every other pass but 26 through 29: what
# actually catches the mutation is the self-tests' own "hex digits render
# lowercase" case, which check-equals fixed literals ("ff", "deadbeef", "0")
# rather than deriving its expectation from fingerprint.sls.
#
# Passes 26 through 29 are the provenance check and the reachability guard
# that closes over it (Task 8): 26 is the comparison, 27 the
# missing-expectation branch, 28 the call site that reaches
# harness-verify-provenance! at all, and 29 harness-provenance-reachability-
# diagnosis itself, each witnessed through the exact-status helper so that
# exit 3 -- the refusal -- is the green baseline, exactly as passes 4 and 5 do
# for the launcher's guard-directory refusals. A third refusal -- a manifest
# naming an unreadable body -- has no mutation; see the stated blind spot
# recorded beside pass 27 below. Pass 28 was pass 26's second mutation until
# Task 8: see the detail beside its declaration for why the reachability guard
# made WRONG_FP_FILE's exit-3 baseline ambiguous for that one mutation and not
# for pass 26's own.
#
# WHAT THIS SUITE NEEDS FROM ITS ENVIRONMENT
#
# The self-tests assert that the lane declared its execution mode, that the
# registration's test name is visible, and read the fingerprint fixture
# through adapter-file-bytes, so BYTE_MACHINE_EXECUTION_MODE=source,
# BYTE_MACHINE_TEST_NAME, and BYTE_MACHINE_FINGERPRINT_SAMPLE (naming
# test/fixtures/fingerprint-sample.bin) must all be set in this process;
# CTest supplies all three -- see this suite's registration in
# test/CMakeLists.txt. Run by hand without them, the baseline fails before any
# mutation is tried -- which is the designed behaviour, not a bug: an
# unverifiable baseline makes every mutation look caught.

cmake_minimum_required(VERSION 3.26)

# See "TWENTY-NINE PASSES..." above. Declared here, rather than only in prose,
# so the count enforced at the bottom of this file is the same text a reader
# checks by eye at the top -- one number to keep in sync, not two that can
# quietly disagree.
set(EXPECTED_PASSES 29)
set(EXPECTED_MUTATIONS 65)

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

# src is staged whole, not just the shared body: --library-root below points at
# src/chez, the owner wrapper's own directory, and --source-dir points at
# src/common, the shared body's directory. Both live under src, so staging the
# body alone would leave the wrapper it is included through unreachable.
set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers"
  "src" "test/common")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

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

# FIND used to open on `(cond (...` itself, back when the error clause was the
# cond's first clause. Task 8 gave harness-exit-status a new first clause --
# provenance outranking both -- which pushed the error and failure clauses one
# line down, onto their own matching indentation; anchoring on those two lines
# alone is what survives a further clause ever being added the same way again.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a failure outranks a harness error in the exit status"
  FIND [[        ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)]]
  REPLACE [[        ((> harness-failure-count 0) harness-status-failed)
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

# The other two print-only decisions, and the same argument. The adapter
# protocol exposes no output-capture service, and the shared runner body may
# not reach past its protocol for one -- so the harness has no way to read
# back what it printed -- and this suite judges a mutation by the verify
# command's exit status, so an output difference is invisible to it whatever
# lane it runs.
# byte-machine.harness.verbose.chez.source closes the half that can be closed:
# it runs a real body with the variable set, so the path is executed and a
# break that raises is caught. What no layer checks is that the line was
# printed. Spec section 5.3 records the manual check that does.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: the value read for BYTE_MACHINE_TEST_VERBOSE is discarded"
  FIND [[    (set! harness-verbose (if (and v (not (string=? v ""))) #t #f)))]]
  REPLACE [[    (set! harness-verbose #f))]]
  EXPECT_SURVIVES
    "the verify command that judges this mutation does not set the variable, so both runs take the same branch -- harness-verbose ends up #f either way -- and the two are byte-identical, not merely indistinguishable by exit status. In a process that does set it the whole difference is one printed line per passing case: no counter, no case count, no status moves, and this suite judges by exit status. byte-machine.harness.verbose.chez.source proves the read happens and does not raise; that the value read is honoured is covered by the manual check recorded in spec section 5.3 -- either self-tests lane with BYTE_MACHINE_TEST_VERBOSE=1 prints one pass line per case and none without it")

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
  FIND [[(source-directories (append source-dirs (list (path-directory program))))]]
  REPLACE [[(source-directories (list (path-directory program)))]])

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC harness-self-tests.chez.sps
  LABEL "launcher: the program's own directory is off the source path"
  FIND [[(source-directories (append source-dirs (list (path-directory program))))]]
  REPLACE [[(source-directories source-dirs)]])

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

# Load-bearing, unlike the three names in the survivor above: the fingerprint
# library now reads files itself (byte-machine test fingerprint), so
# harness-fingerprint-file no longer reaches adapter-file-bytes at all. The
# self-tests' own direct call -- reading the fingerprint sample fixture
# through it -- is the only thing left that makes dropping this export
# visible.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.chez.sps
  LABEL "chez adapter: adapter-file-bytes is dropped from the export list"
  FIND [[    adapter-value->string adapter-describe-condition adapter-file-bytes]]
  REPLACE [[    adapter-value->string adapter-describe-condition]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Second pass: harness-begin's read of the environment filter -----------
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
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-empty-selection.chez.sps")

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

# --- Third pass: the failure counter itself ---------------------------------
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
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-bootstrap.chez.sps
  LABEL "runner: a recorded failure is never counted, so a failing suite exits 0"
  FIND [[  (set! harness-failure-count (+ harness-failure-count 1))]]
  REPLACE [[  (set! harness-failure-count harness-failure-count)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 4 to 5: the launcher's two guard-directory refusals -------------
#
# The launcher decides whether a lane runs at all, and its object guard is the
# sole mechanism that makes `mode=source` an honest claim. Neither refusal can
# be reached by a lane that was set up correctly, so each gets a deliberately
# wrong command line of its own, run through the exact-status helper so that
# exit 2 -- the refusal -- is what a healthy launcher scores.
#
# A third refusal used to live here: a missing required flag, witnessed by
# invoking the launcher with no arguments at all (SPEC named after that
# invocation's own ctest lane, byte-machine.harness.launcher-no-program.chez.source,
# since there was no program on the command line to name). It is gone. Slice 3's
# parse-decision passes below replace it with one mutation per required-flag
# entry, each a strictly more precise witness of the same decision than a
# zero-argument invocation was; keeping both would mean two mutations proving
# the same line, one of them permanently coarser. The retired ctest lane
# itself still runs, unchanged, as a real regression test -- it is just no
# longer this suite's witness.
#
# SPEC names the registered lane rather than a body basename, because the
# witness is a whole invocation and not a program: "passing" means the named
# body never ran.

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_ABSENT_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${ABSENT_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_ABSENT_GUARD_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

# EXPECT_OUTPUT_MATCHES captures what this mutation actually, verifiably
# produces: with the existence check gone, the very next line calls
# directory-list on a path that does not exist, which Chez itself refuses --
# a real, deterministic consequence of deleting exactly this check, not the
# launcher's own die(). Verified against a real staged run, not guessed; see
# byte_machine_slice3_launcher_pass's header comment below for why the wrapper's
# own exit code (0 or 1) cannot make this distinction by itself.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-absent-guard.chez.source
  LABEL "launcher: a guard directory that does not exist is assumed rather than checked"
  FIND [[(if (not (file-directory? object-guard-dir))]]
  REPLACE [[(if #f]]
  EXPECT_OUTPUT_MATCHES "Exception in directory-list")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_DIRTY_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${DIRTY_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${LAUNCHER_DIRTY_GUARD_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

# The one that matters most: a guard directory that has acquired a file is no
# longer a guard, and the lane would go on reporting mode=source while loading
# whatever was put there.
#
# EXPECT_OUTPUT_MATCHES here is "bootstrap: failures=0", not anything about the
# stray file: with this check gone the launcher does not notice the dirty
# guard at all, so the whole staged bootstrap program runs and passes, ending
# with its own success banner. That is the correct, deterministic consequence
# of deleting exactly this line, verified against a real staged run.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.launcher-dirty-guard.chez.source
  LABEL "launcher: a guard directory with a file in it is accepted as a guard"
  FIND [[(if (not (null? (directory-list object-guard-dir)))]]
  REPLACE [[(if #f]]
  EXPECT_OUTPUT_MATCHES "bootstrap: failures=0")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Sixth pass: a source lane that compiles what it imports ---------------
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
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${COMPILE_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_mutation(
  FILE ${LAUNCHER} SPEC byte-machine.harness.bootstrap.chez.source
  LABEL "launcher: a source lane is allowed to compile what it imports"
  FIND [[(compile-imported-libraries #f)]]
  REPLACE [[(compile-imported-libraries #t)]]
  EXPECT_SURVIVES
    "deleting the call is provably unobservable -- Chez's own default for compile-imported-libraries is already #f -- so the only mutation with an effect is turning it on, and its entire effect is a file: Chez writes byte-machine/test/harness.so into the object half of the library-directories pair, which is the guard, and it does so after the launcher has already asserted the guard was empty. No single process can see it. The registered lanes can, and do: with compilation on, the first Chez lane to run pollutes the shared object guard and three of the harness preset's tests fail. This suite runs one process per mutation, so what it can prove about this line is only that the line is still there")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Seventh pass: the library-directories pairing ---------------------------
#
# The pairing is the launcher's central mechanism. Chez looks for a library's
# compiled object only in the *object* half of a library-directories pair, so
# pairing the library root with a directory the build keeps empty is the whole
# reason this lane may call itself "source". Three places in the tree assert
# that -- the launcher's own header, test/CMakeLists.txt, and spec section 7.1 --
# and until this pass nothing checked it. `(library-directories (list
# library-root))` left every test green, because no library root in this tree
# has an object beside its source for Chez to prefer.
#
# So this pass builds one, in a library root of its own. A garbage `.so` is not
# enough: Chez silently ignores a file it cannot read as a library, and both the
# pristine and the unpaired run then exit 0 -- an inconclusive experiment, not
# evidence that the pairing does nothing. The object here is genuinely compiled,
# from a copy of the adapter whose `adapter-runtime-name` returns a sentinel,
# and the pristine `.sls` stays beside it so the baseline has real source to
# load. The sentinel is what makes the catch legible: the mutated run fails
# *because the object was loaded*, and says so in its banner, its FAIL-CONTEXT
# line, and its summary, rather than failing for some unrelated reason.
#
# Everything lives under this suite's work directory. The source tree is only
# read, no other pass's guard is touched, and this pass gets an empty guard of
# its own so that a future change to the shared one cannot quietly decide the
# result.
#
# Reached only when a Chez was passed in, the same way every other Chez pass
# here is: this file refuses to start without one, and the registration in
# test/CMakeLists.txt is guarded on the same variable, so `ctest --preset
# no-scheme` never reaches the compile below.

byte_machine_mutation_reset()

set(POISON_DIR "${WORK_DIR}/poisoned-library-root")
set(POISON_ROOT "${POISON_DIR}/root")
set(POISON_SOURCE_DIR "${POISON_DIR}/poisoned-source")
set(POISON_OBJECT "${POISON_ROOT}/byte-machine/test/harness.so")
set(POISON_GUARD_DIR "${WORK_DIR}/guard-poisoned")

file(REMOVE_RECURSE "${POISON_DIR}" "${POISON_GUARD_DIR}")
file(MAKE_DIRECTORY "${POISON_ROOT}/byte-machine/test")
file(MAKE_DIRECTORY "${POISON_SOURCE_DIR}/byte-machine/test")
file(MAKE_DIRECTORY "${POISON_GUARD_DIR}")

# Asserted, not assumed, for the same reason SITES is: if the adapter is
# refactored past this pattern the "poisoned" copy would be a pristine one, the
# mutated run would pass, and the mutation would be reported UNCAUGHT with no
# hint that the poison was the thing that broke.
set(POISON_FIND [[  (define (adapter-runtime-name) "chez")]])
set(POISON_REPLACE [[  (define (adapter-runtime-name) "POISONED-FROM-OBJECT")]])

file(READ "${SOURCE_ROOT}/${CHEZ_ADAPTER}" POISON_PRISTINE)
string(FIND "${POISON_PRISTINE}" "${POISON_FIND}" POISON_AT)
if(POISON_AT EQUAL -1)
  message(FATAL_ERROR
    "byte-machine-mutation: the Chez adapter no longer contains "
    "'${POISON_FIND}', so the object this pass compiles would be an unpoisoned "
    "copy and the library-directories mutation would prove nothing. Update the "
    "pattern rather than dropping it.")
endif()
string(REPLACE "${POISON_FIND}" "${POISON_REPLACE}" POISON_MUTATED "${POISON_PRISTINE}")

# The pristine source goes down first: Chez prefers the object only while it is
# *not older* than the source beside it, and the object is written by the
# compile below.
#
# There is a SECOND staleness input, and it is not local to this directory: the
# library `include`s harness-runner.scm, which Chez re-resolves through
# source-directories at LOAD time -- so the object is compared against the
# STAGED runner as well. That copy keeps its source-tree mtime only because
# byte_machine_mutation_stage uses file(COPY), which preserves timestamps. If
# staging ever switches to a copy that stamps `now`, the staged runner becomes
# newer than the object, Chez loads the source, and this mutation stops biting.
# It will not do so silently -- the mutation carries no EXPECT_SURVIVES, so the
# regression surfaces as UNCAUGHT and fails the suite -- but a reader changing
# the staging should know why it matters.
file(WRITE "${POISON_ROOT}/byte-machine/test/harness.sls" "${POISON_PRISTINE}")
file(WRITE "${POISON_SOURCE_DIR}/byte-machine/test/harness.sls" "${POISON_MUTATED}")

# harness.sls now imports (byte-machine test fingerprint) (Task 3 of the
# include collapse), so the object compiled below has a real library
# dependency for the first time. MEASURED, not assumed: Chez's staleness
# check on a compiled library is transitive -- an object is trusted only if
# every library it imports also resolves to a non-stale compiled object, not
# bare source. A minimal two-library reproduction confirmed this directly: an
# importer's freshly compiled object was silently discarded in favour of its
# own pristine source whenever the imported library resolved to source only,
# even though the importer's own root was searched first and its object was
# not stale by itself. Giving fingerprint no compiled object anywhere in this
# pass's roots (the shape the plan called for, reasoning "the second root
# exists only to resolve the fingerprint import") reproduces exactly that:
# the poisoned harness object is silently rejected and the baseline's
# pristine banner prints instead, so the mutation below goes UNCAUGHT. The
# fix is to make POISON_ROOT self-sufficient: a real, non-stale fingerprint
# object beside the poisoned harness object, compiled first so harness's
# object is never older than a library it depends on.
#
# One cross-copy invariant this relies on: the compile below resolves
# fingerprint's import from ${SOURCE_ROOT}/test/support/harness/chez (the
# real source tree, via library-directories), while the verify run further
# down resolves the same import from POISON_ROOT's own copy. Compiling
# against one copy and running against another is safe here only because
# the file(READ)/file(WRITE) pair immediately below makes the two
# byte-identical by construction -- the same guarantee the pristine
# harness.sls copy above already depends on.
file(READ "${SOURCE_ROOT}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
     POISON_FINGERPRINT_PRISTINE)
file(WRITE "${POISON_ROOT}/byte-machine/test/fingerprint.sls" "${POISON_FINGERPRINT_PRISTINE}")

set(POISON_COMPILE_SCRIPT "${POISON_DIR}/compile-poisoned-object.ss")
file(WRITE "${POISON_COMPILE_SCRIPT}"
";; Written by SchemeMutationSuite.cmake, never committed. Compiles the
;; poisoned adapter copy into the library root that holds the pristine source,
;; so a launcher which stops pairing that root with an empty object directory
;; loads the object instead of the source. This is a per-runtime staging file,
;; not a shared body, so naming Chez here is allowed.
;;
;; Both halves of the poison are read from the source tree, not from the stage:
;; the two are byte-identical by construction, and reading the stage would make
;; this pass depend on the previous pass having left it in place.
(source-directories (list \"${SOURCE_ROOT}/test/support/harness/shared\"))
(library-directories (list (cons \"${SOURCE_ROOT}/test/support/harness/chez\" \"${POISON_GUARD_DIR}\")))
;; Compiled first, and into POISON_ROOT itself (not the guard): harness's own
;; object is trusted only if this one is also a real, reachable object by the
;; time harness compiles, per the transitive staleness note above.
(compile-library \"${POISON_ROOT}/byte-machine/test/fingerprint.sls\"
                 \"${POISON_ROOT}/byte-machine/test/fingerprint.so\")
(compile-library \"${POISON_SOURCE_DIR}/byte-machine/test/harness.sls\"
                 \"${POISON_OBJECT}\")
")

execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script" "${POISON_COMPILE_SCRIPT}"
  RESULT_VARIABLE POISON_RC
  OUTPUT_VARIABLE POISON_OUT
  ERROR_VARIABLE POISON_ERR)
if(NOT POISON_RC EQUAL 0 OR NOT EXISTS "${POISON_OBJECT}"
   OR NOT EXISTS "${POISON_ROOT}/byte-machine/test/fingerprint.so")
  message(FATAL_ERROR
    "byte-machine-mutation: could not compile the poisoned library root "
    "(exit ${POISON_RC}). Without a real object for both harness and the "
    "fingerprint library it now imports, the library-directories mutation "
    "cannot discriminate, and a run against a file Chez cannot read as a "
    "library, or a harness object it distrusts for an unresolved import, "
    "passes either way.\n"
    "${POISON_OUT}${POISON_ERR}")
endif()

# Makes "not older than the source" true by construction rather than by the
# compile happening to take a second, which a filesystem with coarse timestamps
# would not record. The fingerprint object is touched first, preserving the
# dependency order the compile above already established: harness's object
# must never be older than a library it imports.
file(TOUCH "${POISON_ROOT}/byte-machine/test/fingerprint.so")
file(TOUCH "${POISON_OBJECT}")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${POISON_ROOT}"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${POISON_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

# EXPECT_OUTPUT_MATCHES turns the paragraph above's claim -- that the mutated
# run "says so in its banner, its FAIL-CONTEXT line, and its summary" -- into
# something this suite enforces rather than merely asserts in prose. The
# sentinel is the literal string written into POISON_REPLACE above, so a rc
# that happens to be nonzero for some other reason (a staging error, an
# unrelated crash) is reported caught-for-the-wrong-reason instead of caught.
byte_machine_mutation(
  FILE ${LAUNCHER}
  SPEC "harness-self-tests.chez.sps against a library root holding a compiled object"
  LABEL "launcher: the library root is no longer paired with the object guard"
  FIND [[(library-directories
 (map (lambda (root) (cons root object-guard-dir)) library-roots))]]
  REPLACE [[(library-directories library-roots)]]
  EXPECT_OUTPUT_MATCHES "POISONED-FROM-OBJECT")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 8: the placeholder body's decisions -------------------------------
#
# A wrapper that reimplemented the body is exactly a wrapper whose runtime does
# not notice the body changing. That is why this body is included rather than
# defined in its owner library, and why this pass mutates it there.

set(PLACEHOLDER_BODY src/common/byte-machine/placeholder.scm)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--library-root" "${STAGE_DIR}/src/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-tests.chez.sps")

byte_machine_mutation_reset()

byte_machine_mutation(
  FILE ${PLACEHOLDER_BODY} SPEC placeholder-tests.chez.sps
  LABEL "placeholder: anything is a vector"
  FIND [[  (and (vector? x)]]
  REPLACE [[  (and #t]])

# Two mutations, because the length check can fail two ways: it can be absent,
# or its bound can be wrong. Deleting it is caught by the case that builds a
# length-3 vector carrying the real tag -- reachable through vector-ref on a
# legitimately built placeholder, which is why this is witnessable at all.
byte_machine_mutation(
  FILE ${PLACEHOLDER_BODY} SPEC placeholder-tests.chez.sps
  LABEL "placeholder: the length is not checked at all"
  FIND [[       (= (vector-length x) 2)]]
  REPLACE [[       #t]])

byte_machine_mutation(
  FILE ${PLACEHOLDER_BODY} SPEC placeholder-tests.chez.sps
  LABEL "placeholder: the length check accepts the wrong length"
  FIND [[       (= (vector-length x) 2)]]
  REPLACE [[       (= (vector-length x) 3)]])

byte_machine_mutation(
  FILE ${PLACEHOLDER_BODY} SPEC placeholder-tests.chez.sps
  LABEL "placeholder: the tag is not checked"
  FIND [[       (eq? (vector-ref x 0) placeholder-tag)))]]
  REPLACE [[       #t))]])

# The rule the whole representation rests on. With a symbol tag every
# assertion in the suite still passes except the one written for this, and
# slice 4's identity test would become incapable of failing.
byte_machine_mutation(
  FILE ${PLACEHOLDER_BODY} SPEC placeholder-tests.chez.sps
  LABEL "placeholder: the tag is an interned symbol"
  FIND [[(define placeholder-tag (vector 'byte-machine-placeholder))]]
  REPLACE [[(define placeholder-tag 'byte-machine-placeholder)]])

byte_machine_mutation(
  FILE ${PLACEHOLDER_BODY} SPEC placeholder-tests.chez.sps
  LABEL "placeholder: the marker is allocated per call"
  FIND [[(define (placeholder-marker)
  placeholder-marker-object)]]
  REPLACE [[(define (placeholder-marker)
  (vector 'byte-machine-marker))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 9 to 18: the launcher's parse decisions -------------------------
#
# Deleting a refusal does not produce a wrong answer; it produces an invocation
# that is accepted and then fails somewhere else, or does not fail at all. Two
# of these mutations leave the launcher reaching malformed input and dying at
# 255 rather than 2, which the exact-status helper reports as out-of-vocabulary.
# That is still caught, and it is the honest outcome: the refusal exists exactly
# so that malformed input is named rather than stumbled over.

set(LAUNCHER_BASE_ARGS
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

# byte_machine_slice3_launcher_pass(<lane> <label> <find> <replace>
#                                   <expect_output_matches> <arg>...)
#
# One pass: point the verify command at a deliberately wrong invocation, declare
# one mutation, run it. Defined here rather than inlined ten times because the
# only thing that varies is the lane, the command line, and the mutation.
#
# expect_output_matches exists because the wrapper's own exit code is only ever
# 0 or 1 -- ByteMachineExpectExit.cmake's message(FATAL_ERROR) exits 1
# regardless of what the real launcher's exit status was, so a nonzero result
# here means only "the real process did not exit 2", never which of the two
# very different ways that can happen: the invocation this pass built runs to
# completion once the deleted check stops blocking it (verified as
# "bootstrap: failures=0" -- the bootstrap program's own success banner,
# reachable only by loading and running the entire staged launcher and
# program), or it reaches a later, unrelated Chez error and dies with an
# out-of-vocabulary status (verified per pass -- see the call sites below).
# Both are legitimate evidence that the deleted check mattered. What neither
# looks like is a read error from a staged file that stopped being valid
# Scheme, which is what this project measured exactly once: a REPLACE that
# opened a line comment and swallowed a list's closing parens (recorded next to
# the --source-dir mutation below) caught the pass at exit 255 on
# "Exception in read: ..." rather than on the refusal it names. Every value
# passed here was captured from a real staged run of the mutation it guards,
# not guessed.
#
# The reset, the declaration and the run all happen inside this function on
# purpose. byte_machine_mutation_reset and byte_machine_mutation both write the
# counter with PARENT_SCOPE, so they agree only while they share a caller;
# splitting them across this boundary would leave the run seeing a count from
# somewhere else.
function(byte_machine_slice3_launcher_pass lane label find replace expect_output_matches)
  byte_machine_mutation_reset()

  string(JOIN "|" packed
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
    ${ARGN})

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${CMAKE_COMMAND}"
    "-DBYTE_MACHINE_EXPECT_EXIT=2"
    "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
    -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

  byte_machine_mutation(
    FILE ${LAUNCHER} SPEC "${lane}"
    LABEL "${label}"
    FIND "${find}"
    REPLACE "${replace}"
    EXPECT_OUTPUT_MATCHES "${expect_output_matches}")

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-unknown-flag.chez.source
  "launcher: an unrecognised flag is accepted"
  [[        ((not (member (car rest) known-flags))]]
  [[        (#f]]
  "bootstrap: failures=0"
  "--librarie-root" "${STAGE_DIR}/test/support/harness/chez" ${LAUNCHER_BASE_ARGS})

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-missing-value.chez.source
  "launcher: a flag with no value is accepted"
  [[        ((null? (cdr rest))]]
  [[        (#f]]
  "Exception in cddr"
  ${LAUNCHER_BASE_ARGS} "--source-dir")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: a single-valued flag may be given twice"
  [[   (if (> (length (flag-values flag)) 1)]]
  [[   (if #f]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

# SPEC must name a lane `ctest -N` actually lists: it is the transcript name a
# real invocation is judged under, and once a verify command is set (as every
# pass in this file does), SPEC is otherwise ignored -- so a value that names
# no real lane is checked by nothing, and nothing notices. This pass and the
# entry-specific one below that drops --library-root from required-flags both
# run the identical missing-library-root invocation, so both are witnessed by
# the same registered lane, byte-machine.harness.launcher-no-library-root.chez.source.
# An earlier revision renamed this pass's SPEC to
# "byte-machine.harness.launcher-required-flag-unchecked.chez.source" to stop
# the two mutations sharing one name in the transcript -- a real problem -- but
# that traded it for a worse one: a unique SPEC value naming a lane that does
# not exist. The disambiguation belongs in LABEL instead, which is free text
# with no such constraint: this pass witnesses decision 2's own check (the
# `if` that runs once per required flag, so it breaks identically no matter
# which flag the invocation happened to omit -- library-root was picked only
# because it made a convenient invocation to reuse), while the pass below
# witnesses required-flags' library-root *entry* specifically, i.e. whether
# the flag is still in the list decision 2 walks at all. Two different lines,
# two different mutations, one shared witness.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: a missing required flag is not noticed (decision 2's own check, general across every entry; reuses the no-library-root invocation below only for convenience)"
  [[   (if (null? (flag-values flag))]]
  [[   (if #f]]
  [[library \(byte-machine test harness\) not found]]
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

# Four more: one per entry in required-flags. The check above is one decision,
# but the list it walks is four, and an entry dropped from it is invisible to
# every invocation except the one omitting that flag.

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-program.chez.source
  "launcher: --program is dropped from required-flags"
  [[  (list "--program"]]
  [[  (list ;; --program removed by mutation]]
  "Exception in car"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-object-guard.chez.source
  "launcher: --object-guard is dropped from required-flags"
  [[        "--object-guard"]]
  [[        ;; --object-guard removed by mutation]]
  "Exception in car"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: --library-root is dropped from required-flags"
  [[        "--library-root"]]
  [[        ;; --library-root removed by mutation]]
  [[library \(byte-machine test harness\) not found]]
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

# --source-dir is the last entry in required-flags, so its source line ends
# with two closing parens -- the list's and the define's -- rather than one.
# A FIND that matched only the flag's text left both dangling after a REPLACE
# that opened a line comment: the comment swallowed ")) " too, so the staged
# file was not readable Scheme and died with a read error at exit 255 rather
# than the launcher's own required-flag refusal -- caught, but for the wrong
# reason, and witnessing nothing about the decision this pass names. The FIND
# below includes the trailing "))" so the REPLACE can close the list itself.
# Whichever entry ends up last in required-flags after a reorder or a fifth
# addition inherits this hazard and needs the same treatment.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-source-dir.chez.source
  "launcher: --source-dir is dropped from required-flags"
  [[        "--source-dir"))]]
  [[        ;; --source-dir removed by mutation
        ))]]
  "Exception in include"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

# Two more, for single-valued-flags. --object-guard has never been exercised as
# a repeated flag: the general check just above is witnessed only through
# --program (LAUNCHER_BASE_ARGS already carries one --object-guard, so this
# pass repeats it rather than adding a second fixture guard directory --
# decision 3 counts occurrences, not distinct values). Dropping --object-guard
# from single-valued-flags specifically, leaving the check itself and
# --program's membership in the list untouched, is invisible to every
# invocation but this one.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-object-guard.chez.source
  "launcher: --object-guard is dropped from single-valued-flags"
  [[(define single-valued-flags
  (list "--object-guard" "--program"))]]
  [[(define single-valued-flags
  (list "--program"))]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--object-guard" "${GUARD_DIR}")

# required-flags' own rationale -- "an entry dropped from it is invisible to
# every invocation except the one omitting that flag" -- applies just as much
# to single-valued-flags' other member, so --program gets the same treatment.
# It sits last on its line, hard against the list's and the define's closing
# parens -- the same position that made --source-dir's required-flags
# mutation above catch a read error instead of the decision it names (the
# hazard recorded there). The FIND below matches the whole two-line form,
# both closing parens included, and the REPLACE is itself a complete,
# well-formed define, so there is no dangling ")" left for a comment to
# swallow.
#
# The invocation below repeats --program, so the real lane witnessing it is
# byte-machine.harness.launcher-repeated-flag.chez.source, not a name of this
# pass's own -- see the SPEC-must-name-a-real-lane comment above the
# required-flag-unchecked pass for why that match matters and what happens
# when it drifts.
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: --program is dropped from single-valued-flags (reuses the launcher-repeated-flag invocation, which already repeats --program)"
  [[(define single-valued-flags
  (list "--object-guard" "--program"))]]
  [[(define single-valued-flags
  (list "--object-guard"))]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

# --- Passes 19 to 21: the working-directory matrix --------------------------
#
# One mutation, three passes, three expected outcomes. The launcher is made to
# resolve shared bodies against the working directory -- the mechanism this
# project deliberately does not use -- while the program's own directory is left
# in place so the test body still resolves and each lane fails, or does not, for
# the reason under test.
#
#   empty      fails: nothing to include
#   decoy      fails: wrong answer, on content
#   identical  PASSES: the copy in the working directory is the real body
#
# The survivor is the point. It is what turns "the identical lane is the vacuous
# test someone writes by default" from a comment into something this suite
# observes on every run, and it is what makes the decoy lane's failure
# attributable to content rather than to the mere presence of a same-named file.

if(NOT BYTE_MACHINE_CWD_MATRIX_DIR)
  message(FATAL_ERROR
    "byte-machine-mutation: BYTE_MACHINE_CWD_MATRIX_DIR was not passed in. The "
    "matrix passes assert what a launch directory does or does not change, so "
    "they cannot run from the stage directory like every other pass.")
endif()

set(CWD_MUTATION_FIND
  [[(source-directories (append source-dirs (list (path-directory program))))]])
set(CWD_MUTATION_REPLACE
  [[(source-directories (append (list ".") (list (path-directory program))))]])

foreach(cwd_case empty decoy identical)
  byte_machine_mutation_reset()

  set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY
      "${BYTE_MACHINE_CWD_MATRIX_DIR}/same-name-${cwd_case}")
  if(cwd_case STREQUAL "empty")
    set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY
        "${BYTE_MACHINE_CWD_MATRIX_DIR}/empty")
  endif()

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
    "--library-root" "${STAGE_DIR}/test/support/harness/chez"
    "--library-root" "${STAGE_DIR}/src/chez"
    "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
    "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
    "--object-guard" "${GUARD_DIR}"
    "--program" "${STAGE_DIR}/test/common/placeholder-tests.chez.sps")

  if(cwd_case STREQUAL "identical")
    byte_machine_mutation(
      FILE ${LAUNCHER} SPEC placeholder-tests.chez.sps
      LABEL "launcher: shared bodies resolve against the working directory (identical)"
      FIND "${CWD_MUTATION_FIND}"
      REPLACE "${CWD_MUTATION_REPLACE}"
      EXPECT_SURVIVES
        "This lane runs from a directory holding a copy of every body the lane includes, so an include resolved against the working directory finds the real text and the suite passes. That is the lane's purpose: it is the naive working-directory test, carried as the control that makes the decoy and empty lanes' failures attributable. If this mutation ever starts being caught, the copies have drifted from the bodies they were copied from and the control has quietly become something else.")
  elseif(cwd_case STREQUAL "decoy")
    # The design spec names this exact risk: add an export to placeholder.scm
    # without adding a matching (even if wrong-answered) one to the impostor
    # body test/CMakeLists.txt writes for this directory, and the decoy fails
    # at library construction -- an unbound export, a load-time error -- rather
    # than on content, and would still be "caught" by a bare nonzero check,
    # proving nothing about resolution.
    #
    # This pass's verify command is the launcher itself, unwrapped by
    # ByteMachineExpectExit -- unlike the launcher-parse passes below, where
    # that wrapper's own exit code (0 or 1 regardless of the real one) is all
    # that reaches this file -- so both new options can be used, and both were
    # measured against a real staged run rather than guessed. EXPECT_STATUS 1
    # is the harness's own "an assertion failed" status; a library-construction
    # failure is a different defect the harness's vocabulary reserves 2 for, or
    # an uncaught condition outside the vocabulary entirely. EXPECT_OUTPUT_MATCHES
    # additionally requires the harness's own per-case failure line
    # ("byte-machine-harness: FAIL ", trailing space so FAIL-CONTEXT's summary
    # line cannot satisfy it), printed only once a check actually ran and
    # disagreed -- i.e. once the wrong file was loaded and *evaluated*, not
    # merely failed to load.
    byte_machine_mutation(
      FILE ${LAUNCHER} SPEC placeholder-tests.chez.sps
      LABEL "launcher: shared bodies resolve against the working directory (decoy)"
      FIND "${CWD_MUTATION_FIND}"
      REPLACE "${CWD_MUTATION_REPLACE}"
      EXPECT_STATUS 1
      EXPECT_OUTPUT_MATCHES "byte-machine-harness: FAIL ")
  else()
    byte_machine_mutation(
      FILE ${LAUNCHER} SPEC placeholder-tests.chez.sps
      LABEL "launcher: shared bodies resolve against the working directory (${cwd_case})"
      FIND "${CWD_MUTATION_FIND}"
      REPLACE "${CWD_MUTATION_REPLACE}")
  endif()

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endforeach()

# Cleared rather than left pointing at same-name-identical: this variable is
# set at file scope for the whole loop above, and any pass appended after this
# point with no WORKING_DIRECTORY of its own would otherwise silently launch
# from the matrix's identical directory instead of the stage.
set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY "")

# --- Pass 22: the consumer body's decisions ---------------------------------
#
# Same argument as pass 8, for a second body: a wrapper that reimplemented this
# body is exactly a wrapper whose runtime does not notice the body changing.

set(CONSUMER_BODY src/common/byte-machine/placeholder-consumer.scm)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--library-root" "${STAGE_DIR}/src/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-identity-tests.chez.sps")

byte_machine_mutation_reset()

# Caught by comparison, not by a raise: consume always takes the reject
# branch, so (consume (make-placeholder 7)) returns the marker instead of 7
# and the recognition case fails an ordinary check-equal. An earlier form
# used #t instead of #f, driving the same case into placeholder-value on a
# non-vector and catching it by an induced raise instead -- replaced once
# this comparison-based witness was found. See section 5.3 of the slice-4
# design.
byte_machine_mutation(
  FILE ${CONSUMER_BODY} SPEC placeholder-identity-tests.chez.sps
  LABEL "consumer: the argument is not checked at all"
  FIND [[  (if (placeholder? p)]]
  REPLACE [[  (if #f]])

byte_machine_mutation(
  FILE ${CONSUMER_BODY} SPEC placeholder-identity-tests.chez.sps
  LABEL "consumer: the recognised branch yields the marker, not the value"
  FIND [[      (placeholder-value p)]]
  REPLACE [[      (placeholder-marker)]])

# The only mutation that reaches D3's second clause by itself: recognition
# still works, and the outcome is merely a different object that prints the
# same. This is the one an eq?-free test would miss entirely.
byte_machine_mutation(
  FILE ${CONSUMER_BODY} SPEC placeholder-identity-tests.chez.sps
  LABEL "consumer: the outcome is a lookalike, not the owner's singleton"
  FIND [[      (placeholder-marker)))]]
  REPLACE [[      (vector 'byte-machine-marker)))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 23: the consumer wrapper double-include ---------------------------
#
# Section 7.2's rule -- each shared body is included by exactly one library;
# others import that owner -- stated as something that can fail. The mutation
# makes the consumer a second owner of the placeholder body, so it gets its own
# tag and its own marker, and both identity cases answer wrongly.
#
# It is the mutation this slice exists for, and it is silent under every other
# lane in the tree: measured on 2026-08-17, the mutant raises nothing -- it is
# caught only by the identity lane's own check/check-equal assertions, which
# exit 1. The placeholder-cwd lanes still pass under it, because they import
# only the owner. Only a program with both libraries in scope can see it.
#
# The import is REPLACED, never augmented. Adding an include beside the import
# was measured on the same date: Chez refuses at library construction with
# "multiple definitions for make-placeholder and other identifiers in body" --
# caught, but not for the declared reason. See section 8.1 of the slice-4
# design.

set(CHEZ_CONSUMER_WRAPPER src/chez/byte-machine/placeholder-consumer.sls)

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--library-root" "${STAGE_DIR}/src/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-identity-tests.chez.sps")

byte_machine_mutation(
  FILE ${CHEZ_CONSUMER_WRAPPER} SPEC placeholder-identity-tests.chez.sps
  LABEL "consumer wrapper: includes the owner's body instead of importing the owner"
  FIND [[  (import (rnrs) (byte-machine placeholder) (only (chezscheme) include))
  (include "placeholder-consumer.scm"))]]
  REPLACE [[  (import (rnrs) (only (chezscheme) include))
  (include "placeholder.scm")
  (include "placeholder-consumer.scm"))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 24: the fingerprint algorithm --------------------------------------
#
# The self-tests assert measured literals, so any change to seed, multiplier,
# modulus, the +1, or the digit table moves at least one of them.

set(FINGERPRINT test/support/harness/chez/byte-machine/test/fingerprint.sls)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

byte_machine_mutation_reset()

# Without the +1 a NUL contributes nothing, and the three leading-zero cases
# collapse into one value. This is the only mutation here that a fixed set of
# literals could survive if the literals happened not to include a NUL --
# which is why they do.
byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: leading zero bytes stop being significant"
  FIND [[                           (+ (bytevector-u8-ref bv i) 1))]]
  REPLACE [[                           (bytevector-u8-ref bv i))]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: the seed changes"
  FIND [[(define harness-fingerprint-seed 14695981039346656)]]
  REPLACE [[(define harness-fingerprint-seed 14695981039346657)]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: the multiplier changes"
  FIND [[(define harness-fingerprint-multiplier 1000003)]]
  REPLACE [[(define harness-fingerprint-multiplier 1000033)]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: the modulus changes"
  FIND [[(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1]]
  REPLACE [[(define harness-fingerprint-modulus 2305843009213693907)]])

# Combining becomes a sum, so order stops mattering and the two combine cases
# collapse to one value.
byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: combining stops being order sensitive"
  FIND [[              (modulo (+ (* h harness-fingerprint-multiplier) (+ (car rest) 1))]]
  REPLACE [[              (modulo (+ h (+ (car rest) 1))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 25: the hex rendering table -----------------------------------------
#
# MEASURED 2026-08-17. No manifest is set, so provenance is skipped here
# exactly as it is for every other pass but 26 through 29 below:
# BYTE_MACHINE_FINGERPRINT_FILES is unset, harness-verify-provenance! returns
# #t immediately, and the self-tests suite runs its own cases undisturbed. It
# is the self-tests' own "hex digits render lowercase" case that actually
# witnesses this mutation -- it check-equals fixed literals ("ff", "deadbeef",
# "0") rather than deriving its expectation from fingerprint.sls, so mutating
# the digit table fails an ordinary comparison: the process exits 1 (the
# harness's own "an assertion failed" status) with a "byte-machine-harness:
# FAIL " line, which is exactly what EXPECT_STATUS and EXPECT_OUTPUT_MATCHES
# below assert and exactly what the real run reports caught.

set(HEX_MUTATION_FIND [[(define harness-hex-digits "0123456789abcdef")]])
set(HEX_MUTATION_REPLACE [[(define harness-hex-digits "0123456789ABCDEF")]])

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.chez.sps
  LABEL "fingerprint: hex digits become uppercase"
  FIND "${HEX_MUTATION_FIND}"
  REPLACE "${HEX_MUTATION_REPLACE}"
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-machine-harness: FAIL ")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 26 and 27: the provenance check itself ----------------------------
#
# Wrapped in the exact-status helper so exit 3 -- the refusal -- is the green
# baseline, exactly as passes 4 and 5 do for the launcher. A mutation that makes
# the check more permissive drops the inner status to 0, the wrapper reports
# nonzero, and the mutation is caught. Continued below by passes 28 and 29,
# which this pair's own comments point to at the place each split off.
#
# THE MANIFEST NAMES ONE BODY ON PURPOSE
#
# BYTE_MACHINE_EXPECT_COMMAND packs its argument vector with `|`, which is also
# the manifest separator, so a two-element manifest would be unpacked as two
# arguments. One body is enough: these passes test whether the check runs and is
# consulted, not how values combine, which pass 24 covers. Passes 28 and 29
# keep the same one-body manifest for the same reason.

set(RUNNER_BODY test/support/harness/shared/harness-runner.scm)

set(WRONG_FP_FILE "${WORK_DIR}/wrong.fingerprint")
file(WRITE "${WRONG_FP_FILE}" "not-a-fingerprint")

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_MISMATCH_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WRONG_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_MISMATCH_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "provenance: the comparison always reports agreement"
  FIND [[    ((string=? expected computed) #f)]]
  REPLACE [[    (#t #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# "provenance: harness-begin stops checking at all" used to live here, sharing
# this pass's WRONG_FP_FILE verify command with EXPECT_EXIT 3. Task 8's
# reachability guard (test/support/harness/shared/harness-runner.scm,
# harness-provenance-reachability-diagnosis) made that ambiguous: with the call
# removed, harness-provenance-checked never becomes #t, and the guard now
# refuses with status 3 of its own accord -- the same number WRONG_FP_FILE's
# mismatch was already producing, for an unrelated reason. ByteMachineExpectExit
# compares only the number, so both baseline and this mutation satisfy
# EXPECT_EXIT 3 and the wrapper reports "exited as expected" either way: not
# caught, not because nothing noticed, but because two different refusals now
# agree on the one status this vocabulary gives refusals. Moved to pass 28
# below, which is what gives it a baseline the guard cannot also produce.

# Pass 27: the same wrapper, but the expectation file does not exist, so the
# refusal under test is the missing-expectation branch rather than the
# comparison. Its mutation leaves the guard `(not expected)` matching -- so
# there is no fallthrough to the next clause -- and changes only what the
# matched branch returns: silently #f instead of the diagnosis string.
# harness-verify-provenance! reads that #f as nothing to report and lets the
# run proceed as though the missing expectation had been verified.
#
# Measured 2026-08-17: caught, but not by exiting 0. The self-tests' own
# "a missing expectation is its own diagnosis" case calls
# harness-provenance-diagnosis(#f, ...) directly and checks that a diagnosis
# comes back; with the branch mutated that check fails outright -- an
# ordinary comparison -- and the whole run reports byte-machine-harness
# status 1, not 3. The exact-status wrapper below compares that 1 against the
# declared EXPECT_EXIT of 3 and reports the mismatch. Both routes are a
# failed comparison; neither is a raise.
#
# An earlier form mutated the guard instead of the branch: `(not expected)`
# became `(and #f expected)`, which never matches, so control fell through to
# `(string=? expected computed)` with expected still #f. string=? on a
# non-string is a type violation, so that form was caught by Chez's top-level
# handler killing the process at exit 255 -- outside the harness's own status
# vocabulary, and before a single self-test case ran -- rather than by the
# assertion naming this decision. Replaced once this comparison-based form
# was found, per AGENTS.md's preference for a failed comparison over a raise.
byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_ABSENT_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WORK_DIR}/never-produced.fingerprint"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_ABSENT_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance-absent-expectation.chez.source
  LABEL "provenance: a missing expectation stops being a diagnosis"
  FIND [[    ((not expected)
     (string-append
      "no expectation was supplied, so nothing can say whether this run "
      "executed the text it was supposed to. This run computed " computed "."))]]
  REPLACE [[    ((not expected) #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# A stated blind spot: the third refusal -- a manifest naming an unreadable
# body -- has no mutation here. Making it witnessable would need an
# expectation crafted to equal what the mutant computes after the read fails,
# which is a value with no meaning outside that mutation. It is covered by its
# registered lane, byte-machine.harness.provenance-missing-body.chez.source,
# and this is recorded rather than papered over with an EXPECT_SURVIVES, which
# AGENTS.md reserves for the genuinely unwitnessable.

# --- Pass 28: the call site, witnessed against a baseline the guard cannot
# also satisfy -----------------------------------------------------------
#
# Continues "provenance: harness-begin stops checking at all" from pass 26,
# with a different baseline. WRONG_FP_FILE cannot be reused: it makes the
# unmutated lane's correct behaviour exit 3, and after Task 8 this mutation's
# broken behaviour *also* exits 3 (the reachability guard's own refusal), so a
# wrapper that only compares the exit number cannot tell them apart -- both
# read as "exited 3 as expected." Giving the lane an expectation it actually
# matches makes the unmutated baseline exit 0 instead, which the guard cannot
# produce (harness-provenance-checked is #t by the time harness-summary reads
# it, so the guard stays quiet and the self-tests' own pass/fail is what
# decides). The mutation still removes the call, so harness-provenance-checked
# stays #f, the guard still refuses, and the lane still exits 3 -- now cleanly
# distinct from the 0 baseline instead of coinciding with the old one.
#
# THE MANIFEST NAMES ONE BODY, AS ABOVE, AND ITS EXPECTATION IS COMPUTED, NOT
# WRITTEN BY HAND
#
# byte_machine_expected_fingerprint in test/CMakeLists.txt is a CMake function,
# unreachable from this standalone script, so the value is produced the same
# way it is: running fingerprint-manifest.ss over the staged fingerprint.sls.
# THE ALGORITHM IS NOT REIMPLEMENTED HERE applies here just as it does there.
set(CORRECT_FP_FILE "${WORK_DIR}/correct.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script"
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness/chez"
          "${GUARD_DIR}"
          "${CORRECT_FP_FILE}"
          "${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
  RESULT_VARIABLE fp_rc
  OUTPUT_VARIABLE fp_out
  ERROR_VARIABLE fp_err)
if(NOT fp_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: could not compute pass 28's baseline fingerprint "
    "(exit ${fp_rc}): ${fp_out}${fp_err}")
endif()

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_UNCALLED_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${CORRECT_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=0"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_UNCALLED_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "provenance: harness-begin stops checking at all"
  FIND [[  (harness-verify-provenance!)
  (harness-clear-state!)]]
  REPLACE [[  (harness-clear-state!)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 29: the reachability guard itself -------------------------------
#
# harness-unreached-provenance.scm (test/support/harness/self/) deliberately
# never calls harness-begin, so its lane's baseline already exits 3 through
# the guard alone -- no WRONG_FP_FILE trick needed, and no
# BYTE_MACHINE_EXPECT_FINGERPRINT_FILE either, since nothing in this lane's
# reachable code ever compares a fingerprint. Two mutations, because
# harness-provenance-reachability-diagnosis's rule has two halves that fail
# independently (V13's own comment: "manifest and not checked?"): the
# diagnosis can stop firing, or checked? can stop meaning what its name says.
# Either one drops the baseline's 3 to 0, which EXPECT_EXIT catches cleanly --
# unlike pass 28, nothing else in this lane's execution can also produce 3, so
# no separate baseline is needed here.
set(UNREACHED_PROVENANCE_SPEC byte-machine.harness.unreached-provenance.chez.source)

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_REACHABILITY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-unreached-provenance.chez.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=3"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${PROVENANCE_REACHABILITY_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC ${UNREACHED_PROVENANCE_SPEC}
  LABEL "provenance: the reachability diagnosis stops guarding"
  FIND [[  (if (and manifest (not (string=? manifest "")) (not checked?))]]
  REPLACE [[  (if #f]])

byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC ${UNREACHED_PROVENANCE_SPEC}
  LABEL "provenance: harness-provenance-checked starts true, so unreached looks reached"
  FIND [[(define harness-provenance-checked #f)]]
  REPLACE [[(define harness-provenance-checked #t)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Every pass above has now run exactly once, so the accumulated total is
# final. Compared against the numbers declared at the top of this file --
# see EXPECTED_PASSES and EXPECTED_MUTATIONS, and the "TWENTY-NINE PASSES"
# header comment they restate -- so a whole pass, or a single mutation inside
# one, silently going missing is a build failure here rather than a stale
# comment nobody rereads.
byte_machine_mutation_totals(actual_passes actual_mutations)
if(NOT actual_passes EQUAL EXPECTED_PASSES OR NOT actual_mutations EQUAL EXPECTED_MUTATIONS)
  message(FATAL_ERROR
    "byte-machine-mutation: expected ${EXPECTED_PASSES} passes / "
    "${EXPECTED_MUTATIONS} mutations, got ${actual_passes} "
    "passes / ${actual_mutations} mutations. A byte_machine_mutation_run call -- "
    "a whole pass -- or a byte_machine_mutation() declaration within one was "
    "deleted, or one was added without updating the expected count at the top "
    "of this file. This is what notices a deleted pass group when every "
    "individual specification still reports green.")
endif()

message(STATUS
  "byte-machine-spec: scheme mutation suite complete (${actual_passes} passes, "
  "${actual_mutations} mutations)")
