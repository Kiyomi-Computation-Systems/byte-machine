# Grammar-author testing guide

This guide is for someone who has written a byte-machine grammar and wants to
test it: the harness API, how to register a lane, and the differential and
property guards the tree already provides. Every procedure or keyword named
below is a real export or argument.

## The harness

A test program is an R6RS `.sps` program that imports the private test harness,
`(byte-machine test harness)`, defined in
`test/support/harness/byte-machine/test/harness.sls`. Its public surface is the
export list of that library; the procedures a grammar author uses are:

**Suite lifecycle**

- `harness-begin` — call once, first, with the suite name (a string). It
  verifies the run's provenance, resets counters, reads the
  `BYTE_MACHINE_TEST_FILTER` and `BYTE_MACHINE_TEST_VERBOSE` environment
  variables, and prints the banner.
- `harness-finish` — call once, last. It prints the summary line and exits the
  process with the run's status. (`harness-summary` and `harness-exit-status`
  are also exported if you need the status without exiting.)

**Structure**

- `harness-group` — takes a name and a thunk; group names nest and form the
  dotted prefix of the case ids inside them.
- `harness-case` — takes a name and a thunk holding the assertions. A raise
  inside a case is recorded as that case's failure rather than killing the
  suite, so one broken case does not hide the cases after it. A duplicate case
  id is reported as a harness error, not a failure.

**Assertions**

- `check` — `(check what value)`; passes when `value` is truthy.
- `check-equal` — `(check-equal what actual expected)`; compares with `equal?`.
- `check-not-equal` — `(check-not-equal what actual unexpected)`; passes when
  `actual` is not `equal?` to `unexpected`.
- `check-fail` — `(check-fail what detail)`; an unconditional failure, for a
  branch that should be unreachable.
- `check-raises` — `(check-raises what predicate thunk)`; passes only when
  `thunk` raises an object satisfying `predicate`. Returning normally, or
  raising something the predicate rejects, is a failure.
- `with-cleanup` — `(with-cleanup body cleanup)`; runs `cleanup` whether or not
  `body` raised, re-raising `body`'s condition unchanged so it stays the
  reported defect.

`adapter-environment-variable` is also exported; a program reads its run-time
inputs through it — for example `BYTE_MACHINE_TEST_TMPDIR`, the scratch
directory provided for emitted files.

**Process status** (the `harness-status-*` constants in `harness.sls`): `0`
every selected case passed, `1` one or more assertions failed, `2` a harness,
configuration, or registration error (e.g. a duplicate case id or an empty case
selection), `3` the run could not confirm it executed the intended text (a
provenance failure).

## A minimal test program

`test/common/example-one-byte-tests.sps` is a full worked example. A minimal
skeleton, modelled on it:

```scheme
;;; my-grammar-tests.sps
(import (rnrs)
        (byte-machine test harness)
        (byte-machine graph)      ; construction façade
        (byte-machine verify)     ; verify-machine
        (byte-machine interpret)  ; make-interpreted-machine
        (byte-machine runtime))   ; make-parser, parser-feed!, parser-result-*

(harness-begin "unit.my-grammar")

(harness-group "my-grammar"
  (lambda ()
    (harness-case "an accepted byte stops after one byte"
      (lambda ()
        (let* ((cm (make-interpreted-machine (verify-machine (make-my-grammar-machine))))
               (r  (parser-feed! (make-parser cm '() #f) (make-bytevector 1 0) 0 1)))
          (check-equal "status"   (parser-result-status r)   'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1))))))

(harness-finish)
```

## Registering a lane

Tests run under CTest. Register each program with `byte_machine_add_scheme_lane`
in `test/CMakeLists.txt` (defined in `cmake/ByteMachineSchemeLane.cmake`). The
required keywords are **NAME**, **BACKEND** (`chez`), **PROGRAM** (the `.sps`
path), **TIMEOUT** (seconds), and **SOURCES**; optional ones include
**ENVIRONMENT**, **LABELS**, and **EXPECT_EXIT**.

- **SOURCES** names *every* `.sls` the program loads plus the program itself. It
  is the provenance manifest: the build fingerprints it, and the run refuses
  (status 3) if the text it executed does not match. Basenames must be unique
  within a lane.
- The mode is read from the **NAME**'s trailing field, so each program is
  registered twice — a `...chez.source` lane and a `...chez.aot` lane — from the
  same call with only the name changed. The source lane runs from source; the
  AOT lane runs from a compiled object, proving the grammar behaves identically
  either way.
- **ENVIRONMENT** sets per-lane variables (a property seed, a golden-file path,
  and so on).

```cmake
byte_machine_add_scheme_lane(
  NAME byte-machine.unit.my-grammar.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_SOURCE_DIR}/test/common/my-grammar-tests.sps"
  SOURCES ${BYTE_MACHINE_HARNESS_MANIFEST}
          ${BYTE_MACHINE_CORE_VERIFY}
          "${CMAKE_SOURCE_DIR}/test/common/my-grammar-tests.sps"
  TIMEOUT 120)
# Then repeat verbatim with NAME ...my-grammar.chez.aot for the compiled lane.
```

The `BYTE_MACHINE_*` source-set variables (`BYTE_MACHINE_HARNESS_MANIFEST`,
`BYTE_MACHINE_CORE_VERIFY`, etc.) are defined at the top of `test/CMakeLists.txt`
in dependency order; list the fragment your program actually imports.

## Differential testing — the strongest grammar guard

The single most valuable test for a grammar is a *differential* one: construct
the machine once, run the same inputs through both executors, and assert they
agree. `test/common/differential-one-byte-tests.sps` is the pattern:

1. Build the reference: `(make-interpreted-machine (verify-machine m))`.
2. Emit the generated library — `(emit-machine (compile-machine m '()) 'name p)`
   to a file port under `BYTE_MACHINE_TEST_TMPDIR` — then `load` it and obtain
   the compiled machine with `eval` in `(environment '(generated ...))`.
3. Feed both through the shared `make-parser` / `parser-feed!` API and compare
   the `parser-result-*` fields (`status`, `next`, `consumed`, `stream-offset`,
   `error`) with `check-equal`.

Because the interpreter and the generated parser are independent
implementations of the same semantics, any divergence — the exact class of bug a
code generator is prone to — shows up as a failing `check-equal`.
`test/common/differential-http-tests.sps` extends this to realistic HTTP inputs,
comparing both the result tuple and the callback event trace under every feed
schedule.

## Further guards already in the tree

- **Determinism goldens.** The `test/common/determinism-*-tests.sps` programs
  assert emission is byte-identical across two renderings and equal to a
  committed golden fixture — pinning emitted output byte-for-byte across
  processes and machines.
- **The property suite.** `test/common/property-differential-tests.sps` (driven
  by `(byte-machine test property-driver)`) draws many machines over every IR
  construct from a fixed seed (`BYTE_MACHINE_PROPERTY_SEED`), runs each verified
  machine through the interpreter oracle and the emitted executor, and compares
  them across several layers under a coverage floor and per-construct counters —
  guarding whole classes of grammars at once, not one hand-written fixture.
- **The mutation suite.** `test/support/cmake/SchemeMutationSuite.cmake` (run via
  `make test-mutation`) breaks each decision on a staged copy and requires some
  test to notice. It is what establishes that your assertions can actually fail.
