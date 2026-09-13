# 0023: EOF walks start from the parked set; §16.2:908 is a byte-reachability rule

Date: 2026-09-03
Status: accepted
Milestone: 5, Slice ⓪b (milestone-5-slice-0b-implementation-plan.md)

> **Amendments** — a later note at the foot of this file reaches back into the
> text above it. Nothing above a note is rewritten: the tree each decision was
> taken against is its evidence.
>
> - **2026-09-04 (Milestone 5)** — **annotates items 1 and 3**:
>   [decision 0027](./0027-reachable-path-for-callbacks-and-spans.md) carries the
>   reachability answer those items fixed for the EOF checks to the span and
>   callback restrictions and to `pass-zero-progress`. Nothing above it became
>   false. See the note below.
> - **2026-09-06 (Milestone 6)** — **amends item 3**: its closing clause, "with
>   each node classified as itself", has two exceptions. `parked-eof-start` has
>   started a byte-reachable callback's walk at its pause continuation since
>   Milestone 5 Slice ② (unrecorded here until now), and
>   [decision 0030](./0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
>   starts a parked counted consume's walk at its eof-target — in both cases
>   because the state a parser is parked on and the name its walk starts at are
>   different questions. The set itself is unchanged. See the foot of this file.
> - **2026-09-06 (Milestone 7 Gate 0)** — **amends the second Consequences bullet
>   and annotates the third**:
>   [decision 0031](./0031-reachability-is-the-occupiable-relation.md) narrows
>   `pass-reachability` to the relation items 1 and 3 use, which the third bullet
>   left open; "verifies clean" in the second bullet is no longer what its three
>   families do. Milestone 7's Slice ⓪ implements it. See the foot of this file.

## Context

Decided against the tree at `bafdbe1` (Milestone 4 close) plus Slice ⓪'s tasks 1
and 6. Four questions Slice ⓪ recorded as open turned out to be one: **which
nodes start an EOF walk, under what gate, how many findings does one decision
emit, and how many of the six EOF verdicts are real?** Fixing any one alone
creates the next — the naive fix for the first is what produces the third.

Three measurements decided it, each reproduced from the tree rather than argued:

**1. §16.2:908 was implemented two ways that contradict each other.** The check
lived at three sites under two gating rules — one unconditional and filtered on
source kind, two gated on byte-reachability. So a node reachable *only* as an
eof-target was accepted when it was a pause, a field-action or a field-branch,
and rejected when it was a byte-dispatch, a sequence-dispatch or an
integer-accumulate. The byte edge is untakeable in all six.

**2. The §16.2:909 walk never started at `machine-entry`.** `eof-terminal` was
called from exactly two sites and the entry was neither, although
`parser-finish!` on a fresh or reset parser starts precisely there. `entry = a
stop node` verified with **zero diagnostics** and returned `stopped`; the
identical property one hop away was correctly rejected.

**3. Six of the fifteen EOF-verdict pairs are undecidable by any machine**, all
six inside `{finish, unresolved, error, default-error}` — and four of them are
*acceptance holes*: with `default-error` ranked above `cycle`, a field-branch
machine verifies clean and `parser-finish!` never returns.

## Decision

**1. §16.2:908 is a rule about byte-reachability, not about source kind.** One
derived block, keyed on membership in `byte-reached`, reporting once per
offending byte edge **at its source node**. The gate is sound rather than
convenient: once an execution takes an eof-target it can never feed again
(`parser-feed!` prohibits the `finish-ready` row), so feed-reachable ⊆
`byte-reached` and gating on it cannot miss a real violation.

*Evidence, both directions.* Applying the unconditional reading uniformly breaks
five shipped programs, and the machine it refuses is `make-pause-machine` — an
EOF-only pause continuing into a finish node, **decision 0011's canonical legal
shape**, named in that fixture's own header. Applying the gated reading uniformly
leaves every byte-reachable offender of all six kinds still rejected.

**2. The entry is a §16.2:908 subject.** Decision 0011 item 4(b) and §10.6:616
both state the rule over *reaching*, and the entry is reached by `parser-feed!`.
Reuses `non-eof-into-finish` with **no new code**. Multiplicity 1 by
construction.

**3. The §16.2:909 start set is the set of states an execution can be PARKED
on** — the entry, every byte-reachable pause, and every byte-reachable node
carrying its own EOF route — with each node classified as *itself*. Because it is
a **set**, the entry appears exactly once, so a machine whose entry is also a
dispatch with an eof-target reports one finding, not two.

> **Amended 2026-09-06 (Milestone 6)** by
> [decision 0030](./0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
> — "classified as itself" has two exceptions; see the dated note below. The
> sentence above is left as decided.

This **narrows** decision 0011 item 4(a)'s literal "an eof traversal reachable
from *any state*": a graph node no execution can occupy is not a state that
originates a traversal. Stated here so a later slice does not re-derive it
wrongly from 4(a)'s words.

**4. The `:908` decision unit is the EDGE; the EOF-verdict unit is the NODE.**
The parked-set shape makes the second true *by construction* — one start per
node, one `case`, one diagnostic — so no de-duplication pass exists to get wrong.
§16.4:940's edge/source label is implemented, carrying a **role** (`case`,
`fallback`, `alternative`, `mismatch`, `digit`, `nondigit`, `overflow`, `next`,
`error`, `true`, `false`, `continuation`), never an index: `verify.sls` declines
elsewhere to promise the order of two diagnostics from one node, and an index
would newly promise it.

**5. The EOF verdict order is three tiers**, not a flat six: benign
(`finish unresolved error default-error`) < `eof-reachable-stop` < `cycle`. All
six symbols are kept — M5's span check needs `finish` distinguished from `error`
at `classify`, and 0021 item 3's loud-else discipline forbids merging arms — but
the *order* within the benign tier is not a decision, because nothing can
witness it. An empty zero-width join, `unresolved`'s only producer, is now a
loud raise.

## Consequences

- `pass-eof-execution`'s `:908` half names **one** kind predicate where it named
  six, and `node-out-edges` is the single census it consults. That is the direct
  antidote to the failure mode Milestone 4 Slice ③ shipped three times: a node
  kind taught to the shared accessors and not to the hand-written filters that
  read them.
- **Three machine families become legal** — an EOF-only-reachable dispatch,
  sequence or accumulate node with a byte edge into a finish. They carry
  accept-side fixtures, because "verifies clean" is what the defect looked like.

  > **Amended 2026-09-06 (Milestone 7 Gate 0)** by
  > [decision 0031](./0031-reachability-is-the-occupiable-relation.md) — the
  > three families stay legal under `§16.2:908`, and "verifies clean" is no
  > longer what they do; see the dated note at the foot of this file. The
  > sentence above is left as decided.

- **An over-approximation becomes visible and is NOT fixed here.**
  `pass-reachability` walks `all-out-targets`, so a node reachable only through
  an untakeable EOF edge counts as reached; the old `:908` filter was answering
  the "unreachable nodes" question by accident. That is its own §16.2 question
  and must not be read as closed by this record.

  > **Annotated 2026-09-06 (Milestone 7 Gate 0)** by
  > [decision 0031](./0031-reachability-is-the-occupiable-relation.md) — the
  > question this bullet leaves open is answered there, and Milestone 7's Slice
  > ⓪ implements the answer; see the dated note at the foot of this file. The
  > sentence above was true when written and is left as decided.

- Decision **0021 is annotated, not corrected** — two of its sentences were never
  true, which `AGENTS.md` sends to annotation. Decision **0011 needs no
  amendment**; item 4(b) already states the rule this record implements.

## 2026-09-04 (Milestone 5) — the same answer, carried to spans, callbacks and zero-progress

Milestone 5 Gate 0 (decision 0027, `milestone-5-design.md` §4.5) takes the pair of
relations items 1 and 3 fixed for the EOF checks — `byte-reached` for §16.2:908,
and the EOF walk from the byte-reachable parked set for §16.2:909 — and makes them
the meaning of "reachable path" in §10.4:519, §13:826 and §14:843, three normative
sentences that each name a reachable path and define none. Item 3's sentence, "a
graph node no execution can occupy is not a state that originates a traversal", is
0027's stated reason, transferred rather than re-derived. 0027 also gives
`pass-zero-progress` the `byte-reached` gate §16.2:898's "reachable zero-progress
cycles" asks for; Slice ③ owns that edit.

**What this note does not reach.** The third Consequences bullet's open question
stays open. `pass-reachability` still walks `all-out-targets`, 0027 does not
narrow it, and 0027 is explicit that it "must not be read as closed" remains the
standing instruction.

**One thing 0027 measured that this record did not, recorded here because a reader
arriving at the third Consequences bullet should know it.** Because
`all-out-targets` is wider than the relation items 1 and 3 use, the two do not
agree on every machine: a byte-dispatch node reachable only as `E` →(eof) `T`
→(byte) `Z` is in `pass-reachability`'s reached set and in no execution's state
set. Nothing above this note is wrong about that — this record raised the
over-approximation and declined to fix it — but 0027 is where the first check
whose verdict depends on the difference is named.

## 2026-09-06 (Milestone 6) — item 3's "classified as itself" has two exceptions, and the first went unrecorded

Item 3 ends "with each node classified as *itself*". Measured on 2026-09-06 against
`d793b73`, `parked-eof-start` in `verify.sls` has not done that for every kind since
Milestone 5 Slice ② (`0578bdf`): for a byte-reachable callback node that is not the
entry it answers `(callback-node-pause-continuation n)`, one edge, and its own
comment gives the reason — "a state an execution can be parked on" and "the name
the EOF walk starts at" "are two different questions, and the callback node is the
first kind where they come apart". That deviation was correct and carried no note
here; this note is the first to record it.

[Decision 0030](./0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
item 6 adds the second exception: a parked counted consume starts its walk at its
eof-target, because a parser parked on a non-entry counted consume by `need-input`
holds a positive count and takes its EOF route, never its zero-count successor. The
machine that protects is the one-shot "length, body, stop" grammar — `… →(byte)
body (eof: an error; next: a stop)` — which a walk from the parked node joining
over `next` would reject with `eof-reachable-stop` for a stop no EOF path reaches.

**What does not move.** The set's definition — "the set of states an execution can
be PARKED on" — stands and admits the new kind. Its enumeration stands: the shipped
proxy for "carrying its own EOF route", `(symbol? (node-eof-target n))` at both
sites, is left exactly as it is, because a `#f` route is benign for a parked
counted consume for the same reason it is benign for a parked dispatch. What 0030
corrects is where a walk *starts* for one more kind; what a walk does when it
*arrives* at that kind is its item 5's join, which is `classify`'s business and not
this item's.

## 2026-09-06 (Milestone 7 Gate 0) — the over-approximation is closed by decision 0031, and "verifies clean" stops being true for three kinds

[Decision 0031](./0031-reachability-is-the-occupiable-relation.md) decides that
`pass-reachability` reads the relation items 1 and 3 fixed for the EOF checks —
`byte-reached` plus the EOF walk from the parked set — and that `all-out-targets`
retires. Milestone 7's Slice ⓪ implements it. This note is written at a Gate 0
commit, where `verify.sls` still walks `all-out-targets`, so the third Consequences
bullet describes the tree as it stands today and stops describing it once Slice ⓪
lands.

**The family whose verdict changes, exactly** (0031 item 2): `E →(eof) T →(byte) Z`,
with `T` reachable only through an EOF route and one of byte-dispatch,
sequence-dispatch or integer-accumulate — the kinds whose byte edges are dead at
EOF — and `Z` distinct from `T`, reachable over `all-out-targets` only through a dead
byte edge of `T`, transitively. `Z` gains `unreachable-node`. Not in it: `Z = T` (a
self-loop; `T` is occupiable through the EOF route), `T` a counted consume (`next` is
an EOF successor, decision 0030 item 5), `T` a zero-width kind (the walk flows
through it), and any `Z` reachable by another route.

**Why the second bullet is false for exactly its three kinds.** The bullet names
dispatch, sequence and accumulate nodes, and those are the three kinds of the
family. Their byte edge into a finish is still not a `§16.2:908` violation, so the
families stay legal under that rule; but the finish behind that dead edge is a `Z`,
and under 0031 it is `unreachable-node` unless it has another route. "Verifies
clean" was what the defect looked like and is not what the fix produces: the
accept-side fixture keeps its `:908` half and gains a `:897` finding. The fixture
that carries it — `verify-tests.sps`'s "an EOF-only-reachable byte edge into a
finish is accepted", driven over the eight kinds of `t2-kinds` — keeps its finish
occupiable for the other five kinds (pause, field-action, field-branch, callback,
counted consume), because the EOF walk flows through their zero-width successors,
and through a counted consume's `next`; those five are the fixture's, not this
record's, and nothing about them moves. Measured by the Milestone 7 design's
prototype: `expected (), got ((integer-accumulate unreachable-node)
(sequence-dispatch unreachable-node) (byte-dispatch unreachable-node))`.

**Item 3's sentence is 0031's ground, transferred to its third consumer.** "A graph
node no execution can occupy is not a state that originates a traversal" was stated
here for the `§16.2:909` start set, transferred by decision 0027 to path membership
for the span and callback rules, and is transferred once more by 0031 to the meaning
of "unreachable" in `§16.2:897`. Item 3 itself does not move.
