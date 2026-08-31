# Milestone 4 Design — Fields, Actions, and Branches

Status: **NOT STARTED.** Gate 0 not yet discharged; no slice begun. Authored
2026-08-31, the day Milestone 3 closed (Slice ③ merged as PR
[#35](https://github.com/Kiyomi-Computation-Systems/byte-machine/pull/35),
commit `2351b58`; the standards follow-up as PR
[#36](https://github.com/Kiyomi-Computation-Systems/byte-machine/pull/36),
commit `a942327`). Written after an eight-agent audit of this milestone's
requirements against the shipped tree at `a942327`, followed by a design
conversation in which four calls were settled by the owner: the milestone lands
the twice-deferred `parser-error-*` family; the generated ABI stops versioning
its constructor *name* while keeping its version *check*; the milestone is cut
into four product slices rather than three; and the `eof-terminal` rewrite is a
task inside Slice ② rather than a slice of its own.

Governing plan:
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md) §25
("Milestone 4: Fields, actions, and branches"), scope §25:1559-1564, exit
criteria §25:1568-1570. This document does not change M4's *scope*. It re-cuts
M4 *internally* into an ordered Gate 0 plus four slices; resolves the design
calls the parent plan leaves open — the twice-deferred `parser-error-*` family
(§9.3:397-405) with §17:963's debug map, the generated-ABI constructor collapse
with the version bump to 3 (§9.5:442), and normalized encoding format v2, none
of which §25's Scope list names; and admits **four** obligations that §25's
scope bullets do not name but that landing fields plainly requires (§4.7
enumerates them). Where this document and §25 differ in wording, §25's Scope
list remains authoritative and this document records how that scope is sequenced
and delivered.

## 1. Summary

Milestone 3 widened what a transition can *match* — byte classes and exact
sequences — without the machine acquiring any memory. Every construct shipped
through M3 is a pure function of the current byte and the current state.

Milestone 4 gives the machine **state that outlives a transition**. That is a
larger change than the node count suggests, and it is the first milestone that
moves every layer at once:

- **Three new node kinds**, where M3 added one. Two are zero-width (field
  action, field branch) and one is input-reading (integer accumulate).
- **A new *declaration* kind** — `make-uint-field` — which is the first addition
  to the machine descriptor's declaration set since M1.
- **A runtime and generated-ABI change**, which M3 explicitly declined
  ([milestone-3-design.md](./milestone-3-design.md) §8: "Any `runtime.sls`
  change for sequence support, and any `/v3` ABI"). Field values have to live
  somewhere the parser can reach, and `parser-reset!` has to restore them
  (§12.5:738) with no `exec` call in flight.
- **The first rewrite of a shipped verification analysis.** `eof-terminal` is
  structurally single-successor; a field branch has two targets by §10.6:582.

M4 is one milestone delivered as an ordered Gate 0 plus four slices:

| Phase | Kind | Produces | Discharges |
| --- | --- | --- | --- |
| **Gate 0** | decisions only | 5 records | the calls §25, §9.1, §9.3, §9.5, §12.7 and §16.2 leave open |
| **Slice ①a — The seam** | product | the unversioned generated-ABI constructor; normalized encoding format v2, pre-provisioning the field table and carrying the error `reason`; the `parser-error` record and its accessor family; the state-id→source-name debug map; all three of §12.7's position kinds against shipped node kinds; the milestone's single re-baseline | **no** §25:1559-1564 bullet; exit :1570's error clause (§22.4:1271); §9.3:397-405; §17:963 |
| **Slice ①b — Field declarations and storage** | product | `make-uint-field` and its validation; the `fields` argument becoming load-bearing; verify pass 6a's declaration half; field slot assignment; the parser's field-storage slot; `parser-field-ref`; `parser-reset!` restoring initials | §25:1559 whole; the **declaration** share of :1564's "field diagnostics" plus its accessor `parser-field-ref` (§9.3:410, read-only per §13:801); exit :1568's declaration-time bounds; exit :1570's "final state and fields" clause (§22.4:1267), first comparison |
| **Slice ② — Field action and field branch** | product | the `eof-terminal` multi-successor rewrite; both zero-width node kinds and every verifier arm; seven operations and seven predicates; verify pass 6a's operand half; normalized kinds 5 and 6; the preflight bound check written twice; the `boundary` position row | §25:1560, :1562, :1563; the **operand** share of :1564's "field diagnostics"; the seven-operation shares of exit :1568 and :1569; :1570's "final state and fields" comparison extended over the two zero-width kinds |
| **Slice ③ — Integer accumulate** | product | the input-reading node kind; the checked multiply-add; bases 10 and 16 with their all-256 partitions; the four paths and the EOF chain; fragmentation across a split number; the `byte` position row; the property generator's field draw | §25:1561; :1564's **accumulate** share by reuse, with no new diagnostic code; the accumulate shares of exit :1568 and :1569; :1570's same comparison extended over the accumulate kind |

Scope bullet §25:1564 has four claimants and no half: ①b the declaration
diagnostics and the accessor, ② the operand diagnostics, ③ the accumulate share
by reuse, and Milestone 5 the caller that makes the access callback-visible. §6
elaborates that split; §7 and §8 cite it rather than restate it.

**Dependency order is strict, and the ①a/①b split exists for one measurable
reason.** Every change that moves an emitted byte or a fingerprint is
concentrated in ①a, which contains no fields and no node kinds; ①a reserves the
encoding's field-table slot and the ABI payload's field-initials slot as empty,
so existing machines keep encoding a field count of zero and **①b moves no
existing golden and no existing fingerprint**. §2 gives the cost model, §5 the
measured bill, §6 the demonstration that it stayed paid. Slices ② and ③ then add
node kinds whose oracle is the interpreter≡generated differential rather than a
byte comparison.

Every slice runs in **both execution lanes** (source and AOT) and is checked by
the **interpreter≡generated differential** (parent §18, §22.4).

## 2. Why this shape

**Why the seam comes first, and alone.** The expensive unit of work here is not
code, it is the re-baseline: pinned IR fingerprints, committed goldens, and
mutation pins carrying measured `got` digests that must be re-*measured* by
staging the mutation rather than recomputed. Three separate changes in M4 move
emitted bytes — the ABI constructor rename, the encoding format bump, and the
richer error payload — and none is about fields. Bundling them with field
storage produces one PR in which a reviewer cannot tell which byte moved for
which reason; splitting them across slices pays the re-baseline two or three
times. Pre-provisioning the format in ①a pays it once *and* keeps each diff
readable, and it is why this milestone has four product slices where M3 had
three.

**Why the two zero-width kinds ship together and the input-reading kind ships
alone.** Field action and field branch hit the identical verifier sites, raise
the identical EOF-classification question, and need no fragmentation, all-byte
or need-input work; splitting them would double the verifier work for no new
oracle. Integer accumulate alone reads input, so it alone needs need-input
resumption, split-point fragmentation, all-256 sweeps and an EOF policy — and it
depends on the checked arithmetic Slice ② establishes for `add` and `increment`.

**Why `eof-terminal` is rewritten before either new kind exists.** It is the
only shipped analysis M4 rewrites rather than extends, and its `else` arms
accept an unhandled kind *silently*, so a rewrite landing beside a new node kind
has no clean oracle. §4.4 states the ordering and the refactor's own oracle.

**Rejected: bumping the generated ABI to `/v3`.** That is the precedent
([decision 0012](../decisions/0012-generated-abi-v2-finish.md) item 1, itself
following decision 0010 item 4), and it was rejected on measurement. `/v1` is
not a compatibility path: it requires `(= abi-version current-abi-version)`,
which is 2, so it *rejects* the version it is named for. Its whole remaining
function is to make a stale generated file fail with a clean ABI-mismatch
assertion instead of an unbound-identifier import error, and its only two call
sites in the suite are the two tests that prove that. A `/v3` would add a second
dead-in-production variant arm, a second permanent export, a second
`reserved-member-2` entry and a second accessor pair — and M5 (callbacks) and M6
(counted consume) plausibly move the same seam again. §4.1 keeps what the
versioning buys and stops the family growing.

**Rejected: deferring the `parser-error-*` family a third time.** It has been
deferred twice, to "M4/M5", by [milestone-2-design.md](./milestone-2-design.md)
§7 (:461-464); the rule forbidding the population of one field of an
otherwise-deferred accessor family is that document's §5 (:343-344). M4 produces
two new rows of §12.7's position table, and §22.4:1271 makes the differential
compare "error domain, code, public source-node name, absolute position, and
position kind" — so a third deferral would make M4's own exit criterion :1570
unassertable in the terms §22.4 states it. The family is also *front-loadable*,
which is not obvious: all three position kinds are already producible by node
kinds shipped in M1 and M2 (§12.7:766-773), so ①a can prove the whole family
before any M4 node kind exists, and ② and ③ each add one row to a table that
already works.

**Rejected: a shared arithmetic module between the interpreter and the
emitter.** §18:970-972 makes interpreter independence normative, decision 0015
point 3 restates it, and `interpret.sls` pre-refuses the refactor in a comment.
The seven operations, the seven predicates and the preflight bound check are
written twice on purpose: a shared module would make a lowering bug in overflow
checking invisible to the differential, the single class of defect this
milestone introduces.

## 3. What the parent plan already settles

Recorded here so it is not re-litigated during implementation. None of the
following is an open design call.

- **The public construction surface is fixed by §9.1:283 and :301-306.** One
  field constructor (`make-uint-field name width initial source-label`) and
  three node constructors. There is exactly one field *type*; §29:1754 defers
  additional types.
- **"Flag set/clear" (§25:1562) is `set-mask`/`clear-mask`, not a new
  declaration kind.** §10.2:493: "Flags use unsigned bitfields." Reading :1562
  as a boolean field type contradicts both that line and §29:1754.
- **The operations and predicates are closed enumerations with exact `arguments`
  schemas** — seven each, tabulated at §9.1:328-334 and :336-346. §9.1:348
  states what the verifier enforces over them and adds: "it rejects arbitrary
  operation names or extra arguments."
- **Field action and field branch are zero-width; integer accumulate is
  input-reading.** §10.6:550, :575, :571 and §11.4:652. This classification is
  what every verifier extension in ② and ③ turns on.
- **Overflow leaves the prior value unchanged and does not consume the offending
  digit.** §10.6:568, §15:870, §12.7:773. The second clause fixes the position
  kind and `next`, not just the field value.
- **The checked multiply-add's inequality is given, not chosen.** §15:864-868.
- **Failed operations leaving prior values unchanged (exit §25:1569) is a
  *preflight* property, not a rollback.** §15:856 requires the declared bound to
  be checked *before committing every operation*, so no uncommitted value is
  ever written, and §15:870 says the same for the multiply-add. Every commit is
  therefore a single store of an already-checked value, never a store followed
  by a range test.
- **Fields are parser-owned mutable state.** §7:140 — "Parser: mutable instance
  of a compiled machine, including state, fields, callback bindings, offsets,
  and lifecycle status." What §7:140 does *not* settle is when a write becomes
  visible on the parser object; that is a design call, resolved in §4.6.
- **Machine-field access from a callback is read-only** (§13:801). M4 ships the
  accessor; M5 ships the caller. There is no mutating sibling to design.
- **Parser bookkeeping is not exposed as machine fields** (§10.2:495) — state,
  lifecycle, callback vector, user context, cursor, stream offset and span
  markers stay out of the field set.
- **`#f` as an input node's `eof-target` means the machine default EOF error**
  (§9.1:318), and that applies to integer accumulate because it is an input
  node.
- **Diagnostics compare structure and codes, never rendered text** (§16.4:945).
- **Unreachable nodes are errors in v0.1** (§16.4:947), but a spurious `error`
  target on a safe operation is not one: `node-out-targets` feeds it into the
  reachability walk whenever it is a symbol, so it is *reached* and no pass
  catches it. That is why §4.3's `#f`-when-the-operation-cannot-fail rule is
  enforced at the constructor — the only place that can.
- **The interpreter may not share the normalizer's lowering** (§18:970-972). See
  §2's last rejection.

## 4. Gate 0 — design-call resolutions

Decision-only. No product code is written in Gate 0. writing-plans assigns the
record numbers (next free in `docs/decisions/` is **0018**) and confirms whether
any splits or merges of the five below are warranted.

### 4.1 The generated ABI keeps its version number and drops its versioned name

Replace the `byte-machine-make-compiled-machine/vN` family with one unversioned
`byte-machine-make-compiled-machine` whose **first** action is the `(=
abi-version current-abi-version)` check, and whose payload is carried so that it
can grow without an arity break. `/v1` and `/v2` remain exported as tombstones
for the two shapes already emitted, so a stale generated file still fails with a
clean ABI-mismatch assertion rather than an unbound-identifier import error.

The version *check* stays load-bearing for a reason specific to this project:
Chez prefers a compiled object over source and staleness is transitive across
imports, so a stale compiled object of a generated library really can meet a
newer runtime inside this repository's own build. What the check does not need
is a new *name* per change.

This **amends [decision 0012](../decisions/0012-generated-abi-v2-finish.md) item
1**, whose text binds both the `/vN` name and the constant bump, and it adds a
Milestone 4 parenthetical to **§9.5:442** — the line naming
`byte-machine-make-compiled-machine/v1` as the reserved binding, whose Milestone
2 parenthetical is the precedent for amending it in place. §9.5:444 needs no
correction: all three of its requirements — a generated-ABI version bump,
deterministic regeneration, and a CHANGELOG entry — are *satisfied* here. The
version **number** bump is the requirement and it survives; only the versioned
*name* goes. 0012 gets a dated amendment note, not a rewrite: the tree it was
decided against is its evidence.

**A vocabulary sweep found a second record to annotate, and it matters more than
0012.** [Decision 0010](../decisions/0010-direct-executor-abi.md) item 4 carries
the *general* rule this resolution replaces — the seam "extends by a `/v2`
constructor rather than an arity break" — and it, not 0012, is what a reader
looking for "how do we change the ABI" reaches first. It takes its own dated
note. That note must also say what the rename does **not** reach: 0010's
Consequences separately reserve a benchmark-gated `feed-outcome` `/v2`, a
different family still gated on §23 evidence, which would otherwise read as
having died with the constructor it shares a suffix with.

### 4.2 The normalized encoding gains format version 2, pre-provisioned

Bump the canonical encoding's format version from 1 to 2 in Slice ①a, and in the
same bump introduce (a) a field-table slot, empty until Slice ①b, and (b) the
error declaration's static `reason`, which normalization discards today.

The empty table is deliberate and needs its justification recorded, because a
reviewer cannot derive it from ①a's diff. Without it, ①b's field table is a
second format change and a second re-baseline; with it, ①b's new content is a
count that was already zero. The same argument covers the ABI payload's
field-initials slot, which ①a reserves empty for the same reason. This is a
format decision, not a transformation, so §17:966's prohibition on speculative
transformations does not reach it.

**The reservation covers three slots, and the third is easy to miss.** Besides
the encoding's field table and the ABI payload's field-initials member, `exec`'s
own parameter list must be widened in ①a. The emitted signature is fixed at six
parameters in the template (pre-slice, `compile.sls:156`) and called with six
arguments at two sites (pre-slice, `runtime.sls:218` and `:262`). A field store
added to it in Slice ② would change the emitted text of *every* machine,
including the zero-field ones, and every golden would move in ② — falsifying
this record's own guarantee one slice after it is made. ①a therefore emits the
seventh parameter and passes an empty vector for it, exactly as for the other
two slots.

### 4.3 Field shape is a constructor contract; operand and cross-reference checks are the verifier's

**Constructor** — closed-set membership and the local shape of the one value
being built: `operation` and `predicate` in their closed sets, `width` in {8,
16, 32, 64}, `base` in {10, 16}, `initial` an exact integer within the declared
width, `arguments` a proper list, names and targets symbols. Plus the
`error`-slot rule below.

**Verifier (new pass 6a)** — everything relational: exact arity against the
operation, declared-field references, operand and mask range against the
*referenced field's* width, `low <= high` for `range`, duplicate field names,
and portable field names.

[Decision
0017](../decisions/0017-degenerate-shapes-are-contract-violations.md)'s
reasoning does **not** transfer. 0017 turned on §16.2 containing no
invalid-matcher entry at all; §16.2:889 explicitly names "invalid field widths,
initial values, constants, masks, and operations". The precedent that does
transfer is `make-edge`, which `memq`-checks `mode` at construction even though
§16.2:896 assigns advancement modes to the verifier — and, measured,
`verify.sls` carries no advancement-mode arm at all. A reader who finds these
two precedents and no record will reverse-engineer a rule from them; this record
is why it needs writing down.

**One rejection site per decision.** Where the constructor closes a set, no pass
re-checks it: the pass records the assignment in place, the way `pass-overlap`
records its non-extension. That governs §16.2:889's widths, initial values and
operations *and* §16.2:904's `base`, uniformly — no slice keeps an unreachable
defence-in-depth diagnostic arm for a value its constructor already rejects. Two
reasons, both measured: a second rejection site splits one decision's mutation
witness across two places, and `SITES` is asserted exactly and fails in both
directions (AGENTS.md:147); and an arm no public API can reach cannot be
witnessed at all, so it ships dead and owes an `EXPECT_SURVIVES` — the trap §6
task 3 documents for `pass-schema`'s version check.

**The `error` slot rule.** `make-field-action-node`'s `error` parameter names a
**target node**, and must be `#f` **exactly when the operation cannot fail**.
`store`, `clear`, `set-mask` and `clear-mask` provably cannot fail once the
constant or mask is range-checked against the field width; `increment`,
`decrement` and `add` can. Permitting a target on the four safe operations would
not fail loudly: `node-out-targets` feeds a symbol `error` into the reachability
walk unconditionally, so the target is *reached* and no pass checks whether the
operation can actually fail — the constructor is the only place that can.
Precedent for a target-or-`#f` slot: `eof-target` (§9.1:318).

### 4.4 EOF-chain classification generalizes to multi-successor zero-width nodes

`eof-terminal` walks one successor per step. A field branch has an explicit
target for every possible result (§10.6:582), so the walk becomes a search and
the verdict is the worst case over all paths: any path reaching a stop yields
`eof-reachable-stop`, any cycle yields `cycle`. The `seen` list becomes
per-path, or the join tolerates re-visits.

The rejected alternative was forbidding field-action and field-branch nodes on
EOF chains. [Decision 0011](../decisions/0011-eof-execution-model.md) item 3
already declined an "eof-target must resolve directly to a terminal"
restriction so that intermediate nodes could sit on an EOF chain; forbidding an
entire node kind there would re-impose that restriction for two kinds
specifically, and the rejected alternative supplies no justification for
singling them out. A machine that, at EOF, branches on whether a length field
was ever set is a legitimate use of that permission, and the branch cannot be
resolved statically: field values depend on consumed input. This extends
0011's analysis without changing its rules.

**The walk is one DFS carrying two structures, and that settles the join.** A
path stack detects cycles — a back edge to a node on the current path is a
`cycle`, and only that is — while a global visited set stops a diamond being
re-explored, since two paths converging is not a cycle and re-walking the join
would make a branchy chain exponential. The verdict is the worst case over all
paths, with `unknown` eliminated by the rewrite rather than joined. This is
settled here rather than left to the implementing slice because "the `seen` list
becomes per-path" and "the join tolerates re-visits" are two different
algorithms with two different bugs, and choosing between them is a design call.

**The rewrite is ordered before either new kind exists.** It is the only shipped
analysis M4 rewrites rather than extends, and its `else` arms accept an
unhandled kind silently, so a rewrite landing in the same commit as a new node
kind has no clean oracle — a changed diagnostic could be either. It is therefore
Slice ②'s first task, executed as a behaviour-preserving refactor whose oracle
is "no diagnostic on any existing fixture changed".

### 4.5 The structured parser-error record

Fix the shape of the record behind §9.3:397-405's accessor family — domain,
code, reason, detail, public source-node name, internal state ID, absolute
offset, position kind — together with the state-id→source-name debug map
(§17:963) that makes `parser-error-node-name` answerable in generated code, and
the rule that the record is constructed identically in both lanes.

Two constraints come from outside §9.3. §12.7:777 makes source-node name,
domain, code, offset and position kind **semantic and required to match** across
executors, while explicitly excluding the internal state ID from differential
comparison. And §12.7:766-773's position table is the authority on which kind
each error source reports; M4 adds two rows to it (§4.5 fixes the record, Slice
② adds the zero-width-action row and Slice ③ the integer-overflow row).

### 4.6 Nine resolutions recorded here, not as decision records

- **The three new node kinds lower 1:1, as three new normalized state kinds**
  (encode tags 5, 6 and 7), allocating no internal states. A 1:N expansion into
  dispatch states cannot express the multiply-add — a dispatch state has no
  arithmetic slot — so "many states" would still need an arithmetic state kind,
  and would additionally pay decision 0016's allocator-interleaving cost for
  nothing. §17:961's "explicit ... control flow" is discharged by the explicit
  target slots the constructors already carry. `prefix-blocks` stays
  sequence-only, and that is correct rather than an omission.
- **Operation and predicate fan-out happens at emission time, not at runtime.**
  Each of the three kinds is one source constructor and one normalized kind
  carrying an operation or predicate tag; the emitter's `render-state-arm`
  expands that tag into straight-line code, seven arms for the operations and
  seven for the predicates. This satisfies §19.1:999's "direct code for each
  normalized node" without the runtime opcode interpreter §19.1:1002 forbids.
- **Field writes are made in place, at the operation.** §7:140 makes fields
  parser-owned mutable state but leaves the write *timing* open. The alternative
  §19.1:1004 literally describes — load the field vector into locals at `exec`
  entry, thread it beside `pos` and `off`, write back at return and callback
  boundaries — is rejected on §19.2:1009's "selected for simplicity, not
  speculative density optimization" and on the cost of threading a vector
  through every arm of three new state kinds; §19.2:1011 admits exactly the
  "generic exact arithmetic with declared-bound checks" in-place writing is. The
  observable floor is §13:816-818, "fields include every operation completed
  before the callback"; locals-then-commit meets it too, so :818 does not
  *force* the choice. What in-place writing defers is :1004's
  **exception-safety** clause — a nonlocal escape mid-`exec` leaving the parser
  holding values no returned result reported. M4 has no producer for one:
  callbacks are M5 (§9), so the only mid-`exec` escapes are internal assertion
  violations. M5 discharges it with §12.6:749's `dynamic-wind` poisoning plus
  the poisoned-row answer §6 already flags for `parser-field-ref`.
- **For §16.2:908 (non-EOF control flow into a finish terminal) and §16.2:909
  (EOF-reachable stop terminals), the two zero-width kinds follow the *pause*
  precedent, not the dispatch precedent.** The dispatch precedent is an
  unconditional filter on the source node's kind; the pause precedent is
  byte-reachability-gated, under decision 0011's reasoning that an
  eof-only-reachable zero-width node legally continues into a finish node while
  a byte-reachable one must not. Field action and field branch are zero-width
  like pause, so that reasoning applies verbatim. Integer accumulate is
  input-reading and follows the dispatch precedent instead.
- **Two new diagnostic codes, not more.** `invalid-field-declaration` covers
  duplicate field names and portability; `invalid-field-operand` covers arity,
  undeclared reference, and operand and mask range. Width, initial value,
  operation, predicate and `base` carry **no** diagnostic code at all — §4.3
  closes them at the constructor, and a contract violation is not a diagnostic.
  The offending **field** name goes in the diagnostic's existing `node` slot,
  following the shipped sites that already carry non-node symbols there.
  Widening the diagnostic *record* to §16.4's seven fields is Milestone 7
  (§25:1615-1616).
- **§16.2:904 has no independent content in v0.1, in either half.** Its
  *incompatible field* half: with exactly one field type and four widths, each
  of which holds every digit of both supported bases, "incompatible" is
  coextensive with §9.1:348's declared-field-reference rule, so implement it as
  that check and record the reasoning rather than inventing a distinction. Its
  *unsupported base* half: `base` is a two-member set closed at the constructor,
  so by the one-rejection-site rule the pass records the assignment in place
  instead of carrying an unreachable arm. §29:1754 defers additional field
  types; the first half acquires content then.
- **The hexadecimal digit repertoire is `0-9`, `A-F`, `a-f`.** Genuinely
  unspecified upstream: §21.2 leaves four names unexpanded — `HEXDIG` and
  `HEXDIG-with-value-zero` (:1079-1080), and `ALPHA` and `DIGIT` (:1073, :1087)
  — and of those only `HEXDIG` is ambiguous in a way that changes the byte set,
  because RFC 5234's `HEXDIG` is uppercase-only while `DIGIT`'s `0-9` is settled
  by any reading. §21.2:1104 already makes the transfer-coding token
  case-insensitive, and chunk sizes are read case-insensitively in practice.
  This must be settled before the first all-byte test is written, because
  §22.7:1301's test asserts a specific 256-way partition.
- **No predicate canonicalization.** Ship seven predicate arms; do not rewrite
  `nonzero` as `zero` with swapped targets, or `mask-none` as `mask-any`.
  §17:966 forbids speculative transformations, and canonicalizing would change
  the public source-node identity reported in diagnostics (§12.7:758) and in the
  §17:963 debug map.
- **Exit criterion §25:1570's "traces match" is discharged by §22.4:1262-1272's
  comparison list.** §18:974-985 makes the trace hook interpreter-only and
  opt-in, so generated code has no trace surface at any milestone and a literal
  cross-lane trace comparison is unspecifiable; §22.4 is the section that
  enumerates what the differential compares, and it lists no trace. The other
  exit criterion that says "traces" is **Milestone 8's** (§25:1648), sitting
  beside §21.3:1114's *fixture event trace* — a callback-event sequence, which
  is M5 vocabulary and later; and Milestone 5's own exit criteria do not mention
  traces at all. Per AGENTS.md the criterion is **not reworded**: it gets a
  dated disposition naming this reading, not a limitation record.

### 4.7 Four admitted scope additions, each a demonstrated gap

§25:1559-1564 does not name these. Each is a check or a guard that is *listed
and unimplemented*, or a latent defect, in code this milestone already edits —
the project's rule is that a guard shown not to guard gets closed, not
documented and not deleted. Each was put to the owner and approved on
2026-08-31, and they are listed together so a reviewer meets them as a set
rather than one at a time in four different diffs.

1. **`pass-names-valid` does not check error `reason` strings** (pre-slice,
   `verify.sls:461-477`), though §16.2:886 requires "nonportable names, codes,
   branch keys, labels, or reasons" and §10.1:480 restricts reasons to printable
   ASCII plus LF. The gap has been inert because the emitter has never written a
   user-controlled string. Slice ①a makes it live: carrying `reason` into the
   `parser-error` record means an author-supplied string is written into
   generated Scheme source, so a reason containing `"` or `\` yields a generated
   library that does not parse, failing as a Chez reader error naming a temp
   file. Closed in **Slice ①a**, reusing the existing `invalid-name` code — the
   reading §16.2:886 supports, since it puts reasons in one portability bullet
   with names and codes — so §4.6's two-new-codes budget holds.
2. **`reserved-member-3` has no drift guard** (pre-slice, `compile.sls:53`, and
   `compile.sls:101-107` says so). M4 adds emitted locals in three slices.
   Closed in **Slice ①a**, before the first one lands.
3. **`pass-schema`'s §16.2:884 unsupported-IR-version check is listed and
   unimplemented** — `machine-ir-version` is stamped with no accessor anywhere,
   and the pass is a single `machine?` tag test. Closed in **Slice ①b**, the
   slice that teaches that same pass about field descriptors. (The plan line is
   **:884**; :885 is duplicate declaration names and :886 is the portability
   bullet item 1 cites.)
4. **`eof-target-of` has no else arm** (pre-slice, `interpret.sls:112-116`) and
   falls through to `byte-dispatch-node-eof-target`, a bare `(vector-ref n 4)`
   with no tag guard. On an integer-accumulate node slot 4 is `digit-target`, a
   symbol — so it returns a plausible node name and silently routes EOF into the
   digit path rather than failing. Closed in **Slice ③**, with tag guards on the
   byte-dispatch accessors, before the node kind that triggers it exists.

Nothing else beyond §25:1559-1564 is in scope. A fifth addition discovered
during implementation is a decision for the owner, not for the implementing
slice.

## 5. Slice ①a — The seam: ABI, encoding, and the parser-error record

Discharges **no** §25:1559-1564 scope bullet: this slice adds no field, no node
kind and no verifier check for either. It discharges exit criterion §25:1570's
**error clause** — §22.4:1271's "error domain, code, public source-node name,
absolute position, and position kind" — against node kinds already shipped in M1
and M2, and leaves that criterion's `final state and fields` clause (§22.4:1267)
to ①b, ② and ③. It is the whole re-baseline, paid once, in the slice whose diff
is small enough to read. Its oracle is: *no behaviour changed; the emitted bytes
and the encoding changed in exactly the ways this diff shows, and nothing else.*

**The sharpest hazard is the `/v2` tombstone, and it fails silently in the one
direction the tombstone exists to cover.** Pre-slice the two guards disagree
about where the number comes from: `/v1` tests `(= abi-version
current-abi-version)` (runtime.sls:51), `/v2` tests the literal `(= abi-version
2)` (runtime.sls:66), and they agree today only because `current-abi-version` is
2 (runtime.sls:49). The moment this slice bumps the constant, `/v1` becomes a
real tombstone that refuses everything and `/v2` becomes a **hole that accepts
exactly the stale files it was added to refuse**, defeating decision 0012 item
1's stated purpose. A stale `/v2` object then loads and runs — same `exec`
arity, nothing raises — and the first `parser-error-code` on its bare-symbol
error slot fails an arbitrary distance from the cause. Chez object staleness is
transitive across imports, so this is reachable inside this project's own build,
not only across releases, which is why the version check is load-bearing at all.
The fix interlocks with a second, *loud* failure: `MutationRunner.cmake:59`
asserts `SITES` exactly and the `/v1` guard text is pinned verbatim at
`SchemeMutationSuite.cmake:2544`, so writing the tombstone's new guard as a copy
of that line makes one FIND match two (then three) sites and the suite fails at
declaration. Task 3 writes the three guards as three textually distinct forms
and re-anchors both pins.

**The second hazard is that the differential's own tuple silently stops
comparing what §22.4:1271 requires.** Eight programs build a result tuple
containing `(parser-result-error r)` and compare interpreter against generated
by whole-value equality. Six end in that read
(`differential-one-byte-tests.sps:34`, `differential-eof-tests.sps:28`,
`differential-byte-class-tests.sps:50`, `differential-sequence-tests.sps:58`,
`differential-sequence-node-tests.sps:56`,
`differential-http-version-tests.sps:58`); two carry it before a trailing
`(parser-lifecycle p)` and take `(r p)` rather than a result alone
(`differential-pause-tests.sps:33`, `property-differential-tests.sps:38`).
Between them they drive sixteen CTest lanes (`test/CMakeLists.txt:931`…`:1303`).
Once that slot holds a record those comparisons go **red**, correctly and
immediately, because `parser-error-state-id` is deliberately lane-local:
§12.7:777 says generated IDs "are deterministic for a given normalized graph,
but an independently interpreted machine need not report the same ID.
Differential tests do not compare that accessor across executor kinds." The red
is not the hazard. The hazard is the obvious repair — replacing
`(parser-result-error r)` with `(parser-error-code (parser-result-error r))` —
which restores green while narrowing the comparison back to the single symbol it
compared before the family existed, so the family ships with no differential
behind four of its five comparable members. Task 5 lands one projection helper
with one owner, and Task 7 asserts the exclusion positively rather than by
omission.

1. **Portable reasons, at the verifier, before anything embeds one.**
   `pass-names-valid` (pre-slice, verify.sls:461-477) checks the machine name,
   node names, and error declaration names and codes, and checks **no reason**;
   §16.2:886's list is "nonportable names, codes, branch keys, labels, or
   reasons". §4.7 item 1 records why the gap has been inert (the emitter has
   never written a user-controlled string; its one string literal is `"unknown
   state"`, compile.sls:162) and why this slice makes it live. Extend the pass
   over `error-declaration-reason` with §10.1:480's repertoire ("printable ASCII
   plus LF"; see also §10.5:527's "static printable-ASCII reason"), reusing the
   existing `invalid-name` code so §4.6's two-new-codes budget holds. Extend the
   **existing `machine-errors` arm** (pre-slice, verify.sls:471-476, predicate
   `(and (valid-name? name) (valid-name? code))`) and its one diagnostic rather
   than adding a fourth arm, so one error declaration still yields at most one
   `invalid-name` finding; the message text is free, since §16.4:945 compares
   structure and codes and never rendered prose. Pair it with §20:1039's
   "explicit escaping" in the writer for the two characters still legal inside a
   bounded string, `"` and `\`, plus LF. Skipping this leaves not a missing
   check but an unparseable generated library, failing at the `(load genfile)`
   every differential lane performs
   (`differential-http-version-tests.sps:48-53`) as a Chez reader error naming
   the temp file. The writer half lands here but is first *observable* in Task
   5, which is what emits a reason; its gate carries the escaping check. **Gate:
   every shipped fixture still verifies with zero diagnostics; a fixture whose
   reason contains TAB (0x09) reports exactly one `invalid-name`; and a fixture
   whose reason contains `"`, `\` and LF verifies with zero diagnostics.**

2. **The record and its accessors, in the runtime, referenced by nothing.** Add
   the `parser-error` tagged vector beside the `parser-result` tag (pre-slice,
   runtime.sls:86-95), `parser-error?` (§9.3:397) plus the eight accessors of
   §9.3:398-405, and the generated-code constructor
   `byte-machine-make-parser-error/v1`. Mirror all ten into `reserved-member-2`
   (pre-slice, compile.sls:44-52, twenty symbols mirroring runtime.sls:11-18) in
   the same commit — decision 0012 item 4, guarded by
   `reserved-drift-tests.sps:32-40`. `domain` is `machine` and `detail` is `#f`
   at every M4 site; that is one enumerated *value* with no producer until M5,
   not a half-populated family, and milestone-2-design.md:343-344's rule against
   "populating one field of an otherwise-deferred accessor family" is satisfied
   because every accessor ships at once. **Gate:
   `byte-machine.unit.reserved-drift.chez.{source,aot}` green with member-2 at
   30 symbols (20 pre-slice + `parser-error?` + the eight accessors +
   `byte-machine-make-parser-error/v1`), and `rg` for the new names finds them
   only in runtime.sls and compile.sls.**

3. **The unversioned constructor, the two tombstones, the metadata vector, and
   `exec`'s reserved seventh parameter.** Execute §4.1: one unversioned
   `byte-machine-make-compiled-machine` whose first action is `(= abi-version
   current-abi-version)`, the constant bumped to 3, both tombstones rewritten to
   refuse every version — and, per the hazard above, in text distinct from each
   other and from the live guard. Execute §4.2's third reservation in the same
   commit: widen the emitted `exec` from six parameters to seven (pre-slice,
   `compile.sls:156`) and pass an empty vector at both call sites (pre-slice,
   `runtime.sls:218` and `:262`). It is dead weight in this slice and in ①b, and
   it is the whole reason Slice ②'s field store moves no golden; the new
   parameter's name joins `reserved-member-3` here, not in ②. Carry the growable
   payload as **one quoted vector**, not a rest-arg: a rest-arg lets the payload
   grow without a version bump, and the version check is the only thing standing
   between a stale object and silent wrong answers. It renders as `(quote #())`
   today, introducing no new callable identifier into the emitted body — the
   reason the existing arms say `(quote error)` rather than calling anything.
   Member 0 is the field initials, empty here. The version number is duplicated
   by construction: compile.sls does not import the runtime (compile.sls:14-17),
   so the emitted `byte-machine-make-compiled-machine/v2 2` literal (pre-slice,
   in `render-machine`, compile.sls:164) and `current-abi-version` are two
   independent constants with no static guard. They are bumped in one commit,
   and the sixteen differential lanes — which emit, `load` and `eval` against
   the live runtime — are the only thing that catches a disagreement. Recorded,
   not claimed: §20:1042's "embedded IR format version and generator version" is
   measured **unmet** and stays unmet here — `rg` finds no generator version in
   `src/` or `test/common/` — and the metadata vector is its home when a
   milestone claims it. Half-embedding it is worse than none. **Gate: `/v1` and
   `/v2` raise for every integer including 2 and 3; the unversioned constructor
   raises on 2 and succeeds on 3; member-2 is at 31 symbols with both tombstones
   still exported and the drift lane green; every runtime.sls pin still reports
   `SITES` 1.**

4. **Normalized encoding format 1 → 2.** In `encode-normal` (pre-slice,
   normal-ir.sls:251-282) bump the leading `(put-u8 p 1)` at :254, append the
   declaration `reason` after the code in both the error arm (:276) and the
   dispatch default-eof arm (:274), and write a `u16be` field count of zero with
   no per-field records; §4.2 records why the table is pre-provisioned empty.
   The reason must enter the *encoding*, not merely be read from the source
   machine: decision 0009 point 2 computes the IR fingerprint over the canonical
   normalized IR and §20:1043 makes it the object the determinism checks
   compare, so two machines differing only in a reason must differ in
   fingerprint or the fingerprint stops identifying what was emitted.
   Normalization currently **discards** reason: the `errcode` helper
   (normal-ir.sls:144-147) resolves a declaration name to
   `error-declaration-code` and nothing else. Add the §17:963
   state-ID-to-source-name debug map as a fifth member of the normal-machine
   vector (pre-slice, `make-normal-machine`, normal-ir.sls:28, today the
   four-slot `(vector nm-tag entry states fp)`; accessors at :30-32), total over
   internal prefix states too, mapping each to its declaring node's public name.
   `lower-machine` already builds the forward map in its `name->id` binding
   (normal-ir.sls:140-142), but that alist is local and `lower-machine` returns
   only `(values entry states)` (:248), so the map is built inside
   `lower-machine` and threaded out as a third value for `normalize-machine`
   (:284-286) to place in the vector; `name->id` covers declared nodes only, so
   the internal prefix states — numbered by `allocate-prefix-ids` (:128) from
   `declared-count` onward — get their entries from the prefix-block walk rather
   than from inverting it. milestone-3-design.md:1008-1009 already established
   that the map cannot perturb the fingerprint: "`encode-normal` is called as
   `(encode-normal entry states)` and never sees names" — still true at
   normal-ir.sls:285-286 (pre-slice). **Gate: all four pinned IR fingerprints
   move; each new value is measured once and written at every site; the
   subexpression `(encode-normal entry states)` and its two arguments are
   unchanged, even though its enclosing line :286 gains the debug-map argument
   to `make-normal-machine`; two fixtures differing only in an error
   declaration's reason string produce different fingerprints; a machine with no
   fields encodes a zero field count.**

5. **Both executors' error value, the emitter's two error-producing arms, and
   the differential projection — one commit.** They cannot be split: the two
   lanes are compared by value, so either both produce records or the
   differential is red between commits. *Position kind is not a property of the
   error state.* §12.7:768 assigns `byte` to a "reexecute mismatch", :769
   assigns `boundary` to an "error edge after an advance", :770 assigns
   `boundary` to a "zero-width machine action or callback failure", and :771
   assigns `eof` to "truncated input during `finish!`" — so it is a property of
   the transition that arrived, which the arm cannot see. Carry it as one more
   loop variable in each executor, set from a literal at each jump: `advance` →
   `boundary`, `reexecute` → `byte`, the EOF-chain jump → `eof`, and — the
   fourth case ①a cannot itself produce, stated here so ② and ③ inherit a rule
   instead of each picking one — **a zero-width jump → `boundary`, at the
   current stream offset, per §12.7:770**. **The loop-entry initialization is
   `boundary`, unconditionally, in both a feed call and a finish call — no
   `finish?` key.** Nothing has been consumed since either kind of call began,
   so an error state reached with no jump taken reports a boundary at the
   current stream offset regardless of which call observes it: the same value
   a feed resuming directly onto a pause's parked continuation already
   reports, and now the same value the interpreter's separate
   `parser-finish-op!` reports for that continuation too (decision 0022 item
   5), so the two lanes agree without reading `finish?`. The absolute offset
   needs no new arithmetic: `off` is already bumped on advance and not on
   reexecute, so `(off, pk)` *is* §12.7's stored position in both executors,
   which is the strongest available evidence the lowering is 1:1. In the
   generated lane the kind is a fourth argument to the emitted `loop` — the
   `(let loop ((pos start) (st state) (off offset))` header rendered at
   pre-slice compile.sls:157 gains a fourth argument, `(quote boundary)`,
   unconditionally, and both `loop-tail` forms, compile.sls:75-78, carry it
   forward on every advance/reexecute jump. In the interpreter it is a second
   loop variable in `parser-feed-op!`'s dispatch arm (pre-slice,
   runtime.sls:188-200, whose `(if (eq? mode 'advance) …)` at :196 already has
   the mode in hand), a constant `boundary` in `parser-finish-op!`'s error arm,
   and a constant `eof` in its dispatch arm's default-eof path (pre-slice,
   runtime.sls:274-311). *Static payload.* Render one immutable table per
   generated library — `(define errs (quote #(#(<code> <reason>) …)))`, one
   entry per error *declaration*, which is §19.1:996's "immutable
   field/callback/debug metadata" literally — and build the record at each site
   from that entry plus the site's own two literals and the loop's two
   variables; per-*site* literals would repeat each reason once per error site
   rather than once per declaration, and the default-eof arm alone renders at
   every dispatch state. Before
   (test/fixtures/generated-http-version.golden.sls:18, pre-slice): `((3)
   (byte-machine-make-feed-outcome/v1 (quote error) pos (quote unexpected-byte)
   3 off))`. After, in shape, the third argument becomes
   `(byte-machine-make-parser-error/v1 (vector-ref errs 1) (quote reject) 3 off
   pk)` — declaration entry, public source-node name, state id, absolute offset,
   position kind — and the outcome's own `next-state` and `off` arguments are
   untouched. The default-eof arm (pre-slice, `render-eof-branch`,
   compile.sls:95-99) takes the same shape with a literal `(quote eof)` and the
   *dispatch* node's name, which is where truncation was detected. `errs` and
   the loop variable join `reserved-member-3` (pre-slice, compile.sls:53) in
   this commit. *The record does not grow the seam.* `feed-outcome` keeps its
   five slots and its `/v1` constructor; its existing error slot merely carries
   a richer value (decision 0012 item 3: "`paused` and `finished` are new status
   *symbols*, not a new record"). The only reserved `feed-outcome` `/v2` is
   decision 0010's Consequences / Slice-B amendment, an **optimization** gated
   on §23 benchmark evidence that cannot exist yet — `bench/` holds exactly two
   files, both `.gitkeep`. The sticky-error rows (runtime.sls:150-151, :245-246)
   and `parser-set-stored-error!` need no edit, which is the amendment working.
   *The projection.* One new support library under
   `test/support/harness/byte-machine/test/`, exporting the §22.4:1271
   five-member projection and the excluded state id, added to the SOURCES of the
   sixteen differential lanes; it substitutes for the error member only, so the
   two `(r p)` helpers keep their trailing `(parser-lifecycle p)`. Eight local
   copies of a §12.7:777 reading is eight places for it to drift, and Task 7's
   positive exclusion check needs one owner. **Gate: every differential lane
   green with the projection in place; `rg 'parser-result-error' test/common/`
   shows no lane comparing a whole record across executors; and a fixture whose
   reason contains `"`, `\` and LF emits a library that `load`s, with its `errs`
   entry rendering `\"`, `\\` and `\n` rather than the raw characters — Task 1's
   writer half, first observable here.**

6. **The `reserved-member-3` drift guard.** `compile.sls:101-107` states the gap
   in its own words — `reserved-member-3` is "unchanged -- checked, not assumed,
   since it has no automated drift guard" — while `reserved-member-2` has had
   one since `reserved-drift-tests.sps:32-40`. This slice adds two entries to
   member-3, so the gap is demonstrated rather than theoretical. Build the guard
   the way `reserved-drift-tests.sps` builds member-2's: render a fixture
   exercising every state kind, `read` the emitted datum, collect every symbol
   **outside** a `quote` form, subtract `(environment-symbols (environment
   '(rnrs)))`, the runtime's export set, and the caller's binding, and assert
   the remainder is a subset of `reserved-member-3`. Skipping the `quote` forms
   is what keeps error codes, reasons and the metadata vector out of the
   measurement — and is why Task 1's escaping evidence must be stated separately
   rather than inherited from here. *Admitted scope addition 2 of §4.7.* **Gate:
   the new lane is green, and deleting one entry from `reserved-member-3`
   reddens it with a named symbol.**

7. **All three position kinds, asserted, against already-shipped node kinds.**
   All three kinds are reachable with byte-dispatch and error nodes alone —
   :768's `byte` from a reexecute fallback, :769's `boundary` from an
   advance-mode edge, :771's `eof` from a `finish!` over exhausted input — which
   is what makes the family front-loadable. :770's zero-width failure and :773's
   overflow rider need node kinds that do not exist until ② and ③; those are the
   two rows M4 adds to the *populated* table, not two rows added to the plan.
   Assert each kind in the interpreter and the generated lane, in the source and
   AOT execution lanes, and assert the state-id exclusion **positively**: both
   lanes report a state id, and the comparison deliberately omits it. **Gate:
   three position kinds × two executors × two execution lanes, all asserted by
   value, plus one check that fails if the exclusion is ever widened to drop a
   comparable member.**

8. **The pin sweep, the Pass 33 whole-pass audit, and the CHANGELOG.** All three
   of §9.5:444's requirements are met by this slice — the generated-ABI version
   bump (`current-abi-version` 2 → 3), deterministic regeneration, and the
   CHANGELOG entry. The parent-plan wording the slice amends is **§9.5:442**,
   which names `byte-machine-make-compiled-machine/v1` as the binding emitted
   bodies call and records the emitter as emitting `/v2`; §4.1 owns that
   amendment and decision 0012 item 1's dated note. **Gate: every pin below
   re-measured and re-anchored by LABEL; the Pass 33 whole-pass audit green in
   both directions against a merge-base control; `EXPECTED_PASSES` /
   `EXPECTED_MUTATIONS` at their measured values; `CHANGELOG.md` carrying the
   §9.5:444 entry.**

**Files and passes that must *not* be touched.** `verify.sls` takes exactly one
edit, Task 1's reason clause in `pass-names-valid`; every other pass is
matcher-, node- and field-agnostic in this slice, and an implementer "extending
every pass for M4" will break their pins for nothing. `graph.sls` takes none —
the accessor family is a runtime surface (§9.3), not a construction surface, and
§9.1 fixes what `graph.sls` exports. `ir.sls` takes none: `machine-fields`
(ir.sls:370) has existed and returned `'()` since M1, which is precisely the
precedent Task 4's empty field table extends. `interpret.sls`'s else-arm-less
`eof-target-of` (interpret.sls:112-116) is **left alone here**: it is §4.7 item
4's, closed in Slice ③, because its observable wrong behaviour needs a node kind
whose slot 4 holds something other than an EOF target, so fixing it now buys a
change no test in the tree can witness. `pass-schema`'s §16.2:884 IR-version
check is §4.7 item 3's, closed in ①b, the slice that teaches the same pass about
field descriptors. `machine-gen.sls` takes no edit either: ①a adds no drawable
construct, and §22.6:1295's "as each feature becomes available" puts the field
draw in Slice ③. Only the generator's remaining hardening — the bounded
invalid-machine generator and deterministic failure-seed reporting — is M7
(§25:1618-1621).

**Mutation pins that die in this slice.** Re-anchoring is a re-**measurement**
of each pin's failure signature, not a text edit, and per AGENTS.md:170-171 the
obligation is recorded in the tree by mutation LABEL rather than line number;
AGENTS.md:172-187 requires the sweep to run in both directions, including a
control on the merge base. Measured on the shipped tree by `FILE`, with 44
verify.sls, 42 runtime.sls, 24 compile.sls, 23 normal-ir.sls and 20
interpret.sls pins to sweep:

- **The whole of Pass 33** (`:3140`-`:4463`, "the verifier's decisions", 42 of
  the 44 verify.sls pins). Task 1 joins a check to `pass-names-valid` *and* a
  rejection case to the pass's lane, and adding a check widens every existing
  pin exactly as adding a mutation does — the trigger is "a check joined the
  pass", not "a code was reused". The three `invalid-name` pins (`:3421`,
  `:3484`, `:3490`) are case-anchored ("an uppercase machine name is
  invalid-name: invalid-name" and its two siblings), so the new case's NAME must
  not contain any of them as a substring; Pass 33's own header (`:3230-3241`)
  records that a case name containing an existing pin's regex broke three pins
  at once in M3 Slice ③. Run the whole-pass audit in both directions with a
  merge-base control, by the method that header describes. Pass 37's two
  verify.sls pins (`:5333`, `:5342`) target `valid-name?` itself, which Task 1
  reuses rather than edits; re-check their `SITES` rather than assuming them.
- Both ABI-guard pins. `runtime: a mismatched generated-runtime ABI version is
  accepted` (`:2543-2544`) and `runtime: a mismatched /v2 ABI version is
  accepted` (`:2724-2725`) both FIND guard text this slice rewrites, and the
  naive rewrite makes their FINDs identical — `SITES` is asserted exactly, so
  that is a hard failure, not a silent skip.
- `runtime: advance does not consume the byte` (`:2490`), whose FIND `(loop (+
  pos 1))` is `parser-feed-op!`'s loop tail and gains the position-kind
  argument. Every runtime.sls pin whose FIND text lies inside `parser-feed-op!`
  or `parser-finish-op!` must be swept for the same reason.
- Five compile.sls emitter-text pins: `compile: an advance transition is lowered
  as a reexecute` (`:5238`), `compile: the reexecute fallback is lowered as an
  advance` (`:5245`), `compile: the error arm omits the resolved code`
  (`:5252`), `compile: the exhausted-dispatch eof branch drops the resolved
  default-eof code` (`:5271`), and `compile: the final newline is emitted as
  CRLF` (`:5362`), whose FIND `" exec)))\n"))))` is the render tail the
  constructor rename rewrites. The finish, pause and transition-byte pins
  (`:5264`, `:5306`, `:5314`, `:5424`, `:5997`, `:6146`) survive textually and
  must be re-checked for `SITES`, not assumed.
- The seven pins carrying a measured `got` digest — `:4773`, `:4780`, `:4787`,
  `:4889`, `:4907`, `:4958`, `:4980` — all move when Task 4 bumps the format
  version byte, and `SchemeMutationSuite.cmake:843-852` already states why they
  are different in kind: "an expected golden is RECOMPUTED by re-running the
  lane, but a 'got' digest can only be RE-MEASURED, by applying that one
  mutation to a staged copy and reading what it printed." Staging is destructive
  to unstaged work; commit before measuring.
- Pass 49's branching-golden pass (`:6486`-`:6548`), whose narrative records the
  mutant's own byte count and its digest `14649231454401036534`; both are
  measurements of a golden that moves three times inside this slice.
- Rider: the format version byte at normal-ir.sls:254 has **no** pin — `rg` for
  its text in `SchemeMutationSuite.cmake` finds only the default-eof arm's
  `(begin (put-u8 p 1) …)` at `:4887`. This slice is the first to give that byte
  a second value, and the slice's own oracle ("the encoding changed in exactly
  the ways this diff shows") is otherwise unwitnessed, so it acquires one here.

**What the re-baseline costs, measured.** Task 4 moves every fingerprint,
because the format version byte is inside the hashed encoding (`(fnv1a-64
(encode-normal entry states))`, normal-ir.sls:286): four distinct values at
nineteen sites in `test/` and none in `src/`, enumerated per file in the exit
evidence, seven of them `got` digests that must be re-measured by staging. That
is the bill §4.2's pre-provisioning pays once instead of twice. The one
objection §4.2 does not answer — a field table nothing writes and nothing reads
— is answered by a shipped precedent: `make-machine` has carried a `fields` slot
with no downstream reader since M1 (ir.sls:352, :370), and this slice mirrors
that reservation one layer down.

**Exit evidence.** In the tree, at close-out: `pass-names-valid` rejects a
nonportable reason, every shipped fixture still verifies clean, and a reason
containing `"`, `\` and LF verifies clean, emits escaped, and yields a generated
library that `load`s. Pass 33's pin count is recorded as measured after the edit
(44 verify.sls pins by `FILE` pre-slice), and its whole-pass sweep is reported
in both directions against the merge-base control, with any residue recorded in
the tree beside its pin by LABEL. `reserved-member-2` holds 31 symbols and
`byte-machine.unit.reserved-drift.chez.{source,aot}` is green; the new member-3
drift lane is green and names a deleted entry when one is removed. `rg
'byte-machine-make-compiled-machine/v[12]' test/fixtures/` returns zero matches,
and all three goldens name the unversioned constructor, ABI version 3, and a
`(quote #())` metadata argument. Each of the four superseded fingerprint values
returns zero matches from `rg -o '<value>' test/ src/`, and each successor
appears at the same per-file counts (2 in `compile-tests.sps`, 3 in
`normal-ir-tests.sps`, 1 per golden, 11 in `SchemeMutationSuite.cmake`).
`parser-error?` is true at every error site of all three shipped fixtures in
both executors, with the five §22.4:1271 members equal across lanes and the
state id asserted present-and-excluded; all three §12.7 position kinds are
asserted in both executors and both execution lanes.
`EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (`SchemeMutationSuite.cmake:734-735`,
currently 46/236) are updated to the measured totals, not predicted ones; the
CMake mutation suite stays 1/72; the nine `EXPECT_SURVIVES` measured on `main`
are unchanged, shown by `git diff <merge-base>..HEAD --
test/support/cmake/SchemeMutationSuite.cmake | grep -E '^[+-].*EXPECT_SURVIVES'`
being empty. `ctest --preset release` and `--preset pr` are both green, at the
lane count measured at close-out rather than a count predicted here (86 today).
`CHANGELOG.md` carries the §9.5:444 entry. No file under `src/` mentions a field
beyond `machine-fields` and the encoding's zero count.

## 6. Slice ①b — Field declarations, storage, and the accessor

Discharges §25:1559 (`u8/u16/u32/u64 declarations and storage`) whole, and part
of §25:1564 (`field diagnostics and callback-visible field accessors`): the
**declaration** share of "field diagnostics", across the two mechanisms §4.3
assigns it to — widths and initial values are constructor contract violations
carrying no diagnostic code, duplicate and portable field names are the
verifier's — and the accessor itself, `parser-field-ref` (§9.3:410). The
*operand* share is Slice ②'s, the accumulate share ③'s; only the
**callback-visible** quality, a callback able to read a field read-only per
§13:801, waits on Milestone 5 (§25:1576, §25:1580). Of §25:1568 (`boundary,
overflow, and underflow tests for every width`), attributed in three parts, this
slice owns the **declaration-time bounds** — initial `0` and initial `2^w − 1`
accepted, `2^w` rejected *by the constructor*, all four widths — while the
operation matrix (underflow at `decrement`, overflow at `increment`/`add`) is
②'s and accumulate overflow is ③'s. Of §25:1570 it discharges §22.4:1267's
`final state and fields` clause, first comparison, for a machine that declares
fields but writes none.

**A field declaration that nothing reads is invisible all the way to the emitted
bytes, and every lane stays green while it is.** This is the slice's sharpest
hazard, and it is measured rather than inferred. `make-machine`'s collection
loop checks only `list?` over `(list fields callbacks spans errors nodes)`
(pre-slice, `ir.sls:357-360`), so any proper list passes as `fields`; its two
`for-all` guards (`:361-364`) cover `nodes` and `errors` only. `machine-fields`
(pre-slice, `ir.sls:370`) is then read by **nothing** — `rg 'machine-fields'
--glob '!docs/**'` returns exactly two lines, its export (`ir.sls:10`) and its
definition. It is absent from `graph.sls`'s export and mirrored `only`-import
lists alike (pre-slice, `graph.sls:12-25`, `:26-40`), from the normalizer's
`(only (byte-machine private ir) ...)` import (pre-slice,
`normal-ir.sls:15-25`), so `lower-machine` cannot see fields at all, and from
the emitter, which imports one source-IR name, `machine-name` (pre-slice,
`compile.sls:16`). `encode-normal` (pre-slice, `normal-ir.sls:251-282`) writes a
format-version byte, entry id, state count and per-state tags, nothing else. The
wrong behaviour is therefore total: a machine declaring `(make-uint-field 'count
8 7 #f)` and a machine declaring nothing produce the *same* IR fingerprint and
the *same* generated `.sls`, byte for byte. **Tasks 1 and 2 cannot be a
pull-request boundary**: at the end of task 2 a grammar author can construct and
export field declarations, the suite is green, and the feature does nothing. The
declaration and its first reader ship in one PR.

**The headline oracle is that this slice moves no existing golden and no
existing fingerprint.** §4.2 reserved the encoding's field-table slot and the
ABI payload's field-initials slot as empty in ①a, so ①b fills slots that already
exist and a zero-field machine still encodes a count of zero; this section is
where that reservation is shown to have paid. The surface that must not move is
the one §5 measured and re-baselined: five fingerprint literal sites carrying
three distinct values (`normal-ir-tests.sps:73`, `:122`, `:147`;
`compile-tests.sps:165`, `:212`), the three committed goldens in
`test/fixtures/`, and the seven mutation pins whose `EXPECT_OUTPUT_MATCHES`
embeds a fingerprint literal.

Tasks, in an order where each step's gate is what makes the next one safe:

1. **The descriptor, and the machine guard that makes it load-bearing.**
   `make-uint-field` per §9.1:283 — the shipped signature to match is
   `(make-uint-field name width initial source-label)` — plus `uint-field?` and
   one accessor per slot for §10.2:488-491's four parts, in `ir.sls`, on the
   shipped tagged-vector idiom (`tag` allocates a fresh vector, `ir.sls:41`;
   `tagged?` compares it with `eq?`, `:43`, which is why the tag is unforgeable
   from outside the library). Validation is §4.3's constructor half only,
   dispositioned there against §16.2:889 on the `make-edge` precedent
   (pre-slice, `ir.sls:202-203`): `width` in `{8, 16, 32, 64}` by `memq`, `name`
   a symbol via `require-symbol` (`ir.sls:44-47`), `initial` an exact integer
   with `(<= 0 initial (- (expt 2 width) 1))` (§10.2:490). Then `make-machine`
   gains `(for-all uint-field? fields)` beside its two existing guards. All
   fifty `(make-machine` call sites in `test/` pass `'()` for `fields`
   (measured: `rg -n --no-heading "\(make-machine" test/` → 50 hits, third
   argument `'()` at every one), so the guard is vacuously true across the
   existing corpus. **Gate: the whole `release` preset green with zero test-file
   edits.** If a lane reddens, the guard is wrong, not the fixtures.
2. **The façade, both lists.** `graph.sls` re-exports `make-uint-field`,
   `uint-field?` and the accessors, on M3 Slice ①'s matcher precedent —
   predicates and accessors came through the façade "because a grammar author
   needs to test the matchers they just built" (`graph-tests.sps:11-13`). The
   export list (pre-slice, `graph.sls:12-25`) **and** the mirrored `only` import
   list (`:26-40`) must both be edited; editing one leaves the constructor
   unreachable, silently at read time and loudly at first use. Machine
   *accessors* stay private, per the disposition at `graph-tests.sps:8-13` and
   §9.1's construction-only surface. **Gate:
   `byte-machine.unit.graph.chez.{source,aot}` builds a field-declaring machine
   importing nothing but `(byte-machine graph)`.**
3. **`pass-schema`'s unsupported-IR-version check (§16.2:884, §4.7 item 3) — and
   the observability trap it hides.** `machine-ir-version` is stamped as the
   constant `1` (pre-slice, `ir.sls:351`, into machine slot 1 at `:365`) with
   **no accessor anywhere**: `rg -n 'machine-ir-version|ir-version' --glob
   '!docs/**'` returns exactly those two lines. `pass-schema` (pre-slice,
   `verify.sls:107-108`) is a single `machine?` tag test, so §16.2:884's version
   half is listed and unimplemented, and closing it is two lines. **The trap is
   that no external test can reach the new arm**: `machine-tag` is a freshly
   allocated, unexported vector compared with `eq?`, so a test cannot forge a
   `machine?` object, and `make-machine` stamps a constant, so the public API
   cannot produce a wrong version. A naive check ships dead and its permissive
   mutation survives while the suite reports it caught. Pick a resolution in the
   tree, not implicitly: witness the check in the *restrictive* direction —
   mutate the supported-version constant, so every machine becomes unsupported
   and every verify lane reddens — and declare the permissive direction
   `EXPECT_SURVIVES` with a measured reason. The alternative, a test-visible
   construction path for the version, is not admitted by §9.1:281-282's fixed
   arity and should not be invented here. This is one of the two
   `EXPECT_SURVIVES` additions the exit evidence counts. **Gate: the new
   mutation is declared, its verdict measured on the staged tree, and its reason
   states what was run, not what was expected.**
4. **The field pass (§16.3:924's item 6, "Field and callback type checking"),
   declaration half only.** It carries the relational checks §4.3 assigns to the
   verifier — **duplicate field names** and **portable field names** per
   §10.1:480, reusing `valid-name?` (pre-slice, `verify.sls:43-50`). Widths and
   initial ranges are closed at construction (task 1) and must **not** be
   re-checked here: a machine whose field failed construction never exists, so
   the arm would be dead code whose permissive mutation survives — task 3's trap
   again — and the tree's SITES-2 split precedent
   (`SchemeMutationSuite.cmake:3459-3460`) then demands a per-site witness a
   dead arm cannot supply. Both new diagnostics carry
   `invalid-field-declaration` (§4.6's two-diagnostic-codes resolution) with the
   offending **field** name in the diagnostic's existing `node` slot
   (`make-diagnostic code node message`, pre-slice, `verify.sls:29`), following
   the shipped sites that already put non-node symbols there:
   `duplicate-error-declaration` (`:126-127`) and `missing-target` (`:133-134`).
   The diagnostic *record* is not widened to §16.4's seven fields; that is
   Milestone 7 (§25:1615-1616). Two facts justify a new pass rather than an
   extension. First, field names are invisible to `pass-names` (pre-slice,
   `verify.sls:112-145`), whose duplicate loops walk `machine-nodes` and
   `error-names` only, and to `pass-names-valid` (pre-slice, `:461-477`), whose
   three arms walk `machine-name`, `machine-nodes` and `machine-errors` — the
   third of them being where ①a's `reason` clause lands, so it still has three
   arms and still sees no field here. Measured: **two `u8 count` declarations
   verify clean today**, and once slot = declaration index lands in task 5 they
   take slots 0 and 1, after which `parser-field-ref` resolves `'count` through
   one name→slot map and answers with whichever entry it finds first, orphaning
   the other slot and its initial. Second, `pass-names-valid` must **not** grow
   a fourth arm — for §4.6's distinct-code budget alone, *not* pin collision:
   the three `invalid-name` pins (`:3421`, `:3484`, `:3490`) are each anchored
   on their own case name, and `invalid-name` is absent from the pass's five
   bare-code pins at `:3224-3228`. Recorded so the false reason is not
   re-derived. Do **not** head the pass `PASS 6` — `verify.sls:340`'s EOF-shape
   pass holds that string, and `verify.sls:190-200` refuses renumbering and
   names `pass-eof-execution` as the precedent for an unnumbered pass carrying
   its §16.2 citation instead. Name it, cite §16.3:924, add it to
   `verify-machine`'s `append` (pre-slice, `verify.sls:480-490`). **Gate: after
   tasks 3 and 4 together, run Pass 33's whole-pass pin sweep, both directions,
   with a control on the merge base.** Adding a check widens every existing pin
   exactly as adding a mutation does — the pass header records a 40-mutation,
   1560-ordered-pair sweep for that reason (`:3230-3241`) — and five of its pins
   are bare-code pins (`duplicate-name`, `missing-error-declaration`,
   `invalid-eof-target`, `invalid-shape`, `duplicate-error-declaration`, at
   `:3224-3228`) whose safety argument is that no sibling produces the same
   output. Two new codes and their rejection cases invalidate that until it is
   re-measured, and ①a's sweep cannot cover checks added after it; the
   merge-base control tells a collision this slice introduced from inherited
   debt (AGENTS.md:172-187).
5. **Slot assignment and the field table (§17:962, "assign field, callback, and
   span slots").** Slot index = declaration index: decision 0016 point 1's
   two-phase append applied to fields, whose first phase — every declared node
   keeping its declaration index — is a *declaration-order* identity, and
   §10.1:482 already says declaration order "provides stable IDs, generated
   order, and diagnostics after verification has established determinism."
   Fields have no second phase, because nothing synthesizes a field, so 0016's
   internal-state append does not transfer. The normalized machine gains a field
   table (name, width, initial, slot) and an accessor; `encode-normal` fills
   ①a's reserved slot with the count and one record per field, in slot order.
   `normal-ir.sls`'s export list grows; `compile.sls`'s `(byte-machine private
   normal-ir)` import (pre-slice, `compile.sls:17`) is unqualified and needs no
   edit. **Gate: the five fingerprint literal sites and three goldens named
   above are byte-identical to ①a's merged tree** — proved by `git diff --stat
   <①a merge commit>..HEAD -- test/fixtures/` showing only *added* files, not by
   `git status`, which is blind to a golden re-baselined inside a branch commit
   (milestone-3-design.md:450-454). One new fingerprint is measured and recorded
   for this slice's own field-declaring fixture.
6. **The parser gains field-storage slots, and the initials reach them through
   the ABI payload.** The parser is a fully occupied eight-element tagged vector
   at indices 0-7 (layout comment pre-slice at `runtime.sls:98`, `;; (vector tag
   variant executor entry current offset lifecycle stored-error)`; accessors
   `:124-135`). The values go in a new **slot 8, the ninth** — a mutable vector
   of exact integers indexed by slot — and the name→slot map in a new **slot 9,
   the tenth**, leaving the vector at ten elements and the layout comment two
   names longer. Two slots rather than a pair in one: the map is immutable and
   per compiled machine, the values mutable and per parser, and `parser-reset!`
   must write exactly one of them. **Storage cannot live in the shared
   `op`/`exec` closure**, built once per compiled machine and shared by every
   parser from it — `make-interpreted-machine` closes `op` over the verified IR
   once (pre-slice, `interpret.sls:117-127`) and `make-parser` (pre-slice,
   `runtime.sls:109-123`) copies it into parser slot 2 in all three variant arms
   — and the tree already builds many parsers per compiled machine,
   `(make-parser cm '() #f)` inside per-byte loops at
   `byte-class-interpret-tests.sps:19`, `differential-one-byte-tests.sps:32` and
   `determinism-http-version-tests.sps:59`, so closure-held storage would let
   one parser's writes be read by another. The initials must ride the compiled
   machine, because the parser holds a reference to nothing else; emitted
   literals cannot help, since the generated library exports exactly one
   binding, the compiled machine (§9.2:372;
   `generated-one-byte.golden.sls:19-20`, whose only other top-level definition
   is `exec`), and reset happens with no `exec` call in flight. §19.1:996
   already requires the generated body to carry "immutable field/callback/debug
   metadata". Follow the shipped per-lane asymmetry rather than inventing a
   uniform one — `make-parser`'s `'op` arm *asks* the closure (`(op 'entry)`,
   `runtime.sls:114`) while the `'v2` arm *reads a slot* (`:117-118`) — so the
   interpreter lane answers a new `'field-initials` message and the generated
   lane reads ①a's reserved payload slot. Nothing here emits a new local: the
   store first reaches `exec` in Slice ②, which owns that parameter's name and
   its `reserved-member-3` entry, and that is what keeps a zero-field machine's
   emitted text byte-identical to ①a's. `parser-reset!` then restores the
   declared initials per §12.5:738, and its comment (pre-slice,
   `runtime.sls:328`, `;; Field, span, and poisoned/busy state do not exist yet
   (M4/M5).`) is amended to name what now exists and what still does not.
   **Gate: the four `parser-reset!` mutation pins still match at `SITES 1` —
   `SchemeMutationSuite.cmake:2603-2606`, `:2610-2618`, `:2621-2630`,
   `:3030-3047` — and the fourth still survives.** `SITES` defaults to 1 and is
   asserted exactly, so a pattern that stops matching is a hard failure by
   design (`MutationRunner.cmake:59-62`), and `:3030-3047` is `EXPECT_SURVIVES`,
   which fails just as loudly if its mutant starts being caught (`:64-67`). Two
   of the four are single-line `FIND`s that survive an appended restore. The
   third (`:2621-2630`) was widened in Slice ③ to a **two-line** `FIND` spanning
   `(parser-set-offset! parser 0)` and `(parser-set-lifecycle! parser 'ready)`
   because the single-line form stopped disambiguating, so inserting the restore
   *between* those lines kills it for nothing; the fourth's `FIND` **is**
   `(parser-set-stored-error! parser #f)`, so appending after that line — not
   wrapping or re-indenting it — keeps it at `SITES 1` too. Append after the
   stored-error clear and all four live. This slice's own fifth reset mutation,
   the field-restore `EXPECT_SURVIVES` below, needs a `FIND` colliding with none
   of them inside a five-line procedure.
7. **`parser-field-ref`, and the lanes.** It does not exist: `rg -n
   'parser-field-ref' --glob '!docs/**'` returns nothing, and the parent plan
   carries exactly one occurrence, §9.3:410. **`parser-lifecycle` is the only
   §9.3 parser accessor the tree has shipped** — `parser-stream-offset`,
   `parser-state-name` and `parser-user-context` are absent (`rg` over `src/`,
   zero hits; only the *result* accessor `parser-result-stream-offset` exists) —
   and it (pre-slice, `runtime.sls:132`) is a bare `(vector-ref p 6)` with no
   `parser?` guard, so it is not the idiom to copy. §9.3:425 makes parser
   representations opaque and requires accessors to "enforce where fields such
   as `next` are meaningful", and §9.4:438 lists **accessor misuse** among the
   required condition codes, so `parser-field-ref` raises through
   `byte-machine-contract-violation` (`conditions.sls:19-20`, unchanged — a code
   is a symbol argument, not a new condition type) with a new `accessor-misuse`
   code joining the shipped `invalid-argument`, `invalid-slice`,
   `lifecycle-violation`, `unverified-machine`, `internal`. **Reading an
   undeclared field name is accessor misuse, not a diagnostic** — diagnostics
   are verify-time values about a machine, and none is being verified here — and
   a non-parser first argument is the same condition. Whether reading a field is
   legal in every lifecycle row is a §12.1 question the slice must answer
   explicitly rather than by omission: nothing in §9.3 gates it, and the M5
   poisoned row is the one that will. `parser-field-ref` is a new `(byte-machine
   runtime)` export, so `reserved-member-2` (pre-slice, `compile.sls:44-52`)
   gains it in the same commit — `reserved-drift-tests.sps:32-40` asserts set
   equality against `environment-symbols`, so omitting it reddens
   `byte-machine.unit.reserved-drift.chez.{source,aot}` rather than drifting
   quietly. New lanes: none of the 86 lane names registered in
   `test/CMakeLists.txt` contains `field`, so there is no duplicate-CTest-name
   `FATAL_ERROR` to design around, unlike M3 Slice ②'s `sequence` collision.

**Is a field nothing writes enough observability to prove storage?** Partly, and
the slice must say where the line falls. Provable here: both executors construct
field storage, initialize it from the same declared initials, and answer
`parser-field-ref` identically at every lifecycle point a feed schedule reaches
— §22.4:1267's "final state and fields", across `source` and `aot`. Two
mitigations make that comparison capable of failing. First, **a distinct
non-zero initial per width**, so a lane that zero-fills, reads the wrong slot or
transposes two slots gives a wrong answer rather than a coincidentally right
one; an all-zero fixture passes under every one of those defects. Second, **a
u64 initial at or above `2^60`**, exactly the bignum boundary on this host:
measured under the project's Chez (10.4.1, `/opt/homebrew/bin/chez`),
`(fixnum-width)` is **61** and `(greatest-fixnum)` is **1152921504606846975** =
`2^60 − 1`, so `2^60` is the first non-fixnum while u32's maximum `4294967295`
is still a fixnum. Without a u64 fixture above that line all four widths
exercise the fixnum path only and §15:856's "must not rely on host fixnum width"
is untested. Emission needs no new machinery for it: all four IR fingerprints
already emitted as literals are bignums (measured with `bignum?`), written
through `number->string` at `compile.sls:164` (pre-slice) and read back exactly
in both lanes.

**Not** provable here is `parser-reset!`'s field restore: nothing writes a
field, so a mutant that skips the restore leaves the same values in place and
passes. That is the shape of the shipped, declared limitation on reset's
stored-error clear (`SchemeMutationSuite.cmake:3030-3047`, `EXPECT_SURVIVES`
with a measured reason, one of the nine) and takes the same treatment — declare
the mutation, do not omit it. `EXPECT_SURVIVES` inverts the expectation and
fails loudly if the mutant ever starts being caught
(`MutationRunner.cmake:64-67`), so Slice ②'s first `store` is *told* the
limitation has gone stale rather than trusted to remember. Record the obligation
in the tree beside the pin, named by mutation LABEL, not in the session ledger
(AGENTS.md:184-187).

**One rider for ② and ③, stated here because ①b is where the widths become
real.** §9 already records that §15:856 forbids the `bitwise-and`-to-width idiom
`fnv1a-64` uses (pre-slice, `normal-ir.sls:50-57`, correct there because FNV-1a
*is* defined modulo `2^64`); the consequence for this slice is that task 1's
constructor bound is the *only* range enforcement in the tree at slice end and
deliberately does not generalize. ② and ③ each owe their own
check-before-commit, and neither may reach for `mask64`.

**Passes and files that must *not* be touched.** A field declaration adds no
node, no edge, no byte and no target, so every graph-shaped pass in `verify.sls`
is untouched: `pass-overlap` (pre-slice, `:185-188`), `pass-sequence-ambiguity`
(`:246`), `pass-reachability` (`:252`), `pass-zero-progress` (`:261`),
`pass-eof` (`:342`), `pass-eof-execution` (`:394`). Those gain arms in Slice ②,
when the two zero-width kinds arrive and §16.2:908/:909 acquire field-action and
field-branch successors under §4.6's pause-precedent resolution — not here.
`pass-names-valid` gains no fourth arm, for task 4's distinct-code reason. In
`compile.sls`, `render-transition-arm` and `render-state-arm` (pre-slice,
`:80-138`) change not at all: ①b introduces no normalized state kind, so the
emitter's only edit is the construction line at `:163-165`. `reserved-member-3`
(pre-slice, `compile.sls:53`) is unchanged — the initials ride the payload as a
literal, not as a new emitted `define` or local — and ①a's newly installed drift
guard for it (§4.7 item 2) is what proves that, rather than the comment at
`compile.sls:101-107` that currently has to say "checked, not assumed". In
`interpret.sls`, `kind`, `dispatch`, `seq-step` and `eof-target-of` are
untouched; the `op` closure gains exactly one message arm beside the seven at
`:120-126`, inside the `case` at `:119-127` whose `else` is loud.
`eof-target-of`'s missing else arm (pre-slice, `interpret.sls:112-116`) is
**deliberately left broken here**: it is §4.7 item 4, fixed in Slice ③ beside
the first node kind that can expose it. `conditions.sls` is unchanged. An
implementer "extending everything for M4" will edit six verifier passes and two
emitter renderers for nothing and break their pins in the process.

**Mutation pins that die in this slice.** Two, plus one sweep obligation, each a
re-**measurement** rather than a text edit. (i) `"verify: the schema guard
accepts a non-machine"` (`SchemeMutationSuite.cmake:3461-3466`): its `FIND` is
`pass-schema`'s *entire* one-line body, so task 3's version check destroys the
anchor by construction — the check cannot be appended outside the `machine?`
branch, since `machine-ir-version` on a non-machine would fault before the
diagnostic could be produced. Re-anchor onto the shape task 3 ships and
re-measure its failure signature; its `invalid-shape` bare-code pin must be
re-judged against the new `unsupported-ir-version` sibling. (ii) `"runtime:
reset does not return the lifecycle to ready"` (`:2621-2630`): its two-line
`FIND` dies if the field restore goes between the offset and lifecycle lines and
survives if it is appended — task 6's gate. (iii) The Pass 33 whole-pass sweep,
both directions, with a merge-base control. Newly *created* rather than
re-anchored: `make-machine` has **no mutation pin of any kind today** (measured:
zero `byte_machine_mutation` declarations whose `FIND` names it), so `(for-all
uint-field? fields)` arrives unwitnessed and needs a new mutation. Pass 35's
`normal-ir` `FIND`s at `:4791` and `:4887` sit in the entry-id and dispatch-EOF
arms and are untouched by the field table, but the pass gains mutations for slot
assignment and for the field-table encoding.

**Exit evidence.** In the tree, all of: `make-uint-field`, `uint-field?` and its
accessors defined in `ir.sls` and present in **both** of `graph.sls`'s lists;
`make-machine` carrying a third `for-all`; `rg 'machine-fields' --glob
'!docs/**'` no longer returning only its definition and export, with at least
one hit inside the normalizer; a `machine-ir-version` accessor and a version arm
in `pass-schema`; the field pass in `verify-machine`'s pass list; a field table
in the normalized machine and in the encoding; a ninth and tenth parser slot, a
field restore in `parser-reset!`, and an amended reset comment;
`parser-field-ref` in `(byte-machine runtime)`'s export list **and** in
`reserved-member-2`, with `byte-machine.unit.reserved-drift.chez.{source,aot}`
green. In the lanes: new `byte-machine.unit.field.chez.{source,aot}`
(declaration rejection and acceptance, all four widths at `0`, `2^w − 1` and
`2^w`) and `byte-machine.differential.field.chez.{source,aot}`
(`parser-field-ref` agreeing across interpreter and generated on a fixture with
a distinct non-zero initial per width and a u64 initial at or above `2^60`), the
four-width loop carrying a completion sentinel that reads the **observed** count
rather than the test's own expectation (AGENTS.md:188-196), since no suite here
declares an expected case count and an exhaustive loop that never executes
otherwise passes vacuously. In the numbers, re-measured and not estimated:
`ctest --preset release` above the current 86 and `--preset pr` green; the
Scheme mutation suite above the current 46 passes / 236 mutations, with
`EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (`SchemeMutationSuite.cmake:734-735`)
updated to what was counted; the CMake mutation suite unchanged at 1/72;
`EXPECT_SURVIVES` moving **9 → 11**, the two additions being the reset
field-restore limitation and task 3's permissive-direction version check, each
with a reason stating what was run. And the headline, proved by cross-commit
diff against ①a's merge commit rather than by working-tree status: `git diff
--stat <①a>..HEAD -- test/fixtures/` lists only added files, and `git diff
<①a>..HEAD -- test/common/normal-ir-tests.sps test/common/compile-tests.sps |
grep -E '^[+-].*[0-9]{19}'` is empty.

## 7. Slice ② — Field action and field branch

Discharges §25:1560 (`store/clear/inc/dec/add`) and §25:1562 (`flag set/clear`,
which §3 settles as `set-mask`/`clear-mask` rather than a new declaration kind),
§25:1563 (`equality, zero, range, and mask branches`), and the **operand** share
of §25:1564's `field diagnostics` — the declaration share and the accessor
itself (`parser-field-ref`, §9.3:410) are Slice ①b's, ③ takes the accumulate
share, and only the "callback-visible" quality, a callback able to read a field
read-only per §13:801, waits on Milestone 5. Of exit criterion §25:1568
(`boundary, overflow, and underflow tests for every width`) this slice owns the
**operation** matrix — underflow at `decrement` from `0`, overflow at
`increment` and `add` from each width's maximum, all four widths — while ①b owns
the declaration-time bounds and ③ the accumulate overflow. It discharges
§25:1569 (`failed operations leave prior values unchanged`) for the seven
operations, and extends §22.4:1267's `final state and fields` comparison — exit
§25:1570 — over the two zero-width kinds, the first cross-lane comparison of
fields a machine actually *writes* (①b compared fields declared but never
written). The two kinds ship together for the reason §2 gives.

**Every `file:line` below was measured on `main` at `a942327` and drifts through
Slices ①a and ①b — and, within this slice, across tasks:** Task 1 moves
`eof-terminal` before Tasks 3 and 7 read it, Task 2 moves `node?` and
`node-name` before Tasks 4-7 do. Citations into the files this slice edits
(`private/ir.sls`, `graph.sls`, `verify.sls`, `private/normal-ir.sls`,
`compile.sls`, `runtime.sls`, `interpret.sls`, plus the `test/common/*.sps` and
`SchemeMutationSuite.cmake` sites named below) are therefore given as
**pre-slice** and name the construct, not only the line; no grep or link check
catches that class of staleness later.

**`eof-terminal`'s unknown arm is swallowed twice, so a zero-width kind on an
EOF path is accepted in silence and then hangs.** Pre-slice, `eof-terminal`'s
final arm is `(else 'unknown)` (verify.sls:385) and *both* callers discard that
answer: the `:909` walk's `(case (eof-terminal m t) ... (else '()))`
(verify.sls:417-424) and the byte-reachable-pause walk's identical `case`
(:449-456). Point a dispatch node's `eof-target` at a field-action node and the
whole §16.2:909 chain analysis stops there, reporting nothing: an EOF path that
reaches a stop terminal through one field action verifies clean, and an EOF
chain of two field actions targeting each other is never classified `'cycle`.
Neither runtime loop guards against that — `parser-finish-op!` says so in its
own header, "No local cycle guard: termination relies on the verifier's
eof-zero-progress-cycle/eof-reachable-stop checks having already rejected
non-terminating and stop-terminating EOF chains" (runtime.sls:275-280), and
`parser-finish-v2!` (:260-272) does not re-verify. This is the failure mode the
tree already measured once, recorded verbatim at verify.sls:307-318: a sequence
node whose mismatch edge reexecuted into itself "verified with ok #t and zero
diagnostics", and feeding it one non-matching byte "did not return: reproduced
under a timeout in both the interpreted lane … and the generated lane … since
neither has a local cycle guard and both rely on this REPORT set."

**Verify holds twelve of the tree's sixteen silently-failing kind-dispatch
sites, and it is the only surface whose silence is reported as a clean
verdict.** The appendix census is the count that makes that qualifier true
(AGENTS.md:317): 23 sites, sixteen silent, seven loud, all twelve of verify's
silent — it answers `'()`, `#f` and `'unknown`, and `verify` then reports ok
`#t`. The seven loud arms raise: `parser-feed-op!` and `parser-finish-op!`
(runtime.sls:201, :311), the normalizer's lowering `cond` and `encode-normal`
(normal-ir.sls:239, :280-281), `render-state-arm` (compile.sls:137-138),
`node-name` (ir.sls:347) and `interpret`'s `kind` (interpret.sls:90). The four
silent sites outside verify are not counterexamples, and must not be read as
loud either: `node?` (ir.sls:337-339) answers `#f` and is caught only at
`make-machine` (ir.sls:361-362); `prefix-blocks` (normal-ir.sls:166-174) skips,
which §4.6's 1:1-lowering resolution makes correct here; and `interpret`'s
`dispatch` (:91-104) and `eof-target-of` (:112-116) crash today in an unguarded
`vector-ref` and turn silent the moment a kind lands whose slots hold a
plausible value — the defect §4.7 item 4 closes in Slice ③.

1. **Rewrite `eof-terminal` to a multi-successor walk, behaviour-preserving,
   before either kind exists** — the ordering §4.4 fixes. Pre-slice
   `eof-terminal` (verify.sls:356-385) is structurally single-successor: every
   non-terminal arm ends in `(loop <one-target> (cons name seen))` — the pause
   arm at :366, the byte-dispatch arm at :379-381, the sequence arm at :382-384
   — and `seen` is one flat list threaded down that one path. §10.6:582 requires
   a field branch to have "an explicit target for every possible result", so a
   two-target zero-width node has no representation in that shape. The walk must
   answer over a *set* of successors, and §4.4 leaves two choices open that the
   implementer must not improvise. Both are made here, for the successor set as
   a whole, since field action is multi-successor too (`next` plus `error`):
   - **`seen` is per-path** — exponential in the number of branch nodes on a
     chain (2^k paths), where one shared `seen` tolerating re-visits is linear
     but reports `'cycle` for a diamond that merely re-converges, a false
     rejection. Take per-path and record the cost as accepted: EOF chains are
     short by construction. The over-rejection note in `reexec-targets`
     (verify.sls:293-305) is the precedent for recording a conservatism rather
     than removing it.
   - **Sibling answers join by `max` over one total order, `'unknown` least**:
     `unknown < finish < unresolved < error < default-error < eof-reachable-stop
     < cycle`. `'unknown` is the identity, never absorbing, so a branch one of
     whose arms genuinely cycles cannot report nothing. `cycle` beats
     `eof-reachable-stop` on two grounds already in the tree: a cycle is the
     non-termination neither runtime loop guards against (runtime.sls:275-280,
     :200), so it must survive a join; and it matches the shipped single-path
     order, where `(if (memq name seen) 'cycle` (:360) precedes `((stop-node? n)
     'eof-reachable-stop)` (:365). Only that pair is observable today — both
     callers' `case` maps every other answer to `'()`, and `'unresolved` is
     silent on purpose because `pass-eof` reports the missing target (:362) —
     but pin the whole order in the source for determinism, because
     `pass-eof-execution` `case`s on `eof-terminal`'s **single** answer, so a
     node yields at most one EOF diagnostic however many chain arms it has and
     the join's choice *is* the diagnostic the user sees. The order becomes
     observable only in Task 3, whose fixture pins it.

   **Oracle: no diagnostic on any existing fixture changes.** Run this task with
   neither new kind in `ir.sls`, so nothing confounds the refactor with new-arm
   behaviour. **Gate: `ctest --preset pr` and `--preset release` green with zero
   diagnostic-code or diagnostic-count edits in `test/common/verify-tests.sps`,
   and the three pinned IR fingerprints and all three committed goldens
   (`test/fixtures/generated-{one-byte,pause,http-version}.golden.sls`)
   byte-identical (`git diff --stat $(git merge-base main HEAD)..HEAD --
   test/fixtures/` empty).**

2. **Both node kinds in `ir.sls`**, in one commit with Task 3. §9.1:301 is
   `(make-field-action-node name operation arguments next error source-label)`;
   §9.1:305-306 is `(make-field-branch-node name predicate arguments true-target
   false-target source-label)`. Both join `node?` (pre-slice, ir.sls:337-339)
   and `node-name` (:340-347), or `make-machine`'s `(for-all node? nodes)`
   (:361-362) rejects the node outright, and both are exported from
   `graph.sls`'s export list **and** its `only` import list (pre-slice,
   `graph.sls:12-25` and `:26-40`). Construction-time validation is §4.3's
   constructor half and no more: `operation` in the closed seven of
   §9.1:328-334, `predicate` in the closed seven of §9.1:336-346, `arguments` a
   proper list, `name`/`next`/`true-target`/`false-target` symbols, plus §4.3's
   `error`-slot rule — `error` is a **target node name**, `#f` exactly when the
   operation cannot fail, on the `eof-target` target-or-`#f` precedent whose
   shipped shape is `(or (symbol? eof-target) (eq? eof-target #f))` at pre-slice
   `ir.sls:230-231`. Everything relational is Task 4's, per §9.1:348; §4.3
   records why decision 0017's reasoning does not transfer and why `make-edge`
   is the precedent that does, and it is not re-derived here.

3. **Every verifier site, in the same commit as the kind.** The appendix census
   is the checklist and its counting rule is by *file occurrence*: **nine**
   `verify.sls` sites, census numbers 3, 4 and 8-14. Line numbers are pre-slice,
   and Task 1 has already moved `eof-terminal`.

   | Census site (pre-slice) | What the new arms say |
   | --- | --- |
   | 3 — `node-out-targets`, `(else '())` at :74 | field-action returns `(list next)` plus `error` when it is a symbol; field-branch returns both targets. Feeding this arm also repairs `pass-names`' target resolution (:129-136), `pass-reachability` (via `all-out-targets`, :88-91) and `byte-reached` (:391), all of which walk this one function. |
   | 4 — `node-eof-target`, `(else #f)` at :85 | **Deliberately not extended.** Neither kind reads input, so neither has an eof-target; `#f` is the right answer and `all-out-targets` and `pass-eof` (:342-354) are correct unchanged. Document it in place, as `pass-overlap` documents its own permanent non-extension (:178-184). |
   | 8 — `reexec-targets`, `(else '())` at :322 | Both kinds return their successors **unconditionally, with no mode test** — the pause arm at :273 is the template, for the reason stated there: a zero-width edge makes no progress. |
   | 9 — `pass-zero-progress`'s REPORT guard at :333 | Gains both kinds. Without it a field-action node whose `next` reaches itself verifies clean and hangs `parser-feed-op!`'s `(loop pos)` (runtime.sls:200) and the emitted fallback — the failure verify.sls:307-318 already measured for the sixth kind. |
   | 10 — `eof-terminal` (Task 1) | field-action recurs into `next` and, for the three failing operations, `error`; field-branch joins over both targets, in Task 1's order. |
   | 11 — §16.2:908 source filter at :400 | **Not extended.** §4.6's pause-precedent resolution: the new checks are byte-reachability-gated, not added to the unconditional `(or (byte-dispatch-node? n) (sequence-dispatch-node? n))` filter. |
   | 12 — §16.2:909 source filter at :414 | **Not extended**, same resolution. |
   | 13 — D4(b) byte-reachability gate at :436-445 | **Extended**, as a sibling block beside the pause block, not by widening `(pause-node? n)`. Both kinds are zero-width like pause, and decision 0011's reasoning applies verbatim. |
   | 14 — D4(d) byte-reachability gate at :446-457 | **Extended**, same shape: a new byte-reachability-gated block beside the pause one. |

   Census site 5, `pass-names`' `error-node?` filter (:141), needs no arm —
   neither kind names an error *declaration*; its `error` slot is a node name,
   resolved by `node-out-targets`. **Gate: a per-kind case in `verify-tests.sps`
   for each of the nine rows, in one harness group whose header states the
   census and the counting rule, following `verify-tests.sps:582`'s "sequence
   dispatch reaches every verifier arm"; and a field-branch EOF fixture one of
   whose arms cycles while the other reaches a stop reports exactly one
   diagnostic, `eof-zero-progress-cycle` — Task 1's join order turned into a
   fixed failure signature.**

4. **Pass 6a's operand half.** Slice ①b lands the declaration half; this slice
   adds the relational checks §9.1:348 assigns to the verifier: exact arity
   against the operation or predicate, the `field` argument naming a declared
   field, `constant` and `mask` within the referenced field's declared width,
   and `low <= high` for `range`. One new code, `invalid-field-operand` (§4.6's
   two-diagnostic-codes resolution; ② introduces it, ③ reuses it), with the
   offending **field** name in the diagnostic's existing `node` slot; the
   diagnostic record is **not** widened to §16.4's seven fields, which is
   Milestone 7 (§25:1615-1616). Add the pass to `verify-machine`'s `append`
   (pre-slice, :479-491) after `pass-names`, since it presupposes name
   resolution. Its *name* follows the shipped convention: `pass-eof-execution`
   and `pass-sequence-ambiguity` are unnumbered, for the reason at
   verify.sls:190-200 — renumbering PASS 4-7 would stale fourteen measured
   references for nothing. "6a" is this design's label, not a source identifier.

5. **Normalized state kinds, 1:1, encode tags 5 and 6.** Measured pre-slice tags
   in `encode-normal`: dispatch 0, stop 1, error 2, finish 3, pause 4
   (normal-ir.sls:260-281). The lowering `cond` (:206-239) gains two arms before
   its `(else (assertion-violation ...))`, and `encode-normal`'s `case` gains
   two before its own. §4.6 settles that the lowering is 1:1 and allocates no
   internal states; what this task owes on top is the payload's home. **Carry it
   in the existing seven-slot state vector rather than widening it**:
   normal-ir.sls:35-40 records that slots are per-kind and unused ones `#f`, and
   slot 6 already means two things (a dispatch state's EOF routing, a pause
   state's continuation id). Widening the vector edits **six** shipped state
   literals — :224, :230, :231, :232, :234, and `seq-state`'s at :197, which
   serves both the sequence-dispatch arm at :228-229 and every internal prefix
   state — for no gain. **Gate: existing machines' fingerprints and goldens
   byte-identical — no shipped machine declares a field, so none gains a
   state.**

6. **Emitter fan-out to seven operation arms and seven predicate arms.**
   `render-state-arm`'s `case` (pre-slice, compile.sls:108-138) gains two arms;
   per §4.6 the fan-out happens at emission time, inside them, so the output is
   straight-line code with the bound folded from the declared width —
   §19.1:999's "direct code for each normalized node" without §19.1:1002's
   forbidden opcode VM. The arm sits inside Slice ①a's **four-variable** `loop`
   (①a made the position kind a fourth loop variable, set from a literal at
   every jump) and uses the emitter's `(quote …)` rendering convention, never
   the `'x` reader shorthand. `increment` on a `u8` in field slot 0, state 7,
   next 9, error state 11:

   ```scheme
         ((7)
          (let ((v (vector-ref fs 0)))
            (if (<= v 254)
                (begin (vector-set! fs 0 (+ v 1))
                       (loop pos 9 off (quote boundary)))
                (loop pos 11 off (quote boundary)))))
   ```

   `254` is `2^8 - 1 - 1`, computed by the emitter from the declaration, not by
   the generated code at run time. Both tails carry `(quote boundary)`, from
   §12.7:770 — "Zero-width machine action or callback failure | `boundary` at
   the current stream offset" — which fixes the failure edge directly and the
   success step by the same reading: the edge is zero-width and `off` is
   unchanged. ①a's literal rule is three-way (advance → `boundary`, reexecute →
   `byte`, the EOF-chain jump → `eof`) and a zero-width jump is none of the
   three, so ①a owes the fourth case and this slice is its first consumer.

   **`fs` is the emitted field-store parameter, and ①a already reserved it** (③
   reuses it verbatim). Three slices own three pieces of one thing: ①a emits the
   parameter and passes an empty vector (§4.2, §5 task 3), ①b owns the storage
   it will carry (parser slot 9), and this slice is the first to pass a
   populated vector and read it. The only new emitted local here is the
   arithmetic temporary `v`, which joins `reserved-member-3` (pre-slice,
   compile.sls:53) **in the same commit**, decision 0012 item 4. **Hazard, and a
   dependency on ①a: widening `exec` moves the emitted text of *every* machine,
   zero-field ones included.** If ①a has not reserved that parameter alongside
   the ABI payload's field-initials slot — on §4.2's own pre-provisioning
   argument — this slice pays a second golden re-baseline and its "no golden
   moves" oracle is void. **§4.2 settles it: ①a emits the seventh parameter and
   passes an empty vector**, and §5's task 3 carries it. This slice therefore
   only fills a parameter that already exists. Do **not** route the arithmetic
   through a `(byte-machine runtime)` helper shared with the interpreter — the
   mistake task 7 names.

7. **Interpreter arms, derived independently.** `interpret.sls` refuses this
   refactor pre-slice, at :36-42: "this library imports no normalizer library
   and shares no prefix walker with one … a proposal to factor 'the shared
   prefix walker' into a common library is a change to decision 0015, not a
   refactor." The seven operations, the seven predicates and the preflight bound
   check are implemented **twice on purpose**; a shared arithmetic module would
   blind the differential to exactly the class of defect this milestone
   introduces. The interpreter gains two `kind` answers (pre-slice,
   interpret.sls:80-90), the arithmetic and predicate evaluation behind new `op`
   messages (pre-slice, the op-message `case`, :119-127), and its own field
   storage. **This reaches `runtime.sls`, not only `interpret.sls`**:
   `parser-feed-op!`'s `case (op 'kind node)` (pre-slice, runtime.sls:175-201)
   and `parser-finish-op!`'s (:284-311) both end in an assertion violation on an
   unknown kind, so each needs a zero-width arm that steps without consuming a
   byte (`(loop ...)` with `pos` unchanged, as the reexecute path at :200 does).
   `eof-target-of` (pre-slice, interpret.sls:112-116) must **not** be reached
   for either kind — its missing else arm is §4.7 item 4, fixed in Slice ③ with
   the first input-reading node.

8. **The preflight bound check** (§15:850-870). "Shared code uses exact Scheme
   integers but checks the declared bound before committing every operation. It
   must not rely on host fixnum width or silent wrapping" (§15:856) — checked
   *before* committing, which is what makes §25:1569 true by construction and
   not by a rollback: there is no prior value to restore because no write
   happened. `store`, `clear`, `set-mask` and `clear-mask` cannot fail once the
   constant or mask is range-checked by Task 4 (a mask within the width can
   neither set nor clear a bit outside it); `increment`, `decrement` and `add`
   can. That is §4.3's `error`-slot rule as an execution property, and the shape
   of Task 10's matrix: four operations with no error target and no failure
   column, three with both. §6 records the prohibition this inherits: neither
   executor may reach for `mask64`.

9. **The `boundary` position kind for a zero-width action failure.** §12.7:770's
   row is the first of its class here: measured, zero occurrences of
   `position-kind` or `parser-error` anywhere under `src/` or `test/` today. ①a
   ships the `parser-error-*` record and its `position-kind` accessor
   (§9.3:397-405); this slice adds the row on **both** executors (task 6 for the
   emitted side, task 7 for the interpreter), and §12.7:777 makes it semantic
   and therefore differential-compared (§22.4:1271).

10. **The width × operation × boundary matrix**, discharging this slice's share
    of §25:1568 and §25:1569 for the seven operations: four widths × seven
    operations, and for each of the three failing operations the value one below
    the bound, the bound itself, and the value that crosses it, plus zero and
    the underflow edge for `decrement`. Every failure case asserts the field's
    value **after** the failure equals its value before — §25:1569 read
    literally. **The matrix needs its own completion sentinel, counting observed
    drives**: no suite here declares an expected case count and
    `harness-summary` reports only what ran (AGENTS.md:188-191), so an
    exhaustive loop that never executes passes vacuously. Copy either shipped
    pattern — `differential-sequence-node-tests.sps:272-285`, one `drives`
    counter over both nested loops asserted at `4 × 256 = 1024`, whose own
    comment explains why the shape it replaced (a per-loop counter incremented
    from the literal the `for-each` walks) asserted nothing; or
    `differential-http-version-tests.sps:205-221`, the same remedy at
    `8 × 256 = 2048`. A counter incremented inside the branch that asserts
    success is the vacuous shape AGENTS.md:192-197 names by example. Count
    `(width operation case)` drives observed from what the parser returned.

**Passes and files that must NOT be touched.** `pass-overlap`
(verify.sls:185-188) and `pass-sequence-ambiguity` (:246-249) are permanently
blind to these kinds: one compares canonical matcher byte sets within a
byte-dispatch node (§16.2:893), the other the prefix relation between byte
strings (§16.2:894), and neither kind has a matcher or a byte string.
`node-eof-target`'s `(else #f)` stays `#f`, per Task 3's table. The `:908` and
`:909` **source filters** at :400 and :414 stay `(or (byte-dispatch-node? n)
(sequence-dispatch-node? n))` — §4.6's pause-precedent resolution puts the new
checks in byte-reachability-gated blocks instead, and widening those filters
would additionally break two shipped pins for nothing. **Not for nothing in
Slice ③**, whose input-reading kind follows the dispatch precedent and therefore
*must* widen both filters to a third disjunct; §8's pin list owns those two pins
and their re-sweep. In `interpret.sls`, `dispatch` (pre-slice, :91-104) is
deliberately untouched and the decision is recorded in place, on the same
convention as those filters: neither zero-width kind can reach it — `kind`
answers them separately and `parser-feed-op!` routes them to their own arms —
and its missing tag guard lands in Slice ③ beside the byte-dispatch accessor
guards (§4.7 item 4). Ten `verify.sls` mutation pins anchor to `pass-overlap`
and `pass-sequence-ambiguity` alone (measured: cmake lines 3351, 3361, 3386,
3399, 4395, 4411, 4424, 4437, 4451, plus `verify-machine`'s pass-list entry at
4386); an implementer "extending every pass for M4" will move them for nothing.
Finally, no existing fixture, golden or fingerprint moves in this slice: none
declares a field, so none gains a state.

**Mutation pins that die in this slice.** Measured on the shipped tree: **44**
of the suite's **236** mutations target `src/byte-machine/verify.sls` (42 on
`byte-machine.verify.rejections.chez.source`, 2 on
`byte-machine.verify.identifier-repertoire.chez.source`). Two counts answer two
questions and both are needed: the file *declares* **226**
`byte_machine_mutation` calls, lexed left-to-right past `#` comments, `#[[...]]`
bracket comments and `[[...]]` bracket arguments per AGENTS.md:203-214 — a plain
`rg 'byte_machine_mutation\('` returns 230, four of them text inside comments at
`:6151`, `:6330`, `:6454` and a `FATAL_ERROR` string at `:6648` — and those 226
expand to the **236** the suite *runs* and asserts at
`SchemeMutationSuite.cmake:735`, because `byte_machine_slice3_launcher_pass`
(`:1583`) and `byte_machine_slice5b_launcher_pass` (`:2193`) each wrap one
declaration and are invoked 9 and 3 times. None of the 44 is inside a wrapper,
so 44 holds under either denominator. Every one of the 44 resolves to exactly
one occurrence of its `FIND` — the suite runs at the default `SITES=1` and
asserts it exactly, so a change in site count is a hard failure, not a warning.
Sixteen of the 44 sit in constructs this slice edits:

- `eof-terminal`, **four**, all re-anchored by Task 1 alone: `(if (memq name
  seen) 'cycle` (cmake:3533 → verify.sls:360), `((stop-node? n)
  'eof-reachable-stop)` (cmake:3514 → :365), the pause arm (cmake:3604 → :366),
  and arm 5 (cmake:4157 → :382), whose `FIND` **ends with `(else
  'unknown)))))))`** — the arm boundary — and whose `REPLACE` is that `else`.
- `node-out-targets`, **two**: the pause arm anchored on its own preceding
  comment line (cmake:3565 → :66) and sequence arm 1 (cmake:3938 → :71), whose
  `FIND` ends `(else '())))`.
- `reexec-targets`, **three**: the pause arm, again anchored on its comment
  (cmake:3662 → :272), sequence arm 3 (cmake:4012 → :319, `FIND` ending `(else
  '())))`), and the mismatch-mode pin (cmake:4069 → :320).
- The `pass-zero-progress` REPORT guard, **three pins on one two-line
  construct** (cmake:3406, 3759, 4114 — all → verify.sls:333): two carry the
  two-line `FIND`, one the single-line prefix of it, and all three re-anchor the
  moment the guard gains a disjunct, exactly as Slice ③ re-anchored them when it
  added `sequence-dispatch-node?`.
- The byte-reachable-pause blocks, **four** (cmake:3860 → :438, 3629 → :440,
  3903 → :448, 3709 → :449), at risk only if the new checks are written by
  widening `(pause-node? n)` rather than as sibling blocks; two carry two-line
  `FIND`s that exist *because* the bare gate text occurs twice, so a third and
  fourth copy of that shape is a live `SITES` hazard.

The mechanism, stated once: three of these pins' `FIND` text **spans an arm
boundary** and swallows the enclosing `(else ...)`, so inserting an arm before
that `else` breaks them even though the mutated line itself is untouched.
Re-anchoring is a re-**measurement** of each pin's failure signature against the
rewritten source, not a text edit, and per AGENTS.md:170-171 the obligation is
recorded in the tree by mutation LABEL, not by line number. AGENTS.md:172-187
requires both directions of each sweep — the new pin against the old mutant as
well as the incumbent against the new text — with a control on the merge base.

**Exit evidence.** In the tree, at close-out: `make-field-action-node` and
`make-field-branch-node` exported from both of `graph.sls`'s lists; the **nine**
`verify.sls` census sites carrying an arm or an in-place note for each new kind,
with a harness group in `verify-tests.sps` whose header states that census and
one case per row; `pass-field-operands` in `verify-machine`'s pass list, and
`invalid-field-operand` reachable by arity, undeclared reference, operand range,
mask range and `low > high`; normalized kinds at encode tags 5 and 6, with a
normal-ir test pinning the tag bytes; two new `render-state-arm` arms and
`reserved-member-3` updated in the same commit as the locals it names (`fs`,
`v`); interpreter arms and the two `runtime.sls` op-loop arms, with no shared
arithmetic between `interpret.sls` and `compile.sls`'s emitted output; new
five-segment lanes in both source and AOT (§22.3's unit lanes and §22.4:1267's
differential) — measured: zero of the 86 lane names in `test/CMakeLists.txt`
contain `field`, so `byte-machine.unit.field-action.*`,
`byte-machine.unit.field-branch.*` and `byte-machine.differential.field-op.*`
are collision-free today; the width × operation matrix green with a `drives`
sentinel asserting the observed count; `ctest --preset pr` and `--preset
release` green; the Scheme mutation suite's `EXPECTED_PASSES` /
`EXPECTED_MUTATIONS` (SchemeMutationSuite.cmake:734-735, 46/236 on the shipped
tree) updated to the re-measured totals with every re-anchored pin's new failure
signature recorded; the CMake suite unchanged at 1/72; `EXPECT_SURVIVES` at the
count Slice ①b closed with, **plus the disposition this slice owes on ①b's
survivor** — ①b declared the `parser-reset!` field-restore limitation
`EXPECT_SURVIVES` precisely so ②'s first `store` is told it has gone stale
(`MutationRunner.cmake:63-66`), so either ②'s lanes reach a
store-then-reset-then-read and the pin is re-declared `EXPECT_STATUS 1` with a
measured failure signature, or the slice states the measurement showing they
still do not and the survivor stands; and the three pinned IR fingerprints and
all three committed goldens byte-identical since `main` (`git diff --stat $(git
merge-base main HEAD)..HEAD -- test/fixtures/` empty).

## 8. Slice ③ — Integer accumulate

Discharges §25:1561 in full (`input-reading integer-accumulate nodes with digit,
delimiter, overflow, and EOF paths`) and §17:961 in full (`lower integer
accumulation into explicit digit, fallback, overflow, and EOF control flow`),
and takes a *share* of four criteria other slices also serve: the
integer-accumulation half of §16.2:904; §25:1564's accumulate share of `field
diagnostics`, which adds **no** new diagnostic code and reuses **Slice ②'s**
`invalid-field-operand`; the accumulate share of exit §25:1568 — the checked
multiply-add at each width's maximum, u64 at 2^64 − 1, the seven-operation
matrix and its `decrement` underflow being Slice ②'s and the declaration-time
bounds ①b's — and of exit §25:1569; and exit §25:1570, extending §22.4:1267's
`final state and fields` comparison and §22.4:1271's error clause over the
accumulate kind. :1570's `traces` clause is discharged by §4.6's `traces`
resolution, not by anything built here.

Every `file:line` below was measured on `main` at `a942327` and **drifts through
Slices ①a, ①b and ②**. Citations into files this slice itself edits
(`interpret.sls`, `private/ir.sls`, `verify.sls`, `private/normal-ir.sls`,
`compile.sls`, `runtime.sls`, `graph.sls`, `machine-gen.sls`,
`property-differential-tests.sps`, `SchemeMutationSuite.cmake`) are therefore
**pre-slice** and name the construct, not only the line; no grep or link check
catches that class of staleness later.

**The milestone's sharpest hazard is that `eof-target-of` answers a plausible
node name for a node kind it has never seen, and this slice is the kind that
arms it.** `eof-target-of` (pre-slice, `interpret.sls:112-116`) is a two-way
`if`: sequence-dispatch gets `sequence-dispatch-node-eof-target` and
**everything else falls through** to `byte-dispatch-node-eof-target`, a bare
`(vector-ref n 4)` with no tag guard (pre-slice, `ir.sls:237`). That is correct
today only by accident: `(op 'eof-target ...)` has exactly one caller,
`parser-finish-op!`'s `((dispatch) ...)` arm (pre-slice, `runtime.sls:303-310`),
and `kind` (pre-slice, `interpret.sls:80-90`) answers `'dispatch` for exactly
the two kinds whose slot 4 *is* an eof-target — both constructors put it there
(pre-slice, `make-byte-dispatch-node`'s vector at `ir.sls:232` and
`make-sequence-dispatch-node`'s at `:329`). Under the normative parameter order
`name field base digit-target nondigit-edge overflow-error eof-target
source-label` (§9.1:302-304), slot 4 of the new node is **`digit-target`, a
symbol**: EOF on an accumulate node returns the digit target,
`parser-finish-op!` sets `current` to it, `(loop t)` continues into the digit
path, nothing raises and nothing mismatches a tag, and `parser-finish!` reports
whatever that path reaches. Today's only failure mode here is a raise — the
shipped mutation at `SchemeMutationSuite.cmake:4603-4621` pins the literal Chez
text `Exception in vector-ref: #f is not a vector` — so the day the node kind
lands, a loud failure becomes a silently wrong EOF answer. Task 1 closes it
before the node kind exists.

**The digit repertoires are settled here because they are an input to the first
test, not an outcome of it** (§4.6's hex-repertoire resolution). Base 16 is
`0-9`, `A-F`, `a-f` (22 bytes), base 10 is `0-9` (10 bytes), and the partitions
differ on exactly twelve bytes. Both are unexpanded upstream — §21.2 leaves
`HEXDIG` at :1079-1080, and `DIGIT` at :1073 and inside `tchar`'s own right-hand
side at :1087, unlike the classes that bottom out in `%x` byte values (`OWS`
:1071 via `SP`/`HTAB`, `target-byte` :1090, `field-value-byte` :1091,
`SP`/`HTAB`/`CRLF` :1092-1094) — but only `HEXDIG`'s byte set actually moves,
RFC 5234's being uppercase-only. Write both repertoires down in the node's own
comment and in the all-byte test's group header, in the constructor's commit.

1. **`eof-target-of`'s else arm, and tag guards on three byte-dispatch
   accessors** (§4.7 item 4). Behaviour-preserving on every existing fixture:
   rewrite `eof-target-of` (pre-slice, `interpret.sls`, inside
   `make-interpreted-machine`) from a two-way `if` into a `cond` with one arm
   per kind that *has* an eof-target and an explicit `else` raising
   `byte-machine-contract-violation`, as `kind`'s own `else` does (pre-slice,
   `interpret.sls:90`). Give **exactly three** accessors the tag-guard idiom M3
   Slice ① shipped for the matchers (`exact-byte-matcher-byte`, pre-slice
   `ir.sls:68-71`, whose comment explains that an unguarded `vector-ref` "fails
   far away … rather than at the contract boundary"):
   `byte-dispatch-node-cases`, `-fallback` and `-eof-target` (pre-slice
   `ir.sls:235-237`). Those are the three the Appendix census demonstrates a
   wrong-kind node reaching — `eof-target-of` reaches `-eof-target`, and
   `dispatch`'s else arm (pre-slice `interpret.sls:91-104`, census site 20)
   feeds any other kind into `-cases` and `-fallback`, so this task is also what
   converts site 20 from silent to loud. The other five node accessors stay bare
   **deliberately**, and the reason belongs beside them or the next reader
   re-widens the set from the same observation: `byte-dispatch-node-name`'s only
   reader is `node-name`'s already-guarded arm (pre-slice `ir.sls:341`), and
   nothing reaches the four sequence accessors (pre-slice `ir.sls:331-334`) with
   another kind, `seq-step` being entered only behind `(sequence-dispatch-node?
   n)` (pre-slice `interpret.sls:95`) or through a compound `current` carrying
   that node's own name. M4 creates no new reach. **Gate: `ctest --preset
   release` green with no fixture edited, and the three pinned IR fingerprints
   (`normal-ir-tests.sps`, pre-slice `:73`, `:122`, `:147`) plus all three
   committed goldens
   (`test/fixtures/generated-{one-byte,pause,http-version}.golden.sls`)
   byte-identical against the slice's own merge base — `git diff --stat $(git
   merge-base main HEAD)..HEAD -- test/fixtures/` empty, not `git status`.** The
   one deliberate observable change is the shipped mutation's expected text.

2. **`make-integer-accumulate-node`, the constructor half of §4.3 only.**
   Closed-set membership and local shape of the one value being built: `field`,
   `digit-target` and `overflow-error` symbols, `base` in `{10, 16}`,
   `nondigit-edge` an `edge?`, `eof-target` a symbol or `#f`, `name` a symbol.
   Nothing relational — the field is *not* looked up here, because there is no
   machine to look it up in. Add the kind to `node?` (pre-slice
   `ir.sls:337-339`) and `node-name` (pre-slice `ir.sls:340-347`), or
   `make-machine`'s `(for-all node? nodes)` (pre-slice `ir.sls:361-362`) rejects
   the node outright, and export the constructor, predicate and accessors from
   **both** of `graph.sls`'s lists (pre-slice, the `export` at `graph.sls:12-25`
   and the `only` import at `:26-40`), which M3 Slice ② recorded as a two-place
   edit. **Gate: a unit case per rejected shape, and `base` measured rejected at
   2, 8 and 16.5 as well as at non-integers.**

3. **Every verifier arm, for a *consuming* kind.** `verify.sls` is permissive by
   default at every kind-dispatching site, so a node added to `ir.sls` and not
   here **verifies clean** and crashes later in the normalizer — the M3 Slice ②
   hazard, unchanged. The Appendix census is the count: twelve kind-dispatching
   sites in `verify.sls`, the number the tree derives at
   `verify-tests.sps:521-524` by reading every `cond` that dispatches on node
   kind rather than by grepping one predicate. Seven take an arm; five do not,
   and each non-extension is recorded in place. Pre-slice:
   - `node-out-targets` (`:58-74`): `digit-target`, the `nondigit-edge`'s target
     **and** `overflow-error`, all three node names. Omitting the overflow
     target produces a *loud but false* `'unreachable-node` on the overflow
     handler, which reads as a user grammar error.
   - `node-eof-target` (`:82-85`): a new arm, which then feeds
     `all-out-targets`, `pass-eof` and `pass-eof-execution` for free.
   - `reexec-targets` (`:263-322`): the byte-dispatch arm's structure but
     testing only the fallback, as the sequence arm does — the digit edge always
     advances (§10.6:566, "an explicit advance edge") and the overflow edge is
     non-consuming but terminal-directed, so only `nondigit-edge` can be
     `reexecute`.
   - `pass-zero-progress`'s **report** guard (`:333`): gains a disjunct, or an
     accumulate node whose `nondigit-edge` reexecutes into itself is a
     zero-progress cycle with no local guard in either lane — the shape M3
     Slice ② measured hanging under a timeout in `parser-feed-op!` and in the
     emitted `(loop pos …)` fallback alike.
   - `eof-terminal` (`:357-385`): its own arm, not merged into the byte-dispatch
     arm, per the reasoning at `:367-378`, which Slice ② has by then carried
     into the multi-successor walk.
   - Both `pass-eof-execution` **source filters** (`:400` for §16.2:908, `:414`
     for §16.2:909): accumulate is input-reading, so per §4.6 it follows the
     **dispatch** precedent and joins `(or (byte-dispatch-node? n)
     (sequence-dispatch-node? n))` at both — the opposite of Slice ②'s
     zero-width kinds. Both filter texts are pinned verbatim; see the pins.
   - **Not extended:** `pass-names`' `error-node?` filter (`:141`), since
     `overflow-error` names a target *node*; `pass-overlap` (`:185-188`) and
     `pass-sequence-ambiguity` (`:246-249`), below; and the two D4(b)/(d)
     byte-reachability gates (`:436-445`, `:446-457`), which select pause nodes
     to inspect a continuation this kind has not got.

   §16.2:904's field half lands here too, per §4.6 the declared-field-reference
   check against Slice ①b's field table, reported as `invalid-field-operand`
   with the offending **field** name in the diagnostic's `node` slot; record
   that with one field type "incompatible field" has no content beyond
   "declared" (§29:1754 defers what would give it content). Its *base* half is
   discharged wholly by Task 2's constructor, which rejects any base outside
   `{10, 16}`; per decision 0020 item 6's one-rejection-site rule, pass 6a
   carries **no** arm for it, and the field walk records the assignment in
   place, the way `pass-overlap` documents its own non-extension.
   `normal-ir.sls`'s trie guards (decision 0015 point 2) are not a precedent for
   a pass-6a arm here: those guards stay reachable through `normalize-machine`'s
   own public entry point, while a machine holding an out-of-range `base` cannot
   be constructed at all, so an arm here would ship dead and owe an
   `EXPECT_SURVIVES` this task does not budget for — decision 0020 item 6 works
   this exact case through in full. **Gate: one `verify-tests.sps` case per arm,
   grouped under a header stating the site census and its derivation, following
   the "sequence dispatch reaches every verifier arm" precedent.**

4. **The interpreter arm, and the checked multiply-add — first writing.**
   §15:858-870 is normative and its inequality is quoted exactly, not restated:
   `next = current * base + digit`, checked before multiplication/addition as
   `current <= floor((maximum - digit) / base)`, and "Failure takes the node's
   explicit error edge and leaves the previous field value unchanged" (§15:870).
   **The check happens before the commit, and the commit is a single store of
   the already-checked value** — never a store followed by a range test, which
   would transiently violate §25:1569 and be invisible to any test that reads
   the field only after the operation returns. Give the node its own `kind`
   symbol rather than reusing `'dispatch`: `(op 'dispatch node byte)` answers a
   pure `(target . mode)` pair (pre-slice, `runtime.sls:191-200`) with nowhere
   to put a field commit or a third outcome, so reusing it would silently widen
   a contract two executors share. A dedicated `kind` gets a dedicated arm in
   `parser-feed-op!` (with its own `(>= pos end)` need-input branch) and in
   `parser-finish-op!`, and leaves `kind`'s `else` (pre-slice,
   `interpret.sls:90`) loud for a kind nobody taught the interpreter. Per
   §18:970-972 the interpreter derives this independently of the normalizer; it
   imports no normalizer library today and must not start.

5. **Normalized state kind 7, lowered 1:1** (§4.6's 1:1-lowering resolution).
   Encode tag **7** joins the shipped set — dispatch `0`, stop `1`, error `2`,
   finish `3`, pause `4` (pre-slice, `encode-normal`, `normal-ir.sls:260-281`) —
   with Slice ②'s `5` and `6` in between. One source node becomes one state
   carrying four explicit target slots (digit, fallback-with-mode, overflow,
   EOF), which is what discharges §17:961's "explicit … control flow". The
   `else` guards in `lower-machine` and `encode-normal` (pre-slice,
   `normal-ir.sls:239`, `:280-281`) stay assertion violations. **Gate: a
   tag-collision mutation for tag 7, mirroring the shipped `normal-ir: the pause
   tag collides with finish's tag`; and the three existing fingerprints
   unchanged since Slice ①a's re-baseline, no existing machine gaining an
   accumulate state.**

6. **The emitter arm — the checked multiply-add's *second*, independent
   writing.** §4.6's emission-time fan-out resolution produces straight-line
   code, no runtime opcode dispatch (§19.1:1002). The arm below sits inside
   Slice ①a's **four-variable** `loop` (pre-slice the three-variable `"    (let
   loop ((pos start) (st state) (off offset))\n"` at `compile.sls:157`, and both
   `loop-tail` forms at `:75-78`) and uses `fs`, Slice ②'s new emitted `exec`
   parameter carrying the parser's field vector — **not** a fifth loop variable.
   For a u64 field in base 10 with a reexecute fallback:

   ```scheme
   ((7)
    (if (>= pos end)
        (if finish?
            (loop pos 12 off (quote eof))        ; or the default-eof outcome
            (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f 7 off))
        (let ((b (bytevector-u8-ref bv pos)))
          (case b
            ((48 49 50 51 52 53 54 55 56 57)
             (let ((d (- b 48)) (cur (vector-ref fs 0)))
               (if (<= cur (div (- 18446744073709551615 d) 10))
                   (begin (vector-set! fs 0 (+ (* cur 10) d))
                          (loop (+ pos 1) 3 (+ off 1) (quote boundary)))
                   (loop pos 9 off (quote byte)))))  ; overflow: no advance
            (else (loop pos 5 off (quote byte)))))))  ; nondigit, as drawn
   ```

   Four things are load-bearing. The overflow tail is `(loop pos …)`, never
   `(loop (+ pos 1) …)` — that non-advance *is* §12.7:773 — and its position
   kind is the literal `(quote byte)`, §12.7:768's "rejected current digit" row,
   which :773 restates for overflow; that literal is the slice's differential
   pin, not a placeholder. The other three follow Slice ①a's rule: the
   digit-accepted advance carries `(quote boundary)`, the `finish?` EOF-chain
   jump `(quote eof)`, and the nondigit tail whatever its declared mode selects
   — `(quote byte)` as drawn, or `(loop (+ pos 1) 5 (+ off 1) (quote boundary))`
   for an advance edge. `fs` is written once, after the test. And the bound is
   emitted as the plan's expression rather than constant-folded per digit arm:
   each arm knows its own `d`, so folding is available and is declined for
   §19.2:1011's "generic exact arithmetic with declared-bound checks" and
   §19.2:1009's "selected for simplicity, not speculative density optimization",
   with §23.3:1369 gating the reversal behind compiled benchmarks that cannot
   exist yet (`bench/` holds two `.gitkeep` files). Record the declining at the
   site, as `render-transition-arm` records its own (pre-slice,
   `compile.sls:82-89`). **Any new emitted local — `d` and `cur` here; `fs`
   already joined in Slice ② — joins `reserved-member-3` in the same commit**
   (decision 0012 item 4, pre-slice `compile.sls:53`); §4.7 item 2's drift
   guard, closed in Slice ①a, is what turns "checked, not assumed" into a check.

7. **The all-256 partition test, for both bases** (§22.7:1301). Each of the 256
   bytes lands in exactly one of `{digit, non-digit}`, per base, through the
   interpreter, in a new `byte-machine.unit.accumulate.chez.{source,aot}` lane.
   Assert the **partition**, not a sample: count the bytes that took the digit
   edge and check it equals 10 for base 10 and 22 for base 16, count the bytes
   that took the fallback edge and check the two counts sum to 256, and check
   that the symmetric difference of the two digit sets has size exactly 12 and
   is `{0x41-0x46, 0x61-0x66}`. Every one of those counters must be computed
   from the **observed** parser results, never from the expected repertoire — a
   counter derived from the test's own expectation asserts nothing — and the
   loop over the two bases needs its own sentinel asserting it ran twice.

8. **The differential lane, fragmentation, and the two position pins.** New
   `byte-machine.differential.accumulate.chez.{source,aot}` lanes; both names
   are measured free of collision (`test/CMakeLists.txt` registers 86 lane names
   today — 58 families, 26 of them non-harness — none containing `accumulate` or
   `field`, and a duplicate CTest name is a configure-time `FATAL_ERROR`). Reuse
   the shipped split-point idiom rather than inventing one, all of it in
   `differential-sequence-tests.sps`, which this slice does not edit:
   `all-cut-sets` exhaustive for the input length (`:118`), `slices-for`
   (`:104-108`), `with-empties` (`:109-114`), `run-slices` on one fresh parser
   (`:50-58`), and the seeded multi-split schedule with its genuine-multi-split
   sentinel (`:153-173`), which keeps "every fragmentation" from degenerating to
   zero-cut draws. A multi-digit number split at **every** interior position
   must produce byte-identical `(status next consumed stream-offset error)`
   tuples and byte-identical field values in both lanes — the field is committed
   across a feed boundary, so a value held in an `exec` local instead of the
   parser's store fails exactly here and nowhere else.

   **The overflow row is M4's second new §12.7 position row, and it differs from
   Slice ②'s.** §12.7:773: "Integer-overflow nodes reject and do not consume the
   overflowing digit, so their position is the offending byte." Pin
   `parser-result-next` alongside the position kind — the digit is unconsumed,
   so `next` points **at** it, the convention §11.5:664 states for a reexecute
   error edge and the shape `differential-sequence-tests.sps:79` already pins
   for mismatches. §21.4:1175 restates it fixture-side ("Numeric overflow points
   at the digit that would overflow and leaves it unconsumed") for Milestone 8's
   error catalog, so an off-by-one committed here is found four milestones
   later, in a fixture, by someone not reading this section. Compare
   `parser-error-domain`, `-code`, `-node-name`, `-offset` and `-position-kind`
   across lanes, exactly §22.4:1271's list; do **not** compare
   `parser-error-state-id`, which §12.7:777 excludes from cross-executor
   comparison by name.

9. **The property generator learns a field draw**, its only M4 edit. §22.6:1295
   says to include "byte dispatches, reexecution, fields, callbacks, pauses,
   spans, EOF, and terminals **as each feature becomes available**". Measured,
   `gen-machine` (pre-slice, `machine-gen.sls:119-139`) draws one
   `byte-dispatch` entry named `start` with 1–4 distinct-byte cases over `#(stop
   reject start)` (plus `pausep` when the pause coin fires), modes from
   `#(advance reexecute)` with `advance` forced for `start` and `pausep`, the
   first case pinned to `(stop . advance)`, a `reexecute` fallback to `reject`,
   and an optional `done` finish node as the entry's eof-target; it draws **no**
   fields and **no** sequence nodes, threading `'()` for `fields` at `:129`. Add
   one accumulate node behind its own coin, reachable by a pinned case,
   targeting `stop` on the digit edge, with a declared u8 field so overflow is
   reachable inside 256 draws — and state the by-construction argument the
   generator's own header demands: the node is *consuming*, so it forms no
   zero-progress cycle, and the field it reads is declared in the same draw, so
   pass 6a's declared-field-reference check holds by construction. M3's
   precedent is binding and was learned the hard way: a new draw is **untestable
   until its own anti-vacuity counter exists** — hard-wiring the eof or pause
   coin to a constant produced a machine `verify-machine` still accepts, so no
   existing check failed and both draws needed new assertions before they could
   be witnessed at all (pre-slice, `SchemeMutationSuite.cmake:478-492`). Add an
   `accumulated-count` beside the shipped `paused-count`/`finished-count`
   (pre-slice, `property-differential-tests.sps:139-159`), asserted `>= 1` and
   computed from what the parsers returned; and, the counter being a conjunction
   the way `finished-count` is, write down which conjuncts a seed could zero.

10. **The u64 boundary at 2^64 − 1, the row that exercises the bignum path.**
    Measured on this project's Chez 10.4.1: `(fixnum-width)` is 61 and
    `(most-positive-fixnum)` is 1152921504606846975 = 2^60 − 1, so
    `18446744073709551615` is **not** a fixnum while `4294967295` (u32 max) is.
    The u64 lane is therefore the only width where the committed value, the `(-
    maximum digit)` numerator and the `(* cur base)` product are all bignums,
    and it is the direct test of §15:856's "must not rely on host fixnum width
    or silent wrapping". For every width, feed max, max−1 and max+1 as decimal
    and as hex digit strings, and assert three things separately: the status,
    the field value, and — for the rejecting case — that the field still holds
    the value it had **before** the offending digit, which is §25:1569 as an
    observation rather than an inference.

**Passes and files that must *not* be touched.** `pass-overlap` (pre-slice,
`verify.sls:185-188`) stays filtered on `byte-dispatch-node?` **permanently**:
it compares canonical matcher byte sets *within one byte-dispatch node*
(§16.2:893), and an accumulate node has no `byte-case`s at all — its digit set
is implied by `base` and there is exactly one of it, so no pair can be
non-disjoint. `pass-sequence-ambiguity` (`:246-249`) compares the prefix
relation between byte strings (§16.2:894) and is likewise inapplicable.
`normal-ir.sls`'s trie construction and decision 0016's two-phase internal-id
allocation are untouched, the lowering being 1:1 (§4.6) and this slice
allocating no internal states; `compile.sls`'s `loop-tail` and
`render-transition-arm` are untouched for the same reason, and the interpreter's
`seq-step` and `prefix?` likewise. This paragraph exists because "extend every
pass for M4" is the default instinct and costs mutation-pin re-measurement on
four sites for nothing.

**Mutation pins that die in this slice.** Each is a re-**measurement** of a
failure signature, not a text edit; per AGENTS.md:170-171 the obligation is
recorded in the tree by mutation LABEL rather than line number, and per
AGENTS.md:172-187 every sweep runs in both directions. Lines are `main` at
`a942327`.

- `interpret: eof-target-of does not dereference a compound back to its source
  node` (`:4603-4621`). Both halves move: its `FIND` is the `(let ((n (lookup
  nodes (if (pair? cur) (car cur) cur))))` line Task 1 rewrites, and its
  `EXPECT_OUTPUT_MATCHES` pins the raw Chez `case raised -- Exception in
  vector-ref: #f is not a vector`, which the tag guard replaces with a contract
  violation. The comment at `:4610-4614` argues the defect is "raise-caught, not
  comparison-caught" *because* the accessor chain is unguarded — the argument
  Task 1 falsifies — so it is rewritten, not just re-anchored.
- `runtime: an exhausted dispatch does not take its eof-target` (`:2636-2641`),
  whose `FIND` is the bare `(op 'eof-target node)` at the default `SITES=1`,
  **asserted exactly**. Task 4's accumulate arm in `parser-finish-op!` calls the
  same expression, taking the count to 2 and failing with "found 2, expected 1".
  This is the shipped instance of counting by **file**, not by spec: widen the
  `FIND` to include the surrounding `((dispatch)` line, re-measure the
  occurrence count in `runtime.sls` after Task 4 in both directions, and give
  the new arm its own pin. Check `runtime: a dispatch with no eof-target does
  not route to the default error` (`:2643-2658`) the same way — its multi-line
  `FIND` is unlikely to duplicate, but "unlikely" is not a measurement.
- `ir: make-sequence-dispatch-node accepts a malformed eof-target`
  (`:5868-5887`). Its comment records the trap: the bare guard `(unless (or
  (symbol? eof-target) (eq? eof-target #f))` is byte-identical to
  byte-dispatch's at `ir.sls:230`, so the `FIND` carries the following
  `byte-machine-contract-violation` line to stay unique. Task 2's constructor
  makes that guard line a **third** copy; the disambiguating line is the
  constructor name, so the pin survives — verify by counting occurrences in
  `ir.sls`, and give the new guard its own pin naming its own constructor.
- `verify: zero-progress detection never fires` (`:3405-3415`), whose `FIND` is
  the whole two-line report guard `(if (and (or (byte-dispatch-node? n)
  (pause-node? n) (sequence-dispatch-node? n)) (reaches-self? (node-name n)))`.
  Task 3 adds a fourth disjunct, so the text changes; decision, `REPLACE` and
  pin are unchanged, exactly as when M3 Slice ③ added the third.
- **The two `pass-eof-execution` source-filter pins, which Slice ② was told to
  leave alone and this slice must move.** `verify: a sequence case's byte edge
  into a finish terminal is not flagged (arm 6, :908)` (`:4217-4285`) and
  `verify: a sequence node's own eof-target chain is not walked (arm 7, :909)`
  (`:4287-4383`) each carry `(if (or (byte-dispatch-node? n)
  (sequence-dispatch-node? n))` inside a multi-line `FIND` anchored on the `;;
  :908` / `;; :909` comment; Task 3 adds the third disjunct at both, so both
  `FIND`s and both `REPLACE`s are rewritten and re-measured. Arm 6 carries a
  GENUINELY SUBSUMED verdict against arm 1 and arm 7 an explicit not-subsumed
  two-record finding — re-sweep both over the whole mutation set after the
  widening, not over the mutations their comments name.
- `verify: pause continuations join the zero-progress walk` (`:3661-3702`) has
  been re-anchored twice already for adjacency drift in `reexec-targets`, and
  carries a SUBSUMED RESIDUE finding whose subset count was re-measured at 34
  mutations. Task 3 inserts an accumulate arm into the same `cond`. Re-anchor,
  and **re-sweep the subset claim over the whole mutation set**: a new arm can
  give the broader mutant a new FAIL record and change the ratio, and per the
  residue taxonomy zero unique records is a claim about the spec, not a licence
  to leave the pin unfixable.
- The Pass 33 verify pins generally. M3 Slice ② measured that a node kind added
  to `verify.sls` moves pin anchors by *adjacency* in six places at once; run
  the whole-pass sweep after Task 3 rather than fixing pins one failure at a
  time, in both directions — re-anchoring the incumbent is half the sweep, and
  the new anchor must also be checked against the old mutant.

**Exit evidence.** In the tree, at close-out: `make-integer-accumulate-node`
exported from both of `graph.sls`'s lists with its predicate and accessors;
`eof-target-of` a `cond` with an explicit raising `else`, and
`byte-dispatch-node-cases`, `-fallback` and `-eof-target` tag-guarded with the
other five node accessors left bare and the reason recorded beside them; a
`verify-tests.sps` group whose header states the `verify.sls` kind-dispatching
site census and derives the number, one case per arm; encode tag 7 in
`normal-ir.sls` with its own tag-collision mutation; the emitted checked
multiply-add in `compile.sls`, written independently of the interpreter's, with
`d` and `cur` in `reserved-member-3` and Slice ①a's drift guard green;
`byte-machine.unit.accumulate.chez.{source,aot}` and
`byte-machine.differential.accumulate.chez.{source,aot}` all four green — the
unit lanes carrying the 10/22/256/12 partition counters computed from observed
results plus the two-base loop sentinel, the differential lanes every interior
split point of a multi-digit input, the overflow `(next, position-kind) =
(at-the-digit, byte)` pin, and the max/max−1/max+1 rows for all four widths with
the pre-operation field value asserted unchanged on every rejection; an
`accumulated-count` guard `>= 1` in `property-differential-tests.sps` beside the
shipped `paused-count`/`finished-count`. Measured, and recorded as commands in
the task report rather than asserted: `ctest --preset release` and `--preset pr`
green at the slice's new lane count (86 on `main`, plus the four lanes above and
whatever ①a/①b/② registered — measured at close-out, not predicted here); the
Scheme mutation suite green at its new `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`
(46 / 236 on `main`, declared at `SchemeMutationSuite.cmake:734-735`, not
`:554-555`); the CMake mutation suite unchanged at 1 pass / 72 mutations; the
`EXPECT_SURVIVES` directives unchanged at the count Slice ② closed with, shown
by `git diff <base>..HEAD -- test/support/cmake/SchemeMutationSuite.cmake | grep
-E '^[+-].*EXPECT_SURVIVES'` returning empty; and the three pinned IR
fingerprints and all three committed goldens byte-identical **since Slice ①a's
re-baseline** (`git diff --stat <①a>..HEAD -- test/fixtures/`, empty) — not
since `main`, which ①a's format-version bump 1→2 moved by design.

## Exit (full Milestone 4)

§25:1568-1570's three criteria, allocated to the slices that will discharge
them. At close, each entry is replaced by a **dated disposition** naming the
slice that discharged it and the file and case in the tree that meets it — never
reworded to match what shipped (AGENTS.md, "Correct a stale instruction in
place; annotate a stale record"). A criterion discharged in parts is attributed
in those parts, the way Milestone 3 attributed §25:1533 in halves.

| Criterion | Allocated to | What will meet it |
| --- | --- | --- |
| **:1568** — "boundary, overflow, and underflow tests for every width" | **①b, ② and ③**, in parts | ①b owns the *declaration* part: at all four widths, initial `0` and initial `2^w − 1` accepted and `2^w` rejected — rejected by the **constructor** per §4.3, so this part is discharged by a contract violation and never by a diagnostic. ② owns the *operation* part: the width × operation × boundary matrix over four widths and the seven operations, with underflow at `decrement` from 0 and overflow at `increment`/`add` from each width's maximum. ③ owns the *accumulate* part: the checked multiply-add at each width's maximum. "Every width" means the u64 row actually runs at 2^64−1, which is above `(greatest-fixnum)` = 2^60−1 on the only supported runtime. |
| **:1569** — "failed operations leave prior values unchanged" | **② and ③**, in halves | Both halves are true *by construction* rather than by rollback, because §15:856 mandates a preflight bound check: no uncommitted value is ever written. ② proves it for `increment`, `decrement` and `add` — and proves the complementary claim for `store`, `clear`, `set-mask` and `clear-mask`, which per §4.3's `error`-slot rule cannot fail and therefore carry `#f` in the `error` slot. ③ proves it for the multiply-add, where §10.6:568 and §12.7:773 additionally fix that the offending digit is *not consumed*. |
| **:1570** — "interpreter/generated fields and traces match" | **all four slices** | Read per §4.6 as §22.4:1262-1272's comparison list. ①a discharges its error clause — §22.4:1271's "error domain, code, public source-node name, absolute position, and position kind" — against node kinds shipped in M1 and M2. ①b takes §22.4:1267's "final state and fields" clause, the first cross-lane field comparison, for a machine that declares fields but writes none. ② extends that same comparison over the two zero-width kinds and ③ over the accumulate kind, and each adds one row to §12.7's position table. The "traces" word gets a dated disposition recording §4.6's reading, not a limitation record. |

**Three limitations this milestone closes over rather than glosses**, to be
restated with their qualifiers at close:

1. **`parser-error-domain` ships with one producible value.** The `callback`
   domain and the `detail` payload have no producer until Milestone 5 (§9.3:401
   already fixes `detail` at `#f` for machine errors), so the accessor family is
   complete but the domain is not exercised across both of its values. This is a
   property of what exists, not a gap in M4.
2. **`parser-error-state-id` is excluded from differential comparison by
   §12.7:777**, which calls it "an executor-local debugging aid". M4 therefore
   asserts it *within* a lane (deterministic for a given normalized graph) and
   never *across* lanes. A test that compares it across executors is wrong, not
   thorough.
3. **§16.2:904 is implemented as a check with no independent content** (§4.6).
   The bullet is discharged, but by a check that is coextensive with §9.1:348's
   declared-field-reference rule rather than by a distinct one. If a later
   milestone adds a second field type, this disposition is the record of why no
   separate check exists to extend.

## 9. Explicitly out of Milestone 4

- **Callbacks, decision branches, poisoning, busy/reentrancy guards, and spans**
  — Milestone 5 (§25:1572-1591). M4 ships `parser-field-ref` (§9.3:410), the
  *read-only* accessor §13:801 requires, and M5 ships its caller (§3). One
  consequence worth stating so it is not read as a gap: §16.3:925's **pass 7
  (span-state dataflow) stays absent**. The second, `parser-error-domain`'s
  single producible value, is the Exit block's first limitation.
- **Counted consume** — Milestone 6 (§25:1593-1609, §10.6:596-604, §16.2:903).
  M4 must leave one seam: field storage has to be writable by a bulk subtraction
  of an arbitrary committed count, not only by the seven operations and the
  multiply-add. It must **not** leave a shared "field compatibility" abstraction
  spanning §16.2:903 and :904. The plan keeps them as two bullets, and §4.6
  discharges :904 by folding it into §9.1:348's existing
  declared-field-reference rule — decision 0017 point 4's move, a superficially
  similar case folded into a check that already exists rather than into a new
  rule. M6's :903 arrives with its own construct and its own check, and inherits
  nothing.
- **Widening the diagnostic record to §16.4's seven fields** — Milestone 7
  (§25:1615-1616). M4 introduces field diagnostics with their owning constructs
  and puts the offending field name in the existing `node` slot (§4.6); it does
  not touch the record's shape. Severity has no discriminating value in v0.1
  anyway (§16.4:938 fixes it at `error`).
- **Additional field types** — signed integers, an enum type distinct from a
  sufficiently wide `uint`, and anything else beyond the one `uint` declaration
  — §29:1754. This is what makes §16.2:904 contentless in v0.1 (§4.6).
- **Packed or specialized field storage, unsafe or fixnum-specialized
  arithmetic, transition tables, and peephole optimization** — §29, gated by
  §23.3:1369 behind reproducible compiled benchmarks in both lanes, plus the
  §23.3:1380 decision record. `bench/` holds two `.gitkeep` files and nothing
  else, so no §23 evidence can exist yet. §19.2:1011's "generic exact arithmetic
  with declared-bound checks" is the admitted lowering, and §15:856 forbids the
  `bitwise-and`-to-width idiom `fnv1a-64` uses (§6).
- **§18:974-985's interpreter trace hook.** Not built in M4 (§4.6). It is
  interpreter-only and opt-in, two of its eight payload kinds are M5 vocabulary
  (callback invocation and result; span start/fragment/end), and §18:985's "must
  not alter semantic callback ordering" constraint cannot be tested until
  callbacks exist. It is interpreter-private, so adding it later costs nothing
  that adding it now saves.
- **Everything the private HTTP fixture does *with* fields** — `Content-Length`,
  chunk sizes, chunk extensions, framing conflicts — is Milestone 8
  (§25:1629-1642), as is case-insensitive recognition of the framing headers
  (§25:1637, item 5). M4 ships the mechanism; M8 spends it. Slice ③'s proving
  surfaces borrow the *shape* of §21.2's `Content-Length` and chunk-size
  productions without implementing the fixture.
- **The property generator drawing callbacks, spans, or counted consume** —
  those milestones. §22.6:1295 says to include each feature "as each feature
  becomes available", and Slice ③ adds only the field draws.
- **Any change to advance/reexecute semantics, lookahead, or rewind.** M4
  introduces no new cursor concept (§11:642-664); §11.3:648 still forbids
  rewind.
- **Linux arm64, Windows amd64, and the Windows CRLF/EOF proof** — Milestone 9.
  M4 CI stays the two Tier-1 cells (macOS arm64, Linux amd64).

## 10. Handed to writing-plans

- **Gate 0 record forms.** Five records (§4.1 the unversioned ABI constructor;
  §4.2 encoding format v2 pre-provisioned; §4.3 the constructor/verifier split
  *and* the `error`-slot rule; §4.4 multi-successor EOF classification; §4.5 the
  structured parser-error record). writing-plans assigns numbers from **0018**
  and confirms two possible merges. §4.1 and §4.2 both land in Slice ①a and both
  move emitted bytes, but they govern *different* seams — runtime↔generated
  versus the canonical encoding — with different lineages (0012 versus
  0009/0016); merging them would put an amendment to 0012 inside a record about
  fingerprints. §4.3's `error`-slot rule is deliberately fused with the
  constructor/verifier split because its enforcement *is* that split. §4.1 must
  additionally carry its dated amendment note onto decision 0012 itself, and its
  parent-plan amendment into §9.5.
- **Exact proving machines.** §5–§8 specify the *properties*; writing-plans pins
  the concrete node wiring — the four distinct non-zero initials and the ≥2^60
  u64 initial that prove storage in ①b, together with that slice's accepted `0`
  and `2^w − 1` and rejected `2^w` at each width; the width × operation ×
  boundary matrix and its underflow and overflow cells in ②; the zero-width
  self-loop that must be *rejected* by `pass-zero-progress`; the EOF chain
  through a field branch that ②'s `eof-terminal` rewrite must classify; the
  multi-digit number and its interior split points in ③; and the base-10 and
  base-16 partitions that must differ on exactly twelve bytes.
- **The ordered task list for Slice ①a**, which is a correctness constraint
  rather than a preference, and its single-re-baseline gate. Same for Slice ②,
  whose Task 1 is the `eof-terminal` rewrite and whose oracle is "no diagnostic
  on any existing fixture changed", and Slice ③, whose Task 1 is the
  `eof-target-of` fix.
- **Mutation pin re-anchoring, measured.** All mutations run at the default
  `SITES=1`, so every `FIND` must be unique in its file, and `SITES` fails in
  **both** directions: a new function cloning a shipped skeleton duplicates the
  incumbent's pinned `FIND` lines. M4 will write a field-action constructor and
  a field-branch constructor with near-identical `arguments` guards, and three
  emitter arms with near-identical shapes — anchor each to its own `define` or
  `case` line, and re-sweep both directions against a control run on the merge
  base. Re-anchoring is a re-**measurement** of each pin's failure signature,
  not a text edit; per AGENTS.md:170-171 the obligation is recorded by mutation
  LABEL, not by line number.
- **Lane and manifest bookkeeping**, which is fatal-on-error rather than
  warning: every new test program needs a source+AOT pair (the AOT lane resolves
  libraries only through objects compiled from its own `SOURCES`), each with a
  required `TIMEOUT` and a unique five-segment name under the configure-time
  regex; any new fixture `.sls` must appear in **both** lanes' `SOURCES`;
  basenames must be unique within a lane; and any new `.sls` changes the lane's
  content fingerprint, which the harness verifies at `harness-begin`.
- **The golden environment-variable trap.** A mutation pass over a golden reads
  that golden's path from its own `BYTE_MACHINE_*_GOLDEN_FILE` variable in the
  mutation suite's ctest registration. Add the golden without the variable and
  the pass's **baseline** fails, which reads as a mutation defect rather than as
  the missing environment it is. Verify the current variable set against
  `test/CMakeLists.txt` first; the Appendix's CMake row carries the pattern.
- **Completion sentinels.** No suite declares an expected case or check count,
  so exhaustive loops **pass vacuously**. Every new loop in this milestone — the
  width × operation matrix, the two 256-byte base partitions, the per-position
  split loop — needs its own sentinel, and the sentinel must count **observed**
  drives rather than be computed from the test's own expectation. The loop over
  the loops needs one too.
- **Mutation discipline** (AGENTS.md): every decision gets a mutation asserting
  a measured failure **signature**, not a bare nonzero exit; re-run the
  **whole** mutation suite after adding any exit path, because a new exit path
  can silently disarm an existing mutation by making baseline and mutant land on
  the same status; adding mutations to a lane widens every existing pin's
  collision set in that lane silently; add no new dependencies.
- **Sizing is a floor, not an estimate.** Milestone 3 — one new node kind, no
  runtime change, no ABI change — moved `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`
  from 38/165 to **46/236** (+8 passes, +71 mutations) and the release lane
  count to 86. M4 adds three node kinds, a declaration kind, a runtime change
  and an ABI change M3 explicitly declined. Write only **measured** numbers into
  `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`, the CHANGELOG, or any record — and
  re-locate every citation before repeating it: the M3 design cites those two
  settings at `SchemeMutationSuite.cmake:554-555`, and they are now at
  **:734-735** — a citation into a file its own milestone edited, stale on
  arrival and invisible to any link check.
- **TDD** (§22.1): failing tests first for each slice.
- **Status surfaces.** A slice that closes this milestone is not done until the
  parent plan's §25 close note, this document, `CHANGELOG.md`'s `[Unreleased]`
  preamble, and **`README.org`'s status paragraph** all say it closed.
  README.org is the one no step names — and it carries a *second* unnamed
  surface, the documentation list at `README.org:76-80`, which stops at the
  Milestone 3 design. That list needs a row for this document, added in the PR
  that lands it rather than at close: measured, M2's row arrived only with the
  PR #24 sweep and M3's only with the closing slice PR #35, and
  `AGENTS.md:283-286` records that list among the stale claims PR #24 corrected.

## 11. References

- Parent plan:
  [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md) —
  §9.1 (construction calls, operation and predicate tables), §9.2 (compile and
  emission), §9.3 (runtime calls, and the `parser-error-*` family at :397-405),
  §9.4 (conditions), §9.5 (generated runtime ABI), §10.1-10.2 (descriptor and
  field declarations), §10.6 (the closed node-kind set), §11 (transition and
  cursor semantics), §12.5 (reset), §12.7 (runtime error structure and the
  position table), §13 (callback contract), §15 (fixed-width field semantics),
  §16.2-16.4 (required checks, passes, diagnostics), §17 (normalization), §18
  (reference interpreter), §19 (direct-code backend), §21 (private HTTP
  fixture), §22 (testing strategy), §25 (milestones), §29 (deferred
  optimizations).
- [milestone-3-design.md](./milestone-3-design.md) — the document shape this one
  follows, and the source of the deferrals M4 inherits (§8).
- [milestone-2-design.md](./milestone-2-design.md) §7 — the twice-stated
  deferral of the `parser-error-*` family, and the rule against populating one
  field of an otherwise-deferred family.
- [decision 0009](../decisions/0009-content-and-ir-fingerprints.md) — what the
  IR fingerprint covers, and therefore what §4.2's field table has to enter.
- [decision 0010](../decisions/0010-direct-executor-abi.md) — item 4's
  extend-by-version seam, which §4.1 amends the *mechanism* of without changing
  its purpose.
- [decision 0011](../decisions/0011-eof-execution-model.md) — its point 4's
  three EOF verification checks, whose walk §4.4 generalizes to multi-successor
  zero-width nodes and Slice ③ extends to an input-reading kind.
- [decision 0012](../decisions/0012-generated-abi-v2-finish.md) — amended by
  §4.1.
- [decision 0015](../decisions/0015-sequence-prefix-states.md) point 3 — the
  interpreter-independence rule that makes M4's arithmetic get written twice.
- [decision 0016](../decisions/0016-normalized-state-id-allocation.md) — the
  declaration-index-is-the-id precedent that field slot assignment follows.
- [decision
  0017](../decisions/0017-degenerate-shapes-are-contract-violations.md) — whose
  reasoning §4.3 explains does *not* transfer to fields, and whose point 4 is
  the precedent §9 cites for folding a check into one that already exists rather
  than building a shared field-compatibility abstraction.
- `AGENTS.md` — testing and mutation discipline, documentation and record
  discipline, and the closing ritual.

The section is complete and verified. Returning it now.

## Appendix — per-library change map

| Library | M4 change |
| --- | --- |
| `graph`/`private ir` | **①a: no change, and record it** — the ABI collapse (§4.1), the format-version bump and the `parser-error` family are all downstream of the source IR, and the `fields` argument of `make-machine` (pre-slice `ir.sls:352-366`) plus `machine-fields` (pre-slice `ir.sls:370`) already exist. Measured: `rg -n 'machine-fields' src/ test/` returns **two hits, `ir.sls:10` and `ir.sls:370`** — the export and the definition. It is a shipped accessor with **zero readers anywhere in the tree**; ①b is what first reads it. **①b:** `make-uint-field` (§9.1:283, `(make-uint-field name width initial source-label)`), `uint-field?`, and one accessor per §10.2:488-491 part (name, width, initial, optional label), with §4.3's construction-time checks (`width` in {8,16,32,64}, `initial` an exact integer in range); `make-machine`'s existing `(list? l)` collection loop (pre-slice `ir.sls:357-360`) gains `(for-all uint-field? fields)` beside the shipped `(for-all node? nodes)` (pre-slice `ir.sls:361-362`); `machine-ir-version` (pre-slice `ir.sls:351`, a bare `define` stamped into machine slot 1 at pre-slice `:365` with **no accessor anywhere**) gains one, so `pass-schema` can read it (§4.7 item 3). **②:** `make-field-action-node` and `make-field-branch-node`, each carrying the operation or predicate tag that §4.6's emission-time fan-out expands, and the field-action `error` slot that is a target node name or `#f` (§4.3's `error`-slot rule, on the `eof-target` precedent at §9.1:318 whose shipped shape is the `(or (symbol? eof-target) (eq? eof-target #f))` guard at pre-slice `ir.sls:230-231`). **③:** `make-integer-accumulate-node`, plus §4.7 item 4's tag guards on `byte-dispatch-node-cases`/`-fallback`/`-eof-target` (pre-slice `ir.sls:235-237`, three bare `vector-ref`s). Those three are not uniquely unguarded — every node accessor in the file is a bare `vector-ref`, and the only tag-guarded accessors here are the matcher and sequence-case ones (pre-slice `:68-71`, `:107-110`, `:122-129`, `:142-146`, `:305-312`). What singles these three out is that `interpret`'s `eof-target-of` and `dispatch` reach them with a node of another kind (census sites 20 and 21); nothing reaches the four sequence accessors (pre-slice `:331-334`) that way, so they stay out of scope with the reason stated in place. ② and ③ each add their kinds to `node?` (pre-slice `ir.sls:337-339`) and `node-name` (pre-slice `ir.sls:340-347`). Every one of ①b, ② and ③ edits `graph.sls`'s export list (pre-slice `graph.sls:12-25`) **and** its `only` import list (pre-slice `graph.sls:26-40`) — the M3 rule, unchanged. Internal canonicalization helpers stay unexported for the reason recorded at pre-slice `graph.sls:8-10` about `matcher-bytes`. |
| `verify` | **①a: exactly one edit** (§5's must-not-touch paragraph) — `pass-names-valid` (pre-slice `verify.sls:461-477`) is extended over `error-declaration-reason` with §10.1:480's printable-ASCII-plus-LF repertoire, *inside the existing `machine-errors` arm's* condition and its single diagnostic (pre-slice `:472-477`), reusing the existing `invalid-name` code (§4.7 item 1). It adds no fourth `invalid-name`-emitting site and no new code, so §4.6's two-new-codes budget holds. Every other pass is matcher-, node- and field-agnostic in ①a — recorded here because an implementer "extending every pass for M4" breaks their pins for nothing. Because a check joins the pass, ①a owes the whole-pass pin sweep in the `SchemeMutationSuite.cmake` row below. **①b:** `pass-schema` (pre-slice `verify.sls:107-108`, a single-line `machine?` tag test) gains §16.2:884's unsupported-IR-version check (§4.7 item 3 — note the plan line is **:884**, not :885); and new **pass 6a, declaration half only** — duplicate field names and portable field names, reusing `valid-name?` (pre-slice `verify.sls:43-50`) exactly as `pass-names-valid` does — carrying **one** code, `invalid-field-declaration`, with the offending FIELD name in the diagnostic's existing `node` slot (pre-slice `verify.sls:29`, `:33`). Pass 6a is a separate pass precisely so `pass-names-valid` grows no further arm. **②:** pass 6a gains the **operand half** — exact arity against the operation or predicate, `field` naming a declared field, `constant` and `mask` within the referenced field's declared width, `low <= high` for `range` — under the second code, `invalid-field-operand`, and the pass joins `verify-machine`'s `append` (pre-slice `verify.sls:480-490`) after `pass-names`. The two zero-width kinds are taught to the census sites below **in the same commit as the kinds**. Both are zero-width like pause, so `reexec-targets` (pre-slice `verify.sls:263-322`) and `pass-zero-progress`'s REPORT guard (pre-slice `verify.sls:333`) must gain them or a `store`-into-itself machine verifies clean and hangs — the exact failure M3 Slice ② measured and recorded at pre-slice `verify.sls:307-318`. For §16.2:908/:909 they follow the **pause** precedent (§4.6): the byte-reachability gates at pre-slice `verify.sls:438` and `:448`, **not** the unconditional source-kind filters at pre-slice `:400` and `:414`, which stay byte-dispatch/sequence-only. `pass-overlap` (pre-slice `verify.sls:185-188`) and `pass-sequence-ambiguity` (pre-slice `verify.sls:246-249`) stay unextended, permanently, for the reasons already written beside them. **③:** integer-accumulate's four explicit targets join `node-out-targets` (pre-slice `verify.sls:58-74`) and `node-eof-target` (pre-slice `verify.sls:82-85`); the declared-field-reference check discharges §16.2:904, reported under ②'s `invalid-field-operand` with no new code, and the design records that with exactly one field type that bullet has no independent content (§4.6). |
| `private normal-ir` | **①a: the encoding format version byte goes 1→2** (pre-slice `normal-ir.sls:254`, the `(put-u8 p 1)` that is the first byte `encode-normal` writes), and the same bump carries §4.2's two pre-provisionings and one debug deliverable: the **reserved field table encoded as a count of zero**; the error declaration's static **`reason`** appended after the code at **both** encode sites, the error arm (pre-slice `:276`) and the dispatch default-eof arm (pre-slice `:274`), which normalization discards today (`errcode`, pre-slice `:144-147`, resolves a declaration name to `error-declaration-code` and nothing else); and §17:963's state-ID-to-source-name debug map as a **fifth member** of the normal-machine vector (pre-slice `make-normal-machine`, `normal-ir.sls:28`, today the four-slot `(vector nm-tag entry states fp)`), built here and totalized over internal prefix states. The map cannot perturb a fingerprint: `encode-normal` is called as `(encode-normal entry states)` (pre-slice `:285-286`) and never sees names. The `compile` row emits it. This is the one place M4's re-baseline is paid: **every existing IR fingerprint moves once, here**, and ①b then fills a slot that already exists so a zero-field machine encodes byte-identically and **no existing golden or fingerprint moves in ①b** (§4.2). Hazard for whoever pins this: the literal text `(put-u8 p 1)` occurs **three times** in `encode-normal` — the format-version byte at pre-slice `:254`, the stop tag at pre-slice `:275`, and the default-eof tag inside pre-slice `:274` — so any mutation anchored on it must use a longer surrounding string or the suite reports "pattern occurs 3 times ... expected 1". **①b:** the reserved table filled from `machine-fields`. **② and ③:** §4.6's three new normalized state kinds, tags 5, 6 and 7, at exactly two sites each — `declared`'s lowering `cond` (pre-slice `normal-ir.sls:206-239`) and `encode-normal`'s `case` (pre-slice `normal-ir.sls:260-281`), both with LOUD `else` assertion-violations (pre-slice `:239`, `:280-281`). The `ns-tag` slot map comment (pre-slice `normal-ir.sls:35-40`) and the header comment claiming the repertoire is "six kinds ... a SEVENTH" (pre-slice `normal-ir.sls:72-76`, repeated at pre-slice `:236-238`) are **wrong the moment ② lands** and must be rewritten, not left; `normal-pause-target` (pre-slice `normal-ir.sls:47`, a bare `(cdr (vector-ref s 6))` with no kind guard) is the shipped precedent for a kind-specific accessor reading a shared slot. `prefix-blocks` (pre-slice `normal-ir.sls:166-174`) stays sequence-only and its silently-skipping `else` is **correct** for the new kinds — §4.6's lowering is 1:1, so they allocate no internal states. Record that, because the census below flags that site as silent and a reader will otherwise "fix" it. |
| `compile` (emitter) | **①a:** `reserved-member-2` (pre-slice `compile.sls:44-52`) is the hand-maintained mirror of the runtime's exports, so §4.1's rename **and** the `parser-error` family must land in it in the same commit or `reserved-drift-tests.sps` fails — it asserts set equality against `environment-symbols` (`reserved-drift-tests.sps:32-40`), which is the one automated guard here that already works. `reserved-member-3` (pre-slice `compile.sls:53`, twelve symbols) gets the drift guard §4.7 item 2 asks for; the code states the gap itself at pre-slice `compile.sls:101-107` ("checked, not assumed, since it has no automated drift guard"). The emitted constructor call (pre-slice `compile.sls:164`, `"(byte-machine-make-compiled-machine/v2 2 "`) becomes the unversioned name with §4.1's growable payload, carrying the empty field-initials slot and the state-id→source-name debug map. **①b:** the same call site now computes the initials vector from the declarations — for a zero-field machine the emitted text is **identical** to ①a's, which is what makes §4.2's "no golden moves in ①b" true rather than hoped — and `reserved-member-2` gains `parser-field-ref` in that commit, or the reserved-drift lanes redden. `reserved-member-3` is untouched in ①b: the initials ride the payload as a literal, not as a new emitted `define`. **② and ③:** `render-state-arm` (pre-slice `compile.sls:108-138`) is where §4.6's emitter fan-out to seven arms lives; this single `case` grows more than any other construct in M4. Every new emitted local joins `reserved-member-3` in the same commit — now enforced rather than eyeballed, and the emitted field-store local is Slice ②'s (①b emits none). **No `/v3`** (§4.1). |
| `runtime` | The heaviest ①a row. §4.1 collapses `byte-machine-make-compiled-machine/v1` (pre-slice `runtime.sls:50-56`) and `/v2` (pre-slice `runtime.sls:65-71`) into one unversioned constructor whose first action is the `(= abi-version current-abi-version)` check; `current-abi-version` (pre-slice `runtime.sls:49`) goes 2→3; both old names stay exported as tombstones (pre-slice `runtime.sls:12`). Measured warrant, re-checked here: `/v1` already **rejects** abi 1 because it compares against `current-abi-version`, which is 2, and its only two call sites in the whole suite are `runtime-tests.sps:195` and `:245`. The `parser-error` record, §9.3:397's predicate and :398-405's eight accessors land here and are exported; `parser-result-error` (pre-slice `runtime.sls:95`) now yields the record instead of a bare code symbol, which is what moves every `parser-result-error` comparison in the test programs. **①b:** field storage as a new ninth parser slot (index 8) beside `stored-error` (pre-slice `runtime.sls:98`'s layout comment and the accessor block at pre-slice `:124-135`), initialized in the generated lane from the ABI payload's initials and in the interpreted lane by `make-parser`'s `'op` arm asking the closure (the shipped asymmetry at pre-slice `runtime.sls:114` versus `:117-118`), and restored by `parser-reset!` (pre-slice `runtime.sls:330-334`) — whose own comment at pre-slice `:328-329` ("Field, span, and poisoned/busy state do not exist yet (M4/M5)") is the pre-slice marker for exactly this edit. ①b also ships `parser-field-ref` (§9.3:410), the read accessor over that slot, raising `byte-machine-contract-violation` with the new `accessor-misuse` code (§6 task 7); it is the *mechanism* half of §25:1564's "callback-visible field accessors", and only the callback that makes access callback-visible waits on M5. **② and ③:** `parser-feed-op!`'s `(case (op 'kind node) ...)` (pre-slice `runtime.sls:175-201`) and `parser-finish-op!`'s (pre-slice `runtime.sls:284-311`) gain one arm per new kind; both `else` arms raise, so a missed kind crashes rather than misbehaves. **Cross-file hazard worth carrying into ②'s task list:** `parser-finish-op!` has **no local cycle guard** and says so at pre-slice `runtime.sls:274-280` — it relies entirely on the verifier's EOF checks — so a zero-width field-action chain on an EOF path hangs there unless `eof-terminal` (pre-slice `verify.sls:356-385`) learns the new kinds in the same commit. |
| `interpret` | **①a:** whatever the `parser-error` seam needs from the oracle side (public source-node name is already the interpreter's native currency — it dispatches on node NAMES, not ids). **①b:** one new op-message arm, `'field-initials`, in the `op` closure's `case` (pre-slice `interpret.sls:119-127`) — the eighth message arm beside the seven at `:120-126`, per §6 task 6's asking-lane precedent (`(op 'entry)`, `runtime.sls:114`). `kind`, `dispatch`, `seq-step` and `eof-target-of` are untouched in ①b. **②:** new `kind` symbols and new op messages; two sites, both in the census — `kind` (pre-slice `interpret.sls:80-90`) and the op-message `case` (pre-slice `interpret.sls:119-127`, LOUD `else`). `dispatch` is deliberately not touched in ②: neither zero-width kind can reach it, because `kind` answers them separately and `parser-feed-op!` routes them to their own arms. **③:** the accumulate node, **and §4.7 item 4's fix**: `eof-target-of` (pre-slice `interpret.sls:112-116`) is a two-way `if` with **no else arm**, falling through into `byte-dispatch-node-eof-target`, a bare `(vector-ref n 4)` (pre-slice `ir.sls:237`). On an integer-accumulate node slot 4 is `digit-target`, a symbol — so it returns a **plausible-looking node name** and silently routes EOF into the digit path. Fix it with the first input-reading node, not after; `dispatch`'s guard lands in the same commit, with the byte-dispatch accessor tag guards. The independence rule at pre-slice `interpret.sls:36-42` (this library imports no normalizer library and shares no walker with one, decision 0015 point 3) governs the new kinds too: the interpreter derives field semantics from the source IR, and a proposal to share an "operation applier" with the emitter is a decision change, not a refactor. |
| `private conditions` | **No change expected in any slice, and the design should say so rather than leave it open.** `parser-error` is a *value* §12.7:751-760 calls a record, not a raised condition; the one condition type here (pre-slice `conditions.sls:13-17`) is the contract-violation for programmer errors against the public API, and `accessor-misuse` is a new *code* passed to `byte-machine-contract-violation` (`conditions.sls:19-20`), not a new type. If an implementer finds themselves adding a condition type here, the seam has moved and §6 is wrong. |
| CMake `test/CMakeLists.txt` | New source+AOT lane pairs, five-segment names, each with a `TIMEOUT`, following the shipped pattern (`byte-machine.unit.*`, `.differential.*`, `.determinism.*`, e.g. `test/CMakeLists.txt:1093-1129`). ①b: a field-declaration (`uint-field`) unit lane. ②: unit + differential pairs for field-action and field-branch. ③: unit + differential + determinism for integer-accumulate, the determinism lane carrying its own `BYTE_MACHINE_*_GOLDEN_FILE` environment variable in **both** its ctest registration and the mutation suite's registration — the pattern the comment at `test/CMakeLists.txt:576-584` records, and whose omission makes a mutation pass's BASELINE fail in a way that reads as a mutation defect. **M4 adds no new `src/` library**, so no new `BYTE_MACHINE_CORE_*` fragment is created. Do not read the eight fragments as eight copies of one list; they are nested subsets in dependency order, and the comment at `:155` claiming "each fragment grows the previous one" is itself stale. `_PRIVATE` (`:157`) names two files (conditions, ir); `_GRAPH` (`:724`) adds graph; `_RUNTIME` (`:749`) is its own two-file list (conditions, runtime), not an extension of `_GRAPH`; `_VERIFY` (`:772`) adds verify; `_ALL` (`:796`) unites `_VERIFY` and `_RUNTIME` plus interpret, deduplicated at `:805`; `_NORMAL_IR` (`:875`) is `_VERIFY` plus normal-ir; `_COMPILE` (`:902`) adds compile; and only `_EMIT` (`:925-928`) resolves to all eight product `.sls` files. A new lane names the fragment matching its own dependency closure — `_EMIT` where it needs the whole pipeline — and every new fixture `.sls` goes into that lane's own `SOURCES`, never into a fragment. |
| `SchemeMutationSuite.cmake` | Mutations for every new decision, each with a **measured** failure signature. Pins that move in ①a, named by LABEL rather than line because the line is stale on arrival: "runtime: a mismatched generated-runtime ABI version is accepted" (its `FIND` is the `/v1` guard text, at pre-slice `:2544`) and "runtime: a mismatched /v2 ABI version is accepted" (pre-slice `:2722-2727`) both anchor on constructor text §4.1 rewrites; "compile: reserved member 2 is not checked" (pre-slice `:5221-5226`) and "compile: reserved member 3 is not checked" (pre-slice `:5228-5233`) survive textually but their *baselines* move with the reserved lists. Of the **23** `normal-ir:` pins in the pre-slice `:4770-5151` and `:6618` band (22 in the band plus the one at `:6618` — the same 23 §5's census counts), only the **seven** carrying a measured `got` digest (pre-slice `:4773`, `:4780`, `:4787`, `:4889`, `:4907`, `:4958`, `:4980`) re-baseline when the format version byte moves, and by re-measurement against a staged copy rather than recomputation; the other sixteen assert transition lists, counts, ids and raises, survive textually, and must be re-checked for `SITES` rather than assumed. ①a also owes the Pass 33 whole-pass sweep over `verify.sls`'s **44** pins (measured: 42 on `byte-machine.verify.rejections.chez.source`, 2 on `byte-machine.verify.identifier-repertoire.chez.source`), in both directions with a merge-base control, because ①a joins a check to that pass — the trigger the pass's own header records at `:3230-3241`. In ③, "interpret: eof-target-of does not dereference a compound back to its source node" (pre-slice `:4605`) is re-anchored, and re-measured **in both directions** — the incumbent against the fixed accessor, and the new tag-guard pin against the old mutant. `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` are at **`SchemeMutationSuite.cmake:734-735`**, declaring the measured **46 / 236**; the M3 appendix's `:554-555` had already drifted 180 lines by the time this was written, which is the argument for naming pins by LABEL. Updated from measurement only. |
| Harness machines `test/support/harness/byte-machine/test/*.sls` | New fixture machines, one per slice, built only through `(byte-machine graph)` on the shape of `pause-machine.sls:11-28`: a field machine (①b), a field-action/field-branch machine (②), and a base-10 and base-16 accumulate machine (③) whose digit repertoire is §4.6's `0-9`, `A-F`, `a-f`. Every existing fixture keeps `'()` in `make-machine`'s `fields` position (e.g. `pause-machine.sls:12`, `class-machine.sls`, `http-version-machine.sls`, `sequence-node-machine.sls`), which is the concrete reason existing encodings do not move in ①b. |
| `machine-gen.sls` (property lane) | The generator threads `'()` for fields at `machine-gen.sls:129`. **①a, ①b and ②: no draw, and record it** — no slice before ③ adds a drawable construct, and §22.6:1295's "as each feature becomes available" puts the one M4 draw in ③. **③:** one accumulate node behind its own coin, reachable by a pinned case, targeting `stop` on the digit edge, with a declared u8 field so overflow is reachable inside 256 draws (§8 task 9), plus an `accumulated-count` anti-vacuity guard asserted `>= 1` beside the shipped `paused-count`/`finished-count`. Its by-construction argument: an accumulate node is *consuming*, so it forms no zero-progress cycle, and the field it reads is declared in the same draw, so pass 6a's declared-field-reference check holds by construction. **Every addition must obey the three by-construction constraints already documented at `machine-gen.sls:9-49` and `:105-118`** — the generator's whole contract is that it never manufactures a verifier rejection, and a zero-width field-action node drawn as a self-target is a zero-progress cycle by exactly the argument recorded there for `pausep`. If a slice cannot state the by-construction safety argument, it does not add the draw. |
| The three golden fixtures | `test/fixtures/generated-one-byte.golden.sls`, `generated-pause.golden.sls`, `generated-http-version.golden.sls`. **All three move in ①a and only in ①a**: each ends in a `byte-machine-make-compiled-machine/v2 2 <fingerprint> <entry> exec` call (`generated-one-byte.golden.sls:19-20`, `generated-pause.golden.sls:32-33`, `generated-http-version.golden.sls:84-85`), and both halves change — the constructor name by §4.1, the fingerprint by the format-version bump. `compile-tests.sps:165` pins the same string literally and moves with them. ③'s new determinism lane adds a fourth golden. **No golden moves in ①b, ② or ③** for a machine that declares no fields and uses no new kind; a slice that finds one moving has broken §4.2's reservation and must stop rather than re-baseline. |
| Per-test-program files `test/common/*.sps` | ①a touches the most: every comparison of `parser-result-error` against a bare code symbol becomes a `parser-error-code` read — the differential programs' `rfields` helpers are the concentration point (`property-differential-tests.sps:36-38` and its sibling at `differential-pause-tests.sps:31-33`), and §22.4:1262-1272's list is what those helpers encode, so ①a extends them with error domain, node name, position and position kind, and ①b with field state. `runtime-tests.sps:195` and `:245` are the two `/v1` call sites §4.1 retargets, and `:289-306` the `/v2` ones. `reserved-drift-tests.sps` needs no edit at all — it computes both sides. New programs, and the exit-criterion shares they carry: field declarations and pass 6a's declaration half in `verify-tests.sps` plus a new unit program, carrying §25:1568's **declaration-time** bounds (initial `0` and `2^w − 1` accepted, `2^w` rejected, all four widths) (①b); field-action/field-branch unit + differential, carrying §25:1568's **operation** matrix — underflow at `decrement` from 0, overflow at `increment`/`add` from each width's maximum — and the seven-operation half of §25:1569 (②); accumulate unit + differential + determinism, carrying §25:1568's **accumulate-overflow** cells at each width including the u64 bignum row, and the accumulate half of §25:1569's "failed operations leave prior values unchanged" (③). |

### Node-kind enumeration sites

The complete checklist of places a new node kind or normalized state kind must
be added. **Missing one is the defect this appendix exists to prevent**, and the
failure mode is not uniform: some sites raise, and some quietly return `'()`,
`#f` or `'unknown` and let a malformed machine verify clean.

**How the sweep was done.** Two methods, because a single grep provably cannot
find this set — `verify-tests.sps:523-524` records that a grep for
`byte-dispatch-node?` "cannot see a `cond` dispatching through OTHER kind
predicates and so cannot find its own omission". First, `rg -n --
'-node\?|\bnode\?|normal-state-kind|node-kind' src/`. Second, **every one of the
eight `.sls` files in `src/` read end to end — 1,859 lines total** (`compile`
172, `graph` 40, `interpret` 127, `runtime` 334, `verify` 495, `private
conditions` 20, `private ir` 385, `private normal-ir` 286). The two methods
agree, and the sweep independently reproduces the one number already recorded in
the tree: `verify-tests.sps:521-522` states that "every site in verify.sls that
dispatches on node KIND ... yields TWELVE at HEAD", and this sweep finds exactly
twelve there. The reconciliation is exact rather than coincidental: the tree's
own enumeration is eight sites under its narrower rule
(`verify-tests.sps:546-556`) plus the four its looser wording sweeps in
(`:533-540` — `pass-names`' `error-node?` filter, the two D4(b)/(d)
byte-reachability gates, and `pass-sequence-ambiguity`), which is 8 + 4 = 12 and
is exactly rows 3-14 below. The tree therefore excludes `verify.sls:404` and
`:440` too.

**Counting rule.** One site = **one syntactic branch-selection construct** (a
`cond`, a `case`, an `if`, or a `filter`/`map` predicate) whose branch is chosen
by *the kind of the node or normalized state currently being classified*.
Counted **by FILE occurrence, not by logical check**: `verify.sls`'s two
byte-reachability pause gates are the same check written twice and count twice,
because a slice has to edit both. Three classes are deliberately **excluded**,
each for a stated reason:

1. **Tests on the kind of some *other* node reached through a target** —
   `verify.sls:404` and `:440`, both `finish-node?` applied to a looked-up
   target rather than to the node being visited. Excluding these is what makes
   `verify.sls` come out at twelve rather than fourteen, and it matches the
   tree's own twelve. M4 adds no terminal kind, so neither changes; a future
   milestone that adds one must revisit them.
2. **Matcher-kind dispatch** — `matcher?` (`ir.sls:148-150`) and `matcher-bytes`
   (`ir.sls:181-196`, LOUD `else`). M4 adds no matcher kind.
3. **Executor-variant, lifecycle and outcome-status dispatch in `runtime.sls`**
   — not node kinds. Listed separately below, because M4 grows some of them
   anyway.

**The count is 23**: `private ir` 2, `graph` 0, `verify` 12, `private normal-ir`
3, `compile` 1, `interpret` 3, `runtime` 2, `private conditions` 0. **Sixteen
fail silently, seven fail loudly.** All twelve of `verify.sls`'s fail silently.

| # | Site (pre-slice) | Dispatches on | Unhandled kind |
| --- | --- | --- | --- |
| 1 | `ir.sls:337-339` `node?` | six kind predicates, disjunction | **SILENT** as a predicate (`#f`); becomes loud only at its enforcement point, `make-machine`'s `(for-all node? nodes)` at `ir.sls:361-362`. A constructor added without touching `node?` fails at machine construction, not at node construction. |
| 2 | `ir.sls:340-347` `node-name` | six kind predicates, `cond` | LOUD — `else` raises a contract violation. |
| 3 | `verify.sls:58-74` `node-out-targets` | `cond` | **SILENT** (`else '()`). A kind whose targets are invisible here is never resolution-checked and never walked for reachability. |
| 4 | `verify.sls:82-85` `node-eof-target` | `cond` | **SILENT** (`else #f`). Feeds `all-out-targets` and `pass-eof`. |
| 5 | `verify.sls:141` `pass-names`' error-node filter | `error-node?` | **SILENT** (`'()`). No M4 change: field-action's `error` slot is a target NODE name (§4.3's `error`-slot rule), not an error declaration. |
| 6 | `verify.sls:185-188` `pass-overlap` | `byte-dispatch-node?` | **SILENT** (`'()`). No M4 change, permanently — the reason is written at `verify.sls:178-184`. |
| 7 | `verify.sls:246-249` `pass-sequence-ambiguity` | `sequence-dispatch-node?` | **SILENT** (`'()`). No M4 change — sequence-only by construction. |
| 8 | `verify.sls:263-322` `reexec-targets` | `cond` | **SILENT** (`else '()`). **② must extend it**: both new kinds are zero-width. |
| 9 | `verify.sls:331-338` `pass-zero-progress`'s REPORT guard | three-way `or` of kind predicates | **SILENT** (`#f`). **② must extend it.** Extending the walk (site 8) without the report set is the exact half-fix M3 Slice ② shipped and Slice ③ closed — the measured symptom is recorded at `verify.sls:307-318`: verify returns ok `#t` with zero diagnostics, and the machine then fails to terminate in **both** lanes. |
| 10 | `verify.sls:356-385` `eof-terminal` | `cond` | **SILENT** (`else 'unknown`), and doubly so: `'unknown` then falls through the `(else '())` of the `case` at `verify.sls:417-424`. **② must extend it**, or a zero-width EOF chain is unclassified and `parser-finish-op!`, which has no cycle guard (`runtime.sls:274-280`), hangs. |
| 11 | `verify.sls:398-410` §16.2:908 filter | `(or byte-dispatch-node? sequence-dispatch-node?)` | **SILENT** (`'()`). **Deliberately not extended** (§4.6's pause-precedent resolution): the new zero-width kinds go through sites 13/14 instead, and integer-accumulate is input-reading and joins this filter. Record the decision in place, as `pass-overlap` does. |
| 12 | `verify.sls:412-427` §16.2:909 filter | `(or byte-dispatch-node? sequence-dispatch-node?)` | **SILENT** (`'()`). Same split, same reason (§4.6). |
| 13 | `verify.sls:436-445` D4(b) byte-reachability gate | `pause-node?` + `memq` | **SILENT** (`'()`). **② extends it** — the pause precedent, decision 0011. |
| 14 | `verify.sls:446-457` D4(d) byte-reachability gate | `pause-node?` + `memq` | **SILENT** (`'()`). **② extends it.** Same check as 13, second occurrence, counted separately because it is a separate edit. |
| 15 | `normal-ir.sls:166-174` `prefix-blocks` | `sequence-dispatch-node?` | **SILENT** (skips). **Correct for M4 and must stay** — §4.6's 1:1 lowering allocates no internal states for the new kinds. Flagged so nobody "fixes" it. |
| 16 | `normal-ir.sls:206-239` `declared`'s lowering `cond` | six kind predicates | LOUD — `else` assertion-violation at `:239`. |
| 17 | `normal-ir.sls:260-281` `encode-normal` | `case` on `normal-state-kind` | LOUD — `else` assertion-violation at `:280-281`. Tags 5, 6, 7 land here. |
| 18 | `compile.sls:108-138` `render-state-arm` | `case` on `normal-state-kind` | LOUD — `else` assertion-violation at `:137-138`. §4.6's emission-time fan-out to seven operation arms and seven predicate arms lives inside this one `case`. |
| 19 | `interpret.sls:80-90` `kind` | `cond` over six predicates | LOUD (`else` contract violation at `:90`) — **but** it is preceded by the `(pair? name)` representation test at `:81`, which is **SILENT**: any future compound `current` representation is classified `'dispatch` without being looked at. |
| 20 | `interpret.sls:91-104` `dispatch` | `(if (sequence-dispatch-node? n) ...)` | **SILENT AND WRONG.** The else arm feeds *any* other kind into `byte-dispatch-node-cases`, a bare `(vector-ref n 2)` (`ir.sls:235`), and the `memv`/`matcher-bytes` walk then fails far from the cause. ② does not arm it — `kind` answers both zero-width kinds separately and `parser-feed-op!` routes them to their own arms — so the exposure stays latent. **Guarded in ③**, with the byte-dispatch accessor tag guards, by an explicit `else` raising `byte-machine-contract-violation` as `kind`'s own does at `:90`. A guard, never an arm: a zero-width kind has no `(target . mode)` to return. |
| 21 | `interpret.sls:112-116` `eof-target-of` | two-way `if`, **no else arm** | **SILENT AND WRONG — the §4.7 item 4 defect.** Falls through to `byte-dispatch-node-eof-target`, a bare `(vector-ref n 4)` (`ir.sls:237`). On an integer-accumulate node slot 4 is `digit-target`, a **symbol**, so the walk gets a plausible node name back and routes EOF into the digit path. Fixed in ③, with the first input-reading node. |
| 22 | `runtime.sls:175-201` `parser-feed-op!` | `case` on `(op 'kind node)` | LOUD — `else` assertion-violation at `:201`. |
| 23 | `runtime.sls:284-311` `parser-finish-op!` | `case` on `(op 'kind node)` | LOUD — `else` assertion-violation at `:311`. Note this loop has **no cycle guard** by design (`:274-280`); its termination is site 10's responsibility. |

**Adjacent enumeration sites M4 also grows, excluded from the 23 by the counting
rule.** They are listed because "not a node kind" is not the same as "not an
edit". `interpret.sls:119-127`, the op-message `case` (LOUD `else`) — ①b adds
`'field-initials`, then ② and ③ add one message per new `kind` symbol;
`runtime.sls:112-123`, `make-parser`'s executor-variant `cond`, and
`runtime.sls:154-157`, `parser-feed!`'s variant `case` — **both fall through to
the v1 arm silently**, so §4.1's collapsed constructor must be added to them
explicitly rather than relied on to land somewhere; `runtime.sls:250-254`,
`parser-finish!`'s variant `case`, which is LOUD. Lifecycle dispatch
(`runtime.sls:145-164`, `:239-254`, `:318-322`) and feed-outcome-status dispatch
(`runtime.sls:158-163`, `:265-270`) take **no M4 change** — poisoned/busy are M5
rows, and M4 introduces no new status.
