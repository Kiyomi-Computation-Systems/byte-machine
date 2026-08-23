# Milestone 1 — Phase 1 (CI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the repository's first CI pipeline — the existing suite green on macOS arm64 and Linux amd64 — and tighten the adapter OS/architecture assertions from "not unknown" to exact-value checks, witnessed by mutation.

**Architecture:** Two concerns, kept separate. (1) *Mapping correctness* — refactor the harness adapter's OS/arch derivation into pure `machine-type->…` functions and test them exhaustively over the four Tier-1 machine-type strings; a mutated table row is caught locally by the Scheme mutation suite. (2) *Cell identity* — in CI, the workflow supplies each cell's true OS/arch as ground truth (env vars) and the self-test/bootstrap lanes assert the *live* adapter equals it. Locally those env vars are absent and a not-unknown floor holds. No CMake lane changes are needed; the fix is Scheme + a GitHub Actions workflow + one new mutation.

**Tech Stack:** Chez Scheme (R6RS), the `(byte-machine test harness)` library, the CMake/CTest mutation suite, GitHub Actions.

## Global Constraints

- **Chez floor 10.4.1, threaded machine type.** Discovery owns the version/threaded checks (`cmake/ByteMachineChez.cmake`); CI must install Chez ≥ 10.4.1 or discovery rejects it. Machine types are always `t`-prefixed (threaded).
- **Exit-status vocabulary is exactly `0,1,2,3`** (pass / assertion failure / harness-or-config error / provenance). `EXPECT_STATUS` values live in this set.
- **Mutation discipline (AGENTS.md, global-constraints.md).** Every decision gets a mutation the owning spec notices; assert a *measured* failure signature (`EXPECT_STATUS`/`EXPECT_OUTPUT_MATCHES`), never a bare nonzero exit; `EXPECT_SURVIVES` only for the genuinely unwitnessable, with a re-printed reason. After adding any exit path, re-run the *whole* suite. Update declared totals and their arithmetic comments in the same commit as the mutation.
- **`no-scheme` preset must stay green (8/8).** Nothing in this phase may require a Scheme runtime to configure the build layer.
- **Discovery candidate names are `scheme chez chezscheme`** (`cmake/ByteMachineChez.cmake:51`); identity is decided on probe banner output, not the name. Homebrew installs the binary as `chez` on macOS; the escape hatch is `-DBYTE_MACHINE_CHEZ_EXECUTABLE=/abs/path`.
- **Tier-1 cell → machine type → OS/arch:** `tarm64osx`→darwin/arm64 (measured), `ta6le`→linux/amd64, `tarm64le`→linux/arm64, `ta6nt`→windows/amd64. Milestone 1 CI covers the first two only; Milestone 9 completes the matrix.
- Conventional Commits; run the suite before every commit; no new dependencies.

---

## Task 1: Pure OS/arch mapping functions with exhaustive tests

**Files:**
- Modify: `test/support/harness/byte-machine/test/harness.sls` (adapter section, ~lines 77–134; export list ~lines 38–39)
- Modify: `test/fixtures/stale-root/byte-machine/test/harness.sls` (the deliberately-stale duplicate — it must carry the same new exports/defs or the stale-artifact AOT lane fails to compile the updated program)
- Modify: `test/support/harness/self/harness-self-tests.sps` (the adapter case; the weak checks at ~368–370)

**Interfaces:**
- Produces: `(adapter-machine-type->architecture machine-type-string)` → arch string or `"unknown"`; `(adapter-machine-type->os machine-type-string)` → os string or `"unknown"`. Both pure (string in, string out). `(adapter-architecture)` and `(adapter-os)` become thin wrappers over the live `(adapter-machine-type)`. Consumed by Task 2's bootstrap changes and Task 3's CI assertions.

- [ ] **Step 1: Write the failing exhaustive-mapping test**

In `harness-self-tests.sps`, inside the adapter group, add a case that pins every Tier-1 machine type to its exact OS/arch (this is the mapping-correctness witness). Note argument order is `(check-equal what actual expected)`:

```scheme
    (harness-case "machine types map to the expected os and architecture"
      (lambda ()
        (check-equal "tarm64osx arch" (adapter-machine-type->architecture "tarm64osx") "arm64")
        (check-equal "tarm64osx os"   (adapter-machine-type->os "tarm64osx") "darwin")
        (check-equal "ta6le arch"     (adapter-machine-type->architecture "ta6le") "amd64")
        (check-equal "ta6le os"       (adapter-machine-type->os "ta6le") "linux")
        (check-equal "tarm64le arch"  (adapter-machine-type->architecture "tarm64le") "arm64")
        (check-equal "tarm64le os"    (adapter-machine-type->os "tarm64le") "linux")
        (check-equal "ta6nt arch"     (adapter-machine-type->architecture "ta6nt") "amd64")
        (check-equal "ta6nt os"       (adapter-machine-type->os "ta6nt") "windows")
        (check-equal "unmapped arch"  (adapter-machine-type->architecture "zz99xx") "unknown")
        (check-equal "unmapped os"    (adapter-machine-type->os "zz99xx") "unknown")))
```

- [ ] **Step 2: Run it and confirm it fails**

Run:
```bash
cmake --preset dev && cmake --build --preset dev
ctest --preset harness --output-on-failure -R harness.self
```
Expected: FAIL — `adapter-machine-type->architecture` / `adapter-machine-type->os` are unbound (load failure, status 2), or the case fails if names collide. Either way, not green.

- [ ] **Step 3: Refactor the adapter into pure functions**

In `harness.sls`, replace the bodies of `adapter-architecture`/`adapter-os` (currently deriving from `(adapter-machine-type-body)` inline) so the mapping is a pure function of a supplied string, and the live accessors call it with the live machine type. Keep the existing `adapter-machine-type-body` prefix/`t`-strip and the two tables:

```scheme
  (define (adapter-machine-type-strip-t m)
    (if (and (> (string-length m) 0) (char=? (string-ref m 0) #\t))
        (substring m 1 (string-length m))
        m))

  (define (adapter-machine-type->architecture machine-type)
    (let ((hit (adapter-lookup-prefix adapter-architecture-table
                                      (adapter-machine-type-strip-t machine-type))))
      (if hit (cdr hit) "unknown")))

  (define (adapter-machine-type->os machine-type)
    (let* ((body (adapter-machine-type-strip-t machine-type))
           (arch-hit (adapter-lookup-prefix adapter-architecture-table body)))
      (if (not arch-hit)
          "unknown"
          (let* ((rest (substring body (string-length (car arch-hit))
                                  (string-length body)))
                 (os-hit (adapter-lookup-prefix adapter-os-table rest)))
            (if os-hit (cdr os-hit) "unknown")))))

  (define (adapter-architecture)
    (adapter-machine-type->architecture (adapter-machine-type)))

  (define (adapter-os)
    (adapter-machine-type->os (adapter-machine-type)))
```

Retain `adapter-machine-type-body` if other code references it (`rg -n adapter-machine-type-body test`); otherwise fold it into `adapter-machine-type-strip-t`. For the export list, **leave the existing line `    adapter-os adapter-architecture adapter-execution-mode` byte-for-byte unchanged** — an existing mutation ("an exported adapter name is dropped", `SchemeMutationSuite.cmake` ~:438) pins that exact string with `SITES 1`, so reformatting it makes the mutation match 0 sites (a hard suite error) and risks dropping `adapter-execution-mode` from the export (breaking bootstrap and self-test imports). Append a **new** export line immediately below it:

```scheme
  adapter-machine-type->os adapter-machine-type->architecture
```

Finally, regenerate the deliberately-stale duplicate `test/fixtures/stale-root/byte-machine/test/harness.sls` so it still compiles the updated program. Read the current stale copy to see the trailing divergence comment it appends, then copy the edited real harness over it and re-append that comment. The `byte-machine.harness.stale-artifact.chez.aot` lane compiles the real `harness-self-tests.sps` against this copy; if the copy lacks the two new exports/defs the whole-program AOT compile fails with an unbound identifier (breaking `cmake --build --preset dev` and CI). Confirm the copy still differs from the real file only by its divergence comment (so it still yields the exit-3 provenance mismatch it exists to prove):

```bash
diff test/support/harness/byte-machine/test/harness.sls test/fixtures/stale-root/byte-machine/test/harness.sls
```
Expected: only the trailing divergence comment block differs.

- [ ] **Step 4: Run the exhaustive test to green**

Run:
```bash
cmake --build --preset dev
ctest --preset harness --output-on-failure -R harness.self
```
Expected: PASS. All ten `check-equal`s green; the harness self-test lane exits 0.

- [ ] **Step 5: Replace the weak live-adapter checks with a floor-plus-expected check**

Replace the two `check-not-equal … "unknown"` lines (~368–370) with a check that asserts equality against ground truth when CI provides it, and keeps the not-unknown floor otherwise. Read expected values via the exported `adapter-environment-variable`:

```scheme
        (let ((expect-os (adapter-environment-variable "BYTE_MACHINE_EXPECT_OS"))
              (expect-arch (adapter-environment-variable "BYTE_MACHINE_EXPECT_ARCH")))
          (if (and expect-os (> (string-length expect-os) 0))
              (check-equal "the live os matches the cell" (adapter-os) expect-os)
              (check-not-equal "the os is identified" (adapter-os) "unknown"))
          (if (and expect-arch (> (string-length expect-arch) 0))
              (check-equal "the live architecture matches the cell"
                           (adapter-architecture) expect-arch)
              (check-not-equal "the architecture is identified"
                               (adapter-architecture) "unknown")))
```

(Confirm `adapter-environment-variable` returns `#f`/empty when unset by reading its definition in `harness.sls`; adjust the empty test to match its contract.)

- [ ] **Step 6: Run the harness suite green and commit**

Run:
```bash
cmake --build --preset dev
ctest --preset harness --output-on-failure
```
Expected: PASS (locally `BYTE_MACHINE_EXPECT_OS` is unset, so the floor branch runs; the exhaustive mapping case is always on).

```bash
git add test/support/harness/byte-machine/test/harness.sls test/fixtures/stale-root/byte-machine/test/harness.sls test/support/harness/self/harness-self-tests.sps
git commit -m "test: assert adapter os/arch by exact value, via pure machine-type mapping fns"
```

---

## Task 2: Bootstrap adapter check + the mapping mutation

**Files:**
- Modify: `test/support/harness/self/harness-bootstrap.sps` (the weak checks at ~119–122)
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (add one mutation; bump declared totals)

**Interfaces:**
- Consumes: the pure functions and live accessors from Task 1.
- Produces: a mutation that flips an OS-table row and is caught by the Task 1 exhaustive case at `EXPECT_STATUS 1`.

- [ ] **Step 1: Strengthen the bootstrap assertions**

The bootstrap deliberately cannot use the harness's `check-*`; it uses its own `bootstrap-assert` and reads env via `adapter-environment-variable`. Replace the two not-unknown asserts (~119–122) with expected-when-present, floor otherwise:

```scheme
(let ((expect-os (adapter-environment-variable "BYTE_MACHINE_EXPECT_OS"))
      (expect-arch (adapter-environment-variable "BYTE_MACHINE_EXPECT_ARCH")))
  (bootstrap-assert "adapter: os matches the cell or is at least known"
                    (if (and expect-os (> (string-length expect-os) 0))
                        (string=? (adapter-os) expect-os)
                        (not (string=? (adapter-os) "unknown"))))
  (bootstrap-assert "adapter: architecture matches the cell or is at least known"
                    (if (and expect-arch (> (string-length expect-arch) 0))
                        (string=? (adapter-architecture) expect-arch)
                        (not (string=? (adapter-architecture) "unknown")))))
```

Use `adapter-environment-variable` (already exported by the harness and already called by the bootstrap at ~line 126) — it returns `#f` when the variable is unset. Do **not** use `getenv`: `harness-bootstrap.sps` imports only `(rnrs)` and `(byte-machine test harness)`, and neither exports `getenv`, so it would be an unbound identifier.

- [ ] **Step 2: Run the bootstrap lane green**

Run:
```bash
cmake --build --preset dev
ctest --preset harness --output-on-failure -R bootstrap
```
Expected: PASS locally (floor branch).

- [ ] **Step 3: Locate the harness-mutating pass and add the mapping mutation**

Run:
```bash
rg -n 'FILE \$\{RUNNER\} SPEC harness-self-tests.sps' test/support/cmake/SchemeMutationSuite.cmake
```
This locates the **self-test batch** — the batch whose `BYTE_MACHINE_MUTATION_VERIFY_COMMAND` runs `harness-self-tests.sps` and whose sibling mutations mutate the harness library via `FILE ${RUNNER}` (there `${RUNNER}` is the harness `.sls` path; the export-drop mutation ~:438 is one of them). Insert the new mutation among those siblings, **before that batch's `byte_machine_mutation_run`**:

```cmake
byte_machine_mutation(
  FILE ${RUNNER} SPEC harness-self-tests.sps
  LABEL "adapter: an os-table row maps to the wrong name"
  FIND [[("osx" . "darwin")]]
  REPLACE [[("osx" . "linux")]]
  EXPECT_STATUS 1
  EXPECT_OUTPUT_MATCHES "tarm64osx os")
```

Do **not** use `${RUNNER_BODY}` (that variable belongs to a later provenance batch that runs a different program, so the mutation would go uncaught) or a `byte-machine.*` spec label (no such spec exists — `cmake_parse_arguments` would fatal). `${RUNNER}` is the harness `.sls`, which contains the `("osx" . "darwin")` row; the verify command runs `harness-self-tests.sps`, whose Task 1 case label `"tarm64osx os"` fails `expected "darwin", got "linux"` → the lane exits 1.

- [ ] **Step 4: Bump the declared totals in the same edit**

In `SchemeMutationSuite.cmake`, increment `EXPECTED_MUTATIONS` by 1 (68 → 69) and update the header arithmetic comment (~lines 160–172) to account for the added mutation. `EXPECTED_PASSES` is unchanged (the mutation joins an existing pass). Re-measure, do not assume — read the current value first:

```bash
rg -n "EXPECTED_PASSES|EXPECTED_MUTATIONS" test/support/cmake/SchemeMutationSuite.cmake
```

- [ ] **Step 5: Run the Scheme mutation suite and confirm the new mutation is caught**

Run:
```bash
cmake --build --preset dev
ctest --preset pr --output-on-failure -R scheme-mutation
```
Expected: PASS, and the run reports the new declared totals (e.g. `31 passes / 69 mutations`) with the new mutation caught (not survived). If the suite reports a totals mismatch, the arithmetic comment or `EXPECTED_MUTATIONS` is wrong — fix before proceeding.

- [ ] **Step 6: Commit**

```bash
git add test/support/harness/self/harness-bootstrap.sps test/support/cmake/SchemeMutationSuite.cmake
git commit -m "test: witness the adapter os-table mapping with a mutation; strengthen bootstrap"
```

---

## Task 3: The GitHub Actions pipeline

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the `dev` configure/build presets and the `pr`/`release`/`no-scheme` ctest presets; the `BYTE_MACHINE_EXPECT_OS`/`BYTE_MACHINE_EXPECT_ARCH` env channel the harness now reads.
- Produces: green runs on macOS arm64 and Linux amd64, each asserting its cell identity.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/ci.yml`. macOS arm64 installs Chez via Homebrew (binary `chez`, measured at 10.4.1); Linux amd64 builds Chez from the pinned source release to guarantee the ≥10.4.1 floor (distro packages are frequently older and discovery would reject them). Each job exports its cell's ground truth so the harness asserts identity, and echoes the live machine type for the record.

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  macos-arm64:
    runs-on: macos-14           # Apple silicon runner (arm64)
    env:
      BYTE_MACHINE_EXPECT_OS: darwin
      BYTE_MACHINE_EXPECT_ARCH: arm64
    steps:
      - uses: actions/checkout@v4
      - name: Install Chez Scheme
        run: brew install chezscheme
      - name: Record the runtime identity
        run: |
          chez --version
          echo '(display (machine-type))(newline)' | chez -q
      - name: Configure and build
        run: |
          cmake --preset dev
          cmake --build --preset dev
      - name: Test (pr, then full)
        run: |
          ctest --preset pr --output-on-failure
          ctest --preset release --output-on-failure

  linux-amd64:
    runs-on: ubuntu-latest       # x86-64 (amd64)
    env:
      BYTE_MACHINE_EXPECT_OS: linux
      BYTE_MACHINE_EXPECT_ARCH: amd64
      CHEZ_VERSION: "10.4.1"
    steps:
      - uses: actions/checkout@v4
      - name: Build and install Chez Scheme from source (>= floor)
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential libx11-dev libncurses-dev uuid-dev git
          git clone --depth 1 --branch "v${CHEZ_VERSION}" https://github.com/cisco/ChezScheme.git
          cd ChezScheme
          ./configure --threads
          make -j"$(nproc)"
          sudo make install
      - name: Record the runtime identity
        run: |
          scheme --version
          echo '(display (machine-type))(newline)' | scheme -q
      - name: Configure and build
        run: |
          cmake --preset dev
          cmake --build --preset dev
      - name: Test (pr, then full)
        run: |
          ctest --preset pr --output-on-failure
          ctest --preset release --output-on-failure
      - name: Build-layer specs without a Scheme runtime
        run: |
          cmake --preset no-scheme
          ctest --preset no-scheme --output-on-failure
```

Notes for the executor:
- `chez --script` is what the lanes invoke; discovery finds `chez` (macOS) / `scheme` (Linux source install, on `/usr/local/bin`) via the candidate list — no `-DBYTE_MACHINE_CHEZ_EXECUTABLE` needed. If a runner ever hides Chez off `PATH`, add `-DBYTE_MACHINE_CHEZ_EXECUTABLE=$(command -v chez)` to the configure step.
- Pin `--branch "v${CHEZ_VERSION}"` to the floor; bump only with the version pin in `README.org`/discovery. If the Cisco tag naming differs (`v10.4.1` vs `10.4.1`), correct the ref — verify with `git ls-remote --tags https://github.com/cisco/ChezScheme.git` before finalizing.
- The `no-scheme` step runs only on Linux (one cell is enough to protect the 8/8 build-layer invariant); it configures with `BYTE_MACHINE_REQUIRE_CHEZ=OFF`, so it does not need the Chez install to pass.

- [ ] **Step 2: Lint the workflow locally**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml ok')"
```
Expected: `yaml ok`. (There is no Scheme/CMake test for the workflow file itself; it is validated by the first CI run.)

- [ ] **Step 3: Commit and push to a branch to exercise CI**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: first pipeline — macOS arm64 + Linux amd64, asserting cell identity"
```

CI cannot be verified locally. After pushing the branch and opening the PR, confirm both jobs go green and that the "Record the runtime identity" step prints `tarm64osx` (macOS) and `ta6le` (Linux) — the machine types the cell-identity assertions depend on. If a job is red, treat it as the real signal (this is the first time these mappings run on `ta6le`).

---

## Task 4: Whole-suite re-run, changelog, and close

**Files:**
- Modify: `CHANGELOG.md` (Unreleased section)

- [ ] **Step 1: Re-run the entire mutation surface**

Per AGENTS.md, adding assertions can disarm an existing mutation. Run the full suite, not just the new lanes:

```bash
cmake --build --preset dev
ctest --preset release --output-on-failure
```
Expected: everything green; the Scheme mutation suite reports its new declared totals; the CMake mutation suite is unchanged. Confirm no previously-caught mutation now survives (scan the suite output for `SURVIVED` that is not an `EXPECT_SURVIVES`).

- [ ] **Step 2: Add a changelog entry**

Under `## [Unreleased]` in `CHANGELOG.md`, add:

```markdown
### Added
- Continuous integration on macOS arm64 and Linux amd64 (the first CI in the
  repository), running the full test suite and asserting each cell's OS and
  architecture (Milestone 1, Phase 1).

### Changed
- The harness adapter derives OS and architecture through pure
  `machine-type->…` functions, tested exhaustively over the Tier-1 machine
  types, and the self-test/bootstrap lanes assert the live values by equality
  when the cell's identity is supplied, replacing the earlier not-"unknown"
  checks.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — first CI pipeline and exact adapter os/arch assertions"
```

---

## Self-Review

1. **Spec coverage (milestone-1-design.md §4):** pipeline on macOS arm64 + Linux amd64 → Task 3; adapter assertions exact (equality, not not-"unknown") → Tasks 1–2; two deferred cells not added → confirmed (matrix has two jobs only); D8 feasibility-notes half untouched → confirmed. §24.2 "assert the expected runtime, OS, and architecture" → the runtime name is already asserted in `harness-self-tests` (`adapter-runtime-name`); OS/arch now asserted by exact value.
2. **Placeholder scan:** no "TBD"/"handle errors". The only executor-resolved fill-ins are the exact `EXPECTED_MUTATIONS` number (must be re-measured, Step 4 says so) and confirming the Cisco tag name — both are "measure, don't guess" instructions, not placeholders.
3. **Consistency:** `adapter-machine-type->os`/`->architecture` are used with identical names in Task 1 (definition), Task 1 test, and Task 2 mutation. `BYTE_MACHINE_EXPECT_OS`/`BYTE_MACHINE_EXPECT_ARCH` names match across the harness read (Task 1/2) and the workflow env (Task 3). The `stopped`/status vocabulary is untouched by this phase.
4. **Risk called out:** only macOS arm64 is a measured mapping; `ta6le` runs for the first time in CI. The workflow prints the live machine type so a wrong mapping surfaces explicitly rather than silently.
