# Proof that the CMake-layer specifications are not vacuous.
#
# Each entry below breaks one decision in one module and names the specification
# that must notice. A mutation that survives means that specification passes
# whether the code is right or wrong, which is worse than having no
# specification at all -- an absent test is visibly absent, a vacuous one reports
# success.
#
# Evidence that lives in a transcript is not evidence: nobody can rerun it, and
# it cannot fail when the code changes. This suite therefore lives in the tree,
# and it mutates the assertion helper every specification depends on
# (SpecSupport), not only the modules.
#
# Adding a decision to a module means adding a mutation here. The SITES check
# will tell you when a pattern has drifted; it will not tell you when a new,
# untested decision has been added.
#
# ONE PASS, SEVENTY-THREE MUTATIONS
#
# Every mutation is declared before the single byte_machine_mutation_run call
# at the end of this file, so this suite is one pass by construction.
# EXPECTED_MUTATIONS below is compared against the accumulated total from
# byte_machine_mutation_totals once that call returns. Without it a single
# deleted byte_machine_mutation() call would go unnoticed: SITES cannot see it,
# since a missing declaration is not a pattern that failed to match.

cmake_minimum_required(VERSION 3.26)

set(EXPECTED_PASSES 1)
set(EXPECTED_MUTATIONS 73)

include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")

get_filename_component(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

# Under CTest each test gets a private temporary directory, which also keeps
# concurrent runs from sharing one staging tree. Run directly, the stage goes
# under the (gitignored) build tree rather than the current directory: in script
# mode CMAKE_CURRENT_BINARY_DIR is just wherever the developer happened to be
# standing, so the obvious default drops a tree of copied .cmake files into the
# repository root -- untracked, un-ignored, and exactly the sort of stray file
# that a later file(GLOB) picks up.
if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(STAGE_DIR "$ENV{BYTE_MACHINE_TEST_TMPDIR}/mutation")
else()
  set(STAGE_DIR "${SOURCE_ROOT}/build/mutation")
endif()

# --- ByteMachineProbe ------------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineProbe.cmake SPEC ByteMachineProbeSpec.cmake
  LABEL "probe: key match unanchored, so 'version' matches 'full-version'"
  SITES 2
  FIND [[MATCHES "(^|\n)${key}=([^\n]*)"]]
  REPLACE [[MATCHES "${key}=([^\n]*)"]])

byte_machine_mutation(
  FILE cmake/ByteMachineProbe.cmake SPEC ByteMachineProbeSpec.cmake
  LABEL "probe: empty value accepted"
  FIND [[  if(value STREQUAL "")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineProbe.cmake SPEC ByteMachineProbeSpec.cmake
  LABEL "probe: carriage-return normalization removed"
  FIND [[  string(REPLACE "\r\n" "\n" normalized "${output}")
  string(REPLACE "\r" "\n" normalized "${normalized}")]]
  REPLACE [[  set(normalized "${output}")]])

byte_machine_mutation(
  FILE cmake/ByteMachineProbe.cmake SPEC ByteMachineProbeSpec.cmake
  LABEL "probe: absent optional field returns the previous regex's capture"
  FIND [[    set(${out_var} "" PARENT_SCOPE)]]
  REPLACE [[    set(${out_var} "${CMAKE_MATCH_2}" PARENT_SCOPE)]]
  EXPECT_SURVIVES
    "CMake 4.3.3 clears CMAKE_MATCH_<n> on a failed match, so the stale-capture hazard cannot be provoked on this version; the guard is retained for the declared 3.26 floor")

# --- ByteMachineChez -------------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: any runtime accepted as Chez"
  FIND [[if(NOT full_version MATCHES "Chez Scheme")]]
  REPLACE [[if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: Petite accepted despite having no compile-program"
  FIND [[if(full_version MATCHES "Petite")]]
  REPLACE [[if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: unreadable version accepted"
  FIND [[if(NOT full_version MATCHES "Version ([0-9]+\\.[0-9]+\\.[0-9]+)")]]
  REPLACE [[set(CMAKE_MATCH_1 "99.0.0")
  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: version floor removed"
  FIND [[if(version VERSION_LESS BYTE_MACHINE_CHEZ_MINIMUM_VERSION)]]
  REPLACE [[if(FALSE)]])

# --- ByteMachineTesting ----------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: any test name accepted"
  FIND [[  if(NOT name MATCHES "^byte-machine\\.([a-z0-9-]+)\\.([a-z0-9-]+)\\.([a-z0-9-]+)\\.([a-z0-9-]+)$")]]
  REPLACE [[  set(CMAKE_MATCH_1 unit)
  set(CMAKE_MATCH_2 f)
  set(CMAKE_MATCH_3 chez)
  set(CMAKE_MATCH_4 source)
  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: unknown layer accepted"
  FIND [[  if(NOT layer IN_LIST BYTE_MACHINE_TEST_LAYERS)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: backend/mode incompatibility ignored"
  FIND [[  if(NOT mode IN_LIST BYTE_MACHINE_TEST_MODES_${backend})]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: duplicate test names accepted"
  FIND [[  if(name IN_LIST taken)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: missing timeout accepted"
  FIND [[  if(value STREQUAL "")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: zero and non-numeric timeouts accepted"
  FIND [[  if(NOT value MATCHES "^[0-9]+$" OR value EQUAL 0)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: unknown labels accepted"
  FIND [[    if(NOT label IN_LIST known)]]
  REPLACE [[    if(FALSE)]])

# --- SpecSupport -----------------------------------------------------------
#
# These are the reason this suite exists. Every negative case in every other
# specification, and every positive assertion in all of them, routes through
# these two functions. Break either and every specification stays green --
# which is how a suite reports success while checking nothing.

byte_machine_mutation(
  FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
  LABEL "spec-support: spec_check_equal never fails, so every positive assertion is decoration"
  FIND [[  if(NOT actual STREQUAL expected)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
  LABEL "spec-support: a child that exits 0 counts as rejected"
  FIND [[  if(rc EQUAL 0)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
  LABEL "spec-support: a child failing for the wrong reason counts as rejected"
  FIND [[  if(NOT flat_err MATCHES "${flat_expected}")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
  LABEL "spec-support: diagnostics no longer flattened, so CMake's wrapping breaks matching"
  FIND [[  string(REGEX REPLACE "[ \t\r\n]+" " " flattened "${text}")]]
  REPLACE [[  set(flattened "${text}")]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: a rejected candidate is classified ok, so the search accepts it"
  FIND [[    set(${out_status} "not-chez" PARENT_SCOPE)]]
  REPLACE [[    set(${out_status} "ok" PARENT_SCOPE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: a truncated probe answer is accepted with empty fields"
  FIND [[      set(${out_status} "missing-field" PARENT_SCOPE)]]
  REPLACE [[      set(${out_status} "ok" PARENT_SCOPE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: rejected candidates keep the previous candidate's fields"
  FIND [[  set(${out_version} "" PARENT_SCOPE)
  set(${out_machine_type} "" PARENT_SCOPE)]]
  REPLACE [[  ]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: identity stops raising what the classifier rejected"
  FIND [[  if(NOT status STREQUAL "ok")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineChez.cmake SPEC ByteMachineChezSpec.cmake
  LABEL "chez: absent version floor no longer refused, so the guard fails open"
  FIND [[  if(NOT BYTE_MACHINE_CHEZ_MINIMUM_VERSION MATCHES "^[0-9]+\\.[0-9]+")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
  LABEL "spec-support: a failed specification still signs off as verified"
  FIND [[  if(n EQUAL 0)]]
  REPLACE [[  if(TRUE)]])

byte_machine_mutation(
  FILE test/support/cmake/SpecSupport.cmake SPEC SpecSupportSpec.cmake
  LABEL "spec-support: failures are not counted, so the banner cannot tell"
  FIND [[    spec_record_failure()
    message(SEND_ERROR "byte-machine-spec: ${what}: expected '${expected}', got '${actual}'")]]
  REPLACE [[    message(SEND_ERROR "byte-machine-spec: ${what}: expected '${expected}', got '${actual}'")]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: hyphen-edge features accepted"
  FIND [[  if(feature MATCHES "^-|-$")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineProbe.cmake SPEC ByteMachineProbeSpec.cmake
  LABEL "probe: the optional accessor's clearing branch is deleted, leaving the output untouched"
  FIND [[  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()]]
  REPLACE [[  endif()]])

# --- MutationRunner (byte_machine_mutation_verdict and its registration) ---
#
# The machinery every specification above is trusted through, staged like
# everything else. Judging "caught for the declared reason" rather than merely
# "caught" rests on the `elseif` translating a wrong-reason result into a
# failure; without a mutation of the decision that branch depends on, it could
# be deleted with the whole suite green. These mutations close that.

byte_machine_mutation(
  FILE test/support/cmake/MutationRunner.cmake SPEC MutationRunnerSpec.cmake
  LABEL "mutation-runner: rc 0 is judged caught instead of not-caught"
  FIND [[  if(rc EQUAL 0)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE test/support/cmake/MutationRunner.cmake SPEC MutationRunnerSpec.cmake
  LABEL "mutation-runner: a status mismatch is no longer reported as wrong-reason"
  FIND [[  if(NOT expect_status STREQUAL "" AND NOT rc EQUAL expect_status)]]
  REPLACE [[  if(FALSE)]])

# The exact bug this pure function was extracted to fix: expect_output_matches
# tested by truthiness rather than by presence. A regex CMake reads as false --
# "0", OFF, NOTFOUND, anything ending "-NOTFOUND" -- would silently stop being
# enforced. MutationRunnerSpec.cmake's "reads as CMake-false" case is the one
# assertion that can tell this REPLACE apart from the fixed FIND: every other
# case in that file uses a pattern that is not itself CMake-false, so both
# forms of the condition agree on it.
byte_machine_mutation(
  FILE test/support/cmake/MutationRunner.cmake SPEC MutationRunnerSpec.cmake
  LABEL "mutation-runner: EXPECT_OUTPUT_MATCHES is tested by truthiness, so a pattern reading as CMake-false is silently unenforced"
  FIND [[  if(NOT expect_output_matches STREQUAL "" AND NOT output MATCHES "${expect_output_matches}")]]
  REPLACE [[  if(expect_output_matches AND NOT output MATCHES "${expect_output_matches}")]])

byte_machine_mutation(
  FILE test/support/cmake/MutationRunner.cmake SPEC MutationRunnerSpec.cmake
  LABEL "mutation-runner: a caught verdict is reported as not-caught"
  FIND [[  set(${out_verdict} "caught" PARENT_SCOPE)]]
  REPLACE [[  set(${out_verdict} "not-caught" PARENT_SCOPE)]])

# The verdict for a verify command that had to be killed for running too long: a
# non-numeric result must be its own `did-not-terminate`, not folded into `caught`
# where a non-terminating mutation would read as a silent success. MutationRunnerSpec's
# "a non-numeric result ... is neither caught nor not-caught" case is what tells this
# REPLACE apart from the FIND.
byte_machine_mutation(
  FILE test/support/cmake/MutationRunner.cmake SPEC MutationRunnerSpec.cmake
  LABEL "mutation-runner: a killed, non-terminating command is judged caught instead of did-not-terminate"
  FIND [[    set(${out_verdict} "did-not-terminate" PARENT_SCOPE)]]
  REPLACE [[    set(${out_verdict} "caught" PARENT_SCOPE)]])

# EXPECT_SURVIVES is judged by whether the verify command merely exited zero;
# EXPECT_STATUS and EXPECT_OUTPUT_MATCHES are never consulted for a declared
# survivor. Without this guard the combination is accepted and silently means
# less than it says -- exactly the "wrong reason" defect class this whole
# section exists to close, one level up, at declaration time rather than at
# judging time.
byte_machine_mutation(
  FILE test/support/cmake/MutationRunner.cmake SPEC MutationRunnerSpec.cmake
  LABEL "mutation-runner: EXPECT_SURVIVES alongside EXPECT_STATUS or EXPECT_OUTPUT_MATCHES is accepted instead of refused"
  FIND [[  if(DEFINED arg_EXPECT_SURVIVES AND (DEFINED arg_EXPECT_STATUS OR DEFINED arg_EXPECT_OUTPUT_MATCHES))]]
  REPLACE [[  if(FALSE)]])

# --- ByteMachineExpectExit -------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: the declared vocabulary is widened to accept anything"
  FIND [[  if(NOT code IN_LIST BYTE_MACHINE_EXIT_STATUS_VOCABULARY)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: non-numeric expectations accepted"
  FIND [[  if(NOT code MATCHES "^[0-9]+$")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: an out-of-vocabulary status is reported as an ordinary mismatch"
  FIND [[  if(NOT actual IN_LIST BYTE_MACHINE_EXIT_STATUS_VOCABULARY)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: a command that never ran is judged on its result string"
  FIND [[  if(NOT actual MATCHES "^[0-9]+$")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: an exact match is reported as a mismatch"
  FIND [[  if(actual EQUAL expected)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: the registrar stops validating its expectation"
  FIND [[  byte_machine_expect_exit_classify("${arg_EXPECT_EXIT}" status message)
  if(NOT status STREQUAL "ok")
    message(FATAL_ERROR "byte-machine: ${message} (test '${arg_NAME}')")
  endif()]]
  # A truly empty REPLACE is indistinguishable from an omitted one:
  # cmake_parse_arguments() cannot tell "REPLACE given the empty string" from
  # "REPLACE given nothing" without CMP0174 set to NEW (confirmed against this
  # project's 3.26 floor), and would leave arg_REPLACE undefined, tripping
  # MutationRunner's own REPLACE-is-required check. A comment is a no-op
  # substitution that keeps the mutation meaning "this validation is gone"
  # without relying on a policy this project does not otherwise need.
  REPLACE [[  # deleted]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: a registration with no expectation is accepted"
  FIND [[  if(NOT DEFINED arg_EXPECT_EXIT)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: the classifier leaves a stale message on success"
  FIND [[function(byte_machine_expect_exit_classify code out_status out_message)
  set(${out_message} "" PARENT_SCOPE)]]
  REPLACE [[function(byte_machine_expect_exit_classify code out_status out_message)]])

# The WORKING_DIRECTORY forwarding block in the registrar itself, not a caller
# of it (ByteMachineSchemeLane.cmake has a copy of the same shape, below). Only
# the WORKING_DIRECTORY assertions in ByteMachineExpectExitSpec.cmake exercise
# this path: every other case that reaches byte_machine_add_exit_code_test in
# that specification is rejected before this line runs.
byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: WORKING_DIRECTORY is parsed and then never forwarded to the registrar"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(FALSE)]])

# The other direction of the same conditional: forwarding the keyword to the
# registrar unconditionally, even when the caller gave no WORKING_DIRECTORY at
# all. Only ByteMachineExpectExitSpec.cmake's "absent" assertion can see a
# keyword arriving that should not have.
byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: WORKING_DIRECTORY is forwarded to the registrar even when the caller did not give one"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(TRUE)]])

# --- ByteMachineSchemeLane -------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the chez object guard is dropped, so a stale .so can be preferred over source"
  FIND [[      "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
]]
  # Same empty-REPLACE hazard as the expect-exit mutation above (CMP0174; see
  # its comment for why a truly empty REPLACE will not parse). Here the
  # deleted argument sits inside a multi-line set() list rather than replacing
  # a whole statement, and FIND's match includes the line's own trailing
  # newline -- so the comment needs one too, or it would swallow the following
  # "${program}" line into itself and delete both arguments instead of one.
  REPLACE [[  # deleted
]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an undiscovered chez yields a command with an empty executable"
  FIND [[    if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an unknown backend is reported as usable"
  FIND [[  set(${out_status} "unknown-backend" PARENT_SCOPE)]]
  REPLACE [[  set(${out_status} "ok" PARENT_SCOPE)]])

# Diagnostic wording is asserted exactly (see ByteMachineSchemeLaneSpec.cmake),
# so each of the three messages the functional core can produce gets its own
# mutation: a dropped interpolation and two one-word typos. Any of the three
# would otherwise pass every existing assertion undetected.
#
# The no-runtime message interpolates ${mode}, so a lane names the mode it
# failed to find a runtime for. REPLACE hardcodes "source": both
# specification cases this mutation is caught by call with mode `source`, so
# the only break it introduces is the dropped program interpolation.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the chez no-runtime message drops its program interpolation"
  FIND [[        "no Chez was discovered, so the chez ${mode} lane for '${program}' is not registered."]]
  REPLACE [[        "no Chez was discovered, so the chez source lane is not registered."]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the unknown-backend message is garbled"
  FIND [[    "'${backend}' is not a Scheme lane backend. Known backends: chez."]]
  REPLACE [[    "'${backend}' is not a Scheme land backend. Known backends: chez."]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the unknown-mode message is garbled"
  FIND [[      "'${mode}' is not an execution mode this lane module can build a command for. Known modes: source aot."]]
  REPLACE [[      "'${mode}' is not an execution mode this land module can build a command for. Known modes: source aot."]])

# byte_machine_add_scheme_lane's own decisions -- argument validation, backend
# routing, and the environment it hands to the registrar: any specification
# failure here means the registration function itself, not the functional
# core above it, stopped doing its job.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: unexpected arguments to the registrar are accepted"
  FIND [[  if(arg_UNPARSED_ARGUMENTS)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a missing NAME, BACKEND, PROGRAM, or TIMEOUT is accepted"
  FIND [[    if(NOT arg_${required})]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a program that does not exist is registered anyway"
  FIND [[  if(NOT EXISTS "${arg_PROGRAM}")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an unknown backend no longer stops registration"
  # Deletes the whole two-clause guard; the companion below narrows it to
  # one clause.
  FIND [[  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "unknown-mode")]]
  REPLACE [[  if(FALSE)]])

# The companion to the mutation above: that one deletes the guard outright,
# this one narrows it to the single unknown-backend clause, so unknown-mode
# fails open while unknown-backend stays refused. unknown-mode is
# reachable through the full registrar even with one backend, because
# byte_machine_add_scheme_lane never compares BACKEND against the NAME's own
# backend segment -- byte_machine_test_name_parse supplies only lane_mode,
# and BACKEND alone routes byte_machine_scheme_lane_command. NAME
# '...cmake.direct' (whose "direct" mode byte_machine_test_name_parse
# accepts, since it validates against cmake's own vocabulary) paired with
# BACKEND chez reaches the chez branch carrying a mode it cannot build,
# which is exactly what "lane-rejects-unknown-mode" in
# ByteMachineSchemeLaneSpec.cmake exercises to witness this.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an unknown mode does not stop registration"
  FIND [[  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "unknown-mode")]]
  REPLACE [[  if(status STREQUAL "unknown-backend")]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a no-runtime backend is registered instead of skipped"
  FIND [[  if(status STREQUAL "no-runtime")]]
  REPLACE [[  if(FALSE)]])

# This is the mutation that matters most: if EXPECT_EXIT stopped being able to
# route to the exit-code registrar, every expected-red test would silently
# become a "must exit 0" test.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: EXPECT_EXIT is ignored, so every lane registers as a plain must-exit-0 test"
  FIND [[  if(DEFINED arg_EXPECT_EXIT)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  # Anchored on ${lane_mode}, the mode byte_machine_test_name_parse reads
  # from the lane's own name. REPLACE means only "the execution mode entry is
  # gone"; the fingerprint-sample entry and arg_ENVIRONMENT are untouched.
  LABEL "scheme-lane: the source execution mode is no longer declared in the environment"
  FIND [[    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"
]]
  REPLACE [[    # deleted
]])

# byte-machine.harness.provenance.chez.source, the one lane that proves the
# provenance check can fail, does it by asking WRONG_FINGERPRINT to route here
# to byte_machine_wrong_fingerprint. If this regressed to always calling
# byte_machine_expected_fingerprint, that lane would compare its declared
# sources' real fingerprint against itself, pass, and stop proving anything --
# and only the slow integration lane would notice, since neither
# ByteMachineSchemeLaneSpec.cmake nor this mutation suite would see anything
# wrong without this entry.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: WRONG_FINGERPRINT is ignored, so every lane routes to byte_machine_expected_fingerprint"
  FIND [[    if(arg_WRONG_FINGERPRINT)]]
  REPLACE [[    if(FALSE)]])

# With this block gone, a lane given WORKING_DIRECTORY launches from its
# derived directory instead, and nothing fails unless a registrar is asked
# whether it received WORKING_DIRECTORY at all. No lane in the tree overrides
# its run directory, so a forwarding break is invisible to every registration.
# What sees it is ByteMachineSchemeLaneSpec.cmake's absent/present assertions
# on the keyword, which this mutation and the one below hold in place.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: WORKING_DIRECTORY is parsed and then never forwarded to either registrar"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(FALSE)]])

# The other direction: forwarding the keyword to whichever registrar the lane
# routed to, unconditionally, even when the lane gave no WORKING_DIRECTORY at
# all. Both registrars' "absent" assertions in ByteMachineSchemeLaneSpec.cmake
# can see this -- the plain path and the exit-code path both splice the same
# working_directory_args, so one mutation here is witnessed by both. One
# direction alone tests only half a conditional.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: WORKING_DIRECTORY is forwarded to either registrar even when the lane did not give one"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(TRUE)]])

# The run directory decides where every lane launches from; the three
# decisions inside byte_machine_test_run_directory each get their own
# mutation: an override that silently stops arriving, or arrives empty,
# launches lanes from the wrong place.
byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: WORKING_DIRECTORY names a directory that need not exist"
  FIND [[  if(arg_WORKING_DIRECTORY AND NOT IS_DIRECTORY "${arg_WORKING_DIRECTORY}")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: the override is parsed and then ignored"
  FIND [[  if(override)
    set(${out_dir} "${override}" PARENT_SCOPE)
    return()
  endif()]]
  REPLACE [[  if(FALSE)
    set(${out_dir} "${override}" PARENT_SCOPE)
    return()
  endif()]])

# The empty-override branch is a decision of its own: treating "" as a value
# would launch every non-overriding lane from the filesystem root.
byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: an empty override is treated as a directory"
  FIND [[  if(override)]]
  REPLACE [[  if(TRUE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a repeated basename is not detected"
  FIND [[    if(base IN_LIST seen)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a duplicate-basename manifest is registered anyway"
  FIND [[  if(duplicate_basenames)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the duplicate detector leaves a stale value when there are none"
  FIND [[  set(seen "")
  set(duplicates "")]]
  REPLACE [[  set(seen "")]])

# The aot lanes and the staleness lane: every decision they rely on in
# ByteMachineSchemeLane.cmake, broken on a staged copy. What is deliberately
# *not* mutated here: the builder's own body (the copy-source-of-record logic,
# the DEPENDS list, the prefix order). Those live inside `add_custom_command`
# arguments the spec's stub never executes; their end-to-end witness is the
# staleness lane itself, permanently registered and asserting exit 3.

# A compiled lane that fingerprints the repository originals instead of the
# build's own copies. Under it the staleness lane's expectation and its
# measurement read the same files, they agree, and the lane that exists to
# exit 3 exits 0. Witnessed with no runtime present by the spec's two-source
# aot case and its one-source registration case.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a compiled lane measures the repository originals"
  FIND [[      byte_machine_lane_measured_copies("${object_dir}/fingerprint" measured ${ARGN})
      set(${out_measured} ${measured} PARENT_SCOPE)]]
  REPLACE [[      set(${out_measured} ${ARGN} PARENT_SCOPE)]])

# harness-fingerprint-combine is order-sensitive by design, so a
# reordered measured list computes a different digest over the same bytes.
# Only a two-or-more-source manifest can see this, which is what the spec's
# example-two case exists for.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the measured list is built in reverse"
  FIND [[    list(APPEND copies "${dir}/${name}")]]
  REPLACE [[    list(PREPEND copies "${dir}/${name}")]])

# The execution mode as the literal `source` for every lane. Distinct from
# the deletion mutation above ("the source execution mode is no longer
# declared"): this one keeps the entry and makes it wrong, which is the defect
# a compiled lane actually suffers. Not caught by the harness's own assertion
# -- that assertion accepts any vocabulary member and `source` is one -- but
# by the spec's "an aot lane declares the aot mode" case, asserted with no
# runtime present, which is why the mode logic lives in the registrar
# rather than in the custom command.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the execution mode is the literal source again"
  FIND [[    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"]]
  REPLACE [[    "BYTE_MACHINE_EXECUTION_MODE=source"]])

# The builder call-site guard, in both directions, per the
# WORKING_DIRECTORY precedent: one direction only tests half a conditional.
# if(FALSE): no aot lane ever gets an artifact -- the spec's "reaches the
# artifacts builder" case fails. if(TRUE): every source lane acquires a
# compile step it must not have -- the spec's "never reaches" case fails.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the artifacts builder is never called"
  FIND [[  if(lane_mode STREQUAL "aot")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the artifacts builder is called for every lane"
  FIND [[  if(lane_mode STREQUAL "aot")]]
  REPLACE [[  if(TRUE)]])

# The stale root is parsed and then not forwarded, so the staleness lane
# would silently compile from the real text and exit 0. The spec's
# "STALE_LIBRARY_ROOT reaches the artifacts builder" case fails.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: STALE_LIBRARY_ROOT is parsed and never forwarded"
  FIND [[      "${arg_NAME}" "${arg_PROGRAM}" "${arg_STALE_LIBRARY_ROOT}" ${arg_SOURCES})]]
  REPLACE [[      "${arg_NAME}" "${arg_PROGRAM}" "" ${arg_SOURCES})]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

byte_machine_mutation_totals(actual_passes actual_mutations)
if(NOT actual_passes EQUAL EXPECTED_PASSES OR NOT actual_mutations EQUAL EXPECTED_MUTATIONS)
  message(FATAL_ERROR
    "byte-machine-mutation: expected ${EXPECTED_PASSES} pass / "
    "${EXPECTED_MUTATIONS} mutations, got ${actual_passes} pass / "
    "${actual_mutations} mutations. A byte_machine_mutation_run call or a "
    "byte_machine_mutation() declaration was deleted (or added without "
    "updating EXPECTED_MUTATIONS above) -- 37/37 elsewhere would not notice.")
endif()

message(STATUS
  "byte-machine-spec: mutation suite complete (${actual_passes} pass, "
  "${actual_mutations} mutations)")
