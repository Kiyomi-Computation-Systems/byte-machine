# Milestone 0, Slice 2: Portable test harness and thin runners

Status: accepted; delivered 2026-08-16 by [its implementation plan](./milestone-0-slice-2-implementation-plan.md)
Date: 2026-08-16
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §22.2, §24
Milestone plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — deliverable D4, work-order item 2
Scope: **the harness only.** No byte-machine semantics, no execution lanes beyond one source lane per runtime, no fingerprinting.

## 1. What this slice must prove

The milestone plan states the bar in one sentence: *a deliberately failing assertion produces a
nonzero exit code on both implementations; a passing one produces zero. The harness must be able to
fail before it is trusted to pass.*

That bar is deceptively narrow. Everything in Milestones 1 through 9 is measured with this
instrument, so a defect in it is not one failing test — it is every later test reporting success
regardless of the code. If `check-equal` silently always returned true, the whole project would go
green and stay green. The slice is therefore sized by what it takes to *disprove* that, not by what
it takes to run an assertion.

D4 adds the structural requirement: shared assertion and result code, thin Chez and Gambit adapters
owning imports, process exit codes, and compilation steps, mirroring protium's structure, with
**adapters on both runtimes exporting exactly the same names**.

## 2. Verified environment facts

Both lanes below were run end to end on 2026-08-16 (Darwin 25.5.0 arm64) against the structure this
document specifies, from `/` as the working directory, before the design was accepted.

| Fact | Result |
| --- | --- |
| `gsi -:search=<dir> <program>` resolves a three-segment `(byte-machine test harness)` from an arbitrary CWD | works |
| Gambit `include` of a shared body from inside `define-library`, by source-relative path | works |
| Gambit program `include` of its own body, source-relative, beside the program | works |
| Chez `library-directories` with a three-segment library at `chez/byte-machine/test/harness.sls` | works |
| Chez `include` of a shared body by bare filename through launcher-set `source-directories` | works, from any CWD |
| Chez object-guard pair (`(cons library-root guard-dir)`) with an empty guard directory | works |

The Gambit result is new evidence. The milestone plan §2 recorded `-:search` for *includes*; that it
also resolves *library imports* from an arbitrary CWD is what makes an interpreted Gambit lane
possible, and it had not been measured before.

## 3. Decisions taken

| # | Decision | Rationale |
| --- | --- | --- |
| S1 | The runner carries assertions, groups/cases, an isolated self-probe, summary, and exit statuses. No fingerprint, no PRNG, no deadlines. | Fingerprint has its first consumer in slice 5, PRNG in M2/M7, deadlines never — byte-machine has no async anywhere. Copying protium's deadline layer would repeat exactly the mistake [decision 0001](../decisions/0001-toolchain-discovery.md) named and rejected for threaded Chez: a requirement inherited from a sibling's problem rather than owned by this one. |
| S2 | A `source` mode is registered for Gambit, and slice 2's Gambit lane is `gsi` interpreting the `.sld`. | The mode table was copied verbatim from protium, where Gambit has only `o1` and `aot` — both of which shell out to a C compiler (`gcc-16`, hard-coded in `gambuild-C` on this host). As it stood, the first slice that runs Scheme could not run on Gambit without a working C toolchain, while Chez source needs nothing. §24.2 also wants a dependency-free source suite runnable without native compilation. Divergence from protium, justified: protium has a native shim to link, byte-machine does not. |
| S3 | Exit statuses: 0 pass, 1 assertion failed, 2 harness error. 3 is declared and reserved for lane-provenance failure; 77 is not declared. | protium *measured* that folding provenance into 2 hid a corrupted expectation, because several fixtures legitimately expect 2 — "a check whose failure is indistinguishable from a fixture's expected outcome is not a check." Slice 5 hits the same wall. Reserving the number costs one line and avoids renumbering under slice-5 pressure. 77 has no consumer: byte-machine has no optional lane to declare inapplicable. |
| S4 | Each shared test body has a hand-written `.chez.sps` and `.gambit.scm` wrapper checked in beside it, enforced by a `CONFIGURE_DEPENDS` glob. | Keeps "wrappers contain no semantics" auditable in the source tree. The glob means a newly added body is covered without anyone remembering to enrol it — a guard that silently skips new files is the failure mode that matters. Generated wrappers were rejected: per-body imports do not fit one template, and a contributor debugging a lane would have to read the build tree. |
| S5 | Mutation testing is extended to the Scheme harness. `MutationRunner` is generalized on two axes — the stage set and the verify command — and one mutation is declared per decision in the runner. | The repo already holds its CMake layer to this standard, and the harness is a sharper case: a vacuous runner makes every later milestone vacuous. The generalization is paid once; each further mutation is then a few lines. |
| S6 | A mutation counts as caught when the **Chez source** self-test lane fails. | The mutated file is the shared runner body — identical text on both runtimes — so a second runtime re-proves the same mutation at double the process cost. Keeping the suite fast is how it stays alive; trimming a slow mutation suite is how they die. |
| S7 | The library is `(byte-machine test harness)`, and every harness shared body is named `harness-*.scm`. | The `test` segment keeps test infrastructure out of the namespace §9 reserves for public surface. The prefix addresses D6: `source-directories` is a process-global flat namespace, and an M1 program importing both `(byte-machine graph)` and the harness puts `src/common/byte-machine/` and the harness's shared directory on one path. `runner.scm` or `result.scm` would be a collision waiting for M1; the prefix makes it structurally impossible. |
| S8 | The shared-body basename-uniqueness check (D6) is seeded in this slice rather than waiting for slice 3. | The portability guard this slice adds (§8.4) already globs the shared bodies for wrapper pairing, so asserting uniqueness is a few extra lines on a glob that has to exist anyway. Slice 3 widens it to `src/common/` rather than inventing it, and the harness does not become the first thing to break a rule it will later be measured by. |

### 3.1 Rejected alternatives

- **No harness library; every test program includes the runner directly.** Simpler — no library
  search paths — but it would not exercise the one-owner-per-shared-body rule §7.2 exists to
  establish, and slice 3 would have to build it anyway.
- **A single generic runner program taking the body path as an argument.** `include` expands at
  compile time, so the filename cannot arrive at run time; `load` would work but bypasses the
  include-and-compile behaviour this milestone exists to prove, and the compiled lanes in slice 5
  could not compile the body at all.
- **Mutation-verifying on both runtimes.** No new coverage of the mutation itself. It would catch a
  self-test that is sharp on one runtime and blunt on the other, which is real but marginal against
  doubling every process launch.

## 4. Layout

```text
test/support/harness/
  shared/
    harness-runner.scm              wrapper-free; common R6RS/R7RS subset only
  chez/
    byte-machine/test/harness.sls   adapter + include of the shared body
  gambit/
    byte-machine/test/harness.sld   adapter + include of the shared body
  self/
    harness-bootstrap.scm           + .chez.sps + .gambit.scm
    harness-self-tests.scm          + .chez.sps + .gambit.scm
    harness-failing.scm             + .chez.sps + .gambit.scm
    harness-duplicate-case.scm      + .chez.sps + .gambit.scm
    harness-empty-selection.scm     + .chez.sps + .gambit.scm
test/support/launchers/
  chez-source.ss
cmake/
  ByteMachineExpectExit.cmake       exact-exit-status assertion
  ByteMachineSchemeLane.cmake       lane registration for a body x runtime
  ByteMachinePortabilityGuard.cmake wrapper pairing and basename uniqueness
test/support/cmake/
  ByteMachineExpectExitSpec.cmake
  ByteMachineSchemeLaneSpec.cmake
  ByteMachinePortabilityGuardSpec.cmake
  SchemeMutationSuite.cmake         harness mutations, distinct from MutationSuite.cmake
```

The Gambit library includes the shared body by source-relative path
(`../../../shared/harness-runner.scm`); the Chez library includes it by bare filename, resolved
through the launcher's `source-directories`. This is D6 in the milestone plan, and it is the one
place the two runtimes' mechanisms visibly differ.

## 5. The runner

One shared body, `harness-runner.scm`. It may use only identifiers common to R6RS and R7RS and must
never name either runtime. Everything a runtime does differently arrives through the adapter
protocol in §6.

### 5.1 Exported surface

| Group | Names |
| --- | --- |
| Lifecycle | `harness-begin` `harness-finish` `harness-summary` `harness-exit-status` `harness-empty-selection-error` `harness-empty-selection-diagnosis` |
| Structure | `harness-group` `harness-case` |
| Assertions | `check` `check-equal` `check-not-equal` `check-fail` `check-raises` `with-cleanup` |
| Statuses | `harness-status-pass` `harness-status-failed` `harness-status-harness-error` `harness-status-provenance` |
| Self-test | `harness-probe` `probe-cases` `probe-failed-cases` `probe-checks` `probe-failures` `probe-errors` `probe-skipped` `probe-cleanup-failures` `probe-raised?` `probe-failure-records` `failure-record-id` `failure-record-what` `failure-record-detail` `harness-set-filter!` |
| Pure helpers | `harness-string-contains?` `harness-join` `harness-split` `harness-take` `harness-member?` `harness-failure-context` `harness-normalize-filter` |
| Result state | `harness-counters` `harness-restore-counters!` `harness-capture-state` |

The rows above are forty-two of the fifty-six names each adapter exports; the other fourteen are the
adapter protocol of §6 and its three arithmetic re-exports. The list is derived from the adapters and
not the other way round: review pressure widened it four times during implementation, and a table
kept by hand drifts silently, because nothing loads it.

The pure helpers are exported so the runner's own tests can reach them. `harness-set-filter!` is
exported so the self-tests can exercise filtering without depending on the process environment.
`harness-empty-selection-diagnosis` and `harness-normalize-filter` are the pure rules behind
`harness-empty-selection-error` and `harness-begin`'s filter read, split out for the same reason: a
rule stated as a function of its inputs is directly assertable, while the same rule embedded in a
reader of live state is only observable through whatever that state happens to make visible — and in
the filter's case, nothing at all, since an empty needle matches every id. The result-state group
exists for the bootstrap, which has to undo its own deliberately failing check without using
`harness-probe`, itself one of the things the bootstrap exists to check.

### 5.2 Exit statuses

| Status | Meaning |
| --- | --- |
| 0 | every selected case passed |
| 1 | one or more assertions failed |
| 2 | harness, configuration, or registration error |
| 3 | **reserved** — the run could not confirm it executed the intended text. Declared here, produced first in slice 5. |

Status is computed at the end, never chosen at the throw site: any harness error yields 2, otherwise
any failure yields 1, otherwise 0. A single place to read means a new error path cannot forget to
change the status.

### 5.3 Rules

- **A raise inside a case is that case's failure, not the suite's death.** Guarded, recorded with
  `adapter-describe-condition`, and the run continues. Otherwise the first broken case hides every
  case after it, and the log names one defect where there may be five.
- **An empty selection is status 2.** Not 0, and not silence. This is the rule the test presets
  already enforce one layer up with `execution.noTestsAction`; a suite that ran nothing must not
  report success one layer down either. The diagnostic distinguishes "the filter skipped all N
  registered cases" from "the suite registered no cases", because those are different bugs.
- **A duplicate case id is a harness error, not a failure.** It means one registration silently
  became unreachable: coverage lost with no signal at all. This is the same reasoning already in
  `byte_machine_test_reserve_name`, applied one level down.
- **Probes suppress their own output.** A self-test that deliberately fails a check inside a probe
  must not print a `FAIL` line, or the log teaches readers to ignore `FAIL` lines.
- **Output is flushed per line.** Standard output is block-buffered when it is not a terminal, so a
  process killed by a supervisor loses everything it had written — and the run whose log matters
  most is the one that was killed.

The runner keeps two pieces of lifecycle state that come from the environment, both read once by
`harness-begin` and both treating an empty value as unset, because a shell that writes `VAR=` and one
that never sets `VAR` are otherwise indistinguishable in intent — and the same variable emptied by a
shell must not mean opposite things in the same harness:

| Variable | State | Effect |
| --- | --- | --- |
| `BYTE_MACHINE_TEST_FILTER` | `harness-filter` | only cases whose id contains the value run; the rest are skipped, and a run that selects nothing is status 2 |
| `BYTE_MACHINE_TEST_VERBOSE` | `harness-verbose` | every passing case prints `byte-machine-harness: pass <id>` |

`harness-verbose` is the one of the two with no in-process witness. Like probe suppression it changes
only what is printed, never a counter or a status, and the harness has no portable way to read back
its own output. `byte-machine.harness.verbose.chez.source` executes the path on a real runtime, so a
break that raises is caught and the feature cannot silently rot; that the line is actually printed is
checked by hand — running either self-tests lane with `BYTE_MACHINE_TEST_VERBOSE=1` prints one `pass`
line per case and none without it. Both of its decisions are declared survivors in §9's mutation
suite for that reason.

Every failure line is followed by a `FAIL-CONTEXT` record naming the test, backend, mode, OS,
architecture, runtime version, machine type, and artifact directory. `BYTE_MACHINE_TEST_NAME` and
`BYTE_MACHINE_TEST_TMPDIR` are already set on every registration by
[`byte_machine_add_test`](../../cmake/ByteMachineTesting.cmake); the context is emitted per failure
rather than once per run because a log is usually read at the failure, not from the top.

### 5.4 Recorded limitation: top-level raises

A raise at top level — outside any case, for instance in a wrapper between includes — kills the
process before `harness-finish` runs, with an implementation-defined status that differs between
Chez and Gambit and is not in the vocabulary above.

The fix would be to include each body inside a guarded thunk. That is rejected: it turns the body's
`define`s into internal definitions, and both standards require internal definitions to precede all
expressions in a body, while test bodies legitimately interleave helpers with their uses.

Slice 2 therefore accepts the limitation and makes it visible instead. `ByteMachineExpectExit.cmake`
reports "exit status *N* is not in the declared vocabulary" as a distinct failure rather than folding
it into an ordinary status mismatch, so a crashed lane cannot be misread as a failed assertion.

## 6. Adapter protocol

The adapter is the only place in the harness where runtime-specific identifiers may appear. Both
runtimes must export exactly these names, with the same arity and the same meaning.

| Name | Returns |
| --- | --- |
| `(adapter-runtime-name)` | `"chez"` or `"gambit"` |
| `(adapter-runtime-version)` | bare version number, implementation marker stripped |
| `(adapter-machine-type)` | raw implementation string; evidence only, never compared |
| `(adapter-os)` | `"darwin"`, `"linux"`, `"windows"`, or `"unknown"` |
| `(adapter-architecture)` | `"arm64"`, `"amd64"`, …, or `"unknown"` |
| `(adapter-execution-mode)` | declared by the lane registration through the environment |
| `(adapter-environment-variable name)` | string or `#f` |
| `(adapter-exit code)` | does not return |
| `(adapter-value->string v)` | string |
| `(adapter-describe-condition obj)` | string |
| `(adapter-flush-output)` | unspecified |

Both adapters additionally re-export `modulo`, `quotient`, and `remainder`, which the shared
test bodies call directly. R6RS keeps them outside `(rnrs)`, so Chez imports them from
`(rnrs r5rs)`; R7RS already provides them in `(scheme base)`, but Gambit re-exports them too, so
the shared test bodies do not need to know which runtime supplies them natively.

`adapter-os` and `adapter-architecture` are derived from Chez's machine type and from Gambit's target
triple. §24.2 stage 2 requires every Tier 1 cell to assert the expected runtime, OS, and
architecture; this slice makes the values available, and slice 7 adds the comparison against what
discovery recorded.

### 6.1 Deliberately absent

Four of protium's adapter operations are excluded, each for a reason rather than by triage:

- `adapter-monotonic-milliseconds` and the deadline layer it feeds. byte-machine has no async
  anywhere in its design; CTest's `TIMEOUT` is the only bound with a job to do.
- `adapter-seed-entropy`. protium seeds from the wall clock so seeds *vary* between runs. byte-machine
  is a determinism project — §22.9 compares output byte for byte across processes, runtimes, and
  operating systems — so a varying seed is not merely unnecessary here, it points the wrong way. When
  the PRNG arrives (M2 split schedules, M7 property tests) its seed must come from the environment
  with a fixed default.
- `adapter-threaded?`. Decision 0001 already refused to gate on threading.
- `adapter-file-bytes`. Its first consumer is the fingerprint in slice 5.

The protocol is designed to be extended in slice 5, not rewritten.

## 7. Lanes

### 7.1 Chez source

`test/support/launchers/chez-source.ss`, invoked as:

```text
<chez> --script chez-source.ss <library-root> <shared-dir> <object-guard-dir> <program>
```

It sets:

- `(compile-imported-libraries #f)` — a source lane must not quietly compile;
- `(source-directories (list <shared-dir> <the program's own directory>))` — D6's mechanism, so the
  library's bare-filename include and the program's own body include both resolve from any CWD;
- `(library-directories (list (cons <library-root> <object-guard-dir>)))`.

The pair in the last line is what lets the lane call itself "source" honestly. Chez looks for a
library's compiled object only in the *object* half of a pair, so pairing the source root with a
directory the build keeps empty means a stray `.so` can never be loaded. Pointing
`library-directories` at the source root alone would do the opposite: the object would be found
beside the source and silently preferred. The launcher asserts the guard directory exists and is
empty, and fails with status 2 if not.

Each of its three refusals — a wrong argument count, a guard directory that does not exist, and one
that has acquired a file — is a registered lane of its own asserting status 2 exactly
(`byte-machine.harness.launcher-usage`, `-absent-guard`, and `-dirty-guard`, all `.chez.source`),
because a lane that is set up correctly never reaches a refusal and could not notice one being
deleted. `(compile-imported-libraries #f)` restates Chez's own default, so deleting it is
unobservable and only turning it *on* has an effect: the object is then written into the guard
directory the correctly configured Chez lanes share — the two guard-refusal lanes above are the
exception, each having a guard of its own — so the next of the sharing lanes to start refuses to
run.

The pairing itself is checked by mutation, in the Scheme mutation suite's ninth pass. It is the one
launcher decision no lane in this tree can witness, because no library root here has a compiled
object beside its source for Chez to prefer: unpaired, the launcher behaves identically. The pass
therefore builds a library root that does have one — a genuinely compiled copy of the adapter whose
`adapter-runtime-name` returns a sentinel, sitting beside the pristine `.sls` — and runs the
self-tests body against it. Paired with an empty guard the object is unreachable and the body
passes; unpaired, Chez loads it and the sentinel appears in the banner, the `FAIL-CONTEXT` line, and
the exit status. A *garbage* `.so` proves nothing: Chez ignores a file it cannot read as a library,
and both runs then pass.

The launcher does **not** re-check for Petite or for threading. Discovery already rejects Petite at
configure time and re-probes the exact binary being registered, and decision 0001 explicitly refused
to gate on threading. A second copy of either rule here would be the copied-requirement pattern that
decision named.

### 7.2 Gambit source

No launcher script. `gsi -:search=<harness/gambit> <program>` is sufficient: Gambit's `include`
inside `define-library` is source-file-relative and needs no ambient state, and the program's own
body sits beside the program.

### 7.3 Execution-mode declaration

CMake sets `BYTE_MACHINE_EXECUTION_MODE=source` in each lane's environment at lane registration, and
`adapter-execution-mode` reports it. The launcher never touches this variable. For the Chez lane the
object guard makes the alternative lane impossible, so the declaration cannot be silently wrong.
Slice 5 must supply the equivalent guarantee for each compiled lane it adds.

## 8. Build layer

### 8.1 New modules

- **`ByteMachineExpectExit.cmake`** — runs a packed command and asserts an exact exit status.
  CTest's `WILL_FAIL` only distinguishes zero from nonzero and would accept a crash, a missing
  binary, or a launch failure as proof that an assertion failed. The module rejects an `EXPECT_EXIT`
  outside the declared vocabulary (§5.2) at configure time, so a typo becomes a build failure rather
  than a meaningless assertion, and reports an out-of-vocabulary *observed* status as its own
  distinct failure (§5.4).
- **`ByteMachineSchemeLane.cmake`** — registers one lane test for a body and a runtime, assembling
  the launcher invocation, the search paths, the environment, and the labels. Keeping this in one
  place means the eleven registrations below cannot drift apart. The three launcher-refusal lanes are
  the deliberate exception: this module exists to build the one *correct* command line, and those
  three need wrong ones, so they call `byte_machine_add_exit_code_test` directly.

- **`ByteMachinePortabilityGuard.cmake`** — the wrapper-pairing and basename-uniqueness rules of
  §8.4.

All three are build-layer modules, so all three take the standard the layer already lives by: a
functional core specifiable under `cmake -P` with no runtime present, a specification in
`test/support/cmake/`, and mutations that break each of their decisions in turn.

### 8.2 Registered tests

All are layer `harness`, so the existing `harness` and `pr` presets select them unchanged.

| Test name | Expected exit | Extra label |
| --- | --- | --- |
| `byte-machine.harness.bootstrap.chez.source` | 0 | |
| `byte-machine.harness.bootstrap.gambit.source` | 0 | |
| `byte-machine.harness.self.chez.source` | 0 | |
| `byte-machine.harness.self.gambit.source` | 0 | |
| `byte-machine.harness.failing-body.chez.source` | 1 | `expected-red` |
| `byte-machine.harness.failing-body.gambit.source` | 1 | `expected-red` |
| `byte-machine.harness.duplicate-case.chez.source` | 2 | `expected-red` |
| `byte-machine.harness.duplicate-case.gambit.source` | 2 | `expected-red` |
| `byte-machine.harness.empty-selection.chez.source` | 2 | `expected-red` |
| `byte-machine.harness.empty-selection.gambit.source` | 2 | `expected-red` |
| `byte-machine.harness.verbose.chez.source` | 0 | |
| `byte-machine.harness.launcher-usage.chez.source` | 2 | `expected-red` |
| `byte-machine.harness.launcher-absent-guard.chez.source` | 2 | `expected-red` |
| `byte-machine.harness.launcher-dirty-guard.chez.source` | 2 | `expected-red` |
| `byte-machine.harness.scheme-mutation.cmake.direct` | 0 | |
| `byte-machine.harness.cmake-expect-exit.cmake.direct` | 0 | |
| `byte-machine.harness.cmake-scheme-lane.cmake.direct` | 0 | |
| `byte-machine.harness.cmake-portability-guard.cmake.direct` | 0 | |

The empty-selection lanes are registered with `BYTE_MACHINE_TEST_FILTER` set to a string matching no
case, and the verbose lane with `BYTE_MACHINE_TEST_VERBOSE=1`. The verbose lane runs the self-tests
body a second time for one reason only: without it nothing in this repository ever executes the
verbose path (§5.3). The three launcher lanes run no body at all when they pass — each asserts that
the launcher refused to start (§7.1).

### 8.3 The `expected-red` vocabulary entry

[`CHANGELOG.md`](../../CHANGELOG.md) records `expected-red` as withdrawn "until slice 2 provides a
registration helper that can express it", but the entry is still present in
[`ByteMachineTesting.cmake`](../../cmake/ByteMachineTesting.cmake). This slice resolves the
contradiction in favour of the code: `expected-red` stays in the vocabulary and is used as a
**label**, never as a name segment, because the CTest test itself passes — it is the inner Scheme
process that must fail. The CHANGELOG line is corrected.

### 8.4 Portability guard

Split the same way every other module in this layer is: the rules are pure functions over a list of
filenames, specifiable under `cmake -P` with no files and no runtime present, and the imperative
shell globs the tree at configure time and raises. A violation is a configure failure, not a test
that runs later — a body missing a wrapper must stop the build, not produce a suite that quietly
proves one runtime.

A recursive `CONFIGURE_DEPENDS` glob over `test/support/harness/shared/` and
`test/support/harness/self/`, excluding `*.gambit.scm`, enforcing:

1. every body under `self/` has both a `.chez.sps` and a `.gambit.scm` wrapper;
2. shared-body basenames are unique across all shared-body directories (D6; slice 3 widens the glob
   to `src/common/`);
3. every declared directory contributed at least one body, and a call declaring no directory at all
   is a fatal error, since a guard that found nothing reports every source portable.

The glob is applied per directory rather than once over a combined pattern list, and it descends.
Both are about the same failure: a directory that yields nothing would otherwise pass on its
neighbours' bodies, and a body in a subdirectory would be neither checked nor reported. Rule 3 is
what slice 3 needs when it widens the guard to `src/common/`, which today holds only a `.gitkeep` --
under a combined check the harness directories would keep the result non-empty and the new
directory would be reported portable without having been looked at.

### 8.5 Mutation runner generalization

`MutationRunner.cmake` currently stages `cmake/*.cmake` and `test/support/cmake/*.cmake` and verifies
by running a specification under `cmake -P`. Two parameters are added:

- **stage set** — which trees are copied into the scratch tree, so the harness sources can be staged
  with the relative layout their includes depend on;
- **verify command** — what is run to decide whether a mutation was caught, so a harness mutation can
  be verified by the Chez source self-test lane instead of by `cmake -P`.

Everything else is unchanged and still applies: the source tree is only ever read, the baseline must
be green before any mutation is trusted, `SITES` is asserted exactly so a drifted pattern is a loud
failure rather than a skipped mutation, and `EXPECT_SURVIVES` requires a written reason and fails if
the mutation *starts* being caught.

Harness mutations are declared in a separate `SchemeMutationSuite.cmake` rather than appended to
`MutationSuite.cmake`, because the two have different verify commands and different runtime
requirements — the CMake suite must keep running under the `no-scheme` preset.

## 9. How the harness earns trust

Four layers, ordered by independence. Each depends on strictly less than the one below it.

1. **Exit-code tests (CMake).** Depend on nothing inside the harness. If the entire runner were
   vacuous, a body that fails while exiting 0 still fails here. This is the base case that breaks the
   chicken-and-egg problem: the outermost proof has no dependency on the thing it proves.
2. **Bootstrap body.** Judges the runner's primitives with raw conditionals and its own counter,
   using no assertion, case, group, or summary facility from the runner. It answers "does
   `check-equal` actually compare?" without using `check-equal` to ask. Deliberately failing checks
   run inside `harness-probe`, which isolates them from any enclosing state.
3. **Self-tests.** The full suite, using `harness-probe` to observe failing checks without those
   failures counting against the run. Covers recording, counting, classification, filtering,
   `with-cleanup`, and `check-raises`.
4. **Scheme mutation suite.** Breaks each decision in `harness-runner.scm` and in the Chez launcher on
   a staged copy and checks it against whichever lane can witness it: the self-tests for most
   decisions, the bootstrap lane for the failure counter every assertion reports through, the
   empty-selection lane for the environment read no in-process assertion can reach, and one lane per
   launcher refusal, since a lane that is set up correctly never reaches one.

   Five decisions are declared survivors rather than caught, each with a written reason the suite
   fails if it goes stale. Three are print-only — probe output suppression and the two halves of
   `harness-verbose` — and are unwitnessable for the same reason: they change what is printed, never a
   counter or a status, and the portable subset has no string ports to read output back with. One is
   the export list's three splice-resolved names (§9.1). The last is the launcher's
   `compile-imported-libraries` call, whose only observable effect is a file written *after* the guard
   directory's emptiness has already been asserted, so it is visible to the next process and not to
   the one that wrote it; the registered lanes do catch it, because the correctly configured ones
   share a single guard directory.

   One pass stands apart from the rest: the `library-directories` pairing is witnessed against a
   library root the pass compiles a poisoned object into, because no root in the tree has an object
   beside its source and the mutation is therefore invisible everywhere else (§7.1).

### 9.1 Adapter name parity

D4 requires both adapters to export exactly the same names. Scheme cannot portably reflect on a
library's export list, so the check is made by mutation: deleting an export from `harness.sls` or
`harness.sld` must make a lane fail.

Which lane, and what forces it, is worth stating exactly, because the property that makes the
mutation bite is not "every name is used somewhere" but "every name is referenced from a body or
wrapper, which is *outside* the library":

- The **self-tests body references every adapter-protocol name**, including `adapter-exit`, which it
  can only name and not call. That is what makes running this one body on both runtimes a parity
  proof for the adapter rather than a coincidence, and it is the whole basis of the mutation suite's
  second pass — the only per-runtime witness the Gambit adapter has.
- Every **wrapper references `harness-begin` and `harness-finish`**.
- The **bootstrap body** covers the pure helpers and the result-state group: `harness-join`,
  `harness-split`, `harness-take`, `harness-member?`, `harness-counters`,
  `harness-restore-counters!`, and `adapter-exit` again.
- Three names are referenced by **no body and no wrapper**: `harness-summary`,
  `harness-empty-selection-error`, and `harness-failure-context`. All three are used only inside
  `harness-runner.scm`, which `include` splices into the library body, so those references resolve
  whatever the export list says. Dropping any of them is undetectable, and the suite records that as
  an expected survivor rather than leaving it to be discovered.

A name present in one adapter and absent from the other is otherwise invisible until some later
milestone happens to use it.

### 9.2 Mutations to declare

At minimum, one per decision in the runner and in the Chez launcher:

- assertion comparison inverted or made unconditionally true (`check`, `check-equal`,
  `check-not-equal`);
- failure counter not incremented;
- `harness-current-case-failed` never set, so failures do not become failed cases;
- duplicate case id accepted rather than recorded as an error;
- a raise inside a case escaping instead of being recorded;
- `check-raises` accepting a thunk that returns normally;
- `with-cleanup` swallowing the original raise, or not running cleanup after a raise;
- empty-selection detection removed;
- `harness-begin` ignoring `BYTE_MACHINE_TEST_FILTER` from the environment;
- exit-status precedence changed so a failure outranks a harness error;
- probe state not restored, or probe output not suppressed;
- `BYTE_MACHINE_TEST_VERBOSE` not read, or a passing case not announced when it is set;
- an export deleted from each adapter (§9.1);
- each of the launcher's three refusals removed — wrong argument count, absent guard directory,
  guard directory with a file in it — and each entry of its source path dropped;
- the launcher allowed to compile what it imports;
- the library root unpaired from the object guard, witnessed against a library root that holds a
  compiled object (§7.1).

## 10. Work order

Each step must fail before it passes.

1. `ByteMachineExpectExit.cmake` — specification first, then the module, then its mutations. Pure
   CMake; runs under the existing `no-scheme` preset with no runtime installed.
2. Register `byte-machine.harness.failing-body.chez.source` expecting exit 1. It fails because
   nothing exists. Build the minimum runner, Chez adapter, launcher, and `ByteMachineSchemeLane`
   that makes it pass. This is the slice's central failing test.
3. `harness-bootstrap.scm` and its wrappers — drives the pure helpers and the assertion primitives.
4. `harness-self-tests.scm` and its wrappers — drives the probe, counters, classification,
   filtering, `with-cleanup`, and `check-raises`.
5. `harness-duplicate-case.scm` and `harness-empty-selection.scm` — drive status 2.
6. Gambit adapter and lane; the same six bodies green on both runtimes.
7. Generalize `MutationRunner`; write `SchemeMutationSuite.cmake` with the §9.2 declarations.
8. Portability guard: wrapper-pair check and shared-body basename uniqueness.
9. `CHANGELOG.md` entry; correct the `expected-red` line.

## 11. Out of scope

| Deferred | To |
| --- | --- |
| Content fingerprinting and `adapter-file-bytes` | slice 5 |
| Chez AOT, Gambit `.o1`, Gambit `-exe -nopreload` | slice 5 |
| Producing exit status 3 | slice 5 |
| Deterministic PRNG, seed reporting and replay | M2 split schedules / M7 property tests |
| Inner deadlines and `harness-await` | never — byte-machine has no async |
| Comparing reported OS/architecture against discovery (§24.2 stage 2) | slice 7 |
| CI workflow | slice 7 |
| A decision record for this slice | written at the end of the slice, once there is evidence to record |
| Any byte-machine semantics | milestone plan §11 |

## 12. Exit criteria

- `harness-failing.scm` exits **1** on Chez and on Gambit, asserted as an exact status;
- `harness-self-tests.scm` exits **0** on Chez and on Gambit;
- a duplicate case id and an empty selection each exit **2** on both runtimes;
- the bootstrap body passes on both runtimes without using any assertion, case, group, or summary
  facility from the runner;
- every mutation in `SchemeMutationSuite.cmake` is caught by a lane that can witness it, or is
  declared `EXPECT_SURVIVES` with a written reason;
- deleting from either adapter any export a body or wrapper references makes a lane fail; the three
  that nothing outside the library references are the declared exception, recorded in §9.1;
- the portability guard fails when a body is missing a wrapper, when two shared bodies share a
  basename, when any declared directory contributes no body, and when no directory is declared;
  its glob recurses, so a body in a subdirectory is checked rather than unseen;
- `ByteMachineExpectExit`, `ByteMachineSchemeLane`, and `ByteMachinePortabilityGuard` each have a
  `cmake -P` specification and mutations against their decisions;
- `make dev` runs all of the above; `ctest --preset no-scheme` still passes with no runtime
  installed.

## 13. Risks

| Risk | Response |
| --- | --- |
| The Gambit source mode diverges from protium and from the milestone plan's four-lane D5. | D5's four lanes are the *proof* lanes and are unchanged; the source lane is a fifth developer lane. §24.2 already asks for a source suite runnable without native compilation. Record it in the slice's decision record. |
| The mutation runner generalization breaks the existing CMake mutation suite. | The existing suite keeps its current behaviour as the default for both new parameters, and its baseline check already fails loudly if staging goes wrong. |
| Self-tests grow to depend on the harness features they test, hollowing out the proof. | The bootstrap layer exists precisely for this and may not use those features. Mutations against assertion comparison are the check that the layering held. |
| `expected-red` remains ambiguous between a layer name and a label. | §8.3 fixes it as a label only. If a future slice wants it as a name segment, the vocabulary should split into layers and labels rather than overloading one list. |
