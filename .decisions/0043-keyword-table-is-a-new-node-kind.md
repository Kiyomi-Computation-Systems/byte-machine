# 0043: The keyword table is a new node kind, not a relaxation of sequence dispatch

Date: 2026-09-13
Status: accepted
Milestone: 11, Gate 0 (milestone-11-design.md §4.1)

## Context

Decided against `main` at `e9f8d9c`. Numbers renumber and re-measure if the
concurrent Milestone 10 branch (empty-span, v0.2.0, decision 0042) changes the
base before this lands (milestone-11-design.md §4.6).

**What the parent plan constrains.** `§10.6:544` — sequence dispatch "matches one
of a finite set of exact byte sequences without backtracking. Sequences may share
nonterminal prefixes. Ambiguous terminal prefixes are rejected **unless the grammar
expresses the distinction through explicit states**." `§28:1727` forbids
backtracking outright. The downstream `chez-httparse` brief supplies the evidence
`§29:1749` requires to admit this deferred extension: **neither** keyword table an
HTTP parser needs can use `make-sequence-dispatch-node` — the 47-name method table
because `GET` is a proper prefix of `GET-PARAMETER` (the one such pair, measured
across all 47), and header-name matching because it is case-insensitive
(decision 0045).

**Why not relax `sequence-dispatch`.** Decision 0015 item 2 records that the
sequence lowering works *only because* ambiguous terminal prefixes are rejected:
"every prefix state is either interior-with-children or a leaf, so none needs an
'accept here' slot — which the shipped normalized state does not have," and "the
rejection rule and this lowering are the same decision seen twice; changing either
silently breaks the other." A keyword table's defining state is
accept-here-**and**-continue (`GET` is a complete keyword and the interior of
`GET-PARAMETER`). Adding that to `sequence-dispatch` breaks its own lowering. A
distinct kind leaves `sequence-dispatch`, its `pass-sequence-ambiguity`, and its
`interpret.sls` walker exactly as they are.

**Measured (prototype P1, milestone-11-design.md §3.2), against this base.** A hand
trie of byte-dispatch nodes for `GET`/`GET-PARAMETER`/`close`/`closed`, each
keyword's target reached by **reexecuting** the first non-continuing byte, verifies
and runs and reproduces every semantic below: the delimiter is unconsumed (offset
== keyword length on every hit), the proper-prefix pair resolves both ways, and
`GET-X` is a no-match rather than a fallback to `GET`.

## Decision

**1. A new source node kind `keyword-table`, the fourteenth**, with public
constructors:

```
(make-keyword-table-node name entries no-match eof-target case-insensitive? label)
(make-keyword-entry bytes target label)
```

- `entries` — a non-empty list of `make-keyword-entry`, each a non-empty list of
  byte values and a target node name. **Proper prefixes are permitted**; exact
  duplicate keywords are rejected by the verifier.
- `no-match` — an `edge`, normally `reexecute`.
- `eof-target` — a node name or `#f` for the machine default.
- `case-insensitive?` — a per-table boolean ([decision 0045](./0045-keyword-table-case-insensitivity-is-a-per-table-fold.md)).

**2. The semantics.**

1. **Greedy forward, no backtracking** (`§28:1727`). At a complete keyword, if the
   next byte continues toward a longer keyword the walk continues; otherwise it
   takes this keyword. A byte consumed toward a longer keyword is not returned:
   `GET-X` is a no-match, never `GET` plus `-X`.
2. **The delimiter is not consumed.** Taking a keyword reaches its target over a
   **reexecute**; the following byte is unread, so the grammar decides what must
   follow — which is what makes `MKCOLA` fail *after* the method span closes, at
   offset 5 (P2).
3. **`no-match`** is taken when no keyword is reachable from the bytes seen.
4. **EOF mid-table routes to `eof-target`**, as every byte-reading node does. It
   does not silently take a keyword; there is no delimiter to reexecute.
5. **A span opened before the table closes at the matched length**, because the
   match consumes exactly the keyword's bytes (P1: offset == keyword length).

**3. The reference interpreter derives its trie walk independently of the
normalizer** — decision 0015's rule and for its reason (`§18:970`: the
interpreter≡generated differential is the only thing that catches a lowering
defect, and only if the two are independent). `interpret.sls` imports no normalizer
library and this milestone adds no shared trie-walking helper. The interpreter
reuses the existing `(name . path)` compound-`current` representation, but its
terminal/continue split must change: a position may be **both** a valid keyword
**and** a continuation, which the current `seq-step` treats as an
`assertion-violation`.

**4. `keyword-table` is a distinct kind from `sequence-dispatch`, which is
unchanged.** `pass-sequence-ambiguity` keeps rejecting genuinely ambiguous sequence
dispatches (milestone-11-design.md §4.4); the keyword table is simply not subject
to it. The keyword table's own verifier pass is the inverse — it permits proper
prefixes and rejects only exact duplicates and folded collisions (decision 0045).

## Consequences

- **The fourteenth kind is a census-shaped change.** Every hand-written per-kind
  enumeration in `ir.sls`, `verify.sls`, `interpret.sls`, `normal-ir.sls`,
  `compile.sls`, and the test harness's draw table gains an arm, and the
  `13`/`thirteen` count literals become `14` (milestone-11-design.md §3.1, §4.5).
  Teaching the two shared accessors does not teach the hand filters (AGENTS.md);
  each site is decided explicitly, including the ones whose answer is "not this
  kind."
- **The new verifier pass must not clone `node-overlaps`' skeleton** (AGENTS.md,
  *"`SITES` fails in BOTH directions"*): several shipped mutations pin that
  skeleton's `let`/`ss`/`rest`/`out` lines, and a clone would take each `FIND` to
  two occurrences and hard-fail the suite. The new pass gets its own binding names.
- **The lowering is decided separately** —
  [decision 0044](./0044-keyword-table-lowers-to-a-compact-table-and-bumps-the-abi.md)
  fixes that it lowers to a compact table (not one state per prefix) and bumps the
  ABI; this record fixes only *what the source node is and means*.
- **`make-keyword-table-node` validates local shape only** (`§27:1703`): a name is
  a legal symbol, entries is a non-empty list of `keyword-entry`, each with a
  non-empty byte list. Prefix relations, duplicate keywords, folded collisions,
  target existence and reachability are the verifier's, not the constructor's.
