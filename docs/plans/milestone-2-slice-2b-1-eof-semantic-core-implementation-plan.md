# Milestone 2 Slice ②b-1 — EOF Semantic Core (interpreter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the **finish** node kind, the §16.2 EOF verification checks, and `parser-finish!` + eof-target execution **through the reference interpreter**, so a machine's EOF behavior — idle completion (`finished`) vs. truncation (`error`) — is constructed, verified, and executed with no code generation.

**Architecture:** Mirrors Milestone 1's Phase 2 (prove the semantics through the interpreter before the emitter that will be tested against it). Touches `private/ir.sls`, `graph.sls`, `verify.sls`, `interpret.sls`, `runtime.sls` (+ the `reserved-member-2` mirror in `compile.sls`). **Deliberately touches no normalizer, no emitter, no `/v2`, no goldens** — those are Slice ②b-2; the interpreter runs off the verified source IR, so a finish-node machine is fully exercised here without generation. EOF success is a distinct `finish` node (returns `finished`, EOF-only) per decision 0011; `parser-finish!` runs a finish loop that takes eof-targets and terminates at finish/error, idempotent like feed (no cache, per the ②a design refinement).

**Tech Stack:** Chez Scheme 10.4.1 (R6RS `.sls`), CMake ≥3.26 + presets, the in-tree harness and Scheme mutation suite.

## Global Constraints

- Chez floor **10.4.1**; CMake floor **3.26**. **No new dependencies.** No `include` (decision 0006); unique basenames per lane; `no-scheme` stays **8/8** (no new `cmake.direct` lane).
- Every decision gets a mutation asserting a measured **signature** (`EXPECT_STATUS`/`EXPECT_OUTPUT_MATCHES`); update `EXPECTED_PASSES`/`EXPECTED_MUTATIONS` and their arithmetic in the **same commit** as the mutations; re-run the whole suite. Re-measure `release`/`pr` before writing any count. Current baseline entering ②b-1: `release`/`pr` **62/62**, mutations **37 passes / 109 mutations**, `no-scheme` **8/8**.
- **Every new `(byte-machine runtime)` export must be mirrored in `reserved-member-2` in `src/byte-machine/compile.sls`** or the member-2 drift guard (`reserved-drift-tests.sps`) fails — this surfaces only in the full mutation/drift suite. (`parser-finish!` is the one new export here.)
- Governing design: `docs/plans/milestone-2-design.md` §5, decisions **0011** (EOF execution model; the §16.2 checks are :908–:909 in `docs/plans/byte-machine-implementation-plan.md`). **Out of ②b-1:** finish-state normalizer encoding, the IR-fingerprint move, the emitter finish arm, `/v2`, `position-kind = eof`, and the interpreter≡generated differential — all Slice ②b-2.
- Diagnostics compare by **code**, never rendered text. Conventional Commits; run `make test` before every commit.

---

## Task 1: The finish node + the §16.2 EOF verification checks

**Files:**
- Modify: `src/byte-machine/private/ir.sls` (finish-node constructor/predicate/accessor; `node?`/`node-name`; exports)
- Modify: `src/byte-machine/graph.sls` (export `make-finish-node`)
- Modify: `src/byte-machine/verify.sls` (reachability follows eof-targets; new EOF-execution pass)
- Modify: `test/common/verify-tests.sps` (accept a valid finish machine; reject non-eof-into-finish / eof-reachable-stop / eof-cycle)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (mutations for the three checks; bump counts)

**Interfaces:**
- Produces: `make-finish-node` (name, source-label), `finish-node?`, `finish-node-name` in `(byte-machine private ir)` and `make-finish-node` re-exported from `(byte-machine graph)`. `verify-machine` rejects a byte edge into a finish terminal (`non-eof-into-finish`), an eof-target chain reaching a stop terminal (`eof-reachable-stop`), and an eof-target cycle (`eof-zero-progress-cycle`). Task 2's interpreter consumes `finish-node?`.

- [ ] **Step 1: Write the finish-node + EOF-rejection verify tests (RED)**

In `test/common/verify-tests.sps`, add a group that builds machines through `(byte-machine graph)` and asserts diagnostics by code. Use the existing helpers in that file for constructing machines; the new cases:

```scheme
(harness-group "EOF terminals and eof-target verification (§16.2)"
  (lambda ()
    ;; A valid EOF machine: entry reads byte 1 (advance to stop); its eof-target
    ;; is a FINISH node (idle completion). Fallback -> reject error.
    (define (eof-ok)
      (make-machine 'eofok 's0 '() '() '()
        (list (make-error-declaration 'default-eof 'eof "eof" #f)
              (make-error-declaration 'rejected 'unexpected-byte "bad" #f))
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) 'done #f)   ; eof-target -> finish node 'done
              (make-stop-node 'stop #f)
              (make-finish-node 'done #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (harness-case "a finish node reachable only via an eof-target verifies"
      (lambda ()
        (check "verifies" (verification-ok? (verify-machine (eof-ok))))))
    ;; §16.2:908 — a BYTE edge into a finish terminal is rejected.
    (harness-case "a byte case targeting a finish node is rejected (non-eof-into-finish)"
      (lambda ()
        (let ((m (make-machine 'bad1 's0 '() '() '()
                   (list (make-error-declaration 'default-eof 'eof "eof" #f))
                   (list (make-byte-dispatch-node 's0
                           (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'done 'advance) #f))
                           (make-edge 'done 'reexecute) #f #f)   ; byte edges -> finish node
                         (make-finish-node 'done #f))
                   'default-eof #f)))
          (check "has non-eof-into-finish"
                 (memq 'non-eof-into-finish
                       (map diagnostic-code (verification-diagnostics (verify-machine m))))))))
    ;; §16.2:909 — an eof-target chain reaching a STOP terminal is rejected.
    (harness-case "an eof-target reaching a stop terminal is rejected (eof-reachable-stop)"
      (lambda ()
        (let ((m (make-machine 'bad2 's0 '() '() '()
                   (list (make-error-declaration 'default-eof 'eof "eof" #f))
                   (list (make-byte-dispatch-node 's0
                           (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                           (make-edge 'stop 'reexecute) 'stop #f)   ; eof-target -> stop
                         (make-stop-node 'stop #f))
                   'default-eof #f)))
          (check "has eof-reachable-stop"
                 (memq 'eof-reachable-stop
                       (map diagnostic-code (verification-diagnostics (verify-machine m))))))))
    ;; EOF zero-progress cycle — s0 eof-target s1, s1 eof-target s0.
    (harness-case "an eof-target cycle is rejected (eof-zero-progress-cycle)"
      (lambda ()
        (let ((m (make-machine 'bad3 's0 '() '() '()
                   (list (make-error-declaration 'default-eof 'eof "eof" #f))
                   (list (make-byte-dispatch-node 's0
                           (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
                           (make-edge 's1 'advance) 's1 #f)
                         (make-byte-dispatch-node 's1
                           (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 's0 'advance) #f))
                           (make-edge 's0 'advance) 's0 #f))
                   'default-eof #f)))
          (check "has eof-zero-progress-cycle"
                 (memq 'eof-zero-progress-cycle
                       (map diagnostic-code (verification-diagnostics (verify-machine m))))))))))
```

`make-finish-node` must be imported in the test — it is re-exported from `(byte-machine graph)` (added in Step 3), which `verify-tests.sps` already imports.

- [ ] **Step 2: Run — expect RED** (`make-finish-node` unbound)

Run: `make build 2>&1 | rg -i 'error|exception|unbound|finish' | head`
Expected: RED — `make-finish-node` is not defined/exported.

- [ ] **Step 3: Add the finish node to the IR and graph façade**

In `src/byte-machine/private/ir.sls`, add to the `(export …)` list: `make-finish-node finish-node? finish-node-name`. Add the node definition (next to the stop-node block):

```scheme
  ;; --- finish node (EOF-only successful terminal, returns finished) ---
  (define finish-node-tag (tag 'byte-machine-finish-node))
  (define (make-finish-node name source-label)
    (require-symbol 'make-finish-node 'name name)
    (vector finish-node-tag name source-label))
  (define (finish-node? x) (tagged? finish-node-tag x))
  (define (finish-node-name n) (vector-ref n 1))
```

Extend `node?` and `node-name` to include it:

```scheme
  (define (node? x)
    (or (byte-dispatch-node? x) (stop-node? x) (error-node? x) (finish-node? x)))
  (define (node-name x)
    (cond ((byte-dispatch-node? x) (byte-dispatch-node-name x))
          ((stop-node? x) (stop-node-name x))
          ((error-node? x) (error-node-name x))
          ((finish-node? x) (finish-node-name x))
          (else (byte-machine-contract-violation 'node-name 'invalid-argument 'node))))
```

In `src/byte-machine/graph.sls`, add `make-finish-node` to both the `(export …)` list and the `(only (byte-machine private ir) …)` import list.

- [ ] **Step 4: Add the verify EOF checks**

In `src/byte-machine/verify.sls`, add `finish-node?` handling and the EOF-execution pass.

Reachability must follow eof-targets so an eof-only-reachable finish node is not flagged `unreachable-node`. Add a helper and use it in `pass-reachability`'s `visit` (replace `node-out-targets` there with `all-out-targets`):

```scheme
  ;; byte out-targets PLUS a dispatch node's eof-target (for reachability only).
  (define (all-out-targets n)
    (append (node-out-targets n)
            (if (byte-dispatch-node? n)
                (let ((t (byte-dispatch-node-eof-target n)))
                  (if (symbol? t) (list t) '()))
                '())))
```

Add the eof-chain classifier and the EOF-execution pass:

```scheme
  ;; Walk the eof-target chain from `start`, classifying its terminal.
  (define (eof-terminal m start)
    (let ((nodes (machine-nodes m)))
      (let loop ((name start) (seen '()))
        (if (memq name seen) 'cycle
            (let ((n (lookup nodes name)))
              (cond ((not n) 'unresolved)             ; pass-eof reports missing target
                    ((finish-node? n) 'finish)
                    ((error-node? n) 'error)
                    ((stop-node? n) 'eof-reachable-stop)
                    ((byte-dispatch-node? n)
                     (let ((t (byte-dispatch-node-eof-target n)))
                       (if (symbol? t) (loop t (cons name seen)) 'default-error)))
                    (else 'unknown))))))

  ;; §16.2:908/:909 and the separate EOF zero-progress-cycle check.
  (define (pass-eof-execution m)
    (let ((nodes (machine-nodes m)))
      (append
       ;; :908 — a byte edge (case or fallback) into a finish terminal.
       (apply append
              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (filter values
                                 (map (lambda (t)
                                        (let ((tn (lookup nodes t)))
                                          (if (and tn (finish-node? tn))
                                              (make-diagnostic 'non-eof-into-finish (node-name n)
                                                               "a byte edge targets a finish terminal")
                                              #f)))
                                      (node-out-targets n)))
                         '()))
                   nodes))
       ;; :909 + the EOF-cycle check — walk each dispatch node's eof-target chain.
       (apply append
              (map (lambda (n)
                     (if (byte-dispatch-node? n)
                         (let ((t (byte-dispatch-node-eof-target n)))
                           (if (symbol? t)
                               (case (eof-terminal m t)
                                 ((eof-reachable-stop)
                                  (list (make-diagnostic 'eof-reachable-stop (node-name n)
                                                         "an EOF path reaches a stop terminal")))
                                 ((cycle)
                                  (list (make-diagnostic 'eof-zero-progress-cycle (node-name n)
                                                         "an EOF path cycles without reaching a terminal")))
                                 (else '()))
                               '()))
                         '()))
                   nodes)))))
```

Wire `pass-eof-execution` into `verify-machine`'s `append` list (after `pass-eof`):

```scheme
                                  (pass-eof machine)
                                  (pass-eof-execution machine)
                                  (pass-names-valid machine))
```

- [ ] **Step 5: Run — expect GREEN**

Run: `make build && ctest --preset pr -R 'byte-machine\.verify' --output-on-failure`
Expected: the valid finish machine verifies; the three invalid machines each carry their diagnostic code.

- [ ] **Step 6: Add mutations for the three checks; bump counts**

In `SchemeMutationSuite.cmake`, in the verifier pass (Pass 33 — the one with `SPEC byte-machine.verify.rejections.chez.source`), add three mutations before its `byte_machine_mutation_run`:

```cmake
byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: a byte edge into a finish terminal is accepted"
  FIND [[(if (and tn (finish-node? tn))]]
  REPLACE [[(if (and tn #f)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "non-eof-into-finish")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an EOF-reachable stop terminal is accepted"
  FIND [[((stop-node? n) 'eof-reachable-stop)]]
  REPLACE [[((stop-node? n) 'finish)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof-reachable-stop")

byte_machine_mutation(
  FILE src/byte-machine/verify.sls SPEC byte-machine.verify.rejections.chez.source
  LABEL "verify: an eof-target cycle is classified as a finish terminal"
  FIND [[(if (memq name seen) 'cycle]]
  REPLACE [[(if (memq name seen) 'finish]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "eof-zero-progress-cycle")
```

(The cycle mutation deliberately misclassifies the *detected* cycle as `finish` rather than disabling detection — `(if #f 'cycle …)` would leave `eof-terminal` looping until Chez overflows the stack, a raise-based catch that depends on where it crashes. The comparison form still terminates on the second visit via `memq` and tests the same decision: the `bad3` machine's `eof-zero-progress-cycle` assertion fails. See AGENTS.md "Prefer a mutation caught by a failed comparison over one caught by a raise.")

Update counts: `EXPECTED_MUTATIONS` `109` → `112` (three added to Pass 33); `EXPECTED_PASSES` stays `37`. Update Pass 33's narrative (`+3`).

- [ ] **Step 7: Run the mutation suite; commit**

Run: `ctest --preset release -R 'scheme-mutation' --output-on-failure`
Expected: PASS; totals `37 / 112`.

```bash
git add src/byte-machine/private/ir.sls src/byte-machine/graph.sls src/byte-machine/verify.sls \
        test/common/verify-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: finish node kind + §16.2 EOF verification (non-eof-into-finish, eof-reachable-stop, eof-cycle)"
```

---

## Task 2: `parser-finish!` + eof-target execution through the interpreter

**Files:**
- Modify: `src/byte-machine/interpret.sls` (op gains `finish` kind, `eof-target`, `default-eof-value`)
- Modify: `src/byte-machine/runtime.sls` (`parser-finish!` op path; `parser-feed-op!` finish arm; `finished` lifecycle; export `parser-finish!`)
- Modify: `src/byte-machine/compile.sls` (mirror `parser-finish!` in `reserved-member-2`)
- Modify: `test/common/interpret-tests.sps` and/or `test/common/runtime-tests.sps` (finish execution tests)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (mutations; bump counts)

**Interfaces:**
- Consumes: `finish-node?` (Task 1). Produces: `(parser-finish! parser)` → a `parser-result` with status `finished` (idle) or `error` (truncation), and sets `parser-lifecycle` to `finished`/`error`. `parser-feed-op!` returns `finished` (consuming zero) when the parser is parked at a finish node.

- [ ] **Step 1: Write the finish-execution tests (RED)**

In `test/common/interpret-tests.sps`, add a group over a machine built with `(byte-machine graph)`, driven through `make-interpreted-machine`. Use the `eof-ok`-shaped machine (entry `s0` byte 1→advance→`s1`; `s1` byte 2→advance→`stop`; `s0` eof-target→finish `done`; `s1` eof-target→error `truncated`; fallbacks→`reject`):

```scheme
(harness-group "EOF execution through the interpreter"
  (lambda ()
    (define (m)
      (make-machine 'eofm 's0 '() '() '()
        (list (make-error-declaration 'default-eof 'eof "eof" #f)
              (make-error-declaration 'rejected 'unexpected-byte "bad" #f)
              (make-error-declaration 'truncated 'truncated-input "trunc" #f))
        (list (make-byte-dispatch-node 's0
                (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
                (make-edge 'reject 'reexecute) 'done #f)          ; idle: eof -> finish
              (make-byte-dispatch-node 's1
                (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
                (make-edge 'reject 'reexecute) 'trunc #f)         ; truncation: eof -> error
              (make-stop-node 'stop #f)
              (make-finish-node 'done #f)
              (make-error-node 'trunc 'truncated #f)
              (make-error-node 'reject 'rejected #f))
        'default-eof #f))
    (define (fresh) (make-parser (make-interpreted-machine (verify-machine (m))) '() #f))
    (harness-case "finish with no input is idle completion -> finished"
      (lambda ()
        (let ((r (parser-finish! (fresh))))
          (check-equal "finished" (parser-result-status r) 'finished))))
    (harness-case "finish after one byte is truncation -> error with the code"
      (lambda ()
        (let ((p (fresh)))
          (parser-feed! p (make-bytevector 1 1) 0 1)              ; at s1, offset 1
          (let ((r (parser-finish! p)))
            (check-equal "error" (parser-result-status r) 'error)
            (check-equal "truncation code" (parser-result-error r) 'truncated-input)
            (check-equal "eof at offset 1" (parser-result-stream-offset r) 1)))))
    (harness-case "feeding both bytes stops; finishing a stopped parser stays stopped (§12.2)"
      (lambda ()
        (let ((p (fresh)))
          (parser-feed! p (make-bytevector 2 0) 0 0)              ; empty feed, still ready
          (parser-feed! p (let ((v (make-bytevector 2))) (bytevector-u8-set! v 0 1)
                            (bytevector-u8-set! v 1 2) v) 0 2)    ; -> stopped
          (check-equal "stopped" (parser-lifecycle p) 'stopped)
          (check-equal "finish after stop stays stopped" (parser-result-status (parser-finish! p)) 'stopped))))
    (harness-case "finishing a finished parser stays finished; lifecycle tracks it"
      (lambda ()
        (let ((p (fresh)))
          (parser-finish! p)
          (check-equal "lifecycle finished" (parser-lifecycle p) 'finished)
          (check-equal "again finished" (parser-result-status (parser-finish! p)) 'finished))))
    (harness-case "a dispatch with eof-target #f routes EOF to the default-eof error"
      (lambda ()
        (let ((p (make-parser
                  (make-interpreted-machine
                   (verify-machine
                    (make-machine 'dm 's0 '() '() '()
                      (list (make-error-declaration 'default-eof 'eof "eof" #f))
                      (list (make-byte-dispatch-node 's0
                              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'stop 'advance) #f))
                              (make-edge 'stop 'reexecute) #f #f)   ; eof-target #f -> default
                            (make-stop-node 'stop #f))
                      'default-eof #f)))
                  '() #f)))
          (let ((r (parser-finish! p)))
            (check-equal "default-eof error" (parser-result-status r) 'error)
            (check-equal "default-eof code" (parser-result-error r) 'eof))))))))
```

`parser-finish!` must be imported — it is a new `(byte-machine runtime)` export (Step 3).

- [ ] **Step 2: Run — expect RED** (`parser-finish!` unbound; op has no eof messages)

Run: `make build 2>&1 | rg -i 'error|exception|unbound|finish|eof-target' | head`
Expected: RED.

- [ ] **Step 3: Extend the interpreter op closure**

In `src/byte-machine/interpret.sls`: **no import edit is needed** — `interpret.sls` imports `(byte-machine private ir)` in full (not `only`), so `finish-node?` (once Task 1 exports it), `byte-dispatch-node-eof-target`, and `machine-default-eof-error` are already in scope, as are `errors`/`lookup-error`/`error-declaration-code`. Extend `kind` and add two messages.

`kind` gains a finish arm:
```scheme
      (define (kind name)
        (let ((n (lookup nodes name)))
          (cond ((byte-dispatch-node? n) 'dispatch)
                ((stop-node? n) 'stop)
                ((error-node? n) 'error)
                ((finish-node? n) 'finish)
                (else (byte-machine-contract-violation 'interpret 'internal name)))))
```

Add a `default-eof-value` helper next to `error-value`:
```scheme
      (define (default-eof-value)
        (error-declaration-code (lookup-error errors (machine-default-eof-error m))))
```

Extend the op `case`:
```scheme
       (lambda (msg . args)
         (case msg
           ((entry) (machine-entry m))
           ((kind) (kind (car args)))
           ((dispatch) (dispatch (car args) (cadr args)))
           ((error-value) (error-value (car args)))
           ((eof-target) (byte-dispatch-node-eof-target (lookup nodes (car args))))
           ((default-eof-value) (default-eof-value))
           (else (byte-machine-contract-violation 'interpret 'internal msg))))
```

- [ ] **Step 4: Add `parser-finish!` and the `finished` feed arm to the runtime**

In `src/byte-machine/runtime.sls`: add `parser-finish!` to the export list; add a `finished` case to `parser-feed!`'s lifecycle `case` and a `finish` arm to `parser-feed-op!`; add `parser-finish!` + `parser-finish-op!`.

`parser-feed!` lifecycle case:
```scheme
      (case (parser-result-status r)
        ((stopped) (parser-set-lifecycle! parser 'stopped))
        ((error) (parser-set-lifecycle! parser 'error))
        ((finished) (parser-set-lifecycle! parser 'finished)))
```

`parser-feed-op!` gains a `finish` arm (a parser parked at a finish node re-feeds to `finished`, consuming zero — §12.2 finished×feed!):
```scheme
            ((finish)
             (make-parser-result 'finished pos (- pos start) (parser-offset parser) #f))
```

Add after `parser-feed-v1!`:
```scheme
  ;; parser-finish! (§12.4): run the executor with input exhausted. From the
  ;; current state, an exhausted dispatch takes its eof-target (a named node, else
  ;; the machine default-eof-error); execution continues to a finish node
  ;; (-> finished), an error node (-> error), or a stop node reached this way is
  ;; verifier-rejected so it never occurs. No slice, so next/consumed mirror the
  ;; stream offset / 0. The generated (v1) finish path is Slice ②b-2.
  (define (parser-finish! parser)
    (if (eq? (parser-variant parser) 'op)
        (parser-finish-op! parser)
        (assertion-violation 'parser-finish! "generated finish path is Slice 2b-2" parser)))

  (define (parser-finish-op! parser)
    (let ((op (parser-executor parser))
          (off (parser-offset parser)))
      (let loop ((node (parser-current parser)))
        (case (op 'kind node)
          ((finish)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'finished)
           (make-parser-result 'finished off 0 off #f))
          ((stop)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'stopped)
           (make-parser-result 'stopped off 0 off #f))
          ((error)
           (parser-set-current! parser node)
           (parser-set-lifecycle! parser 'error)
           (make-parser-result 'error off 0 off (op 'error-value node)))
          ((dispatch)
           (let ((t (op 'eof-target node)))
             (if t
                 (begin (parser-set-current! parser t) (loop t))
                 (begin (parser-set-lifecycle! parser 'error)
                        (make-parser-result 'error off 0 off (op 'default-eof-value))))))
          (else (assertion-violation 'parser-finish! "unknown node kind" (op 'kind node)))))))
```

In `src/byte-machine/compile.sls`, add `parser-finish!` to the `reserved-member-2` list (it currently ends `… parser-lifecycle parser-reset!`).

- [ ] **Step 5: Run — expect GREEN**

Run:
```bash
make build && ctest --preset pr -R 'byte-machine\.unit\.interpret|byte-machine\.unit\.runtime' --output-on-failure
```
Expected: the finish-execution tests PASS. Then confirm the drift guard still holds (new export mirrored):
```bash
ctest --preset release -R 'reserved-drift' --output-on-failure
```
Expected: PASS.

- [ ] **Step 6: Add mutations; bump counts**

The finish/eof decisions each get a mutation. Add to the **interpret pass (Pass 34**, `SPEC byte-machine.unit.interpret.chez.source`) and the **runtime pass (Pass 32)**, placed before each pass's `byte_machine_mutation_run` (both are existing passes — no new pass, so `EXPECTED_PASSES` stays 37):

```cmake
# Pass 34 (interpret):
byte_machine_mutation(
  FILE src/byte-machine/interpret.sls SPEC byte-machine.unit.interpret.chez.source
  LABEL "interpret: a finish node is not reported as a finish kind"
  FIND [[((finish-node? n) 'finish)]]
  REPLACE [[((finish-node? n) 'stop)]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finished")

# Pass 32 (runtime):
byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: an exhausted dispatch does not take its eof-target"
  FIND [[(op 'eof-target node)]]
  REPLACE [[#f]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "finished")

byte_machine_mutation(
  FILE src/byte-machine/runtime.sls SPEC byte-machine.unit.runtime.chez.source
  LABEL "runtime: a dispatch with no eof-target does not route to the default error"
  FIND [[(make-parser-result 'error off 0 off (op 'default-eof-value))]]
  REPLACE [[(make-parser-result 'stopped off 0 off (op 'default-eof-value))]]
  EXPECT_STATUS 1 EXPECT_OUTPUT_MATCHES "default-eof")
```

Verify each `FIND` is a verbatim unique substring of the committed code before running (adjust whitespace to match exactly). Counts: `EXPECTED_MUTATIONS` `112` → `115` (interpret +1, runtime +2); `EXPECTED_PASSES` stays `37`. Update both passes' narratives.

- [ ] **Step 7: Run the mutation suite; commit**

Run: `ctest --preset release -R 'scheme-mutation' --output-on-failure`
Expected: PASS; totals `37 / 115`.

```bash
git add src/byte-machine/interpret.sls src/byte-machine/runtime.sls src/byte-machine/compile.sls \
        test/common/interpret-tests.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "feat: parser-finish! + eof-target execution through the interpreter (finished/truncation)"
```

---

## Task 3: The idle-vs-truncation proving surface + whole-suite verification

**Files:**
- Create: `test/support/harness/byte-machine/test/eof-machine.sls` (a shared finish-node proving machine)
- Modify: `test/common/interpret-tests.sps` (import + use the shared fixture; exhaustive per-byte checks) OR a new `test/common/eof-interpret-tests.sps` with its own lane
- Modify: `test/CMakeLists.txt` (if a new lane is added)

**Interfaces:**
- Consumes: `make-finish-node`, `parser-finish!` (Tasks 1–2). Produces: `(byte-machine test eof-machine)` exporting `make-eof-machine` (the idle-vs-truncation machine) for reuse by Slice ②b-2's differential.

- [ ] **Step 1: Create the shared proving-machine fixture**

Create `test/support/harness/byte-machine/test/eof-machine.sls`:

```scheme
;;; The idle-vs-truncation proving machine for Milestone 2 Slice ②b, built only
;;; through (byte-machine graph). Accepts the two-byte sequence 1 2 (feed ->
;;; stopped). At entry s0, EOF is idle completion (eof-target -> finish 'done ->
;;; finished); after one byte at s1, EOF is truncation (eof-target -> error
;;; 'trunc -> error). Shared by the ②b-1 interpreter tests and ②b-2's
;;; interpreter≡generated differential so the graph is written once.
(library (byte-machine test eof-machine)
  (export make-eof-machine)
  (import (rnrs) (byte-machine graph))
  (define (make-eof-machine)
    (make-machine 'eofm 's0 '() '() '()
      (list (make-error-declaration 'default-eof 'eof "unexpected end of input" #f)
            (make-error-declaration 'rejected 'unexpected-byte "unexpected byte" #f)
            (make-error-declaration 'truncated 'truncated-input "truncated input" #f))
      (list (make-byte-dispatch-node 's0
              (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 's1 'advance) #f))
              (make-edge 'reject 'reexecute) 'done #f)
            (make-byte-dispatch-node 's1
              (list (make-byte-case (make-exact-byte-matcher 2) (make-edge 'stop 'advance) #f))
              (make-edge 'reject 'reexecute) 'trunc #f)
            (make-stop-node 'stop #f)
            (make-finish-node 'done #f)
            (make-error-node 'trunc 'truncated #f)
            (make-error-node 'reject 'rejected #f))
      'default-eof #f)))
```

- [ ] **Step 2: Add the exhaustive interpreter test lane**

Create `test/common/eof-interpret-tests.sps` that verifies the machine and drives the interpreter through the whole EOF lifecycle. Assert: `parser-finish!` on a fresh parser → `finished`; feed byte 1 then finish → `error`/`truncated-input` at offset 1; feed 1 then 2 → `stopped`; every byte b≠1 at s0 → `error` at offset 0, and finish there is still idle (`finished`) only on a fresh parser; feed 1 then any b≠2 → `error` at offset 1. Structure the per-byte sweep like `differential-one-byte-tests.sps` but interpreter-only.

Register two lanes in `test/CMakeLists.txt` (source + aot) labeled `unit`, with `SOURCES = HARNESS_MANIFEST + CORE_ALL + eof-machine.sls + the program` (model on the `byte-machine.unit.interpret.chez.*` lanes at ~line 795; add `eof-machine.sls` from `BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT`).

- [ ] **Step 3: Run the new lanes**

Run: `make build && ctest --preset pr -R 'eof-interpret' --output-on-failure`
Expected: both lanes PASS.

- [ ] **Step 4: Whole-suite verification; commit**

Run:
```bash
make clean && make test-all
cmake --preset no-scheme >/dev/null && cmake --build --preset no-scheme >/dev/null && ctest --preset no-scheme
ctest --preset release -R 'scheme-mutation' --output-on-failure | rg 'passes|mutations|PASS|FAIL'
```
Expected: `release` green (62 + 2 new eof-interpret lanes = **64**); `no-scheme` **8/8**; mutation suite `37 / 115`. Re-measure and record the exact `release`/`pr` count.

```bash
git add test/support/harness/byte-machine/test/eof-machine.sls test/common/eof-interpret-tests.sps test/CMakeLists.txt
git commit -m "test: idle-vs-truncation proving machine + exhaustive interpreter EOF lane"
```

---

## Self-Review

1. **Spec coverage (design §5, ②b-1 slice):** finish node (new kind) → Task 1. §16.2 EOF checks (non-eof-into-finish :908, eof-reachable-stop :909, eof zero-progress-cycle; reachability through eof-targets) → Task 1. `parser-finish!` + eof-target execution through the interpreter, `finished` status, idle-vs-truncation, default-eof routing, §12.2 finish-after-terminal stickiness → Tasks 2–3. **Out of scope, correctly absent:** normalizer finish encoding, IR-fingerprint move, emitter finish arm, `/v2`, `position-kind = eof`, the interpreter≡generated differential — all Slice ②b-2 (noted in each task).
2. **Placeholder scan:** each step shows exact code, exact `FIND`/`REPLACE`, and `make`/`ctest` commands with RED/GREEN. The one place with prose ("structure the per-byte sweep like differential-one-byte-tests.sps") is a test whose assertions are enumerated; Task 3 Step 2 names every case. No "TBD".
3. **Type/name consistency:** `make-finish-node`/`finish-node?`/`finish-node-name` defined in Task 1 and used in Tasks 2–3; the op messages `eof-target`/`default-eof-value` defined in interpret (Task 2) and consumed by `parser-finish-op!` (same task); `parser-finish!` exported in Task 2 and mirrored in `reserved-member-2` the same task; the finish result convention `(status, next=off, consumed=0, stream-offset=off, error)` is used identically in `parser-finish-op!` so Slice ②b-2's differential has a fixed target.
4. **Mutation discipline:** every new decision (three verify checks, the finish kind, the eof-target hop, the default-eof route) gets a comparison-based mutation with a measured `EXPECT_OUTPUT_MATCHES`; the cycle mutation is deliberately the crash-free comparison form (not the stack-overflow raise); `EXPECTED_MUTATIONS` 109 → 112 (Task 1) → 115 (Task 2), updated in the same commit; whole suite re-run each task and in Task 3.
