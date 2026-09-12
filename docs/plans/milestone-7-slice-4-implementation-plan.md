# Milestone 7 — Slice ④ (the corruption catalogue, the independent oracle, and the close) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

Authority: [decision 0033](../decisions/0033-property-suite-contract.md) items 1-2 (Gate 0, PR
#85), then `milestone-7-design.md` §4.5, §4.6, §4.8, §4.11, §4.12 and §9, then the parent plan's
`§25:1617`, `§25:1619` and exit `§25:1625`.

This is the slice `§25:1625` names — *every required diagnostic has positive and negative tests* —
and it is the milestone's last. Slice ② built the generator that draws valid machines; this slice
builds the one that **breaks** them, one decision at a time, and a second implementation of the
verifier's graph rules to disagree with the first. Then it closes Milestone 7: `§25:1615-1627`
dispositioned against the tree, §4.11's seven obligations disposed at both ends, §4.12's three
owner-approved items shipped or declined in writing, and every status surface moved.

Everything below was measured at **`dc3e2b1`** (`main` after the Slice ③ close-out and its
reflection commit), on branch `docs/milestone-7-slice-4-plan`, tree clean, against the configured
`dev` preset. Each finding states the command, the prototype or the `file:line` that produced it.
**Every `src/` and `test/` line number in this plan is stale the moment Task 2 lands**, so every
construct is named as well as numbered, and **Task 1 re-takes the whole census at the slice's own
base before anything is edited.**

Five prototypes were run against this exact tree (**P1**, **P1b**, **P2**, **P3**, **P4**, §1).
They are *throwaways* and are labelled as such: each proves a mechanism or prices a drive, and
nothing about this slice's own code. Every rate, count and timing they produce is re-measured
**through the registered lane** by Task 1 and Task 6.

---

## 1. Thirteen findings that shape the work

### F1 — the independent oracle's `§16.2:885` row can never fire on a free draw, and its `:894` row did not fire in 512

§4.6's drive is "free draws — §4.4's generator with its structural steering off, plus every draw
the property lane rejected", and its acceptance rule is that **each rule fires ≥ 1 and stays
silent ≥ 1 across the draws, or the row is red**. Measured:

**P1** (64 draws, committed seed 20260823, `free-steering`): 3 accepted of 64; the rejection
histogram names exactly nine codes — `eof-reachable-stop` 8, `eof-zero-progress-cycle` 32,
`inconsistent-span-state` 10, `invalid-callback-declaration` 11, `missing-target` 7,
`non-eof-into-finish` 34, `overlapping-cases` 11, `unreachable-node` 5, `zero-progress-cycle` 28.
**P1b** (512 draws, same seed and steering): 54 accepted of 512, and **the same nine codes** —
no tenth appears.

Against §4.6's eight rows that is six rows firing (`:887`/`:905`, `:893`, `:897`, `:898`, `:908`,
`:909`) and **two that do not**: `:885` duplicates and `:894` sequence prefix.

The two negatives are not the same kind of negative, and the plan must not treat them alike:

- **`:885` is impossible by construction, not rare.** A second method (`AGENTS.md`, "a
  load-bearing negative earns a second search method"): `machine-gen.sls`'s `fresh!`
  (`:322-324`) allocates `n0`, `n1`, `n2`, … off a monotone counter, and every declaration name is
  derived from one of them (`w<nm>`, `m<nm>` at `:402`/`:423`). No two nodes, fields, callbacks or
  spans can share a name at any seed or any draw count. The row cannot fire, ever.
- **`:894` is reachable and unobserved.** The sequence-dispatch draw (`:455-465`) takes 1-3 cases
  of 1-3 bytes each, every byte uniform over 0-255, so one case being a proper prefix of another
  has probability on the order of 1/256 per pair. 512 draws produced none.

**Resolution — the drive gains a third source, and §4.6's sentence is corrected in place.** The
oracle runs over **free draws ∪ the property lane's rejected draws ∪ the catalogue's corrupted
machines**. The third source makes every rule fire *by construction*, because the catalogue has an
entry per `§16.2` bullet (§4.5) and those entries are exactly the faults the oracle's rows decide.
It costs no generator change (so no acceptance rate, no PRNG stream and no Pass 39 pin moves), and
it is strictly more material than §4.6 asked for. The alternative — teaching the generator to draw
duplicate names — changes the draw for every lane that shares it and buys one row.

### F2 — every catalogue entry has a base in the committed seed set; none needs synthesizing

§4.5 requires **a count per entry of the machines it applied to, each ≥ 1**, and carries an escape
hatch: "if a seed set still offers an entry no base, Slice ④ synthesizes a span-bearing base and
says so." Measured (**P1**, `property-steering`, committed seed, the 36 accepted machines — the
literal the shipped differential lane already asserts):

| Construct the entry needs | Accepted machines offering it |
|---|---|
| span declaration, callback declaration, uint field, ≥ 2 error declarations | **36 of 36** |
| byte dispatch, pause, error, field-action, field-branch, integer-accumulate, callback node, span-start, span-end | **36 of 36** |
| stop node | **19** |
| finish node | **12** |
| sequence dispatch | **6** |
| counted consume | **6** |

Every family an entry can key on is present in at least six of the thirty-six. **The escape hatch
is not exercised**, and the per-entry floors Task 3 asserts are measured numbers rather than hopes.
The four thin rows (stop, finish, sequence dispatch, counted consume) are the ones whose counts a
generator change would move first, so Task 3 asserts each entry's count ≥ 1 *and* prints the whole
table in the check detail.

### F3 — the corruption mechanism is Slice ③'s printer datum plus `eval`, and it is cheap

§4.5 defines `corrupt` as "a pure function from a machine to a machine differing in exactly one
decision". Slice ③ shipped the substrate: `print-machine` (`machine-print.sls:192`) returns a
datum of `(byte-machine graph)` constructor calls, and `property-fixture-tests.sps:72-73` already
evaluates one in `(environment '(rnrs) '(byte-machine graph))` and verifies the result.

**P2** (committed seed, the first five accepted machines): editing the *one* node form whose own
name slot holds the victim symbol — and nothing else in the datum — then `eval`ing it yields
`duplicate-name` attributed to the donor name on every machine tried, and the **unedited** reprint
still verifies clean. **P3** prices the drive at Slice ④'s scale: 36 machines × 60 edits = **2160
`eval` + `verify-machine` in 0.83 s**.

So the edit kit is datum surgery, not record surgery: it needs no second copy of the thirteen
constructors, it expresses "exactly one decision" as a located substitution, and the entries the
ledger records as **constructor refusals** surface naturally as a raise out of `eval` — which is
the refusal, asserted rather than described (F5). Cost is not a constraint on the entry count.

### F4 — one edit produces collateral diagnostics; the positive is containment and the oracle's exactness is the harder half

Measured (**P2**): renaming node `n2` to `n1` on machine 0 emits `duplicate-name` **and**
`missing-target` (the victim's in-edges now dangle) **and** two `unreachable-node`s; on machine 4,
twelve `unreachable-node`s. §4.5 already anticipates this — the positive half is stated as
*contains* the expected `(code . node)` pairs — and the negative half is stated over the twin,
which is a different machine.

The consequence lands on F1's resolution: §4.6 compares the oracle's `(code . node)` set to the
verifier's **exactly**, per rule, so feeding corrupted machines to the oracle raises the bar on the
oracle rather than lowering it. That is the instrument's value and Task 4 states it in the file: a
rule that agrees on 512 free draws and disagrees on a corrupted machine has found something.

### F5 — the totality sentinel's union, as §4.5 writes it, mixes `§16.2` bullets with diagnostic codes

§4.5: "the union of every entry's expected codes, the constructor-refusal list (`§16.2:895`,
`:896`, `:906`, the width/initial/operation/base halves of `:889` and `:904`), and the
unconstructible list … **equals** the code set the census derives from `verify.sls`."

`§16.2:895`, `:896` and `:906` name **no diagnostic code at all** — the appendix ledger's own rows
give them a `—` in the code column — so they cannot be members of a union of codes; and `:889`'s
and `:904`'s constructor halves name `invalid-field-operand`, which those bullets' *pass* halves
already contribute as entries. Taken literally the sentence is unsatisfiable; taken loosely it is
satisfied by the entry codes alone, and the refusal list goes unchecked while the row stays green.

**Resolution, two rows instead of one, each with a distinct failure mode:**

1. **The code sentinel.** `(union of every entry's expected codes) ∪ (the unconstructible list's
   codes)` **set-equals** the census's derived code set. The unconstructible list contributes
   exactly `invalid-shape`, for its unsupported-version half (`§9.1:320-322`); its not-a-machine
   half is an entry. A thirty-first code fails this row by name.
2. **The refusal table**, hand-written and keyed by `§16.2` bullet, each row asserted by
   **performing the edit and catching the raise**: `make-byte-dispatch-node` / `make-sequence-dispatch-node`
   without a fallback (`:895`), `make-edge` with a mode outside the closed set (`:896`), a terminal
   given an out-edge (`:906`, no slot to give), and the width / initial / operation / base halves of
   `:889` and `:904`. A refusal that stops refusing is red here, and it is invisible to row 1.

Both rows are the ratchet §4.5 asks for; neither subsumes the other, and the plan says so at the
site (`AGENTS.md`, "a census row is not a check").

### F6 — `free-steering` and the rejection ledger ship unused, and Slice ④ is their first consumer

Measured: `rg -n 'free-steering' --glob '!*.md' .` finds only `machine-gen.sls:103` (the export) and
`:196` (the definition, with Slice ④ named in its comment); `rg -n 'make-rejection\*'` finds only
`property-driver.sls:39` (the export) and `:883` (the definition), inside a block headed
"**8. rejection ledger**" whose comment reads "DEFERRED (0033 item 1 -> Slice ④) … its receiver is
0033 item 1".

So decision 0033 clause 1's "**rejected draws are counted by code and kept**" — which the shipped
differential lane does **not** do (it counts a bare `rejected-count`) — is discharged by *this*
slice's new lane, not by a change to `property-differential-tests.sps`. That matters twice: no pin
of Pass 39 moves, and §4.9's gate stays trivially true for the differential program.

### F7 — "never handed to an executor" is a structural property of the lane, not a runtime check

§4.5 asks that the corrupted machine is never handed to an executor (`§22.6:1297`), "asserted as
the catalogue's driver having no executor in scope". The rejections program's registration simply
does not list `${BYTE_MACHINE_CORE_EMIT}`'s executor libraries in `SOURCES`, so under the AOT lane
the program *cannot* import `(byte-machine interpret)`, `(byte-machine compile)` or
`(byte-machine runtime)` at all. The plan makes that the assertion and adds the in-program half
that a reader can check: the program's own `import` form names none of the three, stated in the
header with the `SOURCES` list it mirrors.

This is also why §4.12 item 2's `compile-file` witness is **its own program and its own lane pair**
(Task 8) rather than a group inside the rejections program: it needs exactly the three libraries
the rejections lane must not have.

### F8 — §9's close-out search is stale at this base

§9 requires, at the close, that "`rg -n -i 'milestone 7' src/` prints exactly the lines of
`pass-reachability`'s corrected note, quoted in the plan, and no line containing `owed` or
`failing that`". Measured at `dc3e2b1`:

```
src/byte-machine/verify.sls:31:  ;; §16.4:937-943's seven fields in nine slots (decision 0032 item 1, Milestone 7
```

**One line, and it is not `pass-reachability`'s.** Slice ⓪ rewrote that note without naming the
milestone (`verify.sls`'s `pass-reachability` at `:681` and its surrounding comment cite decisions
0031/0027, not "Milestone 7"), and Slice ① added this one — a *provenance* note on the diagnostic
record, naming a decision, not a receiver. Separately, `rg -n -i 'owed|failing that' src/` prints
five lines (`compile.sls:351`, `:376`, `interpret.sls:431`, `runtime.sls:541`,
`private/names.sls:12`), none of which names Milestone 7; the first three are §4.11 item 7's
receivers, which §10 puts **out** of this milestone by name.

**The close-out check is restated** (Task 10): the search prints exactly the one `verify.sls` line,
quoted; that line names a decision and not a receiver; and no line naming Milestone 7 contains
`owed` or `failing that`. Design §9's sentence is corrected in place with the measurement.

### F9 — §4.12 item 3's comment has two candidate sites; one is right and the other is also illegal

`reserved-member-1` exists **twice**: `verify.sls:109`, feeding `valid-name?` (`:112`) — which
`pass-names-valid` applies to declared **names**, member 1 alone — and `compile.sls:41`, feeding
`valid-binding?` (`:122`) — which `render-machine` applies to the output **binding**, against all
three members.

§4.12 item 3 keeps the exclusion **on declared names** and records that it has no warrant, so its
comment belongs at `verify.sls`'s `valid-name?`. That is also the only one of the two §4.9's gate
permits (`git diff … -- src/ ':!src/byte-machine/verify.sls'`). A comment at `compile.sls:41`
would break the gate *and* state the false reason §3.2 item 3 exists to prevent — `:910`'s actual
enforcement is `valid-binding?`, and item 3's check is not `:910`'s.

### F10 — the `:910` witness's totality target is thirteen emitter arms, and `compile-tests.sps`'s lane has neither the generator nor the printer

§9 places the witness in `compile-tests.sps`; §4.8 asks it to be "total over a machine that declares
every construct — the printer's round-trip fixture", which is a *property-lane* object. Measured:
the compile lane's `SOURCES` are `${BYTE_MACHINE_HARNESS_MANIFEST}`, `${BYTE_MACHINE_CORE_COMPILE}`
and the program (`test/CMakeLists.txt:920-935`) — no `machine-gen.sls`, no `machine-print.sls`.
And `render-state-arm` (`compile.sls:285`) dispatches on **thirteen** `normal-state-kind` keys:
`stop`, `error`, `finish`, `pause`, `accumulate`, `field-action`, `field-branch`, `callback`,
`span-start`, `span-end`, `span-completion`, `counted-consume`, `dispatch`.

**Resolution:** the witness stays where §9 puts it, over a **hand-built every-construct machine** in
`compile-tests.sps`'s own style (the file already builds `cc-witness` at `:302` and reads its
rendered text back as a datum for `§25:1607`'s structural witness at `:312`/`:330`), and its totality is proved by a **derived row** on the census technique: the
thirteen arm keys are read out of `compile.sls` **as a datum** and compared against the arms the
witness's rendered text actually exercises. No lane manifest changes, and a fourteenth arm added to
the emitter reddens the row rather than passing silently.

### F11 — §3.1's negative-side accounting has drifted, and the number `§25:1625` is measured against has not

Re-measured at `dc3e2b1` over `test/common/`:

| §3.1's figure (at `5ac363a`) | At this base |
|---|---|
| nineteen `(not (memq '` forms, eighteen naming codes over six codes | **19 / 18 / 6** — unchanged (`unreachable-node` 4, `eof-reachable-stop` 4, `zero-progress-cycle` 3, `non-eof-into-finish` 3, `eof-zero-progress-cycle` 3, `invalid-field-operand` 1) |
| thirteen checks labelled "no diagnostics" | **17 lines** carrying the phrase |
| 144 `(verify-machine` call sites | **155** |
| twenty-four codes with no negative that names them | **24** — unchanged (30 − 6) |

The two moved figures are collateral (Slices ⓪-③ added fixtures); the figure the exit criterion is
measured against — twenty-four of thirty codes with no negative naming them — is unchanged, and it
is what the catalogue's negative half closes. §3.1 is annotated in place at Task 10 with the
re-measurement, never rewritten.

### F12 — the appendix ledger re-run is clean, so Slice ④ works it as written

§11 instructs: "**Re-run the appendix's ledger over `verify.sls` and the census before writing
Slice ④'s plan**: a code the census derives and the ledger lacks is the finding, and the ledger is
corrected in place." Done at this base:

- the census's `pinned-sites` (`diagnostic-census-tests.sps:117`) yields **30 codes summing to 56
  sites**;
- **every one of the thirty appears in an appendix row** (the loop in Task 1 Step 5 prints nothing);
- the only code-shaped tokens in the appendix that are *not* census codes are pass names,
  constructors and accessors (`pass-schema`, `make-edge`, `node-out-targets`, `matcher-bytes`, …),
  plus `invalid-output-binding`, which the `:910` row itself labels "a contract condition, not a
  code".

**The ledger needs no correction before the catalogue is built.** It is still an instruction: a row
Task 2 cannot follow is corrected in place, in the same commit as the entry that could not follow it.

### F13 — the rejection ledger lives in an executor-bound library, so F6 and F7 collide, and one small library resolves them

F6 names `property-driver.sls`'s ledger as the thing Slice ④ consumes; F7 requires the rejections
program to have **no executor in scope**. Measured: `property-driver.sls:45-58` imports
`(byte-machine interpret)`, `(byte-machine compile)` and `(byte-machine runtime)` — it *runs* the
differential, so it is executor-bound by construction. A rejections lane whose `SOURCES` carry the
driver therefore carries all three executors, and F7's structural assertion is gone.

**Resolution:** the ledger moves to a new, executor-free
`(byte-machine test rejection-ledger)` — the record, `make-rejection*` and its accessors — which
`property-driver.sls` imports and **re-exports**, so the driver's export list is unchanged and
nothing that reads it moves. The rejections program imports the small library directly and never
mentions the driver. One body, two consumers, on the `error-projection` precedent the driver's own
header cites ("eight local copies … is eight places for it to drift").

Two costs, both stated: `property-driver.sls` is a **pinned** file (Pass 59 mutations 2 and 3), so
Task 9 Step 5's two-direction sweep must confirm both `FIND`s still anchor — they sit in
`fixture-text` and the minimizer's fail-oracle, neither of which this move touches; and
`property-differential-tests.sps`'s lane gains the new library in `SOURCES`, which means the
configure-time fingerprint reconfigure (Global Constraints) applies to **both** property lanes.

**Also measured, so the plan does not trip on it:** a lane named
`byte-machine.verify.rejections.chez.source` **already exists** (`test/CMakeLists.txt:788`, running
`verify-tests.sps`). §4.10's allocation for this slice is `byte-machine.property.rejections.chez.*`,
which does not collide — but no new check label may share a run of words with that lane's labels,
and Task 9 Step 7's audit covers it.

---

## 2. What this slice ships

**One source commit and one documentation commit, one PR** — design §11's allocation for ③ and ④,
unchanged. The source commit carries every pin it creates and the `EXPECTED_MUTATIONS` arithmetic
(Milestone 6 §9's partition rule: a commit that adds pins without moving the total, or rewrites a
pinned file without its pins, is red by construction and is not scheduled).

- **`(byte-machine test machine-corrupt)`**, new test-support library: §4.5's entry record
  `(name bullet applies? corrupt twin expected)`, the datum edit kit over `print-machine`'s datum
  (F3), the **hand-written entry table** keyed by `§16.2` bullet, and the **hand-written refusal
  table** (F5 row 2). A functional core (F18's rule, as `machine-gen` and `machine-print` are): it
  returns machines and datums and asserts nothing.
- **`(byte-machine test verify-oracle)`**, new test-support library: §4.6's eight rules, each
  written from the plan's sentence and the decision record it cites — never from `verify.sls` — over
  `(byte-machine private ir)`'s accessors; the **hand-written rule table**; per-rule
  `(code . node)` sets. `§16.2:893`'s row computes byte sets from the four matcher accessors and
  **never from `matcher-bytes`** (§4.6, pinned at Task 9).
- **`(byte-machine test rejection-ledger)`**, new test-support library (F13): the rejection record
  and `make-rejection*`, moved out of the executor-bound driver so an executor-free lane can read
  it; `property-driver.sls` imports and re-exports it, its own export list unchanged.
- **`test/common/property-rejections-tests.sps`**, new, registered in both lanes as
  `byte-machine.property.rejections.chez.{source,aot}` under label `property` (§4.10): the
  catalogue's drive over the seed set's accepted machines — positive by containment, negative over
  the twin, never executed (F7), per-entry application counts, and F5's two totality rows — and the
  independent oracle's drive over free draws ∪ the property lane's rejected draws ∪ the catalogue's
  corrupted machines (F1), per rule, with its own fire and silent counters.
- **The `§16.2:910` structural witness** in `compile-tests.sps` (§4.8, F10): every symbol in
  identifier position in an emitted library, minus the template's own, is exactly the output binding
  and the library name's machine-name element; and every declared name occurring anywhere in the
  datum occurs under `quote` — over a hand-built every-construct machine whose totality is a derived
  row against the emitter's thirteen arms.
- **`test/common/compile-limits-tests.sps`**, new, registered in both lanes (§4.12 item 2, approved
  2026-09-06): the largest emittable machine — every construct at the generator's bounds plus a
  hand-built 256-exact-case dispatch and the same over a complement matcher — rendered, written,
  **`compile-file`d**, loaded, and one feed asserted to agree with the interpreter. **P4** proves the
  mechanism on this tree: an 18 757-byte generated library with 256 exact cases compiles, its object
  loads, and the feed agrees (`(stopped)` both lanes).
- **Pins**: one new mutation pass over the rejections lane and one over the limits lane, plus the
  `:910` witness's pin on the existing compile SPEC, plus the `EXPECTED_PASSES` /
  `EXPECTED_MUTATIONS` arithmetic.
- **The close-out** (documentation commit): `§25:1615-1627`'s scope bullets and three exit criteria
  dispositioned against the tree and appended to the parent plan; §4.11's seven obligations each
  disposed **at both ends**; §4.12 items 1-3 recorded as approved-and-shipped; the design's Exit
  table dispositioned in place; §3.1 and §4.6's drive sentence and §9's close-out search annotated
  with F1, F8 and F11's measurements; `README.org`, `CHANGELOG.md`, the parent's Status line and this
  design's header moved; and the milestone close note.

**What this slice does not ship:** no `src/` change except §4.12 item 3's comment at
`verify.sls`'s `valid-name?` (F9) — §4.9's gate permits exactly that file; no change to
`machine-gen.sls`'s draw (F1's resolution is a third drive source, not a new draw); no change to
`property-differential-tests.sps` or its Pass 39 pins (F6); no pass-7 lattice, EOF verdict tiers,
declaration cross-references or field arithmetic in the independent oracle (§4.6 states why each is
outside an honest second implementation's scope; the catalogue covers them by edit); and `§25:1590`
does **not** become a universal (§4.11 item 6 — the remainder is named in the close note).

---

## Global Constraints

- **Authority order.** Decision 0033 items 1-2, then design §4.5/§4.6/§4.8/§4.11/§4.12/§9, then the
  parent plan. **Where an authority is wrong, stop and say so.** This plan carries **four** such
  findings — F1 (§4.6's drive cannot make two of its own rows fire), F5 (§4.5's totality sentinel
  mixes bullets with codes), F8 (§9's close-out search names a note that no longer exists) and F10
  (§9 and §4.8 disagree about which machine the `:910` witness runs over). **All four are corrected
  in place by Task 10**, with the measurement that forced each.
- **Design §4.9's gate, re-taken at this slice's base, with this slice's one exception.**
  `git diff --stat main..HEAD -- src/ ':!src/byte-machine/verify.sls'` prints **nothing**; the only
  `verify.sls` change is §4.12 item 3's comment at `valid-name?` (F9), and
  `git diff main..HEAD -- src/byte-machine/verify.sls` shows **comment lines only**. Run both at the
  end of every task.
- **No committed golden and no pinned fingerprint literal moves.**
  `git diff --stat main..HEAD -- test/fixtures` prints nothing.
- **The `SOURCES` fingerprint is baked at configure time.** Editing any `.sls` listed in a lane's
  `SOURCES` — both new libraries will be — requires
  `touch test/CMakeLists.txt && cmake --preset dev && cmake --build --preset dev` or the lane fails
  `PROVENANCE-ERROR`. This has cost this project two sessions; the mutation lane is immune, which is
  what makes it easy to miss.
- **A number from a throwaway driver describes the driver.** P1-P4 are prototypes. Every rate,
  count and timing they produce is re-measured **through the registered lane** before it is written
  into a comment, a check label or a literal.
- **Prose expectations are not checks.** Every verification step below states an exact literal, an
  exact count, or the exact command whose output is compared — never a described expectation.
- **The verifier is the oracle for validity and nothing else is.** The catalogue's twin "verifies"
  means `verification-ok?` answered `#t`; the oracle's disagreement is a set comparison against
  `verification-diagnostics`. Neither instrument introduces a third notion of validity (§4.7's rule
  for the minimizer, one slice later).
- **A hand-written table is the operand a derived row compares against.** The entry table, the
  refusal table and the rule table are hand-written and exported, exactly as `machine-gen`'s draw
  tables and `machine-print`'s arm tables are (S2/F4). A table read out of the artifact at run time
  would compare the artifact to itself and close nothing.
- **Sentinels read observed values, and every loop carries a literal total and a derived total.**
  The entry loop, the twin loop, the oracle's rule loop and the drive over machines each get both
  (`AGENTS.md`: a counter computed from the test's expectation asserts nothing, and the loop over the
  loops needs one too).
- **Filter for failure, not success.** A "suite complete" line is printed on the way to failing.
  Grep the error signatures and the exit status.
- **Stage before measuring a mutation by hand.** `git checkout --` to undo a hand-applied mutation
  wipes unstaged implementation work. Stage first; treat any reconstruction as untrusted.
- **A pin must resolve exactly once in its own mutant's output.** Before committing any check label
  in a lane that has pins, embed it in every pin's literal core, pick one that shares no run of words
  with any shipped regex, and after the sweep count each pin's matches in its own mutant's output
  (`re.findall`, DOTALL) and require **1**.
- **Re-measure every cross-document `file:line` as the last step before commit**, not while writing.
  A citation into a file this branch edits is stale on arrival and no link check sees it.
- **Run review and audit fan-outs in an isolated worktree**, never the live checkout: a concurrent
  edit invalidates any measurement in flight, and the mutation suite is worst affected because it
  stages the tree.

---

## Task 1 — Re-take every measurement at the slice's own base

Nothing is edited in this task. Its output is the baseline every later claim is measured against,
and three of its steps are instructions §11 addresses to this plan by name.

- [ ] **Step 1 — the gate, before anything.** `git diff --stat dc3e2b1..HEAD -- src/` prints
      nothing (at Task 1 `HEAD` is the base, so this is the empty-diff baseline the later gate
      compares to).
- [ ] **Step 2 — the release suite.** `make test-all` ends with
      `100% tests passed, 0 tests failed out of 116`. Measured at `dc3e2b1`: **116/116**, total
      262.80 s.
- [ ] **Step 3 — the mutation totals.** `rg -n 'EXPECTED_PASSES|EXPECTED_MUTATIONS' test/support/cmake/SchemeMutationSuite.cmake`
      prints `set(EXPECTED_PASSES 59)` and `set(EXPECTED_MUTATIONS 561)`. The suite asserts these
      against its own accumulated totals, so Step 2 passing *is* the measurement that 59/561 hold.
- [ ] **Step 4 — the census.** Extract `pinned-sites` from `diagnostic-census-tests.sps` and count:
      **30 rows**, site total **56**. The rows and the total are asserted separately in the census
      itself, which is why both are re-taken here.
- [ ] **Step 5 — the appendix ledger re-run (§11's instruction).** For each of the thirty census
      codes, assert it occurs in the design's appendix table; then list the code-shaped tokens in
      that table which are *not* census codes. Expected: **the first loop prints nothing**, and the
      second prints only pass names, constructors, accessors and `invalid-output-binding` (F12). A
      code the census derives and the ledger lacks is the finding, and the ledger is corrected in
      place — in the commit that finds it.
- [ ] **Step 6 — §3.1's negative-side accounting.** Over `test/common/`:
      `rg -c "\(not \(memq '" test/common/verify-tests.sps` → **19**; the code histogram →
      `unreachable-node 4`, `eof-reachable-stop 4`, `zero-progress-cycle 3`, `non-eof-into-finish 3`,
      `eof-zero-progress-cycle 3`, `invalid-field-operand 1` (the nineteenth form names the node
      `start`); `rg -c 'no diagnostics' test/common/verify-tests.sps` → **17**;
      `rg -o '\(verify-machine\b' test/common | wc -l` → **155**. Twenty-four of thirty codes have
      no negative that names them — the number `§25:1625` is measured against (F11).
- [ ] **Step 7 — the two draws (P1's measurement, re-taken).** Through a scratch program in the
      scratchpad, never in the tree: 64 draws at the committed seed under `property-steering` →
      **36 accepted**; under `free-steering` → **3 accepted of 64** and a rejection histogram naming
      exactly the nine codes of F1. Print the accepted-machine construct availability table of F2
      and keep it: Task 3's per-entry floors are read from it.
- [ ] **Step 8 — the Milestone 7 receivers in `src/`.** `rg -n -i 'milestone 7' src/` prints
      **exactly one line**, `src/byte-machine/verify.sls:31`, and it names decision 0032, not a
      receiver. `rg -n -i 'owed|failing that' src/` prints five lines, none of which names
      Milestone 7 (F8). Quote both outputs into the task's record; Task 10's close-out compares
      against them.
- [ ] **Step 9 — record the base commit** in the plan's own header if it is not `dc3e2b1`, and
      re-run Steps 1-8 if it is not. Every literal in Tasks 2-11 is stated against this base.

---

## Task 2 — The entry record, the edit kit, and the two tables (tests first)

New library `test/support/harness/byte-machine/test/machine-corrupt.sls`, exporting the entry
record, the edit kit, `corruption-entries` and `constructor-refusals`. **Tests first**: Step 1
writes the program's catalogue group against an empty table and watches it fail for the stated
reason; entries land after.

- [ ] **Step 0 — extract the rejection ledger** (F13), before anything else, because it moves a
      **pinned** file and the two property lanes' `SOURCES` with it. New
      `test/support/harness/byte-machine/test/rejection-ledger.sls` holding the record,
      `make-rejection*` and the accessors; `property-driver.sls` imports and **re-exports** them,
      its export list byte-identical; `property-differential-tests.sps`'s two registrations and the
      fixture lane's two gain the library in `SOURCES`. Then
      `touch test/CMakeLists.txt && cmake --preset dev && cmake --build --preset dev`, run the four
      property lanes green, and run the **mutation suite** — Pass 59's two driver mutations must
      still anchor (`59 passes / 561 mutations`, unchanged at this point). A `FIND` that stopped
      anchoring is re-anchored here, in this commit, not later. `property-driver.sls`'s
      "**8. rejection ledger**" comment (`:876-881`) — which says the block is deferred to Slice ④
      and names 0033 item 1 as its receiver — is corrected at the site to say where the ledger now
      lives and who reads it.
- [ ] **Step 1 — the failing shape.** In `property-rejections-tests.sps` (created here, completed
      in Task 5), assert F5 row 1 — the union of the entry table's expected codes plus the
      unconstructible list set-equals the census's derived code set — with `corruption-entries`
      empty. Expected failure, verbatim in the task's record: the row names the thirty codes it did
      not find. This is the red that proves the row can fail.
- [ ] **Step 2 — the entry record.** `(define-record-type corruption-entry (fields name bullet
      applies? corrupt twin expected))`, where `applies?` is `machine -> boolean`, `corrupt` and
      `twin` are `machine -> machine`, and `expected` is a list of `(code . node)` pairs **derived
      from the `§16.2` bullet the entry names and written before the run** (§4.5). The record's
      accessors are exported; the table is one `(list (make-corruption-entry …) …)`.
- [ ] **Step 3 — the edit kit** (F3). Pure functions over `print-machine`'s datum: locate the one
      form whose constructor name matches a family and whose operand at a named position equals a
      given literal, and substitute. The kit's contract is *exactly one* substitution per edit; it
      raises when it finds zero or more than one, so an entry that stops locating its site is loud
      rather than silently a no-op. `(eval datum (environment '(rnrs) '(byte-machine graph)))`
      rebuilds the machine — the same environment `property-fixture-tests.sps:72` already uses.
- [ ] **Step 4 — the entry table**, worked from the appendix ledger row by row, in ledger order.
      One or more entries per bullet; each entry names its bullet, its `applies?` and its twin. The
      ledger's "Catalogue entry (④)" column is the specification for each row's *edit*; the
      "Code(s)" column is the specification for its `expected`. A row Task 2 cannot follow is
      corrected in the ledger in this commit (§11: the table is an instruction).
- [ ] **Step 5 — the twins** (§4.5, "an entry has two edits, not one"). Each entry's twin is the
      closest **legal** shape: it verifies, and its diagnostics do not contain the entry's code.
      The design fixes three by name and they are built as written — `:897`: `Z` also reachable by a
      byte edge from the entry; `:908`: the EOF-only byte edge into a finish that has another route;
      `:909`: the one-shot "length, body, stop" grammar. A twin that will not verify is a finding
      about the entry, not a licence to drop the twin: record it and re-shape the edit.
- [ ] **Step 6 — the refusal table** (F5 row 2). Hand-written, keyed by `§16.2` bullet, each row a
      thunk performing the refused construction. Rows: `:895` (byte dispatch and sequence dispatch
      built without a fallback), `:896` (`make-edge` with a mode outside the closed set), `:906` (a
      terminal given an out-edge — recorded with the reason "no slot", since there is no constructor
      call to make), `:889`'s width / initial / operation halves and `:904`'s base half. Each row
      asserted by catching the raise in Task 3.
- [ ] **Step 7 — the unconstructible list.** One row: `invalid-shape`'s unsupported-version half
      (`§9.1:320-322`), with the note that `verify-tests.sps` forges one with a test-only vector and
      this table does not. Its not-a-machine half is an **entry**, driven as the census drives it.
- [ ] **Step 8 — green.** Step 1's row now passes by set-equality, and the entry-count literal and
      the derived total both hold. Run the gate.

---

## Task 3 — The catalogue's drive: positive, negative, never executed, and the two totality rows

In `property-rejections-tests.sps`. The drive is the program's (the imperative shell); the entries
and the kit are the library's (the functional core).

- [ ] **Step 1 — the base set.** Draw 64 machines at the committed seed under `property-steering`,
      keep the accepted ones; assert the count is **36** and that it equals the differential lane's
      own literal, so the two programs cannot drift apart silently. A machine-loop sentinel reads
      the observed draw count, not the expectation.
- [ ] **Step 2 — the positive half.** For every accepted machine and every applicable entry: the
      corrupted machine's `(code . node)` pairs **contain** the entry's `expected` pairs. Collateral
      diagnostics are expected and are not compared (F4). One check per entry, its label naming the
      entry and its bullet — never one check per machine, or thirty-odd entries would produce
      thousands of records and no pin could resolve once.
- [ ] **Step 3 — the negative half** (`§25:1625`'s missing half, and `AGENTS.md`'s attribution
      check). For every accepted machine and every applicable entry: the **twin verifies**, and its
      diagnostics **do not contain** the entry's code. One check per entry.
- [ ] **Step 4 — never executed** (F7, `§22.6:1297`). The program imports no executor; state it in
      the header beside the `SOURCES` list it mirrors, and assert structurally that the drive's only
      consumer of a corrupted machine is `verify-machine` — the corrupted machines are counted, and
      the count of machines handed to any executor is **0** by the program having none in scope.
- [ ] **Step 5 — the per-entry application counts.** A counter per entry, incremented from the
      observed `applies?` answer. Every entry's count is **≥ 1** (F2 measured the floors: 36 for
      most families, 19 stop, 12 finish, 6 sequence dispatch, 6 counted consume); the whole table is
      printed in the check detail so a count that collapses is legible without a re-run. An entry
      that never applied is a red row, not a skipped one.
- [ ] **Step 6 — F5 row 1, the code sentinel.** `(union of every entry's expected codes) ∪
      {invalid-shape}` set-equals the census's derived code set, read from `verify.sls` as a datum by
      this program's own reader (the census's `defined-list`/walk shape, replicated as
      `property-differential-tests.sps` replicates it — these are programs, not libraries). Both the
      set-equality and the count literal **30**, neither catching the other.
- [ ] **Step 7 — F5 row 2, the refusal table.** Each refusal row's thunk raises, and the raise is
      caught and identified — the condition's `who` or its message, asserted, never a bare "it
      raised". The `:906` row has no thunk and is asserted by its recorded reason plus the absence
      of a slot in `ir.sls`'s terminal constructors, read as a datum.
- [ ] **Step 8 — the drive's own sentinels.** The entry loop carries a literal count and a derived
      total; the machine loop likewise; and one check asserts that the number of `(machine, entry)`
      pairs actually driven equals the sum of the per-entry counts. The three do not catch each
      other, which is why all three are here.

---

## Task 4 — The independent oracle: eight rules, written from the sentence

New library `test/support/harness/byte-machine/test/verify-oracle.sls`. **Each rule is written
from the plan's sentence and the decision record it cites, with `verify.sls` closed.** A decision
record is a commitment the oracle may read; the implementation is not (§4.6).

- [ ] **Step 1 — the rule table**, hand-written and exported, one row per §4.6 rule:

      | Row | Written from | Compared code(s) | Comparison |
      |---|---|---|---|
      | `:885` duplicates | equality over each table's names | `duplicate-name`, `duplicate-error-declaration`, `duplicate-callback-declaration`, `duplicate-span-declaration` | exact |
      | `:885` (non-duplicate arms) | as above | `invalid-field-declaration`, `duplicate-branch-key` | containment (oracle ⊆ verifier) |
      | `:887`/`:905` resolution | every target names a node | `missing-target` | exact |
      | `:893` overlap | byte sets from the **four matcher accessors** — never `matcher-bytes` | `overlapping-cases` | exact |
      | `:894` prefix | one alternative a prefix of another | `ambiguous-sequence-prefix` | exact |
      | `:897` unreachable | an independent walk implementing decision 0027 item 1's sentence | `unreachable-node` | exact |
      | `:908` byte edge into a finish | a byte-edge walk from the entry, the entry itself included (0023 item 2), reported at the source node (0023 item 4) | `non-eof-into-finish` | exact |
      | `:909` EOF path to a stop | the EOF walk from 0023 item 3's parked set, each start at `parked-eof-start`'s answer (0023's 2026-09-06 note; 0030 item 6), under 0023 item 5's tiers | `eof-reachable-stop`, `eof-zero-progress-cycle` | exact, **jointly per start** |
      | `:898` zero-progress | the edge rule the tree records as a deliberate over-rejection of `§11.4:654` — reexecute edges, pause continuations, zero-width successors, accumulate overflow edges, counted `next` (0030 item 7); digit edges excluded (`§10.6:566`); byte-reached nodes only (0027 item 3) | `zero-progress-cycle` | exact |

- [ ] **Step 2 — `:898`'s expected answer is equality, and the reason is recorded at the site.**
      The oracle implements the **same** conservative rule the verifier does — a cycle of
      non-consuming edges is rejected whether or not a byte can close it — not because `§11.4:654`
      says so (it quantifies over cycles that *can run* without consuming, and names no edges) but
      because the tree records the edge rule as a deliberate over-rejection at two sites. A
      difference is therefore a finding (§4.6).
- [ ] **Step 3 — what is out of scope, and why, in the file.** Pass 7's lattice (0029 is a
      definition, and a second implementation of a lattice is the lattice); the EOF verdict tiers
      (0023 item 5 — a ranking, not a graph fact); `:890-:892`/`:901-:902`'s declaration
      cross-references (table lookups the catalogue covers exactly); the field operand rules
      (`:889`, `:903`, `:904` — arithmetic on declared widths, covered by the catalogue and
      Milestone 4's matrix). Codes outside the table are **not compared**.
- [ ] **Step 4 — the drive, three sources (F1).** Free draws under `free-steering` at the committed
      seed; every draw the property lane rejected (built through `make-rejection*`, the
      shipped ledger's first consumer — F6 — reached through F13's extracted library); and the catalogue's corrupted machines
      from Task 3. Per machine, per rule, the oracle's `(code . node)` set is compared to the
      verifier's set for that rule's codes under that row's comparison.
- [ ] **Step 5 — the fire and silent counters.** Per rule, two observed counters: the number of
      machines on which the oracle's set was non-empty, and the number on which it was empty. Each
      is asserted **≥ 1**. F1 measured six rows firing on free draws alone; the third source is what
      makes `:885` and `:894` fire at all, and the task records the per-source contribution so a
      later generator change that starts drawing duplicates is visible rather than invisible.
- [ ] **Step 6 — zero differences on the committed seed.** One check per rule: the count of
      machines on which the two sets differed is **0**, its detail naming the first differing
      machine, rule and pair. A difference here is a *finding about the verifier or the oracle* and
      stops the task (`AGENTS.md`: it is the one instrument that can find a defect nobody wrote a
      fixture for).
- [ ] **Step 7 — the loop over the loops.** A sentinel asserting the number of `(machine, rule)`
      comparisons actually performed equals `machines × rules`, read from observed values.

---

## Task 5 — `property-rejections-tests.sps`: the program

- [ ] **Step 1 — the header**, stating: what the program is (§4.5 and §4.6's two instruments in one
      program, on §4.10's lane-name allocation); that it imports **no executor** and why (F7); the
      seed rule (`BYTE_MACHINE_PROPERTY_SEED`, unset legal, malformed loud — `§4.10`'s parsing rule,
      replicated from `property-differential-tests.sps`, with the same `(rnrs)`-has-no-`string-trim`
      note); and `BYTE_MACHINE_SOURCE_ROOT`'s loud-when-unset rule, for the census's reason.
- [ ] **Step 2 — the group layout.** Separate `harness-group`s with distinct labels for the
      catalogue's positives, the catalogue's negatives, the refusal table, the totality rows, and
      the oracle — so a pin can assert a failure *signature* rather than a bare nonzero exit, and no
      label is a substring of another (the label audit is Task 9 Step 3).
- [ ] **Step 3 — the seed is printed once** at the suite's start, as the differential lane prints
      it, and every machine-level check label carries `(seed N)` (decision 0033 item 3).
- [ ] **Step 4 — run it under `ctest` in both lanes** and record the counts: checks, cases, and the
      wall clock per lane. These are the numbers Task 6's `TIMEOUT` is set from — **not** copied
      from the differential lane's 180 (Slice ③'s registration comment makes exactly this point).

---

## Task 6 — CMake: two registrations and a measured timeout

- [ ] **Step 1 — the two registrations**, `byte-machine.property.rejections.chez.source` and
      `.aot`, on the fixture lane's shape (`test/CMakeLists.txt:1652-1680`): `SOURCES` =
      `${BYTE_MACHINE_HARNESS_MANIFEST}`, `prng.sls`, `machine-gen.sls`, `machine-print.sls`,
      `rejection-ledger.sls`, `machine-corrupt.sls`, `verify-oracle.sls`,
      **`${BYTE_MACHINE_CORE_VERIFY}`** — `test/CMakeLists.txt:783-785`, which is `CORE_GRAPH` plus
      `verify.sls` and **no executor** — and the program; **not** `${BYTE_MACHINE_CORE_EMIT}` and
      **not** `property-driver.sls` (F7, F13); `ENVIRONMENT BYTE_MACHINE_SOURCE_ROOT=${CMAKE_SOURCE_DIR}/src`
      and `BYTE_MACHINE_HARNESS_ROOT` (Task 9 Step 3).
- [ ] **Step 2 — the executor-free manifest is the assertion.** Write the `SOURCES` list so that
      `(byte-machine interpret)`, `(byte-machine compile)` and `(byte-machine runtime)` are absent,
      and state in a comment that the AOT lane's static-import closure is what makes it enforceable.
      Verify by running the AOT lane.
- [ ] **Step 3 — the timeout, measured.** Set `TIMEOUT` from Task 5 Step 4's measured wall clock
      plus a wide margin, and write the measurement into the comment beside it. **P3** prices the
      catalogue's own arithmetic at 0.83 s for 2160 `eval` + `verify` on this machine, so the drive
      is not expected to be the cost; the oracle's three sources and the AOT lane's build are.
- [ ] **Step 4 — the fingerprint.** All three new libraries are in a lane's `SOURCES`, and F13's
      move puts `rejection-ledger.sls` into the **differential** lane's `SOURCES` too, so
      `touch test/CMakeLists.txt && cmake --preset dev && cmake --build --preset dev` after every
      edit to either, or the lane fails `PROVENANCE-ERROR`.
- [ ] **Step 5 — the `pr` preset already selects label `property`**; confirm both new lanes appear
      in `ctest --preset pr -N` and in `--preset release -N`, and record the new release total
      (**116 → 118** with these two; **120** after Task 8's pair).

---

## Task 7 — The `§16.2:910` structural witness, in `compile-tests.sps`

§4.8, F10. This is `§25:1617`'s discharge and §4.12 item 1's witness.

- [ ] **Step 1 — the every-construct machine**, hand-built in `compile-tests.sps`'s own style
      beside `cc-witness` (`:302`): every declaration family (uint field, callback, span, error) and
      every node kind, so every one of `render-state-arm`'s thirteen arms contributes its emitted
      text. Named for what it is: the `:910` witness machine.
- [ ] **Step 2 — the derived totality row** (F10). Read `compile.sls` as a datum, find
      `(define (render-state-arm …) …)`, take the `case` keys of its `(case (normal-state-kind s) …)`
      — expected **13**: `stop`, `error`, `finish`, `pause`, `accumulate`, `field-action`,
      `field-branch`, `callback`, `span-start`, `span-end`, `span-completion`, `counted-consume`,
      `dispatch` — and assert that the witness machine's rendered text exercises each. A found-it
      guard first: a reader returning `#f` would compare two empties and pass.
- [ ] **Step 3 — the identifier-position walk.** Read the emitted library as a datum
      (`member3-drift-tests.sps`'s technique) and collect the symbols in **identifier position**.
      Assert that this set, minus the template's own identifiers (`reserved-member-3`, the runtime
      calls, the library form), is **exactly** the output binding and the library name's machine-name
      element — so it contains no declared name.
- [ ] **Step 4 — the quote-position walk.** Separately: every declared name occurring **anywhere**
      in the datum occurs under `quote`. Note in the file why the first draft's shape is wrong
      (§4.8): an occurrence check over *all* declared names fails on any machine declaring an error,
      because error-declaration **names** never reach the emitted text — only their codes and
      reasons do. The walk is therefore over the names that occur, not over the names declared.
- [ ] **Step 5 — §4.12 item 3's comment** (F9), at `verify.sls`'s `valid-name?` (`:112`) and
      nowhere else: `reserved-member-1`'s exclusion on declared **names** is kept, and it has no
      warrant — `§16.2:886` is about portability and `if` is portable; `§16.2:910` is about
      generated identifiers and no declared name becomes one (this witness is the measurement).
      Relaxing it is a verdict change with no consumer. **Comment only**; the gate's `verify.sls`
      diff must show comment lines and nothing else.

---

## Task 8 — `§16.2:911`: the `compile-file` witness (§4.12 item 2, approved)

New program `test/common/compile-limits-tests.sps` and one lane pair. **P4** proved the mechanism
on this tree; this task builds the real witness.

- [ ] **Step 1 — the machine.** Every construct at the generator's bounds, plus a hand-built
      **256-exact-case** dispatch and the same dispatch over a **complement matcher** (§4.12 item 2's
      words). Verify it, compile it, render it, and record the emitted source size — P4 measured
      **18 757 bytes** for the 256-case dispatch alone.
- [ ] **Step 2 — `compile-file`**, under the AOT launcher's conventions (`generate-wpo-files #f`, an
      object beside the source in `BYTE_MACHINE_TEST_TMPDIR`), then `load` the object and
      `(eval 'NAME (environment '(generated NAME)))`. P4: the object loads and
      `compiled-machine?` answers `#t`.
- [ ] **Step 3 — one feed agrees with the interpreter.** P4: `(stopped)` in both lanes. Assert the
      full `parser-result` triple the differential lanes compare, not just the status.
- [ ] **Step 4 — `compile-file` writes a `compiling …` line to stdout.** Measured in P4. Suppress
      it or capture it, and check it against every pin regex in the suite before committing — an
      uncontrolled line in a lane's output is exactly what makes a pin resolve twice.
- [ ] **Step 5 — the disposition's content.** Record **which limits were looked for** —
      `§30:1778`'s identifier length and source size, `case` arity, literal size — and what was
      measured for each. The disposition (Task 10) states that none is reachable by a v0.1 machine,
      **or**, if the witness finds one, `:911` gains a check and a code and this item becomes a slice
      of its own (§4.12 item 2's own escape clause). Do not write the disposition before the
      measurement.
- [ ] **Step 6 — the lane pair**, `byte-machine.compile.limits.chez.{source,aot}`, with a measured
      `TIMEOUT` (this lane compiles a large library twice; it is the slowest thing the slice adds).

---

## Task 9 — The pins, the sweep, and the label audit

§9's pin list, priced and made concrete. **Predicted totals: `EXPECTED_PASSES` 59 → 61,
`EXPECTED_MUTATIONS` 561 → 590.** The prediction is fixed by the measurement in Step 6, never the
other way round.

- [ ] **Step 1 — Pass 60, the rejections lane** (`SPEC byte-machine.property.rejections.chez.source`),
      **25 mutations**:

      | # | Mutation | Caught by |
      |---|---|---|
      | 1-2 | one span-bearing and one non-span entry's `corrupt` made a no-op (returns its argument) | that entry's positive check, by comparison |
      | 3 | one entry's `twin` replaced by its `corrupt` | that entry's negative check |
      | 4 | the code sentinel's union loses the unconstructible list | F5 row 1, naming `invalid-shape` |
      | 5 | one refusal row's thunk made legal | F5 row 2, "no raise" |
      | 6 | an entry's `applies?` made constantly false | its per-entry count, which reads the observed answer |
      | 7 | the oracle's `:893` row reads `matcher-bytes` | the structural census of Step 3 |
      | 8-16 | each of the nine oracle rows made to **never fire** (returns `'()`) | that row's **fire** counter |
      | 17-25 | each of the nine oracle rows made to **always fire** (returns every node) | that row's **silent** counter, and its zero-differences check |

      Mutations 8-25 are one-line `REPLACE`s on a rule's body; the pass is cheap (the suite runs 561
      mutations inside a 262.80 s release run, ≈ 0.36 s each), which is why all eighteen are taken
      rather than a sample. Each `EXPECT_OUTPUT_MATCHES` asserts the **failure signature** — the
      check label and its `expected/got` — never a bare nonzero exit.
- [ ] **Step 2 — Pass 61, the limits lane** (`SPEC byte-machine.compile.limits.chez.source`),
      **2 mutations**: `compile-file` replaced by a plain `load` of the source (caught by the check
      that the object file exists, is non-empty and is what was loaded — **write that check first**,
      or this mutation survives because the feed still agrees); and the interpreter-agreement
      comparison inverted.
- [ ] **Step 3 — the `matcher-bytes` prohibition, made checkable.** §4.6 forbids the `:893` row from
      reading `matcher-bytes`, and **no behavioural pin can witness a violation**: an oracle that
      read `matcher-bytes` would agree with the verifier by construction and every comparison would
      stay green. So the program reads `verify-oracle.sls` **as a datum** (a new
      `BYTE_MACHINE_HARNESS_ROOT` on the two registrations, loud when unset for the census's reason)
      and asserts the symbol `matcher-bytes` occurs **zero** times in it. Mutation 7 is what proves
      that census can fail.
- [ ] **Step 4 — two mutations on the existing compile SPEC** for the `:910` witness. The first is
      §9's named pin: the witness's quote-position walk skips the payload (`(quote #(…))`), so a
      declared name emitted as an identifier inside it would pass — caught by the
      identifier-position check. The second is the stronger one and the defect the witness exists
      for: an **emitter arm rendering a declared name in identifier position** (`FILE
      src/byte-machine/compile.sls`, a `(lit …)`/`(quote …)` wrapper dropped in one
      `render-state-arm` arm) — caught by the identifier-position set no longer being exactly the
      binding and the machine-name element. Both join the existing compile pass rather than opening
      one: it already carries **18** mutations under `SPEC byte-machine.unit.compile.chez.source`
      (`SchemeMutationSuite.cmake:8194` onward), and the precedent for a pass running a program it
      did not open is recorded at `SchemeMutationSuite.cmake:506-515`. A mutation on a `.sps`
      program also has a precedent — `property-differential-tests.sps` at `:8737`.
- [ ] **Step 5 — the two-direction sweep.** Re-anchoring is half the sweep: every shipped pin whose
      `FIND` **or** `REPLACE` names a construct this slice re-contracts is checked against both the
      old and the new mutant. This slice edits no shipped library, so the expected answer is "no
      shipped pin moves" — **measured, not assumed**, because a pin's *observation* can move without
      its `FIND` moving (`AGENTS.md`: a verdict change moves what mutants produce).
- [ ] **Step 6 — the per-pin match-count matrix.** For every new pin, count matches of its regex in
      its **own** mutant's output (`re.findall`, DOTALL) and require exactly **1**; and count matches
      in the green tree's output and require **0**. Print the matrix; a clean diagonal is the
      acceptance criterion (Slice ③ Task 9's shape).
- [ ] **Step 7 — the label audit.** No new check label contains, or is contained by, any shipped
      pin's regex; no new regex uses `.*` between `expected` and `got`, and none ends at `got`
      (`AGENTS.md`: `.` spans newlines in CMake, so `.*` bridges to a later record, and a regex
      ending at `got` is satisfied by every mutant that moves the value). Spell the list; pin the
      measured digest.
- [ ] **Step 8 — reconcile the totals.** `EXPECTED_PASSES` and `EXPECTED_MUTATIONS` moved in the
      **same commit** as the pins, and the suite's own totals assertion is what proves the arithmetic.
      If the measured count differs from 590, the plan's prediction is corrected in the commit that
      measures it.

---

## Task 10 — The close-out: three questions, both ends, and every surface

Milestone 6's §9 asks three questions at a close: which exit criteria are met; which obligations
named this milestone; and **what did this milestone approve that the tree does not contain**. The
third is asked against §4.12 by item number.

- [ ] **Step 1 — `§25:1615-1621`, the seven scope bullets**, each dispositioned against the tree by
      file and case, appended to the parent plan's `## Dated dispositions` section (never inserted
      above it — every `§section:line` citation in the repository navigates by line):

      | Bullet | Met by |
      |---|---|
      | `:1615` generative and diagnostic hardening of all mandatory passes | Slice ⓪ (the reachability narrowing), Slice ① (the record), Slice ④ (the catalogue and the independent oracle) |
      | `:1616` structured graph paths in diagnostics | Slice ① (decision 0032; eight codes carry a path) |
      | `:1617` generated-identifier collision checks | Slice ④'s `§16.2:910` structural witness, and §4.12 item 1's appended disposition |
      | `:1618` bounded valid-machine generator | Slice ② (all thirteen kinds, four matchers, seven operations, seven predicates, four callback kinds) |
      | `:1619` bounded invalid-machine generator | Slice ④, in the two tiers Milestone 5 Slice ⓪'s plan named: the catalogue (tier 1) and the independent oracle (tier 2b, widened from "an independent acyclicity walk" to §4.6's rules) |
      | `:1620` differential property suite | Slice ② (three layers, both lanes), Slice ③ (the fixture and the minimizer) |
      | `:1621` deterministic failure seed reporting | Slice ② (decision 0033 item 3: the environment seed, printed once, carried in every label) |

- [ ] **Step 2 — the three exit criteria**, dispositioned in the design's Exit table **in place**
      and in the parent plan: `:1625` by this slice's catalogue (every code in the census's derived
      set has an entry or a stated reason, positive and negative); `:1626` stated as having held
      **before** the milestone, with what the milestone added under it (two lane pairs in Slice ②/③
      and one or two more here); `:1627` by Slice ③'s probe. Each entry is **dated** and names the
      slice, the file and the case — never reworded to match what shipped.
- [ ] **Step 3 — §4.11's seven obligations, each at both ends.** An "addressed here" with no
      receiver is invisible to every completeness sweep (`AGENTS.md`), so each gets the adjudicating
      sentence **and** a note at the site that named it:

      1. `pass-reachability`'s note and the parent's `§25:1611` hand-off — closed by Slice ⓪; verify
         the annotation is in the tree and re-quote it.
      2. the diagnostic record's widening — closed by Slice ①; decisions 0020 and 0022 carry their
         annotating notes (verify).
      3. the generator's missing draws — closed by Slice ②; Milestone 3's, 5's and 6's deferral
         sites each carry the closing note (verify all three).
      4. the bounded invalid-machine generator — closed **here**; Milestone 5 Slice ⓪'s plan §10 and
         Milestone 5's design §8 get their closing notes, and `differential-span-tests.sps`'s
         topology-table comment ("The bounded invalid-machine generator is Milestone 7's, and this
         must not quietly become it") is **corrected in place** to say what now exists and what the
         table still owns.
      5. `§16.2:911` — no longer an orphan: §4.12 item 2's witness (Task 8) and its appended
         disposition. If the witness found a reachable limit, this item says so and names the slice
         it becomes.
      6. `§25:1590`'s universal — **partly** discharged: the catalogue rejects drawn span faults by
         edit (`:899`, `:900`, `:907` over drawn span-bearing bases — F2 measured 36 of 36 accepted
         machines carry a span), and §4.6 keeps pass 7's lattice outside the independent oracle for
         a stated reason, so "every invalid span topology" is **still not a universal**. The
         remainder is named in §10 and in the close note; the receiver end is the topology table's
         comment (item 4).
      7. not this milestone's — `§12.7:770`'s zero-width-machine-action half and `§9.3:392-393`'s
         `parser-result` enforcement, receivers unchanged. §4.9's gate is what proves this milestone
         touched neither; quote the gate's output.

- [ ] **Step 4 — §4.12's three items, by number** (the third close-out question). Item 1: approved
      and **shipped** — the disposition appended with Task 7's witness named. Item 2: approved and
      **shipped** — the disposition appended with Task 8's measurement, naming which limits were
      looked for. Item 3: approved and **shipped** — the comment at `verify.sls`'s `valid-name?`
      (F9) plus the sentence in the `:910` disposition. Nothing approved is left without a receiver.
- [ ] **Step 5 — the design's corrections, in place, each with its measurement** (Global
      Constraints' four findings): §4.6's drive sentence gains F1's third source and the measured
      reason; §4.5's totality sentence is re-stated as F5's two rows; §9's close-out search is
      re-stated per F8 with the one line quoted; §4.8/§9's "the printer's round-trip fixture" is
      re-stated per F10 as the hand-built every-construct machine with its derived arm row; and §3.1
      is annotated with F11's re-measurement. Corrections **annotate**, never rewrite, anything that
      is a record.
- [ ] **Step 6 — the four status surfaces**, all four, in this order so none is forgotten (the
      closing ritual names three and `README.org` is the one that drifted through three closed
      milestones): the parent plan's `Status:` line; this design's `**Status:**` header;
      `CHANGELOG.md`'s `[Unreleased]` paragraph; and `README.org`'s milestone narrative. Each states
      Milestone 7 **closed**, its date, and the slice that closed it.
- [ ] **Step 7 — the close note**, as a dated disposition (Milestones 4, 5 and 6's shape, not a §25
      subsection), carrying: what each slice delivered; the measured totals at the close (release,
      mutation passes/mutations, census codes/sites); the three questions and their answers; and the
      two obligations this milestone hands **on** (§4.11 item 7's pair), with their receivers.
- [ ] **Step 8 — the citation sweep, last.** Re-measure every cross-document `file:line` this
      commit writes, after the last edit to the files they point into. A citation into a file this
      branch edits is stale on arrival and no link check sees it.

---

## Task 11 — The whole-branch review, and the close

- [ ] **Step 1 — the whole-branch review**, read-only, in an **isolated worktree** (never the live
      checkout: a concurrent edit invalidates any measurement in flight, and the mutation suite is
      worst affected because it stages the tree). The reviewers run every command the plan states.
      Put `AGENTS.md`'s sentence in each prompt **verbatim**: *check what this claims the code or the
      spec DOES against the code and the spec, not against the prose.* The seams between artifacts
      are what a task-scoped review cannot see — every task passing tells you nothing about them.
- [ ] **Step 2 — three review dimensions**, as Slices ①-③ ran them: (a) fidelity to the design and
      to decision 0033, every count re-derived; (b) the mutation surface — every new pin's match
      count, the label audit, the two-direction sweep; (c) the close-out's completeness — every
      obligation's both ends, every §4.12 item's receiver, every status surface.
- [ ] **Step 3 — fold the findings** on the branch, then re-run the full release selection and
      record the totals.
- [ ] **Step 4 — the closing ritual** (`AGENTS.md`): **ask the owner for the go-ahead**, then
      squash-merge the PR yourself, fast-forward local `main`, delete the branch locally and
      remotely, and reflect — durable facts into memory, project standards into `AGENTS.md`, and
      anything the code should say about itself into a comment at the site.
- [ ] **Step 5 — CI.** This PR touches `test/` and CMake, so it gets the `ci` label once the branch
      is final and merges after that run is green — **and it is the PR that can finally discharge
      #88's unverified Chez-build cache** (two runs after a reset prove it; the plan in #88's body).
      If Actions credits are still exhausted, say so explicitly in the PR and carry the obligation
      forward by name rather than silently.

---

## Verification

Run in order. Every expectation is a literal, a count or an exact command's output.

1. **The gate.** `git diff --stat main..HEAD -- src/ ':!src/byte-machine/verify.sls'` prints
   nothing; `git diff main..HEAD -- src/byte-machine/verify.sls` shows **comment lines only**
   (§4.12 item 3, F9); `git diff --stat main..HEAD -- test/fixtures` prints nothing.
2. **The release selection.** `make test-all` → `100% tests passed, 0 tests failed out of 120`
   (116 at the base + 2 rejections lanes + 2 limits lanes).
3. **Both Chez modes.** The source and AOT registrations of both new lane pairs are green with
   identical counters — the `.chez.source`/`.chez.aot` pair is what `§25:1626` is about.
4. **The mutation suite.** `59 → 61` passes and `561 → 590` mutations (or the measured number,
   reconciled in Task 9 Step 8), asserted by the suite against what actually ran.
5. **The catalogue.** Every code in the census's derived set (30) has an entry or a stated reason;
   every entry applied to ≥ 1 accepted machine; every entry's positive and negative both ran. Print
   the per-entry table.
6. **The oracle.** Zero differences on the committed seed; every one of the nine rows fired ≥ 1 and
   stayed silent ≥ 1, with the per-source contribution printed (F1).
7. **The `:910` witness.** The thirteen-arm derived row holds; the identifier-position set is
   exactly the binding and the machine-name element; every declared name that occurs, occurs under
   `quote`.
8. **The `:911` witness.** The object file exists and was loaded; one feed agrees with the
   interpreter on the full `parser-result`; the limits looked for are recorded.
9. **The close-out.** `rg -n -i 'milestone 7' src/` prints exactly the one `verify.sls` line, and
   no line naming Milestone 7 contains `owed` or `failing that` (F8); all four status surfaces say
   **closed**; every §4.11 obligation and every §4.12 item has both ends in the tree.
10. **The citation sweep**, last, after every edit.

---

## Exit

Milestone 7 is closed when:

- `§25:1625` is met by the catalogue — every code in the census's **derived** set has an entry
  whose corrupted machine emits it and whose twin does not, or a stated reason (a constructor
  refusal, or unconstructible through the public API), and the totality row is a ratchet that fails
  by name on a thirty-first code;
- `§25:1619`'s bounded invalid-machine generator exists in **both** tiers, with the independent
  oracle agreeing with the verifier on every drawn, rejected and corrupted machine of the committed
  seed and every rule witnessed both firing and silent;
- `§25:1617` is discharged by the `§16.2:910` structural witness, and `§16.2:911` is no longer an
  orphan;
- `§25:1615-1627` are dispositioned against the tree, §4.11's seven obligations are disposed at
  **both** ends, §4.12's three items are recorded as shipped, and all four status surfaces say so;
- the release selection is green in both Chez modes, the mutation suite's declared totals hold, and
  §4.9's gate prints nothing but §4.12 item 3's comment.
