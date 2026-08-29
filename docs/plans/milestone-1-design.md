# Milestone 1 Design — Minimal Executable Machine

Status: design — approved shape, **delivered** (Milestone 1 complete as of
2026-08-23; see the dated note below). Authored 2026-08-22,
the day Milestone 0 closed (PR #11, [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md)).

**Milestone 1 complete as of 2026-08-23**, and merged to `main`. Gate 0
(decisions [0008](../decisions/0008-emitter-emits-importable-library.md) and
[0009](../decisions/0009-content-and-ir-fingerprints.md), PR #12, `9ca009c`),
Phase 1 CI (PR #13, `e0aa377`), Phase 2 semantic core (PR #14, `59a6f85`), and
Phase 3 Slice A (PR #16, `db3d3fd`) and Slice B (PR #17, `4eb16a3`) are all
delivered and reviewed; §6's dated disposition (below its Exit list) states each
of the four full-M1 exit criteria's individual state against the shipped tree —
parent §25's are the same four criteria (its item 2 says
"interpreter/generated" where §6 says "interpreter and generated"), so that
disposition covers both. See CHANGELOG.md's Milestone 1 entries for the
release-facing summary.

**This paragraph and the §6 disposition were written 2026-08-29**, six days
after the close, not at it. Milestone 1 shipped without either: its Phase 3
Slice B plan sent the exit-criteria confirmation to a task report rather than to
a committed document, so nothing in the tree said the milestone had closed. The
Milestone 2 close-out found the gap and it is repaired here rather than dated
back — the tree these notes were checked against is stated in each.

Governing plan: [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md) §25
("Milestone 1: Minimal executable machine"). This document does not change M1's
*scope*; it re-cuts M1 *internally* into an explicit, ordered set of phases and
resolves the design calls the M0 close-out handed forward. Where this document and
§25 differ in wording, §25's Scope list remains authoritative and this document
records how that scope is sequenced and delivered.

## 1. Summary

Milestone 1 turns the harness Milestone 0 built into a working product for the
first time. Its proving machine is the smallest one that exercises the whole
pipeline: **accept one exact byte and stop; reject every other byte at the correct
position, across all 256 values.**

M1 remains **one milestone and one vertical slice** — it still ends at
generated-and-executed output — but it is delivered in four ordered phases:

| Phase | Kind | Produces | Discharges |
| --- | --- | --- | --- |
| **Gate 0** | decisions only | 2–3 records/notes | the inherited design calls |
| **Phase 1 — CI** | infrastructure | a running pipeline over today's harness | spike §7 D8 (pipeline half) |
| **Phase 2 — Semantic core** | product | descriptors, resolver, verifier, reference interpreter; the one-byte machine runs *through the interpreter*, no code generation | most of §25 Scope |
| **Phase 3 — Generation** | product | normalizer, emitter, runtime ABI; the §9.6 end-to-end example; interpreter≡generated | spike §7 D6, D7; "deterministic output" |

Dependency order is strict. Gate 0 unblocks everything. CI is pure infrastructure
and rides underneath the product work. The Phase 3 emitter is **differentially
tested against the Phase 2 interpreter**, so the interpreter must exist and be
trusted before the emitter is meaningful — which is why "semantic core" precedes
"generation" rather than the two being built together.

The roadmap numbering is unchanged: M2–M9 keep their numbers. Splitting M1 into
two milestones was considered and rejected, because a "semantic core" milestone
would be the first milestone that generates no code — a departure from the plan's
"every milestone is a vertical slice" invariant — and it would renumber the whole
roadmap and every cross-reference.

## 2. Why this revision

Read literally, §25 lands the entire architecture pipeline
(builder → IR → verifier → interpreter → normalizer → emitter → runtime), plus
the project's first CI, all at once, on a codebase that as of M0's close carries
~87 lines of placeholder product code under an ~8,500-line harness. That is the
largest single step in the project. This revision keeps the scope but sequences it
so that:

- the design calls that shape the emitter's output contract are settled *before*
  any code depends on them (Gate 0);
- CI stands up *first*, over the harness that already exists, so every later M1
  slice runs on real Tier-1 cells rather than resting — as everything does today —
  on a single developer host;
- the semantic core is proven through the reference interpreter *before* the
  emitter it will be the oracle for is written.

## 3. Gate 0 — design-call resolutions

These are decision-only. No product code is written in Gate 0. Each becomes a
record or a scoping note so later phases cite a settled decision rather than
re-deriving it.

### 3.1 The include collapse — the emitter writes a complete importable `.sls`

§9.6 step 5 requires the end-to-end example to *include* the generated body from a
consumer library wrapper; [§7.2 / decision 0006](../decisions/0006-inline-libraries.md)
forbid any Scheme file including another. The conflict is real and is a design
call, not a wording fix.

**Resolution.** The emitter emits a **complete R6RS `.sls` library** — it owns the
generated library name and export list, imports only `(byte-machine runtime)`, and
contains the machine body. The consumer composes it with `(import (…))`, never with
`include`. §9.6 step 5 is rewritten from "including that generated body" to
"importing the generated library." This aligns with §9.5, whose runtime-ABI export
"exists so a generated wrapper-free body works when its consumer imports only
`(byte-machine runtime)`": "wrapper-free" is read as *needs no hand-written
wrapper* — the generated file is itself the importable library.

A human-authored wrapper library that imports the generated library and re-exports
it under a chosen public name (the alternative considered) remains possible later
without changing this contract; it is additive and out of M1's minimum.

This resolution is recorded as a new decision record (next free number in
`docs/decisions/`). §9.5's "wrapper-free body" and §7.1's "generated bodies"
wording are reconciled there to mean "a self-sufficient generated library."

### 3.2 Two meanings of "fingerprint" — name them apart

The harness already ships a *content* fingerprint (rolling hash mod 2⁶¹−1 over a
lane's manifest text). §20 introduces a *second*, unrelated fingerprint over the
canonical normalized IR (permitted to be 64-bit FNV-1a). One word, two objects.

**Resolution.** Keep the shipped one as the **content/manifest fingerprint**; name
§20's new one the **IR fingerprint**. Phase 3 introduces the IR fingerprint; every
site that says "fingerprint" from that point on names which it means. Recorded as a
decision record or a documented naming note (writing-plans decides which; a record
is preferred if any shipped text must be amended).

### 3.3 Reserved-output-binding rejection — scope to members that exist when tested

§9.2's reserved-output-binding set has three members: (1) R6RS source-mode
syntax/declaration identifiers, (2) `(byte-machine runtime)` exports, (3) the
emitter template's own identifiers. Only member 1 is enumerable before M1 builds
anything.

**Resolution.** Generated-name-safety verification grows across the phases: it
checks member 1 in Phase 2; members 2 and 3 come into scope in Phase 3 once the
runtime exports and the emitter template exist. §22.9's "Reject every canonical
reserved output binding under Chez" is scoped, at each point, to the members that
exist when the test runs. Recorded as a scoping note carried into the relevant
phases.

## 4. Phase 1 — CI (spike §7 D8, pipeline half)

The written feasibility notes half of D8 shipped in M0
([milestone-0-ci-feasibility.md](./milestone-0-ci-feasibility.md)). This phase
stands up the pipeline itself. No CI has ever run in this repository.

**Deliver.**

- A pipeline (GitHub Actions) that runs the existing suite (both ctest presets) on
  the two Tier-1 cells obtainable today: **macOS arm64** and **Linux amd64**.
- **Close the carried-forward assertion gap.** `harness-self-tests.sps` and
  `harness-bootstrap.sps` currently assert `adapter-os` / `adapter-architecture`
  are merely *not "unknown"*. Change them to assert *equal to the expected value*
  (parent §24.2), so a mis-mapped adapter table row fails on the cell that would
  expose it.

**Out of this phase.** The two deferred cells — Linux arm64 and Windows amd64 —
are not added here; parent §25 Milestone 9 completes the Tier-1 matrix. Their M0
feasibility notes stand.

**Exit.** The pipeline is green on both cells; the adapter assertions are exact
(equality, not not-"unknown").

## 5. Phase 2 — Semantic core (no emitter, no generated code)

Everything needed to construct, verify, and *interpret* the one-byte machine, with
no code generation. The one-byte machine is proven entirely through the reference
interpreter here; generation is Phase 3.

**Deliver.**

- **Descriptors** for the one-byte machine: `make-machine` (including the mandatory
  machine-wide `default-eof-error`), an exact-byte dispatch node, a stop node, and
  an error node. Constructors validate local shape only and return
  immutable-by-API descriptors; cross-reference and graph checks belong to the
  verifier (parent §7, §10).
- **Symbolic name resolution.** Targets are referenced by name; the resolver binds
  names to descriptors and rejects unknown targets and duplicate names.
- **Minimal verifier** (`verify-machine` → structured diagnostics, parent §9.2,
  §16): reachability; zero-progress-cycle rejection; generated-name safety
  (reserved-set member 1 per Gate 0 §3.3, names conforming to `[a-z][a-z0-9-]*`);
  exact-byte overlap/determinism; explicit-fallback presence; terminal
  well-formedness; and **EOF-target verification (§16.2) — EOF declarations are
  constructed and verified, but not executed.**
- **Minimal reference interpreter.** `make-interpreted-machine` returns a
  runtime-compatible compiled machine. All 256 byte values run through it: the one
  accepted byte advances and stops (accept); every other byte drives a sticky
  error at position 0.
- **Runtime result singletons.** Per §7.2, `interpret` depends on `runtime`
  because interpreted outcomes must be the runtime's *own* singleton values — were
  they distinct objects, interpreter and generated execution could disagree while
  each looked correct in isolation, the exact defect the differential tests exist
  to catch. So the **result-singleton portion of `(byte-machine runtime)` lands in
  Phase 2**; the generated-code ABI binding waits for Phase 3. "No code
  generation" is exact here; "no runtime at all" is not.

**Exit.** All 256 byte values produce the correct interpreter result; invalid
names, targets, overlap, fallback, and terminals are rejected with structured
diagnostics; EOF declarations are constructed and verified without being executed.

## 6. Phase 3 — Generation (spike §7 D6, D7; "deterministic output")

The emitter, the runtime ABI, the determinism and identifier proofs, and the
required end-to-end example. This phase is the heavy one and is expected to
sub-split at writing-plans time (see §8).

**Deliver.**

- **Normalizer.** Verified IR → canonical normalized private IR in deterministic
  order; the **IR fingerprint** (FNV-1a, Gate 0 §3.2) is embedded (parent §20).
- **Emitter** (`emit-machine`). Writes a complete importable `.sls` (Gate 0 §3.1)
  to *the supplied binary output port only* (parent §20). The generated library
  imports only `(byte-machine runtime)`, calls
  `byte-machine-make-compiled-machine/v1`, and embeds the required runtime-ABI and
  IR/emitter versions (parent §9.5).
- **Runtime ABI.** Add `byte-machine-make-compiled-machine/v1`, the embedded
  version handling, and the portable ABI-mismatch condition to
  `(byte-machine runtime)`. Generated-name safety now extends to reserved members
  2 and 3 (runtime exports, emitter-template identifiers), which now exist.
- **D6 — deterministic output.** Parent §22.9's first five checks: repeat in one
  process; repeat across processes; both Chez lanes; every Tier-1 cell
  byte-for-byte (on the two cells CI provides — M9 completes); compile-and-execute
  the result. Comparison is by the IR fingerprint through the project-owned writer,
  never via implementation `write` formatting.
- **D7 — identifier repertoire and binary LF.** Accept `[a-z][a-z0-9-]*`; reject
  uppercase, non-ASCII, and punctuation. Prove LF bytes survive a binary output
  port unmodified. **Limitation:** the genuine Windows CRLF-translation trap only
  manifests on a Windows cell, which M1 CI does not have, so the LF-write proof
  runs where it is trivially clean; the real Windows proof rides to M9 with that
  cell. The fingerprint *reader* already opens binary (shipped in M0).
- **The §9.6 end-to-end example**, one executable Chez program run in both the
  source and AOT lanes: construct a one-byte machine only through
  `(byte-machine graph)`; verify; compile without runtime evaluation; emit the
  `.sls` to a binary file port; the consumer `(import`s the generated library and
  only `(byte-machine runtime)`; construct a parser, feed the exact `[0,1)` slice,
  inspect the result; compile and run the consumer ahead of time. Tool commands are
  copied verbatim from Milestone 0; there is no include-path setup.
- **Interpreter ≡ generated** differential across all 256 byte values.
- **Delete the M0 placeholder libraries** `placeholder.sls` and
  `placeholder-consumer.sls` (spike §11).

**Exit (full Milestone 1).**

- all 256 byte values tested;
- interpreter and generated results match;
- a graph descriptor can be constructed, verified, compiled, emitted, loaded, and
  run across the public library boundaries in **both** execution lanes;
- invalid names, targets, overlap, fallback, and terminals are rejected.

> **Dispositioned 2026-08-29, recording the close of 2026-08-23.** These four,
> and parent §25's same four, checked individually. Written six days after the
> close because none was written at it (see the header note), so each row
> below was read against two trees: `4eb16a3`, the tree Milestone 1 closed on,
> and HEAD, which now carries Milestone 2. Every case name cited is present
> unchanged in both, and the ten lanes named below are registered in both (60
> lanes then, 72 now). The suite was *run* at HEAD only — 72/72, no failures, on
> the pull-request selection (`make test`, 2026-08-29, Milestone 2 Slice ③ tip);
> `4eb16a3` was read, not re-run, and this disposition claims nothing more about
> it than the text it contains.
>
> (1) **met**: `interpret-tests.sps`'s "all 256 byte values" group, and
> `differential-one-byte-tests.sps`'s "all 256 byte values match" case — the
> byte range is walked, not sampled.
> (2) **met**: `differential-one-byte-tests.sps`'s "interpreter and generated
> agree on every byte" group, which emits the generated library at run time,
> loads it, and compares `parser-result` fields from both executors through the
> one shared `make-parser`/`parser-feed!` API.
> (3) **met**: `example-one-byte-tests.sps`'s "construct, verify, compile, emit,
> import, run" group — parent §9.6's example — specifically its case "the
> emitted parser accepts the exact byte across the library boundary", which
> compiles, emits to a binary file port, loads the emitted file, and reaches the
> compiled machine only through `(environment '(generated one-byte))`. That case
> is the Milestone 1 evidence and is the group's only case at `4eb16a3`; the
> second case beside it at HEAD, the nonzero-offset slice, is Milestone 2's and
> is not claimed here. "Both execution lanes" is the registered pair
> `byte-machine.example.one-byte.{chez.source,chez.aot}`, two lanes over one
> program, not one lane run twice.
> (4) **met**: `verify-tests.sps`'s "rejections, one per decision" group covers
> each named class — names (three `invalid-name` cases: machine, node, and
> error code), targets (`missing-target`, on the entry and on a fallback edge),
> overlap (`overlapping-cases`), fallback (the same fallback-edge case; an
> *absent* fallback has no rejection case because it cannot be built —
> `make-byte-dispatch-node` takes the fallback positionally and raises
> `invalid-argument` for anything that is not an `edge?`, identically at
> `4eb16a3` and HEAD), and terminals (`missing-error-declaration` and
> `invalid-eof-target`, the EOF declaration M1 verifies without executing).
> `identifier-repertoire-tests.sps` adds D7's exhaustive `[a-z][a-z0-9-]*`
> accept/reject proof at both grammar sites.
>
> Not claimed here: the mutation suite, which is not in the pull-request
> selection re-run above. Its Milestone 1 state is the one CHANGELOG.md's
> Milestone 1 Phase 3 Slice B entry records.

## 7. Explicitly out of Milestone 1

- **EOF execution** — `parser-finish!` and EOF edges — is Milestone 2. M1 only
  constructs and verifies EOF declarations (kept explicit so the slice does not
  absorb EOF semantics).
- **All HTTP, libuv, and TCP work** belongs to the separate downstream project (the
  protium replacement, see [chez-http-server-architecture.md](./chez-http-server-architecture.md)
  and decision 0005). It appears in this repository only as the private HTTP
  fixture in Milestone 8.
- **Linux arm64, Windows amd64, and the real Windows CRLF proof** are Milestone 9.
- **Byte classes, sequences, fields, actions, branches, callbacks, spans, and
  counted consumption** are Milestones 3–6.
- **`define-machine` sugar, transition-table / trie specialization, a serialized IR
  format, and a general-purpose CLI** are parent §29 deferrals, gated on benchmark
  or downstream-HTTP evidence.

## 8. Handed to writing-plans

- **Phase 3 sub-split.** Phase 3 is expected to split into at least two slices —
  "emitter + runtime ABI + end-to-end happy path" then "D6 / D7 hardening +
  interpreter≡generated differential" — with failing tests first per the project's
  TDD discipline.
- **Gate 0 record forms.** The include-collapse resolution (§3.1) is a new decision
  record; the fingerprint naming (§3.2) is a record or a documented note; the
  reserved-binding scoping (§3.3) is a scoping note carried into Phases 2 and 3.
  writing-plans assigns the decision numbers and confirms which of §3.2/§3.3 rise
  to full records.
- **Mutation discipline** (global constraints, AGENTS.md): every decision gets a
  mutation that a specification notices, asserting a measured failure signature
  (`EXPECT_STATUS` / `EXPECT_OUTPUT_MATCHES`), not merely a nonzero exit; re-run the
  whole mutation suite after adding any exit path; keep `no-scheme` green at 8/8;
  add no new dependencies.

## 9. References

- Parent plan §25 (Milestone 1 Scope, exit criteria), §7 (portability contract,
  library dependency direction), §9.2/§9.5/§9.6 (compile/emit calls, runtime ABI,
  end-to-end example), §10 (source IR), §16 (verification), §20 (emission and IR
  fingerprint), §22.9 (determinism checklist), §24.2 (adapter assertions).
- [decision 0005](../decisions/0005-chez-only.md) — Chez-only, single implementation.
- [decision 0006](../decisions/0006-inline-libraries.md) — inline `.sls`, no includes.
- [decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md) — M0
  closes at the harness; spike §7 D6/D7/D8 move to M1.
- [milestone-0-close-out.md](./milestone-0-close-out.md) §3 (where D6/D7/D8 land),
  §9 (items handed to M1 unresolved).
- [milestone-0-ci-feasibility.md](./milestone-0-ci-feasibility.md) — D8 feasibility
  notes, four Tier-1 cells.
