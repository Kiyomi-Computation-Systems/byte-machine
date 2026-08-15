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

cmake_minimum_required(VERSION 3.26)

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

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

message(STATUS "byte-machine-spec: mutation suite complete")
