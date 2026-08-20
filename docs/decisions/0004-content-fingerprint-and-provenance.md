# 0004: The manifest is declared, not observed, and an unset one skips provenance rather than refusing it

Date: 2026-08-17
Status: accepted
Milestone: 0, slice 5a

> Amended 2026-08-18 by [decision 0006](./0006-inline-libraries.md): the
> include collapse renamed `SHARED_BODIES` to `SOURCES` (decision 3 below
> names the old spelling) and replaced `fingerprint-manifest.ss`'s verbatim
> `load` with an import of `(byte-machine test fingerprint)` (decision 4
> records the `load` mechanism). Both disciplines those decisions state —
> the manifest is declared and required at registration; provenance is
> skipped, never refused, at run time — are unchanged.

## Context

Milestone plan work-order item 5 requires "all four lanes green over the same
shared body, agreeing on a content fingerprint." Three earlier slices wrote
IOUs against it: slice 2 §11 deferred content fingerprinting,
`adapter-file-bytes`, and the production of exit status 3 to this slice;
slice 2 §7.3 required that a later slice "supply the equivalent guarantee for
each compiled lane it adds"; slice 4 §10 deferred cross-library identity
under compiled lanes here. See
[the slice-5a design](../plans/milestone-0-slice-5a-content-fingerprint.md).

Decision V1 splits deliverable D5 across three slices: 5a builds the
fingerprint and provenance instrument against the source lanes that already
exist; 5b adds Chez AOT; 5c adds Gambit's two compiled modes. Both later
slices inherit `SHARED_BODIES` unchanged from `byte_machine_add_scheme_lane`
(V9, below) and add only a manifest naming their own compiled artifact's
source. Building the instrument now, while every lane is still a source
lane, means it can be shown falsifiable on its own terms; built alongside
three new compiled lanes, its first failure would be indistinguishable from
theirs.

Three falsifiable claims, from design §1:

1. A lane reports the combined content fingerprint of the shared bodies it
   ran, and that value matches what the build computed from the repository
   sources before the run.
2. Chez and Gambit report the same string for the same bodies.
3. The check can fail: a lane given a deliberately wrong expectation exits
   **3**. Slice 2's decision S3 reserved that status; nothing in this tree
   produced it until this slice.

## Measurements

Measured 2026-08-17, Darwin 25.5.0 arm64, Chez 10.4.1 at
`/opt/homebrew/bin/chez`, Gambit 4.9.8 at
`/opt/homebrew/opt/gambit-scheme/bin/gsi` — against the shipped lanes and the
two runtime binaries directly, **not** against the design spec's own §2
table. That table is marked, in its own §2.0, as a pre-slice reading: three
of its four file fingerprints are of a body (`harness-runner.scm`) this
slice edits, and even the file set it fingerprints is not the manifest that
shipped. AGENTS.md requires a measurement to be re-taken against the shipped
artifact before it earns a place in a decision record; none of the values
below are copied from that table.

- **The radix divergence is real, on this machine, on the exact binaries
  discovery registers.** `(number->string 255 16)` renders `FF` under Chez
  and `ff` under Gambit:

  ```
  $ echo '(display (number->string 255 16))' | /opt/homebrew/bin/chez -q
  FF
  $ echo '(display (number->string 255 16))' | /opt/homebrew/opt/gambit-scheme/bin/gsi -f
  ff
  ```

  Neither is wrong; neither standard fixes the case. Because the whole point
  of the fingerprint is that both runtimes print the same string for the
  same text, rendering it through `number->string` would make that claim
  depend on a detail these two runtimes already answer differently, and
  comparing case-insensitively later would be worse — it would hide exactly
  the class of divergence the fingerprint exists to expose. This is why
  `fingerprint.scm` renders hex through an explicit lowercase digit table
  (`"0123456789abcdef"`) instead of a radix conversion.

- **Chez and Gambit agree on the combined fingerprint of a real manifest,
  from the shipped lanes.** `byte-machine.portability.placeholder-identity.chez.source`
  and `byte-machine.portability.placeholder-identity.gambit.source` each
  fingerprint the same five-body manifest, in declaration order —
  `fingerprint.scm`, `harness-runner.scm`, `placeholder.scm`,
  `placeholder-consumer.scm`, `placeholder-identity-tests.scm`:

  ```
  $ ctest --test-dir build/dev -R 'placeholder-identity' -V 2>&1 \
      | grep -E 'fingerprint combined=|Test #'
  39: byte-machine-harness: fingerprint combined=19e3c23b3996fb5
  1/2 Test #39: byte-machine.portability.placeholder-identity.chez.source .....   Passed    0.07 sec
  40: byte-machine-harness: fingerprint combined=19e3c23b3996fb5
  2/2 Test #40: byte-machine.portability.placeholder-identity.gambit.source ...   Passed    0.04 sec
  ```

  Both report `19e3c23b3996fb5` and both pass. This is claim 2, taken from
  the shipped artifact rather than the design's scratch prototype, and it is
  the slice's central cross-runtime claim.

- **The check fails on a deliberately wrong expectation, for four distinct
  reasons, and every failure exits exactly 3.** The four registered
  provenance lanes each report a different `PROVENANCE-ERROR` and the same
  `status=3`:

  ```
  41: PROVENANCE-ERROR fingerprint mismatch: the build expected not-a-fingerprint but this run computed 1aa87c76e563a9ce...
  42: PROVENANCE-ERROR fingerprint mismatch: the build expected not-a-fingerprint but this run computed 1aa87c76e563a9ce...
  43: PROVENANCE-ERROR no expectation was supplied, so nothing can say whether this run executed the text it was supposed to...
  44: PROVENANCE-ERROR cannot read .../no-such-body.scm, which this run is supposed to have executed...
  ```

  This is claim 3.

- **The hex-digit mutation (design §7, F6): predicted asymmetric, measured
  symmetric — a worked instance of the AGENTS.md rule above.** The
  prediction, written into the design before this was run: mutating
  `fingerprint.scm`'s digit table mutates both sides of a Chez comparison at
  once, because the build-time expectation `load`s the identical file (V6),
  so the mutation should survive on Chez and be caught only on Gambit.
  Measured, it is caught **symmetrically, on both runtimes**:

  ```
  -- byte-machine-mutation: caught fingerprint: hex digits become uppercase (Chez)
  -- byte-machine-mutation: caught fingerprint: hex digits become uppercase (Gambit)
  ```

  The two passes carrying this mutation set no manifest, so
  `harness-verify-provenance!` returns immediately (V13, below) and
  provenance never runs. What actually catches the mutation is the
  self-tests' own "hex digits are lowercase on every runtime" case, which
  `check-equal`s the fixed literals `"ff"`, `"deadbeef"`, `"0"` — nothing
  derived from `fingerprint.scm` — so both runtimes fail an ordinary
  comparison and exit 1. The prediction was corrected in two places once
  this was measured: the design document's own §7, and the comment above
  `SchemeMutationSuite.cmake`'s passes 30/31, both corrected the same day
  the measurement was taken. Only the measured outcome is used below; the
  prediction is not.

- **Suite totals, from real runs.** `make test` reports 46/46 and
  `ctest --preset no-scheme` stays 10/10, matching design §9's exit
  criteria; the Scheme mutation suite reports "35 passes, 83 mutations",
  also §9; the CMake mutation suite, which the design does not itself size,
  reports "1 pass, 97 mutations" — one mutation more than before this
  slice, added by a review that found the `WRONG_FINGERPRINT` routing
  unwitnessed: without it, a regression that always called
  `byte_machine_expected_fingerprint` would make every provenance lane
  compare its shared bodies' real fingerprint against itself and stop
  proving anything, invisibly to everything but the slow integration lanes.

## Decision

1. **Render hex through an explicit digit table, never `number->string`
   with a radix.** Forced by the radix measurement above: a fingerprint
   whose rendering depends on an unspecified detail cannot carry a
   cross-runtime claim.

2. **The manifest is declared per lane, not derived or observed (design
   §5.3).** Scheme cannot portably report which files an `include` spliced
   in, so a matching fingerprint proves that *the declared text is unchanged
   and both runtimes read it identically* — not that *the run included
   exactly those files*. A lane whose manifest named the right bodies while
   its wrapper included different ones would pass. Slice 3's T6 body
   mutations, run on both runtimes and required to be noticed, narrow this
   from one side: a body named in the manifest that the run did not actually
   execute is caught by its mutation surviving. The other side — a body
   executed but never named in the manifest — is not narrowed by anything in
   this slice; see the open question below.

3. **`SHARED_BODIES` is required (V9); an unset or empty manifest at run
   time means provenance is skipped, not refused (V13).** Refusing was the
   first design, and it is unimplementable against this tree's own tooling.
   `byte_machine_mutation_run` (`test/support/cmake/MutationRunner.cmake`)
   requires every specification a mutation targets to exit 0 on the staged,
   unmutated tree before any mutation runs, reporting a baseline failure
   otherwise; `byte_machine_mutation_run_spec` runs that verification
   through `execute_process` with no `ENVIRONMENT` argument at all, so a
   mutation-suite process never carries `BYTE_MACHINE_FINGERPRINT_FILES`
   regardless of what any lane registration would have set. A run-time
   refusal on an unset manifest would therefore fail every one of the
   mutation suite's baselines before a single mutation ran — the suite that
   is this repository's own proof that its specifications are not vacuous.
   Nothing is lost by skipping instead: `SHARED_BODIES` being a required
   argument of `byte_machine_add_scheme_lane` already makes an
   unprovenanced *registered* lane impossible, one layer up, at configure
   time — where the guarantee cannot be forged by anything a running
   process does. A run-time refusal would add only a rule the repository's
   own tooling cannot satisfy. The one lane that would have asserted the
   refusal, an earlier draft's `provenance-no-manifest` lane, is deleted
   rather than inverted, because a lane asserting that a skip *skips* passes
   whether or not the code checks anything.

4. **The build-time expectation is computed by a Chez process (design
   §6.1), so a Chez lane compares Chez against itself; the Gambit lane is
   what makes claim 2 cross-runtime.** `fingerprint-manifest.ss` runs under
   Chez and `load`s `fingerprint.scm` verbatim (V6) rather than
   reimplementing the algorithm, so a Chez lane's comparison agrees with
   itself by construction for anything the two computations have in common
   — including a rendering decision that is wrong the same way in both
   places. Only the Gambit lane renders under one runtime and compares
   against a value produced by the other; that is where claim 2's evidence
   actually lives, not a weakness to work around.

   **No mutation in this slice demonstrates this.** F6 was expected to and,
   measured above, does not. This is not a gap this slice's suite happens to
   leave uncovered by oversight: under the staged-copy model, every mutation
   pass mutates one tree and judges it with one verify command, so
   demonstrating the asymmetry would need a pass whose verify command is
   provenance-wrapped *and* whose expectation is computed from an
   *unmutated* copy of the same tree the runtime under test reads mutated —
   a second, differently-staged tree the model does not provide. It is an
   argument about how the build is wired, not a fact the suite reproves on
   every run.

## Consequences

- **Status 3 has a first producer.** Slice 2's decision S3 reserved it and
  nothing produced it before this slice; the four provenance lanes here
  (`byte-machine.harness.provenance.{chez,gambit}.source`,
  `byte-machine.harness.provenance-absent-expectation.chez.source`,
  `byte-machine.harness.provenance-missing-body.chez.source`) are the first
  code in this tree to exit it, for three named reasons, not four: a wrong
  expectation, an expectation the build never produced, and a manifest
  naming a body that cannot be read. The `chez` and `gambit` provenance
  lanes report the identical diagnosis for the first reason and differ only
  by which runtime ran it — design §7's own table already lists these four
  lanes against three assertions; this record now agrees with it.

- **5b and 5c inherit `SHARED_BODIES` unchanged; they do not, on that
  account, owe only a manifest.** V1's split still means a compiled lane's
  registration adds a manifest naming the compiled artifact's source rather
  than replacing any part of the registration mechanism, and the
  required-argument guarantee (V9) and the skip-not-refuse rule (V13) still
  need no change to extend to them. What does not carry over for free: a
  manifest naming that source proves nothing about the compiled artifact
  itself, because both sides of the check still read the source, never the
  artifact. See the gap below.

- **The concrete gap slice 5b must close: a matching fingerprint does not
  prove the running code was built from the text it names.** The final
  whole-branch review demonstrated this directly against the shipped code,
  in a scratch tree, in the shape slice 5b will have: compile
  `(byte-machine test harness)` to a Chez `.so`; edit `harness-runner.scm`
  afterward, leaving `harness.sls` itself untouched, so the object stays
  "current" by Chez's own rule — currency is decided by comparing the
  object's timestamp against the *wrapper's*, and a body reached only
  through `include` has no timestamp of its own that anything consults;
  recompute the expectation with the shipped launcher over the edited
  source; run a lane against the object. Result: `fingerprint verified
  against the build manifest`, exit 0 — while the compiled object provably
  did not contain the edit.

  The mechanism cannot do otherwise. `fingerprint-manifest.ss` at build time
  and `harness-fingerprint-file` at run time (`harness-runner.scm`) are the
  same function reading the same manifest paths from disk
  (`test/CMakeLists.txt`'s `byte_machine_expected_fingerprint`,
  `cmake/ByteMachineSchemeLane.cmake`'s `fingerprint_files`) — current disk
  contents are the only text there is for a source lane, but they are not
  what a compiled lane's object was built from. What the check actually
  proves is narrower than it can sound: **that the declared text is
  unchanged on disk and is read identically by both runtimes — not that the
  code actually executing was built from it.**

  This is a second bound, distinct from the one §5.3 and Decision 2 already
  record — that the manifest is *declared* rather than *observed*, so a
  lane is not proven to touch exactly the files it names. That bound is
  about which files a run reaches; this one is about whether a named file's
  *current* content has any relationship to a *previously built* artifact.
  Both are real and neither closes the other: naming every file a run
  touches would still leave each one read fresh at both ends, telling a
  compiled lane nothing about its object; and a build-baked expectation
  (below) would still say nothing about a file a run reaches outside its
  manifest.

  The direction for closing it, small enough to record now: generate a
  Scheme file at build time holding the combined expectation as a literal,
  have the compiled wrapper `include` it so the value is compiled *into*
  the artifact, and compare that literal — carried inside the object, not
  recomputed from today's source — against the value the run computes from
  the manifest. A stale artifact then carries a stale literal, the
  comparison disagrees, and the lane exits 3. The alternative that looks
  obvious instead — keep computing the expectation from repository
  originals as this slice does, but measure the artifact rather than the
  source — has nowhere to enter this tree today: `byte_machine_expected_fingerprint`
  is handed exactly the `arg_SHARED_BODIES` list the run-time manifest is
  also built from (`cmake/ByteMachineSchemeLane.cmake`, lines 240-241) — one
  list, not two — so "expectation from repository originals, measurement
  from staged copies" is not a distinction this function's inputs can
  express yet.

  One note on how to read this record's own language now:
  `harness-provenance-diagnosis`'s mismatch message (`harness-runner.scm`,
  line 133) offers "or it is running a stale artifact" as a reading of a
  fingerprint *mismatch*. That reading holds only when the staleness
  happens to touch a file the manifest names — the gap above is exactly the
  case where it does not, and the check passes rather than mismatching.
  Left as written rather than softened: it already carries a second,
  always-available reading ("this lane executed different text from the
  one the build measured"), it fires only after a mismatch has happened
  rather than characterizing a pass, and a claim about what a *passing*
  check proves belongs here, not in a string a Scheme process prints.

- **A caller-supplied `ENVIRONMENT` entry always wins over this function's own
  defaults, including `BYTE_MACHINE_EXECUTION_MODE` — pre-existing, and, after
  slice 5b's mode-vocabulary generalisation, caught only for a value outside
  `source`/`aot`/`o1`; a wrong value inside that vocabulary is silent.**
  `byte_machine_add_scheme_lane` appends `${arg_ENVIRONMENT}` after every
  default it computes for itself, by design
  (`cmake/ByteMachineSchemeLane.cmake`, reviewed in Task 5 of this slice):
  CTest applies repeated `ENVIRONMENT` keys in list order, last one wins. That
  ordering is what lets
  `byte-machine.harness.provenance-absent-expectation.chez.source` and
  `byte-machine.harness.provenance-missing-body.chez.source` force a specific,
  named failure, by overriding `BYTE_MACHINE_EXPECT_FINGERPRINT_FILE` or
  `BYTE_MACHINE_FINGERPRINT_FILES` after the function has already computed the
  real ones — the other two mismatch-provenance lanes,
  `byte-machine.harness.provenance.{chez,gambit}.source`, reach status 3
  through the dedicated `WRONG_FINGERPRINT` keyword instead, which changes
  what the function computes as its own default, with no caller `ENVIRONMENT`
  override involved.

  The same last-wins ordering means a caller's `ENVIRONMENT` could just as
  freely override `BYTE_MACHINE_EXECUTION_MODE=source`. *Measured 2026-08-17,
  before slice 5b's mode-plumbing commit (6a18d65); preserved here as history,
  superseded below, not current behavior:* that was not the silent hazard it
  first looks like. `harness-self-tests.scm`'s `check-equal "the mode is
  declared by the lane registration" (adapter-execution-mode) "source"`
  (around line 366) and `harness-bootstrap.scm`'s matching `bootstrap-assert`
  (lines 119-120) both compare `(adapter-execution-mode)` against the literal
  `"source"` inside a live check, and both already run in ordinary green lanes
  — the two `harness.self.*` lanes, the two `harness.bootstrap.*` lanes, and
  `harness.verbose.chez.source`. Checked against the shipped lane, not just
  the source: rerunning `byte-machine.harness.self.chez.source`'s exact CTest
  command and environment with only `BYTE_MACHINE_EXECUTION_MODE` changed away
  from `source` fails outright — `the mode is declared by the lane
  registration -- expected "source", got "chez-aot"`, exit 1, not 0.
  Overriding the variable on a source lane does not pass silently today; it
  turns the lane red. The real hazard 5b and 5c inherit is narrower: both
  assertions hardcode the comparison to `"source"` itself, so a compiled lane
  whose registration legitimately declares a different mode — an `aot` build
  under Chez, an `o1` optimisation level under Gambit — will fail these same
  checks on its own correct mode string, the day it exists, until the
  comparison is generalised to check against the mode the lane's own
  registration declares rather than a hardcoded literal. Landing that
  generalisation is concrete work 5b or 5c owes; it is not a gap either slice
  can discover by surprise.

  **That generalisation has landed — commit 6a18d65, decision W8 of
  `docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md` — in a narrower form
  than the paragraph above asked for.** Both assertions now read
  `(harness-member? (adapter-execution-mode) (list "source" "aot" "o1"))`
  (`harness-self-tests.scm` lines 377-379; `harness-bootstrap.scm` lines
  119-121): a vocabulary check, not the self-referential comparison against
  "the mode the lane's own registration declares" the paragraph above called
  for. Decision W8 gives the reason as self-reference — the check would measure
  the environment against itself — which is the weaker of the two available and
  is superseded by the one recorded beside the assertion itself: this body is
  staged inside `byte-machine.harness.scheme-mutation.cmake.direct`, which
  hand-sets `BYTE_MACHINE_EXECUTION_MODE=source` whatever it stages
  (`test/CMakeLists.txt` line 645), so a name-versus-mode cross-check here
  would be red on every mutation pass's baseline rather than only on a broken
  one. Re-measured
  2026-08-17 against the same shipped lane, the same way: an override outside
  the vocabulary is still caught — `BYTE_MACHINE_EXECUTION_MODE=chez-aot`
  still fails outright, exit 1 (`the mode is one the lane vocabulary defines
  -- expected a true value`). An override *inside* it but wrong for the lane
  is not: the identical rerun with `BYTE_MACHINE_EXECUTION_MODE=aot` on this
  same source lane now prints `mode=aot` and exits 0 — silent, on a smaller
  set of values than before 6a18d65, but silent. The narrower, sound claim
  this bullet always wanted, that *this* lane really is the mode it declares,
  moved instead to a `cmake -P` specification case that reads the functional
  core's name-to-mode mapping directly, where there is no live process for an
  `ENVIRONMENT` override to reach:
  `test/support/cmake/ByteMachineSchemeLaneSpec.cmake` asserts that a lane
  named `byte-machine.harness.example.chez.aot` computes
  `BYTE_MACHINE_EXECUTION_MODE=aot` (lines 366-367), and its `...chez.source`
  counterpart computes `=source` (lines 377-378).

- **Open question (design §11), carried forward unchanged: should the
  manifest be observed rather than declared?** Closing it needs either a
  runtime that can report what an `include` spliced in, which neither
  standard provides, or a build-layer scan of the wrapper's include forms,
  whose shape should not be fixed before Milestone 1 shows what the real
  import graph looks like. It reopens under one condition: **a shared body
  executing in a lane whose manifest does not name it.** `SHARED_BODIES`
  being required (V9) makes that hard to reach by accident; it does not
  make it impossible.

- All measurements are single-host, single-version: one macOS arm64
  machine, Chez 10.4.1, Gambit 4.9.8. Nothing here is a claim about any
  other release or Tier 1 platform.
