# Milestone 0 close-out: the harness is the deliverable

Status: proposed
Date: 2026-08-22
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §25 Milestone 0
Governing plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — this slice replaces its §8 work-order items 6 and 7
Decision record this slice produces: [`docs/decisions/0007-milestone-0-closes-at-the-harness.md`](../decisions/0007-milestone-0-closes-at-the-harness.md)

**Goal:** Milestone 0 closes, and both governing documents say so. Its three
undelivered deliverables — spike §7's D6, D7, and D8 — move to Milestone 1,
where each has a subject. Nothing in the tree is left instructing the next
reader to do something that cannot be done. No code is written, no lane is
registered, no mutation is added.

**Reference convention.** The spike and the parent plan both have numbered
sections, and the spike has **two** independent D-series — §5's decision table
(D1–D7) and §7's deliverables (D0–D9). Every section reference in this document
is prefixed `parent` or `spike`, and every deliverable reference names its
series: "spike §7 D6", never "D6" alone.

## 1. Why this slice exists instead of slice 6

The spike's §8 work order, item 6, reads:

> 6. **Deterministic emission + identifier/LF proofs** (D6, D7). Exit:
>    byte-identical output across implementations; every rejection case
>    rejected.

Its exit condition cannot be met. [Decision 0005](../decisions/0005-chez-only.md)
removed the second implementation, so there is nothing for the output to be
identical *to*. The amendment note at the head of the spike restates spike §7 D6
as "a single-implementation, cross-platform claim" — which is honest, and which
this host also cannot discharge: one of four Tier 1 cells exists locally
(parent §7.3), a second — Linux amd64 — arrives with spike §7 D8, and the
remaining two, Linux arm64 and Windows amd64, are D8's own deferred cells.

That leaves the parent plan's weaker formulation, "deterministic text emission
proof across the Chez source and AOT lanes" (parent §25:1425). Decision 0005
refused the same shape of substitution one deliverable over. Of a two-lane
agreement standing in for the content fingerprint's lost cross-runtime claim, it
wrote that such an agreement "is a weaker statement, and slice 5b already owns it
under its own name" (0005:159–165). For D6 itself 0005 chose the other repair,
restating it as the cross-platform claim above.

Underneath the wording problem is a structural one. D6 and D7 are properties of
an emitter. The spike's own scope decision forbids writing one:

> **Scope decision: Milestone 0 only.** No byte-machine semantics (no IR,
> verifier, interpreter, emitter, or runtime) are implemented in this milestone.

So slice 6 as specified would build a placeholder writer for the sole purpose of
having a subject for a determinism claim, prove the claim about the placeholder,
and then hand Milestone 1 an emitter that has to prove it over again about the
real thing. The placeholder would be the second such object in `src/`, joining
spike §7 D3's tagged value, which spike §11 already schedules for deletion in
Milestone 1.

Parent §25's Milestone 1 **Scope** list already contains both deliverables,
named:

> - minimal verification including reachability, zero-progress-cycle rejection,
>   and generated-name safety for every construct present;
> - minimal reference interpreter;
> - minimal direct-code emitter and runtime;
> - deterministic output;

and its exit criteria already include "invalid names, targets, overlap,
fallback, and terminals are rejected." D6 and D7 are not being dropped. They are
being returned to the milestone that already asks for them.

### 1.1 The ratio this closes

[Decision 0005](../decisions/0005-chez-only.md) recorded the same observation two
slices ago — "the harness outweighs the product it tests by two orders of
magnitude". Re-run at `bca1422` on 2026-08-22 using 0005's own two commands, so
the ratio is comparable: `find cmake test/support -type f` now totals **8460**
lines against `find src -type f`'s **87** — 97:1, where 0005 measured 9858:147,
or 67:1. The gap widened, but **not because the harness grew**: it shrank by
1398 lines when the Chez-only cut landed. The product shrank faster. The four
commands below are this document's own, narrower file set, and are not
subtracted from 0005's:

```
$ wc -l src/byte-machine/*.sls | tail -1
      87 total
$ cat cmake/*.cmake test/support/cmake/*.cmake test/CMakeLists.txt | wc -l
    6828
$ cat test/support/harness/byte-machine/test/*.sls \
      test/support/harness/self/*.sps test/support/launchers/*.ss | wc -l
    2348
$ cat docs/plans/*.md | wc -l
   18690
```

All 87 lines of `src/` are placeholder. Most of the substrate above them was
earned — the exit-code vocabulary, the fingerprint provenance, and the mutation
suite each exist because a specific defect class was demonstrated, and the
ledger records those defects being caught. Slice 6 is the first item whose cost
buys no product and no protection of product, because by construction it has no
product to be about. That is the case for stopping here, not a case against what
came before.

## 2. What Milestone 0 delivered

Stated so the close can be checked rather than asserted. Verified against the
tree at `ceb0894`. Spike §7 series.

| | Deliverable | Status |
| --- | --- | --- |
| D0 | Toolchain discovery | delivered — [0001](../decisions/0001-toolchain-discovery.md) |
| D1 | Repo skeleton | delivered; layout revised by 0005/0006 (§6.2 row S5) |
| D2 | Shared body through both wrappers | delivered in slice 3, **retired** by [0006](../decisions/0006-inline-libraries.md) |
| D3 | Cross-library identity smoke path | delivered — both Chez lanes |
| D4 | Portable test harness + thin runners | delivered |
| D5 | Execution lanes | closed at two lanes — dated note already at spike:160–186 |
| D6 | Deterministic text emission proof | **moves to Milestone 1** |
| D7 | Identifier repertoire and binary LF proof | **moves to Milestone 1** |
| D8 | CI + feasibility notes | notes delivered here; **pipeline moves to Milestone 1** |
| D9 | Decision records + CHANGELOG | delivered, extended by this slice |

## 3. Where the three moved deliverables land

The move is not a deferral to "later". Each lands on a named line of parent §25's
Milestone 1 **Scope** list, and §6.1 row P14 adds the dated note that records the
arrival there.

- **D6 → "deterministic output"** (parent §25:1447). The emitter Milestone 1
  builds is the writer parent §20 requires. Its determinism is then testable
  against something real, along the first five of the seven checks parent §22.9
  enumerates: repeat in one process, repeat across processes, both Chez lanes,
  every Tier 1 cell byte-for-byte, and compile-and-execute the result. Only the
  fourth needs D8. Parent §22.9's remaining two bullets are D7's, not D6's.
- **D7 → "symbolic name resolution"** (parent §25:1440) **and "generated-name
  safety for every construct present"** (parent §25:1444). The `[a-z][a-z0-9-]*`
  grammar (parent §10.1:478) is what name resolution validates against; the
  second repertoire in the same sentence — printable ASCII plus LF for embedded
  labels and reasons — is what the emitter escapes against. The binary-LF write
  half rides with `emit-machine`, whose contract parent §20:1046 fixes: writes
  only to the supplied binary output port.
- **D8 → Milestone 1, bound to D6's cross-cell axis.** These need the same four
  cells. Splitting them is what made slice 6 unresolvable, so they land together
  or not at all. CI over 87 lines of placeholder protects nothing; CI over the
  emitter protects the byte-identity claim that is D6's whole point.

D7 carries one scope note into Milestone 1 that this slice records rather than
solves: parent §9.2's reserved-output-binding set has three members — R6RS
source-mode syntax and declaration identifiers, `(byte-machine runtime)`'s
exports, and the emitter template's own identifiers. Only the first is
enumerable before Milestone 1 exists. Parent §22.9:1315's "Reject every canonical
reserved output binding under Chez" is therefore not a Milestone 0 obligation
under any reading, and Milestone 1 should scope the test to the members that
exist when it runs.

## 4. Exit criteria, and how the close-out meets them

Parent §25's Milestone 0 exit criteria are three:

> - the same shared test body passes in both the source and AOT execution lanes;
> - CI design covers unavailable local platforms;
> - each library owns its own code — no shared include bodies ([decision 0006](../decisions/0006-inline-libraries.md)).

**Criterion 1** is met and was met before this slice, though not by every
program: `placeholder-identity-tests`, `harness-bootstrap`, and
`harness-self-tests` each run in `.chez.source` and `.chez.aot`;
`placeholder-tests` has a source lane only, which the `.chez.aot` block's own
comment at `test/CMakeLists.txt:538–546` states and justifies. Its wording is
stale — "shared test body" is retired vocabulary — and §6.1 row P12 corrects it.

**Criterion 3** is met. The underlying fact is verifiable — `rg '\(include' src
test` returns zero hits — but the 0006 gate is a runnable `rg` acceptance check
described in `milestone-0-include-collapse.md`, **not a registered lane**:
nothing in `ctest` fails if an include reappears. This slice states that
accurately rather than calling the gate executable.

**Criterion 2** is met **by this slice**, through the CI feasibility note
specified in §7. It asks for a *design* covering unavailable platforms — which is
spike §7 D8's "written feasibility notes" half. D8's other half, the running
pipeline, is what §3 moves. D6 and D7 appear in none of the three criteria.

The spike's own §12 carries nine broader criteria, all written before decisions
0005 and 0006. §6.2 row S16 dispositions each **without rewriting them**, for the
reason §5 gives.

## 5. The record/instruction rule

The house rule to date is that a decision record is not edited when a later
decision changes the world; it gains an amendment note, because "a record edited
to agree with a later decision stops being evidence of anything" (the spike's own
header note, spike:11–12; [0005](../decisions/0005-chez-only.md):190–191 states
the same rule in slightly different words).

That rule is correct and this slice keeps it. But it does not cover every stale
sentence in the tree, and applying it document-wide is how the work order came to
instruct an impossible exit. Four categories, not two:

1. **Record — what was true.** Environment measurements, delivery notes,
   decision records' Context and Measurements. Editing one destroys evidence.
   **Amendment note.**
2. **Instruction — what to do next.** Work orders, exit criteria, Deliver and
   Scope lists, deliverable entries, out-of-scope bullets, sequencing sections,
   and comments in live code that tell a reader what the code is for. Leaving a
   false one is not preserving evidence; it is leaving a landmine, and what it
   used to say is in git. **Corrected in place, dated.**
3. **False when written — never true, and load-bearing.** [0001](../decisions/0001-toolchain-discovery.md):86's
   claim of a CI is not superseded; it was wrong on the day it was written, and
   it is cited as evidence for that record's own consequences. Category 1's
   justification does not reach it. **Annotated, never silently fixed**, and the
   note says *this was never true* rather than *this changed*.
4. **Status and orientation — what is true now.** `spike:3`, `CHANGELOG.md:9–13`,
   and parent §25's open Deliver list. These are the sentences that tell the next
   reader what remains, and they are the ones this slice's own goal contradicts
   most directly. **Corrected in place**, and a slice that closes a milestone is
   not finished until all three say so.

**A record document may contain instruction sentences.** The spike's header note
pledges "This document is a record and keeps all of its Gambit content", and §6.2
then makes edits inside it. That is not a contradiction, but it must be said out
loud: the pledge covers the spike's §2 environment facts and its findings, not
its §5 decision table, §7 deliverable entries, §8 work order, §11 scope bullet,
§12 criteria, or §13 sequencing. §6.2 row S2 amends the header to carve that out.
Conversely, a record's own reasoning may contain imperatives — spike:43's "Probe
by banner", spike:45's "never search for `gsc`" — and those stay. §11's criterion
is scoped by document role accordingly.

**An exit criterion changes category when its milestone closes.** While the
milestone is open it is an instruction; the moment it closes it becomes the
record of what was demanded. This slice does both at once, so spike §12 gets
dated dispositions and no rewriting. Rewording "all four execution lanes agree on
a content fingerprint" to "met at two lanes" would edit the bar to match the
result, which is precisely the failure the rule exists to prevent. The right
instrument already exists in the same file: spike §7 D5's dated note (spike:160–186)
states what was achieved without touching what was asked.

This rule is added to AGENTS.md as a project standard. Per that file's own
convention, the bullet carries a demonstrated defect rather than a statistic —
and this slice supplies one: spike §8 item 6 instructed an impossible exit for
four days and consumed a planning cycle before anyone read it against the tree.

## 6. The sweep

Organised by file, with the replacement text for every corrected site, because a
site that names a defect and stops is not executable. Every current-text quote
below was verified against the tree at `ceb0894`.

Dated notes use the form spike §7 D5 already models: a blockquote beginning
**Amended YYYY-MM-DD by …** or **Moved / Retired YYYY-MM-DD by …**.

### 6.1 `docs/plans/byte-machine-implementation-plan.md`

| Row | Site | Disposition |
| --- | --- | --- |
| **P1** | §7.1:152 "The functional core, runtime body, generated body, and shared tests live in wrapper-free `.scm` files." | Correct the settled halves only: **"The functional core and the tests are inline R6RS `.sls` libraries and `.sps` programs ([decision 0006](../decisions/0006-inline-libraries.md)). The form of the runtime and *generated* bodies is fixed by §9.6 and is Milestone 1's to settle — see §9 of the close-out."** |
| **P2** | §9.6:450 item 5, "including that generated body from a consumer library wrapper" | **Annotate, do not rewrite** — the correct replacement is a Milestone 1 design call (§9). Append: **"— this conflicts with §7.2's 'No Scheme file in this repository includes another'; Milestone 1 must resolve it (see [the close-out](./milestone-0-close-out.md) §9)."** |
| **P3** | §20:1038 "rejection of output bindings that collide with portable Scheme syntax, runtime exports, or emitted internal identifiers" | **"…that collide with syntax or declaration identifiers reserved by the R6RS source mode, runtime exports, or emitted internal identifiers"** — aligns with §9.2:374, which was corrected while §20 was not. |
| **P4** | §20:1046 "`emit-machine` writes only to the supplied binary output port through a portability shim (`put-u8` versus `write-u8`)." | **"`emit-machine` writes only to the supplied binary output port with `put-u8`."** `write-u8` is the R7RS spelling; under Chez-only there is one branch and no shim. Rest of the paragraph unchanged. |
| **P5** | §25:1419 "confirmed R6RS library and include strategy" | **"confirmed R6RS library strategy — inline `.sls`, no includes ([decision 0006](../decisions/0006-inline-libraries.md))"** |
| **P6** | §25:1420 "shared hello-library body loaded through its owner wrapper" | **Delete the bullet.** Spike §7 D2 is retired; inventing a replacement deliverable would assert something nobody shipped. Recorded in CHANGELOG. |
| **P7** | §25:1421 "one provisional owner wrapper constructs a placeholder tagged value, another wrapper recognizes it" | **"one provisional library constructs a placeholder tagged value, a second library recognizes it"** — same retired vocabulary as the bullet above it. |
| **P8** | §25:1422 "Tier 1 CI feasibility notes" | Append **"(discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md))"**. |
| **P9** | §25:1425 "deterministic text emission proof across the Chez source and AOT lanes" | **Delete from Milestone 0's Deliver list.** Milestone 1 has no Deliver list; its **Scope** list already carries "deterministic output" (:1447). Recorded by row P14. |
| **P10** | §25:1426 "identifier repertoire and binary LF emission proof across available operating systems" | **Delete from Milestone 0's Deliver list.** Milestone 1's Scope already carries "symbolic name resolution" (:1440) and "generated-name safety for every construct present" (:1444). Recorded by row P14. |
| **P11** | §25:1427 "documented Windows path and LF behavior" | Append **"(discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md))"**. |
| **P12** | §25:1431 exit criterion 1, "the same shared test body passes in both the source and AOT execution lanes" | **"the same test program passes in both the source and AOT execution lanes"** — pure vocabulary repair. |
| **P13** | §25, after Milestone 0's exit criteria | **Add the close note** (category 4 — the milestone is not closed until the governing document says so): <br>**"> Closed 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md). D6, D7, and D8 move to Milestone 1; see [the close-out](./milestone-0-close-out.md)."** |
| **P14** | §25, at the head of Milestone 1's Scope list | **Add the arrival note**, so the move has a destination record: <br>**"> Amended 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md): Milestone 0's D6, D7, and D8 land here. D6 on 'deterministic output'; D7 on 'symbolic name resolution' and 'generated-name safety for every construct present'; D8's CI pipeline alongside D6's cross-cell axis, which needs the same cells."** |

### 6.2 `docs/plans/milestone-0-portability-spike.md`

| Row | Site | Disposition |
| --- | --- | --- |
| **S1** | `:3` Status line, "slices 6–7 not started" (category 4) | **"Status: closed 2026-08-22 — slices 1 through 5 delivered; slice 5c cancelled by [decision 0005](../decisions/0005-chez-only.md); §7 deliverables D6, D7, and D8 moved to Milestone 1 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md). [The close-out](./milestone-0-close-out.md) records what closed and what moved."** Keep the existing 5b/5c clauses. |
| **S2** | `:8–14` header amendment note | **Append one sentence carving out instructions:** "This pledge covers the document's **records** — the §2 environment facts and the §3 findings. Its **instructions** — the §5 decision table, the §7 deliverable entries, the §8 work order, the §11 scope bullet, the §12 exit criteria, and §13 — are corrected in place when they would misdirect, each correction dated. See [the close-out](./milestone-0-close-out.md) §5." |
| **S3** | §5 decision table D2, `:106` "CI now covers macOS arm64 + Linux amd64 for both implementations; full 8-cell Tier 1 matrix lands in Milestone 9" | Correct the tense and the arithmetic: **"CI is to cover macOS arm64 + Linux amd64; the remaining Tier 1 cells land in Milestone 9."** Add a dated line under the table: **"> 2026-08-22: no CI exists in any commit of this repository. D8 moved to Milestone 1 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md). Under Chez-only, Tier 1 is four cells, not eight (parent §7.3): D8's CI covers two, and two — Linux arm64 and Windows amd64 — are deferred."** |
| **S4** | §7 D0, `:154` "Probe-based detection for both runtimes" | **"Probe-based detection, banner-verified, rejecting Petite and GhostScript. Pinned minimum version recorded."** Dated note: one runtime, not two (0005). **The GhostScript classification is not removed** — it survives the Gambit cut and is still specified and mutation-tested at `test/support/cmake/ByteMachineChezSpec.cmake:51–53, :118, :162`. |
| **S5** | §7 D1, `:155` "`src/common/`, `src/chez/`, `src/gambit/`" | **"`src/byte-machine/`, `test/`, `build/` (gitignored), `docs/decisions/`."** |
| **S6** | §7 D2, `:156` shared body / `.sld` / repository-wide basename check | Mark the entry **"*(Retired — see note.)*"** and add: **"> Retired 2026-08-22, effective [decision 0006](../decisions/0006-inline-libraries.md): there is no shared body and no `.sld`, and the repository-wide basename check narrowed to `byte_machine_add_scheme_lane`'s per-lane uniqueness check. Delivered in slice 3 and dismantled by the include collapse; the entry stays because the slice that shipped it is real history."** |
| **S7** | §7 D3, `:157` "Owner wrapper constructs … a second wrapper recognises it" | **"One library constructs a placeholder tagged vector; a second library recognises it; an allocation-free singleton retains `eq?` identity across both imports. Runs in every execution lane."** |
| **S8** | §7 D4, `:158` "thin Chez and Gambit adapters owning imports … adapters on both runtimes must export exactly the same names" | **"Dependency-free (no SRFI-64, no package manager) per parent §22.2: assertion and result code in one library, a thin Chez runner owning imports, process exit codes, and compilation steps. Mirrors protium's harness structure."** The two-runtime `must` is a live instruction naming a retired contract. |
| **S9** | §7 D5, `:159` "Chez source, Chez AOT, Gambit `.o1`, Gambit `-exe -nopreload`." | **"Chez source and Chez AOT. Compiled lanes must be unable to silently fall back to source."** The existing dated note at `:160–186` stays untouched — it is the record of how D5 closed. |
| **S10** | §7 D6, `:187` "Both implementations write byte-identical…" | **"Byte-identical canonical UTF-8/LF output through a project-owned writer; compared by fingerprint, never via implementation `write` formatting."** Dated note: **"> Moved to Milestone 1 on 2026-08-22 by [decision 0007](…). A writer belongs to an emitter, and Milestone 0 ships no emitter (§11). Milestone 1's Scope already carries 'deterministic output'; the cross-cell half of the claim rides with D8."** |
| **S11** | §7 D7, `:188` | Entry text unchanged — it names no retired concept. Dated note recording the move to Milestone 1's "symbolic name resolution" and "generated-name safety" lines, and that parent §9.2's reserved-binding members 2 and 3 are unenumerable until Milestone 1 exists. |
| **S12** | §7 D8, `:189` "CI (macOS arm64 + Linux amd64, both implementations) plus written feasibility notes for the four deferred Tier 1 cells" | **"CI (macOS arm64 + Linux amd64) plus written feasibility notes for the two deferred Tier 1 cells."** **One** dated note covering both halves: the pipeline moves to Milestone 1; the notes are discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md); the "four" was written against a four-platform × two-runtime matrix. |
| **S13** | §8 work order items 6 and 7 | **Replace both with one item 6:** "**Milestone 0 close-out** (spike §7 D6, D7, D8 moved to Milestone 1; D9 completed). Exit: both governing documents record the milestone as closed, the three moved deliverables land on named Milestone 1 Scope lines, and no instruction outside a dated record names a retired concept. See [the close-out](./milestone-0-close-out.md)." |
| **S14** | §9 questions list, `:204–216` | **Do not rewrite the questions.** Add a dated disposition block after the list, pointing at §8 of this document and at [0007](../decisions/0007-milestone-0-closes-at-the-harness.md), which carries the answers to questions 1–4. |
| **S15** | §11, `:230` "and the full 8-cell matrix" | **"and the full Tier 1 matrix"** — the eight-cell arithmetic is the two-runtime one. |
| **S16** | §12, all nine exit criteria | **Do not rewrite (see §5).** Add one dated disposition block after the list, reproduced in §6.5 below. |
| **S17** | §13, `:246` "and two cross-implementation examples" | **"and the parent plan's §9.6 example"** — a forward instruction to Milestone 1 naming a retired contract. |

### 6.3 `docs/decisions/`

| Row | Site | Disposition |
| --- | --- | --- |
| **R1** | [0001](../decisions/0001-toolchain-discovery.md):86 "It runs in CI as `byte-machine.harness.cmake-mutation.cmake.direct`." | **Category 3 — annotate, never edit.** Dated note: "The sentence 'It runs in CI as …' **was never true**: no CI has existed in any commit of this repository. The lane is real and runs under `ctest`. The claim is annotated rather than corrected because it is cited as evidence for this record's own Consequences. D8 moved to Milestone 1 by [0007](./0007-milestone-0-closes-at-the-harness.md)." |
| **R2** | New file `0007-milestone-0-closes-at-the-harness.md` | Contents in §8.1. |

### 6.4 Live code and `CHANGELOG.md`

| Row | Site | Disposition |
| --- | --- | --- |
| **L1** | [`cmake/ByteMachineTesting.cmake`](../../cmake/ByteMachineTesting.cmake):35, `determinism   # byte-identical emission across runs and runtimes` | **"# byte-identical emission across runs, lanes, and platform cells"**. Only the comment changes; the vocabulary entry stays, since it is already in the `pr` preset's label regex and Milestone 1's determinism lanes will use it. |
| **L2** | [`test/CMakeLists.txt`](../../test/CMakeLists.txt):61 "It runs in CI because evidence that only exists in someone's terminal cannot fail when the code changes." | **"It runs under `ctest` because evidence that only exists in someone's terminal cannot fail when the code changes."** Live code, six lines above the very lane 0001 cites, asserting the same CI that has never existed. |
| **C1** | `CHANGELOG.md:9–13` "Milestone 0 (portability and harness spike) is in progress." (category 4) | **"Milestone 0 (portability and harness spike) closed on 2026-08-22; see [the close-out](docs/plans/milestone-0-close-out.md). No public API exists yet…"** — rest of the paragraph unchanged. |
| **C2** | `CHANGELOG.md` `[Unreleased]` | Entries for the close, the move of D6/D7/D8, the new records, and every deletion made under rows P6, S13. |

### 6.5 The spike §12 disposition block

Added verbatim after spike §12's nine criteria; the criteria themselves are not
touched.

> **Dispositioned 2026-08-22 at close ([decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md)).**
> These criteria were written before decisions 0005 and 0006. What each came to,
> in order: (1) **met** on both Chez lanes; the second runtime went with 0005 and
> the working-directory matrix, an include-resolution proof, with 0006. (2)
> **met** — each library owns its own code (0006). (3) **met** on both Chez
> lanes. (4) **met at two lanes**, per D5's note above. (5) **moved** to
> Milestone 1 — D6. (6) **met**; the GhostScript classification survives the
> removal of the `gsc` it guarded against and is still specified and
> mutation-tested. (7) **moved** to Milestone 1 — D8. (8) **met**, at two
> deferred cells, by [the CI feasibility note](./milestone-0-ci-feasibility.md).
> (9) **met** — parent §30 questions 1–4 are answered in
> [0007](../decisions/0007-milestone-0-closes-at-the-harness.md), each with its
> evidence level stated; not all four are answered by test, and 0007 says which
> are not.

### 6.6 Judged and deliberately left alone

Named so a reader can tell these were read rather than missed.

- **Spike §2's environment-facts table**, including "Tier 1 cells available
  locally | 1 of 8" and the Gambit rows. A dated measurement; category 1. Its
  Consequence column carries imperatives ("Probe by banner"; "never search for
  `gsc`") which are a record's own reasoning and stay — §11's criterion is
  scoped for exactly this.
- **Spike §5 decision D6** (the include mechanism). Already annotated as retired
  by the header's 0006 note, including its build-time-check clause.
- **Spike §6**, the recorded-not-used `include-relative` macro. A record of a
  path not taken.
- **Parent §24.2's per-Tier-1-cell CI stages** (`:1392`–`:1396`). Future CI
  instructions, still correct as intent. §24 is titled "CI and Build Strategy"
  and §24.2 "CI stages" — they are CI stages, not release stages.
- **`test/support/cmake/MutationRunner.cmake`:6, "runnable in CI".** A
  capability claim, true of any `cmake -P` script; not an assertion that a CI
  exists.
- **The spike §7 D3 placeholder libraries.** Spike §11 assigns their deletion to
  Milestone 1.
- **The `o1` mode token.** It carries an in-code rationale for its own retention
  at `cmake/ByteMachineTesting.cmake:46–50`.
- **`CHANGELOG.md`'s `### Added`, `### Changed`, `### Removed`, and `### Fixed`
  entries** — 28 mentions of Gambit among them. A changelog entry is a record of
  a change that happened; sweeping it would rewrite history rather than correct
  an instruction. Only the preamble (row C1) is category 4.

## 7. The CI feasibility note

`docs/plans/milestone-0-ci-feasibility.md`. It discharges parent §25's exit
criterion 2, spike §7 D8's "written feasibility notes" half, and parent §25:1427's
"documented Windows path and LF behavior". Required content:

1. **The four Tier 1 cells** (parent §7.3), each with: how Chez is obtained, what
   the binary is called there, whether the shipped probe handles that name, and
   which deliverable the cell is the only witness for.
   - *macOS arm64* — available locally; Homebrew renames upstream `scheme` to
     `chez`; the probe already handles it.
   - *Linux amd64* — hosted runner; Chez packaged as `scheme` or `chezscheme`
     depending on distribution, which is the case 0001's probe was built for.
   - *Linux arm64* — deferred; hosted arm64 runners or emulation. State the two
     options and that neither has been priced, rather than pricing them from
     this host.
   - *Windows amd64* — deferred, and the **only** cell that can exhibit the
     CRLF translation D7 names.
2. **Windows path and LF behavior**, with citations and standing stated
   separately, because the interesting fact here is that the obvious exposure was
   designed out:
   - The `:` versus `;` separator applies to Chez's `--libdirs` option and the
     `CHEZSCHEMELIBDIRS` variable — the *string* form. Cite Chez 10.4.1's own man
     page (`chez.1`, the `--libdirs` section), installed on this host.
   - **This project never uses that form.** All four Scheme entry points set the
     `library-directories` *parameter* with a Scheme list of pairs, built from
     repeatable command-line flags: `chez-source.ss:139–140`, `chez-aot.ss:183–184`,
     `chez-compile.ss:153`, `fingerprint-manifest.ss:59`. So the separator is
     recorded as background about the runtime, not as behavior byte-machine
     depends on.
   - Chez joins the components of a *library name* with `/` to build a partial
     path — `(a b)` becomes `a/b` — and appends it to each root before trying
     each extension. That is library-name resolution, not a separator behavior,
     and it is what makes `/`-delimited roots the portable form.
   - What genuinely stays open on Windows is what
     [0002](../decisions/0002-shared-body-include-mechanism.md):149–151 already
     named: path form — backslashes, drive letters, and what counts as an
     absolute pathname. Unmeasured; arrives with the Windows cell.
   - LF: the fingerprint reader already opens files as binary for this exact
     reason (`fingerprint.sls:50–52`). The *write* side is D7's and is unbuilt.
3. **What each cell would prove that this host cannot** — D6's cross-cell byte
   identity, D7's LF-through-a-binary-port on the one platform whose text ports
   translate, and the probe's own portability.
4. **What is not proposed.** No pipeline, no runner configuration, no workflow
   file. Those are D8, in Milestone 1.

The note lives in `docs/plans/` per AGENTS.md's "plans live in `/docs/plans`";
`docs/reference/` exists but AGENTS.md knows only the two homes.

## 8. Parent §30 questions 1–4

The spike calls these hard requirements and spike §12's criterion 9 requires them
"answered in `docs/decisions/`". They therefore land in **0007**, not here; §8.1
specifies the wording. This section states the substance, with the evidence
behind each stated plainly, because "answered" and "answered by a measurement"
are not the same claim.

1. **Minimum Chez release.** Pinned at 10.4.1 — verified, and the only version
   this project has ever run on. The *floor* is unestablished and needs an older
   release under CI; 0001's Consequences already say so. Evidence: the probe's
   version gate. Answered as a pin with a stated open floor.
2. **Exact source and AOT commands per Tier 1 platform.** Answered for macOS
   arm64 by the shipped launchers, which are executable rather than documentary.
   Per-platform variance is unmeasured and rides with D8.
3. **Windows library search paths.** **Both halves are closed, neither by
   measurement.** The include half is closed by absence (0006 leaves nothing to
   resolve). The separator half was closed **by construction** in
   [0002](../decisions/0002-shared-body-include-mechanism.md):143–147 — "because
   the launcher takes repeatable flags, byte-machine never joins Chez search
   paths with any separator on any platform, so the `:` vs `;` question has no
   Chez-side object left to apply to." That closure is stronger than a
   documentary answer and is not superseded by 0002's include-mechanism
   retirement. What 0002 left open — Windows path form and absolute-path rules —
   is a different question and rides with the Windows cell.
4. **Portable condition construction exposed by the wrappers.** Closed by 0005:
   one implementation, R6RS conditions, no portability layer. A genuine closure
   by decision, not a deferral.

Questions 5–7 the spike already permits to be answered as "deferred, with
rationale". Question 6 (identifier length and source-size limits) is D7's
companion and rides with it to Milestone 1: the grammar imposes no maximum, so
measuring compiler limits before there is generated source to hit them measures
nothing.

### 8.1 What 0007 must contain

Standard header block (`Date:`, `Status:`, `Milestone:`) matching
[0005](../decisions/0005-chez-only.md):3–5. Then:

- **Context** — the four incompatible statements of D6, and the structural fact
  that D6/D7 are properties of an emitter Milestone 0 forbids.
- **Decision** — Milestone 0 closes; spike §7 D6, D7, and D8 move to Milestone 1,
  landing on the parent §25 Scope lines named in §3 of this document.
- **The parent §30 question 1–4 answers** from §8 above, each with its evidence
  level and, where the answer is by construction or by decision rather than by
  test, saying so.
- **Measurements** — the §1.1 ratio, re-taken against the shipped tree at the
  slice's own commit, not copied from here.
- **Consequences** — what closing buys, what it defers, and the named risk: a
  portability regression during Milestone 1 will surface late, because D8 moved.

## 9. Handed to Milestone 1 unresolved

Recorded so Milestone 1 finds them rather than rediscovering them.

- **Parent §9.6 item 5 versus parent §7.2.** The required end-to-end example must
  demonstrate "including that generated body from a consumer library wrapper",
  while §7.2 states "No Scheme file in this repository includes another." The
  example lives in this repository. The conflict is real; the cheapest resolution
  is probably that the emitter emits a complete `.sls` the consumer *imports*,
  which removes the include entirely — but that is a Milestone 1 design call, not
  a wording fix, so row P2 annotates it and leaves it.
- **Parent §9.6's "shared grammar body"** and **§7.1's surviving "generated body
  … wrapper-free `.scm`"** (row P1). Both depend on the resolution above.
- **Two `fingerprint` meanings.** The harness's content fingerprint (rolling hash
  mod 2^61−1, shipped) and parent §20:1041's embedded fingerprint of canonical
  normalized IR (permitted to be 64-bit FNV-1a) are different objects under one
  word. Milestone 1 introduces the second; it should say which it means at every
  site.
- **Parent §22.9's first five bullets** are Milestone 1's determinism checklist —
  the operational form of D6. Its remaining two are D7's.

## 10. File manifest

Everything this slice touches. Nothing else.

| File | Change |
| --- | --- |
| `docs/plans/milestone-0-close-out.md` | this document (new) |
| `docs/plans/milestone-0-ci-feasibility.md` | new — §7 |
| `docs/decisions/0007-milestone-0-closes-at-the-harness.md` | new — §8.1 |
| `docs/plans/byte-machine-implementation-plan.md` | rows P1–P14 |
| `docs/plans/milestone-0-portability-spike.md` | rows S1–S17 |
| `docs/decisions/0001-toolchain-discovery.md` | row R1 |
| `cmake/ByteMachineTesting.cmake` | row L1 — one comment |
| `test/CMakeLists.txt` | row L2 — one comment |
| `AGENTS.md` | the §5 rule, with its demonstrated defect |
| `CHANGELOG.md` | rows C1, C2 |
| `.superpowers/sdd/progress.md` | the close |

The only non-prose edits in the whole slice are the two comments, L1 and L2. No
new library, no new lane, no new mutation, no new exit status, no CI, and no
deletion of the spike §7 D3 placeholders.

## 11. Exit criteria for this slice

- **Every row in §6.1 through §6.4 has landed**, with the replacement text that
  row specifies. The rows are the unit; no count of "sites" is asserted, because
  row S13 bundles two work-order items and row S16 bundles nine criteria.
- **Both governing documents record the milestone as closed** — rows P13 and S1 —
  and `CHANGELOG.md`'s preamble agrees (row C1). A close that only this document
  knows about has not happened.
- **The three moved deliverables have a destination record** — row P14 — not just
  a departure note.
- **Scoped sweep gate.** Scoped to the two governing plan documents, the CMake
  tree, and AGENTS.md. `CHANGELOG.md` is **excluded**: its `### Added` and
  `### Removed` sections are records of what shipped and what was cut, carrying
  28 legitimate historical Gambit mentions; only its preamble is in scope, and
  row C1 checks that. After the sweep this command returns no hit outside a
  dated record:
  ```bash
  rg -n -i "gambit|\.sld|both implementations|both runtimes|two runtimes|four (execution )?lanes|shared (body|test body|grammar body)|owner wrapper|source-directories|8-cell|runs in CI" docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-0-portability-spike.md cmake test/CMakeLists.txt AGENTS.md
  ```
  Hits inside spike §2, spike §3, spike §5's D6 row, spike §6, AGENTS.md's own
  new bullet, and any blockquote beginning "Amended"/"Moved"/"Retired"/
  "Dispositioned" are expected and are not failures.
  The gate is a grep, so it is an inventory check, not a vocabulary check — the
  slice also requires a reading pass over the two governing documents end to end,
  and the implementer records that it happened.
- **0007 exists**, carries the §8.1 contents including the parent §30 question
  1–4 answers, and names the Milestone 1 Scope lines D6, D7, and D8 land on.
- **The CI feasibility note exists** with all four §7 items, including the
  separator/by-construction distinction of §7 item 2 — presenting the separator
  as a live Windows exposure would overstate it, since 0002 designed it out.
- **AGENTS.md carries the record/instruction rule**, with a demonstrated defect
  rather than a statistic.
- **`make test` is 37/37 and the `no-scheme` preset is 8/8**, run fresh rather
  than assumed — two live-code comments are touched, so the suite is evidence,
  not a formality.
- **Mutation totals are unmoved:** 1 CMake mutation pass over 72 mutations, and
  31 Scheme passes over 68.
