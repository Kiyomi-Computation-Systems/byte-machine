# Milestone 2 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as durable records, the three design calls Milestone 2 depends on — the EOF execution model (with the distinct **finish** node and the three §16.2 checks), the `/v2` generated ABI, and the runtime taking coded conditions — so every later slice cites a decision instead of re-deriving it.

**Architecture:** This phase writes and edits *documentation only* — no product code, no tests, no CMake. It produces three new decision records (0011–0013) and adds dated amendments / minimal citation notes to the parent plan and decision 0010 in place. It is the prerequisite for Slice ② (EOF + lifecycle spine) and Slice ③ (pause/resume); Slice ① (incremental execution) consumes none of these decisions and may proceed in parallel. The record text below was corrected by the 2026-08-28 design audit (`.superpowers/sdd/m2-design-audit-report.md`): EOF success is a distinct `finish` node, not a "polysemous stop."

**Tech Stack:** Markdown, `rg`, git. No Scheme, no CMake.

## Global Constraints

- Decision records follow the repo format: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 2, Gate 0 (milestone-2-design.md §N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. See `.decisions/0009-content-and-ir-fingerprints.md` and `.decisions/0010-direct-executor-abi.md` for the house style.
- The next free decision number is **0011** (last is `.decisions/0010-direct-executor-abi.md`). Confirm with `ls .decisions/` before writing; if a higher number exists, use the next free numbers in order.
- **Record vs instruction discipline (AGENTS.md).** A *record* (a measurement, a finding, a decision's Context, a prior decision record) gets a dated amendment note appended, never a rewrite. An *instruction* (a work-order, an exit criterion, a Deliver/Scope entry, a normative spec sentence, or a live comment saying what code is for) is corrected in place. Decision **0010** is a record → append dated amendment notes; the parent plan's §9.5/§12.4/§12.6/§16.2 are normative-spec instructions → add minimal in-place citation clauses only where a reader would otherwise re-derive, never rewrite the surrounding prose.
- **Citation staleness (AGENTS.md / project memory).** Before editing any parent-plan or decision sentence, `rg` for it and Read the surrounding lines to confirm the *current* wording at HEAD. Do not trust the quoted "current text" in this plan as exact — line numbers and phrasing drift. The §16.2 EOF checks live at two separate places (the eof-target bullet AND the finish-terminal / EOF-reachable-stop lines); survey for both.
- **0010 citation precision (audit A5).** In 0010: **item 4** ("extends by a `/v2` constructor rather than an arity break") is the warrant decision 0012 relies on; **item 5** is the deferred coded **ABI-mismatch** condition; the **benchmark-gated `feed-outcome` `/v2`** lives in 0010 Consequences and its Slice-B amendment. Cite each precisely; do not conflate the functional `/v2` (0012) with either.
- **No code, no counts.** Gate 0 changes no `.sls`, no CMake, no test. It quotes and moves **no measured totals**. The finish/pause node kinds, the `/v2` bump, the sticky-feed fix, the golden re-baseline, and the manifest de-dup are described as *obligations handed to the slices*, not performed here.
- Conventional Commits. One decision (plus the amendments it forces) per commit.
- `.superpowers/sdd/` is git-ignored; nothing there is committed. All artifacts here live under `docs/`.

---

## Task 1: Decision 0011 — the EOF execution model

**Files:**
- Create: `.decisions/0011-eof-execution-model.md`
- Modify: `.plans/byte-machine-implementation-plan.md` (§12.4 EOF paragraph; §16.2 EOF-target bullet AND the finish-terminal / EOF-reachable-stop lines) — minimal citation clauses only

**Interfaces:**
- Produces: the settled contract "finish runs the feed loop with input exhausted; EOF success is a distinct **finish** node (never a re-read `stop`); eof-targets chain, terminating at `{finish, error, pause}`; three §16.2 checks guard EOF (zero-progress-cycle, non-EOF-flow-into-finish, EOF-reachable-stop); pause counts as non-progress." Slice ②'s finish-node, `parser-finish!`, normalizer eof encoding, and verify tasks, and Slice ③'s pause task, consume this.

- [ ] **Step 1: Confirm the decision number and read ALL the targets**

Run:
```bash
ls .decisions/
rg -n "parser-finish!|eof-target|EOF edges participate|stream-idle entry state|separate zero-progress" .plans/byte-machine-implementation-plan.md
rg -n "finish terminal|finish node|EOF-reachable stop|reach finish or error|non-EOF control flow" .plans/byte-machine-implementation-plan.md
```
Expected: `0010-...md` is the highest-numbered record (so 0011 is free); the first `rg` prints §12.4's EOF paragraph and §16.2's eof-target bullet; the **second** `rg` prints §10.6's Finish-node definition and the two load-bearing §16.2 checks ("non-EOF control flow into a finish terminal", "EOF-reachable stop terminals"). Read ~10 lines around each hit — the model must reconcile with these, not just the eof-target bullet.

- [ ] **Step 2: Write the decision record**

Create `.decisions/0011-eof-execution-model.md`:

```markdown
# 0011: EOF execution — a distinct finish node, chaining eof-targets, and a unified finish path

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.1)

## Context

Milestone 1 constructed and verified EOF declarations without executing them
(parent §25 M1; milestone-1-design.md §7). `eof-target` on a byte-dispatch node
is either `#f` (route to the machine-wide `default-eof-error`) or a symbol naming
a node, and the M1 verifier checks only that the symbol resolves (parent §16.2).
Milestone 2 must decide what *executing* `parser-finish!` means.

Parent §10.6 is a **closed** node-kind set that already separates **Stop**
("successful sticky one-shot terminal, returns `stopped`") from **Finish**
("successful sticky EOF terminal, returns `finished`; a finish node may be reached
only while processing `parser-finish!`; the verifier rejects ordinary byte or
non-EOF control flow into it"). §16.2 correspondingly **requires** the verifier to
reject non-EOF control flow into a finish terminal and to reject EOF-reachable stop
terminals, and §12.4 mandates a separate EOF zero-progress-cycle check with a
finite-resumes guarantee. Those checks are only load-bearing once EOF processing is
a multi-step traversal into a distinct finish terminal.

## Decision

1. **`parser-finish!` runs the same executor loop as feed, with input permanently
   exhausted.** The only branch that differs is at a dispatch node with no byte
   available: feed returns `need-input`; finish instead takes that node's
   eof-target — the named node when set, else the machine `default-eof-error`.
   Execution then continues through zero-width nodes exactly as feed does.
2. **EOF success is a distinct `finish` node.** `stop` stays feed-only and returns
   `stopped`; `finished` comes from its own node kind (§10.6), which is reachable
   only while processing `parser-finish!`. There is no "polysemous stop"; modeling
   EOF success as a stop re-read on the finish path describes a machine §16.2
   requires the verifier to reject.
3. **eof-targets chain, terminating at `{finish, error, pause}` — never `stop`.**
   A dispatch's eof-target may name another dispatch node; finish, having no byte,
   immediately takes *that* node's eof-target, and so on, until a `finish` node
   (`finished`), an `error` node (`error`), or a pause (`paused-finish`). This is
   the general reading and is the same walk feed already performs; it avoids an
   "eof-target must resolve directly to a terminal" restriction that later
   milestones (zero-width action/callback/span nodes on the EOF path — §12.4) would
   only have to remove.
4. **Three EOF verification checks, each with an asserted diagnostic code.**
   (a) an eof traversal reachable from any state must reach a terminal in finitely
   many steps — an eof-target loop fails (a pause consumes no input and never
   counts as progress, so a pause-loop on the EOF path fails the same way);
   (b) a `finish` node reached by non-EOF (byte) control flow is rejected
   (§16.2); (c) a `stop` node reachable through an eof-target chain is rejected
   (§16.2). Checks (b)/(c) require the verifier to distinguish byte-reachability
   from eof-reachability.

## Consequences

- M2 adds **two** node/state kinds — a **finish** node (Slice ②) and a **pause**
  node (Slice ③). The reference interpreter's `op` closure and the generated
  `exec` (decision 0012) gain a `finish` arm emitting `finished`, distinct from the
  `stop` arm.
- The normalizer changes in **two distinct ways** (not "the else guards become
  real arms"): (a) the existing **dispatch** state arm is extended to encode its
  `eof-target`; (b) the `else` guards are replaced by the new **finish** (Slice ②)
  and **pause** (Slice ③) arms, each with its own canonical tag byte. Because EOF
  routing is now hashed into the IR fingerprint (the collision-safe choice, so two
  machines differing only in EOF routing hash differently), the Milestone 1
  one-byte golden fingerprint **moves and is re-baselined** in Slice ②.
- The verifier gains the EOF zero-progress-cycle, finish-terminal, and
  EOF-reachable-stop checks, and computes byte-reachability and eof-reachability
  separately so an eof-only-reachable finish node is not falsely flagged
  unreachable.
- `finished` is a new sticky terminal status; its lifecycle rides the parser
  lifecycle-state field and coded conditions of decision 0013 (Slice ②).
```

- [ ] **Step 3: Add minimal citation clauses to the parent plan**

Read the current §12.4 and both §16.2 sites (from Step 1). Add only a bracketed citation where a reader would otherwise re-derive the model — do not rewrite the surrounding normative prose. Suggested: at §12.4's separate-zero-progress-cycle sentence, append "(the traversal is the eof-target chain terminating at finish/error/pause; execution model in decision 0011)"; at the §16.2 finish-terminal / EOF-reachable-stop lines, append "(these two checks + the EOF-cycle check are decision 0011's; each carries a diagnostic code)"; at the §16.2 eof-target bullet, append "(EOF *execution*: decision 0011)". One clause each.

- [ ] **Step 4: Verify cross-references resolve and self-review**

Run:
```bash
rg -n "0011|finish node|eof-target chain|EOF-reachable stop|byte-reachability" .plans/byte-machine-implementation-plan.md .decisions/0011-eof-execution-model.md
```
Expected: the citation clauses are present at BOTH §16.2 sites and §12.4, and the new `0011` record resolves. Self-review the record: distinct finish node? chain terminates at finish/error/pause (never stop)? three §16.2 checks? two new kinds + the two-part normalizer change + golden re-baseline in consequences? Any "TBD"? Fix inline.

- [ ] **Step 5: Commit**

```bash
git add .decisions/0011-eof-execution-model.md .plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0011 — EOF execution model (distinct finish node, chaining eof-targets, three §16.2 checks)"
```

---

## Task 2: Decision 0012 — the `/v2` generated ABI

**Files:**
- Create: `.decisions/0012-generated-abi-v2-finish.md`
- Modify: `.decisions/0010-direct-executor-abi.md` (append a dated amendment note)
- Modify: `.plans/byte-machine-implementation-plan.md` (§9.5 generated runtime ABI) — minimal citation clause only

**Interfaces:**
- Produces: the settled contract "M2 adds `byte-machine-make-compiled-machine/v2` carrying a unified `exec` with a `finish?` flag; `current-abi-version`→2; the emitter emits `/v2` while the runtime **keeps its `/v1` export**; terminal arms are one-per-kind (a distinct `finish` arm emits `finished`); the `feed-outcome` record shape is reused; `reserved-member-2`/`-3` gain enumerated deltas." Slice ②'s emitter and runtime tasks, and Slice ③'s pause arm, consume this.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "compiled-machine/v1|current-abi-version|feed-outcome|/v2|extends by|version tag exists|benchmark" .decisions/0010-direct-executor-abi.md
rg -n "Generated runtime ABI|byte-machine-make-compiled-machine|ABI version|CHANGELOG|changelog" .plans/byte-machine-implementation-plan.md
rg -n "reserved-member-2|reserved-member-3" src/byte-machine/compile.sls
```
Expected: 0010 **item 4** (the `/v2`-not-arity-break warrant), **item 5** (the ABI-mismatch coded-condition deferral), and the **Consequences / Slice-B amendment** benchmark `/v2` — cited by name because line numbers into that record have since moved; parent §9.5's ABI paragraph and its CHANGELOG requirement; the current `reserved-member-2`/`-3` lists in compile.sls. Read ~10 lines around each.

- [ ] **Step 2: Write the decision record**

Create `.decisions/0012-generated-abi-v2-finish.md`:

```markdown
# 0012: The generated ABI grows a finish path under /v2 (a unified exec)

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.2)

## Context

`parser-finish!` (decision 0011) must drive the *generated* executor with no
bytes. That is a new runtime<->generated contract. Decision 0010 **item 4** already
fixed how such a change is made: the seam "extends by a `/v2` constructor rather
than an arity break," and "the version tag exists for exactly that." Two neighbours
are *not* this: 0010's Consequences / Slice-B amendment reserve a benchmark-gated
`/v2` of the `feed-outcome` *record* (optimization, gated on §23 evidence), and
0010 item 5 defers a coded ABI-mismatch condition. This record is the functional
`/v2` item 4 anticipated.

## Decision

1. **Add `byte-machine-make-compiled-machine/v2`; bump `current-abi-version` to 2.
   The emitter emits `/v2`; the runtime KEEPS its `/v1` export.** "Retire `/v1`"
   means from emitter *output* only — keeping the `/v1` export lets a stale
   generated file embedding version 1 fail the ABI-version *check* cleanly (an
   assertion), not fail at import with an unbound identifier.
2. **The generated machine exposes one unified `exec` closure carrying a `finish?`
   flag**, not two closures. `exec` is Milestone 1's feed loop; the only *branch*
   that changes is the exhausted-dispatch arm — feed returns `need-input`, finish
   takes the eof-target (decision 0011). The terminal state arms are **one per
   kind and distinct**: `stop` emits `stopped`, `finish` emits `finished`, `error`
   emits `error`, and (Slice ③) pause emits `paused`. §16.2's finish-terminal and
   EOF-reachable-stop checks guarantee the stop and finish arms are each reached
   only on their own path, so no arm is relabeled across paths.
3. **The `feed-outcome` record shape is reused.** `paused` and `finished` are new
   status *symbols*, not a new record. `parser-resume!` and `parser-reset!` touch
   only runtime lifecycle state — no generated call, no ABI surface.
4. **The reserved-output-binding mirrors gain enumerated deltas.**
   `reserved-member-2` (the hand-maintained mirror of `(byte-machine runtime)`
   exports) gains `byte-machine-make-compiled-machine/v2`, `parser-finish!`,
   `parser-resume!`, `parser-reset!` and **keeps** `/v1` and the `/v1`
   feed-outcome constructor; `reserved-member-3` (emitter-template identifiers)
   gains `exec`, `finish?`, and any locals the finish/pause arms emit. Both are
   updated in the same commit as the exports/template they mirror, so the drift
   guard stays load-bearing.

## Consequences

- The emitter renders `exec` with the `finish?` branch and a distinct `finish`
  arm, and constructs the binding via `byte-machine-make-compiled-machine/v2`.
- Retiring `/v1` from emitter output inverts the Milestone 1 `/v1` runtime-test
  group and moves the two goldens (the rendered string embeds the ABI tag and the
  IR fingerprint, which also moves under decision 0011's EOF encoding); Slice ②
  rewrites that test group as `/v2` and re-baselines. Parent §9.5 also requires a
  CHANGELOG.md entry for a pre-1.0 ABI change; Slice ② carries it.
- This functional `/v2` is distinct from the benchmark-gated `feed-outcome` `/v2`
  (0010 Consequences / Slice-B amendment, still gated on §23) and from the coded
  ABI-mismatch condition (0010 item 5, still deferred — decision 0013 only unblocks
  it).
```

- [ ] **Step 3: Append a dated amendment to decision 0010**

Decision 0010 is a *record* → append (do not rewrite). Add a dated section at the end of `.decisions/0010-direct-executor-abi.md`:

```markdown
## <today's date, YYYY-MM-DD> (Milestone 2) — the functional /v2 lands

Milestone 2 introduces `byte-machine-make-compiled-machine/v2` (decision 0012) to
carry `parser-finish!`'s EOF path as a unified `exec` with a `finish?` flag, per
item 4. The emitter emits `/v2`; the runtime keeps the `/v1` export so a stale v1
file fails the version check cleanly. This is the *functional* `/v2` item 4
reserved the version tag for. It is distinct from the benchmark-gated `feed-outcome`
`/v2` (Consequences / the Slice-B amendment above), which remains gated on §23
evidence, and from item 5's coded ABI-mismatch condition, which remains deferred.
```

- [ ] **Step 4: Add a minimal citation clause to §9.5**

At the parent plan's §9.5 generated-runtime-ABI paragraph, append a single clause: "(Milestone 2 adds `byte-machine-make-compiled-machine/v2` with the finish path — a unified `exec` carrying `finish?`; the emitter emits `/v2`, the runtime keeps the `/v1` export — decision 0012)." Do not rewrite the paragraph.

- [ ] **Step 5: Verify and self-review**

Run:
```bash
rg -n "0012|/v2|current-abi-version|finish\?|keeps.*/v1|item 4" .decisions/0012-generated-abi-v2-finish.md .decisions/0010-direct-executor-abi.md .plans/byte-machine-implementation-plan.md
```
Expected: the record, the 0010 amendment, and the §9.5 clause resolve and agree (functional `/v2` per item 4; distinct `finish` arm; `/v1` export kept; benchmark `/v2` and item 5 condition kept separate). Confirm the 0010 edit is an *appended* dated section, not a rewrite of items 1–5, and that the citations distinguish item 4 / item 5 / Consequences. Fix inline.

- [ ] **Step 6: Commit**

```bash
git add .decisions/0012-generated-abi-v2-finish.md .decisions/0010-direct-executor-abi.md .plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0012 — /v2 generated ABI adds the finish path (unified exec, distinct finish arm)"
```

---

## Task 3: Decision 0013 — the runtime takes coded conditions

**Files:**
- Create: `.decisions/0013-runtime-coded-conditions.md`
- Modify: `.decisions/0010-direct-executor-abi.md` (append a dated amendment note narrowing item 5's deferral)
- Modify: `.plans/byte-machine-implementation-plan.md` (§12.6 misuse / §11.1 invalid-slice / §9.4 conditions) — minimal citation clause only

**Interfaces:**
- Produces: the settled contract "`runtime.sls` imports `(byte-machine private conditions)`; lifecycle misuse AND the §11.1 invalid-slice contract raise `&byte-machine-contract` with a stable `code`/`who`; the stored `CORE_ALL` manifest is de-duplicated so `conditions.sls` does not collide as a duplicate basename; item 5's ABI-mismatch condition is unblocked but not required." Slice ②'s runtime lifecycle-condition task and its CMake manifest task consume this.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "API-contract|Prohibited lifecycle|invalid slice|before parser mutation" .plans/byte-machine-implementation-plan.md | rg -n "11\.1|12\.6|9\.4|API-contract|Prohibited|invalid"
rg -n "assertion-violation|invalid slice" src/byte-machine/runtime.sls
rg -n "conditions.sls|CORE_ALL|duplicate|runtime" .decisions/0010-direct-executor-abi.md
rg -n "CORE_RUNTIME|CORE_ALL|CORE_VERIFY|CORE_EMIT|conditions.sls" test/CMakeLists.txt
```
Expected: §12.6's "raise API-contract conditions", §11.1's invalid-slice "API-contract condition", §9.4's condition surface; `runtime.sls:95-96`'s bare `assertion-violation` for a bad slice; 0010 item 5's deferral rationale ("would duplicate `conditions.sls` in the `CORE_ALL` lane manifest"); and the current single-file `BYTE_MACHINE_CORE_RUNTIME` with `CORE_ALL = CORE_VERIFY + CORE_RUNTIME + interpret.sls` (and where `CORE_EMIT` is set relative to `CORE_ALL`). Read the surrounding lines.

- [ ] **Step 2: Write the decision record**

Create `.decisions/0013-runtime-coded-conditions.md`:

```markdown
# 0013: The runtime takes coded conditions for lifecycle misuse

Date: <today's date, YYYY-MM-DD>
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
```

- [ ] **Step 3: Append a dated amendment to decision 0010**

Append a dated section to `.decisions/0010-direct-executor-abi.md` (record → append, do not rewrite item 5):

```markdown
## <today's date, YYYY-MM-DD> (Milestone 2) — item 5's manifest blocker discharged

Milestone 2 gives `runtime.sls` a dependency on `(byte-machine private
conditions)` so lifecycle misuse and the §11.1 invalid-slice contract raise coded
`&byte-machine-contract` conditions (decision 0013), factoring a shared conditions
manifest fragment and de-duplicating `CORE_ALL` to resolve the basename collision
item 5 flagged. Item 5's own deferral — the coded ABI-version-mismatch condition —
is thereby *unblocked* but not yet taken: the mismatch still raises
`assertion-violation` until a slice upgrades it.
```

- [ ] **Step 4: Add a minimal citation clause to §12.6/§11.1**

At the parent plan's §12.6 sentence about API-contract conditions (and/or §11.1's invalid-slice sentence, whichever the Step 1 survey shows is the right site), append: "(the runtime raises coded `&byte-machine-contract` conditions from Milestone 2, invalid-slice included — decision 0013)." Single clause; do not rewrite.

- [ ] **Step 5: Verify and self-review**

Run:
```bash
rg -n "0013|coded.*condition|conditions.sls|CORE_ALL|invalid-slice|unblocked" .decisions/0013-runtime-coded-conditions.md .decisions/0010-direct-executor-abi.md .plans/byte-machine-implementation-plan.md
```
Expected: the record, the 0010 amendment, and the parent-plan clause resolve and agree. Confirm the 0010 edit is *appended*; that the record discharges only item 5's *manifest blocker* (not item 5's condition); and that it claims no measured total (Gate 0 changes no code). Fix inline.

- [ ] **Step 6: Commit**

```bash
git add .decisions/0013-runtime-coded-conditions.md .decisions/0010-direct-executor-abi.md .plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0013 — runtime takes coded conditions for lifecycle misuse (discharges 0010 item 5's manifest blocker)"
```

---

## Self-Review (run after all three tasks)

1. **Spec coverage:** milestone-2-design.md §3 lists three resolutions (§3.1 EOF execution model, §3.2 `/v2` generated ABI, §3.3 runtime coded conditions). Task 1 ↔ §3.1, Task 2 ↔ §3.2, Task 3 ↔ §3.3. All covered. The design's §8 also hands *proving machines*, the *sticky-feed fix*, the *golden re-baseline*, and the *manifest restructure* to writing-plans, but those are Slice-①/② plan concerns, not Gate 0 (decisions only).
2. **Placeholder scan:** the only `<today's date>` tokens are fill-ins the executor resolves at write time; every other line is concrete decision text. No "TBD".
3. **Consistency with the audit:** 0011 models a **distinct finish node** (not polysemous stop), chains eof-targets to `{finish, error, pause}`, and carries all three §16.2 checks; 0012's unified `exec` has a **distinct `finish` arm** and keeps the `/v1` export; 0013 discharges only item 5's *manifest blocker* and leaves item 5's ABI-mismatch condition deferred. The 0010 citations distinguish item 4 (the `/v2` warrant) / item 5 (the ABI-mismatch condition) / Consequences (the benchmark `/v2`). No measured totals are quoted (Gate 0 is docs-only).
4. **Record vs instruction:** decision 0010 is amended by appended dated notes (Task 2 Step 3, Task 3 Step 3); parent-plan §9.5/§12.4/§12.6/§11.1/§16.2 get single citation clauses at the correct (surveyed) sites, never rewrites. Correct.
