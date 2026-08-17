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
- `MutationRunner` takes the staged trees and the verify command as parameters,
  so a mutation can be judged by running a real execution lane rather than only
  by `cmake -P`, and gained a reset entry point so a second declaration pass
  can run under a different verify command in the same script — needed because
  the Scheme suite's passes each judge a different decision through a different
  lane: the shared runner against the self-tests, each adapter's export list on
  its own runtime, and two further runner decisions reachable only through the
  empty-selection and bootstrap lanes. The CMake-layer suite keeps its previous
  behaviour by default.
