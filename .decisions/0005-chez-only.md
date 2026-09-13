# 0005: The second runtime goes, because the only consumer that required it is being replaced

Date: 2026-08-18
Status: accepted
Milestone: 0, plan amendment during slice 5b

## Context

byte-machine has carried two runtimes since [decision 0001](./0001-toolchain-discovery.md).
Every program registers two lanes; every shared body is twinned `.scm` /
`.gambit.scm` behind a pairing guard; all product code was required to be
written to the R6RS∩R7RS intersection, which is why the parent plan's §7.1
forbade record systems, hash tables, bytevector literals, and
`bytevector-copy!` outright.

That requirement had exactly one source. protium — the sibling project
[the milestone plan](../.plans/milestone-0-portability-spike.md) §3 takes most of
this repository's build and harness shape from — required "one behaviorally
identical Scheme API on Chez and Gambit". protium is being replaced by a
Chez-only libuv library. No remaining consumer requires Gambit.

Nothing about the second runtime was wrong. It stopped having a reason, and a
mechanism with no reason still costs every future slice its maintenance.

The full amendment and removal plan is
[chez-only-simplification.md](../.plans/chez-only-simplification.md). This record
is its §4 deliverable and states what the contract now is.

## Measurements

Measured 2026-08-18 against the shipped tree at commit `cf900d7` on branch
`feat/m0-slice-5b-chez-aot` — the tree as it stands *before* any removal task
runs — on Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8. AGENTS.md requires a
number in a decision record to have been re-taken against the shipped artifact.
The first three below were re-taken here; the fourth is marked as the plan's
estimate rather than as a measurement, because it is one.

- **The harness outweighs the product it tests by two orders of magnitude.**

  ```
  $ find cmake test/support -type f | xargs wc -l | tail -1
      9858 total
  $ find src -type f | xargs wc -l | tail -1
       147 total
  ```

  Milestone 0 ships no byte-machine semantics by design (milestone plan D4), so
  this ratio is expected at this point in the project. It is recorded because it
  is the denominator every fraction below is taken against, not as a complaint.

- **Whole files that exist only for Gambit, or only for the `.scm` /
  `.gambit.scm` pairing convention: 1,387 lines.** Exact, over the deletion set
  the removal plan's Tasks 2–4 name — `cmake/ByteMachineGambit.cmake`,
  `cmake/gambit-probe.scm`, `cmake/ByteMachinePortabilityGuard.cmake`, the two
  matching specification files, `src/gambit/`, `test/gambit/`,
  `test/support/harness/gambit/`, and the eight `*.gambit.scm` twins:

  ```
  $ { ls cmake/ByteMachineGambit.cmake cmake/gambit-probe.scm \
         cmake/ByteMachinePortabilityGuard.cmake \
         test/support/cmake/ByteMachineGambitSpec.cmake \
         test/support/cmake/ByteMachinePortabilityGuardSpec.cmake
      find test/support/harness/gambit test/gambit src/gambit -type f
      find test -name '*.gambit.scm'; } | sort -u | xargs wc -l | tail -1
      1387 total
  ```

- **12 of the 49 registered lanes name Gambit**, and the suite is green at
  49/49 on this tree:

  ```
  $ ctest --test-dir build/dev -N | rg -i gambit | rg -c 'Test\s+#'
  12
  $ make test
  100% tests passed, 0 tests failed out of 49
  ```

- **The plan's "roughly 2,600 lines" is larger than any figure above, and is not
  re-measured here.** [chez-only-simplification.md](../.plans/chez-only-simplification.md)
  §1 states that roughly 2,600 lines exist only for Gambit or for the pairing
  convention. That total additionally counts Gambit-specific *regions inside
  files that survive the cut* — the `BACKEND gambit` registrations in
  `test/CMakeLists.txt`, the Gambit passes and the with/without-Gambit count
  arithmetic in `test/support/cmake/SchemeMutationSuite.cmake`, the `gambit`
  branch of `cmake/ByteMachineSchemeLane.cmake`. Those regions are real but were
  not itemized. What *is* measured is a floor on them: 329 lines across
  surviving files name Gambit outright (`rg -i -c gambit`, excluding the
  whole-file set above), and a lane registration or a mutation pass runs several
  lines per naming line. The exact total becomes measurable only once the
  removal tasks land; it belongs in the changelog entry that records them, not
  here.

## Decision

1. **byte-machine targets Chez Scheme and R6RS. Gambit and R7RS leave the
   contract.** [Parent plan](../.plans/byte-machine-implementation-plan.md) §2
   decision 9 is amended accordingly: the backend targets Chez, libraries are
   ordinary R6RS `.sls`, and no cross-implementation wrapper layer exists.
   Product code is free to use full R6RS — §7.1's dialect-intersection list is
   retired, keeping only the two rules that were never about dialect (never rely
   on unspecified argument evaluation order; never put implementation exception
   text in a behavioral contract). Chez-specific emission stays gated on
   benchmark evidence through §2 decision 10, which now names what it gates:
   fixnum operations, unsafe declarations, and any identifier outside plain
   R6RS.

2. **Two execution lanes, not four: `chez.source` and `chez.aot`.** Tier 1
   remains the same four OS/architecture cells, each required in both lanes.

3. **Slice 5c is cancelled.** It existed only to add Gambit `.o1` and
   `gsc -exe -nopreload`. Milestone 0's deliverable D5 closes at two lanes
   rather than four; D6's determinism proof becomes a single-implementation,
   cross-platform claim; D8's CI covers Chez only.

4. **This is a one-way door, and it is accepted as one.** Re-adding Gambit means
   rebuilding, not un-commenting. The pairing guard, the cross-runtime half of
   shared-body ownership, and cross-runtime fingerprint agreement are three of
   the four hardest mechanisms slices 2–5 built, and each was built by being
   shown falsifiable. Deleting them deletes those proofs with them.

5. **What does not change.** OS/architecture portability
   (macOS/Linux/Windows, amd64/arm64) stays in the contract. Deterministic
   generation stays, restated as a single-implementation, cross-platform claim.
   The provenance discipline slice 5b is building — a compiled lane must be
   structurally unable to fall back to source, and a fingerprint must describe
   what an artifact was built from — is Chez-internal and is untouched. Slice
   5b's remaining scope is unchanged by this record.

## Consequences

- **Decisions 0001 and 0004 each lose a claim without being superseded.**
  [0001](./0001-toolchain-discovery.md)'s Gambit half — the GhostScript `gsc`
  collision, deriving `gsc` from a confirmed `gsi`, the `gcc-16` hard-coding —
  becomes history. Its Chez half is untouched and still governs discovery: never
  trust a binary name, interrogate every candidate by probe, reject Petite.
  [0004](./0004-content-fingerprint-and-provenance.md)'s claim 2, that Chez and
  Gambit report the same fingerprint string for the same bodies, becomes history
  too — it was true when measured on 2026-08-17 and there is no second runtime
  left for it to be a claim about. Everything else in 0004 stands, including the
  gap it hands slice 5b: a matching fingerprint does not prove the running code
  was built from the text it names. That gap is Chez-internal and is precisely
  what 5b is closing.

  Neither record gets a supersession header. A superseded decision is one a
  later decision replaced; these are decisions part of whose subject stopped
  existing. The records stay readable as what was decided, and why, at the time.

- **[0002](./0002-shared-body-include-mechanism.md) and
  [0003](./0003-cross-library-identity.md) remain in force, unchanged by this
  record.** The shared-body `include` mechanism (`source-directories` plus bare
  filenames) and the one-owner rule are not Gambit artifacts: with a single
  runtime, a body included by two libraries still gives tagged-vector type tags
  and allocation-free singleton outcomes two identities, and 0003's mutation is
  still what enforces it. They are retired by the follow-up slice named in
  [chez-only-simplification.md](../.plans/chez-only-simplification.md) §6, which
  moves each body inline into its owning library; that slice's own decision
  record is what will add supersession headers to them. This record adds none.

- **A cross-runtime disagreement is no longer a class of defect this repository
  can catch, because it is no longer a class of defect it can have.** The
  fingerprint instrument survives and keeps its other two claims (a lane reports
  what it ran; the check can fail, exiting 3). What it loses is the one claim
  that needed two runtimes to state. Nothing replaces it, and nothing should
  pretend to: a two-lane agreement between `chez.source` and `chez.aot` is a
  weaker statement, and slice 5b already owns it under its own name.

- **Removal is staged so the tree is never in a state its own checks reject.**
  The pairing guard goes first, because this record is what stops the convention
  it enforces from being law; then the lanes and twin files; then the toolchain
  layer, so no lane ever references a deleted module. AGENTS.md's mutation rule
  governs each step: a specification's declared pass and mutation totals are
  updated in the same commit as the passes they lose, and the whole mutation
  suite is re-run after any change to registrations or exits — a green suite
  with stale declared totals is exactly the false comfort that rule exists to
  prevent.

- **Amended by this record**: the parent plan throughout (decisions 2/9/10, the
  §3 goals, the §4 non-goals, §7's portability contract and platform tiers, the
  §8 layout, §9's reserved bindings and required examples, §20's determinism
  claim, §22's harness and determinism tests, §23's admission rule, §24's CI
  stages, §25's Milestone 0/1/7/9 items, §26's release criteria, §27's
  documentation deliverables, §28's now-retired R6RS/R7RS module-incompatibility
  risk, §29, §30); AGENTS.md's two contract bullets, plus a third: Task 4's
  literal-token gate (`rg -n -i --hidden 'gambit' --glob '!docs/**' ...`)
  forced the backend-gating lesson to drop "Gambit lane" from its example
  while keeping the lesson itself, because AGENTS.md sits outside the gate's
  `docs/` exclusion — three bullets changed in total, not two; `README.org`.
  The three milestone documents (the milestone plan, the slice 5b/5c design,
  and the slice 5a design) keep all of their Gambit content and gain only a
  dated header note — they record what was measured and decided at the time,
  and a record that is edited to agree with a later decision stops being
  evidence of anything.
  The rule for *when* a record earns that note, made explicit here because the
  final whole-branch review had to infer it: a design doc gains an amendment
  note when a claim in it is now false, or when live code points a reader at
  it — not merely because the document mentions Gambit. The slice 5a design is
  the case in point: this record did not note it when written, because at that
  point nothing had yet made its §6.1 false; it earned its note only once this
  record's own decision retired claim 2's cross-runtime half and this branch's
  rewrite of `fingerprint-manifest.ss` started sending readers to that section.
