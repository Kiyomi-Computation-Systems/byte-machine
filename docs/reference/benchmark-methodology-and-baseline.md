# Benchmark methodology and baseline report

How byte-machine's compiled baselines are measured, what the committed baseline
records, and why v0.1 records rather than gates.

This is `§27:1699` of
[the implementation plan](../plans/byte-machine-implementation-plan.md), the
write-up of the benchmark artefact shipped in Milestone 9 Slice ③. Every figure
below is quoted from the committed artefact and every method claim from the
runner source. The runner is
[`bench/runner/benchmark.sps`](../../bench/runner/benchmark.sps); the artefact is
[`bench/fixtures/baseline-tarm64osx.sls`](../../bench/fixtures/baseline-tarm64osx.sls).

**Timing here is a recorded snapshot, not a gate** (`§23.1`). v0.1 records
compiled baselines and runs no noisy CI performance gate; this runner is not a
gating lane. The one deterministic property that *is* asserted — no per-byte
allocation in the generated path — lives separately in
[`test/common/allocation-audit-tests.sps`](../../test/common/allocation-audit-tests.sps)
(decision 0040), described under [Allocation audit](#allocation-audit) below.

---

## What is measured, and how

The runner compiles the private HTTP fixture machine (`make-http-machine`) once
with `compile-machine`, then builds **two executors** from it:

- **generated** — the emitted parser: `emit-machine` writes a `.sls` to the temp
  dir, which is `load`ed and `eval`'d as the `httpreq` library;
- **interpreted** — `make-interpreted-machine` over `verify-machine`, the
  reference oracle.

Both executors run every workload, so each row carries a `generated` and an
`interpreted` sub-record. Only the generated numbers describe the shipped
product; the interpreted numbers are recorded for comparison (`§18` asks nothing
of the interpreter's performance).

**Timing method** (`measure` in the runner): one **warmup** round of `inner`
iterations is discarded; then `rounds` timed rounds each run `inner` iterations of
`run-once`, which builds a fresh parser and feeds one workload message — either
whole (one `parser-feed!`) or one byte per call (the fragmentation strategy). The
reported time is the **median** of the per-round milliseconds; **dispersion** is
recorded as `(min max)`, not a standard deviation. Throughputs derive from the
median (`requests-per-second` = `inner / median-seconds`, `bytes-per-second` =
`inner * input-size / median-seconds`). `allocation-bytes-per-message` is the
`sstats-bytes` delta across all rounds over `rounds * inner` — a **per-message**
figure, not the per-byte slope of the allocation audit.

Round and iteration counts come from `BYTE_MACHINE_BENCH_ROUNDS` (default 7) and
`BYTE_MACHINE_BENCH_INNER` (default 200); the committed artefact was recorded at
**5 rounds / 100 iterations** (its `rounds`, `warmup`, `iterations-per-round`).

**Timer-resolution caveat.** Chez `real-time` here is millisecond-granular, and
`measure` floors a zero median to `1/1000` s. Rows whose median rounds to 0 ms
therefore report `requests-per-second` **100000.0** and a `bytes-per-second`
derived from that floor — a resolution ceiling, not a measured rate. Use the
larger workloads (non-zero medians) for real throughput comparison.

## Metric set (`§23.1`)

`required-metrics` in the artefact: `bytes-per-second`, `requests-per-second`,
`allocation-bytes-per-message`, `generated-source-size-bytes`,
`aot-object-size-bytes`, `generation-time-ms`, `median-ms-per-round`,
`dispersion-ms`. Recorded environment fields: `schema`, `harness-version`,
`runtime` (name/version/machine-type/os/architecture), `mode`,
`compiler-options`, `deterministic-seed`, `exact-command`.

`unavailable-metrics`, recorded with reasons rather than silently omitted:

| Metric | Reason recorded |
| --- | --- |
| `cpu-info` | not portably available from Chez Scheme |
| `gc-activity` | `sstats-bytes` gives total allocation; per-collection GC time is not recorded in v0.1 |

The `§23.2` **dense/sparse byte-dispatch microbenchmark families** are
approximated by existing workloads: `dense-byte-dispatch` reuses the many-headers
bytes (many byte-dispatch decisions), `sparse-byte-dispatch` reuses the
fixed-body bytes (a long counted run, few decisions).

## How to run

`BYTE_MACHINE_TEST_TMPDIR` must be set (the emitted generated library is written
there). `BYTE_MACHINE_BENCH_OUT` sets the artefact path (default: stdout). The
`exact-command` recorded in the artefact:

```
chez --script test/support/launchers/chez-source.ss \
  --library-root test/support/harness --library-root src \
  --object-guard build/dev/chez-object-guard \
  --program bench/runner/benchmark.sps
```

## Recorded baseline: macOS arm64 (`tarm64osx`)

Runtime: **chez 10.4.1**, machine-type **tarm64osx**, os **darwin**, architecture
**arm64**, mode **source**, `compiler-options ()`, `deterministic-seed 0` (the
workloads are fixed byte sequences; no PRNG). Harness version `1aea6b5aa6cd4448`.

**One-time metrics:**

| Metric | Value |
| --- | --- |
| `generated-source-size-bytes` | **196 682** |
| `aot-object-size-bytes` | **138 416** |
| `generation-time-ms` | **8** |

**Per-workload throughput** (generated executor, with the interpreter's
bytes/sec for comparison). Rows at the 100000.0 req/s ceiling are timer-floored
(see the caveat above).

| Workload | Input B | Feed | Gen B/s | Gen req/s | Gen alloc B/msg | Interp B/s |
| --- | --- | --- | --- | --- | --- | --- |
| short-normal-requests | 37 | whole | 3,700,000 | 100,000 | 1,440 | 462,500 |
| many-small-headers | 678 | whole | 22,600,000 | 33,333 | 5,152 | 474,126 |
| long-method-target-header-spans | 2027 | whole | 40,540,000 | 20,000 | 1,440 | 2,111,458 |
| byte-at-a-time-fragmentation | 37 | byte | 3,700,000 | 100,000 | 14,720 | 462,500 |
| fixed-length-bodies | 296 | whole | 29,600,000 | 100,000 | 1,568 | 3,700,000 |
| chunked-bodies | 228 | whole | 22,800,000 | 100,000 | 2,368 | 991,304 |
| pipelined-requests | 185 | whole | 18,500,000 | 100,000 | 2,976 | 474,359 |
| early-error | 1 | whole | 100,000 | 100,000 | 896 | 100,000 |
| late-error | 27 | whole | 2,700,000 | 100,000 | 1,216 | 675,000 |
| dense-byte-dispatch | 678 | whole | 22,600,000 | 33,333 | 5,152 | 470,833 |
| sparse-byte-dispatch | 296 | whole | 29,600,000 | 100,000 | 1,568 | 3,288,889 |
| long-exact-sequence-matching | 740 | whole | 18,500,000 | 25,000 | 8,736 | 480,519 |

The `Gen alloc B/msg` column is per-message constant overhead (parser
construction plus one feed), **not** a per-byte cost — it stays flat as messages
grow, which is the point the allocation audit proves formally.

<a id="allocation-audit"></a>
## Allocation audit (decision 0040)

`§26:1680`'s prohibition — no deliberate list/vector/string/result construction
in generated per-byte paths — is asserted as a **slope, not a budget**. The same
machine is fed two valid requests differing only in one header value's length (44
vs 40044 bytes, 40000 apart); allocation is differenced and divided by the byte
difference. The recorded result for the generated executor is a per-byte slope of
**0.0**: `alloc(short) = alloc(long)`, to the byte.

Three properties make it an assertion rather than an observation (decision 0040):
a **live control** in the same lane (a length-proportional `make-bytevector` loop)
asserted **nonzero**, so a zero slope cannot be confused with an apparatus that
cannot move; **both executors measured but only the generated one gated** (the
interpreter does allocate per byte, and `§18` asks nothing of it); and
**callbacks disabled** (`'()` bindings), with the callback-bound figure recorded
beside it so the difference is visible.

## Admission rule (`§23.3`): record, do not optimize

v0.1 records baselines and attempts **no optimization** (`§26:1679`, "without
speculative optimization"). Transition tables, byte-class tables, trie
specialization, sequence unrolling, peephole passes, and unsafe primitives are
admitted only against the six `§23.3` criteria: a reproducible compiled benchmark
showing repeatable material improvement, results in **both** source and AOT lanes,
no significant regression on another supported platform cell, unchanged public and
observable semantics, complete interpreter equivalence, and documented complexity
cost.

Crucially: **do not set a percentage threshold until the baselines establish
normal variance**, and a single favorable microbenchmark is insufficient. Before
the first optimization is admitted, a decision record must derive "material
improvement" and "significant regression" from observed baseline variance. Until
then, the numbers above are a documented starting point — nothing here is a gate.
