# Milestone 6 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as one durable record — `0030` — the two design calls Milestone 6 depends on, so that Slice ① cites a decision instead of re-deriving it. Both are externally observable: `0030`'s executor contract decides *which feed* a span's completion event lands in for every schedule, and its verifier rule decides which diagnostic a fixture emits for a stop behind a zero-count route. A slice that picks either by accident pins the wrong answer in a fixture, and the fixture then defends it.

**Architecture:** This phase writes *documentation only* — no product code, no tests, no CMake. It produces one new decision record, one dated amendment of an existing record, and the Gate-0-discharged mapping in the design document. It is the prerequisite for Slice ①, which implements every item of `0030` in one commit; Slice ⓪ (if the owner approves `milestone-6-design.md` §4.12) does not depend on it and may run first or in parallel.

**Tech Stack:** Markdown, `rg`, `sed`, git. No Scheme, no CMake.

## Global Constraints

- **Decision records follow the repo format**: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 6, Gate 0 (milestone-6-design.md §4.N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` and `docs/decisions/0027-reachable-path-for-callbacks-and-spans.md` are the house style — both are records about the same verifier machinery this record extends — and `docs/decisions/README.md` says what earns a record at all: *"Decisions that only restate the implementation plan do not need a record. These exist for choices a reader of the plan would otherwise have to reverse-engineer from the code."*
- **The next free decision number is 0030.** Measured 2026-09-06: `docs/decisions/` holds `0001`–`0029` contiguous plus `README.md`. Confirm with `ls docs/decisions/` before writing; if a higher number exists because a record landed from another branch, use the next free number and correct every cross-reference in the design (`rg -n 0030 docs/plans/milestone-6-design.md` lists them; measured at six lines on 2026-09-06).
- **Every date written in this phase is the literal date the task runs.** The record body below carries `2026-09-06`; if a task runs later, correct the `Date:` line and every dated note to the actual day. A dated note that lies about its day is worse than none — Milestone 5's completeness check found five tracked sites — three source comments and two decision-record headings — dated a day early against the merge that carried them.
- **Record vs instruction discipline** (`AGENTS.md`, *"Correct a stale instruction in place; annotate a stale record"*). A **record** — a measurement, a finding, a decision record's Context — gets a dated amendment note appended, never a rewrite. An **instruction** — a work order, a scope allocation, a live comment saying what code is for — is corrected in place. Task 2 amends a record by dated note and site marker, never by rewrite; Task 3 corrects instructions.
- **When a record reaches back into an earlier one, the TOP of the earlier record says so.** `docs/decisions/README.md` fixes both halves: a blockquote immediately after `Status:` and before `## Context` with **one bullet per amendment, in the order the notes appear**, each bullet opening with the note's own heading prefix verbatim and using the verb **amends** (a sentence above is now false) or **annotates** (nothing above became false). Task 2 reaches back and may not append a foot note without its top bullet.
- **Citation staleness.** Before writing any parent-plan sentence into the record, `sed -n` the line and read it. **Do not trust the quoted text in this plan or in the design as exact.** Every citation here was measured 2026-09-06 against `b470665`; nothing in this repository catches a stale citation, and Milestone 5 corrected fifty-five that were one line too high.
- **No code, no counts, no forecasts.** Gate 0 changes no `.sls`, no `.sps`, no CMake, no test. It does not touch `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (55 / 476 today, `test/support/cmake/SchemeMutationSuite.cmake`), quote them as predictions, or forecast a milestone total. The arms, the tag, the golden and the census rows are described as *obligations handed to Slice ①*, never performed here.
- **A record measures; it does not repeat.** Where the record states a fact about the tree — that the parked-set membership tests `(symbol? (node-eof-target n))`, that `eof-successors` is an alias for `zero-width-successors`, that `reexec-targets`' accumulate arm lists the overflow edge unconditionally — the task that writes it reads the construct at `HEAD` and cites it by name. Where it repeats a number from the design, it carries the qualifier that makes the number true.
- **The design document is the source of text.** The record is the durable form of `milestone-6-design.md` §4.1 and §4.2. Where this plan and the design differ, re-read the design and reconcile before writing; do not silently prefer one. **Where the design is *wrong*, stop and say so rather than encoding the error in a record** — Milestone 5's Gate 0 corrected three of the design's ten resolutions while writing them, every conclusion intact and every stated reason checked against the artifact.
- **Do not extend the parked set by kind, and do not argue the parked answer from prose.** The design's first draft put the kind into both `§16.2:909` disjunctions by kind; its review showed that unnecessary and an over-rejection, and the design now says why in one invariant: a parser parked on a non-entry counted consume by `need-input` holds a **positive** count (design §4.1's table leaves `current` on the node only in rows that leave the field positive; callbacks cannot write fields, `§13:801`; reset moves `current` to the entry), so its EOF behaviour from a parked state is its EOF route alone. The record's item 6 must state that invariant **against the runtime's arms as read at `HEAD`** — which arms return with `current` on the node and what the field holds when they do — not against the design's table, and must give both machines: the flow-through zero-count stop the join catches (REJECTED) and the one-shot "length, body, stop" grammar the withdrawn rule would have rejected (ACCEPTED). An argument from decision 0023's enumeration, in either direction, would be right for a false reason, which is the failure `AGENTS.md`'s review sentence exists to catch.
- **Do not narrow or defer a check on double-reporting grounds.** The parent plan's dispositions record that the "one finding per decision" rule cited against `§16.4:937-943` **does not exist** (`§Dated`, the Slice ⓪b disposition). No record written here may cite it.

## File Structure

**Created** — one record, self-contained and readable without the design document open:

| File | Responsibility | Source |
| --- | --- | --- |
| `docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md` | The executor contract (order of tests, count completion wins by construction, position kind) and the verifier rule (`next` is an EOF successor and a non-progress edge at a node the walk arrives at; a parked counted consume is classified from its EOF route), both from one fact | design §4.1, §4.2 |

**Modified:**

| File | Change | Task |
| --- | --- | --- |
| `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` | Dated note — item 3's closing clause, "with each node classified as itself", now has two exceptions: the callback node since Milestone 5 Slice ② (never recorded here) and the counted consume by `0030`, both because the state a parser is parked on and the name its EOF walk starts at are different questions. A record, **amended** at that clause, with a site marker under item 3 | 2 |
| `docs/plans/milestone-6-design.md` | §4's Gate-0-discharged blockquote; §9's first bullet gains the discharge note; §4.12 and §5 corrected in place if the owner's decision exists | 3 |

**Deliberately untouched.** Every `.sls` and `.sps`, every CMake file, `README.org`, `CHANGELOG.md`, and `docs/plans/byte-machine-implementation-plan.md` — `0030` changes no normative sentence of the parent plan, so unlike Milestone 5's Gate 0 it appends no disposition; the milestone's close-out (Slice ②) appends the `§25:1593-1609` disposition and the status surfaces move then. Design §3.2's five items are **recorded, not fixed, here**; each is Slice ①'s edit and Gate 0 owns only the reason.

---

## Task 1: Decision 0030 — Counted consume is input-reading with a zero-count route

**Files:**
- Create: `docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md`
- Test: none. Gate 0 is documentation; its verification is each task's `rg` step.

**Interfaces:**
- Consumes: decision 0023 item 3 (the parked set) and decision 0027 item 1 (the occupiable relation), both as **precedent** whose sentences stay true; decision 0021 item 3's loud-`else` discipline; `verify.sls`'s two parked-set disjunctions, `eof-successors`, `reexec-targets` and `classify`, each read at `HEAD`.
- Produces: Slice ①'s executor contract for both lanes, the `count-step` message shape, the four verifier arms the design's appendix marks **BOTH**, and `parked-eof-start`'s arm.

- [ ] **Step 1: Confirm the number is free and re-read the two source sections**

```bash
ls docs/decisions/
rg -n "^### 4\.1 |^### 4\.2 " docs/plans/milestone-6-design.md
```
Expected: no `0030-*` file exists, and the `rg` prints exactly two lines — design §4.1 and §4.2, this record's sources. Read both in full before writing, and read the design's appendix rows marked **BOTH**, which are the sites the record's Consequences must name.

- [ ] **Step 2: Verify the load-bearing citations against the plan, not against the design**

```bash
sed -n '600p;601p;602p;603p;604p' docs/plans/byte-machine-implementation-plan.md
sed -n '638p;642p;652p;654p;725p;771p;872p' docs/plans/byte-machine-implementation-plan.md
sed -n '898p;909p;1013p' docs/plans/byte-machine-implementation-plan.md
```
Expected, in order: `§10.6:600` contains "A zero count transitions immediately without consuming input"; `:601` contains "available bytes are consumed and the parser returns `need-input`"; `:602` contains "execution continues at the target with any remaining input"; `:603` contains "count completion wins"; `:604` contains "normal span fragment rules apply". Then `§11.1:638` contains "already-pending zero-width continuations"; `§11.2:642` contains "increments the cursor by one"; `§11.4:652` names "counted consumption" among the input-dependent kinds; `§11.4:654` is "Any reachable cycle that can run indefinitely without consuming input is invalid."; `§12.4:725` contains "Every input-dependent state uses either a state-specific EOF edge"; `§12.7:771` is the `eof` row; `§15:872` contains "exact subtraction after determining the number of bytes it can commit". Then `§16.2:898` is "reachable zero-progress cycles", `§16.2:909` the EOF-reachable-stop bullet, `§19.2:1013` the "available/count minimum" lowering. **If any line does not contain its phrase, stop and re-measure** — the record's ordering argument rests on `:600` and `:638` together, and its zero-progress argument on `:654`.

- [ ] **Step 3: Measure the verifier constructs the record describes**

```bash
rg -c "symbol\? \(node-eof-target n\)" src/byte-machine/verify.sls
rg -n "define \(eof-successors" src/byte-machine/verify.sls
rg -n -A3 "define \(parked\? " src/byte-machine/verify.sls
rg -n -A3 "define \(parked-eof-start" src/byte-machine/verify.sls
rg -c "\(\(integer-accumulate-node\? n\)" src/byte-machine/verify.sls
rg -n "NON-CONSUMING" src/byte-machine/verify.sls
rg -n "route-byte-step!|\(loop \(\+ pos 1\) 'boundary\)|\(loop pos 'byte\)" src/byte-machine/runtime.sls
```
Expected, as literals: the first prints **`2`** (the proxy at the `§16.2:909` set and at pass 7's `parked?`); the second prints one line, `(define (eof-successors n) (zero-width-successors n))`; the third shows `parked?`'s four disjuncts (entry, `pause-node?`, `callback-node?`, the proxy); the fourth shows `parked-eof-start` answering `(callback-node-pause-continuation n)` for a non-entry callback and `(node-name n)` otherwise — the construct the record extends; the fifth prints **`5`** (the accumulate arms across the file); the sixth prints **exactly one** line, inside `reexec-targets`' accumulate comment, which is the shape the record gives `next`; the seventh prints `route-byte-step!`'s definition and its two `loop` tails plus its call sites — read the feed loop's `accumulate` and `dispatch` arms around them, and confirm that every return with `current` left on an input-reading node is the `need-input` result at `(>= pos end)`, which is what makes the record's item 6 invariant a fact about the runtime and not about the design. **Record what you measure, not what this step says.**

- [ ] **Step 4: Write the record**

Create the file, following `0023`'s house style. Its `## Context` states the fact everything descends from — `§11.4:652` lists counted consume among the input-dependent kinds and `§10.6:600` gives it a transition that consumes nothing — and measures the tree: every per-kind analysis in `verify.sls` partitions kinds into two families and this is the first kind in both; the parked-set proxy at its two sites; `eof-successors`' alias. **Two decision groups, numbered continuously**, so a reader citing "item 4" is unambiguous:

*The executor contract* (design §4.1):

1. **The zero-count test precedes the exhausted-input test, in both lanes, during feed and during finish.** State the table's three rows verbatim from design §4.1 — `v = 0`; `v > 0, pos ≥ end`; `v > 0, pos < end, n = min(v, end − pos)` — and the derivation of the order from `§10.6:600`'s "immediately" and `§11.1:638`'s pending zero-width continuations. Say what the wrong order does: a zero count at the end of a slice returns `need-input`, and a zero count at `parser-finish!` is reported as a truncation.
2. **Count completion wins by construction.** The `n = v` test continues at the successor whether or not `pos + n = end`; `§10.6:603`'s exact case is the ordinary completion case with no input left. **State the symmetric wrong reading and why the differential cannot see it** — both lanes returning `need-input` first agree on every schedule — because that sentence is what makes design §7's placement oracle a value rather than an agreement.
3. **Position kind**: `boundary` after `n ≥ 1` committed bytes (`§11.2:642` applied `n` times); carried through unchanged after a zero-count transition, the shipped zero-width rule. Name the observable: an error node reached through a zero-count counted consume entered over a reexecute edge reports `byte`. Say that `§12.7:770` does not reach this kind because it has no failure of its own.
4. **The interpreter's message is `count-step`**, answering `(committed . target)`, committing the subtraction into the field vector; the finish path asks it over an empty slice and reads the target. One message per shape, on `accumulate-step`'s precedent. State the rejected alternative (a `count-zero?` message) and why (the answer shape already carries it).

*The verifier rule* (design §4.2):

5. **`next` is an EOF successor of the node, unconditionally**: `eof-successors` answers `(list next)` for the kind, and `classify`'s arm joins `dispatch-arm` over the eof-target with `join-over` the `eof-successors` — **written over the helper**, so `classify` and pass 7's `eof-step` read one fact. A stop behind the zero-count route is `eof-reachable-stop`; a cycle through `next` is `eof-zero-progress-cycle`.
6. **The parked set is unchanged; a parked counted consume is classified from its EOF route.** Neither `§16.2:909` disjunction gains a kind; `parked-eof-start` gains an arm answering a non-entry counted consume's eof-target, with the entry starting at itself. **The argument is an invariant measured against the runtime in Step 3**: only the `need-input` return leaves `current` on the node, it does so only with input exhausted and the count still positive (a zero count transitions away; a completing commit transitions away), fields are written by machine nodes only (`§13:801`) and reset moves `current` to the entry — so a parked non-entry counted consume takes its EOF route at `parser-finish!`, never `next`. Give both machines. The one the join (item 5) catches and a dispatch-shaped arm misses: the entry a counted consume with field initial `0`, `#f` eof-target and `next` a stop — `parser-finish!` on a fresh parser answers `stopped`; REJECTED with `eof-reachable-stop` at the entry, and the same shape through a pause continuation is reported at the pause. The one the withdrawn "parked by kind" rule would have rejected wrongly: `… →(byte) body (eof: an error; next: a stop)`, the one-shot "length, body, stop" grammar — ACCEPTED, because a parser parked on `body` holds a positive count and no EOF path reaches the stop. Say that the design's first draft had the wrong rule and that the review of that draft found it, so a later reader does not re-derive the withdrawn version from the draft's commit.
7. **`next` is a zero-progress edge, and the kind is in the REPORT set**, in one commit. `reexec-targets` answers `(list next)`, accumulate's overflow-edge shape. **State the over-rejection with the design's example** — `[branch zero? records → done] → consume(record-size) → decrement records → branch` is rejected although it terminates whenever `records` does — and the ground for accepting it, quoted exactly and not paraphrased: `§11.4:654` reads "Any reachable cycle that can run indefinitely without consuming input is invalid." The verifier cannot see that `records` decrements, so it cannot separate the loop that terminates from the one that runs indefinitely, and it rejects both — the conservatism it already applies to every value-terminated loop (`branch → decrement → branch` is a zero-progress cycle today). State the bound too: `§16.2:913`, "Normal consuming cycles, including the main HTTP message loop, are valid" — every loop `§21` needs carries an advancing dispatch and is untouched. The workaround is a byte-consuming node in the loop.

`## Consequences` must: name the **four** appendix constructs marked BOTH — `reexec-targets`, the zero-progress REPORT set, `classify`, `eof-successors` (and through it pass 7's `eof-step`) — plus `parked-eof-start`, and say that a slice filing the kind under "input-reading, like accumulate" gets exactly those four wrong, and one filing it under "parked, like a callback" gets `parked-eof-start` wrong in the other direction; state what does **not** change and why each is a derivation (`node-out-edges` gains a byte edge with role `next`, so `§16.2:908` sees a finish successor with no new code; both parked-set disjunctions keep their `symbol?` clause and gain nothing, a `#f` route being benign for a node whose parked count is positive; `span-transfer` is identity; `pass-declarations` owes nothing); hand Slice ① its fixtures by shape (the flow-through zero-count stop at the entry and through a pause continuation, both REJECTED; the one-shot "length, body, stop" grammar, ACCEPTED; the self-targeting `next`, `zero-progress-cycle` alone; the self-targeting eof-target, `eof-zero-progress-cycle`; the priced over-rejection of item 7 as an accept/reject pair); and record that the exact-case placement of the completion event is asserted as a **value per feed** in Slice ②, never as lane agreement.

- [ ] **Step 5: Verify and self-review**

```bash
f=docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md
rg -n "16\.4:937" "$f"
rg -c "symbol\? \(node-eof-target" "$f"
for c in reexec-targets REPORT classify eof-successors parked-eof-start; do printf '%s %s\n' "$c" "$(rg -c -F "$c" "$f")"; done
```
Expected: the first prints **nothing** (Global Constraints' last bullet); the second prints a count **≥ 1** (the proxy is named, not paraphrased); the third prints **five** lines, each ending in a count **≥ 1** (the four BOTH constructs and `parked-eof-start` are all named). Then re-read the record asking the one question this project's reviews keep earning: does every *reason* it gives survive a check against the artifact, or only its conclusions? In particular: item 6's reason is the runtime's arms as measured in Step 3, not the design's table and not 0023's prose; item 7's reason is `§11.4:654` as quoted, not the design's convenience.

- [ ] **Step 6: Commit**

Conventional Commits, `docs:`. The message states what was decided and the one thing a reader would otherwise reverse-engineer from the code: why a parked counted consume is classified from its EOF route while one the walk arrives at joins both routes, and why the zero-count test comes first.

---

## Task 2: Amend decision 0023 — item 3's "classified as itself" has two exceptions

**Files:**
- Modify: `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` (top bullet, site marker under item 3, **and** foot note)

**Interfaces:**
- Consumes: `0030` item 6.
- Produces: the pointer a reader arriving at 0023 item 3 by citation needs — that two kinds now start their EOF walk somewhere other than at themselves, one of them since Milestone 5 Slice ② without a note here.

- [ ] **Step 1: Read 0023's header block and item 3, and its existing note**

```bash
sed -n '1,20p' docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^\*\*3\. " docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^## 2026" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
```
Expected: an `Amendments` blockquote already exists with one bullet (2027's, dated 2026-09-04); the second `rg` prints **two** lines — a numbered measurement in `## Context` and item 3 in `## Decision`, which is the second and ends "with each node classified as *itself*"; one dated note exists at the foot. This task adds a **second** bullet, a site marker, and a **second** note; the README's invariant is "every dated note is named by a bullet", and its rule 2 puts a marker under an amended item.

- [ ] **Step 2: Add the top bullet, the site marker, then the foot note**

Verb: **amends item 3** — its closing clause, "with each node classified as itself", is false for two kinds. It became false in Milestone 5 Slice ②, when `parked-eof-start` began starting a byte-reachable callback's walk at its pause continuation, and no note recorded that; `0030` makes counted consume the second exception. Nothing else in item 3 changes: the set is still "the set of states an execution can be PARKED on", its enumeration still describes the shipped proxy, and both parked-set disjunctions are untouched.

```markdown
> - **2026-09-06 (Milestone 6)** — **amends item 3**: its closing clause, "with
>   each node classified as itself", has two exceptions. `parked-eof-start` has
>   started a byte-reachable callback's walk at its pause continuation since
>   Milestone 5 Slice ② (unrecorded here until now), and
>   [decision 0030](./0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
>   starts a parked counted consume's walk at its eof-target — in both cases
>   because the state a parser is parked on and the name its walk starts at are
>   different questions. The set itself is unchanged. See the foot of this file.
```

The site marker, a one-line blockquote directly under item 3 at its indentation and followed by a blank line (README, "Two mechanics that are easy to get wrong"): `> **Amended 2026-09-06 (Milestone 6)** by decision 0030 — "classified as itself" has two exceptions; see the dated note below. The sentence above is left as decided.`

The foot note, headed `## 2026-09-06 (Milestone 6) — …`, names `parked-eof-start` and quotes its own reason ("a state an execution can be parked on and the name the EOF walk starts at are two different questions"); states the counted-consume invariant from `0030` item 6 in one sentence and the machine it protects (the one-shot "length, body, stop" grammar, which a walk from the parked node joining over `next` would reject); records that the callback exception went unrecorded here for two slices and that this note is the first to say so; and says what does **not** move — the set's definition, its enumeration, and the `symbol?` proxy at both sites, which `0030` leaves as they are.

- [ ] **Step 3: Verify**

```bash
rg -n "^> - \*\*20" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^## 2026" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "Amended 2026-09-06" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
```
Expected: **two** bullets and **two** notes, dates matching pairwise (`2026-09-04`, `2026-09-06`), and **one** site-marker line, at a line number between item 3's and `## Consequences`. Then run the README's own check over the directory:

```bash
for f in docs/decisions/0*.md; do keys=$(sed -n '1,/^## /p' "$f" | sed -n '/^> - /p'); for d in $(rg -o '^## .*?(20[0-9]{2}-[0-9]{2}-[0-9]{2})' -r '$1' "$f" | sort -u); do case "$keys" in *"$d"*) ;; *) echo "$f: dated note $d has no bullet in the header block";; esac; done; done
```
Expected: **no output.**

- [ ] **Step 4: Commit**

---

## Task 3: Discharge the gate in the design document

**Files:**
- Modify: `docs/plans/milestone-6-design.md` (§4 heading block; §9's first bullet; §4.12 and §5 **only if** the owner's decision exists)

- [ ] **Step 1: Add the Gate-0-discharged mapping**

A blockquote under `## 4. Gate 0 — design-call resolutions`, recording that §4.1 and §4.2 are carried by `0030` **as performed**: if Task 1 split them, or corrected a stated reason while writing, the blockquote says so — that is the point of writing it after the fact, and Milestone 5's blockquote records three such corrections.

- [ ] **Step 2: Correct §9's first bullet in place**

It reads "Gate 0 is one record, `0030`, carrying §4.1 and §4.2 …" — an **instruction**, corrected in place to say the gate is discharged, with the record's title as shipped.

- [ ] **Step 3: If the owner has decided §4.12, record the decision**

Each item's leading **PROPOSED** becomes **APPROVED `<date>`** or **DECLINED `<date>`**, with the owner's stated reason if one was given; §5's first paragraph is corrected in place to name which items the slice carries, or to say the slice does not exist and the close-out defers both with named receivers. If no decision exists yet, leave §4.12 and §5 untouched and say so in the commit message — an approval invented here would be the failure Milestone 5's close-out recorded.

- [ ] **Step 4: Verify the whole gate**

```bash
ls docs/decisions/003*.md
rg -n "milestone-6-design.md §4" docs/decisions/003*.md
git diff --stat main..HEAD -- src/ test/ README.org CHANGELOG.md docs/plans/byte-machine-implementation-plan.md
```
Expected: one new record `0030`; its `Milestone:` line naming its design source; and **the third command prints nothing** — Gate 0 changes no product code, no test, no status surface and no parent-plan sentence, and this is the check that proves it.

- [ ] **Step 5: Commit**

---

## Verification

Gate 0 ships no test. Its verification is the per-task `rg` checks above plus one whole-gate review, and the review's prompt carries this sentence from `AGENTS.md` verbatim:

> check what this claims the code or the spec DOES against the code and the spec, not against the prose

Milestone 4's Gate 0 shipped **three false supporting reasons across five records**, two originating in its design; Milestone 5's Gate 0 corrected three of ten resolutions' stated reasons while writing them, every conclusion intact. This gate has two resolutions and two places a false reason can hide: item 6, which is right only if the runtime leaves `current` on a counted consume solely with a positive count (Step 3 of Task 1 measures the arms that return with `current` on an input-reading node); and item 7, which is right only if `§11.4:654` says what the record says it says (Step 2 measures it).

**A record whose stated reason survives that check is discharged. A record whose reason is false is rewritten even when its decision is right.**
