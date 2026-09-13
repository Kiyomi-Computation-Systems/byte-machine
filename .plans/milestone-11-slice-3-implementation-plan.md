# Milestone 11 — Slice ③ (span composition, the size measurement, and the 0.3.0 close) Implementation Plan

Authority: `milestone-11-design.md` §7 (the slice) and the Exit table (criteria 5
and 7), the upstream brief
`chez-httparse/.plans/2026-09-13-upstream-keyword-trie-brief.md` §5.5 / §7
(criteria 5 and 7) and §10 (the consumer handoff), and decision 0044 (the
compact-table lowering the size measurement proves). This is the **milestone-closing
slice**: it meets the last two acceptance criteria and **releases 0.3.0**. Depends
on Slices ① (`59c40c9`) and ② (`4e15198`).

Measured at the branch base (`main` = `4e15198`, Slice ② merged): `pr` **149/149**
(152 with the three mutation-harness lanes), mutation **69 passes / 622 mutations**,
diagnostic census 32/58, fourteen node kinds, ABI 6, seven determinism goldens,
README.org status `0.2.0`, CHANGELOG `[Unreleased]` carrying the Milestone 11
section. At the end of the slice: two new demonstration lanes (`pr` 149→**153**,
`.chez.{source,aot}` each), mutation recounted (projected small; see §4), CHANGELOG
`[0.3.0]`, README.org `0.3.0`, tag **v0.3.0**, the brief's seven criteria
dispositioned, the §29 deferred-extension admission discharged.

---

## 1. Why this slice is mostly test, measurement, and ritual

Slices ① and ② shipped every mechanism: the node kind, the compact lowering, the
ABI, both executors' fold, and the collision rejection. Slice ③ adds **no source
mechanism** — it demonstrates two properties the shipped mechanism already has and
then closes the milestone.

- **Span composition (criterion 5) is flow-through by construction.** `verify.sls`'s
  pass-7 `span-transfer` (`:1713`) is `(else state)` for every node that is not a
  span-start/end, so a keyword-table node in a span-active region **passes the span
  state through unchanged** — exactly as byte-dispatch does — and
  `span-node-diagnostics` gives it no finding (a keyword table is not a
  pause/callback/terminal). The executors accumulate a span as `[mark, cursor)`
  driven by the byte cursor, independent of node kind, and a matched keyword's
  reexecute leaves the cursor at the keyword's end (Slice ①'s "offset == keyword
  length"). So a span opened before the table and closed after it captures exactly
  the keyword's bytes, with **nothing new to build**. This slice makes that a
  registered test. **Risk, retired by a prototype first:** confirm in a scratch
  driver that a `span-start → keyword-table → span-end` machine verifies and that
  the span data equals the matched keyword bytes in **both** lanes, before writing
  the fixture into `SOURCES` (a defect here would be executor mechanism, not a test
  gap, and would widen the slice — measure before believing otherwise,
  [[differentials-only-compare-what-fixtures-reach]]).
- **The size measurement (criterion 7) is a lane, not a claim.** The 242-node /
  ~105 KB "before" and the compact "after" are **measured through a registered
  lane**, never the design's prototype numbers copied into a literal
  ([[scratch-fixture-measurements]], [[records-go-stale-when-fixtures-change]]).

## 2. Span composition (criterion 5)

A new fixture (`keyword-span-machine.sls`) whose machine opens a method span, runs a
keyword table, and closes the span at the match — the brief's `MKCOL`/`MKCOLA`
shape:

- `span-start(method) → keyword-table{ GET→m1, GET-PARAMETER→m2, MKCOL→m3, … } → span-end(method) → …`.
  The brief names **`GET` ⊂ `GET-PARAMETER`** as the sole proper-prefix pair across
  the 47 methods; `MKCOL` is a keyword and **`MKCOLA` is not a method — it is a
  failure input**: the walk matches `MKCOL` (5), the sixth byte `A` does not extend
  toward any keyword, so the span closes at 5 and the parser then fails on `A`
  (brief §2: `MKCOLA / HTTP/1.1` records `span[method]="MKCOL"` and fails at offset
  5). Include the prefix pair so the lane also shows the *longer* keyword winning
  when the input reaches it.
- The span data asserts `method = "MKCOL"` (5 bytes) from the input `MKCOLA…` (the
  span closes at the matched length even though the input continues), and
  `= "GET-PARAMETER"` from `GET-PARAMETER…`. **The exact keyword set, the closing
  byte's fate (reexecute vs the no-match route), and the driving inputs are settled
  in the prototype (§1) and the tuples measured, not guessed.**

Lane `byte-machine.differential.keyword-span` (`.chez.{source,aot}`): the span data
(the delivered byte range) is asserted **absolutely on the generated side** and
interpreter ≡ generated. This is the P1 offset property (Slice ①) promoted to a
span-data test — the criterion the design's Exit table assigns here.

## 3. The size measurement (criterion 7 — the change's whole justification)

A fixture (`keyword-method-table.sls`) that builds the **47 llhttp method names**
(sourced from llhttp's method enum / the consumer's `httparse` method table,
embedded here as data — the repository owns its own copy, the consumer builds its
own downstream, design "Explicitly out of Milestone 11") two ways:

- **After:** one `keyword-table` node with 47 `make-keyword-entry` and their
  targets.
- **Before:** the equivalent **trie of byte-dispatch nodes**, one node per distinct
  prefix — an auto-builder over the same 47 names (the design's P2 shape, which
  measured 242 nodes / ~105 KB). The builder is a fixture helper, not shipped
  mechanism.

Lane `byte-machine.unit.keyword-size` (`.chez.{source,aot}`) — the layer segment
of the lane name **is** the ctest label (derived `${layer} ${backend} ${mode}`,
`cmake/ByteMachineTesting.cmake`), and the layer vocabulary is **closed**: an
invented `measure` layer is rejected at *configure* time by
`byte_machine_test_name_parse` (a FATAL_ERROR — not a silent skip), because
`measure` is not in `BYTE_MACHINE_TEST_LAYERS`. So the measurement lane carries an
existing label — `unit` (an absolute self-contained assertion) — which is also in
the `pr` preset's include set `^(harness|unit|verify|differential|property|determinism|portability|example)$`.
Render **both** through `render-machine (compile-machine …)`, and assert
- the compact table's node count and emitted byte count,
- the trie's node count (≈242) and emitted byte count (≈105 KB),
- **after ≪ before** as a ratio,
each against a **measured** literal with the number **recorded in a comment beside
the assertion and in this plan's post-execution record** (never the prototype's
number transcribed). The assertion is a floor/ceiling that the win holds (e.g.
compact bytes < before/10 and compact states ≤ a small constant), so a lowering
regression to one-state-per-prefix (the milestone's forbidden shape) reddens it.

## 4. Mutation pins

**Likely none new** — Slice ③ adds no source mechanism, and the properties it
demonstrates are already pinned: the reexecute that makes a span close at the
keyword length is Slice ①'s interpreter/runtime reexecute pins, and the
one-state-per-table lowering is pinned by the determinism golden and the tag-15
encoder. Before concluding "no pins", run the mutation lane on a prototype and
check whether the size lane's "one compact state" assertion or the span lane's
span-data assertion **separates a mutant no shipped pin already catches**
([[pin-census-by-find-location-misses-moved-observations]]); if the size lane is
the sole witness that the lowering is ONE state (not a trie), add one pin there
(a normal-ir mutant that splits the table), on the lane that witnesses it. Recount
`EXPECTED_PASSES`/`EXPECTED_MUTATIONS` from the rewritten manifest regardless;
adding two lanes to `SOURCES` needs the [[chez-sources-fingerprint-reconfigure]]
reconfigure.

## 5. The close and the 0.3.0 release

- **The seven criteria, dispositioned.** Each of brief §7's seven criteria gets a
  dated disposition naming the file and case that meets it (design Exit table:
  1–3 Slice ①, 4 Slice ②, 5 + 7 this slice, 6 across all three). Recorded in
  `milestone-11-design.md` (a close section) and cross-checked against the tree.
- **The §29 deferred-extension admission discharged.** The milestone supplied every
  item §29:1767 requires (interpreter semantics, verification rules, generated
  parity, documentation, tests) with the downstream brief as the §29:1749 evidence;
  record it discharged.
- **The version bump is the release ledger's single-owner surface, moved in
  lockstep** (NOT a "stay green" no-op — the M10 precedent `19e2c05`). The current
  release string has ONE owner, `release-version` in
  `test/support/harness/byte-machine/test/release-ledger.sls` (`:171`, today
  `"0.2.0"`), and every other version surface mirrors it (§4.5). So the bump is a
  coordinated edit:
  - `release-ledger.sls`: `release-version` `"0.2.0" → "0.3.0"`, **and** the two
    `release-version-surfaces` entries that name a version/milestone by number
    (`:174` "CHANGELOG.md 0.2.0 entry" → "0.3.0 entry"; `:177` "the
    milestone-10-design.md status header" → "milestone-11-design.md") — the lane
    checks only `(length …) = 5`, so stale content stays green yet ships wrong.
  - `test/common/release-ledger-tests.sps` in lockstep: the hard `"0.2.0"` literals
    (`(check-equal "release-version" … "0.2.0")` at `:255`, and the mirror-surface
    and CHANGELOG-entry literals at `:6`/`:98`/`:181`/`:189-191`/`:253`/`:256`)
    move to `"0.3.0"`, and the CHANGELOG-witness check gains a `[0.3.0]` entry
    beside `[0.1.0]`/`[0.2.0]` (as M10 added `[0.2.0]`). Bump one file without the
    other and the `byte-machine.unit.release-ledger` lane reddens mid-slice.
  - The §26/§27 census stays frozen (13 met / 2 amended / 0 open); the new
    keyword-table kind is documented to keep §26:1671 green
    ([[derived-artifact-checked-and-amended-not-waived]]).
- **The other status surfaces** ([[status-surfaces-drift-independently]] —
  README.org is the one that drifts): README.org status `0.2.0 → 0.3.0` **and**
  amend "public API surface unchanged since v0.1" — v0.3 **adds** the
  `keyword-table` node kind and `make-keyword-table-node`/`make-keyword-entry`, the
  first public-API addition since v0.1; CHANGELOG `[Unreleased] → [0.3.0]` dated,
  folding all three Milestone 11 slices; the parent plan on **both** its version
  surfaces — the top status line **and** a new dated Milestone 11 foot disposition
  (the paragraph every prior milestone M4–M10 carries; it is the surface
  `release-version-surfaces:176` names as "the parent plan's dated disposition");
  and `milestone-11-design.md`'s status header.
- **Coordination items (§4.6) closed:** decision numbers (0043–0045 landed), the
  ABI (5→6, clean), the changelog head, the ledger — all reconciled; record them
  closed.
- **The consumer handoff (brief §10):** the before/after node and byte counts from
  §3 reported for `chez-httparse` to cite when it replaces its generated tries and
  bumps its byte-machine gitlink.
- **The tag.** Annotated `v0.3.0`, created **last**, after the release commit
  merges (the M9 rule; the tag is the version of record). A clean-checkout proof as
  M9 Slice ⑤ performed.

## 6. Commits, exit, and boundaries

**Commits.** One source commit (the two fixtures + two lanes + the trie/method
builders + any pin + `EXPECTED` recount) and one documentation/release commit
(CHANGELOG `[0.3.0]`, README.org, the design close + dispositions, the parent plan's
status line **and** its new Milestone 11 foot disposition, the release ledger's
version bump — `release-ledger.sls` **and** `release-ledger-tests.sps` in lockstep,
this plan). The release-ledger version bump is a **source-coupled** edit — its lane
runs in `pr` — so it (both files) lands in the commit that makes `pr` green, i.e.
the same commit as its test literals; keep it with the docs/release commit and
confirm `pr` is green on that commit. One PR, paused before merge for the go-ahead;
the **tag is applied after merge**, not in the PR.

**Oracle.** *Span (criterion 5):* the delivered span data equals the matched
keyword's bytes (`MKCOL` from `MKCOLA…`, `GET-PARAMETER` from `GET-PARAMETER…`),
generated side absolute, both lanes. *Size (criterion 7):* after ≪ before, both
emitted through a lane, the ratio recorded from measurement. *Close:* every one of
the seven criteria has a dated disposition naming a file and case; the §29
admission is discharged; every version surface (README, CHANGELOG, both parent-plan
surfaces, `release-version`, the design header, the tag) reads 0.3.0.

**This is the milestone close** — nothing in Milestone 11 is deferred past it.
Retiring `sequence-dispatch`/`ambiguous-sequence-prefix`, a production HTTP method
table in this repo, and any one-state-per-prefix lowering remain **out of
Milestone 11** (design "Explicitly out"). The consumer's own pickup (its PR, its
re-measured fingerprints) is downstream, not this slice.
