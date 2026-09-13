# Milestone 10 Slice ② — The v0.2.0 release and the close

Design: [milestone-10-design.md](./milestone-10-design.md) §6. Base: `main` at
`4f2f6e6` (Slice ① merged as PR #122, on top of M11 Gate 0 #121). Documentation +
version-surface only; no `src/` change (§4.7 gate holds — `git diff main..HEAD --
src/` prints nothing).

## The version-surface decision (release ledger for a second release)

The release ledger (`(byte-machine test release-ledger)`, decision 0038) is the
**release exit-criteria census**: its `§26`/`§27` rows mirror the parent plan's
frozen v0.1 criteria via a totality set-compare, and the 13-met / 2-amended /
0-open partition is those criteria's state. Those criteria are **unchanged** at
v0.2.0 — the append rule freezes `§26`/`§27`, the empty-span behaviour adds no
criterion row (it is recorded in `CHANGELOG.md` + decision 0042), and every v0.1
criterion still holds (the two amended remain the CI-blocked Tier-1 pair; the CI
budget is still zero). So the census rows and the partition stay as they are.

What moves is the **§4.5 version surface**: `release-version` is the single owner
of the *current* release string, so it becomes `"0.2.0"`, and the surfaces list
names the v0.2.0 mirrors. `release-version-export?` stays `#f` (no `version`
export; the public API adds no name — the only `src/` change this milestone was
`runtime.sls` internals). `current-abi-version` stays 5 (decoupled).

## Tasks

1. **Release ledger** (`release-ledger.sls`): `release-version "0.1.0"` → `"0.2.0"`;
   update `release-version-surfaces` to the v0.2.0 mirrors (CHANGELOG `[0.2.0]`
   entry, README status, parent-plan disposition, **milestone-10-design** status
   header, git tag); relabel the `§4.5` comment to note the version tracks the
   current release while the `§26`/`§27` census stays the (still-met) v0.1 criteria.
2. **Release-ledger tests** (`release-ledger-tests.sps`): `release-version` assertion
   `"0.1.0"` → `"0.2.0"`; keep the 13/2/0 partition (relabel its heading to "the
   release criteria, met through v0.2.0"); the `§26:1684` check keeps verifying the
   `[0.1.0]` entry exists (v0.1's, kept in history) and gains a check that the new
   `[0.2.0]` entry exists.
3. **CHANGELOG.md**: `[Unreleased]` "Nothing yet." → a dated `## [0.2.0] - 2026-09-13`
   section under `### Changed` (empty spans now deliver their data callback once;
   `§14` items 2/5 amended) and `### Added` (the observability), citing decision 0042;
   keep the `[0.1.0]` section and reset `[Unreleased]` to "Nothing yet."
4. **README.org**: status `=0.1.0=` → `=0.2.0=`; note that v0.2 adds empty-span
   observability while the rest of the public API stays frozen.
5. **Parent plan**: append the Milestone 10 close note to the dated dispositions
   (`§1802` foot); update the top Status line's milestone list to include M10.
6. **milestone-10-design.md**: status header OPEN → **CLOSED (v0.2.0 released)**;
   Slices ① and ② delivered.
7. **The five milestone-status surfaces** (AGENTS.md `:593-611`) all say M10 closed:
   this slice plan, the parent plan Status line, `CHANGELOG`'s `[Unreleased]`
   preamble, milestone-10-design.md, and `README.org`.

## The tag — held for after the merge

The annotated `v0.2.0` tag is an outward-facing release act and goes on the merge
commit on `main` **after** this slice merges (as `v0.1.0` did after M9's release
slice). It is not created on this branch; it is the post-merge step, taken on the
owner's explicit go-ahead.

## Verification

`(byte-machine test release-ledger)` green in both Chez modes with `release-version`
`"0.2.0"` and both CHANGELOG entries present; full suite green; `git diff main..HEAD
-- src/` empty. The mutation lane is unaffected (no `src/`/mutation change).

## Not in this slice

- Any `src/` change; any new `§26`/`§27` criterion; the `(byte-machine version)`
  export (still declined).

## Findings recorded this slice

- **The release ledger's second-release semantics, resolved.** The ledger is the
  release exit-criteria census; its `§26`/`§27` rows mirror the plan's frozen v0.1
  criteria (a totality set-compare), so they cannot be re-authored for v0.2 and
  need not be — every criterion still holds and the empty-span behaviour adds no
  row (append rule). Only `§4.5`'s `release-version` (the single owner of the
  *current* release string) moved, to `0.2.0`, with the surfaces and the two
  version assertions following; the 13/2/0 partition and the `[0.1.0]` CHANGELOG
  check stayed, and a `[0.2.0]` check was added beside it. The checked lane is the
  oracle — it stayed green through the bump.
- **M11 Gate 0 (#121) landed on `main` between Slice ①'s push and its merge.** It
  is docs-only (decisions 0043-0045 + `milestone-11-design.md`), orthogonal to
  everything Slice ① touched, so the squash of PR #122 sat cleanly on top; Slice ②
  is based on that `4f2f6e6` `main`. (`gh pr merge`'s output showed a stale-base
  diff listing the M11 files as "created"; the actual merge commit contains only
  Slice ①'s files — verified with `git show --stat`.)
- **No `src/` change** (`§4.7` gate): `git diff main..HEAD -- src/` is empty. The
  mutation lane is untouched (the ledger earns no mutation entry, decision 0038).
- **The tag is the one held act.** `v0.2.0` is annotated onto the merge commit
  after this slice merges, on the owner's go-ahead — an outward-facing release act,
  not created on this branch.
