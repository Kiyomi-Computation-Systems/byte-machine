# Milestone 4 Slice ①a — The Seam: ABI, Encoding, and the Parser-Error Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pay Milestone 4's entire re-baseline once, in the slice that adds no field and
no node kind. Land the unversioned generated-ABI constructor with `current-abi-version`
3, normalized encoding format 2 with three slots reserved empty, the `parser-error`
record and its whole accessor family, §17:963's state-id→source-name debug map, and all
three of §12.7's position kinds asserted against node kinds Milestones 1 and 2 already
shipped. The slice's oracle is: *no behaviour changed; the emitted bytes and the encoding
changed in exactly the ways this diff shows, and nothing else.*

**Architecture:** Nothing here is a feature. Three independent changes move emitted bytes
— the ABI constructor rename (decision 0018), the encoding format bump (decision 0019),
and the richer error payload (decision 0022) — and none is about fields. They are
bundled into one slice so the goldens, the four IR fingerprints and the seven `got`-digest
mutation pins are re-measured once rather than two or three times, and split into eight
ordered tasks so a reviewer can tell which byte moved for which reason. The slice
additionally reserves three slots empty — the encoding's field table, the ABI payload's
field-initials member, and emitted `exec`'s seventh parameter — which is the whole reason
Slice ①b moves no existing golden and no existing fingerprint (decision 0019 point 5).
`verify.sls` takes exactly one edit; `graph.sls` and `private/ir.sls` take none.

**Tech Stack:** R6RS Scheme (Chez 10.4.1), CMake/CTest lanes (CMake 4.3.3 local, floor
3.26), the in-repo mutation suite (`test/support/cmake/SchemeMutationSuite.cmake`).

Design authority: [milestone-4-design.md](./milestone-4-design.md) §5, with §4.1, §4.2,
§4.5, §4.6, §4.7 items 1–2, and the Appendix's per-library change map; decisions
[0018](../decisions/0018-unversioned-generated-abi-constructor.md),
[0019](../decisions/0019-encoding-format-2-pre-provisioned.md) and
[0022](../decisions/0022-structured-parser-error-record.md); parent plan
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md) §9.3:397-405,
§9.5:442/:444, §10.1:480, §10.5:527, §12.7:751-777, §16.2:884-909, §16.4:945, §17:951-966,
§18:970-985, §19.1:996-1004, §19.2:1009-1011, §20:1031/:1039/:1042-1043, §22.1, §22.4:1262-1272,
§22.9:1311-1317, §25:1559-1564 and exits :1568-1570.

**Where this plan and its sources differ, §0 records the difference and which one this
plan follows.** Three of those differences are defects *inside* the design — a three-way
contradiction (D1), a misreadable "reuse" (D7), and a misattributed pin (Task 3, Step 5).

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Baselines to hold, measured 2026-09-01 on `main` = `c3ceec2`** (Darwin arm64, Chez
  10.4.1, CMake 4.3.3): `ctest --preset release` **86/86** (38.84 s), `--preset pr`
  **86/86** (40.99 s; `pr` and `release` select the same 86 today), `--preset no-scheme`
  **8/8** (6.90 s), Scheme mutation suite **46 passes / 236 mutations** (zero `UNCAUGHT`,
  zero `FATAL`, nine `SURVIVES (expected)`), CMake mutation suite **1 pass / 72
  mutations**. Every task ends with these — plus that task's own additions, minus nothing
  — green.

- **`pr == release` is a property of today's lane roster, not of the presets.** `release`
  has no filter; `pr` filters on eight layer labels, and the vocabulary
  (`cmake/ByteMachineTesting.cmake:29-39`) contains two layers the `pr` regex omits,
  `fixture` and `expected-red`. A lane named `byte-machine.fixture.<feature>.chez.source`
  would configure, run under `release`, and be **invisible** to `pr`, to CI's first ctest
  step and to `make test`. Every lane this slice adds uses `unit`, `differential` or
  `determinism`.

- **Three slots are reserved empty and nothing may read them.** The encoding's `u16be`
  field count, the ABI payload's member 0, and emitted `exec`'s seventh parameter are
  written and never consulted in this slice. Decision 0019 point 5 governs what happens if
  a later slice finds a golden or a fingerprint moving: **stop, do not re-baseline** — the
  repair is the missing slot, not the number.

- **`SITES` defaults to 1, is asserted exactly, and fails in BOTH directions.** No pin in
  `SchemeMutationSuite.cmake` declares `SITES` (verified two ways at `c3ceec2`:
  `rg -n '\bSITES\b'` over that file returns **15** hits, every one on a `#`-comment line;
  a structured lex finds zero records carrying the key). So every one of the 236 Scheme
  mutations rides the default, no pin **in that suite** can absorb a duplicated line, and a
  `FIND` whose text a *new* function duplicates fails with "pattern occurs 2 times …
  expected 1" (`MutationRunner.cmake:342-347`, the comparison; `:59-62` is the doc comment,
  `:98-99` the default, `:331-340` the literal count). The tree's **one** `SITES`
  declaration is `MutationSuite.cmake:150` (`SITES 2`, `FILE cmake/ByteMachineProbe.cmake`),
  in the separate 72-mutation CMake suite, which mutates only seven `cmake/` and
  `test/support/cmake/` files — **none of which this slice touches** — so counting against 1
  is correct throughout this slice. A later slice editing one of those seven counts each
  `FIND` against its **declared** `SITES` (AGENTS.md's count-by-FILE rule).

  The check is: lex every `byte_machine_mutation(` block, keep those whose `FILE` is a file
  you touched, and count each `FIND` in the post-edit source — **by FILE, not by SPEC**,
  because `compile.sls`'s 24 pins are spread across **eight** different SPECs
  (`unit.compile`, `verify.identifier-repertoire`, `determinism.one-byte`,
  `property.differential`, `unit.reserved-drift`, `differential.byte-class`,
  `differential.sequence-node`, `differential.http-version`), so a census keyed on any one
  lane cannot see the rest.

- **A textual census of the mutation suite cannot reproduce its own totals, and must not
  be used as the sweep's completeness check.** Measured at HEAD: **224** top-level
  `byte_machine_mutation(` declarations and **34** top-level `byte_machine_mutation_run(`
  calls, plus two helper functions — `byte_machine_slice3_launcher_pass`
  (`SchemeMutationSuite.cmake:1583-1605`, called **9×**) and
  `byte_machine_slice5b_launcher_pass` (`:2193-2228`, called **3×**) — each declaring one
  mutation and running one pass per invocation. 224 + 12 = **236**; 34 + 12 = **46**.
  A step phrased "parse every `byte_machine_mutation(` block and confirm 236" fails by
  construction. Read the totals from `SchemeMutationSuite.cmake:734-735` and count by FILE
  for the sweep.

- **Mutation discipline** (AGENTS.md): every decision gets a mutation whose catch asserts a
  **measured** failure signature — `EXPECT_STATUS` **plus** `EXPECT_OUTPUT_MATCHES` — never
  a bare nonzero exit. A pin must resolve to exactly one `(case, check)` pair. The FAIL
  grammar is `byte-machine-harness: FAIL <group>.<case>: <what> -- <detail>`
  (`harness.sls:409`). `EXPECT_OUTPUT_MATCHES` is an **unanchored CMake regex** over
  stdout+stderr (`MutationRunner.cmake:230`), so `(`, `)`, `.` need `\\(`, `\\)`, `\\.`.
  A pin that is a substring of the FAIL-CONTEXT line, of the summary line, **or of the
  banner** asserts nothing. `harness-banner`
  (`harness.sls:641-650`) prints on **every** run through `harness-begin`, before any case,
  carrying `suite=`, `runtime=`, `version=`, `machine=`, `mode=`, `os=`, `architecture=`.
  There is also a **second** summary shape — `harness-provenance-failure!`
  (`harness.sls:665-677`) prints `PROVENANCE-ERROR` plus a summary with `os=`,
  `architecture=`, `cases=0 status=3` and none of `checks=`/`failures=`/`errors=` — and
  status 3 is a legal exit for a mutation to produce.

- **Sweep pins in BOTH directions, with a merge-base control.** Adding a mutation to a lane
  widens every existing pin's collision set there — *and* an existing mutant may match the
  pin you are adding. Adding a **check** widens pins the same way, and Task 1 adds both a
  check and a rejection case to Pass 33's lane. A pass collision-free on the merge base and
  colliding at HEAD is this branch's doing. Residue is recorded **in the tree beside the
  pin, named by mutation LABEL** — `.superpowers/sdd/` is git-ignored and an obligation
  recorded there has not been recorded.

- **AGENTS.md line citations in the design are all stale, and not by a constant.**
  `AGENTS.md` gained lines in `462d737` and `c3ceec2`, both after the design commit
  `f215af7`. Correct offsets, measured from `git diff f215af7..HEAD -- AGENTS.md` with
  `--unified=0`: lines ≤29 unchanged; 30-238 **+13**; 239-249 **+32**; ≥251 **+43** (old line 250 was
  replaced by a twelve-line block and has no single HEAD line). So
  design §4.3's `AGENTS.md:147` (SITES both directions) is HEAD **:160**; §5's `:170-171`
  (record by LABEL) is HEAD **:183-184**; §5's `:172-187` (sweep both directions) is HEAD
  **:185-200**; design:2265's `AGENTS.md:283-286` is HEAD **:296-299** only under the +13
  rule and is actually **+43** → **:326-329**. **Do not transcribe an AGENTS.md line number
  out of the design.** Every one of HEAD's :170-171 and :172-187 is a *different* rule that
  reads plausibly, which is why this is stated here rather than left to notice.

- **Completion sentinels are mandatory and must read the OBSERVED value.** No suite declares
  an expected case or check count; `harness-summary` reports only what ran, so an exhaustive
  loop that never executes **passes vacuously**. Task 7's three-kind × two-executor ×
  two-lane matrix and Task 6's symbol walk each need one, derived from what the parser or
  the reader *returned*, never from the test's own expected list — and the loop over the
  loops needs one too (assert the driving collection's own `length` where you iterate it).

- **Lane and manifest bookkeeping is fatal in one direction and silent in the other.** A
  source+AOT pair per program, each with a `TIMEOUT` and a unique five-segment lowercase
  name matching `^byte-machine\.([a-z0-9-]+)\.([a-z0-9-]+)\.([a-z0-9-]+)\.([a-z0-9-]+)$`
  (`cmake/ByteMachineTesting.cmake:64`); per-lane basename collisions are a configure-time `FATAL_ERROR`
  (`cmake/ByteMachineSchemeLane.cmake:359-366`) and duplicate test names are reserved and
  rejected in `cmake/ByteMachineTesting.cmake:135-141`. But
  **omitting a lane from a new library's `SOURCES` reddens nothing** — the fingerprint
  expectation and the measurement are both computed over the same declared manifest
  (`test/CMakeLists.txt:191-193`, `:212`; `ByteMachineSchemeLane.cmake:135`, `:439-444`),
  so they agree and the lane goes green and silently uncovered. The AOT step compiles the program's *static import closure*, so an omitted-but-imported
  library is still compiled and the lane still passes — there is no detectable trace at all.
  (`reserved-drift-tests.sps:9-21` records the **inverse** mistake, a library declared in
  SOURCES but not statically imported, which fails AOT-only; do not read it as covering this
  one.) **Count the SOURCES edits explicitly** — that is the only check there is.

- **`ctest --preset <x>` does not build.** Only `make build` / `cmake --build --preset dev`
  regenerates the fingerprint expectation files and the AOT `.so`s. Editing any `.sls` and
  running ctest alone produces `PROVENANCE-ERROR` with exit **3** — a status a step
  expecting 0 or 1 misreads as a code defect.

- **`.superpowers/` is ignored only by an untracked nested `.gitignore`
  (`.superpowers/sdd/.gitignore`).** A sibling artifact written to `.superpowers/` outside
  `sdd/` would **not** be ignored, and `git add -A` after subagent work has staged ledger
  directories under an unrelated commit message before. Stage explicitly, never `-A`.

- **A worktree at `.claude/worktrees/beautiful-ardinghelli-d2fe92/` holds a byte-identical
  copy of the tree at this commit.** It is excluded via `.git/info/exclude:18`, not
  `.gitignore`, so `rg` skips it but `grep -r` and `find` do not. **Prefer `rg`, and scope every
  measurement to `src/`, `test/`, `docs/` or a named file** — this plan's own command blocks
  are not uniformly scoped, so check the scope before trusting a count.

- **Chez floor 10.4.1, CMake floor 3.26. No new dependencies** — only `(rnrs)`,
  `(rnrs eval)`, `(only (chezscheme) load)` where an existing program already uses it, and
  in-repo libraries. `(byte-machine interpret)` must not import any normalizer library
  (§18:970-972, decision 0015 point 3).

- **Exit-status vocabulary is exactly 0, 1, 2, 3** (`cmake/ByteMachineExpectExit.cmake:27-31`).
  This slice adds **no new exit path**; every task still re-runs the *whole* mutation suite,
  because a new exit path can silently disarm an existing mutation and a green suite will
  not say so.

- **Predicted counts are arithmetic to check, never facts to write down.** Re-measure
  release/pr, no-scheme and both mutation totals before any number enters
  `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`, the CHANGELOG, a decision record, a design
  document, or `README.org`. Sizing is a **floor**, not an estimate.

- Conventional Commits; run the suite before every commit; match the touched file's comment
  style and `mode` vocabulary.

- Commands (copy-pasteable; `chez`, not `scheme` — there is no `scheme` on this host):

```bash
make build
```

```bash
make test-all
```

```bash
ctest --preset release -R '<lane>' --output-on-failure
```

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure --no-tests=error
```

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

---

## §0 Design calls locked by this plan

Design §10 hands eleven bullets to writing-plans. **Nine** rulings follow, D1 through D9:
six are calls this plan takes, and three record contradictions or false statements inside
the design that a task cannot execute without one. Each is stated once here and cited, never
restated, by the task that uses it.

**D1 — `reserved-member-3` ends this slice at fifteen symbols, not fourteen.** The design
contradicts itself three ways: §5 task 3 (design:601-602) says emitted `exec`'s seventh
parameter "joins `reserved-member-3` here, not in ②"; §6 task 6 (design:1094-1096) says
Slice ② "owns that parameter's name and its `reserved-member-3` entry"; §5 task 6
(design:741) says "This slice adds **two** entries". **Decision 0019 item 3(c) is the
binding record and is unambiguous**: "the new parameter's name joins `reserved-member-3`
(`compile.sls:53`, today twelve symbols carrying the other six) in the same commit."
So: Task 3 adds one (the seventh parameter), Task 5 adds two (`errs` and the position-kind
loop variable), and `compile.sls:53` goes **12 → 15**. Task 6's gate is measured against 15.

**The ruling is 0019's; do not repair it with a false reconciliation.** Design §6's "that
parameter" *is* emitted `exec`'s seventh parameter — the same identifier 0019 3(c) and §5
task 3 name — so §6 and the appendix's "the emitted field-store local is Slice ②'s"
genuinely contradict 0019 3(c) and §5 task 3. They are not reconciled, and a plan that
claims they are hands the next reader a false reason for a correct call. The record wins
because it is the record; the design's §6 sentence is a defect to report upstream, not to
explain away.

**D2 — the three new emitted identifiers are `fieldv`, `errs` and `pk`.** No design
sentence and no record names the seventh `exec` parameter or the position-kind loop
variable; both are emitted locals, so both must be chosen and both must join
`reserved-member-3`. `errs` is fixed by decision 0022 item 7. `pk` is named by decision 0022 item 1's worked
example — `(byte-machine-make-parser-error/v1 (vector-ref errs N) (quote name) id off pk)`
(record line 106) — and again by design §5's own worked shape. **`fieldv`** is this plan's choice for the seventh
parameter — it is what Slice **②** fills (0019 item 3(c): "Filled in ②"; ①b fills only the
other two reservations).

**`fields` was considered and rejected on measurement.** `(rnrs)` binds it — it is
`define-record-type`'s auxiliary keyword — so Task 6's first subtraction,
`(environment-symbols (environment '(rnrs)))`, would remove it from the walk's remainder
before the subset assertion ran, and deleting it from `compile.sls:53` could never redden
the lane. Verified by
`(memq 'fields (environment-symbols (environment '(rnrs))))` returning a non-`#f` tail under
Chez 10.4.1; the same query returns `#f` for `fieldv`, `errs` and `pk`. **Any replacement
name must be checked against `(rnrs)`, not only against `reserved-member-1`/`-2`.**

**D3 — the reason reaches `encode-normal` through a NEW eighth slot on the normalized-state
vector, not by widening slot 5 or the eof pair.** This is the largest call in the slice and
the design does not make it. `encode-normal` receives only `(entry states)` and never sees
the machine or its declarations, so a reason must already be *inside* a state. The two
places a code reaches the encoder today both have external readers that raise on a
non-symbol: slot 5 (`normal-error-code`, written at `normal-ir.sls:231`, encoded at `:276`)
is read by `compile.sls:115` as `(symbol->string (normal-error-code s))`, and the eof pair's
cdr (`(cons 'default default-eof-code)`, built at `:155` and `:165`, encoded at `:274`) is
read by `compile.sls:99` as `(symbol->string (cdr eof))` **and asserted by whole value**
against `'(default . eof)` at `normal-ir-tests.sps:270-276`. Widening either is three
breakages for one slot. Instead: the state vector goes from seven elements to **eight**,
index 7 holding the reason string (or `#f`), with a `normal-error-reason` accessor. Six
construction sites move (`normal-ir.sls:224-226`, `:230`, `:231`, `:232`, `:234-235`, and
`seq-state`), the slot-map comment at `:35-40` is rewritten, and slot 5, the eof pair,
`compile.sls:99`/`:115` and the whole-value assertion are all untouched.

**D4 — the `u16be` field count goes in the header, immediately after the state count.**
Neither design §5 nor decision 0019 says where. Format 2's layout is therefore fixed here
as `[version u8][entry u32be][state-count u32be][field-count u16be][field records…][state
records…]`, so Slice ①b appends per-field records contiguously after the count without
splitting the state block. The byte stream has no self-description and nothing in the tree
decodes it, so a later disagreement about position is a second unbudgeted re-baseline —
exactly what decision 0019 point 5 forbids.

**D5 — `errcode` is not widened; a sibling `errreason` is added beside it.**
`SchemeMutationSuite.cmake:4875` pins `FIND [[(error-declaration-code (car es)) (loop (cdr
es))]]`, a literal **substring** of `normal-ir.sls:147` (the line carries four closing parens
after it). Widening `errcode` to return both takes that
FIND to zero sites and hard-fails the suite at declaration. A separate helper leaves it
byte-identical.

**D6 — the debug map is built in its own pass over `prefix-blocks`, not inside the existing
`map` at `normal-ir.sls:245`.** That line is pinned verbatim by
`SchemeMutationSuite.cmake:5136`, and the natural edit — making that `map` also emit
`(cons (cdr kv) (node-name n))` — kills the pin. A separate walk leaves `:245` untouched.
The map is appended as `make-normal-machine`'s **fourth argument, after `fp`**, never
before it: `normal-machine-fingerprint` is `(vector-ref m 3)` (`normal-ir.sls:32`) and
`compile.sls:149`/`:171` read it, so inserting the map ahead of `fp` silently renumbers
slot 3 and makes the emitter splice a debug map into the constructor call.

**D7 — Task 1 adds a new string predicate; it does not call `valid-name?`.** What design
§5:557-558 actually says is "reusing the existing `invalid-name` **code**", which is right
and is what §16.2:886 licenses by putting reasons in one portability bullet with names and
codes. The hazard is that §5:559-560 in the same breath quotes the existing arm's
`(valid-name? …)` predicate as the place to extend, and design:2313 uses the word "reusing"
of `valid-name?` in its **①b** paragraph — so "reuse" is easy to read as "call the
predicate". It cannot be called on a reason: `valid-name?`
(`verify.sls:43-50`) opens with `(symbol->string sym)` and a reason is a **string**,
enforced at `ir.sls:282-283` — so the call raises rather than returning `#f` — and the
repertoires differ, `[a-z][a-z0-9-]*` for names against §10.1:480's "printable ASCII plus
LF" for reasons. Applied to reasons, `valid-name?` would reject every shipped fixture's
reason, all of which contain SPACE.

**D8 — the projection library is `test/support/harness/byte-machine/test/error-projection.sls`,
library `(byte-machine test error-projection)`, and Task 7's lane is
`byte-machine.differential.position-kind.chez.{source,aot}`.** Both names are free
(checked). `differential` is a valid layer and is in `pr`'s filter; the basename collides
with nothing in any lane's flattened set.

**D9 — the task order is the design's, unchanged, and one ordering cost is accepted
knowingly.** Task 6 builds the `reserved-member-3` drift guard *after* Tasks 3 and 5 have
added the three entries, so those additions are checked by inspection when made — the exact
condition `compile.sls:107` calls out. The alternative, building the guard first, would
require measuring its subtraction set twice, once before and once after the goldens move
three times. The trade is taken; Task 6's gate compensates by asserting all three entries by
name and by reddening on the deletion of each.

---

## §0b Hazards measured at HEAD that no design sentence names

Each was found by reading the tree at `c3ceec2`, and each would surface as a hard failure or
a silently-passing test if a task were written from the design alone.

**H1 — eleven pins die or are avoided in this slice, and the design's die-list names only
some of them. `Declared at` is the pin's `byte_machine_mutation(` line; the FIND's own line
is given where the two differ.** The last two rows die only if D5/D6 are ignored; every other
row dies under this plan and every death is at *declaration* — a zero-site or two-site
`FIND` — rather than as a moved digest.

| Pin LABEL | Declared at | `FIND` is | Killed by |
| --- | --- | --- | --- |
| `runtime: a /v2 finish does not drive exec with finish? true` | `:2713` | `runtime.sls:262` verbatim | Task 3's seventh argument. Not covered by the design's catch-all ("every runtime.sls pin inside `parser-feed-op!` or `parser-finish-op!`") because `:262` is inside **`parser-finish-v2!`** |
| `compile: reserved-member-2 drops a runtime export (silent drift)` | `:5494` | `make-parser parser? parser-feed!` — the interior of `compile.sls:48` | Any reflow of `reserved-member-2` when Task 2 grows it 20→30 and Task 3 →31 |
| `normal-ir:` the dispatch default-eof arm | `:4884` | `(begin (put-u8 p 1) (put-symbol p (cdr eof)))` = `normal-ir.sls:274` verbatim | Task 4 appends the reason there. The design lists only the `got` digest one line below |
| `normal-ir:` the `errcode` tail | `:4875` | `(error-declaration-code (car es)) (loop (cdr es))` = `normal-ir.sls:147` | Only if `errcode` is widened — **D5** avoids it |
| `normal-ir:` the prefix-block `map` | `:5136` | `normal-ir.sls:245` verbatim | Only if the debug map is built in place — **D6** avoids it |
| `runtime: advance does not consume the byte` | `:2489` (FIND `:2490`) | `(loop (+ pos 1))` = `runtime.sls:199` | Task 5's `pk` loop variable. **A swap pair**: its REPLACE `(loop pos)` is byte-identical to `runtime.sls:200`, so FIND and REPLACE move in lockstep or the mutant fails as an arity error instead of as the consumed-count defect it names |
| `runtime: a finish reaching a named error node does not store its value` | `:2922` (LABEL `:2924`, FIND `:2929-2931`) | `runtime.sls:300-302` — the whole `(let ((e (op 'error-value node))) …)` binding, store and result | Task 5 rewrites that arm to read `pk`; any of the three lines changing takes the FIND to 0 |
| `compile: the final newline is emitted as CRLF` | `:5359` (FIND `:5362`) | `" exec)))\n"))))` = `compile.sls:165` | **Task 3**'s payload placement, not Task 5 and not the rename on `:164` |
| `runtime: a mismatched generated-runtime ABI version is accepted` | `:2541` (FIND `:2544`) | `runtime.sls:51` verbatim | Task 3's tombstone rewrite deletes the text — **0 sites**, not a moved digest |
| `runtime: a mismatched /v2 ABI version is accepted` | `:2722` (FIND `:2725`) | `runtime.sls:66` verbatim | Task 3's tombstone rewrite, same 0-direction |

**H2 — seven pins share three source anchors inside the two procedures Task 5 threads `pk`
through, and only ONE of the three anchors is actually edited.** `runtime.sls:187` (the feed
pause arm) is the byte-identical FIND of `:3057` and `:3085` *and* the second line of
`:2877`'s two-line FIND. `runtime.sls:292` (the finish pause arm) carries `:3093` and is the
second line of `:2885`'s. `runtime.sls:308-310` (the default-eof path) is the byte-identical
FIND of both `:2643` and `:2660`.

**Only `:308-310` is on Task 5's edit list**, because decision 0022 item 9 makes
`default-eof-value` take the dispatch node. The two pause arms take no jump and read no
`pk`; Task 5 must **leave them byte-identical**. Rewriting their five pins "to be textually
distinct" would replace text that matches with text that does not, turning five green pins
into zero-site declaration failures. This hazard is a *do-not-touch*, not a re-anchoring
obligation — the obligations are in H1's table.

**H3 — an `EXPECT_SURVIVES` shares an anchor with a live pin.** `runtime.sls:152` is the
FIND of `:2970` (live) and of `:3009` (`runtime: parser-feed!'s finished sticky arm is
deleted outright`, a declared survivor). `:152` is the **`finished`** sticky row, which carries `#f` in the error slot — decision 0022
item 4 names the sticky-*error* rows (`:150-151`, `:245-246`) and not this one, so nothing in
the records says `:152` must stay. This hazard is what says it: leave it byte-identical.

**H4 — `stub-exec` breaks in Task 3 and is named nowhere.** `runtime-tests.sps:276` is
`(define (stub-exec state offset bv start end finish?)`, handed to
`byte-machine-make-compiled-machine/v2` at `:289`-`:290` and called through
`parser-executor` at `runtime.sls:218` and `:262`. The moment the seventh argument lands,
every `/v2` case in `runtime-tests.sps` raises an arity violation. `stub-feed`
(`runtime-tests.sps:186`) and `stub-exec` (`:277`) also contain the emitted loop header text
verbatim and must **not** gain a fourth loop variable — they are hand-built, and their
contract is with the runtime, not with `loop-tail`.

**H5 — Task 5's red is far wider than the eight differential tuples.** `parser-result-error`
is read at **35 sites in 15 files** under `test/common/` (38 across 16 under `test/`, the
extra three being mutation-pin bodies). Beyond the eight tuple builders:
`differential-pause-tests.sps:112` is a bare-symbol assertion *inside a differential
program*, which a projection wired into `rfields` does not reach; `compile-tests.sps:172`
and `:177` pin the emitted error-arm text with no `parser-result-error` in sight, so
`byte-machine.unit.compile.chez.{source,aot}` redden from a grep that cannot see them; and
`interpret-tests.sps:104`, `eof-interpret-tests.sps:52` and `:90` are
`(not (eq? (parser-result-error r) 'unexpected-byte))` disjuncts inside `(when (or …) (set!
bad b))` guards — they go **red**, not vacuous, because a record makes the `or` fire.
`runtime-tests.sps`'s eleven reads must deliberately stay green: that file drives hand-built
executors that put the bare symbol in the slot themselves, and "fixing" them deletes the
runtime's own evidence that the sticky rows are type-agnostic (decision 0022 item 4).

**H6 — the eight tuple builders have five different shapes, and one has no helper at all.**
`(rfields cm b)` (one-byte `:31`, byte-class `:47`); `(rfields cm bytes)` (eof `:24`);
`(rfields r)` (sequence-node `:53`, http-version `:55`); `(rfields r p)` (pause `:31`,
property `:36`); and **none** — `differential-sequence-tests.sps` has no `rfields`, its
tuple is inline at `:56-58` inside `run-slices`. `differential-eof-tests.sps:28` builds a
**three**-member tuple, so its error slot is index 2, not 4.

**H7 — `(put-u8 p 1)` occurs three times in `normal-ir.sls` and `(put-u8 p 2)` will occur
twice after the bump.** Today: `:254` (version), `:274` (default-eof tag), `:275` (stop
tag). The design's own appendix (design:2314) names the pre-bump collision; nothing names
the post-bump one. Task 4's new format-version pin cannot use either bare literal, and a
global replace of `(put-u8 p 1)` rewrites the stop tag and the default-eof tag too — moving
all four fingerprints for three reasons at once, which the gate "all four fingerprints move"
cannot distinguish from the intended change.

**H8 — five in-tree prose claims go false in this slice; none is caught by any test.**
`compile.sls:8` ("via the v2 ABI"), `compile.sls:104` ("the format version byte stays 1"),
`compile.sls:105-107` ("No new emitted local means `reserved-member-3` … is unchanged"),
`normal-ir.sls:211-212` ("its tag bytes and its format version byte are unchanged"), and
`normal-ir-tests.sps:62` (";; Golden value: measured against this exact encoding (format tag
1; …"). A sixth sits on the three lines directly above the constant Task 3 bumps:
`runtime.sls:46-48` asserts both that the constant is 2 *and* that "the `/v1` constructor
checks it", and Task 3 falsifies both clauses. Two more are already false at HEAD and get corrected as encountered:
`SchemeMutationSuite.cmake:2718-2721` ("the emitter still emits /v1, so
`current-abi-version` stays 1") A sixth and seventh go false with them:
`runtime.sls:46-48` (the constant is 2, and "the `/v1` constructor checks it") and
`runtime.sls:60-64` ("It checks the literal 2, matching what the emitter now emits") — both
**true at HEAD**, both falsified by Task 3. These are **live comments saying what code is for** —
instructions, corrected in place, not records.

**H9 — the design's fingerprint exit check is an aggregate read distributively.**
design:881-882 says each successor appears "2 in `compile-tests.sps`, 3 in
`normal-ir-tests.sps`, 1 per golden, 11 in `SchemeMutationSuite.cmake`". That sums to 19
across **all four** values. Measured per value at HEAD:

| Value | Machine | compile-tests | normal-ir-tests | golden | SchemeMutationSuite | total |
| --- | --- | --- | --- | --- | --- | --- |
| `4236938459847922092` | one-byte | 2 | 1 | 1 | 5 | **9** |
| `9098559711816935340` | node-routing eof | 0 | 1 | 0 | 2 | **3** |
| `15725897457025557005` | pause | 0 | 1 | 1 | 3 | **5** |
| `12299125921751534854` | http-version | 0 | 0 | 1 | 1 | **2** |

19 total in `src/` + `test/`, **none in `src/`**. Value B has no committed golden and value
D has no `normal-ir-tests.sps` assertion, so "each new value is measured once and written at
every site" means four different site sets, not four copies of one. `CHANGELOG.md` carries
**eight further occurrences** (3/2/2/1) which are **records of what was measured then** and
are annotated, never rewritten.

**H10 — four of the eleven `SchemeMutationSuite.cmake` fingerprint occurrences are narrative
comments no check reads** (`:4942`, `:4943`, `:4951`, `:6548`), and the exit evidence
(`rg -o '<value>' test/ src/` returning zero per superseded value) fails unless they move
too. The mutant byte count `3849` has a **third** site the design never names:
`test/support/harness/byte-machine/test/http-version-machine.sls:19`.

**H11 — the `got`-digest cost note in the tree undercounts itself.**
`SchemeMutationSuite.cmake:843-852` says "The five `got` digests" and "leave five pins"; at
HEAD there are **seven** (`:4773`, `:4780`, `:4787`, `:4889`, `:4907`, `:4958`, `:4980`).
All seven carry `EXPECT_STATUS 1` — including `:4958` and `:4980`, whose status lines are
`:4957` and `:4979`. Follow the design's seven, not the comment's five, and correct the
comment in place.

**H12 — the exit-evidence `EXPECT_SURVIVES` grep is over-broad and will report a false
positive.** `rg 'EXPECT_SURVIVES' SchemeMutationSuite.cmake` returns **17** lines; only
**9** are directives (anchored `^\s+EXPECT_SURVIVES`). The other eight are `#`-comment prose
at `:96`, `:128`, `:397`, `:410`, `:1959`, `:2396`, `:2415`, `:3040` — and this slice
rewrites narrative in that file, including `:3040`, the closing line of the comment above the
`parser-reset!` survivor whose stated reason reasons about code Task 5 rewrites. Use the
anchored count.

**H13 — Pass 33's narrative carries five superseded counts, and its live baseline is 42.**
`:3149-3156` (27 / 702 pairs), `:3236` (40 / 1560, merge base `49c8cc4` at 34),
`:3254-3255`, `:3257-3264`, and the fifth audit block at `:3284-3316` whose live figure is
`:3290-3291` (**42 mutations / 1722 ordered pairs**). Also stale after Task 1: `:3313`
("measured at 42"), `:4092` ("UNDER-ANCHORED at 42 mutations") and in-pin notes measured at
34 across **eight** Pass 33 blocks on **ten** comment lines, of which `:3776`, `:3974`,
`:4030`, `:4184` and `:4250` are five — **this list is a starting point, not the closed
set**. Task 8 enumerates the rest by measurement (`rg -n 'at 34 mutations|measured at 34'`
within Pass 33's range) rather than from this plan. At 43 mutations the sweep is 43 × 42 = **1806**
ordered pairs. Note the design's exit evidence says "Pass 33's pin count … (44 verify.sls
pins by `FILE` pre-slice)" — Pass 33 holds **42**; 44 is verify.sls across the file (42 +
Pass 37's two).

**H14 — Pass 49's cited range stops 86 lines short of the pass.** design:848 gives
`:6486`-`:6548`. `:6486` is the header, but the pass runs to `byte_machine_mutation_run` at
**`:6634`**: a second `3849` at `:6580`, the verify command at `:6602-6613`, the mutation
block at `:6615-6632` with LABEL at `:6618` and FIND at `:6628` — a FIND textually identical
to Pass 35's `:5011` but under a different SPEC, and the 23rd `normal-ir.sls` pin.

**H15 — `BYTE_MACHINE_PAUSE_GOLDEN_FILE` is not set for the mutation-suite lane.**
`test/CMakeLists.txt:592-595` sets only `BYTE_MACHINE_FINGERPRINT_SAMPLE`,
`BYTE_MACHINE_GOLDEN_FILE` and `BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE`. If Task 8's sweep
adds a pass whose verify command is `determinism-pause-tests.sps`, its **baseline** fails on
an unset variable, and the comment at `:575-583` records that this reads as a mutation defect
rather than as the missing environment it is.

**H16 — no digest of a golden's own bytes exists anywhere.** The provenance mechanism
fingerprints a lane's `SOURCES`, and no `.golden.sls` appears in any `SOURCES` list — the
goldens reach their programs by environment variable at run time. So there is no digest of a golden's own bytes, and nothing
watches the file itself. **Goldens are regenerated from the emitter, never hand-edited.**
What catches a hand-edit is the byte comparison of the emitter's *fresh* output against the
committed file (`determinism-one-byte-tests.sps:39-42`) — one check, not two: the "compiles
and executes" group at `:44` writes the emitter's fresh output to a temp file and loads
*that*, never the committed golden, so it would not notice.

**H17 — Task 6's recipe is new construction, not a copy.** Design:743-748 says to build the
member-3 guard "the way `reserved-drift-tests.sps` builds member-2's". That file does no
such thing: it sorts `reserved-member-2`, sorts `(environment-symbols (environment
'(byte-machine runtime)))`, and asserts one `check-equal`. No test in the tree walks a `read`
datum for symbols outside `quote` forms — `render-machine` is called from five test programs,
but none reads its output back as a datum. Two further facts the recipe omits: `reserved-member-3` is **not
exported** from `(byte-machine compile)` (`compile.sls:11-13` exports six tokens), so the
lane cannot read it without an export edit; and the recipe's three subtractions leave eight
symbols behind — `library`, `export`, `import`, `generated`, `rnrs`, `byte-machine`,
`runtime`, and the **machine name** (`one-byte`, which is *not* the caller's binding
`one-byte-parser`) — none of which is in `reserved-member-3`, so the guard is red on its
first run. Whether Chez's `(rnrs)` environment binds `library`/`export`/`import` as
identifiers is asserted by nothing in this tree; do not assume it.

**H18 — `parser-error-reason` and `parser-error-detail` are compared by nothing.**
§9.3:398-405 ships eight accessors, §22.4:1271 names five, §12.7:777 excludes exactly one.
That leaves `reason` and `detail` neither required to match nor licensed to differ. Task 7
resolves this in the tree rather than leaving two orphans.

**H19 — §25:1570 contains no error clause.** Its full text is
`- interpreter/generated fields and traces match.` The bridge is design §4.6's disposition
reading "traces match" as §22.4:1262-1272's comparison list, of which :1271 is the error
bullet. The criterion is **not reworded** (AGENTS.md); it gets a dated disposition naming
that reading.

**H20 — §9.5:442 is already amended.** Decision 0018's Gate 0 work replaced that line in
`f215af7`; at HEAD it already reads "Milestone 4 retires the versioned *name*, not the
version: one unversioned constructor checks `current-abi-version` — now 3 —". Design §5
task 8 schedules an amendment that has already landed. **Task 8 verifies, it does not
re-edit.**

---

## File Structure

**Created:**

| File | Responsibility | Task |
| --- | --- | --- |
| `test/support/harness/byte-machine/test/error-projection.sls` | The §22.4:1271 five-member projection with one owner, plus the positively-asserted state-id exclusion (D8) | 5 |
| `test/support/harness/byte-machine/test/reason-machine.sls` | A fixture whose error reasons carry `"`, `\` and LF — the only machine in the tree that exercises the writer's escaping | 1 |
| `test/common/position-kind-tests.sps` | All three §12.7 position kinds, both executors, with a sentinel over the matrix | 7 |
| `test/common/member3-drift-tests.sps` | The `reserved-member-3` drift guard (§4.7 item 2) | 6 |

**Modified — `src/`:**

| File | Change | Tasks |
| --- | --- | --- |
| `src/byte-machine/verify.sls` | **Exactly one pass edited**: `pass-names-valid`'s `machine-errors` arm gains a reason clause, plus the `valid-reason?` predicate it calls (D7). No other pass is touched | 1 |
| `src/byte-machine/runtime.sls` | The `parser-error` record, `parser-error?` and eight accessors, `byte-machine-make-parser-error/v1`, exports; `current-abi-version` 2→3; the unversioned constructor and two tombstones; the seventh `exec` argument at `:218` and `:262`; `pk` threaded through `parser-feed-op!` and `parser-finish-op!` | 2, 3, 5 |
| `src/byte-machine/compile.sls` | `reserved-member-2` 20→31; `reserved-member-3` 12→15 (D1); the export list gains `reserved-member-3` (H17); the emitted constructor, `exec`'s seventh parameter, the loop header, all **three** `loop` jump sites, both error arms, the `errs` table, string escaping | 1, 2, 3, 5, 6 |
| `src/byte-machine/private/normal-ir.sls` | Format byte 1→2; the `u16be` field count (D4); the reason in slot 7 (D3); `errreason` (D5); the debug map as `make-normal-machine`'s fourth argument (D6) and a fifth accessor on the export list; the `only` import list gains `error-declaration-reason` | 4 |
| `src/byte-machine/interpret.sls` | `error-value` and `default-eof-value` yield the record's inputs; `default-eof-value` gains the dispatch node and unwraps a compound; a declaration-index state id | 5 |

**`graph.sls` and `private/ir.sls` take no edit at all**, and `private/conditions.sls` takes
none. `machine-gen.sls` takes none: ①a adds no drawable construct, and §22.6:1295 puts the
field draw in Slice ③. `interpret.sls`'s else-arm-less `eof-target-of` (`:112-116`) is
**left alone** — it is design §4.7 item 4, closed in Slice ③, and its observable wrong
behaviour needs a node kind whose slot 4 holds something other than an EOF target. It sits
six lines below code Task 5 edits; the boundary is restated in that task's steps.

**Modified — `test/`:** the three goldens (regenerated, never hand-edited, H16); sixteen
`SOURCES` blocks in `test/CMakeLists.txt` (**16 edits, not 32** — the sixteen lanes *are* the
eight source/AOT pairs); the eight tuple builders in their five shapes (H6); the collateral
listed in H5; `compile-tests.sps:160`, `:161`, `:165`, `:168`, `:169`, `:172`, `:177`;
`runtime-tests.sps:195`, `:245`, `:276`, `:289`, `:290`, `:306`; `normal-ir-tests.sps`'s
three fingerprints and its layout comment at `:62`; `SchemeMutationSuite.cmake` per Task 8.

**Modified — records and status surfaces:** `CHANGELOG.md` (the §9.5:444 entry, and the
`[Unreleased]` preamble's "Milestone 4 … has not started" corrected — a status line is an
instruction); `README.org:20-21`, the same sentence. `README.org`'s documentation list
already carries the Milestone 4 design row at `:81`; nothing is owed there. The milestone's
*closing* status moves when M4 closes, not here.

---

## Task 1: Portable reasons at the verifier, and the writer's escaping

Design §5 item 1; §4.7 item 1; §16.2:886; §10.1:480; §10.5:527. **This task is what makes an
author-supplied string safe to write into generated Scheme source, and Task 5 is the first
task that writes one.** Skipping it leaves not a missing check but an unparseable generated
library, failing at the `(load genfile)` every differential lane performs as a Chez reader
error naming a temp file.

**Files:**
- Modify: `src/byte-machine/verify.sls` — the one edit this slice makes to that file
- Modify: `src/byte-machine/compile.sls` — the writer half
- Create: `test/support/harness/byte-machine/test/reason-machine.sls`
- Modify: `test/common/verify-tests.sps`, `test/CMakeLists.txt`

**Interfaces:**
- Consumes: nothing.
- Produces: a `valid-reason?` predicate and the guarantee that every verified machine's
  reasons are printable ASCII plus LF; and an escaping writer. Task 5 consumes both.

- [ ] **Step 1: Write the failing tests first (§22.1).**

Add three cases to `test/common/verify-tests.sps`: one whose `default-eof` declaration's
reason contains TAB (`#\tab`, 0x09), one whose reason contains `"`, `\` and LF, and one
whose declaration is nonportable in **every** field, guarding the single-finding rule.

**Amended 2026-09-01, executing this task: no fixture library is created here.** This step
originally also created `test/support/harness/byte-machine/test/reason-machine.sls`.
`verify-tests.sps` builds every machine **inline** through `(byte-machine graph)` — it has
`errs`, `machine*` and `one-byte-nodes` helpers at `:10-21` and constructs its broken
variants in place — so a fixture library would add a lane-manifest edit and a
content-fingerprint change for nothing. The escaping fixture is still needed, but its
consumer is **Task 5**, which is the first task that renders a reason into an emitted
library and `load`s it; it is created there, where it has something to prove. Two helpers
were added to `verify-tests.sps` instead, `machine-errs*` and `machine-with-reason`.

Expected before the implementation: the TAB case fails with `0` diagnostics where `1` is
expected.

**The case NAME is constrained in both directions (H13's lane).** It must not contain any of
`an uppercase machine name is invalid-name: invalid-name`,
`an uppercase node name is invalid-name: invalid-name`, or
`an uppercase error code is invalid-name: invalid-name` as a substring — those are the
verbatim `EXPECT_OUTPUT_MATCHES` of `SchemeMutationSuite.cmake:3421`, `:3484` and `:3490`,
and each is an unanchored regex over the whole run. And each of those three must still
resolve to its own `(case, check)` pair after this case exists. Use a NAME with no
`uppercase` and no `invalid-name` token, e.g. `a reason outside printable ASCII is rejected`.

- [ ] **Step 2: Add `valid-reason?` and its call site in ONE commit.**

`verify.sls` is a library body: a free identifier bound nowhere kills it at **import**,
called or not, and takes down all **46** of the 65 Scheme lanes that reach `verify.sls`
through `CORE_VERIFY → CORE_ALL → CORE_EMIT / CORE_NORMAL_IR / CORE_COMPILE`
(`test/CMakeLists.txt:772`, `:796`, `:875`, `:902`, `:925`) — not the four verify lanes.
Never commit or measure an intermediate state.

Per **D7**, `valid-reason?` takes a **string**. Repertoire: every character `c` such that
`(or (and (char>=? c #\space) (char<=? c #\~)) (char=? c #\newline))` — printable ASCII
(0x20–0x7E) plus LF (0x0A). TAB (0x09) is **excluded**; `"`, `\` and SPACE are **included**.

**Placement matters (H1's fourth trap).** `SchemeMutationSuite.cmake:5344-5345` pins a
two-line adjacency: `verify.sls:42` immediately followed by `verify.sls:43`
(`  (define (valid-name? sym)`). Inserting the new predicate **between** `:42` and `:43`
takes that FIND to zero sites and hard-fails the suite. Place `valid-reason?` **after**
`valid-name?`'s closing paren, not before it.

Extend the **existing** `machine-errors` arm — the third `append` operand, which is
`verify.sls:470-477` (`:470` is `(filter values`, `:477` is `(machine-errors m)))))`; the
design's `:471-476` is the `map` lambda and design:2313's `:472-477` is the `if` plus the
collection, and neither bounds the arm) — by adding a third conjunct to the predicate whose
literal current text is:

```
                    (if (and (valid-name? (error-declaration-name e))
                             (valid-name? (error-declaration-code e)))
```

Do **not** add a fourth arm: one error declaration must still yield at most one
`invalid-name` finding, a rule the design states three times (design:558-561, :1026, :1193)
with two different reasons, so discharging one and not the others leaves a rule with no
owner. Do **not** add a `(string? reason)` guard: `make-error-declaration`
(`ir.sls:279-284`) already rejects a non-string, `ir.sls` is private, and `graph.sls`
re-exports only the constructor — such an arm is unreachable through any public API, ships
dead, and owes an `EXPECT_SURVIVES` that none of the 44 `verify.sls` pins carries.

`SchemeMutationSuite.cmake:3489` pins the literal `(valid-name? (error-declaration-code e))`
— 40 characters, exactly one site, at `verify.sls:473`. The natural third conjunct,
`(valid-reason? (error-declaration-reason e))`, shares no substring with it and leaves the
pin at one site; **that is the shape to write.** What must not appear is a second *verbatim*
occurrence of the pinned string — so do not, for example, re-check the code inside a new
helper.

The diagnostic's message text at `verify.sls:476` is free: §16.4:945 compares structure and
codes, never rendered prose, and the three verifier message literals occur nowhere in
`test/` or `test/support/cmake/`. That freedom is a property of the current pin set, not a
guarantee — re-check before rewording, not after.

- [ ] **Step 3: The writer half in `compile.sls`.**

§20:1039 requires explicit escaping. The emitter has never written a user-controlled string
— its one string literal is `"unknown state"` at `compile.sls:162` — so there is no shipped
escaper. Add one, escaping `"` → `\"`, `\` → `\\`, and LF → `\n`, and use it wherever Task 5
renders a reason. It is dead weight until Task 5 and its gate carries the escaping check.

Beware `SchemeMutationSuite.cmake:5350-5357`: `FILE src/byte-machine/compile.sls`, whose
FIND spans `compile.sls:56-57`, whose **first** line is byte-identical to `verify.sls:42` (the second differs:
`valid-binding?` versus `valid-name?`). Do not write the escaper in that shape.

- [ ] **Step 4: Comment corrections at the sites (H8).**

None yet in this task — `compile.sls:104`'s format-version claim is Task 4's and
`:105-107`'s member-3 claim is Task 6's. Recorded here so a reader of Step 3 does not fix
them early and split the evidence.

- [ ] **Step 5: Lane bookkeeping.**

`reason-machine.sls` goes into **both** the source and AOT lanes' `SOURCES` for every lane
that uses it. A new `.sls` changes the lane's content fingerprint, recomputed at build time
— **rebuild** (`make build`) before running ctest, or the provenance check correctly fails
with exit 3.

- [ ] **Step 6: Gate.**

```bash
make build && ctest --preset release --output-on-failure
```
Expected: `100% tests passed, 0 tests failed out of 86`. This task registers **no** new
lane — its three cases join an existing program — so the literal is 86, not 88. `pr` reports
86 too, and `no-scheme` reports 8.

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```
Stated before running: 237, being 236 plus one new mutation. **Measured: 238**, and the
difference is the finding this gate exists to surface. The repertoire decision has two
directions and each ships a different defect — permissive accepts a control character and
yields an unparseable generated library, restrictive rejects a legal reason and fails every
shipped fixture — so it takes two mutations, not one, and AGENTS.md's "try the opposite
constant first" is what makes that visible. Both are caught by a failed **comparison**
rather than by a raise. `EXPECTED_MUTATIONS` is at the measured 238.

Expected: one line, `byte-machine-spec: scheme mutation suite complete (46 passes, 238
mutations)`, and **no** `UNCAUGHT` and **no** `FATAL` line.

Three behavioural expectations, each a literal:
1. Every shipped fixture still verifies with **exactly 0** diagnostics.
2. A machine whose reason contains TAB reports **exactly 1** diagnostic, whose code is
   `invalid-name`.
3. A machine whose reason contains `"`, `\` and LF verifies with **exactly 0** diagnostics.

The re-anchoring obligation this task creates is Task 8's: Pass 33 gains a check **and** a
case, which widens every one of its 42 pins' collision sets.

---

## Task 2: The `parser-error` record and its accessors, referenced by nothing

Design §5 item 2; decision 0022 items 1 and 2; §9.3:397-405. The record ships whole and
inert: nothing constructs one until Task 5.

**Files:** `src/byte-machine/runtime.sls`, `src/byte-machine/compile.sls`,
`test/common/runtime-tests.sps`.

**Interfaces:**
- Consumes: nothing.
- Produces: `parser-error?`, eight accessors, and `byte-machine-make-parser-error/v1`.
  Task 5 constructs; Task 7 asserts.

- [ ] **Step 1: Failing tests first.** Add cases to `runtime-tests.sps` constructing a
  record through `byte-machine-make-parser-error/v1` and reading all eight accessors.

- [ ] **Step 2: The record, beside the `parser-result` tag.**

`runtime.sls:86` is the section comment `;; --- parser result (immutable snapshot) ---`;
`:87` the tag, `:88-89` the constructor, `:90` the predicate, `:91-95` the five accessors,
`:96` blank. Add the `parser-error` block after `:95`.

Eight members in **§9.3:398-405's order**: `domain`, `code`, `reason`, `detail`,
`node-name`, `state-id`, `offset`, `position-kind` — plus `parser-error?` (§9.3:397).

**The reserved constructor takes five arguments, not eight** (decision 0022 item 1):
`(byte-machine-make-parser-error/v1 <errs-entry> <node-name> <state-id> <offset> <position-kind>)`,
where `<errs-entry>` is a two-element vector packing `code` and `reason`. `domain` and
`detail` are **not** call-site arguments: the constructor fixes them internally to `machine`
and `#f`. `#f` is not a placeholder — §9.3:401 annotates `detail` "`#f` for machine errors".

- [ ] **Step 3: Exports and the `reserved-member-2` mirror, in the SAME commit.**

`reserved-drift-tests.sps:30-40` sorts both sides and asserts `check-equal` on the sorted
lists — **set equality, and duplicate-sensitive**, since a repeated symbol survives sorting.
So a runtime export added without mirroring it into `compile.sls:44-52` reddens the lane, and
so does the reverse; the intermediate state cannot be committed green. Add all ten names to
both in one commit.

The two lists are set-equal but **not line-parallel**: `runtime.sls:15` carries five symbols
that `compile.sls` splits across `:48` (three) and `:49` (two). Do not "mirror line for
line".

**Reflowing `reserved-member-2` breaks a pin (H1).** `SchemeMutationSuite.cmake:5494` FINDs
`make-parser parser? parser-feed!` — the interior of `compile.sls:48`. Append the ten new
names on **new lines** after `:52`'s current last entry; do not re-wrap `:48`.

- [ ] **Step 4: Gate.**

```bash
ctest --preset release -R 'reserved-drift' --output-on-failure
```
Expected: `byte-machine.unit.reserved-drift.chez.source` and `.aot` both pass, **2/2**.

```bash
rg -l 'parser-error' src/ test/
```
Expected at this task's end: **exactly three** paths — `src/byte-machine/runtime.sls`,
`src/byte-machine/compile.sls`, `test/common/runtime-tests.sps`. Any fourth means the record
has acquired a consumer a task before it should have one.

`reserved-member-2` holds **30** symbols at the end of this task (20 + `parser-error?` + the
eight accessors + `byte-machine-make-parser-error/v1`), and **31** after Task 3. Count them.

---

## Task 3: The unversioned constructor, the two tombstones, the metadata vector, and `exec`'s seventh parameter

Design §5 item 3; decision 0018 items 1–5; decision 0019 item 3(c). **The sharpest hazard in
the slice is here, and it fails silently in the one direction the tombstone exists to
cover.**

Pre-slice the two guards disagree about where the number comes from. `runtime.sls:51` is
`    (unless (and (integer? abi-version) (= abi-version current-abi-version))` and
`runtime.sls:66` is `    (unless (and (integer? abi-version) (= abi-version 2))` — identical
but for the last token, and they agree today only because `current-abi-version` is 2
(`runtime.sls:49`). **The moment this task bumps the constant, `/v1` becomes a real tombstone
that refuses everything and `/v2` becomes a hole that accepts exactly the stale files it was
added to refuse**, defeating decision 0012 item 1. A stale `/v2` object then loads and runs —
same `exec` arity, nothing raises — and the first `parser-error-code` on its bare-symbol
error slot fails an arbitrary distance from the cause. Chez object staleness is transitive
across imports, so this is reachable inside this repository's own build.

**Files:** `src/byte-machine/runtime.sls`, `src/byte-machine/compile.sls`,
`test/common/runtime-tests.sps`, `test/common/compile-tests.sps`, the three goldens.

- [ ] **Step 1: Failing tests first.** Assert `/v1` and `/v2` raise for **every** integer
  including 2 and 3; the unversioned constructor raises on 2 and succeeds on 3.

- [ ] **Step 2: Three textually distinct guards.**

Write the live guard and both tombstones so that no two share a `FIND`-able line, and so that
none collides with `runtime.sls:138`'s `(unless (and (bytevector? bv) …` — a fourth
`(unless (and` line, itself pinned at `SchemeMutationSuite.cmake:2563-2564`.

**The rewrite deletes both existing guard texts, so two pins go to ZERO sites in this
commit** — the same `SEND_ERROR` + `uncaught` path as duplication, in the direction that is
easier to miss. Re-anchor both here, not in Task 8: `runtime: a mismatched
generated-runtime ABI version is accepted` (FIND at `SchemeMutationSuite.cmake:2544`) and
`runtime: a mismatched /v2 ABI version is accepted` (FIND at `:2725`). Both keep their
witness — refusing *every* version still refuses the mismatched one, so
`runtime-tests.sps:243-245` and `:305-306` keep raising and keep catching a mutant that
stops raising — so this is `MutationRunner.cmake`'s "update the mutation rather than
deleting it" case, never an `EXPECT_SURVIVES`. Re-measure each `EXPECT_OUTPUT_MATCHES`. Writing any two
alike takes one FIND from 1 site to 2 and hard-fails at declaration. The suite already
records distinctness as the reason the two differ, at `SchemeMutationSuite.cmake:2719-2720`
— whose surrounding comment (`:2718-2721`) is **already false at HEAD** and gets corrected
here (H8).

The live `byte-machine-make-compiled-machine`'s **first action** is the
`(= abi-version current-abi-version)` check, before every other guard and every field read
(decision 0018 item 1). Both tombstones refuse *every* version, not the one they are named
for — a tombstone that still accepts a number is a hole.

- [ ] **Step 3: Discharge decision 0018's delegated `'v1` disposition — BEFORE the constant moves.**

Decision 0018's Consequences says it in as many words: "**The runtime's `'v1` executor path
becomes unconstructable**, and its disposition is owed by the slice that lands this, not by
this record." Once `/v1` refuses every version, nothing can build a `'v1`-variant compiled
machine, so `make-parser`'s `'v1` arm (`runtime.sls:120-123`), `parser-feed!`'s `else`
(`:157`), `parser-feed-v1!` (`:205-213`) and `parser-finish!`'s raising `v1` arm (`:253`)
lose their only witness.

**Measured blast radius.** `runtime-tests.sps` calls `(v1-machine)` at **eleven** sites
(`:195` defines it; `:197`, `:215`, `:221`, `:232`, `:236`, `:255`, `:262`, `:350`, `:360`,
`:526` use it), every one of which starts raising — so
`byte-machine.unit.runtime.chez.{source,aot}` and Pass 32's **baseline** go red, and Task 3
cannot reach its own gate. Two shipped mutations lose their only witness and would silently
become `UNCAUGHT`: `runtime: a v1 machine is driven down the op path`
(`SchemeMutationSuite.cmake:2517-2539`) and `runtime: the v1 result status is hard-wired to
stopped` (`:2548-2553`).

**Decide and record, in the tree.** Decision 0018 supplies the argument for deletion — "An
arm no public API can reach cannot be witnessed and would ship dead owing an
`EXPECT_SURVIVES`" — so the recommended disposition is to **delete** the `'v1` executor path
(`runtime.sls:120-123`, `:157`, `:205-213`, `:253-254`, and `compiled-machine-v1-feed` /
`compiled-machine-v1-entry-state` at `:57-58` if they become unreferenced), rewrite
`runtime-tests.sps`'s `/v1` group accordingly, and **delete the two mutations with the code
they witness**, recording that deletion by LABEL beside the pass. The constructor
`byte-machine-make-compiled-machine/v1` itself **stays exported** as the tombstone — that is
what decision 0018 item 4 requires, and it is a separate site from the executor path.

Whichever disposition is taken, it is recorded in the tree, not in the ledger, and both
LABELs are named in Task 8's sweep.

**Executed 2026-09-02: the path was deleted, and deleting it cost coverage the plan did not
predict.** Both mutations went with the code they witnessed, as decision 0018's argument
requires. But two *other* shipped pins — `runtime: an accepting feed does not record the
stopped lifecycle` and `runtime: a rejecting feed does not record the error lifecycle` —
had their only witness in the deleted `/v1` group's `parser-lifecycle tracks ready ->
terminal` case, and the suite caught it as **wrong-reason**, not as a pass: each mutant
still exited nonzero, and only the `EXPECT_OUTPUT_MATCHES` signature revealed that it was
now failing somewhere else. A bare nonzero-exit catch would have shipped this. The case was
restored against the `/v2` stub, which encodes the same one-byte machine. **Before deleting
a test group, ask which pins name a decision it is the only witness for** — the mirror of
AGENTS.md's rule about deleting a mutation.

- [ ] **Step 4: `current-abi-version` 2 → 3, and the emitter's literal, in ONE commit.**

`compile.sls` does not import the runtime (`compile.sls:14-17`), so the emitted
`byte-machine-make-compiled-machine/v2 2` literal (`compile.sls:164`) and
`current-abi-version` (`runtime.sls:49`) are two independent constants with no static guard.
Nothing but the sixteen differential lanes — which emit, `load` and `eval` against the live
runtime — catches a disagreement. They move together or not at all.

`current-abi-version` is **not exported**, so no test asserts the bump directly; the only
checks are the literals in `runtime-tests.sps` and the differential lanes. Two prose comments
go stale and are corrected in place: `runtime-tests.sps:181-184` and `:239-240`.

- [ ] **Step 5: The growable payload — one quoted vector, appended last.**

`(byte-machine-make-compiled-machine 3 <fingerprint> <entry> exec (quote #(#())))`.

A **quoted vector, not a rest-arg** (decision 0018 item 2): a rest-arg lets the payload grow
*without* a version bump, and the version check is the only thing standing between a stale
object and silent wrong answers. It renders as `(quote #(#()))` — a **one**-member vector
whose **member 0** is the empty field-initials vector, *not* the empty vector itself. An
empty vector has no member 0, so ①b would have to add one, moving every golden in ①b and
voiding the milestone's headline invariant. It introduces no new callable identifier into the
emitted body, which is why the shipped arms say `(quote error)` rather than calling anything.

**This step also kills `SchemeMutationSuite.cmake:5359`** (LABEL `compile: the final newline
is emitted as CRLF`), whose FIND `" exec)))\n"))))` is `compile.sls:165` verbatim — the line
the payload lands on, **not** `:164` where the rename happens, which is what design:834-836
misattributes. Re-anchor FIND and REPLACE onto the post-payload tail **in this commit**,
keeping `EXPECT_STATUS 1` and its `EXPECT_OUTPUT_MATCHES` unchanged, and confirm the new
FIND is unique in `compile.sls`.

- [ ] **Step 6: `exec` from six parameters to seven (decision 0019 item 3(c)).**

`compile.sls:156` — `  (define (exec state offset bv start end finish?)` — gains a seventh
parameter named `fieldv` (**D2**; **not** `fields`, which `(rnrs)` binds), and **both** call
sites pass an empty vector:
`runtime.sls:218` (`(o (exec (parser-current parser) (parser-offset parser) bv start end #f)))`)
and `runtime.sls:262`
(`(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t)))`).

`fieldv` joins `reserved-member-3` **here**, taking `compile.sls:53` from 12 to 13 (**D1**).

**This step breaks `stub-exec` and a pin the design does not name (H4, H1).**
`runtime-tests.sps:276` defines a six-parameter `stub-exec` handed to `/v2` at `:289-:290`;
every `/v2` case raises an arity violation until it gains a seventh parameter.
`SchemeMutationSuite.cmake:2713` (`runtime: a /v2 finish does not drive exec with finish?
true`) FINDs `runtime.sls:262` character-for-character and must be re-anchored in this
commit. Note also that the **feed**-side call at `runtime.sls:218` is unwitnessed by any
mutation (verified two ways), so "the pins will catch a wrong argument at either site" is
false for one of the two.

- [ ] **Step 7: Regenerate the three goldens; never hand-edit (H16).**

Each golden's line 4 is `  (define (exec state offset bv start end finish?)` and each ends in
a `/v2 2 <fingerprint> <entry> exec` call (`generated-one-byte.golden.sls:20`,
`generated-pause.golden.sls:33`, `generated-http-version.golden.sls:85`). The determinism
lanes byte-compare the emitter's fresh output against each committed file, so every one of
those lines must come from the emitter, not from an editor.

Update `compile-tests.sps:165`'s literal `has?` fragment, and check `:160`, `:161`, `:168`,
`:169`, `:172` and `:177` — the design's exit evidence and decision 0018's Consequences name
only `:165`.

- [ ] **Step 8: Gate.**

```bash
rg -n 'byte-machine-make-compiled-machine/v[12]' test/fixtures/
```
Expected: **no output** (exit 1).

```bash
rg -c 'byte-machine-make-compiled-machine ' test/fixtures/
```
Expected: `1` for each of the three golden files.

Behavioural, each a literal: `/v1` and `/v2` raise for every integer including 2 and 3; the
unversioned constructor raises on 2 and succeeds on 3; `reserved-member-2` holds **31**
symbols with both tombstones still exported and `byte-machine.unit.reserved-drift.chez.{source,aot}`
green; `reserved-member-3` holds **13**; and every pin whose `FILE` is `runtime.sls` **or**
`compile.sls` still reports `SITES` 1 after re-anchoring — 42 and 24 blocks respectively,
counted by FILE.

---

## Task 4: Normalized encoding format 1 → 2, the reason, and the debug map

Design §5 item 4; decision 0019 items 1–4; decision 0022 item 9; §17:963; §20:1043.
**This is the task that moves all four fingerprints, and the one the design under-specifies
most.** Read **D3**, **D4**, **D5**, **D6** and **H7** before writing a line.

**Files:** `src/byte-machine/private/normal-ir.sls`, `test/common/normal-ir-tests.sps`,
`test/common/compile-tests.sps`, the three goldens, `test/support/cmake/SchemeMutationSuite.cmake`.

- [ ] **Step 1: Failing tests first.** Assert that two machines differing **only** in an
  error declaration's reason string produce **different** fingerprints.

  **The differing declaration must be REFERENCED or the assertion is vacuous.** `errcode`
  (`normal-ir.sls:144-147`) is reached only from `:150` (the machine default-eof error) and
  `:231` (an error node's target). A declaration that no error node names and that is not the
  default-eof error never reaches the encoder, before or after this task — so two fixtures
  differing only in an *unreferenced* declaration's reason produce **identical** fingerprints,
  and the gate reads as a failure of the slice rather than of the fixture.

- [ ] **Step 2: The import list.**

`normal-ir.sls:15-25` is an `only` list naming `error-declaration-name` and
`error-declaration-code` at `:22` and **not** `error-declaration-reason`. Add it. Nothing in
the design says so, and the code does not compile without it. (`interpret.sls` needs no
import edit — it imports `(byte-machine private ir)` wholesale at `:10`.)

- [ ] **Step 3: Slot 7 on the normalized-state vector (D3).**

The vector goes from seven elements to eight, index 7 holding the reason string or `#f`, with
a `normal-error-reason` accessor. Six construction sites move: `:224-226` (dispatch), `:230`
(stop), `:231` (error), `:232` (finish), `:234-235` (pause), and `seq-state` (used at `:229`
and `:245`). Rewrite the slot-map comment at `:35-40`, which documents the layout and says
"unused slots #f".

Slot 5 (`normal-error-code`), the eof pair, `compile.sls:99`, `compile.sls:115` and
`normal-ir-tests.sps:270-276`'s whole-value assertion against `'(default . eof)` are all
**untouched** — that is the point of the new slot.

Add `errreason` beside `errcode`, **without** editing `errcode` (**D5**).

For a dispatch state, slot 7 holds the machine's default-eof reason when the eof routing is
`(default . code)`, `#f` otherwise.

- [ ] **Step 4: The encoding.**

Format 2's layout, fixed by **D4**:
`[version u8][entry u32be][state-count u32be][field-count u16be][field records…][state records…]`,
with the field count **0** and no per-field records.

- Bump `normal-ir.sls:254` from `(put-u8 p 1)` to `(put-u8 p 2)`.
- Append the reason after the code in **both** encode sites: the error arm (`:276`) and the
  dispatch default-eof arm (`:274`).
- Write the `u16be` zero count after the state count at `:256`.

**`put-symbol` cannot carry a reason.** `normal-ir.sls:67-69`'s `put-symbol` calls
`(symbol->string sym)`, which raises on a string, and `ir.sls:282-283` validates
`(string? reason)`. Add a helper of the same wire shape (u16be byte length, then UTF-8).

**Do not name it `put-string`: `(rnrs)` exports that**, and a second definition in the
library body is a duplicate-definition error at expand time — measured 2026-09-02, after
writing it that way. It is `put-reason`.

**Do not do a global replace of `(put-u8 p 1)` (H7).** It occurs three times — `:254` the
version byte, `:274` the default-eof tag, `:275` the stop tag — and rewriting all three moves
every fingerprint for three reasons at once, which the gate cannot distinguish from the
intended change.

**The reason is encoded once per error STATE and once per default-eof-routing DISPATCH
state, not once per declaration** — `:231` writes the resolved code into every error state
and `:155`/`:165` copy `default-eof-code` into every dispatch state's eof pair. That is the
opposite of Task 5's per-declaration `errs` table, and it is correct rather than duplication:
the encoding serializes the state vector, and per-state repetition is what makes a state-local
change visible in the fingerprint.

- [ ] **Step 5: The debug map (D6, decision 0022 item 9).**

Build it in its **own** pass over `prefix-blocks`, leaving `normal-ir.sls:245` byte-identical
— it is pinned verbatim at `SchemeMutationSuite.cmake:5136`.

Thread it out of `lower-machine` as a third value (`:248` returns `(values entry states)`
today) and place it as `make-normal-machine`'s **fourth argument, after `fp`**:
`(make-normal-machine entry states (fnv1a-64 (encode-normal entry states)) dbg)`. Placing it
before `fp` silently renumbers slot 3 — `normal-machine-fingerprint` is `(vector-ref m 3)`
(`:32`), read by `compile.sls:149` and `:171` — so `fp` would bind to the **debug map**, and
the emitter would render the map where the IR fingerprint belongs in the constructor call.

The map is **total over internal prefix states**. `name->id` (`:140-142`) covers declared
nodes only; internal prefix states, numbered by `allocate-prefix-ids` (`:128-135`) from
`declared-count` onward, take their entries from the prefix-block walk. It maps each state id
to its **declaring node's public name**.

Add the fifth accessor to `normal-ir.sls`'s export list (`:8-13`) — without that line
`compile.sls` cannot see the slot, and no design or decision sentence says so. `compile.sls`
imports the normalizer without an `only` clause (`:17`), so no import edit is needed there,
and `reserved-member-2` mirrors the *runtime*'s exports, so no drift guard moves.

- [ ] **Step 6: Comment corrections at the sites (H8).**

`normal-ir.sls:211-212` ("its tag bytes and its format version byte are unchanged"),
`compile.sls:104` ("the format version byte stays 1") and `normal-ir-tests.sps:62`
(";; Golden value: measured against this exact encoding (format tag 1; …") all go false in
this commit. They are live comments saying what the code is for — **instructions**, corrected
in place.

- [ ] **Step 7: Re-measure all four fingerprints and write each at every one of its sites.**

Use the per-value matrix in **H9**, not the design's aggregate sentence. Each value has a
*different* site set: value B has no golden, value D has no `normal-ir-tests.sps` assertion.

Seven of the nineteen sites are `got` digests in mutation pins, which can only be
**re-measured** by staging that one mutation and reading what it printed — never recomputed
(`SchemeMutationSuite.cmake:843-852`, whose "five" is wrong at seven; H11).

**Executed 2026-09-02, and the order matters more than the plan said.** A blanket
old→new replace across `src/ test/` is the right move for the twelve recomputable sites and
the **wrong** one for the seven `got` digests: it writes the new *baseline* where the
*mutant's own* digest belongs, and the suite then reports seven wrong-reason failures rather
than passes. Do the blanket replace, then re-measure all seven from a staged copy and
overwrite. Stage into a scratch directory and run `chez --libdirs` against it — **not** into
the working tree, where the revert would take the task's own unstaged work with it.
One of the seven, `normal-ir: a dispatch's default-eof routing is not encoded into the
fingerprint`, additionally has its FIND rewritten by this task (H1), so it is re-anchored
*before* it can be re-measured. Four more of the eleven
`SchemeMutationSuite.cmake` occurrences are narrative comments no check reads (`:4942`,
`:4943`, `:4951`, `:6548`) and must move too, or the exit evidence fails (H10).

`CHANGELOG.md`'s eight occurrences are **records** and are annotated, never rewritten.

- [ ] **Step 8: The format-version byte acquires a pin.**

It has none today — verified two ways: `rg -F '(put-u8 p 1)'` over `SchemeMutationSuite.cmake`
returns **two** lines, the FIND and the REPLACE of the *same* default-eof-arm mutation
(`(begin (put-u8 p 1) (put-symbol p (cdr eof)))` at `:4887` and its REPLACE), neither
anchored on `:254`; and a structured lex of every `FIND` whose `FILE` is `normal-ir.sls`
finds no match on `:254`.
The slice's own oracle is otherwise unwitnessed there.

**The obvious FIND collides.** `(put-u8 p 2)` will occur twice after the bump (`:254` and
`:276`), so the pin must use a longer surrounding string unique in the file. Re-anchor
`:4884`, whose FIND this task deletes (H1).

**And the obvious REPLACE collides too — measured, not predicted.** Putting the byte back to
**1** produces the *identical* one-byte digest as the shipped `normal-ir: the FNV offset
basis is changed` mutation: flipping the basis's low bit and flipping the first hashed
byte's low bit reach the same FNV-1a state, so neither pin can discriminate the other's
mutant. Confirmed by running a control on each. The shipped pin is the incumbent and is left
alone; the new mutation uses version **3**, which has never been emitted and collides with
nothing. This is AGENTS.md's both-directions rule paying off inside a single task — the
check that an *existing* mutant matches the pin you are *adding*.

- [ ] **Step 9: Gate.**

```bash
rg -n -F '(encode-normal entry states)' src/byte-machine/private/normal-ir.sls
```
Expected: the definition header and the call site, with the **call** still reading
`(encode-normal entry states)` and its two arguments unchanged, even though its line now
also carries the debug-map argument to `make-normal-machine`.

**Measured 2026-09-02: three lines, not two.** The third is the comment this task adds above
`normal-machine-debug-map`, which quotes the call as its evidence that the map cannot
perturb the fingerprint. Count the two *code* occurrences; a bare line count is the wrong
check here, and this is the plan predicting a literal that its own task then changed.

For each superseded value V:
```bash
rg -o '<V>' src/ test/
```
Expected: **no output** (exit 1).

For each successor, expect its measured per-file counts from the H9 matrix — 9/3/5/2 by
value, 19 in total, none in `src/`.

Two fixtures differing only in a *referenced* error declaration's reason produce different
fingerprints. A machine with no fields encodes a field count of zero — observable only
through a re-measured fingerprint, since `encode-normal` is not exported and nothing in the
tree decodes the stream; document the layout in a comment above the golden number, the way
`normal-ir-tests.sps:62-69` already does.

---

## Task 5: Both executors' error value, the emitter's two error arms, and the differential projection — ONE commit

Design §5 item 5; decision 0022 items 3, 5, 6, 7, 8, 9. **These cannot be split**: the two
lanes are compared by value, so either both produce records or the differential is red
between commits.

**Position kind is a property of the transition that arrived, not of the error state.** One
error node reached by a reexecute edge reports `byte`; the *same* node reached by an advance
edge reports `boundary`. The emitted arm for a normalized error state is keyed on state id
alone (`compile.sls:113-115`) and cannot see which edge jumped to it — so position kind is
carried as one more loop variable in each executor, set from a literal at each jump:
`advance` → `boundary`, `reexecute` → `byte`, the EOF-chain jump → `eof`, and — the case ①a
cannot itself produce, fixed so ② and ③ inherit a rule — a zero-width jump → `boundary`.

**The loop-entry initialization is `boundary`, unconditionally, in both lanes, with no
`finish?` key.** This is the correction Gate 0's whole-branch review made as its Critical
C1, and getting it wrong is not merely wrong — it is wrong in a way that *disarms the test
that would catch it*. Nothing has been consumed since either kind of call began, so an error
state reached with no jump taken reports a boundary at the current stream offset regardless
of which call observes it.

**Files:** `src/byte-machine/runtime.sls`, `src/byte-machine/interpret.sls`,
`src/byte-machine/compile.sls`, the three goldens, the eight tuple builders, the collateral
in H5, `test/support/harness/byte-machine/test/error-projection.sls`,
`test/CMakeLists.txt`.

- [ ] **Step 1: Failing tests first**, then all of Steps 2–7 in one commit.

- [ ] **Step 2: The generated lane.**

`compile.sls:157`'s header — `    (let loop ((pos start) (st state) (off offset))` — gains a
fourth argument, `(quote boundary)`, unconditionally, bound as `pk` (**D2**).

**There are THREE emitted `loop` jump sites, not two.** `rg -n '"\(loop ' src/byte-machine/compile.sls`
returns `:77`, `:78` **and `:97`**. Design §5 names only "both `loop-tail` forms,
compile.sls:75-78"; `:97` is inside `render-eof-branch`'s `node` case — the EOF-chain hop,
which design §5's own rule covers ("the EOF-chain jump → `eof`") but whose emitter site the
list omits. If `:97` is not widened, every generated library with an eof-target chain calls a
four-parameter `loop` with three arguments. It is live in a shipped fixture.

`:77` carries `boundary` (advance), `:78` carries `byte` (reexecute), `:97` carries `eof`.

**`:77` and `:78` are a swap pair and each one's REPLACE is the other's FIND**
(`SchemeMutationSuite.cmake:5235`/`:5242`). Updating only the FINDs leaves each mutation
replacing a four-argument tail with a three-argument one — failing as an arity error rather
than as the lowering defect the pin witnesses, which is the project's own "mutation caught
for the wrong reason". Rewrite FIND and REPLACE in lockstep, and keep the three new tail
texts distinct from each other.

`render-eof-branch`'s **default-EOF** arm (`:98-99`) takes a per-site literal `(quote eof)`,
**not** the loop variable: it is a terminal construction reached by no jump, and §12.7:771
fixes `eof` regardless. Its `node-name` is the **dispatch** node's — the one whose EOF-target
chain was exhausted, which is where truncation was detected (decision 0022 item 9).

`render-state-arm`'s error arm (`:113-115`) reads `pk`.

**Both helpers need signatures they do not have.** `render-eof-branch` is `(eof id)`
(`:95`), called from one site (`:127`) with the enclosing *dispatch* state's id;
`render-state-arm` is `(s)` (`:108`), called from one site (`:161`) with one argument.
`normal-ir.sls`'s exports yield no public source-node name from a normalized state, so the
debug map from Task 4 must be threaded through `render-machine`'s state loop (`:159-161`)
into both.

- [ ] **Step 3: The `errs` table — one entry per error DECLARATION.**

`(define errs (quote #(#(<code> <reason>) …)))` — §19.1:996's "immutable
field/callback/debug metadata" literally. Per-*site* literals would repeat each reason once
per error site: `generated-http-version.golden.sls` carries **nine** error sites over **two**
declarations, eight of them the default-eof arm, because `render-eof-branch` renders at every
dispatch state.

**`compile.sls` cannot see any of this today, and no design or decision sentence says so.**
`compile.sls:16` is `(only (byte-machine private ir) machine-name)` — one identifier. Widen
it to `(only (byte-machine private ir) machine-name machine-errors error-declaration-code
error-declaration-reason)`. A free identifier in a library body kills the library at
**import**, so omitting this reddens every compile, differential and determinism lane at
once. (Task 4's "no import edit is needed there" is about the *normalizer* import at `:17`,
which has no `only` clause; it does not cover the IR import at `:16`.)

**A normalized state carries only the resolved code, so the index must be built at emission
time.** `normal-error-code` is `(vector-ref s 5)` (`normal-ir.sls:45`) and a dispatch state's
eof pair is `(default . <code-symbol>)` (`:46`) — neither carries a declaration position. In
`render-machine`'s `let*` (`compile.sls:145-150`) bind the declaration list once from
`(machine-errors (compilation-machine compilation))`, build from it both the `errs` literal
and a **code → index** alist, and thread that alist — alongside Task 4's debug map — into
`render-state-arm` (`:108`, called at `:161`) and `render-eof-branch` (`:95`, called at
`:127`).

Entries are ordered exactly as `machine-errors` declares them, and a site's index is that
declaration's position — the order `errcode` already walks (`normal-ir.sls:144-147`). Every
shipped fixture declares `default-eof`/`eof` first and `rejected`/`unexpected-byte` second, so
decision 0022's worked example `(vector-ref errs 1)` at a `reject` node is the second of
`http-version-machine.sls`'s two.

Reasons are written through Task 1's escaper.

`errs` and `pk` join `reserved-member-3`, taking `compile.sls:53` from 13 to **15** (**D1**).

- [ ] **Step 4: The interpreter lane — and note where it actually lives.**

`interpret.sls` is a **message closure** (`:117-127`); the execution loop lives in
`runtime.sls`. So the record is built where the loop is, from data the closure supplies.

`parser-feed-op!`'s header is `runtime.sls:173` — `      (let loop ((pos start))`, **one**
variable — with two tails, `:199` (advance) and `:200` (reexecute), and the mode already in
hand at `:196`. `parser-finish-op!`'s header is `runtime.sls:283` —
`      (let loop ((node (parser-current parser)))` — with **one** tail, `:306`, the eof hop,
and no advance/reexecute jump at all. **Neither header line is cited anywhere in the design
or in decision 0022**, which cite the dispatch arm (`:188-200`) and the whole procedures
(`:171-201`, `:274-311`, `:283-311`) instead. These are two different edits, not one.

`parser-feed-op!` gains `pk` initialized `boundary`; `parser-finish-op!` gains one too,
initialized `boundary` and set to `eof` on the eof-target hop at `:306`, then **read**, not
hardcoded, by its error arm at `:297-302`. Its `(dispatch)` arm's default-eof path
(`:303-310`) keeps a constant `eof`.

**There is no binding named `off` in `parser-feed-op!`.** Decision 0022 item 6's conclusion
holds but its name does not: the offset is parser slot 5, mutated at `:198` and read as
`(parser-offset parser)`. The identifier `off` exists in `runtime.sls` only at `:282`, inside
`parser-finish-op!`. A step written as "`(off, pk)` in the error arm" does not compile in the
feed path.

`interpret.sls`: `error-value` (`:105-107`) and `default-eof-value` (`:108-109`) stop
returning `error-declaration-code`. **`default-eof-value` takes no argument and must gain
one** — the dispatch node, which `parser-finish-op!`'s arm already holds as `node`. It must
**unwrap a compound** the way `eof-target-of` does: for a lowered sequence prefix state,
`node` is the pair `(node-name . consumed-bytes)` built at `interpret.sls:79`, and that is the
common case — seven of the eight default-EOF sites in `generated-http-version.golden.sls` sit
on internal prefix states.

**Do not write the unwrap as a clone of `eof-target-of`'s.** `SchemeMutationSuite.cmake:4603`
pins `        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))` verbatim; a new helper
in the same skeleton with the parameter named `cur` makes one FIND match two sites. Name the
parameter `node`. Note also that `(let ((n (lookup nodes name)))` already occupies two
byte-identical sites (`:83`, `:94`) — inert today because no pin FINDs it, but any new pin on
that text must declare its site count.

**`eof-target-of` (`:112-116`) is NOT fixed here.** It is design §4.7 item 4, closed in
Slice ③, and it sits six lines below `default-eof-value`. Adding its `else` arm while in the
neighbourhood moves the pin at `:4603` for a change no test in the tree can witness. This is
a non-goal of this task.

The interpreter's `parser-error-state-id` is the node's **declaration index** — its position
in `machine-nodes` (`ir.sls:374`), the same mapping `lower-machine` builds as `name->id`.
§12.7:777 licenses the two lanes to differ, so this is the interpreter's own deterministic
choice, not a requirement to match. **For a compound `node` there is no declaration index**
(decision 0022 item 8 does not define one, and this is the common case at the default-EOF
terminal); use the enclosing declared node's index, consistent with the unwrapped name.

- [ ] **Step 5: `feed-outcome` does not grow, and the sticky rows take no edit.**

It keeps its five slots and its `/v1` constructor (`runtime.sls:78-84`); its existing error
slot merely carries a richer value. The sticky-error rows (`:150-151`, `:245-246`), the four
`parser-set-stored-error!` call sites that store a produced error (`:161`, `:268`, `:301`,
`:309`), the clear at `:334`, and the setter at `:135` all take **no** edit — they store and
return whatever the executor produced.

**Do not touch `runtime.sls:152` (H3):** it is the byte-identical FIND of a live pin
(`:2970`) and of a declared survivor (`:3009`) whose diff the exit evidence requires to be
empty.

- [ ] **Step 6: The projection library, with one owner (D8).**

Create `test/support/harness/byte-machine/test/error-projection.sls`, library
`(byte-machine test error-projection)`, exporting the §22.4:1271 five-member projection —
error domain, code, public source-node name, absolute position, position kind — and the
excluded state id. Eight local copies of a §12.7:777 reading is eight places for it to drift,
and Task 7's positive exclusion check needs one owner.

**The obvious repair is the trap.** Once the slot holds a record, the eight comparisons go
red — correctly and immediately, because `parser-error-state-id` is deliberately lane-local.
Replacing `(parser-result-error r)` with `(parser-error-code (parser-result-error r))`
restores green while narrowing the comparison back to the single symbol it compared before
the family existed, shipping the family with no differential behind four of its five
comparable members. Substitute the projection for the error member only.

**Executed 2026-09-02. Four things the plan did not predict.** (1) Four of the eight
differential programs still *passed* before the projection went in, because their two lanes'
state ids happened to coincide — the projection belongs in all sixteen lanes, not only the
red ones, and a red-driven edit would have left four lanes comparing a lane-local id by luck.
(2) The single-executor unit lanes need an **`#f`-tolerant** code reader: `parser-result-error`
is `#f` on every non-error result, so a blanket `parser-error-code` wrap raises on them. Each
such program defines `error-code-of` locally. (3) `runtime-tests.sps`'s six hand-written `op`
closures and its `stub-exec` return the record's parts and build the record by hand — they
implement the protocol independently of `interpret.sls`, so they do not redden when it
changes and must be updated deliberately. (4) The emitted default-eof arm's index mutation
must force index **1**, not 0: the default-eof declaration *is* index 0 in every shipped
fixture, so a 0 REPLACE is a no-op and shipped **UNCAUGHT** on its first run.

**Fix the projection's treatment of `#f` explicitly.** `parser-result-error` is `#f` on every
non-error result. If the projection returns `#f` for `#f`, twenty-nine `#f`-tailed literal
tuples survive untouched (`differential-sequence-tests.sps` 8, `differential-sequence-node-tests.sps`
21); if it always returns a five-list, all twenty-nine must be rewritten. **Choose `#f` for
`#f`** — it is the smaller diff and it keeps the non-error tuples readable.

**The eight builders have five shapes and one has no helper (H6).** `differential-sequence-tests.sps`
has no `rfields`; its tuple is inline at `:56-58` inside `run-slices`.
`differential-eof-tests.sps:28` builds a **three**-member tuple, so its error slot is index 2.
A step written as "change `rfields` in each of the eight" silently skips one program.
Positional reads elsewhere (`differential-byte-class-tests.sps:106` reads index 3) are safe
under substitution and break under splicing — substitute, never splice.

- [ ] **Step 7: The collateral (H5), enumerated so none is missed.**

`differential-pause-tests.sps:112` — a bare-symbol assertion *inside* a differential program
that a projection wired into `rfields` does not reach. `compile-tests.sps:172` and `:177` —
the emitted error-arm text, no `parser-result-error` in sight, so a grep cannot find them.
`interpret-tests.sps:104`, `eof-interpret-tests.sps:52` and `:90` — `(not (eq? … 'unexpected-byte))`
disjuncts inside `(when (or …) (set! bad b))` guards asserted at `interpret-tests.sps:107`,
`eof-interpret-tests.sps:55` and `:93`; a record makes the `or` fire, so these go **red**, and
they must become `(not (eq? (parser-error-code (parser-result-error r)) 'unexpected-byte))`.
Plus the single-executor unit lanes' literal tuples.

**`runtime-tests.sps`'s eleven reads stay green and must not be "fixed".** That file does not
import `(byte-machine interpret)`; it drives hand-written `op` closures and hand-built
`stub-feed`/`stub-exec` executors that put the bare symbol in the slot themselves. This task
touches `interpret.sls` and `compile.sls` only. Editing the stubs deletes the runtime's own
evidence that the sticky rows are type-agnostic — decision 0022 item 4's whole argument.
Six hand-written `op` implementers in that file (`one-byte-op` `:12`, `eof-target-op` `:77`,
and four others) implement the message protocol independently and will **not** redden when
`default-eof-value`'s arity changes; check each by hand.

Renaming a check is not free: `SchemeMutationSuite.cmake:2854-2860` asserts
`EXPECT_OUTPUT_MATCHES "feed-stored error value"`, which is the check *name* at
`runtime-tests.sps:549`. Changing the assertion body is safe; renaming the check breaks a pin
in another file, in another language, with no compile-time link.

- [ ] **Step 8: Lane bookkeeping — sixteen edits.**

The projection library joins the `SOURCES` of the sixteen differential lanes, which **are**
the eight source/AOT pairs. Their `NAME` lines are `test/CMakeLists.txt:931`, `:941`, `:972`,
`:983`, `:998`, `:1008`, `:1019`, `:1029`, `:1068`, `:1078`, `:1118`, `:1129`, `:1168`,
`:1179`, `:1292`, `:1303` — find each block's own `SOURCES` list from its `NAME`, since
these are not themselves `SOURCES` lines. That is **16** edits in 16 blocks, not 32. Omitting one reddens nothing — the
fingerprint expectation and the measurement are both over the omitted-entry list — so count
them: `rg -c 'error-projection.sls' test/CMakeLists.txt` must be `16`.

- [ ] **Step 9: Gate.**

Every differential lane green with the projection in place. Then, as literals:

The design's gate — "`rg 'parser-result-error' test/common/` shows no lane comparing a whole
record" — returns **35 matches in 15 files** and can be read as satisfied whatever it prints.
Two checkable replacements, each stated as a literal:

```bash
rg -c 'parser-result-error' test/common/differential-pause-tests.sps
```
Expected `2` before this task, `2` after: `:33`'s tuple member becomes a call to the
projection **over** `(parser-result-error r)`, and `:112` becomes
`(parser-error-code (parser-result-error rr))` — both still name the accessor. The
substantive check is the next one.

```bash
rg -n 'parser-result-error' test/common/ | rg -v 'parser-error-[a-z-]+ \(parser-result-error|error-projection|project-error' | rg -c 'equal\?|check-equal|list '
```
Expected: **0** — every surviving read either feeds an accessor or feeds the projection, and
none is compared whole. Run it on the pre-task tree first and record the number it prints
there; a gate whose before-value is unknown cannot be read as a pass.

```bash
rg -c 'error-projection.sls' test/CMakeLists.txt
```
Expected: `16`.

And: a fixture whose reason contains `"`, `\` and LF emits a library that `load`s, with its
`errs` entry rendering `\"`, `\\` and `\n` rather than the raw characters — Task 1's writer
half, first observable here.

**Re-anchoring owed by this task.** In `runtime.sls`:

- `runtime: advance does not consume the byte` (`SchemeMutationSuite.cmake:2489`, FIND at
  `:2490`) — a **swap pair** with `runtime.sls:200`, so FIND and REPLACE move in lockstep;
  otherwise the mutant replaces a two-argument tail with a one-argument one and fails as an
  arity error instead of as the consumed-count defect it names.
- `runtime: a finish reaching a named error node does not store its value` (`:2922`, LABEL
  `:2924`, FIND `:2929-2931`) — its FIND is `runtime.sls:300-302` entire, the arm this step
  rewrites.
- `:2643` and `:2660`, whose byte-identical FIND is `runtime.sls:308-310`, the default-eof
  path `default-eof-value`'s new argument changes. **Two pins, one anchor** — re-anchor both
  into forms that stay distinct from each other.

In `compile.sls`: the `:5235`/`:5242` **swap pair** (each one's REPLACE is the other's FIND),
and the two error-arm pins whose FINDs are at `:5252` and `:5271`.

**Do NOT touch `runtime.sls:187` or `:292`** (H2). Five pins sit on those two pause arms and
this task edits neither; rewriting their FINDs turns five green pins into zero-site
declaration failures. `compile.sls:5359`'s pin is **Task 3's**, re-anchored there.

---

## Task 6: The `reserved-member-3` drift guard

Design §5 item 6; §4.7 item 2. `compile.sls:101-107` states the gap in its own words —
`reserved-member-3` is "unchanged -- checked, not assumed, since it has no automated drift
guard" — while `reserved-member-2` has had one since `reserved-drift-tests.sps`. This slice
adds **three** entries to member-3 (**D1**), so the gap is demonstrated rather than
theoretical.

**Files:** `test/common/member3-drift-tests.sps` (new), `src/byte-machine/compile.sls`,
`test/CMakeLists.txt`.

- [ ] **Step 1: Read H17 before writing anything.** The design's recipe — "build the guard
  the way `reserved-drift-tests.sps` builds member-2's" — is not a description of that file.
  `reserved-drift-tests.sps:30-40` sorts two lists and asserts one `check-equal`; there is no
  render, no `read`, no `quote`-walk anywhere in the tree. **This task is new construction.**

- [ ] **Step 2: Export `reserved-member-3`.**

`compile.sls:11-13` exports exactly six tokens and `reserved-member-3` is not among them;
`:13` carries `; test-support: the drift guard (§3.4) reads it`, which today applies only to
member-2. Add `reserved-member-3` to the export list and extend that comment. No pin's FIND
touches `compile.sls:11-13`, so no `SITES` re-check is owed for the export itself.

- [ ] **Step 3: Build the walk, and expect it red on its first run.**

Render a fixture exercising every state kind, `read` the emitted datum, and collect every
symbol appearing **outside** a `quote` form. Skipping the `quote` forms is what keeps error
codes, reasons and the metadata vector out of the measurement — and is why Task 1's escaping
evidence is stated separately in Task 5's gate rather than inherited from here.

The design's three subtractions — `(environment-symbols (environment '(rnrs)))`, the runtime's
export set, and the caller's binding — leave **twenty** symbols behind, measured against
`generated-one-byte.golden.sls`. Twelve of them are `reserved-member-3`'s own current
members, which is exactly what the subset assertion is *for*: they are expected to remain.
The other **eight** are the problem, because none of them is in `reserved-member-3` and none
is a runtime export, so the subset assertion fails on them: `library`, `export`, `import`
(from `compile.sls:153-155`), `generated`, `rnrs`, `byte-machine`, `runtime` (the library and
import headers), and the **machine name** (`one-byte`, which is *not* the caller's binding
`one-byte-parser` — golden `:1` versus `:2`).

**Do not assume `(rnrs)` binds `library`/`export`/`import` as identifiers.** The only
`environment-symbols` call in the tree is `reserved-drift-tests.sps:33`'s over
`(byte-machine runtime)`; nothing asserts anything about `(rnrs)`, and
`reserved-drift-tests.sps:9-21` records that this mechanism has already surprised the project
once with an AOT-only failure. **Measure what the walk actually returns, then decide the
subtraction set from the measurement, and write the reason beside it.** The library header
keywords and the machine name are structural, not emitted locals; subtract them by naming
them, with the reason stated, rather than by hoping `(rnrs)` covers them.

- [ ] **Step 4: Sentinel.**

The walk must assert the **observed** symbol count, not a count derived from the expected
set, and the loop over the state kinds needs its own sentinel — assert the driving
collection's `length` where you iterate it.

- [ ] **Step 5: Lane bookkeeping.** A source+AOT pair, each with a `TIMEOUT`, under a
  five-segment name. `byte-machine.unit.member3-drift.chez.{source,aot}` is free.

- [ ] **Step 6: Comment correction (H8).** `compile.sls:105-107`'s "No new emitted local
  means `reserved-member-3` (decision 0012 item 4) is unchanged -- checked, not assumed,
  since it has no automated drift guard" expires in **both** halves: Tasks 3 and 5 added
  emitted locals, and this task installs the guard. `compile.sls:8`'s "via the v2 ABI" was
  falsified by Task 3. Correct both in place.

- [ ] **Step 7: Gate.**

**Executed 2026-09-02. Three things measured rather than assumed.** (1) `(rnrs)` does **not**
bind `library`, `import` or `export` — they survive the first subtraction, exactly as the
step warned not to assume — so the library-header vocabulary and the derived library name are
subtracted **by name** with the reason stated. (2) The lane must import `(byte-machine
runtime)` **statically** even though nothing in it calls the library: the AOT lane compiles
only the static import closure, so a library reached solely through `(environment '(byte-machine
runtime))` is never compiled and `environment` raises "library not found" under AOT only —
the same surprise `reserved-drift-tests.sps:9-21` records, reproduced here. (3) The mutation
needs its **own pass** with its own verify command; appended to the preceding pass it ran
against a different program and reported **UNCAUGHT**, which is what AGENTS.md's
"a mutation's witnessing test lives in its own SPEC lane's program" predicts.

The new lane is green in both modes. `reserved-member-3` holds **15** symbols (**D1**):
the twelve at `compile.sls:53` plus `fieldv`, `errs` and `pk`. Deleting **each** of those
three, one at a time, reddens the lane with that symbol named in the failure — three
measurements, not one, because a guard that catches only the last entry added is a guard for
one symbol.

---

## Task 7: All three position kinds, asserted, against already-shipped node kinds

Design §5 item 7; §12.7:766-773; §22.4:1271; §12.7:777. **This is what makes the family
front-loadable**: all three kinds are reachable with byte-dispatch and error nodes alone.

**Files:** `test/common/position-kind-tests.sps` (new), `test/CMakeLists.txt`.

- [ ] **Step 1: Know which rows exist and which do not.**

§12.7's table at `:766-771` has four rows, and two of them are **half-rows**:

| Plan line | Kind | Producible in ①a? |
| --- | --- | --- |
| `:768` "Reexecute mismatch **or rejected current digit**" | `byte` | **First half yes** — a reexecute fallback. Second half needs Slice ③ |
| `:769` "Error edge after an advance" | `boundary` | **Yes** |
| `:770` "Zero-width machine action **or callback failure**" | `boundary` | **Neither half** — first is Slice ②, second is **Milestone 5** (§25:1572) and is never producible in M4 |
| `:771` "Truncated input during `finish!`" | `eof` | **Yes** |

So: three kinds are producible here; Slice ② makes `:770`'s first half producible; Slice ③
makes `:768`'s second half and the `:773` overflow rider producible. The design's "M4 adds
two rows to §12.7's table" is loose — both rows are already written; M4 makes them
*producible*, and `:773` is prose, not a row. A step that says "Slice ② closes row `:770`"
over-promises.

- [ ] **Step 2: Reach all three from shipped fixtures.**

`byte` (reexecute) and `boundary` (advance) both come from `http-version-machine.sls`'s two
machines (`make-http-version-machine`, `make-http-version-advance-machine`). `eof` comes from
a `finish!` over exhausted input — `eof-machine.sls`, which is already in eight lanes'
`SOURCES`. A lane may carry more than one fixture, and `byte-machine.unit.compile.chez.source`
carries none at all, so there is no constraint forcing one fixture per lane.

- [ ] **Step 3: Assert each kind in both executors and both execution lanes.**

Three position kinds × two executors × two execution lanes, **all asserted by value** — not
by "did not raise".

- [ ] **Step 4: Assert the state-id exclusion POSITIVELY.**

Both lanes must *report* a state id; only the comparison omits it (§12.7:777). Add one check
that fails if the exclusion is ever widened to drop a comparable member — the projection from
Task 5 has one owner precisely so this check has something to assert against.

- [ ] **Step 5: Resolve `reason` and `detail` (H18).**

§9.3:398-405 ships eight accessors; §22.4:1271 names five; §12.7:777 excludes one. `reason`
and `detail` are left neither required to match nor licensed to differ. Both lanes build the
record from the same inputs (decision 0022 item 3), so both **do** agree on them today.
Assert that agreement in this lane and record the reading beside the assertion, so the two do
not ship as orphans that a later slice re-derives.

- [ ] **Step 6: Sentinel — and get the arithmetic right.** "Two execution lanes" is source
  versus AOT, which in this repository is **two CTest registrations of the same program**
  selected by a launcher, outside the program. One process therefore observes at most
  3 kinds × 2 executors = **6** drives. The in-program sentinel asserts **6**, derived from
  what the parser returned and never from the test's own expected list; the ×2 for execution
  lanes is discharged by the lane pair existing and both passing, which CTest reports, not by
  anything the program can count. The loop over the three kinds needs its own sentinel too.

- [ ] **Step 7: Lane bookkeeping.** `byte-machine.differential.position-kind.chez.{source,aot}`
  (**D8**), each with a `TIMEOUT`, and in **both** lanes' `SOURCES`: the fixture `.sls` files
  **and `error-projection.sls`**, which Step 4 asserts against. Every lane in this tree lists
  every library it imports; omitting the projection leaves the AOT lane with no compiled
  object for it.

- [ ] **Step 8: Gate.** Six assertions by value per process, all passing, in **both** lane
  registrations — twelve drives across the pair; the in-program sentinel reporting **6**; and
  one check that fails when the exclusion is widened. Full `release` preset green.

**Executed 2026-09-02. The finish loop's initialization needed a case this task did not
plan.** A mutation setting `parser-finish-op!`'s `pk` initializer to `eof` was **UNCAUGHT**
against the truncation case, because every route into a finish-time error either hops —
setting `eof` on the way — or lands on the default-EOF terminal, which takes its own per-site
constant. Only an error state a prior feed **parked** on is reached by no jump at all, so only
it can observe what the loop was initialized to. The lane gained that case: a pause whose
continuation is an error node, driven feed → resume → `finish!`. This is the shape decision
0022 item 5 spends three paragraphs on, and without it the unconditional-`boundary` rule —
the correction Gate 0's review made as its Critical — is unwitnessed.

**And a bookkeeping trap worth naming.** Adding a pass means adding its
`byte_machine_mutation_run` too, and a `run` that looks redundant may be the previous pass's.
Removing one as a "duplicate" orphaned a whole shipped pass: its mutations were silently
discarded by the next `reset`, every individual lane stayed green, and the only thing that
noticed was `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` — which is exactly what that check's own
comment says it is for.

---

## Task 8: The pin sweep, the Pass 33 whole-pass audit, the status surfaces, and the CHANGELOG

Design §5 item 8; §9.5:444; AGENTS.md's mutation and record discipline.

- [ ] **Step 1: The whole-file `SITES` check, counted by FILE.**

Lex every `byte_machine_mutation(` block — a single left-to-right lex skipping both `#`
comments and bracket arguments, because this file's comments contain CMake syntax and its
bracket arguments contain unbalanced parens, so balancing parens reports a false *absent* and
a textual `EXPECT_STATUS` count reports a false *declared*. Keep the blocks whose `FILE` is
one of the five files this slice touches, and count each `FIND` in the post-edit source.

Pre-slice counts by FILE, measured at `c3ceec2` and confirmed two ways:
`verify.sls` **44**, `runtime.sls` **42**, `compile.sls` **24**, `normal-ir.sls` **23**,
`interpret.sls` **20**.

**Three** blocks resolve their `FIND` through a variable and will report a spurious
`found 0` under a literal count: `:1600` (`FIND "${find}"`, inside
`byte_machine_slice3_launcher_pass`, `:1583-1605`), `:1831`
(`FIND "${HEX_MUTATION_FIND}"`), and `:2220` (inside `byte_machine_slice5b_launcher_pass`,
`:2193-2228` — the second helper this plan's Global Constraints already names). Locate them
with `rg -n 'FIND "\$\{' test/support/cmake/SchemeMutationSuite.cmake`, which returns four
lines: these three plus a `string(FIND …)` call at `:1416` that is not a pin at all. None is a `src/` pin; special-case all three, or the sweep's own
output becomes untrustworthy.

- [ ] **Step 2: Re-anchor every pin this slice kills, by LABEL.**

The design's die-list, **plus the five it misses** (H1) and the seven-pins-on-three-anchors
problem (H2). Re-anchoring is a re-**measurement** of each pin's failure signature, not a text
edit. The obligation is recorded **in the tree beside the pin, named by mutation LABEL** —
not by line number, and not in the git-ignored ledger.

- [ ] **Step 3: The Pass 33 whole-pass audit, in both directions, against a merge-base
  control.**

Task 1 joined a **check** and a **case** to that pass's lane; adding a check widens every
existing pin exactly as adding a mutation does. Re-judge each pin through
`byte_machine_mutation_verdict` against every *other* mutation's captured output — static
inspection cannot see a collision.

Pass 33's live baseline is **42 mutations / 1722 ordered pairs** (`:3290-3291`, the fifth
audit block at `:3284-3316`). At 43 it is 43 × 42 = **1806**. Its narrative carries five
superseded counts (`:3149-3156`, `:3236`, `:3254-3255`, `:3257-3264`, and `:3290-3291`) plus
`:3313`, `:4092`, and five in-pin notes at 34 (`:3776`, `:3974`, `:4030`, `:4184`, `:4250`) —
all of which this sweep **supersedes rather than appends to**. Run a control on the merge
base: a pass collision-free there and colliding at HEAD is this branch's doing.

Sort residue into its **three** kinds, not two — **under-anchored** (a tighter pin exists),
**subsumed** (the narrow mutant's whole record set is a subset of *one* sibling's), and
**separable but deliberately declined**. A subset test reports the third as clean. Compare
whole FAIL **records**, not lines. Rule out under-anchoring by exhaustion, not inspection.
Run the subset test *before* the fix pass.

Pass 37's two `verify.sls` pins (`:5332`, `:5341`) target `valid-name?` itself — `:5332`'s
FIND is `verify.sls:46-47` and `:5341`'s second line **is** `  (define (valid-name? sym)` at
`:43` — which Task 1 reuses rather than edits. Re-check their `SITES` rather than assuming
them. Pass 37 also carries a **third** pin on the same text with `FILE src/byte-machine/compile.sls`
(`:5350-5357`, whose FIND spans `compile.sls:56-57`, a byte-identical twin of `verify.sls:42-43`).

- [ ] **Step 4: Pass 49's full range (H14).** `:6486` is the header, but the pass runs to
  `byte_machine_mutation_run` at **`:6634`** — the second `3849` at `:6580`, the verify
  command at `:6602-6613`, the block at `:6615-6632` with LABEL `:6618` and FIND `:6628`
  (the 23rd `normal-ir.sls` pin, textually identical to Pass 35's `:5011` under a different
  SPEC). Re-baselining `:6486-:6548` alone leaves stale numbers in the same pass. The mutant
  byte count `3849` also sits at
  `test/support/harness/byte-machine/test/http-version-machine.sls:19` (H10).

- [ ] **Step 5: `EXPECTED_PASSES` / `EXPECTED_MUTATIONS`, from measurement only.**

`SchemeMutationSuite.cmake:734-735`, currently `46` and `236`. Write the values the suite
**reports**, never predicted ones. The totals are a runtime accumulation, so a textual census
cannot check them (see Global Constraints).

- [ ] **Step 6: The `EXPECT_SURVIVES` evidence, taken with an anchored count (H12).**

The design's `git diff … | grep -E '^[+-].*EXPECT_SURVIVES'` being empty is over-broad: 17
lines in the file contain the string and only **9** are directives; this slice rewrites
narrative including `:3040`, one of the eight comment lines. Report the anchored count
(`rg -c '^\s+EXPECT_SURVIVES'` = **9**, unchanged) **and** the declaration-level diff, and say
which was measured how.

- [ ] **Step 7: Verify §9.5:442; do not re-edit it (H20).**

Decision 0018's Gate 0 work already replaced that line in `f215af7`. At HEAD it reads
"Milestone 4 retires the versioned *name*, not the version: one unversioned constructor checks
`current-abi-version` — now 3 —". Confirm it, and confirm decision 0012 item 1's and decision
0010 item 4's dated notes are present. **§9.5:444 is deliberately not touched**: a
version-number bump is what it requires, and all three of its requirements are met here.

- [ ] **Step 8: §25:1570's disposition (H19).**

The criterion reads `- interpreter/generated fields and traces match.` and contains no error
clause. AGENTS.md's dated-disposition form is for a criterion whose work has *closed*, and
Milestone 4 has not; this slice discharges only the error clause, so what it writes is a
dated **note recording the reading and the part discharged**, leaving the criterion itself
untouched and open. The note names design §4.6's reading — that "traces match" is discharged by §22.4:1262-1272's comparison list, of which
`:1271` is the error bullet — and naming the file and case in the tree that meets it.

- [ ] **Step 9: Status surfaces, corrected in place.**

**Four** surfaces carry a status sentence this slice falsifies, not two, and AGENTS.md
enumerates the set precisely because a surface no step names is a surface nobody updates:

1. `CHANGELOG.md`'s `[Unreleased]` preamble — "Milestone 4 (fields, actions, and branches)
   has not started".
2. `README.org:20-21` — the same sentence.
3. `docs/plans/byte-machine-implementation-plan.md`'s Status line — the parent plan, which
   the Milestone 3 closing slice corrected for its own milestone.
4. `docs/plans/milestone-4-design.md:3` — "Status: **NOT STARTED.** Gate 0 not yet
   discharged; no slice begun." **This one is already false at HEAD**, not merely made false
   by this slice: Gate 0 discharged 2026-08-31 in `f215af7`.

A status line is an **instruction**, corrected in place, not a record. Correct all four to
name Milestone 4 as in progress with Gate 0 discharged and Slice ①a landed. Locate each by
its text, not by the line number given here.

`README.org`'s documentation list already carries the Milestone 4 design row at `:81`;
nothing is owed there. The milestone's *closing* status moves when M4 closes, not here.

`CHANGELOG.md` gains the §9.5:444 entry: the generated-ABI version bump, deterministic
regeneration, and what moved. Its eight existing fingerprint occurrences are **records** of
what was measured then — annotated if anything, never rewritten.

- [ ] **Step 10: Gate — the slice's exit evidence.**

In the tree, at close-out, each as a literal:

1. A reason containing TAB reports **exactly 1** diagnostic, code `invalid-name`; every
   shipped fixture verifies with **exactly 0**; a reason containing `"`, `\` and LF verifies
   with **exactly 0**, emits with `\"`, `\\` and `\n` in the `errs` entry, and yields a
   generated library that `load`s without a reader error.
2. Pass 33 holds **43** mutations after the edit, against **42** pre-slice (the design's 44
   is `verify.sls` across the whole file: 42 + Pass 37's 2), and its sweep judges
   43 × 42 = **1806** ordered pairs in both directions against the merge-base control. Every
   residue is recorded in the tree beside its pin by LABEL, with its measurement, and
   classified into one of the three buckets — under-anchored, subsumed, or separable but
   declined — never by a subset test alone.
3. `reserved-member-2` holds **31** symbols; `byte-machine.unit.reserved-drift.chez.{source,aot}`
   green. `reserved-member-3` holds **15**; the new member-3 lane green and naming each of the
   three deleted entries in turn.
4. `rg -n 'byte-machine-make-compiled-machine/v[12]' test/fixtures/` returns **no output**;
   all three goldens name the unversioned constructor, ABI version **3**, and a
   `(quote #(#()))` metadata argument.
5. Each superseded fingerprint returns **no output** from `rg -o '<value>' src/ test/`, and
   each successor appears at its own measured per-file counts from the **H9** matrix —
   9/3/5/2 by value, **19** in total, **none in `src/`**.
6. `parser-error?` is true at every error site of all three shipped fixtures in both
   executors, with the five §22.4:1271 members equal across lanes and the state id asserted
   present-and-excluded. All three §12.7 position kinds asserted in both executors and both
   execution lanes, sentinel reporting **12**.
7. `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` at their **measured** totals; the CMake mutation
   suite still **1/72**; the nine `EXPECT_SURVIVES` unchanged, shown by the anchored count
   **and** the declaration-level diff.
8. `ctest --preset release` and `--preset pr` both report `100% tests passed, 0 tests failed
   out of N`, where N is **86 plus twice the number of new programs** (one source lane and
   one AOT lane each) — state N before running — and `--preset no-scheme` reports **8/8**.
9. `CHANGELOG.md` carries the §9.5:444 entry, and **all four** status sentences are
   corrected — `CHANGELOG.md`'s preamble, `README.org`, the parent plan's Status line, and
   `milestone-4-design.md:3`. `rg -n 'Milestone 4.*has not started|NOT STARTED' README.org
   CHANGELOG.md docs/plans/` returns **no output**.
10. `rg -n 'field' src/` returns only `machine-fields` (`ir.sls:10`, `:370`), the encoding's
    zero-count write in `normal-ir.sls`, and `fieldv` in `compile.sls` — no field *type*, no
    field *slot*, no accessor. Anything else means ①b work leaked into ①a.

---

## Self-Review (run after all eight tasks)

- [ ] **Every citation in this plan re-read against HEAD.** This plan's own line numbers were
  measured at `c3ceec2` and it edits four of the files it cites. A citation into a file your
  own change edits is stale on arrival and no link check can see it. Do the content edits
  first and re-anchor last, and name the table, not just the row.
- [ ] **Every gate that reads as prose replaced by a literal, a count, or "no output".** A
  step whose expected result is described gets reported as passing without being run.
- [ ] **Every "met" or "moot" checked by finding the thing in the tree**, not by reading the
  document that claims it.
- [ ] **Every count carries the qualifier that makes it true.** 42 is Pass 33; 44 is
  `verify.sls` by FILE; 236 is the run-time accumulation, 224 the top-level declaration count
  and 226 the textual occurrence count; 9 is anchored
  `EXPECT_SURVIVES` and 17 unanchored; 19 is fingerprint occurrences in `src/`+`test/` and 27
  including `CHANGELOG.md`.
- [ ] **The whole-branch review, with the instruction quoted verbatim in the reviewer's
  prompt:** *check what this claims the code or the spec DOES against the code and the spec,
  not against the prose.* The task-scoped reviews that lacked it caught none of Gate 0's three
  false reasons; the one that carried it caught all three.
- [ ] **After any cross-lane fix, ask both questions:** which value do the two lanes now agree
  on, and does the spec's own principle pick it? And can the mutant still be told from the
  baseline? A fix that makes two lanes agree can disarm the test that caught them — Gate 0
  shipped exactly that and caught it one review later.
- [ ] **The whole mutation suite re-run after every task**, not just the touched lanes.
- [ ] **`git status` before every commit**; stage explicitly, never `git add -A`. Subagents
  write files despite being told not to, and a blanket add commits them under a message that
  does not describe them.
- [ ] **Re-read every early artifact against HEAD before the final review**, and note what
  changed in a dated amendment. A record written in Task 1 goes stale against Tasks 4-8: the
  three decision records this slice consumes were written against `a942327`, and this slice
  moves `src/` for the first time since. State the tree a record was decided against, then
  disclose in a dated note what the change it authorised has altered — do not rewrite it as
  though it were written at the end, because the tree it was decided against is its evidence.
- [x] **Report the design defects upstream — done 2026-09-01.**
  `milestone-4-design.md` now carries an `> **Amendments**` pointer block after its Status
  paragraph and a dated note at its foot, **2026-09-01 (Slice ①a planning)**, carrying items
  A through J: this plan's §0 and §0b findings in the form the design's own readers need.
  Two live work orders were corrected in place and marked at the site — §5 task 6's "two
  entries" (now three) and §6 task 6's contradicting `reserved-member-3` sentence — and the
  Status line, an instruction, was corrected from "NOT STARTED" to "IN PROGRESS". Everything
  else is annotated rather than rewritten, because each named sentence was never true and is
  load-bearing evidence of what the design believed. When a later slice finds another, it
  goes in that note, not only here: a defect fixed only in a plan leaves the design to
  mislead the next slice.
- [ ] **The closing ritual (AGENTS.md), which needs the owner's go-ahead before the merge.**
  Check mergeable and CI first, then on the owner's yes: squash-merge the PR, fast-forward
  local `main`, delete the branch locally and on the remote, and reflect — durable facts into
  memory, project standards into `AGENTS.md`, and anything the code should say about itself
  into a comment at the site. A finding recorded only in a session transcript has not been
  recorded. Note that a docs-only commit gets **no CI check at all**
  (`.github/workflows/ci.yml`'s `paths-ignore`), so "0 checks" on such a PR is by design;
  this slice's commits touch `src/` and will run CI.
