# Milestone 0, Slice 4: Cross-library identity

Status: accepted; delivered 2026-08-17; amended after delivery (dated note below)
Date: 2026-08-17
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §7.2, §25
Milestone plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — deliverable D3, work-order item 4
Previous slice: [`milestone-0-slice-3-shared-body.md`](./milestone-0-slice-3-shared-body.md)
Scope: **one body, two libraries, one runtime at a time.** A second wrapper per runtime that imports the owner instead of re-including the body, and the identity proof that distinguishes those two. Compiled lanes are slice 5.

> Amended 2026-08-18 by [decision 0006](../decisions/0006-inline-libraries.md):
> the one-owner rule this slice enforced by mutation is retired with the
> include mechanism. The identity lane and the consumer's import-the-owner
> shape survive; the mutation that replaced an import with an include is
> unconstructible against the inline tree and was replaced by an
> inline-duplication form (0006 decision 5).

## 1. What this slice must prove

The milestone plan states D3 as: *an owner wrapper constructs a placeholder tagged value, a second
wrapper recognises it, and an allocation-free singleton retains `eq?` identity across both imports.*

Slice 3 built the owner and deliberately left this unproved — one library cannot witness a
cross-library defect. It chose the representation that makes the witness possible (T2: the tag and
the marker are freshly allocated vectors, never symbols) and said so at the tag itself. This slice
spends that choice.

Three claims, each stated so it can be disproved:

1. **Recognition crosses a library boundary.** A value constructed through the owner wrapper is
   recognised by a second wrapper that *imported* the owner rather than including the body again.
2. **The singleton keeps `eq?` identity across both imports.** The consumer's outcome value is the
   owner's object, not a lookalike that behaves the same in every test that does not compare
   identity.
3. **A shared body can name another library's exports as free identifiers,** resolved identically by
   R6RS library-body `include` and R7RS `define-library` `include`.

Claim 3 is not in D3's wording and nothing in this repository proves it today. It is included
because it is the mechanism Milestone 1 runs on: parent plan §7.2's dependency graph has `verify`
importing `graph`, which in practice means `verify.scm` calls graph procedures it does not define
and `verify.sls` supplies them through its import list. Discovering that mechanism during M1, in a
slice that also has semantics to get right, is the failure this milestone exists to prevent.

## 2. Verified environment facts

Measured 2026-08-17 (Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8) against the real Chez launcher
(`test/support/launchers/chez-source.ss`) and a copy of the shipped body
(`src/common/byte-machine/placeholder.scm`) through a copy of its shipped owner wrapper. Only the
consumer body, the consumer wrappers, and the driver program were scratch fixtures — the driver had
no harness and printed two bare booleans, so its own exit status was 0 regardless of what they said.
The exit-status figure in the mutant row below is not the driver's: it is the shipped,
harness-integrated identity lane's, confirmed separately against the exact committed files.

| Fact | Result |
| --- | --- |
| Correct tree: a consumer body's free references resolve through its wrapper's import list, both runtimes, launched from a working directory containing neither body | `recognises=#t`, `eq-marker=#t`, exit 0 on both |
| Mutant: the consumer wrapper's import **replaced by** an `include` of the owner's body | `recognises=#f`, `eq-marker=#f` on the scratch driver; the shipped, harness-integrated identity lane **exits 1** on both, via `check`/`check-equal` failures |
| Wrong mutation form — import **kept** and an `include` **added**, Chez | refused at library construction: `Exception: multiple definitions for make-placeholder and other identifiers in body` |
| Wrong mutation form — import kept and an `include` added, Gambit | **does not fail**: `consumer-tag-EQ-owner-tag=#t`, both cases pass |

Three of these are new. Two carry consequences.

### 2.1 The real mutation produces wrong answers, not an error

The second row is what makes this slice worth its files. Under the double-include mutant both
runtimes report false for both claims, and nothing raises: the shipped, harness-integrated identity
lane catches both through ordinary `check`/`check-equal` failures and exits 1, not through an
exception. That is parent plan §7.2's defect class in its exact stated form — *"interpreter and
generated execution would disagree about callback results while both looking correct in isolation"*
— and "in isolation" is literal here: the existing `byte-machine.portability.placeholder-cwd-*`
lanes still pass under this mutant, because they import only the owner. The defect is visible from
exactly one place in the tree, which is the place this slice adds.

### 2.2 The two runtimes disagree about a body that redefines an imported name

Rows three and four are a divergence, not a symmetry. Given a wrapper that both imports
`(byte-machine placeholder)` and includes that library's body, Chez refuses to construct the
library at all, and Gambit constructs it and answers every question correctly.

This document does **not** characterize Gambit's rule. The measurement establishes that the
configuration does not fail; a follow-up probe using a deliberately wrong body produced results
this design could not reconcile into a single rule within slice 4's budget, and an experiment that
shows nothing is inconclusive rather than negative. What is recorded is the measurement and its one
consequence: this form disqualifies itself as a mutation (§8.1). The rule itself is carried forward
as an open question (§11), not written down as a finding.

## 3. Decisions taken

Continuing the per-slice labelling: slice 2 used `S`, slice 3 used `T`.

| # | Decision | Rationale |
| --- | --- | --- |
| U1 | A second library per runtime, `(byte-machine placeholder-consumer)`, over its own shared body `placeholder-consumer.scm` | D3 needs a second wrapper regardless. Giving it a body is what proves claim 3, which M1 depends on and which nothing else in Milestone 0 covers. A bodiless re-exporter would satisfy D3's wording and leave that mechanism unproved. |
| U2 | The consumer models §7.2's callback-outcome rule: recognise the value, otherwise return **the owner's** singleton | Under the double-include mutation the two test cases then fail for two *different* reasons — wrong tag, and a second marker object — so neither of D3's two clauses is carried by the other. See §5.2. |
| U3 | The identity test is its own shared body with its own two lanes, at the default per-test run directory | Keeps `placeholder-tests.scm`'s stated boundary true — its header says cross-library identity is slice 4's proof and is not attempted there — and leaves slice 3's three-working-directory matrix discriminating exactly what it was built to discriminate. See §7.1. |
| U4 | §7.2's "exactly one owner per body" is enforced by mutation, not by a configure-time guard | A mutation proves the defect is *caught*; a text scan proves only that it is discouraged, and a commented-out `include` satisfies one. Slice 3 §3.1 rejected the guard and its reason has not changed. |
| U5 | The double-include mutation **replaces** the wrapper's import; it never augments it | Forced by §2 rows three and four. See §8.1. |
| U6 | Slice 4 runs on source lanes only | The milestone plan's D3 says "runs in every execution lane" but its own work order puts execution lanes at item 5; the work order governs. Slice 5 registers these same two programs against the compiled lanes at no additional design cost. |
| U7 | The deferred one-owner guard is recorded in **this** slice's decision record, with the condition that reopens it | Slice 3's deferral is recorded in a document about the include *mechanism*. Whoever adds M1's second library over an existing body will be reasoning about *ownership*, and will not look there. |

### 3.1 Rejected alternatives

- **A bodiless re-exporting wrapper.** The smallest thing satisfying D3 as literally written: two
  wrappers that import the owner and re-export it under prefixed names. The double-include mutation
  still fails it, so it is not unsound — it is merely silent about claim 3, and it leaves a `.scm`-free
  library pair in a tree whose entire organizing rule is that semantics live in shared bodies.
- **Folding the identity cases into `placeholder-tests.scm`.** No new files, and identity would ride
  slice 3's three-working-directory matrix for free. Rejected because it changes what those six lanes
  mean, falsifies that body's header comment, and adds no discrimination: the decoy directory holds
  no impostor consumer body, so four of the six lanes would witness nothing the other two do not.
  Slice 3's own rule applies — three directories that all fail the same way prove it once, not three
  times.
- **Pinning the identity lanes to the `same-name-decoy` working directory.** The most adversarial
  single choice at no extra cost, and hollow: it would need an impostor `placeholder-consumer.scm` to
  mean anything, and that impostor would witness the same bare-filename resolution the owner's body
  already witnesses. Adversarial-looking rather than adversarial.
- **A registry or fold as the consumer's shape.** More decisions to mutate and closer to a real M1
  module. Rejected as scope that buys no portability evidence, in a body decision D4 deletes in
  Milestone 1.
- **Adding the configure-time one-owner guard now.** Prevention alongside detection. Rejected under
  U4: it reopens a decision slice 3 closed with a reason that still holds, and it would fix the shape
  of a lint before M1's shape is known well enough to say what it should scan for.

## 4. Layout

Created:

```text
src/common/byte-machine/placeholder-consumer.scm     the consumer body
src/chez/byte-machine/placeholder-consumer.sls       owner wrapper, Chez
src/gambit/byte-machine/placeholder-consumer.sld     owner wrapper, Gambit
test/common/placeholder-identity-tests.scm           shared test body
test/common/placeholder-identity-tests.chez.sps      wrapper: imports both libraries
test/common/placeholder-identity-tests.gambit.scm    wrapper: imports both libraries
docs/decisions/0003-cross-library-identity.md
```

Modified: `test/CMakeLists.txt` (two lane registrations),
`test/support/cmake/SchemeMutationSuite.cmake`, and `CHANGELOG.md`.

### 4.1 The build layer does not change

No CMake module is edited by this slice, and the CMake mutation count does not move.

`src/chez` and `src/gambit` are already library roots and `src/common/byte-machine` is already a
`--source-dir`, so the three new source files are found where they land with no registration.
`byte_machine_portability_guard` already covers both directories from slice 3's T9 widening:
`src/common/byte-machine` is a `SHARED_DIR`, so `placeholder-consumer.scm` owes no program wrapper,
and `test/common` is a `WRAPPED_DIR`, so `placeholder-identity-tests.scm` owes both a `.chez.sps`
and a `.gambit.scm` or configure fails. Both new basenames are unique across the shared-body
namespace, which the guard checks.

That a slice adding two libraries, two bodies, and two lanes needs no build-layer change is evidence
about slice 3's structure, and is the reason this section exists rather than being an absence nobody
notices.

## 5. The consumer body

### 5.1 Exported surface

| Name | Meaning |
| --- | --- |
| `consume` | one value in; its carried value if the owner built it, otherwise the owner's singleton |

Nothing else. No accessor exists solely to be tested: the mutations in §8 are what discriminate, and
an exported hook that only the test calls would be a decision no mutation has to break.

Only the common R6RS/R7RS subset appears: `define`, `if`. Every other identifier in the body is free
and comes from the owning wrapper's imports, which is claim 3.

### 5.2 Why the consumer returns the owner's singleton

```scheme
(define (consume p)
  (if (placeholder? p)
      (placeholder-value p)
      (placeholder-marker)))
```

This is parent plan §7.2's rule in miniature — *"interpreted callbacks must return the runtime's own
singleton outcome values"* — and it is chosen over a thinner pass-through for a specific testing
reason.

D3 has two clauses: recognition, and singleton identity. Written this way, the double-include
mutation breaks each clause through a different mechanism. Recognition breaks because the second
library allocated its own tag, so the owner's values no longer match. Identity breaks because the
second library allocated its own marker, so the outcome is a distinct object. A test that asserted
only one of these would pass while the other was broken, and this shape makes writing that test
awkward rather than natural.

The reject branch, not the accept branch, carries the singleton. That is deliberate: it means
`(consume x)` for a non-placeholder `x` is the identity assertion, and no placeholder needs to be
constructed to make it — so the identity clause does not silently depend on the recognition clause
already working.

### 5.3 Decisions in the body, and which mutation breaks each

| Decision | Mutation | Witness |
| --- | --- | --- |
| the argument is checked at all | `(placeholder? p)` → `#f` | `(consume (make-placeholder 7))` takes the reject branch and returns the marker instead of `7`; the recognition case fails, the identity case still passes |
| the recognised branch yields the carried value | it yields `(placeholder-marker)` instead | the recognition case fails; the identity case still passes, so this is distinguishable from the next row |
| the other branch yields the **owner's** singleton | it yields a freshly allocated `(vector 'x)` | the identity case fails alone — the only mutation that reaches D3's second clause by itself |

All three witnesses are now failed comparisons, not raises. The first row originally caught its
mutation through an induced raise instead — `#t` drove `placeholder-value` onto a non-vector — until
`#f` gave it a comparison-based witness like the other two.

## 6. The wrappers

```scheme
(library (byte-machine placeholder-consumer)
  (export consume)
  (import (rnrs) (byte-machine placeholder) (only (chezscheme) include))
  (include "placeholder-consumer.scm"))
```

```scheme
(define-library (byte-machine placeholder-consumer)
  (export consume)
  (import (scheme base) (byte-machine placeholder))
  (include "../../common/byte-machine/placeholder-consumer.scm"))
```

A library form, imports, exports, and the include. Nothing else, for slice 3's reason.

The two include forms differ exactly as the owner wrappers' do — Chez resolves a bare filename
through launcher-set `source-directories`, Gambit resolves a path relative to the including file.
What is new is the second import: `(byte-machine placeholder)` in both, and it is the entire subject
of this slice. Replacing it with an include of that library's body is the defect; §8 is how the tree
finds out.

## 7. The test body and its lanes

The shared body imports nothing. Its wrappers own the imports, and each imports **both** libraries:

```scheme
(harness-case "recognition crosses a library boundary"
  (lambda ()
    (check-equal "the owner built it and the consumer read it"
                 (consume (make-placeholder 7)) 7)))

(harness-case "the singleton crosses both imports"
  (lambda ()
    (check "the consumer's outcome is the owner's object"
           (eq? (consume 7) (placeholder-marker)))))
```

`make-placeholder` and `placeholder-marker` come from the owner; `consume` comes from the consumer.
That the assertions can be written at all requires both libraries in scope, which is why this body
cannot live in `placeholder-tests.scm` without changing what that file is.

### 7.1 Lanes

```text
byte-machine.portability.placeholder-identity.chez.source
byte-machine.portability.placeholder-identity.gambit.source
```

Two lanes, at `byte_machine_add_scheme_lane`'s default per-test run directory — which is already an
isolated directory in the build tree, so the standing rule that a test never runs from the
repository holds without a `WORKING_DIRECTORY` argument.

No working-directory matrix. The consumer introduces a second include site per runtime but no new
resolution *mechanism*: Chez resolves `placeholder-consumer.scm` by bare filename through
`source-directories`, exactly as it resolves `placeholder.scm`, and Gambit resolves it relative to
the including file, exactly as before. Slice 3 proved that mechanism and its own §1 states the
principle — a second instance of a proven mechanism is not a second proof.

## 8. Mutations

Eight new Scheme mutations: three body mutations run on **each** runtime, and one wrapper mutation
per runtime.

The body mutations run on both runtimes under slice 3's T6. The claim T6 protects is that no wrapper
reimplemented the body's semantics, and a wrapper that had is precisely one whose runtime does not
notice the body changing. That claim is new again here, for a new body.

| # | Target | Mutation | Expected |
| --- | --- | --- | --- |
| B1 | `placeholder-consumer.scm`, each runtime | `(placeholder? p)` → `#f` | identity lane fails |
| B2 | `placeholder-consumer.scm`, each runtime | recognised branch yields `(placeholder-marker)` | identity lane fails |
| B3 | `placeholder-consumer.scm`, each runtime | other branch yields a fresh vector | identity lane fails |
| W1 | `placeholder-consumer.sls` | import **replaced** by `(include "placeholder.scm")` | identity lane fails, both cases |
| W2 | `placeholder-consumer.sld` | import **replaced** by the relative include of the owner's body | identity lane fails, both cases |

Export parity between the two consumer wrappers gets no dedicated mutation, under slice 3's T7: one
shared test body exercises `consume` on both runtimes, so a name missing from either wrapper fails
that runtime's lane at import. None of the eight is `EXPECT_SURVIVES`.

W1 and W2 are separate mutations rather than one. Slice 2's rule S6 ("Chez alone is enough, the text
is identical") does not reach them, because the text is *not* identical and neither is the mechanism: the two
wrappers differ in import syntax and in include path form, and §2 shows the two runtimes do not even
agree on what a body redefining an imported name means.

### 8.1 The double-include mutation must replace the import, never add to it

Forced by §2 rows three and four, and stated as its own subsection because it is the one detail of
this slice that is easy to get wrong and produces a plausible-looking result when gotten wrong.

Writing W1/W2 as "add an `include` alongside the existing import" gives, on Chez, a failure at
library construction with a message about multiple definitions — the lane fails, but for a reason
that has nothing to do with identity, which `MutationRunner`'s caught-for-the-declared-reason check
exists to reject. On Gambit the same edit does not fail at all, so the mutation would simply survive.
One mutation, two wrong outcomes, neither of them the defect under test.

Replacing the import is also the more faithful model. The defect §7.2 forbids is a library that
included a body *instead of* importing its owner — nobody writes both.

### 8.2 Counters

`EXPECTED_MUTATIONS_WITH_GAMBIT` moves from 56 to 64 and `GAMBIT_ONLY_MUTATIONS` from 7 to 11 — the
three body mutations' Gambit runs plus W2. `EXPECTED_MUTATIONS_WITHOUT_GAMBIT` is derived and needs
no edit. The CMake mutation count stays at 96 (§4.1). The implementation plan confirms these against
a real run rather than inheriting them from here.

## 9. Exit criteria

- `(consume (make-placeholder v))` returns `v` on Chez and on Gambit.
- `(eq? (consume x) (placeholder-marker))` holds for a non-placeholder `x` on both.
- All eight mutations are caught, each for its declared reason, with the suite's own totals asserted.
- The existing 38 tests still pass and the two new lanes join them, bringing the suite to 40; the
  `no-scheme` preset stays 10/10.
- A decision record in `docs/decisions/` states the measurements of §2, the U4 deferral with its
  reopening condition, and the §11 open question.

## 10. Explicitly deferred

- **Identity under compiled lanes** — slice 5. Separate instantiation is a modelled risk in source
  mode and a real one under Chez AOT, Gambit `.o1`, and `gsc -exe`. Slice 5 registers these two
  programs against those lanes; no design work is owed here beyond not making that harder.
- **A configure-time guard on "exactly one owner per body"** — U4. The condition that reopens it: a
  shared body existing with no lane registered against it, at which point a missing or duplicated
  wrapper stops being caught at import.
- **A second owner wrapper for the same body within one runtime.** The identity test catches a
  *consumer* that double-includes; it does not catch a second independent owner that nothing imports
  alongside the first. Slice 3 §3.1 declined to guard this and this slice does not revisit it.

## 11. Open questions carried forward

**What does Gambit do when a `define-library` body defines a name the library also imports?** §2 row
four measures that it does not fail, and §2.2 states why this document does not go further. Chez
refuses the same construction outright. M1 will build several libraries over several bodies with real
import graphs, and a runtime that silently accepts a name collision the other rejects is a portability
hazard with no diagnostic. It needs its own measurement, and it is cheap to run — it is deferred
because it is not on D3's path, not because it is unimportant.
