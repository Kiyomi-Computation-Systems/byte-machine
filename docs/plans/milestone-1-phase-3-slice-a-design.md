# Milestone 1 Phase 3 Slice A Design — Emitter and the Interpreter≡Generated Differential

Status: design — approved shape, pending implementation plan. Authored 2026-08-23,
after Phase 2 (semantic core) closed on `main` (PR #14, `59a6f85`).

Governing documents: [milestone-1-design.md](./milestone-1-design.md) §6 ("Phase 3 —
Generation") and §8 ("Handed to writing-plans"); parent
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md) §9.2
(emission API), §9.5 (runtime ABI), §9.6 (end-to-end example), §17 (normalizer),
§18 (reference interpreter as oracle), §19 (portable direct-code backend), §20
(deterministic emission and the IR fingerprint), §22.4 (differential comparison).
Decisions [0005](../decisions/0005-chez-only.md), [0006](../decisions/0006-inline-libraries.md),
[0008](../decisions/0008-emitter-emits-importable-library.md),
[0009](../decisions/0009-content-and-ir-fingerprints.md).

This document does not change Phase 3's *scope*; it resolves the design calls
milestone-1-design.md §6/§8 left open — the generated-code ABI shape and the
module layout — and cuts Phase 3 at its first pre-committed slice boundary.

## 1. Summary

Phase 3 turns the Phase 2 semantic core into a code generator. It is delivered in
the two slices milestone-1-design.md §8 pre-committed. **This document specifies
Slice A**: the normalizer, the emitter, the generated-code runtime ABI, the §9.6
end-to-end example, and the interpreter≡generated differential across all 256 byte
values. **Slice B** — D6 cross-cell/cross-process determinism hardening, D7
exhaustive identifier proofs, the property-based machine generator, and deletion of
the M0 placeholder libraries — gets its own design and plan after Slice A lands.

Two design calls the milestone design left open are resolved here:

- **The generated-code ABI is a direct executor, not an `op` closure** (§3.2).
  Generated code owns its dispatch loop; the runtime drives it through a new
  versioned constructor. This honours parent §19 ("direct resumable executor … not
  a generic opcode VM") and is what gives the differential test discriminating
  power: the interpreter walks the source IR by name, generated code runs lowered
  numeric-state code, so the two are genuinely independent implementations.
- **The runtime↔generated seam carries a named outcome record** (§3.3), not a
  positional value tuple, so the ABI is self-documenting and extends to `/v2` by
  adding a constructor rather than breaking an arity.

## 2. Scope

**In Slice A.**

- **Normalizer** — verified source IR → canonical normalized private IR in
  deterministic order, with the **IR fingerprint** (64-bit FNV-1a, decision 0009)
  computed over its canonical encoding.
- **Emitter** — `(byte-machine compile)` exporting `compile-machine`,
  `compilation-ok?`, `compilation-diagnostics`, `render-machine`, `emit-machine`
  (parent §9.2). Emits a complete importable `.sls` (decision 0008) to the supplied
  binary output port only (parent §20).
- **Runtime ABI** — `byte-machine-make-compiled-machine/v1`,
  `byte-machine-make-feed-outcome/v1`, embedded-version handling, the portable
  ABI-mismatch condition, and `parser-feed!` variant dispatch (§3.2, §3.3).
- **Generated-name safety** — extend the reserved-output-binding check to members 2
  (runtime exports) and 3 (emitter-template top-level identifiers), which come into
  existence in this slice (milestone-1-design.md §3.3).
- **The §9.6 end-to-end example** — one executable Chez program, run in both the
  `chez.source` and `chez.aot` lanes.
- **Interpreter≡generated differential** — all 256 byte values through the fixed
  one-byte machine.

**Deferred to Slice B** (own design + plan): the D6 determinism *hardening* checklist
(repeat across processes, byte-for-byte across cells — parent §22.9); the D7
identifier-repertoire and binary-LF *proofs* beyond what emitter construction needs;
the property-based machine generator and the `property` preset wiring; deletion of
`placeholder.sls` / `placeholder-consumer.sls`.

> Slice A still produces deterministic output and validates the identifier grammar —
> it must, to emit at all. What Slice B adds is the *exhaustive adversarial proof*
> of those properties. Slice A embeds the IR fingerprint and proves determinism
> within a single process; Slice B proves byte-identity across processes and cells.

**Out of Milestone 1 entirely** (milestone-1-design.md §7): EOF *execution*
(`parser-finish!`, EOF edges) — Milestone 2; byte classes, sequences, fields,
callbacks, spans, counted consumption — Milestones 3–6; the real Windows
CRLF-translation proof — Milestone 9; `define-machine` sugar, trie/transition-table
specialization, a serialized IR format, a general CLI — parent §29 deferrals.

## 3. Architecture

### 3.1 Module layout and dependency direction

```
src/byte-machine/private/normal-ir.sls   NEW  normalized IR + normalizer + IR fingerprint (FNV-1a)
src/byte-machine/compile.sls             NEW  (byte-machine compile): compile-machine, render-machine,
                                              emit-machine, reserved-binding set, canonical writer, template
src/byte-machine/runtime.sls             MOD  + /v1 constructors, ABI-mismatch condition, parser-feed! variant dispatch
src/byte-machine/interpret.sls           unchanged — stays the independent IR-walk oracle (parent §18)
```

Dependency direction (parent §7.2): `private conditions ← private ir ← private
normal-ir`; `(byte-machine compile)` depends on `verify` (it re-verifies internally,
§9.2), `private ir`, `private normal-ir`, and `private conditions`. **`compile` does
not depend on `runtime`** — it emits *text* that imports `(byte-machine runtime)`; it
never calls the runtime itself. The interpreter is untouched, preserving the §18
independence the differential relies on.

### 3.2 The generated-code ABI — a direct executor

Today `(byte-machine runtime)` exports `make-compiled-machine`, which wraps an `op`
message closure that `parser-feed!` drives; the interpreter closes such an `op` over
the source IR ([interpret.sls](../../src/byte-machine/interpret.sls)). The
[runtime.sls](../../src/byte-machine/runtime.sls) header claims generated code will
"produce a compiled-machine whose `op` closure answers the messages make-parser
drives, so the two executors are identical by construction." That claim is **retired
here**: it describes the generic opcode VM parent §19 forbids, and "identical by
construction" is precisely the lack of independence that would blind the differential
test to lowering defects. The header comment is corrected in place (an instruction,
not a record — AGENTS.md) as part of Slice A, and the change is recorded in a new
decision record (§6).

The new ABI:

```scheme
;; Exported from (byte-machine runtime). Both are called by generated code,
;; so both are reserved-output-binding members (§3.5, member 2).
(byte-machine-make-compiled-machine/v1 abi-version ir-fingerprint entry-state feed)
  → compiled-machine
;;   abi-version : fixnum — must equal the runtime's supported ABI version,
;;                 else the portable ABI-mismatch condition is raised at construction
;;   ir-fingerprint : the embedded 64-bit IR fingerprint (carried for provenance,
;;                    not executed)
;;   entry-state : the numeric state id feed resumes from on the first call
;;   feed : the resumable executor procedure (below)

(feed state offset bv start end) → feed-outcome
;;   state  : numeric state id to resume from
;;   offset : cumulative stream-offset so far
;;   bv/start/end : the slice to process
;;   Generated code runs the whole dispatch loop in locals and returns exactly one
;;   feed-outcome, committing nothing to the parser itself (parent §19: state in
;;   local variables, committed at observable boundaries — the runtime does the commit).
```

The interpreter keeps producing an `op`-variant compiled-machine unchanged; the two
variants coexist behind the single `compiled-machine?` type and the single
`make-parser` / `parser-feed!` user API.

### 3.3 The runtime↔generated seam — a named outcome record

`feed` returns a runtime-owned outcome record rather than multiple values, chosen for
a self-documenting, `/v2`-extensible contract:

```scheme
(byte-machine-make-feed-outcome/v1 status next error next-state offset) → feed-outcome
;;   status    : symbol ∈ {stopped, error, need-input}
;;   next      : fixnum — absolute index into the fed slice where execution paused/stopped
;;   error     : an error-code symbol, or #f
;;   next-state : numeric state id to resume from (irrelevant when the outcome is sticky)
;;   offset    : the new cumulative stream-offset
```

`feed-outcome` accessors stay **private to `(byte-machine runtime)`**; only the
constructor is exported (generated code builds an outcome, the runtime reads it).
`parser-feed!` branches once on the compiled-machine variant:

- **`op` (interpreter):** the existing loop ([runtime.sls:60](../../src/byte-machine/runtime.sls)), unchanged.
- **`v1` (generated):** call `(feed current-state offset bv start end)`, read the
  outcome, persist `next-state` and `offset` onto the parser, derive
  `consumed = next − start`, and build the `parser-result` (sticky for `stopped` /
  `error`, per today's rules). `make-parser` seeds the parser's initial state from the
  machine's `entry-state`.

The `parser-result` shape stays the single source of truth in the runtime; generated
code never constructs one. The one extra ~56-byte transient per `feed` call (not per
byte) is immediately destructured and discarded — negligible, and by parent §23 /
§2-decision-10 not a basis for a design change absent benchmark evidence.

### 3.4 Normalizer, normalized IR, and the IR fingerprint

The normalizer runs *after* verification and is deterministic (parent §17). For the
M1 node repertoire (byte-dispatch, stop, error) it: resolves symbolic node names to
**stable numeric state ids** in a declaration-derived deterministic order; lowers each
dispatch node's (verified non-overlapping) cases into a byte test against numeric
targets and modes; carries the fallback edge; and resolves each error node's symbolic
error name to its **error code** (the value `parser-result-error` surfaces). It performs
no speculative optimization (§17): the simplest correct graph.

The **IR fingerprint** is 64-bit FNV-1a over a canonical byte encoding of the
normalized IR plus emission options (empty in v0.1). Slice A defines that encoding
and embeds the fingerprint in emitted output; Slice B proves byte-identity of the
whole emission across processes and cells. The encoding must not depend on hash
iteration, object identity, gensym, or implementation `write` (parent §20). It is the
**IR fingerprint** at every site, never a bare "fingerprint" (decision 0009); it must
not touch the shipped content-fingerprint library `(byte-machine test fingerprint)`.

### 3.5 Emitter, reserved-binding set, and generated library shape

`(byte-machine compile)` follows parent §9.2 exactly:

```scheme
(compile-machine machine options)      → compilation      ; takes a MACHINE, re-verifies internally;
                                                          ; v0.1 accepts only '() options
(compilation-ok? compilation)          → boolean
(compilation-diagnostics compilation)  → list of diagnostics
(render-machine compilation binding)   → bytevector        ; pure; the complete canonical source
(emit-machine compilation binding port) → emission-metadata ; writes render's bytevector to the
                                                            ; supplied BINARY port via put-u8 only
```

`compile-machine` taking a machine (and re-verifying) rather than a verification is
the deliberate §9.2 asymmetry with `make-interpreted-machine`: no caller can pair a
verification of one machine with a different machine. `emission-metadata` carries the
IR fingerprint and the byte count.

**The binding is caller-supplied; the library name is derived.** Parent §9.2 fixes
`render-machine`/`emit-machine` at `(compilation binding)` — the `binding` symbol is
the caller's only naming control, and decision 0008 §4 says a *custom* public library
name comes from a hand-written re-export wrapper, not from a render-time argument. So
the emitter owns the library name by a fixed deterministic convention:
`(generated <machine-name>)` (the machine name is already verified against
`[a-z][a-z0-9-]*`). `render-machine` / `emit-machine` validate the `binding` against
that grammar and the reserved-output-binding set *before* writing any bytes, raising an
`invalid-output-binding` API-contract condition on failure. (An earlier draft of this
section made the library name caller-supplied; that contradicted §9.2's arity and
0008 §4 and is corrected here.)

The **reserved-output-binding set** now spans all three members (milestone-1-design.md
§3.3): member 1 — R6RS source-mode identifiers (already checked in Phase 2); member 2
— every `(byte-machine runtime)` export, including the two `/v1` constructors; member 3
— the generated library's own top-level template identifiers (e.g. `feed`). The set is
owned next to the emitter template and deterministically ordered. A test computes
member 2 from the runtime's actual export list and asserts it against the declared set,
so the two cannot silently drift (parent §9.2).

The emitted `.sls` for the one-byte machine is direct code — numeric-state `case`,
inline byte test, loop in `let` locals, plain R6RS (decision 0005 default; no fixnum
or unsafe ops without benchmark evidence):

```scheme
(library (generated <machine-name>)
  (export <binding>)
  (import (rnrs) (byte-machine runtime))
  (define (feed state offset bv start end)
    (let loop ((pos start) (st state) (off offset))
      (case st
        ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
        ((2) (byte-machine-make-feed-outcome/v1 'error pos 'unexpected-byte 2 off))
        (else                                   ; st = 0 : the dispatch node
         (if (>= pos end)
             (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off)
             (let ((b (bytevector-u8-ref bv pos)))
               (if (= b 0)
                   (loop (+ pos 1) 1 (+ off 1)) ; byte 0 → advance to stop
                   (loop pos 2 off))))))))       ; fallback → reexecute to error
  (define <binding>
    (byte-machine-make-compiled-machine/v1 <abi-version> <ir-fingerprint> 0 feed)))
```

This is structurally distinct from the interpreter's name-keyed IR walk, which is the
point: a lowering bug (wrong state numbering, wrong mode, wrong error code) diverges
from the oracle and the all-256 differential catches it.

## 4. Testing strategy

**The five lanes (parent §22.1).** A semantic is complete only when it passes through
(1) source-IR construction+verification, (2) independent interpretation, (3) emission,
(4) generated-parser execution, (5) interpreter/generated differential. Slice A
exercises all five for the one-byte machine.

**Differential (the Slice A core).** For the fixed one-byte machine, build
`cm-ref = (make-interpreted-machine (verify-machine m))` and `cm-gen` by emitting the
library, importing it, and taking its exported compiled-machine. Feed each byte
`0..255` as a one-byte slice through `make-parser` / `parser-feed!` against both, and
assert equal `parser-result-status`, `-next`, `-consumed`, `-stream-offset`, and
`-error`. The internal state id is executor-local and is **not** compared across
executor kinds (parent §12.7). The property-based generator over arbitrary M1-shaped
machines is Slice B; Slice A uses the fixed proving machine only.

**§9.6 end-to-end example.** One documented executable program: construct the machine
only through `(byte-machine graph)`; verify; `compile-machine`; `emit-machine` to a
binary file port; a consumer `(import`s the generated library and only
`(byte-machine runtime)`, constructs a parser, feeds the exact `[0,1)` slice, and
inspects the result. Run in both the `chez.source` and `chez.aot` lanes. Tool commands
are copied verbatim from Milestone 0; there is no include-path setup.

**Generated files and the fingerprint manifest.** The emitted `.sls` is a *test-time
artifact*, written by the test's imperative shell into a temporary library root the
launcher is pointed at (launchers set `(source-directories '())` and take absolute
roots — decision 0006). It is therefore **excluded** from every lane's `SOURCES`
manifest and from the per-lane basename-uniqueness check: the manifest fingerprints
the emitter and the test program, not the emitter's output. This must be stated
explicitly so a generated file is never mistaken for un-fingerprinted repository
Scheme.

**Lane registration.** Each new library gets both a `.chez.source` and a `.chez.aot`
lane via `byte_machine_add_scheme_lane` (parent §22.2 harness; established by Phase 2).
A new cumulative core manifest fragment extends `BYTE_MACHINE_CORE_ALL` with
`private/normal-ir.sls` and `compile.sls`. The differential and end-to-end lanes carry
the already-reserved `differential` label.

**Mutation discipline (milestone-1-design.md §8, AGENTS.md).** Every decision in the
new code gets a mutation an owning spec notices, asserting a *measured* failure
signature (`EXPECT_STATUS` + `EXPECT_OUTPUT_MATCHES`), never a bare nonzero exit.
Adding the `/v1` route and the ABI-mismatch exit is a new exit path, so the **whole**
mutation suite is re-run and each affected pass's baseline/mutant re-checked (AGENTS.md
— a new exit can silently disarm an existing mutation). `no-scheme` stays green at 8/8;
no new dependencies. Declared totals and their arithmetic comments move in the same
commit as the passes they cover; live totals (`EXPECTED_PASSES=34`,
`EXPECTED_MUTATIONS=87`) are re-read from the suite before bumping, never quoted from a
plan.

## 5. Task breakdown (each TDD, failing test first)

1. **Normalizer + normalized IR + IR fingerprint** (`private/normal-ir.sls`) —
   deterministic numeric state ids; canonical encoding; FNV-1a fingerprint. Witnessed
   by a spec that fails if ordering, encoding, or the fingerprint changes.
2. **Runtime ABI** — `byte-machine-make-compiled-machine/v1`,
   `byte-machine-make-feed-outcome/v1`, the ABI-mismatch condition, `parser-feed!`
   variant dispatch; correct the [runtime.sls](../../src/byte-machine/runtime.sls)
   "identical by construction" header comment. Re-run the whole mutation suite.
3. **Emitter** (`compile.sls`) — `compile-machine` / `render-machine` /
   `emit-machine`; reserved-binding set (members 1–3) with the runtime-export drift
   test; binding + library-name validation; canonical source writer; the template.
4. **End-to-end example + all-256 differential** — the §9.6 program and the
   differential, each in `chez.source` and `chez.aot`; new lanes under the
   `differential` label.
5. **Close-out** — the ABI decision record (§6); extend the reserved-binding scoping
   note into Slice A; CHANGELOG entry; re-measure `release` / `no-scheme` / both
   mutation suites against the shipped artifact and record the numbers.

## 6. Decisions to record

- **Direct-executor ABI** (new decision record, next free number after 0009): the
  generated-code ABI is a direct resumable executor driven through
  `byte-machine-make-compiled-machine/v1` with the `feed-outcome` seam, not an `op`
  closure; the [runtime.sls](../../src/byte-machine/runtime.sls) "identical by
  construction / shared executor" comment is corrected; parent §19 is cited as the
  authority. Records the C outcome-record seam and its rationale (self-documenting,
  `/v2`-extensible).
- **Reserved-binding scoping note** (milestone-1-design.md §3.3): amended to record
  that members 2 and 3 are now in force, enumerated next to the template, and covered
  by the runtime-export drift test.

**2026-08-23 reconciliation.** Slice A is closed (Task 5). [Decision
0010](../decisions/0010-direct-executor-abi.md) is written, recording the
direct-executor ABI and the retirement of the "identical by construction"
runtime header comment described above.

§3.2 above says an ABI-version mismatch raises "the portable ABI-mismatch
condition"; annotated rather than reworded, because what shipped differs and
this record stays as the design intent, not a description of the artifact.
Slice A ships `assertion-violation` instead (decision 0010, item 5): a coded
`generated-runtime-abi-mismatch` condition (parent §9.4) is deferred to avoid
a runtime→conditions dependency that would duplicate `conditions.sls` in the
`CORE_ALL` lane manifest. `(byte-machine runtime)` has no import of
`(byte-machine conditions)` today; adding one only for this one condition
type was judged not worth the manifest duplication for a Slice A that has no
caller distinguishing an ABI mismatch from any other assertion failure.

Measured against the shipped artifact (not copied from any plan or task
brief): `ctest --preset release` reports **55/55 tests passed**; the Scheme
mutation suite (`byte-machine.harness.scheme-mutation.cmake.direct`) reports
**"scheme mutation suite complete (36 passes, 107 mutations)"**, matching
`EXPECTED_PASSES`/`EXPECTED_MUTATIONS` in
[SchemeMutationSuite.cmake](../../test/support/cmake/SchemeMutationSuite.cmake);
`ctest --preset no-scheme` stays at **8/8**, unchanged.

**Runtime-export drift test — deferred to Slice B.** §3.5 and §5 Task 3 above
promise "a test computes member 2 from the runtime's actual export list and
asserts it against the declared set, so the two cannot silently drift." The
final whole-branch review found this was never turned into a concrete Slice A
task (Task 3 shipped the reserved-set *usage* and its three per-member
mutations, not the export-list *drift guard*). It ships **no defect in Slice A**:
the review confirmed `reserved-member-2` in `compile.sls` matches
`(byte-machine runtime)`'s exports exactly. The guarantee only becomes
load-bearing when a *new* runtime export appears — which is Slice B's `/v2`
constructor. It was **implemented in Slice B** as `reserved-drift-tests.sps` — set-equality of
`(environment-symbols (environment '(byte-machine runtime)))` against the exported
`reserved-member-2`, witnessed by a mutation that drops one entry — **without** a
`/v2` export: the mutation, not a new export, is what makes the guard load-bearing
(decision 0010, 2026-08-23 note).

## 7. Handed to writing-plans

- The exact canonical encoding the IR fingerprint is computed over (field order, byte
  serialization) — sourced from parent §20; fixed concretely so byte-identity is
  provable in Slice B.
- Concrete representations for the embedded ABI version and IR/emitter versions, and
  the exact `feed-outcome` field validation.
- The precise `emission-metadata` accessor surface (beyond IR fingerprint + byte
  count).
- Per-task lane and mutation deltas, computed against re-measured baselines
  (`release` 47, `no-scheme` 8/8, scheme mutation 34/87, cmake mutation 1/72).
- Whether member 3 (template identifiers) is enumerated by hand or derived, and the
  exact drift test that ties member 2 to the runtime export list.

## 8. References

- [milestone-1-design.md](./milestone-1-design.md) §3.1, §3.2, §3.3, §6, §7, §8.
- Parent [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
  §7.2, §9.2, §9.5, §9.6, §12.7, §17, §18, §19, §20, §22.1, §22.4, §23.
- Decisions [0005](../decisions/0005-chez-only.md), [0006](../decisions/0006-inline-libraries.md),
  [0008](../decisions/0008-emitter-emits-importable-library.md),
  [0009](../decisions/0009-content-and-ir-fingerprints.md).
- [milestone-1-phase-2-semantic-core-implementation-plan.md](./milestone-1-phase-2-semantic-core-implementation-plan.md)
  — the semantic core and the harness/lane/mutation conventions Slice A mirrors.
