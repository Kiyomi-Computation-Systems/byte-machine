# 0012: The generated ABI grows a finish path under /v2 (a unified exec)

Date: 2026-08-28
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.2)

> **Amendments** — a later note at the foot of this file reaches back into the
> text above it. Nothing above a note is rewritten: the tree this record was
> decided against is its evidence.
>
> - **2026-08-31 (Milestone 4)** — **amends item 1 and the first Consequences
>   bullet**: [decision 0018](./0018-unversioned-generated-abi-constructor.md)
>   retires the `/vN` constructor *name* for one unversioned constructor. The
>   version check item 1 exists to protect is kept, and the note records items 2,
>   3 and 4 as standing.

## Context

`parser-finish!` (decision 0011) must drive the *generated* executor with no
bytes. That is a new runtime<->generated contract. Decision 0010 **item 4** already
fixed how such a change is made: the seam "extends by a `/v2` constructor rather
than an arity break," and "the version tag exists for exactly that." Two neighbours
are *not* this: 0010's Consequences / Slice-B amendment reserve a benchmark-gated
`/v2` of the `feed-outcome` *record* (optimization, gated on §23 evidence), and
0010 item 5 defers a coded ABI-mismatch condition. This record is the functional
`/v2` item 4 anticipated.

## Decision

1. **Add `byte-machine-make-compiled-machine/v2`; bump `current-abi-version` to 2.
   The emitter emits `/v2`; the runtime KEEPS its `/v1` export.** "Retire `/v1`"
   means from emitter *output* only — keeping the `/v1` export lets a stale
   generated file embedding version 1 fail the ABI-version *check* cleanly (an
   assertion), not fail at import with an unbound identifier.

   > **Amended 2026-08-31 (Milestone 4)** by
   > [decision 0018](./0018-unversioned-generated-abi-constructor.md) — the
   > emitter no longer emits `/v2` and `current-abi-version` is no longer 2. The
   > reason given here for keeping the old export is carried forward unchanged.
   > See the dated note below; the item above is left as decided.

2. **The generated machine exposes one unified `exec` closure carrying a `finish?`
   flag**, not two closures. `exec` is Milestone 1's feed loop; the only *branch*
   that changes is the exhausted-dispatch arm — feed returns `need-input`, finish
   takes the eof-target (decision 0011). The terminal state arms are **one per
   kind and distinct**: `stop` emits `stopped`, `finish` emits `finished`, `error`
   emits `error`, and (Slice ③) pause emits `paused`. §16.2's finish-terminal and
   EOF-reachable-stop checks guarantee the stop and finish arms are each reached
   only on their own path, so no arm is relabeled across paths.
3. **The `feed-outcome` record shape is reused.** `paused` and `finished` are new
   status *symbols*, not a new record. `parser-resume!` and `parser-reset!` touch
   only runtime lifecycle state — no generated call, no ABI surface.
4. **The reserved-output-binding mirrors gain enumerated deltas.**
   `reserved-member-2` (the hand-maintained mirror of `(byte-machine runtime)`
   exports) gains `byte-machine-make-compiled-machine/v2`, `parser-finish!`,
   `parser-resume!`, `parser-reset!` and **keeps** `/v1` and the `/v1`
   feed-outcome constructor; `reserved-member-3` (emitter-template identifiers)
   gains `exec`, `finish?`, and any locals the finish/pause arms emit. Both are
   updated in the same commit as the exports/template they mirror, so the drift
   guard stays load-bearing.

## Consequences

- The emitter renders `exec` with the `finish?` branch and a distinct `finish`
  arm, and constructs the binding via `byte-machine-make-compiled-machine/v2`.

  > **Amended 2026-08-31 (Milestone 4)** by
  > [decision 0018](./0018-unversioned-generated-abi-constructor.md) — the
  > emitter constructs the binding via the unversioned
  > `byte-machine-make-compiled-machine`. See the dated note below.

- Retiring `/v1` from emitter output inverts the Milestone 1 `/v1` runtime-test
  group and moves the two goldens (the rendered string embeds the ABI tag and the
  IR fingerprint, which also moves under decision 0011's EOF encoding); Slice ②
  rewrites that test group as `/v2` and re-baselines. Parent §9.5 also requires a
  CHANGELOG.md entry for a pre-1.0 ABI change; Slice ② carries it.
- This functional `/v2` is distinct from the benchmark-gated `feed-outcome` `/v2`
  (0010 Consequences / Slice-B amendment, still gated on §23) and from the coded
  ABI-mismatch condition (0010 item 5, still deferred — decision 0013 only unblocks
  it).

## 2026-08-31 (Milestone 4) — the versioned name is retired; the check is not

Milestone 4 Gate 0 (decision 0018, milestone-4-design.md §4.1) replaces the
`byte-machine-make-compiled-machine/vN` family with **one unversioned
`byte-machine-make-compiled-machine`** whose first action is the
`(= abi-version current-abi-version)` check, and whose payload is carried as a
quoted vector so it can grow without an arity break. `current-abi-version` goes
2 → 3. Slice ①a lands it. This annotates item 1 and the first Consequences
bullet; the tree those were decided against is their evidence, so they are not
rewritten.

**Item 1's purpose survives; only its mechanism goes.** The reason given here
for keeping the `/v1` export — that a stale generated file embedding an old
version must "fail the ABI-version *check* cleanly (an assertion), not fail at
import with an unbound identifier" — is carried forward unchanged and is the
whole warrant for the new arrangement. `/v1` and `/v2` both remain exported, as
tombstones, for exactly that. What changes is how they discharge it: each is
rewritten to refuse *every* version unconditionally, rather than to reject as a
side effect of a version comparison.

**Measured, against `a942327`.** `/v1` (runtime.sls:50-56) compares against
`current-abi-version`, which is 2 (runtime.sls:49), so it already rejects the
version 1 it is named for: it is not a compatibility path and never was. `/v2`
(runtime.sls:65-71) does **not** compare against `current-abi-version` — it
tests the literal `2` at runtime.sls:66 — so bumping the constant to 3 does not
retire it; without the rewrite it would keep accepting the version it names.
The two old constructors therefore do not inherit their refusal from the bump
and must each be given it explicitly.

**False from Slice ①a onward:**

- item 1's "The emitter emits `/v2`", and the first Consequences bullet's
  "constructs the binding via `byte-machine-make-compiled-machine/v2`". The
  emitter emits the unversioned name; the pre-slice `/v2` literal is at
  `compile.sls:164`.
- item 1's "bump `current-abi-version` to 2" as a statement of the current
  value. 2 is what Milestone 2 set; the constant is 3 from Slice ①a.

**Untouched.** Items 2 and 3 stand: one unified `exec` closure carrying a
`finish?` flag, one distinct arm per terminal kind, and the reused
`feed-outcome` record with new status symbols. (Slice ①a widens `exec`'s
emitted parameter list from six to seven under a separate Gate 0 record,
milestone-4-design.md §4.2; that is an arity change to item 2's closure, not a
change to its shape.) Item 4's mirror obligation stands and is what governs:
`reserved-member-2` keeps `/v1`, `/v2` and the `/v1` feed-outcome constructor,
gains the unversioned name, and is updated in the same commit as the exports it
mirrors. `byte-machine-make-feed-outcome/v1` keeps its versioned name; 0018
reaches only the compiled-machine family. The general rule this record invoked —
decision 0010 item 4's seam that "extends by a `/v2` constructor rather than an
arity break" — is amended by 0018 as well.
