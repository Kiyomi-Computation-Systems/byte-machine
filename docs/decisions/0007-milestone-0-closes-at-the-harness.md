# 0007: Milestone 0 closes at the harness, and its last three deliverables move to Milestone 1

Date: 2026-08-22
Status: accepted
Milestone: 0, close-out

## Context

Milestone 0 is a portability and harness spike. Slices 1 through 5b delivered its
substrate; [the milestone plan](../plans/milestone-0-portability-spike.md) §8's
work order put item 6 — spike §7's deliverables D6 and D7 — next. That item
cannot be executed, and the reason is not that it is hard.

Spike §7 D6 is stated four incompatible ways, and all four are live in the tree:

- **spike:187**, the deliverable itself: "Both implementations write
  byte-identical canonical UTF-8/LF output through a project-owned writer".
- **spike:201**, work-order item 6's exit condition: "byte-identical output
  across implementations; every rejection case rejected".
- **spike:17–19**, the 2026-08-18 amendment note, restating D6's
  deterministic-emission proof as "a single-implementation, cross-platform
  claim" (the phrase wraps a line break in the source).
- **parent §25:1425**, the Milestone 0 Deliver line: "deterministic text
  emission proof across the Chez source and AOT lanes".

The first two name a second implementation. [Decision 0005](./0005-chez-only.md)
removed it. There is no longer anything for the output to be identical *to*, so
item 6's exit condition is not unmet — it is unsatisfiable as written.

The third is honest, and this host cannot discharge it either. Parent §7.3:195
names four Tier 1 platforms — Chez on Linux amd64, Linux arm64, macOS arm64, and
Windows amd64 — each required in both source and AOT execution. One platform
exists locally, in both lanes (macOS arm64; the Measurements host below). A
second, Linux amd64, arrives with spike §7 D8's pipeline; the remaining two
platforms, in both lanes each, are the four deferred cells D8's written
feasibility notes are about (spike:189). A cross-platform claim needs cells, and
the cells arrive with a deliverable this milestone has not delivered.

The fourth — the parent plan's weaker two-lane formulation — is the substitution
0005 already refused, one deliverable over. Writing of a `chez.source`/`chez.aot`
agreement standing in for the content fingerprint's lost cross-runtime claim,
0005:159–165 says that such an agreement "is a weaker statement, and slice 5b
already owns it under its own name". D6 does not get to take the repair 0005
declined for D5's instrument; for D6 itself 0005 chose the other repair, the
cross-platform restatement above.

Underneath the wording problem is a structural one. D6 and D7 are both
properties of an emitter — D6 of what a writer writes, D7 of which names it
accepts and which bytes survive the port — and the spike's own scope decision
forbids building one. spike:6: "No byte-machine semantics (no IR, verifier,
interpreter, emitter, or runtime) are implemented in this milestone." Slice 6 as
specified would build a placeholder writer for the sole purpose of having a
subject, prove a determinism claim about the placeholder, and hand Milestone 1
an emitter that must prove it again about the real thing.

[The close-out design](../plans/milestone-0-close-out.md) carries this reasoning
at length, together with the sweep that makes the two governing documents agree
with it. This record is that design's §8.1 deliverable and states what the
contract now is.

## Measurements

Measured 2026-08-22 against the shipped tree at commit `7cd6542` — the commit
this record's own text was last written against — on branch `docs/m0-close-out`,
on Darwin 25.5.0 arm64, Chez 10.4.1. AGENTS.md requires a number in a decision
record to have been re-taken against the shipped artifact; these were re-taken
here rather than copied from the close-out design, whose `docs/plans` figure
predates that directory gaining this slice's own two documents.

- **The apparatus outweighs the product it is built around by two orders of
  magnitude.** [0005](./0005-chez-only.md) recorded the same observation on
  2026-08-18 at 9,858 harness lines against 147 product lines (0005:41–44).
  Re-run at this commit, 0005's own two commands give **8,460 against 87** —
  97:1, where 0005 measured 67:1. The gap widened, and not because the harness
  grew: it shrank by 1,398 lines when the Chez-only cut landed, and the product
  shrank faster. The four commands below them are this record's own set, and
  their total is not subtracted from 0005's — but the difference is not a wider
  net: both sets are 29 files and 28 are shared, and 0005's includes
  `cmake/chez-probe.ss` (13 lines) where this one includes `test/CMakeLists.txt`
  (729), so this set is 716 lines *larger*.

  ```
  $ find cmake test/support -type f | xargs wc -l | tail -1
      8460 total
  $ find src -type f | xargs wc -l | tail -1
        87 total

  $ wc -l src/byte-machine/*.sls | tail -1
        87 total
  $ cat cmake/*.cmake test/support/cmake/*.cmake test/CMakeLists.txt | wc -l
      6828
  $ cat test/support/harness/byte-machine/test/*.sls \
        test/support/harness/self/*.sps test/support/launchers/*.ss | wc -l
      2348
  $ cat docs/plans/*.md | wc -l
     20020
  $ git rev-parse --short HEAD
  7cd6542
  ```

  9,176 lines of build layer, harness, and launchers, and 20,020 lines of plans,
  against 87 lines of product.

- **All 87 lines of `src/` are placeholder.** `src/byte-machine/` contains
  exactly `placeholder.sls` and `placeholder-consumer.sls` — spike §7 D3's
  tagged value and the second library that recognises it. Spike §11 schedules
  the tagged value for deletion in Milestone 1 and names only it (spike:230);
  the library that recognises it goes with its subject, but the spike does not
  say so. No byte-machine semantics ship, by spike:6.

These numbers are recorded because they are what the close is weighed against,
not as a complaint about what came before. Every layer above `src/` was earned:
the exit-code vocabulary, the fingerprint and provenance instrument, and the
mutation suite each exist because a specific defect class was demonstrated
first. Slice 6 is the first item whose cost buys no product and no protection of
product — by construction, because it has no product to be about.

## Decision

1. **Milestone 0 closes.** Its work order ends at item 5 as delivered. Spike §8
   item 6 (D6, D7) is not executed as written; item 7 (D8, D9 — spike:202)
   splits. Its D9 half — decision records in `docs/decisions/` and an initial
   `CHANGELOG.md` (spike:190) — **is** delivered: seven records and a
   `CHANGELOG.md` ship, this record among them. Its D8 half is what point 4
   below moves. What Milestone 0 shipped is the harness, the build layer, the
   two Chez execution lanes, the provenance discipline around them, and the
   decision series that records why each exists — the spike's stated purpose —
   and it stops there.

2. **Spike §7 D6 moves to parent §25's Milestone 1 Scope line "deterministic
   output"** (parent §25:1447). The emitter Milestone 1 builds is the writer
   whose determinism D6 is a claim about, so in Milestone 1 the claim has a
   subject.

3. **Spike §7 D7 moves to Milestone 1's "symbolic name resolution"** (parent
   §25:1440) **and "generated-name safety for every construct present"** (parent
   §25:1444). The `[a-z][a-z0-9-]*` repertoire is what name resolution validates
   against; the binary-LF half rides with the emitter's output port.

4. **Spike §7 D8's CI pipeline moves to Milestone 1 alongside D6's cross-cell
   axis, because both need the same four Tier 1 platforms.** Splitting them is
   what made slice 6 unresolvable, so they land together or not at all. D8's
   other half, the written feasibility notes, is discharged by
   [the CI feasibility note](../plans/milestone-0-ci-feasibility.md), which this
   slice ships.

5. **Milestone 1 has no Deliver list — it has a Scope list, and two of the three
   land on lines already written in it.** D6 and D7 stop being owed by a
   milestone that cannot produce them and start being owed by the milestone that
   already asks for them; nothing is added to Milestone 1 for either. D8's
   pipeline is the exception: Milestone 1's Scope has no CI entry, so the
   pipeline rides D6's cross-cell axis rather than a line of its own. Parent
   §25's **Milestone 9** already carries "complete Tier 1 CI" and "source
   generation equality across platform cells" (§25:1602–1603) — the same two
   obligations. The division that makes both true: Milestone 1 stands the
   pipeline up over the emitter, on the cells it can get, and Milestone 9
   completes the Tier 1 matrix. "Complete" presupposes something to complete,
   which is why the pipeline cannot wait for Milestone 9. It is the one
   obligation this record places on Milestone 1 that Milestone 1's Scope does not
   already carry.

## Parent plan §30 questions 1–4

This is why the closure needs a record rather than only a plan section: spike
§12's ninth exit criterion (spike:244) requires that "§30 questions 1–4 are
answered in `docs/decisions/` and backed by tests", and spike:216 calls 1–4 hard
requirements. Each answer below states its evidence level, because "answered" and
"answered by a measurement" are not the same claim.

1. **Minimum Chez release.** Pinned at 10.4.1 — verified, and the only version
   any measurement in this repository records. The *floor* is unestablished:
   establishing it needs an older release under CI, which
   [0001](./0001-toolchain-discovery.md)'s Consequences already say ("lowering
   these pins is that question's answer and needs CI evidence from the older
   release"). Evidence: the probe's version gate
   (`cmake/ByteMachineChez.cmake:46`, enforced at :139–142), which is executable
   and mutation-covered — `MutationSuite.cmake` carries "chez: version floor
   removed" and "chez: absent version floor no longer refused, so the guard fails
   open". Answered as a **pin with a stated open floor** — not as a measured
   floor.

2. **Exact source and AOT commands per Tier 1 platform.** Answered for macOS
   arm64 by the shipped launchers — `test/support/launchers/chez-source.ss`,
   `chez-aot.ss`, and `chez-compile.ss` — which are executable rather than
   documentary: every registered Scheme lane invokes one of them on this host
   (`cmake/ByteMachineSchemeLane.cmake:129`, `:151`, `:272–283`). Evidence: the
   lanes themselves. Per-platform variance is **unmeasured** and rides with D8.

3. **Windows library search paths. Both halves closed, neither by measurement.**
   The include half is closed **by absence**: [0006](./0006-inline-libraries.md)
   moved every body inline, so there is no `include` left to resolve. The
   separator half was closed **by construction** in
   [0002](./0002-shared-body-include-mechanism.md):143–147 — "because the
   launcher takes repeatable flags, byte-machine never joins Chez search paths
   with any separator on any platform, so the `:` vs `;` question has no
   Chez-side object left to apply to." That is a stronger closure than a
   documentary answer, because it removes the object the question is about rather
   than describing it, and it is **not** superseded by 0002's include-mechanism
   retirement: the flag protocol survives `--source-dir`. What 0002 left open is
   a different question — Windows path form: backslashes, drive letters, and what
   counts as an absolute pathname — and that one is unmeasured and rides with the
   Windows cell.

4. **Condition construction available to consumers** (parent §30:1723). Closed
   by [0005](./0005-chez-only.md): one implementation, plain R6RS conditions,
   and no portability layer left to expose anything else. Parent §30 already
   carries its own annotation on this one — "*(Moot: it is plain R6RS
   `condition`/`raise`; no wrapper layer exists to expose anything else.)*" — so
   this record confirms that annotation rather than establishing it. Spike
   §9:211 restates the question as "Portable condition construction exposed by
   the wrappers", and the layer that phrasing names is the one 0005 removed.
   A **closure by decision**, not a deferral.

Questions 5–7 are the spike's own "deferred, with rationale" cases (spike:216);
question 6 — identifier length and source-size limits in supported compilers —
is D7's companion and rides with it, because the grammar imposes no maximum and
measuring compiler limits before there is generated source to hit them measures
nothing.

## Consequences

- **What closing buys.** The milestone stops being open on three items that none
  of its own exit criteria demand, and the tree stops instructing the next reader
  to satisfy an exit condition that no longer has a subject. Spike §8 item 6 has
  been unsatisfiable since [0005](./0005-chez-only.md) removed the second
  implementation — four days, 0005's `Date: 2026-08-18` (0005:3) to this
  record's 2026-08-22 — and it consumed a planning cycle before it was read
  against the tree; leaving it there costs that again.

- **What it defers, by name.** Deterministic byte-identical emission (spike §7
  D6); the identifier repertoire and binary-LF proofs (spike §7 D7); the running
  CI pipeline and with it the Linux amd64, Linux arm64, and Windows amd64 Tier 1
  platforms (spike §7 D8's pipeline half); the actual Chez version floor (§30
  question 1); per-platform source and AOT command variance (question 2); Windows
  path form (question 3's remainder); and identifier and source-size limits
  (question 6). None is dropped; each is named above with the Milestone 1 line or
  the cell it arrives with.

- **The named risk: a portability regression during Milestone 1 will surface
  late, because D8 moved.** Until the pipeline runs, every claim this project
  makes about Linux, Windows, and arm64-versus-amd64 rests on construction and on
  one host. A build-layer or launcher change that breaks a cell nobody runs will
  be found by the Milestone 1 slice that finally stands the pipeline up, on top
  of whatever else that slice is carrying, rather than by the commit that caused
  it. That is the price of this decision. It is stated rather than hedged, and it
  is accepted because CI over 87 lines of placeholder protects nothing, while CI
  over the emitter protects the byte-identity claim that is D6's whole point.

- **Parent §25's Milestone 0 exit criteria are three, and D6 and D7 appear in
  none of them.** They are (parent §25:1431–1433): "the same shared test body
  passes in both the source and AOT execution lanes" (met before this slice);
  "CI design covers unavailable local platforms"; and "each library owns its own
  code — no shared include bodies", met by [0006](./0006-inline-libraries.md) —
  met as a fact about the tree rather than by a gate: `rg '\(include' src test`
  returns no hits at this commit, but 0006's check is a runnable acceptance
  check, **not a registered lane**, so nothing in `ctest` fails if an include
  reappears. The second criterion is D8's written-feasibility-notes half, and it
  **is discharged by** [the CI feasibility
  note](../plans/milestone-0-ci-feasibility.md) — a design covering the
  unavailable cells, which is what the criterion asks for, and not a pipeline,
  which is what moves.
