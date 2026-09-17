# 0048: What "material improvement" means, derived from observed baseline variance

Date: 2026-09-17
Status: accepted
Milestone: 14, Gate 0
Prerequisite for: [0049](0049-a-state-is-a-procedure-not-a-case-arm.md)

## Context

`§23.3` admits an optimization against six criteria, and forbids the first of
them from being quantified in advance:

> Crucially: **do not set a percentage threshold until the baselines establish
> normal variance**, and a single favorable microbenchmark is insufficient.
> Before the first optimization is admitted, a decision record must derive
> "material improvement" and "significant regression" from observed baseline
> variance.

No optimization has been admitted, so that record does not exist. This is it,
and it is written *because* a candidate arrived ([0049](0049-a-state-is-a-procedure-not-a-case-arm.md)),
not before one — which is the order `§23.3` intends: the rule exists so that a
threshold is derived from the instrument rather than chosen to fit a result.

## The committed baseline cannot answer the question it was recorded for

`bench/fixtures/baseline-tarm64osx.sls` was taken at five rounds of one hundred
iterations. Read back, ten of its twelve workloads have a **generated-lane
median of 0, 1 or 3 milliseconds**, with a recorded dispersion of one or two
milliseconds around it:

| workload                      | median | dispersion |
|-------------------------------|--------|------------|
| `short-normal-requests`       |   0 ms |      (0 1) |
| `fixed-length-bodies`         |   0 ms |      (0 1) |
| `chunked-bodies`              |   1 ms |      (0 1) |
| `many-small-headers`          |   3 ms |      (3 3) |

`adapter-real-time` reads whole milliseconds. A median of 0 with a dispersion
of 1 is not a measurement of the parser; it is a measurement of the clock, and
every `bytes-per-second` figure in that artifact is a quotient over it. **The
instrument, at that iteration count, cannot resolve a change smaller than
"everything" — so the threshold this record must derive could not have been
derived from it.** That is not a defect in the baseline as a *record* (its
stated job in Milestone 9 Slice ③ was to record, and it does), but it makes it
useless as the denominator of a percentage.

## What the instrument does when it is asked properly

The same runner at five rounds of **two thousand** iterations, on `tarm64osx`,
Chez 10.4.1, 2026-09-17, one quiet machine, unmodified `main`:

| workload                          | median | dispersion | span as % of median |
|-----------------------------------|--------|------------|---------------------|
| `long-method-target-header-spans` | 101 ms |   (99 103) |                4.0% |
| `long-exact-sequence-matching`    |  90 ms |   (90  90) |                0.0% |
| `dense-byte-dispatch`             |  60 ms |   (60  61) |                1.7% |
| `many-small-headers`              |  59 ms |   (58  59) |                1.7% |
| `pipelined-requests`              |  23 ms |   (22  23) |                4.3% |
| `chunked-bodies`                  |  13 ms |   (12  13) |                7.7% |
| `byte-at-a-time-fragmentation`    |   9 ms |   (9   10) |               11.1% |
| `fixed-length-bodies`             |   6 ms |   (5    6) |               16.7% |
| `late-error`                      |   4 ms |   (3    4) |               25.0% |
| `early-error`                     |   0 ms |   (0    1) |            unbounded |

The dispersion is not a property of the parser; it is one millisecond of clock
quantisation, and it is a *larger fraction* of a smaller median. That is the
whole shape of the table, and it is what the threshold has to be derived from.

## Decision

1. **A workload is ADMISSIBLE EVIDENCE only when its median is at least 20 ms.**
   At and above that, every observed dispersion span is at most 4.3% of the
   median; below it, the span reaches 25% and then unbounded. 20 ms is not a
   round number chosen for comfort — it is where this clock stops dominating
   this instrument, on this cell. Raise iterations until a workload clears it;
   do not quote a workload that does not. `early-error` at one input byte
   cannot clear it at any iteration count the runner allows, and is therefore
   evidence about nothing.

2. **"Material improvement" is at least 20% on the median of at least three
   admissible workloads, with no admissible workload regressing.** Twenty
   percent is roughly five times the worst dispersion span observed above
   (4.3%), and three workloads is what makes it not "a single favorable
   microbenchmark" in `§23.3`'s words. The no-regression half is what stops a
   change trading one workload for another and reporting only the winner.

3. **"Significant regression" is 10% on the median of any single admissible
   workload** — about twice the worst observed span, so that a real slowdown is
   distinguishable from noise while a noise excursion is not reported as one.

4. **Both figures are properties of THIS CELL and are re-derived per cell.**
   The numbers above are `tarm64osx`, Chez 10.4.1, one machine, one quiet
   moment. `§23.3`'s third criterion asks for another platform cell, and the
   right reading of this record there is to repeat the dispersion table and
   derive the thresholds again, not to import 20% and 10%.

5. **The committed baseline is re-recorded at an admissible iteration count.**
   A baseline whose medians sit in the clock's quantisation cannot be the
   "before" of any future comparison, and leaving it in place would mean the
   next optimization re-derives all of this.

## Consequences

- A threshold now exists, so `§23.3`'s prerequisite is discharged and later
  optimizations are judged rather than argued. What they are judged against is
  a dispersion table, so the judgement moves if the instrument does.
- The 20 ms floor is the same defect, in a second place, as the one
  `chez-httparse` found in its own throughput lane on the same day: a rate
  computed over an interval the clock cannot resolve is a fabricated number,
  and it fabricates most confidently when the interval is smallest. Both were
  found by reading the medians rather than the rates.
- Nothing here gates CI. `§23.1` says the benchmark records and does not gate,
  and this record does not change that: it defines how a human reading two
  artifacts decides, not a lane that fails.
