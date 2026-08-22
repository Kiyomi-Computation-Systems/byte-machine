# Tier 1 CI feasibility: what each cell costs, and what only it can witness

Status: accepted — this note is the deliverable, not a plan for one
Date: 2026-08-22
Parent plan: [`byte-machine-implementation-plan.md`](./byte-machine-implementation-plan.md) §7.3 (the Tier 1 matrix) and §25 Milestone 0
Governing plan: [`milestone-0-portability-spike.md`](./milestone-0-portability-spike.md) §7 D8
Design document: [`milestone-0-close-out.md`](./milestone-0-close-out.md) §7, which specifies this note's required content
Discharges: parent §25 exit criterion 2 ("CI design covers unavailable local platforms"); spike §7 D8's **written feasibility notes** half; parent §25:1427 "documented Windows path and LF behavior"

**Goal:** state what a Tier 1 CI matrix would cover, cell by cell, at the level
of evidence each statement actually has. This is a design, not a pipeline. Spike
§7 D8's other half — the running pipeline — moved to Milestone 1 by
[decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md).

## 0. The evidence vocabulary this note uses

Four claims that are easy to blur and are kept apart throughout:

- **Measured** — a command was run on this host and its output is what the
  sentence reports. Every measurement below was taken on Darwin 25.5.0 arm64
  against Chez Scheme 10.4.1 (`machine-type` → `tarm64osx`) on 2026-08-22, and
  against the shipped tree, not a scratch fixture.
- **Documented, not verified on hardware** — an upstream man page, an upstream
  packaging convention, or CMake's documented behaviour says so, and no cell
  exists here to confirm it. Nothing in this class is an argument for skipping
  the cell; it is the reason the cell exists.
- **Uncited** — the sentence is a belief this note holds and cannot attribute:
  no man page, no upstream convention, and no record in this tree states it. It
  is weaker than "documented", and it is called out rather than dressed up
  because the cell that would settle it is the point of naming it.
- **Closed by construction** — the question has no object left in this tree to
  apply to, so no cell can answer it and none needs to. This is stronger than a
  documented answer and weaker than nothing only in the sense that it proves the
  question is gone rather than proving an answer.

Where a paragraph makes more than one kind of claim, each clause carries its own
label. A sentence with no label inherits the section's.

## 1. The four Tier 1 cells

Parent §7.3 fixes the matrix: Chez on Linux amd64, Linux arm64, macOS arm64, and
Windows amd64, **each in both source and AOT execution**. Two decompositions of
that matrix both come to eight, and they are not the same eight. Four platforms ×
source/AOT is eight **lane instances**, which
[0005](../decisions/0005-chez-only.md) did not reduce — under Chez alone both
lanes are still Chez lanes. Four platforms × two implementations was the spike's
eight **cells** (spike §7 D8:189, "both implementations"; spike §11:230, "the
full 8-cell matrix"), and that is the eight 0005 halved, to the four cells
tabulated below (corrected by the close-out's §6.2 rows S12 and S15). "Cell"
below always means one of those four.

| Cell | Chez obtained by | Binary name there | Probe handles it | Machine type | Only witness for |
| --- | --- | --- | --- | --- | --- |
| macOS arm64 | Homebrew formula `chezscheme` | `chez` | yes — measured | `tarm64osx` (measured) | no spike deliverable; the only cell reaching the `chez` name and the `osx` OS row |
| Linux amd64 | hosted runner; distribution package or upstream build | `scheme` or `chezscheme` | yes — by name list | `ta6le` (by inspection) | the first cell that makes any cross-cell claim non-vacuous |
| Linux arm64 | hosted arm64 runner **or** emulation; neither priced | `scheme` or `chezscheme` | yes — by name list | `tarm64le` (by inspection) | architecture varied with the OS held fixed |
| Windows amd64 | upstream Windows distribution | `scheme.exe` | by name plus CMake's suffix rule — documented, not verified | `ta6nt` (by inspection) | CRLF translation (spike §7 D7); Windows path form |

The "probe handles it" column resolves to one line in the shipped tree.
`cmake/ByteMachineChez.cmake:51` sets the candidate list to `scheme chez
chezscheme` — every binary name in the table above is either in that list or is
a list entry plus the platform executable suffix (`scheme.exe`, §1.4) — and identity
is then decided on probe output rather than on which name matched
(`:92` requires `Chez Scheme` in the banner, `:102` rejects Petite, `:139`
enforces the 10.4.1 floor). This is the collision
[0001](../decisions/0001-toolchain-discovery.md):12–14 was built for, and it is
why three of the four cells need no new discovery work.

### 1.1 macOS arm64 — the one cell that exists

**Measured.** Homebrew installs the `chezscheme` formula at 10.4.1 and names the
binary `chez`, where upstream names it `scheme` (`brew list --versions
chezscheme` → `chezscheme 10.4.1`; `chez --version` → `10.4.1`;
`(machine-type)` → `tarm64osx`). Every measurement in this repository was taken
here, and this is the only cell any of them describes.

It is the only witness for **none of spike §7's deliverables**, and that is the
point rather than a weakness. What it does carry alone is narrower than a
deliverable: the `chez` candidate name, which no other Tier 1 cell reaches (§3),
and the `tarm64osx` → arm64/darwin row of `harness.sls`'s OS table
(`harness.sls:99`), the one row of that table that has ever been evaluated.
Every *deliverable* claim it carries is a claim another cell would also carry;
what it cannot carry is any claim of the form "the same on two cells". Spike §7
D6's byte identity is identity *with* something, and until a second cell exists
this one supplies only the left-hand side.

### 1.2 Linux amd64 — the cell that makes cross-cell claims mean anything

**Documented, not verified on hardware.** The machine is a hosted runner, and on
it Chez arrives either from a distribution package or from an upstream build;
the packaged binary is `scheme` on some distributions and `chezscheme` on
others. Which distribution uses which name is **not verified here** and does not
need to be: both names are in the
probe's candidate list (`ByteMachineChez.cmake:51`), and the banner test at `:92`
is what decides identity, so the packaging variance is already absorbed. That
absorption is the verifiable part; the packaging convention is not.

This is the cell spike §7 D8's pipeline half was always scoped to reach
(spike §7 D8, "macOS arm64 + Linux amd64"). It is the only cell that turns
"byte-identical across cells" from a vacuous claim into a checkable one, because
it is the first second cell.

It varies two axes at once against macOS arm64 — operating system **and**
architecture — which is exactly why §1.3 is not optional.

### 1.3 Linux arm64 — deferred, and unpriced on purpose

**Deferred.** Two acquisition routes, and this note deliberately states them
without choosing:

1. A hosted arm64 Linux runner.
2. Emulation — an arm64 userspace under an amd64 runner.

**Neither has been priced, and neither is priced here.** A runtime or cost figure
taken on this host would describe this host, which is the defect AGENTS.md's
scratch-fixture rule names: a measurement earns a place in a design document only
once it has been re-taken against the shipped artifact, and there is no shipped
artifact for a cell that does not exist. Pricing belongs to the milestone that
stands the pipeline up, with the runner in hand.

One design constraint applies to the emulation route regardless of price, and it
is checkable from the shipped tree rather than from a runner. AOT object
directories are keyed by the runtime's own reported machine type —
`test/CMakeLists.txt:101` builds `chez-objects/${BYTE_MACHINE_CHEZ_VERSION}/${BYTE_MACHINE_CHEZ_MACHINE_TYPE}`,
and `:113–116` makes an empty value a configure-time fatal error rather than a
silently shared root. So an emulated cell is only the arm64 cell if the Chez
running inside the emulation reports an arm64 machine type; an amd64 Chez
running an arm64 workload would key its objects `a6le` and would be the amd64
cell wearing a different label. The keying makes that detectable rather than
assumed.

This cell is the **only** witness for architecture varied with the operating
system held fixed. With only macOS arm64 and Linux amd64, a byte difference
between the two cannot be attributed to either axis. That is not a hypothetical
concern about spike §7 D6 — it is what makes D6's result interpretable at all.

### 1.4 Windows amd64 — deferred, and the only cell that can exhibit CRLF

**Deferred.** Chez comes from the upstream Windows distribution, which names the
binary `scheme.exe`. The probe searches the base name `scheme`
(`ByteMachineChez.cmake:51`) via `find_program`, which applies the platform
executable suffix on Windows — **documented CMake behaviour, not verified here**,
and the first thing a Windows cell would confirm or refute.

Two things reduce the Windows exposure below what it looks like from here, both
verifiable in this tree today:

- The lanes invoke the interpreter directly with `--script` and an explicit
  launcher path (`cmake/ByteMachineSchemeLane.cmake:151–155` for the AOT lane,
  `:129` for source). **Measured:** no launcher under
  `test/support/launchers/` carries a `#!` line, and neither `scheme-script` nor
  any shebang appears anywhere in the launchers, `cmake/*.cmake`, or
  `test/CMakeLists.txt`. The `scheme-script`/`#!` route the manual documents at
  `chez.1`:515–521 — whose Windows behaviour that passage says nothing about, and
  would be a separate question — is therefore not used.
- Chez's compiled-object extension names Chez's own object format, not a shared
  library, so it is not the host's `.so`-versus-`.dll` distinction at all.
  **Measured here:**
  `(library-extensions)` returns `((".chezscheme.sls" . ".chezscheme.so")
  (".ss" . ".so") (".sls" . ".so") (".scm" . ".so") (".sch" . ".so"))`, so
  `byte_machine_chez_aot_paths`'s `${stem}.so` (`ByteMachineSchemeLane.cmake:81`)
  needs no platform branch on this host. That those defaults are the same on
  every platform is **uncited**: `chez.1` names `library-extensions` at :533,
  :538, and :572 and nowhere enumerates its defaults, and no record in this tree
  states them either. It is a one-line check on the Windows cell.

This is the **only** cell that can exhibit the CRLF translation spike §7 D7
names, and the only cell that can answer the Windows path-form question §2.4
leaves open.

## 2. Windows path and LF behavior

This section discharges parent §25:1427. The interesting fact is that the
exposure most readers reach for first was designed out of this project two
decisions ago, so §§2.1–2.4 are ordered to say that rather than to bury it.

Man-page citations below are to Chez Scheme 10.4.1's `chez.1` as installed on
this host at `/opt/homebrew/share/man/man1/chez.1.gz` (resolved with `man -w
chez`); line numbers are lines of the decompressed roff source, so they are
reproducible with `gunzip -c` and `sed -n`.

### 2.1 The separator exists, in the string forms of Chez's search settings

`chez.1`:548–553 fixes it:

> The format of the arguments to "--libdirs" and "--libexts" is the same: a
> sequence of substrings separated by a single separator character. The
> separator character is a colon (:), except under Windows where it is a
> semi-colon (;).

Note that the quotation already covers `--libexts` as well as `--libdirs`, and
the same string form reaches Chez through the environment twice over:
`chez.1`:565–567 says that with no `--libdirs` option present,
`CHEZSCHEMELIBDIRS`'s string value is treated as if it had been given to
`--libdirs`, and `:568–570` says the same of `CHEZSCHEMELIBEXTS` and
`--libexts`. A fifth form governs boot files rather than libraries and carries
the identical rule: `SCHEMEHEAPDIRS` "should be a colon-separated list of
directories" (`:684–685`) and "Under Windows, semi-colons are used in place of
colons" (`:695`, restated in the ENVIRONMENT section at `:750–754`).

So the separator belongs to the *string* forms of Chez's search settings — five
of them, not two — every one of which takes **one string** that Chez itself
splits. **This project sets none of them.** §2.2 shows the four call sites that
set the parameter instead, and re-runs the audit widened to all five names; the
paragraph above is a fact about the runtime, recorded so that §2.2 has something
to deny.

### 2.2 This project never uses those forms

**Measured.** No file in this repository passes `--libdirs` or `--libexts`, sets
`CHEZSCHEMELIBDIRS`, `CHEZSCHEMELIBEXTS`, or `SCHEMEHEAPDIRS`, or joins any
search path with `:` or `;`. The audit is
`rg -n -i "libdirs|libexts|CHEZSCHEMELIB|SCHEMEHEAPDIRS"` over the tree —
case-insensitive, and covering all five forms §2.1 names rather than only the
two that are easy to think of. It returns hits in documentation only, and this
is the whole list:

| File | Lines |
| --- | --- |
| [`0002`](../decisions/0002-shared-body-include-mechanism.md) | 26 |
| `milestone-0-portability-spike.md` | 210 |
| `milestone-0-close-out.md` (§7) | 387–389 |
| `milestone-0-close-out-implementation-plan.md` | 179, 200, 217 |
| this note | §2.1, §2.2 |

No hit is in a `.ss`, `.sls`, `.sps`, `.cmake`, or `CMakeLists.txt` file.
`CHEZSCHEMELIBEXTS` and `SCHEMEHEAPDIRS` occur nowhere in the tree except in
this note — which is the point of widening: the narrower search could not have
told the difference between absent and unlooked-for.

What the project does instead is set the `library-directories` **parameter**
directly, with a Scheme list of pairs, in each of the four Scheme entry points:

| Entry point | Line | Value |
| --- | --- | --- |
| `test/support/launchers/chez-source.ss` | 139–140 | `(map (lambda (root) (cons root object-guard-dir)) library-roots)` |
| `test/support/launchers/chez-aot.ss` | 183–184 | `(map (lambda (dir) (cons source-guard-dir dir)) object-dirs)` |
| `test/support/launchers/chez-compile.ss` | 153 | `(map cons library-roots object-dirs)` |
| `test/support/launchers/fingerprint-manifest.ss` | 59 | `(list (cons library-root object-guard-dir))` |

Every root arrives as its own argv entry and is never split, by two different
routes. The three lane launchers take repeatable flags — `--library-root`,
`--object-dir`, `--object-guard`, `--source-guard` — collected by `flag-values`
(`chez-source.ss:89–93`), which returns each occurrence whole and never splits a
value on anything. `fingerprint-manifest.ss` has no flags at all: it takes its
root and guard **positionally** from `(command-line-arguments)` (`:31–37`, usage
line at `:4`), and an argv entry read by `list-ref` is no more joined than a flag
value is. `cmake/ByteMachineSchemeLane.cmake:152–153` shows the build side for
the flag route: `--object-dir` appears twice as two separate arguments, not once
as a joined string. `chez.1`:534 confirms this is the parameter's native shape —
"The values of both parameters are lists of pairs of strings" — so neither route
is a workaround; the string form is the lossy convenience, and this project
declines it.

That is why [0002](../decisions/0002-shared-body-include-mechanism.md):143–147
records the question as **closed by construction**: "because the launcher takes
repeatable flags, byte-machine never joins Chez search paths with any separator
on any platform, so the `:` vs `;` question has no Chez-side object left to apply
to." 0002's "the launcher" is the lane launchers, which is what it measured; the
fourth site reaches the same closure by the positional route instead, and that
phrasing is not carried onto it. The closure survives 0002's own retirement by
[0006](../decisions/0006-inline-libraries.md) — what 0006 removed was
`--source-dir` and the include mechanism, not the flag protocol, and the four
sites above are the post-0006 tree.

**The separator is therefore recorded in this note as background about the
runtime, not as behavior byte-machine depends on.** No Tier 1 cell is needed to
answer it, and the Windows cell must not be justified by it.

### 2.3 The `/` in a library path is name resolution, not a separator

A second slash-shaped fact is easy to mistake for the first. `chez.1`:576–577
describes how the expander turns a library name into a path: it "first constructs
a partial name from the list of components in the library name, e.g., 'a/b' for
library (a b)", then (`:578–581`) searches that partial name in each pair of root
directories in order, trying each source extension and then each object extension
before moving to the next pair. `chez.1`:541–546 states the same rule from the
other end: the full path is the root, followed by the library-name components
"prefixed by slashes", with the extension appended.

That `/` is Chez joining *library-name components*, not the host joining *search
paths*. It is fixed by the library name — described as "slashes" in the flat
statement at `:541–543`, which uses the word and not the glyph, and written
literally as `/` in the worked example at `:576–577` — and it is what makes
`/`-delimited roots the portable form: a root written with forward slashes
concatenates correctly with a partial name Chez has already built with forward
slashes. That the character is the same on Windows is **uncited**: the manual
attaches no platform qualification to either passage, but neither does it state
platform-independence, and no cell here has exercised it. What the manual does
make clear is that this is a resolution rule rather than an argument-parsing
one, so nothing in §2.1's separator clause applies to it.

### 2.4 What genuinely stays open on Windows is path form

[0002](../decisions/0002-shared-body-include-mechanism.md):149–151 already named
it, and nothing since has narrowed it:

> Nothing here was measured on Windows, where path splitting and what counts as
> absolute both work differently (backslashes, drive letters).

Two concrete unknowns follow from §2.3's citation rather than from speculation.
First, the roots the build hands the launchers are CMake-normalised absolute
paths, which on Windows carry a drive letter — whether Chez accepts `C:/…` as a
root, and how it concatenates it with a `/`-prefixed partial name, is unmeasured.
Second, `chez.1`:582–585 gives an absolute *library name* its own resolution
path — "If the partial name is an absolute pathname … only the specified absolute
path is searched" — so "what counts as an absolute pathname" is a question Chez
itself asks, and its Windows answer is unmeasured here.

**Unmeasured. Arrives with the Windows cell.** This — not the separator — is the
Windows question the cell is for.

### 2.5 LF

The read side is already handled, and was handled for this exact reason. The
fingerprint reader opens files as a binary port; its comment at
`test/support/harness/byte-machine/test/fingerprint.sls:50–52` says why:

> Fingerprints a file's exact bytes. A binary port, so the value is a
> fingerprint of bytes rather than of decoded characters -- and so an LF is
> an LF on a platform whose text ports would translate it.

**Measured (as code, not as behaviour on Windows):** `open-file-input-port` plus
`get-bytevector-all` at `fingerprint.sls:59–60`, and the same pair at
`test/support/harness/byte-machine/test/harness.sls:156–157`; those two are the
only file readers in the harness, so no harness path decodes a file as text.

The **write** side does not exist. Spike §7 D7 — "LF bytes survive a binary port
unmodified — the Windows CRLF-translation trap" — is a property of an emitter,
Milestone 0 ships no emitter (spike §11), and
[decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md) moved D7
to Milestone 1 with the emitter's `emit-machine` contract, which parent §20:1046
already fixes in the terms this note needs — it "writes only to the supplied
binary output port", and "Generated source is canonical UTF-8 with LF bytes even
on Windows". That is the requirement stated; nothing implements it yet, and no
cell has tested it. Until then the LF claim is
half-discharged by construction on the read side and **unbuilt** on the write
side. Neither half is a measurement on Windows, and only the Windows cell can
make either one.

## 3. What each cell would prove that this host cannot

Three obligations, and the cells they need.

**Spike §7 D6 — cross-cell byte identity.** Needs at least two cells to be
non-vacuous (Linux amd64 is the first), and three to be interpretable (Linux
arm64 separates the architecture axis from the operating-system axis). This host
can prove determinism *within* a cell — the source and AOT lanes already agree on
one content fingerprint, which is what the 5b remainder delivered — and that is a
strictly weaker claim, as [0005](../decisions/0005-chez-only.md):159–165 said
when it refused the same substitution. No amount of local repetition converts it.

**Spike §7 D7 — LF through a binary port.** Needs Windows amd64, the only Tier 1
cell whose text ports translate. On the other three cells a text port and a
binary port produce the same bytes for LF, so a test that passes there is
consistent with the binary port having been dropped — an unwitnessable decision
on this host in exactly AGENTS.md's sense: not "cannot be tested", but "cannot be
tested *here*", with the witness named.

**The probe's own portability.** Between them the cells reach more than one row
of `BYTE_MACHINE_CHEZ_CANDIDATE_NAMES` — but not four, because the list is three
names for four cells (`ByteMachineChez.cmake:51`, `scheme chez chezscheme`).
macOS arm64 is the only cell that reaches `chez`; the two Linux cells reach
`scheme` or `chezscheme` (§1.2), and Windows amd64 reaches `scheme` as
`scheme.exe` (§1.4). What each cell *does* reach alone is a machine type no other
cell has, and the harness's OS/architecture derivation is where that lands.
`harness.sls:88–95` maps machine-type architecture prefixes (`arm64`, `a6`, …)
and `:97–107` maps operating-system suffixes (`le` → linux, `osx` → darwin,
`nt` → windows, …); `:114–127` does the two-stage lookup. All four Tier 1 cells
resolve correctly **by inspection** — `ta6le` → amd64/linux, `tarm64le` →
arm64/linux, `tarm64osx` → arm64/darwin, `ta6nt` → amd64/windows — and exactly
one of those, `tarm64osx`, has ever been evaluated. The other three rows are
code that has never run.

One caveat about what a cell would buy there, stated because it changes what the
pipeline has to do rather than only where it runs. The shipped assertions are
*not-unknown* checks, not expected-value checks:
`harness-self-tests.sps:368–370` and `harness-bootstrap.sps:119–122` assert only
that `adapter-os` and `adapter-architecture` differ from `"unknown"`. A cell
therefore witnesses that its machine type resolves to *something*, not that it
resolves to the right thing: a table row mapping `nt` to the wrong name would
still pass on Windows. Parent §24.2:1392 (item 2 of the CI stages list, whose
heading is at parent :1389) asks for more than that — "In every Tier 1 cell,
assert the expected runtime, OS, and architecture" — so standing the
matrix up includes tightening those two assertions to compare against the value
the cell declares. Getting the runner is necessary and not sufficient.

## 4. What is not proposed

No pipeline. No runner configuration. No workflow file. No CI provider is named
above, and no cell is scheduled.

Those are spike §7 D8's other half, which
[decision 0007](../decisions/0007-milestone-0-closes-at-the-harness.md) moved to
Milestone 1, where it rides spike §7 D6's cross-cell axis because both need these
same four cells — and where parent §25's Milestone 9 already owns "complete Tier 1
CI" (§25:1602). "Complete" presupposes something to complete, which is the
division: Milestone 1 stands the matrix up on the cells it can get, Milestone 9
finishes it.

The cost of that ordering is stated in 0007 and is not softened here: a
portability regression introduced during Milestone 1 surfaces later than it would
have with a pipeline in place. This note is what makes it surface *findable* — it
records, per cell, what would have caught it.
