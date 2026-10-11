# Proof that the Scheme harness's self-tests, and the Scheme lanes built on
# them, are not vacuous.
#
# The harness is the instrument every test in this project is measured with.
# If `check-equal` silently always returned true, the whole project would go
# green and stay green, and no test written with `check-equal` could notice. So
# each decision in the runner -- and then each decision in the source modules
# the lanes cover -- is broken in turn on a staged copy, and the lane that owns
# it must fail.
#
# HOW THE SUITE IS ORGANISED
#
# The suite runs in PASSES. A pass is one verify command, fixed for the whole
# pass, and the mutations judged against it; each mutation's SPEC names the
# program that command runs, and a mutation is witnessed only by the tests in
# that program. Pass numbers are labels, not a count: a retired pass's number
# is not reused (8, 18 and 19 are among the gaps), so EXPECTED_PASSES and
# EXPECTED_MUTATIONS, declared below, are what hold the totals. They are
# checked against byte_machine_mutation_totals' accumulated count once every
# pass has run. Nothing else can notice a pass deleted by hand: every remaining
# pass still reports green, and only the mutation count drops.
#
# Pass 1 runs the Chez self-tests lane against the runner.
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
# Passes 9 to 17 are the launcher's parse decisions: an unknown flag, a flag
# with no value, a single-valued flag repeated, a required flag unchecked in
# general, one entry dropped from each of required-flags' three members, and
# one entry dropped from each of single-valued-flags' two members. Each gets
# its own pass because each needs its own deliberately wrong invocation and a
# verify command fixed for the whole pass, the same constraint as passes 4 to 5.
#
# No pass covers a launch-directory matrix: library roots are absolute and
# source-directories is empty, so there is no resolution step for a launch
# directory to change.
#
# Pass 20 is the fingerprint algorithm's own decisions -- the +1 that keeps a
# leading zero byte significant, the seed, the multiplier, the modulus, and
# combine's order sensitivity.
#
# Pass 21 is the hex digit table. It sets no manifest, so provenance is
# skipped here exactly as it is for every other pass but 22 through 25: what
# actually catches the mutation is the self-tests' own "hex digits render
# lowercase" case, which check-equals fixed literals ("ff", "deadbeef", "0")
# rather than deriving its expectation from fingerprint.sls.
#
# Passes 22 through 25 are the provenance check and the reachability guard
# that closes over it: 22 is the comparison, 23 the missing-expectation
# branch, 24 the call site that reaches harness-verify-provenance! at all, and
# 25 harness-provenance-reachability-diagnosis itself, each witnessed through
# the exact-status helper so that exit 3 -- the refusal -- is the green
# baseline, exactly as passes 4 and 5 do for the launcher's guard-directory
# refusals. A third refusal -- a manifest naming an unreadable source -- has no
# mutation; see the stated blind spot recorded beside pass 23 below. Pass 24
# has its own pass rather than sharing pass 22's: see the detail beside its
# declaration for why the reachability guard makes WRONG_FP_FILE's exit-3
# baseline ambiguous for that one mutation and not for pass 22's own.
#
# Pass 26 is the aot launcher's own library-path pairing and its
# source-directories narrowing -- the mechanism that makes `mode=aot` an honest
# claim, the same argument pass 7 makes for `mode=source`. The objects it
# exercises are compiled once, from the staged tree, into this pass's own work
# directory, and reused by passes 27 to 29 below. The pairing is witnessed
# against a divergent library source planted where only an unpaired object
# directory would read it; the narrowing is EXPECT_SURVIVES, for the reason
# recorded beside it.
#
# Passes 27 to 29 are the aot-side launchers' three refusals -- chez-aot.ss's
# missing-program check, chez-aot.ss's dirty-source-guard check, and
# chez-compile.ss's unpaired-roots check -- each witnessed the same way passes
# 9 to 17 witness chez-source.ss's parse decisions: a deliberately wrong
# invocation through the exact-status helper, since a correctly set-up lane
# never reaches a refusal on its own. The flag-block copies both files carry
# from chez-source.ss are deliberately not re-proven here; each launcher's own
# header records what that leaves unwitnessed.
#
# Pass 30 is the two decisions inside harness-verify-provenance! that no
# one-source manifest can witness -- the split character and the combining
# order. Passes 22 to 25 pack their verify command through
# BYTE_MACHINE_EXPECT_COMMAND, whose | packing forbids a multi-source manifest,
# so this pass runs the lane command bare instead: its baseline is a passing
# provenance run (exit 0), and each catchable mutation turns that into the
# mismatch refusal (exit 3), with no wrapper needed. Its manifest deliberately
# excludes harness.sls, the file both mutations edit: with it included, an
# inert one-byte edit nowhere near either decision trips the identical
# refusal, so the catch would discriminate nothing.
#
# Pass 31 needs the opposite manifest. harness-provenance-failure!'s single
# shared exit line is reachable only from a run whose own provenance has
# already failed, so witnessing it means deliberately naming harness.sls -- the
# file this mutation edits -- in the very manifest that checks it.
# Self-reference is the mechanism here, not the mistake pass 30 avoids, and a
# decision that can be witnessed does not get an EXPECT_SURVIVES.
#
# Passes 32 onward each cover one source module or one lane. Each pass's own
# header (`--- Pass N: ...`) says which decisions it witnesses and why its
# verify command is the one that can see them.
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
# unverifiable baseline makes every mutation look caught. Pass 38's baseline
# additionally needs BYTE_MACHINE_GOLDEN_FILE (naming
# test/fixtures/generated-one-byte.golden.sls), which the same ctest
# registration supplies and which execute_process passes through unmodified
# to that pass's own verify command. Pass 49's baseline needs
# BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE (naming
# test/fixtures/generated-http-version.golden.sls) by the same mechanism, for
# the same reason.
cmake_minimum_required(VERSION 3.26)
# The totals every pass below must add up to; checked at the bottom of this
# file. Declared as constants rather than stated in prose, so the number a
# reader checks by eye is the number the suite enforces. Adding, retiring or
# moving a mutation changes EXPECTED_MUTATIONS; opening or retiring a pass
# changes EXPECTED_PASSES.
set(EXPECTED_PASSES 78)
set(EXPECTED_MUTATIONS 680)

# --- What an EXPECT_OUTPUT_MATCHES can and cannot say -----------------------
#
# EXPECT_OUTPUT_MATCHES is an UNANCHORED regex over the verify command's
# stdout+stderr, so a pin matching text that every failing run prints is a
# bare nonzero-exit catch wearing a disguise. Text that is unconditional in
# a harness lane: the FAIL-CONTEXT line's `backend=`, `mode=`, `os=`,
# `architecture=`, `machine-type=`, `artifacts=`, and the values of
# BYTE_MACHINE_TEST_NAME / BYTE_MACHINE_TEST_TMPDIR that
# byte_machine_add_test supplies (so `scheme`, `mutation`, `harness`, `cmake`
# and `direct` are all unconditional here); and the summary line's `status=`,
# `cases=`, `checks=`, `failures=`. The FAIL grammar is
#   byte-machine-harness: FAIL <group>.<case>: <what> -- <detail>
# so a sound pin resolves to exactly ONE (case, check) pair. MATCHES is a real
# regex: `(` `)` `.` are metacharacters, so a case name carrying a
# parenthesised section reference cannot be used as a tail unescaped.
#
# Each pin is judged against the captured output of every other mutation in
# its own lane, through byte_machine_mutation_verdict, counting matches with
# `.` spanning newlines. Where two mutants still cross-match, the only test
# that sorts them is whether their FAIL-record sets actually DIFFER. A pair is
# SUBSUMED when the narrow mutant's entire failure set is a subset of one
# sibling's, with byte-identical details: no text in the narrow mutant's
# output is absent from the broad one's, so no pin can separate them against
# these checks. Each subsumed pair is recorded at the narrow mutant's own pin,
# named by the LABEL of the mutation that contains it.
# Subsumption is a claim about the checks, not about the decisions: an
# attribution check (asserting the diagnostic that must be absent), a pair
# asserted as one value, or one fixture carrying both cases separates pairs
# that a subset test alone files as subsumed. Try those before recording one.
#
# Several Pass 35 pins carry a mutant's measured "got" fingerprint digest,
# because every fingerprint-affecting mutation in that lane prints the same
# EXPECTED golden. The two kinds of value are maintained differently. An
# expected golden is RECOMPUTED by re-running the lane; a "got" digest can only
# be RE-MEASURED, by applying that one mutation to a staged copy and reading
# what it printed. A re-baseline after an IR-encoding change that only
# recomputes the expected values leaves those pins pointing at digests no
# mutant produces, and the suite reports them as caught for the wrong reason.
#
# A clean sweep holds only for the mutants and checks that existed when it
# ran. A branch that measured these lanes against another tree re-runs the
# sweep after it merges.
include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")

get_filename_component(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(WORK_DIR "$ENV{BYTE_MACHINE_TEST_TMPDIR}")
else()
  set(WORK_DIR "${SOURCE_ROOT}/build/scheme-mutation")
endif()
set(STAGE_DIR "${WORK_DIR}/stage")

# The diagnostic census READS verify.sls and ir.sls
# as data, and under this suite it must read the STAGED tree -- the one the
# mutation was applied to. Set once, here, rather than per pass: every
# execute_process launched from this script inherits it, so the census sees the
# same text the lane is executing. Reading ${CMAKE_SOURCE_DIR} instead would make
# every source-side mutation report as caught while the census compared the
# pristine file against itself.
set(ENV{BYTE_MACHINE_SOURCE_ROOT} "${STAGE_DIR}/src")
# The rejections program reads verify-oracle.sls as a datum (the
# matcher-bytes prohibition) under BYTE_MACHINE_HARNESS_ROOT, for the same
# reason -- under this suite it must read the STAGED harness tree, so the
# matcher-bytes-in-the-oracle mutation (Pass 60) is seen. Set once here.
# matcher-bytes-in-the-oracle mutation (Pass 60) is seen. Set once here.
set(ENV{BYTE_MACHINE_HARNESS_ROOT} "${STAGE_DIR}/test/support/harness")

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

# src is staged whole: --library-root arguments throughout this file resolve
# every product library through it, and each library owns its own text
# directly, so staging the one directory every library lives under is enough.
set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers"
  "src" "test/common")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER test/support/harness/byte-machine/test/harness.sls)
set(CHEZ_ADAPTER test/support/harness/byte-machine/test/harness.sls)
set(LAUNCHER test/support/launchers/chez-source.ss)

# --- Assertions ------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
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
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a false check counts but records no failure"
  FIND [[      (begin (harness-record-failure! what "expected a true value") #f)))]]
  REPLACE [[      #f))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-equal compares identity instead of structure"
  FIND [[  (if (equal? actual expected)]]
  REPLACE [[  (if (eq? actual expected)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-not-equal is no longer the inverse"
  FIND [[  (if (equal? actual unexpected)]]
  REPLACE [[  (if (not (equal? actual unexpected))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-fail records nothing"
  FIND [[  (harness-record-failure! what detail)
  #f)]]
  REPLACE [[  #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: check-raises accepts a thunk that returned normally"
  FIND [[      ((eq? (car outcome) 'returned)]]
  REPLACE [[      ((eq? (car outcome) 'never-happens)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a failure never marks its case as failed"
  FIND [[  (set! harness-current-case-failed #t)]]
  REPLACE [[  (set! harness-current-case-failed #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a duplicate case id is silently accepted, making one registration unreachable"
  FIND [[      ((harness-member? id harness-case-ids)]]
  REPLACE [[      (#f]])

# harness-record-error! takes one argument where harness-record-failure! takes
# two, so the "case raised" label goes with the call it belongs to: keeping it
# would mutate the arity rather than the classification, and the arity violation
# is caught by a different assertion than the one this line claims to exercise.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a raise inside a case is recorded as an error rather than that case's failure"
  FIND [[                   (harness-record-failure!
                    "case raised"
                    (adapter-describe-condition (car (cdr outcome))))]]
  REPLACE [[                   (harness-record-error!
                    (adapter-describe-condition (car (cdr outcome))))]])

# harness-group and with-cleanup re-raise through identical text, so each of the
# two mutations below anchors on the line above the `if` -- the group-stack pop
# for one, the tail of the cleanup report for the other. They are two mutations,
# not one SITES 2 mutation, because a multi-site mutation is "caught" as soon as
# any one site is caught. harness-group pops its name off the stack *before* it
# re-raises, so deleting the re-raise still leaves every prefix correct; the
# group merely returns the condition instead of throwing it. The self-test "a
# group re-raises its body's condition" is what witnesses the group's re-raise
# on its own; a check that no prefix was left behind cannot.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a group swallows its body's condition instead of re-raising it"
  FIND [[    (set! harness-group-stack (cdr harness-group-stack))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[    (set! harness-group-stack (cdr harness-group-stack))
    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: with-cleanup swallows its body's condition instead of re-raising it"
  FIND [[             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: cleanup never runs"
  FIND [[    (let ((cleanup-outcome (guard (e (#t (list 'raised e)))
                             (list 'value (cleanup)))))]]
  REPLACE [[    (let ((cleanup-outcome (list 'value #f)))]])

# Anchored on the error and failure clauses alone, not on the `(cond` that
# opens harness-exit-status: the provenance clause sits first and outranks both,
# and a clause added above them the same way leaves these two lines unchanged.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
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
  FILE ${RUNNER} SPEC harness-self-tests.sps
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
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a probe inherits the ambient filter and skips its own cases"
  FIND [[  (set! harness-failures '())
  (set! harness-filter #f))]]
  REPLACE [[  (set! harness-failures '()))]])

# --- Empty selection -------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: an empty selection is not diagnosed"
  FIND [[    ((> case-count 0) #f)]]
  REPLACE [[    ((> case-count -1) #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a filtered-out run is diagnosed as having registered nothing"
  FIND [[    ((> skipped-count 0)]]
  REPLACE [[    (#f]])

# --- Output ----------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: probe output suppression is removed"
  FIND [[(define (harness-quiet?) (> harness-probe-depth 0))]]
  REPLACE [[(define (harness-quiet?) #f)]]
  EXPECT_SURVIVES
    "suppression changes only what is printed, never a counter or a status, so no assertion can observe it from inside the process; it is covered only by a manual check of the log, and its real cost -- a log that teaches readers to ignore FAIL lines -- is not machine-checkable")

# The other two print-only decisions, and the same argument. The adapter
# protocol exposes no output-capture service, and the runner may not reach
# past its protocol for one -- so the harness has no way to read
# back what it printed -- and this suite judges a mutation by the verify
# command's exit status, so an output difference is invisible to it whatever
# lane it runs.
# byte-machine.harness.verbose.chez.source closes the half that can be closed:
# it runs a real program with the variable set, so the path is executed and a
# break that raises is caught. What no layer checks is that the line was
# printed; that is a manual check.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: the value read for BYTE_MACHINE_TEST_VERBOSE is discarded"
  FIND [[    (set! harness-verbose (if (and v (not (string=? v ""))) #t #f)))]]
  REPLACE [[    (set! harness-verbose #f))]]
  EXPECT_SURVIVES
    "the verify command that judges this mutation does not set the variable, so both runs take the same branch -- harness-verbose ends up #f either way -- and the two are byte-identical, not merely indistinguishable by exit status. In a process that does set it the whole difference is one printed line per passing case: no counter, no case count, no status moves, and this suite judges by exit status. byte-machine.harness.verbose.chez.source proves the read happens and does not raise; that the value read is honoured is a manual check -- either self-tests lane with BYTE_MACHINE_TEST_VERBOSE=1 prints one pass line per case and none without it")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "runner: a passing case is never announced under verbose"
  FIND [[                 (if harness-verbose
                     (harness-say (string-append "byte-machine-harness: pass " id))))]]
  REPLACE [[                 #f)]]
  EXPECT_SURVIVES
    "the pass line is the only thing this branch produces, and a line that is not printed changes no counter and no status; byte-machine.harness.verbose.chez.source still proves the branch is reached and does not raise, but only a reader of the log can see the line itself, which is a manual check")

# --- The Chez adapter's export list ----------------------------------------

byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.sps
  LABEL "chez adapter: an exported adapter name is dropped"
  FIND [[    adapter-os adapter-architecture adapter-execution-mode]]
  REPLACE [[    adapter-architecture adapter-execution-mode]])

# Not every export is load-bearing, and pretending otherwise would be the more
# comfortable lie. harness-summary, harness-empty-selection-error, and
# harness-failure-context are used only from the runner section of harness.sls
# itself; an internal reference resolves against the definition, never through
# the export list. Dropping any of the three therefore changes nothing any lane
# can observe -- and with one adapter there is no second export list to keep in
# step with, so the export is a tripwire, not a contract. Recorded here so the
# blind spot is asserted rather than remembered, and so the day one of them
# acquires a caller outside the library, this line fails.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.sps
  LABEL "chez adapter: an export used only inside the runner section is dropped"
  FIND [[    harness-begin harness-finish harness-summary harness-exit-status]]
  REPLACE [[    harness-begin harness-finish harness-exit-status]]
  EXPECT_SURVIVES
    "harness-summary, harness-empty-selection-error, and harness-failure-context are referenced only from the runner section of harness.sls itself; an internal reference resolves inside the library whatever the export list says, so no lane imports the three and none can notice one going missing")

# Load-bearing, unlike the three names in the survivor above. The fingerprint
# library reads files itself (byte-machine test fingerprint), so
# harness-fingerprint-file does not reach adapter-file-bytes at all. The
# self-tests' own direct call -- reading the fingerprint sample fixture through
# it -- is the only thing that makes dropping this export visible.
byte_machine_mutation(
  FILE ${CHEZ_ADAPTER} SPEC harness-self-tests.sps
  LABEL "chez adapter: adapter-file-bytes is dropped from the export list"
  FIND [[    adapter-value->string adapter-describe-condition adapter-file-bytes]]
  REPLACE [[    adapter-value->string adapter-describe-condition]])

# No library is reached through an include, so the source path is not
# load-bearing: emptying it is deliberate narrowing, measured inert.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC harness-self-tests.sps
  LABEL "launcher: source-directories is left at Chez's default instead of emptied"
  FIND [[(source-directories '())]]
  REPLACE [[;; deleted]]
  EXPECT_SURVIVES
    "measured inert: no include form exists anywhere, library resolution runs through library-directories, and no lane's outcome differs between an empty source path and Chez's default; the line is kept as narrowing, not as behavior")

# --- The adapter's os-table -------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "adapter: an os-table row maps to the wrong name"
  FIND [[("osx" . "darwin")]]
  REPLACE [[("osx" . "linux")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "tarm64osx os")

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
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-empty-selection.sps")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" -E env
  "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name"
  "${CMAKE_COMMAND}"
  "-DBYTE_MACHINE_EXPECT_EXIT=2"
  "-DBYTE_MACHINE_EXPECT_COMMAND=${EMPTY_SELECTION_COMMAND}"
  -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-empty-selection.sps
  LABEL "runner: harness-begin ignores BYTE_MACHINE_TEST_FILTER"
  FIND [[  (set! harness-filter
        (harness-normalize-filter
         (adapter-environment-variable "BYTE_MACHINE_TEST_FILTER")))]]
  REPLACE [[  (set! harness-filter #f)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Third pass: the failure counter itself ---------------------------------
#
# Under the self-tests lane this mutation is UNCAUGHT: with
# harness-record-failure! not counting, a self-test that fails prints its FAIL
# line, marks its case failed, and leaves the exit status at 0. The mutation
# disarms the mechanism every assertion reports through as it commits the
# defect, so no suite written with `check` can witness it -- which is precisely
# the argument the bootstrap lane exists to answer. It judges the primitives
# with raw conditionals, counts its own failures, and exits by hand.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-bootstrap.sps
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
# No mutation pins the missing-required-flag refusal as a zero-argument
# invocation: the parse-decision passes below witness it with one mutation per
# required-flag entry, each strictly more precise than a zero-argument
# invocation. byte-machine.harness.launcher-no-program.chez.source still runs
# that invocation as an ordinary regression test.
#
# SPEC names the registered lane rather than a program basename, because the
# witness is a whole invocation and not a program: "passing" means the named
# program never ran.

byte_machine_mutation_reset()

string(JOIN "|" LAUNCHER_ABSENT_GUARD_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${ABSENT_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

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
# byte_machine_source_launcher_pass's header comment below for why the wrapper's
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
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${DIRTY_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

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
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${COMPILE_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

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
# reason this lane may call itself "source". The launcher's own header and
# test/CMakeLists.txt both assert that, and this pass is what checks it:
# `(library-directories (list library-root))` leaves every other test green,
# because no library root in this tree has an object beside its source for
# Chez to prefer.
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

# The pristine source goes down first, and the object is written by the
# compile below.
#
# The object is preferred only while it is not older than the .sls beside
# it -- and, transitively, while its imported fingerprint library also
# resolves to a non-stale object (the MEASURED note below). No STAGED file's
# mtime participates.
file(WRITE "${POISON_ROOT}/byte-machine/test/harness.sls" "${POISON_PRISTINE}")
file(WRITE "${POISON_SOURCE_DIR}/byte-machine/test/harness.sls" "${POISON_MUTATED}")

# harness.sls imports (byte-machine test fingerprint), so the object compiled
# below has a real library dependency. MEASURED, not assumed: Chez's staleness
# check on a compiled library is transitive -- an object is trusted only if
# every library it imports also resolves to a non-stale compiled object, not
# bare source. A minimal two-library reproduction confirms this directly: an
# importer's freshly compiled object is silently discarded in favour of its
# own pristine source whenever the imported library resolves to source only,
# even though the importer's own root is searched first and its object is
# not stale by itself. Giving fingerprint no compiled object anywhere in this
# pass's roots reproduces exactly that: the poisoned harness object is silently
# rejected and the baseline's pristine banner prints instead, so the mutation
# below goes UNCAUGHT. So POISON_ROOT is self-sufficient: a real, non-stale
# fingerprint object beside the poisoned harness object, compiled first so
# harness's object is never older than a library it depends on.
#
# One cross-copy invariant this relies on: the compile below resolves
# fingerprint's import from ${SOURCE_ROOT}/test/support/harness (the
# real source tree, via library-directories), while the verify run further
# down resolves the same import from POISON_ROOT's own copy. Compiling
# against one copy and running against another is safe here only because
# the file(READ)/file(WRITE) pair immediately below makes the two
# byte-identical by construction -- the same guarantee the pristine
# harness.sls copy above already depends on.
file(READ "${SOURCE_ROOT}/test/support/harness/byte-machine/test/fingerprint.sls"
     POISON_FINGERPRINT_PRISTINE)
file(WRITE "${POISON_ROOT}/byte-machine/test/fingerprint.sls" "${POISON_FINGERPRINT_PRISTINE}")

set(POISON_COMPILE_SCRIPT "${POISON_DIR}/compile-poisoned-object.ss")
file(WRITE "${POISON_COMPILE_SCRIPT}"
";; Written by SchemeMutationSuite.cmake, never committed. Compiles the
;; poisoned adapter copy into the library root that holds the pristine source,
;; so a launcher which stops pairing that root with an empty object directory
;; loads the object instead of the source. This is a per-runtime staging file,
;; not harness text, so naming Chez here is allowed.
;;
;; Both halves of the poison are read from the source tree, not from the stage:
;; the two are byte-identical by construction, and reading the stage would make
;; this pass depend on the previous pass having left it in place.
(library-directories (list (cons \"${SOURCE_ROOT}/test/support/harness\" \"${POISON_GUARD_DIR}\")))
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
  "--object-guard" "${POISON_GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

# EXPECT_OUTPUT_MATCHES turns the paragraph above's claim -- that the mutated
# run "says so in its banner, its FAIL-CONTEXT line, and its summary" -- into
# something this suite enforces rather than merely asserts in prose. The
# sentinel is the literal string written into POISON_REPLACE above, so a rc
# that happens to be nonzero for some other reason (a staging error, an
# unrelated crash) is reported caught-for-the-wrong-reason instead of caught.
byte_machine_mutation(
  FILE ${LAUNCHER}
  SPEC "harness-self-tests.sps against a library root holding a compiled object"
  LABEL "launcher: the library root is no longer paired with the object guard"
  FIND [[(library-directories
 (map (lambda (root) (cons root object-guard-dir)) library-roots))]]
  REPLACE [[(library-directories library-roots)]]
  EXPECT_OUTPUT_MATCHES "POISONED-FROM-OBJECT")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 9 to 17: the launcher's parse decisions -------------------------
#
# Deleting a refusal does not produce a wrong answer; it produces an invocation
# that is accepted and then fails somewhere else, or does not fail at all. Two
# of these mutations leave the launcher reaching malformed input and dying at
# 255 rather than 2, which the exact-status helper reports as out-of-vocabulary.
# That is still caught, and it is the honest outcome: the refusal exists exactly
# so that malformed input is named rather than stumbled over.

set(LAUNCHER_BASE_ARGS
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# byte_machine_source_launcher_pass(<lane> <label> <find> <replace>
#                                   <expect_output_matches> <arg>...)
#
# One pass: point the verify command at a deliberately wrong invocation, declare
# one mutation, run it. Defined here rather than inlined nine times because the
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
# Scheme: a REPLACE that opens a line comment and swallows a list's closing
# parens (the hazard recorded next to the --library-root mutation below) is
# caught at exit 255 on "Exception in read: ..." rather than on the refusal it
# names. Every value passed here is captured from a real staged run of the
# mutation it guards, not guessed.
#
# The reset, the declaration and the run all happen inside this function on
# purpose. byte_machine_mutation_reset and byte_machine_mutation both write the
# counter with PARENT_SCOPE, so they agree only while they share a caller;
# splitting them across this boundary would leave the run seeing a count from
# somewhere else.
function(byte_machine_source_launcher_pass lane label find replace expect_output_matches)
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

byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-unknown-flag.chez.source
  "launcher: an unrecognised flag is accepted"
  [[        ((not (member (car rest) known-flags))]]
  [[        (#f]]
  "bootstrap: failures=0"
  "--librarie-root" "${STAGE_DIR}/test/support/harness" ${LAUNCHER_BASE_ARGS})

byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-missing-value.chez.source
  "launcher: a flag with no value is accepted"
  [[        ((null? (cdr rest))]]
  [[        (#f]]
  "Exception in cddr"
  ${LAUNCHER_BASE_ARGS} "--library-root")

byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: a single-valued flag may be given twice"
  [[   (if (> (length (flag-values flag)) 1)]]
  [[   (if #f]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

# SPEC must name a lane `ctest -N` actually lists: it is the transcript name a
# real invocation is judged under, and once a verify command is set (as every
# pass in this file does), SPEC is otherwise ignored -- so a value that names
# no real lane is checked by nothing, and nothing notices. This pass and the
# entry-specific one below that drops --library-root from required-flags both
# run the identical missing-library-root invocation, so both are witnessed by
# the same registered lane, byte-machine.harness.launcher-no-library-root.chez.source.
# A unique SPEC per mutation would name a lane that does not exist; the
# disambiguation belongs in LABEL instead, which is free text with no such
# constraint. This pass witnesses the launcher's decision 2 check itself (the
# `if` that runs once per required flag, so it breaks identically no matter
# which flag the invocation happened to omit -- library-root is only a
# convenient invocation to reuse), while the pass below witnesses
# required-flags' library-root *entry* specifically, i.e. whether the flag is
# still in the list decision 2 walks at all. Two different lines, two different
# mutations, one shared witness.
byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: a missing required flag is not noticed (decision 2's own check, general across every entry; reuses the no-library-root invocation below only for convenience)"
  [[   (if (null? (flag-values flag))]]
  [[   (if #f]]
  [[library \(byte-machine test harness\) not found]]
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# Three more: one per entry in required-flags. The check above is one decision,
# but the list it walks is three, and an entry dropped from it is invisible to
# every invocation except the one omitting that flag.

byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-no-program.chez.source
  "launcher: --program is dropped from required-flags"
  [[  (list "--program"]]
  [[  (list ;; --program removed by mutation]]
  "Exception in car"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}")

byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-no-object-guard.chez.source
  "launcher: --object-guard is dropped from required-flags"
  [[        "--object-guard"]]
  [[        ;; --object-guard removed by mutation]]
  "Exception in car"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# --library-root is the last entry in required-flags, so its source line ends
# with two closing parens -- the list's and the define's -- rather than one.
# A FIND that matches only the flag's text leaves both dangling after a REPLACE
# that opens a line comment: the comment swallows "))" too, so the staged file
# is not readable Scheme and dies with a read error at exit 255 rather than the
# launcher's own required-flag refusal -- caught, but for the wrong reason, and
# witnessing nothing about the decision this pass names. The FIND below
# includes the trailing "))" so the REPLACE can close the list itself.
# Whichever entry ends up last in required-flags after a reorder or a fourth
# addition inherits this hazard and needs the same treatment.
byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: --library-root is dropped from required-flags"
  [[        "--library-root"))]]
  [[        ;; --library-root removed by mutation
        ))]]
  [[library \(byte-machine test harness\) not found]]
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")

# Two more, for single-valued-flags. Only this pass exercises --object-guard as
# a repeated flag: the general check just above is witnessed only through
# --program (LAUNCHER_BASE_ARGS already carries one --object-guard, so this
# pass repeats it rather than adding a second fixture guard directory --
# decision 3 counts occurrences, not distinct values). Dropping --object-guard
# from single-valued-flags specifically, leaving the check itself and
# --program's membership in the list untouched, is invisible to every
# invocation but this one.
byte_machine_source_launcher_pass(
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
# parens -- the same position that made --library-root's required-flags
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
byte_machine_source_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: --program is dropped from single-valued-flags (reuses the launcher-repeated-flag invocation, which already repeats --program)"
  [[(define single-valued-flags
  (list "--object-guard" "--program"))]]
  [[(define single-valued-flags
  (list "--object-guard"))]]
  "bootstrap: failures=0"
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

# --- Pass 20: the fingerprint algorithm --------------------------------------
#
# The self-tests assert measured literals, so any change to seed, multiplier,
# modulus, the +1, or the digit table moves at least one of them.

set(FINGERPRINT test/support/harness/byte-machine/test/fingerprint.sls)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

byte_machine_mutation_reset()

# Without the +1 a NUL contributes nothing, and the three leading-zero cases
# collapse into one value. This is the only mutation here that a fixed set of
# literals could survive if the literals happened not to include a NUL --
# which is why they do.
byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: leading zero bytes stop being significant"
  FIND [[                           (+ (bytevector-u8-ref bv i) 1))]]
  REPLACE [[                           (bytevector-u8-ref bv i))]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: the seed changes"
  FIND [[(define harness-fingerprint-seed 14695981039346656)]]
  REPLACE [[(define harness-fingerprint-seed 14695981039346657)]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: the multiplier changes"
  FIND [[(define harness-fingerprint-multiplier 1000003)]]
  REPLACE [[(define harness-fingerprint-multiplier 1000033)]])

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: the modulus changes"
  FIND [[(define harness-fingerprint-modulus 2305843009213693951) ; 2^61 - 1]]
  REPLACE [[(define harness-fingerprint-modulus 2305843009213693907)]])

# Combining becomes a sum, so order stops mattering and the two combine cases
# collapse to one value.
byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: combining stops being order sensitive"
  FIND [[              (modulo (+ (* h harness-fingerprint-multiplier) (+ (car rest) 1))]]
  REPLACE [[              (modulo (+ h (+ (car rest) 1))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 21: the hex rendering table -----------------------------------------
#
# MEASURED. No manifest is set, so provenance is skipped here
# exactly as it is for every other pass but 22 through 25 below:
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
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

byte_machine_mutation(
  FILE ${FINGERPRINT} SPEC harness-self-tests.sps
  LABEL "fingerprint: hex digits become uppercase"
  FIND "${HEX_MUTATION_FIND}"
  REPLACE "${HEX_MUTATION_REPLACE}"
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "hex digits render lowercase: 255")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 22 and 23: the provenance check itself ----------------------------
#
# Wrapped in the exact-status helper so exit 3 -- the refusal -- is the green
# baseline, exactly as passes 4 and 5 do for the launcher. A mutation that makes
# the check more permissive drops the inner status to 0, the wrapper reports
# nonzero, and the mutation is caught. Passes 24 and 25 below cover the rest of
# the provenance check; each says why it needs a pass of its own.
#
# THE MANIFEST NAMES ONE SOURCE ON PURPOSE
#
# BYTE_MACHINE_EXPECT_COMMAND packs its argument vector with `|`, which is also
# the manifest separator, so a two-element manifest would be unpacked as two
# arguments. One source is enough: these passes test whether the check runs and
# is consulted, not how values combine, which pass 20 covers. Passes 24 and 25
# keep the same one-source manifest for the same reason.

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

set(WRONG_FP_FILE "${WORK_DIR}/wrong.fingerprint")
file(WRITE "${WRONG_FP_FILE}" "not-a-fingerprint")

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_MISMATCH_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WRONG_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

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

# "provenance: harness-begin stops checking at all" does not share this pass's
# WRONG_FP_FILE verify command. With the call removed,
# harness-provenance-checked never becomes #t, and the reachability guard
# (harness-provenance-reachability-diagnosis in
# test/support/harness/byte-machine/test/harness.sls) refuses with status 3 of
# its own accord -- the same number WRONG_FP_FILE's mismatch produces, for an
# unrelated reason. ByteMachineExpectExit compares only the number, so both
# baseline and mutant would satisfy EXPECT_EXIT 3 and the wrapper would report
# "exited as expected" either way. Pass 24 below gives that mutation a baseline
# the guard cannot also produce.

# Pass 23: the same wrapper, but the expectation file does not exist, so the
# refusal under test is the missing-expectation branch rather than the
# comparison. Its mutation leaves the guard `(not expected)` matching -- so
# there is no fallthrough to the next clause -- and changes only what the
# matched branch returns: silently #f instead of the diagnosis string.
# harness-verify-provenance! reads that #f as nothing to report and lets the
# run proceed as though the missing expectation had been verified.
#
# Measured: caught, but not by exiting 0. The self-tests' own
# "a missing expectation is its own diagnosis" case calls
# harness-provenance-diagnosis(#f, ...) directly and checks that a diagnosis
# comes back; with the branch mutated that check fails outright -- an
# ordinary comparison -- and the whole run reports byte-machine-harness
# status 1, not 3. The exact-status wrapper below compares that 1 against the
# declared EXPECT_EXIT of 3 and reports the mismatch. Both routes are a
# failed comparison; neither is a raise.
#
# The mutation edits the branch, not the guard. Mutating `(not expected)` to
# `(and #f expected)` would never match, so control would fall through to
# `(string=? expected computed)` with expected still #f. string=? on a
# non-string is a type violation, caught by Chez's top-level handler killing
# the process at exit 255 -- outside the harness's own status vocabulary, and
# before a single self-test case runs -- rather than by the assertion naming
# this decision. AGENTS.md prefers a failed comparison over a raise.
byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_ABSENT_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${WORK_DIR}/never-produced.fingerprint"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

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
# source -- has no mutation here. Making it witnessable would need an
# expectation crafted to equal what the mutant computes after the read fails,
# which is a value with no meaning outside that mutation. It is covered by its
# registered lane, byte-machine.harness.provenance-missing-body.chez.source,
# and this is recorded rather than papered over with an EXPECT_SURVIVES, which
# AGENTS.md reserves for the genuinely unwitnessable.

# --- Pass 24: the call site, witnessed against a baseline the guard cannot
# also satisfy -----------------------------------------------------------
#
# "provenance: harness-begin stops checking at all", with a baseline of its
# own. WRONG_FP_FILE cannot be reused: it makes the unmutated lane's correct
# behaviour exit 3, and this mutation's broken behaviour *also* exits 3 (the
# reachability guard's own refusal), so a wrapper that only compares the exit
# number cannot tell them apart -- both read as "exited 3 as expected." Giving
# the lane an expectation it actually matches makes the unmutated baseline
# exit 0 instead, which the guard cannot produce (harness-provenance-checked is
# #t by the time harness-summary reads it, so the guard stays quiet and the
# self-tests' own pass/fail is what decides). The mutation still removes the
# call, so harness-provenance-checked stays #f, the guard still refuses, and
# the lane exits 3 -- cleanly distinct from the 0 baseline.
#
# THE MANIFEST NAMES ONE SOURCE, AS ABOVE, AND ITS EXPECTATION IS COMPUTED, NOT
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
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${CORRECT_FP_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  RESULT_VARIABLE fp_rc
  OUTPUT_VARIABLE fp_out
  ERROR_VARIABLE fp_err)
if(NOT fp_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: could not compute pass 24's baseline fingerprint "
    "(exit ${fp_rc}): ${fp_out}${fp_err}")
endif()

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_UNCALLED_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${CORRECT_FP_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

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

# --- Pass 25: the reachability guard itself -------------------------------
#
# harness-unreached-provenance.sps (test/support/harness/self/) deliberately
# never calls harness-begin, so its lane's baseline already exits 3 through
# the guard alone -- no WRONG_FP_FILE trick needed, and no
# BYTE_MACHINE_EXPECT_FINGERPRINT_FILE either, since nothing in this lane's
# reachable code ever compares a fingerprint. Two mutations, because
# harness-provenance-reachability-diagnosis's rule ("manifest and not
# checked?") has two halves that fail independently: the diagnosis can stop
# firing, or checked? can stop meaning what its name says.
# Either one drops the baseline's 3 to 0, which EXPECT_EXIT catches cleanly --
# unlike pass 24, nothing else in this lane's execution can also produce 3, so
# no separate baseline is needed here.
set(UNREACHED_PROVENANCE_SPEC byte-machine.harness.unreached-provenance.chez.source)

byte_machine_mutation_reset()

string(JOIN "|" PROVENANCE_REACHABILITY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-unreached-provenance.sps")

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

# --- Pass 26: the aot launcher's library-path pairing ------------------------
#
# Measured against the shipped lane. The objects are compiled once, here, from
# the staged tree; the plant is a byte-divergent copy of the harness library
# dropped at its library-relative path inside the object directory, touched
# newer than the objects. Under the shipped pairing the plant sits in a
# directory Chez consults only for objects and is never read; under the
# unpaired shape every object directory is also a source directory, Chez finds
# the newer source, re-expands it, and load-program refuses the different
# compilation instance at 255 -- outside the status vocabulary, reported as a
# process that died, which is the honest shape of this defect.
byte_machine_mutation_reset()

set(AOT_PASS_DIR "${WORK_DIR}/aot-pairing")
file(MAKE_DIRECTORY "${AOT_PASS_DIR}/harness" "${AOT_PASS_DIR}/src"
     "${AOT_PASS_DIR}/source-guard")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/chez-compile.ss"
          --library-root "${STAGE_DIR}/test/support/harness"
          --object-dir "${AOT_PASS_DIR}/harness"
          --library-root "${STAGE_DIR}/src"
          --object-dir "${AOT_PASS_DIR}/src"
          --program "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps"
          --output "${AOT_PASS_DIR}/harness-bootstrap.so"
  RESULT_VARIABLE aot_compile_rc)
if(NOT aot_compile_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 26 could not compile its artifacts (rc "
    "${aot_compile_rc}); nothing this pass reports would mean anything.")
endif()
file(MAKE_DIRECTORY "${AOT_PASS_DIR}/harness/byte-machine/test")
file(COPY_FILE
  "${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls"
  "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls")
file(APPEND "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls"
  "\n;; planted: only an unpaired library path can read this file\n")
file(TOUCH "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env" "BYTE_MACHINE_EXECUTION_MODE=aot" "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script"
  "${STAGE_DIR}/test/support/launchers/chez-aot.ss"
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--object-dir" "${AOT_PASS_DIR}/src"
  "--source-guard" "${AOT_PASS_DIR}/source-guard"
  "--program" "${AOT_PASS_DIR}/harness-bootstrap.so")

# EXPECT_STATUS and EXPECT_OUTPUT_MATCHES are exactly what this pass's own
# verify command produces against the mutated launcher: rc 255 and, on stdout,
# "Exception: loading .../harness.sls yielded a different compilation
# instance of (byte-machine test harness) from that required by compiled
# program" -- Chez's own load-program refusal, reached because the plant is
# the newer file in a directory the mutated library-directories call also
# treats as a source directory. EXPECT_OUTPUT_MATCHES anchors on the stable
# substring rather than the full sentence, which embeds this machine's
# absolute build path.
byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC byte-machine.harness.self.chez.aot
  LABEL "chez-aot launcher: the source guard is unpaired from the object directories"
  FIND [[(library-directories
 (map (lambda (dir) (cons source-guard-dir dir)) object-dirs))]]
  REPLACE [[(library-directories object-dirs)]]
  EXPECT_STATUS 255
  EXPECT_OUTPUT_MATCHES "different compilation instance")

# FIND carries its own trailing newline: the bare pattern also opens the "WHY
# source-directories IS ALSO EMPTIED" paragraph's own worked example in
# chez-aot.ss ("run once with (source-directories '()) and once left at Chez's
# unset default"), so without the newline the pattern matches twice -- code
# once, prose once -- and the SITES-count guard in byte_machine_mutation
# refuses it (found 2, expected 1) rather than silently mutating the comment
# along with the code. The comment's occurrence is followed by " and", never
# by end-of-line, so anchoring on the trailing newline is precise, not merely
# convenient.
byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC byte-machine.harness.self.chez.aot
  LABEL "chez-aot launcher: source-directories is not emptied"
  FIND [[(source-directories '())
]]
  REPLACE [[(source-directories (list "."))
]]
  EXPECT_SURVIVES
    "measured inert and re-measured through the shipped lane: library resolution runs through library-directories, no file in the tree includes another, so this line narrows nothing reachable today; kept in the launcher because it costs one line and guards a future load or include added to the launcher itself. Reopening condition: a Chez that re-resolves a compiled library's sources at load time.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Passes 27 to 29: the aot-side launchers' own refusals -------------------
#
# The same argument as passes 9-17: a correctly set-up lane never reaches a
# refusal, so only a deliberately wrong invocation can notice one being
# deleted. Three passes, matching the three registered refusal lanes -- the
# decisions these files do not copy from chez-source.ss. The verbatim flag-block copies
# are deliberately not re-proven here; the launchers' own headers record
# what is and is not witnessed per copy.
#
# Unlike byte_machine_source_launcher_pass above, EXPECT_STATUS and
# EXPECT_OUTPUT_MATCHES are optional keywords here rather than a fixed
# positional parameter, so the helper accepts an invocation carrying neither,
# either, or both. cmake_parse_arguments pulls them out of ARGN
# ahead of the launcher's own command-line arguments -- none of which is
# spelled "EXPECT_STATUS" or "EXPECT_OUTPUT_MATCHES" -- and each is forwarded
# to byte_machine_mutation only when given, the same CMP0174-motivated
# reasoning as byte_machine_add_exit_code_test's WORKING_DIRECTORY
# (ByteMachineExpectExit.cmake): a keyword forwarded with an empty value
# would parse as though it were never given at this project's 3.26 floor, but
# silently, since CMP0174 does not warn about it before 3.31.
#
# The reset, the declaration and the run all happen inside this function on
# purpose, the same reason byte_machine_source_launcher_pass's header gives.
function(byte_machine_launcher_file_pass launcher_file lane label find replace)
  cmake_parse_arguments(pass "" "EXPECT_STATUS;EXPECT_OUTPUT_MATCHES" "" ${ARGN})

  byte_machine_mutation_reset()

  string(JOIN "|" packed
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/${launcher_file}"
    ${pass_UNPARSED_ARGUMENTS})

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${CMAKE_COMMAND}"
    "-DBYTE_MACHINE_EXPECT_EXIT=2"
    "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
    -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

  set(narrow_args "")
  if(DEFINED pass_EXPECT_STATUS)
    list(APPEND narrow_args EXPECT_STATUS "${pass_EXPECT_STATUS}")
  endif()
  if(DEFINED pass_EXPECT_OUTPUT_MATCHES)
    list(APPEND narrow_args EXPECT_OUTPUT_MATCHES "${pass_EXPECT_OUTPUT_MATCHES}")
  endif()

  byte_machine_mutation(
    FILE ${launcher_file} SPEC "${lane}"
    LABEL "${label}"
    FIND "${find}"
    REPLACE "${replace}"
    ${narrow_args})

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

# Narrowed from what a real staged run printed, as pass 26's pins are.
# EXPECT_STATUS is not used: this pass runs through ByteMachineExpectExit.cmake,
# same as every byte_machine_source_launcher_pass call above, and that
# wrapper's own message(FATAL_ERROR) always exits 1 on a non-matching real
# status -- 255 included -- so EXPECT_STATUS could only ever see 0 or 1 here
# and would narrow nothing; passes 9-17's header makes the identical point.
# What is real evidence is the wrapper's echoed command output: with the
# existence check gone, load-program itself is handed a path that is not
# there and Chez's own file layer refuses it directly --
# "Exception in load-program: failed for .../no-such-program.so: no such
# file or directory", observed on the wrapper's echoed stdout.
byte_machine_launcher_file_pass(
  test/support/launchers/chez-aot.ss
  byte-machine.harness.chez-aot-launcher-missing-program.chez.aot
  "chez-aot launcher: a missing compiled program is accepted"
  [[(if (not (file-exists? program))]]
  [[(if #f]]
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--source-guard" "${AOT_PASS_DIR}/source-guard"
  "--program" "${AOT_PASS_DIR}/no-such-program.so"
  EXPECT_OUTPUT_MATCHES "Exception in load-program")

# Narrowed from a real run, as above; no EXPECT_STATUS, for the same wrapper
# reason given above the missing-program pass. Reusing the harness object
# directory as the guard (see the rationale where this pass is called)
# reproduces pass 26's unpaired scenario by a different route: the guard is
# the harness's object directory, so once the emptiness check stops blocking
# it, that same directory's library-directories pairing makes it a source
# directory too, and Chez's load-program hits the identical "different
# compilation instance" refusal pass 26's pairing mutation does -- two
# different deleted checks, coincident only in this fixture because both
# ultimately leave the harness object directory readable as a source directory.
byte_machine_launcher_file_pass(
  test/support/launchers/chez-aot.ss
  byte-machine.harness.chez-aot-launcher-dirty-source-guard.chez.aot
  "chez-aot launcher: a dirty source guard is accepted"
  [[(if (not (null? (directory-list source-guard-dir)))]]
  [[(if #f]]
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--object-dir" "${AOT_PASS_DIR}/src"
  "--source-guard" "${AOT_PASS_DIR}/harness"
  "--program" "${AOT_PASS_DIR}/harness-bootstrap.so"
  EXPECT_OUTPUT_MATCHES "different compilation instance")

# Narrowed from a real run, as above; no EXPECT_STATUS, for the same wrapper reason
# given above the missing-program pass. R6RS's map requires its argument
# lists to be the same length; with the pairing-count refusal gone, (map
# cons library-roots object-dirs) is handed a 2-element and a 1-element list
# and Chez's own map refuses them directly, observed on the wrapper's echoed
# stdout as "Exception in map: lists (...) and (...) differ in length".
byte_machine_launcher_file_pass(
  test/support/launchers/chez-compile.ss
  byte-machine.harness.chez-compile-launcher-unpaired-roots.chez.aot
  "chez-compile launcher: unpaired roots are accepted"
  [[(if (not (= (length library-roots) (length object-dirs)))]]
  [[(if #f]]
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps"
  "--output" "${AOT_PASS_DIR}/unpaired.so"
  EXPECT_OUTPUT_MATCHES "Exception in map")

# --- Pass 30: the provenance decisions a one-source manifest cannot witness --
#
# Passes 22-25 pack their verify commands through BYTE_MACHINE_EXPECT_COMMAND,
# whose | packing forbids a multi-source manifest -- their manifests name one
# source on purpose, so the split character and the combining order have no
# witness there. This pass runs the lane command bare: its baseline is
# a PASSING provenance run (exit 0), and each catchable mutation turns that
# into the mismatch refusal (exit 3), so no wrapper is needed and the
# two-source manifest rides in an ordinary env entry.
#
# NEITHER MANIFEST FILE IS ONE THIS PASS MUTATES
#
# harness-verify-provenance! lives in harness.sls, the file both mutations
# below edit. With harness.sls one of the fingerprinted sources, editing it at
# all fails the comparison before the mutated logic is even relevant, so
# EXPECT_STATUS 3 would catch "harness.sls changed", not the decision each
# mutation names. A control shows it: an inert trailing space added to an
# unrelated comment at the top of the file, nowhere near provenance, split, or
# combine, trips the identical PROVENANCE-ERROR refusal. A catch that catches
# anything discriminates nothing (AGENTS.md). This pass fingerprints
# fingerprint.sls and harness-self-tests.sps instead -- two real files a real
# lane's manifest would name, neither touched by any mutation below -- so a
# mismatch can only come from the split or combine logic itself. Pass 31 needs
# the opposite choice for the one decision this manifest shape cannot reach.
byte_machine_mutation_reset()

set(PROVENANCE_MANIFEST
  "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls|${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")
set(PROVENANCE_EXPECT_FILE "${WORK_DIR}/w9-split-combine.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${PROVENANCE_EXPECT_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
          "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps"
  RESULT_VARIABLE w9_expect_rc)
if(NOT w9_expect_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 30 could not compute its two-source "
    "expectation (rc ${w9_expect_rc}). The expectation must come from the "
    "staged copies -- the stage is what the run reads -- so nothing this "
    "pass reports would mean anything without it.")
endif()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${PROVENANCE_MANIFEST}"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${PROVENANCE_EXPECT_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

# The manifest arrives |-joined. Split on anything else and the whole
# two-source string is one path naming no file, so the run refuses with the
# unreadable-source diagnosis -- still 3, still caught, and the label says
# which decision died. Measured: "PROVENANCE-ERROR cannot read
# <fingerprint.sls's path>|<harness-self-tests.sps's path>, which this run
# is supposed to have executed." -- the | that should have separated two
# paths is embedded in the one bogus path the comma-split produces.
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: the manifest is split on the wrong character"
  FIND [[        (let loop ((rest (harness-split raw #\|)) (acc '()))]]
  REPLACE [[        (let loop ((rest (harness-split raw #\,)) (acc '()))]]
  EXPECT_STATUS 3
  EXPECT_OUTPUT_MATCHES "PROVENANCE-ERROR cannot read")

# Combining is order-sensitive by design (pass 20 witnesses that), so
# accumulating in reverse computes a different digest over the same two
# fingerprints -- both individually unchanged, since neither manifest file
# is edited by this mutation, so the mismatch below can only come from the
# order they were combined in, not from either file's own bytes. Measured:
# "PROVENANCE-ERROR fingerprint mismatch: the build expected <combined
# forward> but this run computed <combined reversed>."
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: the manifest digests combine in reverse order"
  FIND [[                               (harness-fingerprint-combine (reverse acc)))))]]
  REPLACE [[                               (harness-fingerprint-combine acc))))]]
  EXPECT_STATUS 3
  EXPECT_OUTPUT_MATCHES "PROVENANCE-ERROR fingerprint mismatch")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 31: the provenance exit constant, witnessed through a deliberately
# self-referential manifest --------------------------------------------------
#
# The one decision pass 30 cannot carry: harness-provenance-failure!'s single
# shared exit line, (adapter-exit harness-status-provenance). Wrong that
# constant and a provenance failure exits indistinguishably from an
# assertion failure -- the whole reason status 3 was reserved -- but under
# pass 30's own manifest (fingerprint.sls and harness-self-tests.sps,
# neither edited by this mutation) provenance keeps succeeding, so the line
# is never reached there: a passing baseline is byte_machine_mutation_run's
# own precondition, no pass may deliberately fail provenance, and a mutation
# whose only effect follows a failure that never happens would report as an
# unwitnessed EXPECT_SURVIVES.
#
# The way to reach the line is the manifest pass 30 deliberately avoids: name
# harness.sls itself -- the file this mutation, like both of pass 30's,
# edits. Pass 30 must avoid that self-reference (its header records the
# control that shows why); here it is the mechanism. Any edit to harness.sls
# staled against a manifest that fingerprints harness.sls fails provenance
# on its own -- exactly a run whose own text no longer matches what the
# build measured, which is what a real stale artifact looks like, not a
# contrived path to this line. That failure calls
# harness-provenance-failure!, which reaches the mutated line and exits
# harness-status-failed (1) instead of harness-status-provenance (3) -- the
# summary text printed just above the exit call still names status 3, built
# from the untouched constant, but the process's actual exit code is 1, so a
# caller reading only the exit status draws exactly the
# indistinguishable-from-an-assertion-failure conclusion this constant
# exists to prevent.
#
# AGENTS.md: a decision that can be witnessed does not get an EXPECT_SURVIVES.
byte_machine_mutation_reset()

set(PROVENANCE_EXIT_MANIFEST
  "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls|${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls")
set(PROVENANCE_EXIT_EXPECT_FILE "${WORK_DIR}/w9-exit-constant.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${PROVENANCE_EXIT_EXPECT_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls"
  RESULT_VARIABLE w9_exit_expect_rc)
if(NOT w9_exit_expect_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 31 could not compute its two-source "
    "expectation (rc ${w9_exit_expect_rc}). The expectation must come from "
    "the staged copies -- the stage is what the run reads -- so nothing "
    "this pass reports would mean anything without it.")
endif()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${PROVENANCE_EXIT_MANIFEST}"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${PROVENANCE_EXIT_EXPECT_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

# Measured: the mutated harness.sls fails its own fingerprint comparison --
# "PROVENANCE-ERROR fingerprint mismatch: the build expected <digest of the
# pristine pair> but this run computed <digest with the mutated harness.sls>"
# -- and the process exits 1 (harness-status-failed, what the mutation put
# in the exit call), not 3 (harness-status-provenance, what the unmutated
# line calls and what the summary text printed just above it still names).
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: a provenance failure exits as an assertion failure"
  FIND [[  (adapter-exit harness-status-provenance))]]
  REPLACE [[  (adapter-exit harness-status-failed))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "PROVENANCE-ERROR fingerprint mismatch")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 32: the runtime parser loop ----------------------------------------
#
# runtime-tests.sps drives the parser lifecycle over a hand-built compiled-
# machine stub, checking each decision directly; this pass proves those checks
# are not vacuous by breaking the decision underneath and requiring the checks
# to notice. The verify command uses both library roots -- the harness and
# src -- an empty object guard, and the runtime program. The baseline runs
# unmutated and exits 0, so a mutation that breaks a decision turns that into
# an assertion failure (exit 1).

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/runtime-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: advance does not consume the byte"
  # FIND and REPLACE move in LOCKSTEP: this is a swap pair with the reexecute
  # tail, and a REPLACE that dropped the position-kind argument would fail as an
  # arity error rather than as the consumed-count defect the pin names. The
  # tail lives once, in `route-byte-step!`, shared by the dispatch and
  # accumulate arms: one decision, with each arm's CALL separately mutable.
  FIND [[              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop (+ pos 1) 'boundary))]]
  REPLACE [[              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop pos 'byte))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one-byte parser lifecycle\\.the accepted byte stops after consuming one byte: consumed")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: need-input becomes a spurious stop"
  # Anchored on the DISPATCH arm: the accumulate arm yields need-input at the
  # end of a slice in the same shape, so a bare FIND matches twice. The two
  # guards are separate decisions about two kinds; only their tails coincide.
  FIND [[            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos]]
  REPLACE [[            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'stopped pos]]
  EXPECT_STATUS 1
  # Not bare "need-input": that word also appears in the DETAIL of unrelated
  # runtime mutants ("expected need-input, got stopped"), so it is satisfied
  # by failures it does not name. Measured: this case and check.
  EXPECT_OUTPUT_MATCHES "an empty slice needs input and reports no result yet: status")

# The stream-offset increment is a decision distinct from the pos cursor: the
# accept case pins it to 1, the reject case to 0, so a no-op increment reddens
# only the accept case (consumed and next stay correct).
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: advance does not increment the stream offset"
  # The increment lives once, in `route-byte-step!`, for both byte-consuming
  # kinds.
  FIND [[              (parser-set-offset! parser (+ 1 (parser-offset parser)))
              (loop (+ pos 1) 'boundary))]]
  REPLACE [[              (parser-set-offset! parser (parser-offset parser))
              (loop (+ pos 1) 'boundary))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one-byte parser lifecycle\\.the accepted byte stops after consuming one byte: stream offset")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a mismatched generated-runtime ABI version is accepted"
  # The version CHECK is the unversioned constructor's first action; the live
  # guard refuses a mismatched number.
  FIND [[    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine]]
  REPLACE [[    (unless #t
      (assertion-violation 'byte-machine-make-compiled-machine]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a mismatched ABI version is refused: refused")

# No mutation pins a sticky result cache: there is none. A repeat feed re-runs
# the executor, which is idempotent for stop/error, so caching or not is
# unobservable; the reset mutations below distinguish current, offset and
# lifecycle restoration.

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an invalid feed slice is accepted instead of raising"
  FIND [[(unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid slice")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an accepting feed does not record the stopped lifecycle"
  FIND [[(case (parser-result-status r)
                 ((stopped) (parser-set-lifecycle! parser 'stopped))]]
  REPLACE [[(case (parser-result-status r)
                 ((stopped) (parser-set-lifecycle! parser 'ready))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "stopped after accept")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a rejecting feed does not record the error lifecycle"
  # Anchored on the error-arm-then-finished-arm adjacency that makes it unique
  # to parser-feed! (parser-finish-v2! orders its arms differently).
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                          (parser-set-stored-error! parser (parser-result-error r)))
                 ((finished) (parser-set-lifecycle! parser 'finished))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'ready)
                          (parser-set-stored-error! parser (parser-result-error r)))
                 ((finished) (parser-set-lifecycle! parser 'finished))]]
  # The detail is part of the pin: `got ready` is the lifecycle this mutant
  # records.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "error after reject -- expected error, got ready")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not restore the entry state"
  FIND [[(parser-set-current! parser (parser-entry parser))]]
  REPLACE [[(parser-set-current! parser (parser-current parser))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "re-parses from entry")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not zero the stream offset"
  FIND [[(parser-set-offset! parser 0)]]
  REPLACE [[(parser-set-offset! parser (parser-offset parser))]]
  # The detail is part of the pin: the entry-state mutation above trips this
  # same check with "expected 1, got 0"; zeroing the offset fails it with
  # "got 2". Measured from both.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "offset zeroed then advanced by one -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not return the lifecycle to ready"
  # Widened with the preceding `(parser-set-offset! parser 0)` line, which
  # occurs only in parser-reset!: parser-resume!'s paused-feed arm carries a
  # second bare `(parser-set-lifecycle! parser 'ready)`.
  FIND [[(parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready)]]
  REPLACE [[(parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'stopped)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ready after reset")

# parser-finish-op!'s eof-target routing and its default-eof fallback. Neither
# is exercised by any feed-path or reset mutation above -- they run only inside
# parser-finish!.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an exhausted dispatch does not take its eof-target"
  FIND [[(op 'eof-target node)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a truthy eof-target continues to it -> finished: finished")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a dispatch with no eof-target does not route to the default error"
  # The routing and the store below share this FIND; they are separate
  # decisions. A default-EOF error has no error node, so its node-name is the
  # exhausted dispatch node's.
  FIND [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'error off 0 off e))))))]]
  REPLACE [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'stopped off 0 off e))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no eof-target routes to the default-eof error: default-eof status")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the default-eof arm does not store its value"
  # Same FIND as the routing mutation above, a distinct decision: dropping only
  # the store (not the status) is witnessed by the case that reads the value
  # back through a later feed. Bare "stored error value" is a substring of a
  # DIFFERENT check's label, "feed-stored error value" (the feed-side store's
  # witness below), so the pin names this case.
  FIND [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (parser-set-stored-error! parser e)
                       (make-parser-result 'error off 0 off e))))))]]
  REPLACE [[(let ((e (parts->parser-error (op 'default-eof-value node) off 'eof)))
                       (make-parser-result 'error off 0 off e))))))]]
  # The detail is part of the pin: "runtime: the errs entry is unpacked
  # reason-first" fails this check too, reading back the REASON string. Nothing
  # stored reads back as #f, and only here.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the error row returns the stored error after a default-EOF truncation: stored error value -- expected eof, got #f")

# parser-feed-op!'s own `finish` arm: a parser parked at a finish node, re-fed,
# returns finished, consuming zero (the finish-feed-op case in
# runtime-tests.sps). This FIND is textually distinct from parser-finish-op!'s
# own 'finished result (off/0/off) two mutations above.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a feed on a finished parser does not return finished"
  #
  # Pinned on the check and its detail rather than on the usual `<case>: <what>`
  # shape: this case's name ends in "(§12.2)", and a pin cannot carry the
  # parentheses unescaped. The detail is measured from a real run of this
  # mutation and states the decision directly -- a feed on a parser parked at a
  # finish node reports finished, not stopped. A bare "status" would be a
  # substring of the summary line's own `status=`.
  #
  # The leading ": " is load-bearing. The re-finish mutation below emits the
  # same detail on another check -- "sticky status -- expected finished, got
  # stopped" -- so without the colon this pin matches that mutation too. The
  # colon binds the pin to a check named exactly "status": in the sibling's
  # line the two characters before "status" are "y ", not ": ".
  FIND [[(make-parser-result 'finished pos (- pos start) (parser-offset parser) #f)]]
  REPLACE [[(make-parser-result 'stopped pos (- pos start) (parser-offset parser) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES ": status -- expected finished, got stopped")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a payload short of the current ABI's members is accepted"
  # Without the guard the runtime reads a member out of a payload that has none
  # and fails with an index error deep in make-parser instead of a named
  # refusal at construction. There is ONE length guard, reading
  # `current-abi-members`: in a chain of per-version minimums a later minimum
  # subsumes every earlier one, so only the last could be witnessed. Deleting
  # it exposes `(vector-ref metadata 2)`, whose `who` is not the constructor's.
  FIND [[    (unless (and (vector? metadata)
                 (>= (vector-length metadata) current-abi-members))]]
  REPLACE [[    (unless (vector? metadata)]]
  EXPECT_STATUS 1
  # The check label and the raise pick one record: the payload exactly one
  # member short of the minimum. The bare case name resolves four times in this
  # mutant's own output -- two failing checks, each followed by a FAIL-CONTEXT
  # line quoting the same id.
  EXPECT_OUTPUT_MATCHES
    "a payload short of the current minimum is refused: refused BY THE CONSTRUCTOR, not by vector-ref -- raised object did not satisfy the predicate: Exception in vector-ref: 2 is not a valid index")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish does not drive exec with finish? true"
  # parser-finish-v2! must drive exec with finish? #t, not #f. The FIND's
  # `empty-bv 0 0 #t` is unique to the finish driver (the feed driver calls
  # exec with `bv start end #f`). `finish?` is the sixth argument (current
  # state, offset, empty-bv, 0, 0, #t) and the only difference between FIND and
  # REPLACE; the two move together whenever the call's tail changes.
  FIND [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t
                    (parser-field-values parser) parser (parser-callbacks parser))))]]
  REPLACE [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #f
                    (parser-field-values parser) parser (parser-callbacks parser))))]]
  # Driving `exec` with finish? #f makes it answer `need-input`, and the finish
  # path's own invariant -- every EOF outcome is terminal or paused, so the
  # `busy` it writes is always overwritten before it returns -- catches that by
  # name and irritant, which names the thing the mutation breaks rather than a
  # downstream consequence. That raise ends two cases, so the case name picks
  # the one whose finish has no input at all.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "finish with no input routes to the default-eof error: case raised -- Exception in parser-finish!: the finish path left the parser busy with irritant need-input")

# The /v2 TOMBSTONE. Both retired constructors refuse EVERY version rather than
# the one they are named for: a guard on the literal version would accept
# exactly the stale files it exists to refuse once the current ABI version
# moved past it. This mutation witnesses that the tombstone raises.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the /v2 tombstone accepts a version"
  # Three textually distinct guard forms is a hard constraint, not style: every
  # mutation runs at the default SITES of 1, asserted exactly, so writing any two
  # of the live guard and the two tombstones alike takes one FIND from one site
  # to two and fails the suite at declaration.
  FIND [[    (assertion-violation 'byte-machine-make-compiled-machine/v2
                         "retired generated-runtime ABI (superseded by the unversioned constructor)"]]
  REPLACE [[    (list 'accepted
                         "retired generated-runtime ABI (superseded by the unversioned constructor)"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "the retired constructors refuse every version: none accepted")

# Pause/resume and the operation matrix: parser-resume! (its two acks and its
# own prohibited-cell else arm), the prohibited feed/finish rows, the feed-side
# stored-error read, both pause arms in parser-feed-op!, the EOF-pause arm in
# parser-finish-op!, and the sticky short-circuit's consumed field.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume on paused-feed reopens feed, not finish"
  # Measured: the lifecycle corruption fails the case's own "lifecycle" check
  # before the next parser-feed! call is reached; that call then raises (the
  # corrupted state is a prohibited feed row), recorded as a second, cascading
  # "case raised" failure. Bare "lifecycle" is not a sound pin: the group name
  # "one-byte parser lifecycle" and the case name "parser-lifecycle tracks
  # ready -> terminal" both contain it.
  FIND [[((paused-feed) (parser-set-lifecycle! parser 'ready) 'feed-ready)]]
  REPLACE [[((paused-feed) (parser-set-lifecycle! parser 'finish-ready) 'feed-ready)]]
  # "runtime: a feed pause maps to paused-feed, not paused-finish" leaves the
  # parser in the same lifecycle, but resumes with a different ACK, so the case
  # asserts the ack and the lifecycle as ONE pair: the sibling reports
  # `(finish-ready finish-ready)` and this mutant `(feed-ready finish-ready)`.
  # Asserted as two checks, every record this mutant emits would be the
  # sibling's too.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "acks feed-ready and reopens feed: the ack and the reopened lifecycle, together -- expected .feed-ready ready., got .feed-ready finish-ready.")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume on paused-finish acks finish-ready"
  # Bare "ack" is not a sound pin: the FAIL-CONTEXT line, printed on every
  # recorded failure, contains " backend=chez", and "ack" is a substring of
  # "backend" -- satisfied by ANY failure. Pinned to the owning case's words.
  FIND [[((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'finish-ready)]]
  REPLACE [[((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'feed-ready)]]
  # The mirror of the paused-feed row above. "runtime: an EOF pause parks
  # paused-finish, not paused-feed" answers the same wrong ack but leaves a
  # different lifecycle: as one pair, the sibling reports `(feed-ready ready)`
  # and this mutant `(feed-ready finish-ready)`.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "EOF path and resumes to finish-ready: the ack and the lifecycle it leaves, together -- expected .finish-ready finish-ready., got .feed-ready finish-ready.")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume outside the paused rows is a prohibited cell"
  FIND [[(else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  REPLACE [[(else 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "resume on ready")

# The whole-arm mutation above is caught by "resume on ready"; this narrower
# mutant admits ONLY error/finished, leaving ready/stopped/finish-ready
# refused, so it needs the two check-raises cases in "resume is prohibited
# outside the paused rows" (runtime-tests.sps). Measured: the thunk returns the
# mutant's own 'ok literal instead of raising, on both; pinned to the first
# ("resume on error"), a label unique in this file, with the returned literal
# making the pin specific to this exact mutant.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume admits error/finished instead of refusing them"
  FIND [[(else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  REPLACE [[((error finished) 'ok)
      (else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "resume on error -- expected a raise, but the thunk returned ok")

# finished x finish!: parser-finish!'s OWN sticky arm, distinct from
# parser-feed!'s sticky-finished arm (LABEL "runtime: a feed on a finished
# parser does not return finished" above). Witnessed by a check in the
# "eof-target continues to it -> finished" case (runtime-tests.sps).
#
# Measured: a single FAIL, on that check only (the first finish! call, via
# the executor's own finish arm, is untouched by this REPLACE and still
# passes). The pin "sticky status -- expected finished, got stopped" alone
# does NOT discriminate: the sibling above ALSO fails a check named "sticky
# status" with the SAME "expected finished, got stopped" text, as a cascade
# (its mutant corrupts lifecycle to 'stopped after the FIRST feed, so the
# second feed's own sticky-status check reports the identical wrong value).
# The case-name tail is what separates them -- "continues to it -> finished"
# occurs only in this mutation's own case.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a re-finish on a finished parser does not return finished"
  FIND [[((finished) (make-parser-result 'finished (parser-offset parser) 0
                                      (parser-offset parser) #f))]]
  REPLACE [[((finished) (make-parser-result 'stopped (parser-offset parser) 0
                                      (parser-offset parser) #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "continues to it -> finished: sticky status -- expected finished, got stopped")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: feed refuses every paused/finish-ready row"
  FIND [[((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  REPLACE [[((paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  # The sibling "a feed pause maps to paused-feed, not paused-finish" breaks
  # the SAME check -- measured. The details differ and separate them: this
  # mutation makes the prohibited call return a tuple, that one leaves the
  # refusal in place but raises with the wrong lifecycle in it.
  EXPECT_STATUS 1
  # The mutant reaches `parser-feed!`'s `else`, which raises for any lifecycle
  # it does not name (an `else` meaning "ready" would execute, and a poisoned
  # parser would re-execute), so the mutant raises the wrong condition instead
  # of none. Measured: the predicate rejects it by `who`/`code`.
  EXPECT_OUTPUT_MATCHES
    "feed on paused-feed -- raised object did not satisfy the predicate: Exception in parser-feed!: unknown lifecycle")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: finish refuses the paused rows"
  FIND [[((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation]]
  REPLACE [[((paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation]]
  # The paused-feed/paused-finish mapping mutation breaks this check too, but
  # by raising with the wrong lifecycle rather than by returning.
  EXPECT_STATUS 1
  # `parser-finish!`'s else is loud, as `parser-feed!`'s is, so the mutant
  # raises the wrong condition rather than executing.
  EXPECT_OUTPUT_MATCHES
    "finish on paused-feed -- raised object did not satisfy the predicate: Exception in parser-finish!: unknown lifecycle")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the error row returns the STORED error"
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                          (parser-set-stored-error! parser (parser-result-error r)))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'error))]]
  # The detail is part of the pin: "runtime: the errs entry is unpacked
  # reason-first" fails this check too, reading back the reason string; nothing
  # stored reads back as #f.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the error row returns the stored error after a feed error: feed-stored error value -- expected unexpected-byte, got #f")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a feed pause maps to paused-feed, not paused-finish"
  # Pinned on the case "feed pauses at the pause node with the first
  # unconsumed index", whose own "lifecycle" check reads the lifecycle right
  # after THIS arm runs -- the decision itself, not a downstream consequence
  # such as the later resume ack. Bare "ack" is not a sound pin (see the
  # resume-on-paused-finish mutation above).
  FIND [[((paused) (parser-set-lifecycle! parser 'paused-feed))]]
  REPLACE [[((paused) (parser-set-lifecycle! parser 'paused-finish))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "unconsumed index: lifecycle")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm parks current on the continuation"
  FIND [[(parser-set-current! parser (op 'pause-target node))
             (make-parser-result 'paused pos (- pos start) (parser-offset parser) #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))]]
  REPLACE [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "continues past the pause")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an EOF pause parks paused-finish, not paused-feed"
  # Bare "lifecycle" is not a sound pin (see the resume-on-paused-feed mutation
  # above), and neither is the case prefix alone: the owning case has two
  # SIBLING checks whose labels ("lifecycle now", "lifecycle final") start with
  # the same word, so "...finish-ready: lifecycle" is a prefix of all three FAIL
  # lines (the intended one fails here, cascading into "lifecycle now" as a
  # second, real failure). Extending into the measured expected/actual pair,
  # unique to this one check, makes the match exact. The FIND includes the
  # pause-target line, which distinguishes the pause NODE's finish arm from the
  # callback arm (that one uses callback-failure-position).
  FIND [[(parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f
             (let ((rp (op 'pause-reason node)))
               (and rp (parts->parser-error rp off pk)))))]]
  REPLACE [[(parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-feed)
           (make-parser-result 'paused off 0 off #f
             (let ((rp (op 'pause-reason node)))
               (and rp (parts->parser-error rp off pk)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "resumes to finish-ready: lifecycle -- expected paused-finish, got paused-feed")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the stopped row short-circuits with consumed zero"
  # Bare "consumed" matches eight other check labels file-wide, and this
  # mutation also reddens two other cases that exercise the same sticky
  # short-circuit -- real, but not a signature that names only this decision.
  # Pinned to the owning case's own words.
  FIND [[((stopped) (make-parser-result 'stopped start 0 (parser-offset parser) #f))]]
  REPLACE [[((stopped) (make-parser-result 'stopped start 1 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "tuple: consumed zero")

# Three decisions whose break no other check catches:
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a finish reaching a named error node does not store its value"
  # parser-finish-op!'s own plain error arm, reached by driving an eof-target
  # chain into a NAMED error node (the pause-op stub's s1 -> 'trunc), which
  # witnesses both this store and the arm's routing together.
  FIND [[(let ((e (parts->parser-error (op 'error-value node) off pk)))
             (parser-set-stored-error! parser e)
             (make-parser-result 'error off 0 off e)))]]
  # The REPLACE drops ONLY the store; FIND and REPLACE differ in that one line,
  # so the pinned record can come from nothing else. One mutation, one decision.
  REPLACE [[(let ((e (parts->parser-error (op 'error-value node) off pk)))
             (make-parser-result 'error off 0 off e)))]]
  # The detail is part of the pin, for the same sibling and the same reason as
  # the feed-side store above.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "finish reaches a named error node via the eof-target chain and stores it: finish repeats the finish-stored error -- expected truncated-input, got #f")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish error does not store its value"
  # parser-finish-v2!'s own error arm is a separate call site from every
  # op-path store above; the case that chains a second finish! through the
  # sticky read is what re-reads the stored value.
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                 (parser-set-stored-error! parser (feed-outcome-error o)))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'error))]]
  # The detail is part of the pin, for the same sibling and the same reason as
  # the two op-path stores above.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a /v2 finish error is stored and repeated on the next call: finish repeats the stored /v2 error -- expected eof, got #f")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish reaching a pause state does not record paused-finish"
  # parser-finish-v2!'s own paused arm -- distinct code from both the shared
  # parser-feed! wrapper's paused arm and parser-finish-op!'s pause arm, both
  # witnessed only through the op-path stub. stub-exec's state 3 is the /v2
  # fixture that reaches a pause state. Bare "lifecycle" is not a sound pin
  # (see the resume-on-paused-feed mutation above); pinned to the owning case.
  FIND [[((paused) (parser-set-lifecycle! parser 'paused-finish)))]]
  REPLACE [[((paused) (parser-set-lifecycle! parser 'paused-feed)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "sets paused-finish: lifecycle")

# parser-feed!'s finished sticky arm (a feed repeated after lifecycle is
# already 'finished) and the error sticky arm's `next` field. The `next`
# witness feeds from a nonzero start: from start 0, `start`, the literal 0, and
# (parser-offset parser) are indistinguishable.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the finished row short-circuits with consumed zero"
  # Not case-prefixed: this case's own name ends in the parenthesised section
  # reference "(§12.2)", and CMake's MATCHES is a real regex --
  # unescaped "(" ")" would open a capture group instead of matching literal
  # parentheses, and "." inside the section number would match any character,
  # so a case-name tail is not a safe anchor here. Extending into the detail
  # (the measured expected/actual pair) gives the same exactness a case tail
  # gives its siblings, without putting a metacharacter in the pattern.
  FIND [[((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))]]
  REPLACE [[((finished) (make-parser-result 'finished start 1 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "sticky consumed zero -- expected 0, got 1")

# The mutation above witnesses the finished arm's FIELD VALUES, not the arm's
# own existence -- deleting the whole `((finished) ...)` clause is a different
# mutant. With the clause gone, the lifecycle 'finished reaches parser-feed!'s
# `else`, which raises for every lifecycle the `case` does not name.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: parser-feed!'s finished sticky arm is deleted outright"
  # REPLACE is a single space, not empty: CMake's cmake_parse_arguments (under
  # this file's own cmake_minimum_required, policy CMP0174 OLD) treats an
  # empty bracket argument as "not passed" and unsets arg_REPLACE, which would
  # trip byte_machine_mutation's own required-argument check. A lone space
  # deletes the clause just as effectively -- Scheme does not care about the
  # blank line it leaves between the preceding clause and `(else`.
  FIND [[((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))]]
  REPLACE [[ ]]
  # Caught because the `else` is loud: the deleted arm's lifecycle reaches it
  # and raises, and the specification catches this mutant by name and
  # irritant. Were that `else` to mean "ready", the op path would re-derive
  # the identical result tuple from `current` and this mutant would survive --
  # a survivor's reason is only as durable as the control-flow shape it names.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "re-feeds to finished, consuming zero: case raised -- Exception in parser-feed!: unknown lifecycle with irritant finished")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the error row's next mirrors the new call's start, not the offset"
  FIND [[(make-parser-result 'error start 0 (parser-offset parser)]]
  REPLACE [[(make-parser-result 'error (parser-offset parser) 0 (parser-offset parser)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "after a feed error: next is the new start")

# parser-reset!'s stored-error clear: declared, not silently unmutated.
# parser-stored-error is unexported, and its only two read sites both require
# lifecycle = 'error -- which parser-reset! unconditionally overwrites to
# 'ready in the very same call, before any read could observe what this line
# left behind. The only way lifecycle can become 'error again is through one of
# this file's four write sites (the feed wrapper, both finish variants, and the
# default-eof arm), every one of which stores a fresh value before or as part
# of its own transition into 'error -- so whatever this clear left behind is
# always overwritten first. Measured: the mutant below passes the whole SPEC
# lane unchanged; EXPECT_SURVIVES is the honest declaration of that, not
# silence.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset's stored-error clear is skipped"
  FIND [[(parser-set-stored-error! parser #f)]]
  REPLACE [[(parser-set-stored-error! parser (parser-stored-error parser))]]
  EXPECT_SURVIVES
    "parser-stored-error is unexported, so nothing outside this library can read the slot directly; its only two read sites (the error sticky arms in parser-feed! and parser-finish!) are both guarded by lifecycle = 'error, and parser-reset! unconditionally sets lifecycle to 'ready in this same call, so neither read site is reachable immediately after a reset. Reaching 'error again requires a fresh feed or finish that re-enters one of the four write sites, and every one of them stores its own value before or alongside its own lifecycle='error transition -- so a stale value left by a skipped clear is always overwritten before anything could observe it. Measured directly: this mutant passes the whole SPEC-lane suite unchanged")

# Two decisions in the same defect class as the sticky error arm's `next`
# field: a pause fixture that feeds from start 0 / a fresh offset 0 cannot
# tell a field reading a computed position from one reading a
# coincidentally-equal constant. Without the nonzero-start cases below, the
# mutants pass the whole SPEC lane.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm's consumed and stream offset collapse to next"
  # parser-feed-op!'s pause arm reads `pos` for next, `(- pos start)` for
  # consumed, and `(parser-offset parser)` for stream-offset -- three DIFFERENT
  # expressions that a feed from start 0 consuming exactly one byte evaluates
  # all to 1. The case "a nonzero-start feed pause separates next, consumed,
  # and stream offset" feeds #vu8(9 1 2)[1,3) so next (2) separates from the
  # other two (both still 1). The REPLACE keeps the optional-reason lines and
  # mutates only the three field expressions.
  FIND [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))]]
  REPLACE [[(make-parser-result 'paused pos pos pos #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "separates next, consumed, and stream offset: consumed -- expected 1, got 2")

# The nonzero-start case above separates `next` from the pair, but NOT
# `consumed` from `stream-offset` -- on any single feed call from a fresh
# parser those two are equal by construction (the offset starts at 0, so the
# cross-call total equals this call's own count), so a mutant that only SWAPS
# the two expressions (rather than collapsing all three) is invisible to it.
# The case "a second feed call separates consumed from stream offset" is what
# catches it: finish-pause-op's s1 also advances on byte 2 into a second,
# byte-reachable pause, so the first call's advance (offset 0->1) makes the
# second call's own consumed (1) and the persisted stream-offset (2) diverge.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm swaps consumed and stream offset"
  # Same FIND as the mutation above; keeps the optional-reason lines and swaps
  # the two fields.
  FIND [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))]]
  REPLACE [[(make-parser-result 'paused pos (parser-offset parser) (- pos start) #f
               (let ((rp (op 'pause-reason node)))
                 (and rp (parts->parser-error rp (parser-offset parser) pk)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "separates consumed from stream offset: consumed -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an EOF pause after consuming bytes reports zero instead of the persisted offset"
  # parser-finish-op!'s pause arm reads `off` -- (parser-offset parser),
  # snapshotted at the top of the call -- into both the next and stream-offset
  # slots. An EOF pause reached before any byte is consumed has `off` = 0, where
  # a hard-coded 0 is indistinguishable. The op stub finish-pause-op (s0
  # --1/advance--> s1, s1's eof-target a pause continuing to a finish) and its
  # own case reach an EOF pause after consuming a byte.
  #
  # Separated from "runtime: advance does not increment the stream offset",
  # whose failures on this case's "next" and "stream offset" checks are this
  # mutant's too (both read 0 instead of 1): that mutation breaks the one write
  # site that makes `off` become 1, this one discards a correctly-computed `off`
  # at the read site. Proving `off` nonzero needs the increment, but separating
  # the two mutants does not: this one keeps the parser's own offset at 1 and
  # reports 0, the sibling holds 0 in both. The case asserts the result's offset
  # and `parser-stream-offset` as one pair -- `(0 1)` here, `(0 0)` there -- and
  # the pin is on that pair.
  #
  # `parser-finish-op!`'s callback arm parks and reports with the same result
  # form, so the FIND includes the PAUSE NODE's own `pause-target` line, which
  # is what makes this the pause node's decision; the callback arm's copy has
  # its own mutation in the callback pass. The REPLACE keeps the
  # optional-reason lines and mutates only the offsets.
  FIND [[(parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f
             (let ((rp (op 'pause-reason node)))
               (and rp (parts->parser-error rp off pk)))))]]
  REPLACE [[(parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused 0 0 0 #f
             (let ((rp (op 'pause-reason node)))
               (and rp (parts->parser-error rp off pk)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the persisted offset, not zero: and it is the offset the parser holds -- expected .1 1., got .0 1.")

# finish-ready's own membership in parser-feed!'s prohibited clause, witnessed
# by runtime-tests.sps's "feed on finish-ready" case. "runtime: feed refuses
# every paused/finish-ready row" above drops paused-feed instead, a separate
# decision (measured: dropping finish-ready does not also un-refuse
# paused-feed, and vice versa). finish-ready is the row that closes the
# resume-then-feed-into-finish route.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: feed admits finish-ready instead of refusing it"
  FIND [[((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  REPLACE [[((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1
  # `parser-feed!`'s else is loud, so the mutant raises the wrong condition
  # rather than executing.
  EXPECT_OUTPUT_MATCHES
    "feed on finish-ready -- raised object did not satisfy the predicate: Exception in parser-feed!: unknown lifecycle")

# The parser-error record's construction decisions, witnessed by
# runtime-tests.sps's own cases.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the ABI version check does not come first"
  # The check precedes every other guard, so a mismatch is reported before any
  # part of the payload is interpreted -- which is what makes the payload safe
  # to grow. Witnessable only by a predicate that names WHICH guard fired:
  # every guard here raises assertion-violation with the same `who`, so a bare
  # assertion-violation? predicate passes whichever one fires and cannot
  # observe the ordering. The irritant is the only thing that differs.
  FIND [[    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))]]
  REPLACE [[    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine "exec must be a procedure" exec))
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine
                           "generated-runtime ABI mismatch" abi-version))]]
  EXPECT_STATUS 1
  # "runtime: a mismatched generated-runtime ABI version is accepted" deletes
  # the check outright. A check moved behind the exec guard and a check
  # deleted outright misbehave identically on every input where the moved one
  # misbehaves at all, so no single-input check can part them -- the deleted
  # check is strictly more permissive. A value spanning two inputs can: named
  # with a second defect and without one, this mutant reports
  # `(not-a-procedure 2)` and the sibling `(not-a-procedure accepted)`.
  EXPECT_OUTPUT_MATCHES
    "the version is named with a second defect and without one -- expected .2 2., got .not-a-procedure 2.")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a machine error is constructed in the callback domain"
  # The error domain is `machine | callback`, and `callback` has exactly one
  # producer: a callback failure. A constructor that hard-wires the wrong
  # member of a two-member enumeration is invisible to every test that does not
  # read the slot, which is why the accessor case reads it rather than
  # assuming it.
  FIND [[    (vector parser-error-tag 'machine (vector-ref entry 0) (vector-ref entry 1) #f]]
  REPLACE [[    (vector parser-error-tag 'callback (vector-ref entry 0) (vector-ref entry 1) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "domain and detail are fixed by the constructor: domain")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the errs entry is unpacked reason-first"
  # The entry packs (code . reason) positionally and both are read from the same
  # two-element vector, so transposing them type-checks and survives anything
  # that reads only one of the pair. Caught by a failed comparison on the code,
  # not by a raise.
  FIND [[    (vector parser-error-tag 'machine (vector-ref entry 0) (vector-ref entry 1) #f]]
  REPLACE [[    (vector parser-error-tag 'machine (vector-ref entry 1) (vector-ref entry 0) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the five call-site members read back: code")

# The portable-name grammar for a callback failure code. The mutant checks
# `symbol?` alone, and the lane's case refuses `BadCode` under the grammar it
# shares with verify.sls.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a callback failure code is not checked against the portable grammar"
  FIND [[(unless (and (symbol? code) (portable-name? code))]]
  REPLACE [[(unless (symbol? code)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "portable name grammar: BadCode refused -- expected a raise")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 33: the verifier's decisions ---------------------------------------
#
# verify-tests.sps asserts the exact diagnostic CODE emitted for each broken
# variant of the one-byte machine (never rendered text); this pass proves those
# code assertions are not vacuous by suppressing the decision that emits each
# code and requiring the owning case to notice. Verify command uses both
# library roots, an empty object guard, and the verify program. Each FIND is a
# verbatim, unique substring of verify.sls.
#
# PIN AUDIT. Adding a mutation OR a check to this lane widens every existing
# pin's collision set silently -- a new check's label can contain an old pin
# as a substring -- so the whole pass is re-judged after either: apply each
# mutation to a staged copy, capture the SPEC lane's full stdout+stderr, and
# re-judge every pin through byte_machine_mutation_verdict against every OTHER
# mutant's captured output, plus a self-check that each pin catches its own
# mutant. Running the same sweep on the merge base tells an introduced
# collision from an inherited one.
#
# Where two mutants cross-match, the pass sorts them by whether their FAIL
# record sets actually differ:
#   * UNDER-ANCHORED: the mutant owns a record no sibling emits, and a pin
#     that names it fixes the collision. A bare diagnostic CODE is the usual
#     culprit; pins here name a case and a check.
#   * SEPARABLE: the sets differ but no single record is the mutant's own, so
#     the fix is a new assertion. Two remedies this pass ships:
#       - ATTRIBUTION checks: "a well-formed pause machine verifies" names the
#         diagnostics that must be ABSENT ("no unreachable-node", "no
#         non-eof-into-finish") rather than one "accepted" boolean that
#         several mutants redden alike.
#       - COUNT, DON'T WITNESS: one fixture carrying several things a walk can
#         reach, asserting the count, so each way of breaking the enumeration
#         reports a different number -- "an EOF walk crosses a pause for both
#         terminal kinds (§16.2:909)" and "an asymmetric collision graph
#         counts every pair, once".
#   * SUBSUMED: the narrow mutant's whole FAIL-record set is a subset of one
#     sibling's -- a decision killed again by a switch above it. Each is
#     recorded at the narrow mutant's own pin, named by the LABEL of the
#     mutation that contains it, with the measurement. Zero unique records is
#     a signal that the specification is under-specified; only what survives
#     an actual separating attempt is recorded as subsumed, and a pin says so
#     where no attempt has been made.
#
# Five pins in this pass are bare codes -- duplicate-name,
# missing-error-declaration, invalid-eof-target, invalid-shape,
# duplicate-error-declaration -- because each names a decision only one
# mutation here can break: each was judged against every sibling and matched
# none.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/verify-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: reachability never reports an unreachable node"
  FIND [[(make-diagnostic 'unreachable-node (node-name n) "node is unreachable")]]
  # Anchored to its own case and check. A bare "unreachable-node" pin is a
  # substring of the "no unreachable-node" attribution check on "a well-formed
  # pause machine verifies", and so matches "a pause continuation is an
  # out-target (resolution + reachability)", which reddens that check.
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an unreachable node is rejected: unreachable-node")

# pass-overlap compares canonical matcher BYTE SETS: two cases matching the
# same byte must be reported. Pinned on the helper's body rather than on the
# pair loop, so the loop's own mutations below stay separate decisions.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: two cases sharing a byte are never found to overlap"
  FIND [[(and (pair? a) (or (and (memv (car a) b) #t) (byte-sets-overlap? (cdr a) b)))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "same byte overlap: overlapping-cases")

# The pair enumeration itself. The helper pin above proves the disjointness
# TEST fires; these three prove the pass reaches every pair, reports each once,
# and does not stop at the first collision it finds.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only the first case is compared against the others"
  FIND [[(outer (cdr ss)]]
  REPLACE [[(outer '()]]
  # A symmetric fixture cannot separate the ways the enumeration can be
  # truncated: on a mutually colliding triple, "only the first case is
  # compared" and "each case is compared only against its successor" both
  # report 2, and "two cases sharing a byte are never found to overlap"
  # produces the same got 0 as this mutant on a second-and-third fixture. "an
  # asymmetric collision graph counts every pair, once" (verify-tests.sps)
  # breaks that symmetry by construction: its colliding pairs are (1,2), (2,3),
  # (2,4), on which the four ways of breaking the enumeration report four
  # DIFFERENT counts (1 here, 2 for the sibling below, 0 for the helper mutant,
  # 7 for the self-comparison mutant) against the correct 3. Measured against
  # every other mutant's captured output: this pin matches no other.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an asymmetric collision graph counts every pair, once: three pairs -- expected 3, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a case's collisions after the first are dropped"
  FIND [[(inner (cdr rest)]]
  REPLACE [[(inner '()]]
  # Same fixture as the mutation above: on the asymmetric collision graph this
  # edit reports 2 where the sibling above reports 1, the helper mutant 0, and
  # the self-comparison mutant 7.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an asymmetric collision graph counts every pair, once: three pairs -- expected 3, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a case is compared against itself"
  FIND [[(let inner ((rest (cdr ss)) (out out))]]
  REPLACE [[(let inner ((rest ss) (out out))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "do not overlap: none")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: zero-progress detection never fires"
  # The FIND is the whole report guard, one disjunct per kind that can sit on a
  # zero-progress cycle; it reflows whenever a kind joins. The REPLACE and the
  # pin do not move with it, which is what says the decision has not moved.
  FIND [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a reexecute self-loop is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine-name grammar check is suppressed"
  # The FIND is the name conjunct alone (the label conjunct shares the arm's
  # test), so the mutant drops the name check and nothing else.
  FIND [[(valid-name? (machine-name m))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an uppercase machine name is invalid-name: invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a missing transition target is not reported"
  FIND [[(make-diagnostic 'missing-target t "no such node")]]
  REPLACE [[#f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a fallback target that names no node is missing-target: missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a duplicate node name is not reported"
  FIND [[(cons (make-diagnostic 'duplicate-name nm "duplicate node name") out)]]
  REPLACE [[out]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an undeclared error reference is not reported"
  FIND [[(if (and (error-node? n) (not (memq (error-node-error-name n) enames)))]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-error-declaration")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the default-eof-error membership check is suppressed"
  FIND [[(if (memq (machine-default-eof-error m) (error-names m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1
  # The bare code "invalid-eof-target" is shared with a second, unrelated
  # decision (a per-node eof-target resolution failure), whose mutants emit it
  # too. Anchored to this mutation's own originating case.
  EXPECT_OUTPUT_MATCHES
    "a default-eof-error naming no declared error is invalid-eof-target: invalid-eof-target")

# Further decisions the verifier emits: the schema guard, the
# duplicate-error-declaration branch, the entry-resolution site of
# missing-target (distinct from the transition site above), and the node-name
# and error-code sites of the name-portability check (distinct from the
# machine-name site above), plus the unsupported-IR-version half of the schema
# check. Each has its own rejection case in verify-tests.sps; as with
# harness-group and with-cleanup, each site of a multi-site decision is
# witnessed on its own.
#
# BOTH directions of the IR-version check are declared and BOTH are caught. A
# test can forge a machine: descriptors are bare R6RS vectors, so a test copies
# the tag with (vector-ref m 0), an (rnrs) primitive needing no private import,
# and builds a machine carrying any version it likes. AGENTS.md reserves
# EXPECT_SURVIVES for the genuinely unwitnessable.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an unsupported IR version is accepted"
  FIND [[          ((not (= (machine-ir-version-of m) supported-ir-version))]]
  REPLACE [[          ((and #f (not (= (machine-ir-version-of m) supported-ir-version)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a machine carrying an unsupported IR version is invalid-shape: unsupported version is reported")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "ir: the supported IR version is not the one machines are stamped with"
  # The restrictive direction, and the reason supported-ir-version is a second
  # constant rather than a reuse of the stamp: forcing the STAMP changes what is
  # built, forcing THIS changes what is accepted, and only the second is a
  # verifier decision. Every shipped fixture becomes unsupported at once.
  FIND [[  (define supported-ir-version 1)]]
  REPLACE [[  (define supported-ir-version 2)]]
  # A bare CHECK NAME carrying no value -- "...: no diagnostics", with neither
  # the expected count nor the got -- matches ANY mutant that reddens that case,
  # and two others do: "verify: a case is compared against itself" (got 1) and
  # "verify: the reason repertoire rejects every reason" (got 2).
  #
  # So the pin is off its own on-point case, which expects ZERO diagnostics and
  # has no code to compare. The record below is a SET DIFFERENCE against every
  # other Pass 33 mutant: `got invalid-shape` where another code was expected is
  # produced by this mutation alone, because it is the only one that makes
  # pass-schema fire on a WELL-FORMED machine. The mechanism is narrow:
  # pass-schema does NOT short-circuit verify-machine -- its diagnostics are
  # appended to the other passes', which are gated only on `(machine?
  # machine)`, still true of a version-mismatched machine. pass-schema is FIRST
  # in that append, so its diagnostic is the one `codes` reports at the head.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: invalid-field-declaration -- expected invalid-field-declaration, got invalid-shape")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the schema guard reports a non-machine under the wrong code"
  # Pinned on its own case: bare "invalid-shape" is emitted by two arms of
  # pass-schema's cond, so it does not resolve to one (case, check) pair.
  # Mutates the CODE the arm reports, not the guard that reaches it: skipping
  # the shape arm lets the version arm call an accessor on a non-vector, so a
  # guard mutant dies by a RAISE rather than by the failed comparison this pin
  # names -- AGENTS.md's "try the opposite constant first". The FIND carries
  # the message string because 'invalid-shape alone occurs twice in this pass.
  FIND [[           (list (make-diagnostic 'invalid-shape #f "not a machine")))]]
  REPLACE [[           (list (make-diagnostic 'invalid-name #f "not a machine")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a non-machine handed to verify-machine is invalid-shape: invalid-shape")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a duplicate error-declaration name is not reported"
  FIND [[(if (memq (car es) seen)]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-error-declaration")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an entry that names no node is not reported"
  FIND [[(if (lookup nodes (machine-entry m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an entry that names no node is missing-target: missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the node-name grammar check is suppressed"
  # The FIND is the name conjunct alone, as for the machine arm's.
  FIND [[(valid-name? (node-name n))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an uppercase node name is invalid-name: invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the error-code grammar check is suppressed"
  FIND [[(valid-name? (error-declaration-code e))]]
  REPLACE [[#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an uppercase error code is invalid-name: invalid-name")

# The reason-repertoire decision. Two mutations, one per direction, because the
# repertoire can be wrong permissively (accept a control character, which is
# what ships an unparseable generated library) or restrictively (reject a
# legal reason, which fails every shipped fixture). Both are caught by a failed
# COMPARISON rather than by a raise: the permissive one lands on a count check
# that reads 0 where the case expects 1, and the restrictive one on the clean
# machine's own diagnostic-count assertion. The pins name a case tail plus a
# check label, so each resolves to one (case, check) pair -- neither fragment
# appears in the banner, the FAIL-CONTEXT line or the summary line.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the reason repertoire accepts every character"
  FIND [[(or (and (char>=? c #\space) (char<=? c #\~)) (char=? c #\newline)))]]
  REPLACE [[#t)]]
  EXPECT_STATUS 1
  # Anchored on the DETAIL, not just the (case, check) pair: the bare pair is
  # matched by two siblings, because any mutation that suppresses the reason
  # clause reaches this same check. The two directions differ in what the
  # count becomes -- 0 when the repertoire accepts everything, 2 when it
  # rejects everything -- so the detail is what separates them.
  EXPECT_OUTPUT_MATCHES "a reason outside printable ASCII is rejected: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the reason repertoire rejects every reason"
  FIND [[          (and (reason-char? (string-ref s i)) (loop (+ i 1))))))]]
  REPLACE [[          (and #f (loop (+ i 1))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a reason may carry quote backslash and newline: no diagnostics -- expected 0, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an EOF-reachable stop terminal is accepted"
  FIND [[((stop-node? n) (verdict 'eof-reachable-stop path))]]
  REPLACE [[((stop-node? n) (verdict 'finish path))]]
  # Bare "eof-reachable-stop" is a diagnostic CODE that two other mutants also
  # emit -- "eof-terminal chains through a pause continuation" and "a
  # byte-reachable pause's continuation chain is an EOF path", both of which
  # redden pause cases whose labels carry the same code. This mutation breaks
  # the classification for EVERY stop terminal, so it is the only mutant to
  # fail the pre-pause eof-target case's own "has eof-reachable-stop" check;
  # anchored there, parentheses escaped. (eof-terminal's stop classification is
  # shared code, so this mutant's own captured output ALSO contains the arm-7
  # sequence case's record; that reverse direction is documented beside arm 7's
  # own pin.)
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an eof-target reaching a stop terminal is rejected \\(eof-reachable-stop\\): has eof-reachable-stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an eof-target cycle is classified as a finish terminal"
  # `path` is the DFS path stack: re-entering the current path is a cycle.
  FIND [[(cond ((memq name path) (verdict 'cycle (cons name path)))]]
  REPLACE [[(cond ((memq name path) (verdict 'finish (cons name path)))]]
  # Bare "eof-zero-progress-cycle" is a diagnostic CODE that "eof-terminal
  # chains through a pause continuation" and "a pause's byte-reachability gate
  # is not checked (eof-terminal chain)" also emit, each reddening a pause case
  # labelled with the same code. Anchored to the pre-pause eof-cycle case's own
  # "has eof-zero-progress-cycle" check, parentheses escaped. (eof-terminal's
  # cycle-detection guard is shared code, so this mutant's own captured output
  # ALSO contains both arm-5 sequence fixtures' records; that reverse direction
  # is documented beside arm 5's own pin.)
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an eof-target cycle is rejected \\(eof-zero-progress-cycle\\): has eof-zero-progress-cycle")

# The pause node's decisions: a pause continuation is an out-target for both
# name resolution (missing-target) and reachability (node-out-targets);
# eof-terminal walks through a pause continuation instead of stopping at it; a
# byte-reachable pause into a finish node is rejected; a pause continuation
# joins the reexecute zero-progress walk (a pause consumes no input, so a
# pause-only or mixed reexecute/pause cycle makes no progress); and a
# byte-reachable pause's continuation chain is itself an EOF path, checked the
# same way a dispatch node's eof-target chain is.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause continuation is an out-target (resolution + reachability)"
  # The label names two decisions, and the pin is on the one this mutation
  # owns. Its resolution half is shared: suppressing the missing-target
  # DIAGNOSTIC ("a missing transition target is not reported") and dropping the
  # pause continuation from the things checked for resolution redden the same
  # case with the same two records, byte for byte. The reachability half is
  # this mutation's alone, because node-out-targets' pause arm is what keeps a
  # pause's continuation on the reachability walk: "a well-formed pause machine
  # verifies" asserts that fixture emits no 'unreachable-node (attribution, not
  # the "accepted" verdict several mutants share), and only this mutant fails
  # it.
  #
  # The bare pause arm occurs three times in this file. The FIND is the pause
  # arm of node-out-edges, which yields (role . target) pairs; do not extend it
  # onto a neighbouring comment line -- an anchor on prose breaks every time the
  # prose is corrected.
  FIND [[          ((pause-node? n) (zero-width-edges n))]]
  REPLACE [[          ((pause-node? n) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a well-formed pause machine verifies: no unreachable-node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal chains through a pause continuation"
  # Each fixture that reaches only one EOF terminal kind past a pause is also
  # broken by the mutation that kills that one classification: eof-terminal's
  # pause arm returning no successor suppresses a diagnostic only where the
  # walk PAST the pause would have found a stop ('eof-reachable-stop) or a
  # cycle ('cycle). Not a subset either way, but no single record is this
  # mutant's own on such a fixture -- separable, and separated: "an EOF walk
  # crosses a pause for both terminal kinds (§16.2:909)" puts both terminal
  # kinds in ONE machine and counts them, expecting 2. The walk stopping at the
  # pause finds neither; losing stop classification or losing cycle
  # classification finds one. The pause's successor set is computed in
  # `eof-successors`; a pause contributes exactly one successor, which is what
  # this mutation removes.
  FIND [[    (cond ((pause-node? n) (list (cons 'continuation (pause-node-continuation n))))]]
  REPLACE [[    (cond ((pause-node? n) '())]]
  EXPECT_STATUS 1
  # An empty zero-width join is a loud raise in `eof-terminal`, so this
  # mutant is caught by the raise that arm exists to make. AGENTS.md prefers a
  # comparison to a raise because a raise usually depends on where the mutant
  # happens to crash -- here it crashes at exactly the decision's own site,
  # which is the case that preference exempts.
  EXPECT_OUTPUT_MATCHES "case raised -- Exception in eof-terminal: empty zero-width join")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pause continuations join the zero-progress walk"
  # Bare "zero-progress-cycle" is a substring of three other check labels in
  # this file ("eof-zero-progress-cycle diagnostic" and "zero-progress-cycle
  # diagnostic" are each a distinct decision), so it does not by itself prove
  # which one failed. Measured: this mutation's own primary witness is the
  # reexecute/pause-only cycle case; pinned to it.
  #
  # SUBSUMED by "verify: zero-progress detection never fires": dropping the
  # pause arm from PASS 5's reexec-targets can only REMOVE zero-progress-cycle
  # diagnostics, and that mutation removes all of them, so every FAIL record
  # this mutant emits is also that one's. This mutant lacks two of that one's
  # records -- the pure byte-dispatch self-loop and arm 3's sequence-mismatch
  # cycle, neither of which needs a pause arm to be found. Left pinned to the
  # check that states this decision.
  FIND [[((pause-node? n) (list (pause-node-continuation n)))]]
  REPLACE [[((pause-node? n) '())]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "cycle with no advance makes no progress: zero-progress-cycle diagnostic")

# The PASS 5 filter guard's `(pause-node? n)` disjunct. The reexecute/
# pause-only cycle fixture above has the byte-dispatch node `e0` itself in the
# cycle, so narrowing the guard back to byte-dispatch-only still flags `e0` and
# that fixture's diagnostic-code check passes either way -- a guard shown not
# to guard. The witness is a pause cycle with NO byte-dispatch node in it,
# which PASS 5 flags only when the disjunct admits pause nodes.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause-only zero-progress cycle is not flagged"
  # Bare "zero-progress-cycle" is shared with three other check labels in this
  # file (see the mutation above); pinned to this decision's own witness case.
  #
  # Recorded SUBSUMED by both "verify: zero-progress detection never fires" and
  # "verify: pause continuations join the zero-progress walk", by exhaustion
  # over the pass. The three edits nest by construction: narrowing PASS 5's
  # report FILTER stops pause nodes being flagged; narrowing its WALK (the
  # mutation above) stops pause nodes AND the dispatch nodes whose cycle runs
  # through one; disabling the check stops everything. The REPLACE drops only
  # the pause clause -- every other kind in the guard stays -- so it does not
  # duplicate "verify: a self-targeting sequence node is not reported as a
  # zero-progress cycle (§25:1533)" below.
  #
  # OPEN: no separating check has been attempted, so this is an
  # under-specified SPEC, not a closed residue -- verify-tests.sps has no case
  # on which dropping the pause clause of the report guard produces a number,
  # or a diagnostic set, that dropping the walk or the whole check does not.
  # The likely remedy is count-don't-witness. The three-cycle case cannot
  # serve: it contains no pause cycle, which is why this mutant leaves it at
  # the correct 3. A fixture must separate this edit from BOTH siblings, and
  # the walk mutation is the harder half: the report guard's pause clause and
  # the walk's pause arm remove overlapping sets of reported nodes, so a
  # fixture holding only self-cycles will not tell them apart -- it needs a
  # cycle that runs THROUGH a pause without being one, which the walk mutation
  # kills and this one does not. No candidate fixture has been run.
  FIND [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[(and (or (byte-dispatch-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  # The witness is a BYTE-reachable pause cycle: an EOF-only pause cycle is
  # excluded from the byte-reachability gate on purpose.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a BYTE-reachable pause cycle is still a zero-progress cycle")

# The sequence-dispatch node kind at verify.sls's permissive fall-throughs, one
# mutation per arm in this same Pass 33: a silently-clean verifier is the
# hazard, and each arm needs its own witness that reddens when it is removed.
# Every EXPECT_OUTPUT_MATCHES below is measured by running the mutant, never
# predicted.
#
# Arm 5 (eof-terminal's sequence-dispatch-node? branch) and the start-set
# narrowing ("the eof-reachable-stops start set enumerates a kind instead of deriving the EOF
# route", below) share one FAIL record: the self-loop fixture ("an eof chain
# that cycles through a sequence node is an EOF cycle") is broken by EITHER --
# with 'seq excluded from the start set, eof-terminal is never even called
# starting from it, so arm 5's own inner branch is moot and the two mutants'
# captured output for that one case is byte-identical. A second fixture -- a
# genuine two-node cycle entered from a BYTE-DISPATCH node, which is in the
# start set either way -- separates them: arm 5's mutant still fails it (the
# walk stops at the sequence node and the cycle is never closed) while the
# start-set narrowing leaves it green. Each is pinned to the one fixture that
# is not also broken by its sibling.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's case and mismatch targets are not out-targets (arm 1, node-out-targets)"
  # node-out-targets is a derived view of node-out-edges, whose arms yield
  # (role . target) pairs; this mutation empties the sequence arm.
  FIND [[          ((sequence-dispatch-node? n)
           (append (map (lambda (c) (cons 'alternative (sequence-case-target c)))
                        (sequence-dispatch-node-cases n))
                   (list (cons 'mismatch
                               (edge-target (sequence-dispatch-node-mismatch n))))))]]
  REPLACE [[          ((sequence-dispatch-node? n) '())]]
  # Comparison-caught: with the arm removed, the sequence case and mismatch
  # edge targets ('stop and 'reject) are never fed to node-out-targets, so
  # pass-reachability treats both as unreached. The mutant also breaks the
  # case-target case, the mismatch-target sibling and the byte-into-finish
  # case, since node-out-targets feeds all of them.
  #
  # The pin is this mutant's one record that no other Pass 33 mutant produces,
  # computed as a set difference against every other mutant in the pass rather
  # than against a suspected sibling. The nearer candidates collide: the
  # case-target check with "a missing transition target is not reported", and
  # the well-formed control's `expected 0, got 2` with "the reason repertoire
  # rejects every reason", which adds one invalid-name diagnostic per
  # declaration on a fixture that declares two. A count is a weaker anchor than
  # a named check: another mutant can reach the same number by another route.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a node reached only through the sequence eof-target is reachable: no unreachable-node -- expected 0, got 2")

# The decision this mutation names -- a sequence node's eof-target feeds the
# reachability walk -- is not witnessed by the "reachability is the occupiable
# relation" group's sequence-dispatch pair. In that pair `T`'s own eof-target
# is the error node, which is already byte-reached, so the walk's answer is
# identical with or without `node-eof-target`'s sequence arm; what the pair
# witnesses is that the walk does not take `T`'s BYTE edge. Without this
# mutation, the case "a node reached only through the sequence eof-target is
# reachable" is reddened only by two mutants -- "a sequence node's case and
# mismatch targets are not out-targets (arm 1)" and "node-out-targets returns
# the roles instead of the targets" -- and BOTH name the byte half, each
# emitting `got 2` where this one emits `got 1`.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's eof-target does not feed reachability (arm 2, eof-step)"
  # `eof-step` is the one reader of `node-eof-target` for the reachability and
  # pass-7 walks. The REPLACE reproduces byte-dispatch-only behaviour by gating
  # the contribution, not by narrowing the helper -- so the mutant differs from
  # the baseline in exactly one thing, which kind's EOF route the walk follows.
  FIND [[  (define (eof-step n)
    (let ((t (node-eof-target n)))
      (append (if (symbol? t) (list t) '()) (eof-successors n))))]]
  REPLACE [[  (define (eof-step n)
    (let ((t (node-eof-target n)))
      (append (if (and (byte-dispatch-node? n) (symbol? t)) (list t) '())
              (eof-successors n))))]]
  EXPECT_STATUS 1
  # Comparison-caught, and the record is UNIQUE across the pass: this mutant
  # emits `got 1` on that case where the two mutants naming the BYTE half emit
  # `got 2`. It also reddens three cases whose kinds lose their EOF route for
  # the same reason (two accumulate, one counted) -- the decision reaches them,
  # so this is a discrimination and not a crash.
  EXPECT_OUTPUT_MATCHES
    "sequence dispatch reaches every verifier arm.a node reached only through the sequence eof-target is reachable: no unreachable-node -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's reexecute mismatch edge is invisible to the zero-progress walk (arm 3, reexec-targets)"
  FIND [[              ((sequence-dispatch-node? n)
               (if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
                   (list (edge-target (sequence-dispatch-node-mismatch n))) '()))
]]
  REPLACE [[              ]]
  # Comparison-caught: with the arm removed, reexec-targets no longer sees
  # through the sequence node, so the dispatch node's own reexecute-only
  # cycle through it goes undetected.
  #
  # The bare zero-progress-cycle record is shared with "verify: zero-progress
  # detection never fires", so the pin is a count. verify-tests.sps's "a
  # byte-dispatch self-loop, a dispatch-through-sequence cycle and the sequence
  # node itself are three zero-progress cycles" puts an INDEPENDENT plain
  # self-loop (a decision only "zero-progress detection never fires" touches)
  # beside the cycle through the sequence node and counts all three. With this
  # arm removed, 'x's plain self-loop is still found, 'start no longer reaches
  # itself, and 'seq is not reported -- 1, a value no other mutant in this pass
  # produces on this check. The check is four-way (3 / 2 / 1 / 0); see the
  # case's own comment for the table.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the sequence mismatch edge's MODE is not tested (arm 3, reexec-targets)"
  # Arm 3's mutation above deletes the WHOLE arm, so it never tests the arm's
  # own `if`: whether a sequence node's mismatch target joins the zero-progress
  # walk is conditional on the edge's MODE, and that condition is what keeps an
  # ADVANCE-mode self-target accepted -- an advance edge consumes the
  # mismatching byte, so the cycle makes progress. verify-tests.sps's advance
  # case is what stops the report guard from being widened past the mismatch
  # edge's mode, and this mutation is what shows it does.
  # `(if #t` rather than `(if #f`, per AGENTS.md's opposite-constant rule:
  # `(if #f` reproduces arm 3's own deletion and would be a second copy of it,
  # while `(if #t` makes self-cycle report the advance fixture and is
  # caught by a failed comparison on a case that passes in the baseline.
  # This mutant fails three checks, all on the advance case and nothing else.
  #
  # The pin is the attribution check. The diagnostic count -- "expected 0, got
  # 1" -- is reached three ways: "a sequence node's case and mismatch targets
  # are not out-targets (arm 1, node-out-targets)" reddens the same two checks
  # with an unreachable-node on 'stop, and "a sequence alternative is compared
  # against itself" with an ambiguous-sequence-prefix. The advance case's "no
  # zero-progress-cycle" check (see its own comment for the table of three
  # diagnostics) is the one record of the three this mutant emits that is unique
  # lane-wide. The pin carries the case-name tail as well as the check label
  # because the bare string "zero-progress-cycle" is a substring of nine other
  # check labels and one case name in verify-tests.sps (measured over its
  # `check`, `check-equal`, `harness-case` and `harness-group` labels, excluding
  # this mutation's own "no zero-progress-cycle"); no regex metacharacter
  # appears in the pin.
  FIND [[(if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "advance mismatch edge is a consuming cycle and passes: no zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a self-targeting sequence node is not reported as a zero-progress cycle"
  # The REPORT set, not the walk: arm 3 above mutates reexec-targets and lands
  # on "got 1", "zero-progress detection never fires" lands on "got 0", and
  # this one lands on "got 2" -- three distinct values on one check, all
  # measured, none predicted. Comparison-caught: the count check fails outright
  # rather than depending on where a mutant happens to crash.
  FIND [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (sequence-dispatch-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))]]
  REPLACE [[(and (memq (node-name n) br898)
                                     (or (byte-dispatch-node? n) (pause-node? n)
                                         (keyword-table-node? n)
                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence node's eof-target is not resolution-checked (arm 4, pass-eof)"
  # pass-eof reads the shared node-eof-target helper (see arm 2 above); the
  # REPLACE reproduces byte-dispatch-only behaviour by gating the call.
  FIND [[              (map (lambda (n)
                     (let ((t (node-eof-target n)))
                       (if (or (eq? t #f) (lookup nodes t)) '()
                           (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                  "eof-target names no node")))))
                   nodes)))))]]
  REPLACE [[              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (let ((t (node-eof-target n)))
                           (if (or (eq? t #f) (lookup nodes t)) '()
                               (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                      "eof-target names no node"))))
                         '()))
                   nodes)))))]]
  # Comparison-caught: with the arm reverted to byte-dispatch-only, a
  # sequence node's dangling eof-target is never checked against the node
  # table, so invalid-eof-target never fires. A clean, single-case witness.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a sequence eof-target that names no node is invalid-eof-target: invalid-eof-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal does not classify a sequence node reached mid-chain (arm 5)"
  # The REPLACE answers a terminal verdict rather than deleting the arm, which
  # keeps the mutation COMPARISON-caught: dropping the arm entirely would reach
  # eof-terminal's raising `else` and kill the mutant by assertion-violation
  # instead of by the wrong classification this pin names.
  FIND [[                ((sequence-dispatch-node? n)
                 (dispatch-arm (sequence-dispatch-node-eof-target n) path))]]
  REPLACE [[                ((sequence-dispatch-node? n) (verdict 'default-error path))]]
  # Comparison-caught: with the arm replaced, the walk stops the moment it
  # reaches a sequence node, so a cycle that must pass back OUT through that
  # node's own eof-target is never closed. Not pinned on the self-loop
  # fixture, whose record is shared with the start-set narrowing (see the
  # header note), nor on the bare two-node (byte-dispatch <-> sequence)
  # fixture, whose record is shared with "verify: an eof-target cycle is
  # classified as a finish terminal" (which disables eof-terminal's own
  # `(memq name seen)` cycle guard outright).
  #
  # The pin is a count. verify-tests.sps's "a byte-dispatch eof self-loop and
  # a two-node dispatch/sequence eof cycle are three eof-zero-progress cycles"
  # puts an INDEPENDENT byte-dispatch eof self-loop (a decision only the
  # cycle-guard mutant touches) beside the two-node cycle, which is entered
  # from the byte-dispatch node's own eof-target and so is unaffected by the
  # start-set narrowing. Correct code reports 3; the cycle-guard mutant reports
  # 0; this mutation still finds the self-loop's own cycle but no walk through
  # the sequence node closes, reporting 1 -- a value no other mutant in the
  # pass produces on this check. A fixture local to the sequence node (a
  # self-referencing 'seq) does not separate this mutation from the start-set
  # narrowing: both report 1 on it.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a byte-dispatch eof self-loop and a two-node dispatch/sequence eof cycle are three eof-zero-progress cycles: eof-zero-progress-cycle count -- expected 3, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the sequence-ambiguity pass is never run"
  FIND [[                                  (pass-sequence-ambiguity machine)]]
  REPLACE [[                                  '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the terminal-prefix test is one-directional"
  # Comparison-caught. The pair test must ask BOTH directions: a caller may
  # declare the longer alternative first, and normal-ir-tests.sps's own
  # "reverse order" case exists because the trie has two distinct guard sites
  # for exactly this. Measured: the summed check goes 6 -> 3, a value no other
  # mutant in this pass produces on it. A per-ordering check would NOT separate
  # this mutation from "never run" -- its records would be a strict subset.
  FIND [[                                 (if (or (byte-prefix? (car as) (car others))
                                         (byte-prefix? (car others) (car as)))]]
  REPLACE [[                                 (if (byte-prefix? (car as) (car others))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 3")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the prefix relation degenerates to a first-byte test"
  # The OVER-rejection direction, which no other mutation in this pass reaches:
  # with the recursion collapsed, any two alternatives sharing a first byte are
  # called ambiguous, and every branching machine would be refused. Measured:
  # the well-formed AB/AC/XY fixture goes 0 -> 1.
  FIND [[((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b)))]]
  REPLACE [[((= (car a) (car b)) #t)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "alternatives that merely share a prefix are not ambiguous: ambiguity count -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only the first sequence alternative is compared against the others"
  # The sequence twin of pass-overlap's own "verify: only the first case is
  # compared against the others". Measured on the nested-family fixture: 4 -> 2.
  FIND [[(scan (cdr as)]]
  REPLACE [[(scan '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence alternative's collisions after the first are dropped"
  # The twin of pass-overlap's "verify: a case's collisions after the first are
  # dropped". Measured: 4 -> 3. Note this and the mutation above are
  # indistinguishable on the summed check (both 4) and on either per-ordering
  # count (both 2); only the nested-family fixture, which makes the two walks
  # visit different pair sets, separates them.
  FIND [[(against (cdr others)]]
  REPLACE [[(against '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 3")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence alternative is compared against itself"
  # The twin of pass-overlap's "verify: a case is compared against itself".
  # Every alternative is a terminal prefix of itself, so self-comparison adds
  # exactly one spurious diagnostic per alternative. Measured: 4 -> 9 on a
  # five-alternative fixture.
  FIND [[(let against ((others (cdr as)) (found found))]]
  REPLACE [[(let against ((others as) (found found))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 9")

# Mutations for pass-fields, the field-declaration checks: one permissive
# mutation per check, one restrictive mutation per check -- the direction that
# makes the pass's clean-premise case load-bearing rather than decorative --
# and the join that wires the pass in at all.
#
#   * Dropping `(pass-fields machine)` from verify-machine's append: its record
#     set is exactly the UNION of the two permissive mutants', and a union is
#     contained in NEITHER of the two sets it unions, so it is separable by a
#     conjunction of one record from each.
#   * The duplicate check made restrictive: three records, all in one group.
#     Neither its set nor the restrictive-portable mutant's contains the other
#     -- this mutant emits `nonportable ... got 2`, which the
#     restrictive-portable mutant does not, and that one emits `two fields ...
#     got 3`, which this one does not.
#
# The join's and the restrictive mutants' pins are CONJUNCTIONS, because each
# mutant's individual records are shared with a sibling and only the pair is
# unique.

# Both field diagnostics carry the offending field name in the `node` slot.
# verify-tests.sps's `codes` helper maps diagnostic-code and is blind to that
# slot, so a `nodes-of` helper and two cases read it; these are their mutations.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the duplicate-field diagnostic does not name the field"
  FIND [[(make-diagnostic/declarations 'invalid-field-declaration fname]]
  REPLACE [[(make-diagnostic/declarations 'invalid-field-declaration #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the duplicate diagnostic names the offending FIELD: the field name -- expected \\(count\\), got \\(#f\\)")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the nonportable-field diagnostic does not name the field"
  FIND [[(make-diagnostic/declarations 'invalid-field-declaration (uint-field-name f)]]
  REPLACE [[(make-diagnostic/declarations 'invalid-field-declaration #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the nonportable diagnostic names the offending FIELD: the field name -- expected \\(Count\\), got \\(#f\\)")

# Four pinned mutations and one survivor for eof-terminal's multi-successor
# walk. Every one of them needs a kind with more than one successor: against
# single-successor kinds all five would be unwitnessable.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: sibling EOF answers take the first arm instead of the max"
  # *** This is the UNION mutant: taking the first arm means neither a branch's
  # false target nor an action's error target is walked, so its record set is
  # exactly the union of the two arm mutations below and is contained in
  # NEITHER. *** AGENTS.md's relation is "inside ONE sibling's", so it is
  # separable, and the conjunction is what separates it -- one record from each
  # arm, which no single-arm mutant can produce together.
  FIND [[                      (if acc (eof-verdict-join acc v) v))))))]]
  REPLACE [[                      (if acc acc v))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "one arm cycling is a cycle even though the other finishes: cycle -- expected a true value.*a field action's error target is walked too: reachable stop -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field branch's false target is not an EOF successor"
  # SUBSUMED BY the union mutant above, by construction -- taking the first arm
  # does everything this does and more. Kept because it names its own decision.
  # Anchored in `zero-width-successors`, the single definition all three
  # consumers share.
  FIND [[          ((field-branch-node? n)
           (list (cons 'true (field-branch-node-true-target n))
                 (cons 'false (field-branch-node-false-target n))))]]
  REPLACE [[          ((field-branch-node? n)
           (list (cons 'true (field-branch-node-true-target n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "one arm cycling is a cycle even though the other finishes: cycle -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field action's error target is not an EOF successor"
  # The other half of the union, and the reason a field ACTION is multi-successor
  # too: a walk following only `next` misses a stop sitting behind a failure.
  FIND [[                 (list (cons 'next (field-action-node-next n)) (cons 'error e))
                 (list (cons 'next (field-action-node-next n))))))]]
  REPLACE [[                 (list (cons 'next (field-action-node-next n)))
                 (list (cons 'next (field-action-node-next n))))))]]
  EXPECT_STATUS 1
  # A CONJUNCTION. `zero-width-successors` feeds THREE consumers, so each of its
  # records is shared with a mutant of one consumer: the EOF record with
  # "sibling EOF answers take the first arm", the reachability record with "a
  # zero-width node's targets are not out-targets". Only the pair is this
  # mutation's own.
  EXPECT_OUTPUT_MATCHES
    "a field action's error target is walked too: reachable stop -- expected a true value.*a zero-width node's targets are out-targets, so they are reachable: nothing unreachable")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: cycle no longer outranks eof-reachable-stop in the join"
  # The one relation the verdict ranking must hold: a cycle is the
  # non-termination neither runtime loop guards against, so it must survive a
  # join. Pinned on the MIRRORED arm order, which is the record that separates it
  # from "the false target is not walked" -- a mutant that walks only the true
  # arm answers this fixture correctly and the other one wrongly.
  # The ranking is three tiers, so `cycle` outranking `eof-reachable-stop` is a
  # tier assignment; swapping the two tiers inverts it in one token.
  FIND [[      (eof-reachable-stop)
      (cycle)))]]
  REPLACE [[      (cycle)
      (eof-reachable-stop)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "cycle outranks eof-reachable-stop in the OTHER arm order too: cycle -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF walk keeps no completed-set"
  FIND [[              ((assq name done) => cdr)
]]
  REPLACE [[              ]]
  EXPECT_SURVIVES
    "measured, not assumed: this mutant passes the whole verify lane unchanged. The completed-set is the walk's SECOND structure and its job is complexity, not correctness -- the path stack alone already answers every verdict correctly, because the only path-dependent answer is `cycle` and a re-visit off the current path re-derives the same verdict rather than a different one. What the set buys is that a diamond costs one visit instead of two, and a chain of k diamonds costs k instead of 2^k, which is exactly the cost of a walk that keeps only the path stack. No assertion over verdicts can see a difference, because there is none. A TIMING witness was considered and declined: a chain of ~25 branch nodes makes the mutant take 2^25 walks and blow the lane's TIMEOUT, but a catch that depends on how fast the host is is not a catch this suite can state, and a nonzero exit is not proof. Reopening condition: if the walk is given a verdict that DOES depend on which path reached a node, the memo stops being sound and this mutation stops being a survivor -- it becomes a bug detector, and must be re-measured then rather than inherited. The condition has since FIRED and this was re-measured, not inherited. The walk now answers a `(verdict path)` pair, so which route reached a node IS observable -- but the mutant STILL SURVIVES (verify-tests 184/184, status 0 with the line deleted). Why no fixture separates it: `eof-verdict-join` folds its operands left-to-right and keeps the LEFT on a tie, so the winning operand's path is always the one computed first, before any node it shares with a later operand is memoised; the memo can only ever return a stale path to a LOSING right operand. A re-convergent fixture (a parked node whose two eof-successors both reach one node that then reaches a stop) was reasoned through and reports the same path with the memo present or absent, because the left branch wins the tie and its path is fresh either way. The reopening condition is now satisfied at the path level and the answer is the same: sound, and unwitnessed, for the same structural reason as before -- one level deeper."
  )

# Five mutations for the zero-width census (further below). Two of them are a
# WALK/REPORT pair, and they need a fixture of their own to be separable at
# all -- see the middle two.

# Six mutations for the input-reading kind's (integer-accumulate) census.
#
# *** The two zero-progress disjuncts have SEPARATE fixtures. *** Both the
# overflow edge and a `reexecute` nondigit edge are non-consuming, so either
# can close a zero-progress cycle; cutting the arm to one disjunct makes a
# self-targeting edge of the other kind verify with ZERO diagnostics. Each
# disjunct's mutation fails only its own fixture, which one shared fixture
# would hide.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's OVERFLOW edge is invisible to the zero-progress walk"
  # An overflow is non-consuming and leaves the field unchanged, so an
  # overflow-error naming its own node re-reads the same byte forever -- and
  # neither runtime loop guards against it.
  FIND [[                (list (integer-accumulate-node-overflow-error n))))]]
  REPLACE [[                '()))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census.an accumulate whose OVERFLOW edge targets itself is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's NONDIGIT reexecute edge is invisible to the zero-progress walk"
  # The nondigit disjunct. Its own fixture, because the overflow mutation
  # above passes this one and vice versa.
  FIND [[                (if (eq? (edge-mode (integer-accumulate-node-nondigit-edge n)) 'reexecute)
                    (list (edge-target (integer-accumulate-node-nondigit-edge n)))
                    '())]]
  REPLACE [[                '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census.an accumulate whose NONDIGIT edge reexecutes into itself is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the accumulate DIGIT edge wrongly joins the zero-progress walk"
  # The restrictive direction, and the reason the digit edge stays out:
  # the digit edge always advances, so a machine looping on digits makes
  # progress and must not be reported.
  FIND [[                (list (integer-accumulate-node-overflow-error n))))]]
  REPLACE [[                (list (integer-accumulate-node-overflow-error n)
                      (integer-accumulate-node-digit-target n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census.the DIGIT edge self-targeting is not a cycle -- it advances: no cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the accumulate kind"
  # SUBSUMED BY either walk mutation above, by construction and in the nesting
  # this file already records for the pause kind -- narrowing the report stops
  # the accumulate node being flagged, narrowing a walk stops that AND every node
  # whose cycle runs through one. Kept because shipping one without the other is
  # the half-fix this pass exists to prevent.
  FIND [[                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census.an accumulate whose NONDIGIT edge reexecutes into itself is a zero-progress cycle: zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's byte targets are not out-targets"
  # Three of its four explicit targets are byte out-targets; the fourth,
  # eof-target, belongs to node-eof-target so that `eof-step` -- which reads
  # it for the reachability walk -- adds it and the byte-into-finish check does
  # not see it. node-out-targets is a derived view of node-out-edges, whose
  # arms yield (role . target) pairs.
  FIND [[          ((integer-accumulate-node? n)
           (list (cons 'digit (integer-accumulate-node-digit-target n))]]
  REPLACE [[          ((integer-accumulate-node? n)
           (list]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census.an accumulate's three byte targets are out-targets, so they are reachable: nothing unreachable")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an accumulate's field reference is not checked"
  # Not a `field-operand-schemas` row: that table is keyed on a selector and an
  # arity and an accumulate node has neither. Reported under the NODE's name,
  # matching the operand walk's own convention, so one code carries one
  # convention.
  FIND [[    (if (field-width-of fs (integer-accumulate-node-field n))]]
  REPLACE [[    (if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the input-reading kind in the verifier census.an accumulate naming no declared field is invalid-field-operand: invalid-field-operand")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a zero-width node's targets are not out-targets"
  # node-out-targets feeds name resolution, reachability AND the
  # byte-into-finish check, so this one arm missing makes a well-formed machine
  # report defects it does not have and hides one it does. The REPLACE keeps
  # the disjunct list intact so the mutant differs from the baseline in ONE
  # thing -- the arm's answer.
  FIND [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (zero-width-edges n))]]
  REPLACE [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           '())]]
  EXPECT_STATUS 1
  # Pinned on the case's SECOND machine, where the zero-width node is reached
  # by a byte edge from the entry. On the first machine the field-action node
  # IS THE ENTRY, which is a parked node, so `eof-step` (which reads
  # `zero-width-edges` directly) visits its successors on the EOF walk and that
  # check stays green under this mutant. Nothing is parked on the second
  # machine's zero-width node, so the arm under test is the only route to the
  # stop. One whole measured record, no `.*`.
  EXPECT_OUTPUT_MATCHES
    "the zero-width census.a zero-width node's targets are out-targets, so they are reachable: and reachable through a zero-width node the entry only reaches by a byte edge -- expected .., got ..unreachable-node . after..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress WALK does not follow a zero-width node"
  # Pinned on the through-a-dispatch fixture, which is the record the REPORT
  # mutation below cannot produce: there the cycle's reported member is the
  # byte-dispatch node, which stays in the report set either way, so narrowing
  # the report leaves that diagnostic standing while narrowing the walk removes
  # it. That fixture exists FOR this separation -- without it the two mutants
  # emit identical records. Deleting the arm stops the walk following every
  # zero-width kind it lists.
  FIND [[              ((or (field-action-node? n) (field-branch-node? n)
                   (callback-node? n)
                   (span-start-node? n) (span-end-node? n))
               (zero-width-successors n))
]]
  REPLACE [[              ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a cycle running THROUGH a zero-width node is attributed to the dispatch: attributed to start")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the zero-width kinds"
  # SUBSUMED BY the walk mutation above, by construction and in the same nesting
  # this file already records for the pause kind: narrowing the REPORT stops the
  # zero-width nodes being flagged, narrowing the WALK stops those AND every node
  # whose cycle merely runs through one. Each removes a superset of the last, so
  # there is no record the narrower one owns. Kept because the two are distinct
  # decisions and shipping only one of them is the defect this pass exists to
  # prevent -- a `store`-into-itself machine that verifies clean and then hangs.
  FIND [[                                         (field-action-node? n) (field-branch-node? n)
                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a zero-width self-cycle is a zero-progress cycle: zero-progress-cycle")

# Eight mutations for pass-fields' operand half. Three by-construction
# subsumptions are recorded at their own sites: each is a NARROWER edit of a
# check a broader mutation already removes, and each is kept because it names its
# own decision.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: field operand arity is not checked"
  # The check the constructor deliberately does not make: nothing can be read
  # out of `arguments` before arity is known.
  FIND [[       ((not (= (length args) (cadr row)))]]
  REPLACE [[       ((and #f (not (= (length args) (cadr row))))]]
  EXPECT_STATUS 1
  # Pinned on the RAISE, which is this mutant's own record lane-wide and is
  # also the decision's own stated reason: arity is checked here rather than
  # in the constructor because nothing can be read out of `arguments` before
  # arity is known, and unguarded, the range check reads a third
  # element that is not there. The union mutants above produce every other
  # record this one does, but not this: with the pass gone, the range check is
  # never reached at all.
  EXPECT_OUTPUT_MATCHES
    "every predicate's arity is enforced: case raised -- Exception in caddr")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an operand naming no declared field is accepted"
  # SUBSUMED BY "the operand width is read from the first declared field"
  # below, by construction: that mutant looks up a field that always exists, so
  # it never reports an undeclared one either, and it additionally answers the
  # wrong width. Kept because the two name different decisions.
  FIND [[           ((not width)]]
  REPLACE [[           ((and #f (not width))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an undeclared field is invalid-field-operand: one -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the operand width is read from the first declared field"
  # The reason the width lookup is keyed on the operand: with one field declared
  # this is invisible, so the fixture declares TWO of different widths and asserts
  # that a value legal for the WIDE one is accepted.
  FIND [[(field-width-of fs (car args))]]
  REPLACE [[(field-width-of fs (uint-field-name (car fs)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the width checked is the REFERENCED field's, not some other field's: legal for the wide field")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: operand range against the declared width is not checked"
  # Pinned on the range fixture's TWO-fault count, which is the record the
  # off-by-one mutation below cannot produce.
  FIND [[                            (if (operand-in-width? v width) #f]]
  REPLACE [[                            (if #t #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an out-of-width range operand does not also report low > high: two width faults only -- expected 2, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the operand width bound is off by one"
  # SUBSUMED BY the mutation above, by construction -- accepting 2^w accepts
  # everything that accepting anything accepts, minus nothing this lane can see.
  # The boundary is what it names: 255 is legal for a u8 and 256 is the first
  # value that is not, so the premise case and this one together pin the edge
  # rather than "some large number is refused".
  FIND [[    (and (integer? v) (exact? v) (<= 0 v (- (expt 2 width) 1))))]]
  REPLACE [[    (and (integer? v) (exact? v) (<= 0 v (expt 2 width))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a constant above the field's declared width is invalid-field-operand: 256 -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: low > high for a range predicate is accepted"
  # The constructor accepts this and the verifier is where it is caught.
  FIND [[                      (> (cadr args) (caddr args)))]]
  REPLACE [[                      #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "low > high for range is invalid-field-operand: one -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a range's low may not equal its high"
  # The RESTRICTIVE direction, and the boundary the check actually names: the
  # test is `low > high`, not `low >= high`. Without this a `range` over a single
  # value would be rejected and nothing would notice.
  FIND [[                      (> (cadr args) (caddr args)))]]
  REPLACE [[                      (>= (cadr args) (caddr args)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "low = high for range is legal: none -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the operand half is never run"
  # The UNION mutant -- dropping the join removes every check above at once, so
  # its record set contains each of theirs and is inside none of them. Separated
  # by a CONJUNCTION: one arity record and one low/high record, which no
  # single-check mutant produces together.
  FIND [[       (pass-field-operands m fs))))]]
  REPLACE [[       '())))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "wrong arity is invalid-field-operand: too few -- expected 1, got 0.*low > high for range is invalid-field-operand: one -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass-fields is never run"
  # The JOIN. Its two records are each shared with one
  # of the two permissive mutants, and with a different one each -- so the
  # conjunction is what identifies it, and neither half alone would.
  # `'()` rather than deleting the line: the runner requires a non-empty REPLACE,
  # and an empty append arm drops the pass while keeping the form well-shaped, so
  # the mutant dies at the checks rather than at expand time.
  FIND [[                                  (pass-fields machine)]]
  REPLACE [[                                  '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 0.*a nonportable field name is invalid-field-declaration: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: every pair of fields is reported as sharing a name"
  # The duplicate check's restrictive direction, which is what makes the
  # clean-premise case load-bearing for THAT check, as the restrictive-portable
  # mutation below does for the portable check.
  FIND [[(memq fname fseen)]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 2.*distinct portable field names verify clean: no diagnostics -- expected 0, got 3")

# *** Both permissive arm mutations below are SUBSUMED BY the join mutation
# above, BY CONSTRUCTION, and are kept anyway. *** Measured: each
# arm's whole record set is a strict subset of the join's, because the join drops
# both checks and each arm drops one, so the join is strictly more permissive on
# every machine and no fixture can redden an arm while leaving the join green.
# That is the one kind of subsumption this project treats as closed rather than
# as an under-specified lane -- there is nothing to separate, not merely nothing
# found. They are kept because they name DISTINCT decisions: that the duplicate
# check fires, that the portable check fires, and that the pass is wired in at
# all. The cost is attribution, not detection: delete the join and all three
# report caught, two of them under an arm's label.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: two fields may share a name"
  # The defect the pass exists to close, which verifies CLEAN without it:
  # slot = declaration index, so two `count` fields take two slots and
  # parser-field-ref answers with whichever the name map finds first,
  # orphaning the other slot and its initial.
  FIND [[(memq fname fseen)]]
  REPLACE [[#f]]
  # Keep these bindings named apart from pass-names' node-duplicate loop, which
  # is the same shape: its `(memq nm seen)` would make this FIND match TWO
  # sites and silently mutate the node check as well.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field name is not checked against the portable grammar"
  FIND [[(valid-name? (uint-field-name f))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a nonportable field name is invalid-field-declaration: one finding -- expected 1, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: every field name is reported as nonportable"
  # The restrictive direction. Only field-carrying machines move, and this file
  # has exactly three, so the mutant emits two records rather than flooding the
  # lane. Pinned on the CLEAN one: without it a permissive-only pin set would
  # accept a pass that rejects everything.
  FIND [[(valid-name? (uint-field-name f))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  # A CONJUNCTION. The clean record alone is shared with the duplicate check's
  # restrictive mutant above, which reddens the same case with the same
  # 0-versus-3. Neither mutant's set contains the other's, so the
  # pair separates them where neither record does: this mutant reports one
  # diagnostic per field and the two-field case reaches 3, which the other never
  # does.
  EXPECT_OUTPUT_MATCHES
    "two fields sharing a name is invalid-field-declaration: one finding -- expected 1, got 3.*distinct portable field names verify clean: no diagnostics -- expected 0, got 3")

# --- Hand-enumerated kind filters. Each lists node kinds separately from
# `node-eof-target` and `node-out-targets`, with an EXPLICIT `else` or an
# implicit '(), so a missing kind is silent unless a mutation pins it.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal's classify loses its accumulate arm and raises out of verification"
  # This one raises, so a legal machine gets no verdict at all rather than a wrong
  # one, and compile-machine raises with it. Caught by a case that asserts
  # verify-machine RETURNS -- an ok?/diagnostics assertion cannot see a raise.
  FIND [[                ((integer-accumulate-node? n)
                 (dispatch-arm (integer-accumulate-node-eof-target n) path))
                (else (assertion-violation 'eof-terminal]]
  REPLACE [[                (else (assertion-violation 'eof-terminal]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an EOF chain may reach an accumulate node at all: case raised")

# --- The byte-into-finish check: ONE block, derived from the edge census ------
#
# The check is one block keyed on byte-reachability alone, reading every kind
# through node-out-edges. No mutation pins a per-kind site or a source-kind
# filter: there is none to remove or narrow independently. The shared
# finish-node? test is pinned by "reads only the first out-target" and the
# vacuous-gate pin; the gate is pinned below in both directions.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the non-eof-into-finish check is not gated on byte-reachability"
  # Measured in both directions: this mutant rejects `make-pause-machine` --
  # the canonical legal shape, an EOF-only pause continuing into a finish --
  # so that fixture's own case reddens alongside the twelve-machine battery.
  # That is the evidence the unconditional reading is wrong, wired in as a pin.
  FIND [[                       (if (memq (node-name n) br908)
                           (filter values]]
  REPLACE [[                       (if #t
                           (filter values]]
  EXPECT_STATUS 1
  # The whole measured `expected ... got ...` record of the check, not a
  # case-label prefix (a prefix is coarse enough for three mutants to satisfy):
  # under this mutant every one of the eight kinds gains `non-eof-into-finish`
  # at `hop`, beside the three `unreachable-node`s the case expects. The case's
  # sibling check "no kind reports non-eof-into-finish for the untakeable edge"
  # is the byte-into-finish rule in isolation and also reddens; either separates
  # this mutant, and the whole-list record is the stronger of the two.
  EXPECT_OUTPUT_MATCHES
    "non-eof-into-finish is gated on byte-reachability, for every kind.an EOF-only-reachable byte edge into a finish is accepted: the finish behind a dead byte edge is unreachable for the three input-reading kinds, and nothing else is reported -- expected ..byte-dispatch .unreachable-node . fin.. .sequence-dispatch .unreachable-node . fin.. .integer-accumulate .unreachable-node . fin..., got ..byte-dispatch .unreachable-node . fin. .non-eof-into-finish . hop.. .sequence-dispatch .unreachable-node . fin. .non-eof-into-finish . hop.. .integer-accumulate .unreachable-node . fin. .non-eof-into-finish . hop.. .pause .non-eof-into-finish . hop.. .field-action .non-eof-into-finish . hop.. .field-branch .non-eof-into-finish . hop.. .callback .non-eof-into-finish . hop.. .counted-consume .non-eof-into-finish . hop...")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the non-eof-into-finish gate is vacuous, so no byte edge into a finish is ever rejected"
  # The reverse direction. A gate that admits nothing passes the acceptance half
  # of the battery for the wrong reason, so the rule needs its own pin against
  # emptiness -- the shape AGENTS.md calls seeding an output before asserting it.
  FIND [[                       (if (memq (node-name n) br908)
                           (filter values]]
  REPLACE [[                       (if #f
                           (filter values]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a BYTE-reachable byte edge into a finish is rejected at its source node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the non-eof-into-finish check reads only the first of a node's out-targets"
  # `node-out-edges` is the single census this rule consults. Reading one
  # element of it is the shape that survives a per-node dedup and still misses a
  # real violation -- a dispatch whose SECOND case targets a finish.
  # The REPLACE guards the empty case: a bare `(car ...)` raises on every node
  # with no out-edges, so most of the lane fails with the identical
  # "Exception in car: () is not a pair" -- a crash, not the decision the label
  # names. Guarded, the mutation is total (it still reads one edge of many) and
  # the failure is a comparison on the case that names the decision.
  FIND [[                                        (node-out-edges n)))
                           '()))
                     nodes)))]]
  REPLACE [[                                        (let ((es (node-out-edges n)))
                                          (if (null? es) '() (list (car es))))))
                           '()))
                     nodes)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a byte-dispatch's case and fallback into one finish are two distinguishable findings")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the entry being a finish terminal is not rejected"
  # The zero-hop case. Kept as its own clause and its own pin rather than folded
  # into the per-edge loop, because it is an independently revertible decision:
  # the rule's words are about control flow INTO a node, and reading the entry
  # as "reached by parser-feed!" is an interpretation. If that reading is ever
  # reversed, this is the one line to remove.
  FIND [[         (if (and en (finish-node? en))]]
  REPLACE [[         (if (and en (finish-node? en) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a machine whose entry IS a finish node is rejected, once, at the entry")

# --- The EOF-shape walk starts from the PARKED set ------------------------------
#
# One walk over the states a parser can be parked on, classifying each node as
# ITSELF, rather than per-kind blocks classifying each kind's eof-TARGET. A
# pause is in the parked set and is classified through the same eof-terminal
# call under the same gate, pinned below in both directions. The derived
# `(symbol? (node-eof-target n))` disjunct replaces a per-kind source filter
# and has its own pin below. The parked-set membership and `span-flow`'s copy
# are ONE `parked?` procedure, so each start-set mutation below reaches all
# three consumers (pass 6, pass 7, `occupiable`).

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF-chain walk does not start at the entry"
  # Without the entry in the start set, a machine whose entry is itself a stop
  # -- or a zero-width node leading to one -- verifies with ZERO diagnostics
  # and `parser-finish!` returns `stopped`.
  FIND [[         (or (eq? (node-name n) (machine-entry m))]]
  REPLACE [[         (or #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an entry whose own EOF path reaches a stop is rejected: each rejected exactly once, at the entry")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF-chain start set is not gated on byte-reachability"
  # The parked set is parkable states, not graph nodes. Ungated, nodes no
  # execution can occupy start walks -- an over-approximation the gate narrows.
  FIND [[    (and (memq (node-name n) br)]]
  REPLACE [[    (and #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an EOF chain of pauses that cycles is a zero-progress EOF cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF-chain start set enumerates a kind instead of deriving the EOF route"
  # A per-kind census as a mutant. Narrowing the derived disjunct back to one
  # kind is the shape that silently drops every other kind's walk -- a sequence
  # node's, an accumulate node's.
  FIND [[             (symbol? (node-eof-target n)))))]]
  REPLACE [[             (byte-dispatch-node? n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an eof chain that cycles through a sequence node is an EOF cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an EOF cycle through pause continuations is not reported"
  # Without its fixture, deleting this clause leaves every runnable program in
  # the tree byte-identical. It is the only site that can attribute an EOF
  # zero-progress cycle to a PAUSE node; the fixture's machine deliberately has
  # no dispatch eof-target chain (its entry's eof route is a finish).
  # parser-finish-op! relies on these checks for termination, so the shape
  # this clause rejects is one that loops forever in both executors.
  FIND [[                               ((cycle)
                                (list (make-diagnostic/path 'eof-zero-progress-cycle (node-name n)
                                                            "an EOF path cycles without reaching a terminal"
                                                            path)))]]
  REPLACE [[                               ((cycle) '())]]
  EXPECT_STATUS 1
  # A CONJUNCTION of two whole measured records no sibling produces together.
  # The bare check label "…AT A PAUSE NODE: at least one, at a pause" is not
  # enough: "the parked set loses the pause disjunct" and two other mutants
  # also redden it.
  EXPECT_OUTPUT_MATCHES
    "EOF terminals and eof-target verification.an eof-target cycle is rejected .eof-zero-progress-cycle.: has eof-zero-progress-cycle -- expected a true value.*the thirteenth kind in the verifier census.a self-targeting eof-target is an EOF zero-progress cycle: eof-zero-progress-cycle, at the node -- expected ..eof-zero-progress-cycle . body.., got .[)]")

# --- The diagnostic's edge/source label ---------------------------------------

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: every non-eof-into-finish finding is labelled `case` regardless of which edge produced it"
  # A constant label is the failure mode a label invites: present, plausible, and
  # carrying no information. It passes any check that merely asserts the slot is
  # non-#f, which is why the fixtures assert the whole (code node edge) triple.
  FIND [[                                                 (car re)]]
  REPLACE [[                                                 'case]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a byte-dispatch's case and fallback into one finish are two distinguishable findings")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: node-out-targets returns the roles instead of the targets"
  # The census and its derived view must not drift apart. `node-out-edges` is
  # the one census; `node-out-targets` is `(map cdr ...)` of it. Taking `car`
  # instead is the shape a hand-written second census would have had to get
  # right, and it breaks reachability and byte-into-finish together -- which is
  # the argument for deriving the view rather than writing it twice.
  FIND [[  (define (node-out-targets n) (map cdr (node-out-edges n)))]]
  REPLACE [[  (define (node-out-targets n) (map car (node-out-edges n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a finish node reachable only via an eof-target verifies")

# --- The EOF verdict tiers ----------------------------------------------------
#
# A flat six-element ranking has 720 orderings, of which 24 are observationally
# identical, so permutation mutations of it survive. Three tiers make those 24
# UNWRITABLE rather than something to declare EXPECT_SURVIVES, and each tier
# assignment is a single-token mutation caught by a failed comparison.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-reachable-stop is promoted into the benign tier"
  # The EOF-shape check's whole verdict, demoted to tie with the verdicts that
  # mean "the chain terminates". Every join then masks it -- three fixtures
  # redden.
  FIND [[    '((finish unresolved error default-error)
      (eof-reachable-stop)]]
  REPLACE [[    '((finish unresolved error default-error eof-reachable-stop)
      ()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an `error` sibling does not mask the stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: default-error is promoted out of the benign tier"
  # The acceptance hole, as a pin. Promoting `default-error` above the benign
  # tier is one step from promoting it above `cycle`, which was MEASURED to make
  # a field-branch machine verify with zero diagnostics while `parser-finish!`
  # never returns. One token, and the only fixture that moves is the one whose
  # sibling verdict is `default-error` -- which is what makes it this pin's own.
  FIND [[    '((finish unresolved error default-error)
      (eof-reachable-stop)]]
  REPLACE [[    '((finish unresolved error)
      (eof-reachable-stop default-error)]]
  EXPECT_STATUS 1
  # A conjunction of two whole measured records; a bare case-name prefix is
  # satisfied by a dozen mutants. Residue, measured and named: "verify: an
  # EOF-reachable stop terminal is accepted" and "verify: eof-reachable-stop is
  # promoted into the benign tier" still satisfy it -- both stop
  # `eof-reachable-stop` being reported at all, so every check this mutant
  # reddens they redden too. The subset relation was computed in BOTH
  # directions; it holds one way only, so this is subsumption rather than
  # under-anchoring.
  EXPECT_OUTPUT_MATCHES
    "a benign EOF verdict never outranks a stop in a join.a `default-error` sibling does not mask the stop: eof-reachable-stop survives the join -- expected ..unreachable-node . rj2. .eof-reachable-stop . s0.., got ..unreachable-node . rj2...*the thirteenth kind in the verifier census.the flow-through zero-count stop at the ENTRY is rejected: eof-reachable-stop, at the entry -- expected ..eof-reachable-stop . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: unresolved is promoted out of the benign tier"
  # This tier assignment is LOAD-BEARING: `classify` answers `'unresolved` for
  # an EOF successor naming no node, and a machine whose chain reaches a
  # dangling name AND a stop reports the stop only because `unresolved` loses
  # the join.
  FIND [[    '((finish unresolved error default-error)
      (eof-reachable-stop)
      (cycle)))]]
  REPLACE [[    '((finish error default-error)
      (eof-reachable-stop)
      (cycle unresolved)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an UNRESOLVED sibling does not mask the stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-width kinds report one role for all their edges"
  # Without a pin, a role could be wired to the wrong accessor, or to a
  # constant, without anything failing. That is the same shape as a label that
  # is always present: there, carrying no information; here, carrying the wrong
  # one. The REPLACE keeps every disjunct, so the mutant differs from the
  # baseline in ONE thing -- the labels -- which is what this LABEL claims and
  # what its pin can prove.
  FIND [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (zero-width-edges n))]]
  REPLACE [[          ((or (field-action-node? n) (field-branch-node? n)
               (callback-node? n)
               (span-start-node? n) (span-end-node? n))
           (map (lambda (re) (cons 'next (cdr re))) (zero-width-edges n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "every other kind labels its edges too")

# The callback-node half of the declaration cross-reference checks. Four
# faults, three codes, and one
# arm ORDER that is load-bearing -- the duplicate check runs first, so a key
# listed twice reports once as a duplicate rather than twice as whatever else it
# is. Each mutation below removes exactly one arm.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback node may invoke a span callback"
  # A callback node invokes one named event or decision callback. Without this arm
  # a node naming a span-data callback verifies clean and then invokes, at run
  # time, a procedure whose signature takes four arguments and not two.
  FIND [[        ((not (memq (callback-declaration-kind cd) '(event decision)))]]
  REPLACE [[        ((and #f (not (memq (callback-declaration-kind cd) '(event decision))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a node invoking a span-kind callback is an invalid invocation: the invocation, and nothing about keys")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback node's UNDECLARED branch key is accepted"
  # This arm also enforces statically that an event callback declares no
  # keys, so every key on its node is undeclared.
  FIND [[                         (if (memq k (callback-declaration-branch-keys cd)) #f]]
  REPLACE [[                         (if #t #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a key the declaration never declared is UNDECLARED: one finding, at the node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a declared branch key with no target on the node is accepted"
  # The arm that makes `normalize-machine`'s own "no target for the default
  # branch" raise unreachable: an optional decision callback's default branch
  # is taken with no callback to ask, so a node with no target for it has
  # nothing to lower.
  FIND [[                         (if (memq k keys) #f]]
  REPLACE [[                         (if #t #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a declared key the node gives no target for is MISSING: one finding, at the node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a branch key listed twice on one node is not reported"
  # Dropping the duplicate arm does not make the machine verify: the key is
  # declared and has a target, so nothing else objects to it. The pin is the
  # duplicate case's whole result, which is the only thing that can tell "not
  # reported" from "reported under another code".
  FIND [[                           (cons (make-diagnostic 'duplicate-branch-key nm
                                                  "branch key listed twice on one node")
                                 kout)]]
  REPLACE [[                           kout]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a key listed twice is DUPLICATED, and reports once: exactly one finding, and it is the duplicate")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback node naming no declaration falls through to the key arms"
  # The RESOLUTION short circuit. Without it the key arms run against `cd` = #f
  # and `callback-declaration-branch-keys` reads slot 4 of a boolean, so the
  # verifier RAISES on a machine it is supposed to reject with one finding.
  #
  # Pinned on the RAISE, deliberately: the raise IS the decision's consequence,
  # not where the mutant happens to crash, and there is no opposite constant to
  # try -- `(and #t (not cd))` is the baseline. Measured: `Exception in
  # vector-ref: #f is not a vector`.
  FIND [[        ((not cd)
         (list (make-diagnostic/declarations 'missing-callback-declaration nm]]
  REPLACE [[        ((and #f (not cd))
         (list (make-diagnostic/declarations 'missing-callback-declaration nm]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the resolution arm answers ALONE: case raised")

# Pass 7, the span-state lattice. One mutation per decision the pass makes,
# including the two structural ones -- the edge set and the node domain.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: span RE-ENTRY is accepted"
  FIND [[               ((and (pair? state) (eq? (cadr state) s))
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span re-entry: this span is already open"
                                            path)))]]
  REPLACE [[               ((and (pair? state) (eq? (cadr state) s)) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span RE-ENTRY: a second start for the same span")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: span OVERLAP is accepted"
  FIND [[               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span overlap: another span is already open"
                                            path)))]]
  REPLACE [[               ((pair? state) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span OVERLAP: a start for a different span while one is open")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a WRONG END is accepted"
  FIND [[               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "wrong end: a different span is open"
                                            path)))]]
  REPLACE [[               ((pair? state) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "WRONG END: closing a span that is not the one open")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an UNMATCHED END is accepted"
  FIND [[               ((eq? state 'none)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "unmatched end: no span is open"
                                            path)))]]
  REPLACE [[               ((eq? state 'none) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "UNMATCHED END: closing with nothing open")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a merge disagreement is not reported"
  # Two branches reaching a merge with different span states is a rejection
  # of its own, not a consequence of any other span-state rule.
  FIND [[                                    ((eq? st 'top)
                                     (list (make-diagnostic/path 'inconsistent-span-state]]
  REPLACE [[                                    ((and #f (eq? st 'top))
                                     (list (make-diagnostic/path 'inconsistent-span-state]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "INCONSISTENT: two branches disagree at a merge")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: top flows onward instead of stopping at the merge"
  # The other half of the merge rule, and the half that keeps the transfer
  # functions TOTAL: with `top` flowing, a span end downstream of the merge is
  # asked what it does on `top`, answers `unmatched end`, and blames a node that
  # is innocent.
  FIND [[                             (if (or (not fs) (eq? fs 'top))]]
  REPLACE [[                             (if (not fs)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "INCONSISTENT: two branches disagree at a merge")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass 7's edge set omits the EOF routes"
  # The edge set, separately from the node domain: without the eof half the
  # dataflow never arrives at a finish node that is only EOF-reachable, and the
  # "successful EOF with an active span" rejection becomes unreachable.
  FIND [[      (append byte-edges eof-edges)))]]
  REPLACE [[      byte-edges))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a span open at an EOF-ONLY finish is rejected too")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass 7's EOF half keeps taking byte edges"
  # Pass 7 uses the occupiable relation, the same one the reachability walk
  # uses, which rejects the walk that crosses an eof-target and then keeps
  # taking byte edges -- that describes no execution. This mutant is that walk,
  # written INLINE in the REPLACE (not a call to a helper, so the mutant is
  # caught by a comparison rather than by an unbound identifier), and the
  # fixture is a machine on which the two relations differ.
  FIND [[                              (map (lambda (t) (cons (node-name n) t)) (eof-step n))]]
  REPLACE [[                              (map (lambda (t) (cons (node-name n) t))
                                   (append (node-out-targets n)
                                           (let ((t (node-eof-target n)))
                                             (if (symbol? t) (list t) '()))))]]
  EXPECT_STATUS 1
  # The mutant reports the unmatched end at `cl` beside the four
  # `unreachable-node`s the case expects, so the whole `got` is pinned rather
  # than the bare check label.
  EXPECT_OUTPUT_MATCHES
    "the span-state lattice.a node no execution can occupy contributes no state: the span end on the untakeable byte edge is not reported -- expected ..unreachable-node . cl. .unreachable-node . exit. .unreachable-node . done. .unreachable-node . fin.., got ..invalid-span-state . cl. .unreachable-node . cl. .unreachable-node . exit. .unreachable-node . done. .unreachable-node . fin..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress report is not gated on byte-reachability"
  # The zero-progress check's byte-reachability gate. Its own fixture asserts
  # BOTH directions, so this mutant is caught by the accepting half -- an
  # unoccupiable cycle, which `unreachable-node` does NOT report either, which
  # is why the gate is not a benign no-op.
  FIND [[                     (let ((cyc (and (memq (node-name n) br898)]]
  REPLACE [[                     (let ((cyc (and #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an unoccupiable zero-progress cycle is accepted")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span open at an ERROR terminal is rejected too"
  # The open-span rejection is about the SUCCESSFUL terminals only; a span may
  # still be open at an error one. This is the mutation that witnesses the
  # `finish`-versus-`error` distinction: widen the check and the accepted
  # machine is rejected.
  FIND [[      ((and (pair? state) (or (stop-node? n) (finish-node? n)))]]
  REPLACE [[      ((and (pair? state) (or (stop-node? n) (finish-node? n) (error-node? n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a span open at an ERROR terminal is ACCEPTED")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the span-active-at-pause check does not see callback invocations"
  # The rule covers explicit pauses OR event/decision callback invocations
  # reachable with a span active, and the two halves are one arm here -- so
  # dropping either is its own mutation and its own case.
  FIND [[      ((and (pair? state) (or (pause-node? n) (callback-node? n)))]]
  REPLACE [[      ((and (pair? state) (pause-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a CALLBACK invocation reachable with a span active is the same finding")

# --- Span ends are PARKED states; span nodes reference declarations ----------
#
# Without either check a machine verifies clean and then fails: one answers
# `stopped` from `parser-finish!`, the other raises out of `normalize-machine`.
#
# `parked-eof-start` has no arm answering `(span-end-node-next n)`: such an
# arm's mutation survives, because a span end is pure flow-through and
# `classify` joins over its `next` anyway, so starting the walk at the node and
# at its successor give the same verdict. Only the membership below does
# anything.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span end is not treated as a parked state"
  # Without the disjunct, a machine whose span end continues into a stop
  # verifies clean -- and `parser-finish!` after a span-data pause answers
  # `stopped` from it, which is the outcome the EOF-shape check exists to
  # forbid. The FIND sits in `parked?`, so the mutant reaches all three
  # consumers (pass 6, pass 7, `occupiable`).
  FIND [[             (span-end-node? n)
             (symbol? (node-eof-target n)))))]]
  REPLACE [[             (symbol? (node-eof-target n)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a span end continuing into a STOP is rejected: one finding, at the span end -- expected ..eof-reachable-stop . cl.., got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span node's declaration cross-reference is not checked"
  # The span half of the declaration cross-reference checks.
  # `make-span-start-node` stores its span as a bare symbol and its own comment
  # assigns this to the verifier; pass 7 cannot do it, because the lattice is
  # well defined over any symbol and treats the name opaquely. Without the arm
  # the machine verifies CLEAN and `normalize-machine` raises
  # `assertion-violation` -- a verified machine crashing the normalizer, which
  # verification exists to rule out.
  FIND [[                           ((or (span-start-node? n) (span-end-node? n))
                            (span-node-declaration-diagnostics sps n))]]
  REPLACE [[                           ((or (span-start-node? n) (span-end-node? n)) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an UNDECLARED span is rejected: one finding per node -- expected ..missing-span-declaration . op. .missing-span-declaration . cl.., got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only a span START's declaration is checked, not a span end's"
  # The accessor split, which one node cannot witness: each kind carries its own
  # `-span` accessor and a fix reaching only one of them leaves the other
  # unchecked. The fixture places both and the pin names the SURVIVING half.
  FIND [[    (let ((s (if (span-start-node? n) (span-start-node-span n) (span-end-node-span n))))]]
  REPLACE [[    (let ((s (if (span-start-node? n) (span-start-node-span n) 'body)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an UNDECLARED span is rejected.*got ..missing-span-declaration . op.."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an ABSENT label is treated as a nonportable one"
  # The declaration LABEL clause. The clause is TOTAL: every fixture in this
  # lane carries `#f` labels, so an arm that rejects absence reddens nearly
  # every case here. Measured: NINE pins in this pass are satisfied by this
  # mutant's output as well as their own. By LABEL:
  #   "verify: default-error is promoted out of the benign tier"
  #   "verify: eof-reachable-stop is promoted into the benign tier"
  #   "verify: unresolved is promoted out of the benign tier"
  #   "verify: every non-eof-into-finish finding is labelled `case` regardless of which edge produced it"
  #   "verify: the non-eof-into-finish check reads only the first of a node's out-targets"
  #   "verify: node-out-targets returns the roles instead of the targets"
  #   "verify: the EOF-chain walk does not start at the entry"
  #   "verify: the entry being a finish terminal is not rejected"
  #   "verify: the zero-progress report is not gated on byte-reachability"
  # A nesting by construction, in the pass-fields-never-run shape, and not a
  # weakness in any of the nine: each still catches its own mutant for its
  # declared reason (0 self-failures), and this pin still catches this one.
  #
  # *** THIS IS THE ARM THAT GETS THE PIN, and the symbol and string arms
  # deliberately do NOT. *** Both of those call `valid-reason?`, so
  # every mutant of them is NESTED BY CONSTRUCTION inside the two reason mutants
  # above -- measured: the permissive `reason-char?` mutant reddens all four
  # label cases and more. A nesting by construction is a closed question, not a
  # coverage gap; their control is that each arm is asserted in BOTH directions
  # (a portable label accepted, a nonportable one rejected).
  #
  # This mutant is not nested: absence is decided before `valid-reason?` is
  # reached, so no reason mutant touches it. Both declaration families take an
  # optional diagnostic label, and an arm that rejected absence would redden
  # every fixture in the tree -- which is why the case it fails is the group's
  # own negative control rather than one of its rejections.
  FIND [[    (cond ((eq? l #f) #t)]]
  REPLACE [[    (cond ((eq? l #f) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "both absent -- expected .., got .invalid-name invalid-name."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the callback family stops checking its label, the span family does not"
  # The per-family split, which one family's fixture cannot witness: each arm
  # reads its own accessor. Pinned on the SHAPE case, and that choice is the
  # measurement -- the permissive reason mutant leaves the shape case GREEN,
  # because `valid-label?`'s `(else #f)` rejects an integer without consulting
  # the repertoire at all. That is this mutant's unique record.
  FIND [[                      (if (and (valid-name? (callback-declaration-name cd))
                               (valid-label? (callback-declaration-source-label cd)))]]
  REPLACE [[                      (if (and (valid-name? (callback-declaration-name cd))
                               #t)]]
  EXPECT_STATUS 1
  # `got .[)]` and not `got ..`: a bare two-wildcard tail also matches the
  # RESTRICTIVE reason mutant, which reddens this same case with a LONGER got
  # list. Requiring a literal `)` as the second character is what asserts the
  # list is EMPTY -- measured, `$` does not work here, because CMake's MATCHES
  # anchors at the end of the whole captured output rather than the line.
  EXPECT_OUTPUT_MATCHES "an integer on the callback -- expected .invalid-name., got .[)]"
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the span family stops checking its label, the callback family does not"
  # The other half of the per-family split. With an integer label only on the
  # callback, this mutant's single record -- the span label case -- would be
  # wholly contained in the permissive `reason-char?` mutant's. The shape
  # fixture carries an integer on the SPAN too, which is the record no reason
  # mutant can produce.
  FIND [[                      (if (and (valid-name? (span-declaration-name sd))
                               (valid-label? (span-declaration-source-label sd)))
                          #f]]
  REPLACE [[                      (if (and (valid-name? (span-declaration-name sd))
                               #t)
                          #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an integer on the span -- expected .invalid-name., got .[)]"
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a callback declaration's NAME is no longer checked"
  # The name check beside the label clause. BOTH families get a pin, because
  # each arm reads its own accessor and one family's pin cannot witness the
  # other's.
  FIND [[                      (if (and (valid-name? (callback-declaration-name cd))
                               (valid-label? (callback-declaration-source-label cd)))
                          #f]]
  REPLACE [[                      (if (and #t
                               (valid-label? (callback-declaration-source-label cd)))
                          #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the callback -- expected ..invalid-name . Bad.., got .[)]"
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span declaration's NAME is no longer checked"
  FIND [[                      (if (and (valid-name? (span-declaration-name sd))
                               (valid-label? (span-declaration-source-label sd)))]]
  REPLACE [[                      (if (and #t
                               (valid-label? (span-declaration-source-label sd)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the span -- expected ..invalid-name . Body.., got .[)]"
)

# --- The label clause is TOTAL over every label carrier -----------------------
# Five conjuncts, one per label-carrying arm, each pinned on the carrier row
# whose integer label it stops rejecting. The fixtures use a wrong-SHAPE label
# because every one of these mutants is otherwise nested inside the permissive
# `reason-char?` mutant above: `valid-label?`'s `(else #f)` rejects an integer
# without consulting the repertoire, so the integer row is the record no reason
# mutant can produce. `got .[)]` asserts the diagnostic list is EMPTY.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine's label is no longer checked"
  FIND [[(valid-label? (machine-source-label m))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "machine: integer label -- expected ..invalid-name . labm.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a node's own label is no longer checked"
  # Every node-kind row reddens; the pin is one of them. The case-label conjunct
  # below keeps the byte-case and sequence-case rows GREEN under this mutant,
  # which is what separates the two pins.
  FIND [[(valid-label? (node-source-label n))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "stop: integer label -- expected ..invalid-name . done.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a node's case labels are no longer checked"
  # The other half of the node arm: only the two case rows redden, under the
  # OWNING node's name, and every node-kind row stays green.
  FIND [[(for-all valid-label? (node-case-labels n))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-case: integer label -- expected ..invalid-name . start.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an error declaration's label is no longer checked"
  FIND [[(valid-label? (error-declaration-source-label e))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "error-declaration: integer label -- expected ..invalid-name . rejected.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a field's label is no longer checked"
  # `pass-fields`' arm; it reports under the field name and the CODE is
  # `invalid-field-declaration`, so the expected list here differs from the
  # four `invalid-name` rows above. This pin is also satisfied by "pass-fields
  # is never run" -- a nesting BY CONSTRUCTION shared with every pin inside
  # that pass: a pass that never runs produces every failure any conjunct
  # inside it can.
  FIND [[(valid-label? (uint-field-source-label f))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "uint-field: integer label -- expected ..invalid-field-declaration . count.., got .[)]")

# --- The counted-consume kind's verifier decisions ----------------------------
# One pin per arm that reads a counted-consume node. Two pairs share a
# fixture and are separated by the `got`: the walk arm and the REPORT-set
# predicate both redden the value-terminated loop, one to an EMPTY list and the
# other to a list missing the counted node; the two halves of `classify`'s join
# each unreport a different fixture.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's next is not an out-edge"
  # This mutant also satisfies two pins whose regexes are case-label prefixes
  # over the edge-role rows ("verify: the eof-cycles-and-finish-flow gate is vacuous, so no byte edge
  # into a finish is ever rejected" and "verify: the zero-width kinds report
  # one role for all their edges"); dropping one kind's out-edge is a per-kind
  # subset of those mutants' effects. This pin's own record is not shared.
  FIND [[          ((counted-consume-node? n)
           (list (cons 'next (counted-consume-node-next n))))]]
  REPLACE [[          ((counted-consume-node? n) '())]]
  EXPECT_STATUS 1
  # An entry-stop fixture cannot witness this: an entry counted consume is
  # PARKED, and its walk visits `next`'s target through `eof-successors`, so
  # nothing in that machine is unreachable with or without the arm. The
  # decision this mutation names -- `next` is a BYTE out-edge -- is observable
  # through the byte-into-finish block, which reads `node-out-edges`: with the
  # arm gone, the byte-reachable counted consume whose `next` is the finish
  # stops being `non-eof-into-finish` and is reported `unreachable-node`
  # instead. That is the measured record below, and it is unique to this
  # mutant across the pass.
  EXPECT_OUTPUT_MATCHES
    "non-eof-into-finish is gated on byte-reachability, for every kind.a BYTE-reachable byte edge into a finish is rejected at its source node: each rejected exactly once, at `hop` -- expected .., got ..counted-consume .unreachable-node . fin...")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's eof-target is read as absent"
  # Also satisfied by "verify: the eof-reachable-stops start set enumerates a
  # kind instead of deriving the EOF route" and "verify: an EOF cycle through
  # pause continuations is not reported" -- both unpark or unreport the node this
  # arm's route parks, so the self-eof fixture goes empty under them too. By
  # construction: the route this arm answers is what the parked-set proxy reads.
  FIND [[          ((counted-consume-node? n) (counted-consume-node-eof-target n))]]
  REPLACE [[          ((counted-consume-node? n) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a self-targeting eof-target is an EOF zero-progress cycle: eof-zero-progress-cycle, at the node -- expected ..eof-zero-progress-cycle . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's field reference is not checked"
  # Also satisfied by "verify: pass-fields is never run" and "verify: the
  # operand half is never run" -- pass containment, the nesting every pin
  # inside pass-fields shares. By construction.
  # counted-operand-diagnostics is a cond whose first clause is the undeclared
  # check; forcing that clause's test #f skips it.
  FIND [[      (cond ((not (field-width-of fs fname))]]
  REPLACE [[      (cond (#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "undeclared: reported under the node -- expected ..invalid-field-operand . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a counted consume's next is invisible to the zero-progress walk"
  # The WALK half of the counted kind's zero-progress rule. Without it no node
  # of the value-terminated loop reaches itself, so the loop's record is EMPTY
  # -- the `got` that separates this pin from the REPORT-set pin below.
  # Also satisfied by "verify: zero-progress detection never
  # fires" and "verify: the zero-progress WALK does not follow a zero-width node"
  # -- the value-terminated loop runs through a branch and an action, so any
  # mutant that breaks the walk at those kinds empties the same record. By
  # construction of the fixture, which needs all three edges to close.
  FIND [[              ((counted-consume-node? n) (list (counted-consume-node-next n)))]]
  REPLACE [[              ((counted-consume-node? n) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "rejected: the three nodes of the loop -- expected ..zero-progress-cycle . br. .zero-progress-cycle . body. .zero-progress-cycle . dec.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the counted-consume kind"
  # The REPORT half. The branch and the action still reach themselves through
  # the counted node's `next`, so the loop's record loses exactly the counted
  # node -- and the self-targeting-next fixture goes empty, which the walk pin
  # above also produces; the loop record is what separates them.
  FIND [[                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))]]
  REPLACE [[                                         (span-start-node? n) (span-end-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "rejected: the three nodes of the loop -- expected ..zero-progress-cycle . br. .zero-progress-cycle . body. .zero-progress-cycle . dec.., got ..zero-progress-cycle . br. .zero-progress-cycle . dec..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-successors answers nothing for a counted consume"
  # `join-over` raises on an empty list, so the arm's loss is a RAISE out of
  # verification -- the same failure mode as the accumulate arm of
  # eof-terminal's classify, pinned on the raise the same way.
  # This mutant's raise also satisfies the pin "verify: eof-terminal chains
  # through a pause continuation", whose regex is a case-raised record; the
  # empty-join raise reaches that case too. That pin is the coarse one.
  FIND [[    (cond ((counted-consume-node? n) (list (counted-consume-node-next n)))
          (else (zero-width-successors n))))]]
  REPLACE [[    (cond ((counted-consume-node? n) '())
          (else (zero-width-successors n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the flow-through zero-count stop at the ENTRY is rejected: case raised")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: classify drops the next half of the counted join"
  # A dispatch-shaped arm: the entry zero-count stop verifies CLEAN -- the hole
  # the join over both halves closes.
  # Also satisfied by "verify: an EOF-reachable stop terminal
  # is accepted", "verify: default-error is promoted out of the benign tier",
  # "verify: eof-reachable-stop is promoted into the benign tier" and "verify: the
  # eof-reachable-stops walk does not start at the entry (D-1)" -- each unreports the entry
  # zero-count stop by a tier or start-set change that sits above this arm in the
  # walk. By construction.
  FIND [[                 (eof-verdict-join (dispatch-arm (counted-consume-node-eof-target n) path)
                                   (join-over (eof-successors n) path)))]]
  REPLACE [[                 (dispatch-arm (counted-consume-node-eof-target n) path))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the flow-through zero-count stop at the ENTRY is rejected: eof-reachable-stop, at the entry -- expected ..eof-reachable-stop . body.., got .[)]")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: classify drops the eof half of the counted join"
  # A zero-width-shaped arm: the self-targeting eof-target is no longer a cycle
  # but the stop behind `next`, a DIFFERENT wrong verdict from the arm's absence.
  # Also satisfied by "verify: an eof-target cycle is
  # classified as a finish terminal" and "verify: cycle no longer outranks
  # eof-reachable-stop in the join" -- both turn the self-eof cycle into the stop
  # this half's absence turns it into. By construction (the join's ranking).
  FIND [[                 (eof-verdict-join (dispatch-arm (counted-consume-node-eof-target n) path)
                                   (join-over (eof-successors n) path)))]]
  REPLACE [[                 (join-over (eof-successors n) path))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a self-targeting eof-target is an EOF zero-progress cycle: eof-zero-progress-cycle, at the node -- expected ..eof-zero-progress-cycle . body.., got ..eof-reachable-stop . body..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a parked counted consume is classified from its own name"
  # A parked non-entry counted consume is classified from its eof-target. With
  # the arm answering the node itself, the one-shot "length, body, stop"
  # grammar is wrongly rejected.
  FIND [[           (counted-consume-node-eof-target n))
          (else (node-name n))))]]
  REPLACE [[           (node-name n))
          (else (node-name n))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the one-shot length, body, stop grammar is ACCEPTED: no diagnostics -- expected .., got .eof-reachable-stop.")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pass 4 walks the retired relation instead of the occupiable one"
  # `pass-reachability` reads `occupiable` and not the walk that crosses an
  # eof-target and then keeps taking byte edges. That walk is reproduced
  # inline in the REPLACE; no helper names it.
  #
  # Comparison-caught, not raise-caught: the mutant verifies the whole `E
  # ->(eof) T ->(byte) Z` family clean, so the group's three REJECTED checks
  # and its transitive one fail with `got ()` against a non-empty expectation,
  # and three other cases fail with the wider relation's verdicts.
  FIND [[    (let ((nodes (machine-nodes m)) (reached (occupiable m)))]]
  REPLACE [[    (let ((nodes (machine-nodes m)) (reached (map car (reach-from m (lambda (n) (append (node-out-targets n) (let ((t (node-eof-target n))) (if (symbol? t) (list t) '()))))))))]]
  EXPECT_STATUS 1
  # SUBSUMED except for one record, and that record is why the fixture exists.
  # Measured: every OTHER check this mutant reddens is also
  # reddened by "verify: reachability never reports an unreachable node", whose
  # suppression of the emission is a superset of this walk's widening on every
  # machine -- whole-set containment, so no family-only check can separate them.
  # The separating fixture is `an orphan beside the family`, which carries a
  # node dead under BOTH relations beside one dead only under the narrowing:
  # this mutant leaves the orphan reported, the emission mutant leaves nothing,
  # and the two `got` lists differ. AGENTS.md's count-don't-witness remedy.
  EXPECT_OUTPUT_MATCHES
    "reachability is the occupiable relation.an orphan beside the family, so the two ways of breaking pass 4 differ: both unoccupiable nodes, the family's and the orphan's -- expected ..unreachable-node . z. .unreachable-node . orphan.., got ..unreachable-node . orphan..")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the parked set loses the pause disjunct"
  # The pause disjunct of `parked?`'s membership. Every other `(pause-node? n)`
  # FIND sits in `pass-zero-progress`, `zero-width-edges`, `node-out-edges`,
  # `parked-eof-start` or `span-transfer`, so none of them witnesses this one.
  # Measured: a byte-reachable pause stops starting a walk, so the case whose
  # stop sits behind a pause continuation loses its finding.
  FIND [[             (pause-node? n)
             (callback-node? n)]]
  REPLACE [[             (callback-node? n)]]
  EXPECT_STATUS 1
  # A CONJUNCTION of two whole records, because neither is unique alone: the
  # first is shared with "verify: an EOF-reachable stop terminal is accepted"
  # and the second with three cycle/out-target mutants, and the intersection of
  # those containing sets is empty. Measured; the `.*` joins two complete
  # records and never sits between an `expected` and its own `got`.
  EXPECT_OUTPUT_MATCHES
    "pause nodes.a byte-reachable pause into a stop would leak stopped through EOF: rejected -- expected a true value.*an EOF cycle through pause continuations is attributed to the pause.an eof-zero-progress-cycle is reported AT A PAUSE NODE: at least one, at a pause -- expected a true value")

# --- The diagnostic record's severity, machine, edge and path fields ---------
# Eleven mutations. Each EXPECT_OUTPUT_MATCHES is measured from the staged
# mutant (never predicted) and pins a single-firing record: a case-name tail,
# a check label, and the measured got in full. The nine below run on the verify
# lane; the two census mutations (a path site made pathless, a path site
# relabelled out of the set) live in the diagnostic-census pass, because a
# mutation is witnessed only by its own SPEC lane's program.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the stamping map is dropped, so severity and machine are #f"
  # No map, no stamp. Separated from the constant and warning mutations below by its got #f (they give a symbol).
  FIND [[(map (lambda (d) (stamp-diagnostic d nm)) ds)]]
  REPLACE [[ds]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "non-machine severity -- expected error, got #f")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine stamp answers a constant instead of the machine name"
  # NOT #f (which would be a subset of the dropped-map mutant, subsumed by construction) -- a wrong NAME, so its got separates it. Pinned on the single-finding case so the record fires exactly once.
  FIND [[(nm (and (machine? machine) (machine-name machine)))]]
  REPLACE [[(nm (and (machine? machine) 'wrong))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "single machine stamp -- expected solo, got wrong")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the diagnostic severity is a warning rather than an error"
  # The `error` constant in stamp-diagnostic. Separable from the dropped map by got warning vs #f.
  FIND [[(diagnostic-edge d) 'error machine-name]]
  REPLACE [[(diagnostic-edge d) 'warning machine-name]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "non-machine severity -- expected error, got warning")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF path is not reversed, so it runs from the node to the start"
  # An EOF path starts at the walk's start, checked as a first/last comparison. SITES=1: all six verdict sites route through this one helper.
  FIND [[(define (verdict v path) (list v (reverse path)))]]
  REPLACE [[(define (verdict v path) (list v path))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "eof-reachable-stop: path starts at the walk start -- expected start, got stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the EOF verdict join keeps the right operand on a tie"
  # The join keeps the LEFT operand on a tie. Verdicts alone cannot see the tie-break; the path is what makes it observable. On the two-distinct-stop fixture the winner's path moves from s1 to s2.
  FIND [[(if (>= (eof-verdict-rank (car a)) (eof-verdict-rank (car b))) a b)]]
  REPLACE [[(if (> (eof-verdict-rank (car a)) (eof-verdict-rank (car b))) a b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "path last is the LEFT branch's stop -- expected s1, got s2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the zero-progress cycle path is empty"
  # Separated from 'zero-progress detection never fires' by the finding COUNT: this mutant keeps the finding with an empty path (got #f), the deleting one removes it and the case's 'is emitted' check fails instead.
  FIND [[((eq? (caar frontier) start) (cons start (reverse (cdar frontier))))]]
  REPLACE [[((eq? (caar frontier) start) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "zero-progress-cycle: path starts at the walk start -- expected start, got #f")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte parent is not recorded, so the non-eof-into-finish path is truncated"
  # reach-from's parent alist. Caught only by a two-hop fixture whose source is not the entry; a source==entry fixture is unchanged.
  FIND [[(cons name parent)]]
  REPLACE [[(cons name #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "non-eof-into-finish \\(edge\\): path starts at the walk start -- expected start, got mid")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a span parent is not recorded, so span paths are truncated"
  # edge-parents' equivalent, kept separate from the byte map above because they are two maps and each reddens a family the other does not.
  FIND [[(cons (cons (car succ) (car frontier)) parents)]]
  REPLACE [[(cons (cons (car succ) #f) parents)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "invalid-span-state: path starts at the walk start -- expected start, got op2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a two-name declarations list loses its second name"
  # invalid-span-callback's declarations slot is a two-element list. Witness: the two-name declarations case.
  FIND [["span data callback is not of kind span-data" (list (span-declaration-name sd) dn)]]
  REPLACE [["span data callback is not of kind span-data" (list (span-declaration-name sd))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "span then callback -- expected \\(body ondata\\), got \\(body\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")


# --- Pass 34: the reference interpreter ----------------------------------------
#
# interpret-tests.sps runs the verified one-byte machine over all 256 byte
# values through the runtime and refuses an unverified machine; this pass proves
# those checks are not vacuous. The first mutation makes dispatch match every
# byte to the first case, so bytes 1..255 wrongly accept and the all-256 case
# fails; the second disarms the unverified-machine refusal, so the refuse case's
# check-raises sees a normal return. Verify command uses both library roots,
# an empty object guard, the interpret program.
#
# Every pin in this pass is judged through byte_machine_mutation_verdict
# against every other mutant's captured output, in both directions, plus a
# self-check that each pin catches its own: no collisions. A changed check set
# in interpret-tests.sps widens pins exactly as a changed mutation set does, so
# an edit to that program needs this sweep re-run.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/interpret-tests.sps")

# The interpreter's membership test is `memv` over the canonical byte set.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch matches every byte to the first case"
  FIND [[((memv byte (matcher-bytes (byte-case-matcher (car cs))))]]
  REPLACE [[(#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no byte in 1..255 misbehaved")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: an unverified machine is accepted"
  FIND [[(unless (verification-ok? verification)]]
  REPLACE [[(when #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

# EOF execution: with a finish node not reporting the `finish` kind,
# parser-finish! never reaches its `finish` arm and the idle-completion case's
# "finished" check fails.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: a finish node is not reported as a finish kind"
  FIND [[((finish-node? n) 'finish)]]
  REPLACE [[((finish-node? n) 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish with no input is idle completion -> finished: finished")

# Sequence prefix tracking through a compound current (name . path).
# interpret-tests.sps carries a "sequence prefix tracking through the
# interpreter" group, an AB/XY group for the position-index defect, the two
# internal guards (mirroring normal-ir-tests.sps's own two), an advance-mode
# group, and an EOF-through-a-compound group that gives eof-target-of's
# compound branch a witness -- no other fixture calls parser-finish! while
# `current` is a compound.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: kind of a compound current is not reported as dispatch"
  # kind's `(if (pair? name) 'dispatch ...)` branch is what lets the runtime
  # keep reading bytes once `current` becomes a mid-sequence compound. Without
  # it, the compound is reported as a stop -- and the dispatch loop reaches
  # that check on the very same call that just built the compound (a
  # single-byte slice hits end-of-slice exactly there), so every multi-byte
  # sequence stops dead after its first byte. Comparison-caught.
  # `kind`'s compound branch separates TWO compounds -- a mid-sequence
  # (name . byte-list) from a span end's (name . completion-pending) -- so the
  # mutation targets the inner `if`'s `'dispatch` answer.
  FIND [[            (if (completion? name) 'span-completion 'dispatch)]]
  REPLACE [[            (if (completion? name) 'span-completion 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: stopped -- expected \\(stopped 1 1 4 #f\\), got \\(stopped 0 0 1 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: seq-step filters live alternatives by position, not the accumulated path"
  # The compound carries the accumulated path, not a bare position index
  # (s . k). Replacing prefix?'s full-path walk with a position-k comparison
  # against the CURRENT byte alone reproduces the position-index defect --
  # with AB and XY, after consuming A a
  # position index finds Y at position 1 in XY and accepts it, even though A
  # never matched X. The AB/AC fixture does not witness this (both share byte
  # 0, so a position check and a path check agree there); only AB/XY, which
  # diverges at position 0, can tell the two representations apart.
  # Comparison-caught. This mutation's two failing checks are each
  # individually reproduced by a DIFFERENT sibling mutation alone (the
  # "mismatch" line by the kind-of-compound mutation above, byte-identical;
  # the "at offset 1" line by the mismatch-edge-not-taken mutation below,
  # byte-identical) -- neither line alone separates this mutation from its
  # neighbor. The pin below requires both, in this order, from the SAME run;
  # verified by matching it against every sibling mutation's own captured
  # output in this pass and confirming it resolves to this mutation alone.
  FIND [[                                (and (> (length bs) k) (prefix? new bs))))]]
  REPLACE [[                                (and (> (length bs) k) (= byte (list-ref bs k)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "A then Y mismatches rather than following the XY alternative: mismatch -- expected error, got stopped.*at offset 1 -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: the mismatch edge is not taken when no alternative matches"
  # Disabling the null-hit clause (via an unreachable `#f` conjunct, the same
  # idiom normal-ir.sls's own guard mutations below use) falls through to the
  # final `else`, so a byte that matches nothing still gets folded into a new
  # compound state instead of routing to the declared mismatch edge -- the
  # mismatching byte is silently accepted into the sequence rather than
  # rejected. Comparison-caught; pinned to "pos 0", not "at offset 1" in the
  # AB/XY case, because "at offset 1" is byte-identical to the position-index
  # mutation's own output above (measured) and "pos 0" is this mutation's
  # alone (measured against every sibling in this pass).
  FIND [[          (cond ((null? hit)]]
  REPLACE [[          (cond ((and (null? hit) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a wrong byte at each position errors at that between-byte offset: pos 0 -- expected \\(error 0 0 0 unexpected-byte\\), got \\(need-input 1 1 1 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: a completed alternative routes to another prefix instead of its declared target"
  # The `(pair? ends)` clause is what lands a fully-consumed alternative on
  # its OWN declared target; folding it into the same "extend the compound"
  # shape the `else` clause uses instead means a complete sequence never
  # actually terminates -- it just grows a compound state forever, so the
  # parser reports need-input after the sequence's own last byte rather than
  # stopping. Comparison-caught, pinned to the same four-byte fixture as the
  # kind-of-compound mutation above but discriminated by the "got" value
  # (need-input here, stopped there) -- verified distinct by direct
  # cross-check against that sibling's captured output.
  FIND [[                ((pair? ends) (cons (sequence-case-target (car ends)) 'advance))]]
  REPLACE [[                ((pair? ends) (cons (cons (sequence-dispatch-node-name n) new) 'advance))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: stopped -- expected \\(stopped 1 1 4 #f\\), got \\(need-input 1 1 4 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: eof-target-of does not dereference a compound back to its source node"
  # Passing `cur` straight through instead of extracting `(car cur)` sends a
  # (name . path) pair to `lookup`, whose `eq?` name comparison can never
  # match a pair against any declared node name -- lookup returns #f, and the
  # unguarded byte-dispatch-node-eof-target accessor then vector-refs #f.
  # Raise-caught, not comparison-caught: there is no representable "wrong but
  # valid" node name to fall back to here (every alternative extraction --
  # `cur` raw, `(cdr cur)`, an inverted pair? test -- feeds a non-node-name
  # into the same accessor chain), so every variant of this defect crashes the
  # same way. The EOF-through-a-compound group exists to give this value a
  # witness.
  FIND [[        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))]]
  REPLACE [[        (let ((n (lookup nodes cur)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
  # `eof-target-of` is a `cond` with a LOUD else, rather than a two-way `if`
  # falling through into a bare slot read (on an accumulate node that slot is
  # `digit-target`, a symbol). Undereferencing a compound reaches that else
  # and raises a CONTRACT VIOLATION, which is the signature pinned here.
    "EOF mid-sequence routes through the sequence node's own eof-target, not the machine default: case raised -- Exception occurred with condition components")

# The same two internal invariants normal-ir.sls's own trie asserts, disabled
# the same way normal-ir.sls's own guard mutations disable them (an
# unreachable `#f` conjunct) -- see "the duplicate-alternative guard is
# dropped" and "the ambiguous-prefix guard is dropped" in Pass 35 below for
# the shared idiom and its own rationale. check-raises cases are not vacuous
# (without the guard, the malformed hit set is silently accepted instead of
# raising), and the predicate is raises-interpret-assertion? (structured: who
# is 'interpret, message is the exact string), not (lambda (e) #t), so a
# mutation swapping which message either guard raises would also be caught;
# no such mutation is declared because the two messages are literal string
# constants.
#
# Both witnesses reach seq-step through a FORGED verification.
# pass-sequence-ambiguity rejects both shapes at verify-machine and
# make-interpreted-machine refuses an unverified machine, so
# interpret-tests.sps's plain `interp` helper cannot carry either machine this
# far. The two cases build theirs with that program's `interp-unverified`,
# which wraps make-verification-result (from (byte-machine private ir)) around
# an ok? #t result the verifier would never produce -- exactly the
# caller-who-skips-verification these guards exist for, which is why they are
# defense-in-depth rather than dead.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: the ambiguous-terminal-prefix guard is dropped"
  FIND [[                ((and (pair? ends) (pair? conts))
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))]]
  REPLACE [[                ((and (pair? ends) (pair? conts) #f)
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "an ambiguous terminal prefix is an assertion violation: AB\\|ABC -- expected a raise, but the thunk returned \\(stopped 1 1 2 #f\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: the duplicate-sequence-alternative guard is dropped"
  FIND [[                ((> (length ends) 1)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))]]
  REPLACE [[                ((and (> (length ends) 1) #f)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))]]
  # Pinned with the trailing " -- expected" immediately after "AB|AB", not
  # "AB|AB" alone: "AB|AB" is a literal substring of the sibling mutation's own
  # "AB|ABC", so an unanchored pin on the bare alternatives text would match
  # both mutants' output (measured). Requiring " -- expected" right after
  # forces the fifth character to be the case-name delimiter, not "C".
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "two identical alternatives are an assertion violation: AB\\|AB -- expected a raise, but the thunk returned \\(stopped 1 1 2 #f\\)")

# kind's and dispatch's own recognition of a BARE (not-yet-entered)
# sequence-dispatch-node name are two more decisions distinct from the
# compound-current branches above -- every seq-m fixture's entry is a bare
# symbol on its first byte, so disabling either one leaves the sequence kind
# unhandled, but from two different sites. Measured separable: disabling
# kind's arm raises interpret's own byte-machine-contract condition (code
# internal, who* interpret, detail seq) before dispatch is ever reached;
# disabling dispatch's arm leaves kind correct, so dispatch falls into the
# byte-dispatch loop instead -- byte-dispatch-node-cases and sequence-dispatch-
# node-cases both read vector slot 2, so it silently reads the sequence's OWN
# case list, and byte-case-matcher (vector slot 1) then reads back the FIRST
# case's byte list as though it were a matcher, which matcher-bytes' own guard
# then refuses (code invalid-argument, who* matcher-bytes, detail matcher) --
# a different condition, from a different site, confirmed by direct comparison
# of the two captured outputs.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: kind does not recognize a bare (not yet entered) sequence node"
  FIND [[                    ((sequence-dispatch-node? n) 'dispatch)]]
  REPLACE [[                    ((and (sequence-dispatch-node? n) #f) 'dispatch)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: case raised.*code: internal.*who\\*: interpret.*detail: seq")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch does not recognize a bare (not yet entered) sequence node"
  # The bare-node dispatch is a `cond` with the keyword-table arm above the
  # sequence arm. Neutering the sequence arm makes a bare sequence node fall to
  # the else (the byte-dispatch loop), where matcher-bytes rejects it.
  FIND [[               ((sequence-dispatch-node? n) (seq-step n '() byte))]]
  REPLACE [[               ((and (sequence-dispatch-node? n) #f) (seq-step n '() byte))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops after four bytes: case raised.*code: invalid-argument.*who\\*: matcher-bytes.*detail: matcher")

# --- count-step, the counted-consume step table -------------------------------
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step tests exhaustion before the zero count"
  FIND [[          (if (= v 0)
              (cons 0 (counted-consume-node-next n))]]
  # The wrong order: exhaustion answered first, so a zero count over an empty
  # slice takes the EOF route instead of transitioning.
  REPLACE [[          (if (or (>= pos end) (= v 0))
              (cons 0 (if (>= pos end) #f (counted-consume-node-next n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the zero-count test comes first: .0 . next. -- expected .0 . done., got .0 . #f.")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step commits (- end pos) instead of the min"
  FIND [[              (let ((k (min v (- end pos))))]]
  REPLACE [[              (let ((k (- end pos)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "surplus input commits the count only and continues: .3 . next. -- expected .3 . done., got .5 . #f.")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step never subtracts"
  FIND [[                (vector-set! fv slot (- v k))]]
  REPLACE [[                (vector-set! fv slot v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "exact input completes the count and continues -- count completion wins: the count reaches zero -- expected 0, got 3")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: count-step continues only when input remains"
  # The count-completion-wins mutant: `pos + k >= end`
  # tested before `k = v`, so the exact case parks instead of continuing.
  FIND [[                (cons k (if (= k v) (counted-consume-node-next n) #f))))))]]
  REPLACE [[                (cons k (if (and (= k v) (< (+ pos k) end)) (counted-consume-node-next n) #f))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "exact input completes the count and continues -- count completion wins: .3 . next. -- expected .3 . done., got .3 . #f.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 35: the normalizer ---------------------------------------------------
#
# normal-ir-tests.sps pins the IR fingerprint of the one-byte machine (a golden
# value) and the structural decisions (entry id, transition sort, error-code
# resolution). This pass proves those checks are not vacuous. Verify command
# uses both library roots, an empty object guard, the normal-ir program.
#
# Pin sweep method: apply each mutation to a staged copy, capture the SPEC
# lane's full stdout+stderr, then re-judge every pin through
# byte_machine_mutation_verdict against every OTHER mutant's captured output,
# plus a self-check that each pin still catches its own. "Ordered pairs" is
# n(n-1) throughout this file -- ordered pairs of DISTINCT mutants, one pin
# judged against one OTHER mutant's capture; self-checks are a separate count.
# Adding a check to normal-ir-tests.sps widens every existing pin exactly as
# adding a mutation does (AGENTS.md), so the sweep is re-run after either.
#
# The "two alternatives over a shared prefix lower to one trie" group (which
# lowers the HTTP `version` production) is not inert under this pass's own
# mutants -- four redden it: "normal-ir: the trie does not merge alternatives
# sharing a byte" (state count 39 rather than 11 -- NOT the count for two
# separate chains, which is 18, measured by normalizing two eight-byte
# alternatives sharing nothing; 39 is trie-put's disabled equal-byte arm
# appending a second alist entry at every one of the seven shared levels, so
# the duplicated subtree compounds down the chain), "normal-ir: trie children
# are not kept ascending by byte", "normal-ir: internal prefix states do not
# append after the declared block", and "normal-ir: a terminal trie child
# consumes an id it should not" (state count 13).

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/normal-ir-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a callback's required? flag is left out of the encoding"
  # The emitter renders name, kind, required? and default-branch into ABI
  # member 1, so each must enter the fingerprint encoding, not merely be read
  # from the source machine. Encoding only the NAME lets two machines differing
  # only in `required?` share a fingerprint and emit DIFFERENT libraries, one
  # raising `missing-required-callback` from make-parser and the other building.
  #
  # No mutation pins the SECTION TAG: a callback record and a span record have
  # different shapes, so collapsing the two tags is UNCAUGHT -- no input
  # separates it.
  FIND [[                     (put-u8 p (if (callback-declaration-required? c) 1 0))]]
  REPLACE [[                     (put-u8 p 1)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "EVERY part the ABI carries is in the fingerprint")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV offset basis is changed"
  FIND [[(define fnv-offset 14695981039346656037)]]
  REPLACE [[(define fnv-offset 14695981039346656038)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 2974960947541485368")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV prime is changed"
  FIND [[(define fnv-prime  1099511628211)]]
  REPLACE [[(define fnv-prime  1099511628212)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 16123314695484888068")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the byte is never mixed into the hash"
  FIND [[(* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime)]]
  REPLACE [[(* h fnv-prime)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 1284000904169526997")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the entry id is hard-wired to node 0"
  FIND [[(entry (id-of (machine-entry machine)))]]
  REPLACE [[(entry 0)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "entry is the id of the entry node, not node 0: entry")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: dispatch cases are not sorted ascending by byte"
  # The per-byte expansion runs through this SAME list-sort call, so reversing
  # it also breaks two byte-class checks named "bytes" -- three FAIL lines in
  # this mutant's own output, where a sound pin resolves to exactly one (case,
  # check) pair. Pinned to the full FAIL line of the entry-and-transition-order
  # witness.
  FIND [[(list-sort (lambda (a b) (< (car a) (car b)))]]
  REPLACE [[(list-sort (lambda (a b) (> (car a) (car b)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "transitions are sorted ascending by byte: bytes -- expected \\(2 5\\), got \\(5 2\\)")

# The per-byte expansion itself. The first keeps only each class's lowest
# byte, so a range of four bytes lowers to one transition instead of four. The
# second makes a vacuous class -- a complement whose canonical set is empty,
# e.g. the complement of the full range -- still emit one transition (on byte
# 0), which the vacuous-complement case catches; matcher-bytes's own
# de-duplication (ir.sls) is untouched by either.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a byte class lowers to only its lowest byte"
  # Not pinned on "one transition per byte, ascending: transitions": the
  # sibling mutation above ("dispatch cases are not sorted ascending by byte")
  # fails the SAME (case, check) pair, since both mutants touch the transition
  # list this pass's fixtures build.
  #
  # The pin is a record only THIS mutant produces: this mutant keeps one byte per
  # class, so the "a complement lowers to 254 transitions covering the
  # universe minus two" case's "count" check goes 254 -> 1; the sibling only
  # reverses order, so that case's length is unchanged (254 -> 254, "count"
  # passes) and it instead fails at check "first" (0 -> 255). Separable in
  # both directions: this pin does not occur anywhere in the sibling's
  # output, and the sibling's own pin ("transitions are sorted ascending by
  # byte: bytes -- expected (2 5), got (5 2)", on the "entry and transition
  # order" group) does not occur in this one's output either -- not because
  # this mutant skips that group (it runs there too, same as everywhere
  # else), but because that group's fixture ("two") uses only exact-byte
  # matchers, whose matcher-bytes is already a one-element list, so taking
  # the car of it is a no-op and the check still passes.
  FIND [[(bs (matcher-bytes (byte-case-matcher c)))]]
  REPLACE [[(bs (list (car (matcher-bytes (byte-case-matcher c)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a complement lowers to 254 transitions covering the universe minus two: count -- expected 254, got 1")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a class matching no bytes still contributes a transition"
  # FIND is whitespace-sensitive by design (disambiguating this closing
  # `bs)))` from others), so it goes stale on ANY reindentation of the
  # byte-dispatch-node branch in lower-machine's `declared` binding even when
  # the branch's own code is untouched -- update the indentation rather than
  # deleting the mutation.
  FIND [[                                                           bs)))]]
  REPLACE [[                                                           (if (null? bs) (list 0) bs))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "zero transitions: none")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an error node resolves to the declaration name, not its code"
  # Not pinned on the bare "unexpected-byte": the check-raises cases ("the two
  # unrepresentable trie shapes fail loudly") fail by printing their whole
  # returned normal-machine, whose error state carries this SAME resolved code
  # -- 'unexpected-byte is rej-decl's code in every seq-machine fixture too --
  # so the bare substring also occurs in two unrelated mutants' output.
  # Anchored to the full check line, which resolves to the one (case, check)
  # pair this mutation witnesses.
  FIND [[(error-declaration-code (car es)) (loop (cdr es))]]
  REPLACE [[(error-declaration-name (car es)) (loop (cdr es))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "code -- expected unexpected-byte, got rejected")

# Encoding decisions: the format version byte, the field count, and the
# declaration's static reason.
#
# The version byte cannot be pinned on its own text. `(put-u8 p 2)` occurs
# TWICE -- the version byte and the error-state tag -- so a bare literal FIND
# reports SITES 2 and fails at declaration. Each FIND below carries enough
# surrounding text to be unique in the file.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the format version byte names the wrong format"
  # Not the byte 1: that produces the identical one-byte digest as the "FNV
  # offset basis is changed" mutation (2974960947541485368, confirmed by a
  # control run of each). The two are arithmetically equivalent at FNV-1a's
  # first mix step, since flipping the basis's low bit and flipping the first
  # hashed byte's low bit reach the same state, so neither pin could
  # discriminate the other's mutant. Version 3 is not a format the encoder
  # emits and collides with nothing.
  FIND [[       (put-u8 p 2)
       (put-u32be p entry)]]
  REPLACE [[       (put-u8 p 3)
       (put-u32be p entry)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the IR fingerprint is the measured golden value: fingerprint -- expected 14095574568398596535, got 14172632155698282590")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the field count is written zero instead of the real count"
  # The count byte must carry the table's length. Pinned on the two-field
  # GOLDEN; it cannot be pinned on any of the inequality cases: with the
  # per-field records still written, zeroing the count leaves every
  # differing-field pair still unequal, so not one of them reddens. That is why
  # the two-field machine has a measured golden of its own instead of resting
  # on the "differ in fingerprint" family.
  FIND [[       (put-u16be p (length fields))]]
  REPLACE [[       (put-u16be p 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 14125028976508365705")

# Five mutations, one per remaining decision in the field record: its three
# components, the order the records are written in, and the slot number the
# table itself carries. Each is pinned on a DISTINCT golden value, all measured.

# Six mutations for the two zero-width kinds' encoding. Each is pinned on a
# DISTINCT measured golden value, which is this file's discipline for an
# encode arm: an inequality pair cannot see a dropped count or a transposed
# pair, only a wrong value can.

# Six mutations for integer accumulate's lowering and encoding at tag 7. Each
# on its own measured golden value -- the four that share a CASE are separated
# by their distinct `got` digests, which is what an exact-value pin buys over
# an inequality.

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the accumulate encode tag collides with field-branch"
  FIND [[                (put-u8 p 7)]]
  REPLACE [[                (put-u8 p 6)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR.a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 6374358628100294515")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an accumulate node's base is dropped from the encoding"
  # The base decides which bytes are digits, so a generated parser observes it
  # and two machines differing only in it are different machines.
  FIND [[                (put-u8 p (normal-field-selector s))
                (put-symbol p (car (normal-field-arguments s)))]]
  REPLACE [[                (put-symbol p (car (normal-field-arguments s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR.a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 9369177108359133434")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the accumulate nondigit edge's MODE is dropped"
  # The non-digit edge is normally a reexecute, so the mode is the
  # whole point of it being an edge rather than a bare target.
  FIND [[                  (put-u8 p (mode->byte (cdr (cadr tg))))
]]
  REPLACE [[                  ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR.a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 13335447011493986019")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the accumulate overflow target is dropped"
  FIND [[                  (put-u32be p (caddr tg)))]]
  REPLACE [[                  )]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR.a base-10 accumulate machine's fingerprint is the measured golden value: fingerprint -- expected 14659003778876959304, got 5178054717376752018")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an accumulate node's EOF edge is read as absent"
  # The unguarded-accessor hazard, in the normalizer: `eof-of` reads
  # `byte-dispatch-node-eof-target`, a bare slot read with NO tag guard, so
  # handing it an accumulate node returns a plausible value from the wrong slot.
  # `acc-eof-of` exists so that cannot happen, and this pins it.
  FIND [[(let ((t (integer-accumulate-node-eof-target n)))]]
  REPLACE [[(let ((t #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR.the EOF routing reaches the encoding: node routing -- expected 11426950116850452563, got 14659003778876959304")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an accumulate state is not widened to the declared layout"
  # The layout-length check is total over the states a fixture produces, so
  # a kind short of the declared layout cannot hide behind a kind-guarded
  # reader.
  FIND [[                                        (list (id-of (integer-accumulate-node-digit-target n))]]
  REPLACE [[                                        #f #f (list (id-of (integer-accumulate-node-digit-target n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer accumulate in the normalized IR.a base-10 accumulate machine's fingerprint is the measured golden value: case raised -- Exception in car")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a sequence-dispatch state is not widened to the declared layout"
  # `seq-state` builds EVERY sequence-dispatch node's state. A state short of
  # the declared eleven slots is invisible elsewhere: sequence states carry
  # kind `dispatch`, the only readers of slots 8-10 are kind-guarded, and every
  # other lane stays green with four of six states in the sequence-node fixture
  # three slots short.
  #
  # Its witness is deliberately TOTAL over the state kinds a fixture can
  # produce; a case naming one kind would pass throughout.
  FIND [[                        (seq-eof-of n) (eof-reason-of (seq-eof-of n))
                        #f #f #f))))]]
  REPLACE [[                        (seq-eof-of n) (eof-reason-of (seq-eof-of n))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every normalized state has the declared layout length.across every fixture and every state kind: no state is the wrong length -- expected \\(\\), got \\(8 8 8 8\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the field-action and field-branch encode tags collide"
  # Tags 5 and 6. Two machines identical but for the kind must differ.
  FIND [[                (put-u8 p 5)]]
  REPLACE [[                (put-u8 p 6)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 15366307625511038639")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field node's selector is dropped from the encoding"
  # `store` and `add` differ only here, and both are observable to a generated
  # parser, so two machines the fingerprint calls identical would emit different
  # behaviour without this.
  # Anchored on the field-ACTION arm specifically: the two arms open with the
  # same two lines, so the bare pair resolves to two sites. The tag byte above
  # is what distinguishes them.
  FIND [[                (put-u8 p 5)
                (put-symbol p (normal-field-selector s))
                (put-operands p (normal-field-arguments s))]]
  REPLACE [[                (put-u8 p 5)
                (put-operands p (normal-field-arguments s))]]
  EXPECT_STATUS 1
  # Pinned on the GOLDEN, not on the inequality case: a bare "these two differ"
  # record is also broken by every mutation that makes ALL fingerprints equal --
  # measured, it collided with both "the FNV prime is changed" and "the byte is
  # never mixed into the hash". An exact value is the only pin an inequality
  # cannot be confused with.
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 7772389593278784940")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field node's operand count is dropped"
  # Without the count the operand list has no boundary, so `(count 7)` followed
  # by the next record is indistinguishable from a three-operand list.
  FIND [[    (put-u16be p (length args))
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-branch machine's IR fingerprint is the measured golden value: fingerprint -- expected 13536979658827033743, got 16908098597654702240")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an operand's kind is not tagged"
  # The reason each operand carries a tag byte: without it a field literally
  # named `7` and the constant 7 could share bytes, and two different machines
  # would share a fingerprint.
  FIND [[                (cond ((symbol? a) (put-u8 p 0) (put-symbol p a))]]
  REPLACE [[                (cond ((symbol? a) (put-symbol p a))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 5142341432422259152")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an absent error target is encoded as state zero"
  # The reason the error target is written with a PRESENCE TAG rather than a
  # sentinel id: `clear` cannot fail and carries no target, and state 0 is a
  # perfectly ordinary state id, so a sentinel would make those two machines
  # share a fingerprint.
  FIND [[                  (if e (begin (put-u8 p 1) (put-u32be p e)) (put-u8 p 0))))]]
  REPLACE [[                  (if e (put-u32be p e) (put-u32be p 0))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-action machine's IR fingerprint is the measured golden value: fingerprint -- expected 1386504585301950044, got 6902603388614441453")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field branch's false target is not encoded"
  # A field branch has an explicit target for every possible result; an encoding
  # carrying only one of them describes a machine that does not exist.
  FIND [[                (put-u32be p (car (normal-field-targets s)))
                (put-u32be p (cdr (normal-field-targets s))))]]
  REPLACE [[                (put-u32be p (car (normal-field-targets s))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-branch machine's IR fingerprint is the measured golden value: fingerprint -- expected 13536979658827033743, got 7453673270761194114")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field's name is dropped from the encoding"
  FIND [[                   (put-symbol p (car f))
]]
  REPLACE [[                   ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 10230586532598973635")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field's width is dropped from the encoding"
  FIND [[                   (put-u8 p (cadr f))
]]
  REPLACE [[                   ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 8284907101070913187")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a field's initial value is dropped from the encoding"
  FIND [[                   (put-u64be p (caddr f)))]]
  REPLACE [[                   )]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 11089340831069462813")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: field records are written in reverse slot order"
  # Slot IS the record's position -- the slot number is deliberately not written
  # -- so record order is the whole of the slot assignment as far as the stream
  # is concerned, and a reversal is a different machine wearing the same bytes
  # everywhere else.
  FIND [[                 fields)]]
  REPLACE [[                 (reverse fields))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the IR fingerprint of a two-field machine is the measured golden value: fingerprint -- expected 5570336114768739383, got 3973801163924336519")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: every field is assigned slot zero"
  # The table's own slot number, which is what every consumer downstream indexes
  # by. Not witnessed by any fingerprint: the slot is not encoded, by design, so
  # this mutation moves no golden and the table assertion is its only witness --
  # the reason that assertion states each entry WHOLE, (name width initial slot),
  # rather than checking the length and the names. The entry's fifth element
  # is `settable?`, so the FIND carries the settable read after `slot`.
  FIND [[                            slot
                            (uint-field-settable? (car fs)))]]
  REPLACE [[                            0
                            (uint-field-settable? (car fs)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and settable.*second -- expected .limit 16 65535 1 #f., got .limit 16 65535 0 #f.")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an error state's reason is dropped from the encoding"
  # The reason must enter the ENCODING, not merely be
  # readable from the source machine, or two machines differing only in a reason
  # share a fingerprint and the fingerprint stops identifying what was emitted.
  FIND [[               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s))
                        (put-reason p (normal-error-reason s)))]]
  REPLACE [[               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the IR fingerprint is the measured golden value: fingerprint -- expected 14095574568398596535, got 3064965786472452921")

# The dispatch eof routing is part of the canonical encoding, so a dispatch
# state's resolved eof (the one-byte machine routes to the default-eof error,
# code 'eof) is mixed into the fingerprint. Dropping the default-eof code from
# the encoding moves the one-byte golden, so normal-ir-tests.sps's fingerprint
# case reddens.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a dispatch's default-eof routing is not encoded into the fingerprint"
  # The default-eof CODE must reach the encoding, so the REPLACE drops
  # put-symbol and keeps the declaration's static reason. The routing is
  # written once, in `put-eof-routing`, shared by the dispatch and accumulate
  # arms -- which is why each arm's CALL stays its own separately mutable line.
  FIND [[        (begin (put-u8 p 1) (put-symbol p (cdr eof))
               (put-reason p reason))))]]
  REPLACE [[        (begin (put-u8 p 1)
               (put-reason p reason))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 14095574568398596535, got 11628869637435983804")

# The NODE-eof encode arm -- tag 0 + u32be routed node id. The mutation above
# only witnesses the DEFAULT arm (tag 1 + code symbol), reached by the one-byte
# machine, whose eof goes to the default-eof error. normal-ir-tests.sps pins
# a second golden over the shared eof-machine, whose s0/s1 BOTH route eof to
# named nodes (finish 'done, error 'trunc), so dropping the routed node id from
# the canonical encoding moves ONLY that node-routing golden (the one-byte golden
# is untouched) and its fingerprint case is the sole witness. Distinct verbatim
# FIND from the default arm above (the '(cdr eof)' payload differs by encoder),
# so SITES stays 1.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a dispatch's node-eof routing target is not encoded into the fingerprint"
  FIND [[(begin (put-u8 p 0) (put-u32be p (cdr eof)))]]
  REPLACE [[(begin (put-u8 p 0))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fingerprint -- expected 13828870821654800916, got 15387434986975117383")

# Three mutations for the pause node in the normalizer. normal-ir-tests.sps
# carries a "pause normalization" group over the shared pause-machine
# fixture (s0 p1 s1 pe stop done trunc reject -> ids 0-7): a structural case
# (p1/pe's kind and resolved continuation target) and a fingerprint golden
# case, measured (not guessed) through the encode arm.
#
# The lower-arm mutation below stores a pause node's OWN id instead of its
# resolved continuation id. Measured: it fails "p1 target" (expected 2, got 1)
# and "pe target" (expected 5, got 3) -- the structural checks, which print
# the actual wrong id -- AND, as a side effect, "pause fingerprint" (the wrong
# id is also what gets hashed). EXPECT_OUTPUT_MATCHES pins the structural
# check, the more precise of the two witnesses.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a pause lowers its continuation id, not its own"
  FIND [[(cons 'node (id-of (pause-node-continuation n)))]]
  REPLACE [[(cons 'node i)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "p1 target")

# The encode-arm mutation drops the continuation id from the pause tag's
# encoded bytes (tag 4 alone, no u32be payload). Measured: it fails ONLY
# "pause fingerprint" -- no other machine in this SPEC lane has a pause node,
# so tag 4 is never encoded for the one-byte or node-routing goldens above,
# and this mutation cannot disturb them.
#
# Golden-family note. The "pause fingerprint" check label is unique in
# normal-ir-tests.sps, but uniqueness of the LABEL is not the question the pin
# answers. This label's FAIL line appears in the output of SEVEN other
# mutants of this same pass: every
# fingerprint-affecting mutation in the lane (FNV offset, FNV prime, byte
# mixing and error-code resolution -- the four that pin "14095574568398596535"
# -- node-eof routing, which pins "13828870821654800916", the pause lower arm,
# and the tag-value mutation below) moves the pause golden too, because the
# pause machine is hashed by the same algorithm. So the bare label said only
# "some fingerprint moved". What separates the siblings is the got value, which is
# distinct for each -- so both pause-encoding mutations below carry theirs,
# the same convention as the five above. The re-baseline cost is bounded: an
# IR-encoding change re-baselines the pause golden itself (in
# normal-ir-tests.sps), and these two move with it.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause encode arm hashes tag and continuation"
  # The arm carries a guarded optional-reason encoding; the REPLACE drops only
  # the u32be continuation, keeping the reason lines, so the mutant changes one
  # thing.
  FIND [[((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s))
                (let ((code (normal-error-code s)))
                  (when code (put-symbol p code) (put-reason p (normal-error-reason s)))))]]
  REPLACE [[((pause) (put-u8 p 4)
                (let ((code (normal-error-code s)))
                  (when code (put-symbol p code) (put-reason p (normal-error-reason s)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause fingerprint -- expected 4328141021048275055, got 466673759874206136")

# A third mutation targets the pause TAG VALUE alone (4 -> 3, colliding with
# finish's own tag byte) rather than the whole payload mutation 2 above
# already covers -- proving the tag byte itself, not just the u32be
# continuation id after it, is mixed into the fingerprint. Left unwitnessed,
# nothing would notice the two kinds' tag bytes becoming equal. (Their
# encodings as a whole stay distinguishable even then: a pause state still
# emits the 4 payload bytes a finish state does not.) Measured: it fails
# ONLY "pause fingerprint" (1 of 23 checks) -- same reasoning as mutation 2
# above: no other machine in this SPEC lane has a pause node, so this arm is
# never reached encoding the one-byte or node-routing goldens. It is witnessed
# by the same check as mutation 2, so a SHARED pin over that check would name
# neither decision (see the golden-family note above); each carries its own
# measured got value instead.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause tag collides with finish's tag"
  FIND [[(put-u8 p 4)]]
  REPLACE [[(put-u8 p 3)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause fingerprint -- expected 4328141021048275055, got 1277720883081950411")

# The sequence prefix trie and its two-phase state-id allocation. Each mutation
# witnesses one decision the trie section rests on; the two-guard pair proves
# normal-ir-tests.sps's check-raises cases are not vacuous (without the guard,
# the malformed trie node is silently built and normalize-machine returns
# instead of raising).
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the trie does not merge alternatives sharing a byte"
  # trie-put's equal-byte arm is what makes AB/AC share one root state instead
  # of the last-inserted alternative silently winning a byte-key tie (the
  # trie's whole reason to exist). Disabling only the "=" arm -- via a bound
  # no real byte value can cross -- leaves "<" and "else" untouched, so a
  # repeated byte falls through to "else" and is appended as a SECOND alist
  # entry instead of replacing the first: two (65 . _) transitions out of one
  # state where the trie should hold one.
  FIND [[          ((= b (caar cs)) (cons (cons b child) (cdr cs)))]]
  REPLACE [[          ((< b (- (caar cs) 1000000)) (cons (cons b child) (cdr cs)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a shared first byte becomes ONE transition into ONE state: root has a single transition -- expected \\(\\(65 4 advance\\)\\), got \\(\\(65 4 advance\\) \\(65 5 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: trie children are not kept ascending by byte"
  # trie-put's "<" arm is the insert-before-if-less test that keeps a trie
  # node's children alist sorted ascending -- the pre-order id allocation
  # depends on this, and so does the lowered states' ascending-by-byte
  # transition order. Flipping "<" to ">" sorts descending
  # instead: two alternatives diverging at position 0 (65, 88) come out of the
  # root in the wrong order.
  FIND [[          ((< b (caar cs)) (cons (cons b child) cs))]]
  REPLACE [[          ((> b (caar cs)) (cons (cons b child) cs))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "alternatives that diverge at position 0 get separate states: root -- expected \\(\\(65 4 advance\\) \\(88 5 advance\\)\\), got \\(\\(88 4 advance\\) \\(65 5 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: internal prefix ids are allocated breadth-first, not depth-first"
  # allocate-prefix-ids's own recursion is what makes id assignment DEPTH-first
  # pre-order: before moving to the next sibling, it
  # fully numbers the current child's whole subtree. The replacement below is a
  # level-order (breadth-first) walk over a queue of trie nodes instead:
  # every node's DIRECT interior children get consecutive ids before any
  # grandchild does. Over the A->{B terminal, C->D}, X->Y fixture this still
  # gives A id 5 (both walks visit the root's own children first), but C (A's
  # nested child) and X (A's root-level sibling) swap: depth-first finishes
  # A's subtree before X (C=6, X=7); breadth-first finishes the whole root
  # level before descending (X=6, C=7).
  FIND [[  (define (allocate-prefix-ids t next)
    (let walk ((cs (trie-children t)) (acc '()) (next next))
      (if (null? cs) (values (reverse acc) next)
          (let ((child (cdar cs)))
            (if (trie-interior? child)
                (let-values (((sub next2) (allocate-prefix-ids child (+ next 1))))
                  (walk (cdr cs) (append (reverse sub) (cons (cons child next) acc)) next2))
                (walk (cdr cs) acc next))))))]]
  REPLACE [[  (define (allocate-prefix-ids t next)
    (let loop ((queue (list t)) (next next) (acc '()))
      (if (null? queue) (values (reverse acc) next)
          (let* ((cs (trie-children (car queue)))
                 (interior (filter (lambda (kv) (trie-interior? (cdr kv))) cs)))
            (let assign ((items interior) (next next) (acc acc) (kids '()))
              (if (null? items)
                  (loop (append (cdr queue) (reverse kids)) next acc)
                  (let ((child (cdr (car items))))
                    (assign (cdr items) (+ next 1) (cons (cons child next) acc) (cons child kids)))))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "depth-first pre-order, not breadth-first: root -- expected \\(\\(65 5 advance\\) \\(88 7 advance\\)\\), got \\(\\(65 5 advance\\) \\(88 6 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: internal prefix states do not append after the declared block"
  # prefix-blocks threads id allocation starting at declared-count: declared
  # nodes keep their declaration index, and every internal state appends after
  # the whole declared block. Starting at 0
  # instead collides internal ids with the declared nodes' own ids (0 is
  # 'seq's own id), corrupting the positional states vector.
  FIND [[            (let loop ((ns nodes) (next declared-count) (acc '()))]]
  REPLACE [[            (let loop ((ns nodes) (next 0) (acc '()))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the declared node keeps its declaration index and the prefix states append: root -- expected \\(\\(1 3 advance\\)\\), got \\(\\(1 0 advance\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a terminal trie child consumes an id it should not"
  # allocate-prefix-ids's non-interior branch is what makes a TERMINAL child
  # (an alternative's own byte-run end) consume no id -- its byte routes
  # straight to the alternative's declared target, never to a lowered prefix
  # state. Making it allocate one anyway grows the four-byte single-alternative
  # fixture from 6 states to 7 and shifts every id after the first terminal.
  FIND [[                (walk (cdr cs) acc next))))))]]
  REPLACE [[                (walk (cdr cs) (cons (cons child next) acc) (+ next 1)))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "three declared nodes plus three internal prefix states: count -- expected 6, got 7")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the duplicate-alternative guard is dropped"
  # trie-insert's bs-null branch is where an alternative's OWN path ends;
  # trie-terminal already set there means some earlier alternative ended at the
  # exact same byte run (an unrepresentable shape, direction 1). Disabling this
  # guard silently overwrites the earlier target instead of raising, so "two
  # identical alternatives are an assertion violation" (normal-ir-tests.sps)
  # goes from a raise to a normal return -- proving that check-raises case is
  # not vacuous.
  FIND [[          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "duplicate sequence alternative" target))
]]
  REPLACE [[          (when #f
            (assertion-violation 'normalize-machine "duplicate sequence alternative" target))
]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "two identical alternatives are an assertion violation: AB\\|AB -- expected a raise, but the thunk returned")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the ambiguous-prefix guard is dropped"
  # trie-insert's bs-non-null branch is where a LATER alternative's path tries
  # to descend past a node an earlier alternative already terminated at
  # (the unrepresentable shape, direction 2 -- AB is a strict prefix of ABC).
  # Disabling this guard lets insertion continue, silently producing a trie
  # node that is both terminal and interior; later code treats it as interior
  # only, so the earlier alternative's target becomes unreachable with nothing
  # failing -- a miscompile -- and "AB|ABC" goes from a raise to a normal
  # return.
  FIND [[        (begin
          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  REPLACE [[        (begin
          (when #f
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "an ambiguous terminal prefix is an assertion violation: AB\\|ABC -- expected a raise, but the thunk returned")

# seq-state's own `id` argument: the internal prefix state's own state-id
# field, distinct from its POSITION in the states vector. Every other check
# reads a state by its vector position, never its own id field, so
# normal-ir-tests.sps asserts normal-state-id on the four-byte fixture's three
# internal states (ids 3, 4, 5) and the depth-first fixture's three (ids 5, 6,
# 7). Zeroing every internal state's id collides ids 3, 4 and 5 all onto 0.
# Anchored to "id 4", not "id 3": id 3 also reads
# "expected 3, got 0" in the sibling "internal prefix states do not append
# after the declared block" mutation's own output above (that mutation
# renumbers the whole internal block starting at 0, so ITS first internal
# state's id is also, coincidentally, 0) -- measured by running both mutants
# and cross-checking pairwise, per the both-directions pin sweep.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an internal prefix state's own id field is wrong"
  # `internal` walks TWO families, so the prefix arm sits inside an `if` on
  # the block's kind.
  FIND [[(map (lambda (kv) (seq-state n (car kv) ids (cdr kv))) ids)]]
  REPLACE [[(map (lambda (kv) (seq-state n (car kv) ids 0)) ids)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "internal prefix states carry their own id, not a placeholder: id 4 -- expected 4, got 0")

# trie-insert's bs-null branch carries a THIRD guard -- (when
# (trie-interior? t) ...) -- distinct from the bs-non-null branch's own
# trie-terminal guard the "ambiguous-prefix guard is dropped" mutation above
# witnesses. It fires only when a LONGER alternative is inserted BEFORE its
# own prefix (every fixture above inserts short-first, so none reaches this
# clause). normal-ir-tests.sps has a reverse-order fixture (ABC before AB) to
# witness it; disabling the guard lets that fixture's ambiguous prefix
# build silently instead of raising.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the bs-null-branch ambiguous-prefix guard is dropped"
  FIND [[          (when (trie-interior? t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  REPLACE [[          (when #f
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "an ambiguous terminal prefix inserted in reverse order is also caught: ABC\\|AB -- expected a raise, but the thunk returned")

# The callback state's encoding. Every part the ABI carries must enter the
# encoding: a callback declaration encoded by NAME alone lets two machines
# differing in `required?` share a fingerprint and emit different libraries.
# The separability group in normal-ir-tests.sps varies one encoded part at a
# time; these three prove that group is not vacuous.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the callback encode tag collides with field-action"
  # Pinned on the GOLDEN, not on a pairwise inequality: a tag change moves every
  # callback fingerprint together, so every inequality in that group survives it
  # and only a fixed value can see it -- the same argument as the accumulate
  # tag's own mutation.
  FIND [[               ((callback)
                (put-u8 p 10)]]
  REPLACE [[               ((callback)
                (put-u8 p 5)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the base machine verifies and normalizes: fingerprint -- expected 4714737223744993991")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a callback node's resolved slot is dropped from the encoding"
  # The slot is what the ABI carries -- the emitted arm indexes `cbv` with it --
  # so two machines whose nodes invoke different declarations would share a
  # fingerprint and call different procedures. The following line rides along in
  # both halves because the runner refuses an empty REPLACE.
  FIND [[                (put-u16be p (normal-field-selector s))
                (let ((tg (normal-field-targets s)))]]
  REPLACE [[                (let ((tg (normal-field-targets s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each part varied alone moves the fingerprint: and every one moved the fingerprint -- expected \\(\\), got \\(slot\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a callback branch's KEY is dropped from the encoding"
  # Only the targets would remain, so a machine whose declaration renames a key
  # -- and whose emitted arm therefore matches a different returned symbol --
  # would share a fingerprint with the original.
  FIND [[                              (put-symbol p (car b))
                              (put-u32be p (cdr b)))]]
  REPLACE [[                              (put-u32be p (cdr b)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each part varied alone moves the fingerprint: and every one moved the fingerprint -- expected \\(\\), got \\(branch-key\\)")

# The span states' encoding, and the SECOND family of internal states (a span
# end's completion state), which is what makes the internal-state allocation
# handle more than one family.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the span-end encode tag collides with span-start"
  # Pinned on the GOLDEN, for the reason the callback tag's own mutation states:
  # a tag change moves every span fingerprint together, so every pairwise
  # inequality in that group survives it and only a fixed value can see it.
  FIND [[               ((span-end)
                (put-u8 p 12)]]
  REPLACE [[               ((span-end)
                (put-u8 p 11)]]
  EXPECT_STATUS 1
  # The span fixture's tail routes through a dispatch: a span end is a parked
  # state, so a span end continuing straight into a stop fails verification.
  EXPECT_OUTPUT_MATCHES "the base machine verifies and normalizes: fingerprint -- expected 8308402030897048213")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a span node's slot is not resolved against the declarations"
  # The slot is what the ABI carries, so two machines whose nodes name different
  # spans would share a fingerprint and open different spans.
  #
  # Anchored on the RESOLUTION rather than on one arm's `put-u16be`: dropping the
  # span-start arm's write alone leaves the span-end's, so the `span-slot` row --
  # which moves BOTH nodes -- still separates and only the golden would notice,
  # which is the tag mutation's pin. Collapsing the resolution moves the row
  # itself, and the two mutations stay distinguishable.
  FIND [[                      ((eq? (span-declaration-name (car sp)) nm) i)]]
  REPLACE [[                      ((eq? (span-declaration-name (car sp)) nm) 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and every one moved the fingerprint -- expected \\(\\), got \\(span-slot\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a span end lowers to a fused state instead of two"
  # A span end resumes at the next undelivered substep, which a fused state
  # cannot express because it has ONE resume point. Caught
  # by the state count, which is what makes the claim checkable rather than
  # asserted.
  FIND [[                      ((span-end-node? n)
                       (loop (cdr ns) (+ next 1) (cons (list n 'span-end #f next) acc)))]]
  REPLACE [[                      ((and #f (span-end-node? n))
                       (loop (cdr ns) (+ next 1) (cons (list n 'span-end #f next) acc)))]]
  EXPECT_STATUS 1
  # A RAISE, and it is the decision's own consequence rather than an incidental
  # crash: with no block allocated, `completion-id-of` cannot answer and says so
  # by name. There is no opposite constant to try.
  EXPECT_OUTPUT_MATCHES "span end has no continuation state")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the debug map skips the second internal family"
  # The debug map must stay TOTAL, and the public parser state names the
  # source span node rather than a generated continuation. The map crosses the
  # seam as ABI payload member 2, so an incomplete one is an index error in the
  # generated lane.
  FIND [[                                        (list (cons ids (node-name n))))))]]
  REPLACE [[                                        '())))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "every state id has a source name -- expected \\(\\), got \\(6\\)")

# --- The counted-consume state's lowering and encoding
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the counted-consume encode tag collides with span-completion"
  FIND [[                (put-u8 p 14)]]
  REPLACE [[                (put-u8 p 13)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a counted-consume machine's fingerprint is the measured golden value: fingerprint -- expected 8698736890881894294, got 16257961618954127535")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's field name is dropped from the encoding"
  # The accumulate arm writes the same put-symbol line; the FIND is unique
  # through its second line, which only this arm has.
  # The three drift-pair pins here ("… field name …",
  # "… successor …", "… EOF routing …") are also satisfied by "normal-ir: the
  # FNV prime is changed" and "normal-ir: the byte is never mixed into the hash",
  # which degenerate the hash so every pair collides; and the EOF-routing pin by
  # "normal-ir: a counted consume's EOF edge is read as absent", which makes the
  # node-routed variant encode as the base. By construction of a drift pair: any
  # mutant that collapses two fingerprints satisfies a pin that expects them apart.
  FIND [[                (put-symbol p (car (normal-field-arguments s)))
                (put-u32be p (car (normal-field-targets s)))]]
  REPLACE [[                (put-u32be p (car (normal-field-targets s)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the field, the successor and the EOF routing each reach the encoding: the field differs -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's successor is dropped from the encoding"
  FIND [[                (put-u32be p (car (normal-field-targets s)))
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)]]
  REPLACE [[                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the field, the successor and the EOF routing each reach the encoding: the successor differs -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's EOF routing is dropped from the encoding"
  FIND [[                (put-u32be p (car (normal-field-targets s)))
                (put-eof-routing p (normal-dispatch-eof s) (normal-error-reason s)))
               ((field-branch)]]
  REPLACE [[                (put-u32be p (car (normal-field-targets s))))
               ((field-branch)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the field, the successor and the EOF routing each reach the encoding: the EOF routing differs -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume lowers a second successor"
  FIND [[                                        (list (id-of (counted-consume-node-next n))))))]]
  REPLACE [[                                        (list (id-of (counted-consume-node-next n)) 0))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one successor -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a counted consume's EOF edge is read as absent"
  # `count-eof-of` reads the machine default for every node, so the node-routed
  # variant encodes exactly like the base machine -- a predictable `got`.
  FIND [[                           (let ((t (counted-consume-node-eof-target n)))]]
  REPLACE [[                           (let ((t #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "node EOF routing -- expected 11703601680155498763, got 8698736890881894294")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 36: the emitter -------------------------------------------------------
#
# compile-tests.sps checks the compilation contract, the binding reserved-set
# (all three members), and the rendered library structure by substring. This
# pass proves those checks are not vacuous. Verify command uses both library
# roots, an empty object guard, the compile program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/compile-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: emitted exec loses a reserved parameter"
  # Without this mutation no FIND anchors on the emitted `exec` parameter list,
  # so a change to the emitted signature is invisible to this suite.
  # compile-tests.sps's "exec carries its three reserved parameters" is the
  # only assertion naming that line as TEXT, and the only one that runs in
  # this mutation's own SPEC lane. It is not the only thing in the tree that
  # would notice -- the committed goldens carry the same line and the
  # determinism lanes compare them byte for byte.
  #
  # Dropping `cbv` -- the last parameter -- rather than mangling the whole list:
  # a caught-by-COMPARISON failure of the signature assertion, not a raise from
  # some later arity mismatch, which is what AGENTS.md prefers and what makes the
  # record name this decision.
  FIND [["  (define (exec state offset bv start end finish? fieldv psr cbv)\n"]]
  REPLACE [["  (define (exec state offset bv start end finish? fieldv psr)\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "exec carries its three reserved parameters: the full parameter list")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: a non-empty option list is accepted"
  FIND [[(unless (null? options)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a non-empty option list is refused: refused")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an invalid machine is reported as compiled ok"
  FIND [[(if (verification-ok? v)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an invalid machine does not compile and carries diagnostics: not ok")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an unverified compilation is rendered anyway"
  FIND [[(unless (compilation-ok? compilation)]]
  REPLACE [[(unless #t]]
  # The detail is part of the pin, not decoration: the invalid-machine mutation
  # above breaks this same check, but there render RETURNS bytes ("expected a
  # raise, but the thunk returned ..."), while dropping the guard here makes it
  # raise the wrong object. Without the detail the two are indistinguishable.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "render refuses a compilation that failed verification: not ok -- raised object did not satisfy the predicate")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the binding grammar check is dropped"
  # The grammar is one call into names.sls, so the mutant drops that call: a
  # grammar-invalid binding renders.
  FIND [[(and (portable-name? sym)]]
  REPLACE [[(and #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "grammar")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 1 is not checked"
  FIND [[(not (memq sym reserved-member-1))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 1")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 2 is not checked"
  FIND [[(not (memq sym reserved-member-2))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 2")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 3 is not checked"
  FIND [[(not (memq sym reserved-member-3))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 3")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an advance transition is lowered as a reexecute"
  FIND [[(string-append "(%s" (number->string target) " (+ pos 1) " (number->string target)
                       " (+ off 1) (quote boundary))")]]
  REPLACE [[(string-append "(%s" (number->string target) " pos " (number->string target)
                       " off (quote byte))")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "advance arm")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the reexecute fallback is lowered as an advance"
  FIND [[(string-append "(%s" (number->string target) " pos " (number->string target)
                       " off (quote byte))")]]
  REPLACE [[(string-append "(%s" (number->string target) " (+ pos 1) " (number->string target)
                       " (+ off 1) (quote boundary))")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "the accepted byte advances and the fallback reexecutes: fallback")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the error arm omits the resolved code"
  # The arm renders a parser-error record, so the resolved code reaches it
  # through the errs-table INDEX rather than as a rendered symbol. Dropping the
  # index to a constant 0 makes every error report the first declaration's
  # code.
  FIND [[(number->string (index-of (normal-error-code s)
                                                  (normal-error-reason s))) ") (quote "]]
  REPLACE [["0" ") (quote "]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "error arm")

# The emitter renders the unified `exec` with a finish? EOF branch and a
# distinct finish terminal arm. compile-tests.sps has a finish-node fixture
# (eof-fin) whose entry dispatch routes eof to a finish node, so all three
# emitter decisions below have a witness in the compile SPEC lane. Each FIND
# is a unique verbatim substring.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: a finish node renders the stopped terminal instead of finished"
  FIND [[(quote finished) pos #f " id " off))\n"]]
  REPLACE [[(quote stopped) pos #f " id " off))\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish arm")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the exhausted-dispatch eof branch drops the resolved default-eof code"
  # The default-eof arm renders a parser-error record, so the resolved code
  # reaches it through the errs-table index. NOT "0": the default-eof
  # declaration IS index 0 in every fixture, so that REPLACE would be a no-op
  # and the mutation UNCAUGHT. Index 1 is the `rejected` declaration, so the
  # arm reports the wrong code.
  FIND [[(number->string (index-of (cdr eof) reason)) ") (quote " (symbol->string name)]]
  REPLACE [["1" ") (quote " (symbol->string name)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof routes to the default-eof error")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the exhausted dispatch does not branch on finish?"
  # Anchored in `render-exhausted-preamble`, which the dispatch and accumulate
  # arms share: the two preambles ARE the same decision, so the pin covers
  # both.
  FIND [[     "       (if (>= pos end)\n"
     "           (if finish?\n"]]
  REPLACE [[     "       (if (>= pos end)\n"
     "           (if #f\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish eof guard")

# The pause node in the emitter. compile-tests.sps has a third inline fixture
# (the pause machine, following the eof-fin precedent above -- the compile
# lanes carry no fixture libraries, and (byte-machine test pause-machine) is
# the source of truth the fixture is kept in sync with by hand) whose rendered
# text pins both pause arms: p1's (continuation target 2) and pe's
# (continuation target 5).
#
# Both mutations below break the SAME two checks, "pause arm p1" and "pause
# arm pe". A substring probe under `check` has content-blind failure text
# ("expected a true value"), so a shared pin would prove a pause arm was
# wrong, never which of the two emitter decisions was wrong. The checks are
# check-equal over the status token and the next state read out of that one
# rendered arm line (compile-tests.sps's `pause-arm`), so the detail carries
# the mutant's own answer and each mutation pins its own measured signature.
# Splitting a substring probe in two does NOT work: a
# pause continuation is a dispatch node whose own need-input arm parks on that
# same state id, so " pos #f 2 off))" survives the next-state mutation
# elsewhere in the rendered text and a target-only probe would be vacuous.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm emits paused"
  # The callback arm's own pause branch renders the same outcome constructor, so
  # the bare form occurs twice. Anchored on the PAUSE ARM's `") (` prefix, which
  # the callback arm -- whose branch opens `((pause) (` inside a `case` -- does
  # not share.
  FIND [[pk) (byte-machine-make-feed-outcome/v1 (quote paused) pos "]]
  REPLACE [[pk) (byte-machine-make-feed-outcome/v1 (quote stopped) pos "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause arm p1 -- expected \"paused 2\", got \"stopped 2\"")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm's next-state is the continuation"
  FIND [[(number->string (normal-pause-target s)) " off))\n"))]]
  REPLACE [[id " off))\n"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "pause arm p1 -- expected \"paused 2\", got \"paused 1\"")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: member 0 is emitted empty regardless of the declarations"
  # ABI member 0 carries the field declarations. The zero-field rendering is
  # pinned by the case before this one -- `(quote #(#()))` -- so this mutation
  # witnesses the NON-empty rendering.
  FIND [[           (fields (let loop ((fs (normal-machine-fields normal)) (acc "")]]
  REPLACE [[           (fields (let loop ((fs '()) (acc "")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field-declaring machine renders its declarations in member 0: pairs in slot order -- expected a true value")


# --- The structural witness that a counted consume commits in bulk ------------
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the emitted counted arm renders a per-byte self-loop"
  # Behaviour-identical: one byte per iteration through the same state, the count
  # decremented each time, the zero-count and exhausted clauses unchanged -- so
  # every behavioural lane passes, and within this SPEC only the datum walk over
  # the emitted arm (no `min`, a `(+ pos 1)`) can see it -- the committed counted
  # golden, being bytes, would see the changed text too. A differential is
  # blind to it by construction.
  FIND [[            "                (let ((n (min v (- end pos))))\n"
            "                  (vector-set! fieldv " slot " (- v n))\n"
            "                  (if (= n v)\n"
            "                      (%s" (num next-id) " (+ pos n) " (num next-id) " (+ off n) (quote boundary))\n"
            "                      (byte-machine-make-feed-outcome/v1 (quote need-input) (+ pos n) #f " id " (+ off n))))))))\n")))]]
  REPLACE [[            "                (begin (vector-set! fieldv " slot " (- v 1))\n"
            "                       (loop (+ pos 1) " id " (+ off 1) (quote boundary)))))))\n")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted arm applies min exactly once and never advances by one: exactly one min -- expected 1, got 0")

# Declared names never reach identifier position in the emitted library. Each
# mutation drops a quote wrapper in one render-state-arm arm, so a DECLARED name
# is emitted in identifier position; the identifier-position walk over the
# every-construct witness catches it (the leftover is no longer exactly the
# binding and the machine name).
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "the span-open arm emits the span name unquoted (identifier position)"
  FIND [[            "       (begin (byte-machine-span-open/v1 psr (quote "]]
  REPLACE [[            "       (begin (byte-machine-span-open/v1 psr ("]]
  EXPECT_OUTPUT_MATCHES "only the binding and the machine name remain -- expected .ecw ecw-parser., got .ecw")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "the error arm emits the source-node name unquoted (identifier position)"
  FIND [[                                                  (normal-error-reason s))) ") (quote "]]
  REPLACE [[                                                  (normal-error-reason s))) ") ("]]
  EXPECT_OUTPUT_MATCHES "only the binding and the machine name remain -- expected .ecw ecw-parser., got .ecw")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 37: identifier repertoire + LF ----------------------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/identifier-repertoire-tests.sps")

# The two grammar pins below mutate names.sls, where the one `portable-name?`
# body lives. No separate mutation pins compile.sls's binding grammar:
# valid-binding? calls the same body, so its observation (a binding `a.b`
# accepted) is exactly the interior-character pin's. Each FIND is unique in
# names.sls on its own. The identifier-repertoire lane drives the verify site
# AND the compile site; the pins name the verify-site record, which is the
# first the harness prints.
byte_machine_mutation(
  FILE src/byte-machine/private/names.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "names: a name with a non-lowercase first char is accepted"
  FIND [[(lower-alpha? (string-ref s 0))
           (let loop ((i 1))]]
  REPLACE [[#t
           (let loop ((i 1))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "every rejected name is refused: reject 9a")

byte_machine_mutation(
  FILE src/byte-machine/private/names.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "names: any interior character is accepted"
  FIND [[(or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))]]
  REPLACE [[#t)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "every rejected name is refused: reject a_b")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "compile: the emitted library line's terminator is CRLF"
  # Anchored on the library line: no payload change reaches it, every machine
  # renders it, and a CRLF injected there fails "no carriage return byte
  # appears and the last byte is LF". Do not move it to the render tail -- the
  # tail is where every ABI payload change lands, so a pin there breaks
  # without the decision it names changing.
  FIND [["(library (generated " mname ")\n"]]
  REPLACE [["(library (generated " mname ")\r\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no carriage return byte appears and the last byte is LF: carriage return present")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 38: determinism vs golden ---------------------------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-one-byte-tests.sps"
  # the golden lives in the source tree; the staged program reads it via env
  # (BYTE_MACHINE_GOLDEN_FILE, supplied by this suite's own ctest registration
  # and inherited unmodified through execute_process -- see "WHAT THIS SUITE
  # NEEDS FROM ITS ENVIRONMENT" above)
  )

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.one-byte.chez.source
  LABEL "compile: the errs table carries declarations the graph never reaches"
  # The encoding carries a reason only where one is resolved, so a declaration
  # nothing names never reaches the IR fingerprint; emitting it anyway makes two
  # machines the fingerprint calls identical emit different bytes. Witnessed by
  # the determinism lane's own equal-fingerprints-equal-bytes case, which is
  # where the property belongs: the fingerprint is what the determinism checks
  # compare.
  #
  # The filter tests a (code . reason) PAIR, because the normalizer resolves
  # each site's declaration name to its code and reason before the emitter sees
  # it. An UNREACHED declaration duplicating a reached one passes the
  # membership test, so the filter also drops a pair it has already emitted.
  #
  # *** No separate mutation pins the dedup half: it is SUBSUMED by this
  # mutation. Measured, with the separating attempts recorded, which is what
  # AGENTS.md requires before the word is used. *** Suppressing only the dedup
  # (`(and (member pair reached) (not (member pair …)))` -> `(member pair
  # reached)`) fails exactly two cases, and this mutation fails both of them plus
  # "equal fingerprints emit equal bytes", so the narrow set is a strict subset
  # of this one's. THREE separating constructions were tried and all three fail:
  #   * A machine with an unreached DISTINCT pair separates them in behaviour but
  #     not in records -- the dedup mutant is CORRECT there, so it reddens
  #     nothing a pin could name.
  #   * A machine whose every declaration is reached with two sharing a pair
  #     makes the two mutants emit IDENTICAL text.
  #   * Both together: this mutation emits one more entry than the dedup mutant,
  #     but every record the dedup mutant produces, this one produces too.
  # The dedup is strictly less permissive than this mutation on every machine, so
  # no fixture can redden it while leaving this one green. The BEHAVIOUR is
  # witnessed -- two determinism-one-byte-tests.sps cases fail against the
  # dedup mutant, measured -- it is the separate PIN that no fixture supports.
  FIND [[                                (if (and (member pair reached)
                                         (not (member pair
                                                      (map (lambda (d)
                                                             (cons (error-declaration-code d)
                                                                   (error-declaration-reason d)))
                                                           acc))))
                                    (cons (car ds) acc) acc))))))]]
  REPLACE [[                                (cons (car ds) acc))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "equal fingerprints emit equal bytes: and so do the emitted bytes")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.one-byte.chez.source
  LABEL "compile: the writer's export line spacing changes"
  FIND [["  (export " bstr ")\n"]]
  REPLACE [["  (export  " bstr ")\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted bytes equal the committed golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 39: property differential is non-vacuous -----------------------------
#
# Pass 36 witnesses the emitter's lowering against fixed machines; this pass
# runs a lowering mutation against the *property* lane, so the
# generated-machine differential is proven to notice divergence too, not just
# a fixed example. The pass also witnesses the property driver's own pause
# protocol, the generator's draw tables (each removal caught by a counter or a
# totality row), and the driver's Layer-3 invariant rows. All run the same
# property-differential-tests.sps program.
#
# Pin sweep over this pass's mutations (re-run after any change here): the
# per-pin match-count matrix has an all-ONE diagonal (every pin matches its own
# mutant's output exactly once) and an all-ZERO off-diagonal. The floor check
# ("the accepted count is at least the floor") co-fires on every removal that
# drops acceptance below the floor (counted-consume and exact-byte); that is
# BY CONSTRUCTION of the CHECK, and each such removal is pinned on its own
# totality row (member-specific got-list) instead. The floor's own pin
# belongs to "machine-gen: the entry names a node that is never built
# (rejects everything)", as a conjunction with a record no removal emits.
# The property verify command is the only "--program
# …/property-differential-tests.sps" in this file, and MutationRunner ignores
# SPEC when VERIFY_COMMAND is set, so a pin is judged only against this
# program's output. No check label is matched by any pin except its owner.
#
# WHAT A CLEAN SWEEP DOES NOT SAY (AGENTS.md): a whole-pass sweep re-judges the pins
# that EXIST; it cannot notice a decision no pin names -- not the two tombstones
# below, and not a construct in the generator that no pin covers. The
# per-member pins here are a REPRESENTATIVE subset, not one-per-member: the eight
# structural node kinds (byte-dispatch, stop, error, field-action, field-branch,
# callback, span-start, span-end), five of seven field operations (clear, increment,
# decrement, add, set-mask), five of seven field predicates (zero, nonzero, range,
# mask-any, mask-all), one of four callback outcomes (continue), and the derived
# accumulate-overflow / declares-field counters have NO dedicated mutation pin. For
# a DRAWN family every one of those removals is still caught by its totality row's
# set-equal (source-vs-table), and for the two DECLARED families with no draw table
# (span events, schedule shapes) the totality row compares the driver's family to a
# cited literal, unexercisable by a table removal. "Not a counter" is exact only for
# byte-dispatch/stop/error/field-action/field-branch, whose counters are fed
# unconditionally (entry, fixed terminals, coverage prefix); removing callback,
# span-start or span-end WOULD also zero their counters, since the coverage segment
# that feeds them is gated on the draw table -- but no pin removes them either way.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-differential-tests.sps")

# The property lane runs over the driver ((byte-machine test property-driver))
# and the generator draws over every node construct.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.property.differential.chez.source
  LABEL "compile: the dispatch byte test is inverted, diverging from the oracle"
  FIND [[       (if (= lo hi)
           (string-append "(fx=? b " (num lo) ")")
           (string-append "(and (fx>=? b " (num lo) ") (fx<=? b " (num hi) "))"))]]
  # The emitted dispatch's `case` key is the source byte, unshifted, so the
  # generated executor agrees with the interpreter oracle; inverting it diverges
  # on every machine. The lane's Layer-1 comparison fails per machine as
  # "machine <i> (seed <s>) byte agreement", and the pin names ONE accepted
  # machine index (machine 0 is accepted at seed 20260823) with its parens
  # escaped, so it matches exactly one record. The bare "byte agreement"
  # substring would match every accepted machine.
  REPLACE [[       (if (= lo hi)
           (string-append "(fx=? b " (num (mod (+ 1 lo) 256)) ")")
           (string-append "(and (fx>=? b " (num (mod (+ 1 lo) 256)) ") (fx<=? b " (num (mod (+ 1 hi) 256)) "))"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[machine 0 \(seed 20260823\) byte agreement]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-differential: resume-pair! stops calling parser-resume!"
  # The pause protocol lives in the driver, so the resume site is in
  # property-driver.sls. Skipping the real resume leaves both parsers at
  # paused-feed; the driver's next feed then trips runtime.sls's
  # lifecycle-violation guard. The drive runs inside the lane's accounting
  # harness-case, so the raise is recorded as "case raised" with the condition's
  # own detail (status 1), not an uncaught exit-255. Pinned to the measured
  # detail tuple "paused-feed feed" -- metacharacter-free, and printed by
  # nothing else in this program.
  FIND [[(list (parser-resume! pr) (parser-resume! pg))]]
  REPLACE [[(list 'feed-ready 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "paused-feed feed")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the pause node kind is dropped from the draw table"
  # The generator draws node kinds from node-kind-draw-table, and the coverage
  # segment's pause node is gated on that table too. Removing `pause` from the
  # table means no generated machine can reach a pause node, so the
  # interpreter-only pause counter reads zero. Pinned to the full
  # interpreter-only label plus the detail -- the half no cross-lane divergence
  # can zero, and not the bare "observes a pause" substring, which matches two
  # labels.
  FIND [[error finish pause]]
  REPLACE [[error finish]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes a pause -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the eof route stops offering a finish terminal"
  # The eof draw's finish member is the `tfin` finish terminal offered by
  # eof-route!. The EOF route is the only accepted producer of a REACHABLE
  # finish, so removing it zeros the finish counter. Pinned to the full
  # interpreter-only label plus the detail.
  FIND [[((= r 1) (use-term! 'tfin))]]
  REPLACE [[((= r 1) (use-term! 'terr))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes an idle-completion finish -- expected a true value]])

# --- Tombstones: two decisions the generator makes UNOBSERVABLE, recorded so
# the next reader does not re-add them.
#
# No mutation pins "the pinned accumulate case advances instead of
# reexecuting": the generator has no pinned digit case, and every inbound mode
# is drawn. The lane feeds the 256 single-byte trials AND drawn inputs of
# length 0-6 under every split point, so an advance inbound edge leaves the
# accumulate node a byte to read and the digit arm runs either way; reexecute
# is not load-bearing there, and no construct in the generator carries the
# decision.
#
# No mutation pins "the accumulate field's initial is one below the only
# workable value": the generator draws one or two uint fields at drawn widths
# and drawn initials, so there is no chosen constant to move by one. Forcing a
# drawn initial to 0 does NOT zero the overflow counter (six base-10 digits
# overflow a u8 from 0, and inputs run to six bytes), and forcing it to (-
# (expt 2 width) 1) zeros the COMMIT counter instead -- a different decision.

# --- Counter pins. Each removes what PRODUCES an observed value and is caught
# by a failed COMPARISON. They sit between Pass 39's reset() and its run() so
# they join Pass 39, not Pass 40. Pins are the interpreter-only half's full
# label plus the detail. The node kinds produced by fixed terminals, the
# entry, or the coverage prefix/segment (byte-dispatch, stop, error,
# field-action, field-branch, callback, span-start/-end, and the
# span-event/callback-outcome families they gate) have no per-construct
# mutation (see "WHAT A CLEAN SWEEP DOES NOT SAY" above). The six Layer-3
# invariant pins are below -- each inverts one row of check-invariants and
# reddens the driver's single Layer-3 oracle check, whose detail names the row.

byte_machine_mutation(
  FILE test/common/property-differential-tests.sps
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-differential: the verifier filter is dropped, executing rejected draws"
  FIND [[(verification-ok? v)]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES [[no draw reached an executor unverified]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the entry names a node that is never built (rejects everything)"
  FIND [[(make-machine 'gen 'cova]]
  REPLACE [[(make-machine 'gen 'no-such-entry]]
  # A CONJUNCTION. The floor check alone is reddened by every removal that drops
  # acceptance below the floor -- measured: "machine-gen: the counted-consume
  # node kind is dropped from the draw table" and "machine-gen: the exact-byte
  # matcher kind is dropped from the draw table" -- so it cannot say which
  # mutant fired. The floor stays in the pin, because it is the check this
  # mutant exists to witness; the sentinel's count of ZERO is what only a draw
  # that rejects everything produces. Its expected count is left open
  # (`[0-9]+`): the decision is the zero, and the measured total moves whenever
  # the generator does.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    [[the accepted count is at least the floor -- expected a true value.*the counter pass ran over the measured accepted machines -- expected [0-9]+, got 0]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the sequence-dispatch node kind is dropped from the draw table"
  FIND [[byte-dispatch sequence-dispatch]]
  REPLACE [[byte-dispatch]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone reaches node kind sequence-dispatch -- expected a true value]])

# counted-consume is pinned on its TOTALITY node row, not its counter: the
# counted-consume counter is fragile -- removing sequence-dispatch OR clear-mask
# from a draw table shifts the free draw and incidentally zeros it, so a counter
# pin here would also be satisfied by those two mutants (measured). The totality
# row's member-specific got-list is unique to this removal. sequence-dispatch's
# own counter is NOT fragile this way (measured 0 off-diagonal), so it keeps its
# counter pin above.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the counted-consume node kind is dropped from the draw table"
  FIND [[span-end counted-consume]]
  REPLACE [[span-end]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the node-kind draw table covers exactly ir.sls.s node. kinds -- expected .byte-dispatch callback error field-action field-branch finish integer-accumulate keyword-table pause sequence-dispatch span-end span-start stop., got .byte-dispatch callback counted-consume error field-action field-branch finish integer-accumulate keyword-table pause sequence-dispatch span-end span-start stop.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: the callback script never answers pause"
  FIND [[((1) 'pause)]]
  REPLACE [[((1) 'continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes callback outcome pause -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: the callback script never answers a declared branch key"
  FIND [[((2) (if (pair? keys) (car keys) 'continue))]]
  REPLACE [[((2) 'continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes callback outcome declared-branch-key -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: the callback script never answers an explicit failure"
  FIND [[(else (cons 'boom #f))]]
  REPLACE [[(else 'continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone observes callback outcome explicit-failure -- expected a true value]])

# The counter set is a FIXED literal list in the driver, decoupled from the
# generator's draw tables, so removing a matcher/operation/predicate from a draw
# table leaves its counter CHECK standing to read zero (caught by comparison).
# The matcher coverage dispatch covmd and the coverage accumulate covacc make
# these robust -- the removal zeros ONLY the intended counter without the free
# draw shifting a different one. Members whose removal HOLDS the floor are pinned
# on their COUNTER label here (byte-range/byte-complement/store/equal). A member
# whose removal DROPS the floor cannot use a counter label -- the floor fails
# first and the counter case is skipped -- so it is pinned on the TOTALITY row
# below, whose source-vs-table comparison catches any draw-table member removal
# INDEPENDENT of the floor. The acceptance count moves whenever the generator
# does, so the totality-row members (exact-byte, byte-set, integer-accumulate,
# mask-none) are pinned there whichever side of the floor they land on.
# clear-mask holds the floor but its removal incidentally zeros the
# counted-consume counter (a draw-shift fragility), so it too is pinned on a
# totality row -- and counted-consume itself is pinned on its totality node row
# above for the same reason, so no counter pin is left for the clear-mask (or
# sequence-dispatch) fragility to collide with. Each totality pin's regex
# carries the member-specific got-list, so it matches only its own removal.

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the byte-range matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(exact-byte byte-set byte-complement)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone matches matcher byte-range -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the byte-complement matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(exact-byte byte-set byte-range)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone matches matcher byte-complement -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the store field operation is dropped from the draw table"
  FIND [['(store clear increment decrement add set-mask clear-mask)]]
  REPLACE [['(clear increment decrement add set-mask clear-mask)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone runs field operation store -- expected a true value]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the equal field predicate is dropped from the draw table"
  FIND [['(equal zero nonzero range mask-any mask-all mask-none)]]
  REPLACE [['(zero nonzero range mask-any mask-all mask-none)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the interpreter alone evaluates field predicate equal -- expected a true value]])

# The floor-dropping / fragile removals, pinned on the TOTALITY rows. The row's
# set-equal fails source-vs-table on the removed member; the got-list (sorted
# by the row) names which member is gone, so each pin matches only its own
# removal. `.` stands in for parens and for the `?` in `node?`; no `.*`.

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the exact-byte matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(byte-set byte-range byte-complement)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the matcher draw table covers exactly ir.sls.s matcher kinds -- expected .byte-complement byte-range byte-set., got .byte-complement byte-range byte-set exact-byte.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the byte-set matcher kind is dropped from the draw table"
  FIND [['(exact-byte byte-set byte-range byte-complement)]]
  REPLACE [['(exact-byte byte-range byte-complement)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the matcher draw table covers exactly ir.sls.s matcher kinds -- expected .byte-complement byte-range exact-byte., got .byte-complement byte-range byte-set exact-byte.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the integer-accumulate node kind is dropped from the draw table"
  FIND [[field-branch integer-accumulate callback]]
  REPLACE [[field-branch callback]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the node-kind draw table covers exactly ir.sls.s node. kinds -- expected .byte-dispatch callback counted-consume error field-action field-branch finish keyword-table pause sequence-dispatch span-end span-start stop., got .byte-dispatch callback counted-consume error field-action field-branch finish integer-accumulate keyword-table pause sequence-dispatch span-end span-start stop.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the mask-none field predicate is dropped from the draw table"
  FIND [['(equal zero nonzero range mask-any mask-all mask-none)]]
  REPLACE [['(equal zero nonzero range mask-any mask-all)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the field-predicate draw table covers exactly ir.sls.s field-predicates -- expected .equal mask-all mask-any nonzero range zero., got .equal mask-all mask-any mask-none nonzero range zero.]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the clear-mask field operation is dropped from the draw table"
  FIND [['(store clear increment decrement add set-mask clear-mask)]]
  REPLACE [['(store clear increment decrement add set-mask)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the field-operation draw table covers exactly ir.sls.s field-operations -- expected .add clear decrement increment set-mask store., got .add clear clear-mask decrement increment set-mask store.]])

# One callback-kind removal, so the callback-kind totality row is exercised too
# (the node/matcher/operation/predicate totality rows each already have a removal
# pin; without this the callback-kind row would be the only draw-table totality row
# no mutation proves load-bearing). Holds the floor; caught by the row's set-equal.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-gen.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "machine-gen: the event callback kind is dropped from the draw table"
  FIND [['(event decision span-data span-complete)]]
  REPLACE [['(decision span-data span-complete)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the callback-kind draw table covers exactly make-callback-declaration.s kinds -- expected .decision span-complete span-data., got .decision event span-complete span-data.]])

# The six Layer-3 invariant pins. Each inverts one
# row's comparison in check-invariants; the row then reports a violation on the
# drawn machines, folded into the driver's inv-verdict and asserted by the SINGLE
# lane check "no accepted machine's trial violated a Layer-3 invariant". That check
# is a check-equal, so its FAIL detail carries the verdict -- (invariant IDX (rowN
# ...)) -- and each pin's regex names its own row, matching exactly that one record
# (a second, undiscriminating record -- the fixture "layers" case's boolean check --
# also reddens; the pin does not match it). Rows read the tuple independently and
# hold on every drawn trial, so inverting one reddens exactly itself. `.` stands in
# for each paren, the suite's convention; no `.*` between `expected` and `got`.
# Row 6 is the exception: see its own comment.

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 1 (the lifecycle x operation table) inverted"
  FIND [[(if (eq? st life) #f]]
  REPLACE [[(if (not (eq? st life)) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row1]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 2 (the feed cursor arithmetic) inverted"
  FIND [[(if (= cn (- nx (step-start s))) #f]]
  REPLACE [[(if (not (= cn (- nx (step-start s)))) #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row2]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 3 (sticky feeds consume nothing) inverted"
  FIND [[(= (tup-consumed t) 0)]]
  REPLACE [[(not (= (tup-consumed t) 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row3]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 4 (fields stay in [0, 2^width)) inverted"
  FIND [[(or (< x 0) (>= x (expt 2 w)))]]
  REPLACE [[(not (or (< x 0) (>= x (expt 2 w))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row4]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 5 (finished from a feed only if already finished) inverted"
  FIND [[(and (eq? (step-op s) 'feed) (not (eq? (step-life s) 'finished)))]]
  REPLACE [[(not (and (eq? (step-op s) 'feed) (not (eq? (step-life s) 'finished))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no accepted machine's trial violated a Layer-3 invariant -- expected none, got .invariant [0-9]+ .row5]])

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "property-driver: Layer-3 row 6 (the span end anchor) inverted"
  # At this seed no ACCEPTED machine reaches a completing span, so the
  # accepted-machine invariant check the other rows use does not witness row 6.
  # The FIXED fixture always does, so this row pins the deterministic
  # fixture-schedule check, which names the violated row (expected none, got
  # (row6 ...)) rather than reporting a bare boolean.
  FIND [[(not (= (cadr (last-elt frags)) coff))]]
  REPLACE [[(= (cadr (last-elt frags)) coff)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[check-invariants holds on every fixture schedule -- expected none, got .row6 span-end-anchor]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.property.differential.chez.source
  LABEL "runtime: span-close does not reset the delivered flag"
  # The delivered flag is reset only in
  # byte-machine-span-close/v1, so a prior span's "has delivered" state cannot leak
  # into the next span opened on the same parser. This is the only lane whose one
  # machine runs TWO spans in sequence: the coverage machine's covx (a nonempty
  # span -- flag set) then covy (an EMPTY span). Dropping the reset leaves covy's
  # flag stale #t, so covy is suppressed and the empty-fragment counter reads zero.
  FIND [[    (parser-set-span-delivered?! parser #f)]]
  REPLACE [[    #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "at least one agreed trial observes span event empty-fragment -- expected a true value")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 40: member-2 drift guard ----------------------------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/reserved-drift-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.reserved-drift.chez.source
  LABEL "compile: reserved-member-2 drops a runtime export (silent drift)"
  FIND [[make-parser parser? parser-feed!]]
  REPLACE [[make-parser parser?]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no drift between reserved-member-2")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 41: the interpreter's pause kind and pause-target message -------------
#
# pause-interpret-tests.sps drives the shared pause-machine (byte-machine test
# pause-machine) end-to-end through the interpreter's pause arms and the
# runtime's paused-feed/paused-finish/finish-ready lifecycle. This pass proves
# that coverage is not vacuous. The first mutation makes a pause node report
# kind 'stop instead of 'pause, and the feed-pause case's own "paused" check
# (byte 1 pausing) fails first. The
# second mutation makes pause-target resolve to the pause node's own name
# instead of its continuation, so `current` never advances past the pause and
# the resumed feed re-enters the same pause
# node instead of consuming byte 2; the same case's "stopped" check (byte 2
# stopping after resume) fails. Both signatures are the exact case-name tail
# ("byte 2 stops") plus the one check label each mutation breaks first, unique
# in this program's own check vocabulary -- neither collides with the other
# mutation's own pin, a group name, or a `-- <detail>` tail. Verify command
# uses both library roots, an empty object guard, the pause-interpret program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/pause-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.pause-interpret.chez.source
  LABEL "interpret: a pause node has its own kind"
  FIND [[((pause-node? n) 'pause)]]
  REPLACE [[((pause-node? n) 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "byte 2 stops: paused")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.pause-interpret.chez.source
  LABEL "interpret: pause-target resolves the continuation, not the pause itself"
  FIND [[((pause-target) (pause-node-continuation (lookup nodes (car args))))]]
  REPLACE [[((pause-target) (car args))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "byte 2 stops: stopped")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 42: matcher canonicalization, the tag-guarded accessors, the
# class-matcher constructors and ascii-bytes --------------------------------------
#
# ir-tests.sps reaches (byte-machine private ir)'s canonicalization spine
# directly; every other pass reaches ir.sls only through a consumer. The first
# mutation swaps the exact-byte arm's returned byte for a constant 0, so an
# exact matcher canonicalizes to the wrong one-element set instead of its own
# byte; the second removes the accessor's tag guard, so a foreign vector reads
# slot 1 and returns instead of raising -- a defect that must not be allowed
# to reach pass-overlap or list-sort. Verify command uses both library roots,
# an empty object guard, the ir program.
#
# FIND is matched as a literal substring (MutationRunner.cmake), not a regex
# and not whitespace-insensitive; it is written without leading whitespace,
# which is what tolerates indentation drift in the matched line. SITES
# defaults to 1 and is asserted exactly.
#
# The rest of the pass exercises the same canonicalization spine: the
# byte-set and byte-range constructors' degenerate-shape guards, ascii-bytes'
# non-ASCII guard, matcher-bytes' byte-set-canonical, complement and else
# arms, the tag guards on the four class-matcher accessors, and the
# ascending-order half of canonicalization. See each mutation's own comment
# for what it measures. The accessors share one check label and case-name
# tail, so their pins carry the case's full name or its own measured "got"
# rather than the bare check label; a pin sweep
# (byte_machine_mutation_verdict, every pin against every other mutant's
# captured output) finds no colliding pair in the pass.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/ir-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an exact-byte matcher does not canonicalize to its own byte"
  FIND [[(list (exact-byte-matcher-byte m))]]
  REPLACE [[(list 0)]]
  # Comparison-caught, not raise-based: the exact-byte arm still runs, so
  # matcher-bytes returns a set instead of raising, and check-equal's "set"
  # comparison is what catches the wrong byte. Measured: this also leaves
  # "canonicalizing a foreign vector is a contract violation" passing under
  # the mutant, since that case's else branch is untouched -- a raise-based
  # mutation routing every case through the same else would make that third
  # case pass for the wrong reason.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one-element set: set -- expected \\(7\\), got \\(0\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the exact-byte accessor reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'exact-byte-matcher-byte 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  # Bare "refuses a foreign vector: refused" cross-matches the four tag-guard
  # mutations below, since every accessor in that guard class shares the same
  # check label and case-name tail. Measured (byte_machine_mutation_verdict
  # against every other Pass 42 mutant's captured output): the full case name
  # is unique in the pass.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the exact-byte accessor refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an empty byte set is accepted"
  # make-sequence-case's own empty-list guard is byte-for-byte the same shape
  # as this one, so the bare `(unless (and (list? bytes) (pair? bytes)` FIND
  # is not unique in this file (SITES=1, asserted exactly). Anchored to the
  # preceding `define` line, which the sequence-case constructor's does not
  # share.
  FIND [[(define (make-byte-set-matcher bytes)
    (unless (and (list? bytes) (pair? bytes)]]
  REPLACE [[(define (make-byte-set-matcher bytes)
    (unless (and (list? bytes)]]
  # Comparison-caught via check-raises' own expected-vs-actual assertion, not
  # an incidental raise: dropping (pair? bytes) lets '() satisfy the rest of
  # the guard (for-all over '() is vacuously true), so construction succeeds
  # and check-raises reports "expected a raise, but the thunk returned ...".
  # Measured: this mutant also fails the ascii-bytes empty-
  # string case ("and cannot become a byte set"), since that check-raises
  # reaches the same guard; the pin below is the first FAIL line only.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an empty byte set is rejected: empty set")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a reversed byte range is accepted"
  FIND [[(unless (<= low high)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "low greater than high is rejected: reversed")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: ascii-bytes admits a non-ASCII character"
  FIND [[(unless (<= 0 c 127)]]
  REPLACE [[(unless #t]]
  # The case name is lowercase ("a non-ASCII character is rejected").
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "a non-ASCII character is rejected: non-ascii")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a byte set is canonicalized without de-duplication"
  FIND [[((and (pair? acc) (= (car s) (car acc))) (loop (cdr s) acc))]]
  REPLACE [[((and (pair? acc) (< (car s) (car acc))) (loop (cdr s) acc))]]
  # A bare case+check pin would also match the ordering mutation below, which
  # breaks the same check ("ascending and de-duplicated: set") with a
  # different measured "got". Each of the two sibling mutations carries its
  # own measured "got" tuple, the same trade the one-byte-fingerprint pins
  # make.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "ascending and de-duplicated: set -- expected \\(0 1 2 254 255\\), got \\(0 1 1 2 254 255\\)")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a complement is not the universe minus the inner set"
  FIND [[((memv b inner) (loop (- b 1) acc))]]
  REPLACE [[((memv b inner) (loop (- b 1) (cons b acc)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "minus the inner set: count")

# --- The four tag-guarded class-matcher accessors, the ascending-order half
# of canonicalization, and matcher-bytes' else arm ---------------------------
#
# The first four are one instance per class-matcher accessor of the same tag-
# guard defect Pass 42's second mutation already proves for
# exact-byte-matcher-byte: dropping the tag check lets the accessor read
# whatever slot N of a foreign vector without raising. Four mutations, not
# one, because each guard sits at its own source line -- deleting
# byte-range-matcher-low's `unless` does not touch byte-range-matcher-high's,
# so a single representative mutation would leave three of the four
# unwitnessed. Each is caught by check-raises' own
# expected-vs-actual assertion (comparison-caught, not raise-based): the
# guard's replacement is `#f`, not a raise, so execution falls through to the
# bare vector-ref and the thunk returns instead of raising.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-set-matcher-bytes reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-set-matcher-bytes 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-set-matcher-bytes refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-range-matcher-low reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-range-matcher-low 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-range-matcher-low refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-range-matcher-high reads slot 2 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-range-matcher-high 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-range-matcher-high refuses a foreign vector: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: byte-complement-matcher-matcher reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'byte-complement-matcher-matcher
                                       'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "byte-complement-matcher-matcher refuses a foreign vector: refused")

# The ordering half of canonicalization: the de-duplication mutation above
# proves the `=` comparison in byte-set-canonical's loop is load-bearing, and
# this one proves `list-sort` itself is. Dropping it leaves
# input-order bytes with no adjacent duplicates untouched by the loop, so the
# result comes back in the caller's order instead of ascending --
# comparison-caught by the same check the de-duplication mutation uses,
# distinguished from it by its own measured "got" (see that mutation's pin
# comment above).
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a byte set canonicalizes without ascending order"
  FIND [[(list-sort < bs)]]
  REPLACE [[bs]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "ascending and de-duplicated: set -- expected \\(0 1 2 254 255\\), got \\(254 1 0 1 255 2\\)")

# matcher-bytes' contract-violation else arm: REPLACE returns the empty list
# instead of raising, witnessed by the existing "canonicalizing a foreign vector
# is a contract violation" case. Comparison-caught via check-raises' own
# expected-vs-actual assertion.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: matcher-bytes canonicalizes a foreign vector instead of raising"
  FIND [[(byte-machine-contract-violation 'matcher-bytes
                                                 'invalid-argument 'matcher)]]
  REPLACE [['()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a contract violation: refused -- expected a raise, but the thunk returned \\(\\)")

# The sequence node kind and its cases, on this same Pass 42 -- ir-tests.sps
# reaches ir.sls's own constructors directly, and these mutations exercise the
# same file. Every EXPECT_OUTPUT_MATCHES is measured, not predicted.
#
# make-sequence-dispatch-node's three guards -- empty cases, a non-edge?
# mismatch, a bad eof-target -- each have a mutation proving their
# check-raises cases are non-vacuous. All three are comparison-caught via
# check-raises' own expected-vs-actual assertion, none raise-based.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a sequence node"
  FIND [[(or (byte-dispatch-node? x) (sequence-dispatch-node? x)
        (keyword-table-node? x) (stop-node? x)]]
  REPLACE [[(or (byte-dispatch-node? x)
        (keyword-table-node? x) (stop-node? x)]]
  # Comparison-caught: with the disjunct removed, node? is false for a
  # sequence node (which would also make make-machine reject it outright),
  # and the case's own `check "node?"` reports "expected a true value".
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a sequence node is a node, and reports its own name: node\\?")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not report a sequence node's name"
  FIND [[((sequence-dispatch-node? x) (sequence-dispatch-node-name x))]]
  REPLACE [[((sequence-dispatch-node? x) 'wrong-name)]]
  # Comparison-caught, not raise-based: the clause still returns a value
  # (the opposite-constant form AGENTS.md prefers over one that falls through
  # to the else arm's raise), so check-equal reports the wrong symbol instead
  # of the call failing to return at all.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a sequence node is a node, and reports its own name: node-name -- expected seq, got wrong-name")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-case accepts an empty byte list"
  # Anchored to the preceding `define` line: make-byte-set-matcher's own
  # empty-list guard (mutated above, in this same pass) is byte-for-byte the
  # same shape, so the bare `(unless (and (list? bytes) (pair? bytes)` text
  # is not unique in this file on its own (SITES=1, asserted exactly).
  FIND [[  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes) (pair? bytes)]]
  REPLACE [[  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes)]]
  # Comparison-caught via check-raises' own expected-vs-actual assertion:
  # dropping (pair? bytes) lets '() satisfy the rest of the guard (for-all
  # over '() is vacuously true), so construction succeeds and check-raises
  # reports the thunk returned instead of raising.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an empty sequence is rejected: empty")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: sequence-case-bytes returns the stored chain rather than a copy"
  FIND [[(append (vector-ref c 1) '())]]
  REPLACE [[(vector-ref c 1)]]
  # Comparison-caught: without the copy, two calls return the SAME pair
  # chain, so `(not (eq? ...))` is false and the case's own "not eq" check
  # reports "expected a true value".
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the bytes accessor returns a copy, not the stored chain: not eq")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-dispatch-node accepts an empty case list"
  FIND [[(unless (and (list? cases) (pair? cases) (for-all sequence-case? cases))]]
  REPLACE [[(unless (and (list? cases) (for-all sequence-case? cases))]]
  # Comparison-caught via check-raises' own expected-vs-actual assertion:
  # dropping (pair? cases) lets '() satisfy the rest of the guard (for-all
  # over '() is vacuously true), so construction succeeds and check-raises
  # reports the thunk returned instead of raising. FIND is unique on its own:
  # byte-dispatch-node's own cases guard has no (pair? cases) conjunct at all
  # (an empty case list is legal there -- the fallback alone can dispatch).
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an empty case list is rejected: no cases")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-dispatch-node accepts a non-edge mismatch"
  FIND [[(unless (edge? mismatch)]]
  REPLACE [[(unless #t]]
  # Comparison-caught: the guard's test is forced true, so a bare target
  # handed in as the mismatch edge is accepted and stored verbatim; the
  # thunk returns instead of raising.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a bare target handed in as the mismatch edge is rejected: not an edge")

# The uint field descriptor. Three decisions --
# the closed width set, the initial's range, and the machine guard that makes
# the descriptor load-bearing at all.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the uint field width set is not closed"
  FIND [[    (unless (memq width '(8 16 32 64))]]
  REPLACE [[    (unless #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the width set is closed at 8, 16, 32 and 64: refused")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a uint field initial is not range-checked against its width"
  # Comparison-caught on the upper bound, which is what the declaration-time
  # range check turns on: 2^w is accepted where it must be refused.
  FIND [[                 (<= 0 initial (- (expt 2 width) 1)))]]
  REPLACE [[                 (<= 0 initial (expt 2 width)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the initial is an exact integer inside the declared width: over the top")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the uint field settable? flag is not boolean-checked"
  # Forcing the guard true lets a non-boolean settable? through, so a settable
  # field could carry junk the verifier and both lanes then read as truthy.
  FIND [[       (unless (boolean? settable?)]]
  REPLACE [[       (unless #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the optional settable. flag must be a boolean: non-boolean -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-machine accepts fields that are not field descriptors"
  # Without this guard the collection loop checks only list?, so any proper list
  # passes -- a machine could carry (junk 42 "string") as its fields and
  # nothing would read it. This is the mutation
  # that says the descriptor is load-bearing rather than decorative.
  FIND [[    (unless (for-all uint-field? fields)]]
  REPLACE [[    (unless #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and refuses a list of anything else: junk fields")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: make-sequence-dispatch-node accepts a malformed eof-target"
  # The bare guard condition `(unless (or (symbol? eof-target) (eq? eof-target
  # #f))` is byte-identical to byte-dispatch-node's own eof-target guard;
  # FIND includes the following contract-violation line, which names
  # make-sequence-dispatch-node and is not shared, to stay unique (SITES=1,
  # asserted exactly).
  FIND [[    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'eof-target))]]
  REPLACE [[    (unless #t
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'eof-target))]]
  # Comparison-caught: the guard's test is forced true, so a non-symbol,
  # non-#f eof-target is accepted and stored verbatim; the thunk returns
  # instead of raising. Its harness case sits beside "an eof-target of #f is
  # legal", the guard's accepting half.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a non-symbol, non-#f eof-target is rejected: bad eof-target")

# Seven mutations for the two zero-width node kinds (field action and field
# branch). They are of the CONSTRUCTOR half of the constructor/verifier
# boundary only -- arity, declared-field references, operand range and
# `low <= high` are pass-field-operands', mutated in Pass 33.
#
# No mutation pins `graph.sls`'s two export lists: the facade is two export
# lists with no decision of its own. Measured: dropping either list's names
# fails at EXPAND time with exit 255 -- an unbound identifier for the export
# list, "missing definition for multiple exports" for the import list -- and
# graph-tests.sps's own case cannot load at all. That is a louder witness than
# a pin, and pinning it would cost a whole new pass (there is no graph-tests
# verify command in this suite) for two decisions already fatal.

# Seven mutations for the integer-accumulate node, the only INPUT-READING
# field kind.
#
# The constructor/verifier boundary: the constructor stays out of a field
# action's `arguments` because that is a LIST whose length it may not assume,
# but this kind has no `arguments` -- its operands are NAMED PARAMETERS, which
# a constructor can close. So `base` is closed here and gets a mutation; the
# FIELD REFERENCE is the verifier's and gets one too, in the restrictive
# direction, because closing it here would be the boundary error.

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the accumulate base set admits an unsupported base"
  # The base check, discharged at construction rather than as a diagnostic: a
  # base is evaluable from the one node being built, so a verifier arm would be
  # a second rejection site -- dead code whose permissive mutation survives.
  FIND [[  (define accumulate-bases '(10 16))]]
  REPLACE [[  (define accumulate-bases '(10 16 8))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.both bases are accepted and nothing else is: base 8 -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an accumulate node's nondigit fallback need not be an edge"
  # It is an EDGE, not a bare target, because a non-digit takes an explicit
  # fallback edge, normally reexecuting the delimiter -- the MODE is the whole
  # point and a bare symbol cannot carry one.
  FIND [[    (unless (edge? nondigit-edge)
]]
  REPLACE [[    (unless #t
]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the nondigit edge must be an edge: a bare symbol -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an accumulate node's overflow-error may be absent"
  # Never #f, unlike a field action's `error`: accumulation can ALWAYS overflow,
  # so there is nothing for the can-it-fail rule to decide and the explicit
  # error edge is unconditional.
  FIND [[    (require-symbol 'make-integer-accumulate-node 'overflow-error overflow-error)
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the overflow-error is a mandatory symbol: absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an accumulate node's eof-target is unchecked"
  # Symbol or #f, the byte-dispatch convention, where #f means the
  # machine default-eof error.
  FIND [[    (unless (or (eq? eof-target #f) (symbol? eof-target))
]]
  REPLACE [[    (unless #t
]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the eof-target is a symbol or #f: a number -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit an integer-accumulate node"
  # The two census sites every new kind must join. One mutation per site, so a
  # half-taught pair cannot pass.
  FIND [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.it is a node and answers node-name: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for an integer-accumulate node"
  FIND [[          ((integer-accumulate-node? x) (integer-accumulate-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.it is a node and answers node-name: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the constructor closes the field REFERENCE, which is the verifier's"
  # The RESTRICTIVE direction, and the boundary itself. Closing the field
  # reference here would need the declaration list, which one node cannot see --
  # this mutant fakes it with a fixed set, and the case that catches it is the
  # one asserting an undeclared name still BUILDS.
  FIND [[    (require-symbol 'make-integer-accumulate-node 'field field)]]
  REPLACE [[    (unless (memq field '(count)) (byte-machine-contract-violation 'make-integer-accumulate-node 'invalid-argument 'field))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "integer-accumulate nodes.the field reference is NOT checked here: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the field operation set admits a name outside the closed enumeration"
  # The constructor rejects arbitrary operation names -- a check the verifier
  # does not carry, because a closed set is evaluable from the node alone.
  FIND [[  (define field-operations '(store clear increment decrement add set-mask clear-mask))]]
  REPLACE [[  (define field-operations '(store clear increment decrement add set-mask clear-mask multiply))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an operation outside the closed set is refused: not an operation")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the field predicate set admits a name outside the closed enumeration"
  FIND [[  (define field-predicates '(equal zero nonzero range mask-any mask-all mask-none))]]
  REPLACE [[  (define field-predicates '(equal zero nonzero range mask-any mask-all mask-none greater))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a predicate outside the closed set is refused: not a predicate")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a field action's arguments are not checked as a proper list"
  # The whole of what the constructor checks of `arguments`. The paired
  # assertion -- that a WRONG ARITY still builds -- has no mutation, by design:
  # making the constructor read the schema is the defect this line's comment
  # forbids, and a mutation that ADDS a check is not a mutation this suite can
  # express.
  FIND [[    (require-proper-list 'make-field-action-node 'arguments arguments)
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "arguments must be a proper list, and nothing more is read: improper")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the error-slot rule is inverted"
  # The error-slot rule: `error` is #f EXACTLY when the operation cannot fail.
  # Pinned on a VALID construction failing, which is the record the permissive
  # direction below cannot produce.
  FIND [[      (when (eq? safe (and (symbol? error) #t))]]
  REPLACE [[      (when (not (eq? safe (and (symbol? error) #t)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a field action carries its six parts: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the error-slot rule never fires"
  # *** SUBSUMED BY the inverted mutation above, BY CONSTRUCTION, and written
  # anyway. *** Measured in both directions: this mutant never raises, so on
  # every combination it fails to reject, the inverted one fails to reject too --
  # its record set is a strict subset, and no fixture can separate them, because
  # "never raises" is contained in "raises only on the valid combinations". The
  # conjunction below is therefore matched by the inverted mutant as well; that
  # is a collision in attribution, not in detection, and it is recorded rather
  # than papered over. The two name distinct decisions -- that the rule exists at
  # all, and that it points the right way -- so both are kept.
  FIND [[      (when (eq? safe (and (symbol? error) #t))
        (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'error))]]
  REPLACE [[      (when #f
        (byte-machine-contract-violation 'make-field-action-node 'invalid-argument 'error))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the error slot is #f exactly when the operation cannot fail: safe op with a target -- expected a raise.*failing op without one -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a field action"
  # `node?` and `node-name` are the two census sites EVERY new kind must join,
  # and missing either is silent at construction and loud much later. One
  # mutation per site, per kind, so a half-taught pair cannot pass. This one
  # drops the field-action disjunct.
  FIND [[        (field-action-node? x) (field-branch-node? x)
        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (field-branch-node? x)
        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  # `?` is a regex metacharacter -- unescaped, `node? --` matches "nod --",
  # which no output contains, and the runner reports a wrong-reason catch.
  EXPECT_OUTPUT_MATCHES
    "field-action nodes.it is a node and answers node-name: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for a field branch"
  FIND [[          ((field-branch-node? x) (field-branch-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "field-branch nodes.it is a node and answers node-name: case raised")

# The callback-invocation node kind. The two census sites every kind must join
# (`node?` and `node-name`), and the four local-shape decisions
# `make-callback-node` owns. Its three CROSS-references -- the callback name,
# the branch keys, and whether the declaration is a decision -- get no mutation
# here on purpose: this constructor makes none of those judgements, and the
# ir-tests case that asserts it makes none of them is the witness for that.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a callback node"
  FIND [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (integer-accumulate-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  # `?` is a regex metacharacter -- unescaped, `node? --` matches "nod --", which
  # no output contains, and the runner reports a wrong-reason catch.
  EXPECT_OUTPUT_MATCHES
    "callback-invocation nodes.it is a node and answers node-name: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for a callback node"
  # `node-name`'s cond has a RAISING else and nothing derives it, so the mutant
  # crashes rather than answering wrongly -- which is why the pin is on the
  # raise here and on the comparison in the sibling above.
  FIND [[          ((callback-node? x) (callback-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "callback-invocation nodes.it is a node and answers node-name: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's continue target may be absent"
  # A SWAP PAIR with the mutation below: each REPLACE is the other's surviving
  # line, so the two move in lockstep. Both targets are mandatory. The
  # constructor's body sits in a case-lambda clause, which sets the indent.
  FIND [[       (require-symbol 'make-callback-node 'continue-target continue-target)
       (require-symbol 'make-callback-node 'pause-continuation pause-continuation)]]
  REPLACE [[       (require-symbol 'make-callback-node 'pause-continuation pause-continuation)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "mandatory symbols: continue-target absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's pause continuation may be absent"
  FIND [[       (require-symbol 'make-callback-node 'continue-target continue-target)
       (require-symbol 'make-callback-node 'pause-continuation pause-continuation)]]
  REPLACE [[       (require-symbol 'make-callback-node 'continue-target continue-target)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "mandatory symbols: pause-continuation absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's branch entries need not be two-element lists"
  # Branch entries are two-element lists, not pairs. Narrowed to `list?`
  # alone, the pair form and the three-element form both build.
  FIND [[                               (and (list? b) (= (length b) 2)
                                    (symbol? (car b)) (symbol? (cadr b))))]]
  REPLACE [[                               (list? b))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "branch targets are two-element lists, not pairs: a three-element list -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a callback node's branch list is stored rather than copied"
  # The node is immutable through its API, on the make-sequence-case
  # precedent. Witnessed by identity, so the mutant is observationally
  # different even though every stored VALUE is equal.
  FIND [[            (map (lambda (b) (list (car b) (cadr b))) branch-targets)]]
  REPLACE [[            branch-targets]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the branch list is copied at construction: a fresh spine -- expected a true value")

# The span-start and span-end node kinds. `node?` and
# `node-name` are the two census sites every kind must join; the mandatory `next`
# is the only local-shape decision either constructor owns.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a span-start node"
  FIND [[        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (span-end-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and each carries all four parts -- expected .., got .span-start.")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a span-end node"
  FIND [[        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (span-start-node? x) (counted-consume-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and each carries all four parts -- expected .., got .span-end.")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name answers for neither span kind"
  # BOTH arms in one mutation, and the reason is recorded rather than left to a
  # reader: `node-name`'s else RAISES, so dropping either arm alone stops the
  # table-driven case at the same point with the same record. Two mutations
  # would be indistinguishable; the pair is one decision -- the kinds joined the
  # cond -- and it gets one mutation.
  FIND [[          ((span-start-node? x) (span-start-node-name x))
          ((span-end-node? x) (span-end-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span nodes.each carries its four parts and is a node: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a span-start node's next may be absent"
  # The kind has no route of its own, so there is no #f arm to
  # defend. Its sibling below is the same decision for the other kind, and they
  # are separable because the case names the kind that failed.
  FIND [[    (require-symbol 'make-span-start-node 'next next)]]
  REPLACE [[    (require-symbol 'make-span-start-node 'span span)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "start next -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a span-end node's next may be absent"
  FIND [[    (require-symbol 'make-span-end-node 'next next)]]
  REPLACE [[    (require-symbol 'make-span-end-node 'span span)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "end next -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the two span kinds share one tag"
  # The defect a table driven by predicates cannot see: if both builders make
  # the same thing and both predicates answer for it, every part-by-part row
  # passes. Only the distinguishability case notices.
  FIND [[  (define span-end-node-tag (tag 'byte-machine-span-end-node))]]
  REPLACE [[  (define span-end-node-tag span-start-node-tag)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the two kinds are distinguishable")

# `node-source-label`'s arm for one kind answers ABSENCE. Caught by comparison
# in the every-kind case (and again by the verifier lane's stop row, under
# another SPEC). No mutation swaps an arm for a same-slot sibling's accessor:
# `stop` and `finish` both store the label at slot 2 and every
# `-source-label` accessor is an unguarded `vector-ref`, so that mutant is
# observationally identical and would be UNCAUGHT. The arm-DELETION mutant is
# the census pass's, where the derived S2b row is what sees it.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-source-label answers #f for a stop node"
  FIND [[((stop-node? x) (stop-node-source-label x))]]
  REPLACE [[((stop-node? x) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each answers its own label -- expected .., got .stop.")


# --- The counted-consume kind's constructor and dispatch ----------------------
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a counted-consume node's next may be absent"
  FIND [[    (require-symbol 'make-counted-consume-node 'next next)
]]
  REPLACE [[    ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "fourteenth constructor refusal: absent -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a counted-consume node's eof-target is unchecked"
  # The `or` is written in the byte-dispatch operand order on purpose: the
  # accumulate constructor's order is pinned at one site and a verbatim copy
  # would take that FIND to two. This FIND is unique through its second line,
  # which names this constructor.
  FIND [[    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-counted-consume-node]]
  REPLACE [[    (unless #t
      (byte-machine-contract-violation 'make-counted-consume-node]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "meaning the machine default: a number -- expected a raise")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node? does not admit a counted-consume node"
  FIND [[        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (span-start-node? x) (span-end-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "counted-consume nodes.it is a node and answers node-name and node-source-label: node\\? -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-name does not answer for a counted-consume node"
  # `node-name`'s cond has a RAISING else, so the mutant crashes rather than
  # answering wrongly; the pin is on the raise, as for every sibling arm.
  FIND [[          ((counted-consume-node? x) (counted-consume-node-name x))
]]
  REPLACE [[          ]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "counted-consume nodes.it is a node and answers node-name and node-source-label: case raised")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: node-source-label answers #f for a counted-consume node"
  # Also satisfied by "ir: node? does not admit a
  # counted-consume node" -- node-builders' one check conjoins node? with the
  # label answer, so a kind node? refuses fails it the same way. By construction.
  FIND [[((counted-consume-node? x) (counted-consume-node-source-label x))]]
  REPLACE [[((counted-consume-node? x) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "each answers its own label -- expected .., got .counted-consume.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# No mutation pins graph.sls's export list against its mirrored `only` import
# list, deliberately.
#
# The decision is that the two lists move together. A mutation dropping a name
# from one of them exits 255 under this suite's launcher with no harness output
# at all, because a missing export is an expand-time failure -- the library never
# loads, so no case runs and there is nothing to match. That is the bare
# nonzero-exit catch AGENTS.md forbids, wearing no signature.
#
# What actually guards the decision is stronger than a mutation: an identifier
# in one list and not the other makes (byte-machine graph) unloadable, so EVERY
# lane importing it fails at once, loudly, at build time. There is no input that
# reaches a half-edited façade and survives.
#
# (Run OUTSIDE the launcher the same mutant surfaces as a harness case raise
# with status 1, because the reference is inside a lambda. Pinning that would
# record a signature this suite never produces.)


# --- Pass 43: class membership and recursive canonicalization ---------------
#
# byte-class-interpret-tests.sps drives five class fixtures over all 256 bytes
# with ABSOLUTE expected outcomes. Two decisions here are unreachable from the
# preceding lanes, because each of their fixtures' matchers is a one-element set:
# `memv` over the whole canonical set (for a singleton, `memv` and `= (car ...)`
# agree, so Pass 34's one-byte machine cannot separate them), and the recursion
# through a nested complement. The first mutation matches only a class's lowest
# byte; the second stops complement canonicalization recursing, so a
# complement-of-a-complement is read as its own inner matcher. Verify command
# uses both library roots, an empty object guard, the byte-class program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/byte-class-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.byte-class.chez.source
  LABEL "interpret: class membership matches only the class's lowest byte"
  FIND [[((memv byte (matcher-bytes (byte-case-matcher (car cs))))]]
  REPLACE [[((= byte (car (matcher-bytes (byte-case-matcher (car cs)))))]]
  # `hits` is a behavioural count (observed stopped/consumed = 1), not
  # membership in the test's own precomputed `accepted` list, so "accepted
  # exactly the class size" reddens: with only the class's lowest canonical
  # byte still matching the dispatch case, exactly one byte ever stops, so
  # `hits` collapses to 1 for every fixture while the class size it is
  # compared against (5, 26, 254, 10, 3) differs per fixture. Pinned to this
  # check, not "no byte misbehaved" (which also reddens here), so this pass
  # demonstrates the sentinel is the one doing the catching.
  # Measured FAIL line: "FAIL all 256 byte values, per class.byte-set accepts
  # exactly its class: accepted exactly the class size -- expected 5, got 1".
  # Each fixture's "expected N" is unique across the whole run, so the bare
  # detail alone would already resolve to one (case, check) pair, but the
  # case-name prefix is kept for robustness against a future fixture whose
  # class size happens to coincide.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "byte-set accepts exactly its class: accepted exactly the class size -- expected 5, got 1")

# The REPLACE below canonicalizes a complement's inner matcher normally UNLESS
# that inner matcher is itself a complement, in which case it reads as the empty
# set -- so a nested complement becomes the full universe while every
# single-level complement is untouched. That isolates the recursion specifically,
# and it is caught by a failed comparison rather than by a raise (AGENTS.md):
# handing `memv` a vector instead of a list would crash somewhere incidental
# rather than redden the assertion that names the decision.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.byte-class.chez.source
  LABEL "ir: complement canonicalization does not recurse"
  FIND [[(let ((inner (matcher-bytes (byte-complement-matcher-matcher m))))]]
  REPLACE [[(let ((inner (if (byte-complement-matcher? (byte-complement-matcher-matcher m)) (quote ()) (matcher-bytes (byte-complement-matcher-matcher m)))))]]
  # The case "nested-complement accepts exactly its class" carries three checks,
  # so a pin on the case name alone would be satisfied by any of the three; the
  # pin is the full measured line, naming exactly one (case, check) pair. The
  # mis-canonicalized nested complement reads as accepting the whole universe,
  # so both "no byte misbehaved" (byte 0 is the first byte that wrongly stops)
  # and "accepted exactly the class size" (hits climbs to 256) redden on this
  # same case; pinned to "no byte misbehaved" because it fires first in check
  # order and is the more direct statement of the defect -- the matcher
  # accepting bytes it must reject -- while "accepted exactly the class size" is
  # downstream arithmetic on the same wrong behaviour. No CMake-regex
  # metacharacters in the pin, so no escaping is needed.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "nested-complement accepts exactly its class: no byte misbehaved -- expected none, got 0")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 44: the byte-class differential is non-vacuous ----------------------
#
# differential-byte-class-tests.sps compares the interpreter against the emitted
# library over all 256 bytes for five class fixtures. Shifting every rendered
# transition byte by one makes the generated executor accept a class shifted one
# byte up, so the comparison diverges at the class's first byte. Verify command
# uses both library roots, an empty object guard, the differential program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-byte-class-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.byte-class.chez.source
  LABEL "compile: every rendered transition byte is shifted by one"
  FIND [[       (if (= lo hi)
           (string-append "(fx=? b " (num lo) ")")
           (string-append "(and (fx>=? b " (num lo) ") (fx<=? b " (num hi) "))"))]]
  REPLACE [[       (if (= lo hi)
           (string-append "(fx=? b " (num (+ 1 lo)) ")")
           (string-append "(and (fx>=? b " (num (+ 1 lo)) ") (fx<=? b " (num (+ 1 hi)) "))"))]]
  # Measured: byte-set is the first fixture in
  # class-machines, so it is the first case in "interpreter and generated agree
  # on every byte, for every class" to run, and its lowest class byte (0) is the
  # one whose rendered arm is shifted away from key 0 to key 1 -- so the
  # generated side stops matching it and falls through to the dispatch node's
  # own reject/reexecute default, diverging from the (unmutated) interpreter at
  # byte 0. Measured FAIL line: "byte-machine-harness: FAIL interpreter and
  # generated agree on every byte, for every class.byte-set agrees on all 256
  # bytes: no byte disagreed -- expected none, got 0". Pinned to byte-set's own
  # case name plus the check label so the pin resolves to one (case, check)
  # pair, not the five fixtures' shared case-name tail ("agrees on all 256
  # bytes: no byte disagreed"), which all five fixtures would match.
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "byte-set agrees on all 256 bytes: no byte disagreed -- expected none, got 0")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 45: the sequence-node absolute interpreter lane is non-vacuous ------
#
# sequence-interpret-tests.sps builds a fixture with mismatch mode 'advance
# (make-advance-mismatch-machine, 'advseq); the other sequence fixtures
# (sequence-machine.sls, pause-machine.sls, and interpret-tests.sps's own)
# use 'reexecute, so this lane is the witness for the advance-mode arithmetic
# (consumed=1, next=1, offset=k+1 rather than consumed=0, next=0, offset=k).
# Both mutations below hardcode seq-step's `(edge-mode mm)` read to a fixed
# symbol, so the interpreter answers with one mode's arithmetic regardless of
# what the machine actually declared; the third re-witnesses the completed-
# alternative-target decision through this lane's own single-alternative
# fixture. Verify command uses both library roots, an empty object guard, the
# absolute program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/sequence-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.sequence-node.chez.source
  LABEL "interpret: the mismatch edge's declared mode is ignored in favour of reexecute"
  # Hardcoding to 'advance leaves the REEXECUTE fixture (seqnode) wrong -- a
  # mismatching byte gets consumed and every position shifts by one -- while
  # the ADVANCE fixture (advseq) is left coincidentally correct, so only
  # seqnode's own checks can catch this. Measured: cases=10 checks=25
  # failures=5, failing seqnode's all-256 case (one check) and all four k=
  # checks in "reexecute leaves next and consumed at zero and the offset at
  # the prefix". Comparison-caught.
  # Pin sweep: this pin's exact tuple pair is the mirror image of the
  # 'reexecute mutation below's own pin (0 0 0 / 1 1 1 vs 1 1 1 / 0 0 0) and
  # absent from that mutation's captured output and from the completed-
  # alternative-target mutation's output.
  # The keyword-table walk carries a second
  # `(cons (edge-target mm) (edge-mode mm))` (its no-match edge, bound through
  # keyword-table-node-no-match), so the bare cons occurs twice. The FIND is
  # anchored on seq-step's own `sequence-dispatch-node-mismatch` binder to
  # stay unique.
  FIND [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))]]
  REPLACE [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) 'advance)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "k=0 -- expected \\(error 0 0 0 unexpected-byte\\), got \\(error 1 1 1 unexpected-byte\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.sequence-node.chez.source
  LABEL "interpret: the mismatch edge's declared mode is ignored in favour of advance"
  # The opposite hardcode: the ADVANCE fixture (advseq) is wrong and the
  # REEXECUTE fixture (seqnode) is coincidentally correct, so only advseq's own
  # checks catch it -- proving 'reexecute is genuinely read too, not merely
  # the default every machine happens to declare. Measured: cases=10
  # checks=25 failures=5, failing advseq's all-256 case and all four k=
  # checks in "advance consumes the offending byte and shifts every position
  # by one". Comparison-caught.
  # Anchored on seq-step's `sequence-dispatch-node-mismatch` binder, as the
  # sibling above is, so the FIND is unique against the keyword-table walk's
  # own no-match cons.
  FIND [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))]]
  REPLACE [[(let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) 'reexecute)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "k=0 -- expected \\(error 1 1 1 unexpected-byte\\), got \\(error 0 0 0 unexpected-byte\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.sequence-node.chez.source
  LABEL "interpret: a completed alternative routes to another prefix instead of its declared target"
  # Same defect, same FIND/REPLACE, as Pass 34's mutation of the same
  # name -- deliberately: that mutation's witness runs through
  # interpret-tests.sps's multi-alternative AB/XY trie fixtures under a
  # DIFFERENT SPEC (byte-machine.unit.interpret.chez.source); this lane's own
  # single-alternative fixture needs its own witness of the same decision
  # (AGENTS.md: a mutation's witnessing test lives in its own SPEC lane's
  # program). Folding a completed alternative into the "extend the compound"
  # shape means the four-byte sequence never terminates: the parser reports
  # need-input at stream-offset 4 instead of stopping. Measured: cases=10
  # checks=25 failures=1, only "the full sequence stops at stream-offset 4"
  # failing -- the all-256 group and the mismatch-mode group are untouched by
  # this mutation (this pin appears in neither mode mutation's captured
  # output).
  # Comparison-caught.
  FIND [[((pair? ends) (cons (sequence-case-target (car ends)) 'advance))]]
  REPLACE [[((pair? ends) (cons (cons (sequence-dispatch-node-name n) new) 'advance))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "the full sequence stops at stream-offset 4: stopped -- expected \\(stopped 1 1 4 #f\\), got \\(need-input 1 1 4 #f\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 46: the sequence-node differential is non-vacuous -----------------
#
# differential-sequence-node-tests.sps is an independent oracle: a
# single-alternative sequence node must reproduce sequence-machine.sls's four
# CHAINED DISPATCH NODES exactly, over tuples measured on the chained form.
# Both executors read the same source IR (the normalizer lowers a
# sequence-dispatch node to an ordinary trie of dispatch nodes before the
# emitter ever sees it), so agreement alone cannot
# prove the lane is worth its runtime: a divergence has to be reachable, and
# the interpreter never reads compile.sls, so the emitter is the only module a
# mutation here can touch and still make the two sides disagree. Verify
# command uses both library roots, an empty object guard, the differential
# program.
#
# The exhaustive group's case ("256 x 4 positions match, in both mismatch
# modes") asserts one (position byte) drive counter at 1024, read from what
# the loop actually drove. Measured: baseline cases=14 failed-cases=0
# checks=29 failures=0 status=0; the byte shift reports cases=14
# failed-cases=14 checks=29 failures=16 status=1, the sticky-stopped row
# cases=14 failed-cases=1 checks=29 failures=2 status=1. Pin sweep in both
# directions at 2 mutations / 2 ordered pairs (n(n-1)): zero collisions.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-sequence-node-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "compile: every rendered transition byte is shifted by one (sequence-node lane)"
  FIND [[       (if (= lo hi)
           (string-append "(fx=? b " (num lo) ")")
           (string-append "(and (fx>=? b " (num lo) ") (fx<=? b " (num hi) "))"))]]
  REPLACE [[       (if (= lo hi)
           (string-append "(fx=? b " (num (+ 1 lo)) ")")
           (string-append "(and (fx>=? b " (num (+ 1 lo)) ") (fx<=? b " (num (+ 1 hi)) "))"))]]
  # Same FIND/REPLACE as Pass 44's byte-class mutation, and (for the small
  # byte values this lane's sequence uses) functionally the same shift as
  # Pass 39's mod-256 mutation. Legitimate per AGENTS.md/SITES being
  # per-mutation: each byte_machine_mutation() call reads a pristine copy of
  # compile.sls and restores it afterward, so three passes carrying the same
  # render-transition-arm decision under three different SPEC lanes is the
  # same defect re-witnessed where each lane's own fixture can see it, not
  # three copies of one test (AGENTS.md: "a mutation's witnessing test lives
  # in its own SPEC lane's program"). The FIND occurs once in the file.
  #
  # Measured: mutant cases=14 failed-cases=14 checks=29 failures=16 status=1
  # (see the pass header). Comparison-caught throughout (check-equal
  # failures, no raise).
  #
  # Pin sweep, both directions, against every other pass that also mutates
  # compile.sls (Passes 36-40, 44). The mutant's very FIRST reported failure --
  # "the full sequence in one slice stops after four bytes in both: generated
  # -- expected (stopped 4 4 4 #f), got (error 0 0 0 unexpected-byte)" -- is
  # NOT usable as this mutation's pin: Pass 36's "advance
  # transition lowered as reexecute" mutation, run against this same program,
  # reaches the byte-identical line by a different mechanism (state 0's
  # matching transition stops advancing pos/off, so state 1 then fails to
  # match the still-unconsumed byte and lands on the same all-zero error
  # tuple). The full output of that mutation and of Pass 36's
  # "reexecute fallback lowered as advance" and "error arm omits the resolved
  # code" siblings against this program: none of the three touches the
  # dispatch CASE key this mutation shifts, so all three diverge first at byte
  # 0 ("(advance 0 0)" / "(reexecute 0 0)" / "(reexecute 0 0)" on the
  # all-256-bytes check) where this mutation diverges first at byte 1
  # ("(reexecute 0 1)", because the shift moves state 0's own accepted byte
  # from 1 to 2). Pinned to that check instead, which the sweep confirms no
  # sibling reaches. Pass 39's mod-256 mutation reproduces this pin exactly
  # when run against this program (expected: `(+ 1 b)` and
  # `(mod (+ 1 b) 256)` agree for b in 1..4, so it is the same decision, not a
  # collision -- and it is declared under a different SPEC, so it never
  # actually runs against this verify command).
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "256 x 4 positions match, in both mismatch modes: no \\(mode position byte\\) disagreed -- expected none, got \\(reexecute 0 1\\)")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "runtime: the sticky-stopped row's next is the call's start, not a fixed zero (sequence-node lane)"
  # parser-feed!'s sticky-stopped arm is shared code reached before either
  # executor variant is dispatched to, so this decision has nothing to do
  # with the emitter the mutation above targets -- it is witnessed here
  # (rather than in Pass 32, where the sibling error- and pause-arm `next`
  # mutations live) because this SPEC lane's nonzero-start case is what
  # reddens for it (AGENTS.md: a mutation's witness lives in its own SPEC
  # lane's program). The FIND occurs once in the file.
  #
  # The "a nonzero-start trailing empty feed separates next from start, zero,
  # and offset" case is the witness. "a trailing empty feed after the
  # sequence completes stays stopped" feeds from start 0, so a next
  # hardcoded to the literal 0 reads identically to the correct start there.
  # (A DIFFERENT mutation of the same arm -- swapping `start` for
  # `(parser-offset parser)` instead of a literal 0 -- is caught by that
  # start-0 case too, and separately by runtime-tests.sps's "a repeat feed on
  # a terminal parser" case: both reach the sticky arm with a nonzero
  # persisted offset even though their own slice starts at 0, so offset and
  # start disagree there. Only the plain literal-0 hardcode needs the
  # nonzero-start witness.)
  #
  # Measured: cases=14 failed-cases=1 failures=2 status=1, both failures on
  # the nonzero-start case's own two checks ("interpreter after completion"
  # and "generated after completion"), each "expected (stopped 5 0 4 #f), got
  # (stopped 0 0 4 #f)". Comparison-caught (check-equal failures, no raise).
  #
  # Pin sweep against the sibling compile.sls mutation above, both directions:
  # that mutation never fails this case's
  # "interpreter after completion" check at all (cm-ref never reads
  # compile.sls, so no compile.sls mutation in this pass can produce that
  # check's FAIL line), and its own "generated after completion" failure
  # reads "got (error 5 0 0 unexpected-byte)" -- disjoint from this
  # mutation's "got (stopped 0 0 4 #f)". Pinned to the "interpreter after
  # completion" check for exactly that reason: it is structurally immune to
  # every mutation this pass's sibling entry could ever carry.
  FIND [[(make-parser-result 'stopped start 0 (parser-offset parser) #f))]]
  REPLACE [[(make-parser-result 'stopped 0 0 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "a nonzero-start trailing empty feed separates next from start, zero, and offset: interpreter after completion -- expected \\(stopped 5 0 4 #f\\), got \\(stopped 0 0 4 #f\\)")

# `parser-state-name`. This lane is its SPEC because a lowered sequence is the
# one shape in the tree where the two lanes hold structurally different things
# at a parked position -- the compound `(seq . bytes)` and an integer id naming
# no source node.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "compile: the emitted state-name table is rendered empty"
  # ABI payload member 2. Empty, the generated lane has nothing to answer from
  # and `parser-state-name` fails on the index -- so the caught record is a
  # raise, and it is the decision's own consequence rather than an incidental
  # crash: the table's whole purpose is to be indexed by the current state.
  FIND [[           (snames (let sloop ((i 0) (acc ""))
                     (if (>= i (vector-length states)) acc]]
  REPLACE [[           (snames (let sloop ((i 0) (acc ""))
                     (if #t acc]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both lanes answer the declaring node at every prefix depth: case raised")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "interpret: parser-state-name answers the compound mid-sequence"
  # The state name is the source callback/span node, not a generated internal
  # continuation. Unwrapping the compound is the whole of this lane's half of
  # that rule, and the mutant answers `(seq 1)` where the generated lane
  # answers `seq` -- a failed COMPARISON naming both sides.
  FIND [[           ((state-name) (let ((c (car args))) (if (pair? c) (car c) c)))]]
  REPLACE [[           ((state-name) (car args))]]
  EXPECT_STATUS 1
  # The bare check label is also satisfied by "compile: every rendered
  # transition byte is shifted by one (sequence-node lane)", which fails the
  # same check with a different list. The measured got -- the compound at
  # every depth -- is this mutant's alone.
  EXPECT_OUTPUT_MATCHES
    "both lanes answer the declaring node at every prefix depth: and each names the sequence node -- expected \\(\\), got \\(\\(3 \\(seq 1 2 3\\) seq\\) \\(2 \\(seq 1 2\\) seq\\) \\(1 \\(seq 1\\) seq\\)\\)")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.sequence-node.chez.source
  LABEL "runtime: parser-state-name reads the entry rather than the current state"
  # The accessor is about WHERE THE PARSER IS. Reading the entry answers
  # correctly for a fresh parser -- which is why the bookend case checks a
  # stopped one too -- and wrongly everywhere else.
  # The v2 arm binds `current` to `c` and unwraps the keyword-table compound;
  # the mutation reads the entry instead.
  FIND [[      ((v2) (let ((c (parser-current parser)))]]
  REPLACE [[      ((v2) (let ((c (parser-entry parser)))]]
  EXPECT_STATUS 1
  # The measured got separates this pin from the same sibling as the pin
  # above, which reddens this check with `(reject error)`.
  EXPECT_OUTPUT_MATCHES
    "a fresh parser names the entry, and a finished one its terminal: stopped, both lanes -- expected \\(seq stopped\\), got \\(stop stopped\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 47: the multi-alternative absolute lane is non-vacuous --------------
#
# http-version-interpret-tests.sps drives TWO alternatives over a shared prefix
# end to end, with absolute tuples: the HTTP `version` production, whose seven
# shared bytes put the branch far enough in that the chain is fully walked
# before either alternative can be distinguished. Both mutations below truncate
# seq-step's live-alternative filter to a single case, so the interpreter
# answers as though the node had declared one alternative rather than two, and
# between them they witness the loss of either one.
#
# Why the decision needs a lane of its own rather than the single-alternative
# one Pass 45 covers: run against sequence-interpret-tests.sps (Pass 45's
# SPEC-lane program), BOTH mutants pass it unchanged --
# status=0, cases=10 failed-cases=0 checks=25 failures=0, no FAIL lines --
# because with one declared alternative the truncated list and the whole list
# are the same list (AGENTS.md: a mutation's witnessing test lives in its own
# SPEC lane's program).
#
# Stated rather than implied, because "the only lane to drive a branching
# sequence node" would be false: interpret-tests.sps, under the DIFFERENT SPEC
# byte-machine.unit.interpret.chez.source, drives AB/AC and AB/XY
# alternatives through the interpreter, and it catches both
# mutations below (measured: cases=21 checks=40, failed-cases=4 for the FIRST
# mutation, 5 for the LAST). What this lane adds is the shape rather than the
# node kind -- a seven-byte shared prefix instead of a one-byte one, asserted as
# absolute tuples rather than as bare statuses -- and the reason these are
# declared here as well is the SPEC-lane rule, which is the same relationship
# Pass 45's completed-alternative mutation documents against Pass 34. Verify
# command uses both library roots, an empty object guard, the absolute
# program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-version-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.http-version.chez.source
  LABEL "interpret: a branching prefix keeps only the FIRST declared alternative live"
  # seq-step filters the node's WHOLE case list for the alternatives still
  # matching the accumulated path. Truncating that list to its head leaves
  # `HTTP/1.0` -- the first declared alternative -- accepting, and `HTTP/1.1`
  # mismatching on its own last byte, at the branch state the shared prefix
  # ends in. The FIND occurs once in the file.
  #
  # Measured: baseline cases=12
  # failed-cases=0 checks=19 failures=0 status=0; mutant cases=12
  # failed-cases=2 checks=19 failures=2 status=1, both failures on HTTP/1.1's
  # own accept checks and nothing else. Comparison-caught (check-equal
  # failures, no raise).
  #
  # Pin sweep, both directions, against every other mutation under this pass's
  # verify command -- which is the sibling below and nothing else: 2 mutations,
  # 2 ordered pairs (n(n-1), this file's convention: ordered pairs of DISTINCT
  # mutants, so the two self-checks are not counted as pairs).
  # Every pin re-judged through byte_machine_mutation_verdict against both
  # captures. Zero collisions, and -- counted separately -- each pin
  # catches its own mutant. The two failure sets are mirror images -- this
  # mutant reports only the HTTP/1.1 cases, the sibling only the HTTP/1.0 ones
  # -- so neither pin can match the other's output.
  # Control: the sequence-interpret-tests.sps run recorded in this pass's
  # header shows the mutants surviving the sibling lane they are NOT declared
  # under.
  FIND [[                            (sequence-dispatch-node-cases n)))]]
  REPLACE [[                            (list (car (sequence-dispatch-node-cases n)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "HTTP/1\\.1 stops at the one target: one byte at a time -- expected \\(stopped 1 1 8 #f\\), got \\(error 0 0 7 unexpected-byte\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.http-version.chez.source
  LABEL "interpret: a branching prefix keeps only the LAST declared alternative live"
  # The opposite truncation, and the reason both are here: keeping only the
  # head leaves the FIRST alternative coincidentally correct, so on its own it
  # cannot show that `HTTP/1.0` is reached by being matched rather than by
  # being the one alternative the interpreter ever looks at. Keeping only the
  # tail is the mirror -- `HTTP/1.1` accepts, `HTTP/1.0` mismatches -- and the
  # pair is what pins "each alternative reaches its OWN target" to both
  # alternatives. Same FIND as the mutation above (each byte_machine_mutation()
  # call reads a pristine copy of interpret.sls and restores it afterward, so
  # sharing a FIND is a different edit, not a repeated one).
  #
  # Measured: mutant cases=12 failed-cases=2 checks=19
  # failures=2 status=1, both failures on HTTP/1.0's own accept checks.
  # Comparison-caught. Pin sweep: see the sibling above -- the same two-way
  # re-judgement covers this pin.
  FIND [[                            (sequence-dispatch-node-cases n)))]]
  REPLACE [[                            (list (car (reverse (sequence-dispatch-node-cases n))))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "HTTP/1\\.0 stops at the zero target: one byte at a time -- expected \\(stopped 1 1 8 #f\\), got \\(error 0 0 7 unexpected-byte\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 48: the multi-alternative differential is non-vacuous --------------
#
# differential-http-version-tests.sps drives the HTTP `version` production
# through BOTH executors and compares their five-field result tuples: at every
# single-cut split, over seeded multi-split schedules, and across all 256 bytes
# at all eight prefix positions in both mismatch modes. Both executors read the
# same source IR, so agreement alone cannot carry the lane -- a divergence has
# to be reachable, and only a module that exactly ONE executor reads can
# produce one: the normalizer and the emitter on the generated side,
# interpret.sls on the reference side (see interpret.sls's header). Shared
# code -- runtime.sls, verify.sls -- makes both executors wrong identically and
# leaves the comparison green. The pair below takes the generated side.
#
# The pair below truncates render-state-arm's per-state transition list to its
# FIRST arm and to its LAST. In this fixture the branch state is the only state
# with more than one arm -- the seven shared-prefix states each have exactly one
# -- so each truncation renders one alternative unreachable in the emitted
# library while the interpreter still accepts it. They are the generated-side
# twin of Pass 47's interpreter-side alternative-filter pair, and the pair is
# what pins "the emitter renders EVERY arm of a branching state" to both
# alternatives rather than to whichever one happens to be rendered.
#
# Why this lane's own SPEC, measured rather than asserted (AGENTS.md: a
# mutation's witnessing test lives in its own SPEC lane's program). Run against
# the two neighbouring lanes, both mutants leave both passing UNCHANGED --
# byte-identical summaries to those programs' own unmutated baselines:
#   differential-sequence-node-tests.sps (Pass 46's SPEC program, the
#   SINGLE-alternative differential): baseline and both mutants all report
#   cases=14 failed-cases=0 checks=29 failures=0 status=0, because with one
#   alternative every dispatch state has exactly one arm and truncating a
#   one-element list is the identity;
#   http-version-interpret-tests.sps (Pass 47's SPEC program, this same fixture
#   through the interpreter alone): baseline and both mutants all report
#   cases=12 failed-cases=0 checks=19 failures=0 status=0, because that program
#   never emits.
#
# Stated rather than implied, because "no other lane catches this" would be
# false: two lanes under DIFFERENT SPECs redden
# for both mutants, and they get their many-arm dispatch states by two
# different routes, neither of which is this lane's.
#   differential-byte-class-tests.sps (cases=13 checks=26; failed-cases=5
#   failures=5 for FIRST, failed-cases=10 failures=15 for LAST): a byte class
#   lowers to one transition per byte, so one declared class
#   renders up to 256 sibling arms.
#   property-differential-tests.sps (cases=2 failed-cases=1 checks=83
#   failures=30, both mutants): NOT byte classes -- machine-gen.sls builds no
#   class at all (`rg byte-class` over that file returns nothing). Its nodes
#   are make-byte-dispatch-node over 1 to 2 randomly drawn byte cases across all
#   four matcher kinds (machine-gen.sls's free draw and its coverage prefix),
#   so a many-arm state is whatever that draw happened to produce.
# Both routes reach a many-arm state without a shared PREFIX, and both run
# under their own SPEC, so neither can witness this pass's mutations. What is
# specific to this lane is the arm count arising from a BRANCHING PREFIX, which
# is exactly what the single-alternative differential above cannot produce.
#
# Verify command uses both library roots, an empty object guard, the
# differential program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-http-version-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.http-version.chez.source
  LABEL "compile: a branching state renders only its FIRST transition arm"
  # Keeping the head leaves `HTTP/1.0` -- the lower branch byte, 48 -- rendered
  # and `HTTP/1.1` falling through to the state's else fallback, so the
  # generated executor rejects at offset 7 where the interpreter stops at 8.
  # The FIND occurs once in the file; SITES therefore stays at its default
  # of 1.
  #
  # Measured: baseline cases=8
  # failed-cases=0 checks=19 failures=0 status=0; mutant cases=8
  # failed-cases=4 checks=19 failures=6 status=1. Comparison-caught throughout
  # (check-equal failures, no raise) -- every dispatch state in this fixture
  # has at least one transition, so `car` never sees an empty list.
  #
  # Pinned to the exhaustive group's own sentinel rather than to any of the
  # five other failing checks, because that check reports the FIRST
  # (mode position byte) triple that disagreed and the triple names the defect
  # exactly: (reexecute 7 49) is prefix position 7 -- the branch -- and byte 49,
  # `HTTP/1.1`'s distinguishing byte, the one this truncation drops. The
  # sibling's is the mirror, (reexecute 7 48).
  FIND [[(render-byte-clauses (normal-dispatch-transitions s))]]
  REPLACE [[(render-byte-clauses (list (car (normal-dispatch-transitions s))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "256 x 8 positions match, in both mismatch modes: no \\(mode position byte\\) disagreed -- expected none, got \\(reexecute 7 49\\)")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.http-version.chez.source
  LABEL "compile: a branching state renders only its LAST transition arm"
  # The opposite truncation, and the reason both are here: keeping only the
  # head leaves `HTTP/1.0` coincidentally correct, so on its own it cannot show
  # that the zero alternative is reached by having its OWN arm rendered rather
  # than by being the one arm the emitter ever writes. Keeping only the tail is
  # the mirror -- `HTTP/1.1` accepts, `HTTP/1.0` rejects at offset 7. Same FIND
  # as the mutation above (each byte_machine_mutation() call reads a pristine
  # copy of compile.sls and restores it afterward, so sharing a FIND is a
  # different edit, not a repeated one).
  #
  # Measured: mutant cases=8 failed-cases=6
  # checks=19 failures=9 status=1 -- two failed cases and three failures more
  # than the sibling, and the two extra cases are exactly the "nonzero-offset
  # and empty slices agree" pair, which feeds `HTTP/1.0` and so is untouched by
  # the sibling's truncation. Comparison-caught.
  #
  # Pin sweep, both directions, against every other mutation under this pass's
  # verify command -- which is the sibling above and nothing else: 2 mutations,
  # 2 ordered pairs (n(n-1), this file's convention: ordered pairs of DISTINCT
  # mutants, so the two self-checks are not counted as pairs).
  # Every pin re-judged through byte_machine_mutation_verdict against both
  # captured outputs. Result: counted separately, each pin catches its own
  # mutant, and each returns wrong-reason against the other's; zero
  # collisions. The two pins differ only in the branch byte they name (49 vs
  # 48), and each mutant's
  # output contains exactly one of the two.
  # Control: the neighbouring-lane measurement recorded in this pass's header
  # shows both mutants surviving the two lanes they are NOT declared under.
  FIND [[(render-byte-clauses (normal-dispatch-transitions s))]]
  REPLACE [[(render-byte-clauses (list (car (reverse (normal-dispatch-transitions s)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES
    "256 x 8 positions match, in both mismatch modes: no \\(mode position byte\\) disagreed -- expected none, got \\(reexecute 7 48\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 49: the sequence determinism golden is non-vacuous -----------------
#
# determinism-http-version-tests.sps compares the emitted bytes of the HTTP
# `version` production against test/fixtures/generated-http-version.golden.sls,
# a committed golden whose machine contains a BRANCH. The mutation below
# flips trie-put's insert-before-if-less arm, so a trie node's children come out
# DESCENDING by byte instead of ascending -- breaking the trie's child-order
# rule, which is what keeps normalized output deterministic at a branch.
#
# trie-put is the whole of that rule for a SEQUENCE prefix state: the `list-sort`
# at the head of the byte-dispatch arm never sees these states,
# and this fixture declares no byte-dispatch node at all. Measured as a control
# rather than read off the source -- flipping that comparator
# `(< (car a) (car b))` -> `(> ...)` re-emits this
# machine BYTE-IDENTICALLY to the committed golden, and leaves this pass's own
# program green (cases=3 failed-cases=0 checks=8 failures=0 status=0).
# `list-sort` is the ascending-by-byte transition sort of a byte-dispatch node,
# not of a sequence prefix state, which is what this fixture is made of.
#
# It is the same one-line edit Pass 35 declares as "normal-ir: trie children are
# not kept ascending by byte", re-declared under this lane's SPEC for the reason
# Pass 46 re-declares Pass 44's byte shift (AGENTS.md: a mutation is witnessed
# only by the tests that run in the lane its SPEC names). What differs is the
# witness kind: Pass 35 asserts the lowered transition list structurally, and
# this pass asserts the EMITTED BYTES.
#
# Why this golden is what witnesses it, measured rather than argued. The
# mutant leaves the tree's other two determinism programs
# passing UNCHANGED -- byte-identical summaries to their own unmutated
# baselines, because neither machine contains a sequence node, so
# trie-put is never called:
#   determinism-one-byte-tests.sps: cases=3 failed-cases=0 checks=4 failures=0
#   status=0, baseline and mutant alike;
#   determinism-pause-tests.sps: cases=4 failed-cases=0 checks=8 failures=0
#   status=0, baseline and mutant alike.
#
# Stated rather than implied, because "no other lane catches this" would be
# false, and because the set that does NOT catch it is the surprising half.
# Measured, exactly one other program reddens:
#   normal-ir-tests.sps (Pass 35's SPEC program, where this same edit is also
#   declared): cases=38 failed-cases=4 checks=82 failures=9 status=1.
# Both lanes that drive this same branching fixture through an EXECUTOR stay
# green: differential-http-version-tests.sps (cases=8 failed-cases=0 checks=19
# failures=0 status=0) and http-version-interpret-tests.sps (cases=12
# failed-cases=0 checks=19 failures=0 status=0). So do the neighbouring
# sequence and core lanes --
# differential-sequence-node-tests.sps, sequence-interpret-tests.sps,
# interpret-tests.sps, compile-tests.sps, ir-tests.sps and verify-tests.sps, all
# status=0. That is not an accident of these fixtures: reordering the two arms
# of a `case` over disjoint byte sets is BEHAVIOUR-PRESERVING, so the two
# executors still agree and no differential can see it. Emission ORDER is
# observable only in the bytes, which is what a golden is for.
#
# The mutant's library is also 3849 bytes -- the same length as the golden -- so
# a size check would not notice either. Diffed against the committed golden, the
# whole difference is the branch state's two arms swapping ((48) before (49)
# becomes (49) before (48)) and the v2 fingerprint moving
# 16999772257989587335 -> 14649231454401036534.
#
# Three neighbouring edits are measured and NOT declared
# here, recorded so the next reader does not re-derive them:
#   allocate-prefix-ids walked breadth-first instead of depth-first (Pass 35
#   carries this edit) is INERT on this fixture -- cases=3 failed-cases=0
#   checks=8 failures=0 status=0. Every interior trie node here has exactly one
#   interior child, so the two walks number the chain identically. Declaring it
#   under this SPEC would be an uncaught mutation.
#   prefix ids started at 0 rather than declared-count (also Pass 35) IS caught
#   here (failed-cases=2 failures=6) but corrupts the states vector outright, so
#   it reddens the execution group as well as the golden and says nothing about
#   the branch's ORDER.
#   trie-put's merge (=) arm disabled (also Pass 35) IS caught here
#   (failed-cases=2 failures=3), but it changes BEHAVIOUR -- `HTTP/1.1` becomes
#   unreachable -- so the execution lanes see it: measured
#   differential-http-version-tests.sps failed-cases=4 failures=6 and
#   normal-ir-tests.sps failed-cases=7 failures=10. It needs no witness here.
#
# Pin sweep, both directions. This pass declares one mutation, so under this
# file's n(n-1) convention there are ZERO ordered pairs of distinct mutants --
# there is no sibling under this verify command to collide with. What is
# run is the self-check, counted separately: the pin against its own
# capture, which it matches. A self-check is not an ordered pair. No OTHER
# pass runs this program, so no other pin's collision set includes it. The pin
# is the case-name tail plus the check label, which resolves to the single (case,
# check) pair "the emitted bytes equal the committed sequence golden" /
# "golden": this program declares exactly one check with that label, and the pin
# contains no regex metacharacter. The measured DETAIL is deliberately not
# pinned: it is a 3849-element bytevector dump, so any pin drawn from it
# embeds the golden's own bytes in this file, and there is no collision here for
# it to resolve.
#
# The word "sequence" in that case name is load-bearing, not decoration. Without
# it this program's case AND check names are byte-identical to Pass 38's
# (determinism-one-byte-tests.sps), so the two pins would be the same string.
# That is sound as this suite works -- BYTE_MACHINE_MUTATION_VERIFY_COMMAND
# is set per pass, each names one --program, and byte_machine_mutation_verdict
# judges a pin only against its own mutation's captured output -- but uniqueness
# costs nothing here, and it stays correct if a pass's verify command
# ever runs more than one determinism program.
# Control: the neighbouring-determinism measurement above shows the
# mutant surviving the two determinism lanes it is NOT declared under.
#
# Verify command uses both library roots, an empty object guard, the
# determinism program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-http-version-tests.sps"
  # the golden lives in the source tree; the staged program reads it via env
  # (BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE, supplied by this suite's own ctest
  # registration and inherited unmodified through execute_process -- see "WHAT
  # THIS SUITE NEEDS FROM ITS ENVIRONMENT" above)
  )

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls
  SPEC byte-machine.determinism.http-version.chez.source
  LABEL "normal-ir: a branching trie's children are emitted descending by byte"
  # The FIND occurs once in the file; SITES therefore stays at its default
  # of 1.
  #
  # Measured: baseline cases=3
  # failed-cases=0 checks=8 failures=0 status=0; mutant cases=3 failed-cases=1
  # checks=8 failures=1 status=1, the one failure being the golden comparison
  # and nothing else. Comparison-caught (a check-equal failure, no raise): the
  # emitted library still loads and both alternatives still walk, which is
  # exactly why the golden rather than the execution group is what notices.
  FIND [[          ((< b (caar cs)) (cons (cons b child) cs))]]
  REPLACE [[          ((> b (caar cs)) (cons (cons b child) cs))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the emitted bytes equal the committed sequence golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# reserved-member-3's drift guard. Its own PASS, because a mutation is
# witnessed only by tests that run in the lane its SPEC names -- appended to
# the preceding pass it would run under a verify command driving a different
# program and report UNCAUGHT.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/member3-drift-tests.sps")

# The list of emitted locals grows whenever a lowering binds a new name, so
# the drift is a live risk rather than a theoretical one. The mutation is a
# deletion, which is the drift the guard exists to catch.
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.member3-drift.chez.source
  LABEL "compile: an emitted local is missing from reserved-member-3"
  # The list includes `v` and `r` (the emitted field arms' locals), `d` (the
  # accumulate arm's digit), `psr` and `cbv` (emitted `exec`'s eighth and
  # ninth parameters), `o` (the callback arm's outcome binding) and `kpath`
  # (the keyword-table arm's resume-path local). Dropping `pk` is the edit.
  # This pin moves whenever the list does, by design: it anchors on the whole
  # list precisely so that a name added without a matching guard entry is what
  # breaks it.
  FIND [[    '(exec loop pos st off b bv start end state offset finish? fieldv errs pk
      v r d o psr cbv n kpath))]]
  REPLACE [[    '(exec loop pos st off b bv start end state offset finish? fieldv errs
      v r d o psr cbv n kpath))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no undeclared emitted local -- expected \\(\\), got \\(pk\\)")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.member3-drift.chez.source
  LABEL "compile: reserved-member-3 loses the accumulate arm's digit local"
  # This fixture carries an accumulate node, so the `d` entry is EXERCISED
  # rather than merely declared. Dropping it is what the guard is for:
  # the emitted body binds a local the list does not reserve, and a caller may
  # legitimately bind the same name. This FIND and the whole-list FIND above
  # are textually distinct and each occurs exactly once, which the suite
  # asserts in both directions (no SITES is declared on either, so each FIND
  # is pinned at one occurrence).
  FIND [[      v r d o psr cbv n kpath))]]
  REPLACE [[      v r o psr cbv n kpath))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no undeclared emitted local -- expected \\(\\), got \\(d\\)")

# --- the counted arm's one local ---------------------------------------------
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.member3-drift.chez.source
  LABEL "compile: reserved-member-3 loses the counted arm's n"
  FIND [[      v r d o psr cbv n kpath))]]
  REPLACE [[      v r d o psr cbv kpath))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no undeclared emitted local -- expected \\(\\), got \\(n\\)")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# The position kind is a property of the ARRIVING transition, asserted BY
# VALUE in both executors.
#
# What the by-value assertion adds, stated honestly. Each mutation below breaks
# exactly ONE lane, so the cross-lane comparison would also catch it. What the
# by-value check adds for these three is that the failure NAMES the wrong kind
# instead of reporting a bare disagreement between two tuples.
#
# The case the by-value assertion uniquely covers -- both lanes agreeing on a
# WRONG kind, which AGENTS.md's "agreement must stay observable" rule is about --
# has no mutation here and cannot have one: a mutation edits a single FILE, and
# making both lanes agree wrongly takes a coordinated edit to compile.sls and
# runtime.sls at once. The by-value assertions in position-kind-tests.sps are
# the only guard against it, which is why they assert the kind against the
# position-kind table rather than only against each other.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/position-kind-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: an emitted reexecute jump carries the advance position kind"
  FIND [[(string-append "(%s" (number->string target) " pos " (number->string target)
                       " off (quote byte))")]]
  REPLACE [[(string-append "(%s" (number->string target) " pos " (number->string target)
                       " off (quote boundary))")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "reexecute mismatch reports byte at the offending byte: kind -- expected byte, got boundary")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the interpreter's advance jump carries the reexecute position kind"
  # Anchored on `route-byte-step!`, where the two byte-consuming kinds share
  # one tail. The decision -- an ADVANCE reports `boundary`, a reexecute
  # reports `byte` -- covers both.
  FIND [[              (loop (+ pos 1) 'boundary))
            (loop pos 'byte)))]]
  REPLACE [[              (loop (+ pos 1) 'byte))
            (loop pos 'byte)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "an advance-mode mismatch reports boundary after the committed byte: kind -- expected boundary, got byte")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the default-EOF arm reports a byte position rather than eof"
  # Truncated input during finish! reports `eof`, and this arm is a
  # terminal construction reached by no jump, so it takes a per-site literal
  # rather than the loop variable. The two mutations above cover `byte` in the
  # generated lane and `boundary` in the interpreter; this one witnesses the
  # third of the three kinds the lane is named for.
  FIND [[") " id " off (quote eof)) " id " off)")))]]
  REPLACE [[") " id " off (quote byte)) " id " off)")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "both lanes report eof at the terminal, not at a hop: generated -- expected eof, got byte")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: a reason is written into generated source unescaped"
  # Generated source escapes a reason explicitly. valid-reason? deliberately
  # ADMITS the three characters that need it -- they are inside the
  # printable-ASCII-plus-LF reason repertoire -- so escape-string is the only
  # thing between an author-supplied reason and a generated library that
  # either does not parse or parses WRONG.
  #
  # Measured, not assumed: with only the quote clause removed the file still
  # READS -- the string terminates early and the reason arrives as "a " instead
  # of the declared text -- so the witnessing check is the ROUND TRIP, not the
  # load. Removing the whole escaper does produce a reader error, but that is a
  # DIFFERENT mutant. The round trip is the stronger assertion anyway:
  # escaping to the empty string would also load.
  #
  # The witness needs a reason carrying a character that must be escaped: a
  # reason of plain lowercase ASCII plus space cannot distinguish this
  # function from the identity.
  FIND [[                  (cond ((char=? c #\") (cons #\" (cons #\\ acc)))]]
  REPLACE [[                  (cond ((char=? c #\nul) (cons c acc))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted library loads and reports the reason unchanged: generated round-trips the reason")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: an error declaration is resolved by code alone"
  # Two declarations may share a CODE --
  # pass-names rejects duplicate declaration NAMES and nothing rejects duplicate
  # codes -- and the normalizer has collapsed the node's declaration name to its
  # resolved code by the time the emitter sees it, so keying on the code alone
  # returns the FIRST declaration carrying it. The generated lane then reports a
  # different declaration's reason than the interpreter, on a machine the
  # verifier accepts with zero diagnostics. Invisible to the other lanes
  # (each fixture uses distinct codes) and to the property lane (machine-gen.sls
  # fixes two declarations with distinct codes), which is why it has its own
  # fixture rather than a wider sweep of the existing ones.
  FIND [[((and (eq? (error-declaration-code (car ds)) code)
                                     (string=? (error-declaration-reason (car ds)) reason))]]
  REPLACE [[((eq? (error-declaration-code (car ds)) code)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "both lanes report the reason of the declaration the node names: generated")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the finish loop initializes the position kind to eof"
  # The initialization is `boundary` UNCONDITIONALLY, in a feed call and a
  # finish call alike, with no finish? key. Initializing this loop to `eof`
  # makes both lanes agree at the default-EOF arm and makes that arm's own
  # literal observationally identical to the inherited variable.
  FIND [[(let loop ((node (parser-current parser)) (pk 'boundary))]]
  REPLACE [[(let loop ((node (parser-current parser)) (pk 'eof))]]
  EXPECT_STATUS 1
  # Witnessed by the PARKED case, not by the truncation one: every other route
  # into a finish-time error either hops (setting `eof` on the way) or lands on
  # the default-EOF terminal, which takes its own per-site constant. Only an
  # error state a prior feed parked on is reached by NO jump, so only it can
  # observe what the loop was initialized to.
  EXPECT_OUTPUT_MATCHES "both lanes report boundary, not eof: interpreter -- expected boundary, got eof")

# The accumulate-overflow offset mutation is declared HERE rather than in the
# field pass, because a mutation's specification is a LABEL and the program
# actually run is this pass's verify command -- the two must name the same lane
# or the mutation runs against the wrong program and reads as uncaught
# (appended to the field pass with a position-kind SPEC, it runs
# field-access-tests.sps and is reported UNCAUGHT).
#
# It belongs to the position-kind lane rather than the field lane because what
# the overflow table row asserts and the field lane does not is the OFFSET.
# field-access-tests.sps pins the overflow's position KIND in both lanes; a
# mutation that moves the kind is caught there. This one moves the offset
# alone -- the kind stays `byte`. Measured, this mutant fails SIX behavioural
# lanes: both position-kind lanes, both determinism.accumulate lanes (that
# golden reads the emitted bytes, and this mutation changes them) and both
# property.differential lanes (the generator's draw puts an accumulate node in
# front of the oracle). differential.field passes, so the OFFSET is a thing
# only the position-kind row asserts.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted overflow advances the stream offset past the digit it did not consume"
  # An overflow "does not consume" the digit, made falsifiable. The generated
  # arm keeps `pos` -- so it does not re-read the byte -- while advancing the
  # ABSOLUTE offset, which is precisely the inconsistency a kind-only assertion
  # cannot see: the error still says `byte`, it just says it about the wrong
  # byte.
  FIND [["                       (%s" (num over) " pos " (num over) " off (quote byte))))))))\n")))]]
  REPLACE [["                       (%s" (num over) " pos " (num over) " (+ off 1) (quote byte))))))))\n")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an accumulate overflow reports byte at the unconsumed digit: offset -- expected 2, got 3")

# --- a callback failure reports `boundary` ------------------------------------
#
# "Zero-width machine action or callback failure | `boundary` at the current
# stream offset." A site building a callback-domain error that passes the
# loop's `pk` instead is right only where the invoking node was reached by an
# ADVANCE edge. Over a REEXECUTE edge `pk` is `byte`, and BOTH LANES would
# report it, so no differential can see it: the lane-to-lane projection is
# satisfied by two lanes agreeing on a wrong value, which is why these rows
# assert the VALUE and not only the agreement.
#
# FOUR mutations, because the rule has four independent sites: one named
# constant serving the runtime's six arms, and three rendered literals. Every
# fixture that reaches one does so over a reexecute edge, which is what makes
# the literal and the variable differ at all.

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: a callback failure reports the loop's position kind"
  # The interpreted half, over all three of its arms at once -- the constant is
  # one decision and the six sites read it.
  #
  # A pin on `kind -- expected boundary, got byte` would also match the
  # emitted-callback-arm mutation below byte for byte: both make that row's
  # kind check fail. What separates them is the
  # PROJECTION's direction -- the harness prints the second `check-equal`
  # argument as "expected", which is the GENERATED lane, so a mutation of the
  # interpreted lane reads `expected …boundary, got …byte` and its emitted
  # sibling reads the mirror. Measured.
  FIND [[  (define callback-failure-position 'boundary)]]
  REPLACE [[  (define callback-failure-position 'byte)]]
  EXPECT_STATUS 1
  # The projection carries the abandoned span and its offset, so each side
  # ends `#f #f` (no span is open at a callback node -- the verifier refuses
  # one there). Measured by staging the mutant.
  EXPECT_OUTPUT_MATCHES
    "the lanes agree on the projection -- expected .callback said-no .callback failure. inv 1 boundary #f #f., got .callback said-no .callback failure. inv 1 byte #f #f."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted callback arm reports the loop's position kind"
  # The generated half, one arm at a time. Each is pinned on its own row's
  # PROJECTION, whose "expected" is the generated lane's value -- the harness
  # prints the second `check-equal` argument as expected -- so the three read as
  # mirror images of each other and no two collide.
  # The FIND spans the callback pause arm's next-state line (its `" "`
  # separator precedes the optional-reason conditional) and the failure arm,
  # which reads the failure's code and detail off the CallbackFailure the
  # seam answers.
  FIND [[            " " (num (cadr tg)) " off))\n"
            "               ((callback-failure? o) (byte-machine-make-feed-outcome/v1 (quote error) pos "
            "(byte-machine-make-callback-error/v1 (callback-failure-code o) (callback-failure-detail o) (quote "
            (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))\n"]]
  REPLACE [[            " " (num (cadr tg)) " off))\n"
            "               ((callback-failure? o) (byte-machine-make-feed-outcome/v1 (quote error) pos "
            "(byte-machine-make-callback-error/v1 (callback-failure-code o) (callback-failure-detail o) (quote "
            (nm (normal-state-id s)) ") " id " off pk) " id " off))\n"]]
  EXPECT_STATUS 1
  # Pinned on the whole projection, both sides, measured: a pin ending at
  # `byte.` would match only by reaching the space before the span members.
  EXPECT_OUTPUT_MATCHES
    "a callback failure reports boundary at the committed offset: the lanes agree on the projection -- expected .callback said-no .callback failure. inv 1 byte #f #f., got .callback said-no .callback failure. inv 1 boundary #f #f."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted span-end arm reports the loop's position kind"
  # Its own site and its own row: a span end is always reached by a reexecute
  # edge in practice -- the delimiter must not be consumed into the payload --
  # so this arm is the one where the defect is easiest to reach and hardest to
  # see, both lanes agreeing on `byte`.
  FIND [[            (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))\n"
            "               " (render-dispatch-else "o") ")))\n")))
        ;; The SECOND substep.]]
  REPLACE [[            (nm (normal-state-id s)) ") " id " off pk) " id " off))\n"
            "               " (render-dispatch-else "o") ")))\n")))
        ;; The SECOND substep.]]
  EXPECT_STATUS 1
  # Measured: the data callback fails with its span still open, so both sides
  # name the span (`body`) and an empty withheld range at the error offset --
  # the failing callback was handed its bytes.
  EXPECT_OUTPUT_MATCHES
    "a span data callback failure reports boundary at the committed offset: the lanes agree on the projection -- expected .callback said-no .callback failure. cl 2 byte body 2., got .callback said-no .callback failure. cl 2 boundary body 2."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "compile: the emitted span-completion arm reports the loop's position kind"
  # The third, and the reason the lane builds a THIRD machine: a span whose
  # completion callback is declared and fails. Neither row above reaches this
  # arm, and its projection differs from the span end's only by the check label.
  FIND [[                (nm (normal-state-id s)) ") " id " off (quote boundary)) " id " off))\n"
                "                 " (render-dispatch-else "o") "))))\n"))))]]
  REPLACE [[                (nm (normal-state-id s)) ") " id " off pk) " id " off))\n"
                "                 " (render-dispatch-else "o") "))))\n"))))]]
  EXPECT_STATUS 1
  # Measured: the span is closed before its completion callback runs, so both
  # sides end `#f #f`.
  EXPECT_OUTPUT_MATCHES
    "a span completion callback failure reports boundary too: the lanes agree on the projection -- expected .callback said-no .callback failure. cl 2 byte #f #f., got .callback said-no .callback failure. cl 2 boundary #f #f."
)

# --- the runtime's counted arm, witnessed here --------------------------------
# The arm runs in the interpreted lane only (the generated lane calls the emitted
# `exec`), so its pins live in a pass whose program EXECUTES a machine carrying
# the kind through the interpreter -- this one, through the three counted rows.
# The emitted arm's exhaustion-first twin is NOT here: this file's check labels
# carry no lane prefix, so the two mutants' records are identical, and the twin
# is pinned in the counted differential pass on a lane-labelled witness.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the counted arm does not advance the stream offset"
  FIND [[                      (parser-set-offset! parser (+ n (parser-offset parser)))]]
  REPLACE [[                      (parser-set-offset! parser (parser-offset parser))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "truncation at a parked counted consume reports eof at the final offset: offset -- expected 2, got 1")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the counted arm parks current on its EOF route when input runs out"
  # `current` must stay on the node after a partial commit; the wrong value
  # available to the arm is the EOF route, and a parser parked THERE finishes
  # on the error node by no jump -- `boundary`, where a truncation is `eof`.
  FIND [[                          (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                              (parser-offset parser) #f))))))]]
  REPLACE [[                          (begin (parser-set-current! parser (op 'eof-target node))
                                 (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                                     (parser-offset parser) #f)))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "truncation at a parked counted consume reports eof at the final offset: kind -- expected eof, got boundary")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.position-kind.chez.source
  LABEL "runtime: the counted arm asks exhaustion before the op"
  FIND [[            ((counted-consume)
             (let* ((r (op 'count-step node (parser-field-values parser) pos end))]]
  REPLACE [[            ((counted-consume)
             (let* ((r (if (>= pos end) (cons 0 #f) (op 'count-step node (parser-field-values parser) pos end)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a zero count at the end of a slice transitions before exhaustion is tested: is a record -- expected a true value")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- parser-field-ref, across BOTH executors ----------------------------------
#
# This header carries no pass number on purpose: the integers do not index
# anything countable, because helper functions call `_run` once per case in a
# loop and consume indices no header names. `EXPECTED_PASSES`, measured from
# the harness, is the only authority. Headers from here on name their subject.
#
# field-access-tests.sps is the only lane in which the field declarations are
# observable at all, and it drives both executors, which reach them by different
# routes: the interpreter asks its op closure a 'field-initials message, the
# generated lane reads member 0 of the ABI payload it was emitted with. Nothing
# is shared between those two paths, so this pass carries a mutation for each
# side separately. It emits and runtime-loads a generated library, so the verify
# command is the differential shape -- both library roots, the shared object
# guard, and BYTE_MACHINE_TEST_TMPDIR inherited from this suite's own test
# environment.
#
# TWO further mutations were measured and are NOT written, each because its
# record set is IDENTICAL to one that is -- not a subset, the same set.
#   * make-parser's op arm discarding what it asked for, versus interpret.sls
#     answering with nothing. One decision seen from the asker's side and the
#     answerer's; the parser ends up with an empty table either way.
#   * The emitter rendering a wrong field NAME, versus the v2 arm ignoring
#     member 0 entirely. A name the parser cannot match is a table it cannot
#     use, and both produce the same four raised cases.
# In each case the written mutation is the one that lives in the file whose
# field-access code it names.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/field-access-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: the v2 arm ignores the ABI payload's field member"
  # The constructor reads members 0, 1 and 2 (member 2 is the state-name
  # table) across these lines, and the OPTIONAL member 3 (the settable table)
  # on the next; the FIND stops before member 3. The decision this pin names
  # is member 0's: member 0 is the field table and dropping it must be caught.
  FIND [[            (vector-ref metadata 0) (vector-ref metadata 1)
            (vector-ref metadata 2)
]]
  REPLACE [[            (vector) (vector-ref metadata 1)
            (vector-ref metadata 2)
]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(generated\\).a fresh parser reads the declared initial at every width: case raised")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the field-initials message answers with no declarations"
  FIND [[                               (machine-fields m))))]]
  REPLACE [[                               '())))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(interpreter\\).a fresh parser reads the declared initial at every width: case raised")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted field declaration carries initial zero"
  # Pinned in THIS lane rather than the compile lane, where its record is
  # indistinguishable from the member-0 mutation's: compile-tests asserts the
  # rendered member by one substring, so every deviation reddens the same check.
  # Its cross-executor DISAGREEMENT records are shared with the runtime's own
  # zero-initials mutation, and what separates it is the emitted table's ORDER
  # assertion -- this mutation is the only one in the pass that changes the
  # rendered text of member 0.
  FIND [[ " . " (number->string (caddr (car fs))) ")")]]
  REPLACE [[ " . " (number->string 0) ")")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the emitted field table is in declaration order: member 0 lists all four in order -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: a fresh parser's field values are zero instead of the declared initials"
  # A just-constructed parser's field values. Distinct from the emitter mutation
  # above, which moves only the GENERATED half: this one moves both, so its
  # record is the interpreter's, which that one never produces.
  FIND [[            (begin (vector-set! v i (cdr (vector-ref decls i)))]]
  REPLACE [[            (begin (vector-set! v i 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(interpreter\\).a fresh parser reads the declared initial at every width: count -- expected 7, got 0")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: parser-field-ref answers an undeclared name instead of refusing"
  # An undeclared name is a CALLER mistake, not a machine outcome, so
  # it must reach a contract violation and never a parser-error.
  FIND [[        (cond ((>= i n)
               (byte-machine-contract-violation 'parser-field-ref 'accessor-misuse
                                                field-name))]]
  REPLACE [[        (cond ((>= i n) 0)]]
  EXPECT_STATUS 1
  # The accessor is shared, so both executors' groups carry the same failure;
  # without the group name the pin resolves TWICE in this mutant's own output.
  # The group name picks one.
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(interpreter\\)\\.an undeclared field name is accessor-misuse: code -- expected accessor-misuse, got no-raise")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: parser-field-ref always reads slot zero"
  # The reason the lane's fixture declares FOUR fields with four DIFFERENT
  # non-zero initials: with equal initials, with a zero among them, or with one
  # field, this mutation is invisible.
  FIND [[               (vector-ref (parser-field-values parser) i))]]
  REPLACE [[               (vector-ref (parser-field-values parser) 0))]]
  EXPECT_STATUS 1
  # The group name keeps the pin from resolving twice in this mutant's own
  # output, once per executor's group, for the reason given at the pin above.
  EXPECT_OUTPUT_MATCHES
    "parser-field-ref \\(interpreter\\)\\.a fresh parser reads the declared initial at every width: limit -- expected 65535, got 7")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: parser-reset! does not restore the field values"
  # Witnessable because a parse in this fixture changes a field: without a
  # writer slot 8 would be constant for a parser's lifetime and restoring a
  # constant is a no-op. The difference between a reset that restores and one
  # that does not is two numbers.
  # Reset restores slot 8 from the canonical merged initials (slot 17) via
  # copy-values. With no make-parser override slot 17 equals the declared
  # initials, so the fixture expects 254; deleting the restore leaves the
  # parse-changed 255.
  FIND [[    (vector-set! parser 8 (copy-values (parser-field-initials parser)))))]]
  REPLACE [[    ))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "parser-reset! restores a field a parse has CHANGED: restored to the declared initial -- expected 254, got 255")

# FIVE mutations over a fixture whose fields a parse actually changes, which is
# what makes them witnessable.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: an overflowing field operation writes anyway"
  # A failed operation leaves the prior value UNCHANGED, not saturated. An
  # overflow that starts AT the ceiling cannot witness this -- there
  # "unchanged" and "clamped to the maximum" coincide. An `add` that overflows
  # from BELOW it separates them.
  FIND [[              (field-action-node-error n))))]]
  REPLACE [[              (begin (vector-set! fv slot m*) (field-action-node-error n)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an overflow from BELOW the ceiling does not clamp: unchanged, not clamped -- expected 254, got 255")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the field bound is never checked"
  # The other direction: with no check the value simply exceeds its declared
  # width and the error target is never reached.
  FIND [[          (if (<= 0 r m*)]]
  REPLACE [[          (if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a failed operation leaves the prior value unchanged: count held at its maximum -- expected 255, got 256")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: increment does not increment"
  # One arm of the operation table, standing for all seven: the arithmetic is
  # written TWICE on purpose, so the differential can compare the two
  # implementations, and this is the interpreter's copy.
  FIND [[                    ((increment) (+ v 1))]]
  REPLACE [[                    ((increment) v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "an increment commits into the parser's own storage: count -- expected 255, got 254")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: a zero-width step consumes a byte"
  # Zero-width means zero-width: the loop must re-enter at the SAME pos. A
  # zero-width node that advanced would silently eat the byte the next dispatch
  # was going to read.
  FIND [[               (parser-set-current! parser t)
               (loop pos pk)))]]
  REPLACE [[               (parser-set-current! parser t)
               (loop (+ pos 1) pk)))]]
  EXPECT_STATUS 1
  # Not pinned on the lifecycle record: an operation that never fails is what
  # that record says, and "runtime: a fresh
  # parser's field values are zero instead of the declared initials", "interpret:
  # the field bound is never checked" and "interpret: increment does not
  # increment" all say it too. The two-field accumulate machine shows the eaten
  # byte itself: `bump`, the zero-width hop after each digit, swallows the `a` of
  # `#1aF`, so n reads 0x1F = 31 rather than 0x1aF = 431.
  EXPECT_OUTPUT_MATCHES
    "the accumulate commits into the field it NAMES, not into slot zero: interpreter n -- expected 431, got 31")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: a zero-width step resets the position kind"
  # The position kind is differential-compared, so the two lanes must
  # agree. A zero-width step does not move the parser in the input, so the kind
  # is carried THROUGH -- a failure reached after one reports what it would have
  # reported without it.
  FIND [[             (parser-set-current! parser t)
             (loop t pk)))]]
  REPLACE [[             (parser-set-current! parser t)
             (loop t 'boundary)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a failure after a zero-width hop on an EOF chain reports eof, not boundary: position kind -- expected eof, got boundary")

# SIX mutations for the EMITTER's field arms. Everything they pin is a
# SECOND implementation of what the interpreter's mutations pin -- the
# arithmetic is written twice on purpose, and these are the copy
# the differential exists to compare.
#
# One mutation is measured and NOT written: swapping the branch arms produces a
# record set IDENTICAL to "the emitted zero predicate is inverted" below -- not a
# subset, the same set. On a two-armed branch, swapping the arms and negating the
# predicate are the same function, so no fixture can separate them by behaviour;
# only reading the source tells them apart.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted bound check is absent"
  # The field-operation bound check, emitter side.
  FIND [[         (if (and (>= r 0) (<= r "]]
  REPLACE [[         (if (or #t (>= r 0) (<= r "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes\\.both lanes agree over every input the fixture can take: count \\[10\\] -- expected 254, got 265")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted upper bound is off by one"
  # The boundary rather than the check: a u8 accepts 255 and rejects 256.
  FIND [[(num (- (expt 2 width) 1))]]
  REPLACE [[(num (expt 2 width))]]
  EXPECT_STATUS 1
  # Pinned on a check that exists for it. Per input, every record this mutant
  # emits, "compile: the emitted bound check is absent" emits too: that mutant
  # drops BOTH ends of the bound, this one loosens the upper end by one, and on
  # any single input where this one misbehaves the other misbehaves
  # identically -- containment by construction, per input. The matrix asserts
  # both ends as one value per width, which
  # spans an overflow AND an underflow: `(256 0)` here, `(256 -1)` there, and
  # `(255 -1)` for the lower-end mutant below.
  EXPECT_OUTPUT_MATCHES
    "the operation matrix over every width\\.overflow, underflow and success agree across widths and lanes: gen both ends u8 \\[02\\] -- expected \\(255 0\\), got \\(256 0\\)")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted overflow writes the value anyway"
  # Emitter side: a failed operation leaves the prior
  # value UNCHANGED, not saturated. The fixture's `add` overflows from BELOW the
  # ceiling, which is what makes unchanged and clamped distinguishable at all.
  FIND [[                "             " (zero-width-jump (cdr tg)) ")))\n")]]
  REPLACE [[                "             (begin (vector-set! fieldv " (num slot) " r) " (zero-width-jump (cdr tg)) "))))\n")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "fields a parse actually writes\\.both lanes agree over every input the fixture can take: count \\[10\\] -- expected 254, got 264")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted increment does not increment"
  # One arm of the emitter's operation table, and the counterpart of the
  # interpreter mutation of the same name -- two implementations, two pins.
  FIND [[      ((increment) "(+ v 1)")]]
  REPLACE [[      ((increment) "v")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane writes, checks and routes identically: count -- expected 255, got 254")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted zero-width step consumes a byte"
  # Zero-width means zero-width in the generated lane too: the emitted jump
  # keeps pos, off and pk. Advancing would eat the byte the next dispatch reads.
  FIND [[(string-append "(%s" (num target) " pos " (num target) " off pk)"))]]
  REPLACE [[(string-append "(%s" (num target) " (+ pos 1) " (num target) " off pk)"))]]
  EXPECT_STATUS 1
  # The emitter's half of the runtime pin above: the lifecycle record is shared
  # with four siblings
  # ("compile: an emitted field declaration carries initial zero", "compile: the
  # emitted bound check is absent", "compile: the emitted upper bound is off by
  # one", "compile: an emitted increment does not increment"); the eaten `a` is
  # this mutant's own.
  EXPECT_OUTPUT_MATCHES
    "the accumulate commits into the field it NAMES, not into slot zero: generated n -- expected 431, got 31")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted zero predicate is inverted"
  # The branch arm. See this block's header for the mutation it stands in for.
  FIND [[      ((zero) "(= v 0)")]]
  REPLACE [[      ((zero) "(not (= v 0))")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane writes, checks and routes identically: seen -- expected 1, got 101")

# THREE mutations for the operation matrix. The two lower-bound
# mutations are what the matrix exists for: the field fixtures above all
# overflow UPWARD, so a check that tested only the upper bound passes all of
# them. Underflow at `decrement` from 0 is the only place the lower half of
# the bound is load-bearing.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the field lower bound is not checked"
  # A decrement at 0 goes to -1 and is accepted. Caught in the INTERPRETER's
  # half of the comparison, which is what makes it distinct from the emitter's.
  FIND [[          (if (<= 0 r m*)]]
  REPLACE [[          (if (<= r m*)]]
  EXPECT_STATUS 1
  # Pinned on the matrix's both-ends check. Per input, every record this mutant
  # emits, "interpret: the field bound is never checked" emits too: one end of
  # the bound is an arm of the
  # whole check, contained per input by construction. Both ends as one value
  # part them -- `(255 -1)` here, `(256 -1)` there.
  EXPECT_OUTPUT_MATCHES
    "the operation matrix over every width\\.overflow, underflow and success agree across widths and lanes: interp both ends u8 \\[02\\] -- expected \\(255 0\\), got \\(255 -1\\)")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted field lower bound is not checked"
  # The same decision in the emitter's copy of the arithmetic. Its record names
  # the GENERATED half, which the interpreter mutation never touches.
  FIND [[         (if (and (>= r 0) (<= r "]]
  REPLACE [[         (if (and #t (<= r "]]
  EXPECT_STATUS 1
  # The emitter's half of the pin above. Contained by construction in "compile:
  # the emitted bound check is absent", and its lower-bound records also emitted
  # by "compile: an emitted overflow writes the value anyway". Both ends as one
  # value: `(255 -1)` here, `(256 -1)` for each of those two.
  EXPECT_OUTPUT_MATCHES
    "the operation matrix over every width\\.overflow, underflow and success agree across widths and lanes: gen both ends u8 \\[02\\] -- expected \\(255 0\\), got \\(255 -1\\)")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: decrement does not decrement"
  # The success control's other side: without a real decrement the underflow
  # row stops underflowing and the lifecycle flips.
  FIND [[                    ((decrement) (- v 1))]]
  REPLACE [[                    ((decrement) v)]]
  EXPECT_STATUS 1
  # The matrix's lifecycle disagreement is also how "interpret: the field bound
  # is never checked" and "interpret: the field lower bound is not checked" fail
  # that row. The coverage group's operation value -- a decrement from 12 that
  # stays at 12 -- is this mutant's alone.
  EXPECT_OUTPUT_MATCHES
    "every operation computes the same value in both lanes: interp decrement -- expected 11, got 12")

# The coverage group exercises every one of the fourteen operations and
# predicates, because a differential only compares what a fixture EXERCISES:
# without it clear-mask, equal, nonzero, mask-any, mask-all and mask-none
# appear in no other fixture, so their two independent implementations would
# never be compared, and inverting the EMITTER's mask-none alone would leave
# every lane at status 0.
#
# TWO mutations pin the group itself -- one per lane, on a member no other
# fixture reaches. The other four are covered by
# the same two checks and are not written separately: their record sets differ
# only in which row of the same loop reddens, so a mutation per member would add
# twelve pins that all resolve to the same two (case, check) pairs.

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted mask-none predicate is inverted"
  # Exercised in BOTH lanes only by the coverage group: without it, this
  # mutation passes every lane in the tree.
  FIND [[      ((mask-none) (string-append "(= 0 (bitwise-and v " (num a) "))"))]]
  REPLACE [[      ((mask-none) (string-append "(not (= 0 (bitwise-and v " (num a) ")))"))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every predicate takes the same arm in both lanes: gen mask-none 3 -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: mask-all is computed as mask-any"
  # The INTERPRETER's half, and the reason the operands are chosen to separate
  # each predicate from its siblings rather than merely to exercise it: with
  # `mask-all 12` on f=12 this mutation answers correctly and SURVIVES. The
  # operand is 14, where 12 has some of the mask bits but not all.
  FIND [[                      ((mask-all) (= a (bitwise-and v a)))]]
  REPLACE [[                      ((mask-all) (not (= 0 (bitwise-and v a))))]]
  EXPECT_STATUS 1
  # `got 1` is a prefix of "runtime: parser-field-ref always reads slot
  # zero"'s `got 12` on the same row. `[^0-9]` ends the number, since `$`
  # cannot end a line here.
  EXPECT_OUTPUT_MATCHES
    "every predicate takes the same arm in both lanes: interp mask-all 14 -- expected 2, got 1[^0-9]")

# FIVE pinned and TWO survivors for the checked multiply-add, written twice
# (interpreter and emitter) so the differential can compare them.
#
# *** The two survivors are the SAME decision in the two lanes. *** Replacing
# the pre-check `current <= floor((maximum - digit) / base)` with a
# compute-then-check `current * base + digit <= maximum`
# gives IDENTICAL answers on this host, because Chez has bignums and never
# wraps. The pre-check is specified anyway, because the accumulation "must not
# rely on host fixnum width or silent wrapping" -- so the form is
# mandated for a host this project does not run on. No fixture can distinguish
# them here; that is a property of the host, not a gap in the lane.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: base 16's lowercase digits are not digits"
  # The reason the fixture spells 1aF: base 16's digits are three DISJOINT
  # ASCII ranges, and a fixture using only 0-9 passes against an implementation
  # that handles no letters at all.
  FIND [[((and (>= byte 97) (<= byte 102)) (+ 10 (- byte 97)))]]
  REPLACE [[((and (>= byte 97) (<= byte 102)) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes.base 16 accepts all three ASCII digit ranges: interpreter")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: a digit is not bounded by the base"
  # `a` is a digit in base 16 and not in base 10. Without this bound a base-10
  # machine would accumulate hex letters.
  FIND [[(and v (< v base) v)]]
  REPLACE [[(and v v)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes.a base-10 machine does not accept a hex letter as a digit: interpreter")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: an overflow consumes the offending digit"
  # Overflow does NOT consume the digit, which is what makes the
  # reported position kind `byte` rather than `boundary`. The value being
  # unchanged is the other half and is pinned by the matrix.
  FIND [[(cons (integer-accumulate-node-overflow-error n) 'reexecute)]]
  REPLACE [[(cons (integer-accumulate-node-overflow-error n) 'advance)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes.an overflow reports position kind BYTE, at the offending digit: interpreter")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: base 16's lowercase digits are not emitted as digits"
  # The emitter's copy of the same decision -- written twice on purpose, and
  # this is the half the differential exists to compare.
  FIND [[" ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"]]
  REPLACE [[" "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes.base 16 accepts all three ASCII digit ranges: generated")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: an emitted overflow consumes the offending digit"
  FIND [[            "                       (%s" (num over) " pos " (num over) " off (quote byte))))))))\n"]]
  REPLACE [[            "                       (%s" (num over) " (+ pos 1) " (num over) " (+ off 1) (quote boundary))))))))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the checked multiply-add, both lanes.an overflow reports position kind BYTE, at the offending digit: generated")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the overflow check is made after the multiply-add"
  FIND [[((<= (vector-ref fv slot) (div (- m* d) base))]]
  REPLACE [[((<= (+ (* (vector-ref fv slot) base) d) m*)]]
  EXPECT_SURVIVES
    "measured, not assumed: this mutant passes the whole lane unchanged, in both lanes, and it always will on this host. The check is specified as `current <= floor((maximum - digit) / base)`, BEFORE the multiply-add; this mutant computes `current * base + digit` first and tests the product. Under Chez the product is an exact integer of unbounded size, so the two forms agree on every input and no fixture can separate them -- including the u64 case, where the accumulated value is already a bignum and the product simply becomes a larger one. The pre-check is written anyway because the accumulation must not rely on host fixnum width or silent wrapping. The form is for a host that WRAPS, where computing the product first would silently produce a small wrong number and the check would pass. This project does not run on such a host, so the requirement is unwitnessable here by construction -- a property of the host, not a gap in the lane. Reopening condition: a backend whose integers wrap, or any change that makes the accumulation use fixnum-specialised arithmetic, makes this mutant a bug detector and it must be re-measured and pinned then."
  )

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted overflow check is made after the multiply-add"
  FIND [[            "                   (if (<= v (div (- " (num mx) " d) " (num base) "))\n"]]
  REPLACE [[            "                   (if (<= (+ (* v " (num base) ") d) " (num mx) ")\n"]]
  EXPECT_SURVIVES
    "measured, not assumed: this mutant passes the whole lane unchanged, in both lanes, and it always will on this host. The check is specified as `current <= floor((maximum - digit) / base)`, BEFORE the multiply-add; this mutant computes `current * base + digit` first and tests the product. Under Chez the product is an exact integer of unbounded size, so the two forms agree on every input and no fixture can separate them -- including the u64 case, where the accumulated value is already a bignum and the product simply becomes a larger one. The pre-check is written anyway because the accumulation must not rely on host fixnum width or silent wrapping. The form is for a host that WRAPS, where computing the product first would silently produce a small wrong number and the check would pass. This project does not run on such a host, so the requirement is unwitnessable here by construction -- a property of the host, not a gap in the lane. Reopening condition: a backend whose integers wrap, or any change that makes the accumulation use fixnum-specialised arithmetic, makes this mutant a bug detector and it must be re-measured and pinned then. The emitter's copy of the same decision; the two are one ruling and both are recorded so neither can be quietly changed alone."
  )

# ONE mutation for split-point fragmentation. The group's other cases TEST
# behaviour the accumulate arm INHERITS rather than implements: an accumulate
# node needs no state of its own across a feed boundary. The
# partially-accumulated value IS the field -- parser slot 8, which
# survives a feed -- and `current` stays parked on the node because the arm
# returns need-input without moving it, exactly as the dispatch arm does.
#
# Two candidate mutations were measured and are NOT written here: resetting
# `current` on need-input SURVIVES (the fixture's entry reexecutes back into
# the accumulate node, so the routing masks it), and reading the previous byte
# is caught by the checked multiply-add cases above rather than by these.

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.field.chez.source
  LABEL "runtime: an exhausted accumulate slice reports stopped instead of need-input"
  # The accumulate arm's own end-of-slice decision. A single-feed fixture never
  # reaches the guard, which is why fragmentation needs cases of its own rather
  # than being assumed to follow from the dispatch arm's pin. Measured, this
  # mutant reddens FOUR groups -- the split cases, the all-256 partition, the
  # default-EOF consumer group, and both property.differential lanes -- and
  # the pin is on the split cases.
  FIND [[            ((accumulate)
             (if (>= pos end)
                 (make-parser-result 'need-input pos]]
  REPLACE [[            ((accumulate)
             (if (>= pos end)
                 (make-parser-result 'stopped pos]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "split-point fragmentation.a number split across a feed boundary accumulates whole: interpreter")

# TWO mutations for the all-256 digit partition -- one per lane, because the
# group's claim is about both lanes agreeing and a mutation to only one of
# them is what that claim is for. Each is an off-by-one at a digit-range BOUND,
# the defect the handful-of-digits fixtures structurally cannot see: they name
# `a`, `F` and `!`, so the bytes that move when a bound slips by one are
# exactly the bytes they never feed. Both are caught by the partition group
# ALONE -- measured.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the base 16 lowercase digit range stops one short of f"
  # 102 is `f`. No other fixture feeds it -- the base 16 lane's case uses `a`
  # and `F` -- so this survives every other accumulate test in the tree. Caught
  # twice over here: the all-256 comparison reports the divergent byte, and the
  # partition SIZE drops 22 -> 21, which is the assertion cross-lane agreement
  # cannot make (two lanes wrong together still agree).
  FIND [[((and (>= byte 97) (<= byte 102)) (+ 10 (- byte 97)))]]
  REPLACE [[((and (>= byte 97) (<= byte 101)) (+ 10 (- byte 97)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "base 16 partitions every byte identically in both lanes: no divergence -- expected none, got \\(102")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted base 10 digit range admits the colon"
  # 58 is `:`, the byte immediately above `9`, and it decodes to 10 -- a digit
  # worth exactly the base. The emitter is the mutated side here and the
  # interpreter is untouched, so this is caught by the CROSS-LANE half of the
  # partition rather than by any absolute count: the generated machine accepts a
  # byte the interpreter rejects.
  FIND [["(and (>= b 48) (<= b 57) (- b 48))"]]
  REPLACE [["(and (>= b 48) (<= b 58) (- b 48))"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "base 10 partitions every byte identically in both lanes: no divergence -- expected none, got \\(58")

# The emitter's reached-declaration walk credits every state kind that can
# consume the default-EOF route. Crediting only `dispatch` states means a
# machine whose only default-eof consumer is an accumulate node has that
# declaration filtered out of the emitted errs table, and index-of raises
# while rendering a machine the verifier has just accepted.
#
# Pinned HERE, on a fixed fixture, rather than on the property lane: the
# generated sequence re-rolls whenever any draw changes, and a defect whose
# only witness is a seeded draw has a witness that can vanish without anyone
# editing it. (It fails the property lane too -- measured.)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: only dispatch states are credited with consuming the default EOF declaration"
  # Narrowing the credit list to `dispatch` alone is the edit; the witness is
  # the field differential's accumulate-only default-eof consumer.
  FIND [[((and (memq (normal-state-kind st)
                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))]]
  REPLACE [[((and (memq (normal-state-kind st)
                                                      '(dispatch))]]
  EXPECT_STATUS 1
  # The render raises in both cases of its group, so the bare message would
  # resolve twice in this mutant's own output; the case name picks the
  # accumulate node's own route.
  EXPECT_OUTPUT_MATCHES
    "the accumulate node.s own eof route resolves the default declaration: case raised -- Exception in render-machine: no error declaration for code")

# --- FOUR operands of the accumulate node, separated by one fixture ---------
# An accumulate machine that declares one field, names itself as its
# digit-target, gives its non-digit edge mode `advance`, and overflows only in
# base 10 leaves the slot lookup, the digit-target operand, the normal
# reexecute case of the non-digit edge, and the base in the bound's divisor as
# free parameters. Seven mutations against one fixture that separates all
# four; each is measured caught by that fixture's group.

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the accumulate commits into slot zero instead of the field it names"
  FIND [[               (slot (car sw)) (m* (field-max (cdr sw)))
               (base (integer-accumulate-node-base n))]]
  REPLACE [[               (slot 0) (m* (field-max (cdr sw)))
               (base (integer-accumulate-node-base n))]]
  EXPECT_STATUS 1
  # This check also fails
  # under "runtime: parser-field-ref always reads slot zero", "runtime: a
  # zero-width step consumes a byte" and "interpret: base 16's lowercase digits
  # are not digits", each with its own wrong n. Committed to slot zero, n is
  # never written at all.
  EXPECT_OUTPUT_MATCHES "the accumulate commits into the field it NAMES, not into slot zero: interpreter n -- expected 431, got 0")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted accumulate commits into slot zero instead of the field it names"
  FIND [[(slot (car sw)) (mx (- (expt 2 (cdr sw)) 1))]]
  REPLACE [[(slot 0) (mx (- (expt 2 (cdr sw)) 1))]]
  EXPECT_STATUS 1
  # Pinned like its interpreted half above, against the generated
  # lane's counterparts: "runtime: parser-field-ref always reads slot zero",
  # "compile: an emitted zero-width step consumes a byte" and "compile: base 16's
  # lowercase digits are not emitted as digits".
  EXPECT_OUTPUT_MATCHES "the accumulate commits into the field it NAMES, not into slot zero: generated n -- expected 431, got 0")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the overflow bound divides by ten rather than by the node's base"
  # The fixture shape matters: `#FFFFF` cannot
  # separate a divisor of 16 from one of 10, because 0xFFF passes both bounds and
  # 0xFFFF fails both. The separating value lands BETWEEN them -- `#1000F`, where
  # 4096 > (65535-15)/16 and 4096 <= (65535-15)/10, so the mutant accepts a digit
  # that writes 65551 into a u16.
  FIND [[(div (- m* d) base)]]
  REPLACE [[(div (- m* d) 10)]]
  EXPECT_STATUS 1
  # The check label alone
  # is also failed by "runtime: parser-field-ref always reads slot zero",
  # "runtime: a zero-width step consumes a byte" and "interpret: the accumulate
  # commits into slot zero instead of the field it names". The value the comment
  # above predicts -- 65551, written past the u16 -- is this mutant's alone.
  EXPECT_OUTPUT_MATCHES "the overflow bound divides by the node's OWN base, at base 16: interpreter leaves 0x1000 -- expected 4096, got 65551")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted overflow bound divides by ten rather than by the node's base"
  FIND [[(div (- " (num mx) " d) " (num base) ")]]
  REPLACE [[(div (- " (num mx) " d) 10)]]
  EXPECT_STATUS 1
  # Pinned like its interpreted half above, against the generated
  # lane's counterparts: "runtime: parser-field-ref always reads slot zero",
  # "compile: an emitted zero-width step consumes a byte" and "compile: the
  # emitted accumulate commits into slot zero instead of the field it names".
  EXPECT_OUTPUT_MATCHES "the overflow bound divides by the node's OWN base, at base 16: generated leaves 0x1000 -- expected 4096, got 65551")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted digit jump self-loops instead of taking digit-target"
  # While an accumulate node IS its own digit-target, a self-loop is
  # indistinguishable from reading the operand; this fixture points the digit
  # edge somewhere else.
  FIND [[                              (%s" (num digit) " (+ pos 1) " (num digit) " (+ off 1) (quote boundary)))]]
  REPLACE [[                              (%s" id " (+ pos 1) " id " (+ off 1) (quote boundary)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one digit is taken and the DECLARED digit-target stops the parse: generated stopped")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.field.chez.source
  LABEL "interpret: the non-digit edge always advances, ignoring its declared mode"
  # The non-digit edge's NORMAL case -- "normally reexecuting the delimiter" --
  # which this is the executing fixture for. Under the mutant the
  # delimiter is consumed at the accumulate node and the fallback dispatch that
  # was supposed to read it runs out of input instead.
  FIND [[            (let ((e (integer-accumulate-node-nondigit-edge n)))
              (cons (edge-target e) (edge-mode e))))]]
  REPLACE [[            (let ((e (integer-accumulate-node-nondigit-edge n)))
              (cons (edge-target e) 'advance)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the delimiter is re-read with no action anywhere in the path: interpreter stopped at sawx")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.field.chez.source
  LABEL "compile: the emitted non-digit edge always advances, ignoring its declared mode"
  # The emitter's copy of the same decision. Written as a tautology rather than
  # by deleting the branch, so the mutation changes WHICH arm is rendered without
  # changing the shape of the code around it.
  FIND [[                 " (if (eq? (cdr nd) 'advance)]]
  REPLACE [[                 " (if (eq? (car nd) (car nd))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the delimiter is re-read with no action anywhere in the path: generated stopped at sawx")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the accumulate determinism lane (pass 50) ---------------------------------
#
# A pass of its own because the verify command is a different program, and the
# ONE mutation in it is one no behavioural lane can catch: it reorders the two
# uppercase/lowercase arms of the emitted base 16 digit `cond`. The ranges are
# disjoint, so every input decodes to the same digit and every differential,
# property and position-kind lane passes -- the emitted BYTES change, and the
# committed golden is the only thing that looks at those.
#
# That is the whole argument for this golden, made falsifiable.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-accumulate-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.determinism.accumulate.chez.source
  LABEL "compile: the emitted base 16 digit cond tries uppercase before lowercase"
  FIND [[                            " ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"
                            " ((and (>= b 65) (<= b 70)) (+ 10 (- b 65)))"]]
  REPLACE [[                            " ((and (>= b 65) (<= b 70)) (+ 10 (- b 65)))"
                            " ((and (>= b 97) (<= b 102)) (+ 10 (- b 97)))"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted bytes equal the committed golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the diagnostic census (pass 51) ------------------------------------------
#
# This pass is why BYTE_MACHINE_SOURCE_ROOT is set to ${STAGE_DIR}/src at the top
# of this file: the census READS the source it is asserting about, so it must
# read the staged copy the mutation was applied to. Pointed at the pristine tree
# it would compare a file with itself and report every mutation here as caught.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/diagnostic-census-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "ir: an eighth field operation is declared with no operand schema row"
  # The drift the row exists for, and measured caught by the census ALONE -- the
  # two tables live in different files, written under different rules, and
  # nothing else compares them. verify.sls's own comment at the schema lookup
  # calls a mismatch "unreachable through the public API": a closed-set claim
  # made in prose, which this row turns into a check.
  FIND [[(define field-operations '(store clear increment decrement add set-mask clear-mask))]]
  REPLACE [[(define field-operations '(store clear increment decrement add set-mask clear-mask frobnicate))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the fourteen names agree across the two files: declared names equal tabulated names")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: pass-declarations is never run"
  # The whole pass, dropped from verify-machine's
  # append. Eight of the census's twenty-four fixtures then find no diagnostic at
  # all, so this is caught by a COMPARISON naming a missing code rather than by a
  # raise from wherever the walk happens to stop.
  # The following line rides along in both halves: the runner refuses an empty
  # REPLACE, so the pass is dropped by rewriting the pair rather than by deleting
  # a line. The following line is `pass-spans`, which its sibling below drops
  # the same way.
  FIND [[                                  (pass-declarations machine)
                                  (pass-spans machine)]]
  REPLACE [[                                  (pass-spans machine)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "duplicate-callback-declaration is emitted")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: pass-spans is never run"
  # The same shape as its sibling above: the whole pass
  # dropped from verify-machine's append. All four span fixtures then find no
  # diagnostic at all, so this is caught by a COMPARISON naming missing codes
  # rather than by a raise from wherever the walk happens to stop. The following
  # line rides along in both halves; the runner refuses an empty REPLACE.
  FIND [[                                  (pass-spans machine)
                                  (pass-overlap machine)]]
  REPLACE [[                                  (pass-overlap machine)]]
  EXPECT_STATUS 1
  # Measured: each of the four span codes has a fixture, so the per-code loop
  # fails four times by name before the summary row does. Pinned on one of them,
  # which is what attributes this to the PASS rather than to a fixture.
  EXPECT_OUTPUT_MATCHES "inconsistent-span-state is emitted -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: an emission site is relabelled with another existing code"
  # The per-code site counts, which is the half of the census that notices a code
  # moving rather than appearing. Behavioural lanes also redden here -- a
  # relabelled site reports the wrong code to a fixture that names it -- but the
  # record pinned is the census's own count row, which is what attributes the
  # failure to the site table rather than to any one fixture.
  # The site is the single `eof-reachable-stop` emission.
  FIND [[(make-diagnostic/path 'eof-reachable-stop (node-name n)]]
  REPLACE [[(make-diagnostic/path 'zero-progress-cycle (node-name n)]]
  EXPECT_STATUS 1
  # "a path-bearing site is relabelled to a non-path code" ALSO reddens this
  # case (it relabels a path site too), so the bare case name would resolve to
  # two mutants. Pinned instead on the count row unique to THIS mutant -- it
  # relabels to `zero-progress-cycle`, so that code reads 2; the sibling
  # relabels to `duplicate-name` and leaves `zero-progress-cycle` at 1.
  EXPECT_OUTPUT_MATCHES
    "the code set and the per-site counts match the pinned table: zero-progress-cycle -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a new diagnostic code appears with no fixture and no pinned row"
  # The RATCHET itself, which is the census's whole reason to exist. This is what
  # a change adding a code looks like to the suite: the code set
  # derived from the source no longer matches the pinned table, AND the
  # source-derived loop finds a code with no machine that emits it. Both layers
  # fire, which is deliberate -- the pinned table alone would let a code be
  # accounted for on paper without ever being produced.
  FIND [[(make-diagnostic 'unreachable-node (node-name n) "node is unreachable")]]
  REPLACE [[(make-diagnostic 'unreachable-nodes (node-name n) "node is unreachable")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no source code lacks a fixture")

# --- the census path row's two directions -----------------------------------
# A mutation is witnessed only by its own SPEC lane's program, so these two run
# on the diagnostic-census lane: one makes a path site pathless (the per-site
# count moves), the other relabels a path site to a non-path code (the code set
# moves). Together they cover both halves of the rule that exactly the
# path-bearing codes are emitted through a path constructor.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a path-bearing site is made pathless"
  # The two constructors have the same arity, so this compiles and the site's code stays path-bearing while its constructor stops carrying a path -- the half of the rule that keeps a new site under a path-bearing code from shipping pathless.
  FIND [[(make-diagnostic/path 'zero-progress-cycle (node-name n)]]
  REPLACE [[(make-diagnostic/declarations 'zero-progress-cycle (node-name n)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "make-diagnostic/path sites -- expected 11, got 10")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a path-bearing site is relabelled to a non-path code"
  # The row's other half ('no other site passes a path'): a non-path code rides a path constructor. Separable from 'an emission site is relabelled' -- which relabels WITHIN the path set -- by the got, which carries `duplicate-name`.
  FIND [[(make-diagnostic/path 'eof-reachable-stop (node-name n)]]
  REPLACE [[(make-diagnostic/path 'duplicate-name (node-name n)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the codes emitted through a path constructor equal the declared policy -- expected \\(eof-reachable-stop eof-zero-progress-cycle inconsistent-span-state invalid-span-state non-eof-into-finish span-active-at-exit span-active-at-pause zero-progress-cycle\\), got \\(duplicate-name")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the kind x position matrix (pass 52) -------------------------------------
#
# The matrix's value is BREADTH, not unique catches: it drives
# every node kind through every structural position, so a newly added kind is
# exercised in all sixteen positions without anyone writing sixteen fixtures.
# Most single-kind omissions it would catch are also caught by some existing
# lane -- measured, and said plainly rather than dressed up.
#
# What it catches ALONE is the ratchet below, and that is the point.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/kind-position-census-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "ir: node? admits a kind the matrix's table does not cover"
  # THE RATCHET. `node?`'s disjunct list IS the closed set of node kinds, and
  # the matrix derives its coverage from it rather than from a list in the test
  # -- a list in the test would be one more census that goes stale. When a node
  # kind is added, this row goes red BEFORE any fixture does, and the sixteen
  # positions are then exercised for it by construction.
  #
  # Measured caught by the matrix ALONE: no other lane in the tree notices.
  FIND [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x)))]]
  REPLACE [[        (integer-accumulate-node? x) (callback-node? x)
        (span-start-node? x) (span-end-node? x) (counted-consume-node? x) (stop-node? x)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the same fourteen kinds -- expected")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "ir: node-source-label loses an arm"
  # The SECOND per-kind census in ir.sls the matrix derives from the file.
  # Deleting an arm shrinks the cond's predicate set by one, and the row's count
  # check says so by comparison -- before any fixture for a missing kind
  # exists, which is the point of deriving it. The sibling `#f`-arm mutant in
  # the ir pass leaves the predicate set intact and cannot redden this row; the
  # two are separate decisions. This row's set-equality check is labelled "arm
  # predicates equal node?'s disjuncts" and NOT "the same ... kinds": a label
  # containing the ratchet pin's substring would let this mutant satisfy that
  # pin.
  FIND [[          ((stop-node? x) (stop-node-source-label x))
          ((error-node? x) (error-node-source-label x))]]
  REPLACE [[          ((error-node? x) (error-node-source-label x))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and there are fourteen of them -- expected 14, got 13")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a zero-width edge role loses its label"
  # The position drift row is NOT blind under this suite, although the census
  # reads the STAGED tree, so a mutation deleting a role deletes it from the
  # code AND from the set derived in the test. The derived set is compared
  # against `role->positions`, which is DECLARED in the test file, and a
  # mutation rewrites only the file its own FILE names -- so the mutated
  # verifier meets an unmutated mapping and the two disagree.
  #
  # This pin is the proof. Renaming `true` breaks the derived-equals-mapped
  # assertion by a COMPARISON, naming both sides, rather than by a raise
  # somewhere downstream. Measured: caught by the census lane alone.
  FIND [[           (list (cons 'true (field-branch-node-true-target n))]]
  REPLACE [[           (list (cons 'tru (field-branch-node-true-target n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "derived roles equal the mapped roles -- expected")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: cycle and eof-reachable-stop are merged into one tier"
  # The 25-cell verdict lattice is what certifies the verdict tiers rather than
  # taking them on trust: every sibling pair, and the join must be the higher
  # tier. Merging the top two tiers collapses ten of the twenty-five cells onto
  # the wrong diagnostic -- `cycle` stops outranking `eof-reachable-stop`, which
  # is the relation a non-terminating machine depends on.
  FIND [[      (eof-reachable-stop)
      (cycle)))]]
  REPLACE [[      (eof-reachable-stop cycle)
      ()))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the join is the higher tier every time")

# --- the callback node kind's four verifier decisions ------------------------
#
# Every pin below was MEASURED by applying the edit by hand and reading which
# records the census emits, not derived from the code. Two of the four produce
# exactly one FAIL record; the other two are pinned on the record that is theirs
# alone among these mutants.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a callback node's three targets are not edges at all"
  # The whole arm, dropped from `zero-width-edges` -- the one census that
  # `node-out-edges`, `zero-width-successors` and `eof-successors` are all views
  # of. Pinned on AXIS C, deliberately: on axes A and B this mutant makes
  # `join-over` raise its own "empty zero-width join", which is a crash rather
  # than a discrimination, while axis C fails by a COMPARISON naming both sides
  # -- three positions that should report `missing-target` and report nothing.
  FIND [[          ((callback-node? n)
           (append (list (cons 'continue (callback-node-continue-target n)))]]
  REPLACE [[          ((and #f (callback-node? n))
           (append (list (cons 'continue (callback-node-continue-target n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "each reports its derived fault -- expected .*callback-pause-continuation want .missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a parked callback is classified as if the walk had flowed through it"
  # THE DECISION THE CALLBACK KIND NEEDS AND NO OTHER KIND DOES. A parser
  # parked at a callback node is parked because that callback returned pause,
  # so it resumes on its pause continuation ALONE; classifying the node itself
  # joins over the continue and branch targets too. The mutant reports
  # `eof-reachable-stop` for a stop terminal that only a feed-time `continue`
  # reaches -- a legal `stopped` feed result and no EOF path. Measured: four
  # cells, across axes A and B; pinned on the axis-A record, which no other
  # mutant in this lane emits. The mutant is "a parked callback starts its
  # walk at its own name".
  FIND [[    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (callback-node-pause-continuation n))]]
  REPLACE [[    (cond ((and (callback-node? n) (not (eq? (node-name n) (machine-entry m))))
           (node-name n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "callback-branch stop want .. got .eof-reachable-stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a callback node's branch edges borrow the continue role"
  # The role VOCABULARY, one level finer than the sibling above: the three edges
  # carry three callback-outcome labels, and collapsing two of them is
  # invisible to reachability and to both terminal rules. Caught only by A',
  # which compares the roles derived from this file against the mapping declared
  # in the test -- one FAIL record, measured.
  FIND [[                   (map (lambda (b) (cons 'branch (cadr b)))]]
  REPLACE [[                   (map (lambda (b) (cons 'continue (cadr b)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "derived roles equal the mapped roles -- expected .*got .alternative case continuation continue digit")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the callback kind"
  # A half-fix: the WALK finds the cycle, nothing reports it, and a callback
  # that continues into itself verifies clean and then invokes its callback
  # forever in both lanes. Its own record is the pause-continuation cell, where
  # the mutant keeps the EOF cycle and loses the feed one -- a record no other
  # mutant here emits.
  FIND [[                                         (integer-accumulate-node? n)
                                         (callback-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (integer-accumulate-node? n)
                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  # The bare cell prefix "callback-pause-continuation advance want" is also
  # emitted by "the parked set loses the callback disjunct" (it moves the same
  # cell's verdict). The whole measured axis-B record is unique to this mutant
  # -- collision set EMPTY.
  EXPECT_OUTPUT_MATCHES
    "every position pointed at itself .axis B..each self-reference matches its derived verdict: each matches its derivation -- expected .., got ..callback-pause-continuation advance want .eof-zero-progress-cycle zero-progress-cycle. got .eof-zero-progress-cycle.. .callback-branch advance want .zero-progress-cycle. got ... .callback-continue advance want .zero-progress-cycle. got ....")

# The span kinds' single successors. Each arm is its own mutation because axis
# C names the position that failed.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a span-start node's successor is not an edge"
  FIND [[          ((span-start-node? n) (list (cons 'next (span-start-node-next n))))]]
  REPLACE [[          ((span-start-node? n) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "each reports its derived fault -- expected .*span-start-next want .missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: a span-end node's successor is not an edge"
  FIND [[          ((span-end-node? n) (list (cons 'next (span-end-node-next n))))]]
  REPLACE [[          ((span-end-node? n) '())]]
  EXPECT_STATUS 1
  # The span end is in the parked set, so it is a walk START; with no
  # out-edge, `eof-terminal`'s zero-width join is empty and RAISES before any
  # verdict is compared, and the pin names that raise.
  #
  # Its span-start sibling above ALSO raises, but only on axis A: at
  # `span-start-next` the span start is not a walk start, so axis C still reaches
  # its value comparison. The axis-C RAISE is therefore this mutant's alone, and
  # that is the line pinned.
  EXPECT_OUTPUT_MATCHES
    "a target naming no node .axis C..every position reports the resolution fault its route calls for: case raised")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: the zero-progress REPORT set excludes the span kinds"
  # The same half-fix for the span kinds: the WALK finds
  # the cycle and nothing reports it, so a span node whose successor is itself
  # verifies clean and then hangs in both lanes.
  FIND [[                                         (span-start-node? n) (span-end-node? n)
                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  REPLACE [[                                         (counted-consume-node? n))
                                     (self-cycle (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "span-start-next advance want")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.unit.kind-position-census.chez.source
  LABEL "verify: the parked set loses the callback disjunct"
  # The parked set's callback disjunct, and its only witness is in THIS
  # lane -- `verify-tests.sps` passes with the disjunct gone (measured), so a
  # pin declared in Pass 33 would ship UNCAUGHT. A mutation is witnessed only
  # by its own SPEC lane's program
  # (AGENTS.md), so it is declared here, where the axis-A cell
  # `(callback-pause-continuation stop)` loses its `eof-reachable-stop`.
  FIND [[             (callback-node? n)
             (span-end-node? n)]]
  REPLACE [[             (span-end-node? n)]]
  EXPECT_STATUS 1
  # The axis-A cell, measured. The axis-B self cell moves too
  # (`(callback-pause-continuation advance)` loses `eof-zero-progress-cycle`),
  # and one record is enough: this pin resolves once in this mutant's own FAIL
  # records and no other mutant in the pass satisfies it.
  EXPECT_OUTPUT_MATCHES
    "every kind in every position agrees with the verifier.s rules .axis A..the product is driven and every cell matches its derived verdict: and every one matches its derived verdict -- expected .., got ..callback-pause-continuation stop want .eof-reachable-stop. got ....")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the callback node executes (pass 53) -------------------------------------
#
# The differential lane is the SPEC because the emitted arm exists nowhere else:
# no other program in the tree loads a generated library containing a callback
# state. Two of the seven mutations below edit code SHARED by both lanes --
# `byte-machine-callback-step/v1`'s vocabulary and the callback-domain error
# record -- so the cross-lane comparison cannot see them at all: both lanes move
# together and agree. They are caught by that program's BY-VALUE assertions,
# which is the "agreement must stay observable" rule with a mutation behind it
# rather than a paragraph.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-callback-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback pause parks on the continue target"
  # A callback pause parks `current` PAST the invocation on the DECLARED pause
  # continuation. The two arms are textually distinct by indentation alone --
  # `parser-feed-op!`'s sits two spaces deeper than `parser-finish-op!`'s -- so
  # each is its own one-site FIND and each is its own decision.
  FIND [[                  (parser-set-current! parser (cadddr parts))]]
  REPLACE [[                  (parser-set-current! parser (cadr parts))]]
  EXPECT_STATUS 1
  # The bare check label is shared with its generated half, "compile: the
  # emitted callback pause resumes at the continue target". The two fail it
  # with the same two walks,
  # transposed -- the harness prints the generated lane as "expected" -- so the
  # DIRECTION is the discriminator, and each pin spells both walks.
  EXPECT_OUTPUT_MATCHES
    "resume then feed agrees, and the callback is not re-delivered: the two lanes agree on the whole walk -- expected ..paused 1 1 1 #f stopped. .decide. feed-ready .decide. .stopped 1 1 2 #f stopped. .decide.., got ..paused 1 1 1 #f stopped. .decide. feed-ready .decide. .stopped 0 0 1 #f stopped. .decide..")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: an EOF callback pause records the FEED pause lifecycle"
  # A pause during EOF produces `paused-finish`. Only the
  # interpreted lane is edited, so the differential sees the disagreement.
  FIND [[                (parser-set-current! parser (cadddr parts))
                (parser-set-lifecycle! parser 'paused-finish)]]
  REPLACE [[                (parser-set-current! parser (cadddr parts))
                (parser-set-lifecycle! parser 'paused-feed)]]
  EXPECT_STATUS 1
  # "compile: the emitted
  # callback arm renders an empty branch map" fails the same check with its own
  # list of disagreements. This one is the pause row's alone.
  EXPECT_OUTPUT_MATCHES
    "finish reaching a callback agrees across the lanes: and every one agrees -- expected .., got ..pause ..paused 0 0 0 #f paused-feed. 1. ..paused 0 0 0 #f paused-finish. 1...")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback pause is routed as a continue"
  # SHARED CODE: both lanes call this classifier, so both move together and the
  # cross-lane comparison stays green. Caught by the by-value case that asserts
  # the four outcomes are four DISTINCT tuples -- without which a lane pair
  # agreeing on one wrong answer for every outcome would pass.
  # The classifier is `classify-callback-result` (one `cond` serving both
  # arities) and answers the outcome object, so "routed as a continue" is
  # literally answering the continue TARGET.
  FIND [[          ((eq? r callback-pause) callback-pause)]]
  REPLACE [[          ((eq? r callback-pause) continue)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and the pause is neither -- expected a true value")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback error is recorded in the machine domain"
  # SHARED CODE again: `domain` is fixed inside one constructor, so a check
  # that only compares domain across lanes passes vacuously by construction.
  # The by-value assertion on the whole projected record is what has teeth
  # here.
  FIND [[    (vector parser-error-tag 'callback code callback-error-reason detail]]
  REPLACE [[    (vector parser-error-tag 'machine code callback-error-reason detail]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the callback-domain error carries the application.s code and callback-contract-violation: the explicit failure's application code")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "interpret: an unbound optional callback defaults to the pause continuation"
  # Unbound optional callbacks default to `continue`, resolved to a TARGET at
  # lowering time, in two independent walks -- this one and
  # `normalize-machine`'s -- so editing either is visible to the
  # differential, which is the whole reason they are not a shared helper.
  FIND [[                (else (callback-node-continue-target n)))))]]
  REPLACE [[                (else (callback-node-pause-continuation n)))))]]
  EXPECT_STATUS 1
  # The two
  # consumes-a-byte mutants below fail this check too, with a stopped tuple one
  # byte on. Taking the pause continuation leaves the parser asking for input,
  # and that tuple is this mutant's alone.
  EXPECT_OUTPUT_MATCHES
    "both lanes take the default with no closure called: the lanes agree -- expected .stopped 1 1 1 #f stopped., got .need-input 1 1 1 #f ready.")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "compile: the emitted callback pause resumes at the continue target"
  # The generated half of the first mutation in this pass. Both are needed: each
  # edits one lane, and a lane that agreed with a mutated sibling would be the
  # defect neither alone can show.
  # Anchored on the pause arm's next-state line alone (the only
  # `(num (cadr tg))`); the mutation swaps the pause next-state to continue.
  FIND [[            " " (num (cadr tg)) " off))\n"]]
  REPLACE [[            " " (num (car tg)) " off))\n"]]
  EXPECT_STATUS 1
  # Pinned like its interpreted half above: the same two walks, in the other
  # direction.
  EXPECT_OUTPUT_MATCHES
    "resume then feed agrees, and the callback is not re-delivered: the two lanes agree on the whole walk -- expected ..paused 1 1 1 #f stopped. .decide. feed-ready .decide. .stopped 0 0 1 #f stopped. .decide.., got ..paused 1 1 1 #f stopped. .decide. feed-ready .decide. .stopped 1 1 2 #f stopped. .decide..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "compile: the emitted callback arm renders an empty branch map"
  # The branch map is what a callback's decision outcome is decided by: with it
  # empty, every returned key falls to the out-of-contract path and the
  # generated lane reports the minted out-of-contract code where the
  # interpreted one takes a branch.
  FIND [[            (let join ((bs (normal-field-arguments s)) (acc ""))]]
  REPLACE [[            (let join ((bs '()) (acc ""))]]
  EXPECT_STATUS 1
  # The bare check label is shared with both consumes-a-byte mutants below,
  # which fail the same check with lists of their own. The halting decision is
  # where an empty branch map shows directly -- the generated lane errors where
  # the interpreted one stops -- and it carries no error projection, so the
  # pin does not move when that projection grows.
  EXPECT_OUTPUT_MATCHES
    "a decision that halts is ordered and stops there: the lanes agree -- expected ..note pick. error 2., got ..note pick. stopped 2.")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback invocation does not commit `current` first"
  # A callback observes `current` committed to its own node, and this is only
  # false in ONE lane: the interpreted arm passes the
  # node it is already parked on, so this write is a no-op there and the
  # generated arm passes its own `st`. Without it the emitted lane's callback
  # sees the state the FEED started in -- `start`, not `inv`.
  # The following line rides along in both halves; the runner refuses an empty
  # REPLACE.
  FIND [[    (parser-set-current! parser state)
    (parser-set-offset! parser offset)]]
  REPLACE [[    (parser-set-offset! parser offset)]]
  EXPECT_STATUS 1
  # Pinned on the generated lane's OWN wrong value, not on the bare check label:
  # its sibling below shares that label, and only the recorded tuple separates
  # them. Measured, and the harness prints the SECOND argument as "expected" --
  # here the generated lane, which reports the state the feed started in.
  EXPECT_OUTPUT_MATCHES "committed value -- expected .start 1.*got .inv 1")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback invocation does not commit the offset first"
  # The offset half of the same rule, and the same one-lane asymmetry: the
  # emitted `exec` owns `off` and writes the parser's slot only on return, so
  # without this the callback sees the offset the feed began at.
  FIND [[    (parser-set-current! parser state)
    (parser-set-offset! parser offset)]]
  REPLACE [[    (parser-set-current! parser state)]]
  EXPECT_STATUS 1
  # Its sibling's mirror: same check label, different recorded tuple.
  EXPECT_OUTPUT_MATCHES "committed value -- expected .inv 0.*got .inv 1")

# The `busy` and `poisoned` lifecycle rows. Both are REACHABLE only through a
# callback -- `busy` needs something running inside the parser and `poisoned`
# needs a callback to escape from one.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a feed does not mark the parser busy while it runs"
  # The line that makes the whole reentrancy row reachable: with it gone the
  # parser is still `ready` inside the callback, so a callback may feed the
  # parser it is running inside, contrary to what a callback is promised to
  # observe.
  # The following lines (the span mark re-anchor) ride along in both halves;
  # the runner refuses an empty REPLACE.
  FIND [[(parser-set-lifecycle! parser 'busy)
       (when (parser-active-span parser)]]
  REPLACE [[(when (parser-active-span parser)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "all six answered -- expected .busy inv 1 7")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a feed refuses a busy parser as a lifecycle violation"
  # "lifecycle violation, reentrancy, poisoned parser" are three distinct
  # codes. The mutant still raises, and still raises from the right `who`, so
  # only a pin that names the CODE can see it -- which is why the test asserts
  # per operation by who AND code rather than through one family predicate.
  FIND [[       (byte-machine-contract-violation 'parser-feed! 'reentrancy]]
  REPLACE [[       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1
  # Both lists in full: a pin stopping after the first entry of the got list
  # is also satisfied by "runtime: a feed does not mark the parser busy while
  # it runs" -- whose list starts the same way, every entry #f -- and
  # `expected .*got` could bridge to a later record. Only the FEED's code is
  # wrong here.
  EXPECT_OUTPUT_MATCHES
    "four operations, each with its own who and the reentrancy code -- expected ..parser-feed! #t. .parser-finish! #t. .parser-resume! #t. .parser-reset! #t.., got ..parser-feed! #f. .parser-finish! #t. .parser-resume! #t. .parser-reset! #t..")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: reset has no busy guard"
  # Reset's lifecycle row, and the one operation whose `busy` cell is not its
  # `poisoned` cell. Without the guard reset is five unconditional mutations,
  # so a callback could reset the parser it is running inside and the feed
  # would continue from the entry.
  FIND [[    (when (eq? (parser-lifecycle parser) 'busy)
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  REPLACE [[    (when #f
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  EXPECT_STATUS 1
  # Pinned like the feed row above, for the same bridge and the same sibling:
  # only RESET's entry is wrong here.
  EXPECT_OUTPUT_MATCHES
    "four operations, each with its own who and the reentrancy code -- expected ..parser-feed! #t. .parser-finish! #t. .parser-resume! #t. .parser-reset! #t.., got ..parser-feed! #t. .parser-finish! #t. .parser-resume! #t. .parser-reset! #f..")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: an escaping callback does not poison the parser"
  # An escaping callback poisons the parser. `dynamic-wind`'s after thunk runs
  # on BOTH exits, so the flag is the whole discrimination: without it the
  # normal path poisons every parser, and without the thunk nothing poisons any.
  FIND [[             (unless completed (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-feed! "unknown lifecycle"]]
  REPLACE [[             (unless #t (parser-set-lifecycle! parser 'poisoned))))))
      (else (assertion-violation 'parser-feed! "unknown lifecycle"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and it is the callback.s own condition, propagated -- expected ..raised boom. poisoned")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a poisoned parser is refused as a lifecycle violation"
  # The third of the three codes, and the same argument as the
  # reentrancy pin: the mutant raises, from the right `who`, with the wrong
  # code.
  FIND [[       (byte-machine-contract-violation 'parser-feed! 'poisoned-parser]]
  REPLACE [[       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1
  # "runtime: an escaping
  # callback does not poison the parser" fails the same check -- with the
  # reentrancy code, since its parser is left busy. The code in the condition
  # dump separates them; `[^:]*` crosses the dump's line breaks and indentation
  # but cannot reach the next record, every one of which carries a colon.
  EXPECT_OUTPUT_MATCHES
    "a poisoned parser raises parser-poisoned, and only reset reuses it: feed -- raised object did not satisfy the predicate: Exception occurred with condition components:[^:]*code: lifecycle-violation")

# A callback CONSUMES NO INPUT, one mutation per lane. Their records are mirror
# images -- each mutant advances its own lane's position and the other's stands
# still -- so the pins are the unbound-optional tuple with the two lanes' values
# in opposite order.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "runtime: a callback invocation consumes a byte"
  # The goto arm is the `else` of a `cond` over the outcome OBJECT and the
  # target is `o` itself. It is textually identical to the span-end arm's
  # else -- both are zero-width, which is the point -- so the FIND carries the
  # failure clause above it: `(list-ref parts 5)` in that shape is this arm's
  # alone.
  FIND [[                                       node (list-ref parts 5)
                                       (parser-offset parser) callback-failure-position)))
                 (else
                  (parser-set-current! parser o)
                  (loop pos pk)))))]]
  REPLACE [[                                       node (list-ref parts 5)
                                       (parser-offset parser) callback-failure-position)))
                 (else
                  (parser-set-current! parser o)
                  (loop (+ pos 1) pk)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the lanes agree -- expected .stopped 1 1 1 #f stopped., got .stopped 2 2 1")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.callback.chez.source
  LABEL "compile: the emitted goto jump consumes a byte"
  # All three zero-width arms build their jump through `render-goto-clauses`,
  # so the anchor is in the renderer, on the clause that actually runs, and the
  # label says "goto" rather than "callback". The `%dispatch` fallback clause
  # is not the anchor: no construction reaches it, so mutating it would survive
  # and this check would cover nothing.
  FIND [[                   (string-append acc (if (string=? acc "") "" " ")
                                  "((eqv? " expr " " (num (car ts)) ") "
                                  (zero-width-jump (car ts)) ")"))))))]]
  REPLACE [[                   (string-append acc (if (string=? acc "") "" " ")
                                  "((eqv? " expr " " (num (car ts)) ") "
                                  "(%s" (num (car ts)) " (+ pos 1) " (num (car ts))
                                  " off pk)" ")"))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the lanes agree -- expected .stopped 2 2 1 #f stopped., got .stopped 1 1 1")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the span kinds execute (pass 54) -----------------------------------------
#
# The differential lane is the SPEC for the same reason the callback pass's
# is: no other program in the tree loads a generated library containing a span
# state. What is different here is what the lane can SEE. A callback outcome
# shows up in a parser result; a span fragment does not -- two lanes can agree
# on every result tuple while handing the application different bytes. So the
# pins below are
# anchored on the FRAGMENT TRACE, and three of them (the emitted span start, the
# emitted span end, and the emitted completion substep) would otherwise resolve
# to the same "the lanes agree" line. The fixture asserts the GENERATED lane's
# trace and active span as values for exactly that reason, and each pin names
# the wrong value rather than the disagreement.
#
# Six mutations edit code SHARED by both lanes -- the fragment step's empty
# check, the boundary flush, the feed's mark re-anchor, reset's span clear -- so
# both lanes move together and a cross-lane comparison cannot see them at all.
# Those are pinned on recorded VALUES, never on agreement.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-span-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the flush delivers an empty fragment instead of suppressing"
  # `>= from to` lives in span-fragment-suppress-empty, which the FLUSH alone
  # reaches (the span ends deliver-if-never through the public step).
  # Inverting it to `> from to` makes an empty flush -- one that accumulated
  # nothing this slice -- deliver a zero-length fragment. Witnessed by the
  # MID trace of "a flush that finds nothing delivers nothing, ...", `()` in
  # the baseline (the flush found nothing and delivered nothing); the FINAL trace
  # is unchanged, because the span end then suppresses the now-set flag, so only
  # the mid trace separates them.
  FIND [[      (if (or (>= from to) (unbound-callback? f))]]
  REPLACE [[      (if (or (> from to) (unbound-callback? f))]]
  EXPECT_STATUS 1
  # `.#vu8...` would match any bytevector, and "interpret loop: a span start
  # records the mark at 0 instead of the cursor" fails this check with
  # `(#vu8(65))`. `[)][)]` says the delivered fragment is EMPTY, which is this
  # mutant's whole defect.
  EXPECT_OUTPUT_MATCHES "the flush delivered nothing -- expected .., got .#vu8.[)][)]"
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: an empty span is suppressed instead of delivered once"
  # The public span-end step delivers an empty fragment
  # exactly when `from == to` and the span has delivered nothing. Weakening that
  # guard to `< from to` makes the arm unreachable (arm 1 already took `< from
  # to`), so an empty span delivers nothing. Witnessed by the AZ empty span,
  # which must deliver one empty fragment then complete.
  FIND [[            ((and (= from to) (not (parser-span-delivered? parser)))]]
  REPLACE [[            ((and (< from to) (not (parser-span-delivered? parser)))]]
  EXPECT_STATUS 1
  # Anchored on the AZ case NAME, not the bare check label: the same "one empty
  # fragment, then the completion" check fires for the EOF-chain span and the
  # carried-EOF cases too (this mutant suppresses every empty delivery), so the
  # case name is what resolves the pin to AZ alone.
  EXPECT_OUTPUT_MATCHES "AZ opens and closes having delivered nothing: one empty fragment, then the completion -- expected .#vu8.. complete., got .complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: parser-finish! does not re-anchor the span mark to 0"
  # parser-finish! re-anchors an active span's mark to 0
  # before the EOF chain runs, so a span carried from a feed and closed empty at
  # EOF sees from==to and delivers its one empty fragment uniformly. Dropping the
  # re-anchor leaves the carried mark (the opening feed's start), so from>to and
  # the span end suppresses -- announcing the empty span only when the last feed
  # happened to start at 0. Witnessed by the nonzero-start carried-empty case,
  # whose whole point is slicing-independence.
  FIND [[       (when (parser-active-span parser)
         (parser-set-span-mark! parser 0))
       (let ((completed #f))]]
  REPLACE [[       (let ((completed #f))]]
  EXPECT_STATUS 1
  # Pinned on the two-span case, which exists for it. On the carried-empty
  # cases, which each hold ONE empty span, every record this mutant emits is
  # emitted byte for byte by "runtime: an empty span is suppressed instead of
  # delivered once": that one span is silenced by both. The containment is the
  # fixture's, not the decisions': on a trace holding an empty span closed
  # inside the feed AND one carried into finish, this mutant silences only the
  # second and the sibling both. The two-span case compares BOTH lanes as one
  # value -- a skipped span close in either lane leaves the delivered flag set
  # and silences the second span exactly as this does, but in one lane only.
  # Measured: seven mutants in this pass redden the case, and they report
  # seven different pairs.
  EXPECT_OUTPUT_MATCHES "each empty span delivers once, in both lanes -- expected ..#vu8.. complete #vu8.. complete. .#vu8.. complete #vu8.. complete.., got ..#vu8.. complete complete. .#vu8.. complete complete.."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: a span-end fragment does not mark the span delivered"
  # span-fragment-deliver! sets the delivered flag, so a
  # span split across feeds whose FINAL fragment is empty suppresses it (the flush
  # delivered the bytes and set the flag). Dropping the set leaves the flag clear,
  # so the empty final fragment delivers spuriously. Witnessed by the nonempty
  # split: `bc` flushed, then an empty tail that must NOT appear.
  FIND [[    (parser-set-span-delivered?! parser #t)]]
  REPLACE [[    #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "no empty tail -- expected .#vu8.98 99. complete., got .#vu8.98 99. #vu8.. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the feed-boundary flush never runs"
  # The flush runs at a feed boundary. The status guard is what selects the
  # boundary: `error` is forbidden a final fragment, `stopped`/`finished` with a
  # span active are verifier-rejected, and `paused` cannot produce a nonempty
  # one. Pointing it at `paused` disables the flush without deleting it.
  FIND [[    (if (and (eq? (parser-result-status r) 'need-input)]]
  REPLACE [[    (if (and (eq? (parser-result-status r) 'paused)]]
  EXPECT_STATUS 1
  # Its half of the pair the flush-pause mutation below also names: this mutant
  # delivers NO fragment, and the pin says so rather than resting on the status
  # line the two share.
  EXPECT_OUTPUT_MATCHES
    "separates two mutants: delivered, and reported as a pause -- expected ..#vu8.98 99.. .paused 3 3 3 #f paused-feed.., got ... .need-input 3 3 3 #f ready.."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: an open span's mark is not re-anchored at the next feed"
  # THE ONE PLACE the feed-boundary re-anchor of an open span's mark lives.
  # Each delivery also advances the mark, so the stale mark this mutant leaves
  # is the previous slice's END -- past the next span end's cursor, so that end
  # delivers NOTHING (`from > to` is suppressed). Measured by staging the
  # mutant: six cases fail, the sub-slice case among them; pinned on the
  # measured got.
  FIND [[       (when (parser-active-span parser)
         (parser-set-span-mark! parser start))
       (let ((completed #f))]]
  REPLACE [[       (let ((completed #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "bc then de, never bc twice -- expected .#vu8.98 99. #vu8.100 101. complete., got .#vu8.98 99. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the mark is re-anchored to 0 rather than to the slice start"
  # The mark is a SLICE offset, anchored at the next feed's `start`. Every
  # other case in the lane feeds a whole bytevector,
  # where `start` and `0` are the same program -- so this mutant is invisible to
  # all of them, and the sub-slice case exists only to separate the two.
  FIND [[         (parser-set-span-mark! parser start))]]
  REPLACE [[         (parser-set-span-mark! parser 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the padding is in neither fragment -- expected .#vu8.98 99. #vu8.100. complete., got .#vu8.98 99. #vu8.7 7 100. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: a full reset leaves the span state behind"
  # A reset clears span state along with the rest of the parser. Both lanes
  # move, so the pin names the accessor's value in each.
  FIND [[    (byte-machine-span-close/v1 parser)
    (vector-set! parser 8]]
  REPLACE [[    (vector-set! parser 8]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "inactive after -- expected .#f #f., got .payload payload."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "interpret loop: the span is not made inactive before the completion callback"
  # Before invoking the completion callback, execution makes the span
  # inactive. One lane only, so the cross-lane comparison catches it too -- but
  # the pin is on the VALUE, because the emitted mutation two below shares that
  # line and only the value separates them.
  FIND [[             (let ((parts (op 'span-completion-parts node)))
               (byte-machine-span-close/v1 parser)]]
  REPLACE [[             (let ((parts (op 'span-completion-parts node)))]]
  EXPECT_STATUS 1
  # The bare check label would resolve TWICE in this mutant's own output --
  # the nonempty-span case and the AZ empty-span case both carry it. The case
  # name picks one.
  EXPECT_OUTPUT_MATCHES "one feed, one nonempty fragment, then the completion: and the span is inactive afterwards -- expected #f, got payload"
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "interpret loop: a span start records the mark at 0 instead of the cursor"
  # Starting a span records the current cursor. The interpreted arm's
  # `pos` against the finish arm's literal 0 -- which is correct THERE, since the
  # finish path has no cursor, and is what makes this FIND one site.
  FIND [[               (byte-machine-span-open/v1 parser (car parts) pos (cadr parts))]]
  REPLACE [[               (byte-machine-span-open/v1 parser (car parts) 0 (cadr parts))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "one fragment then one completion -- expected .#vu8.98 99 100. complete., got .#vu8.65 98 99 100. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: a pause during the flush is reported as need-input"
  # The flush's pause is the FEED's pause: the fragment is committed
  # and the caller must resume. Reported as `need-input` the parser stays ready,
  # so the caller's `parser-resume!` raises a lifecycle violation three steps
  # later -- which the harness shows as a bare raise.
  #
  # The STATUS alone is printed BYTE FOR BYTE by "the feed-boundary flush never
  # runs" above, so a pin on it attributes the catch to neither. They part on
  # the FRAGMENT -- a flush that ran and mis-reported its status still
  # delivered `bc`, one that never ran delivered nothing -- so the lane has a
  # case asserting the PAIR, and each mutation names its own half of it.
  # Measured both ways.
  FIND [[            ((eq? o callback-pause)
             (make-parser-result 'paused (parser-result-next r)]]
  REPLACE [[            ((eq? o callback-pause)
             (make-parser-result 'need-input (parser-result-next r)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "separates two mutants: delivered, and reported as a pause -- expected ..#vu8.98 99.. .paused 3 3 3 #f paused-feed.., got ..#vu8.98 99.. .need-input 3 3 3 #f ready.."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted span start records the mark at 0"
  # The generated half of the interpreted mutation above. Both are needed: each
  # edits one lane, and a lane agreeing with a mutated sibling is the defect
  # neither alone can show.
  FIND [[            (symbol->string (car d)) ") pos " (num (cadr d)) ")\n"]]
  REPLACE [[            (symbol->string (car d)) ") 0 " (num (cadr d)) ")\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane's own fragment -- expected .#vu8.98 99 100. complete., got .#vu8.65 98 99 100. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted span end slices to the end of the feed"
  # A span end emits `[mark,cursor)`, and `cursor` is `pos` -- not `end`. The
  # difference is exactly the delimiter the span end reexecutes onto, so this
  # mutant produces a fragment one byte too long and nothing else moves.
  FIND [[" off (vector-ref cbv " (num (cadr d)) ") bv pos " cid ")))\n"]]
  REPLACE [[" off (vector-ref cbv " (num (cadr d)) ") bv end " cid ")))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "the generated lane's own fragment -- expected .#vu8.98 99 100. complete., got .#vu8.98 99 100 90. complete."
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted completion substep does not close the span"
  # The generated half of making the span inactive before completion. TWO
  # shapes are rendered here -- with and without a declared completion
  # callback -- and this is the one that calls;
  # its sibling below is the one that does not, and each needs its own witness
  # because a single machine renders only one of them.
  FIND [[                "       (begin (byte-machine-span-close/v1 psr)\n"
                "         (let ((o (byte-machine-callback-step/v2 psr " id]]
  REPLACE [[                "       (begin #t\n"
                "         (let ((o (byte-machine-callback-step/v2 psr " id]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "and its span is inactive too -- expected #f, got payload"
)

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.span.chez.source
  LABEL "compile: the emitted completion substep for a span with no callback does not close"
  # The OTHER rendered shape, and the reason the lane builds a second machine at
  # all: a span declaring no completion callback still needs the substep, whose
  # only job is then to make the span inactive. Nothing else in the tree renders
  # this arm, so without the second machine it would ship unexecuted.
  FIND [[                "       (begin (byte-machine-span-close/v1 psr)\n"
                "              " (zero-width-jump (normal-field-targets s)) "))\n")]]
  REPLACE [[                "       (begin #t\n"
                "              " (zero-width-jump (normal-field-targets s)) "))\n")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "#vu8.98 99 100.. payload., got "
)

# --- the span-topology oracle: a universal, made a table ---------------------
#
# "Every invalid span topology is rejected" is a universal over a set nothing
# else writes down, so the lane writes it down: eleven rows, each with the
# verdict DERIVED from the span rules before it was run, and the count as
# the sentinel. These four break one arm of `span-node-diagnostics` each, and
# every one of them turns a rejected row green rather than turning a green row
# red -- which is the direction a census can otherwise miss entirely.

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: a span re-entering itself is not rejected"
  FIND [[               ((and (pair? state) (eq? (cadr state) s))
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "span re-entry: this span is already open"
                                            path)))]]
  REPLACE [[               ((and (pair? state) (eq? (cadr state) s)) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "reentry want .invalid-span-state. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: ending the wrong span is not rejected"
  FIND [[               ((pair? state)
                (list (make-diagnostic/path 'invalid-span-state (node-name n)
                                            "wrong end: a different span is open"
                                            path)))]]
  REPLACE [[               ((pair? state) '())]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "wrong-end want .invalid-span-state. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: a finish reachable with a span active is admitted"
  # `finish` is distinguished from `error` precisely so
  # this arm can name one and not the other, and the table's `error-inside`
  # row is what proves the distinction still costs something: with `finish`
  # dropped the row below goes green while `error-inside` stays green, so only
  # the FINISH row moves.
  FIND [[      ((and (pair? state) (or (stop-node? n) (finish-node? n)))]]
  REPLACE [[      ((and (pair? state) (stop-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "finish-inside want .span-active-at-exit. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.differential.span.chez.source
  LABEL "verify: a callback invocation inside a span is admitted"
  # "An explicit pause node or event/decision callback invocation" inside a
  # span is one rule, and this arm is where the two halves are one `or`.
  # Replacing the callback half with a kind that can never carry the state --
  # a span END sets the state to `none` on the way out -- keeps the arm shaped
  # like itself and makes the callback row green.
  FIND [[      ((and (pair? state) (or (pause-node? n) (callback-node? n)))]]
  REPLACE [[      ((and (pair? state) (or (pause-node? n) (span-end-node? n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "callback-inside want .span-active-at-pause. got .."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: reset refuses a POISONED parser instead of resetting it"
  # Reset is the ONE operation a poisoned parser may run -- every other cell
  # in the lifecycle table's `poisoned` row raises -- so this mutant is
  # the plausible wrong reading of the row, not a strawman. Nothing else in the
  # tree drives reset on a poisoned parser: the callback lane poisons a
  # SPAN-LESS machine and never resets it, so this pin has no sibling.
  #
  # The recorded signature is a RAISE rather than a value mismatch, and the pin
  # names the case, which is what keeps it from being a bare nonzero exit.
  FIND [[    (when (eq? (parser-lifecycle parser) 'busy)
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  REPLACE [[    (when (memq (parser-lifecycle parser) '(busy poisoned))
      (byte-machine-contract-violation 'parser-reset! 'reentrancy]]
  EXPECT_STATUS 1
  # The FAIL grammar is `FAIL <group>.<case>: <what>`, so the case name is
  # followed by `: ` and the GROUP name is followed by a bare `.`. A pin with
  # `.*:` between them is rejected by the suite as "caught by coincidence" --
  # the greedy wildcard swallows the colons inside the group name. Anchor on
  # the case, which is unique.
  EXPECT_OUTPUT_MATCHES "reset is accepted, clears the span, and the parser is reusable: case raised"
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.span.chez.source
  LABEL "runtime: the FINISH path's span completion never closes the span"
  # The interpreted finish path's own `byte-machine-span-close/v1`: the other
  # two pins on that call are reset's (four-space indent) and the FEED loop's
  # (fifteen). This is the thirteen-space one, and the EOF group's fixture is
  # one whose span is closed by a node on the EOF chain after a feed opened it.
  FIND [[          ((span-completion)
           (let ((parts (op 'span-completion-parts node)))
             (byte-machine-span-close/v1 parser)]]
  REPLACE [[          ((span-completion)
           (let ((parts (op 'span-completion-parts node)))]]
  EXPECT_STATUS 1
  # "the lanes agree" in
  # this case is also reddened by "interpret loop: a span start records the mark
  # at 0 instead of the cursor", "compile: the emitted span start records the
  # mark at 0" and "compile: the emitted completion substep does not close the
  # span". The same case's by-value check -- the span still active after finish
  # -- names this decision and no sibling's.
  EXPECT_OUTPUT_MATCHES "the fragment comes from the feed and the completion from finish: and the span is inactive at the end -- expected #f, got payload"
)

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")



# --- input retention ----------------------------------------------------------
#
# Follows the span pass (the fifty-fourth) and is the FIFTY-FIFTH.
#
# A pass whose SPEC reads something no result and no trace can show: what
# is still REACHABLE from a live parser after `parser-feed!` returns.
#
# The three mutations below are the two halves of the retention argument.
# The first makes the runtime retain and layer 1 must see it. The other two make
# an EXEMPT carrier stop carrying, and layer 3 must see that too -- because an
# oracle asserting "nothing is reachable" would pass a runtime that quietly
# dropped the application's own context, and those three carriers are the
# application's to keep.
#
# Layer 2, the negative control, carries no mutant and does not need one: it is a
# FIXTURE that retains on purpose, and `retention-tests.sps` is not a mutation
# target. (Not "no fixture in `test/common` is" -- `property-differential-tests.sps`
# is one, above. The narrower claim is the true one.) Its control is the
# two-directional assertion: layer 1 says "gone" and layer 2 says "retained"
# about the same FIXTURE SHAPE -- not about the same probe; they are two
# `retained?` calls over two fixtures and two bytevectors. An instrument
# answering a constant still fails one of them, and the reason is the shape
# and not the object.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/retention-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.retention.chez.source
  LABEL "runtime: the fed bytevector is stored in the parser and survives the return"
  # The no-retention rule itself. The stored-error slot is the one that makes
  # this a UNIQUE witness rather than a duplicate of some other pass: it is not
  # read on a successful stop, `parser-stored-error` is not exported, and no
  # other lane in the tree looks at what a parser still reaches. Every other
  # suite stays green under this mutant.
  FIND [[(parser-set-lifecycle! parser 'busy)
       (when (parser-active-span parser)]]
  REPLACE [[(parser-set-lifecycle! parser 'busy)
       (parser-set-stored-error! parser bv)
       (when (parser-active-span parser)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "gone in both lanes -- expected ..interpreted . #f. .generated . #f.., got ..interpreted . #t."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.retention.chez.source
  LABEL "runtime: a callback failure's detail is dropped instead of carried"
  # Layer 3's second carrier, and the arm an oracle easily gets wrong: one
  # that excludes only the user-context slot reports a false violation the
  # first time a fixture callback fails with a detail holding its own slice.
  # With the detail dropped the parser stops retaining and the arm
  # reads "gone" -- which is the direction that looks like GOOD news.
  FIND [[    (vector callback-failure-tag code detail)]]
  REPLACE [[    (vector callback-failure-tag code #f)]]
  EXPECT_STATUS 1
  # *** THE CASE NAME IS PART OF THE PIN. *** "retained, and permitted" is the
  # `<what>` of TWO checks in this lane -- the user-context arm and this one --
  # with byte-identical expected values, so a pin starting at the `<what>` also
  # matches the OTHER arm's failure, including mutation 3's. The FAIL grammar is
  # `FAIL <group>.<case>: <what> -- <detail>`, and this pass's own standard is
  # that a sound pin resolves to exactly ONE (case, check) pair.
  EXPECT_OUTPUT_MATCHES "a slot walk misses: retained, and permitted -- expected ..interpreted . #t. .generated . #t.., got ..interpreted . #f. .generated . #f."
)

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.retention.chez.source
  LABEL "runtime: the interpreted parser drops the user context"
  # Layer 3's first carrier, and the mutant is deliberately ONE-LANE: only the
  # `op` arm is edited, so the recorded `got` reads
  # `((interpreted . #f) (generated . #t))`. That asymmetry is the assertion --
  # the two lanes reach `user-context` by different routes (`make-parser` builds
  # both vectors here, but only this arm's literal moves), and a pin that
  # mutated both would not show it.
  # make-parser is a case-lambda and the op vector carries slot 17 (`merged`,
  # the canonical initials), so the arm ends `... #f #f merged)))`; the
  # mutation edits only the op arm's user-context.
  FIND [[                    user-context #f #f 0 #f #f merged)))]]
  REPLACE [[                    'not-the-input #f #f 0 #f #f merged)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "user context may retain it, and does: retained, and permitted -- expected ..interpreted . #t. .generated . #t.., got ..interpreted . #f. .generated . #t."
)

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the counted differential (pass 56) ---------------------------------------
#
# Both lanes over the counted machine, every check labelled by LANE, so a pin
# names which lane went wrong and is caught by the EXPECTED VALUE's record, never
# by the lanes' disagreement (with one FILE per mutation and a runtime arm that
# serves the interpreted lane alone, no mutant here can make both lanes agree
# on a wrong value).
# The emitter's min, subtraction and completion-order decisions live here rather
# than in unit.compile, because only an executing lane with a surplus or exact
# body can see them; the emitter's exhaustion-first twin of the runtime pin in
# the position-kind pass lives here because that pass's labels carry no lane.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-counted-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the reached declaration walk ignores counted consume"
  # The machine whose ONLY default-EOF consumer is the counted consume: the
  # declaration leaves the errs table and render-machine raises on a machine the
  # verifier accepted -- the same defect the field pass pins for the
  # accumulate kind. Dropping counted-consume (keeping keyword-table, on its
  # continuation line) is the edit.
  FIND [[                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))]]
  REPLACE [[                                                      '(dispatch accumulate
                                                        keyword-table))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the only-consumer machine renders, loads and runs: case raised")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm commits (- end pos) instead of the min"
  FIND [[            "                (let ((n (min v (- end pos))))\n"]]
  REPLACE [[            "                (let ((n (- end pos)))\n"]]
  EXPECT_STATUS 1
  # Measured: the projection ends with the abandoned span and its offset,
  # `#f #f` here, so the pin spells them.
  EXPECT_OUTPUT_MATCHES "generated: surplus into a rejection -- expected ..error 5 5 .machine unexpected-byte .unexpected byte. reject 5 byte #f #f. error reject 0.., got ..need-input")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm never subtracts"
  FIND [[            "                  (vector-set! fieldv " slot " (- v n))\n"]]
  REPLACE [[            "                  (vector-set! fieldv " slot " v)\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: exact body -- expected ..need-input 5 5 #f ready comma 0.., got ..need-input 5 5 #f ready comma 3..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm continues only when input remains"
  # The count-completion-wins mutant in the generated
  # lane: the exact body parks on `body` with a zero count instead of continuing
  # to the delimiter dispatch in the same feed.
  FIND [[            "                  (if (= n v)\n"]]
  REPLACE [[            "                  (if (and (= n v) (< (+ pos n) end))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: exact body -- expected ..need-input 5 5 #f ready comma 0.., got ..need-input 5 5 #f ready body 0..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "compile: the emitted counted arm tests exhaustion before the zero count"
  # The runtime arm's twin is pinned in the position-kind pass; this one needs a
  # lane-labelled witness, and the feed-order witness is exactly that.
  FIND [[            "         (cond ((= v 0) " (zero-width-jump next-id) ")\n"]]
  REPLACE [[            "         (cond ((and (= v 0) (< pos end)) " (zero-width-jump next-id) ")\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: parked on the delimiter after 0: -- expected comma, got body")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "runtime: the counted arm re-asks the op after a partial commit"
  # Loops back through the node instead of parking: the op is asked again over
  # the exhausted slice, answers (0 . #f), and the parser parks with the same
  # result -- every tuple lane agrees, and only the counting witness sees the
  # second message: one count-step per feed, in the interpreted lane.
  FIND [[                          (make-parser-result 'need-input (+ pos n) (- (+ pos n) start)
                                              (parser-offset parser) #f))))))]]
  REPLACE [[                          (loop (+ pos n) 'boundary))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "one count-step per feed -- expected 1, got 2")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.counted.chez.source
  LABEL "runtime: the counted finish arm asks the EOF route before the zero count"
  # A zero count transitions before the EOF route is asked, at finish too:
  # the entry-zero machine's fresh parser must
  # transition to `next` and report the empty-body error, not the default EOF.
  FIND [[             (if (cdr r)
                 (begin (parser-set-current! parser (cdr r)) (loop (cdr r) pk))
                 (take-eof-route! node loop))))]]
  REPLACE [[             (take-eof-route! node loop)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "interpreter: the finish reports the empty-body error -- expected .empty body rejected., got .unexpected end of input.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the counted determinism lane (pass 57) -----------------------------------
#
# A pass of its own because the verify command is a different program, and its
# ONE mutation is one no behavioural lane can catch: the emitted position kind
# spelled with a quote mark instead of `(quote …)`. The reader turns both into
# the same datum, so the structural walk in compile-tests cannot see it either;
# the emitted BYTES change, and the committed golden is the only thing that
# looks at those -- the accumulate lane's argument, made falsifiable once more.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-counted-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.counted.chez.source
  LABEL "compile: the emitted counted arm spells its position kind with a quote mark"
  FIND [[            "                      (%s" (num next-id) " (+ pos n) " (num next-id) " (+ off n) (quote boundary))\n"]]
  REPLACE [[            "                      (%s" (num next-id) " (+ pos n) " (num next-id) " (+ off n) 'boundary)\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the emitted bytes equal the committed golden: golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the counted-span differential (pass 58) ----------------------------------
#
# The only decision this lane witnesses that no other lane does is the
# completion's PLACEMENT: the completion event lands in the feed that
# delivered the last body byte. The two mutants that move it are the
# count-completion-order mutants also declared under unit.interpret and
# differential.counted on other records; here each is pinned on the placement
# record per lane, by expected value -- a symmetric wrong reading puts the
# completion in the `,` feed in BOTH lanes and agrees with itself, so neither
# pin could ever rest on lane disagreement.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-counted-span-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.counted-span.chez.source
  LABEL "interpret: count-step continues only when input remains -- the completion lands in the delimiter's feed"
  FIND [[                (cons k (if (= k v) (counted-consume-node-next n) #f))))))]]
  REPLACE [[                (cons k (if (and (= k v) (< (+ pos k) end)) (counted-consume-node-next n) #f))))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "interpreter: byte-at-a-time per-feed events, count and span -- expected .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1. complete. 0 #f. ... 0 #f.., got .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1.. 0 sp. ..complete. 0 #f..")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.counted-span.chez.source
  LABEL "compile: the emitted counted arm continues only when input remains -- the completion lands in the delimiter's feed"
  FIND [[            "                  (if (= n v)\n"]]
  REPLACE [[            "                  (if (and (= n v) (< (+ pos n) end))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "generated: byte-at-a-time per-feed events, count and span -- expected .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1. complete. 0 #f. ... 0 #f.., got .... 3 #f. ... 3 sp. ...data 1.. 2 sp. ...data 1.. 1 sp. ...data 1.. 0 sp. ..complete. 0 #f..")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 59: the printer, the fixture saver, the minimizer -------------------
# The FIFTY-NINTH pass. It runs property-fixture-tests.sps -- the deliberate-
# failure probe. Three mutations are CAUGHT, each by a distinct check whose
# failure signature is asserted (not a bare nonzero exit, the family least
# visible by exit status): the printer emitting another kind's constructor,
# the saver writing a non-reproducing fixture, and the minimizer accepting a
# reduction that no longer disagrees. The fourth, the 64-emission bound, is a
# declared SURVIVOR: the probe measurably minimizes in FOUR emissions, so no
# probe here reaches the bound -- witnessing it would need a machine with >64
# verifying, still-disagreeing reductions, which this lane does not construct.
#
# Sweep over the three caught mutants: the per-pin match-count matrix is a
# clean diagonal. On the green tree all three regexes match ZERO records; each
# mutant matches its OWN pin's regex exactly ONCE and the other two ZERO times
# (pin1 R1=1/R2=0/R3=0, pin2 0/1/0, pin3 0/0/1). The printer pin matches the
# printer group's lone "case raised" render-rejection; the saver pin the RAW
# reruns-disagree check (distinct from the MINIMIZED one's label); the
# minimizer pin the in-memory minimized-still-disagrees check. None of the
# suite's other regexes contains or is contained by these three, none matches
# any fixture check label, and no regex here uses `.*` or ends at `got`.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-fixture-tests.sps")

# The printer's arm for one KIND emitting another kind's constructor. The round
# trip catches it: a stop reprinted as a finish makes a byte edge target a finish
# terminal, which the verifier REJECTS, so render-machine of the reprinted machine
# raises inside the round-trip case. (A KIND swap is caught one step before
# any fingerprint comparison, at verify -- the reprinted machine does not
# verify, a stronger catch than a fingerprint mismatch.)
# COUPLING (measured, seed 20260823): this render-rejection signature holds because
# the first accepted machine carrying a stop node reaches that stop over a BYTE edge,
# so reprinting it as a finish trips `non-eof-into-finish`. Were the first such stop
# EOF-only-reachable, the reprint would VERIFY and the round trip would fail instead
# by byte-identity ("... machine <i> ... expected a true value"). The signature is
# thus tied to the committed seed and generator, as the differential pins' machine
# indices are; a generator change that flips it makes this pin read UNCAUGHT and
# reddens the lane, which is the re-anchor signal.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-print.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "print-stop emits another kind's constructor (make-finish-node)"
  FIND [[    (list 'make-stop-node (lit (stop-node-name n)) (lit (stop-node-source-label n))))]]
  REPLACE [[    (list 'make-finish-node (lit (stop-node-name n)) (lit (stop-node-source-label n))))]]
  EXPECT_OUTPUT_MATCHES "round trip byte-identical over the seed set: case raised -- Exception in render-machine: cannot render an unverified machine")

# The saver writing the base machine instead of the corrupted trial: the emitted
# fixture binds `gen` to the honest interpreter (`ref`) rather than the lying
# wrapper, so the reloaded fixture's lanes AGREE and it reproduces nothing. Caught
# by the in-process re-run of the saved fixture's own gen (reruns-disagree?).
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "the saver writes an honest gen (base machine), so the fixture no longer reproduces"
  FIND [[             (list 'define 'gen gen-expr)]]
  REPLACE [[             (list 'define 'gen 'ref)]]
  EXPECT_OUTPUT_MATCHES "the raw fixture's saved trial still disagrees when re-read and re-run -- expected a true value")

# The minimizer accepting a reduction that no longer disagrees: the failure oracle
# is short-circuited to "always failing", so the minimizer keeps shrinking past the
# disagreement and the minimized trial agrees. Caught by the minimized-still-
# disagrees check.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "the minimizer accepts a reduction that no longer disagrees"
  FIND [[                    (not (eq? (fail-oracle m s i sch) 'none)))))]]
  REPLACE [[                    #t)))]]
  EXPECT_OUTPUT_MATCHES "the minimized trial still disagrees -- expected a true value")

# The 64-emission bound. SURVIVOR, declared with the measured attempt: the
# probe minimizes in FOUR emissions, so removing the loop's bound guard changes
# nothing here -- the fixpoint stops it first. A probe that reached the bound
# would witness this; constructing one (>64 verifying, still-disagreeing
# reductions) is outside this lane.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/property-driver.sls
  SPEC byte-machine.property.fixture.chez.source
  LABEL "the minimizer's emission bound is removed"
  FIND [[             ((or (null? cs) (>= emissions bound))]]
  REPLACE [[             ((or (null? cs) #f)]]
  EXPECT_SURVIVES "the probe minimizes in 4 emissions (< the 64 bound), so the fixpoint stops the loop before the bound is ever consulted; no probe in this lane reaches it")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 60: the corruption catalogue and the oracle -------------------------
# The SIXTIETH pass. It runs property-rejections-tests.sps -- the catalogue and the
# independent oracle. Twenty-five mutations: the catalogue's positive
# (a no-op corrupt), negative (a twin that is its corrupt), refusal (a thunk made
# legal) and per-entry-count (an applies? made false) checks; the code sentinel's
# unconstructible term (see mut4); the matcher-bytes
# prohibition; and each of the nine oracle rows made to never fire (its fire
# counter) and to always fire (its silent counter). Each EXPECT asserts the failure
# signature, never a bare nonzero exit.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-rejections-tests.sps")

# mut1: a non-span entry's corrupt is a no-op -> the positive containment fails.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "a non-span entry's corrupt (dup-node-name) is a no-op"
  FIND [[      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))]]
  REPLACE [[      (lambda (m) m)]]
  EXPECT_OUTPUT_MATCHES "dup-node-name corruptions all contain the expected pairs -- expected a true value")

# mut2: a span-bearing entry's corrupt is a no-op -> the positive containment fails.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "a span-bearing entry's corrupt (span-active-at-pause) is a no-op"
  FIND [[      (lambda (m) (let* ((s (first-node-of m span-start-node?))
                         (nm (span-start-node-name s))
                         (old-next (span-start-node-next s))
                         (d1 (extend (->d m) '(make-machine) 1 (machine-name m) 7
                                     (list 'make-pause-node (q 'zz-inspan-pause) (q old-next) #f))))
                    (build (edit d1 '(make-span-start-node) 1 nm 3 (q 'zz-inspan-pause)))))]]
  REPLACE [[      (lambda (m) m)]]
  EXPECT_OUTPUT_MATCHES "span-active-at-pause corruptions all contain the expected pairs -- expected a true value")

# mut3: one entry's twin is replaced by its corrupt -> the twin no longer verifies.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "an entry's twin is its corrupt (dup-node-name)"
  FIND [[      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))
      identity-twin]]
  REPLACE [[      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))
      (lambda (m) (let ((ns (node-names m))) (rename-to m all-node-ctors ns (car ns))))]]
  EXPECT_OUTPUT_MATCHES "dup-node-name twins verify and lack the entry's code -- expected a true value")

# mut4: the code sentinel drops the unconstructible list. The list is
# LOAD-BEARING because settable-consume-counter is unconstructible-ONLY (no
# corruption entry produces a settable field), so it reaches the sentinel through
# this list alone. Dropping the list drops it from the union, and the sentinel no
# longer set-equals the 33-code census -- the mutation is caught. (invalid-shape,
# the other unconstructible member, is also the not-a-machine entry's expected
# code, so on its own it could not make the list observable.)
byte_machine_mutation(
  FILE test/common/property-rejections-tests.sps
  SPEC byte-machine.property.rejections.chez.source
  LABEL "the code sentinel drops the unconstructible list"
  FIND [[               (sentinel (uniq (append entry-codes unconstructible-codes)))]]
  REPLACE [[               (sentinel (uniq entry-codes))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "the sentinel set-equals the census.s derived code set -- expected a true value")

# mut5: one refusal thunk is made legal -> its refusal check sees no raise.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "a refusal thunk is made legal (make-edge with a valid mode)"
  FIND [[       (lambda () (eval '(make-edge 'x 'not-a-mode) eval-env))]]
  REPLACE [[       (lambda () (eval '(make-edge 'x 'advance) eval-env))]]
  EXPECT_OUTPUT_MATCHES "edge-mode-outside-closed-set raises a contract violation -- expected a true value")

# mut6: an entry's applies? is constantly false -> its per-entry count reads 0.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/machine-corrupt.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "an entry's applies? is constantly false (missing-callback-declaration)"
  FIND [[      (lambda (m) (first-node-of m callback-node?))]]
  REPLACE [[      (lambda (m) #f)]]
  EXPECT_OUTPUT_MATCHES "missing-callback-declaration applied >= 1 -- expected a true value")

# mut7: the oracle's overlapping-transitions row reads matcher-bytes -> the structural census catches it.
byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "the oracle's overlapping-transitions byte-set arm reads matcher-bytes"
  FIND [[          ((byte-set-matcher? mt) (byte-set-matcher-bytes mt))]]
  REPLACE [[          ((byte-set-matcher? mt) (matcher-bytes mt))]]
  EXPECT_OUTPUT_MATCHES "the symbol matcher-bytes does not occur in the oracle -- expected 0, got 1")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule name-duplicates never fires (returns empty)"
  FIND [[(define (rule-duplicates m)
    (append
     (map (lambda (nm) (cons 'duplicate-name nm)) (dups (node-set m)))
     (map (lambda (nm) (cons 'duplicate-error-declaration nm))
          (dups (map error-declaration-name (machine-errors m))))
     (map (lambda (nm) (cons 'duplicate-callback-declaration nm))
          (dups (map callback-declaration-name (machine-callbacks m))))
     (map (lambda (nm) (cons 'duplicate-span-declaration nm))
          (dups (map span-declaration-name (machine-spans m))))))]]
  REPLACE [[(define (rule-duplicates m) '())]]
  EXPECT_OUTPUT_MATCHES "name-duplicates fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule name-duplicates always fires (every node)"
  FIND [[(define (rule-duplicates m)
    (append
     (map (lambda (nm) (cons 'duplicate-name nm)) (dups (node-set m)))
     (map (lambda (nm) (cons 'duplicate-error-declaration nm))
          (dups (map error-declaration-name (machine-errors m))))
     (map (lambda (nm) (cons 'duplicate-callback-declaration nm))
          (dups (map callback-declaration-name (machine-callbacks m))))
     (map (lambda (nm) (cons 'duplicate-span-declaration nm))
          (dups (map span-declaration-name (machine-spans m))))))]]
  REPLACE [[(define (rule-duplicates m) (map (lambda (zzn) (cons 'duplicate-name (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "name-duplicates agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule duplicate-fields-and-branch-keys never fires (returns empty)"
  FIND [[(define (rule-duplicate-fields-and-branch-keys m)
    (append
     (map (lambda (nm) (cons 'invalid-field-declaration nm))
          (dups (map uint-field-name (machine-fields m))))
     (apply append
       (map (lambda (n)
              (if (callback-node? n)
                  (map (lambda (k) (cons 'duplicate-branch-key (node-name n)))
                       (dups (map car (callback-node-branch-targets n))))
                  '()))
            (machine-nodes m)))))]]
  REPLACE [[(define (rule-duplicate-fields-and-branch-keys m) '())]]
  EXPECT_OUTPUT_MATCHES "duplicate-fields-and-branch-keys fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule duplicate-fields-and-branch-keys always fires (every node)"
  FIND [[(define (rule-duplicate-fields-and-branch-keys m)
    (append
     (map (lambda (nm) (cons 'invalid-field-declaration nm))
          (dups (map uint-field-name (machine-fields m))))
     (apply append
       (map (lambda (n)
              (if (callback-node? n)
                  (map (lambda (k) (cons 'duplicate-branch-key (node-name n)))
                       (dups (map car (callback-node-branch-targets n))))
                  '()))
            (machine-nodes m)))))]]
  REPLACE [[(define (rule-duplicate-fields-and-branch-keys m) (map (lambda (zzn) (cons 'invalid-field-declaration (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "duplicate-fields-and-branch-keys agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule missing-target never fires (returns empty)"
  FIND [[(define (rule-missing-target m)
    (let* ((nodes (node-set m))
           (refs (uniq (append (if (symbol? (machine-entry m)) (list (machine-entry m)) '())
                               (apply append (map non-eof-targets (machine-nodes m)))))))
      (map (lambda (t) (cons 'missing-target t))
           (filter (lambda (t) (and (symbol? t) (not (memq t nodes)))) refs))))]]
  REPLACE [[(define (rule-missing-target m) '())]]
  EXPECT_OUTPUT_MATCHES "missing-target fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule missing-target always fires (every node)"
  FIND [[(define (rule-missing-target m)
    (let* ((nodes (node-set m))
           (refs (uniq (append (if (symbol? (machine-entry m)) (list (machine-entry m)) '())
                               (apply append (map non-eof-targets (machine-nodes m)))))))
      (map (lambda (t) (cons 'missing-target t))
           (filter (lambda (t) (and (symbol? t) (not (memq t nodes)))) refs))))]]
  REPLACE [[(define (rule-missing-target m) (map (lambda (zzn) (cons 'missing-target (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "missing-target agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule overlapping-cases never fires (returns empty)"
  FIND [[(define (rule-overlap m)
    (filter-map-nodes m
      (lambda (n)
        (and (byte-dispatch-node? n)
             (any-meet? (map (lambda (c) (matcher-set (byte-case-matcher c)))
                             (byte-dispatch-node-cases n)))
             (cons 'overlapping-cases (byte-dispatch-node-name n))))))]]
  REPLACE [[(define (rule-overlap m) '())]]
  EXPECT_OUTPUT_MATCHES "overlapping-cases fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule overlapping-cases always fires (every node)"
  FIND [[(define (rule-overlap m)
    (filter-map-nodes m
      (lambda (n)
        (and (byte-dispatch-node? n)
             (any-meet? (map (lambda (c) (matcher-set (byte-case-matcher c)))
                             (byte-dispatch-node-cases n)))
             (cons 'overlapping-cases (byte-dispatch-node-name n))))))]]
  REPLACE [[(define (rule-overlap m) (map (lambda (zzn) (cons 'overlapping-cases (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "overlapping-cases agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule ambiguous-sequence-prefix never fires (returns empty)"
  FIND [[(define (rule-prefix m)
    (filter-map-nodes m
      (lambda (n)
        (and (sequence-dispatch-node? n)
             (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
               (and (pairwise-prefix? alts)
                    (cons 'ambiguous-sequence-prefix (sequence-dispatch-node-name n))))))))]]
  REPLACE [[(define (rule-prefix m) '())]]
  EXPECT_OUTPUT_MATCHES "ambiguous-sequence-prefix fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule ambiguous-sequence-prefix always fires (every node)"
  FIND [[(define (rule-prefix m)
    (filter-map-nodes m
      (lambda (n)
        (and (sequence-dispatch-node? n)
             (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
               (and (pairwise-prefix? alts)
                    (cons 'ambiguous-sequence-prefix (sequence-dispatch-node-name n))))))))]]
  REPLACE [[(define (rule-prefix m) (map (lambda (zzn) (cons 'ambiguous-sequence-prefix (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "ambiguous-sequence-prefix agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule unreachable-node never fires (returns empty)"
  FIND [[(define (rule-unreachable m)
    (let ((r (reachable m)))
      (map (lambda (nm) (cons 'unreachable-node nm))
           (filter (lambda (nm) (not (member nm r))) (node-set m)))))]]
  REPLACE [[(define (rule-unreachable m) '())]]
  EXPECT_OUTPUT_MATCHES "unreachable-node fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule unreachable-node always fires (every node)"
  FIND [[(define (rule-unreachable m)
    (let ((r (reachable m)))
      (map (lambda (nm) (cons 'unreachable-node nm))
           (filter (lambda (nm) (not (member nm r))) (node-set m)))))]]
  REPLACE [[(define (rule-unreachable m) (map (lambda (zzn) (cons 'unreachable-node (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "unreachable-node agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule non-eof-into-finish never fires (returns empty)"
  FIND [[(define (rule-non-eof-into-finish m)
    (let ((r (byte-reached m)))
      (uniq
       (filter-map-nodes m
         (lambda (n)
           (and (member (node-name n) r)
                (exists (lambda (t) (finish-name? m t)) (non-eof-targets n))
                (cons 'non-eof-into-finish (node-name n))))))))]]
  REPLACE [[(define (rule-non-eof-into-finish m) '())]]
  EXPECT_OUTPUT_MATCHES "non-eof-into-finish fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule non-eof-into-finish always fires (every node)"
  FIND [[(define (rule-non-eof-into-finish m)
    (let ((r (byte-reached m)))
      (uniq
       (filter-map-nodes m
         (lambda (n)
           (and (member (node-name n) r)
                (exists (lambda (t) (finish-name? m t)) (non-eof-targets n))
                (cons 'non-eof-into-finish (node-name n))))))))]]
  REPLACE [[(define (rule-non-eof-into-finish m) (map (lambda (zzn) (cons 'non-eof-into-finish (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "non-eof-into-finish agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule zero-progress-cycle never fires (returns empty)"
  FIND [[(define (rule-zero-progress m)
    (let* ((br (byte-reached m))                     ; only byte-reached nodes count
           (nodes (filter (lambda (nm) (member nm br)) (node-set m)))
           (on-cycle (nodes-on-nonconsuming-cycle m nodes)))
      (map (lambda (nm) (cons 'zero-progress-cycle nm)) on-cycle)))]]
  REPLACE [[(define (rule-zero-progress m) '())]]
  EXPECT_OUTPUT_MATCHES "zero-progress-cycle fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule zero-progress-cycle always fires (every node)"
  FIND [[(define (rule-zero-progress m)
    (let* ((br (byte-reached m))                     ; only byte-reached nodes count
           (nodes (filter (lambda (nm) (member nm br)) (node-set m)))
           (on-cycle (nodes-on-nonconsuming-cycle m nodes)))
      (map (lambda (nm) (cons 'zero-progress-cycle nm)) on-cycle)))]]
  REPLACE [[(define (rule-zero-progress m) (map (lambda (zzn) (cons 'zero-progress-cycle (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "zero-progress-cycle agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule eof-stop-or-cycle never fires (returns empty)"
  FIND [[(define (rule-eof m)
    (uniq
     (apply append
       (map (lambda (start)
              (let ((v (eof-verdict m (parked-eof-start m start) '())))
                (cond ((eq? v 'stop) (list (cons 'eof-reachable-stop (node-name start))))
                      ((eq? v 'cycle) (list (cons 'eof-zero-progress-cycle (node-name start))))
                      (else '()))))
            (parked-set m)))))]]
  REPLACE [[(define (rule-eof m) '())]]
  EXPECT_OUTPUT_MATCHES "eof-stop-or-cycle fired at least once -- expected a true value")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/verify-oracle.sls
  SPEC byte-machine.property.rejections.chez.source
  LABEL "oracle rule eof-stop-or-cycle always fires (every node)"
  FIND [[(define (rule-eof m)
    (uniq
     (apply append
       (map (lambda (start)
              (let ((v (eof-verdict m (parked-eof-start m start) '())))
                (cond ((eq? v 'stop) (list (cons 'eof-reachable-stop (node-name start))))
                      ((eq? v 'cycle) (list (cons 'eof-zero-progress-cycle (node-name start))))
                      (else '()))))
            (parked-set m)))))]]
  REPLACE [[(define (rule-eof m) (map (lambda (zzn) (cons 'eof-reachable-stop (node-name zzn))) (machine-nodes m)))]]
  EXPECT_OUTPUT_MATCHES "eof-stop-or-cycle agrees with the verifier -- expected none, got .oracle")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 61: the compile-file limits witness ---------------------------------
# The SIXTY-FIRST pass. It runs compile-limits-tests.sps. Two
# mutations: compile-file replaced by a plain load of the source (caught by the
# object-exists check, written before the object is loaded); and the interpreter-
# agreement comparison inverted (caught by the agreement check).
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/compile-limits-tests.sps")

byte_machine_mutation(
  FILE test/common/compile-limits-tests.sps
  SPEC byte-machine.unit.compile-limits.chez.source
  LABEL "compile-file is replaced by a plain load of the source"
  FIND [[(compile-file genfile objfile)]]
  REPLACE [[(load genfile)]]
  EXPECT_OUTPUT_MATCHES "the object file exists and is non-empty -- expected a true value")

byte_machine_mutation(
  FILE test/common/compile-limits-tests.sps
  SPEC byte-machine.unit.compile-limits.chez.source
  LABEL "the interpreter-agreement comparison is inverted"
  FIND [[(check-equal "the two lanes agree on the full triple" (and rc (triple rc)) (triple ri))]]
  REPLACE [[(check-not-equal "the two lanes agree on the full triple" (and rc (triple rc)) (triple ri))]]
  EXPECT_OUTPUT_MATCHES "the two lanes agree on the full triple -- expected any value other than")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- the request line's own decisions ----------------------------------------
# Three decisions the request-line fixture (http-machine.sls) encodes, each
# caught by the unit lane with a MEASURED failure signature -- the got value the
# mutation produces, not a bare nonzero exit. Measured against a staged run:
#   1. the first method byte belongs to the span -- idle REEXECUTES a tchar into
#      message-begin, so advancing it instead drops the byte and
#      the method span reads "ET" not "GET";
#   2. a span ends BEFORE its delimiter SP -- advancing at the token
#      end pulls the SP into the span, which then reads "GET ";
#   3. the version production is HTTP/1.0 / HTTP/1.1 -- altering the 1.1
#      alternative rejects a canonical HTTP/1.1 request at its final digit.
# No other pass mutates this FILE under this SPEC lane, so no other pin's FIND
# or output is touched.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-request-line-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-request-line.chez.source
  LABEL "http-machine: idle advances the first method byte instead of reexecuting it into the span"
  FIND [[(make-edge 'msg-begin 'reexecute)]]
  REPLACE [[(make-edge 'msg-begin 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "method-data .ET.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-request-line.chez.source
  LABEL "http-machine: the method span consumes its delimiter SP instead of ending before it"
  FIND [[(make-edge 'method-close 'reexecute)]]
  REPLACE [[(make-edge 'method-close 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "method-data .GET .")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-request-line.chez.source
  LABEL "http-machine: the HTTP/1.1 version alternative is not recognized"
  FIND [[(make-sequence-case (string-bytes "HTTP/1.1") 'ver-ok #f)]]
  REPLACE [[(make-sequence-case (string-bytes "HTTP/1.2") 'ver-ok #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-version byte 18")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- the header section's own decisions --------------------------------------
# Three decisions the header section encodes, caught by the http-message lane
# with a MEASURED signature (the got value, not a bare nonzero exit). Measured
# against a staged run: the first header-name byte belongs to the name
# span (header-line-start REEXECUTES a tchar into hn-open); a header name ends
# BEFORE its colon (hn-loop reexecutes the colon into hn-close); and the header
# value opens AFTER leading OWS is skipped (ows-skip reexecutes the first
# non-OWS byte into hv-open), so advancing there drops the value's first byte.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-message-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-message.chez.source
  LABEL "http-machine: the first header-name byte is advanced past instead of opening the name span"
  FIND [[(make-edge 'hn-open 'reexecute)]]
  REPLACE [[(make-edge 'hn-open 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "header-name-data .ost.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-message.chez.source
  LABEL "http-machine: the header name consumes its colon instead of ending before it"
  # `(make-edge 'hn-close 'reexecute)` occurs three
  # times (hn-loop, cl-end, te-end all reexecute into hn-close), so the FIND
  # includes hn-loop's own self-loop line to stay a single site.
  FIND [[(make-edge 'hn-loop 'advance) #f))
       (make-edge 'hn-close 'reexecute)]]
  REPLACE [[(make-edge 'hn-loop 'advance) #f))
       (make-edge 'hn-close 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "header-name-data .Host:.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-message.chez.source
  LABEL "http-machine: the header value advances past its first byte instead of opening the span there"
  FIND [[(make-edge 'hv-open 'reexecute)]]
  REPLACE [[(make-edge 'hv-open 'advance)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "header-value-data .xample.com.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- framing recognition and the fixed body ----------------------------------
# Three decisions the framing fixture encodes, caught by the http-framing lane
# with a MEASURED signature. Measured against a staged run:
#   1. recognition is CASE-INSENSITIVE: both-cases yields the
#      character's two cases, so collapsing it to one drops lowercase/mixed names;
#   2. a framing header's flag is checked at the boundary AFTER the line's LF:
#      inverting the duplicate test flags the FIRST Content-Length;
#   3. Content-Length is base-10 checked accumulation: base 16 makes
#      "abc" a valid length and moves the overflow digit.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-framing-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-framing.chez.source
  LABEL "http-machine: framing recognition is no longer case-insensitive"
  FIND [[(if (>= b 97) (list b (- b 32)) (list b (+ b 32)))]]
  REPLACE [[(list b)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "hit: content-length -- expected error")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-framing.chez.source
  LABEL "http-machine: the Content-Length duplicate test is inverted, flagging the first one"
  FIND [[(make-field-branch-node 'cl-line-done 'nonzero '(has-cl)]]
  REPLACE [[(make-field-branch-node 'cl-line-done 'zero '(has-cl)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-content-length boundary 35")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-framing.chez.source
  LABEL "http-machine: Content-Length accumulates in base 16 instead of base 10"
  FIND [['cl-value 'content-length 10 'cl-value]]
  REPLACE [['cl-value 'content-length 16 'cl-value]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "content-length-overflow byte 48")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_reset()

# --- the chunked body and trailers -------------------------------------------
# Three decisions the chunked fixture encodes, caught by the http-chunked lane
# with a MEASURED signature. Measured against a staged run:
#   1. chunk sizes are BASE 16: base 10 rejects an all-`f` size as a
#      malformed extension instead of overflowing;
#   2. the chunk-header size decides body vs trailers: inverting it routes a
#      nonzero chunk's data into the trailer section (its bytes read as a name);
#   3. a Content-Length trailer is FORBIDDEN at the colon: dropping
#      the recognizer's forbidden verdict accepts it.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-chunked-tests.sps")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-chunked.chez.source
  LABEL "http-machine: chunk sizes accumulate in base 10 instead of base 16"
  FIND [['chunk-size 'chunk-size 16 'chunk-size]]
  REPLACE [['chunk-size 'chunk-size 10 'chunk-size]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-chunk-extension byte 46")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-chunked.chez.source
  LABEL "http-machine: the chunk-header size test is inverted, routing chunk data to the trailers"
  FIND [[(make-field-branch-node 'chunk-body-decide 'nonzero '(chunk-size)]]
  REPLACE [[(make-field-branch-node 'chunk-body-decide 'zero '(chunk-size)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "trailer-name-data .HELLO.")

byte_machine_mutation(
  FILE test/support/harness/byte-machine/test/http-machine.sls
  SPEC byte-machine.unit.http-chunked.chez.source
  LABEL "http-machine: a Content-Length trailer is accepted instead of forbidden"
  FIND [['tcl-end
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'e-forbidden-trailer 'reexecute) #f)]]
  REPLACE [['tcl-end
       (list (make-byte-case (make-exact-byte-matcher 58) (make-edge 'trailer-name-close 'reexecute) #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "Content-Length trailer -- expected .forbidden-trailer byte 63., got #f")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- passes 66-68: the keyword-table node kind -------------------------------
# The fourteenth node kind, its compact-table lowering and the per-table fold.
# The census ratchets in ir.sls (the "fourteen kinds" rows above) carry the
# closed-set FORMS; these pins carry the SEMANTICS -- the fold, the
# terminal-vs-continue split, the delimiter reexecute, the target/no-match
# routing, the eof route, and the emitted ABI literal -- each caught absolutely
# by one of the three keyword-table lanes, never by a bare nonzero exit. The
# fold and the reexecute are pinned on BOTH executors (interpreter and
# generated), because the two derive them independently and a defect in one is
# a differential result, not a shared wrong answer.

# --- Pass 66: the interpreter's keyword walk (unit.keyword-table) --------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/keyword-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: the keyword fold goes the wrong direction"
  # A..Z fold to a..z (+32). Subtracting folds an uppercase keyword AWAY from its
  # lowercased input, so the case-insensitive table stops matching a lowercased
  # method. Comparison-caught by the CI cases.
  FIND [[(if (and ci (>= b 65) (<= b 90)) (+ b 32) b)]]
  REPLACE [[(if (and ci (>= b 65) (<= b 90)) (- b 32) b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[accepts every casing to the same target: get -- expected .stopped 3 3 3 got-get #f #f., got .error 0 0 0 reject unexpected-byte 0.]])

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: a matched keyword consumes its delimiter instead of reexecuting it"
  # The byte that closes a keyword is left unread, so the span ends at the
  # keyword length. Advancing consumes it and every span runs one byte long.
  FIND [[(cons (keyword-entry-target term) 'reexecute)]]
  REPLACE [[(cons (keyword-entry-target term) 'advance)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[takes the short keyword, span closes at 3 .delimiter not consumed.: get -- expected .stopped 3 3 3 got-get #f #f., got .stopped 4 4 4 got-get #f #f.]])

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: eof-target-of has no keyword-table arm (the AGENTS.md kind-filter trap)"
  # eof-target-of is the per-kind filter a lookup does not teach. Neutering its
  # keyword-table arm sends a parked table to the raising `else`; a finish! then
  # raises `internal`, reported by the EOF case as "case raised".
  FIND [[((keyword-table-node? n) (keyword-table-node-eof-target n))]]
  REPLACE [[((and (keyword-table-node? n) #f) (keyword-table-node-eof-target n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[each of six EOF inputs takes the eof-target at its own offset: case raised]])

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls
  SPEC byte-machine.unit.keyword-table.chez.source
  LABEL "interpret: a walk position is a terminal even when the path is a proper prefix"
  # A keyword terminates only when the path EQUALS an entry's bytes; dropping the
  # length test makes every proper prefix a false terminal (GET-X would take the
  # GET-PARAMETER path's target instead of no-matching, and a non-keyword first
  # byte would falsely match).
  FIND [[(and (= (length bs) (length path)) (kw-prefix? ci path bs))]]
  REPLACE [[(and #t (kw-prefix? ci path bs))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[never rewinding to GET: get-x -- expected .error 4 4 4 reject unexpected-byte 4., got .stopped 4 4 4 got-gp #f #f.]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 67: the generated compact-table walk (differential.keyword-table) ----
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-keyword-table-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the keyword-step op folds the wrong direction (generated lane)"
  # The runtime op's own fold, derived independently of the interpreter's. The
  # differential asserts the generated table absolutely, so a wrong fold reddens
  # even though the interpreter (unmutated) still folds correctly.
  FIND [[(if (and ci? (>= b 65) (<= b 90)) (+ b 32) b)]]
  REPLACE [[(if (and ci? (>= b 65) (<= b 90)) (- b 32) b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[accepts every casing to the same target: no casing misbehaved -- expected none, got .gen "get " .error 0 0 0 reject unexpected-byte 0..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a matched keyword routes to the no-match edge instead of its target"
  # `(cdr term)` is the matched entry's target id; routing to the no-match target
  # sends every matched keyword to the reject node.
  FIND [[(term (list 'jump (cdr term) i (quote byte)))]]
  REPLACE [[(term (list 'jump (car no-match) i (quote byte)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET-PARAMETER " .error 13 13 13 reject unexpected-byte 13..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a matched keyword consumes its delimiter instead of reexecuting it (generated lane)"
  # The op reports position `i` (the closing byte is left unread); reporting
  # `(+ i 1)` consumes it and the span runs one byte long. Same FIND as the pin
  # above, a different edit -- each is staged independently.
  FIND [[(term (list 'jump (cdr term) i (quote byte)))]]
  REPLACE [[(term (list 'jump (cdr term) (+ i 1) (quote byte)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET-PARAMETER " .stopped 14 14 14 got-gp #f #f..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a walk position is a terminal even when the path is a proper prefix (generated lane)"
  # The generated twin of the interpreter's terminal-length pin: without the
  # length test the op accepts a proper prefix as a terminal, so GET-X takes the
  # GET-PARAMETER path's target rather than no-matching. The walk records as
  # terminal only an entry the shared prefix covers WHOLE, so the decision is
  # that `whole?`.
  FIND [[(scan (cdr es) n (and whole? (car es)))]]
  REPLACE [[(scan (cdr es) n (car es))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET-X" .stopped 4 4 4 got-gp #f #f..]])

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "normal-ir: the case-insensitive flag is not encoded into the table"
  # Slot 8 is the fold flag. Forcing it #f makes a case-insensitive table encode
  # as case-sensitive, so the fold vanishes AND -- the unique witness -- two
  # tables differing only in the flag now render identically, which the
  # fingerprint group forbids. Pinned to that group, not
  # the shared CI-fold failure the runtime-fold pin above also produces.
  FIND [[(keyword-table-node-case-insensitive? n) #f #f)))]]
  REPLACE [[#f #f #f)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the two renders differ on the flag alone -- expected a true value]])

# The three below witness: the walk op's error position-kind, compared across
# executors (interpret.sls lists it as required-to-match); the no-match edge's
# advance arm; and the keyword-table's entry in the reached-declaration credit
# list. Each is caught by its own group in differential-keyword-table.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the no-match reject reports the wrong position-kind (boundary, not byte)"
  # The reexecute no-match does not consume the offending byte, so the error is
  # AT that byte (position-kind byte), not after it (boundary). The differential
  # compares position-kind across executors and absolutely.
  FIND [[(else (list 'jump (car no-match) i (quote byte)))]]
  REPLACE [[(else (list 'jump (car no-match) i (quote boundary)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a no-match reject reports position-kind byte on the generated table and both agree: generated -- expected byte, got boundary]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the advance no-match does not consume the offending byte"
  # The advance arm consumes the mismatching byte (offset i+1); dropping the
  # increment leaves it unconsumed, which is the reexecute behaviour under an
  # advance edge. Caught by the advance-mode group.
  FIND [[(list 'jump (car no-match) (+ i 1) (quote boundary))]]
  REPLACE [[(list 'jump (car no-match) i (quote boundary))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[advances .consumed 1. and the reject is at the boundary after it, both lanes: generated -- expected .error 1 1 1 reject unexpected-byte 1., got .error 0 0 0 reject unexpected-byte 0.]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "compile: the reached declaration walk ignores keyword-table (default-eof credit)"
  # A keyword table with eof-target #f is the sole consumer of the default-eof
  # declaration; not crediting the keyword-table kind filters that declaration
  # out of the errs table and render-machine raises on a machine the verifier
  # accepted -- the same defect the field and counted passes pin for their
  # kinds. Distinct from the counted-consume-drop pin above (different REPLACE,
  # keyword-table's own row).
  FIND [[                                                      '(dispatch accumulate counted-consume
                                                        keyword-table))]]
  REPLACE [[                                                      '(dispatch accumulate counted-consume))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the default-eof machine renders and its EOF route takes the machine default error: case raised.*no error declaration for code]])

# The twelve below pin the in-place keyword walk. The walk finds, in ONE
# pass over the entries, the longest prefix any keyword shares with the parked
# `path` followed by this feed's bytes -- compared in place, never built -- and
# the entry that is all of it. Each mutation names one way of getting that
# wrong. The shared fixture could tell few of them apart, so the lane's "reads
# its parked prefix ... in place" group adds a GET/SET table, one input per
# mutant, and two direct op calls for the two answers no executor can reach
# alone. Every pin below is on a record (or, for the parked-fold pin, a pair of
# records) no other Pass 67 mutant emits: measured by a whole-pass sweep in both
# directions, each pin resolving exactly once in its own mutant's output.
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a parked prefix's bytes are not compared"
  # Every parked byte was matched by an earlier feed, so skipping its comparison
  # looks harmless -- until two keywords agree after a byte on which they differ.
  # Resumed after G, GET and SET then share the whole prefix, and SET, later in
  # the table, is taken.
  FIND [[(if (= (kw-fold (car p) ci?) (kw-fold (car k) ci?))]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[generated GET.ET -- expected .stopped 2 3 3 got-get #f #f., got .stopped 2 3 3 got-set #f #f.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a parked prefix's bytes are not case-folded"
  # A case-insensitive table resumed after capitals compares them raw. The
  # end-to-end CL|OSED record is shared with the drop/reverse/misread mutants and
  # the direct op record with the fold-direction one; only this mutant emits both,
  # so the pin requires the pair (the AGENTS.md whole-set rule).
  FIND [[(if (= (kw-fold (car p) ci?) (kw-fold (car k) ci?))]]
  REPLACE [[(if (= (car p) (kw-fold (car k) ci?))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[generated CL.OSED -- expected .stopped 4 6 6 got-closed #f #f., got .error 0 2 2 reject unexpected-byte 2..*op G.et -- expected .jump 1 2 byte., got .jump 9 0 byte.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: this feed's bytes are not compared"
  # Every fed byte agrees with every keyword, so the walk runs to the end of
  # the longest keyword or of the feed.
  FIND [[((= (kw-fold (bytevector-u8-ref bv at) ci?) (kw-fold (car k) ci?))]]
  REPLACE [[(#t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the case-sensitive generated table refuses a lowercase method: gen -- expected .error 0 0 0 reject unexpected-byte 0., got .need-input 4 4 4 table #f #f.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: this feed's bytes are read from the bytevector's start, not from pos"
  # A fresh walk at pos > 0 compares bv[0..] -- here `zz` -- and refuses a
  # keyword that starts where the feed does.
  FIND [[(let loop ((p path) (k kw) (j 0) (at pos))]]
  REPLACE [[(let loop ((p path) (k kw) (j 0) (at 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[generated zz.GET -- expected .stopped 3 5 3 got-get #f #f., got .error 0 2 0 reject unexpected-byte 0.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a walk compares one byte past the end of its feed"
  # The first feed of a split then sees the second feed's first byte, and a
  # walk that should park is decided early.
  FIND [[((>= at end) (values j #f))]]
  REPLACE [[((> at end) (values j #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[generated CL.OSED -- expected .stopped 4 6 6 got-closed #f #f., got .error 0 2 3 reject unexpected-byte 3.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a keyword is credited one byte past its own end"
  # Every keyword the input covers whole then outruns the input by one, so a
  # completed GET-PARAMETER keeps walking instead of being taken.
  FIND [[((null? k) (values j #t))]]
  REPLACE [[((null? k) (values (+ j 1) #t))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[get-parameter -- expected .stopped 13 13 13 got-gp #f #f., got .need-input 14 14 14 table #f #f.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: the matched length leaves out the parked prefix"
  # With the parked length taken as 0 the stop position overshoots by it: G|GET
  # refuses one byte late.
  FIND [[(let ((plen (length path)))]]
  REPLACE [[(let ((plen 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[agree G.GET -- expected .error 1 2 2 reject unexpected-byte 2., got .error 0 1 1 reject unexpected-byte 1.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a walk may stop before where it resumed"
  # The longest shared prefix starts at the parked length. From 0, a parked
  # prefix that begins no keyword reports a stop behind the feed; no executor
  # parks one, so the op is driven directly.
  FIND [[(let scan ((es entries) (best plen) (term #f))]]
  REPLACE [[(let scan ((es entries) (best 0) (term #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[op X.GET -- expected .jump 9 1 byte., got .jump 9 0 byte.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: an entry the prefix covers only in part becomes the terminal when it tied"
  # At an equal length only an entry the prefix covers WHOLE is a terminal;
  # without that test GET-PARAMETER, tied with GET at 3, displaces it.
  FIND [[((and (= n best) whole?) (scan (cdr es) best (car es)))]]
  REPLACE [[((= n best) (scan (cdr es) best (car es)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[each input matches its expected generated tuple and agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET " .stopped 3 3 3 got-gp #f #f..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a tie on the longest prefix clears the terminal"
  # Only a strictly longer prefix replaces the terminal; `>=` lets GET-PARAMETER,
  # tied with GET at 3 but not whole, wipe GET out.
  FIND [[(cond ((> n best) (scan (cdr es) n (and whole? (car es))))]]
  REPLACE [[(cond ((>= n best) (scan (cdr es) n (and whole? (car es))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[each input matches its expected generated tuple and agrees with the interpreter: no case misbehaved -- expected none, got .gen "GET " .error 3 3 3 reject unexpected-byte 3..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a need answer parks the old prefix without this feed's bytes"
  # G parked by the first feed is dropped, so GGET's second feed starts afresh
  # and takes GET.
  FIND [[(let copy ((j (- i 1)) (acc '()))]]
  REPLACE [[(let copy ((j (- pos 1)) (acc '()))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[generated G.GET -- expected .error 0 1 1 reject unexpected-byte 1., got .stopped 3 4 4 got-get #f #f.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.keyword-table.chez.source
  LABEL "runtime: a need answer parks this feed's bytes in reverse"
  # Two parked bytes GE come back EG, which begins no keyword.
  FIND [[(copy (- j 1) (cons (bytevector-u8-ref bv j) acc))]]
  REPLACE [[(copy (- j 1) (append acc (list (bytevector-u8-ref bv j))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no split misbehaved -- expected none, got .gen 2 .error 0 2 2 reject unexpected-byte 2..]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 68: the emitted ABI literal (determinism.keyword-table) --------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-keyword-table-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.determinism.keyword-table.chez.source
  LABEL "compile: the emitted ABI version literal is not the current one"
  # The emitted literal must be the current ABI version (9). Emitting the
  # prior version both diverges the rendered bytes from the committed golden
  # AND makes the current runtime refuse the
  # library outright at construction -- `byte-machine-make-compiled-machine`
  # validates the version, so the determinism lane's top-level load of the
  # generated file raises "generated-runtime ABI mismatch with irritant 8"
  # (status 255) before it can report the golden mismatch cleanly. That refusal
  # is the sharper witness -- it names the version the emitter stamped -- so the
  # pin asserts it by message, not by the raw-byte golden diff. This is the ONE
  # pin on the emitted literal.
  FIND [[(byte-machine-make-compiled-machine 9 ]]
  REPLACE [[(byte-machine-make-compiled-machine 8 ]]
  EXPECT_STATUS 255
  EXPECT_OUTPUT_MATCHES [[generated-runtime ABI mismatch with irritant 8]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 69: the folded-collision rejection ----------------------------------
# A case-insensitive table whose entries collide under ASCII folding is refused
# with case-insensitive-keyword-collision. The three pins carry the verifier
# code -- the collision arm, its per-table guard, and the verifier's own fold
# -- each caught absolutely by the header lane's collision verify group
# (verify-machine directly), never by a bare nonzero exit. The executor folds
# are pinned in passes 66 and 67; this is the verifier's.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-keyword-header-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.differential.keyword-header.chez.source
  LABEL "verify: the folded-collision check never fires"
  # Forcing the guard #f drops the collision detection: a case-insensitive table
  # whose entries fold-collide now verifies clean, so the header lane's
  # collision-refused assertion reddens.
  FIND [[((and ci (fold=? (car rest) (car others)))]]
  REPLACE [[((and #f (fold=? (car rest) (car others)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the collision table does not verify -- expected a true value]])

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.differential.keyword-header.chez.source
  LABEL "verify: the collision check ignores the case-insensitive? flag (per table)"
  # Forcing the guard #t runs the fold check on EVERY table, so a case-SENSITIVE
  # table of byte-distinct case variants (legal: byte-different, no fold) is
  # wrongly refused. The CS collision machine's verifies-clean assertion reddens.
  # Same FIND as the pin above, a different edit -- each staged independently.
  FIND [[((and ci (fold=? (car rest) (car others)))]]
  REPLACE [[((and #t (fold=? (car rest) (car others)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the case-sensitive collision-shaped table verifies -- expected a true value]])

byte_machine_mutation(
  FILE src/byte-machine/verify.sls
  SPEC byte-machine.differential.keyword-header.chez.source
  LABEL "verify: the collision fold goes the wrong direction"
  # The verifier's own fold, independent of the executors'. Subtracting
  # folds A (65) to 33 while a (97) is unchanged, so A and a no longer fold-equal
  # and the collision is missed -- the case-insensitive table verifies clean.
  FIND [[(if (and (>= b 65) (<= b 90)) (+ b 32) b)]]
  REPLACE [[(if (and (>= b 65) (<= b 90)) (- b 32) b)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the collision table does not verify -- expected a true value]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- the pause reason ---------------------------------------------------------
# THREE passes (one per witnessing program, since the verify command is set per
# group), five mutations, covering the decisions the pause pins above
# do NOT: those cover the pause ARM mechanics (parking, offsets, lifecycle,
# emitted arms, fingerprint tag/continuation, ABI); these cover the reason
# CARRIED by the pause -- the verifier resolving it, the fingerprint encoding it,
# the interpreter reading it, the guard keeping a pause's error slot #f, and the
# errs-table reached-walk finding a pause-only code. Each signature is MEASURED
# by staging the mutant and running its own witnessing program (AGENTS.md).

# Pass A -- the verifier resolution arm, witnessed by verify-tests.sps.
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/verify-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause node's reason is not resolved against the declarations"
  FIND [[((pause-node? n) (pause-node-reason n))]]
  REPLACE [[((pause-node? n) #f)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "a pause node naming an undeclared reason is missing-error-declaration: missing-error-declaration -- expected a true value")
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Pass B -- the fingerprint reason encoding, witnessed by normal-ir-tests.sps.
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/normal-ir-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause reason is dropped from the fingerprint encoding"
  # Anchored on the pause arm's own `(put-u32be ... normal-pause-target ...)` so
  # it targets the pause encode arm, not the callback arm's identical reason form.
  FIND [[(put-u32be p (normal-pause-target s))
                (let ((code (normal-error-code s)))
                  (when code (put-symbol p code) (put-reason p (normal-error-reason s)))))]]
  REPLACE [[(put-u32be p (normal-pause-target s))
                (let ((code (normal-error-code s)))
                  (when #f (put-symbol p code) (put-reason p (normal-error-reason s)))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "reason changes the fingerprint -- expected a true value")
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Pass C -- the interpreter read, the pause error-slot guard, and the
# reached-walk, all witnessed by the differential.pause lane (interpreter ≡
# generated).
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-pause-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.pause.chez.source
  LABEL "runtime: the interpreter feed pause arm drops the reason"
  # `(parser-offset parser) pk` is unique to the feed pause NODE arm (the callback
  # arm uses callback-failure-position; the finish arm uses `off pk`).
  FIND [[(and rp (parts->parser-error rp (parser-offset parser) pk))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "feed pause p1 reports paused-continue with error slot #f: pause code -- expected paused-continue, got #f")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.pause.chez.source
  LABEL "runtime: the interpreter callback pause arm drops the reason (the second author-facing path)"
  # The callback-pause path, which also carries a reason. `(parser-offset
  # parser)` then `callback-failure-position` is unique to the FEED callback arm
  # (the finish callback uses `off`; the pause node uses `pk`).
  FIND [[(and rp (parts->parser-error rp (parser-offset parser)
                                                   callback-failure-position))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "callback-pause reports the callback node's reason, both lanes: reason = paused-upgrade -- expected paused-upgrade, got #f")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.differential.pause.chez.source
  LABEL "runtime: the feed-v2 boundary leaks the pause reason into the error slot"
  # The central safety property: a pause's error slot stays #f. Mutating
  # the error-slot routing to always take `e` leaks the reason there for a pause;
  # the generated lane then disagrees with the interpreter. Anchored on the
  # feed-v2-only `(- (feed-outcome-next o) start)` (finish-v2 uses `0`).
  FIND [[                            (- (feed-outcome-next o) start)
                            (feed-outcome-offset o)
                            (if (eq? st 'paused) #f e)]]
  REPLACE [[                            (- (feed-outcome-next o) start)
                            (feed-outcome-offset o)
                            e]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "feed pause p1 reports paused-continue with error slot #f: fields agree .incl pause reason. -- expected .paused 1 1 1 #f .machine paused-continue")
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.pause.chez.source
  LABEL "compile: the errs reached-walk drops the pause/callback reason code"
  # Without the pause/callback arm, a pause-only code never reaches the errs
  # table, and the emitted pause arm's (vector-ref errs (index-of ...)) raises at
  # emit time when the reason-bearing pause machine is rendered.
  FIND [[                                          ((and (memq (normal-state-kind st)
                                                      '(pause callback))
                                                (normal-error-code st))
                                           (normal-error-code st))]]
  REPLACE [[                                          ((and #f
                                                (normal-error-code st))
                                           (normal-error-code st))]]
  EXPECT_STATUS 255
  EXPECT_OUTPUT_MATCHES "no error declaration for code")
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- a parser can start in a mode ---------------------------------------------
# FOUR passes (one per witnessing program, the verify command being set per
# group), seven mutations, covering the decisions the field/reset
# pins above do NOT: the make-parser initial-values validation (range, settable
# gate, apply), the reset-survival RESTORE SOURCE (slot 17 vs the declared
# decls), the verifier's settable-consume-counter rule, the fingerprint's
# settable encoding, and the emitted settable table. Each signature is measured
# by staging the mutant and running its own witnessing program.

# Pass α -- make-parser's override validation and reset source, via runtime-tests.
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/runtime-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a settable override is validated but never applied"
  FIND [[                   (vector-set! values slot val)))]]
  REPLACE [[                   (if #f #f)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[override applied -- expected 1, got 0]])
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an override's upper width bound is not checked"
  FIND [[                   (unless (and (<= 0 val) (<= val (- (expt 2 w) 1)))]]
  REPLACE [[                   (unless (and (<= 0 val) #t)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a value outside the field.s declared width -- expected a raise]])
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a non-settable field is treated as settable"
  # settable-width returns #f for a non-settable field; forcing a width past it
  # lets a non-settable override through, so the non-settable refusal reddens.
  FIND [[                 (let ((w (settable-width settable name)))]]
  REPLACE [[                 (let ((w (or (settable-width settable name) 8)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a declared but NON-settable field -- expected a raise]])
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: parser-reset! restores the DECLARED initials, not the embedder's"
  # Distinct from the field-pass pin that DELETES the restore (caught with no
  # override): this restores the wrong SOURCE, observable only with an override,
  # so runtime-tests' reset case (mode := 1) is its witness.
  FIND [[    (vector-set! parser 8 (copy-values (parser-field-initials parser)))))]]
  REPLACE [[    (vector-set! parser 8 (initial-values (parser-field-decls parser)))))]]
  EXPECT_STATUS 1
  # Pinned on a check that exists for it: "runtime: a settable override is
  # validated but never applied" also reads 0 after the reset, so the
  # after-value alone would name both. The override's value
  # BEFORE the reset is what differs -- `(1 0)` here, `(0 0)` there.
  EXPECT_OUTPUT_MATCHES [[the override held before the reset and after it -- expected .1 1., got .1 0.]])
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Pass β -- the verifier's settable-consume-counter rule, via diagnostic-census.
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/diagnostic-census-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.unit.diagnostic-census.chez.source
  LABEL "verify: a settable field used as a counted-consume counter is not refused"
  FIND [[            ((field-settable-of fs fname)]]
  REPLACE [[            ((and #f (field-settable-of fs fname))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[settable-consume-counter is emitted -- expected a true value]])
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Pass γ -- the fingerprint's settable encoding, via normal-ir-tests.
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/normal-ir-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: settability is not encoded into the fingerprint"
  # Forcing the collector to skip every settable field leaves settable-slots
  # empty, so no machine writes the tag-10 section and a settable machine shares a
  # fingerprint with a non-settable one. (Inverting the `unless` guard instead
  # would wrongly WRITE an empty section for every field-less machine and move the
  # baseline goldens, masking this witness.)
  FIND [[                      ((list-ref (car fs) 4) (loop (cdr fs) (cons (cadddr (car fs)) acc)))]]
  REPLACE [[                      (#f (loop (cdr fs) (cons (cadddr (car fs)) acc)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[SETTABLE flag differ in fingerprint: different -- expected a true value]])
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Pass δ -- the emitted settable table, via the settable differential.
byte_machine_mutation_reset()
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-settable-tests.sps")
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.settable.chez.source
  LABEL "compile: the settable table is never emitted as payload member 3"
  # Without member 3 the generated lane has no settable table, so its make-parser
  # refuses the mode override the differential supplies -- the generated arm of
  # the fork raises instead of agreeing with the interpreter.
  FIND [[        (if (string=? settable "") "" (string-append " #(" settable ")"))]]
  REPLACE [[        ""]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[non-settable-field]])
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.differential.settable.chez.source
  LABEL "interpret: the settable-fields message reports no field as settable"
  # The interpreter lane's counterpart to compile's member 3 (the settable
  # differential witnesses both lanes). Dropping every settable field makes the op
  # lane's make-parser refuse the mode override the differential supplies -- the
  # interpreter arm raises where the generated agrees.
  FIND [[                    ((uint-field-settable? (car fs))]]
  REPLACE [[                    ((and #f (uint-field-settable? (car fs)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[non-settable-field]])
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 77: the keyword walk's allocation (unit.allocation-audit) -----------
# What the keyword walk allocates is invisible to every
# differential -- the answers are equal whether or not a prefix is copied -- so
# its two allocation decisions are witnessed only by the allocation lane's
# keyword group, which drives `byte-machine-keyword-step/v1` directly.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/allocation-audit-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "runtime: the keyword walk allocates for every byte it compares"
  # One pair per fed byte compared, with every answer unchanged -- smaller than
  # the defect it stands for (a copy of the whole prefix per byte) and caught by
  # the same check. It appends to the loop's own `p`, which the compiler cannot
  # know is empty, so the allocation cannot be folded away.
  FIND [[(loop p (cdr k) (+ j 1) (+ at 1))]]
  REPLACE [[(loop p (cdr k) (+ j 1) (+ at (- (length (append p (list at))) (length p))))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[no k allocated more than k=0 .k . extra bytes. -- expected .., got ..1 . 16000. .2 . 32000.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "runtime: a walk that consumed nothing copies its parked prefix"
  # `(append path '())` is `equal?` to path, so no answer changes; only the
  # prefix's identity and the allocation do.
  FIND [[(if (= i pos)]]
  REPLACE [[(if #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[parks its prefix without copying it: the prefix comes back as the same object -- expected a true value]])

# The runtime op census. The allocation lane derives every
# runtime procedure emitted code can call from compile.sls's string literals,
# counts which of them the audited inputs reach through a counting twin of each
# machine, and gives each op the HTTP slopes do not run a witness of its own.
# Nine mutations, each pinned on the one check naming its decision, measured
# against a staged copy with every pin in this pass resolving exactly once and
# only in its own mutant's output (the two keyword-walk mutants above
# included).

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: an arm no audited input reaches calls a runtime op nothing else emits"
  # The census's reason to exist: a lowering that calls an op the allocation
  # audit has never run. `parser-error?` of a count is #f, so no answer moves;
  # the counted-consume arm is on the body path, which no audited message takes.
  FIND [["         (cond ((= v 0) "]]
  REPLACE [["         (cond ((parser-error? v) #f) ((= v 0) "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[every derived op is reached by an audited input: census ops no witness reached -- expected .., got .parser-error..]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: an unreached arm names a runtime op the derivation cannot see"
  # The same call, its name split across two literals: the emitted text is
  # identical, the derivation misses it, and no twin calls it. Only the rendered
  # libraries, read as data, still carry the name -- the check this pins.
  FIND [["         (cond ((= v 0) "]]
  REPLACE [["         (cond ((parser-" "error? v) #f) ((= v 0) "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[every runtime export a rendered machine names is in the derived census: rendered runtime names absent from the census -- expected .., got .parser-error..]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: a reached op's name is split across two literals"
  # Emitted text unchanged; the derivation loses span-open, which every HTTP
  # header runs. The rendered-names check fires too; this pins the check over
  # what RAN, which is the one that sees a name no rendered fixture carries.
  FIND [["       (begin (byte-machine-span-open/v1 psr (quote "]]
  REPLACE [["       (begin (byte-machine-span-" "open/v1 psr (quote "]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[every op the twins were seen calling is in the derived census: called ops absent from the census -- expected .., got .byte-machine-span-open/v1.]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: the dispatch arm enters a runtime op for every byte it reads"
  # A pure predicate per byte: nothing allocates, so every slope stays zero,
  # and only the per-op call census sees an op move onto the per-byte path.
  FIND [["           (let ((b (bytevector-u8-ref bv pos)))\n"]]
  REPLACE [["           (let ((b (begin (callback-failure? pos) (bytevector-u8-ref bv pos))))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[never per byte of a header value: ops whose calls grow with a header value's length -- expected .., got .callback-failure..]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: the keyword arm enters a runtime op for every byte it matched"
  # The keyword machine has no dispatch arm, so this is the arm's own
  # dimension: a call per matched byte, allocating nothing.
  FIND [["             (%dispatch (caddr r) (cadr r) (+ off (- (caddr r) pos)) (cadddr r))\n"]]
  REPLACE [["             (begin (do ((i pos (+ i 1))) ((>= i (caddr r))) (callback-failure? i)) (%dispatch (caddr r) (cadr r) (+ off (- (caddr r) pos)) (cadddr r)))\n"]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[never per byte of a header value: ops whose calls grow with bytes matched in a keyword -- expected .., got .callback-failure..]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: the keyword arm allocates in proportion to the bytes it matched"
  # `(length (vector->list (make-vector n 0)))` is n, so the offset is unchanged
  # and n pairs are consed per jump. The direct keyword group cannot see it --
  # the op is untouched -- only the emitted-arm witness can.
  FIND [[(%dispatch (caddr r) (cadr r) (+ off (- (caddr r) pos)) (cadddr r))]]
  REPLACE [[(%dispatch (caddr r) (cadr r) (+ off (length (vector->list (make-vector (- (caddr r) pos) 0)))) (cadddr r))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the arm around the walk adds nothing per matched byte: no emitted k allocated more than k=0 .k . extra bytes. -- expected .., got ..1 . 32000. .2 . 64000.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "runtime: a machine error's record grows with the offset it reports"
  # A twelfth slot no accessor reads, sized by the offset -- the shape of a
  # record that copied the input it refused. Also reddens the emitted keyword
  # arm (every k there ends at an error), with a different got. The record's
  # last two members are the abandoned span and its offset, which both
  # constructors build as `#f #f`; FIND and REPLACE differ by the one appended
  # slot.
  FIND [[(vector-ref entry 1) #f
            node-name state-id offset position-kind #f #f))]]
  REPLACE [[(vector-ref entry 1) #f
            node-name state-id offset position-kind #f #f (make-bytevector offset 0)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a machine error's record does not grow with the offset it reports: machine error: alloc.short prefix. = alloc.long prefix. -- expected]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "runtime: a callback failure's record grows with the offset it reports"
  # The same appended slot as the machine-error pin above.
  FIND [[callback-error-reason detail
            node-name state-id offset position-kind #f #f))]]
  REPLACE [[callback-error-reason detail
            node-name state-id offset position-kind #f #f (make-bytevector offset 0)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a callback failure's record does not grow with the offset it reports: callback failure: alloc.short. = alloc.long. -- expected]])

byte_machine_mutation(
  FILE src/byte-machine/compile.sls
  SPEC byte-machine.unit.allocation-audit.chez.source
  LABEL "compile: compile.sls carries a second top-level datum"
  # Chez loads the library with the trailing form in place, so nothing else
  # notices; a census reading only the first datum would walk past any string
  # the second one held.
  FIND [[(bytevector-length bytes)))))]]
  REPLACE [[(bytevector-length bytes)))))
(define census-trailing-datum 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[the census is derived from compile.sls's emitted text: compile.sls is exactly one datum -- expected a true value]])
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 78: the span an error abandons (differential.abandoned-span) -------
# An error records the span it abandons. Every mutation below is measured by
# staging it and running this lane's program through the source launcher: each
# pin resolves exactly once in its own mutant's output, in no other mutant's in
# this pass, and not in the baseline's (a 19 x 20 sweep). The last mutation is
# a declared survivor.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-abandoned-span-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: an error records an abandoned span when none was open"
  # The `s` conjunct. Without it every error is filled, and one with no span
  # open reports `#f` beside an offset computed from the mark a closed span
  # left at 0 -- which reads that feed's start, so it is pinned in a LATER feed,
  # where it is not the 0 a constructor default would give.
  FIND [[(when (and e s)]]
  REPLACE [[(when e]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[and in a later feed, where an offset computed anyway would not be 0: the error records no span -- expected .error 0 0 3 .machine unexpected-byte .unexpected byte. reject 3 byte #f #f. error., got .error 0 0 3 .machine unexpected-byte .unexpected byte. reject 3 byte #f 3. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a result that is not an error is filled as one that abandoned its span"
  # The `e` conjunct. Its removal is caught by a RAISE, not a comparison, and
  # the raise is the decision's own failure: a result with a span open that is
  # not an error -- `need-input` at every feed boundary, `paused` at a flush --
  # has no record to fill. Measured, 15 of 30 cases raise identically, each one
  # a case in which some feed ends with the span open; pinned on the case named
  # for the decision. The opposite constant, `(and #f s)`, is the union of the
  # two seam mutants below and names no decision of its own.
  FIND [[(when (and e s)]]
  REPLACE [[(when s]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a flush that pauses, then an error after resume: case raised -- Exception in vector-set!]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a feed's error does not record the span it abandoned"
  # The feed seam's call. Every finish case stays green under it.
  FIND [[(abandon-span! parser r (parser-result-next r))]]
  REPLACE [[(parser-result-next r)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..#f #f. .#f #f..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a finish's error does not record the span it abandoned"
  # The finish seam's call. Every feed case stays green under it.
  FIND [[(abandon-span! parser r 0)]]
  REPLACE [[0]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a span truncated at EOF: the finish is the truncation error -- expected .error 3 0 3 .machine eof .token truncated. trunc 3 eof tok 3. error., got .error 3 0 3 .machine eof .token truncated. trunc 3 eof #f #f. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: the withheld bytes begin at the error's own stream offset"
  # Drops the slice distance back to the mark, so the withheld range is always
  # empty. Finish is unaffected: its range is empty anyway.
  FIND [[(- cursor (parser-span-mark parser))]]
  REPLACE [[0]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..tok 3. .tok 3..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: the withheld offset forgets the mark and names slice index 0"
  # Drops the mark: the offset becomes the stream offset of the failing feed's
  # slice index 0 -- the feed's own start only when its slice starts at 0, and
  # right then only for a span carried into it.
  FIND [[(- cursor (parser-span-mark parser))]]
  REPLACE [[(- cursor 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..tok 0. .tok 0..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a feed's cursor is taken as 0, as a finish's is"
  # The feed seam passes a finish's cursor, so the mark reads as a distance
  # past the error rather than a position before it.
  FIND [[(abandon-span! parser r (parser-result-next r))]]
  REPLACE [[(abandon-span! parser r 0)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..tok 4. .tok 4..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a finish's cursor is the stream offset it reports as next"
  # The finish seam reads its cursor from the result's `next`, which a
  # finish result fills with the stream offset.
  FIND [[(abandon-span! parser r 0)]]
  REPLACE [[(abandon-span! parser r (parser-result-next r))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a span truncated at EOF: the finish is the truncation error -- expected .error 3 0 3 .machine eof .token truncated. trunc 3 eof tok 3. error., got .error 3 0 3 .machine eof .token truncated. trunc 3 eof tok 0. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a delivery does not advance the mark"
  # Each delivery advances the mark. Without the advance a data callback
  # that fails reports as withheld the bytes it was just handed.
  FIND [[    (parser-set-span-mark! parser to)]]
  REPLACE [[    #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[failing at the span end: the error -- expected .error 3 3 3 .callback too-long .callback failure. close 3 boundary tok 3. error., got .error 3 3 3 .callback too-long .callback failure. close 3 boundary tok 1. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: parser-error-span reads the offset's slot"
  FIND [[  (define (parser-error-span e) (vector-ref e 9))]]
  REPLACE [[  (define (parser-error-span e) (vector-ref e 10))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..1 1. .1 1..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: parser-error-span-offset reads the span's slot"
  FIND [[  (define (parser-error-span-offset e) (vector-ref e 10))]]
  REPLACE [[  (define (parser-error-span-offset e) (vector-ref e 9))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..tok tok. .tok tok..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: the abandoned span is written to its offset's slot"
  # The span lands in the offset's slot and the offset overwrites it: the
  # record names no span beside a right offset.
  FIND [[(vector-set! e 9 s)]]
  REPLACE [[(vector-set! e 10 s)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..#f 1. .#f 1..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: the withheld offset is written to the span's slot"
  # The offset lands in the span's slot: the record names a number as its
  # span and no offset.
  FIND [[(vector-set! e 10 (- (parser-result-stream-offset r)]]
  REPLACE [[(vector-set! e 9 (- (parser-result-stream-offset r)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[refused AT the byte: the withheld bytes are the span's own: read through the accessors, in both lanes -- expected ..tok 1. .tok 1.., got ..1 #f. .1 #f..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: the record names a span other than the one open"
  # A constant name. `abm` declares one span, so only the property rows over
  # the keyword-table and counted fixtures, whose spans are `meth` and `body`,
  # can tell it from the open span's own name.
  FIND [[(vector-set! e 9 s)]]
  REPLACE [[(vector-set! e 9 'tok)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a keyword prefix refused: every schedule abandons the span with delivered .. withheld intact -- expected .., got ..tok 2 byte #t 0 ..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a feed's error is filled before the boundary flush"
  # Fills the executor's result before the boundary flush runs, so an error the
  # flush itself produces -- a data callback failing at a feed boundary -- goes
  # unfilled. Separated from the feed seam's deleted call by the property row,
  # whose span-end failures this mutant still fills.
  FIND [[             (let ((r (span-boundary-flush!
                       parser bv
                       (case (parser-variant parser)
                        ((op) (parser-feed-op! parser bv start end))
                        ((v2) (parser-feed-v2! parser bv start end))
                        (else (assertion-violation 'parser-feed! "unknown parser variant"
                                                   (parser-variant parser)))))))
               (abandon-span! parser r (parser-result-next r))]]
  REPLACE [[             (let ((r (span-boundary-flush!
                       parser bv
                       (let ((x (case (parser-variant parser)
                        ((op) (parser-feed-op! parser bv start end))
                        ((v2) (parser-feed-v2! parser bv start end))
                        (else (assertion-violation 'parser-feed! "unknown parser variant"
                                                   (parser-variant parser))))))
                         (abandon-span! parser x (parser-result-next x))
                         x))))
               #t]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a data callback failing on its first fragment: every schedule abandons the span with delivered .. withheld intact -- expected .., got ..#f 2 boundary #f #f .119..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a machine error is built naming a span"
  # Neither constructor can know the span; what they build must say none.
  FIND [[(vector-ref entry 1) #f
            node-name state-id offset position-kind #f #f))]]
  REPLACE [[(vector-ref entry 1) #f
            node-name state-id offset position-kind 'tok #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a span that closed before the error leaves nothing behind: both accessors answer #f, in both lanes -- expected ..#f #f. .#f #f.., got ..tok #f. .tok #f..]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a machine error is built with a withheld offset"
  # The machine constructor's offset default. Separated from the `s`
  # conjunct's mutant only by the later-feed case, where that one reads 3.
  FIND [[(vector-ref entry 1) #f
            node-name state-id offset position-kind #f #f))]]
  REPLACE [[(vector-ref entry 1) #f
            node-name state-id offset position-kind #f 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[and in a later feed, where an offset computed anyway would not be 0: the error records no span -- expected .error 0 0 3 .machine unexpected-byte .unexpected byte. reject 3 byte #f #f. error., got .error 0 0 3 .machine unexpected-byte .unexpected byte. reject 3 byte #f 0. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a callback error is built naming a span"
  FIND [[callback-error-reason detail
            node-name state-id offset position-kind #f #f))]]
  REPLACE [[callback-error-reason detail
            node-name state-id offset position-kind 'tok #f))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a completion callback that fails finds the span already closed: the error records no span -- expected .error 2 2 2 .callback too-long .callback failure. close 2 boundary #f #f. error., got .error 2 2 2 .callback too-long .callback failure. close 2 boundary tok #f. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: a callback error is built with a withheld offset"
  # The callback constructor's offset default, separated from the `s`
  # conjunct's mutant by the later-feed completion failure, where that one
  # reads 2.
  FIND [[callback-error-reason detail
            node-name state-id offset position-kind #f #f))]]
  REPLACE [[callback-error-reason detail
            node-name state-id offset position-kind #f 0))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES [[a completion callback failing in a later feed: the error records no span -- expected .error 0 0 2 .callback too-long .callback failure. close 2 boundary #f #f. error., got .error 0 0 2 .callback too-long .callback failure. close 2 boundary #f 0. error.]])

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls
  SPEC byte-machine.differential.abandoned-span.chez.source
  LABEL "runtime: the mark advances only when the delivery fails"
  FIND [[    (parser-set-span-delivered?! parser #t)
    (parser-set-span-mark! parser to)
    (callback-commit! parser state offset)
    (classify-callback-result
     (f parser (parser-user-context parser) bv from to)
     '() continue))]]
  REPLACE [[    (parser-set-span-delivered?! parser #t)
    (callback-commit! parser state offset)
    (let ((o (classify-callback-result
              (f parser (parser-user-context parser) bv from to)
              '() continue)))
      (when (callback-failure? o) (parser-set-span-mark! parser to))
      o))]]
  EXPECT_SURVIVES
    "a mark advanced on a SUCCESSFUL delivery is overwritten before anything reads it -- the completion substep closes the span and zeroes the mark, a pause resumes into a feed or a finish that re-anchors it, and a flush that continues ends the feed at a boundary -- so only a FAILING delivery's advance is observable, through parser-error-span-offset. Measured surviving every lane that drives a span: the span, counted-span, pause, callback, keyword-span and abandoned-span differentials, position-kind, the property differential, retention, and the HTTP message and chunked lanes. Declared rather than left unwritten because the boundary flush's absent `paused` arm is INERT only while every delivery advances the mark: narrowed to failing deliveries, that arm would deliver a fragment twice.")
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# Every pass above has run exactly once, so the accumulated total is
# final. Compared against the numbers declared at the top of this file --
# see EXPECTED_PASSES and EXPECTED_MUTATIONS, and the header comment that
# restates them -- so a whole pass, or a single mutation inside
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
