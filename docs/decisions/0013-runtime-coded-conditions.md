# 0013: The runtime takes coded conditions for lifecycle misuse

Date: 2026-08-28
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.3)

## Context

Parent §12.6/§9.4 require prohibited and lifecycle-misuse operations to "raise
API-contract conditions," §11.1 calls an invalid feed slice "an API-contract
condition," and the project asserts conditions by **code and who, never by rendered
text** (`conditions.sls` header). Today `runtime.sls` is condition-free — it raises
`assertion-violation` (e.g. the invalid-slice guard at runtime.sls:95) — because
decision 0010 item 5 deferred coded conditions in the runtime to avoid duplicating
`conditions.sls` in the `CORE_ALL` lane manifest. Milestone 2's lifecycle *is* the
runtime's public contract and introduces a whole family of misuse codes, so the
deferral's blocker is removed here.

## Decision

1. **`runtime.sls` imports `(byte-machine private conditions)`.** Lifecycle misuse
   (the prohibited operation-matrix cells of §12.2 — feed while paused, resume
   while ready, finish while paused, and so on) and the §11.1 invalid-slice
   contract raise `&byte-machine-contract` with a stable `code`/`who` the tests
   assert directly. One condition type keyed by `code`/`who` suffices (§9.4).
2. **The stored `CORE_ALL` manifest is de-duplicated.** Adding the import puts
   `conditions.sls` in both `BYTE_MACHINE_CORE_RUNTIME` and (via graph/ir)
   `BYTE_MACHINE_CORE_VERIFY`, which would collide as a duplicate basename inside
   `CORE_ALL`. A shared conditions manifest fragment is factored and the stored
   `CORE_ALL` value is de-duplicated before it is reused (before `CORE_EMIT` is
   set), so the per-lane `byte_machine_lane_duplicate_basenames` guard stays green.
   No dependency cycle is introduced: `conditions.sls` imports only `(rnrs)`.
3. **Item 5's coded ABI-mismatch condition is unblocked but not required by
   Milestone 2.** Decision 0010 item 5 deferred that condition for the same
   manifest reason. With the runtime->conditions dependency now present, that
   deferral's *blocker* is gone, so the ABI-version-mismatch `assertion-violation`
   *may* be upgraded to a coded condition — but Milestone 2 does not require it, and
   until a slice takes it, it stays `assertion-violation`. Slice ② decides.

## Consequences

- Slice ② adds the runtime lifecycle-state field and the misuse-condition family
  (plus the invalid-slice coded condition), with mutations that assert each code's
  failure signature (`EXPECT_OUTPUT_MATCHES` / `EXPECT_STATUS`), not a bare nonzero
  exit.
- The CMake manifest is restructured (a shared conditions fragment; `CORE_ALL`
  de-dup); `no-scheme` stays at 8/8 (no new `cmake.direct` lane is registered).
- Decision 0010 item 5's *manifest blocker* is discharged; item 5's ABI-mismatch
  condition itself remains deferred (only now unblocked).

## 2026-08-28 (Slice ②a) — as-implemented manifest de-dup

Item 2's "shared conditions manifest fragment" was realized without a separate
named fragment: `conditions.sls` is prepended directly to
`BYTE_MACHINE_CORE_RUNTIME` (before `runtime.sls`) and `BYTE_MACHINE_CORE_ALL`
is de-duplicated with `list(REMOVE_DUPLICATES ...)`. The outcome is identical —
`conditions.sls` reaches `CORE_ALL` once, load order stays conditions → ir →
graph → verify → runtime → interpret, and the per-lane duplicate-basename guard
stays green.
