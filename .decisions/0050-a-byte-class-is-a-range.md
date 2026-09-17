# 0050: A byte class is a range, and a linear scan of its members is not

Date: 2026-09-17
Status: accepted
Milestone: 14, Gate 0
Builds on: [0048](0048-what-material-improvement-means.md) (the thresholds this is judged against), [0049](0049-a-state-is-a-procedure-not-a-case-arm.md) (the same defect, one level up)
Amends: [0014](0014-byte-classes-expand-per-byte.md) (what the expansion costs, not that it happens)

## Context

[0049](0049-a-state-is-a-procedure-not-a-case-arm.md) removed the linear scan
from the outer `(case st ...)`. The **inner** `(case b ...)` had it too, and
`render-transition-arm`'s own comment had been anticipating this since
Milestone 3:

> Byte classes lower to one transition per byte, so a complement renders up to
> 256 sibling arms inside the single `(case b ...)` below: membership code is
> kept simple rather than optimized for density. A grouped datum list or a
> membership table is a deliberately deferred optimization, gated behind
> compiled benchmarks.

The gate is now satisfiable: `§23.3`'s thresholds exist (0048) and the
benchmark can resolve them. Measured against Chez 10.4.1 on 2026-09-17, over a
94-byte set — roughly an HTTP token charset:

| dispatch                                      |     ns |
|-----------------------------------------------|-------:|
| flat `case`, hot byte = first arm              |   0.95 |
| flat `case`, hot byte = `e`                    |  21.60 |
| flat `case`, hot byte = last arm               |  29.40 |
| **range tests**                                | **1.25** |
| 256-entry membership bytevector                |   1.75 |
| grouped datum list `((97 98 99 ...) target)`   |  57.40 |

**One of the two candidates that comment named is worse than what it would
have replaced.** A grouped datum list costs 57.40 ns because `memv` over 94
elements loses to the nested-if expansion `case` already gets — it looks like
the obvious compression and it is a 2.7x regression. The membership table is
fine at 1.75 ns but answers only "is `b` in this class", so a state with
several classes needs several tables and a target per table, where a range
carries its target in the clause.

## Decision

1. **A dispatch renders one clause per RUN, not one arm per byte.**
   Transitions arrive sorted ascending by byte (decision 0014), so a maximal
   stretch of consecutive bytes sharing a target and a mode is exactly the
   source byte class that lowering flattened. A run of one renders
   `(fx=? b k)`; a longer run renders `(and (fx>=? b lo) (fx<=? b hi))`.

2. **Clauses stay in ascending byte order.** The runs partition the byte space,
   so no clause can shadow another and the order is free to be the
   deterministic one rather than a chosen one. Ordering by run length would be
   marginally faster for the common byte and would make `§25:1539`'s
   determinism depend on a tie-break nobody can see; it is not done.

3. **`fx` comparisons, not generic.** `b` is `bytevector-u8-ref`'s result and a
   fixnum by construction, `(rnrs)` exports `fx=?`/`fx>=?`/`fx<=?`, and the
   pair measured 1.25 ns against 1.40 ns.

## What it measured

`bench/runner/benchmark.sps`, five rounds of two thousand iterations, generated
lane, against the baseline 0049 recorded:

| workload                          | before | after |  change |
|-----------------------------------|-------:|------:|--------:|
| `long-method-target-header-spans` |  85 ms |  8 ms | **10.62x** |
| `long-exact-sequence-matching`    |  40 ms | 14 ms |   2.86x |
| `many-small-headers`              |  37 ms | 11 ms |   3.36x |
| `dense-byte-dispatch`             |  37 ms | 11 ms |   3.36x |

Four admissible workloads where 0048 item 2 asks for three, every one far past
its 20% floor, and **no workload regressing anywhere** — the eight inadmissible
ones improve too, they are simply not evidence.

Downstream, on `chez-httparse`: a request target scans at **7.2 ns/byte** where
it scanned at 27.5, a url at **3.2** where it was 22.7, a thirty-header section
at **22.8** where it was 50.7. Against llhttp's own `bench` mode its ratio falls
from **104x to 44x** on a 703-byte request and **67x to 21x** on a url.

## Consequences

- **The emitted text SHRINKS, by a lot**: `chez-httparse`'s message parser goes
  334,508 -> 187,808 bytes (-44%) and its url parser 65,806 -> 31,881 (-52%).
  0049 cost 12% of growth for its speed; this pays some of it back. A `case`
  arm per byte was most of what a generated parser was made of.
- **No fingerprint moves.** The IR is untouched, which is the whole claim: this
  is a rendering change. `httpreq` still fingerprints `12865529106868080404`.
- **The `§16.2:911` limits witness was measuring the thing this removed.** It
  sent all 256 bytes to one target, which now renders as ONE clause: its
  emitted source fell from 18,757 bytes to a few hundred and the lane went red
  rather than quietly vacuous, which is the good failure. Rebuilt as the worst
  case of the lowering that exists — 256 bytes alternating between two
  identical destinations so no run can form, which is the arity a backend limit
  would actually have to survive.
- **Three mutations were re-anchored, not deleted**: the two byte-shift
  mutations and the byte-test inversion all name the emitted byte, which is now
  `lo`/`hi` in a clause rather than a `case` datum.
- **The instrument is running out of admissible workloads, and that is the next
  problem.** Eight of twelve now sit under 20 ms, and raising iterations is
  expensive for a reason that has nothing to do with them: the runner uses one
  `inner` for both lanes, and the interpreted lane is ~100x slower and
  unchanged by any of this work. Five rounds of eight thousand already costs
  five minutes, almost all of it interpreted. Measuring the two lanes at
  different iteration counts would fix it; that is not done here.
- `§23.3` criterion 3 remains undischarged: one platform cell, as in 0049.
