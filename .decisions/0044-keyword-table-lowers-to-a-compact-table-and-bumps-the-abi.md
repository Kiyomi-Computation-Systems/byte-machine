# 0044: The keyword table lowers to a compact table, and the generated ABI goes 5→6

Date: 2026-09-13
Status: accepted
Milestone: 11, Gate 0 (milestone-11-design.md §4.2)

## Context

Decided against `main` at `e9f8d9c`. Re-measured at the rebased base if Milestone
10 (empty-span, v0.2.0) lands first (milestone-11-design.md §4.6).

**What the parent plan constrains.** `§17:957` and `§19.2:1010` fix that *sequence*
alternatives lower to resumable prefix states; they say nothing about a table
lowering. `§28:1711-1713` — "generated code becomes too large" — mitigates with
"measure source/native size, keep normalization simple, and admit compact tables
**only with representative evidence**." `§9.5:444` — the generated ABI "may change
before `1.0.0` only with a generated-ABI version bump, deterministic regeneration,
and a changelog entry." `§20:1043` fixes the fingerprint over "canonical normalized
IR and emission options."

**What the shipped sequence lowering does, and why it is the wrong model here.**
`normal-ir.sls`'s `seq-state` lowers a sequence node to a trie of ordinary
`dispatch` states (decision 0015 items 1-2), one per distinct prefix. Measured
(prototype P2, milestone-11-design.md §3.2): the 47-name method table built that
way is **242 trie nodes / 105 054 emitted bytes** — reproducing the brief §3's 242
exactly. The brief is explicit (§6, §9) that lowering the keyword table this way
"has moved the problem rather than solved it." So the keyword table must lower to a
**table the runtime walks**, not to states.

**The ABI, measured.** `current-abi-version` is **5** (`runtime.sls:85`), the guard
`(= abi-version current-abi-version)` is strict equality (`runtime.sls:115`),
`current-abi-members` is **3** (`runtime.sls:90`), and the emitter writes the
literal `5` into every generated constructor call (`compile.sls:707`). The six
determinism goldens carry that literal on their last line beside the machine's
fingerprint (`test/fixtures/`). The concurrent Milestone 10 keeps the ABI at 5
(its decision 0042 item 3), so a 5→6 bump here is clean in either merge order.

## Decision

**1. A new normalized state kind `keyword-table`, carrying the trie as an embedded
deterministic datum — not one `dispatch` state per prefix.** The datum is a vector
of trie nodes; each node is an ascending `(byte . child-index)` transition list
plus an optional terminal target-id, and the table carries its case-insensitivity
flag (decision 0045). The keyword-table node lowers to **one** normalized state
(plus the embedded datum), so the state-id→source-name table does not gain a state
per prefix. This is the "admit a compact table with representative evidence"
`§28:1713` permits, the evidence being the brief's 242-node measurement.

**2. The generated executor emits the datum inline and calls a new runtime op that
walks it, and the op is resumable.** On running out of input mid-table the op
returns `need-input`, storing "mid-table at trie node *k*" in the parser's opaque
`current`; the next feed resumes there. This is decision 0015's cross-feed
resumability relocated from dispatch prefix states into the op — the runtime treats
`current` as opaque (0015 Consequences), so a compound value flows through feed,
`need-input`, finish and reset untouched.

**3. `current-abi-version` goes 5→6, and the emitted literal moves with it.**
`§9.5:444` requires exactly this for a generated-ABI change, and the generated code
now depends on a runtime binding that did not exist — an old runtime loading a new
keyword-table library must fail with the portable ABI-mismatch condition, not an
unbound-identifier error. The consumer asserts the ABI by reading it out of emitted
text (brief §8), so the bump surfaces loudly. `current-abi-members` **stays 3**:
the trie lives in the emitted state datum, not the compiled-machine metadata
payload, so no payload member is added (contrast decision 0025, which grew the
payload). This is a version bump only.

**4. The oracle is two-sided, exactly as decision 0025's was.** *Forward — the six
goldens re-baseline*: the ABI literal `5`→`6` is on every generated constructor
call, so all six move (a one-character change on the last line), and the ~21
ABI/fingerprint pin sites move with them. This is the deliberate re-baseline the
brief §6 names. *Backward — the fingerprints do not move*: the encoding gains
coverage of the trie datum only for keyword-table states, so a machine that
declares no keyword table encodes byte-identically and its fingerprint is unchanged
from `main` — asserted, not assumed. A fingerprint that moves for a
no-keyword-table machine means the encoding changed when it should not have.

## Consequences

- **The re-baseline is one commit, in Slice ①, alongside the feature** — not a bare
  seam slice ahead of it. Decision 0025's own execution note is the warrant: a
  change that writes bytes for machines the feature does not touch (the ABI literal
  does) is paid where the feature lands, and a bump with no op to justify it would
  be reserved-unused scaffolding no input reaches.
- **The compact lowering's emitted size is a measured exit criterion, not a
  claim.** Brief §7 criterion 7 — 47-keyword size ≪ the 242-node equivalent — is
  measured through a registered lane in Slice ③, both shapes emitted, the
  before/after byte and node counts recorded beside the assertion. The 105 054-byte
  "before" is P2's and is re-measured through the lane, never copied
  (AGENTS.md, *"a number from a throwaway driver describes the driver"*).
- **The emitter gains a `keyword-table` arm and the normalizer a state kind**, so
  the "thirteen normalized state kinds" census in `normal-ir.sls:220-226` and
  `compile.sls:494-498` becomes fourteen. This is the census seam
  (milestone-11-design.md §4.5); the totality rows are the backstop.
- **A seventh determinism golden** renders the new emitter arm, on the rule that
  each golden exists to render an arm no other golden contains
  (`test/CMakeLists.txt` accumulate/counted precedent). It needs its own
  `determinism.*` lane pair and `BYTE_MACHINE_*_GOLDEN_FILE` env var.
- **Resumability across feeds must be witnessed**, not assumed — a keyword split by
  a feed boundary resumes and matches identically to the unsplit feed, in both
  lanes and over `§22.5`'s schedules, and the mutant that drops the stored
  trie-position is caught by a failed comparison, not a raise.
