# Milestone 11 — Slice ② (per-table case-insensitivity: the collision rejection and the header demonstration) Implementation Plan

Authority:
[decision 0045](../.decisions/0045-keyword-table-case-insensitivity-is-a-per-table-fold.md)
— **amended 2026-09-13**: the ASCII fold and the `case-insensitive?` field
shipped in Slice ①, so this slice is narrowed to what remains, item 3 (the
**folded-collision rejection**, its diagnostic, catalog entry and census pin) and
the brief §2b **HTTP-header case-insensitivity demonstration** — then
`milestone-11-design.md` §6 (the slice) and the upstream brief
`chez-httparse/.plans/2026-09-13-upstream-keyword-trie-brief.md` §5.4 / §7
criterion 4.

This slice adds **no node kind, no ABI change, no golden re-baseline, and no
property-generator change.** It is two things: a verifier rejection for a
case-insensitive table whose entries collide under folding, and a demonstration
that a case-insensitive table recognizes every casing of the HTTP header names
the consumer needs while a case-sensitive one does not. Depends on Slice ①
(`59c40c9`).

Measured at the branch base (`main` = `59c40c9`, Slice ① merged): the `pr` subset
**147/147** (150 with the three self-validating mutation-harness lanes), the
Scheme mutation suite **68 passes / 619 mutations**, the diagnostic census **31
codes over 57 sites**, fourteen node kinds, generated ABI 6, seven determinism
goldens. At the end of the slice: `pr` **149/149** (one new differential lane
pair, `.chez.{source,aot}`), mutation **recounted** from the rewritten manifest
(one new pass, projected two–three mutations), diagnostic census **32 over 58**;
node kinds, ABI, and goldens **unchanged**.

---

## 1. Why this slice is narrow, and why it is safe

The fold itself — the `case-insensitive?` field and the ASCII fold in both
executors — is Slice ①'s (decision 0045's amendment), already differentially
covered (`differential-keyword-table-tests.sps` "the fold holds on the generated
table and both lanes agree", and the interpreter-absolute per-table fold group in
`keyword-interpret-tests.sps`). So this slice does **not** touch the executors'
walk logic, the normalizer, the emitter, the runtime, or the ABI. It touches the
**verifier** (one new rejection), **one new fixture + lane** (the demonstration),
and the **diagnostic census surfaces** (catalog, the two census-drive programs,
the corrupt-machine harness).

**The one seam that could have bitten — and why it does not.** Adding a new
rejection can newly refuse machines an earlier slice accepted, shifting the
property suite's accepted-count and perturbing the PRNG stream (AGENTS.md,
*"PRNG-stream-affecting generator changes shift accepted counts"*; the
[[sweeps-cannot-see-unpinned-decisions]] / accepted-count trap). It does **not**
here: `machine-gen.sls:470` draws every generated keyword-table with
`case-insensitive? #f` **by construction** (its comment: *"`case-insensitive?` is
#f here so the machine-drawing PRNG stream is unperturbed; the CI fold is
exercised by the dedicated keyword-table lanes"*). The collision rejection fires
**only** on a case-insensitive table, so it can never reject a generated machine.
The property accepted-count is immune — but it is **re-measured, not assumed**
(the last step of §5).

## 2. The rejection (decision 0045 item 3)

`verify.sls`'s `node-keyword-defects` (`:627`) already rejects an **exact**
duplicate — two entries with byte-identical keywords — as `duplicate-keyword`, in
both case-sensitive and case-insensitive tables. This slice adds its **fold-up
analogue**: in a **case-insensitive** table, two entries that are equal after
ASCII folding but **not** byte-identical (`Content-Length` and `content-length`,
or `GET` and `get`) are refused as **`case-insensitive-keyword-collision`**.

**Disjoint by construction, so each diagnostic has its own witness.** A
byte-identical pair stays `duplicate-keyword` (it is one already, in either table
mode); the new code fires only for `fold-equal? ∧ ¬equal?` **and** only when the
table's `case-insensitive?` is true. The two are never emitted for the same pair,
so each is independently pinnable and neither pin doubles onto the other's mutant.

**Own binding names, folded into the one existing scan.** The check is added to
`node-keyword-defects`' existing `scan`/`probe` loop (its own
`kws`/`rest`/`others`/`dups` bindings, §4.4's "not a clone of `node-overlaps`"
constraint), gaining a `ci` binding (the node's `case-insensitive?`) and a small
local `kw-fold`/`fold=?` — **not** imported from an executor. The verifier is not
part of the interpreter≡generated differential, so decision 0015's independence
rule does not compel sharing.

**`ci` is the guard in exactly one place.** `kw-fold` folds ASCII letters
**unconditionally**; the collision arm is `(and ci (fold=? …))`, so the per-table
control lives solely in that outer guard. Guarding `kw-fold` on `ci` *as well*
would be redundant — and would make the per-table mutation (Pin 2, drop the outer
guard) uncatchable, because a case-sensitive table's `fold=?` would still not fold
and so still find no collision. One guard, one pin.

## 3. The demonstration (brief §7 criterion 4)

A new fixture file `keyword-header-machine.sls` carrying **two** machines over the
**same** four header names the brief §2b names — `Content-Length`,
`Transfer-Encoding`, `Connection`, `Upgrade` — a **case-insensitive**
(`make-keyword-header-ci-machine`) and a **case-sensitive**
(`make-keyword-header-cs-machine`) one, differing only in `case-insensitive?`.
Each keyword → a distinct stop node; no-match → a `reject` error node
(reexecute); eof-target → an `eof-incomplete` error node (Slice ①'s
`eof-reachable-stop` constraint: an EOF path to a stop is a verifier diagnostic,
so the eof-target must be an error node).

A new lane `byte-machine.differential.keyword-header`
(`differential-keyword-header-tests.sps`, `.chez.{source,aot}`) drives, in **both
the interpreter and the generated executor and asserting the generated side
absolutely** (agreement alone cannot carry it — Slice ①'s lane lesson):

- **CI table** recognizes `Content-Length`, `content-length`, and `cOnTeNt-LeNgTh`
  to the **same** target (criterion 4's hit half); `Transfer-Encoding` /
  `transfer-encoding` likewise, so the fold is shown across the hyphen and on a
  second name.
- **CS table** recognizes `Content-Length` (canonical) but **no-matches**
  `content-length` and `cOnTeNt-LeNgTh` (criterion 4's miss half) — the per-table
  contrast, same names, same fixture pair.
- **Structure cases** so the demonstration is not just two casings: a **prefix**
  and an **extension** relative to a keyword, and a **near miss** (one wrong
  byte), each asserted hit/miss in both modes.

New fixture in the lane `SOURCES`, **and** the edit to `machine-corrupt.sls` (a
SOURCES member of the rejections lanes) ⇒ `touch test/CMakeLists.txt && cmake
--preset dev && cmake --build --preset dev` before running (the
[[chez-sources-fingerprint-reconfigure]] rule). The header fixture is **new**, so
no existing golden's provenance moves.

**One differential lane, not also a unit lane.** Design §6 calls for "a CI
differential lane"; the fold's interpreter-absolute oracle already exists in
Slice ①'s `keyword-interpret-tests.sps`. Asserting the generated side absolutely
in the differential (rather than only interpreter≡generated) is what keeps a
both-executors-shared defect visible, so a separate unit lane would be
redundant here.

## 4. The work, by surface

- **Verifier** (`verify.sls`, `node-keyword-defects` ~`:627`) — the fold-collision
  branch (guarded by `case-insensitive?`, disjoint from `duplicate-keyword`, own
  bindings + private `kw-fold`); the new `case-insensitive-keyword-collision`
  diagnostic string. `pass-keyword-table` itself is unchanged (it already visits
  every keyword-table node).
- **Diagnostic catalog** (`.reference/verifier-diagnostic-catalog.md`) — a
  `case-insensitive-keyword-collision` bullet beside `duplicate-keyword`; the
  header count `thirty-one over fifty-seven → thirty-two over fifty-eight`; the
  footer `Thirty-one codes. → Thirty-two codes.`
- **Census test** (`test/common/diagnostic-census-tests.sps`) — `pinned-sites`
  gains `(case-insensitive-keyword-collision 1)`; the plain-`make-diagnostic` site
  count `(site-count-of 'make-diagnostic)` `15 → 16` (`:601`) and the site total
  `57 → 58` (`:606`, label "fifty-seven → fifty-eight"); the pinned code set and
  its total move `31 → 32` / `57 → 58`. All re-measured from `verify.sls`, not
  guessed — the census is the backstop. (The stale Milestone-4-era header comment
  `:5` "all sixteen codes" describes the whole census, already wrong, and does not
  name the corrupt harness's provoked set — leave it; it is not a count this slice
  moves.)
- **Corrupt-machine harness** (`test/support/harness/byte-machine/test/machine-corrupt.sls`)
  — a new `corruption-entries` arm building a **CI** keyword-table whose entries
  fold-collide (`Content-Length` / `content-length`) by datum surgery, asserting
  `case-insensitive-keyword-collision` by the table's node name (the behavioral
  rejection witness + the census sentinel's source, beside the `dup-keyword` arm
  `:242`). `corruption-entries` goes `31 → 32`.
- **Rejections drive** (`test/common/property-rejections-tests.sps`) — the second
  census-drive program, which consumes `corruption-entries` and re-derives the
  census from `verify.sls` (a SOURCES member of `byte-machine.property.rejections.chez.{source,aot}`).
  Three hardcoded literals move `31 → 32`, each re-measured, exactly as Slice ①
  moved them `30 → 31`: `(length census)` (`:240`), `(length sentinel)` (`:241`),
  and `(length corruption-entries)` (`:319`), with their "thirty-one → thirty-two"
  labels. The set-equality `sentinel set=? census` (`:239`) stays green **because**
  the new corrupt arm emits the census's new code. The accepted-count literal `41`
  (`:315`) is **unmoved** (§1). Editing `machine-corrupt.sls` (a SOURCES member of
  these lanes) forces the same [[chez-sources-fingerprint-reconfigure]] reconfigure
  the new fixture already does. This is the file the first plan draft missed —
  without it, both rejections lanes go red and `pr` never reaches 149.
- **Fixture** (`test/support/harness/byte-machine/test/keyword-header-machine.sls`,
  new) — the CI and CS header machines of §3, **plus** a matched **fold-colliding
  pair** over `Content-Length` + `content-length` (byte-distinct case variants):
  `make-keyword-collision-ci-machine` (CI, must be **rejected**) and
  `make-keyword-collision-cs-machine` (CS, must **verify clean** — byte-distinct so
  not a `duplicate-keyword`, case-sensitive so no fold collision). This pair is
  Pin 2's witness (§4 mutation pins).
- **Lane** (`test/common/differential-keyword-header-tests.sps`, new;
  `test/CMakeLists.txt`) — `byte-machine.differential.keyword-header.chez.{source,aot}`,
  fixture in `SOURCES`, `${BYTE_MACHINE_CORE_EMIT}` (it renders + loads generated
  code). Two kinds of group: (a) the **recognition demonstration** of §3
  (interpreter≡generated, generated side absolute); (b) a **collision verify group**
  that calls `verify-machine` **directly** (never through `make-interpreted-machine`,
  which raises on an unverified machine): the CI colliding machine is refused **by
  name** (`case-insensitive-keyword-collision`), the CS colliding machine
  `(verification-ok? (verify-machine m))`. `pr` 147→149.
- **Mutation pins** (`SchemeMutationSuite.cmake`, new Pass 69) — witnessed by the
  collision verify group's two assertions (the CI colliding machine refused by
  name; the CS colliding machine verifies clean). Both machines carry a
  fold-colliding pair; that is what makes each pin separable:
  1. **collision never fires** — neuter the fold-collision branch (emit nothing) ⇒
     the **CI** colliding assertion reddens with "expected
     `case-insensitive-keyword-collision`, got none" (never a bare exit). (The
     corrupt-harness arm and the rejections lane also redden, but the pinned SPEC
     is this lane's direct assertion.)
  2. **collision ignores the flag** — drop the `case-insensitive?` guard so the
     fold check runs on every table ⇒ the **CS** colliding machine
     `(verification-ok? …)` assertion reddens (that table verifies at baseline —
     byte-distinct, case-sensitive — and is wrongly rejected under the mutant).
     This pins the per-table nature (decision 0045 item 1). The CS *header* table
     (four distinct names) does **not** witness this — it has no fold-colliding
     pair — so the pin needs the dedicated CS colliding fixture above.
  3. (**if it separates**) **fold boundary** — fold `@`(64)/`[`(91) ⇒ a collision
     case at a letter boundary changes verdict. Kept only if it produces a
     distinct FAIL the first two do not; otherwise dropped, not padded.
  Re-anchor any Slice ① pin whose `FIND` my `node-keyword-defects` edit shifts
  (grep `FIND`/`REPLACE` on `node-keyword-defects`, both directions —
  [[reanchor-replaces-not-just-finds]]). `EXPECTED_PASSES`/`EXPECTED_MUTATIONS`
  **recounted** from the rewritten manifest, never predicted, in the source
  commit.
- **Docs** — `CHANGELOG.md` `[Unreleased]` gains the collision diagnostic and the
  header demonstration; `.reference/source-ir-and-builder.md`'s keyword-table
  entry notes that a case-insensitive table's fold-colliding entries are rejected.
  Decision 0045 is already amended; no change.

## 5. Exit and boundaries

**Oracle.** *Recognition (criterion 4):* the CI header table matches
`Content-Length` / `content-length` / `cOnTeNt-LeNgTh` (and a second hyphenated
name) to one target and the CS table refuses the mixed casings — asserted on the
**generated** side absolutely and interpreter≡generated, `.chez.{source,aot}`.
*Rejection (decision 0045 item 3):* two fold-colliding CI entries refused **by
name** as `case-insensitive-keyword-collision`, and a CS table over the same
case-differing entries **verifies** (the per-table pin). *Census:* 32 codes over
58 sites, derived from `verify.sls`, in **both** census-drive programs
(`diagnostic-census-tests.sps` and `property-rejections-tests.sps`). *No
regression:* the property suite's **accepted-count** (`41`) is **re-measured** and
unmoved (the generator draws `case-insensitive? #f`, §1) — but the rejections
lane's census / sentinel / entry-count literals **do** move `31 → 32` (they count
diagnostic codes, not accepted machines); the six/seven goldens, the ABI literal,
and the node kind count are untouched.

**Commits.** One source commit (verifier + fixture + lane + corrupt harness + the
two census-drive programs + **the catalog** — the `diagnostic-census` lane checks
it against `verify.sls` via `BYTE_MACHINE_REPO_ROOT`, so it cannot lag the code +
pins + `EXPECTED` recount) and one documentation commit (CHANGELOG,
source-ir-and-builder, this plan). One PR, paused before merge for the go-ahead
(the slice-by-slice cadence).

**Deferred to Slice ③** (design §7): span composition (criterion 5 — a span
closing at the matched keyword's length, `MKCOL` from `MKCOLA`), the 47-keyword
before/after emitted-size measurement (criterion 7, both shapes emitted through a
registered lane), and the milestone close (criteria dispositioned, §29 admission
discharged, all status surfaces current, the 0.3.0 line).
