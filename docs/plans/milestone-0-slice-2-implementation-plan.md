# Milestone 0 Slice 2 — Test Harness Implementation Plan

Status: executed; delivered 2026-08-16

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dependency-free portable Scheme test harness that runs one shared body on Chez and Gambit, proves it can fail before it is trusted to pass, and is itself covered by mutation testing.

**Architecture:** One wrapper-free shared runner body (`harness-runner.scm`) is included by exactly one thin library per runtime (`harness.sls` / `harness.sld`), which supply the adapter procedures and nothing else. Test bodies are shared `.scm` files with a hand-written wrapper per runtime holding only import forms. CMake registers one lane per body per runtime and asserts exact process exit statuses; a generalized mutation runner breaks each decision in the runner and requires the self-tests to notice.

**Tech Stack:** Chez Scheme 10.4.1+ (R6RS `.sls`), Gambit 4.9.8+ (R7RS `.sld`), CMake 3.26+ / CTest, GNU Make as a thin convenience layer.

**Design spec:** [`milestone-0-slice-2-test-harness.md`](./milestone-0-slice-2-test-harness.md). Read it before starting. Section numbers referenced below are its.

## Global Constraints

- **Shared bodies use only the common R6RS/R7RS subset** and must never name Chez or Gambit. Forbidden in shared bodies: `define-record-type`, string ports, `error`, condition accessors, hash tables, sorting, `syntax-case`, `eval`, bytevector literals. Everything runtime-specific arrives through the adapter protocol (spec §6).
- **Exit statuses are exactly 0 (pass), 1 (assertion failed), 2 (harness error), 3 (reserved, unused in this slice).** Nothing else is a legal expectation.
- **Test names match `byte-machine.<layer>.<feature>.<backend>.<mode>`**, all lowercase, feature segment not starting or ending in a hyphen. Registration validates this at configure time.
- **Every registration carries an explicit `TIMEOUT`.** There is no default.
- **Every new CMake module gets a functional core runnable under `cmake -P` with no Scheme installed, a specification in `test/support/cmake/`, and mutations that break each of its decisions.** This is the standard the build layer already holds itself to.
- **`ctest --preset no-scheme` must keep passing** with neither runtime installed. Lane registration is guarded on the runtime having been discovered.
- **Conventional Commits.** Run the tests before every commit.
- Do not commit anything under `build/`.

## File Structure

**Created:**

| Path | Responsibility |
| --- | --- |
| `cmake/ByteMachineExpectExit.cmake` | Exact-exit-status vocabulary, verdict, registration, and the `-P` runner. One file so registration and execution cannot drift. |
| `cmake/ByteMachineSchemeLane.cmake` | Assembles one lane's command line for a backend; registers it. |
| `cmake/ByteMachinePortabilityGuard.cmake` | Wrapper-pairing and shared-body basename-uniqueness rules. |
| `test/support/cmake/ByteMachineExpectExitSpec.cmake` | Specification for the above. |
| `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` | Specification for the above. |
| `test/support/cmake/ByteMachinePortabilityGuardSpec.cmake` | Specification for the above. |
| `test/support/cmake/SchemeMutationSuite.cmake` | Mutations against the Scheme runner and both adapters. |
| `test/support/launchers/chez-source.ss` | Sets `source-directories`, `library-directories`, and the object guard; loads the program. |
| `test/support/harness/shared/harness-runner.scm` | The runner. Assertions, cases, probe, summary, statuses. |
| `test/support/harness/chez/byte-machine/test/harness.sls` | Chez adapter + include. |
| `test/support/harness/gambit/byte-machine/test/harness.sld` | Gambit adapter + include. |
| `test/support/harness/self/harness-failing.scm` + 2 wrappers | Fails one assertion. Must exit 1. |
| `test/support/harness/self/harness-bootstrap.scm` + 2 wrappers | Judges the runner with raw conditionals only. |
| `test/support/harness/self/harness-self-tests.scm` + 2 wrappers | Full self-tests via `harness-probe`. |
| `test/support/harness/self/harness-duplicate-case.scm` + 2 wrappers | Duplicate case id. Must exit 2. |
| `test/support/harness/self/harness-empty-selection.scm` + 2 wrappers | Filter selects nothing. Must exit 2. |

**Modified:**

| Path | Change |
| --- | --- |
| `cmake/ByteMachineTesting.cmake` | Add `source` to Gambit's legal modes. |
| `test/support/cmake/ByteMachineTestingSpec.cmake` | Assert Gambit accepts `source`. |
| `test/support/cmake/MutationRunner.cmake` | Parameterize the stage set and the verify command. |
| `test/support/cmake/MutationSuite.cmake` | Mutations for the three new CMake modules and the Gambit mode. |
| `CMakeLists.txt` | Include the new modules. |
| `test/CMakeLists.txt` | Register every new test. |
| `CHANGELOG.md` | Slice 2 entry; correct the stale `expected-red` line. |

---

### Task 1: Exact-exit-status assertion

Nothing here touches Scheme. It runs under the `no-scheme` preset and is the one layer of the proof stack that depends on nothing inside the harness (spec §9).

**Files:**
- Create: `cmake/ByteMachineExpectExit.cmake`
- Create: `test/support/cmake/ByteMachineExpectExitSpec.cmake`
- Modify: `CMakeLists.txt`
- Modify: `test/CMakeLists.txt`
- Modify: `test/support/cmake/MutationSuite.cmake`

**Interfaces:**
- Consumes: `byte_machine_add_test(NAME COMMAND TIMEOUT LABELS ENVIRONMENT)` from `ByteMachineTesting.cmake`; `spec_check_equal`, `spec_expect_rejected`, `spec_finish` from `SpecSupport.cmake`.
- Produces:
  - `BYTE_MACHINE_EXIT_STATUS_VOCABULARY` — the list `0;1;2;3`.
  - `byte_machine_expect_exit_classify(<code> <out_status> <out_message>)` — status `ok` | `not-a-number` | `not-declared`.
  - `byte_machine_expect_exit_verdict(<expected> <actual> <out_status> <out_message>)` — status `ok` | `did-not-run` | `out-of-vocabulary` | `mismatch`.
  - `byte_machine_add_exit_code_test(NAME <n> COMMAND <cmd>... EXPECT_EXIT <code> TIMEOUT <s> [LABELS ...] [ENVIRONMENT ...])`.

- [ ] **Step 1: Write the failing specification**

Create `test/support/cmake/ByteMachineExpectExitSpec.cmake`:

```cmake
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
```

- [ ] **Step 2: Run it to make sure it fails**

```bash
cmake -P test/support/cmake/ByteMachineExpectExitSpec.cmake
```

Expected: FAIL — `include could not find requested file` for `cmake/ByteMachineExpectExit.cmake`.

- [ ] **Step 3: Write the module**

Create `cmake/ByteMachineExpectExit.cmake`:

```cmake
# Assert the exact exit status of a command.
#
# WHY NOT WILL_FAIL
#
# CTest's WILL_FAIL only distinguishes zero from nonzero. The harness gives each
# status a distinct meaning (docs/plans/milestone-0-slice-2-test-harness.md
# section 5.2), so a test proving "an assertion failed" must compare 1 exactly:
# under WILL_FAIL a segfault, a missing library, or a launcher that never
# started would all count as proof, and the test would keep passing after the
# thing it was written to check stopped happening.
#
# WHY AN OUT-OF-VOCABULARY STATUS IS ITS OWN VERDICT
#
# A status outside the declared set means the process died before the harness
# could report -- an uncaught top-level raise (section 5.4), a crash, or a
# program file Gambit could not find, which exits 70. Reporting that as
# "expected 1, got 70" sends the reader looking for a failed assertion that
# never ran. Naming it separately points at the real defect.
#
# This file is both the module and the runner. Included, it defines functions.
# Run with `cmake -P` and -DBYTE_MACHINE_EXPECT_COMMAND=..., it performs the
# check. One file means the registration and the execution cannot drift apart.

include_guard(GLOBAL)

# Every status the harness is allowed to produce. 3 is reserved for lane
# provenance and is not produced until slice 5; it is declared here so the
# number is not claimed by something else in the meantime. 77 is deliberately
# absent: byte-machine has no optional lane to declare inapplicable.
set(BYTE_MACHINE_EXIT_STATUS_VOCABULARY 0 1 2 3)

# --- Functional core -------------------------------------------------------

# byte_machine_expect_exit_classify(<code> <out_status> <out_message>)
#
# Decide whether a code is a legal *expectation*. Status is `ok`,
# `not-a-number`, or `not-declared`. The message omits the "byte-machine: "
# prefix; whoever raises it adds that.
function(byte_machine_expect_exit_classify code out_status out_message)
  set(${out_message} "" PARENT_SCOPE)

  if(NOT code MATCHES "^[0-9]+$")
    set(${out_status} "not-a-number" PARENT_SCOPE)
    set(${out_message}
      "EXPECT_EXIT must be a whole number, got '${code}'."
      PARENT_SCOPE)
    return()
  endif()

  if(NOT code IN_LIST BYTE_MACHINE_EXIT_STATUS_VOCABULARY)
    set(${out_status} "not-declared" PARENT_SCOPE)
    set(${out_message}
      "EXPECT_EXIT ${code} is not a declared harness status. The harness produces only ${BYTE_MACHINE_EXIT_STATUS_VOCABULARY}, so expecting anything else asserts something that cannot happen and would pass or fail for reasons unrelated to the test."
      PARENT_SCOPE)
    return()
  endif()

  set(${out_status} "ok" PARENT_SCOPE)
endfunction()

# byte_machine_expect_exit_verdict(<expected> <actual> <out_status> <out_message>)
#
# Judge an observed status against an expectation. Status is `ok`,
# `did-not-run`, `out-of-vocabulary`, or `mismatch`.
function(byte_machine_expect_exit_verdict expected actual out_status out_message)
  set(${out_message} "" PARENT_SCOPE)

  # execute_process reports a failure to run at all -- a timeout, a binary that
  # is not executable -- as a non-numeric RESULT_VARIABLE.
  if(NOT actual MATCHES "^[0-9]+$")
    set(${out_status} "did-not-run" PARENT_SCOPE)
    set(${out_message}
      "the command did not run to completion (${actual}). It either failed to launch or was killed before it could report."
      PARENT_SCOPE)
    return()
  endif()

  # Checked before the vocabulary test: an expectation is always in the
  # vocabulary, so a match is a match.
  if(actual EQUAL expected)
    set(${out_status} "ok" PARENT_SCOPE)
    return()
  endif()

  if(NOT actual IN_LIST BYTE_MACHINE_EXIT_STATUS_VOCABULARY)
    set(${out_status} "out-of-vocabulary" PARENT_SCOPE)
    set(${out_message}
      "exit status ${actual} is not in the declared vocabulary (${BYTE_MACHINE_EXIT_STATUS_VOCABULARY}); ${expected} was expected. The process died before the harness could report: an uncaught top-level raise, a crash, or a program file the runtime could not find. That is a different defect from a failed assertion."
      PARENT_SCOPE)
    return()
  endif()

  set(${out_status} "mismatch" PARENT_SCOPE)
  set(${out_message} "expected exit ${expected}, got ${actual}." PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_add_exit_code_test(NAME <name> COMMAND <cmd>... EXPECT_EXIT <code>
#                                 TIMEOUT <seconds> [LABELS ...] [ENVIRONMENT ...])
#
# The command is packed with `|` rather than passed as a list because it has to
# survive a trip through -D into a child cmake, where a `;` would be re-read as
# a list separator. No path in this project contains `|`.
function(byte_machine_add_exit_code_test)
  cmake_parse_arguments(PARSE_ARGV 0 arg ""
    "NAME;EXPECT_EXIT;TIMEOUT" "COMMAND;LABELS;ENVIRONMENT")

  if(arg_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "byte-machine: unexpected arguments to byte_machine_add_exit_code_test: ${arg_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT arg_NAME)
    message(FATAL_ERROR "byte-machine: NAME is required for byte_machine_add_exit_code_test.")
  endif()
  if(NOT arg_COMMAND)
    message(FATAL_ERROR "byte-machine: COMMAND is required for '${arg_NAME}'.")
  endif()
  if(NOT DEFINED arg_EXPECT_EXIT)
    message(FATAL_ERROR
      "byte-machine: '${arg_NAME}' must declare EXPECT_EXIT. A test registered "
      "through this helper exists to assert one exact status; without it there "
      "is nothing to compare and the registration should use byte_machine_add_test.")
  endif()

  byte_machine_expect_exit_classify("${arg_EXPECT_EXIT}" status message)
  if(NOT status STREQUAL "ok")
    message(FATAL_ERROR "byte-machine: ${message} (test '${arg_NAME}')")
  endif()

  string(JOIN "|" packed ${arg_COMMAND})

  byte_machine_add_test(
    NAME "${arg_NAME}"
    COMMAND "${CMAKE_COMMAND}"
            "-DBYTE_MACHINE_EXPECT_EXIT=${arg_EXPECT_EXIT}"
            "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_FILE}"
    TIMEOUT "${arg_TIMEOUT}"
    LABELS ${arg_LABELS}
    ENVIRONMENT ${arg_ENVIRONMENT})
endfunction()

# --- Runner ----------------------------------------------------------------
#
# Reached only under `cmake -P`. The child's output is echoed unconditionally:
# when the status is wrong, the inner run's own diagnostics are the only thing
# that says why, and CTest shows this process's output, not the grandchild's.

if(DEFINED BYTE_MACHINE_EXPECT_COMMAND)
  string(REPLACE "|" ";" _bm_command "${BYTE_MACHINE_EXPECT_COMMAND}")

  execute_process(
    COMMAND ${_bm_command}
    RESULT_VARIABLE _bm_rc
    OUTPUT_VARIABLE _bm_out
    ERROR_VARIABLE _bm_err)

  message(STATUS "byte-machine: --- command output ---\n${_bm_out}${_bm_err}")

  byte_machine_expect_exit_verdict(
    "${BYTE_MACHINE_EXPECT_EXIT}" "${_bm_rc}" _bm_verdict _bm_message)

  if(NOT _bm_verdict STREQUAL "ok")
    message(FATAL_ERROR "byte-machine: ${_bm_message}")
  endif()

  message(STATUS "byte-machine: exited ${_bm_rc} as expected")
endif()
```

- [ ] **Step 4: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachineExpectExitSpec.cmake
```

Expected: PASS, ending with `byte-machine-spec: ByteMachineExpectExit verified`.

- [ ] **Step 5: Wire it into the build**

In `CMakeLists.txt`, inside the `if(BYTE_MACHINE_BUILD_TESTS)` block, after `include(ByteMachineTesting)`:

```cmake
  include(ByteMachineExpectExit)
```

In `test/CMakeLists.txt`, append:

```cmake
# The exact-status assertion decides whether every expected-red test below is
# checking anything at all, so its functional core is specified before any of
# them relies on it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-expect-exit.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineExpectExitSpec.cmake"
  TIMEOUT 120
  LABELS unit)
```

- [ ] **Step 6: Add mutations**

In `test/support/cmake/MutationSuite.cmake`, before the closing `byte_machine_mutation_run(...)` call:

```cmake
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
  LABEL "expect-exit: the registrar stops validating its expectation"
  FIND [[  byte_machine_expect_exit_classify("${arg_EXPECT_EXIT}" status message)
  if(NOT status STREQUAL "ok")
    message(FATAL_ERROR "byte-machine: ${message} (test '${arg_NAME}')")
  endif()]]
  REPLACE [[]])

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
```

- [ ] **Step 7: Verify the whole build layer, including with no Scheme**

```bash
cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS. The new spec and the mutation suite both run; the mutation suite prints `7 more mutations, all accounted for` style output with no `UNCAUGHT` lines.

- [ ] **Step 8: Commit**

```bash
git add cmake/ByteMachineExpectExit.cmake test/support/cmake/ByteMachineExpectExitSpec.cmake test/support/cmake/MutationSuite.cmake CMakeLists.txt test/CMakeLists.txt
git commit -m "feat: assert exact process exit statuses"
```

---

### Task 2: Scheme lane registration and the Gambit source mode

Still no Scheme is executed. This task produces the helper that later tasks register lanes with, and opens the Gambit `source` mode the design chose (spec §3, S2).

**Files:**
- Create: `cmake/ByteMachineSchemeLane.cmake`
- Create: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `cmake/ByteMachineTesting.cmake:37`
- Modify: `test/support/cmake/ByteMachineTestingSpec.cmake`
- Modify: `CMakeLists.txt`, `test/CMakeLists.txt`, `test/support/cmake/MutationSuite.cmake`

**Interfaces:**
- Consumes: `byte_machine_add_test`, `byte_machine_add_exit_code_test`.
- Produces:
  - `byte_machine_scheme_lane_command(<backend> <program> <out_command> <out_status> <out_message>)` — status `ok` | `no-runtime` | `unknown-backend`. Reads `BYTE_MACHINE_CHEZ_EXECUTABLE`, `BYTE_MACHINE_GAMBIT_EXECUTABLE`, and the `BYTE_MACHINE_HARNESS_*` path variables.
  - `byte_machine_add_scheme_lane(NAME <n> BACKEND <chez|gambit> PROGRAM <path> TIMEOUT <s> [EXPECT_EXIT <c>] [LABELS ...] [ENVIRONMENT ...])`.
  - Path variables the caller must set before registering: `BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER`, `BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT`, `BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT`, `BYTE_MACHINE_HARNESS_SHARED_DIR`, `BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR`.

- [ ] **Step 1: Write the failing specification**

Create `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`:

```cmake
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

byte_machine_scheme_lane_command(guile "/h/self/p.scm" command status message)
spec_check_equal("${status}" "unknown-backend" "an unknown backend is rejected")

set(BYTE_MACHINE_CHEZ_EXECUTABLE "")
byte_machine_scheme_lane_command(chez "/h/self/p.chez.sps" command status message)
spec_check_equal("${status}" "no-runtime" "a chez lane without a chez is not registered")
spec_check_equal("${command}" "" "a rejected lane returns no command")

set(BYTE_MACHINE_GAMBIT_EXECUTABLE "")
byte_machine_scheme_lane_command(gambit "/h/self/p.gambit.scm" command status message)
spec_check_equal("${status}" "no-runtime" "a gambit lane without a gambit is not registered")

spec_finish("ByteMachineSchemeLane")
```

- [ ] **Step 2: Run it to make sure it fails**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `include could not find requested file` for `cmake/ByteMachineSchemeLane.cmake`.

- [ ] **Step 3: Write the module**

Create `cmake/ByteMachineSchemeLane.cmake`:

```cmake
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
```

- [ ] **Step 4: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: PASS, ending with `byte-machine-spec: ByteMachineSchemeLane verified`.

- [ ] **Step 5: Open the Gambit source mode**

In `cmake/ByteMachineTesting.cmake`, replace line 37:

```cmake
set(BYTE_MACHINE_TEST_MODES_gambit o1 aot)
```

with:

```cmake
# Gambit's `source` lane is `gsi` interpreting the .sld directly. protium has no
# equivalent because its lanes must link a native shim; byte-machine has no
# native code of its own, and both of Gambit's compiled modes shell out to a C
# compiler whose name was fixed when Gambit was built. Without this mode the
# first slice that runs Scheme could not run on Gambit at all without that
# toolchain, while Chez source needs nothing -- and parent plan section 24.2
# asks for a source suite that stays runnable without native compilation.
set(BYTE_MACHINE_TEST_MODES_gambit source o1 aot)
```

In `test/support/cmake/ByteMachineTestingSpec.cmake`, add to the positive assertions (alongside the existing name-parse cases):

```cmake
# Gambit's interpreted lane. Without it the harness cannot run on Gambit at all
# without a C toolchain.
byte_machine_test_name_parse(
  "byte-machine.harness.self.gambit.source" layer feature backend mode)
spec_check_equal("${mode}" "source" "gambit accepts the source mode")
spec_check_equal("${backend}" "gambit" "gambit source parses its backend")
```

- [ ] **Step 6: Wire in and register the specification**

In `CMakeLists.txt`, after `include(ByteMachineExpectExit)`:

```cmake
  include(ByteMachineSchemeLane)
```

In `test/CMakeLists.txt`, append:

```cmake
# A lane's command line decides whether a source lane is really a source lane.
# Specified before any lane is registered against it.
byte_machine_add_test(
  NAME byte-machine.harness.cmake-scheme-lane.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachineSchemeLaneSpec.cmake"
  TIMEOUT 120
  LABELS unit)
```

- [ ] **Step 7: Add mutations**

In `test/support/cmake/MutationSuite.cmake`, before `byte_machine_mutation_run(...)`:

```cmake
# --- ByteMachineSchemeLane -------------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the chez object guard is dropped, so a stale .so can be preferred over source"
  FIND [[      "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
]]
  REPLACE [[]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: gambit no longer skips .gambini"
  FIND [[      "-f"
]]
  REPLACE [[]])

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

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: gambit's source mode is withdrawn"
  FIND [[set(BYTE_MACHINE_TEST_MODES_gambit source o1 aot)]]
  REPLACE [[set(BYTE_MACHINE_TEST_MODES_gambit o1 aot)]])
```

- [ ] **Step 8: Verify**

```bash
cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, no `UNCAUGHT` lines from the mutation suite.

- [ ] **Step 9: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake cmake/ByteMachineTesting.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/support/cmake/ByteMachineTestingSpec.cmake test/support/cmake/MutationSuite.cmake CMakeLists.txt test/CMakeLists.txt
git commit -m "feat: register Scheme execution lanes and open Gambit's source mode"
```

---

### Task 3: The Chez lane, end to end

The slice's central failing test. A body that fails one assertion must make the process exit exactly 1, which requires the launcher, the adapter, and a minimum runner all at once — there is no smaller increment that produces a running lane.

**Files:**
- Create: `test/support/launchers/chez-source.ss`
- Create: `test/support/harness/shared/harness-runner.scm`
- Create: `test/support/harness/chez/byte-machine/test/harness.sls`
- Create: `test/support/harness/self/harness-failing.scm`
- Create: `test/support/harness/self/harness-failing.chez.sps`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `byte_machine_add_scheme_lane` from Task 2.
- Produces, from the runner: `harness-status-pass`/`-failed`/`-harness-error`/`-provenance` (integers 0/1/2/3), `harness-join`, `harness-member?`, `harness-failure-context`, `harness-group`, `harness-case`, `check`, `harness-begin`, `harness-summary`, `harness-exit-status`, `harness-finish`.
- Produces, from the adapter: the eleven `adapter-*` procedures of spec §6, plus re-exported `modulo`, `quotient`, `remainder`.

- [ ] **Step 1: Write the failing registration**

Add to `test/CMakeLists.txt`:

```cmake
# --- Harness paths ---------------------------------------------------------

set(BYTE_MACHINE_HARNESS_DIR "${CMAKE_CURRENT_LIST_DIR}/support/harness")
set(BYTE_MACHINE_HARNESS_SHARED_DIR "${BYTE_MACHINE_HARNESS_DIR}/shared")
set(BYTE_MACHINE_HARNESS_SELF_DIR "${BYTE_MACHINE_HARNESS_DIR}/self")
set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}/chez")
set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}/gambit")
set(BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-source.ss")

# The object guard is what makes the Chez source lane honest: Chez looks for a
# compiled library only in the object half of a library-directories pair, so
# pairing the source root with a directory that is always empty makes a stale
# .so unloadable. It lives in the build tree precisely because nothing may ever
# be written into it.
set(BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR "${CMAKE_BINARY_DIR}/chez-object-guard")
file(MAKE_DIRECTORY "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}")

# --- Harness lanes ---------------------------------------------------------

# The harness must be able to fail before it can be trusted to pass. This is
# that proof: a body that fails one assertion, with the exact status compared
# from outside, because a program cannot report its own exit status.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.chez.sps"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)
```

- [ ] **Step 2: Run it to make sure it fails**

```bash
cmake --preset dev
```

Expected: FAIL at configure time — `byte-machine: '…failing-body.chez.source' names a program that does not exist`.

- [ ] **Step 3: Write the launcher**

Create `test/support/launchers/chez-source.ss`:

```scheme
;;; Chez source-mode launcher.
;;;
;;; Arguments: <library-root> <shared-dir> <object-guard-dir> <program>
;;;
;;; THE OBJECT GUARD
;;;
;;; Chez looks for a library's compiled object only in the object half of a
;;; library-directories pair. Pairing the library root with a directory the
;;; build keeps empty therefore makes a .so left beside the sources impossible
;;; to load, which is what lets this lane call itself "source" honestly.
;;; Pointing library-directories at the source root alone would do the opposite:
;;; the object would be looked for next to the source and silently preferred.
;;;
;;; WHAT THIS LAUNCHER DELIBERATELY DOES NOT CHECK
;;;
;;; Petite, and whether the build is threaded. Discovery rejects Petite at
;;; configure time and re-probes the exact binary registered here, and decision
;;; 0001 refused to gate on threading because byte-machine has no threads. A
;;; second copy of either rule would be a requirement inherited rather than
;;; owned.

(define (path-directory path)
  (let loop ((i (- (string-length path) 1)))
    (cond ((< i 0) ".")
          ((or (char=? (string-ref path i) #\/)
               (char=? (string-ref path i) #\\))
           (substring path 0 i))
          (else (loop (- i 1))))))

;; Status 2 is the harness's "harness, configuration, or registration error".
;; A launcher that could not set up the lane has not run a test at all, and must
;; not be mistaken for one that ran and failed.
(define (die message)
  (display "byte-machine-launcher: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define args (command-line-arguments))

(if (not (= (length args) 4))
    (die "usage: chez-source.ss <library-root> <shared-dir> <object-guard-dir> <program>"))

(define library-root (list-ref args 0))
(define shared-dir (list-ref args 1))
(define object-guard-dir (list-ref args 2))
(define program (list-ref args 3))

(if (not (file-directory? object-guard-dir))
    (die (string-append "object guard directory does not exist: " object-guard-dir)))

;; Asserted, not assumed. A guard directory that has acquired a file is no
;; longer a guard, and the lane would go on reporting "source" while loading
;; whatever was put there.
(if (not (null? (directory-list object-guard-dir)))
    (die (string-append "object guard directory must be empty but is not: "
                        object-guard-dir)))

(compile-imported-libraries #f)

;; A program may include bodies that live beside it, so its own directory joins
;; the shared directory on the source path. Both are explicit: nothing resolves
;; against the current working directory.
(source-directories (list shared-dir (path-directory program)))
(library-directories (list (cons library-root object-guard-dir)))

(load-program program)
```

- [ ] **Step 4: Write the runner**

Create `test/support/harness/shared/harness-runner.scm`:

```scheme
;;; byte-machine private portable test runner.
;;;
;;; PORTABILITY CONTRACT
;;;
;;; This file is included verbatim by both the R6RS and the R7RS wrapper. It may
;;; use only identifiers common to both standards, and must never name Chez or
;;; Gambit. Everything a runtime does differently arrives through the adapter
;;; protocol, documented in
;;; docs/plans/milestone-0-slice-2-test-harness.md section 6.
;;;
;;; Notable exclusions, each of which differs between the two standards:
;;; define-record-type, string ports, error, condition accessors, hash tables,
;;; and sorting. Records are plain lists behind accessors for the same reason.
;;;
;;; PROCESS STATUS (spec section 5.2)
;;;
;;;   0  every selected case passed
;;;   1  one or more assertions failed
;;;   2  harness, configuration, or registration error
;;;   3  reserved: the run could not confirm it executed the intended text
;;;
;;; Status is computed once, at the end, rather than chosen at each throw site,
;;; so a new error path cannot forget to change it.

(define harness-status-pass 0)
(define harness-status-failed 1)
(define harness-status-harness-error 2)
(define harness-status-provenance 3)

;; ---------------------------------------------------------------------------
;; Pure helpers
;; ---------------------------------------------------------------------------

(define (harness-join parts separator)
  (if (null? parts)
      ""
      (let loop ((rest (cdr parts)) (acc (car parts)))
        (if (null? rest)
            acc
            (loop (cdr rest) (string-append acc separator (car rest)))))))

(define (harness-member? x lst)
  (cond ((null? lst) #f)
        ((equal? x (car lst)) #t)
        (else (harness-member? x (cdr lst)))))

;; ---------------------------------------------------------------------------
;; Mutable result state (the imperative shell of the runner)
;; ---------------------------------------------------------------------------

(define harness-suite-name "(none)")
(define harness-group-stack '())
(define harness-case-ids '())
(define harness-current-case #f)
(define harness-current-case-failed #f)
(define harness-case-count 0)
(define harness-failed-case-count 0)
(define harness-check-count 0)
(define harness-failure-count 0)
(define harness-error-count 0)
(define harness-skipped-count 0)
(define harness-cleanup-failure-count 0)
(define harness-failures '())
(define harness-filter #f)
(define harness-verbose #f)
(define harness-probe-depth 0)

(define (harness-quiet?) (> harness-probe-depth 0))

;; Flushed per line rather than at the summary. Standard output is block
;; buffered when it is not a terminal, so a process killed by a supervisor loses
;; everything it had written -- and the run whose output matters most is the one
;; that was killed before it could finish.
(define (harness-say line)
  (if (not (harness-quiet?))
      (begin (display line) (newline) (adapter-flush-output))))

(define (harness-say-always line)
  (display line) (newline) (adapter-flush-output))

;; ---------------------------------------------------------------------------
;; Failure and error recording
;; ---------------------------------------------------------------------------

;; Emitted per failure rather than once per run, because a log is usually read
;; at the failure rather than from the top. The id and the artifact path are
;; quoted because a case name and a filesystem path may both contain spaces,
;; which would otherwise make a key=value line ambiguous to parse.
(define (harness-failure-context id)
  (string-append
   "byte-machine-harness: FAIL-CONTEXT id=\"" id "\""
   " test=" (let ((t (adapter-environment-variable "BYTE_MACHINE_TEST_NAME")))
              (if t t "(unregistered)"))
   " backend=" (adapter-runtime-name)
   " mode=" (adapter-execution-mode)
   " os=" (adapter-os)
   " architecture=" (adapter-architecture)
   " runtime-version=" (adapter-runtime-version)
   " machine-type=" (adapter-machine-type)
   " artifacts=\"" (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
                     (if d d "(none)"))
   "\""))

(define (harness-record-failure! what detail)
  (set! harness-failure-count (+ harness-failure-count 1))
  (set! harness-current-case-failed #t)
  (let ((id (if harness-current-case harness-current-case "(no case)")))
    (set! harness-failures (cons (list id what detail) harness-failures))
    (harness-say (string-append "byte-machine-harness: FAIL " id ": " what
                                (if (string=? detail "")
                                    ""
                                    (string-append " -- " detail))))
    (harness-say (harness-failure-context id))))

(define (harness-record-error! detail)
  (set! harness-error-count (+ harness-error-count 1))
  (harness-say (string-append "byte-machine-harness: HARNESS-ERROR " detail)))

;; ---------------------------------------------------------------------------
;; Assertions
;; ---------------------------------------------------------------------------

(define (harness-count-check!)
  (set! harness-check-count (+ harness-check-count 1)))

(define (check what value)
  (harness-count-check!)
  (if value
      #t
      (begin (harness-record-failure! what "expected a true value") #f)))

;; ---------------------------------------------------------------------------
;; Groups and cases
;; ---------------------------------------------------------------------------

(define (harness-current-prefix)
  (if (null? harness-group-stack)
      ""
      (string-append (harness-join (reverse harness-group-stack) ".") ".")))

(define (harness-group name thunk)
  (set! harness-group-stack (cons name harness-group-stack))
  (let ((outcome (guard (e (#t (list 'raised e)))
                   (list 'value (thunk)))))
    (set! harness-group-stack (cdr harness-group-stack))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))
        (car (cdr outcome)))))

;; A raise inside a case is that case's failure, not the suite's death.
;; Otherwise the first broken case hides every case after it, and the log names
;; one defect where there may be five.
(define (harness-case name thunk)
  (let ((id (string-append (harness-current-prefix) name)))
    (cond
      ;; A duplicate id means one registration silently became unreachable:
      ;; coverage lost with no signal at all. That is a defect in the suite, not
      ;; a failing assertion, so it is an error and not a failure.
      ((harness-member? id harness-case-ids)
       (harness-record-error! (string-append "duplicate case id " id)))
      (else
       (set! harness-case-ids (cons id harness-case-ids))
       (set! harness-case-count (+ harness-case-count 1))
       (set! harness-current-case id)
       (set! harness-current-case-failed #f)
       (let ((outcome (guard (e (#t (list 'raised e)))
                        (list 'value (thunk)))))
         (if (eq? (car outcome) 'raised)
             (harness-record-failure!
              "case raised"
              (adapter-describe-condition (car (cdr outcome))))))
       (if harness-current-case-failed
           (set! harness-failed-case-count (+ harness-failed-case-count 1))
           (if harness-verbose
               (harness-say (string-append "byte-machine-harness: pass " id))))
       (set! harness-current-case #f)))))

;; ---------------------------------------------------------------------------
;; Suite lifecycle
;; ---------------------------------------------------------------------------

(define (harness-clear-state!)
  (set! harness-group-stack '())
  (set! harness-case-ids '())
  (set! harness-current-case #f)
  (set! harness-current-case-failed #f)
  (set! harness-case-count 0)
  (set! harness-failed-case-count 0)
  (set! harness-check-count 0)
  (set! harness-failure-count 0)
  (set! harness-error-count 0)
  (set! harness-skipped-count 0)
  (set! harness-cleanup-failure-count 0)
  (set! harness-failures '())
  (set! harness-filter #f))

(define (harness-banner)
  (harness-say-always
   (string-append "byte-machine-harness: suite=" harness-suite-name))
  (harness-say-always
   (string-append "byte-machine-harness: runtime=" (adapter-runtime-name)
                  " version=" (adapter-runtime-version)
                  " machine=" (adapter-machine-type)
                  " mode=" (adapter-execution-mode)
                  " os=" (adapter-os)
                  " architecture=" (adapter-architecture))))

(define (harness-begin suite-name)
  (set! harness-suite-name suite-name)
  (harness-clear-state!)
  (set! harness-verbose
        (if (adapter-environment-variable "BYTE_MACHINE_TEST_VERBOSE") #t #f))
  (harness-banner))

(define (harness-exit-status)
  (cond ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)
        (else harness-status-pass)))

(define (harness-summary)
  (let ((status (harness-exit-status)))
    (harness-say-always
     (string-append
      "byte-machine-harness: summary suite=" harness-suite-name
      " runtime=" (adapter-runtime-name)
      " mode=" (adapter-execution-mode)
      " cases=" (number->string harness-case-count)
      " failed-cases=" (number->string harness-failed-case-count)
      " checks=" (number->string harness-check-count)
      " failures=" (number->string harness-failure-count)
      " cleanup-failures=" (number->string harness-cleanup-failure-count)
      " skipped=" (number->string harness-skipped-count)
      " errors=" (number->string harness-error-count)
      " status=" (number->string status)))
    (adapter-flush-output)
    status))

;; Print the summary and exit with the status it reports.
(define (harness-finish)
  (adapter-exit (harness-summary)))
```

- [ ] **Step 5: Write the Chez adapter**

Create `test/support/harness/chez/byte-machine/test/harness.sls`:

```scheme
;;; Chez runtime adapter for the byte-machine private test runner.
;;;
;;; This file and its Gambit counterpart are the only places in the harness
;;; where runtime-specific identifiers may appear, and the two must export
;;; exactly the same names. That requirement is checked by mutation: deleting an
;;; export here must make the self-tests fail (spec section 9.1).
;;;
;;; The shared body is included by bare filename and resolved through Chez's
;;; source-directories, which the launcher sets. That keeps absolute paths out
;;; of the source tree and keeps the include independent of the working
;;; directory.

(library (byte-machine test harness)
  (export
    ;; suite lifecycle
    harness-begin harness-finish harness-summary harness-exit-status
    harness-status-pass harness-status-failed
    harness-status-harness-error harness-status-provenance
    ;; structure
    harness-group harness-case
    ;; assertions
    check
    ;; pure helpers, exported so the runner's own tests can reach them
    harness-join harness-member? harness-failure-context
    ;; adapter protocol
    adapter-runtime-name adapter-runtime-version adapter-machine-type
    adapter-os adapter-architecture adapter-execution-mode
    adapter-environment-variable adapter-exit
    adapter-value->string adapter-describe-condition adapter-flush-output
    ;; arithmetic the shared subset uses, which R6RS keeps outside (rnrs)
    modulo quotient remainder)

  (import
    (rnrs)
    (only (rnrs r5rs) modulo quotient remainder)
    (only (chezscheme)
          include machine-type scheme-version getenv
          with-output-to-string display-condition))

  ;; --- runtime identity ----------------------------------------------------

  (define (adapter-runtime-name) "chez")

  ;; (scheme-version) is "Chez Scheme Version 10.4.1"; evidence records compare
  ;; the bare number, so take the final whitespace-delimited token.
  (define (adapter-runtime-version)
    (let* ((full (scheme-version))
           (n (string-length full)))
      (let loop ((i (- n 1)))
        (cond ((< i 0) full)
              ((char=? (string-ref full i) #\space) (substring full (+ i 1) n))
              (else (loop (- i 1)))))))

  (define (adapter-machine-type) (symbol->string (machine-type)))

  ;; --- OS and architecture, derived from the machine type ------------------
  ;;
  ;; Chez's machine type names the target the runtime was actually built for,
  ;; which is what a portability claim needs: an observed architecture, not a
  ;; configure-time guess. A threaded build carries a leading "t".

  (define (adapter-machine-type-body)
    (let ((m (adapter-machine-type)))
      (if (and (> (string-length m) 0) (char=? (string-ref m 0) #\t))
          (substring m 1 (string-length m))
          m)))

  (define (adapter-string-starts-with? s prefix)
    (let ((sn (string-length s)) (pn (string-length prefix)))
      (and (>= sn pn)
           (string=? (substring s 0 pn) prefix))))

  (define adapter-architecture-table
    '(("arm64" . "arm64")
      ("arm32" . "arm32")
      ("a6" . "amd64")
      ("i3" . "x86")
      ("ppc32" . "ppc32")
      ("rv64" . "riscv64")
      ("la64" . "loongarch64")))

  (define adapter-os-table
    '(("le" . "linux")
      ("osx" . "darwin")
      ("nt" . "windows")
      ("fb" . "freebsd")
      ("ob" . "openbsd")
      ("nb" . "netbsd")
      ("s2" . "solaris")
      ("qnx" . "qnx")
      ("ti" . "ios")
      ("a" . "android")))

  (define (adapter-lookup-prefix table s)
    (cond ((null? table) #f)
          ((adapter-string-starts-with? s (car (car table))) (car table))
          (else (adapter-lookup-prefix (cdr table) s))))

  (define (adapter-architecture)
    (let ((hit (adapter-lookup-prefix adapter-architecture-table
                                      (adapter-machine-type-body))))
      (if hit (cdr hit) "unknown")))

  (define (adapter-os)
    (let* ((body (adapter-machine-type-body))
           (arch-hit (adapter-lookup-prefix adapter-architecture-table body)))
      (if (not arch-hit)
          "unknown"
          (let* ((rest (substring body (string-length (car arch-hit))
                                  (string-length body)))
                 (os-hit (adapter-lookup-prefix adapter-os-table rest)))
            (if os-hit (cdr os-hit) "unknown")))))

  ;; The launcher declares the execution mode; it is the only party that knows
  ;; whether it loaded source or a compiled object. Its object guard makes the
  ;; compiled lane impossible, so the declaration cannot be silently wrong.
  (define (adapter-execution-mode)
    (let ((m (getenv "BYTE_MACHINE_EXECUTION_MODE")))
      (if (and m (not (string=? m ""))) m "unknown")))

  ;; --- services ------------------------------------------------------------

  (define (adapter-environment-variable name) (getenv name))

  (define (adapter-exit code) (exit code))

  (define (adapter-value->string v)
    (with-output-to-string (lambda () (write v))))

  (define (adapter-describe-condition obj)
    (if (condition? obj)
        (with-output-to-string (lambda () (display-condition obj)))
        (with-output-to-string (lambda () (write obj)))))

  (define (adapter-flush-output) (flush-output-port (current-output-port)))

  ;; --- shared body ---------------------------------------------------------
  ;;
  ;; Included by bare filename, resolved through the launcher's
  ;; source-directories. Nothing below this point is Chez-specific.

  (include "harness-runner.scm"))
```

- [ ] **Step 6: Write the failing body and its Chez wrapper**

Create `test/support/harness/self/harness-failing.scm`:

```scheme
;;; Deliberately fails one assertion so the process exits with status 1.
;;;
;;; A program cannot report its own exit status, so this body only fails; the
;;; registration compares the exact status from outside. Status 1 means an
;;; assertion failed and nothing else, and must stay distinguishable from the
;;; status 2 that harness-duplicate-case.scm produces.

(harness-case "an assertion that is meant to fail"
  (lambda ()
    (check "this check fails on purpose" #f)))
```

Create `test/support/harness/self/harness-failing.chez.sps`:

```scheme
;;; Chez wrapper for the failing body. Runtime-specific only in its imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.failing")

(include "harness-failing.scm")

(harness-finish)
```

- [ ] **Step 7: Run the lane and verify it exits 1**

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R failing-body
```

Expected: PASS — one test, `byte-machine.harness.failing-body.chez.source`. Its captured output contains a `FAIL` line, a `FAIL-CONTEXT` line naming `backend=chez mode=source`, and a summary line ending `status=1`.

- [ ] **Step 8: Prove the assertion is not vacuous**

Temporarily change `EXPECT_EXIT 1` to `EXPECT_EXIT 0` in `test/CMakeLists.txt`, then:

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R failing-body
```

Expected: FAIL with `expected exit 0, got 1`. Change it back to `EXPECT_EXIT 1` and re-run to confirm PASS before committing.

- [ ] **Step 9: Commit**

```bash
git add test/support/launchers test/support/harness test/CMakeLists.txt
git commit -m "feat: run the harness on Chez and prove it can fail"
```

---

### Task 4: Bootstrap body

The runner cannot be the only witness to its own correctness. This body judges its primitives with raw conditionals and its own counter, using no assertion, case, group, or summary facility from the runner (spec §9, layer 2).

**Files:**
- Modify: `test/support/harness/shared/harness-runner.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Create: `test/support/harness/self/harness-bootstrap.scm`
- Create: `test/support/harness/self/harness-bootstrap.chez.sps`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: everything from Task 3.
- Produces:
  - `harness-string-contains?(<haystack> <needle>) -> boolean`
  - `harness-split(<text> <separator-char>) -> list of string`
  - `harness-take(<list> <count>) -> list`
  - `harness-counters() -> (failure-count check-count)`
  - `harness-restore-counters!(<saved>) -> unspecified`

- [ ] **Step 1: Write the failing bootstrap body**

Create `test/support/harness/self/harness-bootstrap.scm`:

```scheme
;;; Bootstrap verification of the runner's primitives.
;;;
;;; PORTABILITY: a shared body, included verbatim by each runtime's thin
;;; wrapper. Common R6RS/R7RS subset only.
;;;
;;; The runner cannot be the only witness to its own correctness, so this
;;; program judges it with raw conditionals and its own counter. It uses no
;;; assertion, case, group, or summary facility from the runner; it calls the
;;; primitives under test and inspects what they return. It answers "does check
;;; actually check?" without using check to ask.
;;;
;;; It exits 1 on any failure and 0 otherwise, by hand, because harness-finish
;;; is one of the things it is not allowed to trust.

(define bootstrap-failures 0)

(define (bootstrap-assert name value)
  (if value
      (begin (display "bootstrap: ok   ") (display name) (newline))
      (begin
        (set! bootstrap-failures (+ bootstrap-failures 1))
        (display "bootstrap: FAIL ") (display name) (newline))))

;; --- pure helpers ----------------------------------------------------------

(bootstrap-assert "contains: middle" (harness-string-contains? "abcdef" "cd"))
(bootstrap-assert "contains: prefix" (harness-string-contains? "abcdef" "abc"))
(bootstrap-assert "contains: suffix" (harness-string-contains? "abcdef" "def"))
(bootstrap-assert "contains: absent" (not (harness-string-contains? "abcdef" "z")))
(bootstrap-assert "contains: empty needle" (harness-string-contains? "abc" ""))
(bootstrap-assert "contains: needle longer than haystack"
                  (not (harness-string-contains? "ab" "abc")))

(bootstrap-assert "join: several" (string=? (harness-join '("a" "b" "c") ".") "a.b.c"))
(bootstrap-assert "join: one" (string=? (harness-join '("x") ".") "x"))
(bootstrap-assert "join: none" (string=? (harness-join '() ".") ""))

(bootstrap-assert "split: several"
                  (equal? (harness-split "a.b.c" #\.) '("a" "b" "c")))
(bootstrap-assert "split: no separator"
                  (equal? (harness-split "abc" #\.) '("abc")))
(bootstrap-assert "split: trailing separator keeps the empty field"
                  (equal? (harness-split "a." #\.) '("a" "")))

(bootstrap-assert "take: fewer than available"
                  (equal? (harness-take '(1 2 3 4) 2) '(1 2)))
(bootstrap-assert "take: all" (equal? (harness-take '(1 2) 2) '(1 2)))
(bootstrap-assert "take: none" (equal? (harness-take '(1 2) 0) '()))
(bootstrap-assert "take: more than available"
                  (equal? (harness-take '(1 2) 5) '(1 2)))

(bootstrap-assert "member: present" (harness-member? "b" '("a" "b")))
(bootstrap-assert "member: absent" (not (harness-member? "z" '("a" "b"))))
(bootstrap-assert "member: empty" (not (harness-member? "a" '())))

;; --- the assertion primitive ------------------------------------------------
;;
;; The point of this file. A `check` that always returned a true value would
;; make every test in every later milestone pass, and no test written with
;; `check` could notice.

(bootstrap-assert "check: a true value returns true" (eq? (check "true" #t) #t))
(bootstrap-assert "check: a non-#f value returns true" (eq? (check "zero" 0) #t))

;; A deliberately failing check must be observed without it counting against
;; anything. harness-probe would do this, but the probe is itself part of what
;; the bootstrap is not allowed to trust, so the counters are saved and restored
;; by hand. What is asserted is the return value, nothing the runner counted.
(bootstrap-assert "check: a false value returns false"
                  (let* ((saved (harness-counters))
                         (result (check "deliberate" #f)))
                    (harness-restore-counters! saved)
                    (eq? result #f)))

;; --- adapter protocol -------------------------------------------------------
;;
;; Every adapter procedure is called, so a name missing from one runtime's
;; export list is a load failure on that runtime rather than a silent gap.

(bootstrap-assert "adapter: runtime name is one of the two"
                  (or (string=? (adapter-runtime-name) "chez")
                      (string=? (adapter-runtime-name) "gambit")))
(bootstrap-assert "adapter: version is non-empty"
                  (> (string-length (adapter-runtime-version)) 0))
(bootstrap-assert "adapter: machine type is non-empty"
                  (> (string-length (adapter-machine-type)) 0))
(bootstrap-assert "adapter: os is known"
                  (not (string=? (adapter-os) "unknown")))
(bootstrap-assert "adapter: architecture is known"
                  (not (string=? (adapter-architecture) "unknown")))
(bootstrap-assert "adapter: execution mode is declared by the launcher"
                  (string=? (adapter-execution-mode) "source"))
(bootstrap-assert "adapter: an unset variable reads as false"
                  (not (adapter-environment-variable "BYTE_MACHINE_NOT_SET_ANYWHERE")))
(bootstrap-assert "adapter: value->string writes readably"
                  (string=? (adapter-value->string (list 1 2)) "(1 2)"))
(bootstrap-assert "adapter: a condition describes as a non-empty single line"
                  (let ((text (adapter-describe-condition
                               (guard (e (#t e)) (car '())))))
                    (and (> (string-length text) 0)
                         (not (harness-string-contains? text "\n")))))
(bootstrap-assert "adapter: r5rs arithmetic is reachable"
                  (and (= (quotient 7 2) 3)
                       (= (remainder 7 2) 1)
                       (= (modulo -7 2) 1)))

(adapter-flush-output)

(display "bootstrap: failures=")
(display bootstrap-failures)
(newline)

(adapter-exit (if (= bootstrap-failures 0) 0 1))
```

The `check: a false value returns false` assertion above reaches the counters
through `harness-counters` and `harness-restore-counters!`, added in Step 4,
rather than through `harness-probe`, which does not exist until Task 5 and is
itself one of the things the bootstrap may not trust. It must not touch the
counter variables directly either: R6RS makes assigning an *exported* variable a
syntax violation, so the library would fail to compile.

- [ ] **Step 2: Write the Chez wrapper**

Create `test/support/harness/self/harness-bootstrap.chez.sps`:

```scheme
;;; Chez wrapper for the bootstrap body. Runtime-specific only in its imports.
;;;
;;; harness-begin is deliberately not called: the bootstrap judges the runner
;;; without using its suite lifecycle.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(include "harness-bootstrap.scm")
```

- [ ] **Step 3: Register the lane and run it to see it fail**

Add to `test/CMakeLists.txt`, in the harness lanes block:

```cmake
# The runner cannot be its own only witness. This judges its primitives with
# raw conditionals, using none of the facilities it is checking.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
  TIMEOUT 120)
```

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R bootstrap
```

Expected: FAIL — `harness-string-contains?`, `harness-split`, `harness-take`, and the internal state names are unbound.

- [ ] **Step 4: Add the missing helpers to the runner**

In `test/support/harness/shared/harness-runner.scm`, in the pure-helpers section, before `harness-member?`:

```scheme
(define (harness-string-contains? haystack needle)
  (let ((hn (string-length haystack))
        (nn (string-length needle)))
    (let outer ((start 0))
      (cond ((> (+ start nn) hn) #f)
            ((let inner ((i 0))
               (cond ((= i nn) #t)
                     ((char=? (string-ref haystack (+ start i))
                              (string-ref needle i))
                      (inner (+ i 1)))
                     (else #f)))
             #t)
            (else (outer (+ start 1)))))))

;; A trailing separator yields a trailing empty field, deliberately: dropping it
;; would make "a." and "a" split alike, and a filter written against the
;; difference would silently stop distinguishing them.
(define (harness-split text separator)
  (let ((n (string-length text)))
    (let loop ((i 0) (start 0) (acc '()))
      (cond ((= i n) (reverse (cons (substring text start n) acc)))
            ((char=? (string-ref text i) separator)
             (loop (+ i 1) (+ i 1) (cons (substring text start i) acc)))
            (else (loop (+ i 1) start acc))))))

(define (harness-take lst count)
  (if (or (= count 0) (null? lst))
      '()
      (cons (car lst) (harness-take (cdr lst) (- count 1)))))
```

Add these two beside them. R6RS cannot export a mutable variable such that `set!`
works across the library boundary, so the bootstrap reaches the counters through
accessors rather than directly:

```scheme
;; Exported so the bootstrap can observe a deliberate failure and undo it
;; without depending on harness-probe, which is itself one of the things the
;; bootstrap exists to check.
(define (harness-counters)
  (list harness-failure-count harness-check-count))

(define (harness-restore-counters! saved)
  (set! harness-failure-count (car saved))
  (set! harness-check-count (car (cdr saved)))
  (set! harness-current-case-failed #f))
```

- [ ] **Step 5: Export them**

In `test/support/harness/chez/byte-machine/test/harness.sls`, replace the
pure-helpers export line with:

```scheme
    ;; pure helpers, exported so the runner's own tests can reach them
    harness-string-contains? harness-join harness-split harness-take
    harness-member? harness-failure-context
    harness-counters harness-restore-counters!
```

- [ ] **Step 6: Run the bootstrap to verify it passes**

```bash
ctest --preset harness --output-on-failure -R bootstrap
```

Expected: PASS. Output ends `bootstrap: failures=0`.

- [ ] **Step 7: Prove the bootstrap can fail**

Temporarily change `check` in the runner to `(if #t #t (begin ...))` so it never records. Re-run:

```bash
ctest --preset harness --output-on-failure -R bootstrap
```

Expected: FAIL on `check: a false value returns false`. Revert and re-run to confirm PASS.

- [ ] **Step 8: Commit**

```bash
git add test/support/harness test/CMakeLists.txt
git commit -m "test: judge the runner's primitives without using them"
```

---

### Task 5: Probe, the remaining assertions, and the self-tests

Layer 3 of the proof stack. The runner may now be used to test the runner, because the bootstrap has already established its primitives with raw conditionals, and because every deliberate failure below runs inside `harness-probe`.

**Files:**
- Modify: `test/support/harness/shared/harness-runner.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Create: `test/support/harness/self/harness-self-tests.scm`
- Create: `test/support/harness/self/harness-self-tests.chez.sps`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: everything from Tasks 3 and 4.
- Produces:
  - `check-equal(<what> <actual> <expected>) -> boolean`
  - `check-not-equal(<what> <actual> <unexpected>) -> boolean`
  - `check-fail(<what> <detail>) -> #f`
  - `check-raises(<what> <predicate> <thunk>) -> boolean`
  - `with-cleanup(<body-thunk> <cleanup-thunk>) -> body's value`, re-raising the body's condition unchanged
  - `harness-probe(<thunk>) -> probe record`
  - `probe-cases`, `probe-failed-cases`, `probe-checks`, `probe-failures`, `probe-errors`, `probe-skipped`, `probe-cleanup-failures`, `probe-raised?`, `probe-failure-records`
  - `failure-record-id`, `failure-record-what`, `failure-record-detail`
  - `harness-set-filter!(<string-or-false>)`

- [ ] **Step 1: Write the failing self-tests body**

Create `test/support/harness/self/harness-self-tests.scm`:

```scheme
;;; Self-tests for the byte-machine private test runner.
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only.
;;;
;;; Every deliberate failure below runs inside harness-probe, which gives it a
;;; fresh isolated result state and suppresses its output. Without that, a
;;; self-test that proves failures are recorded would itself fail the run, and
;;; the log would teach readers to ignore FAIL lines.
;;;
;;; Every exported adapter name is referenced here. That is what makes running
;;; this one body on both runtimes a parity proof rather than a coincidence:
;;; a name in one adapter's export list and not the other is a load failure on
;;; that runtime, not a silent gap (spec section 9.1).

(harness-group "assertions"
  (lambda ()

    (harness-case "check counts and passes a true value"
      (lambda ()
        (let ((p (harness-probe (lambda () (check "t" #t)))))
          (check-equal "one check counted" (probe-checks p) 1)
          (check-equal "no failure recorded" (probe-failures p) 0))))

    (harness-case "check records a failure for a false value"
      (lambda ()
        (let ((p (harness-probe (lambda () (check "f" #f)))))
          (check-equal "one check counted" (probe-checks p) 1)
          (check-equal "one failure recorded" (probe-failures p) 1))))

    (harness-case "check-equal compares with equal?"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (check-equal "lists" (list 1 2) (list 1 2))
                    (check-equal "strings" "a" "a")))))
          (check-equal "structural equality passes" (probe-failures p) 0))
        (let ((p (harness-probe (lambda () (check-equal "differ" 1 2)))))
          (check-equal "a difference fails" (probe-failures p) 1))))

    (harness-case "check-equal reports both values"
      (lambda ()
        (let* ((p (harness-probe (lambda () (check-equal "differ" 1 2))))
               (records (probe-failure-records p))
               (detail (failure-record-detail (car records))))
          (check "the expected value appears" (harness-string-contains? detail "2"))
          (check "the actual value appears" (harness-string-contains? detail "1"))
          (check-equal "the label is kept" (failure-record-what (car records)) "differ"))))

    (harness-case "check-not-equal is the inverse"
      (lambda ()
        (let ((p (harness-probe (lambda () (check-not-equal "differ" 1 2)))))
          (check-equal "different values pass" (probe-failures p) 0))
        (let ((p (harness-probe (lambda () (check-not-equal "same" 1 1)))))
          (check-equal "equal values fail" (probe-failures p) 1))))

    (harness-case "check-fail always fails and counts as a check"
      (lambda ()
        (let ((p (harness-probe (lambda () (check-fail "unreachable" "why")))))
          (check-equal "counted" (probe-checks p) 1)
          (check-equal "failed" (probe-failures p) 1))))

    (harness-case "check-raises passes only on a matching raise"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (check-raises "raises a symbol"
                                  (lambda (e) (eq? e 'boom))
                                  (lambda () (raise 'boom)))))))
          (check-equal "a matching raise passes" (probe-failures p) 0))
        (let ((p (harness-probe
                  (lambda ()
                    (check-raises "returns instead"
                                  (lambda (e) #t)
                                  (lambda () 'no-raise))))))
          (check-equal "returning normally fails" (probe-failures p) 1))
        (let ((p (harness-probe
                  (lambda ()
                    (check-raises "wrong object"
                                  (lambda (e) (eq? e 'expected))
                                  (lambda () (raise 'other)))))))
          (check-equal "the wrong raise fails" (probe-failures p) 1))))))

(harness-group "cases"
  (lambda ()

    (harness-case "a raise inside a case is that case's failure"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "raiser" (lambda () (raise 'boom)))
                    (harness-case "later" (lambda () (check "still runs" #t)))))))
          (check-equal "both cases ran" (probe-cases p) 2)
          (check-equal "one case failed" (probe-failed-cases p) 1)
          (check "the suite did not die" (not (probe-raised? p))))))

    (harness-case "a duplicate case id is an error, not a failure"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "same" (lambda () (check "a" #t)))
                    (harness-case "same" (lambda () (check "b" #t)))))))
          (check-equal "the second registration did not run" (probe-cases p) 1)
          (check-equal "recorded as an error" (probe-errors p) 1)
          (check-equal "not recorded as a failure" (probe-failures p) 0))))

    (harness-case "a failing case is counted once however many checks fail"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "two failures"
                      (lambda ()
                        (check "one" #f)
                        (check "two" #f)))))))
          (check-equal "two failures" (probe-failures p) 2)
          (check-equal "one failed case" (probe-failed-cases p) 1))))

    (harness-case "groups prefix case ids"
      (lambda ()
        (let* ((p (harness-probe
                   (lambda ()
                     (harness-group "outer"
                       (lambda ()
                         (harness-group "inner"
                           (lambda ()
                             (harness-case "leaf" (lambda () (check "x" #f))))))))))
               (records (probe-failure-records p)))
          (check-equal "dotted from outermost in"
                       (failure-record-id (car records))
                       "outer.inner.leaf"))))

    (harness-case "a group unwinds its name when its body raises"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (guard (e (#t #t))
                      (harness-group "doomed" (lambda () (raise 'boom))))
                    (harness-case "after" (lambda () (check "x" #f)))))))
          (check-equal "the failed group left no prefix behind"
                       (failure-record-id (car (probe-failure-records p)))
                       "after"))))))

(harness-group "cleanup"
  (lambda ()

    (harness-case "with-cleanup runs cleanup after a normal body"
      (lambda ()
        (let ((ran #f))
          (let ((value (with-cleanup (lambda () 'body)
                                     (lambda () (set! ran #t)))))
            (check-equal "the body's value is returned" value 'body)
            (check "cleanup ran" ran)))))

    (harness-case "with-cleanup runs cleanup after a raise and re-raises"
      (lambda ()
        (let ((ran #f))
          (let ((outcome (guard (e (#t (list 'raised e)))
                           (with-cleanup (lambda () (raise 'boom))
                                         (lambda () (set! ran #t))))))
            (check "cleanup ran" ran)
            (check "the original condition survives"
                   (and (eq? (car outcome) 'raised)
                        (eq? (car (cdr outcome)) 'boom)))))))

    (harness-case "a raising cleanup is recorded separately"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "c"
                      (lambda ()
                        (with-cleanup (lambda () 'body)
                                      (lambda () (raise 'cleanup-boom)))))))))
          (check-equal "counted as a cleanup failure"
                       (probe-cleanup-failures p) 1))))))

(harness-group "probe"
  (lambda ()

    (harness-case "a probe leaves the enclosing state untouched"
      (lambda ()
        (let ((before (harness-counters)))
          (harness-probe (lambda () (check "inside" #f) (check "inside" #f)))
          (check-equal "the enclosing counters are unchanged"
                       (harness-counters) before))))

    (harness-case "a probe reports whether its thunk raised"
      (lambda ()
        (check "a raising thunk is reported"
               (probe-raised? (harness-probe (lambda () (raise 'boom)))))
        (check "a normal thunk is not"
               (not (probe-raised? (harness-probe (lambda () 'fine)))))))

    (harness-case "a probe clears the ambient filter"
      (lambda ()
        (harness-set-filter! "no-such-case")
        (let ((p (harness-probe
                  (lambda () (harness-case "inner" (lambda () (check "x" #t)))))))
          (harness-set-filter! #f)
          (check-equal "the inner case was not skipped" (probe-cases p) 1))))))

(harness-group "filtering"
  (lambda ()

    (harness-case "a filter selects by substring and counts the rest as skipped"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-set-filter! "keep")
                    (harness-case "keep-me" (lambda () (check "x" #t)))
                    (harness-case "drop-me" (lambda () (check "y" #t)))))))
          (check-equal "one selected" (probe-cases p) 1)
          (check-equal "one skipped" (probe-skipped p) 1))))))

(harness-group "adapter"
  (lambda ()

    (harness-case "the adapter reports this runtime"
      (lambda ()
        (check "the runtime names itself"
               (or (string=? (adapter-runtime-name) "chez")
                   (string=? (adapter-runtime-name) "gambit")))
        (check "the version is bare and non-empty"
               (and (> (string-length (adapter-runtime-version)) 0)
                    (not (harness-string-contains? (adapter-runtime-version) "v"))))
        (check "the machine type is reported"
               (> (string-length (adapter-machine-type)) 0))
        (check-not-equal "the os is identified" (adapter-os) "unknown")
        (check-not-equal "the architecture is identified"
                         (adapter-architecture) "unknown")
        (check-equal "the launcher declared the mode"
                     (adapter-execution-mode) "source")))

    (harness-case "the adapter reaches the process environment"
      (lambda ()
        (check "the registration's test name is visible"
               (adapter-environment-variable "BYTE_MACHINE_TEST_NAME"))
        (check "an unset variable reads as false"
               (not (adapter-environment-variable "BYTE_MACHINE_NOT_SET_ANYWHERE")))))

    (harness-case "the adapter renders values and conditions"
      (lambda ()
        (check-equal "a list writes readably"
                     (adapter-value->string (list 1 2)) "(1 2)")
        (check-equal "a string writes with its quotes"
                     (adapter-value->string "a") "\"a\"")
        (let ((text (adapter-describe-condition (guard (e (#t e)) (car '())))))
          (check "a condition describes non-empty" (> (string-length text) 0))
          ;; Single-line, because it is appended to a one-line FAIL record.
          (check "on one line" (not (harness-string-contains? text "\n"))))))

    (harness-case "the shared subset's arithmetic is reachable"
      (lambda ()
        (check-equal "quotient" (quotient 7 2) 3)
        (check-equal "remainder" (remainder 7 2) 1)
        (check-equal "modulo" (modulo -7 2) 1)))

    (harness-case "output can be flushed"
      (lambda ()
        (adapter-flush-output)
        (check "flushing does not raise" #t)))

    (harness-case "the status vocabulary is what the build expects"
      (lambda ()
        (check-equal "pass" harness-status-pass 0)
        (check-equal "failed" harness-status-failed 1)
        (check-equal "harness error" harness-status-harness-error 2)
        (check-equal "provenance, reserved" harness-status-provenance 3)))

    (harness-case "exit status follows error over failure"
      (lambda ()
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "d" (lambda () (check "x" #f)))
                    (harness-case "d" (lambda () (check "y" #t)))))))
          (check-equal "a failure was recorded" (probe-failures p) 1)
          (check-equal "an error was recorded" (probe-errors p) 1))
        ;; The precedence itself, read from the live accessor rather than
        ;; inferred: a harness error outranks a failure because a suite that
        ;; mis-registered cannot be trusted about what it did run.
        (let ((p (harness-probe
                  (lambda ()
                    (harness-case "e" (lambda () (check "x" #f)))
                    (check-equal "failure alone yields 1" (harness-exit-status) 1)
                    (harness-case "f" (lambda () (check "y" #t)))
                    (harness-case "f" (lambda () (check "z" #t)))
                    (check-equal "an error outranks it" (harness-exit-status) 2)))))
          (check-equal "the inner assertions held" (probe-failures p) 1))))))
```

- [ ] **Step 2: Write the Chez wrapper and register the lane**

Create `test/support/harness/self/harness-self-tests.chez.sps`:

```scheme
;;; Chez wrapper for the runner's self-tests. Runtime-specific only in imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.self")

(include "harness-self-tests.scm")

(harness-finish)
```

Add to `test/CMakeLists.txt`:

```cmake
# The runner tested with the runner. Safe only because the bootstrap already
# established its primitives, and because every deliberate failure here runs
# inside a probe.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  TIMEOUT 120)
```

- [ ] **Step 3: Run it to see it fail**

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R "harness.self"
```

Expected: FAIL — `check-equal`, `harness-probe`, `with-cleanup` and the probe accessors are unbound.

- [ ] **Step 4: Add the remaining assertions to the runner**

In `harness-runner.scm`, after `check`:

```scheme
(define (check-equal what actual expected)
  (harness-count-check!)
  (if (equal? actual expected)
      #t
      (begin
        (harness-record-failure!
         what
         (string-append "expected " (adapter-value->string expected)
                        ", got " (adapter-value->string actual)))
        #f)))

(define (check-not-equal what actual unexpected)
  (harness-count-check!)
  (if (equal? actual unexpected)
      (begin
        (harness-record-failure!
         what
         (string-append "expected any value other than "
                        (adapter-value->string unexpected)))
        #f)
      #t))

(define (check-fail what detail)
  (harness-count-check!)
  (harness-record-failure! what detail)
  #f)

;; Run `thunk`; the check passes only when it raises an object satisfying
;; `predicate`. Returning normally is a failure, and so is raising the wrong
;; thing -- an expected error may match only its declared category.
(define (check-raises what predicate thunk)
  (harness-count-check!)
  (let ((outcome (guard (e (#t (list 'raised e)))
                   (list 'returned (thunk)))))
    (cond
      ((eq? (car outcome) 'returned)
       (harness-record-failure!
        what
        (string-append "expected a raise, but the thunk returned "
                       (adapter-value->string (car (cdr outcome)))))
       #f)
      ((predicate (car (cdr outcome))) #t)
      (else
       (harness-record-failure!
        what
        (string-append "raised object did not satisfy the predicate: "
                       (adapter-describe-condition (car (cdr outcome)))))
       #f))))

;; Run `body`, then always run `cleanup`. A failure inside cleanup is reported
;; separately and never replaces the original failure, which is re-raised
;; unchanged: the first condition is the one that explains the defect.
(define (with-cleanup body cleanup)
  (let ((outcome (guard (e (#t (list 'raised e)))
                   (list 'value (body)))))
    (let ((cleanup-outcome (guard (e (#t (list 'raised e)))
                             (list 'value (cleanup)))))
      (if (eq? (car cleanup-outcome) 'raised)
          (begin
            (set! harness-cleanup-failure-count
                  (+ harness-cleanup-failure-count 1))
            (harness-record-failure!
             "cleanup raised"
             (adapter-describe-condition (car (cdr cleanup-outcome)))))))
    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))
        (car (cdr outcome)))))
```

- [ ] **Step 5: Add filtering to `harness-case`**

In `harness-runner.scm`, add before `harness-case`:

```scheme
(define (harness-selected? id)
  (if harness-filter
      (harness-string-contains? id harness-filter)
      #t))

;; Exported so the self-tests can exercise filtering without depending on the
;; process environment.
(define (harness-set-filter! value) (set! harness-filter value))
```

and replace the `(else ...)` arm of `harness-case` with:

```scheme
      (else
       (set! harness-case-ids (cons id harness-case-ids))
       (if (not (harness-selected? id))
           (set! harness-skipped-count (+ harness-skipped-count 1))
           (begin
             (set! harness-case-count (+ harness-case-count 1))
             (set! harness-current-case id)
             (set! harness-current-case-failed #f)
             (let ((outcome (guard (e (#t (list 'raised e)))
                              (list 'value (thunk)))))
               (if (eq? (car outcome) 'raised)
                   (harness-record-failure!
                    "case raised"
                    (adapter-describe-condition (car (cdr outcome))))))
             (if harness-current-case-failed
                 (set! harness-failed-case-count (+ harness-failed-case-count 1))
                 (if harness-verbose
                     (harness-say (string-append "byte-machine-harness: pass " id))))
             (set! harness-current-case #f)))))))
```

The new arm nests two levels deeper than the one it replaces (`if` then `begin`), so it
needs two more trailing close parens than the old arm's five: one each for `begin` and
the new `if`, on top of the `set!`, `else`, `cond`, `let`, and `define` the old arm's five
already closed. Five here silently reproduces the old depth and leaves `let` and `define`
open, which is invisible until the reader runs off the end of the file.

Also set the filter from the environment in `harness-begin`, immediately after `harness-clear-state!`:

```scheme
  (set! harness-filter (adapter-environment-variable "BYTE_MACHINE_TEST_FILTER"))
  (if (and harness-filter (string=? harness-filter ""))
      (set! harness-filter #f))
```

- [ ] **Step 6: Add the probe**

In `harness-runner.scm`, after the groups-and-cases section and before the lifecycle section:

```scheme
;; ---------------------------------------------------------------------------
;; Probes
;; ---------------------------------------------------------------------------
;;
;; A probe runs a thunk against a fresh, isolated result state and returns what
;; happened, without disturbing the enclosing suite. This is how the runner
;; tests itself: a self-test needs to observe a *failing* check being recorded
;; without that failure counting against the run. Output is suppressed so an
;; expected failure cannot be mistaken for a real one in the log.

(define (harness-capture-state)
  (list harness-group-stack harness-case-ids harness-current-case
        harness-current-case-failed harness-case-count harness-failed-case-count
        harness-check-count harness-failure-count harness-error-count
        harness-skipped-count harness-cleanup-failure-count harness-failures
        harness-filter))

(define (harness-restore-state! s)
  (set! harness-group-stack (list-ref s 0))
  (set! harness-case-ids (list-ref s 1))
  (set! harness-current-case (list-ref s 2))
  (set! harness-current-case-failed (list-ref s 3))
  (set! harness-case-count (list-ref s 4))
  (set! harness-failed-case-count (list-ref s 5))
  (set! harness-check-count (list-ref s 6))
  (set! harness-failure-count (list-ref s 7))
  (set! harness-error-count (list-ref s 8))
  (set! harness-skipped-count (list-ref s 9))
  (set! harness-cleanup-failure-count (list-ref s 10))
  (set! harness-failures (list-ref s 11))
  (set! harness-filter (list-ref s 12)))

(define (harness-probe thunk)
  (let ((saved (harness-capture-state)))
    (harness-clear-state!)
    (set! harness-probe-depth (+ harness-probe-depth 1))
    (let ((raised (guard (e (#t #t)) (thunk) #f)))
      (let ((summary (list 'probe
                           harness-case-count
                           harness-failed-case-count
                           harness-check-count
                           harness-failure-count
                           harness-error-count
                           harness-skipped-count
                           harness-cleanup-failure-count
                           raised
                           (reverse harness-failures))))
        (set! harness-probe-depth (- harness-probe-depth 1))
        (harness-restore-state! saved)
        summary))))

(define (probe-cases p) (list-ref p 1))
(define (probe-failed-cases p) (list-ref p 2))
(define (probe-checks p) (list-ref p 3))
(define (probe-failures p) (list-ref p 4))
(define (probe-errors p) (list-ref p 5))
(define (probe-skipped p) (list-ref p 6))
(define (probe-cleanup-failures p) (list-ref p 7))
(define (probe-raised? p) (list-ref p 8))
(define (probe-failure-records p) (list-ref p 9))
(define (failure-record-id r) (list-ref r 0))
(define (failure-record-what r) (list-ref r 1))
(define (failure-record-detail r) (list-ref r 2))
```

**Important:** `harness-clear-state!` already resets `harness-filter` to `#f`. That is deliberate and is what the "a probe clears the ambient filter" self-test asserts — leaving a filter set would let it reach into every probe, skip the probe's own inner cases, and make the runner's self-tests fail for a reason unrelated to what they assert. `harness-begin` sets the real filter immediately after calling it.

- [ ] **Step 7: Extend the Chez export list**

In `harness.sls`, replace the assertions and helper export lines with:

```scheme
    ;; assertions
    check check-equal check-not-equal check-fail check-raises with-cleanup
    ;; self-testing
    harness-probe harness-set-filter!
    probe-cases probe-failed-cases probe-checks probe-failures
    probe-errors probe-skipped probe-cleanup-failures probe-raised?
    probe-failure-records
    failure-record-id failure-record-what failure-record-detail
    ;; pure helpers, exported so the runner's own tests can reach them
    harness-string-contains? harness-join harness-split harness-take
    harness-member? harness-failure-context
    harness-counters harness-restore-counters!
```

- [ ] **Step 8: Run the self-tests to verify they pass**

```bash
ctest --preset harness --output-on-failure -R "harness.self"
```

Expected: PASS. The summary line reports `failures=0 errors=0 status=0`, and no `FAIL` line appears — every deliberate failure was inside a probe.

- [ ] **Step 9: Prove the probe suppresses rather than swallows**

Temporarily change `harness-say` to always print (drop the `harness-quiet?` test) and re-run. Expected: the run still PASSES but the log now shows probe `FAIL` lines. Revert. This confirms the probe suppresses output without altering results.

- [ ] **Step 10: Commit**

```bash
git add test/support/harness test/CMakeLists.txt
git commit -m "test: add the probe, the remaining assertions, and the self-tests"
```

---

### Task 6: The two status-2 lanes

**Files:**
- Modify: `test/support/harness/shared/harness-runner.scm`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`
- Create: `test/support/harness/self/harness-duplicate-case.scm` + `.chez.sps`
- Create: `test/support/harness/self/harness-empty-selection.scm` + `.chez.sps`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Produces:
  - `harness-empty-selection-diagnosis(<case-count> <skipped-count>) -> string or #f` — the pure rule.
  - `harness-empty-selection-error() -> string or #f` — the same rule read off the live counters.

- [ ] **Step 1: Write the two bodies and their wrappers**

`test/support/harness/self/harness-duplicate-case.scm`:

```scheme
;;; Triggers a harness error so the process exits with status 2.
;;;
;;; A duplicate case id means one registration silently became unreachable,
;;; which is a defect in the suite rather than a failing assertion. It must
;;; therefore produce status 2 and stay distinguishable from the status 1 that
;;; harness-failing.scm produces.

(harness-case "duplicated" (lambda () (check "this one runs" #t)))
(harness-case "duplicated" (lambda () (check "this one never runs" #t)))
```

`test/support/harness/self/harness-duplicate-case.chez.sps`:

```scheme
;;; Chez wrapper for the duplicate-case body. Runtime-specific only in imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.duplicate-case")

(include "harness-duplicate-case.scm")

(harness-finish)
```

`test/support/harness/self/harness-empty-selection.scm`:

```scheme
;;; Registers one case that the ambient filter cannot select, so the run
;;; selects nothing and must exit 2.
;;;
;;; CTest fails an empty selection with execution.noTestsAction, and a suite
;;; that ran nothing must not report success one layer down either. The filter
;;; arrives from BYTE_MACHINE_TEST_FILTER, set by this lane's registration.

(harness-case "never-selected" (lambda () (check "unreachable" #t)))
```

`test/support/harness/self/harness-empty-selection.chez.sps`:

```scheme
;;; Chez wrapper for the empty-selection body. Runtime-specific only in imports.

(import (rnrs) (byte-machine test harness) (only (chezscheme) include))

(harness-begin "harness.empty-selection")

(include "harness-empty-selection.scm")

(harness-finish)
```

- [ ] **Step 2: Register both lanes and watch them fail**

Add to `test/CMakeLists.txt`:

```cmake
# A duplicate id is a defect in the suite, not a failing assertion: one
# registration silently became unreachable. Status 2, distinct from 1.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.chez.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

# A suite that selected nothing must not report success, for the same reason
# the presets refuse an empty CTest selection one layer up.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.chez.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name")
```

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R "duplicate-case|empty-selection"
```

Expected: `duplicate-case` PASSES already (Task 3 built the duplicate check). `empty-selection` FAILS with `expected exit 2, got 0` — the filter skipped the only case and the suite still reported success. That is the defect this task fixes.

- [ ] **Step 3: Add empty-selection detection**

In `harness-runner.scm`, add before `harness-exit-status`:

```scheme
;; CTest refuses an empty selection with execution.noTestsAction, and a suite
;; that ran nothing must not report success one layer down either.
;;
;; Split into a pure rule and a reader of the live counters, per AGENTS.md's
;; functional core / imperative shell rule. The split is not ceremony here: the
;; rule's interesting states are "no cases ran" and "every case was filtered
;; out", and a suite in either state cannot assert anything about itself from
;; the inside. As a function of two numbers it is directly testable.
;;
;; The two are distinguished because they are different bugs: a filter that
;; matched nothing is usually a typo in the invocation, while a suite with no
;; cases at all is usually a body that failed to load what it meant to.
(define (harness-empty-selection-diagnosis case-count skipped-count)
  (cond
    ((> case-count 0) #f)
    ((> skipped-count 0)
     (string-append "no case was selected: the filter skipped all "
                    (number->string skipped-count)
                    " registered cases"))
    (else "the suite registered no cases")))

(define (harness-empty-selection-error)
  (harness-empty-selection-diagnosis harness-case-count harness-skipped-count))
```

and make `harness-summary` consult it, by replacing its first line:

```scheme
(define (harness-summary)
  (let ((empty (harness-empty-selection-error)))
    (if empty (harness-record-error! empty)))
  (let ((status (harness-exit-status)))
```

- [ ] **Step 4: Export both, and cover the rule in the self-tests**

Add `harness-empty-selection-error` and `harness-empty-selection-diagnosis` to
the lifecycle exports in `harness.sls`.

Append to `test/support/harness/self/harness-self-tests.scm`:

```scheme
(harness-group "empty selection"
  (lambda ()

    (harness-case "an empty selection is diagnosed from the counts"
      (lambda ()
        (check "a run that executed cases is fine"
               (not (harness-empty-selection-diagnosis 3 0)))
        (check "no cases at all is reported"
               (string? (harness-empty-selection-diagnosis 0 0)))
        (check "a fully filtered run says the filter did it"
               (harness-string-contains?
                (harness-empty-selection-diagnosis 0 4) "filter"))
        (check "and says how many it skipped"
               (harness-string-contains?
                (harness-empty-selection-diagnosis 0 4) "4"))
        ;; The two empty states must not report the same thing: one is a typo in
        ;; the invocation, the other a body that failed to load.
        (check-not-equal "the two empty states read differently"
                         (harness-empty-selection-diagnosis 0 0)
                         (harness-empty-selection-diagnosis 0 4))))))
```

- [ ] **Step 5: Verify both lanes**

```bash
ctest --preset harness --output-on-failure -R "duplicate-case|empty-selection"
```

Expected: PASS, both. `empty-selection`'s output contains `HARNESS-ERROR no case was selected: the filter skipped all 1 registered cases` and a summary ending `status=2`.

- [ ] **Step 6: Confirm the self-tests still pass**

```bash
ctest --preset harness --output-on-failure
```

Expected: PASS, all Chez lanes. The self-tests use probes, and a probe's inner suite legitimately registers cases, so the new empty-selection rule must not have leaked into them.

- [ ] **Step 7: Commit**

```bash
git add test/support/harness test/CMakeLists.txt
git commit -m "feat: fail a suite that selected nothing"
```

---

### Task 7: The Gambit lane

The parity proof. The same five bodies, unchanged, run on Gambit. Nothing in `harness-runner.scm` may change in this task; if it must, the body was not portable and the change belongs in the shared file with a note saying why.

**Files:**
- Create: `test/support/harness/gambit/byte-machine/test/harness.sld`
- Create: `test/support/harness/self/harness-failing.gambit.scm`
- Create: `test/support/harness/self/harness-bootstrap.gambit.scm`
- Create: `test/support/harness/self/harness-self-tests.gambit.scm`
- Create: `test/support/harness/self/harness-duplicate-case.gambit.scm`
- Create: `test/support/harness/self/harness-empty-selection.gambit.scm`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Produces: the same names the Chez adapter exports, with the same arity and meaning. No new names.

- [ ] **Step 1: Register the five Gambit lanes and watch them fail**

Add to `test/CMakeLists.txt`, after the Chez lanes:

```cmake
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.gambit.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.gambit.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.failing-body.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-failing.gambit.scm"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.duplicate-case.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-duplicate-case.gambit.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.empty-selection.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-empty-selection.gambit.scm"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "BYTE_MACHINE_TEST_FILTER=no-case-has-this-in-its-name")
```

```bash
cmake --preset dev
```

Expected: FAIL at configure time — the five Gambit wrapper programs do not exist.

- [ ] **Step 2: Write the Gambit adapter**

Create `test/support/harness/gambit/byte-machine/test/harness.sld`:

```scheme
;;; Gambit runtime adapter for the byte-machine private test runner.
;;;
;;; This file and its Chez counterpart are the only places in the harness where
;;; runtime-specific identifiers may appear, and the two must export exactly the
;;; same names. That is checked by mutation: deleting an export here must make
;;; the self-tests fail on Gambit (spec section 9.1).
;;;
;;; The shared body is included by a path relative to this file, which is how
;;; Gambit resolves `include` inside `define-library`. Chez resolves the same
;;; body by bare filename through its launcher's source-directories. That
;;; difference is the one place the two mechanisms are visibly not the same.
;;;
;;; The import from `(gambit)` is deliberately narrow: importing it wholesale
;;; collides with `(scheme base)`.

(define-library (byte-machine test harness)
  (export
    ;; suite lifecycle
    harness-begin harness-finish harness-summary harness-exit-status
    harness-empty-selection-error harness-empty-selection-diagnosis
    harness-status-pass harness-status-failed
    harness-status-harness-error harness-status-provenance
    ;; structure
    harness-group harness-case
    ;; assertions
    check check-equal check-not-equal check-fail check-raises with-cleanup
    ;; self-testing
    harness-probe harness-set-filter!
    probe-cases probe-failed-cases probe-checks probe-failures
    probe-errors probe-skipped probe-cleanup-failures probe-raised?
    probe-failure-records
    failure-record-id failure-record-what failure-record-detail
    ;; pure helpers, exported so the runner's own tests can reach them
    harness-string-contains? harness-join harness-split harness-take
    harness-member? harness-failure-context
    harness-counters harness-restore-counters!
    ;; adapter protocol
    adapter-runtime-name adapter-runtime-version adapter-machine-type
    adapter-os adapter-architecture adapter-execution-mode
    adapter-environment-variable adapter-exit
    adapter-value->string adapter-describe-condition adapter-flush-output
    ;; arithmetic the shared subset uses; R7RS has it in (scheme base), R6RS
    ;; does not, so both adapters export it and shared bodies need not care
    modulo quotient remainder)

  (import (scheme base) (scheme write) (scheme process-context)
          (only (gambit) system-version-string system-type-string
                display-exception))

  (begin

    ;; --- small local helpers ---------------------------------------------
    ;;
    ;; Deliberately local rather than reused from the runner: the adapter is
    ;; what the runner is built on, so it must not depend on it.

    (define (adapter-contains? haystack needle)
      (let ((hn (string-length haystack)) (nn (string-length needle)))
        (let outer ((start 0))
          (cond ((> (+ start nn) hn) #f)
                ((let inner ((i 0))
                   (cond ((= i nn) #t)
                         ((char=? (string-ref haystack (+ start i))
                                  (string-ref needle i))
                          (inner (+ i 1)))
                         (else #f)))
                 #t)
                (else (outer (+ start 1)))))))

    (define (adapter-trim s)
      (let ((n (string-length s)))
        (let find-start ((a 0))
          (cond ((= a n) "")
                ((char=? (string-ref s a) #\space) (find-start (+ a 1)))
                (else
                 (let find-end ((b n))
                   (if (char=? (string-ref s (- b 1)) #\space)
                       (find-end (- b 1))
                       (substring s a b))))))))

    ;; Gambit's display-exception writes several lines and a trailing newline.
    ;; A FAIL record is one line, and a multi-line detail would break every
    ;; consumer that reads the log a line at a time, so newlines are folded to
    ;; spaces. Chez's display-condition already yields one line.
    (define (adapter-flatten text)
      (let loop ((chars (string->list text)) (acc '()))
        (cond ((null? chars) (adapter-trim (list->string (reverse acc))))
              ((or (char=? (car chars) #\newline)
                   (char=? (car chars) #\return))
               (loop (cdr chars) (cons #\space acc)))
              (else (loop (cdr chars) (cons (car chars) acc))))))

    ;; --- runtime identity -------------------------------------------------

    (define (adapter-runtime-name) "gambit")

    ;; (system-version-string) is "v4.9.8". Evidence records compare bare
    ;; numbers, so the marker is stripped here rather than in every consumer --
    ;; the same normalization cmake/ByteMachineGambit.cmake performs.
    (define (adapter-runtime-version)
      (let ((s (system-version-string)))
        (if (and (> (string-length s) 0) (char=? (string-ref s 0) #\v))
            (substring s 1 (string-length s))
            s)))

    ;; The target triple, e.g. "aarch64-apple-darwin25.6.0". Reported whole as
    ;; evidence; os and architecture are derived from it below.
    (define (adapter-machine-type) (system-type-string))

    (define (adapter-triple-architecture)
      (let* ((triple (adapter-machine-type))
             (n (string-length triple)))
        (let loop ((i 0))
          (cond ((= i n) triple)
                ((char=? (string-ref triple i) #\-) (substring triple 0 i))
                (else (loop (+ i 1)))))))

    (define adapter-architecture-table
      '(("aarch64" . "arm64")
        ("arm64" . "arm64")
        ("x86_64" . "amd64")
        ("amd64" . "amd64")
        ("i386" . "x86")
        ("i686" . "x86")
        ("armv7l" . "arm32")
        ("riscv64" . "riscv64")))

    (define adapter-os-table
      '(("darwin" . "darwin")
        ("linux" . "linux")
        ("mingw" . "windows")
        ("cygwin" . "windows")
        ("windows" . "windows")
        ("freebsd" . "freebsd")
        ("openbsd" . "openbsd")
        ("netbsd" . "netbsd")
        ("solaris" . "solaris")))

    (define (adapter-lookup-exact table key)
      (cond ((null? table) #f)
            ((string=? key (car (car table))) (cdr (car table)))
            (else (adapter-lookup-exact (cdr table) key))))

    (define (adapter-lookup-substring table text)
      (cond ((null? table) #f)
            ((adapter-contains? text (car (car table))) (cdr (car table)))
            (else (adapter-lookup-substring (cdr table) text))))

    (define (adapter-architecture)
      (let ((hit (adapter-lookup-exact adapter-architecture-table
                                       (adapter-triple-architecture))))
        (if hit hit "unknown")))

    (define (adapter-os)
      (let ((hit (adapter-lookup-substring adapter-os-table
                                           (adapter-machine-type))))
        (if hit hit "unknown")))

    ;; Declared by the registration, because the lane is the only party that
    ;; knows what it actually loaded.
    (define (adapter-execution-mode)
      (let ((m (get-environment-variable "BYTE_MACHINE_EXECUTION_MODE")))
        (if (and m (not (string=? m ""))) m "unknown")))

    ;; --- services ----------------------------------------------------------

    (define (adapter-environment-variable name) (get-environment-variable name))

    (define (adapter-exit code) (exit code))

    (define (adapter-value->string v)
      (let ((port (open-output-string)))
        (write v port)
        (get-output-string port)))

    (define (adapter-describe-condition obj)
      (let ((port (open-output-string)))
        (display-exception obj port)
        (adapter-flatten (get-output-string port))))

    (define (adapter-flush-output) (flush-output-port (current-output-port))))

  ;; --- shared body ---------------------------------------------------------
  ;;
  ;; Source-file-relative, which is how Gambit resolves include inside
  ;; define-library. Nothing below this point is Gambit-specific.

  (include "../../../shared/harness-runner.scm"))
```

- [ ] **Step 3: Write the five Gambit wrappers**

`harness-failing.gambit.scm`:

```scheme
;;; Gambit wrapper for the failing body. Runtime-specific only in its imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.failing")

(include "harness-failing.scm")

(harness-finish)
```

`harness-bootstrap.gambit.scm`:

```scheme
;;; Gambit wrapper for the bootstrap body. Runtime-specific only in its imports.
;;;
;;; harness-begin is deliberately not called: the bootstrap judges the runner
;;; without using its suite lifecycle.

(import (scheme base) (scheme write) (byte-machine test harness))

(include "harness-bootstrap.scm")
```

`harness-self-tests.gambit.scm`:

```scheme
;;; Gambit wrapper for the runner's self-tests. Runtime-specific only in imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.self")

(include "harness-self-tests.scm")

(harness-finish)
```

`harness-duplicate-case.gambit.scm`:

```scheme
;;; Gambit wrapper for the duplicate-case body. Runtime-specific only in imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.duplicate-case")

(include "harness-duplicate-case.scm")

(harness-finish)
```

`harness-empty-selection.gambit.scm`:

```scheme
;;; Gambit wrapper for the empty-selection body. Runtime-specific only in imports.

(import (scheme base) (scheme write) (byte-machine test harness))

(harness-begin "harness.empty-selection")

(include "harness-empty-selection.scm")

(harness-finish)
```

- [ ] **Step 4: Run every lane on both runtimes**

```bash
cmake --preset dev && ctest --preset harness --output-on-failure
```

Expected: PASS, ten Scheme lanes plus the CMake specifications. Each Gambit summary line reports `runtime=gambit mode=source`, and each Chez one `runtime=chez mode=source`.

- [ ] **Step 5: Prove the parity check bites**

Temporarily delete `adapter-os` from the Gambit `.sld` export list and re-run:

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R "gambit"
```

Expected: FAIL — the self-tests and the bootstrap both call `adapter-os`, so the Gambit lanes fail to load. Restore the export and confirm PASS. This is the manual form of the mutation Task 8 automates.

- [ ] **Step 6: Commit**

```bash
git add test/support/harness test/CMakeLists.txt
git commit -m "feat: run the same harness bodies on Gambit"
```

---

### Task 8: Mutation testing for the Scheme harness

**Files:**
- Modify: `test/support/cmake/MutationRunner.cmake`
- Create: `test/support/cmake/SchemeMutationSuite.cmake`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `byte_machine_mutation`, `byte_machine_mutation_run` — unchanged signatures.
- Produces: `BYTE_MACHINE_MUTATION_STAGE_DIRS` (list, default `cmake;test/support/cmake`), `BYTE_MACHINE_MUTATION_VERIFY_COMMAND` (list, default empty), `byte_machine_mutation_reset()`.

- [ ] **Step 1: Generalize the stage set**

In `test/support/cmake/MutationRunner.cmake`, after `set(_bm_mutation_count 0)`, add:

```cmake
# Which trees are copied into the scratch tree. The default is what the
# CMake-layer suite needs; the Scheme suite adds the harness and the launchers,
# whose includes resolve against their relative layout and would break if the
# tree were flattened.
set(BYTE_MACHINE_MUTATION_STAGE_DIRS "cmake" "test/support/cmake")

# What decides whether a mutation was caught. Empty keeps the original
# behaviour: run the named specification under `cmake -P` inside the stage. The
# Scheme suite replaces it with a real execution lane, because a Scheme defect
# is only visible to something that runs Scheme.
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND "")
```

Replace `byte_machine_mutation_stage` entirely with:

```cmake
# byte_machine_mutation_stage(<source_root> <stage_dir>)
#
# Copy every declared tree into a scratch tree, preserving the relative layout
# the specifications' and the libraries' includes depend on.
function(byte_machine_mutation_stage source_root stage_dir)
  file(REMOVE_RECURSE "${stage_dir}")

  foreach(rel IN LISTS BYTE_MACHINE_MUTATION_STAGE_DIRS)
    file(MAKE_DIRECTORY "${stage_dir}/${rel}")
    file(GLOB entries "${source_root}/${rel}/*")
    if(NOT entries)
      message(FATAL_ERROR
        "byte-machine-mutation: staging found nothing under '${rel}' in "
        "'${source_root}'. Refusing to run: an empty stage would make every "
        "mutation look caught, which is the exact false confidence this file "
        "exists to eliminate.")
    endif()
    # Directories are copied whole, so a tree such as the harness keeps the
    # layout its relative includes resolve against.
    file(COPY ${entries} DESTINATION "${stage_dir}/${rel}")
  endforeach()
endfunction()
```

- [ ] **Step 2: Generalize the verify command and add a reset**

Replace `byte_machine_mutation_run_spec` with:

```cmake
# byte_machine_mutation_run_spec(<stage_dir> <spec> <out_rc>)
#
# A non-numeric result -- a command that could not be launched at all -- would
# compare unequal to 0 and count as caught. That is safe only because the
# baseline run happens first: if the verify command cannot run, the baseline
# fails and nothing below is trusted.
function(byte_machine_mutation_run_spec stage_dir spec out_rc)
  if(BYTE_MACHINE_MUTATION_VERIFY_COMMAND)
    set(command ${BYTE_MACHINE_MUTATION_VERIFY_COMMAND})
  else()
    set(command "${CMAKE_COMMAND}" -P "${stage_dir}/test/support/cmake/${spec}")
  endif()

  execute_process(
    COMMAND ${command}
    WORKING_DIRECTORY "${stage_dir}"
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err)
  set(${out_rc} "${rc}" PARENT_SCOPE)
endfunction()
```

And add, after it:

```cmake
# byte_machine_mutation_reset()
#
# Discard the declared mutations so a second set can run under a different
# verify command in the same script. Used by the Scheme suite, which verifies
# the shared runner on one runtime but must verify each adapter's export list on
# its own runtime -- a Chez lane cannot notice a name missing from the Gambit
# library.
function(byte_machine_mutation_reset)
  set(_bm_mutation_count 0 PARENT_SCOPE)
endfunction()
```

- [ ] **Step 3: Verify the CMake suite is unchanged by the generalization**

```bash
cmake -P test/support/cmake/MutationSuite.cmake
```

Expected: PASS, same output as before — `baseline green`, then `caught` for every mutation, then `all accounted for`.

- [ ] **Step 4: Write the Scheme mutation suite**

`FIND` is literal text, not a regex, and is matched as a substring of the whole
file. Copy each pattern from `harness-runner.scm` exactly as it stands at the end
of Task 7, indentation included. If `SITES` reports a different count than
declared, the file has drifted: copy the current text rather than loosening the
pattern, or the mutation silently stops covering that code. That check exists
precisely because this is easy to get wrong.

Create `test/support/cmake/SchemeMutationSuite.cmake`:

```cmake
# Proof that the Scheme harness's self-tests are not vacuous.
#
# The harness is the instrument every later milestone is measured with. If
# `check-equal` silently always returned true, the whole project would go green
# and stay green, and no test written with `check-equal` could notice. So each
# decision in the runner is broken in turn on a staged copy, and the self-tests
# must fail.
#
# Verification runs the Chez source lane. The mutated file is the shared runner
# body -- identical text on both runtimes -- so verifying on a second runtime
# would re-prove the same mutation at double the cost. The one exception is an
# adapter's export list, which is per-runtime by definition: a Chez lane cannot
# notice a name missing from the Gambit library. Those run in a second pass.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/MutationRunner.cmake")

get_filename_component(SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(WORK_DIR "$ENV{BYTE_MACHINE_TEST_TMPDIR}")
else()
  set(WORK_DIR "${SOURCE_ROOT}/build/scheme-mutation")
endif()
set(STAGE_DIR "${WORK_DIR}/stage")

# The object guard the Chez launcher requires. It lives outside the stage
# because the stage is removed and rebuilt on every run, and the launcher
# refuses to start if the guard is missing.
set(GUARD_DIR "${WORK_DIR}/guard")
file(REMOVE_RECURSE "${GUARD_DIR}")
file(MAKE_DIRECTORY "${GUARD_DIR}")

if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
  message(FATAL_ERROR
    "byte-machine-mutation: BYTE_MACHINE_CHEZ_EXECUTABLE was not passed in. "
    "This suite runs a real execution lane, so it cannot be verified under the "
    "no-scheme preset; the registration must forward the discovered path.")
endif()

set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

set(RUNNER test/support/harness/shared/harness-runner.scm)

# --- Assertions ------------------------------------------------------------

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check passes whatever it is given"
  FIND [[(define (check what value)
  (harness-count-check!)
  (if value]]
  REPLACE [[(define (check what value)
  (harness-count-check!)
  (if #t]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-equal compares identity instead of structure"
  FIND [[  (if (equal? actual expected)]]
  REPLACE [[  (if (eq? actual expected)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-not-equal is no longer the inverse"
  FIND [[  (if (equal? actual unexpected)]]
  REPLACE [[  (if (not (equal? actual unexpected))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-fail records nothing"
  FIND [[  (harness-record-failure! what detail)
  #f)]]
  REPLACE [[  #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: check-raises accepts a thunk that returned normally"
  FIND [[      ((eq? (car outcome) 'returned)]]
  REPLACE [[      ((eq? (car outcome) 'never-happens)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: failures are not counted"
  FIND [[  (set! harness-failure-count (+ harness-failure-count 1))]]
  REPLACE [[  (set! harness-failure-count harness-failure-count)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a failure never marks its case as failed"
  FIND [[  (set! harness-current-case-failed #t)]]
  REPLACE [[  (set! harness-current-case-failed #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a duplicate case id is silently accepted, making one registration unreachable"
  FIND [[      ((harness-member? id harness-case-ids)]]
  REPLACE [[      (#f]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a raise inside a case is recorded as an error rather than that case's failure"
  FIND [[                   (harness-record-failure!
                    "case raised"]]
  REPLACE [[                   (harness-record-error!
                    "case raised"]])

# Two sites, deliberately: harness-group and with-cleanup re-raise through
# identical text, and both self-tests -- the group one and the cleanup one --
# must notice. Splitting them would need the two to be written differently for
# no reason other than to be mutated apart.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a body's condition is swallowed instead of re-raised (group and cleanup)"
  SITES 2
  FIND [[    (if (eq? (car outcome) 'raised)
        (raise (car (cdr outcome)))]]
  REPLACE [[    (if #f
        (raise (car (cdr outcome)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: cleanup never runs"
  FIND [[    (let ((cleanup-outcome (guard (e (#t (list 'raised e)))
                             (list 'value (cleanup)))))]]
  REPLACE [[    (let ((cleanup-outcome (list 'value #f)))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a failure outranks a harness error in the exit status"
  FIND [[  (cond ((> harness-error-count 0) harness-status-harness-error)
        ((> harness-failure-count 0) harness-status-failed)]]
  REPLACE [[  (cond ((> harness-failure-count 0) harness-status-failed)
        ((> harness-error-count 0) harness-status-harness-error)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a probe does not restore the state it displaced"
  FIND [[        (harness-restore-state! saved)
]]
  REPLACE [[]])

# Anchored on the preceding line. `(set! harness-filter #f))` alone is also a
# substring of the differently-indented copy inside harness-begin, so the bare
# pattern would match two sites and the SITES check would reject it.
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a probe inherits the ambient filter and skips its own cases"
  FIND [[  (set! harness-failures '())
  (set! harness-filter #f))]]
  REPLACE [[  (set! harness-failures '()))]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: an empty selection is not diagnosed"
  FIND [[    ((> case-count 0) #f)]]
  REPLACE [[    ((> case-count -1) #f)]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: a filtered-out run is diagnosed as having registered nothing"
  FIND [[    ((> skipped-count 0)]]
  REPLACE [[    (#f]])

byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.chez.sps
  LABEL "runner: probe output suppression is removed"
  FIND [[(define (harness-quiet?) (> harness-probe-depth 0))]]
  REPLACE [[(define (harness-quiet?) #f)]]
  EXPECT_SURVIVES
    "suppression changes only what is printed, never a counter or a status, so no assertion can observe it from inside the process; it is covered by the manual check in the implementation plan's Task 5 step 9, and its real cost -- a log that teaches readers to ignore FAIL lines -- is not machine-checkable")

byte_machine_mutation(
  FILE test/support/harness/chez/byte-machine/test/harness.sls
  SPEC harness-self-tests.chez.sps
  LABEL "chez adapter: an exported adapter name is dropped"
  FIND [[    adapter-os adapter-architecture adapter-execution-mode]]
  REPLACE [[    adapter-architecture adapter-execution-mode]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Second pass: the Gambit adapter's export list -------------------------
#
# Per-runtime by definition. One mutation, one process; the runner mutations
# above are not repeated.

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  byte_machine_mutation_reset()

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit"
    "-f"
    "${STAGE_DIR}/test/support/harness/self/harness-self-tests.gambit.scm")

  byte_machine_mutation(
    FILE test/support/harness/gambit/byte-machine/test/harness.sld
    SPEC harness-self-tests.gambit.scm
    LABEL "gambit adapter: an exported adapter name is dropped"
    FIND [[    adapter-os adapter-architecture adapter-execution-mode]]
    REPLACE [[    adapter-architecture adapter-execution-mode]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
else()
  message(STATUS
    "byte-machine-mutation: no Gambit was passed in, so the Gambit adapter's "
    "export list is not covered by this run.")
endif()

message(STATUS "byte-machine-spec: scheme mutation suite complete")
```

- [ ] **Step 5: Register it**

Add to `test/CMakeLists.txt`:

```cmake
# The harness is the instrument every later milestone is measured with, so a
# passing self-test suite is not evidence until something has proved it can
# fail. This breaks each decision in the runner on a staged copy and requires
# the self-tests to notice. Registered only when a Chez was discovered: it runs
# a real lane and cannot be verified under the no-scheme preset.
if(BYTE_MACHINE_CHEZ_EXECUTABLE)
  byte_machine_add_test(
    NAME byte-machine.harness.scheme-mutation.cmake.direct
    COMMAND "${CMAKE_COMMAND}"
            "-DBYTE_MACHINE_CHEZ_EXECUTABLE=${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "-DBYTE_MACHINE_GAMBIT_EXECUTABLE=${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
            -P "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SchemeMutationSuite.cmake"
    TIMEOUT 900
    LABELS unit
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")
endif()
```

- [ ] **Step 6: Run it**

```bash
cmake --preset dev && ctest --preset harness --output-on-failure -R scheme-mutation
```

Expected: PASS. Output shows `baseline green`, one `caught` line per mutation, one `SURVIVES (expected)` line for the suppression mutation, and `all accounted for` for each of the two passes.

- [ ] **Step 7: Prove the suite is not itself vacuous**

Temporarily delete the `harness-case "check-equal compares with equal?"` case from `harness-self-tests.scm` and re-run. Expected: FAIL with `UNCAUGHT runner: check-equal compares identity instead of structure`. Restore and confirm PASS.

- [ ] **Step 8: Commit**

```bash
git add test/support/cmake test/CMakeLists.txt
git commit -m "test: require the harness self-tests to notice a broken runner"
```

---

### Task 9: Portability guard

**Files:**
- Create: `cmake/ByteMachinePortabilityGuard.cmake`
- Create: `test/support/cmake/ByteMachinePortabilityGuardSpec.cmake`
- Modify: `CMakeLists.txt`, `test/CMakeLists.txt`, `test/support/cmake/MutationSuite.cmake`

**Interfaces:**
- Produces:
  - `byte_machine_guard_shared_bodies(<out_bodies> <path>...)` — drops wrapper files from a glob result.
  - `byte_machine_guard_missing_wrappers(<out_missing> <body>...)` — returns bodies lacking a `.chez.sps` or `.gambit.scm` sibling, each as `<body>|<missing-wrapper>`.
  - `byte_machine_guard_duplicate_basenames(<out_duplicates> <path>...)` — returns basenames appearing more than once.
  - `byte_machine_portability_guard(SHARED_DIRS <dir>... WRAPPED_DIRS <dir>...)` — the configure-time shell.

- [ ] **Step 1: Write the failing specification**

Create `test/support/cmake/ByteMachinePortabilityGuardSpec.cmake`:

```cmake
# Specification for cmake/ByteMachinePortabilityGuard.cmake.
#
# Two rules, both about failures that are silent by construction.
#
# A shared body with only one wrapper is proven on one runtime while looking
# like it is proven on two. Nothing fails; there is simply one fewer lane than
# the tree suggests.
#
# Two shared bodies with the same basename collapse into one file, because Chez
# resolves includes through source-directories -- a single flat namespace shared
# with src/common once Milestone 1 lands. The build stays green and one of the
# two bodies is never executed again.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/ByteMachinePortabilityGuard.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

# --- Wrapper files are not shared bodies -----------------------------------

byte_machine_guard_shared_bodies(bodies
  "/h/self/a.scm" "/h/self/a.gambit.scm" "/h/self/b.scm")
spec_check_equal("${bodies}" "/h/self/a.scm;/h/self/b.scm"
  "a Gambit wrapper is not itself a shared body")

# Chez wrappers end in .sps and so fall outside a *.scm glob already. The rule
# is stated anyway rather than left to an extension that happens to differ,
# because a future glob that included .sps would otherwise silently start
# treating wrappers as bodies.
byte_machine_guard_shared_bodies(bodies "/h/self/a.scm" "/h/self/a.chez.sps")
spec_check_equal("${bodies}" "/h/self/a.scm"
  "a Chez wrapper is not itself a shared body")

# --- Duplicate basenames ---------------------------------------------------

byte_machine_guard_duplicate_basenames(dupes
  "/h/shared/runner.scm" "/src/common/runner.scm")
spec_check_equal("${dupes}" "runner.scm"
  "the same basename in two directories is a collision")

byte_machine_guard_duplicate_basenames(dupes
  "/h/shared/harness-runner.scm" "/src/common/model.scm")
spec_check_equal("${dupes}" ""
  "distinct basenames are not a collision")

# Reported once however many times it repeats, so the diagnostic names the
# problem rather than counting it.
byte_machine_guard_duplicate_basenames(dupes "/a/x.scm" "/b/x.scm" "/c/x.scm")
spec_check_equal("${dupes}" "x.scm" "a basename is reported once")

# Seeded, so a function that never writes its output is distinguishable from one
# that correctly reports no duplicates.
set(dupes "seed")
byte_machine_guard_duplicate_basenames(dupes "/a/x.scm")
spec_check_equal("${dupes}" "" "a single body has no duplicates")

# --- Missing wrappers ------------------------------------------------------
#
# Checked against real files, because the rule is about what is on disk. The
# staging is written into the test's own temporary directory.

if(DEFINED ENV{BYTE_MACHINE_TEST_TMPDIR})
  set(fixture "$ENV{BYTE_MACHINE_TEST_TMPDIR}/guard-fixture")
else()
  set(fixture "${CMAKE_CURRENT_LIST_DIR}/../../../build/guard-fixture")
endif()
file(REMOVE_RECURSE "${fixture}")
file(MAKE_DIRECTORY "${fixture}")

file(WRITE "${fixture}/both.scm" "")
file(WRITE "${fixture}/both.chez.sps" "")
file(WRITE "${fixture}/both.gambit.scm" "")
file(WRITE "${fixture}/chez-only.scm" "")
file(WRITE "${fixture}/chez-only.chez.sps" "")
file(WRITE "${fixture}/neither.scm" "")

byte_machine_guard_missing_wrappers(missing "${fixture}/both.scm")
spec_check_equal("${missing}" "" "a body with both wrappers is complete")

byte_machine_guard_missing_wrappers(missing "${fixture}/chez-only.scm")
spec_check_equal("${missing}" "${fixture}/chez-only.scm|${fixture}/chez-only.gambit.scm"
  "a body with no Gambit wrapper is reported")

byte_machine_guard_missing_wrappers(missing "${fixture}/neither.scm")
list(LENGTH missing missing_count)
spec_check_equal("${missing_count}" "2" "a body with no wrappers reports both")

spec_finish("ByteMachinePortabilityGuard")
```

- [ ] **Step 2: Run it to see it fail**

```bash
cmake -P test/support/cmake/ByteMachinePortabilityGuardSpec.cmake
```

Expected: FAIL — `include could not find requested file`.

- [ ] **Step 3: Write the module**

Create `cmake/ByteMachinePortabilityGuard.cmake`:

```cmake
# Guard the two rules that keep shared bodies shared.
#
# WHY THESE TWO FAILURES NEED A GUARD RATHER THAN A TEST
#
# Both are silent. A body with only one wrapper is proven on one runtime while
# the tree suggests two: nothing fails, there is simply one fewer lane than
# there appears to be. Two bodies with the same basename collapse into one file,
# because Chez resolves includes through source-directories -- one flat,
# process-global namespace, shared with src/common once Milestone 1 lands -- and
# the build stays green with one body never executed again.
#
# Neither can be caught by a test that runs, because in both cases the thing
# that should have run is exactly the thing that does not. So they are configure
# failures: a violation stops the build.
#
# The glob is CONFIGURE_DEPENDS and its result is asserted non-empty. A guard
# that silently skips new files, or that finds nothing and reports every source
# portable, is worse than no guard at all.

include_guard(GLOBAL)

# --- Functional core -------------------------------------------------------

# byte_machine_guard_shared_bodies(<out_bodies> <path>...)
#
# Drop wrapper files from a glob result. A wrapper declares its runtime in its
# own name -- harness-failing.chez.sps, harness-failing.gambit.scm -- and exists
# precisely to hold the import forms a shared body may not have.
function(byte_machine_guard_shared_bodies out_bodies)
  set(bodies ${ARGN})
  list(FILTER bodies EXCLUDE REGEX "\\.(chez|gambit)\\.(sps|scm)$")
  set(${out_bodies} "${bodies}" PARENT_SCOPE)
endfunction()

# byte_machine_guard_duplicate_basenames(<out_duplicates> <path>...)
#
# Basenames appearing more than once, each reported once however often it
# repeats. Compared with the extension, because the extension is part of what
# an include names.
function(byte_machine_guard_duplicate_basenames out_duplicates)
  set(seen "")
  set(duplicates "")
  foreach(path IN LISTS ARGN)
    get_filename_component(base "${path}" NAME)
    if(base IN_LIST seen)
      list(APPEND duplicates "${base}")
    endif()
    list(APPEND seen "${base}")
  endforeach()
  if(duplicates)
    list(REMOVE_DUPLICATES duplicates)
  endif()
  set(${out_duplicates} "${duplicates}" PARENT_SCOPE)
endfunction()

# byte_machine_guard_missing_wrappers(<out_missing> <body>...)
#
# Bodies lacking a wrapper, reported as `<body>|<missing wrapper>` so the
# diagnostic can name the file that should exist rather than only the one that
# does.
function(byte_machine_guard_missing_wrappers out_missing)
  set(missing "")
  foreach(body IN LISTS ARGN)
    get_filename_component(dir "${body}" DIRECTORY)
    # NAME_WE strips from the first dot, so `x.gambit.scm` and `x.scm` both
    # yield `x`. That is what makes the sibling names below correct.
    get_filename_component(base "${body}" NAME_WE)
    foreach(wrapper "${dir}/${base}.chez.sps" "${dir}/${base}.gambit.scm")
      if(NOT EXISTS "${wrapper}")
        list(APPEND missing "${body}|${wrapper}")
      endif()
    endforeach()
  endforeach()
  set(${out_missing} "${missing}" PARENT_SCOPE)
endfunction()

# --- Imperative shell ------------------------------------------------------

# byte_machine_portability_guard(SHARED_DIRS <dir>... WRAPPED_DIRS <dir>...)
#
# SHARED_DIRS hold bodies included by a library; they need no wrappers.
# WRAPPED_DIRS hold bodies included by a program; each needs both wrappers.
# Every body from either kind of directory shares one basename namespace.
function(byte_machine_portability_guard)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "" "SHARED_DIRS;WRAPPED_DIRS")

  set(patterns "")
  foreach(dir IN LISTS arg_SHARED_DIRS arg_WRAPPED_DIRS)
    list(APPEND patterns "${dir}/*.scm")
  endforeach()

  file(GLOB globbed CONFIGURE_DEPENDS ${patterns})
  byte_machine_guard_shared_bodies(bodies ${globbed})

  if(NOT bodies)
    message(FATAL_ERROR
      "byte-machine: the portability guard found no shared bodies to check, "
      "which means its glob is wrong rather than that the sources are "
      "portable. Searched: ${patterns}")
  endif()

  byte_machine_guard_duplicate_basenames(duplicates ${bodies})
  if(duplicates)
    message(FATAL_ERROR
      "byte-machine: shared body basenames must be unique across every shared "
      "body directory, but these repeat: ${duplicates}. Chez resolves includes "
      "through source-directories, which is one flat namespace, so two bodies "
      "with one basename collapse into a single file and the build stays green "
      "with one of them never executed again.")
  endif()

  set(wrapped "")
  foreach(dir IN LISTS arg_WRAPPED_DIRS)
    file(GLOB dir_globbed CONFIGURE_DEPENDS "${dir}/*.scm")
    byte_machine_guard_shared_bodies(dir_bodies ${dir_globbed})
    list(APPEND wrapped ${dir_bodies})
  endforeach()

  byte_machine_guard_missing_wrappers(missing ${wrapped})
  if(missing)
    message(FATAL_ERROR
      "byte-machine: every shared test body needs a wrapper for each runtime, "
      "or it is proven on one runtime while looking as though it is proven on "
      "two. Missing (body|wrapper): ${missing}")
  endif()

  list(LENGTH bodies body_count)
  message(STATUS
    "byte-machine portability guard: ${body_count} shared bodies, "
    "unique basenames, every wrapped body paired")
endfunction()
```

- [ ] **Step 4: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachinePortabilityGuardSpec.cmake
```

Expected: PASS, ending `byte-machine-spec: ByteMachinePortabilityGuard verified`.

- [ ] **Step 5: Wire it in**

In `CMakeLists.txt`, after `include(ByteMachineSchemeLane)`:

```cmake
  include(ByteMachinePortabilityGuard)
```

In `test/CMakeLists.txt`, immediately after the harness path variables and *before* any lane is registered:

```cmake
# Checked before any lane is registered: a body missing a wrapper must stop the
# build, not produce a suite that quietly proves one runtime.
byte_machine_portability_guard(
  SHARED_DIRS "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
  WRAPPED_DIRS "${BYTE_MACHINE_HARNESS_SELF_DIR}")

byte_machine_add_test(
  NAME byte-machine.harness.cmake-portability-guard.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/ByteMachinePortabilityGuardSpec.cmake"
  TIMEOUT 120
  LABELS unit)
```

- [ ] **Step 6: Prove the guard bites**

```bash
mv test/support/harness/self/harness-failing.gambit.scm /tmp/held.scm
cmake --preset dev
```

Expected: FAIL at configure time naming `harness-failing.scm|…harness-failing.gambit.scm`. Then:

```bash
mv /tmp/held.scm test/support/harness/self/harness-failing.gambit.scm
cp test/support/harness/shared/harness-runner.scm test/support/harness/self/harness-runner.scm
cmake --preset dev
```

Expected: FAIL naming `harness-runner.scm` as a repeated basename. Then:

```bash
rm test/support/harness/self/harness-runner.scm
cmake --preset dev && ctest --preset harness --output-on-failure
```

Expected: PASS, everything green.

- [ ] **Step 7: Add mutations**

In `test/support/cmake/MutationSuite.cmake`, before `byte_machine_mutation_run(...)`:

```cmake
# --- ByteMachinePortabilityGuard -------------------------------------------

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake
  SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: wrapper files are counted as shared bodies"
  FIND [[  list(FILTER bodies EXCLUDE REGEX "\\.(chez|gambit)\\.(sps|scm)$")]]
  REPLACE [[]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake
  SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: a repeated basename is not reported"
  FIND [[    if(base IN_LIST seen)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake
  SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: only the Chez wrapper is required"
  FIND [[    foreach(wrapper "${dir}/${base}.chez.sps" "${dir}/${base}.gambit.scm")]]
  REPLACE [[    foreach(wrapper "${dir}/${base}.chez.sps")]])

byte_machine_mutation(
  FILE cmake/ByteMachinePortabilityGuard.cmake
  SPEC ByteMachinePortabilityGuardSpec.cmake
  LABEL "guard: the duplicate accessor leaves a stale value when there are none"
  FIND [[  set(seen "")
  set(duplicates "")]]
  REPLACE [[  set(seen "")]])
```

- [ ] **Step 8: Verify and commit**

```bash
cmake --preset no-scheme && ctest --preset no-scheme && cmake --preset dev && ctest --preset harness --output-on-failure
```

Expected: PASS both.

```bash
git add cmake/ByteMachinePortabilityGuard.cmake test/support/cmake CMakeLists.txt test/CMakeLists.txt
git commit -m "feat: guard wrapper pairing and shared-body basename uniqueness"
```

---

### Task 10: Documentation and the stale vocabulary line

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.org`

- [ ] **Step 1: Correct the stale CHANGELOG line**

In `CHANGELOG.md`, delete the entry under **Changed** reading:

```markdown
- The `expected-red` test layer is withdrawn until slice 2 provides a
  registration helper that can express it.
```

It contradicts `cmake/ByteMachineTesting.cmake`, which never removed the entry. This slice resolves it in favour of the code.

- [ ] **Step 2: Add the slice 2 entry**

Under **Added** in `CHANGELOG.md`:

```markdown
- A dependency-free portable test harness: one shared runner body included by a
  thin `(byte-machine test harness)` library per runtime, with adapters that
  export identical names and contain no test semantics of their own. Assertions,
  groups and cases, an isolated self-probe, and a computed exit status.
- Source execution lanes for both runtimes. Chez runs through a launcher that
  pairs the library root with an always-empty object directory, so a stale
  compiled object cannot be loaded by a lane that calls itself source. Gambit
  gains a `source` mode: both of its compiled modes shell out to a C compiler
  fixed when Gambit was built, which would have made the first slice that runs
  Scheme unable to run on Gambit at all without that toolchain.
- Exact-exit-status assertions. The harness gives 0, 1, and 2 distinct meanings,
  and an expectation outside the declared vocabulary is a configure error. A
  status outside it that is *observed* is reported as its own failure rather
  than as a wrong assertion outcome, since it means the process died before the
  harness could report.
- Mutation testing extended to the Scheme harness. Each decision in the runner
  is broken on a staged copy and the self-tests must notice. Adapter export
  parity is checked the same way, on each runtime, because Scheme cannot
  portably reflect on a library's export list.
- A portability guard failing the build when a shared test body is missing a
  wrapper, when two shared bodies share a basename, or when its own glob matches
  nothing.

### Changed

- `MutationRunner` takes the staged trees and the verify command as parameters,
  so a mutation can be judged by running a real execution lane rather than only
  by `cmake -P`. The CMake-layer suite keeps its previous behaviour by default.
```

- [ ] **Step 3: Note the new entry points in the README**

In `README.org`, after the existing `make dev` description, add:

```org
Note that =make dev= now launches real Chez and Gambit processes; it is no
longer a CMake-only target. To work on the build layer with no Scheme
installed, use the =no-scheme= preset:

#+begin_src bash
cmake --preset no-scheme && ctest --preset no-scheme
#+end_src
```

- [ ] **Step 4: Full verification**

```bash
make clean && make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS. `make test` runs the full pull-request selection; the `no-scheme` run proves the build layer is still testable without a runtime.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md README.org
git commit -m "docs: record the slice 2 harness and correct the expected-red note"
```

---

## Verification summary

After Task 10 the following must all hold. Any that does not is unfinished work, not a caveat.

| Claim | Command |
| --- | --- |
| A failing assertion exits 1 on both runtimes | `ctest --preset harness -R failing-body` |
| A passing suite exits 0 on both runtimes | `ctest --preset harness -R "harness.self"` |
| A duplicate case id and an empty selection each exit 2 on both | `ctest --preset harness -R "duplicate-case\|empty-selection"` |
| The bootstrap judges the runner without using it | `ctest --preset harness -R bootstrap` |
| Every runner decision is caught by the self-tests, or declared surviving | `ctest --preset harness -R scheme-mutation` |
| Dropping an adapter export fails the self-tests, per runtime | included in the run above |
| The guard fails on a missing wrapper, a repeated basename, and an empty glob | Task 9 step 6 |
| The build layer is still testable with no Scheme installed | `cmake --preset no-scheme && ctest --preset no-scheme` |
| The whole selection is green | `make test` |
