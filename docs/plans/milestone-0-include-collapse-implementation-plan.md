# Milestone 0, The Include Collapse — Implementation Plan

Status: executed; delivered 2026-08-20 (decision 0006, PR #8)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every `include` form from the repository: each library becomes an ordinary inline R6RS `.sls`, each test program a plain `.sps`, and the `include`/`source-directories` mechanism — launchers' `--source-dir`, the cwd matrix, the repository-wide basename guard, the one-owner rule — retires with its subject.

**Architecture:** Law first (decision 0006, supersessions, plan rewrites), then the collapse in dependency order: the two-consumer fingerprint body becomes `(byte-machine test fingerprint)`; the runner inlines into the harness library and the harness root loses its `chez/` segment; the repo-wide guard is replaced by a per-lane basename check and deleted; `src/` collapses and the cwd matrix retires; the eight program pairs merge; the launchers lose `--source-dir`; `SHARED_BODIES` renames to `SOURCES`. Every phase ends green with declared totals updated in the same commit.

**Tech Stack:** CMake 3.26 / CTest presets, Chez Scheme 10.4.1, the project's own `cmake -P` specification and mutation harnesses.

**Design:** [`milestone-0-include-collapse.md`](./milestone-0-include-collapse.md). Section references (§N) below are to that document unless a file is named.

## Global Constraints

- Every task ends with the suite green and a Conventional Commit. `make test-all` (preset `release`) is the gate; tasks that change configure inputs (5, 6, 8) run `make clean && make test-all`.
- Declared pass/mutation totals are updated **in the same commit** as the passes they gain or lose (AGENTS.md). After any change to registrations or exits, the whole mutation suite re-runs and each affected pass must still discriminate for its named reason.
- Baseline on `main` (76f3238), measured 2026-08-18: **37** release-preset lanes, **9** no-scheme lanes, SchemeMutationSuite **29 passes / 65 mutations**, MutationSuite **1 pass / 75 mutations**. Harness (`cmake/` + `test/support/`) 8,327 lines; `src/` 110 lines. (No-scheme corrected after Task 5 measured it: the plan first said 10, a count stale since the Chez-only cycle's own module deletion.)
- Expected counts after each task (the totals gates enforce the mutation columns; a step in each task verifies the lane column):

  | After task | Release lanes | Scheme passes/mutations | CMake pass/mutations | no-scheme |
  |---|---|---|---|---|
  | 1–4 | 37 | 29/65 | 1/75 | 9 |
  | 5 | 36 | 29/65 | 1/66 | 8 |
  | 6 | 34 | 26/62 | 1/66 | 8 |
  | 7 | 34 | 26/62 | 1/66 | 8 |
  | 8–10 | 33 | 25/60 | 1/66 | 8 |

  (CMake column corrected after Task 5's review: eleven guard mutations died with their namespace, the twelfth — the accumulator-initialization hazard — moved with the function body it protects, so the arithmetic is 75 − 12 + 3 = 66, not the 65 first planned.)

- Exit-status vocabulary is exactly **0, 1, 2, 3**. Launcher diagnostics keep the `byte-machine-launcher: HARNESS-ERROR ` prefix and exit **2**.
- CMake floor **3.26**: `cmake_parse_arguments` leaves an explicitly-empty one-value keyword undefined (CMP0174 is 3.31+); mutation REPLACEs use `# deleted` comments, never empty strings.
- The `|` separator for environment-borne path lists; never `:` or `;`.
- **Inlined bodies keep their text verbatim at column 0** inside the surrounding `library` form. This is load-bearing twice over: ~30 mutation FIND anchors match on exact indentation, and `git blame` follows unchanged lines. Only headers explicitly rewritten by a step change.
- No new dependencies. Nothing added to the functional core may require a Scheme runtime to specify; the no-scheme preset stays green (9 lanes through Task 4, 8 from Task 5).

---

## File Structure

**Created**
- `docs/decisions/0006-inline-libraries.md` — the decision record; adds supersession authority over 0002/0003
- `test/support/harness/chez/byte-machine/test/fingerprint.sls` (Task 3; moves up to `test/support/harness/byte-machine/test/fingerprint.sls` in Task 4) — self-contained fingerprint algorithm library
- `src/byte-machine/placeholder.sls`, `src/byte-machine/placeholder-consumer.sls` (Task 6, via `git mv` from the bodies) — inline product libraries

**Modified**
- `docs/plans/byte-machine-implementation-plan.md` (§7.2, §8), `AGENTS.md`, `docs/decisions/0002…`, `0003…`, `0004…`, four milestone/slice docs, `docs/plans/chez-only-simplification.md`, `docs/plans/milestone-0-include-collapse.md` (12-vs-13 correction), `CHANGELOG.md`
- `test/support/harness/{chez/}byte-machine/test/harness.sls` — imports fingerprint (T3), absorbs the runner (T4)
- `test/support/launchers/fingerprint-manifest.ss` (T3), `chez-source.ss`, `chez-compile.ss` (T8)
- `cmake/ByteMachineSchemeLane.cmake` — per-lane basename check (T5), `--source-dir` emission (T4/T6/T8), `SOURCES` rename (T9)
- `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, `SchemeMutationSuite.cmake`, `MutationSuite.cmake` — tracking every change above
- `test/CMakeLists.txt`, `CMakeLists.txt` — registrations, roots, guard call, matrix wiring
- Eight test programs merged to `.sps` (T7)

**Deleted**
- `test/support/harness/shared/fingerprint.scm` (T3), `…/shared/harness-runner.scm` + `shared/` (T4)
- `cmake/ByteMachinePortabilityGuard.cmake`, `test/support/cmake/ByteMachinePortabilityGuardSpec.cmake` (T5)
- `src/common/`, `src/chez/` (T6); eight `.chez.sps` wrappers and eight `.scm` program bodies (T7, by merge)

---

### Task 1: Measured fact — top-level `import` under `--script`

The manifest launcher's rewrite (Task 3) assumes a `--script` file can set `library-directories` and then `import` a library mid-file. §14 makes this the plan's first measured fact. No repository changes; no commit.

**Files:** none (scratchpad only).

**Interfaces:**
- Produces: a measured yes/no plus transcript lines for 0006's Measurements section (Task 2 consumes them verbatim).

- [ ] **Step 1: Build the scratch fixture**

Write these three files under the session scratchpad (`$SCRATCH` below stands for that directory):

`$SCRATCH/import-probe/root/demo/fp.sls`:
```scheme
(library (demo fp)
  (export demo-value)
  (import (rnrs))
(define (demo-value) 41)
)
```

`$SCRATCH/import-probe/probe.ss`:
```scheme
(define root (car (command-line-arguments)))
(define guard (cadr (command-line-arguments)))
(library-directories (list (cons root guard)))
(import (demo fp))
(display (demo-value))
(newline)
(exit 0)
```

And create an empty guard directory:
```bash
mkdir -p "$SCRATCH/import-probe/guard"
```

- [ ] **Step 2: Positive run**

Run (substituting the discovered Chez, e.g. from `build/dev/CMakeCache.txt`'s `BYTE_MACHINE_CHEZ_EXECUTABLE`):
```bash
"$CHEZ" --script "$SCRATCH/import-probe/probe.ss" "$SCRATCH/import-probe/root" "$SCRATCH/import-probe/guard"
```
Expected: prints `41`, exit 0. This is the whole mechanism: parameter set first, `import` next, both at the top level of a `--script` file.

- [ ] **Step 3: Negative control**

Run the same probe with a root that does not contain the library:
```bash
"$CHEZ" --script "$SCRATCH/import-probe/probe.ss" "$SCRATCH/import-probe/guard" "$SCRATCH/import-probe/guard"
```
Expected: nonzero exit with `library (demo fp) not found` in the error text. The import genuinely goes through `library-directories`, not through some ambient path.

- [ ] **Step 4: Record**

Keep both transcripts. Task 2 writes them into 0006's Measurements section with the date and Chez version. If step 2 fails, stop: the fallback is one `eval` of the compute expression over `(environment '(byte-machine test fingerprint))`, the design does not otherwise change, and 0006 records the fallback instead — but do not proceed on an unmeasured assumption.

---

### Task 2: The written law changes first

Every document change, in one commit, before any mechanism moves — the same shape as the Chez-only cut's Task 1.

**Files:**
- Create: `docs/decisions/0006-inline-libraries.md`
- Modify: `docs/decisions/0002-shared-body-include-mechanism.md`, `0003-cross-library-identity.md`, `0004-content-fingerprint-and-provenance.md`, `AGENTS.md`, `docs/plans/byte-machine-implementation-plan.md`, `docs/plans/milestone-0-slice-3-shared-body.md`, `docs/plans/milestone-0-slice-4-cross-library-identity.md`, `docs/plans/milestone-0-slice-5b-5c-compiled-lanes.md`, `docs/plans/milestone-0-portability-spike.md`, `docs/plans/chez-only-simplification.md`, `README.org` (if the sweep in step 5 hits)

**Interfaces:**
- Produces: decision 0006 (cited by header notes and later commit messages); the amended AGENTS.md bullet every later task works under.

- [ ] **Step 1: Write `docs/decisions/0006-inline-libraries.md`**

Content, following the house record shape (Context / Measurements / Decision / Consequences):

```markdown
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
  found". <replace with the actual two transcript excerpts from Task 1>
  This is the mechanism fingerprint-manifest.ss now uses in place of `load`.
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
```

Replace the `<replace with …>` marker with the real Task 1 transcript excerpts before committing.

- [ ] **Step 2: Supersession headers on 0002 and 0003**

In `docs/decisions/0002-shared-body-include-mechanism.md`, after the `Milestone: 0, slice 3` line, insert:

```markdown
Superseded: 2026-08-18 by [0006](./0006-inline-libraries.md) — the include
mechanism this record decides is retired; bodies now live inline in their
owning libraries. The measurements and the repeatable-flags decision remain
valid history (the flag protocol survives; `--source-dir` itself does not).
```

In `docs/decisions/0003-cross-library-identity.md`, after the `Milestone: 0, slice 4` line, insert:

```markdown
Superseded: 2026-08-18 by [0006](./0006-inline-libraries.md) — the one-owner
rule and its import-vs-include mutation are retired with the include
mechanism. The identity lane itself survives, witnessed by 0006's replacement
mutation (a consumer inlining duplicate definitions instead of importing the
owner).
```

- [ ] **Step 3: The 0004 amendment note**

In `docs/decisions/0004-content-fingerprint-and-provenance.md`, after its `Milestone:` line, insert:

```markdown
> Amended 2026-08-18 by [decision 0006](./0006-inline-libraries.md): the
> include collapse renamed `SHARED_BODIES` to `SOURCES` (decision 3 below
> names the old spelling) and replaced `fingerprint-manifest.ss`'s verbatim
> `load` with an import of `(byte-machine test fingerprint)` (decision 4
> records the `load` mechanism). Both disciplines those decisions state —
> the manifest is declared and required at registration; provenance is
> skipped, never refused, at run time — are unchanged.
```

- [ ] **Step 4: AGENTS.md**

Replace:
```markdown
* Libraries are R6RS `.sls`. Until the include-collapse slice lands, shared
  `.scm` bodies contain no library or include form and are included by exactly
  one owner library. R6RS forbids assigning an exported variable — reach mutable
  state through procedures.
```
With:
```markdown
* Libraries are R6RS `.sls`; libraries and programs contain their own code —
  no shared include bodies (docs/decisions/0006-inline-libraries.md). R6RS
  forbids assigning an exported variable — reach mutable state through
  procedures.
```

- [ ] **Step 5: The governing plan**

In `docs/plans/byte-machine-implementation-plan.md` §7.2, replace the transition paragraph:
```markdown
Libraries are R6RS `.sls`. During the transition, the shared-body `include` mechanism and the one-owner rule of decisions 0002/0003 remain in force exactly as decided; the follow-up slice named in [chez-only-simplification.md](./chez-only-simplification.md) §6 retires them by moving each body inline into its owning library.
```
With:
```markdown
Libraries are R6RS `.sls`; each library and each test program contains its own code. No Scheme file in this repository includes another — the transitional shared-body mechanism of decisions 0002/0003 was retired by [decision 0006](../decisions/0006-inline-libraries.md).
```
Delete §7.2's closing line `Chez libraries may use `include` inside the library; shared bodies themselves contain no library or include form.` (the diagram and the `runtime`/`interpret` paragraph stay). In §8, delete the paragraph `` `src/common/` and `src/chez/` remain in place until the §6 follow-up slice collapses them; the second-runtime source tree is deleted by [chez-only-simplification.md](./chez-only-simplification.md). `` and the paragraph `If cross-library `include` behavior is unreliable, begin with fewer shared files and split them only once that behavior is proven reliable. Do not duplicate semantic implementations to preserve the proposed directory shape.` Then sweep for surviving hedges:
```bash
rg -n -i 'shared body|shared bodies|include mechanism|one-owner|follow-up slice' docs/plans/byte-machine-implementation-plan.md
```
Rewrite every remaining hit by the rule *libraries contain their own code; name 0006 where a mechanism is referenced*. Expected after: zero hits. Then check the README the same way:
```bash
rg -n -i 'shared bod|include|source-dir|\.scm' README.org
```
Rewrite any hit that describes the include mechanism as current (build-instruction prose naming Chez, presets, or `include(...)` in CMake snippets is not a hit — the rule targets the retired Scheme mechanism, not the words).

- [ ] **Step 6: Amendment notes on the four milestone/slice records**

Each is a `>`-quoted block inserted directly under the document's `Date:`/status header lines (the portability-spike file already carries an 0005 note; add this one after it).

`milestone-0-slice-3-shared-body.md`:
```markdown
> Amended 2026-08-18 by [decision 0006](../decisions/0006-inline-libraries.md):
> the include mechanism this slice designed and proved is retired — bodies now
> live inline in their owning libraries, launchers take no `--source-dir`, and
> the working-directory matrix (§7.4) is gone. This document records how the
> mechanism worked and how it earned trust while it was law.
```

`milestone-0-slice-4-cross-library-identity.md`:
```markdown
> Amended 2026-08-18 by [decision 0006](../decisions/0006-inline-libraries.md):
> the one-owner rule this slice enforced by mutation is retired with the
> include mechanism. The identity lane and the consumer's import-the-owner
> shape survive; the mutation that replaced an import with an include is
> unconstructible against the inline tree and was replaced by an
> inline-duplication form (0006 decision 5).
```

`milestone-0-slice-5b-5c-compiled-lanes.md`:
```markdown
> Amended 2026-08-18 by [decision 0006](../decisions/0006-inline-libraries.md):
> the include collapse landed before this document's remaining 5b scope.
> `chez-compile.ss` no longer takes `--source-dir` (§5.1 item 2 records the flag grammar it followed),
> `SHARED_BODIES` is now `SOURCES`, and a lane's manifest is its program plus
> the `.sls` libraries it loads. The provenance discipline, the two-list
> split, and the C1–C4 mutations are unchanged in intent; their file targets
> are the inline libraries.
```

`milestone-0-portability-spike.md` (append after the existing 0005 note):
```markdown
> Amended 2026-08-18 by [decision 0006](../decisions/0006-inline-libraries.md):
> the shared-body include mechanism (§5's D6, `source-directories` plus bare
> filenames) is retired — libraries are inline `.sls` and nothing resolves
> through `source-directories`. §9 question 3's Chez half, already closed by
> construction under repeatable flags, is now closed by absence: there is no
> include left to resolve.
```

- [ ] **Step 7: The §6 delivery note**

In `docs/plans/chez-only-simplification.md`, directly under the `## 6. The named follow-up: collapsing the single-runtime indirection` heading, insert:
```markdown
> Delivered: designed by
> [milestone-0-include-collapse.md](./milestone-0-include-collapse.md),
> implemented by
> [milestone-0-include-collapse-implementation-plan.md](./milestone-0-include-collapse-implementation-plan.md),
> recorded as [decision 0006](../decisions/0006-inline-libraries.md).
```

- [ ] **Step 8: Suite and commit**

```bash
make test
```
Expected: same pass count as an untouched checkout (docs must not affect it).
```bash
git add -A && git commit -m "docs: the law changes first — inline libraries become the contract (0006)"
```

---

### Task 3: The fingerprint library

`fingerprint.scm` has two consumers; it becomes `(byte-machine test fingerprint)` (§2 decision 3, §5.1). The harness imports and re-exports it; the manifest launcher imports it instead of `load`ing; the algorithm never exists twice (§12 phase 2).

**Files:**
- Create: `test/support/harness/chez/byte-machine/test/fingerprint.sls`
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls`, `test/support/launchers/fingerprint-manifest.ss`, `test/CMakeLists.txt`, `test/support/cmake/SchemeMutationSuite.cmake`
- Delete: `test/support/harness/shared/fingerprint.scm`

**Interfaces:**
- Produces: library `(byte-machine test fingerprint)` exporting `harness-fingerprint-bytevector`, `harness-fingerprint-file`, `harness-fingerprint-combine`, `harness-fingerprint->string` (same names and behavior as today's exports of the harness); `fingerprint-manifest.ss` argv contract `<library-root> <object-guard> <output> <body>...`.
- Consumes: Task 1's measured import mechanism.

- [ ] **Step 1: Create the library, moving the body for blame**

```bash
git mv test/support/harness/shared/fingerprint.scm test/support/harness/chez/byte-machine/test/fingerprint.sls
```
Then edit the new file. Replace the header comment (lines 1–30, everything above `(define harness-fingerprint-modulus …`) with:

```scheme
;;; Content fingerprint for the text a lane runs.
;;;
;;; A run reports the digest of the sources it executed so that a stale
;;; artifact or a copied variant is detectable rather than merely unlikely. A
;;; matching fingerprint means the declared text is unchanged -- not that the
;;; run loaded exactly those files; the manifest is declared, not observed
;;; (decision 0004, unchanged by the include collapse).
;;;
;;; This is a change detector, not a cryptographic digest. It is a polynomial
;;; rolling hash modulo the Mersenne prime 2^61-1. Do not use it for anything
;;; security relevant.
;;;
;;; TWO CONSUMERS, ONE IMPLEMENTATION
;;;
;;; (byte-machine test harness) re-exports this library's surface, and
;;; fingerprint-manifest.ss imports it to compute build-time expectations.
;;; That is why this is a library of its own rather than text inlined into
;;; the harness: the expectation and the runner share one implementation
;;; through the module system, so they cannot drift apart (decision 0006).
;;;
;;; The arithmetic is deliberately not bitwise: the algorithm needs nothing
;;; beyond exact integers of unbounded range, which R6RS guarantees.
;;; Intermediate products exceed 64 bits, which is what makes exact bignums
;;; load-bearing rather than incidental.

(library (byte-machine test fingerprint)
  (export harness-fingerprint-bytevector
          harness-fingerprint-file
          harness-fingerprint-combine
          harness-fingerprint->string)
  (import (rnrs) (only (rnrs r5rs) modulo quotient remainder))
```
(Corrected after Task 3 landed: the algorithm uses `modulo`/`quotient`/`remainder`, which R6RS keeps outside `(rnrs)` in a strict library body — the same `only` clause `harness.sls` carries for the same reason. The plan's first draft said bare `(import (rnrs))`, which does not compile.)

Keep everything from `(define harness-fingerprint-modulus …)` to the end of the file **verbatim at column 0** (mutation FIND anchors and blame depend on it), with two exceptions. First, replace the comment-plus-definition of `harness-fingerprint-file` (the comment beginning `;; Fingerprints a file's exact bytes, read through adapter-file-bytes …` and the two-line define under it) with:

```scheme
;; Fingerprints a file's exact bytes. A binary port, so the value is a
;; fingerprint of bytes rather than of decoded characters -- and so an LF is
;; an LF on a platform whose text ports would translate it.
;; get-bytevector-all returns the EOF object for an empty file rather than a
;; zero-length bytevector, so an empty file fingerprints as the seed instead
;; of raising. This library reads files itself: the adapter-file-bytes
;; indirection existed for the retired dialect ceiling, and (rnrs io ports)
;; is all the reader ever needed.
(define (harness-fingerprint-read-bytes path)
  (let* ((port (open-file-input-port path))
         (bytes (get-bytevector-all port)))
    (close-port port)
    (if (eof-object? bytes) (make-bytevector 0) bytes)))

(define (harness-fingerprint-file path)
  (harness-fingerprint-bytevector (harness-fingerprint-read-bytes path)))
```

Second, append the library's closing paren as the file's final line:
```scheme
)
```

- [ ] **Step 2: The harness imports and re-exports**

In `test/support/harness/chez/byte-machine/test/harness.sls`:
1. Add `(byte-machine test fingerprint)` to the import form, after `(rnrs)`:
```scheme
  (import
    (rnrs)
    (byte-machine test fingerprint)
    (only (rnrs r5rs) modulo quotient remainder)
    (only (chezscheme)
          include machine-type scheme-version getenv
          with-output-to-string display-condition))
```
The export list is untouched — the four `harness-fingerprint-*` names it already exports are now satisfied by re-export instead of by included definitions.
2. Replace the two lines
```scheme
  (include "fingerprint.scm")
  (include "harness-runner.scm"))
```
with
```scheme
  (include "harness-runner.scm"))
```
3. In the `;; --- shared bodies ---` section comment directly above, change `Nothing below this point is Chez-specific.` context to name one body: replace the comment block with
```scheme
  ;; --- shared body ---------------------------------------------------------
  ;;
  ;; The runner body, included by bare filename until Task 4 of the include
  ;; collapse inlines it here. The fingerprint algorithm formerly included
  ;; beside it is now imported: (byte-machine test fingerprint).
```

- [ ] **Step 3: Rewrite the manifest launcher**

Replace the entire contents of `test/support/launchers/fingerprint-manifest.ss` with:

```scheme
;;; Compute the expected combined fingerprint of a manifest, at build time.
;;;
;;; Usage:
;;;   fingerprint-manifest.ss <library-root> <object-guard> <output> <body>...
;;;
;;; A lane prints the combined fingerprint of the sources it executed. Until
;;; something reads that value back it is a claim, not a check: two lanes can
;;; print different digests for text both say they ran, and a suite that only
;;; prints stays green. This produces the value each lane must agree with,
;;; computed by the build from the repository sources before anything is
;;; compiled from them.
;;;
;;; THE ALGORITHM IS NOT REIMPLEMENTED HERE
;;;
;;; (byte-machine test fingerprint) is imported -- the same library the
;;; harness re-exports to every lane -- so this program and the runner cannot
;;; drift apart. The import mechanism (library-directories set first, import
;;; mid-file under --script) is measured in decision 0006. The root is paired
;;; with the always-empty object guard for the same reason chez-source.ss
;;; pairs its roots: the expectation must be computed from source text, and a
;;; compiled object beside the source must have nowhere to load from.

;;; Status 2 is the harness's "harness, configuration, or registration error",
;;; the same meaning the Chez source launcher gives it.
(define (die message)
  (display "byte-machine-fingerprint: HARNESS-ERROR " (current-error-port))
  (display message (current-error-port))
  (newline (current-error-port))
  (exit 2))

(define args (command-line-arguments))

(if (< (length args) 4)
    (die "usage: fingerprint-manifest.ss <library-root> <object-guard> <output> <body>..."))

(define library-root (list-ref args 0))
(define object-guard-dir (list-ref args 1))
(define output (list-ref args 2))
(define bodies (list-tail args 3))

(if (not (file-directory? object-guard-dir))
    (die (string-append "object guard directory does not exist: " object-guard-dir)))

;; Asserted, not assumed, exactly as the launchers assert it: a guard
;; directory that has acquired a file is no longer a guard, and the
;; expectation would be computed from whatever was put there.
(if (not (null? (directory-list object-guard-dir)))
    (die (string-append "object guard directory must be empty but is not: "
                        object-guard-dir)))

(for-each
 (lambda (body)
   (if (not (file-exists? body))
       (die (string-append "manifest body does not exist: " body))))
 bodies)

(compile-imported-libraries #f)
(source-directories '())
(library-directories (list (cons library-root object-guard-dir)))

(import (byte-machine test fingerprint))

(define combined
  (harness-fingerprint->string
   (harness-fingerprint-combine (map harness-fingerprint-file bodies))))

;; No trailing newline. The reader trims whitespace anyway, but writing exactly
;; the value keeps the file's bytes equal to the string it represents.
(let ((port (open-file-output-port output (file-options no-fail))))
  (put-bytevector port (string->utf8 combined))
  (close-port port))

(display "byte-machine-fingerprint: ")
(display combined)
(newline)
(exit 0)
```

- [ ] **Step 4: Rewire `test/CMakeLists.txt`**

1. `BYTE_MACHINE_HARNESS_MANIFEST` becomes:
```cmake
set(BYTE_MACHINE_HARNESS_MANIFEST
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/fingerprint.sls"
    "${BYTE_MACHINE_HARNESS_SHARED_DIR}/harness-runner.scm")
```
2. In `byte_machine_expected_fingerprint`, the custom command's launcher invocation and DEPENDS change from the shared-dir contract to the library contract:
```cmake
      COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" --script
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}"
              "${BYTE_MACHINE_HARNESS_OBJECT_GUARD_DIR}"
              "${expect_file}"
              ${ARGN}
      DEPENDS ${ARGN}
              "${BYTE_MACHINE_FINGERPRINT_LAUNCHER}"
              "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/fingerprint.sls"
```
(The explicit DEPENDS entry keeps every expectation refreshing when the algorithm changes, whether or not a manifest lists it — same reasoning as before, new path.)
3. Delete the two cwd-matrix `configure_file` lines that copy `fingerprint.scm` into the identical and decoy directories (the matrix rule is "every body the lane *includes*", and the fingerprint is no longer included).

- [ ] **Step 5: Retarget `SchemeMutationSuite.cmake`**

1. `set(FINGERPRINT test/support/harness/shared/fingerprint.scm)` → `set(FINGERPRINT test/support/harness/chez/byte-machine/test/fingerprint.sls)`. The five pass-24 FIND/REPLACE pairs and the hex pass are untouched (the body text is verbatim).
2. In the provenance passes (26–29), every `BYTE_MACHINE_FINGERPRINT_FILES=${STAGE_DIR}/test/support/harness/shared/fingerprint.scm` becomes `…=${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls`.
3. Pass 28's `CORRECT_FP_FILE` computation changes to the new launcher contract:
```cmake
execute_process(
  COMMAND "${BYTE_MACHINE_CHEZ_EXECUTABLE}" "--script"
          "${STAGE_DIR}/test/support/launchers/fingerprint-manifest.ss"
          "${STAGE_DIR}/test/support/harness/chez"
          "${GUARD_DIR}"
          "${CORRECT_FP_FILE}"
          "${STAGE_DIR}/test/support/harness/chez/byte-machine/test/fingerprint.sls"
  RESULT_VARIABLE fp_rc
  OUTPUT_VARIABLE fp_out
  ERROR_VARIABLE fp_err)
```
4. The library-directories poison pass compiles a copy of `harness.sls`, which now imports the fingerprint library. **Superseded as measured during Task 3** — the shape first planned here (fingerprint resolvable as source via a second root) leaves the mutation UNCAUGHT: Chez's staleness check on a compiled library is transitive, so a harness object whose fingerprint import resolves only to bare source is silently discarded in favour of the pristine harness source, and the baseline banner prints under the mutant too. What landed instead, recorded in the block's own comments: a pristine `fingerprint.sls` is copied into `POISON_ROOT` by the same `file(READ)`/`file(WRITE)` discipline as the harness copy, the compile script compiles it to `fingerprint.so` **first** (into `POISON_ROOT` itself), then compiles the poisoned harness; both objects are `file(TOUCH)`ed fingerprint-first; the compile-failure guard checks both objects exist; no second `--library-root` is added to the verify command (measured inert — `POISON_ROOT` alone resolves both libraries in both runs).

- [ ] **Step 6: Suite**

```bash
make test-all
```
Expected: 37/37 green; the scheme-mutation lane reports `29 passes, 65 mutations`; the fingerprint expectation files rebuild (the build log shows the `byte-machine: fingerprint manifest` custom commands re-running).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: the fingerprint body becomes a library with two importers"
```

---

### Task 4: The harness collapse and the root move

The runner inlines into `(byte-machine test harness)`; `shared/` and the `chez/` root segment go (§5.2, §12 phase 3). The harness library joins its lanes' manifests — from here, harness-lane manifests are exactly the two `.sls` files.

**Files:**
- Modify: `test/support/harness/chez/byte-machine/test/harness.sls` (then `git mv` the tree up), `test/CMakeLists.txt`, `cmake/ByteMachineSchemeLane.cmake`, `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, `test/support/cmake/SchemeMutationSuite.cmake`
- Delete: `test/support/harness/shared/harness-runner.scm`, `test/support/harness/shared/`, the `test/support/harness/chez/` directory level

**Interfaces:**
- Produces: harness library root `test/support/harness/` (value of the unchanged variable `BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT`); harness manifest = `fingerprint.sls` + `harness.sls`.

- [ ] **Step 1: Inline the runner**

In `harness.sls`, replace the final line `  (include "harness-runner.scm"))` and the `;; --- shared body ---` comment block above it (added in Task 3) with: the entire text of `test/support/harness/shared/harness-runner.scm` **verbatim at column 0**, followed by a closing `)` on its own final line — with one edit to the runner text as it lands: replace its header (the lines from `;;; byte-machine private portable test runner.` through the paragraph ending `…not because a rule still requires it (AGENTS.md; decision 0005).`, keeping the `PROCESS STATUS` section and everything after it) with:

```scheme
;; ---------------------------------------------------------------------------
;; The runner. Inlined here by the include collapse (decision 0006); formerly
;; test/support/harness/shared/harness-runner.scm, this library's sole
;; included body. Everything below stays plain R6RS out of habit and
;; stability, not law: records as tagged lists, no hash tables, no
;; define-record-type -- nothing has needed to change since the portability
;; era. Free identifiers used below and defined above (the adapter
;; procedures) or imported (the fingerprint library, r5rs arithmetic) are
;; bound by this library; a name bound nowhere kills the library at import.
;;
;; PROCESS STATUS (spec section 5.2)
;;
;;   0  every selected case passed
;;   1  one or more assertions failed
;;   2  harness, configuration, or registration error
;;   3  reserved: the run could not confirm it executed the intended text
;;
;; Status is computed once, at the end, rather than chosen at each throw site,
;; so a new error path cannot forget to change it.
```

Then delete the now-empty include: remove `include` from the `(only (chezscheme) …)` import (it becomes `(only (chezscheme) machine-type scheme-version getenv with-output-to-string display-condition)`), and delete `test/support/harness/shared/harness-runner.scm` and the `shared/` directory:
```bash
git rm test/support/harness/shared/harness-runner.scm
rmdir test/support/harness/shared 2>/dev/null || true
```

- [ ] **Step 2: Move the root up**

```bash
git mv test/support/harness/chez/byte-machine test/support/harness/byte-machine
rmdir test/support/harness/chez
```

- [ ] **Step 3: Rewire `test/CMakeLists.txt`**

1. `set(BYTE_MACHINE_HARNESS_SHARED_DIR …)` — delete the line (its directory is gone). Where refusal-lane COMMAND blocks pass `"--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"`, substitute the still-existing self directory — the flag is still required until Task 8 and its value is inert (nothing resolves through it): `"--source-dir" "${BYTE_MACHINE_HARNESS_SELF_DIR}"`.
2. `set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}/chez")` → `set(BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT "${BYTE_MACHINE_HARNESS_DIR}")`.
3. `BYTE_MACHINE_HARNESS_MANIFEST` becomes the two libraries — the harness's own text joins the fingerprint (§6: every byte the lane runs):
```cmake
set(BYTE_MACHINE_HARNESS_MANIFEST
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/fingerprint.sls"
    "${BYTE_MACHINE_HARNESS_CHEZ_LIBRARY_ROOT}/byte-machine/test/harness.sls")
```
4. The expected-fingerprint DEPENDS entry and manifest paths from Task 3 pick the move up automatically through the variable; confirm with `rg -n 'harness/chez' test/CMakeLists.txt` → expected: no hits.
5. In the portability-guard call, drop the shared dir: `SHARED_DIRS "${BYTE_MACHINE_HARNESS_SHARED_DIR}" "${BYTE_MACHINE_SRC_COMMON_DIR}"` → `SHARED_DIRS "${BYTE_MACHINE_SRC_COMMON_DIR}"`.
6. Delete the two cwd-matrix `configure_file` lines copying `harness-runner.scm` (identical + decoy). The matrix directories now hold only the placeholder body and impostor.

- [ ] **Step 4: The lane command loses the harness `--source-dir`**

In `cmake/ByteMachineSchemeLane.cmake`'s source branch, delete the line `"--source-dir" "${BYTE_MACHINE_HARNESS_SHARED_DIR}"` (the `"--source-dir" "${BYTE_MACHINE_SRC_COMMON_DIR}"` emission stays until Task 6). In `ByteMachineSchemeLaneSpec.cmake`: delete the fixture line `set(BYTE_MACHINE_HARNESS_SHARED_DIR "/h/shared")`, and update the expected command string to:
```cmake
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;--library-root;/h/chez;--library-root;/s/chez;--source-dir;/s/common/byte-machine;--object-guard;/b/guard;--program;/h/self/p.chez.sps"
  "chez lane command line")
```

- [ ] **Step 5: Retarget `SchemeMutationSuite.cmake`**

1. Path variables:
```cmake
set(RUNNER test/support/harness/byte-machine/test/harness.sls)
set(CHEZ_ADAPTER test/support/harness/byte-machine/test/harness.sls)
```
(and later `set(RUNNER_BODY …)` and `set(FINGERPRINT …)` to the same moved root: `test/support/harness/byte-machine/test/harness.sls` and `test/support/harness/byte-machine/test/fingerprint.sls`). Every runner FIND/REPLACE is unchanged — the text moved verbatim.
2. Every `--library-root "${STAGE_DIR}/test/support/harness/chez"` → `--library-root "${STAGE_DIR}/test/support/harness"` (all verify commands, including the poison pass's second root added in Task 3).
3. Every `--source-dir "${STAGE_DIR}/test/support/harness/shared"` → `--source-dir "${STAGE_DIR}/test/support/harness/self"` (required flag, inert value, same substitution rule as the registrations).
4. The poison block (whose shape now includes Task 3's measured transitive-staleness fix — a pristine `fingerprint.so` compiled into `POISON_ROOT` first): three path updates and one comment retirement.
   - The pristine-fingerprint copy: `file(READ "${SOURCE_ROOT}/test/support/harness/chez/byte-machine/test/fingerprint.sls" …)` → `…/test/support/harness/byte-machine/test/fingerprint.sls`.
   - In the compile script: delete the `(source-directories …)` line entirely (the library no longer includes anything) and move the library-directories root up:
```scheme
(library-directories (list (cons \"${SOURCE_ROOT}/test/support/harness\" \"${POISON_GUARD_DIR}\")))
```
   - In the transitive-staleness comment, the named compile-resolution path `${SOURCE_ROOT}/test/support/harness/chez` → `${SOURCE_ROOT}/test/support/harness`.
   - Delete the comment paragraph beginning `# There is a SECOND staleness input, and it is not local to this directory:` (the include re-resolution it documents no longer exists) and replace with:
```cmake
# The object is preferred only while it is not older than the .sls beside
# it -- and, transitively, while its imported fingerprint library also
# resolves to a non-stale object (the MEASURED note below). What died with
# the include (decision 0006) is the include-era caveat this paragraph used
# to carry: no STAGED file's mtime participates any more, because the
# library no longer re-resolves harness-runner.scm at load time.
```
5. The two adapter export-list mutations and the `EXPECT_SURVIVES` note about names "referenced only from harness-runner.scm, which `include` splices into the library body" — the mechanism changed (same file now), so update that survivor's reason text to:
```
"harness-summary, harness-empty-selection-error, and harness-failure-context are referenced only from the runner section of harness.sls itself; an internal reference resolves inside the library whatever the export list says, so no lane imports the three and none can notice one going missing"
```

- [ ] **Step 6: Suite and lane count**

```bash
make test-all
ctest --preset release -N | tail -1
```
Expected: 37/37 green; `Total Tests: 37`; scheme-mutation lane reports `29 passes, 65 mutations`. Also confirm nothing resolves the old paths:
```bash
rg -n 'harness/shared|harness/chez' cmake test src CMakeLists.txt --glob '!*.md'
```
Expected: exactly one hit — `harness.sls`'s own header prose `formerly test/support/harness/shared/harness-runner.scm`, a historical citation this task's step 1 mandates, not a live path. (Corrected after Task 4 landed: the gate as first written said "no hits" and conflicted with the header text it mandates.)

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: the runner lives in its library, and the harness root loses its chez segment"
```

---

### Task 5: The per-lane basename check replaces the guard

The repository-wide guard's one remaining rule narrows to the registrar (§8.2); then the guard module, its spec, its lane, its call, and its twelve MutationSuite declarations are deleted (§9.2). Spec first, then the check, then the deletion.

**Files:**
- Modify: `cmake/ByteMachineSchemeLane.cmake`, `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, `test/support/cmake/MutationSuite.cmake`, `test/CMakeLists.txt`, `CMakeLists.txt`
- Delete: `cmake/ByteMachinePortabilityGuard.cmake`, `test/support/cmake/ByteMachinePortabilityGuardSpec.cmake`

**Interfaces:**
- Produces: `byte_machine_lane_duplicate_basenames(<out_var> <path>...)` in ByteMachineSchemeLane.cmake's functional core (pure; returns repeated basenames, each once); a configure-time refusal in `byte_machine_add_scheme_lane` whose message begins `declares two sources sharing a basename`.

- [ ] **Step 1: The failing spec cases first**

In `ByteMachineSchemeLaneSpec.cmake`, add a rejection case to the `BYTE_MACHINE_SPEC_CASE` dispatch (after `lane-rejects-missing-shared-body`):
```cmake
  elseif(c STREQUAL "lane-rejects-duplicate-source-basename")
    byte_machine_add_scheme_lane(
      NAME byte-machine.harness.example.chez.source
      BACKEND chez
      PROGRAM "${SPEC_SELF}"
      SHARED_BODIES "${SPEC_SELF}" "${SPEC_SELF}"
      TIMEOUT 10)
```
add the matching line to `spec_expect_all_rejected` (after the missing-shared-body entry):
```cmake
  "lane-rejects-duplicate-source-basename|declares two sources sharing a basename"
```
and add pure-function assertions after the `byte_machine_scheme_lane_command` block (before `# --- Rejections`):
```cmake
# Within one lane, measured copies are keyed by basename in a flat
# fingerprint/ directory, so a manifest carrying two entries with one
# basename would let one silently overwrite the other. The pure detector is
# asserted directly; the registrar's refusal is a rejection case below.
byte_machine_lane_duplicate_basenames(dups "/a/x.sls" "/b/y.sls")
spec_check_equal("${dups}" "" "distinct basenames report no duplicates")
byte_machine_lane_duplicate_basenames(dups "/a/x.sls" "/b/x.sls" "/c/x.sls" "/d/y.sls")
spec_check_equal("${dups}" "x.sls" "a repeated basename is reported once, however often it repeats")
```

- [ ] **Step 2: Run the spec — it must fail**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```
Expected: FAIL — `byte_machine_lane_duplicate_basenames` is not defined (and the rejection case, run via the sweep, is "accepted but must be rejected").

- [ ] **Step 3: Implement**

In `cmake/ByteMachineSchemeLane.cmake`, functional core section, after `byte_machine_lane_measured_copies`:
```cmake
# byte_machine_lane_duplicate_basenames(<out_duplicates> <path>...)
#
# Basenames appearing more than once, each reported once however often they
# repeat. Narrowed from the retired repository-wide guard (decision 0006) to
# the one invariant that survives it: byte_machine_lane_measured_copies keys
# a compiled lane's fingerprint/ copies by basename, so within one lane's
# manifest a repeated basename would make one copy silently overwrite the
# other. Compared with the extension, because the extension is part of the
# copied filename.
function(byte_machine_lane_duplicate_basenames out_duplicates)
  set(seen "")
  set(duplicates "")
  foreach(path IN LISTS ARGN)
    get_filename_component(base "${path}" NAME)
    if(base IN_LIST seen)
      list(APPEND duplicates "${base}")
    endif()
    list(APPEND seen "${base}")
  endforeach()
  if(duplicates)
    list(REMOVE_DUPLICATES duplicates)
  endif()
  set(${out_duplicates} "${duplicates}" PARENT_SCOPE)
endfunction()
```
In `byte_machine_add_scheme_lane`, directly after the SHARED_BODIES existence loop:
```cmake
  # Within one lane's manifest, basenames must be unique: the flat
  # fingerprint/ copy directory of the aot branch keys measured copies by
  # basename. This replaced the repository-wide basename guard when the
  # include namespace it policed retired (decision 0006).
  byte_machine_lane_duplicate_basenames(duplicate_basenames ${arg_SHARED_BODIES})
  if(duplicate_basenames)
    message(FATAL_ERROR
      "byte-machine: '${arg_NAME}' declares two sources sharing a basename: "
      "${duplicate_basenames}. byte_machine_lane_measured_copies keys a "
      "compiled lane's fingerprint/ copies by basename, so one would "
      "silently overwrite the other.")
  endif()
```
In `byte_machine_lane_measured_copies`'s header comment, replace the sentence citing the guard (`which is unambiguous because byte_machine_guard_duplicate_basenames forbids two shared bodies sharing one repository-wide`) with `which is unambiguous because byte_machine_add_scheme_lane refuses a manifest carrying two entries with one basename`.

- [ ] **Step 4: Spec green; add the two mutations**

```bash
cmake -P test/support/cmake/ByteMachineSchemeLaneSpec.cmake
```
Expected: PASS (`byte-machine-spec: ByteMachineSchemeLane verified` banner). Then in `MutationSuite.cmake`, at the end of the `# --- ByteMachineSchemeLane` section:
```cmake
byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a repeated basename is not detected"
  FIND [[    if(base IN_LIST seen)]]
  REPLACE [[    if(FALSE)]])

byte_machine_mutation(
  FILE cmake/ByteMachineSchemeLane.cmake SPEC ByteMachineSchemeLaneSpec.cmake
  LABEL "scheme-lane: a duplicate-basename manifest is registered anyway"
  FIND [[  if(duplicate_basenames)]]
  REPLACE [[  if(FALSE)]])
```

- [ ] **Step 5: Delete the guard**

```bash
git rm cmake/ByteMachinePortabilityGuard.cmake test/support/cmake/ByteMachinePortabilityGuardSpec.cmake
```
1. `CMakeLists.txt`: delete `include(ByteMachinePortabilityGuard)`.
2. `test/CMakeLists.txt`: delete the `byte_machine_portability_guard(…)` call, the comment block above it (`# src/common holds bodies included by a library; …`), and the `byte-machine.harness.cmake-portability-guard.cmake.direct` registration.
3. `MutationSuite.cmake`: delete the entire `# --- ByteMachinePortabilityGuard ---` section — exactly 12 `byte_machine_mutation(` declarations (verify: `rg -c 'byte_machine_mutation\(' test/support/cmake/MutationSuite.cmake` drops from 77 matches to 65, two of which are comment mentions, leaving 63 + the 2 added in step 4 = 65 real). Set `set(EXPECTED_MUTATIONS 75)` → `set(EXPECTED_MUTATIONS 65)`. In the header narrative, after the "Seventy-five is ninety-four minus twenty plus one" paragraph, add:
```cmake
# Sixty-five is seventy-five minus twelve plus two: the include collapse
# (decision 0006) deleted ByteMachinePortabilityGuard.cmake whole -- its
# twelve mutations tested a repository-wide basename namespace that no
# longer exists once nothing resolves includes through source-directories --
# and added two for the invariant that survives it, narrowed to one lane:
# byte_machine_lane_duplicate_basenames and the registrar refusal it feeds.
```
Also update the header's guard-history paragraph reference (the "Ninety-four is ninety-seven minus three" paragraph stays — it is history). Sanity-check the declaration count: `rg -c 'byte_machine_mutation\(' test/support/cmake/MutationSuite.cmake` goes 77 → 68 — two of the matches are comment mentions of `byte_machine_mutation()`, so 66 real declarations remain (75 − 12 + 3: eleven guard mutations die with their namespace, the accumulator-initialization hazard moves with the function body into the SchemeLane section alongside the two new lane-check mutations, and the spec gains an ambient-seeding assertion to witness it — corrected after Task 5's review found the twelfth mutation's subject line surviving unguarded), which is what the totals gate enforces.

- [ ] **Step 6: Suite, fresh (configure inputs changed)**

```bash
make clean && make test-all
ctest --preset release -N | tail -1
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure --no-tests=error
```
Expected: 36/36 release green (`Total Tests: 36`); cmake-mutation lane reports `1 pass, 66 mutations`; no-scheme runs 8/8 green. Also:
```bash
rg -n 'PortabilityGuard|portability_guard|byte_machine_guard' cmake test CMakeLists.txt
```
Expected: hits only in `MutationSuite.cmake`'s header prose — the Task 2 history paragraphs and this task's own narrative — never an include, a call, or a declaration. (Corrected after Task 5 landed: "no hits" conflicted with the narrative text this task's own step 5 mandates.)

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: basename uniqueness narrows to the lane, and the guard goes"
```

---

### Task 6: The src collapse, the matrix retirement, and the ownership rewrite

The product libraries absorb their bodies (§5.3), the working-directory matrix retires with its subject (§9.1), and the one-owner passes give way to the inline-duplication mutation (§9.2).

**Files:**
- Create (via `git mv`): `src/byte-machine/placeholder.sls`, `src/byte-machine/placeholder-consumer.sls`
- Modify: `test/CMakeLists.txt`, `cmake/ByteMachineSchemeLane.cmake`, `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, `test/support/cmake/SchemeMutationSuite.cmake`
- Delete: `src/common/`, `src/chez/`

**Interfaces:**
- Produces: `(byte-machine placeholder)` and `(byte-machine placeholder-consumer)` at library root `src/` (unchanged exports); one lane `byte-machine.portability.placeholder.chez.source` replacing the three cwd lanes.

- [ ] **Step 1: Move the bodies, wrap them as libraries**

```bash
git mv src/common/byte-machine/placeholder.scm src/byte-machine/placeholder.sls
git mv src/common/byte-machine/placeholder-consumer.scm src/byte-machine/placeholder-consumer.sls
git rm src/chez/byte-machine/placeholder.sls src/chez/byte-machine/placeholder-consumer.sls
```
(That `git rm` deletes the two thin owner wrappers; their entire content — a library form and an include — is reproduced inline below.)

Edit `src/byte-machine/placeholder.sls`: replace the header's first two paragraphs (from `;;; Placeholder body for the Milestone 0 portability proof.` through the paragraph ending `…(decisions 0002/0003).`) with:
```scheme
;;; Placeholder library for the Milestone 0 portability proof.
;;;
;;; Inline R6RS (decision 0006): the library owns its own text; nothing is
;;; included.
```
Keep the rest of the header verbatim (the Milestone-1 deletion note and the TAG AND MARKER rationale — both are about representation, not about includes — but rewrite the sentence `It exists to prove that the include mechanism loads a body through its owner wrapper, and to give slice 4 a value whose identity can be compared across a library boundary.` to `It exists to give the lanes a value whose identity can be compared across a library boundary.`, and in the tag rationale replace `two libraries that had each included this body` with `two libraries that had each carried a copy of these definitions` and `A freshly allocated vector gives a second include a second tag` with `A freshly allocated vector gives a second copy a second tag`). Then insert after the header, before `(define placeholder-tag …)`:
```scheme
(library (byte-machine placeholder)
  (export make-placeholder placeholder? placeholder-value placeholder-marker)
  (import (rnrs))
```
and append a final line:
```scheme
)
```
All defines stay verbatim at column 0.

Edit `src/byte-machine/placeholder-consumer.sls` the same way: replace the header's first two paragraphs with:
```scheme
;;; Consumer library for the Milestone 0 cross-library identity proof.
;;;
;;; Inline R6RS (decision 0006): the library owns its own text; nothing is
;;; included.
```
rewrite the free-identifier paragraph (from `;;; EVERY IDENTIFIER THIS BODY USES…` through `…every lane that imports only the owner still passes.`) as:
```scheme
;;; placeholder?, placeholder-value and placeholder-marker come from this
;;; library's import of (byte-machine placeholder) -- imported, never copied.
;;; Redefining them here inline is the surviving form of the ownership
;;; defect decisions 0002/0003 guarded in the include era: the consumer
;;; would carry its own tag and its own marker, both identity cases would
;;; answer wrongly, nothing would raise, and every lane that imports only
;;; the owner would still pass. SchemeMutationSuite.cmake makes exactly that
;;; edit and requires the identity lane to fail.
```
keep the Milestone-1 paragraphs and the reject-branch rationale verbatim, and wrap:
```scheme
(library (byte-machine placeholder-consumer)
  (export consume)
  (import (rnrs) (byte-machine placeholder))
```
…body verbatim…
```scheme
)
```

- [ ] **Step 2: Rewire `test/CMakeLists.txt`**

1. `set(BYTE_MACHINE_SRC_COMMON_DIR …)` — delete. `set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src/chez")` → `set(BYTE_MACHINE_SRC_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src")` (variable name kept; only the value loses its segment).
2. Delete the whole working-directory-matrix block: the `BYTE_MACHINE_CWD_MATRIX_DIR`/`…IDENTICAL…`/`…DECOY…`/`…EMPTY…` sets and `file(MAKE_DIRECTORY)` calls, the remaining `configure_file` lines (placeholder.scm), the impostor `file(WRITE …)`, and the matrix comment block.
3. Replace the three-lane `foreach(cwd_case …)` registration with one lane:
```cmake
# --- The placeholder library -------------------------------------------------
#
# One lane, launched from the default private directory like every other
# lane. The three-directory working-directory matrix retired with the include
# mechanism (decision 0006): with absolute library roots and an empty
# source-directories there is nothing left for a launch directory to change,
# so cwd-independence is structural rather than empirical.
byte_machine_add_scheme_lane(
  NAME byte-machine.portability.placeholder.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.chez.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${CMAKE_SOURCE_DIR}/src/byte-machine/placeholder.sls"
                "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-tests.scm"
  TIMEOUT 120)
```
4. The identity lane's SHARED_BODIES becomes:
```cmake
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${CMAKE_SOURCE_DIR}/src/byte-machine/placeholder.sls"
                "${CMAKE_SOURCE_DIR}/src/byte-machine/placeholder-consumer.sls"
                "${BYTE_MACHINE_TEST_COMMON_DIR}/placeholder-identity-tests.scm"
```
5. The scheme-mutation registration drops its matrix argument: delete the line `"-DBYTE_MACHINE_CWD_MATRIX_DIR=${BYTE_MACHINE_CWD_MATRIX_DIR}"`.
6. Two comment sites outside this file justify themselves by the matrix and go stale with it. In `cmake/ByteMachineTesting.cmake`: in `byte_machine_test_run_directory`'s header, replace `A lane that overrides this is making a claim about where resolution happens, which is what the working-directory matrix in test/CMakeLists.txt exists to check.` with `A lane that overrides this is making a claim about where it must launch from; none currently does (the include-era working-directory matrix retired with decision 0006), and the never-from-the-repository default stays because it costs nothing and forecloses a class of accident.` — and in `byte_machine_add_test`'s header, replace the sentence beginning `That is not tidiness: Chez resolves \`include\` against the process working directory…` through `…stopped being staged correctly.` with `That is not tidiness: it is what keeps a test's outcome independent of where the developer happened to stand, and it predates — and outlives — the include mechanism whose working-directory hazards first forced it (decision 0006).` In `test/support/cmake/MutationSuite.cmake`, the comment above the three run-directory mutations (`The run directory is where slice 3's working-directory matrix hangs…`) becomes `The run directory decides where every lane launches from; the three decisions inside byte_machine_test_run_directory each get their own mutation. (The include-era matrix that first hung off this function is gone — decision 0006 — but an override that silently stops arriving, or arrives empty, still launches lanes from the wrong place.)`

- [ ] **Step 3: The lane command's remaining `--source-dir`**

In `cmake/ByteMachineSchemeLane.cmake`'s source branch, the `"--source-dir" "${BYTE_MACHINE_SRC_COMMON_DIR}"` line becomes `"--source-dir" "${BYTE_MACHINE_TEST_COMMON_DIR}"` with the comment:
```cmake
        # Transitional: --source-dir is still a required launcher flag until
        # the flag itself retires (include-collapse Task 8). Program bodies
        # resolve through the program's own directory, so this value is
        # inert; it names a real directory only so the invocation stays
        # honest about what exists.
```
In `ByteMachineSchemeLaneSpec.cmake`: add `set(BYTE_MACHINE_TEST_COMMON_DIR "/t/common")` beside the other fixture roots, and update the expected command string's `--source-dir;/s/common/byte-machine` to `--source-dir;/t/common`.

- [ ] **Step 4: `SchemeMutationSuite.cmake` — matrix out, ownership rewritten, paths retargeted**

1. Delete the whole `# --- Passes 19 to 21: the working-directory matrix` section: the `BYTE_MACHINE_CWD_MATRIX_DIR` FATAL_ERROR check, `CWD_MUTATION_FIND`/`REPLACE`, the `foreach(cwd_case …)` loop, and the trailing `set(BYTE_MACHINE_MUTATION_VERIFY_WORKING_DIRECTORY "")` reset (nothing after it sets a working directory).
2. Path retargets: `set(PLACEHOLDER_BODY src/common/byte-machine/placeholder.scm)` → `set(PLACEHOLDER_BODY src/byte-machine/placeholder.sls)`; `set(CONSUMER_BODY src/common/byte-machine/placeholder-consumer.scm)` → `set(CONSUMER_BODY src/byte-machine/placeholder-consumer.sls)`; delete `set(CHEZ_CONSUMER_WRAPPER src/chez/byte-machine/placeholder-consumer.sls)` (the wrapper is gone; the ownership mutation now targets `${CONSUMER_BODY}`).
3. In every verify command: `--library-root "${STAGE_DIR}/src/chez"` → `--library-root "${STAGE_DIR}/src"`; `--source-dir "${STAGE_DIR}/src/common/byte-machine"` → delete the pair (each of those commands already carries one `--source-dir` pointing at harness/self, which satisfies the required flag).
4. `set(BYTE_MACHINE_MUTATION_STAGE_DIRS …)` keeps `"src"` (now the inline libraries) — no change needed; confirm the list still stages every directory a verify command references.
5. Pass 22 (consumer body decisions): FIND/REPLACE text unchanged; FILE is now the `.sls`.
6. Replace pass 23's declaration (the ownership mutation) with the inline-duplication form:
```cmake
# --- The ownership pass: a consumer that copies instead of importing --------
#
# Decisions 0002/0003's one-owner rule is unconstructible against the inline
# tree -- there is no include form and no body file for a second owner to
# include. The defect class survives inlining, because copy-paste can
# reintroduce it: a consumer that defines its own copies of the owner's
# procedures carries its own tag and its own marker, both identity cases
# answer wrongly, nothing raises, and every lane that imports only the owner
# still passes. This is 0003's silent-defect measurement reconstructed for
# the inline world (decision 0006, decision 5).

byte_machine_mutation_reset()

set(BYTE_MACHINE_MUTATION_VERIFY_COMMAND
  "${BYTE_MACHINE_CHEZ_EXECUTABLE}"
  "--script" "${STAGE_DIR}/test/support/launchers/chez-source.ss"
  "--library-root" "${STAGE_DIR}/test/support/harness"
  "--library-root" "${STAGE_DIR}/src"
  "--source-dir" "${STAGE_DIR}/test/support/harness/self"
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/common/placeholder-identity-tests.chez.sps")

byte_machine_mutation(
  FILE ${CONSUMER_BODY} SPEC placeholder-identity-tests.chez.sps
  LABEL "consumer library: inlines duplicate definitions instead of importing the owner"
  FIND [[  (import (rnrs) (byte-machine placeholder))]]
  REPLACE [[  (import (rnrs))
  (define placeholder-tag (vector 'byte-machine-placeholder))
  (define placeholder-marker-object (vector 'byte-machine-marker))
  (define (make-placeholder value) (vector placeholder-tag value))
  (define (placeholder? x)
    (and (vector? x)
         (= (vector-length x) 2)
         (eq? (vector-ref x 0) placeholder-tag)))
  (define (placeholder-value p) (vector-ref p 1))
  (define (placeholder-marker) placeholder-marker-object)]])

byte_machine_mutation_run("${SOURCE_ROOT}" "${STAGE_DIR}")
```
7. Header renumbering: `set(EXPECTED_PASSES 29)` → `26`, `set(EXPECTED_MUTATIONS 65)` → `62`. Rewrite the header title line to `# TWENTY-SIX PASSES, BECAUSE TWENTY-SIX DIFFERENT WITNESSES ARE NEEDED`, delete the `# Passes 19 to 21 are the working-directory matrix…` paragraph and replace it with:
```cmake
# The three working-directory-matrix passes that used to sit between the
# parse decisions and the consumer pass retired with the include mechanism
# (decision 0006): with library roots absolute and source-directories empty,
# there is no resolution step left for a launch directory to change, so the
# claim the matrix witnessed empirically is now structural.
```
and renumber the following paragraphs and section banners: consumer body 22→19, ownership 23→20, fingerprint 24→21, hex 25→22, provenance 26–29→23–26 (update both the header enumeration and each `# --- Pass N` banner, plus the cross-references inside the pass-26/28 comments — `pass 28` becomes `pass 25`, `passes 26 through 29` becomes `passes 23 through 26`, and pass 22's `Same argument as pass 8` stays).

- [ ] **Step 5: Suite, fresh**

```bash
make clean && make test-all
ctest --preset release -N | tail -1
```
Expected: 34/34 green (`Total Tests: 34` — the three cwd lanes became one); scheme-mutation lane reports `26 passes, 62 mutations`, and the new ownership mutation is reported caught with the identity lane failing at status 1. Confirm the old paths are gone:
```bash
rg -n 'src/common|src/chez|cwd-matrix|CWD_MATRIX|same-name-' cmake test src CMakeLists.txt --glob '!*.md'
```
Expected: no hits.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: the product libraries own their text; the cwd matrix and one-owner rule retire"
```

---

### Task 7: The program merges

Eight `.chez.sps`/`.scm` pairs become eight plain `.sps` programs (§6). Each merged program joins its lane's manifest — from here, every byte of Scheme a lane runs is fingerprinted.

**Files:**
- Modify (via `git mv` of the body + edit): `test/support/harness/self/harness-{bootstrap,failing,self-tests,duplicate-case,empty-selection,unreached-provenance}.sps`, `test/common/placeholder{-tests,-identity-tests}.sps`
- Modify: `test/CMakeLists.txt`, `test/support/cmake/SchemeMutationSuite.cmake`, `cmake/ByteMachineSchemeLane.cmake` (one comment)
- Delete: the eight `.chez.sps` wrappers (content absorbed)

**Interfaces:**
- Produces: program paths `…/<name>.sps`; every lane's manifest ends with its own program file.

- [ ] **Step 1: Merge, one pattern, eight files**

For each pair, the body file (the large one) is moved to the program name and the wrapper's frame is folded in; the wrapper is deleted. The recipe, shown for `harness-self-tests`:
```bash
git mv test/support/harness/self/harness-self-tests.scm test/support/harness/self/harness-self-tests.sps
git rm test/support/harness/self/harness-self-tests.chez.sps
```
Then edit `harness-self-tests.sps`: above the body's existing header comment, insert the program frame (the wrapper's imports minus `(only (chezscheme) include)`, and its `harness-begin`):
```scheme
;;; The runner's self-tests, as a program. Merged from its .chez.sps wrapper
;;; by the include collapse (decision 0006).

(import (rnrs) (byte-machine test harness))

(harness-begin "harness.self")
```
and append the wrapper's tail as the file's last line:
```scheme
(harness-finish)
```
Apply the same recipe to each file, carrying each wrapper's own `harness-begin` string and shape exactly:

| Program | `harness-begin` argument | Notes |
|---|---|---|
| `harness-failing.sps` | `"harness.failing"` | begin + finish |
| `harness-self-tests.sps` | `"harness.self"` | begin + finish |
| `harness-duplicate-case.sps` | `"harness.duplicate-case"` | begin + finish |
| `harness-empty-selection.sps` | `"harness.empty-selection"` | begin + finish |
| `harness-bootstrap.sps` | — | no begin, no finish (the bootstrap judges the runner without the suite lifecycle — keep its wrapper's comment saying so) |
| `harness-unreached-provenance.sps` | — | no begin, no finish (never calling harness-begin is the lane's whole point) |
| `placeholder-tests.sps` | `"portability.placeholder"` | imports add `(byte-machine placeholder)` |
| `placeholder-identity-tests.sps` | `"portability.placeholder-identity"` | imports add `(byte-machine placeholder)` and `(byte-machine placeholder-consumer)`; keep the wrapper's comment that both libraries are imported, never copied |

- [ ] **Step 2: Re-register**

In `test/CMakeLists.txt`, for every scheme-lane registration and every launcher-refusal command: `PROGRAM`/`--program` paths change `.chez.sps` → `.sps`, and each lane's `SHARED_BODIES` list gains its own program as the final entry, replacing the old body entry. Example (the self-tests lane):
```cmake
byte_machine_add_scheme_lane(
  NAME byte-machine.harness.self.chez.source
  BACKEND chez
  PROGRAM "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SHARED_BODIES ${BYTE_MACHINE_HARNESS_MANIFEST}
                "${BYTE_MACHINE_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120)
```
Apply to all: `failing-body`, `bootstrap`, `self`, `duplicate-case`, `empty-selection`, `verbose`, `placeholder` (program entry replaces `placeholder-tests.scm`), `placeholder-identity` (replaces `placeholder-identity-tests.scm`), `provenance`, `provenance-absent-expectation`, `provenance-missing-body`, `unreached-provenance` — and the ten launcher-refusal `--program` arguments.

- [ ] **Step 3: `SchemeMutationSuite.cmake` renames**

Every `--program "${STAGE_DIR}/…/<name>.chez.sps"` → `….sps`, and every `SPEC <name>.chez.sps` → `SPEC <name>.sps` (the launcher-refusal passes' SPEC values name registered lanes, which do not change). No FIND/REPLACE text changes; no totals change (`26 passes, 62 mutations`).

- [ ] **Step 4: The stem comment**

In `cmake/ByteMachineSchemeLane.cmake`'s `byte_machine_chez_aot_paths`, the `NAME_WLE, not NAME_WE` comment justified keeping a `.chez` segment that no longer exists. Replace that comment with:
```cmake
  # NAME_WLE strips one extension: harness-self-tests.sps yields
  # harness-self-tests. (The .chez filename infix this comment once preserved
  # retired with the merged wrappers -- decision 0006.)
```

- [ ] **Step 5: Suite and the manifest claim**

```bash
make test-all
```
Expected: 34/34 green; scheme-mutation `26 passes, 62 mutations`. Spot-check the strengthened manifest: pick the self lane's fingerprint environment out of the configure and confirm the program file is listed:
```bash
ctest --preset release -R 'byte-machine.harness.self.chez.source' --show-only=json-v1 | rg -o 'BYTE_MACHINE_FINGERPRINT_FILES=[^"]*'
```
Expected: three `|`-separated entries ending in `fingerprint.sls`, `harness.sls`, `harness-self-tests.sps`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: eight program pairs merge, and the program text joins the fingerprint"
```

---

### Task 8: The launchers lose `--source-dir`

`chez-source.ss` and `chez-compile.ss` drop the flag and set `(source-directories '())` (§7); the lane command stops emitting it; the refusal-lane inventory and the mutation suite follow (§9).

**Files:**
- Modify: `test/support/launchers/chez-source.ss`, `test/support/launchers/chez-compile.ss`, `cmake/ByteMachineSchemeLane.cmake`, `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, `test/CMakeLists.txt`, `test/support/cmake/SchemeMutationSuite.cmake`

**Interfaces:**
- Produces: launcher flag vocabularies — `chez-source.ss`: `--library-root` (repeatable), `--object-guard`, `--program`; `chez-compile.ss`: `--library-root`/`--object-dir` (paired, repeatable), `--program`, `--output`.

- [ ] **Step 1: `chez-source.ss`**

1. Remove `"--source-dir"` from `known-flags`, `required-flags` (and its trailing-paren position note becomes `--library-root`'s: after this edit `--library-root` is the list's last entry — move the comment about the last entry's two closing parens to sit above `required-flags` unchanged in content, now naming `--library-root`).
2. Delete `(define source-dirs (flag-values "--source-dir"))`.
3. Replace
```scheme
;; A program may include bodies that live beside it, so its own directory joins
;; the declared source directories. All of them are explicit: nothing resolves
;; against the current working directory, which is what the working-directory
;; matrix in test/CMakeLists.txt exists to keep true.
(source-directories (append source-dirs (list (path-directory program))))
```
with
```scheme
;; Nothing includes, so nothing resolves through source-directories at all
;; (decision 0006; measured inert for the aot launcher as mutation C3b, and
;; extended here by the absence of any include form). Emptied rather than
;; left at Chez's CWD-containing default: it still narrows what a later
;; top-level load or include added to this file could reach, and an empty
;; list costs nothing to state.
(source-directories '())
```
4. Delete the now-unused `path-directory` definition (its only caller was the line above).
5. Header: in the `WHY FLAGS RATHER THAN POSITIONS` paragraph, drop `and one source directory per shared-body directory`; in `WHAT THIS LAUNCHER DELIBERATELY DOES NOT CHECK`, drop the `--source-dir` mentions (the paragraph now speaks of `--library-root` alone); update the usage comment to the three-flag form.

- [ ] **Step 2: `chez-compile.ss`**

Same flag-vocabulary removal (`known-flags`, `required-flags`, `(define source-dirs …)`), the same `(source-directories '())` replacement for its `(source-directories (append source-dirs (list (path-directory program))))` line, delete its `path-directory`, and update its usage header (four flags, `--library-root`/`--object-dir` pairing note unchanged).

- [ ] **Step 3: The flag-block rationale in the other two launchers**

`chez-aot.ss` and `chez-compile.ss` justify their duplicated flag blocks partly by the matrix: both headers say `this suite deliberately varies the working directory a lane is launched from (the matrix in test/CMakeLists.txt)`. The rationale's surviving half is real (a `load`-order dependency between launchers would be a new failure mode); the matrix half is gone. In **both** files, replace that sentence with `Chez's own defaults for both library-directories and source-directories are CWD-relative -- (("." . ".")) and (".") respectively, measured 2026-08-17 -- and a launcher must never inherit either, whatever directory a lane happens to launch from.` This is `chez-aot.ss`'s only edit in this slice — comments, not code; the design's "unchanged" holds for its mechanism.

- [ ] **Step 4: The lane command and its spec**

In `cmake/ByteMachineSchemeLane.cmake`'s source branch, delete the transitional `"--source-dir" "${BYTE_MACHINE_TEST_COMMON_DIR}"` emission and its comment (Task 6 step 3). In `ByteMachineSchemeLaneSpec.cmake`: delete `set(BYTE_MACHINE_TEST_COMMON_DIR "/t/common")` and update the expected command string to:
```cmake
spec_check_equal("${command}"
  "/opt/chez;--script;/h/launchers/chez-source.ss;--library-root;/h/chez;--library-root;/s/chez;--object-guard;/b/guard;--program;/h/self/p.chez.sps"
  "chez lane command line")
```

- [ ] **Step 5: The refusal-lane inventory**

In `test/CMakeLists.txt`:
1. Delete the `byte-machine.harness.launcher-no-source-dir.chez.source` registration (the flag it omits no longer exists).
2. Strip the `"--source-dir" "…"` argument pair from every remaining launcher-refusal command (`launcher-absent-guard`, `launcher-dirty-guard`, `launcher-unknown-flag`, `launcher-missing-value`, `launcher-repeated-flag`, `launcher-repeated-object-guard`, `launcher-no-library-root`, `launcher-no-object-guard`) and from the `chez-compile-launcher-unpaired-roots` command.

- [ ] **Step 6: `SchemeMutationSuite.cmake`**

1. Strip every `"--source-dir" "…"` pair from every verify command and from `LAUNCHER_BASE_ARGS`.
2. Delete the two source-path mutations (`launcher: the shared body directory is off the source path` and `launcher: the program's own directory is off the source path` — their FIND text no longer exists). They live in the **placeholder pass** since Task 4's review relocated them there (pass 1's invocation lost the distinction when the harness includes went; the placeholder pass could still catch both, and did, with measured include-starvation signatures). Add the declared survivor in the first pass where the pair originally lived:
```cmake
# The line these two retired mutations targeted is gone with the include
# mechanism; what replaced it is deliberate narrowing, measured inert.
byte_machine_mutation(
  FILE ${LAUNCHER} SPEC harness-self-tests.sps
  LABEL "launcher: source-directories is left at Chez's default instead of emptied"
  FIND [[(source-directories '())]]
  REPLACE [[;; deleted]]
  EXPECT_SURVIVES
    "measured inert (decision 0006, extending 5b's C3b): no include form exists anywhere, library resolution runs through library-directories, and no lane's outcome differs between an empty source path and Chez's default; the line is kept as narrowing, not as behavior")
```
3. Delete the `launcher: --source-dir is dropped from required-flags` pass (`byte_machine_slice3_launcher_pass` call) whole — its subject left `required-flags`. The trailing-paren hazard its comment records now belongs to `--library-root`, the new last entry: move that comment to the `launcher-no-library-root` entry-drop pass and update that pass's FIND/REPLACE to close the list itself:
```cmake
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-no-library-root.chez.source
  "launcher: --library-root is dropped from required-flags"
  [[        "--library-root"))]]
  [[        ;; --library-root removed by mutation
        ))]]
  [[library \(byte-machine test harness\) not found]]
  "--object-guard" "${GUARD_DIR}"
  "--program" "${STAGE_DIR}/test/support/harness/self/harness-bootstrap.sps")
```
4. The `launcher-missing-value` pass's deliberately-trailing flag was `--source-dir`; it becomes `--library-root`:
```cmake
byte_machine_slice3_launcher_pass(
  byte-machine.harness.launcher-missing-value.chez.source
  "launcher: a flag with no value is accepted"
  [[        ((null? (cdr rest))]]
  [[        (#f]]
  "Exception in cddr"
  ${LAUNCHER_BASE_ARGS} "--library-root")
```
If the suite reports this pass caught for the wrong reason, read the reported output and set `EXPECT_OUTPUT_MATCHES` to the exception the staged run actually prints — every expectation in this file is captured from a real staged run, never guessed.
5. Totals and renumbering: `EXPECTED_PASSES 26` → `25`, `EXPECTED_MUTATIONS 62` → `60` (−2 source-path, −1 required-flags entry, +1 survivor). Header: parse-decision paragraph becomes `Passes 9 to 17` (nine: unknown flag, missing value, repeated flag, required-unchecked, three required-flag entries, two single-valued entries), and the downstream banners shift by one more (consumer 18, ownership 19, fingerprint 20, hex 21, provenance 22–25); update the enumeration and cross-references as in Task 6 step 4.7.

- [ ] **Step 7: Suite, fresh**

```bash
make clean && make test-all
ctest --preset release -N | tail -1
rg -n 'source-dir' cmake test src CMakeLists.txt --glob '!*.md'
```
Expected: 33/33 green (`Total Tests: 33`); scheme-mutation `25 passes, 60 mutations`; the `rg` shows only `source-directories` Scheme text in the two launchers' comments and code — no `--source-dir` flag anywhere.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "refactor: launchers drop --source-dir; the source path is empty by construction"
```

---

### Task 9: `SHARED_BODIES` becomes `SOURCES`

The pure rename (§8.1): the manifest argument's name catches up with what it now holds — programs and libraries, not shared bodies.

**Files:**
- Modify: `cmake/ByteMachineSchemeLane.cmake`, `test/support/cmake/ByteMachineSchemeLaneSpec.cmake`, `test/CMakeLists.txt`

**Interfaces:**
- Produces: `byte_machine_add_scheme_lane(… SOURCES <path>…)`; refusal messages `SOURCES is required for byte_machine_add_scheme_lane` and `names a source that does not exist`.

- [ ] **Step 1: The registrar**

In `cmake/ByteMachineSchemeLane.cmake`: `cmake_parse_arguments`'s multi-value list `"LABELS;ENVIRONMENT;SHARED_BODIES"` → `"LABELS;ENVIRONMENT;SOURCES"`; the required loop `foreach(required NAME BACKEND PROGRAM TIMEOUT SHARED_BODIES)` → `… SOURCES)`; every `arg_SHARED_BODIES` → `arg_SOURCES`; the existence-loop message `names a shared body that does not exist` → `names a source that does not exist`; the requiredness comment (`SHARED_BODIES is required, not optional…`) reworded to name `SOURCES` and "a lane cannot be added without its manifest"; the duplicate-basename refusal from Task 5 reads `${arg_SOURCES}`.

- [ ] **Step 2: The spec**

In `ByteMachineSchemeLaneSpec.cmake`: every `SHARED_BODIES` keyword in the ~20 registration calls → `SOURCES`; case names `lane-requires-shared-bodies` → `lane-requires-sources` and `lane-rejects-missing-shared-body` → `lane-rejects-missing-source` (both the dispatch and the `spec_expect_all_rejected` entries); the two expected patterns become `SOURCES is required for byte_machine_add_scheme_lane` and `names a source that does not exist`.

- [ ] **Step 3: The registrations**

In `test/CMakeLists.txt`: every `SHARED_BODIES` keyword → `SOURCES`; the `BYTE_MACHINE_HARNESS_MANIFEST` comment (`The bodies every harness lane executes…`) becomes:
```cmake
# The sources every harness lane executes -- the two libraries; each lane
# appends its own program. Named once: a lane that listed them itself would
# drift, and a manifest that drifts is one that quietly stops describing the
# run.
```

- [ ] **Step 4: Suite**

MutationSuite's scheme-lane FIND texts do not name the keyword (verify: `rg -n 'SHARED_BODIES' test/support/cmake/MutationSuite.cmake` → no hits), so totals are unchanged.
```bash
make test-all
rg -n 'SHARED_BODIES' cmake test src CMakeLists.txt --glob '!*.md'
```
Expected: 33/33 green, `1 pass, 66 mutations` / `25 passes, 60 mutations`; the `rg` returns no hits.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor: the manifest argument is SOURCES — programs and libraries, not shared bodies"
```

---

### Task 10: The gates, the record of the cut, and the PR

§11's acceptance gates, the CHANGELOG entry with re-measured numbers, and the PR.

**Files:**
- Modify: `CHANGELOG.md` (unreleased section only); whatever files the sweeps surface

**Interfaces:**
- Consumes: everything; produces the PR.

- [ ] **Step 1: The semantic-vocabulary sweep (§6's own gate)**

```bash
rg -n -i 'both runtimes|both adapters|both wrappers|two wrappers|each runtime|per runtime|two standards|r7rs|parity proof' src test
```
Expected: empty. Then the reading pass the Chez-only cut proved necessary: read every comment block in `src/byte-machine/*.sls`, `test/support/harness/byte-machine/test/*.sls`, the four launchers, the eight programs, `test/CMakeLists.txt`, and the `cmake/` modules, looking for prose that describes the include world without naming it — "shared body", "wrapper", "owner library", "resolved through source-directories", "the working-directory matrix". Tasks 6 and 8 already rewrote the known sites (the run-directory comments, the launcher flag-block rationale); this pass is the backstop for the ones nothing named. Fix each survivor in place. Re-run the `rg`; still empty.

- [ ] **Step 2: The no-include gate (§11 gate 2)**

```bash
rg -n '\(include ' src test
rg -n 'chezscheme\) include' src test
```
Expected: both empty — zero `include` forms and zero `(only (chezscheme) include …)` imports in any Scheme file under `src/` and `test/`.

- [ ] **Step 3: The fresh full suite (§11 gate 3)**

```bash
make clean && make test-all
cmake --preset no-scheme && ctest --preset no-scheme --output-on-failure --no-tests=error
```
Expected: 33/33 release green; 8/8 no-scheme green; scheme-mutation `25 passes, 60 mutations`; cmake-mutation `1 pass, 66 mutations`.

- [ ] **Step 4: The measurement (§11 gate 4)**

```bash
find cmake test/support -type f | xargs wc -l | tail -1
find src -type f | xargs wc -l | tail -1
```
Record both totals. Baselines were 8,327 and 110; §6 of the Chez-only plan estimated the harness lands toward 4,000–4,500 **after both this slice and the 5b remainder** — record the measured number without adjusting it to the estimate.

- [ ] **Step 5: CHANGELOG**

Add to the `### Changed`/`### Removed` areas of the unreleased section (create the subsection headers if absent), with `<N>` values from step 4:

```markdown
### Changed

- Every library is an ordinary inline R6RS `.sls` and every test program a
  plain `.sps`; no Scheme file includes another. The fingerprint algorithm is
  its own library, `(byte-machine test fingerprint)`, imported by the harness
  and by the build-time expectation alike. A lane's manifest (`SOURCES`,
  formerly `SHARED_BODIES`) is its program plus every library it loads, so
  every byte of Scheme a lane runs is fingerprinted — wrapper text never was,
  before. See [decision 0006](docs/decisions/0006-inline-libraries.md).

### Removed

- The shared-body include mechanism and everything that kept it honest: the
  launchers' `--source-dir`, the working-directory matrix and its asymmetric
  mutation, the repository-wide basename guard
  (`ByteMachinePortabilityGuard.cmake`, its specification, and its twelve
  mutations — replaced by a per-lane basename check in the registrar), and
  the one-owner rule with its import-vs-include mutations (replaced by an
  inline-duplication mutation the identity lane catches). Decisions 0002 and
  0003 are superseded by 0006. The harness stands at <N> lines against the
  8,327-line pre-collapse baseline (`src/`: <N> against 110).
```

- [ ] **Step 6: Suite and commit**

```bash
make test-all
git add -A && git commit -m "chore: changelog for the include collapse"
```

- [ ] **Step 7: The PR**

```bash
git push -u origin HEAD
gh pr create --title "The include collapse: every library owns its own text" --body "$(cat <<'EOF'
Implements docs/plans/milestone-0-include-collapse.md (decision 0006): every
library is an inline R6RS .sls, every test program a plain .sps, and the
include/source-directories mechanism retires — launchers lose --source-dir,
the cwd matrix and repository-wide basename guard go, the one-owner rule is
replaced by an inline-duplication mutation, and a lane's SOURCES manifest now
covers its program text. Lane matrix: 33 release lanes; SchemeMutationSuite
25/60; MutationSuite 1/66. The aot lane-command branch is edited but
lane-unwitnessed until the 5b remainder, as the design records.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
(If pushing over SSH fails on the first attempt, retry — the standing note about agent keys applies; check PR state before retrying a merge, never before retrying a push.)

---

## Self-review notes

- **Spec coverage.** §2's three scope decisions: collapse-first (no task builds body-copy staging; Task 2's 0006 records the carry), merge+rename (Task 7), fingerprint library (Task 3). §5: T3/T4/T6. §6: T7, including the manifest-membership claim (T7 step 5 verifies it against the configured environment). §7: T3 (manifest launcher), T8 (both flag-bearing launchers), chez-aot.ss untouched (no task names it). §8.1: T3/T4/T6/T7 evolve the manifests; T9 renames. §8.2: T5. §8.3: carried by never registering an aot lane; 0006 and the 5b/5c amendment note say so. §9.1: T5 (guard lane), T6 (matrix), T8 (no-source-dir lane). §9.2's four categories: objectless (T6 matrix mutation, T8 source-path pair), unconstructible-with-replacement (T6 step 4.6), retargeted (T3/T4/T6/T7), deleted-with-module (T5). §10: T2 wholesale, CHANGELOG in T10. §11's four gates: T10 steps 1–4. §12's phase rules: every task carries the registration edits its moves force, and each ends with the suite command shown. §14's risks: T1 (import mechanics, with the eval fallback stated), T8 step 6.4 (the one measured-not-guessed expectation), blame via `git mv` of the larger file in T3/T6/T7.
- **Counts.** Lane arithmetic 37→36 (T5: guard spec lane) →34 (T6: three cwd lanes become one) →33 (T8: no-source-dir refusal). Scheme totals 29/65 →26/62 (T6: −3 matrix passes/mutations; pass 23's rewrite is 1-for-1) →25/60 (T8: −1 pass; −3+1 mutations). CMake totals 75 →66 (T5: −12 guard, +2 lane-check, +1 carried accumulator hazard — corrected from 65 after Task 5's review). The suites' own totals gates enforce every row.
- **Type consistency.** The manifest keyword is `SHARED_BODIES` in Tasks 3–8 and `SOURCES` only from Task 9 — every earlier step deliberately uses the old spelling. The fingerprint library's four exports match between T3 (definition), the harness re-export (unchanged export list), and the manifest launcher's calls. The per-lane check is `byte_machine_lane_duplicate_basenames` in T5's function, wiring, spec, and both mutations.
