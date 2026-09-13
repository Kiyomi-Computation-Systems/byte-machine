# Milestone 2 Slice ②b-2 — EOF Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate the EOF path: teach the normalizer to encode the finish node and eof routing (moving the IR fingerprint), the emitter to render a unified `exec` closure with a `finish?` branch under the **`/v2`** ABI, the runtime to drive it, and prove the generated EOF execution equals the interpreter's across the machine.

**Architecture:** Completes Slice ②b (②b-1 proved EOF through the interpreter; this generates it). Decision **0012**: the generated ABI grows a finish path under `/v2` — one unified `exec` closure carrying a `finish?` flag, emitted via `byte-machine-make-compiled-machine/v2`; the emitter emits `/v2` while the runtime **keeps the `/v1` export** (a stale v1 file fails the version check cleanly). The normalizer now hashes eof routing, so the Milestone 1 one-byte golden fingerprint **moves and is re-baselined exactly once** (the `/v2` machinery lands *dormant* first, then the normalizer + emitter + abi bump flip together so no golden is re-baselined twice). `position-kind` is **deferred** out of M2 (design §7 scope-check).

**Tech Stack:** Chez Scheme 10.4.1 (R6RS `.sls`), CMake ≥3.26 + presets, the in-tree harness and Scheme mutation suite.

## Global Constraints

- Chez floor **10.4.1**; CMake floor **3.26**. **No new dependencies.** No `include` (decision 0006); unique basenames per lane; `no-scheme` stays **8/8**.
- **`/v2` per decision 0012:** `byte-machine-make-compiled-machine/v2 abi ir-fingerprint entry-state exec`; the emitter emits `/v2`; the runtime **keeps** the `/v1` export (now a version-mismatch stub). The `feed-outcome` record is **reused** (`byte-machine-make-feed-outcome/v1` stays — `finished` is a new status *symbol*, not a new record). `current-abi-version` → 2.
- **Golden re-baseline is measured, once.** The one-byte IR fingerprint `11963406767470843108` moves when eof routing is hashed; re-baseline **every** site to the **measured** new value in the single task that flips generation (Task 2): `normal-ir-tests.sps:63`, `compile-tests.sps` (`:77` inside the emitted-call `has?` fragment and `:110` `check-equal`), `test/fixtures/generated-one-byte.golden.sls:18`, **and the three Pass-35 FNV `EXPECT_OUTPUT_MATCHES "11963406767470843108"` anchors in `test/support/cmake/SchemeMutationSuite.cmake` (~`:2251/:2258/:2265`)** — those anchors are the golden fingerprint the failing `normal-ir-tests.sps` prints, so a stale anchor makes the FNV mutations report `wrong-reason` and fails the whole scheme-mutation suite. Comparison is by the IR fingerprint through the project writer (§20). (`CHANGELOG.md:462` holds the value as a historical M1 record — do **not** change it.)
- **Reserved-member mirrors (0012):** `reserved-member-2` (`compile.sls`) gains `byte-machine-make-compiled-machine/v2` and **keeps** `/v1` + `byte-machine-make-feed-outcome/v1`; `reserved-member-3` renames `feed`→`exec` and adds `finish?`. Every new `(byte-machine runtime)` export is mirrored in `reserved-member-2` or the drift guard fails.
- **§9.5:444 requires a CHANGELOG.md entry** for the pre-1.0 ABI change (Task 4).
- Every decision gets a comparison-caught mutation asserting a measured signature; **a mutation's witnessing test must live in that mutation's SPEC-lane program** (the runtime SPEC lane, `byte-machine.unit.runtime.chez.source`, drives `runtime.sls` via op stubs, not the interpreter — Task 4 adds this to AGENTS.md); update `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` + arithmetic in the same commit; re-run the whole suite. Re-measure `release`/`pr` before any count. Baseline entering ②b-2: `release`/`pr` **64/64**, mutations **37 passes / 116 mutations**, `no-scheme` **8/8**.
- Governing design: `.plans/milestone-2-design.md` §5 + the ②b-1/②b-2 sub-split note; decisions **0011/0012**; §9.5/§20/§22.4/§22.9 in the parent plan. `position-kind` is deferred (design §7). Conventional Commits; run `make test` before every commit.

---

## Task 1: `/v2` runtime machinery (dormant — emitter still emits `/v1`)

**Files:**
- Modify: `src/byte-machine/runtime.sls` (add `/v2` constructor + `exec`-based drivers; export `/v2`)
- Modify: `src/byte-machine/compile.sls` (`reserved-member-2` += `/v2`)
- Modify: `test/common/runtime-tests.sps` (stub-based `/v2` feed + finish tests)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 32 mutations; counts)

**Interfaces:**
- Produces: `byte-machine-make-compiled-machine/v2 abi ir-fp entry-state exec` (variant `'v2`, stores `exec`); `exec` signature `(state offset bv start end finish?) -> feed-outcome`; `parser-feed!`/`parser-finish!` drive a `'v2` machine via `exec` with `finish?` `#f`/`#t`. Task 2's emitter emits this constructor. **Kept green:** `current-abi-version` stays `1` so the still-`/v1` emitter output remains valid; `/v2` checks the literal `2`.

- [ ] **Step 1: Write the stub-based `/v2` tests (RED)**

In `test/common/runtime-tests.sps`, add a group after the `/v1` group. The `/v2` stub encodes the one-byte machine as a `finish?`-aware `exec` (state 0 dispatch; state 0's eof routes to a `default-eof` error `eof`; state 1 stop; state 2 error):

```scheme
(define (stub-exec state offset bv start end finish?)
  (let loop ((pos start) (st state) (off offset))
    (case st
      ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 'error pos 'unexpected-byte 2 off))
      (else
       (if (>= pos end)
           (if finish?
               (byte-machine-make-feed-outcome/v1 'error pos 'eof 0 off)   ; eof-target #f -> default
               (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off))
           (let ((b (bytevector-u8-ref bv pos)))
             (if (= b 0) (loop (+ pos 1) 1 (+ off 1)) (loop pos 2 off))))))))
(define (v2-machine) (byte-machine-make-compiled-machine/v2 2 99 0 stub-exec))

(harness-group "generated-code ABI (/v2): feed and finish"
  (lambda ()
    (harness-case "a fed accepted byte stops"
      (lambda ()
        (let ((r (parser-feed! (make-parser (v2-machine) '() #f) (make-bytevector 1 0) 0 1)))
          (check-equal "stopped" (parser-result-status r) 'stopped))))
    (harness-case "finish with no input routes to the default-eof error"
      (lambda ()
        (let ((r (parser-finish! (make-parser (v2-machine) '() #f))))
          (check-equal "error" (parser-result-status r) 'error)
          (check-equal "default-eof code" (parser-result-error r) 'eof))))
    (harness-case "a mismatched /v2 ABI version is refused"
      (lambda ()
        (check-raises "refused" (lambda (e) #t)
                      (lambda () (byte-machine-make-compiled-machine/v2 1 99 0 stub-exec)))))))
```

- [ ] **Step 2: Run — expect RED** (`/v2` unbound)

Run: `make build 2>&1 | rg -i 'error|exception|unbound|/v2' | head`
Expected: RED.

- [ ] **Step 3: Add the `/v2` constructor + drivers**

In `src/byte-machine/runtime.sls`: add `byte-machine-make-compiled-machine/v2` to the export list. Keep `current-abi-version` at `1`. Add, next to the `/v1` constructor:

```scheme
  (define (byte-machine-make-compiled-machine/v2 abi-version ir-fingerprint entry-state exec)
    (unless (and (integer? abi-version) (= abi-version 2))
      (assertion-violation 'byte-machine-make-compiled-machine/v2
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? exec)
      (assertion-violation 'byte-machine-make-compiled-machine/v2 "exec must be a procedure" exec))
    (vector compiled-machine-tag 'v2 exec entry-state ir-fingerprint))
  (define (compiled-machine-v2-exec cm) (vector-ref cm 2))
  (define (compiled-machine-v2-entry-state cm) (vector-ref cm 3))
  (define empty-bv (make-bytevector 0))
```

Extend `make-parser` to build a `'v2` parser (the vector layout `(tag variant executor entry current offset lifecycle)` is unchanged; `executor` holds `exec`):

```scheme
    (cond
      ((eq? (compiled-machine-variant compiled-machine) 'op)
       (let* ((op (vector-ref compiled-machine 2)) (entry (op 'entry)))
         (vector parser-tag 'op op entry entry 0 'ready)))
      ((eq? (compiled-machine-variant compiled-machine) 'v2)
       (let ((exec (compiled-machine-v2-exec compiled-machine))
             (entry-state (compiled-machine-v2-entry-state compiled-machine)))
         (vector parser-tag 'v2 exec entry-state entry-state 0 'ready)))
      (else
       (let ((feed (compiled-machine-v1-feed compiled-machine))
             (entry-state (compiled-machine-v1-entry-state compiled-machine)))
         (vector parser-tag 'v1 feed entry-state entry-state 0 'ready))))
```

Extend `parser-feed!` and `parser-finish!` to dispatch the `'v2` variant, and add the `'v2` drivers:

```scheme
  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (byte-machine-contract-violation 'parser-feed! 'invalid-slice (list start end)))
    (let ((r (case (parser-variant parser)
               ((op) (parser-feed-op! parser bv start end))
               ((v2) (parser-feed-v2! parser bv start end))
               (else (parser-feed-v1! parser bv start end)))))
      (case (parser-result-status r)
        ((stopped) (parser-set-lifecycle! parser 'stopped))
        ((error) (parser-set-lifecycle! parser 'error))
        ((finished) (parser-set-lifecycle! parser 'finished)))
      r))

  ;; The generated /v2 path: exec owns the dispatch loop; finish? = #f for feed.
  (define (parser-feed-v2! parser bv start end)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) bv start end #f)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (make-parser-result (feed-outcome-status o) (feed-outcome-next o)
                          (- (feed-outcome-next o) start)
                          (feed-outcome-offset o) (feed-outcome-error o))))
```

Extend `parser-finish!` (from ②b-1) so the `'v2` variant runs `exec` with `finish?` `#t` over the empty slice:

```scheme
  (define (parser-finish! parser)
    (case (parser-variant parser)
      ((op) (parser-finish-op! parser))
      ((v2) (parser-finish-v2! parser))
      (else (assertion-violation 'parser-finish! "unknown parser variant" (parser-variant parser)))))

  (define (parser-finish-v2! parser)
    (let* ((exec (parser-executor parser))
           (o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (case (feed-outcome-status o)
        ((finished) (parser-set-lifecycle! parser 'finished))
        ((error) (parser-set-lifecycle! parser 'error))
        ((stopped) (parser-set-lifecycle! parser 'stopped)))
      (make-parser-result (feed-outcome-status o) (feed-outcome-offset o) 0
                          (feed-outcome-offset o) (feed-outcome-error o))))
```

In `src/byte-machine/compile.sls`, add `byte-machine-make-compiled-machine/v2` to `reserved-member-2` (keep `/v1` and `byte-machine-make-feed-outcome/v1`).

- [ ] **Step 4: Run — expect GREEN**

Run:
```bash
make build
ctest --preset pr -R 'byte-machine\.unit\.runtime|differential|example' --output-on-failure
ctest --preset release -R 'reserved-drift' --output-on-failure
```
Expected: the `/v2` stub tests pass; the existing `/v1` emitter lanes (differential/example) STILL pass (emitter unchanged, `current-abi-version` still 1); drift guard green (new `/v2` export mirrored).

- [ ] **Step 5: Add Pass 32 mutations; bump counts**

Add to Pass 32 (`SPEC byte-machine.unit.runtime.chez.source`), before its run:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a /v2 finish does not drive exec with finish? true"
  FIND [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #t)))]]
  REPLACE [[(o (exec (parser-current parser) (parser-offset parser) empty-bv 0 0 #f)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "default-eof code")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a mismatched /v2 ABI version is accepted"
  FIND [[(unless (and (integer? abi-version) (= abi-version 2))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")
```

Counts: `EXPECTED_MUTATIONS` `116` → `118`; `EXPECTED_PASSES` stays `37`. Update Pass 32's narrative.

- [ ] **Step 6: Run the mutation suite; commit**

Run: `ctest --preset release -R 'scheme-mutation' --output-on-failure` (expect `37 / 118`).
```bash
git add src/byte-machine/runtime.sls src/byte-machine/compile.sls test/common/runtime-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: /v2 runtime machinery (unified exec with finish?), dormant; keeps /v1 export"
```

---

## Task 2: The generation flip — normalizer eof encoding + emitter `exec`/`/v2` + single golden re-baseline

**Files:**
- Modify: `src/byte-machine/private/normal-ir.sls` (finish state + eof-target encoding; fingerprint moves)
- Modify: `src/byte-machine/compile.sls` (emit `exec` with `finish?` branch + finish arm + `/v2` constructor; `reserved-member-3`)
- Modify: `src/byte-machine/runtime.sls` (`current-abi-version` → 2, so `/v1` becomes a mismatch stub)
- Modify: `test/common/normal-ir-tests.sps`, `test/common/compile-tests.sps`, `test/common/runtime-tests.sps` (rewrite the `/v1` mismatch case as `/v2`)
- Modify: `test/common/identifier-repertoire-tests.sps` (the `feed`→`exec` reservation flip; see Step 3)
- Modify: `test/fixtures/generated-one-byte.golden.sls` (re-baselined)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 35/36 mutations; counts; **re-baseline the 3 Pass-35 FNV fingerprint anchors — Step 2**)

**Interfaces:**
- Consumes: `byte-machine-make-compiled-machine/v2` (Task 1). Produces: `(byte-machine private normal-ir)` gains `normal-dispatch-eof` (a dispatch state's resolved eof routing: `(node . <id>)` or `(default . <code-symbol>)`) and a `finish` normal-state kind; the emitter renders `(define (exec state offset bv start end finish?) …)` calling `byte-machine-make-compiled-machine/v2`.

- [ ] **Step 1: Encode the finish state + eof routing in the normalizer (RED via the golden)**

In `src/byte-machine/private/normal-ir.sls`: import `finish-node?`, `byte-dispatch-node-eof-target`, `machine-default-eof-error` (add to the `(only …)` import). Export `normal-dispatch-eof`. Add the accessor (the normal-state vector grows a 7th slot for eof routing):

```scheme
  ;; (vector ns-tag kind id transitions fallback code eof) ; eof: dispatch only
  (define (normal-dispatch-eof s) (vector-ref s 6))
```

In `lower-machine`, resolve each dispatch node's eof routing and add the finish arm. The `id-of`/`errcode` helpers already exist; add a `default-eof-code` and resolve eof:

```scheme
           (default-eof-code (errcode (machine-default-eof-error machine)))
           (eof-of (lambda (n)
                     (let ((t (byte-dispatch-node-eof-target n)))
                       (if (symbol? t) (cons 'node (id-of t)) (cons 'default default-eof-code)))))
```

Dispatch arm → `(vector ns-tag 'dispatch i trs (cons (id-of (edge-target fb)) (edge-mode fb)) #f (eof-of n))`; stop → `(vector ns-tag 'stop i #f #f #f #f)`; error → `(vector ns-tag 'error i #f #f (errcode …) #f)`; **new** `((finish-node? n) (vector ns-tag 'finish i #f #f #f #f))`; the `else` guard stays.

In `encode-normal`, encode the dispatch eof routing (a byte + payload) and the finish kind. In the dispatch case, after the fallback, add:

```scheme
                (let ((eof (normal-dispatch-eof s)))
                  (if (eq? (car eof) 'node)
                      (begin (put-u8 p 0) (put-u32be p (cdr eof)))
                      (begin (put-u8 p 1) (put-symbol p (cdr eof)))))
```
and add `((finish) (put-u8 p 3))` to the state-kind case (before the `else`).

- [ ] **Step 2: Re-baseline the IR-fingerprint golden**

Run `make build && ctest --preset pr -R 'byte-machine\.unit\.normal-ir' --output-on-failure`. It FAILS at `normal-ir-tests.sps` — the one-byte fingerprint is no longer `11963406767470843108`. Read the failure's "got" value; update `normal-ir-tests.sps`'s `11963406767470843108` to that **measured** value. Re-run → PASS. (This is a golden re-baseline, not a placeholder — the test pins the algorithm; the value is measured.)

**In the same step, re-baseline the normalizer-side mutation anchors** (they depend only on the normalizer, not the emitter): update the three `EXPECT_OUTPUT_MATCHES "11963406767470843108"` strings in `test/support/cmake/SchemeMutationSuite.cmake` (the Pass-35 FNV mutations — FNV offset basis, FNV prime, byte-never-mixed, ~lines `:2251/:2258/:2265`) to the **same** measured value. Their kill-signature is the golden fingerprint that the failing `normal-ir-tests.sps` prints; leaving them stale makes those three mutations report `wrong-reason` (= uncaught) and fails the gated scheme-mutation suite. (The `generated-one-byte.golden.sls` and `compile-tests.sps` occurrences carry the same number but are re-baselined in Step 4, after the emitter flip regenerates the surrounding text.)

- [ ] **Step 3: Render `exec`/`/v2` in the emitter**

In `src/byte-machine/compile.sls`: `normal-dispatch-eof` is **already in scope** — compile.sls imports `(byte-machine private normal-ir)` as a **whole library** (`compile.sls:14-17`), so once Step 1 adds `normal-dispatch-eof` to that library's export list it is imported here with **no edit** to compile.sls's import form. Do **not** convert the whole-library import to `(only …)` (that would drop `normal-machine-states`/`-entry`/`-fingerprint`, `normal-state-id`/`-kind`, `normal-error-code`, `normal-dispatch-fallback`/`-transitions` — the accessors the emitter already uses — and break the build). Replace `render-state-arm` with the `exec` version (finish arm; the dispatch exhausted branch checks `finish?`):

```scheme
  (define (render-eof-branch eof id)
    (if (eq? (car eof) 'node)
        (string-append "(loop pos " (number->string (cdr eof)) " off)")
        (string-append "(byte-machine-make-feed-outcome/v1 (quote error) pos (quote "
                       (symbol->string (cdr eof)) ") " id " off)")))

  (define (render-state-arm s)
    (let ((id (number->string (normal-state-id s))))
      (case (normal-state-kind s)
        ((stop)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f " id " off))\n"))
        ((error)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote error) pos (quote "
                        (symbol->string (normal-error-code s)) ") " id " off))\n"))
        ((finish)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote finished) pos #f " id " off))\n"))
        ((dispatch)
         (let ((fb (normal-dispatch-fallback s)))
           (string-append
            "      ((" id ")\n"
            "       (if (>= pos end)\n"
            "           (if finish?\n"
            "               " (render-eof-branch (normal-dispatch-eof s) id) "\n"
            "               (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off))\n"
            "           (let ((b (bytevector-u8-ref bv pos)))\n"
            "             (case b\n"
            (apply string-append (map render-transition-arm (normal-dispatch-transitions s)))
            "               (else " (loop-tail (car fb) (cdr fb)) ")))))\n"))))))
```

In `render-machine`, change the generated `feed` closure to `exec` (add the `finish?` arg) and the constructor to `/v2`:

```scheme
        "  (define (exec state offset bv start end finish?)\n"
        "    (let loop ((pos start) (st state) (off offset))\n"
        "      (case st\n"
        (let loop ((i 0) (acc ""))
          (if (>= i (vector-length states)) acc
              (loop (+ i 1) (string-append acc (render-state-arm (vector-ref states i))))))
        "      (else (assertion-violation (quote exec) \"unknown state\" st)))))\n"
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine/v2 2 " (number->string fp) " "
        (number->string entry) " exec)))\n"))))
```

Update `reserved-member-3`: `feed`→`exec`, add `finish?` → `'(exec loop pos st off b bv start end state offset finish?)`.

**Then flip the two tests that assert `'feed` is *refused*** (the rename frees `'feed` and reserves `'exec`, so both would otherwise regress to failures): `test/common/identifier-repertoire-tests.sps:72` — change `'feed` to `'exec` in `rejected-bindings` (this file runs in two CI lanes, `byte-machine.verify.identifier-repertoire.chez.{source,aot}`); and `test/common/compile-tests.sps:102` — change `(render-machine ok 'feed)` to `(render-machine ok 'exec)` in the "reserved member 3" `check-raises`.

- [ ] **Step 4: Bump `current-abi-version`; re-baseline the emitter goldens; rewrite the `/v1` mismatch case**

In `src/byte-machine/runtime.sls`, change `(define current-abi-version 1)` → `(define current-abi-version 2)`. Now `/v1(1)` raises the mismatch cleanly (a stale v1 file), and `/v2(2)` still passes (it checks the literal 2). In `test/common/runtime-tests.sps`, the old `/v1` "mismatched ABI refused" case constructed `/v1 2 …` expecting a raise (because current was 1); it now must construct `/v1 1 …` (which raises against current=2) OR be dropped in favor of the `/v2` mismatch case from Task 1 — keep one mismatch case: `(byte-machine-make-compiled-machine/v1 1 42 0 stub-feed)` now raises (1≠2). Adjust its abi argument to `1` and keep the expected raise.

Re-baseline `test/fixtures/generated-one-byte.golden.sls` and `compile-tests.sps`: run `make build && ctest --preset pr -R 'differential|example|compile' --output-on-failure` — the emitted text changed (`exec`/`finish?` branch, `/v2`, new fingerprint). Regenerate the golden by emitting the one-byte machine (a small driver, or copy the emitter output from the failing determinism test), and update `generated-one-byte.golden.sls` to the exact new bytes; update `compile-tests.sps`'s asserted structure — the emitted-call `has?` fragment at `:77` (`byte-machine-make-compiled-machine/v1 1 <fp> 0 feed` → `…/v2 2 <newfp> 0 exec`) and the fingerprint `check-equal` at `:110` (to `<newfp>`). Note: `compile-tests.sps` has **no** `need-input` assertion, and the transition/fallback/error `has?` fragments (`:80/:81/:84`) are unchanged by the `feed`→`exec`/`/v2` flip; the member-3 witness (`:102`) was already flipped in Step 3. Re-run → PASS.

- [ ] **Step 5: Run — expect GREEN across generation**

Run: `make build && make test`
Expected: all `pr` lanes pass — normal-ir (new golden), compile (new golden + `/v2`), differential/example (now emit + run `/v2` with the finish path unreachable in feed-only tests but present), runtime (`/v1` now a mismatch stub, `/v2` live).

- [ ] **Step 6: Add mutations for the encoding + emitter arms; bump counts**

Add mutations: Pass 35 (normalizer, `SPEC byte-machine.unit.normal-ir.chez.source`) for the eof encoding (e.g., FIND the `(put-u8 p 0) (put-u32be p (cdr eof))` node-eof encoding, REPLACE to skip it → the fingerprint golden shifts → caught by `normal-ir-tests.sps`); Pass 36 (emitter, `SPEC byte-machine.unit.compile.chez.source`) for the finish arm and the `finish?` branch (FIND the `(quote finished)` finish-arm render / the `(if finish?` branch, REPLACE → the golden/differential fails). Verify each FIND is a unique verbatim substring. Counts: add the number of mutations you wrote; update `EXPECTED_MUTATIONS` and the affected passes' narratives in this commit. Re-run the whole suite.

- [ ] **Step 7: Commit**

```bash
git add src/byte-machine/private/normal-ir.sls src/byte-machine/compile.sls src/byte-machine/runtime.sls \
        test/common/normal-ir-tests.sps test/common/compile-tests.sps test/common/runtime-tests.sps \
        test/common/identifier-repertoire-tests.sps \
        test/fixtures/generated-one-byte.golden.sls test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: emit /v2 exec with the finish? EOF branch; normalizer encodes eof routing (fingerprint re-baselined)"
```

---

## Task 3: Interpreter≡generated differential over EOF

**Files:**
- Create: `test/common/differential-eof-tests.sps`
- Modify: `test/CMakeLists.txt` (two lanes)

**Interfaces:**
- Consumes: `make-eof-machine` (`(byte-machine test eof-machine)`, from ②b-1), the `/v2` emitter (Task 2), `parser-finish!` (both variants).

- [ ] **Step 1: Write the EOF differential (RED if generation is wrong)**

Create `test/common/differential-eof-tests.sps`, modeled on `differential-one-byte-tests.sps` but over `make-eof-machine`, comparing the interpreter (`op`) and the emitted (`v2`) executors for BOTH feed and finish:

```scheme
(import (rnrs) (rnrs eval) (only (chezscheme) load)
        (byte-machine test harness) (byte-machine test eof-machine)
        (byte-machine graph) (byte-machine verify) (byte-machine interpret)
        (byte-machine runtime) (byte-machine compile))
(harness-begin "differential.eof")
(define tmpdir (or (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")
                   (assertion-violation 'differential-eof "no tmpdir" #f)))
(define genfile (string-append tmpdir "/generated-eof.sls"))
(define m (make-eof-machine))
(define cm-ref (make-interpreted-machine (verify-machine m)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine m '()) 'eof-parser p)))
(load genfile)
(define cm-gen (eval 'eof-parser (environment '(generated eofm))))
;; feed a schedule, then finish; return (feed-fields . finish-fields).
(define (rfields cm bytes)
  (let ((p (make-parser cm '() #f)))
    (for-each (lambda (b) (parser-feed! p (make-bytevector 1 b) 0 1)) bytes)
    (let ((rf (parser-finish! p)))
      (list (parser-result-status rf) (parser-result-stream-offset rf) (parser-result-error rf)))))
(harness-group "interpreter and generated agree on finish after every prefix"
  (lambda ()
    (harness-case "idle, one-byte truncation, and full sequence agree"
      (lambda ()
        (check-equal "idle" (rfields cm-gen '()) (rfields cm-ref '()))
        (check-equal "trunc" (rfields cm-gen '(1)) (rfields cm-ref '(1)))
        (check-equal "full+finish" (rfields cm-gen '(1 2)) (rfields cm-ref '(1 2)))
        (check-equal "idle is finished" (car (rfields cm-gen '())) 'finished)
        (check-equal "trunc is error" (car (rfields cm-gen '(1))) 'error)))
    (harness-case "all 256 first bytes: op and gen agree on feed-then-finish"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (unless (equal? (rfields cm-ref (list b)) (rfields cm-gen (list b)))
                (when (eq? bad 'none) (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte disagreed" bad 'none))))))
(harness-finish)
```

Register two `chez` lanes (source + aot) labeled `differential`, `SOURCES = HARNESS_MANIFEST + CORE_EMIT + eof-machine.sls + program` (model on `byte-machine.differential.sequence.chez.*`).

- [ ] **Step 2: Run — expect GREEN**

Run: `make build && ctest --preset pr -R 'differential\.eof' --output-on-failure`
Expected: both lanes PASS — the generated `/v2` finish path equals the interpreter's for idle, truncation, and the full sequence, across all 256 first bytes. A red here is a real lowering defect in Task 2: STOP and use superpowers:systematic-debugging.

- [ ] **Step 3: Commit**

```bash
git add test/common/differential-eof-tests.sps test/CMakeLists.txt
git commit -m "test: interpreter≡generated differential over EOF (feed-then-finish, all 256 first bytes)"
```

---

## Task 4: CHANGELOG, AGENTS.md standard, whole-suite re-measure

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `AGENTS.md`
- (verification)

- [ ] **Step 1: CHANGELOG entry for the `/v2` ABI change (§9.5:444)**

Add an entry to `CHANGELOG.md` (follow its existing format) recording the generated-ABI change: `byte-machine-make-compiled-machine/v2` (unified `exec` with a `finish?` EOF path), `current-abi-version` → 2, `/v1` kept as a version-mismatch stub, the one-byte IR fingerprint re-baselined, and that generated code is deterministically regenerated.

- [ ] **Step 2: Add the mutation-witness-SPEC-lane standard to AGENTS.md**

Under "Testing & mutation discipline", add a bullet (in the project's demonstrated-defect style):

```markdown
* **A mutation's witnessing test lives in its own SPEC lane's program.**
  A mutation is only witnessed by tests that run in the lane named by its
  `SPEC`. The runtime's SPEC lane (`byte-machine.unit.runtime.chez.source`)
  drives `runtime.sls` through hand-built op stubs, not the interpreter — so a
  runtime mutation whose only witness lives in `interpret-tests.sps` (a
  different lane) is uncaught. Slice ②b-1 shipped exactly this until an uncaught
  mutation surfaced it. When you add a mutation, put its witness in that
  mutation's SPEC-lane program.
```

- [ ] **Step 3: Whole-suite clean re-measure**

Run:
```bash
make clean && make test-all
cmake --preset no-scheme >/dev/null && cmake --build --preset no-scheme >/dev/null && ctest --preset no-scheme
ctest --preset release -R 'scheme-mutation' --output-on-failure | rg 'passes|mutations|PASS|FAIL'
```
Expected: `release` green (64 + 2 EOF-differential lanes = **66**); `no-scheme` **8/8**; the mutation suite at its final measured totals. Record the exact `release`/`pr` count and mutation totals for the close-out.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md AGENTS.md
git commit -m "docs: CHANGELOG /v2 ABI entry; AGENTS.md mutation-witness-SPEC-lane standard"
```

---

## Self-Review

1. **Spec coverage (design §5, ②b-2):** normalizer finish/eof encoding + fingerprint move → Task 2. Emitter unified `exec` + `finish?` branch + distinct finish arm + `/v2` constructor → Task 2. `/v2` ABI + `/v1`-kept-as-stub + drivers → Tasks 1–2. Single golden re-baseline → Task 2 (Tasks 1/3 touch no golden). Interpreter≡generated differential over EOF → Task 3. `/v1`→`/v2` blast radius (mismatch case) → Task 2. CHANGELOG + reserved-member-2/-3 deltas → Tasks 1–2, 4. AGENTS.md standard (from the reflect) → Task 4. **Deferred, correctly absent:** `position-kind` (design §7), the pause node (Slice ③).
2. **Placeholder scan:** golden values are *measured* re-baselines (Task 2 Steps 2/4 say run-fail-read-update), not placeholders; Task 2 Step 6's mutation set names the passes/anchors but the exact count is computed at write time (it says update `EXPECTED_MUTATIONS` and the narratives in-commit) — acceptable for a mutation-authoring step. No "TBD".
3. **Type/name consistency:** `byte-machine-make-compiled-machine/v2 abi ir-fp entry exec`, `exec (state offset bv start end finish?)`, `normal-dispatch-eof` → `(node . id)`/`(default . code)`, `parser-feed-v2!`/`parser-finish-v2!`, `compiled-machine-v2-exec`/`-entry-state`, and the `'v2` variant tag are defined in Task 1/2 and used consistently; `render-eof-branch` matches the stub's eof outcome shape so the differential (Task 3) has op≡gen by construction.
4. **Golden-re-baseline-once discipline:** `current-abi-version` stays 1 in Task 1 (emitter still `/v1`, goldens untouched); Task 2 flips the normalizer + emitter + abi bump together, re-baselining **all four** fingerprint sites exactly once — `normal-ir-tests` + the 3 `SchemeMutationSuite.cmake` FNV anchors (Step 2, normalizer-side), then `compile-tests` + `generated-one-byte.golden.sls` (Step 4, emitter-side); Task 3 emits fresh (`make-eof-machine`, no committed golden). The `feed`→`exec` rename also flips `identifier-repertoire-tests.sps:72` and `compile-tests.sps:102` (the two `'feed`-is-refused witnesses) — Step 3.
