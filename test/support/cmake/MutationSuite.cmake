# Proof that the CMake-layer specifications are not vacuous.
#
# Each entry below breaks one decision in one module and names the specification
# that must notice. A mutation that survives means that specification passes
# whether the code is right or wrong, which is worse than having no
# specification at all -- an absent test is visibly absent, a vacuous one reports
# success.
#
# This suite exists because the same check was once run by hand and written up
# in a decision record as evidence. Evidence that lives in a transcript is not
# evidence: nobody can rerun it, and it cannot fail when the code changes. The
# hand-run version also missed the most important case, because it only mutated
# the modules and never the assertion helper every specification depends on.
#
# Adding a decision to a module means adding a mutation here. The SITES check
# will tell you when a pattern has drifted; it will not tell you when a new,
# untested decision has been added.
#
# ONE PASS, NINETY-SEVEN MUTATIONS
#
# Every mutation above is declared before the single byte_machine_mutation_run
# call at the end of this file, so this suite is one pass by construction.
# EXPECTED_MUTATIONS below is compared against the accumulated total from
# byte_machine_mutation_totals once that call returns: it is what would have
# caught a whole-branch review finding that deleting an entire pass group from
# SchemeMutationSuite.cmake left that file's own suite at 37/37 -- the same
# blind spot exists here for a single deleted byte_machine_mutation() call,
# which SITES cannot see either, since a missing declaration is not a pattern
# that failed to match.
#
# Ninety-seven is eighty-nine plus eight: five for MutationRunner's own
# verdict decision and the registration guard beside it (the "MutationRunner"
# section below), two for the other direction of the WORKING_DIRECTORY
# forwarding conditional in ByteMachineExpectExit.cmake and
# ByteMachineSchemeLane.cmake, which until a re-review only had the if(FALSE)
# half of its two mutations, and one for the WRONG_FINGERPRINT branch in
# ByteMachineSchemeLane.cmake's manifest block, which had no mutation until a
# review found the routing decision unwitnessed.

cmake_minimum_required(VERSION 3.26)

set(EXPECTED_PASSES 1)
set(EXPECTED_MUTATIONS 97)

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

# --- ByteMachineGambit -----------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: identity check removed, so Ghostscript passes as Gambit"
  FIND [[if(NOT normalized MATCHES "(^|\n)gambit=yes(\n|$)")]]
  REPLACE [[if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: version floor removed"
  FIND [[if(version VERSION_LESS BYTE_MACHINE_GAMBIT_MINIMUM_VERSION)]]
  REPLACE [[if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: 'v' version marker no longer stripped"
  FIND [[if(raw_version MATCHES "^v(.*)$")]]
  REPLACE [[if(FALSE)]])

# The whole condition is replaced rather than one clause: CMake's if() binds AND
# more tightly than OR, so prefixing a single clause with FALSE leaves the other
# comparisons live and the mutation does nothing.
byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: interpreter/compiler agreement no longer required"
  FIND [[  if(NOT interp_version STREQUAL compiler_version
     OR NOT interp_target STREQUAL compiler_target
     OR NOT interp_stamp STREQUAL compiler_stamp)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: compiler derived from a filename that is not gsi"
  FIND [[if(NOT name MATCHES "^gsi(.*)$")]]
  REPLACE [[if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: compiler derived from a relative path"
  FIND [[if(dir STREQUAL "")]]
  REPLACE [[if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: a hand-set compiler is overwritten by a derivation"
  FIND [[  if(NOT cached STREQUAL recorded_derivation)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: a stale derivation is reused instead of following the interpreter"
  FIND [[  byte_machine_gambit_compiler_beside("${interpreter}" fresh)
  set(${out_path} "${fresh}" PARENT_SCOPE)
  set(${out_derived_from} "${interpreter}" PARENT_SCOPE)
endfunction()]]
  REPLACE [[  set(${out_path} "${cached}" PARENT_SCOPE)
  set(${out_derived_from} "${derived_from}" PARENT_SCOPE)
endfunction()]])

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: an empty cache is treated as a hand-set compiler"
  FIND [[  if(NOT cached)]]
  REPLACE [[  if(FALSE)]])

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
# these two functions. Break either and all four specifications stayed green --
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
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: absent version floor no longer refused, so the guard fails open"
  FIND [[  if(NOT BYTE_MACHINE_GAMBIT_MINIMUM_VERSION MATCHES "^[0-9]+\\.[0-9]+")]]
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

byte_machine_mutation(
  FILE cmake/ByteMachineGambit.cmake SPEC ByteMachineGambitSpec.cmake
  LABEL "gambit: unset GAMBIT_HOME contributes a bare /bin hint outranking PATH"
  FIND [[  if(DEFINED ENV{GAMBIT_HOME} AND NOT "$ENV{GAMBIT_HOME}" STREQUAL "")]]
  REPLACE [[  if(TRUE)]]
  EXPECT_SURVIVES
    "lives in the discovery macro, which runs processes and reads the real environment; it is covered by configure-time behaviour, not by the cmake -P specifications")

# --- MutationRunner (byte_machine_mutation_verdict and its registration) ---
#
# The machinery every specification above is trusted through, and the one
# module in this directory that had neither a specification nor a mutation
# targeting it -- even though it is staged like everything else. A re-review
# found that the fix narrowing "caught" to "caught for the declared reason"
# had reproduced the same defect class one layer down: the `elseif`
# translating a wrong-reason result into a failure could be deleted by hand
# and the whole suite stayed 89/89, because nothing mutated the decision that
# branch depends on. These mutations are what closes that.

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

# A reviewer once deleted this exact block by hand from
# ByteMachineSchemeLane.cmake's copy of the same shape (below) and ran the
# whole suite: 37/37 passed, because nothing forwarded WORKING_DIRECTORY far
# enough to notice it stopped arriving. This is that block's other occurrence
# -- the registrar itself, not a caller of it -- and until the WORKING_DIRECTORY
# assertions in ByteMachineExpectExitSpec.cmake, its path was exercised by
# nothing at all: every case that reaches byte_machine_add_exit_code_test in
# that specification is rejected before this line runs.
byte_machine_mutation(
  FILE cmake/ByteMachineExpectExit.cmake SPEC ByteMachineExpectExitSpec.cmake
  LABEL "expect-exit: WORKING_DIRECTORY is parsed and then never forwarded to the registrar"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(FALSE)]])

# The other direction of the same conditional: forwarding the keyword to the
# registrar unconditionally, even when the caller gave no WORKING_DIRECTORY at
# all. A re-review found this direction just as unwitnessed as the one above
# was before it got a mutation: only ByteMachineExpectExitSpec.cmake's
# "absent" assertion can see a keyword arriving that should not have, and
# nothing mutated the condition to make it arrive.
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
  LABEL "scheme-lane: gambit no longer skips .gambini"
  FIND [[      "-f"
]]
  # Same reasoning as the object-guard mutation above.
  REPLACE [[  # deleted
]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an undiscovered chez yields a command with an empty executable"
  FIND [[    if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an undiscovered gambit yields a command with an empty executable"
  FIND [[    if(NOT BYTE_MACHINE_GAMBIT_EXECUTABLE)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: an unknown backend is reported as usable"
  FIND [[  set(${out_status} "unknown-backend" PARENT_SCOPE)]]
  REPLACE [[  set(${out_status} "ok" PARENT_SCOPE)]])

# Diagnostic wording is asserted exactly (see ByteMachineSchemeLaneSpec.cmake),
# so each message the functional core can produce gets its own mutation: a
# dropped interpolation, a copy-pasted wrong backend name, and a one-word typo.
# Any of the three would otherwise pass every existing assertion undetected.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the chez no-runtime message drops its program interpolation"
  FIND [[        "no Chez was discovered, so the chez source lane for '${program}' is not registered."]]
  REPLACE [[        "no Chez was discovered, so the chez source lane is not registered."]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the gambit no-runtime message names the wrong backend"
  FIND [[        "no Gambit was discovered, so the gambit source lane for '${program}' is not registered."]]
  REPLACE [[        "no Gambit was discovered, so the chez source lane for '${program}' is not registered."]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the unknown-backend message is garbled"
  FIND [[    "'${backend}' is not a Scheme lane backend. Known backends: chez gambit."]]
  REPLACE [[    "'${backend}' is not a Scheme land backend. Known backends: chez gambit."]])

# byte_machine_add_scheme_lane's own decisions -- argument validation, backend
# routing, and the environment it hands to the registrar -- had no coverage at
# all before this: any specification failure here means the registration
# function itself, not the functional core above it, stopped doing its job.
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
  # Re-anchored on the three-clause form the Gambit search-root check added:
  # the single-clause pattern this mutation used to match no longer occurs
  # anywhere in the file (see MutationRunner.cmake's SITES comment -- a pattern
  # that stops matching after a refactor must be updated, not deleted). REPLACE
  # is unchanged: this mutation still means "the whole fatal-error guard is
  # gone", which is a different break than the narrower one below.
  FIND [[  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "comma-in-path"
     OR status STREQUAL "relative-path")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a no-runtime backend is registered instead of skipped"
  FIND [[  if(status STREQUAL "no-runtime")]]
  REPLACE [[  if(FALSE)]])

# This is the mutation that matters most: if EXPECT_EXIT stopped being able to
# route to the exit-code registrar, every expected-red test in this milestone
# would silently become a "must exit 0" test.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: EXPECT_EXIT is ignored, so every lane registers as a plain must-exit-0 test"
  FIND [[  if(DEFINED arg_EXPECT_EXIT)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  # Re-anchored on ${lane_mode}: M0 slice 5b Task 1 replaced the literal
  # "source" with the mode byte_machine_test_name_parse reads from the lane's
  # own name (see MutationRunner.cmake's SITES comment -- a pattern that stops
  # matching after a refactor must be updated, not deleted). REPLACE still
  # means only "the execution mode entry is gone"; the fingerprint-sample
  # entry and arg_ENVIRONMENT are untouched, exactly as before this
  # re-anchoring.
  LABEL "scheme-lane: the source execution mode is no longer declared in the environment"
  FIND [[    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"
]]
  REPLACE [[    # deleted
]])

# byte-machine.harness.provenance.*'s four lanes prove the provenance check
# can fail by asking WRONG_FINGERPRINT to route here to
# byte_machine_wrong_fingerprint. If this regressed to always calling
# byte_machine_expected_fingerprint, every one of those lanes would compare
# its shared bodies' real fingerprint against itself, pass, and stop proving
# anything -- and only the slow integration lanes would notice, since neither
# ByteMachineSchemeLaneSpec.cmake nor this mutation suite would see anything
# wrong without this entry.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: WRONG_FINGERPRINT is ignored, so every lane routes to byte_machine_expected_fingerprint"
  FIND [[    if(arg_WRONG_FINGERPRINT)]]
  REPLACE [[    if(FALSE)]])

# This is the mutation a whole-branch review found undetectable: delete this
# block by hand, reconfigure, and the working-directory matrix's six lanes all
# launch from their derived directories instead of the three fixture
# directories test/CMakeLists.txt built for them -- six copies of one vacuous
# lane, and nothing anywhere failed, because neither registrar this block
# feeds was ever asked whether it received WORKING_DIRECTORY at all.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: WORKING_DIRECTORY is parsed and then never forwarded to either registrar"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(FALSE)]])

# The other direction: forwarding the keyword to whichever registrar the lane
# routed to, unconditionally, even when the lane gave no WORKING_DIRECTORY at
# all. Both registrars' "absent" assertions in ByteMachineSchemeLaneSpec.cmake
# can see this -- the plain path and the exit-code path both splice the same
# working_directory_args, so one mutation here is witnessed by both -- but
# until now nothing mutated the condition to make the keyword arrive
# unwanted, the same blind spot the if(FALSE) mutation above used to be alone
# in closing.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: WORKING_DIRECTORY is forwarded to either registrar even when the lane did not give one"
  FIND [[  if(arg_WORKING_DIRECTORY)]]
  REPLACE [[  if(TRUE)]])

# A comma in a Gambit search root is not a wrong path but a malformed -:
# option list: gsi prints its usage banner and runs no Scheme at all, on every
# Gambit lane at once. A relative root is resolved against gsi's own working
# directory, so a lane would find its libraries or not depending on where
# CTest launched it. Both are configure-time refusals, so each gets its own
# mutation alongside the wrong-separator case, which would corrupt every
# multi-root search silently rather than refusing it.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: a comma in a Gambit search root is accepted"
  FIND [[    if(dir MATCHES ",")]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: the search roots are joined with the wrong separator"
  FIND [[  list(JOIN parts "," joined)]]
  REPLACE [[  list(JOIN parts ";" joined)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: a relative Gambit search root is accepted"
  FIND [[    if(NOT IS_ABSOLUTE "${dir}")]]
  REPLACE [[    if(FALSE)]])

# The two output variables are cleared up front so that a caller-supplied
# stale value cannot leak through on either the accepted path (which never
# rewrites the message) or the rejected path (which never rewrites the
# option). Without this clear, a lane that reused a variable from an earlier
# call could see the earlier call's answer instead of this one's.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: the gambit search function's up-front output clear is deleted, so a stale caller-supplied option or message can survive a call"
  FIND [[  set(${out_option} "" PARENT_SCOPE)
  set(${out_message} "" PARENT_SCOPE)]]
  REPLACE [[  ]])

# The comma check must run first: a comma malforms the -: option list and
# silences gsi -- and therefore every Gambit lane at once -- while a relative
# root only misleads the one lane that carries it. This mutation keeps both
# checks intact and only swaps their order, so it is caught solely by the
# both-defects assertion in the specification; every single-defect case
# supplies a root with exactly one problem and cannot see the checks
# reordered.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: the Gambit search checks are reordered, so a root with both defects reports relative-path instead of comma-in-path"
  FIND [[    if(dir MATCHES ",")
      set(${out_status} "comma-in-path" PARENT_SCOPE)
      set(${out_message}
        "a Gambit search root must not contain a comma, but '${dir}' does. Gambit's -: options are comma-separated, so gsi would print its usage banner and run no Scheme at all."
        PARENT_SCOPE)
      return()
    endif()
    if(NOT IS_ABSOLUTE "${dir}")
      set(${out_status} "relative-path" PARENT_SCOPE)
      set(${out_message}
        "a Gambit search root must be absolute, but '${dir}' is not. Gambit resolves a relative root against its own working directory, so the lane would find its libraries or not depending on where it was launched."
        PARENT_SCOPE)
      return()
    endif()]]
  REPLACE [[    if(NOT IS_ABSOLUTE "${dir}")
      set(${out_status} "relative-path" PARENT_SCOPE)
      set(${out_message}
        "a Gambit search root must be absolute, but '${dir}' is not. Gambit resolves a relative root against its own working directory, so the lane would find its libraries or not depending on where it was launched."
        PARENT_SCOPE)
      return()
    endif()
    if(dir MATCHES ",")
      set(${out_status} "comma-in-path" PARENT_SCOPE)
      set(${out_message}
        "a Gambit search root must not contain a comma, but '${dir}' does. Gambit's -: options are comma-separated, so gsi would print its usage banner and run no Scheme at all."
        PARENT_SCOPE)
      return()
    endif()]])

# The companion to the re-anchored "an unknown backend no longer stops
# registration" mutation above: that one deletes the guard outright, this one
# narrows it back to the pre-Task-3 single clause, so comma-in-path and
# relative-path would fail open while unknown-backend stayed refused. Two
# distinct regressions, so two mutations.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: a refused search list does not stop registration"
  FIND [[  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "comma-in-path"
     OR status STREQUAL "relative-path")]]
  REPLACE [[  if(status STREQUAL "unknown-backend")]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: gambit's source mode is withdrawn"
  FIND [[set(BYTE_MACHINE_TEST_MODES_gambit source o1 aot)]]
  REPLACE [[set(BYTE_MACHINE_TEST_MODES_gambit o1 aot)]])

# The run directory is where slice 3's working-directory matrix hangs: a lane
# that overrides it is asserting something about where resolution happens, so
# each of the three decisions inside byte_machine_test_run_directory gets its
# own mutation.
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

# --- ByteMachinePortabilityGuard --------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: wrapper files are counted as shared bodies"
  FIND [[  list(FILTER bodies EXCLUDE REGEX "\\.(chez|gambit)\\.(sps|scm)$")]]
  # Same empty-REPLACE hazard as the expect-exit and scheme-lane mutations
  # above (CMP0174; this project's 3.26 floor leaves an explicitly-empty
  # REPLACE undefined rather than empty -- see those mutations' comments).
  # FIND's match ends at the statement's own closing paren, not the line's
  # trailing newline, so the comment needs none of its own.
  REPLACE [[  # deleted]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: a repeated basename is not reported"
  FIND [[    if(base IN_LIST seen)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: only the Chez wrapper is required"
  FIND [[    foreach(wrapper "${dir}/${base}.chez.sps" "${dir}/${base}.gambit.scm")]]
  REPLACE [[    foreach(wrapper "${dir}/${base}.chez.sps")]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: the duplicate accessor leaves a stale value when there are none"
  FIND [[  set(seen "")
  set(duplicates "")]]
  REPLACE [[  set(seen "")]])

# The imperative shell. Every decision it makes is observable only as a dead
# process -- a guard that returns has, by construction, found nothing to say --
# so each of these is caught by a rejection case in the specification rather
# than by an assertion on a returned value. The script-mode mutation is what
# proves those cases reach the guard at all: with that branch gone,
# CONFIGURE_DEPENDS makes the function uncallable under `cmake -P` and every
# case dies before reaching the decision it was written for.

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: unexpected arguments to the guard are accepted"
  FIND [[  if(arg_UNPARSED_ARGUMENTS)]]
  REPLACE [[  if(FALSE)]])

# The companion to the one above: the check that catches a mistyped keyword the
# parser has already absorbed into the preceding keyword's value, where
# arg_UNPARSED_ARGUMENTS is empty and cannot see it.
byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: an entry that is not a directory is accepted"
  FIND [[      if(NOT IS_DIRECTORY "${entry}")]]
  REPLACE [[      if(FALSE)]])

# ...and the reach of that check. Deleting the condition (above) and narrowing
# the set of keywords it runs over (here) are two decisions, so they get two
# mutations: a single combined one would prove only that at least one of them
# was noticed.
byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: only SHARED_DIRS entries are checked for being directories"
  # Anchored on the preceding line: the body-collecting loop below iterates the
  # same two keywords, so the bare `foreach` matches two sites and the SITES
  # check rejects it. The two loops are deliberately separate -- every entry has
  # to be judged a directory before any of them is globbed, or a bad entry
  # sitting after a good one would be reported as having contributed nothing
  # rather than as not being a directory at all.
  FIND [[  # what makes the second form reachable; both forms have a rejection case.
  foreach(keyword IN ITEMS SHARED_DIRS WRAPPED_DIRS)]]
  REPLACE [[  # what makes the second form reachable; both forms have a rejection case.
  foreach(keyword IN ITEMS SHARED_DIRS)]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: the glob asks for a build-system re-check where there is no build system"
  FIND [[  if(CMAKE_SCRIPT_MODE_FILE)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: a call naming no directories at all is accepted"
  FIND [[  if(NOT bodies)]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: a duplicate basename is reported without stopping the build"
  FIND [[    message(FATAL_ERROR
      "byte-machine: shared body basenames must be unique across every shared "]]
  REPLACE [[    message(STATUS
      "byte-machine: shared body basenames must be unique across every shared "]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: a missing wrapper is reported without stopping the build"
  FIND [[    message(FATAL_ERROR
      "byte-machine: every shared test body needs a wrapper for each runtime, "]]
  REPLACE [[    message(STATUS
      "byte-machine: every shared test body needs a wrapper for each runtime, "]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: wrappers are demanded of the shared directories, not the wrapped ones"
  FIND [[      if(keyword STREQUAL "WRAPPED_DIRS")]]
  REPLACE [[      if(keyword STREQUAL "SHARED_DIRS")]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: only the top level of a declared directory is searched"
  # The whole point of the recursion. Without it a body in a subdirectory is
  # not rejected -- it is unseen, so it is neither checked for a colliding
  # basename nor required to have wrappers, and the banner covers a file that
  # was never read.
  FIND [[      file(GLOB_RECURSE dir_globbed ${glob_depends} "${dir}/*.scm")]]
  REPLACE [[      file(GLOB dir_globbed ${glob_depends} "${dir}/*.scm")]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: a declared directory that yields no body is accepted"
  # Distinct from the whole-call check below, which sees only that *everything*
  # found nothing: this is what notices one empty directory standing beside a
  # populated one, and it is the check slice 3 needs when src/common joins the
  # guard holding only a .gitkeep.
  FIND [[      if(NOT dir_bodies)]]
  REPLACE [[      if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: bodies are collected from the shared directories only"
  # Anchored on the preceding line, for the same reason as the entry-check loop
  # above: the two loops iterate the same two keywords.
  FIND [[  set(wrapped "")
  foreach(keyword IN ITEMS SHARED_DIRS WRAPPED_DIRS)]]
  REPLACE [[  set(wrapped "")
  foreach(keyword IN ITEMS SHARED_DIRS)]])

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
