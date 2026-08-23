# Milestone 1 — Phase 2 (semantic core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, verify, and *interpret* the one-byte machine ("accept one exact byte and stop; reject every other byte at position 0") entirely in Scheme, with no code generation — proving the whole in-memory pipeline through the reference interpreter across all 256 byte values.

**Architecture:** Functional core, imperative shell. Immutable descriptors (`(byte-machine private ir)`), public constructors (`(byte-machine graph)`), a pure verifier producing structured diagnostics (`(byte-machine verify)`), a reference interpreter that turns a *verification* into a runtime-compatible compiled machine (`(byte-machine interpret)`), and a runtime that owns parser lifecycle, statuses, and the callback outcome singletons (`(byte-machine runtime)`). The interpreter is the semantic oracle; Phase 3's emitter will be differentially tested against it. Only the node kinds the one-byte machine uses (byte-dispatch, stop, error) are implemented; the rest arrive with later milestones.

**Tech Stack:** Chez Scheme, R6RS inline `.sls` libraries, the `(byte-machine test harness)`, CMake/CTest lanes (`chez.source` + `chez.aot`), the Scheme mutation suite.

## Global Constraints

- **R6RS inline `.sls`, no `include`.** Every library owns its own text (decision 0006). Product libraries are `(byte-machine …)` under `src/`; a name `(a b c)` maps to `src/a/b/c.sls`. R6RS forbids assigning an exported variable — reach mutable state through procedures.
- **Immutable-by-API descriptors, tagged-vector-behind-accessors.** Records are tagged vectors whose tag is a freshly-allocated `(vector 'sym)` (see `src/byte-machine/placeholder.sls`); no `define-record-type`. Constructors validate only local shape; cross-reference/graph/semantic checks belong to `verify-machine` (parent §9.1).
- **References are symbolic (parent §10.1).** Transition targets, error-declaration references, and the machine-wide default-EOF error are named by *symbol*, resolved against the declaration/node tables at verification time. This permits forward references and avoids object-identity fragility. (This M1 design choice resolves the parent plan's ambiguity: `make-error-node`'s and `make-machine`'s error arguments are declaration *names*, not declaration objects.)
- **Exact-value tests, mutation-witnessed.** A test that passes whether the code is right or wrong is worse than none (AGENTS.md). Seed an output before asserting it empty. Every decision gets a mutation the owning spec notices, asserting a measured signature (`EXPECT_STATUS`/`EXPECT_OUTPUT_MATCHES`). A guard that cannot be shown to guard is closed, not kept (AGENTS.md "close demonstrated gaps"). After adding an exit path, re-run the whole suite; update declared totals and their arithmetic comments in the same commit.
- **Name grammar `[a-z][a-z0-9-]*`** for machine/declaration/error names, codes, and branch keys (parent §10.1). Generated-name safety in Phase 2 checks this grammar plus reserved-set **member 1** only (R6RS source-mode identifiers); members 2–3 arrive in Phase 3 (Gate 0 §3.3 scoping note).
- **EOF is declared and verified but NOT executed.** `make-machine` requires a machine-wide `default-eof-error` (a declared error's name), and the verifier checks EOF targets, but `parser-finish!` and EOF execution belong to Milestone 2. Keep this line explicit; do not let a task absorb EOF semantics.
- **Exit-status vocabulary `0,1,2,3`.** Test programs end with `(harness-finish)`; a passing run exits 0, an assertion failure exits 1.
- **`no-scheme` stays green (8/8).** No product library may be required to configure the build layer; add no `cmake.direct` lane.
- **There is no `dev` *test* preset.** `dev` is a configure/build preset only. Run tests with `ctest --preset release` (complete selection) or `ctest --preset pr` (labels harness|unit|verify|differential|determinism|portability|example), filtered with `-R` as needed.
- Conventional Commits; run the suite before every commit; no new dependencies (no SRFI, no package manager).

## File Structure

| File | Library | Responsibility |
| --- | --- | --- |
| `src/byte-machine/private/conditions.sls` | `(byte-machine private conditions)` | the contract condition type + raiser used across the core |
| `src/byte-machine/private/ir.sls` | `(byte-machine private ir)` | descriptor representation, constructors (local-shape validation), accessors, predicates; the verification-result value |
| `src/byte-machine/graph.sls` | `(byte-machine graph)` | public façade re-exporting the M1 constructors |
| `src/byte-machine/runtime.sls` | `(byte-machine runtime)` | parser lifecycle, statuses, callback outcome singletons, the compiled-machine ABI |
| `src/byte-machine/verify.sls` | `(byte-machine verify)` | `verify-machine` and the M1 verification passes |
| `src/byte-machine/interpret.sls` | `(byte-machine interpret)` | `make-interpreted-machine`: verified IR → runtime-compatible compiled machine |

Dependency direction (parent §7.2): `private conditions` ← `private ir`/`interpret` (whoever raises contract violations); `private ir` ← graph/verify/interpret; `runtime` depends on nothing above it; `interpret` depends on `runtime`, `verify`, `private ir`, `private conditions`; `verify` depends on `private ir` only; `graph` re-exports `private ir`. (`private ir` imports `private conditions`, so a lane loading `ir.sls` transitively loads `conditions.sls` — both stay in the SOURCES manifest.)

Test programs live under `test/common/`; lanes are registered in `test/CMakeLists.txt`.

---

## Task 1: Contract conditions + descriptor IR

**Files:**
- Create: `src/byte-machine/private/conditions.sls`
- Create: `src/byte-machine/private/ir.sls`
- Create: `test/common/ir-tests.sps`
- Modify: `test/CMakeLists.txt` (register the `ir` unit lanes)

**Interfaces:**
- Produces (conditions): `(byte-machine-contract-violation who code detail)` (raises), `byte-machine-contract-condition?`, `byte-machine-contract-condition-code`, `byte-machine-contract-condition-who`, `byte-machine-contract-condition-detail`.
- Produces (ir constructors, exact signatures from parent §9.1; error references are *names*): `(make-machine name entry fields callbacks spans errors nodes default-eof-error source-label)` (`default-eof-error` is a declared error's *name*), `(make-byte-dispatch-node name cases fallback eof-target source-label)`, `(make-byte-case matcher edge source-label)`, `(make-exact-byte-matcher byte)`, `(make-edge target mode)`, `(make-stop-node name source-label)`, `(make-error-node name error-declaration source-label)` (`error-declaration` is a declared error's *name*), `(make-error-declaration name code reason source-label)`.
- Produces (ir accessors/predicates, consumed by verify/interpret): `machine?`, `machine-name`, `machine-entry`, `machine-nodes`, `machine-errors`, `machine-default-eof-error` (returns a symbol); `byte-dispatch-node?`, `byte-dispatch-node-name`, `byte-dispatch-node-cases`, `byte-dispatch-node-fallback`, `byte-dispatch-node-eof-target`; `byte-case-matcher`, `byte-case-edge`; `exact-byte-matcher?`, `exact-byte-matcher-byte`; `edge-target`, `edge-mode`; `stop-node?`, `stop-node-name`; `error-node?`, `error-node-name`, `error-node-error-name` (returns the referenced error's symbol); `error-declaration?`, `error-declaration-name`, `error-declaration-code`, `error-declaration-reason`; and `node?`, `node-name`.
- Produces (verification-result value): `(make-verification-result ok? diagnostics machine)`, `verification-result?`, `verification-result-ok?`, `verification-result-diagnostics`, `verification-result-machine`.

- [ ] **Step 1: Write the conditions library**

Create `src/byte-machine/private/conditions.sls`:

```scheme
;;; The byte-machine contract-violation condition (parent §9.4, M1 subset).
;;; A programmer error against the public API — bad argument shape, an
;;; unverified machine handed to the interpreter, and so on. Codes are symbols;
;;; tests compare the code and who, never rendered text.
(library (byte-machine private conditions)
  (export byte-machine-contract-violation
          byte-machine-contract-condition?
          byte-machine-contract-condition-code
          byte-machine-contract-condition-who
          byte-machine-contract-condition-detail)
  (import (rnrs))

  (define-condition-type &byte-machine-contract &condition
    make-byte-machine-contract-condition byte-machine-contract-condition?
    (code byte-machine-contract-condition-code)
    (who* byte-machine-contract-condition-who)
    (detail byte-machine-contract-condition-detail))

  (define (byte-machine-contract-violation who code detail)
    (raise (make-byte-machine-contract-condition code who detail))))
```

- [ ] **Step 2: Write the failing IR construction test**

Create `test/common/ir-tests.sps`. It round-trips the one-byte machine's pieces and asserts local-shape validation (including that a dispatch node cannot be built without an edge fallback — the construction-level witness for "missing fallback is rejected"). `check-equal` is `(check-equal what actual expected)`; `check-raises` is `(check-raises what predicate thunk)`:

```scheme
;;; Round-trip tests for the private descriptor IR: construct the pieces of the
;;; one-byte machine and read every field back. A name missing from
;;; (byte-machine private ir) is a load failure, not a silent gap.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine private ir)
        (byte-machine private conditions))

(harness-begin "unit.ir")

(harness-group "matchers and edges"
  (lambda ()
    (harness-case "an exact-byte matcher carries its byte"
      (lambda ()
        (check-equal "byte" (exact-byte-matcher-byte (make-exact-byte-matcher 0)) 0)))
    (harness-case "an edge carries its target and mode"
      (lambda ()
        (let ((e (make-edge 'stop 'advance)))
          (check-equal "target" (edge-target e) 'stop)
          (check-equal "mode" (edge-mode e) 'advance))))))

(harness-group "constructor local-shape validation"
  (lambda ()
    (harness-case "a byte above 255 is rejected"
      (lambda ()
        (check-raises "out of range"
                      byte-machine-contract-condition?
                      (lambda () (make-exact-byte-matcher 256)))))
    (harness-case "an unknown edge mode is rejected"
      (lambda ()
        (check-raises "bad mode"
                      byte-machine-contract-condition?
                      (lambda () (make-edge 'stop 'teleport)))))
    (harness-case "a dispatch node cannot be built without an edge fallback"
      (lambda ()
        (check-raises "no fallback"
                      byte-machine-contract-condition?
                      (lambda () (make-byte-dispatch-node 'start '() 'not-an-edge #f #f)))))))

(harness-group "the one-byte machine descriptor"
  (lambda ()
    (harness-case "the machine reads back its entry, nodes, and default eof error name"
      (lambda ()
        (let* ((accept-edge (make-edge 'stop 'advance))
               (accept-case (make-byte-case (make-exact-byte-matcher 0) accept-edge #f))
               (reject-edge (make-edge 'reject 'reexecute))
               (start (make-byte-dispatch-node 'start (list accept-case) reject-edge #f #f))
               (stop (make-stop-node 'stop #f))
               (eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (reject (make-error-node 'reject 'rejected #f))
               (m (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
                                (list start stop reject) 'default-eof #f)))
          (check-equal "entry" (machine-entry m) 'start)
          (check-equal "node count" (length (machine-nodes m)) 3)
          (check-equal "default eof error name" (machine-default-eof-error m) 'default-eof)
          (check-equal "error node references the reject declaration by name"
                       (error-node-error-name reject) 'rejected)
          (check-equal "start fallback target"
                       (edge-target (byte-dispatch-node-fallback start)) 'reject))))))

(harness-finish)
```

- [ ] **Step 3: Run it and confirm it fails**

Run:
```bash
cmake --preset dev && cmake --build --preset dev
ctest --preset release -R "unit.ir" --output-on-failure
```
Expected: FAIL — the lane is not registered yet / `(byte-machine private ir)` not found. (You register the lane in Step 5.)

- [ ] **Step 4: Write the IR library**

Create `src/byte-machine/private/ir.sls`. Fresh-vector tag pattern; constructors validate local shape and raise `byte-machine-contract-violation`; error references are symbols:

```scheme
;;; Immutable source-IR descriptors (parent §9.1, §10), M1 subset: the machine,
;;; byte-dispatch/stop/error nodes, exact-byte matcher, edge, error
;;; declaration, and the verification-result value. Tagged vectors behind
;;; accessors (like src/byte-machine/placeholder.sls); the tag is a freshly
;;; allocated vector so a second copy gets a second identity. Constructors
;;; validate only local shape; graph/cross-reference checks live in verify.
;;; Error references (error nodes, the machine default eof error) are symbolic
;;; NAMES resolved by verify against the error declarations (parent §10.1).
(library (byte-machine private ir)
  (export make-machine machine? machine-name machine-entry machine-fields
          machine-callbacks machine-spans machine-errors machine-nodes
          machine-default-eof-error machine-source-label
          make-byte-dispatch-node byte-dispatch-node? byte-dispatch-node-name
          byte-dispatch-node-cases byte-dispatch-node-fallback
          byte-dispatch-node-eof-target
          make-byte-case byte-case? byte-case-matcher byte-case-edge
          make-exact-byte-matcher exact-byte-matcher? exact-byte-matcher-byte
          make-edge edge? edge-target edge-mode
          make-stop-node stop-node? stop-node-name
          make-error-node error-node? error-node-name error-node-error-name
          make-error-declaration error-declaration? error-declaration-name
          error-declaration-code error-declaration-reason
          node? node-name
          make-verification-result verification-result? verification-result-ok?
          verification-result-diagnostics verification-result-machine)
  (import (rnrs)
          (byte-machine private conditions))

  (define (tag sym) (vector sym))
  (define (tagged? t x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) t)))
  (define (require-symbol who what v)
    (unless (symbol? v)
      (byte-machine-contract-violation who 'invalid-argument what))
    v)

  ;; --- exact-byte matcher ---
  (define exact-byte-matcher-tag (tag 'byte-machine-exact-byte-matcher))
  (define (make-exact-byte-matcher byte)
    (unless (and (integer? byte) (exact? byte) (<= 0 byte 255))
      (byte-machine-contract-violation 'make-exact-byte-matcher 'invalid-argument 'byte))
    (vector exact-byte-matcher-tag byte))
  (define (exact-byte-matcher? x) (tagged? exact-byte-matcher-tag x))
  (define (exact-byte-matcher-byte m) (vector-ref m 1))

  ;; --- edge ---
  (define edge-tag (tag 'byte-machine-edge))
  (define (make-edge target mode)
    (require-symbol 'make-edge 'target target)
    (unless (memq mode '(advance reexecute))
      (byte-machine-contract-violation 'make-edge 'invalid-argument 'mode))
    (vector edge-tag target mode))
  (define (edge? x) (tagged? edge-tag x))
  (define (edge-target e) (vector-ref e 1))
  (define (edge-mode e) (vector-ref e 2))

  ;; --- byte case ---
  (define byte-case-tag (tag 'byte-machine-byte-case))
  (define (make-byte-case matcher edge source-label)
    (unless (exact-byte-matcher? matcher)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'matcher))
    (unless (edge? edge)
      (byte-machine-contract-violation 'make-byte-case 'invalid-argument 'edge))
    (vector byte-case-tag matcher edge source-label))
  (define (byte-case? x) (tagged? byte-case-tag x))
  (define (byte-case-matcher c) (vector-ref c 1))
  (define (byte-case-edge c) (vector-ref c 2))

  ;; --- byte-dispatch node ---
  (define byte-dispatch-node-tag (tag 'byte-machine-byte-dispatch-node))
  (define (make-byte-dispatch-node name cases fallback eof-target source-label)
    (require-symbol 'make-byte-dispatch-node 'name name)
    (unless (and (list? cases) (for-all byte-case? cases))
      (byte-machine-contract-violation 'make-byte-dispatch-node 'invalid-argument 'cases))
    (unless (edge? fallback)
      (byte-machine-contract-violation 'make-byte-dispatch-node 'invalid-argument 'fallback))
    ;; eof-target is a symbol (a node name) or #f (machine default eof error).
    (unless (or (symbol? eof-target) (eq? eof-target #f))
      (byte-machine-contract-violation 'make-byte-dispatch-node 'invalid-argument 'eof-target))
    (vector byte-dispatch-node-tag name cases fallback eof-target source-label))
  (define (byte-dispatch-node? x) (tagged? byte-dispatch-node-tag x))
  (define (byte-dispatch-node-name n) (vector-ref n 1))
  (define (byte-dispatch-node-cases n) (vector-ref n 2))
  (define (byte-dispatch-node-fallback n) (vector-ref n 3))
  (define (byte-dispatch-node-eof-target n) (vector-ref n 4))

  ;; --- stop node ---
  (define stop-node-tag (tag 'byte-machine-stop-node))
  (define (make-stop-node name source-label)
    (require-symbol 'make-stop-node 'name name)
    (vector stop-node-tag name source-label))
  (define (stop-node? x) (tagged? stop-node-tag x))
  (define (stop-node-name n) (vector-ref n 1))

  ;; --- error node (references a declaration by NAME) ---
  (define error-node-tag (tag 'byte-machine-error-node))
  (define (make-error-node name error-declaration source-label)
    (require-symbol 'make-error-node 'name name)
    (require-symbol 'make-error-node 'error-declaration error-declaration)
    (vector error-node-tag name error-declaration source-label))
  (define (error-node? x) (tagged? error-node-tag x))
  (define (error-node-name n) (vector-ref n 1))
  (define (error-node-error-name n) (vector-ref n 2))

  ;; --- error declaration ---
  (define error-declaration-tag (tag 'byte-machine-error-declaration))
  (define (make-error-declaration name code reason source-label)
    (require-symbol 'make-error-declaration 'name name)
    (require-symbol 'make-error-declaration 'code code)
    (unless (string? reason)
      (byte-machine-contract-violation 'make-error-declaration 'invalid-argument 'reason))
    (vector error-declaration-tag name code reason source-label))
  (define (error-declaration? x) (tagged? error-declaration-tag x))
  (define (error-declaration-name d) (vector-ref d 1))
  (define (error-declaration-code d) (vector-ref d 2))
  (define (error-declaration-reason d) (vector-ref d 3))

  ;; --- node dispatch ---
  (define (node? x)
    (or (byte-dispatch-node? x) (stop-node? x) (error-node? x)))
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          (else (byte-machine-contract-violation 'node-name 'invalid-argument 'node))))

  ;; --- machine (default-eof-error is a declared error NAME) ---
  (define machine-tag (tag 'byte-machine-machine))
  (define machine-ir-version 1)     ; stamped; v0.1 callers do not override (§9.1)
  (define (make-machine name entry fields callbacks spans errors nodes
                        default-eof-error source-label)
    (require-symbol 'make-machine 'name name)
    (require-symbol 'make-machine 'entry entry)
    (require-symbol 'make-machine 'default-eof-error default-eof-error)
    (for-each (lambda (l) (unless (list? l)
                            (byte-machine-contract-violation 'make-machine
                                                             'invalid-argument 'collection)))
              (list fields callbacks spans errors nodes))
    (unless (for-all node? nodes)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'nodes))
    (unless (for-all error-declaration? errors)
      (byte-machine-contract-violation 'make-machine 'invalid-argument 'errors))
    (vector machine-tag machine-ir-version name entry fields callbacks spans
            errors nodes default-eof-error source-label))
  (define (machine? x) (tagged? machine-tag x))
  (define (machine-name m) (vector-ref m 2))
  (define (machine-entry m) (vector-ref m 3))
  (define (machine-fields m) (vector-ref m 4))
  (define (machine-callbacks m) (vector-ref m 5))
  (define (machine-spans m) (vector-ref m 6))
  (define (machine-errors m) (vector-ref m 7))
  (define (machine-nodes m) (vector-ref m 8))
  (define (machine-default-eof-error m) (vector-ref m 9))
  (define (machine-source-label m) (vector-ref m 10))

  ;; --- verification result (carries the machine, per §9.2) ---
  (define verification-result-tag (tag 'byte-machine-verification-result))
  (define (make-verification-result ok? diagnostics machine)
    (vector verification-result-tag ok? diagnostics machine))
  (define (verification-result? x) (tagged? verification-result-tag x))
  (define (verification-result-ok? v) (vector-ref v 1))
  (define (verification-result-diagnostics v) (vector-ref v 2))
  (define (verification-result-machine v) (vector-ref v 3)))
```

- [ ] **Step 5: Register the `ir` unit lanes (source + AOT)**

In `test/CMakeLists.txt`, define the core manifest fragment near the top-of-file manifest definitions:

```cmake
# Milestone 1 semantic-core libraries (Phase 2).
set(BYTE_MACHINE_CORE_PRIVATE
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/conditions.sls"
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/private/ir.sls")
```

Then register (the `SOURCES` manifest lists every `.sls` the program loads plus the program; basenames are unique within the lane):

```cmake
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.ir.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_PRIVATE}
          "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.ir.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_PRIVATE}
          "${CMAKE_SOURCE_DIR}/test/common/ir-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 6: Run the lanes to green and commit**

Run:
```bash
cmake --preset dev && cmake --build --preset dev
ctest --preset release -R "unit.ir" --output-on-failure
```
Expected: PASS, both `.chez.source` and `.chez.aot`.

```bash
git add src/byte-machine/private/conditions.sls src/byte-machine/private/ir.sls test/common/ir-tests.sps test/CMakeLists.txt
git commit -m "feat: private contract conditions and source-IR descriptors (M1 subset)"
```

---

## Task 2: The public `(byte-machine graph)` façade

**Files:**
- Create: `src/byte-machine/graph.sls`
- Create: `test/common/graph-tests.sps`
- Modify: `test/CMakeLists.txt` (register `unit.graph` lanes)

**Interfaces:**
- Consumes: all `make-*` constructors from Task 1.
- Produces: `(byte-machine graph)` exporting exactly the M1 constructors (`make-machine`, `make-byte-dispatch-node`, `make-byte-case`, `make-exact-byte-matcher`, `make-edge`, `make-stop-node`, `make-error-node`, `make-error-declaration`). Consumed by Tasks 4–5 and Phase 3.

- [ ] **Step 1: Write the failing test**

Create `test/common/graph-tests.sps`. Because references are symbolic, the machine a grammar author writes is naturally verifiable — declarations are bound once and referenced by name:

```scheme
;;; The public graph façade builds the one-byte machine with no private import.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (only (byte-machine private ir) machine? machine-entry machine-default-eof-error))

(harness-begin "unit.graph")

(harness-group "graph façade"
  (lambda ()
    (harness-case "the one-byte machine is constructible through (byte-machine graph)"
      (lambda ()
        (let* ((eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
               (rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
               (m (make-machine
                   'one-byte 'start '() '() '()
                   (list eof-decl rej-decl)
                   (list (make-byte-dispatch-node
                          'start
                          (list (make-byte-case (make-exact-byte-matcher 0)
                                                (make-edge 'stop 'advance) #f))
                          (make-edge 'reject 'reexecute) #f #f)
                         (make-stop-node 'stop #f)
                         (make-error-node 'reject 'rejected #f))
                   'default-eof #f)))
          (check "is a machine" (machine? m))
          (check-equal "entry" (machine-entry m) 'start)
          (check-equal "default eof name" (machine-default-eof-error m) 'default-eof))))))

(harness-finish)
```

- [ ] **Step 2: Run and confirm failure**

Run: `cmake --build --preset dev && ctest --preset release -R "unit.graph" --output-on-failure`
Expected: FAIL — lane unregistered / `(byte-machine graph)` not found.

- [ ] **Step 3: Write the façade**

Create `src/byte-machine/graph.sls`:

```scheme
;;; (byte-machine graph): the public construction API. It re-exports the M1
;;; source-IR constructors from the private ir library so grammar authors build
;;; machines without touching internals. Constructors validate local shape only;
;;; verification is (byte-machine verify)'s job (parent §9.1).
(library (byte-machine graph)
  (export make-machine make-byte-dispatch-node make-byte-case
          make-exact-byte-matcher make-edge make-stop-node make-error-node
          make-error-declaration)
  (import (only (byte-machine private ir)
                make-machine make-byte-dispatch-node make-byte-case
                make-exact-byte-matcher make-edge make-stop-node make-error-node
                make-error-declaration)))
```

- [ ] **Step 4: Register the lanes**

```cmake
set(BYTE_MACHINE_CORE_GRAPH
    ${BYTE_MACHINE_CORE_PRIVATE}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/graph.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.graph.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_GRAPH}
          "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.graph.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_GRAPH}
          "${CMAKE_SOURCE_DIR}/test/common/graph-tests.sps"
  TIMEOUT 120)
```

- [ ] **Step 5: Run to green and commit**

Run: `cmake --preset dev && cmake --build --preset dev && ctest --preset release -R "unit.graph" --output-on-failure`
Expected: PASS (source + aot).

```bash
git add src/byte-machine/graph.sls test/common/graph-tests.sps test/CMakeLists.txt
git commit -m "feat: public (byte-machine graph) construction façade"
```

---

## Task 3: The runtime — parser lifecycle, statuses, compiled-machine ABI

**Files:**
- Create: `src/byte-machine/runtime.sls`
- Create: `test/common/runtime-tests.sps`
- Modify: `test/CMakeLists.txt` (register `unit.runtime` lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new runtime mutation pass; bump totals)

**Interfaces:**
- Produces (compiled-machine ABI): `(make-compiled-machine op)` where `op` is a closure answering — `(op 'entry)` → entry node name (symbol); `(op 'kind name)` → `dispatch` | `stop` | `error`; `(op 'dispatch name byte)` → an edge-transition `(cons target-name mode)`, mode `advance`/`reexecute`; `(op 'error-value name)` → **the referenced error declaration's code symbol** (canonical: the *code*, not the declaration name). `compiled-machine?`.
- Produces (parser API, parent §9.3): `(make-parser compiled-machine callback-bindings user-context)` → parser; `(parser-feed! parser bytevector start end)` → parser-result; `parser-result-status`, `parser-result-next`, `parser-result-consumed`, `parser-result-stream-offset`, `parser-result-error`.
- Produces (callback outcome singletons, contract stubs per design §5): `callback-continue`, `callback-pause` (allocation-free `eq?` singletons; execution arrives with the callbacks milestone).
- Statuses are the symbols `stopped`, `error`, `need-input` (M1); `paused`/`finished` arrive later.

- [ ] **Step 1: Write the failing runtime test using a hand-built compiled machine**

Create `test/common/runtime-tests.sps`. The stub `op` returns the error declaration's *code* (`unexpected-byte`) for `'error-value`, matching the interpreter's canonical meaning (Task 5). Seed the empty-slice result variable:

```scheme
;;; Runtime parser lifecycle over a hand-built compiled-machine stub, so the
;;; loop is witnessed independently of the interpreter (Task 5 supplies the real
;;; op). The stub encodes the one-byte machine: byte 0 advances to stop; any
;;; other byte reexecutes into the error node.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine runtime))

(harness-begin "unit.runtime")

(define (one-byte-op msg . args)
  (case msg
    ((entry) 'start)
    ((kind) (case (car args) ((start) 'dispatch) ((stop) 'stop) ((reject) 'error)))
    ((dispatch)
     (let ((byte (cadr args)))
       (if (= byte 0) (cons 'stop 'advance) (cons 'reject 'reexecute))))
    ((error-value) 'unexpected-byte)
    (else (assertion-violation 'one-byte-op "bad message" msg))))

(define (feed-byte b)
  (let ((p (make-parser (make-compiled-machine one-byte-op) '() #f)))
    (parser-feed! p (make-bytevector 1 b) 0 1)))

(harness-group "callback outcome singletons"
  (lambda ()
    (harness-case "continue and pause are stable, distinct singletons"
      (lambda ()
        (check "continue is itself" (eq? callback-continue callback-continue))
        (check "pause is itself" (eq? callback-pause callback-pause))
        (check "continue is not pause" (not (eq? callback-continue callback-pause)))))))

(harness-group "one-byte parser lifecycle"
  (lambda ()
    (harness-case "the accepted byte stops after consuming one byte"
      (lambda ()
        (let ((r (feed-byte 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1)
          (check-equal "next" (parser-result-next r) 1))))
    (harness-case "a rejected byte errors at position 0 without consuming"
      (lambda ()
        (let ((r (feed-byte 65)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "stream offset" (parser-result-stream-offset r) 0)
          (check-equal "error value" (parser-result-error r) 'unexpected-byte))))
    (harness-case "an empty slice needs input and reports no result yet"
      (lambda ()
        (let* ((p (make-parser (make-compiled-machine one-byte-op) '() #f))
               (returned 'not-yet-run))
          (set! returned (parser-result-status (parser-feed! p (make-bytevector 0) 0 0)))
          (check-equal "status" returned 'need-input))))))

(harness-finish)
```

- [ ] **Step 2: Run and confirm failure**

Run: `cmake --build --preset dev && ctest --preset release -R "unit.runtime" --output-on-failure`
Expected: FAIL — lane unregistered / `(byte-machine runtime)` not found.

- [ ] **Step 3: Write the runtime**

Create `src/byte-machine/runtime.sls`:

```scheme
;;; (byte-machine runtime): parser lifecycle, statuses, callback outcome
;;; singletons, and the compiled-machine ABI. Independent of graph/verify/
;;; compile (parent §7.2). The interpreter (Task 5) and, later, generated code
;;; both produce a compiled-machine whose `op` closure answers the messages
;;; make-parser drives, so the two executors are identical by construction.
(library (byte-machine runtime)
  (export make-compiled-machine compiled-machine?
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

  ;; --- compiled machine (the ABI the executor implements) ---
  (define compiled-machine-tag (tag 'byte-machine-compiled-machine))
  (define (make-compiled-machine op)
    (unless (procedure? op)
      (assertion-violation 'make-compiled-machine "op must be a procedure" op))
    (vector compiled-machine-tag op))
  (define (compiled-machine? x) (tagged? compiled-machine-tag x))
  (define (compiled-machine-op cm) (vector-ref cm 1))

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
  (define parser-tag (tag 'byte-machine-parser))
  (define (make-parser compiled-machine callback-bindings user-context)
    (unless (compiled-machine? compiled-machine)
      (assertion-violation 'make-parser "not a compiled machine" compiled-machine))
    (let ((op (compiled-machine-op compiled-machine)))
      (vector parser-tag op (op 'entry) 0 #f)))
  (define (parser? x) (tagged? parser-tag x))
  (define (parser-op p) (vector-ref p 1))
  (define (parser-current p) (vector-ref p 2))
  (define (parser-set-current! p v) (vector-set! p 2 v))
  (define (parser-offset p) (vector-ref p 3))
  (define (parser-set-offset! p v) (vector-set! p 3 v))
  (define (parser-sticky p) (vector-ref p 4))
  (define (parser-set-sticky! p v) (vector-set! p 4 v))

  (define (parser-feed! parser bv start end)
    (unless (and (bytevector? bv) (<= 0 start end (bytevector-length bv)))
      (assertion-violation 'parser-feed! "invalid slice" (list start end)))
    (or (parser-sticky parser)
        (let ((op (parser-op parser)))
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
                                           (op 'kind node))))))))))
```

Note: a zero-progress (reexecute-only) cycle cannot loop forever here only because Task 4's verifier rejects such machines before interpretation; the runtime does not itself bound iteration.

- [ ] **Step 4: Register the lanes and run to green**

```cmake
set(BYTE_MACHINE_CORE_RUNTIME
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/runtime.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.runtime.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_RUNTIME}
          "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.runtime.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_RUNTIME}
          "${CMAKE_SOURCE_DIR}/test/common/runtime-tests.sps"
  TIMEOUT 120)
```

Run: `cmake --preset dev && cmake --build --preset dev && ctest --preset release -R "unit.runtime" --output-on-failure`
Expected: PASS (source + aot).

- [ ] **Step 5: Add a runtime mutation pass**

The runtime makes decisions (advance consumes a byte; the `>= pos end` need-input guard) that must be witnessed. Add a **new** pass to `test/support/cmake/SchemeMutationSuite.cmake`. Model the verify command on the **placeholder pass** (read `rg -n "placeholder" test/support/cmake/SchemeMutationSuite.cmake` — it supplies both `--library-root ${STAGE_DIR}/test/support/harness` and `--library-root ${STAGE_DIR}/src`, `--object-guard ${GUARD_DIR}`, `--program ${STAGE_DIR}/test/common/runtime-tests.sps`). Then declare, between a fresh `byte_machine_mutation_reset` and its `byte_machine_mutation_run`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: advance does not consume the byte"
  FIND [[(loop (+ pos 1))]]
  REPLACE [[(loop pos)]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "consumed")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: need-input becomes a spurious stop"
  FIND [[(make-parser-result 'need-input pos]]
  REPLACE [[(make-parser-result 'stopped pos]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "need-input")
```

Increment `EXPECTED_PASSES` by 1 and `EXPECTED_MUTATIONS` by 2, updating the arithmetic comment. Re-read the current values first (`rg -n "EXPECTED_PASSES|EXPECTED_MUTATIONS" test/support/cmake/SchemeMutationSuite.cmake`).

- [ ] **Step 6: Run the mutation suite and the whole suite, then commit**

Run:
```bash
cmake --build --preset dev
ctest --preset release -R scheme-mutation --output-on-failure
ctest --preset release --output-on-failure
```
Expected: both runtime mutations caught; declared totals match; no regression.

```bash
git add src/byte-machine/runtime.sls test/common/runtime-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: runtime parser lifecycle and compiled-machine ABI, mutation-witnessed"
```

---

## Task 4: The verifier

**Files:**
- Create: `src/byte-machine/verify.sls`
- Create: `test/common/verify-tests.sps`
- Modify: `test/CMakeLists.txt` (register `verify.rejections` lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new verify mutation pass; bump totals)

**Interfaces:**
- Consumes: the IR accessors from Task 1, conditions from Task 1.
- Produces: `(verify-machine machine)` → verification-result; `(verification-ok? verification)`; `(verification-diagnostics verification)`; `(verification-machine verification)` (the machine, for the interpreter). Diagnostics: `diagnostic?`, `diagnostic-code`, `diagnostic-node`, `diagnostic-message`.
- **Stable M1 diagnostic codes — exactly those the passes emit:** `invalid-shape`, `duplicate-name`, `missing-target`, `duplicate-error-declaration`, `missing-error-declaration`, `overlapping-cases`, `unreachable-node`, `zero-progress-cycle`, `invalid-eof-target`, `invalid-name`. (No `missing-fallback`/`terminal-has-outgoing`: those malformed shapes are unconstructible — `make-byte-dispatch-node` requires an edge fallback, and stop/error nodes carry no outgoing edges — so they are rejected at *construction*, witnessed in Task 1, not by a verify pass.)

- [ ] **Step 1: Write the failing verifier tests**

Create `test/common/verify-tests.sps`. Cover the valid machine (ok, no diagnostics) and one rejection per decision, asserting the exact code (parent §16.4). All error references are by name; the errors list holds both declarations:

```scheme
;;; verify-machine over the one-byte machine and its broken variants. Tests
;;; compare diagnostic codes, never rendered text (parent §16.4).
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify))

(harness-begin "verify.rejections")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define errs (list eof-decl rej-decl))
(define accept-case
  (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
(define (dispatch cases fallback) (make-byte-dispatch-node 'start cases fallback #f #f))
(define (one-byte-nodes fallback)
  (list (dispatch (list accept-case) fallback)
        (make-stop-node 'stop #f)
        (make-error-node 'reject 'rejected #f)))
(define (machine* name nodes eof-name)
  (make-machine name 'start '() '() '() errs nodes eof-name #f))
(define (machine nodes) (machine* 'one-byte nodes 'default-eof))

(define (codes m) (map diagnostic-code (verification-diagnostics (verify-machine m))))
(define (has-code? m code) (and (memq code (codes m)) #t))

(harness-group "the valid one-byte machine"
  (lambda ()
    (harness-case "verifies with no diagnostics"
      (lambda ()
        (let ((v (verify-machine (machine (one-byte-nodes (make-edge 'reject 'reexecute))))))
          (check "ok" (verification-ok? v))
          (let ((ds 'seed))
            (set! ds (verification-diagnostics v))
            (check "no diagnostics" (null? ds))))))))

(harness-group "rejections, one per decision"
  (lambda ()
    (harness-case "a fallback target that names no node is missing-target"
      (lambda ()
        (check "missing-target"
               (has-code? (machine (one-byte-nodes (make-edge 'nowhere 'reexecute)))
                          'missing-target))))
    (harness-case "two exact cases on the same byte overlap"
      (lambda ()
        (let ((dup (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f)))
          (check "overlapping-cases"
                 (has-code? (machine (list (dispatch (list accept-case dup)
                                                     (make-edge 'reject 'reexecute))
                                           (make-stop-node 'stop #f)
                                           (make-error-node 'reject 'rejected #f)))
                            'overlapping-cases)))))
    (harness-case "an unreachable node is rejected"
      (lambda ()
        (check "unreachable-node"
               (has-code? (machine (append (one-byte-nodes (make-edge 'reject 'reexecute))
                                           (list (make-stop-node 'orphan #f))))
                          'unreachable-node))))
    (harness-case "a reexecute self-loop is a zero-progress cycle"
      (lambda ()
        (check "zero-progress-cycle"
               (has-code?
                (machine (list (dispatch (list (make-byte-case (make-exact-byte-matcher 0)
                                                               (make-edge 'start 'reexecute) #f))
                                         (make-edge 'start 'reexecute))
                               (make-stop-node 'stop #f)
                               (make-error-node 'reject 'rejected #f)))
                'zero-progress-cycle))))
    (harness-case "two nodes sharing a name is duplicate-name"
      (lambda ()
        (check "duplicate-name"
               (has-code? (machine (list (dispatch (list accept-case)
                                                   (make-edge 'reject 'reexecute))
                                         (make-stop-node 'stop #f)
                                         (make-stop-node 'stop #f)   ; duplicate 'stop
                                         (make-error-node 'reject 'rejected #f)))
                          'duplicate-name))))
    (harness-case "an error node naming an undeclared error is missing-error-declaration"
      (lambda ()
        (check "missing-error-declaration"
               (has-code? (machine (list (dispatch (list accept-case)
                                                   (make-edge 'reject 'reexecute))
                                         (make-stop-node 'stop #f)
                                         (make-error-node 'reject 'ghost #f)))  ; no 'ghost decl
                          'missing-error-declaration))))
    (harness-case "a default-eof-error naming no declared error is invalid-eof-target"
      (lambda ()
        (check "invalid-eof-target"
               (has-code? (machine* 'one-byte (one-byte-nodes (make-edge 'reject 'reexecute))
                                    'ghost-eof)
                          'invalid-eof-target))))
    (harness-case "an uppercase machine name is invalid-name"
      (lambda ()
        (check "invalid-name"
               (has-code? (machine* 'One-Byte (one-byte-nodes (make-edge 'reject 'reexecute))
                                    'default-eof)
                          'invalid-name))))))

(harness-finish)
```

- [ ] **Step 2: Run and confirm failure**

Run: `cmake --build --preset dev && ctest --preset release -R "verify.rejections" --output-on-failure`
Expected: FAIL — lane unregistered / `(byte-machine verify)` not found.

- [ ] **Step 3: Write the verifier**

Create `src/byte-machine/verify.sls`:

```scheme
;;; (byte-machine verify): structural verification of a source machine into a
;;; verification-result carrying diagnostics and the machine (parent §16). M1
;;; subset of §16.2/§16.3: schema, name resolution (nodes + error references),
;;; exact-byte overlap, reachability, zero-progress cycles, terminal/EOF shape,
;;; and generated-name safety (reserved-set member 1 — Gate 0 §3.3). Error
;;; references are symbolic names resolved against the error declarations.
;;; Diagnostics are compared by code, never by text.
(library (byte-machine verify)
  (export verify-machine verification-ok? verification-diagnostics
          verification-machine
          diagnostic? diagnostic-code diagnostic-node diagnostic-message)
  (import (rnrs)
          (byte-machine private ir))

  ;; --- diagnostics ---
  (define diagnostic-tag (vector 'byte-machine-diagnostic))
  (define (make-diagnostic code node message) (vector diagnostic-tag code node message))
  (define (diagnostic? x)
    (and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) diagnostic-tag)))
  (define (diagnostic-code d) (vector-ref d 1))
  (define (diagnostic-node d) (vector-ref d 2))
  (define (diagnostic-message d) (vector-ref d 3))

  ;; --- name grammar [a-z][a-z0-9-]* and reserved-set member 1 ---
  (define reserved-member-1
    '(library import export define define-syntax let let* letrec lambda quote
      if begin set! cond case and or when unless do quasiquote unquote))
  (define (lower-alpha? c) (and (char>=? c #\a) (char<=? c #\z)))
  (define (name-char? c)
    (or (lower-alpha? c) (and (char>=? c #\0) (char<=? c #\9)) (char=? c #\-)))
  (define (valid-name? sym)
    (let ((s (symbol->string sym)))
      (and (> (string-length s) 0)
           (lower-alpha? (string-ref s 0))
           (let loop ((i 1))
             (or (>= i (string-length s))
                 (and (name-char? (string-ref s i)) (loop (+ i 1)))))
           (not (memq sym reserved-member-1)))))

  ;; --- helpers ---
  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (error-names m) (map error-declaration-name (machine-errors m)))
  (define (node-out-targets n)
    (cond ((byte-dispatch-node? n)
           (append (map (lambda (c) (edge-target (byte-case-edge c)))
                        (byte-dispatch-node-cases n))
                   (list (edge-target (byte-dispatch-node-fallback n)))))
          (else '())))

  ;; PASS 1: schema.
  (define (pass-schema m)
    (if (machine? m) '() (list (make-diagnostic 'invalid-shape #f "not a machine"))))

  ;; PASS 2: name resolution — duplicate node names; duplicate error names; every
  ;; transition target and error reference resolves.
  (define (pass-names m)
    (let ((nodes (machine-nodes m)) (enames (error-names m)))
      (append
       (let loop ((ns nodes) (seen '()) (out '()))
         (if (null? ns) (reverse out)
             (let ((nm (node-name (car ns))))
               (loop (cdr ns) (cons nm seen)
                     (if (memq nm seen)
                         (cons (make-diagnostic 'duplicate-name nm "duplicate node name") out)
                         out)))))
       (let loop ((es enames) (seen '()) (out '()))
         (if (null? es) (reverse out)
             (loop (cdr es) (cons (car es) seen)
                   (if (memq (car es) seen)
                       (cons (make-diagnostic 'duplicate-error-declaration (car es)
                                              "duplicate error declaration name") out)
                       out))))
       (apply append
              (map (lambda (n)
                     (filter values
                             (map (lambda (t)
                                    (if (lookup nodes t) #f
                                        (make-diagnostic 'missing-target t "no such node")))
                                  (node-out-targets n))))
                   nodes))
       (if (lookup nodes (machine-entry m)) '()
           (list (make-diagnostic 'missing-target (machine-entry m) "entry names no node")))
       (apply append
              (map (lambda (n)
                     (if (and (error-node? n) (not (memq (error-node-error-name n) enames)))
                         (list (make-diagnostic 'missing-error-declaration (node-name n)
                                                "error node names an undeclared error"))
                         '()))
                   nodes)))))

  ;; PASS 3: exact-byte overlap within a dispatch node.
  (define (pass-overlap m)
    (apply append
           (map (lambda (n)
                  (if (byte-dispatch-node? n)
                      (let loop ((cs (byte-dispatch-node-cases n)) (seen '()) (out '()))
                        (if (null? cs) out
                            (let ((b (exact-byte-matcher-byte (byte-case-matcher (car cs)))))
                              (loop (cdr cs) (cons b seen)
                                    (if (memv b seen)
                                        (cons (make-diagnostic 'overlapping-cases (node-name n)
                                                               "two cases match the same byte") out)
                                        out)))))
                      '()))
                (machine-nodes m))))

  ;; PASS 4: reachability from entry.
  (define (pass-reachability m)
    (let ((nodes (machine-nodes m)) (reached '()))
      (let visit ((name (machine-entry m)))
        (when (and (lookup nodes name) (not (memq name reached)))
          (set! reached (cons name reached))
          (for-each visit (node-out-targets (lookup nodes name)))))
      (filter values
              (map (lambda (n)
                     (if (memq (node-name n) reached) #f
                         (make-diagnostic 'unreachable-node (node-name n) "node is unreachable")))
                   nodes))))

  ;; PASS 5: zero-progress cycles — a reexecute-only cycle consumes no byte.
  (define (pass-zero-progress m)
    (let ((nodes (machine-nodes m)))
      (define (reexec-targets n)
        (if (byte-dispatch-node? n)
            (append (map (lambda (c) (edge-target (byte-case-edge c)))
                         (filter (lambda (c) (eq? (edge-mode (byte-case-edge c)) 'reexecute))
                                 (byte-dispatch-node-cases n)))
                    (if (eq? (edge-mode (byte-dispatch-node-fallback n)) 'reexecute)
                        (list (edge-target (byte-dispatch-node-fallback n))) '()))
            '()))
      (define (reaches-self? start)
        (let loop ((frontier (reexec-targets (lookup nodes start))) (seen '()))
          (cond ((null? frontier) #f)
                ((eq? (car frontier) start) #t)
                ((memq (car frontier) seen) (loop (cdr frontier) seen))
                (else (let ((n (lookup nodes (car frontier))))
                        (loop (append (if n (reexec-targets n) '()) (cdr frontier))
                              (cons (car frontier) seen)))))))
      (filter values
              (map (lambda (n)
                     (if (and (byte-dispatch-node? n) (reaches-self? (node-name n)))
                         (make-diagnostic 'zero-progress-cycle (node-name n)
                                          "reexecute-only cycle makes no progress")
                         #f))
                   nodes))))

  ;; PASS 6: EOF shape — the machine default eof error names a declared error;
  ;; a dispatch eof-target (when a symbol) resolves to a node.
  (define (pass-eof m)
    (let ((nodes (machine-nodes m)))
      (append
       (if (memq (machine-default-eof-error m) (error-names m)) '()
           (list (make-diagnostic 'invalid-eof-target (machine-default-eof-error m)
                                  "machine default eof error names no declared error")))
       (apply append
              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (let ((t (byte-dispatch-node-eof-target n)))
                           (if (or (eq? t #f) (lookup nodes t)) '()
                               (list (make-diagnostic 'invalid-eof-target (node-name n)
                                                      "eof-target names no node"))))
                         '()))
                   nodes)))))

  ;; PASS 7: generated-name safety (member 1) — machine, node, error names/codes.
  (define (pass-names-valid m)
    (append
     (if (valid-name? (machine-name m)) '()
         (list (make-diagnostic 'invalid-name (machine-name m) "machine name is not portable")))
     (filter values
             (map (lambda (n)
                    (if (valid-name? (node-name n)) #f
                        (make-diagnostic 'invalid-name (node-name n) "node name is not portable")))
                  (machine-nodes m)))
     (filter values
             (map (lambda (e)
                    (if (and (valid-name? (error-declaration-name e))
                             (valid-name? (error-declaration-code e)))
                        #f
                        (make-diagnostic 'invalid-name (error-declaration-name e)
                                         "error name or code is not portable")))
                  (machine-errors m)))))

  (define (verify-machine machine)
    (let ((ds (append (pass-schema machine)
                      (if (machine? machine)
                          (append (pass-names machine)
                                  (pass-overlap machine)
                                  (pass-reachability machine)
                                  (pass-zero-progress machine)
                                  (pass-eof machine)
                                  (pass-names-valid machine))
                          '()))))
      (make-verification-result (null? ds) ds machine)))

  (define (verification-ok? v) (verification-result-ok? v))
  (define (verification-diagnostics v) (verification-result-diagnostics v))
  (define (verification-machine v) (verification-result-machine v)))
```

- [ ] **Step 4: Register the lanes and run to green**

```cmake
set(BYTE_MACHINE_CORE_VERIFY
    ${BYTE_MACHINE_CORE_GRAPH}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/verify.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.verify.rejections.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.verify.rejections.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/verify-tests.sps"
  TIMEOUT 120)
```

Run: `cmake --preset dev && cmake --build --preset dev && ctest --preset release -R "verify" --output-on-failure`
Expected: PASS (source + aot).

- [ ] **Step 5: Add the verify mutation pass**

Add a **new** pass to `test/support/cmake/SchemeMutationSuite.cmake`, its verify command modeled on the **placeholder pass** (both `--library-root ${STAGE_DIR}/test/support/harness` and `--library-root ${STAGE_DIR}/src`, `--object-guard ${GUARD_DIR}`, `--program ${STAGE_DIR}/test/common/verify-tests.sps`). Between a fresh `byte_machine_mutation_reset` and `byte_machine_mutation_run`, declare one mutation per decision. Each FIND is a verbatim, unique substring of `verify.sls`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: reachability never reports an unreachable node"
  FIND [[(make-diagnostic 'unreachable-node (node-name n) "node is unreachable")]]
  REPLACE [[#f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "unreachable-node")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: overlap check treats every byte as distinct"
  FIND [[(if (memv b seen)]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "overlapping-cases")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: zero-progress detection never fires"
  FIND [[(if (and (byte-dispatch-node? n) (reaches-self? (node-name n)))]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "zero-progress-cycle")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the machine-name grammar check is suppressed"
  FIND [[(if (valid-name? (machine-name m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a missing transition target is not reported"
  FIND [[(make-diagnostic 'missing-target t "no such node")]]
  REPLACE [[#f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-target")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a duplicate node name is not reported"
  FIND [[(cons (make-diagnostic 'duplicate-name nm "duplicate node name") out)]]
  REPLACE [[out]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "duplicate-name")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an undeclared error reference is not reported"
  FIND [[(if (and (error-node? n) (not (memq (error-node-error-name n) enames)))]]
  REPLACE [[(if #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "missing-error-declaration")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: the default-eof-error membership check is suppressed"
  FIND [[(if (memq (machine-default-eof-error m) (error-names m)) '()]]
  REPLACE [[(if #t '()]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "invalid-eof-target")
```

Increment `EXPECTED_PASSES` by 1 and `EXPECTED_MUTATIONS` by 8, updating the arithmetic comment (re-read current values first).

- [ ] **Step 6: Run mutation suite + whole suite, then commit**

Run:
```bash
cmake --build --preset dev
ctest --preset release -R scheme-mutation --output-on-failure
ctest --preset release --output-on-failure
```
Expected: all eight verify mutations caught with their `EXPECT_OUTPUT_MATCHES`; declared totals match; no regression.

```bash
git add src/byte-machine/verify.sls test/common/verify-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: source-machine verifier (M1 passes) with mutation-witnessed decisions"
```

---

## Task 5: The reference interpreter

**Files:**
- Create: `src/byte-machine/interpret.sls`
- Create: `test/common/interpret-tests.sps`
- Modify: `test/CMakeLists.txt` (register `unit.interpret` lanes)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (new interpret mutation pass; bump totals)

**Interfaces:**
- Consumes: `verification-machine`, `verification-ok?`, `verification-diagnostics` (Task 4); IR accessors (Task 1); the runtime ABI (Task 3).
- Produces: `(make-interpreted-machine verification)` → compiled-machine (parent §9.2). Refuses a failed verification with a `byte-machine-contract-violation` (parent §16.1). `(op 'error-value name)` returns the referenced error declaration's *code* (matching the runtime ABI). Consumed by Phase 3's differential tests.

- [ ] **Step 1: Write the failing interpreter test (all 256 bytes)**

Create `test/common/interpret-tests.sps`. The one-byte machine's errors list holds both declarations; references are by name:

```scheme
;;; The reference interpreter runs the verified one-byte machine over all 256
;;; byte values through the runtime parser API.
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime)
        (byte-machine private conditions))

(harness-begin "unit.interpret")

(define eof-decl (make-error-declaration 'default-eof 'eof "unexpected end of input" #f))
(define rej-decl (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f))
(define one-byte
  (make-machine 'one-byte 'start '() '() '() (list eof-decl rej-decl)
    (list (make-byte-dispatch-node
           'start
           (list (make-byte-case (make-exact-byte-matcher 0) (make-edge 'stop 'advance) #f))
           (make-edge 'reject 'reexecute) #f #f)
          (make-stop-node 'stop #f)
          (make-error-node 'reject 'rejected #f))
    'default-eof #f))

(define cm (make-interpreted-machine (verify-machine one-byte)))
(define (run b)
  (parser-feed! (make-parser cm '() #f) (make-bytevector 1 b) 0 1))

(harness-group "interpreter refuses an unverified machine"
  (lambda ()
    (harness-case "a failed verification is rejected"
      (lambda ()
        (check-raises "refused"
                      byte-machine-contract-condition?
                      (lambda ()
                        (make-interpreted-machine
                         (verify-machine
                          (make-machine 'one-byte 'nowhere '() '() '() (list eof-decl rej-decl)
                                        (list (make-stop-node 'stop #f)) 'default-eof #f)))))))))

(harness-group "all 256 byte values"
  (lambda ()
    (harness-case "byte 0 is accepted and stops after one byte"
      (lambda ()
        (let ((r (run 0)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1))))
    (harness-case "every other byte is rejected at position 0 with the error code"
      (lambda ()
        (let ((bad 'none))
          (let loop ((b 1))
            (when (< b 256)
              (let ((r (run b)))
                (when (or (not (eq? (parser-result-status r) 'error))
                          (not (= (parser-result-stream-offset r) 0))
                          (not (eq? (parser-result-error r) 'unexpected-byte)))
                  (set! bad b)))
              (loop (+ b 1))))
          (check-equal "no byte in 1..255 misbehaved" bad 'none))))))

(harness-finish)
```

- [ ] **Step 2: Run and confirm failure**

Run: `cmake --build --preset dev && ctest --preset release -R "unit.interpret" --output-on-failure`
Expected: FAIL — `(byte-machine interpret)` not found.

- [ ] **Step 3: Write the interpreter**

Create `src/byte-machine/interpret.sls`:

```scheme
;;; (byte-machine interpret): the reference interpreter — the semantic oracle.
;;; It turns a *verification* (which carries its machine, §9.2) into a
;;; runtime-compatible compiled-machine by closing an `op` over the verified IR.
;;; It refuses an unverified/failed machine (§16.1) and never touches the
;;; normalizer or generated code (§18). Error references are symbolic names,
;;; resolved here against the machine's error declarations.
(library (byte-machine interpret)
  (export make-interpreted-machine)
  (import (rnrs)
          (byte-machine private ir)
          (byte-machine private conditions)
          (byte-machine verify)
          (byte-machine runtime))

  (define (lookup nodes name)
    (cond ((null? nodes) #f)
          ((eq? (node-name (car nodes)) name) (car nodes))
          (else (lookup (cdr nodes) name))))
  (define (lookup-error errors name)
    (cond ((null? errors) #f)
          ((eq? (error-declaration-name (car errors)) name) (car errors))
          (else (lookup-error (cdr errors) name))))

  (define (make-interpreted-machine verification)
    (unless (verification-ok? verification)
      (byte-machine-contract-violation 'make-interpreted-machine
                                       'unverified-machine
                                       (verification-diagnostics verification)))
    (let* ((m (verification-machine verification))
           (nodes (machine-nodes m))
           (errors (machine-errors m)))
      (define (kind name)
        (let ((n (lookup nodes name)))
          (cond ((byte-dispatch-node? n) 'dispatch)
                ((stop-node? n) 'stop)
                ((error-node? n) 'error)
                (else (byte-machine-contract-violation 'interpret 'internal name)))))
      (define (dispatch name byte)
        (let ((n (lookup nodes name)))
          (let loop ((cs (byte-dispatch-node-cases n)))
            (cond ((null? cs)
                   (let ((e (byte-dispatch-node-fallback n)))
                     (cons (edge-target e) (edge-mode e))))
                  ((= byte (exact-byte-matcher-byte (byte-case-matcher (car cs))))
                   (let ((e (byte-case-edge (car cs))))
                     (cons (edge-target e) (edge-mode e))))
                  (else (loop (cdr cs)))))))
      (define (error-value name)
        (error-declaration-code
         (lookup-error errors (error-node-error-name (lookup nodes name)))))
      (make-compiled-machine
       (lambda (msg . args)
         (case msg
           ((entry) (machine-entry m))
           ((kind) (kind (car args)))
           ((dispatch) (dispatch (car args) (cadr args)))
           ((error-value) (error-value (car args)))
           (else (byte-machine-contract-violation 'interpret 'internal msg))))))))
```

- [ ] **Step 4: Register the lanes and run to green**

```cmake
set(BYTE_MACHINE_CORE_ALL
    ${BYTE_MACHINE_CORE_VERIFY}
    ${BYTE_MACHINE_CORE_RUNTIME}
    "${BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT}/byte-machine/interpret.sls")

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.interpret.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  TIMEOUT 120)

byte_machine_add_scheme_lane(
  NAME byte-machine.unit.interpret.chez.aot
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_ALL}
          "${CMAKE_SOURCE_DIR}/test/common/interpret-tests.sps"
  TIMEOUT 120)
```

Run: `cmake --preset dev && cmake --build --preset dev && ctest --preset release -R "unit.interpret" --output-on-failure`
Expected: PASS (source + aot) — all 256 bytes correct, unverified machine refused.

- [ ] **Step 5: Add the interpret mutation pass (a NEW pass)**

Add a **new** pass to `test/support/cmake/SchemeMutationSuite.cmake` (verify command modeled on the placeholder pass — both library roots — with `--program ${STAGE_DIR}/test/common/interpret-tests.sps`). Between a fresh `byte_machine_mutation_reset` and `byte_machine_mutation_run`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: dispatch matches every byte to the first case"
  FIND [[((= byte (exact-byte-matcher-byte (byte-case-matcher (car cs))))]]
  REPLACE [[(#t]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "no byte in 1..255 misbehaved")

byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: an unverified machine is accepted"
  FIND [[(unless (verification-ok? verification)]]
  REPLACE [[(when #f]] EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "refused")
```

Increment `EXPECTED_PASSES` by 1 and `EXPECTED_MUTATIONS` by 2, updating the arithmetic comment (re-read current values first).

- [ ] **Step 6: Run mutation suite + whole suite, then commit**

Run:
```bash
cmake --build --preset dev
ctest --preset release -R scheme-mutation --output-on-failure
ctest --preset release --output-on-failure
```
Expected: both interpret mutations caught; totals match; no regression.

```bash
git add src/byte-machine/interpret.sls test/common/interpret-tests.sps test/CMakeLists.txt test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: reference interpreter over verified IR; all-256 one-byte proof"
```

---

## Task 6: Phase-2 acceptance and close

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Confirm the Phase-2 exit conditions**

Run the full suite and re-measure the numbers (do not quote stale totals):
```bash
cmake --preset dev && cmake --build --preset dev
ctest --preset release --output-on-failure
rg -n "\(include" src test
```
Expected: everything green in `.chez.source` and `.chez.aot`; the `unit.*` and `verify.rejections` lanes present; the all-256 interpreter proof passed in both lanes; the Scheme mutation suite reports its new totals (base + 3 passes, + 12 mutations across Tasks 3–5); `rg '\(include' src test` returns no hits.

- [ ] **Step 2: Changelog**

Under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
### Added
- The semantic core (Milestone 1, Phase 2): immutable source-IR descriptors
  and the public (byte-machine graph) constructors; a structural verifier
  (name resolution, exact-byte overlap, reachability, zero-progress cycles,
  terminal/EOF shape, generated-name safety); a runtime parser lifecycle with
  the compiled-machine ABI; and a reference interpreter. The one-byte machine
  ("accept one exact byte, reject the rest at position 0") is proven through the
  interpreter across all 256 byte values in both the Chez source and AOT lanes.
  Error references are symbolic; EOF is declared and verified but not executed.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — Milestone 1 Phase 2 semantic core"
```

*(The zero-include gate stays the documented manual check `rg '(include' src test` — Global Constraints forbid adding a `cmake.direct` lane and fix `no-scheme` at 8/8, so it is not wired into ctest here.)*

---

## Self-Review

1. **Spec coverage (milestone-1-design.md §5):** descriptors → Task 1; symbolic name resolution (nodes + error refs) → Task 4 pass-names; minimal verifier (reachability, zero-progress, overlap, EOF, generated-name safety member-1) → Task 4; reference interpreter → Task 5; runtime result singletons → Task 3; EOF declared+verified-not-executed → Task 1 (`default-eof-error` required as a name), Task 4 (`pass-eof`), no `parser-finish!` anywhere. Exit criteria (all 256; invalid names/targets/overlap/terminals/fallback rejected) → Tasks 1 (construction-level fallback/terminal shape), 4 (verify decisions), 5.
2. **Placeholder scan:** every code step shows complete code. Executor-resolved items are only the exact `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` numbers (each step says re-read then bump by a stated delta) and locating the placeholder pass to model the verify command on (an `rg` is given). No "TBD"/"add error handling"; no inert guards (pass-fallback/terminal-has-outgoing were dropped in favour of construction-level rejection witnessed in Task 1).
3. **Type/name consistency:** the `op` message set (`entry`/`kind`/`dispatch`/`error-value`) is identical in runtime (Task 3), the stub (Task 3), and interpret (Task 5); `error-value` returns the error *code* in all three. Error references are symbols everywhere (`make-error-node` name arg, `default-eof-error`, verifier resolution, interpreter `lookup-error`). `verification-machine`/`verification-ok?`/`verification-diagnostics` match between Task 4 and Task 5. Diagnostic codes asserted in tests (`missing-target`, `overlapping-cases`, `unreachable-node`, `zero-progress-cycle`, `duplicate-name`, `missing-error-declaration`, `invalid-eof-target`, `invalid-name`) are exactly those the passes emit, and each has a witnessing mutation. `parser-result-*` accessors and `stopped`/`error`/`need-input` statuses are consistent throughout.
4. **CMake correctness:** all `ctest` invocations use `release` (or `pr`) with `-R`, not the nonexistent `dev` test preset; `byte_machine_add_scheme_lane` uses NAME/BACKEND/PROGRAM/SOURCES/TIMEOUT with `unit`/`verify` layers and `source`/`aot` modes; SOURCES manifests are complete with unique basenames; the three new mutation passes model their verify command on the placeholder pass (both library roots) and each is a *new* pass with explicit totals bumps.
5. **Deferred correctly:** no field/callback/span/counted/sequence/finish node kinds; no normalizer/emitter/compile; no `parser-finish!`/EOF execution; reserved-set members 2–3 not checked; placeholder libraries not deleted (Phase 3). Matches the design doc's "out of M1" and the EOF guardrail.
```
