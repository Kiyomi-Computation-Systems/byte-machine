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
   ordered by (declaring-node order, then prefix-structure pre-order).
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
