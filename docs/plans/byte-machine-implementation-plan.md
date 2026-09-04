# Byte Machine Implementation Plan

Status: milestones 0, 1, 2, 3, and 4 are closed — 0 on 2026-08-22 ([the spike](./milestone-0-portability-spike.md), [the close-out](./milestone-0-close-out.md), [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md)), 1 on 2026-08-23 ([milestone-1-design.md](./milestone-1-design.md)), 2 on 2026-08-29 ([milestone-2-design.md](./milestone-2-design.md)), and 3 on 2026-08-30 ([milestone-3-design.md](./milestone-3-design.md)); each of those four carries a dated close note under its own §25 subsection below, and each of those cites where its exit criteria are dispositioned. Milestone 3 was delivered as a Gate 0 plus three slices: Slice ① (byte classes) closed 2026-08-29, Slice ② (sequence dispatch and prefix lowering) closed 2026-08-30, and Slice ③ (multiple alternatives, ambiguity, and cycle analysis) closed 2026-08-30 with the milestone. Milestone 4 (fields, actions, and branches) closed 2026-09-03, delivered as a Gate 0 plus four slices: Gate 0 discharged 2026-08-31 (decisions 0018-0022), Slice ①a — the unversioned generated-ABI constructor, normalized encoding format 2, and the `parser-error` family — 2026-09-02, Slice ①b (field declarations, storage, and `parser-field-ref`) 2026-09-02, Slice ② (field action and field branch) 2026-09-03, and Slice ③ (integer accumulation) 2026-09-03 with the milestone; its close note is a dated disposition, not a §25 subsection. Milestone 5's own scope has not begun: two hardening slices ran first — Slice ⓪ (the verifier's kind × position matrix and the diagnostic-code census) and Slice ⓪b (the EOF walk cluster), both closed 2026-09-04 and both dispositioned below. Decisions amended by 0005 (Chez-only) via [chez-only-simplification.md](./chez-only-simplification.md) §2, and by 0006 (inline libraries)

Date: 2026-08-15

Target release: `0.1.0`

Related architecture: [`chez-http-server-architecture.md`](./chez-http-server-architecture.md)

## 1. Purpose

Build a small, byte-oriented deterministic state-machine generator suitable for generating an incremental HTTP/1 request parser.

`byte-machine` is a library and offline source generator. It is not itself the production HTTP parser. A separate project will use this library to define and generate that parser.

This repository will contain a private HTTP request fixture only to prove that the machine model is sufficient for realistic request framing. That fixture is test infrastructure, not a supported HTTP API.

## 2. Approved Decisions

The following decisions are fixed for the initial implementation. Changing one requires an explicit plan update.

1. Machine specifications are built with ordinary Scheme procedures into an immutable, inspectable source IR.
2. A pure verifier/compiler transforms the source IR and an offline generator emits deterministic R6RS Scheme.
3. Generated parsers depend only on the small runtime library, never on the builder, verifier, compiler, or reference interpreter.
4. A reference interpreter is the semantic oracle for generated code.
5. `define-machine` or other macro sugar is deferred until the procedural API is stable.
6. The source IR is closed and serializable. It cannot contain opaque Scheme procedures.
7. Runtime extension points are declared named callbacks bound when a parser is constructed.
8. The initial production backend emits direct Scheme control flow, not a generic opcode interpreter.
9. The backend targets Chez Scheme. Libraries are ordinary R6RS `.sls`; no cross-implementation wrapper layer exists. (Amended 2026-08-18 — see [decision 0005](../decisions/0005-chez-only.md).)
10. Chez-specific emission — fixnum operations, unsafe declarations, or any identifier outside plain R6RS — is permitted only when reproducible compiled benchmarks demonstrate a material need.
11. Portable alternative layouts such as transition tables, trie specialization, or unrolling are also admitted only when benchmarks justify their complexity.
12. Structural verification is mandatory before source emission.
13. Parser fields are fixed-width unsigned integers and bitfields with checked operations.
14. At most one span may be active at a time in v0.1.
15. Parsers never retain an input bytevector after a feed call returns.
16. Message completion is an event. It does not stop a feed; an HTTP-shaped machine loops and continues through pipelined input.
17. Offline generation is library-first. A general-purpose CLI is not part of v0.1.
18. `byte-machine` tests do not vendor or run llhttp. The future HTTP-parser project owns llhttp corpus and differential integration.
19. v0.1 is released only after the private HTTP fixture proves request lines, headers, fixed-length bodies, chunked bodies, trailers, errors, fragmentation, and pipelining.
20. Platform support uses the tiered matrix in this plan.

## 3. Goals

### 3.1 Functional goals

- Define deterministic state machines over byte values `0..255`.
- Consume arbitrary half-open bytevector slices `[start,end)`.
- Resume correctly across every input boundary.
- Preserve exact consumed and error positions.
- Support same-byte reexecution without backtracking.
- Support exact byte, byte-set/class, and exact sequence matching.
- Support named callbacks, fragmented spans, and callback-directed pauses.
- Support fixed-width fields, checked numeric accumulation, flags, and field branches.
- Support efficient counted consumption for fixed-length and chunked bodies.
- Support explicit EOF behavior, successful stopping, sticky errors, reset, pause, and resume.
- Verify graph structure before interpretation or source generation.
- Emit deterministic wrapper-free R6RS Scheme source.
- Produce behavior equivalent to the reference interpreter.

### 3.2 Quality goals

- Functional core / imperative shell architecture.
- TDD for every vertical slice.
- No deliberate per-byte structural allocation in the generated dispatch loop except work performed by callbacks. Exact-integer promotion beyond an implementation's fixnum range is an acknowledged portable-runtime exception and must be measured.
- No dependency on sockets, HTTP, libuv, operating-system APIs, or an event loop.
- No hidden environment or filesystem reads in the functional core.
- Clear, structured, stable diagnostics.
- Reproducible source generation.
- Portable behavior across the supported OS/architecture matrix on Chez Scheme.

## 4. Non-goals for v0.1

- A universal parser-generator framework.
- A production HTTP parser or public HTTP request API.
- HTTP response parsing.
- llhttp behavioral compatibility or corpus integration in this repository.
- Regex syntax, context-free grammars, backtracking, lookbehind, or arbitrary lookahead.
- Arbitrary Scheme expressions embedded in a machine.
- More than one concurrently active span.
- Nested or overlapping spans.
- Runtime compilation or `eval`.
- A general-purpose generator CLI.
- A stable macro DSL.
- Graph visualization tooling.
- SIMD, unsafe Scheme primitives, native-endian tables, or architecture-specific code.
- Emitter variants beyond the direct-code backend without benchmark evidence.
- Resource policies such as maximum header count or body size. Those belong to a parser consumer; fixed-width overflow safety remains a machine concern.

## 5. Architectural Model

```text
ordinary Scheme builder procedures
              |
              v
      immutable source IR
              |
              v
   mandatory structural verifier
              |
              v
       verified source IR
          /             \
         v               v
reference interpreter   deterministic normalizer
                              |
                              v
                     normalized private IR
                              |
                              v
                    portable direct-code emitter
                              |
                              v
                     generated .scm body
                              |
                              v
                     byte-machine runtime
                              |
                              v
                        parser instance
```

The builder, verifier, normalizer, interpreter transition core, and source-rendering core are functional. They accept values and return values without consulting global mutable state, environment variables, the clock, randomness, or the filesystem.

The imperative shells are limited to:

- parser-instance mutation during `feed!`, `finish!`, `resume!`, and `reset!`;
- binding user callbacks and context;
- reading grammar/build inputs in a consuming project;
- the thin `emit-machine` shell that writes pure rendered bytes through a caller-provided binary port;
- process exit and test-runner integration.

## 6. Terminology

- **Source IR**: immutable public graph descriptors constructed by the builder API.
- **Normalized IR**: private lowered graph used by the emitter after names and high-level matchers are resolved.
- **Machine**: an immutable graph plus declarations for fields, callbacks, spans, entry, and EOF policy.
- **Compiled machine**: opaque runtime descriptor containing an executor and immutable metadata. Production values come from generated code; the reference interpreter provides a contract-compatible test adapter.
- **Parser**: mutable instance of a compiled machine, including state, fields, callback bindings, offsets, and lifecycle status.
- **Cursor**: current index in the bytevector supplied to the active feed.
- **Stream offset**: nonnegative exact-integer count of bytes committed as consumed since the last full reset. It is not width-limited by a machine field.
- **Advance edge**: transition that commits the byte examined by its source input node.
- **Reexecute edge**: transition that leaves the cursor unchanged so the target observes the same byte.
- **Zero-progress edge**: transition from a non-input operation or a reexecute edge; it consumes no byte.
- **Span**: a logical range whose data is delivered as zero or more contiguous input fragments followed by one completion event.

## 7. Portability Contract

### 7.1 Shared implementation subset

The functional core and the tests are inline R6RS `.sls` libraries and `.sps` programs ([decision 0006](../decisions/0006-inline-libraries.md)). The form of the runtime and generated libraries is fixed by §9.6 and [decision 0008](../decisions/0008-emitter-emits-importable-library.md): the emitter emits a complete importable `.sls`.

Use:

- ordinary procedures, lexical bindings, lists, vectors, strings, symbols, exact integers, and ports;
- `make-bytevector`, `bytevector?`, `bytevector-length`, `bytevector-u8-ref`, and `bytevector-u8-set!`, supplied directly by R6RS;
- numeric byte constants rather than characters in the IR and hot path;
- tagged vectors hidden behind accessors for records shared across libraries;
- `dynamic-wind` where parser cleanup must survive a callback escape.

The common arithmetic layer provides specified unsigned `and`, `or`, and `xor` operations without assuming a Scheme-standard bitwise library. The initial shared implementation may use exact-integer arithmetic; any Chez-specific primitive replacement is an optimization subject to semantic equivalence tests and the benchmark admission policy. Test every operation at all declared widths.

Product code is plain R6RS. Two correctness rules survive from the portability era because they were never about dialect: never rely on unspecified argument evaluation order, and never put implementation exception text in a behavioral contract. Chez extensions are admitted only through §2 decision 10.

### 7.2 Library wrappers

Libraries are R6RS `.sls`; each library and each test program contains its own code. No Scheme file in this repository includes another — the transitional shared-body mechanism of decisions 0002/0003 was retired by [decision 0006](../decisions/0006-inline-libraries.md).

The internal dependency direction is:

```text
private model/result/diagnostic
          ^
          |
graph <- verify <- compile
  ^         ^          ^
  |         |          |
interpret   +----------+
  |
  v
runtime  (independent of graph/verify/compile; owns runtime result singletons)
```

`runtime` depends on nothing above it, but `interpret` depends on `runtime`:
`make-interpreted-machine` returns a runtime-compatible compiled-machine, and
interpreted callbacks must return the runtime's own singleton outcome values.
Were they distinct objects, interpreter and generated execution would disagree
about callback results while both looking correct in isolation — which is
precisely the class of defect the differential tests exist to catch, so it must
not be reachable through the library structure.

### 7.3 Supported platform tiers

Tier 1 release gates: Chez on Linux amd64; Chez on Linux arm64; Chez on macOS arm64; Chez on Windows amd64 — each in both source and AOT execution. Tier 2: macOS amd64, Windows arm64, additional supported Chez versions.

Tier 2 failures are tracked and must not be knowingly introduced, but unavailable runners or unsupported upstream toolchains do not block v0.1.

This is a coverage-based portability claim, not a claim that every OS and architecture pair is release-certified. Tier 1 covers each required operating-system family and both architectures; Tier 2 covers the remaining cross-product cells.

An initial portability spike must pin the minimum Chez version and record exact invocation, library-search, include-path, and compiled-artifact behavior on Tier 1 systems.

Every Tier 1 cell is a real release gate. If an upstream toolchain or runner makes one infeasible, the tier must be changed through an explicit update to this plan before release; it cannot be silently waived in release notes.

## 8. Proposed Repository Layout

The precise split may be adjusted during the portability spike, but responsibility boundaries must remain intact.

```text
src/
  byte-machine/
    graph.sls
    verify.sls
    compile.sls
    interpret.sls
    runtime.sls
test/
  fixtures/
    http-request-machine.scm
bench/
  fixtures/
  runner/
examples/
  generate-simple-machine/
docs/
  plans/
  reference/
  decisions/
build/
  chez/
```

`build/` is ignored. Chez native artifacts must never be shared between runtime versions, operating systems, or architectures.

## 9. Public Library Surface

The names below are normative for v0.1 unless a failing portability spike forces a documented plan change. Optional arguments use explicit `#f` or option alists; the shared API does not use keywords.

### `(byte-machine graph)`

- Machine, field, callback, span, node, matcher, edge, and EOF-policy constructors.
- Read-only predicates and accessors for source IR.
- ASCII convenience conversion that rejects non-ASCII source strings.
- No mutation API and no exposure of tagged-vector layout.

### `(byte-machine verify)`

- `verify-machine`
- Structured verification result and diagnostic accessors.
- Verification never depends on generated source or the runtime parser.

### `(byte-machine compile)`

- `compile-machine`
- `render-machine`
- `emit-machine`
- Compilation options and result accessors.
- Emission accepts an explicit binary output port and writes canonical UTF-8/LF bytes.
- Expected invalid graphs return diagnostics rather than implementation exceptions.

### `(byte-machine interpret)`

- Reference parser construction and execution directly from verified source IR.
- `make-interpreted-machine`, producing a runtime-compatible compiled-machine value backed by the independent interpreter executor.
- Debug/test API; public enough for grammar authors but not a performance API.
- Same feed-result, callback, field, span, and lifecycle contracts as generated execution.

### `(byte-machine runtime)`

- Compiled-machine and parser constructors.
- `parser-feed!`, `parser-finish!`, `parser-resume!`, and `parser-reset!`.
- Parser/result/error/field accessors.
- Callback binding validation.
- This is the only byte-machine library required by emitted parsers.

No umbrella library is required for v0.1. Avoid forcing runtime consumers to load compiler code.

### 9.1 Normative construction calls

```scheme
(make-machine name entry fields callbacks spans errors nodes
              default-eof-error source-label)
(make-uint-field name width initial source-label)
(make-callback-declaration name kind required? branch-keys
                           default-branch source-label)
(make-span-declaration name data-callback complete-callback source-label)
(make-error-declaration name code reason source-label)

(make-byte-dispatch-node name cases fallback eof-target source-label)
(make-byte-case matcher edge source-label)
(make-exact-byte-matcher byte)
(make-byte-set-matcher bytes)
(make-byte-range-matcher low high)
(make-byte-complement-matcher matcher)      ; complement within 0..255
(make-edge target mode)                    ; mode: advance | reexecute

(make-sequence-dispatch-node name cases mismatch eof-target source-label)
(make-sequence-case bytes target source-label)
(ascii-bytes string)                       ; rejects non-ASCII

(make-field-action-node name operation arguments next error source-label)
(make-integer-accumulate-node name field base digit-target
                              nondigit-edge overflow-error eof-target
                              source-label)
(make-field-branch-node name predicate arguments true-target false-target
                        source-label)
(make-callback-node name callback continue-target branch-targets
                    pause-continuation source-label)
(make-span-start-node name span next source-label)
(make-span-end-node name span next source-label)
(make-counted-consume-node name field next eof-target source-label)
(make-pause-node name continuation source-label)
(make-stop-node name source-label)
(make-finish-node name source-label)
(make-error-node name error-declaration source-label)
```

`bytes`, declaration collections, case collections, argument collections, and branch maps are proper lists in deterministic caller order. Branch maps contain two-element lists `(key target)`, not implementation hash tables. `#f` as an input node's `eof-target` means the machine default EOF error.

`make-machine` stamps the current public source-IR format version; v0.1 callers do not supply or override that version. A future deserializer may expose explicit version handling, but ordinary construction cannot manufacture an unsupported-version descriptor through the public API.

Constructors validate only local shape and return immutable-by-API descriptors (from Milestone 3 that validation includes rejecting an empty byte set, a range with `low > high`, and an empty sequence — decision 0017). Cross-reference, graph, and semantic checks belong to `verify-machine` so callers can accumulate structured diagnostics.

Field-action operations and their exact `arguments` schemas are:

| Operation | Arguments |
| --- | --- |
| `store` | `(field constant)` |
| `clear` | `(field)` |
| `increment` | `(field)` |
| `decrement` | `(field)` |
| `add` | `(field constant)` |
| `set-mask` | `(field mask)` |
| `clear-mask` | `(field mask)` |

Field-branch predicates and their exact `arguments` schemas are:

| Predicate | Arguments |
| --- | --- |
| `equal` | `(field constant)` |
| `zero` | `(field)` |
| `nonzero` | `(field)` |
| `range` | `(field low high)` |
| `mask-any` | `(field mask)` |
| `mask-all` | `(field mask)` |
| `mask-none` | `(field mask)` |

These are closed v0.1 enumerations. The verifier enforces exact arity, declared-field references, operand range, and `low <= high`; it rejects arbitrary operation names or extra arguments.

### 9.2 Normative compile and emission calls

```scheme
(verify-machine machine)                    ; -> verification-result
(verification-ok? verification)
(verification-diagnostics verification)

(compile-machine machine options)           ; -> compilation-result
(compilation-ok? compilation)
(compilation-diagnostics compilation)
(render-machine compilation binding)        ; -> canonical bytevector
(emit-machine compilation binding binary-output-port)

(make-interpreted-machine verification)     ; -> compiled-machine
```

`compile-machine` accepts a machine, while `make-interpreted-machine` accepts a *verification*. That asymmetry is deliberate and has a consequence worth stating outright: a verification result carries the machine it verified, not merely its diagnostics. It is the evidence that a particular machine passed, so it must identify that machine. `compile-machine` re-verifies internally rather than accepting a verification, so that no caller can pair a verification of one machine with a different machine.

`compile-machine` is a pure ahead-of-time transformation from source IR to an emission-ready value. It does not invoke Scheme compilation, load generated code, use `eval`, or write a file. It always performs verification and refuses to expose an emission-ready normalized graph on failure. v0.1 accepts only the empty option list and rejects unknown options; optimization toggles are not hidden in the initial API.

`render-machine` is pure and returns the complete canonical source bytevector. `emit-machine` is a thin imperative convenience that writes exactly that bytevector to the supplied binary port and returns emission metadata containing the IR fingerprint and byte count.

`binding` is a symbol and is the single top-level compiled-machine binding defined by the generated wrapper-free body. It must satisfy the portable name grammar and must not collide with the canonical reserved-output-binding set. That set contains:

- every Scheme syntax or declaration identifier reserved by the R6RS source mode, including library and include forms;
- every identifier exported by `(byte-machine runtime)`, including the generated ABI binding;
- every top-level or lexical identifier emitted by the canonical source template.

The compiler owns this explicit, deterministically ordered set next to the emitter template. Thin runtime wrappers' export lists and the set are checked together by tests so they cannot silently drift. `render-machine` and `emit-machine` validate the binding before producing or writing any bytes and raise an `invalid-output-binding` API-contract condition on failure.

Scoping (Milestone 1, decision lineage milestone-1-design.md §3.3): only member 1 (R6RS source-mode syntax/declaration identifiers) is enumerable before Milestone 1 builds anything. Member 2 (`(byte-machine runtime)` exports) exists once the runtime lands; member 3 (canonical source-template identifiers) once the emitter lands. Generated-name-safety verification checks each member from the phase in which it comes to exist; a test must not assert against a member that does not yet exist.

### 9.3 Normative runtime calls

```scheme
(make-parser compiled-machine callback-bindings user-context)
(parser-feed! parser bytevector start end)  ; -> parser-result
(parser-finish! parser)                     ; -> parser-result
(parser-resume! parser)                     ; -> feed-ready | finish-ready
(parser-reset! parser)                      ; -> parser

(parser-result-status result)
(parser-result-next result)                 ; feed-originated results only
(parser-result-consumed result)             ; feed-originated results only
(parser-result-stream-offset result)
(parser-result-error result)                ; #f unless error

(parser-error? object)
(parser-error-domain error)                 ; machine | callback
(parser-error-code error)
(parser-error-reason error)
(parser-error-detail error)                 ; #f for machine errors
(parser-error-node-name error)              ; public source node
(parser-error-state-id error)               ; generated/internal state ID
(parser-error-offset error)                 ; absolute stream offset
(parser-error-position-kind error)          ; byte | boundary | eof

(parser-lifecycle parser)
(parser-state-name parser)
(parser-stream-offset parser)
(parser-field-ref parser field-name)
(parser-user-context parser)

callback-continue                          ; allocation-free singleton
callback-pause                             ; allocation-free singleton
(make-callback-failure code detail)
(callback-failure? object)
```

`callback-bindings` is a proper list of two-element lists `(name procedure)`. Parser construction resolves it to indexed slots, rejects duplicates and unknown names, rejects missing required callbacks, and installs no-op/default behavior only where declared. An optional decision callback must declare `default-branch`; other optional callbacks default to `continue`.

The symbols `continue` and `pause` are reserved and may not be callback decision branch keys. Callbacks return the exported singleton objects rather than constructing lookalike symbols or vectors.

`make-callback-failure` requires a symbolic code satisfying the same portable ASCII name grammar. Its detail is opaque application data.

Result and parser representations are opaque. Accessors enforce where fields such as `next` are meaningful.

### 9.4 Conditions

Portable API-contract conditions are tagged byte-machine values raised non-continuably with Scheme `raise`. Export:

```scheme
(byte-machine-contract-condition? object)
(byte-machine-contract-condition-code object)
(byte-machine-contract-condition-who object)
(byte-machine-contract-condition-detail object)
```

Codes include invalid argument, invalid slice, invalid output binding, lifecycle violation, reentrancy, poisoned parser, callback binding error, generated-runtime ABI mismatch, and accessor misuse. Tests compare predicates, codes, and payloads across execution lanes, never rendered exception prose.

### 9.5 Generated runtime ABI

`(byte-machine runtime)` exports the reserved generated-code ABI binding `byte-machine-make-compiled-machine`. Emitted bodies call that binding and embed the required runtime ABI and IR/emitter versions. (Milestone 2 added `byte-machine-make-compiled-machine/v2` with the finish path — a unified `exec` carrying `finish?` — [decision 0012](../decisions/0012-generated-abi-v2-finish.md). Milestone 4 retires the versioned *name*, not the version: one unversioned constructor checks `current-abi-version` — now 3 — before reading any payload, the payload is a growable quoted vector, and `/v1` and `/v2` stay exported as tombstones that refuse every version — [decision 0018](../decisions/0018-unversioned-generated-abi-constructor.md).) This export exists so a generated library depends only on `(byte-machine runtime)`: the consumer imports the generated library, whose sole byte-machine import is the runtime ([decision 0008](../decisions/0008-emitter-emits-importable-library.md)); it is not an API for handwritten grammar or application code. Loading or constructing against a mismatched runtime raises the portable ABI-mismatch condition.

The generated ABI is distinct from the user-facing parser API and is documented only in this ABI section and generated-code maintenance notes. It may change before `1.0.0` only with a generated-ABI version bump, deterministic regeneration, and a changelog entry.

### 9.6 Required end-to-end examples

Milestone 1 must add one executable Chez example program, run in both the source and AOT lanes, that demonstrates:

1. constructing a one-byte machine only through `(byte-machine graph)`;
2. verifying it;
3. compiling it without runtime evaluation;
4. emitting the generated library to a binary file port;
5. importing the generated library from the consumer — the emitter emits a complete importable `.sls` ([decision 0008](../decisions/0008-emitter-emits-importable-library.md)), so no file includes another and §7.2 holds;
6. importing only `(byte-machine runtime)` in the consumer;
7. constructing a parser, feeding the exact `[0,1)` slice, and inspecting the result;
8. compiling and running the consumer ahead-of-time.

The exact tool commands come from Milestone 0 and are copied verbatim into this example. There is no include-path setup: [decision 0006](../decisions/0006-inline-libraries.md) retired the mechanism.

## 10. Source IR

### 10.1 Machine descriptor

A machine declares, in deterministic order:

- format version;
- symbolic machine name;
- symbolic entry state;
- fields;
- callbacks;
- zero or more named spans;
- declared machine errors;
- nodes;
- a machine-wide default EOF error;
- optional stable source labels for diagnostics.

Node and declaration names are symbols. Target references are symbolic, which permits forward references and cycles without mutable node objects.

For v0.1, machine names, declaration names, error codes, and callback branch keys must match the portable ASCII grammar `[a-z][a-z0-9-]*`. Human-readable static labels and reasons embedded in generated output are restricted to printable ASCII plus LF. This keeps symbol and string emission independent of reader extensions and Unicode-version differences. Runtime callback error detail remains opaque application data and is never emitted.

Declaration order has no semantic priority. It provides stable IDs, generated order, and diagnostics after verification has established determinism.

### 10.2 Field declarations

Each field declares:

- symbolic name;
- unsigned width: 8, 16, 32, or 64 bits;
- initial exact-integer value within range;
- optional diagnostic label.

Booleans use `u8` values `0` and `1`. Enums use a width sufficient for their declared constants. Flags use unsigned bitfields.

Parser bookkeeping such as current state, lifecycle, callback vector, user context, cursor, stream offset, and span markers is not exposed as machine fields.

### 10.3 Callback declarations

Each callback declares:

- symbolic name;
- kind: event, decision, span-data, or span-complete;
- whether it is required or has a no-op default;
- allowed branch keys for decision callbacks;
- the default branch for an optional decision callback;
- optional diagnostic label.

Callbacks are resolved once into indexed slots when the parser is constructed. Generated hot paths never perform symbolic or alist lookup.

### 10.4 Span declarations

Each span declares:

- symbolic name;
- span-data callback;
- optional span-complete callback;
- optional diagnostic label.

Only one span may be active on any reachable execution path in v0.1. The verifier rejects nested, overlapping, re-entered, or inconsistently closed spans.

### 10.5 Error declarations

Each machine error declares:

- symbolic declaration name;
- stable symbolic error code;
- static printable-ASCII reason;
- optional diagnostic label.

Error nodes and the machine default EOF policy reference these declarations. Callback application failures occupy a separate runtime error domain and do not need source-IR declarations.

### 10.6 Node kinds

The source IR supports the following closed set.

#### Byte dispatch

Examines the current byte and selects among disjoint exact-byte, byte-set, range, or complement transitions plus one explicit fallback. Matchers denote subsets of the closed byte universe `0..255`; complements are canonicalized against that universe before overlap analysis.

Each transition explicitly states `advance` or `reexecute`.

#### Sequence dispatch

Matches one of a finite set of exact byte sequences without backtracking. Sequences may share nonterminal prefixes. Ambiguous terminal prefixes are rejected unless the grammar expresses the distinction through explicit states.

The compiler lowers sequence alternatives into resumable prefix states. A successful sequence consumes every byte in that sequence; sequence dispatch is not a lookahead operation. On a mismatch, already consumed prefix bytes remain consumed and the declared mismatch edge controls whether the mismatching byte advances or is reexecuted. Peeking at a delimiter is expressed with a one-byte dispatch and a reexecute edge.

#### Field action

Performs one declared built-in operation and continues without consuming input.

Initial operations:

- store constant;
- clear to zero;
- checked increment or decrement;
- checked add;
- bitwise set and clear mask.

Underflow, overflow, or an out-of-range result takes an explicit error edge.

#### Integer accumulate

Examines the current byte, converts an ASCII digit for declared base 10 or 16, and performs a checked multiply-add into one unsigned field.

- A valid digit updates the field and takes an explicit advance edge.
- A non-digit takes an explicit fallback edge, normally reexecuting the delimiter.
- Overflow takes an explicit error edge and leaves the previous field value unchanged.
- EOF uses the node's declared EOF edge or the machine default.

This is an input-reading node, not a zero-width field action. It provides numeric scanning without passing an implicit current byte into a later action.

#### Field branch

Selects a transition without consuming input using one of:

- equality to constant;
- zero/nonzero;
- inclusive range;
- bit-mask any/all/none.

Every possible result must have an explicit target.

#### Callback invocation

Invokes one named event or decision callback without consuming input. Decision results select only among statically declared branch keys. Every invocation declares a continue target and a pause continuation. Unknown results are runtime callback-contract errors. A decision that must both select a branch and pause routes that branch to an explicit pause node.

#### Span start

Opens the declared span at the current cursor without consuming input.

#### Span end

Closes the active span at the current cursor without consuming input. It emits a remaining nonempty data fragment, then the completion callback. Internal continuation states ensure a pause never repeats an already delivered fragment or completion event.

#### Counted consume

Consumes up to the remaining value of one declared unsigned field in bulk, subtracting exactly the committed count.

- A zero count transitions immediately without consuming input.
- If input ends first, available bytes are consumed and the parser returns `need-input`.
- If the count reaches zero first, execution continues at the target with any remaining input.
- When available input exactly equals the remaining count, count completion wins: the field reaches zero and execution continues through zero-width/span/message-complete work in the same feed before any `need-input` result.
- When enclosed in a span, normal span fragment rules apply.

#### Pause

Returns `paused` with an explicit continuation node and the first unconsumed input index.

#### Stop

Enters a successful sticky one-shot terminal and returns `stopped`.

#### Finish

Enters the successful sticky EOF terminal and returns `finished`. A finish node may be reached only while processing `parser-finish!`; the verifier rejects ordinary byte or non-EOF control flow into it.

#### Error

Enters a sticky terminal carrying a declared code and reason.

No arbitrary custom node, embedded lambda, or backend code escape hatch exists in v0.1.

## 11. Transition and Cursor Semantics

### 11.1 Input slice

`parser-feed!` accepts `(parser bytevector start end)` with a half-open slice `[start,end)`.

Valid inputs satisfy:

```text
0 <= start <= end <= bytevector-length(bytevector)
```

Invalid arguments raise an API-contract condition before parser mutation.

An empty slice is a valid feed. It may advance already-pending zero-width continuations, but it never represents EOF and never consumes a byte. It returns `need-input` once execution reaches an input-dependent state unless a callback, stop, or error is encountered first.

### 11.2 Advance

An advance edge from a byte-reading node commits the examined byte, increments the cursor by one, increments the stream offset by one, and then enters its target.

### 11.3 Reexecute

A reexecute edge enters its target without changing the cursor or stream offset. The target observes the same current byte. This is used for delimiter handling and span exclusion without pushback.

There is no general rewind or backtracking.

### 11.4 Non-input nodes

Field operations, field branches, callback invocations, and span operations do not consume input. Byte dispatch, sequence-prefix states, integer accumulation, and counted consumption are input-dependent. The executor continues through zero-width nodes until it reaches an input-dependent node, pauses, stops, errors, or finishes.

Any reachable cycle that can run indefinitely without consuming input is invalid.

### 11.5 Result position

Every feed result contains:

- `next`: the first unconsumed index in the supplied bytevector;
- `consumed`: `next - start`;
- absolute stream offset after committed consumption.

For an offending byte reached through a reexecute error edge, `next` points at that byte. Machine authors may deliberately use an advance error edge when the offending byte is considered consumed; tests must make that choice explicit.

## 12. Parser Lifecycle and Results

### 12.1 Lifecycle

```text
ready --feed--> ready | paused-feed | stopped | error
ready --finish-> paused-finish | finished | error
paused-feed --resume-> ready
paused-finish --resume-> finish-ready
finish-ready --finish-> paused-finish | finished | error
any non-busy state --reset-> ready
```

`busy` is an internal guard while feed, finish, or a callback is executing.

A pause records both its exact continuation and whether it occurred while processing input or EOF. `parser-resume!` changes lifecycle state only; it invokes no callback and consumes no input. It returns `feed-ready` for a feed pause and `finish-ready` for an EOF pause.

`parser-resume!` returns the symbol `feed-ready` or `finish-ready`. These are resume acknowledgements; `finish-ready` is also the lifecycle state awaiting the caller's next `parser-finish!`. Neither is a `parser-result` status. In particular, `parser-finish!` never returns `finish-ready`: once invoked from that state, it continues EOF execution until it returns `paused`, `finished`, or `error`.

After `feed-ready`, the caller supplies the unconsumed suffix beginning at the prior feed result's `next` index. It may use the same bytevector or an equivalent copied suffix. After `finish-ready`, the caller calls `parser-finish!` again; feeding bytes is prohibited.

### 12.2 Operation matrix

| Lifecycle | `feed!` | `finish!` | `resume!` | `reset!` |
| --- | --- | --- | --- | --- |
| `ready` | Execute input | Begin EOF processing | Contract condition | Reset and remain ready |
| `paused-feed` | Contract condition | Contract condition | Install continuation; return `feed-ready` | Reset |
| `paused-finish` | Contract condition | Contract condition | Install continuation; return `finish-ready` | Reset |
| `finish-ready` | Contract condition | Continue EOF processing | Contract condition | Reset |
| `stopped` | Return `stopped`, consuming zero | Return `stopped` | Contract condition | Reset |
| `error` | Return stored error, consuming zero | Return stored error | Contract condition | Reset |
| `finished` | Return `finished`, consuming zero | Return `finished` | Contract condition | Reset |
| `poisoned` | Raise `parser-poisoned` | Raise `parser-poisoned` | Raise `parser-poisoned` | Reset |
| `busy` | Raise reentrancy condition | Raise reentrancy condition | Raise reentrancy condition | Raise reentrancy condition |

For repeated `feed!` calls in a sticky state, `next` equals the new call's `start`, `consumed` is zero, and the stored absolute terminal/error offset remains unchanged.

### 12.3 Feed statuses

#### `need-input`

The complete supplied slice was consumed and the machine is waiting for more input. It does not imply that a logical message completed.

#### `paused`

Execution stopped at a callback or explicit pause point. For a feed-originated `paused-feed` result, `next` identifies the first unconsumed byte. A `paused-finish` result has no input slice, so `next` and `consumed` are inapplicable and only the absolute stream offset is exposed. `parser-resume!` must be called before feeding more input or continuing EOF processing.

#### `stopped`

The machine entered a successful explicit terminal. The status is sticky until reset.

#### `error`

The machine entered a declared machine error or callback application error. The status is sticky until reset. Repeated feed attempts return the same error without consuming input.

### 12.4 EOF

`parser-finish!` is distinct from an empty feed.

Every input-dependent state uses either a state-specific EOF edge or the machine's explicitly declared default EOF error. A stream-idle entry state may route EOF to successful `finished`; a partially parsed request routes EOF to a truncation error.

Lowered states inside a sequence inherit the source sequence state's EOF edge. EOF after a nonempty matched prefix therefore reports the source state's EOF policy at the current between-byte stream offset. EOF edges participate in a separate zero-progress-cycle check; EOF processing may not loop indefinitely. (The EOF traversal is the eof-target chain, terminating at finish/error/pause; execution model in decision 0011.)

EOF processing may invoke callbacks and may pause. A pause during EOF produces `paused-finish`; after resume, a subsequent `parser-finish!` continues the saved EOF path. EOF processing never admits new bytes and must terminate in `finished` or `error` after a finite number of resumes.

`finished` is sticky until reset.

### 12.5 Reset

Full reset:

- restores the entry state;
- restores all declared field initial values;
- clears span state, pause continuation, error, stop, finish, and poison state;
- resets stream offset to zero;
- retains the compiled machine, callback bindings, and user context.

HTTP-shaped message loops use explicit field actions to reset message-local values. They do not call full reset and do not reset the stream offset.

### 12.6 Misuse and poisoning

Prohibited lifecycle operations and reentrant parser operations raise API-contract conditions before further mutation. (From Milestone 2 the runtime raises coded `&byte-machine-contract` conditions, the §11.1 invalid-slice contract included — [decision 0013](../decisions/0013-runtime-coded-conditions.md).)

Expected callback failures must use callback result values. If a callback raises an unexpected condition or performs a nonlocal escape, the condition/escape propagates and `dynamic-wind` marks the parser poisoned. Only full reset may reuse it.

### 12.7 Runtime error structure

A sticky runtime error records:

- domain: machine or callback;
- stable symbolic code;
- static reason and optional callback-provided detail;
- public source-node name and internal state ID;
- absolute error offset;
- position kind: offending byte, between-byte boundary, or EOF boundary.

The originating feed result also carries its slice-relative `next`. The persistent error does not store a reusable relative index because later calls may supply different slices.

Position conventions:

| Error source | Stored position |
| --- | --- |
| Reexecute mismatch or rejected current digit | `byte` at the current stream offset |
| Error edge after an advance | `boundary` after the committed byte |
| Zero-width machine action or callback failure | `boundary` at the current stream offset |
| Truncated input during `finish!` | `eof` at the final stream offset |

Integer-overflow nodes reject and do not consume the overflowing digit, so their position is the offending byte. Error nodes reached through other byte edges retain the author's explicit advance/reexecute choice.

Expected malformed input is reported through a feed/finish result, not by raising. API-contract conditions and unexpected callback conditions remain distinct from parser data errors.

The source-node name, domain, code, offset, and position kind are semantic and must match between interpreted and generated execution. The internal state ID is an executor-local debugging aid: generated IDs are deterministic for a given normalized graph, but an independently interpreted machine need not report the same ID. Differential tests do not compare that accessor across executor kinds.

## 13. Callback Contract

Event and decision callbacks receive:

```scheme
(callback parser user-context)
```

Span-data callbacks receive:

```scheme
(callback parser user-context bytevector start end)
```

Span-complete callbacks receive:

```scheme
(callback parser user-context)
```

The input range is valid only for the dynamic extent of the span-data callback. The byte-machine runtime stores no feed bytevector or slice after return. Application-owned opaque values—including callback closures, user context, and callback error detail—may retain data by their own policy and are outside that guarantee.

Machine-field access from a callback is read-only. Allowing callbacks to mutate fields would bypass the closed IR and invalidate interpreter/generated equivalence. User context remains application-owned and may be mutable.

Callback outcomes are:

- `continue`;
- `pause`;
- one declared decision branch key;
- an explicit callback failure containing an application code and optional detail.

The common successful outcomes must use allocation-free singleton values. Error detail allocation is allowed on the exceptional path.

Event and span callbacks accept only `continue`, `pause`, or failure. Decision callbacks may additionally return their declared branch keys. A plain decision-callback pause resumes at that invocation's declared pause continuation; branch-and-pause behavior uses a branch leading to an explicit pause node.

A callback-requested pause occurs after the callback's delivered event has been committed. Resume continues after that event; it is never delivered twice. A span-data callback accepts or rejects its complete supplied range atomically; partial acceptance is not a v0.1 result. Callers that need finer backpressure feed bounded slices and retain ownership of every unconsumed suffix.

At callback entry, the interpreter and generated executor expose identical committed parser state:

- fields include every operation completed before the callback and are read-only through public accessors;
- stream offset and cursor include every byte committed before the callback;
- public parser state names the source callback/span node, not a generated internal continuation; an automatic feed-boundary fragment reports the current source input node together with the active span name;
- lifecycle is `busy`, so parser operations are rejected;
- a span-data callback sees its named span active with the delivered mark already advanced to the fragment end;
- a span-complete callback sees that span inactive;
- no error is installed until a callback returns failure.

An explicit pause node or event/decision callback invocation is invalid on any reachable path where a span is active. Only the active span's own data callback may pause before the span closes. The verifier enforces this restriction, which makes the no-retention contract possible without invoking unrelated callbacks after a pause request.

## 14. Span Semantics

1. Starting a span records the current cursor.
2. Ending a span emits `[mark,cursor)` if nonempty.
3. Ending then emits the span-complete callback if declared.
4. At a feed boundary, an open span emits `[mark,end)` if nonempty, remains logically open, and begins its next possible fragment at the next feed's `start`.
5. Empty span-data fragments are suppressed.
6. A logical span may therefore produce zero or more data fragments followed by exactly one completion event.
7. Fragment boundaries reflect feed boundaries and pauses; consumers must not treat them as semantic token boundaries.
8. If a span-data callback pauses during boundary flushing, the fragment is committed, the span remains open, and resume begins with the next supplied input.
9. If a span-end data or completion callback pauses, generated internal continuation states resume at the next undelivered substep.
10. Errors do not flush a final partial fragment or synthesize a span-complete event. Fragments successfully emitted at earlier feed boundaries remain observable.

During span end, the data callback sees the span active and its mark advanced to the current cursor. Before invoking the completion callback, execution makes the span inactive. A pause after the data fragment retains only an internal `completion-pending` continuation, never the input bytevector.

The verifier proves that no reachable path starts a second span while one is active, ends the wrong span, ends with no active span, or reaches successful stop/finish with a span active.

## 15. Fixed-width Field Semantics

Widths have mathematical ranges:

```text
u8   0 .. 2^8  - 1
u16  0 .. 2^16 - 1
u32  0 .. 2^32 - 1
u64  0 .. 2^64 - 1
```

Shared code uses exact Scheme integers but checks the declared bound before committing every operation. It must not rely on host fixnum width or silent wrapping.

For the integer-accumulate node's checked multiply-add:

```text
next = current * base + digit
```

The implementation checks before multiplication/addition, conceptually:

```text
current <= floor((maximum - digit) / base)
```

Failure takes the node's explicit error edge and leaves the previous field value unchanged.

Counted consume performs exact subtraction after determining the number of bytes it can commit.

## 16. Verification and Diagnostics

### 16.1 Verification is a generation gate

Neither compilation nor emission proceeds when any error diagnostic exists. The reference interpreter also refuses an unverified source machine.

### 16.2 Required checks

The verifier rejects:

- invalid descriptor shapes and unsupported IR versions;
- duplicate machine declaration names;
- nonportable names, codes, branch keys, labels, or reasons;
- missing entry or transition targets;
- missing or invalid machine error declarations and references;
- invalid field widths, initial values, constants, masks, and operations;
- missing or incompatible callbacks;
- optional decision callbacks without a valid declared default branch;
- invalid span callback declarations;
- duplicate or overlapping exact-byte and byte-set transitions;
- sequence ambiguities after prefix analysis;
- missing explicit fallback on every byte/sequence dispatch;
- invalid transition advancement modes;
- unreachable nodes;
- reachable zero-progress cycles;
- span re-entry, overlap, wrong end, unmatched end, and inconsistent successful exits;
- explicit pauses or event/decision callback invocations reachable while a span is active;
- callback decision branches that are missing, duplicated, or undeclared;
- callback decision keys that collide with reserved control outcomes;
- counted consume using an incompatible field;
- integer accumulation using an incompatible field or unsupported base;
- malformed pause continuations;
- terminal nodes with outgoing transitions;
- invalid EOF targets or successful EOF with an active span (EOF *execution*, not just target resolution: decision 0011);
- EOF-only zero-progress cycles and non-EOF control flow into a finish terminal;
- EOF-reachable stop terminals: every EOF path must reach finish or error after finitely many explicit pauses (this and the preceding EOF-cycle / non-EOF-into-finish checks are decision 0011's, each with a diagnostic code);
- generated identifier collisions;
- backend limits that would make emission incorrect.

Normal consuming cycles, including the main HTTP message loop, are valid.

### 16.3 Verification passes

Implement verification as independent pure passes where practical:

1. Descriptor/schema validation.
2. Symbol table construction and name resolution.
3. Matcher canonicalization and byte-set overlap analysis.
4. Reachability.
5. Zero-progress strongly connected component analysis.
6. Field and callback type checking.
7. Span-state dataflow.
8. EOF and terminal validation.
9. Generated-name validation.

Each pass receives an immutable value and returns diagnostics plus any derived immutable analysis.

Normalization is followed by private invariant validation. Compiler bugs that produce malformed normalized IR are internal failures, never user diagnostics and never input to the emitter.

### 16.4 Diagnostic structure

Diagnostics contain:

- stable symbolic code;
- severity (`error`; warnings may be added later);
- machine name;
- node and edge/source label where applicable;
- concise message;
- relevant declaration names;
- a representative graph path when useful.

Tests compare diagnostic structure and codes, not implementation-specific rendered text.

Unreachable nodes are errors in v0.1. Warning or fragment-composition policies are deferred.

## 17. Normalization

Normalization runs only after source verification and is deterministic.

Responsibilities:

- resolve symbolic names to stable numeric IDs (declared nodes keep their declaration index; internal states append after them — decision 0016);
- lower byte ranges and classes to canonical byte sets;
- lower sequence alternatives into resumable prefix states;
- make cursor advancement explicit on every input edge;
- lower multi-step span endings into resumable internal states;
- lower callback outcomes into total numeric/symbolic dispatches;
- lower integer accumulation into explicit digit, fallback, overflow, and EOF control flow;
- assign field, callback, and span slots;
- retain a state-ID-to-source-name debug map;
- preserve enough metadata for interpreter traces and diagnostics.

Normalization must not perform speculative performance transformations in v0.1. It should produce the simplest correct execution graph. Optimization passes remain separate and disabled unless admitted through the benchmark policy.

## 18. Reference Interpreter

The interpreter executes verified source IR directly and shares the public runtime contract. It must not call the normalizer or execute normalized IR. This independence is intentional: interpreter/generated comparison must be able to catch incorrect sequence lowering, slot assignment, internal continuation construction, and other normalization defects.

Interpreter-private state may track progress inside a high-level source node, such as a sequence prefix or a pending span-end substep, but that representation must be derived independently from the production normalizer.

It prioritizes clarity and observability over speed. It should expose an optional trace hook for tests containing:

- node entry;
- cursor and stream offset;
- examined byte when applicable;
- selected edge;
- field changes;
- callback invocation and result;
- span start/fragment/end;
- lifecycle result.

The trace hook is not invoked unless explicitly enabled. Normal interpreter execution must not alter semantic callback ordering.

The interpreter is the authoritative oracle for generated code. It is not an oracle for whether the IR itself correctly models HTTP.

## 19. Portable Direct-code Backend

### 19.1 Initial strategy

Emit a wrapper-free Scheme body containing:

- one compiled-machine binding chosen explicitly by the caller;
- immutable field/callback/debug metadata;
- a direct resumable executor procedure;
- a dispatch loop over stable numeric node IDs;
- a `case` arm or equivalent direct code for each normalized node;
- calls only to the small runtime surface.

The generated executor must not traverse source/normalized graph objects or dispatch through a generic opcode VM.

Parser state is kept in local variables while executing and committed to the parser object at observable return/callback boundaries as required for callback access and exception safety.

### 19.2 Initial lowering choices

- Byte dispatch: portable `case`/conditional code over numeric bytes.
- Byte sets: canonical membership code selected for simplicity, not speculative density optimization (Milestone 3 lowers them to one transition per byte, leaving the encoding and the IR fingerprint in place — decision 0014).
- Sequences: explicit resumable prefix states (ordinary dispatch states, with the interpreter's own prefix representation derived independently — decision 0015).
- Field operations: generic exact arithmetic with declared-bound checks.
- Callbacks: direct indexed vector lookup.
- Counted consume: bulk cursor movement using available/count minimum.

### 19.3 Runtime dependency

Generated code may call stable runtime helpers for:

- parser storage/access;
- result construction/access;
- callback outcomes and callback lookup;
- lifecycle transitions;
- contract conditions;
- span boundary flushing;
- poison cleanup.

It may not call builder, verifier, normalizer, interpreter, or emitter code.

## 20. Deterministic Generation

For the same verified machine, compilation options, output binding, and generator version, generation must emit byte-identical UTF-8/LF source on every supported platform cell.

Requirements:

- declaration-derived stable ordering;
- deterministic internal state numbering;
- a project-owned canonical source writer;
- no dependence on hash iteration, object identity, `gensym`, or implementation `write` formatting;
- ASCII-safe emitted identifiers and explicit escaping;
- rejection of output bindings that collide with syntax or declaration identifiers reserved by the R6RS source mode, runtime exports, or emitted internal identifiers;
- no timestamps, hostnames, usernames, absolute paths, random data, or native details;
- embedded IR format version and generator version;
- embedded deterministic non-cryptographic IR fingerprint ([decision 0009](../decisions/0009-content-and-ir-fingerprints.md)) of canonical normalized IR and emission options;
- a final newline and fixed LF line endings.

The initial IR fingerprint may use a specified 64-bit FNV-1a calculation over the canonical encoding. It is an identity/debugging aid, not a security primitive.

`emit-machine` writes only to the supplied binary output port with `put-u8`. Generated source is canonical UTF-8 with LF bytes even on Windows. Atomic temporary-file creation and replacement belong to the caller's imperative build shell.

## 21. Private HTTP Request Fixture

### 21.1 Purpose

The fixture proves the machine primitives against realistic HTTP-shaped control flow. It does not promise RFC completeness, llhttp compatibility, security suitability as a production parser, or API stability.

### 21.2 Exact fixture grammar

The fixture uses this deliberately reduced byte grammar. It is not labeled RFC ABNF.

```text
request         = request-line header-section body
request-line    = method SP request-target SP version CRLF
method          = 1*tchar
request-target  = 1*target-byte
version         = "HTTP/1.0" / "HTTP/1.1"

header-section  = *header-field CRLF
header-field    = field-name ":" OWS field-value CRLF
field-name      = 1*tchar
field-value     = *field-value-byte
OWS             = *(SP / HTAB)

content-length  = 1*DIGIT *OWS
transfer-value  = case-insensitive("chunked") *OWS

body            = fixed-body / chunked-body / empty
fixed-body      = exactly content-length octets
chunked-body    = *nonzero-chunk last-chunk trailer-section CRLF
nonzero-chunk   = 1*HEXDIG chunk-ext CRLF chunk-data CRLF
last-chunk      = 1*HEXDIG-with-value-zero chunk-ext CRLF
chunk-data      = exactly decoded chunk-size octets
chunk-ext       = *(";" token ["=" token])
token           = 1*tchar
trailer-section = *trailer-field
trailer-field   = header-field

tchar           = ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" /
                  "'" / "*" / "+" / "-" / "." / "^" / "_" /
                  "`" / "|" / "~"
target-byte     = %x21-7E
field-value-byte= HTAB / SP / %x21-7E / %x80-FF
SP              = %x20
HTAB            = %x09
CRLF            = %x0D %x0A
```

After the colon, the fixture consumes all leading OWS before opening the header-value span. The span includes any trailing SP/HTAB because v0.1 has no lookbehind/trailing-marker primitive. An all-OWS value therefore produces an empty value span followed by completion.

Framing rules are intentionally strict:

- `Content-Length` and `Transfer-Encoding` names are recognized case-insensitively; ordinary header names remain opaque spans.
- Any second `Content-Length` is rejected, even if numerically identical.
- `Content-Length` permits only the grammar above and uses checked u64 decimal accumulation.
- Any second `Transfer-Encoding` is rejected.
- The only accepted transfer value is case-insensitive `chunked` followed by optional trailing OWS.
- Any request containing both recognized framing headers is rejected when the later header line completes.
- A request with neither framing header has an empty body.
- Chunk sizes use checked u64 hexadecimal accumulation and may contain leading zeroes.
- Chunk extensions support only token names and optional token values; quoted values and escapes are excluded.
- Trailer fields reuse the header grammar, but `Content-Length` and `Transfer-Encoding` are forbidden as trailer names.

### 21.3 Required event contract

The fixture trace contains these events in order where applicable:

```text
message-begin
method-data* method-complete
target-data* target-complete
version-complete
(header-name-data* header-name-complete
 header-value-data* header-value-complete)*
headers-complete
(nonzero chunks:
 (chunk-extension-name-data* chunk-extension-name-complete
  [chunk-extension-value-data* chunk-extension-value-complete])*
 chunk-header body-data* chunk-complete)*
(zero chunk, when chunked:
 (chunk-extension-name-data* chunk-extension-name-complete
  [chunk-extension-value-data* chunk-extension-value-complete])*
 chunk-header)
(trailer-name-data* trailer-name-complete
 trailer-value-data* trailer-value-complete)*
message-complete
```

Rules:

- `message-begin` occurs only when the first method byte is available, before that byte is consumed. Empty feeds and clean idle EOF do not start a message.
- Method and target spans end before their delimiter SP is consumed.
- Header/trailer name spans end before the colon is consumed.
- Header/trailer value spans exclude leading OWS, include trailing OWS, and end before CR is consumed.
- Completion callbacks occur after all data fragments for that logical span and before its delimiter is consumed unless stated otherwise.
- `headers-complete` occurs after the empty-line CRLF is consumed.
- Fixed-length body data uses one span with no span-complete callback. Each nonempty chunk payload uses a separate body span with no span-complete callback. Chunk framing octets are never body data.
- `chunk-header` occurs after every chunk-size line CRLF, including the zero chunk, and exposes the checked size field.
- Chunk-extension name/value spans exclude their `;`/`=` delimiters and complete before the next delimiter or CR is consumed.
- `chunk-complete` occurs for each nonzero chunk after the data-terminating CRLF is consumed. The zero chunk proceeds directly to trailers.
- `message-complete` occurs after the fixed body, the empty-body header terminator, or the final trailer-section CRLF has been consumed.
- Completion automatically resets explicit message fields and returns to request start without resetting the absolute stream offset.

### 21.4 Fixture errors and precedence

Stable fixture error codes include:

- `invalid-method`;
- `invalid-target`;
- `invalid-version`;
- `invalid-line-ending`;
- `invalid-header-name`;
- `invalid-header-value`;
- `duplicate-content-length`;
- `invalid-content-length`;
- `content-length-overflow`;
- `duplicate-transfer-encoding`;
- `unsupported-transfer-encoding`;
- `framing-conflict`;
- `invalid-chunk-size`;
- `chunk-size-overflow`;
- `invalid-chunk-extension`;
- `invalid-chunk-ending`;
- `forbidden-trailer`;
- `unexpected-eof`.

Lexical errors win at the first offending unconsumed byte. Numeric overflow points at the digit that would overflow and leaves it unconsumed. Duplicate/conflicting framing errors occur at the between-byte boundary after the later header line's LF. A forbidden trailer is reported at the colon following the completed forbidden name. EOF in any non-idle state reports `unexpected-eof` at the final stream boundary.

Before Milestone 8 implementation begins, tests must expand this catalog into a table mapping every fixture state family to its expected byte, boundary, or EOF error. The table is fixture-owned and does not become a generic byte-machine error catalog.

### 21.5 Fixture implementation constraint

The fixture must use only public graph, verification, compile, interpreter, and runtime APIs. All accept/reject choices, framing recognition, counters, and message-loop decisions live in declared graph nodes and fields.

Fixture callbacks may only:

- record observable events and copy span data for tests;
- inspect read-only fields;
- inject `continue`, `pause`, or explicit callback failure outcomes for lifecycle tests.

Callbacks may not parse header contents, select body framing, mutate machine fields, or repair invalid input. Private normalized-IR constructors and emitter/runtime internals are prohibited.

### 21.6 Required behavior summary

The final v0.1 fixture demonstrates request lines, strict headers, checked fixed-length framing, the reduced chunk grammar and trailers, automatic message looping, multiple requests in one feed, arbitrary feed division, clean EOF only while idle, and stable error categories/positions.

### 21.7 Intentional fixture exclusions

- responses and status lines;
- upgrades and CONNECT tunnel transition behavior;
- lenient modes;
- obsolete line folding;
- complete RFC request-target validation;
- all transfer-coding combinations;
- production-grade duplicate `Content-Length` normalization;
- keep-alive/connection policy;
- configurable server limits;
- request object construction;
- public HTTP names or packages.

Fixture files stay under `test/fixtures` and are never re-exported by a public byte-machine library.

## 22. Testing Strategy

### 22.1 TDD rule

Each behavior begins with a failing test. Valid executable semantics are not complete until equivalent tests pass through:

1. source-IR construction and verification;
2. independent verified-source-IR interpretation;
3. source emission;
4. generated parser execution;
5. interpreter/generated differential comparison.

Refactoring follows green tests. No optimization is mixed into initial semantic implementation.

Tests follow an ownership matrix:

- invalid source graphs stop after structured verification failure and are never interpreted or emitted;
- valid semantic features traverse verification, independent source interpretation, normalization, emission, generated execution, and differential comparison;
- emitter formatting and ABI tests exercise compilation/emission without pretending to be parser-semantic tests;
- runtime API/lifecycle misuse tests exercise the interpreter and generated runtime contracts at their owning layer;
- portability wrapper tests exercise values across library boundaries.

### 22.2 Dependency-free harness

Vendor a small portable test harness rather than rely on SRFI-64 or an implementation package manager.

Shared tests contain assertions and structured results. A thin Chez runner provides imports, process exit, and compilation steps.

Fixtures construct bytes numerically or from an ASCII helper. Never rely on checkout line endings to preserve HTTP CRLF.

### 22.3 Unit tests

Cover:

- every public constructor and accessor;
- descriptor immutability by API;
- verification pass successes and failures;
- structured diagnostic codes and paths;
- exact cursor advancement/reexecution;
- sequence prefix resumption and mismatch;
- field boundaries and overflow/underflow;
- callback result validation;
- span boundary, completion, pause, and error behavior;
- counted consume with zero, partial, exact, and surplus input;
- lifecycle transitions and sticky states;
- reset and message-local field reset;
- clean and truncated EOF;
- deterministic normalization and emission.

### 22.4 Interpreter/generated differential tests

For the same machine and feed schedule compare:

- result status;
- per-feed `next` and consumed count;
- absolute stream offset;
- final state and fields;
- callback order and results;
- exact span fragment ranges/content;
- pause continuations;
- error domain, code, public source-node name, absolute position, and position kind;
- stop/finish/reset behavior.

### 22.5 Fragmentation tests

For representative byte strings:

- test every single split point;
- include leading, trailing, and intermediate empty feeds;
- feed through nonzero bytevector start/end indices;
- reuse larger bytevectors containing unrelated prefix/suffix bytes;
- test selected pairs of split points for short messages;
- test deterministic random multi-split schedules.

Interpreter and generated execution must have identical fragment boundaries for the same schedule.

Across different feed schedules, compare a normalized semantic trace that coalesces fragments belonging to the same logical span. Fragment boundaries themselves are intentionally schedule-dependent.

For malformed inputs, cross-schedule assertions compare acceptance, error category, and absolute error position. A partial span may have been flushed by an earlier feed boundary in one schedule but not another, so invalid-input callback prefixes are compared exactly only between interpreter and generated execution using the same schedule.

### 22.6 Property tests

Use a deterministic in-tree pseudo-random generator and print the seed on failure.

Generate bounded small verified machines and inputs to compare interpreter/generated behavior. Include byte dispatches, reexecution, fields, callbacks, pauses, spans, EOF, and terminals as each feature becomes available.

Generate invalid graphs separately to exercise verifier rejection. Never use an invalid graph to test executor behavior.

### 22.7 All-byte tests

Exercise all 256 byte values for byte classes, complements, exact transitions, ASCII helpers, and emitted literal handling.

### 22.8 HTTP fixture tests

Cover positive and negative examples for each fixture feature, exact events and positions, every split point for representative messages, and pipelined combinations.

These expected HTTP traces are curated test expectations, not copied from or compared to llhttp.

### 22.9 Determinism tests

- Generate the same machine repeatedly in one process.
- Generate under separate processes.
- Generate under Chez in both the source and AOT lanes.
- Generate in every Tier 1 cell and compare output byte for byte across operating systems and architectures.
- Compile and execute each generated output.
- Exercise every permitted identifier character plus rejected punctuation, uppercase, non-ASCII names, and non-ASCII static labels.
- Reject every canonical reserved output binding under Chez, including portable syntax names, runtime exports, and emitter-template identifiers — scoped to the members that exist when the test runs (see §9.2 scoping note; Phase 2 covers member 1, Phase 3 members 2–3).

### 22.10 Test exclusions

- Do not compare implementation exception prose.
- Do not use benchmark thresholds as correctness assertions in v0.1.
- Do not make network access part of the normal test suite.
- Do not require llhttp, Node.js, direct C bindings, or the future HTTP project.

## 23. Benchmark and Optimization Policy

### 23.1 v0.1 baseline

v0.1 records compiled baselines but has no noisy CI performance gate.

Measure where supported:

- bytes per second;
- fixture requests per second;
- allocations or GC activity;
- generated source size;
- AOT-compiled artifact size;
- Scheme compile time;
- generation time.

Record:

- Chez version;
- source or compiled mode;
- compiler options;
- OS and architecture;
- CPU information when available;
- fixture and input size;
- warmup method, repetitions, median, and dispersion.

The committed baseline artifact includes canonical workload bytes, deterministic seeds, harness version, exact commands, raw samples, summarized statistics, and a distinction between required metrics and metrics unavailable on a runtime.

### 23.2 Workloads

- short normal requests;
- many small headers;
- long method/target/header spans;
- byte-at-a-time fragmentation;
- fixed-length bodies;
- chunked bodies;
- pipelined requests;
- early and late errors;
- dense byte dispatch and sparse byte dispatch microbenchmarks;
- long exact-sequence matching.

### 23.3 Admission rule

Transition tables, byte-class tables, trie specialization, sequence unrolling, peephole passes, or unsafe primitives require:

1. a reproducible compiled benchmark showing a repeatable material improvement on representative workloads or remedying a demonstrated performance problem;
2. results in both the source and AOT execution lanes;
3. results showing no significant regression on another supported platform cell;
4. unchanged public and observable parser semantics;
5. complete interpreter equivalence and conformance-suite success;
6. documented complexity and maintenance cost.

Do not set a percentage threshold until the v0.1 baselines establish normal variance. A single favorable microbenchmark is insufficient.

Before admitting the first optimization, add a decision record that derives working definitions of “material improvement” and “significant regression” from observed baseline variance. Revisit those definitions when the harness or supported runtime set changes.

## 24. CI and Build Strategy

### 24.1 Portable entry points

- Scheme test/generation programs are the source of truth.
- `make` may provide developer convenience on Unix-like systems.
- Windows must have native PowerShell or direct executable invocations; POSIX shell cannot be the only entry point.
- No network access is required after supported Scheme implementations are installed.

### 24.2 CI stages

1. Source formatting/static repository checks.
2. In every Tier 1 cell, assert the expected runtime, OS, and architecture.
3. In every Tier 1 cell, load values across the graph/verify/compile/runtime library boundaries.
4. In every Tier 1 cell, run shared source/interpreter unit tests.
5. In every Tier 1 cell, generate the fixture parser and retain its bytes for cross-cell comparison.
6. In every Tier 1 cell, perform applicable ahead-of-time compilation and run generated conformance/property tests.
7. Compare generated output across every Tier 1 OS/architecture cell.
8. Run benchmark smoke checks without pass/fail thresholds.
9. Build and execute documentation examples.

The dependency-free source suite remains separately runnable without ahead-of-time compilation.

### 24.3 Artifact discipline

- Never commit native compiler output.
- Keep version/OS/architecture outputs in distinct build directories.
- Commit generated fixture source only if a later workflow demonstrates that review value outweighs stale-artifact risk. v0.1 should generate it during tests by default.
- CI may retain generated source and diagnostics as failure artifacts.

## 25. TDD Implementation Milestones

Every milestone is a vertical slice with failing tests first. Later sessions should implement only one milestone or a clearly bounded subset at a time.

### Milestone 0: Portability and harness spike

Deliver:

- pinned minimum Chez version;
- confirmed R6RS library strategy — inline `.sls`, no includes ([decision 0006](../decisions/0006-inline-libraries.md));
- a cross-library smoke path where one provisional library constructs a placeholder tagged value, a second library recognizes it, and runtime singleton identity is retained across both imports;
- tiny portable test harness and runners;
- Scheme source-mode and ahead-of-time compile invocations;
- Tier 1 CI feasibility notes (discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md));
- documented Windows path and LF behavior (discharged by [the CI feasibility note](./milestone-0-ci-feasibility.md)).

Exit criteria:

- the same test program passes in both the source and AOT execution lanes;
- CI design covers unavailable local platforms;
- each library owns its own code — no shared include bodies ([decision 0006](../decisions/0006-inline-libraries.md)).

> **Closed 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).**
> Three deliverables this milestone did not ship — deterministic text emission,
> the identifier and binary-LF proof, and the CI pipeline — move to Milestone 1,
> where each has a subject: Milestone 0 ships no emitter, and the first two are
> properties of one. The first two left the Deliver list above with this change;
> the pipeline never had a line of its own — the list's only CI entry, "Tier 1 CI
> feasibility notes", is discharged rather than moved. See
> [the close-out](./milestone-0-close-out.md).

### Milestone 1: Minimal executable machine

> **Amended 2026-08-22 by [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md):
> Milestone 0's D6, D7, and D8 land here.** D6 on "deterministic output"; D7 on
> "symbolic name resolution" and "generated-name safety for every construct
> present". Those two lines already exist and now carry Milestone 0's obligations
> too. D8's CI pipeline has no Scope line of its own and rides D6's cross-cell
> axis, because both need the same Tier 1 cells: Milestone 1 stands the pipeline
> up over the emitter, and Milestone 9 below — whose Scope already owns "complete
> Tier 1 CI" and "source generation equality across platform cells" —
> completes it. "Complete" presupposes something to complete.

Scope:

- immutable machine/node/edge/error descriptors;
- symbolic name resolution;
- exact-byte dispatch with explicit fallback;
- advance/reexecute;
- stop and sticky error;
- minimal verification including reachability, zero-progress-cycle rejection, and generated-name safety for every construct present;
- minimal reference interpreter;
- minimal direct-code emitter and runtime;
- deterministic output;
- the required Chez end-to-end example from Section 9.6;

EOF is declared but not executed in this milestone. `make-machine` requires a machine-wide `default-eof-error` and §16.2 requires the verifier to check EOF targets, so Milestone 1 must construct and verify those declarations — but `parser-finish!` and EOF execution belong to Milestone 2. Keeping that line explicit stops the slice from absorbing EOF semantics along with the declarations that mention them.

First proving machine: accept one exact byte and stop; reject every other byte at the correct position.

Exit criteria:

- all 256 byte values tested;
- interpreter/generated results match;
- a graph descriptor can be constructed, verified, compiled, emitted, loaded, and run across the public library boundaries in both execution lanes;
- invalid names, targets, overlap, fallback, and terminals are rejected.

> **Closed 2026-08-23 by [milestone-1-design.md](./milestone-1-design.md)** —
> Gate 0 (PR #12, `9ca009c`), Phase 1 CI (PR #13, `e0aa377`), Phase 2 semantic
> core (PR #14, `59a6f85`), and Phase 3 Slice A (PR #16, `db3d3fd`) and Slice B
> (PR #17, `4eb16a3`). All four criteria are met against the shipped tree; that
> document's §6 dispositions each individually, below its own "Exit (full
> Milestone 1)" list. See CHANGELOG.md's Milestone 1 entries for the
> release-facing summary.
>
> **Annotated 2026-08-29**, six days after the close, not at it: Milestone 1
> closed without a note here, and the Milestone 2 close-out found the gap. The
> §6 disposition this note cites was written on the same later date and says so
> itself, rather than being dated back to the close.

### Milestone 2: Incremental execution and lifecycle

Scope:

- arbitrary slices;
- extend the Section 9.6 examples and their tests to feed a nonzero-offset slice;
- `need-input`;
- exact next/consumed/stream offsets;
- explicit pause node and continuation;
- resume;
- reset;
- finish and EOF edges;
- sticky stopped/error/finished states;
- API misuse and lifecycle conditions.

Exit criteria:

- every split point of short machines passes;
- empty and nonzero-offset slices pass;
- EOF distinguishes idle completion from truncation;
- lifecycle transition table is fully tested.

> **Closed 2026-08-29 by [milestone-2-design.md](./milestone-2-design.md).**
> All four criteria are met against the shipped tree; that document's §6
> dispositions each individually (below its own, more detailed five-item Exit
> list), including a review caught short at Task 7 close-out and a following
> self-review — the lifecycle transition table's `error`/`finished` ×
> `resume!` cells, and separately `finished` × `finish!`, were untested — and
> closed in the same pass, before this note was written. See CHANGELOG.md's
> Milestone 2 entries for the release-facing summary.

### Milestone 3: Byte classes and sequences

Scope:

- canonical byte sets, ranges, complements, and ASCII helper;
- byte-class overlap verification;
- exact sequence alternatives;
- prefix normalization and resumable internal states;
- mismatch positioning;
- ambiguous-prefix rejection;
- extension of zero-progress and EOF-cycle analysis to lowered sequence-prefix states.

Exit criteria:

- all-byte class tests pass;
- every sequence split and mismatch position passes;
- normalized output is deterministic;
- consuming cycles pass and zero-progress cycles fail verification.

> **Closed 2026-08-30 by [milestone-3-design.md](./milestone-3-design.md)** —
> Gate 0 and the design (PR #28, `f29edf7`, decisions 0014–0017), Slice ①
> byte classes (PR #30, `7d6ef3d`), Slice ② sequence dispatch and trie-shaped
> prefix lowering (PR #33, `819a5b1`), and Slice ③ multiple alternatives,
> ambiguity, and cycle analysis. All four criteria are met against the shipped
> tree; that document's own "Exit (full Milestone 3)" list dispositions each
> individually, naming the slice that discharged it and the file and case in
> the tree that meets it, and recording the three limitations this milestone
> closes over rather than glossing them. Scope bullet :1533 is discharged in
> **halves** — its EOF-cycle half in Slice ②, its zero-progress half in
> Slice ③ — and that disposition attributes it that way. See CHANGELOG.md's
> Milestone 3 entries for the release-facing summary.

### Milestone 4: Fields, actions, and branches

Scope:

- u8/u16/u32/u64 declarations and storage;
- store/clear/inc/dec/add;
- input-reading integer-accumulate nodes with digit, delimiter, overflow, and EOF paths;
- flag set/clear;
- equality, zero, range, and mask branches;
- field diagnostics and callback-visible field accessors.

Exit criteria:

- boundary, overflow, and underflow tests for every width;
- failed operations leave prior values unchanged;
- interpreter/generated fields and traces match.

### Milestone 5: Callbacks, poisoning, and spans

Scope:

- callback declarations and indexed binding;
- event and decision callbacks;
- continue/pause/branch/failure outcomes;
- unexpected escape poisoning;
- busy/reentrancy guards and callback-visible committed state;
- one active named span;
- boundary flush and completion;
- pause-safe span internal continuations;
- span dataflow verification.

Exit criteria:

- callback order and exact-once delivery tests pass;
- fragment tests cover boundaries, pause, completion, error, EOF, and reset;
- every invalid span topology is rejected;
- parser input-retention tests demonstrate no bytevector reference is stored by the runtime after return.

### Milestone 6: Counted consumption

Scope:

- bulk count-driven cursor movement;
- partial/exact/surplus feeds;
- span interaction;
- pause at body fragment boundaries;
- zero count;
- EOF truncation;
- counter type verification.

Exit criteria:

- counted consume does not dispatch once per body byte;
- field, cursor, fragment, and offset results match the interpreter for every case;
- surplus bytes continue immediately into the next node/message.

### Milestone 7: Verification and generative hardening

Scope:

- generative and diagnostic hardening of all mandatory verification passes already introduced with their owning constructs;
- structured graph paths in diagnostics;
- generated-identifier collision checks;
- bounded valid-machine generator;
- bounded invalid-machine generator;
- differential property suite;
- deterministic failure seed reporting.

Exit criteria:

- every required diagnostic has positive and negative tests;
- property suite runs in both execution lanes;
- minimized/reproducible failure fixtures can be saved without external tooling.

### Milestone 8: Private HTTP fixture

Implement incrementally:

1. request method and target spans;
2. HTTP version and strict request-line CRLF;
3. general header name/value spans;
4. headers-complete and no-body message loop;
5. case-insensitive fixture recognition of framing headers;
6. checked `Content-Length` and fixed body;
7. chunk size and chunk data;
8. chunk extensions, zero chunk, and trailers;
9. framing conflicts and malformed inputs;
10. pipelined requests and clean idle EOF.

Exit criteria:

- the complete fixture behavior in Section 21 passes;
- representative messages pass every split point;
- interpreter and generated traces match;
- the fixture remains private and no HTTP API leaks into public libraries.

### Milestone 9: Cross-platform hardening and v0.1 release

Scope:

- complete Tier 1 CI;
- source generation equality across platform cells;
- documentation and examples;
- baseline benchmarks;
- generated source readability review;
- generated hot-path allocation audit and fixnum-sized allocation baseline;
- changelog and release notes;
- license/header review;
- clean checkout build and test instructions.

Exit criteria: all criteria in Section 26 are satisfied.

## 26. v0.1 Release Criteria

Release `0.1.0` only when:

- every approved IR node has documented semantics;
- mandatory verification is complete and emission cannot bypass it through the public API;
- interpreter/generated differential tests pass;
- lifecycle, callbacks, spans, fields, offsets, errors, EOF, and counted consumption meet this plan;
- the private HTTP fixture meets its required behavior;
- representative fixture inputs pass every split point;
- deterministic generation passes across supported platform cells;
- every Tier 1 matrix cell passes its required source, generation, AOT-compilation, and execution checks;
- compiled benchmark baselines are recorded without speculative optimization;
- generated per-byte paths contain no deliberate list/vector/string/result construction, and fixnum-sized allocation measurements are recorded with callbacks disabled;
- public libraries and generated-runtime dependency boundaries are documented;
- examples generate, compile, and run from a clean checkout;
- `README.org` explains scope and quick start;
- `CHANGELOG.md` contains the `0.1.0` entry;
- no native build artifacts or unrelated HTTP/server code are committed.

## 27. Documentation Deliverables

Before v0.1, add:

- concise README quick start;
- source IR and builder reference;
- transition/cursor semantics reference;
- callback/span lifetime reference;
- field and overflow reference;
- verifier diagnostic catalog;
- generated-code integration guide for Chez;
- grammar-author testing guide;
- benchmark methodology and baseline report;
- portability matrix and pinned runtime versions;
- changelog.

Examples must use the public procedural API, not private tagged-vector constructors.

## 28. Risks and Mitigations

### Direct `case` performance differs between compilers

Mitigation: correctness-first portable emitter, compiled baselines, and benchmark-gated transition-table or specialized backends.

### Generated code becomes too large

Mitigation: measure source/native size, keep normalization simple, and admit compact tables only with representative evidence.

### u64 becomes a bignum on some runtimes

Mitigation: exact portable semantics first, explicit preflight overflow checks, compiled benchmarks, and no word-size assumptions.

### Pause repeats callbacks or loses bytes

Mitigation: normalize callback/span substeps into explicit continuation states and assert exact event traces and offsets.

### Span lifetime encourages accidental buffer retention

Mitigation: dynamic-extent contract, no bytevector field in parser storage, retention tests, and explicit consumer documentation.

### Sequence matching accidentally introduces backtracking

Mitigation: deterministic prefix lowering, no rewind operation, explicit mismatch semantics, and split/mismatch tests.

### Verification becomes monolithic

Mitigation: independent pure passes returning structured analyses and diagnostics.

### HTTP fixture turns into a second HTTP project

Mitigation: keep it private, retain the explicit exclusions, and move llhttp/RFC compatibility work to the separate parser repository.

### Cross-platform CI availability is incomplete

Mitigation: tiered support, document missing runners/toolchains, use portable test entry points, and avoid claiming untested combinations as release-gated.

### Determinism differs across Scheme writers

Mitigation: canonical project-owned encoding and emitter; never use implementation object rendering for generated source.

## 29. Deferred Extensions

The following require evidence from the separate HTTP project or benchmarks:

- thin `syntax-rules` grammar sugar;
- multiple concurrent or nested spans;
- reusable graph-fragment namespacing/composition;
- additional field types or opaque machine fields;
- custom action extension mechanism;
- transition tables or class tables;
- sequence/trie specialization and peephole optimization;
- Chez-specific emitters;
- unsafe arithmetic or bytevector operations;
- graph/DOT visualization;
- a serialized IR format;
- a general-purpose CLI;
- stable generated-source ABI beyond the runtime/IR version contract;
- warning policies for unreachable fragment nodes;
- a production HTTP grammar.

Every deferred performance feature is subject to Section 23. Every deferred semantic feature requires interpreter semantics, verification rules, generated parity, documentation, and tests before admission.

## 30. Early Spike Questions

These are implementation facts to resolve in Milestone 0, not open architecture decisions:

1. Which minimum Chez release reliably provides the selected module/include and bytevector surface?
2. What exact source and native compiler commands work consistently on each Tier 1 platform?
3. How should relative includes and library search paths be arranged on Windows?
4. Which condition construction is available to consumers? *(Moot: it is plain R6RS `condition`/`raise`; no wrapper layer exists to expose anything else.)*
5. Which allocation/GC metrics can the benchmark harness collect consistently?
6. What identifier length and source-size limits appear in supported compilers?
7. Does the initial direct `case` layout reveal a correctness-neutral compiler issue requiring an early portable layout adjustment?

Answers must be recorded in documentation and tests. They do not authorize implementation-specific semantics or backends.

## 31. Handoff Rules for Later Sessions

Before implementing a milestone, a later session should:

1. Read this plan and the parent HTTP server architecture.
2. Confirm the previous milestone's exit criteria.
3. Select one bounded vertical slice.
4. Add failing tests first.
5. Implement reference semantics before or alongside generated semantics.
6. Run the shared suite in every locally available implementation mode.
7. Record unavailable matrix coverage rather than assuming it passed.
8. Avoid deferred features unless their admission criteria have been satisfied.
9. Update documentation when a public contract becomes executable.
10. Add the appropriate `CHANGELOG.md` entry for a release.

The plan favors a small, explicit machine whose correctness is easy to inspect. Generality and specialization are earned by the real HTTP parser and measured performance, not anticipated in advance.

---

## Dated dispositions (appended; this section never shifts a line above it)

Every citation in this repository navigates by `§section:line`, and the design
document and the Milestone 4 decision records carry dozens of them into the
sections above. An insertion anywhere in the body silently re-numbers all of
them — measured: a ten-line note inserted at §25:1570 moved `§25:1572`
(cited by decision 0022 for "callbacks are Milestone 5") and `§29:1754` (cited
by the Milestone 4 design for deferred field types) onto unrelated text.
**Dispositions are therefore appended here, never inlined.**

### §25:1570 — "interpreter/generated fields and traces match"

**2026-09-02, Milestone 4 Slice ①a.** The criterion is **not reworded**; it
stands exactly as written above. §18:974-985 makes the trace hook
interpreter-only and opt-in, so generated code has no trace surface at any
milestone and a literal cross-lane trace comparison is unspecifiable. The
criterion is discharged through §22.4:1262-1272's comparison list, of which
:1271 is the error bullet.

Slice ①a discharges **:1271's error clause** — error domain, code, public
source-node name, absolute position and position kind, compared across
executors in `test/common/position-kind-tests.sps` and in the sixteen
differential lanes through `(byte-machine test error-projection)`. The
`fields` clause (§22.4:1267) is Slices ①b, ② and ③.

### §25:1572 / §25:1611 — Milestone 5 Slice ⓪, a hardening slice before Milestone 5

**2026-09-03, after Milestone 4 closed.** Neither milestone's scope above is reworded; this
records a slice inserted *before* Milestone 5's work begins, and why it is not simply Milestone
7's.

Milestone 4 Slice ③ shipped **three verifier defects** — two Critical — that 368 mutations, a
50-pass suite, a clean whole-pass pin sweep and ten per-task gates all missed. All three are one
shape: a new node kind reached the shared accessors (`node-eof-target`, `node-out-targets`) and
not the **hand-written per-kind filters** that consume them, where a missing kind is silent. One
raised out of verification on a legal machine; one accepted a machine that then looped forever in
both executors, under a runtime comment stating it relies on that very check for termination.
Every fixture missed all three *by construction*.

**Milestone 7 (§25:1611) keeps its scope unchanged** — it already names *bounded invalid-machine
generator*, *differential property suite* and *deterministic failure seed reporting*, and those
stay there. Slice ⓪ is the part M7 does not own: a **deterministic kind × position matrix** over
the verifier, plus the **diagnostic-code coverage ratchet**. The ratchet comes forward because
Milestones 5 and 6 each add diagnostic codes, and a sentinel that fails until a new code has
fixtures must precede them; the generator does not, and building its corruption catalogue now
would build it twice.

Measured before planning: **230 cells over six axes**; only **two** rules in the whole verifier
are sensitive to a target's kind; "impossible by construction" is **empty** on the kind axis,
because no node constructor can see a target's kind. Instrument validated by injecting 38
single-kind omissions into a copy of `verify.sls` — **34 distinguished, including all three
shipped Slice ③ defects**.

The design found **two live, pre-existing verifier holes**, both reproduced byte-identically on
`main` and so not Slice ③ regressions:

1. **`machine-entry`'s own EOF path is never classified.** `eof-terminal` is called from exactly
   two sites and `machine-entry` is neither, though `parser-finish!` starts precisely there.
   `entry = a stop node` verifies with zero diagnostics and returns `stopped`, while the same
   property one hop away is correctly rejected with `eof-reachable-stop`. §16.2:909 forbids it by
   name. **The fix is deliberately out of Slice ⓪'s scope**: prototyped, it changes 85 of 230
   cells, mostly double-reporting, which collides with §16.4:937-943's one-finding-per-decision.
2. **`verify.sls`'s `eof-zero-progress-cycle` site for pause continuations is dead in the tree.**
   Deleting it leaves all 26 runnable programs byte-identical. It is the only site that can see a
   cycle beginning at a pause continuation with no dispatch eof-target involved, and the runtime
   relies on it for termination. Slice ⓪ Task 1 closes it.

Five open questions are recorded rather than guessed, two of them about this document's own
sections: whether §16.2:908 forbids *starting at* a finish terminal (`entry = finish` verifies
clean today), and that **the two halves of §16.2:908 contradict each other** — the check is
unconditional at one site and byte-reachability-gated at two others, so an EOF-only-reachable
pause is accepted where an EOF-only-reachable dispatch case is rejected. Whichever half is right,
the other is wrong. Also recorded: diagnostic multiplicity is **not** one per decision (a
field-branch with both arms on one finish node emits `non-eof-into-finish` twice), and **four of
the six EOF verdicts carry no observable consequence** — four independent mutations of the
ranking survive all 230 cells.

Full plan: `docs/plans/milestone-5-slice-0-implementation-plan.md`.

### §16.2:908 / §16.2:909 — Milestone 5 Slice ⓪b, the EOF walk cluster

**2026-09-03.** Neither §16.2 bullet is reworded; this records a second hardening slice, after
Slice ⓪ and before Milestone 5's own work, and one finding that changes how :908 must be read.

**§16.2:908's two halves contradict each other in the shipped verifier.** The check exists at
three sites under two gating rules — one unconditional, two gated on byte-reachability. Measured
on six machines whose offending node is reachable ONLY as an eof-target: pause, field-action and
field-branch are accepted; byte-dispatch, sequence-dispatch and integer-accumulate are rejected.

**Resolved in favour of the gated reading, and the evidence is decisive in both directions.**
Applying the unconditional reading uniformly breaks five shipped programs, and the refusal names
`pe` — the shipped pause machine's EOF-only pause whose continuation is a finish node, which is
**decision 0011's canonical legal shape**, named in that fixture's own header. The unconditional
rule, applied consistently, rejects the machine 0011 was written to permit. The gated reading
leaves every byte-reachable offender of all six kinds still rejected.

**Decision 0021 item 5's stated reason is false.** It splits the kinds by "reads input" versus
"zero-width"; a byte-dispatch, a sequence-dispatch and an accumulate node can each be
EOF-only-reachable, and then their byte edges are never traversed by any execution. Slice ⓪b
annotates 0021 rather than correcting it in place, per AGENTS.md's rule for a sentence that was
never true, and opens decision 0023 for the affirmative rules.

**A rule cited fourteen times in this repository does not exist.** "One finding per decision" is
not in §16.4:937-943, which is a contents list with no cardinality clause; the gloss entered at
`milestone-3-slice-1-implementation-plan.md:139` and propagated. It was the stated reason for
keeping Slice ⓪'s D-1 fix out of scope. What §16.4:940 *does* require — an edge or source label
beside the node — is implemented nowhere: `make-diagnostic` takes three arguments at all 31 call
sites. Slice ⓪b adds it, keyed on edge ROLE rather than index, because `verify.sls:380-386`
explicitly declines to promise the order of two diagnostics from one node.

**The `85 of 230` figure in this section's Slice ⓪ disposition is skeleton-dependent and should
not be relied on.** The identical prototype measures 51/144 under one skeleton and 4/144 under
another; and "most of it double-reporting" is not corroborated — a third of the changed cells are
duplicates, two thirds are new coverage. A figure of this kind must name its skeleton.

Full plan: `docs/plans/milestone-5-slice-0b-implementation-plan.md`.

### §16.2:908 / §16.2:909 / §16.4:940 — Milestone 5 Slice ⓪b, delivered

**2026-09-03.** The disposition above recorded Slice ⓪b as planned; this records what it
did. Neither §16.2 bullet is reworded, and §16.4:937-943 is not either — see the third
item, which is about a rule that was never there.

- **:908 is one derived block gated on byte-reachability**, replacing three hand-written
  sites that disagreed with each other. Its half of `pass-eof-execution` now names **one**
  kind predicate where it named six, and `node-out-edges` is the single census it consults.
  The entry is a subject of the rule: `entry = a finish node` is rejected, reusing the
  existing code with no new one.
- **:909 walks the states a parser can be PARKED on**, the entry among them — closing a
  hole in which `entry = a stop node` verified with zero diagnostics and `parser-finish!`
  returned `stopped`. Because the start set is a **set**, no machine double-reports.
- **§16.4:940's edge/source label is implemented**, carrying a role rather than an index.
  The "one finding per decision" rule cited against these checks **does not exist** in
  §16.4:937-943, which is a contents list; the gloss entered at
  `milestone-3-slice-1-implementation-plan.md:139` and propagated to fourteen sites.
- **The EOF verdict order is three tiers.** Four of the six undecidable verdict relations
  were acceptance holes — with `default-error` above `cycle`, a machine verifies clean and
  never terminates.

Recorded in **decision 0023**; decision 0021 is **annotated** at two sentences that were
never true, per this repository's rule for a record rather than an instruction.

**Left open deliberately, and not to be read as closed:** `pass-reachability` walks
`all-out-targets`, so a node reachable only through an untakeable EOF edge counts as
reached. The old :908 filter was answering that question by accident; it is its own §16.2
question and now has no accidental answer.

Plan: `docs/plans/milestone-5-slice-0b-implementation-plan.md`.

### §25:1611 — Milestone 5 Slice ⓪, delivered

**2026-09-03.** Milestone 7's scope is unchanged; this records what the hardening slice before
Milestone 5 actually built, and one thing it deliberately did not.

- **A diagnostic census** derived from the artifact: `verify.sls` is read as a datum and walked
  for emission sites, so the code set, the per-code site counts and the fourteen operand names
  are never declared in a test. It ships **green** — it would not have caught any of Slice ③'s
  three defects, and the plan says so — and its value is the ratchet: a new code, or a new site
  under an existing code, fails it until accounted for. It fired **four times** during Slice ⓪b,
  each on the commit that moved it.
- **A kind × position matrix**: 144 cells over nine kinds and sixteen positions, plus 19
  self-reference cells, 15 dangling cells, a 16-entry absence census and a 25-cell verdict
  lattice. Expected verdicts are **derived from §16.2 before the machine is run**, never
  observed — the mandate that would otherwise have frozen four live defects into an artifact
  reading as authoritative.
- **The operand-schema drift row**, which closes an unchecked agreement between two files whose
  own comment called a mismatch "unreachable through the public API" — verbatim the shape of
  Slice ③'s first Critical.

**Two ordering facts worth keeping.** The slice was **reordered mid-flight**: Tasks 2–5 were
scheduled before Slice ⓪b and moved after it, because the stated reason for the original order
— that fixing D-1 would collide with §16.4:937-943's one-finding-per-decision — rested on a rule
that **does not exist** in §16.4. Run in the new order, all 144 cells matched on the first clean
run; in the old order, four would have been red on arrival. And the matrix was measured
**unable to witness ⓪b's central decision** (the byte-reachability gate moves zero cells), so it
never was the instrument that justified the wait.

**Axes E and F of the plan are not built**, recorded here rather than left as an unticked box:
their purpose was converting Slice ③'s defects from raise-caught to comparison-caught, and ⓪b
removed those raises at the source.

Plan: `docs/plans/milestone-5-slice-0-implementation-plan.md`.

### §25:1568-1570 — Milestone 4's close note, written 2026-09-04, two days late

**Milestone 4 (fields, actions, and branches) closed 2026-09-03** with Slice ③
(integer accumulation), after Gate 0 (2026-08-31, decisions 0018-0022), Slice ①a
(2026-09-02), Slice ①b (2026-09-02) and Slice ② (2026-09-03).

**It closed without a close note, and nothing noticed for two days.** Milestones 0
through 3 each carry one as a §25 blockquote; Milestone 4 has none, and the top
`Status:` line went on describing it as *in progress with Slices ①b, ② and ③
remaining* through four merged PRs. This is the same gap the Milestone 1
blockquote already records ("Milestone 1 closed without a note here, and the
Milestone 2 close-out found the gap") — found the second time by a *slice's*
closing ritual rather than the next milestone's, because Milestone 5 has not
started. The note is written here rather than as a §25 blockquote for the reason
this whole section exists: an insertion at §25 re-numbers every `§section:line`
citation below it.

The three exit criteria, dispositioned against the tree rather than against the
slice plans:

- **:1568 — boundary, overflow, and underflow tests for every width.** Discharged
  by `test/common/field-access-tests.sps`'s operation matrix, which builds one
  machine per width from `matrix-widths '(8 16 32 64)` with `hi` seeded at
  `2^w - 1` and `lo` at `0`, and drives increment-at-max, add-at-max and
  decrement-at-zero through both executors. Its sentinels read observed counts
  (4 widths, 16 schedules). A separate case asserts the u64 maximum exceeds
  `greatest-fixnum`, so that row cannot silently degrade to a fixnum row on a
  host with a wider fixnum (§15:856).
- **:1569 — failed operations leave prior values unchanged.** Discharged by the
  same group: each overflow and underflow row asserts the field's value *and*
  that the lifecycle routed to the error target, with a success control (`lo`
  becomes 1) without which every bound row would pass on a machine that never
  writes.
- **:1570 — interpreter/generated fields and traces match.** Already dispositioned
  above: the trace half is unspecifiable (§18:974-985 makes the hook
  interpreter-only), so the criterion is discharged through §22.4:1262-1272's
  comparison list — the error clause (:1271) by Slice ①a, the `final state and
  fields` clause (:1267) extended by Slices ①b, ② and ③ in turn. The per-slice
  accounting is in `docs/plans/milestone-4-design.md`.

**What Milestone 4 shipped that its criteria do not mention.** Slice ③ shipped
three verifier defects — two Critical — past 368 mutations, a 50-pass suite and
ten per-task gates, all one shape: a new node kind reached the shared accessors
and missed a hand-written per-kind filter. That is why Milestone 5 opened with
two hardening slices rather than with its own scope, dispositioned above.
