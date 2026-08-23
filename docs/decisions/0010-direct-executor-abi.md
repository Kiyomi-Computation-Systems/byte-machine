# 0010: The generated-code ABI is a direct executor, not an op closure

Date: 2026-08-23
Status: accepted
Milestone: 1, Phase 3 Slice A

## Context

Milestone 1's design (§6) deferred the generated-code ABI to Phase 3. The Phase 2
runtime header claimed the interpreter "and, later, generated code both produce a
compiled-machine whose `op` closure answers the messages make-parser drives, so the
two executors are identical by construction." Parent §19 requires the opposite: a
direct resumable executor over stable numeric state ids, not a generic opcode VM.
"Identical by construction" is also the lack of independence that would blind the
interpreter≡generated differential (parent §18, §22.4) to lowering defects.

## Decision

1. Generated code is a **direct executor**: a `feed` procedure that owns the
   dispatch loop (a `case` over numeric state ids, byte test inline, cursor and
   offset in locals) and returns one outcome per feed call.
2. `(byte-machine runtime)` gains `byte-machine-make-compiled-machine/v1` (carrying
   the ABI version, the IR fingerprint, the entry state, and `feed`) and
   `byte-machine-make-feed-outcome/v1` (a named result record: status, next, error,
   next-state, offset). `parser-feed!` dispatches on the compiled-machine variant:
   the interpreter keeps its `op` path unchanged; generated code takes the `feed`
   path. The runtime commits resume state and builds the `parser-result`.
3. The Phase 2 "identical by construction / shared executor" comment is corrected
   in place (it was an instruction, not a record — AGENTS.md).
4. The runtime↔generated seam carries the named `feed-outcome` record (not a
   positional value tuple), so the ABI is self-documenting and extends by a `/v2`
   constructor rather than an arity break.
5. In Slice A an ABI-version mismatch raises `assertion-violation`; a coded
   `generated-runtime-abi-mismatch` condition (parent §9.4) is deferred to avoid a
   runtime→conditions dependency that would duplicate `conditions.sls` in the
   `CORE_ALL` lane manifest.

## Consequences

- The emitter (`(byte-machine compile)`) renders `feed` as direct Scheme and
  constructs the binding via `byte-machine-make-compiled-machine/v1`.
- The interpreter is untouched, preserving the §18 independence the differential
  relies on.
- Slice B may revisit the `feed-outcome` seam under a `/v2` ABI if benchmark
  evidence ever calls for it (parent §23); the version tag exists for exactly that.

## 2026-08-23 (Slice B) — drift guard shipped without /v2

Slice B implements the member-2 runtime-export drift guard
(reserved-drift-tests.sps: `environment-symbols` of `(byte-machine runtime)`
asserted equal to `compile.sls`'s exported `reserved-member-2`, witnessed by a
mutation that drops an entry). It ships **no `/v2` export**: the guard is made
load-bearing by that mutation, not by the arrival of a new export, so item 5's
`/v2` remains gated on benchmark evidence exactly as written above.
