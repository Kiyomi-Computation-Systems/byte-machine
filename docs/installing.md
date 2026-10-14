# Installing

There is nothing to compile. Install byte-machine with Akku, or put one folder
from this repository on Chez's library path, and then you can import.

## What you need

- **Chez Scheme 10.4.1 or newer**, the full system. Petite Chez can't compile
  programs ahead of time, so this repository's build turns it away.
- **This repository's `src/` folder.** It holds every library.
- **CMake 3.26 or newer**, only if you want to run byte-machine's own tests.
  See [Building](building.md).

macOS on arm64 is where byte-machine is developed and fully tested. Linux
(amd64 and arm64) and Windows (amd64) are supported targets, and nothing in
the code is platform-specific. Linux amd64 has a CI job that runs on every
push to `main` and on pull requests labelled `ci`; Linux arm64 and Windows
have none.

## 1. Get byte-machine

**With [Akku](https://akkuscm.org/)**, the R6RS package manager, run this in
your project's folder:

```sh
akku install byte-machine
```

That adds byte-machine to your project's `Akku.manifest`, creating one if
there is none. It pins the version in `Akku.lock` and puts the libraries in
`.akku/lib`. Run your program through `.akku/env`, which adds that folder to
Chez's library path:

```sh
.akku/env chez --program app.sps
```

Or run `. .akku/bin/activate` once to set it for the whole shell. With Akku you
can skip step 3.

**From the source:**

```sh
git clone https://github.com/Kiyomi-Computation-Systems/byte-machine.git
```

To use it from another project without Akku, a git submodule keeps the version
pinned:

```sh
git submodule add https://github.com/Kiyomi-Computation-Systems/byte-machine.git vendor/byte-machine
```

## 2. Know the libraries

Everything lives under `src/`. Five libraries are public:

| Library                    | What it does                                               | Needed at run time? |
|:---------------------------|:-----------------------------------------------------------|:-------------------:|
| `(byte-machine graph)`     | Build a machine out of nodes, edges and declarations.      | no                  |
| `(byte-machine verify)`    | Check a machine and report what is wrong with it.          | no                  |
| `(byte-machine compile)`   | Turn a checked machine into a generated library.           | no                  |
| `(byte-machine interpret)` | Run a checked machine directly, for testing.               | no                  |
| `(byte-machine runtime)`   | Make parsers and feed them. Generated code imports it.     | **yes**             |

`src/byte-machine/private/` holds libraries the public ones use. Don't import
them; they can change without notice.

## 3. Put `src/` on the library path

Pick one of three ways. Paths below are relative to the repository root; from
anywhere else, use absolute paths. Separate several folders with `:` on macOS
and Linux, and `;` on Windows.

**On the command line:**

```sh
chez --libdirs src --program app.sps
```

**In the environment.** Chez reads `CHEZSCHEMELIBDIRS` when it starts:

```sh
export CHEZSCHEMELIBDIRS=/path/to/byte-machine/src
chez --program app.sps
```

**From Scheme.** A program's imports are resolved before its first line runs,
so set the path in a small launcher and load your program from it:

```scheme
;; run.ss -- start with: chez --script run.ss
(library-directories (list "src"))
(load-program "app.sps")
```

## 4. Check it works

From the repository root:

```sh
echo '(import (byte-machine graph) (byte-machine runtime)) (display "ok") (newline)' \
  | chez -q --libdirs src
```

It prints `ok`. Then run the example the rest of these pages use:

```sh
cd examples/words
chez --libdirs ../../src:. --program generate.sps
chez --libdirs ../../src:. --program run.sps
```

## What to ship

You build a machine and generate its parser at build time. At run time, the
generated library imports `(rnrs)` and `(byte-machine runtime)` and nothing
else. So an application ships:

- the generated `.sls` file, and
- three files from `src/byte-machine/`: `runtime.sls`,
  `private/conditions.sls` and `private/names.sls`, kept in that layout.

The builder, verifier, interpreter and code generator stay behind.

## Other R6RS Schemes

Every library under `src/byte-machine/` imports only `(rnrs)` and its own
siblings, and so does a generated parser. Only this repository's build and
test layer is Chez-specific.

Checked by hand, not in CI: the libraries run unchanged on Guile 3.0.11 and
Racket 9.3, and on both the generated library is byte-for-byte the same as
Chez's. Racket loads a generated library only once `#!r6rs` is added as its
first line; the generator doesn't write it.

```sh
guile --r6rs -L src your-program.scm
plt-r6rs ++path src your-program.sps
```

You can also generate on Chez and run only the generated parser and the
runtime elsewhere.
