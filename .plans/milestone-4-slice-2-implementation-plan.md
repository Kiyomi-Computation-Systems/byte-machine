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

- [x] **Task 2 — `eof-terminal`, the multi-successor rewrite (D1).** *(was Task 1)* Now that
  `field-branch` exists, the rewrite's own properties are witnessable — six new cases, none of
  which could have been written a commit earlier.

  Two structures, each doing one job: `path` is the DFS stack (a cycle is a property of the
  path), `done` is the global completed-set. `'unknown` is **deleted** — every constructible
  kind has an arm and the residual `else` raises. Behaviour-preserving for every shipped kind:
  all 92 lanes passed before a single test was added.

  **A mirrored-arm case was added to make two mutants separable.** A mutant that walks only the
  true arm answers one arm order correctly and the other wrongly, so the pair separates "the
  join uses the wrong order" from "the second arm is never walked"; with one order only, the
  rank mutation's records were a strict subset.

  **The completed-set is an `EXPECT_SURVIVES`, measured.** Its job is complexity, not
  correctness: the path stack alone answers every verdict correctly, because the only
  path-dependent answer is `cycle` and a re-visit re-derives the same verdict. A timing witness
  — a ~25-diamond chain making the mutant take 2^25 walks — was **considered and declined**,
  because a catch that depends on host speed is not a catch this suite can state. Survivors go
  to **11**; Task 7 takes them back to 10 by closing ①b's.

  Three shipped pins re-anchored in the same commit: `seen` became the path stack, the pause
  arm moved into `eof-successors`, and arm 5's anchor ended on the `(else 'unknown)` that 0021
  item 3 deletes — the replacement keeps that mutation *comparison*-caught rather than letting
  it die by the new raising `else`.

  `release` 92/92, 49 passes / 287 mutations, no golden moved. One DFS, path stack plus global
  completed-set, `'unknown` deleted with an arm per constructible kind. Pin
  `cycle > eof-reachable-stop`. Re-measure the four `eof-terminal` pins and both callers.
  **Gate:** a diamond that re-converges is not `'cycle`; a genuine cycle still is; no
  `'unknown` remains anywhere in the file.

- [x] **Task 3 — The verifier census, walk and REPORT guard together (H12, D5).**
  Four sites: `node-out-targets`, `reexec-targets`, `pass-zero-progress`'s REPORT guard (with
  its now-false message text), and a new byte-reachability-gated `:908` block. **Row 14 is
  dropped**, and a case holds the drop: a byte path through a zero-width node into a *stop*
  must verify clean, so if a later slice writes the prescribed sibling block that case fails.

  **Two fixtures existed only to make mutants separable, and both were written because the
  first measurement showed they were not.** The walk and the REPORT guard emitted *identical*
  records — the M3 half-fix shape exactly — until a cycle running **through** a zero-width node
  was added, whose reported member is the dispatch and so survives the report narrowing.
  And removing the `:908` byte-reachability gate **survived** until an EOF-only-reachable
  zero-width node was written; every zero-width node in the first five cases is byte-reachable,
  so nothing could see it.

  **`zero-width-successors` was extracted, not triplicated.** Three consumers wanted the same
  fact and the arms were textually identical, so every pin on them resolved to three sites — the
  SITES-fails-both-directions trap, hit twice in this task. Factoring does not collapse three
  decisions: each caller's arm stays its own mutable line.

  Five mutations; **five shipped pins re-anchored**, three of them the same report guard for the
  third time. `release` 92/92, 49 passes / 292 mutations, no golden moved. Every site
  from the corrected census. `pass-overlap` and `pass-sequence-ambiguity` stay unextended,
  permanently. **Row 14 is dropped** with its gap recorded and witnessed. Fixture proving
  `dispatch --advance--> field-action --next--> stop` verifies clean.

- [x] **Task 4 — `pass-fields`' operand half (D4).**
  Arity, the declared-field reference, `constant`/`mask` within the **referenced** field's
  width, and `low <= high` — all of it relational, which is precisely why none of it is a
  constructor contract. One code, `invalid-field-operand`, spending §4.6's remaining budget;
  ③'s accumulate share reuses it with no new code. Inside `pass-fields`, per D4.

  Eight mutations, ten cases. Two boundaries are pinned rather than assumed: **255 is legal for
  a u8 and 256 is the first value that is not**, and the range test is `low > high`, not
  `low >= high`. The width fixture declares **two** fields of different widths, so a check that
  used the first declaration — or any fixed width — passes every other case and fails that one.

  **Pass 33 whole-pass sweep, both directions: 70 pins, 4830 ordered pairs, 25 collisions,
  every one a by-construction nesting and none unclassified.** The nestings run in chains —
  `pass-fields never run` ⊃ `the operand half never run` ⊃ each individual check — and three
  pins were tightened to conjunctions after the first sweep showed they owned no record:
  extracting `zero-width-successors` in Task 3 made one arm feed three consumers, so each of
  its records is shared with a mutant of one consumer and only the *pair* is its own.

  *Two tooling findings. `EXPECT_OUTPUT_MATCHES` followed by a comment line before its string
  is valid CMake but invisible to a by-block parser, so three pins silently went unjudged by
  the sweep while the suite stayed green — comments now sit above the keyword. And the arity
  mutation's own signature is a `caddr` raise, which is the decision's stated reason made
  visible: 0020 item 2 puts arity in the verifier because nothing can be read out of
  `arguments` before arity is known, and unguarded, the range check reads a third element that
  is not there.*

  `release` 92/92, 49 passes / 300 mutations, no golden moved. Arity against the operation or predicate,
  `field` naming a declared field, `constant` and `mask` within the referenced field's declared
  width, `low <= high` for `range`. One new code, `invalid-field-operand`. Whole-pass sweep of
  Pass 33 in both directions afterwards, against a control on the branch point.

- [x] **Task 5 — The normalizer: widen the vector, lower both kinds, encode tags 5 and 6 (D3,
  H4).**
  **D3's cost argument is confirmed, not assumed: widening moved no existing fingerprint.** All
  92 lanes passed before a single new test was added, because the three new slots are `#f` for
  every shipped kind and none of them is written. ③ inherits the room.

  Six mutations, each on its **own measured golden**, which is this file's shipped discipline
  for a new encode arm — an inequality pair cannot see a dropped count or a transposed pair.
  Two encoding decisions are worth naming: each operand carries a **kind tag**, so a field
  literally named `7` cannot share bytes with the constant 7; and the error target carries a
  **presence tag** rather than a sentinel id, so "no error target" and "targets state 0" cannot
  collide.

  normal-ir whole-pass sweep: **36 pins, 1260 ordered pairs, zero collisions.**

  *Two repeats of traps already met this slice. The two encode arms open with the same two
  lines, so the selector FIND resolved to two sites — the third SITES-both-directions hit.
  And a bare-inequality pin collided with every mutation that makes **all** fingerprints equal
  ("the FNV prime is changed", "the byte is never mixed"); only an exact value is safe.*

  `release` 92/92, 49 passes / 306 mutations, no golden moved. Six state literals move in this commit. Two new fingerprint goldens, one per kind,
  each measured — the file's own discipline is that a new encode arm owes its own exact-value
  golden. Tag-collision mutation mirroring the shipped one.

- [x] **Tasks 6 and 7, in ONE commit — the op contract, the interpreter's arithmetic, the
  runtime's zero-width arms, the first field WRITE, and ①b's two debts (D2, H6, H7, H8).**
  Merged for the same reason ①b merged its 6 and 7: the op protocol has no observable until
  the runtime drives it, so a task-6-only test could not fail.

  `(op 'field-step node field-vector)` — **the op does the bound check and the commit; the
  runtime only routes the target it answers.** D2's shape, and the one ③ reuses.

  **Both of ①b's deferred obligations are discharged here, on ①b's own stated condition.**
  The `parser-reset!` `EXPECT_SURVIVES` is deleted and re-declared as a pin, and the isolation
  case ①b declined is written — a parse now changes a field, so both can fail. **Survivors back
  to 10.**

  **H7 answered and pinned: `pk` is carried through a zero-width hop, not reset.** A zero-width
  step does not move the parser in the input, so a failure one hop later reports the kind it
  would have reported without it; on an EOF chain that is `eof`, and resetting to `boundary`
  would claim the parser is between bytes when there are none. §12.7:777 makes this
  differential-compared, so it needed a ruling and a fixture, and the design poses neither.

  *Two mutants survived their first fixture and drove new ones.* An overflow that **clamps to
  the maximum** was invisible because the only overflow in the fixture started **at** the
  ceiling, where "unchanged" and "clamped" coincide — an `add` overflowing from below it
  separates them. And the finish-side `pk` had no witness until an EOF chain ran through a
  field action that then failed. *The verifier also rejected my first EOF fixture as a cycle,
  which is Tasks 2 and 3 doing their job.*

  `release` 92/92, 49 passes / 311 mutations, **ten** `EXPECT_SURVIVES`, no golden moved. The message
  shape ③ will reuse: `(op '<kind> node <field-vector> …)`, op does check-and-commit. New
  `kind` answers. Enumerate every hand-written op-closure stub in the tree first — ①b's
  `'field-initials` broke all six in `runtime-tests.sps`, and the protocol has no default arm.

- [x] **Task 8 — The emitter (H1, H2, H3, H5, D6).**
  `render-state-arm` could not see the declarations at all (H3), so the normalized field table
  is threaded in. Both arms emit `fieldv`, and `v`/`r` join `reserved-member-3` — which
  re-anchored its pin (H2).

  **H1 was the blocker: both v2 `exec` call sites still passed the shared `empty-fields`
  sentinel.** ①a reserved that parameter and ①a and ①b both passed the sentinel, correctly,
  while nothing read it. The moment the emitter writes through it, every generated field
  machine indexes out of bounds — measured, before the line changed.

  **H5 confirmed and closed: the member-3 drift guard rendered the pause machine, which
  declares no fields**, so `v` and `r` would have been reservations nothing exercises. Its
  fixture now carries a *fallible* action (binding both locals) and a branch.

  **A safe operation emits no bound check.** The constructor proved it cannot fail, so a check
  would be a branch no input can take and a mutation of it would survive.

  Six mutations. **One is measured and deliberately not written:** swapping the branch arms
  produces a record set *identical* to inverting the predicate — on a two-armed branch those
  are the same function, so no fixture separates them by behaviour.

  *Two fixtures were extended after mutants survived them: the writer machine had no field
  **branch** at all, so both branch-arm mutations survived the whole lane; and its only
  overflow started at the ceiling. My own `:908` check then rejected the first drift fixture
  for byte-reaching a finish — Task 3 working on a machine I wrote by hand.*

  `release` 92/92, 49 passes / 317 mutations, no golden moved. `render-state-arm`'s fan-out; the width-bound
  argument threaded in one edit; `fieldv` wired from the reserved seventh parameter — and
  **verify that the reservation actually covers ②'s emission**, since the frozen-goldens
  constraint rests on it. `reserved-member-3` and its drift guard's fixture.

- [x] **Task 9 — The operation and predicate matrix (§25:1568, §25:1569).**
  Four widths × four schedules, driven through **both** executors, with sentinels over the
  widths *and* over the schedules within each. One machine per width — a field at its maximum
  and a field at zero, the byte choosing the operation — which keeps the emitted-and-loaded
  library count at four.

  **The lower bound is what the matrix exists for.** Every earlier fixture in this slice
  overflows *upward*, so a check testing only the upper bound passed all of them; `decrement`
  from 0 is the only place the lower half is load-bearing, and it is mutated in both lanes.
  The success control matters equally: without it every overflow row passes on a machine that
  simply never writes.

  The u64 row's maximum is asserted to exceed `(greatest-fixnum)`, so a host with a wider
  fixnum fails loudly rather than quietly ceasing to test §15:856.

  Three mutations. `release` 92/92, 49 passes / 320 mutations, no golden moved. Underflow at
  `decrement` from 0; overflow at `increment` and `add` from each width's maximum; all four
  widths; failed operations leave prior values unchanged. A loop with a sentinel reading the
  **observed** count, per the rule ①b's field lane already follows.

- [x] **Task 10 — Sweeps, status surfaces, CHANGELOG (H9, H10, H11, H14, H15).**

  **The `differential.field` whole-pass sweep found a real weakness and it is recorded rather
  than closed.** 20 pins, 380 ordered pairs, 14 collisions — eight by-construction nestings and
  **six that nest in neither direction**. The cause is structural: this is a differential lane
  and most of its checks compare the two executors *to each other*, which is symmetric, so
  breaking either implementation of the same decision produces the same disagreement. The
  attempt is measured — labelling every check with the **whole schedule** rather than its first
  byte took collisions 18 → 14 and gave two pins a lane-unique record; an exhaustive search for
  a unique ordered *pair* then found none for the remaining six. Every one is still **caught**,
  each by a record its own decision produces; what they lack is unique *attribution*. Closing
  it needs per-lane assertions against expected values wherever the lane currently asserts only
  that the lanes agree — a fixture redesign, recorded as owed.

  **H11 confirmed the hard way.** The `FORTY-EIGHT PASSES` banner was still stale: Slice ①b's
  Important fix wave *recorded it as corrected* and the edit never applied, because it sat in a
  batch that aborted on an earlier assertion — and nothing failed, because the banner is the one
  surface no test can check. The false claim rode a merged commit message for a slice and a
  half. Found by running the check the commit claimed to have run.

  Exit evidence, each measured: `release` **92/92**, `pr` 92/92, `no-scheme` **8/8**; scheme
  mutation **49 passes / 320 mutations**; CMake **1 pass / 72**; **ten** `EXPECT_SURVIVES`;
  `reserved-member-2` **32, unchanged by ②**; goldens and every pinned IR fingerprint
  **byte-identical to `51fd5f3`** — `git diff 51fd5f3..HEAD -- test/fixtures/` empty and no
  19-digit literal removed from either pinning file. New
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

### Whole-branch review — one Critical, found and fixed 2026-09-03

**The multi-agent review could not run: all eight dimension agents died on API 529/500, twice,
with `subagent_tokens: 0`** — rejected at launch. The empty `confirmed: []` it returned is *not*
"no findings"; the journal held zero result lines. Reported as a non-run rather than a clean
bill, and the highest-value dimension was then run by hand.

**CRITICAL — six of the fourteen operations and predicates appeared in NO fixture at all**, so
their two independent implementations were never compared: `clear-mask`, `equal`, `nonzero`,
`mask-any`, `mask-all`, `mask-none`. The design says writing them twice is *"the single class of
defect this milestone introduces"* and that the interpreter≡generated differential is what
catches it — but a differential only compares what a fixture **exercises**.

Measured, not inferred: **inverting the emitter's `mask-none` alone left all 92 lanes at status
0.** Two independent implementations, silently disagreeing.

Closed by a coverage group driving all fourteen through both lanes, one byte each, asserting
**expected values** rather than only cross-lane agreement — two lanes wrong the same way would
agree, and this project has recorded that shape of agreement as disarming its own test.

**Two operands had to be chosen to separate a predicate from its siblings, not merely to
exercise it.** With `mask-all 12` on `f=12`, an implementation computing `mask-any` answers
correctly and the mutation **survived**; the operand is 14, where 12 has some mask bits but not
all. Same for `equal 12` versus `nonzero` — now `equal 99`. All six previously-unexercised
members are now caught in both lanes, verified one mutation at a time.

Two mutations pin the group; the other twelve possible ones are not written because their
records differ only in which row of the same loop reddens, so they would all resolve to the
same two (case, check) pairs.

`release` 92/92, 49 passes / 322 mutations, no golden moved.

---

### Whole-branch review, second finding — the widening was incomplete

**The multi-agent review failed three times**, all agents rejected at launch on API 529/500
with `subagent_tokens: 0`; chunking to three concurrent agents did not help. Seven dimensions
were then run by hand. `seams` found this.

**IMPORTANT — `seq-state` was never widened.** Task 5 took the normalized state vector from
eight slots to eleven and missed the literal that builds **every sequence-dispatch node's
state**. Measured: four of the six states in the sequence-node fixture were three slots short
of the layout this file declares.

**Why it was invisible.** Sequence states carry kind `dispatch`, and the only readers of slots
8–10 are kind-guarded, so nothing ever reached one — all 92 lanes stayed green through Task 5's
six mutations *and* its 36-pin whole-pass sweep. What it left behind is a state shorter than the
declared layout, so any totalising read over states raises on exactly these, and ③'s accumulate
is the next thing likely to add one.

**Two counts in Task 5's record were wrong.** There are **eight** `(vector ns-tag …)` literals
in the normalizer, not the six the plan and commit both state — and the eighth is the one that
was missed. The claim "six state literals move in this commit" was true of the six it edited
and false as a census.

The witness is deliberately **total over the state kinds a fixture can produce**: a case naming
one kind would have passed throughout, which is exactly how the miss survived. Pinned.

`release` 92/92, 49 passes / 323 mutations, no golden moved — the three slots are `#f` and are
not encoded.

---

## Self-Review (run after all ten tasks)

Whole-branch review before the closing ritual, on the pattern ①a and ①b used: dimensions in
parallel, each finding adversarially verified before it is believed. ①b's review found three
Criticals, **two of which were that branch's own earlier work in the same session** — every
task passing tells you nothing about the seams.

Carry ①b's two hardest-won checks into it explicitly: **a measurement written into prose goes
stale when its fixture changes**, and **a correction is a record too**.
