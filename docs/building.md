# Building

This page is for working on byte-machine itself: running its tests,
measuring it, and building this documentation site. To *use* byte-machine you
need none of it; see [Installing](installing.md).

To contribute a change, read
[CONTRIBUTING.md](../CONTRIBUTING.md) first: it lists the checks a pull
request must pass and how to add a mutation.

## What you need

- Chez Scheme 10.4.1 or newer, the full system.
- CMake 3.26 or newer.
- `make`, for the shortcuts below. Without it (on Windows, say) use the CMake
  presets directly; every target is a thin wrapper over them.

## Make targets

`make` on its own lists every target:

| Target                 | What it does                                                        |
|:-----------------------|:--------------------------------------------------------------------|
| `make doctor`          | Find Chez and report what was found, then stop.                     |
| `make build`           | Configure and build the development preset.                         |
| `make dev`             | Build, then run the harness and build-layer self-tests.             |
| `make test`            | Build, then run the everyday test selection.                        |
| `make test-all`        | Build, then run everything, including the mutation suite.           |
| `make test-mutation`   | Run only the mutation suite, printing its progress as it goes.      |
| `make prod`            | Configure and build the release preset.                             |
| `make clean`           | Remove every build tree.                                            |
| `make site`            | Render this documentation into `build/site/`.                       |
| `make check-reference` | Check the API reference against the libraries' exports.             |
| `make check-site`      | Test the site generator, then check every page and link.            |

If Chez can't be found, point the build at it:

```sh
cmake --preset dev -DBYTE_MACHINE_CHEZ_EXECUTABLE=/absolute/path/to/scheme
```

Discovery tries the names `scheme`, `chez` and `chezscheme`, in that order,
and refuses Petite Chez.

## Without make

```sh
cmake --preset dev
cmake --build --preset dev
ctest --preset pr
```

The test presets are `harness` (the build layer's self-tests), `pr` (the
everyday selection) and `release` (everything). An empty selection is a
failure, never a silent pass.

## What the tests cover

Tests are R6RS programs under `test/`, run by CTest. Most run twice: once
from source, and once compiled ahead of time, so a difference between the
two modes can't hide. Among them:

- **Unit tests** for the builder, verifier, compiler and runtime.
- **Differential tests** that run the generated parser and the interpreter
  on the same inputs, under many feed schedules, and require them to agree.
- **A property suite** that generates many random machines from a fixed
  seed and compares the two implementations on each.
- **Determinism tests** that render machines twice and compare the bytes
  with committed copies.
- **An allocation audit** that measures what the generated parser allocates
  per input byte on its test machines, and requires zero.
- **A benchmark smoke test** that runs the command under
  [Benchmarks](#benchmarks) at one round of one iteration, checks the shape
  of what it writes, and checks that every copy of the command in these pages
  is the one the runner records.
- **The mutation suite**, which breaks the library on purpose, one decision
  at a time, on a copy of the source, and requires some test to fail each
  time. It takes about five minutes and runs as one CTest entry, so under
  plain `ctest` it is silent until it finishes; `make test-mutation` shows
  its progress.

## Benchmarks

The benchmark runner records throughput and allocation for an HTTP grammar,
on both the generated parser and the interpreter. It records numbers; it
doesn't pass or fail. After `make build`, from the repository root:

```sh
BYTE_MACHINE_TEST_TMPDIR=$(mktemp -d) \
chez --script test/support/launchers/chez-source.ss \
  --library-root test/support/harness --library-root src \
  --object-guard build/dev/chez-object-guard \
  --program ./bench/runner/benchmark.sps
```

Keep the `./`. The launcher empties Chez's `source-directories`, and
`load-program` looks a relative path up there unless it starts with `./` or
`../`, so a bare `bench/runner/benchmark.sps` is "not found in source
directories". An absolute path works too. The runner records this command in
its results as `exact-command`.

`BYTE_MACHINE_BENCH_ROUNDS` and `BYTE_MACHINE_BENCH_INNER` set the number of
rounds and iterations, and `BYTE_MACHINE_BENCH_OUT` writes the results to a
file. A committed baseline lives in `bench/fixtures/`.

## This site

The pages are the Markdown files in `docs/`. `docs/README.md` becomes the
home page, `index.html`. They are rendered with
[chez-cmark-gfm](https://github.com/Kiyomi-Computation-Systems/chez-cmark-gfm),
which is not a dependency of byte-machine: check it out somewhere and name it
with `CMARK_GFM_ROOT`. It needs the `cmark-gfm` shared library installed (for
example `brew install cmark-gfm`, or `apt-get install cmark-gfm`).

```sh
make site CMARK_GFM_ROOT=/path/to/chez-cmark-gfm
open build/site/index.html
```

`make check-site` runs the site generator's own tests, then renders every
page in memory and checks that:

- the sidebar lists exactly the files in `docs/`;
- every link between pages, and every `#anchor`, points at a real heading;
- no link to a `.md` file is left in the HTML;
- code blocks keep their exact spacing.

It runs `make check-reference` first. That one needs no chez-cmark-gfm: it
reads the export list of every library in `src/byte-machine/` and checks that
[API reference](reference.md) has exactly one entry for each binding, in the
right module, with a body. Add an export without documenting it, and it
fails.

Links from a page to a file outside `docs/` (such as
`../examples/words/`) become links to that file on GitHub, pinned to
`SITE_REF` (default `main`).

To add a page, create it in `docs/` and add it, with its sidebar label, to
the list in `site/pages.sls`. The order there is the sidebar's order.

### Publishing

`.github/workflows/pages.yml` builds the site and deploys it to GitHub Pages
whenever a `v*` tag is pushed, with links pinned to that tag. It can also be
run by hand from the Actions tab. It runs `make check-site` first, so a
broken link stops the deploy.
