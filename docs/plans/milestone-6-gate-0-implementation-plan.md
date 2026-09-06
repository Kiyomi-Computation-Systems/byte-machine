# Milestone 6 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as one durable record — `0030` — the two design calls Milestone 6 depends on, so that Slice ① cites a decision instead of re-deriving it. Both are externally observable: `0030`'s executor contract decides *which feed* a span's completion event lands in for every schedule, and its verifier rule decides which diagnostic a fixture emits for a stop behind a zero-count route. A slice that picks either by accident pins the wrong answer in a fixture, and the fixture then defends it.

**Architecture:** This phase writes *documentation only* — no product code, no tests, no CMake. It produces one new decision record, one dated annotation on an existing record, and the Gate-0-discharged mapping in the design document. It is the prerequisite for Slice ①, which implements every item of `0030` in one commit; Slice ⓪ (if the owner approves `milestone-6-design.md` §4.12) does not depend on it and may run first or in parallel.

**Tech Stack:** Markdown, `rg`, `sed`, git. No Scheme, no CMake.

## Global Constraints

- **Decision records follow the repo format**: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 6, Gate 0 (milestone-6-design.md §4.N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` and `docs/decisions/0027-reachable-path-for-callbacks-and-spans.md` are the house style — both are records about the same verifier machinery this record extends — and `docs/decisions/README.md` says what earns a record at all: *"Decisions that only restate the implementation plan do not need a record. These exist for choices a reader of the plan would otherwise have to reverse-engineer from the code."*
- **The next free decision number is 0030.** Measured 2026-09-06: `docs/decisions/` holds `0001`–`0029` contiguous plus `README.md`. Confirm with `ls docs/decisions/` before writing; if a higher number exists because a record landed from another branch, use the next free number and correct every cross-reference in the design (`0030` appears in its §1 table, §4 preamble and §10).
- **Every date written in this phase is the literal date the task runs.** The record body below carries `2026-09-06`; if a task runs later, correct the `Date:` line and every dated note to the actual day. A dated note that lies about its day is worse than none — Milestone 5's completeness check found five source sites dated a day early against the merge that carried them.
- **Record vs instruction discipline** (`AGENTS.md`, *"Correct a stale instruction in place; annotate a stale record"*). A **record** — a measurement, a finding, a decision record's Context — gets a dated amendment note appended, never a rewrite. An **instruction** — a work order, a scope allocation, a live comment saying what code is for — is corrected in place. Task 2 annotates a record; Task 3 corrects instructions.
- **When a record reaches back into an earlier one, the TOP of the earlier record says so.** `docs/decisions/README.md` fixes both halves: a blockquote immediately after `Status:` and before `## Context` with **one bullet per amendment, in the order the notes appear**, each bullet opening with the note's own heading prefix verbatim and using the verb **amends** (a sentence above is now false) or **annotates** (nothing above became false). Task 2 reaches back and may not append a foot note without its top bullet.
- **Citation staleness.** Before writing any parent-plan sentence into the record, `sed -n` the line and read it. **Do not trust the quoted text in this plan or in the design as exact.** Every citation here was measured 2026-09-06 against `b470665`; nothing in this repository catches a stale citation, and Milestone 5 corrected fifty-five that were one line too high.
- **No code, no counts, no forecasts.** Gate 0 changes no `.sls`, no `.sps`, no CMake, no test. It does not touch `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (55 / 476 today, `test/support/cmake/SchemeMutationSuite.cmake`), quote them as predictions, or forecast a milestone total. The arms, the tag, the golden and the census rows are described as *obligations handed to Slice ①*, never performed here.
- **A record measures; it does not repeat.** Where the record states a fact about the tree — that the parked-set membership tests `(symbol? (node-eof-target n))`, that `eof-successors` is an alias for `zero-width-successors`, that `reexec-targets`' accumulate arm lists the overflow edge unconditionally — the task that writes it reads the construct at `HEAD` and cites it by name. Where it repeats a number from the design, it carries the qualifier that makes the number true.
- **The design document is the source of text.** The record is the durable form of `milestone-6-design.md` §4.1 and §4.2. Where this plan and the design differ, re-read the design and reconcile before writing; do not silently prefer one. **Where the design is *wrong*, stop and say so rather than encoding the error in a record** — Milestone 5's Gate 0 corrected three of the design's ten resolutions while writing them, every conclusion intact and every stated reason checked against the artifact.
- **Do not argue "parked by kind" from decision 0023's words.** 0023 item 3 says the parked set is "the entry, every byte-reachable pause, and every byte-reachable node carrying its own EOF route" — and a counted consume with a `#f` eof-target *does* carry a route, the default one, so 0023's sentence admits it. What excludes it is the **code's proxy** for that sentence, `(symbol? (node-eof-target n))`, at two sites. The record's argument must name the proxy and the machine it admits wrongly, measured; an argument from 0023's prose would be right for a false reason, which is the failure `AGENTS.md`'s review sentence exists to catch.
- **Do not narrow or defer a check on double-reporting grounds.** The parent plan's dispositions record that the "one finding per decision" rule cited against `§16.4:937-943` **does not exist** (`§Dated`, the Slice ⓪b disposition). No record written here may cite it.

## File Structure

**Created** — one record, self-contained and readable without the design document open:

| File | Responsibility | Source |
| --- | --- | --- |
| `docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md` | The executor contract (order of tests, count completion wins by construction, position kind) and the verifier rule (`next` is an EOF successor and a non-progress edge; the node is parked by kind), both from one fact | design §4.1, §4.2 |

**Modified:**

| File | Change | Task |
| --- | --- | --- |
| `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` | Dated note — the parked set gains a member by **kind**, because the shipped proxy for item 3's "carrying its own EOF route" is a `symbol?` test that the new kind's `#f` route fails while its zero-count route can still reach a stop. A record, **annotated**: nothing 0023 says becomes false | 2 |
| `docs/plans/milestone-6-design.md` | §4's Gate-0-discharged blockquote; §10's first bullet gains the discharge note; §4.12 and §5 corrected in place if the owner's decision exists | 3 |

**Deliberately untouched.** Every `.sls` and `.sps`, every CMake file, `README.org`, `CHANGELOG.md`, and `docs/plans/byte-machine-implementation-plan.md` — `0030` changes no normative sentence of the parent plan, so unlike Milestone 5's Gate 0 it appends no disposition; the milestone's close-out (Slice ②) appends the `§25:1593-1609` disposition and the status surfaces move then. Design §3.2's four items are **recorded, not fixed, here**; each is Slice ①'s edit and Gate 0 owns only the reason.

---

## Task 1: Decision 0030 — Counted consume is input-reading with a zero-count route

**Files:**
- Create: `docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md`
- Test: none. Gate 0 is documentation; its verification is each task's `rg` step.

**Interfaces:**
- Consumes: decision 0023 item 3 (the parked set) and decision 0027 item 1 (the occupiable relation), both as **precedent** whose sentences stay true; decision 0021 item 3's loud-`else` discipline; `verify.sls`'s two parked-set disjunctions, `eof-successors`, `reexec-targets` and `classify`, each read at `HEAD`.
- Produces: Slice ①'s executor contract for both lanes, the `count-step` message shape, and the six verifier arms the design's appendix marks **BOTH**.

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
rg -n "symbol\? \(node-eof-target n\)" src/byte-machine/verify.sls
rg -n "define \(eof-successors" src/byte-machine/verify.sls
rg -n -A3 "define \(parked\? " src/byte-machine/verify.sls
rg -n -B2 -A4 "\(\(integer-accumulate-node\? n\)" src/byte-machine/verify.sls
```
Expected: the first prints **exactly two** lines — the `§16.2:909` parked-set disjunction inside `pass-eof-execution` and pass 7's `parked?` — and both are the proxy the record names; the second prints one line defining `eof-successors` as `(zero-width-successors n)`, the alias the record extends; the third shows `parked?`'s four disjuncts (entry, `pause-node?`, `callback-node?`, the proxy); the fourth prints the accumulate arms — read the one inside `reexec-targets`, whose comment says the overflow edge "joins unconditionally" because it is "NON-CONSUMING", which is the shape the record gives `next`. **Record what you measure, not what this step says** — the line count in the first command is the record's Context.

- [ ] **Step 4: Write the record**

Create the file, following `0023`'s house style. Its `## Context` states the fact everything descends from — `§11.4:652` lists counted consume among the input-dependent kinds and `§10.6:600` gives it a transition that consumes nothing — and measures the tree: every per-kind analysis in `verify.sls` partitions kinds into two families and this is the first kind in both; the parked-set proxy at its two sites; `eof-successors`' alias. **Two decision groups, numbered continuously**, so a reader citing "item 4" is unambiguous:

*The executor contract* (design §4.1):

1. **The zero-count test precedes the exhausted-input test, in both lanes, during feed and during finish.** State the table's three rows verbatim from design §4.1 — `v = 0`; `v > 0, pos ≥ end`; `v > 0, pos < end, n = min(v, end − pos)` — and the derivation of the order from `§10.6:600`'s "immediately" and `§11.1:638`'s pending zero-width continuations. Say what the wrong order does: a zero count at the end of a slice returns `need-input`, and a zero count at `parser-finish!` is reported as a truncation.
2. **Count completion wins by construction.** The `n = v` test continues at the successor whether or not `pos + n = end`; `§10.6:603`'s exact case is the ordinary completion case with no input left. **State the symmetric wrong reading and why the differential cannot see it** — both lanes returning `need-input` first agree on every schedule — because that sentence is what makes design §7's placement oracle a value rather than an agreement.
3. **Position kind**: `boundary` after `n ≥ 1` committed bytes (`§11.2:642` applied `n` times); carried through unchanged after a zero-count transition, the shipped zero-width rule. Name the observable: an error node reached through a zero-count counted consume entered over a reexecute edge reports `byte`. Say that `§12.7:770` does not reach this kind because it has no failure of its own.
4. **The interpreter's message is `count-step`**, answering `(committed . target)`, committing the subtraction into the field vector; the finish path asks it over an empty slice and reads the target. One message per shape, on `accumulate-step`'s precedent. State the rejected alternative (a `count-zero?` message) and why (the answer shape already carries it).

*The verifier rule* (design §4.2):

5. **`next` is an EOF successor of the node, unconditionally**: `eof-successors` answers `(list next)` for the kind, and `classify`'s arm joins `dispatch-arm` over the eof-target with `join-over` the `eof-successors` — **written over the helper**, so `classify` and pass 7's `eof-step` read one fact. A stop behind the zero-count route is `eof-reachable-stop`; a cycle through `next` is `eof-zero-progress-cycle`.
6. **The node is parked by kind.** Both `§16.2:909` disjunctions gain `(counted-consume-node? n)` as their own disjunct. **The argument is the proxy, measured in Step 3, and the machine it admits wrongly**: a `#f` eof-target, a zero count, and a `next` naming a stop verifies clean under the proxy and answers `stopped` from `parser-finish!`. Say plainly that decision 0023 item 3's *sentence* admits the node ("carrying its own EOF route" — the default is a route) and that only the code's `symbol?` test does not; this record corrects the code's reading and leaves 0023's words standing (Task 2's note).
7. **`next` is a zero-progress edge, and the kind is in the REPORT set**, in one commit. `reexec-targets` answers `(list next)`, accumulate's overflow-edge shape. **State the over-rejection with the design's example** — `[branch zero? records → done] → consume(record-size) → decrement records → branch` is rejected although it terminates whenever `records` does — and the ground for accepting it: `§11.4:654` forbids a cycle that *can* run without consuming input, the verifier already rejects every value-terminated loop, and the workaround is a byte-consuming node in the loop.

`## Consequences` must: name the **six** appendix constructs marked BOTH — `reexec-targets`, the zero-progress REPORT set, `classify`, `pass-eof-execution`'s parked-set membership, `eof-successors` (and through it pass 7's `eof-step`), pass 7's `parked?` — and say that a slice filing the kind under "input-reading, like accumulate" gets exactly those six wrong and nothing else; state what does **not** change and why each is a derivation (`node-out-edges` gains a byte edge with role `next`, so `§16.2:908` sees a finish successor with no new code; `span-transfer` is identity; `pass-declarations` owes nothing); hand Slice ① its fixtures by shape (the zero-count-route stop with a `#f` eof-target, asserted REJECTED; the self-targeting `next`, both cycles; the priced over-rejection as an accept/reject pair); and record that the exact-case placement of the completion event is asserted as a **value per feed** in Slice ②, never as lane agreement.

- [ ] **Step 5: Verify and self-review**

```bash
rg -n "16\.4:937" docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md
rg -c "symbol\? \(node-eof-target" docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md
rg -n "reexec-targets|REPORT|classify|parked-set|eof-successors|parked\?" docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md | wc -l
```
Expected: the first prints **nothing** (Global Constraints' last bullet); the second prints a count **≥ 1** (the proxy is named, not paraphrased); the third prints a count **≥ 6** (all six BOTH constructs are named). Then re-read the record asking the one question this project's reviews keep earning: does every *reason* it gives survive a check against the artifact, or only its conclusions? In particular: item 6's reason is the code's proxy, not 0023's prose; item 7's reason is `§11.4:654`, not the design's convenience.

- [ ] **Step 6: Commit**

Conventional Commits, `docs:`. The message states what was decided and the one thing a reader would otherwise reverse-engineer from the code: why a kind with its own EOF route is nonetheless a parked state by kind, and why the zero-count test comes first.

---

## Task 2: Annotate decision 0023 — the parked set gains a member by kind

**Files:**
- Modify: `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` (top bullet **and** foot note)

**Interfaces:**
- Consumes: `0030` item 6.
- Produces: the pointer a reader arriving at 0023 item 3 by citation needs — that the parked set now has a member the item's own proxy in code would have excluded.

- [ ] **Step 1: Read 0023's header block and item 3, and its existing note**

```bash
sed -n '1,20p' docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^\*\*3\. " docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^## 2026" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
```
Expected: an `Amendments` blockquote already exists with one bullet (2027's, dated 2026-09-04); item 3 reads "the set of states an execution can be PARKED on — the entry, every byte-reachable pause, and every byte-reachable node carrying its own EOF route"; one dated note exists at the foot. This task adds a **second** bullet and a **second** note; the README's invariant is "every dated note is named by a bullet".

- [ ] **Step 2: Add the top bullet, then the foot note**

Verb: **annotates** — nothing 0023 says becomes false. Item 3's words admit the new kind; what did not was the shipped `symbol?` proxy for those words, and `0030` corrects the proxy, not the sentence.

```markdown
> - **2026-09-06 (Milestone 6)** — **annotates item 3**: the parked set gains a
>   member by KIND. Counted consume carries its own EOF route as item 3 says, but
>   the shipped proxy for "carrying its own EOF route" is a `symbol?` test its
>   `#f` route fails, while its zero-count route can still reach a stop.
>   [Decision 0030](./0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
>   adds the kind as its own disjunct at both sites. See the foot of this file.
```

The foot note, headed `## 2026-09-06 (Milestone 6) — …`, states the proxy by construct name at both sites, the machine it admits wrongly (from `0030` item 6), and that item 3's sentence stands: the correction is to the code's reading of it. It also carries what this record did not predict, in the shape 0027's own Slice ③ note used: item 3 fixes the parked set's *members* and the code chose a *proxy* for one clause; the proxy was exact for every kind whose `#f` route is the whole of its EOF behaviour, and counted consume is the first kind for which it is not.

- [ ] **Step 3: Verify**

```bash
rg -n "^> - \*\*20" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^## 2026" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
```
Expected: **two** bullets and **two** notes, dates matching pairwise (`2026-09-04`, `2026-09-06`). Then run the README's own check over the directory:

```bash
for f in docs/decisions/0*.md; do keys=$(sed -n '1,/^## /p' "$f" | sed -n '/^> - /p'); for d in $(rg -o '^## .*?(20[0-9]{2}-[0-9]{2}-[0-9]{2})' -r '$1' "$f" | sort -u); do case "$keys" in *"$d"*) ;; *) echo "$f: dated note $d has no bullet in the header block";; esac; done; done
```
Expected: **no output.**

- [ ] **Step 4: Commit**

---

## Task 3: Discharge the gate in the design document

**Files:**
- Modify: `docs/plans/milestone-6-design.md` (§4 heading block; §10's first bullet; §4.12 and §5 **only if** the owner's decision exists)

- [ ] **Step 1: Add the Gate-0-discharged mapping**

A blockquote under `## 4. Gate 0 — design-call resolutions`, recording that §4.1 and §4.2 are carried by `0030` **as performed**: if Task 1 split them, or corrected a stated reason while writing, the blockquote says so — that is the point of writing it after the fact, and Milestone 5's blockquote records three such corrections.

- [ ] **Step 2: Correct §10's first bullet in place**

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

Milestone 4's Gate 0 shipped **three false supporting reasons across five records**, two originating in its design; Milestone 5's Gate 0 corrected three of ten resolutions' stated reasons while writing them, every conclusion intact. This gate has two resolutions and two places a false reason can hide: item 6, which is right only if the proxy is what the code tests (Step 3 of Task 1 measures it); and item 7, which is right only if `§11.4:654` says what the record says it says (Step 2 measures it).

**A record whose stated reason survives that check is discharged. A record whose reason is false is rewritten even when its decision is right.**
