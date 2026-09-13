# Milestone 1 Phase 3 Slice B Design — Determinism / Identifier Proofs, Property Generator, and Phase-3 Close-out

Date: 2026-08-23
Status: proposed
Milestone: 1, Phase 3 Slice B

## 1. Summary

Slice A shipped the machinery: the normalizer and IR fingerprint, the emitter
(`(byte-machine compile)`), the direct-executor runtime ABI
(`byte-machine-make-compiled-machine/v1`, decision 0010), the §9.6 end-to-end
example, and the interpreter≡generated differential over the fixed one-byte
machine. Slice A had to *satisfy* determinism and the identifier grammar to emit
at all; it did not *exhaustively prove* them.

Slice B is that proof, plus the remaining Phase-3 close-out:

- **D6** — determinism *hardening* (parent §22.9): repeat in one process, repeat
  across processes, both Chez lanes, byte-for-byte across cells, and
  compile-and-execute the result.
- **D7** — the exhaustive identifier-repertoire proof (accept `[a-z][a-z0-9-]*`,
  reject uppercase / non-ASCII / punctuation for both machine names and output
  bindings) and the binary-LF proof.
- **The property-based machine generator** over bounded M1-shaped machines,
  feeding the interpreter≡generated differential, with a new `property` test
  label wired into the `pr` preset.
- **The member-2 runtime-export drift test** — `environment-symbols` of
  `(byte-machine runtime)` versus the emitter's declared `reserved-member-2`,
  with a witnessing mutation.
- **Deletion of the M0 placeholder libraries** `placeholder.sls` and
  `placeholder-consumer.sls` (spike §11): the real emitter now proves what they
  stood in for.
- **The confirmed Slice A Minors** carried into their owning files.

At the end of Slice B, Milestone 1's Phase-3 obligations are discharged on the
two cells CI provides; M9 completes the four-cell matrix with the same
mechanism.

## 2. Scope

**In Slice B.**

- **D6 determinism hardening** — a determinism spec, run in both `chez.source`
  and `chez.aot` lanes, that (a) emits the fixed one-byte machine twice in one
  process and asserts byte-equality, (b) asserts the emitted bytes are
  byte-identical to a committed golden fixture, and (c) compiles and executes the
  emitted output. Because both CI cells run the same golden-equality assertion in
  both lanes, cross-process, cross-lane, and cross-cell byte-identity all follow
  (§3.1).
- **D7 identifier repertoire + binary LF** — an exhaustive accept/reject proof of
  `[a-z][a-z0-9-]*` at both grammar sites (machine names in `verify`, output
  bindings in `compile`), covering uppercase, non-ASCII, and punctuation; and a
  proof that LF bytes survive the binary output port unmodified (§3.2).
- **Property-based generator** — a deterministic in-tree PRNG and a generator over
  bounded, *valid* M1-shaped machines (byte-dispatch / stop / error), each run
  through the interpreter≡generated differential; seed printed on failure. New
  `property` label; `property` added to the `pr` preset filter (§3.3).
- **Member-2 drift test** — computes member 2 from
  `(environment-symbols (environment '(byte-machine runtime)))` and asserts
  set-equality with `reserved-member-2` in `compile.sls`; a witnessing mutation
  that drops a member-2 entry must be caught (§3.4).
- **Placeholder deletion** — remove `placeholder.sls`, `placeholder-consumer.sls`,
  their two `.sps` test programs, their lane registrations, their `CORE_ALL`
  manifest entries, and any mutation-suite staging; re-measure every count (§3.5).
- **Confirmed Slice A Minors** — T1a, T1b, T1c, T2, T3, T4 (§3.6).

**Deferred, with a note (not dropped).**

- **`/v2` runtime export.** Decision 0010 §5 and its Consequences ship a `/v2`
  constructor *only under benchmark evidence* (parent §23.3 admission rule).
  Milestone 1 has no benchmark gate and no such evidence, so Slice B ships **no
  `/v2`**. The drift guard (§3.4) is made load-bearing by its *mutation*, not by
  the arrival of a new export, so `/v2` is not needed for it. Decision 0010 and
  the Slice A design §6 reconciliation note are amended to say so (§5).
- **Minor T1d** (`id-of` linear `assq` per call). An optimization; parent §23
  forbids optimizing without a reproducible compiled benchmark showing material
  improvement. Slice B builds no benchmark harness, so T1d is recorded as an open
  scale note, not changed.
- **`emission-metadata` named accessors.** No consumer beyond the tests exists
  yet; introducing an accessor surface before a consumer is YAGNI. Recorded, not
  changed.
- **The property generator's fuller shape (§3.3).** As shipped, the generator
  emits a single dispatch (entry) node plus the two terminals, and the property
  differential feeds single bytes only. That is *mutually covering* for the M1
  repertoire — with one dispatch state, single-byte-from-entry feeds exercise
  every dispatch transition, and the M1 emitter produces exactly this shape — so
  the coverage loss is small. The fuller generator §3.3 envisioned (up to a
  handful of dispatch nodes) and the multi-byte / fragmented feed schedule
  (parent §22.5) are **deferred to a later slice**, where multi-dispatch-node
  lowering and mid-stream resumption first become differentially observable.

**Out of Milestone 1 entirely** (milestone-1-design.md §7): EOF *execution* —
Milestone 2; byte classes, sequences, fields, callbacks, spans, counted
consumption — Milestones 3–6; the real Windows CRLF-translation proof and the
Linux arm64 / Windows amd64 cells — Milestone 9; `define-machine` sugar,
trie/transition-table specialization, a serialized IR format, a general CLI —
parent §29 deferrals. Invalid-graph *generation* (parent §22.6, second
paragraph) is not in Slice B: verifier rejection already has targeted tests
(`verify-tests.sps`), and the seed scopes the generator to the differential over
valid machines.

## 3. Architecture

Slice B adds **no new product library** and **no new runtime export**. It adds
test programs, one committed golden fixture, a small deterministic PRNG + machine
generator (a test-support library, not shipped product), mutation passes, one
preset-filter edit, and documentation. It *deletes* two product libraries. The
only product-source edits are the confirmed Minors (§3.6), none of which change
observable behavior — in particular none may move the golden IR fingerprint
`11963406767470843108`.

### 3.1 D6 — determinism proved by a committed golden

Parent §22.9's determinism checklist has seven items. The M1 realization, on the
two cells CI provides:

| §22.9 item | M1 Slice B realization |
|---|---|
| same machine repeatedly in one process | emit twice in one process, assert byte-equal |
| under separate processes | the lane program is a fresh process; asserting equality to a committed golden makes each independent run prove the same bytes |
| both source and AOT lanes | the determinism spec is registered as both a `.chez.source` and a `.chez.aot` lane |
| every Tier-1 cell, byte-for-byte across OS/arch | each cell runs the golden-equality assertion; identical-to-golden in cell A **and** cell B ⇒ A ≡ B transitively. M9 adds the two remaining cells with the same golden |
| compile and execute each generated output | the spec imports the emitted library and runs it (as the example lane already does) |
| every permitted identifier char + rejected forms | D7 (§3.2) |
| reject every reserved output binding, scoped to existing members | drift test (§3.4) + the member-1/2/3 mutations already shipped in Slice A |

The **committed golden** is the raw emitted bytes of the fixed one-byte machine,
stored as `test/fixtures/generated-one-byte.golden.sls`. The comparison is over
*bytes*, not the IR fingerprint: the IR fingerprint is computed over the
normalized IR, so equal fingerprints do not imply equal emitted text; only a
raw-byte comparison proves the writer is deterministic end to end. The emitted
text embeds the IR fingerprint, so a fingerprint change is a superset-caught byte
change.

This needs **no CI artifact plumbing**. CI today (`.github/workflows/ci.yml`) runs
two independent jobs with no cross-job comparison; the committed golden is a
stronger and simpler cross-cell anchor than passing artifacts between jobs, and it
is exactly the "comparison by the project-owned writer" the M1 design §6 D6
bullet calls for. Regenerating the golden after a deliberate emitter change is a
documented one-command step (mirroring the `harness.sls` fixture-regen recipe).

A witnessing mutation perturbs the canonical writer (e.g. a spacing or ordering
change in the template) so the emitted bytes diverge from the golden; the
determinism spec catches it with a measured signature.

### 3.2 D7 — identifier repertoire and binary LF

Two grammar sites enforce `[a-z][a-z0-9-]*` today:

- **machine / node / error names** — `valid-name?` in
  [verify.sls](../src/byte-machine/verify.sls):31, surfaced as `invalid-name`
  diagnostics;
- **output bindings** — the reserved-binding predicate in
  [compile.sls](../src/byte-machine/compile.sls), which validates the caller's
  `binding` against the grammar *and* the three reserved members before writing
  any bytes, raising `invalid-output-binding`.

Slice B adds an **exhaustive repertoire spec** that, for each site, asserts:

- every single accepted character class is accepted (a leading `[a-z]`, interior
  `[a-z0-9-]`), across representative multi-character names;
- **uppercase** `[A-Z]` is rejected;
- **non-ASCII** (e.g. a Latin-1 or CJK code point) is rejected;
- **punctuation** outside `-` (`_`, `.`, `/`, space, digit-leading, empty) is
  rejected;
- the boundary cases: empty name, leading digit, leading hyphen, trailing hyphen
  (accepted or rejected exactly as the grammar specifies — pinned to the shipped
  regex, not guessed).

The rejection assertions check the *diagnostic category and offending value*, not
exception prose (parent §22.10).

The **binary-LF proof**: emit a machine to a binary port, read the bytes back
raw, and assert (a) no `#x0D` (CR) byte appears anywhere, and (b) the final byte
is `#x0A` (LF). This proves the writer emits LF-only line endings through
`put-u8`. **Limitation** (milestone-1-design.md §6 D7): the genuine Windows
CRLF-translation trap only manifests on a Windows cell, which M1 CI does not have,
so this proof runs where it is trivially clean; the real Windows proof rides to
M9. The spec states this limitation in a header comment so it is not mistaken for
the Windows proof.

Witnessing mutations: relax the grammar predicate (e.g. admit uppercase) so a
rejection assertion flips; and a writer mutation that would emit a CR (if any
reachable path exists) — if none is reachable, the LF assertion is carried as a
declared observation with the measured reason, per the close-demonstrated-gaps
rule, rather than a hollow survivor.

### 3.3 Property-based generator and the `property` label

A **deterministic in-tree PRNG** (a small linear-congruential or xorshift
generator in a test-support library — no dependency, parent §22.6) drives a
**machine generator** that produces bounded, *valid* M1-shaped machines:

- a small number of nodes (bounded, e.g. ≤ 6), each a byte-dispatch, stop, or
  error node, with exactly one entry;
- each dispatch node has a set of **non-overlapping** exact-byte cases (distinct
  bytes) plus a fallback edge, with `advance` / `reexecute` modes chosen by the
  PRNG;
- all edge targets resolve to declared nodes; at least one terminal is reachable;
- all names drawn from the valid `[a-z][a-z0-9-]*` grammar.

The generator emits only machines the verifier accepts (it is not a fuzzer of
invalid graphs — §2). For each generated machine, the property spec builds the
interpreter oracle and the emitted-and-imported generated executor and runs the
**interpreter≡generated differential** — asserting equal `parser-result-status`,
`-next`, `-consumed`, `-stream-offset`, and `-error` — over a byte schedule (all
256 single-byte feeds, and a small set of multi-byte / fragmented feeds per
parent §22.5). The internal state id is executor-local and is not compared across
executor kinds (parent §12.7).

The PRNG **seed is fixed and printed on every run**, and printed prominently on
failure, so any counterexample is reproducible (parent §22.6). The number of
generated machines is a small fixed budget (deterministic, not time-bounded).

**Label wiring.** The property lanes carry a new `property` label. The `pr` preset
filter regex in [CMakePresets.json](../CMakePresets.json) (currently
`^(harness|unit|verify|differential|determinism|portability|example)$`) gains
`property`. The `determinism` label already present in that regex is reused by the
D6 lanes; no other preset changes.

### 3.4 Member-2 runtime-export drift test

Slice A shipped the reserved-binding *set* and its three per-member mutations, but
the final whole-branch review found the promised **drift guard** — a test tying
member 2 to the runtime's *actual* export list so the two cannot silently diverge
— was never made a concrete task. Slice B ships it.

The drift spec computes the runtime's export set at runtime via
`(environment-symbols (environment '(byte-machine runtime)))` and asserts
**set-equality** with the emitter's declared `reserved-member-2`
([compile.sls](../src/byte-machine/compile.sls):39). The exact
`environment-symbols` behavior is verified against real Chez 10.4.1 during
implementation (it returns the identifiers visible in an environment that imports
only `(byte-machine runtime)`, i.e. that library's exports); if it returns a
superset in practice, the spec filters to the declared surface and the plan
records the measured behavior.

The guarantee is made **load-bearing by a witnessing mutation**, not by shipping a
new export: a mutation that drops one entry from `reserved-member-2` makes the
declared set a proper subset of the live exports; the drift spec's set-equality
assertion fails with a measured signature (`EXPECT_STATUS` + an
`EXPECT_OUTPUT_MATCHES` naming the missing symbol or the mismatch). This is why
`/v2` is unnecessary for the guard: the mutation simulates exactly the
future-export-forgotten scenario the guard exists to catch. (§5 amends the Slice A
note that had tied the guard's value to `/v2`.)

### 3.5 Placeholder deletion

The M0 placeholder libraries were stand-ins for a real cross-library-identity
consumer before the emitter existed. The emitter and its end-to-end example now
exercise the real public library boundary, so the placeholders are removed
(milestone-1-design.md §6; spike §11). Deletion spans:

- `src/byte-machine/placeholder.sls`, `src/byte-machine/placeholder-consumer.sls`;
- `test/common/placeholder-tests.sps`,
  `test/common/placeholder-identity-tests.sps`;
- their lane registrations in `test/CMakeLists.txt` (including the
  `placeholder-identity` AOT identity lane);
- their entries in the `CORE_ALL` / core manifest fragments;
- any `SchemeMutationSuite.cmake` staging or passes that reference the placeholder
  files.

Because this removes lanes and possibly mutation passes, **every count is
re-measured** against the shipped tree (`release`, `no-scheme`, both mutation
suites) and recorded, never computed on paper.

### 3.6 Confirmed Slice A Minors

Each lands in its owning file, TDD where it changes behavior:

- **T1a** — `private/normal-ir.sls`: the `cond` / `case` over node kinds gain an
  `else` guard that *raises* (an unreachable-today fourth node kind must fail
  loudly, not silently misbehave), plus a one-line "EOF excluded until M2" comment
  documenting why the repertoire is exactly three kinds.
- **T1b** — assert `normal-state-id` directly (it is exported but only indirectly
  exercised today).
- **T1c** — split `normalize-machine`'s combined lowering+encoding into two
  focused functions. **Invariant:** the golden IR fingerprint
  `11963406767470843108` (pinned in `normal-ir-tests.sps` and `compile-tests.sps`)
  must not move; the split is behavior-preserving and the fingerprint test proves
  it.
- **T2** — `runtime.sls`: `make-parser`'s v1 branch uses named accessors instead
  of `(vector-ref cm 2/3)`.
- **T3** — tighten the Pass 36 "unverified rendered anyway" mutation from the loose
  `EXPECT_OUTPUT_MATCHES "ok"` to `"not ok"`, confirmed by a Pass 36 re-run so the
  tighter string actually matches the mutant output.
- **T4** — de-duplicate the one-byte fixture currently copied across
  `differential-one-byte-tests.sps` and `example-one-byte-tests.sps` into one
  shared test fixture.

## 4. Testing strategy

**The five lanes (parent §22.1).** Slice B exercises construction+verification,
interpretation, emission, generated execution, and the differential — now over an
*arbitrary* generated machine population, not only the fixed one-byte machine.

**New test programs** live in `test/common/*.sps`, each registered as both a
`.chez.source` and a `.chez.aot` lane via `byte_machine_add_scheme_lane`
(established by Phase 2 / Slice A). Labels: `determinism` (D6, already whitelisted),
`property` (generator, newly whitelisted), and the existing `verify` / `unit`
labels for the D7 grammar spec and the drift spec as appropriate.

**Mutation discipline (milestone-1-design.md §8, AGENTS.md).** Every decision in
new code and every property proved gets a mutation an owning spec notices,
asserting a *measured* failure signature (`EXPECT_STATUS` + `EXPECT_OUTPUT_MATCHES`),
never a bare nonzero exit. Deleting the placeholder lanes and adding the drift exit
path both touch the exit surface, so the **whole** mutation suite is re-run and
each affected pass re-checked (a new or removed exit can silently disarm an
existing mutation). `no-scheme` stays green at 8/8; no new dependencies. Declared
totals (`EXPECTED_PASSES`, `EXPECTED_MUTATIONS`) and their arithmetic move in the
same commit as the passes they cover, and are re-read from the suite before
bumping — never quoted from a plan.

**Generated / golden files and the manifest.** The emitted `.sls` written by the
determinism and property specs is a *test-time artifact* in a temporary library
root the launcher is pointed at (`(source-directories '())`, absolute roots —
decision 0006); it is excluded from every lane's `SOURCES` manifest and the
basename-uniqueness check, exactly as Slice A established. The **committed golden**
`test/fixtures/generated-one-byte.golden.sls` is a fixture (like
`fingerprint-sample.bin`), not repository Scheme on any library path, and is
likewise excluded from `SOURCES`.

## 5. Decisions to record / amend

- **Decision 0010 amendment.** Add a dated note: the member-2 drift guard is
  load-bearing via its witnessing mutation (drop-an-entry), so `/v2` is **not**
  shipped in Slice B; `/v2` remains gated on benchmark evidence (0010 §5,
  Consequences) exactly as written. This closes the tension between the Slice A
  reconciliation note (which had tied the guard's value to `/v2`) and 0010.
- **Slice A design §6 reconciliation note amendment.** The
  "Runtime-export drift test — deferred to Slice B" paragraph is updated to record
  that Slice B implemented the guard **without** `/v2`, via the mutation.
- **No new numbered decision record** is expected: Slice B introduces no new
  architectural commitment, only proofs of existing ones and the deletion of
  superseded scaffolding. Writing-plans confirms this at close-out; if the property
  generator's design (PRNG choice, machine-shape bounds) warrants a record, it is a
  note next to the generator, not a numbered decision.

## 6. Task breakdown (each TDD, failing test first)

Single `slice-b` plan, executed subagent-driven off `feat/m1-phase-3-slice-b`:

1. **D7 identifier repertoire + binary LF** — exhaustive accept/reject spec at both
   grammar sites; LF-only / final-newline proof; witnessing mutations.
2. **D6 determinism hardening** — golden-bytes determinism spec (emit-twice,
   golden-equal, compile-and-run) in both lanes; committed golden fixture +
   regen recipe; witnessing mutation on the writer.
3. **Property generator + differential** — in-tree PRNG + valid-machine generator;
   per-machine interpreter≡generated differential; seed-on-failure; `property`
   label + `pr` filter edit; both lanes.
4. **Member-2 drift test** — `environment-symbols` vs `reserved-member-2`
   set-equality spec; witnessing drop-an-entry mutation; amend 0010 + Slice A note.
5. **Delete placeholders** — remove the four files, their lanes, `CORE_ALL`
   entries, and mutation staging; re-measure all counts.
6. **Confirmed Minors** — T1a, T1b, T1c (fingerprint-preserving), T2, T3
   (Pass 36 re-run), T4; defer T1d and emission-metadata accessors with notes.
7. **Close-out** — decision-record amendments; CHANGELOG; re-measure
   `release` / `no-scheme` / both mutation suites against the shipped artifact and
   record the numbers; confirm the Phase-3 / Milestone-1 exit criteria
   (milestone-1-design.md §6 "Exit (full Milestone 1)").

## 7. Handed to writing-plans

- The exact PRNG algorithm and its seed constant; the concrete machine-shape
  bounds (max nodes, byte-set sizes) and the generator's valid-by-construction
  argument.
- The concrete byte schedule the property differential runs per machine (all-256
  plus the fragmentation set), and the fixed machine budget.
- The exact `environment-symbols` behavior measured against Chez 10.4.1, and
  whether the drift spec must filter its result.
- The golden-fixture regeneration command and where it is documented.
- Per-task lane and mutation deltas, computed against re-measured baselines
  (`release` 55, `no-scheme` 8/8, scheme mutation 36/107, cmake mutation 1/72).
- The precise wording of the 0010 amendment and the Slice A §6 note update.

## 8. References

- [milestone-1-design.md](./milestone-1-design.md) §6 (Phase 3 deliver/exit), §7,
  §8; [milestone-1-phase-3-slice-a-design.md](./milestone-1-phase-3-slice-a-design.md)
  §2 (Slice B deferrals), §3.4, §3.5, §6 (reconciliation, drift-test deferral).
- Parent [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
  §12.7, §17, §18, §19, §20, §22.1, §22.4, §22.5, §22.6, §22.7, §22.9, §22.10,
  §23, §24.2.
- Decisions [0005](../.decisions/0005-chez-only.md),
  [0006](../.decisions/0006-inline-libraries.md),
  [0008](../.decisions/0008-emitter-emits-importable-library.md),
  [0009](../.decisions/0009-content-and-ir-fingerprints.md),
  [0010](../.decisions/0010-direct-executor-abi.md).
- [milestone-0-close-out.md](./milestone-0-close-out.md) §3 (spike §11 placeholder
  deletion lands in M1 Phase 3).
