# 0017: Degenerate matcher and sequence shapes are constructor contract violations

Date: 2026-08-29
Status: accepted
Milestone: 3, Gate 0 (milestone-3-design.md §4.4)

## Context

Milestone 3's new constructors admit shapes the parent plan never discusses: an
empty byte set; a range with `low > high`; a range with `low = high`; the
complement of a full-universe matcher; a duplicate byte inside one byte-set
matcher; an empty sequence; a length-1 sequence; duplicate alternatives in one
sequence node.

The plan gives no domain constraints beyond "complement within `0..255`"
(§9.1:294). §16.2's list of required checks — an itemized enumeration with no
open-ended qualifier — has **no** invalid-matcher entry at all; its only matcher
bullet is overlap (§16.2:893) and its only sequence bullet is ambiguity
(§16.2:894). So a matcher-validity *diagnostic* would be an addition to that
list, while §9.1:322 says constructors validate only local shape and that
cross-reference and semantic checks belong to verification.

One of these shapes is load-bearing rather than merely untidy. An empty sequence
is the only shape that makes a sequence node zero-width, which contradicts
§11.4:652's classification of sequence-prefix states as input-dependent, and it is
the only way lowered prefix states themselves can enter a zero-progress cycle.

## Decision

1. **Rejected at construction, as local shape:** an empty byte set; a byte range
   with `low > high`; an empty sequence. Each is a contract violation from its
   constructor, following the precedent of the shipped exact-byte matcher's own
   range check.
2. **Legal:** `low = high` (a redundant but well-formed exact byte); a length-1
   sequence (degenerate but well-formed); the complement of a full-universe
   matcher, which canonicalizes to the empty set of *transitions* on a node whose
   fallback then takes every byte — a vacuous case, not a malformed one.
3. **Duplicate bytes within one byte-set matcher are not a constructor error.**
   They are resolved by canonicalization. Sorting or de-duplicating at construction
   would be a construction-time semantic transform, which §9.1:322 forbids and
   §9.1:318's "deterministic caller order" assumes away.
4. **§16.2's check list gains no invalid-matcher bullet.** Overlap
   (§16.2:893) and sequence ambiguity (§16.2:894) remain its only entries in this
   area, and both stay verifier work.

## Consequences

- **Prefix-level zero-progress analysis is removed from Milestone 3's Slice ③
  entirely.** With empty sequences unconstructable, every admissible sequence
  advances, so the §25:1533 cycle extension reduces to the source-level case of a
  mismatch edge reexecuting into its own node. The verifier never needs the
  lowered graph for this: the mismatch edge is a source-level field and every
  prefix state inherits the source node's single EOF edge (§12.4:727), so
  §17:951's verify-before-normalize ordering is never approached.
- Callers lose the ability to accumulate a diagnostic for these three shapes
  alongside other diagnostics; they get a raised condition at the offending
  constructor instead. That is the existing trade for every local-shape error in
  the construction API, and it is accepted here for consistency rather than
  re-litigated per constructor.
- A vacuous complement (decision point 2) is legal and therefore reachable. It is
  not a verifier error, and any future warning about it belongs to the deferred
  warning policy, not to Milestone 3.
