# Milestone 3 Slice ① — Byte Classes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land byte-set, byte-range and byte-complement matchers plus the
`ascii-bytes` helper, canonicalized to subsets of `0..255` and lowered to one
normalized transition per byte, with byte-class overlap verification and
all-256 coverage in both executors and both execution lanes.

**Architecture:** One canonicalization function — `matcher-bytes`, in
`(byte-machine private ir)` — is the single place a matcher's byte set is
computed. It lands *first*, replacing the three existing consumers of the
unguarded `exact-byte-matcher-byte` accessor while exact-byte is still the only
matcher kind, so the change is provably behaviour-preserving against the three
pinned IR fingerprints and both committed goldens. Only then do the new matcher
constructors exist. No new node kind, no new normalized-IR encoding arm, no
emitter change, no ABI movement.

**Tech Stack:** R6RS Scheme (Chez 10.4.1), CMake/CTest lanes, the in-repo
mutation suite (`test/support/cmake/SchemeMutationSuite.cmake`).

Design authority: [milestone-3-design.md](./milestone-3-design.md) §5 (Slice ①),
§3, §4.1, §4.4, §4.5, and its appendix; decisions
[0014](../decisions/0014-byte-classes-expand-per-byte.md) and
[0017](../decisions/0017-degenerate-shapes-are-contract-violations.md); parent
plan [byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
§9.1:291-294, :299, :318, :322; §10.6:536-540; §16.2:893; §16.3:921;
§16.4:937-943; §17:956, :966; §19.2:1009; §22.7:1299-1301; §25:1527-1528,
exit :1537.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Baselines to hold, measured 2026-08-29 on `main` = `a9de657`** (Darwin
  arm64, Chez 10.4.1): `ctest --preset release` **72/72**, `--preset pr`
  **72/72**, `--preset no-scheme` **8/8**, Scheme mutation suite **38 passes /
  165 mutations**, CMake mutation suite **1 pass / 72 mutations**. Every task
  ends with these — plus that task's own additions — green.
- **The three pinned IR fingerprints and both committed goldens must not
  move.** `4236938459847922092` (one-byte), `9098559711816935340`
  (node-routing eof-machine), `15725897457025557005` (pause-machine);
  `test/fixtures/generated-one-byte.golden.sls` and
  `test/fixtures/generated-pause.golden.sls`. Per-byte expansion is a strict
  no-op on the shipped layout (decision 0014), so byte-identity is a real
  independent oracle here, not a re-baseline. Task 1 asserts it explicitly.
- **The encoding-format version byte stays `1`** (`normal-ir.sls:129`
  `(put-u8 p 1)`); no new state-kind tag byte; no `/v3` ABI.
- **Chez floor 10.4.1, CMake floor 3.26. No new dependencies** — only `(rnrs)`
  and in-repo libraries. No SRFI, no package manager.
- **Libraries are inline R6RS `.sls`, programs are `.sps`, and no Scheme file
  may `include` another** (decision 0006).
- **Exit-status vocabulary is exactly 0, 1, 2, 3.** This slice adds no new exit
  path; every task still re-runs the *whole* mutation suite, not only its own
  new pass (AGENTS.md: a new route to an existing status can silently disarm an
  old mutation).
- **Mutation discipline** (AGENTS.md): every decision gets a mutation whose
  catch asserts a **measured** failure signature — `EXPECT_STATUS` **plus**
  `EXPECT_OUTPUT_MATCHES` — never a bare nonzero exit. A pin must resolve to one
  `(case, check)` pair: the FAIL grammar is
  `byte-machine-harness: FAIL <group>.<case>: <what> -- <detail>`, so pin a
  case-name tail plus the check label, and use no regex metacharacters
  (CMake `MATCHES` is a real regex; `(`, `)`, `.` are metacharacters). A
  mutation's witness must live in the program named by its own `SPEC` lane.
  `EXPECT_SURVIVES` only for the demonstrated-unwitnessable, with a written
  reason.
- **`SITES` defaults to 1 and is asserted exactly** (`MutationRunner.cmake:98`).
  A `FIND` whose text an edit has changed makes the suite fail with
  "found 0, expected 1" — so a pin whose line this slice edits is re-anchored in
  **the same commit** as the edit.
- **Predicted counts are arithmetic to check, never facts to write down.**
  Re-measure release/pr, no-scheme and both mutation totals before any number
  enters `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`
  (`SchemeMutationSuite.cmake:554-555`), the CHANGELOG, a decision record, or a
  design document. Prediction for this slice: release/pr **76** (72 + 4 new
  lanes), Scheme mutation **41 passes / 180 mutations** (38 + Passes 42, 43, 44;
  165 + 2 + 5 + 3 + 2 + 2 + 1, with two pins re-anchored rather than added).
  That arithmetic is a thing to check against a run, not a thing to write into a
  record. Milestone 2 Slice ③ predicted ~145-146 mutations and closed at 165;
  design §9 calls sizing a floor, not an estimate.
- **Completion sentinels are mandatory.** No suite declares an expected case or
  check count; `harness-summary` reports only what ran, so an exhaustive loop
  that never executes **passes vacuously**. Every new 256-loop asserts a
  separate sentinel that only a completed loop can satisfy — the
  `last-byte`/`255` shape at `differential-eof-tests.sps:46-54`.
- **Lane and manifest bookkeeping is fatal-on-error.** Every new test program
  needs a source + AOT pair, each with a `TIMEOUT` and a unique five-segment
  lowercase name matching `^byte-machine\.([a-z0-9-]+){4}$`
  (`cmake/ByteMachineTesting.cmake:64`); feature segments must not begin or end
  with a hyphen; any new fixture `.sls` appears in **both** lanes' `SOURCES`;
  basenames are unique within one lane. The AOT lane resolves libraries only
  through objects compiled from its own `SOURCES`. A new `.sls` changes the
  lane's content fingerprint, which is recomputed at build time from `SOURCES`
  and verified at `harness-begin` — no committed fingerprint to update by hand.
- **`.superpowers/sdd/` is git-ignored: never `git add` the ledger.**
- Conventional Commits; run the suite before every commit; match the touched
  file's comment style, em-dash convention and `mode` vocabulary.
- Commands:
  - build: `make build`
  - full suite: `make test-all`
  - one lane: `ctest --preset release -R '<lane>' --output-on-failure`
  - no-scheme: `cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure`
  - Scheme mutation totals: `ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep 'suite complete'`

---

## §0 Design calls locked by this plan

These resolve the freedoms design §5 leaves to writing-plans. Implementers do
not re-litigate them; a **measured** contradiction is a plan defect to record in
the ledger and fix (repo precedent).

**D1 — The canonicalization spine lives in `(byte-machine private ir)` and is
named `matcher-bytes`.** Its three consumers (`verify.sls`, `normal-ir.sls`,
`interpret.sls`) all already import that library, so no new library, no new
CMake `SOURCES` entry, no new basename and no new lane manifest are needed.
Sharing it across the interpreter and the normalizer is *correct here*:
§18:970-972's independence rule is specifically about "progress inside a
high-level source node, such as a sequence prefix or a pending span-end
substep", which is Slice ②'s problem. A matcher's byte set is not
interpreter-private state, and design §1 calls for exactly "one canonicalization
step".

**D2 — `matcher-bytes` returns a proper list of exact integers, ascending and
duplicate-free.** A proper list matches §9.1:318's collection convention,
composes with `memv` and `list-sort`, and needs no adapter. It is *not* a
256-entry vector or a bitmap: decision 0014 point 4 forbids a class table, and a
membership vector is one. Ascending-and-deduplicated is load-bearing — it is
what keeps the normalizer's ascending-by-byte transition sort a **total** order
(decision 0014's consequences), and what stops a duplicate byte inside one
byte-set matcher from being read as that node overlapping itself.

**D3 — `pass-overlap` reports one diagnostic per colliding *pair* of cases, in
caller order.** Not one per shared byte: a complement and a set can share 200
bytes, and §16.4:937-943 wants one finding per decision, not 200 copies of it.
The code stays `'overlapping-cases` (design §4.5 — reuse the shipped code with a
broadened message; no new diagnostic code in this slice).

**D4 — `ascii-bytes` rejects only non-ASCII, and does not reject the empty
string.** §9.1:299 gives the signature and one rejection rule. `ascii-bytes` is
a helper, not a matcher constructor, so decision 0017 point 1's empty-set
rejection does not apply to it: `(ascii-bytes "")` returns `'()`, and
`(make-byte-set-matcher (ascii-bytes ""))` is where the contract violation
fires. It returns bytes in string order with no de-duplication, for decision
0017 point 3's reason (no construction-time semantic transform).

**D5 — `graph.sls` gains the four construction calls plus the four matcher
predicates and their accessors, and `matcher?`. It does not gain machine
accessors, and `matcher-bytes` stays private.** Design §5's rider says adding
"the new matcher predicates and accessors" closes `graph-tests.sps:5`'s reach
into `(byte-machine private ir)`. **That is overstated and this plan does not
follow it that far:** line 5 imports `machine?`, `machine-entry` and
`machine-default-eof-error` — *machine* accessors, which no matcher export
supplies. Adding those to the façade would widen the public API past §9.1's
normative construction list on a "for consistency" argument that design §8
explicitly rejects for `source-label`. So `graph-tests.sps:5` keeps its `only`
reach, and Task 2 records why in a comment at that line. `matcher-bytes` is not
in §9.1's list either and stays a private spine.

**D6 — The proving fixtures live in one shared library,
`test/support/harness/byte-machine/test/class-machine.sls`, exporting five
machine constructors.** One `.sls` in both new lane pairs' `SOURCES`, written
once, driven by both the unit and the differential programs — the shape
`eof-machine.sls` and `pause-machine.sls` already established.

**D7 — Two new programs, four new lanes, not one program and two lanes.**
`byte-class-interpret-tests.sps` asserts **absolute** outcomes over all 256
bytes through the interpreter; `differential-byte-class-tests.sps` asserts
interpreter ≡ generated. Both are required: a differential-only program cannot
witness a defect in `matcher-bytes`, because both executors route through it and
would be wrong *identically*, leaving the comparison green. The absolute
program is where canonicalization mutations are caught.

**D8 — Design §5's six numbered items map to this plan's seven tasks as
follows.** Read this before concluding a task is empty.

| design §5 item | task |
| --- | --- |
| 1 — canonicalization spine, behaviour-preserving | Task 1 |
| 2 — the constructors, `ascii-bytes`, widened guard, degenerate rejections | Task 2 |
| 3 — rewritten `pass-overlap` | Task 3 |
| 4 — normalizer lowering; emitter zero change recorded | Task 1 writes the expansion (behaviour-preserving while every set is a singleton); **Task 4** proves it against class fixtures and records the emitter's zero change |
| 5 — interpreter matcher dispatch through the canonical form | **Task 1** (it is one of the three consumers). Task 5 adds no interpreter code, only the fixtures and lanes that exercise it |
| 6 — all-256 class, complement and ASCII lanes in both executors and both execution lanes | Tasks 5 and 6 |
| — | Task 7: close-out, measured totals, records |

**D9 — Two mutation pins die in this slice, not one.** Design §5 names
`SchemeMutationSuite.cmake:2967` (`(if (memv b seen)`, deleted by the
`pass-overlap` rewrite). It does **not** name `SchemeMutationSuite.cmake:3267`
(Pass 34's `((= byte (exact-byte-matcher-byte (byte-case-matcher (car cs))))`),
which dies the moment `interpret.sls:46` routes through the canonical form —
i.e. in Task 1. Both are re-anchored in Task 1, each a re-**measurement** of the
pin's failure signature rather than a text edit.

**D10 — The overlap pin is re-anchored onto a helper's body, so it is
re-anchored once and not twice.** `byte-sets-overlap?` is introduced in Task 1
with the exact body Task 3 keeps; Task 3 changes only the loop that calls it.
Pinning the helper rather than the loop keeps Task 3 from having to re-measure
the same decision a second time.

**D11 — `pass-reachability` and `pass-zero-progress` are not touched.** Their
walks are matcher-agnostic (they read edges and modes, never matchers), and
§25:1533's cycle bullet is about sequences. Editing them would break their
mutation pins for nothing: the `pass-zero-progress` guard line is pinned twice
with the **same** `FIND` (`SchemeMutationSuite.cmake:2973` and `:3183`) and
`SITES` is asserted exactly, so any change to that line is a hard failure in two
places.

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `src/byte-machine/private/ir.sls` (modify) | `matcher-bytes` spine + guarded `exact-byte-matcher-byte`; then the three new matcher kinds, `matcher?`, `ascii-bytes`, the widened `make-byte-case` guard | 1, 2 |
| `src/byte-machine/graph.sls` (modify) | façade export list **and** `only` import list gain the four construction calls, four predicates, their accessors, `matcher?` | 2 |
| `src/byte-machine/verify.sls` (modify) | `pass-overlap` over canonical sets; then per-colliding-pair diagnostics | 1, 3 |
| `src/byte-machine/private/normal-ir.sls` (modify) | per-byte expansion at the lowering site; `only` import swaps `exact-byte-matcher-byte` for `matcher-bytes` | 1 |
| `src/byte-machine/compile.sls` | **no change** — confirmed and recorded in Task 4 | — |
| `src/byte-machine/interpret.sls` (modify) | membership through the canonical form | 1 |
| `src/byte-machine/runtime.sls` | **no change** | — |
| `test/common/ir-tests.sps` (modify) | spine + constructor local-shape cases | 1, 2 |
| `test/common/graph-tests.sps` (modify) | the façade builds a class machine with no private import | 2 |
| `test/common/verify-tests.sps` (modify) | mixed-kind overlap; per-pair diagnostic count | 3 |
| `test/common/normal-ir-tests.sps` (modify) | per-byte expansion, ordering, dedup, vacuous complement | 4 |
| `test/support/harness/byte-machine/test/class-machine.sls` (create) | the five shared proving machines | 5 |
| `test/common/byte-class-interpret-tests.sps` (create) | absolute all-256 outcomes through the interpreter | 5 |
| `test/common/differential-byte-class-tests.sps` (create) | interpreter ≡ generated over all 256, five machines | 6 |
| `test/CMakeLists.txt` (modify) | four new lanes | 5, 6 |
| `test/support/cmake/SchemeMutationSuite.cmake` (modify) | two re-anchors; new Pass 42 (ir) and Pass 43 (byte-class); Pass 33/35 additions; totals | 1-6 |
| `CHANGELOG.md`, `docs/plans/milestone-3-design.md` (modify) | measured close-out | 7 |

---

## Task 1: The canonicalization spine, behaviour-preserving

**Files:**
- Modify: `src/byte-machine/private/ir.sls:17` (export list), `:39-46` (matcher section)
- Modify: `src/byte-machine/verify.sls:119-133` (`pass-overlap`)
- Modify: `src/byte-machine/private/normal-ir.sls:19` (`only` import), `:100-106` (lowering)
- Modify: `src/byte-machine/interpret.sls:46`
- Test: `test/common/ir-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake:554-555, 2965-2968, 3264-3268`

**Interfaces:**
- Produces:
  - `(matcher-bytes m)` → proper list of exact integers, ascending, no
    duplicates. Raises a `byte-machine-contract-condition?` with code
    `invalid-argument` and detail `matcher` for anything that is not a matcher.
    Exported from `(byte-machine private ir)`; **not** from `(byte-machine graph)`.
  - `(exact-byte-matcher-byte m)` now raises the same condition for a non-exact-byte
    argument instead of returning `(vector-ref m 1)` blindly.
  - `(byte-sets-overlap? a b)` → boolean, internal to `verify.sls`.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing tests**

Append these two groups to `test/common/ir-tests.sps`, immediately before the
final `(harness-finish)` line:

```scheme
(harness-group "matcher canonicalization"
  (lambda ()
    (harness-case "an exact-byte matcher canonicalizes to its one-element set"
      (lambda ()
        (check-equal "set" (matcher-bytes (make-exact-byte-matcher 7)) '(7))))
    (harness-case "the low and high ends of the byte universe canonicalize"
      (lambda ()
        (check-equal "zero" (matcher-bytes (make-exact-byte-matcher 0)) '(0))
        (check-equal "255" (matcher-bytes (make-exact-byte-matcher 255)) '(255))))
    (harness-case "canonicalizing a foreign vector is a contract violation"
      (lambda ()
        (check-raises "refused"
                      byte-machine-contract-condition?
                      (lambda () (matcher-bytes (make-edge 'stop 'advance))))))))

(harness-group "the exact-byte accessor is tag-guarded"
  (lambda ()
    (harness-case "the exact-byte accessor refuses a foreign vector"
      (lambda ()
        (check-raises "refused"
                      byte-machine-contract-condition?
                      (lambda () (exact-byte-matcher-byte (make-edge 'stop 'advance))))))))
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
ctest --preset release -R 'byte-machine.unit.ir.chez.source' --output-on-failure
```

Expected: exit 1, and the output contains
`Exception: variable matcher-bytes is not bound`. (An unbound identifier in a
program is a load failure, not an assertion failure — that is the expected
first red.)

- [ ] **Step 3: Add the spine to `ir.sls`**

In `src/byte-machine/private/ir.sls`, replace line 17

```scheme
          make-exact-byte-matcher exact-byte-matcher? exact-byte-matcher-byte
```

with

```scheme
          make-exact-byte-matcher exact-byte-matcher? exact-byte-matcher-byte
          matcher-bytes
```

Then replace the whole exact-byte matcher section (lines 39-46) with:

```scheme
  ;; --- exact-byte matcher ---
  (define exact-byte-matcher-tag (tag 'byte-machine-exact-byte-matcher))
  (define (make-exact-byte-matcher byte)
    (unless (and (integer? byte) (exact? byte) (<= 0 byte 255))
      (byte-machine-contract-violation 'make-exact-byte-matcher 'invalid-argument 'byte))
    (vector exact-byte-matcher-tag byte))
  (define (exact-byte-matcher? x) (tagged? exact-byte-matcher-tag x))
  ;; Tag-guarded: an unguarded (vector-ref m 1) on a matcher of another kind
  ;; pulls a byte LIST out of the wrong slot and fails far away, inside
  ;; arithmetic or a sort predicate, rather than at the contract boundary.
  (define (exact-byte-matcher-byte m)
    (unless (exact-byte-matcher? m)
      (byte-machine-contract-violation 'exact-byte-matcher-byte 'invalid-argument 'matcher))
    (vector-ref m 1))

  ;; --- matcher canonicalization (parent §10.6:538, §16.3:921; decision 0014) ---
  ;; Every matcher denotes a subset of the closed byte universe 0..255. This is
  ;; the one place that subset is computed: the verifier's overlap analysis, the
  ;; normalizer's per-byte lowering and the interpreter's membership test all
  ;; call it, so a matcher kind taught here is understood by all three at once.
  ;; The result is a proper list of exact integers, ascending and duplicate-free
  ;; -- ordering and de-duplication are what keep the normalizer's
  ;; ascending-by-byte transition sort a TOTAL order (decision 0014).
  (define (matcher-bytes m)
    (cond ((exact-byte-matcher? m) (list (exact-byte-matcher-byte m)))
          (else (byte-machine-contract-violation 'matcher-bytes
                                                 'invalid-argument 'matcher))))
```

- [ ] **Step 4: Run the test and confirm it passes**

```bash
ctest --preset release -R 'byte-machine.unit.ir.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 5: Replace the verifier's consumer**

In `src/byte-machine/verify.sls`, replace lines 119-133 with:

```scheme
  ;; PASS 3: overlap within a dispatch node, over canonical matcher byte sets
  ;; (§16.2:893, §16.3:921). Two cases overlap when their canonical sets share
  ;; any byte; an exact-byte matcher is the one-element case of the same rule.
  (define (byte-sets-overlap? a b)
    (and (pair? a) (or (and (memv (car a) b) #t) (byte-sets-overlap? (cdr a) b))))
  (define (pass-overlap m)
    (apply append
           (map (lambda (n)
                  (if (byte-dispatch-node? n)
                      (let loop ((cs (byte-dispatch-node-cases n)) (seen '()) (out '()))
                        (if (null? cs) out
                            (let ((bs (matcher-bytes (byte-case-matcher (car cs)))))
                              (loop (cdr cs) (append bs seen)
                                    (if (byte-sets-overlap? bs seen)
                                        (cons (make-diagnostic 'overlapping-cases (node-name n)
                                                               "two cases match the same byte") out)
                                        out)))))
                      '()))
                (machine-nodes m))))
```

- [ ] **Step 6: Replace the normalizer's consumer**

In `src/byte-machine/private/normal-ir.sls`, replace line 19

```scheme
                byte-case-matcher byte-case-edge exact-byte-matcher-byte
```

with

```scheme
                byte-case-matcher byte-case-edge matcher-bytes
```

Then replace lines 100-106 with:

```scheme
                                     ((byte-dispatch-node? n)
                                      (let ((trs (list-sort (lambda (a b) (< (car a) (car b)))
                                                   ;; One transition per byte of each case's
                                                   ;; canonical set (decision 0014): the encoding,
                                                   ;; its tag bytes and its format version byte are
                                                   ;; unchanged, and every machine expressible
                                                   ;; before Milestone 3 encodes identically.
                                                   (apply append
                                                     (map (lambda (c)
                                                            (let ((e (byte-case-edge c))
                                                                  (bs (matcher-bytes (byte-case-matcher c))))
                                                              (map (lambda (b)
                                                                     (list b (id-of (edge-target e))
                                                                           (edge-mode e)))
                                                                   bs)))
                                                          (byte-dispatch-node-cases n)))))
```

The three lines that follow (`(fb (byte-dispatch-node-fallback n)))` and the
`(vector ns-tag 'dispatch i trs ...)` form) are unchanged.

- [ ] **Step 7: Replace the interpreter's consumer**

In `src/byte-machine/interpret.sls`, replace line 46

```scheme
                  ((= byte (exact-byte-matcher-byte (byte-case-matcher (car cs))))
```

with

```scheme
                  ((memv byte (matcher-bytes (byte-case-matcher (car cs))))
```

- [ ] **Step 8: Run the whole suite and confirm nothing moved**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 72`.

```bash
git status --porcelain -- test/fixtures/
```

Expected: **no output.** The two committed goldens are byte-identical, which the
determinism lanes have just re-asserted against emission; an empty status is the
independent confirmation that nothing was regenerated to make them agree.

```bash
ctest --preset release -R 'byte-machine.unit.normal-ir' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2` — the three pinned
fingerprints (`4236938459847922092`, `9098559711816935340`,
`15725897457025557005`) still hold.

> **Disposition, 2026-08-29 (Task 7 close-out).** This step's own instruction
> — run the whole mutation suite here, as part of Step 8 — has closed and is
> dispositioned rather than reworded. Run in this step's literal position,
> *before* Steps 9-10 re-anchor the two dying pins and add Pass 42, `make
> test-all` fails on the mutation lane: Steps 3, 5-7 already deleted `(if
> (memv b seen)` and the exact-byte `=` comparison those two pins' `FIND`
> text names, so `SITES` resolves to 0 instead of the asserted 1 and the
> suite raises a stale-`FIND` configure error — exactly what this task's own
> introduction predicts for an un-reanchored pin. The implementer completed
> Steps 9-10 before running Step 8's `make test-all`, which is what shipped
> (commits `3ea0c98`..`dd50a16`; task-1-report.md). The plan's own step
> order was not corrected, because Step 8's instruction has already been
> discharged by the branch that noticed the ordering problem; a future
> re-use of this plan should read Steps 9-10 before Step 8's suite run.

- [ ] **Step 9: Re-anchor the two dying mutation pins**

In `test/support/cmake/SchemeMutationSuite.cmake`, replace the whole Pass 33
overlap mutation — the `byte_machine_mutation(` block at lines 2964-2968, the
one whose `LABEL` is `"verify: overlap check treats every byte as distinct"` and
whose `FIND` is `(if (memv b seen)` — with:

```cmake
# Re-anchored in Milestone 3 Slice ① Task 1: pass-overlap now compares canonical
# matcher BYTE SETS, so the old `(if (memv b seen)` line no longer exists. The
# decision is unchanged -- two cases matching the same byte must be reported --
# and it is pinned on the helper's body rather than on the loop, so Slice ①
# Task 3's per-colliding-pair rewrite of the loop leaves this pin standing.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: two cases sharing a byte are never found to overlap"
  FIND [[(and (pair? a) (or (and (memv (car a) b) #t) (byte-sets-overlap? (cdr a) b)))]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "same byte overlap: overlapping-cases")
```

And replace Pass 34's first mutation — the `byte_machine_mutation(` block at
lines 3264-3268, `LABEL "interpret: dispatch matches every byte to the first
case"` — with:

```cmake
# Re-anchored in Milestone 3 Slice ① Task 1: the interpreter's membership test is
# now `memv` over the canonical byte set, not `=` against a single exact byte.
# Same decision, same witness, same signature -- re-measured, not merely retyped.
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch matches every byte to the first case"
  FIND [[((memv byte (matcher-bytes (byte-case-matcher (car cs))))]]
  REPLACE [[(#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no byte in 1..255 misbehaved")
```

- [ ] **Step 10: Add Pass 42 — the spine's own decisions**

Append, immediately before the `byte_machine_mutation_totals(...)` block at the
end of `test/support/cmake/SchemeMutationSuite.cmake`:

```cmake
# --- Pass 42: matcher canonicalization and the tag-guarded accessor (M3 Slice
# ① Task 1) -----------------------------------------------------------------
#
# ir-tests.sps is the first program to reach (byte-machine private ir)'s
# canonicalization spine directly, and no pass has ever mutated ir.sls: every
# earlier pass reaches it only through a consumer. The first mutation drops the
# exact-byte arm of matcher-bytes, so an exact matcher canonicalizes to the
# contract violation instead of its one-element set; the second removes the
# accessor's tag guard, so a foreign vector reads slot 1 and returns instead of
# raising -- the exact defect design §5 says must not be allowed to reach
# pass-overlap or list-sort. Verify command uses both library roots, an empty
# object guard, the ir program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/ir-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an exact-byte matcher does not canonicalize to its own byte"
  FIND [[(cond ((exact-byte-matcher? m) (list (exact-byte-matcher-byte m)))]]
  REPLACE [[(cond ((and #f (exact-byte-matcher? m)) (list (exact-byte-matcher-byte m)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "one-element set: set")

# Every FIND in this plan is written WITHOUT leading whitespace and matched as a
# substring, so an indentation that drifts from the plan's code block cannot turn
# the pin into a "found 0, expected 1" configure failure. Each is unique in its
# file; confirm with `grep -c` before adding the mutation.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: the exact-byte accessor reads slot 1 of any vector"
  FIND [[(byte-machine-contract-violation 'exact-byte-matcher-byte 'invalid-argument 'matcher)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refuses a foreign vector: refused")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

Then update the declared totals at `SchemeMutationSuite.cmake:554-555`:

```cmake
# Milestone 3 Slice ① Task 1 adds Pass 42 (matcher canonicalization and the
# tag-guarded accessor) with two mutations, and re-anchors two existing pins
# without adding either. Passes become 38 + 1 = 39; mutations 165 + 2 = 167.
set(EXPECTED_PASSES 39)
set(EXPECTED_MUTATIONS 167)
```

> **Disposition, 2026-08-29 (Task 7 close-out).** This step's own worked
> example — the first mutation's `REPLACE`, `(cond ((and #f
> (exact-byte-matcher? m)) ...))` — is dispositioned rather than corrected,
> because its work (proving Pass 42's first decision) has closed under a
> stronger mutation than the one shown here. `(and #f ...)` routes every
> input through the same `else` arm regardless of matcher kind, so it is
> caught by a **raise**, not by the comparison this file's own Global
> Constraints and AGENTS.md's "prefer a mutation caught by a failed
> comparison over one caught by a raise" rule ask for — and review found it
> proved only "`matcher-bytes` returned something," not this mutation's own
> `LABEL`, "does not canonicalize to its own byte": a mutant that returned
> the *wrong* byte would have survived it. It also made the sibling
> "canonicalizing a foreign vector is a contract violation" case pass for
> the wrong reason, since that case expects exactly the `else` arm this
> mutant forces unconditionally. Shipped instead (commit `dd50a16`,
> `SchemeMutationSuite.cmake`'s Pass 42 first mutation): `REPLACE (list
> (exact-byte-matcher-byte m)) (list 0)`, comparison-caught, pinned to the
> measured `"one-element set: set -- expected \(7\), got \(0\)"`.

- [ ] **Step 11: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: exactly one line,
`byte-machine-spec: scheme mutation suite complete (39 passes, 167 mutations)`.
Any `UNCAUGHT` line is a finding to strengthen the test, never to loosen the
mutation. If either declared total disagrees with what the run reports, the
number in `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` is wrong — fix it from the
measurement, never the other way round.

- [ ] **Step 12: Confirm no other pin references an edited line**

```bash
grep -c 'exact-byte-matcher-byte' test/support/cmake/SchemeMutationSuite.cmake
```

Expected: `1` — the Pass 42 accessor mutation's `FIND`. (Pass 34's old
occurrence is gone; Pass 42's new one is the only remaining reference.)

> **Disposition, 2026-08-29 (Task 7 close-out); corrected in Fix wave 1,
> 2026-08-29.** This step's expected count has closed against a measurement
> of `3`, not `1`, and is dispositioned rather than reworded to `3`. The
> original text here derived the `3` from what the plan says Step 10 adds,
> rather than from the file — corrected below by reading the file itself.
>
> `grep -n 'exact-byte-matcher-byte' test/support/cmake/SchemeMutationSuite.cmake`
> on the shipped tree returns three hits, none of them a `FIND`/`REPLACE`
> pair on the same mutation:
>
> 1. `:3989` — `FIND [[(list (exact-byte-matcher-byte m))]]`, the *other*
>    Pass 42 mutation this same Step 10 block adds (`LABEL "ir: an exact-byte
>    matcher does not canonicalize to its own byte"`), re-anchored to its
>    comparison-caught form by commit `dd50a16` (Task 1's own fix wave —
>    see the Step 10 disposition immediately above).
> 2. `:4005` — `FIND [[(byte-machine-contract-violation
>    'exact-byte-matcher-byte 'invalid-argument 'matcher)]]`, this step's own
>    accessor mutation (`LABEL "ir: the exact-byte accessor reads slot 1 of
>    any vector"`), unchanged since it landed in `3ea0c98`. Its `REPLACE` is
>    `[[#f]]` and contains no such identifier.
> 3. `:4076` — a **prose comment**, `# exact-byte-matcher-byte: dropping the
>    tag check lets the accessor read ...`, introducing the four-mutation
>    tag-guard fix wave for the other class-matcher accessors. `git blame`
>    dates this line to commit `c426b5d` (2026-08-29 16:15:50) — Task 2's
>    own fix wave, not Step 10.
>
> So at Step 10/12's landing (`3ea0c98`, then `dd50a16` — both within Task 1)
> the count was **2**: one `FIND` per Pass 42 mutation, each containing the
> identifier once. It became **3** only when Task 2's fix wave added the
> comment at `:4076`, a task later. The `3` recorded above is correct as a
> present-day measurement; what was wrong was reasoning it from the plan's
> own Step 10 text instead of reading the tree. This step's check *intent* —
> no other pin still references code this task deleted — is still
> discharged: this file's `SITES` argument is asserted exactly per mutation,
> so a pin left pointing at deleted text is a hard configure-time failure
> regardless of what a whole-file `grep -c` reports.

- [ ] **Step 13: Commit**

```bash
git add src/byte-machine/private/ir.sls src/byte-machine/verify.sls src/byte-machine/private/normal-ir.sls src/byte-machine/interpret.sls test/common/ir-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "refactor: route every matcher consumer through one canonicalization spine

matcher-bytes in (byte-machine private ir) becomes the single place a matcher's
subset of 0..255 is computed, and exact-byte-matcher-byte gains the tag guard it
never had. The verifier's overlap pass, the normalizer's lowering site and the
interpreter's membership test all call it. Behaviour-preserving: an exact-byte
matcher is the one-element case, so all three pinned IR fingerprints and both
committed goldens come out byte-identical (decision 0014).

Re-anchors two mutation pins whose FIND text this change deletes, and adds
Pass 42 over ir.sls itself, which no pass had ever mutated."
```

---

## Task 2: The matcher constructors, `ascii-bytes`, and the widened guard

**Files:**
- Modify: `src/byte-machine/private/ir.sls` (export list; matcher section; `make-byte-case` guard)
- Modify: `src/byte-machine/graph.sls:6-12` (export list **and** `only` import list)
- Test: `test/common/ir-tests.sps`, `test/common/graph-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 42 additions; totals)

**Interfaces:**
- Consumes: `matcher-bytes`, `exact-byte-matcher?`, `byte-machine-contract-violation` (Task 1).
- Produces:
  - `(make-byte-set-matcher bytes)` → matcher. `bytes` is a non-empty proper
    list of exact integers `0..255`; duplicates are legal. Rejects otherwise
    with detail `bytes`.
  - `(byte-set-matcher? x)`, `(byte-set-matcher-bytes m)` → the list as given.
  - `(make-byte-range-matcher low high)` → matcher. Rejects a non-byte `low`
    (detail `low`), a non-byte `high` (detail `high`), and `low > high`
    (detail `range`). `low = high` is legal.
  - `(byte-range-matcher? x)`, `(byte-range-matcher-low m)`, `(byte-range-matcher-high m)`.
  - `(make-byte-complement-matcher matcher)` → matcher over any matcher,
    including another complement. Rejects a non-matcher with detail `matcher`.
  - `(byte-complement-matcher? x)`, `(byte-complement-matcher-matcher m)`.
  - `(matcher? x)` → the four-way disjunction.
  - `(ascii-bytes s)` → proper list of exact integers in string order, no
    de-duplication. Rejects a non-string (detail `string`) and any character
    above `#\delete` (detail `non-ascii`). `(ascii-bytes "")` → `'()`.
  - `matcher-bytes` now canonicalizes all four kinds, recursively through
    complements.
  - `make-byte-case` accepts any `matcher?`.

- [ ] **Step 1: Write the failing constructor tests**

Append to `test/common/ir-tests.sps`, before `(harness-finish)`:

```scheme
(harness-group "the three class matchers canonicalize"
  (lambda ()
    (harness-case "a byte set canonicalizes ascending and de-duplicated"
      (lambda ()
        (check-equal "set" (matcher-bytes (make-byte-set-matcher '(254 1 0 1 255 2)))
                     '(0 1 2 254 255))))
    (harness-case "a byte set keeps the caller's order in its own accessor"
      (lambda ()
        (check-equal "as given" (byte-set-matcher-bytes (make-byte-set-matcher '(254 1 0)))
                     '(254 1 0))))
    (harness-case "a range canonicalizes to every byte from low to high inclusive"
      (lambda ()
        (check-equal "digits" (matcher-bytes (make-byte-range-matcher 48 57))
                     '(48 49 50 51 52 53 54 55 56 57))
        (check-equal "count" (length (matcher-bytes (make-byte-range-matcher 0 255))) 256)))
    (harness-case "a range with low = high is a legal one-element set"
      (lambda ()
        (check-equal "single" (matcher-bytes (make-byte-range-matcher 9 9)) '(9))))
    (harness-case "a complement is the universe minus the inner set"
      (lambda ()
        (let ((c (matcher-bytes (make-byte-complement-matcher (make-byte-set-matcher '(10 13))))))
          (check-equal "count" (length c) 254)
          (check-equal "first" (car c) 0)
          (check "10 excluded" (not (memv 10 c)))
          (check "13 excluded" (not (memv 13 c)))
          (check "255 present" (and (memv 255 c) #t)))))
    (harness-case "complements nest: complementing twice returns the inner set"
      (lambda ()
        (check-equal "digits again"
                     (matcher-bytes
                      (make-byte-complement-matcher
                       (make-byte-complement-matcher (make-byte-range-matcher 48 57))))
                     '(48 49 50 51 52 53 54 55 56 57))))
    (harness-case "the complement of the full universe is the empty set"
      (lambda ()
        (check-equal "vacuous"
                     (matcher-bytes
                      (make-byte-complement-matcher (make-byte-range-matcher 0 255)))
                     '())))))

(harness-group "degenerate shapes are constructor contract violations (decision 0017)"
  (lambda ()
    (harness-case "an empty byte set is rejected"
      (lambda ()
        (check-raises "empty set"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-set-matcher '())))))
    (harness-case "a byte set holding a non-byte is rejected"
      (lambda ()
        (check-raises "out of range"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-set-matcher '(0 256))))))
    (harness-case "a range with low greater than high is rejected"
      (lambda ()
        (check-raises "reversed"
                      (lambda (e) (and (byte-machine-contract-condition? e)
                                       (eq? (byte-machine-contract-condition-detail e) 'range)))
                      (lambda () (make-byte-range-matcher 9 8)))))
    (harness-case "a complement of something that is not a matcher is rejected"
      (lambda ()
        (check-raises "not a matcher"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-complement-matcher (make-edge 'stop 'advance))))))
    (harness-case "duplicate bytes inside one set are NOT a constructor error"
      (lambda ()
        (check "constructs" (byte-set-matcher? (make-byte-set-matcher '(3 3 3))))))))

(harness-group "ascii-bytes (parent §9.1:299)"
  (lambda ()
    (harness-case "a string becomes its code points in string order"
      (lambda ()
        (check-equal "GET" (ascii-bytes "GET") '(71 69 84))))
    (harness-case "repeated characters are kept, not de-duplicated"
      (lambda ()
        (check-equal "aa" (ascii-bytes "aa") '(97 97))))
    (harness-case "the empty string yields the empty list, which is not a matcher"
      (lambda ()
        (check-equal "empty" (ascii-bytes "") '())
        (check-raises "and cannot become a byte set"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-set-matcher (ascii-bytes ""))))))
    (harness-case "a non-ASCII character is rejected"
      (lambda ()
        (check-raises "non-ascii"
                      (lambda (e) (and (byte-machine-contract-condition? e)
                                       (eq? (byte-machine-contract-condition-detail e) 'non-ascii)))
                      (lambda () (ascii-bytes "caf\xe9;")))))
    (harness-case "code point 127 is ASCII and 128 is not"
      (lambda ()
        (check-equal "delete" (ascii-bytes (string (integer->char 127))) '(127))
        (check-raises "128"
                      byte-machine-contract-condition?
                      (lambda () (ascii-bytes (string (integer->char 128)))))))))

(harness-group "make-byte-case accepts every matcher kind"
  (lambda ()
    (harness-case "a byte-set case constructs and reads back its matcher"
      (lambda ()
        (let* ((m (make-byte-set-matcher '(1 2)))
               (c (make-byte-case m (make-edge 'stop 'advance) #f)))
          (check "byte-set matcher" (byte-set-matcher? (byte-case-matcher c))))))
    (harness-case "a range case and a complement case construct"
      (lambda ()
        (check "range" (byte-case? (make-byte-case (make-byte-range-matcher 1 2)
                                                   (make-edge 'stop 'advance) #f)))
        (check "complement"
               (byte-case? (make-byte-case
                            (make-byte-complement-matcher (make-exact-byte-matcher 0))
                            (make-edge 'stop 'advance) #f)))))
    (harness-case "an edge handed in as a matcher is still refused"
      (lambda ()
        (check-raises "not a matcher"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-case (make-edge 'stop 'advance)
                                                 (make-edge 'stop 'advance) #f)))))))
```

- [ ] **Step 2: Run the tests and confirm they fail**

```bash
ctest --preset release -R 'byte-machine.unit.ir.chez.source' --output-on-failure
```

Expected: exit 1, output contains
`Exception: variable make-byte-set-matcher is not bound`.

- [ ] **Step 3: Add the three matcher kinds, `matcher?` and `ascii-bytes`**

In `src/byte-machine/private/ir.sls`, insert the following **between** the
tag-guarded `exact-byte-matcher-byte` definition and the
`;; --- matcher canonicalization` comment block from Task 1:

```scheme
  ;; --- byte-set matcher (§9.1:292; decision 0017 points 1 and 3) ---
  ;; The caller's list is stored verbatim. Sorting or de-duplicating here would
  ;; be a construction-time semantic transform, which §9.1:322 forbids;
  ;; matcher-bytes does both, once, at canonicalization.
  (define byte-set-matcher-tag (tag 'byte-machine-byte-set-matcher))
  (define (make-byte-set-matcher bytes)
    (unless (and (list? bytes) (pair? bytes)
                 (for-all (lambda (b) (and (integer? b) (exact? b) (<= 0 b 255))) bytes))
      (byte-machine-contract-violation 'make-byte-set-matcher 'invalid-argument 'bytes))
    (vector byte-set-matcher-tag bytes))
  (define (byte-set-matcher? x) (tagged? byte-set-matcher-tag x))
  (define (byte-set-matcher-bytes m)
    (unless (byte-set-matcher? m)
      (byte-machine-contract-violation 'byte-set-matcher-bytes 'invalid-argument 'matcher))
    (vector-ref m 1))

  ;; --- byte-range matcher (§9.1:293; decision 0017 points 1 and 2) ---
  ;; low = high is legal: a redundant but well-formed exact byte.
  (define byte-range-matcher-tag (tag 'byte-machine-byte-range-matcher))
  (define (make-byte-range-matcher low high)
    (unless (and (integer? low) (exact? low) (<= 0 low 255))
      (byte-machine-contract-violation 'make-byte-range-matcher 'invalid-argument 'low))
    (unless (and (integer? high) (exact? high) (<= 0 high 255))
      (byte-machine-contract-violation 'make-byte-range-matcher 'invalid-argument 'high))
    (unless (<= low high)
      (byte-machine-contract-violation 'make-byte-range-matcher 'invalid-argument 'range))
    (vector byte-range-matcher-tag low high))
  (define (byte-range-matcher? x) (tagged? byte-range-matcher-tag x))
  (define (byte-range-matcher-low m)
    (unless (byte-range-matcher? m)
      (byte-machine-contract-violation 'byte-range-matcher-low 'invalid-argument 'matcher))
    (vector-ref m 1))
  (define (byte-range-matcher-high m)
    (unless (byte-range-matcher? m)
      (byte-machine-contract-violation 'byte-range-matcher-high 'invalid-argument 'matcher))
    (vector-ref m 2))

  ;; --- byte-complement matcher (§9.1:294) ---
  ;; It complements a MATCHER, not a byte list, so complements nest and
  ;; canonicalization is recursive. The complement of a full-universe matcher is
  ;; the empty set of transitions on a node whose fallback then takes every byte
  ;; -- vacuous, not malformed (decision 0017 point 2).
  (define byte-complement-matcher-tag (tag 'byte-machine-byte-complement-matcher))
  (define (make-byte-complement-matcher matcher)
    (unless (matcher? matcher)
      (byte-machine-contract-violation 'make-byte-complement-matcher 'invalid-argument 'matcher))
    (vector byte-complement-matcher-tag matcher))
  (define (byte-complement-matcher? x) (tagged? byte-complement-matcher-tag x))
  (define (byte-complement-matcher-matcher m)
    (unless (byte-complement-matcher? m)
      (byte-machine-contract-violation 'byte-complement-matcher-matcher
                                       'invalid-argument 'matcher))
    (vector-ref m 1))

  (define (matcher? x)
    (or (exact-byte-matcher? x) (byte-set-matcher? x)
        (byte-range-matcher? x) (byte-complement-matcher? x)))

  ;; ascii-bytes (§9.1:299): a string's code points as a proper list of exact
  ;; integers, in string order, with no de-duplication -- §9.1:318 names `bytes`
  ;; a proper list, so this composes directly with make-byte-set-matcher. It is a
  ;; helper, not a matcher constructor, so the empty string is legal and yields
  ;; '(); make-byte-set-matcher is where that becomes a contract violation.
  (define (ascii-bytes s)
    (unless (string? s)
      (byte-machine-contract-violation 'ascii-bytes 'invalid-argument 'string))
    (let loop ((i (- (string-length s) 1)) (acc '()))
      (if (< i 0)
          acc
          (let ((c (char->integer (string-ref s i))))
            (unless (<= 0 c 127)
              (byte-machine-contract-violation 'ascii-bytes 'invalid-argument 'non-ascii))
            (loop (- i 1) (cons c acc))))))
```

- [ ] **Step 4: Teach `matcher-bytes` the three new kinds**

Replace the `matcher-bytes` definition from Task 1 with:

```scheme
  (define (byte-set-canonical bs)
    (let loop ((s (list-sort < bs)) (acc '()))
      (cond ((null? s) (reverse acc))
            ((and (pair? acc) (= (car s) (car acc))) (loop (cdr s) acc))
            (else (loop (cdr s) (cons (car s) acc))))))
  (define (matcher-bytes m)
    (cond ((exact-byte-matcher? m) (list (exact-byte-matcher-byte m)))
          ((byte-set-matcher? m) (byte-set-canonical (byte-set-matcher-bytes m)))
          ((byte-range-matcher? m)
           (let loop ((b (byte-range-matcher-high m)) (acc '()))
             (if (< b (byte-range-matcher-low m))
                 acc
                 (loop (- b 1) (cons b acc)))))
          ((byte-complement-matcher? m)
           (let ((inner (matcher-bytes (byte-complement-matcher-matcher m))))
             (let loop ((b 255) (acc '()))
               (cond ((< b 0) acc)
                     ((memv b inner) (loop (- b 1) acc))
                     (else (loop (- b 1) (cons b acc)))))))
          (else (byte-machine-contract-violation 'matcher-bytes
                                                 'invalid-argument 'matcher))))
```

- [ ] **Step 5: Widen `make-byte-case`'s guard**

In `src/byte-machine/private/ir.sls`, replace

```scheme
    (unless (exact-byte-matcher? matcher)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'matcher))
```

with

```scheme
    (unless (matcher? matcher)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'matcher))
```

- [ ] **Step 6: Extend `ir.sls`'s export list**

Replace the `matcher-bytes` export line added in Task 1 with:

```scheme
          make-byte-set-matcher byte-set-matcher? byte-set-matcher-bytes
          make-byte-range-matcher byte-range-matcher?
          byte-range-matcher-low byte-range-matcher-high
          make-byte-complement-matcher byte-complement-matcher?
          byte-complement-matcher-matcher
          matcher? matcher-bytes ascii-bytes
```

- [ ] **Step 7: Run the ir tests and confirm they pass**

```bash
ctest --preset release -R 'byte-machine.unit.ir.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 8: Widen the `graph.sls` façade**

Replace the whole of `src/byte-machine/graph.sls` with:

```scheme
;;; (byte-machine graph): the public construction API. It re-exports the source-IR
;;; constructors from the private ir library so grammar authors build machines
;;; without touching internals. Constructors validate local shape only;
;;; verification is (byte-machine verify)'s job (parent §9.1).
;;;
;;; Milestone 3 Slice ① adds the three class matchers and `ascii-bytes`
;;; (§9.1:292-294, :299) together with the matcher predicates and accessors, so a
;;; grammar author can test what they built. `matcher-bytes` -- the internal
;;; canonicalization spine the verifier, normalizer and interpreter share -- is
;;; deliberately NOT re-exported: §9.1's construction list does not contain it.
(library (byte-machine graph)
  (export make-machine make-byte-dispatch-node make-byte-case
          make-exact-byte-matcher make-edge make-stop-node make-finish-node
          make-pause-node make-error-node make-error-declaration
          make-byte-set-matcher make-byte-range-matcher
          make-byte-complement-matcher ascii-bytes
          matcher? exact-byte-matcher? exact-byte-matcher-byte
          byte-set-matcher? byte-set-matcher-bytes
          byte-range-matcher? byte-range-matcher-low byte-range-matcher-high
          byte-complement-matcher? byte-complement-matcher-matcher)
  (import (only (byte-machine private ir)
                make-machine make-byte-dispatch-node make-byte-case
                make-exact-byte-matcher make-edge make-stop-node make-finish-node
                make-pause-node make-error-node make-error-declaration
                make-byte-set-matcher make-byte-range-matcher
                make-byte-complement-matcher ascii-bytes
                matcher? exact-byte-matcher? exact-byte-matcher-byte
                byte-set-matcher? byte-set-matcher-bytes
                byte-range-matcher? byte-range-matcher-low byte-range-matcher-high
                byte-complement-matcher? byte-complement-matcher-matcher)))
```

- [ ] **Step 9: Add the façade test**

In `test/common/graph-tests.sps`, replace line 5

```scheme
        (only (byte-machine private ir) machine? machine-entry machine-default-eof-error))
```

with

```scheme
        ;; Machine ACCESSORS are still private: §9.1 fixes the public
        ;; CONSTRUCTION surface and lists no accessors, and Milestone 3 Slice ①
        ;; declined to widen the façade past that list "for consistency" -- the
        ;; same argument design §8 rejects for source-label. The matcher
        ;; predicates below do come through the façade, because a grammar author
        ;; needs to test the matchers they just built.
        (only (byte-machine private ir) machine? machine-entry machine-default-eof-error))
```

and append this group before `(harness-finish)`:

```scheme
(harness-group "the façade builds class matchers"
  (lambda ()
    (harness-case "a set, range, complement and ASCII machine build with no private import"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'classes 'start '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-byte-dispatch-node
                          'start
                          (list (make-byte-case (make-byte-set-matcher (ascii-bytes "GET"))
                                                (make-edge 'stop 'advance) #f)
                                (make-byte-case (make-byte-range-matcher 48 57)
                                                (make-edge 'stop 'advance) #f)
                                (make-byte-case (make-byte-complement-matcher
                                                 (make-byte-range-matcher 0 200))
                                                (make-edge 'stop 'advance) #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'start))))
    (harness-case "the façade exports the matcher predicates and accessors"
      (lambda ()
        (check "matcher?" (matcher? (make-byte-range-matcher 1 2)))
        (check-equal "range low" (byte-range-matcher-low (make-byte-range-matcher 1 2)) 1)
        (check-equal "range high" (byte-range-matcher-high (make-byte-range-matcher 1 2)) 2)
        (check-equal "set bytes" (byte-set-matcher-bytes (make-byte-set-matcher '(5 6))) '(5 6))
        (check "complement inner"
               (exact-byte-matcher?
                (byte-complement-matcher-matcher
                 (make-byte-complement-matcher (make-exact-byte-matcher 3)))))))))
```

- [ ] **Step 10: Run the whole suite**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 72`.

```bash
git status --porcelain -- test/fixtures/
```

Expected: **no output.**

- [ ] **Step 11: Add the constructor mutations to Pass 42**

Insert these five mutations into Pass 42, between the two Task 1 mutations and
the `byte_machine_mutation_run(...)` line:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: an empty byte set is accepted"
  FIND [[(unless (and (list? bytes) (pair? bytes)]]
  REPLACE [[(unless (and (list? bytes)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "an empty byte set is rejected: empty set")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a reversed byte range is accepted"
  FIND [[(unless (<= low high)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "low greater than high is rejected: reversed")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: ascii-bytes admits a non-ASCII character"
  FIND [[(unless (<= 0 c 127)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "A non-ASCII character is rejected: non-ascii")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a byte set is canonicalized without de-duplication"
  FIND [[((and (pair? acc) (= (car s) (car acc))) (loop (cdr s) acc))]]
  REPLACE [[((and (pair? acc) (< (car s) (car acc))) (loop (cdr s) acc))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ascending and de-duplicated: set")

byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.ir.chez.source
  LABEL "ir: a complement is not the universe minus the inner set"
  FIND [[((memv b inner) (loop (- b 1) acc))]]
  REPLACE [[((memv b inner) (loop (- b 1) (cons b acc)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "minus the inner set: count")
```

> **Measure, do not assume, every `EXPECT_OUTPUT_MATCHES` above.** Each is the
> case-name tail plus the check label this plan predicts will fail *first*. Run
> the mutant, read the actual first `FAIL <group>.<case>: <what>` line, and use
> that. A pin that names a check the mutant does not break is a false catch, and
> a pin that is a substring of the FAIL-CONTEXT or summary line is a bare
> nonzero-exit catch wearing a disguise (AGENTS.md). Note `ascii-bytes`'s case
> name begins the FAIL id after a `.`, so the pin above starts at a word
> boundary inside the case name; confirm the exact casing from the run.

Then update the totals:

```cmake
# Slice ① Task 2 adds five constructor and canonicalization mutations to
# Pass 42. Passes stay at 39; mutations become 167 + 5 = 172.
set(EXPECTED_PASSES 39)
set(EXPECTED_MUTATIONS 172)
```

- [ ] **Step 12: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: exactly one line,
`byte-machine-spec: scheme mutation suite complete (39 passes, 172 mutations)`.

- [ ] **Step 13: Commit**

```bash
git add src/byte-machine/private/ir.sls src/byte-machine/graph.sls test/common/ir-tests.sps test/common/graph-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: byte-set, byte-range and byte-complement matchers plus ascii-bytes

The three class matchers of parent §9.1:292-294 and the §9.1:299 ASCII helper,
with decision 0017's degenerate-shape rejections at construction (empty set,
low > high) and its explicit non-rejections (low = high, duplicate bytes, a
vacuous complement). make-byte-case's guard widens to any matcher?, and
matcher-bytes canonicalizes all four kinds -- recursively through complements,
since §9.1:294 complements a matcher rather than a byte list.

The graph façade re-exports the four construction calls plus the matcher
predicates and accessors. Machine accessors stay private: §9.1 fixes the public
construction surface and lists none."
```

---

## Task 3: `pass-overlap` as pairwise disjointness over canonical sets

**Files:**
- Modify: `src/byte-machine/verify.sls` (`pass-overlap`)
- Test: `test/common/verify-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 33 additions; totals)

**Interfaces:**
- Consumes: `matcher-bytes`, `byte-sets-overlap?` (Tasks 1-2).
- Produces: `pass-overlap` emitting one `'overlapping-cases` diagnostic per
  colliding **pair** of cases within one dispatch node, in caller order
  (i before j, i ascending then j ascending). Diagnostic node is the dispatch
  node's name. No new diagnostic code.

> **Disposition, 2026-08-29 (Task 7 close-out).** The "in caller order (i
> before j, i ascending then j ascending)" clause above promised something
> nothing in the shipped code or tests can observe, and is dispositioned
> rather than reworded to drop it silently. `make-diagnostic` takes exactly
> `(code node message)` — no ordering field — so every `'overlapping-cases`
> diagnostic one dispatch node produces is `equal?` to every other, and a
> reader comparing the list has no way to recover which pair produced which
> element. The implementation initially carried a `(reverse out)` to try to
> deliver the claim; review found it unobservable (`equal?` collapses the
> distinction the reverse exists to preserve) and additionally found it made
> a sibling test case vacuous. Both `(reverse out)` and the ordering promise
> above were removed together in the fix wave (commit `b835bfe`), verified
> by a control: reintroducing `(reverse out)` left the release lane
> (`ctest --preset release`, i.e. `make test-all`) green at 72/72 — that
> lane's size at Task 3, before Tasks 5-6 added the four byte-class lanes
> that bring the shipped tree's release lane to 76/76 (re-measured on
> `b835bfe` directly for Fix wave 1: 72/72, matching `task-3-report.md`'s own
> figure). Diagnostic order was never re-promised
> at a weaker grain (e.g. "diagnostics for a fixed node appear in some
> stable but unspecified order") because §16.4 and `verify.sls`'s own header
> forbid comparing diagnostics by rendered text, which is the only way an
> order claim could be tested without an ordering field.

- [ ] **Step 1: Write the failing tests**

Append to `test/common/verify-tests.sps`, before `(harness-finish)`:

```scheme
;; Milestone 3 Slice ① Task 3: overlap is a property of canonical byte SETS, so
;; it must be found across mixed matcher kinds, and reported once per colliding
;; PAIR of cases -- not once per shared byte. A set and a complement can share
;; 200 bytes, and §16.4:937-943 wants one finding per decision.
(define (dispatch-node-machine cases)
  (machine (list (dispatch cases (make-edge 'reject 'reexecute))
                 (make-stop-node 'stop #f)
                 (make-error-node 'reject 'rejected #f))))
(define (overlap-count m)
  (length (filter (lambda (c) (eq? c 'overlapping-cases)) (codes m))))
(define (to-stop matcher) (make-byte-case matcher (make-edge 'stop 'advance) #f))

(harness-group "byte-class overlap (§16.2:893)"
  (lambda ()
    (harness-case "a range and an exact byte inside it overlap"
      (lambda ()
        (check "overlapping-cases"
               (has-code? (dispatch-node-machine
                           (list (to-stop (make-byte-range-matcher 48 57))
                                 (to-stop (make-exact-byte-matcher 50))))
                          'overlapping-cases))))
    (harness-case "a set and a complement that share a byte overlap"
      (lambda ()
        (check "overlapping-cases"
               (has-code? (dispatch-node-machine
                           (list (to-stop (make-byte-set-matcher '(200 201)))
                                 (to-stop (make-byte-complement-matcher
                                           (make-byte-range-matcher 0 199)))))
                          'overlapping-cases))))
    (harness-case "disjoint classes do not overlap"
      (lambda ()
        (check-equal "none"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 48 57))
                                           (to-stop (make-byte-range-matcher 65 90))
                                           (to-stop (make-byte-set-matcher '(10 13))))))
                     0)))
    (harness-case "a vacuous complement collides with nothing"
      (lambda ()
        (check-equal "none"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-complement-matcher
                                                     (make-byte-range-matcher 0 255)))
                                           (to-stop (make-byte-range-matcher 48 57)))))
                     0)))
    (harness-case "two classes sharing 200 bytes are one diagnostic, not 200"
      (lambda ()
        (check-equal "exactly one"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 199))
                                           (to-stop (make-byte-range-matcher 0 255)))))
                     1)))
    ;; These three fixtures are ordered deliberately. Each isolates one half of
    ;; the pair enumeration, so the three Task 3 mutations below have distinct
    ;; first failures and distinct failure SETS -- without the first-and-third
    ;; fixture, "collisions after the first are dropped" is subsumed by "only the
    ;; first case is compared" and no pin can separate them.
    (harness-case "a collision between the first and third cases is found"
      (lambda ()
        (check-equal "one pair"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 10))
                                           (to-stop (make-byte-range-matcher 100 110))
                                           (to-stop (make-byte-range-matcher 5 8)))))
                     1)))
    (harness-case "a collision between the second and third cases is found"
      (lambda ()
        (check-equal "one pair"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-set-matcher '(1)))
                                           (to-stop (make-byte-range-matcher 100 110))
                                           (to-stop (make-byte-set-matcher '(105))))))
                     1)))
    (harness-case "three mutually colliding cases are three diagnostics, one per pair"
      (lambda ()
        (check-equal "three pairs"
                     (overlap-count (dispatch-node-machine
                                     (list (to-stop (make-byte-range-matcher 0 10))
                                           (to-stop (make-byte-range-matcher 5 15))
                                           (to-stop (make-byte-range-matcher 8 20)))))
                     3)))))
```

- [ ] **Step 2: Run the tests and confirm the counting cases fail**

```bash
ctest --preset release -R 'byte-machine.verify.rejections.chez.source' --output-on-failure
```

Expected: exit 1. The `has-code?` cases pass already (Task 1's per-case loop
finds *that* an overlap exists); the counting cases fail. The output contains
`FAIL` on `three mutually colliding cases are three diagnostics, one per pair`
with `expected 3, got 2`.

- [ ] **Step 3: Rewrite `pass-overlap` as pairwise disjointness**

In `src/byte-machine/verify.sls`, replace the `pass-overlap` definition written
in Task 1 (leave `byte-sets-overlap?` exactly as it is) with:

```scheme
  ;; One diagnostic per COLLIDING PAIR of cases, in caller order -- not one per
  ;; shared byte. A complement and a set can share 200 bytes, and a naive
  ;; per-byte expansion would turn one decision into 200 identical diagnostics
  ;; against §16.4:937-943. Pairs are enumerated i < j so a pair is reported
  ;; once, and the pass never inspects the lowered graph: canonical byte sets
  ;; are a source-level property (§17:951 verify-before-normalize).
  (define (node-overlaps n)
    (let ((sets (map (lambda (c) (matcher-bytes (byte-case-matcher c)))
                     (byte-dispatch-node-cases n))))
      (let outer ((ss sets) (out '()))
        (if (null? ss)
            (reverse out)
            (outer (cdr ss)
                   (let inner ((rest (cdr ss)) (out out))
                     (if (null? rest)
                         out
                         (inner (cdr rest)
                                (if (byte-sets-overlap? (car ss) (car rest))
                                    (cons (make-diagnostic 'overlapping-cases (node-name n)
                                                           "two cases match the same byte or bytes")
                                          out)
                                    out)))))))))
  (define (pass-overlap m)
    (apply append
           (map (lambda (n) (if (byte-dispatch-node? n) (node-overlaps n) '()))
                (machine-nodes m))))
```

- [ ] **Step 4: Run the tests and confirm they pass**

```bash
ctest --preset release -R 'byte-machine.verify.rejections.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 5: Run the whole suite**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 72`.

- [ ] **Step 6: Add the pair-enumeration mutations to Pass 33**

Insert these three mutations into Pass 33, immediately after the re-anchored
`"verify: two cases sharing a byte are never found to overlap"` mutation:

```cmake
# Slice ① Task 3: the pair enumeration itself. The helper pin above proves the
# disjointness TEST fires; these three prove the pass reaches every pair, reports
# each once, and does not stop at the first collision it finds.
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: only the first case is compared against the others"
  FIND [[(outer (cdr ss)]]
  REPLACE [[(outer '()]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "second and third cases is found: one pair")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a case's collisions after the first are dropped"
  FIND [[(inner (cdr rest)]]
  REPLACE [[(inner '()]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "first and third cases is found: one pair")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a case is compared against itself"
  FIND [[(let inner ((rest (cdr ss)) (out out))]]
  REPLACE [[(let inner ((rest ss) (out out))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "do not overlap: none")
```

> These three pins were chosen to have disjoint failure *sets*, not merely
> distinct first failures: "only the first case is compared" passes the
> first-and-third fixture and fails the second-and-third one, and "collisions
> after the first are dropped" does the reverse; the third mutation is the only
> one that reddens `disjoint classes do not overlap`, because only it compares a
> case against itself. Measure all three against the run and against each
> other's captured output, comparing whole FAIL records rather than lines.

Then update the totals:

```cmake
# Slice ① Task 3 adds three pair-enumeration mutations to Pass 33.
# Passes stay at 39; mutations become 172 + 3 = 175.
set(EXPECTED_PASSES 39)
set(EXPECTED_MUTATIONS 175)
```

- [ ] **Step 7: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: exactly one line,
`byte-machine-spec: scheme mutation suite complete (39 passes, 175 mutations)`.

- [ ] **Step 8: Commit**

```bash
git add src/byte-machine/verify.sls test/common/verify-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: byte-class overlap verification as pairwise set disjointness

pass-overlap now canonicalizes every case's matcher and reports one
'overlapping-cases diagnostic per colliding PAIR of cases, in caller order --
not one per shared byte, which would turn a single 200-byte class collision into
200 identical findings against §16.4:937-943. Overlap is found across mixed
matcher kinds; a vacuous complement collides with nothing."
```

---

## Task 4: Per-byte lowering proved, and the emitter's zero change recorded

**Files:**
- Test: `test/common/normal-ir-tests.sps`
- Modify: `src/byte-machine/compile.sls` (**comment only** — the recorded zero change)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 35 additions; totals)

**Interfaces:**
- Consumes: `normalize-machine`, `normal-dispatch-transitions` (shipped);
  `matcher-bytes` (Task 1); the class constructors (Task 2).
- Produces: no new interface. This task is where decision 0014's lowering gets
  its witnesses. The expansion itself landed in Task 1 (see §0 D8) because it is
  behaviour-preserving while every canonical set is a singleton.

- [ ] **Step 1: Write the failing tests**

Append to `test/common/normal-ir-tests.sps`, before `(harness-finish)`:

```scheme
;; Milestone 3 Slice ① Task 4 (decision 0014): a byte set, range or complement
;; lowers to ONE normalized transition per byte. Normalized IR gains no grouped
;; or set-valued transition and its encoding gains no new arm -- so these cases
;; check the transition LIST, and the three fingerprint goldens above (which no
;; class machine touches) are what proves the encoding did not move.
(define (class-machine name cases)
  (make-machine name 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start cases (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define (accepts matcher) (make-byte-case matcher (make-edge 'stop 'advance) #f))
(define (transitions-of m)
  (normal-dispatch-transitions (vector-ref (normal-machine-states (normalize m)) 0)))

(harness-group "byte classes lower to one transition per byte (decision 0014)"
  (lambda ()
    (harness-case "a range lowers to one transition per byte, ascending"
      (lambda ()
        (let ((trs (transitions-of (class-machine 'ranged (list (accepts (make-byte-range-matcher 48 51)))))))
          (check-equal "transitions" trs '((48 1 advance) (49 1 advance)
                                           (50 1 advance) (51 1 advance))))))
    (harness-case "an unsorted, duplicated byte set lowers ascending and de-duplicated"
      (lambda ()
        (check-equal "bytes"
                     (map car (transitions-of
                               (class-machine 'setm (list (accepts (make-byte-set-matcher '(5 2 5 9)))))))
                     '(2 5 9))))
    (harness-case "a complement lowers to 254 transitions covering the universe minus two"
      (lambda ()
        (let ((bs (map car (transitions-of
                            (class-machine 'compl
                              (list (accepts (make-byte-complement-matcher
                                              (make-byte-set-matcher '(10 13))))))))))
          (check-equal "count" (length bs) 254)
          (check-equal "first" (car bs) 0)
          (check "10 absent" (not (memv 10 bs)))
          (check "13 absent" (not (memv 13 bs))))))
    (harness-case "two disjoint classes on one node interleave into one ascending list"
      (lambda ()
        (check-equal "bytes"
                     (map car (transitions-of
                               (class-machine 'two
                                 (list (accepts (make-byte-set-matcher '(9 1)))
                                       (accepts (make-byte-range-matcher 4 5))))))
                     '(1 4 5 9))))
    (harness-case "a vacuous complement lowers to zero transitions (decision 0017 point 2)"
      (lambda ()
        (check-equal "none"
                     (transitions-of (class-machine 'vacuous
                                       (list (accepts (make-byte-complement-matcher
                                                       (make-byte-range-matcher 0 255))))))
                     '())))
    (harness-case "a full complement lowers to all 256 transitions"
      (lambda ()
        (let ((bs (map car (transitions-of
                            (class-machine 'full
                              (list (accepts (make-byte-complement-matcher
                                              (make-byte-complement-matcher
                                               (make-byte-range-matcher 0 255)))))))))
          (check-equal "count" (length bs) 256)
          (check-equal "first" (car bs) 0)
          (check-equal "last" (list-ref bs 255) 255))))))
```

> **Disposition, 2026-08-29 (Task 7 close-out).** The "full complement" case
> above is dispositioned rather than silently reflowed, because a reader who
> pastes it verbatim reproduces a real defect. Independently re-counted
> (paren depth per line, string contents excluded): the `let`'s binding list
> `((bs (map car (transitions-of ...)))` closes the `bs` pair and every form
> nested inside it, but never closes the **outer** bindings-list paren before
> the three `check-equal` body forms begin — the block is one `)` short at
> that point, running at depth 4 (harness-case, lambda, let, and the still-open
> bindings-list) where the body expects depth 3. Chez's reader does not error
> there: it keeps consuming the three `check-equal` forms as further bindings
> inside the still-open list, and the block's own trailing run of six `)` on
> its last line closes one paren too many for a self-contained form (final
> depth −1), which silently closes one paren belonging to whatever follows in
> the file instead — swallowing the rest of the file's forms by exactly one
> level from that point on, with no read error at any point. This block was
> read-checked as Scheme text at plan-authoring time in the four **library**
> edits this plan specifies (§0's "Verified at plan-authoring time" note), but
> not in the **test** code blocks, which carry the same syntactic risk and got
> none of the check. The implementer found this from Chez's own behavior
> (the appended tests silently vanished) rather than from a read error,
> diagnosed the missing paren, and shipped the corrected block with one
> additional `)` closing the bindings list before the three `check-equal`
> body forms (commit `387f528`, `normal-ir-tests.sps:196-205`;
> task-4-report.md's "Plan defect found and fixed: unbalanced parens in the
> brief's Step 1 code").

- [ ] **Step 2: Run the tests and confirm they pass**

```bash
ctest --preset release -R 'byte-machine.unit.normal-ir.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`. **These pass on the
first run** — Task 1 already wrote the expansion, and this task's job is to
witness it. That is the expected outcome, not a TDD violation: the red for this
code was Task 1's own gate (the fingerprints and goldens had to stay identical
*while* the expansion landed). If any case here fails, Task 1's expansion is
wrong and the defect is in `normal-ir.sls:100-106`, not in this test.

- [ ] **Step 3: Confirm the emitter needs no change, mechanically**

```bash
git diff --stat main -- src/byte-machine/compile.sls
```

Expected: **no output** — `compile.sls` is untouched by Tasks 1-3.

```bash
ctest --preset release -R 'byte-machine.unit.compile.chez|byte-machine.determinism' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 6`.

- [ ] **Step 4: Record the zero change at the site**

In `src/byte-machine/compile.sls`, replace lines 80-83 with:

```scheme
  (define (render-transition-arm tr)
    ;; tr = (byte target mode) -> "((<byte>) <loop-tail>)"
    ;; Milestone 3 Slice ① changed nothing here, and that is a decision rather
    ;; than an oversight: byte classes lower to one transition per byte
    ;; (decision 0014), so a complement renders up to 256 sibling arms inside the
    ;; single `(case b ...)` below. §19.2:1009 asks for "canonical membership
    ;; code selected for simplicity, not speculative density optimization", and a
    ;; grouped datum list or a membership table is the optimization §29:1743
    ;; defers and §23.3:1369 gates behind compiled benchmarks that cannot exist
    ;; yet (`bench/` holds two .gitkeep files).
    (string-append "               ((" (number->string (car tr)) ") "
                   (loop-tail (cadr tr) (caddr tr)) ")\n"))
```

- [ ] **Step 5: Run the whole suite**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 72`.

```bash
git status --porcelain -- test/fixtures/
```

Expected: **no output.**

- [ ] **Step 6: Add the lowering mutations to Pass 35**

Insert these two mutations into Pass 35, immediately after the
`"normal-ir: dispatch cases are not sorted ascending by byte"` mutation:

```cmake
# Slice ① Task 4 (decision 0014): the per-byte expansion itself. The first keeps
# only each class's lowest byte, so a range of four lowers to one transition; the
# second drops the de-duplication that keeps the ascending sort a TOTAL order,
# so a set given a repeated byte lowers to two transitions on it.
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a byte class lowers to only its lowest byte"
  FIND [[(bs (matcher-bytes (byte-case-matcher c)))]]
  REPLACE [[(bs (list (car (matcher-bytes (byte-case-matcher c)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "one transition per byte, ascending: transitions")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a class matching no bytes still contributes a transition"
  FIND [[                                                                   bs)))]]
  REPLACE [[                                                                   (if (null? bs) (list 0) bs))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "vacuous complement lowers to zero transitions: none")
```

> The first `FIND` is whitespace-free and unique. The **second** is one of the
> few in this plan that carries indentation, because the bare token `bs)))` is
> not unique on its own — re-derive it from the file with
> `grep -n 'bs)))' src/byte-machine/private/normal-ir.sls`, confirm exactly one
> hit, and copy that line's leading spaces verbatim. A leading-space mismatch is
> reported as "found 0, expected 1" at suite run time, not as a silent skip.
> Measure both signatures against a run.

Then update the totals:

```cmake
# Slice ① Task 4 adds two per-byte-expansion mutations to Pass 35.
# Passes stay at 39; mutations become 175 + 2 = 177.
set(EXPECTED_PASSES 39)
set(EXPECTED_MUTATIONS 177)
```

- [ ] **Step 7: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: exactly one line,
`byte-machine-spec: scheme mutation suite complete (39 passes, 177 mutations)`.

- [ ] **Step 8: Commit**

```bash
git add test/common/normal-ir-tests.sps src/byte-machine/compile.sls test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: pin per-byte class lowering and record the emitter's zero change

Decision 0014's lowering gets its witnesses: a range, an unsorted duplicated
set, a 254-byte complement, two interleaved classes, a vacuous complement
(0 transitions, decision 0017 point 2) and a full one (256). The three pinned IR
fingerprints and both goldens are unmoved, which is what proves the encoding
gained no arm.

compile.sls carries a comment saying why it did not change, so the absence of a
diff is a recorded decision rather than an unexplained gap."
```

---

## Task 5: The shared class fixtures and the absolute all-256 interpreter lane

**Files:**
- Create: `test/support/harness/byte-machine/test/class-machine.sls`
- Create: `test/common/byte-class-interpret-tests.sps`
- Modify: `test/CMakeLists.txt` (after the `byte-machine.differential.pause.chez.aot` block, currently ending at line 1032)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new Pass 43; totals)

**Interfaces:**
- Consumes: `(byte-machine graph)`'s Task 2 exports.
- Produces, from `(byte-machine test class-machine)`:
  - `(make-byte-set-machine)` → machine `byte-set`, accepting `{0,1,2,254,255}`
  - `(make-byte-range-machine)` → machine `byte-range`, accepting `97..122`
  - `(make-byte-complement-machine)` → machine `byte-complement`, accepting every byte but `10` and `13`
  - `(make-nested-complement-machine)` → machine `nested-complement`, accepting `48..57`
  - `(make-ascii-machine)` → machine `ascii-set`, accepting `{71,69,84}` (`"GET"`)
  - `(class-machines)` → a proper list of `(name machine accepted-bytes)` triples,
    where `accepted-bytes` is a sorted proper list of the bytes that must reach
    `stopped`. Every other byte must reach `error` with code `unexpected-byte`
    at stream offset 0.

- [ ] **Step 1: Write the fixture library**

Create `test/support/harness/byte-machine/test/class-machine.sls`:

```scheme
;;; The Milestone 3 Slice ① byte-class proving machines, shared by the absolute
;;; all-256 interpreter lane and the interpreter≡generated differential so each
;;; graph descriptor is written once. Built only through (byte-machine graph).
;;;
;;; Each machine has the same shape as the M1 one-byte machine -- one dispatch
;;; node, one accepting case, a reexecute fallback into the reject error -- so
;;; the only variable under test is the matcher. Every fallback REEXECUTES, so a
;;; rejected byte's `next` points AT the offending byte (parent §11.5).
;;;
;;; The five cover the matcher repertoire and its two hazards: a set given in
;;; non-ascending order WITH a duplicate (canonicalization must sort and
;;; de-duplicate, or the node overlaps itself); and a complement of a complement
;;; (§9.1:294 complements a MATCHER, so canonicalization is recursive -- a
;;; single-level complement cannot witness that).
(library (byte-machine test class-machine)
  (export make-byte-set-machine make-byte-range-machine
          make-byte-complement-machine make-nested-complement-machine
          make-ascii-machine class-machines)
  (import (rnrs) (byte-machine graph))

  (define (class-machine name matcher)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine name 'start '() '() '() (list eof-decl rej-decl)
        (list (make-byte-dispatch-node 'start
                (list (make-byte-case matcher (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f)))

  ;; Deliberately unsorted and holding a duplicate: decision 0017 point 3 leaves
  ;; both to canonicalization rather than to the constructor.
  (define (make-byte-set-machine)
    (class-machine 'byte-set (make-byte-set-matcher '(254 1 0 1 255 2))))
  (define (make-byte-range-machine)
    (class-machine 'byte-range (make-byte-range-matcher 97 122)))
  (define (make-byte-complement-machine)
    (class-machine 'byte-complement
                   (make-byte-complement-matcher (make-byte-set-matcher '(10 13)))))
  (define (make-nested-complement-machine)
    (class-machine 'nested-complement
                   (make-byte-complement-matcher
                    (make-byte-complement-matcher (make-byte-range-matcher 48 57)))))
  (define (make-ascii-machine)
    (class-machine 'ascii-set (make-byte-set-matcher (ascii-bytes "GET"))))

  (define (range-list low high)
    (let loop ((b high) (acc '())) (if (< b low) acc (loop (- b 1) (cons b acc)))))
  (define (universe-without excluded)
    (let loop ((b 255) (acc '()))
      (cond ((< b 0) acc)
            ((memv b excluded) (loop (- b 1) acc))
            (else (loop (- b 1) (cons b acc))))))

  ;; (name machine accepted-bytes); accepted-bytes ascending, duplicate-free.
  (define (class-machines)
    (list (list 'byte-set (make-byte-set-machine) '(0 1 2 254 255))
          (list 'byte-range (make-byte-range-machine) (range-list 97 122))
          (list 'byte-complement (make-byte-complement-machine) (universe-without '(10 13)))
          (list 'nested-complement (make-nested-complement-machine) (range-list 48 57))
          (list 'ascii-set (make-ascii-machine) '(69 71 84)))))
```

- [ ] **Step 2: Write the absolute all-256 test program**

Create `test/common/byte-class-interpret-tests.sps`:

```scheme
;;; All-byte class tests (parent §22.7:1299-1301; Milestone 3 exit :1537) run
;;; through the reference interpreter with ABSOLUTE expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors canonicalize through
;;; the same `matcher-bytes`, so a defect there would make interpreter and
;;; generated wrong IDENTICALLY and leave a comparison green. This program is
;;; what a canonicalization mutation reddens; differential-byte-class-tests.sps
;;; is what proves the two executors agree.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test class-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.byte-class")

(define (feed cm b)
  (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1))

;; Every machine must VERIFY clean first: a fixture that fails verification would
;; make every behavioural case below meaningless, and §22.6 forbids using an
;; invalid graph to test executor behaviour.
(harness-group "every class fixture verifies clean"
  (lambda ()
    (for-each
     (lambda (entry)
       (harness-case (string-append (symbol->string (car entry)) " verifies with no diagnostics")
         (lambda ()
           (let ((v (verify-machine (cadr entry))))
             (check "ok" (verification-ok? v))
             (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)))))
     (class-machines))))

(harness-group "all 256 byte values, per class"
  (lambda ()
    (for-each
     (lambda (entry)
       (let* ((name (car entry))
              (cm (make-interpreted-machine (verify-machine (cadr entry))))
              (accepted (caddr entry)))
         (harness-case (string-append (symbol->string name) " accepts exactly its class")
           (lambda ()
             ;; `bad` alone proves no byte MISBEHAVED, not that the loop ran: a
             ;; loop that never executed leaves it at its seeded 'none. last-byte
             ;; is set every iteration, so it reaches 255 only if all 256 ran, and
             ;; `hits` counts acceptances so a matcher that accepts nothing at all
             ;; cannot pass by having no counterexample.
             (let ((bad 'none) (last-byte 'unset) (hits 0))
               (let loop ((b 0))
                 (when (< b 256)
                   (let ((r (feed cm b)))
                     (if (memv b accepted)
                         (begin
                           (set! hits (+ hits 1))
                           (unless (and (eq? (parser-result-status r) 'stopped)
                                        (= (parser-result-consumed r) 1))
                             (when (eq? bad 'none) (set! bad b))))
                         (unless (and (eq? (parser-result-status r) 'error)
                                      (eq? (parser-result-error r) 'unexpected-byte)
                                      (= (parser-result-stream-offset r) 0))
                           (when (eq? bad 'none) (set! bad b)))))
                   (set! last-byte b)
                   (loop (+ b 1))))
               (check-equal "no byte misbehaved" bad 'none)
               (check-equal "loop ran all 256 bytes" last-byte 255)
               (check-equal "accepted exactly the class size" hits (length accepted)))))))
     (class-machines))))

;; §22.7 and design §5 item 6: ascii-bytes cannot supply the high half of the
;; universe -- that is make-byte-range-matcher's job -- so its all-byte test
;; asserts REJECTION across 0x80-0xFF rather than acceptance anywhere in it.
(harness-group "the ASCII helper rejects the high half"
  (lambda ()
    (harness-case "every byte from 128 to 255 is rejected by the ascii machine"
      (lambda ()
        (let ((cm (make-interpreted-machine (verify-machine (make-ascii-machine))))
              (bad 'none) (last-byte 'unset) (checked 0))
          (let loop ((b 128))
            (when (< b 256)
              (let ((r (feed cm b)))
                (set! checked (+ checked 1))
                (unless (and (eq? (parser-result-status r) 'error)
                             (eq? (parser-result-error r) 'unexpected-byte))
                  (when (eq? bad 'none) (set! bad b))))
              (set! last-byte b)
              (loop (+ b 1))))
          (check-equal "no high byte was accepted" bad 'none)
          (check-equal "loop ran the whole high half" last-byte 255)
          (check-equal "checked 128 bytes" checked 128))))))

(harness-finish)
```

> **Disposition, 2026-08-29 (Task 7 close-out).** Step 2's `hits` sentinel
> above, and its comment's claim that "`hits` counts acceptances so a matcher
> that accepts nothing at all cannot pass," are dispositioned rather than
> corrected in place, because the work that comment describes has closed
> under a rewritten sentinel — the comment described what the plan intended
> `hits` to do, not what the code above it does. `(set! hits (+ hits 1))`
> sits inside the `(if (memv b accepted) ...)` branch, i.e. it increments
> from the test's own **expected** `accepted` list, never from the observed
> `parser-result-status`/`-consumed` fields the surrounding `unless` checks.
> `hits` is therefore identically `(length accepted)` for **every** possible
> matcher behaviour — it can only differ from the class size if a fixture's
> own `accepted` list held a duplicate, which none does — so "accepted
> exactly the class size" passed whether the matcher was right or wrong,
> exactly the defect this file's own Global Constraints exist to prevent
> ("a test that passes whether the code is right or wrong is worse than no
> test"). Found by the mutation this same plan's Pass 43 adds against
> `interpret.sls`'s class-membership dispatch: the pin predicted by this
> step's own brief text ("accepted exactly the class size") never fired
> against the vacuous sentinel. The implementer diagnosed the vacuity from
> the pin's silence, not from inspection, and shipped a rewritten `hits`
> that increments from the observed result
> (`(and (eq? (parser-result-status r) 'stopped) (= (parser-result-consumed
> r) 1))`) instead of list membership (commit `e581ac4`); re-measured, the
> originally predicted pin now fires as this step's brief said it would.
> Task 6 separately found and closed a second vacuity one level up — the
> `for-each` over `(class-machines)` in this group and its sibling had no
> sentinel on the fixture count itself, so a dropped fixture would shrink
> both groups silently.

- [ ] **Step 3: Register the two lanes**

In `test/CMakeLists.txt`, insert immediately after the
`byte-machine.differential.pause.chez.aot` block (before the
`# --- Milestone 1 Phase 3 Slice B: D7 identifier repertoire` comment):

```cmake
# --- Milestone 3 Slice ①: all-byte class coverage through the interpreter ----
# ABSOLUTE expected outcomes over all 256 bytes for a set, a range, a complement,
# a nested complement and an ASCII set. Absolute rather than differential because
# both executors canonicalize through the same matcher-bytes: a defect there is
# invisible to a comparison and visible here.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.byte-class.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.byte-class.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/byte-class-interpret-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 4: Build, and confirm the lanes register and pass**

```bash
make build && ctest --preset release -R 'byte-machine.unit.byte-class' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 5: Run the whole suite and confirm the new lane count**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 74`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 8` — this slice registers no
new `cmake.direct` lane, so the no-scheme count must not change.

- [ ] **Step 6: Add Pass 43 — class membership the one-byte machine cannot witness**

Append to `test/support/cmake/SchemeMutationSuite.cmake`, immediately before the
`byte_machine_mutation_totals(...)` block:

```cmake
# --- Pass 43: class membership and recursive canonicalization (M3 Slice ①
# Task 5) --------------------------------------------------------------------
#
# byte-class-interpret-tests.sps drives five class fixtures over all 256 bytes
# with ABSOLUTE expected outcomes. Two decisions here are unreachable from every
# earlier lane, because every earlier fixture's matcher is a one-element set:
# `memv` over the whole canonical set (for a singleton, `memv` and `= (car ...)`
# agree, so Pass 34's one-byte machine cannot separate them), and the recursion
# through a nested complement. The first mutation matches only a class's lowest
# byte; the second stops complement canonicalization recursing, so a
# complement-of-a-complement is read as its own inner matcher. Verify command
# uses both library roots, an empty object guard, the byte-class program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/byte-class-interpret-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.byte-class.chez.source
  LABEL "interpret: class membership matches only the class's lowest byte"
  FIND [[((memv byte (matcher-bytes (byte-case-matcher (car cs))))]]
  REPLACE [[((= byte (car (matcher-bytes (byte-case-matcher (car cs)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "accepted exactly the class size")

# The REPLACE below canonicalizes a complement's inner matcher normally UNLESS
# that inner matcher is itself a complement, in which case it reads as the empty
# set -- so a nested complement becomes the full universe while every
# single-level complement is untouched. That isolates the recursion specifically,
# and it is caught by a failed comparison rather than by a raise (AGENTS.md):
# handing `memv` a vector instead of a list would crash somewhere incidental
# rather than redden the assertion that names the decision.
byte_machine_mutation(
  FILE src/byte-machine/private/ir.sls SPEC byte-machine.unit.byte-class.chez.source
  LABEL "ir: complement canonicalization does not recurse"
  FIND [[(let ((inner (matcher-bytes (byte-complement-matcher-matcher m))))]]
  REPLACE [[(let ((inner (if (byte-complement-matcher? (byte-complement-matcher-matcher m)) (quote ()) (matcher-bytes (byte-complement-matcher-matcher m)))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "nested-complement accepts exactly its class")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> `EXPECT_OUTPUT_MATCHES "accepted exactly the class size"` is a bare check
> label. Measure whether it collides with any other mutant's output in this
> lane; if it does, extend it to a case-name tail plus the check label (for
> example `byte-range accepts exactly its class: accepted exactly the class
> size`). The second pin already carries its case name because the nested
> complement is the only fixture that can witness the recursion.

Then update the totals:

```cmake
# Slice ① Task 5 adds Pass 43 (class membership and recursive canonicalization)
# with two mutations. Passes become 39 + 1 = 40; mutations 177 + 2 = 179.
set(EXPECTED_PASSES 40)
set(EXPECTED_MUTATIONS 179)
```

- [ ] **Step 7: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: exactly one line,
`byte-machine-spec: scheme mutation suite complete (40 passes, 179 mutations)`.

- [ ] **Step 8: Commit**

```bash
git add test/support/harness/byte-machine/test/class-machine.sls test/common/byte-class-interpret-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: all-byte class coverage through the interpreter (§22.7, exit §25:1537)

Five shared class fixtures -- a non-ascending duplicated set, a range, a
complement, a complement of a complement, and an ASCII set -- driven over all
256 byte values with ABSOLUTE expected outcomes, in both execution lanes.

Absolute rather than differential because both executors canonicalize through
the same matcher-bytes: a defect there makes them wrong identically and leaves a
comparison green. Pass 43 pins the two decisions no earlier lane can reach,
since every earlier fixture's matcher is a one-element set."
```

---

## Task 6: The interpreter ≡ generated byte-class differential

**Files:**
- Create: `test/common/differential-byte-class-tests.sps`
- Modify: `test/CMakeLists.txt` (immediately after the Task 5 block)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 43 addition; totals)

**Interfaces:**
- Consumes: `(byte-machine test class-machine)`'s `class-machines` (Task 5);
  `compile-machine`, `emit-machine` (shipped).
- Produces: no new interface.

- [ ] **Step 1: Write the differential program**

Create `test/common/differential-byte-class-tests.sps`:

```scheme
;;; interpreter ≡ generated over all 256 byte values, for every class matcher
;;; kind (parent §18, §22.4, §22.7:1301). Each machine's library is emitted at
;;; run time, loaded, and its compiled-machine obtained by environment/eval; both
;;; executors run through the shared make-parser/parser-feed! API and every
;;; parser-result field is compared.
;;;
;;; The complement fixture is the one that proves the emitter needed no change:
;;; it renders 254 sibling arms inside the single `(case b ...)`, which is
;;; §19.2:1009's "canonical membership code selected for simplicity".
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test class-machine)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.byte-class")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

;; Emit, load and eval one fixture's generated library. The library name is
;; (generated <machine-name>) and the binding is <machine-name>-parser, both
;; derived from the fixture's own name, so the five never collide.
(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (rfields cm b)
  (let ((r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1)))
    (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
          (parser-result-stream-offset r) (parser-result-error r))))

(harness-group "interpreter and generated agree on every byte, for every class"
  (lambda ()
    (for-each
     (lambda (entry)
       (let* ((name (car entry))
              (machine (cadr entry))
              (accepted (caddr entry))
              (cm-ref (make-interpreted-machine (verify-machine machine)))
              (cm-gen (generated-machine name machine)))
         (harness-case (string-append (symbol->string name) " agrees on all 256 bytes")
           (lambda ()
             (let ((bad 'none) (last-byte 'unset))
               (let loop ((b 0))
                 (when (< b 256)
                   (unless (equal? (rfields cm-ref b) (rfields cm-gen b))
                     (when (eq? bad 'none) (set! bad b)))
                   (set! last-byte b)
                   (loop (+ b 1))))
               (check-equal "no byte disagreed" bad 'none)
               (check-equal "loop ran all 256 bytes" last-byte 255))))
         ;; Agreement alone cannot see a defect both executors share, so the
         ;; generated side is also checked against the class ABSOLUTELY -- at
         ;; the class's own lowest byte and at a byte just outside it.
         (harness-case (string-append (symbol->string name) " generated stops on a class byte")
           (lambda ()
             (check-equal "stopped" (car (rfields cm-gen (car accepted))) 'stopped)
             (check-equal "consumed" (caddr (rfields cm-gen (car accepted))) 1)))))
     (class-machines))))

(harness-group "a byte outside the class errors in both, at offset 0"
  (lambda ()
    (harness-case "the ASCII machine rejects byte 0 in both executors"
      (lambda ()
        (let* ((m (make-ascii-machine))
               (cm-ref (make-interpreted-machine (verify-machine m)))
               (cm-gen (generated-machine 'ascii-set m)))
          (check-equal "match" (rfields cm-gen 0) (rfields cm-ref 0))
          (check-equal "generated errors" (car (rfields cm-gen 0)) 'error)
          (check-equal "at offset 0" (list-ref (rfields cm-gen 0) 3) 0))))
    (harness-case "the complement machine rejects byte 10 in both executors"
      (lambda ()
        (let* ((m (make-byte-complement-machine))
               (cm-ref (make-interpreted-machine (verify-machine m)))
               (cm-gen (generated-machine 'byte-complement m)))
          (check-equal "match" (rfields cm-gen 10) (rfields cm-ref 10))
          (check-equal "generated errors" (car (rfields cm-gen 10)) 'error))))))

(harness-finish)
```

> The second group calls `generated-machine` again for two fixtures already
> loaded above. Re-`load`ing a generated library in one process was **measured**
> during plan authoring (see "Verified at plan-authoring time" below) and
> redefines it cleanly. If the AOT lane behaves differently, hoist the five
> `generated-machine` results into top-level definitions and reference those
> instead — decide by running the lane, not by reasoning about it.

- [ ] **Step 2: Register the two lanes**

In `test/CMakeLists.txt`, immediately after the Task 5 lane block:

```cmake
# --- Milestone 3 Slice ①: interpreter≡generated over every class matcher -----
# The complement fixture renders 254 sibling arms inside the single `(case b ...)`
# -- the concrete proof that decision 0014's per-byte lowering needed no emitter
# change.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.byte-class.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.byte-class.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/class-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-byte-class-tests.sps"
  TIMEOUT 180)
```

- [ ] **Step 3: Build and run the new lanes**

```bash
make build && ctest --preset release -R 'byte-machine.differential.byte-class' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 4: Run the whole suite**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 76`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 8`.

- [ ] **Step 5: Add the differential's non-vacuity mutation to Pass 43**

The differential lane is only worth its runtime if a divergence would redden it.
This mutation cannot join Pass 43: a pass runs one
`BYTE_MACHINE_MUTATION_VERIFY_COMMAND`, and its verify command names the
byte-class *interpret* program, not this one. So it gets its own pass, appended
immediately after Pass 43's `byte_machine_mutation_run(...)` line (reproduced as
the first line below for placement) and before the
`byte_machine_mutation_totals(...)` block:

```cmake
byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")

# --- Pass 44: the byte-class differential is non-vacuous (M3 Slice ① Task 6) --
#
# differential-byte-class-tests.sps compares the interpreter against the emitted
# library over all 256 bytes for five class fixtures. Shifting every rendered
# transition byte by one makes the generated executor accept a class shifted one
# byte up, so the comparison diverges at the class's first byte. Verify command
# uses both library roots, an empty object guard, the differential program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/differential-byte-class-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.differential.byte-class.chez.source
  LABEL "compile: every rendered transition byte is shifted by one"
  FIND [[(string-append "               ((" (number->string (car tr)) ") "]]
  REPLACE [[(string-append "               ((" (number->string (+ 1 (car tr))) ") "]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "agrees on all 256 bytes: no byte disagreed")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> The pin above matches five cases' shared tail (`agrees on all 256 bytes`) —
> measure whether one fixture reddens first and, if so, narrow it to that
> fixture's own case name (for example `byte-set agrees on all 256 bytes: no
> byte disagreed`).

Then update the totals:

```cmake
# Slice ① Task 6 adds Pass 44 (byte-class differential non-vacuity) with one
# mutation. Passes become 40 + 1 = 41; mutations 179 + 1 = 180.
set(EXPECTED_PASSES 41)
set(EXPECTED_MUTATIONS 180)
```

- [ ] **Step 6: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: exactly one line,
`byte-machine-spec: scheme mutation suite complete (41 passes, 180 mutations)`.

- [ ] **Step 7: Re-confirm the CMake mutation suite is untouched**

```bash
ctest --preset release -R 'cmake-mutation' -V 2>&1 | grep 'suite complete'
```

Expected: exactly one line,
`byte-machine-spec: mutation suite complete (1 pass, 72 mutations)`.

- [ ] **Step 8: Commit**

```bash
git add test/common/differential-byte-class-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: interpreter≡generated differential over every class matcher

All 256 byte values through both executors for the set, range, complement,
nested-complement and ASCII fixtures, in both execution lanes. The complement
renders 254 sibling arms inside the single (case b ...) -- the concrete evidence
that decision 0014's per-byte lowering needed no emitter change.

Pass 44 makes the lane non-vacuous: shifting every rendered transition byte by
one diverges the two executors."
```

---

## Task 7: Close-out — measured totals and the records that carry them

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake:554-555` (final measured totals)
- Modify: `CHANGELOG.md` (`[Unreleased]`)
- Modify: `docs/plans/milestone-3-design.md` (status line and §5's disposition)
- Modify: `.superpowers/sdd/progress.md` (**never `git add` it**)

**Interfaces:** none.

- [ ] **Step 1: Re-measure everything from scratch**

```bash
make clean && make test-all
```

Expected: `100% tests passed, 0 tests failed out of 76`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 8`.

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|SURVIVES"
```

Record the exact reported `(N passes, M mutations)`. Every `SURVIVES` line must
be one this slice deliberately declared with a written reason; there should be
**two** (both pre-existing runtime survivors from Milestone 2 Slice ③). A third
is a finding: strengthen the test, never loosen the mutation.

- [ ] **Step 2: Reconcile the declared totals with the measurement**

If the reported totals differ from `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`, the
declared numbers are wrong. Correct them and their arithmetic comment in the
same edit, then re-run Step 1 until the run is silent about totals.

- [ ] **Step 3: Re-judge every new pin against its lane's other mutants**

For each pin added in Tasks 1-6, confirm it resolves to exactly one
`(case, check)` pair — a pin that also matches another mutant's output in the
same lane is under-anchored. Capture each mutant's output and compare whole
`FAIL` **records**, not lines. Any pin that turns out to be a substring of the
FAIL-CONTEXT line (`backend=`, `mode=`, `os=`, `architecture=`,
`machine-type=`, `artifacts=`, `scheme`, `mutation`, `harness`, `cmake`,
`direct`) or of the summary line (`status=`, `cases=`, `checks=`, `failures=`)
is a bare nonzero-exit catch and must be replaced.

Record the sweep's scope in the ledger with its qualifier attached — "over the
N pins this slice added, judged against every other mutant in their own lanes"
— not as an unqualified claim.

- [ ] **Step 4: Write the CHANGELOG entry**

Add to `CHANGELOG.md`'s `[Unreleased]` `### Added` section, using the measured
numbers from Step 1 and no others:

```markdown
- Byte classes (Milestone 3 Slice ①): `make-byte-set-matcher`,
  `make-byte-range-matcher`, `make-byte-complement-matcher` and `ascii-bytes` on
  the public construction façade, canonicalized to subsets of `0..255` by one
  shared spine and lowered to one normalized transition per byte
  ([decision 0014](docs/decisions/0014-byte-classes-expand-per-byte.md)).
  Degenerate shapes — an empty byte set, a range with `low > high` — are
  constructor contract violations
  ([decision 0017](docs/decisions/0017-degenerate-shapes-are-contract-violations.md));
  duplicate bytes and a vacuous complement are not. `pass-overlap` now reports
  one diagnostic per colliding pair of cases across mixed matcher kinds. The
  normalized encoding, its format version byte, the emitter and the runtime are
  unchanged: all three pinned IR fingerprints and both committed goldens are
  byte-identical.
```

Also update the `[Unreleased]` preamble's milestone sentence to say Milestone 3
is **in progress**, with Slice ① closed and Slices ② and ③ open.

- [ ] **Step 5: Update the design document's status line and §5**

In `docs/plans/milestone-3-design.md`, change the status line from
"Gate 0 discharged; Slices ①–③ not started" to record Slice ① closed with its
date and PR, and add a dated blockquote under §5 dispositioning its six items —
**dispositioned, not reworded** (AGENTS.md: an exit criterion whose work has
closed becomes the record of what was asked). The disposition must name the two
places this plan departed from §5, each with its reason:

1. §5's rider that adding matcher predicates and accessors closes
   `graph-tests.sps:5`'s reach into `(byte-machine private ir)` — line 5 imports
   *machine* accessors, which no matcher export supplies (§0 D5).
2. §5's "Mutation pins that die in this slice" list, which names
   `SchemeMutationSuite.cmake:2967` but not `:3267`, which dies for the same
   reason at the same time (§0 D9).

- [ ] **Step 6: Sweep the status surfaces that this slice does *not* close**

Slice ① opens Milestone 3's product work but does not close the milestone, so
`README.org`'s status paragraph and the parent plan's Status line correctly
still say Milestone 3 has not closed. Confirm mechanically rather than by
memory:

```bash
grep -n 'Milestone 3' README.org docs/plans/byte-machine-implementation-plan.md | head -20
```

Expected: `README.org:18` still reads that Milestone 3 "has not started" — which
is now **false** and must be corrected to "is in progress" (a status line is an
instruction, corrected in place, not a record). Read the parent plan's hit and
correct it the same way if it makes the same claim.

- [ ] **Step 7: Final whole-suite run**

```bash
make test-all && ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep 'suite complete'
```

Expected: `100% tests passed, 0 tests failed out of 76`, then exactly one
`scheme mutation suite complete (...)` line matching the declared totals.

- [ ] **Step 8: Commit**

```bash
git add CHANGELOG.md docs/plans/milestone-3-design.md README.org docs/plans/byte-machine-implementation-plan.md test/support/cmake/SchemeMutationSuite.cmake
git commit -m "docs: close Milestone 3 Slice ① with measured totals

CHANGELOG entry for byte classes; the design document's status line and a dated
disposition of its §5, naming the two places this plan departed from it and why;
the README and parent-plan status lines corrected from 'has not started' to
'in progress'. Every count written here was re-measured against the shipped
tree, not carried from the plan's prediction."
```

- [ ] **Step 9: Update the ledger** (`.superpowers/sdd/progress.md`, never staged)

Record: the measured release/pr, no-scheme and mutation totals; the two design
departures; the two pin re-anchors and what each cost to re-measure; anything
found during Step 3's pin sweep, with its qualifier attached.

---

## Self-Review

**Spec coverage (design §5 and §25:1527-1528, exit :1537).**

| requirement | task |
| --- | --- |
| §25:1527 canonical byte sets, ranges, complements, ASCII helper | 2 |
| §25:1528 byte-class overlap verification | 3 |
| exit §25:1537 all-byte class tests pass | 5, 6 |
| design §5.1 canonicalization spine, three consumers, byte-identical gate | 1 |
| design §5.2 constructors, `ascii-bytes`, widened guard, degenerate rejections, façade exports | 2 |
| design §5.3 rewritten `pass-overlap`, one diagnostic per colliding pair | 3 |
| design §5.4 normalizer lowering; emitter zero change recorded | 1 (code), 4 (proof and record) |
| design §5.5 interpreter matcher dispatch through the canonical form | 1 |
| design §5.6 all-256 class, complement and ASCII lanes, both executors, both execution lanes | 5, 6 |
| design §5 "passes that must not be touched" | §0 D11 |
| design §5 mutation-pin re-anchoring | 1 (both pins), §0 D9 |
| design §9 lane and manifest bookkeeping | 5, 6 |
| design §9 completion sentinels | 5, 6 |
| design §9 measured numbers only | Global Constraints, 7 |
| decision 0014 points 1-4 | 1, 2, 4 |
| decision 0017 points 1-3 | 2 |
| decision 0017 point 4 (sequence alternatives) | **out of scope — Slice ②/③** |

**Out of scope, from design §8 and confirmed absent from every task above:**
sequence dispatch and any sixth node kind; trie or class-table specialization;
the structured parser-error record; widening the diagnostic record to §16.4's
seven fields; extending `machine-gen.sls` to draw class matchers; the
state-ID-to-source-name debug map; the §16.2:884 IR-version check;
case-insensitive HTTP token recognition; cross-node prefix sharing; any
`runtime.sls` change or `/v3` ABI; any lookahead; a `source-label` parameter on
a matcher constructor.

**Type consistency.** `matcher-bytes` returns an ascending duplicate-free proper
list of exact integers everywhere it is named (§0 D2; Tasks 1, 2, 4, 5).
`byte-sets-overlap?` takes two such lists and returns a boolean, introduced in
Task 1 with the body Task 3 preserves (§0 D10). `class-machines` returns a list
of `(name machine accepted-bytes)` triples, consumed positionally by
`car`/`cadr`/`caddr` in both Task 5 and Task 6. `ascii-bytes` returns a list, so
it composes directly with `make-byte-set-matcher` in Tasks 2, 5 and the fixture
library. Machine names (`byte-set`, `byte-range`, `byte-complement`,
`nested-complement`, `ascii-set`) satisfy `[a-z][a-z0-9-]*`, and the derived
bindings (`byte-set-parser`, …) satisfy `valid-binding?` and are absent from all
three reserved members.

**Verified at plan-authoring time (2026-08-29), against a scratch tree carrying
Tasks 1-3's source edits, driven through Chez 10.4.1 outside the harness.** Every
literal this plan asserts about pure behaviour was computed rather than
predicted: `(0 1 2 254 255)` for the unsorted duplicated set; `(48 … 57)` for the
range and for the doubly-complemented range; 256 for `0..255`; `(9)` for
`low = high`; 254 for the complement of `{10,13}`; `()` for the vacuous
complement; `(71 69 84)`, `(97 97)`, `()` and `(127)` for `ascii-bytes`; the four
`(48 1 advance) …` transitions; `(2 5 9)`; `(1 4 5 9)`; 254, `()` and 256
transition counts; overlap counts 0, 0, 1, 1, 1, 3, 1, 1 for the eight verifier
fixtures in Task 3's order; clean verification for all five class machines;
`hits` equal to the class size and zero interpreter/generated disagreement over
all 256 bytes for each of the five; and the one-byte IR fingerprint still
`4236938459847922092` after the lowering change. The three edited libraries and
the rewritten `graph.sls` each parse as exactly one library form.

**That measurement describes a driver, not the shipped lanes** (repo precedent:
a number from a throwaway driver describes the driver). The values above are
pure-function results and are driver-independent, but every count that reaches a
record — lane totals, mutation totals, failure signatures — is re-measured
through the harness by the task that writes it, and by Task 7.

**Known residue, to be measured rather than assumed during execution.** Every
`EXPECT_OUTPUT_MATCHES` in this plan is a *predicted* first-failing
`(case, check)` pair. The plan says so at each site and Task 7 Step 3 sweeps
them. A pin written from this document without running its mutant is exactly the
defect AGENTS.md's "a plan's verification step whose expected result is prose is
not a check" rule was written about.
