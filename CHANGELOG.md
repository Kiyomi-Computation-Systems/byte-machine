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

### Changed

- Chez discovery now probes each candidate name in turn instead of committing to
  the first one `find_program` returns. A host with an unrelated `scheme` earlier
  on PATH than its Chez previously failed to configure.
