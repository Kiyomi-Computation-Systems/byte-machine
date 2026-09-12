# Portability matrix and pinned runtime versions

Which platforms byte-machine's release is gated on, what runtime it is pinned
to, and — for v0.1 — which of those gates ran and which are a recorded deferral.

This is `§27:1700` of
[the implementation plan](../plans/byte-machine-implementation-plan.md), for
byte-machine v0.1 (Milestone 9, the final milestone). It was checked against the
code and the decision record; where a cell was not exercised it is marked
deferred, never described as passing.

---

## 1. Pinned runtime

Chez Scheme **10.4.1 or newer**, the full system — not Petite (the ahead-of-time
lane needs `compile-program`, which Petite does not provide).

The pin is a **floor, not an equality**: it records the version this project has
actually verified. It is `BYTE_MACHINE_CHEZ_MINIMUM_VERSION` in
[`cmake/ByteMachineChez.cmake`](../../cmake/ByteMachineChez.cmake), enforced by
`byte_machine_chez_classify` (a `too-old` verdict below the floor). Lowering it
needs CI evidence from an older release; the Tier 2 matrix (`§7.3`) is why the
check is a floor and not an exact match. The build requires CMake 3.26 or newer
(see [`README.org`](../../README.org)).

## 2. The coverage claim

Per `§7.3`, this is a **coverage-based** portability claim, not a certification
of every OS/architecture pair. **Tier 1** covers each required operating-system
family and both architectures; **Tier 2** (macOS amd64, Windows arm64,
additional Chez versions) covers the remaining cross-product cells and does not
gate v0.1.

## 3. Tier 1 status matrix (v0.1)

Every Tier 1 cell is exercised in **both** source and ahead-of-time (AOT)
execution.

| Target        | Chez machine type | OS / arch      | v0.1 status              | Evidence |
|---------------|-------------------|----------------|--------------------------|----------|
| macOS arm64   | `tarm64osx`       | `darwin/arm64` | **verified locally**     | Every slice is measured on this platform locally; the release's one covered cell. |
| Linux amd64   | `ta6le`           | `linux/amd64`  | **deferred past v0.1**   | No CI (decision 0041); the cell that would discharge `#88`. |
| Windows amd64 | `ta6nt`           | `windows/amd64`| **deferred past v0.1**   | No CI (decision 0041); dry audit only (§7 below). |
| Linux arm64   | `tarm64le`        | `linux/arm64`  | **deferred past v0.1**   | No CI (decision 0041); runner label verified before relied on. |

**Deferred means not run — not passing.** No Tier 1 CI cell ran in Milestone 9.

## 4. The deferral is a recorded amendment, not a silent waiver

`§7.3:203` is firm: a Tier 1 cell made infeasible by an upstream toolchain or
runner "must be changed through an explicit update to this plan before release;
it cannot be silently waived in release notes."

[Decision 0041](../decisions/0041-tier-1-cells-under-a-stated-budget.md) honours
that clause rather than evading it. This is a **private** repository on billed CI
minutes, exhausted since 2026-09-07; the owner set this milestone's CI budget to
**zero**, making every Tier 1 cell unaffordable. Slice ② (Tier 1 CI) is struck
and the `§7.3:195` tier is amended for v0.1: macOS arm64 verified locally, the
other three deferred. Because Milestone 9 is the final milestone, this is not a
carry-forward — it is v0.1's **standing** platform disposition, recorded in the
parent plan and the release ledger, never only in `CHANGELOG.md`.

`#88` (the two-run Chez object-cache verification: cold build, then warm restore)
is **dispositioned, not waived** — it needs a runner this milestone will not pay
for. The ledger's `§26:1678` row moves `open` → `amended`, naming decision 0041
as its receiver.

**Ascending-cost order for whenever cells can be funded** (decision 0041):
Linux amd64 (discharges `#88`), Windows amd64 (×2, prebuilt runtime, no source
build), Linux arm64 (×1), macOS arm64 (×10). Each cell's first run is a single
priced `workflow_dispatch` before it joins the `push`/`ci`-label paths.

## 5. Machine type → OS / architecture

The harness does not guess the platform at configure time; it reads Chez's own
`(machine-type)` — the target the runtime was actually built for — and derives
OS and architecture from it. In
[`test/support/harness/byte-machine/test/harness.sls`](../../test/support/harness/byte-machine/test/harness.sls),
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

## 6. Runtime discovery and the escape hatch

Chez's binary name is not portable — upstream installs `scheme`, Homebrew
installs `chez`, some distributions use `chezscheme`. Discovery tries
`BYTE_MACHINE_CHEZ_CANDIDATE_NAMES` = **`scheme chez chezscheme`** in that order
([`cmake/ByteMachineChez.cmake`](../../cmake/ByteMachineChez.cmake)), probing and
classifying each in turn; rejection of one candidate is not fatal, and Petite is
rejected specifically. When discovery cannot find a usable runtime, point it at
one explicitly:

```
cmake --preset dev -DBYTE_MACHINE_CHEZ_EXECUTABLE=/absolute/path/to/scheme
```

## 7. Windows: answered on paper, runner-unconfirmed

With Slice ② struck, the Windows cell's questions were answered by a **dry
audit** ([`docs/plans/milestone-9-windows-cell-audit.md`](../plans/milestone-9-windows-cell-audit.md))
that costs zero CI minutes. The tree-answerable rows (OS `windows` and arch
`amd64` from the machine-type tables above; the discovery names; the
`-DBYTE_MACHINE_CHEZ_EXECUTABLE` fallback) are asserted now by
`byte-machine.unit.windows-audit.chez.{source,aot}`. The build layer has no
platform branching, and no source build is needed on Windows — Chez publishes a
prebuilt `ChezScheme10.4.1.exe` installer.

Two rows can be answered **only by a runner** and remain predictions until a
post-v0.1 Windows cell confirms them:

| Question | Prediction | Status |
|----------|-----------|--------|
| Does the `ChezScheme10.4.1.exe` installer put a discovery name on `PATH`? | likely no; `-DBYTE_MACHINE_CHEZ_EXECUTABLE` is the expected fallback | **unconfirmed — no CI runner** |
| AOT object extension Chez emits on `ta6nt` | `.so` (Chez's machine-type-independent object suffix) | **unconfirmed — no CI runner** |

These are the standing open questions a funded Windows cell answers first. The
audit is also where `§30` questions 2 and 3 (per-platform commands, Windows
library search paths) are answered on paper.

## 8. References

- `§7.3` (`:195`, `:203`) — tier definitions and the "no silent waiver" clause —
  and `§30` of [the implementation plan](../plans/byte-machine-implementation-plan.md).
- [Decision 0041](../decisions/0041-tier-1-cells-under-a-stated-budget.md) — the
  v0.1 amendment, ascending-cost order, `#88` disposition — and the
  [Windows-cell audit](../plans/milestone-9-windows-cell-audit.md).
- [`cmake/ByteMachineChez.cmake`](../../cmake/ByteMachineChez.cmake),
  [`README.org`](../../README.org) (pin, discovery),
  [`test/support/harness/byte-machine/test/harness.sls`](../../test/support/harness/byte-machine/test/harness.sls)
  (OS/arch derivation).
