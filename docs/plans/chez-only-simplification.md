# The Chez-Only Simplification: Plan Update and Removal Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Status: executed; delivered 2026-08-18 (PR #7). §6's named follow-up, the include collapse, delivered 2026-08-20 (decision 0006, PR #8) — §6 carries the delivery note and measured outcome
Date: 2026-08-18
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) — this document is the "explicit plan update" its §2 requires before a fixed decision changes
Milestone plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — amended by Task 1, not rewritten
Branch: `docs/chez-only-plan-update`, stacked on `feat/m0-slice-5b-chez-aot` (PR #6)

**Goal:** Remove Gambit and R7RS from the project contract, leaving one runtime (Chez Scheme), one dialect (R6RS), and two execution lanes (Chez source, Chez AOT).

**Architecture:** Phase A (this plan) amends every governing document and then deletes the second runtime from the harness in dependency order — pairing guard first, then Gambit lanes and files, then the Gambit toolchain layer — with the full suite green after every task. The single-runtime indirection that remains (shared-body `include`, `source-directories`, the one-owner rule) is untouched here and is retired by a named follow-up slice with its own design.

**Tech Stack:** CMake ≥ 3.26 / CTest presets, Chez Scheme ≥ 10.4.1, GNU make as the thin Unix frontend.

## Global Constraints

- Every task ends with `make test-all` green (fresh configure where noted) and a Conventional Commit.
- AGENTS.md mutation rules remain in force during removal: a spec's declared pass/mutation totals must be updated in the same commit as the passes it loses, and after any change to registrations or exits the **whole** mutation suite is re-run, not just the affected lanes.
- CHANGELOG entries under released versions are history and are never edited. Only the unreleased section changes.
- Phase A deletes nothing that is not Gambit- or pairing-specific. The shared-body mechanism, the cwd-matrix lanes, the launchers' `--source-dir`, the one-owner mutations, and the fingerprint manifest all stay until the follow-up slice (§6).
- Execution starts only after PR #6 (slice 5b, Chez AOT) merges; rebase this branch onto `main` first. Slice 5b's remaining scope is Chez-side and is unchanged by this plan.

---

## 1. Why the contract changes

The dual-runtime requirement existed for one consumer: protium, whose plan required "one behaviorally identical Scheme API on Chez and Gambit." Protium is being replaced by a Chez-only libuv library. No remaining consumer requires Gambit, so byte-machine's second runtime now buys nothing and costs every future slice twice: two lane registrations per program, a pairing guard over every shared body, the R6RS∩R7RS dialect ceiling on all product code, and a mutation suite that carries a with/without-Gambit counting delta.

Measured against the shipped tree on 2026-08-18 (branch `feat/m0-slice-5b-chez-aot`): the harness (`cmake/` + `test/support/`) is 9,858 lines against ~150 lines of product code. Of that, whole files that exist only for Gambit or for the `.scm`/`.gambit.scm` pairing convention measure 1,387 lines, with further Gambit-only regions inside shared files on top of that (an unmeasured estimate; [decision 0005](../decisions/0005-chez-only.md) records the measured figures and their commands). An entire planned slice (5c, Gambit's two compiled modes) exists only for Gambit, and three of the harness's four hardest mechanisms (pairing guard, shared-body ownership, cross-runtime fingerprint agreement) exist only to serve the second runtime.

**What this rules out.** Re-adding Gambit later means rebuilding, not un-commenting: the mechanisms deleted here are exactly what slices 2–5 spent building and proving falsifiable. This is accepted as a one-way door.

**What this does not change.** OS/architecture portability (macOS/Linux/Windows, amd64/arm64) stays in the contract. Determinism of generated source stays, restated as a single-implementation, cross-platform claim. The provenance discipline for compiled lanes (a lane must be structurally unable to fall back to source; fingerprints describe what an artifact was built from) stays — it is Chez-internal and slice 5b's whole point.

## 2. The amended decisions (parent plan)

Task 1 applies these to `docs/plans/byte-machine-implementation-plan.md`. Normative sites get exact replacement text below. Incidental prose mentions of Gambit/R7RS ("Chez and Gambit", "both implementations", "either runtime") are rewritten by this rule: **name Chez alone, drop the comparative clause, and keep the sentence's requirement intact.** The acceptance gate is the `rg` check in Task 1, not line-by-line enumeration.

| Site | Current (abbreviated) | Replacement text (exact) |
| --- | --- | --- |
| §2 decision 2 | "…emits deterministic portable Scheme." | "A pure verifier/compiler transforms the source IR and an offline generator emits deterministic R6RS Scheme." |
| §2 decision 9 | "One portable backend targets both Chez and Gambit. Thin implementation-specific library wrappers isolate module and compatibility differences." | "The backend targets Chez Scheme. Libraries are ordinary R6RS `.sls`; no cross-implementation wrapper layer exists. (Amended 2026-08-18 — see [decision 0005](../decisions/0005-chez-only.md).)" |
| §2 decision 10 | "Implementation-specific backends are permitted only when reproducible compiled benchmarks demonstrate a material need." | "Chez-specific emission — fixnum operations, unsafe declarations, or any identifier outside plain R6RS — is permitted only when reproducible compiled benchmarks demonstrate a material need." |
| §3.1 goal | "Emit deterministic wrapper-free portable Scheme source." | "Emit deterministic wrapper-free R6RS Scheme source." |
| §3.2 quality goal | "Portable behavior across the supported Chez/Gambit and OS/architecture matrix." | "Portable behavior across the supported OS/architecture matrix on Chez Scheme." |
| §4 non-goal | "Chez- or Gambit-specific emitters without benchmark evidence." | "Emitter variants beyond the direct-code backend without benchmark evidence." |
| §7.1 "Avoid in shared code" list | Twelve dialect-intersection bullets (no R6RS/R7RS library forms, no implementation record systems, no hash tables, `#vu8` vs `#u8`, `bytevector-copy!` signatures, no Chez fixnum ops or Gambit `##` primitives, …) | Replace the list and its preamble with: "Product code is plain R6RS. Two correctness rules survive from the portability era because they were never about dialect: never rely on unspecified argument evaluation order, and never put implementation exception text in a behavioral contract. Chez extensions are admitted only through §2 decision 10." |
| §7.2 "Library wrappers" | Chez `.sls` + Gambit `.sld` wrappers; one-owner include rule | Keep the section name, replace the wrapper paragraphs with: "Libraries are R6RS `.sls`. During the transition, the shared-body `include` mechanism and the one-owner rule of decisions 0002/0003 remain in force exactly as decided; the follow-up slice named in [chez-only-simplification.md](./chez-only-simplification.md) §6 retires them by moving each body inline into its owning library." The internal dependency diagram and the `runtime`/`interpret` singleton-identity paragraph stay unchanged — that defect class is about library structure, not about Gambit. |
| §7.3 tiers | Eight Tier 1 cells, "Chez and Gambit on …" | "Tier 1 release gates: Chez on Linux amd64; Chez on Linux arm64; Chez on macOS arm64; Chez on Windows amd64 — each in both source and AOT execution. Tier 2: macOS amd64, Windows arm64, additional supported Chez versions." The coverage-claim paragraph and the explicit-update rule for waiving a cell stay. |
| §8 layout | `src/common/` + `src/chez/` + `src/gambit/` trees | Show the post-follow-up target: `src/byte-machine/*.sls`, `test/`, `bench/`, `examples/`, with the note: "`src/common/` and `src/chez/` remain in place until the §6 follow-up slice collapses them; the second-runtime source tree is deleted by [chez-only-simplification.md](./chez-only-simplification.md)." (The path itself stays out of the note so Task 1's zero-hits gate holds; this plan's Task 3 names it.) |
| §9 reserved bindings | "…reserved by either supported R6RS or R7RS source mode…" | "…reserved by the R6RS source mode, including library and include forms;" |
| §9.6 Milestone 1 examples | "two executable examples—one Chez program and one Gambit program—" | "one executable Chez example program, run in both the source and AOT lanes," |
| §22.2 harness runners | "Thin Chez/Gambit runners provide imports, process exit, and implementation compilation steps." | "A thin Chez runner provides imports, process exit, and compilation steps." (The vendored, dependency-free harness stays.) |
| Emission determinism | "…Chez and Gambit must emit byte-identical UTF-8/LF source." | "…generation must emit byte-identical UTF-8/LF source on every supported platform cell." |
| §24 CI | Both implementations; Gambit native toolchain pinning paragraph | Chez only on the same OS/arch cells; delete the Gambit native-jobs paragraph. Milestone exit items: "pinned minimum Chez version", "confirmed R6RS library and include strategy". |
| Release criteria | "deterministic generation passes between Chez and Gambit"; "generated-code integration guide for Chez and Gambit" | "deterministic generation passes across supported platform cells"; "generated-code integration guide for Chez". |
| Risks | "R6RS/R7RS module incompatibility" risk section | Delete the section; decision 0005 records its retirement. |

## 3. The amended standards (AGENTS.md)

- Replace: "Shared `.scm` bodies use only the R6RS/R7RS common subset and never name Chez or Gambit; runtime-specific code lives only in the thin `.sls`/`.sld` wrappers. R6RS forbids assigning an exported variable — reach mutable state through procedures."
  With: "Libraries are R6RS `.sls`. Until the include-collapse slice lands, shared `.scm` bodies contain no library or include form and are included by exactly one owner library. R6RS forbids assigning an exported variable — reach mutable state through procedures."
- Replace: "Project should be portable across Chez and Gambit Scheme"
  With: "Project targets Chez Scheme (R6RS) only — see docs/decisions/0005-chez-only.md"
- Keep every lesson bullet unchanged, including the ones whose examples name Gambit (the backend-gating lesson, the slice-5a exit-path lesson). They are history and generalize beyond the runtime that taught them. (Corrected after the final whole-branch review: this held through Task 1, but Task 4's literal-token gate (`rg -n -i --hidden 'gambit' --glob '!docs/**' ...`) forced the backend-gating lesson to drop "Gambit lane" from its example while keeping the lesson itself, because AGENTS.md sits outside the gate's `docs/` exclusion. One lesson bullet changed, not zero as this line implied; decision 0005's Consequences records it as the third of AGENTS.md's three amended bullets.)

## 4. New decision record

Task 1 creates `docs/decisions/0005-chez-only.md` with: Context (protium replaced by a Chez-only libuv library; the 2026-08-18 harness measurements from §1), Decision (Chez/R6RS only; two lanes; slice 5c cancelled; one-way door accepted), and Consequences: decisions 0001–0004 stand as historical records — 0001's Gambit half and 0004's cross-runtime-agreement claim become historical rather than superseded, while 0002 and 0003 remain **in force** until the §6 follow-up slice, which is what will add supersession headers to them.

`milestone-0-portability-spike.md` and `milestone-0-slice-5b-5c-compiled-lanes.md` each gain a dated header note (records stay, per the decisions README): D5 closes at two lanes; 5c is cancelled; D6 becomes a single-implementation determinism proof; D8's CI covers Chez only; 5b's scope is unchanged.

## 5. Removal tasks

Phase A only. Every deletion task follows the same shape: show the thing exists, remove it and its spec's declared totals together, re-run the full suite, commit.

### Task 1: The written law changes first

**Files:**
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§2 table above)
- Modify: `AGENTS.md` (§3 above)
- Create: `docs/decisions/0005-chez-only.md` (§4 above)
- Modify: `docs/plans/milestone-0-portability-spike.md`, `docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md` (header notes, §4 above)
- Modify: `README.org` (project description names Chez alone; drop the "Gambit 4.9.8 or newer" requirement bullet)

**Steps:**
- [ ] Apply the §2 replacement table, then sweep the parent plan with `rg -n -i 'gambit|r7rs' docs/plans/byte-machine-implementation-plan.md` and rewrite every remaining hit by the §2 rule. Expected after: zero hits.
- [ ] Apply the §3 AGENTS.md edits. `rg -n -i 'gambit' AGENTS.md` afterwards must show only the two lesson bullets.
- [ ] Write `0005-chez-only.md`; add the two header notes; amend `README.org`.
- [ ] Run `make test` — docs must not affect it. Expected: same pass count as before the edits.
- [ ] Commit: `docs: the plan update — Gambit and R7RS leave the contract`

### Task 2: The pairing rule has nothing left to guard

The portability guard enforces **two** rules: `.scm`/`.gambit.scm` twinning (every wrapped body paired), which stops being law in Task 1, and shared-body basename uniqueness, which the Chez `include`/`source-directories` mechanism still requires and which this plan's constraints keep until the §6 follow-up (`ByteMachineSchemeLane.cmake`'s staging comment leans on it by name). So the pairing **rule** is removed from the module, not the module: `byte_machine_guard_duplicate_basenames` and its enforcement stay. The pairing half goes before any twin file does, so the tree is never in a state a still-registered check rejects. (Re-scoped from "delete the module" after Task 1 landed — the original wording contradicted the Phase A protection list.)

**Files:**
- Modify: `cmake/ByteMachinePortabilityGuard.cmake` (remove the pairing rule and its reporting; keep basename-uniqueness detection and enforcement; rewrite the header comment for a one-rule guard), `test/support/cmake/ByteMachinePortabilityGuardSpec.cmake` (drop pairing passes, keep uniqueness passes, adjust declared totals), `test/CMakeLists.txt` (pairing-specific guard arguments and fixtures go; the uniqueness invocation and the `byte-machine.harness.cmake-portability-guard.cmake.direct` spec lane stay), mutation-suite passes and declared totals that target the pairing half
- `CMakeLists.txt` keeps `include(ByteMachinePortabilityGuard)` — the module still exists until the follow-up slice deletes it whole.

**Steps:**
- [ ] `ctest --preset release -N | rg portability-guard` — expected: the guard spec lane prints (it stays registered).
- [ ] Remove the pairing rule per the file list; `rg -n -i 'pair' cmake/ByteMachinePortabilityGuard.cmake` afterwards should show no live pairing logic, while `byte_machine_guard_duplicate_basenames` still exists and is still invoked.
- [ ] Adjust each touched spec's declared pass/mutation totals in the same edit as the passes they lose.
- [ ] `make clean && make test-all` — expected: green, the guard spec lane still passes (now over one rule), and every remaining mutation pass still shows baseline/mutant differing for its named reason.
- [ ] Commit: `refactor: remove the pairing rule — the convention it enforced is no longer law`

### Task 3: The Gambit lanes and the Gambit halves of the tests

**Files:**
- Modify: `test/CMakeLists.txt` — every `BACKEND gambit` registration (bootstrap, self, failing-body, duplicate-case, empty-selection, cwd-matrix, identity, provenance, unreached-provenance) and the `BYTE_MACHINE_HARNESS_GAMBIT_LIBRARY_ROOT` / `BYTE_MACHINE_SRC_GAMBIT_LIBRARY_ROOT` roots
- Delete: every `*.gambit.scm` under `test/` (8 files), `test/support/harness/gambit/`, `test/gambit/`, `src/gambit/`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` — Gambit passes go, and the with/without-Gambit count arithmetic (the declared "Gambit-only delta") collapses into a single set of expected totals

**Steps:**
- [ ] `ctest --preset release -N | rg -i gambit | wc -l` — expected: nonzero. Record the number.
- [ ] Deregister and delete per the file list; collapse the mutation-suite totals.
- [ ] `make test-all` then `ctest --preset release -N | rg -i gambit` — expected: green; exactly one hit, `byte-machine.harness.cmake-gambit.cmake.direct`, the toolchain module's own spec lane (BACKEND cmake, not gambit) — Task 4 removes it with the module. (Gate corrected after Task 2: "empty" was wrong while the module survives.)
- [ ] Commit: `refactor: remove the Gambit lanes and their test halves`

### Task 4: The Gambit toolchain layer itself

**Files:**
- Delete: `cmake/ByteMachineGambit.cmake`, `cmake/gambit-probe.scm`, `test/support/cmake/ByteMachineGambitSpec.cmake`
- Modify: `README.org` (the remaining Gambit build-layer prose: the `gsi`/`gsc` discovery paragraph, the `gcc-16` requirement, and the `-DBYTE_MACHINE_GAMBIT_EXECUTABLE` example — accurate until this task, stale after it), `CMakeLists.txt` (option `BYTE_MACHINE_REQUIRE_GAMBIT`, `include(ByteMachineGambit)`, the discover call, the status line, the project `DESCRIPTION`, and the `LANGUAGES NONE` comment's Gambit rationale), `Makefile` (help/doctor text and the `-DBYTE_MACHINE_GAMBIT_EXECUTABLE` hint), `cmake/ByteMachineTesting.cmake` (`BYTE_MACHINE_TEST_BACKENDS`, `BYTE_MACHINE_TEST_MODES_gambit`, comments), `cmake/ByteMachineSchemeLane.cmake` (`byte_machine_scheme_lane_gambit_search`, the gambit backend branch, "Known backends: chez gambit." messages) with `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` expectations updated in step, plus the lone reference in `test/support/harness/shared/harness-runner.scm`, and the `byte-machine.harness.cmake-gambit.cmake.direct` spec-lane registration

**Steps:**
- [ ] Delete and edit per the list, then sweep: `rg -n -i --hidden 'gambit' --glob '!docs/**' --glob '!CHANGELOG.md' --glob '!.git/**' .` — expected: empty. (`--hidden` added after review: the gate as first written skipped dotfiles and missed `.gitignore`.)
- [ ] `make clean && make test-all` (the option set changed; the configure must be fresh) — expected: green, and the configure status line names Chez only.
- [ ] Confirm discovery still fails loudly with no runtime: `cmake --preset dev -DBYTE_MACHINE_CHEZ_EXECUTABLE=/nonexistent` — expected: configure fails with the Chez probe's own diagnostic, not a Gambit message.
- [ ] Commit: `refactor: remove the Gambit toolchain layer`

### Task 5: The record of the cut

**Files:**
- Modify: `CHANGELOG.md` (unreleased section only)

**Steps:**
- [ ] Add an unreleased entry: the contract change (0005), the guard/lanes/toolchain removals, the cancelled slice 5c, and a pointer to the §6 follow-up. Released entries stay untouched.
- [ ] `make test-all` — expected: green.
- [ ] Commit: `chore: changelog for the Chez-only cut`
- [ ] Open a PR titled "The Chez-only simplification: plan update and Gambit removal" against `main`.

## 6. The named follow-up: collapsing the single-runtime indirection

> Delivered: designed by
> [milestone-0-include-collapse.md](./milestone-0-include-collapse.md),
> implemented by
> [milestone-0-include-collapse-implementation-plan.md](./milestone-0-include-collapse-implementation-plan.md),
> recorded as [decision 0006](../decisions/0006-inline-libraries.md).
> Measured outcome, 2026-08-18, at that slice's exit gate: the harness landed
> at 7,713 lines (`cmake/` + `test/support/`; 8,327 after this plan's own cut,
> ~9,858 before it) and `src/` at 84. This section's 4,000–4,500 estimate was
> wrong about where the harness's weight lives — the mutation suite's decision
> coverage, which both slices deliberately keep, was always the bulk, and the
> include-era machinery a smaller share than estimated.

Out of scope here; it changes design, not just inventory, so per project convention it gets its own design document and implementation plan. Its scope, fixed now so Phase A reviewers know where the line is:

- Move each shared body inline into its owning `.sls`; delete `src/common/` and the harness `shared/` include split.
- Retire the `include`/`source-directories` mechanism: launchers lose `--source-dir`, the cwd-matrix decoy lanes retire, and the shared-body basename-uniqueness check goes with them. (Sharpened after the final whole-branch review: `byte_machine_guard_shared_bodies`'s wrapper-filter regex is, after this branch, witnessed only by `ByteMachinePortabilityGuardSpec.cmake`'s pure-function assertions against invented paths — no file in the tree matches it for a real configure to exercise. Chez wrappers already fell outside the guard's `*.scm` glob before this branch, and the `.gambit.scm` wrappers that used to be the regex's one real-file match are gone with Gambit. This is a carry note the review established, not a new gap; it means nothing needs to be separately re-proven working before this bullet deletes the check.)
- Retire the one-owner rule and its mutation passes — with no `include`, the double-instantiation defect class is unconstructible.
- Re-scope the fingerprint manifest to fingerprint library sources; the declared-manifest and AOT-provenance discipline of decisions 0004/slice 5b is kept.
- Add supersession headers to decisions 0002 and 0003 pointing at that slice's decision record.

**Acceptance gate, added after the final whole-branch review:** before this slice is called done, re-run the semantic-vocabulary sweep —
`rg -n -i 'both runtimes|both adapters|both wrappers|two wrappers|each runtime|per runtime|two standards|r7rs|parity proof' src test`
— and confirm it is clean except deliberate, named survivals. Task 1's `rg -n -i 'gambit|r7rs'` gate and Task 4's `--hidden 'gambit'` gate both matched on literal runtime names; they could not and did not catch a comment that had drifted to describe a two-runtime world without naming either runtime (`both wrappers`, `each runtime`, `parity proof`, and the like) — a whole final review pass was needed to find those by reading, not by grep. Closing this gate by rule rather than by memory is what makes the same gap not recur when this slice collapses the remaining indirection.

Expected end state after both phases, measured from today's baseline: the harness drops from ~9,900 lines toward roughly 4,000–4,500, the lane matrix is exactly `chez.source` and `chez.aot`, and product code is free to use full R6RS.

## Self-review notes

- Every §2 amendment site is covered by Task 1's steps; incidental prose is gated by the `rg` sweep rather than enumerated.
- Ordering: guard (Task 2) precedes twin-file deletion (Task 3) so no intermediate tree violates a still-registered check; toolchain (Task 4) goes last so lanes never reference a deleted module.
- Declared-totals rule: Tasks 2 and 3 both name it, because both suites carry expected counts and a green run with stale counts is exactly the false comfort AGENTS.md warns about.
