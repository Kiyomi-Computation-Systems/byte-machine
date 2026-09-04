# Milestone 5 — Slice ①a (the seam) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every committed artifact **once**, before any Milestone 5 semantics exist, so that each later slice can assert "no fingerprint moved" as a *gate* rather than a hope. Decision `0025` made real, plus the position-axis drift row `0025` point 4 hands over without settling.

**Architecture:** Six tasks over `compile.sls`, `runtime.sls`, `private/normal-ir.sls`, four committed goldens, five test files and the mutation suite. **Corrected during execution 2026-09-04: Tasks 1-3 are ONE atomic change and ship in one or two commits, not three.** The goldens are regenerated once, and until the ABI literal and the `exec` signature move together the differential lanes fail loading a version-3 library into a version-4 runtime. As first written, Task 1 said the tree is "deliberately inconsistent" until Task 3 while Task 2 required "the full suite green" — both cannot hold, and the standing rule that tests pass before every commit means the plan, not the rule, was wrong. **No node kind, no callback behaviour, no verifier pass.** The slice's own boundary is checkable and Task 6 checks it: `node?`'s disjunct list must still be nine when the slice ends.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS), CMake/CTest, the in-repo mutation suite.

## Global Constraints

- **Authority order.** `docs/decisions/0025-milestone-5-seam-encoding-abi-exec.md` is authoritative; `docs/plans/milestone-5-design.md` §5 is its source; this plan is a work order derived from both. **Where this plan and `0025` differ, re-read `0025` and reconcile before writing code.** Where `0025` is *wrong*, stop and say so — three arguments in this milestone's design were refuted during Gate 0 and the records were rewritten rather than the errors encoded.
- **Every citation below was measured 2026-09-04 at `79c18c7`** (main, after Gate 0 merged). Line numbers move as the tasks run: **re-measure before each edit** and cite the construct, not only the line. No tool in this repository catches a stale citation.
- **FOUR MUTATIONS DIE AT CMAKE CONFIGURE TIME UNDER THIS SLICE'S EDITS, AND THEY FAIL LOUDLY IN A WAY THAT DOES NOT LOOK LIKE A TEST FAILURE.** The message is `byte-machine-mutation: '<label>': pattern occurs 0 times in <file>, expected 1` (`MutationRunner.cmake:98-100`). **Measured: `SchemeMutationSuite.cmake` passes `SITES` to zero mutations**, so every `FIND` is asserted at exactly one occurrence in *both* directions — a `FIND` that dies *and* a `FIND` that gains a twin both fail. Each affected mutation is named in the task that breaks it and **must be re-anchored in that task's own commit.**
- **Do not run `git checkout --` to undo a hand-applied mutation.** It wipes the task's own unstaged work. Stage first.
- **Re-run the whole mutation suite after any edit to an exit path or an emitted string**, not just the lane you touched.
- **The goldens are read from the source tree, not the stage.** Measured: `BYTE_MACHINE_MUTATION_STAGE_DIRS` (`SchemeMutationSuite.cmake:1183-1185`) is `cmake`, `test/support/cmake`, `test/support/harness`, `test/support/launchers`, `src`, `test/common` — **`test/fixtures` is absent.** So a golden re-baseline takes effect for the mutation suite immediately, with no staging change.
- **A new pass goes strictly after the previous pass's `_run` and before the next comment block.** `byte_machine_mutation_reset()` is the only thing that clears the accumulated count (`MutationRunner.cmake:241-259`) and `byte_machine_mutation_run` never does, so a `reset()` placed before the previous pass's `run()` silently steals that pass's declarations. This slice adds **no new pass** (see Task 6).
- **Comments that become false are corrected in place**, records are annotated. Three comment blocks in this slice describe a one-member payload and go false the moment member 1 lands; each is named in its task.

## File Structure

**Modified — source:**

| File | Change | Task |
| --- | --- | --- |
| `src/byte-machine/runtime.sls` | `current-abi-version` 3→4 (`:61`) and its comment | 1 |
| `src/byte-machine/compile.sls` | emitted `exec` gains two parameters (`:532`); `reserved-member-3` gains their names (`:68-70`) and its comment is corrected | 2 |
| `src/byte-machine/compile.sls` | emitted ABI literal 3→4 and the payload's second member (`:550-551`); the member-0 comment block (`:504-517`) corrected | 3 |
| `src/byte-machine/private/normal-ir.sls` | the optional trailing slot-table section, and the header comment (`:465-467`) | 4 |

**Modified — tests and fixtures:**

| File | Change | Task |
| --- | --- | --- |
| `test/common/runtime-tests.sps:306-315` | the version-refusal group re-numbered 2→3 and 3→4 | 1 |
| `test/common/member3-drift-tests.sps:148-150` | the per-name list and its `"six checked"` sentinel become eight | 2 |
| `test/fixtures/generated-{one-byte,pause,accumulate,http-version}.golden.sls` | `:5` (exec signature) in Task 2; the constructor line (`:21`, `:34`, `:36`, `:86`) in Task 3 | 2, 3 |
| `test/common/compile-tests.sps`, `determinism-one-byte-tests.sps`, `field-access-tests.sps` | the metadata-vector literal, pinned outside `test/fixtures/` | 3 |
| `test/common/kind-position-census-tests.sps` | the position-axis drift row | 5 |
| `test/support/cmake/SchemeMutationSuite.cmake` | four re-anchors, the running-total ledger, `EXPECTED_MUTATIONS` | 2, 3, 6 |

**Deliberately untouched.** `src/byte-machine/private/ir.sls` — this slice adds no node kind, and Task 6 asserts it. `src/byte-machine/verify.sls`, `interpret.sls`, `graph.sls`. `README.org` and `CHANGELOG.md` — status surfaces move when the *milestone* closes.

---

## Task 1: `current-abi-version` 3→4, and the coverage `0025` point 2 owes

**Files:** `src/byte-machine/runtime.sls` (`:55-61`); `test/common/runtime-tests.sps` (`:306-315`).

**Mutations broken: none.** Measured across all 366 declarations: no `FIND` contains the `current-abi-version` line, and the two mutations that quote the version *guard* (`SchemeMutationSuite.cmake` L2825's `(unless #t`, L3477's guard reordering) do not quote the literal `3`. The `>= 1` length check at `runtime.sls:84` has no mutation anywhere in the tree.

- [ ] **Step 1: Bump the constant and correct its comment**

`runtime.sls:61` becomes `(define current-abi-version 4)`. The comment above it reads "Bumped to 3 by Milestone 4 Slice ①a" — **that is a record and it stays**; append the Milestone 5 bump rather than rewriting it, so the file keeps both dates.

- [ ] **Step 2: Re-number the version-refusal coverage**

`test/common/runtime-tests.sps:306-315`, the group "the unversioned constructor checks the version first", already has the shape `0025` point 2 asks for: a refused superseded version and an accepted current one. It needs re-numbering only — `2`→`3` and `3`→`4`, in both the literals and the case labels.

**Say in the commit what this is.** `0025` point 2 is explicit: the strict equality at `runtime.sls:79` already enforces the bump, and the `>= 1` at `:84` is the *metadata length* check enforcing nothing about the version. This step is **coverage of a working guard**, not the closing of a hole. A claim made during the design's research said otherwise and `0025` records why it was wrong.

- [ ] **Step 3: Verify**

```bash
rg -n "current-abi-version" src/byte-machine/runtime.sls
ctest --test-dir build/dev -R "byte-machine.unit.runtime" --output-on-failure
```
Expected: `:61` is 4 and `:79` compares against it; the runtime lane green. **The full suite is NOT green until Task 3 completes** — see the Architecture note. Do not commit here unless Tasks 2 and 3 land in the same commit.

**And `runtime-tests.sps:306-315` is not the only place that hard-codes a version.** Measured during execution: four more sites in the same file carry a literal `3`, two of them (`:258`, `:260`) the shared stub compiled machines every `/v2` group builds on, which is why one missed constant surfaces as eleven unrelated-looking failures. Use `rg -n "byte-machine-make-compiled-machine\s+3\b"`, which finds all of them.

- [ ] **Step 4: Commit**

---

## Task 2: Emitted `exec` gains two reserved parameters

**Files:** `src/byte-machine/compile.sls` (`:532`, `:62-70`); `test/common/member3-drift-tests.sps` (`:148-150`); the four goldens (`:5` each); `SchemeMutationSuite.cmake` (three re-anchors).

**Interfaces.** Produces the parameters a callback invocation will need — `§13:784` makes the parser a callback's first argument and generated execution happens inside `exec` (`runtime.sls:381` and `:428` are its only callers). Both are **reserved and unused** here; Slice ② fills them.

- [ ] **Step 1: Widen the template and register the names**

`compile.sls:532` is the **only** place the parameter list is written:

```scheme
        "  (define (exec state offset bv start end finish? fieldv)\n"
```

**Measured absence, and it is a finding worth keeping:** no mutation anywhere in the suite anchors on this line — searched all 366 `FIND`/`REPLACE` bodies for `exec state offset`, `(define (exec` and `bv start end finish?`, zero hits outside `reserved-member-3`'s list. **The emitted `exec` signature is unwitnessed by the mutation suite.** Not this slice's to fix, but Task 6 records it.

**Two further sites, found during execution because the build failed and no search had named them.** `test/common/compile-tests.sps:206-212` asserts the signature verbatim — it is the *only* witness to that line anywhere, which is what the absence above makes it. And `test/common/runtime-tests.sps:232`'s `stub-exec` stands in for generated code, so **its arity tracks the emitted one and nothing asserts that**: the mismatch appears as `incorrect number of arguments 9` from every `/v2` group at once. Widen both.

Both new names join `reserved-member-3` (`compile.sls:68-70`, 18 symbols today). Its comment describes `fieldv` as "reserved empty here and filled in Slice ②" — **that happened in Milestone 4**; correct it in place and name the two new reservations and their filling slice.

- [ ] **Step 2: Re-anchor the three mutations this breaks — in this commit**

| Where | Label | Why it dies |
| --- | --- | --- |
| `SchemeMutationSuite.cmake:8439-8452` | "compile: an emitted local is missing from reserved-member-3" | `FIND` is the whole two-line list, verbatim |
| `:8454-8465` | "compile: reserved-member-3 loses the accumulate arm's digit local" | `FIND` is `      v r d))` — the `))` closes the list and the define |
| `:3019-3031` | "runtime: a /v2 finish does not drive exec with finish? true" | its second `FIND` line is `exec`'s argument-list continuation at `runtime.sls:428-429` |

The two `reserved-member-3` `FIND`s **must stay textually distinct and each stay at exactly one occurrence** — whatever list layout you choose, check both after editing. Measured: the feed call site (`runtime.sls:381-382`) carries no mutation, so only the finish site's pin moves.

- [ ] **Step 3: Update the drift guard's own sentinel**

`test/common/member3-drift-tests.sps:148-150` enumerates `'(fieldv errs pk v r d)` and asserts `(check-equal "six checked" n 6)`. That is a per-name list, deliberately not a count — its comment records that Slice ③ found it stale. Two new parameters make it **eight**; update the list, the `n` sentinel and the `"all six emitted"` label together.

- [ ] **Step 4: Re-baseline the goldens' signature line**

`:5` in all four is `  (define (exec state offset bv start end finish? fieldv)`. **Only that line moves in this task.** The constructor line is Task 3's.

- [ ] **Step 5: Verify**

```bash
rg -c "SITES" test/support/cmake/SchemeMutationSuite.cmake
cmake --build build/dev && ctest --test-dir build/dev --output-on-failure
git diff --stat -- test/fixtures/
```
Expected: the mutation suite **configures** (the three re-anchors hold); the full suite green; and `test/fixtures/` shows exactly four files changed, **one line each**. More than one line per file means Task 3's work leaked in.

- [ ] **Step 6: Commit**

---

## Task 3: The ABI literal and the payload's second member

**Files:** `src/byte-machine/compile.sls` (`:549-551`, `:504-517`); the four goldens; three test files pinning the metadata literal; `SchemeMutationSuite.cmake` (one re-anchor).

- [ ] **Step 1: Decide the member-1 shape, and say which you chose**

The render tail is `compile.sls:549-551`:

```scheme
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine 3 " (number->string fp) " "
        (number->string entry) " exec (quote #(#(" fields "))))))\n"))))
```

The literal `3` becomes `4`. **It is a literal, not a reference** — `current-abi-version` appears nowhere in `compile.sls`, which does not import `(byte-machine runtime)` at all, so the constant is not in scope. Verified at `79c18c7`.

Member 1 is empty for every machine in this slice, and there are two shapes. **Prefer (a):** render a bare `#()` into the tail, exactly as Milestone 4 ①a did for member 0. **(b)** would add a `cbs`-style accumulator seeded to `""` so that ①b fills a body rather than converting a literal — but it can read nothing yet (there is no `normal-machine-callbacks`), so it buys only the churn it claims to avoid. Whichever you choose, **write the reason in the commit**, because the next slice will read it as precedent.

- [ ] **Step 2: Correct the member-0 comment block**

`compile.sls:504-517` says a second member "would be a second ABI growth for data the first already carries" and that "the payload `#(#())`". The first is an argument *about field data* that a reader arriving after this slice will read as a prohibition on exactly what this slice does; the second is simply wrong post-slice. Correct both in place, name member 1, say it is empty here and which slice fills it.

- [ ] **Step 3: Re-anchor the render-tail mutation — and end its churn**

`SchemeMutationSuite.cmake:6784-6802` FINDs `" exec (quote #(#(" fields "))))))\n"))))` — `compile.sls:551` character for character. **Its own comment records two prior re-anchors and predicts this one:** *"the tail is where every payload change lands, and any pin anchored there will keep moving."* This slice is the third.

**Re-anchor it onto `compile.sls:528`** — `"(library (generated " mname ")\n"` — a line no payload change touches. The mutation's decision is "no carriage return byte appears and the last byte is LF", and a CRLF injected at the library line satisfies it for every machine, including a zero-field one. Keep `REPLACE` and `EXPECT_OUTPUT_MATCHES` unchanged; **update the comment to say the churn was ended deliberately and why**, so the next slice does not move it back.

- [ ] **Step 4: Re-baseline every pinned site — there are more than the design named**

The constructor line in the four goldens (`:21`, `:34`, `:36`, `:86`). **And three test files pin the metadata literal outside `test/fixtures/`:** `test/common/compile-tests.sps`, `test/common/determinism-one-byte-tests.sps`, and `test/common/field-access-tests.sps:399` (which quotes a *full* payload including field pairs, and is the one nobody looks in). Find them all:

```bash
rg -n "quote #\(#\(" test/ --glob '!test/fixtures/*'
```
Expected: every hit accounted for before you build. A missed one fails as a golden mismatch naming a file you did not expect.

**That search is necessary and not sufficient**, measured during execution: `compile-tests.sps:205` and `field-access-tests.sps:399` pin payload text carrying *field pairs*, so neither matches a `#(#())` pattern. Search for `(quote #(#(` as above **and** read every hit's full string, including the ones whose member 0 is non-empty.

- [ ] **Step 5: Verify — the forward oracle, and the half that can fail**

```bash
git diff -- test/fixtures/ | rg "^[+-].*make-compiled-machine"
rg -n "14095574568398596535|17903327606435836645|15997144668070819532|16999772257989587335" test/
```
Expected: the constructor line moved in all four, and **every fingerprint literal is unchanged** — `14095574568398596535` (one-byte), `17903327606435836645` (pause), `15997144668070819532` (accumulate), `16999772257989587335` (http-version). **That is the assertion.** The encoding has not been touched yet, so a moved fingerprint here means something reached the normalizer that should not have.

- [ ] **Step 6: Commit**

---

## Task 4: Record the trailing-section shape — the CODE moves to Slice ①b

> **Corrected during execution, 2026-09-04.** This task as first written landed the section in
> ①a. It should not, and decision `0025` carries a dated note saying so. **The seam argument is
> that a change moving a committed artifact is paid once — and this one moves no artifact,
> ever.** A section writing zero bytes for a machine declaring neither leaves the stream, and so
> the fingerprint, identical whether the code exists or not; adding it in ①b costs exactly what
> adding it in ①a costs. That is the whole difference between a trailing section and the header
> slot 0019 had to reserve a slice ahead. Landing it here would have meant a guard over two
> always-empty lists — live code no input can reach, in the milestone that opened with two
> slices about exactly that.
>
> **What ①a owes is the shape, written down before anything depends on it**, and the steps below
> are kept because their traps are what ①b must not walk into.

## Task 4 (as executed): the shape recorded at `encode-normal`'s head

**Files:** `src/byte-machine/private/normal-ir.sls` (`:462-490`, `:546-548`).

- [ ] **Step 1: Read the trap before writing a byte**

`0025` point 1 requires a machine with no callbacks and no spans to encode **byte-identically to today**. Measured: `encode-normal` ends at the state loop (`:546-548` closes the loop, the `let`, the lambda and `call-with-bytevector-output-port`); nothing follows it; there is no terminator, no padding and no length prefix; and `fnv1a-64` folds over every byte.

**Therefore byte-identity holds if and only if the new code writes ZERO bytes for such a machine.** An unconditional `(put-u16be p (length callbacks))` appends 2 bytes to every machine; a `(put-u8 p 0)` "no sections" marker appends 1. Either moves all four golden fingerprints and every pinned site, and fails `0025`'s own backward oracle. **The count lives inside the guard, not before it.**

**And this is not the field-table precedent, so do not reason from it.** Decision 0019 item 3(a) reached byte-identity by writing an unconditional count that *already existed* with value 0, reserved a slice earlier and paid for by a format-version bump in the same commit. Nothing is reserved here. `0025` point 1 calls restating the bargain "consistent, not novel" — the *bargain* is; the *mechanism* is the opposite one, and this plan says so because an implementer copying 0019's shape will write an unconditional count and move every fingerprint.

- [ ] **Step 2: Do not write a bare `(put-u8 p 4)`, or any bare tag 3-7**

`SchemeMutationSuite.cmake:6367-6373` has the bare 12-character `FIND [[(put-u8 p 4)]]` with `SITES` defaulted to 1. Measured tag census in `normal-ir.sls`: tag 0 → 4 sites, 1 → 4, 2 → 2, 3 → 1, 4 → 1, 5 → 1, 6 → 1, 7 → 1, 8 → 0. **A second `(put-u8 p 4)` anywhere in the file fails the suite at declaration** with "pattern occurs 2 times, expected 1". Use tag 8 or higher, or write no bare literal tag at all.

- [ ] **Step 3: Land the section, and leave the header alone**

The four header writes at `:482-485` are unguarded — every machine gets them — and `0025` point 1 forbids changing them. **Six mutations anchor inside `:482-490` and all six must survive byte for byte.** Update the header comment at `:465-467` to describe the trailing section.

- [ ] **Step 4: Verify — this is the task whose oracle is a non-event**

```bash
cmake --build build/dev && ctest --test-dir build/dev --output-on-failure
rg -n "14095574568398596535" test/common/normal-ir-tests.sps
```
Expected: **every fingerprint unchanged, all four goldens unchanged by this task**, and `test/common/normal-ir-tests.sps:223-226` — "filling the reservation does not move a zero-field fingerprint" — still green. `git diff -- test/fixtures/` for *this task alone* must be **empty**. A single moved byte means the section is not fully guarded.

- [ ] **Step 5: Commit**

---

## Task 5: The position-axis drift row — and a correction to what `0025` point 4 asks for

- [ ] **Step 1: Read this before starting; the instruction as written is not executable**

`0025` point 4 and design `§5:641-646` both say to derive `position-table`'s names "from the IR the way `kind-predicates-in-source` derives the kinds". **Measured: `src/byte-machine/private/ir.sls` has no position vocabulary at all** — `rg -n 'position' src/byte-machine/private/ir.sls` returns two comment lines about the field schema. There is nothing to derive from.

The only enumeration with the right cardinality is in **`verify.sls`** — the file the census exists to test. **That asymmetry is the whole point of the kind axis and it does not transfer:** the kind row derives from `ir.sls` and tests `verify.sls`, two independent files, so a mutation to one is caught by the other. A position row deriving from `verify.sls` tests `verify.sls` against itself.

**And the census reads the mutated tree.** `SchemeMutationSuite.cmake:1150` is `set(ENV{BYTE_MACHINE_SOURCE_ROOT} "${STAGE_DIR}/src")`, so a mutation that deletes an arm deletes it from the code *and* from the derived set: the mutant is self-consistent and the row stays green.

- [ ] **Step 2: Build the row anyway, and label exactly what it buys**

**Resolution: derive from `verify.sls`, and say in the test's own comment that this row is structurally weaker than the kind row and why.** It catches what it is for — a hand-edit that adds an edge position to the verifier without adding a matrix cell, which is the Milestone 4 defect shape one level up, and today **nothing** checks `position-table` (`:93`) at all. It does **not** catch a mutation, and the comment must say so rather than let a later reader assume the two axes are equally strong.

If a mutation is wanted as a witness, it must mutate `position-table` *in the test*, not the verifier — and the suite's staging list does include `test/common`, so that works.

- [ ] **Step 3: Verify**

```bash
ctest --test-dir build/dev -R "kind-position" --output-on-failure
```
Plus the row's own sentinel: assert the **observed** count of derived positions, never a count computed from the table under test.

- [ ] **Step 4: Commit**

---

## Task 6: Totals, the ledger, and the slice's own boundary

- [ ] **Step 1: Update the mutation totals and the running ledger**

`EXPECTED_PASSES 52` / `EXPECTED_MUTATIONS 376` at `SchemeMutationSuite.cmake:1004-1005`. **This slice adds no new pass**; if the mutation count moved, the totals move in the same commit or the whole 70-second run `FATAL_ERROR`s at `:9409`.

The reverse-chronological ledger's current top is `:840-842`. Insert this slice's paragraph immediately **above** `:840`, in the same style: name the slice, say what each mutation covers, and close with the arithmetic.

**If — and only if — `EXPECTED_PASSES` moves**, three prose sites go stale and nothing checks any of them: the banner at `:9`, the narrative at `:10-22`, and the phrase at `:9404`. The file's own header records a previous slice *claiming* to have corrected that banner and not having done so.

- [ ] **Step 2: Assert the slice's boundary**

```bash
ctest --test-dir build/dev -R "kind-position" --output-on-failure
git diff --stat main..HEAD -- src/byte-machine/private/ir.sls src/byte-machine/verify.sls src/byte-machine/interpret.sls
```
Expected: `kind-position-census-tests.sps:326`'s "the same nine kinds" green — **that is what proves this slice added no node kind** — and the second command prints **nothing**.

- [ ] **Step 3: Whole-slice verification**

```bash
make test
git diff --stat main..HEAD -- test/fixtures/
rg -n "14095574568398596535|17903327606435836645|15997144668070819532|16999772257989587335" test/ | wc -l
```
Expected: 98/98 and the mutation suite at its new declared totals; four goldens changed, **two lines each and no more**; every fingerprint literal still present and unchanged.

- [ ] **Step 4: Close the unwitnessed signature — corrected during execution**

Task 2 measured that **no mutation anywhere anchors on the emitted `exec` parameter list.** This step as first written deferred a pin to Slice ②, "because a pin belongs with the slice that gives the parameters meaning".

**That was wrong and the gap is closed here.** `AGENTS.md`: a guard shown not to guard gets closed, not documented. And the witness already exists — Task 2 added `compile-tests.sps`'s "exec carries its three reserved parameters", which the same measurement makes *the only assertion over that line in the tree*. The mutation drops the last reserved parameter, so it is caught by a failed comparison in that assertion rather than by a raise from a later arity mismatch.

- [ ] **Step 5: Commit**

---

## Verification

The slice's oracle is two-sided and **the two sides fail for different reasons**, which is why neither alone is enough.

**Forward — the goldens move, exactly once, by a diff stated in advance.** Two lines per file, four files: `:5`'s `exec` signature, and the constructor line's `3`→`4` plus its second member. Nothing else in `test/fixtures/`. An earlier draft of the design asserted an *empty* `git diff -- test/fixtures/` here and was wrong — the goldens are emitted **text**, and `0025` point 1's byte-identity is a claim about the *encoding*.

**Backward — every fingerprint is unchanged.** That is the assertion `0025` point 1 actually buys, and unlike an empty diff it can fail: a moved fingerprint means the trailing section wrote a byte it should not have, and it fails loudly through 25 mutations in the normal-ir pass whose `EXPECT_OUTPUT_MATCHES` quote fingerprint values directly.

**And the boundary is checkable rather than asserted:** `node?`'s disjunct list is still nine, so `kind-position-census-tests.sps:326` stays green. A seam slice that accidentally added a node kind would fail there.
