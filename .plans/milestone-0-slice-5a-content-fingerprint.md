# Milestone 0, Slice 5a: Content fingerprint and lane provenance

Status: accepted; delivered 2026-08-17; amended after delivery (dated note below)
Date: 2026-08-17
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §22.2, §24.2
Milestone plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — deliverable D5, work-order item 5
Previous slice: [`milestone-0-slice-4-cross-library-identity.md`](./milestone-0-slice-4-cross-library-identity.md)
Scope: **the provenance instrument, on the source lanes that already exist.** No compiled lane. Chez
AOT is slice 5b; Gambit `.o1` and `-exe -nopreload` are slice 5c.

> **Amended 2026-08-18 by [decision 0005](../.decisions/0005-chez-only.md): Gambit
> and R7RS leave the project contract.** This document is a record and keeps all
> of its Gambit content — it was true when taken, and a record edited to agree
> with a later decision stops being evidence of anything. What changed *after*
> it: **§6.1's cross-runtime carrier is gone.** Claim 2 ("Chez and Gambit report
> the same string for the same bodies") had its cross-runtime half retired by
> decision 0005, and nothing replaces it; a two-lane agreement between
> `chez.source` and `chez.aot` is the weaker statement slice 5b owns under its
> own name. The **scope line above's Gambit `.o1` and `-exe -nopreload`
> references describe cancelled slice 5c.** Everything else here stands as run:
> the instrument, claims 1 and 3, and the algorithm and its mutations are
> Chez-internal and unchanged. `test/support/launchers/fingerprint-manifest.ss`
> still points readers at §6.1 for what a single-runtime comparison does and does
> not prove; that pointer is accurate for the surviving half of the claim. See
> [chez-only-simplification.md](./chez-only-simplification.md).

## 1. What this slice must prove

The milestone plan states work-order item 5 as: *all four lanes green over the same shared body,
agreeing on a content fingerprint.* Three earlier slices wrote IOUs against it. Slice 2 §11 deferred
content fingerprinting, `adapter-file-bytes`, and the production of exit status 3 here; slice 2 §7.3
required that "slice 5 must supply the equivalent guarantee for each compiled lane it adds"; slice 4
§10 deferred cross-library identity under compiled lanes here.

This slice takes the first of those and leaves the lanes themselves to 5b and 5c. The reason is
ordering, not appetite. The fingerprint is the instrument the compiled lanes are measured with, and
an instrument that has never been shown to fail is not evidence. Built now, while only source lanes
exist, it can be proved falsifiable on its own terms and cheaply; built alongside three compiled
lanes, its first failure would be indistinguishable from theirs.

Three claims, each stated so it can be disproved:

1. **A lane reports the combined content fingerprint of the shared bodies it ran, and that value
   matches what the build computed** from the repository sources before the run.
2. **Chez and Gambit report the same string for the same bodies.** This is D5's "agreeing on a
   content fingerprint" in the only form available before a second execution mode exists, and it is
   the claim the hex-rendering decision in §5.2 exists to protect.
3. **The check can fail.** A lane given a deliberately wrong expectation exits **3** — a status
   nothing else in this tree can produce, which is why slice 2's decision S3 reserved it rather than
   folding provenance into 2.

Claim 3 is the slice's central failing test, in the position `byte-machine.harness.failing-body`
held in slice 2. Claims 1 and 2 are worth nothing until it holds: protium recorded two occasions
where two of its lanes printed different digests for text both claimed to have run and the suite
stayed green, because nothing read the values back.

## 2. Verified environment facts

Measured 2026-08-17 (Darwin 25.5.0 arm64, Chez 10.4.1 at `/opt/homebrew/bin/chez`, Gambit 4.9.8 at
`/opt/homebrew/opt/gambit-scheme/bin/gsi`) against a scratch prototype of §5's algorithm and the
three real shared bodies now in the tree. The prototype used the two `adapter-file-bytes` bodies of
§5.1 verbatim; only the driver was scratch.

| Fact | Chez | Gambit |
| --- | --- | --- |
| `(number->string 255 16)` | `FF` | `ff` |
| `(number->string 3735928559 16)` | `DEADBEEF` | `deadbeef` |
| fingerprint of `harness-runner.scm` | `d1909491964077b` | `d1909491964077b` |
| fingerprint of `placeholder.scm` | `1667beb2a1c784b9` | `1667beb2a1c784b9` |
| fingerprint of `placeholder-consumer.scm` | `f6a5d9af9aaf173` | `f6a5d9af9aaf173` |
| combined over those three, in that order | `101cc6beb745d034` | `101cc6beb745d034` |

### 2.0 What these numbers are measured against, and which of them expire

AGENTS.md requires that a measurement earn its place in a design document only once it has been
re-taken against the shipped artifact. These have not been, and two kinds of row must be
distinguished before they are used.

The first two rows are properties of the runtimes and are stable: nothing this slice ships can
change what `number->string` does with a radix.

The last four are fingerprints of files, and **three of those files include `harness-runner.scm`,
which this slice edits.** The per-file value for that body and the combined value over the three
bodies are therefore *pre-slice* readings. They are recorded to establish that the two runtimes agree
— which is the claim — and not as values anything may later assert against. Any lane, test, or
decision record that needs a combined fingerprint must take it from the shipped artifact at the time
it is written. The implementation plan's Task 3 and Task 8 both say so at the step.

The prototype was a scratch driver over the two `adapter-file-bytes` bodies of §5.1 and the algorithm
of §5.2, verbatim; no harness, no adapter library, no launcher. That is a weaker fixture than the
shipped lane, and slice 4's cost for treating a scratch reading as a shipped one is exactly why this
subsection exists.

Two consequences, and they pull in the same direction.

### 2.1 The radix divergence is real here, not inherited

Protium recorded that Chez and Gambit disagree about the case of the digits `number->string`
produces with a radix. The first two rows measure it on this machine, on the exact binaries
discovery registers. Neither standard fixes the case, so both are conforming.

The whole point of the fingerprint is that both runtimes print the same string for the same text.
Rendering it through `number->string` would make the one claim this slice exists to establish depend
on an unspecified detail that these two runtimes are already known to answer differently. Comparing
case-insensitively later would be worse: it would hide exactly the class of divergence this file
exists to expose. Hence the explicit digit table in §5.2 — the decision is forced by the first two
rows, not a stylistic preference.

### 2.2 Exact integer arithmetic carries the algorithm on both runtimes

Rows three to six are the claim-2 measurement, and they also settle the arithmetic question. The
modulus is 2⁶¹−1, so intermediate products exceed 64 bits and the fold depends on exact bignums.
Both runtimes agree to the digit, from `open-file-input-port` on one side and
`open-binary-input-file` on the other.

This is why the algorithm is arithmetic rather than bitwise. Neither R6RS base nor R7RS small
guarantees bitwise operations; both guarantee exact integer arithmetic of unbounded range. The Chez
adapter already exports `modulo`, `quotient`, and `remainder` — R6RS keeps them outside `(rnrs)` and
slice 2 pulled them in from `(rnrs r5rs)` for the shared subset — so the operators the fold needs
are already in the portable vocabulary and no export list grows for arithmetic's sake.

Note that the rendering drops leading zeros, so fingerprint strings vary in length
(`d1909491964077b` is fifteen digits, `1667beb2a1c784b9` sixteen). That is harmless for the equality
comparison this slice performs and is recorded so a later reader does not mistake a short value for
a truncated one.

## 3. Decisions taken

Continuing the per-slice labelling: slice 2 used `S`, slice 3 used `T`, slice 4 used `U`.

| # | Decision | Rationale |
| --- | --- | --- |
| V1 | D5 is split: 5a is the fingerprint and provenance instrument on the existing source lanes, 5b is Chez AOT, 5c is the two Gambit compiled modes | The instrument measures the lanes. Proving it falsifiable while nothing depends on it is cheap; proving it alongside three new lanes means its first failure is confounded with theirs. Protium's equivalent machinery is roughly 1550 lines of CMake plus three launchers against this repository's current 215-line lane module, so one slice would also be three to four times slice 2, the largest so far. |
| V2 | The manifest covers **shared bodies only**, not wrappers or entry programs | D5's own wording is "agreeing on a content fingerprint", and agreement is only meaningful over text both runtimes execute. Wrappers are per-runtime by definition, so including them would replace the agreement claim with "each lane matches its own expectation". Their coverage is not lost: slice 4's W1/W2 mutate them and the portability guard checks the wrapper pair. |
| V3 | The manifest is declared per-lane, not derived or global | 5b and 5c need lanes to fingerprint *staged copies* rather than repository originals — a compiled lane's whole question is whether the artifact matches the text it was built from. A single global manifest cannot express that, and would also report on files the lane never loaded. |
| V4 | The comparison happens in-process; a mismatch exits 3 | `test/CMakeLists.txt` already records that this tree's registration layer asserts exit status, not output. Comparing in the build layer would need an output-reading mechanism that does not exist and that the verbose lane's comment explains the absence of. |
| V5 | The expectation is a **build output file** whose path arrives in the environment, not a value baked into the environment at configure time | A registration's environment is fixed when CMake configures. The expectation must be recomputed whenever a body changes, which is precisely the case it exists to catch. |
| V6 | The build-time expectation is computed by `load`ing `fingerprint.scm`, never by reimplementing it | A second implementation agreeing with the first is the kind of proof that proves nothing: the two would drift, and the drift would look like a passing comparison. |
| V7 | A provenance failure ends the run immediately, before any case runs | Protium measured why recording-and-continuing is insufficient: a body that then hangs satisfies its timeout expectation whether or not an error was recorded first. Beyond that, a run that cannot show it is executing the intended text says nothing meaningful afterwards. |
| V8 | A manifest body that cannot be read is a provenance failure, not an escaping I/O condition | Otherwise the raise leaves the runner and takes the process out through a status outside slice 2 §5.2's four-value vocabulary, with no summary line and a message about a file handle. `ByteMachineExpectExit.cmake` would then report an out-of-vocabulary observed status, which is a true statement about the wrong thing. |
| V9 | `SHARED_BODIES` is **required** by `byte_machine_add_scheme_lane`, the way `TIMEOUT` already is, and this configure-time requirement is the *whole* of the guarantee | The property worth having is not "the lanes have provenance" but "a lane cannot be added without it". That matters little in 5a, where every lane is a source lane, and a great deal in 5b and 5c, where a lane registered without provenance is exactly the lane that can silently fall back to source. A required argument is unforgeable at configure time, which is why V13 can drop the run-time half without losing anything. |
| V13 | An **unset or empty** `BYTE_MACHINE_FINGERPRINT_FILES` means "not a registered lane" and provenance is skipped, not refused | Refusing was the first design and it is unimplementable: `byte_machine_mutation_run` requires every spec to pass unmutated on the staged tree, and `byte_machine_mutation_run_spec` runs verify commands through `execute_process` with no environment. Under a refusal, all 27 existing mutation passes fail their baseline before running a single mutation. The alternatives were worse — an opt-out variable is a hole anyone can set in CI, and giving the suite a real manifest makes every body mutation exit 3 on provenance instead of 1 on its own assertion, breaking pass 22's declared `EXPECT_STATUS 1` and silently converting passes 9, 10 and 21 to 25 into fingerprint checks. Nothing is lost: V9's requirement already makes an unprovenanced registered lane impossible one layer up. See §6.2. |
| V10 | `\|` joins the manifest path list in the environment | A path list needs a separator, and the portable one is the open question the spike left at §9 item 3 (`:` on Unix, `;` on Windows). `\|` is illegal in a Windows path and rare enough elsewhere to be safe, and `harness-split` already exists in the runner from slice 2. |
| V11 | The provenance check is its own exported procedure called from `harness-begin`, and the bootstrap body calls it directly | The bootstrap deliberately does not call `harness-begin` — it judges the runner's primitives with raw conditionals, using none of its facilities — so a check that lived only inside `harness-begin` would leave the two bootstrap lanes unchecked. One line in the shared bootstrap body is what keeps "every lane that runs Scheme checks its provenance" true rather than nearly true. |
| V12 | No output assertion is added | Protium's provenance lanes assert on output as well as status, but its status 3 has to coexist with a 77 and with fixtures that expect 2. Here 3 is exclusive to provenance and no other lane can produce it, so status alone discriminates. An `EXPECT_OUTPUT_CONTAINS` mechanism would be a new decision owing its own specification and mutations for no added discrimination. |

### 3.1 Rejected alternatives

- **Fingerprinting a computed value rather than files.** The run could digest its own case ids and
  outcomes, which needs no `adapter-file-bytes` at all and would catch an artifact built from older
  text whose case list changed. Rejected on two counts: it is blind to a body whose text changed
  without changing case names, which is most edits, and slice 6's D6 and D7 need
  `adapter-file-bytes` regardless. Building it here gives the binary read its first consumer and its
  first cross-runtime agreement evidence at no extra cost.
- **One global manifest for the whole project.** Zero per-lane bookkeeping and no forgotten-body
  hole. Rejected under V3: it cannot name staged copies, so 5b and 5c would have to replace it
  rather than extend it, and it reports on text a given lane never loaded — a fingerprint that is
  green because of files the lane did not run is a claim about the tree wearing the label of a claim
  about the run.
- **Comparing lanes against each other instead of against a build-computed value.** The most direct
  reading of "all four lanes agree". Rejected because it needs cross-process comparison machinery the
  registration layer does not have (V4), and because it is satisfied by four lanes that all read the
  same wrong file. Agreement with a value the build computed from the repository sources subsumes it.
- **Folding provenance into status 2.** Cheaper by one status. Already rejected, with a measurement,
  in slice 2's decision S3: several lanes in this tree legitimately expect 2, so a mismatch would be
  indistinguishable from those fixtures' own expected outcome on a third of the suite.
- **Deadlines, `harness-await`, and the deterministic PRNG.** Present in protium's harness and
  adjacent to this work. Deadlines were refused permanently in slice 2 S1 — byte-machine has no
  async anywhere — and the PRNG belongs to M2's split schedules and M7's property tests. Copying
  either here would repeat the pattern decision 0001 named and rejected: a requirement inherited
  from a sibling's problem rather than owned by this one.

## 4. Layout

Created:

```text
test/support/harness/shared/fingerprint.scm        the algorithm, included by both adapters
test/support/launchers/fingerprint-manifest.ss     the build-time expectation
.decisions/0004-content-fingerprint-and-provenance.md
```

Modified: both adapters (`adapter-file-bytes`, the export list, and the new include),
`test/support/harness/shared/harness-runner.scm`, `test/support/harness/self/harness-bootstrap.scm`,
`cmake/ByteMachineSchemeLane.cmake`, `test/CMakeLists.txt`,
`test/support/cmake/ByteMachineSchemeLaneSpec.cmake`,
`test/support/cmake/SchemeMutationSuite.cmake`, and `CHANGELOG.md`.

### 4.1 Two build-layer details that are easy to miss

**The cwd-matrix copies.** `fingerprint.scm` is included by both adapters, so it joins the set of
bodies the `same-name-identical` and `same-name-decoy` directories must each carry. That rule is
already stated in `test/CMakeLists.txt`: both non-empty directories carry a copy of every body the
lane includes, because a directory holding only some of them would fail to build
`(byte-machine test harness)` under the launcher mutation, before reaching the code under test, and
all three Chez lanes would then fail identically — destroying the only evidence that they differ.
Adding the include without adding the two `configure_file` calls converts an asymmetric,
discriminating mutation into a symmetric, meaningless one, and the suite stays green while doing it.

**The portability guard needs no change.** `fingerprint.scm` lands in
`test/support/harness/shared`, already a `SHARED_DIRS` entry, so it owes no program wrapper. Its
basename is unique across the shared-body namespace, which the guard checks.

## 5. The algorithm

### 5.1 `adapter-file-bytes`

One new adapter procedure per runtime, and the last piece of the adapter protocol slice 2 declared
and left unimplemented.

```scheme
;; Chez
(define (adapter-file-bytes path)
  (let* ((port (open-file-input-port path))
         (bytes (get-bytevector-all port)))
    (close-port port)
    (if (eof-object? bytes) (make-bytevector 0) bytes)))
```

Gambit has no `get-bytevector-all` in the R7RS surface, so it reads `open-binary-input-file` in
chunks and concatenates. Both are binary ports, which is what makes the value a fingerprint of bytes
rather than of decoded characters — and is the same port discipline slice 6's D7 needs to prove LF
survives on Windows. That proof stays in slice 6; what lands here is the port choice it depends on.

An empty file fingerprints as the seed rather than raising, which is why the Chez branch normalizes
the EOF object: `get-bytevector-all` returns EOF, not a zero-length bytevector, for an empty file.

### 5.2 `fingerprint.scm`

A polynomial rolling hash modulo 2⁶¹−1. It is a change detector, not a cryptographic digest, and the
body says so where a reader will meet it.

Three decisions in it, each with a mutation in §7:

- **The `+1` on each byte.** Without it, leading zero bytes are absorbed and two files differing only
  by a run of leading NULs fingerprint identically.
- **`harness-fingerprint-combine` folds in manifest order**, so a reordered manifest is a different
  value. Order sensitivity is what makes the combined value a fingerprint of a *sequence* of bodies
  rather than of a set.
- **Hex comes from an explicit lowercase digit table**, forced by §2.1.

### 5.3 The bound this slice does not close

The manifest is **declared, not observed.** Scheme cannot portably report which files an `include`
spliced in, so what the fingerprint proves is that *the declared text is unchanged and both runtimes
read it identically* — not that *the run included exactly those files*. A lane whose manifest named
the right bodies while its wrapper included different ones would pass.

This is stated at the algorithm and in the decision record rather than left for a later reader to
discover. What already narrows the gap: slice 3's T6 runs body mutations on both runtimes and
requires the lanes to notice, so a body in the manifest that the run did not actually execute is
caught by its mutation surviving. The residue — a body executed but absent from the manifest — is
what V9's required argument makes hard to reach by accident, and it is the reason `SHARED_BODIES` is
a required argument rather than an optional one defaulting to something plausible.

## 6. Wiring

Two environment variables, both set by `byte_machine_add_scheme_lane`:

| Variable | Value |
| --- | --- |
| `BYTE_MACHINE_FINGERPRINT_FILES` | the manifest, `\|`-joined, in declaration order |
| `BYTE_MACHINE_EXPECT_FINGERPRINT_FILE` | path to the build-computed expectation |

`fingerprint-manifest.ss` runs under Chez at build time, `load`s `fingerprint.scm` (V6), and writes
the combined value to the expectation file. It is an `add_custom_command` whose `DEPENDS` names every
manifest body, so editing a body recomputes the expectation; keyed by a digest of the manifest so
registrations sharing a manifest share one computation rather than each spawning a process to
produce the same answer.

### 6.1 The Gambit lane is the one that carries claim 2

The expectation is computed by a Chez process. A Chez lane therefore compares Chez's output against
Chez's own computation of the same algorithm over the same files, and agrees with itself by
construction for anything the two have in common — including a rendering decision that is wrong the
same way in both places.

It is the **Gambit** lane that turns the expectation into a cross-runtime claim: it renders under one
runtime and compares against a value produced by the other. That is not a weakness to work around, it
is where claim 2's evidence actually lives. Stated here because "both lanes check the fingerprint"
reads like two units of evidence and is one.

No mutation demonstrates this. §7's F6 was expected to and, measured, does not — see the note there.
It is an argument about how the build is wired, and it is marked as one rather than dressed as a fact
the suite reproves.

Computing the expectation under both runtimes and requiring them to agree at build time would move
that evidence into the build. Rejected as a second mechanism proving what the Gambit lane already
proves, and one that would make the expectation unavailable on a host with no Gambit — which the
`no-scheme` preset and the "skip the lane, do not fail configuration" rule both depend on.

`harness-verify-provenance!` runs before any case. On an unset or empty
`BYTE_MACHINE_FINGERPRINT_FILES` it returns immediately and silently (V13). Otherwise it fingerprints
each manifest entry, prints the per-file values and the combined value, then compares. On mismatch,
on a missing expectation file, or on an unreadable manifest body, it prints a `PROVENANCE-ERROR` line
and a summary line carrying `cases=0 status=3`, and exits.

### 6.2 Why an absent manifest is not itself a failure

An unset manifest means the process was not started by a lane registration, and the only two things
that start a harness program any other way are a developer running one by hand and the Scheme
mutation suite. The second is not optional: `byte_machine_mutation_run` requires every spec to exit 0
unmutated on the staged tree, and `byte_machine_mutation_run_spec` runs its verify commands with no
environment at all. A refusal there fails 27 passes at their baseline, before any mutation runs.

What makes skipping safe is that the guarantee lives one layer up and is stronger there. `SHARED_BODIES`
is a required argument (V9), so a registered lane always has a manifest; there is no reachable path
by which a real lane silently loses provenance. A run-time refusal would add nothing on top of that
except a rule the repository's own tooling cannot satisfy.

The cost is one lane. An earlier draft registered `byte-machine.harness.provenance-no-manifest.chez.source`
asserting that an unset manifest exits 3; it is deleted rather than inverted, because a lane asserting
that a skip *skips* would pass whether the code checked anything or not.

The 12 launcher-refusal lanes are unaffected: the launcher dies before `load-program`, so the harness
never runs. That is correct — they assert the launcher refuses, and a provenance check they cannot
reach would be a check in name only.

## 7. Lanes and mutations

Four new lanes, taking the suite from 40 to 44. The `no-scheme` preset stays at 10.

| Lane | Asserts |
| --- | --- |
| `byte-machine.harness.provenance.chez.source` | a deliberately wrong expectation → 3 |
| `byte-machine.harness.provenance.gambit.source` | a deliberately wrong expectation → 3 |
| `byte-machine.harness.provenance-absent-expectation.chez.source` | the expectation file was never built → 3 |
| `byte-machine.harness.provenance-missing-body.chez.source` | the manifest names an unreadable file → 3 |

The two mismatch lanes run on both runtimes because the path they exercise is not identical text on
both: it reads the expectation file through `adapter-file-bytes`, which is new per-runtime code in
this slice, and exits through `adapter-exit`. The two refusals run on Chez only, under slice 2's
rule S6 — they are decisions in the shared runner body, identical text on both, and the mismatch
lanes already establish that both runtimes reach it.

The wrong expectation is produced by the build as a file that is not a fingerprint of anything and
cannot become one, so the check is proved to fire by a registered lane rather than by editing a
build artifact during a mutation gate.

Mutations, each on a staged copy, each expected to be caught by a named lane:

| # | Target | Mutation |
| --- | --- | --- |
| F1 | `fingerprint.scm` | the `+1` byte offset removed |
| F2 | `fingerprint.scm` | the seed changed |
| F3 | `fingerprint.scm` | the multiplier changed |
| F4 | `fingerprint.scm` | the modulus changed |
| F5 | `fingerprint.scm` | `harness-fingerprint-combine` made order-insensitive |
| F6 | `fingerprint.scm` | hex rendered through `number->string` with radix 16 |
| F7 | `harness-runner.scm` | the comparison always reports a match |
| F8 | `harness-runner.scm` | the two non-comparison refusal paths of §6 — absent expectation file, unreadable manifest body — one mutation each, plus `harness-begin` no longer calling the check |
| F9 | both adapters | `adapter-file-bytes` deleted from the export list |

F5 needs a manifest of at least two bodies to be witnessable; every real lane already has one.

**F6's outcome was predicted asymmetric and measured symmetric.** The prediction ran: `fingerprint.scm`
is the same file the build-time expectation loads (V6), so mutating the digit table mutates both sides
of the Chez comparison at once, the two still agree, and the mutation survives on Chez while the
Gambit lane catches it. That reasoning is sound about a *provenance-wrapped* verify command and wrong
about the one this suite actually uses.

Measured 2026-08-17: the mutation is **caught symmetrically, on both runtimes**. The passes that carry
it set no manifest, so `harness-verify-provenance!` returns immediately and provenance never runs
there at all (V13). What catches the mutation is the self-tests' own "hex digits are lowercase on
every runtime" case, which `check-equal`s the fixed literals `"ff"`, `"deadbeef"` and `"0"` rather
than deriving anything from `fingerprint.scm` — so both runtimes fail an ordinary comparison. No
asymmetric declaration, no asserted survivor.

The consequence for §6.1 is recorded rather than glossed: **no mutation in this slice demonstrates
that the cross-runtime claim rests on the Gambit lane.** §6.1 remains true — the expectation is
computed by a Chez process, so a Chez lane compares Chez against Chez — but it is an argument from
how the build is wired, not a fact this suite reproves on every run. Demonstrating it would need a
pass whose verify command is provenance-wrapped *and* whose expectation is built from an unmutated
tree, which the staged-copy model does not offer, since the stage is what gets mutated.

F9 is checked per runtime for slice 2 §9.1's reason: Scheme cannot portably reflect on a library's
export list, so parity between the two adapters is established by mutation rather than by review.

None is `EXPECT_SURVIVES`.

## 8. Work order

Each step must fail before it passes.

1. `fingerprint.scm` and `adapter-file-bytes` on both runtimes, driven by new cases in the existing
   self-tests body. No CMake yet. Exit: both runtimes agree on the §2 values.
2. `fingerprint-manifest.ss` and the `add_custom_command` producing an expectation file.
3. `harness-verify-provenance!` and its four refusals, plus the `SHARED_BODIES` and
   `WRONG_FINGERPRINT` arguments to `byte_machine_add_scheme_lane` and its specification.
4. Register `byte-machine.harness.provenance.chez.source` expecting 3. It fails because nothing
   produces 3. This is the slice's central failing test.
5. The remaining four provenance lanes; `SHARED_BODIES` made required and every existing lane given
   one; the two cwd-matrix `configure_file` calls of §4.1.
6. The §7 mutations, with the suite's own totals asserted.
7. `CHANGELOG.md` and the decision record.

## 9. Exit criteria

- Both runtimes print the same combined fingerprint for the same manifest, verified against one
  build-computed value.
- All five provenance lanes exit exactly 3.
- The existing 40 tests still pass, now each with provenance checked, bringing the suite to 44; the
  `no-scheme` preset stays 10/10.
- The Scheme mutation suite's baseline stays green: every pre-existing pass runs with no manifest and
  therefore no provenance check, and none of its declared expectations changes (V13, §6.2).
- Every mutation in §7 is caught for its declared reason, with the suite's own totals asserted.
- A decision record states the §2 measurements, the §5.3 bound, and the V1 split with what 5b and 5c
  inherit.

## 10. Explicitly deferred

- **Chez AOT** — slice 5b. It inherits `SHARED_BODIES` unchanged and adds a manifest naming the
  compiled artifact's source rather than the repository original.
- **Gambit `.o1` and `-exe -nopreload`** — slice 5c. Both need staged trees, and protium's measured
  finding applies: Gambit decides an object is current by comparing timestamps with the `.sld` alone
  and never consults the files it includes, so an `.o1` lane can silently become a source lane.
- **Cross-library identity under compiled lanes** — slice 4 §10, discharged by 5b and 5c registering
  the two identity programs against the new lanes.
- **Deterministic emission and the binary LF proof** (D6, D7) — slice 6. This slice gives them the
  binary port discipline they depend on and nothing else.
- **Comparing reported OS and architecture against discovery** (§24.2 stage 2) and **CI** — slice 7,
  as slice 2 §11 already recorded.

## 11. Open questions carried forward

**Should the manifest be observed rather than declared?** §5.3 states the bound. Closing it needs a
runtime that can report what an `include` spliced in, which neither standard provides, or a
build-layer scan that parses include forms out of the wrappers — a lint whose shape should not be
fixed before M1 shows what the real import graph looks like. Carried forward for the same reason
slice 4's U4 carried the one-owner guard: the condition that reopens it is a shared body executing
in a lane whose manifest does not name it, which V9's required argument makes hard to reach by
accident and does not make impossible.

Slice 4's own open question — what Gambit does when a `define-library` body defines a name the
library also imports — is untouched by this slice and remains open.
