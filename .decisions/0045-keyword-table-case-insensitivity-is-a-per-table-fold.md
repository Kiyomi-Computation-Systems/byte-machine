# 0045: Keyword-table case-insensitivity is a per-table ASCII fold with collision rejection

Date: 2026-09-13
Status: accepted
Milestone: 11, Gate 0 (milestone-11-design.md §4.3)

## Context

Decided against `main` at `e9f8d9c`; re-measured at the rebased base if Milestone
10 lands first (milestone-11-design.md §4.6).

**What the downstream brief needs, both halves measured by the consumer.** HTTP
field names are case-insensitive (RFC 9110 §5.1), and so are the `Connection` and
`Transfer-Encoding` values that drive framing; the request method is
case-**sensitive** (RFC 9110 §9.1). So case-insensitivity is genuinely per table,
not global — one machine holds both a case-sensitive method table and
case-insensitive header tables. The workaround the consumer ships today for the
insensitive half is decision 0035's byte-set chain: one dispatch node per grammar
character whose matcher is the two-byte set of that character's cases — 52 nodes
for four header names.

**Why a flag on `make-sequence-case` is refused** (brief §4). It would close the
case-insensitive half and leave the method table impossible, because it inherits
`sequence-dispatch`'s prefix rejection (`verify.sls`'s `pass-sequence-ambiguity`) —
strictly less capable than the hand trie a consumer can already build, which is not
worth shipping.

## Decision

**1. `case-insensitive?` is a boolean property of the *table*** — a field on
`make-keyword-table-node` (decision 0043), not of each `keyword-entry` and not a
separate construct. This is the granularity the two consumers need: per table.

**2. When true, an ASCII letter matches either case; a byte with no case matches
only itself.** Folding is `A..Z` ↔ `a..z` and nothing else — the portable-ASCII
world `§10.1:480` fixes for names and the grammar the consumer targets. Bytes are
the universe (`0..255`), so a keyword byte out of range cannot arise, and folding
never leaves it.

**3. The verifier rejects a table whose keywords collide under folding.** Two
entries equal after case-folding (for example `GET` and `get` in one
case-insensitive table) are refused with a new diagnostic — the folded-collision
analogue of the exact-duplicate rejection decision 0043 gives the case-sensitive
table. Without this a folded collision would make the trie walk's terminal choice
ambiguous, the very ambiguity the case-sensitive pass rejects.

**4. Both executors fold independently.** The interpreter's trie walker and the
runtime's walk op each implement the fold; neither shares a helper with the
normalizer (decision 0015's independence rule), so a fold defect in one lane is a
differential result, not a hidden agreement.

**5. The flag is fingerprint-visible.** Two tables differing only in
`case-insensitive?` compile to different parsers and must differ in fingerprint
(decision 0044 item 4's encoding coverage; the declaration-identity principle
decision 0025 records). A case-insensitive table and a case-sensitive one over the
same keywords are not the same machine.

## Consequences

- **Slice ② owns this** (milestone-11-design.md §6): the fold in both executors,
  the `case-insensitive-keyword-collision` diagnostic with its catalog entry and
  census pin, and a differential lane over the brief §2b header shape —
  `Content-Length` / `content-length` / `cOnTeNt-LeNgTh` recognized to one target,
  a case-sensitive table refusing the mixed case, both lanes.
- **The collision rejection is a new diagnostic code**, so
  `.reference/verifier-diagnostic-catalog.md` and `diagnostic-census-tests.sps`
  gain it and their code-count literals move (the diagnostic-census totality row is
  the backstop, AGENTS.md's derived-census rule).
- **The fold is asserted, not the agreement.** A mutation that folds the wrong
  direction, or only one case, or drops the collision check, is caught by an
  expected-value comparison (a mixed-case name that must hit, and two colliding
  entries that must be refused by name) — never by a bare nonzero exit and never by
  two lanes agreeing on a wrong fold (AGENTS.md, *"A fix that makes two lanes agree
  can disarm the test"*).
