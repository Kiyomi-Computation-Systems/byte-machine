# 0052: A callback outcome is the object, not a list naming it

Date: 2026-09-17
Status: accepted
Milestone: 14, Gate 0
Builds on: [0048](0048-what-material-improvement-means.md) (the thresholds), [0051](0051-a-goto-target-comes-from-a-known-set.md) (shipped alongside)
Amends: [0010](0010-direct-executor-abi.md) (takes up its reserved revisit), [0040](0040-allocation-audit-is-a-slope-with-a-control.md) (adds the second slope)

## Context

[0010](0010-direct-executor-abi.md) reserved exactly this, and gated it on
exactly this:

> Slice B may revisit the `feed-outcome` seam under a `/v2` ABI **if benchmark
> evidence ever calls for it** (parent §23).

The evidence arrived. `classify-callback-result` answered `(goto TARGET)`,
`(pause)` or `(failure CODE DETAIL)` — a freshly consed list whose first
element named which of three cases the rest was. Two conses, 32 bytes, on
**every** crossing of the callback seam, and an HTTP grammar crosses it about
four times per header.

## The audit could not see it

`§26:1680`'s prohibition is about per-BYTE allocation and
[0040](0040-allocation-audit-is-a-slope-with-a-control.md) measures exactly
that: two messages differing only in the length of one header **value**, so
the header COUNT is held fixed. 128 bytes per header is invisible to that
slope. It reads instead as part of the per-message intercept, which 0040 item 1
deliberately reports separately and never divides by anything.

So the audit was green while the generated lane's allocation grew linearly in
the one dimension real traffic actually varies. It was visible all along in the
committed baseline, for anyone who subtracted two rows:
`many-small-headers` 5 216 B/message against `short-normal-requests` 1 504,
over 29 extra headers, is 128 B/header exactly — four 32-byte lists.

## Decision

1. **The classifier answers the outcome itself.** A TARGET for a goto, the
   `callback-pause` singleton for a pause, and the `CallbackFailure` record for
   a failure — which the application already allocated, and which is now passed
   through rather than unpacked and re-consed.

2. **Both lanes decode with the same two predicates**, `(eq? o callback-pause)`
   and `callback-failure?`, and anything else is a target. The three cases are
   disjoint **by type**: a target is an exact integer in the generated lane and
   a symbol in the interpreted one, while the other two are tagged vectors, and
   nothing a machine can declare closes that gap — a state id is not a vector
   and `portable-name?` keeps a node name from being one. The order is
   therefore free, and the two lanes use different orders: the emitted arm
   tests its literal targets first (they are what happens), the interpreted arm
   tests them last (it cannot test a target it does not know).

3. **What is NOT given up is the single producer.** `§`'s reason for the seam
   was that callback results are compared across lanes and must be produced by
   both from the same construction. `classify-callback-result` is still the
   only thing that decides which of the three an application's return value is.
   What is dropped is a tag that told a consumer nothing the object did not
   already say about itself.

4. **The contract-violation failure is built once.** It is the one failure no
   application constructed, it carries no detail and no per-call state, and a
   shared immutable record is indistinguishable from a fresh one to every
   reader.

5. **This is ABI 9, and the two step entry points are now `/v2`.** An ABI-8
   generated library decodes the answer with `car`, which a fixnum does not
   answer, so the mismatch must be caught at construction and not at the first
   callback — which the version check does, in the direction this repository's
   own build actually produces (a stale object meeting a newer runtime, since
   Chez prefers a compiled object and staleness is transitive). The `/v1`
   spellings become **tombstones**, on
   `byte-machine-make-compiled-machine/v1`'s precedent: a stale generated file
   has to EXPAND before its own ABI check can run, and an unbound identifier at
   expansion is not the clean refusal.

6. **The allocation audit grows a second slope, per HEADER**, with its own live
   control (0040 item 2 applied to the second dimension) — because a slope of
   zero is indistinguishable from a measurement that cannot move, in whichever
   dimension it is taken. Two requests differing only in header count; what
   makes the difference attributable to headers rather than to their bytes is
   the per-byte slope being zero, asserted in the same lane, with callbacks
   bound as well as disabled.

## Evidence

Per-header allocation in the generated lane, asserted in
`test/common/allocation-audit-tests.sps`, both lanes and both wordings:

| | callbacks disabled | callbacks bound |
|---|---:|---:|
| before | 128 B/header | 128 B/header |
| after  |   **0**      |   **0**      |

Per-message allocation stops depending on the message's shape. From the
benchmark's own `allocation-bytes-per-message`, generated lane:

| workload                       | before  | after |
|--------------------------------|--------:|------:|
| `long-exact-sequence-matching` | 8 800 B | 1 168 B |
| `many-small-headers`           | 5 216 B | 1 168 B |
| `pipelined-requests`           | 3 040 B | 1 168 B |
| `chunked-bodies`               | 2 432 B | 1 296 B |
| `short-normal-requests`        | 1 504 B | 1 168 B |

Five workloads of different shapes converge on one figure: what remains is the
parser and the feed outcome, and nothing that scales with headers, messages or
length. `byte-at-a-time-fragmentation` still scales, at one feed outcome per
feed, which is a different seam.

Time, measured with 0051 (the two shipped together and the table is in 0051):
this half is worth 3-5 ms of the 39 ms `many-small-headers` improvement. The
allocation is the point; the time is a bonus, and saying so is the honest order.

## Consequences

- **A pin bump in `chez-httparse` is mandatory, not optional.** ABI 9 refuses
  an ABI-8 generated parser, so the downstream must regenerate in the same
  commit it bumps — which is what decision 0005 item 3 there already requires,
  and item 5's "the ABI is re-read at each pin" now has something to read.
- Nine mutations moved. Four are the `car`/`cadr`/`caddr` readers becoming
  accessors, three are lane-decode reorderings, one is the ABI literal, one is
  0051's.
- The tombstones are dead code by construction and stay exported anyway. The
  same is true of `byte-machine-make-compiled-machine/v1` and `/v2`, and for
  the same reason.
