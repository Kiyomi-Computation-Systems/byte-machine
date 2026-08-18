# Milestone 0, Slices 5b and 5c: The compiled execution lanes

Status: design agreed; ready for an implementation plan
Date: 2026-08-17
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §22.2, §24.2
Milestone plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — deliverable D5, work-order item 5
Previous slice: [`milestone-0-slice-5a-content-fingerprint.md`](./milestone-0-slice-5a-content-fingerprint.md)
Scope: **the three compiled lanes, and the mechanism that binds a fingerprint to an artifact rather
than to today's source.** Slice 5b is Chez AOT and the binding mechanism; slice 5c is Gambit `.o1`
and `gsc -exe -nopreload`. D5 closes at the end of 5c.

One document for two slices, because the binding mechanism spans them: 5b introduces it and 5c
consumes it. Each slice still gets its own implementation plan.

## 1. What these slices must prove

Slice 5a built the instrument and proved it falsifiable while nothing depended on it. These two
slices are what it was built to measure.

Four claims, each stated so it can be disproved:

1. **Each compiled lane runs its compiled artifact.** Not "reports that it does" — cannot do
   otherwise. All three lanes can degrade into a source lane while still exiting 0, and each
   degrades by a different mechanism, so each needs its own structural answer.
2. **A lane's fingerprint describes the text its artifact was built from**, not the text on disk at
   the moment it ran. Slice 5a's check cannot distinguish these, and for a source lane there is
   nothing to distinguish; for a compiled lane it is the whole question.
3. **All four lanes agree on one content fingerprint for one manifest.** This is D5's own wording,
   and 5c is where the fourth lane exists to agree.
4. **Cross-library identity survives compilation.** Slice 4 §10 deferred this here: separate
   instantiation is a modelled risk in source mode and a real one under Chez AOT, Gambit `.o1`, and
   `gsc -exe`.

Claim 2 is the one this design is mostly about. [Decision record
0004](../decisions/0004-content-fingerprint-and-provenance.md) states the gap it closes, demonstrated
against the shipped tree: a Chez object compiled from `harness-runner.scm`, that body edited
afterwards while `harness.sls` stayed untouched so the object remained current by Chez's own rule,
the expectation recomputed, the lane run — `fingerprint verified against the build manifest`, exit 0,
with the object provably lacking the edit.

## 2. Verified facts, and the difference between kinds of them

This section distinguishes three kinds of fact, because slice 4 paid for conflating two of them (see
[AGENTS.md](../../AGENTS.md) and the `scratch-fixture-measurements` standard).

### 2.1 Measured in this repository

| # | Fact | Where |
| --- | --- | --- |
| M1 | A Chez AOT lane can pass over a stale object: both sides of the fingerprint comparison read the same files on disk | Slice 5a final review, reproduced against the shipped tree |
| M2 | Shared-body basenames are unique repository-wide, enforced at configure time | `byte_machine_guard_duplicate_basenames`, `cmake/ByteMachinePortabilityGuard.cmake` |
| M3 | The test-name grammar already admits `chez.aot`, `gambit.o1`, `gambit.aot`, and rejects an incompatible backend/mode pair | `cmake/ByteMachineTesting.cmake` lines 43–57 |
| M4 | `harness-self-tests.scm` and `harness-bootstrap.scm` assert `(adapter-execution-mode)` against the literal `"source"`, and flipping the variable flips the exit status 0 → 1 | Slice 5a Task 7 review |
| M5 | Staging a shared body alone, without its tree, satisfies Chez and leaves Gambit compiling the unmutated original | `test/support/cmake/SchemeMutationSuite.cmake` lines 237–241 |
| M6 | The Scheme mutation suite cannot express "built before the edit, run after it": staging hands every pass one already-mutated tree | Slice 5a Task 6 |

### 2.2 Recorded by protium as measured there, read from its source, **not re-measured here**

Every row below is a claim protium's own comments make about protium's tree. They are strong priors
and they are why this design has a shape at all, but none has been reproduced against byte-machine.
An implementation plan may rely on them for *direction*; no exit criterion may rest on one until this
repository has seen it.

| # | protium's claim | Where in protium |
| --- | --- | --- |
| P1 | Chez treats an object whose recorded includes cannot be located as out of date and quietly loads the source instead; an empty `source-directories` is what prevents it | `tests/support/launchers/chez-aot.ss` |
| P2 | Gambit decides an object is current from its `.sld`'s timestamp alone and never consults the files that `.sld` includes | `cmake/ProtiumGambitStage.cmake` |
| P3 | `gsc -exe` with `-o` *after* `-exe` warns on **stdout**, exits 0, and reads the output path as one more input file | `cmake/ProtiumGambitLink.cmake` |
| P4 | `gsc -exe -nopreload . protium/harness.sld prog.scm` links cleanly and dies at startup with `Module not found`; naming the module rather than its file is what records the identity `import` asks for | `cmake/ProtiumGambitLink.cmake` |
| P5 | Every misplaced-option shape produces the one string `Unknown or improperly placed`, on stdout, followed by exit 0 and a usable-looking artifact | `ProtiumGambitStage.cmake`, `ProtiumGambitLink.cmake` |
| P6 | An emptied test program left its lane green: gsi ran a file with no forms and exited 0 | `cmake/ProtiumSchemeTesting.cmake` |

P4 is independently recorded in this project's own memory of the Gambit `-exe` module-linking trap,
so it is the one row with corroboration outside protium.

### 2.3 Structural facts about this repository, read from the tree

| # | Fact | Consequence |
| --- | --- | --- |
| S1 | Gambit `.sld` includes are source-file-relative and differ in depth per module: `../../../shared/fingerprint.scm` from `harness.sld`, `../../common/byte-machine/placeholder.scm` from `placeholder.sld` | Protium's flat "every body into one `shared/` directory above one library root" staging cannot transfer. Staging must preserve layout. |
| S2 | There are two Gambit library roots and three modules; Chez likewise has two library roots | Staging keeps two roots; `byte_machine_scheme_lane_gambit_search` already emits `search=A,search=B` |
| S3 | `byte_machine_add_scheme_lane` derives both the expectation and `BYTE_MACHINE_FINGERPRINT_FILES` from one `SHARED_BODIES` list | The two-list split of §4 is the smallest change that lets them differ |
| S4 | Both Gambit compiled modes shell out to a C compiler fixed when Gambit was built | A host with `gsi` but no C toolchain must skip the compiled lanes, not fail |

## 3. Decisions taken

Continuing the per-slice labelling: slice 2 used `S`, slice 3 used `T`, slice 4 used `U`, slice 5a
used `V`. Mutation labels are mnemonic per slice and use `C` here (slice 4's mutations used `W`,
which is why decisions continue past it).

| # | Decision | Rationale |
| --- | --- | --- |
| W1 | V1's boundary is **kept**: 5b is Chez AOT, 5c is both Gambit compiled modes. Reconsidered against the protium measurement rather than inherited | One runtime per slice keeps a new lane's first failure unconfounded, which was V1's own reason and still holds. The imbalance that made reopening tempting is resolved by W2 and W9: 5b now carries the binding mechanism, the mode plumbing and slice 5a's debt, which makes it a slice rather than two launchers. The alternative considered and rejected — 5b = Chez AOT + Gambit `.o1` grouped by shared hazard, 5c = `-exe` — is tidier about hazards and worse about attribution, since it puts two runtimes' machinery in one slice. |
| W2 | A compiled lane's fingerprint is computed over **copies made by the build step that produced the artifact**, while the expectation stays computed from the repository originals | A stale artifact then carries stale copies, the two disagree, and the lane exits 3. This is protium's mechanism for its Gambit lanes; protium does *not* apply it to Chez AOT, where it fingerprints repository originals and relies solely on `DEPENDS`. |
| W3 | This **supersedes** decision record 0004's named direction (a build-time literal `include`d into the wrapper so the value is compiled into the artifact) | 0004 dismissed W2 as having "nowhere to enter this tree today … one list, not two". That is a statement about the current signature, not a principle: protium's lane functions return exactly that second list. The literal is strictly stronger — the value lives inside the object — but its cost is asymmetric and was not measured when 0004 was written. Chez can reach a generated file through `source-directories`; Gambit's `include` is source-file-relative, so the repository `.sld` would have to name a path resolving both in the repository (for the `gsi` source lane) and in a staged tree, which means a checked-in placeholder whose content is wrong for every source lane, staged wrapper text differing from repository wrapper text, and mutation-suite staging changes. W2 touches no Scheme library source at all. |
| W4 | `SHARED_BODIES` keeps its name, its meaning, and its required status; the *measured* paths are a second output of the lane-command function, never a second registration argument | V9's guarantee is that a lane cannot be registered without provenance. A second argument would be a second thing to forget. A computed output cannot be omitted by a registration. |
| W5 | Every compiled lane measures `<its build directory>/fingerprint/<basename>` — one rule for all three | M2 makes a flat directory keyed by basename unambiguous by construction. Protium needs per-lane path logic here precisely because it has no equivalent guard. |
| W6 | The copy step lives in the **same** `add_custom_command` as the compile or link | Copies and artifact then share one producer and cannot be separately stale. This is the whole of W2's strength, and it is weaker than a value carried inside the artifact: a hand-disturbed build tree can desynchronise them. Recorded as a bound, not glossed. |
| W7 | The measured-path computation lives in the **functional core**, reachable under `cmake -P` with no Scheme present | The `no-scheme` preset is the only witness available on a host with no runtime, and slice 7's second platform is the first time the compiled lanes meet a host this project has not run on. |
| W8 | The in-process `(adapter-execution-mode)` assertions generalise from the literal `"source"` to "a member of the known vocabulary, not `unknown`" | Deliberate weakening, and the record must say so. That assertion's real job is catching an environment that never reached the process (M4). The claim *this lane is genuinely AOT* is carried by the lane's structure and proved by mutation, never by an in-process string comparison — comparing against a registration-supplied expected mode would only compare the environment with itself. A second and stronger reason was found while implementing this: the self-tests body is staged inside the Scheme mutation suite's own lane, which hand-sets `BYTE_MACHINE_EXECUTION_MODE=source` whatever it stages, so a name-versus-mode cross-check in that body would be red on every mutation pass's baseline rather than only on a broken one. |
| W9 | Slice 5a's carried-forward items 2–4 land in 5b as one task | 5b edits the same files, and the reasoning is still fresh. Written by someone who no longer remembers why a decision exists, a mutation tests the decision's spelling rather than the decision. |
| W10 | Staging for the Gambit lanes preserves each tree's layout, and is a **separate script** from `byte_machine_mutation_stage` rather than a shared function | Same technique, different inputs: the mutation suite stages a repository subset including `cmake/` and the specifications; a lane stages Gambit roots plus bodies. The precedent is cited in the new script so the next reader finds both. S1 and M5 are why flattening is not an option. |
| W11 | A host with `gsi` but no working C toolchain **skips** the Gambit compiled lanes with a named message | S4. This mirrors the existing `no-runtime` return, which already establishes that an absent capability is a skip with a sentence, not a configuration failure. |
| W12 | Every staleness claim is proved by a registered CTest lane, never by a Scheme mutation | M6. Recorded explicitly so a later reader does not move one into the mutation suite and declare a survivor when it cannot be witnessed there. |

## 4. The two-list split

`byte_machine_scheme_lane_command` gains an output. Where it returns a command today, it returns a
command and the list of paths the run will measure.

```
byte_machine_scheme_lane_command(<backend> <mode> <program>
                                 <out_command> <out_measured>
                                 <out_status> <out_message>
                                 <declared-body>...)
```

- **Declared** — `SHARED_BODIES`, unchanged. Still required, still the expectation's input, still the
  configure-time guarantee. It is what the registration *claims* the lane runs.
- **Measured** — what the run actually reads, and therefore what `BYTE_MACHINE_FINGERPRINT_FILES`
  names. For a source lane it is the declared list, so nothing about the existing registrations
  changes. For a compiled lane it is the `fingerprint/` copies (W5).

Two invariants:

- **Order is preserved.** `harness-fingerprint-combine` is order-sensitive by design (5a decision,
  mutation F5), so `measured[i]` must correspond to `declared[i]`. Walk the declared list and map
  each entry; never partition and rejoin. Protium's `.o1` lane carries the same warning for the same
  reason.
- **A source lane's two lists are the same list**, not two lists that happen to agree. The
  distinction matters to the mutation in §7 that makes a compiled lane return the declared list: it
  must break compiled lanes and leave source lanes untouched.

What this does **not** close: the manifest is still *declared* rather than *observed*, so a lane is
still not proved to touch exactly the files it names (5a §5.3, 0004 Decision 2). That bound is about
which files a run reaches; this one is about whether a named file's current content has any
relationship to a previously built artifact. Neither closes the other, and the record should keep
saying so, because they are easy to conflate.

## 5. Slice 5b — Chez AOT

### 5.1 Deliverables

1. **Mode plumbing.** `byte_machine_add_scheme_lane` stops emitting the literal
   `BYTE_MACHINE_EXECUTION_MODE=source` and derives the mode from the test name;
   `byte_machine_test_name_parse` already returns it (M3). The two in-process assertions generalise
   per W8.
2. **`chez-compile.ss`** — `compile-imported-libraries #t`, `generate-wpo-files #f`, each library
   root paired with its own object directory, `compile-program`. In the repository's `--flag value`
   style with per-argument refusals at status 2, matching `chez-source.ss`.
3. **`chez-aot.ss`** — `source-directories` empty, object directories only on the library path,
   `load-program`. The emptiness is the structural claim (P1).
4. **`byte_machine_lane_chez_aot`** — object directories keyed by Chez version and machine type so
   parallel builds cannot race and no object is reused across runtimes; a `DEPENDS` list covering the
   program, both launchers, every `.sls` under both library roots, and every declared body; and the
   `fingerprint/` copy step in the same command (W6).
5. **The staleness proof lane** — §7.
6. **Slice 5a's carried items 2–4** (W9).
7. **A decision-record amendment** to 0004 recording W2/W3 and the reason.

### 5.2 Registrations

`chez.aot` × {`bootstrap`, `self`, `placeholder-identity`} = three lanes. The third discharges slice
4 §10 for Chez.

### 5.3 One thing measured early, not assumed

Whether a mutation deleting `(source-directories '())` from `chez-aot.ss` can be **witnessed** is
unknown. P1 is a locatability rule; 0004 documents a timestamp rule; the two are different, and
neither has been reproduced here. If it cannot be constructed, it becomes a declared survivor with a
written reason, exactly as slice 5a did for its five.

**When it is measured.** Not before the lane exists: witnessing it needs a compiled artifact and a
registered lane to run, and a scratch driver would only describe the scratch driver
(`scratch-fixture-measurements`). It is measured in the task immediately after the `chez.aot` lane
first runs green, and before the mutation task — early enough to change what this design may assert,
late enough to be possible. The implementation plan carries it as a task of its own so it cannot be
folded into the mutation work and quietly answered by whatever the mutation happened to do.

## 6. Slice 5c — Gambit `.o1` and `gsc -exe -nopreload`

5c cannot start before 5b lands: it consumes the two-list split and the mode plumbing.

### 6.1 Deliverables

1. **Layout-preserving staging** (W10, S1, M5). Declared trees copied whole; two library roots stay
   two roots.
2. **The `.o1` lane: two trees.** A compile tree with the real bodies. A run tree holding the real
   `.sld`s, the compiled objects touched *after* the copy so their currency is established here
   rather than inherited from `file(COPY)`, and every included body overwritten at its staged
   relative path by a diagnostic that still parses, prints a `HARNESS-ERROR` line naming the body,
   and exits 2. P2 is why the object cannot simply be separated from its source: Gambit must find and
   parse the `.sld` to resolve the module at all, so Chez's empty-directory remedy has no analogue.
3. **The `-exe` lane: link, then delete.** `-o` before `-exe` (P3); modules **named, not pathed**
   (P4); the `Unknown or improperly placed` stdout guard retained even though no `-cc-options` or
   `-ld-options` are passed, because P3's misordering is what it now earns its place catching (P5).
   Afterwards every loadable thing is removed, leaving only the inert `fingerprint/` copies.
4. **Two lane functions** returning command and measured paths, under the one rule of W5.
5. **The no-C-toolchain skip path** (W11, S4).

### 6.2 Registrations

`gambit.o1` and `gambit.aot` × {`bootstrap`, `self`, `placeholder-identity`} = six lanes, discharging
slice 4 §10 for Gambit.

## 7. Lanes and mutations

Two independent witnesses for the binding mechanism, because they fail differently: a specification
over the functional core, runnable with no Scheme present (W7), and a registered lane end to end.

### 7.1 The staleness lane

A lane whose artifact is compiled or linked from a **fixture variant** of a body, while its declared
`SHARED_BODIES` names the real one. Measured ≠ expected, so it exits 3 with the provenance mismatch
diagnosis. One per compiled lane: 5b registers the Chez one, 5c the two Gambit ones.

This is what makes claim 2 falsifiable, and W12 is why it is a lane rather than a mutation.

### 7.2 Mutations

Each asserts a failure **signature** and the suite's own totals, never merely a nonzero exit.

| # | Slice | Target | Mutation | Expected witness |
| --- | --- | --- | --- | --- |
| C1 | 5b | `ByteMachineSchemeLane.cmake` | a compiled lane returns the declared list as its measured list (protium's Chez behaviour) | the lane specification fails; end to end, the staleness lane flips 3 → 0 |
| C2 | 5b | `ByteMachineSchemeLane.cmake` | the measured list is reversed | fingerprint mismatch, exit 3, on any lane whose manifest has at least two bodies — a stale artifact is not needed to witness this one |
| C3 | 5b | `chez-aot.ss` | `(source-directories '())` deleted | **witnessability unmeasured** — §5.3; a declared survivor with a written reason if it cannot be constructed |
| C4 | 5b | `ByteMachineSchemeLane.cmake` | the mode is emitted as the literal `source` again | the lane specification fails. Not the in-process assertion: under W8 `source` is a member of the vocabulary, so a lane declaring it would pass. The witness is the functional core's name-to-mode mapping, asserted under `cmake -P`, which is also why W7 is not merely a convenience. |
| C5 | 5c | the staging script | the objects are not touched after the copy | the `.o1` lane interprets, the poison fires, status 2 with the poison's own diagnostic naming the body |
| C6 | 5c | the staging script | the poison template is emptied | the lane passes where 2 was expected |
| C7 | 5c | the link script | the module is pathed rather than named | link succeeds, startup fails with `Module not found` |
| C8 | 5c | the link script | `-o` moved after `-exe` | the misplacement guard fires at build time with its own message |
| C9 | 5c | the staging script | bodies flattened into one directory (protium's layout) | the compile fails to resolve the include |

**Declared survivor.** Skipping the `-exe` lane's post-link deletion changes nothing observable: the
executable consults no disk at startup, so the lane passes either way. The deletion makes "this lane
runs the artifact" a property rather than a test, which is its whole point, and there is no
observation that distinguishes the two. Recorded rather than left as an unexplained gap.

## 8. Work order

**5b**

1. Mode plumbing (W8), with the existing suite kept green.
2. The two-list split (§4), functional core and specification first.
3. `chez-compile.ss` and `chez-aot.ss`, with their refusals.
4. `byte_machine_lane_chez_aot`, the `fingerprint/` copy step, and the three registrations.
5. Measure §5.3 against the lane that now exists, and record the answer in this document before the
   mutations are written.
6. The staleness lane, then C1–C4.
7. Slice 5a's carried items 2–4 (W9).
8. The 0004 amendment and the CHANGELOG entry.

**5c**

1. The staging script (W10), with C9 first — the divergence from protium is the thing most worth
   proving load-bearing.
2. The `.o1` lane, its run tree and poison, and C5–C6.
3. The link script, the `-exe` lane, and C7–C8.
4. The six registrations, and the two Gambit staleness lanes.
5. The no-C-toolchain skip path (W11).
6. The decision record for D5's closure and the CHANGELOG entry.

## 9. Exit criteria

**5b**

- The three `chez.aot` lanes are green and report the same fingerprint as their `chez.source`
  counterparts for the same manifest.
- The Chez staleness lane exits exactly 3, with the mismatch diagnosis.
- C1, C2 and C4 are caught for their declared reasons; C3 is caught or is a declared survivor with a
  written reason, per §5.3.
- The `no-scheme` preset is unchanged, and the measured-path computation is exercised by a
  specification under it (W7).
- Suite totals asserted, as every prior slice has done.

**5c**

- All four lanes green over the same shared body, agreeing on one content fingerprint. **This is
  D5.**
- Both Gambit staleness lanes exit exactly 3.
- C5–C9 caught for their declared reasons; the `-exe` deletion survivor declared with its reason.
- A host with `gsi` and no C toolchain configures, skips the compiled lanes with a named message, and
  runs the source lanes.
- Cross-library identity holds on all three compiled lanes, discharging slice 4 §10.

## 10. Explicitly deferred

- **The declared-versus-observed manifest bound** (5a §5.3, 0004 Decision 2). Not closed here, and
  not closable by W2 — see §4.
- **A value carried inside the artifact.** W2 is weaker than 0004's original direction in the way W6
  states. The reopening condition: a build tree that can be disturbed such that copies and artifact
  desynchronise without the build noticing.
- **Whole-program optimisation.** `generate-wpo-files #f` is declined, not deferred: a portability
  proof does not need it, and it would add a second artifact shape to bind.
- **D6 and D7** — slice 6. **D8 and D9** — slice 7.
- **Slice 4's configure-time one-owner guard** (decision 0003), reopening condition unchanged.
- **Gambit accepting a library body that redefines an imported name** — M1, as slice 4 §11 recorded.

## 11. Open questions carried forward

**Are the compiled lanes affordable?** Build cost is unmeasured — neither protium nor this repository
records a wall-clock figure for staging, compiling, or linking a lane. Nine new lanes, each with its
own artifact, could dominate `make test`. Measured through the real harness early in 5b, per the
`scratch-fixture-measurements` standard. If the number is bad, the mitigation is a preset or label
split for compiled lanes, decided on the number rather than in advance.

**The compiled lanes have never run on Linux.** Slice 7 is the first time, and also the first
exercise of W11's skip path. W7 is the cheap partial mitigation: keeping the registration logic in
the functional core means slice 7 inherits something already specified rather than something only
ever observed working on one host.

**Nothing requires a lane to have run anything.** Protium records P6 — an emptied program left its
lane green, because gsi ran a file with no forms and exited 0 — and requires every registration to
name a line its output must contain. This repository has no output assertion; slice 2 recorded that
its registration layer asserts exit status rather than output. Slice 5a's reachability guard does not
close it either: a program that never calls `harness-begin` or `harness-summary` reaches no guard at
all. The `-exe` lane is where this matters most, since a link can produce a runnable artifact that
proves nothing. Named here rather than folded into these slices, because an output-assertion
mechanism is a change to the registration layer for every lane in the tree, not a compiled-lane
deliverable.

**Does `gsc` on a second platform produce the same object layout?** The `.o1` lane asserts one object
per module by exact leaf name under a directory whose name embeds Gambit's version and target.
Protium records that keying as Gambit's own; whether it is stable across the Tier 1 cells is a slice 7
question, and 5c should fail loudly rather than glob loosely if it is not.
