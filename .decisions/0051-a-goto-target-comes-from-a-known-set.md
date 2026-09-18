# 0051: A goto target is chosen at run time from a set fixed at emit time

Date: 2026-09-17
Status: accepted
Milestone: 14, Gate 0
Builds on: [0048](0048-what-material-improvement-means.md) (the thresholds this is judged against), [0049](0049-a-state-is-a-procedure-not-a-case-arm.md) and [0050](0050-a-byte-class-is-a-range.md) (the same defect, twice already)
Amends: [0049](0049-a-state-is-a-procedure-not-a-case-arm.md) (the sentence it left beside `%dispatch`)

## Context

[0049](0049-a-state-is-a-procedure-not-a-case-arm.md) turned the outer state
`case` into mutually tail-calling procedures and left one linear `case`
standing — `%dispatch`, for the targets that are not known at emit time. It
wrote this beside it:

> The one dispatch that survives, and the three places that need it: the entry
> into a feed, a callback answering `goto`, and a keyword table's jump. All
> three carry a target computed at RUN time, and all three happen once per
> call, per callback and per keyword — **never once per byte — so a linear case
> here costs nothing the per-byte path can see.**

Every clause of that sentence is true except the conclusion. "Not once per
byte" is not "not often": an HTTP grammar crosses a callback, a span fragment
or a span completion about **four times per header**, and at 0.31 ns per arm
skipped a 217-state machine pays about 34 ns for each crossing. Measured,
`many-small-headers` was losing more than a third of its time inside
`%dispatch`.

The sentence is the defect this record is really about. It is the third
instance of one habit — a linear scan whose cost was **argued away instead of
measured** — after 0049 (the state dispatch) and 0050 (the byte dispatch), and
it was written *by* the record that fixed the first one.

## The thing the arm already knows

A callback's target is not known until the callback returns. The **set** it is
drawn from is known: `classify-callback-result` can answer only the node's
continue target, one of its declared branch targets, or its default — and the
emitter renders all three as literals *into that very call*, two lines above
the dispatch. A span fragment's set has one member; a span completion's has
one.

## Decision

1. **The three arms that call application code render one clause per distinct
   declared target** and jump directly, exactly as `render-byte-clauses` does
   one level down. `render-goto-clauses` dedupes (a `default-branch` resolves
   to a branch target) and skips `#f` (a required callback has no default).

2. **Continue is rendered first.** The clauses are a linear scan, so their
   order *is* the optimization, and a bound callback answering `continue` is
   the outcome that actually happens. This is asserted, not left to the
   renderer's argument order.

3. **`%dispatch` stays as the final clause.** Dropping it would convert an
   optimization of a total function into a claim about what the runtime can
   return — checkable only by reading `runtime.sls`, and silently wrong the day
   a fourth outcome is added. It costs one comparison on a path no construction
   reaches.

4. **The mutation that pinned the old jump moves onto the clause that runs.**
   It was anchored to the `%dispatch` line, which is now exactly the clause
   nothing reaches: left there it would survive, and the check would silently
   stop covering anything. This is the suite's own diagnostic ("update the
   mutation rather than deleting it") applied to a line that became dead rather
   than moved.

5. **The keyword table's jump is left alone**, though its target set is known
   here too. It is not measured yet, and assuming it would pay is the mistake
   this record exists to correct.

## Evidence

Generated lane, nine rounds of sixteen thousand iterations, `tarm64osx`, Chez
10.4.1, one instrument (`bench/runner/benchmark.sps` with
`BYTE_MACHINE_BENCH_EXECUTORS=generated`) run on both trees. Combined with
[0052](0052-a-callback-outcome-is-the-object.md), which shipped alongside:

| workload (admissible)             | before | after | delta  |
|-----------------------------------|-------:|------:|-------:|
| `long-exact-sequence-matching`    | 118 ms | 59 ms | -50.0% |
| `many-small-headers`              |  90 ms | 51 ms | -43.3% |
| `dense-byte-dispatch`             |  90 ms | 51 ms | -43.3% |
| `long-method-target-header-spans` |  69 ms | 67 ms |  -2.9% |
| `byte-at-a-time-fragmentation`    |  39 ms | 41 ms |  +5.1% |

Three admissible workloads past 0048's 20% bar. Emitted text grows 1.6% for
this record's half (114 880 -> 116 711 bytes on the HTTP machine).

**The +5.1% is real and unexplained.** The dispersions do not overlap (38-39
against 41-44 over nine rounds), so it is not noise; it is below 0048's 10%
significance bar, so by that record's own vocabulary it is not a regression,
and this record says so rather than leaning on the arithmetic. The obvious
hypothesis — `byte-at-a-time-fragmentation` is the only workload that re-enters
`exec` 37 times per message, so a 1.6% larger `exec` costs it 37 times over —
is **contradicted by the measurement**: 0052 grew the emitted text a further
1.1% and recovered a millisecond. Not attributed, and recorded as not
attributed.

Reopening condition: `%dispatch` is still a linear scan for the one entry it
genuinely cannot avoid — the feed entry, which `byte-at-a-time-fragmentation`
pays 37 times per message where every other workload pays once. If that
dispatch is ever made sub-linear, this workload is where it will show, and the
5% is the first thing to re-measure.

## Consequences

- `render-goto-clauses` is shared by three arms, so the zero-width property is
  pinned in one place rather than three. The mutation that proves it moved
  there with it.
- The emitted text gets a fourth `cond` shape. Its clause count is bounded by
  the node's declared branch count, which the IR already bounds.
- The sentence beside `%dispatch` is rewritten to say which places still enter
  it and why the two that remain are not the same argument.
