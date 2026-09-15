# Milestone 12 Slice ② — the release and the close (v0.4.0)

**Status: plan, written 2026-09-14 against `f8fc243`** (`main`; Slice ① —
"a pause carries a reason" — merged as `f8fc243`, PR #128). One plan at a time:
this is re-taken off the merged Slice ① base, as the design (§6) requires.

The mechanism shipped in Slice ①. This slice ships **no `src/` code and no new
test lane** (the design's §3.6 records the size measurement in prose; there is no
committed size lane). It moves the version surface to `0.4.0` in lockstep, writes
the `[0.4.0]` changelog and the status surfaces, closes the milestone-12 design,
appends the parent plan's dated disposition, tags `v0.4.0`, and runs the closing
ritual (Slice ② closes M12). This mirrors the M10 (#123) and M11 (#127) release
slices exactly.

Authority: the design's [§6](./milestone-12-design.md) and the release-ledger's
`§4.5` version-surface mirror rule. Every anchor below was measured at `f8fc243`;
a file this slice edits re-resolves its own citations as the last step before
commit (AGENTS.md; [[citation-stale-within-its-own-commit]]).

---

## 1. The version surface (one owner + five mirrors)

`release-version` in `release-ledger.sls` is the single owner; the five entries
in `release-version-surfaces` are the mirror rule. All six move together.

### 1a. `test/support/harness/byte-machine/test/release-ledger.sls` — the owner

- `:175` `(define release-version "0.3.0")` → `"0.4.0"`.
- `:158-174` the `§4.5` comment block: re-point from "Milestone 11 (the
  keyword-table node kind, decisions 0043-0045) bumps it to `0.3.0`" to
  "Milestone 12 (a pause carries a reason, decision 0046) bumps it to `0.4.0`";
  update the ABI aside (`current-abi-version` "now 6" → "now 7 … moved 6→7 at
  v0.4.0 for the paused-outcome payload contract"). The `§26`/`§27` census is
  **unchanged** — keep the sentence stating the append rule freezes those rows
  and every one still holds (13 met / 2 amended / 0 open, the two amended still
  the CI-blocked Tier-1 pair); the pause reason adds no criterion row. Keep the
  `release-version-export?` #f rationale (no `version` NAME export); note M12,
  like M11, DID add public API — `parser-result-pause` — a semver-minor's added
  accessor, not a version-string export.
- `:181` the design-header surface string
  `"the milestone-11-design.md status header"` → `"the milestone-12-design.md
  status header"`. The other four surface strings are generic (CHANGELOG entry,
  README status paragraph, parent-plan dated disposition, git tag) and stay;
  count stays 5.

> `release-ledger.sls` is SOURCES-listed for the release-ledger lane
> (`test/CMakeLists.txt:1676,:1688`), so after editing it run
> `touch test/CMakeLists.txt && cmake --preset dev && cmake --build --preset dev`
> or the lane fails PROVENANCE-ERROR ([[chez-sources-fingerprint-reconfigure]]).
> It carries **no** mutation FIND anchors (no `test/support/cmake` reference), so
> the mutation lane is untouched; totals stay 72/628.

### 1b. `test/common/release-ledger-tests.sps` — the lockstep literals

Every hardcoded `0.3.0` moves in lockstep (the M10/M11 precedent — the ledger and
its test are one change, [[prose-expectations-are-not-checks]]):

- `:6` header comment `0.3.0` → `0.4.0` (single-owner note).
- `:98` group heading "met through v0.3.0" → "v0.4.0".
- `:181` case title "carries the 0.1.0, 0.2.0 and 0.3.0 release entries" → "…
  and 0.4.0 …".
- `:192-194` add a fourth witness: keep the `[0.1.0]`/`[0.2.0]`/`[0.3.0]` checks
  (kept-in-history) and add `(check "has the [0.4.0] entry" (harness-string-contains? … "[0.4.0]"))`
  — the current release's own entry.
- `:256` case title `"0.3.0 is the single owner …"` → `"0.4.0 …"`.
- `:258` `(check-equal "release-version" release-version "0.3.0")` → `"0.4.0"`.
- `:259` label `"export still declined at v0.3"` → `"v0.4"`.
- `:260` `(= (length release-version-surfaces) 5)` — count unchanged, assertion
  stays.

Verify: `chez --libdirs "src:test/support/harness" --program test/common/release-ledger-tests.sps`
green, then the full `ctest --preset pr` (156/156).

---

## 2. The changelog and the status surfaces

### 2a. `CHANGELOG.md` — `[Unreleased]` → `[0.4.0]`

The `[Unreleased]` section (`:7`) is currently empty (Slice ① added no changelog
line). Replace the `## [Unreleased]` header with a fresh empty `## [Unreleased]`
above a new dated `## [0.4.0] - 2026-09-14` section, keeping the existing
`[0.3.0]` below. Under the `[0.4.0]` section, in Keep-a-Changelog form:

- **### Added — Milestone 12: a pause carries a reason.** A `pause` node (and a
  `callback` node returning `callback-pause`) takes an OPTIONAL declared reason
  (an `error-declaration` name) via `case-lambda` on `make-pause-node` /
  `make-callback-node`, so no existing machine changes. A paused `parser-result`
  now reports that reason as a `parser-error`-shaped `(code, reason)` value in a
  NEW slot read by **`parser-result-pause`** — the first `§9.3` accessor added
  since v0.1's family — while `parser-result-error` stays `#f` (a pause is not an
  error and remains resumable; `status` and the `paused-feed`/`paused-finish`
  lifecycle rows are unchanged). Reference decision 0046.
- **### Changed — generated-runtime ABI 6 → 7.** The emitted paused-outcome's
  payload contract moves (its error slot goes from always-`#f` to
  `#f | ParserError`); a v6 generated library and a v7 runtime refuse each other.
  A reason-less pause is byte-identical in the emitted parser but for the ABI
  literal (the reason enters the encoding and fingerprint under a presence
  guard). Include the size note: a two-node pause machine emits **1825 bytes**
  without a reason and **1942 bytes** with one declared reason (**+117 bytes** —
  the one errs-table entry plus its wiring; design §3.6).

### 2b. `README.org` — the status paragraph (`:20`)

`*Status:* =0.3.0=` → `=0.4.0=`. Add a lead sentence: v0.4 adds the second
public-API addition since v0.1 — the `parser-result-pause` accessor and an
optional reason on `make-pause-node` / `make-callback-node`, so a paused parser
reports its own `(code, reason)` while the error slot stays `#f`; ABI 6 → 7
(decision 0046). Keep the v0.3 (keyword-table) and v0.2 (empty-span) sentences.

### 2c. `.plans/milestone-12-design.md` — status header + Close section

- `:3` `**Status: Milestone 12 OPEN — design draft (2026-09-14).**` →
  `**Status: Milestone 12 CLOSED 2026-09-14 — v0.4.0.**`
- Append a `## Close` section (mirroring milestone-11-design's) dispositioning
  the brief's **six** acceptance criteria against where each is witnessed
  (criteria 1-5 by Slice ①'s `differential-pause`/`verify`/`normal-ir` lanes and
  the ABI-7 goldens; criterion 6 — the size measurement — by §3.6, recorded in
  the CHANGELOG). State: ledger census unchanged (13/2/0); ABI 7; mutation
  72/628; `pr` 156/156; the two out-of-scope items (span-callback-pause reason,
  mandatory reason) remain deferred with their rationale; `v0.4.0` tagged at the
  merge; consumer picks up ABI 7 downstream.

### 2d. `.plans/byte-machine-implementation-plan.md` — status line + dated foot

- `:3` `Status:` line: "milestones 0 through 11 are closed; **v0.1.0 … v0.2.0
  and v0.3.0 …**" → "0 through 12 … and v0.4.0 on 2026-09-14"; add M12 to the
  parenthetical naming the briefs-outside-§25 milestones (M10 empty-span, M11
  keyword-table, **M12 pause-reason, decision 0046**).
- The M12 foot note at `:2535` currently ends "The v0.4.0 close is the dated
  disposition Slice ② appends below." Replace that closing sentence with the
  actual close disposition: **Milestone 12 closed 2026-09-14**, delivered as a
  design plus Gate-0 decision 0046 plus two slices — Slice ① (the mechanism end
  to end: the optional reason, `parser-result-pause`, both executors, the
  normalizer/fingerprint seam, the errs-table reached-walk arm, ABI 6→7 across
  all seven goldens; PR #128 = `f8fc243`) and Slice ② (this v0.4.0 close). The
  six brief criteria met; census unchanged (13/2/0); ABI 7; `v0.4.0` tagged;
  consumer bumps its gitlink pin off `v0.3.0`.

---

## 3. PR, tag, and the closing ritual

**Branch:** `feat/m12-release` off the freshly-caught-up `main` (`f8fc243`).

**Two commits, one PR** (the M11 #127 shape):
1. `test(release): version surface → 0.4.0` — `release-ledger.sls` +
   `release-ledger-tests.sps` (lockstep). Reconfigure per §1a before running.
2. `docs(release): Milestone 12 close — release v0.4.0` — `CHANGELOG.md`,
   `README.org`, `milestone-12-design.md`, `byte-machine-implementation-plan.md`,
   and this plan doc.

This PR touches `test/`, so it gets the `ci` label once the branch is final and
merges after that run is green (AGENTS.md closing-ritual step 1).

**Closing ritual (Slice ② closes M12 — do the full ritual, not just a slice
merge):**
1. Squash-merge the PR (the agent performs the merge on the user's go-ahead;
   verify `state: MERGED`, never trust the exit code — [[closing-ritual-agent-merges]],
   [[github-ssh-push-first-attempt-fails]]).
2. Catch up local `main` (fetch + fast-forward).
3. Delete the branch locally and on the remote.
4. **Tag** an annotated `v0.4.0` on the merge commit (after merge, the M10/M11
   precedent) and push it.
5. **Reflect** ([[status-surfaces-drift-independently]] — all five status
   surfaces move together; confirm README.org actually moved):
   - Auto-memory: update the [[protium-sibling-project]] pointer to
     **M0-12 CLOSED; v0.4.0 released 2026-09-14** (`main` = the new merge
     commit, tag `v0.4.0`), with the M12 one-liner (pause reason,
     `parser-result-pause`, ABI 6→7, PRs #128 + the release PR).
   - Candidate durable finding from Slice ①: the mutation suite's
     `BYTE_MACHINE_MUTATION_VERIFY_COMMAND` is set **per group**, so a pin
     appended to the wrong group inherits the previous group's witnessing program
     and reads as UNCAUGHT (five pins bit this in Slice ①). Decide at execution
     whether this is distinct enough from [[mutation-spec-is-a-label]] to warrant
     its own memory or an AGENTS.md standard; M11's reflection was memory-only
     (no `docs(agents)` PR), so an AGENTS.md commit is optional, not required.

---

## Exit

`(byte-machine test release-ledger)` green against `0.4.0`; `ctest --preset pr`
156/156; the `[0.4.0]` changelog entry, README status, design status header,
parent-plan disposition, and the `v0.4.0` tag all agree; the census stays
13 met / 2 amended / 0 open; ABI 7; mutation 72/628 unchanged. Milestone 12
closed; the consumer can bump off `v0.3.0` against ABI 7.
