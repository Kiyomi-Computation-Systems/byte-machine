# 0002: The launcher takes repeatable flags instead of a separator-joined path list

Date: 2026-08-16
Status: accepted
Milestone: 0, slice 3

Superseded: 2026-08-18 by [0006](./0006-inline-libraries.md) — the include
mechanism this record decides is retired; bodies now live inline in their
owning libraries. The measurements and the repeatable-flags decision remain
valid history (the flag protocol survives; `--source-dir` itself does not).

## Context

Milestone 0 decision D6 chose `source-directories` plus bare filenames for
Chez's `include`; decision D1 chose a source-relative `include` inside
`define-library` for Gambit — see [the milestone plan](../.plans/milestone-0-portability-spike.md)
§2 and §6. (The milestone plan reuses the label `D6` for an unrelated §7
deliverable, deterministic text emission; this record's `D6` is always the §5
decision.) Slice 3 put the first product code behind that choice: one
wrapper-free body, `src/common/byte-machine/placeholder.scm`, included by
exactly one owner library per runtime (`src/chez/byte-machine/placeholder.sls`,
`src/gambit/byte-machine/placeholder.sld`) — see
[the slice-3 design](../.plans/milestone-0-slice-3-shared-body.md) §3–§6.

Milestone plan §9 question 3 asks what library search paths look like on
Windows, "including the `--libdirs` separator (`:` vs `;`) and `/`-only path
splitting". Slice 3's own design record (§2) measured this behavior
against scratch fixtures, before the design was accepted, to decide how the
launcher should carry more than one root. This record reconfirms the same
behavior against what actually shipped — the real launcher and the real body,
not pre-design scratch copies — and states what §9 question 3 can and cannot
be answered from a single macOS host.

## Measurements

Measured 2026-08-16, Darwin 25.5.0 arm64, Chez 10.4.1, Gambit 4.9.8. The two
Chez measurements run the real launcher
(`test/support/launchers/chez-source.ss`) against the real shared body
(`src/common/byte-machine/placeholder.scm`) through its real owner library
(`src/chez/byte-machine/placeholder.sls`); only the working directory, the
decoy file, and the `--source-dir` value under test are scratch fixtures built
for the purpose. The two Gambit measurements use minimal scratch libraries,
since no product library yet needs a second search root. All four are
reproducible from what is now in the tree.

- **`source-directories` takes precedence over the process working
  directory.** Launcher run with `--source-dir` correctly pointed at
  `src/common/byte-machine`, from a working directory holding a same-named
  decoy `placeholder.scm` whose every export answers wrongly:

  ```
  marker=#(byte-machine-marker)
  value=genuine
  ```

  Exit 0, and both values are the genuine body's, not the decoy's
  (`#(decoy-in-cwd)` / `decoy-in-cwd`). The decoy sitting in the working
  directory was never read.

- **There is no working-directory fallback.** Same decoy-holding working
  directory, `--source-dir` now pointed at a directory that does not contain
  `placeholder.scm` (the program's own directory, which the launcher also
  appends, does not contain it either):

  ```
  Exception in include: file "placeholder.scm" not found in source directories
  ```

  Exit 255, and the decoy file is still sitting untouched in the working
  directory afterward — Chez did not fall back to it. This is the reading
  milestone plan §2's line "Chez `include`, bare relative path → resolves
  against process CWD" needs: that line describes the *default* value of
  `source-directories`, which contains `"."`. `chez-source.ss` sets
  `(source-directories (append source-dirs (list (path-directory
  program))))` — never `"."` — so once the launcher has run, the working
  directory is out of the search entirely, not merely deprioritized.

- **`gsi -:search=A,search=B` resolves libraries from two roots at once.** Two
  scratch libraries, `(pkg alpha)` under root A and `(pkg beta)` under root B,
  imported by one program:

  ```
  $ gsi -:search=A,search=B -f program.scm
  alpha
  beta
  ```

  Exit 0. With only root A on the path:

  ```
  $ gsi -:search=A -f program.scm
  *** ERROR IN "program.scm"@1.21-1.31 -- Cannot find library (pkg beta)
  ```

  Exit 70. The second root is load-bearing, not decorative — a lane that only
  ever needed one root before slice 3 would not have noticed this.

- **A search root containing a comma makes `gsi` print its runtime-options
  usage banner and run no Scheme at all.**
  `-:search=<dir-with-a-comma-in-its-name>` produced

  ```
  Usage: program [-:OPTION,OPTION...] ...
  ```

  followed by the full runtime-options help text (exit 64 in this
  measurement), instead of anything from `program.scm`. Nothing in the
  failure names this project, the missing library, or even Scheme. `-:`
  options are comma-separated, so a path segment containing one is
  indistinguishable from an option boundary.

## Decision

1. **The Chez launcher takes repeatable flags, never a joined path string.**
   `--library-root <dir>` and `--source-dir <dir>` may each be given more than
   once (`test/support/launchers/chez-source.ss`), and
   `byte_machine_scheme_lane_command` (`cmake/ByteMachineSchemeLane.cmake`)
   emits one `--source-dir` per shared-body directory rather than joining them
   with a separator. A separator-joined alternative was considered during
   slice 3's design and rejected outright, because it would reopen question
   3's `:` vs `;` for a problem repeatable flags make disappear rather than
   resolve one way or the other.
2. **Gambit's search-path separator is not byte-machine's to choose.**
   `-:search=A,search=B` is Gambit's own runtime-option syntax; the comma is
   fixed by `gsi` itself on every platform it runs on, not by the host OS's
   PATH convention. `byte_machine_scheme_lane_gambit_search` joins roots with
   `,` for exactly this reason.
3. **A Gambit search root is refused at configure time if it contains a comma
   or is not absolute, before `gsi` is ever invoked.** The comma check exists
   because of this record's third measurement: an unrefused comma silences
   every Gambit lane in the same build at once, with a message naming nothing
   byte-machine owns. The absolute-path check exists because a relative root
   is resolved against `gsi`'s own working directory rather than against
   anything the build controls — the Gambit-side analogue of the second
   measurement, confirmed structurally rather than empirically, since
   Gambit's `include` inside `define-library` is source-file-relative and no
   Scheme-level mutation can make a Gambit lane working-directory-dependent.
   Only a relative *search root* can, and that is a build-layer mistake,
   refused before any Scheme process runs.

## Consequences

- Milestone plan §9 question 3 is answered for macOS arm64, and **closed for
  the Chez side by construction**: because the launcher takes repeatable
  flags, byte-machine never joins Chez search paths with any separator on any
  platform, so the `:` vs `;` question has no Chez-side object left to apply
  to. Gambit's separator is fixed by Gambit at `,`, independent of host OS,
  and a root containing one is refused before it would ever matter.
- The Windows half of question 3 stays open until CI (D8). Nothing here was
  measured on Windows, where path splitting and what counts as absolute both
  work differently (backslashes, drive letters). D8's four deferred Tier 1
  cells — Linux arm64 and Windows amd64, both implementations — still need
  the written feasibility notes the milestone plan's exit criteria (§12)
  require; this record is not one, and does not stand in for one.
- Exit statuses 255 (Chez, an uncaught `include` exception) and 70 (Gambit,
  library not found) both fall outside the harness's declared status
  vocabulary of `{0, 1, 2, 3}` (`.plans/milestone-0-slice-2-test-harness.md`,
  decision S3; enforced by `cmake/ByteMachineExpectExit.cmake`). A broken
  include therefore surfaces as its own out-of-vocabulary failure, distinct
  from every declared status, rather than being misread as a failed assertion
  inside a suite that never had the chance to run one.
- All four measurements are single-host, single-version evidence: one macOS
  arm64 machine, Chez 10.4.1, Gambit 4.9.8. Nothing here is a claim about any
  other release of either runtime, or about any other Tier 1 platform.
