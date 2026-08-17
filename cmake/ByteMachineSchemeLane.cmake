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

# byte_machine_scheme_lane_gambit_search(<out_option> <out_status> <out_message>
#                                        <dir>...)
#
# Build Gambit's `-:` runtime-option argument putting every <dir> on the module
# search path. Status is `ok`, `comma-in-path`, or `relative-path`.
#
# The comma check is not defensive programming. Gambit's -: option list is
# comma-separated, so a root containing one is not a wrong path but a malformed
# option list: gsi prints its usage banner and runs nothing, on every Gambit
# lane at once, mentioning nothing this project owns. A checkout under
# ~/my,projects/ is enough. Refusing at configure time turns that into a
# sentence naming the directory.
function(byte_machine_scheme_lane_gambit_search out_option out_status out_message)
  set(${out_option} "" PARENT_SCOPE)
  set(${out_message} "" PARENT_SCOPE)

  set(parts "")
  foreach(dir IN LISTS ARGN)
    if(dir MATCHES ",")
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
    endif()
    list(APPEND parts "search=${dir}")
  endforeach()

  list(JOIN parts "," joined)
  set(${out_option} "-:${joined}" PARENT_SCOPE)
  set(${out_status} "ok" PARENT_SCOPE)
endfunction()

# byte_machine_scheme_lane_command(<backend> <program>
#                                  <out_command> <out_status> <out_message>)
#
# Status is `ok`, `no-runtime`, or `unknown-backend` -- or, for gambit, one of
# byte_machine_scheme_lane_gambit_search's own statuses (`comma-in-path`,
# `relative-path`), forwarded unchanged. A missing runtime is not fatal: the
# CMake-layer specifications must stay runnable on a host with no Scheme
# installed, so a lane whose runtime was never discovered is skipped with a
# message rather than failing configuration.
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
    # Flags, not positions: a lane names one library root per library family it
    # imports and one source directory per shared-body directory, and both
    # counts grow with each slice.
    set(${out_command}
      "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
      "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
      "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
      "--library-root" "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
      "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
      "--source-dir" "${BYTE_MACHINE_SRC_COMMON_DIR}"
      "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
      "--program" "${program}"
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
    # `-:` runtime options must be the first argument, and the option list is
    # comma-separated: `search=A,search=B` puts two module roots on the path.
    # Measured, with a control proving the second root is load-bearing
    # (docs/plans/milestone-0-slice-3-shared-body.md section 2).
    # `-f` skips .gambini so a developer's personal initialisation cannot change
    # what a test proves. No launcher is needed: Gambit's include inside
    # define-library is source-file-relative and needs no ambient state.
    byte_machine_scheme_lane_gambit_search(search_option search_status search_message
      "${BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT}"
      "${BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT}")
    if(NOT search_status STREQUAL "ok")
      set(${out_status} "${search_status}" PARENT_SCOPE)
      set(${out_message} "${search_message}" PARENT_SCOPE)
      return()
    endif()

    set(${out_command}
      "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
      "${search_option}"
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
#                              [WORKING_DIRECTORY <dir>]
#                              [LABELS ...] [ENVIRONMENT ...])
#
# With EXPECT_EXIT the lane is registered through the exact-status helper;
# without it, a nonzero exit fails the test in the ordinary way.
function(byte_machine_add_scheme_lane)
  cmake_parse_arguments(PARSE_ARGV 0 arg ""
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY" "LABELS;ENVIRONMENT")

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

  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "comma-in-path"
     OR status STREQUAL "relative-path")
    message(FATAL_ERROR "byte-machine: ${message}")
  endif()
  if(status STREQUAL "no-runtime")
    message(STATUS "byte-machine: skipping ${arg_NAME} -- ${message}")
    return()
  endif()

  # The lane registration declares the execution mode; the launcher never
  # touches this variable. For the Chez lane, the launcher's object guard is
  # what makes the declaration unfalsifiable: it makes a compiled object
  # impossible to load.
  #
  # The fixture is immutable and lives in the source tree; a lane only ever
  # reads it. Set for every lane rather than only the self-tests, so a body that
  # starts needing it does not also need a registration change.
  set(environment
    "BYTE_MACHINE_EXECUTION_MODE=source"
    "BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin"
    ${arg_ENVIRONMENT})

  # Same CMP0174 reasoning as byte_machine_add_exit_code_test in
  # ByteMachineExpectExit.cmake: forward WORKING_DIRECTORY only when there is
  # a value, rather than forwarding an empty one unconditionally.
  set(working_directory_args "")
  if(arg_WORKING_DIRECTORY)
    set(working_directory_args WORKING_DIRECTORY "${arg_WORKING_DIRECTORY}")
  endif()

  if(DEFINED arg_EXPECT_EXIT)
    byte_machine_add_exit_code_test(
      NAME "${arg_NAME}"
      COMMAND ${command}
      EXPECT_EXIT "${arg_EXPECT_EXIT}"
      TIMEOUT "${arg_TIMEOUT}"
      LABELS ${arg_LABELS}
      ${working_directory_args}
      ENVIRONMENT ${environment})
  else()
    byte_machine_add_test(
      NAME "${arg_NAME}"
      COMMAND ${command}
      TIMEOUT "${arg_TIMEOUT}"
      LABELS ${arg_LABELS}
      ${working_directory_args}
      ENVIRONMENT ${environment})
  endif()
endfunction()
