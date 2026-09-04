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
- **An over-approximation becomes visible and is NOT fixed here.**
  `pass-reachability` walks `all-out-targets`, so a node reachable only through
  an untakeable EOF edge counts as reached; the old `:908` filter was answering
  the "unreachable nodes" question by accident. That is its own §16.2 question
  and must not be read as closed by this record.
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
