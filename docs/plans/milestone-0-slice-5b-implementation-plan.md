# Milestone 0 Slice 5b: Chez AOT and artifact binding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Chez ahead-of-time execution lane, and make a compiled lane's content fingerprint describe the text its artifact was built from rather than the text on disk when it ran.

**Architecture:** `byte_machine_scheme_lane_command` becomes mode-aware and returns a second output — the paths the run measures — alongside the command. Source lanes return their declared bodies unchanged; the `chez.aot` lane returns copies written beside its object by the same build step that compiled it. Two new Chez launchers compile a program with its libraries into per-lane object directories and then run it with `source-directories` empty, so the lane cannot expand any library source. Everything that decides a path stays in the functional core and is specified under `cmake -P`; only `add_custom_command` lives in the shell.

**Tech Stack:** CMake 3.26, CTest, Chez Scheme 10.4.1 (`compile-program` / `load-program`), the project's own `cmake -P` specification and mutation harnesses.

**Design:** [`milestone-0-slice-5b-5c-compiled-lanes.md`](./milestone-0-slice-5b-5c-compiled-lanes.md). Decision labels `W1`–`W12` and mutation labels `C1`–`C9` below refer to that document.

## Global Constraints

- CMake floor is **3.26**. `cmake_parse_arguments` unsets a one-value keyword given `""`; CMP0174 is 3.31+ and may not be relied on.
- Chez floor is **10.4.1**; the machine type must be threaded. Discovery owns both checks — no launcher re-checks them (`chez-source.ss` records why).
- Exit-status vocabulary is exactly **0, 1, 2, 3**. 0 pass, 1 assertion failure, 2 harness/configuration/registration error, 3 provenance failure. An expectation outside it is a configure error.
- Every launcher diagnostic is prefixed `byte-machine-launcher: HARNESS-ERROR ` and exits **2**.
- Baseline on this branch's merge-base is **46/46** for `make test` (preset `pr`), **10/10** for `no-scheme`, **97** CMake mutations, **83** Scheme mutations across **35** passes. Measured 2026-08-17; every count below is derived from it.
- The `no-scheme` preset must stay green and must stay at **10/10**. Nothing added to the functional core may require a Scheme runtime to specify.
- Shared-body basenames are unique repository-wide (`byte_machine_guard_duplicate_basenames`). W5's flat `fingerprint/` directory depends on this; do not weaken it.
- The `|` separator is used for environment-borne path lists — never `:` or `;`.
- Conventional Commits. Run the suite before every commit.
- No new dependencies. No SRFI-64, no package manager.

---

## File Structure

**Created**

| Path | Responsibility |
| --- | --- |
| `test/support/launchers/chez-compile.ss` | Compile one program and its imported libraries into per-lane object directories. Nothing else. |
| `test/support/launchers/chez-aot.ss` | Run a compiled program with the object directories as the only library path and `source-directories` empty. |
| `test/fixtures/stale-body/harness-runner.scm` | A deliberately divergent copy of one manifest body, used only to build the staleness lane's artifact. |

**Modified**

| Path | Change |
| --- | --- |
| `cmake/ByteMachineSchemeLane.cmake` | Mode-aware command construction; the measured-paths output; the `chez.aot` command and artifact functions. |
| `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` | Specifications for every decision above. |
| `test/CMakeLists.txt` | Object-root paths; three `chez.aot` registrations; the staleness lane. |
| `test/support/harness/self/harness-self-tests.scm` | The mode assertion generalises (W8). |
| `test/support/harness/self/harness-bootstrap.scm` | Same assertion, bootstrap form. |
| `test/support/cmake/MutationSuite.cmake` | Mutations C1, C2, C4, plus W9's carried items. |
| `docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md` | §5.3's measured answer (Task 5). |
| `docs/decisions/0004-content-fingerprint-and-provenance.md` | The W2/W3 amendment. |
| `CHANGELOG.md` | The slice entry. |

---

### Task 1: The execution mode comes from the lane's name

Today `byte_machine_add_scheme_lane` emits the literal `BYTE_MACHINE_EXECUTION_MODE=source`, so a lane named `.chez.aot` would declare itself a source lane. The name already carries the mode and `byte_machine_test_name_parse` already returns it (design M3).

**Considered and cut (YAGNI), with the cost stated in full.** `BACKEND` and the name's backend stay independent, with no guard requiring them to agree.

The common case is not silent: a lane named `.gambit.source` registered with `BACKEND chez` points at a `.gambit.scm` program Chez cannot load, so it fails loudly the first time it runs. A configure-time refusal for a loud run-time failure is ceremony, and it costs a check, a specification rejection case, and a mutation.

Deriving the mode from the name adds a second consequence that the loudness argument does **not** cover, found in this task's review and recorded rather than glossed: `NAME ...gambit.o1 BACKEND chez` now emits `BYTE_MACHINE_EXECUTION_MODE=o1` on a Chez run, and it passes `byte_machine_test_name_parse`, because `o1` is a valid mode for the `gambit` backend. That registration mislabels its evidence quietly. It is still judged not worth a guard — the same registration also names a Gambit program Chez cannot load, so it fails on its first run for the other reason — but the reasoning now covers the whole case rather than half of it.

Reopen if a program ever becomes loadable by both runtimes, which is the condition under which both halves of this argument stop holding at once.

**Files:**
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `test/support/cmake/MutationSuite.cmake` (re-anchor one existing mutation — see Interfaces)
- Modify: `test/support/harness/self/harness-self-tests.scm:365-366`
- Modify: `test/support/harness/self/harness-bootstrap.scm:119-120`

**Interfaces:**
- Produces: `byte_machine_add_scheme_lane` emits `BYTE_MACHINE_EXECUTION_MODE=<mode>` where `<mode>` is the fifth dot-separated field of `NAME`.
- Also modifies: `test/support/cmake/MutationSuite.cmake`. An existing mutation anchors on the literal `"BYTE_MACHINE_EXECUTION_MODE=source"`; replacing that literal stops its pattern matching, and the suite's own site check fails. Re-anchor it on `${lane_mode}`, keeping `LABEL` and `REPLACE` unchanged — the precedent for this is in the same file, and the rule is that a pattern which stops matching after a refactor is updated, never deleted.

- [ ] **Step 1: Write the failing specification cases**

Append to `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, immediately after the existing plain-registration environment assertion:

```cmake
# --- The mode is the name's, not a literal ---------------------------------
#
# A lane that declares a mode it is not running is the defect this whole slice
# exists to prevent, and the declaration is what every other lane's evidence
# is labelled with. Asserted over a name that is not `source`, because the
# literal it replaced was `source`: a mutation restoring the literal passes
# every assertion written over a source lane.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.aot
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
list(GET environment 0 mode_entry)
spec_check_equal("${mode_entry}" "BYTE_MACHINE_EXECUTION_MODE=aot"
  "an aot lane declares the aot mode, read from its own name")

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example.chez.source
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  TIMEOUT 10)
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
list(GET environment 0 mode_entry)
spec_check_equal("${mode_entry}" "BYTE_MACHINE_EXECUTION_MODE=source"
  "a source lane still declares source")
```

- [ ] **Step 2: Run the specification and watch it fail**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL, naming `an aot lane declares the aot mode, read from its own name` — the emitted entry is still `BYTE_MACHINE_EXECUTION_MODE=source`.

- [ ] **Step 3: Derive the mode from the name**

In `cmake/ByteMachineSchemeLane.cmake`, inside `byte_machine_add_scheme_lane`, immediately after the `SHARED_BODIES` existence loop and before the call to `byte_machine_scheme_lane_command`:

```cmake
  # The name is the single source of the mode, so a registration cannot claim
  # one lane while running another. byte_machine_add_test parses the same name
  # again for its labels; the function is pure, so parsing it twice is cheaper
  # than passing a parsed field through a registrar that does not need it.
  byte_machine_test_name_parse("${arg_NAME}" lane_layer lane_feature
                               lane_backend lane_mode)
```

Then change the environment's first entry from the literal:

```cmake
  set(environment
    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"
    "BYTE_MACHINE_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin")
```

- [ ] **Step 4: Run the specification and watch it pass**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: PASS, with the case count risen by two.

- [ ] **Step 5: Generalise the two harness assertions (W8)**

`test/support/harness/self/harness-self-tests.scm`, replacing lines 365–366:

```scheme
        ;; The vocabulary, not a fixed mode. Slice 5b gives this body more than
        ;; one lane to run under, so an equality against any single mode would
        ;; be false on some lane that is behaving correctly. The narrower claim
        ;; -- that this lane really is the mode it declares -- is not made here
        ;; and cannot be: the value would be compared against itself. It is
        ;; carried by the lane's structure (an aot lane cannot expand source)
        ;; and proved by mutation C4 against the registration's own mapping.
        (check "the mode is one the lane vocabulary defines"
               (harness-member? (adapter-execution-mode)
                                (list "source" "aot" "o1")))))
```

`test/support/harness/self/harness-bootstrap.scm`, replacing lines 119–120:

```scheme
(bootstrap-assert "adapter: execution mode is one the lane vocabulary defines"
                  (harness-member? (adapter-execution-mode)
                                   (list "source" "aot" "o1")))
```

- [ ] **Step 6: Run the whole suite**

```bash
make test
```

Expected: PASS, 46/46, unchanged. Then:

```bash
cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, 10/10.

- [ ] **Step 7: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/support/harness/self/harness-self-tests.scm test/support/harness/self/harness-bootstrap.scm
git commit -m "feat: a lane's declared mode comes from its own name"
```

---

### Task 2: The two-list split, in the functional core

`byte_machine_scheme_lane_command` learns the mode and gains an output: the paths the run measures. This task changes no lane's behaviour — every existing lane is a source lane, whose measured list is its declared list — and exists so that Task 4 has somewhere to put a different answer.

**Files:**
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`

**Interfaces:**
- Consumes: `lane_mode` from Task 1.
- Produces:
  ```
  byte_machine_scheme_lane_command(<backend> <mode> <program>
                                   <out_command> <out_measured>
                                   <out_status> <out_message>
                                   <declared-body>...)
  ```
  `out_measured` is a list of the same length and order as `<declared-body>...`. Statuses are unchanged (`ok`, `no-runtime`, `unknown-backend`, `comma-in-path`, `relative-path`) plus `unknown-mode`.

- [ ] **Step 1: Write the failing specification cases**

Append to `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, in the functional-core section beside the existing `byte_machine_scheme_lane_command` assertions:

```cmake
# --- Declared bodies versus measured bodies --------------------------------
#
# A source lane reads the repository sources, so the two lists coincide and
# the distinction is invisible. It is not invisible for a compiled lane, where
# the expectation is computed from the originals and the run must read what
# the artifact was actually built from -- and this is the one place a
# specification can see the rule with no runtime present.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
byte_machine_scheme_lane_command(chez source "/h/self/p.chez.sps"
  command measured status message "/h/shared/a.scm" "/h/shared/b.scm")
spec_check_equal("${status}" "ok" "a chez source lane is accepted")
spec_check_equal("${measured}" "/h/shared/a.scm;/h/shared/b.scm"
  "a source lane measures the bodies it declares, in the declared order")

byte_machine_scheme_lane_command(chez unknown-mode-name "/h/self/p.chez.sps"
  command measured status message "/h/shared/a.scm")
spec_check_equal("${status}" "unknown-mode" "an unregistered mode is rejected")
spec_check_equal("${command}" "" "a rejected lane returns no command")
spec_check_equal("${measured}" "" "a rejected lane measures nothing")
spec_check_equal("${message}"
  "'unknown-mode-name' is not an execution mode this lane module can build a command for. Known modes: source aot."
  "unknown mode message")
```

- [ ] **Step 2: Run the specification and watch it fail**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `byte_machine_scheme_lane_command` currently takes five arguments, so the fifth positional is read as `out_status` and the assertions compare nonsense.

- [ ] **Step 3: Add the mode parameter and the measured output**

In `cmake/ByteMachineSchemeLane.cmake`, change the signature and the two backend branches. The full replacement for the function's header and Chez branch:

```cmake
# byte_machine_scheme_lane_command(<backend> <mode> <program>
#                                  <out_command> <out_measured>
#                                  <out_status> <out_message>
#                                  <declared-body>...)
#
# Status is `ok`, `no-runtime`, `unknown-backend`, `unknown-mode` -- or, for
# gambit, one of byte_machine_scheme_lane_gambit_search's own statuses
# (`comma-in-path`, `relative-path`), forwarded unchanged.
#
# <out_measured> is the list of paths the run will fingerprint, in the order
# the declared bodies were given. For a source lane it is the declared list:
# the repository sources are the only text there is. For a compiled lane it is
# the copies the build wrote beside the artifact, so a fingerprint describes
# what the artifact was built from rather than what is on disk now.
#
# Order is load-bearing. harness-fingerprint-combine is order-sensitive by
# design, so measured[i] must correspond to declared[i]; the mapping below
# walks the declared list rather than partitioning and rejoining it.
function(byte_machine_scheme_lane_command backend mode program
         out_command out_measured out_status out_message)
  set(${out_command} "" PARENT_SCOPE)
  set(${out_measured} "" PARENT_SCOPE)
  set(${out_message} "" PARENT_SCOPE)

  if(backend STREQUAL "chez")
    if(NOT BYTE_MACHINE_CHEZ_EXECUTABLE)
      set(${out_status} "no-runtime" PARENT_SCOPE)
      set(${out_message}
        "no Chez was discovered, so the chez ${mode} lane for '${program}' is not registered."
        PARENT_SCOPE)
      return()
    endif()

    if(mode STREQUAL "source")
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
      set(${out_measured} ${ARGN} PARENT_SCOPE)
      set(${out_status} "ok" PARENT_SCOPE)
      return()
    endif()

    if(mode STREQUAL "aot")
      byte_machine_chez_aot_paths("${program}" object_dir compiled)
      set(${out_command}
        "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
        "--script" "${BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER}"
        "--object-dir" "${object_dir}/harness"
        "--object-dir" "${object_dir}/src"
        "--program" "${compiled}"
        PARENT_SCOPE)
      byte_machine_lane_measured_copies("${object_dir}/fingerprint" measured ${ARGN})
      set(${out_measured} ${measured} PARENT_SCOPE)
      set(${out_status} "ok" PARENT_SCOPE)
      return()
    endif()

    set(${out_status} "unknown-mode" PARENT_SCOPE)
    set(${out_message}
      "'${mode}' is not an execution mode this lane module can build a command for. Known modes: source aot."
      PARENT_SCOPE)
    return()
  endif()
```

The Gambit branch keeps its body unchanged except for setting the measured output beside the command, and rejecting any mode but `source`:

```cmake
  if(backend STREQUAL "gambit")
    if(NOT BYTE_MACHINE_GAMBIT_EXECUTABLE)
      set(${out_status} "no-runtime" PARENT_SCOPE)
      set(${out_message}
        "no Gambit was discovered, so the gambit ${mode} lane for '${program}' is not registered."
        PARENT_SCOPE)
      return()
    endif()
    if(NOT mode STREQUAL "source")
      set(${out_status} "unknown-mode" PARENT_SCOPE)
      set(${out_message}
        "'${mode}' is not an execution mode this lane module can build a command for. Known modes: source aot."
        PARENT_SCOPE)
      return()
    endif()

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
    set(${out_measured} ${ARGN} PARENT_SCOPE)
    set(${out_status} "ok" PARENT_SCOPE)
    return()
  endif()
```

Add the two pure helpers above it:

```cmake
# byte_machine_lane_measured_copies(<dir> <out_var> <declared-body>...)
#
# Map each declared body to the copy a compiled lane's build step wrote into
# <dir>. Flat and keyed by basename, which is unambiguous because
# byte_machine_guard_duplicate_basenames forbids two shared bodies sharing one
# repository-wide. One rule for every compiled lane: protium needs per-lane
# path logic here precisely because it has no equivalent guard.
function(byte_machine_lane_measured_copies dir out_var)
  set(copies "")
  foreach(body IN LISTS ARGN)
    get_filename_component(name "${body}" NAME)
    list(APPEND copies "${dir}/${name}")
  endforeach()
  set(${out_var} "${copies}" PARENT_SCOPE)
endfunction()

# byte_machine_chez_aot_paths(<program> <out_object_dir> <out_compiled>)
#
# Where one AOT lane's artifacts live. Keyed by Chez version and machine type
# so a parallel build cannot race and no object outlives the runtime that
# produced it, and by program stem so two lanes over one program share nothing.
function(byte_machine_chez_aot_paths program out_object_dir out_compiled)
  get_filename_component(stem "${program}" NAME_WE)
  set(dir "${BYTE_MACHINE_CHEZ_OBJECT_ROOT}/${stem}")
  set(${out_object_dir} "${dir}" PARENT_SCOPE)
  set(${out_compiled} "${dir}/${stem}.so" PARENT_SCOPE)
endfunction()
```

Update the one call site in `byte_machine_add_scheme_lane`:

```cmake
  byte_machine_scheme_lane_command(
    "${arg_BACKEND}" "${lane_mode}" "${arg_PROGRAM}"
    command measured status message ${arg_SHARED_BODIES})

  if(status STREQUAL "unknown-backend"
     OR status STREQUAL "unknown-mode"
     OR status STREQUAL "comma-in-path"
     OR status STREQUAL "relative-path")
    message(FATAL_ERROR "byte-machine: ${message}")
  endif()
```

and make the manifest block read the measured list:

```cmake
    string(JOIN "|" fingerprint_files ${measured})
```

Leave `byte_machine_expected_fingerprint`'s argument as `${arg_SHARED_BODIES}`. That asymmetry is the mechanism: the expectation comes from the originals, the measurement from what the artifact was built from.

Define the object root beside the other lane paths in `test/CMakeLists.txt`:

```cmake
# Per-runtime, per-machine object roots for the AOT lane. Keyed this way so a
# parallel build cannot race and an object built by one Chez is never loaded by
# another; nothing is written into the source tree.
set(BYTE_MACHINE_CHEZ_OBJECT_ROOT
    "${CMAKE_BINARY_DIR}/chez-objects/${BYTE_MACHINE_CHEZ_VERSION}/${BYTE_MACHINE_CHEZ_MACHINE_TYPE}")
set(BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-aot.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-compile.ss")
```

Seed the same three in the specification, near the other fixture paths, so the functional core is reachable with no project context:

```cmake
set(BYTE_MACHINE_CHEZ_OBJECT_ROOT "/objects")
set(BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER "/launchers/chez-aot.ss")
set(BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER "/launchers/chez-compile.ss")
```

- [ ] **Step 4: Update every existing call site's expectations in the specification**

Every prior `byte_machine_scheme_lane_command(...)` call in the specification gains `source` as its second argument and `measured` as its fifth. For example the existing unknown-backend case becomes:

```cmake
byte_machine_scheme_lane_command(guile source "/h/self/p.scm"
  command measured status message)
spec_check_equal("${status}" "unknown-backend" "an unknown backend is rejected")
```

- [ ] **Step 5: Run the specification and watch it pass**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: PASS.

- [ ] **Step 6: Run the whole suite and the no-scheme preset**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, 46/46 and 10/10. No lane's behaviour has changed: every registration is still a source lane and every measured list is still its declared list.

- [ ] **Step 7: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/CMakeLists.txt
git commit -m "feat: a lane says what it measures, not only what it declares"
```

---

### Task 3: The compile and AOT launchers

Two programs, in the flag style `chez-source.ss` established. Neither is reachable from any lane until Task 4, so this task's proof is that each refuses what it should.

**Files:**
- Create: `test/support/launchers/chez-compile.ss`
- Create: `test/support/launchers/chez-aot.ss`
- Modify: `test/CMakeLists.txt` (three refusal lanes)

**Interfaces:**
- Produces:
  - `chez-compile.ss --library-root <dir> … --source-dir <dir> … --object-dir <dir> … --program <path> --output <path>`, where the *n*th `--object-dir` pairs with the *n*th `--library-root`.
  - `chez-aot.ss --object-dir <dir> … --program <compiled>`.
  - Both exit 2 with `byte-machine-launcher: HARNESS-ERROR ` on any refusal.

- [ ] **Step 1: Write `test/support/launchers/chez-compile.ss`**

```scheme
;;; Chez ahead-of-time compilation step.
;;;
;;; Usage:
;;;   chez-compile.ss --library-root <dir> [--library-root <dir> ...]
;;;                   --object-dir <dir>   [--object-dir <dir> ...]
;;;                   --source-dir <dir>   [--source-dir <dir> ...]
;;;                   --program <path> --output <path>
;;;
;;; The nth --object-dir pairs with the nth --library-root. The pairing is
;;; positional because library-directories is a list of pairs and there is no
;;; flag spelling of a pair; the counts are asserted equal below, because a
;;; silent mismatch would compile some libraries into a directory the AOT
;;; launcher never puts on its library path, and that lane would then fail at
;;; run time with an unbound library rather than here with a sentence.
;;;
;;; WHY THE FLAG BLOCK BELOW IS A THIRD COPY
;;;
;;; known-flags, required-flags, single-valued-flags and the three loops under
;;; them are the same code chez-source.ss carries. The duplication is
;;; deliberate and it is not a candidate for extraction. A Chez --script
;;; program runs standalone with no library path and no source-directories, so
;;; the only way to share this block is to `load` it from an absolute path --
;;; and that path would have to arrive as a command-line argument, read before
;;; the code that reads command-line arguments exists. The bootstrap argument
;;; that buys costs every launcher and every call site a positional they must
;;; agree on, whose failure mode is a `load` of the wrong file rather than a
;;; named refusal.
;;;
;;; The cost of the copy is that a flag-vocabulary decision fixed in one
;;; launcher is not fixed in the others. Each copy is mutated separately for
;;; that reason: the copies are independent decisions, not one decision spelled
;;; three times.
;;;
;;; WHY compile-imported-libraries IS ON HERE AND OFF THERE
;;;
;;; This step exists to produce the objects; the run must never produce one.
;;; A run that compiled would be doing at run time what this step claims to
;;; have done at build time, and the lane would pass having proved nothing
;;; about the artifact.

(define (path-directory path)
  (let loop ((i (- (string-length path) 1)))
    (cond ((< i 0) ".")
          ((or (char=? (string-ref path i) #\/)
               (char=? (string-ref path i) #\\))
           (substring path 0 i))
          (else (loop (- i 1))))))

(define (die message)
  (display "byte-machine-launcher: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define known-flags
  (list "--library-root" "--object-dir" "--source-dir" "--program" "--output"))

;; One per line, in a different order from known-flags, so each entry is unique
;; text that a mutation can remove on its own.
(define required-flags
  (list "--output"
        "--program"
        "--object-dir"
        "--library-root"
        "--source-dir"))

(define single-valued-flags
  (list "--program" "--output"))

(define args (command-line-arguments))

(let loop ((rest args))
  (cond ((null? rest) #t)
        ((not (member (car rest) known-flags))
         (die (string-append "unknown flag: " (car rest))))
        ((null? (cdr rest))
         (die (string-append "flag has no value: " (car rest))))
        (else (loop (cddr rest)))))

(define (flag-values flag)
  (let loop ((rest args) (found (list)))
    (cond ((null? rest) (reverse found))
          ((string=? (car rest) flag) (loop (cddr rest) (cons (cadr rest) found)))
          (else (loop (cddr rest) found)))))

(for-each
 (lambda (flag)
   (if (null? (flag-values flag))
       (die (string-append "missing required flag: " flag))))
 required-flags)

(for-each
 (lambda (flag)
   (if (> (length (flag-values flag)) 1)
       (die (string-append "flag given more than once: " flag))))
 single-valued-flags)

(define library-roots (flag-values "--library-root"))
(define object-dirs (flag-values "--object-dir"))
(define source-dirs (flag-values "--source-dir"))
(define program (car (flag-values "--program")))
(define output (car (flag-values "--output")))

(if (not (= (length library-roots) (length object-dirs)))
    (die (string-append "each --library-root needs one --object-dir, but there are "
                        (number->string (length library-roots))
                        " roots and "
                        (number->string (length object-dirs))
                        " object directories")))

(compile-imported-libraries #t)
(generate-wpo-files #f)

(source-directories (append source-dirs (list (path-directory program))))
(library-directories (map cons library-roots object-dirs))

(compile-program program output)

(display "byte-machine-launcher: compiled ")
(display output)
(newline)
(flush-output-port (current-output-port))
(exit 0)
```

- [ ] **Step 2: Write `test/support/launchers/chez-aot.ss`**

```scheme
;;; Chez ahead-of-time launcher.
;;;
;;; Usage:
;;;   chez-aot.ss --object-dir <dir> [--object-dir <dir> ...] --program <compiled>
;;;
;;; WHY THE FLAG BLOCK BELOW IS A THIRD COPY
;;;
;;; known-flags, required-flags, single-valued-flags and the three loops under
;;; them are the same code chez-source.ss carries. The duplication is
;;; deliberate and it is not a candidate for extraction. A Chez --script
;;; program runs standalone with no library path and no source-directories, so
;;; the only way to share this block is to `load` it from an absolute path --
;;; and that path would have to arrive as a command-line argument, read before
;;; the code that reads command-line arguments exists. The bootstrap argument
;;; that buys costs every launcher and every call site a positional they must
;;; agree on, whose failure mode is a `load` of the wrong file rather than a
;;; named refusal.
;;;
;;; The cost of the copy is that a flag-vocabulary decision fixed in one
;;; launcher is not fixed in the others. Each copy is mutated separately for
;;; that reason: the copies are independent decisions, not one decision spelled
;;; three times.
;;;
;;; WHY source-directories IS EMPTIED
;;;
;;; This is the whole of the lane's honesty, and it is the AOT counterpart of
;;; the source lane's object guard. Only the object directories go on the
;;; library path and none of them holds Scheme source, so this process cannot
;;; expand a library: either the compiled objects are used or the run fails.
;;; Protium records that Chez otherwise treats an object whose recorded include
;;; dependencies cannot be located as out of date and quietly loads the source
;;; instead -- which would make this a second source lane reporting `mode=aot`.
;;; That claim has not been reproduced in this repository; see section 5.3 of
;;; the slice design and whatever task 5 recorded there.
;;;
;;; No object guard is needed and none is taken: this lane's library path is
;;; object directories, so there is no source half of a pair for an object to
;;; be preferred over.

(define (die message)
  (display "byte-machine-launcher: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define known-flags (list "--object-dir" "--program"))

;; One per line, in a different order from known-flags, so each entry is unique
;; text that a mutation can remove on its own.
(define required-flags
  (list "--program"
        "--object-dir"))

(define single-valued-flags (list "--program"))

(define args (command-line-arguments))

(let loop ((rest args))
  (cond ((null? rest) #t)
        ((not (member (car rest) known-flags))
         (die (string-append "unknown flag: " (car rest))))
        ((null? (cdr rest))
         (die (string-append "flag has no value: " (car rest))))
        (else (loop (cddr rest)))))

(define (flag-values flag)
  (let loop ((rest args) (found (list)))
    (cond ((null? rest) (reverse found))
          ((string=? (car rest) flag) (loop (cddr rest) (cons (cadr rest) found)))
          (else (loop (cddr rest) found)))))

(for-each
 (lambda (flag)
   (if (null? (flag-values flag))
       (die (string-append "missing required flag: " flag))))
 required-flags)

(for-each
 (lambda (flag)
   (if (> (length (flag-values flag)) 1)
       (die (string-append "flag given more than once: " flag))))
 single-valued-flags)

(define object-dirs (flag-values "--object-dir"))
(define program (car (flag-values "--program")))

;; Asserted, not assumed. Without the object this lane cannot run at all, and
;; the failure Chez gives for a missing program file says nothing about which
;; build step should have produced it.
(if (not (file-exists? program))
    (die (string-append "compiled program does not exist: " program)))

(compile-imported-libraries #f)
(source-directories '())
(library-directories object-dirs)

(load-program program)
```

- [ ] **Step 3: Register one refusal lane per launcher decision**

In `test/CMakeLists.txt`, beside the existing Chez launcher refusal lanes:

```cmake
# A lane that is set up correctly never reaches a launcher refusal, so each one
# needs a lane of its own or a deleted refusal is invisible. The same argument
# the three chez-source.ss refusals above are registered under.
#
# Two lanes, not one per refusal in these files. The flag-vocabulary refusals
# below the parser are the same code chez-source.ss already carries and whose
# identical refusals already have lanes; re-proving a verbatim copy buys
# nothing. These two are the decisions that are new here.
byte_machine_add_exit_code_test(
  NAME byte-machine.harness.chez-aot-launcher-missing-program.cmake.direct
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER}"
          --object-dir "${CMAKE_BINARY_DIR}"
          --program "${CMAKE_BINARY_DIR}/no-such-program.so"
  EXPECT_EXIT 2
  TIMEOUT 60
  LABELS expected-red)

byte_machine_add_exit_code_test(
  NAME byte-machine.harness.chez-compile-launcher-unpaired-roots.cmake.direct
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
          --library-root "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
          --library-root "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
          --object-dir "${CMAKE_BINARY_DIR}"
          --source-dir "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
          --program "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
          --output "${CMAKE_BINARY_DIR}/unused.so"
  EXPECT_EXIT 2
  TIMEOUT 60
  LABELS expected-red)
```

Guard the block on a discovered Chez, matching how the existing launcher refusals are gated.

- [ ] **Step 4: Run the three refusal lanes**

```bash
make build && ctest --preset pr -R 'chez-(aot|compile)-launcher' -V
```

Expected: PASS, 2/2, each showing `byte-machine-launcher: HARNESS-ERROR` on stderr — respectively `compiled program does not exist:` and `each --library-root needs one --object-dir, but there are 2 roots and 1 object directories`.

- [ ] **Step 5: Run the whole suite**

```bash
make test
```

Expected: PASS, 48/48.

- [ ] **Step 6: Commit**

```bash
git add test/support/launchers/chez-compile.ss test/support/launchers/chez-aot.ss test/CMakeLists.txt
git commit -m "feat: a Chez compile step, and a launcher that cannot expand source"
```

---

### Task 4: The `chez.aot` lane

The shell half: the custom command that compiles the program and, in the same command, writes the copies the run will measure.

**Files:**
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `byte_machine_chez_aot_paths(<lane-name> <program> <out_object_dir> <out_compiled>)` and `byte_machine_lane_measured_copies` (Task 2); both launchers (Task 3).

**Read this before writing the artifact function.** Object directories are keyed on the **lane name**, not the program stem. That is not incidental: this slice registers two `chez.aot` lanes over the *same* program — `byte-machine.harness.self.chez.aot` here, and `byte-machine.harness.stale-artifact.chez.aot` in Task 6, whose whole purpose is to compile that same program from divergent text. Under program-stem keying they share one object directory, one `.so`, and one flat `fingerprint/` directory, so the stale lane's copies overwrite the real lane's and both lanes compile from whichever text won the race. Task 2's review caught this before Task 4 was written; the per-lane key is what makes the pair possible.
- Produces: `byte_machine_lane_chez_aot_artifacts(<name> <program> <declared-body>...)`, which creates the compile rule and hangs it off the `byte_machine_chez_aot` aggregate target.

- [ ] **Step 1: Write the artifact function**

Append to `cmake/ByteMachineSchemeLane.cmake`, in the imperative-shell section:

```cmake
# byte_machine_lane_chez_aot_artifacts(<name> <program> <declared-body>...)
#
# Build one AOT lane's object and, in the SAME custom command, the copies of
# the bodies it was built from. One command is the whole of decision W6: the
# object and the copies then have one producer and cannot be separately stale,
# which is what makes the copies evidence about the artifact rather than a
# second reading of the source tree.
#
# The DEPENDS list is the other half. Chez decides an object is current by
# comparing timestamps against the wrapper alone, and a body reached only
# through `include` has no timestamp anything consults -- so nothing but this
# list will notice a body changing after the object was built.
function(byte_machine_lane_chez_aot_artifacts name program)
  byte_machine_chez_aot_paths("${name}" "${program}" object_dir compiled)
  byte_machine_lane_measured_copies("${object_dir}/fingerprint" copies ${ARGN})

  set(copy_commands "")
  list(LENGTH ARGN body_count)
  math(EXPR last "${body_count} - 1")
  foreach(i RANGE 0 ${last})
    if(i GREATER_EQUAL 0 AND i LESS body_count)
      list(GET ARGN ${i} body)
      list(GET copies ${i} copy)
      list(APPEND copy_commands
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${body}" "${copy}")
    endif()
  endforeach()

  file(GLOB_RECURSE chez_library_sources
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/*.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/*.sls")
  if(NOT chez_library_sources)
    message(FATAL_ERROR
      "byte-machine: no Chez library sources were found under "
      "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT} or "
      "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}. That means this glob is wrong, "
      "not that the AOT lane has nothing to depend on -- and a lane with no "
      "library dependency goes on passing against the previous text.")
  endif()

  add_custom_command(
    OUTPUT "${compiled}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${object_dir}/harness"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${object_dir}/src"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${object_dir}/fingerprint"
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
            "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            --library-root "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            --library-root "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
            --object-dir "${object_dir}/harness"
            --object-dir "${object_dir}/src"
            --source-dir "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            --source-dir "${BYTE_MACHINE_SRC_COMMON_DIR}"
            --program "${program}"
            --output "${compiled}"
    ${copy_commands}
    DEPENDS "${program}"
            "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            ${chez_library_sources}
            ${ARGN}
    COMMENT "byte-machine: Chez AOT compile for ${name}"
    VERBATIM)

  string(REPLACE "." "_" stem "${name}")
  add_custom_target("byte_machine_chez_aot_${stem}" DEPENDS "${compiled}")
  if(NOT TARGET byte_machine_chez_aot)
    add_custom_target(byte_machine_chez_aot ALL)
  endif()
  add_dependencies(byte_machine_chez_aot "byte_machine_chez_aot_${stem}")
endfunction()
```

Call it from `byte_machine_add_scheme_lane`, after the command has been built and before the registration:

```cmake
  # The shell half of the aot lane. Guarded on the mode rather than on the
  # backend, so adding a mode does not silently acquire this rule.
  if(arg_BACKEND STREQUAL "chez" AND lane_mode STREQUAL "aot")
    byte_machine_lane_chez_aot_artifacts(
      "${arg_NAME}" "${arg_PROGRAM}" ${arg_SHARED_BODIES})
  endif()
```

- [ ] **Step 2: Register the three lanes**

In `test/CMakeLists.txt`, after the existing `chez.source` harness lanes:

```cmake
# --- Chez ahead-of-time lanes ----------------------------------------------
#
# The same three programs the source lanes run, compiled. Nothing about the
# bodies changes; what changes is that the text reaching the process came out
# of an object built earlier, which is why these lanes measure the copies the
# compile step kept rather than the repository sources.
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.scm"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  TIMEOUT 120)

# Slice 4 section 10 deferred cross-library identity under compiled lanes to
# here. Separate instantiation is a modelled risk in source mode and a real one
# once each library is compiled into its own object.
byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder-identity.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
                "${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder-consumer.scm"
                "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.scm"
  TIMEOUT 120)
```

- [ ] **Step 3: Build and run the three new lanes**

```bash
make build && ctest --preset pr -R '\.chez\.aot$' -V
```

Expected: PASS, 3/3. Each prints `mode=aot` on its summary line and `fingerprint verified against the build manifest`.

- [ ] **Step 4: Check the two lanes agree on the value, not merely that both pass**

```bash
ctest --preset pr -R 'harness\.self\.chez\.(source|aot)$' -V | grep -i fingerprint
```

Expected: both lanes report the same combined fingerprint string. Record that value in the commit message — it is the first cross-mode agreement this repository has produced.

- [ ] **Step 5: Run the whole suite**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, 51/51 and 10/10.

- [ ] **Step 6: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake test/CMakeLists.txt
git commit -m "feat: a Chez ahead-of-time lane over the same three programs"
```

---

### Task 5: DISCHARGED — the measurement was taken during Task 3's review

**This task requires no work. Do not dispatch an implementer for it.**

Task 5 existed to answer one question: can a mutation deleting `(source-directories '())` from
`chez-aot.ss` be witnessed? Task 3's review answered it against a real Chez 10.4.1 before this task
came up, and its fix wave then changed the code the question was about. Both results are recorded in
§5.3 of the design.

The answer, in short:

- **`(source-directories '())` is inert.** Outcomes are byte-identical with it and with Chez's
  default, because library resolution runs through `library-directories` and a library's own
  `include` forms resolve relative to the library file. Deleting it is a declared survivor — C3b —
  for a reason that is now understood rather than guessed at.
- **The real defect was elsewhere, and is fixed.** `library-directories` was being handed bare
  strings, which Chez expands into both halves of a `(source . object)` pair, so every object
  directory was also a source directory. Each is now paired with an always-empty source guard, the
  inverse of the source lane's object guard. C3 targets unpairing that guard, which is witnessable
  and was demonstrated: a mutated source planted in an object directory is read under the old shape
  and never read under the new one.

Task 7 carries both mutations in their settled form. Proceed to Task 6.

---

### Task 6: The staleness lane

The lane that makes claim 2 falsifiable: an artifact built from text its registration does not declare.

**Files:**
- Create: `test/fixtures/stale-body/harness-runner.scm`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/CMakeLists.txt`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`

**Interfaces:**
- Consumes: `byte_machine_lane_chez_aot_artifacts` from Task 4. **This task changes its signature** from `(name program)` to `(name program stale_source_dir)`, with the bodies still arriving as `${ARGN}`; its one call site changes with it.
- Produces: a `STALE_SOURCE_DIR <dir>` option on `byte_machine_add_scheme_lane`. When given, the compile step's `--source-dir` list is prefixed with `<dir>`, so a body of the same basename found there is compiled in place of the declared one. The declared list, and therefore the expectation, is untouched.

- [ ] **Step 1: Create the divergent body**

```bash
mkdir -p test/fixtures/stale-body
```

`test/fixtures/stale-body/harness-runner.scm` is a copy of the real body with one comment appended. Produce it mechanically so it can never drift into a second implementation:

```bash
cp test/support/harness/shared/harness-runner.scm test/fixtures/stale-body/harness-runner.scm
cat >> test/fixtures/stale-body/harness-runner.scm <<'BODY'

;; DELIBERATELY NOT THE SHARED BODY OF THE SAME NAME.
;;
;; This copy exists so one lane can compile an artifact from text its own
;; registration does not declare. That lane must exit 3: the expectation is
;; computed from the real body, the run measures the copy the compile step
;; kept, and the two disagree. If it exits 0 instead, a compiled lane's
;; fingerprint has stopped describing its artifact.
;;
;; Regenerate with:
;;   cp test/support/harness/shared/harness-runner.scm \
;;      test/fixtures/stale-body/harness-runner.scm
;;   (then re-append this comment)
BODY
```

- [ ] **Step 2: Write the failing specification case**

Append to `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`:

```cmake
# STALE_SOURCE_DIR changes what is compiled, never what is declared. If it
# reached the declared list the expectation would move with the artifact, the
# two would agree, and the lane that exists to fail would pass.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example-stale.chez.aot
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SHARED_BODIES "${SPEC_SELF}"
  STALE_SOURCE_DIR "/fixtures/stale"
  EXPECT_EXIT 3
  TIMEOUT 10)
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
get_property(fingerprint_function GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION)
spec_check_equal("${fingerprint_function}" "expected"
  "a stale-source lane still computes the real expectation, not a wrong one")
```

- [ ] **Step 3: Run the specification and watch it fail**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `STALE_SOURCE_DIR` is not a known keyword, so it lands in `arg_UNPARSED_ARGUMENTS` and the registration is rejected.

- [ ] **Step 4: Add the option**

In `cmake/ByteMachineSchemeLane.cmake`, add `STALE_SOURCE_DIR` to the one-value keywords:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg "WRONG_FINGERPRINT"
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY;STALE_SOURCE_DIR"
    "LABELS;ENVIRONMENT;SHARED_BODIES")
```

Pass it into the artifact function:

```cmake
  if(arg_BACKEND STREQUAL "chez" AND lane_mode STREQUAL "aot")
    byte_machine_lane_chez_aot_artifacts(
      "${arg_NAME}" "${arg_PROGRAM}" "${arg_STALE_SOURCE_DIR}"
      ${arg_SHARED_BODIES})
  endif()
```

and give that function the parameter, prefixing the compile step's source directories:

```cmake
function(byte_machine_lane_chez_aot_artifacts name program stale_source_dir)
  byte_machine_chez_aot_paths("${name}" "${program}" object_dir compiled)
  byte_machine_lane_measured_copies("${object_dir}/fingerprint" copies ${ARGN})

  # Prefixed, not appended: Chez takes the first match on source-directories,
  # so a body of the same basename here is the one compiled in. Only the
  # staleness lane passes this, and passing it is the only way a lane in this
  # tree can build an artifact from text it does not declare.
  set(compile_source_dirs "")
  if(stale_source_dir)
    list(APPEND compile_source_dirs --source-dir "${stale_source_dir}")
  endif()
  list(APPEND compile_source_dirs
    --source-dir "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
    --source-dir "${BYTE_MACHINE_SRC_COMMON_DIR}")
```

The custom command's two literal `--source-dir` arguments are replaced by that variable, so the compile step reads:

```cmake
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
            "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            --library-root "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            --library-root "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
            --object-dir "${object_dir}/harness"
            --object-dir "${object_dir}/src"
            ${compile_source_dirs}
            --program "${program}"
            --output "${compiled}"
```

and the copy step takes each body from wherever the compile step will have found it, so the measured copy is the compiled text rather than the declared text:

```cmake
  set(copy_commands "")
  list(LENGTH ARGN body_count)
  math(EXPR last "${body_count} - 1")
  foreach(i RANGE 0 ${last})
    if(i GREATER_EQUAL 0 AND i LESS body_count)
      list(GET ARGN ${i} body)
      list(GET copies ${i} copy)
      get_filename_component(body_name "${body}" NAME)
      set(source_of_record "${body}")
      if(stale_source_dir AND EXISTS "${stale_source_dir}/${body_name}")
        set(source_of_record "${stale_source_dir}/${body_name}")
      endif()
      list(APPEND copy_commands
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${source_of_record}" "${copy}")
    endif()
  endforeach()
```

and `${stale_source_dir}` added to the `DEPENDS` list when it is set.

- [ ] **Step 5: Run the specification and watch it pass**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: PASS.

- [ ] **Step 6: Register the lane**

In `test/CMakeLists.txt`, in the provenance section:

```cmake
# An artifact built from text this registration does not declare. The
# expectation comes from the real harness-runner.scm; the compile step is
# pointed at a divergent copy of the same basename and keeps that copy as what
# the run measures. The two disagree, so the lane exits 3.
#
# This is the only lane in the tree that can fail when a compiled lane's
# fingerprint stops describing its artifact -- and it is a lane rather than a
# mutation because the Scheme mutation suite stages one already-mutated tree
# per pass and structurally cannot express "built before the edit, run after
# it" (slice 5a task 6).
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.stale-artifact.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.scm"
  STALE_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/fixtures/stale-body"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)
```

- [ ] **Step 7: Run it**

```bash
make build && ctest --preset pr -R 'stale-artifact' -V
```

Expected: PASS, with the process exiting 3 and printing the provenance mismatch diagnosis naming the fingerprint it computed and the one it expected.

If it exits 0, the mechanism is not working and nothing further in this slice is evidence. Do not proceed past this step until it exits 3.

- [ ] **Step 8: Run the whole suite**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, 52/52 and 10/10.

- [ ] **Step 9: Commit**

```bash
git add test/fixtures/stale-body/harness-runner.scm cmake/ByteMachineSchemeLane.cmake test/CMakeLists.txt test/support/cmake/ByteMachineSchemeLaneSpec.cmake
git commit -m "test: a lane whose artifact was built from text it does not declare"
```

---

### Task 7: The mutations

Every decision this slice added, broken on a staged copy, with the owning specification or lane required to notice.

**Files:**
- Modify: `test/support/cmake/MutationSuite.cmake`

- [ ] **Step 1: Add C1 — the measured list collapses back to the declared list**

```cmake
# C1. Protium's actual behaviour for its Chez AOT lane: fingerprint the
# repository originals. Under it the staleness lane's expectation and its
# measurement read the same files again, they agree, and the lane that exists
# to exit 3 exits 0 -- which is the whole defect decision record 0004 recorded
# and this slice closes.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: a compiled lane measures the repository originals"
  FIND [[      byte_machine_lane_measured_copies("${object_dir}/fingerprint" measured ${ARGN})
      set(${out_measured} ${measured} PARENT_SCOPE)]]
  REPLACE [[      set(${out_measured} ${ARGN} PARENT_SCOPE)]])
```

- [ ] **Step 2: Add C2 — the measured list is reordered**

```cmake
# C2. harness-fingerprint-combine is order-sensitive by design, so a reordered
# measured list computes a different digest over the same bytes. Witnessed by
# any lane whose manifest has two or more bodies, which every real one has: a
# stale artifact is not needed to see this.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: the measured list is built in reverse"
  FIND [[    list(APPEND copies "${dir}/${name}")]]
  REPLACE [[    list(PREPEND copies "${dir}/${name}")]])
```

- [ ] **Step 3: Add C4 — the mode goes back to a literal**

```cmake
# C4. The literal this slice replaced. Distinct from the pre-existing mutation
# anchored on the same line: that one deletes the entry, this one keeps it and
# makes it wrong, which is the defect a compiled lane actually suffers. Not caught by the harness's own
# assertion: under W8 that assertion accepts any mode in the vocabulary, and
# `source` is in the vocabulary -- so a lane declaring it passes. What catches
# it is the registration's name-to-mode mapping, asserted with no runtime
# present, which is why the measured-path and mode logic were kept in the
# functional core rather than in the custom command.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: the execution mode is the literal source again"
  FIND [[    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"]]
  REPLACE [[    "BYTE_MACHINE_EXECUTION_MODE=source"]])
```

- [ ] **Step 4: Add C3 and C3b**

Both are settled — Task 5 records the measurement they come from, taken 2026-08-17 against Chez
10.4.1. Add both.

```cmake
# C3. The source guard is what keeps this lane's library path free of source.
# Chez expands a bare string in library-directories into BOTH halves of a
# (source . object) pair, so handing it object directories alone makes every
# one of them a source directory too -- and Chez will find and expand a .sls,
# .ss, .scm or .sch sitting there. Measured 2026-08-17 against Chez 10.4.1: a
# mutated copy of a library's own source, planted in the object directory, is
# read under this mutation and is not read under the paired shape. The lane
# does not go green either way -- load-program rejects a re-expanded library at
# 255 -- which is exactly why this needs a mutation rather than trust: 255 is
# outside the status vocabulary, so the wrapper reports it as a process that
# died, not as a lane that fell back to source.
byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC harness-self-tests.chez.sps
  LABEL "chez-aot launcher: the source guard is unpaired from the object directories"
  FIND [[(library-directories (map (lambda (dir) (cons source-guard-dir dir)) object-dirs))]]
  REPLACE [[(library-directories object-dirs)]])

# C3b, DECLARED SURVIVOR. Measured inert 2026-08-17 against Chez 10.4.1:
# outcomes are byte-identical with this line and with Chez's default. Library
# resolution runs through library-directories, and a library's own include
# forms resolve relative to the library file rather than through
# source-directories -- verified by compiling a library with an include under
# an empty source-directories, then loading it with the included file's
# directory on no path at all.
#
# Kept rather than deleted: the line still narrows what the process can reach,
# and its inertness is a fact about Chez's resolution order that a future
# reader should find recorded rather than rediscover. Reopening condition: a
# Chez in which a compiled library's includes are re-resolved at load time.
byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC harness-self-tests.chez.sps
  LABEL "chez-aot launcher: source-directories is not emptied"
  FIND [[(source-directories '())]]
  REPLACE [[(source-directories (list "."))]]
  EXPECT_SURVIVES TRUE)
```

Verify C3's FIND text against the shipped `chez-aot.ss` before committing — the fix wave wrote that
line, and this plan quotes it from memory of that wave rather than from the file.

- [ ] **Step 5: Update the suite's asserted totals**

`EXPECTED_MUTATIONS` rises from 97 by the number of mutations actually added in Steps 1–4. Set it to the real number and say in the comment above it what the increment is made of, matching the existing comment's style.

- [ ] **Step 6: Run the CMake mutation suite**

```bash
ctest --preset pr -R 'cmake-mutation' -V
```

Expected: PASS, every mutation caught, and the suite's own totals matching `EXPECTED_MUTATIONS`.

For each mutation, confirm from the output that it was caught by the assertion named in its comment — not merely that something failed. A mutation caught for the wrong reason is a mutation that will stop catching anything the day its real target changes.

- [ ] **Step 7: Run the whole suite**

```bash
make test
```

Expected: PASS, 52/52.

- [ ] **Step 8: Commit**

```bash
git add test/support/cmake/MutationSuite.cmake
git commit -m "test: break every decision this slice added"
```

---

### Task 8: The provenance decisions slice 5a left unmutated

Decision W9, trimmed. Slice 5a's review carried four items forward; this task takes the two that
touch code slice 5b depends on and leaves the rest.

**Cut from this task (YAGNI), and why each is safe to leave:**

- **The `|`-in-a-path and directory-in-`SHARED_BODIES` refusals (carried item 3).** Both guard
  against inputs nobody has written. A directory already fails the build inside
  `fingerprint-manifest.ss`, and a `|` already fails as a manifest member naming no file — less
  prettily, at a layer further from the mistake, but not silently and not green. Two checks, two
  specification cases and two mutations for a nicer message is not a trade this slice should make.
  Reopen if either is ever hit for real.
- **The trimming and rendering mutations** — `harness-whitespace-byte?`, `harness-bytes->string`,
  and `fingerprint->string`'s zero case. Real gaps, and peripheral to anything 5b touches. They are
  reached from the provenance path without being part of it, which is exactly why 5a missed them and
  why deferring them costs 5b nothing.

**What stays, and why it is not YAGNI:** the three `harness-verify-provenance!` and
`harness-provenance-failure!` decisions below are the code path 5b's entire claim rides on. Slice 5b
adds a lane that must exit 3 when an artifact is stale; if the separator, the combining order, or
the failure status are not load-bearing, that lane's 3 means less than it appears to. These are
tested here because 5b depends on them, not because they were on a list.

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`
- Modify: `cmake/ByteMachineSchemeLane.cmake`

- [ ] **Step 1: Correct the signature comment (carried item 4)**

The header comment on `byte_machine_add_scheme_lane` omits `SHARED_BODIES` (required), `WRONG_FINGERPRINT`, and now `STALE_SOURCE_DIR`. Replace it:

```cmake
# byte_machine_add_scheme_lane(NAME <name> BACKEND <chez|gambit> PROGRAM <path>
#                              TIMEOUT <seconds> SHARED_BODIES <path>...
#                              [EXPECT_EXIT <code>] [WRONG_FINGERPRINT]
#                              [STALE_SOURCE_DIR <dir>]
#                              [WORKING_DIRECTORY <dir>]
#                              [LABELS ...] [ENVIRONMENT ...])
#
# NAME, BACKEND, PROGRAM, TIMEOUT and SHARED_BODIES are required. The name's
# fifth field is the execution mode. Its fourth field names a backend too, and
# nothing requires the two to agree: a disagreement points the wrong runtime at
# a program only the other can load, which fails loudly on the first run.
#
# WRONG_FINGERPRINT hands the lane an expectation the run cannot match, and
# STALE_SOURCE_DIR compiles the artifact from bodies of the same basename found
# there. Both exist to make a passing provenance check falsifiable; neither
# belongs on a lane that is meant to pass.
#
# With EXPECT_EXIT the lane is registered through the exact-status helper;
# without it, a nonzero exit fails the test in the ordinary way.
```

One pass, covering the three decisions that are only visible when a manifest of **two or more** bodies reaches the run. Passes 32 and 33 use a one-body manifest and structurally cannot witness either of the first two, which is precisely why the review found them unmutated:

```cmake
# --- The provenance decisions a one-body manifest cannot witness -------------
#
# Each of these is invisible under a single-body manifest: nothing is split on
# a separator that is never reached, nothing is reversed in a list of one, and
# the failure path is not entered at all when the one body agrees. The verify
# command below therefore carries the real two-body harness manifest and the
# expectation computed from it.
function(byte_machine_slice5b_provenance_pass runtime)
  byte_machine_mutation_reset()

  if(runtime STREQUAL "chez")
    set(spec harness-self-tests.chez.sps)
  else()
    set(spec harness-self-tests.gambit.scm)
  endif()

  # The manifest arrives |-joined. Split on anything else and the whole string
  # is one path that names no file, so the run reports a body it cannot read.
  byte_machine_mutation(
    FILE ${RUNNER} SPEC ${spec}
    LABEL "runner on ${runtime}: the manifest is split on the wrong character"
    FIND [[        (let loop ((rest (harness-split raw #\|)) (acc '()))]]
    REPLACE [[        (let loop ((rest (harness-split raw #\,)) (acc '()))]]
    EXPECT_STATUS 3)

  # Combining is order-sensitive, so accumulating in reverse computes a
  # different digest over the same bytes.
  byte_machine_mutation(
    FILE ${RUNNER} SPEC ${spec}
    LABEL "runner on ${runtime}: the manifest digests combine in reverse order"
    FIND [[                               (harness-fingerprint-combine (reverse acc)))))]]
    REPLACE [[                               (harness-fingerprint-combine acc))))]]
    EXPECT_STATUS 3)

  # DECLARED SURVIVOR, for a structural reason rather than a chosen one.
  #
  # A provenance failure exiting 1 would be indistinguishable from an ordinary
  # assertion failure, which is the whole reason status 3 was reserved -- so
  # this decision is worth a mutation. This suite cannot supply one.
  # byte_machine_mutation_run requires the verify command to exit 0 on the
  # staged, unmutated tree, so no pass may run a command whose provenance
  # deliberately fails; and under a command whose provenance succeeds, this
  # line is never reached and the mutation cannot change any outcome.
  #
  # Not a gap in coverage of the decision, only in coverage by this suite: the
  # provenance lanes in test/CMakeLists.txt assert exit 3 directly, and slice
  # 5b's stale-artifact lane adds a fourth. What is unwitnessed is the constant
  # itself, and only here.
  #
  # Reopening condition: a mutation runner that accepts a declared non-zero
  # baseline. Nothing in this slice needs one.
  byte_machine_mutation(
    FILE ${RUNNER} SPEC ${spec}
    LABEL "runner on ${runtime}: a provenance failure exits as an assertion failure"
    FIND [[  (adapter-exit harness-status-provenance))]]
    REPLACE [[  (adapter-exit harness-status-failed))]]
    EXPECT_SURVIVES TRUE)

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()
```

This pass's verify command must set up provenance **correctly**, and must use a manifest of two bodies. `byte_machine_mutation_run` runs every targeted specification on the staged, unmutated tree first and aborts with `baseline failure` if it does not exit 0 — so a command whose provenance deliberately fails cannot be used here, which is what makes the third mutation a declared survivor rather than an `EXPECT_STATUS 1` row.

Set `BYTE_MACHINE_FINGERPRINT_FILES` to the two staged manifest bodies joined with `|`, and `BYTE_MACHINE_EXPECT_FINGERPRINT_FILE` to a file the pass computes from those same two staged bodies with `fingerprint-manifest.ss` — the staged copies, not the repository originals, because the stage is what the run reads. Confirm the baseline passes before trusting any row: an unmutated tree that exits 3 here means the expectation was computed over the wrong two files.

Call the pass for Chez unconditionally and for Gambit inside the existing `if(BYTE_MACHINE_GAMBIT_EXECUTABLE)` guard, matching the slice-5a passes.

Update `EXPECTED_PASSES` and `EXPECTED_MUTATIONS` in that file to the real new numbers, and extend the comment above them to say what the increment is made of.

- [ ] **Step 3: Run both mutation suites**

```bash
ctest --preset pr -R 'mutation' -V
```

Expected: PASS. Both suites' asserted totals match what they actually ran.

- [ ] **Step 4: Run the whole suite**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, 52/52 and 10/10.

- [ ] **Step 5: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: the provenance decisions slice 5a left without a mutation"
```

---

### Task 9: The records

**Files:**
- Modify: `docs/decisions/0004-content-fingerprint-and-provenance.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Amend decision record 0004**

The record's "direction for closing it" names a build-time literal `include`d into the wrapper. Replace that paragraph with what was built, keeping the gap's own description intact — the demonstration of the defect is still correct and still worth reading.

The amendment must state: that W2 supersedes it; that 0004's stated objection to this direction ("one list, not two") was about the function's signature rather than a principle, and the signature changed; that the cost of the literal is asymmetric between the runtimes, with the Gambit half of that reason; and W6's bound — the copies sit beside the artifact rather than inside it, share one producer, and a hand-disturbed build tree can desynchronise them.

Re-measure every number before writing it. Do not copy a value from this plan or from the design document.

- [ ] **Step 2: Write the CHANGELOG entry**

Under `### Added`, describing what a reader of the repository gains: a Chez ahead-of-time lane over the same three programs the source lanes run; a fingerprint that describes the text an artifact was built from; and the lane that proves it can fail. State the suite's new totals, and state plainly what the mechanism does not prove — a lane is still not shown to touch exactly the files it names, and the copies are beside the artifact rather than inside it.

- [ ] **Step 3: Run the whole suite one more time**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS. Record the exact totals and put them in the commit message.

- [ ] **Step 4: Commit**

```bash
git add docs/decisions/0004-content-fingerprint-and-provenance.md CHANGELOG.md
git commit -m "docs: what a compiled lane's fingerprint now describes"
```

---

## Exit criteria for the slice

From design §9, checked before opening a pull request:

- [ ] The three `chez.aot` lanes are green and report the same fingerprint as their `chez.source` counterparts for the same manifest.
- [ ] `byte-machine.harness.stale-artifact.chez.aot` exits exactly 3, with the mismatch diagnosis.
- [ ] C1, C2 and C4 are caught for their declared reasons; C3 is caught; C3b is a declared survivor carrying the measurement Task 5 records.
- [ ] The `no-scheme` preset is 10/10, and the measured-path computation is exercised under it.
- [ ] Both mutation suites assert their own totals and those totals match.
- [ ] Cross-library identity holds on `chez.aot`, discharging slice 4 §10 for Chez.
- [ ] Design §5.3 states a measured answer, not a prediction.
