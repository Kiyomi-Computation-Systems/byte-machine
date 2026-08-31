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

## 2026-08-28 (Milestone 2) — the functional /v2 lands

Milestone 2 introduces `byte-machine-make-compiled-machine/v2` (decision 0012) to
carry `parser-finish!`'s EOF path as a unified `exec` with a `finish?` flag, per
item 4. The emitter emits `/v2`; the runtime keeps the `/v1` export so a stale v1
file fails the version check cleanly. This is the *functional* `/v2` item 4
reserved the version tag for. It is distinct from the benchmark-gated `feed-outcome`
`/v2` (Consequences / the Slice-B amendment above), which remains gated on §23
evidence, and from item 5's coded ABI-mismatch condition, which remains deferred.

## 2026-08-28 (Milestone 2) — item 5's manifest blocker discharged

Milestone 2 gives `runtime.sls` a dependency on `(byte-machine private
conditions)` so lifecycle misuse and the §11.1 invalid-slice contract raise coded
`&byte-machine-contract` conditions (decision 0013), factoring a shared conditions
manifest fragment and de-duplicating `CORE_ALL` to resolve the basename collision
item 5 flagged. Item 5's own deferral — the coded ABI-version-mismatch condition —
is thereby *unblocked* but not yet taken: the mismatch still raises
`assertion-violation` until a slice upgrades it.

## 2026-08-31 (Milestone 4) — the extension mechanism changes; the version tag stays

Milestone 4 Gate 0 (decision 0018, milestone-4-design.md §4.1) replaces item 4's
extension *mechanism*. The seam no longer "extends by a `/v2` constructor": it
extends by a growable quoted-vector payload behind **one** unversioned
`byte-machine-make-compiled-machine` whose first action is the
`(= abi-version current-abi-version)` check. Item 4's purpose is unchanged — a
self-documenting seam that grows without an arity break — and the version tag
this record reserved "for exactly that" is precisely what makes a growable
payload safe, so it stays load-bearing rather than being retired with the name.
`current-abi-version` goes 2 → 3. Slice ①a lands it.

**What this note does not reach.** The Consequences bullet reserving a
`feed-outcome` `/v2` under benchmark evidence (parent §23) is a *different
family*. `byte-machine-make-feed-outcome/v1` keeps its versioned name, that
reservation stays open and still gated on §23 evidence, and `bench/` still holds
only `.gitkeep`. A reader who takes 0018's rename as having retired it has read
one shared suffix as one decision.

Item 5's deferral of a coded `generated-runtime-abi-mismatch` condition is also
untouched: 0018 changes which procedure raises the mismatch, not the condition
kind (decision 0013 item 3).
