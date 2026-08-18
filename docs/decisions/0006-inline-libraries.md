# 0006: Every library owns its own text, and the include mechanism retires

Date: 2026-08-18
Status: accepted
Milestone: 0, the include collapse (chez-only-simplification.md §6)

## Context

Decision 0005 removed the second runtime and deliberately left the
single-runtime indirection standing: shared `.scm` bodies included by owner
libraries through `source-directories`, launchers carrying `--source-dir`, a
working-directory matrix, a repository-wide basename guard, and a one-owner
rule enforced by mutation. The sharing mechanism's second consumer no longer
exists. The design for the collapse is
[milestone-0-include-collapse.md](../plans/milestone-0-include-collapse.md);
this record states what the contract now is.

## Measurements

Measured 2026-08-18, Darwin arm64, Chez 10.4.1, against `main` (76f3238)
unless stated.

- **Top-level `import` under `--script` resolves through
  `library-directories`.** A probe script that sets
  `(library-directories (list (cons root guard)))` and then `(import (demo
  fp))` mid-file prints the library's value and exits 0; the same probe
  pointed at a root without the library dies with "library (demo fp) not
  found". Measured: `chez --script probe.ss <root> <guard>` prints `41`,
  exit 0; `chez --script probe.ss <guard> <guard>` — root repointed at a
  directory without the library — prints `Exception: library (demo fp) not
  found`, exit 255. This is the mechanism fingerprint-manifest.ss now uses
  in place of `load`.
- **Baseline sizes.** Harness (`cmake/` + `test/support/`): 8,327 lines;
  `src/`: 110 lines; 37 release-preset lanes; SchemeMutationSuite 29
  passes / 65 mutations; MutationSuite 1 pass / 75 mutations, of which the
  ByteMachinePortabilityGuard section holds 12.
- **`(source-directories '())` is inert where nothing includes** — measured
  for the AOT launcher on 2026-08-17 (5b/5c design §5.3, mutation C3b);
  extended to the source launcher by this slice, where after the collapse no
  `include` form exists for the parameter to serve.

## Decision

1. **Libraries are inline R6RS `.sls`; programs are plain `.sps`; no Scheme
   file in this repository includes another.** The shared-body contract
   (decisions 0002/0003) is retired, not amended: bodies move into their
   owners verbatim, the eight `.chez.sps`/`.scm` program pairs merge into
   single `.sps` programs, and the `.chez` filename infix goes with the twin
   files it disambiguated.
2. **The fingerprint algorithm is a library, `(byte-machine test
   fingerprint)`, because it has two consumers.** The harness imports and
   re-exports it; `fingerprint-manifest.ss` imports it directly, with its
   library root paired against the always-empty object guard so the
   build-time expectation is computed from source text. The
   no-second-implementation guarantee moves from a verbatim `load` to the
   module system.
3. **A lane's manifest is its program plus every repository `.sls` it
   loads.** Every byte of Scheme a lane runs is fingerprinted — the
   include-era manifest covered shared bodies only, leaving wrapper text
   outside the fingerprint. The declared/measured split of decision 0004 and
   slice 5b is unchanged: source lanes measure the declared paths, compiled
   lanes the copies their build step wrote.
4. **Basename uniqueness narrows from repository-wide law to a per-lane
   registration check.** The flat `fingerprint/` copy directory keys
   measured copies by basename, so within one lane's SOURCES basenames must
   be unique; `byte_machine_add_scheme_lane` refuses violations at configure
   time. The repository-wide guard, its specification, and its twelve
   mutations are deleted with the include namespace they policed.
5. **The one-owner rule is retired as unconstructible; its defect class
   keeps a witness.** With no `include` form, "a second library includes the
   body" cannot be written. The surviving form of the defect — a consumer
   acquiring its own copies of the owner's definitions — is constructible by
   copy-paste, and the identity lane's rewritten mutation (consumer import
   replaced by inline duplicate definitions) catches it at exit 1.
6. **Launchers lose `--source-dir` and set `(source-directories '())`.**
   Working-directory independence becomes structural: absolute library
   roots, an empty source path, nothing else consulted. The cwd matrix and
   its asymmetric mutation retire; one placeholder lane remains, launched
   from the default private directory like every other lane.

## Consequences

- **Decisions 0002 and 0003 are superseded by this record** and gain
  supersession headers. 0003's identity *lane* survives — what is superseded
  is the one-owner rule and its include-based enforcement.
- **Decision 0004 gains an amendment note, not a supersession**: its
  decision 3 names `SHARED_BODIES` (renamed SOURCES) and its decision 4
  records the `load`-verbatim mechanism (replaced by import). The
  requiredness and skip-not-refuse disciplines it decides are unchanged.
- **The aot branch of the lane command is edited unwitnessed.** No
  registered lane exercises the aot mode until the 5b remainder lands
  (collapse-first, design §2/§8.3); the lane-command specification still
  asserts the branch's output shape, and the 5b remainder re-verifies the
  edits end to end.
- **The amendment-note rule of 0005 is applied**, adding dated notes to the
  slice-3 design, the slice-4 design, the 5b/5c design, the milestone plan,
  and 0004; 0001 and 0005 need none — nothing in them becomes false.
- The semantic-vocabulary sweep fixed in chez-only-simplification.md §6 is
  this slice's acceptance gate, plus a new executable gate the include world
  could not state: zero `include` forms in any `.sls`/`.sps`/`.ss` under
  `src/` and `test/`.
