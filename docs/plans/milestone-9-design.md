# Milestone 9 Design — Cross-platform hardening and the v0.1 release

**Status: draft, Gate 0 not yet discharged.**

Written against **`62671b2`** (`main`, Milestone 8 Slice ⑤ merged as PR #108,
2026-09-12). Every number below was measured against that commit, in this
checkout, on `tarm64osx` / Chez Scheme 10.4.1 — the one Tier 1 cell that exists
locally. Measurements taken through throwaway prototypes are labelled as such
and are re-taken through the shipped harness by the slice that owns them
(AGENTS.md, "Re-measure against the shipped artifact before a number enters a
doc or record").

Authority, in order: the parent
[implementation plan](./byte-machine-implementation-plan.md) — `§7.3` (the Tier
1 matrix), `§23` (benchmark policy), `§24` (CI and build strategy),
`§25:1651-1665` (this milestone's scope), **`§26:1669-1685` (the fifteen v0.1
release criteria)**, and `§27:1689-1703` (the eleven documentation
deliverables) — then the decision records, then `AGENTS.md`.

This is the **final** milestone. It closes with a tag, not with a hand-off.

---

## 1. Summary

Milestone 9 is the first milestone that ships no mechanism and no grammar. Every
earlier milestone could prove itself inside one process on one machine: a node
kind either executes identically in both lanes or it does not, and the suite
says which. The claim this milestone exists to make — *this generator emits the
same bytes and this parser behaves the same way on four platforms* — is the one
claim that machine cannot make about itself.

So the milestone's shape follows from where the evidence has to come from:

- **Slice ⓪ — the release ledger.** `§26`'s fifteen criteria and `§27`'s eleven
  documents become a *checked* table in the tree, each row naming its witness or
  its receiver, with a totality row that fails when a criterion is added or
  dropped. Nine of the fifteen are already met at `62671b2`; the table records
  which, against the tree, before any of the remaining six is worked. The
  version surface — the single place `0.1.0` is written — and the license and
  header review (`§25:1662`) land here too, because both are questions about
  what the repository *says*, and the ledger is the artefact that says it.
- **Slice ① — platform neutrality, and the cross-cell argument made total.**
  Everything that can be settled without spending a runner minute: the
  build layer's remaining POSIX-shaped text, the Windows cell's open questions
  written down as a dry audit, and the sixth determinism golden — the HTTP
  fixture's, which Milestone 8 Slice ⑤ deferred *to this milestone by name*.
  The golden is the cross-cell mechanism, not a regression convenience (§4.2).
- **Slice ② — Tier 1 CI.** The cells turn on one at a time, under a stated
  minute budget, in ascending order of cost. `#88`'s two-run Chez-cache
  verification — unperformed since 2026-09-07 and carried unpaid through two
  whole milestones — is discharged by the first run.
- **Slice ③ — the benchmark baseline and the allocation audit.**
  `bench/runner` and `bench/fixtures` hold `.gitkeep` and nothing else.
  `§23.1`'s metric list and `§23.2`'s nine workloads become a runner and a
  committed baseline artefact; `§26:1680`'s allocation claim becomes an asserted
  lane with a live control (§4.3).
- **Slice ④ — examples and the documentation set.** `examples/` holds
  `.gitkeep`; `docs/reference/` holds one of `§27`'s eleven. This slice ships
  the rest and the README quick start.
- **Slice ⑤ — the release.** The generated-source readability review
  (`§25:1659`), the `0.1.0` CHANGELOG entry and release notes, the
  clean-checkout proof, the five status surfaces, and the tag.

**What does not change:** `src/`. Milestones 7 and 8 each closed without a
single behavioural change under `src/`, and this milestone has no reason to
differ — it measures and documents the mechanism those milestones shipped.
§4.7 makes that a gate every slice asserts, as Milestone 8's §4.7 did, with the
two exceptions §4.7 names in advance rather than discovering.

---

## 2. Why this shape

Three facts about `62671b2` set the order.

**The release criteria are mostly already met, and nobody has said so.**
Dispositioned against the tree (§3.1), nine of `§26`'s fifteen criteria are
met today, one is met-but-unasserted, and five are open. A milestone whose exit
is "all criteria in Section 26 are satisfied" (`§25:1665`) that does not begin
by finding out which ones already are will re-litigate nine settled questions
and under-serve the five real ones. This is the same argument decision `0034`
made for Milestone 8's error table, and it produced the cheapest slice of that
milestone. The ledger is `§26`'s analogue.

**The expensive evidence is expensive for a reason that is not technical.**
`Kiyomi-Computation-Systems/byte-machine` is a **private** repository (measured:
`gh repo view --json isPrivate` → `true`). On a private repository every hosted
runner minute is billed, at the multipliers the project's own CI file already
records — macOS at ten times a Linux minute, and the workflow header explains
that a macOS job plus a source-built Linux job cost "about sixty billed minutes
a run" before the month's minutes ran out on 2026-09-07. CI has been one Linux
job ever since, and every Milestone 7 and Milestone 8 pull request merged with
no `ci` label. `§26:1678` asks for **eight** cells (four platforms × source and
AOT). That is a budget question wearing a portability question's clothes, and
§4.4 puts it in front of the owner before Slice ② spends anything.

**Almost nothing in the tree is actually Unix-shaped.** This was the surprise.
The build layer contains **zero** executed POSIX-only commands (§3.2, measured
two ways). The launcher protocol takes repeated `--library-root` flags
specifically so that no path separator is ever joined, closing the `:`-vs-`;`
question by construction — the Milestone 0 spike says so at `§9`, and
`chez-source.ss`'s header says so at its own site. `.gitattributes` already
normalises the tree to LF and marks every byte-exact fixture `-text`, with a
comment naming `§20` and `§24.2` stage 7 as the reasons. And Chez Scheme 10.4.1
ships a **prebuilt Windows installer** (`ChezScheme10.4.1.exe`, Visual
Studio-built, Intel), so the Windows cell needs no source build — the twelve
minutes the Linux job spends building Chez do not repeat there.

The residual Windows risk is therefore narrow and nameable rather than broad:
discovery (`find_program(NAMES scheme chez chezscheme)` against an installer
that does not put `scheme.exe` on `PATH`) and the AOT object convention. Slice
① writes both down as a dry audit; Slice ② answers them with a runner.

---

## 3. What the tree already settles

### 3.1 The fifteen release criteria, dispositioned against `62671b2`

| `§26` | Criterion | State at `62671b2` | Witness / receiver |
|---|---|---|---|
| :1671 | every approved IR node has documented semantics | **partly** — thirteen node kinds, semantics in parent `§10.6`; no reference document | `§27:1692` → Slice ④ |
| :1672 | verification mandatory; emission cannot bypass it through the public API | **met** | `render-machine` on an unverified value raises `invalid-shape` / "not a machine" (measured here, 2026-09-12, by handing it one); Milestone 7 Slice ④'s catalogue |
| :1673 | interpreter/generated differential tests pass | **met** | 30 `differential` lanes of 137 |
| :1674 | lifecycle, callbacks, spans, fields, offsets, errors, EOF, counted consumption meet this plan | **met** | Milestones 2-6 close notes |
| :1675 | the private HTTP fixture meets its required behavior | **met** | Milestone 8 close; `§25:1646` dispositioned in the Slice ⑤ note |
| :1676 | representative fixture inputs pass every split point | **met** | Milestone 8 Slice ⑤; `§4.9` item 3 (pipelining at *every* split) declined by measurement, seeded subset stated as the fallback |
| :1677 | deterministic generation passes across supported platform cells | **open** | one platform runs; five goldens compare, the sixth is missing → Slices ①, ② |
| :1678 | every Tier 1 matrix cell passes source, generation, AOT and execution checks | **open** | 1 platform of 4; 2 cells of 8 → Slice ② |
| :1679 | compiled benchmark baselines recorded without speculative optimization | **open** | `bench/` holds two `.gitkeep` files → Slice ③ |
| :1680 | no deliberate per-byte construction in generated paths; fixnum-sized allocation measured with callbacks disabled | **true but unasserted** — measured 0.0 bytes per input byte (§3.3 P2) | no lane asserts it → Slice ③ |
| :1681 | public library and generated-runtime dependency boundaries documented | **partly** — parent `§7.2` carries the diagram; no reference document | `§27:1697` → Slice ④ |
| :1682 | examples generate, compile, and run from a clean checkout | **open** — `examples/` holds `.gitkeep`; `§9.6`'s example is a *test lane* (§3.2) | Slice ④ |
| :1683 | `README.org` explains scope and quick start | **partly** — scope yes; "Building and testing" builds *the repository*, not a machine | Slice ④ |
| :1684 | `CHANGELOG.md` contains the `0.1.0` entry | **open** | Slice ⑤ |
| :1685 | no native build artifacts or unrelated HTTP/server code committed | **met** | `git ls-files` matching `\.(so|o|a|dylib|dll|exe|obj|lib)$` is **empty**; every HTTP path is under `test/` or `docs/`, and `byte-machine.unit.http-leak` asserts the fixture is not re-exported |

Nine met, three partly, one true-but-unasserted, five open (:1677 and :1678
share Slice ②'s work but are separate criteria and get separate rows).

`§27`'s eleven documentation deliverables, same treatment: **one** exists
(`docs/reference/callback-span-lifetime.md`, :1694) and one is the changelog
(:1701, exists but wants its `0.1.0` entry). The other nine do not exist. The
portability matrix (:1700) has most of its content already written, in
`milestone-0-ci-feasibility.md` and `milestone-0-portability-spike.md` — but
those are *plans*, and a plan is not a reference; Slice ④ decides whether :1700
is a new document or a pointer, and the ledger records which.

### 3.2 Where the spec and the tree already disagree

Four disagreements, each of which the milestone must disposition rather than
quietly satisfy or quietly ignore.

1. **`§8`'s layout puts examples under `examples/generate-simple-machine/`; the
   tree's only example is a test.** `§9.6:446-459` names eight things Milestone
   1 must demonstrate end to end, and `test/common/example-one-byte-tests.sps`
   demonstrates all eight in two lanes
   (`byte-machine.example.one-byte.chez.{source,aot}`), importing only
   `(byte-machine graph)`, `verify`, `compile`, `runtime` and the harness. So
   `§9.6` is **discharged**; what is not discharged is `§26:1682` — "examples
   generate, compile, and run **from a clean checkout**" — which a lane inside
   the suite cannot witness, because it runs under the harness, with library
   roots the build layer sets. Slice ④ owns the difference and the ledger states
   it in these terms, so that "we have an example" is never mistaken for "the
   criterion is met".

2. **`§24.3:1409` says v0.1 should generate fixture source during tests by
   default, and commit it "only if a later workflow demonstrates that review
   value outweighs stale-artifact risk". Five goldens are committed.** The later
   workflow exists and is exactly the determinism lane: a committed golden is
   how cross-cell equality is proved transitively (§4.2). The tension is real
   and is resolved *in favour of committing*, with the reason recorded — and
   Slice ① adds the sixth. `§24.3` is not reworded; the ledger records that the
   tree meets its condition rather than its default, which is the disposition
   Milestone 8 used for `§21.7:1209`.

3. **`README.org`'s footer says "all rights reserved"; `LICENSE` is BSD
   3-Clause.** Both are in the tree at `62671b2`. `§25:1662`'s "license/header
   review" is precisely this: which statement governs, whether `src/` files
   carry a copyright header at all (they carry descriptive headers and no
   copyright line), and what a v0.1 tarball asserts. Slice ⓪.

4. **`README.org`'s Documentation list stops at the Milestone 5 design.**
   Milestones 6, 7 and 8 closed without being added. This is the fifth status
   surface AGENTS.md warns about — "a document no step names is a document
   nobody updates" — appearing again inside the document that lesson was
   written about. Slice ⓪ folds the list into the ledger so that the release's
   own close cannot miss it.

### 3.3 Four prototypes, run against this exact tree

Each is a throwaway driver in the session scratchpad, run against `62671b2`
with `chez --libdirs src:test/support/harness`. Every number here is re-taken
through the shipped harness by the slice named.

**P1 — the build layer's POSIX exposure, measured two ways.** A sweep for
`execute_process`/`COMMAND` arguments naming `/bin/`, `.sh`, `sh -c`, `bash`,
`powershell` or `cmd.exe` across every `.cmake` and `CMakeLists.txt` outside
`build/` returns **six** hits, all the literal string `/bin/true`, in two files
(`ByteMachineExpectExitSpec.cmake` ×5, `ByteMachineTestingSpec.cmake` ×1). A
second pass — reading each of the six at its site rather than counting them —
shows **none of the six is ever executed**: three sit in `spec_expect_all_rejected`
cases whose whole point is that registration is *refused* before any command
runs, one is in a `WORKING_DIRECTORY`-absent rejection, and the remaining two
are handed to a stubbed registrar that records its arguments into a global
property and returns. A parallel sweep for `file(CHMOD`, `CREATE_LINK`,
`SYMLINK`, `$ENV{HOME}` and `.sh` returns **zero**, and a sweep for `WIN32`,
`MSVC`, `UNIX`, `APPLE` and `CMAKE_SYSTEM_NAME` also returns **zero** — the
build layer has no platform branching at all. **Finding: the tree contains no
executed POSIX-only command.** The six strings are cosmetic and are worth one
line of cleanup for the reader, not a portability slice. *(Counting alone would
have produced "six Windows blockers", which is false; the second method is what
AGENTS.md's "check what this claims the code DOES against the code" asks for,
and a load-bearing negative earning a second search method is the standing
standard.)*

**P2 — the per-byte allocation slope, with a live control.** `§26:1680` and
`§3:66` forbid *deliberate per-byte structural allocation* in generated
dispatch. Measured as a slope, not a budget: two requests differing only in the
length of one header value (70 bytes and 40 070 bytes), 300 messages each,
`(sstats-bytes (statistics))` around the loop, callbacks disabled (`'()`
bindings, which is what `§26:1680` means by "with callbacks disabled"):

| executor | 70-byte message | 40 070-byte message | bytes per input byte |
|---|---|---|---|
| generated | 1 408.75 B | 1 408.75 B | **0.0** |
| interpreted | ~451 162 B | ~721 million B | ~17 900 |
| *control* (a `make-bytevector` of the same size) | — | — | **1.0085** |

The generated figure is not "small"; it is **identical** at the two sizes, to
the byte. Split further: parser construction 400.08 B, the feed itself 1 008.03 B,
both flat in message length. The control exists so that a zero slope is a
measurement that *could* have been nonzero — a sentinel computed from the
expectation asserts nothing. The interpreter's ~17.9 KB per input byte is
linear, not quadratic (checked at 160, 1 060 and 10 060 input bytes: allocation
per input byte 12 954 → 17 253 → 17 937, converging), and it is the whole
explanation of P3's 36.6× ratio. It is not a defect: the reference interpreter
is the semantic oracle and `§18` asks nothing of its performance. It *is* a
number `§23.1:1336` asks to be recorded. Slice ③ re-takes all of this through
the shipped harness and turns the generated row into an assertion.

**P3 — the benchmark metrics `§30` question 5 asks about.** All seven of
`§23.1`'s metric families are collectable in plain Chez with no external tool.
On a 110-byte pipelined-shaped request, `tarm64osx`, Chez 10.4.1:

| metric | generated | interpreted |
|---|---|---|
| requests/second | 167 749 | 4 581 |
| bytes/second | 18 452 351 | — |
| ratio | — | 36.6× slower |

and, for the HTTP fixture itself: `compile-machine` 7.2 ms, emission 7.6 ms,
**generated source 196 682 bytes**, `compile-file` 0.378 s, **object 138 195
bytes**. These are single-run figures from a throwaway driver with no warmup and
no dispersion, which is precisely what `§23.1` forbids a *baseline* from being —
they price the runner, they are not the baseline. Slice ③ ships the runner that
produces the committed artefact with warmup, repetitions, median and dispersion.

**P4 — the Windows cell, priced from the distribution rather than guessed.**
Chez Scheme's v10.4.1 release publishes `ChezScheme10.4.1.exe`, the Windows
binary installer built with Visual Studio for Intel targets, beside the source
tarball. So the Windows amd64 cell installs a prebuilt runtime; it does not
repeat the ~12 minutes the Linux job spends building Chez from source, and it
does not need MSVC in CI. What the installer does *not* obviously do is put
`scheme.exe` on `PATH` under a name `find_program(NAMES scheme chez chezscheme)`
finds — and the repository already ships the escape hatch for exactly that
(`-DBYTE_MACHINE_CHEZ_EXECUTABLE=…`, documented in `README.org` and printed by
`make help`). Two open questions remain, and both are one-line answers from a
runner rather than research: the discovered path, and whether Chez's AOT output
keeps the `.so` extension on `ta6nt`. Slice ① writes them down; Slice ② answers
them.

---

## 4. Gate 0 — the design calls this milestone must resolve

Four decision records (`0038`-`0041`), seven obligations, and three scope
questions for the owner.

### 4.1 Decision 0038 — the release ledger is a checked artefact, and it is first

`§25:1665` makes this milestone's exit "all criteria in Section 26 are
satisfied". Fifteen criteria, spread across five slices, most of them already
true: the failure mode is not missing one, it is *believing* one. AGENTS.md has
the receipts — "a plan step whose expected grep result is *described* gets
reported as passing without being run", and "prose expectations are not checks".

So `§26` and `§27` become data the suite reads, in the shape decision `0034`
gave Milestone 8's error table:

- one row per criterion, keyed on the criterion's **text**, not its line number
  (line numbers move; Milestone 8 learned this at `§21.7:1209`);
- each row carries a *state* (`met`, `open`), a *witness* naming what
  establishes it, and — for the open rows — the slice that receives it;
- **two totality rows**: the ledger's criterion set against `§26`'s fifteen and
  `§27`'s eleven, so that adding or dropping a criterion fails by name;
- rows whose witness is mechanical are *checked* (a lane name that must be
  registered; a `git ls-files` pattern that must match nothing; a file that must
  exist), and rows whose witness is a judgement are marked as such and carry the
  close note's paragraph. A ledger that claimed to check a judgement would be
  the "sentinel computed from the test's own expectation" defect.

The ledger lives with the fixture harness and is read by a lane of its own. It
is **self-ratcheting** — its totality rows fail floor-independently when the
criterion set moves — and so, like Milestone 8's error table, it earns no
mutation-suite entry of its own.

**Recommended: adopt.**

### 4.2 Decision 0039 — cross-cell generation equality is proved transitively, through committed goldens

`§24.2` stage 7 says "Compare generated output across every Tier 1 OS/
architecture cell", and `§22:1314` says the same. Read literally that is a
cross-job artefact-comparison step: every cell uploads its generated bytes, a
final job downloads all of them and diffs. That design needs artefact storage, a
fan-in job, and a failure mode ("cell 3's upload is missing") that has nothing
to do with the generator.

The tree already implements the cheaper and stronger thing, and
`determinism-one-byte-tests.sps`'s own header states the argument **and names
this milestone as its completion**: byte-identity within a process, *plus*
equality to a committed golden that every cell and lane compares against, gives
cross-process, cross-lane and cross-cell identity transitively. The golden is
the fixed point. Five machines are covered (one-byte, pause, http-version,
accumulate, counted); `.gitattributes` marks `test/fixtures/**` `-text` so no
checkout filter can touch the bytes.

**The gap is the HTTP fixture** — the largest machine in the tree at 196 682
generated bytes, exercising more of the emitter than the other five combined —
and Milestone 8 Slice ⑤ deferred its golden **to this milestone by name**, in
the header of `determinism-http-tests.sps`: "the committed-golden-file variant
is DEFERRED … named for a hardening slice or M9". Slice ① adds it.

So: **no cross-job comparison step is built.** `§24.2` stage 7 is satisfied by
every cell running the six determinism lane pairs against the same committed bytes,
and the ledger's row for `§26:1677` says so in those words. This is a
disposition of the spec's *mechanism*, not of its requirement, and it is
recorded as one.

**Recommended: adopt.** The risk it accepts: a golden that drifts stale is a
golden nobody regenerates — mitigated by the lane comparing on every run in
every cell, which is the opposite of stale.

### 4.3 Decision 0040 — the allocation audit is a slope with a control, not a budget

`§26:1680` has two halves: a *prohibition* ("generated per-byte paths contain no
deliberate list/vector/string/result construction") and a *measurement*
("fixnum-sized allocation measurements are recorded with callbacks disabled").
A single absolute number serves neither — it cannot distinguish per-message from
per-byte allocation, and it turns into a threshold nobody can justify, which
`§23.3:1378` explicitly forbids before baselines establish variance.

The audit is therefore a **slope**: the same machine fed two messages differing
only in length, allocation differenced, divided by the byte difference. P2
measures exactly 0.0 for the generated executor, with the per-message intercept
reported separately (400.08 B construction + 1 008.03 B feed). Three properties
make it an assertion rather than an observation:

1. **A live control in the same lane** — a loop allocating a known amount per
   byte, asserted nonzero. Without it, a slope of zero is indistinguishable from
   a measurement that cannot move.
2. **Both executors measured**, with only the generated one asserted. The
   interpreter's ~17 900 B/byte is recorded, not gated: it is the oracle, and
   `§18` asks nothing of its allocation.
3. **Callbacks disabled**, as `§26:1680` words it — `'()` bindings — with the
   callback-bound figure recorded beside it so the difference is visible.

**Recommended: adopt.**

### 4.4 Decision 0041 — Tier 1 cells turn on one at a time, under a stated budget, and a cell that cannot run is a plan amendment

`§7.3:203` is unusually firm: "Every Tier 1 cell is a real release gate. If an
upstream toolchain or runner makes one infeasible, the tier must be changed
through an explicit update to this plan before release; it **cannot be silently
waived in release notes**."

Against that stands the budget (§2): a private repository, billed minutes,
macOS at ×10, a month's minutes already exhausted once, and `#88`'s two-run
cache verification unperformed for two milestones because of it. `§26:1678`
wants eight cells.

The decision is procedural, and it is what keeps `§7.3:203` honest:

- Cells turn on **in ascending cost order**: Linux amd64 (running today, and
  the one that discharges `#88`), Windows amd64 (×2, prebuilt runtime, no source
  build), Linux arm64 (×1 where available on this plan — Slice ② verifies the
  label before relying on it), macOS arm64 (×10, and the platform every slice is
  already measured on locally).
- **Each cell's first run is a single `workflow_dispatch`**, priced and
  recorded, before it is added to the `push`/`ci`-label paths. A cell that
  passes once for a known cost is a decision the owner can make; a matrix that
  fans out on every push is not.
- **A cell that cannot be afforded or cannot be run is an amendment to
  `§7.3:195`**, written as a dated disposition in the parent plan and reflected
  in the ledger's row, *before* the release. Never a sentence in the release
  notes. The ledger's `§26:1678` row is `met` only when every cell in `§7.3`'s
  tier — as amended — has passed.

**Recommended: adopt**, with §4.9 item 1 (the budget itself) going to the owner.

### 4.5 What `0.1.0` is written on — one owner, and the surfaces that mirror it

There is no `0.1.0` anywhere in the tree today. (`current-abi-version` is `5`
in `runtime.sls`; that is the generated-runtime ABI, a different thing with a
different lifecycle, and the ledger says so to stop the two being conflated.)

The version needs **one** owner and a mirror rule, because AGENTS.md's
five-status-surface lesson is about exactly this class of drift. The surfaces
that must carry `0.1.0` at the close: `CHANGELOG.md`'s `0.1.0` entry
(`§26:1684`), `README.org`'s status paragraph, the parent plan's dated
disposition, this design's status header, and the git tag. Slice ⓪ picks the
owner and writes the rule; Slice ⑤ executes it and the ledger checks it.

Whether the version is *also* a value in Scheme — a `(byte-machine version)`
export — is §4.9 item 3.

### 4.6 What this milestone does not inherit

- **`§12.7:770`'s zero-width machine-action half.** Untouched since Milestone
  5, its receivers named at `compile.sls:351` and `interpret.sls:431`, its
  narrowing measured by Milestone 8's P2/P3 (the broken shape needs a *fallible*
  zero-width action reached over a **reexecute** edge, and `§21`'s grammar has
  no producer). This milestone changes no `src/` behaviour and so cannot
  discharge it. It is named in the close as still owed — a v0.1 release with a
  known, recorded, unreachable-in-practice defect is the honest outcome, and
  saying so in the release notes is not the "silent waiver" `§7.3:203` forbids,
  because nothing is being waived: nothing claims it fixed.
- **`§9.3:392-393`'s `parser-result` enforcement.** Same treatment, same
  receiver, unchanged.
- **`§25:1590`'s span-topology universal**, still partial after Milestone 7
  Slice ④, its remainder named there.
- **`§29`'s deferred extensions.** All eleven stay deferred; `§23.3`'s
  admission rule is not met for any of them and this milestone deliberately
  produces the baselines *without* acting on them (`§26:1679`, "without
  speculative optimization"). Slice ③ asserting a 36.6× interpreter gap is not
  an invitation to optimise the interpreter.

### 4.7 The gate every slice asserts

`git diff --stat main..HEAD -- src/` is **empty**, with two exceptions declared
here in advance rather than discovered:

1. **Copyright/licence headers**, if §4.9 item 2 is approved — comment-only, and
   the gate becomes "empty after excluding comment lines", measured the way
   Milestone 7 Slice ④ measured its one-comment exception.
2. **A `(byte-machine version)` export**, if §4.9 item 3 is approved — the only
   case in this milestone where a new public name could appear, which is why it
   is a question for the owner and not a slice's judgement.

Absent those two approvals, the gate is the plain one. Every slice asserts it;
the close proves it over the whole branch.

### 4.8 Obligations addressed to this milestone

Seven, each with both ends named (AGENTS.md: "a deferral with no receiver is
how this project once shipped an unwitnessed function").

1. **`#88`'s two-run Chez-cache CI verification** — unperformed since
   2026-09-07, carried in every Milestone 7 and Milestone 8 close note. Receiver:
   **Slice ②**, discharged by the first pair of runs (cache miss, then hit).
2. **The HTTP determinism golden** — deferred by `determinism-http-tests.sps`'s
   header "to a hardening slice or M9". Receiver: **Slice ①**.
3. **Milestone 0 D2's deferral** — "CI is to cover macOS arm64 + Linux amd64;
   the remaining Tier 1 cells land in Milestone 9", and "cross-cell
   byte-identical comparison (`§24.2` stage 7) is partial until M9 and must be
   labelled as such". Receiver: **Slice ②**, and the label is removed by the
   ledger's `§26:1677` row. *Note the drift this obligation has suffered:* D2
   assumed macOS was in CI, and `#88` removed it. Two of D2's four cells are
   now owed, not one.
4. **`§30` question 5** ("which allocation/GC metrics can the benchmark harness
   collect consistently?") — `§30:1781` requires the answers be "recorded in
   documentation and tests". P2/P3 answer it; receiver: **Slice ③** for the
   test, **Slice ④** for `§27:1699`.
5. **`§30` questions 2 and 3** (exact commands per Tier 1 platform; library
   search paths on Windows) — question 3's separator half was closed by
   construction in Milestone 0; the rest is answered by a runner. Receiver:
   **Slice ②**, recorded in `§27:1700`'s portability matrix by **Slice ④**.
6. **`§24.3:1409`'s committed-golden condition** — receiver: **Slice ①**, via
   decision `0039`, recorded as a disposition rather than a rewording.
7. **The five status surfaces** — the milestone plan, the parent plan,
   `CHANGELOG.md`'s `[Unreleased]` preamble, this design, and `README.org`'s
   status paragraph. Receiver: **Slice ⑤**, checked by the ledger, with
   `README.org`'s Documentation list (stale since Milestone 5, §3.2 item 4) in
   the same sweep.

### 4.9 Three scope questions, for the owner

**1. The CI minute budget, and what happens if it is not there.**
`§26:1678` wants eight cells on a private repository with billed minutes and a
history of exhausting them. Before Slice ② spends anything, the owner sets the
budget: how many minutes this milestone may spend, and — if the four-platform
matrix does not fit — which cells are amended out of `§7.3:195` under
`§7.3:203`'s explicit-update rule. Slice ② will bring a measured price per cell
from the first dispatch of each, in ascending cost order, so the decision is
taken against numbers rather than estimates. **Recommended: approve a budget for
the first dispatch of all four platforms (the cheap half — one run each,
Linux amd64 and Windows amd64 being ×1 and ×2 with no source build), then decide
the recurring matrix from those measured prices.** The alternative — deciding the
matrix now — decides it without the only numbers that matter.

**2. Copyright and licence headers in `src/`.**
`§25:1662` asks for the review; the review's *outcome* is the owner's. The tree
is contradictory today (BSD 3-Clause in `LICENSE`, "all rights reserved" in
`README.org`'s footer), and `src/` files carry descriptive headers with no
copyright line. Options: resolve the README footer only (no `src/` change, gate
stays plain); or resolve it and add a one-line SPDX header to each of the nine
`src/` libraries (comment-only `src/` change, gate becomes the comment-excluded
one, §4.7). **Recommended: approve both** — an SPDX line is what a consumer's
tooling reads, and the footer contradiction is the kind of thing a release makes
permanent.

**3. A `(byte-machine version)` export.**
Whether `0.1.0` is readable from Scheme, or lives only in `CHANGELOG.md`, the
README and the tag. A version export is the one new public name this milestone
could add, and `§9`'s public surface is otherwise frozen. **Recommended: decline
for v0.1.** Nothing in `§26` asks for it, a consumer pinning a version pins it in
their build, and adding a public name in the release milestone — after two
milestones of an untouched `src/` — buys a small convenience with the one thing
this milestone is best positioned to keep: a `src/` diff that is empty.

> **Owner decisions on these three questions — 2026-09-12.** Recorded here so each
> approval names a receiver (AGENTS.md, *"an approval with no receiver"*).
>
> - **Item 1 — CI budget: zero.** No CI this milestone; the billed minutes are not
>   available. Dispositioned by [decision 0041](../decisions/0041-tier-1-cells-under-a-stated-budget.md):
>   **Slice ② is struck**, the `§7.3:195` tier is amended for v0.1 (macOS arm64
>   verified locally; Linux amd64, Windows amd64 and Linux arm64 deferred past
>   v0.1), and `#88` is dispositioned, not waived. Because this is the final
>   milestone, the deferral is v0.1's standing disposition, not a carry-forward.
> - **Item 2 — licence & headers: both.** The `README.org` footer contradiction
>   is resolved **and** a one-line SPDX header is added to each of the nine `src/`
>   libraries. The §4.7 gate is therefore the comment-excluded one. Receiver: Slice ⓪.
> - **Item 3 — `(byte-machine version)` export: declined for v0.1.** `0.1.0` lives
>   in `CHANGELOG.md`, `README.org` and the git tag only; `§9`'s public surface
>   stays frozen and the `src/` diff stays empty of new names. Receiver: Slice ⓪
>   (§4.5) and Slice ⑤.

---

## 5. Slice ⓪ — The release ledger, the version surface, and the licence review

**Ships:** `(byte-machine test release-ledger)` — the fifteen `§26` criteria and
eleven `§27` deliverables as data, each row carrying text, state, witness and
receiver — plus a lane that reads it (`byte-machine.unit.release-ledger.chez.
{source,aot}`). Mechanical rows are checked: a named lane must be registered, a
`git ls-files` pattern must match nothing, a named file must exist. Judgement
rows are marked as judgement and carry their paragraph. Two totality rows pin
the criterion set against `§26`'s fifteen and `§27`'s eleven.

Also here, because both are questions about what the repository *says*: the
version-surface rule (§4.5) and `§25:1662`'s licence and header review — the
`README.org` footer contradiction resolved, and, if §4.9 item 2 is approved,
one SPDX line per `src/` library.

**Why first.** Decision `0038`'s argument, and the shape Milestone 8 Slice ⓪
proved: the milestone's exit criterion is a set of fifteen claims, nine of them
already true, and a milestone that does not establish which before working the
rest will re-litigate the nine.

**Oracle.** The initial ledger is written against §3.1's disposition and each
`met` row's witness is re-taken by the lane at its own base, not copied from
this document. The two totality rows fail by name when a criterion moves.

**Exit.** The lane is green in both modes; the ledger's `open` rows are exactly
the five §3.1 names plus the three `partly`; no mutation-suite entry (the
totality rows are self-ratcheting, as Milestone 8 Slice ⓪'s table was).

## 6. Slice ① — Platform neutrality, and the cross-cell argument made total

**Ships:**

1. **The sixth determinism golden** — the HTTP fixture's 196 682 bytes, under
   `test/fixtures/` (`-text`, so no checkout filter can reach it), compared
   byte-for-byte by `determinism-http-tests.sps` exactly as the other five are
   compared. This is obligation 2 and decision `0039`'s mechanism.
2. **The dry Windows audit** — every question the Windows cell will answer,
   written down before it runs: the discovered `scheme.exe` path and whether
   `find_program(NAMES scheme chez chezscheme)` finds it, the AOT object
   extension on `ta6nt`, the `BYTE_MACHINE_EXPECT_OS`/`ARCH` values (`nt` →
   `windows` is already in `harness.sls`'s table), and the `-DBYTE_MACHINE_CHEZ_
   EXECUTABLE` fallback. Each becomes a row Slice ② fills from a runner.
3. **The six cosmetic `/bin/true` strings** replaced with a platform-neutral
   placeholder. Not a portability fix — P1 established none of them executes —
   a readability one, so the next reader's sweep does not reach P1's wrong
   conclusion.

**Why here.** Everything in this slice costs zero runner minutes and every one
of them is a prerequisite for a cell being *worth* turning on: a cell that runs
before the HTTP golden exists proves less than the same cell after.

**Oracle.** The golden is produced by the shipped emitter and compared by the
shipped lane; byte-identity across two emissions already holds (Milestone 8
Slice ⑤) and the golden adds the cross-process, cross-lane and cross-cell leg.
The audit rows are assertions about the *tree*, re-measured at this slice's base.

**Exit.** Six determinism lane pairs green in both modes; the ledger's `§26:1677`
row moves from `open` to "one cell, mechanism complete"; `src/` diff empty.

## 7. Slice ② — Tier 1 CI

**Ships** the matrix, under decision `0041`'s procedure and §4.9 item 1's
budget: each cell's first run is a single `workflow_dispatch`, priced and
recorded, before it joins the `push`/`ci`-label paths.

- **Linux amd64** — running today. Its first two runs of this slice discharge
  **`#88`**: one on a cold cache (the ~12-minute source build) and one on a warm
  one, proving the cache key restores a binary that runs. That is obligation 1,
  outstanding since 2026-09-07.
- **Windows amd64** — `ChezScheme10.4.1.exe` installed (P4), no source build.
  Answers Slice ①'s audit rows and `§30` questions 2 and 3.
- **Linux arm64** — the runner label is verified to exist *on this account's
  plan* before it is relied on; arm64 hosted runners are free on public
  repositories and this repository is private (§2).
- **macOS arm64** — ×10, and the platform every slice is already measured on
  locally, which is why it is last: it is the cell that adds the least new
  information per minute.

Each cell runs `§24.2`'s stages: identity assertion (runtime, OS, architecture
— the harness already carries the `machine-type` → OS/arch tables), the library
boundary load, the shared source suite, generation, AOT compilation, and the
generated suite. `§24.2` stage 7 is satisfied by the six determinism lanes
against the committed goldens (decision `0039`), not by an artefact fan-in.

**Oracle.** A cell passes when the full `release` selection passes in both
modes, with the identity assertion proving it ran where it claims. A cell that
cannot run produces an amendment to `§7.3:195`, written into the parent plan as
a dated disposition, before the release (§4.4).

**Exit.** `§26:1678` `met` for every cell in `§7.3`'s tier as amended; `#88`
discharged with both runs named; the per-cell prices recorded for the owner's
recurring-matrix decision.

## 8. Slice ③ — The benchmark baseline and the allocation audit

**Ships** `bench/runner/` and `bench/fixtures/` — which hold `.gitkeep` and
nothing else today — as `§23.1`'s metric set over `§23.2`'s nine workloads
(short normal requests, many small headers, long spans, byte-at-a-time
fragmentation, fixed-length bodies, chunked bodies, pipelined requests, early
and late errors, dense and sparse dispatch microbenchmarks, long exact-sequence
matching), plus the committed baseline artefact `§23.1` specifies: canonical
workload bytes, deterministic seeds, harness version, exact commands, raw
samples, summarised statistics, and an explicit distinction between required
metrics and metrics unavailable on a runtime.

And the **allocation audit** as an asserted lane, under decision `0040`: the
slope, the live control, both executors measured with only the generated one
gated, callbacks disabled with the callback-bound figure recorded beside it.

**Why here and not earlier.** `§23.1`'s baseline must be recorded *per cell*
("OS and architecture" is a required record field), so the runner is most useful
once Slice ② knows which cells exist. But the audit and the runner are
independent of any cell, and this slice runs the baseline locally on
`tarm64osx` whatever Slice ② concluded — a baseline on one cell is `§26:1679`
satisfied; a baseline on none is not.

**Oracle.** P2's slope re-taken through the shipped harness, with the control
asserted nonzero in the same lane. `§26:1679` says "without speculative
optimization": the slice records and does not act — `§23.3`'s admission rule is
not met for anything in `§29` and this slice does not try to meet it.

**Exit.** `§26:1679` and `§26:1680` `met`; `§30` question 5 answered in a test
(its documentation half is Slice ④'s); no `src/` change and no optimisation.

## 9. Slice ④ — Examples and the documentation set

**Ships:**

- **`examples/`**, which holds `.gitkeep` today. `§8`'s layout names
  `examples/generate-simple-machine/`; `§27:1703` requires examples use the
  public procedural API and not private tagged-vector constructors; `§26:1682`
  requires they "generate, compile, and run **from a clean checkout**". The
  existing `§9.6` lane cannot witness the last of those (§3.2 item 1), so the
  example is a standalone program with its own documented commands, and the
  clean-checkout run is a step Slice ⑤ performs in a fresh clone.
- **`§27`'s nine missing references**: the source IR and builder reference, the
  transition/cursor semantics reference, the field and overflow reference, the
  verifier diagnostic catalogue (which has a derived source already — the census
  the suite computes from `verify.sls`, thirty codes over fifty-six sites), the
  generated-code integration guide for Chez, the grammar-author testing guide,
  the benchmark methodology and baseline report (Slice ③'s artefact written up),
  the portability matrix and pinned runtime versions (Slice ②'s measured cells),
  and the README quick start.
- **`§26:1681`'s dependency-boundary documentation** — `§7.2`'s diagram and the
  rule that generated parsers import only `(byte-machine runtime)`.

**A standing hazard, named in advance.** These documents are dense in
`file:line` citations, and AGENTS.md records two separate defects from exactly
that: a citation stale within its own commit, and citations into files the
change itself edits. The rule this slice works under: cross-document `§section:
line` citations are **re-measured as the last step before commit**, not while
writing, and a reference that cites a file this slice also edits cites it by
name and symbol rather than by line.

**Oracle.** The ledger's `§27` totality row moves to eleven of eleven. The
verifier catalogue is *derived* from the census the suite already computes, not
hand-transcribed — a hand-written catalogue would be a thirty-first place for
the code set to drift.

**Exit.** `§26:1671`, `:1681`, `:1682`, `:1683` `met`; `§27` complete.

## 10. Slice ⑤ — The readability review, the release, and the close

**Ships:**

- **`§25:1659`'s generated source readability review.** The HTTP fixture's
  196 682 bytes are the subject: are the state arms legible, are the names
  stable, is the structure something a consumer debugging a generated parser can
  follow? A judgement, recorded as one in the ledger, with whatever it finds
  either fixed (emitter comments and layout are `src/`-touching, so anything
  beyond comments becomes a decision, not a drive-by) or recorded as known.
- **`CHANGELOG.md`'s `0.1.0` entry** (`§26:1684`) and the release notes,
  including the honest list of what ships known-open: `§12.7:770`'s zero-width
  machine-action half with its measured narrowing, `§9.3:392-393`, `§25:1590`'s
  partial universal, and any Tier 1 cell amended out under `§7.3:203`.
- **The clean-checkout proof** (`§25:1663`, `§26:1682`): a fresh clone, the
  documented commands, the example generating, compiling and running — performed,
  not described.
- **The five status surfaces** (obligation 7), `README.org`'s Documentation list
  brought current through Milestone 8 and this one, and the parent plan's dated
  disposition.
- **The whole-branch review, and the tag.**

**Exit.** Every ledger row `met`; `git diff --stat main..HEAD -- src/` empty
(or comment-only under §4.7's declared exceptions); `0.1.0` tagged.

---

## Exit (full Milestone 9)

| `§25` scope | Discharged by |
|---|---|
| :1655 complete Tier 1 CI | Slice ② — every cell in `§7.3`'s tier as amended, each priced from its first dispatch |
| :1656 source generation equality across platform cells | Slices ① (the sixth golden) and ② (the cells), transitively through committed goldens (decision `0039`) |
| :1657 documentation and examples | Slice ④ — `§27`'s eleven, `examples/`, the quick start |
| :1658 baseline benchmarks | Slice ③ — `§23.1`'s metrics over `§23.2`'s workloads, committed artefact |
| :1659 generated source readability review | Slice ⑤ |
| :1660 generated hot-path allocation audit and fixnum-sized baseline | Slice ③ — the slope with a control (decision `0040`) |
| :1661 changelog and release notes | Slice ⑤ |
| :1662 licence/header review | Slice ⓪ |
| :1663 clean checkout build and test instructions | Slice ④ (written) and ⑤ (performed in a fresh clone) |
| :1665 **all fifteen `§26` criteria** | The ledger, every row `met` (Slice ⓪ builds it; each slice moves its rows; Slice ⑤ closes it) |

---

## 11. Explicitly out of Milestone 9

- **Any `§29` deferred extension.** `§23.3`'s admission rule is not met for any
  of the eleven, and Slice ③ produces baselines precisely so that a *later*
  project can meet it. The 36.6× interpreter gap P3 measured is not a defect and
  not a work item.
- **Any behavioural `src/` change.** §4.7's gate, with two declared exceptions.
- **`§12.7:770`, `§9.3:392-393`, `§25:1590`'s remainder.** Named in the release
  notes as open, receivers unchanged (§4.6).
- **Tier 2 cells** (macOS amd64, Windows arm64, other Chez versions). `§7.3:197`:
  tracked, not release-gating.
- **A public `version` export**, unless §4.9 item 3 is approved against the
  recommendation.
- **Lowering the Chez floor.** `README.org` states the rule — 10.4.1 is a floor
  recording what has been verified, and lowering it needs CI evidence from the
  older release. This milestone verifies 10.4.1 on more platforms, not more
  versions on one.

---

## 12. Handed to writing-plans

Per-slice plans are written one at a time, each against its own re-taken base.
What each plan must carry beyond the usual:

- **Slice ⓪** — the ledger's row schema, and which of the fifteen rows are
  *checked* versus *judgement*; the §4.9 item 2 outcome.
- **Slice ①** — the golden's exact byte count re-measured at the slice's base
  (196 682 is this document's number, at `62671b2`, and the emitter has not
  changed since — but a golden's size is the kind of number that must be taken
  from the artefact being committed, not from a design).
- **Slice ②** — the §4.9 item 1 budget, and the per-cell dispatch order. The
  plan must state what a cell's *failure* produces (an amendment to `§7.3:195`),
  not only what its success produces.
- **Slice ③** — P2's and P3's numbers re-taken through the shipped harness
  before any of them enters the baseline artefact.
- **Slice ④** — the citation-freshness rule (§9) as an explicit final step.
- **Slice ⑤** — the five status surfaces enumerated by name, and the
  clean-checkout run as a performed step with its output recorded.

**Gate 0 writes four decision records:** `0038` (the release ledger is first and
checked), `0039` (cross-cell equality is transitive through committed goldens),
`0040` (the allocation audit is a slope with a control), `0041` (cells turn on
one at a time; an unaffordable cell is a plan amendment, never a release-note
waiver). It also records the owner's §4.9 dispositions.

**The base.** This design is written against `62671b2`, which is `main`. Unlike
Milestone 8's design, no parent squash is pending, so the branch rebases plainly
if `main` moves.

---

## Appendix — the ledger, as an instruction

The initial state Slice ⓪ encodes, as measured in §3.1. `witness` is what the
lane checks or the paragraph that stands in for a check; `receiver` is the slice
that moves the row.

| # | criterion | state | witness / receiver |
|---|---|---|---|
| 1 | `§26:1671` node semantics documented | partly | reference doc → ④ |
| 2 | `§26:1672` verification unbypassable | met | `render-machine` refuses an unverified value |
| 3 | `§26:1673` differential tests pass | met | 30 `differential` lanes |
| 4 | `§26:1674` lifecycle … counted consumption | met | M2-M6 close notes |
| 5 | `§26:1675` HTTP fixture behaviour | met | M8 close, `§25:1646` |
| 6 | `§26:1676` every split point | met | M8 Slice ⑤; `§4.9` item 3 declined by measurement |
| 7 | `§26:1677` deterministic generation across cells | open | six goldens → ①; cells → ② |
| 8 | `§26:1678` every Tier 1 cell | open | → ② |
| 9 | `§26:1679` benchmark baselines | open | → ③ |
| 10 | `§26:1680` no per-byte construction; allocation measured | open (true, unasserted) | slope + control → ③ |
| 11 | `§26:1681` boundaries documented | partly | → ④ |
| 12 | `§26:1682` examples from a clean checkout | open | `examples/` → ④; the run → ⑤ |
| 13 | `§26:1683` README scope and quick start | partly | quick start → ④ |
| 14 | `§26:1684` `0.1.0` changelog entry | open | → ⑤ |
| 15 | `§26:1685` no native artefacts, no unrelated HTTP | met | `git ls-files` pattern empty; `unit.http-leak` |

Plus `§27`'s eleven, of which `:1694` (callback/span lifetime) and `:1701`
(changelog, pending its `0.1.0` entry) exist and nine do not.

**Two rows to watch.** Row 10 is `open` although the property is *true* at
`62671b2` — the distinction between a property holding and a suite knowing it
holds is the whole reason the ledger exists, and a ledger that marked it `met`
on this document's say-so would be the defect it is built to prevent. Row 7
depends on two slices and is `met` only when both have landed; it is one
criterion and gets one row, with two receivers.

---

## References

- Parent plan: `§3:66` (no deliberate per-byte allocation), `§7.2:166-192`
  (library boundaries), `§7.3:193-203` (the Tier 1 matrix and its amendment
  rule), `§8:205-235` (layout: `examples/`, `bench/`), `§9.6:446-459` (the
  required end-to-end example), `§20:1031` (byte-identical output per cell),
  `§22:1314` (generate and compare per cell), `§23:1326-1380` (baseline,
  workloads, admission), `§24:1382-1410` (portable entry points, the nine CI
  stages, artefact discipline), `§25:1651-1665` (this milestone),
  `§26:1669-1685` (the fifteen release criteria), `§27:1689-1703` (the eleven
  documentation deliverables), `§28:1705-1746` (risks), `§29:1747-1768`
  (deferred extensions), `§30:1769-1781` (spike questions 2, 3, 5),
  `§31:1783-1800` (handoff rules).
- Decisions `0005` (Chez only), `0006` (inline libraries), `0008` (the emitter
  emits an importable library), `0034` (a table first, fixture-owned — the shape
  `0038` follows).
- `docs/plans/milestone-0-ci-feasibility.md` — the four cells priced cell by
  cell, and D2's deferral of the remaining ones to this milestone.
- `docs/plans/milestone-0-portability-spike.md` `§9` — the path-separator
  question, closed by construction.
- `docs/plans/milestone-8-slice-5-implementation-plan.md` — Milestone 8's close,
  `§25:1646-1649`, and the deferral of the HTTP determinism golden.
- `AGENTS.md` — the five status surfaces; re-measure before a number enters a
  record; check a claim against the code, not the prose; prose expectations are
  not checks; a deferral needs both ends.
