# 0029: Span state is a lattice; disagreement at a merge point is a diagnostic

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.7)

## Context

Decided against the tree at `cc66302`. The parent plan describes the span
restriction three times, in three vocabularies, and never maps one onto another.
Measured 2026-09-04, verbatim:

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
fourth decides the *shape* of the check, not only its wording.

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

Two arguments, and **the second is the decisive one**.

*(a) From interpretation, and this one alone would not settle it.* Under the
path-existential reading, "inconsistent successful exits" means *some path
reaches a successful exit with a span active* — which is exactly `§14:843`'s
fourth property, "reaches successful stop/finish with a span active", and whose
EOF half `§16.2:907` states a second time. That reading buys the spec no
rejection it does not already make, and leaves one of five normative bullets as a
paraphrase of a sentence in another section; the lattice reading gives the bullet
a referent — merge-point disagreement — that no other sentence in the plan names.
Be precise about the strength of this: it says one reading is more plausible than
the other. **It does not force anything**, and on its own the path-existential
reading would remain available.

*(b) From the graph, and it forces the shape.* `§16.2:913` reads "Normal
consuming cycles, including the main HTTP message loop, are valid." The verifier
may therefore not reject a cyclic machine, and the set of reachable paths through
a cycle is infinite — so a check that literally enumerates the paths `§14:843`
quantifies over does not terminate on the very machine the plan names as the
motivating example. A join over a finite lattice does. Any terminating
path-shaped check is this fixpoint wearing different words, so it is written as
the fixpoint.

*Supporting, not evidence.* Reporting at the merge is also what keeps the
transfer functions total. If `⊤` were allowed to flow onward, every transfer
would need an answer for "what does a span end do on `⊤`?" — and both answers are
bad: reporting downstream blames a node that is innocent, and falling silent is
unsound.

**3. The quantifier "reachable path" is decision 0027's relation**, byte
reachability plus the EOF walk, not `pass-reachability`'s `all-out-targets`. The
analysis runs over the nodes that relation admits: a node no execution can occupy
contributes no state to a join and receives none, so it can neither raise a
diagnostic nor push a live node to `⊤`. Taking the relation from
[decision 0027](./0027-reachable-path-for-callbacks-and-spans.md) rather than
choosing one here is the point, and 0027 states why: a second relation chosen for
no recorded reason is how `§16.2:898`'s missing gate came about.

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

- **`§16.2:899`'s five bullets map onto the analysis explicitly.** This mapping
  is the record's product; three vocabularies with no mapping is what the Context
  describes.

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
