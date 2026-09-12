# Milestone 9 Slice ⓪ — the release ledger, the version surface, and the licence review

**Status: implemented 2026-09-12. Green in both Chez modes (release suite 138 → 140).**

Slice ⓪ of Milestone 9 (design §5), decision [0038](../decisions/0038-release-ledger-is-a-checked-artefact-and-first.md).
It ships the release ledger FIRST, before any criterion is worked, so the
milestone establishes which of `§26`'s fifteen are already true before spending
effort on the rest.

## What shipped

1. **`(byte-machine test release-ledger)`** — `§26`'s fifteen release criteria
   and `§27`'s eleven documentation deliverables as data. A `§26` row is
   `(ref text state kind witness receiver)`, keyed on `text` (not the line
   number); a `§27` row is `(ref text exists? receiver)`. Also the §4.5 version
   surface: `release-version` = `"0.1.0"` (single owner), `release-version-export?`
   = `#f` (declined, §4.9 item 3), and the five mirror surfaces.

2. **`byte-machine.unit.release-ledger.chez.{source,aot}`** — the lane that reads
   it (`test/common/release-ledger-tests.sps`), registered in `test/CMakeLists.txt`.
   It runs 20 cases / 60 checks:
   - **Two totality rows** (self-ratcheting, no mutation entry, as M8 Slice ⓪'s
     table earned none): the lane re-reads `§26` and `§27` from the parent plan
     as data and set-compares against the ledger, verbatim. A criterion added or
     dropped in either the plan or the ledger fails **by name**.
   - **The disposition partition** — `met` = 6, `partly` = 3, `open` = 6 (the
     exact §3.1 table / Appendix names), and every not-`met` row names a receiver
     while every `met` row names none.
   - **Mechanical rows executed** — differential and determinism lanes
     registered (`§26:1673`, `:1677`); `bench/` holds only `fixtures/.gitkeep`
     and `runner/.gitkeep` (`:1679`); `examples/` holds only `.gitkeep`
     (`:1682`); `CHANGELOG.md` exists with no `0.1.0` entry yet (`:1684`);
     `git ls-files` matching the native-artifact pattern is empty and the
     `http-leak` lane is registered (`:1685`). The `git ls-files` result is
     produced by the build layer at configure time (the lane cannot run git) and
     asserted empty by the lane.
   - **Judgement rows recorded, never re-checked** — each carries a nonempty
     witness paragraph; the lane does not recompute the expectation it was handed
     (that would be the "sentinel computed from the test's own expectation"
     defect).
   - **The declined version export made observable** — no public library exports
     a `version` name (the `http-leak` read-as-data technique).

3. **The licence review (`§25:1662`, §4.9 item 2 — both approved).**
   - `README.org`'s footer contradiction resolved: "all rights reserved" →
     "Released under the BSD 3-Clause License", matching `LICENSE`
     (BSD-3-Clause, © 2026 Kiyomi Computation Systems LLC).
   - A one-line SPDX header (`;;; SPDX-License-Identifier: BSD-3-Clause`) added
     to each of the **nine** `src/` libraries (compile, graph, interpret,
     runtime, verify; private/ conditions, ir, names, normal-ir).

## The §4.7 gate

`git diff --stat main..HEAD -- src/` is **nine files, nine insertions — every one
a comment line** (the SPDX header). This is the comment-only exception §4.7
declared in advance for §4.9 item 2; the gate is met in its comment-excluded
form, measured as Milestone 7 Slice ④ measured its one-comment exception.

## Exit (design §5)

- The lane is green in both modes — confirmed (release suite 140/140).
- The ledger's not-`met` rows are exactly the design's disposition: 6 `open`
  + 3 `partly` = 9, each with a receiver.
- No mutation-suite entry (the totality rows are self-ratcheting).

## Findings recorded this slice

- **The design's §3.1 prose summary is internally inconsistent** — "Nine met,
  three partly, one true-but-unasserted, five open" sums to eighteen, and the
  Slice ⓪ exit line counts differently again. The table and Appendix are
  consistent (6/3/6) and are what the ledger encodes; the design is annotated in
  place (dated 2026-09-12) and nothing above the note rewritten. This is exactly
  the drift the ledger exists to catch, caught on its first day.
- **`bench/` is not flat.** The design said "`bench/` holds two `.gitkeep`
  files"; the tree has `bench/fixtures/.gitkeep` and `bench/runner/.gitkeep`.
  The `:1679` check asserts both subdirectories hold only `.gitkeep`, so it
  flips when Slice ③ lands the baseline artefact and runner.
- **The SPDX header shifts current `src/` line numbers by +1.** The 754
  `src/*.sls:NNN` citations in the repo are overwhelmingly in historical M4
  design/plan docs and frozen decision records, which by
  `docs/decisions/README.md`'s convention are pinned to the commit they were
  written against (and already diverge from HEAD after M5–M7 src edits). They are
  deliberately not rewritten; no live check maps them to HEAD.
