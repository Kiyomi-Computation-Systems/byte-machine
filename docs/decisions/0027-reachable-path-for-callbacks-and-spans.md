# 0027: "Reachable path" is byte-reachability plus the EOF walk; pass-zero-progress gains §16.2:898's gate

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.5)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-05 (Milestone 5 Slice ③)** — **annotates**: item 3's edit shipped
>   and item 1's relation is now consumed by a second pass. Nothing above became
>   false; the note records the measurement item 3 predicted and one thing it did
>   not predict.
> - **2026-09-06 (Milestone 7 Gate 0)** — **amends the Consequences bullet
>   "Handed to nobody: `pass-reachability`"**:
>   [decision 0031](./0031-reachability-is-the-occupiable-relation.md) hands it
>   to Milestone 7's Slice ⓪, which implements the walk over item 1's relation.
>   See the foot of this file.
> - **2026-09-07 (Milestone 7 Slice ⓪)** — **amends the Context's "after the gate
>   it verifies clean"**: Slice ⓪ landed the narrowing, so `unreachable-node` at
>   `Z` now replaces the finding that sentence says nothing replaces. The
>   sentence is marked at its site and the note is at the foot of this file.

## Context

Measured against `src/byte-machine/verify.sls` and
`docs/plans/byte-machine-implementation-plan.md` as read on **2026-09-04**, at the
Milestone 5 Gate 0 branch point. Every line number below was read on that day.

Three normative sentences restrict spans and callbacks along a *reachable path*,
and none of them says which reachability relation that is:

- `§10.4:519` — "Only one span may be active on any reachable execution path in
  v0.1." (This one says *reachable execution path*; the other two say *reachable
  path*. Nothing anywhere defines either.)
- `§13:826` — "An explicit pause node or event/decision callback invocation is
  invalid on any reachable path where a span is active."
- `§14:843` — "The verifier proves that no reachable path starts a second span
  while one is active, ends the wrong span, ends with no active span, or reaches
  successful stop/finish with a span active."

**The parent plan records the gap itself**, at `§Dated:1944-1947`:

> **Left open deliberately, and not to be read as closed:** `pass-reachability`
> walks `all-out-targets`, so a node reachable only through an untakeable EOF edge
> counts as reached. The old :908 filter was answering that question by accident;
> it is its own §16.2 question and now has no accidental answer.

**The tree already holds two relations.** `verify.sls` defines eleven `pass-…`
procedures (`:194`, `:203`, `:259`, `:378`, `:432`, `:493`, `:499`, `:508`,
`:638`, `:799`, `:931`) and exactly **two** of them consult a reachability
relation at all — the only uses of `reach-from`/`byte-reached` in the file are at
`:500`, `:796`, `:852` and `:905`:

- **`pass-reachability`** (`:499-505`) binds `(reach-from m all-out-targets)`
  (`:500`). `all-out-targets` (`:170-173`) is a node's byte out-targets **plus**
  its own eof-target, so the walk may cross an eof-target and then keep taking
  byte edges. It reports `unreachable-node`.
- **`pass-eof-execution`** (`:799`) uses `byte-reached` (`:796`), which is
  `reach-from` over `node-out-targets` only: it gates `§16.2:908`'s per-edge block
  (`:855`) and `§16.2:909`'s start set — the parked set — on it (`:908-911`),
  then classifies each start through `eof-terminal` (`:734`).

The first relation is an over-approximation of what an execution can do, and the
tree says why in its own words at `:823-826`: "once an execution takes an
eof-target it can never feed again (`parser-feed!` prohibits the `finish-ready`
row), so feed-reachable is a subset of `byte-reached`". After an eof-target is
taken, execution follows eof-targets and zero-width continuations only —
`classify`'s dispatch arms hop to the node's eof-target (`:772-773`) and its
zero-width arm joins over `eof-successors` — never a byte edge. A walk that mixes
the two describes no execution.

**And a third check applies no relation at all.** `pass-zero-progress`
(`:508-634`) reports `zero-progress-cycle` over `(machine-nodes m)` with no gate,
though `§16.2:898` reads "reachable zero-progress cycles". Measured by reading
`:508-634` in full: neither `reached` nor `byte-reached` occurs as an identifier
anywhere in the pass. Reachability words do occur in its comments — `reached` and
`reach` at `:530` and `:536`, of a trie position and not of a node, and
`reachable`/`reachability` at `:542` and `:551`. The latter pair is a
**different** notion — whether any byte can take the arm that closes a cycle,
which the comment calls a "KNOWN, DELIBERATE OVER-REJECTION, inherited not
introduced". Node reachability from the entry is named nowhere in the pass, in
code or in comment.

## Decision

**1. The span and callback restrictions use byte-reachability plus the EOF walk**
— the pair the shipped `§16.2:908`/`:909` checks already use — **not
`pass-reachability`'s `all-out-targets`.**

A state is *occupiable* when it is in `byte-reached` (`verify.sls:796`) or is
visited by an `eof-terminal` walk (`:734`) from the parked set (`:908-911`,
gated on `byte-reached` in turn). A *reachable path* for `§10.4:519`,
`§13:826` and `§14:843` is a path through occupiable states: byte edges while
input can still arrive, then eof-targets and zero-width continuations, and never
a byte edge after an eof-target.

**2. The reason is decision 0023's, transferred rather than re-derived.**
[0023](./0023-eof-walk-starts-and-finish-reachability.md) item 3, narrowing
[decision 0011](./0011-eof-execution-model.md) item 4(a): "a graph node no
execution can occupy is not a state that originates a traversal."

Its premise is *occupiability* and its consumer there is a walk's **start set**;
here the consumer is **path membership** — whether a state lies on a path a span
or a callback restriction quantifies over. The premise is unchanged and carries
the whole weight in both: a state no execution can occupy neither starts a path
nor lies on one, and both consumers read the same graph. What does not transfer
is the parked-set *shape* — the entry, the byte-reachable pauses, the
byte-reachable nodes with their own EOF route — which is `§16.2:909`'s
start-set answer and is not a definition of reachability.

0023 recorded the sentence, in its own words, "so a later slice does not
re-derive it wrongly from 4(a)'s words". This is that slice, not re-deriving it.

**3. `pass-zero-progress` gains the `byte-reached` gate `§16.2:898` asks for.**
Slice ③ owns the edit; this record owns the reason.

The gate is `byte-reached` **alone**, not the composite of item 1, because
`§16.2` states the two halves as two separate bullets: `:898` "reachable
zero-progress cycles" and `:908` "EOF-only zero-progress cycles and non-EOF
control flow into a finish terminal". The second half already has an owner —
`eof-terminal`'s `walk` returns `cycle` on `(memq name path)` (`:737`) and
`pass-eof-execution` reports it as `eof-zero-progress-cycle` (`:916-918`). So an
EOF-only zero-progress cycle stays rejected after the gate, by the check whose
bullet it is; gating `pass-zero-progress` on the composite would make the two
checks overlap on exactly the machines `:908` was written for.

**What this changes, and the ground it does not rest on.** The design's §3.2 item
4 calls the gate benign because "such a machine is rejected by `unreachable-node`
regardless". **That ground does not hold, and this record does not use it.**
`pass-reachability` accepts every node its `all-out-targets` walk reaches, and
that walk crosses an eof-target and then keeps taking byte edges — so a machine
can hold a zero-progress cycle that `unreachable-node` accepts and that no
execution can enter. Derived by reading `verify.sls`:

> entry `E`, a byte-dispatch whose case and fallback edges advance into an error
> node and whose eof-target is `T`; `T`, a byte-dispatch reachable only that way,
> whose case edge advances into `Z` and whose eof-target is a finish node; `Z`, a
> byte-dispatch whose fallback edge is a `reexecute` edge back to itself.
>
> `unreachable-node` never fires: `all-out-targets` reaches `Z` as `E` →(eof)
> `T` →(byte) `Z`, and reaches the finish node as `T`'s eof-target. `Z` is not
> occupiable: `byte-reached` is `{E, error node}`, the parked set is `{E}`, and
> the EOF walk from `E` visits `T` and the finish node only, because `classify`
> on a byte-dispatch follows its eof-target and never its byte edges
> (`:772-773`). Today `pass-zero-progress` reports `zero-progress-cycle` at `Z`
> and the machine is rejected; after the gate it verifies clean, and no other
> check replaces that finding.
>
> **2026-09-07 (Milestone 7 Slice ⓪): "after the gate it verifies clean, and no
> other check replaces that finding" is amended — a note at the foot of this file
> reaches back into this paragraph.**

So the gate is a **verdict change on a constructible machine family**, not a pure
consistency fix. It is still the right change — `§16.2:898` says *reachable*, and
a state no execution can occupy cannot hang either runtime loop — but a reader who
takes it for a no-op will not write the fixture it needs. The family is exactly
the over-approximation decision 0023's Consequences left open and forbade reading
as closed; narrowing `pass-reachability` would shrink the family to empty, and
that narrowing is **not** decided here.

Gate 0 runs no code, so the shape above is an argument from reading, not a
measurement of a run. Slice ③ owes it a fixture with an asserted verdict.

## Consequences

- **Two reachability relations now live in one verifier, deliberately**, and the
  record says which check uses which:

  | relation | walk | who uses it |
  | --- | --- | --- |
  | `all-out-targets` — byte edges **and** the node's own eof-target, mixed freely | `verify.sls:170-173` through `reach-from` (`:179`) | `pass-reachability` only (`:500`), for `unreachable-node` |
  | byte-reachability plus the EOF walk — `byte-reached` (`:796`), and `eof-terminal` (`:734`) from the parked set (`:908-911`) | two halves, both already shipped | `§16.2:908` (`:855`), `§16.2:909` (`:908`), Slice ③'s span pass (item 1), and `pass-zero-progress`'s new gate, which takes the `byte-reached` half only (item 3) |

  The second is the narrower and is the one that means "an execution can be
  here". The first is retained unchanged and is the subject of an open question
  this record does not answer.

- **The relation is externally observable**, which is why it is settled before any
  slice writes a fixture: the design's §2 lists it among the four Gate 0 calls
  observable from outside — "§4.5's reachability relation through which diagnostic
  a fixture emits". A span fixture built on the wrong relation pins the wrong
  diagnostic, and the golden then defends it.

- **Handed to Slice ③, so it does not re-derive them.** `§16.3:925`'s pass 7 —
  the dataflow shape [decision 0029](./0029-span-state-is-a-lattice.md) fixes —
  evaluates its span lattice over occupiable states only, by item 1.
  `pass-zero-progress` gains its `byte-reached` gate, by item 3, in the same
  commit as the new kinds that pass must learn — one gate and one kind census,
  not two passes over the same `cond`, on the rule its own comment at `:620-625`
  already states for the walk and the report set. Both edits owe fixtures; item
  3's owes one in particular, because it changes a verdict.

- **Handed to nobody: `pass-reachability`.** Its `all-out-targets` walk is
  unchanged by this record. 0023's Consequences states that question and
  says it "must not be read as closed"; it is still not closed, and item 3's
  verdict change is the first thing that depends on the answer.

  > **Amended 2026-09-06 (Milestone 7 Gate 0)** by
  > [decision 0031](./0031-reachability-is-the-occupiable-relation.md) —
  > `pass-reachability` is decided to walk item 1's relation, and Slice ⓪
  > implements it; see the dated note below. The sentence above is left as
  > decided.

- **This disposes of design §3.2's fourth divergence** — `pass-zero-progress`'s
  missing gate — in the direction §3.2 asked for ("Resolve it with §4.5"), but
  not on §3.2's stated reason. The record above replaces that reason.

## 2026-09-05 (Milestone 5 Slice ③): item 3 discharged, and item 1 got its second consumer

**Item 3 shipped.** `pass-zero-progress` now gates its REPORT set on
`byte-reached` alone, as this record specified and for the reason it gave rather
than design §3.2's. The relaxation has an observable direction and the fixture
asserts BOTH halves, the second being the one that matters: a machine holding an
unreachable zero-progress cycle is now accepted, and `unreachable-node` does NOT
catch it — which is exactly the ground §3.2 item 4 offered for calling the gate
benign, and which this record recorded as false. Two shipped fixtures moved with
it, and one now asserts the opposite of what it did: an EOF-only pause cycle is
`eof-zero-progress-cycle` and not `zero-progress-cycle`, which is the non-overlap
the `byte-reached`-alone gate exists to get.

**Item 1 now has a second consumer**, which is what makes it a relation rather
than a local choice: pass 7's dataflow runs over it. Its edge relation is byte
out-edges plus EOF routes and its `parked?` predicate is byte-reachability plus
the parked set — the pair this record named, taken from here rather than minted.

**One thing this record did not predict, and it cost a defect.** Item 1 settles
which nodes are OCCUPIABLE. It says nothing about which nodes are PARKABLE, and
those are different questions with different consumers: `§16.2:909`'s walk starts
from a parked set, and Slice ③ made a span end parkable — a span-data callback's
pause parks the parser on that node's completion substep — without adding it to
that set. Measured before the fix: a machine whose span end continued into a stop
verified clean and answered `stopped` from `parser-finish!`. The record's own
warning about the parked-set SHAPE ("what does not transfer is the parked-set
shape … and is not a definition of reachability") is the sentence that was
right; what was missing is that the shape has to be re-derived for every kind
that can pause, and nothing in the tree derives it from anything.

## 2026-09-06 (Milestone 7 Gate 0) — `pass-reachability` is handed to Slice ⓪, and item 1's relation gets its third consumer

[Decision 0031](./0031-reachability-is-the-occupiable-relation.md) decides that
`pass-reachability` reads item 1's relation — `byte-reached` plus the EOF walk from
the parked set — computed once and shared with pass 7, and that `all-out-targets`
retires. Milestone 7's Slice ⓪ implements it. This note is written at a Gate 0
commit, where `verify.sls` still walks `all-out-targets`: the walk is *decided*, not
yet shipped, and the "Handed to nobody" bullet above is false from 0031 onward
because the hand-off now has a receiver.

The sentence transferred is the one beneath the Consequences' relations table: the
second relation "is the one that means 'an execution can be here'". 0031 takes it as
the meaning of "unreachable" in `§16.2:897`, on the ground item 2 already transferred
from decision 0023 item 3 — a graph node no execution can occupy is not a state that
originates a traversal.

Item 3's verdict change — the `§16.2:898` gate — was recorded above as "the first
thing that depends on the answer". The answer is now given, and 0031's Context
records what it does to that gate's fixture: nothing. The fixture collapses this
record's Context machine into two nodes — `t` plays both `T` and `Z`, its case edge a
`reexecute` self-loop, its eof-target an error node — and `t` is occupiable through
the EOF route, so "and `unreachable-node` does NOT catch it" stays true under the
narrowed walk. This record's machine **as written** — `Z` a third node, distinct from
`T` — is the family the narrowing rejects: measured by the Milestone 7 design's
prototype as three cases in `verify-tests.sps`, one of them this shape with a span
end as `Z` behind `t`'s byte edge (the 0029 item 3 span case). So the Context's
"after the gate it verifies clean, and no other check replaces that finding" stops
being true when Slice ⓪ lands — `unreachable-node` at `Z` replaces it, which is what
"narrowing `pass-reachability` would shrink the family to empty" foresaw; Slice ⓪'s
documentation commit marks that sentence at its site.

**What does not move.** Item 1 — the relation, and its two consumers, now three;
item 3 — `pass-zero-progress`'s gate stays `byte-reached` alone, for the reason item
3 gives; the relations table's second row. The table's first row describes
`all-out-targets` as retained, which is true of the tree at this note's commit and
stops being true when Slice ⓪ lands; it is a record of the tree on 2026-09-04 and is
left as decided.

## 2026-09-07 (Milestone 7 Slice ⓪) — the narrowing landed, and `unreachable-node` at `Z` is the check that replaces the finding

Slice ⓪ (`46da756`, PR #89) narrowed `pass-reachability` to decision 0031's
occupiable relation. The Context's machine **as written** — `Z` a third node,
distinct from `T` — is now rejected with `unreachable-node` at `Z`, so its
sentence "after the gate it verifies clean, and no other check replaces that
finding" is false from that commit. This is what the paragraph below it foresaw
("narrowing `pass-reachability` would shrink the family to empty"), and what the
2026-09-06 note above predicted Slice ⓪ would mark.

**Where it is asserted.** In `verify-tests.sps`: the group "reachability is the
occupiable relation (decision 0031)" builds this exact machine for each of the
three kinds `T` may be — byte-dispatch, sequence-dispatch, integer-accumulate —
and asserts `((unreachable-node . z))` and, for the same machine with `Z` also
byte-reachable from the entry, `()`. The shipped case "a node no execution can
occupy contributes no state (0029 item 3)" is this record's machine with a span
end as `Z`, and it was re-baselined in the same commit to `cl` and the three
nodes behind it.

**What stays true.** Item 3's gate is unchanged and `unreachable-node` still does
NOT catch the `§16.2:898` fixture, for the reason 0031's Context gives and this
file's 2026-09-06 note records: that fixture collapses `T` and `Z` into one node,
which is occupiable through the EOF route. The relations table's first row, which
describes `all-out-targets` as retained, is a record of the tree on 2026-09-04 and
is left as decided; the procedure it names no longer exists.
