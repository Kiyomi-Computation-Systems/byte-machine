# Milestone 1 — Gate 0 (design-call resolutions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settle, as durable records, the three design calls the Milestone 0 close-out handed to Milestone 1, so every later phase cites a decision instead of re-deriving it.

**Architecture:** This phase writes and edits *documentation only* — no product code, no tests, no CMake. It produces two new decision records and corrects the parent plan's now-stale instructions in place. It is the prerequisite for Phase 3 (which builds the emitter the include-collapse decision governs) and for Phase 2 (which the reserved-binding scoping note bounds).

**Tech Stack:** Markdown, `rg`, git. No Scheme, no CMake.

## Global Constraints

- Decision records follow the repo format: `# NNNN: <title>` / `Date: YYYY-MM-DD` / `Status: accepted` / `Milestone: 1` / `## Context` / `## Decision` (numbered) / `## Consequences`. See `.decisions/0006-inline-libraries.md` and `.decisions/0007-milestone-0-closes-at-the-harness.md` for the house style.
- The next free decision number is **0008** (last is `.decisions/0007-milestone-0-closes-at-the-harness.md`). Confirm with `ls .decisions/` before writing; if a higher number exists, use the next free pair in order.
- **Record vs instruction discipline (AGENTS.md).** A *record* (a measurement, a finding, a decision's Context) gets a dated amendment note, never a rewrite. An *instruction* (a work-order, an exit criterion, a Deliver/Scope entry, or a live comment saying what code is for) is corrected in place. §9.6's numbered example steps, §9.5's ABI description, and §7.1's "Milestone 1's to settle" sentence are **instructions** → corrected in place.
- **Citation staleness (AGENTS.md / project memory).** Before editing any parent-plan sentence, `rg` for it and Read the surrounding lines to confirm the *current* wording. Do not trust the quoted "current text" in this plan as exact — line numbers and phrasing drift. Match against what the file says at HEAD.
- Conventional Commits. One decision (plus the parent-plan corrections it forces) per commit.
- `.superpowers/sdd/` is git-ignored; nothing there is committed. All artifacts here live under `docs/`.

---

## Task 1: Decision 0008 — the include collapse

**Files:**
- Create: `.decisions/0008-emitter-emits-importable-library.md`
- Modify: `.plans/byte-machine-implementation-plan.md` (§9.6 step 5; §9.5 ABI paragraph; §7.1 "generated bodies" sentence)
- Modify: `.decisions/0006-inline-libraries.md` (add a forward-reference note if its no-include rule is now cited by 0008 — optional, see Step 5)

**Interfaces:**
- Produces: the settled contract "the emitter emits a complete importable R6RS `.sls` library; consumers compose by `import`, never `include`." Phase 3's emitter task and the §9.6 end-to-end example consume this.

- [ ] **Step 1: Confirm the decision number and read the targets**

Run:
```bash
ls .decisions/
rg -n "including that generated body|wrapper-free|generated bodies|Milestone 1's to settle" .plans/byte-machine-implementation-plan.md
```
Expected: `0007-...md` is the highest-numbered record (so 0008 is free); the `rg` prints the four instruction sites (§9.6 step 5, §9.5 wrapper-free sentence, §7.1). Read ~10 lines around each hit to capture exact current wording.

- [ ] **Step 2: Write the decision record**

Create `.decisions/0008-emitter-emits-importable-library.md`:

```markdown
# 0008: The emitter emits a complete importable library, not an included body

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 1, Gate 0 (milestone-1-design.md §3.1)

## Context

The parent plan's §9.6 required Milestone 1's end-to-end example to *include*
the generated body from a hand-written consumer library wrapper. Decision 0006
(§7.2) forbids any Scheme file in this repository including another. The two
instructions contradict each other; the Milestone 0 close-out (§9) recorded the
conflict as a design call, not a wording fix, and handed it here.

The pre-collapse design imagined the emitter writing a bare `.scm` body (loose
definitions, not a module) that a hand-written `.sls` wrapper pulled in with
`(include ...)` and re-exported. Decision 0006 removed the only mechanism that
made that composition possible: a bare body is not a module, so nothing can
`import` it, and `include` is banned.

## Decision

1. **The emitter emits a complete, self-contained R6RS `.sls` library.** The
   generated file owns its library name, its export list, and its imports; its
   only byte-machine import is `(byte-machine runtime)`. It contains the machine
   body and defines exactly the single top-level compiled-machine binding named
   by the `binding` argument to `render-machine`/`emit-machine` (§9.2).
2. **Consumers compose the generated parser by `import`, never `include`.** The
   §9.6 example's consumer does `(import (<generated-library-name>))`; there is
   no wrapper that includes anything. §7.2's no-include rule stands unbroken.
3. **"Wrapper-free" is read as "needs no hand-written wrapper."** §9.5's ABI
   export exists so the generated code's sole byte-machine dependency is
   `(byte-machine runtime)`. The generated library is itself the importable
   unit; no adapter library is required around it.
4. **A human-authored re-export wrapper remains possible but is out of scope.**
   A consumer that wants a different public library name may write a wrapper that
   imports the generated library and re-exports it — additive, by `import`, and
   not built in Milestone 1.

## Consequences

- Phase 3's emitter writes library boilerplate (the `(library ...)` form, export
  list, and `(import (byte-machine runtime))`) as part of its output, to the
  supplied binary port only (§20).
- The parent plan's §9.6 step 5, §9.5 ABI paragraph, and §7.1 "generated bodies"
  sentence are corrected in place (they are instructions, not records) to match
  this decision.
- Decision 0006's no-include rule is unchanged and now has a second beneficiary:
  generated code composes by the module system like every other library.
```

- [ ] **Step 3: Correct §9.6 step 5 in the parent plan**

Read the current step 5 (from Step 1). Replace the "including that generated body from a consumer library wrapper — this conflicts with §7.2 …" clause with an import-based instruction, e.g.:

> 5. importing the generated library from the consumer — the emitter emits a complete importable `.sls` (decision 0008), so no file includes another and §7.2 holds;

Keep the step's surrounding numbering and the `[0,1)` flow intact.

- [ ] **Step 4: Reconcile §9.5 and §7.1 in the parent plan**

In §9.5, replace the sentence "This export exists so a generated wrapper-free body works when its consumer imports only `(byte-machine runtime)`" with wording that matches decision 0008, e.g.:

> This export exists so a generated library depends only on `(byte-machine runtime)`: the consumer imports the generated library, whose sole byte-machine import is the runtime (decision 0008).

In §7.1, replace "The form of the runtime and *generated* bodies is fixed by §9.6 and is Milestone 1's to settle" with:

> The form of the runtime and generated libraries is fixed by §9.6 and decision 0008: the emitter emits a complete importable `.sls`.

Make the minimal edit that removes the staleness; do not rewrite surrounding prose.

- [ ] **Step 5: Verify cross-references resolve and self-review**

Run:
```bash
rg -n "0008|wrapper-free|include that generated|including that generated body" .plans/byte-machine-implementation-plan.md .decisions/0008-emitter-emits-importable-library.md
rg -n "\(include" src test
```
Expected: no surviving "including that generated body" instruction in §9.6; the new `0008` reference resolves; `rg '\(include' src test` still returns no hits (exit 1 — unchanged; this task adds no code).

Self-review the record: does it state what was decided, what it rules out (bare-body/include), and the evidence (0006 removed the mechanism)? Any "TBD"? Fix inline.

- [ ] **Step 6: Commit**

```bash
git add .decisions/0008-emitter-emits-importable-library.md .plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0008 — emitter emits an importable library, not an included body"
```

---

## Task 2: Decision 0009 — two fingerprints, named apart

**Files:**
- Create: `.decisions/0009-content-and-ir-fingerprints.md`
- Modify: `.plans/byte-machine-implementation-plan.md` (§20 and any site that says "fingerprint" ambiguously in the emission/IR sections)

**Interfaces:**
- Produces: two distinct names — **content/manifest fingerprint** (the shipped harness hash) and **IR fingerprint** (§20's hash over canonical normalized IR). Phase 3 introduces the IR fingerprint and must use the disambiguated name.

- [ ] **Step 1: Survey the ambiguity**

Run:
```bash
rg -n "fingerprint" .plans/byte-machine-implementation-plan.md | rg -n "20\.|normalized|canonical|embed|FNV|IR"
rg -n "fingerprint" test/support/harness/byte-machine/test/fingerprint.sls | head
```
Expected: shows §20's IR-fingerprint uses versus the harness `(byte-machine test fingerprint)` content hash. Read §20 to capture current wording.

- [ ] **Step 2: Write the decision record**

Create `.decisions/0009-content-and-ir-fingerprints.md`:

```markdown
# 0009: Two fingerprints, named apart — content fingerprint and IR fingerprint

Date: <today's date, YYYY-MM-DD>
Status: accepted
Milestone: 1, Gate 0 (milestone-1-design.md §3.2)

## Context

The harness already ships a fingerprint: `(byte-machine test fingerprint)`, a
polynomial rolling hash mod 2^61-1 over a lane's manifest text, used for
build-provenance (decisions 0004, 0006). The parent plan's §20 introduces a
second, unrelated fingerprint — over the canonical normalized IR, permitted to
be 64-bit FNV-1a — embedded in emitted output and used for determinism
comparison. One word names two different objects over two different inputs.
Milestone 1 introduces the second, so the ambiguity becomes live now.

## Decision

1. **The shipped harness hash is the "content fingerprint" (a.k.a. manifest
   fingerprint).** It answers "is the declared manifest text unchanged and read
   identically?" It is provenance, not IR identity. Its library name
   `(byte-machine test fingerprint)` is unchanged.
2. **§20's hash is the "IR fingerprint".** It is computed over the canonical
   normalized IR and embedded in emitted output; it is the object compared in
   the D6 determinism checks. Phase 3 introduces it.
3. **Every site names which it means.** From Milestone 1 onward, prose, exports,
   and comments say "content fingerprint" or "IR fingerprint", never a bare
   "fingerprint", wherever both could be meant.

## Consequences

- Phase 3 introduces `(byte-machine ...)` code and tests for the IR fingerprint
  under the name "IR fingerprint"; it must not overload the harness's content
  fingerprint names.
- §20 of the parent plan is annotated to use "IR fingerprint" explicitly.
- No shipped code is renamed by this record; it fixes vocabulary before the
  second fingerprint exists.
```

- [ ] **Step 3: Annotate §20 and the other emission-fingerprint sites**

In §20, where "fingerprint" refers to the IR/normalized-IR hash, qualify it as "IR fingerprint (decision 0009)" at first use in the section. Also qualify §9.2's `emit-machine` description — "emission metadata containing the fingerprint and byte count" → "…the IR fingerprint and byte count" — since the Step 1 survey `rg` (filtered to §20 terms) does not surface it. Sweep for any other bare "fingerprint" in the emission/IR sections and qualify it. Do not touch the harness's content-fingerprint code or docs.

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "IR fingerprint|content fingerprint|0009" .plans/byte-machine-implementation-plan.md .decisions/0009-content-and-ir-fingerprints.md
```
Expected: §20 first-use qualified; the record resolves. Self-review for placeholders/contradictions; fix inline.

- [ ] **Step 5: Commit**

```bash
git add .decisions/0009-content-and-ir-fingerprints.md .plans/byte-machine-implementation-plan.md
git commit -m "docs: decision 0009 — distinguish the content fingerprint from the IR fingerprint"
```

---

## Task 3: Reserved-output-binding scoping note

**Files:**
- Modify: `.plans/byte-machine-implementation-plan.md` (§9.2 reserved-output-binding set; §22.9 "Reject every canonical reserved output binding")

**Interfaces:**
- Produces: the rule "generated-name-safety verification checks only the reserved-set members that exist when the test runs" — member 1 (R6RS source-mode identifiers) in Phase 2; members 2 (`(byte-machine runtime)` exports) and 3 (emitter-template identifiers) in Phase 3. Phase 2 and Phase 3 verifier tasks consume this scoping.

- [ ] **Step 1: Read the two sites**

Run:
```bash
rg -n "reserved-output-binding|reserved output binding|Reject every canonical" .plans/byte-machine-implementation-plan.md
```
Expected: §9.2's three-member set and §22.9's rejection line. Read both.

- [ ] **Step 2: Annotate §9.2**

After the three-member reserved-set list in §9.2, add a dated scoping note (an instruction correction — this is a test-scoping directive):

> Scoping (Milestone 1, decision lineage milestone-1-design.md §3.3): only member 1 (R6RS source-mode syntax/declaration identifiers) is enumerable before Milestone 1 builds anything. Member 2 (`(byte-machine runtime)` exports) exists once the runtime lands; member 3 (canonical source-template identifiers) once the emitter lands. Generated-name-safety verification checks each member from the phase in which it comes to exist; a test must not assert against a member that does not yet exist.

- [ ] **Step 3: Annotate §22.9**

At §22.9's "Reject every canonical reserved output binding under Chez" bullet, append: "— scoped to the members that exist when the test runs (see §9.2 scoping note; Phase 2 covers member 1, Phase 3 members 2–3)."

- [ ] **Step 4: Verify and self-review**

Run:
```bash
rg -n "Scoping \(Milestone 1|scoped to the members that exist" .plans/byte-machine-implementation-plan.md
```
Expected: both annotations present. Confirm they don't contradict §16.2's "generated identifier collisions" rejection (they scope *which* reserved members are checked, not whether collisions are rejected). Fix inline if needed.

- [ ] **Step 5: Commit**

```bash
git add .plans/byte-machine-implementation-plan.md
git commit -m "docs: scope reserved-output-binding checks to members that exist per phase"
```

---

## Self-Review (run after all three tasks)

1. **Spec coverage:** milestone-1-design.md §3 lists three resolutions (§3.1 include collapse, §3.2 fingerprint naming, §3.3 reserved-binding scoping). Task 1 ↔ §3.1, Task 2 ↔ §3.2, Task 3 ↔ §3.3. All covered.
2. **Placeholder scan:** the only `<today's date>` / `<generated-library-name>` tokens are fill-ins the executor resolves at write time; every other line is concrete. No "TBD".
3. **Consistency:** decision 0008 and the §9.6/§9.5/§7.1 edits all say the same thing (importable `.sls`, compose by import). 0009 keeps the harness fingerprint names unchanged and reserves "IR fingerprint" for the new one. Task 3's scoping matches milestone-1-design.md §3.3 (member 1 Phase 2; members 2–3 Phase 3).
