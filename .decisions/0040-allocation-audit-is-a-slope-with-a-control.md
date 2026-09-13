# 0040: The allocation audit is a slope with a control, not a budget

Date: 2026-09-12
Status: accepted
Milestone: 9, Gate 0 (milestone-9-design.md §4.3)

## Context

Decided against `main` at `c8e5fb6`; `src/` byte-identical to `62671b2`.

`§26:1680` has two halves: a *prohibition* — "generated per-byte paths contain no deliberate
list/vector/string/result construction" — and a *measurement* — "fixnum-sized allocation
measurements are recorded with callbacks disabled". A single absolute number serves neither: it
cannot separate per-message from per-byte allocation, and it becomes a threshold nobody can justify,
which `§23.3:1378` forbids before baselines establish variance.

## Decision

**1. The audit is a slope.** The same machine is fed two messages differing only in length;
allocation is differenced and divided by the byte difference. The design's P2 measures exactly `0.0`
B/byte for the generated executor, with the per-message intercept reported **separately** (400.08 B
construction + 1 008.03 B feed) so a per-message cost is never mistaken for a per-byte one.

**2. A live control in the same lane** — a loop allocating a known amount per byte, asserted
**nonzero**. *Rejected, with the failure it would cause*: a bare slope-of-zero assertion is
indistinguishable from a measurement apparatus that cannot move (AGENTS.md: "a slope of zero is
indistinguishable from a measurement that cannot move"); without the control, a broken measurement
passes green.

**3. Both executors measured, only the generated one asserted.** The interpreter's ~17 900 B/byte
(design P2) is *recorded, not gated*: `§18` asks nothing of its allocation, and it is the oracle,
not the subject.

**4. Callbacks disabled, as `§26:1680` words it** — `'()` bindings — with the callback-bound figure
recorded beside it so the difference is visible, not hidden.

## Consequences

- **Handed to Slice ③**: the allocation lane (slope, live control, both executors,
  callbacks-disabled figure beside the callback-bound one), and `§30` question 5's answer recorded
  in a test (obligation 4).
- **Handed to Slice ④**: the recorded figures into `§27:1699`'s benchmark documentation.
- **A mutation pin for Slice ③**: the control's **nonzero** assertion (mutated to `>= 0`, or the
  control dropped) and the generated-executor slope bound, each with its failure signature asserted
  — the pins AGENTS.md's "a mutation caught for the wrong reason" rule requires.
- No `src/` change: `§26:1680`'s prohibition half is a property of the shipped generated paths,
  read and asserted by the audit, not edited by it.
