# 0016: Normalized state-id allocation — declared nodes keep their index, internal states append

Date: 2026-08-29
Status: accepted
Milestone: 3, Gate 0 (milestone-3-design.md §4.3)

## Context

Parent §17:955 makes normalization "resolve symbolic names to stable numeric IDs"
without saying how they are assigned. In the shipped normalizer they are assigned
implicitly: one counter walks the machine's declared nodes to build the
name-to-id table, and the same counter builds the states vector, so a state's id,
its position in that vector, and its index in the source declaration list all
coincide. `test/common/normal-ir-tests.sps` asserts that coincidence as a
contract — "state ids are the declaration indices" — and **no decision record
states the rule**.

Milestone 3 breaks the coincidence. Lowered sequence-prefix states (decision 0015)
have no source declaration, so an identity defined in terms of the declaration
list no longer covers every state. The choice is externally observable: state ids
feed the IR fingerprint of decision 0009 and the order of the emitted `case` arms.

## Decision

1. **Two-phase append.** Every declared source node keeps its declaration index as
   its id. Internal prefix states are assigned ids after the entire declared block,
   ordered by (declaring-node order, then prefix-structure pre-order, taking each
   prefix state's children in ascending byte order). The child rule is what makes
   the pre-order total: without it a prefix state with two or more children admits
   several pre-orders, and as the Context says the choice is externally observable
   through the IR fingerprint and the order of the emitted `case` arms, so it is
   pinned here rather than left to whatever order the lowering happens to build.
2. **Sequence-free machines are unaffected, byte for byte.** Name resolution
   resolves names, and the encoder walks the states vector positionally without
   ever writing a state's own id, so a machine with no sequence node normalizes and
   encodes exactly as it did before Milestone 3.
3. **Within-node prefix sharing is in scope; cross-node sharing is not.** Two
   alternatives of the *same* sequence node share their common nonterminal prefix
   states: §10.6:544 permits sequences to share nonterminal prefixes, and
   §11.3:648's prohibition on rewind or backtracking leaves no way to honor that
   permission except by merging the shared bytes into common states. Two
   *different* sequence nodes never share prefix states, even for identical byte
   runs.

## Consequences

- Interleaving — giving each sequence node's prefix states ids immediately after
  it — was rejected. It renumbers every later node and moves the fingerprint of
  every machine containing a sequence, for no benefit.
- **Lowered prefix states must likewise carry at most one transition per byte, and
  decision point 3 is what establishes it.** Decision 0014's Consequences rest the
  normalizer's ascending-by-byte sort on that property, and warrant it with the
  overlap check — which is filtered on byte-dispatch nodes and walks *source*
  byte-cases, so it never sees a lowered prefix state and cannot be the warrant
  here. Within-node prefix sharing supplies one: alternatives that agree on a byte
  descend into a single shared child rather than into two sibling states, so no
  prefix state can offer the same byte twice and the sort key cannot tie there
  either. Lowering each alternative as its own chain would break it — two
  alternatives differing only after a common first byte would put two transitions
  on that byte out of one state, and `list-sort` stability would silently pick a
  winner, which is §25:1539's determinism criterion lost to an implementation
  detail. This is why decision point 3's sharing is not a size optimization that
  could be deferred: it is load-bearing for determinism, and the milestone's
  slicing lands it with the sequence node kind for that reason
  (milestone-3-design.md §6).
- **The test that asserts the old contract is amended by this decision, not by a
  routine test update.** Milestone 3 Slice ② rewrites
  `normal-ir-tests.sps`'s "state ids are the declaration indices" case to state the
  two-phase rule. In a diff that edit looks like ordinary test maintenance; it is
  the application of this record, and the commit that makes it should cite 0016.
- Cross-node sharing is excluded for two independent reasons: it would make
  §17:963's state-ID-to-source-name debug map non-functional, since one state would
  answer to two source nodes; and as a pure size optimization it falls under
  §23.3's admission rule, which cannot be satisfied yet.
- Decision 0009's fingerprint is left in place for every machine that could be
  expressed before Milestone 3. Machines containing a sequence node are new, so
  they have no prior fingerprint to move.
