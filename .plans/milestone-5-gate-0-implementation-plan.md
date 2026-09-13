# Milestone 5 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as durable records, the ten design calls Milestone 5 depends on — merged into **six** records, `0024`–`0029` — so that every later slice cites a decision instead of re-deriving it. Four of the ten are externally observable through the IR fingerprint, the emitted text, or a diagnostic's identity, and a slice that picks one by accident pins the wrong answer in a golden.

**Architecture:** This phase writes *documentation only* — no product code, no tests, no CMake. It produces six new decision records and the Gate-0-discharged mapping in the design document. It is the prerequisite for all five Milestone 5 slices: Slice ①a consumes 0025; ①b consumes 0025 and 0028; ② consumes 0024, 0027 and 0028; ③ consumes 0026, 0027 and 0029; ④ consumes 0024. No slice may begin before its records exist, because each record's Consequences section is what removes work the slice would otherwise re-derive.

**Tech Stack:** Markdown, `rg`, git. No Scheme, no CMake.

## Global Constraints

- **Decision records follow the repo format**: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 5, Gate 0 (milestone-5-design.md §4.N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. See `.decisions/0023-eof-walk-starts-and-finish-reachability.md` and `.decisions/0021-eof-classification-multi-successor.md` for the house style, and `.decisions/README.md` for what earns a record at all — *"Decisions that only restate the implementation plan do not need a record. These exist for choices a reader of the plan would otherwise have to reverse-engineer from the code."*
- **The next free decision number is 0024.** Measured 2026-09-04: `.decisions/` holds `0001`–`0023` contiguous plus `README.md`. Confirm with `ls .decisions/` before writing; if a higher number exists because a record landed from another branch, use the next free numbers in order and renumber the cross-references between these six records to match.
- **Every date written in this phase is the literal date the task runs.** The record bodies below carry `2026-09-04`; if a task runs later, correct the `Date:` line and every dated note to the actual day. A dated note that lies about its day is worse than none.
- **Record vs instruction discipline** (`AGENTS.md`, *"Correct a stale instruction in place; annotate a stale record"*). A **record** — a measurement, a finding, a decision record's Context — gets a dated amendment note appended, never a rewrite, because a record edited to agree with a later decision stops being evidence of anything. An **instruction** — a work order, an exit criterion, a normative spec sentence, or a live comment saying what code is for — is corrected in place, because leaving a false one is a landmine and what it used to say is in git.
- **When a record reaches back into an earlier one, the TOP of the earlier record says so.** `.decisions/README.md` fixes both halves: a `Superseded:` line in the `Status:` block for a whole record, or a blockquote immediately after `Status:` and before `## Context` with **one bullet per amendment, in the order the notes appear**, each bullet opening with the note's own heading prefix verbatim and using the verb **amends** (a sentence above is now false) or **annotates** (nothing above became false). Task 2 and Task 4 both reach back; neither may append a foot note without its top bullet.
- **Citation staleness.** Before editing any parent-plan or source sentence, `rg` for it and read the surrounding lines to confirm the *current* wording at `HEAD`. **Do not trust the quoted "current text" in this plan as exact.** Every citation here was measured 2026-09-04 against `9d320d8`; line numbers and phrasing drift, and this repository has no tool that catches a stale citation.
- **No code, no counts, no forecasts.** Gate 0 changes no `.sls`, no `.sps`, no CMake, no test. It does not touch `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (52 passes / 376 mutations today), quote them as predictions, or forecast a milestone total. The node kinds, the verifier passes, the lowering and the ABI edit are described as *obligations handed to the slices*, never performed here.
- **A record measures; it does not repeat.** Where a record states a number about the tree, that number is measured by the task that writes it, against the shipped tree, and cited. Where it repeats a number from elsewhere, it carries the qualifier that makes the number true.
- **The design document is the source of text.** Each record below is the durable form of one or more `milestone-5-design.md` §4 subsections. Where this plan and the design differ, re-read the design and reconcile before writing; do not silently prefer one. **Where the design is *wrong*, stop and say so rather than encoding the error in a record** — the design's own §4.3, §4.6 and §4.12 item 4 were corrected after review for exactly this, and the Amendments block records it.
- **Do not narrow or defer a check on double-reporting grounds.** Design §3 records that two `verify.sls` comments cite `§16.4:937-943` for a "one finding per decision" rule the parent plan's dispositions state *does not exist* (`§Dated:1904-1907`). No record written here may cite that rule.

## File Structure

**Created** — six records, each self-contained and readable without the design document open:

| File | Responsibility | Source |
| --- | --- | --- |
| `.decisions/0024-callback-error-vocabulary.md` | A callback-contract error is a `callback`-domain parser error with a minted code and a fixed static reason — not a raise, not poison | design §4.1, §4.2 |
| `.decisions/0025-milestone-5-seam-encoding-abi-exec.md` | The seam paid once: slot tables as an optional trailing section, the ABI payload's second member, `exec`'s new parameters, `current-abi-version` 3→4 | design §4.3, §4.8 |
| `.decisions/0026-internal-state-id-order.md` | `0016`'s phase two gains one merged pre-order over declaring nodes; one internal state per resumable substep | design §4.4 |
| `.decisions/0027-reachable-path-for-callbacks-and-spans.md` | "Reachable path" is byte-reachability plus the EOF walk, and `pass-zero-progress` gains the gate `§16.2:898` already requires | design §4.5 |
| `.decisions/0028-callback-slots-and-visible-state.md` | What occupies an unbound optional callback's slot, which accessors answer during `busy`, and `parser-active-span` | design §4.6, §4.9, §4.10 |
| `.decisions/0029-span-state-is-a-lattice.md` | The span pass is a dataflow analysis; disagreement at a merge point is itself a diagnostic | design §4.7 |

**Modified:**

| File | Change | Task |
| --- | --- | --- |
| `.decisions/0019-encoding-format-2-pre-provisioned.md` | Dated note — its three reserved slots were **all spent inside Milestone 4**, and `0025` reserves *again* on this item's precedent rather than drawing on it. A record, **annotated**: nothing 0019 says becomes false | 2 |
| `.decisions/0023-eof-walk-starts-and-finish-reachability.md` | Dated note — `0027` generalizes its reachability answer from the EOF checks to the span and callback restrictions. A record, **annotated** | 4 |
| `.plans/byte-machine-implementation-plan.md` | One appended disposition: `§9.3`'s normative accessor list gains `parser-active-span`. **Appended to `## Dated dispositions`, never inlined** — an insertion into the body re-numbers every `§section:line` citation below it (`§Dated:1804-1810`) | 5 |
| `.plans/milestone-5-design.md` | §4's Gate-0-discharged mapping; §11's first bullet gains the discharge note | 7 |

**Deliberately untouched.** Every `.sls` and `.sps`, every CMake file, `README.org` and `CHANGELOG.md` — the milestone's status surfaces move when the milestone *closes*, not when Gate 0 discharges. Design §3.2's four spec-vs-tree divergences are **recorded, not fixed, here**; each is a slice's edit and Gate 0 owns only the reason.

---

## Task 1: Decision 0024 — The callback error vocabulary

**Files:**
- Create: `.decisions/0024-callback-error-vocabulary.md`
- Test: none. Gate 0 is documentation; its verification is each task's `rg` step.

**Interfaces:**
- Consumes: nothing — first record of the milestone.
- Produces: the `callback` error domain, **one minted code** (for an out-of-contract return) plus the **pass-through** of the application's own code from `make-callback-failure`, and the fixed static reason. `§13:808` gives the explicit failure "an application code and optional detail" and `§9.3:423` requires a symbolic code, so discarding it would make a required constructor parameter unobservable. Slice ② implements it; Slice ④'s retention oracle depends on the detail slot it creates.

- [ ] **Step 1: Confirm the number is free and re-read the source sections**

```bash
ls .decisions/
rg -n "^### 4\.1 |^### 4\.2 " .plans/milestone-5-design.md
```
Expected: no `0024-*` file exists, and the `rg` prints exactly two lines — design §4.1 and §4.2, this record's sources. Read both in full before writing.

- [ ] **Step 2: Verify the three load-bearing citations against the plan, not against the design**

```bash
sed -n '586p;749p;775p;530p;438p' .plans/byte-machine-implementation-plan.md
```
Expected, in order: `§10.6:586` contains "Unknown results are runtime callback-contract errors"; `§12.6:749` contains "If a callback raises an unexpected condition or performs a nonlocal escape"; `§12.7:775` is the sentence putting data errors in results; `§10.5:530` contains "Callback application failures occupy a separate runtime error domain"; `§9.4:438` is the API-condition code list. **If any line does not contain its phrase, stop and re-measure** — the record's whole argument is that poisoning's triggers are a *closed pair* and that the API-condition list has no callback-contract entry.

- [ ] **Step 3: Write the record**

Create `.decisions/0024-callback-error-vocabulary.md`, following the house style of `0023`. Its `## Context` states the gap: `rg -n 'callback-contract'` over the parent plan returns exactly one hit, `§10.6:586`, which names the error and assigns it no domain, no code and no channel. Its `## Decision` is numbered and must carry:

1. A callback-contract error is a **stored parser error in a `callback` domain**, reported through the ordinary error-result path.
2. It **does not poison**. `§12.6:749`'s triggers are a closed pair — a raise and a nonlocal escape — and a wrong return value is neither. Extending poisoning to cover it would widen a closed enumeration by inference.
3. It is **not** an API condition — but **do not argue this from absence.** `§9.4:438` opens with the words "Codes include", an explicitly open enumeration, so nothing can be ruled out by not appearing in it. Argue it positively from `§12.3:719`: "The machine entered a declared machine error or callback application error. The status is sticky until reset." That sentence already puts this family on the sticky error *result* channel by name. The `§9.4:438` absence may be cited as corroboration, labelled as corroboration. **Note also** that `:438`'s nearest-looking entry, "callback binding error", is construction-time (`§9.3:419`) and a reviewer will otherwise raise it against a bare "no entry" claim.
4. An explicit `make-callback-failure` outcome and an out-of-contract return share the domain and take **different codes** — the application's, passed through, and a minted one respectively. State the limit honestly: nothing in `§9.3:423`'s grammar reserves the minted symbol, so an application that deliberately returns it is indistinguishable, and no check can see that.
5. The `reason` is **one fixed printable-ASCII constant**, identical in both lanes. `§12.7:757` calls reason *static*, which rules out `#f`; rendering the code's printed form would put a symbol's external representation into a behavioural contract.

`## Consequences` must state: both codes are differential fixtures, not unit tests, because `§12.7:777` compares five values across lanes — source-node name, domain, code, offset, position kind. And it must state what the record **hands to Slice ④**: the detail slot this creates is application data that `§13:799` explicitly permits to retain the input bytevector, so the retention oracle must exclude it alongside user context. That sentence is the deferral's second end.

- [ ] **Step 4: Verify and self-review**

```bash
rg -n "callback-contract" .decisions/0024-callback-error-vocabulary.md
rg -n "16\.4:937" .decisions/0024-callback-error-vocabulary.md
```
Expected: the first prints at least one line; **the second prints nothing** (Global Constraints' last bullet). Then re-read the record asking the one question this project's reviews keep earning: does every *reason* it gives survive a check against the artifact, or only its conclusions?

- [ ] **Step 5: Commit**

Conventional Commits, `docs:`. The message states what was decided and the one thing a reader would otherwise reverse-engineer: why a wrong return value does not poison.

---

## Task 2: Decision 0025 — The Milestone 5 seam, paid once

**Files:**
- Create: `.decisions/0025-milestone-5-seam-encoding-abi-exec.md`
- Modify: `.decisions/0019-encoding-format-2-pre-provisioned.md` (top bullet **and** foot note)

**Interfaces:**
- Consumes: `0019`, **as precedent, not as a slot**. Measured: all three of its reserved slots were filled inside Milestone 4, and three in-tree comments name the slice that filled each (`normal-ir.sls:474`, `compile.sls:504`, `compile.sls:63-64`). This record reserves again and pays its own re-baseline.
- Produces: Slice ①a's entire work list and its two-sided oracle.

- [ ] **Step 1: Confirm the number and re-read both sources**

```bash
rg -n "^### 4\.3 |^### 4\.8 " .plans/milestone-5-design.md
sed -n '114,130p' .decisions/0019-encoding-format-2-pre-provisioned.md
```
Expected: two design subsections, and 0019's item 3 listing its three reserved slots — (a) the encoding's field table, (b) the ABI payload's field-initials member, (c) emitted `exec`'s seventh parameter. **Read item 3 in full.** The design's §4.3 was corrected after review for getting this wrong: only (a) was ever in the *header*.

- [ ] **Step 2: Measure the seam yourself**

```bash
sed -n '465,467p' src/byte-machine/private/normal-ir.sls
sed -n '61p;79p;84p' src/byte-machine/runtime.sls
rg -n "define \(exec " src/byte-machine/compile.sls
grep -n "byte-machine-make-compiled-machine" test/fixtures/*.golden.sls
```
Expected: the header layout comment; `current-abi-version` 3, the strict `(= abi-version current-abi-version)` guard at `:79`, and the metadata `>= 1` **length** check at `:84`; the **seven**-parameter `exec` template (six plus `fieldv`, which decision 0019 item 3(c) added); and four goldens each carrying a literal ABI `3`. **Record the numbers you measure, not the ones written here** — two of the values in this very sentence were wrong on first writing.

- [ ] **Step 3: Write the record**

`## Decision`, numbered:

1. **The callback and span slot tables encode as an optional trailing section, present only when nonempty.** The header does not grow. A machine declaring neither encodes byte-identically to today.
2. **`current-abi-version` goes 3→4**, and the ABI payload gains a second member, empty. `§9.5:444` forces the bump; the strict equality at `runtime.sls:79` is what enforces it. **State plainly that the `>= 1` at `runtime.sls:84` is the metadata *length* check and enforces nothing about the version** — the design records that an earlier draft conflated them, and a record that repeats the conflation re-creates it.
3. **Emitted `exec` gains the parser handle and the callback slot vector, reserved and unused**, on `0019` item 3(c)'s precedent. `§13:784` makes the parser a callback's first argument, so `exec` must receive one.
4. **All of this lands in Slice ①a, before any semantics**, so every later slice can assert "no golden moved" as a gate rather than a hope.

`## Consequences` states the two-sided oracle *as the design states it, including the correction*: the four goldens **do** move — they are emitted text, two lines each — and what must be **unchanged** is every fingerprint. Say why that is the sharper assertion: an empty diff cannot fail, a moved fingerprint can.

Argue point 1 from precedent and **say it is precedent, not proof**: `test/common/normal-ir-tests.sps:173` is about a *field name*, not a declaration table, so it establishes that declaration identity is fingerprint-visible rather than forbidding the alternative.

- [ ] **Step 4: Annotate 0019 — top bullet first, then the foot note**

Add the blockquote bullet after `0019`'s `Status:` block (create the blockquote if absent), then the foot note. Verb: **annotates** — nothing 0019 says becomes false. Its item 3 named where each slot would be filled and each *was* filled as named, inside Milestone 4. The note records that the slots are exhausted and that `0025` reserves again on the precedent.

```markdown
> - **2026-09-04 (Milestone 5)** — **annotates item 3**: all three reserved slots
>   are spent, and Milestone 4 spent them.
>   [Decision 0025](../.decisions/0025-milestone-5-seam-encoding-abi-exec.md) reserves again
>   on this item's precedent rather than drawing on it.
```

- [ ] **Step 5: Verify and self-review**

```bash
rg -n "^> - \*\*20" .decisions/0019-encoding-format-2-pre-provisioned.md
rg -n "^## 2026-09-04" .decisions/0019-encoding-format-2-pre-provisioned.md
```
Expected: the bullet count is **≥** the foot-note count for this date (`README.md`: "bullets may outnumber notes, never the reverse"). A foot note with no bullet is the defect this check exists for.

- [ ] **Step 6: Commit**

---

## Task 3: Decision 0026 — Internal state ids interleave by declaring-node order

**Files:**
- Create: `.decisions/0026-internal-state-id-order.md`

**Interfaces:**
- Consumes: `0016`, whose item 1 pins the order for one family of internal states.
- Produces: the total order Slice ③'s lowering must implement, and the substep granularity.

- [ ] **Step 1: Read 0016's item 1 in full, and §17:955**

```bash
sed -n '23,33p' .decisions/0016-normalized-state-id-allocation.md
sed -n '955p;959p;966p' .plans/byte-machine-implementation-plan.md
sed -n '838p' .plans/byte-machine-implementation-plan.md
```
Expected: 0016 item 1 in full — **"Two-phase append"**, whose text is "Internal prefix states are assigned ids after the entire declared block, ordered by (declaring-node order, then prefix-structure pre-order, taking each prefix state's children in ascending byte order)"; `§17:955`'s "append after" clause; `§17:959`'s span-end lowering; `§17:966`'s no-speculative-fusion sentence; and `§14:838` — **rule 9, the span-end pause rule** — containing "at the next undelivered substep". The design's §4.4 originally cited `§14:837`, which is rule 8's boundary-flush pause and says nothing about substeps; that was corrected after review. **Do not re-introduce it.**

- [ ] **Step 2: Write the record**

`## Decision`:

1. **`0016`'s two-phase append is unchanged; the second phase gains one merged pre-order.** Declared nodes keep their declaration indices. Every internal state of either family is assigned an id **after the entire declared block** — `0016` item 1's own words — and within that block a declaring node contributes all of its internal states, prefix states and span continuations alike, at its own position in declaring-node order. **The merged pre-order operates inside phase two and does not interleave internal states with declared ones**; say so explicitly, because the design's §4.4 was ambiguous enough on first writing to be read the other way, and the wrong reading contradicts `0016`. This extends `0016`'s principle rather than adding a precedence rule beside it; the alternative — the two families in sequence within phase two — needs an arbitrary choice about which comes first and leaves the third family asking again.
2. **A span end lowers to one internal state per resumable substep**, not a fused state. `§17:966` forbids speculative fusion and `§14:838` requires resume at the next undelivered substep, which is only expressible if each substep has one.

`## Consequences`: the order is externally observable through the IR fingerprint and the order of emitted `case` arms — `0016`'s own Context is what makes that observable — so it is pinned by this record and not by the order the lowering happens to build.

- [ ] **Step 3: Verify and self-review**

```bash
rg -n "14:837" .decisions/0026-internal-state-id-order.md
```
Expected: **no output.**

- [ ] **Step 4: Commit**

---

## Task 4: Decision 0027 — "Reachable path" for the callback and span restrictions

**Files:**
- Create: `.decisions/0027-reachable-path-for-callbacks-and-spans.md`
- Modify: `.decisions/0023-eof-walk-starts-and-finish-reachability.md` (top bullet **and** foot note)

**Interfaces:**
- Consumes: `0023`, whose reachability answer this generalizes; `0011` item 4(a), which `0023` already narrowed.
- Produces: the relation Slice ③'s span pass uses, and the gate `pass-zero-progress` is missing.

- [ ] **Step 1: Read the parent plan's own record of the gap**

```bash
sed -n '1944,1947p' .plans/byte-machine-implementation-plan.md
sed -n '826p;519p;843p;898p' .plans/byte-machine-implementation-plan.md
sed -n '618,634p' src/byte-machine/verify.sls
```
Expected: `§Dated:1944-1947`'s "Left open deliberately, and not to be read as closed"; the three sentences that say "reachable path" and define it nowhere; `§16.2:898`'s "reachable zero-progress cycles"; and `pass-zero-progress`'s report loop with **no `reached` term anywhere in it**. Confirm that last one by reading, not by trusting this plan.

- [ ] **Step 2: Write the record**

`## Decision`:

1. **The span and callback restrictions use byte-reachability plus the EOF walk** — the pair the shipped `§16.2:908`/`:909` checks use — not `pass-reachability`'s `all-out-targets`.
2. The reason is `0023`'s, transferred verbatim rather than re-derived: **a graph node no execution can occupy is not a state that originates a traversal.**
3. **`pass-zero-progress` gains the reachability gate `§16.2:898` already requires.** Slice ③ owns the edit; this record owns the reason. State that it is benign today — such a machine is rejected by `unreachable-node` regardless — so that a reader does not mistake a consistency fix for a bug fix.

`## Consequences` must be explicit that **two different reachability relations now live in one verifier, deliberately**, and say which passes use which. An undocumented second relation is how `§16.2:898`'s missing gate came about in the first place.

- [ ] **Step 3: Annotate 0023 — top bullet, then foot note**

Verb: **annotates**. `0023` answered this question for the EOF checks; `0027` extends the same answer to the span and callback restrictions. Nothing `0023` says becomes false.

- [ ] **Step 4: Verify and self-review**

```bash
rg -n "^> - \*\*20" .decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^## 2026-09-04" .decisions/0023-eof-walk-starts-and-finish-reachability.md
```
Expected: bullets ≥ notes for this date.

- [ ] **Step 5: Commit**

---

## Task 5: Decision 0028 — Callback slots, `busy`, and what a callback can see

**Files:**
- Create: `.decisions/0028-callback-slots-and-visible-state.md`
- Modify: `.plans/byte-machine-implementation-plan.md` — **one appended disposition**

**Interfaces:**
- Consumes: nothing.
- Produces: the sixth parser accessor, the `busy` accessor rule, and the unbound-optional-callback slot shape. Slice ①b implements the accessor; Slice ② the rest.

- [ ] **Step 1: Read §9.3's normative list and §13's committed-state list, both in full**

```bash
sed -n '382,425p' .plans/byte-machine-implementation-plan.md
sed -n '816,826p' .plans/byte-machine-implementation-plan.md
sed -n '687,701p' .plans/byte-machine-implementation-plan.md
```
Expected: `§9.3`'s five parser accessors and **no span accessor**; `§13:816-826`'s committed-state bullets including `:818` (fields read-only *through public accessors*), `:820` (the active span name), `:821` (lifecycle is `busy`); and `§12.2`'s operation matrix with **four operation columns and no accessor column**.

- [ ] **Step 2: Write the record**

`## Decision`:

1. **"Parser operations are rejected" (`§13:821`) means the four mutating operations.** All five read accessors answer normally during `busy`. This is forced: `§13:818` requires fields to be read-only *through public accessors* at callback entry, and an accessor that raises during `busy` makes that sentence unsatisfiable and `§25:1580` unobservable.
2. **A sixth parser accessor, `parser-active-span`**, returning the active span's name or `#f`. Rejected alternatives, each with its reason: a compound `parser-state-name` makes every existing caller's contract conditional on a case it cannot detect; a debug-only surface leaves `§13:822-823` with no observable form and blinds `§22.4:1267`'s comparison for the milestone's newest construct.
3. **An unbound optional callback's slot holds a sentinel, short-circuited at the invocation site.** State the honest ground: **no witness distinguishes this from an installed closure** — an unbound callback has no application closure to record with, so neither shape puts an entry in a `§22.4:1268` sequence. The choice is taken on cost. It still binds **both lanes**, because a divergence here would be invisible to the differential, which is the reason to write it down rather than the reason to prefer it.

- [ ] **Step 3: Append the disposition to the parent plan**

`§9.3` is a **normative list**, so adding an accessor is a plan change. Append to `## Dated dispositions` — never inline. Read `§Dated:1804-1810` first and follow it: an insertion into the body re-numbers every `§section:line` citation below it.

```bash
wc -l .plans/byte-machine-implementation-plan.md
```
Run this **before and after**. The line count must grow only at the foot; if any line above the dispositions section moved, the edit was an insertion and must be redone.

- [ ] **Step 4: Verify and self-review**

```bash
rg -n "parser-active-span" .plans/byte-machine-implementation-plan.md
```
Expected: hits only inside the appended disposition, at a line number greater than the start of `## Dated dispositions`.

- [ ] **Step 5: Commit**

---

## Task 6: Decision 0029 — Span state is a lattice

**Files:**
- Create: `.decisions/0029-span-state-is-a-lattice.md`

**Interfaces:**
- Consumes: `0027`'s reachability relation.
- Produces: the shape of Slice ③'s pass 7.

- [ ] **Step 1: Read the three vocabularies side by side**

```bash
sed -n '899p;913p' .plans/byte-machine-implementation-plan.md
sed -n '843p' .plans/byte-machine-implementation-plan.md
sed -n '519p' .plans/byte-machine-implementation-plan.md
sed -n '925p' .plans/byte-machine-implementation-plan.md
```
Expected: `§16.2:899`'s five rejections; `§16.2:913`'s "Normal consuming cycles, including the main HTTP message loop, are valid"; `§14:843`'s four path properties; `§10.4:519`'s four rejections; `§16.3:925`'s pass 7. Three vocabularies, no mapping — that is the record's Context.

- [ ] **Step 2: Write the record**

`## Decision`: the span pass is a **dataflow analysis over an abstract span state**, and disagreement at any merge point — not only at an exit — is itself a diagnostic.

Two arguments, and **the second is the decisive one; say which is which**:
1. Under the path-existential reading, "inconsistent successful exits" adds nothing beyond `§14:843`'s fourth property, and a reading that makes one of five normative bullets vacuous is the weaker reading. *(This is an argument from interpretation.)*
2. `§16.2:913` declares normal consuming cycles valid, **so a check by path enumeration does not terminate on the main HTTP message loop.** A lattice join does. *(This is an argument from the graph, and it is the one that forces the shape.)*

`## Consequences`: the pass must state its abstract domain and its join, and `§16.2:899`'s five bullets map onto it explicitly — the mapping is the record's product, because three vocabularies with no mapping is what the Context describes.

- [ ] **Step 3: Verify and self-review**

- [ ] **Step 4: Commit**

---

## Task 7: Discharge the gate in the design document

**Files:**
- Modify: `.plans/milestone-5-design.md` (§4 heading block, §11 first bullet)

- [ ] **Step 1: Add the Gate-0-discharged mapping**

A blockquote under `## 4. Gate 0 — design-call resolutions`, mapping each §4.x to the record that carries it and recording the merges **as performed**, not as planned. If a merge was split or a record renumbered during execution, the blockquote says so — that is the point of writing it after the fact.

- [ ] **Step 2: Correct §11's first bullet in place**

It is an **instruction** ("the Gate 0 split is settled: six records, 0024-0029"), so it is corrected in place to say the split is discharged, with the record numbers as shipped.

- [ ] **Step 3: Verify the whole gate**

```bash
ls .decisions/002*.md
rg -n "milestone-5-design.md §4" .decisions/002*.md
git diff --stat main..HEAD -- src/ test/
```
Expected: six new records `0024`–`0029`; every one naming its design source in its `Milestone:` line; and **the third command prints nothing** — Gate 0 changes no product code and no test, and this is the check that proves it.

- [ ] **Step 4: Commit**

---

## Verification

Gate 0 ships no test. Its verification is the per-task `rg` checks above plus one whole-gate review, and the review's prompt carries this sentence from `AGENTS.md` verbatim:

> check what this claims the code or the spec DOES against the code and the spec, not against the prose

That is not decoration. Milestone 4's Gate 0 shipped **three false supporting reasons across five records**, two of them originating in its design, and only the review carrying that sentence caught them. The Milestone 5 design's own review refuted 29 of 64 findings but confirmed three arguments that were decisive-sounding and false — §4.3's, §4.6's, and §4.12 item 4's — each attached to a resolution that was nonetheless right.

**A record whose stated reason survives that check is discharged. A record whose reason is false is rewritten even when its decision is right.**
