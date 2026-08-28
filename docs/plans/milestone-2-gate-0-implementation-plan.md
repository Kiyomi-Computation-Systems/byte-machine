# Milestone 2 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as durable records, the three design calls Milestone 2 depends on — the EOF execution model, the `/v2` generated ABI, and the runtime taking coded conditions — so every later slice cites a decision instead of re-deriving it.

**Architecture:** This phase writes and edits *documentation only* — no product code, no tests, no CMake. It produces three new decision records (0011–0013) and adds dated amendments / minimal citation notes to the parent plan and decision 0010 in place. It is the prerequisite for Slice ② (EOF + lifecycle spine) and Slice ③ (pause/resume); Slice ① (incremental execution) consumes none of these decisions and may proceed in parallel.

**Tech Stack:** Markdown, `rg`, git. No Scheme, no CMake.

## Global Constraints

- Decision records follow the repo format: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 2, Gate 0 (milestone-2-design.md §N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. See `docs/decisions/0009-content-and-ir-fingerprints.md` and `docs/decisions/0010-direct-executor-abi.md` for the house style.
- The next free decision number is **0011** (last is `docs/decisions/0010-direct-executor-abi.md`). Confirm with `ls docs/decisions/` before writing; if a higher number exists, use the next free numbers in order.
- **Record vs instruction discipline (AGENTS.md).** A *record* (a measurement, a finding, a decision's Context, a prior decision record) gets a dated amendment note appended, never a rewrite. An *instruction* (a work-order, an exit criterion, a Deliver/Scope entry, a normative spec sentence, or a live comment saying what code is for) is corrected in place. Decision **0010** is a record → append dated amendment notes; the parent plan's §12.4/§16.2/§9.5 are normative-spec instructions → add minimal in-place citation clauses only where a reader would otherwise re-derive, never rewrite the surrounding prose.
- **Citation staleness (AGENTS.md / project memory).** Before editing any parent-plan or decision sentence, `rg` for it and Read the surrounding lines to confirm the *current* wording at HEAD. Do not trust the quoted "current text" in this plan as exact — line numbers and phrasing drift. Match against what the file says at HEAD.
- **No code, no counts.** Gate 0 changes no `.sls`, no CMake, no test. It therefore quotes and moves **no measured totals** (release/mutation/no-scheme). The one-byte golden fingerprint, the `/v2` bump, and the manifest de-dup are described as *obligations handed to the slices*, not performed here.
- Conventional Commits. One decision (plus the amendments it forces) per commit.
- `.superpowers/sdd/` is git-ignored; nothing there is committed. All artifacts here live under `docs/`.

---

## Task 1: Decision 0011 — the EOF execution model

**Files:**
- Create: `docs/decisions/0011-eof-execution-model.md`
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§12.4 EOF paragraph; §16.2 EOF-target verification bullet) — minimal citation clauses only

**Interfaces:**
- Produces: the settled contract "finish runs the feed loop with input exhausted; `stop` is polysemous (`finished` via finish); eof-targets chain and are guarded by an EOF zero-progress-cycle check; pause counts as non-progress." Slice ②'s `parser-finish!`, normalizer eof encoding, and verify EOF-cycle tasks, and Slice ③'s pause task, consume this.

- [ ] **Step 1: Confirm the decision number and read the targets**

Run:
```bash
ls docs/decisions/
rg -n "parser-finish!|eof-target|EOF edges participate|stream-idle entry state|separate zero-progress" docs/plans/byte-machine-implementation-plan.md
```
Expected: `0010-...md` is the highest-numbered record (so 0011 is free); the `rg` prints §12.4's EOF paragraph and §16.2's EOF-target bullet. Read ~10 lines around each hit to capture exact current wording before adding any citation clause.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0011-eof-execution-model.md`:

```markdown
# 0011: EOF execution — chaining eof-targets, a polysemous stop, and a unified finish path

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.1)

## Context

Milestone 1 constructed and verified EOF declarations without executing them
(parent §25 M1; milestone-1-design.md §7). `eof-target` on a byte-dispatch node
is either `#f` (route to the machine-wide `default-eof-error`) or a symbol naming
a node, and the M1 verifier checks only that the symbol resolves (parent §16.2).
Milestone 2 must decide what *executing* `parser-finish!` means.

The parent plan's §12.4 mandates that "EOF edges participate in a separate
zero-progress-cycle check" and that EOF processing "must terminate in `finished`
or `error` after a finite number of resumes," but it does not spell out which
nodes the EOF traversal passes through. A dedicated cycle check is only
load-bearing if EOF processing is a multi-step traversal that could loop; with
Milestone 1/2's node repertoire (dispatch/stop/error, plus the M2 pause) the only
multi-hop EOF traversal is an eof-target chain.

## Decision

1. **`parser-finish!` runs the same executor loop as feed, with input permanently
   exhausted.** The only branch that differs is at a dispatch node with no byte
   available: feed returns `need-input`; finish instead takes that node's
   eof-target — the named node when set, else the machine `default-eof-error`.
   Execution then continues through zero-width nodes exactly as feed does.
2. **`stop` is polysemous.** Reached via feed it yields `stopped`; reached via
   finish it yields `finished`. The node is unchanged; the status reflects the
   path. No "accept/finish" terminal node kind is introduced. This matches
   §12.1's two distinct arrows into a successful terminal.
3. **eof-targets chain.** A dispatch's eof-target may name another dispatch node;
   finish, having no byte, immediately takes *that* node's eof-target, and so on,
   until a `stop` (`finished`), an `error` node (`error`), or a pause
   (`paused-finish`). This is the general reading and is the same walk feed
   already performs; it avoids an "eof-target must resolve directly to a terminal"
   restriction that later milestones (zero-width action/callback/span nodes on the
   EOF path — §12.4) would only have to remove.
4. **EOF has its own zero-progress-cycle check.** An eof traversal reachable from
   any state must reach a terminal in finitely many steps; an eof-target loop
   fails verification with a diagnostic code. A pause consumes no input and never
   counts as progress, so a pause-loop reachable on the EOF path is rejected the
   same way (it would resume forever, violating §12.4's finite-resumes guarantee).

## Consequences

- The reference interpreter's `op` closure gains eof-target/finish handling; the
  emitter's generated `exec` gains the finish branch (decision 0012).
- The normalizer encodes eof-targets into the canonical IR (the `else` guards
  placed "for a fourth kind, Milestone 2" become real arms) and the verifier gains
  the EOF zero-progress-cycle pass.
- The Milestone 1 one-byte golden IR fingerprint must be re-measured when the eof
  encoding lands; it is expected unmoved (that machine has no reachable eof chain
  that changes its canonical bytes) but this is confirmed by measurement, not
  assumed.
- `finished` is a new sticky terminal status; its lifecycle is fixed by decision
  0013's coded conditions and the parser lifecycle-state field (Slice ②).
```

- [ ] **Step 3: Add minimal citation clauses to the parent plan**

Read the current §12.4 and §16.2 (from Step 1). Add only a bracketed citation where a reader would otherwise re-derive the model — do not rewrite the surrounding normative prose. For example, at §12.4's sentence about the separate zero-progress-cycle check, append "(the traversal is the eof-target chain; execution model recorded in decision 0011)"; at §16.2's EOF-target bullet, append "(execution and the EOF-cycle check: decision 0011)". Keep edits to a single clause each.

- [ ] **Step 4: Verify cross-references resolve and self-review**

Run:
```bash
rg -n "0011|eof-target chain|EOF-cycle" docs/plans/byte-machine-implementation-plan.md docs/decisions/0011-eof-execution-model.md
```
Expected: the two citation clauses are present and the new `0011` record resolves. Self-review the record: does it state what finish executes, the polysemous-stop and chaining calls, and the cycle check? Any "TBD"? Fix inline.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/0011-eof-execution-model.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0011 — EOF execution model (chaining eof-targets, polysemous stop, unified finish)"
```

---

## Task 2: Decision 0012 — the `/v2` generated ABI

**Files:**
- Create: `docs/decisions/0012-generated-abi-v2-finish.md`
- Modify: `docs/decisions/0010-direct-executor-abi.md` (append a dated amendment note)
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§9.5 generated runtime ABI) — minimal citation clause only

**Interfaces:**
- Produces: the settled contract "M2 adds `byte-machine-make-compiled-machine/v2` carrying a unified `exec` with a `finish?` flag; `current-abi-version`→2; the emitter emits `/v2` and retires `/v1`; the `feed-outcome` record shape is reused (`paused`/`finished` are new status symbols); `reserved-member-2`/`-3` are updated with the exports/template they mirror." Slice ②'s emitter and runtime tasks, and Slice ③'s pause arm, consume this.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "compiled-machine/v1|current-abi-version|feed-outcome|/v2|extends by|version tag exists" docs/decisions/0010-direct-executor-abi.md
rg -n "Generated runtime ABI|byte-machine-make-compiled-machine|ABI version" docs/plans/byte-machine-implementation-plan.md
```
Expected: 0010 item 4 ("extends by a `/v2` constructor rather than an arity break") and item 5 (the benchmark-gated `/v2`); parent §9.5's ABI paragraph. Read ~10 lines around each.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0012-generated-abi-v2-finish.md`:

```markdown
# 0012: The generated ABI grows a finish path under /v2 (a unified exec)

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.2)

## Context

`parser-finish!` (decision 0011) must drive the *generated* executor with no
bytes. That is a new runtime<->generated contract. Decision 0010 item 4 already
fixed how such a change is made: the seam "extends by a `/v2` constructor rather
than an arity break," and "the version tag exists for exactly that." Item 5's
benchmark-gated `/v2` is an unrelated, optimization-driven revisit of the
`feed-outcome` *record*; it is not this and stays gated on benchmark evidence.

## Decision

1. **Add `byte-machine-make-compiled-machine/v2`; bump `current-abi-version` to 2;
   the emitter emits `/v2` and retires `/v1`.** A generated file embedding version
   1 now fails the ABI-version check cleanly.
2. **The generated machine exposes one unified `exec` closure carrying a `finish?`
   flag**, not two closures. `exec` is Milestone 1's feed loop; the only arm that
   changes is the exhausted-dispatch branch — feed returns `need-input`, finish
   takes the eof-target (decision 0011). Every state arm (stop/error/dispatch and
   the pause arm from Slice ③) is rendered once and shared by both paths, so feed
   and finish cannot silently diverge. This matches 0010's "one feed procedure
   owns the dispatch loop."
3. **The `feed-outcome` record shape is reused.** `paused` and `finished` are new
   status *symbols*, not a new record. `parser-resume!` and `parser-reset!` touch
   only runtime lifecycle state — no generated call, no ABI surface.
4. **The reserved-output-binding mirrors are updated with what they mirror.**
   `reserved-member-2` (the hand-maintained mirror of `(byte-machine runtime)`
   exports) and `reserved-member-3` (emitter-template identifiers) are updated in
   the same commit as the exports/template they mirror, so the drift guard stays
   load-bearing.

## Consequences

- The emitter renders `exec` with the `finish?` branch and constructs the binding
  via `byte-machine-make-compiled-machine/v2`.
- The ABI-version-mismatch guard now rejects an embedded version 1; whether that
  guard's condition is upgraded from `assertion-violation` to a coded condition is
  enabled by decision 0013 but decided at Slice ② plan time.
- This functional `/v2` is distinct from decision 0010 item 5's benchmark-gated
  `/v2` of the `feed-outcome` record, which remains gated on benchmark evidence
  (parent §23).
```

- [ ] **Step 3: Append a dated amendment to decision 0010**

Decision 0010 is a *record* → append (do not rewrite). Add a dated section at the end of `docs/decisions/0010-direct-executor-abi.md`:

```markdown
## <today's date, YYYY-MM-DD> (Milestone 2) — the functional /v2 lands

Milestone 2 introduces `byte-machine-make-compiled-machine/v2` (decision 0012) to
carry `parser-finish!`'s EOF path as a unified `exec` with a `finish?` flag, per
item 4 above. This is the *functional* `/v2` the version tag was reserved for; it
is distinct from item 5's benchmark-gated `/v2` of the `feed-outcome` record,
which remains gated on benchmark evidence.
```

- [ ] **Step 4: Add a minimal citation clause to §9.5**

At the parent plan's §9.5 generated-runtime-ABI paragraph, append a single clause noting the version: "(Milestone 2 supersedes `/v1` with `byte-machine-make-compiled-machine/v2`, adding the finish path — decision 0012)." Do not rewrite the paragraph.

- [ ] **Step 5: Verify and self-review**

Run:
```bash
rg -n "0012|/v2|current-abi-version|finish\?" docs/decisions/0012-generated-abi-v2-finish.md docs/decisions/0010-direct-executor-abi.md docs/plans/byte-machine-implementation-plan.md
```
Expected: the record, the 0010 amendment, and the §9.5 clause all resolve and agree (functional `/v2`, unified `exec`, `feed-outcome` reused). Confirm the 0010 edit is an *appended* dated section, not a rewrite of items 1–5. Fix inline.

- [ ] **Step 6: Commit**

```bash
git add docs/decisions/0012-generated-abi-v2-finish.md docs/decisions/0010-direct-executor-abi.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0012 — /v2 generated ABI adds the finish path (unified exec)"
```

---

## Task 3: Decision 0013 — the runtime takes coded conditions

**Files:**
- Create: `docs/decisions/0013-runtime-coded-conditions.md`
- Modify: `docs/decisions/0010-direct-executor-abi.md` (append a dated amendment note discharging item 5's condition deferral)
- Modify: `docs/plans/byte-machine-implementation-plan.md` (§12.6 misuse / §9.4 conditions) — minimal citation clause only

**Interfaces:**
- Produces: the settled contract "`runtime.sls` imports `(byte-machine private conditions)`; lifecycle misuse raises `&byte-machine-contract` with a stable `code`/`who`; the `CORE_ALL` manifest is de-duplicated so `conditions.sls` does not collide as a duplicate basename." Slice ②'s runtime lifecycle-condition task and its CMake manifest task consume this.

- [ ] **Step 1: Read the targets**

Run:
```bash
rg -n "API-contract|poisoned|Prohibited lifecycle|conditions" docs/plans/byte-machine-implementation-plan.md | rg -n "12\.6|9\.4|API-contract|Prohibited"
rg -n "conditions.sls|runtime→conditions|CORE_ALL|duplicate" docs/decisions/0010-direct-executor-abi.md
rg -n "CORE_RUNTIME|CORE_ALL|CORE_VERIFY|conditions.sls" test/CMakeLists.txt
```
Expected: §12.6's "raise API-contract conditions" and §9.4's condition surface; 0010 item 5's deferral rationale ("would duplicate `conditions.sls` in the `CORE_ALL` lane manifest"); and the current single-file `BYTE_MACHINE_CORE_RUNTIME` manifest with `CORE_ALL = CORE_VERIFY + CORE_RUNTIME + interpret.sls`. Read the surrounding lines.

- [ ] **Step 2: Write the decision record**

Create `docs/decisions/0013-runtime-coded-conditions.md`:

```markdown
# 0013: The runtime takes coded conditions for lifecycle misuse

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 2, Gate 0 (milestone-2-design.md §3.3)

## Context

Parent §12.6/§9.4 require prohibited and lifecycle-misuse operations to "raise
API-contract conditions," and the project asserts conditions by **code and who,
never by rendered text** (`conditions.sls` header). Today `runtime.sls` is
condition-free — it raises `assertion-violation` — because decision 0010 item 5
deferred coded conditions in the runtime to avoid duplicating `conditions.sls` in
the `CORE_ALL` lane manifest. Milestone 2's lifecycle *is* the runtime's public
contract and introduces a whole family of misuse codes, so the deferral ends here.

## Decision

1. **`runtime.sls` imports `(byte-machine private conditions)`.** Lifecycle misuse
   (the prohibited operation-matrix cells of §12.2 — feed while paused, resume
   while ready, finish while paused, and so on) raises `&byte-machine-contract`
   with a stable `code`/`who` the lifecycle tests assert directly.
2. **The `CORE_ALL` manifest is de-duplicated.** Adding the import puts
   `conditions.sls` in both `BYTE_MACHINE_CORE_RUNTIME` and (via graph/ir)
   `BYTE_MACHINE_CORE_VERIFY`, which would collide as a duplicate basename inside
   `CORE_ALL`. A shared conditions manifest fragment is factored and `CORE_ALL`
   de-duplicates it, so the per-lane `byte_machine_lane_duplicate_basenames` guard
   stays green. No dependency cycle is introduced: `conditions.sls` imports only
   `(rnrs)`.
3. **The coded generated-runtime-ABI-mismatch condition is now enabled but not
   required by Milestone 2.** Decision 0010 item 5 deferred that condition for the
   same manifest reason; with the runtime->conditions dependency now present, it
   *may* be upgraded from `assertion-violation` to a coded condition, but Milestone
   2 does not require it. Slice ② decides whether to take it.

## Consequences

- Slice ② adds the runtime lifecycle-state field and the misuse-condition family,
  with mutations that assert each code's failure signature (`EXPECT_OUTPUT_MATCHES`
  / `EXPECT_STATUS`), not a bare nonzero exit.
- The CMake manifest is restructured (a shared conditions fragment; `CORE_ALL`
  de-dup); `no-scheme` stays at 8/8 (no new `cmake.direct` lane is registered).
- Decision 0010 item 5's condition deferral is discharged for lifecycle misuse and
  narrowed (only the optional ABI-mismatch upgrade remains open).
```

- [ ] **Step 3: Append a dated amendment to decision 0010**

Append a dated section to `docs/decisions/0010-direct-executor-abi.md` (record → append, do not rewrite item 5):

```markdown
## <today's date, YYYY-MM-DD> (Milestone 2) — item 5's condition deferral discharged

Milestone 2 gives `runtime.sls` a dependency on `(byte-machine private
conditions)` so lifecycle misuse raises coded `&byte-machine-contract` conditions
(decision 0013), factoring a shared conditions manifest fragment and
de-duplicating `CORE_ALL` to resolve the basename collision item 5 flagged. The
optional upgrade of the ABI-version-mismatch `assertion-violation` to a coded
condition is now unblocked but is not required by Milestone 2.
```

- [ ] **Step 4: Add a minimal citation clause to §12.6/§9.4**

At the parent plan's §12.6 sentence about API-contract conditions (or §9.4's condition surface, whichever the Step 1 survey shows is the right site), append: "(the runtime raises coded `&byte-machine-contract` conditions from Milestone 2 — decision 0013)." Single clause; do not rewrite.

- [ ] **Step 5: Verify and self-review**

Run:
```bash
rg -n "0013|coded.*condition|conditions.sls|CORE_ALL" docs/decisions/0013-runtime-coded-conditions.md docs/decisions/0010-direct-executor-abi.md docs/plans/byte-machine-implementation-plan.md
```
Expected: the record, the 0010 amendment, and the parent-plan clause resolve and agree. Confirm the 0010 edit is *appended*, and that the record does not claim any measured total (Gate 0 changes no code). Fix inline.

- [ ] **Step 6: Commit**

```bash
git add docs/decisions/0013-runtime-coded-conditions.md docs/decisions/0010-direct-executor-abi.md docs/plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0013 — runtime takes coded conditions for lifecycle misuse (discharges 0010 item 5)"
```

---

## Self-Review (run after all three tasks)

1. **Spec coverage:** milestone-2-design.md §3 lists three resolutions (§3.1 EOF execution model, §3.2 `/v2` generated ABI, §3.3 runtime coded conditions). Task 1 ↔ §3.1, Task 2 ↔ §3.2, Task 3 ↔ §3.3. All covered. The design's §8 also hands *proving machines* and *manifest restructure* to writing-plans, but those are Slice-①/② plan concerns, not Gate 0 (decisions only).
2. **Placeholder scan:** the only `<today's date>` tokens are fill-ins the executor resolves at write time; every other line is concrete decision text. No "TBD".
3. **Consistency:** 0011 (finish = exhausted feed loop; polysemous stop; chaining; EOF-cycle check) is the model 0012's unified `exec`/`finish?` implements and 0013's `finished` lifecycle rides on. 0012 reuses the `feed-outcome` record and keeps resume/reset off the ABI surface — matching 0013's runtime-only lifecycle state. Both 0012 and 0013 append (never rewrite) dated amendments to record 0010, per the record-vs-instruction discipline. No measured totals are quoted anywhere (Gate 0 is docs-only).
4. **Record vs instruction:** decision 0010 is amended by appended dated notes (Task 2 Step 3, Task 3 Step 3); parent-plan §9.5/§12.4/§12.6/§16.2 get single citation clauses, never rewrites. Correct.
