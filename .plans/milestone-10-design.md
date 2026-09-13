# Milestone 10 Design — An empty span, observable

**Status: Milestone 10 CLOSED (2026-09-13) — v0.2.0 released.** Gate 0 is
decision [0042](../.decisions/0042-empty-span-delivers-one-fragment-on-the-feed-side.md);
Slice ① (the mechanism, PR #122) and Slice ② (the release and close) are
delivered. Ships as **v0.2.0**.

Written against **`e9f8d9c`** (`main`; v0.1.0 released as `c38e76f`, tag
`v0.1.0`). Every anchor below was measured against that commit, in this checkout,
on `tarm64osx` / Chez Scheme 10.4.1 — the one Tier 1 cell that exists locally
(the release-ledger reality M9 recorded). Measurements are cited by construct and
`file:line` at `e9f8d9c`; a slice that edits a file re-resolves its own citations
as its last step before commit (AGENTS.md, "A `file:line` into a document your
own commit also edits must be re-measured").

Authority, in order: the upstream brief
(`~/github/chez-httparse/.plans/2026-09-13-upstream-empty-span-brief.md`, the
consumer's ask, recorded under its decision 0006 item 4) and the parent
[implementation plan](./byte-machine-implementation-plan.md) — `§13` (the
callback contract), **`§14` (span semantics)**, `§29:1767` (the admission bar for
new semantic behaviour) — then decision 0042, then `AGENTS.md`.

This is the first milestone opened after the release, and the first opened from a
consumer's brief rather than the parent plan. M9 was the *final planned*
milestone (`§25:1651`); this work is neither a `§25` milestone nor a `§29`
deferred extension, so it is admitted under `§29:1767`'s bar — interpreter
semantics, verification rules, generated parity, documentation, and tests before
admission — as a minor release.

---

## 1. Summary

A byte-machine span that opens and closes **having delivered no bytes at all**
notifies its consumer of nothing: the span-data callback never fires, so a
consumer cannot tell "this optional field was present and empty" from "this field
never happened." This milestone makes an empty span observable — its data
callback fires exactly once, with an empty range — **without** reintroducing the
spurious deliveries the current suppression exists to prevent.

The whole mechanism is a per-span "delivered anything yet" flag and a two-way
split of the one procedure that delivers every span fragment. It touches
`runtime.sls` only in `src/`; the emitted text does not move, the verifier does
not move, and the generated ABI does not move. The visible surface of the change
is entirely in the differential test lanes, where the existing "an empty fragment
is suppressed" assertions are the OLD contract and are deliberately re-baselined.

Two slices:

- **Slice ① — the mechanism.** The flag, the step split, the four call sites, the
  re-baselined and added differential fixtures, the property-driver observable,
  the re-authored and new mutations, and the `§14` dated disposition. One atomic
  commit, because flipping the suppression and its by-value assertions cannot be
  split without a red intermediate (AGENTS.md, "A plan that schedules a red
  intermediate commit is the thing that is wrong").
- **Slice ② — the release and the close.** The version surface to `0.2.0`, the
  `CHANGELOG.md` section, the release ledger's version surface, the tag, and the
  five milestone-status surfaces.

## 2. Why this shape

The brief calls the change "non-trivial" for one reason: the single shared
procedure `byte-machine-span-fragment-step/v1` serves four callers with different
requirements, and the property that decides delivery — *has this span delivered
anything?* — is state the runtime does not keep. The naive fix (invert `>=` to
`>`) announces "empty" for a non-empty span whose final fragment happens to be
empty because it fell on a feed boundary. So the shape is forced:

1. **Keep the property, not the sign of a comparison.** A flag cleared at
   span-open, set on any real delivery, answers the span-level question that a
   fragment-level comparison cannot.
2. **Split the callers, not the signature.** Every span END delivers an empty
   span once (feed-loop, emitted, and EOF-side — the generated lane reaches all
   three through the same emitted arm, so keeping the emitted text unchanged
   *forces* the EOF side to deliver too); only the FLUSH keeps suppressing,
   because it is not a span end. The public step gains the behaviour, guarded by
   `from == to` so the one incoherent EOF case (a span carried from a feed,
   `from > to`) still suppresses; a private entry point keeps the flush's
   unconditional suppression.
3. **Do not move the emitted text.** Keeping the emitted call byte-identical is
   what keeps the six determinism goldens, the `reserved-member-3` drift check,
   and the generated ABI still — a large, load-bearing "nothing moved here" the
   slice asserts rather than re-baselines.

## 3. What the tree already settles

Six read-only surveys against `e9f8d9c`. Their findings, and where each
contradicts or confirms the brief:

### 3.1 Goldens, `reserved-member-3`, and the ABI — unchanged if the emitted text is

Six committed determinism goldens compare emitted **text** byte-for-byte; only
`test/fixtures/generated-http.golden.sls` contains a span-end arm, and its
load-and-run leg registers no callbacks (`(make-parser cm '() #f)`), so the
`unbound-callback?` short-circuit makes the change a no-op there. `member3-drift-tests.sps`
renders a machine with a span-end node and asserts `leftover ⊆ reserved-member-3`
plus a count of ten emitted locals, twice. **All stay green iff the emitted
span-end arm binds no new local** — which the chosen shape guarantees, because
the emitted call is untouched. The generated ABI stays **5** (decision 0042
item 3). Editing any listed `.sls` needs a provenance reconfigure
(`touch test/CMakeLists.txt && cmake --preset dev && cmake --build --preset dev`)
before the property lanes pass — a build hygiene note for the slice, not a design
choice.

### 3.2 The behaviour lives in the differential lanes — the brief's SPEC-lane note is wrong

The brief names `runtime-tests`/`interpret-tests` as the suppression's test host.
Neither covers span fragments (`runtime-tests.sps`'s only span mention asserts
`parser-active-span` is `#f` on a fresh parser; `interpret-tests.sps` has zero).
All span-fragment delivery is tested through the differential lanes, which build
a real machine, verify it, compile+emit+load the generated lane, interpret the
reference lane, and compare fragment traces **by value and across lanes**:

- `differential-span-tests.sps:250-254` — "AZ delivers no data callback at all,
  only the completion", asserts `'(complete)`. **Re-baselined** to
  `(list (bytes) 'complete)`: the feed-loop span-end now delivers one empty
  fragment.
- `differential-span-tests.sps:486-499` — a span opened and closed entirely on
  the **EOF chain** (mark 0), asserts `'(complete)`. **Re-baselined** to
  `(list (bytes) 'complete)`: `[0,0)` is a coherent empty range, so the EOF span
  end delivers once, matching the generated lane (which reaches it through the
  emitted arm). The carried-span cases in the `eof-close-machine` group nearby
  (`from > to`) stay green — those the `from == to` guard still suppresses
  (decision 0042 item 4).
- `differential-counted-span-tests.sps:142-156` — the `0:,` empty counted body,
  asserts `'(complete)`. **Re-baselined** (feed-loop span-end).
- `http-message-tests.sps:98-105` — "an all-OWS value produces an empty value
  span", asserts `count-of 'header-value-data == 0`. **Re-baselined** to `1` —
  this is the exact consumer shape (an empty header value).

Coverage gaps the slice closes with new by-value fixtures: criterion 2 (a split
span's empty final fragment) is checked in the delimiter lane only for cross-lane
agreement, and the coalescer normalises the empty fragment away, so a both-lanes-wrong
spurious delivery would pass today; criterion 3 (a flush finding nothing) has no
case. The counted lane already pins criteria 2 and 3 by value through its derived
`expected-per-feed` table.

The property driver (`property-driver.sls:411-418`) derived `span-suppressed-empty`
when a completion was reached with zero data fragments. After the change an empty
span always delivers a zero-length fragment, so that key would lose its witness;
the observable that the coverage machine's `covy` now produces is a zero-LENGTH
delivered fragment. The member is reframed `suppressed-empty → empty-fragment`
(derived from a delivered fragment of length 0), so its counter list, its
`family-members`, and the **declared-literal totality row**
`'(span-open boundary-fragment end-fragment completion empty-fragment)`
(`property-differential-tests.sps:369`, `set-equal` + count 5) move together
(AGENTS.md, "A closed-set totality row is a floor-independent pin"; a *declared*
family's row is a cited literal, so a rename fails it by name).

### 3.3 The verifier does not move

Pass 7's span lattice is `{⊥, none, (active s), ⊤}` (decision 0029) with no byte
extent, so an empty span already verifies clean and no span check constrains
length. `span-active-at-exit` rejects a span active at a *successful* terminal
(`stop`/`finish`) only, never at `error` (`verify.sls:1676-1681`), and an empty
span that opens→ends→completes linearly is not a zero-progress cycle. The one
behavioural change adds no node kind and no pause site; a span-end's data-callback
pause is already a modelled parked state. **No pass-7 rule, reachability rule, or
EOF-execution check changes.**

### 3.4 The mutation surface

Exactly one mutation pins the suppression:
`SchemeMutationSuite.cmake` "an empty span fragment is delivered instead of
suppressed" (`FIND` on `runtime.sls:587`, `REPLACE` inverting `>=`→`>`,
`EXPECT_OUTPUT_MATCHES "completion only -- …"`, witnessed by the AZ case). Under
the fix the `FIND` text survives in `span-fragment-suppress-empty` (the flush
helper), but its witness moves: AZ now goes through the public step, which
delivers. It is **re-authored** — measured against the flush's own empty case —
rather than deleted or loosened. New mutations, each witnessed in its own SPEC
lane's program, `differential-span-tests.sps` (the only program that observes a
span fragment): the flag clear-on-open, the flag set-on-deliver, the public
step's `from == to` empty-delivery guard, and the public-vs-suppress choice at the
call sites. `EXPECTED_MUTATIONS`/`EXPECTED_PASSES` are recounted from the rewritten
manifest, never predicted (currently 602/65).

### 3.5 The spec and the version

`§14:831` (item 2) and `§14:834` (item 5) are the normative source of the
suppression at a span end; they are amended by a dated disposition at the
parent-plan foot (`§1802`), never inline (the append rule protects the dozens of
`§14:83x` citations across the tree). `§14:833` (item 4, the flush) is unchanged.
`§29:1767`'s admission bar is the model for admitting the behaviour. The release
is v0.2.0 (decision 0042 item 6); the release ledger's version surface
(`release-version "0.1.0"` and five mirror surfaces) is updated in place — the
`§26`/`§27` criteria are the v0.1 release criteria the ledger checks and do not
gain a row for an added behaviour.

## 4. Gate 0 — the design calls this milestone resolves

Folded into decision
[0042](../.decisions/0042-empty-span-delivers-one-fragment-on-the-feed-side.md)
(the M8/M9 pattern: no separate gate-0 plan). Its six numbered decisions are the
flag, the signature-preserving step split, the no-ABI-bump, the symmetric EOF
delivery (`from == to`-guarded), the `§14` amendment mechanism, and the v0.2.0
framing. Two design calls the owner resolved at kickoff:

- **Version framing → v0.2.0 minor, as this milestone.** It changes a documented,
  tested invariant and adds observable output — a semver change, not a fix.
- **Generated ABI → no bump, stay ABI 5.** The contract shape is unchanged, so
  semver forbids an ABI break; the consumer's ABI-5 assertion stays true and its
  gitlink-pin re-measure ritual carries the signal (decision 0042 item 3).

The EOF-side behaviour took two turns during implementation, both back to the
owner (decision 0042 item 4). First: **the EOF-side span-end delivers
symmetrically** — the first plan (keep EOF suppressing) would need a `finish?`
branch in the emitted arm (`parser-finish-v2!` runs the emitted `exec` for EOF),
moving the HTTP determinism golden; keeping the emitted text unchanged forces EOF
to deliver too. Then the whole-branch review showed that "deliver only the coherent
`from == to` cases, no finish re-anchor" was slicing-dependent (a span carried from
a feed and closed empty at EOF fired only when its last feed started at 0). So
**`parser-finish!` re-anchors the mark to 0** before the EOF chain, so every EOF
span end sees `from == to` and every empty span — carried or EOF-opened — is
announced exactly once, uniformly. `from > to` is then unreachable at any span
end; the step's guard is defence.

### 4.1 The gate every slice asserts

No `src/` file outside `runtime.sls` changes, and `runtime.sls`'s emitted-text
producers in `compile.sls` are untouched. The determinism goldens and
`reserved-member-3` do **not** move; a slice that finds one moved has a bug, not
a re-baseline. `git diff --stat main..HEAD -- src/` names `runtime.sls` and
nothing else.

## 5. Slice ① — The mechanism

One atomic commit. TDD, tests first.

- **Runtime.** Parser slot 16 `span-delivered?` + accessor pair; append its
  initial `#f` to both `make-parser` vector literals; reset it in
  `byte-machine-span-close/v1` **only** (make-parser inits it `#f`, so span-open
  needs no clear — one load-bearing reset). Split the step: the public
  `byte-machine-span-fragment-step/v1` gains deliver-if-never-delivered with a
  `from == to` guard (deliver on `from < to`; deliver an empty fragment on
  `from == to` with the flag clear; suppress otherwise) and sets the flag on any
  delivery via the shared `span-fragment-deliver!`; a private
  `span-fragment-suppress-empty` keeps unconditional suppression for the flush.
  Repoint the flush (`:617`) to the private entry point; leave the feed-loop
  span-end (`:861`), the EOF span-end (`:1172`), and the emitted arm
  (`compile.sls:423`, unedited) on the public one. **Add a mark re-anchor to 0 at
  the top of `parser-finish!`** (mirroring the per-feed re-anchor) so every empty
  span closing at EOF — carried or EOF-opened — sees `from == to` and delivers
  uniformly (item 4). Rewrite the stale comments (the fragment-step's suppression
  paragraph, and the EOF path's re-anchor notes) to describe the split, the
  finish re-anchor, and the uniform EOF delivery.
- **Differential lanes.** Re-baseline the by-value suppression assertions
  (§3.2); add by-value fixtures for criteria 2, 3, a pause on the empty
  delivery (criterion 5), and a carried empty span closing at EOF delivering
  uniformly (item 4, both slice starts), driving every feed/resume with
  `for-each`/named `let`.
- **Property driver.** Reframe the `span-suppressed-empty → empty-fragment` observable, its counter
  list, `family-members`, and the totality-row literal + count together.
- **Mutations.** Re-author the suppression pin; add the new mutations; recount
  the totals from the manifest; run the whole scheme mutation lane and confirm
  each new/changed pin is caught for the *reason it names* (the wrong-reason guard
  and the exit status, never the "suite complete" line).
- **Spec.** Append the `§14` dated disposition.

Exit: acceptance criteria 1–8 of the brief hold; `make test` green in both Chez
modes; the scheme mutation lane green with recounted totals; the emitted text and
the six goldens unmoved.

## 6. Slice ② — The release and the close

Written against its own re-taken base after Slice ① merges (one plan at a time).
Version surface → `0.2.0`; `CHANGELOG.md` `[Unreleased]` → dated `[0.2.0]` under
`### Changed`/`### Added`; release-ledger `release-version` and hardcoded version
assertions updated; annotated tag `v0.2.0`; and all five milestone-status
surfaces (milestone plan / parent plan / `CHANGELOG` preamble / this design /
`README.org`) say M10 closed. Exit: `(byte-machine test release-ledger)` green
against `0.2.0`; the tag exists; the five surfaces agree.

## Exit (full Milestone 10)

The brief's eight acceptance criteria hold; v0.2.0 is tagged; the consumer can
bump its gitlink pin off `v0.1.0` against generated ABI 5 and re-measure. The
`§14` disposition and decision 0042 record the amended invariant.

## Explicitly out of Milestone 10

- **Multiple concurrent or nested spans, and every other `§29` deferred item.**
- **Any change to the callback signature** (brief §9) or the verifier's span
  rules.
- **A production HTTP grammar** — that is the consumer's, on byte-machine.

## Handed to writing-plans

- **Slice ①** — this design §5 and decision 0042's Slice ① consequences. Its base
  is `e9f8d9c` (or the current `main` at write time).
- **Slice ②** — this design §6 and decision 0042's Slice ② consequences. Written
  against its own base after Slice ① merges.

## References

- Upstream brief: `~/github/chez-httparse/.plans/2026-09-13-upstream-empty-span-brief.md`
- Decision [0042](../.decisions/0042-empty-span-delivers-one-fragment-on-the-feed-side.md)
- Decisions [0027](../.decisions/0027-reachable-path-for-callbacks-and-spans.md),
  [0029](../.decisions/0029-span-state-is-a-lattice.md) — the span-state lattice
  and the reachable-path contract this rests on unchanged.
- Parent plan `§13`, `§14`, `§29:1767`.
