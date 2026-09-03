# Milestone 4 Slice ①b — Field Declarations, Storage, and the Accessor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the machine its first field. `make-uint-field` and its validation, the
`fields` argument becoming load-bearing, verify pass 6a's declaration half, slot assignment
into the encoding's reserved table, the parser's field-storage slot, `parser-field-ref`, and
`parser-reset!` restoring declared initials.

**Architecture:** Slice ①a reserved three slots empty so this slice fills two of them and
**moves no existing golden and no existing fingerprint** — that is the headline oracle, and
§6 is where the reservation is shown to have paid. The third reservation, emitted `exec`'s
seventh parameter `fieldv`, is **Slice ②'s and must stay empty here**; the code says so at
`compile.sls:63` and `runtime.sls:106`, and filling it moves every golden.

**Tech Stack:** R6RS Scheme (Chez 10.4.1), CMake/CTest lanes (CMake 4.3.3 local, floor 3.26),
the in-repo mutation suite (`test/support/cmake/SchemeMutationSuite.cmake`).

Design authority: [milestone-4-design.md](./milestone-4-design.md) §6, with §4.2, §4.3 and
§4.7 item 3; decisions
[0019](../decisions/0019-encoding-format-2-pre-provisioned.md) and
[0020](../decisions/0020-field-shape-is-a-constructor-contract.md); parent plan
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md) §9.1:281-283 and
:301-306, §10.1:480, §10.2:488-495, §12.5:738, §13:801 and :816-818, §16.2:884-889, §16.3:924,
§17:962, §22.4:1267, §25:1559 and :1564, §29:1754.

**Where this plan and the design differ, §0 records the difference and which one this plan
follows.** The design's §6 was authored against `a942327`; Slice ①a has since rewritten
`runtime.sls`, `compile.sls`, `verify.sls`, `interpret.sls` and `normal-ir.sls`, so **every
"pre-slice" line number in §6 predates it** and every number in its exit evidence is stale.
§0b re-derives them.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **The ①b baseline is `51fd5f3`, not the Slice ①a merge.** Measured there (Darwin arm64,
  Chez 10.4.1, CMake 4.3.3): `ctest --preset release` **90/90**, `--preset pr` **90/90**
  (they select the same 90 — `pr`'s label filter admits every layer present, so it is not a
  subset today), `--preset no-scheme` **8/8**, Scheme mutation suite **48 passes / 250
  mutations** (zero `UNCAUGHT`, zero `FATAL`, nine `EXPECT_SURVIVES`), CMake mutation suite
  **1 pass / 72 mutations**.

  **Pin that SHA in every fixtures gate.** `51fd5f3` narrowed the emitted `errs` table
  (resolving decision 0022 item 7) and **deliberately moved `generated-pause.golden.sls`**.
  A gate written as "diff the goldens against the ①a merge" reports that as an ①b regression;
  worse, an implementer may "fix" the golden to make it pass. Once this branch is
  squash-merged the SHA changes — re-derive the baseline from the branch point, never from
  `main`.

- **This slice moves NO golden and NO fingerprint.** Four distinct IR fingerprint values at
  **22 sites** in `src/` + `test/`, none in `src/`:

  | Value | Machine | compile-tests | normal-ir-tests | golden | SchemeMutationSuite | total |
  | --- | --- | --- | --- | --- | --- | --- |
  | `14095574568398596535` | one-byte | 2 | 1 | 1 | 8 | **12** |
  | `13828870821654800916` | node-routing eof | 0 | 1 | 0 | 2 | **3** |
  | `17903327606435836645` | pause | 0 | 1 | 1 | 3 | **5** |
  | `16999772257989587335` | http-version | 0 | 0 | 1 | 1 | **2** |

  A fingerprint or golden moving is decision 0019 point 5's **STOP** condition: the repair is
  the missing reservation, not the baseline. The one legitimate exception is stated in §0 D3.

- **`fieldv` is Slice ②'s.** Emitted `exec`'s seventh parameter stays empty. `reserved-member-3`
  gains **nothing** in this slice — and `SchemeMutationSuite.cmake:6884-6890` FINDs the entire
  `reserved-member-3` literal, so adding to it breaks that pin as well as every golden.

- **`SITES` defaults to 1 and is asserted exactly, in both directions.** Count by **FILE**, not
  by SPEC. Two pins are coupled to lists this slice edits: `:5723-5728` FINDs
  `make-parser parser? parser-feed!` inside `reserved-member-2` (`compile.sls:51`), which ①b
  grows with `parser-field-ref` — **append on a new line, never reflow that line**; and
  `:6884-6890` FINDs `reserved-member-3` entire.

- **A textual census of the mutation suite cannot reproduce its own totals.** Read them from
  `SchemeMutationSuite.cmake:738-739`; two helper functions each declare one mutation and run
  one pass per invocation, so a `byte_machine_mutation(` count is short by twelve.

- **A mutation's witnessing test lives in its own SPEC lane's program — and in the PASS whose
  verify command runs it.** The `SPEC` field is metadata; what executes is the enclosing
  pass's `BYTE_MACHINE_MUTATION_VERIFY_COMMAND`. Slice ①a hit this twice: a mutation appended
  to the wrong pass reported `UNCAUGHT` both times. A new lane needs its own
  `byte_machine_mutation_reset()`, its own verify command, and its own
  `byte_machine_mutation_run(...)` — and adding a `run` means checking you have not orphaned
  the previous pass, which ①a also did.

- **Re-anchor a mutation's REPLACE with its FIND** (AGENTS.md). A stale `FIND` fails loudly at
  declaration; a stale `REPLACE` fails at nothing, and the mutant then differs from the
  baseline in two ways.

- **Sweep pins in BOTH directions, with a merge-base control.** Pass 33 holds **44** mutations
  at `51fd5f3`, so its sweep is 44 × 43 = **1892** ordered pairs before this slice adds one.
  Do **not** edit `SchemeMutationSuite.cmake:3314-3324` to "update" its 40/1560 figures: that
  is a dated record of a completed measurement, and editing it destroys evidence. The new
  sweep gets its own dated record.

- **Completion sentinels are mandatory and must read the OBSERVED value.** The width matrix in
  task 1 and any per-field loop need one, derived from what the constructor or verifier
  returned, never from the test's own expected list. The loop over the loops needs one too.

- **Lane and manifest bookkeeping is fatal in one direction and silent in the other.** A
  source+AOT pair per program, each with a `TIMEOUT` and a unique five-segment lowercase name;
  duplicate names and per-lane basename collisions are configure-time `FATAL_ERROR`. But
  **omitting a file from a lane's `SOURCES` reddens nothing** — the fingerprint expectation and
  the measurement are computed over the same declared manifest. Count the edits.

- **`ctest --preset <x>` does not build.** Editing a `.sls` and running ctest alone yields
  `PROVENANCE-ERROR` with exit **3**.

- Chez floor 10.4.1, CMake floor 3.26, no new dependencies. Conventional Commits. Run the
  suite before every commit. `.superpowers/` is git-ignored; stage explicitly, never
  `git add -A`.

- Commands (`chez`, not `scheme`):

```bash
make build
```

```bash
ctest --preset release --output-on-failure
```

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

---

## §0 Design calls locked by this plan

**D1 — the design's Task 3 trap does not exist, and its prescribed `EXPECT_SURVIVES` must not
be written.** §6 task 3 says "no external test can reach the new arm: `machine-tag` is a
freshly allocated, unexported vector compared with `eq?`, so a test cannot forge a `machine?`
object", and on that ground it tells the implementer to declare the permissive direction
`EXPECT_SURVIVES`.

**Measured, and false.** Descriptors are bare R6RS vectors with no opacity, so a holder of one
instance steals the tag with `(vector-ref m 0)` — an `(rnrs)` primitive, no private import.
Run against the shipped tree with exactly `verify-tests.sps`'s own imports:

```
(real-verifies #t)
(slot0-is-the-tag #(byte-machine-machine))
(slot1-ir-version 1)
(forged-verifies #t diagnostics 0)
(mutated-still-verifies #t version 42)
```

Two routes work: build a fresh vector carrying the stolen tag and a wrong version, or
`(vector-set! m 1 42)` on a real machine. Either produces a `machine?` object whose IR version
is not 1, reachable from a test.

So §16.2:884's check **is witnessable in both directions**, and this slice writes **no**
`EXPECT_SURVIVES` for it. AGENTS.md is explicit that `EXPECT_SURVIVES` is for the genuinely
unwitnessable with a written reason, never to reach green — and "this cannot be tested" is a
claim to demonstrate. The design demonstrated the opposite of what it concluded. The design's
count of "two `EXPECT_SURVIVES` additions" in its exit evidence drops to one, and the ninth
stays the total.

*The forged-machine route is a test-only device and must be labelled as one at its site.* It
reaches through the tagged-vector representation deliberately, and it is the only way to
witness a check the public API cannot reach. Confine it to the one case that needs it.

**D2 — the field pass is new (`pass-fields`), not an extension of `pass-names` or
`pass-names-valid`.** Field names are invisible to both: `pass-names`'s duplicate loops walk
`machine-nodes` and `error-names`, and `pass-names-valid`'s three arms walk `machine-name`,
`machine-nodes` and `machine-errors` — the third being where ①a's `reason` clause landed, so
it still has three arms and still sees no field. Both new diagnostics carry
`invalid-field-declaration` (§4.6's two-code budget) with the offending **field** name in the
diagnostic's existing `node` slot, following `duplicate-error-declaration` and
`missing-target`, which already put non-node symbols there.

**D3 — one golden legitimately moves, and only one, and only if a field is declared.** No
*shipped* fixture declares a field, so all three committed goldens and all four fingerprints
stay put. Any **new** fixture that declares one will encode a non-zero field count and emit
field initials, which is the reservation working as designed — not a violation of 0019 point
5. State this at the gate so a reviewer does not read a new golden as a moved one.

**D4 — slot = declaration index**, per §17:962. The design says so and the normalizer already
numbers declared nodes that way. `parser-field-ref` resolves a name through one name→slot map;
**duplicate field names are what task 4 must reject**, because two `u8 count` declarations
verify clean today and would take slots 0 and 1, after which the accessor answers with
whichever it finds first and orphans the other slot and its initial.

---

## §0b Hazards measured at HEAD (`51fd5f3`) that no design sentence names

**H1 — every number in §6's exit evidence is pre-①a and wrong.** Re-derived:

| §6 says | At `51fd5f3` |
| --- | --- |
| 5 fingerprint literal sites, 3 distinct values | **22 sites, 4 values** (table in Global Constraints) |
| `normal-ir-tests.sps:73`, `:122`, `:147`; `compile-tests.sps:165`, `:212` | all five moved; re-locate by value, not by line |
| 7 mutation pins embedding a fingerprint | **10** |
| `EXPECTED_PASSES`/`MUTATIONS` 46/236 at `:734-735` | **48/250** at **`:738-739`** |
| 86 release lanes | **90**, and `pr` is also 90 |
| 50 `(make-machine` sites in `test/` | **56** in 17 files — all still pass `'()` for `fields` |

Only `EXPECT_SURVIVES` = 9 and the CMake suite's 1/72 survive intact.

**H2 — three §6 claims are right for a reason that is now false.** The repo's own named defect
class, in the document this plan is built from. (1) "the emitter … imports one source-IR name,
`machine-name`" — `compile.sls:18-19` now imports **four**. (2) "`make-parser` copies it into
parser slot 2 in all **three** variant arms" — there are **two** (`'op`, `'v2`) plus a loud
unreachable else; ①a retired `'v1`. (3) "the generated library … whose only other top-level
definition is `exec`" — every golden now has **three**: `errs`, `exec`, and the binding.
Carry the instruction into every task brief verbatim: *check what this claims the code DOES
against the code, not against the prose.*

**H3 — the comment §6 tells the implementer to contrast against no longer exists.** §6 says
`reserved-member-3`'s unchangedness is proved by ①a's drift guard "rather than the comment at
`compile.sls:101-107` that currently has to say 'checked, not assumed'". ①a deleted that
comment; `compile.sls:101-107` is now the string-escaping loop. The live guard is
`test/common/member3-drift-tests.sps`, whose *no undeclared emitted local* case reddens if ①b
emits **any** new local — a tripwire the design does not name by file.

**H4 — filling the `u16be` reservation kills a pin by construction, and §6's die-list omits
it.** `SchemeMutationSuite.cmake:5042-5053` (`normal-ir: the reserved field count is not
written`) FINDs

```
       (put-u32be p (vector-length states))
       (put-u16be p 0)
```

Replacing `(put-u16be p 0)` with a real count takes that FIND to **0 sites** and the suite
hard-fails at declaration. Re-anchor it in the same commit, and re-measure — its decision
(the count reaches the fingerprint) survives, its text does not.

**H5 — `parser-reset!`'s last line is the file's last line.** `runtime.sls` ends at
`    (parser-set-stored-error! parser #f)))` — the clear plus the closing parens of both
`parser-reset!` and the library. Appending the field-restore there edits that line, and pin
`:3073-3079` on it is an `EXPECT_SURVIVES`, which fails loudly in either direction.
`runtime.sls:405`'s comment (`Field, span, and poisoned/busy state do not exist yet (M4/M5)`)
is a live instruction this slice falsifies and corrects in place.

**H6 — the `machine-fields` grep is a genuine binary, and one of the few §6 measurements that
survives.** Exactly two occurrences at HEAD — its export and its definition — confirmed two
ways. §6's gate ("`rg machine-fields` no longer returning only its definition and export, with
at least one hit inside the normalizer") is therefore usable verbatim.

**H7 — a repo-wide `EXPECT_SURVIVES` count is not the suite's count.** Anchored, repo-wide,
the grep returns **12**: nine in `SchemeMutationSuite.cmake`, one in `MutationSuite.cmake`, and
two inside `MutationRunnerSpec.cmake`, which are the runner's own spec fixtures. Gate on the
**nine in the Scheme suite**, and say which question the number answers.

**H8 — `make-machine` accepts any proper list as `fields` today, and nothing reads it.**
Measured: `(make-machine 'm 'start (list 'junk 42 "string") …)` succeeds and `machine-fields`
returns it. That is why task 1's `(for-all uint-field? fields)` guard is what makes the
descriptor load-bearing, and why the guard is vacuously true across all 56 existing call sites.

**H9 — tasks 1 and 2 cannot be a PR boundary.** At the end of task 2 an author can construct
and export field declarations, the suite is green, and the feature does nothing: a machine
declaring `(make-uint-field 'count 8 7 #f)` and one declaring nothing produce the same
fingerprint and the same `.sls`, byte for byte. The declaration and its first reader ship in
one PR.

---

## File Structure

**Modified — `src/`:**

| File | Change | Tasks |
| --- | --- | --- |
| `private/ir.sls` | `make-uint-field`, `uint-field?`, four accessors, constructor validation; `make-machine` gains `(for-all uint-field? fields)`; `machine-ir-version` gains an accessor | 1, 3 |
| `graph.sls` | Re-exports the constructor, predicate and accessors — **both** the export list and the mirrored `only` import list | 2 |
| `verify.sls` | `pass-schema` gains §16.2:884's version check; new `pass-fields`, declaration half, joined to `verify-machine`'s `append` | 3, 4 |
| `private/normal-ir.sls` | The `only` import gains the field accessors; slot assignment; the reserved `u16be` count becomes real and per-field records follow it | 5 |
| `runtime.sls` | A ninth parser slot for field storage; initials from the ABI payload's member 0 and from the interpreter's new op message; `parser-field-ref`; `parser-reset!` restores initials | 6, 7 |
| `compile.sls` | The metadata vector's member 0 computed from the declarations; `reserved-member-2` gains `parser-field-ref` (**appended, never reflowed**) | 6, 7 |
| `interpret.sls` | One new op-message arm, `'field-initials` | 6 |

**`compile.sls`'s `reserved-member-3` gains nothing** (§0), and emitted `exec`'s `fieldv` stays
empty — that is Slice ②'s.

**Created:** a program for the descriptor and the accessor, and its lane pair.

*(Corrected 2026-09-02 by the whole-branch review: this said a **field fixture under
`test/support/harness/byte-machine/test/`** would be created, and none was. The fixture is
built inline in `test/common/field-access-tests.sps`, the way the determinism lanes build
theirs, because it is used by one program; a harness library is for a fixture two lanes share.
Also "a unit program … and their lane pairs" — singular, and it is a **differential** pair,
`byte-machine.differential.field.chez.{source,aot}`, which is what the design's own exit
evidence names.)*

---

## Task 1: The descriptor, and the machine guard that makes it load-bearing

Design §6 task 1; decision 0020's constructor half; §9.1:283; §10.2:488-491.

**Files:** `src/byte-machine/private/ir.sls`, `test/common/ir-tests.sps`.

- [ ] **Step 1: Failing tests first.** Drive the four widths and their boundaries.

- [ ] **Step 2: `make-uint-field name width initial source-label`**, on the shipped
  tagged-vector idiom — `tag` at `ir.sls:41`, `tagged?` at `:42-43`, `require-symbol` at
  `:44-47` (all three still current; `ir.sls` has not been touched since M3 Slice ②).

  Validation is decision 0020's **constructor half only**, on the `make-edge` precedent at
  `ir.sls:202-203`: `width` in `{8, 16, 32, 64}` by `memq`; `name` a symbol via
  `require-symbol`; `initial` an exact integer with `(<= 0 initial (- (expt 2 width) 1))`.
  These carry **no diagnostic code** — a contract violation is not a diagnostic (§4.6).

  **The u64 row must actually run at 2^64−1**, which is above `(greatest-fixnum)` = 2^60−1 on
  the only supported runtime. A width matrix that stops at u32 tests nothing about bignums.

- [ ] **Step 3: `make-machine` gains `(for-all uint-field? fields)`** beside its two existing
  guards at `ir.sls:361-364`. Today the collection loop checks only `list?` (`:357-360`), so
  any proper list passes — measured, a machine can carry `(junk 42 "string")` as its fields.

  **Gate: the whole `release` preset green with ZERO test-file edits.** All **56**
  `(make-machine` sites in `test/` pass `'()`, so the guard is vacuously true across the
  corpus. If a lane reddens, the guard is wrong, not the fixtures.

- [ ] **Step 4: a mutation per decision**, each with a measured signature: the width set, the
  initial's upper bound, and the machine guard.

---

## Task 2: The façade, both lists

Design §6 task 2. **Files:** `src/byte-machine/graph.sls`, `test/common/graph-tests.sps`.

- [ ] **Step 1:** Add the constructor, predicate and accessors to `graph.sls`'s export list
  **and** its mirrored `only` import list. Editing one leaves the constructor unreachable —
  silently at read time, loudly at first use.

- [ ] **Step 2:** Machine *accessors* stay private, per the disposition in `graph-tests.sps`
  and §9.1's construction-only surface. Predicates and accessors for the *descriptor* do come
  through, on M3 Slice ①'s matcher precedent: a grammar author needs to test what they just
  built.

- [ ] **Step 3: Gate.** `byte-machine.unit.graph.chez.{source,aot}` builds a field-declaring
  machine importing nothing but `(byte-machine graph)`.

**Executed 2026-09-02: this task declares NO mutation, and the reason is recorded beside the
pass rather than left as an omission.** A mutation dropping a name from one list was written
and measured: under the suite's launcher it exits **255 with no harness output at all**,
because a missing export is an expand-time failure — the library never loads, no case runs,
and there is nothing to match. That is the bare nonzero-exit catch AGENTS.md forbids, wearing
no signature. What guards the decision is stronger than a mutation anyway: a half-edited
façade makes `(byte-machine graph)` unloadable, so every lane importing it fails at once, at
build time, and no input reaches a half-edited façade and survives. (Run *outside* the
launcher the same mutant surfaces as a case raise with status 1, because the reference is
inside a lambda — pinning that would have recorded a signature this suite never produces.)

**This is not a PR boundary (H9).** At this point the feature does nothing.

---

## Task 3: `pass-schema`'s unsupported-IR-version check

Design §6 task 3; §4.7 item 3; §16.2:884. **Read §0 D1 first: the design's trap does not
exist and its prescribed `EXPECT_SURVIVES` must not be written.**

- [ ] **Step 1: Failing test first**, using the forged-machine route D1 measured. Label it at
  the site as a test-only device that reaches through the tagged-vector representation
  deliberately, because the public API cannot produce a wrong version and this is the only way
  to witness the check.

- [ ] **Step 2:** Give `machine-ir-version` an accessor (it is stamped at `ir.sls:351` into
  slot 1 at `:365` with none anywhere, verified three ways), and extend `pass-schema` — today
  a single `machine?` tag test — with the version comparison.

- [ ] **Step 3: Mutations in BOTH directions**, both witnessable: permissive (accept any
  version) caught by the forged-machine case, and restrictive (mutate the supported constant,
  so every machine becomes unsupported) caught by every verify lane. Measure each signature.

---

## Task 4: `pass-fields`, declaration half

Design §6 task 4; §16.3:924 item 6; decision 0020's verifier half.

- [x] **Step 1: Failing tests first.** Two `u8 count` declarations verify clean today —
  measured — and that is the defect this pass closes (**D4**).

- [x] **Step 2:** A **new** pass (**D2**), carrying duplicate field names and portable field
  names per §10.1:480, reusing `valid-name?`. Both diagnostics carry
  `invalid-field-declaration`, with the field name in the diagnostic's `node` slot.

- [x] **Step 3: Do NOT re-check widths or initial ranges here.** They are closed at
  construction, so a machine whose field failed construction never exists and the arm would be
  dead code whose permissive mutation survives — decision 0020's one-rejection-site rule.

- [x] **Step 4:** Join the pass to `verify-machine`'s `append`, and re-sweep Pass 33 in both
  directions: adding a *check* widens every existing pin's collision set exactly as adding a
  mutation does. 44 pins, 1892 ordered pairs, against a control on the branch point.

  **Executed 2026-09-02.** Control at the branch point `2302ffd`: **44 pins, 1892 ordered
  pairs, 5 collisions** — the plan's predicted numbers exactly. HEAD: **49 pins, 2352 pairs**,
  8 collisions before the fixes, **5 after** — the control's five, same labels, same pairs.
  Three were this branch's and all three are closed:

  - `verify: every field name is reported as nonportable` (task 4's restrictive mutant) was
    **subsumed**, not merely loose: *both* of its records were also emitted by `verify: the
    reason repertoire rejects every reason`, because the field fixtures carry `errs` — two
    declarations, two reasons — so a two-field clean machine reddens 0-versus-2 by either
    route. Separated **by construction**, the way the residue rules ask: a third field makes
    the restrictive mutant report 3 where the reason mutant reports 2. Fixture change, not a
    pin edit.
  - `ir: the supported IR version is not the one machines are stamped with` (task 3) was
    **under-anchored** in the degenerate way — its pin was a bare *check name carrying no
    value*, `"...: no diagnostics"`, so it matched any mutant that reddened that case at all,
    and two did. Its own case expects **zero** diagnostics and therefore has no code to
    compare, so it was re-anchored off that case entirely, onto a record computed as a set
    difference against all 48 others. ①a's finding was that a count is a weaker anchor than a
    named check; a check with no value is weaker still, and that is the reusable form of it.
  - The third was the first two counted twice over.

- [x] **Step 5 — RETRACTED 2026-09-03 by the whole-branch review. The claim below is wrong
  about `SchemeMutationSuite.cmake`, and the retraction is recorded at that file's residue
  block.** That file already enumerates five pairs (`:3418`, `:3432`) and already carries a
  measured separating attempt for `arm 6 < arm 1` at arm 6's own pin (`:3415-3416`). The five
  measured here are right and agree with it; what was wrong was comparing them against the
  "four pairs" heading alone, without reading the six lines beneath it. What *does* survive is
  narrower and is not about that file: **Slice ①a's plan** records four where five is correct,
  and is annotated at its own site. Struck text follows.

  ~~Step 5 (not in the plan; found by step 4's control): the residue is FIVE pairs, not
  four.~~ Slice ①a's audit recorded four subsumed pairs and `SchemeMutationSuite.cmake`'s
  residue block lists four. There is a fifth: `verify: a sequence case's byte edge into a
  finish terminal is not flagged (arm 6, :908)` emits exactly two FAIL records and `verify: a
  sequence node's case and mismatch targets are not out-targets (arm 1, node-out-targets)`
  emits both of them plus seven more, and arm 6's pin is the shared count. Measured at
  **three** revisions — `c3ceec2` (42 pins / 1722 pairs), `2302ffd` (44 / 1892) and HEAD (49 /
  2352) — and the residue is the same five labels and pairs at every one, so it is inherited
  debt that predates Milestone 4: **missed, not created**. It is recorded in the tree beside
  the residue block, and recorded there as **unresolved**: its bucket rests on the subset test
  alone, and AGENTS.md is explicit that the subset test is not sufficient to say "subsumed" —
  the separating attempt has not been made, and it is a sequence-dispatch question rather than
  this slice's.

  Two harness bugs were found and fixed inside the sweep itself before any of the above was
  believed, both of which manufacture false findings: CMake **unescapes a quoted argument**
  before compiling the regex, so judging the raw file text compiles `\\(` where the suite
  compiles `\(` and four pins appear not to match their own mutants; and CMake's regex `.`
  matches a newline, so a pin spanning two records with `.*` appears not to match its own
  mutant unless the judge is `DOTALL` **and** runs against the whole output rather than
  record by record. A sweep that reports a pin failing to match *its own* mutant is reporting
  a bug in the sweep, not in the pin — the suite itself was green throughout.

---

## Task 5: Slot assignment and the field table

Design §6 task 5; §17:962; decision 0019 item 3(a).

- [x] **Step 1: Failing test first** — two machines differing only in a field declaration must
  differ in fingerprint, and a zero-field machine must still encode a count of zero.

- [x] **Step 2:** `normal-ir.sls`'s `only` import gains the field accessors — it currently
  cannot see fields at all, which is why `lower-machine` never has. Assign slot = declaration
  index (**D4**).

- [x] **Step 3:** The reserved `u16be` count becomes the real count, with per-field records
  following it in the position ①a fixed. **This kills a pin by construction (H4):** re-anchor
  `SchemeMutationSuite.cmake:5042-5053` in the same commit and re-measure it.

- [x] **Step 4: Gate.** All four fingerprints and all three goldens **unmoved** — a
  zero-field machine encodes identically. A new field-declaring fixture legitimately gets its
  own values (**D3**).

  **Measured.** `git diff --stat 51fd5f3..HEAD -- test/fixtures/` is **empty** — no golden
  moved and none was added. The three pre-existing `normal-ir-tests.sps` fingerprint literals
  are unchanged; `14095574568398596535` now appears **twice** rather than once, the second
  being the new *"filling the reservation does not move a zero-field fingerprint"* case, which
  states decision 0019 item 5 as the invariant it is instead of leaving the goldens to notice.
  One new value, `5570336114768739383`, for the slice's own two-field fixture.

  **Record layout**, since neither the design nor 0019 fixes it: each record is
  `[name-length u16be][name UTF-8][width u8][initial u64be]`, in slot order, and the **slot is
  not written** — it is the record's position, and writing it too would let the stream express
  a table whose slots disagree with their order. The initial is a fixed 64 bits regardless of
  the declared width, so the layout does not vary with the value; a width-sized initial would
  let two declarations of different widths share a byte string whenever the narrower value
  fits, which is the collision the width byte exists to prevent.

- [x] **Step 5 (the discipline's, not the plan's): the normal-ir pass's whole-pass sweep.**
  Six cases joined that lane, and a check widens every existing pin exactly as a mutation
  does. **30 pins, 870 ordered pairs, zero collisions**, every pin still catching its own
  mutant; control at `51fd5f3`, 25 pins / 600 pairs, also zero. Recorded in the pass's own
  audit block.

  **The count byte cannot be pinned on any inequality case**, which is why this slice measures
  a golden of its own rather than resting on the *"differ in fingerprint"* family: with the
  per-field records still written, zeroing the count leaves every differing-field pair still
  unequal and not one of them reddens. Symmetrically, the **slot number** is witnessed by no
  fingerprint at all — it is deliberately not encoded — so the table assertion is its only
  witness, and that is why the assertion states each entry **whole**, `(name width initial
  slot)`, instead of checking the length and the names.

---

## Task 6: The parser's field slot, and the initials

Design §6 task 6; §12.5:738; decision 0019 item 3(b).

- [x] **Step 1: Failing tests first**, including `parser-reset!` restoring declared initials.

- [x] **Step 2:** A ninth parser slot beside `stored-error`. Initials reach it through the
  **shipped per-lane asymmetry**, not a uniform mechanism: `make-parser`'s `'op` arm *asks*
  the closure (a new `'field-initials` message in `interpret.sls`), and the `'v2` arm *reads*
  the ABI payload's member 0, which ①a reserved empty. `compile.sls` computes that member from
  the declarations.

  **H2:** there are **two** variant arms plus a loud unreachable else, not three.

- [x] **Step 3:** `parser-reset!` restores the declared initials, and its comment at
  `runtime.sls:405` — "Field, span, and poisoned/busy state do not exist yet (M4/M5)" — is
  corrected in place to name what now exists and what still does not. **H5: that block ends at
  the file's last line and carries an `EXPECT_SURVIVES` pin.**

- [x] **Step 4: Gate.** No golden moves for a zero-field machine — the emitted text is
  identical to ①a's, which is what makes 0019's reservation true rather than hoped.

---

## Task 7: `parser-field-ref`, and the lanes

Design §6 task 7; §9.3:410; §13:801.

- [x] **Step 1: Failing tests first.** Read-only per §13:801; there is no mutating sibling to
  design.

- [x] **Step 2:** Add the accessor, raising `byte-machine-contract-violation` with a new
  `accessor-misuse` code for an undeclared field name. Add `parser-field-ref` to
  `reserved-member-2` **by appending on a new line** — `SchemeMutationSuite.cmake:5723-5728`
  FINDs the interior of `compile.sls:51`, and a reflow takes it to 0 sites. The
  `reserved-drift` lane asserts set equality, so the export and the mirror land in one commit.

- [x] **Step 3: Lane bookkeeping.** New source+AOT pairs, five-segment names, `TIMEOUT` on
  each, every imported library in **both** lanes' `SOURCES`. A library reached only through
  `environment` must be **statically imported** or the AOT lane alone fails.

- [x] **Step 4: Gate — the slice's exit evidence.** Each a literal:

  1. `rg -c 'machine-fields' src/ test/` returns more than the two occurrences it returns
     today, with at least one inside the normalizer (**H6** — this gate survives §6 intact).

     *(Corrected 2026-09-02 by the whole-branch review: the executed record read this gate as
     satisfied by "five sites in `normal-ir.sls`", which counts `normal-machine-fields` — a
     different identifier the substring search also matches. **`\b` does not separate them
     either**: `-` is a non-word character, so `\bmachine-fields\b` still matches inside
     `normal-machine-fields`, and the second measurement was wrong the same way as the first.
     The search that answers the gate is*
     `rg -c --pcre2 '(?<![\w-])machine-fields(?![\w-])' src/ test/`*, and it reports **11
     occurrences across 8 files** against **2 in one file** (`ir.sls`) at `51fd5f3` — including
     3 in `normal-ir.sls`, which is the normalizer hit the gate asks for. The gate holds; both
     numbers first quoted for it did not.)*
  2. All four fingerprints and all three committed goldens **byte-identical to `51fd5f3`**.
     Diff against that SHA, not against `main` (Global Constraints).
  3. `reserved-member-3` **unchanged**; `reserved-member-2` grows by exactly one.
  4. Declaration-time bounds at all four widths: initial `0` and `2^w − 1` accepted, `2^w`
     rejected — by the **constructor**, so this share of §25:1568 is discharged by a contract
     violation and never by a diagnostic. The u64 row runs at 2^64−1.
  5. `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` at their **measured** totals; the nine Scheme-suite
     `EXPECT_SURVIVES` unchanged (**H7**: a repo-wide grep returns 12 and answers a different
     question); CMake suite still 1/72.
  6. `release`, `pr` and `no-scheme` green at their measured counts.
  7. `CHANGELOG.md` and the status surfaces updated — §25:1559 is discharged **whole** by this
     slice, which is a status change.

---

### Tasks 6 and 7 — executed 2026-09-02, in ONE commit

**The plan asks task 6 for a test it cannot have, and that is why the two tasks ship
together.** Step 1 reads *"Failing tests first, including `parser-reset!` restoring declared
initials"* — but the parser's field slots have no reader until task 7's `parser-field-ref`
exists, so every task-6-only assertion about them would be a test that cannot fail. Rather
than write one, the storage and its accessor ship in one commit. Task 6 does have standalone
evidence — the emitted member 0, and the unmoved zero-field golden — and it is asserted in
`compile-tests.sps` either way.

**Member 0 carries `(name . initial)` PAIRS, not bare initials.** Decision 0019 item 3(b)
names it the field-initials member, and the parser needs two things from the declarations: the
initial values, and the name-to-slot resolution `parser-field-ref` answers by. The slot is the
pair's **position**, so one member fixes both, and it still renders `#()` when there are no
fields — which is what keeps `(quote #(#()))` byte-identical to ①a. A second member would have
been a second ABI growth for data the first already determines.

**Two of the slice's own decisions turn out to have no witness in this slice, and both are
recorded rather than papered over:**

1. `parser-reset!`'s field restore. **Measured: the mutation that deletes it passes the whole
   field-access lane unchanged.** `parser-field-ref` is read-only (§13:801) and ①b ships no
   writer, so slot 8 is constant for a parser's lifetime and restoring a constant is a no-op.
   It ships **now** under an `EXPECT_SURVIVES` carrying its measurement and its reopening
   condition, rather than being deferred to ②: a ② that adds a write without adding the
   restore leaks one parse's values into the next, and the restore arriving first makes that a
   defect ② must *introduce* rather than one it must *remember*. **This moves the Scheme
   suite's declared survivors from nine to ten, which contradicts step 4 gate item 5** — that
   gate was written before the measurement, and the measurement wins.
2. Per-parser **isolation** of the value storage, for the same reason. Two parsers sharing one
   vector and two holding their own are observationally identical through a read-only API. No
   case is written; the reason sits at the site, and the case belongs in ②'s writer commit.

**The `'field-initials` message breaks every hand-written op-closure stub.** Six in
`runtime-tests.sps`, each of which answered `bad message` and failed its whole group. They
answer `#()` now. Worth knowing before ② adds another message: the op protocol has no default,
so every addition to it is a change to every stub in the tree.

**`fields` cannot be a top-level `define`** in a program importing `(rnrs)` — it is
`define-record-type`'s auxiliary keyword, and the collision is a *"multiple definitions"*
error at expand time, not a shadowing warning. The same trap as `put-string` in ①a.

**Three mutations were measured and deliberately not written**, each because its record set is
*identical* — not a subset, the same set — to one that is: `make-parser`'s op arm discarding
what it asked for (versus `interpret.sls` answering with nothing), and the emitter rendering a
wrong field name (versus the v2 arm ignoring member 0 entirely). The one written is in each
case the one living in the file whose new code it names.

**Gate (step 4), each measured:**

1. `machine-fields`, counted with a boundary that actually excludes `normal-machine-fields`
   (`rg -c --pcre2 '(?<![\w-])machine-fields(?![\w-])'`), reaches **11 occurrences across 8
   files**, 3 of them in the normalizer, against **2 in one file** at `51fd5f3`. ✔ *(Corrected
   twice, 2026-09-02: first written as "five sites in `normal-ir.sls`", which counted
   `normal-machine-fields`; then re-measured with `\b`, which does not exclude it either,
   because `-` is a non-word character.)*
2. Three committed goldens and all four pinned IR fingerprints **byte-identical to `51fd5f3`**
   — `git diff --stat 51fd5f3..HEAD -- test/fixtures/` is empty. ✔
3. `reserved-member-3` unchanged; `reserved-member-2` **31 → 32**, exactly one. ✔
4. Declaration-time bounds at all four widths, discharged by the **constructor** in
   `ir-tests.sps` — `0` and `2^w − 1` accepted, `2^w` and `-1` refused, plus inexact and
   non-numeric. ✔
5. `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` at **49 / 271**; CMake suite **1 / 72**;
   `EXPECT_SURVIVES` **10, not 9** — see the deviation above. ✔ (amended)
6. `release` **92/92**, `pr` **92/92**, `no-scheme` **8/8**. ✔
7. `CHANGELOG.md`, `README.org` updated; §25:1559 discharged whole. ✔

---

### Whole-branch review — the three Criticals, fixed 2026-09-02

Eight review dimensions, each finding refuted by three independent verifiers (read-the-code,
run-it, already-handled), majority-2 to survive. **58 confirmed, 3 refuted**, deduping to
about 13 distinct defects — the same issue was found by up to ten dimensions independently.

**Critical 1 — `51fd5f3`'s `errs`-table fix did not close the defect it names, and decision
0022's amendment records it as measured closed.** Reproduced independently: two machines that
verify clean with **equal IR fingerprints** emitted **different bytes** (1262 vs 1225), the
larger carrying a duplicate `errs` entry. The filter cannot test declaration identity — the
normalizer resolves each site's declaration NAME to its code and reason before the emitter sees
it — so it tests pair membership, and an *unreached* declaration duplicating a *reached* pair
passed. `51fd5f3` fixed the case where the unreached pair is ABSENT from `reached` and left the
case where it is present under another declaration's name. Its own regression case cannot see
it: that case's spare declaration uses a distinct code, so the filter drops it from both
machines.

Fixed by dropping a pair already emitted, keeping declaration-order position — so no shipped
golden moves and no `errs` index shifts. Two new cases, both premises asserted; the errs-line
assertion is stated separately from the byte comparison, because two machines can also be made
equal by emitting the duplicate in BOTH, which is agreement bought by making the difference
unobservable.

**Critical 2 — both of task 4's "SUBSUMED" declinations were wrong, and one stated measurement
was false.** The join's record set is the UNION of the two permissive mutants', and a union is
inside NEITHER of the sets it unions — AGENTS.md's relation is "inside ONE sibling's", so it was
separable all along, and the tree already ships the remedy as the `:909` conjunction pin. Worse,
the second bullet claimed the restrictive duplicate mutant "reddens twenty-odd records across
five unrelated groups"; measured, it reddens **three records in one group**. That description
was true of an earlier TWO-field clean fixture — a third field was added later **in the same
task**, to separate a different pin, and the paragraph was never re-measured.

*The reusable lesson is not about fields: a measurement written against a fixture goes stale
when the fixture changes, and nothing in this suite checks prose.*

Both mutations are now written, both with conjunction pins. The re-sweep is **51 pins / 2550
ordered pairs / 7 collisions**: the 5 inherited, plus 2 new ones that are subsumption **by
construction** — each permissive arm is a strict subset of the join, because the join drops both
checks and each arm drops one, so the join is strictly more permissive on every machine and no
fixture can redden an arm while leaving it green. Kept anyway, because they name distinct
decisions; the cost is attribution, not detection, and it is recorded at the site.

**Critical 3 — decision 0019 point 5 was false and carried no amendment.** Commit `51fd5f3`
moved `generated-pause.golden.sls`; point 5 makes exactly that a STOP condition for every later
slice. The licence existed in 0022's amendment, the design's preamble and this plan — none of
which a reader arriving at point 5 by citation reaches. Concrete cost: a ② or ③ implementer
diffs against ①a's merge, sees the difference, and either halts or "fixes" the golden.

0019 now carries an Amendments block and a dated foot note moving the baseline to **`51fd5f3`**,
and the four inheriting sites are corrected at their own sites: two live gates in
`milestone-4-design.md`, Slice ③'s exit evidence, and the CHANGELOG's byte-identical claim.
Point 5's reasoning is untouched for its actual target — a golden moving because a *slot was
added late* is still a STOP, repaired by the slot and not the baseline. What changed is that a
golden is evidence, not an authority: when it disagrees with an invariant this record states,
the invariant wins.

Totals after the three fixes: `release` 92/92, scheme mutation **49 passes / 273 mutations**,
no golden moved against `51fd5f3`.

---

### Whole-branch review — the Importants and Minors, 2026-09-02

Fifteen distinct Importants and ten Minors, after deduping the 58 confirmed findings (the
same issue was found by up to ten dimensions independently).

**The one that mattered most was a correction to a correction.** ①b's task-4 record claimed
`SchemeMutationSuite.cmake`'s residue count was "one short" and that no separating attempt
existed for `arm 6 < arm 1`. Both false about that file: it already enumerates five pairs at
`:3418` and `:3432`, and `:3415-3416` records Slice ②'s *measured* attempt at arm 6's own pin.
The five measured were right; comparing them against the "four pairs" heading **without reading
the six lines beneath it** is what produced a confident correction to a record that was already
correct. Retracted at that file's residue block, struck in this plan. What survives is
narrower and elsewhere: **Slice ①a's plan** records four where five is right, annotated at its
own site.

**The design's u64/bignum row had been dropped without record.** `milestone-4-design.md`
:1208-1218 requires a distinct non-zero initial per width and a u64 initial at or above `2^60`
— the bignum boundary on this host, where `(greatest-fixnum)` is `2^60 − 1` — because below it
all four widths exercise the fixnum path only and §15:856's "must not rely on host fixnum
width" is untested. The fixture shipped as three fields, one of them zero, no u64. It is now
four widths with distinct non-zero initials, `total u64 = 2^60`, a loop over all four carrying
a sentinel that reads the **observed** count, and a case asserting the u64 value is above
`(greatest-fixnum)` so a host with a wider fixnum fails loudly rather than quietly ceasing to
test what the case exists for.

**The zero-field control was one interpreted machine shared by both groups**, so the case
inside `parser-field-ref (generated)` ran the interpreter and the v2 arm's empty-member-0 path
was executed nowhere in the tree. Each lane has its own now — which needed a second machine
NAME, since the emitted library is named after the machine and two `field-access` fixtures
would emit two `(generated field-access)` libraries into one process.

**Name-keyed cross-executor reads are blind to slot ORDER.** Each lane resolves a name against
its own vector, so two differently-ordered vectors both answer correctly for every name. The
two orders come from different sources — `interpret.sls` from `machine-fields`, `compile.sls`
from `normal-machine-fields` — so their agreement was a claim, not a construction. Two cases
now check it: the emitted member 0's text, and the normalizer's own order.

**Both field diagnostics' "carries the offending field name" decision was asserted nowhere.**
`verify-tests.sps` read every diagnostic through a `codes` helper that maps `diagnostic-code`
and is blind to the `node` slot. A `nodes-of` helper, two cases, two mutations.

**The suite's bookkeeping narrative was wrong in four ways**, all measured and all now
rewritten from `git cat-file` plus a per-SPEC census: it named `c3ceec2` as the merge base
(three commits early), carried the merge-base constant as 48/255 where it is 48/**249** (255 is
this branch's own task 3, double-counted), credited ①a with a determinism mutation that is
`51fd5f3`'s, and filed a task-3 mutation "in the ir pass" when its FILE is `ir.sls` but its
**SPEC** is the verify lane — and it is the SPEC that decides which pass witnesses a mutation.

**Also fixed:** the new pass was numbered 49 where 49 was taken (header numbers run ahead of
the run count) → **Pass 50**; the `FORTY-EIGHT PASSES` banner → forty-nine; Pass 35's note said
six cases joined where eight did; the supported-IR-version pin justified itself with a
short-circuit `verify-machine` does not have (the uniqueness is empirical, from the set
difference — pass-schema is merely *first* in the append); decision **0020 item 6**'s two
premises, measured false, now carry an amendment and a foot note; the lane moved from `unit` to
**`differential`**, which is what the design's exit evidence names; `parser-reset!`'s doc block
had come to sit on `parser-field-ref`; `normal-ir.sls`'s "encode-normal … never sees names" and
"every consumer indexes BY SLOT" were both false; a §13:801 citation was carrying a claim that
line does not make; and gate 1's count was corrected **twice** — `\b` does not exclude
`normal-machine-fields` either, because `-` is a non-word character.

Totals after both waves: `release` **92/92**, `no-scheme` **8/8**, scheme mutation **49 passes /
275 mutations**, CMake **1/72**, ten declared `EXPECT_SURVIVES`, no golden moved against
`51fd5f3`.

---

## Self-Review (run after all seven tasks)

- [ ] **Every citation re-read against HEAD**, and every count carrying the qualifier that
  makes it true. This plan's numbers were measured at `51fd5f3`; the slice edits seven of the
  files it cites.
- [ ] **Every gate is a literal, a count, or "no output"** — never a description.
- [ ] **The whole-branch review, over the SEAMS**, with AGENTS.md's instruction quoted verbatim
  in the reviewer's prompt: *check what this claims the code or the spec DOES against the code
  and the spec, not against the prose.* On Slice ①a that review found a Critical eight passing
  per-task gates could not, and the triage then found three vacuous assertions and two false
  stated reasons **in the slice's own new artifacts**.
- [ ] **Annotate the design where this plan diverged from it** — §0 D1 in particular, since §6
  prescribes an `EXPECT_SURVIVES` on a premise this plan measured false. A defect fixed only in
  a plan leaves the design to mislead Slice ②.
- [ ] **The closing ritual**, which needs the owner's go-ahead before the merge.
