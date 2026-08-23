# Milestone 1 Phase 3 Slice A — Emitter and Differential — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a complete importable R6RS `.sls` parser library from a verified one-byte machine and prove, across all 256 byte values, that the generated parser behaves identically to the Phase 2 reference interpreter.

**Architecture:** A pure normalizer lowers the verified source IR to a canonical normalized IR carrying a 64-bit FNV-1a **IR fingerprint** (`(byte-machine private normal-ir)`). A pure emitter renders that to importable `.sls` source text and writes it to a binary port (`(byte-machine compile)`). Generated code is a **direct resumable executor** (a `case` over numeric state ids, byte test inline, loop state in locals) driven through a new versioned runtime ABI, `byte-machine-make-compiled-machine/v1`, that `parser-feed!` dispatches to alongside the untouched interpreter `op` path. Differential and end-to-end tests emit the library at run time, `load` it, obtain its compiled-machine by `eval`/`environment`, and run it through the shared `make-parser`/`parser-feed!` API — which reuses the resident `(byte-machine runtime)` instance, so tags and singletons are shared across the boundary.

**Tech Stack:** Chez Scheme (R6RS, `.sls`/`.sps`), CMake + CTest presets, the in-tree portable test harness `(byte-machine test harness)`, the CMake Scheme mutation suite.

This plan implements **Slice A** of Phase 3, per
[milestone-1-phase-3-slice-a-design.md](./milestone-1-phase-3-slice-a-design.md).
Slice B (D6 cross-cell/cross-process determinism hardening, D7 exhaustive
identifier proofs, the property-based machine generator, and deletion of the M0
placeholder libraries) gets its own plan after this slice lands.

## Global Constraints

- **Chez-only, plain R6RS.** No second runtime; no fixnum/unsafe/non-R6RS identifiers in emitted or emitter code without benchmark evidence (decision 0005). Full R6RS is available.
- **Inline libraries, no includes.** Every `.sls`/`.sps` owns its full text; `rg '\(include' src test` must stay empty (decision 0006).
- **No `define-record-type`.** Records are tagged vectors behind accessors; the tag is a freshly-allocated `(vector 'sym)` so a second copy gets a second identity — matching the existing product code.
- **No new dependencies.** No SRFI, no package manager.
- **Functional core / imperative shell.** The normalizer, the reserved-binding checks, and the source writer are pure; the only side effect is `emit-machine`'s `put-bytevector` to the caller-supplied binary port.
- **Compare structure, never prose.** Tests assert diagnostic codes, statuses, error codes, fingerprints, and rendered-text substrings — never rendered exception text.
- **Emitter output.** `emit-machine` writes only to the supplied binary output port. The library name is derived `(generated <machine-name>)` (parent §9.2 gives `render-machine`/`emit-machine` only a `binding` argument; a custom public name is a wrapper, decision 0008 §4). The `binding` is caller-supplied and validated against `[a-z][a-z0-9-]*` and the reserved-output-binding set (members 1, 2, 3) before any bytes are written.
- **IR fingerprint, named.** The new hash is the **IR fingerprint** (64-bit FNV-1a over the canonical normalized IR); never a bare "fingerprint", and it must not touch the harness content-fingerprint library `(byte-machine test fingerprint)` (decision 0009).
- **TDD.** Failing test first, prove RED, implement, prove GREEN, then a mutation pass, then commit. One Conventional-Commits commit per task.
- **Mutation discipline.** Every decision gets a mutation an owning spec catches, asserting a measured failure signature (`EXPECT_STATUS` + `EXPECT_OUTPUT_MATCHES`), never a bare nonzero exit. After adding any exit path, re-run the **whole** mutation suite (a new exit can silently disarm an existing mutation). Update `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` and their arithmetic comment in the same commit as the passes they cover. Keep the `no-scheme` preset green at 8/8.
- **Baselines to hold** (re-measured on merged `main`, Darwin arm64, Chez 10.4.1): `release` 47/47, `no-scheme` 8/8, scheme mutation suite **34 passes / 87 mutations**, CMake mutation suite 1/72, zero-include gate clean. Re-read the live `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` before bumping; never quote a plan number as if measured.

## File Structure

| File | Responsibility |
| --- | --- |
| `src/byte-machine/private/normal-ir.sls` | **Create.** Normalized IR data + `normalize-machine` + canonical encoding + FNV-1a IR fingerprint. Pure; depends only on `(byte-machine private ir)`. |
| `src/byte-machine/runtime.sls` | **Modify.** Add `byte-machine-make-compiled-machine/v1`, `byte-machine-make-feed-outcome/v1`, the `op`/`v1` compiled-machine variants, and `parser-feed!` variant dispatch. Correct the header comment. Stays a standalone library (no new import). |
| `src/byte-machine/compile.sls` | **Create.** `(byte-machine compile)`: `compile-machine`, `compilation-ok?`, `compilation-diagnostics`, `render-machine`, `emit-machine`; the reserved-binding set; the canonical source writer/template. |
| `test/common/normal-ir-tests.sps` | **Create.** Unit tests for the normalizer, the golden IR fingerprint, entry/sort/error-code structure. |
| `test/common/runtime-tests.sps` | **Modify.** Add a `/v1` ABI group. |
| `test/common/compile-tests.sps` | **Create.** Unit tests for compile/render/emit, options and binding validation, and rendered-text structure. |
| `test/common/differential-one-byte-tests.sps` | **Create.** Emit → load → run the generated one-byte parser and compare to the interpreter across all 256 bytes. |
| `test/common/example-one-byte-tests.sps` | **Create.** The §9.6 documented end-to-end walkthrough. |
| `test/CMakeLists.txt` | **Modify.** New core-manifest fragments and lane pairs. |
| `test/support/cmake/SchemeMutationSuite.cmake` | **Modify.** New Pass 35 (normal-ir) and Pass 36 (compile); extend Pass 32 (runtime); bump totals. |
| `docs/decisions/0010-direct-executor-abi.md` | **Create.** Records the direct-executor ABI + the retired runtime comment. |
| `CHANGELOG.md` | **Modify.** Slice A entry. |

Dependency direction (parent §7.2): `private conditions ← private ir ← private normal-ir`; `(byte-machine compile)` depends on `verify`, `private ir`, `private normal-ir`; it does **not** depend on `runtime` (it emits text that imports runtime). The interpreter is untouched.

Lane-manifest fragments to add in `test/CMakeLists.txt`, in dependency order beside the existing ones:

```cmake
# Normalizer: reads the verified IR through graph+verify, produces the normalized IR.
set(BYTE_MACHINE_CORE_NORMAL_IR
    ${BYTE_MACHINE_CORE_VERIFY}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/normal-ir.sls")

# The emitter reads the normalized IR and re-verifies internally.
set(BYTE_MACHINE_CORE_COMPILE
    ${BYTE_MACHINE_CORE_NORMAL_IR}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/compile.sls")

# Differential + example: build (graph), verify, interpret (oracle), run (runtime),
# and emit (compile). CORE_ALL already unites verify+runtime+interpret.
set(BYTE_MACHINE_CORE_EMIT
    ${BYTE_MACHINE_CORE_ALL}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/normal-ir.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/compile.sls")
```

All basenames within each fragment are distinct (`conditions ir graph verify runtime interpret normal-ir compile`), so `byte_machine_lane_duplicate_basenames` stays satisfied. The generated `.sls` is a run-time artifact written under `BYTE_MACHINE_TEST_TMPDIR`; it is **never** in a `SOURCES` manifest (it does not exist at configure time, and `byte_machine_add_scheme_lane` requires every `SOURCES` entry to exist).

---

### Task 1: Normalizer, normalized IR, and the IR fingerprint

**Files:**
- Create: `src/byte-machine/private/normal-ir.sls`
- Test: `test/common/normal-ir-tests.sps`
- Modify: `test/CMakeLists.txt` (add `BYTE_MACHINE_CORE_NORMAL_IR` and the lane pair)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 35)

**Interfaces:**
- Consumes: `(byte-machine private ir)` accessors (`machine-nodes`, `machine-entry`, `machine-errors`, `byte-dispatch-node?`, `byte-dispatch-node-cases`, `byte-dispatch-node-fallback`, `byte-case-matcher`, `byte-case-edge`, `exact-byte-matcher-byte`, `edge-target`, `edge-mode`, `stop-node?`, `error-node?`, `error-node-error-name`, `error-declaration-name`, `error-declaration-code`, `node-name`); `(byte-machine verify)` (`verify-machine`, `verification-ok?`, `verification-machine`) — used by the test to produce a verified machine.
- Produces:
  - `(normalize-machine machine)` → normal-machine. `machine` is an already-verified machine (the caller passes `(verification-machine v)`).
  - `(normal-machine? x)`, `(normal-machine-entry m)` → integer state id, `(normal-machine-states m)` → vector of normal-state indexed by id, `(normal-machine-fingerprint m)` → 64-bit integer.
  - `(normal-state-kind s)` → `'dispatch|'stop|'error`, `(normal-state-id s)` → integer.
  - `(normal-dispatch-transitions s)` → list of `(byte target-id mode)` ascending by byte; `(normal-dispatch-fallback s)` → `(target-id . mode)`; `(normal-error-code s)` → symbol.

- [ ] **Step 1: Write the failing test** — `test/common/normal-ir-tests.sps`

```scheme
;;; The normalizer lowers a verified machine to numeric-state normalized IR and a
;;; deterministic IR fingerprint. The one-byte machine pins the fingerprint
;;; algorithm (a golden value); a second, out-of-order machine pins the entry
;;; assignment and transition sort, which one dispatch case cannot witness.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine private normal-ir))

(harness-begin "unit.normal-ir")

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

(define (normalize m) (normalize-machine (verification-machine (verify-machine m))))
(define n1 (normalize one-byte))

(harness-group "the one-byte machine"
  (lambda ()
    (harness-case "entry is the first node's id"
      (lambda () (check-equal "entry" (normal-machine-entry n1) 0)))
    (harness-case "three states, in declaration order"
      (lambda ()
        (let ((s (normal-machine-states n1)))
          (check-equal "count" (vector-length s) 3)
          (check-equal "state 0 kind" (normal-state-kind (vector-ref s 0)) 'dispatch)
          (check-equal "state 1 kind" (normal-state-kind (vector-ref s 1)) 'stop)
          (check-equal "state 2 kind" (normal-state-kind (vector-ref s 2)) 'error))))
    (harness-case "the dispatch state lowers its case and fallback to ids"
      (lambda ()
        (let ((d (vector-ref (normal-machine-states n1) 0)))
          (check-equal "transitions" (normal-dispatch-transitions d) '((0 1 advance)))
          (check-equal "fallback" (normal-dispatch-fallback d) '(2 . reexecute)))))
    (harness-case "the error state carries the resolved error CODE, not its name"
      (lambda ()
        (check-equal "code" (normal-error-code (vector-ref (normal-machine-states n1) 2))
                     'unexpected-byte)))
    ;; Golden value: measured against this exact encoding (format tag 1; entry and
    ;; state-count as u32be; per dispatch state u16be transition count then each
    ;; (u8 byte, u32be target, u8 mode) ascending by byte, then u32be fallback
    ;; target + u8 mode; stop = one tag byte; error = tag byte + u16be code-length
    ;; + UTF-8 code bytes) run through FNV-1a. A change to any FNV constant, the
    ;; XOR/multiply, or the field layout moves this number.
    (harness-case "the IR fingerprint is the measured golden value"
      (lambda ()
        (check-equal "fingerprint" (normal-machine-fingerprint n1)
                     11963406767470843108)))
    (harness-case "normalization is deterministic"
      (lambda ()
        (check-equal "same fingerprint twice"
                     (normal-machine-fingerprint (normalize one-byte))
                     (normal-machine-fingerprint n1))))))

;; Entry is the second node; the dispatch node lists byte 5 before byte 2.
(define two
  (make-machine 'two 'go '() '() '() (list eof-decl rej-decl)
    (list (make-stop-node 'halt #f)
          (make-byte-dispatch-node 'go
            (list (make-byte-case (make-exact-byte-matcher 5) (make-edge 'halt 'advance) #f)
                  (make-byte-case (make-exact-byte-matcher 2) (make-edge 'halt 'advance) #f))
            (make-edge 'bad 'reexecute) #f #f)
          (make-error-node 'bad 'rejected #f))
    'default-eof #f))
(define n2 (normalize two))

(harness-group "entry and transition order"
  (lambda ()
    (harness-case "entry is the id of the entry node, not node 0"
      (lambda () (check-equal "entry" (normal-machine-entry n2) 1)))
    (harness-case "transitions are sorted ascending by byte"
      (lambda ()
        (check-equal "bytes"
                     (map car (normal-dispatch-transitions (vector-ref (normal-machine-states n2) 1)))
                     '(2 5))))))

(harness-finish)
```

- [ ] **Step 2: Run the test to verify it fails (RED)**

The lane does not exist yet; register it first (Step 4 below registers both source and AOT). Before the library exists, run:

Run: `cmake --preset dev && cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.unit\.normal-ir' --output-on-failure`
Expected: the build/run fails because `(byte-machine private normal-ir)` is not found (an unbound-library error from the launcher, Chez exit 255) — the genuine RED for a not-yet-written library.

- [ ] **Step 3: Write the implementation** — `src/byte-machine/private/normal-ir.sls`

```scheme
;;; (byte-machine private normal-ir): the normalizer (parent §17). Lowers a
;;; VERIFIED source machine to a canonical normalized IR in deterministic order
;;; — nodes numbered by declaration order, dispatch cases sorted ascending by
;;; byte, error references resolved to their codes — and computes the IR
;;; fingerprint (decision 0009): 64-bit FNV-1a over a canonical byte encoding of
;;; the normalized IR. Pure; runs only after verification (parent §16.3).
(library (byte-machine private normal-ir)
  (export normalize-machine
          normal-machine? normal-machine-entry normal-machine-states
          normal-machine-fingerprint
          normal-state-kind normal-state-id
          normal-dispatch-transitions normal-dispatch-fallback
          normal-error-code)
  (import (rnrs)
          (only (byte-machine private ir)
                machine-nodes machine-entry machine-errors
                byte-dispatch-node? byte-dispatch-node-cases byte-dispatch-node-fallback
                byte-case-matcher byte-case-edge exact-byte-matcher-byte
                edge-target edge-mode stop-node? error-node? error-node-error-name
                error-declaration-name error-declaration-code node-name))

  (define nm-tag (vector 'byte-machine-normal-machine))
  (define (make-normal-machine entry states fp) (vector nm-tag entry states fp))
  (define (normal-machine? x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) nm-tag)))
  (define (normal-machine-entry m) (vector-ref m 1))
  (define (normal-machine-states m) (vector-ref m 2))
  (define (normal-machine-fingerprint m) (vector-ref m 3))

  (define ns-tag (vector 'byte-machine-normal-state))
  ;; (vector ns-tag kind id transitions fallback code) ; unused slots #f
  (define (normal-state-kind s) (vector-ref s 1))
  (define (normal-state-id s) (vector-ref s 2))
  (define (normal-dispatch-transitions s) (vector-ref s 3))
  (define (normal-dispatch-fallback s) (vector-ref s 4))
  (define (normal-error-code s) (vector-ref s 5))

  ;; --- FNV-1a 64-bit over a canonical byte encoding (decision 0009) ---
  (define mask64 (- (expt 2 64) 1))
  (define fnv-offset 14695981039346656037)
  (define fnv-prime  1099511628211)
  (define (fnv1a-64 bv)
    (let loop ((i 0) (h fnv-offset))
      (if (= i (bytevector-length bv)) h
          (loop (+ i 1)
                (bitwise-and mask64 (* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime))))))

  (define (put-u16be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  (define (put-u32be p n)
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 24)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 16)))
    (put-u8 p (bitwise-and 255 (bitwise-arithmetic-shift-right n 8)))
    (put-u8 p (bitwise-and 255 n)))
  (define (put-symbol p sym)
    (let ((b (string->utf8 (symbol->string sym))))
      (put-u16be p (bytevector-length b)) (put-bytevector p b)))
  (define (mode->byte m) (if (eq? m 'advance) 0 1))

  (define (normalize-machine machine)
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
                                     ((error-node? n) (vector ns-tag 'error i #f #f (errcode (error-node-error-name n)))))
                                   acc))))))))
      (let ((fp (fnv1a-64
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
                            ((error) (put-u8 p 2) (put-symbol p (normal-error-code s)))))
                        (loop (+ i 1)))))))))
        (make-normal-machine entry states fp)))))
```

- [ ] **Step 4: Register both lanes** — append to `test/CMakeLists.txt` after the interpret lanes

```cmake
# --- Milestone 1 Phase 3 Slice A: normalizer ------------------------------
set(BYTE_MACHINE_CORE_NORMAL_IR
    ${BYTE_MACHINE_CORE_VERIFY}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/normal-ir.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.normal-ir.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_NORMAL_IR}
          "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.normal-ir.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_NORMAL_IR}
          "${CMAKE_SOURCE_DIR}/test/common/normal-ir-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 5: Run the tests to verify they pass (GREEN)**

Run: `cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.unit\.normal-ir' --output-on-failure`
Expected: both `...chez.source` and `...chez.aot` PASS; the golden fingerprint case reports the measured value.

- [ ] **Step 6: Add the mutation pass** — append Pass 35 to `test/support/cmake/SchemeMutationSuite.cmake`, immediately before the final `byte_machine_mutation_totals` block

```cmake
# --- Pass 35: the normalizer (Milestone 1 Phase 3 Slice A) --------------------
#
# normal-ir-tests.sps pins the IR fingerprint of the one-byte machine (a golden
# value) and the structural decisions (entry id, transition sort, error-code
# resolution). This pass proves those checks are not vacuous. Verify command
# modelled on the placeholder pass (Pass 8): both library roots, an empty object
# guard, the normal-ir program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/normal-ir-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV offset basis is changed"
  FIND [[(define fnv-offset 14695981039346656037)]]
  REPLACE [[(define fnv-offset 14695981039346656038)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "11963406767470843108")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the FNV prime is changed"
  FIND [[(define fnv-prime  1099511628211)]]
  REPLACE [[(define fnv-prime  1099511628212)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "11963406767470843108")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the byte is never mixed into the hash"
  FIND [[(* (bitwise-xor h (bytevector-u8-ref bv i)) fnv-prime)]]
  REPLACE [[(* h fnv-prime)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "11963406767470843108")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: the entry id is hard-wired to node 0"
  FIND [[(entry (id-of (machine-entry machine)))]]
  REPLACE [[(entry 0)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "entry")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: dispatch cases are not sorted ascending by byte"
  FIND [[(list-sort (lambda (a b) (< (car a) (car b)))]]
  REPLACE [[(list-sort (lambda (a b) (> (car a) (car b)))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "bytes")

byte_machine_mutation(
  FILE src/byte-machine/private/normal-ir.sls SPEC byte-machine.unit.normal-ir.chez.source
  LABEL "normal-ir: an error node resolves to the declaration name, not its code"
  FIND [[(error-declaration-code (car es)) (loop (cdr es))]]
  REPLACE [[(error-declaration-name (car es)) (loop (cdr es))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "unexpected-byte")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

Do not update `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` yet — Task 5 sets the final totals once every pass in this slice exists, so the suite is not run end-to-end between tasks. (Run the individual lanes and, if you want, this pass in isolation, but the whole-suite totals check lands in Task 5.)

- [ ] **Step 7: Commit**

```bash
git add src/byte-machine/private/normal-ir.sls test/common/normal-ir-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: normalizer and IR fingerprint for the one-byte machine"
```

---

### Task 2: Runtime ABI — the direct-executor `/v1` seam

**Files:**
- Modify: `src/byte-machine/runtime.sls`
- Modify: `test/common/runtime-tests.sps` (add a `/v1` group before `(harness-finish)`)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (extend Pass 32)

**Interfaces:**
- Produces (new exports from `(byte-machine runtime)`):
  - `(byte-machine-make-compiled-machine/v1 abi-version ir-fingerprint entry-state feed)` → compiled-machine. Raises `assertion-violation` if `abi-version` ≠ the runtime's supported version, or if `feed` is not a procedure.
  - `(byte-machine-make-feed-outcome/v1 status next error next-state offset)` → feed-outcome. `status ∈ {stopped, error, need-input}`; `next` = absolute stop index; `error` = code symbol or `#f`; `next-state` = numeric resume id; `offset` = new cumulative stream-offset.
  - `feed` contract (implemented by generated code, called by the runtime): `(feed state offset bv start end)` → feed-outcome.
- Unchanged public surface: `make-compiled-machine`, `make-parser`, `parser-feed!`, `parser-result*`, `callback-continue`, `callback-pause` — the interpreter keeps producing an `op`-variant machine and is not edited.

> **Preserve the Phase 2 Pass 32 FIND strings verbatim.** The existing runtime mutation pass anchors on `(loop (+ pos 1))`, `(make-parser-result 'need-input pos`, and `(parser-set-offset! parser (+ 1 (parser-offset parser)))`. These live in the `op` loop; when moving that loop into `parser-feed-op!`, keep those three lines byte-for-byte or Pass 32 stops matching. The implementation below already does.

> **ABI mismatch is an `assertion-violation`, not a coded condition, in Slice A.** Importing `(byte-machine private conditions)` into `runtime.sls` would place `conditions.sls` in `BYTE_MACHINE_CORE_RUNTIME`, and `BYTE_MACHINE_CORE_ALL` already carries it through `CORE_VERIFY` — the two together would trip `byte_machine_lane_duplicate_basenames`. `runtime.sls` therefore stays a standalone library and raises via `assertion-violation`, consistent with its existing guards. A coded `generated-runtime-abi-mismatch` condition (parent §9.4) is deferred to a milestone that refactors the manifest composition; Slice A never needs to compare it across lanes.

- [ ] **Step 1: Write the failing test** — add this group to `test/common/runtime-tests.sps` immediately before `(harness-finish)`

```scheme
;; The direct-executor ABI. A hand-built feed encodes the one-byte machine over
;; numeric states (0 dispatch, 1 stop, 2 error), so the v1 path is witnessed
;; independently of the emitter.
(define (stub-feed state offset bv start end)
  (let loop ((pos start) (st state) (off offset))
    (case st
      ((1) (byte-machine-make-feed-outcome/v1 'stopped pos #f 1 off))
      ((2) (byte-machine-make-feed-outcome/v1 'error pos 'unexpected-byte 2 off))
      (else
       (if (>= pos end)
           (byte-machine-make-feed-outcome/v1 'need-input pos #f 0 off)
           (let ((b (bytevector-u8-ref bv pos)))
             (if (= b 0) (loop (+ pos 1) 1 (+ off 1)) (loop pos 2 off))))))))
(define (v1-machine) (byte-machine-make-compiled-machine/v1 1 42 0 stub-feed))
(define (v1-feed-byte b)
  (parser-feed! (make-parser (v1-machine) '() #f) (make-bytevector 1 b) 0 1))

(harness-group "generated-code ABI (/v1)"
  (lambda ()
    (harness-case "the accepted byte stops after consuming one byte"
      (lambda ()
        (let ((r (v1-feed-byte 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "stream offset" (parser-result-stream-offset r) 1))))
    (harness-case "a rejected byte errors at position 0 with the code"
      (lambda ()
        (let ((r (v1-feed-byte 65)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "stream offset" (parser-result-stream-offset r) 0)
          (check-equal "error value" (parser-result-error r) 'unexpected-byte))))
    (harness-case "an empty slice needs input"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (got 'not-yet))
          (set! got (parser-result-status (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" got 'need-input))))
    (harness-case "a terminal result is sticky across a second feed"
      (lambda ()
        (let* ((p (make-parser (v1-machine) '() #f))
               (r1 (parser-feed! p (make-bytevector 1 0) 0 1))
               (r2 (parser-feed! p (make-bytevector 1 0) 0 1)))
          (check-equal "second next equals first" (parser-result-next r2) (parser-result-next r1))
          (check-equal "second consumed equals first"
                       (parser-result-consumed r2) (parser-result-consumed r1)))))
    (harness-case "a mismatched ABI version is refused"
      (lambda ()
        (check-raises "refused"
                      (lambda (e) #t)
                      (lambda () (byte-machine-make-compiled-machine/v1 2 42 0 stub-feed)))))))
```

- [ ] **Step 2: Run to verify RED**

Run: `cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.unit\.runtime' --output-on-failure`
Expected: FAIL — `byte-machine-make-compiled-machine/v1` and `byte-machine-make-feed-outcome/v1` are unbound (the program fails to expand; Chez exit 255 through the launcher).

- [ ] **Step 3: Rewrite** `src/byte-machine/runtime.sls`

```scheme
;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile (parent §7.2). Two executor variants share this one parser API and
;;; the one parser-result contract: the reference interpreter builds an `op`
;;; message closure over the source IR; generated code (Phase 3, decision 0010)
;;; is a direct resumable executor constructed through
;;; byte-machine-make-compiled-machine/v1. The two are deliberately different
;;; implementations, which is what lets the interpreter≡generated differential
;;; catch lowering defects (parent §18, §22.4).
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
          byte-machine-make-compiled-machine/v1 byte-machine-make-feed-outcome/v1
          make-parser parser?
          parser-feed!
          parser-result? parser-result-status parser-result-next
          parser-result-consumed parser-result-stream-offset parser-result-error
          callback-continue callback-pause)
  (import (rnrs))

  (define (tag sym) (vector sym))
  (define (tagged? t x) (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))

  ;; Allocation-free outcome singletons (parent §13). M1 exercises neither;
  ;; they fix the contract so interpreter and generated callbacks return the
  ;; same objects once callbacks land.
  (define callback-continue (vector 'byte-machine-callback-continue))
  (define callback-pause (vector 'byte-machine-callback-pause))

  ;; --- compiled machine: two variants behind one type ---
  ;; op:  (vector tag 'op op-closure)               -- the reference interpreter
  ;; v1:  (vector tag 'v1 feed entry-state fingerprint) -- generated code
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag 'op op))
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-variant cm) (vector-ref cm 1))

  (define current-abi-version 1)
  (define (byte-machine-make-compiled-machine/v1 abi-version ir-fingerprint entry-state feed)
    (unless (and (integer? abi-version) (= abi-version current-abi-version))
      (assertion-violation 'byte-machine-make-compiled-machine/v1
                           "generated-runtime ABI mismatch" abi-version))
    (unless (procedure? feed)
      (assertion-violation 'byte-machine-make-compiled-machine/v1 "feed must be a procedure" feed))
    (vector compiled-machine-tag 'v1 feed entry-state ir-fingerprint))

  ;; --- feed outcome (the runtime<-generated seam; accessors private) ---
  (define feed-outcome-tag (tag 'byte-machine-feed-outcome))
  (define (byte-machine-make-feed-outcome/v1 status next error next-state offset)
    (vector feed-outcome-tag status next error next-state offset))
  (define (feed-outcome-status o) (vector-ref o 1))
  (define (feed-outcome-next o) (vector-ref o 2))
  (define (feed-outcome-error o) (vector-ref o 3))
  (define (feed-outcome-next-state o) (vector-ref o 4))
  (define (feed-outcome-offset o) (vector-ref o 5))

  ;; --- parser result (immutable snapshot) ---
  (define parser-result-tag (tag 'byte-machine-parser-result))
  (define (make-parser-result status next consumed stream-offset error)
    (vector parser-result-tag status next consumed stream-offset error))
  (define (parser-result? x) (tagged? parser-result-tag x))
  (define (parser-result-status r) (vector-ref r 1))
  (define (parser-result-next r) (vector-ref r 2))
  (define (parser-result-consumed r) (vector-ref r 3))
  (define (parser-result-stream-offset r) (vector-ref r 4))
  (define (parser-result-error r) (vector-ref r 5))

  ;; --- parser (mutable state behind procedures) ---
  ;; (vector tag variant executor current offset sticky)
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (if (eq? (compiled-machine-variant compiled-machine) 'op)
        (let ((op (vector-ref compiled-machine 2)))
          (vector parser-tag 'op op (op 'entry) 0 #f))
        (let ((feed (vector-ref compiled-machine 2))
              (entry-state (vector-ref compiled-machine 3)))
          (vector parser-tag 'v1 feed entry-state 0 #f))))
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-variant p) (vector-ref p 1))
  (define (parser-executor p) (vector-ref p 2))
  (define (parser-current p) (vector-ref p 3))
  (define (parser-set-current! p v) (vector-set! p 3 v))
  (define (parser-offset p) (vector-ref p 4))
  (define (parser-set-offset! p v) (vector-set! p 4 v))
  (define (parser-sticky p) (vector-ref p 5))
  (define (parser-set-sticky! p v) (vector-set! p 5 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (assertion-violation 'parser-feed! "invalid slice" (list start end)))
    (or (parser-sticky parser)
        (if (eq? (parser-variant parser) 'op)
            (parser-feed-op! parser bv start end)
            (parser-feed-v1! parser bv start end))))

  ;; The interpreter path, unchanged from Phase 2 (its decisions are witnessed by
  ;; SchemeMutationSuite Pass 32; the three FIND anchors live here).
  (define (parser-feed-op! parser bv start end)
    (let ((op (parser-executor parser)))
      (let loop ((pos start))
        (let ((node (parser-current parser)))
          (case (op 'kind node)
            ((stop)
             (let ((r (make-parser-result 'stopped pos (- pos start)
                                          (parser-offset parser) #f)))
               (parser-set-sticky! parser r) r))
            ((error)
             (let ((r (make-parser-result 'error pos (- pos start)
                                          (parser-offset parser)
                                          (op 'error-value node))))
               (parser-set-sticky! parser r) r))
            ((dispatch)
             (if (>= pos end)
                 (make-parser-result 'need-input pos (- pos start)
                                     (parser-offset parser) #f)
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
            (else (assertion-violation 'parser-feed! "unknown node kind"
                                       (op 'kind node))))))))

  ;; The generated path: the feed owns the dispatch loop and returns one outcome;
  ;; the runtime commits resume state and builds the result (single source of the
  ;; parser-result shape).
  (define (parser-feed-v1! parser bv start end)
    (let* ((feed (parser-executor parser))
           (o (feed (parser-current parser) (parser-offset parser) bv start end))
           (status (feed-outcome-status o))
           (next (feed-outcome-next o)))
      (parser-set-current! parser (feed-outcome-next-state o))
      (parser-set-offset! parser (feed-outcome-offset o))
      (let ((r (make-parser-result status next (- next start)
                                   (feed-outcome-offset o) (feed-outcome-error o))))
        (if (or (eq? status 'stopped) (eq? status 'error)) (parser-set-sticky! parser r))
        r))))
```

- [ ] **Step 4: Run to verify GREEN**

Run: `cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.unit\.(runtime|interpret)' --output-on-failure`
Expected: runtime source+aot and interpret source+aot all PASS (the interpreter is unchanged and still drives the `op` path).

- [ ] **Step 5: Extend Pass 32** — add four mutations inside the existing Pass 32 block in `SchemeMutationSuite.cmake` (after its third `byte_machine_mutation(...)`, before its `byte_machine_mutation_run`)

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a v1 machine is driven down the op path"
  FIND [[(if (eq? (parser-variant parser) 'op)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "status")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a mismatched generated-runtime ABI version is accepted"
  FIND [[(unless (and (integer? abi-version) (= abi-version current-abi-version))]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: the v1 result status is hard-wired to stopped"
  FIND [[(status (feed-outcome-status o))]]
  REPLACE [[(status 'stopped)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "status")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a v1 terminal result is not made sticky"
  FIND [[(if (or (eq? status 'stopped) (eq? status 'error)) (parser-set-sticky! parser r))]]
  REPLACE [[(if #f (parser-set-sticky! parser r))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "second")
```

The `FIND` for the status mutation is the `let*` binding `(status (feed-outcome-status o))` exactly as written in Step 3 (it occurs once). Do not bump totals here (Task 5).

- [ ] **Step 6: Commit**

```bash
git add src/byte-machine/runtime.sls test/common/runtime-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: direct-executor /v1 runtime ABI with parser-feed! variant dispatch"
```

---

### Task 3: The emitter — `(byte-machine compile)`

**Files:**
- Create: `src/byte-machine/compile.sls`
- Test: `test/common/compile-tests.sps`
- Modify: `test/CMakeLists.txt` (add `BYTE_MACHINE_CORE_COMPILE` and the lane pair)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 36)

**Interfaces:**
- Consumes: `(byte-machine verify)`, `(only (byte-machine private ir) machine-name)`, `(byte-machine private normal-ir)`.
- Produces (exports of `(byte-machine compile)`):
  - `(compile-machine machine options)` → compilation. Verifies internally; `options` must be `'()`.
  - `(compilation-ok? c)` → boolean; `(compilation-diagnostics c)` → list.
  - `(render-machine compilation binding)` → bytevector (the complete canonical `.sls` source). Pure. Raises `assertion-violation` on an unverified compilation or an invalid `binding`.
  - `(emit-machine compilation binding port)` → emission metadata `#(emission-metadata <ir-fingerprint> <byte-count>)`; writes `render-machine`'s bytevector to the binary `port`.

- [ ] **Step 1: Write the failing test** — `test/common/compile-tests.sps`

```scheme
;;; The emitter compiles, renders, and emits the one-byte machine, and validates
;;; its options and output binding. Structure of the rendered text is asserted by
;;; substring (the generated parser's behaviour is proven end-to-end in the
;;; differential and example lanes). Rendered bytes are decoded with utf8->string
;;; only to search them — never to compare against implementation `write` output.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine compile))

(harness-begin "unit.compile")

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
;; An invalid machine: entry names no node (verify emits missing-target).
(define broken
  (make-machine 'one-byte 'nowhere '() '() '() (list eof-decl rej-decl)
    (list (make-stop-node 'stop #f)) 'default-eof #f))

(define ok (compile-machine one-byte '()))
(define (text) (utf8->string (render-machine ok 'one-byte-parser)))
(define (has? needle) (harness-string-contains? (text) needle))

(harness-group "compilation"
  (lambda ()
    (harness-case "a valid machine compiles ok"
      (lambda () (check "ok" (compilation-ok? ok))))
    (harness-case "an invalid machine does not compile and carries diagnostics"
      (lambda ()
        (let ((c (compile-machine broken '())))
          (check "not ok" (not (compilation-ok? c)))
          (check "has diagnostics" (not (null? (compilation-diagnostics c)))))))
    (harness-case "a non-empty option list is refused"
      (lambda ()
        (check-raises "refused" (lambda (e) #t)
                      (lambda () (compile-machine one-byte '(fast))))))))

(harness-group "rendered library structure"
  (lambda ()
    (harness-case "it is a library that exports the binding and imports the runtime"
      (lambda ()
        (check "library form" (has? "(library (generated one-byte)"))
        (check "export" (has? "(export one-byte-parser)"))
        (check "import" (has? "(import (rnrs) (byte-machine runtime))"))))
    (harness-case "it constructs the compiled machine through the v1 ABI with the fingerprint"
      (lambda ()
        (check "v1 call" (has? "(byte-machine-make-compiled-machine/v1 1 11963406767470843108 0 feed)"))))
    (harness-case "the accepted byte advances and the fallback reexecutes"
      (lambda ()
        (check "advance arm" (has? "((0) (loop (+ pos 1) 1 (+ off 1)))"))
        (check "fallback"    (has? "(else (loop pos 2 off))"))))
    (harness-case "the error state emits the resolved code"
      (lambda ()
        (check "error arm" (has? "(byte-machine-make-feed-outcome/v1 (quote error) pos (quote unexpected-byte) 2 off)"))))))

(harness-group "binding validation"
  (lambda ()
    (harness-case "an uppercase or punctuated binding is refused"
      (lambda ()
        (check-raises "grammar" (lambda (e) #t) (lambda () (render-machine ok 'Bad)))))
    (harness-case "an R6RS keyword binding is refused (reserved member 1)"
      (lambda ()
        (check-raises "member 1" (lambda (e) #t) (lambda () (render-machine ok 'define)))))
    (harness-case "a runtime export binding is refused (reserved member 2)"
      (lambda ()
        (check-raises "member 2" (lambda (e) #t) (lambda () (render-machine ok 'parser-feed!)))))
    (harness-case "a template identifier binding is refused (reserved member 3)"
      (lambda ()
        (check-raises "member 3" (lambda (e) #t) (lambda () (render-machine ok 'feed)))))))

(harness-group "emission"
  (lambda ()
    (harness-case "emit writes render's bytes and reports the fingerprint and count"
      (lambda ()
        (let-values (((port get) (open-bytevector-output-port)))
          (let ((meta (emit-machine ok 'one-byte-parser port)))
            (check-equal "fingerprint" (vector-ref meta 1) 11963406767470843108)
            (check-equal "byte count matches render"
                         (vector-ref meta 2) (bytevector-length (render-machine ok 'one-byte-parser)))
            (check-equal "bytes written match render"
                         (get) (render-machine ok 'one-byte-parser))))))))

(harness-finish)
```

- [ ] **Step 2: Run to verify RED**

Run: `cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.unit\.compile' --output-on-failure`
Expected: FAIL — `(byte-machine compile)` not found.

- [ ] **Step 3: Write the implementation** — `src/byte-machine/compile.sls`

```scheme
;;; (byte-machine compile): the offline emitter (parent §9.2, §19, §20;
;;; decisions 0008, 0009, 0010). compile-machine re-verifies internally and
;;; normalizes; render-machine renders the normalized IR to a complete importable
;;; R6RS .sls as a canonical UTF-8/LF bytevector (no implementation `write`);
;;; emit-machine writes those bytes to the supplied binary port only. The
;;; generated library imports only (rnrs) and (byte-machine runtime), owns the
;;; derived library name (generated <machine-name>), and defines the single
;;; caller-named compiled-machine binding via the v1 ABI. Pure but for
;;; emit-machine's port write.
(library (byte-machine compile)
  (export compile-machine compilation-ok? compilation-diagnostics
          render-machine emit-machine)
  (import (rnrs)
          (byte-machine verify)
          (only (byte-machine private ir) machine-name)
          (byte-machine private normal-ir))

  (define c-tag (vector 'byte-machine-compilation))
  ;; (vector c-tag ok? diagnostics machine normal) ; normal #f when not ok
  (define (make-compilation ok? diags machine normal) (vector c-tag ok? diags machine normal))
  (define (compilation-ok? c) (vector-ref c 1))
  (define (compilation-diagnostics c) (vector-ref c 2))
  (define (compilation-machine c) (vector-ref c 3))
  (define (compilation-normal c) (vector-ref c 4))

  (define (compile-machine machine options)
    (unless (null? options)
      (assertion-violation 'compile-machine "v0.1 accepts only the empty option list" options))
    (let ((v (verify-machine machine)))
      (if (verification-ok? v)
          (make-compilation #t '() (verification-machine v)
                            (normalize-machine (verification-machine v)))
          (make-compilation #f (verification-diagnostics v) (verification-machine v) #f))))

  ;; --- reserved-output-binding set (all three members now exist, design §3.3) ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  (define reserved-member-2
    '(make-compiled-machine compiled-machine?
      byte-machine-make-compiled-machine/v1 byte-machine-make-feed-outcome/v1
      make-parser parser? parser-feed!
      parser-result? parser-result-status parser-result-next
      parser-result-consumed parser-result-stream-offset parser-result-error
      callback-continue callback-pause))
  (define reserved-member-3 '(feed loop pos st off b bv start end state offset))
  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-binding? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0) (lower-alpha? (string-ref s 0))
           (let loop ((i 1)) (or (>= i (string-length s))
                                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))
           (not (memq sym reserved-member-1))
           (not (memq sym reserved-member-2))
           (not (memq sym reserved-member-3)))))

  (define (validate-binding binding)
    (unless (symbol? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding))
    (unless (valid-binding? binding)
      (assertion-violation 'render-machine "invalid-output-binding" binding)))

  ;; --- canonical source writer ---
  ;; Each transition/fallback lowers to a loop tail: advance bumps pos and off,
  ;; reexecute keeps both. Rendered as one string with explicit, counted parens.
  (define (loop-tail target mode)
    (if (eq? mode 'advance)
        (string-append "(loop (+ pos 1) " (number->string target) " (+ off 1))")
        (string-append "(loop pos " (number->string target) " off)")))

  (define (render-transition-arm tr)
    ;; tr = (byte target mode) -> "((<byte>) <loop-tail>)"
    (string-append "               ((" (number->string (car tr)) ") "
                   (loop-tail (cadr tr) (caddr tr)) ")\n"))

  (define (render-state-arm s)
    (let ((id (number->string (normal-state-id s))))
      (case (normal-state-kind s)
        ((stop)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote stopped) pos #f " id " off))\n"))
        ((error)
         (string-append "      ((" id ") (byte-machine-make-feed-outcome/v1 (quote error) pos (quote "
                        (symbol->string (normal-error-code s)) ") " id " off))\n"))
        ((dispatch)
         (let ((fb (normal-dispatch-fallback s)))
           (string-append
            "      ((" id ")\n"
            "       (if (>= pos end)\n"
            "           (byte-machine-make-feed-outcome/v1 (quote need-input) pos #f " id " off)\n"
            "           (let ((b (bytevector-u8-ref bv pos)))\n"
            "             (case b\n"
            (apply string-append (map render-transition-arm (normal-dispatch-transitions s)))
            "               (else " (loop-tail (car fb) (cdr fb)) ")))))\n"))))))

  (define (render-machine compilation binding)
    (unless (compilation-ok? compilation)
      (assertion-violation 'render-machine "cannot render an unverified machine"
                           (compilation-diagnostics compilation)))
    (validate-binding binding)
    (let* ((normal (compilation-normal compilation))
           (mname (symbol->string (machine-name (compilation-machine compilation))))
           (states (normal-machine-states normal))
           (entry (normal-machine-entry normal))
           (fp (normal-machine-fingerprint normal))
           (bstr (symbol->string binding)))
      (string->utf8
       (string-append
        "(library (generated " mname ")\n"
        "  (export " bstr ")\n"
        "  (import (rnrs) (byte-machine runtime))\n"
        "  (define (feed state offset bv start end)\n"
        "    (let loop ((pos start) (st state) (off offset))\n"
        "      (case st\n"
        (let loop ((i 0) (acc ""))
          (if (>= i (vector-length states)) acc
              (loop (+ i 1) (string-append acc (render-state-arm (vector-ref states i))))))
        "      (else (assertion-violation (quote feed) \"unknown state\" st)))))\n"
        "  (define " bstr "\n"
        "    (byte-machine-make-compiled-machine/v1 1 " (number->string fp) " "
        (number->string entry) " feed)))\n"))))

  (define (emit-machine compilation binding port)
    (let ((bytes (render-machine compilation binding)))
      (put-bytevector port bytes)
      (vector 'emission-metadata
              (normal-machine-fingerprint (compilation-normal compilation))
              (bytevector-length bytes)))))
```

- [ ] **Step 4: Register both lanes** — append to `test/CMakeLists.txt`

```cmake
# --- Milestone 1 Phase 3 Slice A: emitter ---------------------------------
set(BYTE_MACHINE_CORE_COMPILE
    ${BYTE_MACHINE_CORE_NORMAL_IR}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/compile.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.compile.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.compile.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_COMPILE}
          "${CMAKE_SOURCE_DIR}/test/common/compile-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 5: Run to verify GREEN**

Run: `cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.unit\.compile' --output-on-failure`
Expected: both lanes PASS.

- [ ] **Step 6: Add Pass 36** — append to `SchemeMutationSuite.cmake` before the totals block

```cmake
# --- Pass 36: the emitter (Milestone 1 Phase 3 Slice A) ----------------------
#
# compile-tests.sps checks the compilation contract, the binding reserved-set
# (all three members), and the rendered library structure by substring. This
# pass proves those checks are not vacuous. Verify command modelled on the
# placeholder pass (Pass 8): both library roots, an empty object guard, the
# compile program.

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/compile-tests.sps")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: a non-empty option list is accepted"
  FIND [[(unless (null? options)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an invalid machine is reported as compiled ok"
  FIND [[(if (verification-ok? v)]]
  REPLACE [[(if #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "not ok")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an unverified compilation is rendered anyway"
  FIND [[(unless (compilation-ok? compilation)]]
  REPLACE [[(unless #t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "ok")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the binding grammar check is dropped"
  FIND [[(and (> (string-length s) 0) (lower-alpha? (string-ref s 0))]]
  REPLACE [[(and #t (lower-alpha? #\a)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "grammar")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 1 is not checked"
  FIND [[(not (memq sym reserved-member-1))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 1")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 2 is not checked"
  FIND [[(not (memq sym reserved-member-2))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 2")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: reserved member 3 is not checked"
  FIND [[(not (memq sym reserved-member-3))]]
  REPLACE [[#t]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "member 3")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: an advance transition is lowered as a reexecute"
  FIND [[(string-append "(loop (+ pos 1) " (number->string target) " (+ off 1))")]]
  REPLACE [[(string-append "(loop pos " (number->string target) " off)")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "advance arm")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the reexecute fallback is lowered as an advance"
  FIND [[(string-append "(loop pos " (number->string target) " off)")]]
  REPLACE [[(string-append "(loop (+ pos 1) " (number->string target) " (+ off 1))")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "fallback")

byte_machine_mutation(
  FILE src/byte-machine/compile.sls SPEC byte-machine.unit.compile.chez.source
  LABEL "compile: the error arm omits the resolved code"
  FIND [[(symbol->string (normal-error-code s)) ") " id " off))\n")]]
  REPLACE [["internal" ") " id " off))\n")]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "error arm")

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```

- [ ] **Step 7: Commit**

```bash
git add src/byte-machine/compile.sls test/common/compile-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: emitter renders and emits an importable generated library"
```

---

### Task 4: End-to-end example and the all-256 differential

**Files:**
- Create: `test/common/differential-one-byte-tests.sps`
- Create: `test/common/example-one-byte-tests.sps`
- Modify: `test/CMakeLists.txt` (add `BYTE_MACHINE_CORE_EMIT` and two lane pairs)

**Interfaces:**
- Consumes: `(byte-machine graph)`, `(byte-machine verify)`, `(byte-machine interpret)`, `(byte-machine runtime)`, `(byte-machine compile)`, plus `(rnrs eval)` and `(only (chezscheme) load)` for the runtime load of the emitted library, and `(byte-machine test harness)`.
- Produces: no library — two executable proof programs.

> **How the generated library is loaded.** The program emits the `.sls` to a file under `BYTE_MACHINE_TEST_TMPDIR` (set per-lane by the registration), `(load)`s it (which installs the `(library ...)` form), then obtains the exported binding with `(eval '<binding> (environment '(generated one-byte)))`. Verified in both the source and AOT lanes: the runtime-loaded library's `(import (byte-machine runtime))` reuses the resident runtime instance, so the generated compiled-machine shares tags and singletons with the interpreter side. The file name is arbitrary (load is by explicit path); the library *name* is what `environment` resolves. The generated file is never in any `SOURCES` manifest.

- [ ] **Step 1: Write the differential test** — `test/common/differential-one-byte-tests.sps`

```scheme
;;; interpreter ≡ generated across all 256 byte values (parent §22.4). The
;;; generated library is emitted at run time, loaded, and its compiled-machine
;;; obtained by environment/eval; both executors run through the shared
;;; make-parser/parser-feed! API and their parser-result fields are compared.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine compile))

(harness-begin "differential.one-byte")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'differential "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/generated-one-byte.sls"))

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

(define cm-ref (make-interpreted-machine (verify-machine one-byte)))
(call-with-port (open-file-output-port genfile (file-options no-fail))
  (lambda (p) (emit-machine (compile-machine one-byte '()) 'one-byte-parser p)))
(load genfile)
(define cm-gen (eval 'one-byte-parser (environment '(generated one-byte))))

(define (rfields cm b)
  (let ((r (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1)))
    (list (parser-result-status r) (parser-result-next r) (parser-result-consumed r)
          (parser-result-stream-offset r) (parser-result-error r))))

(harness-group "interpreter and generated agree on every byte"
  (lambda ()
    (harness-case "all 256 byte values match"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 0))
            (when (< b 256)
              (unless (equal? (rfields cm-ref b) (rfields cm-gen b))
                (if (eq? bad 'none) (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte disagreed" bad 'none))))
    (harness-case "the accepted byte stops after one byte in both"
      (lambda ()
        (check-equal "match" (rfields cm-gen 0) (rfields cm-ref 0))
        (check-equal "generated stops" (car (rfields cm-gen 0)) 'stopped)))
    (harness-case "a rejected byte errors at position 0 in both"
      (lambda ()
        (check-equal "match" (rfields cm-gen 7) (rfields cm-ref 7))
        (check-equal "generated errors" (car (rfields cm-gen 7)) 'error)))))

(harness-finish)
```

- [ ] **Step 2: Write the example test** — `test/common/example-one-byte-tests.sps`

```scheme
;;; The parent §9.6 end-to-end example, run as one program in both lanes:
;;; construct only through (byte-machine graph); verify; compile without runtime
;;; evaluation; emit the .sls to a binary file port; the consumer imports the
;;; generated library (by import, never include) and only (byte-machine runtime),
;;; constructs a parser, feeds the exact [0,1) slice, and inspects the result.
(import (rnrs) (rnrs eval)
        (only (chezscheme) load)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine runtime))

(harness-begin "example.one-byte")

(define tmpdir
  (let ((d (adapter-environment-variable "BYTE_MACHINE_TEST_TMPDIR")))
    (if (and d (not (string=? d ""))) d
        (assertion-violation 'example "BYTE_MACHINE_TEST_TMPDIR is unset" d))))
(define genfile (string-append tmpdir "/example-one-byte.sls"))

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

(harness-group "construct, verify, compile, emit, import, run"
  (lambda ()
    (harness-case "the emitted parser accepts the exact byte across the library boundary"
      (lambda ()
        (let ((comp (compile-machine one-byte '())))
          (check "verified and compiled" (compilation-ok? comp))
          (call-with-port (open-file-output-port genfile (file-options no-fail))
            (lambda (p) (emit-machine comp 'one-byte-parser p)))
          (load genfile)
          (let* ((cm (eval 'one-byte-parser (environment '(generated one-byte))))
                 (input (make-bytevector 1 0))
                 (r (parser-feed! (make-parser cm '() #f) input 0 1)))
            (check-equal "status" (parser-result-status r) 'stopped)
            (check-equal "consumed one byte" (parser-result-consumed r) 1)))))))

(harness-finish)
```

- [ ] **Step 3: Register both lane pairs** — append to `test/CMakeLists.txt`

```cmake
# --- Milestone 1 Phase 3 Slice A: differential and example ----------------
set(BYTE_MACHINE_CORE_EMIT
    ${BYTE_MACHINE_CORE_ALL}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/normal-ir.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/compile.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.one-byte.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.differential.one-byte.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/differential-one-byte-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.example.one-byte.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.example.one-byte.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_EMIT}
          "${CMAKE_SOURCE_DIR}/test/common/example-one-byte-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 4: Run to verify GREEN**

Run: `cmake --build --preset dev && ctest --preset pr -R 'byte-machine\.(differential|example)\.one-byte' --output-on-failure`
Expected: all four lanes PASS; the `all 256 byte values match` case reports no disagreement. (These lanes carry the `differential` and `example` labels, both already in the `pr` preset filter — no preset edit needed.)

- [ ] **Step 5: Commit**

```bash
git add test/common/differential-one-byte-tests.sps test/common/example-one-byte-tests.sps test/CMakeLists.txt
git commit -m "test: interpreter-vs-generated differential and the end-to-end example"
```

---

### Task 5: Close-out — decision record, totals, docs

**Files:**
- Create: `docs/decisions/0010-direct-executor-abi.md`
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (bump `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` + the header arithmetic)
- Modify: `CHANGELOG.md`
- Modify: `docs/plans/milestone-1-phase-3-slice-a-design.md` (dated note reconciling it to what shipped)

- [ ] **Step 1: Write the decision record** — `docs/decisions/0010-direct-executor-abi.md`

```markdown
# 0010: The generated-code ABI is a direct executor, not an op closure

Date: 2026-08-23
Status: accepted
Milestone: 1, Phase 3 Slice A

## Context

Milestone 1's design (§6) deferred the generated-code ABI to Phase 3. The Phase 2
runtime header claimed the interpreter "and, later, generated code both produce a
compiled-machine whose `op` closure answers the messages make-parser drives, so the
two executors are identical by construction." Parent §19 requires the opposite: a
direct resumable executor over stable numeric state ids, not a generic opcode VM.
"Identical by construction" is also the lack of independence that would blind the
interpreter≡generated differential (parent §18, §22.4) to lowering defects.

## Decision

1. Generated code is a **direct executor**: a `feed` procedure that owns the
   dispatch loop (a `case` over numeric state ids, byte test inline, cursor and
   offset in locals) and returns one outcome per feed call.
2. `(byte-machine runtime)` gains `byte-machine-make-compiled-machine/v1` (carrying
   the ABI version, the IR fingerprint, the entry state, and `feed`) and
   `byte-machine-make-feed-outcome/v1` (a named result record: status, next, error,
   next-state, offset). `parser-feed!` dispatches on the compiled-machine variant:
   the interpreter keeps its `op` path unchanged; generated code takes the `feed`
   path. The runtime commits resume state and builds the `parser-result`.
3. The Phase 2 "identical by construction / shared executor" comment is corrected
   in place (it was an instruction, not a record — AGENTS.md).
4. The runtime↔generated seam carries the named `feed-outcome` record (not a
   positional value tuple), so the ABI is self-documenting and extends by a `/v2`
   constructor rather than an arity break.
5. In Slice A an ABI-version mismatch raises `assertion-violation`; a coded
   `generated-runtime-abi-mismatch` condition (parent §9.4) is deferred to avoid a
   runtime→conditions dependency that would duplicate `conditions.sls` in the
   `CORE_ALL` lane manifest.

## Consequences

- The emitter (`(byte-machine compile)`) renders `feed` as direct Scheme and
  constructs the binding via `byte-machine-make-compiled-machine/v1`.
- The interpreter is untouched, preserving the §18 independence the differential
  relies on.
- Slice B may revisit the `feed-outcome` seam under a `/v2` ABI if benchmark
  evidence ever calls for it (parent §23); the version tag exists for exactly that.
```

- [ ] **Step 2: Re-read and bump the mutation totals** — in `SchemeMutationSuite.cmake`

First confirm the live declared values are still `EXPECTED_PASSES 34` / `EXPECTED_MUTATIONS 87`. This slice adds Pass 35 (6 mutations) and Pass 36 (10 mutations) and four mutations to Pass 32, for **+2 passes** and **+20 mutations**. Update the two `set(...)` lines:

```cmake
set(EXPECTED_PASSES 36)
set(EXPECTED_MUTATIONS 107)
```

Extend the header arithmetic comment (the "THIRTY-ONE PASSES" block) with a Slice A paragraph, in the same voice as the existing ones:

```
# Milestone 1 Phase 3 Slice A adds two passes and twenty mutations: Pass 32
# (runtime) gains four -- v1 variant dispatch, the ABI-version check, the v1
# result-status read, and v1 stickiness -- so 3 -> 7; Pass 35 (the normalizer)
# adds six -- the FNV offset, the FNV prime, the byte-mixing XOR, the entry id,
# the transition sort, and error-code resolution; Pass 36 (the emitter) adds ten
# -- options validation, the compiled-ok verdict, the unverified-render refusal,
# the binding grammar, the three reserved-set members, the advance and reexecute
# loop tails, and the error-arm code. So 34 + 2 = 36 passes and 87 + 20 = 107
# mutations.
```

- [ ] **Step 3: Run the whole suite (a new exit path was added)** — AGENTS.md requires re-running the entire mutation suite after adding exit paths (`/v1` and emitter `assertion-violation`s).

Run: `cmake --build --preset dev && ctest --preset release --output-on-failure`
Then the mutation suite specifically:
Run: `ctest --preset release -R 'byte-machine\.harness\.scheme-mutation' --output-on-failure`
Expected: `scheme mutation suite complete (36 passes, 107 mutations)`; the totals check passes. Confirm no existing pass's baseline flipped (the report lists each pass). Then confirm the full and no-scheme selections:
Run: `ctest --preset release --output-on-failure` (expect the prior 47 plus the 12 new lanes = 59 tests, all pass — re-measure and record the exact number) and `ctest --preset no-scheme --output-on-failure` (expect 8/8, unchanged).

- [ ] **Step 4: Update CHANGELOG.md** — add under the unreleased/Milestone 1 section

```markdown
- Milestone 1 Phase 3 Slice A: the emitter and the interpreter≡generated
  differential. A verified one-byte machine is normalized to a canonical IR with
  a 64-bit FNV-1a IR fingerprint, emitted as a complete importable `.sls` that
  imports only `(byte-machine runtime)` and constructs a direct executor through
  the new `byte-machine-make-compiled-machine/v1` ABI, and proven to match the
  reference interpreter across all 256 byte values in both the source and AOT
  lanes, plus the §9.6 end-to-end example. Decision 0010 records the ABI.
```

- [ ] **Step 5: Reconcile the design doc** — append a dated note to `docs/plans/milestone-1-phase-3-slice-a-design.md` §6 recording that decision 0010 was written, the ABI-mismatch-is-assertion-violation choice (§3.2 said "portable ABI-mismatch condition"; Slice A ships `assertion-violation` for the manifest-composition reason above — annotate, do not silently reword), and the measured totals (`release` count, scheme mutation 36/107).

- [ ] **Step 6: Commit**

```bash
git add docs/decisions/0010-direct-executor-abi.md test/support/cmake/SchemeMutationSuite.cmake CHANGELOG.md docs/plans/milestone-1-phase-3-slice-a-design.md
git commit -m "docs: decision 0010 (direct-executor ABI), Slice A totals and changelog"
```

---

## Self-Review

**1. Spec coverage.** Design §2 "In Slice A": normalizer (Task 1), emitter (Task 3), runtime ABI (Task 2), generated-name safety members 2/3 (Task 3, `reserved-member-2`/`-3` + binding validation tests/mutations), §9.6 end-to-end (Task 4 example), all-256 differential (Task 4). Deferred items (D6 hardening, D7 exhaustive proofs, property generator, placeholder deletion) are explicitly out and appear in no task. ✓

**2. Placeholder scan.** All code blocks are complete and were executed against real Chez 10.4.1 during planning (normalizer, `/v1` runtime, emitter, differential, example — source and AOT). The golden fingerprint `11963406767470843108` and every mutation `FIND` string are verbatim from that verified code. No TBD/TODO. ✓

**3. Type/name consistency.** `normalize-machine`, `normal-machine-*`, `normal-state-*`, `normal-dispatch-*`, `normal-error-code` are used identically across `normal-ir.sls`, `compile.sls`, and `normal-ir-tests.sps`. `byte-machine-make-compiled-machine/v1` / `byte-machine-make-feed-outcome/v1` appear identically in `runtime.sls`, the runtime test, the emitter's `reserved-member-2`, and the emitted text. Lane names match the `byte-machine.<layer>.<feature>.<backend>.<mode>` grammar with `layer ∈ {unit, differential, example}` (all in the `pr` filter). Manifest fragments compose without duplicate basenames. ✓

**4. Ambiguity.** The generated library is a run-time artifact under `BYTE_MACHINE_TEST_TMPDIR`, excluded from every `SOURCES` manifest (stated in File Structure and Task 4). The runtime refactor preserves Pass 32's three FIND anchors (called out in Task 2). Mutation totals are bumped only in Task 5, after all passes exist, so the between-task suite is never run against stale totals. ✓
