# 0023: EOF walks start from the parked set; §16.2:908 is a byte-reachability rule

Date: 2026-09-03
Status: accepted
Milestone: 5, Slice ⓪b (milestone-5-slice-0b-implementation-plan.md)

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
