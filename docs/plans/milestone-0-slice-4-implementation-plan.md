# Milestone 0 Slice 4: Cross-Library Identity — Implementation Plan

Status: executed; delivered 2026-08-17

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove that a value built through one library wrapper is recognised by a second wrapper that imported the first, and that an allocation-free singleton keeps `eq?` identity across both imports, on Chez and on Gambit.

**Architecture:** A second library per runtime, `(byte-machine placeholder-consumer)`, built over its own wrapper-free shared body. Its wrappers **import** `(byte-machine placeholder)` rather than including that library's body a second time; the body names the owner's exports as free identifiers and the wrapper's import list supplies them. A shared test body importing both libraries asserts the two claims, and four mutation passes prove those assertions can fail.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS `.sls`), Gambit 4.9.8 (R7RS `.sld`), CMake 3.26+, CTest, the project's own Scheme test harness and mutation runner. No third-party Scheme dependencies.

**Design spec:** [`milestone-0-slice-4-cross-library-identity.md`](./milestone-0-slice-4-cross-library-identity.md). Read §5.2, §8.1 and §8.2 before starting; they carry the reasoning the code cannot.

> **Correction, recorded after execution.** This plan is kept as the historical
> artifact of what was planned, and two claims in it were wrong. Both were
> corrected in the design spec, decision record 0003, and the shipped code; they
> are left standing here rather than rewritten, in the manner of the milestone
> plan's §2.1 and §10.
>
> 1. **The double-include mutant does not "exit 0".** That figure came from a
>    pre-design scratch driver that printed two booleans and had no harness. The
>    shipped harness-integrated identity lane fails through ordinary
>    `check`/`check-equal` mismatches and exits **1** on both runtimes. "Nothing
>    raises" was and remains correct. `MutationRunner` treats a zero return code
>    as *not-caught*, so the original claim, if true, would have made passes 26
>    and 27 report uncaught.
> 2. **Task 2's first mutation is `(if #f`, not `(if #t`.** The plan's form was
>    caught by an induced raise; a comparison-based witness was found during
>    review and replaces it, which dissolves the concession the design spec's
>    §5.3 originally argued for.
>
> Two smaller drifts, fixed during execution: Task 2 and Task 3's Step 3 each say
> to replace "the single occurrence" of the file's quoted header title, but there
> are two, and neither task lists the follow-on fix to the paragraph naming which
> passes are Gambit-gated.

## Global Constraints

- Shared `.scm` bodies use only the R6RS/R7RS common subset and never name Chez or Gambit. Runtime-specific code lives only in the thin `.sls`/`.sld` wrappers. (AGENTS.md)
- R6RS forbids assigning an exported variable; reach mutable state through procedures. (AGENTS.md)
- Every decision in a module gets a mutation that breaks it, and the owning specification must notice. `EXPECT_SURVIVES` is for the genuinely unwitnessable, with a written reason — never to reach green. (AGENTS.md)
- Run tests before every commit; fix failures before proceeding. (AGENTS.md)
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, …). (AGENTS.md)
- Work happens on branch `feat/m0-slice-4-cross-library-identity`, already created.
- Slice 4 is **source lanes only**. Do not add Chez AOT, Gambit `.o1`, or `gsc -exe` lanes; those are slice 5. (Spec U6)
- No CMake module under `cmake/` is edited by this slice, and the CMake mutation count stays at 96. (Spec §4.1)
- Toolchains are discovered, never named by bare binary. Do not hardcode `chez`, `gsi`, or `gsc` anywhere.

## File Structure

**Created:**

| Path | Responsibility |
| --- | --- |
| `src/common/byte-machine/placeholder-consumer.scm` | The consumer body. Defines `consume` and nothing else; every other identifier it uses is free. |
| `src/chez/byte-machine/placeholder-consumer.sls` | Chez owner wrapper. Library form, imports, exports, include. No semantics. |
| `src/gambit/byte-machine/placeholder-consumer.sld` | Gambit owner wrapper. Same, with a source-relative include path. |
| `test/common/placeholder-identity-tests.scm` | Shared test body. Two cases, one per D3 clause. |
| `test/common/placeholder-identity-tests.chez.sps` | Chez test wrapper. Imports only. |
| `test/common/placeholder-identity-tests.gambit.scm` | Gambit test wrapper. Imports only. |
| `docs/decisions/0003-cross-library-identity.md` | Decision record: the measurements, the U4 deferral with its reopening condition, the carried-forward open question. |

**Modified:**

| Path | Change |
| --- | --- |
| `test/CMakeLists.txt` | Two `byte_machine_add_scheme_lane` registrations, appended after the working-directory matrix block. |
| `test/support/cmake/SchemeMutationSuite.cmake` | Four new passes (24–27), eight new mutations, counter and header-prose updates. |
| `CHANGELOG.md` | Unreleased entry. |

Nothing under `cmake/` changes. `src/chez` and `src/gambit` are already library roots, `src/common/byte-machine` is already a `--source-dir`, and `byte_machine_portability_guard` already covers both `src/common/byte-machine` (as a `SHARED_DIR`) and `test/common` (as a `WRAPPED_DIR`). The mutation suite already stages `src` and `test/common` whole.

---

### Task 1: Cross-library identity, red to green

**Files:**
- Create: `test/common/placeholder-identity-tests.scm`
- Create: `test/common/placeholder-identity-tests.chez.sps`
- Create: `test/common/placeholder-identity-tests.gambit.scm`
- Create: `src/common/byte-machine/placeholder-consumer.scm`
- Create: `src/chez/byte-machine/placeholder-consumer.sls`
- Create: `src/gambit/byte-machine/placeholder-consumer.sld`
- Modify: `test/CMakeLists.txt` (append after the `foreach(cwd_case ...)` block that ends the working-directory matrix)

**Interfaces:**
- Consumes: `(byte-machine placeholder)` exports `make-placeholder`, `placeholder?`, `placeholder-value`, `placeholder-marker` (from `src/common/byte-machine/placeholder.scm`). Harness exports `harness-begin`, `harness-finish`, `harness-group`, `harness-case`, `check`, `check-equal` — signatures `(check what value)` and `(check-equal what actual expected)`.
- Produces: library `(byte-machine placeholder-consumer)` exporting exactly `consume`, a one-argument procedure. Tasks 2 and 3 mutate the three files that make it up and depend on their exact text.

- [ ] **Step 1: Write the failing test body**

Create `test/common/placeholder-identity-tests.scm`:

```scheme
;;; Cross-library identity tests. Milestone 0 slice 4, deliverable D3.
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only. Imports live in the
;;; two wrappers beside this file, and each imports BOTH libraries -- the owner
;;; for make-placeholder and placeholder-marker, the consumer for consume.
;;; Needing both names in scope at once is exactly why these cases cannot live
;;; in placeholder-tests.scm, whose header says cross-library identity is this
;;; slice's proof and is not attempted there.
;;;
;;; Under a consumer that included the owner's body instead of importing it,
;;; both cases below answer wrongly and nothing raises. Every other lane in this
;;; tree still passes, because every other lane imports only the owner. That is
;;; the whole reason this file exists.

(harness-group "placeholder-identity"
  (lambda ()

    (harness-case "recognition crosses a library boundary"
      (lambda ()
        ;; Built through the owner, read through the consumer. A second copy of
        ;; the body would give the consumer its own tag, so the owner's value
        ;; would stop matching and consume would return the consumer's marker
        ;; instead of 7.
        (check-equal "the owner built it and the consumer read it"
                     (consume (make-placeholder 7))
                     7)))

    (harness-case "the singleton crosses both imports"
      (lambda ()
        ;; Deliberately a non-placeholder: this drives consume down the branch
        ;; that yields the owner's singleton, so the identity claim does not
        ;; silently depend on the recognition claim above already holding.
        (check "the consumer's outcome is the owner's own object"
               (eq? (consume 7) (placeholder-marker)))))))
```

- [ ] **Step 2: Write the two test wrappers**

Create `test/common/placeholder-identity-tests.chez.sps`:

```scheme
;;; Chez wrapper for the cross-library identity tests. Runtime-specific only in
;;; its imports. Both libraries are imported here, never included: importing the
;;; owner is the claim under test.

(import (rnrs)
        (byte-machine test harness)
        (byte-machine placeholder)
        (byte-machine placeholder-consumer)
        (only (chezscheme) include))

(harness-begin "portability.placeholder-identity")

(include "placeholder-identity-tests.scm")

(harness-finish)
```

Create `test/common/placeholder-identity-tests.gambit.scm`:

```scheme
;;; Gambit wrapper for the cross-library identity tests. Runtime-specific only
;;; in its imports. Both libraries are imported here, never included: importing
;;; the owner is the claim under test.

(import (scheme base)
        (scheme write)
        (byte-machine test harness)
        (byte-machine placeholder)
        (byte-machine placeholder-consumer))

(harness-begin "portability.placeholder-identity")

(include "placeholder-identity-tests.scm")

(harness-finish)
```

- [ ] **Step 3: Register the two lanes**

Append to `test/CMakeLists.txt`, immediately after the `endforeach()` that closes the working-directory matrix block:

```cmake
# --- Cross-library identity ------------------------------------------------
#
# Slice 4, deliverable D3. One body, two libraries: the owner constructs, the
# consumer -- which imported the owner rather than including its body again --
# recognises, and the allocation-free singleton stays one object across both
# imports.
#
# No working-directory matrix here. The consumer adds a second include site per
# runtime but no new resolution mechanism: Chez resolves it by bare filename
# through source-directories exactly as it resolves the owner's body, and Gambit
# resolves it relative to the including file exactly as before. Slice 3 proved
# that mechanism; a second instance of a proven mechanism is not a second proof.
#
# Passing here is not yet evidence. What makes it evidence is passes 24 to 27 in
# SchemeMutationSuite.cmake, and in particular the double-include mutation --
# under which both cases below answer wrongly, nothing raises, and every other
# lane in this tree still passes.
byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder-identity.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.chez.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder-identity.gambit.source
  BACKEND gambit
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.gambit.scm"
  TIMEOUT 120)
```

No `LABELS` argument: `byte_machine_add_test` derives `portability`, the backend, and the mode from the test name, and `portability` is already in the `pr` preset's filter. No `WORKING_DIRECTORY`: the default is already an isolated per-test directory in the build tree.

- [ ] **Step 4: Run the lanes and verify they FAIL**

```bash
cmake --preset dev && ctest --preset pr -R placeholder-identity --output-on-failure
```

Expected: both lanes fail. `(byte-machine placeholder-consumer)` does not exist yet, so each runtime refuses at import — Chez with a message naming the library as not found, Gambit with `Cannot find library (byte-machine placeholder-consumer)`. Configure itself must succeed: the portability guard is satisfied because the new test body has both of its wrappers.

If configure fails instead, stop and read the guard's diagnostic — it means a wrapper is missing or a basename collides.

- [ ] **Step 5: Write the consumer body**

Create `src/common/byte-machine/placeholder-consumer.scm`:

```scheme
;;; Consumer body for the Milestone 0 cross-library identity proof.
;;;
;;; PORTABILITY: shared body, common R6RS/R7RS subset only. No library form, no
;;; include, no runtime-specific identifier. Included by exactly one owner
;;; library per runtime, one such library living in each runtime's own source
;;; tree.
;;;
;;; EVERY IDENTIFIER THIS BODY USES BUT DOES NOT DEFINE COMES FROM ITS OWNER
;;; WRAPPER'S IMPORT LIST
;;;
;;; placeholder?, placeholder-value and placeholder-marker are free here. They
;;; are supplied by (byte-machine placeholder), which each wrapper imports --
;;; never by a second include of that library's body. Replacing the import with
;;; an include is the defect byte-machine-implementation-plan.md's section 7.2
;;; forbids, and it is silent: both identity cases simply answer wrongly,
;;; nothing raises, and every lane that imports only the owner still passes.
;;;
;;; This is also the mechanism Milestone 1 runs on, where verify.scm calls graph
;;; procedures it does not define and verify.sls supplies them by importing
;;; (byte-machine graph).
;;;
;;; This carries no byte-machine semantics and is deleted in Milestone 1
;;; (milestone-0-portability-spike.md, decision D4).

;;; The reject branch, not the accept branch, carries the singleton. That is
;;; deliberate: it means the identity assertion needs no placeholder constructed
;;; in order to be made, so the identity claim does not silently depend on the
;;; recognition claim already working. See section 5.2 of
;;; milestone-0-slice-4-cross-library-identity.md.
;;;
;;; This models section 7.2's rule that interpreted callbacks must return the
;;; runtime's own singleton outcome values rather than lookalikes.
(define (consume p)
  (if (placeholder? p)
      (placeholder-value p)
      (placeholder-marker)))
```

- [ ] **Step 6: Write the Chez owner wrapper**

Create `src/chez/byte-machine/placeholder-consumer.sls`:

```scheme
;;; Chez owner library for the consumer body.
;;;
;;; A library form, imports, exports, and the include. Nothing else: any
;;; semantics here would be semantics the shared body no longer owns.
;;;
;;; The second import is the whole subject of slice 4. (byte-machine placeholder)
;;; is imported, never included -- including it would make this library a second
;;; owner of that body, giving it its own tag and its own marker. Pass 26 in
;;; SchemeMutationSuite.cmake makes exactly that edit and requires the identity
;;; lane to fail.

(library (byte-machine placeholder-consumer)
  (export consume)
  (import (rnrs) (byte-machine placeholder) (only (chezscheme) include))
  (include "placeholder-consumer.scm"))
```

- [ ] **Step 7: Write the Gambit owner wrapper**

Create `src/gambit/byte-machine/placeholder-consumer.sld`:

```scheme
;;; Gambit owner library for the consumer body.
;;;
;;; A library form, imports, exports, and the include. Nothing else, for the
;;; reason given in the Chez counterpart.
;;;
;;; The body is included by a path relative to this file, which is how Gambit
;;; resolves include inside define-library; Chez resolves the same body by bare
;;; filename through its launcher's source-directories. As with the owner pair,
;;; that difference is why a staged copy for mutation testing must preserve this
;;; relative layout rather than flatten it.
;;;
;;; The second import is the subject of slice 4; pass 27 in
;;; SchemeMutationSuite.cmake replaces it with an include and requires the
;;; identity lane to fail.

(define-library (byte-machine placeholder-consumer)
  (export consume)
  (import (scheme base) (byte-machine placeholder))
  (include "../../common/byte-machine/placeholder-consumer.scm"))
```

- [ ] **Step 8: Run the lanes and verify they PASS**

```bash
cmake --preset dev && ctest --preset pr -R placeholder-identity --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 9: Run the whole suite**

```bash
make test
```

Expected: `100% tests passed, 0 tests failed out of 40`. The suite was 38 before this task; the two new lanes bring it to 40.

- [ ] **Step 10: Verify the no-scheme preset is unaffected**

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 10`. The new lanes are Scheme lanes and skip when no runtime is discovered.

- [ ] **Step 11: Commit**

```bash
git add src/common/byte-machine/placeholder-consumer.scm src/chez/byte-machine/placeholder-consumer.sls src/gambit/byte-machine/placeholder-consumer.sld test/common/placeholder-identity-tests.scm test/common/placeholder-identity-tests.chez.sps test/common/placeholder-identity-tests.gambit.scm test/CMakeLists.txt
git commit -m "feat: a second library recognises the owner's values and shares its singleton (M0 slice 4)"
```

---

### Task 2: The consumer body's decisions, on both runtimes

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: `src/common/byte-machine/placeholder-consumer.scm` and both test wrappers from Task 1. The `FIND` strings below are exact text from that body; they will not match if Task 1's body was retyped rather than copied.
- Produces: passes 24 and 25. Task 3 appends passes 26 and 27 after them and assumes counters are at 25 passes / 62 mutations.

Three decisions, three mutations, run once per runtime. Both runtimes run the same list under slice 3's rule T6: a wrapper that reimplemented the body is exactly a wrapper whose runtime does not notice the body changing, and that claim is new again for a new body.

- [ ] **Step 1: Append passes 24 and 25**

Insert into `test/support/cmake/SchemeMutationSuite.cmake` **after** the line `set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY "")` that follows the working-directory matrix, and **before** the `byte_machine_mutation_totals(...)` call at the end of the file:

```cmake
# --- Pass 24: the consumer body's decisions, on Chez -------------------------
#
# Same argument as passes 9 and 10, for a second body: a wrapper that
# reimplemented this body is exactly a wrapper whose runtime does not notice the
# body changing, so the list runs once per runtime.

set(CONSUMER_BODY src/common/byte-machine/placeholder-consumer.scm)

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--library-root" "${STAGE_DIR}/src/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-identity-tests.chez.sps")

# byte_machine_slice4_body_pass(<runtime>)
#
# Declared once and called per runtime, for the reason
# byte_machine_slice3_body_pass gives: a mutation added for one runtime and
# forgotten for the other is precisely the asymmetry the pair exists to rule
# out. The reset, the declarations and the run all live inside this function
# because byte_machine_mutation_reset and byte_machine_mutation both write the
# counter with PARENT_SCOPE and agree only while they share a caller.
function(byte_machine_slice4_body_pass runtime)
  byte_machine_mutation_reset()

  if(runtime STREQUAL "chez")
    set(spec placeholder-identity-tests.chez.sps)
  else()
    set(spec placeholder-identity-tests.gambit.scm)
  endif()

  # Caught by a raise rather than by a comparison: consume takes the recognised
  # branch for 7, and placeholder-value indexes a non-vector. Weaker than the
  # two below, and accepted rather than missed -- the alternative is a defensive
  # branch in consume that exists only to make this mutation fail prettily, and
  # that branch would be a decision with no independent reason to exist. See
  # section 5.3 of the slice-4 design.
  byte_machine_mutation(
    FILE ${CONSUMER_BODY} SPEC ${spec}
    LABEL "consumer on ${runtime}: the argument is not checked at all"
    FIND [[  (if (placeholder? p)]]
    REPLACE [[  (if #t]])

  byte_machine_mutation(
    FILE ${CONSUMER_BODY} SPEC ${spec}
    LABEL "consumer on ${runtime}: the recognised branch yields the marker, not the value"
    FIND [[      (placeholder-value p)]]
    REPLACE [[      (placeholder-marker)]])

  # The only mutation that reaches D3's second clause by itself: recognition
  # still works, and the outcome is merely a different object that prints the
  # same. This is the one an eq?-free test would miss entirely.
  byte_machine_mutation(
    FILE ${CONSUMER_BODY} SPEC ${spec}
    LABEL "consumer on ${runtime}: the outcome is a lookalike, not the owner's singleton"
    FIND [[      (placeholder-marker)))]]
    REPLACE [[      (vector 'byte-machine-marker)))]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endfunction()

byte_machine_slice4_body_pass("chez")

# --- Pass 25: the same decisions, on Gambit ---------------------------------

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit,search=${STAGE_DIR}/src/gambit"
    "-f"
    "${STAGE_DIR}/test/common/placeholder-identity-tests.gambit.scm")

  byte_machine_slice4_body_pass("gambit")
endif()
```

Note the third mutation's `REPLACE` uses the same symbol the owner's marker carries, `'byte-machine-marker`. That is deliberate: the lookalike must be indistinguishable except by `eq?`, or the mutation would be caught by something other than the identity claim.

- [ ] **Step 2: Update the counters**

In the same file, change:

```cmake
set(EXPECTED_PASSES_WITH_GAMBIT 23)
set(EXPECTED_MUTATIONS_WITH_GAMBIT 56)
```

to:

```cmake
set(EXPECTED_PASSES_WITH_GAMBIT 25)
set(EXPECTED_MUTATIONS_WITH_GAMBIT 62)
```

and change:

```cmake
set(GAMBIT_ONLY_PASSES 2)
set(GAMBIT_ONLY_MUTATIONS 7)
```

to:

```cmake
set(GAMBIT_ONLY_PASSES 3)
set(GAMBIT_ONLY_MUTATIONS 10)
```

- [ ] **Step 3: Update the header prose, which restates the same numbers**

Replace this block near the top of the file:

```
# TWENTY-THREE PASSES WHEN GAMBIT IS DISCOVERED, BECAUSE TWENTY-THREE
# DIFFERENT WITNESSES ARE NEEDED
#
# Two of the twenty-three are gated on BYTE_MACHINE_GAMBIT_EXECUTABLE, the same
# precondition every Gambit lane in this tree runs under: pass 2, the Gambit
# adapter's export list (one mutation), and pass 10, the placeholder body's
# decisions run a second time on Gambit (six mutations, the same list pass 9
# declares for Chez). Without Gambit this file runs twenty-one passes and
# forty-nine mutations rather than twenty-three passes and fifty-six -- the
# with-Gambit pair less that 2-pass, 7-mutation delta.
```

with:

```
# TWENTY-FIVE PASSES WHEN GAMBIT IS DISCOVERED, BECAUSE TWENTY-FIVE
# DIFFERENT WITNESSES ARE NEEDED
#
# Three of the twenty-five are gated on BYTE_MACHINE_GAMBIT_EXECUTABLE, the
# same precondition every Gambit lane in this tree runs under: pass 2, the
# Gambit adapter's export list (one mutation); pass 10, the placeholder body's
# decisions run a second time on Gambit (six mutations, the same list pass 9
# declares for Chez); and pass 25, the consumer body's decisions on Gambit
# (three mutations, the same list pass 24 declares for Chez). Without Gambit
# this file runs twenty-two passes and fifty-two mutations rather than
# twenty-five passes and sixty-two -- the with-Gambit pair less that 3-pass,
# 10-mutation delta.
```

Then replace the single occurrence of `the "TWENTY-THREE PASSES"` near the totals check at the end of the file with `the "TWENTY-FIVE PASSES"`.

Finally, insert this paragraph immediately after the existing paragraph that begins `# Passes 21 to 23 are the working-directory matrix:`:

```
# Passes 24 and 25 are the consumer body's three decisions, run once per
# runtime for the reason passes 9 and 10 give. Slice 4's design calls the first
# of the three out as caught by an induced raise rather than by a failed
# comparison -- weaker than the other two, weighed and accepted rather than
# missed.
```

- [ ] **Step 4: Run the mutation suite**

```bash
cmake --preset dev && ctest --preset pr -R scheme-mutation --output-on-failure
```

Expected: passes, and its final status line reads `scheme mutation suite complete (25 passes, 62 mutations)`.

If it reports a mutation that survived, that is a finding about the identity test, not a reason to loosen the mutation. If a `FIND` pattern reports zero or more than one site, the body text drifted from Task 1 — reconcile against the file rather than relaxing the pattern.

- [ ] **Step 5: Run the whole suite**

```bash
make test
```

Expected: `100% tests passed, 0 tests failed out of 40`.

- [ ] **Step 6: Commit**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: break each of the consumer body's decisions on both runtimes (M0 slice 4)"
```

---

### Task 3: The double-include mutation — §7.2's actual witness

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: `src/chez/byte-machine/placeholder-consumer.sls` and `src/gambit/byte-machine/placeholder-consumer.sld` from Task 1, verbatim. Counters at 25 passes / 62 mutations from Task 2.
- Produces: passes 26 and 27; final counters 27 passes / 64 mutations.

This is the proof the slice exists for. Each mutation makes the consumer wrapper a **second owner** of the placeholder body by replacing its import with an include, and requires the identity lane to fail.

**The mutation must replace the import, never add to it.** Measured on 2026-08-17: adding an include alongside the import makes Chez refuse at library construction with `multiple definitions for make-placeholder and other identifiers in body` — caught, but for a reason unrelated to identity, which `MutationRunner`'s caught-for-the-declared-reason check rejects — and does not fail on Gambit at all, so the mutation would simply survive. One edit, two wrong outcomes, neither of them the defect under test. See spec §8.1.

- [ ] **Step 1: Append passes 26 and 27**

Insert after `byte_machine_slice4_body_pass("gambit")`'s closing `endif()` and before the `byte_machine_mutation_totals(...)` call:

```cmake
# --- Passes 26 and 27: the consumer wrapper double-includes ------------------
#
# Section 7.2's rule -- each shared body is included by exactly one library per
# runtime; others import that owner -- stated as something that can fail. The
# mutation makes the consumer a second owner of the placeholder body, so it gets
# its own tag and its own marker, and both identity cases answer wrongly.
#
# It is the mutation this slice exists for, and it is silent under every other
# lane in the tree: measured on 2026-08-17, the mutant exits 0 on both runtimes
# and raises nothing. The placeholder-cwd lanes still pass under it, because
# they import only the owner. Only a program with both libraries in scope can
# see it.
#
# The import is REPLACED, never augmented. Adding an include beside the import
# was measured on the same date: Chez refuses at library construction with
# "multiple definitions for make-placeholder and other identifiers in body" --
# caught, but not for the declared reason -- and Gambit does not fail at all,
# leaving the mutation a survivor. See section 8.1 of the slice-4 design.
#
# Two passes rather than one shared list, unlike passes 24 and 25: slice 2's
# rule S6 ("Chez alone is enough, the text is identical") does not reach these,
# because the two wrappers differ in import syntax and in include path form, and
# the two runtimes do not even agree on what the augmenting variant means.

set(CHEZ_CONSUMER_WRAPPER src/chez/byte-machine/placeholder-consumer.sls)
set(GAMBIT_CONSUMER_WRAPPER src/gambit/byte-machine/placeholder-consumer.sld)

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness/chez"
  "--library-root" "${STAGE_DIR}/src/chez"
  "--source-dir" "${STAGE_DIR}/test/support/harness/shared"
  "--source-dir" "${STAGE_DIR}/src/common/byte-machine"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-identity-tests.chez.sps")

byte_machine_mutation(
  FILE ${CHEZ_CONSUMER_WRAPPER} SPEC placeholder-identity-tests.chez.sps
  LABEL "consumer wrapper on chez: includes the owner's body instead of importing the owner"
  FIND [[  (import (rnrs) (byte-machine placeholder) (only (chezscheme) include))
  (include "placeholder-consumer.scm"))]]
  REPLACE [[  (import (rnrs) (only (chezscheme) include))
  (include "placeholder.scm")
  (include "placeholder-consumer.scm"))]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

if(BYTE_MACHINE_GAMBIT_EXECUTABLE)
  byte_machine_mutation_reset()

  set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
    "${BYTE_MACHINE_GAMBIT_EXECUTABLE}"
    "-:search=${STAGE_DIR}/test/support/harness/gambit,search=${STAGE_DIR}/src/gambit"
    "-f"
    "${STAGE_DIR}/test/common/placeholder-identity-tests.gambit.scm")

  byte_machine_mutation(
    FILE ${GAMBIT_CONSUMER_WRAPPER} SPEC placeholder-identity-tests.gambit.scm
    LABEL "consumer wrapper on gambit: includes the owner's body instead of importing the owner"
    FIND [[  (import (scheme base) (byte-machine placeholder))
  (include "../../common/byte-machine/placeholder-consumer.scm"))]]
    REPLACE [[  (import (scheme base))
  (include "../../common/byte-machine/placeholder.scm")
  (include "../../common/byte-machine/placeholder-consumer.scm"))]])

  byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
endif()
```

- [ ] **Step 2: Update the counters to their final values**

Change:

```cmake
set(EXPECTED_PASSES_WITH_GAMBIT 25)
set(EXPECTED_MUTATIONS_WITH_GAMBIT 62)
```

to:

```cmake
set(EXPECTED_PASSES_WITH_GAMBIT 27)
set(EXPECTED_MUTATIONS_WITH_GAMBIT 64)
```

and change:

```cmake
set(GAMBIT_ONLY_PASSES 3)
set(GAMBIT_ONLY_MUTATIONS 10)
```

to:

```cmake
set(GAMBIT_ONLY_PASSES 4)
set(GAMBIT_ONLY_MUTATIONS 11)
```

- [ ] **Step 3: Update the header prose again**

Replace the block Task 2 wrote:

```
# TWENTY-FIVE PASSES WHEN GAMBIT IS DISCOVERED, BECAUSE TWENTY-FIVE
# DIFFERENT WITNESSES ARE NEEDED
#
# Three of the twenty-five are gated on BYTE_MACHINE_GAMBIT_EXECUTABLE, the
# same precondition every Gambit lane in this tree runs under: pass 2, the
# Gambit adapter's export list (one mutation); pass 10, the placeholder body's
# decisions run a second time on Gambit (six mutations, the same list pass 9
# declares for Chez); and pass 25, the consumer body's decisions on Gambit
# (three mutations, the same list pass 24 declares for Chez). Without Gambit
# this file runs twenty-two passes and fifty-two mutations rather than
# twenty-five passes and sixty-two -- the with-Gambit pair less that 3-pass,
# 10-mutation delta.
```

with:

```
# TWENTY-SEVEN PASSES WHEN GAMBIT IS DISCOVERED, BECAUSE TWENTY-SEVEN
# DIFFERENT WITNESSES ARE NEEDED
#
# Four of the twenty-seven are gated on BYTE_MACHINE_GAMBIT_EXECUTABLE, the
# same precondition every Gambit lane in this tree runs under: pass 2, the
# Gambit adapter's export list (one mutation); pass 10, the placeholder body's
# decisions run a second time on Gambit (six mutations, the same list pass 9
# declares for Chez); pass 25, the consumer body's decisions on Gambit (three
# mutations, the same list pass 24 declares for Chez); and pass 27, the Gambit
# consumer wrapper's double-include (one mutation, the per-runtime half of the
# section 7.2 proof pass 26 makes for Chez). Without Gambit this file runs
# twenty-three passes and fifty-three mutations rather than twenty-seven passes
# and sixty-four -- the with-Gambit pair less that 4-pass, 11-mutation delta.
```

Then replace `the "TWENTY-FIVE PASSES"` near the totals check with `the "TWENTY-SEVEN PASSES"`.

Finally, append to the paragraph Task 2 added after the working-directory-matrix paragraph:

```
# Passes 26 and 27 are the slice's reason for existing: the consumer wrapper
# made a second owner of the placeholder body, once per runtime. Unlike every
# other mutation in this file, the mutant raises nothing and exits 0 -- it
# answers both identity claims wrongly while every lane that imports only the
# owner still passes.
```

- [ ] **Step 4: Run the mutation suite**

```bash
cmake --preset dev && ctest --preset pr -R scheme-mutation --output-on-failure
```

Expected: passes, final status line `scheme mutation suite complete (27 passes, 64 mutations)`.

If either double-include mutation is reported as a **survivor**, do not add `EXPECT_SURVIVES`. A survivor here means the identity test is not actually comparing what it claims to — check that the test wrapper imports both libraries and that the `eq?` case was not weakened to `equal?`.

- [ ] **Step 5: Confirm the mutation is invisible to the other lanes**

This is the claim the design rests on, so verify it rather than trusting it. Apply the Chez mutation by hand, run the pre-existing placeholder lanes, and confirm they still pass:

The wrapper is committed as of Task 1, so `git checkout --` restores it and no backup copy is needed.

```bash
printf '%s\n' '(library (byte-machine placeholder-consumer)' '  (export consume)' '  (import (rnrs) (only (chezscheme) include))' '  (include "placeholder.scm")' '  (include "placeholder-consumer.scm"))' > src/chez/byte-machine/placeholder-consumer.sls
ctest --preset pr -R 'placeholder-cwd' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 6`. The six working-directory lanes are green while the tree contains the defect — which is what makes the identity lane the only witness. No reconfigure is needed: a `.sls` is not a configure input, and the lane reads it from the source tree at run time.

Now confirm the identity lane *does* catch it. This command is expected to FAIL, so run it on its own rather than chaining it:

```bash
ctest --preset pr -R 'placeholder-identity.*chez' --output-on-failure
```

Expected: the Chez identity lane fails, reporting **both** cases failed, with a nonzero exit and no raise in the output. Both failing is the point — one mutation, two independent clauses.

Restore the wrapper:

```bash
git checkout -- src/chez/byte-machine/placeholder-consumer.sls
```

- [ ] **Step 6: Confirm the tree is clean and the suite is green**

```bash
git diff --stat src/ && make test
```

Expected: `git diff` on `src/` is empty (the wrapper was restored), and `100% tests passed, 0 tests failed out of 40`.

- [ ] **Step 7: Commit**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: a consumer that double-includes the owner's body fails the identity lane (M0 slice 4)"
```

---

### Task 4: Decision record and changelog

**Files:**
- Create: `docs/decisions/0003-cross-library-identity.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing executable. Records what Tasks 1–3 established.
- Produces: nothing later tasks read.

- [ ] **Step 1: Read the existing decision records for format**

```bash
cat docs/decisions/README.md && head -40 docs/decisions/0002-shared-body-include-mechanism.md
```

Match the heading structure: `# NNNN: <one-line decision>`, then Date / Status / Milestone, then Context, Measurements, Decision, Consequences.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0003-cross-library-identity.md`:

```markdown
# 0003: A second library imports the owner, and a mutation is what enforces it

Date: 2026-08-17
Status: accepted
Milestone: 0, slice 4

## Context

Parent plan [byte-machine-implementation-plan.md](../plans/byte-machine-implementation-plan.md)
§7.2 requires that each shared body be included by exactly one implementation
library per runtime, and that other libraries import that owner rather than
including the body again. Its stated reason is that a second include gives
tagged-vector type tags and allocation-free singletons a second identity.

Slice 3 built the first owner and chose the representation that makes a
violation visible — a freshly allocated tag and marker, never symbols — but
could not witness one, because a single library cannot. Slice 4 adds the second
library and the test that can fail. See
[the slice-4 design](../plans/milestone-0-slice-4-cross-library-identity.md).

## Measurements

Measured 2026-08-17, Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8, against the
real Chez launcher and the shipped placeholder body.

- **A shared body can name another library's exports as free identifiers, on
  both runtimes.** `placeholder-consumer.scm` defines only `consume` and refers
  to `placeholder?`, `placeholder-value` and `placeholder-marker`, which its
  wrapper's import list supplies. Both runtimes resolve them, from a working
  directory containing neither body. This is the mechanism Milestone 1 runs on
  and nothing in the tree exercised it before this slice.

- **The double-include defect is silent.** With the consumer wrapper's import
  replaced by an `include` of the owner's body, both runtimes exit 0 and answer
  both identity claims wrongly. Nothing raises. The six
  `byte-machine.portability.placeholder-cwd-*` lanes stay green, because they
  import only the owner. This is §7.2's "both looking correct in isolation" in
  its literal form.

- **Chez and Gambit disagree about a library body that redefines an imported
  name.** Given a wrapper that both imports `(byte-machine placeholder)` and
  includes that library's body, Chez refuses to construct the library:
  `Exception: multiple definitions for make-placeholder and other identifiers in
  body`. Gambit constructs it and answers every question correctly. This record
  states the measurement, not a rule — see Consequences.

## Decision

1. **The consumer library imports the owner and is given its own shared body.**
   A bodiless re-exporter would satisfy deliverable D3 as written and leave the
   free-identifier mechanism unproved until Milestone 1 needed it.

2. **§7.2's "exactly one owner per body" is enforced by mutation, not by a
   configure-time guard.** Passes 26 and 27 of
   `test/support/cmake/SchemeMutationSuite.cmake` replace each consumer
   wrapper's import with an include and require the identity lane to fail. A
   mutation proves the defect is caught; a text scan would prove only that it is
   discouraged, and a commented-out include satisfies one. Slice 3 §3.1 rejected
   the guard and its reason has not changed.

3. **The mutation replaces the import; it never adds to it.** Forced by the
   third measurement: the augmenting variant fails on Chez for a reason
   unrelated to identity, which the runner's caught-for-the-declared-reason
   check rejects, and does not fail on Gambit at all.

## Consequences

- **The deferred one-owner guard is recorded here, where ownership is the
  subject.** It reopens when a shared body exists with no lane registered
  against it — at that point a missing or duplicated wrapper stops being caught
  at import, which is what currently makes the guard unnecessary. Slice 3
  recorded the same deferral in a document about the include *mechanism*;
  whoever adds Milestone 1's second library over an existing body will be
  reasoning about ownership and would not have looked there.

- **The identity test does not catch a second independent owner.** It catches a
  *consumer* that double-includes. A second owner wrapper that nothing imports
  alongside the first stays invisible, by the same slice-3 decision.

- **What Gambit does with a body that redefines an imported name is an open
  question, not a finding.** The measurement establishes that the construction
  does not fail; a follow-up probe using a deliberately wrong body produced
  results this slice could not reconcile into a single rule within its budget,
  and an inconclusive experiment is not a negative result. Milestone 1 builds
  several libraries over several bodies with real import graphs, and a runtime
  that silently accepts a name collision the other rejects is a portability
  hazard with no diagnostic. It needs its own measurement.

- **Identity under compiled lanes is untested.** Everything here is source mode,
  where separate instantiation is modelled rather than real. Slice 5 registers
  these same two programs against the Chez AOT, Gambit `.o1`, and `gsc -exe`
  lanes, which is where the risk is genuine.

- All measurements are single-host, single-version: one macOS arm64 machine,
  Chez 10.4.1, Gambit 4.9.8. Nothing here is a claim about any other release or
  Tier 1 platform.
```

- [ ] **Step 3: Add the changelog entry**

Open `CHANGELOG.md`, find the `Unreleased` section, and add under it — matching the existing entry style, which is prose describing what became provable rather than a bare file list:

```markdown
### Added

- Cross-library identity proof (Milestone 0 slice 4, deliverable D3). A second
  library per runtime, `(byte-machine placeholder-consumer)`, built over its own
  wrapper-free body whose free identifiers are supplied by the wrapper's import
  of `(byte-machine placeholder)`. A shared test body importing both libraries
  asserts that a value built through the owner is recognised through the
  consumer, and that the allocation-free singleton is one object across both
  imports.
- The consumer body additionally proves a mechanism Milestone 1 depends on and
  nothing previously exercised: a shared body naming another library's exports
  as free identifiers, resolved identically by R6RS library-body `include` and
  R7RS `define-library` `include`.
- Eight Scheme mutations in four passes (24 to 27), bringing the suite to 27
  passes and 64 mutations. The decisive two replace each consumer wrapper's
  import with an include of the owner's body: the mutant exits 0 on both
  runtimes, raises nothing, answers both identity claims wrongly, and leaves
  every lane that imports only the owner green.
- Decision record 0003, including the deferred one-owner guard with the
  condition that reopens it, and an open question about Chez and Gambit
  disagreeing over a library body that redefines an imported name.
```

- [ ] **Step 4: Verify the whole suite one more time**

```bash
make test && make dev
```

Expected: `100% tests passed, 0 tests failed out of 40` from `make test`, and the harness selection green from `make dev`.

- [ ] **Step 5: Verify the no-scheme preset**

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 10`.

- [ ] **Step 6: Commit**

```bash
git add docs/decisions/0003-cross-library-identity.md CHANGELOG.md
git commit -m "docs: record the cross-library identity decisions and what stays open (M0 slice 4)"
```

---

## Exit criteria for the slice

Check every line before declaring the slice done. Each is a command with an expected output, not a judgement.

- [ ] `make test` reports `100% tests passed, 0 tests failed out of 40`.
- [ ] `ctest --preset pr -R scheme-mutation --output-on-failure` reports `scheme mutation suite complete (27 passes, 64 mutations)`.
- [ ] `ctest --preset pr -R cmake-mutation --output-on-failure` still reports 96 CMake mutations — this slice edits no `cmake/` module.
- [ ] `cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure` reports 10/10.
- [ ] `git diff --stat cmake/` is empty.
- [ ] No `EXPECT_SURVIVES` was added anywhere in this slice.
- [ ] `docs/decisions/0003-cross-library-identity.md` exists and states the U4 deferral's reopening condition and the carried-forward open question.
