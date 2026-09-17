# 0049: A state is a procedure, not a case arm

Date: 2026-09-17
Status: accepted
Milestone: 14, Gate 0
Builds on: [0048](0048-what-material-improvement-means.md) (the thresholds this is judged against)
Amends: [0016](0016-normalized-state-id-allocation.md) (its Context's "the order of the emitted `case` arms" no longer describes a cost)

## Context

`render-machine` emitted one `(case st ...)` re-entered on every state
transition, with one arm per state in state-id order.

**Chez compiles a large `case` over integer keys as a linear scan.** Measured
against 10.4.1 on 2026-09-17: in a 300-arm case the arm at index 5 dispatches
in 1.90 ns and the arm at index 295 in 93.15 ns — about **0.31 ns per arm
skipped**, with the total arm count irrelevant and only the matching arm's
position counting. Identical at optimize-level 0, 2 and 3, so no compiler
setting avoids it.

The consequence is that a machine's per-byte cost depended on **where
[0016](0016-normalized-state-id-allocation.md) happened to number its hot
states**, which is not a property anyone chose and not one a grammar author can
see. `chez-httparse` found it from the outside: its 530-state message machine
scans a request target at 240 ns/byte while its own 75-state url machine scans
the same grammar over the same bytes at 29 — because `url-path` is state 468
in the first and state 15 in the second. Permuting the emitted arms, which
changes no semantics, moved that figure to 42.4 ns/byte.

## What was measured, against 0048's thresholds

Four dispatch designs, same runtime, hot arm at index 468 of 530:

| design                                     | ns/transition |
|--------------------------------------------|--------------:|
| flat `case` (what was emitted)             |        185.85 |
| nested range tests, 8 buckets              |         22.95 |
| nested range tests, 32 buckets             |         11.65 |
| mutually tail-calling procedures           |      **0.80** |

Bucketing plateaus near 11.65 ns and leaves cost position-dependent, just less
so. Direct tail calls remove the dispatch entirely, and Chez compiles a known
tail call between local procedures that never escape as a jump.

`bench/runner/benchmark.sps`, five rounds of two thousand iterations, generated
lane, `tarm64osx`, Chez 10.4.1:

| workload                          | before | after | change |
|-----------------------------------|-------:|------:|-------:|
| `long-method-target-header-spans` | 101 ms | 85 ms |  1.19x |
| `long-exact-sequence-matching`    |  90 ms | 40 ms |  2.25x |
| `dense-byte-dispatch`             |  60 ms | 37 ms |  1.62x |
| `many-small-headers`              |  59 ms | 37 ms |  1.59x |
| `pipelined-requests`              |  23 ms | 10 ms |  2.30x |

Five admissible workloads (median >= 20 ms before), every one improving by at
least 19%, four of them by at least 59%, and **no admissible workload
regressing** — 0048 item 2 is met with two workloads to spare. The inadmissible
workloads all improve too (`chunked-bodies` 13->4 ms, `fixed-length-bodies`
6->2) and are recorded rather than quoted as evidence.

Downstream, on `chez-httparse`'s 530-state machine, where there is more
position to lose: a request target goes 241.9 -> **27.9 ns/byte** (8.7x), a
thirty-header section 236.9 -> **51.4** (4.6x), and against llhttp's own
`bench` mode on its own inputs the ratio falls from **485x to 105x** on a
703-byte request and **365x to 91x** on a chunked `POST`. The benefit scales
with state count, which is the point: it is the position term that is gone.

## Decision

1. **Every state renders as a procedure; a transition to a target known at emit
   time is a direct tail call.** `(loop pos <target> off pk)` becomes
   `(%s<target> pos <target> off pk)`. `st` is still passed, because a keyword
   table reads its resumed path out of it, and a literal target is not a pair,
   so a fresh entry gets the empty path exactly as before.

2. **One dispatch survives, for the three targets that are not known at emit
   time**: the entry into a feed, a callback answering `goto`, and a keyword
   table's jump. It is still a linear `case`, and that is fine — those happen
   once per call, per callback and per keyword, never once per byte.

3. **The emitter's private names carry a `%` prefix, which is unforgeable.**
   `%s<id>` and `%dispatch` are not in `reserved-member-3` and cannot be: a
   machine's state count has no bound. `portable-name?` admits
   `[a-z][a-z0-9-]*` and nothing else, so no output binding and no declared
   name can begin with `%`, and the collision that list exists to prevent is
   impossible by construction rather than by enumeration. The member-3 drift
   guard and the `§16.2:910` witness both assert the prefix rather than
   trusting it, so an emitter local introduced *without* it still fails them.

4. **State ids are not reordered, and 0016 is not reopened.** A hotness
   ordering would buy less, move every IR fingerprint, and leave cost dependent
   on numbering forever. Nothing about id allocation changes here; what changes
   is that ids no longer have a cost attached. 0016's Context says the choice
   is "externally observable through the IR fingerprint and the order of the
   emitted `case` arms" — the fingerprint half still holds, the arm-order half
   no longer describes anything an embedder can feel.

## Consequences

- **The emitted text grows about 12%** (`chez-httparse`'s message machine,
  298 KB -> 335 KB): each transition now names its target twice, and the
  `%dispatch` table adds one line per state. This is `§23.3`'s documented
  complexity cost, and it is paid in a generated artifact that is reviewed as a
  diff, not in hand-written source.
- **All seven committed goldens move, and no fingerprint does.** The machine
  fingerprint is over the IR, and the IR is untouched: `one-byte-parser` still
  renders `14095574568398596535`, `httpreq` still `12865529106868080404`. A
  golden diff with a moving fingerprint would have meant this change reached
  something it should not have.
- **Eleven mutations in the scheme mutation suite were re-anchored, not
  deleted.** Their FIND patterns are literal copies of emitter text and every
  one of them named a transition this record rewrites; the suite's own
  diagnostic asks for exactly that ("update the mutation rather than deleting
  it, or this check silently stops covering that code"). The mutations that
  invert an advance into a reexecute, a reexecute's position kind, a
  zero-width step's consumption and the counted arm's bulk consume all still
  fire, against the new spelling.
- **`§23.3` criterion 3 is not discharged.** Everything above is one platform
  cell. The design is not cell-specific — a direct tail call is not a Chez
  trick — but the *measurement* is, and per 0048 item 4 another cell re-derives
  its own thresholds before it can say so.
- Interpreter equivalence is unaffected by construction: `interpret.sls` is not
  touched, and the differential lanes that compare the two executors are what
  say so rather than this sentence.
