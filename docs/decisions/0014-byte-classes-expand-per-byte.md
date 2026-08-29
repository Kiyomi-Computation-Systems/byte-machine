# 0014: Byte classes expand to per-byte normalized transitions

Date: 2026-08-29
Status: accepted
Milestone: 3, Gate 0 (milestone-3-design.md §4.1)

## Context

Milestone 3 adds byte sets, ranges and complements to a byte-dispatch node that
until now accepts only exact-byte matchers (`private/ir.sls`
`make-exact-byte-matcher`, and `make-byte-case`'s guard, which rejects every
other matcher form). Parent §10.6:538 says matchers "denote subsets of the closed
byte universe `0..255`" and that "complements are canonicalized against that
universe before overlap analysis", and §17:956 makes normalization "lower byte
ranges and classes to canonical byte sets". Neither says how a canonical byte set
is *represented in normalized IR*, and that representation decides whether the
committed goldens and the IR fingerprint of decision 0009 move.

The shipped normalizer emits one `(byte target-id mode)` triple per byte-case and
sorts ascending by byte; the encoder writes a `u16be` transition count followed by
`u8 byte, u32be target, u8 mode` per transition. The emitter renders one
single-datum `case` arm per transition. A grouped or set-valued transition would
change all three.

## Decision

1. **A byte set, range or complement is canonicalized to a subset of `0..255` and
   lowered to one normalized transition per byte.** Canonicalization is recursive
   over complements (§9.1:294 complements a *matcher*, not a byte list), and an
   exact-byte matcher is the one-element case of the same function.
2. **Normalized IR gains no grouped or set-valued transition, and its encoding
   gains no new arm.** The `u16be` transition count already admits 256. The
   encoding-format version byte is unchanged.
3. **The emitter is unchanged.** A complement renders up to 256 sibling arms
   inside the existing single `case`. §19.2:1009 requires "canonical membership
   code selected for simplicity, not speculative density optimization", and this
   is that reading.
4. **No class table, transition table, or membership bitmap in v0.1.** A 256-entry
   vector lookup for class membership *is* a class table. §29:1743 defers
   transition and class tables; §23.3:1369 gates them behind reproducible compiled
   benchmarks in both lanes; and §23.3:1380 additionally requires a decision record
   deriving "material improvement" from observed baseline variance *before the
   first optimization is admitted*. `bench/` contains only `.gitkeep` files, so no
   such evidence exists and none can be manufactured inside this milestone.

## Consequences

- **The IR fingerprint does not move, and neither do the goldens.** Per-byte
  expansion is a strict no-op on the shipped layout: every machine expressible
  before Milestone 3 encodes identically after it. Decision 0009's fingerprint
  therefore stands unamended, and the three pinned fingerprints, both committed
  goldens, and the derived mutant fingerprints in the mutation suite stay valid and
  keep witnessing the encoding. Milestone 3 Slice ① asserts this as its own gate:
  the canonicalization spine lands *before* any new matcher kind exists, so
  byte-identical output is a real check rather than a re-baseline.
- A dispatch node carrying a complement can reach 256 transitions. That is
  accepted output size, not a defect to optimize around; §17:966 asks for "the
  simplest correct execution graph".
- The normalizer's ascending-by-byte sort remains a **total** order, because the
  overlap check still guarantees no two cases of one node share a byte. This is
  load-bearing: a grouped sort key that could tie would make emission depend on
  `list-sort` stability, and emission determinism is a Milestone 3 exit criterion
  (§25:1539).
- Density optimization is not forbidden forever — it is deferred behind §23.3.
  Whoever revisits it must first supply the §23.3:1380 baseline-variance record.
