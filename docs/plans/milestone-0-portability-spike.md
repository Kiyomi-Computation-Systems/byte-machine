# Milestone 0: Portability and Harness Spike

Status: ready to implement; all decisions closed
Date: 2026-08-15
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §25 Milestone 0
Scope decision: **Milestone 0 only.** No byte-machine semantics (no IR, verifier, interpreter, emitter, or runtime) are implemented in this milestone.

> **Amended 2026-08-18 by [decision 0005](../decisions/0005-chez-only.md): Gambit
> and R7RS leave the project contract.** This document is a record and keeps all
> of its Gambit content — the §2 environment facts, the D1 and D3 findings, and
> the four-lane model taken from protium were true when they were taken, and a
> record edited to agree with a later decision stops being evidence of anything.
> What changed *after* it: **D2's `.sld` half is dead** — the shared body now
> has a single R6RS `.sls` owner, not a paired `.sls`/`.sld`; deliverable
> **D5 closes at two lanes** (`chez.source`, `chez.aot`) rather than four,
> and **slice 5c is cancelled** —
> it existed only to add Gambit's `.o1` and `gsc -exe -nopreload` modes; **D6's**
> deterministic-emission proof becomes a single-implementation, cross-platform
> claim rather than a Chez-versus-Gambit one; **D8's CI covers Chez only**.
> Slice 5b's scope is unchanged. See
> [chez-only-simplification.md](./chez-only-simplification.md).

## 1. Why this milestone exists

Section 7 of the parent plan asserts a portability contract — wrapper-free shared `.scm` bodies, thin Chez `.sls` / Gambit `.sld` wrappers, singleton identity preserved across library boundaries, byte-identical deterministic emission — but nothing in this repository proves it. Milestone 1 depends on that contract holding end to end, including §9.6 item 8 ("compile and run the consumer natively").

A pre-planning spike ran against the real local toolchain. Its findings are in §2. **A sibling project, `~/github/protium`, has already solved most of this milestone**; §3 records what it settled and what byte-machine should take from it.

## 2. Confirmed environment facts

Measured on this machine (Darwin 25.5.0, arm64) on 2026-08-15.

| Fact | Value | Consequence |
| --- | --- | --- |
| Chez Scheme | 10.4.1 | Matches protium's pinned requirement (threaded, full system, not Petite) |
| Chez binary | `/opt/homebrew/bin/chez` (also `petite`, `scheme-script`) | Homebrew renames upstream `scheme` to `chez`. Linux distros ship `scheme` or `chezscheme`. **Binary name is not portable**, and a `scheme` on `PATH` is not necessarily Chez. Probe by banner. |
| Gambit | v4.9.8, `aarch64-apple-darwin25.6.0` | Matches protium's pin ("4.9.8, exactly") |
| Gambit binaries | `/opt/homebrew/opt/gambit-scheme/bin/{gsi,gsc}` | Keg deliberately **not linked**. `gsi` is absent from `PATH`; `gsc` on `PATH` is **GhostScript**. Find `gsi`, then derive `gsc` from the same directory — never search for `gsc`. |
| Gambit native C toolchain | requires `gcc-16` on `PATH` | Hard-coded as `C_COMPILER="gcc-16"` in `gambuild-C` by the Homebrew build config. Removing `/opt/homebrew/bin` from `PATH` breaks `gsc -exe` linking outright. Relevant to CI, which will likely build Gambit from source with a controlled `CC`. |
| Chez `include`, bare relative path | resolves against **process CWD** | Not source-file-relative. Holds in source mode, `compile-library`, and `compile-program`. |
| Chez `include` via `source-directories` | **works**, from any CWD | Include by bare filename; the launcher sets `(source-directories ...)` before importing. This is protium's mechanism. |
| Gambit `include` in `define-library` | **source-file-relative** (R7RS-conformant) | Works from any CWD with `-:search=<dir>`. |
| Cross-library singleton `eq?` identity | holds on both implementations | §7.2's "one owner wrapper per shared body" rule is sound, in source and compiled modes. |
| Gambit `gsc -exe` + user `.sld` | **works** — see §3.1 | Requires the module to be *named*, not *pathed*. |
| Tier 1 cells available locally | 1 of 8 (macOS arm64) | Linux amd64/arm64 and Windows amd64 require CI. |

### 2.1 Corrections to the first spike

Two conclusions in the first pass were wrong. Both are recorded because the wrong versions were briefly load-bearing:

- **"`source-directories` does not affect Chez `include`."** False. The spike wrote a boot script setting it and never loaded it. Chez resolves bare-filename includes through `source-directories` correctly, from any working directory.
- **"`gsc -exe` is broken with user `.sld` libraries."** False. See §3.1.

## 3. What protium already settled

`~/github/protium` is a sibling Kiyomi project (libuv bindings for Chez and Gambit) with the same `AGENTS.md` standards and the same two-runtime portability problem. It is pre-release but its build and harness layers are mature. It runs **one unchanged shared body through four execution lanes** — Chez source, Chez AOT, Gambit `.o1`, and Gambit `-exe -nopreload` — and requires all four to report the same content fingerprint.

Directly relevant prior art:

| Concern | Protium's answer |
| --- | --- |
| Toolchain discovery | `find_program(NAMES scheme chez chezscheme)` then a probe script interrogates the candidate; rejects Petite and non-Chez. Gambit found via `gsi`, `gsc` derived from its directory. |
| Chez shared-body include | Bare filename + `source-directories` set by the launcher |
| Gambit shared-body include | Plain R7RS source-relative `include` |
| Gambit native linking | `gsc -f -o <exe> -exe -nopreload . <module-name> <program>` (§3.1) |
| Build entry points | CMake + checked-in presets, with a thin `Makefile` providing `build` / `dev` / `test` / `test-all` / `prod` / `clean` |
| Test harness | Shared bodies + per-runtime adapter (`harness.sls` / `harness.sld`) exporting identical names; includes deterministic PRNG, deadlines, fingerprinting, and self-tests |
| Execution-mode honesty | Compiled lanes replace or delete staged sources so a lane that fell back to interpretation cannot report success |

### 3.1 Gambit native linking — the actual recipe

Verified against this repository's spike:

```
cd <library-root>
gsc -f -o <executable> -exe -nopreload . <module/name-without-extension> <program.scm>
```

Three details are load-bearing, all documented in protium's `cmake/ProtiumGambitLink.cmake`:

- **The module is named, not pathed.** `bm/model` links and runs; `bm/model.sld` links successfully and then dies at startup. This was the entire cause of the "blocker" in the first spike pass.
- **`-o` must precede `-exe`.** The other order is accepted with a warning, then ignored, leaving the executable somewhere the build does not look.
- **`-nopreload` makes failure diagnosable.** Without it, a wrong module reference exits **70 silently**. With it, the same mistake reports `*** ERROR IN ##collect-modules -- Module not found (##get-module 'bm/model)`.

Use `-nopreload` in every Gambit link, including exploratory ones.

## 4. Previously open decisions, now closed

Both were first answered on the basis of the §2.1 errors, and were reconfirmed once those were corrected:

- **O1 — Chez include mechanism.** Resolved: `source-directories` + bare filename, as protium does. The `include-relative` macro (§6) is retained as documented prior art, not used.
- **O2 — Protium infrastructure reuse.** Resolved: mirror protium's patterns into byte-machine under its own names.

## 5. Decisions taken

| # | Decision | Rationale |
| --- | --- | --- |
| D1 | Gambit uses plain R7RS `include`; native links use the §3.1 recipe with `-nopreload` always | Verified working; matches protium |
| D2 | CI now covers macOS arm64 + Linux amd64 for both implementations; full 8-cell Tier 1 matrix lands in Milestone 9 | Catches portability drift early without blocking on Windows and arm64-Linux runners. Cross-cell byte-identical comparison (§24.2 stage 7) is partial until M9 and must be labelled as such. |
| D3 | Toolchain binaries are discovered by probe, never by bare name; `gsc` is derived from a confirmed `gsi` | Forced by the GhostScript collision and Chez's non-portable binary name. Matches protium exactly. |
| D4 | Milestone 0 ships no byte-machine semantics | Parent plan §25: "no semantic implementation is duplicated in wrappers." The placeholder tagged value exists only to prove identity across boundaries and is deleted in Milestone 1. |
| D5 | Execution lanes follow protium's four-lane model, plus byte-machine's own cross-implementation generated-source comparison | §22 and §24 need exactly this; §24.2 stage 7 additionally needs byte-identical *generated* source, which protium has no analogue for. |
| D6 | Chez shared bodies are included by bare filename, resolved through a launcher-set `source-directories` | Documented public Chez API, no `syntax-case`, and identical to protium so a contributor learns one mechanism across both repos. Consequence: every launcher must set it, and shared-body basenames must be unique across all source directories — enforce that with a build-time check rather than by convention. |
| D7 | Protium's build and harness patterns are mirrored into byte-machine under its own names: CMake modules, checked-in presets, a thin `Makefile` (`build`/`dev`/`test`/`test-all`/`prod`/`clean`), probe-based toolchain discovery, and the shared-body-plus-adapter harness | Proven against the same two runtimes and the same standards. Accepted cost: real duplication between two repositories, which will drift. Extracting a shared package stays open as later work once both projects' needs are known. |

## 6. Chez `include-relative` macro (recorded, not used)

Not the chosen mechanism (see D6), but recorded because it is verified working and is the fallback if a downstream consumer ever needs to include a generated body from its own tree without launcher cooperation (§9.6 item 5). Verified in source mode, under `compile-library`, and under `compile-program`, from arbitrary working directories.

```scheme
(library (byte-machine include-relative)
  (export include-relative)
  (import (chezscheme))
  (meta define (bm-dirname p)
    (let loop ((i (- (string-length p) 1)))
      (cond ((< i 0) ".")
            ((char=? (string-ref p i) #\/) (substring p 0 i))
            (else (loop (- i 1))))))
  (define-syntax include-relative
    (lambda (x)
      (syntax-case x ()
        ((k filename)
         (let* ((ann (syntax->annotation #'k))
                (src (and ann (annotation-source ann)))
                (sfd (and src (source-object-sfd src)))
                (path (and sfd (source-file-descriptor-path sfd))))
           (if (not path)
               (syntax-violation 'include-relative "no source path" x)
               (let ((full (string-append (bm-dirname path) "/"
                                          (syntax->datum #'filename))))
                 (with-syntax ((inc (datum->syntax #'k 'include))
                               (fn  (datum->syntax #'k full)))
                   #'(inc fn))))))))))
```

Two details are load-bearing and would need regression tests:

- `bm-dirname` must be `meta define`; a plain `define` raises "attempt to reference out-of-phase identifier".
- The `include` identifier must be reintroduced with `(datum->syntax #'k 'include)`. Using the template's own `include` makes the included definitions invisible to the library's `export` list ("missing definition for multiple exports").

Trade-off against `source-directories`: the macro needs no launcher state and resolves correctly for a *consumer* including a generated body from its own tree (§9.6 item 5), but it is more machinery and diverges from protium. `source-directories` uses only documented public API and matches the sibling project, but requires every launcher — including a downstream consumer's — to set it, and puts all shared bodies in one flat basename namespace.

## 7. Deliverables

Each is a testable artifact, not a note.

- **D0 — Toolchain discovery.** Probe-based detection for both runtimes, banner-verified, rejecting Petite and GhostScript. Pinned minimum versions recorded.
- **D1 — Repo skeleton.** `src/common/`, `src/chez/`, `src/gambit/`, `test/`, `build/` (gitignored), `docs/decisions/`.
- **D2 — Shared body loaded through both wrappers.** One wrapper-free `.scm` body, one `.sls`, one `.sld`, no duplicated semantics. Includes a build-time check that shared-body basenames are unique, since D6 puts them in one flat namespace.
- **D3 — Cross-library identity smoke path.** Owner wrapper constructs a placeholder tagged vector; a second wrapper recognises it; an allocation-free singleton retains `eq?` identity across both imports. Runs in every execution lane.
- **D4 — Portable test harness + thin runners.** Dependency-free (no SRFI-64, no package manager) per §22.2: shared assertion/result code, thin Chez and Gambit adapters owning imports, process exit codes, and compilation steps. Mirrors protium's harness structure; adapters on both runtimes must export exactly the same names.
- **D5 — Execution lanes.** Chez source, Chez AOT, Gambit `.o1`, Gambit `-exe -nopreload`. Compiled lanes must be unable to silently fall back to source.
- **D6 — Deterministic text emission proof.** Both implementations write byte-identical canonical UTF-8/LF output through a project-owned writer; compared by fingerprint, never via implementation `write` formatting.
- **D7 — Identifier repertoire and binary LF proof.** Permitted `[a-z][a-z0-9-]*` names accepted; uppercase, non-ASCII, and punctuation rejected. LF bytes survive a binary port unmodified — the Windows CRLF-translation trap.
- **D8 — CI (macOS arm64 + Linux amd64, both implementations)** plus written feasibility notes for the four deferred Tier 1 cells.
- **D9 — Decision records** in `docs/decisions/` and initial `CHANGELOG.md`.

## 8. Work order

Ordered so each slice is independently verifiable, TDD-first per §22.1.

1. **Skeleton + toolchain discovery** (D0, D1). Exit: discovery reports both runtimes and versions on a clean checkout, and fails loudly when `gsc` resolves to GhostScript.
2. **Test harness + adapters** (D4). Exit: a deliberately failing assertion produces a nonzero exit code on both implementations; a passing one produces zero. The harness must be able to fail before it is trusted to pass.
3. **Shared body through both wrappers** (D2). Exit: identical shared body loads through both wrappers from at least three different working directories.
4. **Cross-library identity smoke path** (D3). Exit: tagged-value recognition and singleton `eq?` identity hold on both implementations.
5. **Execution lanes** (D5). Exit: all four lanes green over the same shared body, agreeing on a content fingerprint.
6. **Deterministic emission + identifier/LF proofs** (D6, D7). Exit: byte-identical output across implementations; every rejection case rejected.
7. **CI + decision records** (D8, D9). Exit: green on both cells; deferred cells documented, not assumed.

## 9. Questions this milestone must answer

Mapped from parent plan §30. Answers land in `docs/decisions/`, backed by tests.

1. Minimum Chez and Gambit releases providing the required module/include and bytevector surface. *(Local evidence: Chez 10.4.1, Gambit 4.9.8 — both matching protium's pins. CI must establish the actual floor.)*
2. Exact source and native compiler commands per Tier 1 platform. *(§3.1 answers Gambit native on macOS arm64.)*
3. Relative includes and library search paths on Windows — including the `--libdirs` separator (`:` vs `;`) and `/`-only path splitting.
4. Portable condition construction exposed by the wrappers.
5. Which allocation/GC metrics the benchmark harness can collect consistently.
6. Identifier length and source-size limits in supported compilers.
7. Whether the direct `case` layout reveals a correctness-neutral compiler issue.

Questions 5–7 may be answered as "deferred, with rationale" if Milestone 0 cannot reach them without implementing semantics; 1–4 are hard requirements.

## 10. Parent-plan corrections (folded in)

Found while reading; small, but worth fixing before code depends on them. The
first three have been applied to the implementation plan.

- **§7.2 dependency diagram is missing an edge.** `make-interpreted-machine` returns a runtime-compatible compiled-machine, and callbacks must return the runtime's singletons, so `interpret` depends on `runtime`. The diagram shows `runtime` with no incoming edge.
- **§9.2 API asymmetry.** `compile-machine` takes a *machine*; `make-interpreted-machine` takes a *verification*. That means a verification result must carry its machine, not just diagnostics. Worth stating explicitly in §9 rather than leaving it implied.
- **Milestone 1 must accept EOF declarations it cannot yet execute.** `make-machine` requires `default-eof-error` and §16.2 mandates EOF-target checks, but `parser-finish!` is Milestone 2. M1 should construct and verify EOF declarations while leaving EOF *execution* to M2, so the slice does not sprawl.
- **D3's "every execution lane" is sequenced by the work order, not simultaneous with it.** §8 puts the cross-library identity path at item 4 and execution lanes at item 5, so slice 4 proves D3 on source lanes only; slice 5 extends the same two programs to the compiled lanes at no added design cost. D3's own wording is unchanged — see slice 4's decision U6.

## 11. Explicitly out of scope

Source IR, constructors, verifier passes, normalizer, interpreter, emitter, runtime, HTTP fixture, benchmarks, and the full 8-cell matrix. The placeholder tagged value from D3 is deleted in Milestone 1.

## 12. Exit criteria

Per parent plan §25 Milestone 0, plus what the spike added:

- the same shared test body passes on Chez and Gambit, from multiple working directories;
- no semantic implementation is duplicated in any wrapper;
- singleton identity and tagged-value recognition hold across library boundaries in every execution lane;
- all four execution lanes agree on a content fingerprint, and no compiled lane can silently fall back to source;
- deterministic byte-identical text emission is proven between implementations;
- toolchain discovery works without bare binary names and detects the GhostScript collision;
- CI is green on macOS arm64 and Linux amd64 for both implementations;
- the four deferred Tier 1 cells have written feasibility notes;
- §30 questions 1–4 are answered in `docs/decisions/` and backed by tests.

## 13. Sequencing after Milestone 0

Milestone 1 is the whole architecture end to end in a narrow slice — builder, verifier, interpreter, normalizer, emitter, runtime, deterministic output, and two cross-implementation examples. It should be planned as several sub-slices rather than a single unit, roughly: descriptors and name resolution → minimal verification → reference interpreter → emitter and runtime → the §9.6 examples. Its first proving machine stays exactly as the parent plan specifies: accept one exact byte and stop, reject every other byte at the correct position, across all 256 byte values.
