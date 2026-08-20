# Milestone 0, the include collapse: every library owns its own text

Status: accepted; delivered 2026-08-18 (decision 0006; §6 of chez-only-simplification.md carries the delivery note and measured outcome)
Date: 2026-08-18
Parent plan: [`chez-only-simplification.md`](./chez-only-simplification.md) §6 — this is the design document that section requires; its scope bullets are contract here, not suggestions
Governing plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §7.2 and §8, whose transition notes this slice discharges
Decisions retired: [0002](../decisions/0002-shared-body-include-mechanism.md) and [0003](../decisions/0003-cross-library-identity.md) gain supersession headers from this slice's decision record; [0005](../decisions/0005-chez-only.md) is why they can

**Goal:** No Scheme file in this repository includes another. Each library is an
ordinary inline R6RS `.sls`, each test program an ordinary `.sps`, and the
`include`/`source-directories` mechanism — with everything that existed to keep
it honest — retires.

## 1. What this slice must prove

The Chez-only cut (decision 0005) removed the second runtime but deliberately
left the single-runtime indirection standing: shared `.scm` bodies included by
owner libraries, launchers carrying `--source-dir`, a working-directory matrix
proving includes resolve against the right tree, a repository-wide basename
guard, and a one-owner rule enforced by mutation. All of it served a sharing
mechanism whose second consumer no longer exists. This slice deletes the
mechanism and must prove three things about what remains:

1. **Nothing was lost that was load-bearing.** Every claim the include-era
   machinery enforced either becomes structural (unconstructible defect classes
   need no guard) or is re-established against the inline tree (defect classes
   that survive get a rewritten witness). The distinction is argued per
   mechanism in §9, not waved at.
2. **Provenance gets stronger, not weaker.** The fingerprint manifest re-scopes
   from shared bodies to the program plus every library it loads — text the
   include world never fingerprinted. The declared-manifest discipline and the
   AOT-provenance discipline of decision 0004 and slice 5b are kept intact.
3. **The vocabulary goes with the concept.** The acceptance gate fixed in
   chez-only-simplification.md §6 — the semantic sweep plus a reading pass —
   is this slice's exit condition, because the Chez-only cut demonstrated that
   a grep for a departed name clears files in which the departed *idea* still
   lives.

## 2. Scope decisions taken at design time

Three decisions were made during this design's review and bind the
implementation plan:

1. **Collapse first; the 5b remainder follows.** Slice 5b is partially landed:
   the mode plumbing, the declared/measured split, and the launchers exist, but
   `byte_machine_lane_chez_aot`, the three `chez.aot` registrations, the
   staleness lane, and mutations C1–C4 do not. Sequencing the collapse first
   means the 5b remainder never builds the shared-body copy staging this slice
   would immediately rework. The cost is stated in §8.3: this slice's edits to
   the aot branch of the lane command ride unwitnessed by any registered lane
   until the 5b remainder lands.
2. **Program pairs merge, and the `.chez` infix goes.** The eight
   `.chez.sps`/`.scm` pairs under `test/support/harness/self/` and
   `test/common/` each become one plain `.sps` program. The infix
   disambiguated against twins that no longer exist; keeping it would leave
   filenames asserting a per-runtime split the vocabulary sweep exists to
   retire.
3. **The fingerprint body becomes a real library; everything else inlines into
   its owner.** `fingerprint.scm` is the one body with two consumers — the
   harness library includes it and `fingerprint-manifest.ss` `load`s it
   verbatim so the build-time expectation and the runner cannot drift. Inlining
   it into the harness would force the manifest launcher to expand the whole
   runner to reach three procedures. Instead it becomes
   `(byte-machine test fingerprint)`, imported by both consumers: the no-drift
   guarantee moves from a `load` of a file into the module system doing its
   job. The full-dissolution alternative (splitting the runner into several
   libraries, dissolving the adapter protocol) was rejected: it churns every
   program and mutation pass for structure nothing yet consumes, and
   Milestone 1 reshapes this ground anyway.

## 3. Facts this design rests on

Structural facts, read from the tree on 2026-08-18 at `main` (76f3238), with
line counts measured the same day. Behavioral claims below cite where they were
measured; nothing here presents a new measurement, and every number the
implementation records (the CHANGELOG's final deltas above all) is re-taken at
that point per the AGENTS.md rule.

- **Baseline sizes.** Harness (`cmake/` + `test/support/`): 8,327 lines.
  Product (`src/`): 110 lines. The §6 estimate is that this slice moves the
  harness toward roughly 4,000–4,500; that number is a target to re-measure,
  not a promise.
- **The file reader exists three times.** `adapter-file-bytes` is defined in
  the harness adapter and again in `fingerprint-manifest.ss`, and
  `fingerprint.scm`'s `harness-fingerprint-file` names it as a free identifier
  a third consumer must bind. All three exist because a shared body could not
  carry its own I/O under the retired dialect ceiling. `(rnrs io ports)`
  provides everything the reader does.
- **Wrapper text is unfingerprinted today.** A lane's `SHARED_BODIES` names
  bodies only; the twelve-line `.sps` wrappers never appear in any manifest.
  Under the merge, the test text lives in the program file, so the manifest
  must grow to cover it or provenance would silently narrow (§6 of this
  document, claim 2 of §1).
- **The guard's live subject is already gone.** Task 2 of the Chez-only plan
  kept `ByteMachinePortabilityGuard.cmake` (204 lines) alive solely for
  shared-body basename uniqueness, which the flat `source-directories`
  namespace requires; its wrapper-filter regex is already witnessed only by
  the spec's invented paths (chez-only-simplification.md §6 records this as a
  carry note). The module, its 257-line spec, its spec lane, and its 12
  declarations in `MutationSuite.cmake` all have exactly one remaining reason
  to exist, and this slice deletes that reason.
- **`(source-directories '())` is measured-inert where nothing includes.**
  Slice 5b's C3b measurement (5b/5c design §5.3, 2026-08-17): library
  resolution runs through `library-directories`, and a library's own `include`
  forms resolve relative to the library file rather than through
  `source-directories`. After this slice no `include` forms exist at all,
  which extends the same conclusion to the source launcher (§7).
- **The 5b remainder is pending.** No `chez.aot` lane is registered; the aot
  branch of `byte_machine_scheme_lane_command` and the measured-copies helper
  are live code with no registered caller. (Three `chez.aot`-named
  exit-code tests exercise launcher refusals, not the lane command.)

## 4. End-state layout

```
src/byte-machine/placeholder.sls                       library + body, inline
src/byte-machine/placeholder-consumer.sls              imports the owner
test/support/harness/byte-machine/test/fingerprint.sls new; self-contained
test/support/harness/byte-machine/test/harness.sls     adapter + runner, inline
test/support/harness/self/*.sps                        six merged programs
test/common/*.sps                                      two merged programs
test/support/launchers/chez-source.ss                  --source-dir gone
test/support/launchers/chez-compile.ss                 --source-dir gone
test/support/launchers/chez-aot.ss                     unchanged
test/support/launchers/fingerprint-manifest.ss         imports, never loads
```

Library roots become `src/` and `test/support/harness/` — the per-runtime
`chez/` segments die with the distinction they carried. Deleted outright:
`src/common/`, `src/chez/`, `test/support/harness/shared/`, the
`test/support/harness/chez/` root (its contents move up), all eight `.scm`
program bodies, `cmake/ByteMachinePortabilityGuard.cmake`, its spec, and the
cwd-matrix fixtures and wiring. This discharges the governing plan §8's
transition note, whose target layout this is.

## 5. The libraries

### 5.1 `(byte-machine test fingerprint)`

The algorithm exactly as `fingerprint.scm` carries it — constants, bytevector
fold, file fingerprint, order-sensitive combine, explicit-digit hex — plus a
private file reader: binary port, `get-bytevector-all`, EOF-object mapped to
the empty bytevector, the same three decisions the adapter's reader documents
(bytes not characters, LF is LF, empty file fingerprints as the seed). The
body's "SHARED BODY CONTRACT" header dies with the contract; the header
comment that `harness-fingerprint-file` cannot be separated from whatever
defines `adapter-file-bytes` dissolves, because the library now defines what
it depends on. What survives verbatim is the reasoning that must: the
change-detector-not-crypto warning, the exact-bignum rationale, the
explicit-digit-table measurement, and the declared-not-observed limit — the
last reworded, since "which files an `include` spliced in" becomes "which
files the run actually loaded," a gap that library resolution does not close.

Exports: `harness-fingerprint-bytevector`, `harness-fingerprint-file`,
`harness-fingerprint-combine`, `harness-fingerprint->string`.

### 5.2 `(byte-machine test harness)`

The adapter section stays as the file's first act, unchanged in surface:
`adapter-file-bytes` keeps its name and its definition because the self-tests
read the sample fixture through it, and renaming a protocol member is churn
this slice does not need. The runner body follows inline, where its `include`
sat. The library imports `(byte-machine test fingerprint)` and **re-exports
its four procedures, so the export list and every program's import list are
unchanged**. Free identifiers that the runner body used to receive from the
surrounding library — the adapter procedures, the fingerprint procedures, the
R5RS arithmetic — are all still bound, now by definition and import rather
than by include-time splicing; per the standing lesson, any name bound nowhere
kills the library at import, so the merged file fails loudly or not at all.

Net: two readers remain in the tree (the fingerprint library's private one,
the adapter's protocol one), each owned where it is used, replacing today's
three copies.

### 5.3 The product libraries

`(byte-machine placeholder)` absorbs `placeholder.scm` between its imports and
its close paren; `(byte-machine placeholder-consumer)` likewise, and keeps
importing the owner. The owners' headers — "a library form, imports, exports,
and the include; nothing else" — described a division of labor that no longer
exists and are replaced by the body's own header. The consumer's header note
pointing at the one-owner mutation is replaced by one pointing at its
replacement (§9.2). The fresh-allocation representation choices (tag vector,
marker singleton) move unchanged; they were never about the include mechanism.

## 6. The programs

Each merged `.sps` is: the wrapper's import form minus
`(only (chezscheme) include)`, then the body text where the `include` form
sat, inside the wrapper's existing `harness-begin`/`harness-finish` frame
where one exists (the bootstrap wrapper deliberately calls neither, and the
merged bootstrap keeps that).
Renames: `harness-bootstrap.chez.sps` → `harness-bootstrap.sps`, and likewise
for `harness-failing`, `harness-self-tests`, `harness-duplicate-case`,
`harness-empty-selection`, `harness-unreached-provenance`,
`placeholder-tests`, `placeholder-identity-tests`.

**The program file joins the manifest.** This is a strengthening the merge
forces into the open: today the wrapper's twelve lines are outside every
fingerprint; after the merge the test text lives in the program, and a
manifest that omitted it would let a program edit ship unfingerprinted. The
re-scoped claim is: *every byte of Scheme the lane runs — program and
libraries — is fingerprinted.* The provenance lanes that prove the check can
fail (wrong expectation, absent expectation, missing manifest entry,
unreached verification) keep their shapes against the new manifest.

## 7. Launchers

**`chez-source.ss`.** `--source-dir` leaves all three flag lists; the
program-directory append dies with it; `(source-directories '())` is set
outright. The line is kept for the same reason `chez-aot.ss` keeps it — it
narrows what a later top-level `load` or `include` could reach — and it is a
declared survivor for the same measured reason as C3b: with no `include` form
anywhere, resolution runs entirely through `library-directories`, so deleting
the line is inert. The object guard, its two refusal checks, and the flag
grammar refusals are untouched. The header's what-this-does-not-check section
loses its source-directory clause.

**`chez-compile.ss`.** Same flag removal, same `(source-directories '())`,
same program-directory retirement. `compile-program` expands a program whose
text contains no include and whose libraries resolve through the paired
`library-directories` — which is the pairing-count refusal's continued reason
to exist.

**`chez-aot.ss`.** Unchanged. It never took `--source-dir`, and its source
guard is the mechanism slice 5b already proved.

**`fingerprint-manifest.ss`.** Arguments become
`<library-root> <object-guard> <output> <body>...`. It pairs the root against
the always-empty guard on `library-directories`, imports
`(byte-machine test fingerprint)`, and computes as before. The `load`, the
local `adapter-file-bytes` copy, and the shared-dir argument all go. The
header's no-second-implementation argument survives with a stronger mechanism
under it; the guard pairing is what keeps the expectation computed from source
text, by the same reasoning the source lane's object guard was built on. The
top-level `import`-under-`--script` mechanics are this design's one unverified
assumption and are the implementation plan's first measured fact (§14).

## 8. The lane machinery

### 8.1 `SOURCES` and the manifest

`SHARED_BODIES` renames to `SOURCES` everywhere — registrar argument, spec
expectations, environment plumbing comments. A lane's `SOURCES` is its program
plus every repository `.sls` it loads:
`BYTE_MACHINE_HARNESS_MANIFEST` becomes `fingerprint.sls` + `harness.sls`;
the placeholder lanes append their product libraries; every lane appends its
own program. The declared/measured split survives untouched: source lanes
measure the declared paths, compiled lanes measure the copies their build step
wrote. `byte_machine_expected_fingerprint`'s invocation carries the new
launcher arguments, and its `DEPENDS` keeps an explicit entry for the
algorithm's source — now `fingerprint.sls` — because the algorithm affects
every expectation whether or not a manifest lists it.

### 8.2 The per-lane basename invariant

The repository-wide basename guard dies with the flat include namespace, but a
smaller invariant survives it: `byte_machine_lane_measured_copies` keys the
compiled lane's `fingerprint/` directory by basename, so **within one lane's
`SOURCES` list, basenames must be unique**. That check moves into the
registrar as a configure-time `FATAL_ERROR` naming the colliding entries, with
its own spec assertions and its own mutation in `MutationSuite.cmake`. The
helper's comment stops citing the deleted guard and cites the registrar's
check instead.

### 8.3 The aot branch: carried, unwitnessed

The aot branch of `byte_machine_scheme_lane_command` and the measured-copies
helper are edited to the new manifest shape with no registered lane to witness
them — the collapse-first cost, accepted in §2. The lane-command spec still
asserts the branch's output shape under `cmake -P`, so the carry is
spec-witnessed but not lane-witnessed. The 5b remainder's staleness lane and
C1–C4 are what will witness it end to end, and its plan re-verifies this
slice's aot-branch edits rather than trusting them. Named here so no reader of
a green suite between the two slices mistakes coverage that does not exist.

## 9. Lanes and mutations

### 9.1 Lanes

- The three `placeholder-cwd-*` lanes collapse into one
  `byte-machine.portability.placeholder.chez.source`. Working-directory
  independence stops being an empirical claim: absolute library roots, empty
  `source-directories`, and nothing else consulted. The decoy fixtures, the
  `configure_file` refresh wiring, and the impostor body go with them.
- `launcher-no-source-dir` retires with its flag. Every surviving refusal
  lane's command line drops its `--source-dir` arguments.
- The portability-guard spec lane retires with the module.
- The identity lane, the provenance lanes, the verbose lane, and the launcher
  refusal inventory otherwise stay.

### 9.2 Mutations

Ruled by the standing lesson: a mutation is not dead just because its
witnesses are — before deleting one, ask what its REPLACE still changes in the
surviving tree.

**Retired as objectless** (the text the mutation edits no longer exists):
the asymmetric launcher mutation over the working-directory matrix, and the
`--source-dir` flag-vocabulary passes. Their subjects are deleted lines, not
surviving behavior.

**Retired as unconstructible, with a constructible replacement.** The
one-owner passes (decision 0003's import-replaced-by-include) cannot be
written against a tree with no include form and no body files. But the defect
class they guarded — a consumer acquiring its own copy of the owner's
identity — survives inlining, because copy-paste can reintroduce it. The
replacement pass replaces the consumer's import of
`(byte-machine placeholder)` with inline duplicate definitions of the four
placeholder procedures; the identity lane must fail with ordinary check
failures at exit 1 while every other lane stays green — the same asymmetric
witness shape 0003 proved, reconstructed for the inline world.

**Retargeted:** every body mutation whose FIND/REPLACE text survives moves its
FILE from the `.scm` body to the `.sls`/`.sps` now carrying that text; the
runner and placeholder decision mutations are this category wholesale. The
provenance passes keep their staged-lane shapes against the re-scoped
manifest.

**Deleted with their module:** the 12 portability-guard declarations in
`MutationSuite.cmake`.

Every retirement, retarget, and replacement updates the owning suite's
declared pass/mutation totals in the same commit, and the whole mutation suite
re-runs after any change to registrations or exits, checking each affected
pass's baseline and mutant still differ for the named reason.

## 10. Documents

- **`docs/decisions/0006-inline-libraries.md`** records the collapse: context (0005 and §6),
  the inline-library decision, the manifest re-scope and its strengthened
  claim, the per-lane basename invariant, and the replacement identity
  mutation. It is what adds supersession headers to 0002 and 0003 — noting
  that 0003's identity *lane* survives; what is superseded is the one-owner
  rule and its include-based enforcement.
- **AGENTS.md** drops the transition clause: "Libraries are R6RS `.sls`;
  libraries and programs contain their own code — no shared include bodies.
  R6RS forbids assigning an exported variable — reach mutable state through
  procedures."
- **The governing plan** gets §7.2's wrapper paragraphs and §8's layout note
  rewritten to their post-collapse text, and a sweep
  (`rg -n -i 'follow-up slice|include-collapse|shared body' docs/plans/byte-machine-implementation-plan.md`)
  rewrites any remaining transitional hedge.
- **Amendment notes**, by 0005's stated rule (a record gains a note when a
  claim in it is now false or live code points readers at it): the slice-3
  design (the mechanism it designed is retired), the slice-4 design (its
  enforcement mechanism is replaced), the 5b/5c design (`chez-compile.ss`
  usage and `SHARED_BODIES` naming), milestone-plan §5/§9 sites that present
  the include decision as current, and **decision 0004** — its decision 3
  names `SHARED_BODIES` as the required argument and its decision 4 records
  the `load`-verbatim mechanism, both of which this slice renames or
  replaces while keeping the discipline they state. Decisions 0001 and 0005
  need none: nothing in them becomes false.
- **`chez-only-simplification.md` §6** gains a dated header note naming this
  document and, when landed, the implementing PR — the plan promised a named
  follow-up, and the record should show it arrived.
- **CHANGELOG** (unreleased): the collapse, the retired mechanisms, the
  re-measured line counts against §3's baseline.

## 11. How the slice earns trust

1. **The semantic sweep, verbatim from §6:**
   `rg -n -i 'both runtimes|both adapters|both wrappers|two wrappers|each runtime|per runtime|two standards|r7rs|parity proof' src test`
   clean except deliberate, named survivals — plus the reading pass the
   Chez-only cut proved necessary, because drift can describe a retired world
   without using its names ("every runtime must report the same value" in the
   fingerprint header is the standing example; it dies in §5.1's rewrite).
2. **A gate the include world could not state:** zero `include` forms and zero
   `(only (chezscheme) include)` imports in any `.sls`, `.sps`, or `.ss` under
   `src/` and `test/`. Executable, and expected to stay true forever.
3. **The suite, fresh:** `make clean && make test-all` green after every task,
   declared totals correct, every surviving mutation still discriminating for
   its named reason.
4. **The measurement:** harness and product line counts re-taken and recorded
   in the CHANGELOG against the 8,327/110 baseline and the §6 estimate.

## 12. Work order

Design-level phases; the implementation plan cuts tasks. Two rules govern
every phase: the tree configures and the full suite passes at each phase
boundary, and a phase that moves or deletes a file carries the registration,
manifest, and fixture edits that move forces — file moves and the wiring that
names them are not separable into different phases, because the registrar
refuses a manifest entry that does not exist.

1. **Law first:** decision 0006, supersession headers on 0002/0003, AGENTS.md,
   the governing-plan rewrites, the amendment notes.
2. **The fingerprint library** — after the plan's first measured fact (§14)
   confirms the mechanics. `fingerprint.sls` is created, both consumers
   switch (the harness's `include` becomes an import; the manifest launcher's
   `load` becomes an import), and `fingerprint.scm` is deleted in the same
   phase, so the algorithm never exists in the tree twice.
3. **The harness collapse:** runner inline, `shared/` deleted, harness root
   moves up.
4. **The src collapse and program merges:** product libraries inline,
   `src/common`/`src/chez` deleted, eight programs merged and renamed.
5. **Launchers and the residue:** flag removals, the `SOURCES` rename,
   cwd-matrix retirement, the per-lane basename check, refusal-lane inventory.
6. **Guard deletion:** module, spec, spec lane, 12 mutation declarations.
7. **Mutation-suite rework:** retirements, retargets, the replacement identity
   pass, totals — then the full suite re-run and the discriminating check.
8. **The gates:** §11's sweeps and measurement, CHANGELOG, PR.

## 13. Out of scope

- **The 5b remainder** (aot lane wiring, staleness lane, C1–C4, 0004
  amendment): follows this slice, per §2, on the inline tree.
- **Dissolving the adapter protocol** or splitting the runner: rejected in §2.
- **Milestone 1's real libraries**: this slice hands them a tree where a new
  library is one ordinary file, which is the point.
- **Renaming `harness-*` procedure prefixes or lane names**: the lane-name
  vocabulary (`chez.source`, `chez.aot`, `cmake.direct`) is untouched.

## 14. Risks and open questions

- **Top-level `import` under `--script`** (the manifest launcher's new
  mechanism) is asserted, not yet measured. It is the implementation plan's
  first task: measure, record in 0006, and only then build on it. If it fails,
  the fallback is one `eval` over `(environment ...)` — uglier, same
  guarantee — and the design does not otherwise change.
- **The aot branch rides unwitnessed** between this slice and the 5b
  remainder (§8.3). Accepted and named; the 5b plan re-verifies.
- **The mutation-suite rework is the bulk of the effort.** SchemeMutationSuite
  is 1,615 lines and most passes name paths or stage bodies this slice moves.
  The plan should budget accordingly and keep the retarget commits mechanical
  (path moves separate from behavioral rewrites).
- **History legibility:** eight merges and two tree moves in one slice.
  The plan should stage `git mv` of the larger file of each pair before
  editing, so blame follows the test text rather than the wrapper.
