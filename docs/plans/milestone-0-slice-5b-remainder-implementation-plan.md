# Milestone 0 Slice 5b Remainder: the real aot lanes, the staleness lane, C1–C4, and the 0004 amendment — Implementation Plan

Status: ready to execute (regenerated 2026-08-20 against the post-0005/post-0006 tree, replacing Tasks 4 and 6–9 of [milestone-0-slice-5b-implementation-plan.md](./milestone-0-slice-5b-implementation-plan.md))

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register the three real `chez.aot` lanes over artifacts a build step actually compiles, prove the fingerprint-binding mechanism can fail with a lane whose artifact is built from text it does not declare, break every decision this adds, and close decision record 0004.

**Architecture:** The functional core already exists and is specified: `byte_machine_scheme_lane_command`'s aot branch returns the run command and the measured `fingerprint/` copy paths, keyed per lane name (`cmake/ByteMachineSchemeLane.cmake`). What is missing is the imperative shell that makes those paths true — one `add_custom_command` per aot lane that compiles the program and writes the measured copies in the same command (design W6) — plus the staleness lane, the mutations, and the records. Both launchers (`chez-compile.ss`, `chez-aot.ss`) shipped in slice 5b's first half and were re-verified through the include collapse; **no task in this plan edits a launcher's behaviour**.

**Tech Stack:** CMake 3.26, CTest, Chez Scheme 10.4.1 (`compile-program` / `load-program`), the project's own `cmake -P` specification and mutation harnesses.

**Design:** [`milestone-0-slice-5b-5c-compiled-lanes.md`](./milestone-0-slice-5b-5c-compiled-lanes.md) — read its two amendment blocks first: decision 0005 cancelled slice 5c (D5 closes at the end of this remainder, at the two Chez lanes), and decision 0006 moved every file target onto the inline libraries. Decision labels `W1`–`W12` and mutation labels `C1`–`C4`/`C3b` below refer to that document. This plan replaces Tasks 4 and 6–9 of [`milestone-0-slice-5b-implementation-plan.md`](./milestone-0-slice-5b-implementation-plan.md), whose remaining tasks were written against the pre-0005/pre-0006 tree; its Tasks 1–3 were delivered by PR #6 and survive as shipped code, and its Task 5 stays discharged (design §5.3).

**Carries:** the cycle ledger (`.superpowers/sdd/progress.md`, end of the include-collapse section) names three carries into this remainder, all from the include collapse's final review. Each is discharged at a named step: the **aot command-array spec gap** (Task 1 Step 5's full-command assertion), the **`.chez.sps` spec fixture strings** (Task 1 Step 5's rename), and the **`byte_machine_chez_aot_paths` comment describing its lanes in the future tense** (Task 3 Step 6).

## Global Constraints

- CMake floor is **3.26**. `cmake_parse_arguments` unsets a one-value keyword given `""`; CMP0174 is 3.31+ and may not be relied on. Forward optional single-value keywords conditionally, never empty.
- Chez floor is **10.4.1**, threaded machine type. Discovery owns both checks; no launcher re-checks them.
- Exit-status vocabulary is exactly **0, 1, 2, 3**: pass, assertion failure, harness/configuration/registration error, provenance failure. An expectation outside it is a configure error. A status outside it that is observed is its own failure class (process died).
- Every launcher diagnostic is prefixed `byte-machine-launcher: HARNESS-ERROR ` and exits **2**.
- **Baseline, measured 2026-08-20 on this branch's base** (Darwin arm64, Chez 10.4.1): `make test` (preset `pr`) **33/33**, preset `release` **33/33**, preset `no-scheme` **8/8**; CMake mutation suite **1 pass / 66 mutations**; Scheme mutation suite **25 passes / 60 mutations**; total `release` test time **14.4 s**. Harness (`cmake/` + `test/support/`) is **7,724 lines**, `src/` is 87. Every count below derives from these. Re-measure before writing any of them into a record (AGENTS.md; a green run with stale declared totals is the false comfort the totals gates exist to break).
- **Do not expect the harness to shrink.** chez-only-simplification.md §6 records that the old 4,000–4,500-line estimate was wrong about where the weight lives; this plan *adds* lanes and mutations to the 7,724-line base, and that growth is the deliverable.
- The `no-scheme` preset must stay green and stay at **8/8**. Nothing added to the functional core may require a Scheme runtime to specify. This plan registers no new `cmake.direct` lane, so the count does not change.
- Libraries are inline R6RS `.sls`, programs are `.sps`, and **no Scheme file may `include` another** (decision 0006; its acceptance gate greps for `include` forms). The staleness fixture in Task 3 is an ordinary standalone library file.
- Registration manifests use the keyword **`SOURCES`** (required). Within one lane's manifest, basenames must be unique (`byte_machine_lane_duplicate_basenames`, per-lane — the repository-wide guard is retired, decision 0006 decision 4).
- The `|` separator is used for environment-borne path lists — never `:` or `;`. Corollary, recorded in SchemeMutationSuite passes 22–25: `BYTE_MACHINE_EXPECT_COMMAND` also packs with `|`, so a multi-source manifest can never ride through the ByteMachineExpectExit wrapper. Task 6 depends on this fact.
- Every mutation asserts a failure **signature** where one has been measured (`EXPECT_STATUS` / `EXPECT_OUTPUT_MATCHES`), never merely a nonzero exit — and only where measured, not guessed. `EXPECT_SURVIVES` takes a written reason the suite re-prints; it is for the genuinely unwitnessable, never to reach green. Both suites assert their own totals; update the declared totals and their arithmetic comments in the same commit as the mutations.
- This plan adds no new exit path (status 3 has producers since slice 5a), but Tasks 4–6 still end with the *whole* mutation suite re-run, not only the new passes (AGENTS.md: a new route to an existing status can disarm an old mutation silently).
- Conventional Commits. Run the suite before every commit.
- No new dependencies. No SRFI-64, no package manager.

---

## File Structure

**Created**

| Path | Responsibility |
| --- | --- |
| `test/fixtures/stale-root/byte-machine/test/harness.sls` | A deliberately divergent (comment-appended) copy of the harness library, at its library-relative path, used only to build the staleness lane's artifact. |

**Modified**

| Path | Change |
| --- | --- |
| `cmake/ByteMachineSchemeLane.cmake` | Gains `byte_machine_lane_chez_aot_artifacts` (the W6 custom command) and the `STALE_LIBRARY_ROOT` keyword; the registrar calls the builder for aot lanes. |
| `test/CMakeLists.txt` | Registers `bootstrap.chez.aot`, `self.chez.aot`, `placeholder-identity.chez.aot`, and `stale-artifact.chez.aot`. |
| `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` | Builder stub and its reached/not-reached assertions; a two-source aot command case; the `STALE_LIBRARY_ROOT` case. |
| `test/support/cmake/MutationSuite.cmake` | C1, C2, C4, and the three shell-decision mutations; totals 66 → 72. |
| `test/support/cmake/SchemeMutationSuite.cmake` | C3/C3b pass, three launcher-refusal passes, and the W9 two-source provenance pass; totals 25/60 → 30/68. |
| `test/support/launchers/chez-aot.ss`, `test/support/launchers/chez-compile.ss` | **Comments only**: the "neither this file nor chez-aot.ss has a mutation of its own yet" paragraphs become false in Task 5 and are corrected there. |
| `docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md` | Dated measurement addenda to §5.3 (re-measure through the real lane) and §11 (lane build cost). |
| `docs/decisions/0004-content-fingerprint-and-provenance.md` | The closure amendment (W2/W3/W6). |
| `docs/plans/milestone-0-portability-spike.md` | Dated note on D5: closed at the two Chez lanes (decision 0005). |
| `CHANGELOG.md` | The remainder's entry. |

**Explicitly not touched:** launcher *behaviour* (both launchers shipped and re-verified; their flag grammars are `chez-compile.ss --library-root <dir>... --object-dir <dir>... --program <path> --output <path>` with positional pairing, and `chez-aot.ss --object-dir <dir>... --source-guard <dir> --program <compiled>`), `harness.sls`/`fingerprint.sls` (the W9 mutations stage copies; the sources do not change), and the lane-name grammar (`chez.aot` is already admitted — `cmake/ByteMachineTesting.cmake`).

---

### Task 1: The aot artifacts builder and the three real lanes

Design §8 item 4. The shell half of the mechanism: one custom command per aot lane that compiles the program and writes the measured copies — same command, one producer, which is the whole of W6.

**Files:**
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `byte_machine_chez_aot_paths(<name> <program> <out_object_dir> <out_compiled>)` and `byte_machine_lane_measured_copies(<dir> <out_var> <source>...)` — both shipped, in `cmake/ByteMachineSchemeLane.cmake`. `BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER`, `BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT`, `BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT`, `BYTE_MACHINE_HARNESS_MANIFEST` — all set in `test/CMakeLists.txt` before the harness lanes.
- Produces: `byte_machine_lane_chez_aot_artifacts(<name> <program> <stale_library_root> <declared-source>...)` — Task 3 changes nothing about this signature; the third parameter is already present and empty-string-valued for every lane this task registers. Task 4's shell mutations target the registrar's call-site guard.

**Read this before writing the builder.** Object directories are keyed on the **lane name**, not the program stem — `byte_machine_chez_aot_paths`'s own header explains why: this plan registers two `chez.aot` lanes over the *same* program (`self.chez.aot` here, `stale-artifact.chez.aot` in Task 3, both over `harness-self-tests.sps`), and program-stem keying would give them one object directory and one `fingerprint/`, letting the stale lane's copies silently overwrite the real lane's.

- [ ] **Step 1: Write the failing spec — the builder is reached for aot and only for aot**

`ByteMachineSchemeLaneSpec.cmake` stubs `byte_machine_add_test`/`byte_machine_add_exit_code_test` after including the module, because `add_test` is not scriptable under `cmake -P`. `add_custom_command` is not scriptable there either, so the builder gets the same treatment: a recorder stub, defined next to the registrar stubs (after the module include, around line 263), plus assertions on the two existing registration cases.

Add the stub beside the registrar stubs:

```cmake
# The aot artifacts builder is imperative shell (add_custom_command is not
# scriptable under cmake -P), so it is stubbed the same way the two
# registrars are: recorded, not run. What the spec can see is the routing
# decision -- an aot registration must reach it, a source registration must
# not -- and the arguments it was reached with, which is where Task 3's
# stale-root forwarding becomes assertable with no Scheme present.
function(byte_machine_lane_chez_aot_artifacts name program stale_library_root)
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_NAME "${name}")
  set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_STALE "${stale_library_root}")
endfunction()
```

In the existing aot registration case (the one asserting `BYTE_MACHINE_EXECUTION_MODE=aot`, around line 330), seed the property before the registration and assert after it:

```cmake
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_NAME "none")
```

…then, after the existing environment assertions of that case:

```cmake
get_property(builder_name GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_NAME)
spec_check_equal("${builder_name}" "byte-machine.harness.example.chez.aot"
  "an aot registration reaches the artifacts builder with its own lane name")
get_property(builder_stale GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_STALE)
spec_check_equal("${builder_stale}" ""
  "a lane without STALE_LIBRARY_ROOT hands the builder an empty stale root")
```

In the source-mode registration case immediately below it (the "a source lane still declares source" case), seed the property the same way before the registration and add:

```cmake
get_property(builder_name GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_NAME)
spec_check_equal("${builder_name}" "none"
  "a source registration never reaches the artifacts builder")
```

Seed before asserting (AGENTS.md: an output variable is seeded before it is asserted empty or unchanged).

- [ ] **Step 2: Run the spec and watch it fail**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `builder_name` is `none` after the aot registration, because nothing in `byte_machine_add_scheme_lane` calls the builder yet.

- [ ] **Step 3: Write the builder and its call site**

Append to `cmake/ByteMachineSchemeLane.cmake`, in the imperative-shell section:

```cmake
# byte_machine_lane_chez_aot_artifacts(<name> <program> <stale_library_root>
#                                      <declared-source>...)
#
# Build one aot lane's compiled program and, in the SAME custom command, the
# fingerprint/ copies of the sources it was built from. One command is the
# whole of decision W6: the object and the copies then have one producer and
# cannot be separately stale, which is what makes the copies evidence about
# the artifact rather than a second reading of the source tree.
#
# The DEPENDS list is the other half. Every .sls under both library roots is
# a compile input (compile-imported-libraries), so every one of them must be
# able to re-trigger this command; a library missing from this list would
# leave the artifact -- and its copies -- describing the previous text, which
# is the exact defect class decision 0004 demonstrated.
#
# <stale_library_root> is empty for every lane that is meant to pass. When it
# is set (the staleness lane, Task 3 of the remainder plan), it is prefixed
# as one extra (source root -> object dir) pair sharing the harness object
# directory, so a library present there at its library-relative path is the
# one compiled in -- and the copy step below takes each declared source from
# wherever the compile found it, so the measured copies stay evidence about
# the artifact under staleness too. The declared list, and therefore the
# expectation, is never touched by this parameter.
function(byte_machine_lane_chez_aot_artifacts name program stale_library_root)
  byte_machine_chez_aot_paths("${name}" "${program}" object_dir compiled)

  # Prefixed, not appended: Chez consults library-directories entries in
  # order and takes the first source it can resolve (measured for this exact
  # shape -- design section 5.3's remainder addendum), so a library present
  # in the stale root shadows the real one for the compile while every
  # library absent there still resolves from the real roots.
  set(stale_pair_args "")
  if(stale_library_root)
    list(APPEND stale_pair_args
      --library-root "${stale_library_root}"
      --object-dir "${object_dir}/harness")
  endif()

  # The copy step takes each declared source from wherever the compile step
  # will have found it. A declared source is shadowed exactly when the stale
  # root holds a file at the same path relative to the harness library root;
  # sources outside that root (the program, src/ libraries) are never
  # shadowed, because the stale pair above is the harness pair's shadow and
  # nothing else's.
  set(sources_of_record "")
  foreach(body IN LISTS ARGN)
    set(source_of_record "${body}")
    if(stale_library_root)
      string(FIND "${body}" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/" at)
      if(at EQUAL 0)
        string(REPLACE "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/" ""
               relative "${body}")
        if(EXISTS "${stale_library_root}/${relative}")
          set(source_of_record "${stale_library_root}/${relative}")
        endif()
      endif()
    endif()
    list(APPEND sources_of_record "${source_of_record}")
  endforeach()

  byte_machine_lane_measured_copies("${object_dir}/fingerprint" copies ${ARGN})
  set(copy_commands "")
  list(LENGTH ARGN source_count)
  math(EXPR last "${source_count} - 1")
  foreach(i RANGE 0 ${last})
    list(GET sources_of_record ${i} source_of_record)
    list(GET copies ${i} copy)
    list(APPEND copy_commands
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
              "${source_of_record}" "${copy}")
  endforeach()

  # Configure-time glob, deliberately without CONFIGURE_DEPENDS: a new
  # library arrives with a SOURCES edit in test/CMakeLists.txt, which forces
  # the reconfigure this glob needs anyway. Empty is a fatal error, not a
  # lane with no dependencies: a lane that depends on nothing goes on
  # passing against the previous text.
  file(GLOB_RECURSE chez_library_sources
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/*.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/*.sls")
  if(NOT chez_library_sources)
    message(FATAL_ERROR
      "byte-machine: no Chez library sources were found under "
      "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT} or "
      "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}. That means this glob is wrong, "
      "not that the aot lane has nothing to depend on.")
  endif()

  add_custom_command(
    OUTPUT "${compiled}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${object_dir}/harness"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${object_dir}/src"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${object_dir}/fingerprint"
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
            "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            ${stale_pair_args}
            --library-root "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            --object-dir "${object_dir}/harness"
            --library-root "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}"
            --object-dir "${object_dir}/src"
            --program "${program}"
            --output "${compiled}"
    ${copy_commands}
    DEPENDS "${program}"
            "${BYTE_MACHINE_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            "${BYTE_MACHINE_HARNESS_CHEZ_AOT_LAUNCHER}"
            ${chez_library_sources}
            ${sources_of_record}
    COMMENT "byte-machine: Chez aot compile for ${name}"
    VERBATIM)

  string(REPLACE "." "_" stem "${name}")
  add_custom_target("byte_machine_chez_aot_${stem}" DEPENDS "${compiled}")
  if(NOT TARGET byte_machine_chez_aot)
    add_custom_target(byte_machine_chez_aot ALL)
  endif()
  add_dependencies(byte_machine_chez_aot "byte_machine_chez_aot_${stem}")
endfunction()
```

Note the pairing order: `chez-compile.ss` pairs the nth `--library-root` with the nth `--object-dir` positionally, and the run command built by `byte_machine_scheme_lane_command`'s aot branch passes `--object-dir ${object_dir}/harness` then `--object-dir ${object_dir}/src` — the compile step above must keep harness-then-src so the objects land where the run will look, and the stale pair (when present) shares the harness object directory so the run command needs no change at all.

Call it from `byte_machine_add_scheme_lane`, after the `no-runtime` / `unknown-*` status checks and before the environment block:

```cmake
  # The shell half of the aot lane. Guarded on the mode rather than on the
  # backend, so adding a backend does not silently acquire this rule; by this
  # point status is `ok`, so a chez executable is known to exist.
  if(lane_mode STREQUAL "aot")
    byte_machine_lane_chez_aot_artifacts(
      "${arg_NAME}" "${arg_PROGRAM}" "" ${arg_SOURCES})
  endif()
```

(The empty third argument is `STALE_LIBRARY_ROOT`'s slot; Task 3 replaces the literal with the parsed keyword.)

- [ ] **Step 4: Run the spec and watch it pass**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: PASS, including the three new assertions.

- [ ] **Step 5: Add the two-source aot command case to the spec**

C1 and C2 (Task 4) need a witness that sees a **multi**-source measured list with no runtime present: the existing aot registration case carries one source, and a reversal of a one-element list is invisible. Append to the pure-function section of `ByteMachineSchemeLaneSpec.cmake` (after the "Declared sources versus measured sources" source-mode case):

```cmake
# The aot half of the same rule, over two sources, because a one-source
# manifest cannot witness order: the measured list must be the fingerprint/
# copies, in the declared order. This is the assertion mutations C1 (measured
# collapses to declared) and C2 (measured built in reverse) break.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
byte_machine_scheme_lane_command(byte-machine.harness.example-two.chez.aot
  chez aot "/h/self/p.sps"
  command measured status message "/h/shared/a.scm" "/h/shared/b.scm")
spec_check_equal("${status}" "ok" "a two-source chez aot lane is accepted")
spec_check_equal("${measured}"
  "/objects/byte-machine_harness_example-two_chez_aot/fingerprint/a.scm;/objects/byte-machine_harness_example-two_chez_aot/fingerprint/b.scm"
  "an aot lane measures the fingerprint copies, in the declared order")
spec_check_equal("${command}"
  "/opt/chez;--script;/launchers/chez-aot.ss;--object-dir;/objects/byte-machine_harness_example-two_chez_aot/harness;--object-dir;/objects/byte-machine_harness_example-two_chez_aot/src;--source-guard;/b/guard;--program;/objects/byte-machine_harness_example-two_chez_aot/p.so"
  "chez aot lane command line")
```

Run `cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake`. Expected: PASS immediately — the pure core already does this; the case exists to make C1/C2 catchable, and if it fails instead, stop: the assertion text above was derived from `byte_machine_chez_aot_paths` (`.` → `_` in the name key, `NAME_WLE` stem) and the mismatch is between this plan and the shipped code, which must be resolved by reading the code, not by editing it.

This step also discharges two ledger carries from the include collapse's final review. First, the **aot command-array spec gap**: the full-command assertion above is the first spec of the aot branch's complete command line. Second, the **`.chez.sps` fixture strings**: the spec's invented program paths (`/h/self/p.chez.sps`, in the source-mode cases and the two no-runtime message assertions that interpolate them) still carry the wrapper-era `.chez` infix that retired with decision 0006. Rename every occurrence in this spec file to `p.sps`, updating the two no-runtime message assertions in the same edit — they quote the path verbatim, so a half-done rename fails loudly here rather than silently anywhere. Re-run the spec after the rename: PASS, and `rg -n 'chez\.sps' test/support/cmake/ByteMachineSchemeLaneSpec.cmake` comes back empty. (`rg -n 'chez\.sps'` across the repository then reports only historical prose in `docs/`, if anything; source and specs are clean.)

- [ ] **Step 6: Register the three lanes**

In `test/CMakeLists.txt`, after the `chez.source` harness lanes and their launcher-refusal blocks (below the `chez-aot-launcher-dirty-source-guard` registration is a natural place):

```cmake
# --- Chez ahead-of-time lanes ----------------------------------------------
#
# Three of the programs the source lanes run, compiled. Nothing about the
# sources changes; what changes is that the text reaching the process came
# out of objects built earlier, which is why these lanes measure the copies
# the compile step kept rather than the repository sources. Three lanes, not
# one per source lane: bootstrap (the runner's primitives with no runner),
# self (the runner on itself), and placeholder-identity (slice 4 section 10
# deferred cross-library identity under compiled lanes to exactly here --
# separate instantiation is a modelled risk in source mode and a real one
# once each library is compiled into its own object).
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.bootstrap.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder-identity.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${CMAKE_SOURCE_DIR}/src/byte-machine/placeholder.sls"
          "${CMAKE_SOURCE_DIR}/src/byte-machine/placeholder-consumer.sls"
          "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.sps"
  TIMEOUT 120)
```

Each lane's `SOURCES` is byte-for-byte its `chez.source` counterpart's list. That is what makes the expectation file shared: `byte_machine_expected_fingerprint` keys by a digest of the declared manifest, so `self.chez.source` and `self.chez.aot` verify against the *same* build-produced expectation — cross-mode agreement is structural, not coincidental.

- [ ] **Step 7: Build and run the aot selection**

```bash
make build
ctest --preset pr -R '\.chez\.aot$' --output-on-failure
```

Expected: **6/6** (the three launcher-refusal lanes carry the same suffix). Each new lane's output ends `fingerprint verified against the build manifest`. Confirm the artifacts exist and are what the run loaded:

```bash
ls build/dev/chez-objects/*/*/byte-machine_harness_self_chez_aot/
```

Expected: `harness/ src/ fingerprint/ harness-self-tests.so`, with `fingerprint/` holding `fingerprint.sls harness.sls harness-self-tests.sps`.

- [ ] **Step 8: Record the cross-mode agreement and the lane build cost**

The design's §9 first criterion and §11's first open question, both discharged by measurement:

```bash
ctest --preset pr -R 'harness\.self\.chez\.(source|aot)$' --show-only=json-v1 | grep -o 'BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=[^"]*'
```

Expected: two lines naming the **same** expectation file (same manifest digest — `ctest -V` does not print ENVIRONMENT properties, which is why this uses the json view). `cat` that file and record the value for the Task-1 commit message — it is the first cross-mode agreement this repository has produced.

```bash
time make test
```

Record the wall-clock against the 2026-08-20 baseline (release preset test time 14.4 s; the compile step runs at `make build`, so measure the whole `make test`, not ctest alone). Append a dated sentence to design §11's "Are the compiled lanes affordable?" paragraph with both numbers. If the added cost is disproportionate, raise it at review before adding a preset split — the design says the mitigation is decided on the number, not in advance.

- [ ] **Step 9: Run the whole suite**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, **36/36** (33 + 3) and **8/8**.

- [ ] **Step 10: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake test/CMakeLists.txt test/support/cmake/ByteMachineSchemeLaneSpec.cmake docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md
git commit -m "feat: three Chez ahead-of-time lanes over compiled artifacts"
```

---

### Task 2: Re-measure §5.3 through the real lane

Design §8 item 5: "Measure §5.3 against the lane that now exists, and record the answer in this document before the mutations are written." The 2026-08-17 measurements behind C3/C3b were taken against scratch fixtures and the pre-collapse tree; the `scratch-fixture-measurements` standard says a number earns its place in a design record only re-taken against the shipped artifact. Task 3 additionally relies on library-directories consulting its entries in order, which becomes load-bearing for the first time there and must be measured here first.

**Files:**
- Modify: `docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md`

- [ ] **Step 1: Re-take the C3 measurement against Task 1's real artifacts**

Using the objects Task 1 built (adjust the versioned path segment to what `ls build/dev/chez-objects/` shows):

```bash
OBJ=$(ls -d build/dev/chez-objects/*/*/byte-machine_harness_self_chez_aot)
mkdir -p "$OBJ/harness/byte-machine/test"
cp test/support/harness/byte-machine/test/harness.sls "$OBJ/harness/byte-machine/test/harness.sls"
printf '\n;; planted for the section-5.3 re-measure\n' >> "$OBJ/harness/byte-machine/test/harness.sls"
sed 's/(map (lambda (dir) (cons source-guard-dir dir)) object-dirs)/object-dirs/' \
  test/support/launchers/chez-aot.ss > /tmp/chez-aot-unpaired.ss
```

Run the real lane's command shape once with the shipped launcher and once with the unpaired copy (`ctest --preset pr -R 'harness\.self\.chez\.aot$' -V` prints the exact command line; substitute the launcher path for the second run and run both by hand). Expected: shipped launcher — the plant is never read, the lane is green; unpaired copy — Chez reads the planted source and `load-program` refuses at **255** naming a different compilation instance. Then remove the plant:

```bash
rm "$OBJ/harness/byte-machine/test/harness.sls"
```

If the unpaired run does **not** fail, stop: C3 has lost its witness on this tree, and per AGENTS.md that is a finding to investigate before Task 5 declares anything.

- [ ] **Step 2: Measure library-directories ordering for the exact stale shape**

Two roots holding the same library name with divergent bodies, compiled through the real launcher with root A prefixed, both pairs sharing one object directory — the exact shape Task 3's stale pair takes:

```bash
S=$(mktemp -d)
mkdir -p "$S/a/x" "$S/b/x" "$S/obj" "$S/guard"
cat > "$S/a/x/lib.sls" <<'EOF'
(library (x lib)
  (export which)
  (import (rnrs base))
  (define (which) "first"))
EOF
cat > "$S/b/x/lib.sls" <<'EOF'
(library (x lib)
  (export which)
  (import (rnrs base))
  (define (which) "second"))
EOF
cat > "$S/prog.sps" <<'EOF'
(import (rnrs base) (rnrs io simple) (x lib))
(display (which))
(newline)
EOF
chez --script test/support/launchers/chez-compile.ss \
  --library-root "$S/a" --object-dir "$S/obj" \
  --library-root "$S/b" --object-dir "$S/obj" \
  --program "$S/prog.sps" --output "$S/prog.so"
chez --script test/support/launchers/chez-aot.ss \
  --object-dir "$S/obj" --source-guard "$S/guard" --program "$S/prog.so"
```

(`chez` here is the discovered `BYTE_MACHINE_CHEZ_EXECUTABLE`; `cmake --preset dev` prints it.) Expected: the run prints `first` — the earlier pair's source wins, including when both pairs share one object directory. This is the fact Task 3's prefixed stale pair stands on; note that the staleness lane's own exit-3 gate (Task 3 step 6) re-proves it end to end through the real harness, which is what lets a scratch measurement be recorded at all.

- [ ] **Step 3: Record both in the design document**

Append a dated addendum to design §5.3: the C3 re-measure (real artifacts, shipped launcher, planted library, both outcomes, the 255), the C3b status (unchanged: the launcher's own header records `source-directories` emptiness as measured inert, and nothing in the inline tree resolves through it), and the ordering measurement with its scratch-then-lane caveat. Keep the section's existing text; the addendum extends the record, it does not rewrite history.

- [ ] **Step 4: Commit**

```bash
git add docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md
git commit -m "docs: section 5.3 re-measured against the shipped aot lane"
```

---

### Task 3: The staleness lane

Design §7.1 and W12: the lane that makes claim 2 falsifiable — an artifact compiled from a fixture variant of a library the registration declares in its real form. It is a lane and not a mutation because the Scheme mutation suite stages one already-mutated tree per pass and structurally cannot express "built before the edit, run after it".

The include-era mechanism (`--source-dir` prefixing) died with decision 0006; the inline mechanism is a **stale library root**: one extra `--library-root`/`--object-dir` pair, prefixed to the compile step only, sharing the harness object directory. The run command does not change, the declared list does not change, the expectation does not change — only what the compile resolves, and therefore what the copies record.

**Files:**
- Create: `test/fixtures/stale-root/byte-machine/test/harness.sls`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Consumes: `byte_machine_lane_chez_aot_artifacts` from Task 1 — its third parameter stops being the literal `""` at the call site and becomes the parsed keyword; the function body already handles it.
- Produces: a `STALE_LIBRARY_ROOT <dir>` one-value option on `byte_machine_add_scheme_lane`. Nothing later consumes it; it exists for exactly one registration.

- [ ] **Step 1: Create the divergent library**

```bash
mkdir -p test/fixtures/stale-root/byte-machine/test
cp test/support/harness/byte-machine/test/harness.sls test/fixtures/stale-root/byte-machine/test/harness.sls
cat >> test/fixtures/stale-root/byte-machine/test/harness.sls <<'BODY'

;; DELIBERATELY NOT THE LIBRARY OF THE SAME NAME UNDER test/support/harness.
;;
;; This copy exists so one lane can compile an artifact from text its own
;; registration does not declare. That lane must exit 3: the expectation is
;; computed from the real library, the run measures the copy the compile
;; step kept, and the two disagree. If it exits 0 instead, a compiled
;; lane's fingerprint has stopped describing its artifact.
;;
;; Behaviour-identical on purpose -- the divergence is this comment -- so
;; the lane can only fail the provenance way, never by the program
;; misbehaving.
;;
;; Regenerate after any harness.sls change (staleness of THIS copy only
;; widens the divergence and cannot make the two texts agree, so
;; regeneration is hygiene, not correctness):
;;   cp test/support/harness/byte-machine/test/harness.sls \
;;      test/fixtures/stale-root/byte-machine/test/harness.sls
;;   (then re-append this comment block)
BODY
```

The trailing comment is lexically inert — Chez reads the library form and skips what follows — so the copy stays a valid, behaviour-identical library whose bytes differ.

- [ ] **Step 2: Write the failing spec case**

Append to `ByteMachineSchemeLaneSpec.cmake`, after the WRONG_FINGERPRINT cases:

```cmake
# STALE_LIBRARY_ROOT changes what is compiled, never what is declared or
# run. If it reached the declared list the expectation would move with the
# artifact, the two would agree, and the lane that exists to fail would
# pass; if it changed the run command the lane would stop being the same
# lane it is the stale twin of. Three assertions, one per invariant.
set(BYTE_MACHINE_CHEZ_EXECUTABLE "/opt/chez")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_REGISTRAR "none")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION "none")
set_property(GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_STALE "unset")
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.example-stale.chez.aot
  BACKEND chez
  PROGRAM "${SPEC_SELF}"
  SOURCES "${SPEC_SELF}"
  STALE_LIBRARY_ROOT "/fixtures/stale-root"
  EXPECT_EXIT 3
  TIMEOUT 10)
get_property(builder_stale GLOBAL PROPERTY BYTE_MACHINE_SPEC_AOT_BUILDER_STALE)
spec_check_equal("${builder_stale}" "/fixtures/stale-root"
  "STALE_LIBRARY_ROOT reaches the artifacts builder")
get_property(fingerprint_function GLOBAL PROPERTY BYTE_MACHINE_SPEC_FINGERPRINT_FUNCTION)
spec_check_equal("${fingerprint_function}" "expected"
  "a stale lane still computes the real expectation from its declared sources")
get_property(environment GLOBAL PROPERTY BYTE_MACHINE_SPEC_ENVIRONMENT)
list(GET environment 0 mode_entry)
spec_check_equal("${mode_entry}" "BYTE_MACHINE_EXECUTION_MODE=aot"
  "a stale lane is an ordinary aot lane to everything downstream of the builder")
```

- [ ] **Step 3: Run the spec and watch it fail**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `STALE_LIBRARY_ROOT` is not a known keyword, so it lands in `arg_UNPARSED_ARGUMENTS` and the registration is refused before any assertion runs.

- [ ] **Step 4: Add the keyword and thread it through**

In `byte_machine_add_scheme_lane`, extend the one-value keywords:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg "WRONG_FINGERPRINT"
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY;STALE_LIBRARY_ROOT"
    "LABELS;ENVIRONMENT;SOURCES")
```

and replace the builder call's empty literal:

```cmake
  if(lane_mode STREQUAL "aot")
    byte_machine_lane_chez_aot_artifacts(
      "${arg_NAME}" "${arg_PROGRAM}" "${arg_STALE_LIBRARY_ROOT}" ${arg_SOURCES})
  endif()
```

Also update the registrar's signature comment — it currently omits `SOURCES`, `WRONG_FINGERPRINT`, and now `STALE_LIBRARY_ROOT` (this is slice 5a's carried item 4, landing here where the signature last changes):

```cmake
# byte_machine_add_scheme_lane(NAME <name> BACKEND <chez> PROGRAM <path>
#                              TIMEOUT <seconds> SOURCES <path>...
#                              [EXPECT_EXIT <code>] [WRONG_FINGERPRINT]
#                              [STALE_LIBRARY_ROOT <dir>]
#                              [WORKING_DIRECTORY <dir>]
#                              [LABELS ...] [ENVIRONMENT ...])
#
# NAME, BACKEND, PROGRAM, TIMEOUT and SOURCES are required. The name's
# fifth field is the execution mode; the registrar derives it, so a
# registration here cannot claim one lane while running another.
#
# WRONG_FINGERPRINT hands the lane an expectation the run cannot match, and
# STALE_LIBRARY_ROOT compiles the artifact from any library the given root
# holds at its library-relative path while the declared SOURCES keep naming
# the real one. Both exist to make a passing provenance check falsifiable;
# neither belongs on a lane that is meant to pass.
#
# With EXPECT_EXIT the lane is registered through the exact-status helper;
# without it, a nonzero exit fails the test in the ordinary way.
```

- [ ] **Step 5: Run the spec and watch it pass**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: PASS.

- [ ] **Step 6: Register the lane and prove it exits 3**

In `test/CMakeLists.txt`, in the provenance section after `unreached-provenance`:

```cmake
# An artifact built from text this registration does not declare. The
# expectation comes from the real harness.sls; the compile step resolves
# (byte-machine test harness) from a divergent fixture copy instead and
# keeps that copy as what the run measures. The two disagree, so the lane
# exits 3. This is the only lane in the tree that can fail when a compiled
# lane's fingerprint stops describing its artifact -- a lane rather than a
# mutation because the Scheme mutation suite stages one already-mutated
# tree per pass and cannot express "built before the edit, run after it"
# (design W12, slice 5a task 6).
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.stale-artifact.chez.aot
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  STALE_LIBRARY_ROOT "${CMAKE_CURRENT_LIST_DIR}/fixtures/stale-root"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)
```

Registering this lane also discharges the ledger's third carry: `byte_machine_chez_aot_paths`'s header comment (around `cmake/ByteMachineSchemeLane.cmake:66`) justifies lane-name keying by saying "slice 5b's remainder registers byte-machine.harness.self.chez.aot and byte-machine.harness.stale-artifact.chez.aot" — future tense, attributed to a slice that is now this one. Reword that sentence to present tense ("That is not hypothetical: two registered lanes share this PROGRAM — …self.chez.aot and …stale-artifact.chez.aot, and the second compiles it from deliberately divergent text"), so the comment describes the tree instead of predicting it.

```bash
make build && ctest --preset pr -R 'stale-artifact' -V
```

Expected: PASS, with the inner process exiting **3** and printing the provenance mismatch diagnosis naming the computed and expected fingerprints. **If it exits 0, the binding mechanism is not working and nothing further in this plan is evidence; do not proceed past this step until it exits 3.** (Exit 0 here would mean the measured copies matched the declared expectation — check `fingerprint/harness.sls` inside the stale lane's object directory: it must carry the fixture's trailing comment block.)

- [ ] **Step 7: Run the whole suite**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, **37/37** and **8/8**.

- [ ] **Step 8: Commit**

```bash
git add test/fixtures/stale-root cmake/ByteMachineSchemeLane.cmake test/CMakeLists.txt test/support/cmake/ByteMachineSchemeLaneSpec.cmake
git commit -m "test: a lane whose artifact was built from text it does not declare"
```

---

### Task 4: The CMake-layer mutations — C1, C2, C4, and the shell decisions

Every decision Tasks 1 and 3 added to `cmake/ByteMachineSchemeLane.cmake`, broken on a staged copy, with `ByteMachineSchemeLaneSpec.cmake` required to notice. Before writing any FIND text, open the shipped file and copy the line verbatim — this plan quotes the tree at plan time, and Task 1/3 just edited it.

**Files:**
- Modify: `test/support/cmake/MutationSuite.cmake`

- [ ] **Step 1: Add the six mutations**

In the `--- ByteMachineSchemeLane ---` section, after the duplicate-basename mutations:

```cmake
# C1. Protium's actual behaviour for its Chez aot lane: fingerprint the
# repository originals. Under it the staleness lane's expectation and its
# measurement read the same files again, they agree, and the lane that
# exists to exit 3 exits 0 -- the whole defect decision record 0004
# demonstrated and this slice closes. Witnessed with no runtime present by
# the spec's two-source aot case and its one-source registration case.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a compiled lane measures the repository originals"
  FIND [[      byte_machine_lane_measured_copies("${object_dir}/fingerprint" measured ${ARGN})
      set(${out_measured} ${measured} PARENT_SCOPE)]]
  REPLACE [[      set(${out_measured} ${ARGN} PARENT_SCOPE)]])

# C2. harness-fingerprint-combine is order-sensitive by design, so a
# reordered measured list computes a different digest over the same bytes.
# Only a two-or-more-source manifest can see this, which is what the spec's
# example-two case exists for.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the measured list is built in reverse"
  FIND [[    list(APPEND copies "${dir}/${name}")]]
  REPLACE [[    list(PREPEND copies "${dir}/${name}")]])

# C4. The literal the mode plumbing replaced. Distinct from the deletion
# mutation above ("the source execution mode is no longer declared"): this
# one keeps the entry and makes it wrong, which is the defect a compiled
# lane actually suffers. Not caught by the harness's own assertion -- under
# W8 that assertion accepts any vocabulary member and `source` is one -- but
# by the spec's "an aot lane declares the aot mode" case, asserted with no
# runtime present, which is why the mode logic lives in the registrar
# rather than in the custom command.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the execution mode is the literal source again"
  FIND [[    "BYTE_MACHINE_EXECUTION_MODE=${lane_mode}"]]
  REPLACE [[    "BYTE_MACHINE_EXECUTION_MODE=source"]])

# The builder call-site guard, in both directions, per the
# WORKING_DIRECTORY precedent: one direction only tests half a conditional.
# if(FALSE): no aot lane ever gets an artifact -- the spec's "reaches the
# artifacts builder" case fails. if(TRUE): every source lane acquires a
# compile step it must not have -- the spec's "never reaches" case fails.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the artifacts builder is never called"
  FIND [[  if(lane_mode STREQUAL "aot")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: the artifacts builder is called for every lane"
  FIND [[  if(lane_mode STREQUAL "aot")]]
  REPLACE [[  if(TRUE)]])

# The stale root is parsed and then not forwarded, so the staleness lane
# would silently compile from the real text and exit 0. The spec's
# "STALE_LIBRARY_ROOT reaches the artifacts builder" case fails.
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: STALE_LIBRARY_ROOT is parsed and never forwarded"
  FIND [[      "${arg_NAME}" "${arg_PROGRAM}" "${arg_STALE_LIBRARY_ROOT}" ${arg_SOURCES})]]
  REPLACE [[      "${arg_NAME}" "${arg_PROGRAM}" "" ${arg_SOURCES})]])
```

What is deliberately *not* mutated here: the builder's own body (the copy-source-of-record logic, the DEPENDS list, the prefix order). Those live inside `add_custom_command` arguments the spec's stub never executes; their end-to-end witness is the staleness lane itself, permanently registered and asserting exit 3 — which is exactly the division of labour W12 prescribes. Record this sentence as a comment above the group.

- [ ] **Step 2: Update the declared total**

`EXPECTED_MUTATIONS` in `MutationSuite.cmake` rises **66 → 72**; extend the arithmetic comment beside it in its existing style (…`+ 6 slice-5b-remainder scheme-lane`). `EXPECTED_PASSES` stays 1.

- [ ] **Step 3: Run the CMake mutation suite**

```bash
ctest --preset pr -R 'cmake-mutation' --output-on-failure
```

Expected: PASS, 72 mutations, every one caught (none of these six declares a survivor). For each new mutation, confirm from the output that it was caught by the assertion named in its comment — a mutation caught for the wrong reason stops catching anything the day its real target changes. Where the catching assertion's failure text is stable, narrow with `EXPECT_OUTPUT_MATCHES` — but only from the observed output of this run, never guessed.

- [ ] **Step 4: Run the whole suite and commit**

```bash
make test
git add test/support/cmake/MutationSuite.cmake
git commit -m "test: break every registrar decision the aot lanes added"
```

Expected before the commit: PASS, 37/37.

---

### Task 5: The Scheme-layer mutations — C3, C3b, and the launcher refusals

The launcher headers both carry the sentence "neither this file nor chez-aot.ss has a mutation of its own yet … intended work for the slice that wires a real chez.aot lane." This is that slice. It lands C3/C3b (design §7.2, measurements settled in §5.3 and re-taken in Task 2) plus one mutation per genuinely-new launcher refusal — the three that have registered lanes. The remaining flag-block copies stay unmutated with the headers' honesty updated, not silently.

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`
- Modify: `test/support/launchers/chez-aot.ss` (comments only)
- Modify: `test/support/launchers/chez-compile.ss` (comments only)

- [ ] **Step 1: The C3/C3b pass**

Model: pass 7 (the source launcher's library-directories pairing). The pass compiles real objects once, into the suite's work directory, using the *staged* compile launcher over the *staged* tree — so the run and its inputs come from one place — then plants a divergent library source inside the object directory, where only an unpaired library path can see it. Append after pass 25, before the totals gate:

```cmake
# --- Pass 26: the aot launcher's library-path pairing ------------------------
#
# C3 and C3b, measured 2026-08-17 and re-measured against the shipped lane
# (design section 5.3, remainder addendum). The objects are compiled once,
# here, from the staged tree; the plant is a byte-divergent copy of the
# harness library dropped at its library-relative path inside the object
# directory, touched newer than the objects. Under the shipped pairing the
# plant sits in a directory Chez consults only for objects and is never
# read; under C3's unpaired shape every object directory is also a source
# directory, Chez finds the newer source, re-expands it, and load-program
# refuses the different compilation instance at 255 -- outside the status
# vocabulary, reported as a process that died, which is the honest shape of
# this defect.
byte_machine_mutation_reset()

set(AOT_PASS_DIR "${WORK_DIR}/aot-pairing")
file(MAKE_DIRECTORY "${AOT_PASS_DIR}/harness" "${AOT_PASS_DIR}/src"
     "${AOT_PASS_DIR}/source-guard")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/chez-compile.ss"
          --library-root "${STAGE_DIR}/test/support/harness"
          --object-dir "${AOT_PASS_DIR}/harness"
          --library-root "${STAGE_DIR}/src"
          --object-dir "${AOT_PASS_DIR}/src"
          --program "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps"
          --output "${AOT_PASS_DIR}/harness-bootstrap.so"
  RESULT_VARIABLE aot_compile_rc)
if(NOT aot_compile_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 26 could not compile its artifacts (rc "
    "${aot_compile_rc}); nothing this pass reports would mean anything.")
endif()
file(MAKE_DIRECTORY "${AOT_PASS_DIR}/harness/byte-machine/test")
file(COPY_FILE
  "${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls"
  "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls")
file(APPEND "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls"
  "\n;; planted: only an unpaired library path can read this file\n")
file(TOUCH "${AOT_PASS_DIR}/harness/byte-machine/test/harness.sls")

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env" "BYTE_MACHINE_EXECUTION_MODE=aot" "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script"
  "${STAGE_DIR}/test/support/launchers/chez-aot.ss"
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--object-dir" "${AOT_PASS_DIR}/src"
  "--source-guard" "${AOT_PASS_DIR}/source-guard"
  "--program" "${AOT_PASS_DIR}/harness-bootstrap.so")

byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC byte-machine.harness.self.chez.aot
  LABEL "chez-aot launcher: the source guard is unpaired from the object directories"
  FIND [[(library-directories
 (map (lambda (dir) (cons source-guard-dir dir)) object-dirs))]]
  REPLACE [[(library-directories object-dirs)]])

byte_machine_mutation(
  FILE test/support/launchers/chez-aot.ss SPEC byte-machine.harness.self.chez.aot
  LABEL "chez-aot launcher: source-directories is not emptied"
  FIND [[(source-directories '())]]
  REPLACE [[(source-directories (list "."))]]
  EXPECT_SURVIVES
    "measured inert 2026-08-17 and re-measured through the shipped lane: library resolution runs through library-directories, no file in the inline tree includes another (decision 0006), so this line narrows nothing reachable today; kept in the launcher because it costs one line and guards a future load or include added to the launcher itself. Reopening condition: a Chez that re-resolves a compiled library's sources at load time.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

Before committing, run once and read C3's report: if the caught status is the measured 255, narrow it with `EXPECT_STATUS 255`; if the diagnostic text (`different compilation instance`) is in the captured output, add `EXPECT_OUTPUT_MATCHES` for it — from the observed run only. The environment override matters: the mutation lane's own registration exports `BYTE_MACHINE_EXECUTION_MODE=source`, and the staged program asserts membership of the vocabulary, so the verify command sets `aot` explicitly for its own invocation.

- [ ] **Step 2: The three launcher-refusal passes**

Model: passes 9–17's `byte_machine_slice3_launcher_pass` — a wrapper verify command whose green baseline is the refusal firing at 2, so deleting the refusal is what breaks it. The helper is chez-source-specific (it hardcodes the launcher path), so add a sibling that takes the launcher too, and call it three times — one per refusal that has a registered lane, each invocation copied from that lane's own command line in `test/CMakeLists.txt`:

```cmake
# --- Passes 27 to 29: the aot-side launchers' new refusals -------------------
#
# The same argument as passes 9-17: a correctly set-up lane never reaches a
# refusal, so only a deliberately wrong invocation can notice one being
# deleted. Three passes, matching the three registered refusal lanes -- the
# decisions genuinely new in these files. The verbatim flag-block copies
# are deliberately not re-proven here; the launchers' own headers record
# what is and is not witnessed per copy.
function(byte_machine_slice5b_launcher_pass launcher_file lane label find replace)
  byte_machine_mutation_reset()

  string(JOIN "|" packed
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/${launcher_file}"
    ${ARGN})

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${CMAKE_COMMAND}"
    "-DBYTE_MACHINE_EXPECT_EXIT=2"
    "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
    -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

  byte_machine_mutation(
    FILE ${launcher_file} SPEC "${lane}"
    LABEL "${label}"
    FIND "${find}"
    REPLACE "${replace}")

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

byte_machine_slice5b_launcher_pass(
  test/support/launchers/chez-aot.ss
  byte-machine.harness.chez-aot-launcher-missing-program.chez.aot
  "chez-aot launcher: a missing compiled program is accepted"
  [[(if (not (file-exists? program))]]
  [[(if #f]]
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--source-guard" "${AOT_PASS_DIR}/source-guard"
  "--program" "${AOT_PASS_DIR}/no-such-program.so")

byte_machine_slice5b_launcher_pass(
  test/support/launchers/chez-aot.ss
  byte-machine.harness.chez-aot-launcher-dirty-source-guard.chez.aot
  "chez-aot launcher: a dirty source guard is accepted"
  [[(if (not (null? (directory-list source-guard-dir)))]]
  [[(if #f]]
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--object-dir" "${AOT_PASS_DIR}/src"
  "--source-guard" "${AOT_PASS_DIR}/harness"
  "--program" "${AOT_PASS_DIR}/harness-bootstrap.so")

byte_machine_slice5b_launcher_pass(
  test/support/launchers/chez-compile.ss
  byte-machine.harness.chez-compile-launcher-unpaired-roots.chez.aot
  "chez-compile launcher: unpaired roots are accepted"
  [[(if (not (= (length library-roots) (length object-dirs)))]]
  [[(if #f]]
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-dir" "${AOT_PASS_DIR}/harness"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps"
  "--output" "${AOT_PASS_DIR}/unpaired.so")
```

The dirty-source-guard pass reuses the object directory as its non-empty guard — it holds the pass-26 objects, which is enough, since the check counts entries, not kinds. Note pass 26 must run before 27–29 so `AOT_PASS_DIR` is populated. Run each once and narrow with `EXPECT_OUTPUT_MATCHES`/`EXPECT_STATUS` per the observed mutant outcome (the mutant either runs to some completion or dies out-of-vocabulary; both are legitimate evidence — passes 9–17's header records the doctrine).

- [ ] **Step 3: Correct the launcher headers**

In both launchers, the paragraph "The cost of the copy is that a flag-vocabulary decision fixed in one launcher … neither this file nor chez-aot.ss has a mutation of its own yet (MutationSuite.cmake and SchemeMutationSuite.cmake name chez-source.ss only). Mutating each copy separately is intended work for the slice that wires a real chez.aot lane, not a claim this commit can make." is now false. Replace its final two sentences in each file with (adjusting the named mutations per file):

```
;;; That independence is now partially witnessed: SchemeMutationSuite.cmake
;;; mutates this file's own refusals and decisions (passes 26-29 -- the
;;; library-path pairing and source-directories in chez-aot.ss; the
;;; missing-program, dirty-source-guard, and unpaired-roots refusals). The
;;; verbatim flag-block loops below those decisions remain witnessed only
;;; in chez-source.ss's copy; a defect introduced into one copy alone would
;;; not be caught here, and that residual is accepted, recorded here rather
;;; than left implied.
```

This is the vocabulary sweep in miniature (AGENTS.md: removing or outgrowing a concept means sweeping the comments that assert it).

- [ ] **Step 4: Update the declared totals**

`SchemeMutationSuite.cmake`: `EXPECTED_PASSES` **25 → 29**, `EXPECTED_MUTATIONS` **60 → 65** (pass 26: +2, passes 27–29: +1 each). Extend the header comment's arithmetic in its existing style.

- [ ] **Step 5: Run the Scheme mutation suite, then the whole suite**

```bash
ctest --preset pr -R 'scheme-mutation' --output-on-failure
make test
```

Expected: PASS, 29 passes / 65 mutations, C3b reported as a declared survivor with its reason, everything else caught for its declared reason. Then 37/37.

- [ ] **Step 6: Commit**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake test/support/launchers/chez-aot.ss test/support/launchers/chez-compile.ss
git commit -m "test: the aot launchers get mutations of their own"
```

---

### Task 6: W9 — the provenance decisions a one-source manifest cannot witness

Slice 5a's carried items 2–4 (design W9), in the trimmed form the superseded plan's Task 8 argued for and this plan keeps: the `|`-in-path and directory-refusal items stay cut (both guard inputs nobody has written, and both already fail loudly one layer down), the trimming/rendering mutations stay deferred (reachable from the provenance path without being part of it). What lands is the pair of decisions 5b's whole claim rides on — the manifest split character and the combining order — plus the structural survivor for the status constant. All three live in `harness.sls`'s `harness-verify-provenance!` and are invisible to every existing pass: passes 22–25 use a one-source manifest **because** `BYTE_MACHINE_EXPECT_COMMAND` packs with `|` (their own header says so), so nothing currently splits a separator or combines a list of two.

The way out is to not use the wrapper: these two mutations flip a *passing* provenance run (exit 0) to a mismatch (exit 3), so the plain lane command is its own verify — no exact-status wrapper, no `|` packing conflict, `EXPECT_STATUS 3` narrowing the catch.

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

- [ ] **Step 1: Write the pass**

Append after pass 29. Before writing the FIND texts, copy them verbatim from the shipped `test/support/harness/byte-machine/test/harness.sls` (at plan time: the split at its line 723, the combine at 726, the exit at 671 — re-check, Task 5 did not touch this file but the plan must not trust its own quotations):

```cmake
# --- Pass 30: the provenance decisions a one-source manifest cannot witness --
#
# Passes 22-25 pack their verify commands through BYTE_MACHINE_EXPECT_COMMAND,
# whose | packing forbids a multi-source manifest -- their manifests name one
# source on purpose, so the split character and the combining order have
# never had a witness. This pass runs the lane command bare: its baseline is
# a PASSING provenance run (exit 0), and each catchable mutation turns that
# into the mismatch refusal (exit 3), so no wrapper is needed and the
# two-source manifest rides in an ordinary env entry.
byte_machine_mutation_reset()

set(W9_MANIFEST
  "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls|${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls")
set(W9_EXPECT_FILE "${WORK_DIR}/w9-two-source.fingerprint")
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness"
          "${GUARD_DIR}"
          "${W9_EXPECT_FILE}"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/fingerprint.sls"
          "${STAGE_DIR}/test/support/harness/byte-machine/test/harness.sls"
  RESULT_VARIABLE w9_expect_rc)
if(NOT w9_expect_rc EQUAL 0)
  message(FATAL_ERROR
    "byte-machine-mutation: pass 30 could not compute its two-source "
    "expectation (rc ${w9_expect_rc}). The expectation must come from the "
    "staged copies -- the stage is what the run reads -- so nothing this "
    "pass reports would mean anything without it.")
endif()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${CMAKE_COMMAND}" "-E" "env"
  "BYTE_MACHINE_FINGERPRINT_FILES=${W9_MANIFEST}"
  "BYTE_MACHINE_EXPECT_FINGERPRINT_FILE=${W9_EXPECT_FILE}"
  "--"
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.sps")

set(RUNNER_BODY test/support/harness/byte-machine/test/harness.sls)

# The manifest arrives |-joined. Split on anything else and the whole
# two-source string is one path naming no file, so the run refuses with the
# unreadable-source diagnosis -- still 3, still caught, and the label says
# which decision died.
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: the manifest is split on the wrong character"
  FIND [[        (let loop ((rest (harness-split raw #\|)) (acc '()))]]
  REPLACE [[        (let loop ((rest (harness-split raw #\,)) (acc '()))]]
  EXPECT_STATUS 3)

# Combining is order-sensitive by design (slice 5a, mutation F5), so
# accumulating in reverse computes a different digest over the same bytes --
# visible only when there are at least two of them.
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: the manifest digests combine in reverse order"
  FIND [[                               (harness-fingerprint-combine (reverse acc)))))]]
  REPLACE [[                               (harness-fingerprint-combine acc))))]]
  EXPECT_STATUS 3)

# DECLARED SURVIVOR, structural. A provenance failure exiting 1 would be
# indistinguishable from an assertion failure -- the whole reason status 3
# was reserved -- so the constant deserves a mutation, and this suite cannot
# supply one: byte_machine_mutation_run requires the verify command to exit
# 0 on the staged unmutated tree, so no pass may deliberately fail
# provenance, and under a command whose provenance succeeds this line is
# never reached. Not a coverage gap for the decision, only for this suite:
# four provenance lanes in test/CMakeLists.txt and the stale-artifact lane
# assert exit 3 directly. Reopening condition: a mutation runner accepting
# a declared non-zero baseline.
byte_machine_mutation(
  FILE ${RUNNER_BODY} SPEC byte-machine.harness.provenance.chez.source
  LABEL "runner: a provenance failure exits as an assertion failure"
  FIND [[  (adapter-exit harness-status-provenance))]]
  REPLACE [[  (adapter-exit harness-status-failed))]]
  EXPECT_SURVIVES
    "unreached under any verify command this runner accepts: the baseline must exit 0, so provenance must succeed, so the provenance exit is never taken; the decision is witnessed by the five registered lanes that assert exit 3 directly. Reopening condition: a mutation runner accepting a declared non-zero baseline.")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

Confirm the baseline before trusting any row: run the suite once and check pass 30's baseline is green — an unmutated tree exiting 3 here means the expectation was computed over the wrong two files (the repository originals instead of the staged copies, or one file instead of two).

- [ ] **Step 2: Update the declared totals**

`EXPECTED_PASSES` **29 → 30**, `EXPECTED_MUTATIONS` **65 → 68**; extend the header arithmetic.

- [ ] **Step 3: Run the Scheme mutation suite, then the whole suite**

```bash
ctest --preset pr -R 'scheme-mutation' --output-on-failure
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS, 30/68, the survivor reported with its reason; then 37/37 and 8/8.

- [ ] **Step 4: Commit**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: the provenance decisions slice 5a left without a mutation"
```

---

### Task 7: The records — 0004's closure, D5, and the CHANGELOG

**Files:**
- Modify: `docs/decisions/0004-content-fingerprint-and-provenance.md`
- Modify: `docs/plans/milestone-0-portability-spike.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Amend decision record 0004**

The record's Consequences section ends with "The direction for closing it, small enough to record now: generate a Scheme file at build time holding the combined expectation as a literal, have the compiled wrapper `include` it…". That direction is doubly dead — W2/W3 superseded it by choice, and decision 0006 removed both the wrappers and the `include` mechanism it needed. Add a dated amendment note directly below that paragraph (keep the paragraph itself — the record's own header explains this file preserves history), stating:

- The gap is **closed by the slice 5b remainder**, by W2 rather than by the literal: a compiled lane's fingerprint is computed over copies written by the same build command that produced the artifact, while the expectation stays computed from the repository originals; a stale artifact carries stale copies, the two disagree, the lane exits 3, and `byte-machine.harness.stale-artifact.chez.aot` is the registered proof.
- 0004's stated objection ("one list, not two … nowhere to enter this tree today") was about `byte_machine_scheme_lane_command`'s signature, not a principle; the two-list split changed the signature, and the spec's declared-versus-measured cases now assert the asymmetry with no runtime present.
- W6's bound, stated plainly: the copies sit **beside** the artifact rather than inside it; one producer means they cannot be *separately* stale through the build, but a hand-disturbed build tree can desynchronise them. The literal-in-the-artifact direction was strictly stronger and is recorded as the reopening shape, noting its cost analysis is moot for the Gambit half (decision 0005) and unpaid for the Chez half.
- The include-timestamp sentence in the demonstration ("a body reached only through `include` has no timestamp of its own that anything consults") describes the include-era tree; the defect class survives 0006 in its general form — an artifact built before an edit, run after it — which is exactly what the staleness lane constructs and the aot `DEPENDS` list exists to prevent.

Re-measure every number before writing it. Do not copy a value from this plan or from the design document.

- [ ] **Step 2: Record D5's closure on the milestone plan**

`docs/plans/milestone-0-portability-spike.md` names deliverable D5. Add a dated note at its D5 entry (matching the amendment-note style 0005 established): D5 closes here, at the two Chez lanes — `chez.source` and `chez.aot` agreeing on one content fingerprint per manifest, with the staleness lane as the falsifiability proof — which is the weaker statement decision 0005 recorded when it cancelled slice 5c's four-lane form.

- [ ] **Step 3: Write the CHANGELOG entry**

Under `### Added`, in the unreleased section: a Chez ahead-of-time lane over three of the programs the source lanes run, compiled by a build step that writes the lane's measured `fingerprint/` copies in the same command; a fingerprint that therefore describes the text an artifact was built from rather than the text on disk when it ran; the lane that proves it can fail (built from a divergent fixture library, exits 3); and the mutations (state the final totals of both suites). State plainly what the mechanism does not prove: a lane is still not shown to touch exactly the files it names (0004 decision 2's bound, unchanged), and the copies sit beside the artifact rather than inside it (W6's bound).

- [ ] **Step 4: Run the whole suite one more time**

```bash
make test && make test-all && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: PASS — 37/37, 37/37, 8/8. Record the exact totals in the commit message.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/0004-content-fingerprint-and-provenance.md docs/plans/milestone-0-portability-spike.md CHANGELOG.md
git commit -m "docs: what a compiled lane's fingerprint now describes; D5 closes"
```

---

## Exit criteria for the slice

From design §9 (5b), adjusted by 0005's closure of D5 at two lanes; checked before opening a pull request:

- [ ] The three `chez.aot` lanes are green and verify against the **same** expectation files as their `chez.source` counterparts (same manifest digest — the cross-mode agreement is structural and was recorded in Task 1's commit).
- [ ] `byte-machine.harness.stale-artifact.chez.aot` exits exactly 3, with the mismatch diagnosis.
- [ ] C1, C2, C4, and the three shell mutations are caught by the lane specification; C3 is caught through the real pairing pass; C3b and the status-constant mutation are declared survivors carrying their measured/structural reasons.
- [ ] The `no-scheme` preset is **8/8**, and the measured-path computation is exercised under it (the two-source aot case in `ByteMachineSchemeLaneSpec.cmake` — W7).
- [ ] Both mutation suites assert their own totals and those totals match: CMake **1/72**, Scheme **30/68**.
- [ ] Cross-library identity holds on `chez.aot` (`placeholder-identity.chez.aot` green), discharging slice 4 §10 for Chez.
- [ ] Design §5.3 carries the remainder's re-measured addendum and §11 the build-cost number; 0004 carries the closure amendment; the milestone plan records D5 closed.
- [ ] The ledger's three carries are discharged: the aot command line is spec-asserted in full, `rg 'chez\.sps'` finds nothing in specs or source, and the aot-paths comment speaks in the present tense.
- [ ] Lane count 37 in `pr` and `release`; the four new lanes are the only registration delta.
