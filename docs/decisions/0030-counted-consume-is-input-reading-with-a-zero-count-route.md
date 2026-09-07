# 0030: Counted consume is input-reading with a zero-count route — the executor contract, and the verifier's two answers

Date: 2026-09-06
Status: accepted
Milestone: 6, Gate 0 (milestone-6-design.md §4.1, §4.2)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-06 (Milestone 7 Gate 0)** — **annotates the Context's `§12.7:772`
>   citation**: that line of the parent plan is blank, and the sentence it cites —
>   "Integer-overflow nodes reject and do not consume the overflowing digit" — is
>   `§12.7:773`. `reexec-targets`' comment in `verify.sls` carries the same
>   citation, and Milestone 7's Slice ⓪ corrects it there
>   ([decision 0031](./0031-reachability-is-the-occupiable-relation.md), Context).
>   Nothing above became false; this bullet is the whole note.

## Context

Decided against `main` at `d793b73` (the Milestone 6 design and the Slice ⓪ plan
merged; `src/` and `test/` byte-identical to `b470665`, Milestone 5's close).
Every construct named below was read on 2026-09-06 and is cited by name; the
design's §3.1 measured the line numbers and this record deliberately does not
repeat them.

**One fact, and everything here descends from it.** `§11.4:652` lists counted
consumption among the input-dependent kinds — "Byte dispatch, sequence-prefix
states, integer accumulation, and counted consumption are input-dependent" — and
`§10.6:600` gives the same kind a transition that consumes nothing: "A zero count
transitions immediately without consuming input." No other kind in `§10.6`'s
closed set has both properties. Every per-kind analysis in `verify.sls` partitions
kinds into exactly these two families and gives each a different answer:
input-reading kinds carry their own EOF route and their byte edges make progress;
zero-width kinds are reached without input and have no EOF route. The new kind
needs an answer from both families at four sites, and at a fifth the two answers
must be kept apart.

**The parent plan states five sentences of semantics and no order among them.**
`§10.6:598-604` is a lead sentence and five bullets: bulk consumption with exact
subtraction (`:598`, `§15:872`); the zero count (`:600`); input ending first, with
`need-input` (`:601`); the count reaching zero first, continuing at the target
(`:602`); the exact case, in which "count completion wins: the field reaches zero
and execution continues through zero-width/span/message-complete work in the same
feed before any `need-input` result" (`:603`); and the span rule (`:604`). Every
shipped input-reading arm in both lanes opens with the exhausted-input test —
`parser-feed-op!`'s `accumulate` and `dispatch` arms with `(if (>= pos end)
(make-parser-result 'need-input …))`, and `compile.sls`'s
`render-exhausted-preamble` with `(if (>= pos end) (if finish? …` — so an
implementer arriving with that shape in hand would test exhaustion first, and
`:600` says a zero count transitions *immediately*.

**The verifier's constructs, measured.**

- The `§16.2:909` parked set is written twice by hand — in `pass-eof-execution`
  and as pass 7's `parked?` — and both admit an input-reading node through the
  clause `(symbol? (node-eof-target n))`: `rg -c "symbol\? \(node-eof-target n\)"
  src/byte-machine/verify.sls` prints **2**. `parked?` has four disjuncts: the
  entry, `pause-node?`, `callback-node?`, and that clause.
- `eof-successors` is a one-line alias, `(define (eof-successors n)
  (zero-width-successors n))`, read by `classify`'s zero-width arm and by pass 7's
  `eof-step`.
- `parked-eof-start` answers `(callback-node-pause-continuation n)` for a
  non-entry callback and `(node-name n)` for every other kind, and its own comment
  says why: "a state an execution can be parked on" and "the name the EOF walk
  starts at" are two different questions.
- `reexec-targets`' integer-accumulate arm lists the overflow edge
  unconditionally, because `§12.7:772` "makes it NON-CONSUMING"; that arm is the
  shape of a route that can be taken without consuming input.
- In `runtime.sls`, the only return that leaves `current` on an input-reading node
  is the `need-input` result, and both shipped input-reading arms produce it only
  at `(>= pos end)`; every byte step goes through `route-byte-step!`, which moves
  `current` to the target first.

## Decision

Two groups, numbered continuously: items 1–4 are the executor contract (design
§4.1), items 5–7 the verifier rule (design §4.2).

**1. The zero-count test precedes the exhausted-input test, in both lanes, during
feed and during finish.** For field value `v`, cursor `pos` and slice end `end`:

| | Feed | Finish | Position kind carried to the target |
| --- | --- | --- | --- |
| `v = 0` | transition to `next`; nothing consumed | transition to `next` | carried through unchanged |
| `v > 0`, `pos ≥ end` | return `need-input` at `pos`; `current` stays on the node | take the EOF route: a named eof-target hops with `eof`; `#f` is the default EOF error at this node, `eof` at the final offset (`§12.7:771`) | — |
| `v > 0`, `pos < end`, `n = min(v, end − pos)` | field `:= v − n`; cursor and offset `+= n`; if `n = v`, continue at `next` with the remaining input; else return `need-input` at `pos + n` | unreachable — finish supplies no input | `boundary` |

The order is derived, not chosen: `§10.6:600` says "immediately", and `§11.1:638`
lets an empty feed "advance already-pending zero-width continuations" — a counted
consume with nothing left to consume is such a continuation. The same order holds
at `parser-finish!`: a counted consume reached with a zero count — the entry of a
fresh parser whose field initial is zero, a pause or callback continuation, a node
on an EOF chain — takes `next`, and only a positive count is a truncation.

What the other order does, so a reader can recognise it: a zero count at the end
of a slice returns `need-input` and parks on the node instead of transitioning,
and a zero count at `parser-finish!` is reported as a truncation. Neither is
visible in the differential result tuple for a zero-length body — both orders
return `need-input` with the same `next`, `consumed` and offset — so the fixtures
that see it are `parser-state-name` after the feed, the finish result after it,
and the span variant's completion placement (item 2).

**2. Count completion wins by construction, not by a special case.** Row 3's
`n = v` test continues at `next` whether or not `pos + n = end`; `§10.6:603`'s
exact case is the ordinary completion case with no input left, and the executor
loop then runs the successor's zero-width work — a span end's fragment and
completion among it — before any input-dependent node can return `need-input`.
The wrong reading is **symmetric**: two lanes that both test `pos + n ≥ end`
before `n = v` return `need-input` first, transition on the next feed, and agree
with each other on every schedule while disagreeing with the plan. That is why
the design's Slice ② asserts *which feed* the completion event lands in as a
value derived from the schedule, never as lane agreement.

**3. Position kind.** After `n ≥ 1` committed bytes the kind is `boundary`
(`§12.7:769`, an error edge after an advance). After a zero-count transition the
loop's kind is carried through unchanged — the shipped zero-width convention,
which `runtime.sls`'s field-action arm and `compile.sls`'s `zero-width-jump` both
record, and which `§12.7`'s table does not reach: it has no row for an error node
reached through a *non-failing* zero-width route. The parent plan's `§12.7:770`
disposition disputes that convention only for zero-width machine-action
**failures**, and a counted consume has no failure of its own — it invokes no
callback and takes no error edge — so neither `§12.7:770` nor its deferral
reaches this kind. The observable, so a fixture can pin it: an error node reached
through a zero-count counted consume entered over a reexecute edge reports
`byte` at the current offset, exactly as an error node reached through a field
branch does today; through a counted consume that committed anything,
`boundary`.

**4. The interpreter's message is `count-step`**, answering `(committed .
target)` — the bytes to advance, and the successor when the count reached zero
or `#f` when input ran out first — and committing the subtraction into the field
vector, on `interpret.sls`'s own rule for its field messages: "The op RECEIVES
the parser's field vector and COMMITS into it; the runtime only routes the target
it answers." The finish path asks the same message over an empty slice and reads
only the target: `(0 . next)` is the zero-count transition, `(0 . #f)` means take
the EOF route, for which the existing `eof-target` message gains an arm. A
separate `count-zero?` message was rejected because the answer shape already
carries the distinction, and one message per shape is `accumulate-step`'s
precedent.

**5. `next` is an EOF successor of the node, unconditionally, at every node the
EOF walk ARRIVES at.** `eof-successors` answers `(list next)` for the kind, and
`classify`'s arm is the join of the input-reading answer and the zero-width
answer, written over that helper: `(eof-verdict-join (dispatch-arm (node-eof-target
n) path) (join-over (eof-successors n) path))`. So `classify` and pass 7's
`eof-step` read one fact from one helper and cannot disagree — `zero-width-edges`'
own rule, "one fact, three consumers", applied a kind later. A stop behind the
zero-count route is `eof-reachable-stop`; a cycle through `next` is
`eof-zero-progress-cycle`; the `#f` route's half is `default-error`, tier 0.

This is the arm that closes the real hole. A counted consume reached during
`parser-finish!` with a zero count transitions to `next`, and `next` can be a
stop — `§16.2:909`'s exact prohibition. A `classify` arm written on the dispatch
pattern (hop to the eof-target; `#f` is benign) never sees `next`, so a machine
whose entry is a counted consume with field initial `0`, a `#f` eof-target and a
stop for `next` verifies clean and `parser-finish!` on a fresh parser answers
`stopped`; the same shape through a pause continuation is the same hole, reported
at the pause once the join exists.

**6. The parked set is unchanged, and `parked-eof-start` gains an arm: a
non-entry counted consume starts its walk at its eof-target.** Neither `§16.2:909`
disjunction gains a kind of its own; both keep `(symbol? (node-eof-target n))`.
The ground is an invariant of item 1's table, checked against the runtime rather
than against the table: the only return that leaves `current` on an input-reading
node is `need-input`, and for this kind that return happens only in rows 2 and
3-partial, both of which leave the field **positive** — a zero count transitions
away (row 1) and a completing commit transitions away (row 3, `n = v`). Fields are
written by machine nodes only (`§13:801`: "Machine-field access from a callback
is read-only"), and `parser-reset!` moves `current` to the entry. So a parser
parked on a non-entry counted consume by `need-input` holds a positive count at
`parser-finish!` and takes its EOF route, never `next`, and its walk starts there
— exactly as `parked-eof-start` already starts a parked callback's walk at its
pause continuation, for the reason that construct's comment gives. The **entry** is
the exception it already carries for callbacks: a fresh parser is parked at the
entry without having executed it, its count is the field's initial and may be
zero, so the entry starts at itself and takes item 5's join. A `#f` eof-target is
then benign for a parked node exactly as it is for a dispatch, and the shipped
proxy's exclusion of it is correct rather than accidental.

Two machines fix the rule from both sides, and Slice ① owes both as fixtures.
*Rejected*: the entry a counted consume with initial `0`, `#f` eof-target and a
stop for `next` — item 5's hole, `eof-reachable-stop` at the entry. *Accepted*:
`… →(byte) body (eof: an error; next: a stop)`, the one-shot "length, body, stop"
grammar — a parser parked on `body` holds a positive count and takes the error at
EOF, and no EOF path reaches the stop. **The design's first draft parked the kind
by kind and would have rejected the second machine**; its review found that the
by-kind disjunct caught nothing item 5 does not (every parked origin whose count
may be zero already reaches the node through a walk the join classifies), was
inert in pass 7 (a byte-reachable counted consume's `next` is already a byte
edge, the shipped span-end derivation), and over-rejected. Recorded here so the
withdrawn rule is not re-derived from the draft's commit.

**7. `next` is a zero-progress edge, and the kind joins the REPORT set, in one
commit.** `reexec-targets` answers `(list next)` for the kind — the same shape
the arm gives accumulate's overflow edge — and the report set's kind list gains
the predicate in the same commit, on the rule `pass-zero-progress`'s own comment
states: the walk and the report set move together or the half-fix Milestone 3
Slice ② shipped returns. A self-targeting `next` is `zero-progress-cycle`: with a
zero count it hangs both executors.

**This is a known over-rejection, priced.** The verifier already rejects every
loop whose termination depends on a field value — `branch → decrement → branch`
is a zero-progress cycle today though it terminates after finitely many
iterations — and `next` inherits that conservatism: `[branch zero? records → done]
→ consume(record-size) → decrement records → branch` is rejected although it
terminates whenever `records` does. The ground, quoted rather than paraphrased:
`§11.4:654` reads "Any reachable cycle that can run indefinitely without consuming
input is invalid." The verifier cannot see that `records` decrements, so it cannot
separate the loop that terminates from the one that runs indefinitely, and it
rejects both. The bound is `§16.2:913`: "Normal consuming cycles, including the
main HTTP message loop, are valid" — every loop `§21` needs, the message loop and
the chunk loop, carries a byte dispatch that advances and is untouched. The
workaround for the rejected shape is a byte-consuming node in the loop.

## Consequences

- **Four verifier constructs need the kind in both families' answer**, and a
  slice filing it under "input-reading, like accumulate" gets exactly these four
  wrong and nothing else: `reexec-targets` (item 7), the zero-progress REPORT set
  (item 7), `classify` (item 5), and `eof-successors` — and through it pass 7's
  `eof-step` (item 5). **A fifth, `parked-eof-start`, takes the input-reading
  answer** for a stated reason (item 6), and a slice filing the kind under
  "parked, like a callback" gets that one wrong in the other direction.
- **What does not change, and why each is a derivation.** `node-out-edges` gains
  the kind's `next` as a byte edge with role `next`, so `§16.2:908`'s derived block
  rejects a byte-reachable counted consume whose `next` is a finish with no new
  code. Both parked-set disjunctions keep their `symbol?` clause and gain
  nothing (item 6). `span-transfer` is the identity and `span-node-diagnostics`
  answers nothing: a counted consume inside a span is `§10.6:604`'s explicit
  case. `pass-names`' error filter, `pass-overlap`, `pass-sequence-ambiguity` and
  `pass-declarations`' node walk owe nothing — the kind names no error
  declaration, has no cases, and names no callback or span; its one
  cross-reference is a field, which is `pass-field-operands`' (design §4.3).
- **Fixtures Slice ① owes, by shape.** The flow-through zero-count stop at the
  entry, REJECTED (`eof-reachable-stop`); the same through a pause continuation,
  REJECTED at the pause; the one-shot "length, body, stop" grammar, ACCEPTED; a
  self-targeting `next`, `zero-progress-cycle` alone; a self-targeting eof-target,
  `eof-zero-progress-cycle`; item 7's priced over-rejection as an accept/reject
  pair — the loop with a consuming node verifies, the loop without one does not.
- **The exact-case placement of the completion event is asserted as a value per
  feed in Slice ②**, never as lane agreement (item 2). Under the byte-at-a-time
  schedule of a three-byte body the completion lands in the feed that delivered
  the third byte, not in the feed that delivers the delimiter after it.
- **Decision 0023 item 3 is amended**, not for its set — "the set of states an
  execution can be PARKED on" stands and admits the kind — but for its closing
  clause, "with each node classified as itself", which item 6 makes false for a
  second kind. It was already false for the callback node since Milestone 5
  Slice ②, unrecorded there until this record's note.
