# 0042: An empty span delivers one empty fragment on the feed side

Date: 2026-09-13
Status: accepted
Milestone: 10, Gate 0 (milestone-10-design.md §4)

## Context

Decided against `main` at `e9f8d9c` (v0.1.0 released, `c38e76f`, tag `v0.1.0`).
This is the first milestone after the release, and the first opened from an
upstream brief filed by the `chez-httparse` consumer rather than from the parent
plan — the work is neither a `§25` milestone (M9 was the final one, `§25:1651`)
nor a `§29` deferred extension (`:1751-1765` does not list it).

**What the runtime does today.** One procedure delivers every span fragment,
`byte-machine-span-fragment-step/v1` (`runtime.sls:585-593`), and its
`(or (>= from to) (unbound-callback? f))` guard suppresses any zero-byte
fragment. `from` is the span mark (`parser-span-mark`, slot 14), `to` the
cursor. The procedure is reached from four sites, with **different**
requirements:

| site | what it is | today | wants |
|---|---|---|---|
| `runtime.sls:617` | the feed-boundary flush in `parser-feed!`, on `need-input` only | suppresses | **keep suppressing** — a read boundary landing at a span start must not fire a zero-byte fragment |
| `runtime.sls:861` | the interpreter's feed-loop span-end | suppresses | **deliver** an empty span once |
| `runtime.sls:1172` | the EOF-side span-end in `parser-finish!` | suppresses | **deliver via the public step**; `parser-finish!` re-anchors the mark to 0 so every empty span fires uniformly (see item 4) |
| `compile.sls:423` | the emitted span-end arm (feed loop AND, via `parser-finish-v2!`, EOF) | suppresses | **deliver**, byte-for-byte agreeing with `:861` |

**Why it is wrong.** A span that opens and closes having delivered nothing
notifies its consumer of nothing — the data callback never fires — so a consumer
cannot distinguish "an optional field was present and empty" from "this field
never happened." `chez-httparse` measures its HTTP/1 parser against llhttp's
recorded corpus by **bit-exact trace equality**; llhttp announces empty spans
(`off=9 len=0 span[protocol]=""` for `GET /foo bar/ HTTP/1.1`) and byte-machine
cannot. Seven expectations in that corpus are empty spans — empty header value
(`Line4:`, ×4), a status line with no reason phrase, a malformed target's empty
protocol, and a lenient variant — five inside the consumer's v0.1 scope. Any
byte-oriented grammar with optional fields hits this immediately, which is what
puts the fix here rather than in the consumer (chez-httparse decision 0006).

**Why the naive fix is wrong.** Emptiness is a property of the SPAN, not of the
fragment. A span split across two feeds can have an empty **final fragment**
while being a non-empty **span**: the flush delivers the earlier bytes, the mark
is re-anchored to the next slice's `start` (`runtime.sls:708-709`), and the span
then ends on that slice's first byte with `from == to`. Inverting `>=` to `>` on
the shared step would announce "empty" for that non-empty span. So a span end
must answer *"has anything been delivered for this span at all?"* — state the
runtime does not currently keep.

**What the tree already settles** (measured at `e9f8d9c`; full survey in
milestone-10-design.md §3):

- **The verifier needs no change.** Pass 7's span-state lattice tracks only
  `active`/`none` (decision 0029) — it has no notion of byte extent, so a
  zero-width span already verifies clean, and no reachability or parked-set rule
  moves. The one behavioural change (the data callback now fires once for an
  empty fragment) adds no node kind and no pause site; a span-end's data-callback
  pause is already a modelled parked state (`verify.sls:1566-1572`).
- **The emitted text can stay byte-for-byte identical**, which keeps all six
  determinism goldens, `member3-drift-tests.sps`'s `reserved-member-3` subset and
  twice-asserted count, and the generated ABI unchanged.
- **The behaviour is exercised only in the DIFFERENTIAL lanes**, not in
  `runtime-tests.sps`/`interpret-tests.sps` (which have no span-fragment
  coverage). `differential-span-tests.sps` and `differential-counted-span-tests.sps`
  assert the current suppression **by value** (`'(complete)`); those literals are
  the OLD contract and are deliberately re-baselined by this milestone.

## Decision

**1. A per-span "delivered anything yet" flag.** The parser gains slot 16, a
boolean, inited `#f` by `make-parser` and reset `#f` by `byte-machine-span-close/v1`
(which transitively covers `parser-reset!` and both completion arms, exactly as
slots 12/14/15 already are), and set on every real delivery. `span-open` does
**not** touch it — the init and the close-reset already leave it `#f` at every
span start, so a single reset line is load-bearing and its deletion is caught by
the one fixture that runs two spans on one parser (the property coverage machine's
covx→covy). The feed re-anchor at `runtime.sls:708-709` must **not** clear it — a
span that delivered bytes and then has an empty final fragment stays "delivered." *Rejected, with the failure it would cause*: inverting
`(>= from to)` to `(> from to)` on the shared step — it announces "empty" for a
split span's empty final fragment (the hazard above); it is the exact mutant
`SchemeMutationSuite.cmake`'s "an empty span fragment is delivered instead of
suppressed" pin already exists to catch. And: having consumers infer emptiness
from the absence of a data callback — forbidden by the consumer's decision 0008,
and the class of inference that makes a wrong parser look right.

**2. The public step gains the behaviour and serves EVERY span end; only the
flush gets a private suppress-always entry point.** `byte-machine-span-fragment-step/v1`
keeps its exact seven-argument signature and gains deliver-if-never-delivered:
deliver on `from < to` (real bytes); deliver an empty `[from,to)` when
`from == to` and the flag is clear; otherwise suppress (`from == to` with the flag
set — a split span's empty final fragment; or `from > to` — the incoherent EOF
carried case of item 4). It is reached by ALL THREE span-END sites: the feed-loop
span-end (`runtime.sls:861`), the emitted arm (`compile.sls:423`), and the
EOF-side span-end (`runtime.sls:1172`, routed here rather than to a suppress path
— see item 4). A new internal `span-fragment-suppress-empty` keeps today's
unconditional `from >= to` suppression and serves the FLUSH (`:617`) only, which
is not a span end. *Rejected*: giving the flush the deliver-if-never behaviour —
a mid-span read boundary that accumulated nothing would announce empty for a span
still being built (criterion 3). *Rejected*: the `from >= to` empty-delivery
condition first tried — it delivers `[from,to)` when `from > to` too, which at an
EOF carried span (`to = 0`, `from` a stale slice offset) is a backwards range; the
`from == to` guard is what makes the shared step safe at every site.

**3. No generated-ABI bump; the emitted text does not move.** The emitted arm's
call to `byte-machine-span-fragment-step/v1` is untouched — same name, same
arguments — so nothing binds a new emitted local, `reserved-member-3` does not
grow, and the HTTP determinism golden does not re-baseline. The runtime↔generated
contract's *shape* is unchanged though its *behaviour* is not; generation and the
runtime always ship together (a compiled machine is constructed by the runtime's
own `make-parser`, which owns the parser vector), so no mixed-version object
hazard exists within byte-machine, and adding slot 16 is invisible to generated
code, which reaches the parser only through runtime procedures. `current-abi-version`
stays **5**. *Rejected*: bumping ABI 5→6 — it misuses a number that tracks the
payload *shape* to signal a *behaviour* change; the semver minor bump (item 6) is
the honest signal, and the consumer's own gitlink-pin bump ritual (brief §10)
re-measures its goldens regardless. The consumer's assertion that emitted text
carries ABI 5 stays true and stays green.

**4. The EOF-side span-end delivers through the same public step, and
`parser-finish!` re-anchors the mark to 0 so every empty span is announced
uniformly.** The generated lane has no separate EOF executor: `parser-finish-v2!`
runs the emitted `exec` with `finish?` and cursor `0`, so its EOF span-end *is* the
emitted span-end arm, which calls the public step. Making the EOF side suppress
while the feed side delivers would require a `finish?` branch inside that emitted
arm — moving the HTTP determinism golden and re-anchoring the `compile.sls`
span-end mutation, the very costs item 3 exists to avoid. So the interpreter routes
its EOF span-end to the public step too (matching the generated lane). To make that
correct for a span CARRIED from a feed (whose mark still holds the opening feed's
`start`), `parser-finish!` re-anchors an active span's mark to 0 before the EOF
chain runs — mirroring the per-feed re-anchor to the next slice's `start`, since
the finish path's slice `start` is 0. Every EOF span end then sees `from == to == 0`:
an empty span delivers its one empty fragment, a non-empty carried span (flag set)
suppresses. So `from > to` is not reachable at any span end (feed marks are `<=` the
cursor, EOF marks are 0); the step's `from == to` guard therefore suppresses only
the flag-set final fragment, and its `from > to` arm is kept as defence. *Rejected*:
keeping EOF suppression via a `finish?` branch in the emitted arm — it moves a
committed golden the milestone otherwise leaves byte-identical, for nothing gained.
*Rejected*: leaving the finish path un-re-anchored — the whole-branch review measured
that it announced a carried empty span only when the last feed happened to start at
0, a slicing-dependent inconsistency (the same logical empty span fires or not by
how the caller sliced its input). The result is uniform: **every** empty span,
feed-side or EOF-side, is announced exactly once. *(This is the milestone's third
EOF position: "keep the asymmetry" was dropped once the shared emitted EOF path was
measured, then "deliver only the coherent cases, no finish re-anchor" was dropped
once the review measured its slicing-dependence — each per the brief's own
instruction to verify the suggested shape against the invariants.)*

**5. `§14` items 2 and 5 are amended by a dated disposition, never inlined.**
`§14:831` (item 2, "Ending a span emits `[mark,cursor)` if nonempty") and
`§14:834` (item 5, "Empty span-data fragments are suppressed") are the normative
source of the suppression. They are amended — a span end (feed-side, or on the EOF
chain over a coherent `from == to`) now emits `[mark,cursor)` even when empty,
exactly once, when the span has delivered nothing. `§14:833` (item 4, the feed
boundary flush) is UNCHANGED: an empty flush still delivers nothing, which is why
only the flush keeps the suppress-always entry point (item 2). The amendment is a
dated disposition appended at the parent plan's foot (`§1802`), because an inline
edit would renumber every `§section:line` citation below it (AGENTS.md, the append
rule). `§13:822` and `§14:841` are unchanged: an empty span end still sees its span
active with the mark advanced to the cursor, and a pause after the (now possibly
empty) data fragment still retains only the `completion-pending` continuation.
`§14:835` (item 6, "zero or more data fragments followed by exactly one
completion") stays literally true as written, but the "**zero** fragments with a
completion" case is no longer reachable: under item 4 every span that reaches its
end delivers at least the empty fragment, so a completion is now always preceded by
one or more fragments. Zero fragments occurs only for a span that never reaches its
end — one abandoned at an error terminal, which synthesizes no completion
(`§14:839`).

**6. Ships as v0.2.0 (minor).** This deliberately changes documented, tested
behaviour (`§14:834`) and adds observable output, which is a semver *change*, not
a *fix*. The release is Milestone 10 Slice ②.

## Consequences

- **Handed to Slice ① (the mechanism, one atomic commit).** Slot 16 and its
  accessor; the reset in span-close (only); the shared `span-fragment-deliver!`
  helper; the public step's deliver-if-never body with the `from == to` guard,
  reached by all three span ends (feed-loop, emitted, and the EOF-side span end
  routed to it); the private `span-fragment-suppress-empty` for the flush only.
  TDD in the differential lanes: re-baseline the by-value suppression assertions
  (`differential-span-tests.sps` AZ case AND its EOF-chain `eopen`/`eclose` span,
  `differential-counted-span-tests.sps` `0:,` cases and the `§25:1609`
  two-message case, `http-message-tests.sps` all-OWS empty header value 0→1) to
  the delivering shape, and add by-value fixtures for a split span's empty final
  fragment suppressed (criterion 2), a flush finding nothing (criterion 3), and a
  pause on the empty delivery itself (criterion 5), and a carried empty span
  closing at EOF delivering uniformly for both slice starts (item 4). Reconcile the
  property driver's `span-event` family: an empty span now always delivers a
  zero-length fragment, so `span-suppressed-empty` (a completion with no fragment)
  loses its witness and is reframed to `empty-fragment` (derived from a delivered
  fragment of length 0, which the coverage machine's `covy` produces) — its
  counter, `family-members`, and the declared-literal totality row move together,
  recounted not predicted. Re-author the `SchemeMutationSuite.cmake` suppression
  pin (its `FIND` survives in the flush helper, but its witness moves and the
  behaviour it names is now split across the `from == to` guard and the flush) and
  add mutations for the `from == to` empty-delivery guard (witness: the AZ empty
  span), the flag set-on-deliver (witness: the split span's empty final fragment),
  the flag reset in span-close (witness: the property coverage machine's two
  spans), and the `parser-finish!` mark re-anchor to 0 (witness: the nonzero-start
  carried-empty-at-EOF case); recount `EXPECTED_MUTATIONS`, never predict it (this
  slice: 602 → 606). Append the
  `§14` disposition the moment the behaviour lands. The emitted text stays
  byte-identical — a determinism-golden move is a slice failure, not a re-baseline.

- **Handed to Slice ② (the release and the close).** The version surface moves to
  `0.2.0` across the five surfaces the release ledger names; `CHANGELOG.md`'s
  `[Unreleased]` becomes a dated `[0.2.0]` section under `### Changed`/`### Added`;
  the release ledger's `release-version` and its hardcoded version assertions are
  updated in place (the `§26`/`§27` criteria are the v0.1 criteria the ledger
  checks and are unchanged — an added behaviour is not a new `§26` row); the tag,
  and the five milestone-status surfaces (AGENTS.md `:593-611`) all say M10 closed.

- **A mutation pin re-authored, not loosened**, and new behaviour gets new
  mutations its own SPEC lane's program (`differential-span-tests.sps`) witnesses.

- **The consumer picks it up** by bumping its gitlink pin off `v0.1.0`, targeting
  the same generated ABI 5, and re-measuring its affected goldens (brief §10).
