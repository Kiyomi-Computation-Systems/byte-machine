# Milestone 0 Close-out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Milestone 0 in both governing documents, move spike §7 deliverables D6, D7, and D8 to Milestone 1, and correct every instruction in the tree that still names a retired concept.

**Architecture:** Seven tasks, ordered so that every link target exists before anything links to it: the decision record first, then the CI feasibility note, then the two document sweeps, then the mixed record/live-code/orientation task, then the standards and ledger, then verification. Each task is a single commit with its own check.

**Tech Stack:** Markdown, CMake comments, `rg`, `ctest`, `make`. No Scheme is written.

**Design:** [`milestone-0-close-out.md`](./milestone-0-close-out.md). Every row ID below (`P3`, `S12`, `L1`, …) is that document's row ID, and the replacement text is repeated here in full — do not read the design to execute a step.

## Global Constraints

- **Prose only.** No new library, no new lane, no new mutation, no new exit status, no CI, no deletion of the spike §7 D3 placeholders. The only non-prose edits in the entire plan are two CMake comments (Task 5, rows L1 and L2).
- **Match on text, never on line number.** Line numbers shift as earlier rows land within the same file. Every edit below gives a unique FIND string.
- **Never cite a line number in a file this slice edits.** The two governing plans — `byte-machine-implementation-plan.md` and `milestone-0-portability-spike.md` — are edited by Tasks 3 and 4, and every insertion or deletion shifts every line below it. A `§25:1425` written before those tasks is wrong after them, and neither the vocabulary grep nor the link check can see it. **Cite the section only** (`parent §25`, `spike §7 D6`) for those two files. Line numbers remain correct and expected for files this slice does not edit: the launchers, the harness, the CMake modules, and decisions 0002–0006. Decision 0001 is only appended to, so citations into it are safe.
  Row P14 shipped this defect once and it was corrected in `0867e66`/`6c38ddf`: Milestone 9's Scope lines moved from :1602–1603 to :1615–1616 under Task 3's own edits. **Task 7 Step 0 sweeps the rest**, after Task 4 has finished shifting the spike.
- **Dated notes take one of four forms**, matching spike §7 D5's existing note: a blockquote beginning `> **Amended YYYY-MM-DD by …`, `> **Moved YYYY-MM-DD by …`, `> **Retired YYYY-MM-DD …`, or `> **Dispositioned YYYY-MM-DD …`. The date is **2026-08-22** throughout.
- **Records are never edited.** Spike §2's environment-facts table (including its Gambit rows and its "1 of 8" count), spike §5's D6 row, spike §6, `CHANGELOG.md`'s `### Added` / `### Changed` / `### Removed` / `### Fixed` entries, and `docs/decisions/` bodies other than the annotation in row R1. If a step seems to require editing one of these, stop and report it.
- **`CHANGELOG.md` has 28 historical Gambit mentions in its `### Added` and `### Removed` sections.** They are records of what shipped and what was cut. Do not touch them. Only the preamble (row C1) and new `[Unreleased]` entries (row C2) are in scope.
- **The full test matrix runs in Task 5 and Task 7 only.** Tasks 1–4 and 6 touch no file CMake reads.
- **`.superpowers/sdd/` is git-ignored** (`.superpowers/sdd/.gitignore` is `*`). Update the ledger in place; never `git add` it -- the command fails. No `git add` line in this plan names it.
- **Every claim written into a document must have been re-read against the tree in this branch**, not copied from the design document's quotation of it. The design document was itself corrected twice for exactly this.

## File Structure

| File | Task | Responsibility |
| --- | --- | --- |
| `docs/decisions/0007-milestone-0-closes-at-the-harness.md` | 1 | row R2 — new: the holding, the parent §30 question answers, the measurements, the consequences |
| `docs/plans/milestone-0-ci-feasibility.md` | 2 | new — the four Tier 1 cells, Windows path and LF behavior, what each cell would prove |
| `docs/plans/byte-machine-implementation-plan.md` | 3 | rows P1–P14 |
| `docs/plans/milestone-0-portability-spike.md` | 4 | rows S1–S17 |
| `docs/decisions/0001-toolchain-discovery.md` | 5 | row R1 — the never-true CI annotation |
| `cmake/ByteMachineTesting.cmake` | 5 | row L1 — one comment |
| `test/CMakeLists.txt` | 5 | row L2 — one comment |
| `CHANGELOG.md` | 5, 6 | row C1 (preamble) and row C2 (entries) |
| `AGENTS.md` | 6 | the record/instruction standard |
| `.superpowers/sdd/progress.md` | 1–7 | the ledger, appended each task |

---

### Task 1: Decision record 0007 (row R2)

Everything else links to this file, so it lands first.

**Files:**
- Create: `docs/decisions/0007-milestone-0-closes-at-the-harness.md`
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the link target `../decisions/0007-milestone-0-closes-at-the-harness.md` (from `docs/plans/`) and `./0007-milestone-0-closes-at-the-harness.md` (from `docs/decisions/`), used by rows P13, P14, S1, S3, S4, S10, S11, S12, S16, and R1.

- [ ] **Step 1: Read the two model records end to end**

Read `docs/decisions/0005-chez-only.md` and `docs/decisions/0004-content-fingerprint-and-provenance.md` in full. 0005 is the structural model — header block, Context, Measurements, Decision, Consequences. Note that 0005's header block is exactly three lines (`Date:`, `Status:`, `Milestone:`) and that its Measurements section states what was measured against which commit on which host.

- [ ] **Step 2: Re-take the ratio measurement against this branch**

Run each command and record the actual output — do not copy the numbers from the design document:

```bash
wc -l src/byte-machine/*.sls | tail -1; cat cmake/*.cmake test/support/cmake/*.cmake test/CMakeLists.txt | wc -l; cat test/support/harness/byte-machine/test/*.sls test/support/harness/self/*.sps test/support/launchers/*.ss | wc -l; cat docs/plans/*.md | wc -l; git rev-parse --short HEAD
```

The `docs/plans` count will differ from the design document's 18690, because this plan and the close-out design are now in that directory. Use what the command prints, and state the commit it was taken at.

- [ ] **Step 3: Write the record**

Create `docs/decisions/0007-milestone-0-closes-at-the-harness.md` with this exact header block and these six sections:

```markdown
# 0007: Milestone 0 closes at the harness, and its last three deliverables move to Milestone 1

Date: 2026-08-22
Status: accepted
Milestone: 0, close-out
```

**Context** must state:
- The four incompatible live statements of spike §7 D6, with their locations: spike §7 D6 ("Both implementations write byte-identical…"), spike §8 item 6 (its exit condition), the spike header note's restatement as "a single-implementation, cross-platform claim", and parent §25 ("across the Chez source and AOT lanes").
- That the first two name a second implementation [decision 0005](./0005-chez-only.md) removed; that the third needs cells this host does not have (one of parent §7.3's four Tier 1 cells exists locally); and that 0005 refused the same shape of substitution one deliverable over, writing of a two-lane agreement that it "is a weaker statement, and slice 5b already owns it under its own name" (0005:159–165).
- The structural fact: D6 and D7 are properties of an emitter, and the spike's scope decision forbids one — "No byte-machine semantics (no IR, verifier, interpreter, emitter, or runtime) are implemented in this milestone."

**Measurements** carries the Step 2 numbers, the commit, and the host, in 0005's style. State that all of `src/` is placeholder.

**Decision** must state, in this order:
1. Milestone 0 closes.
2. Spike §7 D6 moves to parent §25's Milestone 1 **Scope** line "deterministic output".
3. Spike §7 D7 moves to Milestone 1's "symbolic name resolution" and "generated-name safety for every construct present".
4. Spike §7 D8's CI pipeline moves to Milestone 1 alongside D6's cross-cell axis, because both need the same four cells; D8's written-feasibility-notes half is discharged by [the CI feasibility note](../plans/milestone-0-ci-feasibility.md).
5. Milestone 1 has no Deliver list — it has a Scope list, and all three landing lines already exist in it.

**Parent §30 questions 1–4** — this section is why the record exists rather than the plan section: spike §12's ninth criterion requires these answered in `docs/decisions/`. Each answer states its evidence level.

1. **Minimum Chez release.** Pinned at 10.4.1, verified, the only version this project has run on. The floor is unestablished and needs an older release under CI; [0001](./0001-toolchain-discovery.md)'s Consequences already say so. Evidence: the probe's version gate. Answered as a pin with a stated open floor — **not** as a measured floor.
2. **Exact source and AOT commands per Tier 1 platform.** Answered for macOS arm64 by the shipped launchers, which are executable rather than documentary. Per-platform variance is unmeasured and rides with D8.
3. **Windows library search paths. Both halves closed, neither by measurement.** The include half by absence ([0006](./0006-inline-libraries.md) leaves nothing to resolve). The separator half **by construction** in [0002](./0002-shared-body-include-mechanism.md):143–147 — quote it: "because the launcher takes repeatable flags, byte-machine never joins Chez search paths with any separator on any platform, so the `:` vs `;` question has no Chez-side object left to apply to." State that this closure is stronger than a documentary answer and is not superseded by 0002's include-mechanism retirement. State that what 0002 left open — Windows path form, backslashes, drive letters, what counts as absolute — is a different question and rides with the Windows cell.
4. **Portable condition construction exposed by the wrappers.** Closed by 0005: one implementation, R6RS conditions, no portability layer. A closure by decision, not a deferral.

Then one line: questions 5–7 are the spike's own "deferred, with rationale" cases; question 6 (identifier length and source-size limits) is D7's companion and rides with it, because the grammar imposes no maximum and measuring compiler limits before there is generated source to hit them measures nothing.

**Consequences** must state:
- What closing buys: the milestone stops being open on three items none of its own exit criteria demand.
- What it defers, by name.
- The named risk: a portability regression during Milestone 1 will surface late, because D8 moved. This is the cost of the decision and is stated, not hedged.
- That parent §25's Milestone 0 exit criteria are three, and D6/D7 appear in none of them; criterion 2 is D8's notes half and is discharged here.

- [ ] **Step 4: Verify every link in the new record resolves**

```bash
python3 - <<'PY'
import re,os
bad=[]
for f in ["docs/decisions/0007-milestone-0-closes-at-the-harness.md"]:
    d=os.path.dirname(f)
    for m in re.finditer(r'\]\(([^)#]+?)(#[^)]*)?\)',open(f).read()):
        t=m.group(1)
        if t.startswith(("http","mailto")): continue
        p=os.path.normpath(os.path.join(d,t))
        if not os.path.exists(p): bad.append((f,t))
for b in bad: print("MISSING",*b)
print("broken:",len(bad))
PY
```

Expected: `broken: 0`.

- [ ] **Step 5: Verify every quotation against its source**

For each of the four quoted strings (0005:159–165, the spike's scope decision, 0002:143–147, and any parent §25 Scope line names), run `rg -n` for the exact string in the named file and confirm one hit. A quotation that differs by a word is a defect — the design document was corrected for exactly this class four times.

```bash
python3 -c '
import re
pairs=[("docs/decisions/0005-chez-only.md","is a weaker statement, and slice 5b already owns it under its own name"),
       ("docs/plans/milestone-0-portability-spike.md","No byte-machine semantics (no IR, verifier, interpreter, emitter, or runtime) are implemented in this milestone"),
       ("docs/decisions/0002-shared-body-include-mechanism.md","byte-machine never joins Chez search paths with any separator on any platform")]
for f,q in pairs:
    hay=re.sub(r"\s+"," ",open(f).read())
    print(hay.count(re.sub(r"\s+"," ",q)), f, q[:40])
'
```

Expected: `1` for each. **Do not use `rg -nF`** for this -- every one of these
quotations wraps a line break in its source, so a literal single-line search
reports a correct quotation as absent. Normalize whitespace, as above.

- [ ] **Step 6: Append to the ledger and commit**

Append to `.superpowers/sdd/progress.md` a section header for this branch (following the file's existing convention — branch name, plan path, design path, merge base) and `Task 1: COMPLETE` with the commit SHA and the measured numbers.

```bash
git add docs/decisions/0007-milestone-0-closes-at-the-harness.md
git commit -m "docs: record decision 0007, Milestone 0 closes at the harness"
```

---

### Task 2: The CI feasibility note

**Files:**
- Create: `docs/plans/milestone-0-ci-feasibility.md`
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: `0007` (Task 1) for its citation.
- Produces: the link target `./milestone-0-ci-feasibility.md` (from `docs/plans/`) and `../plans/milestone-0-ci-feasibility.md` (from `docs/decisions/`), used by rows P8, P11, S12, and S16.

- [ ] **Step 1: Read the four launcher call sites before writing anything**

The central claim of this note is that byte-machine designed the Windows separator question out. Verify it rather than repeating it:

```bash
rg -n "library-directories" test/support/launchers/*.ss cmake/*.cmake test/support/cmake/*.cmake
```

Expected: every hit passes a Scheme **list of pairs**, never a separator-joined string — `chez-source.ss:139-140`, `chez-aot.ss:183-184`, `chez-compile.ss:153`, `fingerprint-manifest.ss:59`. If any call site joins with `:` or `;`, stop: the note's premise is false and this is a plan defect to report.

- [ ] **Step 2: Read the Chez man page section on `--libdirs`**

```bash
gunzip -c /opt/homebrew/share/man/man1/chez.1.gz | rg -n -A4 -B4 "separator character"
```

Record the line number for citation. If the man page is not at that path, find it with `man -w chez` and cite what you actually read. If it cannot be found on this host, say so in the note and mark the separator rule as uncited rather than citing it from memory.

- [ ] **Step 3: Write the note**

Create `docs/plans/milestone-0-ci-feasibility.md`. Header block in the style of the other plan documents (`Status:`, `Date: 2026-08-22`, `Parent plan:`, and a line naming what it discharges: parent §25 exit criterion 2, spike §7 D8's feasibility-notes half, and parent §25's "documented Windows path and LF behavior").

**Section 1 — The four Tier 1 cells.** Parent §7.3 fixes them: Chez on Linux amd64, Linux arm64, macOS arm64, Windows amd64, each in both source and AOT execution. For each cell give four facts: how Chez is obtained, what the binary is called there, whether the shipped probe handles that name, and which deliverable the cell is the only witness for.

- *macOS arm64* — available locally; Homebrew renames upstream `scheme` to `chez`; the probe already handles it (this is the collision [0001](../decisions/0001-toolchain-discovery.md) was built for).
- *Linux amd64* — hosted runner; packaged as `scheme` or `chezscheme` depending on distribution, which is the same probe case.
- *Linux arm64* — deferred. Hosted arm64 runners or emulation. **State that neither option has been priced, and do not price them from this host** — a cost estimate taken here would describe this host, which is the defect AGENTS.md's scratch-fixture rule names.
- *Windows amd64* — deferred, and the **only** cell that can exhibit the CRLF translation spike §7 D7 names.

**Section 2 — Windows path and LF behavior.** Four paragraphs, in this order, because the point is that the obvious exposure was designed out:

1. The `:` versus `;` separator applies to Chez's `--libdirs` option and the `CHEZSCHEMELIBDIRS` variable — the **string** form. Cite the man page line recorded in Step 2.
2. **This project never uses that form.** All four Scheme entry points set the `library-directories` *parameter* with a Scheme list of pairs, built from repeatable command-line flags. Cite the four sites from Step 1 with their line numbers. Conclude that the separator is recorded here as background about the runtime, not as behavior byte-machine depends on.
3. Chez joins the components of a *library name* with `/` to build a partial path — `(a b)` becomes `a/b` — and appends it to each root before trying each extension. That is library-name resolution, not a separator behavior, and it is what makes `/`-delimited roots the portable form. Cite the man page.
4. What genuinely stays open on Windows is what [0002](../decisions/0002-shared-body-include-mechanism.md):149–151 already named: path form — backslashes, drive letters, and what counts as an absolute pathname. Unmeasured; arrives with the Windows cell.

Then LF: the fingerprint reader already opens files as binary for this exact reason — quote the comment at `test/support/harness/byte-machine/test/fingerprint.sls:50–52`, "an LF is an LF on a platform whose text ports would translate it". The **write** side is D7's and is unbuilt.

**Section 3 — What each cell would prove that this host cannot.** D6's cross-cell byte identity; D7's LF-through-a-binary-port on the one platform whose text ports translate; the probe's own portability across the three binary names.

**Section 4 — What is not proposed.** No pipeline, no runner configuration, no workflow file. Those are spike §7 D8, in Milestone 1 per [0007](../decisions/0007-milestone-0-closes-at-the-harness.md).

- [ ] **Step 4: Verify the note does not overstate the separator**

```bash
rg -n -i "separator" docs/plans/milestone-0-ci-feasibility.md
```

Read every hit. Each must be scoped to the `--libdirs`/`CHEZSCHEMELIBDIRS` string form and must be accompanied by the statement that this project does not use it. A sentence presenting the separator as a live Windows exposure of byte-machine is wrong and must be rewritten — [0002](../decisions/0002-shared-body-include-mechanism.md) closed it by construction.

- [ ] **Step 5: Verify links, then commit**

Run the Step 4 link checker from Task 1 with `docs/plans/milestone-0-ci-feasibility.md` in the file list. Expected `broken: 0`.

```bash
git add docs/plans/milestone-0-ci-feasibility.md
git commit -m "docs: add the Tier 1 CI feasibility note, discharging M0 exit criterion 2"
```

---

### Task 3: Sweep the parent plan (rows P1–P14)

**Files:**
- Modify: `docs/plans/byte-machine-implementation-plan.md`
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: `0007` (Task 1), `milestone-0-ci-feasibility.md` (Task 2) — both are link targets here.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Apply the eleven find/replace rows**

Apply in this order. Each FIND is unique in the file; verify with `rg -nF` before each edit if unsure.

| Row | FIND | REPLACE |
| --- | --- | --- |
| P1 | `The functional core, runtime body, generated body, and shared tests live in wrapper-free \`.scm\` files.` | `The functional core and the tests are inline R6RS \`.sls\` libraries and \`.sps\` programs ([decision 0006](../decisions/0006-inline-libraries.md)). The form of the runtime and *generated* bodies is fixed by §9.6 and is Milestone 1's to settle — see [the Milestone 0 close-out](./milestone-0-close-out.md) §9.` |
| P2 | `5. including that generated body from a consumer library wrapper;` | `5. including that generated body from a consumer library wrapper — this conflicts with §7.2's "No Scheme file in this repository includes another", and Milestone 1 must resolve it (see [the Milestone 0 close-out](./milestone-0-close-out.md) §9);` |
| P3 | `- rejection of output bindings that collide with portable Scheme syntax, runtime exports, or emitted internal identifiers;` | `- rejection of output bindings that collide with syntax or declaration identifiers reserved by the R6RS source mode, runtime exports, or emitted internal identifiers;` |
| P4 | `` `emit-machine` writes only to the supplied binary output port through a portability shim (`put-u8` versus `write-u8`). `` | `` `emit-machine` writes only to the supplied binary output port with `put-u8`. `` |
| P5 | `- confirmed R6RS library and include strategy;` | `- confirmed R6RS library strategy — inline \`.sls\`, no includes ([decision 0006](../decisions/0006-inline-libraries.md));` |
| P6 | `- shared hello-library body loaded through its owner wrapper;` | *(delete the whole line)* |
| P7 | `- a cross-library smoke path where one provisional owner wrapper constructs a placeholder tagged value, another wrapper recognizes it, and runtime singleton identity is retained across both imports;` | `- a cross-library smoke path where one provisional library constructs a placeholder tagged value, a second library recognizes it, and runtime singleton identity is retained across both imports;` |
| P8 | `- Tier 1 CI feasibility notes;` | `- Tier 1 CI feasibility notes (discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md));` |
| P9 | `- deterministic text emission proof across the Chez source and AOT lanes;` | *(delete the whole line)* |
| P10 | `- identifier repertoire and binary LF emission proof across available operating systems;` | *(delete the whole line)* |
| P11 | `- documented Windows path and LF behavior.` | `- documented Windows path and LF behavior (discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md)).` |
| P12 | `- the same shared test body passes in both the source and AOT execution lanes;` | `- the same test program passes in both the source and AOT execution lanes;` |

- [ ] **Step 2: Insert the Milestone 0 close note (row P13)**

Immediately after the line `- each library owns its own code — no shared include bodies ([decision 0006](../decisions/0006-inline-libraries.md)).`, insert a blank line and then:

```markdown
> **Closed 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).**
> The three deliverables above that this milestone did not ship — deterministic
> text emission, the identifier and binary-LF proof, and CI — move to Milestone 1,
> where each has a subject: Milestone 0 ships no emitter, and the first two are
> properties of one. See [the close-out](./milestone-0-close-out.md).
```

- [ ] **Step 3: Insert the Milestone 1 arrival note (row P14)**

Immediately after the line `### Milestone 1: Minimal executable machine` and before the line `Scope:`, insert a blank line and then:

```markdown
> **Amended 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md):
> Milestone 0's D6, D7, and D8 land here.** D6 on "deterministic output"; D7 on
> "symbolic name resolution" and "generated-name safety for every construct
> present". Those two lines already exist and now carry Milestone 0's obligations
> too. D8's CI pipeline has no Scope line of its own and rides D6's cross-cell
> axis, because both need the same Tier 1 cells: Milestone 1 stands the pipeline
> up over the emitter, and Milestone 9 below — whose Scope already owns "complete
> Tier 1 CI" and "source generation equality across platform cells" —
> completes it. "Complete" presupposes something to complete.
```

- [ ] **Step 4: Verify the Deliver list still reads correctly and the deletions took**

```bash
sed -n '/^### Milestone 0: Portability and harness spike/,/^### Milestone 1:/p' docs/plans/byte-machine-implementation-plan.md
```

Expected: the Deliver list has seven bullets (three were deleted), the last ends with a period, "shared hello-library body" and "owner wrapper" are gone, "Tier 1 CI feasibility notes" and "documented Windows path and LF behavior" both carry their discharge parenthetical, the three exit criteria are present with criterion 1 reading "the same test program", and the close note follows them.

- [ ] **Step 5: Verify no retired vocabulary survives in the swept sections**

```bash
rg -n -i "shared test body|shared hello-library|owner wrapper|portability shim|write-u8|portable Scheme syntax|and include strategy" docs/plans/byte-machine-implementation-plan.md
```

Expected: no output. If §7.2's heading "Library wrappers" or §22's "portability wrapper tests" appear, they are out of this row set — leave them and note them in the ledger.

- [ ] **Step 6: Verify links, then commit**

Run the Task 1 link checker with `docs/plans/byte-machine-implementation-plan.md` in the file list. Expected `broken: 0`.

```bash
git add docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: sweep the parent plan and close Milestone 0 in it"
```

---

### Task 4: Sweep the spike (rows S1–S17)

The largest task. Seventeen rows in one file, none of which touches code.

**Files:**
- Modify: `docs/plans/milestone-0-portability-spike.md`
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: `0007` (Task 1), `milestone-0-ci-feasibility.md` (Task 2).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Replace the Status line (row S1)**

FIND the whole of line 3, which begins `Status: in progress — slices 1 through 5b delivered`. REPLACE with:

```markdown
Status: closed 2026-08-22 — slices 1 through 5 delivered, 5b in two halves (2026-08-18, PR #6; remainder 2026-08-21, [milestone-0-slice-5b-remainder-implementation-plan.md](./milestone-0-slice-5b-remainder-implementation-plan.md)), closing D5 at the two Chez lanes (dated note at D5 below); slice 5c cancelled by decision 0005 (amendment notes below); §7 deliverables D6, D7, and D8 moved to Milestone 1 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md). [The close-out](./milestone-0-close-out.md) records what closed and what moved.
```

- [ ] **Step 2: Carve instructions out of the header pledge (row S2)**

FIND `> [chez-only-simplification.md](./chez-only-simplification.md).` and append these lines directly beneath it, inside the same blockquote:

```markdown
> **Amended 2026-08-22:** the pledge above covers this document's *records* —
> the §2 environment facts and the §3 findings. Its *instructions* — the §5
> decision table, the §7 deliverable entries, the §8 work order, the §11 scope
> bullet, the §12 exit criteria, and §13 — are corrected in place when they
> would misdirect, each correction dated. See
> [the Milestone 0 close-out](./milestone-0-close-out.md) §5.
```

- [ ] **Step 3: Correct §5's D2 row and add the CI note (row S3)**

FIND `CI now covers macOS arm64 + Linux amd64 for both implementations; full 8-cell Tier 1 matrix lands in Milestone 9` and REPLACE with `CI is to cover macOS arm64 + Linux amd64; the remaining Tier 1 cells land in Milestone 9`.

Then, immediately after the §5 table (before the `## 6.` heading), insert:

```markdown
> **Amended 2026-08-22.** No CI exists in any commit of this repository; D2's
> present tense above was corrected to the future. D8 moved to Milestone 1 by
> [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).
> Under Chez-only, Tier 1 is four cells and not eight (parent plan §7.3): D8's
> CI covers two, and two — Linux arm64 and Windows amd64 — are deferred.
```

- [ ] **Step 4: Correct the §7 deliverable entries (rows S4–S12)**

Apply these nine, in order. All FIND strings are unique.

| Row | FIND | REPLACE |
| --- | --- | --- |
| S4 | `Probe-based detection for both runtimes, banner-verified, rejecting Petite and GhostScript. Pinned minimum versions recorded.` | `Probe-based detection, banner-verified, rejecting Petite and GhostScript. Pinned minimum version recorded.` |
| S5 | `\`src/common/\`, \`src/chez/\`, \`src/gambit/\`, \`test/\`, \`build/\` (gitignored), \`docs/decisions/\`.` | `\`src/byte-machine/\`, \`test/\`, \`build/\` (gitignored), \`docs/decisions/\`.` |
| S6 | `- **D2 — Shared body loaded through both wrappers.**` | `- **D2 — Shared body loaded through both wrappers.** *(Retired — see note below.)*` |
| S7 | `Owner wrapper constructs a placeholder tagged vector; a second wrapper recognises it;` | `One library constructs a placeholder tagged vector; a second library recognises it;` |
| S8 | `shared assertion/result code, thin Chez and Gambit adapters owning imports, process exit codes, and compilation steps. Mirrors protium's harness structure; adapters on both runtimes must export exactly the same names.` | `assertion and result code in one library, a thin Chez runner owning imports, process exit codes, and compilation steps. Mirrors protium's harness structure.` |
| S9 | `- **D5 — Execution lanes.** Chez source, Chez AOT, Gambit \`.o1\`, Gambit \`-exe -nopreload\`. Compiled lanes must be unable to silently fall back to source.` | `- **D5 — Execution lanes.** Chez source and Chez AOT. Compiled lanes must be unable to silently fall back to source.` |
| S10 | `Both implementations write byte-identical canonical UTF-8/LF output through a project-owned writer; compared by fingerprint, never via implementation \`write\` formatting.` | `Byte-identical canonical UTF-8/LF output through a project-owned writer; compared by fingerprint, never via implementation \`write\` formatting.` |
| S12 | `- **D8 — CI (macOS arm64 + Linux amd64, both implementations)** plus written feasibility notes for the four deferred Tier 1 cells.` | `- **D8 — CI (macOS arm64 + Linux amd64)** plus written feasibility notes for the two deferred Tier 1 cells.` |

Then add these dated notes, each directly beneath the entry it annotates, indented as a blockquote inside the list item (matching D5's existing note):

**Beneath D0 (row S4):**
```markdown
  > **Amended 2026-08-22:** one runtime, not two ([decision 0005](../decisions/0005-chez-only.md)).
  > The GhostScript classification is *not* removed with Gambit: it survives the
  > cut and is still specified and mutation-tested at
  > `test/support/cmake/ByteMachineChezSpec.cmake:51-53`, `:118`, and `:162`.
```

**Beneath D2 (row S6):**
```markdown
  > **Retired 2026-08-22, effective [decision 0006](../decisions/0006-inline-libraries.md)
  > (2026-08-18):** there is no shared body and no `.sld`, and the
  > repository-wide basename check narrowed to `byte_machine_add_scheme_lane`'s
  > per-lane uniqueness check. Delivered in slice 3 and dismantled by the include
  > collapse. The entry stays because the slice that shipped it is real history.
```

**Beneath D6 (row S10):**
```markdown
  > **Moved to Milestone 1 on 2026-08-22 by
  > [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).** A
  > writer belongs to an emitter, and Milestone 0 ships no emitter (§11). Parent
  > plan §25's Milestone 1 Scope already carries "deterministic output". The
  > cross-cell half of the claim rides with D8, which needs the same cells.
```

**Beneath D7 (row S11 — the entry text itself is unchanged):**
```markdown
  > **Moved to Milestone 1 on 2026-08-22 by
  > [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).**
  > Lands on parent plan §25's Milestone 1 Scope lines "symbolic name resolution"
  > and "generated-name safety for every construct present". Note for Milestone 1:
  > parent §9.2's reserved-output-binding set has three members, and only the
  > first — R6RS source-mode syntax and declaration identifiers — is enumerable
  > before `(byte-machine runtime)` and the emitter template exist, so parent
  > §22.9's "Reject every canonical reserved output binding" must be scoped to
  > the members that exist when it runs.
```

**Beneath D8 (row S12) — one note covering both halves:**
```markdown
  > **Amended 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).**
  > The pipeline moves to Milestone 1, beside D6's cross-cell axis. The written
  > feasibility notes are discharged by
  > [the CI feasibility note](./milestone-0-ci-feasibility.md). "Four deferred
  > cells" was written against a four-platform, two-runtime matrix; Chez-only
  > Tier 1 is four cells total (parent plan §7.3), so two are deferred — Linux
  > arm64 and Windows amd64.
```

- [ ] **Step 5: Replace work-order items 6 and 7 with one item (row S13)**

FIND both lines:

```markdown
6. **Deterministic emission + identifier/LF proofs** (D6, D7). Exit: byte-identical output across implementations; every rejection case rejected.
7. **CI + decision records** (D8, D9). Exit: green on both cells; deferred cells documented, not assumed.
```

REPLACE with the single line:

```markdown
6. **Milestone 0 close-out** (D9 completed; D6, D7, D8 moved to Milestone 1). Exit: both governing documents record the milestone as closed, the three moved deliverables land on named Milestone 1 Scope lines, and no instruction outside a dated record names a retired concept. See [the close-out](./milestone-0-close-out.md).
```

- [ ] **Step 5b: Disposition the completed work-order items (row S18)**

Items 1 through 5 of §8 still name two runtimes, two wrappers, and four lanes.
They are *completed* instructions, which by the rule in the design's §5 have
become the record of what was asked — so they get a dated block and no rewrite,
exactly as §12's criteria do. Insert directly beneath work-order item 6:

```markdown
> **Dispositioned 2026-08-22 at close ([decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md)).**
> Items 1 through 5 are delivered, and their exits are left exactly as written
> for the reason [the close-out](./milestone-0-close-out.md) §5 gives: a completed
> instruction is the record of what was asked, and rewording it to match what
> shipped edits the bar. Items 1 through 4 were met under the contract of their
> day — two runtimes, two wrappers — and item 5 closed at **two** of the four
> lanes it names, per §7 D5's dated note and §12's disposition (4): the two Gambit
> compiled lanes were cancelled with slice 5c before they existed, and `chez.aot`
> landed after Gambit was already gone, so the four were never green together.
> What survives decisions 0005 and 0006 is stated at the §7 deliverable entries
> and in §12's dispositions, not here. Item 6 replaces the original items 6 and
> 7; [the close-out](./milestone-0-close-out.md) §1 says why the original item 6
> could not be executed.
```

- [ ] **Step 5c: Extend the §5 note to cover D5 (row S19)**

§5's D5 row reads "Execution lanes follow protium's four-lane model, plus
byte-machine's own cross-implementation generated-source comparison". Same
treatment. Append these lines to the dated block Step 3 added under the §5 table:

```markdown
> D5's row is left as written for the same reason: it records a decision that was
> taken, and the dated note at §7's D5 entry states where execution lanes
> actually closed.
```

- [ ] **Step 5d: Widen row S2's carve-out (row S20)**

Row S2's amendment tells the reader that §5's decision table, §8's work order,
and §12's exit criteria "are corrected in place when they would misdirect" —
but rows S16, S18, and S19 deliberately do not correct those three in place.
Append one sentence to the S2 blockquote:

```markdown
> Where a completed instruction has become the record of what was asked, it gets
> a dated disposition instead of a correction — §5's D5 row, §8's items 1–5, and
> §12's criteria.
```

- [ ] **Step 5e: Fix §13's residual plural (row S21)**

Row S17 made §13's first sentence singular, but the same sentence pair still ends
"→ emitter and runtime → the §9.6 examples". Parent §9.6 specifies "one
executable Chez example program".

| Row | FIND | REPLACE |
| --- | --- | --- |
| S21 | `→ the §9.6 examples.` | `→ the §9.6 example.` |

- [ ] **Step 6: Add the §9 questions disposition block (row S14)**

Do **not** rewrite the seven questions. FIND `Questions 5–7 may be answered as "deferred, with rationale" if Milestone 0 cannot reach them without implementing semantics; 1–4 are hard requirements.` and insert directly beneath it:

```markdown
> **Dispositioned 2026-08-22 at close ([decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md)),
> which carries the answers.** Questions 1–4 are answered there, each with its
> evidence level stated — a pin with an open floor (1), the shipped launchers
> (2), closure by absence and by construction (3), closure by decision (4). Not
> all four are answered by test, and 0007 says which are not. Question 3's
> separator half was already closed by construction in
> [decision 0002](../decisions/0002-shared-body-include-mechanism.md): this
> project never joins Chez search paths with a separator. Question 6 rides with
> D7 to Milestone 1.
```

- [ ] **Step 7: Correct the scope bullet and the sequencing line (rows S15, S17)**

| Row | FIND | REPLACE |
| --- | --- | --- |
| S15 | `and the full 8-cell matrix.` | `and the full Tier 1 matrix.` |
| S17 | `deterministic output, and two cross-implementation examples.` | `deterministic output, and the parent plan's §9.6 example.` |

- [ ] **Step 8: Add the §12 disposition block (row S16)**

Do **not** rewrite the nine criteria — rewording "all four execution lanes" to "two lanes" would edit the bar to match the result. Insert directly beneath the ninth bullet (`- §30 questions 1–4 are answered in \`docs/decisions/\` and backed by tests.`):

```markdown
> **Dispositioned 2026-08-22 at close ([decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md)).**
> These criteria were written before decisions 0005 and 0006. What each came to,
> in order: (1) **met** on both Chez lanes; the second runtime went with 0005, and
> the working-directory matrix — an include-resolution proof — with 0006.
> (2) **met**: each library owns its own code (0006). (3) **met** on both Chez
> lanes. (4) **met at two lanes**, per D5's note above. (5) **moved** to
> Milestone 1 — D6. (6) **met**; the GhostScript classification survives the
> removal of the `gsc` it guarded against and is still specified and
> mutation-tested. (7) **moved** to Milestone 1 — D8. (8) **met**, at two
> deferred cells, by [the CI feasibility note](./milestone-0-ci-feasibility.md).
> (9) **met**: parent plan §30 questions 1–4 are answered in
> [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md), each
> with its evidence level stated.
```

- [ ] **Step 9: Verify the record sections were not touched**

```bash
git diff docs/plans/milestone-0-portability-spike.md | rg "^[-+]" | rg -i "Homebrew renames|Probe by banner|never search for|1 of 8|4.9.8|include-relative"
```

Expected: no output. Any hit means an edit reached spike §2, §3, or §6 — all records. Revert it.

- [ ] **Step 10: Verify the instruction sections are clean**

```bash
rg -n -i "both runtimes|both implementations|both wrappers|owner wrapper|8-cell|cross-implementation|Gambit .o1|four deferred" docs/plans/milestone-0-portability-spike.md
```

Read every hit. Each must be inside spike §2's table, spike §3, spike §5's D6 row, spike §6, or a dated blockquote. Any hit in §7's entry text, §8, §11, §12, or §13 is a missed row.

- [ ] **Step 11: Verify links, then commit**

Run the Task 1 link checker with `docs/plans/milestone-0-portability-spike.md` in the file list. Expected `broken: 0`.

```bash
git add docs/plans/milestone-0-portability-spike.md
git commit -m "docs: sweep the milestone plan and close it at the harness"
```

---

### Task 5: The never-true CI claims, two comments, and the CHANGELOG preamble

The only task that edits files CMake reads, so the only one before Task 7 that runs the suite.

**Files:**
- Modify: `docs/decisions/0001-toolchain-discovery.md` (row R1)
- Modify: `cmake/ByteMachineTesting.cmake` (row L1)
- Modify: `test/CMakeLists.txt` (row L2)
- Modify: `CHANGELOG.md` (row C1)
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: `0007` (Task 1).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Establish that no CI has ever existed, before annotating that it never did**

```bash
git log --all --diff-filter=A --name-only --pretty=format: | sort -u | rg -i "^\.github|workflow|\.gitlab|azure-pipelines|\.circleci" ; echo "exit=$?"
```

Expected: no matching paths (`exit=1` from `rg` finding nothing). This is the evidence for the word "never" in the annotation. If anything matches, the annotation is wrong and this is a plan defect to report.

- [ ] **Step 2: Annotate 0001, do not edit it (row R1)**

The claim at `docs/decisions/0001-toolchain-discovery.md:86` is category 3 — false when written, not superseded, and load-bearing (it is cited as evidence for that record's own Consequences). Leave the sentence exactly as it stands. Append a note at the end of the file:

```markdown

## Note added 2026-08-22

The sentence above, "It runs in CI as
`byte-machine.harness.cmake-mutation.cmake.direct`", **was never true**. No CI
has existed in any commit of this repository; verified by
`git log --all --diff-filter=A --name-only` on 2026-08-22. The lane is real and
runs under `ctest`.

The claim is annotated rather than corrected because it is load-bearing — it is
offered as evidence for this record's own Consequences, and a reader checking
that reasoning needs to see what was actually claimed. This is not a
supersession: nothing changed the world, the sentence was wrong on the day it
was written.

Deliverable D8 (CI) moved to Milestone 1 by
[decision 0007](./0007-milestone-0-closes-at-the-harness.md).
```

- [ ] **Step 3: Correct the two live-code comments (rows L1, L2)**

| Row | File | FIND | REPLACE |
| --- | --- | --- | --- |
| L1 | `cmake/ByteMachineTesting.cmake` | `  determinism   # byte-identical emission across runs and runtimes` | `  determinism   # byte-identical emission across runs, lanes, and platform cells` |
| L2 | `test/CMakeLists.txt` | `# notice. It runs in CI because evidence that only exists in someone's terminal` | `# notice. It runs under \`ctest\` because evidence that only exists in someone's` |

Row L2's comment spans two lines. After the edit the pair must read:

```cmake
# notice. It runs under `ctest` because evidence that only exists in someone's
# terminal cannot fail when the code changes.
```

So the following line also changes, from `# cannot fail when the code changes.` to `# terminal cannot fail when the code changes.`

Do **not** change `test/support/cmake/MutationRunner.cmake:6` ("runnable in CI") — a capability claim, true of any `cmake -P` script, and not an assertion that a CI exists.

- [ ] **Step 4: Correct the CHANGELOG preamble (row C1)**

FIND `Milestone 0 (portability and harness spike) is in progress. No public API` and REPLACE with:

```markdown
Milestone 0 (portability and harness spike) closed on 2026-08-22; see
[the close-out](docs/plans/milestone-0-close-out.md). No public API
```

Leave the rest of the paragraph and every entry in `### Added`, `### Changed`, `### Removed`, and `### Fixed` untouched — those are records of what shipped and what was cut, including 28 historical Gambit mentions.

- [ ] **Step 5: Verify the L1 comment did not disturb the layer vocabulary**

```bash
rg -n -A12 "set\(BYTE_MACHINE_TEST_LAYERS" cmake/ByteMachineTesting.cmake
```

Expected: ten layer tokens, unchanged, with only the `determinism` comment differing. The token itself must still be present — it is already inside the `pr` preset's label regex and Milestone 1's determinism lanes will use it.

- [ ] **Step 6: Run the full matrix — this task touched files CMake reads**

```bash
make clean && make test
```

Expected: `100% tests passed, 0 tests failed out of 37`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: 8/8. Then confirm the mutation totals did not move:

```bash
rg -n "^set\(EXPECTED_(PASSES|MUTATIONS)" test/support/cmake/MutationSuite.cmake test/support/cmake/SchemeMutationSuite.cmake
```

Expected: 1 CMake mutation pass over 72 mutations, and 31 Scheme passes over 68 — the declared constants, unchanged by this branch.

- [ ] **Step 7: Commit**

```bash
git add docs/decisions/0001-toolchain-discovery.md cmake/ByteMachineTesting.cmake test/CMakeLists.txt CHANGELOG.md
git commit -m "docs: annotate the never-true CI claims and correct two live comments"
```

---

### Task 6: The AGENTS.md standard, CHANGELOG entries, and the ledger

**Files:**
- Modify: `AGENTS.md`
- Modify: `CHANGELOG.md` (row C2)
- Modify: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: everything from Tasks 1–5 — the CHANGELOG entries describe them.
- Produces: nothing.

- [ ] **Step 1: Read the existing AGENTS.md bullets for their form**

Every bullet in the guidelines list states a rule, then the demonstrated defect that earned it, with a site pointer. The W9 bullet (`SchemeMutationSuite passes 30/31`) is the closest model. A bullet that states a rule with a statistic instead of an instance does not match the file's convention.

- [ ] **Step 2: Add the record/instruction bullet**

Insert after the bullet ending `(SchemeMutationSuite passes 30/31).` and before the bullet beginning `* Libraries are R6RS \`.sls\``:

```markdown
* A stale sentence is corrected or annotated according to what it does, not
  which file it sits in. A **record** — a measurement, a finding, a decision
  record's Context — gets an amendment note, because a record edited to agree
  with a later decision stops being evidence of anything. An **instruction** —
  a work order, an exit criterion, a Deliver or Scope list, a deliverable
  entry, or a comment in live code saying what the code is for — gets corrected
  in place, because leaving a false one is not preserving evidence, it is
  leaving a landmine, and what it used to say is in git. Two corollaries the
  close-out paid for: a record *document* still contains instruction sentences
  (the milestone plan's header pledges it keeps all its Gambit content, and its
  §7 deliverable entries still had to be corrected — so the pledge was scoped
  to name which sections it covers), and a sentence that was **never true** is
  a third case, annotated rather than fixed when it is load-bearing
  (docs/decisions/0001-toolchain-discovery.md's claim of a CI that has never
  existed). The demonstrated defect: milestone-0-portability-spike.md's
  work-order item 6 instructed an exit — "byte-identical output across
  implementations" — that decision 0005 had made impossible, and it survived
  two further slices — the include collapse (PR #8) and the 5b remainder
  (PR #10), each with its own plan, review, and merge — before anyone read it
  against the tree. Status lines are instructions too: a slice that closes a milestone is
  not done until the milestone plan, the parent plan, and CHANGELOG.md all say
  it closed.
```

- [ ] **Step 3: Add the CHANGELOG entries (row C2)**

Under `### Changed`, add entries for: the Milestone 0 close and the move of D6/D7/D8 to Milestone 1; the parent-plan and milestone-plan sweeps; the corrected Tier 1 cell arithmetic (four cells, two deferred, not four); the `determinism` layer comment; the `cmake-mutation` lane comment; and the 0001 annotation.

Under `### Removed`, add the three deleted Deliver bullets by name — "shared hello-library body loaded through its owner wrapper", "deterministic text emission proof across the Chez source and AOT lanes", and "identifier repertoire and binary LF emission proof across available operating systems" — stating that the first is retired with decision 0006 and the other two moved rather than being dropped.

Under `### Added`, add the two new documents and decision 0007.

Match the existing entries' voice: they say what changed and why it mattered, not what file was edited.

- [ ] **Step 4: Verify AGENTS.md still parses as one list**

```bash
rg -c "^\* " AGENTS.md
```

Expected: `19`. The file carries 18 bullets before this task (measured 2026-08-22 at `ceb0894`), and this task adds exactly one.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md CHANGELOG.md
git commit -m "docs: record the record/instruction standard and the close in CHANGELOG"
```

---

### Task 7: Verification and close

No new content. This task proves the branch met its own exit criteria.

**Files:**
- Modify: `.superpowers/sdd/progress.md`

- [ ] **Step 0: Re-verify every line citation into the two governing plans, and strip the stale ones**

Tasks 3 and 4 shifted lines throughout `byte-machine-implementation-plan.md` and
`milestone-0-portability-spike.md`. Every `§N:NNNN` citation into either file,
written anywhere on this branch, is now suspect. Audit them:

```bash
python3 -c '
import re,glob
tgt={"parent":open("docs/plans/byte-machine-implementation-plan.md").read().split(chr(10)),
     "spike":open("docs/plans/milestone-0-portability-spike.md").read().split(chr(10))}
pat=re.compile(r"§\s?(\d+(?:\.\d+)?)\s?:\s?(\d{3,4})")
for f in glob.glob("docs/**/*.md",recursive=True)+["AGENTS.md","CHANGELOG.md"]:
    for i,line in enumerate(open(f).read().split(chr(10)),1):
        for m in pat.finditer(line):
            print(f"{f}:{i}  {m.group(0)}")
'
```

For every hit, open the cited line and check it says what the citing sentence
claims. Where it does not — or where the citation points into either governing
plan at all — **replace the line number with the section reference alone**
(`parent §25`, `spike §7 D6`, `parent §24.2`). Do not renumber to the new line:
the next edit to those files will break it again.

Leave line citations into files this slice does not edit exactly as they are —
the launchers, the harness, the CMake modules, and decisions 0002 through 0006.
Decision 0001 is appended to, not inserted into, so citations into it are safe.

Record in the ledger how many citations you audited, how many you stripped, and
any whose cited line said something other than what the sentence claimed — that
last class is a factual defect, not a formatting one, and needs its sentence
re-checked rather than just its citation removed.

- [ ] **Step 1: Run the scoped sweep gate**

Scoped to the two governing plan documents, the CMake tree, and AGENTS.md. `CHANGELOG.md` is **excluded** — its `### Added` and `### Removed` sections are records carrying 28 legitimate historical Gambit mentions; its preamble was checked in Task 5.

```bash
rg -n -i "gambit|\.sld|both implementations|both runtimes|two runtimes|four (execution )?lanes|shared (body|test body|grammar body)|owner wrapper|source-directories|8-cell|runs in CI" docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-0-portability-spike.md cmake test/CMakeLists.txt AGENTS.md
```

Read every hit and classify it. Expected-and-allowed: spike §2's environment table, spike §3, spike §5's D6 row, spike §6, any blockquote beginning `> **Amended`/`> **Moved`/`> **Retired`/`> **Dispositioned`, and AGENTS.md's own new bullet quoting the defect. Anything else is a missed row — fix it and re-run.

This is a grep, so it is an inventory check and not a vocabulary check — which is why Step 2 exists. Record the classification of every hit in the ledger.

- [ ] **Step 2: Read the two governing documents end to end**

Read `docs/plans/milestone-0-portability-spike.md` and `docs/plans/byte-machine-implementation-plan.md` §25 in full, looking for the *idea* rather than the word: a sentence asserting a contract the project has retired, or instructing work that cannot be done. AGENTS.md's own standard says a removal gate that greps the departed name is an inventory check; the Chez-only cut cleared every file while "both runtimes" and "parity proof" survived in live comments.

Record in the ledger that this pass happened, what was read, and what it found — including "nothing" if that is the answer. An exit criterion with no artifact cannot be checked at review.

- [ ] **Step 3: Confirm the milestone reads as closed in all three places**

```bash
rg -n "closed 2026-08-22" docs/plans/milestone-0-portability-spike.md; rg -n "Closed 2026-08-22" docs/plans/byte-machine-implementation-plan.md; rg -n "closed on 2026-08-22" CHANGELOG.md
```

Expected: one hit each. A close that only the close-out document knows about has not happened.

- [ ] **Step 4: Confirm the three moved deliverables have a destination record**

```bash
rg -n -B2 -A6 "### Milestone 1: Minimal executable machine" docs/plans/byte-machine-implementation-plan.md
```

Expected: the arrival note from Task 3 Step 3, naming all three landing lines. A departure note without an arrival note leaves the deliverables nowhere.

- [ ] **Step 5: Run the full matrix fresh**

```bash
make clean && make test
```

Expected: `100% tests passed, 0 tests failed out of 37`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme
```

Expected: 8/8.

- [ ] **Step 6: Verify every link in every touched document resolves**

```bash
python3 - <<'PY'
import re,os
files=["docs/plans/milestone-0-close-out.md","docs/plans/milestone-0-close-out-implementation-plan.md","docs/plans/milestone-0-ci-feasibility.md","docs/decisions/0007-milestone-0-closes-at-the-harness.md","docs/decisions/0001-toolchain-discovery.md","docs/plans/byte-machine-implementation-plan.md","docs/plans/milestone-0-portability-spike.md","CHANGELOG.md","AGENTS.md"]
bad=[]
for f in files:
    if not os.path.exists(f): print("ABSENT",f); continue
    d=os.path.dirname(f)
    for m in re.finditer(r'\]\(([^)#]+?)(#[^)]*)?\)',open(f).read()):
        t=m.group(1)
        if t.startswith(("http","mailto")): continue
        p=os.path.normpath(os.path.join(d,t))
        if not os.path.exists(p): bad.append((f,t))
for b in bad: print("MISSING",*b)
print("broken:",len(bad))
PY
```

**Expected: not zero.** The checker resolves every markdown link relative to the
file it appears in, and this plan and the design both *quote* link text destined
for other directories — a `./0007-…md` written for a note that lands in
`docs/decisions/` cannot resolve from `docs/plans/`. That pattern is established
here: `milestone-0-include-collapse-implementation-plan.md`, an already-merged
slice's plan, carries four such hits. So the criterion is **every hit is a quoted
link that resolves at its destination**, checked one by one, and no `ABSENT`
lines. A hit that is a live link, or a placeholder like `(…)`, is a defect.

- [ ] **Step 7: Write the final ledger entry and commit**

Record: every row landed, the Step 1 classification, the Step 2 reading pass and its findings, the fresh matrix results, and any row that was changed during execution — with the reason, following this file's convention of recording plan corrections in the ledger rather than only at the site.

```bash
git add
git commit -m "docs: record the close-out verification pass"
```

- [ ] **Step 8: Request review, then follow the closing ritual**

Use `superpowers:requesting-code-review` for a whole-branch review against the design document. Then AGENTS.md's closing ritual: squash-merge, fast-forward `main`, delete the branch locally and remotely, and reflect — durable facts to memory, project standards to AGENTS.md, and anything the code should say about itself to a comment at the site.
