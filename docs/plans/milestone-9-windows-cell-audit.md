# The dry Windows-cell audit (Milestone 9 Slice ①)

**Every question the Windows amd64 Tier 1 cell would answer, written down before
it runs** (design §6 item 2). Written now, against `main`, so that whoever funds
CI after v0.1 turns the cell on against a baseline rather than a blank slate.

There is **no CI this milestone** (decision
[0041](../decisions/0041-tier-1-cells-under-a-stated-budget.md), §4.9 item 1): the
Windows cell is deferred past v0.1. The rows answerable from the tree are asserted
now by `byte-machine.unit.windows-audit.chez.{source,aot}`
(`test/common/windows-audit-tests.sps`); the two answerable only from a runner
are marked **deferred** and carry the prediction the runner will confirm.

| # | question | answer | how |
|---|---|---|---|
| 1 | `BYTE_MACHINE_EXPECT_OS` for the Windows build | `windows` | **asserted** — the harness maps machine-type `…nt` → `windows`; `ta6nt`/`a6nt` → `windows` |
| 2 | `BYTE_MACHINE_EXPECT_ARCH` for the Windows build | `amd64` | **asserted** — the harness maps `a6…` → `amd64` |
| 3 | the runtime discovery names | `scheme`, `chez`, `chezscheme` | **asserted** — `BYTE_MACHINE_CHEZ_CANDIDATE_NAMES` in `cmake/ByteMachineChez.cmake` |
| 4 | the discovery escape hatch | `-DBYTE_MACHINE_CHEZ_EXECUTABLE=<abs>` | **asserted** — documented in `README.org` |
| 5 | does the `ChezScheme10.4.1.exe` installer put one of the discovery names on `PATH`? | **prediction:** likely no; `-DBYTE_MACHINE_CHEZ_EXECUTABLE` is the expected fallback (design P4) | **deferred** — runner-only |
| 6 | the AOT object extension Chez emits on `ta6nt` | **prediction:** `.so` (Chez's `machine-type`-independent object suffix), to be confirmed | **deferred** — runner-only |

## Notes

- **The build needs no source build on Windows.** Chez v10.4.1 publishes
  `ChezScheme10.4.1.exe`, a prebuilt Visual-Studio Intel installer beside the
  source tarball (design P4), so the Windows cell installs a runtime rather than
  spending the ~12 minutes the Linux job spends building Chez, and needs no MSVC
  in CI.
- **The build layer has no platform branching** (design P1: sweeps for `WIN32`,
  `MSVC`, `UNIX`, `APPLE`, `CMAKE_SYSTEM_NAME` all return zero), so there is no
  Windows-specific CMake path to audit — only the two runner-only unknowns above.
- **Rows 5 and 6 have no v0.1 receiver.** With Slice ② struck (decision 0041),
  they are the standing open questions a post-v0.1 Windows cell answers first;
  Slice ④ records them in `§27:1700`'s portability matrix as "from audit,
  prediction stated, runner-unconfirmed".
