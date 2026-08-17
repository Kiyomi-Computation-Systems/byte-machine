# Milestone 0, Slice 3: One shared body through both wrappers

Status: design agreed; ready for an implementation plan
Date: 2026-08-16
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §7.2, §8
Milestone plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) — deliverable D2, work-order item 3
Previous slice: [`milestone-0-slice-2-test-harness.md`](./milestone-0-slice-2-test-harness.md)
Scope: **the include mechanism for product code.** One placeholder body, one owner library per runtime, and the working-directory proof. Cross-library identity is slice 4; compiled lanes are slice 5.

## 1. What this slice must prove

The milestone plan states the bar in one sentence: *an identical shared body loads through both
wrappers from at least three different working directories.*

Slice 2 already runs shared bodies through per-runtime wrappers, so the obvious reading — "prove
`include` works" — is already answered and would make this slice a formality. The part that is not
yet answered is the part §7.2 actually asserts: that the wrapper is *thin*, that the body is what
runs on both runtimes, and that neither depends on where the process was launched from. Each of
those can be false while every test is green, which is what makes them worth a slice.

Three claims, then, each stated so it can be disproved:

1. **The body is what runs.** A wrapper that quietly reimplemented the semantics passes every test
   the shared body would have passed. Only mutating the body and watching *each* runtime notice
   distinguishes the two.
2. **Resolution does not depend on the working directory.** A test run from one directory proves
   nothing about this, and three directories that all fail the same way prove it once, not three
   times.
3. **The wrapper structure supports exactly one owner per body.** Slice 4 witnesses this with `eq?`
   across two importing libraries. Slice 3 is where the representation is chosen that makes that
   test capable of failing — see §5.2, which is the single most consequential paragraph here.

This slice also puts the first files in `src/`. Everything from here compiles against the shape it
establishes.

## 2. Verified environment facts

Measured on 2026-08-16 (Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8) against scratch fixtures
built for the purpose, before the design was accepted.

| Fact | Result |
| --- | --- |
| `gsi -:search=A,search=B` resolves libraries from two roots at once | works |
| the same invocation with only root A on the path | `Cannot find library (pkg beta)`, exit 70 — so the second root is load-bearing, not decorative |
| Chez `include` by bare filename with a **same-named decoy file in the working directory** | resolves through `source-directories`; the decoy is ignored |
| Chez `include` with `source-directories` pointing somewhere the file is not, decoy still in the CWD | `file "placeholder-body.scm" not found in source directories`, exit 255 — no CWD fallback |
| a Gambit search root whose path contains a comma | `gsi` prints its runtime-options usage banner and runs no Scheme at all |

Two of these are new and neither was assumed by the milestone plan.

The plan's §2 table records "Chez `include`, bare relative path → resolves against **process CWD**".
That is a statement about the *default* value of `source-directories`, which contains `"."`. Once a
launcher sets it explicitly to a list that excludes `"."`, the working directory leaves the search
entirely — Chez refused rather than picking up a same-named file sitting in the CWD. This is what
makes the decoy lane in §7.4 legal: it discriminates on *content*, not merely on whether some file
was found.

The comma result is a portability trap with no diagnostic value on its own. Gambit's `-:` options
are comma-separated, so a checkout or build tree under `~/my,projects/` breaks every Gambit lane
with output that names nothing this project owns. §8.2 turns it into a configure error.

## 3. Decisions taken

| # | Decision | Rationale |
| --- | --- | --- |
| T1 | The shared body carries the D3 payload — tagged vector and singleton — in this slice. Slice 4 adds only the second wrapper per runtime and the cross-boundary `eq?` test. | Keeps slice 3's "no duplicated semantics" claim about a body with something in it worth duplicating, and leaves slice 4 a genuine proof rather than a file-shuffling exercise. Both slices keep their own exit criteria from the milestone plan's work order. |
| T2 | The type tag and the singleton are **freshly allocated objects, never symbols**. | Symbols are interned, so a symbol tag is `eq?` to itself across any number of includes and slice 4's identity test would pass against a tree that had included the body twice — the exact defect §7.2 exists to prevent. See §5.2. |
| T3 | The library is `(byte-machine placeholder)`, body `placeholder.scm`. | Named for its lifetime. D4 deletes it in Milestone 1, so it must not squat on `model`, `graph`, or any other name M1 wants, and M1 must not inherit a file it never designed. |
| T4 | The Chez launcher takes repeatable flags: `--library-root`, `--source-dir`, `--object-guard`, `--program`. | Slice 3 needs two library roots and two source directories; slice 5's compiled lanes and M1's further libraries need more. Positional expansion works today and renumbers every caller at each of those steps. A separator-joined path list was rejected outright: it re-opens milestone plan §9 question 3 (`:` vs `;` on Windows) for no benefit, and §2 shows what a stray separator character does to a Gambit invocation. |
| T5 | Test bodies and their wrappers are **co-located** in `test/common/`. | `src/` is split per runtime because library *search roots* must be; test wrappers are programs passed by absolute path, so splitting them buys no mechanism, only directories. Co-location keeps the portability guard's rule a sibling glob, auditable at a glance. Recorded as a permitted adjustment to parent plan §8, which states the split may be adjusted during this spike provided responsibility boundaries hold. |
| T6 | "No semantics duplicated in a wrapper" is checked by **mutating the body and requiring each runtime's lane to fail**. | A wrapper that reimplemented the body is precisely a wrapper whose runtime does not notice the body changing, so this witnesses the claim rather than approximating it. It inverts slice 2's rule S6 ("Chez alone is enough, the text is identical"): there the body was known-shared, here proving it is shared is the whole point. |
| T7 | Export parity between the two wrappers gets **no dedicated check**. | One shared test body, identical text, exercises every export on both runtimes, so a name missing from either wrapper fails that runtime's lane at import. Slice 2 needed a mutation for its adapters; slice 3 gets the same coverage from the structure and should not pay twice. |
| T8 | The three working directories are chosen one per failure mode, and all three live in the build tree. | See §7.4. Building them in the build tree keeps intact `byte_machine_add_test`'s existing rule that a test never runs from the repository — a rule whose stated reason is this very hazard. |
| T9 | The portability guard is widened at its **call site only**. | `src/common/byte-machine` joins as a `SHARED_DIR`, `test/common` as a `WRAPPED_DIR`. The per-directory "contributed no shared body" rule that makes this safe was built in slice 2 for exactly this moment. |

### 3.1 Rejected alternatives

- **A guard rule that every `src/common` body owns exactly one `.sls` and one `.sld`.** The
  basename form is already false in this tree: the harness body is `harness-runner.scm` and its
  library is `harness.sls`. The form that would work — scanning wrapper text for an `include` of
  that body — is a syntactic lint by another name, and a commented-out include satisfies it. The
  failure it would catch is not silent today: a missing wrapper fails that runtime's lane at import.
  It becomes silent only once a body exists with no lane registered against it, which is an M1
  problem to solve when M1's shape is known.
- **Three ordinary working directories** (repo root, build tree, temp). Satisfies the exit criterion
  as written with no fixtures to maintain, but all three break identically and none catches a
  wrong-file resolution.
- **A minimal inert body now, D3 payload in slice 4.** Smaller slice 3, but it defers T2 — the one
  decision that determines whether slice 4's test can fail — into the slice that depends on it.
- **Running the vacuous-control lane from `src/common/byte-machine` itself.** The most literal
  version of "the directory where a CWD-relative include would accidentally succeed", but it points
  a test at the repository, against a documented rule. A configure-time copy in the build tree has
  the same property and needs no exception.

## 4. Layout

Created:

```text
src/common/byte-machine/placeholder.scm        the wrapper-free body
src/chez/byte-machine/placeholder.sls          owner library, Chez
src/gambit/byte-machine/placeholder.sld        owner library, Gambit
test/common/placeholder-tests.scm              shared test body
test/common/placeholder-tests.chez.sps         wrapper: imports only
test/common/placeholder-tests.gambit.scm       wrapper: imports only
docs/decisions/0002-shared-body-include-mechanism.md
```

Modified: the Chez launcher, `ByteMachineTesting.cmake`, `ByteMachineExpectExit.cmake`,
`ByteMachineSchemeLane.cmake`, their three specifications, both mutation suites,
`test/CMakeLists.txt`, and `CHANGELOG.md`. The `.gitkeep` files in the four directories that
acquire real contents are deleted.

Generated at configure time, never checked in:

```text
${CMAKE_BINARY_DIR}/cwd-matrix/same-name-identical/placeholder.scm      copy of the real body
${CMAKE_BINARY_DIR}/cwd-matrix/same-name-identical/harness-runner.scm   copy of the real body
${CMAKE_BINARY_DIR}/cwd-matrix/same-name-decoy/placeholder.scm          impostor
${CMAKE_BINARY_DIR}/cwd-matrix/same-name-decoy/harness-runner.scm       copy of the real body
${CMAKE_BINARY_DIR}/cwd-matrix/empty/
```

Both non-empty directories carry a copy of *every* body the lane's libraries include, not only the
one under test. §9.1 explains why: without the harness copy, the mutation that models a
CWD-relative include takes the harness down first and all three lanes fail identically, which is
exactly the asymmetry the matrix exists to produce. Only the placeholder body is ever an impostor.

These files share basenames with real bodies deliberately. That is why they cannot be checked
in: the portability guard forbids repeated basenames across shared-body directories, and a fixture
whose whole purpose is to collide would either break the guard or force an exemption. Slice 2 put
its dirty-guard fixture in the build tree on the weaker version of this argument.

## 5. The shared body

### 5.1 Exported surface

| Name | Meaning |
| --- | --- |
| `make-placeholder` | one value in, tagged vector out |
| `placeholder?` | recognises what `make-placeholder` produced, and nothing else |
| `placeholder-value` | the carried value |
| `placeholder-marker` | nullary; returns the singleton, allocating nothing |

Nothing else. No name, no version, no origin string: the decoy fixture in §7.4 distinguishes the
real body from an impostor by making an existing procedure return the wrong answer, so no API exists
solely to be tested.

Only the common R6RS/R7RS subset appears: `define`, `vector`, `vector?`, `vector-length`,
`vector-ref`, `eq?`, `=`, `and`. No record type, no condition, no library or include form.

### 5.2 Why the tag and the singleton are fresh allocations

The tag is a vector allocated once when the body is loaded, and the singleton is another. Neither is
a symbol, and this is not a style preference.

Symbols are interned. `(eq? 'bm-placeholder 'bm-placeholder)` is true no matter how many separate
copies of the body produced those two occurrences. A symbol tag therefore makes the double-include
defect **structurally invisible**: two libraries that each included the body would recognise each
other's values, and slice 4's `eq?` test would pass against precisely the tree §7.2 forbids. With a
fresh allocation, a second include yields a second tag, the second library rejects the first's
values, and the defect is caught.

Slice 3 does not witness this — one library cannot. Slice 3 is where the representation is chosen
that lets slice 4 witness it, so the rule is written as a comment on the tag itself, where the next
person to reach for a symbol will read it.

### 5.3 Decisions in the body, and which mutation breaks each

`placeholder?` makes three decisions rather than one, so the mutation suite has three things to
break:

| Decision | Mutation | Witness |
| --- | --- | --- |
| the argument is a vector | `(vector? x)` → `#t` | `(placeholder? 7)` reaches `vector-length` and raises; the case errors |
| the length is right | the check is deleted | a length-3 vector carrying the *real* tag is accepted |
| the length is right | `2` → `3` | every genuine placeholder is rejected; the round-trip case fails |
| the tag matches | tag comparison → `#t` | a same-shaped vector carrying a *symbol* that looks like the tag is accepted |

The length decision gets two mutations because it can fail two ways — the check can be absent, or
its bound can be wrong — and the first of those is the one an earlier draft of this document got
wrong. It claimed deleting the check outright was unwitnessable from outside the library, on the
grounds that the tag is private so no caller could construct a mis-sized vector carrying it. That
premise is false: a legitimately built placeholder hands the tag over through ordinary
`vector-ref`, so `(vector (vector-ref (make-placeholder 0) 0) 1 2)` is a length-3 vector with the
genuine tag, buildable from the exported API alone. The claim was found by review, not by test,
which is the point of the standard it broke: "this cannot be tested" is a claim to demonstrate, and
concluding it without demonstrating it is how a decision quietly stops being checked.

The third witness doubles as the executable version of §5.2: the test constructs
`(vector 'byte-machine-placeholder <v>)` and requires `placeholder?` to reject it. If the tag ever
becomes a symbol, that case fails.

## 6. The wrappers

```text
src/chez/byte-machine/placeholder.sls     (include "placeholder.scm")
src/gambit/byte-machine/placeholder.sld   (include "../../common/byte-machine/placeholder.scm")
```

Each contains a library form, an import list, an export list, and the include. Nothing else. The two
include forms differ because the two mechanisms differ — Chez resolves a bare filename through
launcher-set `source-directories`, Gambit resolves a path relative to the including file — and that
difference is the one place in the tree where the mechanisms are visibly not the same. It has a
consequence for staging that §9.2 spells out.

## 7. Lanes

### 7.1 The launcher's flag protocol

`chez-source.ss` moves from four positional arguments to:

```text
--library-root <dir>    repeatable, at least once
--source-dir <dir>      repeatable, at least once
--object-guard <dir>    exactly once
--program <path>        exactly once
```

Every root is paired with the same always-empty object guard, which is what keeps `mode=source`
unfalsifiable now that there is more than one root. The program's own directory is appended to
`source-directories` as before, so a program's body resolves beside it.

Each refusal exits 2 and gets its own lane, on the argument slice 2 established: a correctly
set-up lane never reaches a refusal, so nothing else can notice one being deleted.

| Refusal | Why it needs its own lane |
| --- | --- |
| unknown flag | new decision |
| flag missing its value | new decision; a trailing `--program` would otherwise mean "no program" silently |
| a single-valued flag given twice | one decision covering both `--program` and `--object-guard`; last-one-wins would be silent |
| no `--program` | replaces the retired exact-arity refusal; a bare invocation is the natural form |
| no `--object-guard` | the flag absent, as distinct from the directory it names being absent |
| no `--library-root` | without it the failure arrives as Chez's own "library not found", which reads as a broken test rather than a broken invocation |
| no `--source-dir` | same, arriving as exit 255 from `include` |
| guard directory absent / non-empty | the existing two lanes from slice 2, retained unchanged |

Seven new lanes and the two retained: nine. The four missing-flag refusals are one loop over a
declared list of required flags, so they are one *decision* — but a flag dropped from that list is
its own defect, invisible to every other lane, which is why each entry gets a lane rather than the
loop getting one.

### 7.2 Chez lane command

Two library roots — `src/chez` and the harness's — and two source directories —
`src/common/byte-machine` and the harness's shared directory. All absolute; nothing resolves against
the working directory.

### 7.3 Gambit lane command

`-:search=<harness-root>,<src-gambit-root>`, verified in §2 along with the control showing the
second root is doing real work. No launcher: Gambit's include inside `define-library` needs no
ambient state.

### 7.4 The working-directory matrix

Three directories, each catching a different failure of the mechanism, all created at configure time
under `${CMAKE_BINARY_DIR}/cwd-matrix/`:

| Directory | Contents | What a CWD-relative include does here |
| --- | --- | --- |
| `same-name-identical/` | `configure_file(COPYONLY)` copies of both real bodies | **succeeds** — the vacuous control |
| `same-name-decoy/` | real harness body, impostor placeholder body: same basename, complete export list, wrong answers | finds a file and reports the **wrong** one |
| `empty/` | nothing | finds **nothing** |

Six lanes: three directories on each runtime, in the existing `portability` layer, whose vocabulary
entry already reads "values crossing library boundaries; runtime identity".

The decoy must implement the *complete* export list. An incomplete one fails the lane at library
construction, which is still a failure but a different one — the claim being made is that resolution
picked the wrong file, and that claim is only tested if the wrong file would otherwise work.

The control lane is carried deliberately and is non-discriminating by design. It is the test someone
writes by default, and it is what makes the decoy lane's failure attributable to content rather than
to the mere presence of a same-named file in the working directory. §9.1 makes the repository
observe its vacuity rather than take this paragraph's word for it. It must never be cited as
evidence on its own.

## 8. Build layer

### 8.1 Module changes

`byte_machine_add_test` already gives every test a private working directory under the build tree,
and its comment cites this exact hazard as the reason. It gains an optional `WORKING_DIRECTORY`
overriding the derived run directory; the temporary directory is unaffected.
`byte_machine_add_exit_code_test` and `byte_machine_add_scheme_lane` forward it. The expect-exit
runner needs nothing: its `execute_process` inherits the working directory CTest set, so the Scheme
process runs where the lane asked.

`byte_machine_scheme_lane_command` builds the flag-based Chez invocation and the comma-joined Gambit
search list.

### 8.2 The comma refusal

Any Gambit search root containing a comma is a configure error, with the diagnostic naming the
directory and the reason. §2 measured what happens without it: a usage banner from `gsi` mentioning
nothing this project owns, on every Gambit lane at once.

### 8.3 Portability guard

Call site only. `src/common/byte-machine` joins as a `SHARED_DIR`, `test/common` as a
`WRAPPED_DIR`. The rule that makes this safe — every declared directory must contribute at least one
body, checked per directory rather than over the combined result — was written in slice 2 with this
moment named in its comment. Both directories acquire their first body in this slice, so the guard
tightens as they are populated rather than being widened over empty trees.

The flat basename namespace now spans `src/common` and the harness's shared directory for the first
time, which is what slice 2's `harness-*` prefix convention was for.

### 8.4 Registered tests

| Lane | Count | Status |
| --- | --- | --- |
| `byte-machine.portability.placeholder-cwd-{identical,decoy,empty}.{chez,gambit}.source` | 6 | 0 |
| launcher refusals, Chez | 9 (7 new, 2 retained) | 2 |
| existing slice 1 and 2 registrations | unchanged | — |

`ctest --preset no-scheme` must still pass with neither runtime installed.

## 9. How the slice earns trust

Under a correct mechanism **all six matrix lanes pass**, the decoy included — the decoy is simply
ignored. So the matrix proves nothing until something has made it fail, and the thing that makes it
fail is not a mutation of the body.

### 9.1 The asymmetric launcher mutation

Mutate the launcher to resolve shared bodies against the working directory — the declared
`--source-dir` values replaced by `(list ".")`, keeping the program's own directory so the test body
beside its wrapper still resolves and the lane fails for the reason under test:

| Lane | Expected outcome |
| --- | --- |
| `cwd-empty` | fails — nothing to include |
| `cwd-decoy` | fails — wrong answer, on content |
| `cwd-identical` | **passes** |

The suite asserts all three, the survivor included. That is what makes §7.4's claim about the
control lane an observation the repository repeats on every run rather than a comment.

This is where §4's second fixture copy is paid for. The mutated launcher resolves *every* shared
body against the working directory, and the harness runner is a shared body too — so a matrix
directory holding only a placeholder body fails to build `(byte-machine test harness)` before it
reaches the code under test, and all three lanes fail identically. The asymmetry, and with it the
only evidence that the decoy and control lanes differ, is destroyed by a fixture that looks
complete. The non-empty directories therefore carry every body the lane includes; `empty/` carries
none, which is its entire purpose.

The Gambit half of the matrix is weaker evidence and is recorded as such. Gambit resolves the
include relative to the including file, so this mutation cannot touch it, and no Scheme-level
mutation can: what would make a Gambit lane working-directory-dependent is a *relative search
root*, which is a build-layer mistake. It is refused at configure time beside the comma refusal
(§8.2) and witnessed there, in the CMake specification and mutation suite, rather than by a Scheme
pass whose mutation would have to target a file the Gambit lane never reads. Symmetry of lane
counts is not symmetry of evidence.

### 9.2 Body mutations, verified on both runtimes

Each decision in §5.3 is broken on a staged copy, and **each runtime's lane must fail**. This is
T6's proof that no wrapper reimplements the body.

One staging detail decides whether it works at all: the Gambit `.sld` includes by a relative path,
so the staged tree must preserve `src/gambit/byte-machine → ../../common/byte-machine`. Staging the
body alone and pointing at it satisfies Chez, which resolves by bare filename, and silently leaves
Gambit compiling the unmutated original — a mutation suite reporting a caught mutation on a runtime
that never saw it. Only one of the two runtimes will tell you.

### 9.3 Mutations to declare

- three body decisions (§5.3), each verified on both runtimes;
- each launcher parse decision: unknown flag, missing value, a single-valued flag given twice, each
  of the four required-flag entries (`--program`, `--object-guard`, `--library-root`,
  `--source-dir`), and both guard-directory checks;
- the `source-directories` mutation of §9.1, with its declared survivor;
- the relative-search-root mutation for Gambit;
- `WORKING_DIRECTORY` ignored by `byte_machine_add_test` — witnessed by the matrix collapsing to
  three copies of one lane;
- the comma refusal deleted — witnessed by its specification.

## 10. Work order

Each step is independently verifiable and leaves the suite green.

1. **Launcher flag protocol** and its refusal lanes. No product code involved; the existing harness
   lanes move to the new invocation form and must keep passing.
2. **Multi-root lane command construction** for both runtimes, plus the comma refusal. Verified by
   routing the existing harness lanes through the new code path.
3. **The body, both wrappers, the shared test body and its wrappers**, one lane per runtime from the
   default working directory. The portability guard's call site widens here, in the same step that
   gives both new directories their first body.
4. **`WORKING_DIRECTORY` override**, the three matrix directories and their fixtures, six lanes.
5. **Mutations**: the asymmetric launcher mutation, body decisions on both runtimes, the CMake
   decisions.
6. **Decision record 0002 and the changelog entry.**

## 11. Out of scope

Cross-library identity (slice 4), compiled lanes (slice 5), fingerprinting and deterministic emission
(slice 6), CI (slice 7). No byte-machine semantics: the placeholder is deleted in Milestone 1 per
D4. No second body in `src/common` — the guard rule that a second body would need is argued and
rejected in §3.1.

## 12. Exit criteria

- the same body loads through both wrappers from three working directories chosen for three
  different failure modes;
- the launcher mutation makes the matrix fail in the asymmetric pattern of §9.1, survivor included;
- every decision in the body is caught on **both** runtimes;
- every launcher refusal has a lane asserting exit 2 exactly;
- a Gambit search root containing a comma is a configure error;
- `src/common/byte-machine` and `test/common` are under the portability guard;
- `ctest --preset no-scheme` passes with neither runtime installed;
- decision record 0002 records the §2 measurements, including the partial answer to milestone plan
  §9 question 3.

## 13. Risks

- **Nine launcher refusal lanes for one launcher.** Each is a process spawn, and the pressure to
  trim them is the pressure that kills mutation suites. Recorded now, while the trade can still be
  made deliberately.
- **The Gambit matrix lanes are weaker than the Chez ones** (§9.1). The risk is that six lanes read
  as six units of evidence.
- **The decoy fixture must track the export list.** An export added to the body without being added
  to the decoy turns a content test into a construction failure — still red, but no longer testing
  what it says.
- **The vacuous control lane can be misread.** It passes under a broken mechanism; that is its
  purpose. It is named `identical` rather than anything suggesting a proof, and §9.1 pins its
  meaning.
- **`configure_file(COPYONLY)` keeps the matrix fixtures in step with the real bodies only at
  configure time.** A build that edits a body without reconfiguring runs the control against a stale
  copy. Contents do not affect the correct-mechanism outcome, so this degrades the control, not the
  suite.
- **A body added to `src/common` or to the harness must be copied into both non-empty matrix
  directories** (§9.1), or the launcher mutation silently stops being asymmetric. This is the
  fixture-completeness trap in its general form, and it is the most likely way this slice's evidence
  decays after the slice ships.
