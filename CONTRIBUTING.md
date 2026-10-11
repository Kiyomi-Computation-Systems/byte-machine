# Contributing to byte-machine

Thanks for wanting to improve this. Two kinds of contribution get two levels
of ceremony. A **small fix** (a typo, a doc fix, a bug with a test that shows
it) needs only the checks below. **Larger work** should start as an issue, so
the design can be agreed before code is written. That includes anything that
changes the machine model, the verifier's rules, the emitted code or the
generated-runtime ABI, since those reach every user's generated parsers.

## Setup

You need Chez Scheme 10.4.1 or newer (the full system, not Petite) and CMake
3.26 or newer.

```sh
git clone https://github.com/Kiyomi-Computation-Systems/byte-machine.git
cd byte-machine
make doctor    # find Chez and report what was found
make test      # build, then run the everyday selection
```

`make help` lists every target. [docs/building.md](docs/building.md) covers
building, the test presets, benchmarks and the docs site in full.

## Before you open a pull request

- **`make test-all` passes.** It runs everything, including the mutation
  suite, which takes about five minutes and prints nothing until it finishes;
  `make test-mutation` runs it alone with live progress.
- **`make check-reference` passes** if you changed what a public library
  exports. [docs/reference.md](docs/reference.md) must document every export,
  and nothing else.
- **`make check-site` passes** if you changed anything in `docs/`. It needs a
  checkout of [chez-cmark-gfm](https://github.com/Kiyomi-Computation-Systems/chez-cmark-gfm)
  named with `CMARK_GFM_ROOT`.
- **`make check-akku` passes** if you changed `Akku.manifest`, `.akkuignore`,
  or added `.sls` files outside `src/`. It installs the package as an Akku
  dependency and fails unless exactly `src/`'s libraries are installed.
- **`CHANGELOG.md` has an entry** under `[Unreleased]` for any change a user
  of the library would notice. Write it for that user: what changed, and
  whether they must regenerate their parsers.

CI is a single Linux job. A maintainer starts it by adding the `ci` label to
your pull request, so run the checks above yourself first.

## Tests

Every change to behaviour comes with a test, written first. A test is
finished when you have watched it fail against the wrong code, not when it
passes against the right code.

Tests are R6RS programs under `test/`, run by CTest, and most run twice: once
from source and once compiled ahead of time. Run through `make`, the build is
reconfigured each time. If you run `ctest` directly after editing a library
and a lane fails with `PROVENANCE-ERROR`, the lane's record of its source
files is stale: run `cmake --preset dev` and try again.

A change to the emitted code shows up as a determinism failure against the
committed goldens in `test/fixtures/generated-*.golden.sls`. Update the
golden in the same commit, and say in the changelog that users must
regenerate.

### The mutation suite

The mutation suite breaks the library on purpose, one decision at a time, on
a copy of the source, and requires the test lane that owns the decision to
fail. A decision you add to `src/` gets a mutation in
`test/support/cmake/SchemeMutationSuite.cmake`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the schema guard reports a non-machine under the wrong code"
  FIND [[           (list (make-diagnostic 'invalid-shape #f "not a machine")))]]
  REPLACE [[           (list (make-diagnostic 'invalid-name #f "not a machine")))]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "a non-machine handed to verify-machine is invalid-shape: invalid-shape")
```

- `FILE` is the file to mutate. `FIND` is exact text in it, which must occur
  exactly `SITES` times (default 1), and `REPLACE` is what the mutant puts in
  its place. Anchor `FIND` on code, never on a comment.
- `SPEC` names the test lane that must catch the mutant. Only the tests in
  that lane's program count, so put the witnessing test there.
- `EXPECT_STATUS` is the exit status the lane must fail with: 1 when checks
  fail.
- `EXPECT_OUTPUT_MATCHES` is a CMake regex over the failing lane's output. A
  failing check prints `FAIL <group>.<case>: <check> -- <detail>`, so pin the
  end of the case name plus the check label. A pin that matches text printed
  on every failure, such as the summary line, proves nothing. CMake's `.`
  matches any character, so use `\\.` for a literal dot.
- Prefer a mutant that fails a comparison over one that raises: a raise shows
  where the mutant crashed, not which decision it broke.
- Raise `EXPECTED_MUTATIONS` near the top of the file by one for each
  mutation you add, and `EXPECTED_PASSES` for each new pass.
- `EXPECT_SURVIVES "<reason>"` declares a mutation that no test can catch. It
  is for decisions that genuinely cannot be observed, with the reason written
  out, never for getting the suite green.

## Code

- **R6RS only.** Libraries under `src/` import `(rnrs)` and each other, and
  generated code imports only `(rnrs)` and `(byte-machine runtime)`. Every
  library starts with `#!r6rs` and an SPDX licence line. Each library holds its
  own code: no `include`.
- **Pure core, effects at the edge.** Building, verifying, compiling and
  rendering a machine are pure functions of their inputs; `emit-machine` only
  writes the rendered bytes to the port it is given.
- **Keep the public surface narrow.** Five libraries are public;
  `src/byte-machine/private/` is not. If a test needs something internal, it
  imports the private library rather than widening a public export.
- **Comments document types, invariants and reasons.** Say what a value is and
  why the code is shaped the way it is, not the history of how it got there.
  That belongs in the commit message.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org): `feat:`,
  `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- Name branches by kind: `fix/<slug>`, `feat/<slug>`, `docs/<slug>`.
- Keep one concern per pull request. Pull requests are squash-merged.

## Licence

byte-machine is licensed under the BSD 3-Clause License (see
[LICENSE](LICENSE)). By contributing, you agree that your contribution is
licensed under the same terms.
