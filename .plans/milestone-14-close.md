# Milestone 14 — the emitted dispatches stop being linear scans

Status: **closed 2026-09-18, ships v0.6.0**
Opened: 2026-09-17, outside the `§25` sequence
Gate 0: [0048](../.decisions/0048-what-material-improvement-means.md)
Slices: [0049](../.decisions/0049-a-state-is-a-procedure-not-a-case-arm.md),
[0050](../.decisions/0050-a-byte-class-is-a-range.md),
[0051](../.decisions/0051-a-goto-target-comes-from-a-known-set.md),
[0052](../.decisions/0052-a-callback-outcome-is-the-object.md),
[0053](../.decisions/0053-the-feed-entry-is-a-search.md)

## This is a close, not a design, and it is written after the fact

Milestones 10, 11 and 13 were each opened outside `§25` from a `chez-httparse`
brief, and each got a `milestone-N-design.md` before its slices. **This one did
not.** It began as a question from the consumer — *are there other
opportunities to improve performance?* — and every slice was chosen from the
measurement the previous slice produced. There was no point at which a design
could have named the five changes, because the third and fourth were invisible
until the first two removed what was hiding them.

So this file is the record that would have been the design's status header, and
it says what happened rather than what was planned. Writing a design document
now, dated today, describing work that did not follow it, would be the
retrofit `§4.12`'s derived-census rule exists to prevent one level up: an
artefact that looks like a cause and is an effect.

What stood in for a design is `§23.3`'s own precondition, which is why 0048 is
the Gate 0 record: **no optimization could be admitted until a threshold had
been derived from observed baseline variance**, and none had been. Deriving it
came first, it invalidated the committed baseline in the process, and every
slice after it was judged rather than argued.

## What shipped

One defect, at four depths, plus the allocation it hid.

| slice | what was linear | after |
|-------|-----------------|-------|
| 0049 | the state `case`, re-entered per transition | one procedure per state, direct tail calls — 0.80ns against 185.85ns |
| 0050 | the byte `case`, one arm per byte of a class | one clause per run of consecutive bytes — 1.25ns against 21.60ns |
| 0051 | the callback `goto`, through `%dispatch` | the literals the arm already wrote, continue first |
| 0053 | the feed entry, the last one standing | a balanced binary search, ceil(log2 N) comparisons |

and 0052, which is not a dispatch: the callback seam answered a freshly consed
`(goto TARGET)` where it could answer the target, which was **128 bytes of
garbage per HTTP header** that the allocation audit could not see because its
slope holds the header count fixed.

**Three of the five were dismissed in writing before they were measured**, each
by the record that fixed the previous one. 0049 named the three dispatches it
left and said a linear case there "costs nothing the per-byte path can see";
0050 closed a Milestone 3 comment proposing a candidate that measured 2.7×
*worse* than the status quo; 0051 said the feed entry "genuinely cannot be a
literal", which is true and was never the whole question. None was wrong about
the mechanism. Every one was wrong about the size, and none had a number. That
pattern is now in `AGENTS.md` as *a fix that names what it is not fixing has
named the next defect*.

## Evidence

Nine rounds of sixteen thousand iterations, `tarm64osx`, Chez 10.4.1, the
committed runner on both trees, generated lane:

| workload | at v0.5.0 | at v0.6.0 |
|----------|----------:|----------:|
| `long-exact-sequence-matching` | 118 ms | 60 ms |
| `many-small-headers` | 90 ms | 51 ms |
| `dense-byte-dispatch` | 90 ms | 51 ms |
| `long-method-target-header-spans` | 69 ms | 67 ms |
| `byte-at-a-time-fragmentation` | 39 ms | 32 ms |

Per-header allocation in the generated lane goes **128 B → 0**, and per-message
allocation stops depending on the message's shape: five workloads of different
lengths, header counts and message counts converge on one figure.

Downstream, `chez-httparse` parses a 308-byte request at **175,342 msg/s where
it parsed at 14,925** before this milestone opened — twelve times — with its
live llhttp differential reporting `agreed=9557 late-complete=4
early-complete=0 unclassified=0` at every pin, unchanged. Against llhttp on
llhttp's own bench inputs its ratios fall from **485×/365×/89× to
25.5×/29.3×/19.9×**.

## What is admitted, and the one thing that is not

0049, 0050, 0051 and 0052 each clear 0048 rule 2 — 20% on three or more
admissible workloads, none regressing past the significance bar.

**0053 does not, and ships saying so.** It is 22% on one admissible workload
and flat on four, where the rule asks for three. The reason is the instrument:
`http-machine.sls` is 217 states with no keyword table, so every whole-buffer
workload crosses the feed entry exactly once per message and there is nothing
there to remove. Adding byte-at-a-time variants of other inputs would have
reached three and would have been fitting the instrument to the result; they
were not added. The release ledger's `§26:1679` claim carries the shortfall,
and the consumer's 530-state machine — where the same change is worth 4.5% on
the whole-buffer path and 77% byte-at-a-time — is the evidence offered instead.

This is the first milestone in which the project's own admission rule was not
met by something that shipped. It is recorded as an exception rather than
resolved by widening the rule, because a threshold edited in the week it
becomes inconvenient is not a threshold.

## The ABI

**8 → 9** (0052): the callback seam changed what it *answers*, from a list
tagged with the outcome's name to the outcome object, so an ABI-8 generated
parser meeting an ABI-9 runtime would decode every callback wrong. It is
refused at construction instead. `byte-machine-callback-step/v1` and
`byte-machine-span-fragment-step/v1` are retired to tombstones on
`byte-machine-make-compiled-machine/v1`'s precedent — a stale generated file
has to EXPAND before its own ABI check can run, and an unbound identifier at
expansion is not the clean refusal.

This is the fourth ABI bump (3→4 at M5, 5→6 at M11, 7→8 at M13) and the second
that is breaking for a generated artefact rather than additive. Consumers
regenerate; `chez-httparse` did so in its own PR, and its two ABI expectations
— both of which READ the number out of the emitted text rather than remembering
it — were the whole cost of the bump downstream.

## Census, unchanged

The `§26`/`§27` exit criteria are **13 met / 2 amended / 0 open**, the two
amended still the CI-blocked Tier-1 pair and the budget still zero. This
milestone adds no criterion row: it ships no new node kind, no new diagnostic,
and no new public graph API. The diagnostic census closes at **33 codes / 60
sites** and the mutation lane at **76 passes / 637 mutations**, both identical
to v0.5.0 — twenty-three mutations were *re-anchored* across the five slices
and not one was added or dropped, which is the suite's own rule ("update the
mutation rather than deleting it") holding through the largest `src/` churn
since M11.

`§4.7`'s gate did not apply: every slice ships `src/` mechanism.

## Known-open, receivers unchanged

`§12.7:770`'s zero-width-machine-action half, `§9.3:392-393`, and `§25:1590`'s
remainder. `§23.3` criterion 3 (a second platform cell) stays undischarged for
all five decisions: one cell, one machine, and 0048 says its thresholds are
re-derived per cell rather than imported.

One item this milestone opened and did not close: **the benchmark's machine is
less than half the size of the largest machine the ecosystem generates**, and
several of these costs are proportional to state count. That is why 0053 could
only be seen in one cell. `§23.2` fixes the workloads and a baseline whose
inputs move is not a baseline, so the workloads were not changed — but a flat
row in that table now means "this instrument cannot see it here" as often as it
means "there is nothing there", and 0053 records which.
