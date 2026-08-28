# Milestone 2 Slice ②a — Lifecycle Spine (feed-only) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the runtime an explicit parser lifecycle-state field with `parser-lifecycle`/`parser-reset!`, fix the latent M1 sticky-repeat feed bug by removing the stale result cache, and route the §11.1 invalid-slice contract through a coded `&byte-machine-contract` condition (decision 0013) — all feed-only, no EOF/finish/pause.

**Architecture:** Modifies only `(byte-machine runtime)` (`src/byte-machine/runtime.sls`) plus its test and mutation lanes and the CMake manifest. The parser vector gains an `entry` slot (for reset) and a `lifecycle` symbol slot (`ready`/`stopped`/`error`) **replacing the `sticky` result cache**. Per the design's Slice-②a refinement (`milestone-2-design.md` §5), `parser-feed!` no longer returns a cached result: it always runs the executor, and re-executing at a terminal is idempotent — the `stop`/`error` arms return exactly the §12.2 sticky-repeat tuple (`next = start`, `consumed = 0`, stored offset) by construction. A true stored-result short-circuit is deferred to M5 (callbacks). No finish node, no `parser-finish!`, no `/v2` — those are Slice ②b.

**Tech Stack:** Chez Scheme 10.4.1 (R6RS `.sls`), CMake ≥3.26 + presets, the in-tree test harness and Scheme mutation suite.

## Global Constraints

- Chez floor **10.4.1**; CMake floor **3.26**. **No new dependencies.**
- No Scheme file may `include` another (decision 0006); within a lane's `SOURCES`, basenames must be unique.
- `no-scheme` stays **8/8** (this slice registers no `cmake.direct` lane).
- Every decision gets a mutation asserting a measured failure **signature** (`EXPECT_STATUS` / `EXPECT_OUTPUT_MATCHES`), never a bare nonzero exit; a mutation that becomes unwitnessable is **deleted with justification**, not left to survive. Update `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` and their arithmetic in the **same commit** as the mutations; re-run the whole mutation suite after any change. Re-measure `release`/`pr` before writing any count into a record.
- Governing design: `docs/plans/milestone-2-design.md` §3.3, §5, and the runtime row of its Appendix; decisions **0011/0012/0013**. Decision **0013** authorizes the runtime→conditions dependency and the `CORE_ALL` manifest de-dup.
- Conventional Commits. Run `make test` before every commit.

---

## Task 1: Runtime coded conditions + the `CORE_ALL` manifest de-dup (decision 0013)

**Files:**
- Modify: `src/byte-machine/runtime.sls` (import `conditions`; the invalid-slice guard)
- Modify: `test/CMakeLists.txt` (`BYTE_MACHINE_CORE_RUNTIME`; de-dup `BYTE_MACHINE_CORE_ALL`)
- Modify: `test/common/runtime-tests.sps` (import `conditions`; add the invalid-slice test)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (add the invalid-slice mutation; bump counts)

**Interfaces:**
- Produces: `(byte-machine runtime)` raises `&byte-machine-contract` (code `invalid-slice`, who `parser-feed!`) on a bad slice, via `(byte-machine private conditions)`. Tasks 2–3 inherit the `conditions` import and the manifest shape.

- [ ] **Step 1: Add the invalid-slice test (RED)**

In `test/common/runtime-tests.sps`, add `(byte-machine private conditions)` to the `import` list:

```scheme
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private conditions)
        (byte-machine runtime))
```

Then add this `harness-group` just before `(harness-finish)`:

```scheme
(harness-group "invalid feed slices"
  (lambda ()
    (harness-case "a slice past the bytevector end raises a coded contract condition"
      (lambda ()
        (check-raises "invalid slice"
          (lambda (e)
            (and (byte-machine-contract-condition? e)
                 (eq? (byte-machine-contract-condition-code e) 'invalid-slice)
                 (eq? (byte-machine-contract-condition-who e) 'parser-feed!)))
          (lambda ()
            (parser-feed! (make-parser (make-compiled-machine one-byte-op) '() #f)
                          (make-bytevector 1 0) 0 5)))))))
```

- [ ] **Step 2: Run it — expect RED (import/condition failure)**

Run:
```bash
make build 2>&1 | rg -i 'error|exception' | head
```
Expected: the runtime lane fails to build — `runtime-tests.sps` imports `(byte-machine private conditions)` but that library is not in the runtime lane's `SOURCES` yet (unbound library / missing source), and `runtime.sls` still raises `assertion-violation` (not the coded condition). This is the RED. (If it builds, the test fails because the current guard raises `assertion-violation`, so `byte-machine-contract-condition?` is false.)

- [ ] **Step 3: Add `conditions` to the runtime manifest and de-dup `CORE_ALL`**

In `test/CMakeLists.txt`, change `BYTE_MACHINE_CORE_RUNTIME` (currently a single-library manifest, ~line 744) to prepend `conditions.sls`, and update its comment:

```cmake
# The runtime now depends on (byte-machine private conditions) for coded API
# contract conditions (decision 0013); conditions.sls imports only (rnrs), so no
# cycle. It is listed first so the AOT lane compiles it before runtime.sls.
set(BYTE_MACHINE_CORE_RUNTIME
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/conditions.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls")
```

Then, immediately after the `set(BYTE_MACHINE_CORE_ALL ...)` block (~line 793, which unites `CORE_VERIFY` + `CORE_RUNTIME` + `interpret.sls`), add a de-dup so `conditions.sls` — now present in both `CORE_VERIFY` (via `CORE_IR`) and `CORE_RUNTIME` — does not collide as a duplicate basename inside `CORE_ALL` (and, transitively, `CORE_EMIT`):

```cmake
# conditions.sls now reaches CORE_ALL twice — once via CORE_VERIFY's ir manifest,
# once via CORE_RUNTIME (decision 0013). REMOVE_DUPLICATES keeps the first (early,
# before ir.sls) occurrence, so load/compile order stays conditions -> ir -> ... ->
# runtime -> interpret, and the per-lane duplicate-basename guard stays green.
list(REMOVE_DUPLICATES BYTE_MACHINE_CORE_ALL)
```

- [ ] **Step 4: Switch the invalid-slice guard to a coded condition**

In `src/byte-machine/runtime.sls`, add the import and change the guard.

Import (currently `(import (rnrs))`):
```scheme
  (import (rnrs)
          (byte-machine private conditions))
```

The `parser-feed!` invalid-slice guard (currently raises `assertion-violation`):
```scheme
  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    (or (parser-sticky parser)
        (if (eq? (parser-variant parser) 'op)
            (parser-feed-op! parser bv start end)
            (parser-feed-v1! parser bv start end))))
```
(Only the guard's raise changes in this task; the `(or (parser-sticky parser) …)` body is replaced in Task 2.)

- [ ] **Step 5: Run — expect GREEN**

Run:
```bash
make build
ctest --preset pr -R 'byte-machine\.unit\.runtime' --output-on-failure
```
Expected: both runtime lanes PASS, including the new invalid-slice case.

- [ ] **Step 6: Add the invalid-slice mutation and bump the counts**

In `test/support/cmake/SchemeMutationSuite.cmake`, inside Pass 32 (the runtime pass), just before its `byte_machine_mutation_run(...)` call (~line 1914), add:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an invalid feed slice is accepted instead of raising"
  FIND [[(unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid slice")
```

Update the totals (`~line 231`): `EXPECTED_MUTATIONS` `104` → `105` (Pass 32 gains one mutation; `EXPECTED_PASSES` stays `37`). Update Pass 32's mutation-count comment/narrative accordingly (search the header narrative near line 165 for the Pass 32 count and the running arithmetic; adjust `+1`).

- [ ] **Step 7: Run the mutation suite, then commit**

Run:
```bash
ctest --preset release -R 'scheme-mutation' --output-on-failure
```
Expected: PASS at 38? — no: the suite reports `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`; confirm it prints the new mutation caught and the totals line matches (`37 passes / 105 mutations`).

```bash
git add src/byte-machine/runtime.sls test/CMakeLists.txt test/common/runtime-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: runtime raises a coded invalid-slice contract condition; CORE_ALL de-dup (decision 0013)"
```

---

## Task 2: The lifecycle field + `parser-lifecycle`, replacing the sticky cache (C2 fix)

**Files:**
- Modify: `src/byte-machine/runtime.sls` (parser vector, accessors, `make-parser`, `parser-feed!`, `parser-feed-op!`, `parser-feed-v1!`; export `parser-lifecycle`)
- Modify: `test/common/runtime-tests.sps` (overturn the sticky test; add a lifecycle test)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (delete the obsolete sticky mutation; add a lifecycle mutation; adjust counts)

**Interfaces:**
- Consumes: the `conditions` import (Task 1).
- Produces: `(parser-lifecycle p)` → `ready | stopped | error`; the parser vector is `(vector parser-tag variant executor entry current offset lifecycle)`. `parser-reset!` (Task 3) uses `parser-entry`/`parser-set-lifecycle!`.

- [ ] **Step 1: Overturn the sticky test + add the lifecycle test (RED)**

In `test/common/runtime-tests.sps`, **replace** the `harness-case "a terminal result is sticky across a second feed"` (currently asserting `r2.next == r1.next` and `r2.consumed == r1.consumed`) with the §12.2-correct assertions, and add a lifecycle case in the same group:

```scheme
    (harness-case "a repeat feed on a terminal parser reports a fresh empty result (§12.2)"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (r1 (parser-feed! p (make-bytevector 1 0) 0 1))
               (r2 (parser-feed! p (make-bytevector 1 0) 0 1)))
          (check-equal "first stopped" (parser-result-status r1) 'stopped)
          (check-equal "second still stopped" (parser-result-status r2) 'stopped)
          (check-equal "second next is the new slice start" (parser-result-next r2) 0)
          (check-equal "second consumed is zero" (parser-result-consumed r2) 0)
          (check-equal "second stream offset unchanged"
                       (parser-result-stream-offset r2) (parser-result-stream-offset r1)))))
    (harness-case "parser-lifecycle tracks ready -> terminal"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
          (check-equal "starts ready" (parser-lifecycle p) 'ready)
          (parser-feed! p (make-bytevector 1 0) 0 1)
          (check-equal "stopped after accept" (parser-lifecycle p) 'stopped)
          (let ((q (make-parser (v1-machine) '() #f)))
            (parser-feed! q (make-bytevector 1 65) 0 1)
            (check-equal "error after reject" (parser-lifecycle q) 'error)))))
```

- [ ] **Step 2: Run — expect RED**

Run: `make build && ctest --preset pr -R 'byte-machine\.unit\.runtime' --output-on-failure`
Expected: RED — the overturned test fails because the current `parser-feed!` returns the cached `r1` (so `r2.next` is `1`, not `0`), and `parser-lifecycle` is unbound.

- [ ] **Step 3: Refactor the parser for the lifecycle field (GREEN)**

In `src/byte-machine/runtime.sls`: add `parser-lifecycle` to the export list; replace the parser section (vector layout comment, `make-parser`, accessors, `parser-feed!`, `parser-feed-op!`, `parser-feed-v1!`) with:

```scheme
  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor entry current offset lifecycle)
  ;; lifecycle: ready | stopped | error   (finished/paused/finish-ready arrive in
  ;; Slice ②b/③). There is no cached "sticky" result: a repeat feed on a terminal
  ;; parser re-runs the executor, which is idempotent for stop/error (and, in ②b,
  ;; finish) and returns the §12.2 sticky-repeat tuple by construction. A stored-
  ;; result short-circuit returns at M5, when callbacks make re-execution
  ;; non-idempotent (design milestone-2-design.md §5).
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (if (eq? (compiled-machine-variant compiled-machine) 'op)
        (let* ((op (vector-ref compiled-machine 2)) (entry (op 'entry)))
          (vector parser-tag 'op op entry entry 0 'ready))
        (let ((feed (compiled-machine-v1-feed compiled-machine))
              (entry-state (compiled-machine-v1-entry-state compiled-machine)))
          (vector parser-tag 'v1 feed entry-state entry-state 0 'ready))))
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-variant p) (vector-ref p 1))
  (define (parser-executor p) (vector-ref p 2))
  (define (parser-entry p) (vector-ref p 3))
  (define (parser-current p) (vector-ref p 4))
  (define (parser-set-current! p v) (vector-set! p 4 v))
  (define (parser-offset p) (vector-ref p 5))
  (define (parser-set-offset! p v) (vector-set! p 5 v))
  (define (parser-lifecycle p) (vector-ref p 6))
  (define (parser-set-lifecycle! p v) (vector-set! p 6 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    (let ((r (if (eq? (parser-variant parser) 'op)
                 (parser-feed-op! parser bv start end)
                 (parser-feed-v1! parser bv start end))))
      (case (parser-result-status r)
        ((stopped) (parser-set-lifecycle! parser 'stopped))
        ((error) (parser-set-lifecycle! parser 'error)))
      r))

  ;; The interpreter path. stop/error return a fresh result each call — no cache —
  ;; so a repeat feed on a terminal parser re-runs here and returns (status, next=
  ;; start, consumed=0, stored offset) by construction (§12.2).
  (define (parser-feed-op! parser bv start end)
    (let ((op (parser-executor parser)))
      (let loop ((pos start))
        (let ((node (parser-current parser)))
          (case (op 'kind node)
            ((stop)
             (make-parser-result 'stopped pos (- pos start) (parser-offset parser) #f))
            ((error)
             (make-parser-result 'error pos (- pos start) (parser-offset parser)
                                 (op 'error-value node)))
            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start) (parser-offset parser) #f)
                 (let* ((byte (bytevector-u8-ref bv pos))
                        (trans (op 'dispatch node byte))
                        (target (car trans))
                        (mode (cdr trans)))
                   (parser-set-current! parser target)
                   (if (eq? mode 'advance)
                       (begin
                         (parser-set-offset! parser (+ 1 (parser-offset parser)))
                         (loop (+ pos 1)))
                       (loop pos)))))
            (else (assertion-violation 'parser-feed! "unknown node kind" (op 'kind node))))))))

  ;; The generated path: the feed owns the dispatch loop and returns one outcome;
  ;; the runtime commits resume state and builds the result. No cache (see above).
  (define (parser-feed-v1! parser bv start end)
    (let* ((feed (parser-executor parser))
           (o (feed (parser-current parser) (parser-offset parser) bv start end))
           (status (feed-outcome-status o))
           (next (feed-outcome-next o)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (make-parser-result status next (- next start)
                          (feed-outcome-offset o) (feed-outcome-error o)))))
```

Note the removed `parser-sticky`/`parser-set-sticky!` accessors and the removed `(parser-set-sticky! parser r)` calls; delete their old definitions.

- [ ] **Step 4: Run — expect GREEN**

Run: `make build && ctest --preset pr -R 'byte-machine\.unit\.runtime' --output-on-failure`
Expected: the overturned repeat-feed test and the lifecycle test PASS. Then run the emitter/differential lanes that build parsers, to confirm nothing else read `parser-sticky`:
```bash
ctest --preset pr -R 'differential|example' --output-on-failure
```
Expected: PASS (only `runtime.sls` referenced the sticky accessors).

- [ ] **Step 5: Delete the obsolete sticky mutation, add the lifecycle mutation, adjust counts**

In `SchemeMutationSuite.cmake`, **delete** the mutation whose `FIND` is `(if (or (eq? status 'stopped) (eq? status 'error)) (parser-set-sticky! parser r))` (LABEL "runtime: a v1 terminal result is not made sticky", ~line 1907-1912) — its anchor no longer exists and idempotent re-execution now provides its behavior. Add a comment in its place:

```cmake
# (removed 2026-08-28, Slice ②a) "a v1 terminal result is not made sticky": the
# sticky cache was deleted; a repeat feed re-runs the executor, which is idempotent
# for stop/error, so setting-vs-not-setting a cache is now unobservable in M2's
# callback-free world. Its intent is re-witnessed by the reset mutations (Task 3),
# which distinguish current/offset/lifecycle restoration. See design §5.
```

Add the lifecycle mutation before the pass's `byte_machine_mutation_run`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an accepting feed does not record the stopped lifecycle"
  FIND [[((stopped) (parser-set-lifecycle! parser 'stopped))]]
  REPLACE [[((stopped) (parser-set-lifecycle! parser 'ready))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "stopped after accept")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a rejecting feed does not record the error lifecycle"
  FIND [[((error) (parser-set-lifecycle! parser 'error))]]
  REPLACE [[((error) (parser-set-lifecycle! parser 'ready))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "error after reject")
```

Counts: Pass 32 loses one mutation (sticky) and gains two (the `stopped` and `error` lifecycle arms are two decisions) → net **+1**. `EXPECTED_MUTATIONS` `105` → `106`; `EXPECTED_PASSES` stays `37`. Adjust the Pass 32 narrative (`-1 sticky, +2 lifecycle`).

- [ ] **Step 6: Run the mutation suite; commit**

Run: `ctest --preset release -R 'scheme-mutation' --output-on-failure`
Expected: PASS; totals `37 / 106`.

```bash
git add src/byte-machine/runtime.sls test/common/runtime-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: explicit parser lifecycle field + parser-lifecycle; remove the sticky cache (C2 fix, §12.2)"
```

---

## Task 3: `parser-reset!`

**Files:**
- Modify: `src/byte-machine/runtime.sls` (add `parser-reset!`; export it)
- Modify: `test/common/runtime-tests.sps` (reset tests)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (three reset mutations; bump counts)

**Interfaces:**
- Consumes: `parser-entry`, `parser-set-current!`, `parser-set-offset!`, `parser-set-lifecycle!` (Task 2).
- Produces: `(parser-reset! p)` restores entry state, offset 0, lifecycle `ready`.

- [ ] **Step 1: Add reset tests (RED)**

In `test/common/runtime-tests.sps`, add a `harness-group` before `(harness-finish)`:

```scheme
(harness-group "parser-reset!"
  (lambda ()
    ;; Witness current-restoration via a status CHANGE: reach the error terminal,
    ;; reset, then feed byte 0. From the entry state byte 0 is ACCEPTED (stopped);
    ;; if reset failed to restore `current`, the parser would still be at the error
    ;; node and the result would stay 'error. (For an accept-then-accept sequence,
    ;; both entry and the stop terminal yield 'stopped, so only the offset would
    ;; differ — which would witness the wrong decision. Hence error-then-accept.)
    (harness-case "reset returns to ready and re-parses from the entry state"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
          (parser-feed! p (make-bytevector 1 65) 0 1)         ; -> error, parked at the error node
          (check-equal "error before reset" (parser-lifecycle p) 'error)
          (parser-reset! p)
          (check-equal "ready after reset" (parser-lifecycle p) 'ready)
          (check-equal "re-parses from entry"
                       (parser-result-status (parser-feed! p (make-bytevector 1 0) 0 1))
                       'stopped))))
    (harness-case "reset zeroes the stream offset"
      (lambda ()
        (let ((p (make-parser (v1-machine) '() #f)))
          (parser-feed! p (make-bytevector 1 0) 0 1)          ; advance -> offset 1, stopped
          (parser-reset! p)
          (check-equal "offset zeroed then advanced by one"
                       (parser-result-stream-offset (parser-feed! p (make-bytevector 1 0) 0 1))
                       1))))))
```

- [ ] **Step 2: Run — expect RED** (`parser-reset!` unbound)

Run: `make build 2>&1 | rg -i 'error|exception|reset' | head`
Expected: RED — `parser-reset!` is not defined/exported.

- [ ] **Step 3: Implement `parser-reset!` (GREEN)**

In `src/byte-machine/runtime.sls`: add `parser-reset!` to the export list, and define it after `parser-feed-v1!`:

```scheme
  ;; Full reset (§12.5), M2 subset: entry state, offset 0, lifecycle ready. Field,
  ;; span, pause, finish, poison, and stored-error state do not exist yet (Slice
  ;; ②b / M4 / M5). Returns unspecified.
  (define (parser-reset! parser)
    (parser-set-current! parser (parser-entry parser))
    (parser-set-offset! parser 0)
    (parser-set-lifecycle! parser 'ready))
```

- [ ] **Step 4: Run — expect GREEN**

Run: `make build && ctest --preset pr -R 'byte-machine\.unit\.runtime' --output-on-failure`
Expected: reset tests PASS.

- [ ] **Step 5: Add the three reset mutations; bump counts**

In `SchemeMutationSuite.cmake`, before Pass 32's `byte_machine_mutation_run`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not restore the entry state"
  FIND [[(parser-set-current! parser (parser-entry parser))]]
  REPLACE [[(parser-set-current! parser (parser-current parser))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "re-parses from entry")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not zero the stream offset"
  FIND [[(parser-set-offset! parser 0)]]
  REPLACE [[(parser-set-offset! parser (parser-offset parser))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "offset zeroed then advanced by one")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: reset does not return the lifecycle to ready"
  FIND [[(parser-set-lifecycle! parser 'ready)]]
  REPLACE [[(parser-set-lifecycle! parser 'stopped)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ready after reset")
```

Counts: `EXPECTED_MUTATIONS` `106` → `109` (three added); `EXPECTED_PASSES` stays `37`. Update the Pass 32 narrative (`+3`).

- [ ] **Step 6: Run the mutation suite; commit**

Run: `ctest --preset release -R 'scheme-mutation' --output-on-failure`
Expected: PASS; totals `37 / 109`.

```bash
git add src/byte-machine/runtime.sls test/common/runtime-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: parser-reset! (entry + offset + lifecycle), §12.5 M2 subset"
```

---

## Task 4: Whole-suite verification and re-measure

**Files:** none (verification only).

- [ ] **Step 1: Full clean rebuild + all presets**

Run:
```bash
make clean && make test-all
cmake --preset no-scheme >/dev/null && cmake --build --preset no-scheme >/dev/null && ctest --preset no-scheme
ctest --preset release -R 'scheme-mutation' --output-on-failure | rg 'passes|mutations|PASS|FAIL'
```
Expected: `release` all green; `no-scheme` **8/8**; the Scheme mutation suite reports `37 passes / 109 mutations`, all caught. Record the measured `release`/`pr` lane counts (unchanged from Slice ①'s 62 — this slice adds no lane) and the mutation totals for the CHANGELOG/close-out; do not guess them.

- [ ] **Step 2: Confirm scope isolation**

Run:
```bash
rg -n 'parser-sticky|parser-finish!|finish-node|/v2|finished' src/byte-machine/runtime.sls || echo "clean: no sticky accessors, no ②b constructs"
git diff --stat main...HEAD
```
Expected: no `parser-sticky` references remain; no `parser-finish!`/finish/`/v2` (those are Slice ②b). The diff touches only `src/byte-machine/runtime.sls`, `test/common/runtime-tests.sps`, `test/CMakeLists.txt`, and `test/support/cmake/SchemeMutationSuite.cmake`.

- [ ] **Step 3: Commit any record/CHANGELOG note if the project convention requires one for this slice** (a runtime API addition — `parser-lifecycle`/`parser-reset!` — is public surface; add a CHANGELOG.md "Added" line if the repo keeps one at this granularity, else skip). Commit if changed.

---

## Self-Review

1. **Spec coverage (design §5, Slice-②a scope):** lifecycle field + `parser-lifecycle` → Task 2. Remove-the-stale-cache C2 fix (idempotent re-execution) + overturn `runtime-tests.sps:95-102` → Task 2. `parser-reset!` (§12.5 subset) → Task 3. Coded conditions + `CORE_ALL` de-dup (decision 0013) + invalid-slice → Task 1. **Out of scope, correctly absent:** finish node, `parser-finish!`, `finished`, `/v2`, eof encoding, fingerprint move, position-kind — all Slice ②b; `poisoned`/`busy` — M5.
2. **Placeholder scan:** every step shows the exact code, the exact `FIND`/`REPLACE`, and exact `make`/`ctest` commands with expected RED/GREEN. No "TBD".
3. **Type/name consistency:** the parser vector layout `(tag variant executor entry current offset lifecycle)` and its accessors are defined once in Task 2 and used by `parser-reset!` in Task 3; `parser-lifecycle`/`parser-reset!` are added to the export list in the task that defines them; `byte-machine-contract-violation`/`byte-machine-contract-condition?`/`-code`/`-who` match `src/byte-machine/private/conditions.sls`. Mutation `FIND` strings are copied verbatim from the Task-2/3 code.
4. **Mutation discipline:** the obsolete sticky mutation is **deleted with a written justification** (Task 2 Step 5), not left to survive; three reset mutations + one lifecycle + one invalid-slice replace it; `EXPECTED_MUTATIONS` goes 104 → 105 (Task 1) → 106 (Task 2, net +1) → 109 (Task 3), updated in the same commit as each change; the whole suite is re-run each task and finally in Task 4.
