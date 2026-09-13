# Milestone 4 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as durable records, the five design calls Milestone 4 depends on — the unversioned generated-ABI constructor, the pre-provisioned encoding format 2, the constructor/verifier split for field shape, multi-successor EOF classification, and the structured `parser-error` record — and carry the two amendments the first of them forces, so every later slice cites a decision instead of re-deriving it.

**Architecture:** This phase writes and edits *documentation only* — no product code, no tests, no CMake. It produces five new decision records (0018–0022), **two** dated amendment notes — on decision 0012 item 1 and on decision 0010 item 4 — one in-place correction to the parent plan's §9.5:442, and the Gate-0-discharged mapping in the design document. It is the prerequisite for all four M4 slices: Slice ①a consumes 0018, 0019 and 0022; ①b consumes 0019 and 0020; ② consumes 0019, 0020 and 0021; ③ consumes 0020 and 0021. No slice may begin before its records exist, because each record's Consequences section is what removes work from the slice that would otherwise be re-derived — 0019 in particular is what makes ①b's, ②'s and ③'s "no existing golden moves" oracle true, and a slice that starts without it will pay a second re-baseline.

**Tech Stack:** Markdown, `rg`, git. No Scheme, no CMake.

## Global Constraints

- Decision records follow the repo format: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 4, Gate 0 (milestone-4-design.md §4.N)` / `## Context` / `## Decision` (numbered) / `## Consequences`. See `.decisions/0011-eof-execution-model.md` and `.decisions/0017-degenerate-shapes-are-contract-violations.md` for the house style, and `.decisions/README.md` for what earns a record at all.
- The next free decision number is **0018** (last is `.decisions/0017-degenerate-shapes-are-contract-violations.md`). Confirm with `ls .decisions/` before writing; if a higher number exists because a record landed from another branch, use the next free numbers in order and renumber the cross-references between these five records to match.
- **Every date written in this phase is the literal date the task runs.** The record bodies below carry `2026-08-31`; if a task runs later, correct the `Date:` line and every dated amendment note to the actual day. A dated note that lies about its day is worse than none.
- **Record vs instruction discipline (AGENTS.md, "Correct a stale instruction in place; annotate a stale record").** A *record* — a measurement, a finding, a decision record's Context — gets a dated amendment note appended, never a rewrite, because a record edited to agree with a later decision stops being evidence of anything. An *instruction* — a work order, an exit criterion, a Scope entry, a normative spec sentence, or a live comment saying what code is for — is corrected in place, because leaving a false one is a landmine and what it used to say is in git. Task 1 applies both halves: decisions 0012 and 0010 are **records** and are annotated; the parent plan's §9.5:442 sentence is a **normative-spec instruction** and is corrected.
- **Citation staleness (AGENTS.md; project memory).** Before editing any parent-plan or source sentence, `rg` for it and read the surrounding lines to confirm the *current* wording at HEAD. Do not trust the quoted "current text" in this plan as exact — line numbers and phrasing drift, and this plan's line numbers were measured at `a942327` plus the design commit `0a267de`.
- **No code, no counts, no forecasts.** Gate 0 changes no `.sls`, no `.sps`, no CMake, no test. It does not touch `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (46/236 today, at `test/support/cmake/SchemeMutationSuite.cmake:734-735`), quote them as predictions, or forecast a milestone total. The constructors, the node kinds, the verifier arms, the lowering and the ABI edit are described as *obligations handed to the slices*, never performed here.
- **A record measures; it does not repeat.** Where a record states a number about the tree, that number is measured by the task that writes it, against the shipped tree, and cited. Where it repeats a number from elsewhere, it carries the qualifier that makes the number true (AGENTS.md, "Keep a count next to the qualifier that makes it true").
- **The design document is the source of text.** Each record below is the durable form of a `milestone-4-design.md` §4 subsection. Where this plan and the design differ, re-read the design and reconcile before writing; do not silently prefer one. Where the design is *wrong*, stop and say so rather than encoding the error in a record.
- **Do NOT amend decision 0009.** Record 0019 *extends* the fingerprint's coverage rather than falsifying it, and 0019's own Consequences state the extension. An amendment on 0009 saying "the encoding grew a field" duplicates a statement that already has a home and sends a future reader hunting in the wrong file.
- Conventional Commits. One decision — plus the amendments it forces — per commit.
- `.superpowers/sdd/` is git-ignored; nothing there is committed. Every artifact this phase produces lives under `docs/`.

## File Structure

**Created** — five records, one per §4 resolution, each self-contained and readable without the design document open:

| File | Responsibility | Source |
| --- | --- | --- |
| `.decisions/0018-unversioned-generated-abi-constructor.md` | The runtime↔generated seam: one unversioned constructor, version checked first, `/v1` and `/v2` as tombstones | design §4.1 |
| `.decisions/0019-encoding-format-2-pre-provisioned.md` | The canonical encoding: format 1→2, and the three slots reserved empty in ①a | design §4.2 |
| `.decisions/0020-field-shape-is-a-constructor-contract.md` | Where field validation lives, and the `error`-slot `#f` rule | design §4.3 |
| `.decisions/0021-eof-classification-multi-successor.md` | The EOF walk's generalization and its shape | design §4.4 |
| `.decisions/0022-structured-parser-error-record.md` | The `parser-error` record, its accessors, and how position kind reaches it | design §4.5 |

**Modified:**

| File | Change | Task |
| --- | --- | --- |
| `.decisions/0012-generated-abi-v2-finish.md` | Dated amendment note — a record, annotated, never rewritten | 1 |
| `.decisions/0010-direct-executor-abi.md` | Dated amendment note. Item 4 carries the *general* extend-by-`/vN` rule 0018 replaces, and it is what a reader looking for "how do we change the ABI" reaches first. Found by a vocabulary sweep, not by design §4.1's original text | 1 |
| `.plans/byte-machine-implementation-plan.md` | §9.5:442's reserved-binding sentence corrected in place — a normative instruction, stale in two halves. **§9.5:444 is deliberately not touched**: a version-number bump is what it requires | 1 |
| `.plans/milestone-4-design.md` | §4's Gate-0-discharged mapping; §10's first bullet gains the merge resolutions | 6 |

**Deliberately untouched.** `.decisions/0009-content-and-ir-fingerprints.md` (see Global Constraints), every `.sls` and `.sps`, every CMake file, `README.org` and `CHANGELOG.md` — the milestone's status surfaces move when the milestone *closes*, not when Gate 0 discharges. Task 1's vocabulary sweep reads those two files but changes neither.

---

> **The record bodies embedded below are the drafts as dispatched, not the
> records as shipped.** Every one of Tasks 1–5 went through a review that
> corrected its record in the tree — in three cases a *semantic*
> correction, not a wording one. `.decisions/0018`–`0022` are
> authoritative; these blocks are the work orders they were built from,
> kept because the record of what was asked is not the record of what
> shipped (AGENTS.md, "Correct a stale instruction in place; annotate a
> stale record"). A re-run must reconcile against the shipped records
> rather than transcribing these verbatim. Three examples from that
> review, not an inventory of every correction it made: Task 5's body still
> initializes the position-kind loop variable to `byte` where decision 0022 now
> initializes it to `boundary` unconditionally, in both a feed call and a finish
> call, with no `finish?` key; Task 5's body still calls `0a267de` `HEAD`; and
> Task 5's position table still carries an over-wide row.

## Task 1: Decision 0018 — One unversioned generated-ABI constructor, with the version check first

**Files:**
- Create: `.decisions/0018-unversioned-generated-abi-constructor.md`
- Modify: `.decisions/0012-generated-abi-v2-finish.md` (append one dated note)
- Modify: `.decisions/0010-direct-executor-abi.md` (append one dated note)
- Modify: `.plans/byte-machine-implementation-plan.md:442` (in-place correction)
- Test: none. Gate 0 is documentation; its verification is the `rg` checks in each task's penultimate step.

**Interfaces:**
- Consumes: nothing — this is the first record.
- Produces: the unversioned `byte-machine-make-compiled-machine` contract, `current-abi-version` 3, the tombstone rule for `/v1` and `/v2`, and the **quoted-vector payload shape whose member 0 is the field initials**. Record 0019 reserves that member; Slice ①a task 3 implements it.

- [ ] **Step 1: Confirm the number is free and re-read the source section**

Run:
```bash
ls .decisions/
rg -n "^### 4.1 " .plans/milestone-4-design.md
```
Expected: no `0018-*` file exists yet, and the `rg` prints exactly one line — design §4.1, this record's source. Read that subsection in full before writing. If `0018` is taken because a record landed from another branch, use the next free number and carry it through every cross-reference in this plan.

- [ ] **Step 2: Write the record**

Create `.decisions/0018-unversioned-generated-abi-constructor.md`. The
shipped record in the tree is authoritative per the note above; reconcile
against it rather than transcribing the draft block below verbatim.

````markdown
# 0018: One unversioned generated-ABI constructor, with the version check first

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.1)

## Context

Decided against the shipped tree at commit `a942327`, where Milestones 0-3 are
closed. The only later commit, `0a267de`, adds this milestone's design document
and touches no source; every `file:line` below was re-read at that tree.

Decision 0012 item 1 is the precedent this record breaks: a change to the
runtime↔generated seam ships as a new `byte-machine-make-compiled-machine/vN`
plus a bump of `current-abi-version`, itself following decision 0010 item 4's
"extends by a `/v2` constructor rather than an arity break". Milestone 4 moves
that seam again — the ABI payload must carry field initials — so the precedent
produces a `/v3`. The measurements below say that family has stopped paying
for itself.

**`/v1` refuses the version it is named for.** Its guard reads

    (unless (and (integer? abi-version) (= abi-version current-abi-version))

(`runtime.sls:51`), and `current-abi-version` is 2 (`runtime.sls:49`). A stale
generated file declaring ABI 1 — the only shape a `/v1` name describes — is
therefore rejected *by* `/v1`. It is already a tombstone, not a compatibility
path; the whole of what decision 0012 item 1 kept it for is that the rejection
is a clean assertion rather than an unbound-identifier import failure.

**The two guards disagree about where the number comes from.** `/v2` tests a
literal instead: `(unless (and (integer? abi-version) (= abi-version 2))`
(`runtime.sls:66`). They agree today only because the constant is 2, and they
fail in opposite directions the moment it moves. `/v2` goes on accepting 2 — a
hole that admits exactly the stale files decision 0012 item 1 added it to
refuse, and one that fails late: such an object loads, `exec` has the same
arity, nothing raises. `/v1` inverts instead, accepting only the new live
number and nothing else, so the one name whose contract is "the old shape" would
admit the newest one and hand a `/v2`-shaped `exec` to the four-argument `feed`
path.

**`/v1` has two call sites in the whole tree, both in one test program.**
`runtime-tests.sps:195` builds the stub machine for the `/v1` harness group, and
`runtime-tests.sps:245` is the refusal case. The first has to declare `2` to get
past the guard, and the comment above it says so
(`runtime-tests.sps:179-184`: "It declares abi 2 -- the current ABI version --
because /v1's guard checks (= abi current-abi-version)"). Nothing in `src/`
calls it, and none of the three goldens do: `render-machine` emits
`(byte-machine-make-compiled-machine/v2 2 …` (`compile.sls:164`).

**The `'v1` arm of `make-parser` is dead in production.** The variant `cond` at
`runtime.sls:112-123` reaches its `else` — the `'v1` arm at `:120-123` — only
for a compiled machine built by the `/v1` constructor (`runtime.sls:56`), which
is reachable only past the guard above. The emitter has emitted `/v2` since
Milestone 2, and a file emitted before that declares 1 and is refused, so no
generated library can reach the arm. Its only witness is the hand-built stub.

**The version *check* is nonetheless load-bearing here specifically.** Chez
prefers a compiled object over source and staleness is transitive across
imports; without the object-guard pair "a stale compiled object is silently
preferred over the source a 'source' lane claims to run"
(`milestone-0-slice-2-implementation-plan.md:590`). Every differential program
emits a library, `(load genfile)`s it and `eval`s the binding against the
*resident* runtime instance (`differential-http-version-tests.sps:48-53`), so a
stale generated object meeting a newer runtime is reachable inside this
repository's own build, not only across releases. What that argument justifies
is a check, not a name.

**Unversioned names are already the norm on this surface.**
`reserved-member-2` (`compile.sls:44-52`), the hand-maintained mirror of the
runtime's exports asserted set-equal to `environment-symbols` by
`reserved-drift-tests.sps:32-40`, carries twenty symbols, seventeen of which
have no version suffix. Nothing in the mirror or its drift guard depends on a
reserved name being versioned.

## Decision

1. **One unversioned `byte-machine-make-compiled-machine`, whose first action is
   the `(= abi-version current-abi-version)` check.** The check precedes every
   other guard and every field read, so a version mismatch is reported before
   any part of the payload is interpreted — which is what makes the payload safe
   to grow. The `/vN` family stops growing here: Milestones 5 and 6 plausibly
   move this seam again, and each `/vN` costs a dead-in-production variant arm,
   a permanent export, a `reserved-member-2` entry and an accessor pair.

2. **The growable payload is one quoted vector, not a rest-arg.** A rest-arg
   would let the payload grow *without* a version bump, and the version check is
   the only thing standing between a stale object and silent wrong answers; the
   vector keeps growth and the check coupled. It renders as `(quote #())` today,
   introducing no new callable identifier into the emitted body — the reason the
   shipped arms say `(quote error)` rather than calling anything
   (`generated-one-byte.golden.sls:17`). Member 0 is the field initials, empty
   until Slice ①b. This is §19.1:996's "immutable field/callback/debug
   metadata", carried positionally.

3. **`current-abi-version` goes from 2 to 3 (`runtime.sls:49`), and the
   emitter's literal moves in the same commit.** The number is duplicated by
   construction: `compile.sls` does not import the runtime
   (`compile.sls:14-17`), so the emitted `…/v2 2` literal (`compile.sls:164`)
   and `current-abi-version` are two independent constants with no static guard
   between them. Nothing but the differential lanes catches a disagreement, so
   they move together or not at all.

4. **`/v1` and `/v2` stay exported and are rewritten to refuse every version —
   in text distinct from each other and from the live guard.** Refusing *every*
   version, rather than the one they are named for, is what the measurements
   above require: a tombstone that still accepts a number is a hole. The textual
   distinctness is a hard constraint, not style. All mutations run at the
   default `SITES`, which "defaults to 1 and is asserted exactly"
   (`MutationRunner.cmake:58-59`) and fails loudly with "pattern occurs N times
   … expected N" (`MutationRunner.cmake:342-345`); AGENTS.md:147 records that
   `SITES` fails in *both* directions, so new code duplicating a pinned line
   breaks the suite at declaration. The `/v1` guard is pinned verbatim —
   `FIND [[(unless (and (integer? abi-version) (= abi-version
   current-abi-version))]]` at `SchemeMutationSuite.cmake:2544`, under LABEL
   "runtime: a mismatched generated-runtime ABI version is accepted" — and the
   `/v2` guard at `:2725` under "runtime: a mismatched /v2 ABI version is
   accepted". The suite already records distinctness as the reason those two
   differ (`SchemeMutationSuite.cmake:2719-2720`). Writing the live guard as a
   copy of the `/v1` text takes that `FIND` from one site to two, and the third
   guard would make it three.

5. **`reserved-member-2` gains the unversioned name and keeps both tombstones,
   in the same commit as the export change.** The mirror is hand-maintained
   (`compile.sls:44-52`) and `reserved-drift-tests.sps:32-40` asserts it equal
   to the runtime's live `environment-symbols`, so an export change that skips
   the mirror reddens the drift lanes rather than degrading quietly. That is
   decision 0012 item 4's rule, applied unchanged.

## Consequences

- **This amends decision 0012 item 1.** Its constant-bump half survives intact;
  its `/vN`-name half does not. Per AGENTS.md, 0012 gets a dated amendment note
  rather than a rewrite — the tree it was decided against is its evidence.
- **Parent §9.5:442 gains a Milestone 4 parenthetical**, on the precedent of the
  Milestone 2 parenthetical already in that line. §9.5:444 is *not* amended: its
  three requirements for a pre-1.0 ABI change are "a generated-ABI version bump,
  deterministic regeneration, and a changelog entry", and the version **number**
  bump is the requirement — it says nothing about a versioned binding name.
  Deterministic regeneration and the CHANGELOG entry bind the implementing slice
  exactly as written.
- **Decision 0010 item 4's purpose is kept and its mechanism replaced.** The
  seam still extends without an arity break; it now extends through the payload
  vector under one name instead of through a new versioned constructor. Item 4's
  other clause — the named `feed-outcome` record — is untouched.
- **The three goldens move**, each on the constructor line that embeds the name,
  the ABI literal and the IR fingerprint:
  `test/fixtures/generated-one-byte.golden.sls:20`,
  `test/fixtures/generated-pause.golden.sls:33`, and
  `test/fixtures/generated-http-version.golden.sls:85`.
- **The runtime's `'v1` executor path becomes unconstructable**, and its
  disposition is owed by the slice that lands this, not by this record. Once
  `/v1` refuses every version, nothing can build a `'v1`-variant compiled
  machine, so `make-parser`'s `'v1` arm (`runtime.sls:120-123`),
  `parser-feed!`'s `else` (`runtime.sls:157`), `parser-feed-v1!`
  (`runtime.sls:205`) and `parser-finish!`'s raising `v1` arm
  (`runtime.sls:253`) lose their only witness — with them three shipped
  mutations, named by LABEL because the lines are stale on arrival: "runtime: a
  v1 machine is driven down the op path", "runtime: a mismatched
  generated-runtime ABI version is accepted", and "runtime: the v1 result status
  is hard-wired to stopped". An arm no public API can reach cannot be witnessed
  and would ship dead owing an `EXPECT_SURVIVES`.
- **This is distinct from the benchmark-gated `feed-outcome` `/v2`** reserved by
  decision 0010's Consequences and its Slice-B amendment, which stays gated on
  §23 evidence. That `/v2` is a change to the outcome *record*; this record
  touches only the compiled-machine constructor, and `feed-outcome` keeps its
  five slots and its `/v1` constructor.
- **Deliberately not touched.** Decision 0010 item 5's coded
  `generated-runtime-abi-mismatch` condition stays deferred: the collapsed
  constructor still raises `assertion-violation`. The canonical *encoding*
  format version is a different seam with a different lineage and has its own
  Gate 0 record. §20:1042's embedded generator version is measured unmet and
  stays unmet (`rg` for a generator version across `src/` and `test/common/`
  returns nothing) — the payload vector is its eventual home, but
  half-embedding it is worse than none.
````

- [ ] **Step 3: Append the dated note to decision 0012 — a record, annotated**

Decision 0012 is a *record*: its Context is the evidence of the tree it was decided against, so nothing above is rewritten — not item 1, not item 4, not the Consequences bullets, and not the title, which is cited by `.plans/byte-machine-implementation-plan.md:442`. Confirm the file's current tail first:

```bash
tail -5 .decisions/0012-generated-abi-v2-finish.md
```
Expected: the Consequences bullet ending `decision 0013 only unblocks\nit).`

Append one blank line, then exactly:

````markdown
## 2026-08-31 (Milestone 4) — the versioned name is retired; the check is not

Milestone 4 Gate 0 (decision 0018, milestone-4-design.md §4.1) replaces the
`byte-machine-make-compiled-machine/vN` family with **one unversioned
`byte-machine-make-compiled-machine`** whose first action is the
`(= abi-version current-abi-version)` check, and whose payload is carried as a
quoted vector so it can grow without an arity break. `current-abi-version` goes
2 → 3. Slice ①a lands it. This annotates item 1 and the first Consequences
bullet; the tree those were decided against is their evidence, so they are not
rewritten.

**Item 1's purpose survives; only its mechanism goes.** The reason given here
for keeping the `/v1` export — that a stale generated file embedding an old
version must "fail the ABI-version *check* cleanly (an assertion), not fail at
import with an unbound identifier" — is carried forward unchanged and is the
whole warrant for the new arrangement. `/v1` and `/v2` both remain exported, as
tombstones, for exactly that. What changes is how they discharge it: each is
rewritten to refuse *every* version unconditionally, rather than to reject as a
side effect of a version comparison.

**Measured, against `a942327`.** `/v1` (runtime.sls:50-56) compares against
`current-abi-version`, which is 2 (runtime.sls:49), so it already rejects the
version 1 it is named for: it is not a compatibility path and never was. `/v2`
(runtime.sls:65-71) does **not** compare against `current-abi-version` — it
tests the literal `2` at runtime.sls:66 — so bumping the constant to 3 does not
retire it; without the rewrite it would keep accepting the version it names.
The two old constructors therefore do not inherit their refusal from the bump
and must each be given it explicitly.

**False from Slice ①a onward:**

- item 1's "The emitter emits `/v2`", and the first Consequences bullet's
  "constructs the binding via `byte-machine-make-compiled-machine/v2`". The
  emitter emits the unversioned name; the pre-slice `/v2` literal is at
  `compile.sls:164`.
- item 1's "bump `current-abi-version` to 2" as a statement of the current
  value. 2 is what Milestone 2 set; the constant is 3 from Slice ①a.

**Untouched.** Items 2 and 3 stand: one unified `exec` closure carrying a
`finish?` flag, one distinct arm per terminal kind, and the reused
`feed-outcome` record with new status symbols. (Slice ①a widens `exec`'s
emitted parameter list from six to seven under a separate Gate 0 record,
milestone-4-design.md §4.2; that is an arity change to item 2's closure, not a
change to its shape.) Item 4's mirror obligation stands and is what governs:
`reserved-member-2` keeps `/v1`, `/v2` and the `/v1` feed-outcome constructor,
gains the unversioned name, and is updated in the same commit as the exports it
mirrors. `byte-machine-make-feed-outcome/v1` keeps its versioned name; 0018
reaches only the compiled-machine family. The general rule this record invoked —
decision 0010 item 4's seam that "extends by a `/v2` constructor rather than an
arity break" — is amended by 0018 as well.
````

The placement precedent is `.decisions/0010-direct-executor-abi.md`, which already carries dated `## <date> (<phase>) — <what changed>` sections appended below its Consequences.

- [ ] **Step 4: Append the dated note to decision 0010 — the record that carries the general rule**

This is the higher-value of the two. Decision 0010 item 4 is where the *general* "extends by a `/v2` constructor rather than an arity break" rule lives, and it is what a reader looking for "how do we change the ABI" reaches first. Confirm what is there:

```bash
sed -n '28,34p;44,48p' .decisions/0010-direct-executor-abi.md
rg -n "^## 20" .decisions/0010-direct-executor-abi.md
```
Expected: item 4's "extends by a `/v2` constructor rather than an arity break"; the Consequences bullet reserving a benchmark-gated `feed-outcome` `/v2`; and the existing dated sections, below which this one goes.

Append at the end of the file, after one blank line:

````markdown
## 2026-08-31 (Milestone 4) — the extension mechanism changes; the version tag stays

Milestone 4 Gate 0 (decision 0018, milestone-4-design.md §4.1) replaces item 4's
extension *mechanism*. The seam no longer "extends by a `/v2` constructor": it
extends by a growable quoted-vector payload behind **one** unversioned
`byte-machine-make-compiled-machine` whose first action is the
`(= abi-version current-abi-version)` check. Item 4's purpose is unchanged — a
self-documenting seam that grows without an arity break — and the version tag
this record reserved "for exactly that" is precisely what makes a growable
payload safe, so it stays load-bearing rather than being retired with the name.
`current-abi-version` goes 2 → 3. Slice ①a lands it.

**What this note does not reach.** The Consequences bullet reserving a
`feed-outcome` `/v2` under benchmark evidence (parent §23) is a *different
family*. `byte-machine-make-feed-outcome/v1` keeps its versioned name, that
reservation stays open and still gated on §23 evidence, and `bench/` still holds
only `.gitkeep`. A reader who takes 0018's rename as having retired it has read
one shared suffix as one decision.

Item 5's deferral of a coded `generated-runtime-abi-mismatch` condition is also
untouched: 0018 changes which procedure raises the mismatch, not the condition
kind (decision 0013 item 3).
````

- [ ] **Step 5: Correct §9.5:442 in place — a normative instruction**

Unlike Steps 3 and 4, this is an *instruction*: a normative spec sentence naming the reserved binding. It is corrected in place and git holds what it said. Confirm the current wording:

```bash
sed -n '442p' .plans/byte-machine-implementation-plan.md
```
Expected: a single unwrapped line beginning `` `(byte-machine runtime)` exports the reserved generated-code ABI binding `byte-machine-make-compiled-machine/v1`. `` and containing the Milestone 2 parenthetical `the emitter emits /v2, the runtime keeps the /v1 export`.

It is stale in two halves: the reserved binding is no longer the versioned name, and "the emitter emits `/v2`" becomes false. Replace **line 442 in full** — the file is one paragraph per line, so the replacement stays unwrapped — with:

```
`(byte-machine runtime)` exports the reserved generated-code ABI binding `byte-machine-make-compiled-machine`. Emitted bodies call that binding and embed the required runtime ABI and IR/emitter versions. (Milestone 2 added `byte-machine-make-compiled-machine/v2` with the finish path — a unified `exec` carrying `finish?` — [decision 0012](../.decisions/0012-generated-abi-v2-finish.md). Milestone 4 retires the versioned *name*, not the version: one unversioned constructor checks `current-abi-version` — now 3 — before reading any payload, the payload is a growable quoted vector, and `/v1` and `/v2` stay exported as tombstones that refuse every version — [decision 0018](../.decisions/0018-unversioned-generated-abi-constructor.md).) This export exists so a generated library depends only on `(byte-machine runtime)`: the consumer imports the generated library, whose sole byte-machine import is the runtime ([decision 0008](../.decisions/0008-emitter-emits-importable-library.md)); it is not an API for handwritten grammar or application code. Loading or constructing against a mismatched runtime raises the portable ABI-mismatch condition.
```

Everything from `This export exists so a generated library` onward is unchanged; only the binding name and the parenthetical move.

**Do not touch §9.5:444.** Its three requirements — "a generated-ABI version bump, deterministic regeneration, and a changelog entry" — are *satisfied* by this milestone, not contradicted: `current-abi-version` goes 2 → 3, which is a version bump. The sentence never mandated a versioned constructor *name*. Correcting it would be editing a true instruction.

- [ ] **Step 6: Verify and self-review**

Run:
```bash
rg -n "^# 0018:|^Date:|^Status:|^Milestone:" .decisions/0018-unversioned-generated-abi-constructor.md
rg -c "2026-08-31" .decisions/0012-generated-abi-v2-finish.md .decisions/0010-direct-executor-abi.md
rg -n "make-compiled-machine/v1\`\. Emitted" .plans/byte-machine-implementation-plan.md
rg -n "generated-ABI version bump" .plans/byte-machine-implementation-plan.md
git diff --stat
```
Expected, in order: the four header lines with `Milestone: 4, Gate 0 (milestone-4-design.md §4.1)`; `1` for each of the two records; **nothing** from the third (the stale binding name is gone); §9.5:444 still present and unmodified; and a `git diff --stat` naming exactly four files, none of them a `.sls`, `.sps`, `.cmake` or `CMakeLists.txt`.

Then confirm no measured total moved and no forecast was written:
```bash
rg -n "EXPECTED_PASSES|EXPECTED_MUTATIONS|46 passes|236" .decisions/0018-unversioned-generated-abi-constructor.md
```
Expected: nothing, or only a measurement this record took itself and cited. Fix inline.

- [ ] **Step 7: Commit**

```bash
git add .decisions/0018-unversioned-generated-abi-constructor.md \
        .decisions/0012-generated-abi-v2-finish.md \
        .decisions/0010-direct-executor-abi.md \
        .plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0018 — one unversioned generated-ABI constructor

Amends 0012 item 1 and 0010 item 4 with dated notes, and corrects the
reserved-binding sentence at parent plan 9.5:442 in place.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

One commit, not four. A record that retires a mechanism while the parent plan still names it leaves the spec asserting something the decision has killed.

---

## Task 2: Decision 0019 — The normalized encoding gains format version 2, pre-provisioned

**Files:**
- Create: `.decisions/0019-encoding-format-2-pre-provisioned.md`
- Test: none. Gate 0 is documentation; its verification is the `rg` checks in each task's penultimate step.

**Interfaces:**
- Consumes: 0018's payload shape — this record reserves member 0 of it.
- Produces: encoding format 2, the three slots reserved empty in Slice ①a (the encoding's field table, the ABI payload's field-initials member, and emitted `exec`'s seventh parameter), the carriage of the error declaration's `reason`, and the measured re-baseline. Record 0022 consumes the `reason` carriage; Slices ①a, ①b, ② and ③ all consume the reservation.

- [ ] **Step 1: Confirm the number is free and re-read the source section**

Run:
```bash
ls .decisions/
rg -n "^### 4.2 " .plans/milestone-4-design.md
```
Expected: no `0019-*` file exists yet, and the `rg` prints exactly one line — design §4.2, this record's source. Read that subsection in full before writing. If `0019` is taken because a record landed from another branch, use the next free number and carry it through every cross-reference in this plan.

- [ ] **Step 2: Write the record**

Create `.decisions/0019-encoding-format-2-pre-provisioned.md`. The shipped
record in the tree is authoritative per the note above; reconcile against it
rather than transcribing the draft block below verbatim.

````markdown
# 0019: Normalized encoding format 2, with three slots reserved empty

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.2)

## Context

Measured against the shipped tree at commit `a942327`, the commit Milestone 3
closed at. The only later commit adds `.plans/milestone-4-design.md` and
touches no `src/`, so every line cited below is the line Slice ①a will open.

**What `encode-normal` encodes, and what it cannot see.** It takes two
parameters — `(define (encode-normal entry states)`, normal-ir.sls:251 — and has
exactly one caller, `(fnv1a-64 (encode-normal entry states))` at
normal-ir.sls:286. It never receives the machine. That is a *structural* claim,
not a policy one: field declarations, field initial values and the machine name
are invisible to the IR fingerprint by construction, not by omission.
milestone-3-design.md:1008-1009 relied on the same fact for the debug map. What
it does write is a version byte of 1 (:254), the entry id, the state count, and
then one tagged record per state — dispatch 0 (:262), stop 1 (:275), error 2
(:276), finish 3 (:277), pause 4 (:279).

**The error declaration's `reason` is discarded at normalization.** The helper
that resolves an error reference is `errcode` (normal-ir.sls:144-147); it walks
`machine-errors` for a matching `error-declaration-name` and returns
`error-declaration-code` and nothing else. Both encode arms that emit an error
therefore emit a code symbol only: the error arm at :276 and the dispatch
default-eof arm at :274. The accessor `error-declaration-reason` exists
(ir.sls:288), is not among `graph.sls`'s exports (graph.sls:12-25), and `rg`
finds no reader for it anywhere in `src/` or `test/`. §10.5:527 makes a "static
printable-ASCII reason" part of every error declaration, and §10.1:480 fixes its
repertoire. Today the value is validated at construction, stored, and dropped.

**The fingerprint is computed over the encoding, not over the emitted text.**
This is the distinction the whole record turns on. `normalize-machine` hashes
`(encode-normal entry states)` and stores the result in slot 3 of the
normal-machine vector (normal-ir.sls:286; accessor at :32). The emitter *reads*
that number — `(fp (normal-machine-fingerprint normal))`, compile.sls:149 — and
splices it into the rendered constructor call at compile.sls:164. Emitted text
is strictly downstream of the fingerprint and never upstream of it. So the two
changes have different blast radii: **an `encode-normal` change moves the
fingerprints and, through :164, the goldens; an emitted-template change moves
the goldens only.** Goldens are compared as raw bytes
(determinism-one-byte-tests.sps:41-42 and its two siblings), and
compile-tests.sps:165 additionally pins the whole constructor call as a
substring.

**The `exec` measurement.** The emitted signature is fixed at six parameters in
one template string — `"  (define (exec state offset bv start end finish?)\n"`,
compile.sls:156 — and a generated `exec` is called with six arguments at exactly
two sites, `runtime.sls:218` (feed, `#f`) and `runtime.sls:262` (finish, `#t`).
Those are the only two: `runtime.sls:206-208` is the `/v1` five-argument `feed`,
a different closure. All three committed goldens carry that six-parameter line
verbatim at line 4. A field-store parameter added in Slice ② would therefore
change the emitted text of *every* machine, including the zero-field ones, and
all three goldens would move in ② — falsifying the milestone's own oracle that
①b, ② and ③ move no existing golden (milestone-4-design.md §1's dependency-order
paragraph, and its appendix row for the three golden fixtures) one to two slices
after this record is made.

**The version byte has never distinguished anything.** It has read 1 through
every encoding change so far: Milestone 2 appended eof routing to the dispatch
record and added the `finish` and `pause` tags — decision 0011's Consequences,
which re-baselined the fingerprints without touching the byte — and Milestone 3
deliberately did not change the encoding at all (decision 0014's Consequences:
"every machine expressible before Milestone 3 encodes identically after it";
decision 0015 point 1: "the encoding-format version byte is unchanged", restated
in the code at compile.sls:104). One value has named at least three encodings.
Note also that no record owns that byte: normal-ir.sls:250 credits the layout to
"decision 0009 layout", but decision 0009 contains no occurrence of "layout",
"format", "version" or "encoding".

## Decision

1. **The canonical encoding's format version byte goes 1 → 2 in Slice ①a**, at
   `normal-ir.sls:254`, and this record is its owner from that commit forward.
   The bump is not what forces the re-baseline — encoding the `reason` does that
   — which is exactly why it is taken here: it is nearly free in ①a and free in
   no other slice. From ①a the byte names one encoding rather than three.

2. **The same bump introduces the error declaration's static `reason` into the
   encoding**, appended after the code at both sites that emit one: the error
   arm (`normal-ir.sls:276`) and the dispatch default-eof arm (`:274`). It must
   enter the *encoding*, not merely be read from the source machine. Decision
   0009 point 2 computes the IR fingerprint over the canonical normalized IR and
   §20:1043 makes it "embedded deterministic non-cryptographic IR fingerprint
   … of canonical normalized IR and emission options" — the object the
   determinism checks compare. Two machines differing only in a reason must
   therefore differ in fingerprint, or the fingerprint stops identifying what
   was emitted.

3. **The same bump reserves three slots, each written with an empty value and
   read by nothing.**
   (a) *The encoding's field table* — a `u16be` count of zero with no per-field
   records, in `encode-normal`. Filled in ①b.
   (b) *The ABI payload's field-initials member* — member 0 of the single quoted
   metadata vector the unversioned constructor takes (§4.1), rendering as
   `(quote #())`. Filled in ①b.
   (c) *Emitted `exec`'s seventh parameter* — the template at `compile.sls:156`
   goes from six parameters to seven, both call sites (`runtime.sls:218`,
   `:262`) pass an empty vector, and the new parameter's name joins
   `reserved-member-3` (`compile.sls:53`, today twelve symbols carrying the
   other six) in the same commit. Filled in ②.
   Slot (c) is the one a reader will miss, because it is not in the encoding at
   all; it is reserved here for the same reason and by the same argument.

4. **This is a format decision, not a transformation, so §17:966 does not reach
   it.** That line reads: "Normalization must not perform speculative
   performance transformations in v0.1. It should produce the simplest correct
   execution graph." A count of zero changes no lowering, allocates no state and
   yields no different execution graph; it is a byte in the serialization of a
   graph that is unchanged. The §17 responsibility the reservation serves is
   :962, "assign field, callback, and span slots" — this holds the slot's place
   one slice before the assignment exists.

5. **A later slice that finds an existing golden or an existing fingerprint
   moving has broken this reservation and must STOP, not re-baseline.** From
   ①a's merge, the three committed goldens under `test/fixtures/` are
   byte-identical for the rest of Milestone 4, and the four IR fingerprint
   values ①a measures are the values ①b, ② and ③ ship. A movement is evidence
   that a slot was added late, not evidence that a number needs updating; the
   repair is the slot, not the baseline. Re-baselining instead silently converts
   this record's guarantee into a second unbudgeted re-measurement, which is the
   outcome the whole ①a/①b split exists to avoid.

## Consequences

- **The re-baseline this concentrates in ①a, measured.** Four distinct IR
  fingerprint values are pinned at **nineteen sites across six files**, and none
  in `src/`: `4236938459847922092` (9 sites), `15725897457025557005` (5),
  `9098559711816935340` (3), `12299125921751534854` (2). By file — one per
  golden (`generated-one-byte.golden.sls:20`, `generated-pause.golden.sls:33`,
  `generated-http-version.golden.sls:85`), two in `compile-tests.sps` (`:165`,
  `:212`), three in `normal-ir-tests.sps` (`:73`, `:122`, `:147`), and eleven in
  `test/support/cmake/SchemeMutationSuite.cmake`. **Seven of those eleven are
  mutation pins carrying a measured `got` digest** — `:4773`, `:4780`, `:4787`,
  `:4889`, `:4907`, `:4958`, `:4980` — and `SchemeMutationSuite.cmake:843-852`
  states why they are different in kind: "an expected golden is RECOMPUTED by
  re-running the lane, but a 'got' digest can only be RE-MEASURED, by applying
  that one mutation to a staged copy and reading what it printed." Each must be
  re-measured by staging the mutation, never recomputed. The remaining four
  cmake sites are narrative (`:4942`, `:4943`, `:4951`, `:6548`), and Pass 49's
  narrative additionally records the mutant library's own byte count (`:6544`,
  `:6580`) alongside its digest — both measurements of a golden this slice
  moves. That doctrine block is itself pre-Milestone-3 and says "five" and
  "~15"; the measured counts today are seven and nineteen, so it is re-measured
  in the same slice rather than cited as current.

- **What it removes from ①b, ② and ③.** ①b fills a count that is already zero
  and a payload member that is already `(quote #())`, so a machine declaring no
  fields encodes *and renders* byte-identically. ② adds its field store to a
  parameter that already exists in the emitted text. ③ adds a node kind, which
  moves nothing existing because no shipped fixture uses one. Each of the three
  therefore gets "no existing golden and no existing fingerprint moved" as a
  gate assertable by `git diff` against ①a's merge — a falsifiable oracle they
  would otherwise not have, and the only thing that pays back ①a's bill.

- **Decision 0009 is extended by the field table, not falsified, and takes no
  dated amendment.** 0009 fixes the IR fingerprint's *input* ("computed over the
  canonical normalized IR"), its *embedding*, and its *role* in the D6
  determinism checks. It fixes no layout, no member list and no version — the
  words "layout", "format", "version" and "encoding" do not occur in its text.
  Adding a field table and a reason changes what the canonical normalized IR
  *contains*, which is precisely the freedom 0009 left open, so no sentence of
  it becomes false and it gets no amendment note; the tree it was decided
  against remains its evidence. The question arises only because
  `normal-ir.sls:250` credits the byte layout to "decision 0009 layout", an
  attribution 0009 does not support — that comment is corrected in ①a to point
  here. Contrast decision 0012 item 1, which names the `/vN` binding in its own
  decision text and therefore *does* take a dated amendment under §4.1: a record
  needs amending when its own words go false, not when a later record builds on
  it.

- **The format version byte acquires its first mutation pin here, and the naive
  anchor will fail.** `rg` finds no pin on `normal-ir.sls:254`; the only
  `put-u8 p 1` FIND in the suite is the default-eof arm's longer literal at
  `:4887`. The literal `(put-u8 p 1)` occurs three times in `encode-normal`
  (`:254`, `:274`, `:275`), and after the bump `(put-u8 p 2)` occurs **twice**
  (`:254` and the error arm at `:276`) — so the collision moves rather than
  disappears, and `SITES` is asserted exactly (`MutationRunner.cmake:59`). Any
  pin on the new byte must anchor on surrounding text.

- **What this deliberately does not touch.** No verifier pass: the encoding
  format version is *not* §16.2:884's "unsupported IR versions", which is
  `machine-ir-version` (ir.sls:351, stamped with no accessor) against a
  `pass-schema` that is still a bare `machine?` tag test (verify.sls:107-108);
  closing that is Slice ①b's. No `graph.sls` or `ir.sls` change: `make-machine`
  has taken a `fields` argument (ir.sls:352) and `machine-fields` has been
  exported (ir.sls:370) since M1 with no reader anywhere in `src/` or `test/`,
  and this reservation mirrors that shipped precedent one layer down. And this
  record settles only that the `reason` is *encoded* — its portability check in
  `pass-names-valid` and the writer's escaping of `"`, `\` and LF are Slice ①a's
  own tasks under §10.1:480 and §20:1039, not consequences of the format.
````

- [ ] **Step 3: Verify and self-review**

Run:
```bash
rg -n "^# 0019:|^Date:|^Status:|^Milestone:" .decisions/0019-encoding-format-2-pre-provisioned.md
git diff --stat
git status --short
```
Expected: the four header lines, with `Milestone: 4, Gate 0 (milestone-4-design.md §4.2)`; a `git diff --stat` that is empty (this task only *adds* a file); and `git status --short` showing exactly one untracked file, `.decisions/0019-encoding-format-2-pre-provisioned.md`. No `.sls`, `.sps`, `.cmake` or `CMakeLists.txt` may appear.

Then check the record against its source and against decision 0009:
```bash
rg -n "§4.2" .plans/milestone-4-design.md
rg -c "2026-08-31" .decisions/0009-content-and-ir-fingerprints.md || echo 0
```
Expected: the design subsection this record is the durable form of; and `0` — decision 0009 takes **no** amendment in this phase (Global Constraints). Note `rg -c` prints nothing and exits 1 on zero matches, hence the `|| echo 0`. Re-read the design subsection against the record and reconcile any divergence before committing; if the design is wrong, stop and say so rather than encoding the error.

- [ ] **Step 4: Commit**

```bash
git add .decisions/0019-encoding-format-2-pre-provisioned.md
git commit -m "docs: decision 0019 — the normalized encoding gains format version 2, pre-provisioned

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Decision 0020 — Field shape is a constructor contract; operand and cross-reference checks are the verifier's

**Files:**
- Create: `.decisions/0020-field-shape-is-a-constructor-contract.md`
- Test: none. Gate 0 is documentation; its verification is the `rg` checks in each task's penultimate step.

**Interfaces:**
- Consumes: nothing.
- Produces: the constructor/verifier split for field validation, the disposition of each item §16.2's field bullet names, and the `error`-slot rule (`#f` exactly when the operation cannot fail, with all seven operations classified). Consumed by Slices ①b, ② and ③.

- [ ] **Step 1: Confirm the number is free and re-read the source section**

Run:
```bash
ls .decisions/
rg -n "^### 4.3 " .plans/milestone-4-design.md
```
Expected: no `0020-*` file exists yet, and the `rg` prints exactly one line — design §4.3, this record's source. Read that subsection in full before writing. If `0020` is taken because a record landed from another branch, use the next free number and carry it through every cross-reference in this plan.

- [ ] **Step 2: Write the record**

Create `.decisions/0020-field-shape-is-a-constructor-contract.md`. The
shipped record in the tree is authoritative per the note above; reconcile
against it rather than transcribing the draft block below verbatim.

````markdown
# 0020: Field shape is a constructor contract; operands and cross-references are the verifier's

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.3)

## Context

Measured against the tree at `a942327`, the commit Milestone 3 closed on. The
Milestone 4 design (`0a267de`) adds no code, so every line cited below is the
shipped one.

Milestone 4 adds one declaration constructor and three node constructors —
`make-uint-field` (§9.1:283), `make-field-action-node` (§9.1:301),
`make-integer-accumulate-node` (§9.1:302-304) and `make-field-branch-node`
(§9.1:305-306) — and with them the first construction-time values the parent
plan gives closed domains: widths (§10.2:489), initial values (§10.2:490),
seven operations (§9.1:326-334), seven predicates (§9.1:336-346), and `base`.
Which mechanism rejects each is a real choice, because the two are observably
different. `byte-machine-contract-violation` **`raise`s**
(`conditions.sls:19-20`), so a constructor rejection is non-continuable, stops
at the offending call, and builds nothing; a diagnostic is a value
`verify-machine` accumulates into a list, and no compilation or emission
proceeds while one exists (§16.1:878).

**Decision 0017's reasoning does not transfer, and the difference is one line
of §16.2.** 0017's Context turns on an absence: "§16.2's list of required
checks — an itemized enumeration with no open-ended qualifier — has **no**
invalid-matcher entry at all" (0017:17-19), so a matcher-validity *diagnostic*
would have been an addition to that list. §16.2:889 is the opposite case: it
names the field items outright — "invalid field widths, initial values,
constants, masks, and operations". Closing them at the constructor therefore
*removes* an entry §16.2 lists, where 0017 merely declined to add one. One item
is the exception that proves the reading: **predicates** appear in no §16.2
bullet at all, so for them 0017's argument applies unchanged — and lands in the
same place this record puts the other four.

**The precedent that does transfer is `make-edge`.** It `memq`-checks `mode`
against `(advance reexecute)` at construction (`ir.sls:200-204`, the check at
`:202-203`) even though §16.2:896 lists "invalid transition advancement modes"
among the verifier's required checks — and, measured, `verify.sls` carries no
arm for it: its only `edge-mode` reads are inside `pass-zero-progress`
(`verify.sls:266`, `:268`, `:320`), where they classify progress rather than
validate a mode, and none of its fourteen diagnostic codes names one. §16.2:896
is discharged wholly at the constructor today. Two other shipped constructors
supply the shapes M4 reuses: `make-byte-dispatch-node`'s `(or (symbol?
eof-target) (eq? eof-target #f))` (`ir.sls:229-231`) is the target-or-`#f`
slot, and 0017 point 1's range checks are local shape.

A reader who finds §16.2:889 and `make-edge` and no record will
reverse-engineer a rule from them, and the two point opposite ways
(`.decisions/README.md:8-10`).

This is **one** record and not two. The `error`-slot rule below is the single
constructor check whose soundness is *supplied by the verifier* — `store` and
`set-mask` cannot fail only because pass 6a range-checks their operand against
the referenced field's width — so its enforcement is the constructor/verifier
split, and splitting the record would put the two halves of one argument in two
files.

## Decision

1. **The constructor checks closed-set membership and the local shape of the
   one value being built, and nothing else.** `width` in `{8, 16, 32, 64}`;
   `initial` an exact integer in `[0, 2^width - 1]`; `operation` in the closed
   seven of §9.1:326-334; `predicate` in the closed seven of §9.1:336-346;
   `base` in `{10, 16}`; `arguments` a proper list; `name`, `field`, `next`,
   `true-target`, `false-target`, `digit-target` and `overflow-error` symbols;
   `eof-target` a symbol or `#f` (§9.1:318); `nondigit-edge` an `edge?`. Each is
   a `byte-machine-contract-violation`, on the `make-edge` precedent. `initial`
   is in this list and the field-action `constant` is not, for one reason worth
   stating because the predicate is identical: `make-uint-field` receives the
   width in its own argument list (§9.1:283), so the bound is local; a
   field-action node names its field by symbol, so the bound is somewhere else.

2. **`arguments` is checked as a proper list and no further; the schema is not
   read at construction.** This single line fixes the whole boundary for the
   `arguments` slot. Everything that requires the §9.1:326-346 schema —
   which position holds the field, how many positions there are, what each one
   means — is the verifier's, because §9.1:348 assigns exact arity to it and
   nothing can be read out of `arguments` before arity is known. The
   consequence that will look wrong to a reader of 0017: **`low <= high` for
   the `range` predicate is the verifier's**, though 0017 point 1 rejects `low >
   high` in `make-byte-range-matcher`. There, `low` and `high` are named
   parameters; here they are the second and third elements of a list whose
   length the constructor is not entitled to assume.

3. **The verifier's half is a new pass — pass 6a, §16.3:924's "Field and
   callback type checking" — and it is everything relational:** exact arity
   against the operation or predicate, the `field` argument naming a declared
   field, `constant` and `mask` within the *referenced* field's declared width,
   `low <= high` for `range`, duplicate field names, and portable field names
   (§10.1:480). "6a" is this design's label; the source name follows the
   unnumbered-pass convention `verify.sls:190-200` records.

4. **§16.2:889's five items split three and two.** Widths, initial values and
   **operations** are discharged at construction — a raised contract violation,
   never a diagnostic, carrying no diagnostic code at all. **Constants** and
   **masks** stay diagnostics, in pass 6a, under `invalid-field-operand`. That
   is the exact split, and it is not a departure from §9.1:322, whose sentence
   states its own criterion: "Constructors validate only local shape and return
   immutable-by-API descriptors ... Cross-reference, graph, and semantic checks
   belong to `verify-machine` so callers can accumulate structured
   diagnostics." Accumulation is what cross-reference checks are *for*, and
   every item on the constructor side is evaluable from the one value being
   built while every item on the verifier side needs a second object — the
   field declaration — to evaluate at all. What callers lose is the ability to
   collect a width or an operation error beside other diagnostics; they get a
   raise at the offending constructor instead. That is 0017's Consequences trade
   taken again, for consistency, and not re-litigated per constructor.

5. **The `error` slot of `make-field-action-node` names a target node, and is
   `#f` exactly when the operation cannot fail.** Not "may be" — exactly. The
   partition is a property of the operation symbol alone, so it is a second
   closed-set lookup on a value item 1 already closes, and it stays inside "the
   local shape of the one value being built". Reasoning over all seven
   operations against their §9.1:326-334 schemas, a field of width `w`, its
   maximum `M = 2^w - 1`, and the invariant that a stored value is in `[0, M]`:
   - `store (field constant)` — writes `constant`, which pass 6a has already
     bounded by `M`. **Cannot fail.**
   - `clear (field)` — writes `0`, in range at every width. **Cannot fail.**
   - `set-mask (field mask)` — `v | mask` with both operands in `[0, M]`; an
     OR of two `w`-bit values sets no bit above `w-1`, so the result is in
     `[0, M]`. **Cannot fail.**
   - `clear-mask (field mask)` — clears bits, so the result is `<= v <= M` and
     `>= 0`. **Cannot fail**, and unlike `set-mask` it does not even need the
     mask bound.
   - `increment (field)` — `v + 1` exceeds `M` at `v = M`. **Can fail.**
   - `decrement (field)` — `v - 1` is below `0` at `v = 0`. **Can fail.**
   - `add (field constant)` — `v + constant` exceeds `M` for in-range operands.
     **Can fail.**
   Four safe, three failing, which is exactly §10.6:560's "Underflow, overflow,
   or an out-of-range result takes an explicit error edge" once the third
   disjunct is discharged by pass 6a. **`#f` is required and not merely
   permitted** because the alternative writes unreachable nodes into user
   grammars: an `error` target on a safe operation is a node no execution can
   enter, and §16.4:947 makes unreachable nodes errors in v0.1, so the author
   would be obliged to author a node the verifier is then obliged to reject.
   The rule completes a three-way pattern across the three new constructors,
   and nothing else is left open in it: integer accumulate's `overflow-error`
   is mandatory, because §15:864-868's multiply-add can always fail; field
   action's `error` is conditional, by this rule; field branch has no error
   slot at all (§9.1:305-306), because a predicate over an in-range field and a
   bounded operand is total and §10.6:582 already demands "an explicit target
   for every possible result".

6. **No unreachable duplicate arm is admissible anywhere in Milestone 4, and
   the `base` arm of milestone-4-design.md §8 task 3 is dropped.** Where the
   constructor closes a set, the pass records the assignment in place — the way
   `pass-overlap` records its permanent non-extension (`verify.sls:178-184`) —
   and carries no arm and no code. The reconciling rule is not "walk cost" and
   not "new pass versus new clause": **a duplicate guard is admissible exactly
   when a caller can still reach it through the public API.** The tree states
   that criterion itself, at the very guards that §8 task 3 cites as its
   precedent: `normal-ir.sls:99-102` keeps the trie's `assertion-violation`s
   that `pass-sequence-ambiguity` has made redundant "because normalize-machine
   is a public entry point that does not itself verify: a caller who skips
   verification must fail loudly here". Those guards are reachable, and they
   raise rather than diagnose. A pass-6a arm for `base` is neither:
   `verify-machine` is handed a `machine`, a machine holding a `base` outside
   `{10, 16}` cannot be constructed, and the design's §4.6 gives `base` no
   diagnostic code to report. So it would ship dead, split one decision's
   mutation witness across two sites that `SITES` asserts exactly and that fail
   in both directions (`AGENTS.md:147`; `MutationRunner.cmake:59-62`), and owe
   an `EXPECT_SURVIVES` for a check the tree already has a reachable rejection
   for. The one arm that *is* admissible under the same rule is not a duplicate:
   `pass-schema`'s §16.2:884 IR-version check is the sole rejection site for
   that requirement — `make-machine` stamps `machine-ir-version` as a constant
   (`ir.sls:351`, into slot 1 at `:365`) and `machine-tag` is unforgeable
   (`ir.sls:41-43`) — so it closes a listed-and-unimplemented gap rather than
   re-closing one, and it pays for its unreachability with the measured
   `EXPECT_SURVIVES` Slice ①b declares.

## Consequences

- **Slice ①b's constructor work is fully specified and its verifier work is
  fully bounded.** `make-uint-field` validates width, name, and `initial`
  against the width, and nothing else; the field pass carries duplicate and
  portable field names and must **not** re-check widths or initials — a machine
  whose field failed construction never exists, so the arm would be item 6's
  dead code. Exit criterion §25:1568's declaration-time share is therefore
  discharged by a **raised condition** at `2^w`, at all four widths, and never
  by a diagnostic; a unit lane asserting a diagnostic there is asserting the
  wrong mechanism.
- **Slice ② inherits its constructor list, its pass-6a list, and the shape of
  its own test matrix.** The four-safe/three-failing partition of item 5 is the
  design's §7 task 8 preflight property seen at construction time, so the
  width-by-operation matrix has four operations with no error target and no
  failure column and three with both; that shape is settled here and is not the
  implementing task's to choose. Field branch has no error slot to design.
- **Slice ③ loses one arm and gains no code.** Its constructor takes `base` in
  `{10, 16}` plus local shape and nothing relational — there is no machine to
  resolve a field against at construction. §16.2:904's *base* half is
  discharged by an in-place note beside the pass, not by a clause inside pass
  6a's field walk; its *incompatible field* half stays as the design's §4.6
  settles it, folded into the declared-field-reference check. The milestone's
  Exit limitation 3 (§16.2:904 discharged by a check with no independent
  content) stands and is now true of both halves.
- **The diagnostic-code budget holds at two, and this split is what makes it
  hold.** `invalid-field-declaration` covers duplicate and nonportable field
  names (①b); `invalid-field-operand` covers arity, undeclared field
  reference, constant range, mask range, and `low > high` (②, reused by ③ with
  no addition). Width, initial value, operation, predicate and `base` carry no
  code, which is the whole of the saving: five closed sets that §16.2:889 and
  :904 would otherwise have made five diagnostic surfaces.
- **Not touched.** Nothing here changes the diagnostic *record* — widening it to
  §16.4's seven fields is Milestone 7, and the offending field name rides the
  existing `node` slot. Nothing here reaches execution: §15:856's
  check-before-commit is an execution property that item 5 only reads, and
  §25:1569 remains true by construction rather than by rollback. And nothing
  here revisits decision 0017 — its four points stand exactly as written; this
  record establishes only that its *argument* is unavailable where §16.2 speaks.
````

- [ ] **Step 3: Verify and self-review**

Run:
```bash
rg -n "^# 0020:|^Date:|^Status:|^Milestone:" .decisions/0020-field-shape-is-a-constructor-contract.md
git diff --stat
git status --short
```
Expected: the four header lines, with `Milestone: 4, Gate 0 (milestone-4-design.md §4.3)`; a `git diff --stat` that is empty (this task only *adds* a file); and `git status --short` showing exactly one untracked file, `.decisions/0020-field-shape-is-a-constructor-contract.md`. No `.sls`, `.sps`, `.cmake` or `CMakeLists.txt` may appear.

Then check the record against its source and against decision 0009:
```bash
rg -n "§4.3" .plans/milestone-4-design.md
rg -c "2026-08-31" .decisions/0009-content-and-ir-fingerprints.md || echo 0
```
Expected: the design subsection this record is the durable form of; and `0` — decision 0009 takes **no** amendment in this phase (Global Constraints). Note `rg -c` prints nothing and exits 1 on zero matches, hence the `|| echo 0`. Re-read the design subsection against the record and reconcile any divergence before committing; if the design is wrong, stop and say so rather than encoding the error.

- [ ] **Step 4: Commit**

```bash
git add .decisions/0020-field-shape-is-a-constructor-contract.md
git commit -m "docs: decision 0020 — field shape is a constructor contract

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Decision 0021 — EOF-chain classification generalizes to multi-successor zero-width nodes

**Files:**
- Create: `.decisions/0021-eof-classification-multi-successor.md`
- Test: none. Gate 0 is documentation; its verification is the `rg` checks in each task's penultimate step.

**Interfaces:**
- Consumes: nothing.
- Produces: the generalized EOF walk and its shape (one depth-first walk carrying a path stack and a global visited set), the ordering constraint that puts the rewrite first in Slice ②, and the precedent assignment for §16.2's finish-terminal and EOF-reachable-stop checks. Consumed by Slice ② task 1 and Slice ③.

- [ ] **Step 1: Confirm the number is free and re-read the source section**

Run:
```bash
ls .decisions/
rg -n "^### 4.4 " .plans/milestone-4-design.md
```
Expected: no `0021-*` file exists yet, and the `rg` prints exactly one line — design §4.4, this record's source. Read that subsection in full before writing. If `0021` is taken because a record landed from another branch, use the next free number and carry it through every cross-reference in this plan.

- [ ] **Step 2: Write the record**

Create `.decisions/0021-eof-classification-multi-successor.md`. The shipped
record in the tree is authoritative per the note above; reconcile against it
rather than transcribing the draft block below verbatim.

````markdown
# 0021: EOF-chain classification is a multi-successor search — one DFS, worst case over all paths

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.4)

## Context

Decided against the shipped tree at commit `a942327` (Milestone 3 close). Every
`verify.sls` and `runtime.sls` citation below is **pre-slice**: Slice ②'s first
task rewrites the function this record is about, so each names the construct as
well as the line.

`eof-terminal` (`verify.sls:356-385`) is structurally single-successor. Every
non-terminal arm tail-calls `loop` on exactly **one** target, with `seen` a flat
list threaded down that one path: the pause arm `(loop
(pause-node-continuation n) (cons name seen))` at `:366`, the byte-dispatch arm
`(if (symbol? t) (loop t (cons name seen)) 'default-error)` at `:379-381`, and
the sequence arm, byte-identical in body, at `:382-384`. `(memq name seen)` at
`:360` is both the cycle test and the whole of the walk's memory.

Parent §10.6:582, on the field branch: "Every possible result must have an
explicit target." A field branch carries two (`true-target`, `false-target` —
§9.1:305-306) and a field action carries `next` plus `error` (§9.1:301), `error`
being a node name and `#f` only when the operation cannot fail (design §4.3).
Neither shape has a representation in a walk that recurses on one target. Both
kinds are zero-width (§10.6:550, §11.4:652), so both can sit on an EOF chain —
which decision 0011 item 3 made a *chain* rather than a direct resolution
precisely so that later zero-width kinds could.

**The failure is silent, and silence on this surface is reported as a clean
verdict.** `eof-terminal`'s final arm is `(else 'unknown)` (`:385`), and both
callers discard that answer: the §16.2:909 chain walk's `(case (eof-terminal m
t) ...)` ends `(else '())` (`:417-424`), and the byte-reachable-pause walk's
identical `case` ends the same way (`:449-456`). Point a dispatch node's
`eof-target` at a node of an unhandled kind and the analysis stops there and
reports nothing — `verify` answers ok `#t`, zero diagnostics, for a chain it
never classified.

Nothing downstream catches that. `parser-finish-op!` says so in its own header:
"No local cycle guard: termination relies on the verifier's
eof-zero-progress-cycle/eof-reachable-stop checks having already rejected
non-terminating and stop-terminating EOF chains" (`runtime.sls:275-280`), and
the generated finish path `parser-finish-v2!` (`:260-272`) runs `exec` once and
does not re-verify. Termination in both lanes is a claim this analysis makes.

The tree has already measured what that costs, in a note kept deliberately at
`verify.sls:307-318`: a sequence node whose mismatch edge reexecuted into itself
"verified with ok #t and zero diagnostics", and feeding it one non-matching byte
"did not return: reproduced under a timeout in both the interpreted lane
(parser-feed-op!'s `(loop pos)`, runtime.sls:200) and the generated lane
(compile.sls's emitted `(loop pos <target> off)` fallback), since neither has a
local cycle guard and both rely on this REPORT set." One node kind earlier, that
is this record's failure mode exactly: an unfed kind-dispatch arm, a clean
verdict, a hang in both lanes.

Finally, §16.2:909 already states the obligation over paths rather than over *a*
path — "every EOF path must reach finish or error after finitely many explicit
pauses" — so what follows is a reading of the requirement, not an extension of
it.

## Decision

1. **`eof-terminal` classifies a chain by searching every successor of every
   node it reaches, and the verdict is the worst case over all paths.** Any path
   reaching a stop yields `eof-reachable-stop`; any path that cycles yields
   `cycle`, which outranks it, because a cycle is the non-termination neither
   runtime loop guards against (`runtime.sls:275-280`, `:200`) and must survive
   the join. The total order is pinned in the source for determinism even where
   it is not yet observable: `pass-eof-execution` `case`s on `eof-terminal`'s
   **single** answer (`verify.sls:417-424`, `:449-456`), so a node yields at
   most one EOF diagnostic however many arms its chain has, and the join's
   choice *is* the diagnostic the user sees.
2. **The walk is one depth-first traversal carrying two structures, and that
   settles the join.** A **path stack**: a back edge to a node on the current
   path is a `cycle`, and only that is. A **global visited set**: a node whose
   exploration has *completed* is not re-explored, its verdict is reused. Two
   paths converging is not a cycle, and re-walking the join makes a branchy
   chain exponential. Reuse is sound because any cycle through a node consists
   of nodes reachable from it, so it is found while that node is itself on the
   path — a completed node's verdict is therefore path-independent, and
   preserving that invariant is part of this decision. The two naive
   alternatives §4.4 first floated are two different algorithms with two
   different bugs, which is why neither is left to the implementing slice.
   Making `seen` per-path keeps one structure doing both jobs and pays 2^k
   paths for k branch nodes on a chain, re-classifying every join once per path
   into it. Letting one shared `seen` tolerate re-visits — that is, keeping it
   as the cycle test — reports `cycle` for a diamond that merely re-converges,
   a false rejection of a legal machine. "Is this node on the path I am on
   now" and "have I classified this node already" are different questions, and
   one list cannot answer both.
3. **`'unknown` is eliminated by the rewrite, not joined into the lattice.** The
   rewrite gives every §10.6 node kind `ir.sls` can construct its own arm, and
   `'unknown` leaves the answer set rather than becoming its least element. A
   value that both callers' `case` maps to `(else '())` is not a lattice bottom,
   it is the silence above; a residual arm may not reintroduce one.
4. **The rewrite is Slice ②'s first task, executed before either new node kind
   exists**, as a behaviour-preserving refactor whose oracle is *no diagnostic
   on any existing fixture changed*. Run with neither kind in `ir.sls`, so
   nothing confounds the refactor with new-arm behaviour — the `else` arms
   accept an unhandled kind silently, so a rewrite landing in the same commit
   as a new kind has no clean oracle, since a changed diagnostic could be
   either. Gate: `ctest --preset pr` and `--preset release` green, zero
   diagnostic-code or diagnostic-count edits in
   `test/common/verify-tests.sps`, and the three pinned IR fingerprints and all
   three committed goldens byte-identical.
5. **At §16.2:908's and :909's four filter sites, the two zero-width kinds
   follow the *pause* precedent and integer accumulate follows the *dispatch*
   precedent** (design §4.6). The unconditional source filters `(or
   (byte-dispatch-node? n) (sequence-dispatch-node? n))` at `verify.sls:400`
   (:908) and `:414` (:909) are **not** extended for field action or field
   branch; the byte-reachability-gated blocks at `:436-445` and `:446-457` are,
   each as a sibling block beside the pause block rather than by widening
   `(pause-node? n)` at `:438` and `:448`. Decision 0011's reasoning — recorded
   in the tree at `verify.sls:387-390`, "an eof-only-reachable pause legally
   continues into a finish node (decision 0011); a byte-reachable one must not"
   — applies verbatim to any zero-width kind. Integer accumulate reads input and
   joins the two unconditional filters instead, in Slice ③.

## Consequences

- **Rejects the alternative of forbidding field-action and field-branch nodes on
  EOF chains.** That reading would reject a legitimate and obvious machine — at
  EOF, branch on whether a length field was ever set — that §21.3's fixture will
  want, and it cannot be recovered statically, since field values depend on
  consumed input. It would also re-impose, for two kinds, exactly the
  "eof-target must resolve directly to a terminal" restriction decision 0011
  item 3 declined so that later milestones would not have to remove it.
- **This extends decision 0011's analysis without changing any of its rules, and
  0011 needs no dated amendment.** Its item 3 names "zero-width
  action/callback/span nodes on the EOF path" as the future its chaining was
  general for; its item 4's three checks keep their wording, their codes
  (`eof-reachable-stop`, `eof-zero-progress-cycle`, `non-eof-into-finish`) and
  their byte-reachability/eof-reachability split. Every machine expressible
  before this record classifies identically after it — that is item 4's oracle.
  0011 fixed the rules, not the algorithm implementing them, so there is
  nothing in its text this supersedes. Contrast §4.1, which does owe decision
  0012 a dated amendment: it retires a name 0012 fixed.
- **Obliges** a `verify-tests.sps` fixture that distinguishes the two structures
  rather than merely exercising a branch: a diamond that must verify clean and a
  back edge that must report `eof-zero-progress-cycle`. A test that only walks a
  branching chain passes under both rejected algorithms.
- **Obliges** the field-action and field-branch arms to report their full
  successor set — `next` plus `error` when it is a symbol, both branch targets —
  in `node-out-targets` and `reexec-targets` as well, since `pass-reachability`,
  `pass-names`, `byte-reached` and `pass-zero-progress` all walk those two and
  would otherwise disagree with this walk about what a successor is.
- **Does not touch** `node-eof-target` (`verify.sls:82-85`), whose `(else #f)`
  is the right answer for two kinds that read no input, and adds **no** runtime
  cycle guard in either lane: termination stays a verifier obligation, exactly
  as `runtime.sls:275-280` states it. The generated finish path continues not to
  re-verify.
- **Does not settle** the other eleven silently-failing kind-dispatch sites the
  design's §7 census counts inside `verify.sls`. This record closes one of them,
  the one whose silence is reported as a clean verdict twice over; the rest keep
  whatever disposition their own slices give them.
````

- [ ] **Step 3: Verify and self-review**

Run:
```bash
rg -n "^# 0021:|^Date:|^Status:|^Milestone:" .decisions/0021-eof-classification-multi-successor.md
git diff --stat
git status --short
```
Expected: the four header lines, with `Milestone: 4, Gate 0 (milestone-4-design.md §4.4)`; a `git diff --stat` that is empty (this task only *adds* a file); and `git status --short` showing exactly one untracked file, `.decisions/0021-eof-classification-multi-successor.md`. No `.sls`, `.sps`, `.cmake` or `CMakeLists.txt` may appear.

Then check the record against its source and against decision 0009:
```bash
rg -n "§4.4" .plans/milestone-4-design.md
rg -c "2026-08-31" .decisions/0009-content-and-ir-fingerprints.md || echo 0
```
Expected: the design subsection this record is the durable form of; and `0` — decision 0009 takes **no** amendment in this phase (Global Constraints). Note `rg -c` prints nothing and exits 1 on zero matches, hence the `|| echo 0`. Re-read the design subsection against the record and reconcile any divergence before committing; if the design is wrong, stop and say so rather than encoding the error.

- [ ] **Step 4: Commit**

```bash
git add .decisions/0021-eof-classification-multi-successor.md
git commit -m "docs: decision 0021 — EOF-chain classification generalizes to multi-successor nodes

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Decision 0022 — The structured parser-error record

**Files:**
- Create: `.decisions/0022-structured-parser-error-record.md`
- Test: none. Gate 0 is documentation; its verification is the `rg` checks in each task's penultimate step.

**Interfaces:**
- Consumes: 0019's carriage of the error declaration's `reason` through the encoding.
- Produces: the `parser-error` record's shape and full accessor list, the rule that it is constructed identically in both lanes, how position kind reaches it, and which accessor is excluded from cross-lane comparison. Consumed by Slice ①a tasks 2 and 5.

- [ ] **Step 1: Confirm the number is free and re-read the source section**

Run:
```bash
ls .decisions/
rg -n "^### 4.5 " .plans/milestone-4-design.md
```
Expected: no `0022-*` file exists yet, and the `rg` prints exactly one line — design §4.5, this record's source. Read that subsection in full before writing. If `0022` is taken because a record landed from another branch, use the next free number and carry it through every cross-reference in this plan.

- [ ] **Step 2: Write the record**

Create `.decisions/0022-structured-parser-error-record.md`. The shipped
record in the tree is authoritative per the note above; reconcile against it
rather than transcribing the draft block below verbatim.

````markdown
# 0022: The structured parser-error record — one shape in both lanes, position kind from the arriving transition

Date: 2026-08-31
Status: accepted
Milestone: 4, Gate 0 (milestone-4-design.md §4.5)

## Context

Decided against the tree at `a942327`, the commit Milestone 3 closed at. `HEAD`
(`0a267de`) adds only the Milestone 4 design document; no product file differs.

**Today the error slot is a bare code symbol.** `parser-result-error` is
`(vector-ref r 5)` of the parser-result vector (runtime.sls:88-95), and every
producer puts a symbol there. The interpreter's `error-value` returns
`(error-declaration-code (lookup-error errors …))` (interpret.sls:105-107), and
`default-eof-value` the same (interpret.sls:108-109). The emitter renders that
symbol as a literal in the error arm (compile.sls:113-115) and in the
default-eof arm (`render-eof-branch`, compile.sls:95-99); the committed golden
shows the result as `(byte-machine-make-feed-outcome/v1 (quote error) pos (quote
unexpected-byte) 3 off)` (test/fixtures/generated-http-version.golden.sls:18).
Tests read it as a symbol — `(check-equal "error value" (parser-result-error r)
'unexpected-byte)` (runtime-tests.sps:51). Of §9.3:397-405's nine public names,
**none** exists: `rg 'parser-error'` over `src/` returns nothing. A machine
error therefore reports one of the eight members §12.7:753-760 requires it to
record.

**The family has been deferred twice, both times to "M4/M5".** Milestone 2 put
it out of scope in its own §7 — "**The full structured `parser-error-*` accessor
family** (§9.3), including `position-kind`" — with the note that "the
categorical `position-kind` marker and richer error structure arrives with the
milestones that produce richer errors (M4+)"
([milestone-2-design.md](./milestone-2-design.md):461-464). Milestone 3
deferred it again in its §8:992-997, on the same authority. The rule both
deferrals rest on is milestone-2-design.md:343-344, which rejected shipping
`position-kind` alone in M2 because that "removes an inconsistent carve-out
(populating one field of an otherwise-deferred accessor family)". That rule is
the reason the family cannot land a member at a time, and it is what makes this
record's scope the whole of §9.3:397-405 rather than the two members M4's own
error paths would otherwise force.

**A third deferral is not available.** §22.4:1271 makes the
interpreter≡generated differential compare "error domain, code, public
source-node name, absolute position, and position kind", and Milestone 4's exit
criterion §25:1570 is discharged through that list — so deferring again would
make M4's own exit criterion unassertable in the terms §22.4 states it.

**The debug map was deferred on exactly this dependency, and its inverse is
already built.** Milestone 3's §8 struck §17:963's map with a reason that names
this record: "**The state-ID-to-source-name debug map** (§17:963) — its only
consumers are the unshipped parser-error accessors, and no v0.1 error is raised
*inside* a lowered prefix state"
([milestone-3-design.md](./milestone-3-design.md):1004-1006). The forward
direction exists: `lower-machine` builds `name->id` by walking `machine-nodes`
with an index (private/normal-ir.sls:140-142). It is local — `lower-machine`
returns only `(values entry states)` (:248) and `make-normal-machine` is a
four-slot vector (:28) — so the inverse is a threaded return value, not an
analysis. Internal prefix states are the one part `name->id` does not cover:
they are numbered by `allocate-prefix-ids` (private/normal-ir.sls:128-135) from
the declared count onward and must take their entries from the prefix-block walk
instead of from inverting the alist.

**Position kind is a property of the transition that arrived, not of the error
state.** §12.7:766-773's table is the authority, and two of its rows prove the
point on their own:

| Error source | Stored position |
| --- | --- |
| Reexecute mismatch or rejected current digit | `byte` at the current stream offset |
| Error edge after an advance | `boundary` after the committed byte |

One error node reached by a reexecute edge reports `byte`; the *same* node
reached by an advance edge reports `boundary`. The emitted arm for a normalized
error state is keyed on the state id alone (`render-state-arm`,
compile.sls:113-115) and cannot see which edge jumped to it, so position kind
cannot be a per-site literal in either executor. The remaining rows are :770
("Zero-width machine action or callback failure" → `boundary` at the current
stream offset) and :771 ("Truncated input during `finish!`" → `eof` at the final
stream offset).

**All three kinds are already producible, which is why the family is
front-loadable.** `byte` comes from a reexecute fallback, `boundary` from an
advance-mode edge, and `eof` from a `finish!` over exhausted input — byte
dispatch and error nodes only, both shipped in Milestones 1 and 2. The whole
family can therefore be proved in a slice that adds no node kind; Slice ② adds
:770's row and Slice ③ :773's overflow rider to a table that already works.

## Decision

1. **The record is one tagged vector with eight members and nine public names,
   and the member order is §9.3:398-405's.** `domain`, `code`, `reason`,
   `detail`, `node-name`, `state-id`, `offset`, `position-kind`, plus
   `parser-error?` (§9.3:397). It lives beside the parser-result tag
   (runtime.sls:86-95) and is opaque per §9.3:425. Generated code constructs it
   through one reserved binding, `byte-machine-make-parser-error/v1`; all ten
   names are mirrored into `reserved-member-2` (compile.sls:44-52, twenty
   symbols at `a942327`) in the same commit that exports them, per decision 0012
   item 4, so the `reserved-drift-tests.sps` guard stays load-bearing.
2. **Every accessor ships at once, and `domain`/`detail` ship at their
   *specified* machine-domain values.** `domain` is `machine` and `detail` is
   `#f` at every Milestone 4 construction site. `#f` is not a placeholder:
   §9.3:401 annotates `detail` "`#f` for machine errors". This is what
   milestone-2-design.md:343-344 requires — a whole family, not one populated
   field of a deferred one.
3. **Both lanes construct the same record, with the same members, from the same
   inputs.** The interpreter's two error producers (interpret.sls:105-107 and
   :108-109) and the emitter's two error-producing arms (compile.sls:113-115 and
   :95-99) stop yielding `error-declaration-code` and yield a `parser-error`
   instead. They land in one commit: the lanes are compared by value, so a split
   leaves the differential red between commits. §12.7:777 makes source-node
   name, domain, code, offset and position kind "semantic and must match between
   interpreted and generated execution", and this is the construction that makes
   that assertable.
4. **`feed-outcome` does not grow.** It keeps its five slots and its `/v1`
   constructor (runtime.sls:78-84); its existing `error` slot merely carries a
   richer value. Decision 0012 item 3 is the precedent — "`paused` and
   `finished` are new status *symbols*, not a new record" — and the only
   reserved `feed-outcome` `/v2` is decision 0010's Consequences / Slice-B
   amendment, an optimization "gated on benchmark evidence" (§23) that cannot
   exist yet: `bench/` holds two `.gitkeep` files. Consequently the sticky-error
   rows (runtime.sls:150-151 and :245-246), the four `parser-set-stored-error!`
   call sites (:161, :268, :301, :309) and the slot's setter (:135) take no
   edit: they store and return whatever the executor produced. That is the
   amendment working rather than an omission.
5. **Position kind is carried as one more loop variable in each executor, set
   from a literal at each jump.** `advance` → `boundary`; `reexecute` → `byte`;
   the EOF-chain jump → `eof`; and — the case Milestone 4's seam slice cannot
   itself produce, fixed here so Slices ② and ③ inherit a rule instead of each
   choosing one — a **zero-width jump → `boundary` at the current stream
   offset**, per §12.7:770. Initialize to `byte` at loop entry: nothing has been
   consumed in this call, so a resumed feed entering an error state directly
   reports the current byte. In the generated lane it is a fourth argument to
   the emitted `loop` (header at compile.sls:157; both `loop-tail` forms at
   compile.sls:75-78), and it joins `reserved-member-3` (compile.sls:53) in the
   commit that emits it. In the interpreter it is a second loop variable in
   `parser-feed-op!` (runtime.sls:171-201, whose dispatch arm already has the
   mode in hand at :196) and a constant `eof` in `parser-finish-op!`
   (runtime.sls:274-311).
6. **The absolute offset needs no new arithmetic.** `off` is already bumped on
   advance and not on reexecute — in the interpreter at runtime.sls:196-200 and
   in the emitted tails at compile.sls:75-78 — so `(off, position-kind)` *is*
   §12.7's stored position in both executors. That the two lanes reach it by the
   same rule from independent code is the strongest available evidence the
   lowering is 1:1.
7. **The static payload lives in one immutable per-library table keyed by error
   *declaration*, not per site.** Generated code defines `(define errs (quote
   #(#(<code> <reason>) …)))`, one entry per error declaration — §19.1:996's
   "immutable field/callback/debug metadata" literally — and each site builds
   its record from a table index plus its own two literals (public source-node
   name, state id) and the loop's two variables. The reason is measured, not
   aesthetic: `generated-http-version.golden.sls` carries **nine** error sites
   over **two** declarations, eight of them the default-eof arm (:10, :22, :31,
   :40, :49, :58, :67, :76) because `render-eof-branch` renders at every
   dispatch state. Per-site literals would repeat each reason string once per
   site. `errs` joins `reserved-member-3` with the loop variable.
8. **`parser-error-state-id` is the single accessor excluded from cross-lane
   differential comparison, on §12.7:777's authority** — generated IDs "are
   deterministic for a given normalized graph, but an independently interpreted
   machine need not report the same ID. Differential tests do not compare that
   accessor across executor kinds." Both lanes must still *report* one; only the
   comparison omits it. The exclusion is expressed once, in one shared
   projection over the §22.4:1271 five, and asserted **positively** — a check
   that fails if the exclusion is ever widened to drop a comparable member —
   because the differential's obvious repair for the red this record causes is
   to narrow the comparison back to the code symbol it compared before the
   family existed.
9. **The §17:963 debug map is normalizer output, total over internal prefix
   states, and cannot perturb the IR fingerprint.** It is what makes
   `parser-error-node-name` answerable in the generated lane, where the emitter
   needs the public name of each state as an emission-time literal. It is added
   as a member of the normal-machine vector (private/normal-ir.sls:28) and
   threaded out of `lower-machine` (:248) rather than reconstructed;
   milestone-3-design.md:1008-1009 already established the fingerprint argument
   — "`encode-normal` is called as `(encode-normal entry states)` and never sees
   names" — and that call is unchanged at private/normal-ir.sls:286.

## Consequences

- **Milestone 4 can assert §22.4:1271 in the terms §22.4 states it.** Error
  domain, code, public source-node name, absolute position and position kind
  become five comparable values across interpreter and generated execution where
  there was one symbol, so exit criterion §25:1570's error clause is discharged
  against node kinds already shipped, before Milestone 4's first field exists.
  Slices ② and ③ inherit decision 5's zero-width rule and add one populated row
  each rather than re-deriving a convention.
- **Two enumerated values ship with no producer until Milestone 5, and that is
  not a half-populated family.** `domain` = `callback` and a non-`#f` `detail`
  have exactly one producer in the plan — §13:808's "explicit callback failure
  containing an application code and optional detail", with §13:824 fixing that
  "no error is installed until a callback returns failure" — and callbacks are
  Milestone 5 (§25:1572). What milestone-2-design.md:343-344 forbids is
  populating one *field* of a deferred *family*; every one of §9.3:397-405's
  accessors ships here, and an enumerated field whose second value has no
  producer yet is the ordinary condition of a closed enumeration mid-plan.
- **The encoding is obliged to carry the error declaration's `reason`, and that
  obligation is decision 0019's, not re-decided here.** Normalization discards
  it today: the `errcode` helper resolves a declaration name to
  `error-declaration-code` and nothing else (private/normal-ir.sls:144-147),
  even though `error-declaration-reason` has existed since Milestone 1
  (private/ir.sls:288). Because the record now reports the reason, two machines
  differing only in a reason are observably different machines, and decision
  0009 point 2 makes the IR fingerprint the object §20:1043 embeds and the
  determinism checks compare — so a reason outside the canonical encoding would
  leave the fingerprint no longer identifying what was emitted.
- **This record is what makes §16.2:886's unchecked `reason` clause live.**
  Carrying the reason into the record means an author-supplied string is written
  into generated Scheme source for the first time; `pass-names-valid` checks
  machine, node, error-declaration names and codes and no reason at all
  (verify.sls:461-477), and §10.1:480 restricts embedded reasons to printable
  ASCII plus LF. The gap was inert only because the emitter had never written a
  user-controlled string. Closing it, and the matching writer-side escaping
  §20:1039 requires, is an obligation of the slice that lands this record, not
  of a later one.
- **It deliberately touches nothing else.** `parser-result` keeps its five slots
  and its accessors (runtime.sls:88-95) — the error member's *type* changes, not
  the result's shape. `graph.sls` takes no edit: §9.3 is a runtime surface, and
  §9.1 fixes the construction surface. The §16.4 diagnostic record is not
  widened; that is Milestone 7 (§25:1616), and §16.4:945 keeps diagnostics
  compared by structure and code rather than rendered text either way.
  `parser-field-ref` and the callback-visible half of §25:1564 are untouched:
  they are Milestone 4's later slices and Milestone 5's caller. And nothing here
  upgrades §9.4:438's ABI-mismatch condition, which decision 0010 item 5 still
  leaves as an `assertion-violation`.
````

- [ ] **Step 3: Verify and self-review**

Run:
```bash
rg -n "^# 0022:|^Date:|^Status:|^Milestone:" .decisions/0022-structured-parser-error-record.md
git diff --stat
git status --short
```
Expected: the four header lines, with `Milestone: 4, Gate 0 (milestone-4-design.md §4.5)`; a `git diff --stat` that is empty (this task only *adds* a file); and `git status --short` showing exactly one untracked file, `.decisions/0022-structured-parser-error-record.md`. No `.sls`, `.sps`, `.cmake` or `CMakeLists.txt` may appear.

Then check the record against its source and against decision 0009:
```bash
rg -n "§4.5" .plans/milestone-4-design.md
rg -c "2026-08-31" .decisions/0009-content-and-ir-fingerprints.md || echo 0
```
Expected: the design subsection this record is the durable form of; and `0` — decision 0009 takes **no** amendment in this phase (Global Constraints). Note `rg -c` prints nothing and exits 1 on zero matches, hence the `|| echo 0`. Re-read the design subsection against the record and reconcile any divergence before committing; if the design is wrong, stop and say so rather than encoding the error.

- [ ] **Step 4: Commit**

```bash
git add .decisions/0022-structured-parser-error-record.md
git commit -m "docs: decision 0022 — the structured parser-error record

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---
## Task 6: Close Gate 0 in the design document

**Files:**
- Modify: `.plans/milestone-4-design.md` (§4 preamble, and §10's first bullet)

**Interfaces:**
- Consumes: all five records from Tasks 1–5, by their assigned numbers.
- Produces: a design document whose §4 names the assigned record numbers, so Slices ①a–③ cite numbers rather than section references, and whose §10 no longer hands writing-plans a question that has been answered.

- [ ] **Step 1: Confirm all five records exist and carry the expected numbers**

Run:
```bash
ls .decisions/
rg -n "^# 00(1[89]|2[0-2]):" .decisions/
```
Expected: exactly five new records, `0018`–`0022`, with the titles from Tasks 1–5. If the numbers differ from this plan because a record landed from another branch, note the actual numbers and use them consistently in Steps 2 and 3, and re-check the cross-references *between* the five records (0022's Consequences cite 0019; 0020 and 0021 cite each other's scope boundary).

- [ ] **Step 2: Add the Gate-0-discharged mapping to §4's preamble**

§4's preamble currently reads, in full:

```
Decision-only. No product code is written in Gate 0. writing-plans assigns the
record numbers (next free in `.decisions/` is **0018**) and confirms whether
any splits or merges of the five below are warranted.
```

Leave that paragraph exactly as it stands — it is the record of what Gate 0 was asked to do — and append the dated blockquote below it. This is an *appended record* of what was decided, not a rewrite of §4's argument:

```markdown
> **Gate 0 discharged 2026-08-31.** §4.1 → decision
> [0018](../.decisions/0018-unversioned-generated-abi-constructor.md), §4.2 →
> [0019](../.decisions/0019-encoding-format-2-pre-provisioned.md), §4.3 →
> [0020](../.decisions/0020-field-shape-is-a-constructor-contract.md), §4.4 →
> [0021](../.decisions/0021-eof-classification-multi-successor.md), §4.5 →
> [0022](../.decisions/0022-structured-parser-error-record.md). Neither merge
> §10 asked about was taken, and neither was §4.3's internal split: the
> reasoning is in §10's first bullet, and each record states its own boundary.
> §4.6's nine resolutions and §4.7's four scope additions stayed in this
> document by design and have no records. 0018 additionally carried dated
> amendment notes onto **two** records — decision 0012 item 1 and decision 0010
> item 4, the latter found by a vocabulary sweep rather than by §4.1's original
> text — and one in-place correction into the parent plan's §9.5:442. §9.5:444
> was deliberately left alone: bumping `current-abi-version` 2 → 3 satisfies its
> "generated-ABI version bump" requirement rather than contradicting it.
```

- [ ] **Step 3: Append the merge resolutions to §10's first bullet**

§10's first bullet hands writing-plans the five record forms and asks it to confirm two possible merges, and to note that §4.3's `error`-slot rule is deliberately fused. Append the outcome so a later reader does not re-open a settled question. Add at the end of that bullet, preserving its existing text:

```markdown
  **Resolved:** five records, no merges. §4.1 and §4.2 stayed separate — 0018
  carries an amendment to 0012 and 0019 carries a fingerprint re-baseline, and a
  reader looking for either would not find it in a record named for the other.
  §4.3's `error`-slot rule stayed inside 0020, because deciding which operations
  can fail is the same act as deciding where that is checked, and a reader who
  applied one without the other would require an unreachable error node on
  `store`.
```

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "0018|0019|0020|0021|0022" .plans/milestone-4-design.md
rg -n "confirms whether" .plans/milestone-4-design.md
rg -c "Gate 0 discharged" .plans/milestone-4-design.md
```
Expected: the first shows §4's blockquote naming all five numbers and §10's `**Resolved:**` paragraph; §11 (References) contributes **no** hits — it catalogues the design's *antecedent* decisions (0009–0012, 0015–0017) and Gate 0 does not touch it, exactly as Milestone 3's Gate 0 did not touch its own §10. The second still prints the §4 preamble line, unchanged — it is a record of the question, and Step 2 appends rather than replaces. The third prints `1`. Fix inline.

Then confirm the five links resolve:
```bash
for f in 0018-unversioned-generated-abi-constructor 0019-encoding-format-2-pre-provisioned \
         0020-field-shape-is-a-constructor-contract 0021-eof-classification-multi-successor \
         0022-structured-parser-error-record; do
  test -f ".decisions/$f.md" && echo "OK  $f" || echo "MISSING  $f"
done
```
Expected: five `OK` lines.

- [ ] **Step 5: Commit**

```bash
git add .plans/milestone-4-design.md
git commit -m "docs: discharge Milestone 4 Gate 0 — map design §4 to decisions 0018-0022

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Self-Review (run after all six tasks)

1. **Spec coverage.** `milestone-4-design.md` §4 lists five resolutions requiring records (§4.1 the unversioned ABI constructor, §4.2 encoding format 2 pre-provisioned, §4.3 the constructor/verifier split including the `error`-slot rule, §4.4 multi-successor EOF classification, §4.5 the structured parser-error record), plus §4.6's nine in-document resolutions and §4.7's four scope additions. Task 1 ↔ §4.1 (with both amendments it forces), Task 2 ↔ §4.2, Task 3 ↔ §4.3, Task 4 ↔ §4.4, Task 5 ↔ §4.5, Task 6 closes the loop. §4.6 and §4.7 deliberately get no records — the design says so and Task 6 Step 2 states it. The design's §10 also hands *proving machines*, *pin re-anchoring*, *lane bookkeeping*, *the golden environment-variable trap*, *completion sentinels* and *sizing* to writing-plans; every one of those is a Slice ①a/①b/②/③ plan concern, not Gate 0, which is decisions only. Covered.

2. **Placeholder scan.** Every record body below is complete decision text, not a summary. Every `rg` and `ls` has a stated expected result. Every date is the literal `2026-08-31`, with the Global Constraints rule for a task that runs later. No "TBD", no "similar to Task N", no "add appropriate handling". The only conditionals are Task 1 Step 1's and Task 6 Step 1's instructions for a number collision, and Task 1's vocabulary sweep acting on whatever it finds — both are real branches, not placeholders.

3. **Consistency across the five records.** They share one vocabulary: *the seam* for the runtime↔generated boundary, *the canonical encoding* for what the fingerprint covers, *zero-width* and *input-reading* for the node classification, *pre-slice* for a citation into code the milestone will edit. The boundaries are stated rather than assumed: 0019 owns the encoding's `reason` and 0022 cites it rather than re-deciding it; 0020 owns where field validation lives and 0021 does not restate it; 0018 owns the ABI name and 0019 owns the ABI *payload*, including the reserved `exec` parameter, and each says which is which. 0019 and 0022 both bear on Slice ①a's single re-baseline, and only 0019 measures it.

4. **Record vs instruction.** Decisions 0012 and 0010 are records → dated amendment notes appended, their Contexts left intact as the evidence of the trees they were decided against. The parent plan's §9.5:442 sentence is a normative instruction → corrected in place, with git holding what it said; §9.5:444 is a true instruction and is left alone, because a version-*number* bump is exactly what it requires. `milestone-4-design.md` §4 and §10 get *appended* dated notes, never rewrites — including §4's preamble sentence, which records the question Gate 0 was asked. Decision 0009 is deliberately unamended, and Task 2's verify step checks that no amendment was added to it. Correct.

5. **No counts, no code.** No task touches a `.sls`, a `.sps`, a CMake file, `README.org` or `CHANGELOG.md`. Task 1's vocabulary sweep reads the last two and reports; it does not edit them, because the milestone's status surfaces move when the milestone closes. Task 2's record *measures* the re-baseline it concentrates in Slice ①a and cites what it measured — that is a measurement of the shipped tree, not a forecast of a milestone total, and it carries its scope with it.

6. **Ordering.** Two real dependencies, not none: **Task 1 before Task 2**, because 0019 reserves member 0 of the payload shape 0018 defines; and **Task 2 before Task 5**, because 0022 consumes 0019's carriage of the error declaration's `reason` through the encoding and must cite it rather than re-decide it. Tasks 3 and 4 are independent of everything and of each other. Task 6 consumes all five. Within Task 1, all four artifacts land in **one commit** — a record that retires a mechanism while the parent plan still names it leaves the spec asserting something the decision has killed, and a reader who pulls the intermediate commit sees exactly that.

7. **What Gate 0 deliberately does not do.** It writes no `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` forecast, adds no lane, and touches neither `README.org` nor `CHANGELOG.md`. The CHANGELOG entry §9.5:444 requires for a pre-1.0 ABI change is **Slice ①a's**, not Gate 0's, because it records what shipped and nothing has shipped yet; 0018's Consequences say so. The milestone's four status surfaces move when the milestone closes.
