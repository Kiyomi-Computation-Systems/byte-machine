# Milestone 11 — Slice ① (the keyword-table node kind, end to end) Implementation Plan

Authority: [decision 0043](../.decisions/0043-keyword-table-is-a-new-node-kind.md)
(the node kind and its exact-duplicate rejection),
[decision 0044](../.decisions/0044-keyword-table-lowers-to-a-compact-table-and-bumps-the-abi.md)
(the compact-table lowering and the ABI bump), and
[decision 0045](../.decisions/0045-keyword-table-case-insensitivity-is-a-per-table-fold.md)
(the per-table fold — amended 2026-09-13 to ship the fold in this slice, not
Slice ②), then `milestone-11-design.md` §5 (the slice) and §3–§4 (the
resolutions §5 builds on), then the upstream brief
`chez-httparse/.plans/2026-09-13-upstream-keyword-trie-brief.md` §7 (the
acceptance criteria).

This slice adds **one node kind** — `keyword-table`,
`(make-keyword-table-node name entries no-match eof-target case-insensitive?
source-label)` with `(make-keyword-entry bytes target source-label)` — to the
IR, the builder façade, the verifier, **both** executors, the normalizer, the
emitter, the runtime, and every census surface the fourteenth kind reddens. It
is one census-shaped change, done in one commit, because a plan that split it
would schedule a red intermediate commit (AGENTS.md).

Measured at the branch base (`main` after PR #121, Gate 0): the `pr` subset
**141/141**, the Scheme mutation suite **65 passes / 602 mutations**, the
diagnostic census **30 codes over 56 sites**, thirteen node kinds, generated ABI
version 5, six determinism goldens.

At the end of the slice: `pr` **147/147** (six new lanes), mutation **68 passes /
612 mutations**, diagnostic census **31 over 57**, fourteen node kinds, ABI 6,
seven goldens.

---

## 1. What the keyword-table node is

A dispatch that matches one of a set of keywords, **tolerating proper prefixes**
— the property `sequence-dispatch` refuses (`ambiguous-sequence-prefix`). `GET`
and `GET-PARAMETER` may both be entries; the walk is greedy, forward, and never
backtracks:

- It follows the longest live keyword path, consuming each byte that extends
  toward some entry.
- It accepts a keyword only when the next byte **cannot** extend any live path
  and the walk sits on a keyword terminal — so `GET` followed by a space (or any
  non-`-` byte) takes the short keyword and **reexecutes** the closing byte, and
  the span closes at the keyword's own length (brief §7 criteria 2, 5).
- A byte consumed toward a longer keyword is never returned: `GET-X` commits down
  the `GET-PARAMETER` path and, when `X` fails to extend it, no-matches at offset
  4 rather than rewinding to `GET`.
- At end of input a parked table takes its `eof-target`, never a keyword — no
  byte has closed one (brief §7 "EOF mid-table").
- When `case-insensitive?` is true the match folds ASCII letters (`A`–`Z` ↔
  `a`–`z`) and nothing else, per table (decision 0045); the verifier rejects two
  byte-identical entries (`duplicate-keyword`).

## 2. The compact-table lowering (decision 0044)

The node lowers to **one** normalized `keyword-table` state (encoder tag 15)
carrying its entries, no-match edge, eof route and fold flag as data — **not** a
trie of dispatch states. The runtime op `byte-machine-keyword-step/v1` walks that
table, and a parked walk is resumable across feeds through a compound `current`
of `(state-id . path-bytes)`, emitted only for keyword machines so that a machine
with no keyword table renders byte-identically but for the ABI version literal.
The ABI bumps **5 → 6**: the op is a new runtime export, and a version-5
generated library and a version-6 runtime refuse each other.

## 3. The work, by surface

- **IR** (`private/ir.sls`) — `keyword-entry` (4-slot) and `keyword-table-node`
  (7-slot) records with local-shape checks; arms in `node?`, `node-name`,
  `node-source-label` (the three closed-set forms).
- **Builder** (`graph.sls`) — `make-keyword-table-node` / `make-keyword-entry`
  exported (constructor-only, the byte-dispatch precedent).
- **Verifier** (`verify.sls`) — reachability arms (`node-out-edges` roles
  `keyword`/`no-match`, `node-eof-target`); `pass-keyword-table`, the
  exact-duplicate rejection with its own binding names (§4.4) and driver
  registration; zero-progress walk + report-set arms; `eof-terminal` classify
  arm; `node-case-labels` arm; the `duplicate-keyword` diagnostic.
- **Interpreter** (`interpret.sls`) — the independent trie walker
  (`kw-fold`/`kw-prefix?`/`kw-terminal`/`kw-step`, accept-and-continue, greedy,
  no backtracking, with the fold), and the `kind` / `dispatch` (bare and
  compound) / `eof-target-of` arms. Derived independently of the normalizer
  (decision 0015), so a lowering defect is a differential result.
- **Normalizer** (`private/normal-ir.sls`) — the `keyword-table` normalized state
  reusing the dispatch slots (entries, no-match, fold flag at slot 8), the
  `kw-eof-of` resolver, and the encoder arm (tag 15).
- **Emitter** (`compile.sls`) — the `render-state-arm` for the table (the trie
  datum, the resumable op call handling fresh-entry vs resume, the jump→loop and
  need→need-input/eof branches); the reached-declaration credit list gains
  `keyword-table`; the reserved-member lists gain `byte-machine-keyword-step/v1`
  (member-2) and `kpath` (member-3); the ABI literal `5→6`.
- **Runtime** (`runtime.sls`) — `byte-machine-keyword-step/v1` (its own
  `kw-fold`/`kw-prefix?`), `parser-state-name` v2 unwrapping the compound, and
  `current-abi-version` `5→6`.
- **Re-baseline** — all six goldens to ABI 6 (literal only; fingerprints
  asserted unmoved), the ABI/fingerprint literal sites in `runtime-tests.sps`,
  `compile-tests.sps`.

## 4. The new lanes and the seventh golden

- `byte-machine.unit.keyword-table` — the interpreter absolute oracle
  (`keyword-interpret-tests.sps`): the brief's §7 criteria stated as independent
  expectations, so a walk-logic defect the two executors share is visible here.
- `byte-machine.differential.keyword-table` — interpreter ≡ generated
  (`differential-keyword-table-tests.sps`): every group but the exhaustive byte
  sweep (twenty trie prefixes × 256 bytes × two tables = 10240 drives) also
  asserts the generated side absolutely, so a fold or walk mutation that hit both
  lanes identically cannot pass by agreement. It also pins the cross-feed resume
  and the fingerprint difference (decision 0045 item 5).
- `byte-machine.determinism.keyword-table` — the **seventh** golden
  (`determinism-keyword-table-tests.sps` + `generated-keyword-table.golden.sls` +
  `BYTE_MACHINE_KEYWORD_TABLE_GOLDEN_FILE`). The case-**insensitive** fixture is
  the golden, being the strictly richer render (it carries the fold datum the
  case-sensitive table omits).

Both fixtures live in `keyword-table-machine.sls` and carry the **same** keyword
set (`GET`, `GET-PARAMETER`, `close`, `closed`), differing only in the fold flag
— the one difference decision 0045 item 5 says must move the fingerprint.

## 5. The defect this work found

The interpreter's `eof-target-of` — the parked-set EOF resolver — is a
hand-written per-kind filter, and teaching `kind`/`dispatch` the new kind did not
teach it (the AGENTS.md kind-filter trap,
[[kind-filters-outlive-their-lookups]]). A parked keyword-table at end of input
fell to its raising `else` (`internal`), surfaced by the property differential
and reproduced before the fix. Pass 66's third mutation pins it: neutering the
arm reddens the unit lane's EOF case with `case raised … code: internal`.

## 6. Mutation accounting (65/602 → 68/612)

**Seventeen shipped pins re-anchored** to the keyword-table arms this slice
inserted — twelve FINDs shifted in `ir.sls`, `verify.sls`, `interpret.sls`,
`runtime.sls`, `compile.sls`; two `machine-gen` draw-table got-lists gained
`keyword-table`; two `ir.sls` census-count literals moved `thirteen → fourteen`;
and the property Layer-3 row-6 pin re-homed onto the deterministic fixture check
(the node-kind draw table's growth, required by the totality row, shifted the
generator's PRNG stream so that no *generated* accepted machine reaches a
completing span at this seed — the fixed fixture always does, and it was taught
to name the violated row).

**Three new passes, ten new mutations** (design §5, one per decision the nodes
encode):

- Pass 66 (`unit.keyword-table`, 4): the fold direction, the delimiter reexecute,
  the `eof-target-of` arm, the terminal-vs-proper-prefix test.
- Pass 67 (`differential.keyword-table`, 5): the runtime op's own fold, delimiter
  and terminal test; a matched keyword routed to no-match; the normalizer
  dropping the fold flag (pinned on the fingerprint group it alone reddens).
- Pass 68 (`determinism.keyword-table`, 1): the emitted ABI literal, caught by
  the seventh golden — the only pin on that literal, which had none before.

Every new pin asserts its failure signature, never a bare nonzero exit
([[mutation-caught-for-wrong-reason]]).

## 7. Exit and boundaries

**Oracle met.** The prefix pair, `close`/`closed`, `GETX`, `GET-X`, and
offset == keyword length are driven through both lanes; the interpreter and
generated table agree on 10240 drives; the ABI refusal is asserted; a
no-keyword-table machine's fingerprint is unmoved (the goldens changed by the
version literal only).

**Deferred, by decision 0045's amendment and design §6–§7.** Slice ② owns the
folded-collision diagnostic (`case-insensitive-keyword-collision`) and the brief
§2b HTTP-header case-insensitivity demonstration; Slice ③ owns span composition
and the 47-keyword before/after size measurement. This slice proves the
mechanism and the fold on a small table; it does not yet claim the size win.
