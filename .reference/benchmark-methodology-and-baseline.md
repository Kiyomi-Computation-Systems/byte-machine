# Benchmark methodology and baseline report

How byte-machine's compiled baselines are measured, what the committed baseline
records, and how a proposed optimization is judged against it.

Every figure below is quoted from the committed artefact and every method claim
from the runner source. The runner is
[`bench/runner/benchmark.sps`](../bench/runner/benchmark.sps); the artefact is
[`bench/fixtures/baseline-tarm64osx.sls`](../bench/fixtures/baseline-tarm64osx.sls).

**Timing here is a recorded snapshot, not a gate.** The benchmark records
compiled baselines; no CI lane runs it or fails on its numbers, because
wall-clock timing is too noisy to gate CI on. The deterministic
allocation properties that *are* asserted — among them no per-byte allocation
in the generated path — live separately in
[`test/common/allocation-audit-tests.sps`](../test/common/allocation-audit-tests.sps),
described under [Allocation audit](#allocation-audit) below.

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
product; the interpreter is the reference oracle, carries no performance
requirement, and its numbers are recorded for comparison only.

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
**9 rounds / 16000 iterations** (its `rounds`, `warmup`, `iterations-per-round`).
`BYTE_MACHINE_BENCH_EXECUTORS` is `both` (the default, and how the committed
artefact is always taken) or `generated`, which skips the interpreter — about
200× slower, so most of a run's wall clock — for quick before/after comparisons
of a generated-lane change. The setting is recorded in the artefact, so a
generated-only run cannot be mistaken for a baseline.

**Timer-resolution caveat.** Chez `real-time` is millisecond-granular, so every
median carries about one millisecond of quantisation, visible in the
`dispersion-ms` span. That span is a larger fraction of a smaller median, and a
rate computed over a median of a few milliseconds is mostly a measurement of the
clock. If a median is 0, `measure` substitutes `1/1000` s before dividing, so the
derived rate is a resolution ceiling, not a measured rate. Read the medians and
dispersions, not the rates, when judging whether a row resolves anything; the
[admission rule](#admission-rule) below states the threshold.

## Metric set

`required-metrics` in the artefact: `bytes-per-second`, `requests-per-second`,
`allocation-bytes-per-message`, `generated-source-size-bytes`,
`aot-object-size-bytes`, `generation-time-ms`, `median-ms-per-round`,
`dispersion-ms`. Recorded environment fields: `schema`, `harness-version`,
`runtime` (name/version/machine-type/os/architecture), `mode`, `executors`,
`compiler-options`, `warmup`, `rounds`, `iterations-per-round`,
`deterministic-seed`, `exact-command`.

`unavailable-metrics`, recorded with reasons rather than silently omitted:

| Metric | Reason recorded |
| --- | --- |
| `cpu-info` | not portably available from Chez Scheme |
| `gc-activity` | `sstats-bytes` gives total allocation; per-collection GC time is not recorded |

The **dense/sparse byte-dispatch microbenchmark families** are approximated by
existing workloads: `dense-byte-dispatch` reuses the many-headers bytes (many
byte-dispatch decisions), `sparse-byte-dispatch` reuses the fixed-body bytes (a
long counted run, few decisions).

## How to run

`BYTE_MACHINE_TEST_TMPDIR` names the directory the emitted generated library is
written to (default `/tmp`). `BYTE_MACHINE_BENCH_OUT` sets the artefact path (default: stdout). The
`exact-command` recorded in the artefact:

```
chez --script test/support/launchers/chez-source.ss \
  --library-root test/support/harness --library-root src \
  --object-guard build/dev/chez-object-guard \
  --program bench/runner/benchmark.sps
```

## Recorded baseline: macOS arm64 (`tarm64osx`)

Runtime: **chez 10.4.1**, machine-type **tarm64osx**, os **darwin**, architecture
**arm64**, run from source through the source launcher in `exact-command` (the
artefact's `mode` field reads `"unknown"` because `BYTE_MACHINE_EXECUTION_MODE`
was not set for the run), `executors both`, `compiler-options ()`,
`deterministic-seed 0` (the workloads are fixed byte sequences; no PRNG).
Harness version `1aea6b5aa6cd4448`.

**One-time metrics:**

| Metric | Value |
| --- | --- |
| `generated-source-size-bytes` | **129 379** |
| `aot-object-size-bytes` | **71 370** |
| `generation-time-ms` | **5** |

**Per-workload results** (generated executor, with the interpreter's bytes/sec
for comparison). The median and its `(min max)` dispersion are milliseconds per
round of 16000 iterations; rows with a median under 20 ms are not admissible
evidence for an optimization (see the [admission rule](#admission-rule)).

| Workload | Input B | Feed | Gen median ms (min–max) | Gen B/s | Gen req/s | Gen alloc B/msg | Interp B/s |
| --- | --- | --- | --- | --- | --- | --- | --- |
| short-normal-requests | 37 | whole | 6 (5–6) | 98,666,667 | 2,666,667 | 1,168 | 455,735 |
| many-small-headers | 678 | whole | 51 (50–52) | 212,705,882 | 313,725 | 1,168 | 454,062 |
| long-method-target-header-spans | 2027 | whole | 67 (66–67) | 484,059,701 | 238,806 | 1,168 | 2,031,317 |
| byte-at-a-time-fragmentation | 37 | byte | 32 (32–33) | 18,500,000 | 500,000 | 14,993 | 421,652 |
| fixed-length-bodies | 296 | whole | 8 (7–8) | 592,000,000 | 2,000,000 | 1,264 | 3,268,461 |
| chunked-bodies | 228 | whole | 17 (16–17) | 214,588,235 | 941,176 | 1,296 | 928,008 |
| pipelined-requests | 185 | whole | 17 (17–17) | 174,117,647 | 941,176 | 1,168 | 461,347 |
| early-error | 1 | whole | 3 (2–3) | 5,333,333 | 5,333,333 | 992 | 222,222 |
| late-error | 27 | whole | 5 (4–5) | 86,400,000 | 3,200,000 | 992 | 720,000 |
| dense-byte-dispatch | 678 | whole | 51 (50–52) | 212,705,882 | 313,725 | 1,168 | 455,034 |
| sparse-byte-dispatch | 296 | whole | 8 (7–8) | 592,000,000 | 2,000,000 | 1,264 | 3,213,026 |
| long-exact-sequence-matching | 740 | whole | 60 (59–60) | 197,333,333 | 266,667 | 1,168 | 455,700 |

The `Gen alloc B/msg` column is per-message constant overhead (parser
construction plus one feed and its result), **not** a per-byte cost — it is the
same 1,168 bytes for a 37-byte request and a 2027-byte one, and the same for one
header and thirty, which is what the allocation audit asserts. The
byte-at-a-time row is higher because it makes one feed call, and builds one
result, per input byte.

`requests-per-second` counts workload messages; `pipelined-requests` carries
five HTTP requests in one message.

<a id="allocation-audit"></a>
## Allocation audit

The generated per-byte path performs no deliberate list, vector, string or
result construction. This is asserted as a **slope, not a budget**: the same
machine is fed two valid requests differing only in one header value's length
(70 vs 40070 bytes, 40000 apart); allocation is differenced and divided by the
byte difference. The generated executor's slope is **0**: `alloc(short) =
alloc(long)`, to the byte.

Three properties make it an assertion rather than an observation:

- a **live control** in the same lane (a length-proportional `make-bytevector`
  loop) asserted **nonzero**, so a zero slope cannot be confused with an
  apparatus that cannot move;
- **both executors measured but only the generated one asserted** (the
  interpreter does allocate per byte, and carries no allocation requirement);
- **callbacks disabled** (`'()` bindings), with the zero slope also asserted
  with callbacks bound, and both per-message figures printed.

A slope sees only the dimension it varies, so the lane takes it in several:

- **per header** — two requests differing only in header count (1 vs 201);
  the generated slope is asserted zero, with its own live control;
- **per matched keyword byte** — the keyword-table walk
  (`byte-machine-keyword-step/v1`) is driven directly, and what one walk
  allocates must not depend on how much of a keyword it matched, how long a
  prefix it resumed with, or how long a prefix it parks; the emitted keyword
  arm around the walk is checked the same way;
- **per error offset** — a machine error's record and a callback failure's
  record must not grow with the offset they report.

Finally, the lane carries a **census of runtime ops**: it derives, from
`compile.sls`'s emitted text, every `(byte-machine runtime)` procedure
generated code can call, runs the audited inputs on a counting copy of each
machine, and fails, naming the op, for any derived op no audited input reaches.
So a lowering that starts calling a new runtime op fails the lane until the
audit gains an input that exercises it.

<a id="admission-rule"></a>
## Admission rule for optimizations

An optimization — transition tables, byte-class tables, trie specialization,
sequence unrolling, peephole passes, unsafe primitives, and the like — is
admitted only when it meets all six of these criteria: a reproducible compiled
benchmark showing repeatable **material improvement**; results in **both**
source and AOT lanes; no **significant regression** on another supported
platform; unchanged public and observable semantics; complete interpreter
equivalence; and a documented complexity cost. A single favorable
microbenchmark is insufficient.

The two thresholds are derived from the instrument's observed variance, not
chosen in advance:

1. **Admissible evidence.** A workload counts only when its generated-lane
   median is **at least 20 ms** per round. At and above that, the observed
   dispersion span stays within about 4% of the median; below it, the
   millisecond clock dominates. Raise `BYTE_MACHINE_BENCH_INNER` until a
   workload clears the floor, and do not quote one that does not.
2. **Material improvement** is at least **20%** on the median of at least
   **three** admissible workloads, with no admissible workload regressing.
3. **Significant regression** is **10%** on the median of any single
   admissible workload.

The thresholds are properties of the platform cell they were derived on
(`tarm64osx`, Chez 10.4.1); on another cell, repeat the dispersion measurement
and derive them again rather than importing these figures. In the committed
baseline above, five workloads are admissible: `many-small-headers`,
`long-method-target-header-spans`, `byte-at-a-time-fragmentation`,
`dense-byte-dispatch`, and `long-exact-sequence-matching`.

None of this gates CI: it defines how a reader comparing two artefacts decides,
not a lane that fails.

## Other runners

[`bench/runner/keyword-walk.sps`](../bench/runner/keyword-walk.sps) times and
weighs the keyword-table walk alone, against a prefix-copying reference walk,
and prints Chez's `time` report per (match length, walk). It takes single runs,
is not part of the baseline artefact, and gates nothing; the property it
illustrates — allocation flat in match length — is asserted by the allocation
audit. Run from the repository root:

```
chez --libdirs src --script bench/runner/keyword-walk.sps
```
