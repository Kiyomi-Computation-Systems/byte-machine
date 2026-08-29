# Milestone 3 Design — Byte Classes and Sequences

Status: design — approved shape, **Gate 0 discharged; Slices ①–③ not started**
(see the dated notes below). Authored 2026-08-29, the day Milestone 2 closed
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
| **Slice ② — Sequence dispatch and prefix lowering** | product | the sixth node kind and every verifier arm; trie-shaped prefix lowering; state-id allocation; independent interpreter tracking; both mismatch modes | §25:1530-1531 and the single-alternative half of :1529, exit :1538 |
| **Slice ③ — Multiple alternatives and ambiguity** | product | multi-alternative fixtures over Slice ②'s trie; ambiguous-terminal-prefix rejection; the zero-progress/EOF-cycle extension; determinism pins; the `HTTP/1.0`⁄`HTTP/1.1` fixture | the multi-alternative half of §25:1529, plus :1532-1533, exits :1539-:1540 |

Dependency order is strict. Gate 0 unblocks everything. Slice ① is purely
additive to the normalized encoding, so it can assert *no fingerprint moved* as
its own oracle. Slice ② lands the node kind and the trie-shaped lowering, and is
validated against a machine already on `main`. Slice ③ adds the milestone's
remaining new analysis — ambiguous-terminal-prefix rejection and the cycle
extension — together with the fixtures that exercise more than one alternative.
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
record numbers (next free in `docs/decisions/`, assigned 0014–0017) and confirms
whether any splits or merges of the four below are warranted.

> **Gate 0 discharged 2026-08-29.** §4.1 → decision
> [0014](../decisions/0014-byte-classes-expand-per-byte.md), §4.2 →
> [0015](../decisions/0015-sequence-prefix-states.md), §4.3 →
> [0016](../decisions/0016-normalized-state-id-allocation.md), §4.4 →
> [0017](../decisions/0017-degenerate-shapes-are-contract-violations.md). §4.5's
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
- [decision 0009](../decisions/0009-content-and-ir-fingerprints.md) — the IR
  fingerprint §4.1 and §4.3 are designed to leave in place.
- [decision 0010](../decisions/0010-direct-executor-abi.md) — the direct-executor
  ABI (**item 4**: extension by version, the warrant for §8's no-`/v3` boundary).
- [decision 0011](../decisions/0011-eof-execution-model.md) — the EOF execution
  model whose chain §4.2's corollary discusses.
- [decision 0012](../decisions/0012-generated-abi-v2-finish.md) — `/v2` (**item 3**:
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
