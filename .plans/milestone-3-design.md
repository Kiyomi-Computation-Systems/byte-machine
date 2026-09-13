# Milestone 3 Design — Byte Classes and Sequences

Status: **MILESTONE 3 CLOSED 2026-08-30.** Gate 0 discharged; **Slice ① (byte
classes) closed 2026-08-29**, merged as PR
[#30](https://github.com/Kiyomi-Computation-Systems/byte-machine/pull/30)
(`7d6ef3d`); **Slice ② (sequence dispatch and prefix lowering) closed
2026-08-30**, merged as PR
[#33](https://github.com/Kiyomi-Computation-Systems/byte-machine/pull/33)
(`819a5b1`); **Slice ③ (multiple alternatives, ambiguity, and cycle analysis)
closed 2026-08-30 and closes the milestone with it** (every commit on branch
`feat/milestone-3-slice-3` since it diverged from `main` at merge base
`49c8cc4`, including this note's own commit; PR not yet opened as of this
note). The three slices together discharge §5's, §6's and §7's scope — each
with its own dated disposition below — and the **milestone's** exit criteria
are dispositioned per criterion in the "Exit (full Milestone 3)" block that
follows §7, which the parent plan's §25 close note cites rather than restates.
Authored 2026-08-29, the day Milestone 2 closed
(PR [#23](https://github.com/Kiyomi-Computation-Systems/byte-machine/pull/23),
commit `5906ade`; status sweep PRs #24–#27). Written after a 92-agent audit of
this milestone's requirements against the shipped tree, in which every gap claim
sized medium or larger was independently adversarially refuted before being
admitted as work; the refutation pass removed roughly two thirds of the claimed
scope, most of it as *already shipped by M1/M2* or as *another milestone's*.

> **Amended 2026-08-29.** Three citation errors, found during Gate 0 execution
> after this design was approved, are corrected in the body below rather than
> left standing; this note is the record of the errors, not the correction. §8
> (Explicitly out of Milestone 3) attributed a "new status symbols and new state
> ids, not a new record" rule to "Decision 0010 item 4 / 0012" — 0012 item 3 says
> only that `paused`/`finished` are new status *symbols*, not a new
> `feed-outcome` record, and says nothing about state ids; 0010 item 4 is the
> general extend-by-version seam, not this rule (fixed by `87e8520`). §10
> (References)'s decision-0012 entry repeated the same mischaracterization,
> crediting item 3 with "new statuses and state ids" (fixed by `9ffc193`). §4.4
> (Degenerate matcher and sequence shapes are constructor contract violations)
> claimed the parent plan "calls" §16.2's required-checks list "closed"; the plan
> never says so — it calls only §10.6's node-kind set closed
> (`byte-machine-implementation-plan.md:534`) (fixed by `3f8cd1b`).

> **Amended 2026-08-29 (second amendment).** The Slice ②/③ boundary moved, after
> a whole-branch review found that Slice ② as originally scoped would accept and
> silently miscompile a multi-alternative sequence node. §6 scoped the lowering as
> "linear prefix lowering (no sharing yet)" while `make-sequence-dispatch-node`
> takes a plural `cases` list (§9.1:297) with local-shape validation only, and
> decision 0017 point 4 leaves colliding alternatives to the verifier. Two
> alternatives sharing a first byte — `AB` and `AC` — would therefore construct,
> verify clean, and lower to two transitions on that byte out of one state; the
> normalizer's ascending-by-byte sort key ties there, `list-sort` stability
> silently picks a winner, and the losing alternative goes dead with nothing
> failing. `AB` and `AC` are not *ambiguous* — ambiguity is one alternative being
> a terminal prefix of another — so Slice ③'s ambiguous-terminal-prefix check
> would not have caught it either; shared-prefix (trie) lowering is what does. The
> owner approved moving trie-shaped lowering into Slice ②, where a one-alternative
> trie *is* a linear chain, so the slice grows by a tree construction rather than
> by a new concept and keeps the same `sequence-machine.sls` oracle; Slice ③ keeps
> the multi-alternative fixtures, ambiguity rejection, the cycle extension, the
> determinism pins and the `HTTP/1.0`⁄`HTTP/1.1` fixture. §1's phase table and
> dependency paragraph, §6, §7 and the appendix are corrected in the body below;
> this note is the record of what moved and why, not the correction. The status
> line above was corrected in the same pass — it read "**not started**" while §4's
> blockquote recorded Gate 0 discharged.

Governing plan: [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
§25 ("Milestone 3: Byte classes and sequences"), scope §25:1527-1533, exit
criteria §25:1537-1540. This document does not change M3's *scope*; it re-cuts M3
*internally* into an ordered Gate 0 plus three slices and resolves the design
calls the parent plan leaves open. Where this document and §25 differ in wording,
§25's Scope list remains authoritative and this document records how that scope
is sequenced and delivered.

## 1. Summary

Milestone 2 turned a single-shot accept into a parser with a lifecycle: arbitrary
slices, exact offsets, EOF, pause/resume, reset, and the full reachable operation
matrix, all over a machine built from **exact-byte** transitions only. The
proving surface reached four chained dispatch nodes
(`test/support/harness/byte-machine/test/sequence-machine.sls`).

Milestone 3 widens what a transition can *match*. It is two very unequal halves
resting on one closed-set spine:

- **Byte classes** are a *matcher* change that the existing byte-dispatch node
  absorbs whole. Three constructors plus `ascii-bytes` (§9.1:292-294, :299), a
  widened `make-byte-case` guard, one canonicalization step, and a rewritten
  overlap pass. No new node kind, no new encoding, no ABI movement.
- **Sequence dispatch** is the **sixth node kind** in a repertoire closed at five
  (`private/ir.sls:141-149`). It must be threaded through all seven shipped
  modules, and it brings the milestone's only genuinely new analysis: prefix
  lowering, ambiguity rejection, and the cycle extension.

M3 is one milestone delivered as an ordered Gate 0 plus three slices:

| Phase | Kind | Produces | Discharges |
| --- | --- | --- | --- |
| **Gate 0** | decisions only | 4 records | the calls §25, §10.6 and §16.2 leave open |
| **Slice ① — Byte classes** | product | canonicalization spine; `make-byte-set-matcher` / `make-byte-range-matcher` / `make-byte-complement-matcher` / `ascii-bytes`; rewritten overlap pass; per-byte lowering; all-256 class lanes | §25:1527-1528, exit :1537 |
| **Slice ② — Sequence dispatch and prefix lowering** | product | the sixth node kind and every verifier arm; trie-shaped prefix lowering; state-id allocation; independent interpreter tracking; both mismatch modes | §25:1530-1531 and the single-alternative half of :1529, exit :1538, and the Slice ② half of exit :1539 |
| **Slice ③ — Multiple alternatives and ambiguity** | product | multi-alternative fixtures over Slice ②'s trie; ambiguous-terminal-prefix rejection; the **zero-progress** half of the cycle extension (:1533's EOF-cycle half shipped in Slice ②); determinism pins; the `HTTP/1.0`⁄`HTTP/1.1` fixture | the multi-alternative half of §25:1529, plus :1532 and the zero-progress half of :1533, the Slice ③ half of exit :1539, and exit :1540 |

Dependency order is strict. Gate 0 unblocks everything. Slice ① is purely
additive to the normalized encoding, so it can assert *no fingerprint moved* as
its own oracle. Slice ② lands the node kind and the trie-shaped lowering, and is
validated against a machine already on `main`. Slice ③ adds the milestone's
remaining new analysis — ambiguous-terminal-prefix rejection and the
zero-progress half of the cycle extension — together with the first lanes that
drive more than one alternative end to end through **both** executors. That last
clause is deliberately narrow, and was narrowed by measurement during Slice ③'s
execution: Slice ② had already pinned the trie merge structurally in
`normal-ir-tests.sps` and executed `AB`/`AC` through the interpreter in
`interpret-tests.sps`, so what ③ adds over it is the **differential** across a
branch, a seven-byte shared prefix, absolute tuples, and both mismatch modes.
Every slice runs in **both execution lanes** and is checked by the
**interpreter≡generated differential** (parent §18, §22.4).

## 2. Why this shape

Read literally, §25 M3 lands canonical byte sets, overlap verification, sequence
alternatives, prefix normalization, mismatch positioning, ambiguity rejection,
and a cycle-analysis extension all at once. Two facts about the shipped tree
argue for cutting it differently.

**The two halves are not the same size.** Byte classes never leave the
byte-dispatch node; sequences add a node kind. Fusing them into one slice would
hide a small, fully-verifiable change inside a large one.

**Milestone 3 is unusually poor in independent oracles, and the slicing can
manufacture two.** `determinism-one-byte-tests.sps` compares the emitter against
a file the emitter itself produced; if state numbering or the encoding moves,
goldens and fingerprints are regenerated *from the code under test* in one step,
and the only surviving check is the differential — which compares behaviour and
deliberately does not compare state ids (§12.7:777). So:

- Slice ① is behaviour-preserving at its riskiest point. The canonicalization
  spine lands *before* any new matcher kind exists, which means the three pinned
  IR fingerprints (`normal-ir-tests.sps:66,115,140`) and both committed goldens
  must come out **byte-identical**. That is a real independent oracle, and it is
  the only one in the milestone that does not depend on the code under test.
- Slice ② proves the new node kind against a machine already on `main`. A
  single-alternative sequence matching `1 2 3 4` must reproduce
  `sequence-machine.sls` — four *chained dispatch nodes* — exactly: all eight
  cut-sets, the seeded 32-schedule multi-split, nonzero-offset and empty slices,
  and every mismatch position, against the `(status next consumed stream-offset)`
  tuples already pinned in `differential-sequence-tests.sps:118-201`. The
  construct is new; the expected behaviour is not, and it was measured by a
  different mechanism.

Splitting M3 into more than one milestone was considered and rejected for the
same reason M1 and M2 were not split: every milestone is a vertical slice that
generates and executes code, and the roadmap numbering (M3–M9) stays fixed.

Splitting the sequence half at the **pipeline seam** (interpreter first, then
generation — M1's Phase-2/Phase-3 shape) was considered and rejected. It would
deliberately leave `main` in a state where a constructible source machine cannot
be compiled, requiring a designed, tested refusal that the following slice then
deletes; and it would separate the ambiguous-prefix rule from the lowering that
justifies it. Those are the same decision seen twice (§4.2), and reviewing them
in different pull requests is how one silently drifts from the other.

## 3. What the parent plan already settles

Recorded here so it is not re-litigated during implementation. None of the
following is an open design call.

- **The public construction surface is fixed by §9.1:291-299**, including two
  asymmetries that look like mistakes and are not. The four matcher constructors
  take **no `source-label`** — uniquely among §9.1's constructors — and the
  shipped `make-exact-byte-matcher` correctly has arity 1. And
  `make-sequence-dispatch-node` carries a full mismatch **edge** while
  `make-sequence-case` carries a bare **target**, because a successful sequence
  always consumes every byte (§10.6:546); giving a sequence case an
  advance/reexecute mode would reintroduce the lookahead §10.6:546 forbids.
- **`make-byte-complement-matcher` complements a *matcher*, not a byte list**
  (§9.1:294), so complements nest and canonicalization is recursive.
- **The interpreter may not share the normalizer's lowering** (§18:970-972). Its
  prefix tracking must be *derived independently*. Sequence matching is written
  twice on purpose; that independence is exactly what lets the differential catch
  incorrect sequence lowering. An implementation that factors "the shared prefix
  walker" into a common library defeats the milestone's main safety property.
- **Every lowered prefix state inherits the source sequence state's EOF edge**
  (§12.4:727), and sequence-prefix states are **input-dependent** (§11.4:652).
- **There is no general rewind or backtracking** (§11.3:648). Peeking at a
  delimiter is a one-byte dispatch with a reexecute edge (§10.6:546).
- **Overlap and sequence ambiguity are two separate required checks**
  (§16.2:893 and §16.2:894), and matcher canonicalization plus byte-set overlap
  analysis is a named verification pass (§16.3:921).

## 4. Gate 0 — design-call resolutions

Decision-only. No product code is written in Gate 0. writing-plans assigns the
record numbers (next free in `.decisions/`, assigned 0014–0017) and confirms
whether any splits or merges of the four below are warranted.

> **Gate 0 discharged 2026-08-29.** §4.1 → decision
> [0014](../.decisions/0014-byte-classes-expand-per-byte.md), §4.2 →
> [0015](../.decisions/0015-sequence-prefix-states.md), §4.3 →
> [0016](../.decisions/0016-normalized-state-id-allocation.md), §4.4 →
> [0017](../.decisions/0017-degenerate-shapes-are-contract-violations.md). §4.5's
> two resolutions stayed in this document by design and have no record.

### 4.1 Byte classes expand to per-byte transitions

**Resolution.** A byte set, range or complement is canonicalized to a subset of
`0..255` and lowered to **one normalized transition per byte**. Normalized IR
gains no grouped or set-valued transition, and its encoding gains no new arm.

**Why.** §19.2:1009 requires "canonical membership code selected for simplicity,
not speculative density optimization"; §17:966 forbids speculative
transformations and demands "the simplest correct execution graph"; §29:1743
defers transition and class tables, and §23.3:1369 gates them behind reproducible
compiled benchmarks that **cannot exist yet** — `bench/` contains two `.gitkeep`
files, and §23.3:1380 additionally requires a decision record deriving "material
improvement" from observed baseline variance *before* the first optimization is
admitted. A 256-entry vector lookup for class membership *is* a class table.

**Consequences.** `normal-ir.sls:101-106` builds one `(byte target-id mode)`
triple per case and sorts ascending by byte; `:138-142` encodes `u16be count`
then `u8 byte, u32be target, u8 mode` per transition. Per-byte expansion is a
strict no-op on that layout: every existing machine encodes identically, so all
three pinned fingerprints, both goldens, `compile-tests.sps:163` and `:212`, and
the four derived mutant fingerprints at `SchemeMutationSuite.cmake:3310,3317,
3324,3357` stay valid and keep witnessing the encoding. The `u16be` count already
admits 256. `compile.sls:80-83` (`render-transition-arm`, hard-coded to a
one-element datum list) needs **no change**, and a complement renders up to 256
sibling arms inside the single `(case b ...)` at `compile.sls:114-117`, which
§19.2:1009 explicitly sanctions.

**Caveat to carry into implementation.** The shipped `list-sort` at
`normal-ir.sls:101` is a *total* order only because `pass-overlap` guarantees no
two cases share a byte. Any grouped sort key that can tie would make emission
depend on `list-sort` stability. Per-byte expansion preserves the guarantee.

### 4.2 Sequence lowering: ordinary dispatch prefix states, and an independently derived interpreter representation

**Resolution.** One record, because §18:970-972 makes these one decision.

- A lowered prefix state is an **ordinary normalized `dispatch` state**. No tag 5,
  no new emitter arm, no ABI change, and the encoding-format version byte at
  `normal-ir.sls:129` stays 1.
- The reference interpreter represents "inside sequence *s* at prefix position
  *k*" as a **compound `current`** value, `(s . k)`.

> **Amended 2026-08-30 (Task 6 close-out; Slice ② closed).** This
> illustration's `(s . k)` — a prefix **position index** — is a measured
> design defect, not merely superseded prose. Counterexample: alternatives
> `AB` and `XY` on one sequence node. After consuming `A`, a position index
> records only "position 1"; asked "is there an alternative with position 1
> reached", it finds `XY` does (byte `Y` at index 1) and follows it —
> accepting the byte pair `A` then `Y`, a sequence that appears on neither
> alternative and was never on the input. A position index cannot
> distinguish "which alternative(s) are still live" from "how far along am
> I", and mismatch detection needs the former. The shipped representation is
> the **consumed byte path** instead: `(name . path)`, where `path` is the
> exact bytes read so far (`interpret.sls`'s `seq-step`, the sole producer of
> the compound form — Task 3, commit `c4a2039`). Measured directly:
> `interpret-tests.sps`'s "A then Y mismatches rather than following the XY
> alternative" case feeds `AB`/`XY` the bytes `A` then `Y` and checks two
> things — the result's status is `'error` (`car`, not an accept) and its
> offset is `1` (`cadddr`) — not the full five-field tuple
> `(error 0 0 1 unexpected-byte)` as an earlier version of this amendment
> described; the case never compares one. Both checks still discriminate the
> exact failure this amendment's counterexample predicts if `path` were
> replaced by a bare position, so the conclusion stands on the two checks the
> case actually makes. Decision 0015 needs no matching amendment: point 3
> says only "a compound `current` value" and never names `(s . k)` or any
> other concrete shape, so it was never wrong — this design section's
> illustration was.

**Why (lowering).** §10.6:546, §17:957 and §19.2:1010 all say "resumable prefix
states", and a resumable byte-reading state *is* the shipped dispatch state. The
rejection of ambiguous **terminal** prefixes (§10.6:544) is what makes this
possible: it guarantees every prefix state is either interior-with-children or a
leaf, so none needs an "accept here" slot — which the shipped `normal-state`
(`normal-ir.sls:31-44`) does not have. The need-input resume point at
`compile.sls:110-113` then gives cross-feed resumability for free.

**Why (interpreter).** `runtime.sls` treats `current` as fully opaque: there is
no `symbol?` test anywhere in the file, all sites either store it or hand it to
the executor, and `parser-reset!` clears it at `:331`. A compound value therefore
flows through feed, `need-input`, finish and reset with **zero `runtime.sls`
change**. It is independent of the normalizer by construction, since
`interpret.sls` imports no normalizer library.

**Consequences.** `interpret.sls`'s `lookup` (`:15-18`) matches node names with
`eq?` and returns `#f` for a pair, and `kind` (`:32-39`) then raises a contract
violation; both must be taught to destructure. **Reject any design that closes
mutable prefix state over `make-interpreted-machine`**: one compiled machine
serves arbitrarily many parsers (`interpret.sls:24-31`, `runtime.sls:109-123`),
so that state would be shared across them and no shipped test would catch it.

**Two corollaries that prevent designed-for-nothing work.** A mid-sequence
**pause cannot arise** — every source edge target is a *declared* node name and
prefix positions have none — so no mid-sequence pause-resumption protocol should
be designed. And a mid-sequence feed boundary is **`need-input`, not `paused`**:
different statuses with different lifecycle consequences, since `need-input`
returns *without touching the lifecycle at all* (`runtime.sls:190`), leaving it
`ready` for a direct further feed, while `paused` sets `paused-feed`
(`runtime.sls:163`) and `:146` then makes a further `parser-feed!` a contract
violation until `parser-resume!` restores `ready` (`:319`). M2 already pins the mid-chain need-input shape
at `differential-sequence-tests.sps:196-201`. Conflating the two is the classic
error here.

**Not this milestone's problem, recorded so it is not mistaken for one.** §12.4's
EOF chain may terminate at a pause (`paused-finish`, `runtime.sls:289-292`), at
which point `current` parks on the pause's continuation and the prefix position
is discarded. That is correct — EOF never returns to bytes, and from
`finish-ready` a `parser-feed!` is a contract violation — but an implementation
must not assume byte matching can resume afterwards.

### 4.3 Normalized state-id allocation: two-phase append

**Resolution.** Source nodes keep their declaration index. Internal prefix states
are **appended after the declared block**, ordered by (declaring-node order,
prefix-structure pre-order). Within-node prefix sharing is in scope; **cross-node
sharing is not**.

**Why.** `normal-ir.sls:76-79` builds `name->id` by walking `machine-nodes` with a
counter, and `:93-97` builds the states vector with the same counter, so id,
vector position and declaration index coincide today. Prefix states have no
source declaration, so that identity must be extended. Appending keeps every
declared node's id — `id-of` resolves *names*, and `encode-normal` never writes a
state's own id, walking positionally at `:131-134` — so **sequence-free machines
encode identically**. Interleaving would renumber every later node and move every
fingerprint in any machine containing a sequence. Cross-node sharing would make
the §17:963 state-ID-to-source-name debug map non-functional (one state, two
source nodes) and is a §23.3-gated size optimization regardless.

**Consequences, and the reason this is a record rather than a code comment.**
`normal-ir-tests.sps:41-46` asserts *"state ids are the declaration indices"* as a
contract, and **no decision record states that rule today**. Amending that test is
this decision being applied — it will otherwise read in the diff as a routine
test update. The record states the id rule for the first time.

### 4.4 Degenerate matcher and sequence shapes are constructor contract violations

**Resolution.** `make-byte-set-matcher` rejects an empty byte list;
`make-byte-range-matcher` rejects `low > high`; `make-sequence-case` rejects an
empty byte list. `low = high` remains legal (a redundant but well-formed exact
byte), and length-1 sequences remain legal (degenerate but well-formed).
Duplicate bytes inside one byte-set matcher are **not** a constructor error; they
are resolved by canonicalization.

**Why.** §9.1:322 says constructors validate only local shape, and these three
shapes *are* local shape — the precedent is `make-exact-byte-matcher`'s own range
check at `ir.sls:41-44`. §16.2's check list has no "invalid matcher" bullet at
all; its only matcher entry is :893 overlap. So a matcher-validity *diagnostic*
would be an addition to that list, while a constructor check is the shipped
convention. Duplicate bytes are excluded from the constructor because sorting or
de-duplicating at construction would be a construction-time semantic transform,
which §9.1:322 forbids and §9.1:318's "deterministic caller order" assumes away.

**Consequences.** The empty sequence is the load-bearing case: it is the only
shape that makes a sequence node zero-width — contradicting §11.4:652, which
classifies sequence-prefix states as input-dependent — and the only way prefix
states themselves can enter a zero-progress cycle. Rejecting it at construction
**removes prefix-level zero-progress analysis from Slice ③ entirely**, because
every admissible sequence advances.

### 4.5 Two resolutions recorded here, not as decision records

- **Diagnostic codes.** Reuse the shipped `'overlapping-cases` for canonicalized
  byte-set overlap with a broadened message, and add **exactly one** new code for
  ambiguous terminal prefixes (§16.2 lists :893 and :894 separately, so the
  ambiguity code is definitely new). Widening the diagnostic *record* to §16.4's
  seven fields is Milestone 7 (§25:1603). Note that no `source-label` accessor
  exists on any construct except `machine-source-label` (`ir.sls:178`) even though
  every construct stores one — adding labels to diagnostics means writing
  accessors first, which is why it is not attempted here.
- **`ascii-bytes` returns a proper list of exact integers**, not a bytevector.
  §9.1:318's collection rule names `bytes` — the argument of both
  `make-byte-set-matcher` and `make-sequence-case` — as a proper list, so a list
  composes directly with both consumers with no adapter. The plan gives only the
  signature and the rejection rule (§9.1:299) and never states a return type.

## 5. Slice ① — Byte classes

Discharges §25:1527 (canonical byte sets, ranges, complements, ASCII helper) and
§25:1528 (byte-class overlap verification); exit criterion §25:1537 (all-byte
class tests pass).

**Task order is load-bearing, not stylistic.** The milestone's sharpest hazard is
that `exact-byte-matcher-byte` (`ir.sls:46`) is a bare `(vector-ref m 1)` with no
tag check and three direct consumers. Widening `make-byte-case`'s guard
(`ir.sls:61-63`) before fixing them does **not** produce a clean contract
violation: it pulls slot 1 out of the wrong vector and fails far away as a raw
Chez arithmetic error inside `(= byte ...)` or `list-sort`'s `(< (car a) (car b))`.
Worse, `pass-overlap`'s `memv` over a list-valued slot 1 compares by identity,
never reports an overlap and never errors — **the overlap check would appear to
run while silently approving every overlapping byte set.**

1. **Canonicalization spine, behaviour-preserving.** Introduce
   `matcher → canonical byte set over 0..255` (recursive over complements, per
   §10.6:538), add the tag check to `exact-byte-matcher-byte` itself, and replace
   all three consumers: `verify.sls:126` (`pass-overlap`), `normal-ir.sls:103`
   (lowering), `interpret.sls:46` (`(= byte (exact-byte-matcher-byte ...))`).
   Exact-byte is a one-element set, so behaviour is identical.
   **Gate: all three pinned fingerprints and both goldens byte-identical.**
2. **The constructors.** `make-byte-set-matcher`, `make-byte-range-matcher`,
   `make-byte-complement-matcher`, `ascii-bytes`, the widened `make-byte-case`
   guard (a `matcher?` disjunction), and the §4.4 degenerate-shape rejections.
   Export from `graph.sls`, whose export list *and* `only` import list
   (`graph.sls:6-12`) must both be edited. Rider: the facade exports zero
   predicates and accessors today, which is why `graph-tests.sps:5` reaches into
   `(byte-machine private ir)`; adding the new matcher predicates and accessors
   closes that in the same edit.
3. **Rewritten `pass-overlap`** (`verify.sls:119-133`) as canonicalize-then-
   pairwise-disjointness across mixed matcher forms within one dispatch node.
   **One diagnostic per colliding pair, not per byte** — naive per-byte expansion
   turns one overlapping 200-byte class pair into ~200 identical diagnostics
   against §16.4:937-943.
4. **Normalizer lowering** per §4.1, and the emitter: **confirm zero change and
   record that it is zero**, rather than leaving the absence of a diff unexplained.
5. **Interpreter matcher dispatch** through the canonical form.
6. **All-256 class, complement and ASCII lanes** in both executors and both
   execution lanes (§22.7:1301). `ascii-bytes`'s all-byte test asserts
   **rejection** across `0x80-0xFF` — it cannot supply the high half, which is
   `make-byte-range-matcher`'s job.

**Passes that must *not* be touched.** `pass-reachability`'s core walk and
`pass-zero-progress`'s `reaches-self?` are matcher-agnostic: they walk edges and
modes, never matchers. §25:1533's cycle bullet is about sequences, not classes.
An implementer "extending every pass for M3" will edit these for nothing and
break their mutation pins in the process.

**Mutation pins that die in this slice.** `(if (memv b seen)`
(`SchemeMutationSuite.cmake:2967`) is deleted outright by the `pass-overlap`
rewrite. The `pass-zero-progress` guard line is pinned **twice with the same
FIND** (`:2973` and `:3183`), and `SITES` is asserted exactly, so a change in site
count is a hard failure. Re-anchoring is a re-**measurement** of each pin's
failure signature, not a text edit; per AGENTS.md:122-127 the obligation is
recorded by mutation LABEL, not line number.

> **Disposition, 2026-08-29 (Task 7 close-out; Slice ① closed).** §5's own
> work has closed, so per AGENTS.md's "an instruction changes category when
> its work closes" rule, its six numbered items and its two departures below
> are dispositioned here rather than reworded to match what shipped. Each was
> re-checked against the tree, not asserted from memory.
>
> **The six items, each found in the tree:**
>
> 1. **Canonicalization spine.** `matcher-bytes` in
>    `(byte-machine private ir)` is the single canonicalization spine;
>    `exact-byte-matcher-byte` carries the tag guard; `verify.sls`'s
>    `pass-overlap`, `normal-ir.sls`'s lowering, and `interpret.sls`'s
>    membership test all call it. **Gate met**: `4236938459847922092`,
>    `9098559711816935340`, `15725897457025557005` and both committed goldens
>    (`generated-one-byte.golden.sls`, `generated-pause.golden.sls`) are
>    byte-identical on the shipped tree — shown by the cross-commit diff
>    against the branch's merge base, `git diff --stat
>    $(git merge-base main HEAD)..HEAD -- test/fixtures/` (`a9de657..f7d6234`
>    at close-out), empty. (A plain `git status --porcelain` only shows the
>    working tree matches HEAD; it is blind to a golden re-baselined inside a
>    branch commit, which is exactly what this gate exists to catch — the
>    per-task uses of `git status` elsewhere in this plan are fine, since
>    there the surrounding commit is untouched.) Task 1.
> 2. **The constructors.** `make-byte-set-matcher`, `make-byte-range-matcher`,
>    `make-byte-complement-matcher`, `ascii-bytes`, the widened
>    `make-byte-case` guard, and decision 0017's degenerate-shape rejections
>    are exported from `graph.sls`'s `export` and `only` import lists
>    (`graph.sls:12-20`, mirrored at `:22-30`) alongside `matcher?` and the
>    four class predicates/accessors. Task 2.
> 3. **Rewritten `pass-overlap`.** `verify.sls`'s `pass-overlap` is now a thin
>    wrapper over `node-overlaps`, which enumerates each colliding **pair** of
>    cases once via `byte-sets-overlap?` over canonical sets — measured: a
>    200-byte overlapping pair reports one diagnostic, not ~200. Task 3.
> 4. **Normalizer lowering; emitter zero change recorded.** Per-byte lowering
>    is witnessed (range triples, dedup, a 254-byte complement, two
>    interleaved classes, a vacuous complement at 0 transitions, a double
>    complement at 256); `compile.sls` carries a comment at the site recording
>    why the emitter needed no change, confirmed by the complement fixture
>    rendering 254 sibling arms inside its one `(case b ...)`. Tasks 1 and 4.
> 5. **Interpreter matcher dispatch through the canonical form.**
>    `interpret.sls`'s dispatch test is `(memv byte (matcher-bytes
>    (byte-case-matcher (car cs))))`, not a bare `=` against one exact byte.
>    Task 1.
> 6. **All-256 class, complement and ASCII lanes, both executors, both
>    execution lanes.** `byte-machine.unit.byte-class.chez.{source,aot}`
>    (absolute, through the interpreter) and
>    `byte-machine.differential.byte-class.chez.{source,aot}`
>    (interpreter ≡ generated) are all four green on the shipped tree
>    (`release`/`pr` 76/76). Tasks 5 and 6.
>
> **The two places this plan departed from §5, each dispositioned rather than
> corrected, because the work they describe has closed:**
>
> 1. **The `graph-tests.sps:5` rider was wrong when written and stayed wrong.**
>    §5 item 2 claimed "adding the new matcher predicates and accessors
>    closes [`graph-tests.sps:5`'s reach into `(byte-machine private ir)`]
>    in the same edit." On the pre-slice tree, `graph-tests.sps:5` was
>    `(only (byte-machine private ir) machine? machine-entry
>    machine-default-eof-error))` — three **machine** accessors. No matcher
>    predicate or accessor supplies a machine accessor, so widening the
>    façade with matcher exports cannot close that import, and it did not:
>    the shipped `graph-tests.sps` still carries the identical private-`ir`
>    import (now at line 11, below a comment explaining why machine
>    accessors stay private while matcher predicates came through the
>    façade — §9.1 fixes the public construction surface and lists no
>    accessors). The rider conflated "the façade gained matcher exports"
>    with "the one private reach this file has closes," which do not imply
>    each other (§0 D5).
> 2. **The "Mutation pins that die in this slice" list was incomplete.** It
>    named `SchemeMutationSuite.cmake:2967` (`verify.sls`'s
>    `(if (memv b seen)` overlap pin) but not `:3267`
>    (`interpret.sls`'s `(= byte (exact-byte-matcher-byte ...))` dispatch
>    pin), even though Task 1 Step 1 names `interpret.sls`'s exact-byte
>    comparison as one of the three consumers the same canonicalization
>    spine change replaces (§0 D9) — both pins' `FIND` text vanishes from
>    the tree at the same commit, for the same reason. Both needed
>    **re-anchoring** (not literal deletion, despite "dies" and "deleted
>    outright" above): Task 1 Step 9 re-anchored both, shipped as the
>    `verify.sls` mutation now labeled "verify: two cases sharing a byte are
>    never found to overlap" and the `interpret.sls` mutation still labeled
>    "interpret: dispatch matches every byte to the first case," both
>    present and caught on the shipped tree.

## 6. Slice ② — Sequence dispatch and prefix lowering

Discharges §25:1530 (prefix normalization and resumable internal states),
§25:1531 (mismatch positioning), and the single-alternative half of §25:1529;
exit criterion §25:1538 (every sequence split and mismatch position passes).
What stays single-alternative is the *fixture*, not the lowering: the M2 oracle
this slice must reproduce is a single-alternative machine.

**The node kind and every verifier arm land in one commit.** This is the
milestone's second structural hazard: `normal-ir.sls:121` and `compile.sls:122`
both end their node-kind dispatch with an assertion violation and comments saying
a sixth kind must fail loudly. `verify.sls` does the **opposite** at six sites —
`node-out-targets` `(else '())` at `:56`; `all-out-targets`' `byte-dispatch-node?`
conditional at `:58-63`; `reexec-targets` `(else '())` at `:158`; `eof-terminal`
`(else 'unknown)` at `:207`, swallowed by its caller's own `(else '())`; and
`byte-dispatch-node?` filters at `:185`, `:222`, `:236`. A sequence node added to
`ir.sls` but not to `verify.sls` **verifies clean** — targets never
resolution-checked, cycles never detected, EOF chain never walked — and only
crashes later in the normalizer. That is the worst possible failure ordering. The
one exception is reachability: an unextended `all-out-targets` produces a *loud
but false* `'unreachable-node` on every successor only a sequence reaches, which
reads as a user grammar error rather than a verifier gap.

> **Disposition, 2026-08-30 (Task 6 close-out; Slice ② closed).** This
> paragraph's own count was wrong twice over, found by execution rather than
> by re-reading it: it says "six sites" and then enumerates **seven**
> references (`:56`, `:58-63`, `:158`, `:207`, `:185`, `:222`, `:236`); the
> Slice ② implementation plan corrected the prose to "seven" (§0 D2) before
> Task 1 began. Task 1's own review then found an **eighth**: `pass-overlap`
> (§16.2:893 canonical byte-set overlap), which stayed filtering on
> `byte-dispatch-node?` alone when the other seven landed, with no deferral
> note recorded beside it. That non-extension is correct, not a bug —
> cross-alternative sequence collision is §16.2:894 ambiguity, decision 0017
> point 4 assigns it to the verifier, and §7 below assigns the check itself to
> Slice ③, so `pass-overlap` has nothing to enforce yet — but it was
> undocumented in a file whose entire stated hazard, one paragraph above, is
> silent permissiveness. It is now documented in place, at both the file
> header and the pass itself (`verify.sls:8-16`, `:176-180`). A later audit
> for this close-out, enumerating **every** site in `verify.sls` that
> dispatches on node kind — rather than grepping `byte-dispatch-node?`, which
> cannot see a `cond` that dispatches through *other* kind predicates and so
> cannot itself find an omission — confirms **eight** is the true count: six
> sites extended to the sixth kind (`node-out-targets`; `node-eof-target`,
> which Task 1's fix wave collapsed three near-duplicate accessor sites into;
> `reexec-targets`; `eof-terminal`; and both `pass-eof-execution` filters,
> §16.2:908/:909) plus two sites deliberately left unextended and each
> documented in place: `pass-overlap` above, and `pass-zero-progress`'s report
> guard (`(or (byte-dispatch-node? n) (pause-node? n))`, `verify.sls:228`),
> whose sequence extension is §25:1533's zero-progress-cycle work — Slice ③,
> not this one.

> **Disposition, 2026-08-30 (whole-branch review fix wave; Slice ③ closed, and
> Milestone 3 with it).** Slice ③ Task 2 did that §25:1533 work — the report
> guard above now reads
> `(or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))` —
> so of the two sites the disposition above left unextended, one is now
> extended and one (`pass-overlap`) is permanently not: the census is **eight
> sites, seven extended, one never**, membership unchanged. The number's
> primary home is the derivation beside the arms that cover it, in
> `verify-tests.sps`'s "sequence dispatch reaches every verifier arm" group
> header; the appendix's Task 6 close-out disposition on the `verify` row
> (Slice ③ closed) records the same move. The paragraph and the disposition
> above are left as written, being the record of what was measured under
> Slice ②.

**The lowering is trie-shaped from the start, and that is a correctness
requirement rather than an early optimization.** `make-sequence-dispatch-node`
takes a plural `cases` list (§9.1:297) and validates local shape only, and
decision 0017 point 4 leaves colliding alternatives to the verifier. So nothing
stops a two-alternative node from being constructed and verified clean the day
this slice merges. Lowered per-alternative as separate linear chains, two
alternatives sharing a first byte — `AB` and `AC` — put two transitions on that
byte out of one state; the ascending-by-byte sort key of §4.1's caveat ties
there, `list-sort` stability picks a winner, and the other alternative goes dead
with nothing failing. They are not *ambiguous* — neither is a terminal prefix of
the other — so §7's ambiguous-terminal-prefix check would not catch it either.
Merging the shared byte into one state is what removes the tie, so it lands with
the node kind. For a single alternative a trie *is* a linear chain, so this is a
tree construction rather than a new concept and the oracle below is unchanged.
Genuinely ambiguous alternatives are a different failure and stay with Slice ③:
the trie has no "accept here" slot to offer them (§4.2), so this slice's fixtures
keep every alternative distinguishable and Slice ③ is what turns that convention
into a checked property. That does put the rejection rule and the lowering it
constrains in different pull requests, which §2 warns is how one drifts from the
other; §4.2 is the shared resolution that has to be re-read in both.

Contents:

- **Source IR.** `make-sequence-dispatch-node` and `make-sequence-case` with
  local-shape validation only; both added to `node?` (`ir.sls:141-142`) and
  `node-name` (`:143-149`), or `make-machine`'s `(for-all node? nodes)` at
  `:163-164` rejects the node outright. Exported from both lists in `graph.sls`.
- **All six verifier arms above**, plus the `node-out-targets` arm that also
  repairs `pass-names`' missing-target resolution (`:101-107`) and `byte-reached`
  (`:213`) for free.
- **Trie-shaped prefix lowering.** The alternatives of one node descend into
  shared states wherever they agree, per §10.6:544 and §4.3's within-node sharing;
  a one-alternative trie is a linear chain. With the §4.3 id allocation, whose
  pre-order takes each state's children in ascending byte order so the traversal
  is a total order (decision 0016 point 1), and with `normal-ir-tests.sps:41-46`
  amended to the recorded rule.
- **Interpreter prefix tracking** per §4.2, with `lookup` and `kind` destructuring.
- **Emitter: confirm zero change and record it.** Any new emitted local must be
  added to `reserved-member-3` (`compile.sls:53`) in the **same commit** (decision
  0012 item 4); `reserved-member-3` has no automated drift guard, unlike member-2.
- **The oracle.** A single-alternative sequence matching `1 2 3 4` reproduces
  `sequence-machine.sls` exactly: all eight cut-sets, the seeded 32-schedule
  multi-split with its genuine-multi-split sentinel, nonzero-offset and empty
  slices, and every mismatch position, against tuples already pinned at
  `differential-sequence-tests.sps:118-201`. That the oracle machine has one
  alternative is a property of this fixture — `sequence-machine.sls` is what M2
  shipped — not a limit on the lowering under test.
- **Both mismatch modes.** Every shipped fixture uses `reexecute` fallbacks
  (`sequence-machine.sls:19,22,25,28`; `pause-machine.sls:17,21`), so the
  **advance-mismatch path has zero coverage anywhere in the tree** while §11.5:664
  says authors may deliberately choose either and "tests must make that choice
  explicit". An advance-mode mismatch edge silently shifts every reported position
  by one, and no existing test would look obviously wrong.

> **Disposition, 2026-08-30 (Task 6 close-out; Slice ② closed).** Each item
> above, against the shipped tree, re-checked rather than assumed:
>
> 1. **Source IR.** Shipped in Task 1 (commit `4ae825f`, fix wave `32146a0`):
>    `make-sequence-dispatch-node`/`make-sequence-case` in `ir.sls`, both added
>    to `node?`/`node-name`; ten names — not eight, as Task 1's own report
>    first miscounted and later corrected by measuring
>    `git diff 2468881..4ae825f -- src/byte-machine/graph.sls` — exported from
>    `graph.sls`'s export list and its `only`-import list alike.
> 2. **All verifier arms above** — **eight**, not six; see the dated
>    disposition immediately above — plus `node-out-targets`'s repair of
>    `pass-names`' target resolution and `byte-reached`. Task 1; measured
>    mutation total 41 passes/200 after its fix wave (from 41/186 on `main`).
> 3. **Trie-shaped prefix lowering** with decision 0016's two-phase id
>    allocation and the amended `normal-ir-tests.sps:41-46` rule. Task 2
>    (commit `b9f2be6`, fix wave `0b6a983`); measured mutation total 41
>    passes/209.
> 4. **Interpreter prefix tracking**, `lookup`/`kind` destructuring, the
>    `(name . path)` representation (§4.2's dated amendment above, not the
>    `(s . k)` this bullet's own cross-reference used to imply). Task 3
>    (commit `c4a2039`); measured mutation total 41 passes/218.
> 5. **Emitter: zero change, confirmed and recorded.** A comment above
>    `render-state-arm` in `compile.sls`; no executable change.
>    `reserved-member-3` checked and confirmed unchanged — no new emitted
>    local. Task 3, same commit.
> 6. **The oracle.** `differential-sequence-node-tests.sps` reproduces every
>    `sequence-machine.sls` tuple pinned at
>    `differential-sequence-tests.sps:118-201` exactly, over a
>    single-alternative `1 2 3 4` machine, including all eight cut-sets and
>    the seeded multi-split schedule. Task 5 (commits `e27e0ca`..`c6ae163`,
>    two fix waves); measured mutation total 43 passes/223 (the slice's final
>    total).
> 7. **Both mismatch modes.** Fixtures for both `reexecute`- and
>    `advance`-mode mismatch landed in Task 4 (commit `d435b6f`, two new
>    lanes, `byte-machine.unit.sequence-node.chez.{source,aot}`; mutation
>    total 42 passes/221) and were driven through the interpreter≡generated
>    differential in Task 5
>    (`byte-machine.differential.sequence-node.chez.{source,aot}`), closing
>    the "zero coverage anywhere in the tree" gap this bullet warns about.
>    Both new lane families use distinct five-segment names, avoiding the
>    collision the closing "Naming" paragraph below warns against with the M2
>    `byte-machine.differential.sequence.chez.*` pair.
>
> Final measured totals for the whole slice, re-taken for this close-out
> (commands in `.superpowers/sdd/task-6-report.md`): `ctest --preset release`
> 80/80 (from 76 on `main`); `ctest --preset no-scheme` 8/8 (unchanged);
> Scheme mutation suite 43 passes/223 mutations (from 41/186 on `main`);
> CMake mutation suite 1 pass/72 mutations (unchanged); 9 pre-existing
> `EXPECT_SURVIVES`, none added, removed or edited since `main`
> (`git diff 2468881..HEAD -- test/support/cmake/SchemeMutationSuite.cmake |
> grep -E '^[+-].*EXPECT_SURVIVES'`, empty); the three pinned IR fingerprints
> and both committed goldens byte-identical since `main`
> (`git diff --stat 2468881..HEAD -- test/fixtures/`, empty).

**Naming.** `byte-machine.differential.sequence.chez.{source,aot}` is already
registered at `test/CMakeLists.txt:968-987` for the M2 chained-dispatch machine,
and duplicate CTest names are a configure-time `FATAL_ERROR`. New lanes need
distinct five-segment names. More generally: anyone grepping `sequence` in this
tree will conclude half of M3 already ships.

## 7. Slice ③ — Multiple alternatives, ambiguity, and cycle analysis

Discharges the multi-alternative half of §25:1529 (exact sequence alternatives —
Slice ② built the lowering that admits them; this slice is where more than one is
constructed, executed and checked), §25:1532 (ambiguous-prefix rejection) and
§25:1533 (extension of zero-progress and EOF-cycle analysis to lowered
sequence-prefix states); exit criteria §25:1539 (normalized output is
deterministic) and §25:1540 (consuming cycles pass and zero-progress cycles fail
verification).

- **Multi-alternative fixtures over Slice ②'s trie.** The branching prefix
  structure itself — shared *nonterminal* prefixes in the lowering, per §10.6:544
  — lands in Slice ② (§6), because without it two alternatives sharing a byte
  miscompile silently. This slice is where more than one alternative is first
  constructed, lowered and executed end to end. See §8's mirror trap before
  reading §29:1744 as a prohibition.
- **Ambiguous-terminal-prefix rejection**, one new diagnostic code (§4.5).
- **The cycle extension**, which §25:1533 makes sound larger than it is *given
  Gate 0 record 4.4*: with empty sequences rejected at construction every sequence
  advances, so this reduces to the source-level case of a mismatch edge
  reexecuting back into its own node. At source granularity that is one self-loop;
  at lowered granularity only prefix position 0 genuinely makes no progress, since
  positions ≥1 reach position 0 only after an advance. **Both over-rejecting every
  self-targeting sequence node and under-rejecting the position-0 loop fail
  §25:1540.** The saving grace is that verification never needs the lowered graph:
  the mismatch edge is a source-level field (§9.1:297) and every prefix state
  inherits the source node's single EOF edge (§12.4:727), so §17:951's
  verify-before-normalize ordering is never actually approached.
- **Determinism pins** for sequence machines (§22.9).
- **The `HTTP/1.0` ⁄ `HTTP/1.1` fixture** — shared prefix `HTTP/1.`, a real
  workload from §21.2's grammar rather than an invented one, and the smallest
  fixture that exercises shared nonterminal prefixes with a distinguishing
  terminal byte.

> **Disposition, 2026-08-30 (Task 6 close-out; Slice ③ closed, and Milestone 3
> with it).** §7's own work has closed, so per AGENTS.md's "an instruction
> changes category when its work closes" rule its five bullets are dispositioned
> here rather than reworded to match what shipped. Each was re-checked against
> the tree. **Three of this slice's novelty-or-mechanism claims were measured
> FALSE during execution**, none of them by reading; the narrowed claims are the
> ones below, and the originals stand above as the record of what was asked.
>
> 1. **Multi-alternative fixtures over Slice ②'s trie.** Shipped in Tasks 3-5:
>    `test/support/harness/byte-machine/test/http-version-machine.sls` (both
>    mismatch-mode machines, written once and shared by three programs);
>    `test/common/http-version-interpret-tests.sps` with the lane pair
>    `byte-machine.unit.http-version.chez.{source,aot}`, whose four groups are
>    **three** of **absolute** interpreter outcomes ("each alternative reaches
>    its OWN target through the shared prefix", "mismatch positioning, at the
>    branch and before it (§11.5:664)", "every proper prefix is need-input,
>    never paused (decision 0015 point 5)") plus **one** verification check
>    ("both fixtures verify clean under the §16.2:894 pass") — three absolute and
>    one verifying, not four absolute;
>    `test/common/differential-http-version-tests.sps` with
>    `byte-machine.differential.http-version.chez.{source,aot}`; and a structural
>    group in `normal-ir-tests.sps`, **"two alternatives over a shared prefix
>    lower to one trie"** ("the shared prefix is not duplicated", "the chain is
>    linear until the distinguishing byte", "the branch state routes each
>    alternative to its OWN declared node"). That is *not* "alternatives share
>    prefix states wherever they agree", which is **Slice ②'s** — it is present at
>    Slice ②'s merged tip `49c8cc4` and absent from this slice's diff — and is
>    the very group whose cases the narrowing below credits to Slice ②. An
>    earlier draft of this disposition named that group here, crediting one group
>    to both slices four lines apart.
>    **NARROWED, by measurement.** This bullet's second sentence — "this slice is
>    where more than one alternative is first constructed, lowered and executed
>    end to end" — is **false as written**, and the plan that inherited it was
>    corrected before Task 3 ran. Slice ② already ships two lanes that drive the
>    trie MERGE: `normal-ir-tests.sps` pins structurally that a shared first byte
>    becomes one transition into one state and pins the branch's transition list,
>    and `interpret-tests.sps` executes `AB`/`AC` through the interpreter. The
>    gap statement is true only with its own qualifier — *the **differential** is
>    single-alternative*. What Slice ③ adds is the differential over a branch,
>    plus depth (a seven-byte shared prefix), absolute tuples, and both mismatch
>    modes. No sentence in this milestone's records may say "first to exercise
>    the trie merge".
>    **A second narrowing, inside that differential and measured the same way.**
>    Its first draft claimed that a defect resuming into the wrong prefix state
>    across a feed boundary would be caught there and nowhere else. False:
>    rendering the need-input resume id as the entry state instead of the current
>    one also reddens `differential-sequence-node-tests.sps` (failed-cases=9,
>    failures=10), because a single-alternative chain has prefix states to resume
>    into too. What needs a **branch** is *losing* an alternative, not *resuming*
>    — a one-arm state and a truncated one-arm state are the same state. The
>    corrected claim is written into the shipped program's own header.
> 2. **Ambiguous-terminal-prefix rejection, one new diagnostic code (§4.5).**
>    Task 1: `pass-sequence-ambiguity` with its `byte-prefix?` and
>    `node-ambiguities` helpers in `verify.sls`, called from `verify-machine`
>    directly after `pass-overlap` as an unnumbered pass, reporting exactly one
>    `'ambiguous-sequence-prefix` per colliding pair. Witnessed by
>    `verify-tests.sps`'s group "sequence ambiguity (§16.2:894)" — including
>    "alternatives that merely share a prefix are not ambiguous", which is what
>    stops the check from rejecting every branching machine — and by
>    `interpret-tests.sps`'s "§16.2:894 rejects both unrepresentable shapes before
>    the interpreter". `pass-overlap` is **permanently** not extended (§0 D1 of
>    the slice plan; decision 0017 point 4), and the guards for the same two
>    internal invariants are **kept** as defense-in-depth in both files — three
>    assertion sites in `normal-ir.sls`'s `trie-insert`, because the ambiguity
>    invariant is checked in both directions, and two in `interpret.sls`'s
>    `seq-step` — each with the reason written at its site. The normalizer's
>    three keep their witnesses in `normal-ir-tests.sps` ("an ambiguous terminal
>    prefix is an assertion violation" and "an ambiguous terminal prefix inserted
>    in reverse order is also caught"), which the new pass left untouched because
>    that program takes `verification-machine` without consulting
>    `verification-ok?`. The interpreter's two are re-witnessed through a forged
>    `make-verification-result` in `interpret-tests.sps`'s "the interpreter's own
>    guards still fire for a caller that skips verification" — which is what kept
>    Pass 34's two shipped mutations ("interpret: the ambiguous-terminal-prefix
>    guard is dropped" and "interpret: the duplicate-sequence-alternative guard is
>    dropped") alive rather than uncaught, with neither pin changed.
> 3. **The cycle extension.** Task 2, one line: `pass-zero-progress`'s REPORT
>    guard gained `sequence-dispatch-node?`. **Attributed in halves.** §25:1533
>    reads "zero-progress **and EOF-cycle** analysis", and its **EOF-cycle half
>    shipped in Slice ②** — `eof-terminal`'s sequence arm and
>    `pass-eof-execution`'s two filters, witnessed by `verify-tests.sps`'s "an eof
>    chain that cycles through a sequence node is an EOF cycle" and "an eof chain
>    that cycles from a dispatch node through a sequence node's own eof-target is
>    an EOF cycle". Measured on unmodified `main` before Slice ③ began: a sequence
>    node with a self-cycling `eof-target` already reported
>    `eof-zero-progress-cycle`. Slice ③ owns the **zero-progress** half only.
>    This bullet's own phrasing — "positions ≥1 reach position 0 only after an
>    advance" — was found imprecise and misleading to an implementer; the
>    load-bearing invariant is **"no zero-width edge can ENTER a position-≥1
>    prefix state"**, from which the lowered zero-width cycle set equals the
>    source-level one. That invariant, and the extension's deliberate inherited
>    over-approximation, are written into `verify.sls` at the site rather than
>    left in this document.
> 4. **Determinism pins for sequence machines (§22.9).** Task 5:
>    `test/common/determinism-http-version-tests.sps` and the lane pair
>    `byte-machine.determinism.http-version.chez.{source,aot}`, plus the third
>    committed golden `test/fixtures/generated-http-version.golden.sls` — 3849
>    bytes, generated by the shipped emitter, IR fingerprint
>    `12299125921751534854`, 11 normalized states.
>    **NARROWED, and this one was the task's own stated justification.** The plan
>    said "a `list-sort` tie at the branch is precisely how §25:1539 would be
>    lost". **False.** The branch's child order comes from `trie-put`'s ascending
>    alist insertion, not from the `list-sort` that orders a byte-dispatch node's
>    transitions (decision 0014); this fixture declares no byte-dispatch node at
>    all. Established with a control rather than by reading: flipping
>    `list-sort`'s comparator re-emits this machine **byte-identically**, while
>    the same flip *does* reorder a two-case byte-dispatch node's arms — so the
>    flip is a real mutation and the byte-identity is not an artifact. The task
>    stands; only the named mechanism was wrong, and the corrected mechanism is
>    written into the shipped program's header.
>    One scoping note, so this disposition does not contradict the two other
>    places in this file that allocate exit :1539. §7's own opening sentence two
>    paragraphs above claims :1539 for this slice, and §1's phase table said the
>    same in Slice ③'s "Discharges" cell. The milestone exit disposition below
>    credits it to **Slice ② and Slice ③ together** — Slice ②'s
>    `normal-ir-tests.sps` "caller order does not change the canonical result" is
>    the other half, present at Slice ②'s merged tip `49c8cc4` and absent from
>    this slice's diff, so the attribution is measured rather than assumed.
>    §7's opening sentence is a closed instruction and stands as written; **§1's
>    two phase-table cells were corrected in place at this close**, because that
>    table is a navigational map that has to be true, and a half-narrowed cell —
>    Slice ③'s :1533 split into halves while :1539 still read whole — is the
>    worst of the three states: it reads as measured and current while asserting
>    what the measurement disproved. Slice ②'s row now names its half of :1539
>    too, so the pair is symmetric rather than leaving the criterion
>    under-allocated. The same halving applies to :1533's opening claim,
>    corrected in item 3 above.
> 5. **The `HTTP/1.0` ⁄ `HTTP/1.1` fixture.** Built in Task 3 over §21.2:1065's
>    `version = "HTTP/1.0" / "HTTP/1.1"`, driven by Tasks 4 and 5. Measured
>    lowering: entry 0, 11 states, seven internal prefix states appended after the
>    four declared ones (decision 0016 point 2), the branch at id 10 after the
>    seven-byte shared prefix `HTTP/1.`, every prefix state carrying the source
>    node's mismatch edge as its fallback and inheriting its EOF edge (§12.4:727).
>    The emitter needed **zero** change: state 10 renders as an ordinary two-arm
>    `(case b ...)`.
>
> **The slice's implementation plan is a record now, and diverged from the tree
> in three places that are dispositioned there rather than edited** (see its own
> dated close-out disposition): the differential program's measured shape moved
> from `cases=8 checks=20` to `cases=8 checks=19` when a review replaced the
> `last-byte`/`positions` sentinel pair with one `drives` counter asserted at
> 2048 — the pair could not distinguish "256 bytes at 8 positions" from "256 at
> one position and none at the other seven" — and several drafted case names and
> the `list-sort` justification were superseded as above.

**Exit (full Milestone 3).** The parent plan's four exit criteria (§25:1537-1540),
each dispositioned against the shipped tree. Two of the four (:1537, :1538) were
discharged by *other* slices outright and a third (:1539) only in part, so this
list — not any one slice's own disposition — is what the parent plan's §25 close
note cites.

> **Dispositioned 2026-08-30 at close.** Every "met" below names the file and
> the case in the tree that meets it, found there rather than asserted from
> memory. Measured totals for the whole milestone as it closes, re-taken for
> this close-out (commands in `.superpowers/sdd/task-6-report.md`):
> `ctest --preset release` **86/86** and `--preset pr` **86/86** (from 80 at
> Slice ②'s close, 76 at Slice ①'s); `--preset no-scheme` **8/8** (unchanged
> across all three slices); Scheme mutation suite **46 passes / 235 mutations**
> (from 43/223 at Slice ②'s close), zero `UNCAUGHT`, zero `FATAL`, **nine**
> `SURVIVES (expected)`, none added, removed or edited by any of the three
> slices — measured across the whole milestone, not only this slice
> (`git diff a9de657..HEAD -- test/support/cmake/SchemeMutationSuite.cmake |
> grep -E '^[+-].*EXPECT_SURVIVES'`, empty, where `a9de657` is Slice ①'s merge
> base — the last commit before any M3 product code landed);
> CMake mutation suite **1 pass / 72 mutations**, unchanged. The three
> pinned IR fingerprints (`4236938459847922092`, `9098559711816935340`,
> `15725897457025557005`) and both pre-existing committed goldens are
> byte-identical across the **whole** milestone, not merely across its last
> slice: `git diff --stat a9de657..HEAD -- test/fixtures/` shows exactly one
> changed path, the new `generated-http-version.golden.sls`, and no line
> carrying any of the three fingerprints changed in `normal-ir-tests.sps` over
> the same range. That was Slice ①'s own oracle and it held through ② and ③.
>
> **Amended 2026-08-30 (whole-branch review fix wave).** The totals above are
> the close-out measurement and stand as written. The fix wave that followed
> added one mutation to Pass 33 — `"verify: the sequence mismatch edge's MODE
> is not tested (arm 3, reexec-targets)"` — plus the one attribution check in
> `verify-tests.sps` its pin needed, so the shipped suite is **46 passes / 236
> mutations**. Everything else in this paragraph was re-measured and is
> unchanged: `release` 86/86, `no-scheme` 8/8, zero `UNCAUGHT`, zero `FATAL`,
> nine `SURVIVES (expected)` with no diff line touching an `EXPECT_SURVIVES`,
> CMake 1 pass / 72 mutations, and the three fingerprints and both pre-existing
> goldens byte-identical.
>
> 1. **:1537 — "all-byte class tests pass": MET, by Slice ①.**
>    `byte-class-interpret-tests.sps` ("all 256 byte values, per class", "the
>    ASCII helper rejects the high half") and `differential-byte-class-tests.sps`
>    ("interpreter and generated agree on every byte, for every class"), each in
>    a source and an AOT lane, over the shared fixture list in
>    `class-machine.sls` whose own completeness is asserted by a group in both
>    programs.
>    **Residue, named rather than closed (§0 D10b of the Slice ③ plan).** No lane
>    compiles and executes a machine whose only case is a vacuous complement,
>    `(make-byte-complement-matcher (make-byte-range-matcher 0 255))`. That
>    construct is exercised by the normalizer (`normal-ir-tests.sps`, "a vacuous
>    complement lowers to zero transitions (decision 0017 point 2)") and by the
>    verifier (`verify-tests.sps`, "a vacuous complement collides with nothing"),
>    and by nothing that compiles and runs it. Confirmed still open at this
>    close, not merely inherited as a claim. It belongs to §25:1527 and to this
>    criterion — **Slice ①'s** scope — so Slice ③ did not widen to close it, and
>    it closes with the milestone. Provenance: carried in the Milestone 3 session
>    ledger out of Slice ① into Slice ②'s close-out, and thence into Slice ③'s
>    implementation plan as §0 D10b.
> 2. **:1538 — "every sequence split and mismatch position passes": MET, by
>    Slice ②, extended to a branching trie by Slice ③.** Slice ②:
>    `differential-sequence-node-tests.sps` ("the M2 chained-dispatch tuples are
>    reproduced exactly", "every fragmentation of the sequence reaches stopped in
>    both lanes", "nonzero-offset slices report exact next / consumed /
>    stream-offset", "both mismatch modes, absolutely, on the generated
>    executor") and `sequence-interpret-tests.sps` ("all 256 byte values at every
>    sequence position", "the two mismatch modes report different positions,
>    explicitly"). Slice ③ Tasks 3-4 re-point that rig at two alternatives over a
>    seven-byte shared prefix, in both mismatch modes, including the cut at the
>    branch boundary asserted by name.
>    **Limitation, recorded rather than glossed (§8).** Mismatch positions are
>    asserted through `status`/`next`/`consumed`/`stream-offset`/`code` only. The
>    structured parser-error record (`parser-error-node-name`, `-state-id`,
>    `-position-kind`) is deferred to M4/M5 by milestone-2-design.md §7, which
>    forbids populating one field of an otherwise-deferred family. This is the
>    same limitation Slice ② recorded against this criterion; the branching
>    fixtures do not change it.
> 3. **:1539 — "normalized output is deterministic": MET, by Slice ② and Slice ③
>    together.** Slice ②: `normal-ir-tests.sps`'s "caller order does not change
>    the canonical result", which normalizes the same two alternatives in both
>    declaration orders and compares fingerprints. Slice ③ Task 5:
>    `determinism-http-version-tests.sps`'s "rendering twice in one process
>    yields identical bytes" and "the emitted bytes equal the committed sequence
>    golden", in a source and an AOT lane, against the third committed golden —
>    the first golden containing a branch.
>    **Limitation, recorded rather than glossed.** §22.9's bullet at :1314 —
>    generate in every Tier 1 cell and compare output byte for byte across
>    operating systems and architectures — is **not built**:
>    `.github/workflows/ci.yml` has no `upload-artifact` step and no cross-cell
>    comparison job, so no cross-cell artifact is retained or compared.
>    "Deterministic" as discharged here means byte-identical within one process,
>    identical across the source and AOT lanes (:1313), and equal to a committed
>    golden; cross-process (:1312) and cross-cell (:1314) identity follow
>    **transitively** from every lane comparing against the same committed bytes,
>    not from a direct measurement. M9 completes the four-cell matrix with the
>    same goldens.
> 4. **:1540 — "consuming cycles pass and zero-progress cycles fail
>    verification": MET, by Slice ③ Task 2, one case per half.** `verify-tests.sps`:
>    "a sequence node whose reexecute mismatch edge targets itself is a
>    zero-progress cycle" (the failing half) and "the same self-target with an
>    advance mismatch edge is a consuming cycle and passes" (the passing half,
>    which asserts `ok` **and** a diagnostic count of zero). The passing half is
>    as load-bearing as the failing one: it is what stops the report guard from
>    being widened past the mismatch edge's mode. Measured on `main` before the
>    change, the failing half's fixture verified clean with zero diagnostics and
>    did not return when fed a non-matching byte, in the interpreted and the
>    generated lane alike.

## 8. Explicitly out of Milestone 3

- **Trie/sequence specialization, sequence unrolling, peephole optimization,
  transition tables and byte-class tables** — §29:1743-1744, gated by §23.3:1369
  behind reproducible compiled benchmarks in both lanes, plus the §23.3:1380
  decision record. `bench/` contains two `.gitkeep` files, so no §23 evidence can
  exist yet.
  ⚠️ **Mirror trap.** §29:1744 defers trie **specialization**; the shared-prefix
  **structure** is *required*, because §10.6:544 permits shared nonterminal
  prefixes and §11.3:648 forbids rewind, so per-alternative linear chains cannot
  work. Reading :1744 as "no prefix sharing in M3" produces a design that cannot
  satisfy :544.
- **The structured parser-error record** (`parser-error-node-name`,
  `-state-id`, `-position-kind`, §9.3) — deferred to M4/M5 by
  [milestone-2-design.md](./milestone-2-design.md) §7, which specifically forbids
  populating one field of an otherwise-deferred family. M3's mismatch tests
  therefore assert `status`/`next`/`consumed`/`stream-offset`/`code`, and that
  limitation must be **recorded** rather than glossed when discharging §25:1538.
- **Widening the diagnostic record to §16.4's seven fields** — Milestone 7
  (§25:1603). Severity has no discriminating value in v0.1 anyway (§16.4:938 fixes
  it at `error`; :947 defers warning policy).
- **Extending the property generator** (`machine-gen.sls`) to draw class matchers
  or sequence nodes — Milestone 7 (§25:1605-1607); §22.6's enumeration names no M3
  construct.
- **The state-ID-to-source-name debug map** (§17:963) — its only consumers are the
  unshipped parser-error accessors, and no v0.1 error is raised *inside* a lowered
  prefix state (mismatch and prefix EOF both route to declared source targets, and
  the error surfaces at an error node carrying its own name). If added anyway it
  cannot perturb the fingerprint: `encode-normal` is called as
  `(encode-normal entry states)` and never sees names.
- **The §16.2:884 "unsupported IR versions" check** — `machine-ir-version` is
  stamped at `ir.sls:153` with no accessor and `pass-schema` (`verify.sls:79-80`)
  is a single `machine?` tag test. Half-implemented and easy to score as done, but
  not M3 scope.
- **Case-insensitive recognition of `Content-Length` / `Transfer-Encoding` /
  `chunked`** — §25:1624 names it as **Milestone 8** item 5. The HTTP fixture's own
  byte classes (`tchar`, `target-byte`, `field-value-byte`, `OWS`) are §21.2
  grammar and likewise M8. M3 ships the *mechanism*; M8 spends it.
- **Cross-node prefix-state sharing** between distinct sequence nodes (§4.3).
- **Any `runtime.sls` change for sequence support, and any `/v3` ABI.** The `/v2`
  contract is `(state offset bv start end finish?) → feed-outcome` with an opaque
  state; no node kind appears in it. Decision 0012 item 3 established that new
  behaviour rides on new status symbols rather than a new `feed-outcome` record,
  and the executor state the ABI carries is opaque, so new state ids need no ABI
  surface at all.
- **Any general lookahead or "try the sequence, restore on mismatch" mechanism** —
  §10.6:546 and §11.3:648 forbid it.
- **Adding a `source-label` parameter to any matcher constructor "for
  consistency"** — §9.1:291-294 give them arity 1/1/2/1 without one (§3).
- **Re-doing all-byte coverage for exact transitions** (M1 exit criterion,
  extended by M2 across seven programs) or **re-building split-point/fragmentation
  machinery** (M2 Slice ①). M3 re-points that rig at the new constructs.

## 9. Handed to writing-plans

- **Gate 0 record forms.** Four records (§4.1 per-byte expansion; §4.2 sequence
  lowering *and* the independent interpreter representation; §4.3 state-id
  allocation; §4.4 degenerate shapes). writing-plans assigns numbers and confirms
  whether §4.2 should split — it deliberately fuses the normalizer and interpreter
  calls because §18:970-972 makes them one decision, and splitting them invites
  the shared-walker mistake §3 warns about.
  **Resolved:** §4.2 stayed one record (0015). Splitting it would separate the
  normalized representation from the interpreter constraint that makes the
  differential meaningful, which is the mistake §3 warns about.
- **Exact proving machines.** §5–§7 specify the *properties*; writing-plans pins
  the concrete node wiring — the class/complement/ASCII fixtures and their 256-value
  loops; the single-alternative sequence that must reproduce `sequence-machine.sls`
  and the mapping from its cut-sets to the pinned tuples; the advance-mode and
  reexecute-mode mismatch fixtures with their asserted `next`; the shared-prefix
  `HTTP/1.0`⁄`1.1` fixture; and the position-0 zero-progress rejection fixture
  together with a *consuming* sequence cycle that must pass.
- **The ordered task list for Slice ①** (§5), which is a correctness constraint
  rather than a preference, and its byte-identical-fingerprint gate.
- **Mutation pin re-anchoring** (§5): `SchemeMutationSuite.cmake:2967` dies;
  `:2973`/`:3183` are double-pinned with `SITES` asserted; `eof-terminal`'s
  `((stop-node? n) 'eof-reachable-stop)` (`:3059`) and `(if (memq name seen) 'cycle`
  (`:3066`) both move if the eof helpers are touched. Each is a re-measurement.
- **Lane and manifest bookkeeping**, which is fatal-on-error rather than warning:
  every new test program needs a source+AOT pair (the AOT lane resolves libraries
  only through objects compiled from its own `SOURCES`), each with a required
  `TIMEOUT` and a unique five-segment name under the configure-time regex; any new
  fixture `.sls` must appear in **both** lanes' `SOURCES`; basenames must be unique
  within a lane; and any new `.sls` changes the lane's content fingerprint, which
  the harness verifies at `harness-begin`.
- **Completion sentinels.** No suite declares an expected case or check count —
  `harness-summary` reports only what ran, so exhaustive loops **pass vacuously**.
  Every new 256-loop, per-position mismatch loop and schedule loop needs its own
  hand-written sentinel, following `differential-eof-tests.sps:54` and
  `differential-sequence-tests.sps:157-160`.
- **Mutation discipline** (AGENTS.md): every decision gets a mutation asserting a
  measured failure **signature**, not a bare nonzero exit; re-run the **whole**
  mutation suite after adding any exit path, because a new exit path can silently
  disarm an existing mutation by making baseline and mutant land on the same
  status; adding mutations to a lane widens every existing pin's collision set in
  that lane silently; add no new dependencies.
- **Sizing is a floor, not an estimate.** M2 Slice ③ — one new node kind, one new
  public operation, one new golden — cost +42 mutations, +1 mutation pass, +6
  lanes, 7 tasks and six review rounds, against a plan prediction of ~145-146
  mutations that measured 161 and closed at 165. M3's sequence half alone touches
  more modules than that. Write only **measured** numbers into `EXPECTED_PASSES` /
  `EXPECTED_MUTATIONS` (38/165 today at `SchemeMutationSuite.cmake:554-555`), the
  CHANGELOG, or any record.
- **TDD** (§22.1): failing tests first for each slice.

## 10. References

- Parent plan §25 (Milestone 3 scope :1527-1533, exit criteria :1537-1540), §9.1
  (normative construction calls — matchers :291-294, sequence :297-298,
  `ascii-bytes` :299, collection rule :318, constructor-validation rule :322),
  §10.6 (the closed node-kind set — byte dispatch :536-540, sequence dispatch
  :542-546), §11.3 (no rewind :648), §11.4 (input-dependent nodes :652), §11.5
  (result position and explicit mismatch-mode choice :664), §12.4 (EOF; prefix
  states inherit the source EOF edge :727), §16.2 (required checks — overlap :893,
  sequence ambiguity :894, mandatory fallback :895), §16.3 (verification passes —
  matcher canonicalization and byte-set overlap :921), §16.4 (diagnostic structure
  :933-947), §17 (normalization — verify-before-normalize :951, canonical byte sets
  :956, resumable prefix states :957, no speculative transformations :966), §18
  (reference interpreter — normalizer independence :970-972), §19.2 (initial
  lowering choices :1008-1010), §22.4 (differential), §22.5 (fragmentation), §22.7
  (all-byte :1299-1301), §22.9 (determinism), §23.3 (optimization admission rule
  :1369, :1380), §29 (deferred extensions :1743-1744).
- [milestone-2-design.md](./milestone-2-design.md) §4-§7 (what M2 built and left,
  and the deferred parser-error family).
- [milestone-1-design.md](./milestone-1-design.md) §5-§7.
- [decision 0009](../.decisions/0009-content-and-ir-fingerprints.md) — the IR
  fingerprint §4.1 and §4.3 are designed to leave in place.
- [decision 0010](../.decisions/0010-direct-executor-abi.md) — the direct-executor
  ABI (**item 4**: extension by version, the warrant for §8's no-`/v3` boundary).
- [decision 0011](../.decisions/0011-eof-execution-model.md) — the EOF execution
  model whose chain §4.2's corollary discusses.
- [decision 0012](../.decisions/0012-generated-abi-v2-finish.md) — `/v2` (**item 3**:
  new behaviour rides on new status symbols rather than a new `feed-outcome`
  record; **item 4**: the `reserved-member-3` obligation in §6).

## Appendix — per-library change map

| Library | M3 change |
| --- | --- |
| `graph`/`private ir` | Slice ①: `make-byte-set-matcher`, `make-byte-range-matcher`, `make-byte-complement-matcher`, `ascii-bytes`; a tag check on `exact-byte-matcher-byte`; `make-byte-case`'s guard widened to a `matcher?` disjunction; matcher predicates/accessors exported (closing `graph-tests.sps:5`'s reach into `private ir`). Slice ②: `make-sequence-dispatch-node`, `make-sequence-case`, and both added to `node?`/`node-name`. Both slices edit `graph.sls`'s export list **and** its `only` import list. |
| `verify` | Slice ①: `pass-overlap` rewritten as canonical-set pairwise disjointness, one diagnostic per colliding pair. Slice ②: all six permissive fall-throughs taught the sequence node (`:56`, `:58-63`, `:158`, `:185`, `:207`, `:222`, `:236`) — in the same commit as the node kind. Slice ③: ambiguous-terminal-prefix pass with one new code, and the zero-progress extension for a self-targeting mismatch edge. `pass-reachability` and `reaches-self?` are **unchanged** (§5). |
| `private normal-ir` | Slice ①: matcher canonicalization at the lowering site (`:103`); byte sets expand to per-byte transitions; encoding, tag bytes and format version byte **unchanged**, fingerprints **must not move**. Slice ②: sequence arm replacing part of the `else` guard at `:121`; trie-shaped prefix lowering, alternatives of one node sharing states wherever they agree; two-phase-append id allocation with the ascending-byte child rule, and `normal-ir-tests.sps:41-46` amended to the recorded rule. Slice ③ adds no further normalizer change — the branching structure its fixtures exercise is already here. |
| `compile` (emitter) | Slices ① and ②: **confirm zero change and record it** — `render-transition-arm` (`:80-83`) and the `(case b ...)` at `:114-117` already render per-byte arms, and a prefix state is an ordinary dispatch state. Any new emitted local goes into `reserved-member-3` (`:53`) in the same commit. No `/v3`. |
| `interpret` | Slice ①: matcher dispatch through the canonical form, replacing `(= byte (exact-byte-matcher-byte ...))` at `:46`. Slice ②: compound `current` for prefix position, with `lookup` (`:15-18`) and `kind` (`:32-39`) destructuring; derived **independently** of `normal-ir` (§18:970-972), and holding no mutable state across parsers. |
| `runtime` | **No change.** `current` is opaque (no `symbol?` test anywhere), `parser-reset!` clears it at `:331`, and the `/v2` contract mentions no node kind. |
| CMake `test/CMakeLists.txt` | New source+AOT lane pairs for the class, complement, ASCII, single-alternative-sequence, mismatch-mode, shared-prefix and ambiguity-rejection programs, each with a `TIMEOUT` and a unique five-segment name (`byte-machine.differential.sequence.*` is taken); every new fixture `.sls` in **both** lanes' `SOURCES`. |
| `SchemeMutationSuite.cmake` | Mutations for every new decision, each with a measured failure signature; re-anchor `:2967` (deleted), `:2973`/`:3183` (double-pinned, `SITES` exact), and `:3059`/`:3066` if the eof helpers move; `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (`:554-555`) updated from measurement only. |

> **Disposition, 2026-08-30 (Task 6 close-out; Slice ② closed).** The
> `verify` row's "all six permissive fall-throughs ... (`:56`, `:58-63`,
> `:158`, `:185`, `:207`, `:222`, `:236`)" repeats §6's miscount verbatim —
> seven references under a count of six, and silent about the eighth
> (`pass-overlap`, deliberately left unextended). See the dated disposition
> at §6 above for the full count — eight sites, six extended and two
> deliberately deferred to Slice ③, each documented in place in
> `verify.sls` — rather than restating it here.

> **Disposition, 2026-08-30 (Task 6 close-out; Slice ③ closed, and Milestone 3
> with it).** The remaining Slice ③ entries in this table, against the shipped
> tree:
>
> - **`verify`.** Both Slice ③ entries shipped: `pass-sequence-ambiguity` with
>   the one new code `'ambiguous-sequence-prefix`, and the zero-progress REPORT
>   guard extended to a self-targeting `reexecute` mismatch edge. **That moves
>   the node-kind site census §6's disposition records from six extended plus two
>   unextended to SEVEN extended plus ONE**, the one being `pass-overlap`,
>   permanently rather than deferred; the eight-site membership is unchanged.
>   Recounted at this close by enumerating every site in `verify.sls` that
>   dispatches on node kind rather than by grepping `byte-dispatch-node?`, which
>   cannot see a `cond` dispatching through other kind predicates. The number's
>   primary home is beside the arms that cover it, in `verify-tests.sps`'s
>   "sequence dispatch reaches every verifier arm" group header, which carries
>   the derivation; it is repeated here only because this set has been miscounted
>   twice and §6 above would otherwise leave a design-only reader on the old
>   split. `pass-sequence-ambiguity` is a ninth kind-dispatching site and
>   deliberately outside that census — sequence-only by construction, never a
>   permissive fall-through that had to be taught the sixth kind. The row's
>   "`pass-reachability` and `reaches-self?` are **unchanged**" **held**, with
>   the qualifier that makes it true: the `reaches-self?` *procedure* and
>   `pass-reachability` are byte-for-byte unchanged on this branch; what Slice ③
>   edited is the one line in `pass-zero-progress` that *calls* `reaches-self?`,
>   which is that pass's report filter and not the walk.
> - **`private normal-ir`.** "Slice ③ adds no further normalizer change"
>   **held.** The file's entire diff against `main` for this slice is one
>   comment block; the branching structure its fixtures exercise was already
>   there. Verified by reading the diff, not by trusting a stat line.
> - **`compile` (emitter) and `runtime`.** Zero change in Slice ③ as well, not
>   only in ① and ②: neither file appears in this branch's diff at all, and no
>   new emitted local means `reserved-member-3` is untouched. The branching
>   prefix state renders as an ordinary two-arm `(case b ...)`.
> - **`interpret`.** Slice ③'s only edit is a comment at `seq-step`'s two
>   guards, recording that §16.2:894 now rejects both shapes at verification and
>   that the guards are kept as defense-in-depth. No behavioural change, as the
>   slice plan's global constraints required.
> - **CMake `test/CMakeLists.txt`.** The row predicted a lane pair for an
>   "ambiguity-rejection program"; **no such program or lane was built, and none
>   was needed.** The §16.2:894 check is a verifier pass, so its witnesses are
>   groups inside the already-registered `verify-tests.sps` and
>   `interpret-tests.sps` programs. Slice ③ registered six lanes, three
>   source+AOT pairs, all for the `HTTP/1.0`⁄`HTTP/1.1` fixture:
>   `byte-machine.{unit,differential,determinism}.http-version.chez.{source,aot}`.
> - **`SchemeMutationSuite.cmake`.** Every line number in this row is stale by
>   construction — the file went from 3858 lines at `a9de657`, the last commit
>   before any M3 product code landed (the same 3858 at `f29edf7`, the
>   decisions-only Gate 0 commit),
>   to 6470 at this close — and is left as the record of where those anchors sat
>   when the design was written. The obligations they name were discharged and
>   are recorded in the tree beside the pins, by mutation LABEL rather than by
>   line number, as AGENTS.md requires.
>   `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` closed the milestone at a measured
>   **46 passes / 235 mutations**; §9's "38/165 today at
>   `SchemeMutationSuite.cmake:554-555`" was the pre-M3 value at authoring time
>   and likewise stands as a record rather than being updated.
>   *Amended 2026-08-30 (whole-branch review fix wave):* one mutation was added
>   to Pass 33 after that close, so the shipped declaration is **46 passes /
>   236 mutations**; the `SchemeMutationSuite.cmake` line count quoted a few
>   lines above ("6470 at this close") was taken at that same moment and has
>   grown with the fix wave's edits to that file. Both sentences stand as the
>   record of what was measured at the close.
