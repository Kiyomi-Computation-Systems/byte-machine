# 0031: Reachability is the occupiable relation — `pass-reachability` walks it, `all-out-targets` retires, and the family whose verdict changes

Date: 2026-09-06
Status: accepted
Milestone: 7, Gate 0 (milestone-7-design.md §4.1)

## Context

Decided against `main` at `50516af` — the Milestone 7 design (PR #83) and its Gate 0
plan (PR #84) merged; `src/` and `test/` byte-identical to `5ac363a`, the commit the
design measured (`git diff --stat 5ac363a..50516af -- src/ test/` prints nothing).
Every construct named below was read on 2026-09-06 and is cited by name, with the
command that found it; the design's §3.1 measured the line numbers and this record
deliberately does not repeat them.

**One fact, and everything here descends from it.** `§16.2:897` reads "unreachable
nodes;" and `§16.4:947` begins "Unreachable nodes are errors in v0.1." Neither says
over which relation a node is reachable, and the verifier holds two.
[Decision 0027](./0027-reachable-path-for-callbacks-and-spans.md) item 1 defines the
*occupiable* relation — a state is occupiable when it is in `byte-reached` or is
visited by an EOF walk from the parked set — and its Consequences table gives it two
consumers, the `§16.2:908`/`:909` checks and pass 7's span lattice. The sentence
beneath that table says the occupiable relation "is the one that means 'an execution
can be here'", and that `all-out-targets`, read by `pass-reachability` alone, "is
retained unchanged and is the subject of an open question this record does not
answer". [Decision 0023](./0023-eof-walk-starts-and-finish-reachability.md)'s third
Consequence raised the question — "`pass-reachability` walks `all-out-targets`, so a
node reachable only through an untakeable EOF edge counts as reached" — and said it
"must not be read as closed by this record". Milestone 6 priced narrowing it (its
design §8) and handed it here at the parent plan's appended disposition "§25:1611 —
Milestone 6 hands the reachability narrowing to Milestone 7", under `§25:1615`'s
reading ("generative and diagnostic hardening of all mandatory verification passes
already introduced"); `pass-reachability`'s own note in `verify.sls` names that
disposition.

The ground the answer rests on is the parent plan's `§12.2:694`, the `finish-ready`
row of the operation matrix, whose `feed!` column reads "Contract condition". Once an
execution takes an eof-target it can never feed again, so feed-reachable ⊆
`byte-reached`, and a walk that crosses an eof-target and then takes a byte edge
describes no execution. `verify.sls` records that sentence at `pass-eof-execution`'s
gate and again above `span-flow`'s `eof-nodes`.

**The verifier's constructs, measured** (each command run at `50516af`):

- **`all-out-targets` has one consumer.** `rg -n all-out-targets
  src/byte-machine/verify.sls` prints six lines: the definition ("byte out-targets
  PLUS a dispatch/sequence node's eof-target (for reachability only)"), the one call
  `(reach-from m all-out-targets)` in `pass-reachability`, and four comment lines —
  `reach-from`'s header, `pass-reachability`'s note, `pass-zero-progress`'s note, and
  the edge-relation comment above `eof-step`. `reach-from` is a visited-set DFS from the entry over whatever edge
  function it is handed, "shared by pass-reachability and byte-reached, which differ
  only in which edge function they walk"; `byte-reached` is `(reach-from m
  node-out-targets)`.
- **The `§16.2:909` parked set is written twice by hand, and the copies differ by one
  disjunct.** `pass-eof-execution`'s membership, gated on `byte-reached`, has five
  disjuncts — the entry, `pause-node?`, `callback-node?`, `span-end-node?`,
  `(symbol? (node-eof-target n))`; pass 7's `parked?`, gated the same way, has four —
  the same without `span-end-node?` — under a comment deriving the omission inert for
  pass 7 and warning that "the next kind that can pause has to be added to BOTH".
  `rg -n "^\s+\(span-end-node\? n\)$" src/byte-machine/verify.sls` prints exactly one
  line, the disjunct in `pass-eof-execution`; `rg -n "symbol\? \(node-eof-target n\)"`
  prints three — the two code sites and one comment inside `parked-eof-start` naming
  the clause (Milestone 6's Gate 0 plan counted two, before that comment was written).
- **`span-flow`'s `eof-nodes` is the EOF half of 0027 item 1's relation as a visited
  set**: a DFS whose frontier is seeded with `(eof-step n)` for every node satisfying
  `parked?`, following `eof-step` and "never taking a byte edge". `eof-step` is pass
  7's per-node EOF successor list, read from the same helper `classify`'s join reads
  (decision 0030 item 5's "one fact" rule).
- **The two walks do not start in the same place.** `pass-eof-execution` calls
  `(eof-terminal m (parked-eof-start m n))` — and `parked-eof-start` answers a
  non-entry callback's pause continuation, a non-entry counted consume's eof-target,
  and the node's own name otherwise — while `span-flow` seeds from `(eof-step n)` of
  the parked node itself. Two procedures today; item 4 says why their visited sets
  are one set.
- **`unreachable-node` has one emission site**, `pass-reachability`'s `map`; the
  diagnostic census's row is `(unreachable-node 1)` (`diagnostic-census-tests.sps`);
  the kind × position matrix asserts "exactly three cells prune the sink" as an
  observed count (`kind-position-census-tests.sps`).
- **A stale citation, recorded so the slice that edits the file corrects it.**
  `reexec-targets`' integer-accumulate arm, inside `pass-zero-progress`, cites
  `§12.7:772` for the overflow edge being non-consuming. That line of the parent plan
  is blank; the sentence — "Integer-overflow nodes reject and do not consume the
  overflowing digit, so their position is the offending byte" — is `§12.7:773`.
  Decision 0030's Context carries the same citation.

**The pricing was measured, and it was wrong in two of three predictions.** Milestone
6's design §8, transcribed into the `§25:1611` disposition, predicted from reading
that the narrowing would (a) make decision 0027's `E →(eof) T →(byte) Z` family gain
`unreachable-node`; (b) flip "the shipped `verify-tests.sps` fixture asserting that
`unreachable-node` does **not** catch that family"; (c) move the matrix's pruning
count, "because a sink reached only through a placed node's EOF route stops being
reached". The Milestone 7 design applied the change — `pass-reachability` reading
`byte-reached` ∪ the EOF walk's visited set, one changed line and a thirteen-line
helper, reproduced in its §4.1 — in a detached worktree at `5ac363a` and ran the
release selection minus the mutation lane: 113 lanes, 111 pass, and
`byte-machine.verify.rejections.chez.source` and `.aot` fail on **three cases** of
`verify-tests.sps`, listed in the design's §3.2 item 1 with their `got` lists. PR
#83's tree-claims review re-ran the prototype and, in the PR's description,
"reproduced the three cases byte for byte". Measured against that run:

- **Effect (a) occurs**, in a fixture the pricing did not name: "a node no execution
  can occupy contributes no state (0029 item 3)" builds 0027's Context machine's shape with a
  span end as `Z` — `cl` on `t`'s byte edge, then `exit`, `done` and `fin` behind it —
  and answers `unreachable-node` four times where it answered nothing.
- **Effect (b) does not occur.** The fixture named — "and `unreachable-node` does NOT
  catch it, which is why the gate is not benign", under `§16.2:898`'s gate group —
  builds a **collapsed** variant of 0027's Context machine: `t` plays both `T` and `Z`,
  its case edge a `reexecute` self-loop and its eof-target an error node, so in the
  fixture `Z = T`. `t` is occupiable — the entry is parked, its eof-target is `t`, the
  EOF walk visits it — so the check "t is not reported unreachable" holds under both
  relations. 0027's machine **as written** has `Z` distinct from `T` — a third node
  carrying the `reexecute` self-loop, and a finish node as `T`'s eof-target — and that
  machine is in the family; the 0029 item 3 case is its shape.
- **Effect (c) does not occur.** No builder in the matrix's `kind-table` names an
  eof-target (every input-reading builder passes `#f`), and the sink `ee` is in
  `byte-reached` in every cell that keeps it — through a byte edge of the host where there is
  one (its fallback at twenty positions; its case or alternative edge at
  `dispatch-fallback` and `sequence-mismatch`, where the fallback is the position
  under test), and through the placed node's own out-targets at the entry position — so a walk that drops only nodes reached
  through an eof-target cannot touch it. The count stays 3;
  `unit.kind-position-census` passed in both modes under the prototype.
- **The other two cases** the pricing did not name: the `t2-kinds` accept case ("an
  EOF-only-reachable byte edge into a finish is accepted"), where `fin` is reachable
  only through the placed node's byte edge and that edge is dead for the three
  input-reading kinds among the eight; and the join case ("a `default-error` sibling
  does not mask the stop"), where `x` is an EOF-only-reachable byte-dispatch whose
  fallback is the byte edge to `rj2` and nothing else reaches `rj2`.

The pricing's "three test files", corrected by Milestone 6's Slice ② to the two it
could name, is **one file, three cases**; the census row does not move, because the
narrowing changes the walk and not the emission site. This record cites that
measurement rather than re-deriving the family from the walk's definition, because
deriving it from reading is exactly how the pricing named the wrong fixture.

## Decision

**1. `pass-reachability` reads the occupiable relation, computed once and shared
with pass 7.** The relation is `byte-reached` ∪ the set of nodes the EOF walk from
the parked set visits — decision 0027 item 1's, unchanged — and it is computed by one
procedure, `occupiable`, factored out of `span-flow`'s `eof-nodes` so that
`pass-reachability` and `span-flow` read one walk (the "ONE census, two views" rule
`node-out-edges`' comment states). `span-flow` keeps its edge list; only the visited
set moves. The ground is decision 0023 item 3's sentence, transferred to a third
consumer as 0027 transferred it to a second: "a graph node no execution can occupy is
not a state that originates a traversal". A node no execution can occupy is
unreachable in the only sense the plan uses the word. The gate is sound by
`§12.2:694`: once an execution takes an eof-target it can never feed again, so
feed-reachable ⊆ `byte-reached`, and eof-targets and zero-width continuations — the
EOF walk — are the whole of what an execution can do afterwards.

**2. The family whose verdict changes, stated exactly.** `E →(eof) T →(byte) Z`,
where `T` is reachable only through an EOF route; `T` is byte-dispatch,
sequence-dispatch or integer-accumulate — the three kinds whose byte edges are dead at
EOF; and `Z` is a node **distinct from `T`**, reachable over `all-out-targets` only
through a dead byte edge of `T`, transitively: a node behind such a `Z`'s own
eof-target is in the family too (the third case's `exit`, `done` and `fin`). Every
such `Z` gains `unreachable-node`; nothing else does. Not in the family, and why:

- `Z = T`, a self-loop — `T` is occupiable through the EOF route, measured on the
  `§16.2:898` gate fixture, a collapsed variant of 0027's machine (effect (b) above).
- `T` a counted consume — `next` is an EOF successor of the node (decision 0030 item
  5), so the walk visits `Z` behind it.
- `T` any zero-width kind — the walk flows through its continuation.
- `Z` reachable by any other route — a byte edge from a byte-reached node, or an EOF
  route the walk takes.

**3. `all-out-targets` is retired.** It has one consumer (Context), and its
retirement leaves `reach-from` with one caller, `byte-reached`. Three mutations name
it or its consequence, decided here by LABEL so Slice ⓪'s plan reconciles rather
than improvises:

- "verify: a sequence node's eof-target does not feed reachability (arm 2,
  all-out-targets)" — its `FIND` is `all-out-targets`' definition. It retires with
  its reason written in its place (`AGENTS.md`: a mutation whose decision a later fix
  subsumes is retired with the reason, never weakened until green); the decision it
  named — that a sequence node's eof-target feeds reachability — is pinned by the new
  group's sequence-dispatch pair (item 5).
- "verify: pass 7's EOF half keeps taking byte edges" — its `REPLACE` rewrites
  `span-flow`'s edge list over `(all-out-targets n)`. Re-shaped to an inline
  equivalent of the retired walk, because an unbound identifier is a raise and not a
  comparison, and `AGENTS.md` prefers the comparison catch.
- "verify: reachability never reports an unreachable node" — its `FIND` is the
  `make-diagnostic 'unreachable-node` site, which does not move. Re-read with its
  `REPLACE`; it stays if its `FIND` survives the edit.

**4. One parked set.** The two hand-written copies become one `parked?` with the
superset membership — `span-end-node?` included — read by `pass-eof-execution`, by
pass 7 and by `occupiable`. The argument that this changes no verdict is a derivation
with a measurement, not a hope:

- *For occupiability*, the disjunct is inert by derivation: a byte-reachable span
  end's `next` is a byte out-edge, already in `byte-reached`, so seeding an EOF walk
  there adds nothing the union does not hold.
- *For pass 7*, the tree derives it inert in `parked?`'s own comment ("seeding an EOF
  walk there would add a duplicate edge to a relation that is joined, not counted"),
  and decision 0030 item 6 records the same derivation for a counted consume's
  `next`.
- *Measured*: the design's semantics review added the disjunct to pass 7's copy under
  the narrowed walk, and `verify-tests.sps`, the matrix and the census answered
  exactly as without it.

And the second derivation the record rests on — that `pass-eof-execution`'s walk,
starting at `parked-eof-start`'s answer, and `span-flow`'s walk, starting at
`eof-step` of the parked node itself, visit the same occupiable set: every name the
first skips — a parked callback's continue and branch targets, a parked counted
consume's `next` — is a byte out-edge of a byte-reached node, so it is in
`byte-reached` already, and whatever lies on its EOF routes is visited by the walk of
the first parked node along them. Both are seeded from the same set, and the union is
one set. Slice ⓪ builds the one procedure; it does not change which nodes
`pass-eof-execution` classifies or where their walks start.

**5. What the three cases assert afterwards**, decided here so Slice ⓪ does not
improvise and no fixture is rewritten to hide the narrowing. Each keeps the property
it tests and gains the narrowing's witness, in a shape the file already has:

- **The `t2-kinds` accept case** collects every code per kind into `bad` today;
  afterwards it collects `(code . node)` pairs — its reject sibling's shape — and
  asserts the whole set: empty for pause, field-action, field-branch, callback and
  counted-consume; exactly `((unreachable-node . fin))` for byte-dispatch,
  sequence-dispatch and integer-accumulate. A derived set, three kinds — the same
  three item 2 names — and the case's `§16.2:908` property, no `non-eof-into-finish`
  for any kind, stands.
- **The join case** is a `check-equal` on the whole list and asserts
  `((unreachable-node . rj2) (eof-reachable-stop . s0))`.
- **The 0029 item 3 case** asserts no span code and `unreachable-node` at each of
  `cl`, `exit`, `done` and `fin`.

Plus, in a new group, the family's canonical pair for each of the three kinds — `Z`
distinct and dead, REJECTED with the node named; the same machine with `Z` also
reachable by a byte edge from the entry, ACCEPTED — and the two ACCEPTED controls
item 2 names: the self-loop, and `Z` behind a counted consume's `next`.

## Consequences

- **What does not change.** `byte-reached` and every `§16.2:908`/`:909` verdict;
  pass 7's domain (0027 item 1 already); `pass-zero-progress`'s gate — `byte-reached`
  alone, not the composite, for 0027 item 3's reason, which stands: `§16.2` states
  `:898` and `:908` as two bullets, and the EOF-only half already has its owner in
  `eof-terminal`'s `cycle`; the code `unreachable-node` and its single emission site;
  the census row `(unreachable-node 1)`; the matrix's pruning count 3. Every
  executable lane stays green because no executable fixture holds a dead node —
  measured by the prototype, re-taken by Slice ⓪.
- **0023's "three machine families become legal" survives as a `:908` verdict, not as
  the clean verification its second Consequence promised.** A byte edge from an
  EOF-only-reachable node into a finish is still not a `:908` violation; for the three
  kinds whose byte edges are dead at EOF, that finish is a dead node under `:897`
  unless it has another route. Two rules, two bullets, both true of the same machine —
  so the sentence "They carry accept-side fixtures, because 'verifies clean' is what
  the defect looked like" is false for those three kinds, and 0023's second
  Consequence is **amended** by a dated note with a site marker (Milestone 7 Gate 0).
  Its third Consequence stays true and is **annotated**, because it would otherwise
  read as current.
- **0027's "Handed to nobody: `pass-reachability`" is now false** — it is handed to
  Slice ⓪ under this record — and is **amended** by a dated note with a site marker
  (Milestone 7 Gate 0). Milestone 6's design §8 bullet, a record in a closed design,
  gets a dated note indexed in that document's Amendments block. Nothing is
  rewritten.
- **Handed to Slice ⓪, by shape.** *The verdict change is exactly the three cases*:
  on the unmodified tests, re-taken at the slice's own base commit, the release
  selection minus the mutation lane fails at the three named cases and nowhere else.
  *Nothing else moved*: the census row, the pruning count, every executable lane,
  every golden byte-identical. *Both ends written*: `pass-reachability`'s note in
  `verify.sls` corrected in place — an instruction — to say what the pass walks, that
  this record decided it, and that item 2's family is the verdict change; the
  parent's `§25:1611` hand-off annotated, as a record, with the corrected accounting
  — one file, three cases, effects (b) and (c) absent. New pins: `occupiable` mutated
  back to the retired walk, caught by the family's REJECTED fixtures going green; the
  unified `parked?` losing each disjunct in turn, each caught by the case that
  disjunct's kind already has.
- **`reexec-targets`' `§12.7:772` citation is corrected in passing by Slice ⓪**,
  which edits `verify.sls` anyway — the sentence is `:773` (Context). Decision 0030's
  Context carries the same citation and is annotated by Milestone 7 Gate 0's note.
- **Not decided here.** A path in the `unreachable-node` diagnostic — decision 0032
  assigns it none, because a finding about a place has no path to give; warning
  severity for dead nodes (`§16.4:947` defers the policy); any change to which nodes
  are *parkable*, which 0027's Slice ③ note records as a different question with no
  derived answer.
