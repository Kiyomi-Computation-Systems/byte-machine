# Milestone 11 Design — The keyword table

**Status: CLOSED 2026-09-13, v0.3.0 released.** Delivered as Gate 0 (decisions
0043-0045, PR #121) plus three slices — Slice ① (PR #125 = `59c40c9`), Slice ②
(PR #126 = `4e1519868`), Slice ③ (this v0.3.0 close). All seven brief acceptance
criteria are met (see "Close" at the foot); the diagnostic census closes at 32/58,
the mutation lane at 69/622, and the generated ABI at 6. This milestone **shipped
new `src/` mechanism** — the first since Milestone 6 — and **bumped the generated
ABI** 5→6, the first bump since Milestone 5. (Written originally against `main` at
`e9f8d9c`; the base moved as Milestone 10 and the slices landed.)

> **Concurrent branch (coordination, not dependency).** A parallel session owns
> **Milestone 10 / v0.2.0** — the empty-span-delivery brief
> (`chez-httparse/.plans/2026-09-13-upstream-empty-span-brief.md`), decision
> **0042**, `milestone-10-design.md`. The two briefs are independent in code
> (empty-span §11): M10 touches the runtime's span **delivery** and **keeps the
> generated ABI at 5** (its decision 0042 item 3); this milestone touches the IR,
> verifier, lowering, emitter and runtime, and **bumps the ABI to 6**. M10 ships
> first (0.2.0); this ships after it (0.3.0). **This branch rebases onto `main`
> once M10's squash lands** — `git rebase --onto main e9f8d9c` if that merge is a
> squash, never a plain `git rebase main` (AGENTS.md, *"Rebase --onto after a
> parent squash-merge"*). §4.6 carries the full coordination list.

Measured at `e9f8d9c` by the two Explore surface maps (this session) and **three
throwaway prototypes** (§3.2), none of which touches the repository:

- full `release` and mutation lane at their shipped totals — **65 passes /
  602 mutations** (`SchemeMutationSuite.cmake:1382-1383`); `current-abi-version`
  **5** (`runtime.sls:85`), the emitted literal `5` at `compile.sls:707`;
- the IR closed set is **13** node kinds; the sole literal-datum copy of it is
  `machine-gen.sls:125-128`'s `node-kind-draw-table`, cross-checked against
  `ir.sls`'s `node?` by `property-differential-tests.sps:353-354`;
- six determinism goldens under `test/fixtures/`; the diagnostic census is
  **30 codes over 56 sites** (`.reference/verifier-diagnostic-catalog.md`).

---

## 1. Summary

Milestone 11 admits one deferred extension: a **keyword table** — a single source
node that matches a set of keywords in which one may be a proper prefix of another
(`GET` ⊂ `GET-PARAMETER`), with optional per-table case-insensitivity, and that
**lowers to a compact table rather than to one dispatch state per prefix**.

The extension is deferred by the parent plan — §29 lists both "transition tables
or class tables" and "sequence/trie specialization and peephole optimization" —
and admissible only "with evidence from the separate HTTP project or benchmarks"
(§29:1749) once it carries "interpreter semantics, verification rules, generated
parity, documentation, and tests" (§29:1767). The downstream `chez-httparse` brief
is that evidence: **neither** of the two keyword tables an HTTP parser needs can
use the shipped `make-sequence-dispatch-node` — the method table because `GET` is a
proper prefix of `GET-PARAMETER` (the one such pair across all 47 llhttp method
names), and header-name matching because it is case-insensitive — and the
workaround costs **242 generated nodes / ~105 KB** for the method table alone
(§3.2, measured).

The milestone's centre of gravity is the claim that this new kind can be added as
the **fourteenth** node kind without disturbing the thirteen, that the interpreter
and the generated executor agree on it for every input, and that its lowering
turns 242 states into a table a compiler and a human can both read — the last of
which is the change's whole justification and is a *measured* exit criterion, not
an argued one (§4.2, exit criterion 7).

## 2. Why this shape

**It is a deferred extension, and the admission gate is satisfied.** Handoff rule
8 (§31:1794) — "avoid deferred features unless their admission criteria have been
satisfied" — points at §29:1767's list. This milestone supplies every item:
interpreter semantics (§4.1, decision 0043), verification rules (§4.1, §4.4),
generated parity (the differential lanes, §5–§7), documentation
(`source-ir-and-builder.md`, the catalog), and tests; and the *evidence* §29:1749
demands is the downstream brief's two measured consumers. Nothing here is
anticipated generality — it is "earned by the real HTTP parser and measured
performance" (§31:1798), which is exactly the bar §29 and §28's
"generated code becomes too large" mitigation ("admit compact tables **only with
representative evidence**", §28:1713) set.

**A new node kind, not a relaxation of `sequence-dispatch`** (§4.1). Decision 0015
ties the sequence lowering to the prefix-rejection this feature must drop: item 2
records that ambiguous terminal prefixes are rejected *precisely so that* "every
prefix state is either interior-with-children or a leaf, so none needs an 'accept
here' slot — which the shipped normalized state does not have," and that "the
rejection rule and this lowering are the same decision seen twice; changing either
silently breaks the other." A keyword table's defining behaviour is an
*accept-here-and-also-continue* state (`GET` is a complete keyword **and** the
interior of `GET-PARAMETER`). Relaxing `sequence-dispatch` to permit that would
break its own lowering; a distinct kind leaves `sequence-dispatch` and its
verifier pass exactly as they are (§4.4).

**A compact, table-driven lowering, not one state per prefix** (§4.2). The brief
is explicit and repeated (§6, §9): lowering to one state per prefix "has moved the
problem rather than solved it." The shipped `sequence-dispatch` lowers to a trie of
ordinary `dispatch` states (decision 0015; `normal-ir.sls`'s `seq-state`), which is
exactly the 242-state shape measured in §3.2. So the keyword table needs a **new
normalized state kind** carrying the trie as data and a **new runtime op** that
walks it — and a new runtime binding the generated code depends on is an ABI
contract change (§9.5:444), so `current-abi-version` goes **5→6**.

**Semver puts it at v0.3.0.** A new node kind is new public API. The v0.1 API is
frozen (`README.org`); the parent plan's milestones end at M9/v0.1. M10 owns the
next minor (0.2.0, empty-span). This is the minor after that: **0.3.0**. It is not
a v0.1 patch — a patch adds no API — and the owner has set it as Milestone 11.

## 3. What the parent plan settles, and what this milestone resolves

`§10.6` fixes the **closed set** of node kinds (thirteen; §10.6:534-622) and
already anticipates the shape this milestone builds: sequence dispatch "matches one
of a finite set of exact byte sequences without backtracking … Ambiguous terminal
prefixes are rejected **unless the grammar expresses the distinction through
explicit states**" (§10.6:544). A keyword table *is* that explicit expression, made
a first-class node so the grammar author writes one node instead of a hand trie.
`§17:957` and `§19.2:1010` fix that *sequence* alternatives lower to resumable
prefix states; they say nothing about a table lowering, which §4.2 resolves.
`§28:1727` ("Sequence matching accidentally introduces backtracking") is a
standing constraint this kind must honour — its match is greedy-forward with no
rewind (§4.1, measured in §3.2: `GET-X` is a no-match, never a fallback to `GET`).

What the parent plan does **not** settle, and §4 resolves: the new kind's
constructor shape and semantics (§4.1); how it lowers and whether the ABI moves
(§4.2); whether case-insensitivity is a property of the table, each case, or a
separate construct (§4.3); whether `ambiguous-sequence-prefix` survives (§4.4).

### 3.1 The surface a fourteenth node kind touches, mapped

Two Explore maps (this session) enumerated every site. The kind is **visible** in
the source IR, verifier and interpreter, and — unlike `sequence-dispatch` — stays
visible through normalization into a **new normalized state kind** with its own
emitter arm and runtime op. Adding the fourteenth kind is a **census-shaped**
change (AGENTS.md, *"A per-kind census … is still a per-kind census"*): it reddens
every hand-written per-kind enumeration and every `13`/`thirteen` count literal
until updated. The load-bearing sites:

- **`ir.sls`** — new record (`keyword-table-node`, companion `keyword-entry`); the
  three closed-set forms `node?` (`:767`), `node-name` (`:774`),
  `node-source-label` (`:794`).
- **`graph.sls`** — export the constructor family (predicate + accessors, as
  `sequence-dispatch` does, `:125-129`).
- **`verify.sls`** — `node-out-edges`/`-out-targets`/`node-eof-target` arms; a new
  prefix-**tolerant** duplicate/collision pass and its driver registration; the
  `pass-zero-progress` walk **and** its report-set (in lockstep); the
  `eof-terminal` walk arm; `node-case-labels`; the new diagnostic code(s).
- **`interpret.sls`** — `kind`/executor/`eof-target-of` arms; an independent trie
  walker (decision 0015's independence rule; §4.1).
- **`normal-ir.sls`** — a new normalized state kind, its compact table encoding,
  the `internal-blocks`/`declared` arms, the fingerprint coverage.
- **`compile.sls`** — a new emitter arm; the ABI literal `5→6` (`:707`); the
  default-eof "reached" set (`:551`) and the state-arm `else` set (`:494`).
- **`runtime.sls`** — the resumable walk op (new export); `current-abi-version`
  `5→6` (`:85`).
- **Tests/tooling** — `machine-gen.sls` draw table + `build!` arm + export;
  `property-driver.sls` counter/case; `property-differential-tests.sps` totality
  (`13→14`) and its count literal; new `unit`/`differential` lane pairs + a fixture
  machine in the lane `SOURCES` (+ reconfigure); a **7th** determinism golden +
  lane + env var; `SchemeMutationSuite.cmake` pins + `EXPECTED_PASSES/MUTATIONS`;
  `verifier-diagnostic-catalog.md` + `diagnostic-census-tests.sps` (+ its `14`
  literals); the kind × position matrix and `compile-tests.sps` render totality;
  `source-ir-and-builder.md`; `CHANGELOG.md`; the release ledger stays green by
  documenting the kind (`§26:1671`).

### 3.2 Three prototypes, run against this exact tree

All three are throwaways in the session scratchpad; none touches the repository.

| # | What it built | What it measured |
|---|---|---|
| **P1** | a hand trie of byte-dispatch nodes for `GET`, `GET-PARAMETER`, `close`, `closed`, each keyword's target an error node reached by **reexecuting** the non-continuing byte | **verifies, compiles, runs**; every brief semantic reproduced: `GET `→GET(3), `GET-PARAMETER `→long(13), `GETX`→GET(3, `X` unread), `close `/`closed ` **distinguished** (5/6, the pair `sequence-dispatch` refuses), `GET-X`→no-match(4, no backtrack); **offset == keyword length** on every hit — the span-close position (§5.5). **22 nodes / 9 287 emitted bytes** |
| **P2** | the full **47-method** table as an auto-built trie of byte-dispatch nodes, one node per distinct prefix | **242 trie nodes / 105 054 emitted bytes** — reproduces the brief §3's 242 exactly; `MKCOLA `→`MKCOL` consumed 5 (brief §2 verbatim: span `MKCOL`, fail at offset 5). **This is the "before" for exit criterion 7** |
| **—** | the **"after"** (compact table) is *not* prototyped — the feature does not exist yet | its size is estimated by construction (the 47 keyword strings + targets as one embedded datum + one state arm — kilobytes, not ~105 KB) and **measured through a registered lane in Slice ③**, never predicted into a literal |

**What the prototypes do not prove.** Nothing about the compact lowering's emitted
size (the feature does not exist), nothing about resumability across feeds, nothing
about case-insensitivity. Each of those is a slice measurement.

---

## 4. Gate 0 — design-call resolutions

A resolution earns a **decision record** when it is externally observable or a
later slice is measured against it; otherwise it lives here and is cited from the
code (Milestone 5/7/8's rule).

### 4.1 The keyword table is a new node kind — *record 0043*

**Record.** The public constructors:

```
(make-keyword-table-node name entries no-match eof-target case-insensitive? label)
(make-keyword-entry bytes target label)
```

- `entries` — a non-empty list of `make-keyword-entry`, each a non-empty byte list
  and a target node name. **Proper prefixes are permitted** (`GET` ⊂
  `GET-PARAMETER`); exact-duplicate keywords are rejected by the verifier (§4.4).
- `no-match` — an `edge` (normally `reexecute`, so the no-match route sees the
  first byte that ruled every keyword out).
- `eof-target` — a node name or `#f` for the machine default, exactly as every
  other input-reading node (§10.6, brief §5.6).
- `case-insensitive?` — a boolean **per table** (§4.3).

**The semantics**, each measured in P1:

1. **Greedy forward, no backtracking.** At a complete keyword, if the next byte
   continues toward a longer keyword the walk continues; otherwise it takes this
   keyword. Once it consumes a byte committing to a longer keyword, it does not
   return to the shorter one — `GET-X` is a no-match, not `GET`+`-X` (P1). This is
   §28:1727 honoured.
2. **The delimiter is not consumed.** Taking a keyword reaches its target over a
   **reexecute**, so the following byte is still unread and the grammar decides
   what must follow. This is what makes `MKCOLA` fail *after* the span closes, at
   offset 5 (P2, brief §2).
3. **A `no-match` route** when no keyword is reachable from the bytes seen.
4. **EOF mid-table routes to `eof-target`**, like every byte-reading node — it does
   **not** silently take a keyword (there is no delimiter to reexecute).
5. **Spans compose.** A span opened before the table closes at the matched length,
   because the match consumes exactly the keyword's bytes and reexecutes the
   delimiter (P1: offset == keyword length on every hit).

**The reference interpreter derives its trie walk independently** of the
normalizer — decision 0015's rule, and for its reason: the interpreter≡generated
differential is the only mechanism that catches a lowering defect (§18:970), and it
can do so only if the two are genuinely independent. `interpret.sls` imports no
normalizer library; this milestone introduces no shared trie-walking helper for the
purpose. The interpreter reuses the `(name . path)` compound-`current`
representation `sequence-dispatch` already uses (`interpret.sls:34-37`), but its
terminal/continue split changes: a position may be **both** a valid keyword **and**
a continuation, which `seq-step` today treats as an `assertion-violation`.

**Why a record.** It is the milestone's central semantic choice; every slice is
built on it; and a later reader who sees an accept-and-continue state needs the
reason `sequence-dispatch` could not host it.

### 4.2 It lowers to a compact table, and the generated ABI goes 5→6 — *record 0044*

**Record.** The keyword table lowers to a **new normalized state kind**
(`keyword-table`) carrying the trie as an embedded deterministic datum — a vector
of trie nodes, each an ascending `(byte . child)` transition list plus an optional
terminal target-id and the table's case-insensitivity flag — **not** to one
`dispatch` state per prefix. The generated executor emits that datum inline and
calls a **new runtime op** that walks it; the op is **resumable**, storing "mid-
table at trie node *k*" in the parser's opaque `current` on `need-input` and
resuming on the next feed (decision 0015's cross-feed resumability, relocated from
dispatch states into the op). Because the generated code now depends on a runtime
binding that did not exist, **`current-abi-version` goes 5→6** (`runtime.sls:85`)
and the emitted literal moves with it (`compile.sls:707`) — §9.5:444 requires
exactly a version bump + deterministic regeneration + a changelog entry.

**The blast radius, and it is the ABI's, not the encoding's.** The ABI literal is
on every generated library's constructor call, so **all six determinism goldens
re-baseline** (the literal `5`→`6` on the last line — decision 0025's `3`→`4`
precedent) and the ~21 ABI/fingerprint pin sites move with them. This is the
deliberate re-baseline the brief §6 names ("Determinism goldens re-baseline if
emitted text changes; that is expected here"). The **encoding** (fingerprint)
gains coverage of the trie datum only for keyword-table states, so a machine that
declares no keyword table encodes byte-identically and its **fingerprint does not
move** — only the ABI literal does (decision 0025's two-sided oracle: forward, the
goldens move; backward, the fingerprints do not).

**`current-abi-members` is unchanged (3).** The trie lives in the emitted state
datum, not the compiled-machine metadata payload, so no ABI payload member is
added (contrast decision 0025, which grew the payload). The bump is a version bump
only.

**Why a record.** It is externally observable (the ABI, the emitted size), exit
criterion 7 is measured against it, and the six-golden re-baseline is a
deliberate, explained cost a later reader must see the reason for.

### 4.3 Case-insensitivity is a per-table fold — *record 0045*

**Record.** `case-insensitive?` is a property of the **table**, not of each entry
and not a separate construct. When true, an ASCII letter in a keyword matches
either case (`A`↔`a`); a byte with no case matches only itself. The HTTP method
table is case-**sensitive** (RFC 9110 §9.1) and header names are not (RFC 9110
§5.1), so the choice is genuinely per table and neither global nor per case
(brief §5.4). The verifier rejects a table whose keywords **collide under folding**
(two entries equal after case-folding, e.g. `GET` and `get` in one CI table) with a
new diagnostic — the folded-collision analogue of the exact-duplicate rejection
(§4.4). Folding is ASCII-only (`§10.4:480`'s portable-ASCII world); a keyword byte
outside `0..255` cannot arise (bytes are the universe).

**Rejected: a case-insensitivity flag on `make-sequence-case`** (brief §4). It
would close header matching and leave the method table impossible, because it
inherits `sequence-dispatch`'s prefix rejection — less capable than the hand trie
a consumer can already build.

**Why a record.** It is an observable API property, the collision rejection is a
new diagnostic the catalog and census must carry, and Slice ② is measured against
it.

### 4.4 `ambiguous-sequence-prefix` survives, and `sequence-dispatch` is untouched

**Design-internal; no record.** The brief (§8) asks whether
`ambiguous-sequence-prefix` survives once a construct exists that handles the shape
it rejects. It survives. `sequence-dispatch` still cannot disambiguate `GET` from
`GET-PARAMETER` — that is correct *for a node with no notion of what follows*
(brief §4) — and `pass-sequence-ambiguity` still catches it. The keyword table is
simply **not subject to that pass**; the pass keeps filtering `sequence-dispatch-node?`
only. Retiring the sequence node or its pass is a separate deprecation this
milestone does not take (§29 does not defer `sequence-dispatch` away). The keyword
table's own verifier pass is the **inverse**: it permits proper prefixes and
rejects only exact duplicates (§4.1) and folded collisions (§4.3).

**A trap this milestone must not spring** (AGENTS.md, *"`SITES` fails in BOTH
directions"*): the new pass must **not** be drafted as a structural clone of
`pass-sequence-ambiguity`/`node-overlaps`, whose `let`/`ss`/`rest`/`out` skeleton
several shipped mutations pin by single line — a clone would take those `FIND`s
from one occurrence to two and hard-fail the suite. The new pass gets its own
binding names.

### 4.5 The census seam is the milestone's real width

**Design-internal.** §3.1 lists the sites. The discipline is AGENTS.md's: teaching
the two shared accessors (`node-out-targets`, `node-eof-target`) does **not** teach
the hand-written per-kind filters, and a kind missing from one of those is silent
(the filter yields `'()` and the pass has nothing to say). Every per-kind
enumeration in §3.1 is visited, and the answer for the keyword table is decided at
each — including the sites where the answer is "not this kind." The property
suite's totality row (`13→14`) and the census count literals are the mechanical
backstop that a site was missed.

### 4.6 Coordination with Milestone 10, itemised

M10 (empty-span, v0.2.0) is in flight in a parallel session. The obligations this
creates, none a code dependency:

1. **Decision numbers.** M10 holds **0042** (uncommitted on its branch). This
   milestone takes **0043 / 0044 / 0045**. If M10's count changes before it merges,
   these renumber — they are checked, not assumed, at rebase.
2. **The ABI.** M10 keeps `current-abi-version` at **5** (its 0042 item 3), so this
   milestone's **5→6** bump is clean in either merge order. If `main`'s ABI has
   moved past 5 when this lands, bump to the next integer above it (a checked step,
   not a hardcoded 6).
3. **Rebase, not merge-from-main.** M10 ships first. This branch rebases
   `--onto main <this base>` after M10's squash, and **re-measures** every count,
   fingerprint and golden at the new base before writing any into a literal
   (AGENTS.md, *"Re-measure … before a number enters a doc or record"*).
4. **`CHANGELOG.md` and the release ledger.** M10 turns `[Unreleased]` into
   `[0.2.0]`. This milestone adds its own `[Unreleased]`→`[0.3.0]` entry **on top
   of** M10's section, and touches the release ledger only to keep `§26:1671`
   green (the new kind is documented). No shared line beyond the changelog head.

---

## 5. Slice ① — the keyword table, case-sensitive, end to end

**Scope, as an allocation.** The irreducible vertical: a node kind is not
executable, and therefore not testable, until it exists in the IR, the verifier,
**both** executors and the ABI at once — so this slice adds all of that, plus every
census surface the fourteenth kind reddens (§3.1, §4.5). It is large because
"add the fourteenth node kind" is one census-shaped change, and a plan that split
it would schedule a red intermediate commit (AGENTS.md).

**The work.**

- **IR** — `keyword-table-node` + `keyword-entry` records (local-shape checks
  only); the three closed-set forms.
- **Builder** — export the constructor family through `graph.sls`.
- **Verifier** — reachability arms; the prefix-tolerant duplicate-rejection pass
  (its own binding names, §4.4) + driver registration; zero-progress walk +
  report-set; `eof-terminal`; `node-case-labels`; the `duplicate-keyword`
  diagnostic.
- **Interpreter** — the independent trie walker (accept-and-continue), the
  `kind`/executor/`eof-target-of` arms.
- **Normalizer** — the `keyword-table` normalized state kind and its compact,
  deterministic trie encoding; the fingerprint coverage; a machine with no keyword
  table encodes byte-identically (asserted, decision 0044).
- **Emitter** — the new state arm (emit the trie datum + the resumable op call,
  handling fresh-entry vs resume); the ABI literal `5→6`; the reached-set and
  else-set updates.
- **Runtime** — the resumable walk op (new export); `current-abi-version` `5→6`.
- **The re-baseline** — all six goldens to ABI 6 (literal only; fingerprints
  asserted unmoved), the ~21 ABI/fingerprint pin sites, in **one** commit.
- **Lanes** — `byte-machine.unit.keyword-table` (absolute) and
  `byte-machine.differential.keyword-table` (interpreter≡generated), each
  `.chez.{source,aot}`; a fixture machine `keyword-table-machine.sls` in the lane
  `SOURCES` (+ reconfigure); a **7th** determinism golden + lane + env var.
- **Property suite** — the draw-table entry + `build!` arm + `property-driver`
  counter/case; the totality row (`13→14`) and its count literal.
- **Mutation pins** — one per decision the slice's nodes encode (each entry's
  target routing, the terminal-vs-continue split, the delimiter reexecute, the
  no-match route, the eof route, the ABI literal), failure signatures asserted,
  never a bare nonzero exit; `EXPECTED_PASSES/MUTATIONS` recounted from the
  rewritten manifest, never predicted.
- **Docs** — the `source-ir-and-builder.md` node entry; `CHANGELOG.md`
  `[Unreleased]`.

**Oracle.** *Semantics:* P1's table, driven through both lanes — the prefix pair,
`close`/`closed`, `GETX`, `GET-X`, offset == keyword length. *ABI:* a version-5
generated library refused by a version-6 runtime, and vice versa. *No fingerprint
moved:* a no-keyword-table machine's fingerprint is byte-identical to `main`'s.

### What Slice ① explicitly defers to later slices

Case-insensitivity (Slice ②) and the span-composition lane and the 47-keyword
before/after size measurement (Slice ③). Slice ① proves the mechanism on a
case-sensitive table; it does not yet claim the size win.

## 6. Slice ② — per-table case-insensitivity

**Scope.** Decision 0045 through every layer: the `case-insensitive?` field in IR,
its ASCII fold in the interpreter's walker and the runtime op, its presence in the
normalized encoding (so two tables differing only in the flag differ in
fingerprint), and the folded-collision rejection + diagnostic in the verifier.
Depends on ①.

**The work.** The fold in both executors (independent, decision 0015); the
`case-insensitive-keyword-collision` diagnostic + catalog + census pins; a CI
differential lane over the header-name shape the brief §2b names —
`Content-Length` / `content-length` / `cOnTeNt-LeNgTh` to one target, and a
case-sensitive table refusing the mixed case; mutation pins for the fold and the
collision rejection.

**Oracle.** *Recognition:* a table of names — canonical, lowercase, mixed case, a
prefix, an extension, a near miss — each asserted to hit or miss in a CI table and
a CS table, in both lanes. *Rejection:* two fold-colliding entries refused by name.

## 7. Slice ③ — span composition, the size measurement, and the close

**Scope.** Exit criteria 5 and 7 and the milestone close. Depends on ②.

**The work.**

- **The span lane** (criterion 5): a span opened before a keyword table, closing at
  the matched keyword's length — `MKCOL` from six bytes of `MKCOLA` — asserted as
  span data in both lanes, the P1 offset property made a registered test.
- **The size measurement** (criterion 7, the change's whole justification):
  the 47-keyword table built once as a keyword-table node and once as the
  equivalent trie of byte-dispatch nodes (P2's shape, ~105 KB), **both emitted
  through a registered lane**, the before/after byte counts and node counts
  recorded in the slice report and in the comment beside the assertion — measured,
  not the prototype's number copied.
- **The close-out:** brief §7's seven criteria dispositioned against the tree; the
  §29 deferred-extension admission recorded as discharged; all status surfaces
  (the parent plan, `CHANGELOG.md`'s `[0.3.0]`, this design, `README.org`, the
  release ledger) brought current; the coordination items of §4.6 closed.

**Oracle.** *Span:* the matched-length span data, both lanes. *Size:* after ≪
before, the ratio recorded. *Close:* every criterion has a dated disposition
naming the file and case that meets it.

---

## Exit — brief §7's seven acceptance criteria, allocated

| # | Criterion | Slice | What meets it |
|---|---|---|---|
| 1 | `GET`+`GET-PARAMETER` verify and compile | ① | the fixture machine + `unit.keyword-table` |
| 2 | `GET-PARAMETER `→long, `GET `→short, `GETX`→`GET`+`X` unread | ① | the differential lane, both executors |
| 3 | `close`/`closed` distinguished | ① | the same lane (the pair `sequence-dispatch` refuses) |
| 4 | a CI table matches `Content-Length`/`content-length`/`cOnTeNt-LeNgTh`; a CS one does not | ② | the CI differential lane |
| 5 | a span closes at the matched keyword's length | ③ | the span lane (`MKCOL` from `MKCOLA`) |
| 6 | interpreter ≡ generated on all of the above, under the property suite too | ①-③ | `differential.keyword-table` + the property draw table |
| 7 | 47-keyword emitted size ≪ today's 242-node equivalent | ③ | the before/after measurement, both emitted through a lane |

## Explicitly out of Milestone 11

- **Retiring `sequence-dispatch` or `ambiguous-sequence-prefix`** (§4.4) — a
  separate deprecation §29 does not schedule.
- **Any lowering that is one state per prefix** (brief §9) — that is the workaround,
  in the compiler.
- **A production HTTP method table in this repo** — the consumer builds it
  downstream (brief §10); this milestone ships the mechanism and a fixture.
- **Quoted values, escapes, or any grammar beyond a byte-keyword set** — out of the
  primitive's scope.
- **Changing the empty-span behaviour** — that is Milestone 10's (§4.6).

## Handed to writing-plans

- **Rebase onto `main` after M10's squash and re-measure everything** (§4.6) before
  a single count, fingerprint or golden enters a literal.
- **Gate 0 writes three records** — 0043 (§4.1), 0044 (§4.2), 0045 (§4.3). §4.4 and
  §4.5 stay here and are cited from the code.
- **The new verifier pass gets its own binding names** (§4.4) — never a clone of
  `node-overlaps`.
- **Each slice is one source commit plus one documentation commit, one PR**, pins
  and `EXPECTED_MUTATIONS` arithmetic in the source commit (Milestone 6 §9).
- **The compact-lowering size is measured through a lane in Slice ③**, never the
  prototype's number copied (AGENTS.md, *"a number from a throwaway driver
  describes the driver"*).
- **The ABI bump and the feature land together in Slice ①** — a bare bump would be
  reserved-unused scaffolding no input reaches (decision 0025's execution note).

## References

- Parent plan `.plans/byte-machine-implementation-plan.md`: §9.5:440-444 (the ABI
  contract), §10.6:532-622 (the closed node-kind set; §10.6:544, sequence
  dispatch), §17:949-966 and §19.2:1006-1014 (normalization and lowering choices),
  §28:1711-1729 (the "too large" and "backtracking" risks), §29:1747-1767 (the
  deferred-extension gate), §31:1783-1798 (handoff rules).
- Decisions **0015** (sequence prefix states — the prefix-rejection ↔ lowering
  coupling this feature breaks), **0025** (the M5 ABI 3→4 seam and its two-sided
  golden/fingerprint oracle — the template for §4.2), 0016 (state-id order), 0009
  (the fingerprint).
- The concurrent **Milestone 10** design and decision **0042** (empty-span,
  v0.2.0) — coordination only (§4.6).
- `chez-httparse/.plans/2026-09-13-upstream-keyword-trie-brief.md` — the upstream
  brief and its two measured consumers.
- `AGENTS.md` — testing and mutation discipline; the census, per-kind-filter, and
  re-measurement rules this milestone leans on.

---

## Close (2026-09-13) — the seven criteria dispositioned, the admission discharged

Brief §7's seven acceptance criteria, each against the tree:

| # | Criterion | Met by |
|---|---|---|
| 1 | `GET` + `GET-PARAMETER` verify and compile | Slice ① — `keyword-table-machine.sls` + `byte-machine.unit.keyword-table` |
| 2 | `GET-PARAMETER `→long, `GET `→short, `GETX`→`GET`+`X` unread | Slice ① — `byte-machine.differential.keyword-table` (both executors) |
| 3 | `close`/`closed` distinguished | Slice ① — same lane (the pair `sequence-dispatch` refuses) |
| 4 | a CI table matches `Content-Length`/`content-length`/`cOnTeNt-LeNgTh`; a CS one does not | Slice ② — `byte-machine.differential.keyword-header` |
| 5 | a span closes at the matched keyword's length | Slice ③ — `byte-machine.differential.keyword-span` (`MKCOL` from `MKCOLA`, span data absolute, both lanes) |
| 6 | interpreter ≡ generated on all of the above, under the property suite too | ①-③ — the differential lanes + the property draw table (keyword-table drawn, `case-insensitive? #f`) |
| 7 | 47-keyword emitted size ≪ today's 242-node equivalent | Slice ③ — `byte-machine.unit.keyword-size`: **2,795 bytes as one keyword-table state vs 96,169 bytes as the 242-node byte-dispatch trie, 34× smaller**, both rendered through the emitter (measured through the lane, not the prototype's number copied) |

**The §29 deferred-extension admission is discharged.** §29:1749 admits the
sequence/trie specialization "with evidence from the separate HTTP project or
benchmarks" once it carries "interpreter semantics, verification rules, generated
parity, documentation, and tests" (§29:1767). The `chez-httparse` brief is the
evidence; this milestone supplied every item. Recorded discharged in the parent
plan's dated foot disposition.

**Coordination (§4.6) closed.** Decision numbers 0043-0045 landed as taken; the
ABI bump 5→6 was clean (M10 held ABI 5); the `CHANGELOG` head and the release
ledger were reconciled at each slice; the M10/M11 merge seam was reviewed at
Slice ①. No item remains open.

**Version surfaces at 0.3.0:** README.org status, `CHANGELOG.md [0.3.0]`, the
parent plan's status line and its Milestone 11 foot disposition, the release
ledger's `release-version` (single owner) and its five mirror surfaces, this
design's status header, and the annotated `v0.3.0` tag.
