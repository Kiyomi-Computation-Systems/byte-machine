# Specification for cmake/ByteMachineExpectExit.cmake.
#
# CTest's WILL_FAIL only distinguishes zero from nonzero, so it accepts a crash,
# a missing library, or a failure to launch as proof that an assertion failed.
# This module compares the exact status instead, which means it has to say what
# the legal statuses even are -- and has to tell an out-of-vocabulary status
# apart from a wrong one, because those are different defects. A Gambit program
# whose file is missing exits 70; reporting that as "expected 1, got 70" would
# send a reader looking for a failed assertion that never ran.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachineExpectExit.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  # byte_machine_add_test belongs to a project context this script does not
  # have. Stubbing it is what lets the registration function's own validation be
  # exercised: without this case, deleting the classify call from the registrar
  # would leave every assertion below green.
  function(byte_machine_add_test)
  endfunction()

  if(c STREQUAL "registration-rejects-undeclared-status")
    byte_machine_add_exit_code_test(
      NAME byte-machine.harness.example.chez.source
      COMMAND "/bin/true"
      EXPECT_EXIT 7
      TIMEOUT 10)
  elseif(c STREQUAL "registration-rejects-non-numeric-status")
    byte_machine_add_exit_code_test(
      NAME byte-machine.harness.example.chez.source
      COMMAND "/bin/true"
      EXPECT_EXIT "one"
      TIMEOUT 10)
  elseif(c STREQUAL "registration-requires-expectation")
    byte_machine_add_exit_code_test(
      NAME byte-machine.harness.example.chez.source
      COMMAND "/bin/true"
      TIMEOUT 10)
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Driver ----------------------------------------------------------------

# The vocabulary is the whole point of the module; assert it explicitly so a
# silent widening is visible here rather than in a test that starts passing.
spec_check_equal("${BYTE_MACHINE_EXIT_STATUS_VOCABULARY}" "0;1;2;3"
  "declared exit-status vocabulary")

foreach(code 0 1 2 3)
  byte_machine_expect_exit_classify("${code}" status message)
  spec_check_equal("${status}" "ok" "classify accepts declared status ${code}")
endforeach()

byte_machine_expect_exit_classify("7" status message)
spec_check_equal("${status}" "not-declared" "classify rejects 7")

set(status "seed")
byte_machine_expect_exit_classify("77" status message)
spec_check_equal("${status}" "not-declared" "classify rejects 77")

byte_machine_expect_exit_classify("one" status message)
spec_check_equal("${status}" "not-a-number" "classify rejects a non-number")

# Seeded, so a classifier that never writes its output is distinguishable from
# one that writes the right thing. An assertion against an unseeded variable is
# satisfied by a function that does nothing at all.
set(message "seed")
byte_machine_expect_exit_classify("0" status message)
spec_check_equal("${message}" "" "classify clears the message on success")

byte_machine_expect_exit_verdict("1" "1" verdict message)
spec_check_equal("${verdict}" "ok" "verdict: exact match")

byte_machine_expect_exit_verdict("1" "2" verdict message)
spec_check_equal("${verdict}" "mismatch" "verdict: a declared but wrong status is a mismatch")

# 70 is what Gambit exits when it cannot find the program file. It must not be
# reported as a wrong assertion outcome.
byte_machine_expect_exit_verdict("1" "70" verdict message)
spec_check_equal("${verdict}" "out-of-vocabulary" "verdict: 70 is out of vocabulary")

set(verdict "seed")
byte_machine_expect_exit_verdict("0" "139" verdict message)
spec_check_equal("${verdict}" "out-of-vocabulary" "verdict: a crash is out of vocabulary")

# execute_process reports a failure to run at all as a non-numeric result.
byte_machine_expect_exit_verdict("0" "Process terminated due to timeout" verdict message)
spec_check_equal("${verdict}" "did-not-run" "verdict: a non-numeric result did not run")

set(message "seed")
byte_machine_expect_exit_verdict("2" "2" verdict message)
spec_check_equal("${message}" "" "verdict clears the message on success")

spec_expect_all_rejected("${SPEC_SELF}"
  "registration-rejects-undeclared-status|is not a declared harness status"
  "registration-rejects-non-numeric-status|must be a whole number"
  "registration-requires-expectation|must declare EXPECT_EXIT")

spec_finish("ByteMachineExpectExit")
