# Milestone 5 — Slice ③ (spans) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the machine *hand out ranges of the input it has already seen* without ever storing them. The eleventh and twelfth node kinds, `§14`'s ten fragment rules, the boundary flush, resumable span-end substeps, and `§16.3:925`'s pass 7 — decision `0029`'s lattice. Discharges `§25:1581`-`:1584`, exit criterion `§25:1590`, and four of the six legs of `§25:1589` (boundaries, pause, completion, error; EOF and reset are Slice ④'s).

**Architecture:** Eight tasks. **This slice adds TWO node kinds, a second family of internal states, a whole verifier pass, and the runtime's first stateful bookkeeping that is not a scalar.** It is the largest slice of the milestone by every measure. The three task merges below are not discretion — each is a pair whose halves cannot be independently green, and Slice ② corrected its own plan three times for exactly this.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS), CMake/CTest, the in-repo mutation suite.

**Measured at `09f55fb`** (main, after Slice ②'s close-out): `release` 102/102; scheme mutation **53 passes / 418 mutations**. Every `file:line` below was read that day.

---

## 1. Seven findings that change the work

Design §8 and decisions `0026`/`0027`/`0029` were written at `db86ab6` and `cc66302`. Slices ①a, ①b and ② moved the tree under them. These are the differences that change what a task must do, not merely where a line sits.

### F1 — `byte-machine-callback-step/v1` **cannot invoke a span-data callback**, and it is code both lanes call

Slice ② built one procedure that both invokes and classifies (`runtime.sls:528`). It applies

```scheme
(f parser (parser-user-context parser))
```

— arity **two**. `§13:790` gives a span-data callback arity **five**:

```scheme
(callback parser user-context bytevector start end)
```

So the shared entry point is unusable for the very callback kind this slice exists to deliver. The fix is a **split, not a widening**: classification (`§13:803-808`'s outcomes, which spans share — `§13:812` restricts them to continue/pause/failure and nothing else) is one procedure; invocation differs by arity and gets one site per kind. A widened rest-arg would put the arity decision inside the classifier, where neither lane can see which kind it holds.

**This is an edit to code the emitted library calls**, so it moves emitted text and the ABI's reserved-name set. Task 5 owns it.

### F2 — `parser-reset!` does not clear the active span, and its own comment says span state does not exist

`§12.5:739` requires reset to clear span state. `parser-reset!` (`runtime.sls:1001`) writes slots 4, 5, 6, 7 and 8 and **never slot 12**, which is `parser-active-span` and has existed since Slice ①b. It is harmless today only because nothing ever sets it.

Its comment (`runtime.sls:988-1000`) is stale twice over: *"Span and poisoned/busy state still do not exist (②/③ and M5)"* — `poisoned` and `busy` shipped in Slice ②, and slot 12 shipped in ①b. **Correct the comment in the same commit that adds the clear**, or the next reader inherits a false census.

### F3 — design §8's reset citation is stale

§8 says *"Note `runtime.sls:532-535`'s comment that reset clears the pause continuation only as a side effect of `current := entry`"*. That comment is now at **`runtime.sls:988-1000`**; `:532-535` is inside Slice ②'s callback classifier. The *observation* still holds and is still the right one: reset has no separate saved-continuation field, and this slice is what stops that reasoning being true, because span state is not restored by `current := entry`.

### F4 — design §9's retention measurement is stale, and its conclusion survives

§9 says *"measured, the parser is a ten-slot vector (`runtime.sls:183-184`) with no slot that can hold a bytevector."* It is **fourteen slots** now: ①b added callbacks (10), user-context (11) and active-span (12); ② added the state-name table (13). **Three of them can hold a bytevector** — `user-context`, any callback closure, and `parser-error-detail` inside the stored error.

The conclusion survives because all three are exactly `§13:799`'s exempt carriers, and the non-exempt surface (field values, active span *name*, current state, state names) still cannot hold one. But the sentence as written is false, and §9's own layer 3 already turns on that exemption boundary. **Task 8 corrects §9 in place** — it is an instruction a later slice executes, not a record.

### F5 — the mark is a new parser slot, and `parser-active-span` is only half the span state

`§14:830` records the cursor at span start and `§14:831` emits `[mark,cursor)` at end. Slot 12 holds the *name*; nothing holds the *mark*. Slot 14 is the mark.

**It is a slice offset, not a stream offset, and it re-anchors at every feed boundary** (`§14:833`). That is what keeps `§28:1725`'s "no bytevector field in parser storage" structurally true rather than observed: the mark never has to mean anything *between* feeds, so nothing has to be retained to interpret it.

### F6 — decision `0029` fixes pass 7's node domain and says **nothing about its edge set**, and `§16.2:907` cannot be reached without one

`0029` item 3 takes the *reachability relation* from `0027` — byte-reachability plus the EOF walk — and that settles **which nodes carry state**. It does not say which edges the transfer function follows, and the two are different questions.

The gap is load-bearing: `§16.2:907` is *"successful EOF with an active span"*, and design §8 allocates its span half to this pass. A dataflow over `node-out-targets` alone never reaches a finish node that is only EOF-reachable — `node-out-targets` excludes eof-targets by construction (`verify.sls:181`, `node-eof-target` is its own accessor for exactly that reason). **Pass 7's edge set must be `all-out-targets`' shape — byte out-edges plus eof routes — while its node domain stays `0027`'s.** Task 2 states it and its fixture proves it: a machine whose only route to a finish node is an eof-target, with a span left open.

### F7 — `pass-zero-progress`'s gate changes which machines verify, and the census will move

`0027` item 3 assigns the `byte-reached` gate to this slice. It is a **relaxation**: machines holding an unreachable zero-progress cycle stop being rejected. `0027` records that `pass-reachability` does not catch them either — its `all-out-targets` walk crosses an eof-target and then keeps taking byte edges, so it accepts nodes no execution can occupy.

So this edit has an observable accept/reject change with **no existing fixture**, and the diagnostic census pins `zero-progress-cycle` at one site. Task 3 owns it alone, with a fixture for the family it newly accepts.

---

## 2. Slice ④ does NOT fold into ③ — the design's open question, decided

Design §11's last handed-forward item reads *"Decide whether Slice ④ folds into ③, with §9's negative-control cost stated."* **Decided 2026-09-05: they stay separate**, and §9's own argument is what decides it — strengthened, not weakened, by Slice ②.

`§25:1591`'s retention guarantee is about the **non-exempt** parser surface, and F4 above re-measures that surface: still no slot on it can hold a bytevector. So a retention test written after the span path is already green passes **whether or not the span path runs**, and is indistinguishable from a vacuous one. The defence is §9's negative control — a deliberately retaining fixture the oracle must *fail* on — and it has to be designed alongside the oracle rather than added once the test is green. A slice boundary is the cheapest mechanism that enforces that ordering, and this project has shipped the other shape repeatedly.

The size argument is secondary but real: this slice already carries two node kinds, a second internal-state family, a whole verifier pass, the interpreter's independently derived substep representation, and the runtime's first non-scalar bookkeeping.

**One piece of ④ moves forward, and only one.** Task 7 validates the liveness probe. §9 says its own measurement *"was taken in a throwaway scratch driver and does not count"*; if the probe does not discriminate through the harness in the AOT lane, ④'s oracle needs redesigning, and that is far cheaper to learn while ③ is in flight. It needs no spans.

---

## Global Constraints

- **Authority order.** `milestone-5-design.md` §8, then decisions `0029` (the lattice), `0027` (the relation), `0026` (internal state ids). Where an authority is wrong, **stop and say so**: this milestone has corrected seven such defects, and §1 above adds four more.
- **Wire tags 11 and 12 are the two lowest free literals.** Measured at `09f55fb`: state kinds hold 0-7 and **10**; 8 and 9 are the trailing slot-table *section* discriminators (Slice ①b). A duplicate `(put-u8 p N)` fails the suite at *declaration* against its bare one-site `FIND`.
- **Do not write a state-tag literal, or `(cons '`, in a COMMENT.** Both matchers are textual. Slices ①b and ② each broke a pin this way.
- **`edge-roles-in-source` collects every `(cons 'SYM …)` in `verify.sls`** — **16 code occurrences** at `09f55fb` (18 textual; two are in the comment forbidding them). Two new roles land here, and `role->positions` and `position-table` must gain their rows *in the same commit*, or the census pass goes red on its **baseline**.
- **The lattice runs over the DECLARED graph, never the normalized one** (`0029` Consequences). `compile.sls:33` verifies before `:36` normalizes, so a span end is one node to pass 7 whatever it lowers to afterwards.
- **The mutation suite declares no `SITES`**, so every `FIND` is pinned at one occurrence in *both* directions.
- **A mutant can HANG the suite** — the runner has no per-mutant timeout (AGENTS.md). Any fixture that re-enters the runtime must bound itself.

---

## Task 1: The two node kinds, the matrix, and the edge roles

**Files:** `private/ir.sls`, `graph.sls`, `verify.sls`, `test/common/kind-position-census-tests.sps`, `test/common/ir-tests.sps`.

**ONE COMMIT.** `node?`'s eleventh and twelfth disjuncts redden the census's S2 row, which reads `ir.sls` **at run time**; the matrix rows are what answer it. Slice ② merged its Tasks 1-2 for this exact reason and recorded the correction in its own plan.

- [ ] **Step 1: The constructors** — `§9.1:309-310`:
      `(make-span-start-node name span next source-label)` and
      `(make-span-end-node name span next source-label)`.
      Model on `make-field-action-node`: one mandatory successor, no `#f` arm.
      Decision `0020`'s **constructor half only** — `span` is a symbol and nothing more. Whether it names a declared span is a cross-reference this constructor cannot see; `§16.2:899` and pass 7 own it.
- [ ] **Step 2: `node?`, `node-name`, and the export lists** — twelve kinds. `node-name`'s `cond` has a **raising `else` and nothing derives it**, so a missed arm is a crash at first use. `graph.sls` re-exports the two constructors and nothing else, on the rule its own header states.
- [ ] **Step 3: The verifier's shared sites** — both kinds are **zero-width** (`§10.6:590`, `:594`, "without consuming input"), so they join `zero-width-edges` with one role each, and through it `node-out-edges`, `zero-width-successors`, `eof-successors`, `reexec-targets` and the zero-progress REPORT set. The walk and the REPORT set move **in one commit** — the half-fix Milestone 3 Slice ② shipped.
- [ ] **Step 4: `parked-eof-start` — the span kinds are NOT parked states, and say so.** Slice ② added that helper because a callback's parked resume route differs from its flow-through route. Neither span kind pauses *itself*: `§14:837` and `§14:838` park on the span-data or completion callback's own pause, whose continuation is that callback node's, not the span node's. A span node classifies as flow-through, like a field action. **Assert it rather than omitting it** — Slice ② shipped a `parked-eof-start` whose identity collapse reddened four matrix cells, and the matrix is what will notice this too.
- [ ] **Step 5: The matrix** — twelve kinds, and two new positions (`span-start-next`, `span-end-next`) with their sixteen-plus verdict cells **derived from `§16.2` before running**. `role->positions` and `position-table` gain their rows here. Counts to move: `"the same ten kinds"`, `"position-table is exactly 15 role-carrying + 4 unlabelled"` (→ 17 + 4), `"eleven constructor refusals"`, and the axis-A/B/C driven totals.
- [ ] **Step 6: Verify** — `rg -n "\(cons '" src/byte-machine/verify.sls | grep -v ";;" | wc -l` matches the new code count; `unit.ir` and `unit.kind-position-census` green; contract-violation tests per rejection (who + code + detail).
- [ ] **Step 7: Commit**

---

## Task 2: Pass 7 — the span lattice

**Files:** `verify.sls`, `test/common/verify-tests.sps`, `test/common/diagnostic-census-tests.sps`.

- [ ] **Step 1: The domain, the join, and the EDGE SET**

Decision `0029` item 1's flat lattice — `⊥`, `none`, `(active s)` per declared span, `⊤` — seeded `none` at the entry, run to a fixpoint. **`§16.3:929` makes the fixpoint map a first-class output**, not a local: "Each pass receives an immutable value and returns diagnostics plus any derived immutable analysis."

**The edge set is this task's to decide, because `0029` does not (F6).** It is the byte out-edges *plus* the eof routes — `all-out-targets`' shape — while the node domain stays `0027`'s occupiable set. State the two separately in the code, because they are two questions and a later slice will otherwise fuse them.

- [ ] **Step 2: The five rejections, mapped**

`0029`'s Consequences table is the specification; transcribe it rather than re-deriving it:

| `§16.2:899` | transfer |
| --- | --- |
| span re-entry | start for `s` on `(active s)` |
| overlap | start for `s` on `(active t)`, `t ≠ s` |
| wrong end | end for `s` on `(active t)`, `t ≠ s` |
| unmatched end | end on `none` |
| inconsistent successful exits | a join yielding `⊤` |

**`⊤` is reported at the node where it arises and never flows onward** (`0029` item 2). That is what keeps the transfer functions total.

- [ ] **Step 3: `§16.2:900` and `§16.2:907`'s span half**

`:900` — "explicit pauses or event/decision callback invocations reachable while a span is active" — reads the same abstract state at a pause node or a callback node. `§13:826` adds the exception in words: *"Only the active span's own data callback may pause before the span closes."*

`:907` and `0029` item 4 — a stop or finish reached with `(active s)`. This is where F6's edge set earns its keep, and where `0023` item 5's kept `finish`-vs-`error` distinction is consumed: `§14:839` contemplates a span still open at an **error** terminal, so only the successful ones are rejected.

- [ ] **Step 4: The codes**

Minted here, not by `0029`. The diagnostic census is the ratchet — **a new code, or a new site under an existing code, fails it until accounted for** — so `pinned-sites` and `code-fixtures` move in this commit with one fixture per code. Prefer **few codes with distinguishing messages**, the precedent `invalid-callback-declaration` and Slice ②'s `invalid-callback-invocation` both set.

- [ ] **Step 5: Verify** — a positive machine that verifies clean *first*, or every rejection below it is satisfiable by a pass that rejects all spans. Then one fixture per row of Step 2's table, plus `⊤` at a merge, plus an **error** terminal with a span open (accepted — `0029`'s own worked example), plus F6's EOF-only finish.
- [ ] **Step 6: Commit**

---

## Task 3: `pass-zero-progress`'s reachability gate

**Files:** `verify.sls`, `test/common/verify-tests.sps`.

**Its own commit, because it is the only accept/reject change in this slice that has nothing to do with spans**, and burying a relaxation inside a feature commit is how one goes unreviewed.

- [ ] **Step 1** — `0027` item 3: the gate is `byte-reached` **alone**, not item 1's composite. `§16.2` states the two halves as two bullets and `:908`'s half already has an owner in `eof-terminal`'s `cycle` verdict; gating on the composite would make the two checks overlap on exactly the machines `:908` was written for.
- [ ] **Step 2: Verify** — the fixture `0027`'s Context derives: entry `E` dispatching into an error node with eof-target `T`, and `T` a byte-dispatch reachable only that way, holding a reexecute self-loop. Before the gate it is `zero-progress-cycle`; after, it verifies clean. **Assert both directions** — the pre-gate verdict is what says the fixture reaches the arm at all.
- [ ] **Step 3** — re-run the diagnostic census. `zero-progress-cycle`'s site count does not move (the report site is unchanged); its *fixture* may, if the shipped one relied on an unreachable cycle.
- [ ] **Step 4: Commit**

---

## Task 4: Lowering, the second internal-state family, and encoding

**Files:** `private/normal-ir.sls`, `test/common/normal-ir-tests.sps`.

- [ ] **Step 1: Span start is 1:1; span end is not**

`0026` item 2: **one internal state per resumable substep, not a fused state**, because `§14:838` resumes "at the next undelivered substep" and a fused state has one resume point. The substeps are `§14:831`-`:832` and `§14:841`: emit the remaining nonempty fragment; make the span inactive; invoke the completion callback. `§14:841` names the state between them — `completion-pending`.

- [ ] **Step 2: `0026` item 1's merged pre-order — and this is the family that makes the rule non-inert**

Phase one is untouched: declared nodes keep their declaration index. In phase two, **a declaring node contributes all of its internal states at its own position in declaring-node order** — a span-end node's continuations sit ahead of a *later* sequence node's prefix states, not in a family block of their own. `prefix-blocks` (`normal-ir.sls:366`) currently allocates for `sequence-dispatch-node?` only; it becomes a two-family walk.

**Every existing fingerprint must be unchanged**: a machine with no span node allocates no second-family state, so its ids and its encoding do not move. That is checkable and is Step 5.

- [ ] **Step 3: The debug map stays TOTAL** — `§17:963`, and `§13:820` requires `parser-state-name` to name "the source callback/span node, not a generated internal continuation". A span continuation answers with its **declaring** node's public name, exactly as a prefix state does. Slice ② made this reachable: the map now crosses the seam as ABI payload member 2, so an incomplete map is an *index error in the generated lane*, not a missing debug string.
- [ ] **Step 4: Encoding** — wire tags **11** and **12**, and every part that reaches the ABI in the encoding (decision `0019` item 2). For a span node that is the resolved **span slot** and its `next`; for the substep states, their own kind and successor. Slice ①b shipped the converse of `0019` item 2 and Slice ② shipped a separability group for it — **copy that group's shape**, varying one encoded part at a time against a machine held otherwise fixed.
- [ ] **Step 5: Verify** — a golden fingerprint for one span machine (a tag change moves every span fingerprint together, so only a fixed value catches it); every pre-existing fingerprint unchanged; the state vector's declared layout length holds for the new kinds.
- [ ] **Step 6: Commit**

---

## Task 5: Execution in both lanes

**Files:** `runtime.sls`, `interpret.sls`, `compile.sls`, `test/common/differential-span-tests.sps` (new), `test/CMakeLists.txt`.

**ONE COMMIT, and Slice ② established the rule: an emitted arm is a call to something.** Rendering the span arms without the runtime that serves them ships either a call to an unbound identifier — a generated library that fails at *load*, which no test loads — or a reachable `assertion-violation` a later task deletes. Neither is visible to "fingerprints unchanged".

- [ ] **Step 1: Split the invocation from the classification (F1)**

One classifier over `§13:803-808`'s outcomes; one invocation site per callback arity. Span callbacks accept only continue, pause and failure (`§13:812`), so their branch map is empty and the classifier is unchanged in substance — what moves is *who applies `f`*.

`reserved-member-2` and `reserved-member-3` both have drift guards and both move with the exports.

- [ ] **Step 2: Parser span state — a name and a mark, never a bytevector**

Slot 12 already holds the name. Slot 14 is the mark (F5). `§14:833` re-anchors it at every feed boundary, so it is a **slice offset**.

- [ ] **Step 3: The boundary flush** — `§19.3:1024`'s runtime helper, and `§14:833`: at a feed boundary an open span emits `[mark,end)` **if nonempty** (`§14:834` suppresses empty fragments), remains logically open, and re-anchors. `§14:837`: a pause *during* the flush commits the fragment and resumes with the next supplied input.
- [ ] **Step 4: Reset clears span state, and the stale comment goes with it (F2)** — `§12.5:739`.
- [ ] **Step 5: The interpreter's own substep representation** — `§18:972` **permits its own and forbids sharing one**. This independence is what lets the differential catch a lowering defect at all; a proposal to share is a change to decision `0015`, not a refactor.
- [ ] **Step 6: Emission** — `render-state-arm` for both kinds and for the substep states.
- [ ] **Step 7: Verify** — a both-lanes fixture per fragment rule, before the oracle: start/end with a nonempty fragment, an empty one suppressed, a flush at a feed boundary, a pause in the flush, a pause between the span-end substeps, and an error with a span open (`§14:839`: no final partial fragment, no synthesized completion, earlier fragments still observable).
- [ ] **Step 8: Commit**

---

## Task 6: The oracle

**Files:** `test/common/differential-span-tests.sps`.

Design §8's four items, with Slice ②'s correction carried forward: **one recording closure per lane, each with its own accumulator.** ②'s plan asked for one closure shared by both parsers, which yields one list with nothing to compare it to.

- [ ] **Step 1: Same-schedule exactness** — `§22.4:1269` compares "exact span fragment ranges/content". The recording callback **copies** the slice inside the dynamic extent, which `§13:799` explicitly permits. Over `§22.5`'s schedule list; Slice ②'s thirty-schedule table is the shape to reuse.
- [ ] **Step 2: Cross-schedule normalization** — fragment lists **coalesced per logical span** are identical across schedules (`§22.5:1287`). **The test must NOT assert raw fragment boundaries across schedules**: `§22.5:1287` calls them "intentionally schedule-dependent" and `§14:836` says consumers must not read meaning into them. A test that pins them asserts the opposite of the contract.
- [ ] **Step 3: Topology, enumerated as data** — `§25:1590`'s "every invalid span topology is rejected" is a universal over a set the plan does not enumerate. **Slice ⓪'s matrix is the honest shape**: enumerate the topologies, derive each verdict from `§14:843` and `§16.2:899` *before* running, and let the count be the sentinel. **The bounded invalid-machine generator is Milestone 7's**, and this slice must not quietly become it.
- [ ] **Step 4: The error path** — `§14:839` delivers no completion event; the success path delivers exactly one (`§14:835`). `§22.5:1289`: for malformed inputs, cross-schedule assertions compare **only** acceptance, error category and absolute error position, because a partial span may have been flushed at a boundary in one schedule and not another. Callback prefixes are compared exactly **only between the two lanes on the same schedule**.
- [ ] **Step 5: Commit**

---

## Task 7: Validate Slice ④'s liveness probe

**Files:** `test/common/` (a small lane), `test/CMakeLists.txt`.

**Moved forward from Slice ④ deliberately, and it is cheap here and expensive there.** Design §9's retention oracle rests on a weak-reference probe — `weak-cons`, `bwp-object?`, `collect`, `make-guardian` — and says in its own words that the measurement behind it *"was taken in a throwaway scratch driver and does not count"*. If the probe does not discriminate through the real harness in the **AOT** lane, ④'s oracle needs redesigning; that is much cheaper to learn while ③ is in flight than after it ships.

- [ ] **Step 1** — assert, through the harness and in both lanes, that the probe distinguishes a deliberately retained object from a dropped one. **This is the negative control in miniature**, and it needs no spans.
- [ ] **Step 2** — record the result where ④ will find it: if the probe does not discriminate, say so in the design's §9 rather than in this plan alone.
- [ ] **Step 3: Commit**

---

## Task 8: Census reconciliation, corrections, and totals

- [ ] **Step 1: Re-run all three recognisers** (the design Appendix's, as Slice ② rewrote them) and reconcile, **including the `test/` rows** — `t2-kinds`, the matrix's two tables, the diagnostic census, and the member-3 drift fixture. A row found that the Appendix lacks is a finding about the Appendix.
- [ ] **Step 2: Correct design §8 and §9 in place** — §8's `runtime.sls:532-535` (F3), and §9's slot measurement (F4), which is false as written while its conclusion stands. Both are **instructions** a later slice executes; the amendment law corrects those in place and annotates records.
- [ ] **Step 3: Decision notes** — `0026` (its second family now exists, so the rule is no longer inert), `0027` (item 3 discharged), `0029` (the pass shipped; item 3's edge-set gap named in F6). Dated notes, verb chosen per `docs/decisions/README.md`.
- [ ] **Step 4: Totals** — `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` move in the same commit as the declarations, and so do the banner at the head of `SchemeMutationSuite.cmake`, its narrative, and the phrase near the totals gate. **Nothing checks any of the three.**
- [ ] **Step 5: The ledger and the four status surfaces** are the closing ritual's, not this task's.
- [ ] **Step 6: Commit**

---

## Verification

`release` green, the mutation suite at its new totals, and six things checkable rather than asserted:

1. **`node?` has twelve disjuncts and the matrix has twelve rows** — S2 compares them, so neither drifts alone.
2. **`role->positions` covers every `(cons 'SYM …)` in `verify.sls`**, counted in code and not in prose.
3. **Every fingerprint that existed before this slice is unchanged**, and the goldens move only if a machine *without* a span node renders differently — which it must not.
4. **Pass 7 accepts a machine with a span open at an ERROR terminal and rejects one with a span open at a finish** — the pair that proves `0023` item 5's kept distinction is doing work.
5. **The span trace is identical across every schedule once coalesced, and raw fragment boundaries are asserted nowhere across schedules.**
6. **The liveness probe discriminates in both lanes** — or the design says it does not, before Slice ④ is planned.
