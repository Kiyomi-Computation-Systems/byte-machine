# Milestone 2 Design — Incremental Execution and Lifecycle

Status: design — approved shape, **delivered** (Milestone 2 complete as of
2026-08-29; see the dated note below). Authored 2026-08-28,
after Milestone 1 closed (PR #17, commit `4eb16a3`). Revised 2026-08-28 after a
systematic audit of this design against the parent plan's normative sections and
the Milestone 1 source (`.superpowers/sdd/m2-design-audit-report.md`): the audit
corrected an EOF-terminal modeling error (a distinct **finish** node, not a
"polysemous stop"), surfaced a latent Milestone 1 sticky-feed bug, and tightened
the proving surface and ABI/test obligations. The three-slice architecture is
unchanged.

**Milestone 2 complete as of 2026-08-29.** Gate 0 (decisions 0011-0013),
Slice ① (incremental execution), Slice ②a/②b-1/②b-2 (lifecycle spine, EOF
semantic core, EOF generation), and Slice ③ (pause/resume, §6) are all
delivered and reviewed; §6's dated disposition (below its Exit list) states
each of the five full-M2 exit criteria's individual state against the shipped
tree — parent §25's four criteria are the same four in shorter form (§6's own
framing), so that disposition covers both. See CHANGELOG.md's Milestone 2
entries for the release-facing summary. Merge to `main` is the pending
closing ritual as of this note.

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
one byte to a short **byte sequence** — built from M1's existing node kinds plus
the two the parent plan's closed node set (§10.6) reserves for this milestone: an
explicit **finish** terminal and an explicit **pause**.

M2 is one milestone and one continued vertical slice; like M1 it is delivered in
an explicit, ordered set of phases:

| Phase | Kind | Produces | Discharges |
| --- | --- | --- | --- |
| **Gate 0** | decisions only | 3 records | the inherited EOF/ABI/condition calls |
| **Slice ① — Incremental execution** | product | a multi-byte machine; arbitrary/nonzero-offset slices; fragmentation and split-point differential; the §9.6 example fed a nonzero-offset slice | most of §25's "arbitrary slices / `need-input` / exact offsets" |
| **Slice ② — EOF + lifecycle spine** | product | `parser-finish!`, the **finish** node, eof-target execution and encoding, `finished`, `parser-reset!`, coded misuse conditions, the EOF-cycle + finish-terminal checks, idle-vs-truncation | §25's "finish and EOF edges / sticky finished / API misuse / reset" |
| **Slice ③ — Pause / resume** | product | the pause node, `parser-resume!`, `paused-feed`/`paused-finish`/`finish-ready`, the full reachable operation matrix | §25's "explicit pause node and continuation / resume" |

Dependency order is strict. Gate 0 unblocks everything. Slice ① is mostly test
surface over feed engine M1 already shipped (`parser-feed!` already accepts
arbitrary `(bv start end)`, returns `need-input`, and reports `next`/`consumed`/
`stream-offset` for *fresh and resume* feeds), so it lands first and gives Slice
②'s EOF work a real multi-byte machine to finish against. Slice ② installs the
lifecycle-state field that Slice ③'s pause states hang off, and also fixes the one
feed path M1 got wrong (the sticky-repeat case — §5). Every slice runs in **both
execution lanes** and is checked by the **interpreter≡generated differential**
(parent §18, §22.4).

## 2. Why this shape

Read literally, §25 M2 lands arbitrary slices, `need-input`, offsets, a pause node
and continuation, resume, reset, finish and EOF edges, sticky terminal states, and
the full API-misuse condition family — all at once. That is a large step onto a
runtime that today has no lifecycle-state field at all (just `current` + a stored
`sticky` result) and an emitter that renders only `dispatch`/`stop`/`error`. This
revision keeps the scope but sequences it so that:

- the three design calls that shape EOF execution, the generated ABI, and how
  misuse surfaces are settled *before* any code depends on them (Gate 0);
- the cheap, high-value increment (incremental feeding) proves out *first*, over
  the feed engine M1 already trusts;
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
- **EOF success is a distinct `finish` node, not a re-read `stop`.** Parent §10.6
  is a *closed* node-kind set that already separates **Stop** ("successful sticky
  one-shot terminal, returns `stopped`") from **Finish** ("successful sticky EOF
  terminal, returns `finished`; a finish node may be reached only while processing
  `parser-finish!`; the verifier rejects ordinary byte or non-EOF control flow into
  it"). `stop` stays feed-only; `finished` comes from its own node kind. An earlier
  draft of this design modeled a single "polysemous stop" that yields `finished`
  when reached via finish — that is not merely a naming choice, it describes a
  machine the §16.2 verifier is *required to reject*, and it is dropped.
- **eof-targets chain, terminating at `{finish, error, pause}`.** A dispatch's
  eof-target may name another dispatch node; finish, having no byte, immediately
  takes *that* node's eof-target, and so on, until a **`finish` node**
  (`finished`), an **`error` node** (`error`), or a **pause** (`paused-finish`,
  Slice ③) — **never a `stop` node**. This is the general reading and is the same
  walk feed already performs; it avoids an "eof-target must resolve directly to a
  terminal" restriction that later milestones (zero-width action/callback/span
  nodes on the EOF path — §12.4) would only have to remove.
- **Three EOF verification checks, all mandated by §16.2.** (a) An eof traversal
  reachable from any state must reach a terminal in finitely many steps — an
  eof-target loop fails verification (the "separate zero-progress-cycle check" of
  §12.4:727). A pause consumes no input and never counts as progress, so a
  pause-loop on the EOF path is rejected the same way. (b) A `finish` node reached
  by non-EOF (byte) control flow is rejected (§16.2:908). (c) A `stop` node
  reachable through an eof-target chain is rejected (§16.2:909). Checks (b)/(c)
  require the verifier to distinguish *byte-reachability* from *eof-reachability*.

§12.4 does not spell out hop-to-hop chaining in words; it *does* mandate a
dedicated EOF-cycle check and a finite-resumes guarantee, and §16.2 mandates the
finish-terminal and EOF-reachable-stop rejections, all of which are only
load-bearing once EOF processing is a multi-step traversal into a distinct finish
terminal. This is recorded so later milestones cite it rather than re-derive it.

### 3.2 The generated ABI grows a finish path under `/v2`

`parser-finish!` must drive the *generated* executor with no bytes. That is a new
runtime↔generated contract, and [decision 0010](../decisions/0010-direct-executor-abi.md)
**item 4** already fixed how such a change is made: the seam "extends by a `/v2`
constructor rather than an arity break," and "the version tag exists for exactly
that." Two neighbours are *not* this and must not be conflated with it: 0010's
Consequences and its Slice-B amendment reserve a **benchmark-gated `/v2`** of the
`feed-outcome` *record* (optimization, gated on §23 evidence), and 0010 **item 5**
defers a coded **ABI-mismatch condition** (still `assertion-violation`). The
resolution:

- Add `byte-machine-make-compiled-machine/v2`; bump `current-abi-version` to `2`;
  **the emitter emits `/v2`; the runtime keeps its `/v1` *export*** so that a stale
  generated file embedding version 1 fails the version *check* cleanly (an
  assertion, not an unbound-identifier error). "Retire `/v1`" means *from emitter
  output only*.
- The generated machine exposes **one unified `exec` closure carrying a `finish?`
  flag**, not two closures. `exec` is M1's feed loop; the only *branch* that
  changes is the exhausted-dispatch arm — feed returns `need-input`, finish takes
  the eof-target (§3.1). The terminal **state arms are one-per-kind and distinct**:
  a `stop` arm emits `stopped`, a **`finish` arm emits `finished`**, an `error`
  arm emits `error`, and (Slice ③) a pause arm emits `paused`. This removes an ABI
  under-specification the old "shared stop arm relabeled on the finish path" model
  carried, and §16.2 (b)/(c) guarantee the stop and finish arms are each reached
  only on their own path.
- The `feed-outcome` record **shape is reused**. `paused` and `finished` are new
  status *symbols*, not a new record. `parser-resume!` and `parser-reset!` touch
  only runtime lifecycle state — no generated call, no ABI surface.
- **The reserved-output-binding mirrors are updated with what they mirror**, and
  the exact deltas are enumerated (not left as "updated"): `reserved-member-2` gains
  `byte-machine-make-compiled-machine/v2`, `parser-finish!`, `parser-resume!`,
  `parser-reset!` and **keeps** `/v1` and the `/v1` feed-outcome constructor;
  `reserved-member-3` gains `exec`, `finish?`, and any locals the finish/pause arms
  emit. The drift guard (`reserved-drift-tests.sps`) stays load-bearing.

### 3.3 The runtime takes coded conditions

§12.6/§9.4 require prohibited and lifecycle-misuse operations to "raise API-
contract conditions," and the project asserts conditions by **code and who, never
by text** (`conditions.sls` header). Today `runtime.sls` is condition-free (it
raises `assertion-violation`) because decision 0010 item 5 deferred coded
conditions in the runtime to avoid a manifest collision. M2's lifecycle *is* the
runtime's public contract and introduces a whole family of misuse codes, so the
deferral's blocker is removed here:

- `runtime.sls` imports `(byte-machine private conditions)`; lifecycle misuse
  raises `&byte-machine-contract` with a stable `code`/`who` the tests assert
  directly. The **invalid-slice** contract of §11.1 (today a bare
  `assertion-violation` at `runtime.sls:95`) becomes a coded `&byte-machine-contract`
  too, so slice-①/② tests assert a code.
- The manifest cost is real and bounded. `BYTE_MACHINE_CORE_RUNTIME` is today a
  single-file manifest; adding the import puts `conditions.sls` in both
  `CORE_RUNTIME` and (via graph/ir) `CORE_VERIFY`, which would collide as a
  duplicate basename inside `CORE_ALL`. A shared conditions manifest fragment is
  factored and the stored `CORE_ALL` value is de-duplicated before `CORE_EMIT` is
  set (the audit confirmed this is sufficient and complete). The per-lane
  `byte_machine_lane_duplicate_basenames` guard stays green; no cycle is introduced
  (`conditions.sls` imports only `(rnrs)`).
- This removes the *manifest* blocker item 5 cited, which **enables** — but does
  not require — upgrading the ABI-mismatch `assertion-violation` (item 5's own
  condition) to a coded one. That upgrade stays deferred; Slice ② decides whether
  to take it.

## 4. Slice ① — Incremental execution

Everything needed to feed a machine incrementally, with **no new node kind** and
minimal new engine code for the *fresh and resume* feed paths (the audit confirmed
`parser-feed!` already implements §11 correctly for those; only the sticky-repeat
case is broken, and that is Slice ②'s to fix — §5). The work is a bigger proving
machine, the fragmentation/split-point differential, and the §9.6 extension.

**Deliver.**

- A **three-byte (or longer) accept-sequence** machine, built from M1's existing
  node kinds: entry dispatch `s0` reads byte A and advances to `s1`; `s1` reads B
  and advances to `s2`; `s2` reads C and advances to a `stop`; each fallback routes
  to a declared `error` with an **explicit** advance-vs-reexecute mode (§11.5:664
  forbids leaving it implicit). A three-byte machine has **≥2 interior split
  points**, which the two-byte machine an earlier draft proposed does not — and
  §22.5 requires split-point *pairs* and multi-split schedules, unsatisfiable on
  one split point.
- **Fragmentation and split-point tests**, both lanes and differential, matching
  §22.5's letter: every single split of `[A][B][C]`; selected **pairs** of split
  points; a **deterministic random multi-split** schedule; and **leading,
  trailing, and intermediate** empty feeds (an empty feed is valid and consumes
  nothing — §11.1).
- **All-256 coverage at each sequence position** (§22.7): at each of the three
  positions, all 256 byte values match between interpreter and generated (the
  correct byte advances; every other takes the fallback error at the correct
  position with its declared edge mode → asserted `next`).
- **Arbitrary/nonzero-offset slices**: feeding `[X A B C Y]` over `[1,4)` yields the
  same result with exact `next`/`consumed`/`stream-offset` (parent §11.5).
- **Extend the §9.6 end-to-end example** (both source and AOT lanes) to feed a
  nonzero-offset slice, per §25 M2.

**Exit.** Every split point (and pair, and the multi-split schedule) of the
sequence machine passes in both lanes and under the differential; leading/trailing/
intermediate empty feeds and nonzero-offset slices report exact positions; all 256
values at each position match; the §9.6 example runs with a nonzero-offset slice.

## 5. Slice ② — EOF + lifecycle spine

`parser-finish!`, the **finish** node, and the lifecycle-state field the rest of
M2 depends on — plus the sticky-repeat feed fix M1 left broken.

> **Sub-split (2026-08-28):** Slice ② was cut into **②a** (lifecycle spine,
> feed-only — closed, PR #20) and **②b** (EOF execution). ②b is itself cut, along
> M1's Phase-2/Phase-3 seam, into **②b-1** (EOF semantic core through the
> *interpreter*: the finish node, the §16.2 EOF checks, `parser-finish!` +
> eof-target execution, `finished`, idle-vs-truncation — no normalizer/emitter/
> `/v2`/goldens) and **②b-2** (EOF *generation*: the normalizer finish/eof
> encoding + the IR-fingerprint move & single golden re-baseline, the emitter
> finish arm, `/v2`, and the interpreter≡generated differential over EOF).
> Everything below is delivered across ②b-1 then ②b-2. `position-kind` is
> **deferred out of M2** (2026-08-28 scope-check) — it belongs to the structured
> `parser-error-*` family §7 defers to M4/M5; the eof *offset* is already carried
> by `parser-result-stream-offset`.

**Deliver.**

- **A parser lifecycle-state field** replacing today's bare `sticky`. Slice ②
  reaches `ready`, `stopped`, `error`, and `finished`; the operation matrix
  (§12.2) is enforced for those rows. `poisoned` and `busy`/reentrancy are **out of
  M2** — neither can be triggered without callbacks (an unexpected escape;
  synchronous re-entry), so they ride to M5. A minimal `parser-lifecycle` accessor
  is exposed so the transition-table tests assert the state directly (§9.3).
- **Fix the sticky-repeat feed bug (§12.2:701) by removing the stale cache.** M1's
  `parser-feed!` returns the cached result verbatim (`runtime.sls:97`), so a repeated
  feed in a sticky state reports a stale `next`/`consumed` (indexing the *first*
  bytevector). §12.2 requires `next = the new call's start`, `consumed = 0`, stored
  stream-offset/error unchanged. **Design refinement (2026-08-28, Slice ②a):** rather
  than rebuild a fresh *cached* result, Slice ② **removes the sticky cache entirely**
  and lets `parser-feed!` always run the executor. Re-executing at a terminal is
  idempotent in M2's callback-free world — the `stop`/`error`/(②b) `finish` arms
  return exactly the §12.2 sticky-repeat tuple (`next = start`, `consumed = 0`, stored
  offset) — so the fix holds *by construction*, in both lanes, and **overturns**
  `runtime-tests.sps:95-102`, which pinned the wrong behavior. A true stored-result
  short-circuit (needed once callbacks at M5 make re-execution non-idempotent) is
  deferred to M5; the lifecycle field is observational until then. This deletes the
  now-unwitnessable `SchemeMutationSuite` "v1 terminal not made sticky" mutation,
  whose effect idempotent re-execution now provides.

  **Superseded (2026-08-29, Slice ③ — D1):** the deferral above did not survive
  contact with the ②b-2 default-EOF carry. `parser-finish-op!`'s default arm
  parks `current` on the dispatch node it just exhausted, not past it, so a
  feed after a default-EOF truncation re-ran **dispatch** and consumed bytes
  in both lanes — the idempotent re-execution this paragraph relied on was
  demonstrated broken, not merely superseded early. Slice ③ pulls the
  short-circuit forward: `stopped`/`error`/`finished` now return the §12.2
  sticky tuple **at the operation entry**, without re-running the executor
  (`runtime.sls:145-152` for `parser-feed!`, `:239-248` for
  `parser-finish!`), and the parser gains a stored-error slot (slot 7,
  `parser-stored-error`/`parser-set-stored-error!`) so the error row has a
  value to return without re-executing anything. "The lifecycle field is
  observational until then" no longer describes the shipped tree — M5's
  remaining open item is narrower than this paragraph states: only the
  *result* short-circuit callbacks will need (arbitrary stored results, not
  only the error value), not the entry-gating short-circuit itself, which
  Slice ③ already ships. Regression coverage: `runtime-tests.sps`'s "the
  error row returns the stored error after a default-EOF truncation" case.
  See the Slice ③ plan §0 D1
  (`docs/plans/milestone-2-slice-3-pause-resume-implementation-plan.md`) for
  the full rationale.
- **The `finish` node — a new node kind** (`make-finish-node` in graph/ir; a
  normalizer arm with its own canonical tag byte; a `finish` render arm in the
  emitter emitting `finished`; a `finish` kind in the interpreter `op` and the
  differential). It returns `finished` and is EOF-only.
- **`parser-finish!`** in both executors, per §3.1. It **short-circuits on a sticky
  result at the finish entry** (§12.2:695-697: `finish!` on `stopped`/`error`/
  `finished` returns the stored result) before executing any EOF path. The
  interpreter's `op` gains eof-target/finish handling; the generated `exec` gains
  the `finish?` branch (§3.2). `finished` is sticky until reset.
- **eof-target execution and encoding — two distinct normalizer changes.** (a) The
  existing **dispatch** state arm is extended to encode its `eof-target` (the
  normalizer newly imports `byte-dispatch-node-eof-target` and
  `machine-default-eof-error`); (b) the `else` guards are replaced by the new
  **finish** arm (the pause arm is Slice ③). EOF routing **is hashed into the IR
  fingerprint** — encoding the resolved `default-eof-error`/eof-targets as real
  bytes, so two machines that differ only in EOF routing get different fingerprints
  (the collision-safe choice). **The M1 one-byte golden fingerprint therefore
  moves and is re-baselined** in `normal-ir-tests.sps`, `compile-tests.sps`, and
  `test/fixtures/generated-one-byte.golden.sls` (the rendered string embeds the
  number).
- **EOF verification (§16.2), three checks with asserted diagnostic codes.** the
  EOF zero-progress-cycle check; rejection of non-EOF control flow into a `finish`
  node (§16.2:908); rejection of an EOF-reachable `stop` terminal (§16.2:909).
  `node-out-targets` (verify.sls) and reachability are extended to compute
  byte-reachability and eof-reachability separately, so an eof-only-reachable
  `finish` node is not falsely flagged unreachable.
- **`parser-reset!`** — a §12.5 subset: restore the entry state, reset stream
  offset to zero, clear lifecycle/sticky/pause/error/stop/**finish** state. No
  fields, spans, or user context exist to restore yet (the rest of §12.5 completes
  in M4/M5).
- **Coded misuse conditions** (§3.3): each prohibited operation-matrix cell, and
  the invalid-slice contract, raises `&byte-machine-contract` with an asserted
  `code`/`who`.
- **The truncation error carries the absolute stream offset** as its EOF position
  (already exposed by `parser-result-stream-offset`). **`position-kind` is deferred
  (2026-08-28, Slice ②b-2 scope-check):** its accessor `parser-error-position-kind`
  is part of the structured `parser-error-*` family (§9.3) that §7 defers to M4/M5,
  and M2's idle-vs-truncation is distinguished by *status* (`finished` vs `error`),
  not by the categorical `'eof`/`'byte`/`'boundary` marker; the eof *offset* is
  already carried. `position-kind` lands with that structured-error family, not in
  M2 — this removes an inconsistent carve-out (populating one field of an otherwise-
  deferred accessor family).
- **`/v2` blast radius** (§3.2): rewrite the `/v1` runtime-tests behavioral group as
  `/v2` (the abi=1 case now fails the version check; the "mismatch refused" case now
  uses abi≠2) and re-baseline the two goldens with the moved fingerprint. Add the
  **CHANGELOG.md** entry §9.5:444 requires for a pre-1.0 ABI change (bump +
  deterministic regeneration + changelog).
- **Idle-vs-truncation proving surface**: a state whose eof-target resolves
  (directly or via a chain) to a **`finish` node** so `finish` returns `finished`
  (idle completion); another whose eof-target resolves to an **`error` node** so
  `finish` returns a truncation `error`. Both `finished` and `error` are sticky
  across repeated finish/feed (and the sticky-repeat fix above applies). A
  **committed determinism golden** (render-twice + golden compare, both lanes)
  covers a machine that actually exercises the eof encoding.

**Exit.** EOF distinguishes idle completion (`finished`) from truncation (`error`
at the eof stream offset); `finished` is sticky and sticky-repeat feeds report
`next = new start`, `consumed = 0`; reset returns to `ready` at entry with offset
0; an eof-target cycle, a byte-reachable finish node, and an eof-reachable stop
node each fail verification with the correct code; the reachable non-pause rows of
the operation matrix (and invalid-slice) raise the correct coded conditions; the
IR fingerprint is re-baselined and deterministic across processes; all of the above
match between interpreted and generated execution.

## 6. Slice ③ — Pause / resume

The explicit pause node and the pause half of the lifecycle. With no callbacks
until M5, this node is M2's only generator of a pause, and it exists so the
paused-feed/paused-finish/resume lifecycle can be exercised now.

**Deliver.**

- **A new source-IR node kind**, `make-pause-node` (graph façade, verify,
  normalizer, emitter, interpreter). It carries a name and **one zero-width
  out-edge to a target** — the §10.6 "explicit continuation node," with no
  advance/reexecute mode, because pause reads no byte (§11.2 defines advance only
  for byte-reading nodes). It is the **fifth** normalized state kind (after
  dispatch/stop/error/finish); the normalizer therefore ends M2 with five arms.
- **Resume as a saved target state.** `exec` emits `(feed-outcome 'paused …
  next-state=target …)`; the runtime records `paused-feed` or `paused-finish` by
  entry point, saves `current = target`, and `parser-resume!` only flips lifecycle
  (`ready` or `finish-ready`) and consumes no input. The next feed/finish re-enters
  `exec` at `target`, past the pause. No continuation object — it rides the same
  numeric-state resume the executor already uses. (The audit confirmed this shape
  against §10.6/§12.1/§12.3.)

  **As shipped (2026-08-29, Slice ③ — D6):** the paused result's `next`/
  `consumed` fields follow the shape the operation demanded, not one shared
  convention. A feed-path pause returns `next` = the first unconsumed index
  and `consumed = next − start` (§10.6:608, §12.3:711) — ordinary mid-slice
  progress reporting, unaffected by pausing (`runtime.sls:183-187`). A
  finish-path pause has no slice to report against, so it mirrors the
  `finished` convention ②b already shipped: `next` = the stream offset,
  `consumed = 0` (`runtime.sls:288-291`, matching `:284-287`'s `finished`
  arm exactly). Accessor-applicability enforcement (§9.3:425) — refusing
  `parser-result-next`/`-consumed` where they are not meaningful for a given
  status — stays deferred with the structured `parser-error-*` family (§7;
  M4/M5), the same scope call ②b made for `finished` results.
- **Cycle analysis treats pause as non-progress** (it consumes no input). Feed's
  zero-progress check rejects a reexecute/pause-only cycle with no advance; the EOF
  check from Slice ② already forbids a pause-loop on the EOF path.
- **Extend the §22.6 property generator** to emit finish/eof-target and pause
  machines (§22.6:1295 names M2 as where pauses and EOF enter the bounded random
  generator) and re-run the property differential. Add a **determinism golden** for
  a pause machine.
- **Pause proving surface**, both lanes and differential: feed reaches
  `paused-feed`; `parser-resume!` returns `feed-ready`; a further feed continues to
  `stopped`. A pause reached during EOF yields `paused-finish`; resume returns
  `finish-ready`; a further `parser-finish!` continues the saved EOF path to
  `finished`.

**Exit (full Milestone 2).**

- every split point (and pair / multi-split) of short machines passes (Slice ①);
- empty and nonzero-offset slices pass (Slice ①);
- EOF distinguishes idle completion from truncation (Slice ②);
- the lifecycle transition table is fully tested for its **reachable** rows —
  `ready`/`paused-feed`/`paused-finish`/`finish-ready`/`stopped`/`error`/`finished`
  × `feed!`/`finish!`/`resume!`/`reset!` — with `poisoned`/`busy` explicitly
  carried to M5 (the M5 plan inherits those exact rows);
- interpreter and generated results match across all of the above.

> **Dispositioned 2026-08-29 at close.** These five, and parent §25's same
> four in shorter form, checked individually against the shipped tree. (1)
> **met**: `differential-sequence-tests.sps`'s "every fragmentation of 1 2 3 4
> reaches stopped in both lanes" group covers every split, split-point pairs,
> and a deterministic multi-split schedule. (2) **met**: the same file's
> leading/intermediate/trailing-empty-feed case and its "nonzero-offset
> slices" group. (3) **met**: `differential-eof-tests.sps`'s "idle, one-byte
> truncation, and full sequence agree" case. (4) **met** for the 28 reachable
> `(state, operation)` cells — `runtime-tests.sps`'s "pause + resume" and
> "operation matrix" groups witness every prohibited and sticky cell directly,
> including `error`/`finished` × `resume!`: **Task 7 close-out review found
> these two cells untested** (a mutation admitting exactly those two rows
> while still refusing `ready`/`stopped`/`finish-ready` would have survived),
> and they were closed in the same pass with two `check-raises` cases plus a
> measured mutation (`SchemeMutationSuite.cmake`, "runtime: resume admits
> error/finished instead of refusing them"). A self-review of the same
> criterion then found one more untested cell, `finished` × `finish!`
> (`parser-finish!`'s own sticky arm, distinct from the `resume!` cells
> above) — closed the same way, with one more `runtime-tests.sps` check
> (:126-137) and one more mutation (`SchemeMutationSuite.cmake`, "runtime: a
> re-finish on a finished parser does not return finished"). `ready` ×
> `reset!` has no case of its own — a documented scope call, not a gap: reset
> on an already-`ready` parser is idempotent by construction, and
> `stopped`/`error` × `reset!` are covered by the pre-existing
> "parser-reset!" group. `poisoned`/`busy` stay out of M2 per §7 and are
> excluded from the 28, not silently short. (5)
> **met**: every file cited above is a `differential-*` program comparing the
> interpreter and generated executors directly, and `differential-pause-
> tests.sps` extends this to pause continuations.

## 7. Explicitly out of Milestone 2

- **`poisoned` and `busy`/reentrancy** lifecycle rows — they require an unexpected
  callback escape or synchronous re-entry to trigger, and callbacks are Milestone 5.
  §25's "lifecycle transition table is fully tested" is read, for M2, as **over the
  reachable rows only**; the exit criterion is annotated to say so.
- **The full structured `parser-error-*` accessor family** (§9.3), including
  `position-kind` — M2 carries only the eof *stream offset* that locates truncation
  (via `parser-result-stream-offset`); the categorical `position-kind` marker and richer error
  structure arrives with the milestones that produce richer errors (M4+).
- **Byte classes, sequences, fields, actions, branches, callbacks, spans, and
  counted consumption** remain Milestones 3–6; M2's "sequence" is a hand-wired
  chain of exact-byte dispatch nodes, not the sequence *construct* of M3.
- **Field/span/user-context reset** — M2's reset restores only entry state and
  stream offset because nothing else exists yet (parent §12.5).
- **Linux arm64, Windows amd64, and the real Windows CRLF/EOF proof** remain
  Milestone 9; M2 CI stays the two Tier-1 cells (macOS arm64, Linux amd64).
- **The benchmark-gated `feed-outcome` `/v2` revisit** (decision 0010 Consequences
  / Slice-B amendment) and **the coded ABI-mismatch condition** (decision 0010 item
  5) are distinct from this milestone's functional `/v2` (§3.2) and coded-lifecycle
  conditions (§3.3); the ABI-mismatch condition upgrade is *enabled* by §3.3 but
  stays deferred, and the benchmark `/v2` stays gated on §23 evidence.

## 8. Handed to writing-plans

- **Gate 0 record forms.** Three records (§3.1 EOF execution model — including the
  distinct finish node and the three §16.2 checks; §3.2 `/v2` generated ABI; §3.3
  runtime coded conditions). writing-plans assigns numbers and confirms whether
  §3.1 and §3.2 stay separate or merge (both shape the executor). The Gate-0 §16.2
  citation edit must **widen its survey** to the load-bearing lines (`finish
  terminal` / `EOF-reachable stop` / `reach finish or error` at §16.2:908-909), not
  only the eof-target bullet, and reconcile the record with those two mandatory
  checks.
- **Exact proving machines.** §4–§6 specify the *properties* the machines must
  have; writing-plans pins the concrete node wiring (a ≥3-byte sequence with ≥2
  interior split points; per-fallback advance-vs-reexecute mode and the asserted
  `next`; the eof chain; the eof-cycle, byte-reachable-finish, and eof-reachable-
  stop rejection fixtures; the idle→`finish`-node and truncation→`error`-node
  fixtures — there is **no** "shared terminal / polysemy" fixture, which §16.2:909
  makes unverifiable).
- **The sticky-repeat feed fix (C2) and the `/v2` blast radius (G1).** Slice ②
  owns the engine change and overturns `runtime-tests.sps:95-102`, rewrites the
  `/v1` runtime test group as `/v2`, and re-baselines the two goldens plus the
  moved IR fingerprint; add the §9.5:444 CHANGELOG entry.
- **Reserved-member deltas, enumerated** (§3.2): member-2 += `/v2`,
  `parser-finish!`, `parser-resume!`, `parser-reset!` (keep `/v1` + `/v1`
  feed-outcome); member-3 += `exec`, `finish?`, and any finish/pause locals.
- **Manifest restructure (§3.3).** Factor a shared conditions fragment and
  de-duplicate the stored `CORE_ALL` value; keep `no-scheme` at 8/8 (no new
  `cmake.direct` lane).
- **Mutation discipline** (global constraints, AGENTS.md): every decision gets a
  mutation asserting a measured failure **signature** (`EXPECT_STATUS` /
  `EXPECT_OUTPUT_MATCHES`), not a bare nonzero exit; re-run the whole mutation
  suite after adding any exit path; add no new dependencies; re-measure release and
  mutation totals before writing any count into a record.
- **TDD** (parent §22.1): failing tests first for each slice.

## 9. References

- Parent plan §25 (Milestone 2 Scope, exit criteria), §9.3 (normative runtime
  calls), §9.4 (conditions), §9.5 (generated runtime ABI, CHANGELOG requirement),
  §9.6 (end-to-end example), §10.6 (the closed node-kind set — Stop / Finish /
  Pause), §11 (transition and cursor semantics), §12 (parser lifecycle and results:
  operation matrix §12.2, EOF §12.4, reset §12.5, misuse §12.6, error structure
  §12.7), §16.2 (verification — EOF-target, finish-terminal, EOF-reachable-stop,
  EOF-cycle checks), §16.4 (diagnostic structure), §17/§19/§20 (normalization,
  backend, deterministic generation + IR fingerprint), §22.4 (differential), §22.5
  (fragmentation), §22.6 (property generator), §22.7 (all-byte), §22.9
  (determinism).
- [milestone-1-design.md](./milestone-1-design.md) §5–§7 (what M1 built and left).
- `.superpowers/sdd/m2-design-audit-report.md` — the audit that produced this
  revision (74 findings; the finish-node and sticky-feed corrections).
- [decision 0006](../decisions/0006-inline-libraries.md) — inline `.sls`, no
  includes.
- [decision 0009](../decisions/0009-content-and-ir-fingerprints.md) — the IR
  fingerprint the eof encoding extends (and moves).
- [decision 0010](../decisions/0010-direct-executor-abi.md) — the direct-executor
  ABI (**item 4**: extend by `/v2`, the warrant §3.2 relies on; **item 5**: the
  deferred coded ABI-mismatch condition; Consequences / Slice-B amendment: the
  benchmark-gated `/v2`).

## Appendix — per-library change map

| Library | M2 change |
|---|---|
| `graph`/`private ir` | `make-finish-node` (Slice ②); `make-pause-node` (Slice ③); export both. |
| `verify` | encode eof-target into byte-reachability *and* eof-reachability; EOF zero-progress-cycle check; reject non-EOF flow into a finish node; reject EOF-reachable stop; extend zero-progress to count pause as non-progress. |
| `private normal-ir` | extend the **dispatch** arm to encode `eof-target` (new imports); replace the `else` guards with **finish** (Slice ②) and **pause** (Slice ③) arms + canonical tag bytes; the IR fingerprint **moves** (re-baseline the golden). |
| `compile` (emitter) | unified `exec` with a `finish?` branch; distinct `finish` arm emitting `finished`; pause arm; `/v2` constructor call (emit `/v2`, keep `/v1` export); enumerated `reserved-member-2`/`-3` deltas. |
| `interpret` | `op` gains eof-target/finish messages and `finish`/`pause` handling. |
| `runtime` | explicit lifecycle-state field + `parser-lifecycle` accessor, **replacing the sticky cache** (removed — idempotent re-execution provides §12.2 sticky-repeat by construction; a stored-result short-circuit returns at M5 with callbacks); `parser-finish!`, `parser-resume!`, `parser-reset!`; `paused`/`finished` statuses; truncation carries the eof stream offset; `/v2` constructor; import `conditions`; coded misuse + invalid-slice conditions; operation-matrix enforcement. |
| CMake `test/CMakeLists.txt` | shared conditions fragment; de-dup `CORE_ALL`; rewrite `/v1` runtime lane group as `/v2`; new determinism goldens. |
