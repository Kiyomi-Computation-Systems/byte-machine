# Milestone 5 — Slice ② (the callback-invocation node) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the machine *call out*. The tenth node kind, the four callback outcomes, the `busy` and `poisoned` lifecycle rows, `dynamic-wind` poisoning, and `parser-state-name` — the accessor Slice ①b could not build. Discharges `§25:1577`, `:1578`, `:1579`, `:1580` and exit criterion `§25:1588`.

**Architecture:** Nine tasks. **This is the first slice since Milestone 4 to add a node kind** — `node?` goes nine disjuncts to ten — and all three Slice ③ defects were that exact shape. The per-kind census is this plan's spine, and §1 below replaces the design's appendix rather than citing it.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS), CMake/CTest, the in-repo mutation suite.

---

## 1. The per-kind census, re-measured — and why the design's appendix cannot be used as-is

Design §7 says: *"Re-run the appendix's stated recogniser at plan-writing time and reconcile against the table."* **Done, at `317b89c`, and the instruction does not work.**

**The appendix's own recogniser cannot find two rows the appendix itself lists.** `rg -- '-node\?'` and `rg 'normal-state-kind'` both return **zero hits** for `runtime.sls`, yet the table lists `runtime.sls:323` and `:459`. Those two dispatch on the *wire kind symbol* — `(case (op 'kind node) …)` — which neither recogniser sees. Followed literally, the reconciliation produces a checklist that omits the generated/interpreted runtime seam entirely.

**A third recogniser is therefore required**, and this plan states it:

```bash
rg -n -- "-node\?" src/byte-machine/            # per-kind predicate dispatch
rg -n "normal-state-kind" src/byte-machine/     # normalized-kind dispatch
rg -n "case \(op 'kind|\(op 'kind" src/byte-machine/   # WIRE-kind dispatch — the missing one
```

**And the exclusion rule writes out a demonstrated defect surface.** The appendix drops "import/export lists" as not-constructs. Slice ①b's own title is *"…and five missing exports"*: an unexported accessor is an unbound identifier at the *importing library's import*, not at its call site, so the failure names the wrong file. **Export and import lists are rows in this table.**

**Eight of the appendix's 27 rows have stale line numbers** (①a and ①b moved them) and **at least five rows are missing**. The table below is measured at `317b89c` and supersedes it.

| File | Site | Construct | Note |
|---|---|---|---|
| `private/ir.sls` | `:10-63` | the library export list | **missing from the appendix** |
| `private/ir.sls` | `:491-495` | `node?` — the closed set; a census test reads it | was `:484-488` |
| `private/ir.sls` | `:496-506` | `node-name` — nine arms, raising `else`, nothing derives it | was `:489-499` |
| `private/ir.sls` | nine sites | the per-kind predicate definitions | **missing** |
| `graph.sls` | export + import lists | the façade | **missing — no row at all** |
| `verify.sls` | `:98` | `zero-width-edges` — the one census | |
| `verify.sls` | `:125` | `node-out-edges` | |
| `verify.sls` | `:162` | `node-eof-target` | |
| `verify.sls` | `:232`, `:381`, `:434`, `:495`, `:626`, `:848`, `:859` | the six passes and the `:908` clause | unchanged |
| `verify.sls` | `:511`, `:764`, `:910` | `reexec-targets`, `classify`, the `:909` gate | were `:510`, `:761`, `:908` |
| `interpret.sls` | `:84-92`, `:98`, `:158-160`, `:293` | kind dispatch and its special cases | unchanged |
| `interpret.sls` | `:252-320` | **the executor-op message table** (`((kind) …)` at `:314`) | **missing** |
| `private/normal-ir.sls` | `:130` | `normal-state-kind` | **missing** |
| `private/normal-ir.sls` | `:313-329` | `prefix-blocks` / `block-of` (raises on a miss) | **missing** |
| `private/normal-ir.sls` | `:362-445` | `lower-machine` cond | was `:342-425` |
| `private/normal-ir.sls` | `:541-594` | `encode-normal` state arms | was `:494-547` |
| `compile.sls` | `:257-380` | `render-state-arm` | was `:247-357` |
| `compile.sls` | `:413`, `:445-446` | error reason/code; the reached-declaration walk | were `:390`, `:422` |
| `runtime.sls` | `:477`, `:613` | the two **wire-kind** cases — invisible to both stated recognisers | were `:323`, `:459` |

**Task 9 re-runs all three recognisers and reconciles again.** A row found then that this table lacks is a finding about this plan.

---

## Global Constraints

- **Authority order.** `milestone-5-design.md` §7, then decisions `0024` (callback errors), `0028` (slots, `busy`, accessors — **read its dated note**), `0025` (the seam). Where an authority is wrong, **stop and say so**; this milestone has corrected five such defects, three of them found while writing a plan.
- **Wire tag 10 is the lowest free literal.** The appendix says "0-7 taken"; measured at `317b89c`, **8 and 9 are also taken** — ①b's trailing-section discriminators. A duplicate `(put-u8 p N)` fails the suite at *declaration* against its bare one-site `FIND`.
- **Do not write a state-tag literal, or `(cons '`, in a COMMENT.** Both matchers are textual. ①b broke a pin by spelling a tag out in the comment warning against duplicating it, and its own `(cons '` check answered 15 because two were in the comment forbidding them.
- **`edge-roles-in-source` collects every `(cons 'SYM …)` in `verify.sls`** — 13 occurrences over 12 code lines, 12 distinct, all mapped. **A callback node's new edge roles will add to this**, so `role->positions` and the matrix must gain their rows *in the same commit*, or the census pass goes red on its **baseline**.
- **The `else` arms in `parser-feed!` (`:430`) and `parser-finish!` mean "ready".** Setting lifecycle to `poisoned` or `busy` without adding arms makes the parser **re-execute instead of raising**. There is no exhaustiveness check, and no test would notice today because no test can produce those states.
- **The mutation suite declares no `SITES`**, so every `FIND` is pinned at one occurrence in *both* directions.

---

## 2. The three divergences ② fixes — and the fourth, which is not ②'s

Design §3.2 lists four. **Three are ②'s. The fourth is not, and scheduling it here would break another slice's commit-coupling.**

1. **`parser-reset!` has no lifecycle guard** (`runtime.sls:699-704`, five unconditional mutations) though `§12.2:699`'s `busy` row forbids it. **②'s.**
2. **`parser-resume!`'s else arm** (`:659-660`) answers `'lifecycle-violation` where `§12.2:698` requires `parser-poisoned`. **②'s.**
3. **A `paused-finish` result populates `next`/`consumed`** that `§12.3:711` calls inapplicable. **②'s to *disposition*, and it has no authority yet** — neither §4 nor any of `0024`-`0029` resolves it, while the tree pins the *current* behaviour twice (`runtime-tests.sps:227-235`, plus a mutation on that exact FAIL line). **Task 8 decides it and records the decision; it does not quietly change behaviour a pin asserts.**
4. **`pass-zero-progress`'s missing reachability gate** — **NOT ②'s.** Decision `0027` item 3 and design §4.5 both assign it to Slice ③, which owes a fixture for the machine family it changes. §7's framing was wrong; corrected here.

---

## Task 1: The tenth node kind

**Files:** `private/ir.sls` (constructor, predicate, accessors, `node?`, `node-name`, exports); `graph.sls` (both lists).

- [ ] **Step 1: The constructor** — `§9.1:307-308`: `(make-callback-node name callback continue-target branch-targets pause-continuation source-label)`. Model on `make-field-branch-node`, the nearest zero-width multi-successor precedent.

**Constructor half only** (decision 0020, and `ir.sls`'s own recorded consequence): local shape and closed-set membership. `branch-targets` is a **proper list of two-element lists** (`§9.1:318`) — the same convention `§9.3:419` fixes for bindings and that ①b's review caught being implemented as pairs. **Do not check** whether the named callback exists, its kind, or whether the branch keys match its declaration: all three are cross-references and `§16.2:901`'s node half owns them.

- [ ] **Step 2: `node?` and `node-name`, and the exports**

Adding the tenth disjunct to `node?` **fires the S2 ratchet** (`kind-position-census-tests.sps:326`), which reads `ir.sls` at run time — so the kind-table row must land in the same commit. `node-name`'s `cond` has a **raising `else` and nothing derives it**, so a missed arm is a crash at first use, not a failed assertion.

- [ ] **Step 3: Verify** — contract-violation tests per rejection (who + code + detail); `unit.ir` green.
- [ ] **Step 4: Commit**

---

## Task 2: The matrix row, and the edge roles

**Files:** `kind-position-census-tests.sps`.

- [ ] **Step 1** — `node?` now has ten disjuncts, so S2 is red until the kind table has a tenth row with sixteen position cells whose verdicts are **derived from `§16.2` before running**.
- [ ] **Step 2** — the node's edge roles join `verify.sls`'s census, so `role->positions` and `position-table` gain rows. **Both in this commit**, or the census pass fails on its baseline.
- [ ] **Step 3: Verify** — `rg -n "\(cons '" src/byte-machine/verify.sls | grep -v ";;" | wc -l` matches the new code count; `unit.kind-position-census` green.
- [ ] **Step 4: Commit**

---

## Task 3: Lowering, encoding, emission

**Files:** `private/normal-ir.sls`, `compile.sls`.

- [ ] **Step 1** — `lower-machine`'s cond, `prefix-blocks`/`block-of` (**raises on a miss**), the state arms with **wire tag 10**, and `render-state-arm`.
- [ ] **Step 2: Verify** — every existing fingerprint **unchanged**; the four goldens move only if the emitted text of a machine *without* a callback node changes, which it must not.
- [ ] **Step 3: Commit**

---

## Task 4: `parser-state-name`, and the id→name table

**Files:** `private/normal-ir.sls`, `compile.sls`, `runtime.sls`, `interpret.sls`.

- [ ] **Step 1: Read what ①b could not do, and pick the transport**

`§13:820` requires the *source* node name. The op lane can answer today (`current` is a node name, or the compound `(name . path)` inside a sequence — return `(car current)`). The generated lane holds an **integer state id** and `normal-machine-debug-map` is read at exactly one site, at emission time.

**`parser-state-name` returns a bare symbol, always.** `§13:820`'s "together with the active span name" was split across two accessors by decision `0028` item 2, and the parent plan's disposition at `§Dated:2053-2058` rejects the compound: *"no caller can predict which calls return the compound."*

**Transport: a third ABI payload member.** Note what the ground truth established: *"a separate emitted definition" is not a third option* — `compile.sls` emits one export and the constructor's five arguments are the only channel, so a top-level `define` must still be passed in. It is a rendering choice, not a transport. Both real options grow the payload; a third member keeps member 1's meaning intact and follows `0025`'s own growth precedent. **`§9.5:444` forces an ABI version bump, 4→5.**

- [ ] **Step 2: Verify** — the accessor answers **identically in both lanes** for the same machine and position. That cross-lane equality is the whole point; a per-lane test proves nothing.
- [ ] **Step 3: Commit**

---

## Task 5: Outcomes, and invocation

**Files:** `runtime.sls`, `interpret.sls`, `compile.sls`.

- [ ] **Step 1** — the four outcomes of `§13:803-808`. `continue` and `pause` are the shipped singletons; a branch key is a bare symbol (`§9.3:421`); a failure is ①b's `make-callback-failure`. An **unbound optional callback's slot holds ①b's sentinel and is short-circuited** (decision `0028`) — this is the slice that makes that real.
- [ ] **Step 2** — `§13:812`: event and span callbacks accept only continue/pause/failure. An out-of-contract return is decision `0024`'s **`callback`-domain parser error** — not a raise, not poison.
- [ ] **Step 3** — `§16.2:901`'s node half: branch targets missing, duplicated or undeclared.
- [ ] **Step 4: Verify** — a positive fixture per outcome, in both lanes.
- [ ] **Step 5: Commit**

---

## Task 6: `busy`, `poisoned`, and the ordering clause

**Files:** `runtime.sls`, `private/conditions.sls`.

- [ ] **Step 1: The two rows, and the `else` arms that would swallow them**

`§12.2:698-699`. **`parser-feed!`'s `else` at `:430` means "ready"** — add the arms *before* touching the lifecycle values, or a poisoned parser silently re-executes. Same in `parser-finish!`.

Then the two shipped-behaviour changes of §2: `parser-reset!` gains its guard; `parser-resume!`'s else arm answers `parser-poisoned`.

- [ ] **Step 2: `§12.6:747`'s ordering clause, which is a separate obligation**

*"Prohibited lifecycle operations and reentrant parser operations raise API-contract conditions **before further mutation**."* Testable and must be tested: sample lifecycle, offset, every field and the stored error **before and after** a refused operation and assert byte-for-byte equality. A test that only checks the raise cannot see a guard that mutates first.

- [ ] **Step 3: Verify** — `§9.4:438`'s `reentrancy` and `poisoned parser` codes are distinct from `lifecycle-violation`; all five accessors answer during `busy` (decision `0028` item 1).
- [ ] **Step 4: Commit**

---

## Task 7: Poisoning, and the escape the differential cannot see

**Files:** `runtime.sls`.

- [ ] **Step 1** — `§12.6:749`: an unexpected condition or nonlocal escape **propagates**, and `dynamic-wind` marks the parser poisoned. `§7.1:160` names the mechanism as available. Only full reset may reuse it.
- [ ] **Step 2: Build the escape-catching wrapper the oracle needs**

**A differential written as "compare the two results" cannot see this case at all, because neither lane returns a result.** Both lanes run under a wrapper; the test compares that the *same* condition escaped `parser-feed!` **and** that both parsers are poisoned. If the harness has no such wrapper, building it is this task's work, not an assumption.

- [ ] **Step 3: Commit**

---

## Task 8: The oracle — and two of the design's four are not buildable as written

- [ ] **Step 1: Correct oracle 1 before executing it**

§7 says *"One recording closure passed as the binding to both parsers."* **One closure with one accumulator produces one list, and there is nothing to compare it to.** Worse, the shipped both-lanes driver alternates the two parsers inside a single expression, so a shared accumulator yields an *interleaved* sequence in which a lane-swap defect is invisible.

**Corrected: one closure per lane, each with its own accumulator, compared per schedule.** Over `§22.5:1278-1283`'s schedule list. This is `§22.4:1268`'s first-ever exercise — measured, **no test in the tree has ever compared a callback order.**

- [ ] **Step 2: Oracle 2's accessor is Task 4's** — `§19.1:1004`'s commit point has never been executed because no callback boundary has existed. The recording closure captures `parser-field-ref`, `parser-lifecycle`, `parser-stream-offset` and `parser-state-name` **from inside the callback**.
- [ ] **Step 3: Exact-once under pause** — `§13:814`. The oracle is the recording *sequence* across a resume, not a count: a count cannot distinguish "delivered twice" from "delivered once and something else added an entry".
- [ ] **Step 4: Poisoning propagates** — Task 7's wrapper.
- [ ] **Step 5: Commit**

---

## Task 9: Census reconciliation, totals, and the paused-finish disposition

- [ ] **Step 1: Re-run all three recognisers** (§1) and reconcile against §1's table. A row found that the table lacks is a finding **about this plan**, and gets recorded as one.
- [ ] **Step 2: Disposition `§12.3:711`** (§2 item 3). It has no authority; the tree pins the current behaviour twice. **Decide, record the decision as a dated disposition, and if the decision changes behaviour, re-anchor the pin in the same commit.**
- [ ] **Step 3: Totals and the ledger** — `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` move in the same commit as the declarations. If a pass is added, the banner at `SchemeMutationSuite.cmake:9`, the narrative at `:10-22` and the phrase near the totals gate all go stale and nothing checks any of them.
- [ ] **Step 4: Update the design's appendix** to §1's table, with the third recogniser and the export-list rule stated. The appendix is an **instruction** and is corrected in place.
- [ ] **Step 5: Commit**

---

## Verification

`release` green, the mutation suite at its new totals, and four things checkable rather than asserted:

1. **`node?` has ten disjuncts and the matrix has ten rows** — S2 compares them, so neither can drift alone.
2. **`role->positions` covers every `(cons 'SYM …)` in `verify.sls`**, counted in code and not in prose.
3. **Every fingerprint that existed before this slice is unchanged for machines without a callback node**, and the four goldens move only for the ABI bump Task 4 forces.
4. **`parser-state-name` answers identically in both lanes** — the accessor Slice ①b deferred, and the reason it was deferred was precisely that one lane could not answer.
