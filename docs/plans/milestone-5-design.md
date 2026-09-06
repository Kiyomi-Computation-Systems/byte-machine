# Milestone 5 Design — Callbacks, poisoning, and spans

**Status: closed 2026-09-06 with Slice ④.** Gate 0 discharged 2026-09-04 (decisions 0024-0029, PR #56); Slice ①a landed 2026-09-04 (PR #58 = `87a99c9`); Slice ①b landed 2026-09-04 (PR #61 = `c011e35`); Slice ② landed 2026-09-05 (PR #65 = `0578bdf`), which also **rewrote this document's Appendix in place** — its stated recogniser could not find two rows the Appendix itself listed. Slice ③ landed 2026-09-05 (PR #68 = `b26065e`): the eleventh and twelfth node kinds, pass 7's span-state lattice, `§16.2:898`'s reachability gate, wire tags 11-13 and the second internal-state family, execution in both lanes with `§19.3:1024`'s boundary flush, and the oracle. It **rewrote this document's Appendix in place a second time** — nearly every line number in the table had moved (all but `zero-width-edges`, and three range rows whose start was unchanged), and the first correction's own diagnosis was wrong: the recognisers found both defect sites and one already had a row, so what failed was the checklist pass. It also **corrected §8's reset citation and §9's slot measurement in place** (sixteen slots, three of which can hold a bytevector, and why the conclusion survives), and **recorded in §9 that Slice ④'s liveness probe discriminates in both lanes**, measured through the real harness. Slice ④ closed the milestone 2026-09-06 (PR #71 = `6bfa8ed`): the three-layer retention oracle in both lanes, the three uncovered SHAPES of `§25:1589`'s EOF and reset legs — ③ having already shipped both legs it disclaimed here, which is recorded in ④'s plan as F1 — `§27:1694`'s lifetime reference, and the close-out's two deferrals written at their receivers' source sites. The oracle is reachability-based rather than a slot walk — that is finding F2 of ④'s plan, not a question §9 poses; §9 prescribes the weak-reference probe from the start and its slot paragraph is a measurement, not an alternative.

**Originally written when nothing had started:** Milestone 4 closed 2026-09-03 (its close note is a dated
disposition in the parent plan, `§25:1568-1570`, written 2026-09-04). Milestone 5's two
hardening slices closed 2026-09-04 — Slice ⓪ (PR #52 = `5aa99a1`) and Slice ⓪b, in the same
merge — and their standards landed as PR #53 = `db86ab6`. Milestone 5's own scope has not
begun. This document is written against `db86ab6` on branch `docs/milestone-5-design`,
`main` at the same commit, tree clean, `release` 98/98, scheme mutation 52 passes / 376
mutations.

**Every citation in this document was measured on 2026-09-04 against `db86ab6`.** Parent-plan
citations are `§section:line`; source citations are `file:line`. Two classes of staleness are
known and neither is caught by any tool in this repository: a `src/` line number moves when a
slice edits the file above it, and a `§section:line` moves if anything is ever *inserted* into
the parent plan's body rather than appended to its dispositions section. Where a citation is
load-bearing this document names the *construct* as well as the line, so a reader who finds
the line wrong can still find the thing.

> **Amendments.** This document's amendment law, stated before there is anything to amend, and
> taken from `AGENTS.md`'s "Correct a stale instruction in place; annotate a stale record":
> a **record** here — a measurement, a finding, a count taken against the tree — gets a dated
> note appended and is never rewritten, because a record edited to agree with a later decision
> stops being evidence of anything. An **instruction** — a scope allocation, an obligation
> handed to a slice, a resolution a slice must implement — is corrected in place, because
> leaving a false one is a landmine and what it used to say is in git. Later dated notes are
> indexed here, newest first, each naming the section it amends.
>
>
> **2026-09-04, the review of the first draft (`6ee27bc`).** No *record* here has been amended;
> everything the review moved was an **instruction** and was corrected in place, per the law
> above. Kept as a record because a reader should know what the first draft got wrong: sixty-four
> findings raised, twenty-nine refuted, and of what survived, the two that mattered were **§5's
> forward oracle** — it asserted an empty `git diff -- test/fixtures/`, which is false, because
> the goldens are emitted *text* and this slice moves two lines in each — and **the appendix
> census**, which asserted completeness while missing six rows, one of them the very site that
> shipped a Milestone 4 defect. Both are now stated with the recogniser or the measurement that
> makes them checkable. Three arguments were also weakened from "decisive" to what the artifacts
> actually support (§4.3, §4.6, §4.12 item 4); in each case the resolution was right and the
> stated reason was not.
>
> **2026-09-04, the Slice ② plan's measurements** — **amends §7 and the Appendix**: §7's first
> oracle named a closure shape that cannot be compared, and its divergence list assigned Slice
> ③'s `pass-zero-progress` gate to ②. The Appendix was superseded by the ② plan's §1, whose
> re-measurement found its stated recogniser cannot find two rows the Appendix itself lists.
>
> **2026-09-05, Slice ② Task 9** — **the Appendix is REWRITTEN in place**, not
> annotated: a table a later slice works as a checklist is an instruction, and an
> instruction that cannot be followed gets corrected. It now states three
> recognisers (the third for wire-kind dispatch), counts export and import lists
> as rows, and carries the `test/` censuses the shipped `src/`-only scope hid —
> one of which, `verify-tests.sps`'s §16.2:908 kind list, Slice ② found late
> because of exactly that scope.
>
> > **2026-09-04, the Slice ①a plan's measurements** — **amends §5**: its position-axis bullet
> told an implementer to derive the position names "from the IR", and there is nothing in
> `ir.sls` to derive them from. Corrected in place with what the row can actually be and what it
> is worth. Decision 0025 point 4 repeats the same instruction and carries a dated note.
>
> > **2026-09-04, Gate 0's execution and review** — **amends §4.1 and §4.7**, two more arguments
> that did not carry. §4.1 argued the condition channel "was not left open" from the absence of a
> callback-contract entry in `§9.4:438`; that list opens "Codes include" and rules nothing out by
> absence. Replaced with `§12.3:719`, which names callback application error on the error result
> channel positively. §4.7 called its graph argument decisive for both halves of the resolution;
> it forces the *shape* (fixpoint, not enumeration) and says nothing about reporting at merge
> points, which rests on interpretation alone and now says so.
>
> **2026-09-04, writing the Gate 0 plan** — **amends §4.4**: its resolution as first written
> ("one merged pre-order over declared nodes … at its own position in declaration order") reads
> as interleaving internal states with declared ones, which contradicts decision 0016 item 1's
> **two-phase append**. Found while verifying the Gate 0 plan's citations, not by the design
> review. Corrected in place as an instruction; 0016's phase boundary stands and the merged
> pre-order operates inside phase two.
>
> **2026-09-04, the owner's decision on §4.12** — **annotates §4.12 and §10**: items 1, 2 and 3
> approved and in scope; item 4 declined and moved to §10's exclusions. §4.12's heading and
> preamble are corrected in place as instructions; the decision and its date are recorded on
> each item.

**Governing plan.** The parent plan's `§25` "Milestone 5" subsection is authoritative. Its
Scope list is `§25:1576-1584` and its Exit criteria are `§25:1588-1591`. **This document
changes no scope and rewords no criterion**; where it appears to say something the parent does
not, the parent wins and this document is wrong. Four additions this document *proposes* are
collected in §4.12 and are not in scope until the owner approves them on a stated date.

---

## 1. Summary

Milestone 4 left a machine that can declare unsigned integer fields, write them with
zero-width actions and branches, and read them from the input stream with a checked
integer-accumulate node. It cannot talk to the application at all: no callback is ever
invoked, no byte range is ever handed out, and the only way a parser communicates is through
its result and its field values after the fact.

Milestone 5 makes the machine *call out*. It adds three node kinds, two declaration families,
two lifecycle states' worth of guarding, one poisoning mechanism, and the first byte ranges
this system has ever handed to code it does not control. That last one is why the milestone's
fourth exit criterion is about what the runtime *does not keep*.

**Measured, and it is the number that shapes everything below.** `§10.6` declares a closed set
of **thirteen** node kinds (thirteen `####` headings at plan lines 536-618; the closure
sentence is `§10.6:534` "The source IR supports the following closed set", reinforced by
`§10.6:622` "No arbitrary custom node, embedded lambda, or backend code escape hatch exists in
v0.1"). **Nine are shipped** (`src/byte-machine/private/ir.sls:484-488`, `node?`'s nine
disjuncts). Milestone 5 adds **three** — callback invocation, span start, span end. Milestone 6
adds the thirteenth, counted consume.

Adding three node kinds at once is the single largest structural risk this milestone carries,
because it is exactly the shape of every verifier defect Milestone 4 Slice ③ shipped: a new
kind reached the shared accessors and missed a hand-written per-kind filter, silently. **The
defect surface is measured, not estimated** — see §3's site census and the appendix.

| Phase | Kind | Produces | Discharges |
|---|---|---|---|
| Gate 0 | decisions only | records 0024+ | nothing; unblocks every slice |
| Slice ①a | seam | ABI payload member, exec signature, encoding shape, position-axis drift row | no `§25` bullet; pays every artifact move once |
| Slice ①b | declarations | callback and span declarations, binding resolution, five missing `§9.3` exports | `§25:1576` |
| Slice ② | node kind + lifecycle | callback-invocation node, outcomes, `busy`, reentrancy, poisoning | `§25:1577`, `:1578`, `:1579`, `:1580`; exit `:1588` |
| Slice ③ | node kinds + dataflow | span start/end, fragments, completion-pending, span verification | `§25:1581`, `:1582`, `:1583`, `:1584`; exit `:1590`, and `:1589`'s boundary/pause/completion/error legs |
| Slice ④ | evidence | retention oracle with its negative control, EOF/reset fragment legs, the lifetime reference | exit `:1591`, and `:1589`'s EOF and reset legs; the milestone close note |

**Dependency order is strict and each edge is forced, not preferred.** ①a before ①b because
the generated lane's `make-parser` sees only the ABI payload, so a declaration cannot reach it
until the payload has a member to carry it. ①b before ② because a callback node names a
callback declaration and invokes a bound procedure. ② before ③ because `§16.2:900` — "explicit
pauses or event/decision callback invocations reachable while a span is active" — needs *both*
the span dataflow and the callback node kind, so it can land nowhere else. ③ before ④ because
nothing can retain a bytevector until spans deliver one.

**The oracle every slice runs under is the interpreter ≡ generated differential**, not a byte
comparison of emitted text. `§18:970` says the two implementations exist separately on purpose
and that the differential is what catches a divergence; `§18:972` permits the interpreter to
derive its own substep representation and forbids sharing one. Milestone 5 is the first
milestone where the two lanes must agree about *sequences of external effects* rather than
about a final value, and `§22.4:1268`'s callback-order comparison has never been exercised.

---

## 2. Why this shape

**Why Gate 0 comes first.** Every prior milestone opened this way and the reason is recorded in
Milestone 4's Gate 0 plan: a record's Consequences section is what removes work from the slice
that would otherwise re-derive it, so a slice starting without its record pays twice. Ten
design calls are collected in §4.1-§4.10. Four are externally observable — §4.3's encoding shape
and §4.4's state-id order through the IR fingerprint, §4.8's exec parameters and ABI member
through the emitted text, and §4.5's reachability relation through which diagnostic a fixture
emits — and an implementing slice that picks one by accident pins the wrong answer in a golden.

**Why the seam is its own slice, and why it contains no semantics.** Slice ①a moves every
committed artifact once, before any behaviour exists to argue about. Decision 0019 set this
precedent for Milestone 4 and it worked: it let every later slice assert "no golden moved" as a
*gate* rather than as a hope. The seam slice's own oracle is two-sided — the artifacts move
exactly once by a diff stated in advance, and `node?`'s disjunct list is still nine afterwards,
which is what proves the slice added no node kind.

**Rejected: adding the ABI member with the first callback arm.** One fewer re-baseline in
total, but the emitted text of every zero-callback machine still moves — just later, and mixed
into a commit that also changes behaviour, where a reviewer cannot tell an intended move from a
regression. `§9.5:444` forces a version bump either way.

**Rejected: one "callbacks and spans" slice.** A span *is* a pair of callback deliveries, so
the two look like one construct. They are not: `§16.2:900` restricts explicit pauses and
event/decision callbacks on paths where a span is active, which means the callback node's
semantics must be *settled* before the span pass can state what it forbids. Merging them puts
the restriction and the thing it restricts in the same commit, with nothing to check either
against.

**Rejected: spans before the callback node.** Constructively impossible, not merely awkward —
a span's data callback is a callback invocation, and `§16.2:900` has no meaning until callback
nodes exist.

**Why retention is its own slice rather than a task inside ③.** The criterion at `§25:1591`
is *vacuously true today*: the parser was a ten-slot vector when this was written — `tag
variant executor entry current offset lifecycle stored-error field-values field-decls`, measured
at the Gate 0 branch point — in which no slot could hold a bytevector, so a retention test
written then passed without the span path ever running. **Re-measured at Slice ③: sixteen slots,
three of which CAN hold one, and the conclusion still stands** — see §9's corrected paragraph,
which carries the derivation rather than repeating the count. That is the exact failure mode `AGENTS.md` calls a vacuous test, and the
only defence is a **negative control** — a deliberately retaining fixture the oracle must
*fail* on. A negative control is a designed artifact, not a bolt-on, and folding ④ into ③ is
where it gets bolted on. The owner may still choose to fold; the cost is stated here so the
choice is informed.

**Why the milestone does not open with the verifier.** Tempting, because `§16.2` gains eight
check families. But a verifier check with no construct to reject is unwitnessable, and Slice ⓪
just spent a whole slice establishing that an unwitnessed verifier clause is how two
pre-existing holes survived. Each check travels with the construct it constrains.

---

## 3. What the parent plan already settles

These are settled. A slice that re-derives one is doing work the plan already did, and a Gate 0
record that "decides" one is spending a record on a sentence already written. Four of these
were reported as open questions during this design's own research and are listed here
precisely so they are not reopened.

- **Callback arities**, all four kinds. Event and decision: `(callback parser user-context)`
  (`§13:781-785`). Span-data: `(callback parser user-context bytevector start end)`
  (`§13:787-791`). Span-complete: `(callback parser user-context)` — no range (`§13:793-797`).
- **The reserved control outcomes are enumerated**, in one sentence: `§9.3:421` — "The symbols
  `continue` and `pause` are reserved and may not be callback decision branch keys. Callbacks
  return the exported singleton objects rather than constructing lookalike symbols or vectors."
  `§16.2:902`'s check has fixed content; only its diagnostic *code* is unminted. **This was
  reported as an open design call and it is not one.**
- **Poisoned and reentrancy are their own condition codes**, not variants of lifecycle
  violation. `§9.4:438` lists them separately — "lifecycle violation, reentrancy, poisoned
  parser, callback binding error" are four entries in one enumeration — and `§12.2:698` and
  `:699` name them apart in the operation matrix. **Also reported as open, and also not.**
- **An event callback's pause uses its node's declared pause continuation.** `§10.6:586` —
  "Every invocation declares a continue target and a pause continuation" — and `§13:812` leaves
  an event callback no other pause target. **Reported as open by one reader and settled by
  another; it is settled.**
- **Outcomes are a closed four-category set** (`§13:803-808`), the successful ones must be
  allocation-free singletons (`§13:810`), and allocation on the failure path is explicitly
  permitted (`§13:810`). Both singletons are already shipped
  (`src/byte-machine/runtime.sls:35-36`).
- **Event and both span callback kinds may return only continue, pause, or failure**
  (`§13:812`). Only decision callbacks may return a branch key.
- **Field access from a callback is read-only** and the reason is stated: mutation "would
  bypass the closed IR and invalidate interpreter/generated equivalence" (`§13:801`). Any later
  proposal for a field setter must answer that sentence.
- **The no-retention guarantee's scope boundary is enumerated.** `§13:799` — the runtime stores
  nothing, and *three* application-owned carriers are outside the guarantee: "callback
  closures, user context, and callback error detail."
- **`§16.2:890`'s "incompatible" and `§16.2:892`'s "invalid" are derivable, not undefined.**
  `§10.3:502` gives four callback kinds; `§10.6:586` says a callback node invokes "one named
  event or decision callback" (so a node naming a span-data declaration is *incompatible*);
  `§10.4:515-516` says a span declares a span-data callback and an optional span-complete
  callback (so a span naming an event declaration is an *invalid span callback declaration*).
  The design states the derivation rather than minting a definition.
- **The mark re-anchors at every feed boundary, unconditionally.** `§14:833`'s third clause —
  "and begins its next possible fragment at the next feed's `start`" — is not governed by the
  "if nonempty" that governs the emission. This is load-bearing for §4.6's EOF derivation.

**Where the parent stops settling.** It does not say which reachability relation "reachable
path" means (`§13:826`, `§10.4:519`, `§14:843`) — the plan's own dispositions record that gap
at `§Dated:1944-1947` and instruct that it not be read as closed. It does not say what a
callback-contract error *is*. It does not say what occupies an optional callback's slot. It
does not say how the active span name is observable. Those are §4's.

### 3.1 The per-kind defect surface, measured

Three Milestone 4 Slice ③ defects were one shape: a new node kind reached the shared accessors
and missed a hand-written per-kind filter. Milestone 5 adds three kinds at once. **Measured at
`db86ab6`** (`rg -n -- '-node\?' src/byte-machine/verify.sls`, excluding comment-only lines,
grouped by enclosing construct): `verify.sls` contains **thirteen** node-kind branch-selection
constructs, at `:97` (`zero-width-edges`), `:124` (`node-out-edges`), `:161` (`node-eof-target`),
`:232` (pass-names error-reference filter), `:381` (`pass-field-operands`), `:434`
(`pass-overlap`), `:495` (`pass-sequence-ambiguity`), `:510` (`reexec-targets`), `:626`
(zero-progress report set), `:761` (`classify`), `:848` (the `:908` zero-hop entry clause),
`:859` (the `:908` per-edge target), `:908` (the `:909` parked-set gate).

The full cross-library census is the appendix, which states the **recogniser** it was built
with so that its completeness can be re-derived rather than trusted. Every site gets a row and
every row states *either* the new arm *or* that the site is deliberately not extended, with the
reason — Milestone 4's Slice ② used exactly this checklist shape and it is the only thing that
has ever caught this defect class before it shipped.

**The two ratchets Slice ⓪ built fire automatically here, and that is what it was for.**
`test/common/kind-position-census-tests.sps:326` compares `node?`'s disjunct list against the
matrix's own key set ("the same nine kinds"), deriving the former from `ir.sls` at run time —
so the moment a tenth kind reaches `ir.sls`, that assertion goes red and stays red until a
matrix row exists with sixteen position cells and verdicts derived from `§16.2`.
`test/common/diagnostic-census-tests.sps` does the same for each new diagnostic code and each
new emission site. **Measured now: sixteen distinct diagnostic codes over twenty-eight emission
sites.** (A count of 31 was reported during research; 31 is the pre-Slice-⓪b number, and the
census's own comment at `diagnostic-census-tests.sps:123-139` records the intervening moves
31→29→30→28. Re-measuring after a fix wave is `AGENTS.md:557-566`.)

### 3.2 Where the spec and the tree already disagree

Four divergences exist **today**, before Milestone 5 changes anything. Each is inherited by a
slice that would otherwise plan only additions. They are recorded here so that no slice
discovers one mid-task and reports it as its own regression.

1. **`parser-reset!` has no lifecycle guard at all.** `§12.2:699`'s `busy` row requires all four
   operations to raise the reentrancy condition, and `busy` is the only row where `reset!` is
   not permitted. Measured: `parser-reset!` (`src/byte-machine/runtime.sls:545-550`) is five
   unconditional mutations with no lifecycle read of any kind. A callback calling
   `parser-reset!` on its own parser succeeds silently today. **Adding `busy` is a behaviour
   change to shipped code, not only an addition.** Slice ②.
2. **`parser-resume!`'s else arm will give the wrong code.** It answers every non-paused state
   with `'lifecycle-violation` (`runtime.sls:501-506`); once `poisoned` exists, `§12.2:698`
   requires `parser-poisoned` there. Slice ②.
3. **A `paused-finish` result populates fields `§12.3:711` calls inapplicable.** The spec: "a
   `paused-finish` result has no input slice, so `next` and `consumed` are inapplicable and only
   the absolute stream offset is exposed", and `§9.3:425` requires accessors to enforce where
   fields are meaningful. Measured: the EOF pause arm builds `(make-parser-result 'paused off 0
   off #f)` (`runtime.sls:467`) and `parser-result-next` is an unguarded `(vector-ref r 2)`
   (`runtime.sls:140`). `§12.4:729` permits EOF processing to invoke callbacks and pause, so
   Milestone 5 turns one shipped paused-finish path into many. **Disposition it deliberately;
   do not inherit it.** Slice ②.
4. **`pass-zero-progress` applies no reachability gate**, though `§16.2:898` says "reachable
   zero-progress cycles". Measured: its report loop (`verify.sls:618-634`) maps over
   `(machine-nodes m)` with no `reached` term anywhere in the pass. Benign today — such a
   machine is rejected by `unreachable-node` regardless — but it is the same question §4.5
   settles, in a pass Slice ③ must extend with three zero-width kinds. Resolve it with §4.5.

**And one hazard that is not a divergence but will mislead a slice.** Two comments in
`verify.sls` (`:402` and `:468`) justify their design by citing `§16.4:937-943` for a
"one finding per decision" rule. The parent plan's own dispositions record, verbatim at
`§Dated:1904-1907`, that **this rule does not exist**: "A rule cited fourteen times in this
repository does not exist... which is a contents list with no cardinality clause". The two
comments' *designs* are fine; their stated *reasons* are false. **No Milestone 5 check may be
narrowed or deferred on double-reporting grounds** without first checking `§16.4:933-947`
itself.

---

## 4. Gate 0 — design-call resolutions

Decision-only: no product code, no tests, no CMake. **The next free decision number is 0024**
(measured: `docs/decisions/` holds 0001-0023, contiguous, plus `README.md`). Writing-plans
should confirm the split below — several of these merge naturally and a record per call is not
the goal.

§4.1-§4.10 are destined for records. §4.11 collects resolutions that stay in this design with
no record. §4.12 collects scope additions the parent plan does not name.

> **Gate 0 discharged 2026-09-04**, as six records, exactly the merges §11 named.
>
> | Record | Carries | Merge |
> | --- | --- | --- |
> | [0024](../decisions/0024-callback-error-vocabulary.md) | §4.1, §4.2 | the callback-error vocabulary as one |
> | [0025](../decisions/0025-milestone-5-seam-encoding-abi-exec.md) | §4.3, §4.8 | the seam as one bargain, decision 0019's shape |
> | [0026](../decisions/0026-internal-state-id-order.md) | §4.4 | — |
> | [0027](../decisions/0027-reachable-path-for-callbacks-and-spans.md) | §4.5 | absorbs the `pass-zero-progress` gate |
> | [0028](../decisions/0028-callback-slots-and-visible-state.md) | §4.6, §4.9, §4.10 | the callback's runtime surface |
> | [0029](../decisions/0029-span-state-is-a-lattice.md) | §4.7 | — |
>
> **The gate did not just transcribe this section — it corrected it.** §4.1's and §4.7's
> arguments were both refuted while the records were being written, and both are amended above.
> §4.4's contradiction with decision 0016 was found earlier, while the Gate 0 plan was written.
> **Three of ten resolutions reached a record with a different stated reason than this document
> first gave them**, every conclusion intact. A design section is a draft argument until
> something checks it against the artifacts.
>
> Two records reach back: `0025` annotates decision 0019, and `0027` annotates decision 0023.
> One appended disposition adds `parser-active-span` to `§9.3`'s normative list — appended to
> the parent plan's `## Dated dispositions`, measured as 37 insertions and zero deletions, so no
> `§section:line` citation moved.

### 4.1 The callback-contract error: a `callback`-domain parser error, not a raise and not poison

**The call.** `§10.6:586` says "Unknown results are runtime callback-contract errors" and that
is the only sentence in the plan that names such an error. It assigns no domain, no code, and
no channel. (`rg -n 'callback-contract|Unknown results'` returns exactly that one hit.)

**Resolved: a stored parser error in a new `callback` domain, with a minted stable code,
reported through the ordinary error result path. It does not poison.**

Three constraints force it. `§12.7:775` puts data errors in results rather than conditions, and
a callback returning the wrong kind of value is a data error about the machine's environment,
not a misuse of the API by the caller. `§12.3:719` — "The machine entered a declared machine error or
**callback application error**. The status is sticky until reset." — already puts this family on
the sticky error *result* channel by name. **That positive citation is the argument.** An
earlier draft argued instead that `§9.4:438`'s code list contains no callback-contract entry, so
the channel "was not left open"; that does not follow, because `:438` opens with the words
"Codes include" — an open enumeration, from which nothing can be ruled out by absence. The
absence is corroboration and the record labels it as such.
`§12.6:749`'s poisoning triggers are a closed pair — "If a callback raises an unexpected
condition or performs a nonlocal escape" — and a wrong *return value* is neither; extending
poisoning to cover it would widen a closed enumeration by inference.

`§10.5:530` already contemplates the domain: "Callback application failures occupy a separate
runtime error domain and do not need source-IR declarations."

**Consequence.** An explicit `make-callback-failure` outcome and an out-of-contract return
land in the *same* domain with *different* codes. The five values `§12.7:777` compares across
lanes — source-node name, domain, code, offset, position kind — must be identical for both, so
each is a differential fixture and not merely a unit test.

### 4.2 The reason of a callback-domain error is a fixed constant string

**The call.** `§9.3:400`'s `(parser-error-reason error)` is a required accessor that must
answer something. A callback failure supplies "an application code and optional detail"
(`§13:808`) and no reason, and `§10.5:530` says callback failures need no source-IR
declaration, so there is no `errs`-table entry to draw a static reason from.

**Resolved: one fixed printable-ASCII constant, identical in both lanes, for every
callback-domain error.**

`§12.7:757` calls reason *static*, which rules out `#f`. Rendering the code's printed form
would put a symbol's external representation into a behavioural contract. The cross-lane cost
is zero either way — `§12.7:777` does not compare reason — so this is a public-API
answerability decision, and the cheapest answerable thing that stays static wins.

Pairs naturally with §4.1 in one record.

### 4.3 Slot tables encode as an optional trailing section, absent when empty

**The call.** `§17:962` requires callback and span slot *assignment* in the normalized IR. No
sentence anywhere says which normalization outputs the canonical *encoding* must cover. The
field table's presence in the encoding was fixed by decision 0019, not by the plan.

**Resolved: the callback and span slot tables are encoded, as a trailing section present only
when nonempty. The header does not grow. A machine that declares neither encodes
byte-identically to today.**

Measured header (`src/byte-machine/private/normal-ir.sls:465-467`):
`[version u8][entry u32be][state-count u32be][field-count u16be]`. **Decision 0019
pre-provisioned three slots and only one of them was ever in this header** — item 3(a)'s `u16be`
field count. Item 3(b) is the ABI payload's field-initials member and 3(c) is emitted `exec`'s
seventh parameter, neither of which is in the encoding at all. All three are spent. Growing it moves all four committed
goldens under `test/fixtures/` and the fingerprint literal pinned at
`test/common/normal-ir-tests.sps:96-99` for machines that have no callbacks and no spans —
paying a re-baseline for machines the feature does not touch. Decision 0019 struck exactly this
bargain once; restating it is consistent, not novel.

**Not encoding the tables at all is rejected on precedent, and the precedent is narrower than
it first looks.** `test/common/normal-ir-tests.sps:173` asserts that two machines differing only
in a *field name* differ in fingerprint — it is about fields, not about callbacks, so it does
not by itself forbid leaving callback slots out. What it establishes is that in this system
declaration identity is fingerprint-visible, and a design in which two machines differing only
in their callback bindings share a fingerprint would break that consistency for the one
declaration family whose identity reaches *outside* the machine. That is an argument from
precedent, not a proof, and it is stated as one.

### 4.4 Internal state ids interleave by declaring-node order

**The call.** `§17:955` says internal states "append after" declared nodes, citing decision
0016 — whose item 1 pins a total order for exactly one family (prefix states: declaring-node
order, then prefix-structure pre-order, children ascending by byte). No clause covers a second
family or its interleaving with the first. `§20:1036` requires determinism without saying what
the order is.

**Resolved: decision 0016's two-phase append is unchanged, and the second phase gains one
merged pre-order. All declared nodes keep their declaration indices; every internal state — of
either family — is assigned an id after the entire declared block; and within that block a
declaring node contributes all of its internal states, prefix states and span continuations
alike, at its own position in declaring-node order.**

**Read 0016 item 1 before implementing this, because a shorter statement of it is wrong.** Its
text is "Internal prefix states are assigned ids after the entire declared block, ordered by
(declaring-node order, then prefix-structure pre-order, taking each prefix state's children in
ascending byte order)". So the merged pre-order operates *inside* the second phase; it does not
interleave internal states with declared ones, and an earlier draft of this document was
ambiguous enough to be read that way.

This extends 0016's own ordering principle rather than adding a precedence rule beside it. The
alternative — the two families in sequence within phase two, all prefix states then all span
continuations — requires an arbitrary choice about which family comes first and leaves the
third family, whenever it arrives, asking the same question again. The order is externally
observable through the IR fingerprint and the order of emitted `case` arms — decision 0016's
Context is what makes that observable — so it must be pinned by a record.

**Also settled here:** a span end lowers to **one internal state per resumable substep**, not a
fused state. `§17:966` forbids speculative fusion, and `§14:838` — rule 9, the span-end pause
rule, not rule 8's boundary-flush pause — requires resume "at the next undelivered substep",
which is only expressible if each substep has one.

### 4.5 "Reachable path" means byte-reachability plus the EOF walk

**The call.** `§13:826`, `§10.4:519` and `§14:843` each say "reachable path" and none defines
it. **The plan itself records the gap**, at `§Dated:1944-1947`: "Left open deliberately, and
not to be read as closed: `pass-reachability` walks `all-out-targets`, so a node reachable only
through an untakeable EOF edge counts as reached... it is its own `§16.2` question and now has
no accidental answer."

**Resolved: the span and callback restrictions use byte-reachability plus the EOF walk — the
pair the shipped `:908`/`:909` checks use — not `pass-reachability`'s `all-out-targets`.**

Decision 0023 settled the same question for the EOF checks one slice ago and its reasoning
transfers verbatim: a graph node no execution can occupy is not a state that originates a
traversal. Two different reachability relations in one verifier is a defensible design; two
different relations chosen for *no stated reason* is how `§16.2:898`'s missing gate came about.

**This record also disposes of §3.2's fourth divergence.** `pass-zero-progress` must gain the
gate `§16.2:898` already requires, or the design must record why it does not. Slice ③ owns the
edit; the record owns the reason.

### 4.6 Optional callbacks are a slot sentinel, short-circuited at the invocation site

**The call.** `§9.3:419` says `make-parser` "installs no-op/default behavior only where
declared" and fixes what a default *returns* — an optional decision callback must declare
`default-branch`, other optional callbacks default to `continue` — but not what occupies the
indexed slot.

**Resolved: a sentinel occupies the slot and the invocation site short-circuits it. An unbound
optional callback produces no entry in the callback-order sequence.**

The alternative — an installed closure returning the singleton — is uniform but allocates a
closure per unbound optional callback at construction, and buys nothing observable in return.
**No witness distinguishes the two designs**, and this document says so rather than claiming
one: an unbound optional callback has, by construction, no application closure to record with,
so neither shape puts an entry in a `§22.4:1268` sequence the application can see. The
resolution is taken on cost, not on observability. It still binds **both lanes** — a divergence
here would be invisible to the differential, which is the reason to write it down rather than
the reason to prefer it.

### 4.7 The span lattice must meet at merge points

**The call.** `§16.2:899` enumerates five span rejections; `§14:843` names four path
properties; `§10.4:519` names four rejections. Three vocabularies, no mapping, and the word
"inconsistent" appears only in `§16.2:899`.

**Resolved: the span pass is a dataflow analysis over an abstract span state, and disagreement
at any merge point — not only at an exit — is itself a diagnostic.**

**Two arguments, and they reach different halves of this resolution.** An earlier draft ran them
together and called the second decisive for both; it is not, and Gate 0's own review is what
separated them.

*The shape* is forced by the graph. **`§16.2:913` declares normal consuming cycles valid —
"including the main HTTP message loop" — so a check by path enumeration does not terminate.**
A fixpoint over a finite abstract domain does. That settles *analysis rather than enumeration*,
and nothing more.

*The merge-point rule* rests on interpretation alone, and this document says so rather than
borrowing the graph argument's force. Under the path-existential reading, "inconsistent
successful exits" means only that some path reaches a successful exit with a span active —
exactly `§14:843`'s fourth property — leaving one of `§16.2:899`'s five bullets a restatement of
another document's sentence. A reading that makes a normative bullet redundant is the weaker
reading. **That is the whole case for reporting at merge points, and it is weaker than the case
for the shape.** A reviewer who disagrees is disagreeing with something the plan genuinely
underdetermines, which is what a Gate 0 record is for.

### 4.8 The seam reserves the exec parameters and the ABI member, empty

**The call.** Whether Slice ①a reserves the emitted `exec`'s new parameters and an empty ABI
payload member ahead of any semantics, or whether they arrive with the first callback arm.

**Resolved: reserve in the seam slice. `exec` gains its parameters unused, the payload gains an
empty member, `current-abi-version` goes 3→4 once, and the goldens re-baseline exactly once
before any behaviour exists.** Decision 0019 item 3(c)'s precedent.

Measured: the emitted signature is
`(define (exec state offset bv start end finish? fieldv)` (`src/byte-machine/compile.sls:532`)
— no parser handle and no callback table, while `§13:784` makes the parser a callback's first
argument, so `exec` must receive one. `current-abi-version` is 3 (`runtime.sls:61`).

**A correction to a claim made during this design's own research, recorded because the false
version of it would have sent Slice ①a writing a test for a hole that does not exist.** It was
reported that "`runtime.sls:84-88`'s `>= 1` check will not enforce the bump, so the slice owes
a test that it did." That conflates two different checks. The **version** check
(`runtime.sls:79`) is `(= abi-version current-abi-version)` — strict equality, which *does*
enforce the bump. The `>= 1` at `runtime.sls:84` is a **minimum length** check on the metadata
vector, which is what lets the payload grow at all. The constructor's own comment
(`runtime.sls:63-71`) states the coupling: the payload is one quoted vector rather than a
rest-arg precisely so that "the vector keeps growth and the check coupled." Slice ①a still owes
a test that a version-3 generated file is refused by a version-4 runtime — that path is real —
but it owes it as *coverage of a working guard*, not as the closing of a hole.

### 4.9 Every read accessor answers while lifecycle is `busy`

**The call.** `§13:821` says lifecycle at callback entry is `busy`, "so parser operations are
rejected". `§12.2`'s operation matrix has exactly four columns — `feed!`, `finish!`, `resume!`,
`reset!` — and no accessor column, so its `busy` row settles nothing about the five read
accessors. (`rg -n 'accessor' docs/plans/byte-machine-implementation-plan.md` finds no sentence
tying an accessor to a lifecycle state; `§12.1:679` defines `busy` only as "an internal guard
while feed, finish, or a callback is executing".)

**Resolved: "parser operations" means the four mutating operations. All five read accessors —
`parser-lifecycle`, `parser-state-name`, `parser-stream-offset`, `parser-field-ref`,
`parser-user-context` — answer normally during `busy`.**

This is forced, not preferred. `§13:816-826`'s entire list of committed state is addressed *to
a callback*, and `§13:818` requires that fields "are read-only through public accessors" at
callback entry. An accessor that raises during `busy` makes that sentence unsatisfiable, and
`§25:1580`'s "callback-visible committed state" unobservable.

### 4.10 The active span is observable through a sixth parser accessor

**The call.** `§13:820` requires that an automatic feed-boundary fragment "reports the current
source input node together with the active span name". Measured: `§9.3:382-425`'s normative
list has exactly five parser accessors and none of them names a span. `§10.2:495` puts span
markers in parser bookkeeping and explicitly outside machine fields, so `parser-field-ref`
cannot answer.

**Resolved: add `parser-active-span`, returning the active span's name or `#f`. `§9.3` is a
normative list, so this is a plan change and lands as an appended disposition, not a silent
addition.**

Making `parser-state-name` return a compound value in the feed-boundary case was rejected: it
makes every existing caller's contract conditional on a case the caller cannot detect. Treating
`§13:820` as a debug surface with no public witness was rejected for a sharper reason —
`§13:822` and `§13:823` (the data callback sees its span active; the completion callback sees
it inactive) would then have no observable form either, and `§22.4:1267`'s "final state"
comparison could not see them. That would leave Milestone 5's newest and least-tested
construct with its cross-lane oracle deliberately blinded.

### 4.11 Resolutions that stay in this design and get no record

- **An event callback's branch map must be empty, and the verifier is what rejects a non-empty
  one.** `§10.3:504` gives branch keys only to decision callbacks, so every key in an event
  callback's map is undeclared and `§16.2:901`'s existing "undeclared" clause already covers
  it. A constructor-side rejection is *excluded*: `§9.1:307-308`'s signature gives the constructor
  the callback *name* only and `§9.1:322` limits constructors to local shape, so "is this an
  event callback" is a cross-reference — which decision 0020 item 1 assigns to the verifier.
- **EOF never delivers a span-data fragment; an EOF span-end delivers only the completion
  callback.** Derived, not chosen, and the derivation is short enough to check: `§14:833`'s
  re-anchor clause is unconditional (§3's last bullet), so at every feed return with an open
  span the mark moves to the next feed's `start`; `parser-finish!` admits no new bytes
  (`§12.4:729`); therefore at a span end reached during EOF, `mark == cursor`, and `§14:833`
  suppresses an empty fragment. **A reviewer should check this derivation rather than take
  it** — if it is wrong, `§25:1589`'s EOF fragment leg asserts the wrong thing.
- **`§14`'s rule 6 quantifies over successful paths only.** Rule 6 (`§14:834`) promises "exactly
  one completion event"; rule 10 (`§14:839`), four lines later, says errors synthesize none.
  Both are verbatim. A fragment oracle written against rule 6's literal text will assert a
  completion event that rule 10 forbids, and `§25:1589` requires the error case. The design
  states the reading; it does not amend the plan.
- **The cursor half of `§13:819` is witnessed, contrary to the obvious reading.** The stream
  offset has an accessor (`§9.3:409`) and the cursor has none — but at a feed-boundary flush the
  span-data callback's own `end` argument *is* the cursor (`§14:833`'s `[mark,end)`), and after
  any callback the result's `next` is the cursor (`§11.5:660`). A slice must not record this as
  unobservable and skip it.
- **`§16.2:911` ("backend limits that would make emission incorrect") has no owner in any
  milestone.** Searched `§25:1611-1666` and `rg -n 'backend limit'`: the bullet cites nothing
  and nothing claims it. Not Milestone 5's work. Recorded here as an orphan so it stops looking
  covered.

### 4.12 Scope additions — settled by the owner 2026-09-04

**Items 1, 2 and 3 are approved and in scope. Item 4 is declined** and moves to §10. Each was a
demonstrated gap in code Milestone 5 already edits, stated with what was measured, so the
approval was of a fact rather than a feeling.

1. **APPROVED 2026-09-04. `make-machine` has no `for-all` guard for the callback or span
   collections.** Measured:
   the fields collection is guarded (`ir.sls:559-560`) and the collection loop at `ir.sls:548-551`
   is where the others would go. Adding `make-callback-declaration` and `make-span-declaration`
   without the matching guards reopens, for two collections Milestone 5 is about to make
   load-bearing, exactly the hole `ir.sls`'s own comment records closing for fields. **Cost:
   small, and it is in a file Slice ①b edits anyway.**
2. **APPROVED 2026-09-04, scoped to Milestone 5's two new declaration families. `§16.2:886`'s
   "labels" clause has never been implemented, for any of the nine shipped kinds.** Measured: `rg -n 'source-label|label' src/byte-machine/verify.sls` returns two hits,
   both comments about `§16.4:940`'s diagnostic edge label; nothing in the tree checks any
   declaration's label against any grammar. `§10.3:506` and `§10.4:517` give callbacks and spans
   an optional diagnostic label, and `§10.1:480` puts labels under a *different* grammar from
   names — "printable ASCII plus LF", against `[a-z][a-z0-9-]*` for names, codes and branch
   keys. So Milestone 5 adds two label-bearing families to a check that does not exist. **The
   proposal is the check for M5's two families only**; retrofitting the other nine is a separate
   question and is not proposed here.

   **DISCHARGED 2026-09-06 by Slice ④, the close-out — and it had been dropped.** No slice plan
   picked this item up, so it was in no exit criterion and on no deferral list, and it was found
   only by the whole-branch review asking what the milestone had approved that the tree did not
   contain. It ships as a second call site of `valid-reason?` folded into each family's existing
   name-clause `and`: no new diagnostic code, and a census that does not move. See the parent
   plan's Milestone 5 close note, "One approved scope item nearly did not ship".
3. **APPROVED 2026-09-04, for Slice ④. `§27:1694`'s "callback/span lifetime reference" has no
   owner.** `§28:1725` lists explicit
   consumer documentation as one of four mitigations for the retention risk. The other three —
   the dynamic-extent contract, no bytevector field in parser storage, retention tests — are
   squarely Milestone 5's. This is the only one that can silently ship as nothing, because
   `§25:1591` does not name it. **Proposed for Slice ④.**

4. **DECLINED 2026-09-04 — moved to §10.** The `graph.sls` export convention, stated for the
   first time and applied forward only. Measured against the full file: Milestone 3's sequence-dispatch exports its
   predicate, four accessors, `sequence-case?` and two case accessors; **Milestone 4's three
   node kinds export constructors only** (`graph.sls:22-23`) — no `field-action-node?`, no
   `field-branch-node?`, no `integer-accumulate-node?`. **The header does not contradict this**,
   and an earlier draft of this document said it did. `graph.sls:12-15` records that Milestone 4
   added `make-uint-field` "with its predicate and one accessor per §10.2:488-491 part" — a
   *declaration* family, and `uint-field?` with four accessors is indeed exported (`:17-18`) —
   and then draws the line: "Machine ACCESSORS stay private: §9.1 fixes a construction surface,
   and reading a built machine back is not part of it." Node-kind predicates fall on the private
   side of that line, and Milestone 4 followed it. What is genuinely unstated is why
   sequence-dispatch is the exception. **Proposed: Milestone 5's two declaration families export
   predicates and accessors on the `uint-field` precedent, its three node kinds export
   constructors only on the Milestone 4 precedent, and the header gains one sentence naming
   sequence-dispatch as the outlier it is.** Retrofitting Milestone 4's three kinds is *not* proposed —
   that is a change to shipped surface with no Milestone 5 consumer.

---

## 5. Slice ①a — The seam: ABI, encoding, exec signature, and the position axis

**Scope, as an allocation.** This slice discharges **no `§25` scope bullet and no exit
criterion.** It exists to move every committed artifact once, before any behaviour exists, so
that each later slice can assert "no golden moved" as a gate. Its work is Gate 0's §4.3
(encoding shape) and §4.8 (exec signature and ABI member) made real, plus one task Gate 0 does
not settle: the position-axis drift row below. **No semantics** — that is the boundary, and
"nothing else" would have been wrong, since the drift row is neither §4.3's nor §4.8's.

**Citation staleness policy, declared before any `file:line` appears.** Every citation in this
section was measured pre-slice at `db86ab6`. Each names the *construct* as well as the line.
No tool in this repository catches a citation that goes stale because this slice's own edit
moved the line — that class is caught by review or not at all.

**The work.**

- Grow the ABI payload with an empty callback/span member; bump `current-abi-version` 3→4
  (`src/byte-machine/runtime.sls:61`). Register the new emitted identifiers in
  `reserved-member-3` (`src/byte-machine/compile.sls:68-70`).
- Widen the emitted `exec` parameter list (`src/byte-machine/compile.sls:532`) with the parser
  handle and the callback slot vector, both reserved and unused.
- Land §4.3's encoding shape in `src/byte-machine/private/normal-ir.sls` (header at `:465-467`).
- **Add a position-axis drift row to `test/common/kind-position-census-tests.sps`.** Measured:
  `position-table` (`:93`) is hand-written data that nothing checks, while the kind axis beside
  it derives its set from `ir.sls` at run time and three consumers pin literals against it. A
  milestone adding three node kinds with new edge positions is the moment that asymmetry costs
  something. **Corrected 2026-09-04, while measuring for the Slice ①a plan: this cannot derive
  from the IR.** `ir.sls` has no position vocabulary at all — the only enumeration with the right
  cardinality is in `verify.sls`, the file the census exists to test. So the row derives from
  `verify.sls` and is **structurally weaker than the kind row**, which derives from `ir.sls` and
  tests `verify.sls` — two independent files. It catches a hand-edit that adds a position to the
  verifier without adding a matrix cell, which is what nothing checks today; it does *not* catch
  a mutation, because the census reads the staged tree
  (`SchemeMutationSuite.cmake:1157`). **Corrected by Slice ①a's final review: that does not make
  it blind** — the derived set is compared against a mapping declared in the test, so a mutation
  to `verify.sls` reddens it. The row's own comment states what it can and cannot certify.

**Oracle — two-sided, and both sides are commands with falsifiable results.**

*Forward:* the four committed goldens under `test/fixtures/` move **exactly once**, by a diff
this slice states in advance and a reviewer can diff against. **They are emitted *text*, so
§4.3's "encodes byte-identically to today" does not spare them** — an earlier draft of this
document claimed an empty `git diff -- test/fixtures/` was the assertion, and that was wrong.
Measured: every golden carries the `exec` signature at `:5` and the constructor call as its last
line (`generated-one-byte.golden.sls:21`, `generated-pause.golden.sls:34`,
`generated-accumulate.golden.sls:36`, `generated-http-version.golden.sls:86`), and this slice's
work list moves both — the parameter list widens, the literal `3` becomes `4`, and the metadata
vector gains its second member. **Two lines per file, four files, and nothing else.**

What §4.3 buys is the other half of the gate, and it is the sharper half: **every fingerprint is
unchanged.** The four goldens each carry one (`14095574568398596535` and its three siblings) and
`test/common/normal-ir-tests.sps:96-99` pins the same value as a literal. A fingerprint that
moves in this slice means the encoding changed when §4.3 said it would not — that is the
assertion, and unlike an empty diff it can actually fail.

*Backward:* every existing suite green with zero semantic re-baseline. **The two drift guards
are not the same shape, and the difference bites in the next slice.** `member3-drift` is the
subset assertion (`test/common/member3-drift-tests.sps:127`, `extra` must be `'()`), so an
unregistered emitted local reddens rather than colliding silently — that is the one this slice's
new `reserved-member-3` entries answer to. `reserved-drift` is **set equality**
(`test/common/reserved-drift-tests.sps:37-40`, "the declared set equals the live runtime export
set") between `reserved-member-2` and `(byte-machine runtime)`'s live exports, so it reddens in
*both* directions: Slice ①b adds six runtime exports (§6) and each one must join
`reserved-member-2` in the same commit or that lane goes red. This slice adds none, so it stays
green here — the note is for §6, which would otherwise meet a red test it was told was a subset
assertion. And — the one that proves this slice's own boundary — **`node?`'s disjunct list is
still nine**, so
`kind-position-census-tests.sps:326` stays green. A seam slice that accidentally added a node
kind would fail that assertion, which is what makes "no semantics" checkable rather than
asserted.

*Coverage of the version guard:* a version-3 generated file must be refused by a version-4
runtime. Note §4.8's correction — this tests a guard that works, and its value is that the
guard keeps working, not that a hole is being closed.

---

## 6. Slice ①b — Callback and span declarations, binding resolution, and five missing exports

**Scope, as an allocation.** Discharges `§25:1576` ("callback declarations and indexed
binding") **whole**. It adds **no node kind** — that boundary is the slice's own oracle.
Declaration-side shares of `§16.2:885`, `:886`'s *name* clause, `:890`, `:891`, `:892` and
`:901` land here; the node-side share of `:901` is Slice ②'s, and every span-topology check is
Slice ③'s.

**The work.**

- `make-callback-declaration` (`§9.1:284-285`) and `make-span-declaration` (`§9.1:286`), with
  the `for-all` guards `make-machine` currently lacks for both collections (§4.12 item 1,
  **approved 2026-09-04** — the collection loop is `ir.sls:548-551` and checks only `list?`;
  the per-element guards are separate `unless (for-all P coll)` forms at `:552-560`, so this is
  a fourth and fifth such form, not an edit to the loop). Measured: `machine-callbacks` and
  `machine-spans` already exist as constructor parameters, vector slots and exported accessors,
  and **nothing anywhere reads either** — ①b is their first reader, and the guard is what makes
  them load-bearing.
- **(Removed 2026-09-04 — stale by one settlement.)** This bullet said "the `graph.sls` export
  convention of §4.12 item 4, pending approval". Item 4 was **declined** and moved to §10, so
  stating a convention is out of scope. What survives is the *precedent*: ①b's two declaration
  families export a predicate and accessors on the `uint-field` pattern, and the header gains
  nothing. **Note there are two precedents, not one** — `make-error-declaration` is exported
  constructor-only, and it also stores a `source-label` it has no accessor for. The owner's
  decline text names `uint-field`, so ①b follows that one knowingly.
- Verification pass 6a's callback half: `§16.2:890` ("missing or incompatible callbacks"),
  `:891` (optional decision callbacks without a valid declared default branch), `:892`
  ("invalid span callback declarations"), `:901`'s declaration share, and `:902` — whose content
  `§9.3:421` already fixes, so only its code is minted. "Incompatible" and "invalid" are the
  derivations recorded in §3, not new definitions.
- **`§16.2:885` and `§16.2:886`'s name clause acquire two new subjects, and neither is a new
  check.** Measured: `pass-names` (`verify.sls:203-236`) scans node names and error declaration
  names and reads no other declaration collection, so callback and span names are outside every
  duplicate-name and grammar check the tree performs today. `§9.1:284-286` gives both families a
  `name`, and `§10.1:480` puts declaration names under `[a-z][a-z0-9-]*`. Extending an existing
  pass to two new collections is cheaper than a new pass and is the whole of the work — but it
  is work no scope bullet names, which is why it is written down here.
- `make-parser`'s `§9.3:419` binding resolution, with the `reentrancy`, `poisoned parser` and
  `callback binding error` codes of `§9.4:438`.
- **The five `§9.3` exports that do not exist anywhere in `src/`.** Measured at `db86ab6`, each
  by `rg -c` over `src/byte-machine/*.sls` and `src/byte-machine/private/*.sls`, each returning
  **zero**: `parser-state-name`, `parser-stream-offset`, `parser-user-context`,
  `make-callback-failure`, `callback-failure?`. Plus `parser-active-span` from §4.10.

**Oracle.** A machine that **declares** callbacks and spans but contains no callback or span
*node* must verify, normalize, emit and run identically in both lanes, with the differential's
existing value tuple unchanged. That is what proves declarations are separable from nodes, and
it is a property no later slice can establish retroactively.

Every `§9.3:419` rejection — duplicate binding, unknown name, missing required callback,
optional decision callback with no `default-branch` — is driven by a positive test asserting
its `§9.4` code. The two defaulting rules are witnessed by observed behaviour, never by reading
the resolver.

The diagnostic census (`test/common/diagnostic-census-tests.sps`) goes **red** on each new code
and each new emission site, and is re-baselined in the commit that moved it — never in a
separate tidying commit, because a census re-baselined apart from its cause is a census nobody
checked.

---

## 7. Slice ② — The callback-invocation node, outcomes, `busy`, and poisoning

**Scope, as an allocation.** Discharges `§25:1577` (event and decision callbacks), `:1578`
(continue/pause/branch/failure outcomes), `:1579` (unexpected escape poisoning) and `:1580`
(busy/reentrancy guards and callback-visible committed state), and exit criterion `§25:1588`
(callback order and exact-once delivery). Spans are Slice ③'s entirely.

**The work, and it is the widest per-kind reach in the milestone.**

- `make-callback-node` (`§9.1:307-308`) and its node-reference positions.
- **The two lifecycle rows of `§12.2:698-699`, including two changes to shipped behaviour**
  that §3.2 records. The tree already anticipates them: `runtime.sls:185-186`'s comment
  enumerates the seven shipped lifecycle values and adds "poisoned/busy are M5 rows".
  The changes are: `parser-reset!` gains the lifecycle guard it has never had, and
  `parser-resume!`'s else arm stops answering `'lifecycle-violation` where `§12.2:698` requires
  `parser-poisoned`.
- **`§12.6:747`'s ordering clause, which is a separate obligation from poisoning and is easy to
  read past.** "Prohibited lifecycle operations and reentrant parser operations raise
  API-contract conditions **before further mutation**." That is testable and must be tested: a
  refused operation leaves lifecycle, offset, fields and stored error byte-for-byte unchanged.
- `dynamic-wind` poisoning (`§12.6:749`; `§7.1:160` names the mechanism as available).
- §4.1/§4.2's callback-contract error, and `§16.2:901`'s node half.
- **Every per-kind site, worked from the appendix census as a checklist with a row per site.**
  **The appendix is the authority and this bullet deliberately does not restate it** — a partial
  copy of that list is how a site goes missing, and an earlier draft of this document carried one
  that was short by six rows. Re-run the appendix's stated recogniser at plan-writing time and
  reconcile against the table; a row the recogniser finds and the table lacks is the finding.
  Each row states the new arm **or** that the site is deliberately not extended, with the
  reason.
- **Disposition `§12.3:711`'s paused-finish divergence** (§3.2 item 3) rather than inherit it:
  `§12.4:729` lets EOF processing invoke callbacks and pause, so this slice turns one shipped
  paused-finish path into many. **Measured while planning ②: it has no authority** — neither §4
  nor any of `0024`-`0029` resolves it — **and the tree pins the current behaviour twice**
  (`runtime-tests.sps:227-235` and a mutation on that exact FAIL line). So ② decides and records
  it; it does not quietly change behaviour a pin asserts.
- **THREE of §3.2's four divergences are ②'s, not four.** The `pass-zero-progress` reachability
  gate is **Slice ③'s** — decision `0027` item 3 says so in one sentence ("Slice ③ owns the
  edit; this record owns the reason") and §4.5 repeats it. Scheduling it here would change a
  verdict on a machine family ③ owes a fixture for, and break ③'s stated commit-coupling.

**Oracle — four things, and none of them is "the tests pass".**

1. **Cross-lane callback order.** **Corrected 2026-09-04 while planning ②: one closure per
   LANE, each with its own accumulator**, compared per schedule over `§22.5:1278-1283`'s
   schedule list. This bullet first said "one recording closure passed as the binding to *both*
   parsers" — one closure with one accumulator produces one list and there is nothing to compare
   it to, and the shipped both-lanes driver alternates the two parsers inside a single
   expression, so a shared accumulator yields an interleaved sequence in which a lane-swap
   defect is invisible. This is `§22.4:1268`'s first-ever exercise. It is also the *only* available
   oracle: `§18:974`'s trace hook does not exist in the tree, and `§Dated:1814-1819` already
   ruled a literal cross-lane trace comparison unspecifiable.
2. **The commit point.** The same recording closure captures, *from inside the callback*,
   `parser-field-ref` values, `parser-lifecycle`, `parser-stream-offset` and
   `parser-state-name`; all must match across lanes. `§19.1:1004`'s "committed to the parser
   object at observable return/callback boundaries" has never been executed by anything,
   because no callback boundary has existed.
3. **Exact-once under pause.** `§13:814` — a callback-requested pause occurs *after* the
   delivered event is committed, and resume "continues after that event; it is never delivered
   twice." The oracle is the recording sequence across a resume, not a count.
4. **Poisoning propagates rather than returning.** `§12.6:749` says the condition or escape
   *propagates* — it is not caught. So the differential harness must run both lanes under an
   escape-catching wrapper and compare that the same condition escaped `parser-feed!` **and**
   that both parsers are poisoned. A differential written as "compare the two results" cannot
   see this case at all, because neither lane returns a result.

---

## 8. Slice ③ — Spans: start, end, boundary flush, completion-pending, and dataflow verification

**Scope, as an allocation.** Discharges `§25:1581` (one active named span), `:1582` (boundary
flush and completion), `:1583` (pause-safe span internal continuations) and `:1584` (span
dataflow verification), exit criterion `§25:1590` (every invalid span topology rejected), and
**four of the six legs of `§25:1589`.** That criterion reads "fragment tests cover boundaries,
pause, completion, error, EOF, and reset"; this slice discharges boundaries, pause, completion
and error, and Slice ④ discharges EOF and reset (§9). Neither slice discharges `:1589` whole,
and saying so is how the milestone avoids each believing the other covered a leg.

**Corrected in place 2026-09-06 by Slice ④, because a later slice works this paragraph as a
checklist.** The allocation above is what was planned; it is not what happened. Slice ③ also
shipped an EOF group and a reset group, and its oracle drives `parser-finish!` on all
thirty-seven schedules — so it discharged parts of BOTH legs it disclaimed here. The safeguard
failed in the direction the sentence does not anticipate: not each slice believing the other
covered a leg, but one slice covering a leg it had disclaimed, leaving ④'s scope overstated on
four surfaces until ④ measured it. Slice ④ closed the three SHAPES that remained (a span open
at `parser-finish!` and closed on the EOF chain; a reset while parked between the span-end
substeps; a reset of a poisoned parser with a span open) and re-covered nothing. **Read the
allocation as a plan, and the tree as the record.**

**The work.**

- `make-span-start-node` and `make-span-end-node` (`§9.1:309-310`).
- Span state in the parser: **a name and a mark, never a bytevector.** `§14:833`'s mark
  re-anchors unconditionally at every feed boundary (§3), so the mark never has to mean anything
  *between* feeds — only the span's identity and its open-ness persist. That is what keeps
  `§28:1725`'s "no bytevector field in parser storage" structurally true rather than merely
  observed.
- The `§19.3:1024` span-boundary-flush runtime helper.
- The normalizer's span-end lowering into resumable internal states (`§17:959`, ordered by
  §4.4) **and** the interpreter's independently derived substep representation — `§18:972`
  permits its own and forbids sharing one.
- `§16.3:925`'s pass 7, implementing §4.7's lattice, covering `§16.2:899`, `:900` and `:907`'s
  span half. `§16.2:900` lands here and can land nowhere else: it needs both the span dataflow
  and Slice ②'s callback node.
- **Reset clears span state.** `§12.5:739`. The citation here read `runtime.sls:532-535`, which
  by Slice ②'s head was inside the callback classifier; the comment meant is the one above
  `parser-reset!` — find it by that name, not by a line. Its observation still holds and is
  still the right one: reset has no separate saved-continuation field, so `current := entry`
  clears the pause continuation as a side effect. **This slice is what stops that reasoning
  being sufficient**, because span state is not restored by `current := entry` — and the
  comment itself said, through Slice ②, that "span and poisoned/busy state still do not exist",
  which was false of `poisoned`, of `busy`, and of the active-span slot ①b shipped.
- `pass-zero-progress`'s reachability gate, per §4.5.

**Oracle.**

1. **Same-schedule exactness.** For one span-bearing machine, the interpreter's and the
   generated lane's fragment lists — **ranges and content**, per `§22.4:1269` — are identical
   for every schedule (`§22.5:1285`). The recording callback *copies* the slice inside the
   dynamic extent, which `§13:799` explicitly permits ("Application-owned opaque values ... may
   retain data by their own policy").
2. **Cross-schedule normalization.** Fragment lists coalesced per logical span are identical
   *across* schedules (`§22.5:1287`). The test must **not** assert raw fragment boundaries
   across schedules: `§22.5:1287` calls them "intentionally schedule-dependent" and `§14:836`
   says consumers must not read meaning into them. A test that pins them would be asserting the
   opposite of the contract.
3. **Topology, enumerated rather than generated.** `§25:1590`'s "every invalid span topology is
   rejected" is a universal over a set the plan does not enumerate. Slice ⓪'s kind × position
   matrix is the shape that answers this honestly: enumerate the topologies as data, derive each
   expected verdict from `§14:843` and `§16.2:899` *before* running, and let the count be the
   sentinel. **The bounded invalid-machine generator is Milestone 7's** (`§25` names it there),
   and this slice must not quietly become it.
4. **The error path delivers no completion event** (`§14:839`), while the success path delivers
   exactly one (`§14:834`) — the reading recorded in §4.11. `§22.5:1289` states the matching
   test rule and it is easy to violate: for malformed inputs, cross-schedule assertions compare
   only acceptance, error category and absolute error position, because "a partial span may have
   been flushed by an earlier feed boundary in one schedule but not another". Callback prefixes
   on the error path are compared **exactly only between the two lanes on the same schedule**.

---

## 9. Slice ④ — Retention, the EOF and reset fragment axes, and the milestone's exit evidence

**Scope, as an allocation.** Discharges exit criterion `§25:1591` (input retention), the EOF and
reset legs of `:1589` that no earlier slice naturally reaches, and — pending §4.12 item 3 —
`§27:1694`'s callback/span lifetime reference. It writes the milestone's close note as an
appended disposition.

**Why this cannot be folded in without redesigning it.** `§25:1591` is **vacuously true
today**, and the measurement behind that sentence has been re-taken twice. It first read "the
parser is a ten-slot vector with no slot that can hold a bytevector". The parser is now
**SIXTEEN slots** — ①b added callbacks (10), user-context (11) and active-span (12); ② added the
state-name table (13); ③ added the span mark (14) and the span data-callback slot (15) — and
**three of them can hold a bytevector**: `user-context`, any callback closure in slot 10, and
`parser-error-detail` inside the stored error.

The CONCLUSION survives, and it survives for a reason worth stating rather than by luck. All
three are exactly `§13:799`'s exempt carriers, which is what layer 3 below turns on. The
non-exempt surface still cannot hold one: field values are integers, the active span is a
NAME, `current` is a node name or a state id, the state-name table is symbols — and Slice ③'s
two slots are both integers, the mark being a **slice offset** re-anchored at every feed
boundary (`§14:833`) precisely so that nothing has to be retained to interpret it. So the
sentence was false as written and is corrected here; what it concluded is not.

A retention test written against this tree still passes whether or not the span path runs. The
defence is a **negative control**: a deliberately retaining fixture the oracle must *fail* on,
designed alongside the oracle rather than added after it goes green.

**The retention oracle, in three layers.**

1. **Liveness.** A weak reference to a freshly allocated fed bytevector is `bwp` after the test
   drops its own strong reference and collects. Research measured under Chez 10.4.1 that
   `weak-cons`, `bwp-object?`, `collect` and `make-guardian` are all bound and that the probe
   discriminates. That measurement was taken in a throwaway scratch driver and did not count; it
   has since been **re-measured through the real harness, in both lanes** — Slice ③ task 7,
   `test/common/liveness-probe-tests.sps`, registered as
   `byte-machine.unit.liveness-probe.chez.{source,aot}`. **The probe discriminates in both:** a
   dropped bytevector reads `bwp` and a retained one does not, repeatably rather than only on a
   process's first collection, and a guardian agrees with the weak pair on both arms. Slice ④
   may build on it.

   Three things that lane found, and Slice ④ inherits all three. **The allocation must happen
   inside a procedure that returns only the weak pair** — a `let`-bound temporary in the same
   frame as the `collect` call can still be live at the collection point, which a scratch driver
   would not have surfaced. **The strong reference the negative control holds must live at
   module level and be cleared by assignment**, because a `harness-case` thunk closing over the
   bytevector keeps it alive whatever the runtime does, and the case then reports "retained"
   about its own closure. And **the lane is not mutation-pinned, because it imports no
   `byte-machine` source**: its control is the two-directional assertion, not a mutant — a probe
   answering a constant fails one arm or the other.
2. **The negative control**, above — without which layer 1 asserts nothing.
3. **The exemption boundary.** `§13:799` names **three** application-owned carriers outside the
   guarantee: callback closures, user context, and **callback error detail**. Once §4.1 gives a
   callback-domain error a detail slot, the parser's stored error transitively holds application
   data that `§13:799` permits to retain the bytevector, and `§12.7:777` does not compare detail
   across lanes. **An oracle that excludes only the user-context slot will report a false
   violation** the first time a fixture callback fails with a detail holding its own slice.

**Two things to say out loud, because both are easy to get wrong late.**

- **`§25:1590` and `§25:1591` are not independent.** `§13:826` states that the verifier
  restriction is "what makes the no-retention contract possible". Weaken or defer `§16.2:900`
  and `§25:1591`'s guarantee loses its stated enabling condition — the retention tests would
  still pass, and would be testing a weaker claim than the one the plan makes.
- **`§25:1599` "span interaction" is a Milestone 6 scope bullet**, and `§10.6:604`'s "When
  enclosed in a span, normal span fragment rules apply" belongs to counted consume. Neither is
  Milestone 5's, and both read as though they might be.

---

## 10. Explicitly out of Milestone 5

- **Counted consume** (`§10.6:596-604`), the thirteenth node kind, and its span interaction
  (`§25:1599`) — Milestone 6.
- **The bounded invalid-machine generator** and the differential property suite — Milestone 7,
  which owns both by name. Slice ③'s span-topology enumeration is a fixture table, not a
  generator, and the design says so in §8 precisely so the boundary is not crossed by drift.
- **Retrofitting `graph.sls` predicates and accessors onto Milestone 4's three node kinds** —
  a change to shipped surface with no Milestone 5 consumer (§4.12 item 4).
- **`§16.2:886`'s label grammar for the nine already-shipped kinds** — §4.12 item 2 proposes
  the check for Milestone 5's two new declaration families only.
- **`§16.2:911`** ("backend limits that would make emission incorrect") — recorded in §4.11 as
  an orphan with no owner in any milestone. Naming it is not claiming it.
- **Stating the `graph.sls` export convention.** §4.12 item 4, declined by the owner
  2026-09-04. Milestone 5's declaration families and node kinds follow the existing precedents
  — `uint-field`'s for declarations, Milestone 4's constructor-only shape for node kinds — and
  the header gains nothing. Nothing in the milestone depends on it, which is why it was the one
  of four proposals worth dropping.
- **A field-mutating accessor for callbacks.** `§13:801` forbids it and states why.

---

## 11. Handed to writing-plans

- **DISCHARGED 2026-09-04. The Gate 0 split was six records, 0024-0029**, exactly as planned;
  the mapping is the blockquote under §4. Ten resolutions, merged as follows,
  each merge for a stated reason. `0024` = §4.1 + §4.2, one callback-error vocabulary. `0025` =
  §4.3 + §4.8, the seam — encoding shape, ABI payload and `exec` signature in one record, which
  is exactly the shape decision 0019 took for Milestone 4 and the reason its reservations read
  as one bargain. `0026` = §4.4. `0027` = §4.5, absorbing the `pass-zero-progress` gate. `0028`
  = §4.6 + §4.9 + §4.10, the callback's runtime surface: what occupies a slot, what answers
  during `busy`, and what is observable. `0029` = §4.7.
- **§4.12 is settled** (owner, 2026-09-04): items 1-3 approved, item 4 declined. Slice plans may
  proceed on that basis.
- Re-measure every `file:line` in §5-§9 at plan-writing time. They were measured at `db86ab6`
  and each slice moves the lines below its own edits.
- **Re-measure the diagnostic-code and emission-site counts before quoting them.** Sixteen codes
  over twenty-eight sites at `db86ab6`; a stale 31 was reported during this design's own
  research and the census's own comment records the moves that made it stale.
- Decide whether Slice ④ folds into ③, with §9's negative-control cost stated.

---

## Appendix — per-kind site census

> **REWRITTEN A SECOND TIME, 2026-09-05, by Milestone 5 Slice ③ Task 8, and this
> is again a CORRECTION IN PLACE: an appendix a later slice works as a checklist
> is an INSTRUCTION.** Slice ② rewrote the table and fixed its recognisers;
> Slice ③ ran it as a checklist and found the table wanting — and then this
> paragraph got the diagnosis wrong, which the slice's own final review caught.
> Corrected, and the corrected version is worse for the checklist than the first
> one was for the table.
>
> **(1) Every line number in it had moved** — all fifteen `verify.sls` rows, all
> five `interpret.sls` rows, all five `normal-ir.sls` rows, both `runtime.sls`
> rows (which were also off by one *at the head they were measured on*), and four
> of the `compile.sls` rows.
>
> **(2) Rows were missing, but NOT for the two defects.** The table did lack rows
> for sites no recogniser finds — `normal-ir.sls`'s internal-state builder and its
> debug-map walk, both extended by Slice ③ blind. But **recogniser 1 finds both
> defect sites**: `pass-declarations`' filter is `(if (callback-node? n) …)` and
> the `§16.2:909` membership is a disjunction of `-node?` predicates. And the
> table **already carried a row** for the `§16.2:909` gate. So the recognisers
> worked and one of the two rows existed; **what failed was the checklist pass**,
> which walked the table and did not ask, of the row in front of it, whether a
> span end can be parked on.
>
> **(3) One row's stated obligation was not met** — the member-3 drift fixture,
> which rendered SEVEN of `render-state-arm`'s twelve arms. The row said what was
> owed; nobody checked it. It is twelve of twelve now.
>
> The lesson the table can carry is (2)'s: **a row is not a check.** Reading a row
> tells you a site exists; only asking the row's question of the new kind tells
> you whether it owes an arm.
>
> **So the table no longer carries line numbers.** They are the part that goes
> stale silently, nothing checks them, and `docs/decisions/README.md` already
> says the repair is "replacing the line number with a quoted sentence or an item
> name, which cannot go stale again". Every row below names a CONSTRUCT that `rg`
> finds by name. A row whose name no longer resolves is a finding about the
> table; a row that resolves is where the reader looks.

**Three recognisers, and they must be run over `test/` as well as `src/`:**

```bash
rg -n -- "-node\?" src/byte-machine/ test/common/        # per-kind predicate dispatch
rg -n "normal-state-kind" src/byte-machine/ test/common/  # normalized-kind dispatch
rg -n "\(op 'kind" src/byte-machine/ test/common/         # WIRE-kind dispatch
```

Slice ② added the third recogniser and scoped all three to `src/`; the same
`src/`-only mistake it had just corrected for the *table*.

**Recogniser 3 as printed finds nothing under `test/`, and that is a finding about
the recogniser rather than about `test/`.** `test/common/runtime-tests.sps` holds
six stub executor tables answering the same wire-kind message, but written from
the CALLEE's side — `((kind) (case (car args) …))` inside the op closure — not the
caller's. So a fourth form is needed, and `rg -n "\(\(kind\)" test/common/` finds
exactly those six. The first version of this Appendix said recogniser 3 matched
them; run as printed it returns zero hits anywhere under `test/`.

**Three rules the table itself carries, because no recogniser expresses them:**

1. **Export and import lists ARE rows.** An unexported accessor is an unbound
   identifier at the *importing* library's import, so the failure names the wrong
   file. Every library gets a row.
2. **Some census sites are invisible to all three recognisers.** They dispatch on
   something else — a block tag, a normalized state's own field, a vector slot
   number. `normal-ir.sls`'s internal-state builder and its debug-map walk are
   both of these, and both were extended by Slice ③ with no row to work from.
3. **A row may be DERIVED**, meaning a new kind owes it nothing because it reads
   a census listed elsewhere. `make-machine`'s `(for-all node? nodes)` gate is the
   example: extending `node?` extends it. Saying so is the point — it tells a
   later slice not to look for an arm.

Slice ③ shipped **twelve** of `§10.6`'s thirteen node kinds and **twelve**
normalized state kinds (the same twelve less `sequence`, which lowers to ordinary
dispatch states, plus `span-completion`, which has no source node). Wire tags
**0-13 are all taken**; the next kind's is **14**.

### `src/byte-machine/private/ir.sls`

| Construct | What a new kind owes it |
|---|---|
| the library `export` list | the kind's constructor, predicate and every accessor |
| `node?` | one disjunct — **twelve** now, and a census test reads the count |
| `node-name` | one arm, above a **raising `else`**; nothing derives it from `node?` |
| the per-kind tag/constructor/predicate/accessor blocks | one block — **TWELVE**, not the "ten sites" the shipped table said |
| `make-machine`'s `(for-all node? nodes)` | **DERIVED** from `node?`. No arm owed. |
| `matcher?`, `matcher-bytes`, the edge-`mode` set, `field-operations`, `field-predicates`, `accumulate-bases`, `make-callback-declaration`'s kind set | **NOT node-kind censuses.** Listed so they are not counted as ones: each is a closed set over a different vocabulary, and no node kind reaches any of them. |

### `src/byte-machine/graph.sls`

| Construct | What a new kind owes it |
|---|---|
| the `export` list and the `(only (byte-machine private ir) …)` import | the CONSTRUCTOR only. The façade carries no predicate and no accessor, deliberately: `§9.1:280-316`'s normative list has none. |

### `src/byte-machine/verify.sls`

| Construct | What a new kind owes it |
|---|---|
| `zero-width-edges` | the kind's zero-width out-edges, each with a ROLE symbol — the ONE census the next two are views of |
| `node-out-edges` | a view; check it does not need widening |
| `node-eof-target` | an arm iff the kind declares an EOF route |
| `pass-names`' error-reference filter | an arm iff the kind names an error declaration |
| `pass-field-operands` | an arm iff the kind carries a field operand |
| `pass-overlap` | an arm iff the kind has byte cases |
| `pass-sequence-ambiguity` | an arm iff the kind has a prefix trie |
| `reexec-targets` | an arm iff the kind can be entered by a reexecute edge |
| the zero-progress REPORT set | **moves with `reexec-targets`, never after it** |
| `classify` | an arm — this is the EOF walk's flow-through |
| `parked-eof-start` | an arm iff the kind's resume point differs from its own name. **A span end needs none: it is flow-through, so `classify` already joins over its `next`.** |
| `pass-eof-execution`'s **parked-set membership** | **A SEPARATE SITE from `parked-eof-start`, and the table listed only the other one.** A kind belongs here iff a parser can be parked on it. Slice ③ shipped without the span end and the machine it let through answered `stopped` from `parser-finish!`. |
| `§16.2:908`'s zero-hop entry clause and per-edge target | check both |
| `pass-declarations`' **per-kind node walk** | **THE ROW THE TABLE LACKED, and the second Slice ③ hole.** Any kind that names a DECLARATION — a callback, a span, a field — needs an arm here, because a constructor cannot see the machine's tables. |
| `callback-node-diagnostics` | `§16.2:901`'s node half for callbacks |
| `span-node-declaration-diagnostics` | its span half |
| pass 7: `eof-step`, `parked?`, `span-flow`, `span-transfer`, `span-node-diagnostics` | **`parked?` is a SECOND hand-written copy of the parked-set disjunction.** A kind added to one and not the other makes the two disagree. |
| `byte-reached`'s kind list | an arm iff the kind can carry byte-reachability onward |
| `eof-verdict-tiers` | **NOT a node-kind census** — a verdict-symbol table. One research pass counted it as one. |

### `src/byte-machine/interpret.sls`

| Construct | What a new kind owes it |
|---|---|
| the `export`/`import` lists | nothing today: the import is bare, not `(only …)` |
| `kind` | an arm |
| `completion-state` / `completion?` | **the SHAPE census for what `current` may be**, and `§18:972`-load-bearing. A mid-sequence compound has a byte-list cdr; a span end's substep has a symbol cdr. A third shape must be told apart from both. |
| `dispatch`'s sequence special case | check |
| `eof-target-of` | an arm iff the kind declares an EOF route |
| the field-action special case | check |
| the executor-op **message table** | one message per kind that needs data from the source IR |

### `src/byte-machine/private/normal-ir.sls`

| Construct | What a new kind owes it |
|---|---|
| the `export` list | any new accessor the emitter reads |
| the `(only (byte-machine private ir) …)` import | the kind's predicate and accessors |
| the normal-MACHINE vector's slot layout | **APPEND-ONLY** — `compile.sls` reads slot 3 by index. Three slices have extended it. |
| the normal-STATE vector's slot layout and its accessors | where a kind either fits the existing slots or forces a widening |
| `normal-state-kind` | the kind symbol |
| `internal-blocks` / `prefix-blocks` / `span-end-blocks` / `completion-id-of` / `block-of` | a family iff the kind lowers to internal states |
| the slot resolvers (`callback-slot-of`, `callback-decl-of`, `callback-default-of`, `span-slot-of`, and `normalize-machine`'s `cb-slot`) | one per declaration the kind names |
| `lower-machine`'s declared `cond` | an arm, above a **raising `else`** |
| the **internal-state builder** (phase two) | **INVISIBLE TO ALL THREE RECOGNISERS** — it dispatches on a block tag |
| the **debug-map walk** | **INVISIBLE TO ALL THREE**, and its totality is load-bearing across the ABI seam: an incomplete map is an INDEX ERROR in the generated lane, not a missing string |
| `encode-normal`'s state arms | a wire tag. **0-13 taken; the next is 14.** |

### `src/byte-machine/compile.sls`

| Construct | What a new kind owes it |
|---|---|
| the `export` list and the `(only …)` import | check |
| `reserved-member-2` | **SET EQUALITY with `(byte-machine runtime)`'s exports** — it moves in the same commit the exports do, in both directions |
| `reserved-member-3` | every identifier the emitted body binds. A new emitted local moves this list, both of its mutation `FIND`s, and `member3-drift-tests.sps`'s twice-asserted nine. |
| `render-state-arm`'s `case` | an arm, above a raising `else` whose comment enumerates the covered kinds — **that comment is a census and has drifted twice** |
| the error reason/code selection on `normal-state-kind` | check |
| the reached-declaration walk, `'(dispatch accumulate)` | **the Milestone 4 Slice ③ defect site** |
| `snames` (ABI payload member 2) | total over every normalized state, with a raising miss — where an unmapped internal state aborts emission |
| the callback arm's "calls APPLICATION code" note | **THREE arms do now.** It said "the only" through Slice ③. |

### `src/byte-machine/runtime.sls`

| Construct | What a new kind owes it |
|---|---|
| the `export` list | the SET-EQUALITY partner of `reserved-member-2` |
| the feed **wire-kind** `case` | an arm — invisible to recognisers 1 and 2 |
| the finish **wire-kind** `case` | an arm, and **check the two agree** |
| `callback-failure-position` | `§12.7:770` as a constant, read by every arm that builds a callback-domain error |

### Test-side censuses, none of which is derived from anything

| File | Construct | What a new kind owes it |
|---|---|---|
| `kind-position-census-tests.sps` | `kind-table`, `kind-predicates` | the kind axis; `S2` derives its key set from `ir.sls` and reddens first |
| | `position-table`, `role->positions` | the position axis and the edge-role map — **hand-written, and no assertion can say the rows are the right rows** |
| | `expected-codes`, `self-expectations`, the dangling-cell derivation, the absence census | **four more hand-written tables inside the same file**, each needing the new kind's derived verdict |
| `verify-tests.sps` | `t2-kinds` / `t2-hop` | `§16.2:908`'s per-kind byte-reachability rows |
| | the **edge-ROLE label census** | **THE ONLY census of `diagnostic-edge` in the tree.** It stopped at four kinds for two slices while `zero-width-edges` grew seven more edges. |
| | the span-lattice group and its two tails | a fixture that CLOSES a span must route its span end through a dispatch, not into a stop: a span end is a parked state |
| `diagnostic-census-tests.sps` | `pinned-sites`, `code-fixtures` | one row and one fixture per diagnostic code |
| `member3-drift-tests.sps` | the fixture machine | **must render EVERY emitted arm.** It rendered SEVEN of twelve before Slice ③ extended it — the first correction here said nine, and the final review re-measured — and TWELVE of twelve after. The last to arrive was `pause`, which binds nothing, and that is exactly why nobody noticed it. |
| | the hard-coded exercised-name list and its literal count | a second edit for any new `reserved-member-3` entry |
| `ir-tests.sps` | the per-kind constructor/accessor group | one group per kind — the census for `ir.sls`'s own blocks |
| `normal-ir-tests.sps` | the layout-length lists and the wire-tag golden | the only test-side pin on the encoding tags |
| `position-kind-tests.sps` | the `§12.7` producer table | a row per PRODUCER, not per kind — and its rows must be reached over the edge mode that makes the value differ |
| `runtime-tests.sps` | six stub `(op 'kind …)` tables | recogniser 3 matches them; check each |
| `graph-tests.sps` | the façade's own test | it has no span case and no callback case — the mirror is witnessed only indirectly |

---

## References

- Parent plan: `docs/plans/byte-machine-implementation-plan.md` — `§25:1576-1584` (scope),
  `§25:1588-1591` (exit), `§9`, `§10.3`, `§10.4`, `§10.6`, `§11`, `§12`, `§13`, `§14`, `§16`,
  `§17`, `§18`, `§19`, `§22`, and the appended `## Dated dispositions` section.
- `docs/plans/milestone-4-design.md` — the structural template this document follows.
- Decisions 0011 (EOF execution model), 0013 (runtime coded conditions), 0016 (internal state
  order), 0018 (unversioned generated-ABI constructor), 0019 (encoding format 2), 0020
  (constructor/verifier split), 0022 (structured `parser-error`), 0023 (EOF walk starts).
- `AGENTS.md` — testing and mutation discipline, documentation and record discipline.
