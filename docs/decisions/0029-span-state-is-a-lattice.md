# 0029: Span state is a lattice; disagreement at a merge point is a diagnostic

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.7)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-05 (Milestone 5 Slice ③)** — **annotates**: the pass shipped. Nothing
>   above became false; the note records the edge set item 3 does not fix, one
>   Consequence the shipped verifier does not implement for ANY pass, and the
>   `§16.2:899` rejection this record's mapping does not cover.

## Context

Decided against the tree at `cc66302`. The parent plan enumerates what the
verifier rejects about spans three times, in three vocabularies, and never maps
one onto another. (The restriction itself is stated three times more — `§2:36`,
approved decision 14, "At most one span may be active at a time in v0.1.";
`§4:81-82`, the non-goals; and `§29:1752`, "- multiple concurrent or nested
spans;", among the deferred extensions — but none of the three names a check or a
rejection, so none adds a vocabulary to map.) Measured 2026-09-04, verbatim:

- **`§16.2:899`** — "span re-entry, overlap, wrong end, unmatched end, and
  inconsistent successful exits;". Five rejections, named as a list of nouns.
- **`§14:843`** — "The verifier proves that no reachable path starts a second
  span while one is active, ends the wrong span, ends with no active span, or
  reaches successful stop/finish with a span active." Four properties, quantified
  over paths.
- **`§10.4:519`** — "Only one span may be active on any reachable execution path
  in v0.1. The verifier rejects nested, overlapping, re-entered, or
  inconsistently closed spans." Four rejections again, and one name — *nested* —
  that appears in neither of the other two.

The pass that must satisfy all three is named once and described nowhere:
`§16.3:925` is the whole of it, "7. Span-state dataflow.", and `§25:1584` lists
"span dataflow verification." as Milestone 5 scope.

The word that carries the open question appears once. `rg -nw "inconsistent"`
over the parent plan returns exactly one line, `§16.2:899`; the adverb form
`inconsistently` appears once more, at `§10.4:519`. Nothing defines either, and
whether "inconsistent" is a fifth property or a restatement of `§14:843`'s
fourth decides the *domain* the check runs over, not only its wording.

Nothing is implemented yet, so nothing here is a fix. `rg -n "define \(pass-"
src/byte-machine/verify.sls` returns eleven passes and none of them is the span
pass; `rg -n "span" src/byte-machine/verify.sls` returns exactly one line, the
comment at `:694-695` recording that "Milestone 5's span check needs `finish`
distinguished from `error` at `classify`".

## Decision

**1. Pass 7 is a dataflow analysis over an abstract span state, run to a
fixpoint — not an enumeration of paths.** The abstract domain is the flat
lattice

- `⊥` — no state has reached this node yet;
- `none` — no span is active;
- `(active s)`, one element per declared span name `s`;
- `⊤` — incoming edges disagree.

It is finite (the declared span set is finite) and of height two, so the join is
`⊥ ⊔ x = x`, `x ⊔ x = x`, and `⊤` otherwise. The entry is seeded `none`. Each
node's out-state is its transfer function applied to the join of its in-edges,
and the analysis terminates because a value can rise at most twice.

**2. Disagreement at any merge point — not only at an exit — is itself a
diagnostic.** A join yielding `⊤` is reported at the node where it arises.

Two arguments were offered for items 1 and 2 together. They do not divide
evenly: **only the first reaches item 2.**

*(a) From interpretation.* Under the path-existential reading, "inconsistent
successful exits" means *some path reaches a successful exit with a span active*
— which is exactly `§14:843`'s fourth property, "reaches successful stop/finish
with a span active", and whose EOF half `§16.2:907` states a second time. That
reading buys the spec no rejection it does not already make, and leaves one of
`§16.2:899`'s five named rejections as a paraphrase of a sentence in another
section; the lattice reading gives that name a referent — merge-point
disagreement — that no other sentence in the plan names. Be precise about the
strength of this: it says one reading of an undefined word is more plausible than
the other. **It does not force anything**, and it is the whole of the
interpretive case.

*(b) From the graph — it forces item 1, and stops there.* `§16.2:913` reads
"Normal consuming cycles, including the main HTTP message loop, are valid." The
verifier may therefore not reject a cyclic machine, and the set of reachable
paths through a cycle is infinite — so a check that literally enumerates the
paths `§14:843` quantifies over does not terminate on the very machine the plan
names as the motivating example. A fixpoint over a finite domain does. That
settles analysis rather than enumeration, and nothing more. It is **not** an
argument for item 2: the path-existential reading has its own terminating form —
the same walk over the powerset of `{none, (active s), …}`, joined by union — and
that one is finite, terminates on cycles, forms no `⊤`, raises nothing at a
merge, and decides `§14:843`'s four properties exactly. The two analyses are not
one check wearing different words; they part on a constructible machine. Two
branches, one starting span `s` and one not, merge into a node whose only
continuation is an *error* terminal: this record reports that merge, and the
powerset analysis accepts the machine — as does `§14:843`, because an error
terminal is not a successful stop/finish, and `§14:839` contemplates a span still
open at one.

*The other half of the warrant, once `⊤` is in the domain.* Reporting at the
merge is what keeps the transfer functions total. If `⊤` were allowed to flow
onward, every transfer would need an answer for "what does a span end do on
`⊤`?" — and both answers are bad: reporting downstream blames a node that is
innocent, and falling silent is unsound. Item 2 — and with it the choice of the
flat lattice over the powerset domain in item 1 — rests on (a) and on this, and
on nothing about cycles.

**3. The quantifier "reachable path" is decision 0027's relation**, byte
reachability plus the EOF walk, not `pass-reachability`'s `all-out-targets`. The
analysis runs over the nodes that relation admits: a node no execution can occupy
contributes no state to a join and receives none, so it can neither raise a
diagnostic nor push a live node to `⊤`. Taking the relation from
[decision 0027](./0027-reachable-path-for-callbacks-and-spans.md) rather than
choosing one here is the point: 0027 carries two relations deliberately and names
the check that uses each, so a third, minted here for this pass alone, would be a
relation with no recorded reason. What 0027 measured at `§16.2:898` is the
neighbouring failure and not this one — `pass-zero-progress` applies **no**
relation where that bullet says *reachable*: "neither `reached` nor
`byte-reached` occurs as an identifier anywhere in the pass"
([0027](./0027-reachable-path-for-callbacks-and-spans.md):59-60 — **as an
identifier** is load-bearing, because `reached` appears in a comment at
`verify.sls:530` and `reaches-self?` is defined at `:610`, both inside the pass)
— and 0027 item 3 answers it with the `byte-reached`
gate.

**4. A successful exit requires `none`.** `(active s)` surviving to a stop node
(`§10.6:612`, "Enters a successful sticky one-shot terminal and returns
`stopped`.") or a finish node (`§10.6:616`) is `§14:843`'s fourth property, and
it stays a separate check from item 2's `⊤`: paths that *agree* on leaving a span
open are consistent and still wrong.

## Consequences

- **The pass states its own abstract domain and its own join.** They are not
  inferable from the diagnostics it emits, and `§16.3:929` — "Each pass receives
  an immutable value and returns diagnostics plus any derived immutable analysis."
  — makes the fixpoint map a first-class output, not a local variable.

- **`§16.2:899`'s five named rejections map onto the analysis explicitly.** This
  mapping is the record's product; three vocabularies with no mapping is what the
  Context describes.

  | `§16.2:899` | where it arises |
  | --- | --- |
  | span re-entry | transfer of a span start for `s` on `(active s)` |
  | overlap | transfer of a span start for `s` on `(active t)`, `t ≠ s` |
  | wrong end | transfer of a span end for `s` on `(active t)`, `t ≠ s` |
  | unmatched end | transfer of a span end on `none` |
  | inconsistent successful exits | a join yielding `⊤` |

  `§10.4:519`'s *nested* gets no cell of its own: with only one span permitted
  active, nesting **is** a start on `(active t)` — the overlap row when `t ≠ s`,
  the re-entry row when `t = s`. `§14:843`'s fourth property is decision item 4's
  terminal check rather than a row here, and its EOF half is already a bullet of
  its own — `§16.2:907`, "invalid EOF targets or successful EOF with an active
  span".

- **Handed to Slice ③.** Design §8 allocates `§16.2:899`, `:900` and `:907`'s
  span half to this one pass. `:900` — "explicit pauses or event/decision
  callback invocations reachable while a span is active;" — is answered by
  reading the same abstract state at the pause or callback node. Design §8 says
  it "lands here and can land nowhere else", and the reason has two halves: it
  needs this dataflow *and* Slice ②'s callback node. The diagnostic codes are
  Slice ③'s to mint, not this record's; Slice ⓪'s census is the ratchet, and
  `§Dated:1959-1960` says what it does — "a new code, or a new site under an
  existing code, fails it until accounted for".

- **The graph is the declared one, not the normalized one.** `§18:970` calls the
  verifier's output "verified source IR"; `§9.2:368` says `compile-machine`
  "always performs verification and refuses to expose an emission-ready
  normalized graph on failure"; `§16.3:931` puts normalization outside the
  numbered pass list entirely — "Normalization is followed by private invariant
  validation." — and `compile.sls:33` runs `verify-machine` before `:36` calls
  `normalize-machine` on its result. So the resumable internal states that
  [decision 0026](./0026-internal-state-id-order.md) orders do not exist when
  pass 7 runs: a span end is one node to this analysis, whatever it lowers to
  afterwards. A slice that runs the lattice over the lowered graph is analysing a
  different program.

- **Distinguishing a successful exit from an error exit is load-bearing here, and
  it is already paid for.** [Decision 0023](./0023-eof-walk-starts-and-finish-reachability.md)
  item 5 kept all six EOF verdict symbols, and named this check as one of its two
  reasons — "M5's span check needs `finish` distinguished from `error` at
  `classify`". `verify.sls:694-695` carries the same reason in the code. Item 4
  above is what consumes it.

- **This record adds no third reachability relation.** 0027 records the two the
  verifier deliberately carries and says which passes use which; pass 7 consumes
  one of them and defines none of its own.

## 2026-09-05 (Milestone 5 Slice ③): the pass shipped, and three things the record left to it

`pass-spans` implements items 1, 2 and 4 as written: the flat lattice, the
fixpoint, `top` reported where it arises, and the successful-exit check kept
separate from it. The `§16.2:899` mapping in the Consequences is the table the
verify fixtures are organised by, and `differential-span-tests.sps` enumerates
eleven span topologies with each verdict derived from `§14:843` or `§16.2:899`
before it was run — which is what `§25:1590`'s universal now rests on.

**1. Item 3 fixes the NODE domain and says nothing about the EDGE SET, and the
two are different questions.** The record takes 0027's reachability relation and
concludes which nodes carry state; a dataflow also needs to know which edges the
transfer function follows. It is load-bearing: `§16.2:907` is *successful EOF with
an active span*, and a dataflow over byte out-edges alone never reaches a finish
node that is only EOF-reachable. The pass's edge relation is therefore byte edges
plus EOF routes, and a fixture whose only route to a finish is an eof-target,
with a span left open, is what proves it. This is a gap in the record, filled by
the implementation, not a contradiction of it.

**2. Item 3's "a node no execution can occupy contributes no state to a join and
receives none" is satisfied BY THE RELATION, not by a guard.** A `(memq to live)`
filter was written first and its mutation shipped UNCAUGHT: `live` is the closure
of the pass's own edge relation, so every edge's target is in it by construction
and the filter could never fire. It was deleted rather than documented, and the
decision it was meant to witness is now witnessed where the two relations
actually differ — an EOF half that keeps taking byte edges.

**3. One Consequence describes something the shipped verifier does not do for ANY
pass.** It reads: `§16.3:929` "makes the fixpoint map a first-class output, not a
local variable". Every pass in `verify.sls` returns diagnostics and nothing else,
and `verify-machine` appends their lists; there is no channel for a derived
analysis and `pass-spans` inventing one would have been the only pass with an
unused second return. `§16.3:929`'s "plus any derived immutable analysis" is
permissive, so nothing is violated — but the Consequence reads as a requirement
this pass failed to meet, and it is not: it is a requirement the ARCHITECTURE has
never met, and whoever wants the map (an emitter consuming span state, say) is
changing `verify-machine`, not `pass-spans`.

**4. The mapping table does not cover `§16.2:901`'s span half, and nothing else
did either.** The five rejections `§16.2:899` names all map onto the lattice, and
a sixth fault does not: a span node naming a span the machine never DECLARED. The
lattice is well defined over any symbol, so it treats the name opaquely and can
never notice — which is correct for a lattice and wrong for a verifier.
`make-span-start-node`'s own comment had assigned the cross-reference to
"`§16.2:899` and pass 7's lattice (decision 0029)", so the obligation was recorded
against this record and discharged by nothing. Measured before the fix: such a
machine verified CLEAN and then raised out of `normalize-machine`. It is now
`pass-declarations`' `missing-span-declaration`, beside the callback half — where
a NAME cross-reference belongs, and where this record never put it.
