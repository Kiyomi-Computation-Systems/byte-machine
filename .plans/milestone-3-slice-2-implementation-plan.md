# Milestone 3 Slice ② — Sequence Dispatch and Prefix Lowering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land sequence dispatch — the sixth node kind in a repertoire closed at
five — with trie-shaped prefix lowering into ordinary dispatch states, two-phase
state-id allocation, an independently derived interpreter representation, and
both mismatch modes, proved against a machine already on `main`.

**Architecture:** A sequence node lowers to ordinary normalized `dispatch`
states: no new state kind, no new encoding tag, no emitter arm, no ABI movement
(decision 0015). Its alternatives are merged into a **trie**, so alternatives
that agree on a byte descend into one shared state — which is what keeps the
normalizer's ascending-by-byte sort a total order (decision 0016). The reference
interpreter tracks prefix progress in a compound `current` derived independently
of the normalizer, because that independence is the only thing that lets the
interpreter≡generated differential catch a lowering defect (§18:970-972).

**Tech Stack:** R6RS Scheme (Chez 10.4.1), CMake/CTest lanes, the in-repo
mutation suite (`test/support/cmake/SchemeMutationSuite.cmake`).

Design authority: [milestone-3-design.md](./milestone-3-design.md) §6 (Slice ②),
§3, §4.2, §4.3, §4.4, and its appendix; decisions
[0015](../.decisions/0015-sequence-prefix-states.md) and
[0016](../.decisions/0016-normalized-state-id-allocation.md), with
[0017](../.decisions/0017-degenerate-shapes-are-contract-violations.md) point 4
governing what is *not* a constructor error; parent plan
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
§9.1:297-298 and :318/:322, §10.6:542-546, §11.3:648, §11.4:652, §11.5:664,
§12.4:727, §16.2:894, §17:951/:957, §18:970-972, §19.2:1010, §22.4, §22.5,
§25:1529-1531 and exit :1538.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Baselines to hold, measured 2026-08-30 on `main` = `2468881`** (Darwin
  arm64, Chez 10.4.1): `ctest --preset release` **76/76**, `--preset pr`
  **76/76**, `--preset no-scheme` **8/8**, Scheme mutation suite **41 passes /
  186 mutations** (9 declared `EXPECT_SURVIVES`), CMake mutation suite **1 pass
  / 72 mutations**. Every task ends with these — plus that task's own additions
  — green.
- **The three pinned IR fingerprints and both committed goldens must not move.**
  `4236938459847922092` (one-byte), `9098559711816935340` (node-routing
  eof-machine), `15725897457025557005` (pause-machine);
  `test/fixtures/generated-one-byte.golden.sls` and
  `test/fixtures/generated-pause.golden.sls`. Decision 0016 point 2 is the
  warrant: name resolution resolves *names*, and `encode-normal` walks the
  states vector positionally without ever writing a state's own id, so a machine
  with no sequence node normalizes and encodes exactly as before. **Verified
  during plan authoring** against a prototype carrying every source change in
  Tasks 1-3: the one-byte fingerprint came out `4236938459847922092` unchanged.
- **The encoding-format version byte stays `1`** (`normal-ir.sls`
  `(put-u8 p 1)`); **no new state-kind tag byte**; **no `/v3` ABI**; **no
  `runtime.sls` change**. `current` is opaque to the runtime — it is stored,
  handed to the executor, and restored by `parser-reset!`, and nothing tests its
  shape — so a compound value flows through feed, `need-input`, finish and reset
  untouched.
- **Chez floor 10.4.1, CMake floor 3.26. No new dependencies** — only `(rnrs)`
  and in-repo libraries.
- **`(byte-machine interpret)` must not import any normalizer library, and must
  not share a prefix-walking helper with one** (§18:970-972, decision 0015
  point 3). A reviewer should treat a proposal to factor "the shared prefix
  walker" into a common library as a change to decision 0015, not a refactor.
- **Interpreter prefix state may not be closed over the compiled machine**
  (decision 0015 point 4). One compiled machine serves arbitrarily many parsers;
  prefix progress lives in the parser's own `current`.
- **Exit-status vocabulary is exactly 0, 1, 2, 3.** This slice adds no new exit
  path; every task still re-runs the *whole* mutation suite.
- **Mutation discipline** (AGENTS.md): every decision gets a mutation whose
  catch asserts a **measured** failure signature — `EXPECT_STATUS` **plus**
  `EXPECT_OUTPUT_MATCHES` — never a bare nonzero exit. A pin must resolve to
  exactly one `(case, check)` pair, not one case: the FAIL grammar is
  `byte-machine-harness: FAIL <group>.<case>: <what> -- <detail>`.
  `EXPECT_OUTPUT_MATCHES` is an unanchored CMake regex, so `(`, `)`, `.` need
  `\(`, `\)`, `\.` (written `\\(` etc. in the file). A pin that is a substring
  of the FAIL-CONTEXT line (`backend=`, `mode=`, `os=`, `architecture=`,
  `machine-type=`, `artifacts=`, `scheme`, `mutation`, `harness`, `cmake`,
  `direct`) or the summary line (`status=`, `cases=`, `checks=`, `failures=`)
  is a bare nonzero-exit catch. Prefer a mutation caught by a **failed
  comparison** over one caught by a raise; try the opposite constant first.
- **Sweep pins in BOTH directions.** Adding a mutation to a lane widens every
  existing pin's collision set there — *and* an existing mutant may match the
  pin you are adding. Slice ①'s Task 4 did only the first half and left decision
  0014's headline claim pinned to a signature two mutations produce. Run a
  control on the merge base: a pass collision-free there and colliding at HEAD
  is this branch's doing. Record a genuinely **subsumed** residue in the tree
  beside the pin, named by mutation LABEL — the ledger is git-ignored.
- **`SITES` defaults to 1 and is asserted exactly.** A `FIND` whose text an edit
  changes fails the suite with "found 0, expected 1", so a pin whose line a task
  edits is re-anchored in **the same commit**.
- **Predicted counts are arithmetic to check, never facts to write down.**
  Re-measure release/pr, no-scheme and both mutation totals before any number
  enters `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`, the CHANGELOG, a decision
  record, or a design document. Prediction: release/pr **80** (76 + 4 lanes),
  Scheme mutation **43 passes / ~205 mutations**. Slice ① predicted 41/180 and
  measured 41/186; M2 Slice ③ predicted ~145 and measured 165. Design §9 calls
  sizing a floor, not an estimate.
- **Completion sentinels are mandatory, and must read the OBSERVED value.** No
  suite declares an expected case or check count; `harness-summary` reports only
  what ran, so an exhaustive loop that never executes **passes vacuously**.
  Slice ① shipped a counter incremented from the test's own expected list — it
  equalled the expected total for every possible machine behaviour and closed
  nothing. Derive counters from what the parser returned, and give the loop over
  the loops a sentinel too.
- **Lane and manifest bookkeeping is fatal-on-error.** Source + AOT pair per
  program, each with a `TIMEOUT` and a unique five-segment lowercase name
  matching `^byte-machine\.([a-z0-9-]+)\.([a-z0-9-]+)\.([a-z0-9-]+)\.([a-z0-9-]+)$`;
  feature segments must not begin or end with a hyphen; any new fixture `.sls`
  in **both** lanes' `SOURCES`; basenames unique within a lane. Duplicate CTest
  names are a configure-time `FATAL_ERROR` — and
  `byte-machine.differential.sequence.chez.{source,aot}` is **already taken** by
  the Milestone 2 chained-dispatch machine (`test/CMakeLists.txt:968-987`).
  Anyone grepping `sequence` in this tree will conclude half of M3 already
  ships. A new `.sls` changes the lane's content fingerprint, recomputed at
  build time from `SOURCES`; there is nothing committed to update by hand, but
  **rebuild after editing a test file** or the provenance check correctly fails
  on a stale build.
- **`.superpowers/sdd/` is git-ignored: never `git add` it.**
- Conventional Commits; run the suite before every commit; match the touched
  file's comment style and `mode` vocabulary.
- Commands: `make build`; `make test-all`; one lane
  `ctest --preset release -R '<lane>' --output-on-failure`; no-scheme
  `cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure`;
  mutation totals
  `ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"`.

---

## §0 Design calls locked by this plan

These resolve what design §6 leaves to writing-plans, and correct three places
where the design's own text does not survive contact with the tree. Implementers
do not re-litigate them; a **measured** contradiction is a plan defect to record
in the ledger and fix.

**D1 — The interpreter's compound `current` carries the consumed byte PATH, not
a position index. Design §4.2's `(s . k)` is insufficient and would ship a
silent miscompile.**

Design §4.2 illustrates the compound value as `(s . k)` — sequence name and
prefix position. Decision 0015 point 3 itself says only "a compound `current`
value"; the `(s . k)` literal is the design document's, not the record's.

A bare position index is wrong the moment two alternatives diverge at position
0. With alternatives `AB` and `XY`, after consuming `A` the state is `(s . 1)`;
feeding `Y` then finds that *some* alternative has `Y` at position 1 and
follows `XY` — accepting a sequence that was never on the input. **Measured
during plan authoring:** with the path representation, `A` then `Y` yields
`(error 1 unexpected-byte)` (correct mismatch); a position index accepts.

So `current` is `(name . path)` where `path` is the byte list consumed so far
inside the sequence, in order, and the live alternatives at any point are those
having `path` as a proper prefix. Position `k` is `(length path)`, so nothing in
decision 0015's reasoning changes — only the representation that realizes it.
For a single alternative the two are equivalent, which is why the M2 oracle
cannot distinguish them and why this must be settled here rather than left to
Slice ③'s fixtures.

**This is a design-record defect to disposition, not to silently route around.**
Task 6 adds a dated amendment to design §4.2 recording that `(s . k)` was
measured insufficient and what replaced it. Decision 0015's own text needs no
amendment — it never named the representation.

**D2 — There are SEVEN permissive verifier fall-throughs, not six.** Design §6
says "six sites" and then enumerates seven line references; its appendix repeats
"all six permissive fall-throughs" with the same seven. Counted against the tree
at `main` = `2468881` (line numbers current, not the design's pre-Slice-① ones):

| # | site | `verify.sls` | what it must learn |
| --- | --- | --- | --- |
| 1 | `node-out-targets` `(else '())` | `:57` | every case target plus the mismatch edge target |
| 2 | `all-out-targets`' `byte-dispatch-node?` conditional | `:59-63` | the sequence node's eof-target |
| 3 | `reexec-targets` `(else '())` | `:179` | the mismatch edge when its mode is `reexecute` |
| 4 | `pass-eof`'s `byte-dispatch-node?` filter | `:206` | eof-target resolution |
| 5 | `eof-terminal`'s `(else 'unknown)` | `:228` | walk the sequence node's eof-target |
| 6 | `pass-eof-execution`'s §16.2:908 filter | `:243` | a sequence byte edge into a finish terminal |
| 7 | `pass-eof-execution`'s §16.2:909 filter | `:257` | walk the sequence node's eof chain |

Site 1 also repairs `pass-names`' missing-target resolution (`:101-107` region)
and `byte-reached` (`:234`) for free, since both walk `node-out-targets`.

> **Disposition, 2026-08-30 (whole-branch review fix wave; Slice ② closed).**
> D2's own "SEVEN, not six" count above is itself superseded, not the final
> word: Task 1's own review found an **eighth** permissive fall-through,
> `pass-overlap` (§16.2:893 canonical byte-set overlap), which stayed
> filtering on `byte-dispatch-node?` alone when the other seven landed —
> correct, since §16.2:894 cross-alternative sequence collision is Slice ③'s
> per decision 0017 point 4 and design §7, but undocumented at the time this
> D2 was written. The binding correction lives at design §6's own dated
> disposition ("Disposition, 2026-08-30 (Task 6 close-out; Slice ② closed)"),
> which names this D2 by section as one of the two counts its "eight"
> supersedes and re-derives the total directly from the shipped `verify.sls`
> rather than from either prior count: **six** sites extended to the sixth
> kind (`node-out-targets`; `node-eof-target`, into which three of the seven
> above collapsed; `reexec-targets`; `eof-terminal`; and both
> `pass-eof-execution` filters) plus **two** deliberately left unextended
> (`pass-overlap`, and D3's own report guard, immediately below). D2's table
> above is left as written — this plan is not the artifact design §6's
> disposition edited — but a reader who stops at D2 alone would still
> undercount `verify.sls`'s permissive fall-throughs by one.

**D3 — `pass-zero-progress`'s report guard at `:190` is deliberately NOT
extended here.** It reads
`(or (byte-dispatch-node? n) (pause-node? n))`, and adding sequence nodes to the
*reported* set is §25:1533's cycle extension, which design §7 assigns to
Slice ③. Site 3 above (`reexec-targets`) **is** extended, so the walk sees
*through* a sequence node's reexecute mismatch edge and other nodes' cycles are
still detected correctly. Extending the walk without extending the report is the
right split, and it is the seam most likely to be "fixed" by mistake: a
self-targeting sequence node not being flagged in Slice ② is correct.

**D4 — The two degenerate trie shapes are internal assertion violations in BOTH
implementations, not verifier diagnostics.** A trie node that is both terminal
and interior (`AB` with `ABC`) has no representation: decision 0015 point 2 says
a prefix state has no "accept here" slot. Two identical alternatives are the
maximal case of the same thing. Decision 0017 point 4 leaves both to the
verifier — and that verifier check is **Slice ③'s** (§16.2:894), so between ②
and ③ such a node is constructible and verifies clean.

Design §6 and the Gate 0 ledger both call for a **two-line internal guard, not a
designed-and-deleted refusal**. This plan puts the guard in the normalizer's
trie builder *and* in the interpreter's step function, raising
`assertion-violation` with the same two messages — `"ambiguous terminal prefix"`
and `"duplicate sequence alternative"` — so the two implementations agree on
what is unrepresentable rather than one accepting what the other rejects.
**Measured:** both fire, with matching messages, on `AB|ABC` and `AB|AB`.

**D5 — Trie representation and id allocation.** A trie node is
`(children . terminal)`; `children` is an association list `(byte . node)` kept
**ascending by byte**, which is what makes decision 0016 point 1's pre-order
total. Ids are allocated **depth-first pre-order**, taking each node's children
in ascending byte order, over the **interior non-root** nodes only: the root is
the declared node's own state and keeps its declaration index, and a **terminal**
child consumes no id because its byte routes straight to that alternative's
declared target.

DFS pre-order is observably different from breadth-first, so it is pinned by a
fixture rather than left to whichever the lowering happens to build. **Measured**
on alternatives `AB` / `ACD` / `XY` with five declared nodes: internal ids come
out `5` (child of `A`), `6` (child of `C`, nested under 5), `7` (child of `X`).
Breadth-first would give `5`, `7`, `6`.

**D6 — `sequence-case-bytes` returns a copy.** Slice ①'s whole-branch review
closed both aliasing routes on `byte-set-matcher-bytes` — the constructor storing
the caller's list and the accessor handing the chain back — because §9.1 says
constructors "return immutable-by-API descriptors". The same applies here.
Copying is not the semantic transform §9.1:322 forbids: order and duplicates are
preserved. Use `(append lst '())`; `list-copy` is **not** in R6RS `(rnrs)`
(verified by a failing Chez load during Slice ①).

**D7 — Fixtures and lanes.** One shared fixture library
`test/support/harness/byte-machine/test/sequence-node-machine.sls` exporting both
mismatch-mode machines, driven by two programs:
`byte-machine.unit.sequence-node.chez.{source,aot}` (absolute) and
`byte-machine.differential.sequence-node.chez.{source,aot}` (interpreter ≡
generated). Both are required for the same reason Slice ① needed both: a defect
in a code path both executors share is invisible to a comparison. `sequence-node`
is a legal five-segment feature name and does not collide with the M2
`differential.sequence` lanes.

**D8 — Out of scope, from design §7 and §8.** The ambiguous-terminal-prefix
*diagnostic* and its new diagnostic code; multi-alternative *fixtures* driven
end to end; the §25:1533 zero-progress/EOF-cycle extension for sequence nodes;
determinism pins for sequence machines; the `HTTP/1.0`⁄`HTTP/1.1` fixture — all
Slice ③. Also out: cross-node prefix sharing; the structured parser-error record
(so this slice's mismatch tests assert `status`/`next`/`consumed`/
`stream-offset`/`code` only, and that limitation is **recorded** when discharging
§25:1538); extending `machine-gen.sls`; the state-ID-to-source-name debug map;
any general lookahead or rewind.

Note the *lowering* is trie-shaped and multi-alternative-capable from this slice,
and Tasks 2-3 pin that with unit-level fixtures — what stays single-alternative
is the **executed** fixture, because the M2 oracle this slice must reproduce is a
single-alternative machine.

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `src/byte-machine/private/ir.sls` (modify) | `make-sequence-dispatch-node`, `make-sequence-case`, predicates and accessors; both added to `node?` and `node-name` | 1 |
| `src/byte-machine/graph.sls` (modify) | export list **and** `only` import list gain the two constructors, predicates and accessors | 1 |
| `src/byte-machine/verify.sls` (modify) | all seven arms of D2, in the same commit as the node kind | 1 |
| `src/byte-machine/private/normal-ir.sls` (modify) | trie builder with D4's guards; two-phase id allocation; sequence arm replacing part of the `else` at `:130` | 2 |
| `src/byte-machine/interpret.sls` (modify) | compound `current` per D1; `kind`/`dispatch`/`eof-target` destructuring; D4's guards | 3 |
| `src/byte-machine/compile.sls` | **no change** — confirmed and recorded, plus the `reserved-member-3` check | 3 |
| `src/byte-machine/runtime.sls` | **no change** | — |
| `test/common/ir-tests.sps`, `graph-tests.sps` (modify) | constructor local-shape and façade cases | 1 |
| `test/common/verify-tests.sps` (modify) | one case per arm | 1 |
| `test/common/normal-ir-tests.sps` (modify) | trie shapes, id allocation, the guards, and the amended declaration-index case citing 0016 | 2 |
| `test/common/interpret-tests.sps` (modify) | compound-`current` unit cases including the `AB`/`XY` divergence | 3 |
| `test/support/harness/byte-machine/test/sequence-node-machine.sls` (create) | both mismatch-mode proving machines | 4 |
| `test/common/sequence-interpret-tests.sps` (create) | absolute outcomes through the interpreter | 4 |
| `test/common/differential-sequence-node-tests.sps` (create) | the M2 oracle reproduced, both modes | 5 |
| `test/CMakeLists.txt` (modify) | four new lanes | 4, 5 |
| `test/support/cmake/SchemeMutationSuite.cmake` (modify) | new passes and mutations; totals | 1-5 |
| `CHANGELOG.md`, `.plans/milestone-3-design.md` (modify) | measured close-out and the D1 amendment | 6 |

---

## Task 1: The sixth node kind and every verifier arm, in one commit

**Files:**
- Modify: `src/byte-machine/private/ir.sls` (export list; new section before `;; --- node dispatch ---`; `node?`; `node-name`)
- Modify: `src/byte-machine/graph.sls` (export list **and** `only` import list)
- Modify: `src/byte-machine/verify.sls` (seven sites per §0 D2)
- Test: `test/common/ir-tests.sps`, `test/common/graph-tests.sps`, `test/common/verify-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Why one commit.** This is the milestone's second structural hazard.
`normal-ir.sls:130` and `compile.sls:130` both end their kind dispatch with an
assertion violation, so a sixth kind fails loudly there. `verify.sls` does the
**opposite** at all seven sites: a sequence node added to `ir.sls` but not to
`verify.sls` **verifies clean** — targets never resolution-checked, cycles never
detected, EOF chain never walked — and only crashes later in the normalizer.
That is the worst possible failure ordering. The one exception is reachability:
an unextended `all-out-targets` produces a *loud but false* `'unreachable-node`
on every successor only a sequence reaches, which reads as a user grammar error
rather than a verifier gap.

**Interfaces:**
- Produces:
  - `(make-sequence-case bytes target source-label)` → sequence case. `bytes` is
    a non-empty proper list of exact integers `0..255` (decision 0017 point 1
    rejects the empty sequence); `target` is a symbol. Rejects otherwise with
    code `invalid-argument`, details `bytes` / `target`. A length-1 sequence is
    **legal** (decision 0017 point 2). Duplicate bytes within one alternative
    are legal.
  - `(sequence-case? x)`, `(sequence-case-bytes c)` → a **copy** (§0 D6),
    `(sequence-case-target c)`.
  - `(make-sequence-dispatch-node name cases mismatch eof-target source-label)`
    → node. `cases` a non-empty proper list of sequence cases; `mismatch` a full
    **edge** (target + mode); `eof-target` a symbol or `#f`. Details `cases` /
    `mismatch` / `eof-target`.
  - `(sequence-dispatch-node? x)`, `-name`, `-cases`, `-mismatch`,
    `-eof-target`.
  - `node?` and `node-name` accept the new kind — without this,
    `make-machine`'s `(for-all node? nodes)` rejects the node outright.
- Consumes: `edge?`, `edge-target`, `edge-mode`, `byte-value?`,
  `require-symbol`, `tag`/`tagged?` (all already in `ir.sls`).

**The asymmetry between the two constructors is deliberate and not a mistake.**
`make-sequence-dispatch-node` carries a full mismatch **edge** while
`make-sequence-case` carries a bare **target**, because a successful sequence
consumes every byte in it (§10.6:546) — giving a case an advance/reexecute mode
would reintroduce the lookahead :546 forbids. Design §3 records this.

- [ ] **Step 1: Write the failing constructor tests**

Append to `test/common/ir-tests.sps`, before `(harness-finish)`. Reuse the
file's existing `contract-violation?` helper (it takes a `who` and a detail):

```scheme
(harness-group "the sequence node and its cases (parent §9.1:297-298)"
  (lambda ()
    (harness-case "a sequence case carries its bytes and target"
      (lambda ()
        (let ((c (make-sequence-case '(1 2 3) 'stop #f)))
          (check "is a sequence case" (sequence-case? c))
          (check-equal "bytes" (sequence-case-bytes c) '(1 2 3))
          (check-equal "target" (sequence-case-target c) 'stop))))
    (harness-case "the bytes accessor returns a copy, not the stored chain"
      (lambda ()
        (let ((c (make-sequence-case '(1 2 3) 'stop #f)))
          (check "not eq" (not (eq? (sequence-case-bytes c) (sequence-case-bytes c))))
          (check-equal "still equal" (sequence-case-bytes c) '(1 2 3)))))
    (harness-case "a length-1 sequence is legal (decision 0017 point 2)"
      (lambda ()
        (check-equal "single" (sequence-case-bytes (make-sequence-case '(7) 'stop #f)) '(7))))
    (harness-case "duplicate bytes inside one alternative are legal"
      (lambda ()
        (check-equal "aa" (sequence-case-bytes (make-sequence-case '(97 97) 'stop #f)) '(97 97))))
    (harness-case "an empty sequence is rejected (decision 0017 point 1)"
      (lambda ()
        (check-raises "empty" (contract-violation? 'make-sequence-case 'bytes)
                      (lambda () (make-sequence-case '() 'stop #f)))))
    (harness-case "a non-byte inside a sequence is rejected"
      (lambda ()
        (check-raises "256" (contract-violation? 'make-sequence-case 'bytes)
                      (lambda () (make-sequence-case '(1 256) 'stop #f)))))
    (harness-case "a non-symbol target is rejected"
      (lambda ()
        (check-raises "target" (contract-violation? 'make-sequence-case 'target)
                      (lambda () (make-sequence-case '(1) 42 #f)))))
    (harness-case "a sequence node carries its cases, mismatch edge and eof-target"
      (lambda ()
        (let* ((c (make-sequence-case '(1 2) 'stop #f))
               (mm (make-edge 'reject 'reexecute))
               (n (make-sequence-dispatch-node 'seq (list c) mm 'done #f)))
          (check "is a sequence node" (sequence-dispatch-node? n))
          (check-equal "name" (sequence-dispatch-node-name n) 'seq)
          (check-equal "case count" (length (sequence-dispatch-node-cases n)) 1)
          (check-equal "mismatch target" (edge-target (sequence-dispatch-node-mismatch n)) 'reject)
          (check-equal "mismatch mode" (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
          (check-equal "eof-target" (sequence-dispatch-node-eof-target n) 'done))))
    (harness-case "an eof-target of #f is legal and means the default eof error"
      (lambda ()
        (check-equal "false"
                     (sequence-dispatch-node-eof-target
                      (make-sequence-dispatch-node
                       'seq (list (make-sequence-case '(1) 'stop #f))
                       (make-edge 'reject 'reexecute) #f #f))
                     #f)))
    (harness-case "an empty case list is rejected"
      (lambda ()
        (check-raises "no cases" (contract-violation? 'make-sequence-dispatch-node 'cases)
                      (lambda () (make-sequence-dispatch-node
                                  'seq '() (make-edge 'reject 'reexecute) #f #f)))))
    (harness-case "a bare target handed in as the mismatch edge is rejected"
      (lambda ()
        (check-raises "not an edge" (contract-violation? 'make-sequence-dispatch-node 'mismatch)
                      (lambda () (make-sequence-dispatch-node
                                  'seq (list (make-sequence-case '(1) 'stop #f))
                                  'reject #f #f)))))
    (harness-case "a sequence node is a node, and reports its own name"
      (lambda ()
        (let ((n (make-sequence-dispatch-node
                  'seq (list (make-sequence-case '(1) 'stop #f))
                  (make-edge 'reject 'reexecute) #f #f)))
          (check "node?" (node? n))
          (check-equal "node-name" (node-name n) 'seq))))))
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
ctest --preset release -R 'byte-machine.unit.ir.chez.source' --output-on-failure
```

Expected: exit 1, output contains
`Exception: variable make-sequence-case is not bound`.

- [ ] **Step 3: Add the node kind to `ir.sls`**

Extend the export list — insert immediately before the `node? node-name` line:

```scheme
          make-sequence-dispatch-node sequence-dispatch-node?
          sequence-dispatch-node-name sequence-dispatch-node-cases
          sequence-dispatch-node-mismatch sequence-dispatch-node-eof-target
          make-sequence-case sequence-case? sequence-case-bytes sequence-case-target
```

Insert this section immediately **before** the `;; --- node dispatch ---`
comment:

```scheme
  ;; --- sequence case (§9.1:298) ---
  ;; A byte list and a bare TARGET, with no mode. A successful sequence consumes
  ;; every byte in it (§10.6:546), so giving a case an advance/reexecute mode
  ;; would reintroduce the lookahead :546 forbids. The mismatch EDGE on the node
  ;; below carries the only mode a sequence has. The accessor copies for the same
  ;; reason byte-set-matcher-bytes does: §9.1 says constructors return
  ;; immutable-by-API descriptors, and a copy preserves order and duplicates, so
  ;; it is not the semantic transform §9.1:322 forbids.
  (define sequence-case-tag (tag 'byte-machine-sequence-case))
  (define (make-sequence-case bytes target source-label)
    (unless (and (list? bytes) (pair? bytes) (for-all byte-value? bytes))
      (byte-machine-contract-violation 'make-sequence-case 'invalid-argument 'bytes))
    (require-symbol 'make-sequence-case 'target target)
    (vector sequence-case-tag (append bytes '()) target source-label))
  (define (sequence-case? x) (tagged? sequence-case-tag x))
  (define (sequence-case-bytes c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-bytes 'invalid-argument 'case))
    (append (vector-ref c 1) '()))
  (define (sequence-case-target c)
    (unless (sequence-case? c)
      (byte-machine-contract-violation 'sequence-case-target 'invalid-argument 'case))
    (vector-ref c 2))

  ;; --- sequence-dispatch node (§9.1:297, §10.6:542-546) ---
  ;; The sixth node kind. Matches one of a finite set of exact byte sequences
  ;; without backtracking; alternatives may share nonterminal prefixes. Whether
  ;; two alternatives collide is a cross-case property, so it is verification's
  ;; job, not this constructor's (decision 0017 point 4).
  (define sequence-dispatch-node-tag (tag 'byte-machine-sequence-dispatch-node))
  (define (make-sequence-dispatch-node name cases mismatch eof-target source-label)
    (require-symbol 'make-sequence-dispatch-node 'name name)
    (unless (and (list? cases) (pair? cases) (for-all sequence-case? cases))
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'cases))
    (unless (edge? mismatch)
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'mismatch))
    ;; eof-target is a node name, or #f for the machine default eof error.
    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-sequence-dispatch-node 'invalid-argument 'eof-target))
    (vector sequence-dispatch-node-tag name cases mismatch eof-target source-label))
  (define (sequence-dispatch-node? x) (tagged? sequence-dispatch-node-tag x))
  (define (sequence-dispatch-node-name n) (vector-ref n 1))
  (define (sequence-dispatch-node-cases n) (vector-ref n 2))
  (define (sequence-dispatch-node-mismatch n) (vector-ref n 3))
  (define (sequence-dispatch-node-eof-target n) (vector-ref n 4))
```

Then extend `node?` and `node-name`:

```scheme
  (define (node? x)
    (or (byte-dispatch-node? x) (sequence-dispatch-node? x) (stop-node? x)
        (error-node? x) (finish-node? x) (pause-node? x)))
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((sequence-dispatch-node? x) (sequence-dispatch-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          ((finish-node? x) (finish-node-name x))
          ((pause-node? x) (pause-node-name x))
          (else (byte-machine-contract-violation 'node-name 'invalid-argument 'node))))
```

- [ ] **Step 4: Run the ir lane and confirm it passes**

```bash
ctest --preset release -R 'byte-machine.unit.ir.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 5: Extend the `graph.sls` façade**

Add to **both** the `export` list and the `only` import list — they must stay in
step, and both are explicit:

```scheme
          make-sequence-dispatch-node make-sequence-case
          sequence-dispatch-node? sequence-dispatch-node-name
          sequence-dispatch-node-cases sequence-dispatch-node-mismatch
          sequence-dispatch-node-eof-target
          sequence-case? sequence-case-bytes sequence-case-target
```

Append to `test/common/graph-tests.sps` before `(harness-finish)`:

```scheme
(harness-group "the façade builds a sequence machine"
  (lambda ()
    (harness-case "a single-alternative sequence machine builds through the façade"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'seqnode 'seq '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-sequence-dispatch-node
                          'seq (list (make-sequence-case '(1 2 3 4) 'stop #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'seq))))
    (harness-case "the façade exports the sequence predicates and accessors"
      (lambda ()
        (let ((c (make-sequence-case '(1 2) 'stop #f)))
          (check "sequence-case?" (sequence-case? c))
          (check-equal "bytes" (sequence-case-bytes c) '(1 2))
          (check-equal "target" (sequence-case-target c) 'stop))))))
```

- [ ] **Step 6: Write the failing verifier tests**

Append to `test/common/verify-tests.sps` before `(harness-finish)`. One case per
arm of §0 D2, plus the well-formed control:

```scheme
;; Milestone 3 Slice ② Task 1: the sixth node kind, at all seven of verify.sls's
;; permissive fall-throughs. A sequence node added to ir.sls but NOT to verify.sls
;; VERIFIES CLEAN -- targets never resolution-checked, cycles never detected, EOF
;; chain never walked -- and only crashes later in the normalizer. That is why
;; these land in the same commit as the node kind.
(define (seq-node cases mismatch eof-target)
  (make-sequence-dispatch-node 'seq cases mismatch eof-target #f))
(define (one-alt bytes target) (list (make-sequence-case bytes target #f)))
(define (seq-machine* name nodes eof-name)
  (make-machine name 'seq '() '() '() errs nodes eof-name #f))
(define (seq-machine nodes) (seq-machine* 'seqnode nodes 'default-eof))
(define (well-formed-seq-nodes)
  (list (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) #f)
        (make-stop-node 'stop #f)
        (make-error-node 'reject 'rejected #f)))

(harness-group "sequence dispatch reaches every verifier arm"
  (lambda ()
    (harness-case "a well-formed sequence machine verifies with no diagnostics"
      (lambda ()
        (let ((v (verify-machine (seq-machine (well-formed-seq-nodes)))))
          (check "ok" (verification-ok? v))
          (check-equal "diagnostic count" (length (verification-diagnostics v)) 0))))
    ;; arm 1 -- node-out-targets: a case target
    (harness-case "a case target that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'nowhere)
                                           (make-edge 'reject 'reexecute) #f)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'missing-target))))
    ;; arm 1 -- node-out-targets: the mismatch edge target
    (harness-case "a mismatch target that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'nowhere 'reexecute) #f)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'missing-target))))
    ;; arm 2 -- all-out-targets: a node reachable ONLY through the sequence eof-target
    (harness-case "a node reached only through the sequence eof-target is reachable"
      (lambda ()
        (check-equal "no unreachable-node"
                     (length (filter (lambda (c) (eq? c 'unreachable-node))
                                     (codes (seq-machine
                                             (list (seq-node (one-alt '(1 2) 'stop)
                                                             (make-edge 'reject 'reexecute)
                                                             'done)
                                                   (make-stop-node 'stop #f)
                                                   (make-error-node 'reject 'rejected #f)
                                                   (make-finish-node 'done #f))))))
                     0)))
    ;; arm 3 -- reexec-targets: a dispatch node whose cycle runs through a sequence
    (harness-case "a reexecute cycle through a sequence node's mismatch edge is found"
      (lambda ()
        (check "zero-progress-cycle"
               (has-code?
                (make-machine 'cyc 'start '() '() '() errs
                  (list (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                        (make-edge 'seq 'reexecute) #f))
                                  (make-edge 'seq 'reexecute))
                        (seq-node (one-alt '(1 2) 'stop) (make-edge 'start 'reexecute) #f)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)
                'zero-progress-cycle))))
    ;; arm 4 -- pass-eof: eof-target resolution
    (harness-case "a sequence eof-target that names no node is invalid-eof-target"
      (lambda ()
        (check "invalid-eof-target"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'reject 'reexecute) 'ghost)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'invalid-eof-target))))
    ;; arm 5 -- eof-terminal: the chain is walked THROUGH a sequence node
    (harness-case "an eof chain that cycles through a sequence node is an EOF cycle"
      (lambda ()
        (check "eof-zero-progress-cycle"
               (has-code?
                (make-machine 'eofcyc 'start '() '() '() errs
                  (list (dispatch (list accept-case) (make-edge 'reject 'reexecute))
                        (seq-node (one-alt '(1 2) 'stop) (make-edge 'reject 'reexecute) 'start)
                        (make-stop-node 'stop #f)
                        (make-error-node 'reject 'rejected #f))
                  'default-eof #f)
                'eof-zero-progress-cycle))))
    ;; arm 6 -- :908, a sequence BYTE edge into a finish terminal
    (harness-case "a sequence case targeting a finish terminal is non-eof-into-finish"
      (lambda ()
        (check "non-eof-into-finish"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'done)
                                           (make-edge 'reject 'reexecute) #f)
                                 (make-error-node 'reject 'rejected #f)
                                 (make-finish-node 'done #f)))
                          'non-eof-into-finish))))
    ;; arm 7 -- :909, the sequence node's own eof chain reaching a stop
    (harness-case "a sequence eof path reaching a stop terminal is eof-reachable-stop"
      (lambda ()
        (check "eof-reachable-stop"
               (has-code? (seq-machine
                           (list (seq-node (one-alt '(1 2) 'stop)
                                           (make-edge 'reject 'reexecute) 'stop)
                                 (make-stop-node 'stop #f)
                                 (make-error-node 'reject 'rejected #f)))
                          'eof-reachable-stop))))))
```

> **Disposition, 2026-08-30 (Task 6 close-out).** Arm 5's fixture above
> (`"an eof chain that cycles through a sequence node is an EOF cycle"`)
> pointed the sequence node's `eof-target` at `'start`, a node built through
> this file's pre-existing `dispatch` helper
> (`(define (dispatch cases fallback) (make-byte-dispatch-node 'start cases
> fallback #f #f))`), which hard-wires *its own* `eof-target` to `#f` — so
> `eof-terminal`'s walk from `'seq` reached `'start`, found a non-symbol
> eof-target on its very first step, and returned `'default-error` with no
> revisit and no cycle, ever. The fixture never built the cycle it named.
> Task 1 measured this directly (the one case that stayed red after all seven
> arms landed) and fixed it by pointing the sequence node's `eof-target` at
> itself (`'seq`, not `'start`), which genuinely self-cycles and exercises
> arm 5's `eof-terminal` branch through real self-reference — documented in
> place in `verify-tests.sps` beside the fixture. A second fixture was added
> to isolate arm 5 from arm 7 (both otherwise reach the same
> `eof-terminal` stop/cycle classification code), traced in both directions
> by the review.

- [ ] **Step 7: Run the verifier tests and confirm the expected red**

```bash
ctest --preset release -R 'byte-machine.verify.rejections.chez.source' --output-on-failure
```

Expected: exit 1. **Confirm the shape, not just the failure** — before the arms
exist, the well-formed control and the six positive-diagnostic cases fail while
"a node reached only through the sequence eof-target is reachable" fails for the
*opposite* reason (a false `'unreachable-node`, per the exception design §6
names). Record which cases failed in the report.

- [ ] **Step 8: Add all seven verifier arms**

Arm 1 — in `node-out-targets`, insert before its `(else '())`:

```scheme
          ;; A sequence node's byte out-edges: every alternative's target plus
          ;; the mismatch edge's. Feeding this arm also repairs pass-names'
          ;; target resolution and byte-reached, which both walk this function.
          ((sequence-dispatch-node? n)
           (append (map sequence-case-target (sequence-dispatch-node-cases n))
                   (list (edge-target (sequence-dispatch-node-mismatch n)))))
```

Arm 2 — replace `all-out-targets`' body:

```scheme
  (define (all-out-targets n)
    (append (node-out-targets n)
            (let ((t (cond ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
                           ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
                           (else #f))))
              (if (symbol? t) (list t) '()))))
```

Arm 3 — in `reexec-targets`, insert before its `(else '())`:

```scheme
              ;; Only the mismatch edge can be reexecute; every case edge
              ;; advances by construction (§10.6:546). This teaches the WALK to
              ;; see through a sequence node. Adding sequence nodes to the
              ;; REPORTED set is §25:1533's cycle extension, which is Slice ③ --
              ;; a self-targeting sequence node going unflagged here is correct.
              ((sequence-dispatch-node? n)
               (if (eq? (edge-mode (sequence-dispatch-node-mismatch n)) 'reexecute)
                   (list (edge-target (sequence-dispatch-node-mismatch n))) '()))
```

Arm 4 — replace `pass-eof`'s per-node lambda body:

```scheme
              (map (lambda (n)
                     (let ((t (cond ((byte-dispatch-node? n) (byte-dispatch-node-eof-target n))
                                    ((sequence-dispatch-node? n) (sequence-dispatch-node-eof-target n))
                                    (else #f))))
                       (if (or (eq? t #f) (lookup nodes t)) '()
                           (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                  "eof-target names no node")))))
                   nodes)
```

Arm 5 — in `eof-terminal`, insert before its `(else 'unknown)`:

```scheme
                    ((sequence-dispatch-node? n)
                     (let ((t (sequence-dispatch-node-eof-target n)))
                       (if (symbol? t) (loop t (cons name seen)) 'default-error)))
```

Arm 6 — in `pass-eof-execution`'s §16.2:908 block, widen the filter:

```scheme
                     (if (or (byte-dispatch-node? n) (sequence-dispatch-node? n))
```

Arm 7 — in `pass-eof-execution`'s §16.2:909 block, widen the filter and read the
right accessor:

```scheme
                     (if (or (byte-dispatch-node? n) (sequence-dispatch-node? n))
                         (let ((t (if (byte-dispatch-node? n)
                                      (byte-dispatch-node-eof-target n)
                                      (sequence-dispatch-node-eof-target n))))
```

Update `verify.sls`'s file header to name the sixth kind in its pass list.

- [ ] **Step 9: Confirm all seven arms are present, mechanically**

```bash
grep -c 'sequence-dispatch-node?' src/byte-machine/verify.sls
```

Expected: `7` — one predicate use per arm. A count below 7 means an arm was
missed; the arm that will otherwise verify clean is the one that costs most.

- [ ] **Step 10: Run the whole suite**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 76`.

```bash
git status --porcelain -- test/fixtures/
```

Expected: **no output.**

- [ ] **Step 11: Add the mutations**

Two new passes: one over `ir.sls` in the existing `byte-machine.unit.ir.chez.source`
lane (Pass 42 already exists there — **add to it**, do not open a second), and
one over `verify.sls` in `byte-machine.verify.rejections.chez.source` (Pass 33 —
likewise add to it).

At minimum, each of these decisions gets a mutation with a **measured**
signature; judge whether more are needed and say so in your report:

- `node?` does not admit a sequence node (so `make-machine` rejects it)
- `node-name` does not report a sequence node's name
- `make-sequence-case` accepts an empty byte list
- `sequence-case-bytes` returns the stored chain rather than a copy
- **one mutation per verifier arm** — seven in total. These are the point of the
  task: a silently-clean verifier is the hazard, so each arm needs a witness
  that reddens when it is removed.

Every `FIND` must be unique in its file (`grep -c` it), and every
`EXPECT_OUTPUT_MATCHES` measured from an actual mutant run — the plan predicts
none of them. To measure one:

```bash
/opt/homebrew/bin/chez --script test/support/launchers/chez-source.ss \
  --library-root test/support/harness --library-root src \
  --object-guard <empty-dir> --program test/common/verify-tests.sps
```

Use `/private/tmp/claude-501/-Users-yuzu-github-byte-machine/9acb7875-bab2-42c8-9e9c-1f94c9dec601/scratchpad`
for scratch work, never `/tmp`.

Then update `EXPECTED_PASSES` / `EXPECTED_MUTATIONS` from measurement, with the
arithmetic comment in the same edit.

- [ ] **Step 12: Sweep the pins in both directions**

Both lanes you touched already hold many mutations. Re-judge **every** pin in
Pass 33 and Pass 42 — old and new — against every *other* mutant's captured
output in the same pass, comparing whole FAIL **records**. Then run the same
sweep on `main` as a control: a collision present at HEAD and absent on `main`
is yours. Report what you found, including "no collisions" if that is the
answer.

- [ ] **Step 13: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: one `suite complete` line matching your declared totals, no
`UNCAUGHT`. Nine `SURVIVES` lines are expected and pre-existing; a tenth is a
finding.

- [ ] **Step 14: Commit**

```bash
git add src/byte-machine/private/ir.sls src/byte-machine/graph.sls src/byte-machine/verify.sls test/common/ir-tests.sps test/common/graph-tests.sps test/common/verify-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: sequence dispatch, the sixth node kind, with every verifier arm

make-sequence-dispatch-node and make-sequence-case per §9.1:297-298, with the
asymmetry §10.6:546 requires: the node carries a full mismatch EDGE while its
cases carry bare targets, because a successful sequence consumes every byte and a
per-case mode would reintroduce the lookahead :546 forbids.

The node kind and all SEVEN of verify.sls's permissive fall-throughs land
together. verify.sls fails OPEN where normal-ir.sls and compile.sls fail loudly:
a sequence node known to the IR but not the verifier verifies clean -- targets
unresolved, cycles undetected, EOF chain unwalked -- and only crashes later in
the normalizer. Design §6 counts six of these sites and enumerates seven; seven
is the measured number.

pass-zero-progress's report guard is deliberately NOT extended: the walk now sees
through a sequence node, but adding sequence nodes to the reported set is
§25:1533's cycle extension, which is Slice ③."
```

---

## Task 2: Trie-shaped prefix lowering and two-phase id allocation

**Files:**
- Modify: `src/byte-machine/private/normal-ir.sls` (`only` import; trie section; lowering)
- Test: `test/common/normal-ir-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: Task 1's sequence accessors.
- Produces: no new exported interface. A sequence node lowers to ordinary
  normalized `dispatch` states — decision 0015 point 1 — so
  `normal-state-kind` still returns `'dispatch`, the encoding gains no arm, and
  the format version byte stays `1`.

**Why the trie is a correctness requirement, not an early optimization.**
`make-sequence-dispatch-node` takes a plural `cases` list and validates local
shape only, and decision 0017 point 4 leaves colliding alternatives to the
verifier — whose check is Slice ③'s. So a two-alternative node is constructible
and verifies clean the day this slice merges. Lowered as separate linear chains,
two alternatives sharing a first byte (`AB` and `AC`) put two transitions on
that byte out of one state; the ascending-by-byte sort key ties there,
`list-sort` stability silently picks a winner, and the other alternative goes
dead with nothing failing. They are not *ambiguous* — neither is a terminal
prefix of the other — so Slice ③'s ambiguity check would not catch it either.
Merging the shared byte into one state is what removes the tie. Decision 0016's
Consequences say this explicitly: within-node sharing is what supplies the
one-transition-per-byte property for lowered prefix states, which decision 0014
rests the sort on and which §25:1539's determinism criterion needs.

- [ ] **Step 1: Write the failing lowering tests**

Append to `test/common/normal-ir-tests.sps` before `(harness-finish)`:

```scheme
;; Milestone 3 Slice ② Task 2 (decisions 0015 and 0016). A sequence node lowers
;; to ORDINARY dispatch states -- no new state kind, no new encoding arm -- with
;; alternatives merged into a trie so no prefix state can offer the same byte
;; twice, which is what keeps the ascending-by-byte sort a total order.
(define (seq-alt bytes target) (make-sequence-case bytes target #f))
(define (seq-machine name alts extra-nodes)
  (make-machine name 'seq '() '() '() (list eof-decl rej-decl)
    (append (list (make-sequence-dispatch-node
                   'seq (map (lambda (a) (seq-alt (car a) (cdr a))) alts)
                   (make-edge 'reject 'reexecute) #f #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            extra-nodes)
    'default-eof #f))
(define (state-of m i) (vector-ref (normal-machine-states (normalize m)) i))
(define (state-count m) (vector-length (normal-machine-states (normalize m))))
(define (kinds-of m)
  (let ((s (normal-machine-states (normalize m))))
    (let loop ((i 0) (a '()))
      (if (= i (vector-length s)) (reverse a)
          (loop (+ i 1) (cons (normal-state-kind (vector-ref s i)) a))))))
(define (trs-of m i) (normal-dispatch-transitions (state-of m i)))

(define four-byte (seq-machine 'seqnode '(((1 2 3 4) . stop)) '()))

(harness-group "a single-alternative sequence lowers to a chain of dispatch states"
  (lambda ()
    (harness-case "three declared nodes plus three internal prefix states"
      (lambda () (check-equal "count" (state-count four-byte) 6)))
    (harness-case "every lowered prefix state is an ordinary dispatch state"
      (lambda ()
        (check-equal "kinds" (kinds-of four-byte)
                     '(dispatch stop error dispatch dispatch dispatch))))
    (harness-case "the declared node keeps its declaration index and the prefix states append"
      (lambda ()
        (check-equal "root" (trs-of four-byte 0) '((1 3 advance)))
        (check-equal "prefix 1" (trs-of four-byte 3) '((2 4 advance)))
        (check-equal "prefix 2" (trs-of four-byte 4) '((3 5 advance)))
        (check-equal "prefix 3 targets the alternative's declared target"
                     (trs-of four-byte 5) '((4 1 advance)))))
    (harness-case "every prefix state inherits the mismatch edge as its fallback"
      (lambda ()
        (for-each (lambda (i)
                    (check-equal (string-append "fallback " (number->string i))
                                 (normal-dispatch-fallback (state-of four-byte i))
                                 '(2 . reexecute)))
                  '(0 3 4 5))))
    (harness-case "every prefix state inherits the source node's EOF edge (§12.4:727)"
      (lambda ()
        (for-each (lambda (i)
                    (check-equal (string-append "eof " (number->string i))
                                 (normal-dispatch-eof (state-of four-byte i))
                                 '(default . eof)))
                  '(0 3 4 5))))))

(harness-group "alternatives share prefix states wherever they agree"
  (lambda ()
    (define shared (seq-machine 'shared '(((65 66) . stop) ((65 67) . halt))
                                (list (make-stop-node 'halt #f))))
    (harness-case "a shared first byte becomes ONE transition into ONE state"
      (lambda ()
        (check-equal "root has a single transition" (trs-of shared 0) '((65 4 advance)))))
    (harness-case "the shared state branches to both alternatives' targets"
      (lambda ()
        (check-equal "branch" (trs-of shared 4) '((66 1 advance) (67 3 advance)))))
    (harness-case "caller order does not change the canonical result"
      (lambda ()
        (check-equal "same fingerprint"
                     (normal-machine-fingerprint
                      (normalize (seq-machine 'shared '(((65 66) . stop) ((65 67) . halt))
                                              (list (make-stop-node 'halt #f)))))
                     (normal-machine-fingerprint
                      (normalize (seq-machine 'shared '(((65 67) . halt) ((65 66) . stop))
                                              (list (make-stop-node 'halt #f))))))))
    (harness-case "alternatives that diverge at position 0 get separate states"
      (lambda ()
        (let ((d (seq-machine 'disjoint '(((65 66) . stop) ((88 89) . halt))
                              (list (make-stop-node 'halt #f)))))
          (check-equal "root" (trs-of d 0) '((65 4 advance) (88 5 advance)))
          (check-equal "A branch" (trs-of d 4) '((66 1 advance)))
          (check-equal "X branch" (trs-of d 5) '((89 3 advance))))))))

(harness-group "internal ids are depth-first pre-order, children ascending (decision 0016)"
  (lambda ()
    ;; A -> {B terminal, C -> D}, X -> Y. Depth-first gives 5,6,7; breadth-first
    ;; would give 5,7,6 -- so this fixture is what pins the traversal.
    (define ordered
      (make-machine 'order 'seq '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node 'seq
                (list (seq-alt '(65 66) 'stop) (seq-alt '(65 67 68) 'halt)
                      (seq-alt '(88 89) 'done))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f) (make-error-node 'reject 'rejected #f)
              (make-stop-node 'halt #f) (make-stop-node 'done #f))
        'default-eof #f))
    (harness-case "depth-first pre-order, not breadth-first"
      (lambda ()
        (check-equal "root" (trs-of ordered 0) '((65 5 advance) (88 7 advance)))
        (check-equal "A's child is 5" (trs-of ordered 5) '((66 1 advance) (67 6 advance)))
        (check-equal "C's child is 6, nested under 5" (trs-of ordered 6) '((68 3 advance)))
        (check-equal "X's child is 7, after the whole A subtree" (trs-of ordered 7)
                     '((89 4 advance)))))))

(harness-group "two sequence nodes never share prefix states (decision 0016 point 3)"
  (lambda ()
    (define two
      (make-machine 'two 'sa '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node 'sa (list (seq-alt '(1 2 3) 'sb))
                (make-edge 'reject 'reexecute) #f #f)
              (make-sequence-dispatch-node 'sb (list (seq-alt '(1 2 3) 'stop))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f) (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (harness-case "identical byte runs in two nodes get disjoint states, in declaring order"
      (lambda ()
        (check-equal "sa root" (trs-of two 0) '((1 4 advance)))
        (check-equal "sb root" (trs-of two 1) '((1 6 advance)))
        (check-equal "sa prefix states are 4,5" (trs-of two 4) '((2 5 advance)))
        (check-equal "sb prefix states are 6,7" (trs-of two 6) '((2 7 advance)))
        (check-equal "state count" (state-count two) 8)))))

(harness-group "the two unrepresentable trie shapes fail loudly (decision 0015 point 2)"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (lambda (e) #t)
                      (lambda () (normalize (seq-machine 'amb '(((65 66) . stop)
                                                                ((65 66 67) . halt))
                                                         (list (make-stop-node 'halt #f))))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (lambda (e) #t)
                      (lambda () (normalize (seq-machine 'dup '(((65 66) . stop)
                                                                ((65 66) . halt))
                                                         (list (make-stop-node 'halt #f))))))))))
```

> **Disposition, 2026-08-30 (Task 6 close-out).** Two plan defects in this
> block, both measured, neither an implementer deviation:
> 1. **Both `check-raises` predicates above are `(lambda (e) #t)`** — accepts
>    any raise at all, so a swapped message, a wrong `who`, or a later pass
>    rejecting the fixture for an unrelated reason would all still show green.
>    This is the exact vacuity Slice ①'s review had already tightened out of
>    `ir-tests.sps`, under a house rule `conditions.sls` states in its own
>    header. Task 2's own review found it here and fixed it: a
>    `raises-normalize-assertion?` helper asserting `assertion-violation?`,
>    `condition-who`, and the exact `condition-message`, wired into both call
>    sites. Measured proof the gap was real: swapping the two guards' message
>    strings in `normal-ir.sls` reddened both cases under the fixed
>    predicates; both passed vacuously under the original `(lambda (e) #t)`.
> 2. **No fixture above, nor any earlier in this harness-group, asserts an
>    internal prefix state's own `id` field** — every check reaches a prefix
>    state by its *position* in `normal-machine-states`, never by
>    `normal-state-id`, so `seq-state`'s `id` argument could be wrong (e.g.
>    hard-coded to `0`) and nothing would notice, even though the field is
>    load-bearing at `compile.sls:109` — `render-state-arm`'s
>    `(normal-state-id s)` call (re-derived against the shipped tree, not
>    trusted at the line number this disposition was first written with:
>    `:102` was accurate on `main`, but this branch's own commit `c4a2039`
>    inserted a seven-line comment above `render-state-arm`, moving the line
>    to `:109`). And the field does not derive "each emitted state
>    procedure's name" — the emitter renders no per-state procedures at all,
>    one shared `exec` closure with a single `(case st ...)`
>    (`test/fixtures/generated-one-byte.golden.sls:4-18`) — it derives the
>    `case` datum key each state's arm matches on and the `next-state` field
>    its outcome carries forward. Task 2's own review found this surviving
>    mutation and
>    closed it with two new cases asserting `normal-state-id` directly on the
>    four-byte and depth-first fixtures, plus a matching mutation, both
>    measured caught.

Neither defect changed this block's own `FIND`/`REPLACE` in
`SchemeMutationSuite.cmake`; both are test-file fixes plus one new mutation,
recorded at the commits above.

**Amend the existing declaration-index case** — this edit is decision 0016 being
applied, not routine test maintenance, and the commit must cite 0016. Replace
the `"state ids are the declaration indices"` case with:

```scheme
    ;; Decision 0016 point 1: a DECLARED node keeps its declaration index; only
    ;; internal prefix states break the old coincidence, and they append after
    ;; the entire declared block. The one-byte machine has no sequence node, so
    ;; its ids are unchanged -- which is decision 0016 point 2 in one assertion.
    (harness-case "declared nodes keep their declaration indices (decision 0016)"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "id 0" (normal-state-id (vector-ref s 0)) 0)
          (check-equal "id 1" (normal-state-id (vector-ref s 1)) 1)
          (check-equal "id 2" (normal-state-id (vector-ref s 2)) 2)
          (check-equal "no internal states in a sequence-free machine"
                       (vector-length s) 3))))
```

- [ ] **Step 2: Run and confirm the expected red**

```bash
ctest --preset release -R 'byte-machine.unit.normal-ir.chez.source' --output-on-failure
```

Expected: exit 1 with an `assertion-violation` naming `"unknown node kind"` —
`normal-ir.sls`'s existing `else` guard firing on the sixth kind, which is
exactly the loud failure design §6 says that guard is for.

- [ ] **Step 3: Extend the `only` import**

In `src/byte-machine/private/normal-ir.sls`, add to the `(only (byte-machine
private ir) ...)` list:

```scheme
                sequence-dispatch-node? sequence-dispatch-node-cases
                sequence-dispatch-node-mismatch sequence-dispatch-node-eof-target
                sequence-case-bytes sequence-case-target
```

- [ ] **Step 4: Add the trie section**

Insert immediately before the
`;; Lowering: verified machine -> (values entry states-vector). No encoding.`
comment:

```scheme
  ;; --- sequence prefix trie (decisions 0015, 0016) ---
  ;; A trie node is (children . terminal); children is an alist (byte . node)
  ;; kept ASCENDING by byte, which is what makes decision 0016 point 1's
  ;; pre-order total. Alternatives that agree on a byte descend into ONE shared
  ;; child, so no prefix state can offer the same byte twice -- the property
  ;; decision 0014 rests the ascending sort on, and which pass-overlap cannot
  ;; supply here because it walks source byte-cases and never sees these states.
  (define (empty-trie) (cons '() #f))
  (define (trie-children t) (car t))
  (define (trie-terminal t) (cdr t))
  (define (trie-interior? t) (pair? (trie-children t)))
  (define (trie-put cs b child)
    (cond ((null? cs) (list (cons b child)))
          ((= b (caar cs)) (cons (cons b child) (cdr cs)))
          ((< b (caar cs)) (cons (cons b child) cs))
          (else (cons (car cs) (trie-put (cdr cs) b child)))))
  ;; The two guards below are internal invariants, not user diagnostics. Decision
  ;; 0015 point 2: a prefix state has no "accept here" slot, so a trie node that
  ;; is both terminal and interior is UNREPRESENTABLE rather than merely
  ;; unwanted. §16.2:894's ambiguity check rejects it as a diagnostic -- and that
  ;; check is Slice ③, so between ② and ③ such a node is constructible and
  ;; verifies clean. These fail loudly instead of silently dropping an
  ;; alternative. (byte-machine interpret) carries the same two guards.
  (define (trie-insert t bs target)
    (if (null? bs)
        (begin
          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "duplicate sequence alternative" target))
          (when (trie-interior? t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
          (cons (trie-children t) target))
        (begin
          (when (trie-terminal t)
            (assertion-violation 'normalize-machine "ambiguous terminal prefix" target))
          (let* ((b (car bs))
                 (hit (assv b (trie-children t)))
                 (child (trie-insert (if hit (cdr hit) (empty-trie)) (cdr bs) target)))
            (cons (trie-put (trie-children t) b child) (trie-terminal t))))))
  (define (build-trie cases)
    (let loop ((cs cases) (t (empty-trie)))
      (if (null? cs) t
          (loop (cdr cs) (trie-insert t (sequence-case-bytes (car cs))
                                      (sequence-case-target (car cs)))))))
  ;; Ids for every INTERIOR non-root node, depth-first pre-order with children
  ;; ascending by byte (decision 0016 point 1). The root is the declared node's
  ;; own state, and a TERMINAL child consumes no id -- its byte routes straight
  ;; to that alternative's declared target. Returns (alist next-id), keyed by
  ;; trie-node identity.
  (define (allocate-prefix-ids t next)
    (let walk ((cs (trie-children t)) (acc '()) (next next))
      (if (null? cs) (values (reverse acc) next)
          (let ((child (cdar cs)))
            (if (trie-interior? child)
                (let-values (((sub next2) (allocate-prefix-ids child (+ next 1))))
                  (walk (cdr cs) (append (reverse sub) (cons (cons child next) acc)) next2))
                (walk (cdr cs) acc next))))))
```

- [ ] **Step 5: Rewrite the lowering's `let*` tail**

Replace everything from `(entry (id-of (machine-entry machine)))` through the
existing `(states (list->vector ...))` binding with:

```scheme
           (entry (id-of (machine-entry machine)))
           (declared-count (length nodes))
           ;; Decision 0016: declared nodes keep their declaration index; every
           ;; internal prefix state appends after the whole declared block, in
           ;; declaring-node order. Interleaving would renumber every later node
           ;; and move the fingerprint of every machine containing a sequence.
           (seq-eof-of (lambda (n)
                         (let ((t (sequence-dispatch-node-eof-target n)))
                           (if (symbol? t) (cons 'node (id-of t))
                               (cons 'default default-eof-code)))))
           (prefix-blocks
            (let loop ((ns nodes) (next declared-count) (acc '()))
              (if (null? ns) (reverse acc)
                  (let ((n (car ns)))
                    (if (sequence-dispatch-node? n)
                        (let ((t (build-trie (sequence-dispatch-node-cases n))))
                          (let-values (((ids next2) (allocate-prefix-ids t next)))
                            (loop (cdr ns) next2 (cons (list n t ids) acc))))
                        (loop (cdr ns) next acc))))))
           (block-of (lambda (n)
                       (let loop ((bs prefix-blocks))
                         (cond ((null? bs) #f)
                               ((eq? (car (car bs)) n) (car bs))
                               (else (loop (cdr bs)))))))
           (trie-transitions
            (lambda (t ids)
              (map (lambda (kv)
                     (let ((b (car kv)) (child (cdr kv)))
                       (list b
                             (if (trie-interior? child)
                                 (cdr (assq child ids))
                                 (id-of (trie-terminal child)))
                             'advance)))
                   (trie-children t))))
           ;; Every prefix state carries the source node's mismatch edge as its
           ;; fallback and inherits its EOF edge (§12.4:727).
           (seq-state
            (lambda (n t ids id)
              (let ((mm (sequence-dispatch-node-mismatch n)))
                (vector ns-tag 'dispatch id (trie-transitions t ids)
                        (cons (id-of (edge-target mm)) (edge-mode mm)) #f
                        (seq-eof-of n)))))
           (declared
            (let loop ((ns nodes) (i 0) (acc '()))
              (if (null? ns) (reverse acc)
                  (let ((n (car ns)))
                    (loop (cdr ns) (+ i 1)
                          (cons
                           (cond
                             ((byte-dispatch-node? n)
                              (let ((trs (list-sort (lambda (a b) (< (car a) (car b)))
                                           (apply append
                                             (map (lambda (c)
                                                    (let ((e (byte-case-edge c))
                                                          (bs (matcher-bytes (byte-case-matcher c))))
                                                      (map (lambda (b)
                                                             (list b (id-of (edge-target e))
                                                                   (edge-mode e)))
                                                           bs)))
                                                  (byte-dispatch-node-cases n)))))
                                    (fb (byte-dispatch-node-fallback n)))
                                (vector ns-tag 'dispatch i trs
                                        (cons (id-of (edge-target fb)) (edge-mode fb)) #f
                                        (eof-of n))))
                             ((sequence-dispatch-node? n)
                              (let ((blk (block-of n)))
                                (seq-state n (cadr blk) (caddr blk) i)))
                             ((stop-node? n) (vector ns-tag 'stop i #f #f #f #f))
                             ((error-node? n) (vector ns-tag 'error i #f #f (errcode (error-node-error-name n)) #f))
                             ((finish-node? n) (vector ns-tag 'finish i #f #f #f #f))
                             ((pause-node? n)
                              (vector ns-tag 'pause i #f #f #f
                                      (cons 'node (id-of (pause-node-continuation n)))))
                             ;; The repertoire is now these six kinds. A future
                             ;; kind reaching here must fail loudly, not lower to
                             ;; nothing.
                             (else (assertion-violation 'normalize-machine "unknown node kind" n)))
                           acc))))))
           (internal
            (apply append
                   (map (lambda (blk)
                          (let ((n (car blk)) (ids (caddr blk)))
                            (map (lambda (kv) (seq-state n (car kv) ids (cdr kv))) ids)))
                        prefix-blocks)))
           (states (list->vector (append declared internal))))
```

- [ ] **Step 6: Run the normalizer lane**

```bash
ctest --preset release -R 'byte-machine.unit.normal-ir.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 7: Run the whole suite and confirm nothing moved**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 76`.

```bash
git status --porcelain -- test/fixtures/
```

Expected: **no output.** The three pinned fingerprints and both goldens are the
check that decision 0016 point 2 holds: a sequence-free machine must encode
byte-identically after this change.

- [ ] **Step 8: Add the mutations and sweep**

Add to the existing normalizer pass (`byte-machine.unit.normal-ir.chez.source`).
At minimum, one measured mutation per decision:

- the trie merges shared prefixes (break `trie-put`'s `(= b (caar cs))` arm so a
  repeated byte appends a sibling instead of merging — this is the silent
  miscompile the slice exists to prevent, so it must be caught)
- children are kept ascending (break the `<` comparison)
- id allocation is depth-first pre-order (allocate breadth-first)
- internal states append after the declared block (start `next` at 0)
- a terminal child consumes no id
- each of the two guards fires

Then sweep both directions, as Task 1 Step 12, and update the totals from
measurement.

- [ ] **Step 9: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: one `suite complete` line matching your declared totals, no `UNCAUGHT`.

- [ ] **Step 10: Commit**

```bash
git add src/byte-machine/private/normal-ir.sls test/common/normal-ir-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: trie-shaped sequence prefix lowering with two-phase state ids

Alternatives of one sequence node are merged into a trie, so any that agree on a
byte descend into ONE shared state. That is a correctness requirement, not an
optimization: lowered as separate chains, AB and AC put two transitions on the
same byte out of one state, the ascending-by-byte sort ties, list-sort stability
picks a winner, and the other alternative goes dead with nothing failing.
Decision 0016's Consequences make within-node sharing the warrant for the
one-transition-per-byte property that decision 0014 rests its sort on.

State ids follow decision 0016: declared nodes keep their declaration index and
internal prefix states append after the whole declared block, depth-first
pre-order with children ascending by byte. normal-ir-tests.sps's
'state ids are the declaration indices' case is amended to that rule -- that edit
is decision 0016 being applied, not routine test maintenance.

Sequence-free machines encode byte-identically: all three pinned fingerprints and
both goldens are unmoved (decision 0016 point 2)."
```

---

## Task 3: Interpreter prefix tracking, and the emitter's recorded zero change

**Files:**
- Modify: `src/byte-machine/interpret.sls`
- Test: `test/common/interpret-tests.sps`
- Modify: `src/byte-machine/compile.sls` (**comment only**)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: Task 1's sequence accessors. **Not** Task 2's trie — see below.
- Produces: `current` may now be `(name . path)`. `kind` of a compound is
  `'dispatch`; `dispatch` of a compound steps the prefix; `eof-target` of a
  compound returns the *source* node's eof-target.

**The independence requirement is the point of this task.** §18:970-972 forbids
the interpreter from calling the normalizer or executing normalized IR, because
the interpreter≡generated differential is the only mechanism that can catch
incorrect sequence lowering — and it can only do that if the two implementations
are genuinely independent. `interpret.sls` imports no normalizer library and
must not gain one, and **must not share a prefix walker with the normalizer**.
Decision 0015's Consequences say a reviewer should treat a proposal to factor
"the shared prefix walker" into a common library as a change to that decision.
The interpreter walks source byte lists; the normalizer builds numbered states.
They are different algorithms reaching the same answer, on purpose.

**Why the path and not a position index (§0 D1).** Design §4.2 illustrates the
compound as `(s . k)`. That is insufficient: with alternatives `AB` and `XY`,
after consuming `A` a position index finds that *some* alternative has `Y` at
position 1 and follows `XY`, accepting a sequence that was never on the input.
Measured during plan authoring: with the path, `A` then `Y` correctly mismatches.

- [ ] **Step 1: Write the failing interpreter tests**

Append to `test/common/interpret-tests.sps` before `(harness-finish)`:

```scheme
;; Milestone 3 Slice ② Task 3 (decision 0015 points 3-5). Prefix progress lives
;; in the parser's own `current` as (name . path), where path is the byte list
;; consumed so far inside the sequence -- NOT a bare position index. Design
;; §4.2's (s . k) is insufficient: see the AB/XY case below.
(define (seq-alt* bytes target) (make-sequence-case bytes target #f))
(define (seq-m name alts mode extra)
  (make-machine name 'seq '() '() '() (list eof-decl rej-decl)
    (append (list (make-sequence-dispatch-node
                   'seq (map (lambda (a) (seq-alt* (car a) (cdr a))) alts)
                   (make-edge 'reject mode) #f #f)
                  (make-stop-node 'stop #f)
                  (make-error-node 'reject 'rejected #f))
            extra)
    'default-eof #f))
(define (feed-bytes cm bs)
  (let ((p (make-parser cm '() #f)))
    (let loop ((l bs) (r #f))
      (if (null? l) r
          (loop (cdr l)
                (let ((x (parser-feed! p (make-bytevector 1 (car l)) 0 1)))
                  (list (parser-result-status x) (parser-result-next x)
                        (parser-result-consumed x) (parser-result-stream-offset x)
                        (parser-result-error x))))))))
(define (interp m) (make-interpreted-machine (verify-machine m)))

(harness-group "sequence prefix tracking through the interpreter"
  (lambda ()
    (define one (interp (seq-m 'one '(((1 2 3 4) . stop)) 'reexecute '())))
    (harness-case "the full sequence stops after four bytes"
      (lambda ()
        (check-equal "stopped" (feed-bytes one '(1 2 3 4)) '(stopped 1 1 4 #f))))
    (harness-case "a mid-sequence feed boundary is need-input, never paused (decision 0015 point 5)"
      (lambda ()
        (check-equal "need-input" (car (feed-bytes one '(1 2))) 'need-input)))
    (harness-case "a wrong byte at each position errors at that between-byte offset"
      (lambda ()
        (check-equal "pos 0" (feed-bytes one '(200)) '(error 0 0 0 unexpected-byte))
        (check-equal "pos 1" (feed-bytes one '(1 200)) '(error 0 0 1 unexpected-byte))
        (check-equal "pos 2" (feed-bytes one '(1 2 200)) '(error 0 0 2 unexpected-byte))
        (check-equal "pos 3" (feed-bytes one '(1 2 3 200)) '(error 0 0 3 unexpected-byte))))))

(harness-group "the compound current is a PATH, not a position index (§0 D1)"
  (lambda ()
    ;; AB and XY diverge at position 0. After consuming A, a position index would
    ;; find that SOME alternative has Y at position 1 and follow XY -- accepting a
    ;; sequence that was never on the input. This case is what makes the
    ;; representation observable.
    (define d (interp (seq-m 'diverge '(((65 66) . stop) ((88 89) . halt))
                             'reexecute (list (make-stop-node 'halt #f)))))
    (harness-case "A then Y mismatches rather than following the XY alternative"
      (lambda ()
        (check-equal "mismatch" (car (feed-bytes d '(65 89))) 'error)
        (check-equal "at offset 1" (cadddr (feed-bytes d '(65 89))) 1)))
    (harness-case "each alternative still accepts on its own bytes"
      (lambda ()
        (check-equal "AB" (car (feed-bytes d '(65 66))) 'stopped)
        (check-equal "XY" (car (feed-bytes d '(88 89))) 'stopped)))
    (harness-case "alternatives sharing a first byte both remain live through it"
      (lambda ()
        (let ((s (interp (seq-m 'shared '(((65 66) . stop) ((65 67) . halt))
                                'reexecute (list (make-stop-node 'halt #f))))))
          (check-equal "AB" (car (feed-bytes s '(65 66))) 'stopped)
          (check-equal "AC" (car (feed-bytes s '(65 67))) 'stopped)
          (check-equal "AD mismatches" (car (feed-bytes s '(65 68))) 'error))))))

(harness-group "the interpreter carries the same two internal guards as the normalizer"
  (lambda ()
    (harness-case "an ambiguous terminal prefix is an assertion violation"
      (lambda ()
        (check-raises "AB|ABC" (lambda (e) #t)
                      (lambda ()
                        (feed-bytes (interp (seq-m 'amb '(((65 66) . stop) ((65 66 67) . halt))
                                                   'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))
    (harness-case "two identical alternatives are an assertion violation"
      (lambda ()
        (check-raises "AB|AB" (lambda (e) #t)
                      (lambda ()
                        (feed-bytes (interp (seq-m 'dup '(((65 66) . stop) ((65 66) . halt))
                                                   'reexecute (list (make-stop-node 'halt #f))))
                                    '(65 66))))))))

> **Disposition, 2026-08-30 (Task 6 close-out).** Both `check-raises`
> predicates above are `(lambda (e) #t)`, the same plan-authored vacuity as
> Task 2's block above — the third instance of this class from this plan.
> Unlike Task 2's, this one was caught and fixed by the **implementer**
> during Task 3 itself, not by a later review: replaced with a
> `raises-interpret-assertion?` helper (mirroring `normal-ir-tests.sps`'s
> `raises-normalize-assertion?`), asserting `assertion-violation?`,
> `(eq? (condition-who e) 'interpret)`, and the exact message string, at both
> call sites. Task 3 was also the first task on this branch to pass review
> with zero fix-wave findings, and the difference was applying this exact
> lesson up front rather than reaching for the weakest predicate that
> compiles.

(harness-group "advance-mode mismatch shifts every reported position by one (§11.5:664)"
  (lambda ()
    (define adv (interp (seq-m 'adv '(((1 2 3 4) . stop)) 'advance '())))
    (harness-case "the offending byte is consumed and the offset advances past it"
      (lambda ()
        (check-equal "pos 0" (feed-bytes adv '(200)) '(error 1 1 1 unexpected-byte))
        (check-equal "pos 1" (feed-bytes adv '(1 200)) '(error 1 1 2 unexpected-byte))
        (check-equal "pos 2" (feed-bytes adv '(1 2 200)) '(error 1 1 3 unexpected-byte))
        (check-equal "pos 3" (feed-bytes adv '(1 2 3 200)) '(error 1 1 4 unexpected-byte))))))
```

- [ ] **Step 2: Run and confirm the expected red**

```bash
ctest --preset release -R 'byte-machine.unit.interpret.chez.source' --output-on-failure
```

Expected: exit 1. The interpreter's `kind` reaches its
`byte-machine-contract-violation` `else` on a sequence node, because `lookup`
finds one and no arm claims it.

- [ ] **Step 3: Add the prefix step and destructuring**

In `src/byte-machine/interpret.sls`, insert before `(define (kind name)`:

```scheme
      ;; `current` is either a declared node NAME or, inside a sequence, the
      ;; compound (name . path) where path is the byte list consumed so far.
      ;; The PATH -- not a bare position index -- is what keeps alternatives that
      ;; diverge at position 0 apart: with AB and XY, after consuming A a
      ;; position index would find Y at position 1 in SOME alternative and follow
      ;; XY. Derived independently of the normalizer (§18:970-972, decision 0015
      ;; point 3): this library imports no normalizer library and shares no
      ;; prefix walker with one. That independence is what lets the
      ;; interpreter≡generated differential catch a lowering defect at all, so a
      ;; proposal to factor "the shared prefix walker" into a common library is a
      ;; change to decision 0015, not a refactor.
      (define (prefix? p bs)
        (cond ((null? p) #t)
              ((null? bs) #f)
              ((= (car p) (car bs)) (prefix? (cdr p) (cdr bs)))
              (else #f)))
      (define (seq-step n path byte)
        (let* ((k (length path))
               (new (append path (list byte)))
               (hit (filter (lambda (c)
                              (let ((bs (sequence-case-bytes c)))
                                (and (> (length bs) k) (prefix? new bs))))
                            (sequence-dispatch-node-cases n)))
               (ends (filter (lambda (c) (= (length (sequence-case-bytes c)) (length new))) hit))
               (conts (filter (lambda (c) (> (length (sequence-case-bytes c)) (length new))) hit)))
          (cond ((null? hit)
                 ;; §10.6:546 -- already consumed prefix bytes remain consumed,
                 ;; and the declared mismatch edge decides whether the mismatching
                 ;; byte advances or is reexecuted.
                 (let ((mm (sequence-dispatch-node-mismatch n)))
                   (cons (edge-target mm) (edge-mode mm))))
                ;; The same two internal invariants the normalizer's trie asserts,
                ;; for the same reason (decision 0015 point 2): a prefix position
                ;; that both accepts and continues has no representation here
                ;; either. Slice ③ rejects it as a diagnostic before this point.
                ((and (pair? ends) (pair? conts))
                 (assertion-violation 'interpret "ambiguous terminal prefix"
                                      (sequence-dispatch-node-name n)))
                ((> (length ends) 1)
                 (assertion-violation 'interpret "duplicate sequence alternative"
                                      (sequence-dispatch-node-name n)))
                ;; A successful alternative consumes every byte in it, so the last
                ;; step always advances into the declared target.
                ((pair? ends) (cons (sequence-case-target (car ends)) 'advance))
                (else (cons (cons (sequence-dispatch-node-name n) new) 'advance)))))
```

Replace `kind` with:

```scheme
      (define (kind name)
        (if (pair? name)
            'dispatch                   ; mid-sequence: always reading a byte
            (let ((n (lookup nodes name)))
              (cond ((byte-dispatch-node? n) 'dispatch)
                    ((sequence-dispatch-node? n) 'dispatch)
                    ((stop-node? n) 'stop)
                    ((error-node? n) 'error)
                    ((finish-node? n) 'finish)
                    ((pause-node? n) 'pause)
                    (else (byte-machine-contract-violation 'interpret 'internal name))))))
```

Replace `dispatch` with:

```scheme
      (define (dispatch name byte)
        (if (pair? name)
            (seq-step (lookup nodes (car name)) (cdr name) byte)
            (let ((n (lookup nodes name)))
              (if (sequence-dispatch-node? n)
                  (seq-step n '() byte)
                  (let loop ((cs (byte-dispatch-node-cases n)))
                    (cond ((null? cs)
                           (let ((e (byte-dispatch-node-fallback n)))
                             (cons (edge-target e) (edge-mode e))))
                          ((memv byte (matcher-bytes (byte-case-matcher (car cs))))
                           (let ((e (byte-case-edge (car cs))))
                             (cons (edge-target e) (edge-mode e))))
                          (else (loop (cdr cs)))))))))
```

Add an eof helper beside `error-value`, and route the message through it:

```scheme
      ;; Every lowered prefix state inherits the source node's EOF edge
      ;; (§12.4:727), so a compound current answers with its own node's.
      (define (eof-target-of cur)
        (let ((n (lookup nodes (if (pair? cur) (car cur) cur))))
          (if (sequence-dispatch-node? n)
              (sequence-dispatch-node-eof-target n)
              (byte-dispatch-node-eof-target n))))
```

```scheme
           ((eof-target) (eof-target-of (car args)))
```

- [ ] **Step 4: Run the interpreter lane**

```bash
ctest --preset release -R 'byte-machine.unit.interpret.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

- [ ] **Step 5: Confirm the independence constraint, mechanically**

```bash
grep -c 'normal-ir' src/byte-machine/interpret.sls
```

Expected: `0`. The interpreter must not import or mention a normalizer library.

- [ ] **Step 6: Confirm the emitter and runtime need no change**

```bash
git diff --stat main -- src/byte-machine/compile.sls src/byte-machine/runtime.sls
```

Expected: **no output** — neither file has changed in Tasks 1-3.

```bash
grep -n 'reserved-member-3' src/byte-machine/compile.sls
```

Read the list. A prefix state is an ordinary dispatch state rendered by the
existing `render-state-arm`, so **no new emitted local is introduced** and
`reserved-member-3` needs no entry. Decision 0012 item 4 requires any new
emitted local to join it in the same commit, and `reserved-member-3` has no
automated drift guard (unlike member-2), so this is a check to *run*, not to
assume. Record the result either way.

- [ ] **Step 7: Record the zero change at the site**

In `src/byte-machine/compile.sls`, extend the `render-state-arm` `dispatch` arm's
comment (or add one immediately above `(define (render-state-arm s)`):

```scheme
  ;; Milestone 3 Slice ② changed nothing here either, and that is decision 0015
  ;; point 1 rather than an oversight: a lowered sequence-prefix state IS an
  ;; ordinary normalized dispatch state, so it renders through this same arm, the
  ;; encoding gains no tag, the format version byte stays 1, and the need-input
  ;; resume point below gives cross-feed resumability with no new mechanism. No
  ;; new emitted local means reserved-member-3 (decision 0012 item 4) is
  ;; unchanged -- checked, not assumed, since it has no automated drift guard.
```

- [ ] **Step 8: Run the whole suite**

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 76`.

```bash
git status --porcelain -- test/fixtures/
```

Expected: **no output.**

- [ ] **Step 9: Add the mutations and sweep**

Add to the existing interpreter pass (`byte-machine.unit.interpret.chez.source`).
At minimum:

- `kind` of a compound `current` is `'dispatch`
- `seq-step` filters live alternatives by the **path** (mutate `prefix?` to
  compare only the last byte, or to ignore the path — this is §0 D1's defect,
  and the `AB`/`XY` case is its witness)
- the mismatch edge is taken when no alternative matches
- a completed alternative routes to its declared target, not to another prefix
- `eof-target-of` reads the sequence node's eof-target through a compound
- each of the two guards fires

Sweep both directions and update the totals from measurement.

- [ ] **Step 10: Run the whole mutation suite**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: one `suite complete` line matching your declared totals, no `UNCAUGHT`.

- [ ] **Step 11: Commit**

```bash
git add src/byte-machine/interpret.sls test/common/interpret-tests.sps src/byte-machine/compile.sls test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: interpreter sequence prefix tracking via a compound current

Prefix progress lives in the parser's own current as (name . path), where path is
the byte list consumed so far inside the sequence -- not the (s . k) position
index design §4.2 illustrates. A position index is wrong the moment two
alternatives diverge at position 0: with AB and XY, after consuming A it finds Y
at position 1 in SOME alternative and follows XY, accepting a sequence that was
never on the input.

Derived independently of the normalizer, which is the property that lets the
interpreter≡generated differential catch a lowering defect at all (§18:970-972).
This library imports no normalizer library and shares no prefix walker with one.

The emitter and runtime are unchanged and recorded as such: a prefix state is an
ordinary dispatch state, so it renders through the existing arm and introduces no
emitted local, leaving reserved-member-3 untouched (decision 0012 item 4)."
```

---

## Task 4: The shared sequence fixtures and the absolute interpreter lane

**Files:**
- Create: `test/support/harness/byte-machine/test/sequence-node-machine.sls`
- Create: `test/common/sequence-interpret-tests.sps`
- Modify: `test/CMakeLists.txt` (after the Slice ① byte-class differential block)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Consumes: `(byte-machine graph)`'s Task 1 exports.
- Produces, from `(byte-machine test sequence-node-machine)`:
  - `(make-sequence-node-machine)` → machine `seqnode`, one alternative
    `1 2 3 4` → `stop`, mismatch `reject`/**reexecute**, eof-target `#f`
  - `(make-advance-mismatch-machine)` → machine `advseq`, the same alternative
    with mismatch `reject`/**advance**
  - `(sequence-node-bytes)` → `'(1 2 3 4)`

**Why these two machines.** The reexecute machine is the M2 oracle's shape:
Task 5 must reproduce `sequence-machine.sls`'s pinned tuples with it. The
advance machine exists because **every shipped fixture in this tree uses
`reexecute`** (`sequence-machine.sls`, `pause-machine.sls`), so the
advance-mismatch path has **zero coverage anywhere**, while §11.5:664 says
authors may deliberately choose either and "tests must make that choice
explicit". An advance-mode mismatch edge silently shifts every reported position
by one, and no existing test would look obviously wrong. Measured during plan
authoring: reexecute gives `(error 0 0 k unexpected-byte)`, advance gives
`(error 1 1 k+1 unexpected-byte)`.

- [ ] **Step 1: Write the fixture library**

```scheme
;;; The Milestone 3 Slice ② sequence-dispatch proving machines, shared by the
;;; absolute interpreter lane and the interpreter≡generated differential so each
;;; graph descriptor is written once. Built only through (byte-machine graph).
;;;
;;; Both accept the same single alternative 1 2 3 4 and differ only in their
;;; mismatch MODE. The reexecute machine is the shape Milestone 2's
;;; sequence-machine.sls built from four chained dispatch nodes, so its behaviour
;;; is pinned by tuples measured before this node kind existed. The advance
;;; machine exists because every shipped fixture in this tree uses reexecute, so
;;; the advance path has no coverage at all -- and §11.5:664 requires the choice
;;; to be explicit, because an advance-mode mismatch shifts every reported
;;; position by one and nothing would look obviously wrong.
;;;
;;; One alternative, not several: what this slice reproduces is a
;;; single-alternative oracle. The LOWERING is trie-shaped and
;;; multi-alternative-capable, and Tasks 2-3 pin that at unit level; Slice ③ is
;;; where more than one alternative is executed end to end.
(library (byte-machine test sequence-node-machine)
  (export make-sequence-node-machine make-advance-mismatch-machine
          sequence-node-bytes)
  (import (rnrs) (byte-machine graph))

  (define (sequence-node-bytes) '(1 2 3 4))

  (define (build name mismatch-mode)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine name 'seq '() '() '() (list eof-decl rej-decl)
        (list (make-sequence-dispatch-node
               'seq
               (list (make-sequence-case (sequence-node-bytes) 'stop #f))
               (make-edge 'reject mismatch-mode) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f)))

  (define (make-sequence-node-machine) (build 'seqnode 'reexecute))
  (define (make-advance-mismatch-machine) (build 'advseq 'advance)))
```

- [ ] **Step 2: Write the absolute test program**

Create `test/common/sequence-interpret-tests.sps`:

```scheme
;;; All-byte sequence-dispatch coverage (parent §22.7; Milestone 3 exit §25:1538)
;;; through the reference interpreter, with ABSOLUTE expected outcomes.
;;;
;;; Absolute, not differential, on purpose: both executors are built from the same
;;; source IR, so a defect there makes them wrong IDENTICALLY and leaves a
;;; comparison green. This program is what a prefix-tracking mutation reddens;
;;; differential-sequence-node-tests.sps is what proves the two executors agree.
;;;
;;; Every byte is fed as its own [0,1) slice through ONE parser, which is the
;;; shape that makes the between-byte stream-offset observable at every position
;;; -- and the shape in which the two mismatch modes differ visibly (§11.5:664).
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test sequence-node-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.sequence-node")

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (parser-result-error r)))
(define (feed-bytes cm bs)
  (let ((p (make-parser cm '() #f)))
    (let loop ((l bs) (r #f))
      (if (null? l) r
          (loop (cdr l) (rfields (parser-feed! p (make-bytevector 1 (car l)) 0 1)))))))
(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (interp m) (make-interpreted-machine (verify-machine m)))
(define seq-bytes (sequence-node-bytes))
(define machines
  (list (list 'seqnode (make-sequence-node-machine))
        (list 'advseq (make-advance-mismatch-machine))))

;; §22.6 forbids using an invalid graph to test executor behaviour, so both
;; fixtures are proved clean before any behavioural case runs.
(harness-group "both sequence fixtures verify clean"
  (lambda ()
    (harness-case "the fixture list holds both mismatch modes"
      (lambda () (check-equal "fixture count" (length machines) 2)))
    (for-each
     (lambda (e)
       (harness-case (string-append (symbol->string (car e)) " verifies with no diagnostics")
         (lambda ()
           (let ((v (verify-machine (cadr e))))
             (check "ok" (verification-ok? v))
             (check-equal "diagnostic count" (length (verification-diagnostics v)) 0)))))
     machines)))

(harness-group "a single-alternative sequence accepts its four bytes"
  (lambda ()
    (define one (interp (make-sequence-node-machine)))
    (harness-case "the full sequence stops at stream-offset 4"
      (lambda ()
        (check-equal "stopped" (feed-bytes one seq-bytes) '(stopped 1 1 4 #f))))
    (harness-case "every proper prefix is need-input, never paused (decision 0015 point 5)"
      (lambda ()
        ;; `bad` alone proves no prefix MISBEHAVED, not that the loop ran; `seen`
        ;; counts what the parser actually returned, so a machine that reached a
        ;; terminal early cannot pass by leaving no counterexample.
        (let ((bad 'none) (seen 0))
          (for-each
           (lambda (k)
             (let ((r (feed-bytes one (head-n seq-bytes k))))
               (when (eq? (car r) 'need-input) (set! seen (+ seen 1)))
               (unless (equal? r (list 'need-input 1 1 k #f))
                 (when (eq? bad 'none) (set! bad k)))))
           '(1 2 3))
          (check-equal "no prefix misbehaved" bad 'none)
          (check-equal "all three prefixes returned need-input" seen 3))))))

(harness-group "all 256 byte values at every sequence position"
  (lambda ()
    (for-each
     (lambda (e)
       (let* ((name (car e))
              (cm (interp (cadr e)))
              (advance? (eq? name 'advseq)))
         (harness-case (string-append (symbol->string name)
                                      " accepts only its own byte at each position")
           (lambda ()
             ;; last-byte and positions are set from the loops themselves, so a
             ;; loop that never ran cannot pass; accepted is counted from the
             ;; parser's OWN status, never from the expectation.
             (let ((bad 'none) (last-byte 'unset) (positions 0) (accepted 0))
               (for-each
                (lambda (k)
                  (set! positions (+ positions 1))
                  (let ((prefix (head-n seq-bytes k))
                        (want (list-ref seq-bytes k)))
                    (let loop ((b 0))
                      (when (< b 256)
                        (let ((r (feed-bytes cm (append prefix (list b)))))
                          (if (= b want)
                              (begin
                                (unless (memq (car r) '(need-input stopped))
                                  (when (eq? bad 'none) (set! bad (cons k b))))
                                (when (memq (car r) '(need-input stopped))
                                  (set! accepted (+ accepted 1))))
                              (unless (equal? r (if advance?
                                                    (list 'error 1 1 (+ k 1) 'unexpected-byte)
                                                    (list 'error 0 0 k 'unexpected-byte)))
                                (when (eq? bad 'none) (set! bad (cons k b))))))
                        (set! last-byte b)
                        (loop (+ b 1))))))
                '(0 1 2 3))
               (check-equal "no (position . byte) misbehaved" bad 'none)
               (check-equal "the byte loop ran all 256 values" last-byte 255)
               (check-equal "the position loop ran all four positions" positions 4)
               (check-equal "exactly one byte per position continued" accepted 4))))))
     machines)))

> **Disposition, 2026-08-30 (Task 6 close-out).** The accept branch above
> (`(unless (memq (car r) '(need-input stopped)) ...)`, `(when (memq (car r)
> '(need-input stopped)) (set! accepted (+ accepted 1)))`) asserts only
> **status-class membership** — "the parser reported some form of progress" —
> never a literal tuple. This loop runs for both `cmseq` (`reexecute`) and
> `advseq` (`advance`), so after this block `advseq`'s accept path had **no
> absolute assertion anywhere in the tree**, interpreted or generated — a gap
> this task's own review flagged and carried forward rather than fixing here
> (fixing it in place would have required narrowing this loop's generality,
> which covers all four positions x 256 bytes x two machines). Closed in
> Task 5: `differential-sequence-node-tests.sps` gained
> `(check-equal "advance accept" (run-slices ad-gen (list (list (u8v 1 2 3 4)
> 0 4))) '(stopped 4 4 4 #f))` on the generated executor, the missing
> literal. (Traced separately: `advseq`'s and `cmseq`'s accept-path
> transitions render through the same `compile.sls` code regardless of
> mismatch mode — mismatch mode only selects the *fallback* edge — so the new
> literal is real, non-decorative coverage for "does an absolute tuple
> exist," though it is not independently mutation-discriminating from the
> pre-existing `cmseq` accept literal; recorded as measured, not claimed
> otherwise.)

;; §11.5:664 -- authors may deliberately choose either mismatch mode and "tests
;; must make that choice explicit". Every shipped fixture in this tree uses
;; reexecute, so before this slice the advance path had no coverage anywhere; an
;; advance-mode mismatch shifts every reported position by one and no existing
;; test would look obviously wrong.
(harness-group "the two mismatch modes report different positions, explicitly"
  (lambda ()
    (define re (interp (make-sequence-node-machine)))
    (define ad (interp (make-advance-mismatch-machine)))
    (harness-case "reexecute leaves next and consumed at zero and the offset at the prefix"
      (lambda ()
        (check-equal "k=0" (feed-bytes re '(200)) '(error 0 0 0 unexpected-byte))
        (check-equal "k=1" (feed-bytes re '(1 200)) '(error 0 0 1 unexpected-byte))
        (check-equal "k=2" (feed-bytes re '(1 2 200)) '(error 0 0 2 unexpected-byte))
        (check-equal "k=3" (feed-bytes re '(1 2 3 200)) '(error 0 0 3 unexpected-byte))))
    (harness-case "advance consumes the offending byte and shifts every position by one"
      (lambda ()
        (check-equal "k=0" (feed-bytes ad '(200)) '(error 1 1 1 unexpected-byte))
        (check-equal "k=1" (feed-bytes ad '(1 200)) '(error 1 1 2 unexpected-byte))
        (check-equal "k=2" (feed-bytes ad '(1 2 200)) '(error 1 1 3 unexpected-byte))
        (check-equal "k=3" (feed-bytes ad '(1 2 3 200)) '(error 1 1 4 unexpected-byte))))
    (harness-case "the two modes agree on a successful sequence"
      (lambda ()
        (check-equal "same accept" (feed-bytes re seq-bytes) (feed-bytes ad seq-bytes))))))

(harness-finish)
```

> Note `rfields`, not `fields`: R6RS `(rnrs)` re-exports `fields` as a
> `define-record-type` auxiliary keyword, so `(define (fields r) ...)` is a
> "multiple definitions" load error. `differential-one-byte-tests.sps` already
> uses `rfields` for the same reason. Measured, not guessed — the first draft of
> this program failed to load.

- [ ] **Step 3: Register the two lanes**

In `test/CMakeLists.txt`, after the Slice ① `differential.byte-class` block:

```cmake
# --- Milestone 3 Slice ②: sequence dispatch through the interpreter -----------
# ABSOLUTE expected outcomes for a single-alternative sequence node and its
# advance-mismatch twin. Absolute rather than differential because both executors
# read the same source IR: a defect there is invisible to a comparison and
# visible here.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.sequence-node.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.sequence-node.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/sequence-interpret-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 4: Build and run**

```bash
make build && ctest --preset release -R 'byte-machine.unit.sequence-node' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 78`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 8` — unchanged; this slice
registers no `cmake.direct` lane.

- [ ] **Step 5: Add a new mutation pass over the new SPEC lane**

Open a pass over `byte-machine.unit.sequence-node.chez.source` for the decisions
no earlier lane can reach — in particular the advance/reexecute mismatch-mode
distinction, which no fixture in the tree could witness before this task, since
every shipped fixture uses `reexecute`. At minimum: the mismatch edge's **mode**
is honoured (swap `advance` for `reexecute` in the runtime path the interpreter
returns, or invert the fixture's mode and watch the absolute assertions redden),
and a completed alternative routes to its declared target.

Measure every signature. Sweep both directions. Update the totals from
measurement.

- [ ] **Step 6: Run the whole mutation suite and commit**

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: one `suite complete` line matching your declared totals, no `UNCAUGHT`.
Then commit the fixture library, the program, the lanes and the pass together.

---

## Task 5: The differential lane — reproducing the Milestone 2 oracle

**Files:**
- Create: `test/common/differential-sequence-node-tests.sps`
- Modify: `test/CMakeLists.txt`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:** consumes Task 4's fixtures; adds none.

**This is the slice's independent oracle.** A single-alternative sequence node
matching `1 2 3 4` must reproduce `sequence-machine.sls` — four *chained
dispatch nodes* — exactly. The construct is new; the expected behaviour is not,
and it was measured by a different mechanism before this node kind existed. The
tuples are already pinned in `test/common/differential-sequence-tests.sps`, and
**verified during plan authoring** to be reproduced by the prototype lowering:

| case | pinned tuple |
| --- | --- |
| full input `1 2 3 4` in one slice | `(stopped 4 4 4 #f)` |
| wrong byte at position `k` (each byte its own slice) | `(error 0 0 k unexpected-byte)` for `k` in 0..3 |
| nonzero-offset slice `[1,5)` of `9 1 2 3 4 9` | `(stopped 5 4 4 #f)` |
| that slice split mid-sequence | `(stopped 5 2 4 #f)` |
| an empty nonzero-offset slice after two bytes | `(need-input 3 0 2 #f)` |

- [ ] **Step 1: Write the differential program**

Create `test/common/differential-sequence-node-tests.sps`:

```scheme
;;; interpreter ≡ generated over a single-alternative SEQUENCE NODE (parent §18,
;;; §22.4, §22.5). This lane is the slice's independent oracle: the construct is
;;; new, but the expected behaviour is not. Milestone 2's sequence-machine.sls
;;; built the same four-byte accept from four CHAINED DISPATCH NODES, and the
;;; tuples below were measured against it before this node kind existed
;;; (test/common/differential-sequence-tests.sps).
;;;
;;; Agreement alone cannot carry the lane -- both executors read the same source
;;; IR -- so every group also asserts the GENERATED side absolutely.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test sequence-node-machine)
        (byte-machine test prng)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.sequence-node")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential-sequence-node
                             "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (generated-machine name machine)
  (let ((genfile (string-append tmpdir "/generated-" (symbol->string name) ".sls"))
        (binding (string->symbol (string-append (symbol->string name) "-parser"))))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine machine '()) binding p)))
    (load genfile)
    (eval binding (environment (list 'generated name)))))

(define (rfields r)
  (list (parser-result-status r) (parser-result-next r)
        (parser-result-consumed r) (parser-result-stream-offset r)
        (parser-result-error r)))
(define (u8 b) (make-bytevector 1 b))
(define (u8v . bs) (u8-list->bytevector bs))
(define (head-n l k) (if (= k 0) '() (cons (car l) (head-n (cdr l) (- k 1)))))
(define (run-slices cm slices)
  (let ((p (make-parser cm '() #f)))
    (let loop ((ss slices) (last #f))
      (if (null? ss) last
          (loop (cdr ss)
                (rfields (parser-feed! p (car (car ss)) (cadr (car ss)) (caddr (car ss)))))))))
(define (drive cm prefix b)
  (run-slices cm (append (map (lambda (x) (list (u8 x) 0 1)) prefix)
                         (list (list (u8 b) 0 1)))))
(define (schedule->string cuts)
  (string-append "("
                 (fold-left (lambda (acc c)
                              (string-append acc (if (string=? acc "") "" " ")
                                             (number->string c)))
                            "" cuts)
                 ")"))

(define seq-bytes (sequence-node-bytes))
(define seq-machine (make-sequence-node-machine))
(define adv-machine (make-advance-mismatch-machine))
(define cm-ref (make-interpreted-machine (verify-machine seq-machine)))
(define cm-gen (generated-machine 'seqnode seq-machine))
(define ad-ref (make-interpreted-machine (verify-machine adv-machine)))
(define ad-gen (generated-machine 'advseq adv-machine))

;; --- the Milestone 2 tuples, reproduced by a sequence node ---
(harness-group "the M2 chained-dispatch tuples are reproduced exactly"
  (lambda ()
    (harness-case "the full sequence in one slice stops after four bytes in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))
        (check-equal "generated" (run-slices cm-gen (list (list (u8v 1 2 3 4) 0 4)))
                     '(stopped 4 4 4 #f))))
    (harness-case "a wrong byte at each position errors at that between-byte offset in both"
      (lambda ()
        (let ((bad 'none) (positions 0))
          (for-each
           (lambda (k)
             (set! positions (+ positions 1))
             (let ((expect (list 'error 0 0 k 'unexpected-byte)))
               (unless (equal? (drive cm-ref (head-n seq-bytes k) 200) expect)
                 (when (eq? bad 'none) (set! bad (cons 'ref k))))
               (unless (equal? (drive cm-gen (head-n seq-bytes k) 200) expect)
                 (when (eq? bad 'none) (set! bad (cons 'gen k))))))
           '(0 1 2 3))
          (check-equal "no position misbehaved" bad 'none)
          (check-equal "the position loop ran all four" positions 4))))))

(harness-group "nonzero-offset slices report exact next / consumed / stream-offset"
  (lambda ()
    (define padded (u8v 9 1 2 3 4 9))
    (harness-case "one nonzero-offset slice accepts with exact fields in both"
      (lambda ()
        (check-equal "interpreter" (run-slices cm-ref (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))
        (check-equal "generated" (run-slices cm-gen (list (list padded 1 5)))
                     '(stopped 5 4 4 #f))))
    (harness-case "a nonzero-offset slice split mid-sequence resumes with exact fields"
      (lambda ()
        (check-equal "interpreter"
                     (run-slices cm-ref (list (list padded 1 3) (list padded 3 5)))
                     '(stopped 5 2 4 #f))
        (check-equal "generated"
                     (run-slices cm-gen (list (list padded 1 3) (list padded 3 5)))
                     '(stopped 5 2 4 #f))))
    (harness-case "an empty nonzero-offset slice consumes nothing and needs input"
      (lambda ()
        (check-equal "interpreter"
                     (run-slices cm-ref (list (list padded 1 3) (list padded 3 3)))
                     '(need-input 3 0 2 #f))
        (check-equal "generated"
                     (run-slices cm-gen (list (list padded 1 3) (list padded 3 3)))
                     '(need-input 3 0 2 #f))))))

;; --- fragmentation (§22.5) ---
(define seq-input (u8v 1 2 3 4))
(define (slices-for cuts)
  (let ((bounds (append '(0) cuts '(4))))
    (let loop ((bs bounds) (acc '()))
      (if (null? (cdr bs)) (reverse acc)
          (loop (cdr bs) (cons (list seq-input (car bs) (cadr bs)) acc))))))
(define (with-empties slices)
  (define e (list seq-input 0 0))
  (let loop ((ss slices) (acc (list e)))
    (cond ((null? ss) (reverse acc))
          ((null? (cdr ss)) (loop '() (cons (car ss) (cons e acc))))
          (else (loop (cdr ss) (cons e (cons (car ss) acc)))))))

(harness-group "every fragmentation of the sequence reaches stopped in both lanes"
  (lambda ()
    (define all-cut-sets '(() (1) (2) (3) (1 2) (1 3) (2 3) (1 2 3)))
    (harness-case "each of the eight split sets stops at offset 4 in both"
      (lambda ()
        (let ((bad 'none) (sets 0))
          (for-each
           (lambda (cuts)
             (set! sets (+ sets 1))
             (let ((ri (run-slices cm-ref (slices-for cuts)))
                   (rg (run-slices cm-gen (slices-for cuts))))
               (unless (and (eq? (car ri) 'stopped) (= (cadddr ri) 4)
                            (eq? (car rg) 'stopped) (= (cadddr rg) 4)
                            (equal? ri rg))
                 (when (eq? bad 'none) (set! bad (schedule->string cuts))))))
           all-cut-sets)
          (check-equal "no split misbehaved" bad 'none)
          (check-equal "all eight cut-sets ran" sets 8))))
    (harness-case "leading / intermediate / trailing empty feeds still accept"
      (lambda ()
        (check-equal "interpreter with empties"
                     (car (run-slices cm-ref (with-empties (slices-for '(1 2 3))))) 'stopped)
        (check-equal "generated with empties"
                     (car (run-slices cm-gen (with-empties (slices-for '(1 2 3))))) 'stopped)
        (check-equal "empties do not change agreement"
                     (run-slices cm-ref (with-empties (slices-for '(1 2 3))))
                     (run-slices cm-gen (with-empties (slices-for '(1 2 3)))))))
    (harness-case "a deterministic random multi-split schedule accepts and agrees"
      (lambda ()
        (define seed 20260830)
        (let loop ((i 0) (s (make-prng seed)) (multi 0) (bad 'none))
          (if (>= i 32)
              (begin
                (check-equal "no schedule disagreed" bad 'none)
                ;; the case name promises multi-split: assert the seed actually
                ;; produced a draw with >= 2 cuts rather than assuming it.
                (check "at least one draw was a genuine multi-split (>= 2 cuts)" (> multi 0)))
              (let*-values (((d1 s1) (prng-next s 2))
                            ((d2 s2) (prng-next s1 2))
                            ((d3 s3) (prng-next s2 2)))
                (let* ((cuts (append (if (= d1 1) '(1) '())
                                     (if (= d2 1) '(2) '())
                                     (if (= d3 1) '(3) '())))
                       (ri (run-slices cm-ref (slices-for cuts)))
                       (rg (run-slices cm-gen (slices-for cuts))))
                  (loop (+ i 1) s3 (+ multi (if (>= (length cuts) 2) 1 0))
                        (if (and (eq? bad 'none)
                                 (or (not (equal? ri rg)) (not (eq? (car rg) 'stopped))))
                            (schedule->string cuts) bad)))))))))) 

(harness-group "interpreter and generated agree on all 256 bytes at every position"
  (lambda ()
    (harness-case "256 x 4 positions match, in both mismatch modes"
      (lambda ()
        (let ((bad 'none) (last-byte 'unset) (positions 0))
          (for-each
           (lambda (k)
             (set! positions (+ positions 1))
             (let ((prefix (head-n seq-bytes k)))
               (let loop ((b 0))
                 (when (< b 256)
                   (unless (equal? (drive cm-ref prefix b) (drive cm-gen prefix b))
                     (when (eq? bad 'none) (set! bad (list 'reexecute k b))))
                   (unless (equal? (drive ad-ref prefix b) (drive ad-gen prefix b))
                     (when (eq? bad 'none) (set! bad (list 'advance k b))))
                   (set! last-byte b)
                   (loop (+ b 1))))))
           '(0 1 2 3))
          (check-equal "no (mode position byte) disagreed" bad 'none)
          (check-equal "the byte loop ran all 256 values" last-byte 255)
          (check-equal "the position loop ran all four" positions 4))))))

;; §11.5:664 -- the advance path had no coverage anywhere in this tree before
;; Slice ②, and an advance-mode mismatch shifts every reported position by one.
;; Asserted absolutely on the GENERATED side, not only as agreement.
(harness-group "both mismatch modes, absolutely, on the generated executor"
  (lambda ()
    (harness-case "reexecute keeps next and consumed at zero"
      (lambda ()
        (check-equal "k=0" (drive cm-gen '() 200) '(error 0 0 0 unexpected-byte))
        (check-equal "k=3" (drive cm-gen '(1 2 3) 200) '(error 0 0 3 unexpected-byte))))
    (harness-case "advance consumes the offending byte and shifts the offset"
      (lambda ()
        (check-equal "k=0" (drive ad-gen '() 200) '(error 1 1 1 unexpected-byte))
        (check-equal "k=3" (drive ad-gen '(1 2 3) 200) '(error 1 1 4 unexpected-byte))))
    (harness-case "both modes accept the sequence identically"
      (lambda ()
        (check-equal "same accept"
                     (run-slices cm-gen (list (list (u8v 1 2 3 4) 0 4)))
                     (run-slices ad-gen (list (list (u8v 1 2 3 4) 0 4))))))))

(harness-finish)
```

> The seed `20260830` is this program's own; its multi-split sentinel was
> confirmed to hold during plan authoring. If a future edit changes the seed,
> re-confirm that sentinel rather than assuming — asserting "at least one draw
> had ≥2 cuts" is what stops the case name from promising coverage the draws did
> not produce.

> **Disposition, 2026-08-30 (Task 6 close-out).** Four vacuity gaps in this
> brief-supplied program, three found by Task 5's review rather than by the
> plan or the implementer:
> 1. **`with-empties` (above) never produces a trailing empty feed**, though
>    its one caller's case name promises "leading / intermediate / **trailing**
>    empty feeds still accept." Reading the loop: the `(null? (cdr ss))`
>    branch conses the empty slice `e` onto the accumulator built so far and
>    stops — the schedule always ends on a **data** slice, never on `e`. This
>    helper is copied verbatim from the M2 oracle
>    (`differential-sequence-tests.sps`), which has the identical gap — an M2
>    finding surfaced by this slice, left as M2's own carried item, not fixed
>    here. Fixed for *this* file: the existing case was renamed to "leading /
>    intermediate empty feeds still accept" (accurate to what it tests), and a
>    genuinely new case, "a trailing empty feed after the sequence completes
>    stays stopped," was added, asserting an absolute tuple after a real
>    trailing empty feed on both executors.
> 2. **The eight-cut-set sweep (`"each of the eight split sets stops at
>    offset 4 in both"`, above) asserted only `status` and `stream-offset`**,
>    which are identical across every cut-set by construction, plus a
>    loop-iteration counter — so a `slices-for` that silently ignored `cuts`
>    and returned one whole slice would have left all eight green. Fixed:
>    replaced with a full-tuple comparison against eight measured literals,
>    one per cut-set (`consumed` — `next - start`, computed fresh per final
>    slice — is 4, 3, 2, 1, 2, 1, 1, 1 across the eight sets in the order
>    given; only `consumed` separates a real split from a whole-slice one).
>    Sensitivity-checked by deliberately corrupting one literal and
>    confirming the case reddened, not merely re-run clean.
> 3. **`advseq`'s accept path had no absolute literal-tuple assertion
>    anywhere in the tree**, in either executor — see the disposition on
>    Task 4's "all 256 byte values" block above; the fix (`"advance
>    accept"`) landed in this file's `"both mismatch modes, absolutely, on
>    the generated executor"` group below.
> 4. **This program's own header claimed "every group also asserts the
>    GENERATED side absolutely"** (above, before the `import` clause), but
>    the 256-byte exhaustive-agreement group asserts only *agreement*
>    (`interpreter ≡ generated`), never a literal for any specific byte —
>    correctly, since that group's job is exhaustive coverage across 256
>    byte values x 4 positions x 2 mismatch modes, which no fixed literal
>    tuple could stand in for. The header's universal claim was false, not
>    the group's design; corrected to name the one group it excludes, rather
>    than adding a redundant literal pin inside the 256-byte loop.
>
> **A fifth gap surfaced by the fix wave's own fix, not by the brief:** the
> new trailing-empty case (item 1) first fed `start = 0` and asserted
> `next = 0` — which cannot distinguish `next = start` (correct) from a
> hardcoded literal `0` (wrong), the exact zero-start indistinguishability
> trap this repository had already named and closed twice, for the sticky
> `error` and `pause` arms, and never for `stopped`. Because
> `parser-feed!`'s sticky arms run before any executor dispatch, a mutation
> there breaks the interpreter and the generated executor identically, so no
> agreement-based differential could ever have caught it either. Closed with
> a second, nonzero-start case (`(stopped 5 0 4 #f)`, where `start=5 !=
> offset=4 != 0` separates all three candidates) plus a mutation on
> `consumed`; the offset-swap variant of the same trap turned out already
> caught incidentally, so only the literal-`0` mutation was added.
>
> Final mutation total for this file's lane: 43 passes/223 (from 42/221
> before Task 5).

- [ ] **Step 2: Register the two lanes**

In `test/CMakeLists.txt`, immediately after Task 4's block:

```cmake
# --- Milestone 3 Slice ②: interpreter≡generated over a sequence node ----------
# The slice's independent oracle. A single-alternative sequence node must
# reproduce sequence-machine.sls -- four CHAINED DISPATCH NODES -- exactly: the
# construct is new, the expected behaviour is not, and it was measured by a
# different mechanism before this node kind existed.
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence-node.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.sequence-node.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/sequence-node-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-sequence-node-tests.sps"
  TIMEOUT 180)
```

The runtime-emitted generated libraries go to `BYTE_MACHINE_TEST_TMPDIR` and
appear in **no** `SOURCES` list. `prng.sls` is listed before the core because the
AOT lane compiles its `SOURCES` in order — the Milestone 2 sequence lanes at
`test/CMakeLists.txt:968-987` are the precedent to follow exactly.

- [ ] **Step 3: Build and run the new lanes**

```bash
make build && ctest --preset release -R 'byte-machine.differential.sequence-node' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`.

```bash
make test-all
```

Expected: `100% tests passed, 0 tests failed out of 80`.

```bash
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 8`.

- [ ] **Step 4: Confirm the M2 lane still passes unchanged**

```bash
ctest --preset release -R 'byte-machine.differential.sequence.chez' --output-on-failure
```

Expected: `100% tests passed, 0 tests failed out of 2`. The Milestone 2
chained-dispatch lane is the source of every tuple this task reproduces; if it
moved, the oracle moved with it and the reproduction proves nothing.

- [ ] **Step 5: Add the non-vacuity mutation, sweep, and run the whole suite**

Open a pass over the new differential SPEC lane. The lane is only worth its
runtime if a divergence would redden it, so the mutation must make the two
executors disagree — the emitter is the natural target, since the interpreter
does not read it. Measure the signature; sweep both directions against the other
passes that also mutate `compile.sls`; update the totals from measurement; then:

```bash
ctest --preset release -R 'scheme-mutation' -V 2>&1 | grep -E "suite complete|UNCAUGHT|FATAL"
```

Expected: one `suite complete` line matching your declared totals, no `UNCAUGHT`.

- [ ] **Step 6: Commit**

**Record when discharging exit criterion §25:1538** — in the commit message and
in Task 6's CHANGELOG entry — that mismatch positions are asserted through
`status`/`next`/`consumed`/`stream-offset`/`code` only. The structured
parser-error record (`parser-error-node-name`, `-state-id`, `-position-kind`) is
deferred to M4/M5, and milestone-2-design.md §7 forbids populating one field of
an otherwise-deferred family. Design §8 says that limitation must be **recorded**
rather than glossed.

---

## Task 6: Close-out — measured totals and the records that carry them

**Files:** `test/support/cmake/SchemeMutationSuite.cmake` (final measured
totals), `CHANGELOG.md`, `.plans/milestone-3-design.md`,
`.superpowers/sdd/progress.md` (**never `git add` it**).

- [ ] Re-measure everything from `make clean && make test-all`, the no-scheme
      preset, and both mutation suites. Record the exact reported
      `(N passes, M mutations)`. Nine `SURVIVES` lines are expected and
      pre-existing; a tenth is a finding to strengthen the test, never to loosen
      the mutation.
- [ ] Reconcile `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` and their arithmetic
      comment with the measurement.
- [ ] Re-judge every pin this slice added against its lane's other mutants, in
      **both** directions, and confirm no later task widened an earlier task's
      pins — the one thing no single task's sweep can see. Record the sweep's
      scope **with its qualifier attached**.
- [ ] Write the CHANGELOG entry using measured numbers only, and update the
      `[Unreleased]` preamble to say Milestone 3 is in progress with Slices ①
      and ② closed and ③ open.
- [ ] **Amend design §4.2 with a dated note** recording that its `(s . k)`
      illustration was measured insufficient — with the `AB`/`XY` counterexample
      — and that the shipped representation is the consumed byte path. This is a
      **record**, so it gets an amendment, not a reword. Decision 0015 needs no
      amendment: it never named the representation.
- [ ] **Disposition design §6's two miscounts** in a dated note beside untouched
      text: it says "six sites" and enumerates seven, and its appendix repeats
      "all six permissive fall-throughs" with the same seven references.
- [ ] Add a dated disposition of design §6's contents list, recording what each
      item cost and where it landed.
- [ ] Sweep the status surfaces. Slice ② does **not** close Milestone 3 — Slice
      ③ remains — so `README.org` and the parent plan should continue to read
      "in progress". Confirm mechanically rather than from memory:
      `grep -n 'Milestone 3' README.org .plans/byte-machine-implementation-plan.md`.
- [ ] Final whole-suite run, then commit.
- [ ] Update the ledger with measured totals, the dispositions, and anything the
      pin sweep found.

---

## Self-Review

**Spec coverage.**

| requirement | task |
| --- | --- |
| §25:1529 (single-alternative half) exact sequence alternatives | 1, 4, 5 |
| §25:1530 prefix normalization and resumable internal states | 2 |
| §25:1531 mismatch positioning | 3, 4, 5 |
| exit §25:1538 every sequence split and mismatch position passes | 5 |
| design §6 source IR, `node?`/`node-name`, `graph.sls` both lists | 1 |
| design §6 all permissive verifier fall-throughs, same commit as the node kind | 1 (seven, per §0 D2) |
| design §6 trie-shaped prefix lowering with 0016's id allocation | 2 |
| design §6 `normal-ir-tests.sps` amended to the recorded rule | 2 |
| design §6 interpreter prefix tracking with `lookup`/`kind` destructuring | 3 |
| design §6 emitter zero change confirmed and recorded; `reserved-member-3` | 3 |
| design §6 the oracle — `sequence-machine.sls` reproduced exactly | 5 |
| design §6 both mismatch modes | 3 (unit), 4 (absolute), 5 (differential) |
| design §6 distinct five-segment lane names | 4, 5 |
| decision 0015 points 1-6 | 2 (1-2), 3 (3-6) |
| decision 0016 points 1-3 | 2 |
| decision 0017 points 1-2 for sequences (empty rejected, length-1 legal) | 1 |
| decision 0017 point 4 (collisions are not constructor errors) | 1, and §0 D4 for the internal guard |

**Out of scope, from design §7 and §8**, and absent from every task above: the
ambiguity *diagnostic* and its new code; multi-alternative fixtures executed end
to end; the zero-progress/EOF-cycle extension for sequence nodes (§0 D3);
determinism pins for sequence machines; the `HTTP/1.0`⁄`HTTP/1.1` fixture;
cross-node prefix sharing; the structured parser-error record; widening the
diagnostic record; extending `machine-gen.sls`; the state-ID-to-source-name debug
map; any `runtime.sls` change or `/v3` ABI; any lookahead or rewind.

**Type consistency.** `sequence-case-bytes` returns a fresh proper list of exact
integers everywhere it is named (Tasks 1-5). `sequence-dispatch-node-mismatch`
returns an **edge**; `sequence-case-target` returns a **symbol** — the asymmetry
§10.6:546 requires, and the two are never interchanged. The interpreter's
`current` is a symbol or `(name . path)` with `path` a proper list of bytes, and
`seq-step` is the only producer of the compound form. Trie nodes are
`(children . terminal)` throughout Task 2, with `children` an ascending alist.
`allocate-prefix-ids` returns `(values alist next-id)`; its alist is keyed by
trie-node identity and read with `assq`.

**Verified at plan-authoring time (2026-08-30)**, against a prototype carrying
every source change in Tasks 1-3, driven through Chez 10.4.1 outside the
harness: a single-alternative `1 2 3 4` sequence node verifies with zero
diagnostics and lowers to 6 states with kinds
`(dispatch stop error dispatch dispatch dispatch)` and transitions
`((1 3 advance))`, `((2 4 advance))`, `((3 5 advance))`, `((4 1 advance))` with
fallback `(2 . reexecute)` throughout; it reproduces **every** M2 oracle tuple in
the table above, and interpreter ≡ generated over all 256 bytes at all four
positions; `AB`/`AC` merge byte 65 into one shared state; `AB`/`XY` get separate
states and the interpreter correctly mismatches on `A` then `Y`; caller order
does not move the fingerprint; ids for `AB`/`ACD`/`XY` come out `5, 6, 7`
(depth-first) rather than `5, 7, 6`; two sequence nodes with identical byte runs
get disjoint states in declaring order; both guards fire in both implementations
with matching messages; and the one-byte fingerprint is still
`4236938459847922092`. All four edited libraries parse as exactly one library
form.

**That prototype describes a driver, not the shipped lanes.** The values above
are pure-function results and driver-independent, but every count that reaches a
record — lane totals, mutation totals, failure signatures — is re-measured
through the harness by the task that writes it, and again by Task 6.

**Three Scheme blocks in this plan are deliberate fragments and will not
balance on their own:** Task 1 Step 8's two arm-widening snippets (each replaces
the head of an enclosing `if`) and Task 2 Step 5's `let*` binding tail. Every
other Scheme block in this document was extracted and read by Chez 10.4.1 during
plan authoring and parses as a complete form — a check Slice ① applied to its
library edits but not its test blocks, and paid for with an unbalanced test case
that silently swallowed the rest of a file.

**Known residue, to be measured rather than assumed.** This plan deliberately
supplies **no** `EXPECT_OUTPUT_MATCHES` strings. Slice ① predicted them and was
wrong in four tasks out of six; the discipline that worked was measuring each
mutant and pinning what came back. Every mutation step here names the *decision*
to witness and leaves the signature to measurement.
