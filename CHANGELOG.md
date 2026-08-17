# Changelog

All notable changes to byte-machine are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Milestone 0 (portability and harness spike) is in progress. No public API
exists yet; see
[the implementation plan](docs/plans/byte-machine-implementation-plan.md) for
scope and [the milestone plan](docs/plans/milestone-0-portability-spike.md) for
what this milestone delivers.

### Added

- CMake build frontend with checked-in presets and a thin `Makefile` over it.
- Probe-based Chez and Gambit discovery that interrogates candidates rather
  than trusting binary names, rejecting Petite and Ghostscript's `gsc`. See
  [decision 0001](docs/decisions/0001-toolchain-discovery.md).
- CTest registration helper enforcing the test-name grammar, label vocabulary,
  duplicate-name rejection, and mandatory timeouts at configure time.
- Specifications for the functional core of every build-layer module, runnable
  under `cmake -P` with no Scheme runtime present.
- A mutation suite that breaks each decision in each module on a staged copy and
  requires the owning specification to notice, so "the specifications pass" is a
  claim the repository can check rather than one it merely asserts.
- A specification for the shared assertion helper itself, which every other
  specification depends on and none of them could have caught breaking.
- `.gitattributes` normalizing the repository to LF and marking fixture trees
  binary, since generated-source comparison and CRLF-framed HTTP fixtures both
  depend on exact bytes.
- A dependency-free portable test harness: one shared runner body included by a
  thin `(byte-machine test harness)` library per runtime, with adapters that
  export identical names and contain no test semantics of their own. Assertions,
  groups and cases, an isolated self-probe, and a computed exit status.
- Source execution lanes for both runtimes. Chez runs through a launcher that
  pairs the library root with an always-empty object directory, so a stale
  compiled object cannot be loaded by a lane that calls itself source. Each of
  the launcher's three refusals — a wrong argument count, a guard directory that
  is missing, and one that has acquired a file — is a lane of its own asserting
  status 2, because a lane that is set up correctly never reaches a refusal and
  so cannot notice one being deleted. Gambit gains a `source` mode: both of its
  compiled modes shell out to a C compiler fixed when Gambit was built, which
  would have made the first slice that runs Scheme unable to run on Gambit at
  all without that toolchain.
- Exact-exit-status assertions. The harness gives 0, 1, and 2 distinct
  meanings, and reserves 3, not yet produced, for lane provenance in a later
  slice. An expectation outside this four-value vocabulary is a configure
  error. A status outside it that is *observed* is reported as its own failure
  rather than as a wrong assertion outcome, since it means the process died
  before the harness could report.
- Mutation testing extended to the Scheme harness and to the Chez launcher. Each
  decision is broken on a staged copy and checked against whichever lane can
  witness it: the self-tests for most decisions in the runner, the bootstrap lane
  for the failure counter every assertion reports through, the empty-selection
  lane for the environment read no in-process assertion can reach, and one lane
  per launcher refusal. Adapter export parity is checked the same way, on each
  runtime, because Scheme cannot portably reflect on a library's export list.

  Five mutations are declared survivors instead, each with a written reason the
  suite fails if it stops being true. Three are print-only — probe output
  suppression and the two halves of `BYTE_MACHINE_TEST_VERBOSE` — and share one
  cause: they change what is printed, never a counter or a status, and the
  portable subset has no string ports for a suite to read its own output back
  with. One is `harness-summary`, `harness-empty-selection-error`, and
  `harness-failure-context`, used only inside the shared runner body that
  `include` splices into each adapter's library, so an internal reference
  resolves whatever the export list says and dropping one of the three is not
  detectable. The last is the launcher's `compile-imported-libraries` call:
  deleting it restates Chez's default and changes nothing, and turning it on
  writes an object into the guard directory only *after* that directory's
  emptiness has been asserted, so the pollution is visible to the next process
  and not to the one that caused it. The registered lanes do catch that one —
  the correctly configured ones share a single guard directory — which this
  suite, one process per mutation, cannot.

  The pairing that makes a Chez source lane honest is checked against a library
  root built for the purpose: no root in the tree has a compiled object beside
  its source, so unpairing the root from the guard is invisible everywhere else.
  The pass compiles a poisoned copy of the adapter — one whose runtime name is a
  sentinel — into a root of its own, beside the pristine source. Paired, the
  object is unreachable and the self-tests pass; unpaired, Chez loads it and the
  sentinel comes out in the banner, the failure context, and the exit status.
- A portability guard failing the build when a shared test body is missing a
  wrapper, when two shared bodies share a basename, when any declared directory
  contributes no body, when no directory is declared at all, when it receives an
  argument it does not recognize, or when a `SHARED_DIRS` or `WRAPPED_DIRS`
  entry is not an existing directory. Its glob recurses, so a body in a
  subdirectory is checked rather than unseen. Every rule past the first two was
  added after being shown to leave a tree unchecked while still producing a
  green build.
- The first product library: one shared body in `src/common/byte-machine/`
  included by exactly one thin library per runtime. Its type tag and singleton
  are freshly allocated rather than symbols, because symbols are interned and a
  symbol tag would make a body included twice indistinguishable from one
  included once — the defect the one-owner rule exists to prevent.
- A working-directory matrix. The same body loads through both wrappers from
  three directories chosen so each catches a different failure: a copy where an
  include resolved against the working directory would accidentally succeed, a
  same-named impostor where it would report the wrong answer, and an empty
  directory where it would find nothing. All three pass under a correct
  mechanism, so what proves them is a launcher mutation whose expected outcome
  is asymmetric — the first passes, the other two fail — with the survivor
  asserted rather than ignored.
- Mutation coverage that runs on both runtimes for the shared body, inverting
  the rule the harness runner uses. A wrapper that quietly reimplemented the
  body is exactly a wrapper whose runtime does not notice the body changing, so
  the claim that no wrapper duplicates semantics is witnessed rather than
  reviewed.
- The Chez launcher takes repeatable `--library-root` and `--source-dir` flags,
  since a lane now imports from both the harness and the product tree. Each of
  its parse refusals is a lane asserting status 2, because a correctly set-up
  lane never reaches one.
- A Gambit search root containing a comma is refused at configure time.
  Gambit's `-:` options are comma-separated, so such a root makes `gsi` print
  its usage banner and run no Scheme at all, on every Gambit lane at once, in
  output that names nothing this project owns. A relative search root is
  refused too, for a different reason: `gsi` resolves it against its own
  working directory, so the lane would find its libraries or not depending on
  where it was launched — the one thing the working-directory matrix exists
  to rule out.
- `byte_machine_add_test` gains an optional `WORKING_DIRECTORY`, overriding
  its derived per-test run directory; the temporary directory it also creates
  is unaffected. `byte_machine_add_exit_code_test` and
  `byte_machine_add_scheme_lane` forward it, which is what lets the
  working-directory matrix launch six lanes from three fixture directories
  instead of their derived ones.
- Cross-library identity proof (Milestone 0 slice 4, deliverable D3). A second
  library per runtime, `(byte-machine placeholder-consumer)`, built over its own
  wrapper-free body whose free identifiers are supplied by the wrapper's import
  of `(byte-machine placeholder)`. A shared test body importing both libraries
  asserts that a value built through the owner is recognised through the
  consumer, and that the allocation-free singleton is one object across both
  imports.
- The consumer body additionally proves a mechanism Milestone 1 depends on and
  nothing previously exercised: a shared body naming another library's exports
  as free identifiers, resolved identically by R6RS library-body `include` and
  R7RS `define-library` `include`.
- Eight Scheme mutations in four passes (24 to 27), bringing the suite to 27
  passes and 64 mutations. The decisive two replace each consumer wrapper's
  import with an include of the owner's body: the mutant answers both
  identity claims wrongly and raises nothing, but the identity lane still
  fails it — an ordinary `check`/`check-equal` mismatch, exit 1 on both
  runtimes — while every lane that imports only the owner stays green.
- [Decision 0003](docs/decisions/0003-cross-library-identity.md), including
  the deferred one-owner guard with the condition that reopens it, and an
  open question about Chez and Gambit disagreeing over a library body that
  redefines an imported name.
- A content fingerprint of the shared test bodies a lane's manifest names,
  checked in-process against a value the build computed from the same files
  before the run — proving the declared text is unchanged on disk and read
  identically by both runtimes, not that the run executed it, so two lanes
  claiming to run the same text can be shown to disagree rather than merely
  trusted to agree. `adapter-file-bytes`
  reads a file through a binary port on both runtimes, the last piece of
  slice 2's adapter protocol left unimplemented. The algorithm is a
  polynomial rolling hash using only exact integer arithmetic, never bitwise
  operations, since neither R6RS nor R7RS guarantees the latter over the
  unbounded range the fold needs. Hex renders through an explicit lowercase
  digit table rather than `number->string` with a radix, because Chez and
  Gambit render `(number->string 255 16)` as `FF` and `ff` respectively —
  measured on both runtimes — and a fingerprint whose case depended on that
  would make the one claim it exists to carry, that both runtimes agree,
  depend on a detail they already answer differently.
- The expectation a lane's fingerprint is checked against is computed once
  at build time, from the repository sources, by `load`ing the same
  `fingerprint.scm` the lane itself runs rather than reimplementing the
  algorithm a second time — a second implementation agreeing with the first
  would prove nothing, since the two could drift and the drift would look
  like a passing comparison. A run that cannot show it executed the intended
  text now exits status 3 before any test case runs: the first thing in this
  tree to produce the status slice 2's decision S3 reserved for exactly
  this.
- `byte_machine_add_scheme_lane` gains a required `SHARED_BODIES` argument:
  a lane cannot be registered without declaring the manifest it will be
  checked against. At run time, an unset or empty manifest means the
  process was not started by a lane registration — a developer running the
  harness by hand, or the mutation suite, whose own machinery runs every
  verify command with no environment at all — and provenance is skipped
  rather than refused, because refusing would fail the mutation suite's own
  baseline before a single mutation ran. The guarantee lives at configure
  time, where it cannot be forged by anything a running process does.
- Six new lanes prove the check can fail, each exiting exactly 3, for one
  of four diagnoses: a wrong expectation (reported identically by the Chez
  and Gambit lanes, which differ only by runtime), a build that never
  produced one, a manifest naming a body that cannot be read, and a manifest
  the run never verified at all. The suite grows from 40 to 46 tests and the
  Scheme mutation suite from 27 to 35 passes (64 to 83 mutations), breaking
  every decision in the algorithm and in the check itself on a staged copy. One of those mutations — the hex digit table
  turned uppercase — was predicted to be caught only on Gambit, since the
  build-time expectation loads the same mutated file a Chez lane runs
  against; measured, it is caught symmetrically on both runtimes instead, by
  an unrelated self-test comparison against fixed literal strings, because
  the passes that carry it set no manifest and provenance never runs there
  at all. Both the design record and the mutation suite's own comment were
  corrected once this was measured.
- A lane that was given a manifest and never verified it now exits 3.
  Requiring the manifest at configure time makes the environment
  unforgeable; it says nothing about whether anything read it, and the check
  is reached either through `harness-begin` or through a hand-placed call —
  which is what the bootstrap body needed, having deliberately no
  `harness-begin`. Forget that line in a future body and the lane runs
  un-provenanced with nothing failing, which was the last way the
  configure-time guarantee could hold while the run-time one did not. The
  guard fires from the summary, so it cannot catch a body that reaches
  neither the summary nor the check — the bootstrap's own shape, a single
  deliberate exception that carries its own call.
- [Decision 0004](docs/decisions/0004-content-fingerprint-and-provenance.md),
  including the bound the manifest does not close — a matching fingerprint
  proves the declared text is unchanged, not that the run included exactly
  those files — and the open question that reopens it.

### Changed

- Chez discovery now probes each candidate name in turn instead of committing to
  the first one `find_program` returns. A host with an unrelated `scheme` earlier
  on PATH than its Chez previously failed to configure.
- Version floors are checked for presence before use. `if(x VERSION_LESS "")` is
  false in CMake, so an absent floor accepted every release silently.
- The Chez version is read from after the banner's `Version` keyword rather than
  from the first dotted number anywhere in it.
- Gambit's interpreter is interrogated before its compiler is derived, so a
  Ghostscript `gsi` reports that it is not Gambit instead of complaining about a
  derived path that was never the problem.
- An explicitly set `BYTE_MACHINE_GAMBIT_COMPILER` now survives the interpreter
  changing in the same configure. Provenance is decided by comparing the cached
  value against the recorded derivation, not by interpreter identity.
- Test presets declare a configuration and refuse an empty selection, so the
  documented preset entry point behaves like `make` — on Windows' default
  multi-config generator every test previously reported "Not Run".
- Specifications print their success banner only when nothing failed.
- `MutationRunner` is now generalized on three axes rather than two: it takes
  the staged trees and the verify command as parameters, so a mutation can be
  judged by running a real execution lane rather than only by `cmake -P`;
  gained a reset entry point so a second declaration pass can run under a
  different verify command in the same script — needed because the Scheme
  suite's passes each judge a different decision through a different lane:
  the shared runner against the self-tests, each adapter's export list on its
  own runtime, and two further runner decisions reachable only through the
  empty-selection and bootstrap lanes; and gained a verify working directory,
  separate from the staged tree, because the working-directory matrix's
  single mutation is judged by launching from three different directories,
  not by what it does to the stage. The CMake-layer suite keeps its previous
  behaviour by default on all three axes.
- `byte_machine_mutation` gained optional `EXPECT_STATUS` and
  `EXPECT_OUTPUT_MATCHES`, narrowing "caught" to "caught for the declared
  reason": a nonzero verify-command result whose exit status or combined
  stdout+stderr does not also satisfy the declared expectation is reported
  separately, as caught for the wrong reason, and counted the same as an
  outright miss rather than as a pass. Applied only where measured, not
  guessed — a REPLACE that once opened a line comment and swallowed a list's
  closing parens had reported caught at exit 255 on a read error rather than
  on the refusal it named.
- `byte_machine_mutation_run` now accumulates a running pass and mutation
  count across every call in a process (`byte_machine_mutation_totals`), and
  both mutation suites compare that total against a count declared next to
  their own header comment, failing loudly on a mismatch. A whole-branch
  review had deleted an entire pass group from the Scheme suite and left it
  reporting 37/37 regardless, with the mutation count silently dropping
  underneath that number and nothing noticing; this is what would have
  caught it.

### Fixed

- `MutationRunner.cmake` — the machinery every specification in this tree is
  trusted through, and staged like everything else — had neither a
  specification nor a mutation targeting it. A re-review found this let the
  "caught for the declared reason" narrowing above reproduce the exact defect
  class it was written to close, one layer down: the branch that turns a
  wrong-reason result into a failure could be deleted by hand and the real
  CMake-layer suite stayed 89/89, because nothing mutated the decision that
  branch depends on, or the branch itself. The verdict decision is now split
  out as a pure function, `byte_machine_mutation_verdict` — no
  `execute_process`, no filesystem — with its own specification,
  `MutationRunnerSpec.cmake`, registered so it also runs under
  `ctest --preset no-scheme`. Five mutations in `MutationSuite.cmake` break
  each of the pure function's decisions and the registration guard beside it,
  and the specification carries a sixth, self-contained check of its own: a
  real staged mutation, deliberately declared with an unsatisfiable
  `EXPECT_OUTPUT_MATCHES`, that reaches past the pure function into
  `byte_machine_mutation_run` itself to prove a wrong-reason verdict is acted
  on and not merely computed correctly and discarded — the one part of this
  fix that cannot be specified as a pure function, because it is what the
  imperative shell does with the answer, and the exact branch the original
  deletion targeted.
- `EXPECT_OUTPUT_MATCHES`'s presence was tested by truthiness rather than
  `STREQUAL ""`, unlike the `EXPECT_STATUS` check one line above it. A
  pattern CMake itself reads as false — `"0"`, `OFF`, `NOTFOUND`, anything
  ending `-NOTFOUND` — is still a regex someone declared, and would have been
  silently unenforced rather than checked.
- `byte_machine_mutation` now refuses `EXPECT_SURVIVES` declared together
  with `EXPECT_STATUS` or `EXPECT_OUTPUT_MATCHES`. A declared survivor is
  judged only by whether the verify command exited zero, so the other two
  would have been parsed, stored, and never consulted — silently inert
  rather than enforced.
- The `WORKING_DIRECTORY`-forwarding conditional in `ByteMachineExpectExit.cmake`
  and `ByteMachineSchemeLane.cmake` was mutated in only one direction —
  `if(arg_WORKING_DIRECTORY)` to `if(FALSE)` — which only the specifications'
  "present" assertions could catch. Their "absent" assertions, proof that the
  keyword does not reach the registrar when no caller gave one, are exactly
  what stops the `CMP0174`-driven conditional-forwarding fix from silently
  regressing to unconditional forwarding, and had no mutation exercising
  them. Both sites now also mutate to `if(TRUE)`.
- `SchemeMutationSuite.cmake`'s pass 8 (the poisoned-compiled-object
  mutation) now declares `EXPECT_OUTPUT_MATCHES "POISONED-FROM-OBJECT"`,
  enforcing what its own comment already claimed: the mutated run names the
  sentinel in its banner, its FAIL-CONTEXT line, and its summary. Its
  without-Gambit expected pass and mutation counts are now derived from the
  with-Gambit pair and a declared Gambit-only delta (2 passes / 7 mutations)
  instead of duplicated as a second pair of literals that a new non-gated
  pass could update only one half of. A comment naming a retired ctest lane
  is corrected to include its `.chez.source` suffix.
