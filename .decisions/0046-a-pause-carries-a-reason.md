# 0046: A pause carries a reason, without becoming an error

Date: 2026-09-14
Status: accepted
Milestone: 12, Gate 0 (milestone-12-design.md §4)

## Context

Decided against `main` at `9c027fd` (v0.3.0 released, tag `v0.3.0`). This is the
third milestone opened from a `chez-httparse` consumer brief rather than the
parent plan (M10 empty-span, M11 keyword-table were the first two). It is neither
a `§25` milestone (M9 was the final one, `§25:1651`) nor a `§29` deferred
extension, so it is admitted under `§29:1767`'s bar as a minor release.

**What the runtime does today.** A machine that reaches a `pause` node yields
`status = 'paused` with the result's error slot `#f`
(`runtime.sls:916-920`), and so does a `callback` node whose callback returns
`callback-pause` (`:962-965`). Both `make-parser-result 'paused … #f` sites in
the feed loop, and their two mirrors in `parser-finish-op!` (`:1243-1246`,
`:1280-1283`), pass `#f` in the error slot; the generated arms
(`compile.sls:285`, `:411`) emit `#f` in the outcome's error slot too, threaded
back into the result by `parser-feed-op!`'s generated path and
`parser-finish-v2!`. A probe machine with one pause node, fed the byte that
reaches it, reports `(status paused error #f stream-offset 1)`.

**Why it is wrong.** A consumer that pauses for more than one reason cannot tell
its caller which, and a consumer that renders parser outcomes as text cannot
render a pause without inventing words. `chez-httparse` reproduces llhttp
bit-exactly; llhttp's pauses carry a code and a message
(`p.pause(ERROR.PAUSED_UPGRADE, 'Pause on CONNECT/Upgrade')`), and its corpus
records `off=127 error code=22 reason="Pause on CONNECT/Upgrade"`. **Seven
request fixtures in the consumer's v0.1 scope end on exactly that line** and it
cannot produce it: its trace adapter renames parser output into llhttp's
vocabulary and never computes (its decisions 0008/0014), so with nothing to
rename it refuses. The distinction that matters: llhttp's HTTP/2 preface "pause"
is `p.error(ERROR.PAUSED_H2_UPGRADE, …)` — an error despite the word, which
renders fine today — and the upgrade pause resumes where the error does not.
That is the whole point of the pause node, so the fix must keep it.

**What the tree already settles** (measured at `9c027fd`; full survey in
milestone-12-design.md §3):

- **The reason DATA already has a home.** `make-error-declaration`
  (`ir.sls:538`) is `(name code reason label)`; an error node names one and
  `pass-names` resolves it (`missing-error-declaration`, `verify.sls:351-354`).
  A pause reason is the same `(code, reason)` data, renamed through the same
  consumer table (brief §7: `paused-upgrade . 22` beside `paused-h2-upgrade . 23`).
- **There is no "every error declaration is referenced" check** — only
  `duplicate-error-declaration` (`verify.sls:336`) — so a declaration referenced
  by a pause node is clean. The reason is a declaration reference, not a node
  target, so it stays out of `node-out-targets` (`:171`), as an error node's does.
- **The verifier's graph rules do not move.** The identity is a leaf datum on a
  node whose reachability, EOF-execution, and span/lattice shape are unchanged.
- **The generated outcome's error slot is the payload channel.** `feed-outcome`
  (`runtime.sls:163`) carries a `parser-error` in slot 3 for an error, `#f`
  otherwise; the emitted pause arms put `#f` there. Filling it for a pause moves
  the emitted CONTRACT — unlike Milestone 10, where the emitted text stayed
  byte-identical and decision 0042 item 3 rightly declined an ABI bump.

## Decision

**1. An optional reason declaration on the two author-facing pause node kinds.**
`make-pause-node` (`ir.sls:357`) and `make-callback-node` (`:703`) each gain an
**optional** trailing reason — a declared error name, or `#f` — via `case-lambda`,
so the existing arities are unchanged and no existing machine changes (brief
criterion 1, "a pause without one keeps today's behaviour exactly"). Each gets a
`-reason` accessor. The constructor checks local shape only (a symbol or `#f`);
whether the name resolves is the verifier's, on the error-node precedent.
*Rejected*: a mandatory reason — existing machines pause for one obvious reason
and should not have to name it (brief §6). *Rejected*: a new `pause-declaration`
family as the default — it duplicates `error-declaration`'s shape and adds a
machine slot and a verifier resolution for data the consumer renames through the
one table it already has; the shape is reused instead (brief §4.1 sanctions
either). Kept as the fallback only if the prototype (item 8) shows a pause
referencing an error declaration muddies a verifier pass.

**2. The reason is a *distinct* result slot; the error slot stays `#f` for a
pause.** `parser-result` (`runtime.sls:180`) gains a seventh slot `pause`,
holding a `parser-error`-shaped value or `#f`, via `case-lambda` so the ~20
non-pause construction sites are unchanged. `parser-result-error` stays `#f` for
a pause. *Rejected, with the failure it would cause*: folding the reason into the
existing error slot — it makes `parser-result-error` non-`#f` for a pause, and a
consumer written before this change that treats "has an error" as "failed" then
mis-reads a resumable pause as a failure (brief §6). The paused/errored
distinction stays obvious to a consumer that checks only the slot: the error slot
is `#f`, the pause slot is not.

**3. The reason value is `parser-error`-shaped.** It is built from the resolved
declaration through the runtime's own `parser-error` constructor
(`byte-machine-make-parser-error/v1`, `runtime.sls:206`): domain `machine`, the
declaration's code and reason, detail `#f`, the pausing node's name, the state
id, the offset, and the position kind — exactly the record an error node
produces. So the consumer's code→name rename table needs no second kind (brief
§4.2). "It is not an error" is enforced at the result (item 2's distinct slot +
the `'paused` status), never by the record's type.

**4. Both author-facing pause paths are covered by one helper; span-callback
pauses are not.** A single `pause-reason-of` reads a pausing node's declared
reason at every pause site. The `pause` node (`runtime.sls:920`, `:1246`) and the
`callback` node (`:965`, `:1283`) can declare one; a consumer that pauses at
either gets its reason, never `#f` for one and a reason for the other (brief §5).
The span-end and span-completion pauses (`:1001`, `:1031`, `:1324`, `:1350`) are
a span callback returning `callback-pause` — an internal fragment-resumption
step that parks on the next undelivered substep, not an author-declared pause
POINT, and the span node kinds carry no reason surface. `pause-reason-of` returns
`#f` for these; they keep today's behaviour. *Rejected*: adding a reason field to
span DECLARATIONS to cover them — an unmotivated widening (no `§25`/`§29` grammar
pauses in a span callback; llhttp's reason-bearing pause is the upgrade pause, a
pause node), and adding the arm would be WRONG scope, not merely inert (AGENTS.md,
the absent-arm rule). The boundary is documented at the sites.

**5. The feed-outcome reuses its error slot; the boundary routes by status; the
reason reaches the emitter through the normalizer and the errs table.**
`feed-outcome` keeps five slots. The emitted pause arms
(`compile.sls:285`, `:411`) construct the reason record into slot 3 (the error
slot) when the site declares one, else `#f` (unchanged); the two span pause arms
(`:447`, `:474`) stay `#f`. At the two generated→result boundaries —
`parser-feed-v2!` (the generated feed path, `runtime.sls:1101-1103`, NOT
`parser-feed-op!`, which is the interpreter loop) and `parser-finish-v2!`
(`:1204-1205`) — slot 3 routes to the result's error slot for an `'error` status
and to the new pause slot for a `'paused` status, `#f` otherwise. One outcome
carries one status, so the routing is unambiguous. This keeps the emitted-text
delta to the four pause arms only, not every outcome site. But the emitter reads
a NORMALIZED state, not the source node, so the reason reaches the arm only
through two additional seams (design §3.7, the decision-0019 rule "a datum the
ABI carries must be in the encoding, not merely read from the source"):
`normal-ir.sls`'s `lower-machine` must resolve the reason into the normalized
pause/callback state AND `encode-normal` must fold it into the fingerprint under a
presence guard (else two machines differing only in reason share a fingerprint
but emit different bytes); and the errs-table reached-walk (`compile.sls:575-606`)
must gain a pause/callback arm (else a pause-only code is filtered out and the arm
raises "no error declaration for code" at emit time). So the reason does NOT reach
the generated lane "exactly as an error node does" — it travels a new normalizer
thread, a new fingerprint arm, and a new reached-walk arm, analogous to but not
sharing the error node's path. *Rejected*: a sixth feed-outcome slot — it changes
the constructor arity and moves the emitted text at EVERY outcome site (all seven
goldens), where reusing the existing slot moves only the reason-bearing pause
arms (the ABI-literal bump moves all seven goldens regardless — §6).

**6. The generated ABI bumps 6 → 7 — an honest shape move, not a behaviour
signal.** The emitted paused-outcome's payload contract moves: slot 3 of a paused
outcome goes from "always `#f`" to "`#f | ParserError`", so a consumer decoding a
v7 generated parser must know a paused outcome may carry a reason.
`current-abi-version` (`runtime.sls:92`) and the emitted literal
(`compile.sls:763`) move 6→7; the ABI lane reads 7 out of the emitted text
(`compile-tests.sps:208`), as `v0.3.0` did for ABI 6 (brief §4 criterion 5).
This does NOT contradict decision 0042 item 3: there the emitted text stayed
byte-identical (a runtime-only delivery flag), so a bump would have misused a
shape number for a behaviour change; here the emitted CONTRACT genuinely moves,
which is exactly what the ABI number tracks.

**7. Ships as v0.4.0 (minor).** Adds observable output and new optional public
API (the two constructors' reason, `parser-result-pause`) with no break — a
semver minor, as M10 (v0.2.0) and M11 (v0.3.0). The release is Milestone 12
Slice ②.

**8. Slice ① prototypes the load-bearing shape first.** Per brief §6 (the slice
owns the design; a primitive designed from a survey is a guess with a version
number) and the M10/M11 precedent, a scratch prototype in an isolated worktree
confirms in BOTH lanes: a declared reason reaches the pause slot with the error
slot `#f` and status `'paused`; a resume then a re-pause at a second node reports
the SECOND reason (brief criterion 4); reusing `error-declaration` trips no
verifier pass (else item 1's fallback); and the ABI reads 7 out of the emitted
text. Only then are the fixtures written.

## Consequences

- **Handed to Slice ① (the mechanism, one atomic commit).** After the item-8
  prototype: the optional reason on `make-pause-node`/`make-callback-node` and
  the two accessors; the verifier resolution arm mirroring `verify.sls:351-354`;
  the `parser-result` pause slot + accessor via `case-lambda`; the
  `pause-reason-of` helper; the four reason-bearing interpreter pause arms and
  the two boundary routings; the four generated pause arms (two reason-bearing,
  two span arms unchanged) and the ABI literal; `current-abi-version` 6→7. TDD in
  the pause lanes: extend `pause-machine.sls` with two declared reasons; extend
  `differential-pause-tests.sps`'s `rfields` to project the pause slot; add the
  resume-and-re-pause-two-reasons case (criterion 4), a callback-pause reason
  case, and by-value assertions that the error slot stays `#f`, the status stays
  `'paused`, and the lifecycle rows are unchanged (criterion 3); update
  `compile-tests.sps:208` to ABI 7; record the before/after size measurement
  (brief criterion 6) MEASURED through the emitter with its reproduce command.
  Re-author the pause mutation FINDs the shape change breaks
  (`SchemeMutationSuite.cmake:3708-3710`, `:3727-3730`, the Pass 35/36
  normalizer/encoder/emitter pins `:476-483`, the ABI-literal pin `:14004-14007`
  → 7/6/6, the error-threading pins near `:3688`) and add the new pins (the
  reason-read at each arm, the error/pause boundary routing, the `pause-reason-of`
  present/absent direction, and the fingerprint reason-encode arm), each witnessed
  in its own SPEC lane's program; recount `EXPECTED_MUTATIONS`/`EXPECTED_PASSES`
  (currently 622/69), never predict them. Regenerate **all seven** determinism
  goldens (each embeds the ABI literal verbatim and is byte-compared, so all move
  to 7; the pause golden also moves its reason-bearing arm), asserting each
  fingerprint is unmoved except the pause golden's.

  The seams the design's §3.7 and §5 add beyond the naive account, all owed by
  Slice ①: `normal-ir.sls`'s `lower-machine` reason threading and `encode-normal`
  guarded fingerprint arm (+ `normal-ir-tests.sps` differ-in-reason and
  unreferenced-reason cases); the errs-table reached-walk pause/callback arm
  (`compile.sls:575-606`); `parser-result-pause` added to `reserved-member-2`
  (`compile.sls:53-73`); the diagnostic-census re-pin (`diagnostic-census-tests.sps`
  counts + site total + layer-3 fixture, and the catalog check if a new
  `missing-pause-declaration` code is chosen); the three direct ABI-6 constructions
  in `runtime-tests.sps` (`:286`, `:289`, `:534`) and the `verify-tests.sps` case;
  `machine-print.sls`'s `print-pause`/`print-callback` reason field (before any
  `machine-corrupt.sls` reason corruption); the `property-driver.sls` rebuild
  (`:688`, `:706-709`); and the mechanism-describing reference docs
  (`.reference/source-ir-and-builder.md`,
  `.reference/generated-code-integration-chez.md` incl. its already-stale "ABI
  currently 5" → 7) with a `§9.3` accessor-list disposition for
  `parser-result-pause`.

- **Handed to Slice ② (the release and the close).** The version surface moves to
  `0.4.0` across the five surfaces the release ledger names; `CHANGELOG.md`'s
  `[Unreleased]` becomes a dated `[0.4.0]` section; the release ledger's
  `release-version` and its hardcoded version assertions
  (`release-ledger-tests.sps`) move in lockstep; the tag, and the five
  milestone-status surfaces (AGENTS.md) all say M12 closed. The `§26`/`§27`
  criteria are the v0.1 criteria the ledger checks and gain no row.

- **A mutation pin per new decision**, witnessed in the pause lanes' programs,
  including the §6 guard turned into a pin (a mutant routing the reason to the
  error slot for a pause must redden).

- **The consumer picks it up** by bumping its gitlink pin off `v0.3.0` against
  generated ABI 7, adding `paused-upgrade . 22` to its trace adapter's error
  table, and moving its seven pause fixtures from `not-yet` to `passing` — its
  `trace-recorder-note-paused!`, which today only refuses, becomes a rename like
  every other row (brief §7).
