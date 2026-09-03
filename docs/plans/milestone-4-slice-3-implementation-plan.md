# Milestone 4 Slice ③ — Integer accumulate: implementation plan

**Baseline: `14c4f300d13d2af4cc0a0d54140afd83c9e7a26f`** (Slice ② merged, PR #46).
Design: `milestone-4-design.md` §8, **as corrected in place 2026-09-03** — see its Amendments
block. Decisions: 0015, 0016, 0017, 0019, 0020, 0021, 0022. Parent spec:
`byte-machine-implementation-plan.md`.

The last slice of Milestone 4. Discharges §25:1561, §25:1564's accumulate share **by reuse with
no new diagnostic code**, the accumulate shares of §25:1568 and :1569, and extends §22.4:1267's
comparison over the input-reading kind.

---

## Global Constraints

- **Diff fixtures against `51fd5f3`** (decision 0019 point 5 as amended by ①b), *not* against
  ①a's merge and not against `main`.
- **③ adds a fourth golden** (§0 D4), so the fixtures gate is *"the three existing goldens
  byte-identical, new files added"* — never "the diff is empty". Verify by value, not by
  `git status`.
- **Every `file:line` in design §8 is presumed stale.** §8 was written at `a942327`, before ①a,
  ①b and ② existed; Slice ② alone changed six of the seven files ③ touches. Recon measured
  63 hazards, nine blocking. Cite constructs by name.
- **Correct a stale instruction in place; annotate a stale record.** §8's `reexec-targets`
  instruction is already corrected in the design — read the marker before implementing.
- **③ is input-reading.** It joins the verifier census but must **not** join
  `zero-width-successors`: it consumes a byte and makes progress.

---

## §0 Design calls locked by this plan

**D1 — `reexec-targets`' accumulate arm takes TWO disjuncts.** The `nondigit-edge` target when
its mode is `reexecute`, **plus the `overflow-error` target unconditionally**; `digit-target`
stays out because it always advances (§10.6:566). §8 says only `nondigit-edge` can be
`reexecute` "since the overflow edge is terminal-directed" — **it is not**, and §8 contradicts
itself sixteen lines later. §12.7:772 makes the overflow non-consuming and §15:870 leaves the
field unchanged, so an `overflow-error` naming its own node re-reads the same byte forever, and
neither runtime loop guards against it. **Measured:** cutting ②'s field-action arm back to one
disjunct makes a self-targeting error edge verify with zero diagnostics. **The overflow
self-cycle owes its own fixture** — the nondigit self-cycle cannot distinguish the one-disjunct
mutant, and the adjacent REPORT-guard bullet inherits the same blind spot.

**D2 — The diagnostic carries the NODE's name, not the field's.** §8 prescribes the field name;
Slice ② shipped and documented the opposite, with the reason at its own site: *"an operand fault
is a property of the site that wrote it, and the field it names may not exist."* Following §8
would put two conventions under one diagnostic code.

**D3 — The accumulate field-reference check is a SIBLING ARM in `pass-fields`, not a
`field-operand-schemas` row.** That table is keyed on a selector and an arity; an accumulate node
has `field` and `base` and neither. ②'s promise of *one home* is kept — the arm lives in
`pass-fields` and reuses `invalid-field-operand` with no new code (§4.6's budget is spent).
The **base** half of §16.2:904 is genuinely constructor-only.

**D4 — ③ adds a determinism lane and a fourth golden.** §8 orders both that and an empty
fixtures diff; they are incompatible. The lane owes its own `BYTE_MACHINE_*_GOLDEN_FILE` in the
mutation suite's registration, or a pass's BASELINE reddens and reads as a mutation defect.

**D5 — The op-step contract is ②'s, reused.** `(op '<kind> node field-vector …)`: the op does
the bound check **and** the commit, the runtime only routes. If the op returned a value for the
runtime to store, ③'s accumulate would force the runtime to decide overflow-versus-digit, putting
§15:858-870's inequality where the generated library can reach it. **The return shape needs
deciding in Task 1 and stating once** — a `(target . mode)` pair changes every zero-width arm ②
shipped, so prefer a bare target and keep the mode implicit in the kind.

**D6 — The arithmetic is written twice, as in ②.** Interpreter from `machine-fields`, emitter
from `normal-machine-fields`. No shared helper, over all three channels: `(byte-machine
runtime)`, `(byte-machine private ir)`'s `only` list in `compile.sls`, and any new export.

---

## §0b Hazards measured at `14c4f30` that no design sentence names correctly

Sixty-three findings survived adversarial re-measurement; those above are locked as rulings.
The rest, in the order a task list meets them.

**H1 — SITES=1 collisions are the single largest mechanical risk, and §8 names none of them.**
At least **nine** shipped pins have FINDs that ③'s new arms would duplicate — in `runtime.sls`,
`compile.sls` (`loop-tail`'s two rendered strings and the emitted maximum
`(num (- (expt 2 width) 1))`), and `verify.sls`. Every one is a **configure-time FATAL_ERROR**,
not a test failure. Enumerate the whole pin set **by FILE** before writing any arm; this slice
has hit the trap four times already across ①b and ②.

**H2 — Encode tag 7 needs the `reason` slot as well as the four targets.** An accumulate node's
EOF route follows the dispatch precedent, so it can be `(default . code)` — and then `put-reason`
must have a reason to write. Slot 7 is in use; the four target slots are 3, 4, 5 and 6 with slot
6 keeping its shipped `(node . id)` / `(default . code)` convention.

**H3 — `graph.sls` exports CONSTRUCTORS only.** §8 tells ③ to export "the constructor, predicate
and accessors"; Slice ② exported the constructor alone, deliberately, matching the façade's rule
that accessors stay private. Follow ②, or change the rule knowingly.

**H4 — The property generator's accumulate draw is unreachable as §8 specifies it.** `byte-trial`
builds a fresh parser pair and feeds **exactly one byte**; `feed-loop!` re-feeds only on a
mutually agreed pause, and a dispatch returning `need-input` leaves the lifecycle `ready`. The
inbound edge must be pinned `reexecute` (state the zero-progress argument: the accumulate node
itself advances on the digit edge, so no cycle forms), or the draw exercises only the EOF path.
Two further traps: *"a declared u8 field so overflow is reachable inside 256 draws"* is
satisfiable at exactly one initial; **any new draw in `gen-machine` re-rolls the seeded sequence
and invalidates the two shipped goldens**; and the property lane's oracle compares no field value
today, so an accumulate draw would compare nothing.

**H5 — The base-16 digit arm cannot be one `case` group with one `d`.** §8's own example
contradicts its following sentence. Budget the arm shape as a decision, not a transcription.

**H6 — `render-machine`'s `reached` walk is a second normal-state-kind dispatch** that decides
the emitted `errs` table's contents. It is not in §8's census and it is where ①b's Critical lived.

**H7 — The census is FIFTEEN kind-dispatching sites, not twelve**, and §8's derivation site no
longer contains what it cites. The zero-progress REPORT guard already has **five** disjuncts and
gains a sixth; its pin has been re-anchored three times and will move again.

**H8 — The interpreter's `field-step` op arm is a two-way `if` with a permissive fallthrough.**
③ adds a third kind to it; an `if` that falls through routes the new kind to the branch handler
silently. Make it a `case` with a loud `else` in the same commit.

**H9 — Position kind: ③ inherits a task, not a precedent.** Slice ② never added the `boundary`
row its own comment claimed — corrected at that file on this branch. Budget a task: new fixture,
new row, **two sentinel bumps**, two CMake `SOURCES` edits. §12.7:777 makes it
differential-compared, so the row must be added for **both** lanes.

**H10 — The `differential.field` sweep debt names ③ by name.** Six pins nesting in neither
direction; closing it needs per-lane assertions against expected values. ③ adds arms to that
lane and will hit it.

**H11 — Every count in §8 is the `a942327` column.** Measured at `14c4f30`: suite **49 passes /
323 mutations** (declared at `:915-916`), **ten** `EXPECT_SURVIVES`, **94** lanes, **72**
`verify.sls` pins, **six** pinned IR fingerprints at eight assertion sites — not three, and at
none of the cited lines. Restate every one from measurement.

**H12 — `eof-terminal`'s residual `else` is now LOUD.** §8's "verifies clean and crashes later"
reasoning is stale: it raises out of verification. The failure mode ③ must design against
changed with Slice ②.

**H13 — Exit criteria: only three of §8's exist, only one has a disposition**, and ③ owes the
other two plus the full-milestone Exit section at `design:2251`.

**H14 — `member3-drift-tests.sps` already names ③** and specifies where the emitted locals must
appear; its fixture is ②'s field-declaring machine, which ③ extends rather than replaces. `d`
and `cur` joining `reserved-member-3` is **not enough** — the fixture carries an explicit list.

---

## Task list

Each task is one commit: failing tests first, the implementation, mutations measured in both
directions, then the gate.

- [x] **Task 1 — The accumulate node: constructor and façade (H3).**
  Seven parameters plus the label. **The boundary here is 0017's, not 0020's** — 0020 keeps the
  constructor out of `arguments` because that is a *list* whose length it may not assume, and
  this kind has no `arguments`: its operands are named parameters, exactly 0017 point 1's
  situation. So `base` ∈ {10,16} is closed here (§16.2:904's base half) and the **field
  reference** is the verifier's, asserted in both directions — a case proving an undeclared name
  still *builds*, and a restrictive mutation that closes it here.

  `overflow-error` is a **mandatory symbol**, unlike a field action's `error`: accumulation can
  always overflow, so there is nothing for the can-it-fail rule to decide. `nondigit-edge` is an
  **edge**, not a bare target, because §10.6:567's mode is the whole point.

  Seven mutations; `node?`'s pin re-anchored. **H3 followed:** the façade exports the
  constructor only, matching ②. *The 10-space export line is a substring of the 16-space import
  line, so both had to be anchored by neighbour — the fifth time this slice-family has hit a
  SITES trap.*

  **The op-step return shape is deferred to Task 4**, where the first consumer exists; deciding
  it here would be a decision with nothing to check it.

  `release` 92/92, 49 passes / 330 mutations, no golden moved.

- [x] **Task 2 — The verifier census (D1, D3, H1, H7).**
  Five sites: `node-out-targets` (three byte targets), `node-eof-target` (the fourth, so
  `all-out-targets` adds it for reachability and the `:908` filter does not see it),
  `reexec-targets` with **two disjuncts**, the REPORT guard's sixth, and `pass-fields`' sibling
  arm.

  **D1 held, and the two fixtures prove it separately.** Measured: the overflow-disjunct
  mutation fails *only* the overflow self-cycle case, the nondigit-disjunct mutation *only* the
  nondigit one. A single fixture would have hidden whichever half it did not exercise — which is
  exactly what §8's instruction would have shipped, since it names only `nondigit-edge`.

  A third fixture pins the **digit** edge's exclusion (§10.6:566 makes it always advance), so a
  walk that wrongly added it fails; and a fourth is the clean premise.

  **D3 held:** the field-reference check is a sibling arm reusing `invalid-field-operand`,
  reported under the **node's** name per ②'s convention.

  Six mutations; **four shipped report-guard pins re-anchored** for the sixth disjunct — the
  fourth time that guard has moved. `release` 92/92, 49 passes / 336 mutations, no golden moved. Fifteen sites re-measured; the
  accumulate kind joins as **input-reading**. `reexec-targets` takes **two disjuncts** and the
  REPORT guard its sixth, in one commit. `pass-fields` gains its sibling arm.
  **Fixtures: the overflow self-cycle AND the nondigit self-cycle**, since neither distinguishes
  the other's mutant.

- [x] **Task 3 — The normalizer: lowering and encode tag 7 (H2).**
  1:1 like ②'s kinds, so it allocates no internal state. `selector` carries the base,
  `arguments` the field name, `targets` the three byte targets; the EOF routing rides **slot 6's
  shipped `(node . id)` / `(default . code)` convention** with `reason` in slot 7 — H2 confirmed.

  **`acc-eof-of` is a separate lambda, not a widened `eof-of`.** `eof-of` reads
  `byte-dispatch-node-eof-target`, a bare slot read with no tag guard, so handing it another
  kind returns a plausible value from the wrong slot — §4.7 item 4's hazard, avoided by
  construction and pinned.

  Six mutations, each on its own measured golden; the four sharing a case are separated by
  distinct `got` digests, which is what an exact-value pin buys over an inequality. The
  layout-length check ②'s `seq-state` miss earned is applied to the new kind.

  *Seventh SITES collision: the dispatch and accumulate arms wrote the EOF routing identically,
  taking every pin on it to two sites. Factored into `put-eof-routing`; each arm's **call**
  stays separately mutable.*

  `release` 92/92, 49 passes / 342 mutations, no golden moved.

- [x] **Task 4 — The checked multiply-add, both lanes (D5, D6, H1, H5).**
  §15:864-868's inequality written as the spec writes it — a check **before** the multiply-add.
  Overflow leaves the value unchanged *and* does not consume the digit, so the reported position
  kind is `byte`, pinned in both lanes.

  **D5 settled: a separate `accumulate-step` message returning `(target . mode)`**, not a widened
  `field-step`. The mode is unavoidable here — a digit advances, a non-digit takes its edge's
  mode, an overflow consumes nothing — and widening `field-step` would have changed every
  zero-width arm ② shipped for no gain.

  **H5 confirmed:** base 16's digits are three disjoint ASCII ranges, so the digit test is a
  range comparison per base, not one `case` group.

  **§4.7 item 4's hazard was LIVE and is fixed.** `eof-target-of` was a two-way `if` with no else,
  so an accumulate node fell into `byte-dispatch-node-eof-target` — a bare `(vector-ref n 4)`,
  which on an accumulate node is `digit-target`, a symbol. It would have silently routed EOF into
  the digit path. Now a `cond` with a loud else.

  **Two `EXPECT_SURVIVES`, one per lane, and their reason is §15:856 itself.** Compute-then-check
  gives identical answers under Chez's bignums; the pre-check form is mandated for a host that
  *wraps*, which this project does not run on. Unwitnessable by construction — a property of the
  host, not a gap. Survivors go to **12**.

  **H1 realised in full: nine shipped pins had to be re-anchored**, and four duplications could
  not be separated by any anchor because the two arms genuinely do the same thing. Three shared
  tails were factored — `route-byte-step!`, `render-exhausted-preamble`, `put-eof-routing` — each
  leaving every caller's *call* separately mutable.

  `release` 92/92, 49 passes / 349 mutations, no golden moved.

- [ ] **Task 5 — need-input resumption and split-point fragmentation.** The state an accumulate
  node must carry across a feed boundary, which is not obviously a field. The shipped split-point
  idiom is hardcoded for a 4-byte input.

- [ ] **Task 6 — Bases 10 and 16, all-256 partitions (H5).** The digit arm's shape is a decision.
  Both lanes, every byte.

- [ ] **Task 7 — The `byte` position row (H9).** New fixture, new row, two sentinel bumps, two
  `SOURCES` edits, both lanes.

- [ ] **Task 8 — The property generator's field draw (H4).** Inbound edge pinned `reexecute`; the
  oracle extended to compare a field value; the two shipped goldens **re-measured**, because any
  new draw re-rolls the seeded sequence.

- [ ] **Task 9 — The determinism lane and the fourth golden (D4).** Its own
  `BYTE_MACHINE_*_GOLDEN_FILE` in the mutation-suite registration.

- [ ] **Task 10 — Sweeps, the `differential.field` debt (H10), status surfaces, CHANGELOG, and
  the full-milestone Exit section (H13).** Milestone 4 closes here.

---

## Self-Review (run after all ten tasks)

Whole-branch review on the pattern ①a, ①b and ② used. Carry the three lessons this milestone
earned, all of which cost a defect:

- **A sweep re-judges the pins that exist; it cannot notice a decision no pin names.** ②'s
  `seq-state` miss survived six mutations and a 36-pin sweep at zero collisions.
- **A differential compares only what a fixture reaches**, and an operand must separate a member
  from its **siblings**, not merely exercise it.
- **A claim of done outruns the doing.** Three times in this milestone — the `FORTY-EIGHT`
  banner, ②'s "six state literals" census that was eight, and ②'s position-kind row that was
  never added. Verify your own records by running the check they claim.
