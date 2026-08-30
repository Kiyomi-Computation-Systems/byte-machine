# Milestone 3 Slice ③ — Multiple Alternatives, Ambiguity, and Cycle Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Milestone 3 by turning the two shipped internal trie guards into a
`verify-machine` diagnostic (§16.2:894), extending zero-progress reporting to
sequence nodes (§25:1533), and driving **more than one alternative** end to end
through both executors — including the `HTTP/1.0`⁄`HTTP/1.1` shared-prefix fixture
from §21.2's grammar — with determinism pins over a sequence machine.

**Architecture:** Slice ② already ships the trie-shaped lowering that *admits*
multiple alternatives; nothing in the normalizer, the emitter, the runtime or the
ABI changes here. This slice adds **one verifier pass** (a source-level pairwise
terminal-prefix test, measured equivalent to the trie's guards), **one line** to
`pass-zero-progress`'s report guard, and the fixtures and lanes that execute a
branching trie. The two remaining source edits are each one decision, and each
breaks a shipped mutation pin that must be re-anchored in the same commit.

**Tech Stack:** R6RS Scheme (Chez 10.4.1), CMake/CTest lanes (CMake 4.3.3 local,
floor 3.26), the in-repo mutation suite
(`test/support/cmake/SchemeMutationSuite.cmake`).

Design authority: [milestone-3-design.md](./milestone-3-design.md) §7 (Slice ③),
§4.2, §4.3, §4.4, §4.5, §8 and its appendix; decisions
[0014](../decisions/0014-byte-classes-expand-per-byte.md),
[0015](../decisions/0015-sequence-prefix-states.md),
[0016](../decisions/0016-normalized-state-id-allocation.md) and
[0017](../decisions/0017-degenerate-shapes-are-contract-violations.md) (point 4
governs what is verifier work rather than a constructor error); parent plan
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
§9.1:297-299/:318/:322, §10.6:542-546, §11.3:648, §11.4:652, §11.5:664, §12.4:727,
§16.2:893-895, §16.3, §16.4:933-947, §17:951/:957/:966, §18:970-972, §19.2:1010,
§21.2:1065, §22.1, §22.4, §22.5, §22.7:1299-1301, §22.9:1311-1317, §25:1529/:1532-1533
and exits :1539-:1540, §29:1743-1744.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Baselines to hold, measured 2026-08-30 on `main` = `49c8cc4`** (Darwin arm64,
  Chez 10.4.1, CMake 4.3.3): `ctest --preset release` **80/80** (38.28 s),
  `--preset pr` **80/80** (`pr` and `release` currently select the same 80 tests),
  `--preset no-scheme` **8/8** (7.35 s), Scheme mutation suite **43 passes / 223
  mutations** (24.39 s, zero `UNCAUGHT`, zero `FATAL`, nine
  `SURVIVES (expected)`), CMake mutation suite **1 pass / 72 mutations** with
  exactly one declared survivor. Every task ends with these — plus that task's own
  additions — green.
- **The three pinned IR fingerprints and both committed goldens must not move.**
  `4236938459847922092` (one-byte), `9098559711816935340` (node-routing
  eof-machine), `15725897457025557005` (pause-machine);
  `test/fixtures/generated-one-byte.golden.sls` and
  `test/fixtures/generated-pause.golden.sls`. This slice adds **no normalizer and
  no emitter change at all** (D9), so the warrant is stronger than Slice ②'s: the
  only source edits are in `verify.sls`, which runs before normalization
  (§17:951) and never feeds it.
- **No `runtime.sls` change, no `compile.sls` change, no
  `private/normal-ir.sls` change, no `interpret.sls` behavioural change, no new
  state-kind tag byte, no `/v3` ABI, and the encoding-format version byte stays
  `1`.** The only permitted `interpret.sls` / `normal-ir.sls` edits in this slice
  are **comment corrections** (D5). If a task believes it needs an executable
  change in either file, that is a plan defect: record it in the ledger and stop.
- **Chez floor 10.4.1, CMake floor 3.26. No new dependencies** — only `(rnrs)`,
  `(rnrs eval)`, `(only (chezscheme) load)` where an existing determinism program
  already uses it, and in-repo libraries.
- **`(byte-machine interpret)` must not import any normalizer library, and must
  not share a prefix-walking helper with one** (§18:970-972, decision 0015
  point 3). Unchanged from Slice ②; a proposal to factor "the shared prefix
  walker" into a common library is a change to decision 0015, not a refactor.
- **Exit-status vocabulary is exactly 0, 1, 2, 3**
  (`cmake/ByteMachineExpectExit.cmake:27-31`). This slice adds **no new exit
  path**; every task still re-runs the *whole* mutation suite, because a new exit
  path can silently disarm an existing mutation and a green suite will not say so.
- **Mutation discipline** (AGENTS.md): every decision gets a mutation whose catch
  asserts a **measured** failure signature — `EXPECT_STATUS` **plus**
  `EXPECT_OUTPUT_MATCHES` — never a bare nonzero exit. A pin must resolve to
  exactly one `(case, check)` pair, not one case. The FAIL grammar is
  `byte-machine-harness: FAIL <group>.<case>: <what> -- <detail>`
  (`harness.sls:409`). `EXPECT_OUTPUT_MATCHES` is an **unanchored CMake regex**,
  so `(`, `)`, `.` need `\(`, `\)`, `\.` (written `\\(` etc. in the file). A pin
  that is a substring of the FAIL-CONTEXT line (`backend=`, `mode=`, `os=`,
  `architecture=`, `machine-type=`, `artifacts=`, and the values `scheme`,
  `mutation`, `harness`, `cmake`, `direct`) or of the summary line (`suite=`,
  `runtime=`, `mode=`, `cases=`, `failed-cases=`, `checks=`, `failures=`,
  `cleanup-failures=`, `skipped=`, `errors=`, `status=`) is the bare
  nonzero-exit catch AGENTS.md forbids, wearing a signature. Prefer a mutation
  caught by a **failed comparison** over one caught by a raise; try the opposite
  constant first.
- **Sweep pins in BOTH directions.** Adding a mutation to a lane widens every
  existing pin's collision set there — *and* an existing mutant may match the pin
  you are adding. Adding a *check* widens pins the same way. This slice adds
  checks to `verify-tests.sps`, which is the SPEC lane of Pass 33's **34**
  mutations, so the whole-pass re-sweep is mandatory, not optional. Run a control
  on the merge base: a pass collision-free there and colliding at HEAD is this
  branch's doing.
- **`SITES` defaults to 1 and is asserted exactly, and it fails in BOTH
  directions.** A `FIND` whose text an edit changes fails with "found 0,
  expected 1"; a `FIND` whose text a *new* function accidentally duplicates fails
  with "pattern occurs 2 times in … expected 1"
  (`MutationRunner.cmake:342-348`). The second direction is the one that is easy
  to miss, and this plan hit it during authoring — see D8b. **This slice edits the
  text of two shipped `FIND`s** (D8); both are re-anchored in the same commit as
  the edit.
- **Predicted counts are arithmetic to check, never facts to write down.**
  Re-measure release/pr, no-scheme and both mutation totals before any number
  enters `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`, the CHANGELOG, a decision record,
  a design document, or `README.org`. Prediction: release/pr **86** (80 + 6 lanes — three
  programs × source/AOT), Scheme mutation **46 passes / ~240 mutations** (43 plus
  one non-vacuity pass each for Tasks 3, 4 and 5). Design §9's rule stands: sizing
  is a **floor**, not an estimate — Slice ① predicted 41/180 and measured 41/186;
  Slice ② predicted 43/~205 and measured 43/223.
- **Completion sentinels are mandatory, and must read the OBSERVED value.** No
  suite declares an expected case or check count; `harness-summary` reports only
  what ran, so an exhaustive loop that never executes **passes vacuously**. Derive
  every counter from what the parser or verifier *returned*, never from the test's
  own expected list, and give the loop over the loops a sentinel too (assert the
  driving collection's own `length` where you iterate it).
- **Lane and manifest bookkeeping is fatal-on-error.** Source + AOT pair per
  program, each with a `TIMEOUT` and a unique five-segment lowercase name matching
  `^byte-machine\.([a-z0-9-]+)\.([a-z0-9-]+)\.([a-z0-9-]+)\.([a-z0-9-]+)$`
  (`cmake/ByteMachineTesting.cmake:64-69`); feature segments must not begin or end
  with a hyphen; any new fixture `.sls` in **both** lanes' `SOURCES`; basenames
  unique within a lane. Duplicate CTest names are a configure-time `FATAL_ERROR`,
  and both `byte-machine.differential.sequence.chez.{source,aot}` (M2, at
  `test/CMakeLists.txt:968-987`) and
  `byte-machine.{unit,differential}.sequence-node.chez.{source,aot}` (Slice ②, at
  `:1089-1108` and `:1114-1133`) are **already taken**. A new `.sls` changes the
  lane's content fingerprint, recomputed at build time from `SOURCES`; there is
  nothing committed to update by hand, but **rebuild after editing any test file**
  (`cmake --build --preset dev`, or `make build`) or the provenance check
  correctly fails on a stale build. `ctest --preset <x>` does **not** build.
- **`.superpowers/sdd/` is git-ignored: never `git add` it.** An obligation
  recorded only there has not been recorded — provenance for any surviving pin
  residue goes **in the tree beside the pin, named by mutation LABEL**.
- Conventional Commits; run the suite before every commit; match the touched
  file's comment style and `mode` vocabulary.
- Commands (copy-pasteable; `chez`, not `scheme` — there is no `scheme` on this
  host):

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

  `no-scheme` has its own `binaryDir` (`build/no-scheme`) while `release` is a
  *test* preset pointing at configure preset `dev` (`build/dev`), so running
  no-scheme never forces a `release` reconfigure. **Measured.**

---

## §0 Design calls locked by this plan

These resolve what design §7 leaves to writing-plans. Implementers do not
re-litigate them; a **measured** contradiction is a plan defect to record in the
ledger and fix. Every "measured" below was taken during plan authoring against a
scratch copy of `main` = `49c8cc4` carrying the prototype source edits; the real
tree was never modified (`git status --porcelain` empty throughout).

**D1 — The §16.2:894 check is its OWN pass. `pass-overlap` stays
byte-dispatch-only PERMANENTLY, and its comment is corrected from "deferred to
Slice ③" to say so.**

`verify.sls:176-180` currently reads "Deliberately NOT extended to
`sequence-dispatch-node?` (Milestone 3 Slice ②) … design §7 assigns it to
Slice ③. A sequence node is invisible to this pass between ② and ③." That
sentence is an **instruction** in live code (AGENTS.md: "a comment in live code
saying what the code is for"), and after this slice it is false in a way that
would send the next reader to extend `pass-overlap`.

The resolution is that `pass-overlap` is never extended. Decision 0017 point 4
(`0017:44-46`): "Overlap (§16.2:893) and sequence ambiguity (§16.2:894) remain its
only entries in this area, and both stay verifier work" — two §16.2 bullets, two
checks, two codes. `pass-overlap` compares *canonical matcher byte sets within one
byte-dispatch node*; cross-alternative sequence collision is a *prefix* relation
between byte **strings**, which is a different predicate over different data. The
comment gets corrected in place to "not extended to sequence nodes at all —
§16.2:894 is `pass-sequence-ambiguity` below, per decision 0017 point 4", and the
file header comment at `:8-16` gets the matching correction.

**D2 — One new diagnostic code, `'ambiguous-sequence-prefix`, covering BOTH
unrepresentable shapes.**

Design §4.5 requires "**exactly one** new code for ambiguous terminal prefixes".
Duplicate alternatives are the maximal case of the same relation (`AB` is a
terminal prefix of `AB`), so both the normalizer's `"ambiguous terminal prefix"`
and its `"duplicate sequence alternative"` guard shapes report this one code.
Existing codes, so the new one does not collide (`rg -o "make-diagnostic '[a-z-]*"
src/byte-machine/verify.sls | sort -u`, thirteen): `duplicate-error-declaration`,
`duplicate-name`, `eof-reachable-stop`, `eof-zero-progress-cycle`,
`invalid-eof-target`, `invalid-name`, `invalid-shape`,
`missing-error-declaration`, `missing-target`, `non-eof-into-finish`,
`overlapping-cases`, `unreachable-node`, `zero-progress-cycle`. The convention is
a lowercase hyphenated symbol naming the defect, and `'ambiguous-sequence-prefix`
follows it. Diagnostics are compared **by code, never by text** (`verify.sls:17`),
so the message is free prose: use
`"one alternative is a terminal prefix of another"`.

**D3 — The check is a SOURCE-LEVEL pairwise terminal-prefix test over the node's
own alternatives, reported once per colliding PAIR. Measured equivalent to the
normalizer's trie guards over an exhaustive small space.**

§16.2:894 says "sequence ambiguities **after prefix analysis**". The pairwise test
*is* the prefix analysis: it needs no trie and no lowered graph, which keeps
§17:951's verify-before-normalize ordering intact (the same warrant design §7
gives for the cycle extension). One diagnostic per colliding pair, enumerated
`i < j`, mirrors `pass-overlap`'s shipped convention (`verify.sls:150-159`) and
§16.4:937-943's one-finding-per-decision rule.

**Measured equivalence.** Over **all 469** nonempty alternative-sets of size ≤ 3
drawn from the 14 binary strings of length 1–3, the pairwise test and the
normalizer's three trie guards (`normal-ir.sls:102-116`) agree on **every** case —
**0 disagreements**. That is the control this plan owes for a claim that would
otherwise be inspection-only; the exhaustive driver is reproduced in Task 1
Step 2b so the implementer re-runs it rather than trusting this sentence.

**D4 — The check runs where §16.2 lists it: immediately after `pass-overlap`, as
an UNNUMBERED pass.**

`verify.sls` numbers PASS 1-7 but already ships one unnumbered pass
(`pass-eof-execution`, introduced at `:300` as "§16.2:908/:909 and the separate EOF
zero-progress-cycle check"), so an unnumbered pass is house convention, not a
novelty. Renumbering PASS 4-7 to insert a "PASS 4" would stale **thirteen**
comment references across four files (`SchemeMutationSuite.cmake` ×5,
`verify.sls` ×4, `milestone-1-phase-2-semantic-core-implementation-plan.md` ×4)
for no gain. Name it `pass-sequence-ambiguity`, place it between `pass-overlap`
and `pass-reachability`, and call it into `verify-machine`'s `append` directly
after `(pass-overlap machine)`.

Diagnostic **order** is not asserted anywhere: every `verify-tests.sps` case tests
by code membership or by counting a code, never by position (`codes`/`has-code?`
at `:24-25`). Insertion position is therefore free; §16.2's own ordering is the
tiebreaker.

**D5 — The two internal guards STAY. `normal-ir-tests.sps`'s three guard cases
SURVIVE unchanged; `interpret-tests.sps`'s two DO NOT and are rewritten. Measured
— and this corrects the carried-in claim.**

The Milestone 3 ledger carried in: "The guard fixtures in `interpret-tests.sps`
and `normal-ir-tests.sps` will fail verification once :894 lands." **Half of that
is wrong, and the half that is wrong is the half a task would otherwise budget
for.** Measured by wiring a prototype `pass-sequence-ambiguity` into `verify.sls`
and running every program that runs standalone:

- `normal-ir-tests.sps` — **unchanged: `cases=35 failed-cases=0 checks=73
  failures=0 … status=0`.** Its helper is
  `(define (normalize m) (normalize-machine (verification-machine (verify-machine m))))`
  (`normal-ir-tests.sps:27`): it calls `verify-machine` but takes
  `verification-machine` **without consulting `verification-ok?`**, so the
  ambiguous machine still reaches `normalize-machine` and the trie guards still
  fire with `who = 'normalize-machine`. All three cases (`AB|ABC`, `AB|AB`,
  `ABC|AB`) keep passing.
- `interpret-tests.sps` — **`cases=18 failed-cases=2 checks=35 failures=2 …
  status=1`**, exactly its two guard cases, each failing loudly with
  `raised object did not satisfy the predicate` and a
  `&byte-machine-contract / code: unverified-machine / who*:
  make-interpreted-machine` condition dump. Its helper is
  `(define (interp m) (make-interpreted-machine (verify-machine m)))`
  (`interpret-tests.sps:131`), and `make-interpreted-machine` refuses an
  unverified machine (`interpret.sls:25-28`) with a condition that is **not** an
  `assertion-violation?`, so `raises-interpret-assertion?` (`:180-185`) correctly
  rejects it.
- Independently re-measured across the whole directory: of the **23**
  `test/common/*.sps` programs, **10** cannot run standalone (they need
  `BYTE_MACHINE_TEST_TMPDIR` or a `*_GOLDEN_FILE`), and of the **12** that run
  besides `interpret-tests.sps`, **all report `failures=0`**. `interpret-tests.sps`
  is the sole casualty.

The guards themselves are **kept** as defense-in-depth: `normalize-machine` is a
public entry point that does not itself call `verify-machine`, so deleting them
would let a caller who skips verification silently drop an alternative — the exact
failure decision 0015 point 2 names as unrepresentable. No decision record states
the post-:894 disposition of the guards (checked: 0015 is 80 lines, 0017 is 75,
neither mentions it), so **this plan is the record**, and Task 1 writes the reason
into the comment at each guard site.

**And "defense-in-depth" here is a WITNESSED claim, not an asserted one — which is
what keeps two shipped mutations alive.** The obvious reading of the paragraph
above is that `interpret.sls`'s guards become unreachable, because
`make-interpreted-machine` refuses an unverified machine and `(byte-machine
verify)` exports no verification constructor. That reading is wrong, and acting on
it would have cost two mutations and two guards: `(byte-machine private ir)`
**does** export `make-verification-result` (`ir.sls:36`), and two shipped test
programs already import that library (`graph-tests.sps`, `ir-tests.sps`). Forging
`(make-verification-result #t '() m)` is *exactly* the caller-who-skips-
verification the guards exist for, and it reaches them. **Measured:** the forged
path raises `assertion-violation` with `who = 'interpret` and messages
`"ambiguous terminal prefix"` and `"duplicate sequence alternative"`, unchanged.

This matters because `SchemeMutationSuite.cmake:4218-4228` and `:4230-4245`
(Pass 34, LABELs `"interpret: the ambiguous-terminal-prefix guard is dropped"` and
`"interpret: the duplicate-sequence-alternative guard is dropped"`) are pinned
verbatim to those two cases' FAIL details. Deleting the cases would leave both
mutants exiting **0** — UNCAUGHT — with no remedy that does not either delete the
guards or add a tenth and eleventh `EXPECT_SURVIVES`. Re-witnessing them through
the forged verification keeps everything: **measured**, both mutants still fail
with byte-identical details
(`… AB|ABC -- expected a raise, but the thunk returned (stopped 1 1 2 #f)` and its
`AB|AB` twin), so **neither pin changes** — only the enclosing group's name does,
and the pins do not contain it. AGENTS.md's rule is the one that produced this:
before concluding a decision cannot be witnessed, find something that can.

**D6 — The cycle extension is exactly one line: `pass-zero-progress`'s REPORT
guard. The walk already sees through a sequence node and is not touched — and
§25:1533 has TWO halves, only one of which is this slice's.**

§25:1533 reads "extension of zero-progress **and EOF-cycle** analysis to lowered
sequence-prefix states". The **EOF-cycle half already shipped, in Slice ②**:
`eof-terminal`'s `sequence-dispatch-node?` arm (`verify.sls:289-291`) and
`pass-eof-execution`'s two filters (`:307`, `:321`), witnessed at
`verify-tests.sps:616`, `:642` and the count case at `:714`. **Measured on
unmodified `main` = `49c8cc4`:** a sequence node whose `eof-target` cycles back to
itself already verifies `ok #f` with `(eof-zero-progress-cycle)`. Slice ③ owns
only the **zero-progress** half. Task 6 must attribute the bullet in halves; a
close-out that credits :1533 entirely to this task's one-line edit is the
"before writing 'met', find the thing in the tree" failure AGENTS.md records, and
an implementer who reads :1533 as unstarted will go looking for EOF work that is
already done.

`reexec-targets`' sequence arm shipped in Slice ② (`verify.sls:227-229`); it
returns the mismatch target only when the mode is `reexecute`, so `advance`-mode
self-targets are already excluded from the walk and stay accepted. The single edit
is `verify.sls:241`:

```scheme
(if (and (or (byte-dispatch-node? n) (pause-node? n)) (reaches-self? (node-name n)))
```
becomes
```scheme
(if (and (or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))
         (reaches-self? (node-name n)))
```

**Both halves of exit criterion §25:1540 measured on `main` today**, on minimal
fixtures with nothing unreachable:

| fixture | today | required after Slice ③ |
| --- | --- | --- |
| `seq` alt `AB`, mismatch `(make-edge 'seq 'reexecute)` | `ok #t`, **zero diagnostics** | `zero-progress-cycle` on `seq` |
| `seq` alt `AB`, mismatch `(make-edge 'seq 'advance)` | `ok #t`, zero diagnostics | **unchanged — consuming cycles pass** |
| byte-dispatch twin of row 1 | `zero-progress-cycle` on `d` | unchanged |

Row 1 is the reproduced hang: feeding one byte that does not match the
alternative's first byte **does not return** — measured `exit=124` under
`timeout 10` through the interpreter, and the same shape is emitted by
`compile.sls` for the generated lane, since neither executor carries a local cycle
guard and both rely on this REPORT set.

**D7 — The extension inherits the incumbent's over-approximation, deliberately and
on the record. This is what design §7's "over-rejecting … fails §25:1540" warning
does NOT mean.**

`reaches-self?` is a pure **edge** walk: it never asks whether the arm closing the
cycle is reachable for any byte. So it over-rejects a node whose alternatives'
first bytes cover all 256 values with a `reexecute` self-target — that node's root
fallback is dead code and every trip round the loop consumes a byte. **Measured:**
256 alternatives `(b 0) → stop` for `b` in 0..255 verify clean today and the
machine terminates (feeding `5 7 0` returns `stopped`, exit 0 under `timeout 20`).

**Control, which is why this costs the plan nothing:** the *incumbent* byte-dispatch
analysis is already exactly this conservative. A byte-dispatch node whose single
case is `(make-byte-range-matcher 0 255)` with a `reexecute` self-fallback —
fallback likewise dead code, likewise cannot loop — reports `zero-progress-cycle`
on `main` **today**. Measured directly. So extending the REPORT guard *preserves*
a uniform, shipped conservatism rather than introducing a new one, and making the
analysis exact would require the same reachability refinement for byte-dispatch
fallbacks, changing existing verdicts — out of scope (§29, §23.3).

Design §7's own phrasing — "positions ≥1 reach position 0 only after an advance" —
is **imprecise and will mislead an implementer**: a position-≥1 prefix state
reaches position 0 by taking the mismatch edge, which under `reexecute` is a
zero-width step (the advance happened earlier, on the way *in*). The load-bearing
invariant is **"no zero-width edge can ENTER a position-≥1 prefix state"**, from
which the lowered zero-width cycle set equals the source-level one, and no prefix
state at position ≥ 1 can be a cycle *member*. State it that way; it is what makes
design §7's "verification never needs the lowered graph" true rather than merely
plausible. Task 2 writes both the invariant and the over-rejection into the
comment at the site.

**D8 — Exactly TWO shipped `FIND`s break, both on D6's one-line edit, and they are
byte-identical to each other. One further pin re-anchors. Established by an
exhaustive scan, not by inspection.**

Method, because inspection is what missed one of these: lex every
`byte_machine_mutation(` block in `SchemeMutationSuite.cmake`, keep the **36**
whose `FILE` is `src/byte-machine/verify.sls` (not the 34 under Pass 33's SPEC —
Pass 37 mutates the same file twice more under
`byte-machine.verify.identifier-repertoire.chez.source`, and a SPEC census cannot
see them), and count each `FIND` literal in the post-edit `verify.sls` against its
declared `SITES`. Run it after Task 1 and again after Task 2.

1. `SchemeMutationSuite.cmake:3232-3238`, LABEL `"verify: zero-progress detection
   never fires"`, `FIND [[(if (and (or (byte-dispatch-node? n) (pause-node? n)) (reaches-self? (node-name n)))]]`
   — **the exact line D6 edits.** After the edit it matches 0 sites.
2. `SchemeMutationSuite.cmake:3561-3587`, LABEL `"verify: a pause-only
   zero-progress cycle is not flagged"`, carries the **byte-identical** `FIND`.
   It is the one a per-LABEL reading misses, because nothing about its label or
   its pin (`"chain of pauses that cycles is a zero-progress EOF cycle:
   zero-progress-cycle diagnostic"`) suggests it shares an anchor with (1). Both
   re-anchor in the same commit as the edit; their `REPLACE`s differ and must stay
   different — (1) disables the report outright (`(if #f`), (2) narrows the filter
   so **pause** nodes go unflagged, and (2)'s `REPLACE` must be rewritten to drop
   *only* the pause clause from the widened guard, or it silently becomes a second
   copy of Task 2's own new mutation. **Measured** with the corrected `REPLACE`:
   it emits exactly one FAIL record, its own pinned EOF-pause one, and `combined3`
   still counts 3 — so no collision.
3. `SchemeMutationSuite.cmake:3764-3800`, LABEL `"verify: a sequence node's
   reexecute mismatch edge is invisible to the zero-progress walk (arm 3,
   reexec-targets)"`, is a **pin** re-anchor rather than a `FIND` break: it is
   pinned to
   `"a byte-dispatch self-loop and a sequence-mismatch cycle are two zero-progress cycles: zero-progress-cycle count -- expected 2, got 1"`.
   D6 changes the correct count from 2 to 3, so the case name and its
   `check-equal` expectation both change and the pin text changes with them.

**Task 1 breaks nothing** — but only because of D8b. Its first draft broke three
more.

The `combined3` case (`verify-tests.sps:688-713`) is Slice ②'s
count-don't-witness discriminator, and D6 makes it **four-way**. Measured, all on
the one check, after the case is renamed and its expectation set to 3:

| source | `zero-progress-cycle count` | resulting FAIL detail |
| --- | --- | --- |
| correct Slice ③ code | **3** | *(case passes)* |
| REPORT guard's sequence clause dropped (the new mutation) | **2** | `expected 3, got 2` |
| `reexec-targets`' sequence arm dropped (arm 3) | **1** | `expected 3, got 1` |
| PASS 5's report conditional replaced by `(if #f` (`:3235`) | **0** | `expected 3, got 0` |

Four distinct values, one check, no collision. Rename the case to
`"a byte-dispatch self-loop, a dispatch-through-sequence cycle and the sequence node itself are three zero-progress cycles"`
so the record says what it now counts, and pin the two sequence mutations to
`… expected 3, got 2` and `… expected 3, got 1` respectively. `:3235`'s own pin
(`"a reexecute self-loop is a zero-progress cycle: zero-progress-cycle"`) still
resolves uniquely and does **not** change; only its FIND does.

**D8b — The new pass must not reuse `node-overlaps`' loop-binding names, because
a duplicated line is a broken `FIND` in the other direction.**

`pass-overlap`'s `node-overlaps` (`verify.sls:160-175`) is the natural template
for a pairwise pass, and copying its skeleton verbatim is what the first draft of
this plan did. Three shipped mutations pin **single lines** of that skeleton —
`SchemeMutationSuite.cmake:3187` (`FIND [[(outer (cdr ss)]]`), `:3212`
(`FIND [[(inner (cdr rest)]]`) and `:3225`
(`FIND [[(let inner ((rest (cdr ss)) (out out))]]`) — so a structural clone takes
each from one occurrence to two and the suite hard-fails
`pattern occurs 2 times in src/byte-machine/verify.sls, expected 1`, three times
over, for mutations this slice never touches.

The fix is to name the new pass's bindings differently, not to widen three shipped
`FIND`s: `alts`/`scan`/`as`/`against`/`others`/`found` instead of
`sets`/`outer`/`ss`/`inner`/`rest`/`out`. **Measured** after the rename: all three
shipped literals are back to exactly one occurrence, and an exhaustive re-count of
all 36 `verify.sls` `FIND`s reports **zero** mismatches attributable to Task 1.
The renamed bindings also read better — `as` and `others` say what a pairwise scan
is doing, where `ss` and `rest` were inherited from a byte-set pass.

**D9 — Fixtures, lanes, goldens and names.**

One shared fixture library
`test/support/harness/byte-machine/test/http-version-machine.sls`, modelled on
`pause-machine.sls` (whose header names its three consumers, so the graph is
written once), exporting both mismatch-mode machines over the §21.2:1065 grammar
production `version = "HTTP/1.0" / "HTTP/1.1"`. Machine name `'http-version`: the
emitted library is `(library (generated <machine-name>) …)` and names must match
`[a-z][a-z0-9-]*`, so never `'HTTP/1.x`.

Three programs, four new lanes plus two determinism lanes:

| program | lanes | why |
| --- | --- | --- |
| `test/common/http-version-interpret-tests.sps` | `byte-machine.unit.http-version.chez.{source,aot}` | **absolute** outcomes through the interpreter — both executors read the same source IR, so a defect there is invisible to a comparison and visible only here |
| `test/common/differential-http-version-tests.sps` | `byte-machine.differential.http-version.chez.{source,aot}` | interpreter ≡ generated over a **branching** trie, with §22.5 split schedules |
| `test/common/determinism-http-version-tests.sps` | `byte-machine.determinism.http-version.chez.{source,aot}` | §22.9 pins + a third committed golden |

`http-version` is a legal five-segment feature segment and collides with nothing.
The third golden is `test/fixtures/generated-http-version.golden.sls`, generated
**from the shipped emitter, never hand-written**, and reached through a new
`BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE` environment variable (the tree uses one
per golden: `BYTE_MACHINE_GOLDEN_FILE`, `BYTE_MACHINE_PAUSE_GOLDEN_FILE`).
`.gitattributes:19` (`test/fixtures/** -text`) already protects any new file
dropped into `test/fixtures/`.

**Measured lowering of the fixture**, so the plan's structural assertions are not
predictions. Nodes declared in order `ver`, `zero`, `one`, `reject`; alternatives
`HTTP/1.0 → zero` and `HTTP/1.1 → one`; mismatch `(make-edge 'reject <mode>)`;
`eof-target` `#f`:

```
entry 0, 11 states, IR fingerprint 12299125921751534854
  id 0  dispatch  ((#\H 4 advance))          fb (3 . reexecute)  eof (default . eof)
  id 1  stop            ; zero
  id 2  stop            ; one
  id 3  error           ; reject
  id 4  dispatch  ((#\T 5 advance))
  id 5  dispatch  ((#\T 6 advance))
  id 6  dispatch  ((#\P 7 advance))
  id 7  dispatch  ((#\/ 8 advance))
  id 8  dispatch  ((#\1 9 advance))
  id 9  dispatch  ((#\. 10 advance))
  id 10 dispatch  ((#\0 1 advance) (#\1 2 advance))   <-- the branching prefix state
```

Seven internal prefix states appended after the four declared ones (decision 0016
point 2), the branch at id 10 after the seven-byte shared prefix `HTTP/1.`, and
**every** prefix state carrying the source node's mismatch edge as its fallback and
inheriting its EOF edge (§12.4:727). The emitter needs **zero** change: state 10
renders as an ordinary two-arm `(case b ((48) …) ((49) …) (else …))`; rendered
size 3849 bytes.

**D10 — Milestone 3 CLOSES here, so Task 6 is a milestone close-out, not a slice
close-out.** Slice ③ discharges the multi-alternative half of §25:1529, plus
:1532 and :1533, and exits :1539 and :1540 — the last of M3's scope. AGENTS.md's
five surfaces plus the ones no step names are enumerated in Task 6; Slice ②
deliberately deferred that sweep here.

**D10b — One carried-in coverage gap this slice does NOT close, named here so the
milestone does not close over it silently.** The Milestone 3 ledger carries
"no lane drives a vacuous complement past the normalizer (carried from Slice ①)"
— the compile-and-execute path for a zero-transition dispatch state built from
`(make-byte-complement-matcher (make-byte-range-matcher 0 255))`. **Confirmed
still open at `49c8cc4`:** that construct appears only at
`normal-ir-tests.sps:195-201` (normalizer) and `verify-tests.sps:449` (verifier);
`differential-byte-class-tests.sps` and `byte-class-interpret-tests.sps` drive an
ordinary complement, so nothing compiles or executes the vacuous one.

It belongs to §25:1527 and exit :1537 — **Slice ①'s** scope, not §7's — so this
plan does not widen to close it. But D10 makes this slice the milestone close, and
a gap that no surface records is a gap that closes with the milestone. Task 6
therefore names it in the CHANGELOG limitations list and in the design's dated
exit disposition, with its ledger provenance, exactly as it names the deferred
parser-error record and §22.9:1314. *If a task has spare capacity, closing it is
one case in `byte-class-interpret-tests.sps` — compile and feed a machine whose
only case is a vacuous complement and assert both executors take the fallback for
every byte — and closing it is better than recording it.*

**D11 — Out of scope, from design §7 and §8, restated so no task widens.**
Trie/sequence **specialization**, unrolling, peephole, transition tables and
byte-class tables (§29:1743-1744, gated by §23.3:1369 behind reproducible compiled
benchmarks — `bench/` holds two `.gitkeep` files, so no §23 evidence can exist
yet). *(The shared-prefix **structure** is required and already shipped in Slice ②;
reading :1744 as "no prefix sharing in M3" is design §8's named mirror trap.)*
The structured parser-error record (`parser-error-node-name`, `-state-id`,
`-position-kind`) — so this slice's mismatch tests assert
`status`/`next`/`consumed`/`stream-offset`/`code` only, and that limitation is
**recorded** when discharging §25:1538-1540, not glossed. Widening the diagnostic
record to §16.4's seven fields (M7). Extending `machine-gen.sls` to draw class
matchers or sequence nodes (M7, §25:1605-1607). The state-ID-to-source-name debug
map (§17:963). The §16.2:884 unsupported-IR-versions check. Case-insensitive
`Content-Length`/`Transfer-Encoding`/`chunked` and the HTTP fixture's own byte
classes (`tchar`, `target-byte`, `field-value-byte`, `OWS`) — §25:1624 makes those
**Milestone 8**; M3 ships the mechanism, M8 spends it, so this slice's HTTP
fixture is the `version` production and nothing more. Cross-node prefix-state
sharing (§4.3). Any general lookahead or rewind (§10.6:546, §11.3:648). Any
`source-label` parameter added "for consistency". Re-doing all-byte coverage for
exact transitions or re-building split-point machinery — M3 re-points that rig.

**D12 — No new decision record.** Design §4.5 routes the diagnostic-code question
into the design document by design, and the Gate 0 discharge note records that
"§4.5's two resolutions stayed in this document by design and have no record".
`docs/decisions/README.md` excludes records that only restate the plan. Each
deliverable is already governed: the ambiguity check by 0017 point 4 + 0015
point 2 + design §4.5; the cycle extension by 0017's Consequences (prefix-level
analysis removed, reduces to the source-level self-loop); the multi-alternative
fixtures by 0017 point 4 + 0016 point 3 + 0015; the determinism pins by 0016's
Consequences + 0009. **0014-0017 have never been amended** (one commit,
`f29edf7`); if this slice ships anything that changes what they assert, that is a
dated amendment appended to the record, never a rewrite, and never a new `0018`.

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `src/byte-machine/verify.sls` (modify) | `pass-sequence-ambiguity` + `byte-prefix?` + `node-ambiguities`; the `'ambiguous-sequence-prefix` code; the `verify-machine` call; D1's two corrected comments | 1 |
| `src/byte-machine/verify.sls` (modify) | D6's one-line REPORT-guard edit; D7's invariant and over-rejection recorded at the site; the deferral comment corrected | 2 |
| `src/byte-machine/private/normal-ir.sls` (modify) | **comment only** — the trie guards' "Slice ③ rejects it as a diagnostic" note becomes "Slice ③ *has* rejected it; these are defense-in-depth for a caller who skips verification" | 1 |
| `src/byte-machine/interpret.sls` (modify) | **comment only** — same correction at `seq-step`'s guards | 1 |
| `test/common/verify-tests.sps` (modify) | ambiguity cases + the count fixtures; the two zero-progress cases; the renamed `combined3` case at 3 | 1, 2 |
| `test/common/interpret-tests.sps` (modify) | the two guard cases rewritten to the new reality (D5) | 1 |
| `test/common/normal-ir-tests.sps` | **unchanged by Task 1** — measured unaffected by the :894 pass (D5), which Task 1 confirms and records. Task 3 adds the branching-trie structural group | 1, 3 |
| `test/support/harness/byte-machine/test/http-version-machine.sls` (create) | both mismatch-mode `HTTP/1.0`⁄`HTTP/1.1` machines | 3 |
| `test/common/http-version-interpret-tests.sps` (create) | absolute outcomes through the interpreter, both modes | 3 |
| `test/common/differential-http-version-tests.sps` (create) | interpreter ≡ generated over a branching trie, split schedules | 4 |
| `test/common/determinism-http-version-tests.sps` (create) | §22.9 pins over a sequence machine | 5 |
| `test/fixtures/generated-http-version.golden.sls` (create) | the third committed golden, generated not written | 5 |
| `test/CMakeLists.txt` (modify) | six new lanes (three source+AOT pairs) | 3, 4, 5 |
| `test/support/cmake/SchemeMutationSuite.cmake` (modify) | new passes and mutations; **two re-anchors**; totals | 1-5 |
| `CHANGELOG.md`, `README.org`, `docs/plans/byte-machine-implementation-plan.md`, `docs/plans/milestone-3-design.md` (modify) | the milestone close-out across every status surface | 6 |

---

## Task 1: The ambiguous-terminal-prefix check (§16.2:894)

**Files:**
- Modify: `src/byte-machine/verify.sls` (new pass after `pass-overlap` at `:181-184`; call site in `verify-machine` at `:386-397`; comments at `:8-16` and `:176-180`)
- Modify: `src/byte-machine/private/normal-ir.sls:94-101` (comment only)
- Modify: `src/byte-machine/interpret.sls:63-66` (comment only)
- Test: `test/common/verify-tests.sps` (new group)
- Test: `test/common/interpret-tests.sps` — one import added at `:3-10`; the guard
  group at `:186-202` replaced by two groups (three diagnostic cases plus the two
  guard cases, whose **names must not change**); the
  `raises-interpret-assertion?` helper at `:180-185` stays and keeps both callers
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (six mutations into Pass 33; Pass 34's comment at `:4206-4217` corrected, its two pins untouched)

**Interfaces:**
- Consumes: `sequence-dispatch-node?`, `sequence-dispatch-node-cases`,
  `sequence-case-bytes`, `node-name`, `machine-nodes` — all already imported by
  `verify.sls` via `(byte-machine private ir)` (`verify.sls:22-23`, a whole-library
  import, so no import-list edit is needed).
- Produces: diagnostic code `'ambiguous-sequence-prefix`, reachable through the
  shipped `verification-diagnostics` / `diagnostic-code` accessors. No new export.

- [ ] **Step 1: Write the failing tests**

Append this group to `test/common/verify-tests.sps`, after the existing
`"sequence dispatch reaches every verifier arm"` group (which ends at `:789`) and
before `(harness-finish)` at `:791`. It reuses that group's shipped helpers
`errs`, `seq-alt`-style construction, `codes` (`:24`) and `has-code?` (`:25`).

```scheme
;; Milestone 3 Slice ③ Task 1: §16.2:894 sequence ambiguity. One alternative
;; being a terminal prefix of another is UNREPRESENTABLE (decision 0015 point
;; 2: a prefix state has no "accept here" slot), so it is rejected here rather
;; than left to the normalizer's internal guard. Duplicate alternatives are the
;; maximal case of the same relation -- `AB` is a terminal prefix of `AB` -- so
;; both shapes carry the one code design §4.5 allows. Reported once per
;; colliding PAIR, like pass-overlap (§16.4:937-943).
(define (amb-machine name alts extra-nodes)
  (make-machine name 'seq '() '() '() errs
    (append (list (make-sequence-dispatch-node 'seq
                    (map (lambda (a) (make-sequence-case (car a) (cdr a) #f)) alts)
                    (make-edge 'reject 'reexecute) #f #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            extra-nodes)
    'default-eof #f))
(define two-more (list (make-stop-node 'halt #f) (make-stop-node 'done #f)))
(define three-more (append two-more (list (make-stop-node 'more #f))))
;; Counters read the OBSERVED diagnostic list, never the fixture's own shape.
(define (ambiguity-count m)
  (length (filter (lambda (c) (eq? c 'ambiguous-sequence-prefix)) (codes m))))
(define nested-short-first
  (amb-machine 'nest '(((65) . stop) ((65 66) . halt) ((65 66 67) . done)) two-more))
(define nested-long-first
  (amb-machine 'nest-rev '(((65 66 67) . done) ((65 66) . halt) ((65) . stop)) two-more))

(harness-group "sequence ambiguity (§16.2:894)"
  (lambda ()
    (harness-case "an alternative that is a terminal prefix of another is rejected"
      (lambda ()
        (let ((m (amb-machine 'amb '(((65 66) . stop) ((65 66 67) . halt))
                              (list (make-stop-node 'halt #f)))))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "ambiguous-sequence-prefix" (has-code? m 'ambiguous-sequence-prefix)))))
    (harness-case "two identical alternatives are the maximal case of the same relation"
      (lambda ()
        (let ((m (amb-machine 'dup '(((65 66) . stop) ((65 66) . halt))
                              (list (make-stop-node 'halt #f)))))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "ambiguous-sequence-prefix" (has-code? m 'ambiguous-sequence-prefix)))))
    ;; The count fixtures. SUMMED over both declaration orders, deliberately:
    ;; a short-first list is caught by a one-directional test as well as by a
    ;; correct one, so a per-ordering check leaves the one-directional
    ;; mutation's whole failure set inside the never-run mutation's -- the
    ;; subsumed shape AGENTS.md names. The sum separates them (6 / 3 / 0).
    (harness-case "the prefix test asks both directions, counted over both declaration orders"
      (lambda ()
        (check-equal "ambiguity count over both orderings"
                     (+ (ambiguity-count nested-short-first)
                        (ambiguity-count nested-long-first))
                     6)))
    ;; The over-rejection direction, which nothing else in this file tests: a
    ;; SHARED first byte is not ambiguity (§10.6:544 permits shared nonterminal
    ;; prefixes; the trie merges them), and a check that cannot tell the two
    ;; apart would reject every branching machine this slice ships.
    (harness-case "alternatives that merely share a prefix are not ambiguous"
      (lambda ()
        (check-equal "ambiguity count"
                     (ambiguity-count
                      (amb-machine 'ok '(((65 66) . stop) ((65 67) . halt) ((88 89) . done))
                                   two-more))
                     0)))
    ;; The pair ENUMERATION, mirroring pass-overlap's own three enumeration
    ;; mutations. A nested family of three (3 pairs) plus a disjoint pair
    ;; (1 pair) = 4; the three ways to break the walk give 2, 3 and 9, all
    ;; distinct and all distinct from the two mutations above.
    (harness-case "every pair is enumerated once, across a nested family and a disjoint one"
      (lambda ()
        (check-equal "ambiguity count"
                     (ambiguity-count
                      (amb-machine 'fam '(((65) . stop) ((65 66) . halt) ((65 66 67) . done)
                                          ((88) . more) ((88 89) . stop))
                                   three-more))
                     4)))
    (harness-case "a byte-dispatch machine contributes no sequence ambiguity"
      (lambda ()
        (check-equal "ambiguity count"
                     (ambiguity-count (machine (one-byte-nodes (make-edge 'reject 'reexecute))))
                     0)))))
```

Rewrite `interpret-tests.sps`'s guard group (`:186-202`) to the reality D5
measured. The predicate helper `raises-interpret-assertion?` (`:180-185`) **stays
and keeps both its callers** — what changes is only how the machine reaches
`seq-step`, because `interp` can no longer carry an ambiguous one. Three cases are
added for the diagnostic; the two guard cases keep their **names** (Pass 34's two
pins depend on their FAIL details, and only the enclosing group's name changes):

```scheme
;; Milestone 3 Slice ③ Task 1. §16.2:894 now rejects both unrepresentable shapes
;; at verify-machine, and make-interpreted-machine refuses an unverified machine
;; (interpret.sls:25-28) -- so `interp` can no longer carry one this far. The
;; guards below are NOT thereby dead: normalize-machine and make-interpreted-
;; machine both remain reachable by a caller that skips verification, and
;; (byte-machine private ir) exports make-verification-result, so that caller is
;; expressible here. Forging an ok? verification the verifier would never
;; produce is precisely the shape the guards exist to catch, and witnessing them
;; that way keeps SchemeMutationSuite.cmake's two Pass 34 guard mutations alive
;; with their pins unchanged.
(define (unverified m) (make-verification-result #t '() m))
(define (interp-unverified m) (make-interpreted-machine (unverified m)))

(harness-group "§16.2:894 rejects both unrepresentable shapes before the interpreter"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is a verification diagnostic"
      (lambda ()
        (let ((v (verify-machine (seq-m 'amb '(((65 66) . stop) ((65 66 67) . halt))
                                        'reexecute (list (make-stop-node 'halt #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "ambiguous-sequence-prefix"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'ambiguous-sequence-prefix))
                         (verification-diagnostics v))))))
    (harness-case "two identical alternatives are the same diagnostic"
      (lambda ()
        (let ((v (verify-machine (seq-m 'dup '(((65 66) . stop) ((65 66) . halt))
                                        'reexecute (list (make-stop-node 'halt #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "ambiguous-sequence-prefix"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'ambiguous-sequence-prefix))
                         (verification-diagnostics v))))))
    (harness-case "handing the rejected machine to the interpreter is a contract violation"
      (lambda ()
        (check-raises "unverified-machine"
                      (lambda (e)
                        (and (byte-machine-contract-condition? e)
                             (eq? (byte-machine-contract-condition-code e) 'unverified-machine)
                             (eq? (byte-machine-contract-condition-who e) 'make-interpreted-machine)))
                      (lambda ()
                        (interp (seq-m 'amb2 '(((65 66) . stop) ((65 66 67) . halt))
                                       'reexecute (list (make-stop-node 'halt #f))))))))))

(harness-group "the interpreter's own guards still fire for a caller that skips verification"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (raises-interpret-assertion? "ambiguous terminal prefix")
                      (lambda ()
                        (feed-bytes (interp-unverified
                                     (seq-m 'amb '(((65 66) . stop) ((65 66 67) . halt))
                                            'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (raises-interpret-assertion? "duplicate sequence alternative")
                      (lambda ()
                        (feed-bytes (interp-unverified
                                     (seq-m 'dup '(((65 66) . stop) ((65 66) . halt))
                                            'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))))
```

> **Do not rename either guard case.** `SchemeMutationSuite.cmake:4218-4228` and
> `:4230-4245` are pinned to their FAIL details, which begin with the case name.
> **Measured** with the rewrite above: both mutants still fail with byte-identical
> details, so both pins are left exactly as they are. What *does* need a one-line
> touch is the Pass 34 comment at `:4206-4217`, which describes the cases as
> reached through the ordinary construction path — correct it to name the forged
> verification.

**One import must be ADDED.** Checked: `interpret-tests.sps:3-10` already imports
`(byte-machine private conditions)` (the contract accessors) and
`(byte-machine verify)` (`diagnostic-code`, `verification-ok?`,
`verification-diagnostics`) — but **not** `make-verification-result`. Add it, and
add only it:

```scheme
        (byte-machine private conditions)
        (only (byte-machine private ir) make-verification-result))
```

Reaching into `(byte-machine private ir)` from a test program is house
convention, not a new liberty: `graph-tests.sps` and `ir-tests.sps` both do it,
and `ir.sls:36` exports the constructor deliberately.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
make build && ctest --preset release -R 'verify.rejections|unit.interpret' --output-on-failure
```

Expected: **FAIL**, at exactly `cases=55 failed-cases=4 checks=72 failures=6` on
`verify.rejections` — measured — with these six failing checks and no others:

```
sequence ambiguity (§16.2:894).an alternative that is a terminal prefix of another is rejected: rejected -- expected a true value
sequence ambiguity (§16.2:894).an alternative that is a terminal prefix of another is rejected: ambiguous-sequence-prefix -- expected a true value
sequence ambiguity (§16.2:894).two identical alternatives are the maximal case of the same relation: rejected -- expected a true value
sequence ambiguity (§16.2:894).two identical alternatives are the maximal case of the same relation: ambiguous-sequence-prefix -- expected a true value
sequence ambiguity (§16.2:894).the prefix test asks both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 0
sequence ambiguity (§16.2:894).every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 0
```

The `"merely share a prefix"` and `"a byte-dispatch machine contributes none"`
cases **pass already**, both expecting 0 and getting 0 with no pass at all. That
is why neither can carry a pin on its own and why the plan does not treat them as
the task's red state — they are the over-rejection guard, and they only start
discriminating once the pass exists.

`unit.interpret` fails at `cases=21 failed-cases=3 checks=40` on the three new
diagnostic cases; its two guard cases pass throughout, before and after, because
the forged-verification path does not depend on the new verifier pass.

- [ ] **Step 2b: Run the equivalence control BEFORE implementing (D3)**

This is the control the plan owes for D3's claim, and it must be run against the
implementation once it exists — but write it now so it is not skipped. Save as a
scratch file outside the repository (never `git add` it):

```scheme
;; D3 control: does a source-level pairwise terminal-prefix test accept exactly
;; the alternative-sets the normalizer's trie guards accept? Exhaustive over
;; every nonempty subset of size <= 3 of the 14 binary strings of length 1..3.
(import (rnrs) (byte-machine graph) (byte-machine verify) (byte-machine private normal-ir))
(define (byte-prefix? a b)
  (cond ((null? a) #t) ((null? b) #f)
        ((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b))) (else #f)))
(define (pairwise-ambiguous? seqs)
  (let outer ((ss seqs))
    (cond ((null? ss) #f)
          (else (let inner ((rest (cdr ss)))
                  (cond ((null? rest) (outer (cdr ss)))
                        ((or (byte-prefix? (car ss) (car rest))
                             (byte-prefix? (car rest) (car ss))) #t)
                        (else (inner (cdr rest)))))))))
(define words
  (append (list '(0) '(1))
          (list '(0 0) '(0 1) '(1 0) '(1 1))
          (list '(0 0 0) '(0 0 1) '(0 1 0) '(0 1 1) '(1 0 0) '(1 0 1) '(1 1 0) '(1 1 1))))
(define (subsets-upto lst k)
  (cond ((= k 0) '(())) ((null? lst) '(()))
        (else (append (map (lambda (s) (cons (car lst) s)) (subsets-upto (cdr lst) (- k 1)))
                      (subsets-upto (cdr lst) k)))))
(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end" #f))
(define (mk seqs)
  (make-machine 'm 'seq '() '() '() (list eof-decl)
    (list (make-sequence-dispatch-node 'seq
            (map (lambda (w) (make-sequence-case w 'a #f)) seqs)
            (make-edge 'a 'reexecute) #f #f)
          (make-stop-node 'a #f))
    'default-eof #f))
(define (trie-raises? seqs)
  (guard (e (#t #t))
    (normalize-machine (verification-machine (verify-machine (mk seqs)))) #f))
(define cases (filter pair? (subsets-upto words 3)))
(display (list 'case-count (length cases))) (newline)
(let loop ((cs cases) (n 0) (dis 0))
  (if (null? cs)
      (begin (display (list 'checked n 'disagreements dis)) (newline))
      (let* ((seqs (car cs)) (p (pairwise-ambiguous? seqs)) (t (trie-raises? seqs)))
        (loop (cdr cs) (+ n 1) (if (eq? p t) dis (+ dis 1))))))
```

```bash
chez --libdirs "src:test/support/harness" --script <scratch>/d3-control.ss
```

Expected, **exactly**: `(case-count 469)` then `(checked 469 disagreements 0)`.
Any nonzero disagreement count is a plan defect — record it in the ledger and
stop, because it means the pass and the guards disagree about what is
unrepresentable and one of them is wrong.

- [ ] **Step 3: Write the pass**

In `src/byte-machine/verify.sls`, insert immediately after `pass-overlap` (which
ends at `:184`) and before `;; PASS 4: reachability from entry.`:

```scheme
  ;; Sequence ambiguity (§16.2:894), an unnumbered pass beside PASS 3 because
  ;; §16.2 lists :893 and :894 adjacently and because renumbering PASS 4-7 would
  ;; stale thirteen comment references for nothing. pass-eof-execution below is
  ;; the shipped precedent for an unnumbered pass.
  ;;
  ;; "After prefix analysis" is what the pairwise test below IS: one alternative
  ;; being a terminal prefix of another is decidable from the source byte lists
  ;; alone, so this pass never inspects the lowered graph and §17:951's
  ;; verify-before-normalize ordering is preserved. Measured equivalent to the
  ;; normalizer's three trie guards (normal-ir.sls:102-116) over all 469
  ;; nonempty alternative-sets of size <= 3 drawn from the 14 binary strings of
  ;; length 1..3: zero disagreements.
  ;;
  ;; Duplicate alternatives are the MAXIMAL case of the same relation (`AB` is a
  ;; terminal prefix of `AB`), so both shapes carry the one new code design §4.5
  ;; allows. Alternatives that merely SHARE a nonterminal prefix -- `AB` and
  ;; `AC` -- are explicitly legal (§10.6:544); the trie merges them, and a check
  ;; that could not tell the two apart would reject every branching machine.
  (define (byte-prefix? a b)
    (cond ((null? a) #t)
          ((null? b) #f)
          ((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b)))
          (else #f)))
  ;; One diagnostic per COLLIDING PAIR, enumerated i < j so a pair is reported
  ;; once -- pass-overlap's convention above, and §16.4:937-943's one finding
  ;; per decision. Every diagnostic a node contributes shares that node's
  ;; (code, node, message) triple, so no pair carries an identity of its own and
  ;; the relative order of two diagnostics from one node is not promised.
  ;;
  ;; The bindings are deliberately NOT node-overlaps' (`ss`/`outer`/`rest`/
  ;; `inner`/`out`): three shipped mutations pin single lines of that skeleton,
  ;; and a structural clone takes each from one occurrence to two, failing the
  ;; suite with "pattern occurs 2 times ... expected 1" (§0 D8b).
  (define (node-ambiguities n)
    (let ((alts (map sequence-case-bytes (sequence-dispatch-node-cases n))))
      (let scan ((as alts) (found '()))
        (if (null? as)
            found
            (scan (cdr as)
                  (let against ((others (cdr as)) (found found))
                    (if (null? others)
                        found
                        (against (cdr others)
                                 (if (or (byte-prefix? (car as) (car others))
                                         (byte-prefix? (car others) (car as)))
                                     (cons (make-diagnostic 'ambiguous-sequence-prefix (node-name n)
                                                            "one alternative is a terminal prefix of another")
                                           found)
                                     found)))))))))
  (define (pass-sequence-ambiguity m)
    (apply append
           (map (lambda (n) (if (sequence-dispatch-node? n) (node-ambiguities n) '()))
                (machine-nodes m))))
```

Wire it in at `verify-machine` (`:386-397`), immediately after `pass-overlap`:

```scheme
                          (append (pass-names machine)
                                  (pass-overlap machine)
                                  (pass-sequence-ambiguity machine)
                                  (pass-reachability machine)
```

- [ ] **Step 4: Correct the three stale deferral comments in place (D1, D5)**

These are **instructions** in live code, not records: AGENTS.md requires them
corrected in place, because leaving a false one is a landmine and what they used
to say is in git.

`verify.sls:176-180` — replace the whole comment above `pass-overlap`:

```scheme
  ;; NOT extended to sequence-dispatch-node?, and not deferred either: whether
  ;; two sequence ALTERNATIVES collide is §16.2:894 ambiguity, which
  ;; pass-sequence-ambiguity below owns. Decision 0017 point 4 keeps :893 and
  ;; :894 as two entries with two checks and two codes, and the predicates
  ;; genuinely differ -- this pass compares canonical matcher byte SETS within
  ;; one byte-dispatch node; that one compares the prefix relation between byte
  ;; STRINGS. A sequence node is invisible to this pass permanently.
```

`verify.sls:8-16` — the file header's Slice ② paragraph, corrected to name the
new pass and drop "design §7 assigns it to Slice ③":

```scheme
;;; Milestone 3 Slice ② added the sixth node kind, sequence-dispatch (§9.1:297,
;;; §10.6:542-546), to every one of these passes EXCEPT overlap: its case
;;; targets and mismatch edge are out-targets and eof-targets for name
;;; resolution and reachability, its mismatch edge's reexecute mode joins the
;;; zero-progress walk, and its eof-target joins the EOF-shape and :908/:909
;;; terminal checks. Milestone 3 Slice ③ added pass-sequence-ambiguity
;;; (§16.2:894) and taught pass-zero-progress's REPORT set the sixth kind
;;; (§25:1533). Cross-alternative sequence collision stays out of pass-overlap
;;; permanently -- it is :894's, not :893's; see pass-overlap's own filter.
```

`normal-ir.sls:94-101` — the trie-guard comment, corrected and given its reason
for staying:

```scheme
  ;; The two guards below are internal invariants, not user diagnostics. Decision
  ;; 0015 point 2: a prefix state has no "accept here" slot, so a trie node that
  ;; is both terminal and interior is UNREPRESENTABLE rather than merely
  ;; unwanted. Milestone 3 Slice ③'s pass-sequence-ambiguity (§16.2:894) now
  ;; rejects both shapes at verify-machine, so a verified machine cannot reach
  ;; them. They are KEPT as defense-in-depth because normalize-machine is a
  ;; public entry point that does not itself verify: a caller who skips
  ;; verification must fail loudly here rather than silently lose an
  ;; alternative. (byte-machine interpret)'s seq-step carries the same two.
```

`interpret.sls:63-66` — the same correction at `seq-step`:

```scheme
                ;; The same two internal invariants the normalizer's trie asserts,
                ;; for the same reason (decision 0015 point 2): a prefix position
                ;; that both accepts and continues has no representation here
                ;; either. Slice ③'s §16.2:894 pass rejects both shapes before
                ;; this point, and make-interpreted-machine refuses an unverified
                ;; machine -- so these are unreachable through the public path and
                ;; kept as defense-in-depth, exactly as normal-ir.sls's are.
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
make build && ctest --preset release -R 'verify.rejections|unit.interpret|unit.normal-ir' --output-on-failure
```

Expected: **PASS**, all three lanes (×2 for source/aot = six tests), with these
**exact** summary counts — all three measured during plan authoring by running the
blocks above verbatim against a scratch copy carrying the new pass:

| suite | on `main` | after this task |
| --- | --- | --- |
| `verify.rejections` | `cases=49 checks=64` | **`cases=55 checks=72`** |
| `unit.interpret` | `cases=18 checks=35` | **`cases=21 checks=40`** |
| `unit.normal-ir` | `cases=35 checks=73` | **`cases=35 checks=73`** (unchanged) |

`unit.normal-ir` must be green **and identical** without any edit to
`normal-ir-tests.sps` — that is D5's measured prediction, and a failure or a
changed count there means D5 is wrong and the task must stop and record it.

- [ ] **Step 6: Run the whole suite**

```bash
make test-all
```

Expected: **80/80** — no new lanes yet; this task adds only cases to existing
programs.

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: `43 passes, 223 mutations`, no `UNCAUGHT`, no `FATAL`. Adding checks to
`verify-tests.sps` widens Pass 33's pins; if any mutation reports UNCAUGHT or
caught-for-the-wrong-reason here, that is the widening and it is fixed in Step 8's
sweep, not worked around.

- [ ] **Step 7: Add the six mutations**

Append to Pass 33 (`SchemeMutationSuite.cmake`, between `:4055` and the
`byte_machine_mutation_run` call at `:4057`). Six, not three: the pass makes six
decisions, and `pass-overlap`'s own three *enumeration* mutations (`:3187`,
`:3212`, `:3225`) are the shipped precedent for the last three — a pairwise pass
that visits the wrong pairs is a real defect and nothing else here would notice.

Every count below was **measured** during plan authoring against the fixtures
Step 1 adds. Each mutant has at least one record no other emits, which is what the
pins are anchored to:

| mutant | `both orderings` (correct 6) | `merely share` (correct 0) | `every pair` (correct 4) | unique pin |
| --- | --- | --- | --- | --- |
| pass never wired | **0** | 0 | 0 | `both orderings … got 0` |
| test is one-directional | **3** | 0 | 4 | `both orderings … got 3` |
| `byte-prefix?` stops at byte 1 | 6 | **1** | 4 | `merely share … got 1` |
| outer scan does not advance | 4 | 0 | **2** | `every pair … got 2` |
| inner scan does not advance | 4 | 0 | **3** | `every pair … got 3` |
| an alternative is compared with itself | 12 | 3 | **9** | `every pair … got 9` |

Note what the table forced: the one-directional mutant's records are a **subset**
of the never-wired mutant's on any *per-ordering* check, because a short-first
declaration is caught by a one-directional test too. Summing both orderings into
one check is the count-don't-witness remedy AGENTS.md prescribes, and it is why
Step 1's fixture set has a `both orderings` case rather than two ordering cases.

```cmake
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the §16.2:894 sequence-ambiguity pass is never run"
  FIND [[                                  (pass-sequence-ambiguity machine)]]
  REPLACE [[                                  '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 0")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the terminal-prefix test is one-directional (§16.2:894)"
  # Comparison-caught. The pair test must ask BOTH directions: a caller may
  # declare the longer alternative first, and normal-ir-tests.sps's own
  # "reverse order" case exists because the trie has two distinct guard sites
  # for exactly this. Measured: the summed check goes 6 -> 3, a value no other
  # mutant in this pass produces on it. A per-ordering check would NOT separate
  # this mutation from "never run" -- its records would be a strict subset.
  FIND [[                                 (if (or (byte-prefix? (car as) (car others))
                                         (byte-prefix? (car others) (car as)))]]
  REPLACE [[                                 (if (byte-prefix? (car as) (car others))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "both directions, counted over both declaration orders: ambiguity count over both orderings -- expected 6, got 3")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the prefix relation degenerates to a first-byte test (§16.2:894)"
  # The OVER-rejection direction, which no other mutation in this pass reaches:
  # with the recursion collapsed, any two alternatives sharing a first byte are
  # called ambiguous, and every branching machine this milestone ships would be
  # refused. Measured: the well-formed AB/AC/XY fixture goes 0 -> 1.
  FIND [[((= (car a) (car b)) (byte-prefix? (cdr a) (cdr b)))]]
  REPLACE [[((= (car a) (car b)) #t)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "alternatives that merely share a prefix are not ambiguous: ambiguity count -- expected 0, got 1")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only the first sequence alternative is compared against the others"
  # The sequence twin of pass-overlap's ":3187" enumeration mutation. Measured
  # on the nested-family fixture: 4 -> 2.
  FIND [[(scan (cdr as)]]
  REPLACE [[(scan '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 2")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence alternative's collisions after the first are dropped"
  # The twin of pass-overlap's ":3212". Measured: 4 -> 3. Note this and the
  # mutation above are indistinguishable on the summed check (both 4) and on
  # either per-ordering count (both 2); only the nested-family fixture, which
  # makes the two walks visit different pair sets, separates them.
  FIND [[(against (cdr others)]]
  REPLACE [[(against '()]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 3")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a sequence alternative is compared against itself"
  # The twin of pass-overlap's ":3225". Every alternative is a terminal prefix
  # of itself, so self-comparison adds exactly one spurious diagnostic per
  # alternative. Measured: 4 -> 9 on a five-alternative fixture.
  FIND [[(let against ((others (cdr as)) (found found))]]
  REPLACE [[(let against ((others as) (found found))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "every pair is enumerated once, across a nested family and a disjoint one: ambiguity count -- expected 4, got 9")
```

Update `EXPECTED_MUTATIONS` at `SchemeMutationSuite.cmake:667` from the
**measured** total the next step reports. `EXPECTED_PASSES` (`:666`) stays 43 —
these six join an existing pass.

- [ ] **Step 7b: Correct Pass 34's stale comment**

`SchemeMutationSuite.cmake:4206-4217` describes its two guard mutations' witnesses
as reached through the ordinary construction path. After Step 1's rewrite they are
reached through a forged verification instead. **The two pins and both
FIND/REPLACE pairs stay exactly as they are** — measured, both mutants still fail
with byte-identical details — but the comment is a live instruction about how the
witness works, and AGENTS.md corrects those in place. Add a sentence naming
`interp-unverified` and `make-verification-result`, and say why the ordinary path
no longer reaches the guards (§16.2:894 rejects the shape first).

- [ ] **Step 8: Sweep the pins of Pass 33, Pass 34 AND Pass 35, in BOTH directions**- [ ] **Step 8: Sweep Pass 33's pins in BOTH directions**

Mandatory, not optional, and it covers **three** passes rather than one. AGENTS.md
records that adding a mutation *or a check* to a lane widens every existing pin's
collision set silently — and this task changes the SPEC-lane **programs** of three
passes, not just Pass 33's:

| pass | SPEC lane | program this task edits | mutations |
| --- | --- | --- | --- |
| 33 | `byte-machine.verify.rejections.chez.source` | `verify-tests.sps` (+6 cases) | 34 → **40** |
| 34 | `byte-machine.unit.interpret.chez.source` | `interpret-tests.sps` (+3 cases, guard group renamed) | 12 |
| 35 | `byte-machine.unit.normal-ir.chez.source` | *(unchanged by this task — swept in Task 3)* | 22 |

So the sweep here is 40 × 39 = 1560 ordered pairs for Pass 33 plus 12 × 11 = 132
for Pass 34. Pass 35 is untouched by Task 1 and is swept in Task 3, which is the
task that edits `normal-ir-tests.sps`. Recording that split matters: a sweep
scoped to "the pass I added mutations to" would miss Pass 34 entirely, and Pass
34 is the one whose two pins this task came closest to orphaning.

Method — the one Pass 33's own header records at `:3081-3090`: apply each mutation
to a staged copy, capture the SPEC lane's full stdout+stderr, then re-judge every
pin through `byte_machine_mutation_verdict` against every **other** mutant's
captured output.

Capture one mutant's output with:

```bash
chez --script test/support/launchers/chez-source.ss --library-root test/support/harness --library-root src --object-guard <empty-dir> --program test/common/verify-tests.sps
```

Run it on a **scratch copy** of the tree; the suite itself never mutates the
source tree and neither should the sweep.

Run the control on the merge base (`git merge-base HEAD main`): a pass that is
collision-free there and colliding at HEAD is this branch's doing, which
distinguishes an introduced defect from inherited debt. For every collision,
classify by AGENTS.md's **three** buckets — under-anchored, subsumed, or separable
but deliberately declined — comparing whole FAIL **records**, not lines. Rule out
under-anchoring by exhaustion ("no record it emits is unique to it"), not by
inspection. A mutant with **zero unique FAIL records** means the spec is
under-specified: try the count-don't-witness remedy before writing "subsumed", and
**re-sweep after each fix**, because a first attempt can collide with a third
mutant. Record any surviving residue **in the tree beside its pin, named by
mutation LABEL**.

Expected result: `43 passes, 229 mutations` (223 + six), no `UNCAUGHT`, no
`FATAL`, nine `SURVIVES (expected)` — the pass count does **not** move, because
all six join Pass 33. Write only the measured number into `:667`; `229` is
arithmetic to check, not a fact to copy.

- [ ] **Step 9: Commit**

```bash
git add src/byte-machine/verify.sls src/byte-machine/private/normal-ir.sls src/byte-machine/interpret.sls test/common/verify-tests.sps test/common/interpret-tests.sps test/support/cmake/SchemeMutationSuite.cmake && git commit -m "feat(verify): reject ambiguous terminal prefixes (§16.2:894)"
```

---

## Task 2: The cycle extension (§25:1533) and the three anchors it moves

**Files:**
- Modify: `src/byte-machine/verify.sls:209-245` (the REPORT guard at `:241`, and the comment above `reexec-targets`' sequence arm)
- Test: `test/common/verify-tests.sps` (two new cases; one renamed case with a new expectation)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (**two re-anchors** at `:3235` and `:3800`, one new mutation)

**Interfaces:**
- Consumes: `sequence-dispatch-node?` (already imported), `reaches-self?`,
  `reexec-targets` — both local to `pass-zero-progress`.
- Produces: `'zero-progress-cycle` now also attributed to sequence nodes. No new
  code, no new export.

- [ ] **Step 1: Write the failing tests**

Append to `test/common/verify-tests.sps`, in the existing `"sequence dispatch
reaches every verifier arm"` group so it sits beside the arm-3 case it
complements. Both halves of exit criterion §25:1540 get a case, because rejecting
the consuming one fails the criterion just as surely as accepting the
zero-progress one.

```scheme
    ;; Milestone 3 Slice ③ Task 2: §25:1533's cycle extension, and BOTH halves
    ;; of exit criterion §25:1540. Slice ② taught reexec-targets to see THROUGH
    ;; a sequence node while deliberately leaving it out of the REPORTED set;
    ;; this is the report. Measured on `main` before the extension: the first
    ;; fixture verified ok #t with ZERO diagnostics and HUNG both executors
    ;; (exit 124 under timeout), while the byte-identical shape built from a
    ;; byte-dispatch node reported zero-progress-cycle.
    (harness-case "a sequence node whose reexecute mismatch edge targets itself is a zero-progress cycle"
      (lambda ()
        (let ((m (make-machine 'selfseq 'seq '() '() '() errs
                   (list (seq-node (one-alt '(65 66) 'stop) (make-edge 'seq 'reexecute) #f)
                         (make-stop-node 'stop #f))
                   'default-eof #f)))
          (check "rejected" (not (verification-ok? (verify-machine m))))
          (check "zero-progress-cycle" (has-code? m 'zero-progress-cycle)))))
    ;; The other half of :1540. The mismatch edge's MODE is the whole decision:
    ;; an advance edge consumes the mismatching byte, so the loop makes
    ;; progress and must verify clean. reexec-targets already discriminates on
    ;; mode (verify.sls:227-229); this case is what stops the report guard from
    ;; being widened past it.
    (harness-case "the same self-target with an advance mismatch edge is a consuming cycle and passes"
      (lambda ()
        (let ((v (verify-machine
                  (make-machine 'advseq 'seq '() '() '() errs
                    (list (seq-node (one-alt '(65 66) 'stop) (make-edge 'seq 'advance) #f)
                          (make-stop-node 'stop #f))
                    'default-eof #f))))
          (check "ok" (verification-ok? v))
          (check-equal "diagnostic count" (length (verification-diagnostics v)) 0))))
```

Then edit the shipped `combined3` case at `verify-tests.sps:688-713`. Rename it
and change its expectation from 2 to 3, and replace its comment with the measured
four-way table:

```scheme
    (harness-case "a byte-dispatch self-loop, a dispatch-through-sequence cycle and the sequence node itself are three zero-progress cycles"
      (lambda ()
        ;; Count-don't-witness, and Slice ③ makes it four-way. Measured against
        ;; this one check:
        ;;   correct code                                       -> 3
        ;;   PASS 5's REPORT guard loses its sequence clause     -> 2
        ;;   reexec-targets loses its sequence arm (arm 3)       -> 1
        ;;   PASS 5's report conditional replaced by (if #f      -> 0
        ;; 'x's case and fallback both reexecute into itself, a decision only
        ;; the last of those touches; 'start -> 'seq -> 'start is the cycle the
        ;; walk must see THROUGH; and 'seq itself is what Slice ③ added to the
        ;; REPORTED set.
        (check-equal "zero-progress-cycle count"
                     (length (filter (lambda (c) (eq? c 'zero-progress-cycle))
                                     (codes
                                      (make-machine 'combined3 'x '() '() '() errs
                                        (list (make-byte-dispatch-node 'x
                                                (list (make-byte-case (make-exact-byte-matcher 0)
                                                                      (make-edge 'x 'reexecute) #f))
                                                (make-edge 'x 'reexecute) #f #f)
                                              (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                                              (make-edge 'seq 'reexecute) #f))
                                                        (make-edge 'seq 'reexecute))
                                              (seq-node (one-alt '(1 2) 'stop) (make-edge 'start 'reexecute) #f)
                                              (make-stop-node 'stop #f)
                                              (make-error-node 'reject 'rejected #f))
                                        'default-eof #f))))
                     3)))
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
make build && ctest --preset release -R 'verify.rejections' --output-on-failure
```

Expected: **FAIL**, with these three failures and no others:
- `a sequence node whose reexecute mismatch edge targets itself is a zero-progress cycle: rejected -- expected a true value`
- the same case's `zero-progress-cycle` check
- `a byte-dispatch self-loop, a dispatch-through-sequence cycle and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 2`

The advance-mode case **passes already** — it is the regression guard, and its
passing before the change is the point.

- [ ] **Step 3: Make the one-line change**

`src/byte-machine/verify.sls:241`:

```scheme
                     (if (and (or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))
                              (reaches-self? (node-name n)))
```

- [ ] **Step 4: Correct the deferral comment and record D7's invariant at the site**

Replace the comment above `reexec-targets`' sequence arm. **It is at
`verify.sls:209-226` on `main`, and Task 1 moves it** — Task 1 inserts the new
pass and its comment ahead of it, so by the time this task runs the block sits
roughly 48 lines lower. Find it by its text
(`rg -n "Only the mismatch edge can be reexecute" src/byte-machine/verify.sls`),
not by the line number this plan cites; every `verify.sls` line number in Task 2
is stated as of `main` and is stale the moment Task 1 lands.
Its first half is an **instruction** that is now false and gets corrected; its
second half is a dated **record** of a measurement and is preserved as such, with
its disposition appended rather than its wording edited.

```scheme
              ;; Only the mismatch edge can be reexecute; every case edge
              ;; advances by construction (§10.6:546). This teaches the WALK to
              ;; see through a sequence node, and Milestone 3 Slice ③ added the
              ;; sixth kind to the REPORTED set below (§25:1533), so a
              ;; self-targeting reexecute mismatch edge is now flagged.
              ;;
              ;; Why the source-level walk is exact enough at lowered
              ;; granularity: NO ZERO-WIDTH EDGE CAN ENTER A POSITION->=1 PREFIX
              ;; STATE. Every trie edge advances, so a prefix state at position
              ;; k >= 1 is reached only by consuming a byte; the only zero-width
              ;; edge out of any sequence-derived state is the shared mismatch
              ;; edge this arm returns. The lowered zero-width cycle set is
              ;; therefore exactly the source-level one and no position->=1
              ;; state can be a cycle MEMBER -- which is why verification never
              ;; needs the lowered graph (§17:951). Design §7's phrasing
              ;; ("positions >=1 reach position 0 only after an advance") is
              ;; about the path INTO the state, not the edge out of it, and is
              ;; not the load-bearing property.
              ;;
              ;; KNOWN, DELIBERATE OVER-REJECTION, inherited not introduced:
              ;; reaches-self? is a pure edge walk and never asks whether the
              ;; arm closing the cycle is reachable for any byte. A sequence
              ;; node whose alternatives' first bytes cover all 256 values has a
              ;; dead root fallback and cannot loop, yet is reported. Measured:
              ;; 256 alternatives (b 0) -> stop, mismatch reexecute -> itself,
              ;; terminates on every input. The incumbent byte-dispatch
              ;; analysis is already exactly this conservative -- a node whose
              ;; single case is (make-byte-range-matcher 0 255) with a
              ;; reexecute self-fallback reports zero-progress-cycle today,
              ;; measured -- so this preserves a uniform shipped conservatism.
              ;; Making it exact would need the same reachability refinement for
              ;; byte-dispatch fallbacks and would change existing verdicts.
              ;;
              ;; Fix wave 2 (Important 1), measured 2026-08-30 under Slice ②,
              ;; preserved as the record of what was true then: a sequence node
              ;; whose mismatch edge reexecutes into itself -- one alternative,
              ;; no other nodes -- verified with ok #t and zero diagnostics,
              ;; where the byte-identical shape built from a byte-dispatch node
              ;; reported zero-progress-cycle. Feeding it one byte that does not
              ;; match the alternative's first byte did not return: reproduced
              ;; under a timeout in both the interpreted lane
              ;; (parser-feed-op!'s `(loop pos)`, runtime.sls:200) and the
              ;; generated lane (compile.sls's emitted `(loop pos <target>
              ;; off)` fallback), since neither has a local cycle guard and both
              ;; rely on this REPORT set. CLOSED by Slice ③'s extension above.
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
make build && ctest --preset release -R 'verify.rejections' --output-on-failure
```

Expected: **PASS**, both lanes, at exactly `cases=57 checks=76` — measured, by
running Tasks 1 and 2's blocks verbatim against a scratch copy carrying both
`verify.sls` edits. (Task 1 left it at 55/72; this task adds two cases and four
checks.)

- [ ] **Step 6: Re-anchor the two broken mutations and add the new one**

**Two** shipped `FIND`s break here, not one, and they are byte-identical to each
other — which is why a per-LABEL reading finds only the first (§0 D8).

`SchemeMutationSuite.cmake:3235`, LABEL `"verify: zero-progress detection never
fires"`. Keep LABEL, REPLACE and the pin; replace only the FIND:

```cmake
  FIND [[(if (and (or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))
                              (reaches-self? (node-name n)))]]
  REPLACE [[(if #f]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a reexecute self-loop is a zero-progress cycle: zero-progress-cycle"
```

`SchemeMutationSuite.cmake:3585`, LABEL `"verify: a pause-only zero-progress cycle
is not flagged"`. Its REPLACE must be rewritten too, not only its FIND: the
shipped `REPLACE [[(if (and (byte-dispatch-node? n) (reaches-self? (node-name n)))]]`
drops the pause clause *and* — against the widened guard — the sequence clause,
which makes it a second copy of the new mutation below and destroys both pins'
uniqueness. Narrow it to drop **only** the pause clause, which is what its LABEL
says it does:

```cmake
  FIND [[(if (and (or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))
                              (reaches-self? (node-name n)))]]
  REPLACE [[(if (and (or (byte-dispatch-node? n) (sequence-dispatch-node? n))
                              (reaches-self? (node-name n)))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "chain of pauses that cycles is a zero-progress EOF cycle: zero-progress-cycle diagnostic"
```

**Measured** with that REPLACE: the mutant emits exactly **one** FAIL record — its
own pinned EOF-pause one — and `combined3` still counts 3, so it collides with
nothing. With the shipped REPLACE left in place it emits four, three of which the
new mutation below also emits.

`SchemeMutationSuite.cmake:3798-3800` — arm 3's pin, re-anchored to the renamed
case and the new count. Append a dated note above it recording *why* the number
moved, so the next reader does not read it as a correction to a claim that was
wrong:

```cmake
  # Re-anchored by Milestone 3 Slice ③ Task 2: extending PASS 5's REPORT set to
  # the sixth kind adds 'seq itself to this case's count, so the correct value
  # moved 2 -> 3 and the case was renamed to say what it now counts. The pin's
  # "got 1" is unchanged and was re-measured, not assumed: with the arm
  # removed, 'x's plain self-loop is still found, 'start no longer reaches
  # itself, and 'seq is not reported -- 1. The check is now four-way
  # (3 / 2 / 1 / 0); see the case's own comment for the table.
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 1"
```

And the new mutation for the decision this task ships. Append it to Pass 33
immediately after arm 3's declaration:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a self-targeting sequence node is not reported as a zero-progress cycle (§25:1533)"
  # The REPORT set, not the walk: arm 3 above mutates reexec-targets and lands
  # on "got 1", "zero-progress detection never fires" lands on "got 0", and
  # this one lands on "got 2" -- three distinct values on one check, all
  # measured, none predicted. Comparison-caught: the count check fails outright
  # rather than depending on where a mutant happens to crash.
  FIND [[(if (and (or (byte-dispatch-node? n) (pause-node? n) (sequence-dispatch-node? n))]]
  REPLACE [[(if (and (or (byte-dispatch-node? n) (pause-node? n))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES
    "and the sequence node itself are three zero-progress cycles: zero-progress-cycle count -- expected 3, got 2")
```

> Two mutations in this pass now share a `FIND` **prefix** (`:3235`'s re-anchored
> text and the new one's). They are distinct literals of different lengths, so
> `SITES 1` holds for each — but confirm it by running the suite rather than by
> reading, because a `FIND` that begins matching twice fails with
> "found 2, expected 1" and that is the loud failure the assertion exists for.

- [ ] **Step 7: Re-run the whole suite and re-sweep Pass 33**

```bash
make test-all && ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: **80/80**, and `43 passes, 230 mutations` (229 + one), no `UNCAUGHT`,
no `FATAL`, nine `SURVIVES (expected)`. Re-run Task 1 Step 8's sweep — Pass 33 is
now **41** mutations over 1640 ordered pairs, and this task added a mutation,
*re-anchored two FINDs and one pin*, and **renamed a case**, which changes the
FAIL text every pin in the pass is judged against. Write only the measured total
into `:667`.

- [ ] **Step 8: Commit**

```bash
git add src/byte-machine/verify.sls test/common/verify-tests.sps test/support/cmake/SchemeMutationSuite.cmake && git commit -m "feat(verify): report zero-progress cycles through sequence nodes (§25:1533)"
```

---

## Task 3: The multi-alternative fixture and the absolute interpreter lane

**Files:**
- Create: `test/support/harness/byte-machine/test/http-version-machine.sls`
- Create: `test/common/http-version-interpret-tests.sps`
- Modify: `test/CMakeLists.txt` (two lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (a new pass proving the lane is non-vacuous)

**Interfaces:**
- Produces: `(byte-machine test http-version-machine)` exporting
  `make-http-version-machine` (mismatch mode `reexecute`),
  `make-http-version-advance-machine` (mismatch mode `advance`),
  `http-version-bytes` (`(lambda (s) …)`-free: a procedure of one string tag
  returning the byte list for that alternative), and `http-version-shared-prefix`
  (the byte list `HTTP/1.`). Task 4 and Task 5 both import this library.

- [ ] **Step 1: Write the fixture library**

```scheme
;;; The Milestone 3 Slice ③ multi-alternative proving machines: the §21.2:1065
;;; grammar production `version = "HTTP/1.0" / "HTTP/1.1"`, shared by the
;;; absolute interpreter lane, the interpreter≡generated differential and the
;;; determinism golden so the graph is written once (pause-machine.sls's
;;; convention). Built only through (byte-machine graph).
;;;
;;; Why this fixture and not an invented one: it is the smallest shape that
;;; exercises a shared NONTERMINAL prefix with a distinguishing terminal byte
;;; (§10.6:544), it comes from the parent plan's own fixture grammar rather
;;; than from imagination, and its seven-byte shared prefix `HTTP/1.` puts the
;;; branch far enough in that a mismatch position is unambiguous.
;;;
;;; The machine name is 'http-version because the emitted library is
;;; `(library (generated <machine-name>) ...)` and names must match
;;; [a-z][a-z0-9-]* -- never 'HTTP/1.x.
;;;
;;; Milestone 8, not here: case-insensitive recognition and the grammar's byte
;;; classes (tchar, target-byte, field-value-byte, OWS) are §25:1624 item 5.
;;; This fixture is the `version` production and nothing more.
(library (byte-machine test http-version-machine)
  (export make-http-version-machine make-http-version-advance-machine
          http-version-bytes http-version-shared-prefix)
  (import (rnrs) (byte-machine graph))

  (define (string-bytes s) (map char->integer (string->list s)))
  ;; `ascii-bytes` would also do here; string-bytes is used instead so this
  ;; fixture exercises no Slice ① construct it is not testing.
  (define (http-version-bytes which)
    (case which
      ((zero) (string-bytes "HTTP/1.0"))
      ((one)  (string-bytes "HTTP/1.1"))
      (else (assertion-violation 'http-version-bytes "no such alternative" which))))
  (define (http-version-shared-prefix) (string-bytes "HTTP/1."))

  (define (build name mismatch-mode)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine name 'ver '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node
               'ver
               (list (make-sequence-case (http-version-bytes 'zero) 'zero #f)
                     (make-sequence-case (http-version-bytes 'one) 'one #f))
               (make-edge 'reject mismatch-mode) #f #f)
              (make-stop-node 'zero #f)
              (make-stop-node 'one #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f)))

  (define (make-http-version-machine) (build 'http-version 'reexecute))
  (define (make-http-version-advance-machine) (build 'http-version-advance 'advance)))
```

- [ ] **Step 2: Write the failing absolute-outcome program**

`test/common/http-version-interpret-tests.sps`. Every tuple below is **measured**,
not predicted — feeding one byte at a time through one parser, and separately as a
whole-buffer feed. The five fields are
`(status next consumed stream-offset error)`.

```scheme
;;; Multi-alternative sequence dispatch (§25:1529's multi-alternative half;
;;; exit §25:1538-1540) through the reference interpreter, with ABSOLUTE
;;; expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors are built from the
;;; same source IR, so a defect there makes them wrong IDENTICALLY and leaves a
;;; comparison green. This program is what a trie-branching defect reddens;
;;; differential-http-version-tests.sps is what proves the two agree.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test http-version-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.http-version")

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (parser-result-error r)))
(define (feed-one-at-a-time cm bs)
  (let ((p (make-parser cm '() #f)))
    (let loop ((l bs) (r #f))
      (if (null? l) r
          (loop (cdr l) (rfields (parser-feed! p (make-bytevector 1 (car l)) 0 1)))))))
(define (feed-whole cm bs)
  (let ((p (make-parser cm '() #f)) (bv (u8-list->bytevector bs)))
    (rfields (parser-feed! p bv 0 (bytevector-length bv)))))
(define (interp m) (make-interpreted-machine (verify-machine m)))
(define (bytes s) (map char->integer (string->list s)))

(define machines
  (list (list 'reexecute (make-http-version-machine))
        (list 'advance (make-http-version-advance-machine))))

;; §22.6 forbids using an invalid graph to test executor behaviour, so both
;; fixtures are proved clean before any behavioural case runs -- and after
;; Slice ③'s §16.2:894 pass that is a real check, not a formality: two
;; alternatives sharing `HTTP/1.` are exactly the shape a broken ambiguity
;; test would refuse.
(harness-group "both fixtures verify clean under the §16.2:894 pass"
  (lambda ()
    (harness-case "the fixture list holds both mismatch modes"
      (lambda () (check-equal "fixture count" (length machines) 2)))
    (for-each
     (lambda (e)
       (harness-case (string-append (symbol->string (car e)) " verifies with no diagnostics")
         (lambda ()
           (let ((v (verify-machine (cadr e))))
             (check "ok" (verification-ok? v))
             (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)))))
     machines)))

(harness-group "each alternative reaches its OWN target through the shared prefix"
  (lambda ()
    (define re (interp (make-http-version-machine)))
    ;; Both alternatives accept with the identical tuple -- both targets are
    ;; stop nodes, so `next` does NOT distinguish them and no check here can.
    ;; What these cases DO catch is an alternative that stopped accepting at
    ;; all, which is how a dropped or mis-merged trie branch shows up. The
    ;; structural claim lives in Step 3b.
    (harness-case "HTTP/1.0 stops at the zero target"
      (lambda ()
        (check-equal "one byte at a time" (feed-one-at-a-time re (bytes "HTTP/1.0"))
                     '(stopped 1 1 8 #f))))
    (harness-case "HTTP/1.1 stops at the one target"
      (lambda ()
        (check-equal "one byte at a time" (feed-one-at-a-time re (bytes "HTTP/1.1"))
                     '(stopped 1 1 8 #f))))
    ;; NOT asserted here, deliberately: that the two alternatives reach
    ;; DIFFERENT declared nodes. Both targets are stop nodes, so the two accepts
    ;; are behaviourally identical through the public accessors and no check in
    ;; this program can separate them -- a check claiming to would be asserting
    ;; something it cannot see. The distinction is structural, and it is
    ;; asserted where it is observable: Step 3b's normal-ir-tests.sps group,
    ;; over the branching prefix state's own transition list.
    (harness-case "a whole-buffer feed of each alternative consumes all eight bytes"
      (lambda ()
        (check-equal "HTTP/1.0" (feed-whole re (bytes "HTTP/1.0")) '(stopped 8 8 8 #f))
        (check-equal "HTTP/1.1" (feed-whole re (bytes "HTTP/1.1")) '(stopped 8 8 8 #f))))))

;; Every input below is TRUNCATED at (and including) the mismatching byte, so
;; each tuple is the mismatch's OWN result. Feeding the rest of the string and
;; reading the last tuple is a trap this plan fell into once while measuring:
;; after the error the parser is parked, further feeds are no-ops, and the
;; final tuple silently reports the parked state instead of the mismatch. The
;; two agree only when the mismatch happens to be on the last byte -- which is
;; true of `HTTP/1.2` and false of a position-0 mismatch, so a fixture set that
;; used whole strings would have been right in one case and quietly wrong in
;; the other.
(harness-group "mismatch positioning, at the branch and before it (§11.5:664)"
  (lambda ()
    (define re (interp (make-http-version-machine)))
    (define ad (interp (make-http-version-advance-machine)))
    (harness-case "reexecute mode points AT the distinguishing byte after the shared prefix"
      (lambda ()
        ;; `HTTP/1.` is seven bytes, so the distinguishing byte sits at
        ;; stream-offset 7 and a reexecute mismatch reports that offset having
        ;; consumed nothing of it.
        (check-equal "HTTP/1.2" (feed-one-at-a-time re (bytes "HTTP/1.2"))
                     '(error 0 0 7 unexpected-byte))))
    (harness-case "advance mode shifts the same mismatch by exactly one"
      (lambda ()
        (check-equal "HTTP/1.2" (feed-one-at-a-time ad (bytes "HTTP/1.2"))
                     '(error 1 1 8 unexpected-byte))))
    (harness-case "a mismatch INSIDE the shared prefix reports its own position, both modes"
      (lambda ()
        ;; `HTTP/` is five bytes, so the offending `2` is at offset 5.
        (check-equal "HTTP/2 reexecute" (feed-one-at-a-time re (bytes "HTTP/2"))
                     '(error 0 0 5 unexpected-byte))
        (check-equal "HTTP/2 advance" (feed-one-at-a-time ad (bytes "HTTP/2"))
                     '(error 1 1 6 unexpected-byte))))
    (harness-case "a mismatch at prefix position 0 reports offset 0, both modes"
      (lambda ()
        (check-equal "X reexecute" (feed-one-at-a-time re (bytes "X"))
                     '(error 0 0 0 unexpected-byte))
        (check-equal "X advance" (feed-one-at-a-time ad (bytes "X"))
                     '(error 1 1 1 unexpected-byte))))))

(harness-group "every proper prefix is need-input, never paused (decision 0015 point 5)"
  (lambda ()
    (define re (interp (make-http-version-machine)))
    (harness-case "all seven proper prefixes of HTTP/1.0 return need-input"
      (lambda ()
        ;; SENTINELS, both levels. `seen` counts what the PARSER returned, not
        ;; what the fixture expects, so a loop that never runs cannot pass; and
        ;; the outer length assertion is what catches a shortened prefix list.
        (let ((full (bytes "HTTP/1.0")))
          (check-equal "the fixture is eight bytes long" (length full) 8)
          (let loop ((k 1) (seen 0) (bad 'none))
            (if (> k 7)
                (begin
                  (check-equal "need-input results observed" seen 7)
                  (check-equal "no prefix misbehaved" bad 'none))
                (let* ((pre (let take ((l full) (n k)) (if (= n 0) '() (cons (car l) (take (cdr l) (- n 1))))))
                       (r (feed-one-at-a-time re pre)))
                  (loop (+ k 1)
                        (if (eq? (car r) 'need-input) (+ seen 1) seen)
                        (if (eq? (car r) 'need-input) bad k))))))))
    (harness-case "the seven-byte shared prefix is one of them"
      (lambda ()
        (check-equal "HTTP/1." (feed-one-at-a-time re (http-version-shared-prefix))
                     '(need-input 1 1 7 #f))))))

(harness-finish)
```

- [ ] **Step 3: Run it to verify it fails**

Before the lane exists, run the program directly:

```bash
chez --libdirs "src:test/support/harness" --script test/common/http-version-interpret-tests.sps
```

Expected before Step 1's file exists: exit **non-zero** with
`Exception ... library (byte-machine test http-version-machine) not found`.
Once it exists, expect exactly
`cases=12 failed-cases=0 checks=19 failures=0 ... status=0` — measured, by running
this program verbatim against the shipped tree. If any tuple differs, **the tuple
in this plan is the thing to distrust**: re-measure, record the measured value in
the ledger, and fix the plan rather than the assertion.

- [ ] **Step 3b: Assert the branching lowering where it is observable**

The one claim Step 2's program cannot make is the one that matters most: that the
two alternatives descend into **one** shared chain and part at **one** state,
routing to **different** declared nodes. Add it to `test/common/normal-ir-tests.sps`,
which already has `normalize`, `trs-of` and `state-count` and builds its machines
inline — so this needs **no** import, no lane edit and no `SOURCES` change.

Every value below is **measured**, over the machine `seq-machine` builds for these
alternatives (declared `seq`=0, `stop`=1, `reject`=2, then `halt`=3, with the
seven internal prefix states appended at 4-10 per decision 0016 point 2):

```scheme
;; Milestone 3 Slice ③ Task 3: the §21.2:1065 `version` production lowered.
;; Two alternatives sharing the seven-byte prefix `HTTP/1.` descend into ONE
;; chain and part at ONE state -- §10.6:544's shared nonterminal prefixes, and
;; the property that makes decision 0014's ascending-by-byte sort a total order
;; (no prefix state can offer the same byte twice). This is where "each
;; alternative reaches its OWN declared node" is observable at all: both
;; targets are stop nodes, so the two accepts are behaviourally identical.
(harness-group "two alternatives over a shared prefix lower to one trie"
  (lambda ()
    (define httpver
      (seq-machine 'httpver
                   (list (cons '(72 84 84 80 47 49 46 48) 'stop)    ; HTTP/1.0
                         (cons '(72 84 84 80 47 49 46 49) 'halt))   ; HTTP/1.1
                   (list (make-stop-node 'halt #f))))
    (harness-case "the shared prefix is not duplicated"
      (lambda ()
        ;; Two eight-byte alternatives lowered as separate chains would need
        ;; fourteen internal states; merged, they need seven.
        (check-equal "state count" (state-count httpver) 11)))
    (harness-case "the chain is linear until the distinguishing byte"
      (lambda ()
        (check-equal "root"     (trs-of httpver 0)  '((72 4 advance)))
        (check-equal "state 4"  (trs-of httpver 4)  '((84 5 advance)))
        (check-equal "state 5"  (trs-of httpver 5)  '((84 6 advance)))
        (check-equal "state 6"  (trs-of httpver 6)  '((80 7 advance)))
        (check-equal "state 7"  (trs-of httpver 7)  '((47 8 advance)))
        (check-equal "state 8"  (trs-of httpver 8)  '((49 9 advance)))
        (check-equal "state 9"  (trs-of httpver 9)  '((46 10 advance)))))
    (harness-case "the branch state routes each alternative to its OWN declared node"
      (lambda ()
        ;; 48 -> state 1 ('stop), 49 -> state 3 ('halt): ascending by byte, two
        ;; transitions, two different declared targets. A lowering that dropped
        ;; an alternative would show one transition here and nothing else in
        ;; this milestone would fail.
        (check-equal "branch transitions" (trs-of httpver 10)
                     '((48 1 advance) (49 3 advance)))))))
```

Run it:

```bash
make build && ctest --preset release -R 'unit.normal-ir' --output-on-failure
```

Expected: **PASS**, both lanes, at exactly `cases=38 checks=82` (from `cases=35
checks=73`) — measured, by running this group verbatim inside
`normal-ir-tests.sps` on a scratch copy. If `state count` comes out 18 rather than 11, the
alternatives are being lowered as separate chains and Slice ②'s trie is not doing
what it claims — stop and record it, because that is a shipped defect, not a
fixture problem.

- [ ] **Step 4: Register the lanes**

Append to `test/CMakeLists.txt` after the Slice ② `sequence-node` block (which
ends at `:1133`):

```cmake
# --- Milestone 3 Slice ③: multiple alternatives over a shared prefix ---------
# The §21.2 `version = "HTTP/1.0" / "HTTP/1.1"` production. Both lanes list the
# fixture .sls in SOURCES because the aot lane resolves libraries only through
# objects compiled from its own SOURCES (the source-guard blocks fallback).
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-version.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.http-version.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/http-version-interpret-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 5: Run the new lanes and the whole suite**

```bash
make build && ctest --preset release -R 'unit.http-version' --output-on-failure
```

Expected: **PASS**, 2 tests (source + aot), at exactly `cases=12 checks=19` —
measured, by running Step 2's program verbatim against the shipped tree. Every
tuple it asserts was measured the same way; if one differs, re-measure and fix
**this plan**, not the assertion.

```bash
make test-all
```

Expected: **82/82** (80 + 2). Any other number means a lane was skipped or a name
collided — re-read the configure output for
`byte-machine: skipping <NAME> -- <message>`.

- [ ] **Step 6: Add the non-vacuity pass**

Every executed lane in this tree carries a mutation pass proving the lane is not
vacuous; Passes 44, 45 and 46 are the shipped precedents for exactly this shape.
Add a new pass (a `reset` / `VERIFY_COMMAND` / mutations / `run` quadruple, since
there is no pass-declaration macro — a pass is a call boundary) mutating
`interpret.sls`'s `seq-step` under this program's own SPEC lane, because **a
mutation is only witnessed by tests that run in the lane named by its SPEC**:

```cmake
# --- Pass 47: the multi-alternative absolute lane is non-vacuous (M3 Slice ③ --
# Task 3) ----------------------------------------------------------------------
# A seq-step decision mutated under THIS lane's SPEC, because a mutation is
# witnessed only by the tests that run in its own SPEC lane (AGENTS.md).
# Justify the new SPEC by MEASUREMENT, not by novelty: run your chosen mutants
# against Pass 45's SPEC-lane program too, and state that they pass it
# unchanged. Do NOT write "the first lane to drive a branching sequence node" --
# interpret-tests.sps has driven AB/AC since Slice ②, under a different SPEC,
# and it catches these mutations. What is new is the SHAPE. Pass 45 does the
# same thing for the single-alternative lane, and its comment at :5611-5617 is
# the shipped precedent for duplicating an edit under a different SPEC. Do NOT
# describe this as "the same FIND/REPLACE as Pass 34's mutation of the same
# name": no Pass 34 mutation carries this label, and Pass 45's own comment
# makes a same-edit claim that is true only modulo indentation.
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/http-version-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.http-version.chez.source
  LABEL "interpret: a branching prefix keeps only the FIRST live alternative"
  FIND [[(hit (filter (lambda (c)]]
  REPLACE [[(hit (list-head-or-null (filter (lambda (c)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "<measure this>")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> The mutation above is a **sketch whose FIND/REPLACE the implementer must
> replace with a real one**, and this is deliberate: the plan cannot pin a
> signature it has not measured, and AGENTS.md forbids writing an unmeasured
> number or pin into the tree. Pick a mutation that a **failed comparison** in
> this program catches — the strongest candidates are (i) `seq-step`'s
> `ends`/`conts` split at `interpret.sls:55-56`, which decides whether a
> completed alternative accepts or continues, and (ii) the `prefix?` recursion at
> `:46`. Apply it to a scratch copy, run the capture command from Task 1 Step 8
> with `--program test/common/http-version-interpret-tests.sps`, and pin the
> exact `(case, check)` pair from the captured FAIL line. Try the opposite
> constant first, and prefer the form caught by a comparison over one caught by a
> raise.

Then re-run Task 1 Step 8's sweep **for this new pass** (it has its own SPEC lane,
so its pins are judged against its own mutants), and update
`EXPECTED_PASSES`/`EXPECTED_MUTATIONS` from measurement.

- [ ] **Step 7: Commit**

```bash
git add test/support/harness/byte-machine/test/http-version-machine.sls test/common/http-version-interpret-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake && git commit -m "test: drive two sequence alternatives over a shared prefix (§25:1529)"
```

---

## Task 4: The interpreter ≡ generated differential over more than one alternative

**Files:**
- Create: `test/common/differential-http-version-tests.sps`
- Modify: `test/CMakeLists.txt` (two lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (a non-vacuity pass)

**Interfaces:**
- Consumes: `(byte-machine test http-version-machine)` from Task 3;
  `(byte-machine test prng)` for the seeded split schedules, exactly as
  `differential-sequence-node-tests.sps` does.
- Produces: nothing importable.

- [ ] **Step 1: Read the shipped differential before writing a new one**

```bash
sed -n '1,60p' test/common/differential-sequence-node-tests.sps
```

`differential-sequence-node-tests.sps` is Slice ②'s differential and the template:
copy its structure — the emit-to-`$BYTE_MACHINE_TEST_TMPDIR`/`load`/`eval` dance,
the tuple comparison helper, the seeded schedule generator, and its sentinels at
`:273-275` — rather than inventing a second idiom. What changes is **only** the
machine and the byte strings driven through it.

- [ ] **Step 2: Write the program**

The differential's job here is the one thing Slice ② could not do: prove the two
**executors agree** on a branching trie, at every split point, for both
alternatives, and at a mismatch on the distinguishing byte.

> **Correction, 2026-08-30 (found during Task 3 execution).** An earlier version
> of this paragraph, and of the program's own header below, said "no lane in this
> tree exercised the trie MERGE". **Measured: false.** Slice ② already ships two
> lanes that do — `normal-ir-tests.sps:280-287` asserts structurally that "a
> shared first byte becomes ONE transition into ONE state" and pins the branch's
> transition list, and `interpret-tests.sps:166-171` executes `AB`/`AC` through
> the interpreter. The design's gap statement is true **only with its own
> qualifier**: *the **differential** is single-alternative*. Dropping that
> qualifier turned a true claim into a false one — AGENTS.md's "keep a count next
> to the qualifier that makes it true", applied to a claim rather than a number.
> What is genuinely new here is the **differential** over a branch; what Task 3
> adds is depth, absolute tuples and both mismatch modes. Task 6's §7 disposition
> must say it that way.

**Measured:** this program was run verbatim against the shipped tree during plan
authoring and reports `cases=8 checks=20 failures=0`.

```scheme
;;; interpreter ≡ generated over a MULTI-ALTERNATIVE sequence node (parent §18,
;;; §22.4, §22.5). Slice ② pinned the trie merge structurally (normal-ir-tests)
;;; and executed it through the interpreter (interpret-tests), but its
;;; DIFFERENTIAL drove a single alternative -- so no lane has compared the two
;;; EXECUTORS across a branch: two alternatives sharing
;;; `HTTP/1.` descend into one chain and part at one state, and a lowering that
;;; resumed into the wrong prefix state across a feed boundary would be caught
;;; here and nowhere else.
;;;
;;; Agreement alone cannot carry the lane -- both executors read the same source
;;; IR -- so the absolute tuples live in http-version-interpret-tests.sps and the
;;; groups below assert AGREEMENT, plus one generated-side absolute per mismatch
;;; mode. The exhaustive group's own value is 256 bytes at all eight prefix
;;; positions in both modes, which no fixed set of literal tuples could replace.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test http-version-machine)
        (byte-machine test prng)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.http-version")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-http-version
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; The binding is derived from `name`; the LIBRARY name is not -- emit-machine
;; draws it from the compiled machine's own machine-name field, so this call
;; only works while the fixture passes the same symbol to make-machine.
;; (environment (list 'generated name)) is what fails loudly if they diverge.
(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (parser-result-error r)))
(define (u8 b) (make-bytevector 1 b))
(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (drop-n l k) (if (= k 0) l (drop-n (cdr l) (- k 1))))
(define (run-slices cm slices)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss) last
          (loop (cdr ss)
                (rfields (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))))))))
(define (drive cm prefix b)
  (run-slices cm (append (map (lambda (x) (list (u8 x) 0 1)) prefix)
                         (list (list (u8 b) 0 1)))))
;; One slice per run of bytes between consecutive cuts. `cuts` is ascending and
;; strictly inside (0, length).
(define (slices-for bs cuts)
  (let loop ((start 0) (cs (append cuts (list (length bs)))) (out '()))
    (if (null? cs) (reverse out)
        (let* ((end (car cs))
               (run (head-n (drop-n bs start) (- end start))))
          (loop end (cdr cs)
                (cons (list (u8-list->bytevector run) 0 (length run)) out))))))
(define (schedule->string cuts)
  (string-append "("
                 (fold-left (lambda (acc c)
                              (string-append acc (if (string=? acc "") "" " ")
                                             (number->string c)))
                            "" cuts)
                 ")"))

(define zero-bytes (http-version-bytes 'zero))
(define one-bytes (http-version-bytes 'one))
(define shared (http-version-shared-prefix))
(define re-machine (make-http-version-machine))
(define ad-machine (make-http-version-advance-machine))
(define cm-ref (make-interpreted-machine (verify-machine re-machine)))
(define cm-gen (generated-machine 'http-version re-machine))
(define ad-ref (make-interpreted-machine (verify-machine ad-machine)))
(define ad-gen (generated-machine 'http-version-advance ad-machine))

(harness-group "both alternatives agree at every single-cut split"
  (lambda ()
    (harness-case "nine cut positions x two alternatives x two modes all agree and accept"
      (lambda ()
        ;; SENTINELS: `compared` counts runs the LOOP performed, `accepts`
        ;; counts what the executors RETURNED. A loop that never ran, or an
        ;; executor that stopped accepting, is caught by a different one.
        (let ((bad 'none) (compared 0) (accepts 0))
          (for-each
           (lambda (alt)
             (for-each
              (lambda (cm-pair)
                (let loop ((k 0))
                  (when (<= k 8)
                    (let* ((cuts (if (or (= k 0) (= k 8)) '() (list k)))
                           (ss (slices-for alt cuts))
                           (ri (run-slices (car cm-pair) ss))
                           (rg (run-slices (cdr cm-pair) ss)))
                      (set! compared (+ compared 1))
                      (when (and (equal? ri rg) (eq? (car rg) 'stopped))
                        (set! accepts (+ accepts 1)))
                      (unless (equal? ri rg)
                        (when (eq? bad 'none) (set! bad (list 'disagree k))))
                      (unless (eq? (car rg) 'stopped)
                        (when (eq? bad 'none) (set! bad (list 'not-stopped k)))))
                    (loop (+ k 1)))))
              (list (cons cm-ref cm-gen) (cons ad-ref ad-gen))))
           (list zero-bytes one-bytes))
          (check-equal "nothing disagreed or failed to accept" bad 'none)
          (check-equal "the loop ran 2 alternatives x 2 modes x 9 cuts" compared 36)
          (check-equal "every run accepted, observed from the executors" accepts 36))))
    (harness-case "the cut at the branch boundary is one of them, and is asserted by name"
      (lambda ()
        ;; A cut at offset 7 lands exactly between the shared prefix and the
        ;; distinguishing byte: the resume point a wrong prefix state would
        ;; corrupt. Asserted separately so it is visibly covered, not
        ;; incidentally covered.
        (check-equal "shared prefix is seven bytes" (length shared) 7)
        (check-equal "HTTP/1.0 interpreter"
                     (run-slices cm-ref (slices-for zero-bytes '(7)))
                     (run-slices cm-gen (slices-for zero-bytes '(7))))
        (check-equal "HTTP/1.1 interpreter"
                     (run-slices cm-ref (slices-for one-bytes '(7)))
                     (run-slices cm-gen (slices-for one-bytes '(7))))
        (check-equal "HTTP/1.1 accepts across that cut"
                     (car (run-slices cm-gen (slices-for one-bytes '(7))))
                     'stopped)))))

(harness-group "seeded multi-split schedules agree"
  (lambda ()
    (harness-case "32 draws over both alternatives agree, with at least one genuine multi-split"
      (lambda ()
        (define seed 20260830)
        (let loop ((i 0) (s (make-prng seed)) (multi 0) (bad 'none))
          (if (>= i 32)
              (begin
                (check-equal "no schedule disagreed" bad 'none)
                (check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0)))
              (let*-values (((d1 s1) (prng-next s 2))
                            ((d2 s2) (prng-next s1 2))
                            ((d3 s3) (prng-next s2 2))
                            ((alt s4) (prng-next s3 2)))
                (let* ((cuts (append (if (= d1 1) '(2) '())
                                     (if (= d2 1) '(5) '())
                                     (if (= d3 1) '(7) '())))
                       (bs (if (= alt 0) zero-bytes one-bytes))
                       (ss (slices-for bs cuts))
                       (ri (run-slices cm-ref ss))
                       (rg (run-slices cm-gen ss)))
                  (loop (+ i 1) s4 (+ multi (if (>= (length cuts) 2) 1 0))
                        (if (and (eq? bad 'none)
                                 (or (not (equal? ri rg)) (not (eq? (car rg) 'stopped))))
                            (schedule->string cuts) bad))))))))))

(harness-group "nonzero-offset and empty slices agree"
  (lambda ()
    (define padded (u8-list->bytevector (append '(9) zero-bytes '(9))))
    (harness-case "one nonzero-offset slice accepts identically in both"
      (lambda ()
        (check-equal "agree"
                     (run-slices cm-ref (list (list padded 1 9)))
                     (run-slices cm-gen (list (list padded 1 9))))
        (check-equal "accepted" (car (run-slices cm-gen (list (list padded 1 9)))) 'stopped)))
    (harness-case "an empty slice mid-sequence changes nothing in either"
      (lambda ()
        (let ((ss (list (list (u8-list->bytevector (head-n zero-bytes 4)) 0 4)
                        (list (make-bytevector 0) 0 0)
                        (list (u8-list->bytevector (drop-n zero-bytes 4)) 0 4))))
          (check-equal "agree" (run-slices cm-ref ss) (run-slices cm-gen ss))
          (check-equal "accepted" (car (run-slices cm-gen ss)) 'stopped))))))

(harness-group "interpreter and generated agree on all 256 bytes at every prefix position"
  (lambda ()
    (harness-case "256 x 8 positions match, in both mismatch modes"
      (lambda ()
        (let ((bad 'none) (last-byte 'unset) (positions 0))
          (let pos ((k 0))
            (when (< k 8)
              (set! positions (+ positions 1))
              (let ((prefix (head-n zero-bytes k)))
                (let loop ((b 0))
                  (when (< b 256)
                    (unless (equal? (drive cm-ref prefix b) (drive cm-gen prefix b))
                      (when (eq? bad 'none) (set! bad (list 'reexecute k b))))
                    (unless (equal? (drive ad-ref prefix b) (drive ad-gen prefix b))
                      (when (eq? bad 'none) (set! bad (list 'advance k b))))
                    (set! last-byte b)
                    (loop (+ b 1)))))
              (pos (+ k 1))))
          (check-equal "no (mode position byte) disagreed" bad 'none)
          (check-equal "the byte loop ran all 256 values" last-byte 255)
          (check-equal "the position loop ran all eight" positions 8))))))

;; §11.5:664, asserted ABSOLUTELY on the generated side rather than as agreement:
;; the branch byte is where the two modes visibly differ on a multi-alternative
;; node, and agreement between two wrong executors would look identical.
(harness-group "both mismatch modes at the branch, absolutely, on the generated executor"
  (lambda ()
    (harness-case "reexecute keeps next and consumed at zero and points at the branch byte"
      (lambda ()
        (check-equal "branch" (drive cm-gen shared 50) '(error 0 0 7 unexpected-byte))
        (check-equal "position 0" (drive cm-gen '() 88) '(error 0 0 0 unexpected-byte))))
    (harness-case "advance consumes the offending byte and shifts the offset by one"
      (lambda ()
        (check-equal "branch" (drive ad-gen shared 50) '(error 1 1 8 unexpected-byte))
        (check-equal "position 0" (drive ad-gen '() 88) '(error 1 1 1 unexpected-byte))))))

(harness-finish)
```

Three things in it are load-bearing and easy to weaken by accident:

- **`generated-machine` derives only the BINDING from its `name` argument.** The
  emitted *library* name comes from the compiled machine's own `machine-name`
  field, set inside the fixture at construction time. They agree only because
  `http-version-machine.sls` passes the same symbol to `make-machine`. Nothing
  asserts that invariant; `(environment (list 'generated name))` is what fails
  loudly if a future fixture lets them diverge, and `load` alone would not.
- **The two sentinels in the first case count different things.** `compared`
  counts runs the *loop* performed (2 alternatives × 2 modes × 9 cuts = 36) and
  catches a loop that never ran; `accepts` counts what the *executors returned*
  and catches executors that stopped accepting. A single counter derived from the
  fixture's own shape would close neither.
- **The branch-boundary cut at offset 7 is asserted by name** even though the
  first case already covers it, because "covered incidentally" and "covered" read
  identically in a green run, and offset 7 is precisely the resume point a wrong
  prefix state would corrupt.

- [ ] **Step 3: Run it, and prove it can fail**

The program needs `BYTE_MACHINE_TEST_TMPDIR`, so either register the lanes first
(Step 4) or supply the variable by hand:

```bash
BYTE_MACHINE_TEST_TMPDIR=/tmp/bm-diff chez --libdirs "src:test/support/harness" --script test/common/differential-http-version-tests.sps
```

Expected: `cases=8 checks=20 failures=0 ... status=0` — measured.

Then the control, which matters more than the pass: a differential that goes
green on its first run has told you nothing until you have seen it go red.
Temporarily change one absolute tuple in the last group — make the reexecute
branch case expect `'(error 0 0 6 unexpected-byte)` instead of offset 7 — re-run,
and confirm **exactly one** check fails with
`branch -- expected (error 0 0 6 unexpected-byte), got (error 0 0 7 unexpected-byte)`.
Restore it and confirm `failures=0` again before continuing. Do the same for one
agreement check if you have edited the comparison helpers.

- [ ] **Step 4: Register the lanes**

```cmake
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.http-version.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.http-version.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-http-version-tests.sps"
  TIMEOUT 180)
```

- [ ] **Step 5: Confirm the emitter needed no change, and record it**

The appendix's `compile` row says "confirm zero change and record it". Do both:

```bash
git diff --stat HEAD -- src/byte-machine/compile.sls
```

Expected: **no output**. Then confirm `reserved-member-3` (`compile.sls:53`) is
unchanged — it has no automated drift guard, unlike member-2 — and add a one-line
comment beside the fixture library recording that a branching prefix state emits
as an ordinary multi-arm `(case b …)` and needed no emitter arm, with the measured
rendered size (3849 bytes for this machine) as the evidence that it rendered at
all.

- [ ] **Step 6: Run everything**

```bash
make test-all
```

Expected: **84/84** (82 + 2).

- [ ] **Step 7: Add the non-vacuity pass, sweep, and commit**

Same shape as Task 3 Step 6: a new pass under
`SPEC byte-machine.differential.http-version.chez.source`, with a **measured**
pin. Passes 44 and 46 are the shipped precedents for a differential's non-vacuity
pass; read one before writing this one. Then:

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

```bash
git add test/common/differential-http-version-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake && git commit -m "test: interpreter≡generated over a branching sequence trie (§22.4)"
```

---

## Task 5: Determinism pins for a sequence machine (§22.9)

**Files:**
- Create: `test/common/determinism-http-version-tests.sps`
- Create: `test/fixtures/generated-http-version.golden.sls` (**generated, never hand-written**)
- Modify: `test/CMakeLists.txt` (two lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (a non-vacuity pass)

**Interfaces:**
- Consumes: `(byte-machine test http-version-machine)` from Task 3;
  `(byte-machine compile)`'s `compile-machine`, `render-machine`, `emit-machine`.
- Produces: environment variable contract
  `BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE`.

- [ ] **Step 1: Read the two shipped determinism programs**

```bash
cat test/common/determinism-pause-tests.sps
```

`determinism-pause-tests.sps` is the closer template of the two, because it
imports a shared fixture library rather than building its machine inline — exactly
this task's shape. Copy its structure.

**What §22.9 already covers, so this task does not rebuild it:** bullet :1311
(same process, repeated) and :1313 (source and AOT lanes) are covered by the
program shape plus a lane pair; :1312 (separate processes) is established
*transitively* by the committed golden, and that reasoning must be restated in
this program's header exactly as the two shipped ones restate it, not silently
assumed; :1315 (compile and execute) is the emit/`load`/`eval` group. Bullet
:1314's cross-cell artifact retention is **not built anywhere** (no
`upload-artifact` step exists in `.github/workflows/ci.yml`) and this task does
not build it — but do not write a close-out sentence claiming §22.9 is fully
discharged.

- [ ] **Step 2: Write the failing program**

```scheme
;;; §22.9 determinism over a MULTI-ALTERNATIVE sequence machine, proved against
;;; a committed golden. Byte-identity in this process AND equality to the
;;; golden (which every cell and lane compares against) give cross-process,
;;; cross-lane, and cross-cell identity transitively; M9 completes the four-cell
;;; matrix with the same golden. Comparison is over raw bytes through the
;;; project-owned writer, never via implementation `write`.
;;;
;;; Why a third golden rather than reusing one: decision 0016's ascending-byte
;;; child rule and two-phase id allocation are what keep a BRANCHING trie's
;;; emission deterministic, and neither the one-byte nor the pause golden
;;; contains a branch. A `list-sort` tie at the branch is precisely how
;;; §25:1539 would be lost, and only a machine with a branch can witness it.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test http-version-machine)
        (byte-machine graph)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.http-version")

(define ok (compile-machine (make-http-version-machine) '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'http-version-parser)
                     (render-machine ok 'http-version-parser))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'http-version-parser)
                     (adapter-file-bytes golden-file))))))

(harness-group "the golden output compiles and executes BOTH alternatives"
  (lambda ()
    (harness-case "each alternative reaches its own target and the branch byte mismatches"
      (lambda ()
        (let* ((tmpdir (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR"))
               (genfile (string-append tmpdir "/determinism-http-version.sls")))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine ok 'http-version-parser p)))
          (load genfile)
          (let* ((cm (eval 'http-version-parser (environment '(generated http-version))))
                 (run (lambda (bs)
                        (let ((bv (u8-list->bytevector bs)))
                          (parser-feed! (make-parser cm '() #f) bv 0 (bytevector-length bv)))))
                 (r0 (run (http-version-bytes 'zero)))
                 (r1 (run (http-version-bytes 'one)))
                 (rx (run (append (http-version-shared-prefix) '(50)))))  ; `HTTP/1.2`
            ;; A single-alternative walk would leave the branching prefix state
            ;; untested by this lane, which is the whole reason for a third
            ;; golden -- so both alternatives AND the branch mismatch are driven.
            (check-equal "HTTP/1.0 status" (parser-result-status r0) 'stopped)
            (check-equal "HTTP/1.0 consumed" (parser-result-consumed r0) 8)
            (check-equal "HTTP/1.1 status" (parser-result-status r1) 'stopped)
            (check-equal "HTTP/1.1 consumed" (parser-result-consumed r1) 8)
            ;; Not asserted: that the two accepts differ. Both targets are stop
            ;; nodes, so they are behaviourally identical here -- the structural
            ;; claim lives in normal-ir-tests.sps (Task 3 Step 3b) and in the
            ;; golden's own bytes, which this group already pins. What IS
            ;; asserted is that the branch was actually taken: a generated
            ;; machine that had lost an alternative would redden one of the two
            ;; accepts above, and a generated machine that never branched would
            ;; redden the mismatch below.
            (check-equal "HTTP/1.2 status" (parser-result-status rx) 'error)
            (check-equal "HTTP/1.2 stops at the branch byte"
                         (parser-result-stream-offset rx) 7)))))))

(harness-finish)
```

- [ ] **Step 3: Generate the golden — do not write it**

```bash
mkdir -p /tmp/bm-golden && chez --libdirs "src:test/support/harness" --script /dev/stdin <<'EOF'
(import (rnrs) (byte-machine test http-version-machine) (byte-machine compile))
(let ((ok (compile-machine (make-http-version-machine) '())))
  (call-with-port (open-file-output-port "test/fixtures/generated-http-version.golden.sls"
                                         (file-options no-fail))
    (lambda (p) (emit-machine ok 'http-version-parser p))))
EOF
```

Then confirm what landed, with a check that can fail:

```bash
wc -c test/fixtures/generated-http-version.golden.sls && head -3 test/fixtures/generated-http-version.golden.sls
```

Expected: **3849** bytes, and the first three lines exactly

```
(library (generated http-version)
  (export http-version-parser)
  (import (rnrs) (byte-machine runtime))
```

A different byte count is not automatically wrong — it is a signal that something
about the fixture differs from the one measured during plan authoring. Diff the
two machines before accepting it, and record the measured number.

- [ ] **Step 4: Register the lanes**

```cmake
# --- Milestone 3 Slice ③: determinism against a committed golden (sequence) ---
# The third golden. Unlike the one-byte and pause goldens, this machine has a
# BRANCHING prefix state, which is the only shape that can witness a list-sort
# tie at the branch -- decision 0016's ascending-byte child rule, and the way
# §25:1539 would otherwise be lost.
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.http-version.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http-version.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.http-version.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/http-version-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/determinism-http-version-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-http-version.golden.sls")
```

- [ ] **Step 5: Run the lanes and the whole suite**

```bash
make build && ctest --preset release -R 'determinism.http-version' --output-on-failure
```

Expected: **PASS**, 2 tests.

```bash
make test-all
```

Expected: **86/86** (84 + 2).

- [ ] **Step 6: Prove the golden is load-bearing**

A golden that nothing would notice changing is not a pin. Flip one byte in the
committed golden, confirm both lanes redden with a `golden` check failure, then
restore it:

```bash
cp test/fixtures/generated-http-version.golden.sls /tmp/bm-golden.bak && printf '\n;; scratch\n' >> test/fixtures/generated-http-version.golden.sls && ctest --preset release -R 'determinism.http-version' --output-on-failure; cp /tmp/bm-golden.bak test/fixtures/generated-http-version.golden.sls
```

Expected: **FAIL** on both lanes with the `golden` check, then a clean tree
(`git status --porcelain` empty for that path) after the restore. Re-run
`ctest --preset release -R 'determinism.http-version'` and expect **PASS** before
continuing.

- [ ] **Step 7: Add the non-vacuity pass, sweep, and commit**

Pass 38 (`SchemeMutationSuite.cmake:4900`) is the shipped determinism-vs-golden
pass and the template. Note that its baseline needs
`BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE` in the lane environment, exactly as the
existing suite registration supplies `BYTE_MACHINE_GOLDEN_FILE` at
`test/CMakeLists.txt:581-592` — **add the new variable there too**, or the new
pass's baseline fails on the staged tree and the failure will look like a
mutation problem rather than an environment one.

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

```bash
git add test/common/determinism-http-version-tests.sps test/fixtures/generated-http-version.golden.sls test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake && git commit -m "test: determinism pins over a branching sequence machine (§22.9)"
```

---

## Task 6: Close-out — Milestone 3 closes

This is a **milestone** close-out, not a slice close-out (D10). Slice ② explicitly
deferred the status sweep here.

**Files:** `README.org`, `CHANGELOG.md`,
`docs/plans/byte-machine-implementation-plan.md`,
`docs/plans/milestone-3-design.md`,
`docs/plans/milestone-3-slice-3-implementation-plan.md` (this file),
`test/support/cmake/SchemeMutationSuite.cmake`.

- [ ] **Step 1: Re-measure every number, before any of them enters a document**

```bash
make build && ctest --preset release --output-on-failure --no-tests=error
```

```bash
ctest --preset pr --output-on-failure --no-tests=error
```

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure --no-tests=error
```

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL|SURVIVES"
```

```bash
ctest --preset release -R 'cmake-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Record each number with the command that produced it. Then confirm what must
**not** have moved:

```bash
git diff --stat 49c8cc4..HEAD -- test/fixtures/generated-one-byte.golden.sls test/fixtures/generated-pause.golden.sls src/byte-machine/compile.sls src/byte-machine/runtime.sls src/byte-machine/private/normal-ir.sls
```

Expected: only `normal-ir.sls` appears, and its diff must be **comment-only** —
verify by reading it, not by trusting the stat. `compile.sls`, `runtime.sls` and
both goldens must be absent entirely.

```bash
git diff 49c8cc4..HEAD -- test/support/cmake/SchemeMutationSuite.cmake | grep -E '^[+-].*EXPECT_SURVIVES'
```

Expected: **no output** — nine declared survivors, none added, removed or edited.

- [ ] **Step 2: Re-read every early artifact against HEAD**

Before the final review, not during it. §0's D1-D12 were written in this task's
planning; Tasks 1-5 may have measured something that contradicts one. For each
contradiction, add a **dated amendment** to the affected §0 entry stating what the
tree it was decided against was, and what has since changed — do not rewrite it as
though it had been written at the end, because the tree it was decided against is
its evidence.

Read, specifically: every `file:line` citation this plan makes into a file the
plan's own tasks edited. Those are stale on arrival and no link check can see it.
`verify.sls` line numbers in particular shift by the length of Task 1's new pass.

- [ ] **Step 3: The five status surfaces, plus the one no step names**

AGENTS.md: a slice that closes a milestone is not done until the milestone plan,
the parent plan, `CHANGELOG.md`'s `[Unreleased]` preamble, that milestone's own
design document, **and `README.org`'s status paragraph** all say it closed. All
five are **instructions** and are corrected in place.

| # | surface | anchor now | treatment |
| --- | --- | --- | --- |
| 1 | `README.org` status paragraph | `:15-24` | corrected in place: Milestone 3 has **closed**, Slice ③ with it |
| 2 | `README.org` documentation list | `:73-80` | **the gap no step names.** `rg -n 'milestone-3' README.org` returns nothing: the list points at the M0, M1 and M2 plans and has never gained an M3 entry. Neither Slice ① nor Slice ② added one. Add `[[file:docs/plans/milestone-3-design.md][Milestone 3 design]] — byte classes and sequences` |
| 3 | `CHANGELOG.md` `[Unreleased]` preamble | `:7-16` | corrected in place |
| 4 | `CHANGELOG.md` new entry | append in `### Added` | measured numbers only |
| 5 | parent plan Status line | `:3` | corrected in place |
| 6 | parent plan §25 close note | insert between `:1540` and `:1542` | **new** — M1 (`:1479-1490`) and M2 (`:1514-1521`) both carry one; M3 does not yet |
| 7 | design Status block | `:3-18` | corrected in place |
| 8 | design §1 phase table + dependency paragraph | `:93`, `:98-100` | corrected in place |
| 9 | design §7 dated disposition | after `:701` | **new**, mirroring §5's at `:421`, §6's at `:527` and `:609` |
| 9b | design **`**Exit (full Milestone 3).**`** block | **does not exist** — `milestone-3-design.md` has no milestone-level exit list at all | **new, and Step 3b below is what creates it**. Both prior close notes point at one (`milestone-2-design.md:441-455` plus its `> **Dispositioned 2026-08-29 at close.**` block); M3's §5/§6/§7 dispositions are all slice-scoped, so row 6's close note would otherwise have nothing to cite |
| 10 | design appendix rows | `:842-843`, disposition after `:848` | dated disposition |
| 11 | live-code deferral comments | `verify.sls:8-16`, `:176-180`, `:209-226`; `interpret.sls:63-66`; `normal-ir.sls:94-101`; `verify-tests.sps:518-528`; `sequence-node-machine.sls:16` | corrected in Tasks 1-2; **`verify-tests.sps:518-528` and `sequence-node-machine.sls:16` are the two easiest to miss** — the first says pass-overlap and the report guard are "deliberately left unextended until Slice ③", the second says "Slice ③ is where more than one alternative is executed end to end" |
| 12 | mutation totals | `SchemeMutationSuite.cmake:666-667` | re-measured |
| 12b | the suite's headline prose | `SchemeMutationSuite.cmake:9` (`# FORTY-THREE PASSES, BECAUSE FORTY-THREE DIFFERENT WITNESSES ARE NEEDED`) and `:148` (which cites it) | corrected in place — the numeral is spelled out, so a grep for `43` misses it |
| 13 | ledger | `.superpowers/sdd/progress.md` | updated, **never `git add`** |

⚠️ **Grep trap.** `Slice ③` and `Slice 3` are *also* Milestone 2's pause/resume
slice. `rg -n 'Slice ③|Slice 3' src test` returns roughly seventy hits and the
large majority are M2 — including `normal-ir.sls:39`
(`;; pause states carry (node . <continuation-id>) there (Slice ③).`), which must
**not** be touched. Only the eight locations in row 11 are Milestone 3's.

- [ ] **Step 3b: Write the per-criterion exit disposition — the artifact both prior close notes point at**

M1's and M2's close notes are one sentence plus a pointer: *"All four criteria are
met against the shipped tree; that document's §6 dispositions each individually."*
The substance lives in the design document's `**Exit (full Milestone N).**` list
with a dated per-criterion disposition. **`milestone-3-design.md` has no such
list** — its only dated dispositions are §5's, §6's and the appendix's, every one
slice-scoped. So a close note claiming "all four criteria are met" would have
nothing to point at, for a milestone whose first two criteria were discharged by
*other slices*.

Add an `**Exit (full Milestone 3).**` block to `milestone-3-design.md` with a
dated disposition per §25 criterion, each naming the file and case in the tree
that meets it — and **find each one in the tree before writing "met"**:

| §25 | criterion | where it is met, and by which slice |
| --- | --- | --- |
| :1537 | all-byte class tests pass | Slice ① — `byte-class-interpret-tests.sps`, `differential-byte-class-tests.sps`. **Carries D10b's named residue.** |
| :1538 | every sequence split and mismatch position passes | Slice ② — `differential-sequence-node-tests.sps`, `sequence-interpret-tests.sps`; extended to a branching trie by this slice's Tasks 3-4. **Carries the deferred parser-error-record limitation (design §8).** |
| :1539 | normalized output is deterministic | Slice ② (`normal-ir-tests.sps`'s caller-order-invariance case) + Slice ③ Task 5's third golden and its lane pair. **Carries the §22.9:1314 limitation — no cross-cell artifact retention exists.** |
| :1540 | consuming cycles pass and zero-progress cycles fail verification | Slice ③ Task 2's two cases — one per half, and the passing half is as load-bearing as the failing one |

Then attribute §25:1533 **in halves** (D6): zero-progress → this slice's Task 2;
EOF-cycle → Slice ②, cited. Row 6's parent-plan close note then cites this block
the way M1's and M2's cite theirs, rather than restating it — AGENTS.md's rule
that a number restated without its qualifier becomes a different claim applies to
dispositions too.

- [ ] **Step 4: Dispositions, not rewordings**

An instruction whose work has closed has become the **record** of what was asked:
it gets a dated disposition and is never reworded to match what shipped, because
rewording it edits the bar to fit the result. That applies to design §7's bullet
list and to this plan's own §0 and task headings. Before writing "met" or "moot"
anywhere, **find the thing in the tree** — and then check what the document
already says elsewhere, because this project's two recorded failures of that rule
each contradicted two other sentences in their own file.

Keep every count next to the qualifier that makes it true. "Three residues closed"
and "three residues closed *among the ones this branch introduced*" are different
claims; when two numbers answer different questions about the same thing, state
both with their questions attached.

- [ ] **Step 5: Write the CHANGELOG entry**

Measured numbers only. State what Slice ③ delivered against §25's scope bullets
and exit criteria by number, and state the two limitations explicitly rather than
glossing them: (i) mismatch tests assert
`status`/`next`/`consumed`/`stream-offset`/`code` only, because the structured
parser-error record is deferred to M4/M5 (design §8); (ii) §22.9 bullet :1314's
cross-cell artifact retention is not built (no `upload-artifact` step exists in
`.github/workflows/ci.yml`), so "determinism" here means same-process, cross-lane
and golden-equality, established transitively; and (iii) D10b's carried-in gap —
no lane compiles and executes a vacuous complement — which belongs to §25:1527
and exit :1537 and closes with the milestone unless a task closes it first. Name
its ledger provenance. Three limitations, not two: the count and the qualifier
travel together.

- [ ] **Step 6: Final whole-suite run and commit**

```bash
make test-all && ctest --preset release -R 'mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

```bash
git add README.org CHANGELOG.md docs/plans/byte-machine-implementation-plan.md docs/plans/milestone-3-design.md docs/plans/milestone-3-slice-3-implementation-plan.md test/support/cmake/SchemeMutationSuite.cmake && git commit -m "docs: Milestone 3 close-out — measured totals and dispositions"
```

- [ ] **Step 7: Request the whole-branch review**

Every task passing tells you nothing about the seams: the whole-branch review is
what finds an invariant with no owner. Use
`superpowers:requesting-code-review` over the full branch diff, and quote
constraints rather than paraphrasing them — an invented constraint is
indistinguishable from a real one and blocks fixable findings.

- [ ] **Step 8: Ask before running the closing ritual**

AGENTS.md's closing ritual is the agent's to **perform** (squash merge, catch up
`main`, delete the branch, reflect), but merging `main` is gated: check
`mergeable` and CI, then ask the user for the go-ahead and run it on their yes.
Do not hand the merge to the user, and do not run it unasked.

---

## Self-Review

**1. Spec coverage.** Design §7's six bullets, against tasks:

| §7 bullet | Task |
| --- | --- |
| Multi-alternative fixtures over Slice ②'s trie | 3 (absolute), 4 (differential) |
| Ambiguous-terminal-prefix rejection, one new diagnostic code (§4.5) | 1 |
| The cycle extension (§25:1533), both halves of §25:1540 | 2 |
| Determinism pins for sequence machines (§22.9) | 5 |
| The `HTTP/1.0`⁄`HTTP/1.1` fixture | 3 (built), 4 and 5 (driven) |
| §8's mirror trap — shared-prefix *structure* is required, *specialization* is deferred | §0 D11 |

Parent-plan scope: §25:1529 multi-alternative half → Tasks 3-4; :1532
ambiguous-prefix rejection → Task 1; :1533 cycle extension → Task 2; exit :1539
determinism → Task 5; exit :1540 both halves → Task 2. Note :1533 is attributed in **halves** (§0 D6): its
EOF-cycle half shipped in Slice ②, measured on unmodified `main`; only the
zero-progress half is Task 2's.

Carried-in items from the ledger, each with its destination: the :894 check with
one new code → Task 1; the two internal assert-guards as its floor → §0 D5,
Task 1 Step 4; `pass-overlap` still byte-dispatch-only → §0 D1, resolved as
**permanent** rather than deferred; `pass-zero-progress`'s REPORT guard and its
measured hang → Task 2; the guard fixtures' "symmetric known work" → §0 D5,
**corrected by measurement — only `interpret-tests.sps` is affected, and it is
rewritten rather than deleted**; no **differential** over a branching trie
(the design's gap statement, with its qualifier restored — see Task 4 Step 2's
dated correction) → Task 4; the one Pass 33 subsumption (arm 6 vs arm 1) → untouched, and the sweeps
in Tasks 1-2 must not silently reclassify it; the vacuous-complement gap → §0 D10b,
**named rather than closed**, with Task 6 recording it.

**2. Placeholder scan.** Two steps deliberately hand the implementer a
**measurement** rather than a literal, and both say so explicitly and say how to
take it: Task 3 Step 6's and Task 4 Step 7's non-vacuity mutation pins. That is
not a placeholder — AGENTS.md forbids writing an unmeasured pin into the tree, so
a plan that invented one would be instructing a violation. Everything else carries
its literal.

Task 4 was a placeholder in this plan's first draft — a numbered list of "required
content" rather than code, which is exactly the `"Write tests for the above"`
failure the writing-plans skill names. It now carries the complete program, and
that program was **run verbatim** (`cases=8 checks=20 failures=0`), as were
Task 1's `verify-tests.sps` group and `interpret-tests.sps` rewrite
(`cases=55 checks=72` and `cases=21 checks=40`), Task 2's two cases
(`cases=57 checks=76`), Task 3's absolute program (`cases=12 checks=19`) and
Task 3 Step 3b's structural group (`cases=38 checks=82`). Task 5's determinism
program is the one Scheme block **not** run end to end during plan authoring,
because it needs a golden that does not exist until Task 5 Step 3 generates it;
its `render-machine` byte count (3849) and the first three lines of the golden
*were* measured.

**2b. What an adversarial review of this plan changed, recorded because the plan
is the thing being reviewed.** A thirty-agent review of the first draft, each
finding independently refuted before it counted, produced twenty-four surviving
findings, of which three were critical and every one was a defect measurement
would have caught and reading had not:

- **The new pass was a structural clone of `node-overlaps`**, duplicating three
  shipped single-line `FIND`s and hard-failing the suite with "pattern occurs 2
  times … expected 1" — the `SITES` assertion firing in the direction the plan's
  own Global Constraints did not mention. Fixed by D8b's rename; re-measured with
  an exhaustive scan over all 36 `verify.sls` `FIND`s.
- **A second shipped `FIND` was byte-identical to the one D8 named** (`:3585`
  beside `:3235`), and the obvious re-anchor for it would have made Task 2's own
  new mutation unpinnable. Fixed in D8 and Task 2 Step 6, with the corrected
  `REPLACE` measured to emit exactly one FAIL record.
- **Task 1's `interpret-tests.sps` rewrite orphaned two Pass 34 mutations.** The
  draft deleted the cases they are pinned to and asserted the guards had become
  unreachable. They had not: `(byte-machine private ir)` exports
  `make-verification-result`, so the caller-who-skips-verification is
  expressible, and witnessing the guards through it keeps both mutations, both
  pins, both guards and all nine `EXPECT_SURVIVES`. This is AGENTS.md's rule in
  the flesh — "find something that can witness the decision before concluding
  nothing can" — and the first draft concluded first.
- Two further findings were **subsumption in miniature**: the one-directional
  mutation's records were a strict subset of the never-run mutation's on any
  per-ordering check, and the two enumeration mutations were indistinguishable
  on every check the draft had. Both closed by count-don't-witness fixtures (the
  summed-orderings check and the nested-family check), measured to give six
  mutants six distinct values.
- §25:1533 was treated as one bullet when it has **two halves**, the EOF-cycle
  half having shipped in Slice ②. Measured on unmodified `main`. Recorded in D6
  and attributed in halves by Task 6.

**3. Type consistency.** `http-version-bytes` takes a symbol (`'zero` / `'one`)
and returns a byte list in Tasks 3, 4 and 5; `http-version-shared-prefix` takes no
argument and returns a byte list, and is called as `(http-version-shared-prefix)`
at all three call sites. `make-http-version-machine` and
`make-http-version-advance-machine` take no arguments. The diagnostic code
`'ambiguous-sequence-prefix` is spelled identically in `verify.sls`,
`verify-tests.sps`, `interpret-tests.sps` and all three mutation pins. The lane
feature segment is `http-version` in all six registrations, and the golden
environment variable is `BYTE_MACHINE_HTTP_VERSION_GOLDEN_FILE` in the program,
both lanes, and the mutation-suite registration.

**4. Known plan risk, stated rather than hidden.** The predicted lane count (82
after Task 3, 84 after Task 4, 86 after Task 5) and mutation totals (229 after
Task 1, 230 after Task 2, then one pass each for Tasks 3-5) are **arithmetic to
check, not facts**. Design §9 records that sizing is a floor: Slice ② predicted ~205
mutations and measured 223. Every number in this plan that describes the *future*
is a prediction; every number that describes the *present* was measured during
plan authoring against `main` = `49c8cc4` and is labelled as such.
