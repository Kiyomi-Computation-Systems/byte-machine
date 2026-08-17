# Milestone 0 Slice 3 — Shared Body Through Both Wrappers, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the first files in `src/`: one wrapper-free shared body included by exactly one thin library per runtime, exercised by one shared test body on both runtimes from three working directories chosen so each catches a different failure of the include mechanism.

**Architecture:** The Chez launcher moves from four positional arguments to repeatable flags, so a lane can name two library roots and two source directories. `src/common/byte-machine/placeholder.scm` is included by `placeholder.sls` (Chez, bare filename through launcher-set `source-directories`) and `placeholder.sld` (Gambit, source-relative path). `test/common/` holds the shared test body with its two wrappers beside it. Three configure-time fixture directories provide the working-directory matrix, and a launcher mutation makes that matrix fail in an asymmetric pattern the suite asserts, survivor included.

**Tech Stack:** Chez Scheme 10.4.1+ (R6RS `.sls`), Gambit 4.9.8+ (R7RS `.sld`), CMake 3.26+ / CTest, GNU Make as a thin convenience layer.

**Design spec:** [`milestone-0-slice-3-shared-body.md`](./milestone-0-slice-3-shared-body.md). Read it before starting. Section numbers referenced below are its.

## Global Constraints

- **Shared bodies use only the common R6RS/R7RS subset and must never name Chez or Gambit.** Forbidden in shared bodies: `define-record-type`, string ports, `error`, condition accessors, hash tables, sorting, `syntax-case`, `eval`, bytevector literals, and any library or include form. R6RS forbids assigning an exported variable — reach mutable state through procedures.
- **Exit statuses are exactly 0 (pass), 1 (assertion failed), 2 (harness error), 3 (reserved, unused).** Nothing else is a legal expectation.
- **Test names match `byte-machine.<layer>.<feature>.<backend>.<mode>`**, all lowercase, feature segment not starting or ending in a hyphen. Layers are the declared vocabulary in `cmake/ByteMachineTesting.cmake`; this slice uses `portability` for product-code lanes and `harness` for launcher lanes.
- **Every registration carries an explicit `TIMEOUT`.** There is no default.
- **Every new CMake decision gets a specification case in `test/support/cmake/` and a mutation that breaks it.** An uncaught mutation is a finding about the tests, not a reason to loosen it. `EXPECT_SURVIVES` is for the genuinely unwitnessable, with a written reason.
- **`ctest --preset no-scheme` must keep passing** with neither runtime installed. Every lane that needs a runtime is registered only when its runtime was discovered.
- **The type tag and the singleton in `placeholder.scm` are freshly allocated objects, never symbols** (spec §5.2). This is the one decision in the slice that another slice depends on.
- **Conventional Commits.** Run the tests before every commit. Do not commit anything under `build/`.

## File Structure

**Created:**

| Path | Responsibility |
| --- | --- |
| `src/common/byte-machine/placeholder.scm` | The wrapper-free shared body. Tagged vector plus one singleton. No library form, no include, no runtime-specific identifier. |
| `src/chez/byte-machine/placeholder.sls` | Chez owner library. Library form, imports, exports, include. Nothing else. |
| `src/gambit/byte-machine/placeholder.sld` | Gambit owner library. Same, with a source-relative include. |
| `test/common/placeholder-tests.scm` | Shared test body. Runs unchanged on both runtimes. |
| `test/common/placeholder-tests.chez.sps` | Chez wrapper: imports, `harness-begin`, include, `harness-finish`. |
| `test/common/placeholder-tests.gambit.scm` | Gambit wrapper: the same four things. |
| `docs/decisions/0002-shared-body-include-mechanism.md` | The measured mechanism facts and what they close. |

**Modified:**

| Path | Change |
| --- | --- |
| `test/support/launchers/chez-source.ss` | Repeatable-flag argument protocol: three parse decisions over a four-entry required-flag list, each with its own lane and its own mutation. |
| `cmake/ByteMachineSchemeLane.cmake` | Flag-based Chez command line, two roots per runtime, Gambit search-list builder that refuses a comma, `WORKING_DIRECTORY` forwarding. |
| `cmake/ByteMachineTesting.cmake` | Optional `WORKING_DIRECTORY` overriding the derived run directory. |
| `cmake/ByteMachineExpectExit.cmake` | Forward `WORKING_DIRECTORY`. |
| `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` | New command-line and comma-refusal cases. |
| `test/support/cmake/ByteMachineTestingSpec.cmake` | `WORKING_DIRECTORY` cases. |
| `test/support/cmake/MutationRunner.cmake` | Third axis: the verify command's working directory. |
| `test/support/cmake/MutationSuite.cmake` | Mutations for the new CMake decisions. |
| `test/support/cmake/SchemeMutationSuite.cmake` | Launcher verify commands updated; new passes for the launcher's parse decisions, the body on each runtime, and the asymmetric matrix mutation. |
| `test/CMakeLists.txt` | Source-tree path variables, widened guard call, matrix fixtures, new lanes. |
| `CHANGELOG.md` | Slice 3 entry. |

**Deleted:** `src/common/byte-machine/.gitkeep`, `src/chez/byte-machine/.gitkeep`, `src/gambit/byte-machine/.gitkeep`, `test/common/.gitkeep`.

---

### Task 1: The launcher takes flags

Everything else in this slice needs two library roots, and the launcher's fixed four-positional shape cannot express that. This task changes the protocol and every caller together, so the tree is green at the end. No new capability is used yet.

**Files:**
- Modify: `test/support/launchers/chez-source.ss` (rewrite)
- Modify: `cmake/ByteMachineSchemeLane.cmake` (Chez branch of `byte_machine_scheme_lane_command`)
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `test/CMakeLists.txt` (three hand-built launcher lanes, plus seven new refusal lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (verify commands only)

**Interfaces:**
- Consumes: `spec_check_equal`, `spec_expect_all_rejected`, `spec_finish` from `SpecSupport.cmake`; `byte_machine_add_exit_code_test` from `ByteMachineExpectExit.cmake`.
- Produces: launcher CLI `--library-root <dir>` (repeatable, ≥1), `--source-dir <dir>` (repeatable, ≥1), `--object-guard <dir>` (exactly once), `--program <path>` (exactly once). Every refusal exits 2 with a `byte-machine-launcher: HARNESS-ERROR ` prefix on stderr.

- [ ] **Step 1: Update the lane specification to expect the flag form**

In `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, replace the Chez command-line assertion:

```cmake
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;/h/chez;/h/shared;/b/guard;/h/self/p.chez.sps"
  "chez lane command line")

# The guard directory is the entire mechanism that stops a stale .so from being
# loaded in a lane that calls itself source. Asserted by position, because
# dropping it would leave a command that still runs.
list(GET command 5 guard)
spec_check_equal("${guard}" "/b/guard" "chez lane passes the object guard directory")
```

with:

```cmake
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;--library-root;/h/chez;--source-dir;/h/shared;--object-guard;/b/guard;--program;/h/self/p.chez.sps"
  "chez lane command line")

# The guard directory is the entire mechanism that stops a stale .so from being
# loaded in a lane that calls itself source. Asserted through its flag rather
# than by position: with a repeatable-flag protocol a position is no longer
# stable, and a lane that dropped the guard would still run.
list(FIND command "--object-guard" guard_index)
math(EXPR guard_value_index "${guard_index} + 1")
list(GET command "${guard_value_index}" guard)
spec_check_equal("${guard}" "/b/guard" "chez lane passes the object guard directory")
```

- [ ] **Step 2: Run the specification to verify it fails**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `chez lane command line: expected '...--library-root...', got '/opt/chez;--script;...'`.

- [ ] **Step 3: Rewrite the launcher**

Replace `test/support/launchers/chez-source.ss` entirely:

```scheme
;;; Chez source-mode launcher.
;;;
;;; Usage:
;;;   chez-source.ss --library-root <dir> [--library-root <dir> ...]
;;;                  --source-dir <dir>  [--source-dir <dir> ...]
;;;                  --object-guard <dir> --program <path>
;;;
;;; WHY FLAGS RATHER THAN POSITIONS
;;;
;;; A lane needs one library root per library family it imports and one source
;;; directory per shared-body directory, and both counts grow: slice 3 has two
;;; of each, slice 5's compiled lanes and Milestone 1's libraries add more. A
;;; positional protocol renumbers every caller at each of those steps. A
;;; separator-joined list was rejected outright: it would need a path separator
;;; that is `:` on Unix and `;` on Windows, which is the open question in
;;; milestone-0-portability-spike.md section 9, for no benefit here.
;;;
;;; THE OBJECT GUARD
;;;
;;; Chez looks for a library's compiled object only in the object half of a
;;; library-directories pair. Pairing every root with a directory the build
;;; keeps empty therefore makes a .so left beside the sources impossible to
;;; load, which is what lets this lane call itself "source" honestly. Pointing
;;; library-directories at the source roots alone would do the opposite: the
;;; object would be looked for next to the source and silently preferred.
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

;; --- the flag vocabulary ---------------------------------------------------
;;
;; required-flags is data, not control flow, so that dropping an entry is its
;; own defect with its own lane rather than a silent widening of what a valid
;; invocation looks like.

(define known-flags
  (list "--library-root" "--source-dir" "--object-guard" "--program"))

;; One per line, and in a different order from known-flags, so that each entry
;; is unique text in this file and can be removed by a mutation of its own.
;; Dropping an entry is a real defect with a real consequence -- an invocation
;; missing that flag stops being refused -- and it is invisible to every lane
;; but the one that omits it.
(define required-flags
  (list "--program"
        "--object-guard"
        "--library-root"
        "--source-dir"))

(define single-valued-flags
  (list "--object-guard" "--program"))

(define args (command-line-arguments))

;; Decision 1: every argument is a known flag followed by a value.
(let loop ((rest args))
  (cond ((null? rest) #t)
        ((not (member (car rest) known-flags))
         (die (string-append "unknown flag: " (car rest))))
        ((null? (cdr rest))
         (die (string-append "flag has no value: " (car rest))))
        (else (loop (cddr rest)))))

;; Safe only after decision 1: the list is known to be flag/value pairs.
(define (flag-values flag)
  (let loop ((rest args) (found (list)))
    (cond ((null? rest) (reverse found))
          ((string=? (car rest) flag) (loop (cddr rest) (cons (cadr rest) found)))
          (else (loop (cddr rest) found)))))

;; Decision 2: every required flag appears.
(for-each
 (lambda (flag)
   (if (null? (flag-values flag))
       (die (string-append "missing required flag: " flag))))
 required-flags)

;; Decision 3: a single-valued flag appears at most once. Last-one-wins would
;; silently run a different program, or guard a different directory, than the
;; command line says.
(for-each
 (lambda (flag)
   (if (> (length (flag-values flag)) 1)
       (die (string-append "flag given more than once: " flag))))
 single-valued-flags)

(define library-roots (flag-values "--library-root"))
(define source-dirs (flag-values "--source-dir"))
(define object-guard-dir (car (flag-values "--object-guard")))
(define program (car (flag-values "--program")))

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
;; the declared source directories. All of them are explicit: nothing resolves
;; against the current working directory, which is what the working-directory
;; matrix in test/CMakeLists.txt exists to keep true.
(source-directories (append source-dirs (list (path-directory program))))

;; Every root is paired with the same always-empty guard directory.
(library-directories
 (map (lambda (root) (cons root object-guard-dir)) library-roots))

(load-program program)
```

- [ ] **Step 4: Update the Chez lane command line**

In `cmake/ByteMachineSchemeLane.cmake`, replace the Chez `set(${out_command} ...)` block:

```cmake
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
```

with:

```cmake
    # Flags, not positions: a lane names one library root per library family it
    # imports and one source directory per shared-body directory, and both
    # counts grow with each slice.
    set(${out_command}
      "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
      "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
      "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
      "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
      "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
      "--program" "${program}"
      PARENT_SCOPE)
```

- [ ] **Step 5: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: `byte-machine-spec: ByteMachineSchemeLane verified`.

- [ ] **Step 6: Update the three hand-built launcher lanes**

In `test/CMakeLists.txt`, inside the `if(BYTE_MACHINE_CHEZ_EXECUTABLE)` block, the three `byte_machine_add_exit_code_test` calls spell out their own command lines. Rewrite their `COMMAND` blocks to the flag form. The usage lane changes meaning — it is now a launcher invoked with no arguments at all — so rename it too:

```cmake
  # A launcher invoked with nothing at all. Replaces the exact-arity refusal the
  # positional protocol had; with flags, "no arguments" is the natural form of
  # the same mistake.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-program.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red)

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-absent-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_ABSENT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-dirty-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_DIRTY_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")
```

- [ ] **Step 7: Add the six remaining refusal lanes**

Immediately after the three above, still inside the `if(BYTE_MACHINE_CHEZ_EXECUTABLE)` block:

```cmake
  # One lane per parse decision. A correctly set-up lane never reaches a
  # refusal, so nothing else in this tree can notice one being deleted. Each
  # names a real program where it can, so that deleting the refusal produces a
  # lane that runs and exits 0 rather than one that fails for another reason.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-unknown-flag.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--librarie-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  # A trailing flag. Without this refusal it would mean "no program" and be
  # reported as a missing required flag, sending the reader to the wrong line.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-missing-value.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red)

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-repeated-flag.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  # The three remaining required-flag entries. Each is a separate lane because
  # required-flags is a list: an entry dropped from it is invisible to every
  # lane but the one that omits that flag.
  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-library-root.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-source-dir.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")

  byte_machine_add_exit_code_test(
    NAME byte-machine.harness.launcher-no-object-guard.chez.source
    COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
            "--script" "${BYTE_MACHINE_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
            "--program" "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-bootstrap.chez.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "BYTE_MACHINE_EXECUTION_MODE=source")
```

- [ ] **Step 8: Update the mutation suite's verify commands**

In `test/support/cmake/SchemeMutationSuite.cmake`, the passes drive the launcher directly. Replace the shared verify command:

```cmake
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "${STAGE_DIR}/test/support/harness/chez"
  "${STAGE_DIR}/test/support/harness/shared"
  "${GUARD_DIR}"
  "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")
```

with:

```cmake
set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")
```

Then find every other `set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND ...)` in the file — the passes for the bootstrap lane, the empty-selection lane, the Gambit lane, and the three launcher refusals — and convert each to the same flag form. The Gambit pass is unaffected in shape; only the Chez ones change. Grep afterwards to be sure none was missed:

```bash
rg -n 'chez-source.ss' test/support/cmake/SchemeMutationSuite.cmake
```

Every hit must be followed by `--library-root` on the next line, except the three refusal passes, whose command lines are deliberately wrong in one way each.

- [ ] **Step 9: Build and run the whole suite**

```bash
make test
```

Expected: all tests pass, including the six new `expected-red` launcher lanes and the renamed `launcher-no-program`.

- [ ] **Step 10: Verify the no-scheme preset still configures and runs**

```bash
cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: pass. The launcher lanes are inside `if(BYTE_MACHINE_CHEZ_EXECUTABLE)` and are simply not registered.

- [ ] **Step 11: Commit**

```bash
git add test/support/launchers/chez-source.ss cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/support/cmake/SchemeMutationSuite.cmake test/CMakeLists.txt
git commit -m "refactor: launcher takes repeatable flags instead of four positions"
```

---

### Task 2: The placeholder library, on both runtimes

**Files:**
- Create: `src/common/byte-machine/placeholder.scm`
- Create: `src/chez/byte-machine/placeholder.sls`
- Create: `src/gambit/byte-machine/placeholder.sld`
- Create: `test/common/placeholder-tests.scm`
- Create: `test/common/placeholder-tests.chez.sps`
- Create: `test/common/placeholder-tests.gambit.scm`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `test/CMakeLists.txt`
- Delete: the four `.gitkeep` files listed in File Structure

**Interfaces:**
- Consumes: the flag protocol from Task 1; `harness-begin`, `harness-finish`, `harness-group`, `harness-case`, `check`, `check-equal` from `(byte-machine test harness)`.
- Produces: library `(byte-machine placeholder)` exporting `make-placeholder`, `placeholder?`, `placeholder-value`, `placeholder-marker`. CMake variables `BYTE_MACHINE_SRC_COMMON_DIR`, `BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT`, `BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT`, `BYTE_MACHINE_TEST_COMMON_DIR`, read by `byte_machine_scheme_lane_command`.

- [ ] **Step 1: Extend the lane specification to expect both roots**

In `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, add the new path variables beside the existing fixture paths:

```cmake
set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "/s/chez")
set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "/s/gambit")
set(BYTE_MACHINE_SRC_COMMON_DIR "/s/common/byte-machine")
```

Replace the Chez and Gambit command-line assertions with:

```cmake
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;--library-root;/h/chez;--library-root;/s/chez;--source-dir;/h/shared;--source-dir;/s/common/byte-machine;--object-guard;/b/guard;--program;/h/self/p.chez.sps"
  "chez lane command line")
```

```cmake
spec_check_equal("${command}"
  "/opt/gsi;-:search=/h/gambit,search=/s/gambit;-f;/h/self/p.gambit.scm"
  "gambit lane command line")
```

and update the `first_option` assertion to match:

```cmake
list(GET command 1 first_option)
spec_check_equal("${first_option}" "-:search=/h/gambit,search=/s/gambit"
  "gambit runtime option comes first")
```

- [ ] **Step 2: Run the specification to verify it fails**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL on both command-line assertions — the second root is absent from each.

- [ ] **Step 3: Add both roots to the lane command**

In `cmake/ByteMachineSchemeLane.cmake`, the Chez branch:

```cmake
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
```

and the Gambit branch:

```cmake
    # `-:` runtime options must be the first argument, and the option list is
    # comma-separated: `search=A,search=B` puts two module roots on the path.
    # Measured, with a control proving the second root is load-bearing
    # (docs/plans/milestone-0-slice-3-shared-body.md section 2).
    # `-f` skips .gambini so a developer's personal initialisation cannot change
    # what a test proves. No launcher is needed: Gambit's include inside
    # define-library is source-file-relative and needs no ambient state.
    set(${out_command}
      "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
      "-:search=${BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT},search=${BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT}"
      "-f"
      "${program}"
      PARENT_SCOPE)
```

- [ ] **Step 4: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: `byte-machine-spec: ByteMachineSchemeLane verified`.

- [ ] **Step 5: Write the shared test body**

Create `test/common/placeholder-tests.scm`:

```scheme
;;; Shared tests for (byte-machine placeholder).
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only. This file is run
;;; unchanged on both runtimes through the two wrappers beside it, which is what
;;; makes it a parity proof rather than two similar test suites: a name missing
;;; from either owner library is a load failure on that runtime, not a silent
;;; gap.
;;;
;;; Cross-library identity is slice 4's proof and is not attempted here. What
;;; this body asserts about the marker is only that it is one object, which is
;;; what a fresh allocation buys and an interned symbol would have given for
;;; free.

(harness-group "placeholder"
  (lambda ()

    (harness-case "a constructed placeholder round-trips its value"
      (lambda ()
        (check-equal "value survives construction"
                     (placeholder-value (make-placeholder 7))
                     7)))

    (harness-case "placeholder? recognises what make-placeholder built"
      (lambda ()
        (check "recognised" (placeholder? (make-placeholder 7)))))

    (harness-case "placeholder? rejects a value that is not a vector"
      (lambda ()
        (check "an integer is not a placeholder" (not (placeholder? 7)))))

    (harness-case "placeholder? rejects a same-shaped vector with a symbol tag"
      (lambda ()
        ;; The executable form of the rule in placeholder.scm's header. The tag
        ;; is a freshly allocated vector precisely so that a symbol spelled like
        ;; it is not it; if the tag ever becomes a symbol, this case fails, and
        ;; with it the representation slice 4's identity test depends on.
        (check "a symbol spelled like the tag is not the tag"
               (not (placeholder? (vector 'byte-machine-placeholder 7))))))

    (harness-case "the marker is one object"
      (lambda ()
        (check "eq? to itself across two calls"
               (eq? (placeholder-marker) (placeholder-marker)))))))
```

- [ ] **Step 6: Write both test wrappers**

Create `test/common/placeholder-tests.chez.sps`:

```scheme
;;; Chez wrapper for the placeholder tests. Runtime-specific only in its imports.

(import (rnrs)
        (byte-machine test harness)
        (byte-machine placeholder)
        (only (chezscheme) include))

(harness-begin "portability.placeholder")

(include "placeholder-tests.scm")

(harness-finish)
```

Create `test/common/placeholder-tests.gambit.scm`:

```scheme
;;; Gambit wrapper for the placeholder tests. Runtime-specific only in its imports.

(import (scheme base)
        (scheme write)
        (byte-machine test harness)
        (byte-machine placeholder))

(harness-begin "portability.placeholder")

(include "placeholder-tests.scm")

(harness-finish)
```

- [ ] **Step 7: Register the two lanes**

In `test/CMakeLists.txt`, add the source-tree path variables next to the existing `# --- Harness paths ---` block:

```cmake
# --- Source tree paths -----------------------------------------------------
#
# Read by byte_machine_scheme_lane_command. src/ holds the product libraries;
# the harness above is test infrastructure. A lane imports from both, which is
# why the launcher takes repeatable roots.
set(BYTE_MACHINE_SRC_COMMON_DIR "${CMAKE_SOURCE_DIR}/src/common/byte-machine")
set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src/chez")
set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src/gambit")
set(BYTE_MACHINE_TEST_COMMON_DIR "${CMAKE_CURRENT_LIST_DIR}/common")
```

and, at the end of the file's lane section, the two lanes:

```cmake
# --- The placeholder library -----------------------------------------------
#
# One shared body, one owner library per runtime, one shared test body. The
# working directories these run from are what slice 3 is actually about; they
# arrive in the next task, and until then both run from the default private run
# directory.
byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.chez.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.gambit.scm"
  TIMEOUT 120)
```

- [ ] **Step 8: Run the two lanes and watch them fail for the right reason**

```bash
make build && ctest --preset pr -R 'byte-machine\.portability\.placeholder' --output-on-failure
```

Expected: both FAIL. Chez reports a library `(byte-machine placeholder)` it cannot find; Gambit reports `Cannot find library (byte-machine placeholder)` and exits 70. If either fails with a *different* message — a missing `placeholder-tests.scm`, say — fix that before continuing: the red must be the absence of the library, not of the test.

- [ ] **Step 9: Write the shared body**

Create `src/common/byte-machine/placeholder.scm`:

```scheme
;;; Placeholder body for the Milestone 0 portability proof.
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only. No library form, no
;;; include, no runtime-specific identifier. Included by exactly one library per
;;; runtime: src/chez/byte-machine/placeholder.sls and
;;; src/gambit/byte-machine/placeholder.sld.
;;;
;;; This carries no byte-machine semantics and is deleted in Milestone 1
;;; (milestone-0-portability-spike.md, decision D4). It exists to prove that one
;;; body loads through both wrappers, and to give slice 4 a value whose identity
;;; can be compared across a library boundary.
;;;
;;; THE TAG AND THE MARKER ARE FRESHLY ALLOCATED, NEVER SYMBOLS
;;;
;;; Symbols are interned, so (eq? 'x 'x) is true however many separate copies of
;;; this body produced those two occurrences. A symbol tag would make the
;;; double-include defect that the implementation plan's section 7.2 forbids
;;; structurally invisible: two libraries that had each included this body would
;;; recognise each other's values, and slice 4's identity test would pass
;;; against exactly the tree the rule exists to prevent. A freshly allocated
;;; vector gives a second include a second tag, so the second library rejects
;;; the first's values and the defect is caught.
;;;
;;; test/common/placeholder-tests.scm holds the executable form of this rule.

(define placeholder-tag (vector 'byte-machine-placeholder))

(define placeholder-marker-object (vector 'byte-machine-marker))

(define (make-placeholder value)
  (vector placeholder-tag value))

;; Three decisions, deliberately not folded into one: each is broken by its own
;; mutation in SchemeMutationSuite.cmake, on each runtime.
(define (placeholder? x)
  (and (vector? x)
       (= (vector-length x) 2)
       (eq? (vector-ref x 0) placeholder-tag)))

(define (placeholder-value p)
  (vector-ref p 1))

;; Allocation-free: the object is built once, when this body is loaded, and
;; every call returns that same object.
(define (placeholder-marker)
  placeholder-marker-object)
```

- [ ] **Step 10: Write both owner libraries**

Create `src/chez/byte-machine/placeholder.sls`:

```scheme
;;; Chez owner library for the placeholder body.
;;;
;;; A library form, imports, exports, and the include. Nothing else: any
;;; semantics here would be semantics the shared body no longer owns, and the
;;; body mutations in SchemeMutationSuite.cmake exist to catch exactly that.
;;;
;;; The body is included by bare filename and resolved through Chez's
;;; source-directories, which the launcher sets. That keeps absolute paths out
;;; of the source tree and keeps the include independent of the working
;;; directory.

(library (byte-machine placeholder)
  (export make-placeholder placeholder? placeholder-value placeholder-marker)
  (import (rnrs) (only (chezscheme) include))
  (include "placeholder.scm"))
```

Create `src/gambit/byte-machine/placeholder.sld`:

```scheme
;;; Gambit owner library for the placeholder body.
;;;
;;; A library form, imports, exports, and the include. Nothing else, for the
;;; reason given in the Chez counterpart.
;;;
;;; The body is included by a path relative to this file, which is how Gambit
;;; resolves include inside define-library. Chez resolves the same body by bare
;;; filename through its launcher's source-directories. That difference is the
;;; one place the two mechanisms are visibly not the same, and it is why a
;;; staged copy for mutation testing must preserve this relative layout rather
;;; than flatten it.

(define-library (byte-machine placeholder)
  (export make-placeholder placeholder? placeholder-value placeholder-marker)
  (import (scheme base))
  (include "../../common/byte-machine/placeholder.scm"))
```

- [ ] **Step 11: Run the two lanes and watch them pass**

```bash
make build && ctest --preset pr -R 'byte-machine\.portability\.placeholder' --output-on-failure
```

Expected: both PASS, each reporting 5 cases.

- [ ] **Step 12: Widen the portability guard**

In `test/CMakeLists.txt`, replace the guard call:

```cmake
byte_machine_portability_guard(
  SHARED_DIRS "${BYTE_MACHINE_HARNESS_SHARED_DIR}"
  WRAPPED_DIRS "${BYTE_MACHINE_HARNESS_SELF_DIR}")
```

with:

```cmake
# src/common holds bodies included by a library, so they owe no program
# wrapper; test/common holds bodies included by a program, so each owes both.
# Every body from either kind of directory shares one basename namespace, which
# now spans the harness and src/ for the first time.
byte_machine_portability_guard(
  SHARED_DIRS "${BYTE_MACHINE_HARNESS_SHARED_DIR}" "${BYTE_MACHINE_SRC_COMMON_DIR}"
  WRAPPED_DIRS "${BYTE_MACHINE_HARNESS_SELF_DIR}" "${BYTE_MACHINE_TEST_COMMON_DIR}")
```

- [ ] **Step 13: Confirm the guard is live, by making it fail on purpose**

```bash
mv src/common/byte-machine/placeholder.scm /tmp/placeholder.scm.bak && cmake --preset dev
```

Expected: configure FAILS with `contributed no shared body: .../src/common/byte-machine`. Then restore and reconfigure:

```bash
mv /tmp/placeholder.scm.bak src/common/byte-machine/placeholder.scm && cmake --preset dev
```

Expected: `byte-machine portability guard: 7 shared bodies, unique basenames, every wrapped body paired`.

- [ ] **Step 14: Delete the placeholder .gitkeep files**

```bash
git rm src/common/byte-machine/.gitkeep src/chez/byte-machine/.gitkeep src/gambit/byte-machine/.gitkeep test/common/.gitkeep
```

- [ ] **Step 15: Run the whole suite and the no-scheme preset**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: both pass.

- [ ] **Step 16: Commit**

```bash
git add src test/common cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/CMakeLists.txt
git commit -m "feat: one shared body through both owner libraries"
```

---

### Task 3: A comma in a Gambit search root is a configure error

**Files:**
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`
- Modify: `test/support/cmake/MutationSuite.cmake`

**Interfaces:**
- Produces: `byte_machine_scheme_lane_gambit_search(<out_option> <out_status> <out_message> <dir>...)` — status `ok` or `comma-in-path`.

- [ ] **Step 1: Write the failing specification**

In `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, add to the driver, just after the Gambit command-line assertions:

```cmake
# --- The Gambit search list ------------------------------------------------
#
# Gambit's -: options are comma-separated, so a search root containing a comma
# does not produce a wrong path: gsi prints its runtime-options usage banner and
# runs no Scheme at all, naming nothing this project owns. Measured on
# 2026-08-16; see docs/plans/milestone-0-slice-3-shared-body.md section 2.
byte_machine_scheme_lane_gambit_search(option status message "/a" "/b")
spec_check_equal("${status}" "ok" "two roots are accepted")
spec_check_equal("${option}" "-:search=/a,search=/b" "two roots join with a comma")

byte_machine_scheme_lane_gambit_search(option status message "/a")
spec_check_equal("${option}" "-:search=/a" "one root needs no separator")

byte_machine_scheme_lane_gambit_search(option status message "/a" "/b,c")
spec_check_equal("${status}" "comma-in-path" "a comma in a root is rejected")
spec_check_equal("${option}" "" "a rejected search list yields no option")
spec_check_equal("${message}"
  "a Gambit search root must not contain a comma, but '/b,c' does. Gambit's -: options are comma-separated, so gsi would print its usage banner and run no Scheme at all."
  "comma rejection message")

# Seeded, so a function that never writes its message is distinguishable from
# one that clears it.
set(message "seed")
byte_machine_scheme_lane_gambit_search(option status message "/a")
spec_check_equal("${message}" "" "an accepted search list clears the message")
```

Add a rejection case to the `BYTE_MACHINE_SPEC_CASE` dispatch, before its `else()`:

```cmake
  elseif(c STREQUAL "lane-rejects-comma-in-gambit-root")
    set(BYTE_MACHINE_GAMBIT_EXECUTABLE "/opt/gsi")
    set(BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT "/h/gam,bit")
    set(BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT "/s/gambit")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.gambit.source
      BACKEND gambit
      PROGRAM "${SPEC_SELF}"
      TIMEOUT 10)
```

and add it to the `spec_expect_all_rejected` list at the end of the file:

```cmake
  "lane-rejects-comma-in-gambit-root|must not contain a comma"
```

- [ ] **Step 2: Run the specification to verify it fails**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: FAIL — `Unknown CMake command "byte_machine_scheme_lane_gambit_search"`.

- [ ] **Step 3: Write the function and call it**

In `cmake/ByteMachineSchemeLane.cmake`, add to the functional core, above `byte_machine_scheme_lane_command`:

```cmake
# byte_machine_scheme_lane_gambit_search(<out_option> <out_status> <out_message>
#                                        <dir>...)
#
# Build Gambit's `-:` runtime-option argument putting every <dir> on the module
# search path. Status is `ok` or `comma-in-path`.
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
    list(APPEND parts "search=${dir}")
  endforeach()

  list(JOIN parts "," joined)
  set(${out_option} "-:${joined}" PARENT_SCOPE)
  set(${out_status} "ok" PARENT_SCOPE)
endfunction()
```

In the Gambit branch of `byte_machine_scheme_lane_command`, replace the hand-built `-:search=...` string:

```cmake
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
```

In `byte_machine_add_scheme_lane`, make the new status fatal alongside `unknown-backend`:

```cmake
  if(status STREQUAL "unknown-backend" OR status STREQUAL "comma-in-path")
    message(FATAL_ERROR "byte-machine: ${message}")
  endif()
```

- [ ] **Step 4: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```

Expected: `byte-machine-spec: ByteMachineSchemeLane verified`.

- [ ] **Step 5: Add the mutations**

In `test/support/cmake/MutationSuite.cmake`, beside the other `ByteMachineSchemeLane.cmake` mutations:

```cmake
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: a comma in a Gambit search root is accepted"
  FIND [[    if(dir MATCHES ",")]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: the search roots are joined with the wrong separator"
  FIND [[  list(JOIN parts "," joined)]]
  REPLACE [[  list(JOIN parts ";" joined)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "lane: a comma-in-path status does not stop registration"
  FIND [[  if(status STREQUAL "unknown-backend" OR status STREQUAL "comma-in-path")]]
  REPLACE [[  if(status STREQUAL "unknown-backend")]])
```

- [ ] **Step 6: Run the mutation suite**

```bash
ctest --preset pr -R 'byte-machine\.harness\.cmake-mutation' --output-on-failure
```

Expected: PASS, with the three new mutations reported caught.

- [ ] **Step 7: Commit**

```bash
git add cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineSchemeLaneSpec.cmake test/support/cmake/MutationSuite.cmake
git commit -m "feat: refuse a Gambit search root containing a comma"
```

---

### Task 4: The working-directory matrix

**Files:**
- Modify: `cmake/ByteMachineTesting.cmake`
- Modify: `cmake/ByteMachineExpectExit.cmake`
- Modify: `cmake/ByteMachineSchemeLane.cmake`
- Modify: `test/support/cmake/ByteMachineTestingSpec.cmake`
- Modify: `test/support/cmake/MutationSuite.cmake`
- Modify: `test/CMakeLists.txt`

**Interfaces:**
- Produces: optional `WORKING_DIRECTORY <dir>` on `byte_machine_add_test`, `byte_machine_add_exit_code_test`, and `byte_machine_add_scheme_lane`. CMake variables `BYTE_MACHINE_CWD_IDENTICAL_DIR`, `BYTE_MACHINE_CWD_DECOY_DIR`, `BYTE_MACHINE_CWD_EMPTY_DIR`.

- [ ] **Step 1: Write the failing specification**

The decision — which directory a registration ends up using — goes in the functional core, not the shell. `byte_machine_add_test` is the imperative shell: it calls `add_test`, which is not scriptable under `cmake -P`, and it creates directories, so a specification that drove it would leave `test-run/` litter wherever it was run. The module's own header documents this core/shell split; follow it.

Add to the driver of `test/support/cmake/ByteMachineTestingSpec.cmake`:

```cmake
# --- The run directory ------------------------------------------------------
#
# Which directory a lane launches from is a decision, and slice 3 is the first
# code to depend on being able to change it. Specified against the pure function
# rather than through byte_machine_add_test: the registrar calls add_test, which
# script mode does not have, and creates directories, which a specification must
# not do to whatever tree it happens to be run from.
byte_machine_test_run_directory("byte-machine.harness.example.cmake.direct" "" derived)
spec_check_equal("${derived}" "${CMAKE_BINARY_DIR}/test-run/byte-machine.harness.example.cmake.direct"
  "with no override, the run directory is derived from the test name")

byte_machine_test_run_directory("byte-machine.harness.example.cmake.direct" "/some/where" chosen)
spec_check_equal("${chosen}" "/some/where" "an override is used verbatim")

# The empty string is the shape a caller that omitted WORKING_DIRECTORY produces,
# and it must mean "derive", not "launch from the filesystem root".
byte_machine_test_run_directory("byte-machine.harness.other.cmake.direct" "" empty_override)
spec_check_equal("${empty_override}" "${CMAKE_BINARY_DIR}/test-run/byte-machine.harness.other.cmake.direct"
  "an empty override still derives, and derives from this name")
```

Then the existence check, which is I/O and stays in the shell. Add a rejection case to the `BYTE_MACHINE_SPEC_CASE` dispatch, stubbing the two project-context commands first if the file does not already stub them — put these immediately after `set(c "${BYTE_MACHINE_SPEC_CASE}")`:

```cmake
  # add_test and set_tests_properties belong to a project context this script
  # does not have. Stubbing both lets the registrar's own validation be
  # exercised: without it a case would die on that unrelated error instead of
  # falling through to the "must be rejected" check.
  function(add_test)
  endfunction()
  function(set_tests_properties)
  endfunction()
```

Then the case:

```cmake
  if(c STREQUAL "registration-rejects-absent-working-directory")
    byte_machine_add_test(
      NAME byte-machine.harness.example.cmake.direct
      COMMAND "/bin/true"
      TIMEOUT 10
      WORKING_DIRECTORY "/there/is/no/such/directory")
```

(If the file's dispatch already opens with `if(c STREQUAL ...)`, add this as another `elseif` branch instead.)

Add it to the file's `spec_expect_all_rejected` list:

```cmake
  "registration-rejects-absent-working-directory|is not an existing directory"
```

- [ ] **Step 2: Run the specification to verify it fails**

```bash
cmake -P test/support/cmake/ByteMachineTestingSpec.cmake
```

Expected: FAIL — `case 'registration-rejects-absent-working-directory' exited 0 but must be rejected`.

- [ ] **Step 3: Implement the override**

In `cmake/ByteMachineTesting.cmake`, add the pure function to the functional core, beside the other pure decisions:

```cmake
# byte_machine_test_run_directory(<name> <override> <out_dir>)
#
# Where a lane launches from. Empty override means the derived private
# directory, which is the default precisely because Chez once resolved includes
# against the process working directory: a test allowed to run from the
# repository could load a body the build never staged, and would keep passing
# after that body stopped being staged correctly.
#
# A lane that overrides this is making a claim about where resolution happens,
# which is what the working-directory matrix in test/CMakeLists.txt exists to
# check. Pure, so that the choice can be specified without registering a test or
# creating a directory.
function(byte_machine_test_run_directory name override out_dir)
  if(override)
    set(${out_dir} "${override}" PARENT_SCOPE)
    return()
  endif()
  set(${out_dir} "${CMAKE_BINARY_DIR}/test-run/${name}" PARENT_SCOPE)
endfunction()
```

Add `WORKING_DIRECTORY` to the single-value keywords:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "NAME;TIMEOUT;WORKING_DIRECTORY" "COMMAND;LABELS;ENVIRONMENT")
```

Replace the existing `run_dir` / `tmp_dir` block with one that asks the core, keeping the temporary directory derived either way:

```cmake
  # The temporary directory is always the derived one: a test that writes
  # scratch files must not be able to disturb a directory it was pointed at to
  # make a claim about resolution.
  set(tmp_dir "${CMAKE_BINARY_DIR}/test-run/${arg_NAME}/tmp")
  file(MAKE_DIRECTORY "${tmp_dir}")

  # The directory must exist. CTest reports a missing working directory as a
  # failure to launch, which the exact-status helper classifies as `did-not-run`
  # -- correct, but it points at the runtime rather than at the registration
  # that named a directory nobody created.
  if(arg_WORKING_DIRECTORY AND NOT IS_DIRECTORY "${arg_WORKING_DIRECTORY}")
    message(FATAL_ERROR
      "byte-machine: '${arg_NAME}' was given WORKING_DIRECTORY "
      "'${arg_WORKING_DIRECTORY}', which is not an existing directory. A lane "
      "that overrides its working directory is asserting something about where "
      "resolution happens, so the directory has to be one the build made on "
      "purpose.")
  endif()

  byte_machine_test_run_directory("${arg_NAME}" "${arg_WORKING_DIRECTORY}" run_dir)
  file(MAKE_DIRECTORY "${run_dir}")
```

- [ ] **Step 4: Forward it from both registrars**

In `cmake/ByteMachineExpectExit.cmake`, add `WORKING_DIRECTORY` to the parse keywords of `byte_machine_add_exit_code_test` and pass it through:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "NAME;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY" "COMMAND;LABELS;ENVIRONMENT")
```

```cmake
  byte_machine_add_test(
    NAME "${arg_NAME}"
    COMMAND "${CMAKE_COMMAND}"
            "-DBYTE_MACHINE_EXPECT_EXIT=${arg_EXPECT_EXIT}"
            "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_FILE}"
    TIMEOUT "${arg_TIMEOUT}"
    LABELS ${arg_LABELS}
    WORKING_DIRECTORY "${arg_WORKING_DIRECTORY}"
    ENVIRONMENT ${arg_ENVIRONMENT})
```

The runner itself needs no change: its `execute_process` has no `WORKING_DIRECTORY`, so the child inherits the one CTest set for this process.

In `cmake/ByteMachineSchemeLane.cmake`, do the same for `byte_machine_add_scheme_lane`:

```cmake
  cmake_parse_arguments(PARSE_ARGV 0 arg ""
    "NAME;BACKEND;PROGRAM;TIMEOUT;EXPECT_EXIT;WORKING_DIRECTORY" "LABELS;ENVIRONMENT")
```

and add `WORKING_DIRECTORY "${arg_WORKING_DIRECTORY}"` to both the `byte_machine_add_exit_code_test` and the `byte_machine_add_test` calls at the end of the function.

- [ ] **Step 5: Run the specification to verify it passes**

```bash
cmake -P test/support/cmake/ByteMachineTestingSpec.cmake
```

Expected: `byte-machine-spec: ByteMachineTesting verified`.

- [ ] **Step 6: Build the three matrix directories**

In `test/CMakeLists.txt`, after the source-tree path variables from Task 2:

```cmake
# --- The working-directory matrix ------------------------------------------
#
# Three directories, each catching a different failure of the include
# mechanism. Under a correct mechanism all three lanes pass and the decoy is
# simply ignored, so the matrix proves nothing on its own: what proves it is the
# launcher mutation in SchemeMutationSuite.cmake, whose expected outcome is
# asymmetric -- empty and decoy fail, identical passes.
#
# Both non-empty directories carry a copy of EVERY body the lane includes, the
# harness runner included. A directory holding only a placeholder body would
# fail to build (byte-machine test harness) under that mutation, before reaching
# the code under test, and all three lanes would fail identically -- destroying
# the only evidence that the lanes differ.
#
# They live in the build tree, which keeps intact byte_machine_add_test's rule
# that a test never runs from the repository. They cannot be checked in in any
# case: they share basenames with real bodies on purpose, and the portability
# guard forbids exactly that.
set(BYTE_MACHINE_CWD_MATRIX_DIR "${CMAKE_BINARY_DIR}/cwd-matrix")
set(BYTE_MACHINE_CWD_IDENTICAL_DIR "${BYTE_MACHINE_CWD_MATRIX_DIR}/same-name-identical")
set(BYTE_MACHINE_CWD_DECOY_DIR "${BYTE_MACHINE_CWD_MATRIX_DIR}/same-name-decoy")
set(BYTE_MACHINE_CWD_EMPTY_DIR "${BYTE_MACHINE_CWD_MATRIX_DIR}/empty")
file(MAKE_DIRECTORY "${BYTE_MACHINE_CWD_IDENTICAL_DIR}")
file(MAKE_DIRECTORY "${BYTE_MACHINE_CWD_DECOY_DIR}")
file(MAKE_DIRECTORY "${BYTE_MACHINE_CWD_EMPTY_DIR}")

# COPYONLY rather than file(COPY): configure_file records a dependency, so
# editing a body re-runs configure and refreshes the copies.
configure_file("${BYTE_MACHINE_SRC_COMMON_DIR}/placeholder.scm"
               "${BYTE_MACHINE_CWD_IDENTICAL_DIR}/placeholder.scm" COPYONLY)
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm"
               "${BYTE_MACHINE_CWD_IDENTICAL_DIR}/harness-runner.scm" COPYONLY)
configure_file("${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm"
               "${BYTE_MACHINE_CWD_DECOY_DIR}/harness-runner.scm" COPYONLY)

# The impostor. It implements the complete export list on purpose: an
# incomplete one would fail the lane at library construction, which is a
# different failure. The claim under test is that resolution picked the wrong
# file, and that is only tested if the wrong file would otherwise work.
file(WRITE "${BYTE_MACHINE_CWD_DECOY_DIR}/placeholder.scm"
";;; Impostor placeholder body. Not part of the product.
;;;
;;; Shares a basename with src/common/byte-machine/placeholder.scm and answers
;;; every question wrongly. It is only ever reachable by an include that
;;; resolved against the process working directory, which is the defect
;;; byte-machine.portability.placeholder-cwd-decoy.* exists to catch.

(define (make-placeholder value) (vector 'decoy value))
(define (placeholder? x) #f)
(define (placeholder-value p) 'decoy)
(define (placeholder-marker) (vector 'decoy))
")
```

- [ ] **Step 7: Replace the two plain lanes with six**

In `test/CMakeLists.txt`, delete the two `byte-machine.portability.placeholder.{chez,gambit}.source` registrations from Task 2 and put this in their place:

```cmake
# --- The placeholder library, from three working directories ---------------
#
# Same program, same body, three launch directories. See the matrix comment
# above for what each one catches and why passing here is not yet evidence.
foreach(cwd_case identical decoy empty)
  if(cwd_case STREQUAL "identical")
    set(cwd_dir "${BYTE_MACHINE_CWD_IDENTICAL_DIR}")
  elseif(cwd_case STREQUAL "decoy")
    set(cwd_dir "${BYTE_MACHINE_CWD_DECOY_DIR}")
  else()
    set(cwd_dir "${BYTE_MACHINE_CWD_EMPTY_DIR}")
  endif()

  byte_machine_add_scheme_lane(
    NAME "byte-machine.portability.placeholder-cwd-${cwd_case}.chez.source"
    BACKEND chez
    PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.chez.sps"
    TIMEOUT 120
    WORKING_DIRECTORY "${cwd_dir}")

  byte_machine_add_scheme_lane(
    NAME "byte-machine.portability.placeholder-cwd-${cwd_case}.gambit.source"
    BACKEND gambit
    PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.gambit.scm"
    TIMEOUT 120
    WORKING_DIRECTORY "${cwd_dir}")
endforeach()
```

- [ ] **Step 8: Run the six lanes**

```bash
make build && ctest --preset pr -R 'placeholder-cwd' --output-on-failure
```

Expected: 6 tests, all PASS. Confirm the working directories actually differ:

```bash
ctest --preset pr -R 'placeholder-cwd' -V 2>&1 | rg 'Test command|Working Directory'
```

Expected: three distinct `cwd-matrix/...` directories, each appearing twice.

- [ ] **Step 9: Add the mutations for the new CMake decisions**

In `test/support/cmake/MutationSuite.cmake`:

```cmake
byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: WORKING_DIRECTORY names a directory that need not exist"
  FIND [[  if(arg_WORKING_DIRECTORY AND NOT IS_DIRECTORY "${arg_WORKING_DIRECTORY}")]]
  REPLACE [[  if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: the override is parsed and then ignored"
  FIND [[  if(override)
    set(${out_dir} "${override}" PARENT_SCOPE)
    return()
  endif()]]
  REPLACE [[  if(FALSE)
    set(${out_dir} "${override}" PARENT_SCOPE)
    return()
  endif()]])

# The empty-override branch is a decision of its own: treating "" as a value
# would launch every non-overriding lane from the filesystem root.
byte_machine_mutation(
  FILE cmake/ByteMachineTesting.cmake SPEC ByteMachineTestingSpec.cmake
  LABEL "testing: an empty override is treated as a directory"
  FIND [[  if(override)]]
  REPLACE [[  if(TRUE)]])
```

- [ ] **Step 10: Run the mutation suite and the full test suite**

```bash
ctest --preset pr -R 'byte-machine\.harness\.cmake-mutation' --output-on-failure && make test
```

Expected: both pass.

- [ ] **Step 11: Commit**

```bash
git add cmake/ByteMachineTesting.cmake cmake/ByteMachineExpectExit.cmake cmake/ByteMachineSchemeLane.cmake test/support/cmake/ByteMachineTestingSpec.cmake test/support/cmake/MutationSuite.cmake test/CMakeLists.txt
git commit -m "feat: run the placeholder lanes from three working directories"
```

---

### Task 5: Make the matrix and the body prove they can fail

Everything so far is green under both a correct mechanism and several broken ones. This task is where that stops being true.

**Files:**
- Modify: `test/support/cmake/MutationRunner.cmake`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: `byte_machine_mutation`, `byte_machine_mutation_reset`, `byte_machine_mutation_run` from `MutationRunner.cmake`.
- Produces: `BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY` — the directory the verify command runs in; empty means the stage directory, which is the existing behaviour.

- [ ] **Step 1: Give the mutation runner a verify working directory**

In `test/support/cmake/MutationRunner.cmake`, beside the existing `BYTE_MACHINE_MUTATION_VERIFY_COMMAND` declaration:

```cmake
# Where the verify command runs. Empty means the stage directory, which is what
# every pass wanted until slice 3. The working-directory matrix needs a pass per
# launch directory, because what it asserts is that the launch directory does
# not matter -- a claim no command run from one fixed place can make.
set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY "")
```

and in `byte_machine_mutation_run_spec`, replace:

```cmake
  execute_process(
    COMMAND ${command}
    WORKING_DIRECTORY "${stage_dir}"
```

with:

```cmake
  set(verify_cwd "${stage_dir}")
  if(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY)
    set(verify_cwd "${BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY}")
  endif()

  execute_process(
    COMMAND ${command}
    WORKING_DIRECTORY "${verify_cwd}"
```

This parameter needs no specification of its own: if it were ignored, all three matrix passes below would run from the stage directory, the mutation would be caught in each, and the pass that declares a survivor would report its recorded limitation as stale. It is witnessed by the thing it exists for.

- [ ] **Step 2: Stage the product tree**

In `test/support/cmake/SchemeMutationSuite.cmake`, the stage list must carry `src` whole and `test/common`, because the Gambit owner library includes the body by a relative path and a flattened stage would leave Gambit compiling the unmutated original. Replace:

```cmake
set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers")
```

with:

```cmake
# src is staged whole, not just the body: src/gambit/byte-machine/placeholder.sld
# includes ../../common/byte-machine/placeholder.scm, so the relative layout is
# part of what has to be copied. Staging the body alone satisfies Chez, which
# resolves by bare filename, and silently leaves Gambit compiling the
# unmutated original -- a suite reporting a caught mutation on a runtime that
# never saw it.
set(BYTE_MACHINE_MUTATION_STAGE_DIRS
  "cmake" "test/support/cmake" "test/support/harness" "test/support/launchers"
  "src" "test/common")
```

- [ ] **Step 3: Add the placeholder verify commands and the body mutations**

At the end of `test/support/cmake/SchemeMutationSuite.cmake`, after the existing passes:

```cmake
# --- Pass 10: the body's decisions, on Chez --------------------------------
#
# A wrapper that reimplemented the body is exactly a wrapper whose runtime does
# not notice the body changing. That is why these two passes exist and why they
# run the same mutations twice: this is not the runner body, identical text on
# both runtimes, but a body whose being shared is the thing under test.

set(PLACEHOLDER_BODY src/common/byte-machine/placeholder.scm)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--library-root" "${STAGE_DIR}/src/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-tests.chez.sps")

# byte_machine_slice3_body_pass(<runtime>)
#
# One whole pass over the body's decisions, declared once. Both runtimes call
# it, so they are provably checked against the same list: a mutation added for
# one and forgotten for the other would be exactly the asymmetry these two
# passes exist to rule out.
#
# The reset, the declarations and the run are all inside this function on
# purpose. byte_machine_mutation_reset and byte_machine_mutation both write the
# counter with PARENT_SCOPE, so they agree only while they share a caller;
# declaring here and running from the caller would leave the run seeing a count
# of zero and reporting a pass that checked nothing. The verify command is read
# from the caller's scope, which is what makes the runtime the only difference.
function(byte_machine_slice3_body_pass runtime)
  byte_machine_mutation_reset()

  if(runtime STREQUAL "chez")
    set(spec placeholder-tests.chez.sps)
  else()
    set(spec placeholder-tests.gambit.scm)
  endif()

  byte_machine_mutation(
    FILE ${PLACEHOLDER_BODY} SPEC ${spec}
    LABEL "placeholder on ${runtime}: anything is a vector"
    FIND [[  (and (vector? x)]]
    REPLACE [[  (and #t]])

  # The length check is broken by changing the constant, not by deleting it.
  # Deleting it cannot be witnessed from outside the library: the tag is
  # private, so no caller can build a mis-sized vector carrying it. Changing the
  # constant breaks the same decision and every genuine placeholder is rejected.
  byte_machine_mutation(
    FILE ${PLACEHOLDER_BODY} SPEC ${spec}
    LABEL "placeholder on ${runtime}: the length check accepts the wrong length"
    FIND [[       (= (vector-length x) 2)]]
    REPLACE [[       (= (vector-length x) 3)]])

  byte_machine_mutation(
    FILE ${PLACEHOLDER_BODY} SPEC ${spec}
    LABEL "placeholder on ${runtime}: the tag is not checked"
    FIND [[       (eq? (vector-ref x 0) placeholder-tag)))]]
    REPLACE [[       #t))]])

  # The rule the whole representation rests on. With a symbol tag every
  # assertion in the suite still passes except the one written for this, and
  # slice 4's identity test would become incapable of failing.
  byte_machine_mutation(
    FILE ${PLACEHOLDER_BODY} SPEC ${spec}
    LABEL "placeholder on ${runtime}: the tag is an interned symbol"
    FIND [[(define placeholder-tag (vector 'byte-machine-placeholder))]]
    REPLACE [[(define placeholder-tag 'byte-machine-placeholder)]])

  byte_machine_mutation(
    FILE ${PLACEHOLDER_BODY} SPEC ${spec}
    LABEL "placeholder on ${runtime}: the marker is allocated per call"
    FIND [[(define (placeholder-marker)
  placeholder-marker-object)]]
    REPLACE [[(define (placeholder-marker)
  (vector 'byte-machine-marker))]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

byte_machine_slice3_body_pass("chez")

# --- Pass 11: the same decisions, on Gambit --------------------------------

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit,search=${STAGE_DIR}/src/gambit"
    "-f"
    "${STAGE_DIR}/test/common/placeholder-tests.gambit.scm")

  # The same five mutations, declared once and run per runtime. Writing them out
  # twice would let the two lists drift, and a mutation silently present on only
  # one runtime is precisely the defect this pair of passes exists to detect.
  byte_machine_slice3_body_pass("gambit")
endif()
```

- [ ] **Step 4: Run the two body passes**

```bash
ctest --preset pr -R 'byte-machine\.harness\.scheme-mutation' --output-on-failure
```

Expected: PASS, with ten new mutations reported caught — five on each runtime. If a Gambit one survives while its Chez twin was caught, the stage is not preserving the relative layout; re-read Step 2 before changing anything else.

- [ ] **Step 5: Add the launcher's parse decisions**

Still in `test/support/cmake/SchemeMutationSuite.cmake`, after the two body passes. Each of these needs an invocation that is wrong in exactly one way, wrapped in the exact-status helper so the *baseline* is green and the mutation turns an expected 2 into something else. A refusal cannot be witnessed by a correctly set-up lane, because a correctly set-up lane never reaches one — which is why each gets its own pass with its own command line.

```cmake
# --- Passes 12 to 19: the launcher's parse decisions ------------------------
#
# Deleting a refusal does not produce a wrong answer; it produces an invocation
# that is accepted and then fails somewhere else, or does not fail at all. Two
# of these mutations leave the launcher reaching malformed input and dying at
# 255 rather than 2, which the exact-status helper reports as out-of-vocabulary.
# That is still caught, and it is the honest outcome: the refusal exists exactly
# so that malformed input is named rather than stumbled over.

set(LAUNCHER_BASE_ARGS
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

# byte_machine_slice3_launcher_pass(<lane> <label> <find> <replace> <arg>...)
#
# One pass: point the verify command at a deliberately wrong invocation, declare
# one mutation, run it. Defined here rather than inlined eight times because the
# only thing that varies is the lane, the command line, and the mutation.
#
# The reset, the declaration and the run all happen inside this function on
# purpose. byte_machine_mutation_reset and byte_machine_mutation both write the
# counter with PARENT_SCOPE, so they agree only while they share a caller;
# splitting them across this boundary would leave the run seeing a count from
# somewhere else.
function(byte_machine_slice3_launcher_pass lane label find replace)
  byte_machine_mutation_reset()

  string(JOIN "|" packed
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
    ${ARGN})

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${CMAKE_COMMAND}"
    "-DBYTE_MACHINE_EXPECT_EXIT=2"
    "-DBYTE_MACHINE_EXPECT_COMMAND=${packed}"
    -P "${STAGE_DIR}/cmake/ByteMachineExpectExit.cmake")

  byte_machine_mutation(
    FILE ${LAUNCHER} SPEC "${lane}"
    LABEL "${label}"
    FIND "${find}"
    REPLACE "${replace}")

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-unknown-flag.chez.source
  "launcher: an unrecognised flag is accepted"
  [[        ((not (member (car rest) known-flags))]]
  [[        (#f]]
  "--librarie-root" "${STAGE_DIR}/test/support/harness/chez" ${LAUNCHER_BASE_ARGS})

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-missing-value.chez.source
  "launcher: a flag with no value is accepted"
  [[        ((null? (cdr rest))]]
  [[        (#f]]
  ${LAUNCHER_BASE_ARGS} "--source-dir")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-repeated-flag.chez.source
  "launcher: a single-valued flag may be given twice"
  [[   (if (> (length (flag-values flag)) 1)]]
  [[   (if #f]]
  ${LAUNCHER_BASE_ARGS}
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-self-tests.chez.sps")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: a missing required flag is not noticed"
  [[   (if (null? (flag-values flag))]]
  [[   (if #f]]
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

# Four more: one per entry in required-flags. The check above is one decision,
# but the list it walks is four, and an entry dropped from it is invisible to
# every invocation except the one omitting that flag.

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-program.chez.source
  "launcher: --program is dropped from required-flags"
  [[  (list "--program"]]
  [[  (list ;; --program removed by mutation]]
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-object-guard.chez.source
  "launcher: --object-guard is dropped from required-flags"
  [[        "--object-guard"]]
  [[        ;; --object-guard removed by mutation]]
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: --library-root is dropped from required-flags"
  [[        "--library-root"]]
  [[        ;; --library-root removed by mutation]]
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")

byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-source-dir.chez.source
  "launcher: --source-dir is dropped from required-flags"
  [[        "--source-dir"]]
  [[        ;; --source-dir removed by mutation]]
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.chez.sps")
```

Then update the file's header comment. It opens `NINE PASSES, BECAUSE NINE DIFFERENT WITNESSES ARE NEEDED` and enumerates them; that sentence is now false. Rewrite the count and append a paragraph for the new groups: the body on each runtime (why twice, when the runner body is verified once), the launcher's parse decisions (why one pass each), the working-directory matrix (why three passes for one mutation, and why one of them declares a survivor), and the Gambit search roots.

Run it before moving on:

```bash
ctest --preset pr -R 'byte-machine\.harness\.scheme-mutation' --output-on-failure
```

Expected: PASS, with eight more mutations reported caught. A dropped-entry mutation reported *uncaught* means its FIND text matched somewhere other than `required-flags` — check that `known-flags` is still written inline on one line, which is what makes the eight-space-indented entries unique.

- [ ] **Step 6: Add the three matrix passes**

Append to `test/support/cmake/SchemeMutationSuite.cmake`. These need the matrix fixture directories, which `test/CMakeLists.txt` builds under `CMAKE_BINARY_DIR`; the registration must forward that path, so also add `"-DBYTE_MACHINE_CWD_MATRIX_DIR=${BYTE_MACHINE_CWD_MATRIX_DIR}"` to the `byte_machine_add_test` COMMAND that registers this suite in `test/CMakeLists.txt`.

```cmake
# --- Passes 20 to 22: the working-directory matrix -------------------------
#
# One mutation, three passes, three expected outcomes. The launcher is made to
# resolve shared bodies against the working directory -- the mechanism this
# project deliberately does not use -- while the program's own directory is left
# in place so the test body still resolves and each lane fails, or does not, for
# the reason under test.
#
#   empty      fails: nothing to include
#   decoy      fails: wrong answer, on content
#   identical  PASSES: the copy in the working directory is the real body
#
# The survivor is the point. It is what turns "the identical lane is the vacuous
# test someone writes by default" from a comment into something this suite
# observes on every run, and it is what makes the decoy lane's failure
# attributable to content rather than to the mere presence of a same-named file.

if(NOT BYTE_MACHINE_CWD_MATRIX_DIR)
  message(FATAL_ERROR
    "byte-machine-mutation: BYTE_MACHINE_CWD_MATRIX_DIR was not passed in. The "
    "matrix passes assert what a launch directory does or does not change, so "
    "they cannot run from the stage directory like every other pass.")
endif()

set(CWD_MUTATION_FIND
  [[(source-directories (append source-dirs (list (path-directory program))))]])
set(CWD_MUTATION_REPLACE
  [[(source-directories (append (list ".") (list (path-directory program))))]])

foreach(cwd_case empty decoy identical)
  byte_machine_mutation_reset()

  set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY
      "${BYTE_MACHINE_CWD_MATRIX_DIR}/same-name-${cwd_case}")
  if(cwd_case STREQUAL "empty")
    set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY
        "${BYTE_MACHINE_CWD_MATRIX_DIR}/empty")
  endif()

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
    "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
    "--library-root" "${STAGE_DIR}/test/support/harness/chez"
    "--library-root" "${STAGE_DIR}/src/chez"
    "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
    "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
    "--object-guard" "${GUARD_DIR}"
    "--program" "${STAGE_DIR}/test/common/placeholder-tests.chez.sps")

  if(cwd_case STREQUAL "identical")
    byte_machine_mutation(
      FILE ${LAUNCHER} SPEC placeholder-tests.chez.sps
      LABEL "launcher: shared bodies resolve against the working directory (identical)"
      FIND "${CWD_MUTATION_FIND}"
      REPLACE "${CWD_MUTATION_REPLACE}"
      EXPECT_SURVIVES
        "This lane runs from a directory holding a copy of every body the lane includes, so an include resolved against the working directory finds the real text and the suite passes. That is the lane's purpose: it is the naive working-directory test, carried as the control that makes the decoy and empty lanes' failures attributable. If this mutation ever starts being caught, the copies have drifted from the bodies they were copied from and the control has quietly become something else.")
  else()
    byte_machine_mutation(
      FILE ${LAUNCHER} SPEC placeholder-tests.chez.sps
      LABEL "launcher: shared bodies resolve against the working directory (${cwd_case})"
      FIND "${CWD_MUTATION_FIND}"
      REPLACE "${CWD_MUTATION_REPLACE}")
  endif()

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endforeach()

# --- Pass 23: the Gambit lanes use absolute search roots -------------------
#
# The mutation above cannot touch Gambit: it resolves the include relative to
# the including file, so no launcher decides anything. What the Gambit matrix
# lanes prove is narrower -- that the lane command's search roots are absolute
# -- and this is what witnesses it. All three Gambit lanes fail together;
# symmetry of lane counts is not symmetry of evidence.

byte_machine_mutation_reset()

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY
      "${BYTE_MACHINE_CWD_MATRIX_DIR}/empty")

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=test/support/harness/gambit,search=src/gambit"
    "-f"
    "${STAGE_DIR}/test/common/placeholder-tests.gambit.scm")

  # No file is mutated: the deliberately relative search roots above are the
  # mutation. The runner still needs a declaration, so this one rewrites a
  # comment character in the launcher, which cannot affect a Gambit lane.
  byte_machine_mutation(
    FILE ${LAUNCHER} SPEC placeholder-tests.gambit.scm
    LABEL "gambit lane: relative search roots do not resolve from another directory"
    FIND [[;;; Chez source-mode launcher.]]
    REPLACE [[;;; Chez source-mode launcher (mutated).]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endif()
```

- [ ] **Step 7: Forward the matrix path to the mutation suite registration**

In `test/CMakeLists.txt`, in the `byte_machine_add_test` call that registers `byte-machine.harness.scheme-mutation.cmake.direct`, add the new `-D` argument after the Gambit one:

```cmake
            "-DBYTE_MACHINE_CWD_MATRIX_DIR=${BYTE_MACHINE_CWD_MATRIX_DIR}"
```

- [ ] **Step 8: Run the mutation suite and read the survivor line**

```bash
ctest --preset pr -R 'byte-machine\.harness\.scheme-mutation' --output-on-failure -V 2>&1 | rg -i 'survive|caught|identical'
```

Expected: the two `(empty)` and `(decoy)` mutations reported caught, and the `(identical)` one reported as an expected survivor. If `(identical)` is reported caught, the suite will say the recorded limitation is stale — that means the fixture copies no longer match the real bodies, not that the mutation is wrong.

- [ ] **Step 9: Run everything**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: both pass.

- [ ] **Step 10: Commit**

```bash
git add test/support/cmake/MutationRunner.cmake test/support/cmake/SchemeMutationSuite.cmake test/CMakeLists.txt
git commit -m "test: prove the body is shared and the matrix can fail"
```

---

### Task 6: Record what was measured

**Files:**
- Create: `docs/decisions/0002-shared-body-include-mechanism.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Read the existing decision record for its format**

```bash
cat docs/decisions/0001-toolchain-discovery.md
```

Match its heading structure, status line, and voice.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0002-shared-body-include-mechanism.md` covering, in the format 0001 establishes:

- **Context.** Milestone 0 D6 chose `source-directories` plus bare filenames for Chez and source-relative `include` for Gambit. Milestone plan §9 question 3 asks what library search paths look like across platforms.
- **Measurements** (2026-08-16, Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8), each with the exact observed output:
  - `source-directories` takes precedence over the process working directory: a same-named decoy in the CWD is ignored.
  - There is no CWD fallback. With `source-directories` pointing where the file is not, Chez reports `file "..." not found in source directories` and exits 255, with the decoy still sitting in the CWD. The milestone plan's "bare relative path resolves against process CWD" describes the *default* value of `source-directories`, which contains `"."`.
  - `gsi -:search=A,search=B` resolves libraries from two roots; with only A, `Cannot find library (pkg beta)` and exit 70.
  - A search root containing a comma makes `gsi` print its runtime-options usage banner and run no Scheme.
- **Decision.** The launcher takes repeatable flags and byte-machine uses no PATH-style separator anywhere on the Chez side; Gambit's separator is fixed by Gambit at `,` and a root containing one is refused at configure time.
- **Consequences.** §9 question 3 is answered for macOS arm64 and closed for the Chez side by construction; the Windows half stays open until CI (D8). Exit statuses 255 and 70 both fall outside the harness vocabulary, so a broken include is reported as out-of-vocabulary rather than as a wrong assertion outcome.

- [ ] **Step 3: Add the changelog entry**

In `CHANGELOG.md`, under `## [Unreleased]` → `### Added`, append:

```markdown
- The first product library: one shared body in `src/common/byte-machine/`
  included by exactly one thin library per runtime. Its type tag and singleton
  are freshly allocated rather than symbols, because symbols are interned and a
  symbol tag would make a body included twice indistinguishable from one
  included once — the defect the one-owner rule exists to prevent.
- A working-directory matrix. The same body loads through both wrappers from
  three directories chosen so each catches a different failure: a copy where an
  include resolved against the working directory would accidentally succeed, a
  same-named impostor where it would report the wrong answer, and an empty
  directory where it would find nothing. All three pass under a correct
  mechanism, so what proves them is a launcher mutation whose expected outcome
  is asymmetric — the first passes, the other two fail — with the survivor
  asserted rather than ignored.
- Mutation coverage that runs on both runtimes for the shared body, inverting
  the rule the harness runner uses. A wrapper that quietly reimplemented the
  body is exactly a wrapper whose runtime does not notice the body changing, so
  the claim that no wrapper duplicates semantics is witnessed rather than
  reviewed.
- The Chez launcher takes repeatable `--library-root` and `--source-dir` flags,
  since a lane now imports from both the harness and the product tree. Each of
  its parse refusals is a lane asserting status 2, because a correctly set-up
  lane never reaches one.
- A Gambit search root containing a comma is refused at configure time.
  Gambit's `-:` options are comma-separated, so such a root makes `gsi` print
  its usage banner and run no Scheme at all, on every Gambit lane at once, in
  output that names nothing this project owns.
```

- [ ] **Step 4: Run everything one last time**

```bash
make test && cmake --preset no-scheme && ctest --preset no-scheme
```

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/0002-shared-body-include-mechanism.md CHANGELOG.md
git commit -m "docs: record the shared-body include mechanism"
```

---

## Verification checklist

Against the spec's §12. Each line must be a command someone can run, not a claim.

- [ ] `make test` passes, and `ctest --preset no-scheme` passes with neither runtime installed.
- [ ] `ctest --preset pr -R 'placeholder-cwd' -V | rg 'Working Directory'` shows three distinct directories, each used by both runtimes.
- [ ] The scheme-mutation suite reports the `(empty)` and `(decoy)` launcher mutations caught and the `(identical)` one as an expected survivor.
- [ ] The scheme-mutation suite reports all five body mutations caught on Chez **and** all five on Gambit.
- [ ] Every launcher refusal has a lane asserting exit 2: `ctest --preset pr -R 'launcher-' | rg 'tests passed'` shows nine.
- [ ] Removing `src/common/byte-machine/placeholder.scm` makes `cmake --preset dev` fail with `contributed no shared body`.
- [ ] `rg -n "chez|gambit|chezscheme|scheme base" src/common test/common/placeholder-tests.scm` returns nothing: no shared body names a runtime.
