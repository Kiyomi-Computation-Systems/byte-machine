# Specification for cmake/ByteMachineSchemeLane.cmake.
#
# A lane's command line is where a source lane quietly stops being a source
# lane. Chez needs its object-guard pair to make a compiled object unloadable,
# and Gambit needs -f so a developer's .gambini cannot change a test result.
# Both are invisible when they are missing: the lane still runs and still
# passes, having proved something other than what it claims.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachineSchemeLane.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

if(DEFINED BYTE_MACHINE_SPEC_CASE)
  set(c "${BYTE_MACHINE_SPEC_CASE}")

  # Neither registrar belongs to a project context this script does not have
  # -- add_test is not scriptable under cmake -P. Stubbing both is what keeps
  # a rejection that stopped rejecting from crashing on that unrelated error
  # instead of falling through to the "must be rejected" check below, which is
  # what actually proves the case.
  function(byte_machine_add_test)
  endfunction()
  function(byte_machine_add_exit_code_test)
  endfunction()

  if(c STREQUAL "lane-rejects-unparsed-arguments")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10
      unexpected-extra-argument)
  elseif(c STREQUAL "lane-requires-name")
    byte_machine_add_scheme_lane(
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-backend")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-program")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      TIMEOUT 10)
  elseif(c STREQUAL "lane-requires-timeout")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}")
  elseif(c STREQUAL "lane-requires-existing-program")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "/h/self/does-not-exist.chez.sps"
      TIMEOUT 10)
  elseif(c STREQUAL "lane-rejects-unknown-backend")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND guile
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
  else()
    message(FATAL_ERROR "byte-machine-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "byte-machine-spec: case '${c}' was accepted but must be rejected")
endif()

set(BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER "/h/launchers/chez-source.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "/h/chez")
set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "/h/gambit")
set(BYTE_MACHINE_HARNESS_SHARED_DIR "/h/shared")
set(BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR "/b/guard")

# --- Chez ------------------------------------------------------------------

set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
byte_machine_scheme_lane_command(chez "/h/self/p.chez.sps" command status message)
spec_check_equal("${status}" "ok" "chez lane classifies")
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;/h/chez;/h/shared;/b/guard;/h/self/p.chez.sps"
  "chez lane command line")

# The guard directory is the entire mechanism that stops a stale .so from being
# loaded in a lane that calls itself source. Asserted by position, because
# dropping it would leave a command that still runs.
list(GET command 5 guard)
spec_check_equal("${guard}" "/b/guard" "chez lane passes the object guard directory")

# --- Gambit ----------------------------------------------------------------

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
byte_machine_scheme_lane_command(gambit "/h/self/p.gambit.scm" command status message)
spec_check_equal("${status}" "ok" "gambit lane classifies")
spec_check_equal("${command}"
  "/opt/gsi;-:search=/h/gambit;-f;/h/self/p.gambit.scm"
  "gambit lane command line")

# Gambit requires its -: runtime options to be the very first argument, and -f
# must be present or a developer's .gambini can change what a test proves.
list(GET command 1 first_option)
spec_check_equal("${first_option}" "-:search=/h/gambit" "gambit runtime option comes first")
list(FIND command "-f" f_index)
spec_check_equal("${f_index}" "2" "gambit lane skips initialisation files")

# --- Rejections ------------------------------------------------------------

# Diagnostics carry a stable prefix precisely so a specification can assert the
# exact wording, not merely a nonzero status. Asserted here for all three
# messages the functional core can produce: a typo, a dropped interpolation, or
# a garbled string would otherwise pass every existing assertion undetected.
byte_machine_scheme_lane_command(guile "/h/self/p.scm" command status message)
spec_check_equal("${status}" "unknown-backend" "an unknown backend is rejected")
spec_check_equal("${message}"
  "'guile' is not a Scheme lane backend. Known backends: chez gambit."
  "unknown backend message")

set(BYTE_MACHINE_CHEZ_EXECUTABLE "")
byte_machine_scheme_lane_command(chez "/h/self/p.chez.sps" command status message)
spec_check_equal("${status}" "no-runtime" "a chez lane without a chez is not registered")
spec_check_equal("${command}" "" "a rejected lane returns no command")
spec_check_equal("${message}"
  "no Chez was discovered, so the chez source lane for '/h/self/p.chez.sps' is not registered."
  "chez lane no-runtime message")

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "")
byte_machine_scheme_lane_command(gambit "/h/self/p.gambit.scm" command status message)
spec_check_equal("${status}" "no-runtime" "a gambit lane without a gambit is not registered")
spec_check_equal("${message}"
  "no Gambit was discovered, so the gambit source lane for '/h/self/p.gambit.scm' is not registered."
  "gambit lane no-runtime message")

# --- Registration (byte_machine_add_scheme_lane) ----------------------------
#
# add_test is not scriptable under cmake -P, so the two registrars are stubbed
# here too, this time to record which one byte_machine_add_scheme_lane reached
# and with what arguments rather than to stand aside for a rejection. Routing
# and the environment prefix live directly in this function with no pure
# helper underneath, so stubbing its two dependencies is the only way to
# observe them at all.
function(byte_machine_add_test)
  cmake_parse_arguments(PARSE_ARGV 0 s "" "NAME;TIMEOUT" "COMMAND;LABELS;ENVIRONMENT")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "plain")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT "${s_ENVIRONMENT}")
endfunction()

function(byte_machine_add_exit_code_test)
  cmake_parse_arguments(PARSE_ARGV 0 s "" "NAME;EXPECT_EXIT;TIMEOUT" "COMMAND;LABELS;ENVIRONMENT")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "exit-code")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_EXPECT_EXIT "${s_EXPECT_EXIT}")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT "${s_ENVIRONMENT}")
endfunction()

# An EXPECT_EXIT lane must route to the exit-code registrar and forward the
# code. Both this registration and the plain one below must carry the source
# execution mode ahead of whatever the caller supplied -- the one fact the
# launcher itself cannot assert about its own invocation.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  TIMEOUT 10
  EXPECT_EXIT 1
  ENVIRONMENT "FOO=bar")
get_property(registrar GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR)
spec_check_equal("${registrar}" "exit-code" "EXPECT_EXIT routes to the exit-code registrar")
get_property(expect_exit GLOBAL PROPERTY BYTE_MACHINE_SPEC_EXPECT_EXIT)
spec_check_equal("${expect_exit}" "1" "EXPECT_EXIT is forwarded to the exit-code registrar")
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
spec_check_equal("${environment}" "BYTE_MACHINE_EXECUTION_MODE=source;FOO=bar"
  "exit-code registration carries the source execution mode ahead of caller-supplied entries")

set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  TIMEOUT 10
  ENVIRONMENT "FOO=bar")
get_property(registrar GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR)
spec_check_equal("${registrar}" "plain" "a lane without EXPECT_EXIT routes to the plain registrar")
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
spec_check_equal("${environment}" "BYTE_MACHINE_EXECUTION_MODE=source;FOO=bar"
  "plain registration carries the source execution mode ahead of caller-supplied entries")

# A no-runtime backend must skip registration silently: neither registrar may
# be reached. This runs in-process rather than through spec_expect_rejected, so
# simply reaching the assertion below is itself proof that nothing raised.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  TIMEOUT 10)
get_property(registrar GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR)
spec_check_equal("${registrar}" "none" "a no-runtime backend registers nothing and does not raise")

spec_expect_all_rejected("${SPEC_SELF}"
  "lane-rejects-unparsed-arguments|unexpected arguments to byte_machine_add_scheme_lane"
  "lane-requires-name|NAME is required for byte_machine_add_scheme_lane"
  "lane-requires-backend|BACKEND is required for byte_machine_add_scheme_lane"
  "lane-requires-program|PROGRAM is required for byte_machine_add_scheme_lane"
  "lane-requires-timeout|TIMEOUT is required for byte_machine_add_scheme_lane"
  "lane-requires-existing-program|names a program that does not exist"
  "lane-rejects-unknown-backend|is not a Scheme lane backend")

spec_finish("ByteMachineSchemeLane")
