# Milestone 2 Design — Incremental Execution and Lifecycle

Status: design — approved shape, pending implementation plan. Authored 2026-08-28,
after Milestone 1 closed (PR #17, commit `4eb16a3`).

Governing plan: [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
§25 ("Milestone 2: Incremental execution and lifecycle"). This document does not
change M2's *scope*; it re-cuts M2 *internally* into an ordered Gate 0 plus three
slices and resolves the design calls M1 handed forward when it constructed and
verified EOF declarations without executing them
([milestone-1-design.md](./milestone-1-design.md) §7, parent §25 M1). Where this
document and §25 differ in wording, §25's Scope list remains authoritative and
this document records how that scope is sequenced and delivered.

## 1. Summary

Milestone 1 proved the smallest machine end-to-end: **accept one exact byte and
stop; reject every other byte at the correct position**, run through both the
reference interpreter and generated code across all 256 values. It deliberately
stopped at a single `parser-feed!` over a one-byte slice, and it **declared and
verified** EOF (`default-eof-error`, dispatch `eof-target`) without ever
executing it (parent §25 M1; the normalizer even carries `else` guards placed for
"a fourth kind, Milestone 2").

Milestone 2 turns that single-shot accept into a **parser with a lifecycle**:
input arrives in arbitrary slices across many calls, the parser reports exactly
what it consumed and where it is, it runs EOF when the caller says the stream is
over, it can pause and resume, and it can be reset. The proving surface grows from
one byte to a short **byte sequence** — still built only from M1's node repertoire
plus one new node kind (an explicit pause) — because a sequence is the smallest
machine with real *split points* and a real *idle-vs-truncation* EOF distinction.

M2 is one milestone and one continued vertical slice; like M1 it is delivered in
an explicit, ordered set of phases:

| Phase | Kind | Produces | Discharges |
| --- | --- | --- | --- |
| **Gate 0** | decisions only | 3 records | the inherited EOF/ABI/condition calls |
| **Slice ① — Incremental execution** | product | a multi-byte machine; arbitrary/nonzero-offset slices; fragmentation and split-point differential; the §9.6 example fed a nonzero-offset slice | most of §25's "arbitrary slices / `need-input` / exact offsets" |
| **Slice ② — EOF + lifecycle spine** | product | `parser-finish!`, eof-target execution and encoding, `finished`, `parser-reset!`, coded misuse conditions, the EOF-cycle check, idle-vs-truncation | §25's "finish and EOF edges / sticky finished / API misuse / reset" |
| **Slice ③ — Pause / resume** | product | the pause node, `parser-resume!`, `paused-feed`/`paused-finish`/`finish-ready`, the full reachable operation matrix | §25's "explicit pause node and continuation / resume" |

Dependency order is strict. Gate 0 unblocks everything. Slice ① is almost pure
test surface over engine code M1 already shipped (`parser-feed!` already accepts
arbitrary `(bv start end)`, returns `need-input`, and reports `next`/`consumed`/
`stream-offset`), so it lands first and gives Slice ②'s EOF work a real
multi-byte machine to finish against. Slice ② installs the lifecycle-state field
that Slice ③'s pause states hang off. Every slice runs in **both execution lanes**
and is checked by the **interpreter≡generated differential** (parent §18, §22.4).

## 2. Why this shape

Read literally, §25 M2 lands arbitrary slices, `need-input`, offsets, a pause node
and continuation, resume, reset, finish and EOF edges, sticky terminal states, and
the full API-misuse condition family — all at once. That is a large step onto a
runtime that today has no lifecycle-state field at all (just `current` + a stored
`sticky` result) and an emitter that renders only `dispatch`/`stop`/`error`. This
revision keeps the scope but sequences it so that:

- the three design calls that shape EOF execution, the generated ABI, and how
  misuse surfaces are settled *before* any code depends on them (Gate 0);
- the cheap, high-value increment (incremental feeding, which needs mostly a
  bigger machine and more tests) proves out *first*, over the engine M1 already
  trusts;
- the lifecycle-state spine is installed with EOF (Slice ②) *before* the pause
  states that require it (Slice ③).

Splitting M2 into more than one milestone was considered and rejected for the same
reason M1 was not split: every milestone is a vertical slice that generates and
executes code, and the roadmap numbering (M3–M9) stays fixed.

## 3. Gate 0 — design-call resolutions

Decision-only. No product code is written in Gate 0. writing-plans assigns the
record numbers (next free in `docs/decisions/`) and confirms whether any splits or
merges of the three below are warranted.

### 3.1 EOF execution model

M1 left `eof-target` as either `#f` (route to the machine `default-eof-error`) or a
symbol naming a node, and verified only that the symbol *resolves* (parent §16.2,
verify `pass-eof`). M2 must decide what executing it *means*. The resolution:

- **`parser-finish!` runs the same executor loop as feed, with input permanently
  exhausted.** The only branch that differs is at a dispatch node with no byte
  available: feed returns `need-input`; finish instead takes that node's
  **eof-target** (the named node when set, else the machine `default-eof-error`).
  Execution then continues through zero-width nodes exactly as feed does.
- **`stop` is polysemous.** Reached via feed it yields `stopped`; reached via
  finish it yields `finished`. The node is unchanged; the status reflects the
  path. This matches §12.1's two distinct arrows into a successful terminal and
  adds no "accept/finish" node kind.
- **eof-targets chain.** A dispatch's eof-target may name another dispatch node;
  finish, having no byte, immediately takes *that* node's eof-target, and so on,
  until a `stop` (`finished`), an `error` node (`error`), or a pause
  (`paused-finish`, Slice ③). This is the general reading: with M1/M2's node
  repertoire the only multi-hop EOF traversal *is* an eof-target chain, and it is
  the same walk feed already performs. It avoids a "eof-target must resolve
  directly to a terminal" restriction that M4/M5 (zero-width action, callback, and
  span nodes on the EOF path — §12.4) would only have to remove.
- **EOF gets its own zero-progress-cycle check** (parent §12.4: "EOF edges
  participate in a separate zero-progress-cycle check … may not loop
  indefinitely"). An eof traversal reachable from any state must reach a terminal
  in finitely many steps; an eof-target loop fails verification.

§12.4 does not spell out hop-to-hop chaining in words; it *does* mandate a
dedicated EOF-cycle check and a finite-resumes guarantee, which are only load-
bearing if EOF processing is a multi-step traversal. Chaining is the M2-era form
of that traversal. This is an engineering call for generality, recorded so later
milestones cite it rather than re-deriving it.

### 3.2 The generated ABI grows a finish path under `/v2`

`parser-finish!` must drive the *generated* executor with no bytes. That is a new
runtime↔generated contract, and [decision 0010](../decisions/0010-direct-executor-abi.md)
item 4 already fixed how such a change is made: the seam "extends by a `/v2`
constructor rather than an arity break," and "the version tag exists for exactly
that." (Item 5's benchmark-gated `/v2` is an unrelated, optimization-driven
revisit of the `feed-outcome` *record*; it is not this.) The resolution:

- Add `byte-machine-make-compiled-machine/v2`; bump `current-abi-version` to `2`;
  the emitter emits `/v2` and retires `/v1`.
- The generated machine exposes **one unified `exec` closure carrying a `finish?`
  flag**, not two closures. `exec` is M1's feed loop; the only arm that changes is
  the exhausted-dispatch branch — `(if finish? <take-eof-target> need-input)`.
  Every state arm (`stop`/`error`/`dispatch`/pause) is rendered **once** and shared
  by both paths, so feed and finish cannot silently diverge and generated code
  stays small. Pause is mode-agnostic in generated code: the arm emits `paused`;
  the runtime tags `paused-feed` vs `paused-finish` by which entry point it came
  through.
- The `feed-outcome` record **shape is reused**. `paused` and `finished` are new
  status *symbols*, not a new record. `parser-resume!` and `parser-reset!` touch
  only runtime lifecycle state — no generated call, no ABI surface.
- `reserved-member-2` (the runtime-export mirror, drift-guarded) and
  `reserved-member-3` (emitter-template identifiers) are updated in the same
  commit as the exports/template they mirror.

### 3.3 The runtime takes coded conditions

§12.6/§9.4 require prohibited and lifecycle-misuse operations to "raise API-
contract conditions," and the project asserts conditions by **code and who, never
by text** (`conditions.sls` header). Today `runtime.sls` is condition-free (it
raises `assertion-violation`) because 0010 item 5 deferred coded conditions to
avoid a manifest collision. M2's lifecycle *is* the runtime's public contract and
introduces a whole family of misuse codes, so the deferral ends here:

- `runtime.sls` imports `(byte-machine private conditions)`; lifecycle misuse
  raises `&byte-machine-contract` with a stable `code`/`who` the tests assert
  directly.
- The manifest cost is real and bounded. `BYTE_MACHINE_CORE_RUNTIME` is today a
  single-file manifest; adding the import puts `conditions.sls` in both
  `CORE_RUNTIME` and (via graph/ir) `CORE_VERIFY`, which collide as a duplicate
  basename inside `CORE_ALL`. writing-plans factors a shared conditions fragment
  and de-duplicates `CORE_ALL` (the per-lane `byte_machine_lane_duplicate_basenames`
  guard stays green). No cycle is introduced: `conditions.sls` imports only
  `(rnrs)`.

This revisits 0010 item 5 and is recorded as such.

## 4. Slice ① — Incremental execution

Everything needed to feed a machine incrementally, with **no new node kind** and
minimal new engine code: `parser-feed!` already accepts arbitrary slices, returns
`need-input`, and reports exact positions. The work is a bigger proving machine,
the fragmentation/split-point differential, and the §9.6 extension.

**Deliver.**

- A **two-byte accept-sequence** machine, built from M1's existing node kinds:
  entry dispatch `s0` reads byte A and advances to dispatch `s1`; `s1` reads byte B
  and advances to a `stop`; each fallback routes to a declared `error`. This is the
  smallest machine with a genuine split point (`need-input` between A and B).
- **Fragmentation and split-point tests**, both lanes and differential: every
  split of `[A][B]` (`[A]` then `[B]`; `[AB]`; either with interspersed empty
  feeds) reaches `stopped`, and the mismatch positions of a wrong A or B report the
  correct offending byte.
- **Arbitrary/nonzero-offset slices**: feeding `[X A B Y]` over `[1,3)` yields the
  same result with exact `next`/`consumed`/`stream-offset`; an empty slice is a
  valid feed that consumes nothing (parent §11.1).
- **Extend the §9.6 end-to-end example** (both source and AOT lanes) to feed a
  nonzero-offset slice, per §25 M2 ("extend the Section 9.6 examples and their
  tests to feed a nonzero-offset slice").

**Exit.** Every split point of the sequence machine passes in both lanes and under
the differential; empty and nonzero-offset slices report exact positions; the
§9.6 example runs with a nonzero-offset slice.

## 5. Slice ② — EOF + lifecycle spine

`parser-finish!` and the lifecycle-state field the rest of M2 depends on.

**Deliver.**

- **A parser lifecycle-state field** replacing today's bare `sticky`. Slice ②
  reaches `ready`, `stopped`, `error`, and `finished`; the operation matrix
  (parent §12.2) is enforced for those rows. `poisoned` and `busy`/reentrancy are
  **out of M2** — neither can be triggered without callbacks (an unexpected escape;
  synchronous re-entry), so they ride to M5 with the callbacks that produce them.
- **`parser-finish!`** in both executors, per the §3.1 model: the interpreter's
  `op` gains eof-target/finish handling; the generated `exec` gains the `finish?`
  branch (§3.2). `finished` is sticky until reset.
- **eof-target execution and encoding.** The normalizer encodes eof-targets into
  the canonical IR (the `else` guards become real arms), and the emitter renders
  the finish branch. The IR fingerprint layout gains the eof encoding; the M1
  one-byte golden fingerprint is **unmoved** (that machine declares only the
  machine-wide default and no reachable eof chain that changes its bytes — verified
  by re-measure, not assumed).
- **The EOF zero-progress-cycle check** (§3.1) in `verify`, with a diagnostic code
  a mutation asserts; plus reachability that follows eof-targets.
- **`parser-reset!`** — trivial in M2: restore the entry state, reset stream offset
  to zero, clear lifecycle/sticky/pause/error/stop/finish state. No fields, spans,
  or user context exist to restore yet (parent §12.5's full-reset list completes in
  M4/M5).
- **Coded misuse conditions** (§3.3): each prohibited operation-matrix cell raises
  `&byte-machine-contract` with an asserted `code`/`who`.
- **Idle-vs-truncation proving surface**: a state whose eof-target resolves
  (directly or via a chain) to a **successful terminal** so `finish` returns
  `finished` (idle completion); another whose eof-target resolves to an **error**
  node so `finish` returns a truncation `error`; a machine whose eof-targets
  **loop** so verification fails. `finished` and `error` are sticky across repeated
  finish/feed.

**Exit.** EOF distinguishes idle completion (`finished`) from truncation (`error`);
`finished` is sticky; reset returns to `ready` at entry with offset 0; an
eof-target cycle fails verification; the reachable non-pause rows of the operation
matrix raise the correct coded conditions; all of the above match between
interpreted and generated execution.

## 6. Slice ③ — Pause / resume

The explicit pause node and the pause half of the lifecycle. With no callbacks
until M5, this node is M2's only generator of a pause, and it exists so the
paused-feed/paused-finish/resume lifecycle can be exercised now.

**Deliver.**

- **A new source-IR node kind**, `make-pause-node` (graph façade, verify,
  normalizer, emitter, interpreter). It carries a name and **one zero-width
  out-edge to a target** — no advance/reexecute mode, because pause reads no byte
  (parent §11.2 defines advance only for byte-reading nodes). It is the fourth
  normalized state kind.
- **Resume as a saved target state.** `exec` emits `(feed-outcome 'paused …
  next-state=target …)`; the runtime records `paused-feed` or `paused-finish` by
  entry point, saves `current = target`, and `parser-resume!` only flips lifecycle
  (`ready` or `finish-ready`) and consumes no input. The next feed/finish re-enters
  `exec` at `target`, past the pause. No continuation object — it rides the same
  numeric-state resume the executor already uses.
- **Cycle analysis treats pause as non-progress** (it consumes no input). Feed's
  zero-progress check rejects a reexecute/pause-only cycle with no advance; the EOF
  check from Slice ② already forbids an eof traversal that never reaches a terminal,
  which also forbids a pause-loop during EOF (it would resume forever, violating
  §12.4's finite-resumes guarantee).
- **Pause proving surface**, both lanes and differential: feed reaches
  `paused-feed`; `parser-resume!` returns `feed-ready`; a further feed continues to
  `stopped`. A pause reached during EOF yields `paused-finish`; resume returns
  `finish-ready`; a further `parser-finish!` continues the saved EOF path to
  `finished`.

**Exit (full Milestone 2).**

- every split point of short machines passes (Slice ①);
- empty and nonzero-offset slices pass (Slice ①);
- EOF distinguishes idle completion from truncation (Slice ②);
- the lifecycle transition table is fully tested for its **reachable** rows —
  `ready`/`paused-feed`/`paused-finish`/`finish-ready`/`stopped`/`error`/`finished`
  × `feed!`/`finish!`/`resume!`/`reset!` — with `poisoned`/`busy` explicitly
  carried to M5;
- interpreter and generated results match across all of the above.

## 7. Explicitly out of Milestone 2

- **`poisoned` and `busy`/reentrancy** lifecycle rows — they require an unexpected
  callback escape or synchronous re-entry to trigger, and callbacks are Milestone 5.
- **Byte classes, sequences, fields, actions, branches, callbacks, spans, and
  counted consumption** remain Milestones 3–6; M2's "sequence" is a hand-wired
  chain of exact-byte dispatch nodes, not the sequence *construct* of M3.
- **Field/span/user-context reset** — M2's reset restores only entry state and
  stream offset because nothing else exists yet (parent §12.5).
- **Linux arm64, Windows amd64, and the real Windows CRLF/EOF proof** remain
  Milestone 9; M2 CI stays the two Tier-1 cells (macOS arm64, Linux amd64).
- **The benchmark-gated `feed-outcome` `/v2` revisit** (decision 0010 item 5) is
  distinct from §3.2's functional `/v2` and stays gated on benchmark evidence
  (parent §23).

## 8. Handed to writing-plans

- **Gate 0 record forms.** Three records (§3.1 EOF execution model; §3.2 `/v2`
  generated ABI; §3.3 runtime coded conditions). writing-plans assigns numbers and
  confirms whether §3.1 and §3.2 stay separate or merge (both shape the executor).
- **Exact proving machines.** §4–§6 specify the *properties* the machines must
  have; writing-plans pins the concrete node wiring (byte values, whether the idle
  terminal is shared with the feed-path `stop` to exercise polysemy directly, the
  precise eof chain and the eof-cycle rejection fixture).
- **Manifest restructure (§3.3).** Factor a shared conditions fragment and
  de-duplicate `CORE_ALL` so `runtime.sls`'s new import does not collide the
  `conditions.sls` basename; keep `no-scheme` at 8/8 (no new `cmake.direct` lane).
- **Mutation discipline** (global constraints, AGENTS.md): every decision gets a
  mutation asserting a measured failure **signature** (`EXPECT_STATUS` /
  `EXPECT_OUTPUT_MATCHES`), not a bare nonzero exit; re-run the whole mutation
  suite after adding any exit path; add no new dependencies; re-measure release and
  mutation totals before writing any count into a record; confirm the M1 one-byte
  golden fingerprint is unmoved by the eof encoding.
- **TDD** (parent §22.1): failing tests first for each slice.

## 9. References

- Parent plan §25 (Milestone 2 Scope, exit criteria), §11 (transition and cursor
  semantics: input slice, advance/reexecute, non-input nodes, result position),
  §12 (parser lifecycle and results: operation matrix, feed statuses, EOF, reset,
  misuse/poisoning, runtime error structure), §16.2 (EOF-target verification), §18
  (reference interpreter independence), §20 (deterministic generation and the IR
  fingerprint), §22.4/§22.5 (differential and fragmentation tests), §9.5/§9.6
  (runtime ABI, end-to-end example).
- [milestone-1-design.md](./milestone-1-design.md) §5–§7 (what M1 built and what it
  left for M2).
- [decision 0006](../decisions/0006-inline-libraries.md) — inline `.sls`, no
  includes.
- [decision 0009](../decisions/0009-content-and-ir-fingerprints.md) — the IR
  fingerprint the eof encoding extends.
- [decision 0010](../decisions/0010-direct-executor-abi.md) — the direct-executor
  ABI (item 4: extend by `/v2`; item 5: the deferred coded condition this
  milestone's §3.3 discharges).
