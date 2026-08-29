# Milestone 3 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as durable records, the four design calls Milestone 3 depends on — per-byte expansion of byte classes, sequence lowering into ordinary dispatch prefix states together with the independently derived interpreter representation, normalized state-id allocation, and degenerate matcher/sequence shapes as constructor contract violations — so every later slice cites a decision instead of re-deriving it.

**Architecture:** This phase writes and edits *documentation only* — no product code, no tests, no CMake. It produces four new decision records (0014–0017) and adds minimal in-place citation clauses to the parent plan. It is the prerequisite for all three M3 slices: Slice ① consumes 0014 and 0017, Slice ② consumes 0015, 0016 and 0017, Slice ③ consumes 0015 and 0017. No slice may begin before its records exist, because each record's Consequences section is what removes work from the slice that would otherwise be re-derived (0017 in particular removes an entire analysis from Slice ③).

**Tech Stack:** Markdown, `rg`, git. No Scheme, no CMake.

## Global Constraints

- Decision records follow the repo format: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 3, Gate 0 (milestone-3-design.md §N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. See `docs/decisions/0011-eof-execution-model.md` and `docs/decisions/0012-generated-abi-v2-finish.md` for the house style.
- The next free decision number is **0014** (last is `docs/decisions/0013-runtime-coded-conditions.md`). Confirm with `ls docs/decisions/` before writing; if a higher number exists, use the next free numbers in order and renumber the cross-references between these four records to match.
- **Record vs instruction discipline (AGENTS.md:157-165).** A *record* (a measurement, a finding, a decision's Context, a prior decision record) gets a dated amendment note appended, never a rewrite. An *instruction* (a work-order, an exit criterion, a Deliver/Scope entry, a normative spec sentence, or a live comment saying what code is for) is corrected in place. The parent plan's §9.1/§17/§19.2 sentences touched here are **normative-spec instructions** → add minimal in-place citation clauses only where a reader would otherwise re-derive, never rewrite the surrounding prose.
- **Do NOT amend decision 0009.** Records 0014 and 0016 are both designed so the IR fingerprint and the normalized encoding do **not** move. 0009 is neither falsified nor extended by them, so it takes no dated amendment; each record states the no-move guarantee in its own Consequences instead. Adding an amendment to 0009 that says "nothing changed" is noise, and it would make a future reader hunt for a change that does not exist.
- **Citation staleness (AGENTS.md, project memory).** Before editing any parent-plan sentence, `rg` for it and read the surrounding lines to confirm the *current* wording at HEAD. Do not trust the quoted "current text" in this plan as exact — line numbers and phrasing drift, and this plan's own line numbers were measured at `7955a4d`.
- **No code, no counts.** Gate 0 changes no `.sls`, no CMake, no test. It quotes and moves **no measured totals**: `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (38/165 today) are not touched, quoted as predictions, or forecast. The matcher constructors, the sequence node kind, the verifier arms, the lowering and the id allocation are described as *obligations handed to the slices*, not performed here.
- **The design document is the source of text.** Each record below is the durable form of a `milestone-3-design.md` §4 subsection. Where this plan and the design differ, re-read the design and reconcile before writing; do not silently prefer one.
- Conventional Commits. One decision (plus the citation clauses it forces) per commit.
- `.superpowers/sdd/` is git-ignored; nothing there is committed. All artifacts here live under `docs/`.

> **Amended 2026-08-29.** Five verification steps below (Tasks 1–4's final
> "Verify and self-review" step, and Task 5's Step 4) asserted that
> `milestone-3-design.md`'s §10 References section would name the newly
> written decision records (0014–0017); that was never true. §10 catalogues
> the design's antecedent decisions (0009–0012) and Gate 0 never touches it —
> the record numbers land in §4 instead, via the mapping blockquote Task 5's
> Step 2 adds. The five steps are corrected in place below; this note is the
> record of the error, not the correction.

---

## Task 1: Decision 0014 — byte classes expand to per-byte transitions

**Files:**
- Create: `docs/decisions/0014-byte-classes-expand-per-byte.md`
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§19.2's byte-sets bullet) — minimal citation clause only

**Interfaces:**
- Produces: the settled contract "a byte set, range or complement canonicalizes to a subset of `0..255` and lowers to one normalized transition per byte; normalized IR gains no grouped or set-valued transition and its encoding gains no new arm; the IR fingerprint and both goldens do not move." Slice ①'s normalizer-lowering and emitter-confirm tasks consume this, and its no-move guarantee is Slice ①'s Task-1 gate.

- [ ] **Step 1: Confirm the decision number and read all the targets**

Run:
```bash
ls docs/decisions/
rg -n "canonical membership code|lower byte ranges and classes|speculative performance transformations|simplest correct execution graph" docs/plans/byte-machine-implementation-plan.md
rg -n "transition tables or class tables|sequence/trie specialization" docs/plans/byte-machine-implementation-plan.md
rg -n "Transition tables, byte-class tables|material improvement" docs/plans/byte-machine-implementation-plan.md
```
Expected: `0013-...md` is the highest-numbered record (so 0014 is free); the first `rg` prints §17's canonical-byte-sets bullet, §19.2's byte-sets bullet and §17's no-speculative-transformations paragraph; the second prints §29's two deferral bullets; the third prints §23.3's admission rule and its decision-record precondition. Read ~6 lines around each hit — the record rests on all four sites jointly, and any one of them alone is a weaker warrant.

- [ ] **Step 2: Confirm the benchmark precondition really is unmet**

Run:
```bash
ls -la bench/
find bench -type f | sort
```
Expected: only `.gitkeep` files. This is load-bearing: §23.3 gates class tables behind reproducible compiled benchmarks, and the record asserts that no such evidence *can* exist yet. If `bench/` has acquired real benchmarks since this plan was written, stop and re-derive the warrant before writing the record — the argument changes.

- [ ] **Step 3: Write the decision record**

Create `docs/decisions/0014-byte-classes-expand-per-byte.md`:

```markdown
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
```

- [ ] **Step 4: Add a minimal citation clause to the parent plan**

At §19.2's byte-sets bullet — currently `- Byte sets: canonical membership code selected for simplicity, not speculative density optimization.` — append a single clause so it reads:

```
- Byte sets: canonical membership code selected for simplicity, not speculative density optimization (Milestone 3 lowers them to one transition per byte, leaving the encoding and the IR fingerprint in place — decision 0014).
```

Single clause; do not rewrite the bullet or its neighbours, and do not touch §17, §29 or §23.3 — the record cites them, which is enough.

- [ ] **Step 5: Verify cross-references resolve and self-review**

Run:
```bash
rg -n "0014" docs/decisions/ docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-3-design.md
rg -n "EXPECTED_PASSES|EXPECTED_MUTATIONS|38/165|165 mutations" docs/decisions/0014-byte-classes-expand-per-byte.md
```
Expected: the first prints the new record and the §19.2 clause; its only hit inside the design document is §4's pre-existing "expected 0014–0017" placeholder — an incidental number match, not a citation, since neither §4.1 nor §10 names the record yet (§4's mapping arrives only in Task 5, and §10 never gains one at all — it continues to catalogue only the design's antecedent decisions 0009–0012). The second prints **nothing** — Gate 0 quotes no measured totals. Confirm the record cites §19.2:1009, §29:1743, §23.3:1369 and §23.3:1380 as a *joint* warrant rather than resting on one; confirm decision 0009 was **not** amended. Fix inline.

- [ ] **Step 6: Commit**

```bash
git add docs/decisions/0014-byte-classes-expand-per-byte.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0014 — byte classes expand to per-byte normalized transitions"
```

---

## Task 2: Decision 0015 — sequence lowering and the independently derived interpreter representation

**Files:**
- Create: `docs/decisions/0015-sequence-prefix-states.md`
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§19.2's sequences bullet) — minimal citation clause only

**Interfaces:**
- Consumes: decision 0014's canonicalization vocabulary (a prefix state's single-byte test is the one-element canonical set).
- Produces: the settled contract "a lowered prefix state is an ordinary normalized `dispatch` state — no new tag, no emitter arm, no ABI change; the reference interpreter represents prefix position as a compound `current` derived independently of the normalizer; a mid-sequence boundary is `need-input`, never `paused`; a mid-sequence pause cannot arise." Slice ②'s lowering, interpreter and emitter-confirm tasks and Slice ③'s ambiguity-rejection task consume this.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "resumable prefix states|explicit resumable prefix states|lower sequence alternatives" docs/plans/byte-machine-implementation-plan.md
rg -n "must not call the normalizer|derived independently from the production normalizer" docs/plans/byte-machine-implementation-plan.md
rg -n "Lowered states inside a sequence inherit" docs/plans/byte-machine-implementation-plan.md
rg -n "symbol\?" src/byte-machine/runtime.sls
rg -n "parser-set-current!|parser-set-lifecycle!" src/byte-machine/runtime.sls
```
Expected: the first prints §10.6:546, §17:957 and §19.2:1010 — three sites all saying "resumable prefix states"; the second prints §18:970 and §18:972; the third prints §12.4:727. The fourth `rg` must print **nothing**: `runtime.sls` never inspects `current`, which is the fact that makes a compound value free. If it prints anything, stop — the record's central Consequence is false and must be re-derived. The fifth shows the sites that store `current` and set the lifecycle; read enough to confirm `parser-reset!` restores `current` from the entry slot.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0015-sequence-prefix-states.md`:

```markdown
# 0015: Sequence lowering — ordinary dispatch prefix states, and an independently derived interpreter representation

Date: 2026-08-29
Status: accepted
Milestone: 3, Gate 0 (milestone-3-design.md §4.2)

## Context

Sequence dispatch is the sixth node kind in parent §10.6's closed set, and the
first Milestone 3 adds. §10.6:546, §17:957 and §19.2:1010 all say the compiler
lowers sequence alternatives into "resumable prefix states" without saying what a
prefix state *is* in normalized IR. Separately, §18:970 forbids the reference
interpreter from calling the normalizer or executing normalized IR, and §18:972
permits interpreter-private progress state inside a high-level source node — "such
as a sequence prefix" — but requires that representation be "derived independently
from the production normalizer".

These are one decision, not two. The interpreter≡generated differential is the
only mechanism that can catch incorrect sequence lowering (§18:970 says so
explicitly), and it can only do that if the two implementations are genuinely
independent. Deciding the normalized representation without simultaneously
deciding — and constraining — the interpreter's invites the natural refactor that
destroys the property: factoring "the shared prefix walker" into a common library.

## Decision

1. **A lowered prefix state is an ordinary normalized `dispatch` state.** No new
   state kind, no new encoding tag, no new emitter arm, and the encoding-format
   version byte is unchanged. A resumable byte-reading state is precisely what the
   shipped dispatch state already is, and the shipped need-input resume point
   therefore gives cross-feed resumability with no new mechanism.
2. **This is possible only because ambiguous terminal prefixes are rejected**
   (§10.6:544). That rejection guarantees every prefix state is either
   interior-with-children or a leaf, so none needs an "accept here" slot — which
   the shipped normalized state does not have. The rejection rule and this lowering
   are the same decision seen twice; changing either silently breaks the other.
3. **The reference interpreter represents "inside sequence *s* at prefix position
   *k*" as a compound `current` value.** It is derived independently of the
   normalizer, which is automatic rather than aspirational: `interpret.sls` imports
   no normalizer library, and this decision forbids introducing such an import or a
   shared prefix-walking helper for the purpose.
4. **Interpreter prefix state may not be closed over the compiled machine.** One
   compiled machine serves arbitrarily many parsers, so prefix progress lives in
   the parser's own `current`, never in a closure created at
   machine-construction time.
5. **A mid-sequence feed boundary returns `need-input`, never `paused`.** The two
   have different lifecycle consequences: `need-input` leaves the lifecycle
   `ready` for a direct further feed, while `paused` sets `paused-feed` and makes a
   further `parser-feed!` a contract violation until `parser-resume!`.
6. **A mid-sequence pause cannot arise, and no protocol for one is designed.**
   Every source edge target is a *declared* node name, and prefix positions have no
   declared names, so no source construct can route a pause into the middle of a
   sequence.

## Consequences

- **No `runtime.sls` change and no `/v3` ABI.** The runtime treats `current` as
  fully opaque — it never tests it, only stores it or hands it to the executor —
  and `parser-reset!` restores it from the entry slot, so a compound value flows
  through feed, `need-input`, finish and reset untouched. The `/v2` contract
  mentions no node kind; decision 0012 item 3 established that new behaviour rides
  on new status symbols rather than a new `feed-outcome` record, and the executor
  state the ABI carries is opaque, so new state ids need no ABI surface at all.
- The interpreter's node lookup and node-kind dispatch must learn to destructure a
  compound `current`; today they match node names by identity and raise a contract
  violation on anything else. That is the whole of the interpreter change *this
  representation choice* forces — not the whole of Milestone 3's interpreter work:
  Slice ② must also add sequence byte matching, prefix advance and mismatch
  routing to `interpret.sls`, and Slice ① separately rewrites its matcher dispatch
  onto the canonical byte set of decision 0014.
- **EOF discards prefix position, and that is correct.** §12.4:727 makes every
  lowered prefix state inherit the source sequence state's EOF edge, and decision
  0011 lets that chain terminate at a pause. At that point `current` parks on the
  pause's continuation and the prefix position is gone. EOF never returns to bytes
  — from `finish-ready` a `parser-feed!` is a contract violation — so nothing can
  observe the loss. An implementation must not assume byte matching resumes
  afterwards.
- Because the interpreter and the normalizer implement prefix matching twice, a
  divergence between them is a *test result*, not a merge conflict. Reviewers
  should treat a proposal to share the walker as a change to this decision.
```

- [ ] **Step 3: Add a minimal citation clause to the parent plan**

At §19.2's sequences bullet — currently `- Sequences: explicit resumable prefix states.` — append a single clause so it reads:

```
- Sequences: explicit resumable prefix states (ordinary dispatch states, with the interpreter's own prefix representation derived independently — decision 0015).
```

Single clause; do not rewrite. Do not add a clause at §18 — §18:970-972 is already explicit and a citation there would only restate it.

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "0015" docs/decisions/ docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-3-design.md
rg -n "v3|/v3" docs/decisions/0015-sequence-prefix-states.md
```
Expected: the first prints the record and the §19.2 clause; it finds nothing in the design document — unlike 0014's coincidental placeholder match, "0015" is not even a substring of §4's "expected 0014–0017" placeholder, so neither §4.2 nor §10 shows a hit, and §10 never gains one at all, continuing to catalogue only the design's antecedent decisions 0009–0012. The second prints only the sentence ruling `/v3` out — confirm the record does not accidentally *propose* one. Confirm the record states decision points 3 and 4 as constraints on the interpreter (not merely a description), since those are what preserve the differential's power. Fix inline.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/0015-sequence-prefix-states.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0015 — sequence prefix states are ordinary dispatch states, interpreter derives its own"
```

---

## Task 3: Decision 0016 — normalized state-id allocation is two-phase append

**Files:**
- Create: `docs/decisions/0016-normalized-state-id-allocation.md`
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§17's stable-numeric-IDs bullet) — minimal citation clause only

**Interfaces:**
- Consumes: decision 0015 (prefix states exist and are dispatch states, so they need ids).
- Produces: the settled contract "source nodes keep their declaration index; internal prefix states are appended after the declared block, ordered by declaring-node order then prefix-structure pre-order with each state's children taken in ascending byte order; within-node prefix sharing is in scope, cross-node sharing is not." Slice ②'s id-allocation task consumes this, and the test amendment it forces is named here so it is not mistaken for a routine test edit.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "resolve symbolic names to stable numeric IDs|state-ID-to-source-name" docs/plans/byte-machine-implementation-plan.md
rg -n "state ids are the declaration indices" test/common/normal-ir-tests.sps
rg -n "name->id|id-of|list->vector" src/byte-machine/private/normal-ir.sls
rg -n "0016|declaration index" docs/decisions/
```
Expected: the first prints §17:955 and §17:963; the second prints the harness case asserting the id contract — read it and the ~8 lines after it, because that assertion is what this decision changes; the third shows the counter that makes id, vector position and declaration index coincide today; the fourth prints **nothing**, confirming no record states the rule yet. That absence is the reason this record exists.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0016-normalized-state-id-allocation.md`:

```markdown
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
```

- [ ] **Step 3: Add a minimal citation clause to the parent plan**

At §17's stable-numeric-IDs bullet — currently `- resolve symbolic names to stable numeric IDs;` — append a single clause so it reads:

```
- resolve symbolic names to stable numeric IDs (declared nodes keep their declaration index; internal states append after them — decision 0016);
```

Single clause; do not rewrite. Leave §17:963's debug-map bullet alone — 0016 cites it, and Milestone 3 does not build it.

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "0016" docs/decisions/ docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-3-design.md
rg -n "declaration indices" test/common/normal-ir-tests.sps
```
Expected: the first prints the record and the §17 clause; it finds nothing in the design document — "0016" is not a substring of §4's "expected 0014–0017" placeholder either, so neither §4.3 nor §10 shows a hit, and §10 never gains one at all, continuing to catalogue only the design's antecedent decisions 0009–0012. The second still prints the **unmodified** test — Gate 0 changes no test; the record only *names* the amendment Slice ② will make. If the test has changed, Gate 0 has overstepped; revert the test and keep the record. Fix inline.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/0016-normalized-state-id-allocation.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0016 — normalized state ids, declared nodes keep their index and internal states append"
```

---

## Task 4: Decision 0017 — degenerate matcher and sequence shapes are constructor contract violations

**Files:**
- Create: `docs/decisions/0017-degenerate-shapes-are-contract-violations.md`
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§9.1's constructor-validation sentence) — minimal citation clause only

**Interfaces:**
- Consumes: decision 0014 (canonicalization is where duplicate bytes go).
- Produces: the settled contract "an empty byte set, a range with `low > high`, and an empty sequence are constructor contract violations; `low = high` and length-1 sequences are legal; duplicate bytes within one set are resolved by canonicalization, not rejected; §16.2's check list gains no invalid-matcher bullet." Slice ①'s constructor task and Slice ③'s cycle-analysis task consume this — the latter is *shrunk* by it.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "Constructors validate only local shape|deterministic caller order" docs/plans/byte-machine-implementation-plan.md
rg -n "duplicate or overlapping exact-byte|sequence ambiguities after prefix analysis" docs/plans/byte-machine-implementation-plan.md
rg -n "do not consume input|input-dependent" docs/plans/byte-machine-implementation-plan.md
rg -n "make-exact-byte-matcher" src/byte-machine/private/ir.sls
```
Expected: the first prints §9.1:322 and §9.1:318; the second prints §16.2's only two matcher/sequence bullets — read the whole check list and confirm for yourself that it contains **no** "invalid matcher" entry, because the record asserts that absence; the third prints §11.4:652, which classifies sequence-prefix states as input-dependent; the fourth shows the shipped local range check that is this decision's precedent.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0017-degenerate-shapes-are-contract-violations.md`:

```markdown
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
4. **Duplicate alternatives, or any alternatives that are otherwise
   mutually-ambiguous, within one sequence node are not a constructor error
   either, and §16.2's check list gains no invalid-matcher bullet.** Overlap
   (§16.2:893) and sequence ambiguity (§16.2:894) remain its only entries in
   this area, and both stay verifier work. Whether two alternatives collide is
   a cross-case property, not the local shape of either one — exactly parallel
   to how overlap between two byte-cases of one dispatch node is verifier work
   rather than constructor work (§9.1:322) — and two identical alternatives
   are only the maximal instance of the ambiguity §16.2:894 already requires
   the verifier to reject, so the check that catches them is Slice ③'s
   existing work, not a new rule. Alternatives that merely *share* bytes
   without either being a terminal prefix of the other — `AB` and `AC` — are
   not ambiguous, and they are left to no check at all: the trie-shaped
   lowering merges their shared prefix into one state, which is why that
   lowering is not deferrable past the slice that adds the node kind
   (decision 0016 point 3, milestone-3-design.md §6).

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
```

- [ ] **Step 3: Add a minimal citation clause to the parent plan**

At §9.1's constructor-validation sentence — currently beginning `Constructors validate only local shape and return immutable-by-API descriptors.` — append a single clause to that first sentence so it reads:

```
Constructors validate only local shape and return immutable-by-API descriptors (from Milestone 3 that validation includes rejecting an empty byte set, a range with `low > high`, and an empty sequence — decision 0017).
```

Single clause; do not rewrite the rest of the paragraph, and do **not** add anything to §16.2 — the record's fourth decision point is precisely that §16.2 stays as it is.

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "0017" docs/decisions/ docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-3-design.md
git diff HEAD~1 -- docs/plans/byte-machine-implementation-plan.md
```
Expected: the first prints the record and the §9.1 clause; its only hit inside the design document is §4's pre-existing "expected 0014–0017" placeholder — an incidental number match, not a citation, since neither §4.4 nor §10 names the record yet (§4's mapping arrives only in Task 5, and §10 never gains one at all — it continues to catalogue only the design's antecedent decisions 0009–0012). The second must show a change to §9.1 **only** — if §16.2 was touched, the edit contradicts decision point 4; revert it. Confirm the record states the empty-sequence consequence explicitly, since that is what Slice ③'s scope now rests on. Fix inline.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/0017-degenerate-shapes-are-contract-violations.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0017 — degenerate matcher and sequence shapes are constructor contract violations"
```

---

## Task 5: Close Gate 0 in the design document

**Files:**
- Modify: `docs/plans/milestone-3-design.md` (§4 preamble, and §9's first bullet)

**Interfaces:**
- Consumes: all four records from Tasks 1–4.
- Produces: a design document whose §4 names the assigned record numbers, so Slices ①–③ cite numbers rather than section references.

- [ ] **Step 1: Confirm all four records exist and carry the expected numbers**

Run:
```bash
ls docs/decisions/
rg -n "^# 001[4-7]:" docs/decisions/
```
Expected: exactly four new records, `0014`–`0017`, with the titles from Tasks 1–4. If the numbers differ from this plan (because a record landed from another branch), note the actual numbers and use them consistently in Step 2.

- [ ] **Step 2: Replace §4's number placeholder with the assigned numbers**

In `docs/plans/milestone-3-design.md` §4, the preamble currently reads that writing-plans "assigns the record numbers (next free in `docs/decisions/`, expected 0014–0017)". Replace `expected 0014–0017` with the assigned range and add the per-subsection mapping, so a reader of §4.1 knows it is 0014 without counting. Add one dated line recording that Gate 0 is discharged:

```
> **Gate 0 discharged 2026-08-29.** §4.1 → decision 0014, §4.2 → 0015,
> §4.3 → 0016, §4.4 → 0017. §4.5's two resolutions stayed in this document by
> design and have no record.
```

This is a *record* of what was decided, appended — not a rewrite of §4's argument.

- [ ] **Step 3: Update §9's first bullet**

§9's first bullet currently hands writing-plans the four record forms and asks it to confirm whether §4.2 should split. Append the outcome, so a later reader does not re-open a settled question:

```
  **Resolved:** §4.2 stayed one record (0015). Splitting it would separate the
  normalized representation from the interpreter constraint that makes the
  differential meaningful, which is the mistake §3 warns about.
```

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "0014|0015|0016|0017" docs/plans/milestone-3-design.md
rg -n "expected 0014" docs/plans/milestone-3-design.md
```
Expected: the first shows §4's mapping naming all four numbers and §9's resolution naming 0015; §10 contributes no hits at all — Gate 0 never touches it, and it continues to catalogue only the design's antecedent decisions 0009–0012, not the new records. The second prints **nothing** — the placeholder is gone. Fix inline.

- [ ] **Step 5: Commit**

```bash
git add docs/plans/milestone-3-design.md
git commit -m "docs: discharge Milestone 3 Gate 0 — map design §4 to decisions 0014-0017"
```

---

## Self-Review (run after all five tasks)

1. **Spec coverage:** `milestone-3-design.md` §4 lists four resolutions requiring records (§4.1 per-byte expansion, §4.2 sequence lowering + interpreter representation, §4.3 state-id allocation, §4.4 degenerate shapes) plus §4.5's two in-document resolutions. Task 1 ↔ §4.1, Task 2 ↔ §4.2, Task 3 ↔ §4.3, Task 4 ↔ §4.4, Task 5 closes the loop. §4.5 deliberately gets no record — the design says so, and Task 5 Step 2 states it. The design's §9 also hands *proving machines*, *mutation pin re-anchoring*, *lane bookkeeping*, *completion sentinels* and *sizing* to writing-plans, but those are Slice-①/②/③ plan concerns, not Gate 0 (decisions only). Covered.
2. **Placeholder scan:** every date is the literal `2026-08-29`; every record body is complete decision text; every `rg` has a stated expected result. No "TBD", no "similar to Task N", no "add appropriate handling". The only conditional is Task 5 Step 1's instruction for a number collision, which is a real branch, not a placeholder.
3. **Consistency across records:** 0014 and 0016 both assert the fingerprint does not move — 0014 for the encoding layout, 0016 for id assignment — and neither amends 0009; that division is stated in both. 0015 depends on §10.6:544's ambiguity rejection and says so; 0017 shrinks Slice ③'s cycle analysis and says so; and 0017's canonicalization-handles-duplicates point matches 0014's canonicalization function rather than inventing a second one. The four records use one vocabulary: *canonical byte set*, *prefix state*, *declared node*, *internal state*.
4. **Record vs instruction:** parent-plan §19.2 (twice), §17 and §9.1 get single citation clauses at surveyed sites, never rewrites; §16.2 is deliberately untouched (0017 decision point 4) and Task 4 Step 4 checks that; decision 0009 is deliberately unamended and Task 1 Step 5 checks that; `milestone-3-design.md` §4/§9 get *appended* dated notes. Correct.
5. **No counts:** Task 1 Step 5 greps for measured totals and expects no hits. No task touches `SchemeMutationSuite.cmake`, any `.sls`, any `.sps`, or any CMake file. Gate 0 is docs-only, and Task 3 Step 4 verifies the one test it names is still unmodified.
