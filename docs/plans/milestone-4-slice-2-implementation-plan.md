# Milestone 4 Slice ② — Field action and field branch: implementation plan

**Baseline: `ce6180317325a7188d0fd10f7fe964fd7dcd0cbf`** (Slice ①b merged, PR #43).
Design: `milestone-4-design.md` §7, **as corrected in place 2026-09-03** — see its Amendments
block. Decisions: 0016, 0019, 0020, 0021, 0022. Parent spec: `byte-machine-implementation-plan.md`.

Discharges §25:1560 (`store/clear/inc/dec/add`), §25:1562 (`flag set/clear`, settled as
`set-mask`/`clear-mask`), §25:1563 (`equality, zero, range, and mask branches`), the **operand**
share of §25:1564, the **operation** share of §25:1568, §25:1569 whole, and extends §22.4:1267's
`final state and fields` comparison over the two zero-width kinds — the first cross-lane
comparison of fields a machine actually **writes**.

---

## Global Constraints

- **Diff fixtures against `51fd5f3`, never against ①a's merge and never against `main`.**
  Decision 0019 point 5 was amended by Slice ①b: `51fd5f3` moved `generated-pause.golden.sls`
  when it resolved 0022 item 7. An ①a-anchored diff reports a false positive; `main`-anchored
  reports ①a's format bump.
- **The three committed goldens and every pinned IR fingerprint stay frozen.** ②'s new kinds
  appear only in ②'s own fixtures. §7's premise for this is decision 0019 item 3(c)'s reserved
  seventh `exec` parameter, which is real and already shipped — **verify that claim in Task 8
  rather than assuming it**, since it is the whole reason ② is not a second re-baseline.
- **Every `file:line` in design §7 and §8 was measured at `a942327` and is presumed stale.**
  §7 says so itself. Cite constructs by name; where this plan gives a line it is measured at
  `ce61803` and is re-checkable.
- **Correct a stale instruction in place; annotate a stale record.** Six of §7's live work
  orders were false, not merely stale, and are already corrected in the design.

---

## §0 Design calls locked by this plan

**D1 — `eof-terminal` is one DFS with two structures, and `'unknown` is deleted.**
§4.4 and decision 0021 items 2-3 govern; §7 Task 1's per-path `seen` and seven-value
`'unknown`-least order are **superseded and struck**. A path stack detects cycles; a **global
completed-set** memoizes verdicts so a diamond is not re-explored. Every
`ir.sls`-constructible §10.6 kind gets its own arm, so the `(else 'unknown)` residual goes
away entirely. 0021 item 1 pins only `cycle > eof-reachable-stop`; the rest of the order is
this slice's call, and `'unknown` may not appear in it.

**D2 — There is ONE field store, parser slot 8, and the interpreter reaches it through a
message that receives it.** "The interpreter gains its own field storage" is unbuildable: the
`op` closure is built once per compiled machine and has no parser in scope, which
`runtime.sls` records verbatim because ①b hit it. `parser-feed-op!` and `parser-finish-op!`
both have `parser` in scope and pass `(parser-field-values parser)` into the op. **The op does
the bound check and the commit; the runtime only routes the returned target.** If the op
returned a value for the runtime to store, ③'s accumulate would force the runtime to decide
overflow-versus-digit, putting §15:858-870's inequality where the generated library can reach
it. The no-shared-helper rule holds over **three** channels: `(byte-machine runtime)`,
`(byte-machine private ir)`'s `only` list in `compile.sls`, and any new export. Both lanes
reach the declared width independently — interpreter via `(machine-fields m)` →
`uint-field-width`, emitter via `(normal-machine-fields normal)`.

**D3 — ② widens the normalized state vector.** It is **eight** slots (①a appended `reason`),
leaving five free. ②'s two kinds need exactly five each — zero spare — and ③'s accumulate
needs eight. Whoever widens pays the same six-literal edit once, and ② is already editing
those six literals. §7's "carry it in the existing seven-slot vector rather than widening it"
was decided against a count that is wrong. **③ inherits the room and must not invent a
packing.** Slot 6's shipped `(node . id)` / `(default . code)` convention is reused verbatim
by ③'s EOF routing — say so here so ③ does not build a parallel encoding.

**D4 — The operand half goes INSIDE `pass-fields`; no new pass.** ①b built `pass-fields` for
exactly this and records it in the tree. A sibling pass would duplicate an
indentation-anchored line that `verify: pass-fields is never run` pins at SITES=1 — the
SITES-fails-both-directions trap. Second code: `invalid-field-operand`, which spends §4.6's
remaining budget entirely. ③'s accumulate share reuses it with **no new code**.

**D5 — Census row 14 is NOT extended "same shape".** A byte-reachability-gated sibling block
turns `dispatch --advance--> field-action --next--> stop` into a false `eof-reachable-stop`.
A pause is an EOF *start* because `parser-feed-op!`'s pause arm commits `current` past it; a
zero-width node never becomes `current`, since the dispatch arm returns `need-input` without
moving it. Row 10's `eof-terminal` extension plus the shipped pause block cover every real EOF
start. **Take the drop-it option** and record "entry is a zero-width node" as a stated,
witnessed gap; the alternative — gating on `(eq? (node-name n) (machine-entry m))` — is
admissible but buys nothing ③ needs. Either way, a fixture must prove
`dispatch --advance--> field-action --next--> stop` still verifies clean.

**D6 — The emitted field parameter is `fieldv`.** Not `fs`; `fs` is already bound in
`compile.sls` as something else, and every §7/§8 code sample using it would emit an unbound
identifier.

---

## §0b Hazards measured at `ce61803` that no design sentence names correctly

Forty-four distinct findings survived adversarial re-measurement. Those above are locked as
§0 rulings; these are the rest, in the order a task list meets them.

**H1 — Two mutation pins outside `verify.sls` die in tasks 6-7, and §7's pin inventory is
verify-only.** §7 budgets a re-anchor sweep for `verify.sls` alone. Both v2 `exec` call sites
still pass the shared module-level `empty-fields`, and one is a SITES=1 pin; `loop-tail`'s two
rendered strings are each pinned at SITES=1 across three mutations. Enumerate the whole pin
set by FILE before Task 6, not by SPEC.

**H2 — `reserved-member-3` moved and grew to fifteen symbols**, and its pin needs both a
re-anchored FIND and a **re-measured** failure signature. Adding `fieldv` to the literal makes
the shipped FIND stop matching — a hard SITES failure at configure time, not a test failure.

**H3 — `render-state-arm` cannot see the field declarations.** The emitter cannot fold a width
bound without a new argument. Decide the argument's shape in Task 8 and thread it in one edit,
because every arm signature moves with it.

**H4 — `compile.sls` holds TWO normal-state-kind dispatch sites, not one.** The appendix census
undercounts. Any step describing "the emitter's single `case`" is an incomplete checklist.
Also: **forbid using state slot 7 for an operand payload**, so `compile.sls`'s reader keeps
seeing `#f`.

**H5 — `member3-drift-tests.sps` renders only the pause machine**, which declares no fields, and
asserts a three-name literal list. ②'s new emitted locals are unwitnessed by it as it stands.
② must choose the fixture shape ③ then extends — a field-declaring machine, or the drift guard
stops guarding the thing it was added for.

**H6 — Both op loops gained a second loop variable.** The design's `(loop pos)` zero-width-arm
shape is wrong; every arm passes two arguments.

**H7 — Position kind on an EOF chain is an open question the design never poses.** Inside
`parser-finish-op!` a field-action node reached along an EOF chain arrives with `pk` already
`'eof`, so a failed operation there is not obviously the `boundary` §12.7:770 prescribes.
**State explicitly whether the zero-width arm carries `pk` through or resets it**, and pin the
choice on both executors — §12.7:777 makes position kind differential-compared, so the lanes
disagreeing is a lane failure.

**H8 — ①b left ② two obligations recorded in the tree that the design does not carry**, and
§7 weakens one into an escape hatch it does not have. Both land in the commit that adds the
first field WRITE: (1) delete `parser-reset!`'s `EXPECT_SURVIVES`, re-declare it
`EXPECT_STATUS 1` with a signature re-measured from a staged mutant, and drop the survivor
total back to **9**; (2) add the per-parser isolation case to `field-access-tests.sps` and
delete the decline comment. The survivor's own text names the ordering trap: a ② that adds a
writer without the restore leaks one parse's values into the next — the restore already
exists, so this is a defect ② would have to *introduce*, and the isolation case is what proves
it did not. **Run `rg -n 'Slice ②' src/ test/` before writing the task list** and fold every
site in; the design predates both ①a and ①b and cannot enumerate what they deferred.

**H9 — The fingerprint gate is under-specified.** `normal-ir-tests.sps` pins **five** sites,
not three, and one is a two-field machine — the value ②'s field-writing machines are closest
to disturbing. Write the gate as a value-level diff, not a count:
`git diff 51fd5f3..HEAD -- test/common/normal-ir-tests.sps test/common/compile-tests.sps | grep -E '^[+-].*[0-9]{19}'`
empty, plus `git diff --stat 51fd5f3..HEAD -- test/fixtures/` empty.

**H10 — Every suite total in §7 and §8 is the `a942327` column.** Baseline is **49 passes /
275 mutations**, **54** `verify.sls` pins, **9** `EXPECT_SURVIVES` after H8 closes the tenth,
CMake 1/72, `release` 92/92. The design's counting *mechanism* is sound and reusable; only the
numbers moved.

**H11 — The suite's own banner is already one behind.** It names itself "the one surface no
test can check" and ①b left it stale at the next bump. ② fixes it or compounds exactly the
drift the banner exists to prevent.

**H12 — `pass-zero-progress`'s diagnostic message becomes false when its REPORT guard is
extended, and no pin holds it.** Extending the walk without the report set is the half-fix M3
Slice ② shipped and ③ closed; the measured symptom is recorded beside the code. Extend both in
one commit, and fix the message text in the same edit.

**H13 — Arm placement decides whether three pins die.** The design budgets a re-anchor sweep
that is partly avoidable: placing new arms *after* the pinned ones leaves their FINDs intact.
Measure before choosing placement.

**H14 — Three lane names already contain `field`**, and the lane census is 94, not 86. ①b
shipped `byte-machine.differential.field.chez.{source,aot}`, so §7's collision-freeness
measurement is stale — all five proposed names are still free, but re-measure rather than
quote.

**H15 — Both §12.7 position rows already exist and are differential-pinned.** ② and ③ each add
a **row to one shipped table-driven test**, not a new mechanism. §7 task 9's "zero occurrences
of position-kind or parser-error" measurement is void.

**H16 — Every `AGENTS.md:<line>` citation in §7 and §8 is stale by a mechanical offset**, and
each lands on a *plausible neighbouring rule* — including the sentinel rule ②'s matrix depends
on. Re-resolve every one by content before relying on it.

---

## Task list

Each task is one commit: failing tests first, then the implementation, then mutations measured
in both directions, then the gate. Tasks 1-3 are strictly ordered; 4-9 depend on 1-3.

> ***TASKS 1 AND 2 ARE SWAPPED, 2026-09-03, on measurement.*** The plan ordered the
> `eof-terminal` rewrite first "so its own tests are written against shipped kinds". That
> reasoning is wrong: **every shipped kind is single-successor**, so no shipped kind can
> witness a multi-successor join, a diamond that re-converges, or the completed-set's reuse.
> Written first, the rewrite would ship with tests that cannot fail — the exact shape this
> project has twice recorded as a defect. The two zero-width kinds land first; `field-branch`
> is what makes a diamond constructible, and the rewrite follows with real witnesses.

- [x] **Task 1 — The two zero-width kinds: descriptor, façade, and the machine guard.**
  *(was Task 2)* `ir.sls` constructors, predicates and accessors; `graph.sls`'s export list and
  its mirrored `only` import, both in one commit. Decision 0020 fixes the boundary and item 2
  fixes the whole of it in one line: **`arguments` is a proper list and no further.** Arity,
  declared-field references, operand range and `low <= high` are pass 6a's — Task 4's, not
  this one's — and 0020 flags `low <= high` as the consequence that will look wrong to a reader
  of 0017. The error slot's rule (`#f` exactly when the operation cannot fail) IS the
  constructor's, because nothing downstream fails loudly on a target the operation can never
  reach: `node-out-targets` feeds it into the reachability walk unconditionally.

  Seven mutations. `graph.sls`'s two lists get none, following ①b's precedent — measured
  anyway, so the precedent is followed knowingly: either list losing the names is an
  **expand-time** failure at exit 255, louder than a pin, and pinning it would cost a whole
  pass for two decisions already fatal. `release` 92/92, 49 passes / 282 mutations, no golden
  moved.

  *Trap worth carrying: `?` is a regex metacharacter, so a pin naming `node?` matched `nod `
  and the runner reported a wrong-reason catch.*

- [ ] **Task 2 — `eof-terminal`, the multi-successor rewrite (D1).** *(was Task 1)* Now that
  `field-branch` exists, the rewrite's own properties are witnessable. One DFS, path stack plus global
  completed-set, `'unknown` deleted with an arm per constructible kind. Pin
  `cycle > eof-reachable-stop`. Re-measure the four `eof-terminal` pins and both callers.
  **Gate:** a diamond that re-converges is not `'cycle`; a genuine cycle still is; no
  `'unknown` remains anywhere in the file.

- [ ] **Task 3 — The verifier census, walk and REPORT guard together (H12, D5).** Every site
  from the corrected census. `pass-overlap` and `pass-sequence-ambiguity` stay unextended,
  permanently. **Row 14 is dropped** with its gap recorded and witnessed. Fixture proving
  `dispatch --advance--> field-action --next--> stop` verifies clean.

- [ ] **Task 4 — `pass-fields`' operand half (D4).** Arity against the operation or predicate,
  `field` naming a declared field, `constant` and `mask` within the referenced field's declared
  width, `low <= high` for `range`. One new code, `invalid-field-operand`. Whole-pass sweep of
  Pass 33 in both directions afterwards, against a control on the branch point.

- [ ] **Task 5 — The normalizer: widen the vector, lower both kinds, encode tags 5 and 6 (D3,
  H4).** Six state literals move in this commit. Two new fingerprint goldens, one per kind,
  each measured — the file's own discipline is that a new encode arm owes its own exact-value
  golden. Tag-collision mutation mirroring the shipped one.

- [ ] **Task 6 — The op-message contract and the interpreter's arms (D2, H1).** The message
  shape ③ will reuse: `(op '<kind> node <field-vector> …)`, op does check-and-commit. New
  `kind` answers. Enumerate every hand-written op-closure stub in the tree first — ①b's
  `'field-initials` broke all six in `runtime-tests.sps`, and the protocol has no default arm.

- [ ] **Task 7 — The runtime: zero-width arms, the first field WRITE, and ①b's two debts
  (H6, H7, H8).** Both op loops, two arguments per arm. **Closes the tenth `EXPECT_SURVIVES`
  and adds the isolation case in this commit.** Decide and pin the `pk` question.

- [ ] **Task 8 — The emitter (H2, H3, H5, D6).** `render-state-arm`'s fan-out; the width-bound
  argument threaded in one edit; `fieldv` wired from the reserved seventh parameter — and
  **verify that the reservation actually covers ②'s emission**, since the frozen-goldens
  constraint rests on it. `reserved-member-3` and its drift guard's fixture.

- [ ] **Task 9 — The operation and predicate matrix (§25:1568, §25:1569).** Underflow at
  `decrement` from 0; overflow at `increment` and `add` from each width's maximum; all four
  widths; failed operations leave prior values unchanged. A loop with a sentinel reading the
  **observed** count, per the rule ①b's field lane already follows.

- [ ] **Task 10 — Lanes, sweeps, status surfaces, CHANGELOG (H9, H10, H11, H14, H15).** New
  lane pairs with re-measured names; whole-pass sweeps for every pass that gained a check;
  the banner; the count narrative; the fingerprint/golden gate as a value-level diff.

---

## §③ — What Slice ② must decide for Slice ③ (shared decisions only)

Slice ③'s task list is deliberately **not** written here: it would be written against a tree
that does not exist, and this project has already shipped one unwitnessed function from a
stale brief. What ③ needs settled *now*, because ② will otherwise foreclose it:

1. **The op-message contract (D2)** is the one ③ reuses for accumulate. If ② gets it wrong,
   ③'s overflow decision migrates into `runtime.sls`.
2. **The widened state vector (D3)**, and slot 6's `(node . id)` / `(default . code)`
   convention reused verbatim for ③'s EOF routing.
3. **`pass-fields` as the single home (D4)** — ③'s accumulate share reuses
   `invalid-field-operand` with no new code, and needs one candidate home, not two.
4. **The census sites ② edits that ③ would otherwise edit again.** Four `verify.sls` sites are
   touched by both slices, and the two `:908`/`:909` filters split the other way; ② should
   teach them with ③'s input-reading kind in mind.
5. **The position rows (H15).** ② owns `boundary`, ③ owns `byte`; both are rows in one shipped
   table-driven test.
6. **`reserved-member-3` growth discipline and the drift guard's fixture (H5)** — whatever ②
   chooses, ③ extends.
7. **`loop-tail`'s two rendered strings are pinned at SITES=1 across three mutations.** ③
   re-inlining the overflow tail is a hard configure-time failure; ② should leave the seam
   where ③ can use it.

---

## Self-Review (run after all ten tasks)

Whole-branch review before the closing ritual, on the pattern ①a and ①b used: dimensions in
parallel, each finding adversarially verified before it is believed. ①b's review found three
Criticals, **two of which were that branch's own earlier work in the same session** — every
task passing tells you nothing about the seams.

Carry ①b's two hardest-won checks into it explicitly: **a measurement written into prose goes
stale when its fixture changes**, and **a correction is a record too**.
