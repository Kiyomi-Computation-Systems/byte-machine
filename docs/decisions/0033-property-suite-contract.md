# 0033: The property suite's contract — the verifier decides validity, every draw proves it ran, the seed comes from the environment, and a failure is a file

Date: 2026-09-06
Status: accepted
Milestone: 7, Gate 0 (milestone-7-design.md §4.3)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-11 (Milestone 7 Slice ② implementation)** — **amends item 2 and
>   item 5's rows 1 and 6; annotates item 4**: the counters are **ten**, not the
>   shipped eight, and the field counter reads a value back rather than the draw
>   (item 2); `§12.2:695` permits the sticky `stopped` from `parser-finish!` that
>   row 1 calls impermissible, and the `§16.2:909` hole is the `(ready |
>   finish-ready, finish!)` pair (row 1); row 6 needs a third inapplicability
>   condition — no bound completion callback; and the reproduction fixture and
>   saver are Slice ③'s, not ②'s (item 4). See the dated notes at the foot; the
>   items stand as decided.

## Context

Decided against `main` at `50516af` — the Milestone 7 design (PR #83) and its Gate 0
plan (PR #84) merged; `src/` and `test/` byte-identical to `5ac363a`. Every construct
named below was read on 2026-09-06 and is cited by name, with the command that found
it.

**What the parent plan leaves open.** `§22.6:1295` says "Generate bounded small
verified machines and inputs to compare interpreter/generated behavior" and does not
say who guarantees *verified*. `§22.6:1293` says "print the seed on failure" and does
not say where the seed comes from. `§22.6:1297` says "Never use an invalid graph to
test executor behavior". `§25:1621` asks for "deterministic failure seed reporting"
and `§25:1627` that "minimized/reproducible failure fixtures can be saved without
external tooling", and neither says what a fixture is or where it goes. The
Milestone 0 harness plan wrote, when the PRNG was still a plan, that "its seed must
come from the environment" (`milestone-0-slice-2-test-harness.md`). All of it is
developer-facing, and every pin in the property pass is measured against whichever
answer lands — which is why the answers are a record.

**The lane as shipped, measured** (each command run at `50516af`):

- **The seed is a literal and the count is forty.** `property-differential-tests.sps`
  has `(define seed 20260823)` and `(define machine-count 40)`; the seed is printed in
  the per-machine agreement label (`… (seed N) byte agreement`), so `:1293`'s letter
  holds and its intent — replay without editing the test — does not.
- **Eight anti-vacuity counters.** `rg -c '"at least one|"the interpreter alone'
  test/common/property-differential-tests.sps` prints 8: five "at least one …"
  checks (two built with `string-append`, which is why the pattern matches the
  label's opening quote and not `(check`) and three "the interpreter alone …" twins —
  pause, finish, field, digit and overflow observed in agreement; digit, overflow and
  pause observed in the interpreter alone.
- **Six pins in one pass**, Pass 39 of `SchemeMutationSuite.cmake`, quoted verbatim
  because Slice ②'s plan decides each by name: "compile: the dispatch byte test is
  inverted, diverging from the oracle"; "property-differential: resume-pair! stops
  calling parser-resume!"; "machine-gen: the pause draw's coin is hard-wired to
  false"; "machine-gen: the eof draw's coin is hard-wired to false"; "machine-gen:
  the pinned accumulate case advances instead of reexecuting"; "machine-gen: the
  accumulate field's initial is one below the only workable value".
- **Two registrations passing nothing.** `byte-machine.property.differential.chez.source`
  and `.aot` in `test/CMakeLists.txt`, each `TIMEOUT 180` and no `ENVIRONMENT` line,
  so the default seed is what CI runs.
- **An artifacts directory nothing cleans.** `cmake/ByteMachineTesting.cmake` does
  `set(tmp_dir "${CMAKE_BINARY_DIR}/test-run/${arg_NAME}/tmp")`, `file(MAKE_DIRECTORY)`
  on it and on the run directory, and passes `BYTE_MACHINE_TEST_TMPDIR=${tmp_dir}` in
  the lane's environment; `rg -n "file\(REMOVE" cmake/ test/CMakeLists.txt` prints
  nothing. The harness's FAIL-CONTEXT line already prints the directory as
  `artifacts=`, and the lane already writes its emitted libraries there
  (`prop-N.sls`).
- **Seeded schedules already exist, for fixed machines.** `rg -l prng
  test/common/*.sps` prints four files — the property lane and the sequence,
  sequence-node and http-version differentials — so the contract's novelty is the
  *drawn machine* under a schedule, not the seed.
- **`machine-gen.sls`'s constraints, by the file's own count.** Two were added after
  "Step 5 (running the property lane against the reference verifier) showed real
  verify-machine rejections across the seed's 40 machines" — a case targeting
  `start` is forced to `advance`, and the first case always targets `stop`; a third,
  "reachability itself", adds `pausep` only when a case drew it; and the accumulate
  draw's four bullets are coverage pins for a one-byte trial (the inbound case
  pinned to `reexecute`, overflow routed to its own error, the field's initial and
  the digit's value chosen so one byte commits or overflows), not verifier rules.
  Three verifier rules, hand-encoded; the design's §4.3 and §7 said "five
  hand-written constraints" until its Gate 0 plan's review counted, and were
  corrected in that plan's PR.

## Decision

**1. Validity is `verify-machine`'s verdict, not the generator's promise.** Draw from
every construct — `§10.6`'s thirteen kinds, `§9.1`'s four matchers, the declaration
families, `§22.5`'s schedule shapes — with structural steering only where a draw
would otherwise be unconstructible (a target must name something); verify every draw;
hand only accepted machines to an executor; count rejected draws by code and keep
them, as Slice ④'s free material; never feed one (`§22.6:1297`); and assert
structurally that the count of machines handed to `make-interpreted-machine` equals
the count the verifier accepted. *Rejected, with the failure each would cause*:
validity by construction extended to seven more kinds — the generator would encode
pass 7's lattice, decision 0030's join, the parked set and `§16.2:908`'s gate by
hand, a second verifier in the test tree that agrees with the first by construction
and can therefore never disagree with it; retry-until-accepted with no floor — a
verifier over-rejection would disappear from the lane without a trace.

**2. Every drawn construct proves it ran, and the accepted count has a floor.** For
each node kind, matcher kind, field operation and predicate, callback outcome, span
event and schedule shape, a counter reads an *observed* value from the trial — a
field that changed, a fragment delivered, a pause taken, a state name reached, a
status returned — never the draw that requested it. Each has the two halves the
shipped lane has, interpreter-only (attribution: the arm ran) and agreed (the
property held while it ran); each is asserted ≥ 1 over the seed set; the shipped
eight stay. **The floor**: a literal the plan fixes by measuring the acceptance rate
under the committed seed and setting it no lower than half the machine count; a
measured rate below half sends the draw back for steering before the lane lands. A
verifier change that starts rejecting most draws is then a red lane, not a quietly
shrunk one — clause 1's one real cost, made visible.

> **Amended 2026-09-11 (Milestone 7 Slice ②)** — the counter set is ten, not the
> shipped eight, and the field counter reads a value back rather than the draw.
> See the dated note at the foot; the text above is left as decided.

**3. The seed comes from `BYTE_MACHINE_PROPERTY_SEED`, with the committed default.**
The value is a decimal exact non-negative integer; unset or empty means the literal
the program declares; anything else is a loud `assertion-violation`, never a
fallback — a typo that silently ran the default would report the wrong seed in every
label. The parse is `string->number` on the trimmed value with that check (design
§4.10; carried here because it is developer-facing). The registrations pass nothing,
so CI and every pin run the default; a developer replays a reported seed by setting
the variable; the seed is printed once at the suite's start and carried in every
machine-level check label, the shipped agreement label's shape; a mutation pin whose
witness is a drawn shape names the seed it was measured under, in its comment.

**4. A disagreement writes a fixture and says where.** On the first disagreement for
a machine, the lane writes a self-contained R6RS program to
`BYTE_MACHINE_TEST_TMPDIR` — the lane's imports, the machine as `§9.1` constructor
calls, the callback script and the schedule as quoted data, one `harness-group` with
one case running the same trial through the shared driver library,
`harness-finish` — and the check's detail names the file. Run with the shipped
launcher (`chez-source.ss --program <file>`) it exits 1 on the disagreement and 0
when fixed; "without external tooling" (`§25:1627`) means `chez`, the launcher and
the tree. Slice ③ adds the minimized twin beside it. It is not `§29:1761`'s
"serialized IR format" — test support emitting Scheme source against the public API,
with no reader but `load` — and not `§29:1762`'s "general-purpose CLI".

**5. The comparison is three layers.** *Per schedule*, `§22.4:1264-1272`'s nine
members, "result status" through "stop/finish/reset behavior". *Across schedules*,
`§22.5:1285-1289`: identical fragment boundaries for the same schedule (`:1285`);
coalesced traces invariant across schedules and raw boundaries deliberately not
(`:1287`); malformed inputs compared across schedules by acceptance, error category
and absolute error position only, callback prefixes within one schedule only
(`:1289`). *And the invariant layer*, per lane, per operation, stated with the
qualifiers the design's review measured:

| Invariant | Qualifier | Source |
| --- | --- | --- |
| after each operation, `(status, lifecycle-after)` is a pair the row for `(lifecycle-before, operation)` permits, and a contract condition is raised exactly where the row says "Contract condition" | `poisoned` and `busy` are not driven — unreachable with scripted callbacks; a `stopped` from `parser-finish!`, which no row permits, is a `§16.2:909` hole and is reported as one | `§12.2:691-699` |
| `start ≤ next ≤ end`, `0 ≤ consumed ≤ end − start`, and the stream offset after equals the offset before plus `consumed` | **feed-originated results only** — `§9.3:392-393` marks `next` and `consumed` so; for a `parser-finish!` result `next` equals the stream offset and `consumed` is 0, the shipped values, measured by the design's review as `finished next 5 consumed 0 offset 5` and recorded in the parent's `§12.3:711` disposition | `§11.5:660`, `§9.3:392-393` |
| in a sticky state a feed returns `consumed` 0 and `next = start`, and the stored offset is unchanged | — | `§12.2:701` |
| every field value is an exact integer in `[0, 2^width)` | — | `§15` |
| `finished` is returned only by `parser-finish!` or a sticky feed after it | a verifier-completeness property: both executors carry an unconditional finish arm, and `§16.2:908`'s block over `node-out-edges` is the mechanism that keeps a feed from reaching it | `§12.4`, decision 0011 item 2 |
| for a span that reaches its end with its data callback bound, the concatenation of its fragments in one schedule equals the input bytes the span covered | not applicable at an error — "Errors do not flush a final partial fragment" (`§14:839`); not applicable when the optional span-data callback is unbound, since no fragment is delivered | `§14:831-834`, `:839` |

> **Amended 2026-09-11 (Milestone 7 Slice ②)** — row 1's sticky `stopped` from
> `parser-finish!` is a `§16.2:909` hole (the `(ready | finish-ready, finish!)`
> pair), and row 6 needs a third inapplicability condition (no bound completion
> callback). See the dated note at the foot; the rows stand as decided.

A trial that violates an invariant in one lane fails whether or not the other lane
agrees. **The layer's blind spot, by name**: an agreed-wrong value that satisfies
every invariant is invisible to all three layers, and one is in the tree today — the
position kind of a failed zero-width action reached over a reexecute edge, the
parent's `§12.7:770` open half, wrong in both lanes (the design's §3.2, measured
2026-09-05) and with its receivers named in the design's §4.11 item 7. The lane's
header will say so; drawing the shape does not make this milestone the receiver.

## Consequences

- **Handed to Slice ②**: the generator over every construct (design §4.4), the
  driver as a library `(byte-machine test property-driver)`, the counters and the
  floor (item 2), the seed plumbing (item 3), and the fate of Pass 39's six
  mutations — each retired with its reason written in its place or re-anchored,
  decided per LABEL in ②'s plan and never loosened; four of the six `FIND` text in
  `machine-gen.sls` that the rewrite deletes, which is why the generator, the
  driver, the lane program and those pins land in one commit (design §11).
- **Handed to Slice ③**: the printer — total over the kinds and matchers, proved by a
  derived row and a round trip by IR fingerprint on every accepted machine; the saver
  (item 4); and the minimizer — validity oracle the verifier, failure oracle the
  lane's own comparison, a removed node's in-edges retargeted to a fresh error node
  of its own and never a shared sink, which would join `none` with `(active s)`
  inside a span and stop every reduction at `inconsistent-span-state`; its test a
  deliberate failure, since the lane cannot wait for a real one.
- **Handed to Slice ④**: the rejected draws, counted by code (item 1), as the
  catalogue's and the independent oracle's free material.
- **Not decided here**: the corruption catalogue's shape (design §4.5); the
  independent oracle's scope (§4.6); the bounds — machines per seed, node budget,
  input length, schedule count (§4.10, a plan's numbers).

## Notes (2026-09-11, Milestone 7 Slice ② implementation)

Four items above were instructions the implemented tree corrects; the items stand as
the record of what was decided, and these notes carry what the slice found. The
Context is a measurement of the tree 0033 was decided against and is untouched.

- **Item 2 (the counters).** "The shipped eight stay, each with the two halves the
  shipped lane has" could not hold: the shipped eight are five agreed and three
  interpreter-only, and `finished` and `field` have no twin, so the set is **ten**,
  not eight (48 keys, 96 checks). And one of the eight — "at least one generated
  machine declares a field" — read **the draw** (`(pair? fnames)`), which this same
  item forbids, so its **witness changed** to a field value read back through
  `parser-field-ref` from both parsers and differing from its declared initial; its
  **label survives** unchanged.
- **Item 5, row 1 (the lifecycle table).** "A `stopped` from `parser-finish!`, which
  no row permits" is wrong: `§12.2:695` permits exactly that for the **sticky** arm.
  The invariant is keyed on **`(lifecycle-before, operation)`**, never on the status
  alone, and the `§16.2:909` hole is the pair `(ready | finish-ready, finish!) →
  stopped` — a verifier-completeness property, reported as a hole, not a runtime
  event. `poisoned` and `busy` are not driven by a script from
  `{continue, pause, key, failure}` and the row says so rather than asserting them
  vacuously.
- **Item 5, row 6 (the span content invariant).** The row needs a **third
  inapplicability condition** — no bound span-complete callback — because there is
  **no public observation of a span's start offset** and the completion callback's
  reported end offset is the only anchor available; without a completion callback
  the end anchor is dropped and conjuncts (i) content and (ii) contiguity stand.
  (The `finished next 5 consumed 0 offset 5` digest is a value whose command is
  nowhere and whose fixture this slice does not write, so row 2's arithmetic is
  asserted as a **relation**, not by repeating that digest.) Also: item 5 files
  `§22.5:1285` under "Across schedules", but the sentence reads "for the same
  schedule" — the driver puts it in **Layer 1**, with the design and the shipped
  tree — and row 2's Source column drops `§11.1`, which design §4.4 carries and the
  driver keeps.
- **Item 4 (the fixture and the saver are Slice ③'s).** The reproduction fixture,
  the saver, and the failing-machine path in a check's detail are **Slice ③'s**
  (0033's own Consequences hand "the saver (item 4)" to ③, and design §8 puts it
  there). Slice ② ships the driver **shaped so ③ can add the saver without
  re-shaping it** — the `on-first-disagreement` parameter, the at-most-once-per-machine
  rule in the driver, and `check-fail` as the only assertion whose detail the caller
  chooses — and writes **no fixture**. Item 4 is not this slice's obligation.
