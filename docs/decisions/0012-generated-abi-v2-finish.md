# 0012: The generated ABI grows a finish path under /v2 (a unified exec)

Date: 2026-08-28
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.2)

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
- Retiring `/v1` from emitter output inverts the Milestone 1 `/v1` runtime-test
  group and moves the two goldens (the rendered string embeds the ABI tag and the
  IR fingerprint, which also moves under decision 0011's EOF encoding); Slice ②
  rewrites that test group as `/v2` and re-baselines. Parent §9.5 also requires a
  CHANGELOG.md entry for a pre-1.0 ABI change; Slice ② carries it.
- This functional `/v2` is distinct from the benchmark-gated `feed-outcome` `/v2`
  (0010 Consequences / Slice-B amendment, still gated on §23) and from the coded
  ABI-mismatch condition (0010 item 5, still deferred — decision 0013 only unblocks
  it).
