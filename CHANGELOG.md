# Changelog

All notable changes to byte-machine are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Milestones 0 through 3 (portability spike, minimal executable machine,
incremental execution and lifecycle, byte classes and sequences) have closed.
Milestone 3 closed **2026-08-30** with Slice ③ (multiple alternatives,
ambiguity, and cycle analysis), after Slices ① (byte classes) and ② (sequence
dispatch and prefix lowering); Milestone 4 (fields, actions, and branches) is in
progress — its Gate 0 discharged **2026-08-31** (decisions 0018–0022) and Slice
①a landed **2026-09-02**, with Slices ①b, ② and ③ remaining. See
[the implementation plan](docs/plans/byte-machine-implementation-plan.md) §25
for overall scope; the entries below record what each milestone actually
delivered. No versioned release exists yet.

### Changed

- **The generated-code ABI is one unversioned constructor, and its version is
  now 3.** `byte-machine-make-compiled-machine` replaces the `/vN` family; its
  first action is the `(= abi-version current-abi-version)` check, so a mismatch
  is reported before any part of the payload is interpreted, and the payload is
  one growable quoted vector rather than a rest-arg, which keeps growth and the
  version check coupled. `/v1` and `/v2` remain exported as tombstones that
  refuse **every** version — a tombstone that still accepts a number is a hole,
  and after the bump `/v2`'s old literal-2 guard would have accepted exactly the
  stale files it was added to refuse. Generation is deterministic and the three
  committed goldens are regenerated from the emitter. See
  [decision 0018](docs/decisions/0018-unversioned-generated-abi-constructor.md);
  this satisfies §9.5:444's three requirements for a pre-1.0 ABI change.
- **The canonical normalized encoding is format 2**, carrying the static reason
  of every error declaration the graph **reaches** — an error node's, and the
  machine default-eof error's — and reserving a field-table count of zero. Two
  machines differing only in a reached declaration's reason therefore differ in
  IR fingerprint, without which the fingerprint would stop identifying what was
  emitted. All four pinned fingerprints moved once, here. See
  [decision 0019](docs/decisions/0019-encoding-format-2-pre-provisioned.md).
- **A parser error is a structured record, not a bare code symbol.**
  `parser-result-error` now yields a `parser-error` carrying domain, code,
  reason, detail, public source-node name, state ID, absolute offset and
  position kind (§9.3:397-405), constructed identically by the reference
  interpreter and by generated code. See
  [decision 0022](docs/decisions/0022-structured-parser-error-record.md).

### Added

- CMake build frontend with checked-in presets and a thin `Makefile` over it.
- Probe-based Chez and Gambit discovery that interrogates candidates rather
  than trusting binary names, rejecting Petite and Ghostscript's `gsc`. See
  [decision 0001](docs/decisions/0001-toolchain-discovery.md).
- CTest registration helper enforcing the test-name grammar, label vocabulary,
  duplicate-name rejection, and mandatory timeouts at configure time.
- Specifications for the functional core of every build-layer module, runnable
  under `cmake -P` with no Scheme runtime present.
- A mutation suite that breaks each decision in each module on a staged copy and
  requires the owning specification to notice, so "the specifications pass" is a
  claim the repository can check rather than one it merely asserts.
- A specification for the shared assertion helper itself, which every other
  specification depends on and none of them could have caught breaking.
- `.gitattributes` normalizing the repository to LF and marking fixture trees
  binary, since generated-source comparison and CRLF-framed HTTP fixtures both
  depend on exact bytes.
- A dependency-free portable test harness: one shared runner body included by a
  thin `(byte-machine test harness)` library per runtime, with adapters that
  export identical names and contain no test semantics of their own. Assertions,
  groups and cases, an isolated self-probe, and a computed exit status.
- Source execution lanes for both runtimes. Chez runs through a launcher that
  pairs the library root with an always-empty object directory, so a stale
  compiled object cannot be loaded by a lane that calls itself source. Each of
  the launcher's three refusals — a wrong argument count, a guard directory that
  is missing, and one that has acquired a file — is a lane of its own asserting
  status 2, because a lane that is set up correctly never reaches a refusal and
  so cannot notice one being deleted. Gambit gains a `source` mode: both of its
  compiled modes shell out to a C compiler fixed when Gambit was built, which
  would have made the first slice that runs Scheme unable to run on Gambit at
  all without that toolchain.
- Exact-exit-status assertions. The harness gives 0, 1, and 2 distinct
  meanings, and reserves 3, not yet produced, for lane provenance in a later
  slice. An expectation outside this four-value vocabulary is a configure
  error. A status outside it that is *observed* is reported as its own failure
  rather than as a wrong assertion outcome, since it means the process died
  before the harness could report.
- Mutation testing extended to the Scheme harness and to the Chez launcher. Each
  decision is broken on a staged copy and checked against whichever lane can
  witness it: the self-tests for most decisions in the runner, the bootstrap lane
  for the failure counter every assertion reports through, the empty-selection
  lane for the environment read no in-process assertion can reach, and one lane
  per launcher refusal. Adapter export parity is checked the same way, on each
  runtime, because Scheme cannot portably reflect on a library's export list.

  Five mutations are declared survivors instead, each with a written reason the
  suite fails if it stops being true. Three are print-only — probe output
  suppression and the two halves of `BYTE_MACHINE_TEST_VERBOSE` — and share one
  cause: they change what is printed, never a counter or a status, and the
  portable subset has no string ports for a suite to read its own output back
  with. One is `harness-summary`, `harness-empty-selection-error`, and
  `harness-failure-context`, used only inside the shared runner body that
  `include` splices into each adapter's library, so an internal reference
  resolves whatever the export list says and dropping one of the three is not
  detectable. The last is the launcher's `compile-imported-libraries` call:
  deleting it restates Chez's default and changes nothing, and turning it on
  writes an object into the guard directory only *after* that directory's
  emptiness has been asserted, so the pollution is visible to the next process
  and not to the one that caused it. The registered lanes do catch that one —
  the correctly configured ones share a single guard directory — which this
  suite, one process per mutation, cannot.

  The pairing that makes a Chez source lane honest is checked against a library
  root built for the purpose: no root in the tree has a compiled object beside
  its source, so unpairing the root from the guard is invisible everywhere else.
  The pass compiles a poisoned copy of the adapter — one whose runtime name is a
  sentinel — into a root of its own, beside the pristine source. Paired, the
  object is unreachable and the self-tests pass; unpaired, Chez loads it and the
  sentinel comes out in the banner, the failure context, and the exit status.
- A portability guard failing the build when a shared test body is missing a
  wrapper, when two shared bodies share a basename, when any declared directory
  contributes no body, when no directory is declared at all, when it receives an
  argument it does not recognize, or when a `SHARED_DIRS` or `WRAPPED_DIRS`
  entry is not an existing directory. Its glob recurses, so a body in a
  subdirectory is checked rather than unseen. Every rule past the first two was
  added after being shown to leave a tree unchecked while still producing a
  green build.
- The first product library: one shared body in `src/common/byte-machine/`
  included by exactly one thin library per runtime. Its type tag and singleton
  are freshly allocated rather than symbols, because symbols are interned and a
  symbol tag would make a body included twice indistinguishable from one
  included once — the defect the one-owner rule exists to prevent.
- A working-directory matrix. The same body loads through both wrappers from
  three directories chosen so each catches a different failure: a copy where an
  include resolved against the working directory would accidentally succeed, a
  same-named impostor where it would report the wrong answer, and an empty
  directory where it would find nothing. All three pass under a correct
  mechanism, so what proves them is a launcher mutation whose expected outcome
  is asymmetric — the first passes, the other two fail — with the survivor
  asserted rather than ignored.
- Mutation coverage that runs on both runtimes for the shared body, inverting
  the rule the harness runner uses. A wrapper that quietly reimplemented the
  body is exactly a wrapper whose runtime does not notice the body changing, so
  the claim that no wrapper duplicates semantics is witnessed rather than
  reviewed.
- The Chez launcher takes repeatable `--library-root` and `--source-dir` flags,
  since a lane now imports from both the harness and the product tree. Each of
  its parse refusals is a lane asserting status 2, because a correctly set-up
  lane never reaches one.
- A Gambit search root containing a comma is refused at configure time.
  Gambit's `-:` options are comma-separated, so such a root makes `gsi` print
  its usage banner and run no Scheme at all, on every Gambit lane at once, in
  output that names nothing this project owns. A relative search root is
  refused too, for a different reason: `gsi` resolves it against its own
  working directory, so the lane would find its libraries or not depending on
  where it was launched — the one thing the working-directory matrix exists
  to rule out.
- `byte_machine_add_test` gains an optional `WORKING_DIRECTORY`, overriding
  its derived per-test run directory; the temporary directory it also creates
  is unaffected. `byte_machine_add_exit_code_test` and
  `byte_machine_add_scheme_lane` forward it, which is what lets the
  working-directory matrix launch six lanes from three fixture directories
  instead of their derived ones.
- Cross-library identity proof (Milestone 0 slice 4, deliverable D3). A second
  library per runtime, `(byte-machine placeholder-consumer)`, built over its own
  wrapper-free body whose free identifiers are supplied by the wrapper's import
  of `(byte-machine placeholder)`. A shared test body importing both libraries
  asserts that a value built through the owner is recognised through the
  consumer, and that the allocation-free singleton is one object across both
  imports.
- The consumer body additionally proves a mechanism Milestone 1 depends on and
  nothing previously exercised: a shared body naming another library's exports
  as free identifiers, resolved identically by R6RS library-body `include` and
  R7RS `define-library` `include`.
- Eight Scheme mutations in four passes (24 to 27), bringing the suite to 27
  passes and 64 mutations. The decisive two replace each consumer wrapper's
  import with an include of the owner's body: the mutant answers both
  identity claims wrongly and raises nothing, but the identity lane still
  fails it — an ordinary `check`/`check-equal` mismatch, exit 1 on both
  runtimes — while every lane that imports only the owner stays green.
- [Decision 0003](docs/decisions/0003-cross-library-identity.md), including
  the deferred one-owner guard with the condition that reopens it, and an
  open question about Chez and Gambit disagreeing over a library body that
  redefines an imported name.
- A content fingerprint of the shared test bodies a lane's manifest names,
  checked in-process against a value the build computed from the same files
  before the run — proving the declared text is unchanged on disk and read
  identically by both runtimes, not that the run executed it, so two lanes
  claiming to run the same text can be shown to disagree rather than merely
  trusted to agree. `adapter-file-bytes`
  reads a file through a binary port on both runtimes, the last piece of
  slice 2's adapter protocol left unimplemented. The algorithm is a
  polynomial rolling hash using only exact integer arithmetic, never bitwise
  operations, since neither R6RS nor R7RS guarantees the latter over the
  unbounded range the fold needs. Hex renders through an explicit lowercase
  digit table rather than `number->string` with a radix, because Chez and
  Gambit render `(number->string 255 16)` as `FF` and `ff` respectively —
  measured on both runtimes — and a fingerprint whose case depended on that
  would make the one claim it exists to carry, that both runtimes agree,
  depend on a detail they already answer differently.
- The expectation a lane's fingerprint is checked against is computed once
  at build time, from the repository sources, by `load`ing the same
  `fingerprint.scm` the lane itself runs rather than reimplementing the
  algorithm a second time — a second implementation agreeing with the first
  would prove nothing, since the two could drift and the drift would look
  like a passing comparison. A run that cannot show it executed the intended
  text now exits status 3 before any test case runs: the first thing in this
  tree to produce the status slice 2's decision S3 reserved for exactly
  this.
- `byte_machine_add_scheme_lane` gains a required `SHARED_BODIES` argument:
  a lane cannot be registered without declaring the manifest it will be
  checked against. At run time, an unset or empty manifest means the
  process was not started by a lane registration — a developer running the
  harness by hand, or the mutation suite, whose own machinery runs every
  verify command with no environment at all — and provenance is skipped
  rather than refused, because refusing would fail the mutation suite's own
  baseline before a single mutation ran. The guarantee lives at configure
  time, where it cannot be forged by anything a running process does.
- Six new lanes prove the check can fail, each exiting exactly 3, for one
  of four diagnoses: a wrong expectation (reported identically by the Chez
  and Gambit lanes, which differ only by runtime), a build that never
  produced one, a manifest naming a body that cannot be read, and a manifest
  the run never verified at all. The suite grows from 40 to 46 tests and the
  Scheme mutation suite from 27 to 35 passes (64 to 83 mutations), breaking
  every decision in the algorithm and in the check itself on a staged copy. One of those mutations — the hex digit table
  turned uppercase — was predicted to be caught only on Gambit, since the
  build-time expectation loads the same mutated file a Chez lane runs
  against; measured, it is caught symmetrically on both runtimes instead, by
  an unrelated self-test comparison against fixed literal strings, because
  the passes that carry it set no manifest and provenance never runs there
  at all. Both the design record and the mutation suite's own comment were
  corrected once this was measured.
- A lane that was given a manifest and never verified it now exits 3.
  Requiring the manifest at configure time makes the environment
  unforgeable; it says nothing about whether anything read it, and the check
  is reached either through `harness-begin` or through a hand-placed call —
  which is what the bootstrap body needed, having deliberately no
  `harness-begin`. Forget that line in a future body and the lane runs
  un-provenanced with nothing failing, which was the last way the
  configure-time guarantee could hold while the run-time one did not. The
  guard fires from the summary, so it cannot catch a body that reaches
  neither the summary nor the check — the bootstrap's own shape, a single
  deliberate exception that carries its own call.
- [Decision 0004](docs/decisions/0004-content-fingerprint-and-provenance.md),
  including the bound the manifest does not close — a matching fingerprint
  proves the declared text is unchanged, not that the run included exactly
  those files — and the open question that reopens it.
- A Chez ahead-of-time lane for each of three programs the source lanes
  already run — `bootstrap`, `self`, and `placeholder-identity`, the last
  discharging slice 4's deferred compiled-lane identity claim for Chez. Each
  pair verifies against the same expectation file as its `chez.source`
  counterpart, since both declare the same manifest and the expectation is
  keyed by it. The compiled program is loaded with every object directory
  paired against an always-empty source guard, so nothing on the library
  path can be expanded from source behind the artifact's back; a guard that
  has acquired a file is refused at status 2 by a lane of its own, because a
  correctly configured lane never reaches that refusal.
- A compiled lane's fingerprint now describes the text its artifact was
  built from rather than the text on disk when it ran. The build command
  that compiles the artifact also writes, in the same command, a copy of
  every declared source as that compile resolved it; the lane measures those
  copies, while the expectation stays computed from the repository
  originals. A source lane's declared and measured lists are the same list,
  since current disk contents are the only text a source lane has; a
  compiled lane's are two, and the measured one describes what its artifact
  was compiled from. That difference is the whole of the change.
  `byte-machine.harness.stale-artifact.chez.aot` is what makes the
  disagreement reachable rather than argued: it declares the same manifest
  as `byte-machine.harness.self.chez.source` and is checked against the same
  expectation, while its artifact is compiled against a divergent fixture
  copy of `(byte-machine test harness)` — so it exits 3 with the fingerprint
  mismatch diagnosis instead of passing. This closes the gap decision 0004
  recorded for slice 5b, by the alternative that record dismissed rather
  than by the build-time literal it proposed, and 0004 now carries the
  amendment saying so.

  Two bounds, stated because neither is closed. A lane is still not shown to
  touch exactly the files it names — the manifest is declared, not observed,
  and nothing here narrows that. And the copies sit *beside* the artifact
  rather than inside it: one producer means the build cannot leave them
  separately stale, but the artifact's own bytes enter neither side of the
  comparison, so a build tree disturbed by hand can desynchronise them. A
  value compiled into the object would be strictly stronger, and is recorded
  as the shape that reopens this.
- Mutations for every decision the compiled lanes added, each asserting a
  failure signature rather than a nonzero exit. In the build layer, caught
  by the lane specification under `cmake -P` with no Scheme runtime present:
  a compiled lane measuring the repository originals, the measured list
  built in reverse, the execution mode emitted as the literal `source`
  again, and the three ways the artifacts builder can be miswired — never
  called, called for every lane, and the stale root parsed and never
  forwarded. In the Scheme layer: unpairing the aot launcher's source guard,
  which makes Chez expand a library planted in an object directory and
  `load-program` refuse at 255; a pass for each of the three refusals the
  two compiled-lane launchers add — a missing compiled program, a source
  guard that has acquired a file, and a `--library-root` left unpaired with
  an `--object-dir`; and slice 5a's three carried provenance decisions —
  the manifest separator, the digest combination order, and the status a
  provenance failure exits with. Leaving `source-directories` unemptied in
  the aot launcher is a declared survivor carrying its measured reason:
  resolution runs through `library-directories`, and decision 0006 leaves no
  `include` for it to resolve. The last carried decision was planned as a
  survivor too and shipped caught instead — a manifest that fingerprints the
  mutated body makes any edit to it fail provenance on its own, which is
  what reaches the exit line, and the mutant exits 1 while the summary
  printed immediately above still names status 3. The CMake suite stands at
  1 pass / 72 mutations and the Scheme suite at 31 passes / 68 mutations,
  each asserting its own totals; the pull-request and release selections
  stand at 37 lanes and `no-scheme` at 8.
- The Milestone 0 close-out design
  (`docs/plans/milestone-0-close-out.md`), stating what the milestone
  delivered against its own deliverable list, why three of its deliverables
  could not be executed as originally specified, and where each lands in
  Milestone 1 instead.
- A Tier 1 CI feasibility note (`docs/plans/milestone-0-ci-feasibility.md`),
  discharging Milestone 0's second exit criterion with a design covering the
  two Tier 1 platform cells this host cannot run — not a running pipeline.
- [Decision 0007](docs/decisions/0007-milestone-0-closes-at-the-harness.md),
  recording that Milestone 0 closes at the harness, and answering the parent
  plan's four remaining hard questions with each answer's evidence level
  stated rather than assumed.
- Continuous integration on macOS arm64 and Linux amd64 (the first CI in the
  repository), running the full test suite and asserting each cell's OS and
  architecture (Milestone 1, Phase 1).
- The semantic core (Milestone 1, Phase 2): immutable source-IR descriptors
  and the public (byte-machine graph) constructors; a structural verifier
  (name resolution, exact-byte overlap, reachability, zero-progress cycles,
  terminal/EOF shape, generated-name safety); a runtime parser lifecycle with
  the compiled-machine ABI; and a reference interpreter. The one-byte machine
  ("accept one exact byte, reject the rest at position 0") is proven through the
  interpreter across all 256 byte values in both the Chez source and AOT lanes.
  Error references are symbolic; EOF is declared and verified but not executed.
- Milestone 1 Phase 3 Slice A: the emitter and the interpreter≡generated
  differential. A verified one-byte machine is normalized to a canonical IR with
  a 64-bit FNV-1a IR fingerprint, emitted as a complete importable `.sls` that
  imports only `(byte-machine runtime)` and constructs a direct executor through
  the new `byte-machine-make-compiled-machine/v1` ABI, and proven to match the
  reference interpreter across all 256 byte values in both the source and AOT
  lanes, plus the §9.6 end-to-end example. Decision 0010 records the ABI.
- Milestone 1 Phase 3 Slice B: the D6 determinism-hardening and D7
  identifier-repertoire proofs Slice A's emitter had to satisfy but not yet
  exhaustively prove, a property-based machine generator, and the member-2
  runtime-export drift guard. D6 is a determinism spec, registered in both
  the `chez.source` and `chez.aot` lanes, that emits the fixed one-byte
  machine twice in one process and asserts byte-equality, compares the
  emitted bytes to a committed raw-byte golden fixture
  (`test/fixtures/generated-one-byte.golden.sls`), and compiles and executes
  the result — comparison is over raw bytes through the project-owned
  writer, never `write`. Because both CI cells run the same golden
  comparison in both lanes, cross-process, cross-lane, and cross-cell
  byte-identity follow transitively; M9 completes the four-cell matrix
  against the same golden. D7 is an exhaustive accept/reject proof of
  `[a-z][a-z0-9-]*` at both grammar sites — machine/node/error names
  (`verify`'s `valid-name?`) and output bindings (`compile`'s
  reserved-binding predicate) — covering uppercase, non-ASCII, punctuation,
  and the empty/leading-digit/leading-hyphen/trailing-hyphen boundary cases,
  diagnostics checked by category rather than prose; plus a binary-LF proof
  that reads the emitted bytes raw and asserts no CR byte appears and the
  final byte is LF. As milestone-1-design.md §6 already notes, the genuine
  Windows CRLF-translation trap only manifests on a Windows cell, which M1 CI
  does not have, so this proof runs where it is trivially clean; the real
  Windows proof rides to M9.

  A deterministic in-tree PRNG (`(byte-machine test prng)`) and a bounded,
  valid-machine generator (`(byte-machine test machine-gen)`) drive the
  interpreter≡generated differential over 40 generated machines (fixed seed,
  printed on every run) rather than only the fixed one-byte machine, each
  checked against all 256 single-byte feeds. A new `property` test label is
  added to the `pr` preset filter. The generator emits a single dispatch node
  plus terminals and the differential feeds single bytes — mutually covering
  for the M1 repertoire (one dispatch state, single-byte feeds reach every
  transition); the fuller multi-dispatch-node generator and the multi-byte /
  fragmented feed schedule (parent §22.5) are deferred to a later slice, where
  they first become differentially observable. The member-2 runtime-export drift guard
  asserts `(environment-symbols (environment '(byte-machine runtime)))` is
  set-equal to `compile.sls`'s declared `reserved-member-2`, made
  load-bearing by a mutation that drops one entry, caught on the
  set-inequality FAIL line rather than by a bare nonzero exit. This ships
  with no `/v2` runtime export — `/v2` remains gated on benchmark evidence
  per [decision 0010](docs/decisions/0010-direct-executor-abi.md) §5, which
  is amended to record that the guard's value does not depend on `/v2`
  shipping. Measured on the shipped tree: `release` 60/60, `no-scheme` 8/8,
  the Scheme mutation suite 37 passes/104 mutations, the CMake mutation
  suite 1 pass/72 mutations.
- Milestone 2 Gate 0: three decision records answering the EOF, ABI, and
  condition questions Milestone 1 handed forward, with no code change.
  [Decision 0011](docs/decisions/0011-eof-execution-model.md) fixes the EOF
  execution model. `parser-finish!` runs the same executor loop as feed with input
  permanently exhausted, and the only branch that differs is a dispatch node with
  no byte available: feed returns `need-input`, finish instead takes that node's
  `eof-target` — the named node when set, else the machine `default-eof-error`.
  EOF success is its own `finish` node kind rather than a `stop` re-read on the
  finish path, because that "polysemous stop" model describes a machine parent
  §16.2 requires the verifier to *reject*; and eof-targets chain, terminating at
  `finish`, `error`, or (Slice ③) `pause`, never at `stop`.
  [Decision 0012](docs/decisions/0012-generated-abi-v2-finish.md) takes the
  `/v2`-constructor-over-arity-break seam
  [decision 0010](docs/decisions/0010-direct-executor-abi.md) item 4 had already
  fixed for exactly this kind of change: `byte-machine-make-compiled-machine/v2`,
  `current-abi-version` 2, one unified `exec` closure carrying a `finish?` flag
  rather than two closures, terminal arms one per kind, and the `feed-outcome`
  record shape reused — `finished` and `paused` are new status *symbols*, not a new
  record. [Decision 0013](docs/decisions/0013-runtime-coded-conditions.md) lets
  `runtime.sls` import `(byte-machine private conditions)`, so lifecycle misuse and
  the §11.1 invalid-slice contract raise `&byte-machine-contract` with a stable
  `code`/`who` the tests assert directly rather than `assertion-violation` text.
  That was decision 0010 item 5's deferral, whose blocker was the `CORE_ALL` lane
  manifest; 0013 removes it by de-duplicating the manifest.

  The design this gate serves was revised the same day after a systematic audit
  against the parent plan's normative sections and the Milestone 1 source. The
  audit is what corrected the EOF-terminal modeling error above, and it surfaced a
  latent Milestone 1 sticky-feed bug that Slice ②a then fixed. Docs only: the lane
  count stays 60 and both mutation suites are untouched.
- Milestone 2 Slice ①: incremental execution, proven over the first machine with
  more than one dispatch node. A four-byte accept-sequence fixture
  (`(byte-machine test sequence-machine)` — `s0` through `s3` each read one byte of
  `1 2 3 4` into a `stop`, every fallback reexecuting into the reject error so a
  wrong byte's `next` points *at* the offending byte, parent §11.5) gives three
  interior split points, which is what makes parent §22.5's split-point pairs and
  multi-split schedules satisfiable at all. Its interpreter≡generated differential
  covers whole-input accept and per-position reject; all 256 bytes at each of the
  four positions; every fragmentation of the input, including leading, intermediate
  and trailing empty feeds and a deterministic multi-split schedule; and
  nonzero-offset slices asserting exact `next`/`consumed`/`stream-offset`. The §9.6
  end-to-end example gains a nonzero-offset case — byte 0 at index 1 of a padded
  buffer, fed as `[1,2)` — reusing the library the first case emitted and loaded,
  so the example stays one narrative rather than two.

  No `src/` change, and that is the point: Milestone 1's feed engine already
  accepted an arbitrary `(bv start end)` and already reported `need-input` and
  exact offsets, so this slice is the evidence that it does, over a machine whose
  multiple dispatch nodes can actually distinguish a correct implementation from a
  lucky one. It never re-feeds a terminal parser: the §12.2 sticky-repeat path was
  still broken at this commit, and fixing it is Slice ②a's job. Two lanes under a
  new `differential.sequence` name, source and AOT, take the lane count 60 → 62;
  both mutation suites unchanged.
- Milestone 2 Slice ②a: the lifecycle spine. The parser gains an explicit lifecycle
  field (`ready` | `stopped` | `error`) and exports `parser-lifecycle`. It replaces
  the ad hoc result cache Milestone 1 used to make terminal results sticky, and
  removing that cache *is* the fix for the bug the Milestone 2 design audit found: a
  repeat `parser-feed!` on a terminal parser now re-runs the executor — idempotent
  for `stop` and `error` in this callback-free milestone — and returns the §12.2
  sticky-repeat tuple (`next` = `start`, `consumed` 0, the stored offset) by
  construction, instead of by a cached value that could disagree with the parser's
  actual state. A stored-result short-circuit returns at Milestone 5, when callbacks
  make re-execution non-idempotent. `parser-reset!` ships the Milestone 2 subset of
  parent §12.5: the parser vector grows an `entry` slot, and reset restores `current`
  to the entry state, zeroes the stream offset, and returns lifecycle to `ready`.

  Per [decision 0013](docs/decisions/0013-runtime-coded-conditions.md),
  `runtime.sls` now imports `(byte-machine private conditions)`, and
  `parser-feed!`'s invalid-slice guard raises `&byte-machine-contract` (code
  `invalid-slice`, who `parser-feed!`) instead of `assertion-violation`. Because
  that import puts `conditions.sls` into `CORE_ALL` by two paths at once — the
  runtime manifest and, via graph/ir, the verify manifest — the stored `CORE_ALL`
  value is de-duplicated before it is reused, keeping the per-lane
  duplicate-basename guard green. `compile.sls`'s `reserved-member-2`, the
  hand-maintained mirror of the runtime's exports, gains `parser-lifecycle` and
  `parser-reset!` so the member-2 drift guard stays accurate. The Scheme mutation
  suite drops the now-unwitnessable "v1 terminal result is not made sticky"
  mutation — its anchor left with the cache — and gains the coded-condition
  mutation, two lifecycle-arm mutations, and three `parser-reset!` mutations, one
  per decision the procedure makes: 104 → 109 mutations, 37 passes unchanged. Lane
  count unchanged at 62.
- Milestone 2 Slice ②b-1: the EOF semantic core, through the reference interpreter
  only. `finish` joins `byte-dispatch`, `stop` and `error` as a source-IR node kind
  — `make-finish-node`, exported from `(byte-machine graph)` — giving EOF success
  the distinct terminal
  [decision 0011](docs/decisions/0011-eof-execution-model.md) called for. The
  verifier grows the parent §16.2 checks that only become load-bearing once EOF is
  executed rather than merely declared: a byte edge into a finish terminal is
  `non-eof-into-finish` (§16.2:908), an eof-target chain that reaches a `stop` is
  `eof-reachable-stop` (§16.2:909), and a chain that cycles without reaching a
  terminal is `eof-zero-progress-cycle`. Reachability now walks eof-targets as well
  as byte edges, so a node reachable only by EOF is no longer reported unreachable.

  `parser-finish!` runs the executor with input exhausted: from the current state an
  exhausted dispatch takes its eof-target — a named node, else the machine
  `default-eof-error` — and execution continues through zero-width nodes to
  `finished` or `error`, with `next` and `consumed` mirroring the stream offset and
  0, since a finish has no slice. That loop carries no cycle guard of its own, and
  deliberately so: termination is exactly what the two new verifier checks buy,
  which is what makes them worth having once Slice ②b-2's generated path stops
  re-verifying at run time. `finished` joins the lifecycle field. A shared
  idle-vs-truncation fixture (`(byte-machine test eof-machine)`, which accepts `1 2`
  and routes EOF at entry to a finish node but EOF after one byte to a truncation
  error) proves the distinction the whole slice exists for; it is written once here
  and reused by Slice ②b-2's differential. The generated finish path is still
  absent — `parser-finish!` on a `v1` parser raises rather than guessing at an ABI
  Slice ②b-2 had not yet defined. Two new lanes, `unit.eof-interpret` in source and
  AOT, take the count 62 → 64; the Scheme mutation suite goes 109 → 116 with 37
  passes.
- Milestone 2 Slice ②b-2: EOF generation. The emitter now emits the `/v2`
  generated-runtime ABI, `byte-machine-make-compiled-machine/v2`, and
  `current-abi-version` bumps to `2`. The generated machine exposes one unified
  `exec` closure carrying a `finish?` flag — `(state offset bv start end
  finish?)` — so a single closure serves both `parser-feed!` (`finish?` `#f`)
  and `parser-finish!` (`finish?` `#t`) rather than two closures. Only the
  exhausted-dispatch arm branches on the flag: feed still returns `need-input`,
  while finish takes the dispatch state's resolved eof-target — continuing the
  eof-target chain to a named node's loop, or routing to the machine default-eof
  error. Terminal state arms are one-per-kind and distinct: `stop` emits
  `stopped`, the new `finish` arm emits `finished`, and `error` emits `error`,
  removing the ABI under-specification the M1 "shared stop arm relabeled on the
  finish path" model carried. `/v1` is kept only as a runtime *export* — a
  version-mismatch stub — so a stale generated file embedding abi 1 fails the
  version check cleanly with an `assertion-violation` rather than an
  unbound-identifier error; "retire `/v1`" means from emitter output only. The
  normalizer encodes each dispatch state's eof routing into the canonical bytes,
  so the one-byte IR fingerprint re-baselines once, from `11963406767470843108`
  to `4236938459847922092`, at every site that pins it — the IR-fingerprint and
  emitted-bytes goldens, the normalizer and emitter specs, and the mutation-suite
  fingerprint anchors — and the generated library is byte-identically
  regenerated from the verified machine on every run. The reserved-output-binding
  mirrors track their surface: `reserved-member-2` gains
  `byte-machine-make-compiled-machine/v2` (keeping `/v1`), and
  `reserved-member-3`'s generated-local set renames `feed` to `exec` and gains
  `finish?`. The interpreter≡generated differential is extended to
  feed-then-finish across all 256 first bytes, distinguishing idle completion
  (`finished`) from truncation (`error`).
  [Decision 0010](docs/decisions/0010-direct-executor-abi.md) item 4 governs the
  `/v2`-constructor-over-arity-break seam.
- Milestone 2 Slice ③: the explicit pause node, `parser-resume!`, and the
  full reachable operation matrix, closing Milestone 2. A new source-IR node
  kind, `make-pause-node` — the fifth normalized state kind after
  dispatch/stop/error/finish — carries a name and one zero-width
  continuation edge, with no advance/reexecute mode (pause reads no byte).
  `parser-resume!` changes only lifecycle and consumes no input:
  `paused-feed` acks to `ready` (`'feed-ready`), `paused-finish` acks to
  `finish-ready` (`'finish-ready`); the next feed/finish re-enters the saved
  continuation directly, with no separate continuation object — both
  executors park `current` on the continuation before returning `paused`
  (interpreter: `parser-set-current!` to `(op 'pause-target node)`;
  generated: `next-state` = the continuation's state id). A feed-path pause
  returns `next` = the first unconsumed index and `consumed = next - start`;
  a finish-path pause has no slice, so it mirrors the `finished` convention
  (`next` = the stream offset, `consumed = 0`).

  The runtime now gates every operation on lifecycle at entry and enforces
  the full **reachable** §12.2 matrix — `ready` / `paused-feed` /
  `paused-finish` / `finish-ready` / `stopped` / `error` / `finished` ×
  `feed!` / `finish!` / `resume!` / `reset!` (`poisoned`/`busy` are
  unreachable without callbacks and ride to Milestone 5). Every prohibited
  cell raises `&byte-machine-contract` with the single code
  `'lifecycle-violation`: `who` is the refused operation (`parser-feed!` /
  `parser-finish!` / `parser-resume!`), `detail` is `(list <state> <op>)`.
  See [decision 0013](docs/decisions/0013-runtime-coded-conditions.md)'s
  2026-08-29 note.

  The verifier's reachability and zero-progress passes learn a pause arm: a
  malformed or missing continuation is `missing-target` (§16.2:905); a
  byte-reachable pause into a `finish` node is `non-eof-into-finish`
  (§16.2:908); an EOF chain — through pauses, including from a
  byte-reachable pause's continuation — into a `stop` node is
  `eof-reachable-stop` (§16.2:909); an EOF chain of pauses that never
  reaches a terminal is `eof-zero-progress-cycle`; a pause folded into a
  reexecute-only cycle makes no progress and is `zero-progress-cycle`. No
  new diagnostic codes were needed.

  The normalizer lowers `pause` to canonical encode tag byte 4, with the
  continuation riding the routing slot as `(node . <id>)`; the emitter's
  pause arm emits `(byte-machine-make-feed-outcome/v1 'paused pos #f
  <continuation-id> off)`. Pause is purely additive to the encoding — the
  one-byte and node-routing goldens (`4236938459847922092`,
  `9098559711816935340`) are unmoved — and a machine containing a pause
  node gets its own golden, measured at `15725897457025557005`
  (`test/fixtures/generated-pause.golden.sls`, `normal-ir-tests.sps`). The
  §22.6 property generator now draws `pausep` and an eof target for a
  subset of generated machines, and the differential driver resumes both
  parsers through a feed-pause/finish-pause schedule.

  Three new lane pairs (source + AOT): `byte-machine.unit.pause-interpret`,
  `byte-machine.differential.pause`, `byte-machine.determinism.pause`.
  Measured on the shipped tree: `release`/`pr` 72/72, `no-scheme` 8/8, the
  Scheme mutation suite 38 passes/165 mutations (156 caught, 9 declared
  `EXPECT_SURVIVES`), the CMake mutation suite unchanged at 1 pass/72
  mutations. (Corrected 2026-08-29: this line first read 164 mutations and 155
  caught, which never matched the merged tree — `SchemeMutationSuite.cmake`
  declares `EXPECTED_MUTATIONS 165`. Re-run against the merged tree, the suite
  reports "38 passes, 165 mutations" with 9 `SURVIVES (expected)` lines; the
  other four figures were re-run and confirmed unchanged.) The two extra
  mutations past this slice's own close-out close a gap Task 7's review found
  in exit criterion 4: `error`/`finished` ×
  `resume!` and `finished` × `finish!` had no direct test (see
  [milestone-2-design.md](docs/plans/milestone-2-design.md) §6's dated
  disposition). Three further mutations past that close the final
  whole-branch review's (pre-merge) own findings: two Critical gaps where the
  feed-path and finish-path pause arms collapsed
  `next`/`consumed`/`stream-offset` to indistinguishable values on every
  zero-start fixture, and one Minor gap in `finish-ready`'s own membership in
  `parser-feed!`'s prohibited lifecycle rows.

- Byte classes (Milestone 3 Slice ①): `make-byte-set-matcher`,
  `make-byte-range-matcher`, `make-byte-complement-matcher` and `ascii-bytes` on
  the public construction façade, canonicalized to subsets of `0..255` by one
  shared spine and lowered to one normalized transition per byte
  ([decision 0014](docs/decisions/0014-byte-classes-expand-per-byte.md)).
  Degenerate shapes — an empty byte set, a range with `low > high` — are
  constructor contract violations
  ([decision 0017](docs/decisions/0017-degenerate-shapes-are-contract-violations.md));
  duplicate bytes and a vacuous complement are not. `pass-overlap` now reports
  one diagnostic per colliding pair of cases across mixed matcher kinds. The
  normalized encoding, its format version byte, the emitter and the runtime are
  unchanged: all three pinned IR fingerprints and both committed goldens are
  byte-identical. Measured on the shipped tree: `release`/`pr` 76/76,
  `no-scheme` 8/8, the Scheme mutation suite 41 passes/186 mutations (177
  caught, 9 declared `EXPECT_SURVIVES`, all pre-existing and none from this
  slice), the CMake mutation suite unchanged at 1 pass/72 mutations.

- Sequence dispatch (Milestone 3 Slice ②): `make-sequence-dispatch-node` and
  `make-sequence-case` on the public construction façade — the sixth node
  kind in the parent plan's closed repertoire (§10.6) — threaded through six
  of `verify.sls`'s eight node-kind-dispatching sites: target resolution,
  reachability, the zero-progress cycle WALK, and both EOF-chain checks (the
  true site count, and the six/eight split, is design §6's own dated
  disposition, corrected there after two earlier miscounts). The other two
  sites are deliberately deferred to Slice ③: `pass-overlap`'s
  cross-alternative collision check, and the zero-progress cycle REPORT,
  which still filters on `byte-dispatch-node?`/`pause-node?` alone — so the
  walk sees a self-targeting sequence-node mismatch edge but nothing reports
  it. Measured consequence: such a machine verifies with zero diagnostics
  today, and feeding it one byte that does not match its alternative does not
  return, in either executor (dated comment at `verify.sls`'s zero-progress
  pass). A sequence node lowers to ordinary normalized
  `dispatch` states through a trie that merges alternatives sharing a byte
  prefix, so two alternatives sharing a first byte (`AB`/`AC`) no longer
  silently collide on the ascending-byte sort key; internal prefix states get
  ids appended after the declared block, depth-first pre-order, ascending by
  child byte ([decision 0016](docs/decisions/0016-normalized-state-id-allocation.md)).
  The reference interpreter tracks prefix progress independently, as a
  compound `current` carrying the consumed byte path rather than a bare
  position index — measured necessary: a position index cannot distinguish
  which alternatives are still live from how far along it is, so it accepts
  byte sequences never on the input when two alternatives diverge at position
  0 (`AB`/`XY`; see the dated amendment at design §4.2)
  ([decision 0015](docs/decisions/0015-sequence-prefix-states.md)). The
  emitter and `runtime.sls` are unchanged, confirmed and recorded at the
  change site (`compile.sls`'s `render-state-arm`). Both mismatch modes
  (`reexecute` and `advance`) are covered; the interpreter≡generated
  differential reproduces Milestone 2's `sequence-machine.sls` chained-dispatch
  oracle exactly, over all eight cut-sets, nonzero offsets, empty slices and a
  seeded multi-split schedule. Exit criterion §25:1538: mismatch positions in
  this lane are asserted through `status`/`next`/`consumed`/`stream-offset`/
  `code` only — the structured `parser-error-*` record (`parser-error-node-name`,
  `-state-id`, `-position-kind`) is deferred to M4/M5 per
  milestone-2-design.md §7, which forbids populating one field of an
  otherwise-deferred family; recorded per §8 rather than glossed. Measured on
  the shipped tree: `release`/`pr` 80/80, `no-scheme` 8/8, the Scheme
  mutation suite 43 passes/223 mutations (214 caught, 9 declared
  `EXPECT_SURVIVES`, all pre-existing and none from this slice, confirmed by
  a cross-commit diff against `main` rather than `git status`), the CMake
  mutation suite unchanged at 1 pass/72 mutations.

- Multiple alternatives, ambiguity and cycle analysis (Milestone 3 Slice ③) —
  **the slice that closes Milestone 3**. `verify-machine` gains
  `pass-sequence-ambiguity`, the parent plan's §16.2:894 check, with one new
  diagnostic code `'ambiguous-sequence-prefix` and one diagnostic per colliding
  pair: one alternative being a terminal prefix of another is now rejected at
  verification rather than only asserted inside the normalizer and the
  interpreter, and duplicate alternatives report the same code as the maximal
  case of the same relation. The check is a source-level pairwise test over the
  node's own byte lists, so it never inspects the lowered graph and §17:951's
  verify-before-normalize ordering is preserved; it was measured equivalent to
  the normalizer's three trie guards over all 469 nonempty alternative-sets of
  size ≤ 3 drawn from the 14 binary strings of length 1–3, with zero
  disagreements. `pass-overlap` is **not** extended to sequence nodes, now or
  later: §16.2:893 and :894 are two entries, two checks and two codes
  ([decision 0017](docs/decisions/0017-degenerate-shapes-are-contract-violations.md)
  point 4), and the guards for the same two invariants are kept as
  defense-in-depth in both files — **three** assertion sites in
  `normal-ir.sls`'s `trie-insert`, because the ambiguity invariant is checked in
  both directions there, and **two** in `interpret.sls`'s `seq-step` — for a
  caller who reaches `normalize-machine` without verifying, or who forges a
  verification result. (Per invariant: ambiguity holds two of the normalizer's
  three sites and one of the interpreter's two; duplicate-alternative holds one
  of each.) Scope bullet §25:1532.
  Together with the REPORT-guard extension below, this closes both of the two
  verifier sites the Milestone 3 Slice ② entry above records as deferred to this
  slice — one by extending it, the other by establishing that it is never
  extended; that entry's "deliberately deferred to Slice ③" and its "verifies
  with zero diagnostics today" are the record of the tree as it stood at Slice
  ②'s close, and stand as written.
- `pass-zero-progress`'s REPORT set gains the sixth node kind, so a sequence
  node whose `reexecute` mismatch edge reaches itself is reported as a
  `zero-progress-cycle` instead of verifying clean and hanging both executors
  (the hang was measured on `main` before the change: `exit=124` under a
  timeout, in the interpreted and the generated lane alike). The walk already
  saw through such a node — that shipped in Slice ②. An `advance` mismatch edge
  consumes the offending byte, so the same self-target stays accepted: both
  halves of exit criterion §25:1540, one case each. Scope bullet §25:1533 is
  discharged **in halves** — this is its zero-progress half; its EOF-cycle half
  shipped in Slice ②, in `eof-terminal`'s sequence arm and `pass-eof-execution`'s
  two filters, and a sequence node with a self-cycling `eof-target` already
  reported `eof-zero-progress-cycle` before this slice began. The extension
  inherits the incumbent's deliberate over-approximation — `reaches-self?` is a
  pure edge walk and never asks whether the arm closing the cycle is reachable
  for any byte — which a byte-dispatch node whose single case is
  `(make-byte-range-matcher 0 255)` already exhibited on `main`; recorded at the
  site rather than silently widened.
- The `HTTP/1.0` ⁄ `HTTP/1.1` fixture from the parent plan's §21.2:1065 grammar
  (`version = "HTTP/1.0" / "HTTP/1.1"`), two alternatives over the seven-byte
  shared prefix `HTTP/1.`, in both mismatch modes: an absolute interpreter lane
  pair, an interpreter≡generated differential lane pair, and a structural group
  in the already-registered normalizer program — six new lanes in all, three
  source+AOT pairs, counting the determinism pair below.
  **What is new here is stated narrowly.** Slice ② already
  drove the trie merge — `normal-ir-tests.sps` pins structurally that a shared
  first byte becomes one transition into one state, and `interpret-tests.sps`
  executes `AB`/`AC` through the interpreter — so this slice adds the
  **differential** over a branch, plus depth, absolute tuples and both mismatch
  modes. Measured, not assumed, about what that differential is for: a lowering
  that **loses** an alternative is caught here and not by the single-alternative
  differential, where a one-arm state and a truncated one-arm state are the same
  state; a defect that **resumed** into the wrong prefix state across a feed
  boundary reddens the single-alternative differential too, so that is not this
  lane's alone. Multi-alternative half of scope bullet §25:1529; exit criterion
  §25:1538 extended from Slice ②'s linear chain to a branching trie.
- §22.9 determinism pins over a branching sequence machine, and a third
  committed golden, `test/fixtures/generated-http-version.golden.sls` (3849
  bytes, generated by the shipped emitter, never hand-written; IR fingerprint
  `12299125921751534854`, 11 normalized states). Neither the one-byte nor the
  pause golden contains a branch, and a branch is the only shape that can
  witness an unstable child order at the branching prefix state. The order in
  question is `trie-put`'s own ascending alist insertion, **not** the
  `list-sort` that orders a byte-dispatch node's transitions: measured with a
  control — flipping `list-sort`'s comparator re-emits this machine
  byte-identically while it does reorder a two-case byte-dispatch node's arms,
  so the flip is a real mutation and the byte-identity is not an artifact. Exit
  criterion §25:1539.

  **Three limitations are recorded rather than glossed, and the count carries
  its qualifier: three, among the limitations Milestone 3 closes over.**
  (i) Mismatch positions in this slice's lanes are asserted through
  `status`/`next`/`consumed`/`stream-offset`/`code` only — the structured
  `parser-error-*` record (`parser-error-node-name`, `-state-id`,
  `-position-kind`) is deferred to M4/M5 by milestone-2-design.md §7, which
  forbids populating one field of an otherwise-deferred family; the same
  limitation Slice ② recorded against §25:1538, unchanged by the branching
  fixtures. (ii) §22.9's bullet at :1314 — generate in every Tier 1 cell and
  compare output byte for byte across operating systems and architectures — is
  **not built**: `.github/workflows/ci.yml` has no `upload-artifact` step and no
  cross-cell comparison job. "Deterministic" here therefore means byte-identical
  within one process, identical across the source and AOT lanes, and equal to a
  committed golden; cross-process (:1312) and cross-cell (:1314) identity follow
  **transitively** from every lane comparing against the same committed bytes,
  not from a direct measurement. (iii) No lane compiles and executes a machine
  whose only case is a vacuous complement,
  `(make-byte-complement-matcher (make-byte-range-matcher 0 255))` — that
  construct is exercised by the normalizer (`normal-ir-tests.sps`, "a vacuous
  complement lowers to zero transitions (decision 0017 point 2)") and the
  verifier (`verify-tests.sps`, "a vacuous complement collides with nothing")
  but never compiled and run.
  It belongs to scope bullet §25:1527 and exit criterion §25:1537 — **Slice ①'s**
  scope, not this slice's — and so closes with the milestone. Provenance: the
  Milestone 3 session ledger carried it out of Slice ① into Slice ②'s close-out
  and thence into this slice's implementation plan as §0 D10b, which confirmed
  it still open and assigned this record.

  Nothing in the normalizer, the emitter, `runtime.sls` or the `/v2` ABI
  changed; `private/normal-ir.sls`'s only edit on this branch is a comment. The
  three pinned IR fingerprints (`4236938459847922092`, `9098559711816935340`,
  `15725897457025557005`) and both pre-existing committed goldens are
  byte-identical. Measured on the shipped tree: `release`/`pr` 86/86,
  `no-scheme` 8/8, the Scheme mutation suite 46 passes/235 mutations (226
  caught, zero uncaught, 9 declared `EXPECT_SURVIVES`, all pre-existing and none
  added, removed or edited on this branch), the CMake mutation suite unchanged
  at 1 pass/72 mutations.

  **Amended 2026-08-30 (whole-branch review fix wave).** The paragraph above is
  the measurement taken at the slice's close and stands as written. The review's
  fix wave then added one mutation to Pass 33 — `"verify: the sequence mismatch
  edge's MODE is not tested (arm 3, reexec-targets)"`, for the `reexecute` test
  in `reexec-targets`' sequence arm, which had no mutation — and one attribution
  check to `verify-tests.sps` that its pin needed. The suite ships at **46
  passes / 236 mutations**, 227 caught; every other number above is unchanged
  and was re-measured, including the three fingerprints, both goldens and the
  nine `EXPECT_SURVIVES`.

### Changed

- Decision records now say **at the top** when a later decision reached back
  into them, and **at the site** on the item a later note makes false. Five
  records carried dated amendment notes with nothing above the fold pointing at
  them (0001, 0004, 0010, 0012, 0013); 0010 had accumulated four such notes, and
  its item 4 read "extends by a `/v2` constructor" forty-seven lines above the
  note recording that
  [decision 0018](docs/decisions/0018-unversioned-generated-abi-constructor.md)
  had replaced that mechanism. Nothing above a note was rewritten — the pointers
  are additions, and the convention and its boundary (a pointer routes; it never
  restates) are stated in
  [docs/decisions/README.md](docs/decisions/README.md), whose previous wording
  covered supersession only. The one-bullet-per-note invariant ships with the
  command that checks it.
- [Decision 0010](docs/decisions/0010-direct-executor-abi.md)'s 2026-08-23
  Slice-B note gains a dated annotation: its "item 5's `/v2` remains gated on
  benchmark evidence" names the wrong item. Item 5 is the deferral of a coded
  ABI-mismatch condition and mentions no `/v2` and no benchmark gate; the
  reservation is the third Consequences bullet's. Every other citation of that
  note — 0012 twice, 0018, 0010's own Milestone 4 note, and Milestone 4's design
  and Gate 0 plan — pairs it with the Consequences bullet, so what stays gated
  was never in doubt, only which item the sentence named. Annotated rather than
  corrected because it was wrong when written rather than made wrong by a later
  decision, and because those citations reach it. Re-measured against the merged
  Milestone 4 Gate 0: 16 citation sites in 8 files, all pairing the reservation
  with the Consequences bullet.
- Chez discovery now probes each candidate name in turn instead of committing to
  the first one `find_program` returns. A host with an unrelated `scheme` earlier
  on PATH than its Chez previously failed to configure.
- Version floors are checked for presence before use. `if(x VERSION_LESS "")` is
  false in CMake, so an absent floor accepted every release silently.
- The Chez version is read from after the banner's `Version` keyword rather than
  from the first dotted number anywhere in it.
- Gambit's interpreter is interrogated before its compiler is derived, so a
  Ghostscript `gsi` reports that it is not Gambit instead of complaining about a
  derived path that was never the problem.
- An explicitly set `BYTE_MACHINE_GAMBIT_COMPILER` now survives the interpreter
  changing in the same configure. Provenance is decided by comparing the cached
  value against the recorded derivation, not by interpreter identity.
- Test presets declare a configuration and refuse an empty selection, so the
  documented preset entry point behaves like `make` — on Windows' default
  multi-config generator every test previously reported "Not Run".
- Specifications print their success banner only when nothing failed.
- `MutationRunner` is now generalized on three axes rather than two: it takes
  the staged trees and the verify command as parameters, so a mutation can be
  judged by running a real execution lane rather than only by `cmake -P`;
  gained a reset entry point so a second declaration pass can run under a
  different verify command in the same script — needed because the Scheme
  suite's passes each judge a different decision through a different lane:
  the shared runner against the self-tests, each adapter's export list on its
  own runtime, and two further runner decisions reachable only through the
  empty-selection and bootstrap lanes; and gained a verify working directory,
  separate from the staged tree, because the working-directory matrix's
  single mutation is judged by launching from three different directories,
  not by what it does to the stage. The CMake-layer suite keeps its previous
  behaviour by default on all three axes.
- `byte_machine_mutation` gained optional `EXPECT_STATUS` and
  `EXPECT_OUTPUT_MATCHES`, narrowing "caught" to "caught for the declared
  reason": a nonzero verify-command result whose exit status or combined
  stdout+stderr does not also satisfy the declared expectation is reported
  separately, as caught for the wrong reason, and counted the same as an
  outright miss rather than as a pass. Applied only where measured, not
  guessed — a REPLACE that once opened a line comment and swallowed a list's
  closing parens had reported caught at exit 255 on a read error rather than
  on the refusal it named.
- `byte_machine_mutation_run` now accumulates a running pass and mutation
  count across every call in a process (`byte_machine_mutation_totals`), and
  both mutation suites compare that total against a count declared next to
  their own header comment, failing loudly on a mismatch. A whole-branch
  review had deleted an entire pass group from the Scheme suite and left it
  reporting 37/37 regardless, with the mutation count silently dropping
  underneath that number and nothing noticing; this is what would have
  caught it.
- `ByteMachineExpectExit`'s comments and specification illustrated the
  out-of-vocabulary case with Gambit's own missing-file exit number (70); no
  lane ever declared 70 as an expected exit, and the declared vocabulary was
  and remains 0/1/2/3. Re-measured with Gambit gone: Chez 10.4.1 exits 255 for
  a `--script` naming a file that does not exist, and the illustration now
  uses that measured value.
- Every library is an ordinary inline R6RS `.sls` and every test program a
  plain `.sps`; no Scheme file includes another. The fingerprint algorithm is
  its own library, `(byte-machine test fingerprint)`, imported by the harness
  and by the build-time expectation alike. A lane's manifest (`SOURCES`,
  formerly `SHARED_BODIES`) is its program plus every library it loads, so
  every byte of Scheme a lane runs is fingerprinted — wrapper text never was,
  before. See [decision 0006](docs/decisions/0006-inline-libraries.md).
- Milestone 0 (portability and harness spike) closes. Its three undelivered
  deliverables — a determinism proof, an identifier/LF proof, and a CI
  pipeline — are properties of an emitter this milestone was never scoped
  to build; they move to Milestone 1, landing on Scope lines that already
  named them rather than becoming new obligations there. See
  [decision 0007](docs/decisions/0007-milestone-0-closes-at-the-harness.md).
- Both governing plans are swept by grep over their whole text and then read:
  the milestone-0-portability-spike plan end to end, all thirteen sections; the
  parent implementation plan at §25 in full, plus §§7.1, 7.3, 9.2, 9.6, 10.1,
  20, 22.9, 24.2, 29, and 30 — the sections the citation audit reached. What
  either pass found is corrected: sentences the Chez-only cut, the
  inline-library collapse, and this close left stale — retired two-runtime and
  shared-body vocabulary, exit criteria and Deliver-list entries superseded by
  what actually shipped, and each plan's own status line. Every site is
  corrected in place or given a dated note depending on whether it names a
  record, an instruction, or a claim that was never true — none is rewritten to
  agree with the outcome after the fact. Both governing plans now record
  Milestone 0 as closed.
- The milestone plan's Tier 1 cell arithmetic is corrected: under Chez-only
  there are four Tier 1 platform cells, not eight, and two of them are
  deferred, not four. The old count dated from when the matrix still
  multiplied four platforms by two runtimes.
- The `determinism` mutation-suite layer comment now says byte-identical
  emission is claimed "across runs, lanes, and platform cells" rather than
  "across runs and runtimes" — there is no longer a second runtime for that
  claim to be about, and the entry stays because Milestone 1's determinism
  lanes will use it.
- The comment above the `cmake-mutation` lane, which claimed the lane "runs
  in CI", now says it runs under `ctest`. No CI has existed in any commit of
  this repository, and the old wording sat a few lines from the exact lane
  [decision 0001](docs/decisions/0001-toolchain-discovery.md) cites as
  evidence of one.
- [Decision 0001](docs/decisions/0001-toolchain-discovery.md) gains a dated
  annotation on its claim that a lane "runs in CI": that sentence was never
  true, and it is annotated rather than silently corrected because the
  record cites it as evidence for its own Consequences.
- The harness adapter derives OS and architecture through pure
  `machine-type->…` functions, tested exhaustively over the Tier-1 machine
  types, and the self-test/bootstrap lanes assert the live values by equality
  when the cell's identity is supplied, replacing the earlier not-"unknown"
  checks.
- The confirmed Milestone 1 Phase 3 Slice A Minors land in their owning
  files, TDD where behavior changes: `private/normal-ir.sls`'s node-kind
  dispatch gains an `else` guard that raises on an unreachable fourth kind,
  plus a comment documenting why the repertoire is exactly three kinds until
  EOF execution lands in M2; `normal-state-id` is now asserted directly
  rather than only exercised indirectly; `normalize-machine`'s combined
  lowering-and-encoding splits into two focused functions, with the golden
  IR fingerprint `11963406767470843108` pinned unchanged across the split to
  prove it is behavior-preserving; `runtime.sls`'s `make-parser` v1 branch
  reads the compiled-machine through named accessors instead of positional
  `(vector-ref cm 2/3)`; the Scheme mutation suite's Pass 36 assertion
  tightens from the loose `EXPECT_OUTPUT_MATCHES "ok"` to `"not ok"`; and
  the one-byte fixture duplicated across the differential and example test
  programs collapses into one shared fixture. Two Slice A minors are
  deferred with a note instead of changed: `id-of`'s linear `assq` scan per
  call (parent §23 forbids optimizing without a reproducible compiled
  benchmark showing material improvement, and Slice B builds no benchmark
  harness) and named accessors for `emission-metadata` (no consumer exists
  yet beyond the tests that construct it).
- Sticky lifecycle rows (`stopped`/`error`/`finished`) now short-circuit at
  the operation entry and synthesize the §12.2 result tuple directly,
  instead of re-executing the interpreter/generated loop from a parked
  terminal `current` and relying on that re-execution being idempotent (the
  mechanism Slice ②a shipped). The parser gains a stored-error slot
  (`runtime.sls` slot 7, `parser-stored-error`) so the error row has a value
  to return without re-running anything. This changes no asserted result
  tuple for the cases Slice ②a's mechanism already got right — but it fixes
  one Slice ②a left broken and unwitnessed: a repeat feed after a
  **default-EOF truncation** left `current` parked on the exhausted dispatch
  node rather than past it, so `parser-finish-op!`'s default arm made the
  next feed re-run dispatch and **consume bytes** instead of returning the
  sticky error tuple. That is an observable behavior change, now covered by
  `runtime-tests.sps`'s "the error row returns the stored error after a
  default-EOF truncation" case. See
  [milestone-2-design.md](docs/plans/milestone-2-design.md) §5's 2026-08-29
  note (D1).

### Removed

- Gambit and R7RS leave the project contract: byte-machine now targets Chez
  Scheme and R6RS only. The one consumer that required a second runtime,
  protium, is being replaced by a Chez-only libuv library, so nothing
  remaining needs Gambit. See
  [decision 0005](docs/decisions/0005-chez-only.md) and
  [the removal plan](docs/plans/chez-only-simplification.md). Milestone 0
  slice 5c, which existed only to add Gambit's two compiled modes, is
  cancelled; deliverable D5 closes at two lanes, `chez.source` and
  `chez.aot`.
- The portability guard's pairing rule — every wrapped body twinned `.scm` /
  `.gambit.scm` — goes with nothing left to pair. Its basename-uniqueness
  rule stays in force: the Chez `include`/`source-directories` mechanism
  still needs it, until the follow-up slice below retires that mechanism
  too.
- All 11 Gambit execution lanes and their test halves: the `.gambit.scm`
  drivers, the `.sld` harness adapter and its wrappers, `src/gambit/`, and
  `test/gambit/`. The Scheme mutation suite's with/without-Gambit counting
  delta collapses into a single declared set.
- The Gambit toolchain layer: the discovery module, the probe script, their
  specification and spec lane, and every build-frontend reference to
  Gambit — the `BYTE_MACHINE_REQUIRE_GAMBIT` option, presets, `Makefile`
  text, and backend vocabulary.

  Net across the cut, measured on this branch: registered lanes drop from
  49 to 37; the CMake-layer mutation suite drops from 97 to 75, net of one
  mutation restored with a new registrar-path witness and one added over
  the unknown-mode message — a pre-existing gap closed during review, not
  Gambit fallout; the Scheme-layer mutation suite drops from 35 passes/83
  mutations to 29 passes/65 mutations; the `no-scheme` selection drops from
  10 to 9.

  What stays: [decision 0002](docs/decisions/0002-shared-body-include-mechanism.md)
  and [decision 0003](docs/decisions/0003-cross-library-identity.md) — the
  shared-body `include` mechanism and its one-owner rule — remain in force,
  unchanged by this cut. The follow-up slice named in
  [the removal plan](docs/plans/chez-only-simplification.md)'s §6 (since
  designed and landed — see the include-collapse entries above and below)
  collapses that indirection into inline R6RS libraries; until it lands, both
  decisions govern exactly as before.
- The shared-body include mechanism and everything that kept it honest: the
  launchers' `--source-dir`, the working-directory matrix and its asymmetric
  mutation, the repository-wide basename guard
  (`ByteMachinePortabilityGuard.cmake`, its specification, and its twelve
  mutations — replaced by a per-lane basename check in the registrar), and
  the one-owner rule with its import-vs-include mutation (replaced by an
  inline-duplication mutation the identity lane catches). Decisions 0002 and
  0003 are superseded by 0006. The harness stands at 7,724 lines against the
  8,327-line pre-collapse baseline (`src/`: 87 against 110), re-measured at
  the branch head after the final review's own prose fixes.
- Three bullets leave Milestone 0's Deliver list. "Shared hello-library body
  loaded through its owner wrapper" is retired along with the shared-body
  include mechanism itself — see
  [decision 0006](docs/decisions/0006-inline-libraries.md). "Deterministic
  text emission proof across the Chez source and AOT lanes" and "identifier
  repertoire and binary LF emission proof across available operating
  systems" are not dropped: both move to Milestone 1, landing on Scope
  lines that already named them ("deterministic output"; "symbolic name
  resolution" and "generated-name safety for every construct present"). See
  [decision 0007](docs/decisions/0007-milestone-0-closes-at-the-harness.md).
- The M0 placeholder libraries `src/byte-machine/placeholder.sls` and
  `src/byte-machine/placeholder-consumer.sls` (spike §11;
  milestone-1-design.md §6), along with their test programs
  (`test/common/placeholder-tests.sps`,
  `test/common/placeholder-identity-tests.sps`), their lane registrations —
  including the `placeholder-identity` AOT identity lane — and the ten
  mutations across three Scheme mutation-suite passes that staged them. They
  were stand-ins for a real cross-library-identity consumer before the
  emitter existed; the emitter and its §9.6 end-to-end example now exercise
  the real public library boundary, so the stand-ins are superseded rather
  than replaced. `release` drops from 63 to 60 lanes (`no-scheme` is
  unaffected at 8/8, these were Chez-only lanes) and the Scheme mutation
  suite from 40 passes/114 mutations to 37 passes/104 mutations.

### Fixed

- `MutationRunner.cmake` — the machinery every specification in this tree is
  trusted through, and staged like everything else — had neither a
  specification nor a mutation targeting it. A re-review found this let the
  "caught for the declared reason" narrowing above reproduce the exact defect
  class it was written to close, one layer down: the branch that turns a
  wrong-reason result into a failure could be deleted by hand and the real
  CMake-layer suite stayed 89/89, because nothing mutated the decision that
  branch depends on, or the branch itself. The verdict decision is now split
  out as a pure function, `byte_machine_mutation_verdict` — no
  `execute_process`, no filesystem — with its own specification,
  `MutationRunnerSpec.cmake`, registered so it also runs under
  `ctest --preset no-scheme`. Five mutations in `MutationSuite.cmake` break
  each of the pure function's decisions and the registration guard beside it,
  and the specification carries a sixth, self-contained check of its own: a
  real staged mutation, deliberately declared with an unsatisfiable
  `EXPECT_OUTPUT_MATCHES`, that reaches past the pure function into
  `byte_machine_mutation_run` itself to prove a wrong-reason verdict is acted
  on and not merely computed correctly and discarded — the one part of this
  fix that cannot be specified as a pure function, because it is what the
  imperative shell does with the answer, and the exact branch the original
  deletion targeted.
- `EXPECT_OUTPUT_MATCHES`'s presence was tested by truthiness rather than
  `STREQUAL ""`, unlike the `EXPECT_STATUS` check one line above it. A
  pattern CMake itself reads as false — `"0"`, `OFF`, `NOTFOUND`, anything
  ending `-NOTFOUND` — is still a regex someone declared, and would have been
  silently unenforced rather than checked.
- `byte_machine_mutation` now refuses `EXPECT_SURVIVES` declared together
  with `EXPECT_STATUS` or `EXPECT_OUTPUT_MATCHES`. A declared survivor is
  judged only by whether the verify command exited zero, so the other two
  would have been parsed, stored, and never consulted — silently inert
  rather than enforced.
- The `WORKING_DIRECTORY`-forwarding conditional in `ByteMachineExpectExit.cmake`
  and `ByteMachineSchemeLane.cmake` was mutated in only one direction —
  `if(arg_WORKING_DIRECTORY)` to `if(FALSE)` — which only the specifications'
  "present" assertions could catch. Their "absent" assertions, proof that the
  keyword does not reach the registrar when no caller gave one, are exactly
  what stops the `CMP0174`-driven conditional-forwarding fix from silently
  regressing to unconditional forwarding, and had no mutation exercising
  them. Both sites now also mutate to `if(TRUE)`.
- `SchemeMutationSuite.cmake`'s pass 8 (the poisoned-compiled-object
  mutation) now declares `EXPECT_OUTPUT_MATCHES "POISONED-FROM-OBJECT"`,
  enforcing what its own comment already claimed: the mutated run names the
  sentinel in its banner, its FAIL-CONTEXT line, and its summary. Its
  without-Gambit expected pass and mutation counts are now derived from the
  with-Gambit pair and a declared Gambit-only delta (2 passes / 7 mutations)
  instead of duplicated as a second pair of literals that a new non-gated
  pass could update only one half of. A comment naming a retired ctest lane
  is corrected to include its `.chez.source` suffix.
