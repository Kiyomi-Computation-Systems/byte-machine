# 0036: An error node is per span state, not per error code

Date: 2026-09-12
Status: accepted
Milestone: 8, Gate 0 (milestone-8-design.md §4.3)

## Context

Decided against `main` at `bf6e56d`; `src/` and `test/` byte-identical to `741e0ca` (0034's
Context).

**The verifier construct this rests on, read at `bf6e56d`.** Decision
[0029](./0029-span-state-is-a-lattice.md) — "Span state is a lattice; disagreement at a merge point
is a diagnostic" — fixes the abstract domain `pass-spans` computes as a **flat lattice of height
two** over `{none, (active s), …}`, so a join of any two distinct elements is `⊤`: joining
`(active a)` with `(active b)` is refused exactly as joining `(active a)` with `none` is.

**What the design measured (P1a, at `741e0ca`; reproduces at `bf6e56d`).** A single `reject` error
node reached **both** from inside the header-name span and from after it was closed is refused by
`pass-spans` as **`inconsistent-span-state`**. This is not a prototype artefact; it is the shipped
verifier enforcing decision 0029.

**Why the refusal is real, not incidental.** `§14`'s span retention rules are stated *per span*: a
sink reached with different spans open has no single answer to "which span was active when the error
was reported". Pass 7 refusing the shared sink is refusing a genuine ambiguity, not a fixture
mistake.

## Decision

**1. The fixture declares one error node per (code × span state it is reachable in), all naming one
error *declaration* per code.** The reported `parser-error-code` and reason are therefore **per
code**, as `§21.4` requires, while the graph satisfies pass 7: no error node is reached with two
different span states open. *Rejected, with the failure it would cause*: one shared sink per code —
`pass-spans` refuses it as `inconsistent-span-state` the moment two regions with different open
spans route to it, and the first slice that tries the sharing rediscovers this mid-task as a
verifier failure.

**2. `unexpected-eof` needs one error node per region whose EOF route it serves.** It is reachable
from every non-idle region (0037), so on the order of **ten** nodes, all naming one
`unexpected-eof` declaration. The lexical rejections (`invalid-method`, `invalid-target`, …) are
each raised from inside their own region and mostly need one node each.

**3. This is recorded as the shape it is, not as a workaround.** Pass 7 is enforcing a real
invariant (Context); the duplication a reader sees in the machine is the price of a per-code report
under a per-span domain, and this record is the reason kept at hand.

## Consequences

- **Handed to every slice that raises an error** (①–⑤): budget one error node per (code × open-span
  state), and never share a sink across regions with different open spans. Slice ③'s framing errors,
  Slice ④'s chunk and trailer errors, and Slice ⑤'s per-region `unexpected-eof` witnesses all pay
  this.
- **Interlocks with 0037**: the per-region `unexpected-eof` nodes are the same nodes the default-eof
  declaration names; idle is the one region whose EOF route goes to the finish terminal instead.
- **A mutation pin** wherever a slice could collapse two per-state nodes into one, asserting the
  `inconsistent-span-state` signature rather than a bare nonzero exit.
