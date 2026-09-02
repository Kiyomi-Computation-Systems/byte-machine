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

**Created:** a field fixture under `test/support/harness/byte-machine/test/`, a unit program
for the descriptor and the accessor, and their lane pairs.

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

- [ ] **Step 1: Failing tests first.** Two `u8 count` declarations verify clean today —
  measured — and that is the defect this pass closes (**D4**).

- [ ] **Step 2:** A **new** pass (**D2**), carrying duplicate field names and portable field
  names per §10.1:480, reusing `valid-name?`. Both diagnostics carry
  `invalid-field-declaration`, with the field name in the diagnostic's `node` slot.

- [ ] **Step 3: Do NOT re-check widths or initial ranges here.** They are closed at
  construction, so a machine whose field failed construction never exists and the arm would be
  dead code whose permissive mutation survives — decision 0020's one-rejection-site rule.

- [ ] **Step 4:** Join the pass to `verify-machine`'s `append`, and re-sweep Pass 33 in both
  directions: adding a *check* widens every existing pin's collision set exactly as adding a
  mutation does. 44 pins, 1892 ordered pairs, against a control on the branch point.

---

## Task 5: Slot assignment and the field table

Design §6 task 5; §17:962; decision 0019 item 3(a).

- [ ] **Step 1: Failing test first** — two machines differing only in a field declaration must
  differ in fingerprint, and a zero-field machine must still encode a count of zero.

- [ ] **Step 2:** `normal-ir.sls`'s `only` import gains the field accessors — it currently
  cannot see fields at all, which is why `lower-machine` never has. Assign slot = declaration
  index (**D4**).

- [ ] **Step 3:** The reserved `u16be` count becomes the real count, with per-field records
  following it in the position ①a fixed. **This kills a pin by construction (H4):** re-anchor
  `SchemeMutationSuite.cmake:5042-5053` in the same commit and re-measure it.

- [ ] **Step 4: Gate.** All four fingerprints and all three goldens **unmoved** — a
  zero-field machine encodes identically. A new field-declaring fixture legitimately gets its
  own values (**D3**).

---

## Task 6: The parser's field slot, and the initials

Design §6 task 6; §12.5:738; decision 0019 item 3(b).

- [ ] **Step 1: Failing tests first**, including `parser-reset!` restoring declared initials.

- [ ] **Step 2:** A ninth parser slot beside `stored-error`. Initials reach it through the
  **shipped per-lane asymmetry**, not a uniform mechanism: `make-parser`'s `'op` arm *asks*
  the closure (a new `'field-initials` message in `interpret.sls`), and the `'v2` arm *reads*
  the ABI payload's member 0, which ①a reserved empty. `compile.sls` computes that member from
  the declarations.

  **H2:** there are **two** variant arms plus a loud unreachable else, not three.

- [ ] **Step 3:** `parser-reset!` restores the declared initials, and its comment at
  `runtime.sls:405` — "Field, span, and poisoned/busy state do not exist yet (M4/M5)" — is
  corrected in place to name what now exists and what still does not. **H5: that block ends at
  the file's last line and carries an `EXPECT_SURVIVES` pin.**

- [ ] **Step 4: Gate.** No golden moves for a zero-field machine — the emitted text is
  identical to ①a's, which is what makes 0019's reservation true rather than hoped.

---

## Task 7: `parser-field-ref`, and the lanes

Design §6 task 7; §9.3:410; §13:801.

- [ ] **Step 1: Failing tests first.** Read-only per §13:801; there is no mutating sibling to
  design.

- [ ] **Step 2:** Add the accessor, raising `byte-machine-contract-violation` with a new
  `accessor-misuse` code for an undeclared field name. Add `parser-field-ref` to
  `reserved-member-2` **by appending on a new line** — `SchemeMutationSuite.cmake:5723-5728`
  FINDs the interior of `compile.sls:51`, and a reflow takes it to 0 sites. The
  `reserved-drift` lane asserts set equality, so the export and the mirror land in one commit.

- [ ] **Step 3: Lane bookkeeping.** New source+AOT pairs, five-segment names, `TIMEOUT` on
  each, every imported library in **both** lanes' `SOURCES`. A library reached only through
  `environment` must be **statically imported** or the AOT lane alone fails.

- [ ] **Step 4: Gate — the slice's exit evidence.** Each a literal:

  1. `rg -c 'machine-fields' src/ test/` returns more than the two occurrences it returns
     today, with at least one inside the normalizer (**H6** — this gate survives §6 intact).
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
