# 0032: The diagnostic record carries `§16.4`'s seven fields, and the path has a policy

Date: 2026-09-06
Status: accepted
Milestone: 7, Gate 0 (milestone-7-design.md §4.2)

> **Amendments** — later notes at the foot of this file reach back into the text
> above them. Nothing above a note is rewritten.
>
> - **2026-09-10, Milestone 7 Slice ① (implemented)** — **annotates items 3–4 and
>   the Context**: Slice ① corrected three instructions in place (each marked at
>   its site) and recorded where its measurement differs from the Context's.
>   Nothing above became false. See the foot note.

## Context

Decided against `main` at `50516af` — the Milestone 7 design (PR #83) and its Gate 0
plan (PR #84) merged; `src/` and `test/` byte-identical to `5ac363a`. Every construct
named below was read on 2026-09-06 and is cited by name, with the command that found
it.

**One fact, and everything here descends from it.** `§16.4:935` reads "Diagnostics
contain:" and lists seven bullets (`:937-943`): a stable symbolic code; severity
("`error`; warnings may be added later"); machine name; "node and edge/source label
where applicable"; a concise message; "relevant declaration names"; "a representative
graph path when useful". The shipped record is `(vector diagnostic-tag code node
message #f)` from `make-diagnostic`, with `make-diagnostic/edge` filling the fifth
slot — three of the seven bullets in four slots, because `:940` is two things.
`§16.4:945` fixes how any of it is tested: "Tests compare diagnostic structure and
codes, not implementation-specific rendered text." `§16.4:947` defers warning policy.
`§25:1616` names "structured graph paths in diagnostics" as this milestone's scope,
and every earlier artifact that noticed the gap assigned the widening here:
Milestone 3's design §8 ("Widening the diagnostic record to §16.4's seven fields —
Milestone 7"), Milestone 4's design §4.6 and §9 (the same sentence; its Slices ①b and
② each say the record "is not widened"),
[decision 0020](./0020-field-shape-is-a-constructor-contract.md)'s "Not touched"
bullet ("widening it to §16.4's seven fields is Milestone 7, and the offending field
name rides the existing `node` slot") and
[decision 0022](./0022-structured-parser-error-record.md)'s "It deliberately touches
nothing else" bullet ("that is Milestone 7 (§25:1616)").

**The constructs, measured** (each command run at `50516af`):

- **Fifty-six emission sites, two constructors, four accessors.** `rg -c
  "\(make-diagnostic '" src/byte-machine/verify.sls` prints 55 — the three-argument
  sites — and `rg -c "\(make-diagnostic/edge"` prints 2: its definition and its one
  call, the `§16.2:908` per-edge block. The accessors index slots 1-4 and
  `diagnostic?` tests the tag. `(byte-machine verify)` exports `verify-machine`, the
  three `verification-` accessors, `diagnostic?` and the four accessors.
- **What the tests read**, as `rg -o -F` substring hits over `test/common/*.sps`:
  `diagnostic-code` 76, `diagnostic-node` 41, `diagnostic-edge` 5,
  `diagnostic-message` 0 — 122 reads of the shipped four. **No test compares a whole
  record or reads its length**: `rg -n 'vector-length|vector->list' test/common/*.sps
  | rg -i diag` finds two lines, both the census's source-datum walker in
  `diagnostic-census-tests.sps`, which reads `verify.sls` as a datum and touches no
  diagnostic record; `rg -n "equal\? diag|#\(diagnostic|vector 'diagnostic"
  test/common/*.sps` prints nothing.
- **What the `node` slot holds**, a census of the 56 sites by the expression at each:
  a node's name at 34 (`(node-name n)` 20, `nm` 6, `name` 5, `(machine-entry m)` 2,
  `t` 1 — the last two being targets that may name nothing); a declaration's name at
  19 (callback 8 — `(callback-declaration-name cd)` 7 and `cn` 1; span 6 —
  `(span-declaration-name sd)` 5 and `pn` 1; error 3 — `(car es)`,
  `(error-declaration-name e)`, `(machine-default-eof-error m)`; field 2 — `fname`,
  `(uint-field-name f)`); the machine's at 1 (`invalid-name` on `(machine-name m)`);
  `#f` at 2 (`pass-schema`'s two `invalid-shape` arms). So `:940`'s "node … where
  applicable" is implemented as "the subject's name, whichever table it lives in",
  and `:942`'s declaration names have ridden the `node` slot at nineteen sites since
  the codes were minted.
- **Where a path could come from.** `eof-terminal`'s `walk` takes `(name path)`, and
  `path` is the DFS stack — `(cons name path)` at each step, `(memq name path)` the
  cycle test; `done`, its memo, is bound inside `eof-terminal` and so is local to one
  call; `eof-verdict-join` is `(if (>= (eof-verdict-rank a) (eof-verdict-rank b)) a
  b)`, the left operand on a tie. `reaches-self?` (inside `pass-zero-progress`) and
  `reach-from` keep a frontier or a visited set and no parent. `pass-spans` keeps
  `span-flow`'s edge list and an in-state association list rebuilt each round, and no
  parent map; the edge list exists before the fixpoint starts.
- **The path-bearing sites number twelve**, over eight codes, counted multiline
  (`rg -n -U` over the eight codes, then `rg -c make-diagnostic`; a single-line search
  prints 11, because the `/edge` site's code sits on the line after its constructor):
  `eof-reachable-stop` 1, `eof-zero-progress-cycle` 1, `zero-progress-cycle` 1,
  `non-eof-into-finish` 2, `invalid-span-state` 4, `inconsistent-span-state` 1,
  `span-active-at-pause` 1, `span-active-at-exit` 1.
- **The trap a path's representation must avoid.** `kind-position-census-tests.sps`'s
  `edge-roles-in-source` derives the edge-role vocabulary from every `(cons 'SYM …)`
  form in `verify.sls`, read as a datum. `span-transfer`'s comment records what
  happens to a pair built that way — "`(list 'active s)` and NOT `(cons 'active s)`"
  … "a pair built that way would enter the edge-role vocabulary as a thirteenth
  'role' and take the kind x position matrix's A' row red on its BASELINE. Measured
  -- it did, on the first draft."
- **The census counts constructors by name**: `diagnostic-census-tests.sps`'s
  `diagnostic-constructors` collects every `define` whose name satisfies
  `make-diagnostic-name?`, a prefix test on `make-diagnostic`, so a new constructor
  is an emission-site recogniser without an edit to the census.
- **`verify-machine` runs every pass but `pass-schema` under `(machine? machine)`**,
  and appends their results into one list.
- **The pins that touch a site**: 19 `FIND` blocks and 8 `REPLACE` blocks in
  `SchemeMutationSuite.cmake` contain `make-diagnostic '` — 27 lines (lexed by block,
  then counted by line).

## Decision

**1. The shape.** `(vector tag code node message edge severity machine declarations
path)` — the four shipped slots in place, four appended. Four accessors are added and
exported from `(byte-machine verify)`: `diagnostic-severity`, `diagnostic-machine`,
`diagnostic-declarations`, `diagnostic-path`. `diagnostic?` and the four shipped
accessors are unchanged, so the 122 test reads of the shipped four are unchanged. The
widening is invisible to every shipped assertion because no test compares a whole
record or reads its length (Context) — the one datum walker that does read vectors
reads the source file, not a result.

**2. Severity and machine name are stamped once, in `verify-machine`**, by one `map`
over the appended pass results: severity the constant `error` (`§16.4:938`; warnings
are a policy `§16.4:947` defers, and a record that carries the field is what makes
adding one a change to one constant); machine name `(machine-name m)` for every
diagnostic of a machine and `#f` for `pass-schema`'s not-a-machine arm — correct
because `verify-machine` runs the other passes only under `(machine? machine)`, so a
diagnostic with no machine name is exactly a diagnostic about something that is not a
machine. No emission site changes for these two fields and the diagnostic census does
not move. *Rejected*: a per-site machine argument — fifty-six edits to thread a value
every site would compute the same way, and a census move for nothing.

**3. The `node` slot keeps its shipped meaning — the subject's name, whichever table
it lives in — and `declarations` is added beside it, per site.** The slot is a list,
because `invalid-span-callback` names a span and a callback at once. The sites that
pass a non-empty list, by code:

- the nineteen whose subject is a declaration (callback 8, span 6, error 3, field 2;
  Context) pass `(list subject)`, and `invalid-span-callback`'s two among them add
  the callback the span names;
- `missing-error-declaration` — `(error-node-error-name n)`, the undeclared error;
- five of the seven `invalid-field-operand` sites — the field name: `(car args)` in
  the operand walk's three arms, the node's own field accessor in the accumulate and
  counted-consume arms; the unknown-selector and wrong-arity arms fire before any operand is read
  ("nothing can be read out of `arguments` before arity is known", the arm's own
  comment) and pass `'()`;
- `missing-callback-declaration` and the three `invalid-callback-invocation` sites at
  a callback node — `cn`, the callback the node invokes;
- the two **span** `missing-callback-declaration` sites — `(list (span-declaration-name
  sd) dn)` and `… cn` — the span **and** the callback it names *(corrected 2026-09-10,
  Slice ①: these were omitted here; see the foot note and Slice ① finding F12)*;
- `missing-span-declaration` — the span the node names.

Every other site is untouched: `make-diagnostic` keeps its arity and fills the new
slots with `'()` and `#f`; `make-diagnostic/edge` **gains a fifth `path` parameter**
*(corrected 2026-09-10, Slice ①: its one call site is a path site, so a four-argument
arity would leave it dead — see the foot note and finding F4)*; the sites that carry a
declaration list or a path call new constructors whose names begin `make-diagnostic`,
so the census counts them without an edit. About thirty sites gain a `declarations` argument and the twelve
path-bearing sites (item 4) a path — forty-two of fifty-six; the fourteen that keep
their text keep their pins. Of the 27 pin lines that contain `make-diagnostic '`
(Context), eleven sit at path-bearing sites, six at sites that gain a declaration
list and ten at unchanged sites (measured by code and node expression); Slice ①'s
plan reconciles by LABEL every pin whose site moves.

**4. The path policy**, total over the census — eight codes, twelve emission sites,
and `#f` everywhere else:

| Code | Path carried | Produced by |
| --- | --- | --- |
| `eof-reachable-stop`, `eof-zero-progress-cycle` | the EOF walk's stack from `parked-eof-start`'s answer for the reporting node — the node itself, a parked callback's pause continuation, a parked counted consume's eof-target — to the stop, or around the cycle | `eof-terminal`'s `walk`: `path` already is the DFS stack; the walk returns the verdict and its path as a two-element `list`, never a `(cons 'verdict …)` pair (Context: `edge-roles-in-source` would collect the symbol as an edge role and the matrix would go red on its baseline); `eof-verdict-join` keeps the surviving verdict's path, its left operand on a tie |
| `zero-progress-cycle` | the cycle, from the reporting node back to itself | `self-cycle` returns the cycle *(renamed from `reaches-self?` 2026-09-10, Slice ① F9: a `?` name that answers a list lies)* |
| `non-eof-into-finish` | the byte path from the entry to the source node, then the offending edge's target | `reach-from` gains a parent map; the zero-hop entry clause ("the entry is a finish terminal") carries the one-element path |
| `invalid-span-state`, `inconsistent-span-state`, `span-active-at-pause`, `span-active-at-exit` | a path from the entry to the node over `span-flow`'s edge relation | a parent map computed once from the edge list, before the fixpoint |
| every other code | `#f` | — |

"When useful" (`§16.4:943`) is read as *when the finding is about a path*. A finding
about a place — a duplicate, a bad name, an overlap, a dangling target, an
unreachable node — has no path to give, and a list of names that merely led to the
node would be `§29:1760`'s "graph/DOT visualization" in disguise.

**5. A path is representative, not canonical, and tests compare its shape.** It is a
list of node names starting at the walk's start — `parked-eof-start`'s answer for an
EOF verdict, the entry otherwise — and ending at the stop, around the cycle, at the
offending edge's target, or at the node. It is deterministic: every walk here visits
in list order, the memoised `done` table is local to one `eof-terminal` call and
records the first path that settled a verdict, and a tie in the join keeps its left
operand. `§16.4:943` says "representative" and `§16.4:945` forbids comparing it as
text, so a test asserts a path's first element, its last, and membership — never the
list.

**6. The census gains a derived row**: every emission site whose code is in the
path-bearing set passes a path argument and no other site does, read from
`verify.sls` as a datum the way the constructor set is, so a new site under a
path-bearing code cannot ship pathless.

## Consequences

- **Handed to Slice ①, by file.** `verify.sls`: the record and the four accessors
  (item 1); the stamping `map` in `verify-machine` (item 2); the per-site declaration
  lists by code (item 3); the four walks' parent maps or returned paths (item 4).
  `diagnostic-census-tests.sps`: the path row (item 6). `verify-tests.sps`: shape
  assertions for each of the eight codes — first element, last element, membership
  (item 5) — one positive and one negative per code (`§25:1625`).
  `SchemeMutationSuite.cmake`: the pins whose `FIND` or `REPLACE` contains a site
  that gains an argument, reconciled by LABEL at plan time, never loosened.
- **Two hazards its plan must clear**, both measured rather than guessed. The
  `cons`-role trap: a `(cons 'verdict path)` anywhere in `verify.sls` reddens the
  matrix's role row on its baseline. The first-element assertion: for a parked
  callback and a parked counted consume the path starts at `parked-eof-start`'s
  answer — the pause continuation, the eof-target — and NOT at the reporting node; a
  test asserting the reporting node first would pass for a dispatch and fail for
  those two kinds, and the design's first draft said "the reporting node" until its
  review found it.
- **Decisions 0020 and 0022 are annotated**, not amended (Milestone 7 Gate 0): their
  "Milestone 7" sentences are true, and this record is the decision they pointed at.
  The field name stays in the `node` slot, as 0020 said it would, and gains a
  `declarations` entry beside it; `§16.4:945`'s comparison rule, which 0022 invoked,
  is unchanged.
- **Not decided here.** Warning severity's *policy* — which findings, if any, are
  warnings (`§16.4:947` defers it; the field is a constant until it is not); a
  diagnostic renderer; a diagnostic catalog (`§27:1696`); a path for
  `unreachable-node` (none, by item 4 — decision 0031 says the same).

## Note — 2026-09-10, Milestone 7 Slice ① (implemented)

Slice ① implemented this record. Three of the **instructions** above were corrected
in place, each marked at its site; the **Context** is a record measured at `50516af`
and is untouched, so where this slice measured differently the difference is named
here rather than written back.

- **Item 3, `make-diagnostic/edge`'s arity (F4).** The clause "`make-diagnostic` and
  `make-diagnostic/edge` keep their arities" was wrong for `/edge`: item 4 puts both
  `non-eof-into-finish` sites in the path set, and `/edge`'s one call site is one of
  them, so keeping the four-argument arity would leave it dead code. It gains a fifth
  `path` parameter and keeps its name, its call site and its five test reads.
- **Item 3, the two span `missing-callback-declaration` sites (F12).** Item 3 gave the
  callback **node**'s `missing-callback-declaration` its callback but not the two
  **span** sites theirs, though the undeclared name is in scope at both. Following the
  item's own principle — a site that names a declaration beside a node passes it — the
  two span sites now carry `(list (span-declaration-name sd) dn)` and `… cn`. No count
  moves; only the contents at two of the thirty declaration sites change. **This was a
  scope call the plan flagged for the reviewer** and may be overturned; if it is, the
  two sites revert to the one-element list and the asymmetry is recorded at the sites.
- **Item 4, the walk's name (F9).** `reaches-self?` is renamed `self-cycle`: its
  contract changed from a `#t`/`#f` answer to the cycle itself, and a `?` name that
  answers a list is a comment that lies. Item 4's "two-element `list`, never a
  `(cons 'verdict …)` pair" was already right and is what shipped.

- **The Context's "122 accessor reads" is 129 at this slice's base** (`12c03d9`):
  Slice ⓪ added cases. The Context's number described `50516af` and is correct for
  that tree; it stays. Nothing in item 1's invisibility argument depends on the exact
  number — only that no test reads a whole record or its length, which holds at 129 too.

The one declared survivor `verify.sls` carries — "the EOF walk keeps no completed-set" —
named this slice as its reopening condition. The condition fired (the walk now carries
a path); it was re-measured and **still survives**, with a dated note at the mutation
recording why (the join's left-biased tie-break hands the memo only a losing operand's
stale path). Decision 0021 item 2, which the memo implements, is therefore unamended.
