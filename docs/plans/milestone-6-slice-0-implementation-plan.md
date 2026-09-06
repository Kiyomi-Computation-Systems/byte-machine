# Milestone 6 — Slice ⓪ (the label clause made total, and the shared name grammar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Authority: `milestone-6-design.md` §4.12 (both items **approved by the owner
2026-09-06**) and §5, then the parent plan's Milestone 5 close note (the two
paragraphs that name "Milestone 6's close-out" as fallback receiver), then
`§16.2:886` and `§9.3:423`.

This is a **hardening slice on the Milestone 5 Slice ⓪/⓪b precedent**: it discharges
no `§25` bullet, adds no node kind, and precedes Slice ①. It exists because two
obligations named this milestone's close-out as their fallback receiver and the
owner chose to close them rather than defer them a third time.

Everything below was measured at **`cd77fb9`** (`main` after PR #74; `src/` and
`test/` are byte-identical to `b470665`, so the design's measurements still hold:
`release` 108/108, 55 passes / 476 mutations, 30 diagnostic codes over 55 sites).
Every `§N:LINE` was resolved by opening the plan at that line, and every
`file:line` below names the construct as well — the lines move the moment Task 1
lands, and no tool here notices.

---

## 1. Eight findings that shape the work

### F1 — the label fold reaches FOUR arms in TWO passes, not three in one

Design §4.12 item 1 folds `valid-label?` into "`pass-names-valid`'s three arms".
Measured: the machine arm and the node arm of `pass-names-valid` are `if`s, only
the error-declaration arm is an `and` — and the **uint field** is checked
nowhere in that pass. Its name check lives in `pass-fields`' field-name arm
(`verify.sls`, the `(valid-name? (uint-field-name f))` `map`), a pass of its own
by that pass's stated reason ("so that those two keep the pin-visible shape they
were measured with"). So the fold is four arms: three in `pass-names-valid`, one
in `pass-fields`. The design's §4.12 item 1 already says so after its review;
this finding records that the pin arithmetic below follows from it.

### F2 — two shipped FINDs move, two survive as substrings, one is untouched

Five shipped mutations anchor on the four arms' `valid-name?` calls, all
`FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source`:

| LABEL | FIND | after the fold |
| --- | --- | --- |
| "verify: the machine-name grammar check is suppressed" | `(if (valid-name? (machine-name m)) '()` | **moves** — the arm becomes `(if (and (valid-name? …) (valid-label? …)) '()`; re-anchor FIND **and** REPLACE |
| "verify: the node-name grammar check is suppressed" | `(if (valid-name? (node-name n)) #f` | **moves**, same reason |
| "verify: the error-code grammar check is suppressed" | `(valid-name? (error-declaration-code e))` | **untouched** — a fourth conjunct joins the existing `and` on its own line |
| "verify: a field name is not checked against the portable grammar" | `(valid-name? (uint-field-name f))` | **survives as a substring** of `(and (valid-name? (uint-field-name f)) (valid-label? …))`; its `REPLACE [[#t]]` still means "name check dropped" |
| "verify: every field name is reported as nonportable" | the same FIND | survives likewise; `REPLACE [[#f]]` still means "every field rejected" |

`SITES` is asserted exactly at 1 in both directions, so a FIND that stops
matching fails at CMake **configure** time, not as a test. Re-anchor a moving
FIND together with its REPLACE, and read the pair afterwards asking what single
decision separates them — the standing rule since Slice ③ shipped a re-anchored
FIND whose REPLACE still carried pre-slice text.

### F3 — case labels have no name of their own and report under the owning node

`make-byte-case` and `make-sequence-case` store a `source-label` and neither has
a `name`. A diagnostic's `node` slot is "the identifying name of whatever the
diagnostic is about" (`pass-fields`' own comment), so a bad case label is
reported **under the owning node's name**, folded into the node arm's `and`
beside the node's own label: one finding for a node bad in name, label or any
case label — the fold's one-finding shape, which `verify-tests.sps` already
witnesses for the callback family ("a declaration bad in BOTH name and label
reports ONCE"). The imprecision this carries — a node whose *name* is portable
is reported with the offending label nowhere in the record — is the one the
callback arm's own comment already admits; it is stated, not fixed.

### F4 — `node-source-label` is a new per-kind census site, and Slice ① owes it an arm

The node arm needs one label from any of twelve kinds, and `ir.sls` has no
dispatcher for it. Task 1 adds `node-source-label` beside `node-name` — a `cond`
with one arm per kind above a raising `else`, `node-name`'s exact shape. **That
is a thirteenth-kind obligation**: the design's appendix must gain the row
("`node-source-label` — one arm above the raising `else`") so Slice ① sees it, and
a **derived** totality check must exist so a kind added to `node?` without an
arm reddens by comparison rather than by the `else`'s raise. The check lives in
`kind-position-census-tests.sps`, which already reads `ir.sls` as a datum for
`node?`'s disjuncts (`kind-predicates-in-source`, the S2 row): a sibling walk
collects `node-source-label`'s `cond` predicates and asserts the two sets are
equal. Nine kinds also need the accessor the dispatcher will call (F5).

### F5 — nine carriers have no accessor, and the slots are these

Nineteen constructors take a `source-label`; ten have an accessor. The nine
without, each with the vector slot its constructor stores the label in, measured
from the `(vector …-tag …)` form in each constructor:

| constructor | slot | new accessor |
| --- | --- | --- |
| `make-byte-case` | 3 | `byte-case-source-label` |
| `make-byte-dispatch-node` | 5 | `byte-dispatch-node-source-label` |
| `make-stop-node` | 2 | `stop-node-source-label` |
| `make-finish-node` | 2 | `finish-node-source-label` |
| `make-pause-node` | 3 | `pause-node-source-label` |
| `make-error-node` | 3 | `error-node-source-label` |
| `make-error-declaration` | 4 | `error-declaration-source-label` |
| `make-sequence-case` | 3 | `sequence-case-source-label` |
| `make-sequence-dispatch-node` | 5 | `sequence-dispatch-node-source-label` |

Bare `vector-ref`s, as every existing `-source-label` accessor is; **exported from
`ir.sls` only**, not from `graph.sls` — `graph.sls`'s header keeps machine
accessors private, and the verifier imports the private library already.

### F6 — the parent plan claims a receiver sentence that the arm does not carry

The Milestone 5 close note reads "Owed by whoever next widens
`pass-declarations`' label arms, and failing that by Milestone 6's close-out;
written at that arm in `verify.sls` as well as here" (`§Dated:2379-2381`).
Measured: the arm's comment records the gap and ends "recorded in the parent
plan's Milestone 5 close note with a receiver" — it names **no receiver**. The
close note is a **record**, so this is a dated disposition appended beside it
(Task 6), never a rewrite; the design's review found it and §4.11 already says
"half true (gap yes, receiver no)".

### F7 — two census instruments constrain the shape of the new code

- `kind-position-census-tests.sps`'s `edge-roles-in-source` collects the quoted
  symbol from **every** `(cons 'SYM …)` form in `verify.sls` and compares the set
  to a declared mapping. `node-case-labels` (Task 2) must therefore build no
  `(cons '…)` — an `append`/`map` shape, as `span-transfer` was rewritten to
  `(list 'active …)` for exactly this reason.
- `diagnostic-census-tests.sps` derives emission sites from every
  `(define (make-diagnostic… ) …)` and pins `(invalid-name 6)` and
  `(invalid-field-declaration 2)`. The fold adds no site and no constructor, so
  both rows stay — **run** the census rather than assume it.

### F8 — the names library changes three FINDs' homes and one FIND's text

The grammar `[a-z][a-z0-9-]*` is written twice: `verify.sls`'s `lower-alpha?`,
`name-char?`, `valid-name?` and `compile.sls`'s identical trio behind
`valid-binding?`. Three shipped mutations anchor inside those bodies:

| LABEL | FILE / SPEC | FIND (verbatim) | after Task 4 |
| --- | --- | --- | --- |
| "verify: a name with a non-lowercase first char is accepted" | `verify.sls` / `verify.identifier-repertoire` | `(lower-alpha? (string-ref s 0))` + `(let loop ((i 1))` | the text moves to `names.sls`; **FILE becomes `src/byte-machine/private/names.sls`**, SPEC unchanged |
| "verify: any interior character is accepted" | `verify.sls` / `verify.identifier-repertoire` | `name-char?`'s body + `(define (valid-name? sym)` | moves to `names.sls`; the second line of the FIND is re-anchored on the line that follows the body **there** |
| "compile: the binding grammar check is dropped" | `compile.sls` / `unit.compile` | `(and (> (string-length s) 0) (lower-alpha? (string-ref s 0))` | `compile.sls` keeps its FILE; the FIND becomes `valid-binding?`'s new `(portable-name? sym)` conjunct, whose `REPLACE` is `#t` |

The identifier-repertoire lane already loads every library the emitter does
(`BYTE_MACHINE_CORE_EMIT` ⊇ `BYTE_MACHINE_CORE_PRIVATE`), so a mutation whose
FILE is the new library is witnessed by that lane without a new SPEC.

---

## 2. What this slice ships

1. **Every `source-label` in the tree checked against `§10.1:480`** — nineteen
   carriers, through one predicate at four arms, with no new diagnostic code and
   an unmoved census (Tasks 1–3).
2. **One name grammar, in one private library, read by three consumers** —
   `verify.sls`, `compile.sls`, and for the first time `runtime.sls`'s
   `make-callback-failure`, closing `§9.3:423` (Task 4).
3. **Both obligations' second ends** written where their receivers will look:
   the source notes corrected in place, an appended parent-plan disposition, and
   the design's appendix row for Slice ① (Tasks 5–6).

Three source commits, one PR, each green on its own: the accessors and the
dispatcher (Task 1, which changes no verifier behaviour); the fold **with its
re-anchored pins** (Tasks 2 and 3 — the fold moves two shipped `FIND`s, and a
commit carrying the fold without their re-anchor fails the mutation lane at
configure time, which is a red intermediate commit); and the names library with
its re-homed pins (Task 4). The pin sweep (Task 5) runs once after all three,
because two of them move `FIND`s in `verify.sls`; the documentation commit
(Task 6) closes the PR.

---

## Global Constraints

- **Authority order.** Design §4.12 and §5, then the parent plan. Where an
  authority is wrong, **stop and say so** — the design's own review withdrew one
  of its rules a day ago.
- **No new diagnostic code, no new emission site.** The census must read
  `(invalid-name 6)` and `(invalid-field-declaration 2)` at the slice's head.
  If a step needs a new site, the plan is wrong and stops.
- **No `(cons 'SYM …)` form enters `verify.sls`** (F7).
- **`SITES` is asserted exactly at 1 in both directions** and a broken FIND fails
  at configure time. Re-anchor FIND and REPLACE together (F2). Before adding
  any line to `verify.sls` or `ir.sls`, check it does not duplicate a pinned
  line: every `-source-label` accessor is a one-line `vector-ref` and nine new
  ones must not collide with a pinned existing one (measured: no shipped FIND
  anchors on any `-source-label` accessor definition — confirm before Task 1).
- **Fixtures for a label conjunct use a wrong-SHAPE label (an integer), not a
  bad character.** Every label conjunct nests inside the shipped permissive
  `reason-char?` mutant unless the fixture carries a value that mutant cannot
  accept; `valid-label?`'s `(else #f)` rejects an integer without consulting the
  repertoire, which is the shipped span-family pin's own measured reason.
- **Every case asserts both directions** — an integer label rejected under the
  expected `diagnostic-node`, and a portable label (a symbol and a string)
  accepted — so an arm rejecting every carrier fails as loudly as one rejecting
  none.
- **Sentinels read observed counts**, never a table's length; and the loop over
  the carriers asserts its own length.
- **Mutations go into the existing passes, before each pass's `_run`**, never in
  a new pass: verify.rejections' pass (its `_run` follows the four M5 label pins),
  unit.ir's, unit.runtime's, unit.compile's, identifier-repertoire's.
  `EXPECTED_PASSES` stays 55; `EXPECTED_MUTATIONS` is re-measured from the
  harness, not computed.
- **Filter suite output for the failure signatures** — `CMake Error`,
  `wrong reason`, `UNCAUGHT`, `tests passed` — and the exit status. The mutation
  suite prints "suite complete" on the way to failing.
- **Record vs instruction.** The parent plan's close note is a record and takes
  an appended disposition; the three source comments this slice retires are
  instructions and are corrected in place; the design's appendix is an
  instruction and gains rows in place.
- **Both lanes, always.** Every new case runs in `.chez.source` and `.chez.aot`.

---

## Task 1 — The nine accessors and `node-source-label`, tests first

**Files:** `src/byte-machine/private/ir.sls`; `test/common/ir-tests.sps`;
`test/common/kind-position-census-tests.sps`.

- [ ] **Step 1: Confirm no shipped pin anchors on an accessor line this task adds beside**

```bash
rg -c -- '-source-label' test/support/cmake/SchemeMutationSuite.cmake
rg -n 'define \(node-name' src/byte-machine/private/ir.sls
```
Expected: the first prints a count — read each hit and confirm none is a `FIND`
on an `ir.sls` accessor definition (measured 2026-09-06: every hit is inside the
four `verify.sls` label-arm FINDs and their comments); the second prints one line,
where `node-source-label` goes next.

- [ ] **Step 2: Write the failing tests**

In `ir-tests.sps`, one table-driven group on the span-node group's shape: a row
per carrier in F5's table — builder, predicate where one exists, the new
accessor — asserting the accessor answers `'lbl` when built with `'lbl` and `#f`
when built with `#f`; sentinel `driven` = **9**. A second case drives
`node-source-label` over all twelve kind builders (the kind × position census's
`kind-table` shape) and asserts `'lbl` for each; sentinel **12**; and asserts it
**raises** a contract violation on a non-node.

In `kind-position-census-tests.sps`, beside S2: a walk over `ir.sls` as a datum
that finds `(define (node-source-label x) (cond …))` and collects each arm's
predicate name, compared for set equality against `kind-predicates-in-source`.
Expected literal in the check: "the same twelve kinds". **This row is the one that
goes red when Slice ① adds the thirteenth disjunct without the arm.**

- [ ] **Step 3: Implement**

Nine one-line accessors at F5's slots, exported from `ir.sls`; `node-source-label`
as a `cond` over the twelve predicates with `node-name`'s raising `else`. No
`graph.sls` change.

- [ ] **Step 4: Run**

```bash
ctest --preset release -R 'unit\.ir\.|kind-position-census' --output-on-failure
```
Expected: `100% tests passed` over **4** tests.

- [ ] **Step 5: Commit** — "feat(ir): a source-label accessor for every carrier, and `node-source-label`". Green on its own: no verifier arm reads the new accessors yet.

## Task 2 — The fold: four arms, one predicate, tests first

**Files:** `src/byte-machine/verify.sls`; `test/common/verify-tests.sps`.

- [ ] **Step 1: Write the failing group**

A new `harness-group` in `verify-tests.sps`, "every label carrier is checked
(§16.2:886)", driven from a table of **seventeen** rows — the machine, the uint
field, the error declaration, a byte case, a sequence case, and the twelve node
kinds (the two declaration families already have their group). Each row is a
builder taking a label and the `diagnostic-node` the finding must carry:

| carrier | reported under |
| --- | --- |
| machine | the machine name |
| uint field | the field name |
| error declaration | the declaration name |
| byte case, sequence case | the **owning node's** name (F3) |
| each node kind | the node's name |

Per row: an integer label yields exactly `((invalid-name . <expected-node>))`
over the diagnostics; a portable symbol label and a portable string label each
yield `'()`. Sentinel: `driven` = **17**, and the table's length asserted to be
17 separately. One more case: a node bad in **name, label and a case label**
reports **once** (F3's fold assertion).

- [ ] **Step 2: Implement the fold**

- `pass-names-valid`'s machine arm: `(if (and (valid-name? (machine-name m)) (valid-label? (machine-source-label m))) '() …)`.
- Its node arm: `(and (valid-name? (node-name n)) (valid-label? (node-source-label n)) (for-all valid-label? (node-case-labels n)))`, with `node-case-labels` a local `cond` — byte-dispatch cases' labels, sequence-dispatch cases' labels, `'()` otherwise — built with `map`, **no `cons`-quote form** (F7).
- Its error-declaration arm: a fourth conjunct `(valid-label? (error-declaration-source-label e))` on its own line, leaving the `(valid-name? (error-declaration-code e))` line as it is (F2).
- `pass-fields`' field-name arm: `(and (valid-name? (uint-field-name f)) (valid-label? (uint-field-source-label f)))`, keeping `(valid-name? (uint-field-name f))` verbatim inside it (F2).
- Messages: extend each arm's static message with "or label" (they are compared
  by code, never by text, but a reader tracing a report deserves the word).

- [ ] **Step 3: Correct the two instructions this makes false**

- `valid-label?`'s header comment: "for Milestone 5's two new declaration
  families only (design §4.12 item 2 …; design §10 excludes the nine
  already-shipped label-bearing kinds)" → the check is total over every
  carrier as of Milestone 6 Slice ⓪, and name the four arms.
- The `pass-declarations` label-arm comment beginning "*** DO NOT EXTEND THESE
  TWO ARMS …" and its "EIGHT of those are excluded by NOTHING" paragraph → the
  gap is closed; say where each carrier is checked and keep the fold's
  one-finding argument.

- [ ] **Step 4: Run, and read the census**

```bash
ctest --preset release -R 'verify\.rejections|diagnostic-census|kind-position-census' --output-on-failure
```
Expected: `100% tests passed` over **6** tests — the census lanes green is the
measurement that no site moved.

- [ ] **Step 5: Do not commit yet.** The fold has moved two shipped `FIND`s (F2), so the mutation lane fails at configure time until Task 3 re-anchors them; Tasks 2 and 3 are one commit.

## Task 3 — Pins for the label work

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`.

- [ ] **Step 1: Re-anchor the two moving FINDs (F2)**

"verify: the machine-name grammar check is suppressed" and "verify: the
node-name grammar check is suppressed": new FIND on the `(if (and (valid-name? …`
opening, REPLACE dropping the `valid-name?` conjunct to `#t` **and nothing
else**. Confirm the other three F2 pins still resolve to exactly one site:

```bash
for s in '(valid-name? (error-declaration-code e))' '(valid-name? (uint-field-name f))'; do printf '%s -> ' "$s"; rg -c -F "$s" src/byte-machine/verify.sls; done
```
Expected: `1` and `1`.

- [ ] **Step 2: Add the conjunct pins, in verify.rejections' pass before its `_run`**

Five mutations, each dropping one label conjunct to `#t`, each pinned on its
integer-label case's own `(case, check)` tail with the `got .[)]` shape the M5
span-family pin documents:

1. the machine arm's label conjunct;
2. the node arm's `node-source-label` conjunct;
3. the node arm's `node-case-labels` conjunct;
4. the error-declaration arm's label conjunct;
5. `pass-fields`' label conjunct.

And **one in unit.ir's pass**: `node-source-label`'s arm for one kind answering
`#f` (absence) — caught by comparison in `ir-tests.sps`'s twelve-kind case and
again in `verify-tests.sps`'s row for that kind; pin on the `ir-tests` check.
Do not pin an arm swapped for a same-slot sibling's accessor: measured, `stop`
and `finish` both store the label at slot 2 and every `-source-label` accessor
is an unguarded `vector-ref`, so that mutant is observationally identical and
would ship `UNCAUGHT`. Say so in a comment beside the pin.

- [ ] **Step 3: Judge each pin against its lane, both directions**

Run the suite and then the sweep over the two passes touched; a new pin that
matches an existing mutant's output, or an existing pin the new mutants match, is
re-anchored before the commit.

```bash
ctest --preset release -R scheme-mutation --output-on-failure 2>&1 | rg -n 'CMake Error|wrong reason|UNCAUGHT|tests passed'
```
Expected: exactly one line, `100% tests passed, 0 tests failed out of 1`, and no
other match.

- [ ] **Step 4: Commit** — "feat(verify): §16.2:886's label clause over every carrier, with its pins" (Tasks 2 and 3 together).

## Task 4 — `(byte-machine private names)`, and its three consumers

**Files:** `src/byte-machine/private/names.sls` (new); `src/byte-machine/verify.sls`;
`src/byte-machine/compile.sls`; `src/byte-machine/runtime.sls`;
`test/common/runtime-tests.sps`; `test/CMakeLists.txt`;
`test/support/cmake/SchemeMutationSuite.cmake`.

- [ ] **Step 1: Write the failing runtime case**

In `runtime-tests.sps`'s "callback failure values" group, beside "the code must
be symbolic (§9.3:423)": a case asserting `(make-callback-failure 'BadCode #f)`
and `(make-callback-failure 'a_b #f)` each raise `invalid-argument` for `'code`,
and that `(make-callback-failure 'ok-code-9 #f)` builds. Run the runtime lanes;
expected: **red** on the new case only.

- [ ] **Step 2: The library**

`src/byte-machine/private/names.sls`, on `conditions.sls`'s shape: imports
`(rnrs)` only; exports **`portable-name?`** — a symbol satisfies `[a-z][a-z0-9-]*`
— and nothing else. The reserved-set tests stay with their owners: a callback
code is never emitted, so `reserved-member-1` is not its business, and
`compile.sls`'s three sets are the emitter's. Header comment: `§10.1:480`'s
grammar, the three consumers, and why the runtime may import it (decision 0008
constrains what the **generated** library imports; the runtime already imports
`(byte-machine private conditions)`).

- [ ] **Step 3: The three consumers**

- `verify.sls`: delete `lower-alpha?` and `name-char?`; `valid-name?` becomes
  `(and (portable-name? sym) (not (memq sym reserved-member-1)))`; import the
  library. `reason-char?`/`valid-reason?` stay — a different repertoire.
- `compile.sls`: delete its `lower-alpha?` and `name-char?`; `valid-binding?`
  becomes `(and (portable-name? sym) (not (memq sym reserved-member-1)) (not (memq sym reserved-member-2)) (not (memq sym reserved-member-3)))`; import the library.
- `runtime.sls`: `make-callback-failure`'s guard becomes
  `(unless (and (symbol? code) (portable-name? code)) …)`; import the library;
  **replace** the two comment paragraphs ("TYPE ONLY HERE …" and "*** RECEIVER
  …") with the fact — `§9.3:423`'s grammar half is enforced through
  `(byte-machine private names)`, closed by Milestone 6 Slice ⓪.

- [ ] **Step 4: The manifests**

In `test/CMakeLists.txt`: `BYTE_MACHINE_CORE_PRIVATE` gains `names.sls` after
`conditions.sls`; `BYTE_MACHINE_CORE_RUNTIME` gains it after `conditions.sls`
(the AOT launcher compiles in list order, so the library precedes its importer
in both); the `REMOVE_DUPLICATES` comment above `BYTE_MACHINE_CORE_ALL` names
`names.sls` beside `conditions.sls` as the second file reaching it twice.

```bash
rg -c 'private/names\.sls' test/CMakeLists.txt
```
Expected: **`2`**.

- [ ] **Step 5: Re-home and re-anchor the three grammar mutations (F8), and add one**

- "verify: a name with a non-lowercase first char is accepted" and "verify: any
  interior character is accepted": `FILE src/byte-machine/private/names.sls`,
  FINDs on the grammar body **as written there**, SPEC unchanged.
- "compile: the binding grammar check is dropped": FIND
  `(and (portable-name? sym)` in `compile.sls`, REPLACE `(and #t`; confirm
  `(portable-name? sym)` occurs **once** in `compile.sls`.
- New, in unit.runtime's pass before its `_run`: `make-callback-failure` drops the
  `(portable-name? code)` conjunct — pinned on Step 1's case.

```bash
rg -c -F '(portable-name? sym)' src/byte-machine/compile.sls src/byte-machine/verify.sls
rg -c -F '(portable-name? code)' src/byte-machine/runtime.sls
```
Expected: `1`, `1`, `1`.

- [ ] **Step 6: Run everything**

```bash
ctest --preset release --output-on-failure 2>&1 | rg -n 'tests passed|Failed|Not Run'
```
Expected: `100% tests passed, 0 tests failed out of 108` and no other line.
`reserved-drift` is among them: the runtime's export set is unchanged because
the predicate is imported, not re-exported.

- [ ] **Step 7: Commit** — "refactor(names): one portable-name grammar for the verifier, the emitter and the runtime".

## Task 5 — The pin sweep, both directions, once

Both commits move FINDs in `verify.sls`. Re-judge every pin in the five touched
passes against every other mutant in its lane, in both directions (a new pin
matched by an old mutant is as much a collision as the reverse), and record any
subsumed residue **in the tree beside the pin**, named by LABEL. Re-measure the
totals from the harness:

```bash
rg -n 'EXPECTED_PASSES|EXPECTED_MUTATIONS' test/support/cmake/SchemeMutationSuite.cmake | head -2
```
Expected: `EXPECTED_PASSES 55` unchanged; `EXPECTED_MUTATIONS` at the value the
suite's own totals line reports, which is 476 plus the mutations Tasks 3 and 4
added and minus none — state the number you measured, not this sentence.

## Task 6 — Both ends, and the design's appendix

- [ ] **Step 1: The parent plan — one appended disposition, never an insertion**

```bash
wc -l docs/plans/byte-machine-implementation-plan.md
```
Run before and after; the count grows only at the foot. Append under
`## Dated dispositions` a heading `### §16.2:886 and §9.3:423 — Milestone 6
Slice ⓪, delivered`, dated, stating: the label clause is total over nineteen
carriers, through four arms and one predicate, no new code, census unmoved;
`§9.3:423`'s grammar half is enforced at `make-callback-failure` through
`(byte-machine private names)`, and where that predicate lives and why; and
**F6** — the close note's "written at that arm in `verify.sls` as well as here"
was false when written, the arm carried the gap and no receiver, and the
receiver's second end is this disposition.

- [ ] **Step 2: The design's appendix and §5**

`milestone-6-design.md` is an instruction and is corrected in place: the
`ir.sls` table gains "`node-source-label` — one arm above the raising `else`;
Slice ① owes it, and the census's derived row reddens until it exists"; the
`verify.sls` table gains "`node-case-labels` — no arm, the kind has no cases";
the test-side table gains the `node-source-label` totality row under
`kind-position-census-tests.sps`; §5's first paragraph gains the landing date and
PR. The Amendments block indexes it.

- [ ] **Step 3: The four status surfaces, and the ones the ritual does not sweep**

`README.org`'s status paragraph, `CHANGELOG.md`'s `[Unreleased]`, the parent
plan's `Status:` line, the design's `Status:` header — Milestone 6 is **in
progress** with Slice ⓪ closed — plus the source comments this slice retired
(Tasks 2 and 4 already corrected them; confirm none still names "Milestone 6's
close-out" as a receiver):

```bash
rg -n -i "milestone 6's close-out" src/
```
Expected: **exactly one** hit — `pass-reachability`'s note, which Slice ② owns —
and no other.

---

## Verification

`release` green in both lanes, the mutation suite at its re-measured totals, and
six things checkable rather than asserted:

1. **The census does not move**: `diagnostic-census` green with
   `(invalid-name 6)` and `(invalid-field-declaration 2)` — the fold added no
   site.
2. **Nineteen carriers, each asserted both ways**: the seventeen-row group's
   sentinel reads 17 and the two M5 family cases still pass; every integer label
   is reported under the carrier's expected name.
3. **The totality row is derived**: `node-source-label`'s predicates equal
   `node?`'s disjuncts, read from `ir.sls` as a datum — the row Slice ① will turn
   red and green.
4. **One grammar**: `rg -n 'lower-alpha\?|name-char\?' src/byte-machine/` returns
   hits in `names.sls` **only**.
5. **`make-callback-failure` refuses `'BadCode`** in both runtime lanes, and
   `reserved-drift` is green.
6. **Every FIND resolves to one site**, and the suite's failure-signature filter
   returns only the `tests passed` line.

## Exit

Two obligations that named this milestone's close-out are closed, not deferred;
Slice ① starts against a total label check and a single grammar, and the design's
appendix tells it the one new row it owes.
