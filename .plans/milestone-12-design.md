# Milestone 12 Design — A pause says why

**Status: Milestone 12 CLOSED 2026-09-14 — v0.4.0 released.** Delivered as this
design plus Gate 0 = decision
[0046](../.decisions/0046-a-pause-carries-a-reason.md) (the M8–M11 pattern: the
gate is folded into one decision, no separate gate-0 plan) plus two slices —
Slice ① (the mechanism end to end; PR #128 = `f8fc243`) and Slice ② (this
v0.4.0 release and close). The six acceptance criteria are dispositioned in the
[Close](#close-2026-09-14--the-six-criteria-dispositioned) section below.

Written against **`9c027fd`** (`main`; v0.3.0 released as `9c027fd`, tag
`v0.3.0` — Milestone 11 Slice ③ was the release commit). Every anchor below was
measured against that commit, in this checkout, on `tarm64osx` / Chez Scheme
10.4.1 — the one Tier 1 cell that exists locally (the release-ledger reality M9
recorded). Measurements are cited by construct and `file:line` at `9c027fd`; a
slice that edits a file re-resolves its own citations as its last step before
commit (AGENTS.md, "A `file:line` into a document your own commit also edits
must be re-measured").

Authority, in order: the upstream brief
(`~/github/chez-httparse/.plans/2026-09-14-upstream-pause-reason-brief.md`, the
consumer's ask, recorded under its decision 0006 item 4) and the parent
[implementation plan](./byte-machine-implementation-plan.md) — `§9` (the public
API surface), `§12` (lifecycle), `§13` (the callback contract), `§22.4` (pause
continuations), `§29:1767` (the admission bar for new semantic behaviour) — then
decision 0046, then `AGENTS.md`.

This is the third milestone opened from a consumer brief rather than the parent
plan (M10 empty-span was the first, M11 keyword-table the second). It is neither
a `§25` milestone (M9 was the final planned one, `§25:1651`) nor a `§29`
deferred extension, so it is admitted under `§29:1767`'s bar — interpreter
semantics, verification rules, generated parity, documentation, and tests before
admission — as a minor release.

---

## 1. Summary

A machine that reaches a **pause node** yields `status = 'paused` and nothing
more: the parser result's error slot is `#f`. A consumer that pauses for more
than one reason cannot tell its caller which, and a consumer that renders parser
outcomes as text cannot render a pause without inventing words. This milestone
gives a pause the same `(code, reason)` identity an error already has —
**without making it an error**: a paused parser stays resumable, `status` stays
`'paused`, and the lifecycle rows do not move.

The whole mechanism is an **optional reason declaration** on the two
author-facing pause points — the `pause` node and the `callback` node — and the
threading of that reason from the pausing site to a **new, distinct** result
slot. `parser-result-error` stays `#f` for a pause (so a consumer that only
checks the error slot still reads "not failed"); a new `parser-result-pause`
carries a `parser-error`-shaped value, so the consumer's existing code→name
rename table needs no second kind. The generated ABI moves **6 → 7**, because
the emitted paused-outcome's payload contract moves (its error slot goes from
always-`#f` to possibly a reason record) — read out of the emitted text as
`v0.3.0` did for ABI 6.

Two slices:

- **Slice ① — the mechanism.** The optional reason on `make-pause-node` and
  `make-callback-node`; the verifier resolution; the eight interpreter pause
  sites and the two generated→result boundaries; the four generated pause arms
  and the ABI 6→7 bump; the extended differential / interpret / determinism
  pause lanes (including the resume-and-re-pause-with-two-reasons case); the
  property driver; the re-authored and new mutations; the size measurement. One
  atomic commit — the ABI bump, the result-shape growth, and the emitted pause
  arms cannot be split without a red intermediate (AGENTS.md, "A plan that
  schedules a red intermediate commit is the thing that is wrong").
- **Slice ② — the release and the close.** The version surface to `0.4.0`, the
  `CHANGELOG.md` section, the release ledger's version surface + hardcoded
  assertions, the annotated tag, and the five milestone-status surfaces.

## 2. Why this shape

Two brief traps (§5) force the shape:

1. **A pause is not an error and must not become one.** The tempting shortcut is
   to route a pause through an error node (the corpus line is textually
   identical and no fixture resumes), or to reuse the *public* result error slot
   for the pause reason. Both are wrong: the first makes the parser unresumable;
   the second makes `parser-result-error` non-`#f` for a pause, so a consumer
   written before this change that treats "has an error" as "failed" breaks
   (brief §6). So the reason goes to a **new, distinct** result slot, leaving the
   error slot `#f` for a pause. `status` stays `'paused`.

2. **There are two author-facing pause paths, not one.** The `pause` NODE and a
   `callback` NODE whose callback returns `callback-pause` both produce
   `'paused` (`runtime.sls:916`, `:962`). Covering only the pause node would give
   a consumer a reason for one and `#f` for the other — "worse than `#f` for
   both" (brief §5). So the reason is a static, per-node optional declaration on
   **both** kinds, read by a single `pause-reason-of` helper at every pause site.

The reason DATA reuses the existing `error-declaration` family (name, code,
reason, label) referenced by name, because a pause reason and an error reason
are the same data — a `(code, reason)` pair the consumer renames through one
table (brief §7: `paused-upgrade . 22` beside `paused-h2-upgrade . 23`). The
"it is not an error" distinction lives at the RESULT (a distinct slot + the
`'paused` status), not in the declaration family. This adds no declaration
family and no machine slot; the pause node names one of the machine's existing
error declarations, exactly as an error node does.

## 3. What the tree already settles

Read-only survey against `9c027fd`.

### 3.1 The pause sites, and where the reason attaches

| site | `runtime.sls` | pause producer | reason source |
|---|---|---|---|
| feed-loop pause node | `:916-920` | pause node | the node's optional reason |
| feed-loop callback pause | `:962-965` | callback node | the node's optional reason |
| feed-loop span-end pause | `:1001-1004` | span-data callback | **none** (see §3.4) |
| feed-loop span-completion pause | `:1031-1034` | span-complete callback | **none** (see §3.4) |
| finish pause node | `:1243-1246` | pause node | the node's optional reason |
| finish callback pause | `:1280-1283` | callback node | the node's optional reason |
| finish span-end pause | `:1324-1327` | span-data callback | **none** (see §3.4) |
| finish span-completion pause | `:1350-1353` | span-complete callback | **none** (see §3.4) |

All eight build `(make-parser-result 'paused … #f)` today; the four
reason-bearing ones gain the reason in the new pause slot. A **ninth** paused
result is built at `runtime.sls:762`, inside `span-boundary-flush!` — the
trailing-fragment flush that wraps BOTH feed variants (called at `:846` on the
output of `parser-feed-op!` and `parser-feed-v2!`): if the flushed span-data
callback pauses, `:762` produces `'paused`. It is a span-callback pause (no reason
surface, §3.4), so it correctly stays `#f`, but note it is a generated-side pause
that sits DOWNSTREAM of the `:1101-1103` boundary — so "every generated pause
routes through the two boundaries" is not literally true; the flush pause is the
one exception, and it needs no reason. Under the new `case-lambda`
`make-parser-result` (§3.2) its 5-arg call defaults the pause slot to `#f`
unchanged, so no edit is needed there beyond acknowledging it. The generated
finish path (`parser-finish-v2!`, `:1192-1205`) threads `feed-outcome-error` into
the result already, so it is covered by the boundary routing below; it has no
pause arm of its own.

### 3.2 The result and outcome shapes — the ABI moves because the emitted payload contract does

`parser-result` is a six-element vector (`make-parser-result`, `runtime.sls:180`:
tag + five args status/next/consumed/stream-offset/error). It gains a **seventh**
element, `pause`, holding a `parser-error`-shaped value or `#f`, via a
`case-lambda` so the ~20 non-pause construction sites do not change (**5-arg →
`pause` defaults `#f`; 6-arg → `pause` given** — the tag is a constant, not an
argument). The new `parser-result-pause` accessor length-guards the short arity
(returns `#f`). `parser-result` is a runtime record, not part of the
generated↔runtime ABI, so this element alone does not move the ABI.

`feed-outcome` is a five-slot record (`byte-machine-make-feed-outcome/v1`,
`runtime.sls:163`: status, next, error, next-state, offset). Its `error` slot
(slot 3) is the outcome's diagnostic-payload channel — a `parser-error` for an
error status, `#f` for every other status today. The generated pause arms
(`compile.sls:285`, `:411`, `:447`, `:474`) emit `#f` in it. For a
reason-bearing pause, the emitted arm instead constructs the reason record
there with the same `byte-machine-make-parser-error/v1` call the emitted error
arm makes (`compile.sls:158`) — **but the code and reason reach that arm only
through the normalizer and the errs table, not from the source node** (§3.7):
the emitter is handed a normalized state, so `normal-ir.sls` must carry the
resolved reason into it, and the errs-table reached-walk must include the pause
reason or the arm's `(vector-ref errs …)` raises at emit time. **This moves the
emitted paused-outcome's payload contract** — slot 3 of a paused outcome goes
from "always `#f`" to "`#f | ParserError`" — so a consumer decoding a v7
generated parser must know this. That is an honest ABI move (the emitted CONTRACT changed), unlike Milestone
10, where the emitted text stayed byte-identical and decision 0042 item 3 rightly
declined a bump. `current-abi-version` (`runtime.sls:92`) and the emitted literal
(`compile.sls:763`, `(byte-machine-make-compiled-machine 6 …)`) move **6 → 7**;
the ABI lane reads it out of the emitted text (`compile-tests.sps:208`).

The feed-outcome keeps five slots. At the two generated→result boundaries —
`parser-feed-v2!` (the generated feed path, `runtime.sls:1089-1103`, NOT
`parser-feed-op!`, which is the interpreter loop) and `parser-finish-v2!`
(`:1204-1205`) — the runtime routes slot 3 by status:
`error` slot gets it when the status is `'error`, the new `pause` slot gets it
when the status is `'paused`, both `#f` otherwise. One outcome carries exactly
one status, so the routing is unambiguous. This keeps the emitted-text delta to
the four pause arms only (not every outcome site).

### 3.3 The verifier resolves the reason exactly like an error node's

`pass-names` (PASS 2, `verify.sls:322`) resolves an error node's declaration by
name — `missing-error-declaration` when `(error-node-error-name n)` is not in
`(error-names m)` (`:351-354`). A pause/callback node that names a reason gets
the same arm. There is **no** "every declared error is referenced by an error
node" check (only `duplicate-error-declaration`, `:336`), so a declaration
referenced by a pause node is clean. The reason name is a declaration reference,
NOT a node target, so it must **not** enter `node-out-targets` (`:265`); the
pause node's `zero-width-edges` arm (`:171`) returns only its `continuation`,
exactly as `error-node-error-name` does not enter the target set. No reachability, EOF-execution, or span/lattice rule moves: the identity is
a leaf datum on a node whose graph shape is unchanged.

### 3.4 Span-data / span-complete callback pauses stay `#f`, by design

The span-end and span-completion pause sites (§3.1, four rows) are a span
callback returning `callback-pause`. They are an internal
fragment-resumption mechanism — the parser parks on the next undelivered substep
(`runtime.sls:1002`, `:1032`) — not an author-declared pause POINT, and the span
node kinds carry no reason surface. Adding one would mean a new optional field on
the span DECLARATION, an unmotivated widening the consumer does not need (llhttp's
reason-bearing pauses are the upgrade pause — a pause node). So `pause-reason-of`
returns `#f` for these, and they keep today's behaviour. This is a documented
scope line, not an oversight: a consumer that never pauses in a span callback (no
`§25`/`§29` grammar does) sees a uniform surface, and the boundary is stated here
and at the sites (AGENTS.md, "A comment justifying an ABSENT arm must say whether
adding it would be inert or WRONG" — here adding it would be WRONG scope, needing
a span-declaration field for no consumer).

### 3.5 The pause fixture, the lanes, and the mutation surface

`test/support/harness/byte-machine/test/pause-machine.sls` is the shared pause
proving machine (`make-pause-node 'p1 's1 #f`, `make-pause-node 'pe 'done #f`),
driven by `differential-pause-tests.sps` (interp ≡ gen), `pause-interpret-tests.sps`,
and `determinism-pause-tests.sps` (the golden `generated-pause.golden.sls`). The
differential lane's `rfields` (`differential-pause-tests.sps:32-35`) projects the
error slot via `(byte-machine test error-projection)`; it gains a
`(project-error (parser-result-pause r))` field so a reason divergence is a
cross-lane failure. The optional reason is added to `pause-machine.sls` (or a
reason-bearing sibling fixture) with two distinct declared reasons so criterion 4
(resume and re-pause report two different reasons) is by-value.

Mutations live in `SchemeMutationSuite.cmake`. New pins, each witnessed in its
own SPEC lane's program (the differential/interpret pause lanes): the
reason-read at the pause-node arm, the reason-read at the callback arm, the
error/pause boundary routing (a mutant routing the reason to the error slot must
redden — this is the §6 guard turned into a pin), and the `pause-reason-of`
absent→present direction. `EXPECTED_MUTATIONS`/`EXPECTED_PASSES` are recounted
from the manifest, never predicted (currently 69 passes / 622 mutations).

### 3.6 The size measurement (criterion 6)

A before/after emitted-size measurement, as the keyword-table work recorded
(M11 Slice ③): the emitted bytes of the pause proving machine WITHOUT a reason
(the shape shipped at v0.3.0) versus WITH a declared reason on its pause node,
measured through the real emitter. The reason's cost is one
`byte-machine-make-parser-error/v1` call in one arm — expected to be small and
bounded; recorded MEASURED, with the reproduce command beside it, never a
prototype number (AGENTS.md, [[scratch-fixture-measurements]]).

**Measured 2026-09-14** (through the real emitter, `render-machine`): a
two-node pause machine emits **1825 bytes** without a reason and **1942 bytes**
with one declared upgrade reason — **+117 bytes**, the one errs-table entry plus
the one `byte-machine-make-parser-error/v1` construction the reason arm adds.
The cost is per declared reason and bounded; a reason-less pause is byte-identical
(criterion 1). Re-derive with a two-node pause machine built through
`(byte-machine graph)`, rendered with and without a `reason` on its pause node:
`(bytevector-length (render-machine (compile-machine m '()) 'sz))`. Recorded here
and in the `CHANGELOG.md` `[0.4.0]` entry (Slice ②); no committed size LANE, since
unlike the keyword-table's 34× win the reason's cost is incidental, not the
milestone's point.

### 3.7 The normalizer and the fingerprint carry the reason — "the encoding is not the same list as what the emitter reads"

The emitter is handed a **normalized** state, never the source node
(`render-state-arm`, `compile.sls:256`), and reads error data from the normalized
slots (`normal-error-code`/`-reason`, `:280-281`); the pause arm reads only
`normal-pause-target` (`:286`). So the pause reason reaches the emitter ONLY if
the normalizer puts it there. `lower-machine` builds the pause state
(`normal-ir.sls:552-555`) and the callback state (`:627-635`) with the code and
reason slots `#f`; Slice ① resolves the reason name to `(code . reason)` via the
existing `errcode`/`errreason` helpers (`:310-317`) into those slots, mirroring
the error-node arm (`:547-550`).

Two consequences the design must own, both AGENTS.md's decision-0019 rule ("a
datum the ABI carries must be in the encoding, not merely read from the source"):

1. **The fingerprint encoder must encode the reason, under a presence guard.**
   `encode-normal`'s pause arm (`normal-ir.sls:765`) writes tag 4 + the
   continuation id only; the callback arm (tag 10, `:823-840`) encodes no reason.
   If the emitter emits a reason but the encoder ignores it, two pause machines
   differing only in reason get the SAME fingerprint but DIFFERENT emitted bytes —
   silently breaking "equal fingerprints ⇒ equal bytes," the invariant
   `normal-ir-tests.sps:111` guards for error reasons and the mutation suite pins
   at Pass 35/36 (`SchemeMutationSuite.cmake:476-483`). The reason bytes are
   written **only when a reason is declared** (like the keyword-table section,
   decision 0044), so a reason-less pause machine's fingerprint does not move —
   criterion 1. `normal-ir-tests.sps` gains the mirror of `:111` (differ-in-reason
   ⇒ differ-in-fingerprint) and `:116` (an unreferenced reason does not reach the
   encoding).

2. **The errs-table reached-walk must include the pause reason.** The emitted
   `errs` vector holds only the `(code . reason)` pairs the normalized graph
   *reaches* (`compile.sls:575-606`): today, error states and the dispatch-family
   default-EOF routes. Pause/callback states hit its `(else #f)` arm and
   contribute nothing, so a **pause-only** reason (the consumer's
   `paused-upgrade . 22`, distinct from any error code) is filtered out of `errs`,
   and the emitted pause arm's `(vector-ref errs (index-of code reason))` raises
   `render-machine "no error declaration for code"` at EMIT time (`:651-660`) —
   the exact footgun `:581-597` documents for the accumulate/keyword-table kinds.
   Slice ① adds a pause/callback arm to the reached-walk.

This is the correction to the "exactly as an error node does" phrasing in §2 and
the earlier drafts of §3.2/decision item 5: at the SOURCE and VERIFIER level the
pause node names a declaration exactly as an error node does, but carrying that
reason to the GENERATED lane travels a path the error node's does not fully share
— a new normalizer thread, a new fingerprint arm, and a new reached-walk arm.

## 4. Gate 0 — the design calls this milestone resolves

Folded into decision
[0046](../.decisions/0046-a-pause-carries-a-reason.md). Its numbered decisions
are: the optional error-declaration reason on the two author-facing pause node
kinds; the distinct result `pause` slot leaving `error` `#f`; the
`parser-error`-shaped reason value; the feed-outcome error-slot reuse with
status routing at the boundary; the honest ABI 6→7 bump; the span-callback `#f`
scope line; and the v0.4.0 framing. Two calls the owner resolves at kickoff and
the slice validates with a prototype:

- **Version framing → v0.4.0 minor.** Adds observable output and new optional
  public API (`make-pause-node`/`make-callback-node` reason, `parser-result-pause`)
  with no break — a semver minor, as M10 (v0.2.0) and M11 (v0.3.0) were.
- **ABI → bump 6→7.** Justified by a genuine emitted-payload-contract move
  (§3.2), not a behaviour change in an unchanged shape (which decision 0042 item
  3 rightly declined for M10). The consumer re-measures and bumps its pin against
  ABI 7 (brief §7), as it did for ABI 6.

### 4.1 What Slice ① validates with a prototype before committing to fixtures

Per brief §6 ("do not design from the brief alone; the slice that does the work
owns the design") and the M10/M11 precedent (prototype the load-bearing shape
first): a scratch prototype in an isolated worktree confirms, in BOTH lanes,
that (a) a pause node with a declared reason reports the reason in the pause slot
with the error slot `#f` and status `'paused`; (b) a resume then a re-pause at a
second node reports the SECOND reason, not the first (criterion 4); (c) reusing
`error-declaration` trips no verifier pass; and (d) a generated reason-bearing
pause **emits and runs end-to-end** — not merely grepping the ABI literal — so
the normalizer threading, the fingerprint arm, and the errs-table reached-walk
(§3.7) are all exercised and the emit-time `no error declaration for code`
assertion cannot hide until fixtures; and the ABI literal reads 7. If reusing
`error-declaration` proves to trip a pass, the fallback is a minimal
`pause-declaration` family of the same shape (brief §4.1 sanctions either) —
measured, not assumed.

## 5. Slice ① — The mechanism

One atomic commit. TDD, tests first.

- **IR (`ir.sls`).** `make-pause-node` and `make-callback-node` gain an optional
  trailing reason (a declared error name or `#f`) via `case-lambda` — the
  existing arities keep today's behaviour, so no existing machine changes
  (criterion 1). Add the `-reason` accessor to each, length-guarded to return `#f`
  on the short arity. The reason is a symbol or `#f`, checked for local shape
  only; declaredness is the verifier's.
- **Verifier (`verify.sls`).** Resolve a pause/callback node's reason name
  against the error declarations, mirroring the error-node arm at `:351-354`
  (`missing-error-declaration`, or a `missing-pause-declaration` code if the
  prototype shows the shared code muddies diagnostics). Confirm the reason does
  not enter `node-out-targets`.
- **Normalizer + fingerprint (`private/normal-ir.sls`) — §3.7, the seam the
  emitter reads through.** `lower-machine` resolves the reason into the
  normalized pause state (`:552-555`) and callback state (`:627-635`) code/reason
  slots via `errcode`/`errreason` (`:310-317`), mirroring the error-node arm
  (`:547-550`). `encode-normal`'s pause arm (`:765`) and callback arm (`:823-840`)
  encode the reason **under a presence guard** — reason bytes only when a reason
  is declared, so a reason-less machine's fingerprint does not move (criterion 1).
- **Compiler (`compile.sls`).** Extend the errs-table reached-walk (`:575-606`)
  with a pause/callback arm so a pause-only reason survives into `errs` (else the
  arm's `index-of` raises at emit time, §3.7). The pause-node and callback pause
  arms (`:285-287`, `:411-412`) emit the reason record (read from the normalized
  slots + `errs`) into the outcome's error slot when the site declares one (else
  `#f`, unchanged); the two span pause arms (`:447`, `:474`) stay `#f`. Bump the
  emitted ABI literal 6→7 (`:763`). Add `parser-result-pause` to `reserved-member-2`
  (`:53-73`), beside `parser-result-error`, or the reserved-drift lane fails
  (brief §5 trap 4).
- **Runtime (`runtime.sls`).** Add the `pause` element to `make-parser-result` via
  `case-lambda`; export and add `parser-result-pause`. Add a `pause-reason-of`
  helper (reads a pause/callback node's declared reason, builds a
  `parser-error`-shaped value from the resolved declaration, or `#f`). Fill it at
  the four reason-bearing interpreter pause arms (`:920`, `:965`, `:1246`,
  `:1283`); the span-callback pause arms (`:1003`, `:1033`, `:1327`, `:1353`) and
  the flush pause (`:762`) pass `#f`. Route feed-outcome slot 3 to the error/pause
  result slot by status at the two v2 boundaries (`:1101-1103`, `:1204-1205`).
  Bump `current-abi-version` 6→7 (`:92`).
- **Census & drift surfaces (loud ratchets — they fail the build, so name them).**
  Diagnostic census (`diagnostic-census-tests.sps`): the new verifier arm adds a
  `make-diagnostic/declarations` site — re-pin the per-code count (`:119`), the
  site total (`:615-619`), the layer-3 fixture (`:526-549`), and, if a new
  `missing-pause-declaration` code is chosen, its `code-fixtures` witness and the
  derived catalog check against `.reference/verifier-diagnostic-catalog.md`
  (`:659-671`). The ABI 6→7 bump also moves, beyond `compile-tests.sps:208`, the
  three direct `(byte-machine-make-compiled-machine 6 …)` constructions in
  `runtime-tests.sps` (`:286`, `:289`, `:534`) and the ABI-literal mutation pin
  (`SchemeMutationSuite.cmake:14004-14007`, FIND/REPLACE/irritant 6/5/5 → 7/6/6).
  A `verify-tests.sps` case parallels the error-node one (`:95`).
- **Round-trip printer (`test/support/harness/.../machine-print.sls`).**
  `print-pause` (`:120`) and `print-callback` (`:141`) render the reason field, or
  a reason-bearing machine loses it on print↔reparse (and `machine-corrupt.sls`,
  which edits the printed datum, needs it before any reason-targeting corruption).
- **Reference docs (mechanism-describing; version/status docs are Slice ②).**
  `.reference/source-ir-and-builder.md` (`:112`, `:140`, the constructor
  signatures — the `§27:1692` "documents every constructor" artifact);
  `.reference/generated-code-integration-chez.md` (`:98-103` parser-result
  accessors + `parser-result-pause`; `:122` "ABI currently `5`" is ALREADY stale,
  → 7); `.reference/transition-and-cursor-semantics.md` and
  `callback-span-lifetime.md` pause semantics; and the parent plan's §9.3 accessor
  call list gains a `parser-result-pause` disposition (the `parser-state-name`
  precedent), appended not inlined.
- **Tests.** Extend the pause fixture with two declared reasons; extend
  `differential-pause-tests.sps` `rfields` to project the pause slot; add the
  resume-and-re-pause-two-reasons case (criterion 4); add a callback-pause reason
  case; assert the error slot stays `#f` for a pause and `status` stays `'paused`
  and the lifecycle rows (`paused-feed`, `paused-finish`) are unchanged
  (criterion 3). Add `normal-ir-tests.sps` cases mirroring `:111`
  (differ-in-reason ⇒ differ-in-fingerprint) and `:116` (an unreferenced reason
  does not reach the encoding). Regenerate **all seven** determinism goldens
  (every one embeds `make-compiled-machine 6` verbatim and is byte-compared, so
  all move to 7; the pause golden additionally moves its reason-bearing arm) —
  asserting each fingerprint is unmoved except the pause golden's, which the
  reason changes. Add the size measurement (§3.6).
- **Property driver + mutations.** Reconcile any pause observable and the
  `property-driver.sls` rename-rebuild (`:688`, `:706-709`) so it carries a
  reason; re-author the pause mutation FINDs the shape change breaks
  (`SchemeMutationSuite.cmake:3708-3710`, `:3727-3730`, the Pass 35/36
  normalizer/encoder/emitter pins `:476-483`, and the error-threading pins around
  `:3688`) and add the new pins (§3.5, plus the fingerprint-reason encode arm);
  recount the totals from the manifest; run the whole scheme mutation lane and
  confirm each new/changed pin is caught for the reason it names (the wrong-reason
  guard and the exit status, never the "suite complete" line — AGENTS.md).

Exit: the brief's six acceptance criteria hold; `make test` green in both Chez
modes; the scheme mutation lane green with recounted totals; the ABI reads 7; the
size measurement recorded.

## 6. Slice ② — The release and the close

Written against its own re-taken base after Slice ① merges (one plan at a time).
Version surface → `0.4.0`; `CHANGELOG.md` `[Unreleased]` → dated `[0.4.0]` under
`### Added`/`### Changed`; release-ledger `release-version` (`release-ledger.sls`)
and the hardcoded assertions in `release-ledger-tests.sps` updated in lockstep;
`README.org` status; the parent plan's dated disposition and the milestone-status
surfaces; annotated tag `v0.4.0`. The `§26`/`§27` census is unchanged — those are
the v0.1 release criteria the ledger checks, and a pause reason adds no criterion
row. Exit: `(byte-machine test release-ledger)` green against `0.4.0`; the tag
exists; the five surfaces agree.

## Exit (full Milestone 12)

The brief's six acceptance criteria hold; v0.4.0 is tagged; the consumer can bump
its gitlink pin off `v0.3.0` against generated ABI 7, add the `paused-upgrade . 22`
row to its trace adapter's error table, and move its seven pause fixtures from
`not-yet` to `passing`. Decision 0046 records the added identity.

## Explicitly out of Milestone 12

- **A reason on span-data / span-complete callback pauses** (§3.4) — needs a span
  declaration field no consumer wants; deferred with its rationale.
- **A mandatory reason.** The declaration is optional; existing machines pause
  for one obvious reason and do not name it (brief §6, criterion 1).
- **Any change to `status` or the lifecycle rows** (criterion 3).

## Handed to writing-plans

- **Slice ①** — this design §5 and decision 0046's Slice ① consequences, after
  the §4.1 prototype confirms the shape. Base `9c027fd` (or current `main`).
- **Slice ②** — this design §6 and decision 0046's Slice ② consequences. Written
  against its own base after Slice ① merges.

## References

- Upstream brief: `~/github/chez-httparse/.plans/2026-09-14-upstream-pause-reason-brief.md`
- Decision [0046](../.decisions/0046-a-pause-carries-a-reason.md)
- Decision [0022](../.decisions/0022-structured-parser-error-record.md) — the
  `parser-error` record shape the reason value reuses.
- Decision [0042](../.decisions/0042-empty-span-delivers-one-fragment-on-the-feed-side.md)
  — the ABI-tracks-shape principle this milestone's honest bump respects.
- Parent plan `§9`, `§12`, `§13`, `§22.4`, `§29:1767`.

## Close (2026-09-14) — the six criteria dispositioned

Delivered as Gate 0 (decision 0046) plus two slices; the brief's six acceptance
criteria, each against the tree:

| # | Criterion | Met by |
|---|---|---|
| 1 | `make-pause-node` takes an OPTIONAL reason (a pause without one is unchanged) | Slice ① — `make-pause-node`/`make-callback-node` `case-lambda` (`private/ir.sls`); the reason-less arm proved unchanged by every pre-existing pause lane |
| 2 | a paused `parser-result` reports a `(code, reason)` value, `parser-error`-shaped | Slice ① — `parser-result-pause` (new slot, `runtime.sls`); `byte-machine.differential.pause` reads it on both executors |
| 3 | `status` stays `'paused`; `paused-feed`/`paused-finish` lifecycle rows unchanged | Slice ① — the pause-machine interpret lane (reads status/offset/lifecycle only) is unaffected; `parser-result-error` stays `#f` |
| 4 | the reason survives resume-and-re-pause (two nodes → two reasons) | Slice ① — `byte-machine.differential.pause`'s resume+re-pause group over the local `chain` machine (`paused-cont` then a second distinct reason, not the first twice) |
| 5 | interpreted and generated executors agree; ABI bumped as the outcome shape moved | Slice ① — `byte-machine.differential.pause` (both lanes); ABI **6 → 7** read out of the emitted text, all seven determinism goldens re-baselined |
| 6 | a before/after size measurement | §3.6, recorded in the `CHANGELOG.md [0.4.0]` entry: a two-node pause machine emits **1,825 bytes** without a reason and **1,942 bytes** with one declared reason (**+117 bytes**), measured through the emitter |

**Brief §6 honoured.** The reason does not ride the error slot:
`parser-result-error` stays `#f` for a pause, in a NEW `parser-result-pause`
slot, so a slot-only consumer keeps the paused/errored distinction; the reason
is optional (criterion 1); `status` and the lifecycle rows do not move.

**Out of scope, deferred with rationale (unchanged):** a reason on
span-data/span-complete callback pauses (needs a span-declaration field no
consumer wants), and a mandatory reason.

**Coordination (§4.6) closed.** Decision 0046 landed as taken; the ABI bump 6→7
was clean (M11 held ABI 6); the `CHANGELOG` head and the release ledger were
reconciled at each slice. The `§26`/`§27` release census is **unchanged** —
13 met / 2 amended / 0 open, the two amended still the CI-blocked Tier-1 pair; a
pause reason adds no criterion row. The mutation lane closes at 72 passes / 628
mutations, all caught; `pr` 156/156; the diagnostic census is unchanged.

**Version surfaces at 0.4.0:** README.org status, `CHANGELOG.md [0.4.0]`, the
parent plan's status line and its Milestone 12 foot disposition, the release
ledger's `release-version` (single owner) and its five mirror surfaces, this
design's status header, and the annotated `v0.4.0` tag. The consumer
(`chez-httparse`) picks up ABI 7 downstream (its own PR, re-measured
fingerprints) per the brief's §10.
