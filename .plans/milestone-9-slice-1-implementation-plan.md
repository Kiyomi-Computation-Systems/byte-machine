# Milestone 9 Slice ① — platform neutrality, and the cross-cell argument made total

**Status: implemented 2026-09-12. Green in both Chez modes (release suite 140 → 142).**

Slice ① of Milestone 9 (design §6), decisions
[0039](../.decisions/0039-cross-cell-equality-through-committed-goldens.md) and
[0041](../.decisions/0041-tier-1-cells-under-a-stated-budget.md). Everything here
costs zero runner minutes.

## What shipped

1. **The sixth determinism golden** (obligation 2, decision 0039). The HTTP
   fixture's canonical generated source — **196 682 bytes**, the largest machine
   in the tree — committed as `test/fixtures/generated-http.golden.sls` (`-text`
   via `.gitattributes`, so no checkout filter can touch it).
   `determinism-http-tests.sps` now compares the freshly emitted bytes against it
   byte-for-byte, exactly as the other five goldens are compared; the header's
   "committed-golden variant is DEFERRED … named for a hardening slice or M9" is
   discharged. Byte-identity within a process **plus** equality to the committed
   golden gives the cross-process / cross-lane / cross-cell leg of `§24.2` stage 7
   transitively — no cross-job artefact comparison is built. There are now **six
   determinism lane pairs**, all green.

2. **The dry Windows-cell audit** (design §6 item 2). Every question the Windows
   amd64 cell would answer, written down before it runs, in
   `.plans/milestone-9-windows-cell-audit.md`. The rows answerable from the
   tree are **asserted**, not narrated, by
   `byte-machine.unit.windows-audit.chez.{source,aot}`: the machine-type identity
   (`ta6nt`/`a6nt` → `windows`/`amd64`, already in the harness tables), the
   discovery names (`BYTE_MACHINE_CHEZ_CANDIDATE_NAMES scheme chez chezscheme`),
   and the `-DBYTE_MACHINE_CHEZ_EXECUTABLE` fallback (README). The two runner-only
   rows (the discovered `scheme.exe` path; the AOT object extension on `ta6nt`)
   carry a stated prediction and are **deferred past v0.1** with no CI (decision
   0041) — Slice ② would have filled them from a runner.

3. **The six cosmetic `/bin/true` strings** in `ByteMachineExpectExitSpec.cmake`
   (×5) and `ByteMachineTestingSpec.cmake` (×1) replaced with the neutral
   placeholder `placeholder-command`. Not a portability fix — P1 established none
   of the six is ever executed (they sit in registration-rejection and
   argument-forwarding cases, never run, never asserted) — a readability one, so
   the next reader's `/bin/` sweep does not reach P1's wrong "six Windows
   blockers" conclusion.

4. **Ledger update.** `§26:1677` moves to "MECHANISM COMPLETE (Slice ①): all six
   determinism lane pairs compare committed goldens … cross-CELL width is one
   cell (macOS arm64, local); the others deferred past v0.1 (decision 0041)".
   The `release-ledger` lane now also asserts the sixth golden file is committed.

## Exit (design §6)

- Six determinism lane pairs green in both modes — confirmed.
- The ledger's `§26:1677` row moved from `open`/"sixth missing" to "mechanism
  complete, one cell" — confirmed by the ledger lane.
- **`src/` diff empty** — confirmed (`git diff --stat main..HEAD -- src/` prints
  nothing; the work is all under `test/` and `docs/`).

## Notes

- **The golden is 196 682 bytes exactly**, matching the design's §3.3 P3
  measurement — produced by the shipped emitter (`render-machine`), the same
  procedure the other five goldens were produced by.
- **No mutation entry** — the golden is guarded by the determinism lane on every
  run (the opposite of a stale golden), and the audit lane's assertions are
  totality-free.
