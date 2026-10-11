# The benchmark runner's smoke lane: run the command the runner records, then
# hand what happened to the checker.
#
# bench/runner/benchmark.sps writes its own run command into every artefact it
# produces (`exact-command`), and its header, docs/building.md and the
# benchmark reference document the same command. Until this lane nothing ran
# that command, and it shipped broken: the source launcher empties
# source-directories, so the bare relative `--program bench/runner/benchmark.sps`
# it recorded was "not found in source directories" on every tree since the
# runner was added, while every baseline was taken by some other invocation.
# Nothing else runs the runner either, so a change that broke it surfaced only
# at the next baseline recording.
#
# WHAT RUNS
#
# The recorded command, read out of the runner's text and run from the tree
# root, at one round of one iteration with both executors (about a second).
# Two tokens are replaced and no others: the leading `chez`, by the Chez this
# build discovered, and the `--object-guard` value, by an empty directory of
# this lane's own, because the recorded build/dev/chez-object-guard exists only
# under the dev preset and the mutation suite's stage has no build tree at all.
# Every other token, the program path among them, runs as recorded; the checker
# asserts that, so a driver that "helpfully" made a path absolute would fail.
#
# WHY CMAKE RUNS IT
#
# Chez starts a subprocess only through a shell (`system`, `process`), so
# running the command from Scheme would mean quoting it for /bin/sh and cmd.exe
# alike. execute_process takes an argument list, the same way on every host.
#
# WHAT CHECKS IT
#
# test/common/bench-runner-smoke-tests.sps, run through the source launcher
# after the command. This file asserts nothing itself: it writes what happened
# -- the command it ran, its exit status, its output -- into the work
# directory, and every verdict is a harness check there, so a failure prints a
# FAIL record a mutation pin can name. This file exits nonzero exactly when the
# checker does.
#
# Run with BYTE_MACHINE_TEST_TMPDIR set, as
#   cmake -DBYTE_MACHINE_CHEZ_EXECUTABLE=<chez> -P test/common/bench-runner-smoke.cmake
# The tree is the one this file sits in, so the mutation suite's staged copy
# runs its own runner.
cmake_minimum_required(VERSION 3.26)

if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
  message(FATAL_ERROR
    "bench-runner-smoke: BYTE_MACHINE_CHEZ_EXECUTABLE was not passed in.")
endif()
if("$ENV{BYTE_MACHINE_TEST_TMPDIR}" STREQUAL "")
  message(FATAL_ERROR "bench-runner-smoke: BYTE_MACHINE_TEST_TMPDIR is unset.")
endif()

get_filename_component(tree "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(test_tmpdir "$ENV{BYTE_MACHINE_TEST_TMPDIR}")
set(work "${test_tmpdir}/bench-runner")
set(guard "${work}/guard")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${guard}" "${work}/runner")

# --- The recorded command, as text -----------------------------------------
#
# The checker reads the same string back as a datum, so a regex that picked the
# wrong text here shows up there as a command that differs from the one
# recorded.
file(READ "${tree}/bench/runner/benchmark.sps" runner_text)
string(REGEX MATCHALL "'exact-command[ \t\r\n]+\"[^\"]*\"" hits "${runner_text}")
list(LENGTH hits hit_count)

set(ran "")
if(NOT hit_count EQUAL 1)
  set(status "not run: the runner's text holds ${hit_count} exact-command strings")
else()
  string(REGEX REPLACE "^'exact-command[ \t\r\n]+\"([^\"]*)\"$" "\\1"
         recorded "${hits}")
  separate_arguments(recorded_argv UNIX_COMMAND "${recorded}")
  set(index 0)
  set(previous "")
  foreach(token IN LISTS recorded_argv)
    if(index EQUAL 0)
      list(APPEND ran "${BYTE_MACHINE_CHEZ_EXECUTABLE}")
    elseif(previous STREQUAL "--object-guard")
      list(APPEND ran "${guard}")
    else()
      list(APPEND ran "${token}")
    endif()
    set(previous "${token}")
    math(EXPR index "${index} + 1")
  endforeach()

  # The runner's own settings, as a user running it by hand would give them.
  # BYTE_MACHINE_BENCH_EXECUTORS is removed rather than set, so the default --
  # both executors, which is how a baseline is taken -- is what runs, whatever
  # the calling shell exported. The provenance variables belong to the checker,
  # not to the runner, and are restored for it below.
  set(saved_fingerprint_files "$ENV{BYTE_MACHINE_FINGERPRINT_FILES}")
  set(saved_expect_fingerprint "$ENV{BYTE_MACHINE_EXPECT_FINGERPRINT_FILE}")
  unset(ENV{BYTE_MACHINE_FINGERPRINT_FILES})
  unset(ENV{BYTE_MACHINE_EXPECT_FINGERPRINT_FILE})
  unset(ENV{BYTE_MACHINE_BENCH_EXECUTORS})
  set(ENV{BYTE_MACHINE_BENCH_ROUNDS} "1")
  set(ENV{BYTE_MACHINE_BENCH_INNER} "1")
  set(ENV{BYTE_MACHINE_BENCH_OUT} "${work}/artefact.sls")
  set(ENV{BYTE_MACHINE_TEST_TMPDIR} "${work}/runner")

  execute_process(
    COMMAND ${ran}
    WORKING_DIRECTORY "${tree}"
    TIMEOUT 120
    RESULT_VARIABLE status
    OUTPUT_VARIABLE runner_out
    ERROR_VARIABLE runner_err)
  file(WRITE "${work}/runner.log" "${runner_out}${runner_err}")
  if(NOT status STREQUAL "0")
    message(STATUS
      "bench-runner-smoke: the recorded command exited ${status}; its output:\n"
      "${runner_out}${runner_err}")
  endif()

  set(ENV{BYTE_MACHINE_FINGERPRINT_FILES} "${saved_fingerprint_files}")
  set(ENV{BYTE_MACHINE_EXPECT_FINGERPRINT_FILE} "${saved_expect_fingerprint}")
endif()

string(JOIN "\n" ran_lines ${ran})
file(WRITE "${work}/ran.txt" "${ran_lines}\n")
file(WRITE "${work}/status.txt" "${status}")

# --- The checker -------------------------------------------------------------
set(ENV{BYTE_MACHINE_TEST_TMPDIR} "${test_tmpdir}")
set(ENV{BYTE_MACHINE_EXECUTION_MODE} "source")
set(ENV{BYTE_MACHINE_BENCH_TREE} "${tree}")
set(ENV{BYTE_MACHINE_BENCH_SMOKE_DIR} "${work}")
set(ENV{BYTE_MACHINE_CHEZ_EXECUTABLE} "${BYTE_MACHINE_CHEZ_EXECUTABLE}")

execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
          --script "${tree}/test/support/launchers/chez-source.ss"
          --library-root "${tree}/test/support/harness"
          --object-guard "${guard}"
          --program "${tree}/test/common/bench-runner-smoke-tests.sps"
  TIMEOUT 120
  RESULT_VARIABLE checker_status)

if(NOT checker_status STREQUAL "0")
  message(FATAL_ERROR "bench-runner-smoke: the checker exited ${checker_status}.")
endif()
