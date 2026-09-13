# 0038: The release ledger is a checked artefact, and it is first

Date: 2026-09-12
Status: accepted
Milestone: 9, Gate 0 (milestone-9-design.md §4.1)

## Context

Decided against `main` at `c8e5fb6` (Milestone 9 design merged as #110); `src/` byte-identical
to `62671b2`, the design's base.

`§25:1665` makes this milestone's exit "all criteria in Section 26 are satisfied": fifteen criteria
in `§26`, eleven deliverables in `§27`, spread across five slices, and — per the design's §3.1
disposition against `62671b2` — nine of the fifteen already true. AGENTS.md names the failure mode:
"a plan step whose expected grep result is *described* gets reported as passing without being run",
and "prose expectations are not checks". The risk is not missing a criterion; it is *believing* one.

Milestone 8 Slice ⓪ proved the countermeasure — the error table of decision [0034], carried as data
a lane reads, self-ratcheting on totality rows.

## Decision

**1. `§26` and `§27` become data a lane reads, not prose a human audits.** A library
`(byte-machine test release-ledger)` carries one row per criterion, keyed on the criterion's
**text**, never its line number (line numbers move — Milestone 8 learned this at `§21.7:1209`). Each
row carries a *state* (`met`, `partly`, `open`), a *witness* naming what establishes it, and — for
the `open`/`partly` rows — the slice that receives it.

**2. Mechanical witnesses are checked; judgement witnesses are marked.** A row whose witness is
mechanical is *executed* by the lane: a named test lane must be registered, a `git ls-files` pattern
must match nothing, a named file must exist. A row whose witness is a judgement is marked
`judgement` and carries the close note's paragraph verbatim — the lane does not pretend to check it.
*Rejected, with the failure it would cause*: a ledger that "checked" a judgement row by recomputing
the expectation it was handed would be AGENTS.md's "sentinel computed from the test's own
expectation" — a green that asserts nothing.

**3. Two totality rows.** The ledger's criterion set against `§26`'s fifteen, and its deliverable
set against `§27`'s eleven, so adding or dropping one fails **by name**, floor-independently. Like
Milestone 8's error table, the ledger is therefore self-ratcheting and earns **no mutation-suite
entry of its own**.

**4. The ledger is first.** Slice ⓪ ships it before any criterion is worked, so the milestone
establishes which nine are already true before spending effort on the rest. A milestone that does
not will re-litigate the nine.

## Consequences

- **Handed to Slice ⓪**: `(byte-machine test release-ledger)` and its lane
  (`byte-machine.unit.release-ledger.chez.{source,aot}`), the initial rows written against the
  design's §3.1 disposition with each `met` row's witness **re-taken by the lane at its own base**,
  not copied from the design (AGENTS.md: "re-measure before citing your own earlier number").
- **Handed to every later slice**: a row to move from `open`/`partly` to `met`, and the totality
  rows that fail if the criterion set drifts.
- **Handed to Slice ⑤**: the ledger read at the close, its `open` rows reduced to exactly those the
  owner's amendments (decision [0041]) leave open for v0.1.
- **No mutation pin**: the two totality rows are the ratchet.

[0034]: ./0034-http-error-table-is-first-and-fixture-owned.md
[0041]: ./0041-tier-1-cells-under-a-stated-budget.md
