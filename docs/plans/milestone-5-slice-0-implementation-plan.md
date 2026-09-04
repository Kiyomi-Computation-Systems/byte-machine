# Milestone 5 Slice ⓪ — the kind × position matrix and the diagnostic-code census

**Status:** Tasks 1 and 6 done. **Tasks 2-5 and 7 now run AFTER Slice ⓪b** (reordered
2026-09-03 — see §2). Task 1's fixture is measured byte-identical under ⓪b's new verifier, and
Task 6's census is expected to move from 31 sites to 28, which is its ratchet working.

*Citations corrected 2026-09-03.* Every `verify.sls:NNN` below was measured against the tree as
it stands. The first set was **stale on arrival**, by four lines: they were taken from a design
pass run against a worktree predating the commit that expanded a comment in that same file, and
the plan was written after that commit merged. Most consequentially, D-2's site was cited as
`:831`, which is the **live** `eof-reachable-stop` half of that `case`; the dead clause was
`:834`. This is the "citations into files you edit" trap — no grep or link check can see it,
because every cited line exists and holds plausible code. Written 2026-09-03 against `main` at `bafdbe1` (Milestone 4
closed). Every number below is **measured**, and the measurement is named beside it; where an
agent's figure disagreed with the tree, the tree won and the disagreement is recorded.

## §1 Why this is its own slice, before Milestone 5

Milestone 4 Slice ③ shipped **three verifier defects** that 368 mutations, a 50-pass mutation
suite, a clean whole-pass pin sweep and ten per-task gates all missed. All three are one shape:
a new node kind was taught to the shared accessors (`node-eof-target`, `node-out-targets`) and
**not** to the hand-written per-kind filters that consume them, where a missing kind is silent.
Two were Critical — one raised out of verification on a legal machine, the other accepted a
machine that then looped forever in both executors.

Every fixture missed all three **by construction**: each accumulate machine declared
`eof-target #f` and made the accumulate node the entry, so no EOF chain in the tree could reach
one. That is a **census** failure, not a fuzzing failure, and the instrument for a census is
exhaustive and deterministic, not random.

**Milestone 7 already owns the generative half** — §25's Milestone 7 scope names *bounded
invalid-machine generator*, *differential property suite* and *deterministic failure seed
reporting*. This slice is the part M7 does **not** own: a deterministic matrix, plus the
coverage ratchet that makes a future diagnostic code's fixtures mandatory as it lands rather
than in M7. M5 and M6 each add codes; the ratchet must precede them.

**Instrument validated before being planned.** 38 single-kind omissions were injected into a
copy of `verify.sls`: the matrix distinguishes **34**, including all three shipped Slice ③
defects. The 5 survivors are disjoint from it by construction and define exactly what the
diagnostic-code census must own (§7).

## §2 Two live defects the design already found

Both **pre-existing** — reproduced byte-identically on `main` — so neither is a Slice ③
regression, and both are this slice's opening charter.

### D-1 `machine-entry`'s own EOF path is never classified

`eof-terminal` is called from exactly two sites (`verify.sls:777`, `:830`); `machine-entry` is
neither, while `parser-finish!` on a fresh or reset parser starts precisely there
(`runtime.sls:212`, `:226`, `:548`). Measured, through both executors:

```
entry = stop                        verify ()  → parser-finish! → stopped
entry = finish                      verify ()  → parser-feed!   → finished
entry = field-action → stop         verify ()  → parser-finish! → stopped
entry = field-branch (both → stop)  verify ()  → parser-finish! → stopped
-- the same property one hop away, correctly rejected --
entry = pause → stop                verify (eof-reachable-stop)
dispatch eof-target = stop          verify (eof-reachable-stop)
```

§16.2:909 forbids the first four by name.

***Superseded 2026-09-03 — Slice ⓪b takes this fix, and runs BEFORE Slice ⓪'s Tasks 2-5.***
This paragraph read: *"Do not fix this in Slice ⓪. The one-line fix (a walk start at the entry)
was prototyped and changes 85 of 230 cells, most of it double-reporting — `BASE p4 stop` goes
from one `eof-reachable-stop` to two, which collides with §16.4:937-943's
one-finding-per-decision."* Both of its load-bearing claims are false:

- **§16.4:937-943 has no one-finding-per-decision rule.** It is a *contents* list. The gloss
  entered at `milestone-3-slice-1-implementation-plan.md:139` and propagated to fourteen citing
  sites until it read like spec. It was the stated reason for deferring this fix.
- **The 85-of-230 figure is skeleton-dependent and not reproducible.** The identical prototype
  measures **51/144** under one skeleton and **4/144** under another; a figure of this kind must
  name its skeleton. And "most of it double-reporting" is not corroborated — a third of the
  changed cells are duplicates, two thirds are new coverage. *The **recommended** shape (the
  parked set, derived) measures **zero** duplicates.*

The hole is real and Slice ⓪b closes it. **Tasks 2-5 now follow ⓪b**, because building 230
expected verdicts against a verifier about to change would derive a third of them twice, snap
eleven mutation anchors and move this slice's own site census from 31 to 28. The matrix was
supposed to justify the wait by measuring ⓪b's blast radius — measured, it **cannot see ⓪b's
central decision at all** (the gate change moves 0 of 144 cells).

### D-2 `verify.sls:834` is dead in the tree

`pass-eof-execution`'s last arm walks each byte-reachable pause's continuation and reports two
verdicts. Its `eof-reachable-stop` half is covered; its **`eof-zero-progress-cycle` half is
produced by nothing**. Measured: deleting that clause leaves all 26 runnable programs
byte-identical, 504 case-runs, zero failures.

It is the only site that can see a cycle beginning at a pause continuation with no dispatch
eof-target involved — and `parser-finish-op!` states in its own comment that it carries no
local cycle guard *because* it relies on this check. Same consequence as Slice ③'s Critical #2:
verifies clean, hangs both lanes. **Task 1 closes it**, with a five-node fixture.

## §3 The instrument: 230 cells, six axes

| Axis | Cells | ACCEPT | REJECT | What it is |
|---|---:|---:|---:|---|
| **A** base kind × position (advance only) | 144 | 128 | 16 | 9 kinds × 16 target-bearing positions |
| **B** self-reference | 19 | 6 | 13 | 15 advance (P1 has none) + the 4 that flip under `reexecute` |
| **C** dangling (target names no node) | 16 | 0 | 16 | 13 `missing-target`, 3 `invalid-eof-target` |
| **D** EOF verdict lattice | 25 | 9 | 16 | 5×5 through a field-branch, the only observable join |
| **E** EOF-chain (depth 2) | 24 | 0 | 24 | 4 walk starts × 6 hop kinds, hop's EOF → a stop |
| **F** named separators | 2 | 0 | 2 | two shapes no product axis expresses |
| **total** | **230** | **143** | **87** | |

Plus a separate **16-cell absence census**: 12 positions raise `byte-machine-contract-violation`
on `#f`, 3 are legally absent (`P4`, `P7`, `P16` — the machine default EOF error), and **1 has
gated existence** (`P10`: `error` must be a symbol exactly when the operation is fallible,
`infallible-field-operations` at `ir.sls:310`).

**Three measured facts that shape the build:**

- **Only two rules in the whole verifier are sensitive to a target's KIND** — `finish` in a byte
  position (12 cells, `non-eof-into-finish`) and `stop` in an EOF position (4 cells,
  `eof-reachable-stop`). The kind axis is nearly flat, which is why axes B–F carry the pins.
- **"Impossible by construction" is empty on the kind axis, structurally.** Every target slot is
  a bare symbol checked only by `require-symbol` (`ir.sls:62-65`), and a node constructor cannot
  see the machine's node list. *Every kind restriction in this system is necessarily a verifier
  check*, and there are exactly two.
- **Mode is irrelevant across the base matrix** — all 36 `reexecute` rows measured byte-identical
  to their `advance` twins. Do not pay for them. But **4 of 6 accepted self-cells flip** under
  `reexecute`; those 4 stay.

### §3.1 The skeleton decision, made explicitly

A **fixed** skeleton (host + placed node + all sinks always present) puts `unreachable-node` in
**144 of 144** base cells and swamps the signal. A **reachability-pruned** skeleton gives clean
records — measured: zero incidental `unreachable-node`, `missing-target`, `invalid-field-*`,
`duplicate-*` or `invalid-name` across all 230 — but makes the machine shape cell-dependent,
which is a masking hazard.

**Resolution: prune, and make the pruned node-name set part of the recorded value.** Each cell's
record is `(position kind node-names diagnostics)`, so a skeleton shift becomes a failed
comparison instead of a silent re-shaping.

## §4 Open questions — recorded, not guessed

**OQ-1 — the `machine-entry` column is unclassified.** §2's D-1. Four cells will fail a
§16.2-derived expectation on day one; that is the finding, not a baseline to freeze.

**OQ-2 — does §16.2:908 forbid *starting at* a finish terminal?** `entry = finish` verifies clean
and one byte returns `finished` without being examined. :908 says "into a finish terminal"; zero
hops is a real question, not an implementation edge.

**OQ-3 — the two halves of §16.2:908 contradict each other, and nothing witnesses it.** The check
exists at three sites under two gating rules: the diagnostic at `verify.sls:756` is
unconditional; those at `:801` and `:821` are gated on byte-reachability. Measured on six machines whose offending node is
EOF-only-reachable: pause / field-action / field-branch → ACCEPTED, dispatch-case / seq-case /
accumulate-digit → REJECTED. Whichever half is right, the other is wrong.

**OQ-4 — diagnostic multiplicity is not one per decision.** Measured: a field-branch with both
arms on one finish node emits `non-eof-into-finish` **twice**; a byte-dispatch with two cases
plus a fallback emits it **three times**. §16.4:937-943 asks for one finding per decision, and
`pass-overlap` / `pass-sequence-ambiguity` both enumerate pairs `i<j` for exactly that reason;
the :908 sites do not. **Consequence: the per-cell oracle is a sorted multiset, never a set and
never a boolean.**

**OQ-5 — four of the six EOF verdicts carry no observable consequence.** `eof-verdict-ranking` is
a 6-element list (`verify.sls:658`) and decision 0021 item 1 pins only `cycle > eof-reachable-
stop`. Four independent mutations survive all 230 cells: permute the low four ranks; `classify`
finish→error; `classify` error→finish; `dispatch-arm` `#f`→`'unresolved`. Record as a spec
finding; **do not** write a sentinel pretending the ranking has six decisions.

## §5 Tasks — seven commits, house style

Failing tests first, then implementation, then mutations measured **in both directions**.

New program: **`test/common/kind-position-census-tests.sps`**. Not `position-kind-tests.sps`,
which exists and means §12.7's parser-error position kinds — an unrelated thing.

- [x] **Task 1 — close the dead pause-continuation EOF-cycle site.** One harness-group in `verify-tests.sps`: entry
  dispatch —advance→ `p` (pause) → `q` (pause) → `p`, dispatch `eof-target` = a finish node.
  Pristine emits `eof-zero-progress-cycle` at both pauses; the pair *(that code, a PAUSE node
  name)* is producible **only** by site 831. First, because it needs no census machinery and its
  mutant survives the entire shipped suite today.

  **Done.** The fixture is in `verify-tests.sps`; the machine's entry routes its own EOF to a
  finish, so the *other* `eof-zero-progress-cycle` site has nothing to say and cannot be the
  source of the records. Measured pristine: `zero-progress-cycle` at `p` and `q`, and
  `eof-zero-progress-cycle` at `p` and `q`. The assertion is written on the **pair**
  *(`eof-zero-progress-cycle`, a pause node)* rather than on the count of four, because §16.4's
  one-finding-per-decision is Slice ⓪b's OQ-4 and the count may legitimately drop; the pair
  survives any de-duplication. One mutation, measured caught by this group alone.
  `release` 94/94, 50 passes / **369** mutations.
- [x] **Task 2 — the tables, axis A, and the sentinels.** Done, and **after ⓪b**, which is why
  all 144 cells matched their §16.2-derived expectations on the first clean run. Built before
  ⓪b, the four entry-column cells would have been red on day one — H1's mandate was to record
  that as a finding, and the reorder made the finding a fix instead.

  Nine kinds and sixteen positions **as data**, so the product is a derivation rather than a
  literal. Expected verdicts derived from the two rules that are actually kind-sensitive
  (§16.2:908's finish, §16.2:909's stop), never observed.

  **The skeleton is pruned using the verifier's own answer** — building the cell with the shared
  sink, and rebuilding without it when the verifier calls it unreachable. Computing reachability
  in the test would have meant re-implementing `node-out-targets`: a second census, the exact
  thing this instrument exists to catch.

  **S2 is the ratchet, and its mutation is caught by the matrix ALONE** — `node?`'s disjunct list
  *is* the closed set, and the table's coverage is derived from it. When M5 adds a callback kind
  this row goes red before any fixture does. `release` 98/98, 52 passes / 373 mutations. The 16 position builders and 9 kind
  builders as **data** (two association lists), the pruning closure, §3.1's record shape, and
  **S1+S2 land here, not later** — the sentinel is what makes a Milestone 5 callback kind fail
  before it fails a fixture.
- [x] **Task 3 — the self axis (19).** Done. Fifteen positions with a self variant (the entry
  has none — a machine is not a node), four of them twice because they carry a mode and flip
  under `reexecute`. **Every cell matched its derived verdict on the first run**, deriving from
  the progress rules rather than from observation: a byte edge that advances makes progress, so a
  self-loop through it is legal; a sequence case always consumes (§10.6:546) and an accumulate
  digit edge advances (§10.6:566), so both are legal self-loops by design.

  This is the axis a scoping cut would reach for first, and it is the one carrying the pause
  EOF-cycle site's **second, independent** coverage — the site that was dead in the suite until
  Task 1. Including the 4 `reexecute` rows; *not* the base matrix's
  36 mode rows. This is the commit that covers `verify.sls:834` a **second** way (`SELF p8`).
- [x] **Task 4 — the dangling axis and the absence census.** Done. Fifteen dangling cells (the
  entry's host list is empty, so it has none to build), each deriving its fault from the route:
  §16.2:905's `missing-target` for a byte edge, `invalid-eof-target` for the three EOF routes —
  a different fault, because `#f` there is *legal* and means the machine default, so a symbol
  resolving to nothing is a distinct mistake.

  The absence census is where "impossible by construction" actually lives. The **kind** axis has
  no constructor refusals at all — every target slot is a bare symbol and a node constructor
  cannot see the machine's node list, which is *why* every kind restriction is necessarily a
  verifier check and there are exactly two. The absence axis has eight refusals, three legal
  absences, and **one conditional position**: a field action's `error`, gated on the operation's
  fallibility, asserted all four ways because it is the only cell in the matrix whose *existence*
  is conditional.
- [ ] **Task 5 — the EOF-chain axis (24), the verdict lattice (25), the two separators (2).**
  The task that converts all three shipped Slice ③ defects from raise-caught to
  **comparison-caught**.
- [x] **Task 6a — the source-derived census and the operand drift row.** Layers 1 and 2 of §7,
  plus S5. `verify.sls` and `ir.sls` are read as data and walked; the code set, the per-code
  site counts (16 codes, **31** sites, measured) and the fourteen operand names are derived from
  the artifacts, never declared in the test. Guards: every emitted code is a quoted symbol (32
  `make-diagnostic` forms, minus the definition header, subtracted **by name**), and each source
  file is exactly one datum. Two lanes, two mutations, a new pass 51 — the operand drift row's
  mutant is caught by the census **alone**. `release` 96/96, 51 passes / **371** mutations.

  *Plumbing, resolved more cheaply than §9's H5 feared:* one variable,
  `BYTE_MACHINE_SOURCE_ROOT`, and the mutation suite overrides it to `${STAGE_DIR}/src` **once**,
  beside where `STAGE_DIR` is defined — every `execute_process` in that script inherits it, so
  all 51 passes are covered by a single line rather than per-pass plumbing. Unset raises.

- [x] **Task 6b — fixture coverage (layer 3 of §7).** One machine per code — sixteen, each
  built and measured to emit its own code — iterated over the **source-derived** key set, with S4
  counting rows asserted inside the loop and comparing against the source-derived total rather
  than the fixture table's own length, so a missing row and a missing code cannot cancel. The
  discriminator is the code plus the machine's shape, **never** message text.

  **The ratchet is pinned by its own mutation.** Renaming one emitted code makes a code appear in
  the source with no fixture and no pinned row; measured, *both* layers fire — the derived code
  set stops matching the pinned table, and the source-derived loop finds a code nothing emits.
  Both are deliberate: the pinned table alone would let a code be accounted for on paper without
  ever being produced. `release` 96/96, 51 passes / **372** mutations.
- [ ] **Task 7 — the dispositions append and the mutation registrations.** Append under
  `## Dated dispositions` at `byte-machine-implementation-plan.md:1802` (file is 1825 lines;
  **never insert above** — AGENTS.md:324). Record OQ-1…OQ-5, the skeleton decision, that the
  census ships **green**, and that the matrix does **not** subsume the differential lanes.

## §6 Mutations — the axis each depends on

24 of 25 killed mutations carry a uniquely-failed record. The nine mutations distinguished by a
**single cell** are the reason §8's H3 matters.

| # | Mutation | Axis | Uniquely-failed record |
|---|---|---|---|
| M1 | `classify` accumulate arm → `'unresolved` — **shipped defect 1** | E | `(EOFCHAIN p16 integer-accumulate (eof-reachable-stop))` |
| M1b | `classify` accumulate arm **deleted** — defect 1 as it shipped | A | `(BASE p4 integer-accumulate (***RAISED***))` |
| M2 | :909 filter drops `integer-accumulate` — **shipped defect 2** | E | `(EOFCHAIN p16 byte-dispatch (eof-reachable-stop))` |
| M3 | :908 filter drops `integer-accumulate` — **shipped defect 3** | A | ⊂ M15 **by construction** (see below) |
| M8 | :831's `((cycle) …)` deleted — **the live hole** | B | `(SELF p8 advance (zero-progress-cycle))` |
| M10 | zero-progress REPORT set drops `pause` | B | `(SELF p8 advance (eof-zero-progress-cycle))` |
| M12 | zero-progress WALK drops the overflow edge | F | without axis F, M12 ⊂ M11 |
| M17 | swap the pinned top rank pair | F | the 3-way join separates it from M18 |
| M19 | `missing-target` entry site deleted | C | `(DANGLE p1 (ACCEPTED))` |
| M25 | `byte-reached` walks `all-out-targets` | D | `(LATTICE finish finish (non-eof-into-finish ×2))` |

**M3 ⊂ M15 is a nesting by construction, not a coverage gap** — M15 disables the very
`finish-node?` predicate M3's filter exists to gate, so M3's effect is a strict subset for every
possible machine. Register both and record the nesting by LABEL, per the project's convention.

**Both-direction requirement.** Each task must show (a) the new pin fails its own mutant with the
record above, and (b) the new cells do **not** re-anchor an incumbent — specifically that the
suite's **twelve** `EXPECT_SURVIVES` directives are unchanged, and that no incumbent's mutant is
now killed by a matrix cell instead of by its own assertion. *(Twelve is the count of directives
at line start, which equals the runtime `SURVIVES (expected)` count. A substring grep for the
keyword returns 29 — it also matches blocks that merely discuss it, and that exact confusion
already produced one false census this project has paid for.)* **Task 5 is the risky one:** 51
cells all asserting EOF verdicts is the shape that silently re-anchors decision 0021's pin.

## §7 The census — a complement, not a second opinion

Measured: the 230-cell matrix produces **6 of the 16** codes — `eof-reachable-stop` (48),
`zero-progress-cycle` (22), `eof-zero-progress-cycle` (14), `missing-target` (13),
`non-eof-into-finish` (12), `invalid-eof-target` (3). The census owns the other **ten**.

The five mutations the matrix cannot see map one-to-one onto **intra-node content** and the
**three non-node reference positions** the matrix excludes by definition — `error-node-error-name`
(`ir.sls:418`), `machine-default-eof-error` (`ir.sls:547`), and the field reference
(`ir.sls:382` / `verify.sls:309`). The census is the matrix's complement on a disjoint axis.

**Three layers.** *Layer 1 (live set):* `read` `verify.sls` as one datum and walk it for
`(make-diagnostic 'X …)` — the technique `member3-drift-tests.sps:75` already uses. Guards: every
code literal must be a **quoted symbol** (32 candidate forms today, of which one is
`make-diagnostic`'s own definition header — subtract it *explicitly*, not by pattern luck), and
`(eof-object? (read p))` after the library form. *Layer 2 (pinned counts):* source-derived code
set vs a new `verifier-diagnostic-codes` export; per-code site counts vs a pinned table totalling
**31** (re-measured at implementation time, never copied from here). *Layer 3 (fixture table):*
keyed by (code, site-discriminator), iterated over the **source-derived** key set. The
discriminator **cannot be message text** — §16.4 and `verify.sls:19` forbid comparing rendered
text, and the texts are not unique anyway (775/828 share one, 778/831 share one, which is exactly
where the hole is). Use the diagnostic's **node slot** plus fixture shape.

**The operand-table drift row.** Extract `field-operations` (7) + `field-predicates` (7) from
`ir.sls:305-306` and `field-operand-schemas`' keys from `verify.sls:277-284`, assert set equality.
Measured: the sets match (14 = 14) and **nothing pins that**. This converts `verify.sls:301`'s
"Unreachable through the public API" comment — verbatim the shape of Slice ③'s defect #1 — into a
checked invariant.

## §8 Sentinels — each reading an observed value

- **S1 product (Task 2).** Count cells **as driven**, inside the loop after the verdict compare;
  `check-equal` against `(* (length positions) (length kinds))` computed in a *separate*
  expression. Insufficient alone — adding a kind without a builder row moves neither number —
  so paired with S2.
- **S2 closed-set drift (Task 2).** Read `node?`'s disjunct list out of `ir.sls` as a datum and
  compare the kind-predicate set against the kind table's keys. **This is the one that goes RED
  when Milestone 5 adds a callback node kind.**
- **S3 site census (Task 6).** Source-derived site count vs a pinned per-code table totalling 31.
  RED when a site is added under an *existing* code — the shipped pattern (Slice ③ reused
  `invalid-field-operand` with, in the source's own words, "NO NEW CODE").
- **S4 fixture coverage (Task 6).** Iterate the source-derived key set; count rows asserted
  inside the loop; compare against the source-derived total — **never** the fixture table's own
  length.
- **S5 operand drift (Task 6).** §7's set equality. RED on a one-line eighth name.
- **S6 loop-over-the-loops (Tasks 3–5).** Each axis increments its own counter; a final
  `check-equal` asserts their sum equals the records the harness actually compared. AGENTS.md:282
  — an exhaustive loop that never executes passes vacuously.

## §9 Hazards, ranked by what actually went wrong in Milestone 4

**H1 — the expected-verdict table is a second census, stale on arrival.** *This is the attack on
the thesis, and it is measured true.* Four cells in the `P1` column have an observed verdict that
**contradicts §16.2:909**, and the only affordable way to fill 230 verdicts is to record what the
shipped verifier returns — which would freeze four live defects into an artifact that reads as
authoritative. **Mandatory mitigation:** every expected verdict is DERIVED from a cited §16.2
bullet *before* the machine is run; a differing observation is a **finding**, not a baseline;
cells with no §16.2 bullet get `accept` and say so at the cell.

**H2 — the row count is a constant a later slice can satisfy by editing prose.** The precedent is
in the most structurally similar file: `position-kind-tests.sps` carries a `*** CORRECTED
2026-09-03 ***` block recording that Slice ② changed only that file's **comment** — six lines,
none of them code — while the prose claimed a row was added and pinned. Its sentinels were
correct and observed-value-based, and the drift happened anyway. At 230 rows the hazard is
larger. **Mitigation:** S1+S2 — the count is a *derivation from the constructor surface*, never a
literal.

**H3 — scoping will cut the wrong axis.** The base 144 is 63% of the cells and the least
informative per cell: two rules, 16 rejections. Nine mutations are distinguished by a **single**
cell, and those cells live in axes **B, C, E, F** — the four a budget cut reaches for first.
**Cutting axis B alone loses the only coverage of that site in the entire tree** — it is the site Task 1 closed, and axis B is its *second*, independent witness.
**Mitigation:** §6's axis column exists so a scoper can see the cost.

**H4 — "census clean" will be read as "the Slice ③ shape is closed".** Measured decisively:
deleting the four fixtures that exist *only* because of the three Slice ③ defects leaves the code
census at 16/16 **and** the site census at 29/31, unchanged. All three defects made an *existing*
code go unemitted for a *new* kind, from a site another kind already fired. **Mitigation:** the
census is the **regression-scope** instrument; the matrix is the **defect-finding** half. Task 6
ships green and must not be reported as a discovery.

**H5 — the census's plumbing is itself a three-place census.** `byte_machine_mutation_stage`
copies the tree to `${STAGE_DIR}` and builds the verify lane's command from `${STAGE_DIR}` paths.
A census reading `${CMAKE_SOURCE_DIR}/src/byte-machine/verify.sls` would read the **pristine**
source while running the **mutated** object — every source-side mutation then reports as caught
or as a bogus mismatch, either way meaningless. Set the variable in three places (both lane
registrations plus the mutation command's environment), pin it with its own mutation, and make an
unset variable raise loudly, as the `BYTE_MACHINE_GOLDEN_FILE` precedent already does.

**H6 — a boolean or set-valued oracle is silently wrong.** OQ-4 measures one decision emitting 2
or 3 identical diagnostics. And `entry = field-branch (true=finish, false=stop)` verifies as
`(non-eof-into-finish)` — **rejected**, so a `verification-ok?` oracle passes — while §16.2:909
also requires `eof-reachable-stop` for the false arm, which is absent. **Mitigation:** one
`check-equal` per cell against the exact sorted **multiset** of `(code . node)` pairs, with
`RAISED` as a recorded verdict *value*, so M1b is a failed comparison rather than an escaping
`assertion-violation` (AGENTS.md prefers the comparison form).

**H7 — a green matrix will be read as executor coverage.** Two of Slice ③'s four review findings
produced **no verdict change at all** (the emitter's `reached` filter; and `dup-code`, where both
lanes returned records differing only in `reason` on a machine the verifier accepts with zero
diagnostics). The matrix is a **verifier** instrument. It does not speak for the differential
lanes, the emitter, or the executors, and the plan says so here so that no closing record claims
it does.

## §10 Explicitly out of scope

- **The D-1 fix.** Still out of *this* slice's scope, but no longer deferred: it is Slice ⓪b's
  T4, which now runs **before** Tasks 2-5. See §2's superseded note — the "85 of 230, mostly
  double-reporting" characterisation does not survive re-measurement, and the recommended shape
  produces zero duplicates.
- **Tier 2a — the corruption catalogue**, and **Tier 2b — free draws plus an independent
  acyclicity walk.** Both are Milestone 7's, which names *bounded invalid-machine generator*
  already. Building 2a now would build it twice: M5 and M6 each add codes. The **ratchet** (S3+S4)
  is what comes forward, so a new code's coverage is mandatory the moment it lands.
- **Any change to the executors or the emitter.** §9's H7.
