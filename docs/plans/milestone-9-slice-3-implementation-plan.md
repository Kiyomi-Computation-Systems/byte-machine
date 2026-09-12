# Milestone 9 Slice ③ — the benchmark baseline and the allocation audit

**Status: implemented 2026-09-12. Green in both Chez modes (release suite 142 → 144).**

Slice ③ of Milestone 9 (design §8), decision
[0040](../decisions/0040-allocation-audit-is-a-slope-with-a-control.md). No `src/`
change and no optimisation (§26:1679 "without speculative optimization"; §23.3's
admission rule is not met for anything and is not pursued).

## What shipped

1. **The allocation audit** (`byte-machine.unit.allocation-audit.chez.{source,aot}`,
   decision 0040, §26:1680, §30 q5) — the **gated, deterministic** half. Feeds the
   generated and interpreted executors two no-body requests differing only in one
   header value's length (70 vs 40 070 bytes, design §3.3 P2's sizes), callbacks
   disabled (`'()` bindings), allocation measured with `(sstats-bytes
   (statistics))`:
   - **generated per-byte slope is zero** — `alloc(short) = alloc(long)` to the
     byte, asserted;
   - a **live control** (a length-proportional `make-bytevector` loop) asserted
     **nonzero**, so a zero slope is distinguishable from an apparatus that cannot
     move;
   - **both executors measured, only the generated one gated** — the interpreter's
     ~18 000 B/byte is recorded, not gated (§18 asks nothing of it);
   - **callbacks-disabled and callbacks-bound both recorded** (generated slope zero
     under each), the bound figure beside the disabled one.

2. **The benchmark runner and committed baseline** (§23.1, §23.2, §26:1679) —
   `bench/runner/benchmark.sps` produces `bench/fixtures/baseline-tarm64osx.sls`,
   the committed baseline artefact with every §23.1 field: schema, harness
   version, runtime (Chez version / machine-type / OS / arch), mode, compiler
   options, CPU (unavailable — noted), warmup, rounds, iterations, deterministic
   seed, the exact command, one-time metrics (generated source **196 682 B**, AOT
   object **138 416 B** via `compile-file`, generation time), the required-metrics
   list, the unavailable-metrics list with reasons, and the **twelve §23.2
   workloads** with canonical bytes and per-executor summaries (median, dispersion,
   bytes/s, requests/s, allocation/message). Recorded, **no perf gate** (§23.1);
   the runner is not a gating lane.

3. **Ledger updates.** `§26:1679` → `met` (the ledger lane reads the committed
   artefact and asserts its §23.1 field set and twelve workloads); `§26:1680` →
   `met` (the ledger lane asserts the allocation-audit lane is registered). The
   partition is now **8 met, 3 partly, 4 open**.

## Exit (design §8)

- `§26:1679` and `§26:1680` `met` — confirmed by the ledger lane.
- `§30` question 5 answered in a test (the allocation lane records which
  allocation metrics are collectable; the documentation half is Slice ④).
- **`src/` diff empty and no optimisation** — confirmed.

## Notes

- **Timing is recorded, not asserted.** §23.1 forbids a noisy CI perf gate, so the
  committed artefact is a snapshot; the ledger checks its *structure*, not its
  timing values, so it does not rot on re-measurement.
- **The AOT object size (138 416 B) is a real `compile-file` measurement**, close
  to the design's §3.3 P3 figure (138 195 B) — the small difference is expected
  between a scratch driver and the shipped runner.
- **Two §23.2 microbenchmark families are approximated**: "dense byte dispatch" by
  the many-small-headers workload and "sparse byte dispatch" by the fixed-body
  workload, since the HTTP fixture is the machine under test and has no standalone
  dispatch-density knob. The artefact names them so the approximation is visible.
