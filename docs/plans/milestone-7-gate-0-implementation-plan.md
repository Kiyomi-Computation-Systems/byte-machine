# Milestone 7 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as three durable records — `0031`, `0032`, `0033` — the three design calls every Milestone 7 slice depends on, so that each slice cites a decision instead of re-deriving it. All three are externally observable: `0031` decides which machines verify (a family of three cases in the tree changes verdict); `0032` decides what a diagnostic *is* (four new public accessors on `(byte-machine verify)`, and which codes carry a path); `0033` fixes a developer-facing contract (an environment variable, a file written on failure, what "valid" means for a drawn machine) that every property fixture and every pin in the property pass will be measured against. A slice that picks any of them by accident pins the wrong answer in a fixture, and the fixture then defends it.

**Architecture:** This phase writes *documentation only* — no product code, no tests, no CMake. It produces three new decision records, dated notes reaching back into four existing records and one closed design, and the Gate-0-discharged mapping in the design document. It is the prerequisite for Slice ⓪ (which implements `0031`), Slice ① (`0032`) and Slices ②-④ (`0033`).

**Tech Stack:** Markdown, `rg`, `sed`, git. No Scheme, no CMake — with one permitted exception in Task 1 Step 4, a re-measurement in a *detached scratch worktree* that is taken only if the tree has moved under the design's measurement.

## Global Constraints

- **Decision records follow the repo format**: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 7, Gate 0 (milestone-7-design.md §4.N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. `docs/decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md` is the house style (its Context measures the tree and cites constructs by name, its Decision is numbered continuously, its Consequences hand each slice what it owes by shape), and `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` and `0027-reachable-path-for-callbacks-and-spans.md` are the records about the same verifier machinery `0031` extends. `docs/decisions/README.md` says what earns a record at all: *"Decisions that only restate the implementation plan do not need a record. These exist for choices a reader of the plan would otherwise have to reverse-engineer from the code."*
- **The next free decision numbers are 0031, 0032 and 0033.** Measured 2026-09-06: `docs/decisions/` holds `0001`–`0030` contiguous plus `README.md`. Confirm with `ls docs/decisions/` before writing; if a higher number exists because a record landed from another branch, use the next free numbers and correct every cross-reference in the design (`rg -n '003[123]' docs/plans/milestone-7-design.md` lists them).
- **Every date written in this phase is the literal date the task runs.** The bodies below carry `2026-09-06`; if a task runs later, correct the `Date:` line and every dated note to the actual day. A dated note that lies about its day is worse than none — Milestone 5's completeness check found five tracked sites dated a day early against the merge that carried them.
- **Record vs instruction discipline** (`AGENTS.md`, *"Correct a stale instruction in place; annotate a stale record"*). A **record** — a measurement, a finding, a decision record's Context or Consequences — gets a dated note appended, never a rewrite. An **instruction** — a work order, a scope allocation, a live comment saying what code is for — is corrected in place. Task 4 amends and annotates records by dated note, header bullet and site marker, never by rewrite; Task 5 corrects instructions in the design.
- **When a record reaches back into an earlier one, the TOP of the earlier record says so.** `docs/decisions/README.md` fixes both halves: a blockquote immediately after `Status:` and before `## Context` with **one bullet per amendment, in the order the notes appear**, each bullet opening with the note's own heading prefix verbatim and using the verb **amends** (a sentence above is now false) or **annotates** (nothing above became false); and, for an **amends**, a one-line site marker directly under the item or bullet it names, at its indentation, followed by a blank line. A note short enough may live in its bullet with nothing at the foot (README: "bullets may outnumber notes, never the reverse"). Task 4 reaches back into four records and may not append a foot note without its top bullet.
- **Citation staleness.** Before writing any parent-plan sentence into a record, `sed -n` the line and read it. **Do not trust the quoted text in this plan or in the design as exact.** Every citation here was measured 2026-09-06 against `8edceb1` (`main` after PR #83); nothing in this repository catches a stale citation.
- **No code, no counts, no forecasts.** Gate 0 changes no `.sls`, no `.sps`, no CMake, no test. It does not touch `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (58 / 522 today, `test/support/cmake/SchemeMutationSuite.cmake`), quote them as predictions, or forecast a milestone total. The narrowing, the widened record, the generator and the fixture saver are described as *obligations handed to their slices*, never performed here.
- **A record measures; it does not repeat.** Where a record states a fact about the tree — that `all-out-targets` has one call, that `make-diagnostic/edge` has one call site, that the property lane's seed is a literal — the task that writes it reads the construct at `HEAD` and cites it by name. Where it repeats a number from the design, it carries the qualifier that makes the number true.
- **The design document is the source of text.** Each record is the durable form of `milestone-7-design.md` §4.1, §4.2 or §4.3. Where this plan and the design differ, re-read the design and reconcile before writing; do not silently prefer one. **Where the design is *wrong*, stop and say so rather than encoding the error in a record** — Milestone 5's Gate 0 corrected three of ten resolutions' stated reasons while writing them, every conclusion intact, and Milestone 7's design was itself corrected in eleven important findings by its review before it merged (the second commit of PR #83 lists them).
- **The prototype's measurement is a record and is cited, not re-derived from reading.** `0031`'s central fact — three cases in one program flip, and nothing else moves — was measured by the design's prototype and reproduced byte for byte by the design's tree-claims review. Task 1 Step 4 says exactly when it is re-taken (the two files it depends on have moved) and how; a record that asserts the family from the walk's *definition* alone would be right for a reason the review has already shown is easy to get wrong (Milestone 6's pricing named the wrong fixture from reading).
- **Do not describe `pass-eof-execution`'s walk and `span-flow`'s walk as one procedure today.** They are two: the first starts a parked node's walk at `parked-eof-start`'s answer, the second at `eof-step` of the node itself. The design derives the two occupiable sets equal (every skipped name is a byte out-edge of a byte-reached node) and the semantics review re-measured it; `0031` states the equality as a *derivation with a measurement*, and Slice ⓪ is where the one procedure is built.
- **Do not narrow or defer a check on double-reporting grounds.** The parent plan's dispositions record that the "one finding per decision" rule cited against `§16.4:937-943` **does not exist**. No record written here may cite it.

## File Structure

**Created** — three records, each self-contained and readable without the design document open:

| File | Responsibility | Source |
| --- | --- | --- |
| `docs/decisions/0031-reachability-is-the-occupiable-relation.md` | `pass-reachability` reads decision 0027's occupiable relation, computed once and shared with pass 7; `all-out-targets` is retired; the two parked-set copies become one; the family whose verdict changes, exactly, with the three tree cases and what each asserts afterwards | design §4.1, §3.2 item 1 |
| `docs/decisions/0032-diagnostic-record-seven-fields-and-path-policy.md` | the record carries `§16.4`'s seven fields in four new slots; severity and machine name are stamped once in `verify-machine`; declaration names are passed per site; a path is carried by eight codes at twelve sites, starting at the walk's start, as a list and never a `cons` pair | design §4.2, §3.1 |
| `docs/decisions/0033-property-suite-contract.md` | validity is the verifier's verdict; every drawn construct proves it ran, with an accepted-count floor; the seed comes from `BYTE_MACHINE_PROPERTY_SEED` with the committed default; a disagreement writes a self-contained fixture to `BYTE_MACHINE_TEST_TMPDIR`; the comparison is `§22.4`'s nine members plus a plan-derived invariant layer with its qualifiers | design §4.3, §4.4 (Layer 3), §4.7 |

**Modified:**

| File | Change | Task |
| --- | --- | --- |
| `docs/decisions/0027-reachable-path-for-callbacks-and-spans.md` | dated note — the Consequences bullet "Handed to nobody: `pass-reachability`" becomes false (0031 hands it to Slice ⓪). A record, **amended** at that bullet, with a site marker | 4 |
| `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` | dated note — the second Consequence ("They carry accept-side fixtures, because 'verifies clean' is what the defect looked like") becomes false for three kinds under 0031 and is **amended**, with a site marker; the third ("NOT fixed here … must not be read as closed by this record") stays true and is **annotated** with a marker, since it would otherwise read as current | 4 |
| `docs/decisions/0020-field-shape-is-a-constructor-contract.md` | header bullet only — **annotates** the "Not touched" bullet's "widening it to §16.4's seven fields is Milestone 7": that widening is 0032; nothing above became false | 4 |
| `docs/decisions/0022-structured-parser-error-record.md` | header bullet only — **annotates** the "It deliberately touches nothing else" bullet's "that is Milestone 7 (§25:1616)": likewise 0032 | 4 |
| `docs/plans/milestone-6-design.md` | dated note under §8's "Narrowing `pass-reachability`" bullet (a record in a closed design) and its index entry in that document's Amendments block: two of the three predicted effects do not occur, and the one that does is in a fixture the bullet did not name | 4 |
| `docs/plans/milestone-7-design.md` | §4's Gate-0-discharged blockquote; §11's first bullet corrected in place; the Status header moved | 5 |

**Deliberately untouched.** Every `.sls` and `.sps`, every CMake file, `README.org`, `CHANGELOG.md`, and `docs/plans/byte-machine-implementation-plan.md` — the three records change no normative sentence of the parent plan, so like Milestone 6's Gate 0 this one appends no disposition; the `§25:1611` hand-off's annotation carrying §3.2 item 1's corrected accounting is **Slice ⓪'s** (design §4.11 item 1), and the `§16.2:910`/`:911` dispositions the owner approved are **Slice ④'s**, appended with the witnesses' measurements (design §11). `pass-reachability`'s note in `verify.sls` is corrected by Slice ⓪ in the commit that changes the walk.

---

## Task 1: Decision 0031 — `pass-reachability` walks the occupiable relation

**Files:**
- Create: `docs/decisions/0031-reachability-is-the-occupiable-relation.md`
- Test: none. Gate 0 is documentation; its verification is each task's `rg` step.

**Interfaces:**
- Consumes: decision 0027 item 1 (the occupiable relation and its two consumers) and its Consequences table; decision 0023 item 3's sentence and its second and third Consequences; the parent's "§25:1611 — Milestone 6 hands the reachability narrowing to Milestone 7" disposition and Milestone 6's design §8 (the pricing, as a record); `verify.sls`'s `all-out-targets`, `pass-reachability`, `byte-reached`, `parked?`, `span-flow`'s `eof-nodes` walk and `pass-eof-execution`'s parked-set membership, each read at `HEAD`.
- Produces: Slice ⓪'s relation, its one implementation, the exact family whose verdict changes, the three tree cases with what each asserts afterwards, and the pins it names by LABEL.

- [ ] **Step 1: Confirm the number is free and re-read the two source sections**

```bash
ls docs/decisions/
rg -n "^### 4\.1 |^### 3\.2 " docs/plans/milestone-7-design.md
```
Expected: no `0031-*` file exists, and the `rg` prints exactly two lines — design §4.1 and §3.2, this record's sources. Read §4.1 in full, §3.2 item 1 in full (the measurement, the three cases with their `got` lists, and why effects (b) and (c) do not occur), and §5 (Slice ⓪), which is what the record's Consequences hand over.

- [ ] **Step 2: Verify the load-bearing citations against the plan, not against the design**

```bash
sed -n '897p;947p' docs/plans/byte-machine-implementation-plan.md
sed -n '694p' docs/plans/byte-machine-implementation-plan.md
rg -n -U "a graph node no\s+execution can occupy" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md docs/decisions/0027-reachable-path-for-callbacks-and-spans.md
rg -n "Handed to nobody|is the one that means" docs/decisions/0027-reachable-path-for-callbacks-and-spans.md
rg -n "^- \*\*Three machine families|^- \*\*An over-approximation" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "^### §25:1611 — Milestone 6 hands" docs/plans/byte-machine-implementation-plan.md
```
Expected, in order: `§16.2:897` is "- unreachable nodes;" and `§16.4:947` begins "Unreachable nodes are errors in v0.1."; `§12.2:694` is the `finish-ready` row, whose `feed!` column reads "Contract condition" — the sentence the gate's soundness rests on ("once an execution takes an eof-target it can never feed again"); the third command prints the sentence in **both** records (0023 item 3 at one line, and 0027 item 2 quoting it across a line break — which is why the search is multiline: a single-line `rg` misses it); the fourth prints two lines in 0027 — the Consequences table row ("is the one that means 'an execution can be here'", NOT item 1, which defines the relation without that sentence) and the "Handed to nobody" bullet; the fifth prints the two Consequences bullets of 0023 the record reaches (lines 113 and 116 at `8edceb1`); the sixth prints one heading in the parent's dispositions section. **If any line does not contain its phrase, stop and re-measure** — the record's soundness argument rests on `:694`, and its attribution of the "an execution can be here" sentence was wrong in the design's first draft and corrected by review.

- [ ] **Step 3: Measure the verifier constructs the record describes**

```bash
rg -n "all-out-targets" src/byte-machine/verify.sls
rg -n -A3 "define \(parked\? " src/byte-machine/verify.sls
rg -n "^\s+\(span-end-node\? n\)$" src/byte-machine/verify.sls
rg -n -B2 -A12 "\(eof-nodes$" src/byte-machine/verify.sls
rg -n "symbol\? \(node-eof-target n\)" src/byte-machine/verify.sls
rg -n -F 'harness-case "an EOF-only-reachable byte edge into a finish is accepted"' test/common/verify-tests.sps
rg -n -F 'harness-case "a `default-error` sibling does not mask the stop"' test/common/verify-tests.sps
rg -n -F 'harness-case "a node no execution can occupy contributes no state (0029 item 3)"' test/common/verify-tests.sps
rg -n -F 'LABEL "verify: a sequence node'"'"'s eof-target does not feed reachability (arm 2, all-out-targets)"' test/support/cmake/SchemeMutationSuite.cmake
rg -n -F 'LABEL "verify: pass 7'"'"'s EOF half keeps taking byte edges"' test/support/cmake/SchemeMutationSuite.cmake
rg -n -F 'LABEL "verify: reachability never reports an unreachable node"' test/support/cmake/SchemeMutationSuite.cmake
```
Expected, as literals: the first prints **six** lines — the definition, one call inside `pass-reachability` (`(reached (reach-from m all-out-targets))`), and four comment lines — so the retirement removes one consumer; the second shows `parked?`'s four disjuncts (the entry, `pause-node?`, `callback-node?`, the `(symbol? (node-eof-target n))` clause) and **no** `span-end-node?`; the third prints **exactly one** line — the disjunct standing alone on its line inside `pass-eof-execution`'s `§16.2:909` membership (line 1182 at `8edceb1`), which is the one disjunct the two copies differ by, and which `parked?` (the second command) lacks; the fourth shows `span-flow`'s `eof-nodes` walk — a DFS seeded from `(eof-step n)` for every `parked?` node, following `eof-step` — which is the walk `occupiable` reproduces verbatim; the fifth prints **three** lines — the two code sites (the `§16.2:909` membership and pass 7's `parked?`) and one comment line inside `parked-eof-start` that names the clause; Milestone 6's Gate 0 plan counted **2**, before that comment existed; the next three print one line each — the three cases §3.2 item 1 names, whose group and case labels the record quotes; the last three print one `LABEL` line each — the pins §5 names. **Record what you measure, not what this step says.**

- [ ] **Step 4: Cite the prototype's measurement, or re-take it**

```bash
git diff --stat 5ac363a..HEAD -- src/byte-machine/verify.sls test/common/verify-tests.sps test/common/kind-position-census-tests.sps test/common/diagnostic-census-tests.sps
```
Expected: **no output** — the four files the measurement depends on are unchanged since the design measured them, and the record cites the design's run (§3.2 item 1: 113 lanes, 111 pass, `verify.rejections` source and AOT fail on the three named cases with the quoted `got` lists) and the tree-claims review's reproduction ("byte for byte", PR #83's second commit message). If the command prints anything, re-take it before writing: `git worktree add --detach <scratch> HEAD`, apply §4.1's two hunks to `src/byte-machine/verify.sls` there, `cmake --preset dev && cmake --build --preset dev && ctest --preset release -E scheme-mutation --output-on-failure`, and record the FAIL lines that result; then `git worktree remove --force <scratch>`. The record carries whichever measurement it rests on, dated, with the commit it was taken against.

- [ ] **Step 5: Write the record**

Create the file, following `0030`'s house style. Its `## Context` states the fact everything descends from — decision 0027 item 1 defines the occupiable relation and gives it two consumers, 0023's third Consequence raised `pass-reachability`'s over-approximation and forbade reading it as closed, and Milestone 6 priced narrowing it and handed it here — and measures the tree (Step 3): `all-out-targets`' one consumer; the two parked-set copies and their one differing disjunct; `span-flow`'s walk; the three cases. It records the measurement of Step 4 with its date and commit, and **states plainly that the pricing was wrong in two of three predictions**, naming the two (the `§16.2:898` fixture does not flip because its `Z` is `T`, occupiable through the EOF route; the matrix's pruning count does not move because no placed node carries an EOF route to the sink) and the one that does occur in a fixture the pricing did not name. **Decision, numbered continuously:**

1. **`pass-reachability` reads the occupiable relation** — `byte-reached` ∪ the nodes the EOF walk from the parked set visits — computed by one procedure that `span-flow` also reads (the "one census, two views" rule `node-out-edges`' comment states). Quote 0023 item 3's sentence as the ground, transferred to a third consumer: "a graph node no execution can occupy is not a state that originates a traversal". State the soundness of the gate from `§12.2:694`: once an execution takes an eof-target it can never feed again, so feed-reachable ⊆ `byte-reached`.
2. **The family whose verdict changes, stated exactly**: `E →(eof) T →(byte) Z` where `T` is reachable only through an EOF route, `T` is byte-dispatch, sequence-dispatch or integer-accumulate — the three kinds whose byte edges are dead at EOF — and `Z` is distinct from `T` and reachable over `all-out-targets` only through a dead byte edge of `T`, transitively (a node behind such a `Z`'s own eof-target is in the family). **State what is not in it and why each**: `Z = T` (a self-loop; `T` is occupiable through the EOF route — measured on 0027's Context machine); `T` a counted consume (`next` is an EOF successor, decision 0030 item 5); `T` any zero-width kind (the walk flows through it); `Z` reachable by any other route.
3. **`all-out-targets` is retired.** It has one consumer and the retirement leaves `reach-from` with one caller (`byte-reached`). Name the pins by LABEL (Step 3) and what each does: the "arm 2, all-out-targets" mutation retires with its reason written in its place, its decision pinned by the new group's sequence-dispatch pair; the "pass 7's EOF half keeps taking byte edges" mutation's `REPLACE` is re-shaped to an inline equivalent, because an unbound identifier is a raise and not a comparison; "reachability never reports an unreachable node" is re-read with its `REPLACE` and stays if its `FIND` survives.
4. **One parked set.** The two hand-written copies become one procedure with the superset membership (`span-end-node?` included). **The argument is a derivation with a measurement**: a byte-reachable span end's `next` is a byte out-edge, already in `byte-reached`, so the disjunct is inert for occupiability; the tree derives it inert for pass 7 (`parked?`'s own comment; 0030 item 6); and the design's semantics review re-measured it — with the disjunct added to pass 7's copy under the narrowed walk, `verify-tests.sps`, the matrix and the census answer exactly as without it. State the second derivation the record rests on: the two walks (`pass-eof-execution`'s, starting at `parked-eof-start`'s answer; `span-flow`'s, starting at `eof-step` of the parked node) visit the same occupiable set, because every name the first skips — a parked callback's continue and branch targets, a parked counted consume's `next` — is a byte out-edge of a byte-reached node.
5. **What the three cases assert afterwards**, decided here so Slice ⓪ does not improvise, and so that no fixture is rewritten to hide the narrowing: the `t2-kinds` accept case asserts the whole `(code . node)` set per kind — empty for pause, field-action, field-branch, callback and counted-consume; exactly `((unreachable-node . fin))` for byte-dispatch, sequence-dispatch and integer-accumulate — a derived set, three kinds; the join case asserts `((unreachable-node . rj2) (eof-reachable-stop . s0))`; the 0029 item 3 case asserts no span code and `unreachable-node` at each of `cl`, `exit`, `done`, `fin`. Plus the family's canonical pair per kind (`Z` distinct and dead, REJECTED; `Z` also byte-reachable from the entry, ACCEPTED) and the two ACCEPTED controls (the self-loop; `Z` behind a counted consume's `next`).

`## Consequences` must: state what does **not** change (`byte-reached`, every `§16.2:908`/`:909` verdict, pass 7's domain, `pass-zero-progress`'s `byte-reached`-alone gate and the reason it is not the composite, the code and its single emission site, the census row `(unreachable-node 1)`, the matrix's pruning count 3); say how 0023's "three machine families become legal" survives — as a `:908` verdict, not as the clean verification its second Consequence promised, so that Consequence is **amended** (Task 4); say 0027's "Handed to nobody" is now false and **amended** (Task 4); hand Slice ⓪ its oracle by shape (the verdict change is exactly the three cases on the unmodified tests, re-taken at the slice's base; nothing else moved; both ends — `verify.sls`'s note corrected in place naming this record, the parent's `§25:1611` hand-off annotated with the corrected accounting); and say the `pass-reachability` comment's `§12.7:772` citation is a blank line (the sentence is `:773`) and is corrected by Slice ⓪ in passing.

- [ ] **Step 6: Verify and self-review**

```bash
f=docs/decisions/0031-reachability-is-the-occupiable-relation.md
rg -n "16\.4:937" "$f"
rg -c "12\.2:694" "$f"
for c in all-out-targets parked-eof-start span-end-node byte-reached eof-step "Z = T" counted; do printf '%s %s\n' "$c" "$(rg -c -F "$c" "$f")"; done
rg -c -F "verifies clean" "$f"
```
Expected: the first prints **nothing** (Global Constraints' last bullet); the second prints **≥ 1** (the gate's soundness sentence is cited by line); the third prints **seven** lines, each ending in a count **≥ 1** (the retired walk, the two walk starts, the two relations, and the two shapes excluded from the family are all named); the fourth prints **≥ 1** (0023's second Consequence is quoted, not paraphrased, where the record says it becomes false). Then re-read the record asking the one question this project's reviews keep earning: does every *reason* it gives survive a check against the artifact, or only its conclusions? In particular: item 2's family is the measured set, not the walk's definition read off the code; item 4's equality is a derivation the review measured, not a hope.

- [ ] **Step 7: Commit**

Conventional Commits, `docs:`. The message states what was decided and the one thing a reader would otherwise reverse-engineer from the code: which relation "unreachable" quantifies over, and why the family of machines that changes verdict is three cases in the tree and not the fixture the pricing named.

---

## Task 2: Decision 0032 — the diagnostic record carries `§16.4`'s seven fields, and the path has a policy

**Files:**
- Create: `docs/decisions/0032-diagnostic-record-seven-fields-and-path-policy.md`

**Interfaces:**
- Consumes: `§16.4:935-947`; `§29:1760`; design §4.2 and §3.1's slot census; `verify.sls`'s `make-diagnostic`, `make-diagnostic/edge`, the four accessors and the export list, `eof-terminal`'s `walk`, `eof-verdict-join`, `reaches-self?`, `reach-from`, `pass-spans`; the census's derived constructor set; the matrix's `edge-roles-in-source`; decisions 0020 and 0022's "Milestone 7" sentences.
- Produces: Slice ①'s record shape, its stamping rule, the per-site `declarations` list, the path policy (which codes, from where, as what), the list-not-`cons` rule, the accessors, and the test-comparison rule.

- [ ] **Step 1: Re-read the sources and confirm the number is free**

```bash
ls docs/decisions/ | rg '^003'
rg -n "^### 4\.2 |^### 3\.1 " docs/plans/milestone-7-design.md
```
Expected: `003` matches `0031-*` only (Task 1 landed; `0032` free); the second prints two lines. Read §4.2 in full — its three rules and its table — and §3.1's two diagnostic paragraphs (the four-slot record, the test-read counts, the slot census: 34 node sites, 19 declaration sites, 1 machine, 2 `#f`).

- [ ] **Step 2: Verify the citations**

```bash
sed -n '935p;937p;938p;939p;940p;941p;942p;943p;945p;947p' docs/plans/byte-machine-implementation-plan.md
sed -n '1760p' docs/plans/byte-machine-implementation-plan.md
sed -n '275p' docs/decisions/0020-field-shape-is-a-constructor-contract.md
sed -n '365p' docs/decisions/0022-structured-parser-error-record.md
```
Expected: `:935` "Diagnostics contain:"; `:937` code; `:938` "severity (`error`; warnings may be added later)"; `:939` machine name; `:940` "node and edge/source label where applicable"; `:941` message; `:942` "relevant declaration names"; `:943` "a representative graph path when useful"; `:945` "Tests compare diagnostic structure and codes, not implementation-specific rendered text."; `:947` "Unreachable nodes are errors in v0.1. Warning or fragment-composition policies are deferred."; `§29:1760` "graph/DOT visualization"; the 0020 line contains "§16.4's seven fields is Milestone 7"; the 0022 line contains "that is Milestone 7 (§25:1616)". **If any differs, stop and re-measure.**

- [ ] **Step 3: Measure the constructs**

```bash
sed -n '36,44p' src/byte-machine/verify.sls
rg -c "\(make-diagnostic '" src/byte-machine/verify.sls
rg -c "\(make-diagnostic/edge" src/byte-machine/verify.sls
rg -n "define \(walk name path\)|define \(eof-verdict-join|define \(reaches-self\?|define \(reach-from|define \(pass-spans" src/byte-machine/verify.sls
rg -n "define \(make-diagnostic-name\?|define diagnostic-constructors" test/common/diagnostic-census-tests.sps
rg -n "define \(edge-roles-in-source" test/common/kind-position-census-tests.sps
rg -n -B6 "\(list 'active \(span-start-node-span n\)\)" src/byte-machine/verify.sls | rg "cons 'active"
for a in diagnostic-code diagnostic-node diagnostic-edge diagnostic-message; do printf '%s %s\n' "$a" "$(rg -o -F "$a" test/common/*.sps | wc -l | tr -d ' ')"; done
python3 - <<'PY'
import re
s=open('src/byte-machine/verify.sls').read()
for k,v in sorted({}.items()): pass
hits=re.findall(r"\(make-diagnostic(?:/edge)?\s+'([a-z-]+)\s+(\(machine-entry m\)|\(node-name n\)|\(machine-name m\)|\(machine-default-eof-error m\)|\(error-declaration-name e\)|\(callback-declaration-name cd\)|\(span-declaration-name sd\)|\(uint-field-name f\)|\(car es\)|#f|[a-z]+)", s)
from collections import Counter
print(Counter(h[1] for h in hits).most_common(), "total", len(hits))
PY
```
Expected, as literals: lines 36-44 show the five-slot record `(vector diagnostic-tag code node message #f)`, `make-diagnostic/edge`, and accessors indexing slots 1-4; **55** three-argument sites and **2** `make-diagnostic/edge` lines (its definition and one call); the five `define` lines exist (`walk` takes `(name path)` — the DFS stack a path can be read from; `reaches-self?` and `reach-from` keep only a visited set and no parent; `pass-spans` keeps an edge list and an in-state alist and no parent map); the census derives its constructor set from every `define` whose name begins `make-diagnostic`; `edge-roles-in-source` exists, and the `span-transfer` comment records that `(cons 'active …)` would enter the edge-role vocabulary — **the trap the path's representation must avoid**; the test-read counts are **76 / 41 / 5 / 0** (substring hits over `test/common/*.sps`); the slot census totals **56** with `(node-name n)` 20, `(callback-declaration-name cd)` 7, `nm` 6, `name` 5, `(span-declaration-name sd)` 5, `(machine-entry m)` 2, `#f` 2 and singletons for the rest. **Record what you measure.**

- [ ] **Step 4: Write the record**

`## Context`: the four-of-seven starting point (three of `§16.4`'s seven bullets in four slots, since `:940` is two things), the measurement of Step 3, and the fact that every earlier artifact that noticed — Milestone 3's design §8, Milestone 4's design §4.6 and §9, decisions 0020 and 0022 — assigned the widening here. **Decision, numbered:**

1. **The shape**: `(vector tag code node message edge severity machine declarations path)` — the four shipped slots in place; four accessors added and exported from `(byte-machine verify)`: `diagnostic-severity`, `diagnostic-machine`, `diagnostic-declarations`, `diagnostic-path`. `diagnostic?` and the four shipped accessors are unchanged; state why the widening is invisible to every shipped assertion (no test compares a whole record or reads its length — the two searches §3.1 states, both empty).
2. **Severity and machine name are stamped once, in `verify-machine`**, by one `map` over the appended pass results: severity the constant `error` (`§16.4:938`; warnings deferred, `:947`), machine name `(machine-name m)`, and `#f` for `pass-schema`'s not-a-machine arm (state why that is correct: `verify-machine` runs the other passes only under `(machine? machine)`). No emission site changes for these two fields and the census does not move. Rejected: a per-site machine argument (fifty-six edits to thread one value; a census move for nothing).
3. **The `node` slot keeps its shipped meaning — the subject's name, whichever table it lives in — and `declarations` is added beside it, per site.** List the sites that pass a non-empty list, by code: the nineteen whose subject is a declaration (callback 8, span 6, error 3, field 2) pass `(list subject)`; `missing-error-declaration` the error name; five of the seven `invalid-field-operand` sites the field name (the arity and unknown-selector arms fire before any operand is read and pass `'()`); `missing-callback-declaration` and `invalid-callback-invocation` at a node the callback name; `missing-span-declaration` the span name; `invalid-span-callback` the callback the span names. Every other site is untouched: `make-diagnostic` and `make-diagnostic/edge` keep their arities and fill the new slots with `'()` and `#f`; the sites that carry a list or a path call new constructors whose names begin `make-diagnostic`, so the census counts them. About thirty sites gain an argument; the rest keep their text and their pins (27 `FIND`s in the suite contain `make-diagnostic '`, measured).
4. **The path policy**, as the design's table, total over the census: `eof-reachable-stop` and `eof-zero-progress-cycle` carry the EOF walk's stack from `parked-eof-start`'s answer for the reporting node — the node itself, a parked callback's pause continuation, a parked counted consume's eof-target — to the stop or around the cycle, produced by `eof-terminal`'s `walk` returning the verdict and its path **as a two-element `list`, never a `(cons 'verdict …)` pair**, because `edge-roles-in-source` collects every `(cons 'SYM …)` in `verify.sls` as an edge role and would go red; `eof-verdict-join` keeps the surviving verdict's path, its left operand on a tie; `zero-progress-cycle` carries the cycle from the reporting node back to itself (`reaches-self?` gains parent links); `non-eof-into-finish` carries the byte path from the entry to the source node then the offending edge's target (`reach-from` gains a parent map; the zero-hop entry clause carries the one-element path); the four span codes carry a path from the entry to the node over `span-flow`'s edge relation (a parent map computed once from the edge list, before the fixpoint); every other code carries `#f`. Eight codes, twelve emission sites. "When useful" (`§16.4:943`) is read as "when the finding is about a path": a finding about a place — a duplicate, a bad name, an overlap, a dangling target, an unreachable node — has no path to give, and a list of names that merely led to the node would be `§29:1760`'s visualization in disguise.
5. **A path is representative, not canonical, and tests compare its shape.** It starts at the walk's start (`parked-eof-start`'s answer for an EOF verdict, the entry otherwise); it is deterministic because every walk visits in list order, the memoised `done` table is local to one `eof-terminal` call and records the first path that settled a verdict, and a tie in the join keeps its left operand; `§16.4:945` forbids comparing it as text, so tests assert its first element, its last, and membership.
6. **The census gains a derived row**: every emission site whose code is path-bearing passes a path and no other does, read from `verify.sls` as a datum.

`## Consequences`: hand Slice ① its work by file (the record and accessors; the stamping `map`; the per-site lists by code; the four walks' parent maps or returned paths; the census row; the shape assertions in `verify-tests.sps`; the pins whose `FIND` contains a site that gains an argument, reconciled by LABEL at plan time); state the two hazards its plan must clear (the `cons`-role trap; the `first element` assertion is the walk's start, not the reporting node, for parked callbacks and counted consumes); say 0020 and 0022 are **annotated** (Task 4), nothing above them false; and say what this record does not decide — warning severity's *policy* (`§16.4:947`), a diagnostic renderer, a catalog (`§27:1696`).

- [ ] **Step 5: Verify and self-review**

```bash
f=docs/decisions/0032-diagnostic-record-seven-fields-and-path-policy.md
rg -n "16\.4:937-943" "$f" | rg -i "one finding"
for c in diagnostic-severity diagnostic-machine diagnostic-declarations diagnostic-path parked-eof-start edge-roles-in-source "two-element" "left operand"; do printf '%s %s\n' "$c" "$(rg -c -F "$c" "$f")"; done
rg -c -F "twelve" "$f"
```
Expected: the first prints **nothing**; the second prints **eight** lines, each ending in a count **≥ 1**; the third **≥ 1** (the twelve path-bearing sites are counted, with the eight codes beside them). Then the reason check: item 2's `#f` rule rests on `verify-machine`'s `(machine? machine)` guard, read at `HEAD`; item 4's path start rests on `parked-eof-start` as shipped, not on "the parked node".

- [ ] **Step 6: Commit**

---

## Task 3: Decision 0033 — the property suite's contract

**Files:**
- Create: `docs/decisions/0033-property-suite-contract.md`

**Interfaces:**
- Consumes: `§22.6:1293-1297`, `§22.4:1262-1272`, `§22.5:1276-1289`, `§12.2:687-701`, `§11.5:660`, `§9.3:392-393`, `§14:831-839`, `§25:1621`, `§25:1627`; design §4.3 (the five clauses), §4.4's Layer 3 table with its qualifiers, §4.7's fixture shape; `property-differential-tests.sps`, `machine-gen.sls`, Pass 39 of the mutation suite, the two lane registrations, `cmake/ByteMachineTesting.cmake`'s tmp directory, the harness's FAIL-CONTEXT line.
- Produces: Slices ②-④'s shared contract — what "valid" means for a drawn machine, what each draw must prove, where the seed comes from, what a failure writes and where, and the invariant layer as a named contract with its qualifiers.

- [ ] **Step 1: Re-read the sources and confirm the number is free**

```bash
ls docs/decisions/ | rg '^003'
rg -n "^### 4\.3 |^### 4\.4 |^### 4\.7 " docs/plans/milestone-7-design.md
```
Expected: `0031-*` and `0032-*` exist, `0033` free; three heading lines. Read §4.3 in full, §4.4's "Layer 3" table and the scripted-bindings paragraph, and §4.7's fixture paragraph.

- [ ] **Step 2: Verify the citations**

```bash
sed -n '1293p;1295p;1297p' docs/plans/byte-machine-implementation-plan.md
sed -n '691p;694p;701p' docs/plans/byte-machine-implementation-plan.md
sed -n '392p;393p;660p' docs/plans/byte-machine-implementation-plan.md
sed -n '839p' docs/plans/byte-machine-implementation-plan.md
sed -n '1621p;1627p' docs/plans/byte-machine-implementation-plan.md
rg -n "its seed must come from the environment" docs/plans/milestone-0-slice-2-test-harness.md
```
Expected: `:1293` "print the seed on failure"; `:1295` "bounded small verified machines"; `:1297` "Never use an invalid graph to test executor behavior"; `:691` the `ready` row, `:694` the `finish-ready` row, `:701` the sticky-feed sentence ("`next` equals the new call's `start`, `consumed` is zero"); `:392-393` both annotated "feed-originated results only"; `:660` "`next`: the first unconsumed index"; `§14:839` begins "10. Errors do not flush a final partial fragment"; `:1621` "deterministic failure seed reporting"; `:1627` "minimized/reproducible failure fixtures can be saved without external tooling"; the last prints one line (the Milestone 0 plan's sentence). **If any differs, stop.**

- [ ] **Step 3: Measure the lane**

```bash
rg -n "define seed|define machine-count" test/common/property-differential-tests.sps
rg -c '"at least one|"the interpreter alone' test/common/property-differential-tests.sps
awk 'NR>=8233 && NR<=8360 && /LABEL "/' test/support/cmake/SchemeMutationSuite.cmake
rg -n -A10 "NAME byte-machine.property.differential.chez.source" test/CMakeLists.txt | rg "TIMEOUT|ENVIRONMENT"
rg -n "artifacts=" test/support/harness/byte-machine/test/harness.sls
rg -n "set\(tmp_dir|file\(MAKE_DIRECTORY|BYTE_MACHINE_TEST_TMPDIR=" cmake/ByteMachineTesting.cmake
rg -n "file\(REMOVE" cmake/ test/CMakeLists.txt
rg -l prng test/common/*.sps
```
Expected: the seed is the literal `20260823` and the count `40`; **eight** counter checks (five "at least one …", two of them built with `string-append`, and three "the interpreter alone …" — the pattern matches the opening quote of the label, not `(check`, for that reason); **six** `LABEL` lines — Pass 39's mutations, quoted verbatim in the record because Slice ②'s plan decides each by name; the source registration has `TIMEOUT 180` and **no** `ENVIRONMENT` line (so it passes nothing, and the default seed is what CI runs); the FAIL-CONTEXT line prints `artifacts=` from `BYTE_MACHINE_TEST_TMPDIR`; `cmake/ByteMachineTesting.cmake` sets `tmp_dir` and creates it with `file(MAKE_DIRECTORY)` and passes it as `BYTE_MACHINE_TEST_TMPDIR`; **no** `file(REMOVE` anywhere (nothing cleans it); the PRNG is imported by the property lane and by three fixed-machine differentials (sequence, sequence-node, http-version), so "seeded schedules" already exist in the tree and the contract's novelty is the drawn machine, not the seed.

- [ ] **Step 4: Write the record**

`## Context`: what `§22.6` leaves open (who guarantees "verified"; where the seed comes from; what a saved fixture is) and the measurement of Step 3 — the lane as shipped (a literal seed, eight counters, six pins, two registrations passing nothing, an artifacts directory nothing cleans), and `machine-gen.sls`'s five constraints with their true provenance (two rejection-driven verifier rules, one reachability rule, and the accumulate pins as one-byte coverage pins — the design's review corrected the first draft's "five verifier mirrors"). **Decision, numbered:**

1. **Validity is `verify-machine`'s verdict, not the generator's promise.** Draw from every construct with structural steering only where a draw would otherwise be unconstructible; verify every draw; hand only accepted machines to an executor; count rejected draws by code and keep them (Slice ④'s free material); assert structurally that the executed count equals the accepted count. Rejected alternatives, with reasons: validity by construction extended to seven more kinds (a second verifier in the test tree that cannot disagree with the first); retry-until-accepted with no floor (an over-rejection disappears from the lane without a trace).
2. **Every drawn construct proves it ran** — a counter per kind, matcher, operation, predicate, callback outcome, span event and schedule shape, reading an *observed* value, never the draw; each with an interpreter-only half (attribution) and an agreed half (the property), each ≥ 1 over the seed set; the shipped eight stay. **Plus the accepted-count floor**: a literal the plan fixes by measuring the rate under the committed seed and setting it no lower than half the machine count; a measured rate below half sends the draw back for steering before the lane lands.
3. **The seed**: `BYTE_MACHINE_PROPERTY_SEED`, a decimal exact non-negative integer; unset or empty means the program's literal; anything else is a loud `assertion-violation`, never a fallback (a typo that silently ran the default would report the wrong seed in every label). The registrations pass nothing; a developer replays by setting the variable; the seed is printed once at the suite's start and carried in every machine-level check label; a pin whose witness is a drawn shape names the seed it was measured under.
4. **A disagreement writes a fixture and says where**: on the first disagreement for a machine, a self-contained R6RS program — the lane's imports, the machine as `§9.1` constructor calls, the callback script and the schedule as quoted data, one `harness-group` running the same trial through the shared driver library, `harness-finish` — written to `BYTE_MACHINE_TEST_TMPDIR`, its path in the check's detail; it exits 1 through the shipped launcher on the disagreement and 0 when fixed; Slice ③ adds the minimized twin beside it. State what it is not: `§29:1761`'s serialized IR format (test support emitting source against the public API, no reader but `load`), `§29:1762`'s CLI.
5. **The comparison**: `§22.4:1264-1272`'s nine members per schedule, `§22.5:1285-1289`'s across-schedule rules (coalesced traces invariant; raw fragment boundaries not; malformed inputs compared across schedules by acceptance, code and absolute offset only), **and the invariant layer**, stated as a table with the qualifiers the design's review measured: the `§12.2` operation matrix as permitted `(status, lifecycle)` per `(lifecycle, operation)` — `poisoned` and `busy` not driven; a `stopped` from `parser-finish!` is a `:909` hole and is reported as one; for a **feed-originated** result `start ≤ next ≤ end`, `0 ≤ consumed ≤ end − start`, offset-after = offset-before + `consumed`, and for a `parser-finish!` result `next` = the offset and `consumed` = 0 (`§9.3:392-393`; the `§12.3:711` disposition's shipped values); the sticky-feed rule (`§12.2:701`); field values in `[0, 2^width)`; `finished` only from `parser-finish!` or a sticky feed after it — a verifier-completeness property, `§16.2:908`'s block being the mechanism; and, for a span that reaches its end with its data callback bound, the fragments' concatenation equals the input bytes the span covered (`§14:831-834`; not applicable at an error, `:839`). A trial that violates an invariant in one lane fails whether or not the other lane agrees. **State the layer's blind spot by name**: an agreed-wrong value that satisfies every invariant — the position kind of a failed zero-width action reached over a reexecute edge, the parent's `§12.7:770` open half — is invisible to all three layers, and the lane's header will say so.

`## Consequences`: hand Slice ② the generator, the driver library, the counters, the floor, the seed plumbing, and the fate of Pass 39's six mutations (each retired with its reason or re-anchored, decided per LABEL in ②'s plan, never loosened); hand Slice ③ the printer (total over the kinds and matchers, proved by a derived row and a round trip by fingerprint), the saver and the minimizer (validity oracle the verifier, failure oracle the lane's comparison, in-edges of a removed node retargeted to a fresh error node — never a shared sink); hand Slice ④ the rejected draws; and say what this record does not decide — the catalogue's shape (design §4.5), the independent oracle's scope (§4.6), the bounds (§4.10, a plan's numbers).

- [ ] **Step 5: Verify and self-review**

```bash
f=docs/decisions/0033-property-suite-contract.md
for c in BYTE_MACHINE_PROPERTY_SEED BYTE_MACHINE_TEST_TMPDIR "feed-originated" "12.7:770" "half the machine count" "assertion-violation" "machine-gen: the pause draw" "fresh error node"; do printf '%s %s\n' "$c" "$(rg -c -F "$c" "$f")"; done
rg -n "16\.4:937" "$f"
```
Expected: **eight** lines each with a count **≥ 1** (the two variables; the cursor row's qualifier; the named blind spot; the floor rule; the seed parse rule; a Pass 39 LABEL quoted verbatim; the minimizer's sink rule); the last prints nothing. Reason check: item 5's cursor row is qualified as the runtime behaves (finish results carry the offset in `next` — the review measured `finished next 5 consumed 0 offset 5`), and item 1's rejected alternatives state the failure each would cause, not a preference.

- [ ] **Step 6: Commit**

---

## Task 4: The notes that reach back — 0027, 0023, 0020, 0022, and Milestone 6's design §8

**Files:**
- Modify: `docs/decisions/0027-reachable-path-for-callbacks-and-spans.md` (top bullet, site marker under the "Handed to nobody" bullet, foot note)
- Modify: `docs/decisions/0023-eof-walk-starts-and-finish-reachability.md` (top bullet, two site markers, foot note)
- Modify: `docs/decisions/0020-field-shape-is-a-constructor-contract.md` (top bullet only)
- Modify: `docs/decisions/0022-structured-parser-error-record.md` (top bullet only)
- Modify: `docs/plans/milestone-6-design.md` (Amendments index entry; dated note under §8's reachability bullet)

**Interfaces:**
- Consumes: `0031` (items 1-5) and `0032` (items 1-4).
- Produces: the pointers a reader arriving at any of the five by citation needs.

- [ ] **Step 1: Read each header block and the sentences the notes reach**

```bash
for n in 0020 0022 0023 0027; do f=$(ls docs/decisions/$n-*.md); printf '%s bullets=%s notes=%s markers=%s\n' "$n" "$(rg -c '^> - \*\*20' "$f")" "$(rg -c '^## 20' "$f")" "$(rg -c 'Amended 20|Annotated 20' "$f" || echo 0)"; done
rg -n "^- \*\*Handed to nobody" docs/decisions/0027-reachable-path-for-callbacks-and-spans.md
rg -n "^- \*\*Three machine families|^- \*\*An over-approximation" docs/decisions/0023-eof-walk-starts-and-finish-reachability.md
rg -n "Milestone 7" docs/decisions/0020-*.md docs/decisions/0022-*.md
rg -n "^- \*\*Narrowing \`pass-reachability\`" docs/plans/milestone-6-design.md
rg -n "^> \*\*2026-09-06, Slice ② delivered" docs/plans/milestone-6-design.md
```
Expected at `8edceb1`: `0020 bullets=1 notes=1 markers=0`, `0022 bullets=1 notes=1 markers=1`, `0023 bullets=2 notes=2 markers=1`, `0027 bullets=1 notes=1 markers=0`; 0027's bullet at line 181; 0023's two bullets at lines 113 and 116; one "Milestone 7" line in each of 0020 (275) and 0022 (365); the M6 design's §8 bullet at line 1121 and its newest Amendments entry (the Slice ② one) at line 42, which the new entry goes **above** (newest first).

- [ ] **Step 2: 0027 — amend "Handed to nobody"**

Verb: **amends** the Consequences bullet "Handed to nobody: `pass-reachability`" — after `0031` it is handed to Slice ⓪, and "it is still not closed" is false. Top bullet (opening with the note's heading prefix, e.g. `**2026-09-06 (Milestone 7 Gate 0)**`), a site marker directly under the bullet at its indentation followed by a blank line (`> **Amended 2026-09-06 (Milestone 7 Gate 0)** by [decision 0031](./0031-reachability-is-the-occupiable-relation.md) — `pass-reachability` now walks item 1's relation; see the dated note below. The sentence above is left as decided.`), and a foot note headed `## 2026-09-06 (Milestone 7 Gate 0) — …` that: names item 1's relation as the one `pass-reachability` reads; quotes the Consequences table's "is the one that means 'an execution can be here'" as the sentence transferred; records that item 3's verdict change (the `§16.2:898` gate) was "the first thing that depends on the answer" and that the answer is now given; and says what does **not** move — item 1, item 3, the table's second row.

- [ ] **Step 3: 0023 — amend the second Consequence, annotate the third**

One top bullet, verb **amends**, naming both bullets: the second Consequence's "They carry accept-side fixtures, because 'verifies clean' is what the defect looked like" is false for three of the families under `0031` (byte-dispatch, sequence-dispatch, integer-accumulate — the finish behind their dead byte edge is `unreachable-node`), so the fixture keeps its `:908` half and gains a `:897` finding; the third Consequence's "NOT fixed here … must not be read as closed by this record" stays true and is annotated because it would otherwise read as current. Two site markers — `**Amended …**` under the second bullet, `**Annotated …**` under the third — each at the bullet's indentation, each followed by a blank line. One foot note headed `## 2026-09-06 (Milestone 7 Gate 0) — …` carrying: the family exactly (0031 item 2), the three-kind split and why the other five kinds keep their finish occupiable, and the statement that item 3's sentence ("a graph node no execution can occupy …") is 0031's ground, transferred to its third consumer.

- [ ] **Step 4: 0020 and 0022 — bullet-only annotations**

Each gets one top bullet, verb **annotates**, with the whole note in the bullet (README: a note short enough may live in its bullet; bullets may outnumber notes): 0020 — the "Not touched" bullet's "widening it to §16.4's seven fields is Milestone 7" is decision `0032`, Slice ①; the field name stays in the `node` slot and gains a `declarations` entry beside it; nothing above became false. 0022 — the "It deliberately touches nothing else" bullet's "that is Milestone 7 (§25:1616)" is decision `0032`; `§16.4:945`'s comparison rule is unchanged; nothing above became false. No site marker is required for an annotation, and none is added: neither bullet reads as current in a way a marker would correct.

- [ ] **Step 5: Milestone 6's design §8 — the pricing gets its dated note**

A record in a closed design; annotate, never rewrite. Under the §8 bullet "Narrowing `pass-reachability`", an indented dated paragraph: *(Annotated 2026-09-06, Milestone 7 Gate 0 — measured by the Milestone 7 design's prototype at `5ac363a` and reproduced by its review: of the three effects above, the `verify-tests.sps` fixture named does **not** flip — its `Z` is `T`, occupiable through the EOF route — and the matrix's pruning count does **not** move — no placed node carries an EOF route to the sink; the family does gain `unreachable-node`, in three cases the bullet did not name: the `t2-kinds` accept case, the join's `default-error` case, and the 0029 item 3 span case. One file, three cases; `milestone-7-design.md` §3.2 item 1 carries the enumeration and decision 0031 the resolution.)* And an index entry at the **top** of the Amendments block's dated entries: `**2026-09-06, Milestone 7 Gate 0** — **annotates §8's reachability bullet** (a record): two of its three predicted effects do not occur and the third occurs in fixtures it did not name; see the note under the bullet.`

- [ ] **Step 6: Verify**

```bash
for n in 0020 0022 0023 0027; do f=$(ls docs/decisions/$n-*.md); printf '%s bullets=%s notes=%s markers=%s\n' "$n" "$(rg -c '^> - \*\*20' "$f")" "$(rg -c '^## 20' "$f")" "$(rg -c 'Amended 20|Annotated 20' "$f" || echo 0)"; done
for f in docs/decisions/0*.md; do keys=$(sed -n '1,/^## /p' "$f" | sed -n '/^> - /p'); for d in $(rg -o '^## .*?(20[0-9]{2}-[0-9]{2}-[0-9]{2})' -r '$1' "$f" | sort -u); do case "$keys" in *"$d"*) ;; *) echo "$f: dated note $d has no bullet in the header block";; esac; done; done
rg -c "Milestone 7 Gate 0" docs/plans/milestone-6-design.md
rg -n "^> \*\*2026-09-06, Milestone 7 Gate 0" docs/plans/milestone-6-design.md
```
Expected: `0020 bullets=2 notes=1 markers=0`, `0022 bullets=2 notes=1 markers=1`, `0023 bullets=3 notes=3 markers=3`, `0027 bullets=2 notes=2 markers=1`; the README's invariant check prints **nothing**; the M6 design contains the phrase **twice** (the index entry and the note), and the index entry sits at a line number **below** the amendment law's paragraph and **above** the Slice ② entry (newest first).

- [ ] **Step 7: Commit**

---

## Task 5: Discharge the gate in the design document

**Files:**
- Modify: `docs/plans/milestone-7-design.md` (§4 heading block; §11's first bullet; the Status header)

- [ ] **Step 1: Add the Gate-0-discharged mapping**

A blockquote under `## 4. Gate 0 — design-call resolutions`, in the shape of Milestone 6's (`rg -n "Gate 0 discharged 2026-09-06" docs/plans/milestone-6-design.md` shows it): a three-row table — `0031` carries §4.1; `0032` carries §4.2; `0033` carries §4.3 with §4.4's Layer 3 and §4.7's fixture shape — **as performed**: if a task split or merged a resolution, or corrected a stated reason while writing, the blockquote says so — that is the point of writing it after the fact; Milestone 5's blockquote records three such corrections. Below the table, the four records' notes and the M6 design's, by verb.

- [ ] **Step 2: Correct §11's first bullet and the Status header in place**

Both are **instructions**. §11's first bullet ("Gate 0 is three records, `0031`-`0033`, carrying …") becomes "Gate 0 is discharged: …" with the records' titles as shipped. The Status header gains "Gate 0 discharged <date> as decisions 0031-0033 (PR #N)", the PR number filled in by the closing ritual.

- [ ] **Step 3: Verify the whole gate**

```bash
ls docs/decisions/003*.md
rg -n "milestone-7-design.md §4" docs/decisions/003*.md
rg -c "APPROVED 2026-09-06" docs/plans/milestone-7-design.md
git diff --stat main..HEAD -- src/ test/ README.org CHANGELOG.md docs/plans/byte-machine-implementation-plan.md
```
Expected: three new records `0031`, `0032`, `0033`; each `Milestone:` line naming its design source (three lines); **`3`** — §4.12's approvals are already recorded and this plan does not revise them; and **the last command prints nothing** — Gate 0 changes no product code, no test, no status surface and no parent-plan sentence, and this is the check that proves it.

- [ ] **Step 4: Commit**

---

## Verification

Gate 0 ships no test. Its verification is the per-task `rg` checks above plus one whole-gate review, read-only, in an isolated worktree, whose prompt carries this sentence from `AGENTS.md` verbatim:

> check what this claims the code or the spec DOES against the code and the spec, not against the prose

Milestone 4's Gate 0 shipped **three false supporting reasons across five records**; Milestone 5's corrected three of ten resolutions' stated reasons while writing them; Milestone 7's own design had eleven important findings folded before it merged. This gate has three records and four places a false reason can hide, each with the measurement that settles it: `0031` item 2's family, which is the prototype's measured set and not the walk's definition read off the code (Task 1 Step 4); `0031` item 4's equality of the two walks, a derivation the semantics review re-measured; `0032` item 4's path start, which is `parked-eof-start`'s answer and not the reporting node (a first draft of the design said the reporting node, and the review found it); and `0033` item 5's cursor row, which holds for feed-originated results only (finish results put the offset in `next` — measured by the review as `finished next 5 consumed 0 offset 5`).

**A record whose stated reason survives that check is discharged. A record whose reason is false is rewritten even when its decision is right.**
