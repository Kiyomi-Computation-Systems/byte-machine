# 0053: The feed entry is a search, not a scan

Date: 2026-09-18
Status: accepted
Milestone: 14, Gate 0
Builds on: [0048](0048-what-material-improvement-means.md) (the thresholds), [0049](0049-a-state-is-a-procedure-not-a-case-arm.md), [0050](0050-a-byte-class-is-a-range.md), [0051](0051-a-goto-target-comes-from-a-known-set.md) (the same defect, three times already)
Amends: [0051](0051-a-goto-target-comes-from-a-known-set.md) (what it left standing, and why that was not a reason to stop)

## Context

This is the fourth instance of one defect, and the fourth record to fix it.
Each of the previous three named what it was **not** fixing, and each of those
became the next one:

| record | fixed | named and left |
|--------|-------|----------------|
| 0049 | the state `case` | "the entry into a feed, a callback answering `goto`, and a keyword table's jump ... a linear case here costs nothing" |
| 0050 | the byte `case` | (nothing; it closed a comment that had been open since Milestone 3) |
| 0051 | the callback `goto` | "the keyword jump's target set IS known here ... and is not yet measured; it is left alone rather than assumed" |

0051 was right about the feed entry: its target is the state the parser is
parked in, so `render-goto-clauses`' trick — test the literals the emitter
already wrote — does not apply. **It cannot be a literal. It can stop being
linear**, and 0051 did not ask that question.

## What it costs

Measured in situ on `chez-httparse`'s 530-state message machine, which is the
largest machine either project has: a copy of the emitted parser with
`%dispatch`'s `(case st ...)` replaced by a binary search over the same ids,
loaded ahead of the real one with a load marker proving which copy ran (the
correction AGENTS.md records from the permutation experiment). Three runs of
each, Chez 10.4.1, `tarm64osx`:

| | linear `case` | binary search | |
|---|---:|---:|---:|
| whole buffer | 167,084–167,224 msg/s | 176,056–176,522 | **+5.6%** |
| byte at a time | 25,109–25,300 msg/s | **44,395–44,692** | **+77%** |

Spans under 0.8% across three runs on each side.

**The byte-at-a-time figure is the same number `byte-at-a-time-fragmentation`
has been reporting all along, from the other side.** 0051 recorded a +5.1%
cost on that workload and declined to attribute it. It is the only workload
that re-enters `exec` once per byte, so it is the only one that pays the feed
entry more than twice per message — it is not an unusual workload, it is the
one that measures this.

**The whole-buffer figure is the keyword jump.** One feed entry per message
cannot be 5.6% of a parse. A request with eight headers crosses `%dispatch`
about ten times — the entry, the method table, and one per header name — and
at roughly 48ns saved per crossing that is about 335ns of a 5.98µs parse,
which is what was measured. That is an inference from two measurements, not a
third measurement, and is marked as one; what it settles is that 0051's "left
alone rather than assumed" no longer needs its own experiment.

## And what byte-machine's own benchmark can see of it

Nine rounds of sixteen thousand, both executors, the committed instrument on
both trees:

| workload (admissible)             | before | after | delta  |
|-----------------------------------|-------:|------:|-------:|
| `byte-at-a-time-fragmentation`    |  41 ms | 32 ms | **-22.0%** |
| `many-small-headers`              |  52 ms | 51 ms |  -1.9% |
| `dense-byte-dispatch`             |  52 ms | 51 ms |  -1.9% |
| `long-method-target-header-spans` |  67 ms | 67 ms |   0.0% |
| `long-exact-sequence-matching`    |  60 ms | 60 ms |   0.0% |

**This does not meet [0048](0048-what-material-improvement-means.md) rule 2,
which asks for 20% on three admissible workloads.** It is 20% on one, and flat
on four. Saying so is the point of having the rule; what follows is the reason,
not a way around it.

`test/support/harness/byte-machine/test/http-machine.sls` has **217 states and
no keyword table**. Its whole-buffer workloads therefore cross `%dispatch`
**exactly once per message**, over a scan averaging 108 arms — about 33ns of a
3.2µs parse, which is the 1% those rows show. There is nothing for the change
to remove there. `chez-httparse`'s message machine has 530 states *and* keyword
tables, so a whole-buffer parse of an eight-header request crosses the same
dispatch about ten times, and gains 5.6%.

So the shortfall is a property of the INSTRUMENT: **the benchmark's machine is
less than half the size of the largest machine this project's ecosystem
generates, and this cost is proportional to size.** Adding byte-at-a-time
variants of other inputs would reach three workloads and would be fitting the
instrument to the result — every one of them would measure the same crossing.
They are not added.

What is offered instead is the shape of the evidence, stated plainly: one
admissible workload past the bar, four unchanged (nothing traded away), a
shared code path that every workload executes and only one executes often, a
mechanism that predicts exactly which rows move and by how much, and a second
machine on a different grammar where the same change is worth 5.6% and 77%.

## Decision

1. **`%dispatch` renders a balanced binary search over the state ids**:
   ceil(log2 N) comparisons where the scan averaged N/2 arms. The leaves are
   the same tail calls the `case` arms were, so the state procedures still
   never escape and 0049's direct jumps are untouched.

2. **A JUMP TABLE IS REJECTED, and not on taste.** A vector of the state
   procedures indexed by id is O(1), but storing them makes every one of them
   *escape*, and they close over `exec`'s `bv`, `end`, `finish?`, `fieldv`,
   `psr` and `cbv` — so Chez would have to build N closures on every `exec`
   entry, which is the per-feed path this record exists to make cheaper.
   Hoisting them out would mean passing those six as arguments on every
   transition instead, which is the hot path paying for the cold one. This is
   0050's reason for rejecting bucketing, one level out: the fast shape is the
   one that keeps them local.

3. **The leaves carry no test of their own**, which is sound only if the state
   ids are exactly `0..N-1` in order. Lowering assigns them that way, but this
   renderer would answer the WRONG state for a gap rather than fail — a live
   state routed to its neighbour, silently, with no fixture obliged to notice.
   **`render-machine` checks it at emit time** and raises, rather than
   inheriting the invariant by assumption.

4. **The in-range guard replaces the `case`'s `else` arm** and is not dropped.
   A search with no bound check answers *some* state for every integer, which
   is strictly worse than the scan it replaces. It also makes `fx<?` safe,
   which needs the operand to be a fixnum.

5. **The test asserts the property, not the shape.** No state is reached by
   more comparisons than `ceil(log2 N) + 1`, measured over two witnesses of
   different sizes, because a single size cannot tell a bound that is a
   function of N from a constant that happens to fit. A scan fails it at any N
   above the bound; a tree whose midpoint was computed wrongly fails it too,
   which a substring check on the emitted text would not catch. Every state is
   separately asserted to appear exactly once, which is what makes the depth
   bound a statement about a total function.

## Consequences

- Emitted text grows: the HTTP machine's golden goes 118 023 → 129 379 bytes
  (+9.6%). An internal node is smaller than the `case` arm it replaces but
  there are N-1 of them on top of N leaves. Recorded as this record's
  complexity cost, against the 44% 0050 gave back.
- **`byte-at-a-time-fragmentation` stops being the workload that only ever
  regresses.** It is the one cell of the benchmark that measures the feed
  entry, and until now every optimization made the rest faster while it stood
  still or slipped.
- The keyword-table jump still goes through `%dispatch`, and now does so at
  log cost. Rendering its own target set as literals — 0051's unfinished
  business — is now worth much less and is not pursued.
- **The benchmark under-measures anything proportional to state count.** Its
  machine is 217 states with no keyword table; the ecosystem's largest is 530
  with them. That is not a reason to change the workloads — `§23.2` fixed them
  and a benchmark whose inputs move is not a baseline — but it is a reason to
  read a flat row as "this instrument cannot see it here" rather than as "there
  is nothing there", and to say which when it happens.
- `§23.3` criterion 3 stays undischarged: one platform cell, as for 0049–0052.
