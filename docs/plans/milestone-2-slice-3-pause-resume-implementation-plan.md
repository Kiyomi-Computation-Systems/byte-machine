# Milestone 2 Slice ③ — Pause / Resume + Full Operation Matrix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the explicit pause node, `parser-resume!`, the `paused-feed`/
`paused-finish`/`finish-ready` lifecycle states, and enforcement of the full
reachable §12.2 operation matrix — closing Milestone 2.

**Architecture:** The pause node is the fifth node/state kind, threaded through
the same six libraries the finish node crossed in Slice ②b (ir/graph → verify →
interpret → normal-ir → compile → runtime), plus the runtime lifecycle work that
is Slice ③'s own: entry gating on every operation, a sticky-row short-circuit
with a stored error value (which also closes the ②b-2 default-EOF re-dispatch
carry), and `parser-resume!`. Proving surface: a shared pause-machine fixture
driven through unit, differential, and determinism lanes, plus the property
generator extension.

**Tech Stack:** R6RS Scheme (Chez 10.4.1), CMake/CTest lanes, the in-repo
mutation suite (`test/support/cmake/SchemeMutationSuite.cmake`).

Design authority: [milestone-2-design.md](./milestone-2-design.md) §6 (Slice ③),
§3.1–§3.3; decisions [0011](../decisions/0011-eof-execution-model.md),
[0012](../decisions/0012-generated-abi-v2-finish.md),
[0013](../decisions/0013-runtime-coded-conditions.md); parent plan
[byte-machine-implementation-plan.md](./byte-machine-implementation-plan.md)
§9.1:312, §10.6:606-608, §12.1–§12.6, §16.2:898-909, §22.4–§22.6, §25 M2.

## Global Constraints

- **Baselines to hold (measured on `main` = 98d4a01):** release/pr **66/66**,
  no-scheme **8/8**, scheme mutation **37 passes / 123 mutations**, cmake
  mutation **1/72**. Every task ends with these (plus its own additions) green.
- **Existing goldens must NOT move.** One-byte IR fingerprint
  `4236938459847922092` (9 sites) and node-routing fingerprint
  `9098559711816935340` (2 sites) stay byte-identical: the pause kind is purely
  additive (new encode tag byte 4; no existing kind's layout changes; the format
  tag byte at `normal-ir.sls:122` stays 1). Task 4 asserts this.
- **Mutation discipline** (AGENTS.md): every decision gets a mutation whose
  catch asserts a measured failure **signature** (`EXPECT_STATUS` +
  `EXPECT_OUTPUT_MATCHES`), never a bare nonzero exit; a mutation's witness
  lives in its own SPEC lane's program; after adding any exit path (every new
  coded condition is one) **re-run the whole mutation suite** and confirm each
  affected pass still discriminates for its named reason; `EXPECT_SURVIVES` only
  for the demonstrated-unwitnessable, with a written reason.
- **Predicted counts are arithmetic-to-check, not hard-coded:** re-measure
  release/pr, no-scheme, and mutation totals before writing any number into
  `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` (`SchemeMutationSuite.cmake:323-324`),
  the CHANGELOG, or a record. Expected totals after Slice ③ ≈ release 72,
  passes 38, mutations ~145-146 (the per-task chain 123 +5 +10 +2 +4 reaches
  144 at Task 4; Task 6 adds 1-2 Pass 39 mutations) — measure.
  **Measured at close (2026-08-29):** release/pr 72/72 and passes 38 landed
  on prediction; mutations landed at **161**, not ~145-146 — six review
  rounds, a pair-wise pin re-audit, and Task 7's own close-out review (which
  found exit criterion 4 short two cells and closed them, +2) added
  witnesses this arithmetic did not foresee. This prediction is left as
  written, per AGENTS.md; see CHANGELOG.md's Slice ③ entry for the measured
  total in force.
- **No new dependencies.** Only `(rnrs)` + in-repo libraries.
- **Conditions are asserted by code and who, never rendered text**
  (`conditions.sls` header; decision 0013).
- **Reserved-mirror same-commit rule** (decision 0012 item 4): a new
  `(byte-machine runtime)` export and its `reserved-member-2` entry
  (`compile.sls:44-51`) land in the same commit; new emitter-template locals
  (there are none in this slice) would go to `reserved-member-3`.
- `.superpowers/sdd/` is git-ignored: never `git add` the ledger.
- Conventional Commits; run `make test` before every commit; `mode` vocabulary,
  em-dash conventions, and comment style follow the touched file.
- Commands: `make build` configures+builds; single lane:
  `ctest --preset release -R '<lane>' --output-on-failure`; full:
  `make test-all`; no-scheme:
  `cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure`
  (use the repo's existing no-scheme preset invocation if it differs — check
  `CMakePresets.json:105-116`); mutation suite:
  `ctest --preset release -R 'scheme-mutation' --output-on-failure`.

---

## §0 Design calls locked by this plan

These resolve the freedoms design §6 left to writing-plans. Each is cited where
a task implements it; implementers do not re-litigate them, but a **measured**
contradiction is a plan defect to record in the ledger and fix (repo precedent).

**D1 — Sticky rows short-circuit at the operation entry; the parser stores the
error value (new slot 7).** §12.2's `stopped`/`error`/`finished` rows return the
sticky tuple (`next = the new call's start`, `consumed = 0`, stored
offset/error) *without re-running the executor*. Rationale: the ②a mechanism
(idempotent re-execution from a parked terminal `current`) is **demonstrated
broken** for the default-EOF truncation — `parser-finish-op!`'s default arm
(`runtime.sls:249-254`) never moves `current` off the dispatch node, and the
generated default-eof arm (`compile.sls:89-90`) re-uses the dispatch's own id as
`next-state`, so in both lanes a feed after truncation re-runs **dispatch** and
consumes bytes (②b-2 final-review carry, ledger; op≡gen-consistent). A stored
error value is the minimum state that makes the error row's "return stored
error" satisfiable; `stopped`/`finished` need no stored value. This supersedes
milestone-2-design.md §5's "the lifecycle field is observational until then" —
Task 7 adds the dated design-doc amendment. M5's full stored-*result*
short-circuit (needed for callbacks) remains deferred.

**D2 — One misuse code: `'lifecycle-violation`.** Parent §9.4:438 names the
code taxonomy ("Codes include … lifecycle violation …"); decision 0013 fixes
mechanism, not symbols. Every prohibited §12.2 cell raises
`(byte-machine-contract-violation <op-who> 'lifecycle-violation (list <state> <op>))`
with who ∈ `{parser-feed!, parser-finish!, parser-resume!}` and the detail
carrying the offending row and column. Tests assert code + who (+ detail where
the row matters). Task 7 records the enumeration as a dated note on 0013.

**D3 — `current` parks PAST the pause.** Both executors resume by re-entering
at `parser-current`; a pause therefore commits `current` to its
**continuation** before returning `paused` (generated: `next-state` = the
continuation's state id; interpreter: `parser-set-current!` to
`(op 'pause-target node)`). `parser-resume!` flips lifecycle only
(§12.1:681) — no saved-continuation field is needed; `parser-reset!` already
restores `current` to entry, which is §12.5's "clears pause continuation" for
this representation.

**D4 — Verifier integration points.** (a) `node-out-targets` gains a pause arm
returning `(list continuation)` — PASS 2 name-resolution then rejects a
malformed/missing continuation (`missing-target`, §16.2:905) and PASS 4
reachability sees through pauses for free; the §16.2:908 dispatch check is
unaffected (it filters on `byte-dispatch-node?`). (b) Byte-flow-into-finish via
a pause: a **byte-reachable** pause whose continuation is a finish node is
rejected with the existing `non-eof-into-finish` code; byte-reachability is an
entry DFS over `node-out-targets` (dispatch byte edges + reached-pause
continuations, eof-targets excluded), so an eof-only-reachable pause may
legally continue into finish (0011:40-43). (c) `eof-terminal` gains a pause arm
that chains through the continuation with the existing seen-set — an EOF pause
loop classifies `cycle` → `eof-zero-progress-cycle`, an EOF chain through
pauses into a stop → `eof-reachable-stop` (§16.2:909 "finitely many explicit
pauses"). (d) The §909/cycle walk **also runs from every byte-reachable
pause's continuation**. Under D3 a feed pause parks `current` on its
continuation and `parser-resume!` returns the row to `ready`, where
`parser-finish!` may begin EOF processing — so every byte-reachable pause's
continuation is a possible EOF-processing start, and its chain must reach
finish or error (a chain into a stop would leak `stopped` through the finish
path, which §12.1 forbids — finish returns only `paused`/`finished`/`error`).
Consequence, recorded deliberately: **a byte-reachable pause may not continue
directly (or through pauses) into a stop terminal** — put a dispatch between
them or use a finish. An entry pause is byte-reachable by definition, so
finish!-first machines are covered by the same walk with no special entry
clause. (e) PASS 5 zero-progress: pause continuations join the zero-width walk
(a reexecute/pause-only cycle with no advance is rejected — design §6), and
pause nodes join the set of walk roots. **No new diagnostic codes**: every
pause rejection reuses `missing-target` / `non-eof-into-finish` /
`eof-reachable-stop` / `eof-zero-progress-cycle` / `zero-progress-cycle`.
**Anchor duty**: two existing Pass 33 mutation FINDs sit on lines these edits
touch or duplicate (`SchemeMutationSuite.cmake:2157-2161` anchors the PASS 5
guard; `:2234-2239` anchors `(if (and tn (finish-node? tn))`) — Task 1
re-anchors them in the same commit (Steps 5 and 7).

**D5 — Normalized/generated encoding.** Pause is normalized-state kind
`'pause`, canonical encode tag byte **4**, payload u32be continuation state id.
The continuation rides slot 6 (the routing slot) as `(node . <id>)` with a
dedicated accessor `normal-pause-target`; the emitter's pause arm emits
`(byte-machine-make-feed-outcome/v1 (quote paused) pos #f <continuation-id> off)`.
No new template identifiers → `reserved-member-3` unchanged. Machines
containing pause nodes get fresh goldens (measured when the code exists —
Tasks 4/5); pause-free machines are byte-identical.

**D6 — `paused` result shapes.** Feed-path pause: `next` = first unconsumed
index (`pos`), `consumed` = `pos - start` (§10.6:608, §12.3:711). Finish-path
pause: no slice exists, so the result mirrors the `finished` convention already
shipped in ②b (`next` = stream offset, `consumed` = 0). Accessor-applicability
enforcement (§9.3:425) stays with the deferred structured-error family
(M4/M5) — the same scope call ②b made for `finished` results; Task 7's design
note names it.

**D7 — `poisoned` and `busy` rows are out** (design §7): unreachable without
callbacks; the M5 plan inherits those rows. v1-variant parsers cannot pause
(the v1 ABI predates `paused`); every new gate still applies to them uniformly,
and `parser-resume!` on a v1 parser is always a `'lifecycle-violation` (it can
never be in a paused row).

**D8 — New lanes and passes.** Three lane pairs: `byte-machine.unit.pause-interpret`
(CORE_ALL + pause-machine fixture), `byte-machine.differential.pause`
(CORE_EMIT + fixture), `byte-machine.determinism.pause` (CORE_EMIT + fixture +
`BYTE_MACHINE_PAUSE_GOLDEN_FILE` env). One new mutation pass (Pass 41,
SPEC `byte-machine.unit.pause-interpret.chez.source`) for the interpreter's
pause decisions; all other new mutations join the existing pass whose SPEC lane
already witnesses that file (32 runtime / 33 verify / 35 normal-ir /
36 compile / 39 property). `EXPECTED_PASSES` 37→38.

---

## File structure

| File | Change | Task |
|---|---|---|
| `src/byte-machine/private/ir.sls` | pause node ctor/predicate/accessors; `node?`/`node-name` arms; exports | 1 |
| `src/byte-machine/graph.sls` | re-export `make-pause-node` | 1 |
| `src/byte-machine/verify.sls` | D4 (a)–(e) | 1 |
| `test/common/verify-tests.sps` | pause acceptance + 5 rejection fixtures | 1 |
| `src/byte-machine/runtime.sls` | slot 7 stored-error; lifecycle values; gating; short-circuit; `parser-resume!`; pause arms; comment rewrites | 2 |
| `src/byte-machine/compile.sls` | `reserved-member-2` += `parser-resume!` (T2); pause render arm + else guard (T4) | 2, 4 |
| `test/common/runtime-tests.sps` | operation-matrix table via op stubs; resume; sticky short-circuit; stored error | 2 |
| `src/byte-machine/interpret.sls` | `kind` pause arm; `pause-target` message | 3 |
| `test/support/harness/byte-machine/test/pause-machine.sls` | new shared fixture | 3 |
| `test/common/pause-interpret-tests.sps` | interpreter pause walks | 3 |
| `src/byte-machine/private/normal-ir.sls` | pause lower/encode arms; `normal-pause-target`; comment updates | 4 |
| `test/common/normal-ir-tests.sps` | pause fingerprint golden (measured) | 4 |
| `test/common/compile-tests.sps` | pause render/exec assertions | 4 |
| `test/common/differential-pause-tests.sps` | op≡gen pause differential | 5 |
| `test/common/determinism-pause-tests.sps` | render-twice + committed golden + execute | 5 |
| `test/fixtures/generated-pause.golden.sls` | committed golden (generated in-task) | 5 |
| `test/CMakeLists.txt` | 3 lane pairs; pause-machine into normal-ir SOURCES | 3, 4, 5 |
| `test/support/harness/byte-machine/test/machine-gen.sls` | eof/finish/pause draws | 6 |
| `test/common/property-differential-tests.sps` | resume-aware driver | 6 |
| `test/support/cmake/SchemeMutationSuite.cmake` | new mutations (passes 32/33/35/36/39, new 41); totals; L1992 tighten | 1–7 |
| `CHANGELOG.md`, `docs/decisions/0013…`, `docs/plans/milestone-2-design.md` | close-out records | 7 |

---

### Task 1: Pause node in the source IR + verifier

**Files:**
- Modify: `src/byte-machine/private/ir.sls` (pause block after finish block
  :96-102; `node?`/`node-name` :127-135; exports :10-26)
- Modify: `src/byte-machine/graph.sls` (both lists)
- Modify: `src/byte-machine/verify.sls` (:46-58, :131-155, :175-188, :190-224)
- Modify: `test/common/verify-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 33 + totals)

**Interfaces:**
- Produces: `(make-pause-node name continuation source-label)` (parent
  §9.1:312), `pause-node?`, `pause-node-name`, `pause-node-continuation` — all
  exported from `(byte-machine private ir)`; `make-pause-node` re-exported from
  `(byte-machine graph)`. Verifier accepts the Task-3 fixture shape and rejects
  the five D4 defect shapes with existing codes.
- Consumes: nothing new.

- [ ] **Step 1: Failing tests first.** In `test/common/verify-tests.sps`, add a
  group `"pause nodes (Slice ③)"` with these cases (mirror the file's existing
  fixture style — machines built inline through `(byte-machine graph)`; assert
  diagnostics by `diagnostic-code`):

```scheme
;; Shared helper for this group: a machine over nodes with entry 'e0 and the
;; standard three error declarations, matching the group's other fixtures.
(define (pause-fixture nodes)
  (make-machine 'pm 'e0 '() '() '()
    (list (make-error-declaration 'default-eof 'eof "eof" #f)
          (make-error-declaration 'rejected 'unexpected-byte "bad byte" #f)
          (make-error-declaration 'truncated 'truncated-input "truncated" #f))
    nodes 'default-eof #f))

(harness-group "pause nodes (Slice \x2462;)"
  (lambda ()
    (harness-case "a well-formed pause machine verifies"
      (lambda ()
        ;; e0 --byte 1/advance--> p (pause) --> s1 --byte 2/advance--> stop;
        ;; e0's eof-target pauses (pe) into a finish node.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) 'pe #f)
                         (make-pause-node 'p 's1 #f)
                         (make-byte-dispatch-node 's1
                           (list (make-byte-case (make-exact-byte-matcher 2)
                                                 (make-edge 'stop 'advance) #f))
                           (make-edge 'reject 'reexecute) 'trunc #f)
                         (make-pause-node 'pe 'done #f)
                         (make-stop-node 'stop #f)
                         (make-finish-node 'done #f)
                         (make-error-node 'trunc 'truncated #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "accepted" (verification-ok? v)))))
    (harness-case "a pause continuation naming no node is malformed (\x00A7;16.2:905)"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'nowhere #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "missing-target diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'missing-target))
                         (verification-diagnostics v))))))
    (harness-case "a byte-reachable pause into a finish node is non-EOF flow (\x00A7;16.2:908)"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'done #f)
                         (make-finish-node 'done #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "non-eof-into-finish diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'non-eof-into-finish))
                         (verification-diagnostics v))))))
    (harness-case "an EOF chain of pauses that cycles is a zero-progress EOF cycle"
      (lambda ()
        ;; e0's eof-target enters pa; pa -> pb -> pa never reaches a terminal.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'stop 'advance) #f))
                           (make-edge 'reject 'reexecute) 'pa #f)
                         (make-pause-node 'pa 'pb #f)
                         (make-pause-node 'pb 'pa #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "eof-zero-progress-cycle diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-zero-progress-cycle))
                         (verification-diagnostics v))))))
    (harness-case "an EOF chain through a pause into a stop is rejected (\x00A7;16.2:909)"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'stop 'advance) #f))
                           (make-edge 'reject 'reexecute) 'pa #f)
                         (make-pause-node 'pa 'stop #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "eof-reachable-stop diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-reachable-stop))
                         (verification-diagnostics v))))))
    (harness-case "a byte-reachable pause into a stop would leak stopped through EOF (\x00A7;16.2:909)"
      (lambda ()
        ;; D4(d): after feed pauses at p, current = stop and resume returns to
        ;; ready, where finish! would begin EOF processing AT the stop.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'advance) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'stop #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "eof-reachable-stop diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-reachable-stop))
                         (verification-diagnostics v))))))
    (harness-case "an entry pause is byte-reachable, so its chain is walked too"
      (lambda ()
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-pause-node 'e0 'stop #f)
                         (make-stop-node 'stop #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "entry eof-reachable-stop diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'eof-reachable-stop))
                         (verification-diagnostics v))))))
    (harness-case "a reexecute/pause-only cycle with no advance makes no progress"
      (lambda ()
        ;; e0 --byte 1/reexecute--> p (pause) --> e0: no byte is ever consumed.
        (let ((v (verify-machine
                  (pause-fixture
                   (list (make-byte-dispatch-node 'e0
                           (list (make-byte-case (make-exact-byte-matcher 1)
                                                 (make-edge 'p 'reexecute) #f))
                           (make-edge 'reject 'reexecute) #f #f)
                         (make-pause-node 'p 'e0 #f)
                         (make-error-node 'reject 'rejected #f))))))
          (check "rejected" (not (verification-ok? v)))
          (check "zero-progress-cycle diagnostic"
                 (exists (lambda (d) (eq? (diagnostic-code d) 'zero-progress-cycle))
                         (verification-diagnostics v))))))))
```

  Match the file's existing import list, group placement, and escape/emoji
  conventions before committing the test text (the `\x2462;` escapes above are
  placeholders for however the file spells "②"-style glyphs — copy the file's
  own convention, plain ASCII "Slice 3" if that is what it uses).

- [ ] **Step 2: Run to verify failure.**
  `ctest --preset release -R 'byte-machine.verify.rejections.chez.source' --output-on-failure`
  Expected: FAIL — `make-pause-node` unbound.

- [ ] **Step 3: ir.sls.** Insert after the finish-node block (`ir.sls:96-102`):

```scheme
  ;; --- pause node (explicit continuation; returns paused -- parent §10.6) ---
  ;; One zero-width out-edge to `continuation`: pause reads no byte, so it has
  ;; no advance/reexecute mode (§11.2 defines modes only for byte reads).
  (define pause-node-tag (tag 'byte-machine-pause-node))
  (define (make-pause-node name continuation source-label)
    (require-symbol 'make-pause-node 'name name)
    (require-symbol 'make-pause-node 'continuation continuation)
    (vector pause-node-tag name continuation source-label))
  (define (pause-node? x) (tagged? pause-node-tag x))
  (define (pause-node-name n) (vector-ref n 1))
  (define (pause-node-continuation n) (vector-ref n 2))
```

  Extend `node?` (:128-129) to
  `(or (byte-dispatch-node? x) (stop-node? x) (error-node? x) (finish-node? x) (pause-node? x))`
  and `node-name` (:130-135) with
  `((pause-node? x) (pause-node-name x))` before the `else`. Add
  `make-pause-node pause-node? pause-node-name pause-node-continuation` to the
  export list beside the finish line (:20). Update the header comment's kind
  inventory (:1-8) to include the pause node.

- [ ] **Step 4: graph.sls.** Add `make-pause-node` to both the `export` list
  and the `only` import list (`graph.sls:6-12`), beside `make-finish-node`.

- [ ] **Step 5: verify.sls.** Four edits (D4):

  (a) `node-out-targets` (:46-51) gains the pause arm:

```scheme
  (define (node-out-targets n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (edge-target (byte-case-edge c)))
                        (byte-dispatch-node-cases n))
                   (list (edge-target (byte-dispatch-node-fallback n)))))
          ;; A pause's single zero-width out-edge (§10.6): resolution-checked by
          ;; PASS 2 (a malformed continuation is 'missing-target, §16.2:905) and
          ;; walked by reachability. The §16.2:908 dispatch check below filters
          ;; on byte-dispatch-node?, so this arm does not feed it.
          ((pause-node? n) (list (pause-node-continuation n)))
          (else '())))
```

  (b) PASS 5 (:131-155): add the pause arm to `reexec-targets` and widen the
  walk roots. Replace the `reexec-targets` `'()`-else shape and the final
  filter predicate:

```scheme
      (define (reexec-targets n)
        (cond ((byte-dispatch-node? n)
               (append (map (lambda (c) (edge-target (byte-case-edge c)))
                            (filter (lambda (c) (eq? (edge-mode (byte-case-edge c)) 'reexecute))
                                    (byte-dispatch-node-cases n)))
                       (if (eq? (edge-mode (byte-dispatch-node-fallback n)) 'reexecute)
                           (list (edge-target (byte-dispatch-node-fallback n))) '())))
              ;; A pause consumes no input (§12.4, design §6): its continuation
              ;; is a zero-width edge, so a reexecute/pause-only cycle with no
              ;; advance is a zero-progress cycle.
              ((pause-node? n) (list (pause-node-continuation n)))
              (else '())))
```

  and in the closing `filter`/`map`, change the guard
  `(and (byte-dispatch-node? n) (reaches-self? (node-name n)))` to
  `(and (or (byte-dispatch-node? n) (pause-node? n)) (reaches-self? (node-name n)))`.
  Keep the diagnostic code `'zero-progress-cycle`; reword the message to
  `"a zero-width cycle (reexecute edges/pause continuations) makes no progress"`.
  **This edit breaks an existing anchor** (mutations anchor CODE, not
  messages): the Pass 33 mutation "verify: zero-progress detection never fires"
  at `SchemeMutationSuite.cmake:2157-2161` FINDs the old guard
  `(if (and (byte-dispatch-node? n) (reaches-self? (node-name n)))` — after the
  edit it matches zero times and MutationRunner SEND_ERRORs. Re-anchor its
  FIND to the new widened guard text in the same commit (its `(if #f` REPLACE
  still works); confirm with
  `rg -n "reaches-self" test/support/cmake/SchemeMutationSuite.cmake` that no
  other anchor touches these lines, and record the re-anchor in the ledger.

  (c) `eof-terminal` (:175-188): insert a pause arm after the stop arm:

```scheme
                    ((pause-node? n) (loop (pause-node-continuation n) (cons name seen)))
```

  (the seen-set makes a pause loop classify `'cycle`; a chain through pauses
  into stop still classifies `'eof-reachable-stop` — §16.2:909's "finitely many
  explicit pauses").

  (d) `pass-eof-execution` (:190-224): two additions. First, a byte-reachability
  helper directly above the pass:

```scheme
  ;; Byte-flow reachability (feed can arrive): entry DFS over node-out-targets
  ;; -- dispatch case/fallback edges plus reached-pause continuations --
  ;; excluding eof-targets. An eof-only-reachable pause legally continues into
  ;; a finish node (decision 0011); a byte-reachable one must not (§16.2:908).
  (define (byte-reached m)
    (let ((nodes (machine-nodes m)) (reached '()))
      (let visit ((name (machine-entry m)))
        (let ((n (lookup nodes name)))
          (when (and n (not (memq name reached)))
            (set! reached (cons name reached))
            (for-each visit (node-out-targets n)))))
      reached))
```

  Second, inside `pass-eof-execution`'s `append`, add two new clauses after the
  existing :908 clause. Bind the byte-reached set once for both (note the
  binding is `cn`, not `tn` — the line `(if (and tn (finish-node? tn))` already
  exists at `verify.sls:201` and is the FIND of the Pass 33 mutation at
  `SchemeMutationSuite.cmake:2234-2239`; reusing it would make that anchor
  match twice and SEND_ERROR):

```scheme
       ;; D4(b)/(d): checks keyed on byte-reachability. A feed pause parks
       ;; current on its continuation and resume returns the row to ready, so
       ;; every byte-reachable pause's continuation is both a feed re-entry
       ;; point (:908 -- it must not be a finish terminal) and a possible EOF-
       ;; processing start (:909 -- its chain must reach finish or error,
       ;; never a stop, never a cycle).
       (let ((br (byte-reached m)))
         (append
          (apply append
                 (map (lambda (n)
                        (if (and (pause-node? n) (memq (node-name n) br))
                            (let ((cn (lookup nodes (pause-node-continuation n))))
                              (if (and cn (finish-node? cn))
                                  (list (make-diagnostic 'non-eof-into-finish (node-name n)
                                                         "a pause continuation byte-reaches a finish terminal"))
                                  '()))
                            '()))
                      nodes))
          (apply append
                 (map (lambda (n)
                        (if (and (pause-node? n) (memq (node-name n) br))
                            (case (eof-terminal m (pause-node-continuation n))
                              ((eof-reachable-stop)
                               (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                      "an EOF path reaches a stop terminal")))
                              ((cycle)
                               (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                      "an EOF path cycles without reaching a terminal")))
                              (else '()))
                            '()))
                      nodes))))
```

  (An entry pause is byte-reachable by definition — the DFS starts at the
  entry — so no separate entry clause exists; a byte-reachable pause whose
  continuation legally chains into a finish node is impossible, but the walk
  classifying it `'finish` falls to the else while the :908 clause above
  rejects it, so the two clauses never disagree.)

- [ ] **Step 6: Run the tests green.**
  `ctest --preset release -R 'byte-machine.verify.rejections' --output-on-failure`
  Expected: PASS (both modes). Then `make test` — expect 66/66 with no
  regression (no lane count change in this task).

- [ ] **Step 7: Pass 33 mutations.** In `SchemeMutationSuite.cmake`, extend
  Pass 33 (verifier, `SPEC byte-machine.verify.rejections.chez.source`,
  starts ~:2126) with five mutations. FIND text is the exact code from Step 5
  (re-copy from the committed file, not from this plan). Predicted signatures —
  **measure each before committing** and adjust `EXPECT_OUTPUT_MATCHES` to the
  observed harness FAIL line:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a pause continuation is an out-target (resolution + reachability)"
  FIND [[((pause-node? n) (list (pause-node-continuation n)))
          (else '())]]
  REPLACE [[((pause-node? n) '())
          (else '())]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-target")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: eof-terminal chains through a pause continuation"
  FIND [[((pause-node? n) (loop (pause-node-continuation n) (cons name seen)))]]
  REPLACE [[((pause-node? n) 'finish)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof-zero-progress-cycle")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte-reachable pause into finish is rejected"
  FIND [[(if (and cn (finish-node? cn))]]
  REPLACE [[(if (and cn #f (finish-node? cn))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "non-eof-into-finish")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: pause continuations join the zero-progress walk"
  FIND [[((pause-node? n) (list (pause-node-continuation n)))
              (else '())]]
  REPLACE [[((pause-node? n) '())
              (else '())]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "zero-progress-cycle")
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte-reachable pause's continuation chain is an EOF path"
  FIND [[(case (eof-terminal m (pause-node-continuation n))]]
  REPLACE [[(case 'finish]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof-reachable-stop")
```

  The first and fourth FINDs are the same arm text in two different functions,
  but their second lines differ in indentation (10 vs 14 spaces, matching the
  Step 5 snippets), so as written each already occurs exactly once — the
  binding gate is `rg -F` counting exactly one occurrence of every FIND (old
  Pass 33 anchors included: re-check `:2157` and `:2234` per Step 5) before
  running the suite; widen any FIND that double-matches with its preceding
  line. Bump `EXPECTED_MUTATIONS` `:324` by the number added (123→128
  predicted);
  update the header running-count narrative in the same style as the ②b
  paragraphs (~:233-321). Run
  `ctest --preset release -R 'scheme-mutation' --output-on-failure` — all
  passes green, every new mutation CAUGHT by name.

- [ ] **Step 8: Full suite + commit.** `make test` (66/66) and re-run the
  mutation lane. Commit:

```bash
git add src/byte-machine/private/ir.sls src/byte-machine/graph.sls \
        src/byte-machine/verify.sls test/common/verify-tests.sps \
        test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: pause node in source IR + verifier pause checks (M2 Slice 3 T1)"
```

---

### Task 2: Runtime lifecycle — full operation matrix, resume, sticky short-circuit

**Files:**
- Modify: `src/byte-machine/runtime.sls` (:11-18 exports; :97-130 parser
  record; :132-143 feed; :148-173 feed-op; :205-255 finish; :260-263 reset)
- Modify: `src/byte-machine/compile.sls` (:44-51 `reserved-member-2` only)
- Modify: `test/common/runtime-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 32 + totals)

**Interfaces:**
- Produces: `parser-resume!` (exported; returns `'feed-ready` | `'finish-ready`);
  lifecycle values `paused-feed`/`paused-finish`/`finish-ready`; coded
  `'lifecycle-violation` on every prohibited §12.2 cell (D2); sticky-row
  short-circuit + stored error (D1); op-path pause arms committing `current`
  to `(op 'pause-target node)` (D3). Task 3's interpreter and Task 4's emitter
  rely on: feed maps outcome/result status `paused` → lifecycle `paused-feed`;
  the finish paths map it → `paused-finish`.
- Consumes: nothing from Task 1 (this task drives runtime.sls through
  hand-built op stubs only — the SPEC-lane rule).

- [ ] **Step 1: Failing tests first.** In `test/common/runtime-tests.sps` add a
  pause-capable stub beside `one-byte-op` and the matrix groups. The stub
  machine: entry `s0` dispatch (byte 1 → advance → `p`; else reexecute →
  `reject`), `p` pause (continuation `s1`), `s1` dispatch (byte 2 → advance →
  `stop`; else reexecute → `reject`; eof-target `trunc`), s0's eof-target `pe`
  (pause, continuation `done`), `done` finish, `trunc`/`reject` errors, `stop`
  stop:

```scheme
(define (pause-op msg . args)
  (case msg
    ((entry) 's0)
    ((kind) (case (car args)
              ((s0 s1) 'dispatch) ((p pe) 'pause) ((stop) 'stop)
              ((done) 'finish) ((trunc reject) 'error)))
    ((dispatch)
     (let ((node (car args)) (byte (cadr args)))
       (case node
         ((s0) (if (= byte 1) (cons 'p 'advance) (cons 'reject 'reexecute)))
         ((s1) (if (= byte 2) (cons 'stop 'advance) (cons 'reject 'reexecute))))))
    ((pause-target) (case (car args) ((p) 's1) ((pe) 'done)))
    ((eof-target) (case (car args) ((s0) 'pe) ((s1) 'trunc)))
    ((error-value) (case (car args) ((trunc) 'truncated-input) (else 'unexpected-byte)))
    (else (assertion-violation 'pause-op "bad message" msg))))

(define (pause-parser) (make-parser (make-compiled-machine pause-op) '() #f))
(define (lifecycle-violation? who op)
  ;; D2: detail is (list <state> <op>) -- the state varies by call site, the
  ;; refused operation must match.
  (lambda (e)
    (and (byte-machine-contract-condition? e)
         (eq? (byte-machine-contract-condition-code e) 'lifecycle-violation)
         (eq? (byte-machine-contract-condition-who e) who)
         (eq? (cadr (byte-machine-contract-condition-detail e)) op))))
```

  Cases (one `harness-case` each; group `"pause + resume (§12.1)"`):

```scheme
    (harness-case "feed pauses at the pause node with the first unconsumed index"
      (lambda ()
        (let* ((p (pause-parser))
               (r (parser-feed! p (make-bytevector 2 1) 0 2)))   ; bytes 1 1
          (check-equal "status" (parser-result-status r) 'paused)
          (check-equal "next" (parser-result-next r) 1)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-feed))))
    (harness-case "resume from a feed pause acks feed-ready and reopens feed"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (check-equal "ack" (parser-resume! p) 'feed-ready)
          (check-equal "lifecycle" (parser-lifecycle p) 'ready)
          (let ((r (parser-feed! p (make-bytevector 1 2) 0 1)))
            (check-equal "continues past the pause" (parser-result-status r) 'stopped)))))
    (harness-case "finish! pauses on the EOF path and resumes to finish-ready"
      (lambda ()
        (let* ((p (pause-parser))
               (r (parser-finish! p)))
          (check-equal "status" (parser-result-status r) 'paused)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-finish)
          (check-equal "ack" (parser-resume! p) 'finish-ready)
          (check-equal "lifecycle now" (parser-lifecycle p) 'finish-ready)
          (let ((r2 (parser-finish! p)))
            (check-equal "continues to finished" (parser-result-status r2) 'finished)
            (check-equal "lifecycle final" (parser-lifecycle p) 'finished)))))
```

  Group `"operation matrix (§12.2)"` — every prohibited cell, plus sticky rows:

```scheme
    (harness-case "feed is prohibited in paused-feed, paused-finish, and finish-ready"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)             ; -> paused-feed
          (check-raises "feed on paused-feed" (lifecycle-violation? 'parser-feed! 'feed)
            (lambda () (parser-feed! p (make-bytevector 1 2) 0 1))))
        (let ((p (pause-parser)))
          (parser-finish! p)                                     ; -> paused-finish
          (check-raises "feed on paused-finish" (lifecycle-violation? 'parser-feed! 'feed)
            (lambda () (parser-feed! p (make-bytevector 1 2) 0 1)))
          (parser-resume! p)                                     ; -> finish-ready
          (check-raises "feed on finish-ready" (lifecycle-violation? 'parser-feed! 'feed)
            (lambda () (parser-feed! p (make-bytevector 1 2) 0 1))))))
    (harness-case "finish is prohibited while paused"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)
          (check-raises "finish on paused-feed" (lifecycle-violation? 'parser-finish! 'finish)
            (lambda () (parser-finish! p))))
        (let ((p (pause-parser)))
          (parser-finish! p)
          (check-raises "finish on paused-finish" (lifecycle-violation? 'parser-finish! 'finish)
            (lambda () (parser-finish! p))))))
    (harness-case "resume is prohibited outside the paused rows"
      (lambda ()
        (check-raises "resume on ready" (lifecycle-violation? 'parser-resume! 'resume)
          (lambda () (parser-resume! (pause-parser))))
        (let ((p (pause-parser)))
          (parser-finish! p) (parser-resume! p)                  ; -> finish-ready
          (check-raises "resume on finish-ready" (lifecycle-violation? 'parser-resume! 'resume)
            (lambda () (parser-resume! p))))
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)             ; -> stopped
          (check-raises "resume on stopped" (lifecycle-violation? 'parser-resume! 'resume)
            (lambda () (parser-resume! p))))))
    (harness-case "sticky rows short-circuit: stopped feed/finish return the tuple"
      (lambda ()
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)
          (let ((r (parser-feed! p (make-bytevector 3 0) 1 3)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "next is the new start" (parser-result-next r) 1)
            (check-equal "consumed zero" (parser-result-consumed r) 0))
          (check-equal "finish on stopped returns stopped"
                       (parser-result-status (parser-finish! p)) 'stopped))))
    (harness-case "the error row returns the stored error after a feed error"
      (lambda ()
        ;; Witnesses parser-feed!'s own store (the finish-path store below is a
        ;; separate site with its own mutation).
        (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
          (parser-feed! p (make-bytevector 1 65) 0 1)            ; -> error
          (let ((r (parser-feed! p (make-bytevector 1 0) 0 1)))
            (check-equal "sticky status" (parser-result-status r) 'error)
            (check-equal "feed-stored error value" (parser-result-error r) 'unexpected-byte))
          (check-equal "finish repeats the feed-stored error"
                       (parser-result-error (parser-finish! p)) 'unexpected-byte))))
    (harness-case "the error row returns the stored error after a default-EOF truncation"
      (lambda ()
        ;; Closes the \x2461;b-2 carry: with default-eof-op (eof-target #f), finish!
        ;; errors via the machine default while current stays on the dispatch node;
        ;; the old re-execution mechanism would re-run dispatch and consume bytes.
        (let ((p (make-parser (make-compiled-machine default-eof-op) '() #f)))
          (parser-finish! p)
          (let ((r (parser-feed! p (make-bytevector 1 0) 0 1)))
            (check-equal "status stays error" (parser-result-status r) 'error)
            (check-equal "consumed zero" (parser-result-consumed r) 0)
            (check-equal "stored error value" (parser-result-error r) 'eof))
          (check-equal "finish repeats the stored error"
                       (parser-result-error (parser-finish! p)) 'eof))))
    (harness-case "reset recovers every reachable row to ready"
      (lambda ()
        (let ((p (pause-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)             ; paused-feed
          (parser-reset! p)
          (check-equal "from paused-feed" (parser-lifecycle p) 'ready))
        (let ((p (pause-parser)))
          (parser-finish! p) (parser-resume! p)                  ; finish-ready
          (parser-reset! p)
          (check-equal "from finish-ready" (parser-lifecycle p) 'ready)
          (check-equal "re-feeds from entry"
                       (parser-result-status (parser-feed! p (make-bytevector 1 1) 0 1))
                       'paused))))
```

  Reuse the file's existing `default-eof-op` stub (:~80-95); check its
  machine default error code (the existing test asserts `'eof`) and keep the
  assertion consistent with it.

- [ ] **Step 2: Run to verify failure.**
  `ctest --preset release -R 'byte-machine.unit.runtime.chez.source' --output-on-failure`
  Expected: FAIL — `parser-resume!` unbound.

- [ ] **Step 3: runtime.sls.** All edits in one coherent change:

  (a) Export list (:15): `parser-feed! parser-finish! parser-resume! parser-lifecycle parser-reset!`.

  (b) Parser record comment + shape (:97-130): 8th slot `stored-error`, and the
  comment block replaced (it is an instruction, corrected in place):

```scheme
  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor entry current offset lifecycle stored-error)
  ;; lifecycle: ready | paused-feed | paused-finish | finish-ready | stopped |
  ;; error | finished (§12.1; poisoned/busy are M5 rows). Sticky rows
  ;; short-circuit at the operation entry and synthesize the §12.2 tuple
  ;; (next = the new call's start, consumed = 0, stored offset/error) without
  ;; re-running the executor: ②a's idempotent re-execution broke on default-EOF
  ;; truncation, which parks `current` on a dispatch node (②b-2 final review).
  ;; stored-error (slot 7) is the error value the error row returns; #f
  ;; otherwise. M5's full stored-result short-circuit (callbacks) stays deferred.
```

  The three `make-parser` arms (:112, :116, :120) each gain a trailing `#f`
  (e.g. `(vector parser-tag 'op op entry entry 0 'ready #f)`); add accessors:

```scheme
  (define (parser-stored-error p) (vector-ref p 7))
  (define (parser-set-stored-error! p v) (vector-set! p 7 v))
```

  (c) `parser-feed!` (:132-143) becomes:

```scheme
  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    (case (parser-lifecycle parser)
      ((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation
                                        (list (parser-lifecycle parser) 'feed)))
      ((stopped) (make-parser-result 'stopped start 0 (parser-offset parser) #f))
      ((error) (make-parser-result 'error start 0 (parser-offset parser)
                                   (parser-stored-error parser)))
      ((finished) (make-parser-result 'finished start 0 (parser-offset parser) #f))
      (else
       (let ((r (case (parser-variant parser)
                  ((op) (parser-feed-op! parser bv start end))
                  ((v2) (parser-feed-v2! parser bv start end))
                  (else (parser-feed-v1! parser bv start end)))))
         (case (parser-result-status r)
           ((stopped) (parser-set-lifecycle! parser 'stopped))
           ((error) (parser-set-lifecycle! parser 'error)
                    (parser-set-stored-error! parser (parser-result-error r)))
           ((finished) (parser-set-lifecycle! parser 'finished))
           ((paused) (parser-set-lifecycle! parser 'paused-feed)))
         r))))
```

  (d) `parser-feed-op!` (:148-173): insert the pause arm after the finish arm
  (:158-159):

```scheme
            ((pause)
             ;; D3: commit current PAST the pause -- the resumed feed re-enters
             ;; at the continuation, mirroring the generated next-state.
             (parser-set-current! parser (op 'pause-target node))
             (make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))
```

  Rewrite the stale mechanism comment above the function (:145-147) to say the
  sticky rows now short-circuit in `parser-feed!` (this loop no longer serves
  repeat feeds on a terminal parser).

  (e) `parser-finish!` (:205-209) becomes:

```scheme
  (define (parser-finish! parser)
    (case (parser-lifecycle parser)
      ((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation
                                        (list (parser-lifecycle parser) 'finish)))
      ((stopped) (make-parser-result 'stopped (parser-offset parser) 0
                                     (parser-offset parser) #f))
      ((error) (make-parser-result 'error (parser-offset parser) 0
                                   (parser-offset parser) (parser-stored-error parser)))
      ((finished) (make-parser-result 'finished (parser-offset parser) 0
                                      (parser-offset parser) #f))
      (else                             ; ready | finish-ready
       (case (parser-variant parser)
         ((op) (parser-finish-op! parser))
         ((v2) (parser-finish-v2! parser))
         (else (assertion-violation 'parser-finish! "v1 has no finish path"
                                    (parser-variant parser)))))))
```

  (f) `parser-finish-v2!` (:215-225): status case gains
  `((paused) (parser-set-lifecycle! parser 'paused-finish))` and the error arm
  stores the value:
  `((error) (parser-set-lifecycle! parser 'error) (parser-set-stored-error! parser (feed-outcome-error o)))`.

  (g) `parser-finish-op!` (:227-255): pause arm after the finish arm; error and
  default-eof arms store their values:

```scheme
          ((pause)
           (parser-set-current! parser (op 'pause-target node))
           (parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f))
```

```scheme
          ((error)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'error)
           (let ((e (op 'error-value node)))
             (parser-set-stored-error! parser e)
             (make-parser-result 'error off 0 off e)))
```

```scheme
                 (begin (parser-set-lifecycle! parser 'error)
                        (let ((e (op 'default-eof-value)))
                          (parser-set-stored-error! parser e)
                          (make-parser-result 'error off 0 off e)))
```

  (h) `parser-resume!` before `parser-reset!`:

```scheme
  ;; §12.1: resume changes lifecycle only -- no callback, no input, no executor
  ;; run. paused-feed -> ready ('feed-ready ack); paused-finish -> finish-ready
  ;; ('finish-ready ack, which is also the state awaiting the next finish!).
  ;; Every other row of §12.2's resume! column is a prohibited cell.
  (define (parser-resume! parser)
    (case (parser-lifecycle parser)
      ((paused-feed) (parser-set-lifecycle! parser 'ready) 'feed-ready)
      ((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'finish-ready)
      (else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))))
```

  (i) `parser-reset!` (:260-263): add `(parser-set-stored-error! parser #f)`
  and update its comment — the M2 subset now also clears the stored error, and
  `current := entry` is what clears the pause continuation (§12.5).

- [ ] **Step 4: reserved-member-2 (same commit — decision 0012 item 4).** In
  `compile.sls:48`, the line becomes:

```scheme
      make-parser parser? parser-feed! parser-finish! parser-resume!
      parser-lifecycle parser-reset!
```

  (keep the surrounding list intact; only `parser-resume!` is added).

- [ ] **Step 5: Green + blast radius.**
  `ctest --preset release -R 'byte-machine.unit.runtime' --output-on-failure` → PASS;
  `ctest --preset release -R 'byte-machine.unit.reserved-drift' --output-on-failure`
  → PASS (set-equality holds with the mirrored export). Then `make test`
  (66/66) — the sticky-repeat and finish-path lanes (interpret/eof-interpret/
  differential/example) must stay green: the short-circuit synthesizes the same
  tuples those tests assert.

- [ ] **Step 6: Pass 32 mutations + whole-suite re-run.** Add to Pass 32
  (SPEC `byte-machine.unit.runtime.chez.source`, ~:1931). FINDs anchor the
  Step-3 code verbatim (copy from the committed file; confirm uniqueness with
  `rg -F`). Predicted set — measure every signature:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume on paused-feed reopens feed, not finish"
  FIND [[((paused-feed) (parser-set-lifecycle! parser 'ready) 'feed-ready)]]
  REPLACE [[((paused-feed) (parser-set-lifecycle! parser 'finish-ready) 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "continues past the pause")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume on paused-finish acks finish-ready"
  FIND [[((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'finish-ready)]]
  REPLACE [[((paused-finish) (parser-set-lifecycle! parser 'finish-ready) 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ack")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: resume outside the paused rows is a prohibited cell"
  FIND [[(else (byte-machine-contract-violation 'parser-resume! 'lifecycle-violation
                                             (list (parser-lifecycle parser) 'resume)))]]
  REPLACE [[(else 'feed-ready)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "resume on ready")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: feed refuses every paused/finish-ready row"
  FIND [[((paused-feed paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  REPLACE [[((paused-finish finish-ready)
       (byte-machine-contract-violation 'parser-feed! 'lifecycle-violation]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "feed on paused-feed")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: finish refuses the paused rows"
  FIND [[((paused-feed paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation]]
  REPLACE [[((paused-finish)
       (byte-machine-contract-violation 'parser-finish! 'lifecycle-violation]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finish on paused-feed")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the error row returns the STORED error"
  FIND [[((error) (parser-set-lifecycle! parser 'error)
                    (parser-set-stored-error! parser (parser-result-error r)))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'error))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "feed-stored error value")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a feed pause maps to paused-feed, not paused-finish"
  FIND [[((paused) (parser-set-lifecycle! parser 'paused-feed))]]
  REPLACE [[((paused) (parser-set-lifecycle! parser 'paused-finish))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ack")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the feed pause arm parks current on the continuation"
  FIND [[(parser-set-current! parser (op 'pause-target node))
             (make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))]]
  REPLACE [[(make-parser-result 'paused pos (- pos start) (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "continues past the pause")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an EOF pause parks paused-finish, not paused-feed"
  FIND [[(parser-set-lifecycle! parser 'paused-finish)
           (make-parser-result 'paused off 0 off #f))]]
  REPLACE [[(parser-set-lifecycle! parser 'paused-feed)
           (make-parser-result 'paused off 0 off #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "lifecycle")
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the stopped row short-circuits with consumed zero"
  FIND [[((stopped) (make-parser-result 'stopped start 0 (parser-offset parser) #f))]]
  REPLACE [[((stopped) (make-parser-result 'stopped start 1 (parser-offset parser) #f))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "consumed")
```

  **Then the AGENTS.md exit-path rule:** this task adds three raise sites and a
  short-circuit that bypasses executor arms — run the FULL mutation suite. Four
  pre-existing Pass 32 anchors are broken **textually** by Step 3 and must be
  re-anchored in the same commit (MutationRunner SEND_ERRORs on FIND count ≠ 1):
  the stopped-lifecycle mutation (~:2021, its FIND at :2029-2030 anchors
  `(case (parser-result-status r)` at the OLD indentation — Step 3(c) re-nests
  it under the `else` arm); the error-lifecycle mutation (~:2035, FIND at
  :2042-2043 anchors the old two-line error/finished arms — the error arm now
  stores the value); the default-eof routing mutation (~:2080, FIND at :2083
  anchors `(make-parser-result 'error off 0 off (op 'default-eof-value))`,
  which Step 3(g)'s let-bound rewrite deletes); and the reset-ready mutation
  (~:2062, FIND `(parser-set-lifecycle! parser 'ready)` — unique today, but
  `parser-resume!` adds a second occurrence, so widen it with the preceding
  `(parser-set-offset! parser 0)` line). ("a feed on a finished parser does not
  return finished", ~:2092, is NOT affected: its witness feeds a FRESH parser
  parked at a finish node, lifecycle `ready`, so the short-circuit never
  fires.) Then re-examine the rest of Pass 32 for semantic disarms: for each
  mutation now caught for a different reason or uncaught, re-anchor it or its
  witness so it still discriminates its named decision, and record what moved
  in the ledger. Bump `EXPECTED_MUTATIONS` (predicted 128→138) and the header
  narrative; re-run `ctest --preset release -R 'scheme-mutation'` to green.

- [ ] **Step 7: Full suite + commit.** `make test` 66/66; no-scheme preset 8/8.

```bash
git add src/byte-machine/runtime.sls src/byte-machine/compile.sls \
        test/common/runtime-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: full operation matrix, parser-resume!, sticky short-circuit (M2 Slice 3 T2)"
```

---

### Task 3: Interpreter pause + shared fixture + pause-interpret lane

**Files:**
- Modify: `src/byte-machine/interpret.sls` (:32-38 `kind`; :54-63 op closure)
- Create: `test/support/harness/byte-machine/test/pause-machine.sls`
- Create: `test/common/pause-interpret-tests.sps`
- Modify: `test/CMakeLists.txt` (new lane pair after :845)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new Pass 41; totals)

**Interfaces:**
- Consumes: Task 1's `pause-node?`/`pause-node-continuation`; Task 2's runtime
  behavior (`paused`→`paused-feed`/`paused-finish`, `parser-resume!`).
- Produces: `(byte-machine test pause-machine)` exporting `make-pause-machine`
  — node order `s0 p1 s1 pe stop done trunc reject` (ids 0-7, entry 0), reused
  verbatim by Tasks 4-5; interpreter `op` understands `'pause` kind and the
  `'pause-target` message.

- [ ] **Step 1: The fixture** (mirrors `eof-machine.sls`'s header/style):

```scheme
;;; The pause/resume proving machine for Milestone 2 Slice ③, built only
;;; through (byte-machine graph). Feed: byte 1 advances into pause p1
;;; (continuation s1); after resume, byte 2 stops. EOF at entry routes to the
;;; eof-path pause pe (continuation done/finish): finish! pauses, resume,
;;; finish! -> finished. EOF after byte 1 (at s1) is truncation ('trunc ->
;;; error). Shared by the Slice ③ interpreter tests, the pause differential,
;;; and the pause determinism golden so the graph is written once.
(library (byte-machine test pause-machine)
  (export make-pause-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-pause-machine)
    (make-machine 'pausem 's0 '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'truncated 'truncated-input "truncated input" #f))
      (list (make-byte-dispatch-node 's0
              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'p1 'advance) #f))
              (make-edge 'reject 'reexecute) 'pe #f)
            (make-pause-node 'p1 's1 #f)
            (make-byte-dispatch-node 's1
              (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
              (make-edge 'reject 'reexecute) 'trunc #f)
            (make-pause-node 'pe 'done #f)
            (make-stop-node 'stop #f)
            (make-finish-node 'done #f)
            (make-error-node 'trunc 'truncated #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))
```

- [ ] **Step 2: Failing test.** `test/common/pause-interpret-tests.sps`
  (imports mirror `eof-interpret-tests.sps`: harness, graph? no — pause-machine,
  verify, interpret, runtime):

```scheme
;;; The shared pause machine driven end-to-end through the interpreter: the
;;; feed pause/resume walk, the EOF pause/resume walk, truncation after resume,
;;; and all-256 first-byte coverage of the paused-vs-rejected split.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine test pause-machine)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(harness-begin "unit.pause-interpret")

(define (fresh-parser)
  (make-parser (make-interpreted-machine (verify-machine (make-pause-machine))) '() #f))

(harness-group "feed pause walk"
  (lambda ()
    (harness-case "byte 1 pauses with one byte consumed; resume; byte 2 stops"
      (lambda ()
        (let* ((p (fresh-parser))
               (r1 (parser-feed! p (u8-list->bytevector '(1 2)) 0 2)))
          (check-equal "paused" (parser-result-status r1) 'paused)
          (check-equal "next" (parser-result-next r1) 1)
          (check-equal "consumed" (parser-result-consumed r1) 1)
          (check-equal "offset" (parser-result-stream-offset r1) 1)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-feed)
          (check-equal "ack" (parser-resume! p) 'feed-ready)
          (let ((r2 (parser-feed! p (u8-list->bytevector '(1 2)) 1 2)))
            (check-equal "stopped" (parser-result-status r2) 'stopped)
            (check-equal "offset 2" (parser-result-stream-offset r2) 2)))))))

(harness-group "EOF pause walk"
  (lambda ()
    (harness-case "finish pauses, resumes to finish-ready, finishes"
      (lambda ()
        (let* ((p (fresh-parser))
               (r1 (parser-finish! p)))
          (check-equal "paused" (parser-result-status r1) 'paused)
          (check-equal "lifecycle" (parser-lifecycle p) 'paused-finish)
          (check-equal "ack" (parser-resume! p) 'finish-ready)
          (let ((r2 (parser-finish! p)))
            (check-equal "finished" (parser-result-status r2) 'finished)
            (check-equal "sticky finished feed"
                         (parser-result-status (parser-feed! p (make-bytevector 1 1) 0 1))
                         'finished)))))
    (harness-case "truncation after a resumed pause carries the eof offset"
      (lambda ()
        (let ((p (fresh-parser)))
          (parser-feed! p (make-bytevector 1 1) 0 1)   ; paused at p1
          (parser-resume! p)
          (let ((r (parser-finish! p)))                ; s1's eof-target -> trunc
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "code" (parser-result-error r) 'truncated-input)
            (check-equal "offset" (parser-result-stream-offset r) 1)))))))

(harness-group "all-256 first bytes"
  (lambda ()
    (harness-case "byte 1 pauses; every other byte rejects at offset 0"
      (lambda ()
        (let loop ((b 0))
          (when (< b 256)
            (let* ((p (fresh-parser))
                   (r (parser-feed! p (make-bytevector 1 b) 0 1)))
              (if (= b 1)
                  (check-equal "paused" (parser-result-status r) 'paused)
                  (begin
                    (check-equal "error" (parser-result-status r) 'error)
                    (check-equal "code" (parser-result-error r) 'unexpected-byte)
                    (check-equal "offset" (parser-result-stream-offset r) 0))))
            (loop (+ b 1))))))))

(harness-finish)
```

  (`harness-finish` is the terminator every `.sps` program in `test/common/`
  ends with — e.g. `eof-interpret-tests.sps:112`; the harness exports no
  `harness-end`.)

- [ ] **Step 3: Lane pair.** After the eof-interpret pair
  (`test/CMakeLists.txt:845`), mirroring its exact shape:

```cmake
# Milestone 2 Slice ③: the shared pause/resume proving machine driven through
# the interpreter's pause arms and the runtime's paused-feed/paused-finish/
# finish-ready lifecycle.
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.pause-interpret.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.pause-interpret.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/pause-interpret-tests.sps"
  TIMEOUT 120)
```

  Run the source lane: FAIL — the interpreter raises
  `'internal` on the pause node (`kind`'s else).

- [ ] **Step 4: interpret.sls.** In `kind` (:32-38), before the else:
  `((pause-node? n) 'pause)`. In the op closure (:54-63), after the
  `eof-target` message:

```scheme
           ((pause-target) (pause-node-continuation (lookup nodes (car args))))
```

  Update the header comment if it enumerates kinds.

- [ ] **Step 5: Green.** Both pause-interpret lanes PASS; `make test` —
  expected 68/68 (66 + the new pair; **measure**, record actual).

- [ ] **Step 6: New mutation Pass 41.** Model its skeleton on Pass 34
  (~:2257): `byte_machine_mutation_reset()`, then a verify command copied from
  Pass 34's stanza (~:2267-2275) with `--program` swapped to
  `"${STAGE_DIR}/test/common/pause-interpret-tests.sps"`. No fixture-staging
  step exists or is needed: the suite stages `test/support/harness` and
  `test/common` whole (`BYTE_MACHINE_MUTATION_STAGE_DIRS`,
  `SchemeMutationSuite.cmake:368-370`), so pause-machine.sls and the new
  program arrive automatically. Then:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.pause-interpret.chez.source
  LABEL "interpret: a pause node has its own kind"
  FIND [[((pause-node? n) 'pause)]]
  REPLACE [[((pause-node? n) 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "paused")
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.pause-interpret.chez.source
  LABEL "interpret: pause-target resolves the continuation, not the pause itself"
  FIND [[((pause-target) (pause-node-continuation (lookup nodes (car args))))]]
  REPLACE [[((pause-target) (car args))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "stopped")
```

  Measure both signatures. Bump `EXPECTED_PASSES` 37→38 and
  `EXPECTED_MUTATIONS` (+2); header narrative. Full mutation lane green.

- [ ] **Step 7: Commit.**

```bash
git add src/byte-machine/interpret.sls \
        test/support/harness/byte-machine/test/pause-machine.sls \
        test/common/pause-interpret-tests.sps test/CMakeLists.txt \
        test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: interpreter pause kind + shared pause-machine fixture + lane (M2 Slice 3 T3)"
```

---

### Task 4: Normalizer + emitter pause arms

**Files:**
- Modify: `src/byte-machine/private/normal-ir.sls` (:14-22 imports; :31-42
  layout comment + accessor; :96-114 lower; :119-148 encode; :67-68, :111-113
  comments; :8-13 exports)
- Modify: `src/byte-machine/compile.sls` (:92-113 render-state-arm)
- Modify: `test/common/normal-ir-tests.sps` (pause fingerprint golden)
- Modify: `test/common/compile-tests.sps` (pause render assertions)
- Modify: `test/CMakeLists.txt` (pause-machine.sls into both
  `byte-machine.unit.normal-ir` SOURCES, :856-859 and :866-869)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Passes 35/36; totals)

**Interfaces:**
- Consumes: Task 1's `pause-node?`/`pause-node-continuation`; Task 3's fixture.
- Produces: normalized kind `'pause` (encode tag 4 + u32be continuation id);
  `normal-pause-target` exported; generated pause arm
  `((<id>) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f <cont-id> off))`.
  Task 5 relies on both plus the fixture's node ids (s0=0 p1=1 s1=2 pe=3
  stop=4 done=5 trunc=6 reject=7).

- [ ] **Step 1: Failing tests.** (a) `normal-ir-tests.sps`: add a group after
  the node-routing golden block (:95-115), importing
  `(byte-machine test pause-machine)` beside the existing eof-machine import —
  **and, in this same step, add**
  `"${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"`
  to both normal-ir lane SOURCES (after the eof-machine lines,
  `test/CMakeLists.txt:858` and `:868`), or the Step-2 red run dies at import
  (library not found) instead of at the normalizer:

```scheme
(harness-group "pause normalization (Slice ③)"
  (lambda ()
    (harness-case "pause states lower to kind pause with the continuation id"
      (lambda ()
        ;; Node order s0 p1 s1 pe stop done trunc reject -> ids 0..7.
        (let* ((nm (normalize-machine
                    (verification-machine (verify-machine (make-pause-machine)))))
               (states (normal-machine-states nm))
               (p1 (vector-ref states 1))
               (pe (vector-ref states 3)))
          (check-equal "p1 kind" (normal-state-kind p1) 'pause)
          (check-equal "p1 target" (normal-pause-target p1) 2)
          (check-equal "pe kind" (normal-state-kind pe) 'pause)
          (check-equal "pe target" (normal-pause-target pe) 5))))
    (harness-case "the pause encoding is pinned by a fingerprint golden"
      (lambda ()
        ;; MEASURED through the shipped normalizer once the encode arm lands
        ;; (Step 5) -- the ②b-2 node-routing golden's measure-then-pin protocol.
        ;; The literal 0 below is deliberately wrong so the first post-encode
        ;; run FAILS printing expected-vs-actual; pin the printed actual.
        (check-equal "pause fingerprint"
                     (normal-machine-fingerprint
                      (normalize-machine
                       (verification-machine
                        (verify-machine (make-pause-machine)))))
                     0)))))
```

  Follow the file's actual normalize/verify call chain (:95-115 shows whether
  it goes through `verify-machine` or hands the machine straight to
  `normalize-machine`) — copy that chain, not this sketch's. After Step 5's
  measurement, replace the wrong literal with the measured one and record the
  value in the ledger.
  (b) `compile-tests.sps`: add a case rendering the pause machine — inline the
  same graph as the shared fixture with a comment naming
  `(byte-machine test pause-machine)` as the source of truth (the ②b-2
  `eof-fin` inline-fixture precedent; the compile lanes carry no fixture
  libraries today). **Render-substring assertions only** — this file's charter
  is the rendered text, not execution (header :1-5: "the generated parser's
  behaviour is proven end-to-end in the differential and example lanes"), and
  its CORE_COMPILE lane manifest carries no `runtime.sls`, so a compile+eval
  case cannot even load the generated library here. The execution walks
  (feed 1 → paused / resume / feed 2 → stopped; finish → paused / resume /
  finished) are Task 5's, in the CORE_EMIT lanes. Assert, via the file's
  existing substring-check helper (the `:94` idiom — reuse its helper name;
  there is no R6RS `string-contains`), that the rendered text contains both
  pause arms:

```text
((1) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 2 off))
((3) (byte-machine-make-feed-outcome/v1 (quote paused) pos #f 5 off))
```

- [ ] **Step 2: Run red.** Normal-ir source lane and compile source lane both
  FAIL (`assertion-violation 'normalize-machine "unknown node kind"`).

- [ ] **Step 3: normal-ir.sls.**
  - imports (:15-22): add `pause-node? pause-node-continuation` to the `only`
    list.
  - exports (:8-13): add `normal-pause-target`.
  - layout comment (:32-36): extend the slot-6 note:
    `;;   pause states carry (node . <continuation-id>) there (Slice ③).`
  - accessor after :42: `(define (normal-pause-target s) (cdr (vector-ref s 6)))`
  - lower arm after the finish arm (:110):

```scheme
                                     ((pause-node? n)
                                      (vector ns-tag 'pause i #f #f #f
                                              (cons 'node (id-of (pause-node-continuation n)))))
```

  - correct the closed-set comment (:111-113) in place: "exactly these five
    node kinds (dispatch/stop/error/finish/pause)" and the :67-68 header note
    ("a sixth node/state kind").
  - encode arm after `((finish) (put-u8 p 3))` (:145):

```scheme
               ;; pause: tag 4 + u32be continuation state id (D5).
               ((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))
```

- [ ] **Step 4: compile.sls.** In `render-state-arm` (:92-113), after the
  finish arm (:100-101):

```scheme
        ((pause)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote paused) pos #f "
                        (number->string (normal-pause-target s)) " off))\n"))
```

  and close the case with an inspected guard after the dispatch arm (the same
  convention as normal-ir's else guards — no mutation, unreachable today):

```scheme
        (else (assertion-violation 'render-machine "unknown state kind"
                                   (normal-state-kind s))))))
```

  Paren accounting: the dispatch arm's current last line (:113) ends with the
  closers for `case`/`let`/`define` as well as its own — adding an `else`
  clause after it means those three outer closers move from :113's tail onto
  the guard line above. Rebalance accordingly (a slip fails loudly at compile,
  so this costs time, not correctness).

- [ ] **Step 5: Measure + pin the golden.** (SOURCES wiring landed in Step 1.)
  Run the normal-ir lane: the structural checks pass, the deliberately-wrong
  `check-equal ... 0` FAILS printing the measured pause fingerprint; pin that
  literal, re-run green. Run compile lanes green.
  **Assert the no-move constraint:** `rg -c '4236938459847922092' test/ src/`
  and `rg -c '9098559711816935340' test/` — unchanged counts; the one-byte and
  eof lanes plus `determinism.one-byte` all green (`make test`, expected 68/68
  measured).

- [ ] **Step 6: Pass 35/36 mutations.** Pass 35 (normalizer, SPEC
  `byte-machine.unit.normal-ir.chez.source`, ~:2301):

```cmake
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: a pause lowers its continuation id, not its own"
  FIND [[(cons 'node (id-of (pause-node-continuation n)))]]
  REPLACE [[(cons 'node i)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "p1 target")
byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the pause encode arm hashes tag and continuation"
  FIND [[((pause) (put-u8 p 4) (put-u32be p (normal-pause-target s)))]]
  REPLACE [[((pause) (put-u8 p 4))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "pause fingerprint")
```

  Pass 36 (emitter, SPEC `byte-machine.unit.compile.chez.source`, ~:2392):

```cmake
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm emits paused"
  FIND [[(quote paused) pos #f "]]
  REPLACE [[(quote stopped) pos #f "]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "pause arm")
byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the pause arm's next-state is the continuation"
  FIND [[(number->string (normal-pause-target s)) " off))\n"))]]
  REPLACE [[id " off))\n"))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "pause arm")
```

  Replace every `<measured>` with the observed harness FAIL line before
  committing (the suite's own wrong-reason check refuses a wrong signature —
  ledger precedent). Verify FIND uniqueness with `rg -F`; totals bump
  (predicted +4, 140→144 running); header narrative; full mutation lane green.

- [ ] **Step 7: Commit.**

```bash
git add src/byte-machine/private/normal-ir.sls src/byte-machine/compile.sls \
        test/common/normal-ir-tests.sps test/common/compile-tests.sps \
        test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: normalizer + emitter pause arms, pause fingerprint golden (M2 Slice 3 T4)"
```

---

### Task 5: Pause differential + determinism golden

**Files:**
- Create: `test/common/differential-pause-tests.sps`
- Create: `test/common/determinism-pause-tests.sps`
- Create: `test/fixtures/generated-pause.golden.sls` (generated in-task)
- Modify: `test/CMakeLists.txt` (two lane pairs after :986 and :1026)

**Interfaces:**
- Consumes: everything above; `make-pause-machine`; the determinism-one-byte
  program (:read `determinism-one-byte-tests.sps` as the template) and
  `differential-eof-tests.sps` as the differential template.
- Produces: lanes `byte-machine.differential.pause.chez.{source,aot}` and
  `byte-machine.determinism.pause.chez.{source,aot}`; the committed golden;
  env var `BYTE_MACHINE_PAUSE_GOLDEN_FILE`.

- [ ] **Step 1: Differential program.** `differential-pause-tests.sps`, built
  from `differential-eof-tests.sps`'s structure (cm-ref = interpreted, cm-gen =
  eval of the emitted `(generated pausem)` library): for each of the 256 first
  bytes, run the same schedule on both parsers and compare, field by field,
  after every step — status, next, consumed, stream-offset, error, AND
  `parser-lifecycle` (the §22.4 "pause continuations" comparison is observable
  as: identical post-resume continuation behavior). Schedule per byte b:
  feed `[b]`; if both paused → resume both (compare acks), feed `[2]`, compare
  (stopped for b=1); else compare the error results. Then the finish walks:
  fresh parsers, finish! → compare paused; resume both → compare acks; finish!
  → compare finished. And the truncation walk (feed 1, resume, finish!) —
  compare error + offset. Seed a `bad` flag exactly as the eof differential
  does so a vacuous run cannot pass.
- [ ] **Step 2: Determinism program + golden.**
  `determinism-pause-tests.sps` mirrors `determinism-one-byte-tests.sps`
  (:read it first): render twice in-process → byte-equal; render vs
  `BYTE_MACHINE_PAUSE_GOLDEN_FILE` → byte-equal; emit to tmpdir, load+eval,
  run the feed-pause-resume-stop walk and the finish-pause-resume-finished
  walk. Generate the golden from the shipped emitter
  (`render-machine` over `(compile-machine (make-pause-machine) '())`, binding
  `pausem`) via a one-off `chez --script` invocation, write it to
  `test/fixtures/generated-pause.golden.sls`, and commit it; record its
  embedded fingerprint (must equal Task 4's measured golden) in the ledger.
- [ ] **Step 3: Lanes.** After :986 (differential block) and after :1026
  (determinism block), mirroring their neighbors exactly:

```cmake
# --- Milestone 2 Slice ③: interpreter≡generated differential over pause/resume --
byte_machine_add_scheme_lane(
  NAME byte-machine.differential.pause.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-pause-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"
          "${CMAKE_SOURCE_DIR}/test/common/differential-pause-tests.sps"
  TIMEOUT 120)
```

  (plus its `.aot` twin, and the determinism pair with
  `ENVIRONMENT "BYTE_MACHINE_PAUSE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-pause.golden.sls"`
  on both). **The determinism.pause lanes do NOT mirror their one-byte
  neighbors' SOURCES**: the neighbors build their machine inline and carry no
  fixture library, but `determinism-pause-tests.sps` imports
  `(byte-machine test pause-machine)`, and an aot lane resolves libraries only
  through objects compiled from its own SOURCES (the source-guard blocks
  fallback) — so both determinism.pause lanes list
  `"${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/pause-machine.sls"`
  in SOURCES exactly as the differential block above does. Confirm the golden
  file is in **no** SOURCES manifest
  (`rg generated-pause.golden test/CMakeLists.txt` → the two ENVIRONMENT lines
  only).
- [ ] **Step 4: Red→green.** Land the two `.sps` programs (failing stubs are
  fine) and the golden **before** registering the lanes —
  `byte_machine_add_scheme_lane` FATAL_ERRORs at configure time on a missing
  PROGRAM or SOURCES entry, so registration-first yields a broken configure,
  not a red lane. Then register, drive red→green through the program content;
  both pairs green in source and aot. `make test` — expected 72/72
  (**measure**).
- [ ] **Step 5: Commit.**

```bash
git add test/common/differential-pause-tests.sps test/common/determinism-pause-tests.sps \
        test/fixtures/generated-pause.golden.sls test/CMakeLists.txt
git commit -m "test: pause differential + determinism golden lanes (M2 Slice 3 T5)"
```

---

### Task 6: Property generator learns eof/finish/pause

**Files:**
- Modify: `test/support/harness/byte-machine/test/machine-gen.sls`
- Modify: `test/common/property-differential-tests.sps`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 39; totals)

**Interfaces:**
- Consumes: `make-pause-node`/`make-finish-node` via graph; runtime pause
  lifecycle.
- Produces: `gen-machine` optionally emitting (a) an entry eof-target at a
  finish node `'done` (idle completion) and (b) a pause `'pausep` with
  continuation `'start` reachable as an extra case-target draw; a driver that
  resumes through pauses and finishes every machine.

- [ ] **Step 1: Read first.** `machine-gen.sls` in full (81 lines) — the draw
  helpers, the two validity constraints (first case pinned `(stop . advance)`;
  target-`start` forces `advance`), and the header's constraint log; and the
  driver program (`property-differential-tests.sps` — note `rfields` builds a
  FRESH parser per byte per side and feeds a single 1-byte slice; there is no
  multi-feed schedule to hook into). New draws follow the file's existing
  PRNG-threading style.
- [ ] **Step 2: Behavior-preserving driver extension.** Restructure the driver
  so both parsers stay live per byte: build the pair once per byte, feed the
  slice, and whenever either side reports `paused`, assert both do,
  `parser-resume!` both, compare acks, and re-feed from `next`; after the feed
  concludes, `parser-finish!` both sides and compare (a finish `paused` →
  resume both → finish again). Run the property lane — still green (no
  generator changes yet), confirming the extension is behavior-preserving on
  M1-shaped machines.
- [ ] **Step 3: Generator draws.** Two independent draws per machine:

```scheme
    ;; Slice ③ draws: an idle-completion eof route and an explicit pause.
    ;; done (finish) joins the graph only when drawn as the entry eof-target,
    ;; so it is never byte-reachable (§16.2:908 holds by construction).
    ;; pausep's continuation is 'start: the walk from a byte-reachable pause's
    ;; continuation (D4(d)) lands on the entry dispatch, whose eof route is a
    ;; finish, an error, or the machine default -- never a stop -- so §16.2:909
    ;; holds by construction (a continuation of 'stop would be rejected).
    ;; Every case targeting pausep is forced to advance (same rule as
    ;; target-'start), so no zero-width cycle can form through it.
```

  (a) eof draw: `eof-target` = `'done` (adding `(make-finish-node 'done #f)`)
  in half the draws, else `#f` as today. (b) pause draw: in half the draws,
  add `(make-pause-node 'pausep 'start #f)` and extend the case-target
  vocabulary with `'pausep` for the NON-pinned cases (the first-case
  reachability pin `(stop . advance)` stays exactly as it is — re-pinning it
  to pausep would strand the stop node and trip `unreachable-node`); any case
  drawing target `'pausep` forces mode `advance`, extending the existing
  target-`'start` rule. Thread both draws through the PRNG state discipline;
  update the header constraint log with the by-construction arguments above.
  Every generated machine must still verify: the lane run IS the check (the
  driver refuses unverified machines already).
- [ ] **Step 4: Green + Pass 39.** Property lanes green in both modes. Add one
  Pass 39 mutation: break the driver's resume handling (FIND the driver's
  resume line, REPLACE with a skip) — the lane must fail with the
  lifecycle-violation surfacing (measure the signature). If the pause draw's
  probability line is separately witnessable (e.g. REPLACE the draw with
  always-`#f` and an assertion in the driver counts ≥1 paused machine per
  seed set — add that count assertion if absent), add it; if measurement shows
  it unwitnessable under the fixed seeds, record the measured reason in the
  pass rather than shipping a decorative mutation. Totals + narrative; full
  mutation lane green.
- [ ] **Step 5: Commit.**

```bash
git add test/support/harness/byte-machine/test/machine-gen.sls \
        test/common/property-differential-tests.sps \
        test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: property generator emits eof/finish/pause machines (M2 Slice 3 T6)"
```

---

### Task 7: Close-out — fast-follow, records, M2 exit criteria

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (:1992)
- Modify: `docs/decisions/0013-runtime-coded-conditions.md` (dated note)
- Modify: `docs/plans/milestone-2-design.md` (dated §5/§6 amendments; Status)
- Modify: `CHANGELOG.md`
- Modify: `docs/plans/byte-machine-implementation-plan.md` only if it carries
  M1-close-style annotations to mirror (check first; do not invent a convention)

**Interfaces:** none produced; consumes the finished tree.

- [ ] **Step 1: Fast-follow (b).** The v1-op mutation's
  `EXPECT_OUTPUT_MATCHES "status"` (:1992) — run that single mutation, read the
  actual failure output, and pin the specific line. Predicted shape: the
  mutant makes the v1 group's cases RAISE (the suite's own comment :1987-1989
  records the mechanism), so the harness prints
  `FAIL <case-name>: case raised` — pin the case NAME + "case raised", not a
  check name (no check runs). Record before/after in the ledger.

> **Dispositioned 2026-08-29 (Task 7).** Not executed here. The work landed
> first on `fix/mutation-signature-vacuity-audit` (branched off `main` at
> `98d4a01`, single commit `67f59e7`), whose own broader pin-vacuity sweep
> reached this exact mutation before Task 7 did. The predicted shape above
> was confirmed correct — the mutant makes every `/v1` case RAISE inside
> `parser-feed-op!`'s `(op 'kind node)`, so the harness's own "case raised"
> failure is what the bare `"status"` pin was really catching (via the
> summary line's unconditional `status=1`, not any FAIL line) — and that
> branch's measured replacement is
> `"an empty slice needs input: case raised"`: the case name of the raising
> `/v1` fixture, with the colon disambiguating it from the one-byte group's
> differently-worded case ("an empty slice needs input **and reports no
> result yet**"), which would otherwise also match. That branch is not
> merged into this one, so this tree still carries the original bare
> `"status"` pin, on the mutation LABELed "runtime: a v1 machine is driven
> down the op path" (`main`'s `:1992`; line numbers in this tree shift as
> Slice ③ grows the file, so cite by LABEL, not line) — plus two siblings the
> same audit also fixed: LABEL "runtime: the v1 result status is hard-wired
> to stopped" (`main`'s `:2006`) and LABEL "runtime: a feed on a finished
> parser does not return finished" (`main`'s `:2097`). All three are that
> branch's scope, not this slice's; editing them here would conflict with
> work already done there.
>
> Coordination note for that branch, left by this slice's own pin re-audit
> (`.superpowers/sdd/pin-audit-report.md` §6, not committed): Slice ③'s new
> mutants **widened** some of the same six lanes' pre-existing collision
> sets it left untouched (e.g. Pass 32's bare `"finished"` pin now also
> matches the EOF-pause mutant's failure text) — `fix/mutation-signature-
> vacuity-audit` should re-measure its own pins after this slice merges,
> not assume they are still sound against the merged tree.

- [ ] **Step 2: 0013 dated note.** Follow 0013's own amendment convention — a
  dated second-level section (its ②a note is
  `## 2026-08-28 (Slice ②a) — as-implemented manifest de-dup`), NOT a
  blockquote: add `## <date> (Slice ③) — misuse codes as shipped` recording:
  the family shipped as the single code `'lifecycle-violation` (who = the
  refused operation, detail = `(list <state> <op>)`) — parent §9.4:438 names
  "lifecycle violation" as the code; the prohibited-cell inventory is §12.2's,
  enforced for the reachable rows (poisoned/busy ride to M5).
- [ ] **Step 3: Design-doc amendments.** In `milestone-2-design.md`: a dated
  note at §5's sticky-cache paragraph recording D1 (short-circuit + stored
  error; driver: the ②b-2 default-EOF carry) and at §6 recording D6
  (paused-finish results mirror finished; accessor enforcement deferred with
  the structured-error family). Update the header Status line (:3) to record
  Slice ③ delivered / M2 complete once Step 5's gates pass.
- [ ] **Step 4: CHANGELOG.** Added-section entry: pause node + `parser-resume!`
  + full reachable operation matrix + `'lifecycle-violation` + the three lane
  pairs + the pause goldens (cite measured fingerprint), and the sticky-row
  mechanism change under Changed (it alters no asserted tuple, but the
  default-EOF repeat-feed behavior it fixes IS observable — say so).
- [ ] **Step 5: Exit criteria + clean re-measure.** `make clean && make build`;
  `make test-all` (release), pr preset, no-scheme preset, mutation lane, cmake
  mutation lane. Record all totals (predicted release 72, no-scheme 8, scheme
  mutation 38 passes/~145-146, cmake 1/72 — **write only measured numbers**).
  Verify design §6's full-M2 exit list against the tree (each Slice ①/②
  criterion re-run via the existing lanes; Slice ③'s via the new ones) and
  §25's four criteria; confirm the two untouched goldens one last time.
- [ ] **Step 6: Commit.**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake CHANGELOG.md \
        docs/decisions/0013-runtime-coded-conditions.md \
        docs/plans/milestone-2-design.md
git commit -m "docs: M2 Slice 3 close-out -- records, changelog, regex tighten (T7)"
```

  Then: final whole-branch review (opus), fix wave, PR — the closing ritual is
  the controller's, gated on the user's go-ahead.

---

## Verification summary (what proves what)

| Obligation (source) | Witness |
|---|---|
| pause returns `paused` + continuation + first unconsumed index (§10.6:608) | T2 stubs, T3 interpreter, T4 exec, T5 differential |
| resume semantics + acks (§12.1:673-685) | T2 matrix group; T3/T5 walks |
| full reachable matrix, coded cells (§12.2, §12.6, 0013) | T2 matrix group + Pass 32 mutations |
| sticky rows tuple + stored error (§12.2:701) | T2 (incl. default-EOF carry case) |
| EOF pause → paused-finish → finish continues (§12.4:729) | T3, T5 |
| finite pauses / no stop on EOF paths (§16.2:908-909) | T1 fixtures + Pass 33 |
| zero-progress incl. pause (§16.2:898, design §6) | T1 |
| malformed continuations (§16.2:905) | T1 (missing-target) |
| encode/render determinism + goldens (§22.9, 0009) | T4 fingerprint golden, T5 determinism lanes |
| differential incl. pause continuations (§22.4) | T5 |
| property pauses (§22.6:1295) | T6 |
| reserved mirrors same-commit (0012 item 4) | T2 (member-2) — member-3 unchanged (D5) |
| existing goldens unmoved | T4 Step 5, T7 Step 5 |
