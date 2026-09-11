# Milestone 7 — Slice ③ (the printer, the fixture, and the minimizer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

Authority: [decision 0033](../decisions/0033-property-suite-contract.md) item 4 (Gate 0, PR
#85), then `milestone-7-design.md` §4.7 and §8, then the parent plan's `§25:1627`.

This is the slice `§25:1627` names — *minimized/reproducible failure fixtures can be saved
without external tooling*. Slice ② built the fuzzer; this slice builds the crash report. It
adds no draw, no comparison layer and no counter: it turns a disagreement the shipped lane
already detects into **a file a person runs**, and then makes that file small.

Everything below was measured at **`6c832c4`** (`main` after the Slice ② close-out), on branch
`docs/m7-slice-3-plan`, tree clean, against the configured `dev` preset. Each finding states the
command or the file:line that produced it. **Every `src/` and `test/` line number in this plan
is stale the moment Task 2 lands**, so every construct is named as well as numbered, and
**Task 1 re-takes the whole census at the slice's own base before anything is edited.**

One prototype was run against this exact tree (**P3**, §1 F5). It is a *throwaway* and is
labelled as one: it proves the launcher/harness mechanics of a hand-run fixture and nothing
about this slice's own code.

---

## 1. Eleven findings that shape the work

### F1 — §8's "the saver, in the property driver" contradicts F18's functional core, and the seam Slice ② left resolves it without relocating anything

Design §8 says "**The saver**, in the property driver: on the first disagreement per machine,
the fixture program written to `BYTE_MACHINE_TEST_TMPDIR`". Read literally that puts
`open-file-output-port` inside `(byte-machine test property-driver)`, whose own header
(`property-driver.sls:3-9`) states the opposite: "A FUNCTIONAL CORE (F18): it returns values and
asserts NOTHING … The one seam that does I/O is `emit-and-load` in the LANE (and, in Slice ③,
the saver)".

Both are satisfiable, and Slice ② already shaped the resolution:

- `run-machine` takes `on-first-disagreement` as its eighth argument
  (`property-driver.sls:456`) and returns `fixture-path` as its fourth value
  (`:505`, today always `#f`).
- The comment at `:453-455` is an instruction: "on-first-disagreement is #f in this slice and
  fixture-path is always #f: the parameter and the fixture-path return are DEFERRED shaping for
  Slice ③ (0033 item 4) … **Slice ③ adds only the call site; this signature does not change.**"
- `disagreement->detail` is exported at `:530` with the comment "Exported for Slice ③ (0033
  item 4): the caller-chosen `check-fail` detail the saver will render."

**The resolution this plan takes.** The *driver* calls `(on-first-disagreement m script
schedule input verdict)` at the point it folds the first Layer-1 disagreement, and threads that
call's return into the `fixture-path` value. The *lane* supplies the closure, and the closure
does the I/O. §8's sentence is about **where the saver fires**, not where the port is opened.
**Task 12 corrects §8 in place** to say so; a later reader following §8 literally would undo
F18's first reason.

### F2 — the fixture cannot rebuild the manifest, and does not need to; it needs a single-trial entry the driver does not export

This is the load-bearing structural finding of the slice, and it is the other end of a sentence
F18 already wrote: threading a draw manifest out of `gen-machine` "is the generator's *claim*
rather than the machine's *content*, … **and it gives Slice ③'s printer nothing**"
(`milestone-7-slice-2-implementation-plan.md` F18, option 1).

Measured:

- `manifest` has **nine** fields (`machine-gen.sls:205-214`): `fields callbacks spans
  node-kinds key->node cb-targets witnesses markers script`.
- **`make-manifest` is not exported.** `machine-gen.sls:108-110` exports `manifest?` and the
  nine accessors, and no constructor.
- `run-machine` reads the manifest twice over, for two different purposes:
  - the **comparison** needs only `manifest-fields` (`:457`, for `fnames`) and
    `manifest-callbacks` (`:472` into `run-schedule`, `:510` `all-bound`, `:515` `draw-script`);
  - the **decoder** half — `manifest-node-kinds` (`:359`), `manifest-witnesses` (`:387`),
    `manifest-markers` (`:391`) — is read *only* inside `observe-lane!`, which feeds **only the
    counters**.
- The comparison's half is recoverable from the machine: `machine-fields`, `machine-callbacks`
  and `machine-spans` are exported by `(byte-machine private ir)` (`ir.sls:10-11`, defined at
  `:862-864`), and the driver **already imports that library** (`property-driver.sls:53`).

**Therefore:** the fixture asserts one trial and no counter, so it needs no decoder, so it needs
no manifest. It needs a **new exported single-trial entry** on the driver — call it
`run-one-trial` — taking `(machine ref-cm gen-cm script schedule input)` and deriving `fnames`
and the callback declarations from the machine through `ir`. `make-manifest` stays unexported,
nothing prints a manifest, and `run-machine`'s signature does not change (F1's instruction
holds: a **new export** is not a changed signature).

**The minimizer reads the same entry**, which is why it is one export and not two: §4.7's
minimizer "asserts nothing and needs a boolean oracle", and `run-one-trial`'s verdict *is* that
oracle.

### F3 — the printer emits public constructors but must read through `(byte-machine private ir)`, and the asymmetry in `graph.sls` must not be widened

`graph.sls`'s export list carries the **whole construction surface** the printer emits:
`make-machine`, all thirteen `make-*-node`, `make-byte-case`, `make-sequence-case`, `make-edge`,
`make-error-declaration`, `make-uint-field`, `make-callback-declaration`, `make-span-declaration`,
all four matcher constructors and `ascii-bytes`. §4.7's "emits Scheme source against the public
API" is therefore satisfiable exactly as written.

It exports **no node accessors** — with one exception: the `sequence-dispatch-node-*` and
`sequence-case-*` family *is* exported. The header's stated reason for the general rule is
quoted in `AGENTS.md`: "Machine ACCESSORS stay private: §9.1 fixes a construction surface, and
reading a built machine back is not part of it."

**Therefore:** the printer's read side imports `(byte-machine private ir)` — F18's option 2,
with its four-program precedent, and `ir.sls` is already in both property lane manifests via
`BYTE_MACHINE_CORE_EMIT`, so **no CMake manifest gains a file for this**. Widening `graph.sls`
is a `src/` change and is **ruled out by §4.9's gate**. The sequence-family exception is
pre-existing; this slice does not extend it and does not remove it.

### F4 — the closed sets are thirteen and four, and the derived row's operand must be the printer's own hand-written table

`node?` (`ir.sls:662-667`) has **thirteen** disjuncts: `byte-dispatch sequence-dispatch stop
error finish pause field-action field-branch integer-accumulate callback span-start span-end
counted-consume`. `matcher?` (`ir.sls:193-195`) has **four**: `exact-byte byte-set byte-range
byte-complement`.

The S2 technique, and the trap F18 records verbatim: the printer's arm table is **hand-written
and exported**, and the totality row derives `node?`'s disjuncts from `ir.sls` **as a datum** and
compares the two sets. **If the printer dispatched off a list read out of `ir.sls` at run time,
the row would compare `ir.sls` against `ir.sls` and close nothing.** The property program already
carries readers of exactly this shape (`property-differential-tests.sps`, the `ir-datum` /
`strip-suffix` block at `:165-175`); the printer's rows reuse them rather than writing a fourth.

Design §4.9's Appendix list is an instruction: the printer's arm table is one of the
**test-side censuses this milestone names** so Milestone 8's slices find it.

### F5 — "without external tooling" is measured TRUE, and the cost is that the fixture must carry its own invocation

**P3 (prototype, run 2026-09-11 against `6c832c4`).** A fixture-shaped standalone `.sps` —
importing `(byte-machine test harness)`, `(byte-machine graph)`, `(byte-machine verify)`,
`(byte-machine interpret)`, `(byte-machine runtime)` — placed in a scratch directory outside the
tree and run with:

```
env -u BYTE_MACHINE_FINGERPRINT_FILES -u BYTE_MACHINE_EXPECT_FINGERPRINT_FILE \
    -u BYTE_MACHINE_TEST_TMPDIR \
  chez --script <tree>/test/support/launchers/chez-source.ss \
    --library-root <tree>/test/support/harness \
    --library-root <tree>/src \
    --object-guard <build>/chez-object-guard \
    --program ./fixture-probe.sps
```

printed the harness banner, then `FAIL … the lanes agree`, then
`summary … failed-cases=1 checks=2 failures=1 … status=1`, and **exited 1**. Re-running with the
failing check removed exits 0.

Two mechanisms make that work, both verified rather than assumed:

1. **Provenance is skipped when `BYTE_MACHINE_FINGERPRINT_FILES` is unset**
   (`harness.sls:711-723`, `harness-verify-provenance!` at `:724`). The comment names this case
   explicitly: "An unset or empty `BYTE_MACHINE_FINGERPRINT_FILES` means this process was not
   started by a lane registration, and the only things that start a harness program any other
   way are **a developer running one by hand** and the Scheme mutation suite." A hand-run fixture
   therefore does **not** trip `PROVENANCE-ERROR`.
2. **The launcher does not check that `--library-root` names an existing directory**
   (its own header says so, and says why). It *does* check the object guard with
   `file-directory?`.

**The cost.** `chez-source.ss` requires `--library-root` (repeatable), `--object-guard` and
`--program`; none is defaulted. A saved fixture that does not carry those flags is reproducible
only by someone who already knows them, which is not what `§25:1627` claims. **The saver
therefore writes the exact invocation into the fixture's header comment**, with the two library
roots and the object guard as the lane knew them (absolute paths), plus the seed and the machine
index. Task 6's oracle runs that comment's command verbatim, by hand, once, and the plan records
the output.

### F6 — the fixture must emit a generated lane, which needs a writable directory, and `BYTE_MACHINE_TEST_TMPDIR` is exactly what a hand-run fixture does not have

The generated half of the differential comes from `emit-and-load`
(`property-differential-tests.sps:78-83`): it writes `"<tmpdir>/prop-<i>.sls"`, `load`s it, and
`(eval 'gen-parser (environment '(generated gen)))`. `tmpdir` is read at `:73-76` and is
**loud when unset** — `assertion-violation 'property "BYTE_MACHINE_TEST_TMPDIR is unset"`.

A hand-run fixture has it unset (P3 ran with it unset deliberately). The fixture therefore
cannot copy the lane's `emit-and-load` verbatim.

**Task 5 Step 1 is a bounded experiment with a stated fallback**, because the two resolutions
differ in kind and only measurement decides:

- **(a)** `eval` the `(library (generated gen) …)` form directly, with no file at all. If Chez
  accepts a library definition through `eval` in the fixture's environment, the fixture becomes
  genuinely self-contained and F5's claim strengthens.
- **(b)** if (a) does not hold: the fixture defaults its emission directory to **its own
  directory** — `BYTE_MACHINE_TEST_TMPDIR` when set, else `"."` — and says in the file that it
  writes one `.sls` beside itself.

**The experiment is time-boxed to Step 1 and its result is recorded either way.** (b) is a
complete answer on its own; (a) is only better. Do not spend the slice on (a).

### F7 — the liar reads slot 2, because `compiled-machine-op` is exported nowhere

§4.7's probe is "a compiled machine whose op is wrapped to lie about one member". Measured:

- `(byte-machine runtime)` exports `make-compiled-machine` and `compiled-machine?` and **no op
  accessor** (`runtime.sls:12-13`); `compiled-machine-variant` and the `/v2` accessors are
  internal too.
- `make-compiled-machine op` builds `(vector compiled-machine-tag 'op op)` (`runtime.sls:73-76`).
- `make-parser` itself reads the op as `(vector-ref compiled-machine 2)` (`runtime.sls:440`)
  after dispatching on `(compiled-machine-variant …)`.
- The op is a **message-dispatch closure**, not a step function: `interpret.sls:384-386` shows
  `(lambda (msg . args) (case msg ((entry) …) …))`, with at least `entry`, `field-initials` and
  `field-step` (`:445-453`) in the vocabulary.

**Therefore** the probe builds its liar as

```scheme
(make-compiled-machine
  (let ((real (vector-ref honest-cm 2)))
    (lambda (msg . args) (perturb msg (apply real msg args)))))
```

reaching slot 2 knowingly, from a test, on `AGENTS.md`'s own precedent ("the test reaches inside
knowingly, and the public narrowness stays true"). **This is not a `src/` change and §4.9's gate
stays clean.** The rejected alternative is named in the file: exporting an op accessor from
`runtime.sls` would widen a public surface for a test's convenience, which `AGENTS.md` forbids in
those words.

**Which member to lie about is Task 6 Step 2's measurement, not this plan's guess.** The
constraint is that the lie must be *reducible*: a perturbation that disagrees on every input
gives the minimizer nothing to shrink toward and would reach §8's bound for the wrong reason
(F10). Candidates in preference order — a `field-step` commit off by one; `field-initials`
altering one field's initial. Measure which yields a disagreement on **some but not all** drawn
inputs and record the rate.

### F8 — repeated same-named library load is already proven at the lane's scale, but prove it directly anyway

The shipped lane calls `emit-and-load` once per machine — **64 loads of a library named
`(generated gen)` in one process**, each followed by `(eval 'gen-parser (environment '(generated
gen)))`. If `environment` resolved to the *first* load, every machine after the first would be
compared against machine 0's parser and the counters could not reach thirty node kinds; they do
(census 30 codes / 56 sites, per-constructor 14/30/11/1, measured on the merged tree). So the
mechanism holds at 64.

The minimizer rides the same mechanism harder: up to **64 re-emissions inside one machine's
reduction loop**, interleaved with trials. **Task 1 Step 6 measures it directly** — two loads of
two different machines under one name, asserting the second `environment` lookup yields a parser
that behaves as the second machine — because the lane proves this only incidentally, and an
incidental proof is the kind that a later change silently removes.

### F9 — the timing budget comes from the probe's shape, not from the differential's

Design §4.9's note (2026-09-11, Task 8 Step 4, via ctest) measured the two property differential
lanes at **~4 s each against a 180 s timeout**, with emission dominating. That number describes
**64 machines × ~50 schedules**; the fixture lane runs **one** machine.

The minimizer's cost is `(reductions attempted) × (one emission + one trial)`. A single trial is
one schedule, not the 256-byte sweep plus eight inputs, so it is roughly three orders of
magnitude below a `run-machine` call — **which is the reason F2's single-trial entry is required
and not merely convenient**: a minimizer whose oracle was `run-machine-verdict`
(`property-driver.sls:504-505`) would re-run the full sweep per candidate.

**Task 7 sets the fixture lane's timeout from a measurement taken after Task 5 lands**, never by
copying 180.

### F10 — the bound is pinned only after an attempt, and §8 says so in those words

Design §8: "the bound — pinned only after an attempt: a probe whose lying lane disagrees on every
reduction reaches it, and **if no probe can, the survivor is declared with that measured reason,
never before the attempt**."

This plan carries that forward unchanged: **Task 8 Step 5 may not declare the 64-emission bound a
survivor until Task 6 has tried to reach it.** If it is reached, it is pinned like any other
constant; if it is not, the survivor declaration quotes the attempt's measured numbers. A
survivor declared from reading is the shape `AGENTS.md` records as the recurring defect.

### F11 — `artifacts=` already exists in the failure context, and the design says two different things about where the path goes

Measured in P3's own output, verbatim:

```
byte-machine-harness: FAIL-CONTEXT id="the probe.the lanes agree" test=(unregistered) … artifacts="(none)"
```

Design §4.3 item 4 says the check's detail names the file **and** that the context line "already
prints it as `artifacts=`". Design §8 says only "its path in the check detail".

**Task 4 Step 3 measures which mechanism sets `artifacts=`** — whether the harness exposes a
setter or whether the string is fixed — and resolves the two sentences in favour of what the
harness can actually do, then corrects the losing sentence in place (Task 12). Writing the path
into the check detail is required either way; `artifacts=` is required only if the harness
already supports it without a harness change.

---

## 2. What this slice ships

**One source commit and one documentation commit, one PR** — design §11's allocation for ③ and
④, unchanged.

- **`(byte-machine test machine-print)`**, new test-support library: the printer of §4.7, total
  over the thirteen node kinds and four matcher kinds, plus the declaration families and
  `make-machine` itself. Emits `§9.1` constructor calls against `graph.sls`'s public surface
  (F3); reads through `(byte-machine private ir)`.
- **`run-one-trial`**, new export on `(byte-machine test property-driver)` (F2): one machine, one
  script, one schedule, one input, declarations derived from the machine; returns the Layer-1
  verdict. The fixture asserts on it and the minimizer uses it as a boolean oracle.
  `run-machine`'s signature does not change.
- **The saver**: a closure built in `property-differential-tests.sps` and passed as
  `run-machine`'s existing `on-first-disagreement` argument (F1). Writes the fixture program,
  returns its path, which `run-machine` threads into the `fixture-path` return; the lane names
  the path in the check detail (F11).
- **The minimizer**, in the driver as a pure function over `(machine script input schedule)` with
  an injected emit-and-run oracle (so it stays inside F18's functional core): §4.7's reduction
  sequence, both oracles (the **verifier** for validity, `run-one-trial` for failure), greedy to a
  fixpoint, deterministic, bounded to 64 emissions. Writes the minimized fixture beside the raw
  one.
- **`test/common/property-fixture-tests.sps`**, new, registered in both lanes as
  `byte-machine.property.fixture.chez.{source,aot}` under label `property` (design §4.9): the
  deliberate-failure probe of §4.7 — a lying lane (F7) driven through the saver and the
  minimizer; the raw fixture loaded in-process and asserted to **fail**; the minimized one
  asserted strictly smaller (fewer nodes or a shorter input) **and still failing**; a **passing**
  pair asserted to write nothing.
- **Pins**: a new mutation pass over the new program, plus the `EXPECTED_MUTATIONS` arithmetic.
- **Documentation**: the §8/§4.3/§4.7 corrections F1 and F11 force, the design and parent-plan
  Status lines, `CHANGELOG.md`, `README.org`, and the appendix entry for the printer's arm table.

**What this slice does not ship:** no `src/` change of any kind; no new draw, comparison layer or
counter; no corruption catalogue and no independent oracle (Slice ④); no serialized IR format, no
CLI and no visualizer (`§29:1760-1762` — the printer lives in `test/support`, emits Scheme source
against the public API, and has no reader but `load`).

---

## Global Constraints

- **Authority order.** Decision 0033 item 4, then design §4.7/§8, then the parent plan. **Where
  an authority is wrong, stop and say so.** This plan carries **three** such findings — F1 (§8's
  "in the property driver" contradicts the driver's own header), F11 (§4.3 item 4 and §8 disagree
  about where the fixture path is reported), and F6 (§4.7's fixture shape omits that the
  generated lane needs a writable directory). **All three are corrected in place by Task 12.**
  Slice ②'s plan carried ten, Slice ①'s two, Slice ⓪'s three.
- **Design §4.9's gate, re-taken at this slice's base.** This slice touches no `src/` file at
  all: `git diff --stat main..HEAD -- src/` prints **nothing**. One line of output means the plan
  is wrong. Run it at the end of every task.
- **No committed golden and no pinned fingerprint literal moves.**
  `git diff --stat main..HEAD -- test/fixtures` prints nothing.
- **The `SOURCES` fingerprint is baked at configure time.** Editing any `.sls` listed in a lane's
  `SOURCES` — `property-driver.sls` and the new `machine-print.sls` both are — requires
  `touch test/CMakeLists.txt && cmake --preset dev && cmake --build --preset dev` or the lane
  fails `PROVENANCE-ERROR`. This has cost this project two sessions; the mutation lane is immune,
  which is what makes it easy to miss.
- **A number from a throwaway driver describes the driver.** P3 is the only prototype here and
  its claim is scoped to launcher and harness mechanics. Every rate, count and timing this slice
  states must be re-measured **through the registered lane**.
- **Prose expectations are not checks.** Every verification step below states an exact literal,
  an exact count, or the exact command whose output is compared — never a described expectation.
- **A saver that writes a fixture which passes is the defect to pin** (§4.7). Three of the four
  pin families in Task 8 have that same failure signature — the artifact is green when the bug is
  red — and it is the signature the mutation lane is least able to see by exit status alone.
  Assert the failure *signature*, not a nonzero exit.
- **Filter for failure, not success.** A "suite complete" line is printed on the way to failing.
  Grep the error signatures and the exit status.
- **Sentinels read observed values, and every loop carries a literal total and a derived total.**
  The minimizer's reduction loop and the printer's arm sweep each get both.
- **Stage before measuring a mutation by hand.** `git checkout --` to undo a hand-applied
  mutation wipes unstaged implementation work. Stage first; treat any reconstruction as untrusted.
- **Re-measure every cross-document `file:line` as the last step before commit**, not while
  writing. A citation into a file this branch edits is stale on arrival and no link check sees it.

---

## Task 1 — Re-take every measurement at the slice's own base

- [x] **Step 1.** Confirm the base: `git rev-parse --short HEAD`, `git status --porcelain`
      (empty), `git log --oneline -1 main`. Record the SHA; every later citation is relative to it.
      **Measured 2026-09-11:** branch `docs/m7-slice-3-plan`, `HEAD` = `23d9c2a`, tree clean;
      `main` = `6c832c4`. The branch adds only this plan doc (`git diff --stat main..HEAD` =
      one file, 690 insertions), so the `src/` and `test/` tree every citation names is
      byte-for-byte `main` at **`6c832c4`** — the SHA all later citations are relative to.
- [x] **Step 2.** Re-run the full release selection in **both** Chez modes and record the totals.
      The merged-tree numbers to reproduce or correct: **114/114 both modes**.
      **Measured 2026-09-11 at `6c832c4`** (`ctest --preset release -V`, which registers both the
      `.chez.source` and `.chez.aot` lanes): **`100% tests passed, 0 tests failed out of 114`**,
      total test time 253.42 s. Reproduces.
- [x] **Step 3.** Re-run the mutation lane and record: the merged-tree numbers are **58 passes /
      557 mutations**, with `EXPECTED_MUTATIONS 557` at `test/support/cmake/SchemeMutationSuite.cmake:1380`.
      Record the exact line number at this base — Task 8 edits it.
      **Measured 2026-09-11 at `6c832c4`:** the Scheme mutation suite reports
      **`scheme mutation suite complete (58 passes, 557 mutations)`** (exit 0) — reproduces.
      `EXPECTED_MUTATIONS 557` is at **`SchemeMutationSuite.cmake:1380`** and `EXPECTED_PASSES 58`
      at **`:1379`** (Task 8 Step 4 edits :1380). The CMake *spec* mutation suite
      (`byte-machine-spec … 1 pass, 72 mutations`) is separate and unrelated to this arithmetic.
- [x] **Step 4.** Re-take every `file:line` cited in §1 F1–F11 and correct any that moved. The
      set: `property-driver.sls` :3-9, :53, :359, :387, :391, :453-456, :472, :504-505, :510,
      :515, :530; `machine-gen.sls` :108-110, :205-214; `property-differential-tests.sps` :73-76,
      :78-83, :165-175; `ir.sls` :10-11, :193-195, :662-667, :862-864; `graph.sls`'s export list;
      `runtime.sls` :12-13, :73-76, :440; `interpret.sls` :384-386, :445-453;
      `harness.sls` :454, :509, :530, :711-723, :724.
      **Measured 2026-09-11 at `6c832c4`:** every one reproduces exactly — **none moved**
      (expected: the branch tree is `main` content). Spot-confirmations worth keeping: `node?`
      has thirteen disjuncts and `matcher?` four (`ir.sls` :662-667 / :193-195, F4); `run-machine`'s
      signature is `(m ref-cm gen-cm manifest inputs state counters on-first-disagreement)` with
      `on-first-disagreement` the **eighth** arg at `property-driver.sls:456`, and its verdict
      fold returns `fixture-path` as the **fourth** of five values (`:505`, F1/F2);
      `make-manifest` is **not** in `machine-gen.sls:108-110`'s export list (nine accessors, no
      constructor, F2); `graph.sls` exports the whole construction surface plus the matcher and
      `sequence-*` accessor families and **no other node accessors** (F3); `make-parser` reads the
      op at `(vector-ref compiled-machine 2)` (`runtime.sls:440`, F7); the provenance skip on
      unset `BYTE_MACHINE_FINGERPRINT_FILES` is `harness.sls:711-724` (F5); `harness.sls`'s only
      datum writer is the internal `with-output-to-string`+`write` at `:149` (Task 2 Step 6).
- [x] **Step 5.** Re-take the property lanes' wall-clock through `ctest` in both modes (design
      §4.9's note says ~4 s each at a 180 s timeout). Task 7 sets the new lane's timeout relative
      to this, and a base that has drifted changes that arithmetic.
      **Measured 2026-09-11 at `6c832c4`** (from the same `ctest --preset release -V` run):
      `byte-machine.property.differential.chez.source` **Passed 4.26 sec**,
      `…​.chez.aot` **Passed 4.08 sec**, both against a 180 s `TIMEOUT`. No drift from §4.9's note;
      Task 7's fixture-lane timeout is set from Task 5 Step 8's measurement, not from these.
- [x] **Step 6 (F8).** Measure repeated same-named library load directly. Write a throwaway
      program that emits **two different** machines to two files, both declaring `(generated gen)`,
      loads them in order, and asserts the second `(eval 'gen-parser (environment '(generated
      gen)))` behaves as the **second** machine on an input the two disagree on. Record the result
      verbatim. **If the second load does not win, stop**: §4.7's minimizer is unbuildable as
      specified and the finding goes to the owner before any code is written.
      **Measured 2026-09-11 at `6c832c4` — RESULT: PASS, the second load wins; the minimizer is
      buildable as specified, no escalation.** Two one-dispatch machines (accept `0x41` vs accept
      `0x42`), each named `gen` so each emits `(library (generated gen) (export gen-parser) …)`
      through `emit-machine`/`compile-machine` exactly as `emit-and-load` does
      (`property-differential-tests.sps:78-83`), written to two files, run through the source
      launcher with provenance unset (F5's `env -u`). Verbatim:

      ```
      load A -> gen-parser(0x41) = stopped
      load B -> gen-parser(0x41) = error

      first load resolved to A?  #t
      SECOND LOAD WINS (B)?       #t

      F8 RESULT: PASS -- second same-named load wins; minimizer buildable
      EXIT=0
      ```

      After `(load fileA)`, `(eval 'gen-parser (environment '(generated gen)))` drives `0x41` →
      `stopped` (machine A accepts); after `(load fileB)` under the **same** library name a fresh
      `environment` lookup drives `0x41` → `error` (machine B rejects). The later `load` shadows
      the earlier binding, so the minimizer's up-to-64 re-emissions-under-one-name inside one
      reduction loop resolve to the current candidate, not a stale one. **Two incidental findings
      for later tasks:** (a) the emitted **library name is `(generated <machine-name>)`** — the
      `'gen-parser` argument to `emit-machine` is only the *export* name; the lane works because
      `gen-machine` names every drawn machine `'gen` (`machine-gen.sls:729`), so Task 4's saver
      must emit the machine under a name whose `(generated …)` form the fixture re-loads.
      (b) machine names must be **portable** (`invalid-name` rejects the capital in `'mA`), so the
      saver emitting a machine named `gen` stays legal. Throwaway lives at `scratchpad/f8-probe.sps`,
      outside the tree.
- [x] **Step 7.** Re-run design §4.9's gate (`git diff --stat main..HEAD -- src/`) and record that
      it is empty at the base. **Measured 2026-09-11:** empty — the whole branch diff is one file,
      `docs/plans/milestone-7-slice-3-implementation-plan.md` (690 insertions), and nothing under
      `src/`.

**Exit:** every number in §1 either reproduces or is corrected in place, with the correcting
command written beside it.

---

## Task 2 — The printer, tests first

- [ ] **Step 1.** Write the printer's tests **before** the printer, in a new
      `test/common/machine-print-tests.sps` or folded into the probe program — Task 6 Step 1
      decides which, and the decision is recorded with its reason. The tests assert:
      (a) the **derived totality row** — `node?`'s thirteen disjuncts and `matcher?`'s four, read
      from `ir.sls` as a datum with the property program's existing reader shape (`property-differential-tests.sps:165-175`), set-equal to the
      printer's **hand-written exported arm table** (F4); (b) the **round trip** on a fixed
      hand-built machine.
- [ ] **Step 2.** Write `(byte-machine test machine-print)` in
      `test/support/harness/byte-machine/test/machine-print.sls`. Exports: the printer entry, and
      the arm table (`node-print-arm-table`, `matcher-print-arm-table`) for the row to read.
      Imports `(byte-machine private ir)` for reading (F3) and emits calls to `graph.sls`'s public
      constructors only.
- [ ] **Step 3.** Cover the **declaration families and `make-machine`**, not only nodes: uint
      fields, callback declarations, span declarations, error declarations, byte cases, sequence
      cases, edges. A printer total over nodes and partial over declarations reprints a machine
      that verifies and is not the same machine.
- [ ] **Step 4.** The round trip's proof is the **IR fingerprint**, not structural equality:
      `render-machine` of `compile-machine` of the reprinted machine is **byte-identical** to that
      of the original (`property-differential-tests.sps`'s `machine->bytes` is exactly this
      function — reuse its shape, and say in the file that it is the same proof).
- [ ] **Step 5.** Run the round trip over **every accepted machine of the committed seed set**
      (§8), not over a hand-picked few. Record the accepted count it ran over; the merged-tree
      floor is 32 with 36 measured.
- [ ] **Step 6.** Do **not** `write` a machine object. A machine is a tagged vector and `write`
      renders `#(…)`. The printer builds a **datum** — a list of constructor-call forms — and
      writes that. §4.7's phrase "the harness's own writer" names no export that exists
      (`harness.sls` has no general datum writer; `with-output-to-string` + `write` at `:149` is
      internal): **Task 12 corrects the phrase** to say what the constraint actually is.
- [ ] **Step 7.** Reconfigure after adding the `.sls` (Global Constraints: the `SOURCES`
      fingerprint), then re-run the property lanes.

**Exit:** the derived row is set-equal, the round trip is byte-identical over every accepted
machine, and `git diff --stat main..HEAD -- src/` is empty.

---

## Task 3 — `run-one-trial`: the single-trial entry (F2)

- [ ] **Step 1.** Tests first: a machine whose two lanes agree returns `'none`; a machine driven
      against a deliberately different second lane returns a non-`'none` verdict of the same shape
      `run-machine` produces.
- [ ] **Step 2.** Add `run-one-trial` to the driver's exports. Signature:
      `(run-one-trial m ref-cm gen-cm script schedule input) -> verdict`. Derive `fnames` from
      `(machine-fields m)` and the callback declarations from `(machine-callbacks m)` — **not**
      from a manifest (F2).
- [ ] **Step 3.** Factor, do not duplicate. `one-schedule`'s body already does this work
      (`property-driver.sls:470-481`); `run-one-trial` and `run-machine` must share it, or the
      disagreement rule exists twice and drifts. The driver's header states "one body, three
      consumers" — a second copy falsifies it.
- [ ] **Step 4.** Assert `run-machine`'s signature is unchanged: its argument list and its five
      return values are byte-identical to the base. Cite F1's comment at `:453-455` in the commit
      message as the instruction being honoured.
- [ ] **Step 5.** Prove the two entries agree: for a machine and a schedule the full sweep covers,
      `run-one-trial`'s verdict equals the verdict `run-machine` folds for that same schedule.
      Without this, the fixture can reproduce a disagreement the lane never had.
- [ ] **Step 6.** Reconfigure (the driver is in both lanes' `SOURCES`), re-run both property lanes.

**Exit:** `run-one-trial` exported and shared with `run-machine`'s body; Step 5's agreement
asserted in the suite, not in the plan.

---

## Task 4 — The saver

- [ ] **Step 1.** Tests first: a lane whose trial disagrees writes **exactly one** file per
      machine; a lane whose trials agree writes **none**.
- [ ] **Step 2.** In the driver, call `on-first-disagreement` at the point `fail!` folds the
      first Layer-1 verdict, and thread its return into the `fixture-path` value (F1). The driver
      opens no port. Guard the call so `#f` stays a legal argument — the existing
      `run-machine-verdict` passes `#f` and must keep working.
- [ ] **Step 3 (F11).** Measure how `artifacts=` is populated in `FAIL-CONTEXT` and record it.
      If the harness exposes a setter, use it and keep §4.3 item 4's sentence; if it does not,
      the path goes in the check detail alone and §4.3's sentence is the one corrected. **Do not
      change the harness to make a design sentence true.**
- [ ] **Step 4.** The saver closure lives in `property-differential-tests.sps` and writes the
      fixture program of §4.7: the `import` the lane uses, the printed machine datum, the callback
      script and schedule as quoted data, one `harness-group` with one case calling
      `run-one-trial`, and `harness-finish`.
- [ ] **Step 5 (F5).** Write the **invocation header** into the fixture as a comment: the exact
      `chez --script … chez-source.ss --library-root … --library-root … --object-guard …
      --program <this file>` command, plus the seed and the machine index. Absolute paths, as the
      lane knew them.
- [ ] **Step 6 (F6).** Resolve the fixture's emission directory per F6's experiment result, and
      state the resolution in the fixture's own header.
- [ ] **Step 7.** "At most once per machine" is the driver's existing rule (`fail!` sets `verdict`
      only `(when (eq? verdict 'none) …)`). Assert the saver inherits it rather than re-deriving
      it: one file per machine even when many schedules disagree.

**Exit:** a disagreeing trial produces one file whose header carries a runnable command; an
agreeing run produces none.

---

## Task 5 — The minimizer

- [ ] **Step 1 (F6).** Run F6's time-boxed experiment and record the result. Everything below
      holds under either answer.
- [ ] **Step 2.** Tests first: a reduction that no longer disagrees is **rejected**; a reduction
      whose machine no longer verifies is **rejected**; a reduction that is smaller and still
      disagrees is **accepted**; the loop terminates.
- [ ] **Step 3.** Implement §4.7's reduction sequence, in order, as a pure function over
      `(machine script input schedule)` with the emit-and-run oracle injected: remove a node —
      **its in-edges retargeted to a fresh error node of its own, never a shared sink** — remove a
      case or an alternative, remove an unnamed declaration, drop one input byte, merge two
      adjacent feeds, drop a resume or the finish.
- [ ] **Step 4.** The fresh-error-node rule is load-bearing and its reason goes in a comment at
      the site: a shared sink joins `none` with `(active s)` inside a span and stops every
      subsequent reduction at `inconsistent-span-state` (decision 0029 item 2).
- [ ] **Step 5.** The two oracles are the shipped ones and no third: **validity** is
      `verify-machine`'s verdict, **failure** is `run-one-trial` returning any non-`'none`
      verdict — *any* disagreement, not necessarily the same tag.
- [ ] **Step 6.** Greedy to a fixpoint, deterministic, bounded to **64 emissions**. The bound is a
      named constant with its own pin candidate (F10, Task 8).
- [ ] **Step 7.** Write the minimized fixture beside the raw one, through Task 4's saver — one
      writer, two calls.
- [ ] **Step 8.** Measure the per-candidate cost and the emissions actually used on the probe's
      machine. Task 7 reads these numbers.

**Exit:** Step 2's four properties asserted; the reduction order implemented as §4.7 lists it;
Step 8's numbers recorded.

---

## Task 6 — `property-fixture-tests.sps`, the deliberate-failure probe

- [ ] **Step 1.** Decide and record where the printer's tests live (Task 2 Step 1) — folded here,
      or their own program. Folding keeps one new lane pair; a separate program keeps the probe's
      failure signature clean for the mutation pass. **Record the reason for whichever is chosen.**
- [ ] **Step 2 (F7).** Build the lying lane by wrapping slot 2, and **measure which member to lie
      about**: the perturbation must disagree on *some but not all* drawn inputs, or the minimizer
      has nothing to shrink toward. Record the disagreement rate for the member chosen and for at
      least one rejected candidate — the spread is the evidence that the choice was measured.
- [ ] **Step 3.** Drive the pair through the saver and the minimizer.
- [ ] **Step 4.** Load the **raw** fixture in-process through `eval` and assert it **fails**.
- [ ] **Step 5.** Assert the **minimized** fixture is strictly smaller — fewer nodes **or** a
      shorter input — **and still fails**. Both halves, in one case.
- [ ] **Step 6.** Assert a **passing** pair writes **nothing**: no raw fixture, no minimized one.
- [ ] **Step 7.** Sentinels: the reduction loop's literal and derived totals, and a counter over
      the loop over the loops. A counter computed from the test's own expectation asserts nothing
      — read observed values.
- [ ] **Step 8 (F5).** **By hand, once**: run the raw fixture's own header command from the tmp
      directory and record that it exits **1**; edit the lie away and record that it exits **0**.
      Paste both outputs into this plan's Verification section. This is `§25:1627`'s oracle and it
      is not satisfied by an in-process `eval` alone.

**Exit:** all six assertions green in both lanes; Step 8's two transcripts recorded.

---

## Task 7 — CMake: two registrations and a measured timeout

- [ ] **Step 1.** Register `byte-machine.property.fixture.chez.source` and `…​.aot` with
      `byte_machine_add_scheme_lane`, modelled on the differential pair at
      `test/CMakeLists.txt:1607-1637`. `SOURCES` gains `machine-print.sls` beside `machine-gen.sls`
      and `property-driver.sls`.
- [ ] **Step 2.** `ENVIRONMENT`: `BYTE_MACHINE_SOURCE_ROOT` if and only if the program reads
      `ir.sls` as a datum (it does if Task 6 Step 1 folds the printer's rows here). Do **not** pass
      a seed — decision 0033 item 3's "the registrations pass nothing" governs the seed.
- [ ] **Step 3.** Set `TIMEOUT` from Task 5 Step 8's measurement plus margin. **Do not copy 180.**
      Record the measured wall-clock for both lanes.
- [ ] **Step 4.** Confirm both lanes carry label `property` and are selected by the `pr` preset
      (design §4.9).
- [ ] **Step 5.** Reconfigure and re-run the full release selection in both modes. Record the new
      totals; the base is 114/114.

**Exit:** two new lanes green in both modes, with their measured timings recorded.

---

## Task 8 — The pins

- [ ] **Step 1.** Open a new pass over `property-fixture-tests.sps`, placed **after the previous
      pass's `_run`** — a new block before it, or a `reset()` first, discards it.
- [ ] **Step 2.** The four pin families from §8, each asserting a **failure signature**, never a
      bare nonzero exit:
      - the printer's arm for one kind emitting **another kind's** constructor — caught by the
        round trip's fingerprint;
      - the saver writing the **base** machine instead of the corrupted trial — the reloaded
        fixture **passes**;
      - the minimizer accepting a reduction that **no longer disagrees** — the minimized fixture
        **passes**;
      - the bound (F10, Step 5).
- [ ] **Step 3.** Before adding any pin, run the **two-direction sweep**: every new mutant against
      every shipped pin, and every shipped mutant against every new pin. A new check label that
      *contains* a shipped pin's regex resolves that pin to two checks and neither the sweep nor
      the lane sees it — so also take a **per-pin match count** against its own mutant's output.
- [ ] **Step 4.** `EXPECTED_MUTATIONS` is a formula in (additions, retirements), not a guess.
      Compute it, edit the literal at `SchemeMutationSuite.cmake:1380` (re-measured in Task 1
      Step 3), and confirm `EXPECTED_PASSES` moves by exactly one.
- [ ] **Step 5 (F10).** Attempt the bound before declaring anything about it. If reached, pin it;
      if not, declare the survivor **with the attempt's measured numbers** in its declaration.
- [ ] **Step 6.** Re-run the whole mutation lane and record passes and mutations. The base is
      58/557.

**Exit:** the arithmetic closes exactly, the sweep is clean in both directions, and every new pin
has a recorded match count of 1 against its own mutant.

---

## Task 9 — The sweep, the match-count matrix, and the label audit

- [ ] **Step 1.** Sweep every pin whose `FIND` **or** `REPLACE` touches a construct this slice
      renames or re-contracts — `run-machine`'s call site, `property-differential-tests.sps`'s
      import list, the driver's export list. A census by `FIND` location alone misses pins whose
      `REPLACE` names a construct the slice re-shaped.
- [ ] **Step 2.** Produce the match-count matrix: for each pin touched, the number of records of
      its own mutant's output that its regex matches. Anything but 1 is a finding.
- [ ] **Step 3.** Audit every new `LABEL` for containment against every shipped pin's regex, both
      directions.
- [ ] **Step 4.** Confirm no pin regex uses `.*` to bridge `expected` and `got` (CMake `.` spans
      newlines, so it bridges to a later record), and that no regex ends at `got`.

**Exit:** the matrix is all-ones and the label audit is clean.

---

## Task 10 — Both ends, the records, and the status surfaces

- [ ] **Step 1.** Every deferral this slice creates is written at **both** ends: here and at its
      receiver. A deferral recorded only in this plan closes nothing.
- [ ] **Step 2 (F1, F11, F6, and Task 2 Step 6).** Correct design §8, §4.3 item 4 and §4.7 **in
      place**, each with a dated annotation naming the measurement that forced it. Do not reword a
      parent-plan exit criterion.
- [ ] **Step 3.** Add the printer's arm table to the design Appendix's list of test-side censuses
      (§4.9 names it already — confirm it is there and correct it if not).
- [ ] **Step 4.** Update **four** status surfaces, not three: `README.org`, the parent plan's
      Status line, `milestone-7-design.md`'s Status header, and `CHANGELOG.md`. `README.org` is
      the one the closing ritual does not name and the one that sat three milestones stale.
- [ ] **Step 5.** Re-measure every cross-document `file:line` this plan and the design cite, as
      the **last** step before the documentation commit.

**Exit:** three corrections applied with dated annotations; four status surfaces agree.

---

## Task 11 — The whole-branch review, and the close

- [ ] **Step 1.** Review the **whole branch**, not the tasks: every task passing tells you nothing
      about the seams. The question is which invariant has no owner.
- [ ] **Step 2.** Reviewers are told to check what the code **does** against the code, never
      against this plan's prose — a decision can be right while its stated reason is false.
      Put `AGENTS.md`'s sentence in the reviewer's prompt **verbatim**; do not paraphrase it, and
      do not invent constraints, which are indistinguishable from real ones and block fixable
      findings.
- [ ] **Step 3.** Specific seams to name in the prompt: the driver's functional core after the
      saver lands (F1); `run-one-trial` and `run-machine` sharing one body (Task 3 Step 3); the
      fixture's import list against the lane's (§8's "imports only what the lane imports"); the
      printer's arm table against `node?` after any rebase.
- [ ] **Step 4.** Full release selection, both Chez modes; full mutation lane; both new lanes.
      Record every total.
- [ ] **Step 5.** Ask the owner before running the closing ritual. Merging `main` is gated; the
      agent performs the squash-merge itself once the owner says go.

**Exit:** review clean or every finding dispositioned; all suites green; owner asked.

---

## Verification

Run from the repository root at the branch's tip. Each command's expected output is a literal or
an exact count, never a description.

- [ ] `git diff --stat main..HEAD -- src/` → **empty** (design §4.9's gate).
- [ ] `git diff --stat main..HEAD -- test/fixtures` → **empty**.
- [ ] Full release selection, **Chez source** → record `N/N`; the base is 114/114 and this slice
      adds two lanes.
- [ ] Full release selection, **Chez AOT** → same count as source.
- [ ] Mutation lane → record passes/mutations; the base is 58/557 and Task 8 Step 4 states the
      new pair.
- [ ] `byte-machine.property.fixture.chez.source` and `.aot` → pass; record each wall-clock.
- [ ] The printer's derived totality row → **13** node kinds and **4** matcher kinds, set-equal.
- [ ] The round trip → byte-identical over **every** accepted machine; record the accepted count.
- [ ] **Task 6 Step 8, by hand** — the raw fixture through its own header command exits **1**;
      with the lie removed, **0**. Paste both transcripts here.
- [ ] Per-pin match count for every pin this slice adds or touches → **1**.

---

## Exit

`§25:1627` — *minimized/reproducible failure fixtures can be saved without external tooling* — is
discharged when:

1. the probe's saved fixture, run through `chez-source.ss` from the tmp directory with the tree's
   library roots, **exits 1**, and **0** once the lie is removed (asserted in the lane by `eval`,
   and once by hand with the command written out — Verification, above);
2. the minimized fixture is strictly smaller and still reproduces;
3. the printer is total over the thirteen node kinds and four matcher kinds by a derived row, and
   the round trip is byte-identical over every accepted machine of the seed set;
4. the fixture imports only what the lane imports;
5. no `src/` file changed.

**Not discharged here, and not claimed:** Slice ④'s corruption catalogue, its independent oracle,
and the milestone close — including `§4.12` items 1–3, whose receiver is Slice ④'s plan by design
§11.
