# Specification for the functional core of cmake/ByteMachineTesting.cmake.
#
# The registration helper decides which tests exist at all, so a defect here is
# invisible in the worst way: a malformed or duplicated registration produces a
# suite that runs fewer tests than it appears to and still reports success. Each
# rule is therefore enforced at configure time and specified before anything
# relies on it.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachineTesting.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  if(c STREQUAL "too-few-segments")
    byte_machine_test_name_parse("byte-machine.unit.graph.chez" l f b m)
  elseif(c STREQUAL "uppercase")
    byte_machine_test_name_parse("byte-machine.unit.Graph.chez.source" l f b m)
  elseif(c STREQUAL "wrong-prefix")
    byte_machine_test_name_parse("bytemachine.unit.graph.chez.source" l f b m)
  elseif(c STREQUAL "unknown-layer")
    byte_machine_test_name_parse("byte-machine.smoke.graph.chez.source" l f b m)
  elseif(c STREQUAL "unknown-backend")
    byte_machine_test_name_parse("byte-machine.unit.graph.guile.source" l f b m)
  elseif(c STREQUAL "incompatible-mode")
    # Chez has no .o1 lane; the mode exists but not for this backend.
    byte_machine_test_name_parse("byte-machine.unit.graph.chez.o1" l f b m)
  elseif(c STREQUAL "feature-leading-hyphen")
    byte_machine_test_name_parse("byte-machine.unit.-graph.chez.source" l f b m)
  elseif(c STREQUAL "feature-trailing-hyphen")
    byte_machine_test_name_parse("byte-machine.unit.graph-.chez.source" l f b m)
  elseif(c STREQUAL "unknown-label")
    byte_machine_test_validate_labels(unit bogus)
  elseif(c STREQUAL "duplicate-name")
    byte_machine_test_reserve_name("byte-machine.unit.graph.chez.source")
    byte_machine_test_reserve_name("byte-machine.unit.graph.chez.source")
  elseif(c STREQUAL "missing-timeout")
    byte_machine_test_require_timeout("" "byte-machine.unit.graph.chez.source")
  elseif(c STREQUAL "zero-timeout")
    byte_machine_test_require_timeout("0" "byte-machine.unit.graph.chez.source")
  elseif(c STREQUAL "noninteger-timeout")
    byte_machine_test_require_timeout("30s" "byte-machine.unit.graph.chez.source")
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Positive --------------------------------------------------------------

byte_machine_test_name_parse("byte-machine.unit.graph.chez.source" l f b m)
spec_check_equal("${l}" "unit" "layer")
spec_check_equal("${f}" "graph" "feature")
spec_check_equal("${b}" "chez" "backend")
spec_check_equal("${m}" "source" "mode")

# Every backend/mode pair the project actually has a lane for must parse. These
# are the four lanes of the execution model, and a helper that rejected one
# would silently delete that lane's coverage.
foreach(pair "chez.source" "chez.aot" "gambit.o1" "gambit.aot" "cmake.direct")
  byte_machine_test_name_parse("byte-machine.unit.graph.${pair}" l f b m)
endforeach()

# A multi-word feature with interior hyphens is fine; only the edges are barred.
byte_machine_test_name_parse("byte-machine.differential.span-boundary.gambit.o1" l f b m)
spec_check_equal("${f}" "span-boundary" "hyphenated feature")

# Gambit's interpreted lane. Without it the harness cannot run on Gambit at all
# without a C toolchain.
byte_machine_test_name_parse(
  "byte-machine.harness.self.gambit.source" layer feature backend mode)
spec_check_equal("${mode}" "source" "gambit accepts the source mode")
spec_check_equal("${backend}" "gambit" "gambit source parses its backend")

byte_machine_test_validate_labels(unit chez source)
byte_machine_test_reserve_name("byte-machine.unit.unique-one.chez.source")
byte_machine_test_reserve_name("byte-machine.unit.unique-two.chez.source")
byte_machine_test_require_timeout("120" "byte-machine.unit.graph.chez.source")

# --- Negative --------------------------------------------------------------

set(negative_cases
  "too-few-segments|byte-machine: malformed test name"
  "uppercase|byte-machine: malformed test name"
  "wrong-prefix|byte-machine: malformed test name"
  "unknown-layer|byte-machine: unknown test layer 'smoke'"
  "unknown-backend|byte-machine: unknown test backend 'guile'"
  "incompatible-mode|byte-machine: incompatible backend/mode"
  "feature-leading-hyphen|Feature segment '-graph' must not begin or end with a hyphen"
  "feature-trailing-hyphen|Feature segment 'graph-' must not begin or end with a hyphen"
  "unknown-label|byte-machine: unknown test label 'bogus'"
  "duplicate-name|byte-machine: duplicate test name"
  "missing-timeout|byte-machine: TIMEOUT is required"
  "zero-timeout|byte-machine: TIMEOUT for .* must be a positive whole number"
  "noninteger-timeout|byte-machine: TIMEOUT for .* must be a positive whole number")

spec_expect_all_rejected("${SPEC_SELF}" ${negative_cases})

spec_finish("ByteMachineTesting")
