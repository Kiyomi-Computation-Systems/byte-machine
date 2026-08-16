# Register one execution lane: a program, run by one runtime, in one mode.
#
# WHY THE COMMAND LINE IS BUILT IN ONE PLACE
#
# Ten registrations that each spell out their own invocation drift. The two
# details most worth not drifting are invisible when they are wrong: Chez's
# object-guard pair, without which a stale compiled object is silently preferred
# over the source a "source" lane claims to run, and Gambit's -f, without which
# a developer's .gambini file participates in every test result.
#
# Slice 2 registers only source lanes. The compiled lanes arrive in slice 5 and
# extend this module rather than replacing it.

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/ByteMachineExpectExit.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/ByteMachineTesting.cmake")

# --- Functional core -------------------------------------------------------

# byte_machine_scheme_lane_command(<backend> <program>
#                                  <out_command> <out_status> <out_message>)
#
# Status is `ok`, `no-runtime`, or `unknown-backend`. A missing runtime is not
# fatal: the CMake-layer specifications must stay runnable on a host with no
# Scheme installed, so a lane whose runtime was never discovered is skipped with
# a message rather than failing configuration.
function(byte_machine_scheme_lane_command backend program
         out_command out_status out_message)
  set(${out_command} "" PARENT_SCOPE)
  set(${out_message} "" PARENT_SCOPE)

  if(backend STREQUAL "chez")
    if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
      set(${out_status} "no-runtime" PARENT_SCOPE)
      set(${out_message}
        "no Chez was discovered, so the chez source lane for '${program}' is not registered."
        PARENT_SCOPE)
      return()
    endif()
    # The launcher takes its four paths positionally: library root, shared body
    # directory, object guard, program.
    set(${out_command}
      "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
      "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
      "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
      "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
      "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
      "${program}"
      PARENT_SCOPE)
    set(${out_status} "ok" PARENT_SCOPE)
    return()
  endif()

  if(backend STREQUAL "gambit")
    if(NOT BYTE_MACHINE_GAMBIT_EXECUTABLE)
      set(${out_status} "no-runtime" PARENT_SCOPE)
      set(${out_message}
        "no Gambit was discovered, so the gambit source lane for '${program}' is not registered."
        PARENT_SCOPE)
      return()
    endif()
    # `-:` runtime options must be the first argument; `-f` skips .gambini so a
    # developer's personal initialisation cannot change what a test proves.
    # No launcher is needed: Gambit's include inside define-library is
    # source-file-relative and needs no ambient state.
    set(${out_command}
      "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
      "-:search=${BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT}"
      "-f"
      "${program}"
      PARENT_SCOPE)
    set(${out_status} "ok" PARENT_SCOPE)
    return()
  endif()

  set(${out_status} "unknown-backend" PARENT_SCOPE)
  set(${out_message}
    "'${backend}' is not a Scheme lane backend. Known backends: chez gambit."
    PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_add_scheme_lane(NAME <name> BACKEND <chez|gambit> PROGRAM <path>
#                              TIMEOUT <seconds> [EXPECT_EXIT <code>]
#                              [LABELS ...] [ENVIRONMENT ...])
#
# With EXPECT_EXIT the lane is registered through the exact-status helper;
# without it, a nonzero exit fails the test in the ordinary way.
function(byte_machine_add_scheme_lane)
  cmake_parse_arguments(PARSE_ARGV 0 arg ""
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT" "LABELS;ENVIRONMENT")

  if(arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "byte-machine: unexpected arguments to byte_machine_add_scheme_lane: ${arg_UNPARSED_ARGUMENTS}")
  endif()
  foreach(required NAME BACKEND PROGRAM TIMEOUT)
    if(NOT arg_${required})
      message(FATAL_ERROR
        "byte-machine: ${required} is required for byte_machine_add_scheme_lane ('${arg_NAME}').")
    endif()
  endforeach()
  if(NOT EXISTS "${arg_PROGRAM}")
    message(FATAL_ERROR
      "byte-machine: '${arg_NAME}' names a program that does not exist: "
      "${arg_PROGRAM}. A lane registered against a missing file would fail at "
      "run time with a runtime error rather than at configure time with this one.")
  endif()

  byte_machine_scheme_lane_command(
    "${arg_BACKEND}" "${arg_PROGRAM}" command status message)

  if(status STREQUAL "unknown-backend")
    message(FATAL_ERROR "byte-machine: ${message}")
  endif()
  if(status STREQUAL "no-runtime")
    message(STATUS "byte-machine: skipping ${arg_NAME} -- ${message}")
    return()
  endif()

  # The launcher is the only party that knows what it actually loaded, so it is
  # the party that declares the mode. For the Chez lane the object guard makes
  # the compiled lane impossible, so the declaration cannot be silently wrong.
  set(environment "BYTE_MACHINE_EXECUTION_MODE=source" ${arg_ENVIRONMENT})

  if(DEFINED arg_EXPECT_EXIT)
    byte_machine_add_exit_code_test(
      NAME "${arg_NAME}"
      COMMAND ${command}
      EXPECT_EXIT "${arg_EXPECT_EXIT}"
      TIMEOUT "${arg_TIMEOUT}"
      LABELS ${arg_LABELS}
      ENVIRONMENT ${environment})
  else()
    byte_machine_add_test(
      NAME "${arg_NAME}"
      COMMAND ${command}
      TIMEOUT "${arg_TIMEOUT}"
      LABELS ${arg_LABELS}
      ENVIRONMENT ${environment})
  endif()
endfunction()
