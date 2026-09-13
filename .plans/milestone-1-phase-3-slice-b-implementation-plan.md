# Milestone 1 Phase 3 Slice B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove Phase 3's determinism (D6) and identifier (D7) properties exhaustively, add the property-based machine generator, ship the member-2 runtime-export drift guard, delete the M0 placeholder libraries, and land the confirmed Slice A Minors — closing Milestone 1's Phase-3 obligations on the two CI cells.

**Architecture:** Slice B adds **no new product library** and **no new runtime export** (`/v2` stays benchmark-gated per decision 0010). It adds test programs, one shared fixture library, one committed golden byte fixture, a test-support PRNG + machine generator under `(byte-machine test …)`, mutation passes, one preset-filter edit, and doc amendments; it deletes two product libraries and their lanes. The only product-source edits are behaviour-preserving Minors — none may move the golden IR fingerprint `11963406767470843108`.

**Tech Stack:** R6RS Scheme on Chez 10.4.1 (source + AOT lanes); CMake/CTest harness; the in-tree `(byte-machine test harness)` runner; the CMake Scheme mutation suite.

## Global Constraints

Copied verbatim from the design (milestone-1-phase-3-slice-b-design.md) and the repo's standing rules (AGENTS.md, milestone-1-design.md §8):

- **Baselines at branch base** (`db3d3fd`, re-verified on the branch): `ctest --preset release` **55/55**; `ctest --preset no-scheme` **8/8**; Scheme mutation suite **36 passes / 107 mutations** (`EXPECTED_PASSES`/`EXPECTED_MUTATIONS` at `test/support/cmake/SchemeMutationSuite.cmake:199-200`); CMake mutation suite **1 pass / 72 mutations**.
- **Golden IR fingerprint** of the one-byte machine is `11963406767470843108`. Any behaviour-preserving edit (T1c) must leave it unchanged; it is pinned in `test/common/normal-ir-tests.sps` and `test/common/compile-tests.sps`.
- **Mutation discipline:** every decision in new code, and every property proved, gets a mutation an owning spec notices, asserting a **measured** failure signature (`EXPECT_STATUS` + `EXPECT_OUTPUT_MATCHES`), never a bare nonzero exit. Adding or removing an exit path re-runs the **whole** mutation suite; declared totals and their arithmetic move in the **same commit** as the passes they cover and are **re-read from the suite before bumping**, never quoted from this plan.
- **No new dependencies.** `no-scheme` stays green at 8/8. Generated/emitted `.sls` files written by tests are excluded from every lane's `SOURCES` manifest and the basename-uniqueness check (decision 0006); the committed golden byte fixture is a fixture, not repository Scheme on any library path.
- **Lane labels are auto-derived** from the second dotted component of the lane name (`cmake/ByteMachineTesting.cmake:211-215`); the layer vocabulary (`ByteMachineTesting.cmake:29-39`) already contains `property` and `determinism`. The `pr` preset filter (`CMakePresets.json:79`) already whitelists `determinism`; only `property` must be added.
- **`/v2` is not shipped** (decision 0010 §5 gates it on benchmark evidence). The drift guard is made load-bearing by its mutation, not by a new export.
- **Conventional Commits**; run the affected lane(s) green before every commit; end commit messages with the `Co-Authored-By` trailer.

**Expected count movements** (intended; **re-measure and record actuals** in each task's close — the numbers below are the arithmetic to check against, not values to hard-code without measuring):

| Task | New lanes (`release`) | Mutation passes | Mutations | Notes |
|---|---|---|---|---|
| 1 D7 repertoire + LF | +2 (source+aot) | +1 | +~4 | grammar-relax ×2 sites, LF-CR inject, interior-char relax |
| 2 D6 determinism | +2 | +1 | +~2 | writer perturbation vs golden |
| 3 Property generator | +2 | +1 | +~2 | generator/differential witnessed |
| 4 Member-2 drift | +2 | +1 | +1 | drop-an-entry from `reserved-member-2` |
| 5 Delete placeholders | −4 (2 source, 2 aot) | −1 or per-pass | − | remove placeholder pass(es); re-measure |
| 6 Minors | 0 | +~1 | +~2 | T1a else-guards; T3 retarget (net 0) |
| 7 Close-out | 0 | 0 | 0 | docs + final re-measure |

---

### Task 1: D7 — identifier repertoire and binary-LF proofs

**Files:**
- Create: `test/common/identifier-repertoire-tests.sps`
- Modify: `test/CMakeLists.txt` (register two lanes after the Slice A example lanes, ~line 946)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new pass; bump `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` at :199-200)

**Interfaces:**
- Consumes: `(byte-machine verify)` — `verify-machine`, `verification-ok?` (verify.sls); `(byte-machine graph)` constructors; `(byte-machine compile)` — `compile-machine`, `render-machine` (compile.sls). The name grammar `[a-z][a-z0-9-]*` is enforced by `valid-name?` (verify.sls:31, machine/node/error names) and `valid-binding?` (compile.sls:50, output bindings). Both reject: empty; first char not `[a-z]`; any interior char outside `[a-z0-9-]`; and reserved member-1 words.
- Produces: lane `byte-machine.verify.identifier-repertoire.chez.{source,aot}` (label `verify`, already in `pr`).

- [ ] **Step 1: Write the failing test.** Create `test/common/identifier-repertoire-tests.sps`. It drives both grammar sites. For the **verify** site it builds a machine whose *machine name* is the candidate and checks `verification-ok?` matches the expectation (a name-invalid machine yields an `invalid-name` diagnostic → not ok). For the **binding** site it renders the fixed one-byte machine with the candidate as the binding and checks accept (returns a bytevector) vs reject (raises a `'render-machine` `invalid-output-binding` assertion). It also proves LF-only output.

```scheme
;;; D7 (parent §22.9, §20): the emitted identifier repertoire, proved exhaustively.
;;; Machine names go through verify's [a-z][a-z0-9-]* grammar; output bindings go
;;; through compile's identical grammar plus the reserved set. Diagnostics and
;;; conditions are checked by category, never by prose (parent §22.10). The LF
;;; proof reads raw emitted bytes; the real Windows CRLF trap rides to M9 (this
;;; cell cannot exhibit it).
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile))

(harness-begin "verify.identifier-repertoire")

;; --- a machine whose only variable is its NAME, for the verify-site grammar ---
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define (machine-named nm)
  (make-machine nm 'start '() '() '() (list rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define (name-accepted? nm) (verification-ok? (verify-machine (machine-named nm))))

;; --- the fixed one-byte machine, for the binding-site grammar ---
(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define ok (compile-machine one-byte '()))
(define (binding-accepted? sym)
  (guard (e (#t #f)) (bytevector? (render-machine ok sym))))

;; Accepted repertoire: leading [a-z], interior [a-z0-9-], including a trailing
;; hyphen (a name-char) and digits after the first position. Both sites agree.
(define accepted '(a z ab a1 a-b abc-123 zzz9 a- start one-byte))
;; Rejected: empty, leading digit, leading hyphen, uppercase anywhere,
;; punctuation other than '-', and a reserved member-1 keyword.
(define rejected-names '(9a -a Ab aB a.b a_b a/b a+b |a b| define))
;; Bindings additionally reserve runtime exports (member 2) and template ids
;; (member 3); the grammar-only rejects above still apply.
(define rejected-bindings '(9a -a Ab a.b define make-compiled-machine feed))

(harness-group "machine names: the verify-site grammar"
  (lambda ()
    (harness-case "every accepted name verifies"
      (lambda ()
        (for-each (lambda (nm) (check (string-append "accept " (symbol->string nm))
                                      (name-accepted? nm)))
                  accepted)))
    (harness-case "every rejected name is refused"
      (lambda ()
        (for-each (lambda (nm) (check (string-append "reject " (symbol->string nm))
                                      (not (name-accepted? nm))))
                  rejected-names)))))

(harness-group "output bindings: the compile-site grammar and reserved set"
  (lambda ()
    (harness-case "every accepted binding renders"
      (lambda ()
        (for-each (lambda (sym) (check (string-append "accept " (symbol->string sym))
                                       (binding-accepted? sym)))
                  accepted)))
    (harness-case "every rejected binding is refused"
      (lambda ()
        (for-each (lambda (sym) (check (string-append "reject " (symbol->string sym))
                                       (not (binding-accepted? sym))))
                  rejected-bindings)))))

(harness-group "binary output is LF-only with a final newline"
  (lambda ()
    (harness-case "no carriage return byte appears and the last byte is LF"
      (lambda ()
        (let* ((bytes (render-machine ok 'one-byte-parser))
               (n (bytevector-length bytes)))
          (let loop ((i 0))
            (when (< i n)
              (when (= (bytevector-u8-ref bytes i) 13)
                (check-fail "carriage return present"
                            (string-append "CR byte at offset " (number->string i))))
              (loop (+ i 1))))
          (check-equal "final byte is LF" (bytevector-u8-ref bytes (- n 1)) 10))))))

(harness-finish)
```

- [ ] **Step 2: Register the two lanes.** In `test/CMakeLists.txt`, after the Slice A example lanes (~line 946), add. The manifest is `BYTE_MACHINE_CORE_EMIT` (it already unites verify + compile, the two libraries this spec imports):

```cmake
# --- Milestone 1 Phase 3 Slice B: D7 identifier repertoire + binary LF -------
byte_machine_add_scheme_lane(
  NAME byte-machine.verify.identifier-repertoire.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.verify.identifier-repertoire.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/identifier-repertoire-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 3: Configure and run the new lanes — expect PASS (witness-strengthening).** These lanes assert an already-true property, so they pass on first run; the RED is the mutations in Step 5. Run:

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
ctest --preset dev -R 'identifier-repertoire' --output-on-failure
```

Expected: 2 tests pass. If any accepted/rejected case fails, the candidate lists are wrong against the shipped grammar — fix the *test data* to match `valid-name?`/`valid-binding?`, not the grammar.

- [ ] **Step 4: Commit the spec + lanes.**

```bash
git add test/common/identifier-repertoire-tests.sps test/CMakeLists.txt
git commit -m "test: exhaustive D7 identifier repertoire and binary-LF proof (Slice B)"
```

- [ ] **Step 5: Add the witnessing mutations.** In `test/support/cmake/SchemeMutationSuite.cmake`, add a new pass after Pass 36 (before the totals check near line 2333). Model the verify command on Pass 36's (both library roots, empty object guard). Each mutation asserts the repertoire spec catches a relaxed grammar or an injected CR:

```cmake
# --- Pass 37: D7 identifier repertoire + LF (Slice B) -------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/identifier-repertoire-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "verify: a name with a non-lowercase first char is accepted"
  FIND [[(lower-alpha? (string-ref s 0))
           (let loop ((i 1))]]
  REPLACE [[#t
           (let loop ((i 1))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "reject")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "verify: any interior character is accepted"
  FIND [[(or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-name? sym)]]
  REPLACE [[#t)
  (define (valid-name? sym)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "reject")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "compile: any interior binding character is accepted"
  FIND [[(or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-binding? sym)]]
  REPLACE [[#t)
  (define (valid-binding? sym)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "reject")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.verify.identifier-repertoire.chez.source
  LABEL "compile: the final newline is emitted as CRLF"
  FIND [[" feed)))\n"))))]]
  REPLACE [[" feed)))\r\n"))))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "carriage return")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> **Note on the two interior-char mutations:** `name-char?` is defined *identically* in verify.sls (:29) and compile.sls (:48). Each `FIND` above anchors on the line that *follows* the definition (`(define (valid-name? sym)` / `(define (valid-binding? sym)`), which differs between the files, so the two-line `FIND` is unique within each file. Verify uniqueness in Step 6.

- [ ] **Step 6: Verify each `FIND` is unique, then bump the totals.** Confirm anchors:

```bash
grep -c 'feed)))\\n' src/byte-machine/compile.sls    # expect 1
grep -n 'define (valid-name? sym)' src/byte-machine/verify.sls    # the anchor line
grep -n 'define (valid-binding? sym)' src/byte-machine/compile.sls
```

Then set `EXPECTED_PASSES` `36 → 37` and `EXPECTED_MUTATIONS` `107 → 111` at `SchemeMutationSuite.cmake:199-200`, and update the header arithmetic comment (search the file for the running-total narrative near line 194).

- [ ] **Step 7: Run the whole mutation suite — expect the new pass green and totals reconciled.**

```bash
ctest --preset dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -20
```

Expected: `scheme mutation suite complete (37 passes, 111 mutations)` (or the re-measured actuals). If a mutation is *uncaught* (survives), the spec does not witness that decision — re-examine the `FIND`/spec pairing; do **not** silence it by deleting the mutation. If the CR mutation is caught but the output substring differs, align `EXPECT_OUTPUT_MATCHES` to what the spec actually prints (`check-fail`'s `what` is `"carriage return present"`).

- [ ] **Step 8: Re-measure `release`/`no-scheme` and commit.**

```bash
ctest --preset release 2>&1 | tail -3    # expect 57/57 (55 + 2)
ctest --preset no-scheme 2>&1 | tail -3  # expect 8/8
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: witness the D7 grammar and LF decisions by mutation (Slice B)"
```

Record the measured `release` and mutation numbers in the task report.

---

### Task 2: D6 — determinism hardening against a committed golden

**Files:**
- Create: `test/common/determinism-one-byte-tests.sps`
- Create: `test/fixtures/generated-one-byte.golden.sls` (the committed golden bytes — generated in Step 2, never hand-typed)
- Modify: `test/CMakeLists.txt` (two lanes; the golden path passed via `ENVIRONMENT`)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new pass; bump totals)

**Interfaces:**
- Consumes: `(byte-machine compile)` `compile-machine`/`render-machine`/`emit-machine`; `(byte-machine graph)`; `(byte-machine runtime)`; `(rnrs eval)` `environment`/`eval`; `(only (chezscheme) load)`. `render-machine` returns the complete canonical source as a **bytevector** (compile.sls:97-122); it is pure and deterministic. `adapter-file-bytes` (harness.sls:161) reads a file as raw bytes; `adapter-environment-variable` reads env.
- Produces: lane `byte-machine.determinism.one-byte.chez.{source,aot}` (label `determinism`, already in `pr`).

- [ ] **Step 1: Write the failing test.** Create `test/common/determinism-one-byte-tests.sps`. It (a) renders twice and asserts byte-equality, (b) asserts the rendered bytes equal the committed golden read from `BYTE_MACHINE_GOLDEN_FILE`, and (c) emits, loads, and runs the generated parser (compile-and-execute):

```scheme
;;; D6 (parent §22.9, §20): deterministic emission proved against a committed
;;; golden. Byte-identity in this process AND equality to the golden (which every
;;; cell and lane compares against) give cross-process, cross-lane, and cross-cell
;;; identity transitively; M9 completes the four-cell matrix with the same golden.
;;; Comparison is over raw bytes through the project-owned writer, never via
;;; implementation `write`.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "determinism.one-byte")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(define ok (compile-machine one-byte '()))

(define golden-file
  (let ((f (adapter-environment-variable "BYTE_MACHINE_GOLDEN_FILE")))
    (if (and f (not (string=? f ""))) f
        (assertion-violation 'determinism "BYTE_MACHINE_GOLDEN_FILE is unset" f))))

(harness-group "byte-identical emission"
  (lambda ()
    (harness-case "rendering twice in one process yields identical bytes"
      (lambda ()
        (check-equal "twice" (render-machine ok 'one-byte-parser)
                     (render-machine ok 'one-byte-parser))))
    (harness-case "the emitted bytes equal the committed golden"
      (lambda ()
        (check-equal "golden" (render-machine ok 'one-byte-parser)
                     (adapter-file-bytes golden-file))))))

(harness-group "the golden output compiles and executes"
  (lambda ()
    (harness-case "loading the emitted library and feeding byte 0 stops after one byte"
      (lambda ()
        (let* ((tmpdir (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR"))
               (genfile (string-append tmpdir "/determinism-one-byte.sls")))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine ok 'one-byte-parser p)))
          (load genfile)
          (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
                 (r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 0) 0 1)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "consumed" (parser-result-consumed r) 1)))))))

(harness-finish)
```

- [ ] **Step 2: Generate the committed golden from the shipped emitter.** Do **not** hand-type it. Run the emitter once and write its exact bytes:

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
CHEZ=$(sed -n 's/.*BYTE_MACHINE_CHEZ_EXECUTABLE:[A-Z]*=//p' build/dev/CMakeCache.txt)
"$CHEZ" --libdirs "src" --program /dev/stdin > test/fixtures/generated-one-byte.golden.sls <<'EOF'
(import (rnrs) (byte-machine graph) (byte-machine compile))
(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
            (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))
(emit-machine (compile-machine one-byte '()) 'one-byte-parser
              (standard-output-port))
EOF
```

Then sanity-check the golden opens as a library and contains the v1 call with the golden fingerprint:

```bash
grep -c '(byte-machine-make-compiled-machine/v1 1 11963406767470843108 0 feed)' test/fixtures/generated-one-byte.golden.sls   # expect 1
tail -c 20 test/fixtures/generated-one-byte.golden.sls | xxd | tail -1   # last byte 0a, no 0d
```

> If `--libdirs`/`--program` differ on the host Chez, use the same launcher the lanes use (`test/support/launchers/chez-source.ss`) with `--library-root src`. The only requirement is that the bytes come from the shipped `emit-machine`.

- [ ] **Step 3: Register the two lanes with the golden path in the environment.** In `test/CMakeLists.txt`, after Task 1's lanes:

```cmake
# --- Milestone 1 Phase 3 Slice B: D6 determinism against a committed golden ---
byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.one-byte.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-one-byte.golden.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.determinism.one-byte.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/determinism-one-byte-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "BYTE_MACHINE_GOLDEN_FILE=${CMAKE_SOURCE_DIR}/test/fixtures/generated-one-byte.golden.sls")
```

- [ ] **Step 4: Run the new lanes — expect PASS.**

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
ctest --preset dev -R 'determinism.one-byte' --output-on-failure
```

Expected: 2 pass. A `golden` failure means the committed bytes and the live emitter disagree — re-run Step 2 (do not edit the test to accept a mismatch).

- [ ] **Step 5: Commit the spec, golden, and lanes.**

```bash
git add test/common/determinism-one-byte-tests.sps test/fixtures/generated-one-byte.golden.sls test/CMakeLists.txt
git commit -m "test: D6 byte-identical emission proved against a committed golden (Slice B)"
```

- [ ] **Step 6: Add the witnessing mutation.** A perturbation of the canonical writer must diverge from the golden. In `SchemeMutationSuite.cmake` add a pass (verify command targets `determinism-one-byte-tests.sps`):

```cmake
# --- Pass 38: D6 determinism vs golden (Slice B) -----------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/determinism-one-byte-tests.sps"
  # the golden lives in the source tree; the staged program reads it via env
  )
set(ENV{BYTE_MACHINE_GOLDEN_FILE} "${SOURCE_ROOT}/test/fixtures/generated-one-byte.golden.sls")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.determinism.one-byte.chez.source
  LABEL "compile: the writer's export line spacing changes"
  FIND [["  (export " bstr ")\n"]]
  REPLACE [["  (export  " bstr ")\n"]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "golden")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> `BYTE_MACHINE_GOLDEN_FILE` must be set for the staged run to read the golden. Confirm the mutation harness passes the process environment to its verify command (Pass 36's placeholder-derived command relies on the same inheritance; `test/CMakeLists.txt:591-600` sets env for the suite). If the suite scrubs env, pass the golden path another way the suite supports (measure in Step 7). Verify `FIND` `"  (export " bstr ")\n"` occurs once (compile.sls:111).

- [ ] **Step 7: Bump totals, run the suite, re-measure.** Set `EXPECTED_PASSES` `37 → 38`, `EXPECTED_MUTATIONS` `111 → 112` (adjust to actuals). Run:

```bash
ctest --preset dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -8
ctest --preset release 2>&1 | tail -3     # expect 59/59
```

If the golden mutation survives because the staged program could not read the golden, that is a real gap — wire the golden path through the mechanism the suite actually provides (the suite's `ENVIRONMENT` block in `test/CMakeLists.txt`) rather than declaring a survivor.

- [ ] **Step 8: Commit.**

```bash
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: witness deterministic emission by perturbing the writer (Slice B)"
```

---

### Task 3: Property-based machine generator and the interpreter≡generated differential

**Files:**
- Create: `test/support/harness/byte-machine/test/prng.sls` — deterministic in-tree PRNG
- Create: `test/support/harness/byte-machine/test/machine-gen.sls` — bounded valid-machine generator
- Create: `test/common/property-differential-tests.sps` — the property spec
- Modify: `CMakePresets.json:79` — add `property` to the `pr` filter
- Modify: `test/CMakeLists.txt` — a manifest fragment + two lanes
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` — new pass; bump totals

**Interfaces:**
- Consumes: `(byte-machine graph)` constructors; `(byte-machine verify)` `verify-machine`/`verification-ok?`; `(byte-machine interpret)` `make-interpreted-machine`; `(byte-machine compile)` `compile-machine`/`emit-machine`; `(byte-machine runtime)`; `(rnrs eval)`.
- Produces:
  - `(byte-machine test prng)` exporting `make-prng` (seed → state) and `prng-next` (state, bound → (values k state')). Pure LCG; no `random`, no mutation of global state.
  - `(byte-machine test machine-gen)` exporting `gen-machine` (prng-state → (values machine prng-state')), producing only machines `verify-machine` accepts.
  - lane `byte-machine.property.differential.chez.{source,aot}` (label `property`, newly whitelisted).

- [ ] **Step 1: Write the PRNG and its unit test.** Create `test/support/harness/byte-machine/test/prng.sls`:

```scheme
;;; A deterministic in-tree PRNG (parent §22.6): no host `random`, no global
;;; state, seed reproducible. 64-bit LCG (Knuth MMIX constants) masked to 63 bits;
;;; prng-next returns a value in [0,bound) and the next state, so callers thread
;;; state explicitly and a failing seed replays exactly.
(library (byte-machine test prng)
  (export make-prng prng-next)
  (import (rnrs))
  (define mask (- (expt 2 63) 1))
  (define (make-prng seed) (bitwise-and mask (+ seed 1)))
  (define (step s)
    (bitwise-and mask (+ (* s 6364136223846793005) 1442695040888963407)))
  ;; Return (values k s') with 0 <= k < bound, using the high bits of the next
  ;; state (low LCG bits are the least random).
  (define (prng-next s bound)
    (let ((s2 (step s)))
      (values (mod (bitwise-arithmetic-shift-right s2 17) bound) s2))))
```

Add a case to a new `test/common/property-differential-tests.sps` (Step 3) or a dedicated prng check inside it; the PRNG's own determinism is asserted there (same seed ⇒ same sequence).

- [ ] **Step 2: Write the machine generator.** Create `test/support/harness/byte-machine/test/machine-gen.sls`. It builds a machine with one dispatch entry node, a bounded set of distinct exact-byte cases (non-overlapping — distinct bytes), a fallback edge, and two terminals (one stop, one error), all names from the valid grammar. Every machine it returns is accepted by `verify-machine` (asserted in the spec):

```scheme
;;; A bounded generator of VALID M1-shaped machines (parent §22.6): entry is a
;;; byte-dispatch node whose cases are distinct bytes (non-overlapping by
;;; construction) targeting stop/error/self, plus a fallback; two terminals. It
;;; never emits an invalid graph — verifier rejection has its own tests
;;; (verify-tests.sps). State is threaded from (byte-machine test prng).
(library (byte-machine test machine-gen)
  (export gen-machine)
  (import (rnrs)
          (byte-machine test prng)
          (byte-machine graph))

  (define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
  (define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
  ;; targets a dispatch case may point at: the two terminals or back to entry.
  (define targets '#(stop reject start))
  (define modes '#(advance reexecute))

  ;; Draw n DISTINCT bytes in [0,256).
  (define (distinct-bytes s n)
    (let loop ((s s) (need n) (acc '()))
      (if (= need 0) (values (reverse acc) s)
          (let-values (((b s2) (prng-next s 256)))
            (if (memv b acc) (loop s2 need acc)
                (loop s2 (- need 1) (cons b acc)))))))

  (define (gen-case s b)
    (let*-values (((ti s1) (prng-next s (vector-length targets)))
                  ((mi s2) (prng-next s1 (vector-length modes))))
      (values (make-byte-case (make-exact-byte-matcher b)
                              (make-edge (vector-ref targets ti) (vector-ref modes mi)) #f)
              s2)))

  (define (gen-cases s bytes)
    (let loop ((s s) (bs bytes) (acc '()))
      (if (null? bs) (values (reverse acc) s)
          (let-values (((c s2) (gen-case s (car bs))))
            (loop s2 (cdr bs) (cons c acc))))))

  ;; 1..4 dispatch cases; a reexecute fallback to the error terminal.
  (define (gen-machine s)
    (let*-values (((ncell s1) (prng-next s 4))
                  ((bytes s2) (distinct-bytes s1 (+ 1 ncell)))
                  ((cases s3) (gen-cases s2 bytes)))
      (values
       (make-machine 'gen 'start '() '() '() (list eof-decl rej-decl)
         (list (make-byte-dispatch-node 'start cases
                 (make-edge 'reject 'reexecute) #f #f)
               (make-stop-node 'stop #f)
               (make-error-node 'reject 'rejected #f))
         'default-eof #f)
       s3))))
```

> A `reexecute` self-loop on `start` for the same byte every time would be a zero-progress cycle the verifier rejects; here every case that targets `start` may do so with `advance` or `reexecute`, and the verifier accepts a reexecute edge only when some path makes progress. Step 4 asserts **every** generated machine verifies — if the verifier rejects any, tighten `targets`/`modes` (e.g. force `advance` when the target is `start`) until all pass. This is the "generator emits only valid machines" contract; fix the generator, never feed an invalid machine to the differential.

- [ ] **Step 3: Write the property differential spec.** Create `test/common/property-differential-tests.sps`. For a fixed seed it generates N machines, verifies each, emits+loads each, and runs the interpreter≡generated differential across all 256 single-byte feeds; it prints the seed and the failing machine index on any disagreement:

```scheme
;;; Property differential (parent §22.4, §22.6): generated valid machines, the
;;; interpreter oracle vs the emitted executor, all 256 single-byte feeds each.
;;; The seed is fixed and printed; a disagreement prints the machine index so the
;;; case replays. Generated .sls are test-time artifacts in the tmp root.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine test prng)
        (byte-machine test machine-gen)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "property.differential")

(define seed 20260823)
(define machine-count 40)
(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'property "BYTE_MACHINE_TEST_TMPDIR is unset" d))))

(define (rfields cm b)
  (let ((r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1)))
    (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
          (parser-result-stream-offset r) (parser-result-error r))))

;; Emit `m` to a fresh file, load it, and return its compiled-machine. The
;; library name is (generated gen) for every machine, so each emission gets its
;; own file and a fresh eval environment.
(define (emit-and-load m i)
  (let ((genfile (string-append tmpdir "/prop-" (number->string i) ".sls")))
    (call-with-port (open-file-output-port genfile (file-options no-fail))
      (lambda (p) (emit-machine (compile-machine m '()) 'gen-parser p)))
    (load genfile)
    (eval 'gen-parser (environment '(generated gen)))))

(harness-group "the PRNG is reproducible"
  (lambda ()
    (harness-case "the same seed yields the same first draw"
      (lambda ()
        (let-values (((a _sa) (prng-next (make-prng seed) 256))
                     ((b _sb) (prng-next (make-prng seed) 256)))
          (check-equal "same" a b))))))

(harness-group "interpreter and generated agree on every generated machine"
  (lambda ()
    (harness-case "all generated machines verify and agree on all 256 bytes"
      (lambda ()
        (let loop ((i 0) (s (make-prng seed)))
          (when (< i machine-count)
            (let-values (((m s2) (gen-machine s)))
              (let ((v (verify-machine m)))
                (check (string-append "machine " (number->string i) " verifies")
                       (verification-ok? v))
                (when (verification-ok? v)
                  (let ((cm-ref (make-interpreted-machine v))
                        (cm-gen (emit-and-load m i)))
                    (let ((bad 'none))
                      (let bl ((b 0))
                        (when (< b 256)
                          (unless (equal? (rfields cm-ref b) (rfields cm-gen b))
                            (if (eq? bad 'none) (set! bad b)))
                          (bl (+ b 1))))
                      (check-equal
                       (string-append "machine " (number->string i)
                                      " (seed " (number->string seed) ") byte agreement")
                       bad 'none)))))
              (loop (+ i 1) s2))))))))

(harness-finish)
```

- [ ] **Step 4: Add the manifest fragment, the two lanes, and the preset edit.** In `test/CMakeLists.txt`, after Task 2's lanes, add a fragment that extends `BYTE_MACHINE_CORE_EMIT` and includes the two test-support libraries (they live under the harness library root, so they load like `harness.sls`):

```cmake
# --- Milestone 1 Phase 3 Slice B: property generator + differential ----------
byte_machine_add_scheme_lane(
  NAME byte-machine.property.differential.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  TIMEOUT 180)

byte_machine_add_scheme_lane(
  NAME byte-machine.property.differential.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/prng.sls"
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/machine-gen.sls"
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/property-differential-tests.sps"
  TIMEOUT 180)
```

In `CMakePresets.json:79` change the `pr` filter to add `property`:

```json
          "label": "^(harness|unit|verify|differential|property|determinism|portability|example)$"
```

- [ ] **Step 5: Run the property lanes — expect PASS. Fix the generator, not the spec, on any verify/agreement failure.**

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
ctest --preset dev -R 'property.differential' --output-on-failure 2>&1 | tail -20
```

Expected: 2 pass. If a machine fails to verify, the generator produced an invalid graph — constrain it (Step 2 note) until all `machine-count` machines verify. If a machine disagrees on a byte, that is either a real lowering bug (investigate the emitter against the oracle for that seed/index) or an over-broad generator producing a shape Slice A never emitted — narrow the generator to the M1 repertoire and record the finding. Also confirm `property` now runs under `pr`:

```bash
ctest --preset pr -N 2>&1 | grep -c 'property.differential'   # expect 2
```

- [ ] **Step 6: Commit the generator, spec, lanes, and preset.**

```bash
git add test/support/harness/byte-machine/test/prng.sls \
        test/support/harness/byte-machine/test/machine-gen.sls \
        test/common/property-differential-tests.sps test/CMakeLists.txt CMakePresets.json
git commit -m "test: property-based machine generator and interpreter-generated differential (Slice B)"
```

- [ ] **Step 7: Add the witnessing mutation.** Prove the differential is not vacuous under generated machines: mutate the emitter's advance-arm lowering (already witnessed by compile-tests Pass 36, but re-anchor here so the *property* lane is proven to notice divergence on arbitrary machines). In `SchemeMutationSuite.cmake` add a pass whose SPEC is the property lane:

```cmake
# --- Pass 39: property differential is non-vacuous (Slice B) ------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/property-differential-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.property.differential.chez.source
  LABEL "compile: the dispatch byte test is inverted, diverging from the oracle"
  FIND [[(number->string (car tr)) ") "]]
  REPLACE [[(number->string (modulo (+ 1 (car tr)) 256)) ") "]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "byte agreement")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> This mutation shifts every emitted case byte by one, so the generated executor accepts the wrong byte and the differential's `byte agreement` check fails on the first machine whose behaviour depends on the shifted byte. Confirm `FIND` `(number->string (car tr)) ") "` is unique (compile.sls:75). If it survives (some seeds might not distinguish), enlarge `machine-count` or the byte coverage until it is caught, and record why.

- [ ] **Step 8: Bump totals, run the suite, re-measure `release`/`no-scheme`, commit.** Set `EXPECTED_PASSES` `38 → 39`, `EXPECTED_MUTATIONS` `112 → 113` (actuals). Then:

```bash
ctest --preset dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -8
ctest --preset release 2>&1 | tail -3    # expect 61/61
ctest --preset no-scheme 2>&1 | tail -3  # expect 8/8
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: witness the property differential against a lowering mutation (Slice B)"
```

---

### Task 4: Member-2 runtime-export drift guard

**Files:**
- Modify: `src/byte-machine/compile.sls` — export `reserved-member-2` (test-support export) with a comment
- Create: `test/common/reserved-drift-tests.sps`
- Modify: `test/CMakeLists.txt` — two lanes on `BYTE_MACHINE_CORE_COMPILE`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` — drift mutation; bump totals
- Modify: `.decisions/0010-direct-executor-abi.md`, `.plans/milestone-1-phase-3-slice-a-design.md` — dated amendments

**Interfaces:**
- Consumes: `(byte-machine compile)` — now also exporting `reserved-member-2` (the declared runtime-export mirror, compile.sls:39-45); `(rnrs eval)` `environment`; `(only (chezscheme) environment-symbols)`. `reserved-member-2` today is exactly the 15 exports of `(byte-machine runtime)` (runtime.sls:11-17).
- Produces: lane `byte-machine.unit.reserved-drift.chez.{source,aot}` (label `unit`).

- [ ] **Step 1: Measure `environment-symbols` against real Chez before writing the test.** The spec's correctness hinges on what `(environment-symbols (environment '(byte-machine runtime)))` returns. Measure it:

```bash
CHEZ=$(sed -n 's/.*BYTE_MACHINE_CHEZ_EXECUTABLE:[A-Z]*=//p' build/dev/CMakeCache.txt)
"$CHEZ" --libdirs "src" -q <<'EOF'
(import (rnrs) (rnrs eval) (only (chezscheme) environment-symbols))
(for-each (lambda (s) (display s)(newline))
          (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                     (environment-symbols (environment '(byte-machine runtime)))))
EOF
```

Expected: exactly the 15 runtime exports (`make-compiled-machine`, `compiled-machine?`, `byte-machine-make-compiled-machine/v1`, `byte-machine-make-feed-outcome/v1`, `make-parser`, `parser?`, `parser-feed!`, `parser-result?`, `parser-result-status`, `parser-result-next`, `parser-result-consumed`, `parser-result-stream-offset`, `parser-result-error`, `callback-continue`, `callback-pause`). **Record the exact output in the task report.** If Chez returns extra symbols (imported `(rnrs)` names leaking through), the spec must filter to the declared surface — Step 3's comparison then intersects with a known non-runtime marker set, and the report states the filter and why.

- [ ] **Step 2: Export `reserved-member-2` from compile.sls.** Modify `src/byte-machine/compile.sls`. Add to the export list (compile.sls:11-12) and annotate the definition:

```scheme
  (export compile-machine compilation-ok? compilation-diagnostics
          render-machine emit-machine
          reserved-member-2)          ; test-support: the drift guard (§3.4) reads it
```

Add a comment above `reserved-member-2` (compile.sls:39):

```scheme
  ;; The hand-maintained mirror of (byte-machine runtime)'s exports. Exported
  ;; solely so reserved-drift-tests.sps can assert it against the runtime's actual
  ;; environment-symbols: a new runtime export not added here would let the emitter
  ;; accept a binding that collides with it (Slice B; Slice A design §6).
```

- [ ] **Step 3: Write the drift spec.** Create `test/common/reserved-drift-tests.sps`. It sorts both the declared mirror and the live exports and asserts set-equality:

```scheme
;;; The member-2 runtime-export drift guard (Slice A design §6; parent §9.2, §20).
;;; compile.sls's reserved-member-2 must exactly mirror (byte-machine runtime)'s
;;; exports; otherwise the emitter could accept a binding that collides with a
;;; runtime export. This asserts the two sets are equal. It passes today (they are
;;; identical); its RED is the mutation that drops an entry (SchemeMutationSuite
;;; Pass 40). If a /v2 export is ever added, both lists change together or this
;;; lane fails.
(import (rnrs) (rnrs eval)
        (only (chezscheme) environment-symbols)
        (byte-machine test harness)
        (byte-machine compile))

(harness-begin "unit.reserved-drift")

(define (sorted syms)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) syms))
(define declared (sorted reserved-member-2))
(define live (sorted (environment-symbols (environment '(byte-machine runtime)))))

(harness-group "reserved member 2 mirrors the runtime exports"
  (lambda ()
    (harness-case "the declared set equals the live runtime export set"
      (lambda ()
        (check-equal "no drift between reserved-member-2 and (byte-machine runtime)"
                     declared live)))))

(harness-finish)
```

> If Step 1 showed extra symbols, replace `live` with the filtered form measured there (e.g. intersect with a `runtime-surface` predicate) and note it in the header comment.

- [ ] **Step 4: Register the two lanes.** In `test/CMakeLists.txt`, after Task 3's lanes. The manifest is `BYTE_MACHINE_CORE_COMPILE` (compile + its deps); the runtime library is loaded because the spec's `environment` reference resolves `(byte-machine runtime)` from the src root — add it explicitly to the manifest so the lane declares everything it loads:

```cmake
# --- Milestone 1 Phase 3 Slice B: member-2 runtime-export drift guard ---------
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.reserved-drift.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls"
          "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.reserved-drift.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls"
          "${CMAKE_SOURCE_DIR}/test/common/reserved-drift-tests.sps"
  TIMEOUT 120)
```

> `runtime.sls` is not in `BYTE_MACHINE_CORE_COMPILE` (compile does not depend on runtime — Slice A design §3.1), so it is named explicitly. Its basename `runtime.sls` is unique within the lane. If the basename-uniqueness check or the manifest fingerprint objects, confirm no other manifest entry shares the basename (none does).

- [ ] **Step 5: Run the drift lanes — expect PASS (witness-strengthening).**

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
ctest --preset dev -R 'reserved-drift' --output-on-failure
```

Expected: 2 pass (the sets are identical today). A failure means Step 1's measurement and the declared list disagree — reconcile against the measured `environment-symbols` output, not by editing the expectation blindly.

- [ ] **Step 6: Commit the export, spec, and lanes.**

```bash
git add src/byte-machine/compile.sls test/common/reserved-drift-tests.sps test/CMakeLists.txt
git commit -m "test: member-2 runtime-export drift guard via environment-symbols (Slice B)"
```

- [ ] **Step 7: Add the drift mutation.** Drop a grammar-invalid entry (so only the drift set-equality notices — `valid-binding?` behaviour is unchanged because `parser-feed!` is grammar-rejected regardless). In `SchemeMutationSuite.cmake`:

```cmake
# --- Pass 40: member-2 drift guard (Slice B) ---------------------------------
byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/reserved-drift-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.reserved-drift.chez.source
  LABEL "compile: reserved-member-2 drops a runtime export (silent drift)"
  FIND [[make-parser parser? parser-feed!]]
  REPLACE [[make-parser parser?]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "drift")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

> `FIND` `make-parser parser? parser-feed!` occurs once in compile.sls (line 42). After the drop, `declared` has 14 symbols and `live` has 15; `check-equal` fails and prints its `what` (`"no drift between reserved-member-2 and (byte-machine runtime)"`, which contains `drift`). Confirm the substring matches what `check-equal` prints (it prints `what` then the expected/got values).

- [ ] **Step 8: Bump totals, run the suite, re-measure, commit.** Set `EXPECTED_PASSES` `39 → 40`, `EXPECTED_MUTATIONS` `113 → 114` (actuals):

```bash
ctest --preset dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -8
ctest --preset release 2>&1 | tail -3    # expect 63/63
git add test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: witness member-2 drift by dropping a runtime export (Slice B)"
```

- [ ] **Step 9: Amend the decision record and the Slice A note.** In `.decisions/0010-direct-executor-abi.md`, append under Consequences a dated note; in `.plans/milestone-1-phase-3-slice-a-design.md` §6, update the "Runtime-export drift test — deferred to Slice B" paragraph. Exact text:

0010 (append after the last Consequences bullet):

```markdown
## 2026-08-23 (Slice B) — drift guard shipped without /v2

Slice B implements the member-2 runtime-export drift guard
(reserved-drift-tests.sps: `environment-symbols` of `(byte-machine runtime)`
asserted equal to `compile.sls`'s exported `reserved-member-2`, witnessed by a
mutation that drops an entry). It ships **no `/v2` export**: the guard is made
load-bearing by that mutation, not by the arrival of a new export, so item 5's
`/v2` remains gated on benchmark evidence exactly as written above.
```

Slice A design §6, replace the last sentence of the "Runtime-export drift test — deferred to Slice B" paragraph ("It is therefore **deferred to the Slice B plan** … rather than being dropped by omission.") with:

```markdown
It was **implemented in Slice B** as `reserved-drift-tests.sps` — set-equality of
`(environment-symbols (environment '(byte-machine runtime)))` against the exported
`reserved-member-2`, witnessed by a mutation that drops one entry — **without** a
`/v2` export: the mutation, not a new export, is what makes the guard load-bearing
(decision 0010, 2026-08-23 note).
```

- [ ] **Step 10: Commit the doc amendments.**

```bash
git add .decisions/0010-direct-executor-abi.md .plans/milestone-1-phase-3-slice-a-design.md
git commit -m "docs: record the member-2 drift guard shipped without /v2 (Slice B)"
```

---

### Task 5: Delete the M0 placeholder libraries

**Files:**
- Delete: `src/byte-machine/placeholder.sls`, `src/byte-machine/placeholder-consumer.sls`, `test/common/placeholder-tests.sps`, `test/common/placeholder-identity-tests.sps`
- Modify: `test/CMakeLists.txt` — remove the three placeholder lanes (source, aot, identity source + identity aot)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` — remove/adjust any placeholder pass(es); re-measure totals
- Modify: `CHANGELOG.md` — noted in Task 7

**Interfaces:**
- Consumes: nothing new. Removes lanes `byte-machine.portability.placeholder.chez.source` (CMakeLists:610-617), `byte-machine.portability.placeholder-identity.chez.source` (631-639), `byte-machine.portability.placeholder-identity.chez.aot` (570-578).
- Produces: `release` drops by 4 lanes (placeholder source, identity source, identity aot = 3 lanes actually — confirm count with `ctest -N`).

- [ ] **Step 1: Inventory every reference before deleting.** Placeholders are referenced by lanes, the mutation suite (the "ownership" mutation described at CMakeLists:619-630 lives in SchemeMutationSuite.cmake), and possibly comments. Enumerate:

```bash
rg -n 'placeholder' test/CMakeLists.txt
rg -n 'placeholder' test/support/cmake/SchemeMutationSuite.cmake
rg -n 'placeholder' --files-with-matches src test docs
ctest --preset release -N 2>&1 | grep -c placeholder    # lane count to lose
```

Record the exact lane count and every mutation pass that names a placeholder file.

- [ ] **Step 2: Remove the lanes.** In `test/CMakeLists.txt`, delete the three `byte_machine_add_scheme_lane` blocks that name placeholder programs (the AOT identity lane at 570-578, the source placeholder lane at 610-617, and the source identity lane at 631-639), along with their explanatory comment blocks. Leave the surrounding harness/provenance structure intact.

- [ ] **Step 3: Remove the placeholder mutation pass(es).** In `SchemeMutationSuite.cmake`, delete the pass(es) that mutate `placeholder-consumer.sls`/`placeholder.sls` (the ownership mutation and any siblings found in Step 1). Update the running-total arithmetic comment. This changes `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` — do not set the new values yet; measure in Step 6.

- [ ] **Step 4: Delete the four files.**

```bash
git rm src/byte-machine/placeholder.sls src/byte-machine/placeholder-consumer.sls \
       test/common/placeholder-tests.sps test/common/placeholder-identity-tests.sps
```

- [ ] **Step 5: Configure — expect a clean configure and no dangling references.**

```bash
cmake --preset dev 2>&1 | tail -5     # expect no error about a missing placeholder source
rg -n 'placeholder' src test | grep -v '\.so:' || echo "no source references remain"
```

Expected: configure succeeds; no `.sls`/`.sps`/CMake reference to a placeholder remains (build-tree `.so` copies under `build/` are stale artifacts, ignore them; `make clean` clears them).

- [ ] **Step 6: Re-measure all suites and set the new mutation totals.**

```bash
cmake --build --preset dev >/dev/null
ctest --preset release 2>&1 | tail -3     # expect 63 - (lanes removed)
ctest --preset no-scheme 2>&1 | tail -3   # expect 8/8 (placeholders were chez lanes)
ctest --preset dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -8
```

Set `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` to the measured post-removal values. If the mutation suite reports a mismatch, the arithmetic comment and the constants must match what actually ran — reconcile to the measured numbers.

- [ ] **Step 7: Commit.**

```bash
git add -A
git commit -m "refactor: delete the M0 placeholder libraries, superseded by the emitter (Slice B)"
```

Record the measured `release` and mutation numbers.

---

### Task 6: The confirmed Slice A Minors

**Files:**
- Modify: `src/byte-machine/private/normal-ir.sls` — T1a (else-guards + comment), T1c (split lowering/encoding)
- Modify: `test/common/normal-ir-tests.sps` — T1b (direct `normal-state-id` assertion)
- Modify: `src/byte-machine/runtime.sls` — T2 (named accessors in `make-parser` v1 branch)
- Create: `test/support/harness/byte-machine/test/one-byte-machine.sls` — T4 shared fixture
- Modify: `test/common/differential-one-byte-tests.sps`, `test/common/example-one-byte-tests.sps` — T4 use the shared fixture
- Modify: `test/CMakeLists.txt` — T4 add the fixture to the differential + example manifests
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` — T1a else-guard mutations; T3 Pass 36 retarget

**Interfaces:**
- Consumes: existing normal-ir, runtime, differential/example specs. `normalize-machine` (normal-ir.sls:60) currently mixes lowering (build entry+states) and encoding (FNV over the canonical bytes); the golden fingerprint `11963406767470843108` must not move.
- Produces: `(byte-machine test one-byte-machine)` exporting `make-one-byte-machine` → machine.

- [ ] **Step 1 (T1c): Write the fingerprint-invariance guard first.** `normal-ir-tests.sps` already asserts the golden (`the IR fingerprint is the measured golden value`, line 54). Run it before touching normalize so the baseline is green:

```bash
ctest --preset dev -R 'unit.normal-ir' --output-on-failure
```

Expected: pass, golden `11963406767470843108`.

- [ ] **Step 2 (T1c): Split `normalize-machine` into lowering and encoding.** In `src/byte-machine/private/normal-ir.sls`, replace the single `normalize-machine` (lines 60-113) with two helpers and a thin composite. The byte sequence fed to `fnv1a-64` is byte-for-byte the same, so the fingerprint is unchanged:

```scheme
  ;; Lowering: verified machine -> (values entry states-vector). No encoding.
  (define (lower-machine machine)
    (let* ((nodes (machine-nodes machine))
           (name->id (let loop ((ns nodes) (i 0) (acc '()))
                       (if (null? ns) (reverse acc)
                           (loop (cdr ns) (+ i 1) (cons (cons (node-name (car ns)) i) acc)))))
           (id-of (lambda (nm) (cdr (assq nm name->id))))
           (errcode (lambda (nm)
                      (let loop ((es (machine-errors machine)))
                        (if (eq? (error-declaration-name (car es)) nm)
                            (error-declaration-code (car es)) (loop (cdr es))))))
           (entry (id-of (machine-entry machine)))
           (states (list->vector
                    (let loop ((ns nodes) (i 0) (acc '()))
                      (if (null? ns) (reverse acc)
                          (let ((n (car ns)))
                            (loop (cdr ns) (+ i 1)
                                  (cons
                                   (cond
                                     ((byte-dispatch-node? n)
                                      (let ((trs (list-sort (lambda (a b) (< (car a) (car b)))
                                                   (map (lambda (c)
                                                          (let ((b (exact-byte-matcher-byte (byte-case-matcher c)))
                                                                (e (byte-case-edge c)))
                                                            (list b (id-of (edge-target e)) (edge-mode e))))
                                                        (byte-dispatch-node-cases n))))
                                            (fb (byte-dispatch-node-fallback n)))
                                        (vector ns-tag 'dispatch i trs
                                                (cons (id-of (edge-target fb)) (edge-mode fb)) #f)))
                                     ((stop-node? n) (vector ns-tag 'stop i #f #f #f))
                                     ((error-node? n) (vector ns-tag 'error i #f #f (errcode (error-node-error-name n))))
                                     ;; The M1 repertoire is exactly these three node kinds; EOF
                                     ;; execution (a fourth kind) is Milestone 2. A future kind
                                     ;; reaching here must fail loudly, not lower to nothing.
                                     (else (assertion-violation 'normalize-machine "unknown node kind" n)))
                                   acc)))))))) 
      (values entry states)))

  ;; Encoding: (entry, states) -> canonical bytes (decision 0009 layout).
  (define (encode-normal entry states)
    (call-with-bytevector-output-port
     (lambda (p)
       (put-u8 p 1)
       (put-u32be p entry)
       (put-u32be p (vector-length states))
       (let loop ((i 0))
         (when (< i (vector-length states))
           (let ((s (vector-ref states i)))
             (case (normal-state-kind s)
               ((dispatch)
                (put-u8 p 0)
                (let ((trs (normal-dispatch-transitions s)))
                  (put-u16be p (length trs))
                  (for-each (lambda (tr)
                              (put-u8 p (car tr)) (put-u32be p (cadr tr))
                              (put-u8 p (mode->byte (caddr tr)))) trs))
                (let ((fb (normal-dispatch-fallback s)))
                  (put-u32be p (car fb)) (put-u8 p (mode->byte (cdr fb)))))
               ((stop) (put-u8 p 1))
               ((error) (put-u8 p 2) (put-symbol p (normal-error-code s)))
               (else (assertion-violation 'normalize-machine "unknown state kind"
                                          (normal-state-kind s)))))
           (loop (+ i 1)))))))

  (define (normalize-machine machine)
    (let-values (((entry states) (lower-machine machine)))
      (make-normal-machine entry states (fnv1a-64 (encode-normal entry states)))))
```

- [ ] **Step 3 (T1c): Prove the fingerprint did not move.**

```bash
cmake --build --preset dev >/dev/null
ctest --preset dev -R 'unit.normal-ir|unit.compile|differential.one-byte' --output-on-failure
```

Expected: all pass; the golden case still reports `11963406767470843108`. If it moved, the split changed the byte sequence — diff the encoder against the original field order; do not update the golden.

- [ ] **Step 4 (T1b): Add the direct `normal-state-id` assertion.** In `test/common/normal-ir-tests.sps`, inside the `"the one-byte machine"` group (after the `"three states…"` case, ~line 38), add:

```scheme
    (harness-case "state ids are the declaration indices"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "id 0" (normal-state-id (vector-ref s 0)) 0)
          (check-equal "id 1" (normal-state-id (vector-ref s 1)) 1)
          (check-equal "id 2" (normal-state-id (vector-ref s 2)) 2))))
```

- [ ] **Step 5 (T2): Named accessors in runtime `make-parser`.** In `src/byte-machine/runtime.sls`, the v1 branch of `make-parser` (lines 79-81) uses `(vector-ref compiled-machine 2/3)`. Add two private accessors beside the v1 constructor (after line 47) and use them:

```scheme
  (define (compiled-machine-v1-feed cm) (vector-ref cm 2))
  (define (compiled-machine-v1-entry-state cm) (vector-ref cm 3))
```

and rewrite the `else` branch of `make-parser` (lines 79-81):

```scheme
        (let ((feed (compiled-machine-v1-feed compiled-machine))
              (entry-state (compiled-machine-v1-entry-state compiled-machine)))
          (vector parser-tag 'v1 feed entry-state 0 #f))))
```

- [ ] **Step 6 (T2): Prove runtime + differential still pass.**

```bash
cmake --build --preset dev >/dev/null
ctest --preset dev -R 'unit.runtime|differential.one-byte|example.one-byte' --output-on-failure
```

Expected: pass.

- [ ] **Step 7 (T4): Create the shared fixture library.** Create `test/support/harness/byte-machine/test/one-byte-machine.sls`:

```scheme
;;; The fixed one-byte proving machine, shared by the differential and example
;;; lanes so the graph descriptor is written once (Slice A Minor T4). Built only
;;; through (byte-machine graph).
(library (byte-machine test one-byte-machine)
  (export make-one-byte-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-one-byte-machine)
    (let ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
          (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)))
      (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
        (list (make-byte-dispatch-node 'start
                (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) #f #f)
              (make-stop-node 'stop #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))))
```

- [ ] **Step 8 (T4): Use it in the two specs.** In `test/common/differential-one-byte-tests.sps`, add `(byte-machine test one-byte-machine)` to the imports (line 5-12) and replace the `eof-decl`/`rej-decl`/`one-byte` block (lines 22-31) with:

```scheme
(define one-byte (make-one-byte-machine))
```

Do the same in `test/common/example-one-byte-tests.sps` (imports line 6-12; fixture lines 22-31).

- [ ] **Step 9 (T4): Add the fixture to both manifests.** In `test/CMakeLists.txt`, add the fixture library to the `SOURCES` of all four differential/example lanes (source+aot each), right after `${BYTE_MACHINE_CORE_EMIT}`:

```cmake
          "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/one-byte-machine.sls"
```

- [ ] **Step 10 (T4): Rebuild and run the differential + example lanes — expect PASS.**

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
ctest --preset dev -R 'differential.one-byte|example.one-byte' --output-on-failure
```

Expected: 4 pass. A manifest/fingerprint error means the fixture was added to the lane's `SOURCES` but not imported by the program, or vice-versa — the manifest must name exactly what the program loads.

- [ ] **Step 11 (T1a + T3): Witness the new else-guards; retarget Pass 36.** T1a's else-guards are unreachable today (only three node kinds exist), so a hollow mutation would be an unwitnessable survivor — instead, do **not** add a mutation for the unreachable guards; record them as by-inspection safety in the normal-ir header comment (close-demonstrated-gaps rule: they cannot be exercised until a fourth node kind exists in M2). For **T3**, retarget the Pass 36 "unverified rendered anyway" mutation from the loose `"ok"` to `"not ok"` and confirm it still catches. In `SchemeMutationSuite.cmake`, change line 2280:

```cmake
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "not ok")
```

Then re-run only that pass's lane logic through the whole suite (Step 12) and confirm the mutant still exits 1 with `not ok` in the output. If the mutant's output does not contain `not ok`, revert to `"ok"` and record why (the tighter string was not observed).

- [ ] **Step 12: Run the whole mutation suite and the full matrix.**

```bash
ctest --preset dev -R 'scheme-mutation' --output-on-failure 2>&1 | tail -8
ctest --preset release 2>&1 | tail -3
ctest --preset no-scheme 2>&1 | tail -3
```

Expected: suite green at the current totals (T1a adds no mutation; T3 retargets one, count unchanged); `release` unchanged from Task 5; `no-scheme` 8/8.

- [ ] **Step 13: Add the T1a header comment and commit the Minors.** In `normal-ir.sls`, add above `lower-machine` a one-line note that the else-guards are unreachable-today safety for a future M2 node kind. Commit:

```bash
git add src/byte-machine/private/normal-ir.sls test/common/normal-ir-tests.sps \
        src/byte-machine/runtime.sls \
        test/support/harness/byte-machine/test/one-byte-machine.sls \
        test/common/differential-one-byte-tests.sps test/common/example-one-byte-tests.sps \
        test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "refactor: land the confirmed Slice A Minors (T1a-c, T2, T3, T4)"
```

---

### Task 7: Close-out

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.plans/milestone-1-design.md` §6 (mark the Phase-3 exit items delivered, if it tracks status) — verify wording only, edit if a status line exists
- Verify: the Milestone-1 exit criteria (milestone-1-design.md §6 "Exit (full Milestone 1)")

**Interfaces:** none (documentation + measurement).

- [ ] **Step 1: Add the CHANGELOG entry.** In `CHANGELOG.md`, under the appropriate Added/Changed/Removed sections, add Slice B: the D6 golden-determinism proof, the D7 identifier-repertoire + binary-LF proof, the property-based generator and `property` preset wiring, the member-2 drift guard, the placeholder-library removal, and the Minors. State that `/v2` was **not** added (benchmark-gated, decision 0010). Follow the file's existing entry style (check the Slice A entry as the template).

- [ ] **Step 2: Confirm the Milestone-1 Phase-3 exit criteria.** Re-read milestone-1-design.md §6 "Exit (full Milestone 1)" and check each against the tree: all 256 byte values tested (differential + property); interpreter≡generated match (differential + property); a graph descriptor constructed/verified/compiled/emitted/loaded/run across public boundaries in both lanes (example lane); invalid names/targets/overlap/fallback/terminals rejected (verify-tests + D7 repertoire). Record the evidence lane for each in the task report.

- [ ] **Step 3: Full clean re-measurement.**

```bash
make clean 2>/dev/null; rm -rf build
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null
ctest --preset release --output-on-failure 2>&1 | tail -3
ctest --preset no-scheme --output-on-failure 2>&1 | tail -3
ctest --preset dev -R 'scheme-mutation|cmake-mutation' --output-on-failure 2>&1 | tail -12
```

Record the final measured `release`, `no-scheme`, Scheme-mutation, and CMake-mutation numbers. These are the numbers the whole-branch review checks; they must match `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`.

- [ ] **Step 4: Commit the close-out.**

```bash
git add CHANGELOG.md .plans/milestone-1-design.md
git commit -m "docs: Milestone 1 Phase 3 Slice B close-out — CHANGELOG and exit criteria (Slice B)"
```

- [ ] **Step 5: Whole-branch review handoff.** Do not open the PR here. The controller runs the final whole-branch review (opus), then `finishing-a-development-branch` opens the PR for the user's squash-merge, per the repo's closing ritual.

---

## Self-Review

**Spec coverage** (design §2 / §3 → task):
- D6 determinism hardening → Task 2 (golden bytes, emit-twice, compile-and-run, both lanes). ✓
- D7 repertoire + binary LF → Task 1. ✓
- Property generator + `property` preset wiring → Task 3. ✓
- Member-2 drift test → Task 4. ✓
- Placeholder deletion → Task 5. ✓
- Confirmed Minors T1a/b/c, T2, T3, T4 → Task 6; T1d + emission-metadata accessors deferred with a note (design §2; Task 6 Step 11 records the T1a rationale; note T1d in Task 7 CHANGELOG as an open scale item). ✓
- Decision 0010 / Slice A §6 amendments → Task 4 Step 9. ✓
- Close-out / re-measure / exit criteria → Task 7. ✓

**Placeholder scan:** No "TBD"/"TODO". Two places defer to measurement by design (Task 4 Step 1 `environment-symbols`; every mutation count "re-measure before bump") — these are explicit measurement steps with commands, not vague placeholders. The mutation counts in the header table are labelled "intended, re-measure," matching the repo's re-measure discipline.

**Type/name consistency:** `make-one-byte-machine` (Task 6) used consistently in both specs and the fixture. `reserved-member-2` exported (Task 4) and read by `reserved-drift-tests.sps` — names match. `gen-machine`/`make-prng`/`prng-next` defined in Task 3 libraries and used in the property spec — signatures match (state-threading `(values … state')`). Lane names use the derived-label components (`verify`, `determinism`, `property`, `unit`) that exist in `BYTE_MACHINE_TEST_LAYERS`. `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` bumped in every task that adds/removes a pass, re-read from the suite.

**Known reviewer-bait (plan-mandated, flagged for the final review):**
- Tasks 1–4 lanes are witness-strengthening (pass on first run); their RED is the mutation, matching the 5b-remainder precedent for immediate-pass spec cases.
- Task 6 T1a adds no mutation (unreachable else-guards) — recorded as by-inspection safety per the close-demonstrated-gaps rule, not a hollow survivor.
- Task 2's golden mutation depends on the staged program reading `BYTE_MACHINE_GOLDEN_FILE`; if the suite scrubs env, wire the path through the suite's own `ENVIRONMENT` mechanism rather than declaring a survivor (Step 6/7 note).
