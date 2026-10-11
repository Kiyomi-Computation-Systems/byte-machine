# Portability matrix and pinned runtime versions

Which platforms byte-machine targets, what runtime it is pinned to, and which
of those platforms have actually been exercised. Where a platform has not been
exercised it is marked **not verified**, never described as passing.

---

## 1. Pinned runtime

Chez Scheme **10.4.1 or newer**, the full system — not Petite (the ahead-of-time
lane needs `compile-program`, which Petite does not provide).

The pin is a **floor, not an equality**: it records the version this project has
actually verified. It is `BYTE_MACHINE_CHEZ_MINIMUM_VERSION` in
[`cmake/ByteMachineChez.cmake`](../cmake/ByteMachineChez.cmake), enforced by
`byte_machine_chez_classify` (a `too-old` verdict below the floor). Lowering it
needs evidence from a run on the older release; newer Chez versions are expected
to work, which is why the check is a floor and not an exact match. The build
requires CMake 3.26 or newer (see [`README.org`](../README.org)).

## 2. The coverage claim

This is a **coverage-based** portability claim, not a certification of every
OS/architecture pair. The required targets (**Tier 1**) cover each supported
operating-system family and both architectures; the remaining cross-product
cells (macOS amd64, Windows arm64, additional Chez versions) are **Tier 2**:
expected to work, not part of the claim.

## 3. Tier 1 status matrix

A Tier 1 cell is exercised in **both** source and ahead-of-time (AOT)
execution.

| Target        | Chez machine type | OS / arch      | Status                   | Evidence |
|---------------|-------------------|----------------|--------------------------|----------|
| macOS arm64   | `tarm64osx`       | `darwin/arm64` | **verified locally**     | The full suite, in both modes, is run on this platform before every change merges. |
| Linux amd64   | `ta6le`           | `linux/amd64`  | **not verified**         | An on-demand CI job is defined in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml); no run of it is part of this claim. |
| Windows amd64 | `ta6nt`           | `windows/amd64`| **not verified**         | No runner; dry audit only (section 7 below). |
| Linux arm64   | `tarm64le`        | `linux/arm64`  | **not verified**         | No runner. |

**Not verified means not run — not passing.** macOS arm64 is the one covered
cell; the other three are supported targets whose behaviour is predicted from
the build's design (no platform branching, section 7) but has not been
observed.

## 4. Machine type → OS / architecture

The harness does not guess the platform at configure time; it reads Chez's own
`(machine-type)` — the target the runtime was actually built for — and derives
OS and architecture from it. In
[`test/support/harness/byte-machine/test/harness.sls`](../test/support/harness/byte-machine/test/harness.sls),
`adapter-machine-type->architecture` and `adapter-machine-type->os` strip the
leading threaded-build `t`, match an architecture prefix from
`adapter-architecture-table`, then match an OS prefix on the remainder from
`adapter-os-table`. The four Tier 1 targets resolve as:

| Machine type | strip `t` | arch prefix → arch  | OS remainder → OS   | Result         |
|--------------|-----------|---------------------|---------------------|----------------|
| `tarm64osx`  | `arm64osx`| `arm64` → `arm64`   | `osx` → `darwin`    | `darwin/arm64` |
| `ta6le`      | `a6le`    | `a6` → `amd64`      | `le` → `linux`      | `linux/amd64`  |
| `ta6nt`      | `a6nt`    | `a6` → `amd64`      | `nt` → `windows`    | `windows/amd64`|
| `tarm64le`   | `arm64le` | `arm64` → `arm64`   | `le` → `linux`      | `linux/arm64`  |

A non-threaded Windows type (`a6nt`, no leading `t`) resolves to the same
`windows/amd64`.

## 5. Runtime discovery and the escape hatch

Chez's binary name is not portable — upstream installs `scheme`, Homebrew
installs `chez`, some distributions use `chezscheme`. Discovery tries
`BYTE_MACHINE_CHEZ_CANDIDATE_NAMES` = **`scheme chez chezscheme`** in that order
([`cmake/ByteMachineChez.cmake`](../cmake/ByteMachineChez.cmake)), probing and
classifying each in turn; rejection of one candidate is not fatal, and Petite is
rejected specifically. When discovery cannot find a usable runtime, point it at
one explicitly:

```
cmake --preset dev -DBYTE_MACHINE_CHEZ_EXECUTABLE=/absolute/path/to/scheme
```

## 6. Running on another cell

A run on a given cell can assert its own identity: set
`BYTE_MACHINE_EXPECT_OS` and `BYTE_MACHINE_EXPECT_ARCH` (the CI job sets
`linux` / `amd64`), and the harness self-test lanes require the OS and
architecture derived from `(machine-type)` (section 4) to equal them, so a run
on the wrong runtime cannot pass as the intended cell. When they are unset, those
lanes require only that both are identified (not `unknown`).

## 7. Windows: answered on paper, runner-unconfirmed

The Windows amd64 cell's questions have been answered by a **dry audit** against
the tree. The tree-answerable rows — OS `windows` and arch `amd64` from the
machine-type tables above, the discovery names, and the
`-DBYTE_MACHINE_CHEZ_EXECUTABLE` fallback — are asserted by
`byte-machine.unit.windows-audit.chez.{source,aot}`
([`test/common/windows-audit-tests.sps`](../test/common/windows-audit-tests.sps)).
The build layer has no platform branching (no `WIN32`, `MSVC`, `UNIX`, `APPLE`
or `CMAKE_SYSTEM_NAME` conditions), so the per-platform commands are the same
everywhere and there is no Windows-specific CMake path. Library search paths
reach Chez as a list — the test launchers take one `--library-root` flag per
directory and set `library-directories` from them — so no platform path
separator is involved. No source build is needed on Windows — Chez publishes a
prebuilt `ChezScheme10.4.1.exe` installer.

Two questions can be answered **only by a runner** and remain predictions until
a Windows cell runs:

| Question | Prediction | Status |
|----------|-----------|--------|
| Does the `ChezScheme10.4.1.exe` installer put a discovery name on `PATH`? | likely no; `-DBYTE_MACHINE_CHEZ_EXECUTABLE` is the expected fallback | **unconfirmed — no runner** |
| AOT object extension Chez emits on `ta6nt` | `.so` (Chez's machine-type-independent object suffix) | **unconfirmed — no runner** |

## 8. References

- [`cmake/ByteMachineChez.cmake`](../cmake/ByteMachineChez.cmake),
  [`README.org`](../README.org) (pin, discovery),
  [`test/support/harness/byte-machine/test/harness.sls`](../test/support/harness/byte-machine/test/harness.sls)
  (OS/arch derivation),
  [`test/common/windows-audit-tests.sps`](../test/common/windows-audit-tests.sps)
  (the tree-answerable Windows rows),
  [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) (the Linux amd64
  job).
