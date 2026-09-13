# Milestone 5 — Slice ①b (declarations and binding) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make callback and span *declarations* real — constructed, guarded, verified, normalized, encoded, and resolved into indexed parser slots — with **no node kind and no callback ever invoked**. Discharges `§25:1576` ("callback declarations and indexed binding") whole.

**Architecture:** Seven tasks over `private/ir.sls`, `graph.sls`, `verify.sls`, `private/normal-ir.sls`, `runtime.sls`, five test files and the mutation suite. The slice's boundary is checkable and Task 7 checks it: `node?`'s disjunct list must still be nine, and no callback may be invoked because none can be.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS), CMake/CTest, the in-repo mutation suite.

---

## Settled by the owner 2026-09-04: `parser-state-name` is Slice ②'s, whole

**`parser-state-name` cannot be answered by the generated lane in this slice.** Measured at `f78b710`:

- `§13:820` requires it to name "the source callback/span node, not a generated internal continuation".
- The `'v2` parser holds `current` as an **integer state id** (`runtime.sls:251`, `compiled-machine-v2-entry-state`). There is no id→name table anywhere on the generated side.
- `normal-machine-debug-map` (`normal-ir.sls:64`) is the id→name map, and it is read at **exactly one site** — `compile.sls:377`, at *emission* time, where it bakes names into emitted error constructors as literals. **It never crosses into the emitted library.**
- The interpreted lane can answer today: `current` is already a node name, or the compound `(name . path)` inside a sequence (`interpret.sls:32-33`).

So the export can ship, but only half of it works, and the differential would compare an answer against a hole.

**Settled: the whole export moves to Slice ②** — not merely its generated half, which is what this plan first proposed. The owner's call is the stronger one and the reason is worth keeping: **a public accessor that answers in one lane and not the other is worse than one that does not exist yet.** It would ship a `§9.3` name whose contract holds only where a caller happens to be, and the differential would compare an answer against a hole rather than failing.

Slice ② is where it belongs — the first slice that *invokes* a callback, and therefore the first with a caller that can witness the value, and the first that must carry an id→name table for the generated lane regardless.

**Consequence for this slice: ①b owes FIVE exports, not six.** `parser-active-span` (decision `0028`) still ships here, because a span *declaration* exists in ①b and the accessor answers `#f` with no active span in either lane — it has no id→name problem. Task 7 records the deferral's other end.

---

## Global Constraints

- **Authority order.** `.plans/milestone-5-design.md` §6, then decisions `0024` (the callback error vocabulary), `0025` (the seam — **read its two dated notes**), `0028` (binding, `busy`, accessors). Where an authority is wrong, **stop and say so**; this milestone has already corrected four such defects, two of them found while writing a plan.
- **Every citation below was measured 2026-09-04 at `f78b710`.** Re-measure before each edit.
- **The constructor/verifier split is decision 0020's, and putting a check in the wrong half is silent.** `ir.sls:510-513` states the consequence verbatim: *"a machine whose field failed construction never exists, so the arm would be unreachable through any public API and its permissive mutation would survive while the suite reported it caught."* Three of ①b's checks are locally evaluable in `make-callback-declaration` and the design assigns all three to the verifier — `§16.2:891` (optional decision callback without a valid default branch), `§16.2:902` (a branch key colliding with `continue`/`pause`), and the callback-kind cross-reference. **They belong in pass 6a. Do not "helpfully" also check them in the constructor.**
- **The mutation suite declares no `SITES` anywhere**, so every `FIND` is pinned at exactly one occurrence in *both* directions. A `FIND` that dies *and* a `FIND` that gains a twin both fail at CMake configure with `pattern occurs N times ... expected 1` — which does not look like a test failure.
- **Do not write a quoted-symbol `cons` in `verify.sls`.** `edge-roles-in-source` (`kind-position-census-tests.sps:365-384`) collects the quoted symbol from **every** `(cons 'SYM …)` form in that file, not only edge-role ones — measured now, **13 occurrences over 12 lines, 12 distinct symbols**, all mapped in `role->positions` (`alternative case continuation digit error fallback false mismatch next nondigit overflow true`). A new pass writing `(cons 'callback name)` adds a 13th role, fails *derived roles equal the mapped roles*, and takes the census pass to a red baseline. **The file's own comment describes the walk as being about edge roles, which it is not.** Verify with `rg -o "\\(cons '" src/byte-machine/verify.sls | wc -l` — **13 today**. Note `rg -c` counts LINES and answers 12; the occurrence count is the one that matters.
- **Fresh identifiers in every copied loop.** `(memq (car es) seen)` (`verify.sls:216`), `(memq fname fseen)` and `(valid-name? (uint-field-name f))` are each a `FIND` at one site. ①b writes two more duplicate-name scans and two more grammar scans; a copy-paste twins those pins.
- **`§16.3`'s pass numbering collides in the file.** `verify.sls:238` heads "PASS 6a" (fields) and `verify.sls:636` heads "PASS 6" (EOF shape). **Refer to passes by function name, never by number.**

---

## File Structure

**Modified — source:**

| File | Change | Task |
| --- | --- | --- |
| `private/ir.sls` | `make-callback-declaration`, `make-span-declaration`, predicates and accessors; two `for-all` guards in `make-machine` | 1 |
| `graph.sls` | re-export both families on the `uint-field` precedent | 1 |
| `verify.sls` | the declaration half of pass 6a; `pass-names` gains two collections | 2 |
| `private/normal-ir.sls` | slot assignment, and the trailing section ①a deferred | 3 |
| `runtime.sls` | `make-parser` binding resolution; the new exports | 4, 5 |
| `compile.sls` | `reserved-member-2` — the mirror `reserved-drift` asserts by **set equality** | 5 |

**Deliberately untouched.** `interpret.sls`'s node dispatch and `private/ir.sls`'s `node?` — ①b adds no node kind, and Task 7 asserts it.

---

## Task 1: The two declaration constructors, and the guards that make them load-bearing

**Files:** `private/ir.sls`, `graph.sls`.

- [ ] **Step 1: Read the precedent in full before writing**

`make-uint-field` (`ir.sls:501-533`) is the exact shape to clone twice: a `tag` constant, `require-symbol` per mandatory symbol, `memq` for a closed set, `(vector TAG …)` in argument order with `source-label` last, and one unguarded `(vector-ref f n)` accessor per part.

`§9.1:284-286` gives the signatures:
```scheme
(make-callback-declaration name kind required? branch-keys default-branch source-label)
(make-span-declaration name data-callback complete-callback source-label)
```

**What belongs here:** `require-symbol` on `name`; `memq` on `kind` over `§10.3:502`'s closed set `(event decision span-data span-complete)`; list-shape on `branch-keys`. **What does not:** anything cross-referential, and anything the verifier owns (Global Constraints).

- [ ] **Step 2: The two `for-all` guards**

Measured: `make-machine`'s collection loop (`ir.sls:548-551`) checks only `list?`; the per-element guards are separate forms at `:552-560`. Add a fourth and fifth in that shape, with `detail` `'callbacks` / `'spans` — **not `'collection`**, because the house test helper asserts who + code + detail.

**Measured, and it is why this task matters:** `machine-callbacks` and `machine-spans` already exist as constructor parameters, vector slots and exported accessors, and `rg` finds **no reader anywhere** — three hits, all inside `ir.sls` itself. ①b is their first reader.

- [ ] **Step 3: `graph.sls`**

Re-export both families with predicate and accessors, on the `uint-field` precedent (`graph.sls:17-18`, `:34`). **Say in the commit that this is a choice between two precedents**: `make-error-declaration` is exported constructor-only and stores a `source-label` it has no accessor for. The owner's §4.12 decline names `uint-field`, so follow it knowingly.

**Measured: zero mutations target `graph.sls`, deliberately** (`SchemeMutationSuite.cmake:7499-7506` records why). These edits get no pin; an expand-time unbound identifier is the witness.

- [ ] **Step 4: Verify** — contract-violation tests for each rejection, asserting who + code + detail. `ctest -R "byte-machine.unit.ir"`.

- [ ] **Step 5: Commit**

---

## Task 2: The declaration half of pass 6a

**Files:** `verify.sls`, and the diagnostic census.

- [ ] **Step 1: Decide where the checks live, and prefer a new pass**

`pass-fields`'s tail (`verify.sls:281`) is `       (pass-field-operands m fs))))` — seven leading spaces, four trailing parens — and it is the verbatim `FIND` of `SchemeMutationSuite.cmake:5158`. **Appending a callback arm inside that `append` breaks the pin.** A separate `pass-declarations` avoids it; if you extend `pass-fields` instead, re-anchor in the same commit.

- [ ] **Step 2: The checks**

`§16.2:885` (duplicate declaration names) and `:886`'s *name* clause acquire two new subjects — measured, `pass-names` (`verify.sls:203-236`) scans node names and error declaration names only, so callback and span names are outside every duplicate-name and grammar check today. `:890` (missing or incompatible callbacks), `:891` (optional decision callback without a valid default branch), `:892` (invalid span callback declarations), `:901`'s declaration share, and `:902`.

**`:902`'s content is already fixed** by `§9.3:421` — *"The symbols `continue` and `pause` are reserved and may not be callback decision branch keys."* Only its code is minted.

**"Incompatible" and "invalid" are derivations, not new definitions** (design §3): `§10.6:586` says a callback node invokes "one named event or decision callback", so a node naming a span-data declaration is *incompatible*; `§10.4:515-516` says a span declares a span-data callback and an optional span-complete callback, so a span naming an event declaration is an *invalid span callback declaration*. **The node half of that is Slice ②'s** — ①b has no nodes.

- [ ] **Step 3: Re-baseline the diagnostic census in this commit**

`test/common/diagnostic-census-tests.sps` derives the code set and the site count from the source and goes red on each new code and each new emission site. Re-baseline **in the commit that moved it** — a census re-baselined in a separate tidying commit is a census nobody checked.

- [ ] **Step 4: Verify** — a positive fixture per new code; the census green at its new numbers; **`rg -o "\\(cons '" src/byte-machine/verify.sls | wc -l` still 13.**

- [ ] **Step 5: Commit**

---

## Task 3: Slot assignment and the trailing section ①a deferred

**Files:** `private/normal-ir.sls`.

- [ ] **Step 1: Read the shape ①a recorded, and resolve its ambiguity**

The comment block at `encode-normal`'s head is the work order: `[... state records...][callback table?][span table?]`, each table wholly inside its own emptiness guard, **the count included**, because an unconditional count is two bytes on every machine and moves all four goldens.

> **⚠ The shape as recorded is ambiguous, and this is a real defect in the authority.** With both tables guarded and neither self-describing, a machine with one callback and no spans and a machine with no callbacks and one span both emit `[count][one record]`. They differ only if a callback record and a span record can never be byte-equal — and both are symbol-shaped, so they can collide. That would falsify the very claim `0025` point 1 rests its rejected alternative on: *declaration identity is fingerprint-visible*.
>
> **Resolution: each present section carries a one-byte section tag before its count**, and the tags live inside the guards. A machine declaring neither still writes zero bytes. `0025` gets a dated note; the comment at `encode-normal`'s head is an instruction and is corrected in place.

- [ ] **Step 2: The tag trap**

`SchemeMutationSuite.cmake:6367` is a bare `FIND [[(put-u8 p 4)]]` with `SITES` defaulted to 1. Measured tag census in `normal-ir.sls`: tag 0 → 4 sites, 1 → 4, 2 → 2, 3 → 1, 4 → 1, 5 → 1, 6 → 1, 7 → 1, 8 → 0. **Use 8 and 9 for the two section tags.** A second `(put-u8 p 4)` fails the suite at declaration.

- [ ] **Step 3: Slot assignment** — `§17:962`. Add `normal-machine-callbacks` / `-spans` on the `normal-machine-fields` precedent.

- [ ] **Step 4: Verify — the oracle is a non-event**

```bash
git diff --stat -- test/fixtures/
rg -n "14095574568398596535|17903327606435836645|15997144668070819532|16999772257989587335" test/
```
Expected: **empty**, and every fingerprint unchanged. All four goldens declare neither a callback nor a span, so a single moved byte means the section is not fully guarded. Plus a new fixture that *does* declare one, whose fingerprint differs from the same machine without it.

- [ ] **Step 5: Commit**

---

## Task 4: Binding resolution in `make-parser`

**Files:** `runtime.sls`.

- [ ] **Step 1: The resolution** — `§9.3:419`, bindings resolved **once** into indexed slots at construction. Decision `0028` fixes the shape: **an unbound optional callback's slot holds a sentinel, short-circuited at the invocation site**, not an installed closure. Nothing invokes anything in ①b, so what ships here is the slot table and its resolution.

- [ ] **Step 2: The four rejections, each with its `§9.4:438` code** — duplicate binding, unknown name, missing required callback, optional decision callback with no `default-branch`. Each driven by a **positive test asserting the code**, never by reading the resolver.

- [ ] **Step 3: The two defaulting rules** (`§9.3:419`: an optional decision callback must declare `default-branch`; other optional callbacks default to `continue`) — **witnessed by observed behaviour**, never by reading the resolver.

- [ ] **Step 4: Verify** — `ctest -R "byte-machine.unit.runtime"`.

- [ ] **Step 5: Commit**

---

## Task 5: The public exports, and the guard that fails in both directions

**Files:** `runtime.sls`, `compile.sls`.

- [ ] **Step 1: The exports**

Measured absent from all of `src/`: `parser-stream-offset`, `parser-user-context`, `make-callback-failure`, `callback-failure?`. Plus `parser-active-span` from decision `0028`. (`parser-state-name` is also absent and stays that way — Slice ②'s.)

**`parser-state-name` is NOT in this list** — settled 2026-09-04, it is Slice ②'s whole (see the head of this plan). Five exports here, and `parser-active-span` is the sixth name only in the sense that it is new; it ships because it answers `#f` in both lanes with no active span.

`make-callback-failure` takes a symbolic code satisfying `§9.3:423`'s portable ASCII grammar and an opaque detail. `callback-continue` and `callback-pause` already exist (`runtime.sls:35-36`) — check whether they are exported.

- [ ] **Step 2: `reserved-member-2`, and this is the trap ①a wrote down for this moment**

`test/common/reserved-drift-tests.sps:37-40` asserts **set EQUALITY** — *"the declared set equals the live runtime export set"* — between `reserved-member-2` (`compile.sls:47-61`) and `(byte-machine runtime)`'s live exports. It reddens in **both** directions. **Every export added in Step 1 must join `reserved-member-2` in the same commit.** ①a's own plan records this as the obligation ①b inherits.

- [ ] **Step 3: Verify** — `ctest -R "drift"`; both drift lanes green.

- [ ] **Step 4: Commit**

---

## Task 6: The slice's oracle

- [ ] **Step 1: Build the machine the oracle needs**

*A machine that declares callbacks and spans and contains no callback or span node* must verify, normalize, emit and run **identically in both lanes**, with the differential's existing value tuple unchanged. That is what proves declarations are separable from nodes, and **no later slice can establish it retroactively** — once nodes exist, the property is unobservable.

- [ ] **Step 2: Assert the tuple is unchanged**, not merely that both lanes agree. A differential that compares two lanes which both changed the same way passes while the contract moved.

- [ ] **Step 3: Commit**

---

## Task 7: Totals, the ledger, and the boundary

- [ ] **Step 1** — `EXPECTED_PASSES` / `EXPECTED_MUTATIONS` (`SchemeMutationSuite.cmake:1004-1005`, currently 52 / 378) move in the same commit as the declarations, or the run `FATAL_ERROR`s. Ledger paragraph above the current top.

- [ ] **Step 2: Assert the boundary**

```bash
rg -n "define \(node\? " -A4 src/byte-machine/private/ir.sls
ctest --test-dir build/dev -R "byte-machine.unit.kind-position-census" --output-on-failure
rg -n "\(cons '" src/byte-machine/verify.sls | grep -v ";;" | wc -l
```
Expected: `node?` still lists **nine** disjuncts; "the same nine kinds" green; the `cons` count in CODE still **12 lines / 13 occurrences**.

**Two corrections to this step, both made during execution.** It first asserted `interpret.sls` is untouched — too broad: the slice legitimately adds a `callback-decls` message to the op interface, which is not node dispatch. The boundary is *no node kind*, and `node?` is what states it. And the `cons` count must exclude comment lines: a bare textual count answers 15 because two of them are in the comment forbidding them, and the census reads the file with `read`, which strips comments. **Note the test name is `unit.kind-position-census`** — `-R kind-position.chez.source` matches nothing and reports silence, which Slice ①a's own probe nearly mistook for proof.

- [ ] **Step 3: Record what ② inherits, in a place ② will read** — not only in a commit message. `AGENTS.md`: a deferral needs both ends.
  1. **`parser-state-name`, whole** (owner, 2026-09-04). Slice ② must carry an id→name table into the generated lane; `normal-machine-debug-map` (`normal-ir.sls:64`) is the map and `compile.sls:377` is the only place it is read today, at emission time.
  2. The node-side share of `§16.2:890` and `:901`.
  3. The generated lane's `busy` guard, which needs a caller to witness.

- [ ] **Step 4: Commit**

---

## Verification

`release` green, the mutation suite at its new declared totals, and three things that are checkable rather than asserted:

1. **No golden moved.** All four declare neither a callback nor a span, so Task 3's section must write zero bytes for them. This is the gate Slice ①a paid for.
2. **`node?` is still nine disjuncts.** ①b adds no node kind.
3. **`(cons '` in `verify.sls` still occurs 13 times**, so the position census's role derivation still sees exactly the twelve distinct roles it maps.
