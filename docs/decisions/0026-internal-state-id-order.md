# 0026: Internal state ids merge by declaring-node order inside 0016's phase two

Date: 2026-09-04
Status: accepted
Milestone: 5, Gate 0 (milestone-5-design.md §4.4)

## Context

Decided 2026-09-04 against branch `feat/milestone-5-gate-0` (base `cc66302`) plus
this gate's own documentation changes. Every parent-plan and `src/` line quoted
below was read that day. Gate 0 changes no product code; what follows is an order
handed to Slice ③.

**The gap.** Exactly one sentence in the parent plan says how internal state ids
are *assigned* — `§17:955`. Measured two ways on 2026-09-04, because a
load-bearing negative deserves a second method: a case-insensitive search for
"internal state" over the whole plan returns seven lines — `§9.3:403`,
`§12.7:758`, `§12.7:777`, `§17:955`, `§17:959`, `§20:1036`, `§25:1530` — and a
search for `internal` intersected with `id|ID|number|index` adds none of its own.
Only `:955` states an assignment rule:

> resolve symbolic names to stable numeric IDs (declared nodes keep their declaration index; internal states append after them — decision 0016);

It defers to [decision 0016](./0016-normalized-state-id-allocation.md), whose
item 1 pins a total order for exactly **one** family:

> Internal prefix states are assigned ids after the entire declared block, ordered by (declaring-node order, then prefix-structure pre-order, taking each prefix state's children in ascending byte order).

`§20:1036` requires "deterministic internal state numbering" and does not say what
the numbering is. Nothing covers a second family, or how a second family orders
against the first.

**Milestone 5 creates the second family.** `§17:959` — "lower multi-step span
endings into resumable internal states;" — is Slice ③'s obligation, and a span-end
continuation has no source declaration, exactly as a prefix state has none.

**Measured against the tree, 2026-09-04: today there is exactly one family, and
the shipped normalizer already spells 0016 item 1 out.** `normal-ir.sls:293`'s
`prefix-blocks` walks the declared node list in order and allocates ids upward
from `declared-count` (`:273`) for sequence-dispatch nodes only; `:427`'s
`internal` flattens those blocks in the same order; `:433` builds the states
vector as `(append declared internal)`. The kinds that allocate no internal state
say so at their own sites (`:382-386`, `:400-403`). So the rule below is **inert
until Slice ③ lands** — which is why it can be settled by argument now rather
than discovered by a moved golden later.

**The choice is not free.** 0016's Context:

> The choice is externally observable: state ids feed the IR fingerprint of decision 0009 and the order of the emitted `case` arms.

Re-measured here rather than taken on trust: `compile.sls:543-547` emits one
`case` arm per entry of the normalized `states` vector, **in vector order**, each
arm keyed on `normal-state-id` (`compile.sls:235`).

**And observable despite `§12.7:777` — the objection a later slice will otherwise
raise against this whole record.** That sentence reads: "The internal state ID is
an executor-local debugging aid: generated IDs are deterministic for a given
normalized graph, but an independently interpreted machine need not report the
same ID. Differential tests do not compare that accessor across executor kinds."
It puts the *reported id value* outside the cross-lane contract. It leaves the IR
fingerprint and the emitted text inside it, and `§20:1036` still requires the
numbering to be deterministic within the generated lane. What this record pins is
therefore the allocation order, not any id's value.

**Why the phase boundary needs restating.** The design's §4.4 as first written
read as interleaving internal states with *declared* ones; it was corrected in
place on 2026-09-04 and the correction is a dated note in that document's
Amendments block. That reading is not merely outside 0016 item 1's words — 0016's
own Consequences rejected it, with a reason:

> Interleaving — giving each sequence node's prefix states ids immediately after it — was rejected. It renumbers every later node and moves the fingerprint of every machine containing a sequence, for no benefit.

The two internal families interleave **with each other**, by declaring node.
Internal states never interleave with declared ones.

## Decision

**1. 0016's two-phase append is unchanged; its second phase gains one merged
pre-order over declaring nodes.**

Phase one is untouched: every declared source node keeps its declaration index as
its id. Phase two assigns an id to every internal state, of either family, after
the entire declared block; and within that block a declaring node contributes
**all** of its internal states — prefix states and span continuations alike — at
its own position in declaring-node order. Where 0016 item 1's within-node order
applies it is unchanged: a node's prefix states keep prefix-structure pre-order,
children ascending by byte.

**The merged pre-order operates inside phase two. It does not interleave internal
states with declared ones.** Said in as many words because a shorter statement of
this rule reads the other way, and the other way is the shape 0016's Consequences
rejected.

This extends 0016's own ordering principle rather than adding a precedence rule
beside it: item 1 already orders internal states by declaring-node order, and this
rule says only that "declaring node" keeps its meaning when one node declares two
kinds of internal state. The alternative — the two families in sequence within
phase two, all prefix states and then all span continuations — requires an
arbitrary choice about which family comes first, and leaves the third family,
whenever it arrives, asking the same question again.

"Declaring node" is well defined for the second family, and the parent plan
requires it to be: `§17:963` keeps a "state-ID-to-source-name debug map", which the
shipped normalizer makes total over the one internal family that exists today by
answering with each prefix state's *declaring* node (`normal-ir.sls:434-440`, the
`debug-map` binding and the comment above it, which says so in those words); and
`§13:820` requires that "public parser state names the
source callback/span node, not a generated internal continuation". A span
continuation with no declaring node leaves both unsatisfiable. Slice ③ keeps that
map total over the new family.

**2. A span end lowers to one internal state per resumable substep, not a fused
state.**

**The decisive constraint is `§14:838` — rule 9, the span-end pause rule:**

> If a span-end data or completion callback pauses, generated internal continuation states resume at the next undelivered substep.

A fused state has a single resume point; "the next undelivered substep" is
expressible only if each substep has one. `§14:841` names the state that sits
between the substeps a span end delivers: "A pause after the data fragment retains
only an internal `completion-pending` continuation, never the input bytevector."

**Supporting, and only supporting**, `§17:966`: "Normalization must not perform
speculative performance transformations in v0.1. It should produce the simplest
correct execution graph." Fusing substeps into one state is a state-count
reduction that correctness does not require, so that sentence defers it. Which way
this cuts matters: on its own `§17:966` would forbid fusion only as an
*optimization*; it is rule 9 that makes the unfused shape the correct one.

**Consistent, and decisive by itself in neither case**: `§17:959` calls the
construct "multi-step span endings", so an ending has more than one step; and
`§10.6:594` uses the plural for a *single* span end — "It emits a remaining
nonempty data fragment, then the completion callback. Internal continuation states
ensure a pause never repeats an already delivered fragment or completion event."
Between them they rule out one state for the whole span end. Neither picks
one-per-substep. Rule 9 does.

## Consequences

- **The order is pinned by this record, not by whatever order the lowering happens
  to build** — 0016's own reason for pinning its own. It is observable twice over:
  through decision 0009's IR fingerprint, and through the emitted `case` arm order
  measured above at `compile.sls:543-547`.
- **A machine that declares no span end keeps every id it has today.** With one
  family present, phase two's merged pre-order *is* 0016 item 1's order, so this
  rule moves no id and no fingerprint. That is 0016 item 2's sequence-free
  guarantee transferred. Whatever else Milestone 5's seam work does to emitted text
  is [0025](./0025-milestone-5-seam-encoding-abi-exec.md)'s business, not this
  record's.
- **Decision 0016 needs no amendment.** Item 1's phase boundary stands as written,
  and this record extends its order to a second family rather than contradicting
  anything it says. Nothing was appended to 0016, deliberately.
- **Slice ③ owns the lowering; this record owns the order and the granularity.**
  Three obligations hand over: allocate phase-two ids by the merged pre-order, give
  each resumable substep its own internal state, and keep `§17:963`'s debug map
  total over the new family. Slice ③ consumes this record together with
  [0027](./0027-reachable-path-for-callbacks-and-spans.md) and
  [0029](./0029-span-state-is-a-lattice.md).
- **This binds the normalizer's ids only.** `§18:972` — "Interpreter-private state
  may track progress inside a high-level source node, such as a sequence prefix or
  a pending span-end substep, but that representation must be derived independently
  from the production normalizer" — keeps the interpreter's substep representation
  its own. Nothing here requires the two to have the same shape; what must agree is
  the observable event sequence, which is Slice ③'s oracle rather than this
  record's.
- **What this record does not decide**: how many substeps a span end has — the
  parent plan names two deliverable events at `§10.6:594`, but the count belongs to
  the lowering — and nothing about slot numbering, which `§17:962` keeps as its
  own responsibility: "assign field, callback, and span slots".
