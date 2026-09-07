# Milestone 7 — Slice ① (the seven-field diagnostic record and the path policy) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Authority: [decision 0032](../decisions/0032-diagnostic-record-seven-fields-and-path-policy.md)
(Gate 0, PR #85), then `milestone-7-design.md` §6 and §4.2, then the parent plan's
`§16.4:935-947` and `§25:1616` / `§25:1625`.

This is the slice `§25:1616` names ("structured graph paths in diagnostics"). It widens
the diagnostic record from four slots to nine, adds four public accessors, gives thirty
emission sites a `declarations` list and twelve a path, and changes **no verdict**: every
machine this slice's tree accepts or rejects is accepted or rejected exactly as `main`
does today. It depends on Slice ⓪ (PR #89), which settled the walks `verify.sls`
performs so that this slice — which edits the same file at every emission site — does not
meet a moving relation.

Everything below was measured at **`12c03d9`** (`main` after PR #90), on branch
`docs/m7-slice-1-plan`, tree clean. Each number states the command that produced it.
`src/` line numbers move the moment Task 3 lands and no tool here notices them; every
construct is therefore named as well as numbered, and Task 1 re-takes the whole census at
the slice's own base before anything is edited.

---

## 1. Fourteen findings that shape the work

### F1 — the record's own region carries no pins, so this slice writes the first ones

Lexing all 516 `byte_machine_mutation(` blocks in `SchemeMutationSuite.cmake` and locating
each `FIND` in `verify.sls`: **140** have `FILE src/byte-machine/verify.sls`, every one of
them resolves (0 count mismatches against its declared `SITES`), and **none** lands in
lines 1–60 — the export list, `diagnostic-tag`, the two constructors and the four
accessors.

*Blocks, not mutations, and the gap is measured rather than shrugged at:* the lane declares
525 and the lexer finds 516 blocks. The nine are two helper functions
(`byte_machine_slice3_launcher_pass`, `byte_machine_slice5b_launcher_pass`) that each wrap
one `byte_machine_mutation(` call and are invoked several times — their `FILE` is
`${LAUNCHER}` and `${launcher_file}`, so **none of the nine is a `verify.sls` mutation** and
the census of 140 is total over the file this slice edits. That is the boundary this
finding's every count carries. `rg -n -F diagnostic-tag` and `rg -n -F diagnostic-edge` over the suite print
nothing.

So the shape of the record is unpinned today. Every decision in this slice's item 1 —
which slots exist, in what order, what each constructor leaves in the ones it does not
fill — arrives with no mutation naming it, and the mutations Task 6 adds are the first.
That is a fact about where to spend the pin budget, not a defect: the four shipped
accessors are read 129 times (F14), so a wrong *index* is loud, while a wrong *default*
(`#f` where `'()` belongs) is silent until something reads it.

### F2 — the moving-site census: exactly thirty, twelve and fourteen

Reading `verify.sls` as text with a paren-balanced splitter over every `(make-diagnostic…`
form (`scratchpad/sites.py`), and classifying each site by decision 0032 items 3 and 4:

| | sites | constructor after this slice |
|---|---|---|
| gains a `declarations` list | **30** | `make-diagnostic/declarations` |
| gains a `path` | **12** | `make-diagnostic/path` (11) and `make-diagnostic/edge` (1) |
| unchanged | **14** | `make-diagnostic` |
| | **56** | |

The design says "about thirty sites gain a `declarations` argument"; at this base it is
**exactly thirty**, and the twelve path sites are exactly decision 0032 item 4's table —
`zero-progress-cycle` 1, `non-eof-into-finish` 2, `eof-reachable-stop` 1,
`eof-zero-progress-cycle` 1, `invalid-span-state` 4, `span-active-at-pause` 1,
`span-active-at-exit` 1, `inconsistent-span-state` 1. **No site is in both sets**: every
path-bearing code's subject is a node, and every declaration-bearing site's subject is a
declaration or names one beside a node. 30 + 12 + 14 = 56 and 30 + 12 = 42, which is the
design's corrected "forty-two of fifty-six".

The fourteen that keep their text, by line and code, so a later reader can check the
claim rather than trust it: `invalid-shape` ×2 (`pass-schema`), `duplicate-name`,
`missing-target` ×2, `invalid-field-operand` ×2 (the unknown-selector and wrong-arity
arms, which fire before any operand is read), `overlapping-cases`,
`ambiguous-sequence-prefix`, `unreachable-node`, `invalid-eof-target` (the dispatch arm),
`invalid-name` ×2 (the machine's own name, and a node's), and `duplicate-branch-key` at
the callback **node** (F12).

### F3 — the new constructors must not delegate, or the census's own identity breaks

`diagnostic-census-tests.sps` asserts

```scheme
(check-equal "quoted sites plus one header per constructor"
             (+ (length (census-codes the-census)) (length diagnostic-constructors))
             (census-total the-census))
```

where `census-total` counts **every** form whose car is any `define`d name beginning
`make-diagnostic`, and `census-codes` counts only those whose second element is a quoted
symbol. The difference is exactly the constructors' own `define` headers, whose `code`
parameter is unquoted — one per constructor, which is what the identity says.

A constructor that delegates (`(define (make-diagnostic code node message)
(make-diagnostic* code node message …))`) puts a *second* unquoted-code form in scope per
delegation, and the identity fails by the number of delegations. **Each of the four
constructors therefore builds its vector inline.** This is not a style preference: it is
the census's arithmetic, and it is the reason the four bodies are near-identical by
design.

### F4 — `make-diagnostic/edge`'s only call site is a path site, so 0032 item 3 and item 4 cannot both be followed literally

Item 3 says "`make-diagnostic` and `make-diagnostic/edge` keep their arities". Item 4 puts
**both** `non-eof-into-finish` sites in the path set, and `make-diagnostic/edge` has
exactly one call site — the `§16.2:908` per-edge block — which is one of them
(`rg -c "\(make-diagnostic/edge" src/byte-machine/verify.sls` prints 2: the definition and
that call). Keeping its arity leaves it with **zero callers**, which is dead code this
project deletes rather than documents.

**Resolution: `make-diagnostic/edge` gains a fifth parameter, `path`**, and keeps its
name, its one call site and the five test reads of `diagnostic-edge`. Item 3's clause is
an instruction inside a record and is corrected in place (Task 7), with a dated note. The
alternative — a fifth constructor `make-diagnostic/edge-path` beside a retired
`make-diagnostic/edge` — buys nothing and costs a name.

The constructor set after this slice is therefore **four**, and the census's derived
header count goes 2 → 4.

### F5 — the machine stamp is one value computed from the machine, not a per-pass split

Decision 0032 item 2 stamps the machine name "`(machine-name m)` for every diagnostic of a
machine and `#f` for `pass-schema`'s not-a-machine arm", justified by "`verify-machine`
runs the other passes only under `(machine? machine)`". The justification is sound and the
*mechanism* a careless reading suggests is not: `pass-schema` is a three-armed `cond`, and
its **second** arm — `invalid-shape`, "unsupported IR version" — is reached only when
`(machine? m)` is already true. A split that stamped "`pass-schema`'s output" with `#f`
would stamp that arm `#f` on a real machine and make the record's own rule ("a diagnostic
with no machine name is exactly a diagnostic about something that is not a machine")
false.

So the stamp is **one value, bound once**: `(and (machine? machine) (machine-name
machine))`, applied to the whole appended list. Under that shape the rule is true by
construction and the version arm is right without anybody thinking about it.

The version arm is also **unconstructible through the public API** — `machine-ir-version`
is stamped 1 and `supported-ir-version` is 1 (`ir.sls:817,822`), and the only way to reach
the arm is the shipped mutation `(define supported-ir-version 2)`. So the wrong answer the
split would ship could never be tested. That is the argument for the single stamp, stated
where the next reader will look for it.

### F6 — the one declared survivor names its own reopening condition, and this slice is it

`verify.sls` has exactly one `EXPECT_SURVIVES` mutation: **"verify: the EOF walk keeps no
completed-set"**, which deletes `((assq name done) => cdr)` from `eof-terminal`'s `walk`.
Its recorded reason ends:

> "Reopening condition: if a later slice gives the walk a verdict that DOES depend on which
> path reached a node, the memo stops being sound and this mutation stops being a survivor
> — it becomes a bug detector, and must be re-measured then rather than inherited."

This slice gives the walk an answer that depends on which route reached a node. **The
condition fires.** Task 6 re-measures the mutation rather than inheriting it, and both
endings have a disposition written in advance:

- **caught** — `EXPECT_SURVIVES` is replaced by a measured pin and the reason is replaced
  by a short note recording that the condition fired and which case separates it;
- **still surviving** — the reason gains a dated note saying the condition fired, what was
  tried, and why no fixture separated it. It is not inherited silently either way.

The memo stays **sound** for paths, and the plan says why so the re-measurement is not
mistaken for a bug: `eof-terminal` binds a fresh `done` per call and `walk` is entered as
`(walk start '())`, so every `path` in that call has `start` at its tail and every
memoised path is a genuine path *from `start`*. What the memo fixes is *which* of several
such paths is reported — decision 0032 item 5's "the first path that settled a verdict".

### F7 — twenty-three of the hundred and forty pins move, and the other hundred and
seventeen keep their `FIND`s

Measured by locating every verify.sls `FIND` in the source and intersecting its line span
with the constructs this slice edits. **Design §11 asks Slice ①'s plan for exactly this
list, by LABEL.**

**Moving because the `FIND` covers a moving emission site (13):**

1. `verify: the duplicate-field diagnostic does not name the field`
2. `verify: the nonportable-field diagnostic does not name the field`
3. `verify: a callback node naming no declaration falls through to the key arms`
4. `verify: every :908 finding is labelled `case` regardless of which edge produced it`
5. `verify: an emission site is relabelled with another existing code`
6. `verify: an EOF cycle through pause continuations is not reported`
7. `verify: span RE-ENTRY is accepted`
8. `verify: a span re-entering itself is not rejected`
9. `verify: span OVERLAP is accepted`
10. `verify: a WRONG END is accepted`
11. `verify: ending the wrong span is not rejected`
12. `verify: an UNMATCHED END is accepted`
13. `verify: a merge disagreement is not reported`

Number 4 is the subtle one and is the reason this census was run rather than a `rg` for
`make-diagnostic '`: its `FIND` is the single token `(car re))` — the edge argument
*with the closing paren of the whole form*. A fifth argument moves that paren onto a new
line, so the `FIND` goes stale even though the line's own text survives. `(car re)` occurs
once in the file, so the re-anchor is unambiguous; its `REPLACE` (`'case)`) must lose the
same paren, or the mutant changes two things.

Of the eight suite lines that carry `make-diagnostic '` at these thirteen sites, all
thirteen `REPLACE`s must be re-read with their `FIND`s: five of them (numbers 1, 2, 3, 5,
13) contain a `make-diagnostic` call of their own, and a `REPLACE` left at the pre-slice
constructor name applies, exits nonzero and pins nothing.

**Moving because the zero-progress report block is restructured (8):**

14. `verify: zero-progress detection never fires`
15. `verify: a pause-only zero-progress cycle is not flagged`
16. `verify: a self-targeting sequence node is not reported as a zero-progress cycle (§25:1533)`
17. `verify: the zero-progress report is not gated on byte-reachability`
18. `verify: the zero-progress REPORT set excludes the zero-width kinds`
19. `verify: the zero-progress REPORT set excludes the accumulate kind`
20. `verify: the zero-progress REPORT set excludes the callback kind` (declared under
    `SPEC byte-machine.unit.kind-position-census.chez.source`, not the verify lane — a
    mutation is witnessed only by its own SPEC lane's program)
21. `verify: the zero-progress REPORT set excludes the span kinds`

**Moving because `classify`'s terminal arms return a pair (2):**

22. `verify: an eof-target cycle is classified as a finish terminal`
23. `verify: an EOF-reachable stop terminal is accepted`

**Not moving, and each for a reason worth writing down**, because a reader would expect
several of them to:

- `verify: the zero-progress REPORT set excludes the counted-consume kind` — its `FIND`
  stops one line short of the `(reaches-self? …)` call, so it is the one member of that
  family the restructure does not touch.
- `verify: the EOF walk keeps no completed-set` — `((assq name done) => cdr)` is unchanged
  text: the memo's value becomes a two-element list and `=> cdr` delivers it unaltered.
  (Its *verdict* may change; see F6.)
- `verify: sibling EOF answers take the first arm instead of the max` — unchanged **because
  the pair handling goes inside `eof-verdict-join`**, not at its call sites. That is the
  design constraint that keeps this pin, the two counted-join pins and `join-over` intact.
- `verify: classify drops the next half of the counted join`, `… the eof half …` — same.
- `verify: eof-terminal does not classify a sequence node reached mid-chain (arm 5)`,
  `verify: eof-terminal's classify loses its accumulate arm and raises out of
  verification` — `dispatch-arm` keeps its signature.
- the five `eof-verdict-tiers` pins — the tier list itself is untouched.
- `verify: the :908 check is not gated on byte-reachability`, `verify: the :908 gate is
  vacuous, so no byte edge into a finish is ever rejected` — kept **because the parent map
  is bound as a `let*` sibling of `br908`**, which adds a binding without adding a nesting
  level, so the body's indentation does not move.
- `verify: the :908 check reads only the first of a node's out-targets`,
  `verify: the entry being a finish terminal is not rejected (Slice ⓪b, OQ-2)`.
- `verify: pass 7's EOF half keeps taking byte edges` — `span-flow` does not change at all
  (F11).
- `verify: pass-fields is never run`, `verify: pass-declarations is never run`,
  `verify: pass-spans is never run`, `verify: the §16.2:894 sequence-ambiguity pass is
  never run` — kept **because the stamp binds as a sibling of `ds`** (F8).
- `verify: §16.2:900 does not see callback invocations`, `verify: a callback invocation
  inside a span is admitted`, `verify: a span open at an ERROR terminal is rejected too`,
  `verify: a finish reachable with a span active is admitted`,
  `verify: top flows onward instead of stopping at the merge` — `cond` heads, unchanged.

Four of those "not moving" entries are only true under a specific shape of the edit. Those
shapes are Global Constraints below, not suggestions.

### F8 — `verify-machine`'s stamp binds beside `ds`, not above it

The four `verify: pass-X is never run` pins anchor on single lines of the pass list
(`(pass-fields machine)` and friends), whose text is entirely indentation plus the call.
Introducing the machine name as a `let*` step above `ds` re-indents the whole `append` by
four columns and breaks all four.

Binding it as a **sibling** in the same `let` does not — `nm` reads only `machine` — and
stamping at the result:

```scheme
(let ((ds (append (pass-schema machine) …))          ; unchanged, to the column
      (nm (and (machine? machine) (machine-name machine))))
  (make-verification-result (null? ds)
                            (map (lambda (d) (stamp-diagnostic d nm)) ds)
                            machine))
```

`(null? ds)` is computed on the unstamped list and stamping cannot change emptiness. The
two shapes are equally clear; the one that does not churn four pins for nothing is
preferred, and this sentence is why.

### F9 — the eight zero-progress pins move because one walk must not become two

`reaches-self?` answers `#t`/`#f` from a frontier walk with a `seen` set and no parent
links. Decision 0032 item 4 wants the cycle itself. Two shapes were weighed:

- **one walk that returns the cycle** — the `if`'s test must then bind its value, so the
  block's head and the alignment of the `(or …)` disjuncts change, and eight pins
  re-anchor;
- **a second walk** (`reaches-self?` unchanged, a `cycle-path` beside it called only when a
  finding fires) — the eight `FIND`s survive untouched.

The second is rejected. It is a **second census of the same relation**, which is the
failure mode this file has spent three slices removing ("*** ONE census, two views ***"
at `node-out-edges`; decision 0031 collapsing two hand-written parked sets), and the two
walks would disagree silently: the diagnostic would carry an empty or wrong path while the
finding itself stayed right, and nothing would be red. Eight mechanical re-anchors are
cheaper than a permanent drift surface.

Since the contract changes, the procedure is **renamed** `self-cycle` — a name ending in
`?` that answers a list is a live comment that lies. Measured blast radius:
`rg -n 'reaches-self' src/ test/` finds three sites in `verify.sls` (a comment at the
`reexec-targets` header, the definition, the call) and one comment in
`test/support/harness/byte-machine/test/machine-gen.sls`; all four are live comments or
code and are corrected in place. Four of the eight `FIND`s already contain the old name,
so the rename adds no pin churn beyond what the restructure costs.

Each of the eight `REPLACE`s reproduces the whole block minus one disjunct. They are
regenerated **from the post-edit source**, mechanically, and each is re-measured — not
hand-edited from the old text, which is how a `REPLACE` silently starts changing two
things.

### F10 — the path makes the EOF join's tie-break observable for the first time

`eof-verdict-join` is `(if (>= (eof-verdict-rank a) (eof-verdict-rank b)) a b)`, and
decision 0032 item 5 rests its determinism claim on the `>=` — "a tie in the join keeps its
left operand". Today that claim has **no witness**, and this is measured rather than
argued: with `>=` changed to `>` in a staged copy of `src/` and `test/` and every
verify-driving program run through the real `chez-source.ss` launcher —
`verify-tests.sps` (172 cases, 274 checks), `diagnostic-census-tests.sps`,
`kind-position-census-tests.sps`, `position-kind-tests.sps`, `graph-tests.sps`,
`interpret-tests.sps`, `compile-tests.sps`, `ir-tests.sps`, `normal-ir-tests.sps` — **all
nine exit 0 with zero `FAIL` records.** When two ranks tie the two verdicts are the same
symbol, so the two operators return observationally identical answers and nothing in the
tree can tell them apart.

With a path travelling beside the verdict, a tie *within* tier 1 or tier 2 returns a
different path for each operand. So `>=` → `>` becomes a comparison catch, and 0032 item
5's determinism sentence gains the witness it has never had. The fixture is a variant of
the shipped `t6-join-machine` (`verify-tests.sps`, the group "a benign EOF verdict never
outranks a stop in a join") in which **both** successors reach a stop, so the reported path
names which operand won.

The fixture has one constraint that decides whether it discriminates at all, and it is the
memo: the two branches must reach **two distinct stop nodes**. Route them to the same stop
and the second branch is a memo hit that returns the *first* branch's path, so `>=` and `>`
report the identical list and the mutation is uncatchable on a fixture that looks right.
Tier 1 has exactly one member, so "a tie in tier 1" means both operands answer
`eof-reachable-stop` — which is what two distinct stop nodes behind one zero-width
multi-successor node produces.

This is the one place where the slice adds a pin for a decision that predates it, and it
is here because the widening is what made the decision observable.

### F11 — `span-flow` does not change; the parent map is `pass-spans`'s

Decision 0032 item 4 asks for "a parent map computed once from the edge list, before the
fixpoint". `span-flow` already returns that edge list — `(from . to)` pairs over the
byte edges of byte-reached nodes plus the EOF edges of the parked/eof-visited set — and
nothing about producing it changes. The parent map is a BFS from the entry over that list,
bound in `pass-spans` beside `edges`.

The invariant that makes every span path exist is worth stating because a reader will ask:
`pass-spans` seeds its in-state map with the entry alone and propagates only along
`edges`, so a node that receives *any* state is reachable from the entry over exactly the
relation the parent map is built from. Every node that can carry one of the seven span
findings therefore has a path, and a node with no path cannot produce a finding.

### F12 — decision 0032 item 3's declaration list is asymmetric at two sites, and the
asymmetry is not the principle

Item 3 gives `invalid-span-callback`'s two sites "the callback the span names" beside the
span, and gives the callback **node**'s `missing-callback-declaration` its callback (`cn`).
It does not give the two **span** `missing-callback-declaration` sites theirs — although
the undeclared name is in scope at both (`dn` at the data-callback arm, `cn` at the
completion arm, bound in the same `let*` the sibling `invalid-span-callback` arms read),
and although `make-span-declaration` requires the data callback to be a symbol, so `dn` is
never `#f`.

Under item 3's own principle — "relevant declaration names", "the sites that name a
declaration *beside* a node pass it" — a finding that says "span data callback names no
declaration" without naming the callback withholds the only name a reader needs. The same
fault at a callback node already names it.

**Recommendation: follow the principle.** The two span `missing-callback-declaration` sites
pass `(list (span-declaration-name sd) dn)` and `(list (span-declaration-name sd) cn)`.
No count moves — the thirty declaration-gaining sites are the same thirty; only the
contents at two of them change. Item 3's bullet is corrected in place (it is a work order)
with a dated note at the record's foot and a header bullet, on the pattern Slice ⓪ used on
decision 0027. **This is a scope call and the reviewer may overturn it**; if it is
overturned, the asymmetry is recorded at the two sites in `verify.sls` with its reason,
because an unexplained asymmetry is what the next slice "fixes" by accident.

The mirror question, answered the other way: `duplicate-branch-key` at the callback
**node** stays without declarations, while the same code at the *declaration* keeps
`(list (callback-declaration-name cd))`. The fault there is the node's own key list; the
callback resolved and is not implicated. That reason goes in a comment at the site, so the
two sites of one code reading differently is a decision on the page rather than an
oversight.

### F13 — the `(cons 'SYM …)` trap, and exactly where this slice could hit it

`kind-position-census-tests.sps`'s `edge-roles-in-source` reads `verify.sls` as a datum and
collects the quoted symbol of **every** `(cons 'SYM …)` form as an edge role; a thirteenth
role takes the kind × position matrix's role row red **on its baseline**. `span-transfer`'s
comment records paying for this once.

The test is on a **quoted car**. Everything this slice builds pairs from variables —
`(cons name parent)` in `reach-from`, `(cons name v)` in `eof-terminal`'s memo, `(cons t p)`
in `self-cycle`'s frontier — and is safe. The one place the trap is live is
`eof-terminal`'s answer, where `(cons 'cycle path)` is the obvious spelling and is
forbidden: the verdict and its path travel as a **two-element `list`**, per 0032 item 4.
The Global Constraints carry this as a hard rule and Task 3 checks it by running the
matrix, not by reading the diff.

### F14 — the shipped accessors are read 129 times, not 122

`rg -o -F` over `test/common/*.sps` at this base: `diagnostic-code` **79**,
`diagnostic-node` **45**, `diagnostic-edge` **5**, `diagnostic-message` **0** — total
**129**. Decision 0032 measured 122 at `50516af`; Slice ⓪ added cases, and the record is
right about the tree it was decided against. The number matters only as the size of what
must not move, and the two searches that made the widening invisible are both still empty
at this base: `rg -n 'vector-length|vector->list' test/common/*.sps | rg -i diag` finds
only the census's source-datum walker, and
`rg -n "equal\? diag|#\(diagnostic|vector 'diagnostic" test/common/*.sps` prints nothing.

The number is re-taken in Task 1 and the plan does not repeat 122 anywhere as though it
described this tree.

---

## 2. What this slice ships

One PR, **two commits** (design §11): a source commit carrying `verify.sls`,
`verify-tests.sps`, `diagnostic-census-tests.sps` and `SchemeMutationSuite.cmake`
together — tests written first and red, the record, the walks, the census row, the pins,
`EXPECTED_MUTATIONS` — and a documentation commit. A widening that lands without its
re-anchored pins fails the mutation lane at declaration; a census row that lands without
the constructors is red; the partition is fixed by the tree, not chosen.

- **`verify.sls`** — the nine-slot record; four new accessors exported; four constructors,
  each building its vector inline (F3), with `make-diagnostic/edge` gaining `path` (F4);
  `stamp-diagnostic` and one `map` in `verify-machine` binding the machine name as a
  sibling of `ds` (F5, F8); `declarations` at the thirty sites; paths at the twelve, from
  `eof-terminal`'s `(verdict path)` answer, `self-cycle`'s returned cycle, `reach-from`'s
  parent alist and `pass-spans`'s edge-list parent map; comments corrected in place at
  `reach-from`, `reexec-targets` and `machine-gen.sls` for the rename.
- **`verify-tests.sps`** — one positive and one negative case per path-bearing code, each
  positive asserting the path's **first element, last element and membership** and never
  the list as text (`§16.4:945`); the severity and machine cases over a multi-diagnostic
  machine and over the not-a-machine arm; the declarations values one per declaration
  family plus `invalid-span-callback`'s two-element list; the join tie-break fixture (F10).
- **`diagnostic-census-tests.sps`** — the path row of 0032 item 6, derived on both halves
  it can derive: the path-carrying constructor set from each constructor's own parameter
  list, the code set declared because it *is* the policy; plus a **per-constructor site
  table** (14 / 30 / 11 / 1) whose sum is asserted against the existing 56, which is what
  makes the declarations change census-shaped rather than a case per site somebody thought
  of.
- **`SchemeMutationSuite.cmake`** — twenty-three re-anchored by LABEL, each `FIND` with its
  `REPLACE`; the declared survivor re-measured (F6); the new pins of Task 6;
  `EXPECTED_MUTATIONS` re-measured.
- **Documentation** — decision 0032's two corrected instructions with their dated notes
  (F4, F12); the design's §6 and Status header; the parent plan's dispositions section
  appended, never inserted; `CHANGELOG.md` and `README.org`.

**Not shipped, on purpose:** any verdict change; any diagnostic **code** added or removed;
any file under `src/` other than `verify.sls` (design §4.9's gate); a diagnostic renderer
or catalogue (§27:1696, Slice ④); a warning policy (`§16.4:947` defers it and the field is
a constant until it is not); a path for `unreachable-node` (0031 and 0032 both say none).

---

## Global Constraints

- **Authority order.** Decision 0032, then design §6/§4.2, then the parent plan. Where an
  authority is wrong, **stop and say so**: this plan already carries two of its
  instructions being wrong (F4, F12), and Slice ⓪'s carried three.
- **No verdict moves.** For every fixture in the tree, the set of diagnostic **codes** and
  the **node** each is reported under is byte-identical to `main`'s. The proof is that the
  129 shipped accessor reads (F14) pass **with the record widened and not one shipped case
  edited** — Task 3 Step 5, against Task 2 Step 1's "before" run. A shipped case edited to
  accommodate the widening is the widening failing to be invisible.
- **No diagnostic code is added or removed.** The census must read thirty codes over
  fifty-six sites at the slice's head, with `(unreachable-node 1)`, and the kind × position
  matrix's "exactly three cells prune the sink" must read 3.
- **No `(cons 'SYM …)` form enters `verify.sls`** (F13). The EOF walk's answer is a
  two-element `list`. Checked by running the matrix.
- **The four constructors build their vectors inline** (F3). No delegation, no shared
  builder whose name begins `make-diagnostic`.
- **`stamp-diagnostic` does not begin with `make-diagnostic`**, or the census counts every
  call to it as an emission site.
- **Four shapes are load-bearing for pins that must not move** (F7): the pair handling goes
  **inside** `eof-verdict-join`; the machine name binds as a **sibling** of `ds`; the byte
  parent map binds as a **`let*` sibling** of `br908`; `span-flow` is not edited.
- **`SITES` is asserted at 1 in both directions.** Before adding any line to `verify.sls`,
  check it does not duplicate a line some shipped `FIND` anchors on — `parent-path`,
  `edge-parents` and the four constructor bodies are the new code most at risk — and
  re-check after the edit with the lane itself, which reports "found 0, expected 1" and
  "pattern occurs 2 times" alike.
- **Every path assertion is by shape, never by text** (`§16.4:945`, 0032 item 5): first
  element, last element, membership. A test that compares a whole path list is the thing
  `:945` forbids, and it will be re-broken by the next slice that adds a node kind.
- **Sentinels read observed values.** Every loop over the eight path codes, the thirty
  declaration sites or the four constructors asserts the count it actually drove, and the
  count comes from what `verify-machine` returned — never from the test's own table
  length.
- **Pins go into the existing passes before their `_run`**, never into a new pass;
  `EXPECTED_PASSES` stays **58**. `EXPECTED_MUTATIONS` is **re-measured from the harness**;
  the arithmetic in Task 6 is a prediction the tree overrides.
- **Prefer the comparison catch.** Every new mutant is judged by how many cases it fails
  and whether they fail identically. Pin a case-name tail plus a check label, no `.*`
  between `expected` and `got`, the measured `got` spelled in full, `got .[)]` for an empty
  list, `$` anchors nothing, and each pin matching **exactly once** among its own mutant's
  `FAIL ` records.
- **A widening mutant nests inside a deleting one.** "The path is empty" is strictly less
  destructive than "the finding is gone", so every new path pin needs a fixture carrying
  something positive under both — assert the finding **count** beside the path, so the two
  report different numbers.
- **Filter suite output for the failure signatures** — `CMake Error`, `wrong reason`,
  `UNCAUGHT`, `tests passed` — and the exit status. The mutation suite prints "suite
  complete" on the way to failing.
- **Record vs instruction.** Source and test comments naming a renamed construct are
  instructions, corrected in place. Decision 0032's items 3 and 4 are instructions inside a
  record: corrected in place, with a dated note and a header bullet. Its **Context** is a
  record measured at `50516af` and is not touched; where this plan's numbers differ (F14),
  the difference is stated here and in the note, not written back into the Context.
- **Both lanes, always.** Every new case runs in `.chez.source` and `.chez.aot`.
- **Design §4.9's gate at every step**: `git diff --stat 5ac363a..HEAD -- src/
  ':!src/byte-machine/verify.sls'` prints nothing; `git diff --stat main..HEAD --
  test/fixtures` prints nothing.

---

## Task 1 — Re-take the census at the base, and the pin ledger

**Files:** none modified. A detached scratch worktree, removed at the end.

Every number in §1 was measured at `12c03d9`. If the slice's base has moved, they are
re-taken **before** anything is edited; if it has not, they are re-taken anyway, because a
census nobody re-ran is a census nobody checked.

- [ ] **Step 1.** `git log --oneline -1` and `git diff --stat <base>..HEAD -- src/ test/`.
      Expected: no output from the diff if the base is `12c03d9`.
- [ ] **Step 2.** Re-run the emission-site census and confirm the three totals.
      Expected exactly: `30` declaration-gaining, `12` path-bearing, `14` unchanged,
      summing to `56`; the twelve path sites' codes exactly decision 0032 item 4's eight.
      A different number is a finding and stops the task.
- [ ] **Step 3.** Re-run the accessor-read counts and the two emptiness searches (F14).
      Expected: four counts, and **no output** from
      `rg -n "equal\? diag|#\(diagnostic|vector 'diagnostic" test/common/*.sps`; the
      `vector-length|vector->list` search finds **only** the two
      `diagnostic-census-tests.sps` lines.
- [ ] **Step 4.** Re-run the pin census (lex every `byte_machine_mutation(` block, keep
      `FILE src/byte-machine/verify.sls`, locate each `FIND`).
      Expected exactly: **140** blocks, **0** `FIND`-count mismatches, and the
      twenty-three LABELs of F7 — no more, no fewer. A LABEL in the tree that is not in
      F7's list, or the reverse, is corrected in this plan before Task 2 begins.
- [ ] **Step 5.** Record the baseline suite numbers, measured not quoted:
      `cmake --preset dev`, `ctest --preset release` (expected **114/114**), and the
      mutation lane's own declared totals (expected `58 passes / 525 mutations`),
      filtered for the failure signatures.
- [ ] **Step 6.** Read decision 0032's items 3 and 4 against the tree once more and
      confirm F4 and F12 reproduce. Expected: `rg -c "\(make-diagnostic/edge"` prints
      `2`; `dn` and `cn` are in scope at both span `missing-callback-declaration` arms.

**Exit:** the six expectations above met, or this plan corrected where they are not.

---

## Task 2 — Tests first: the record, the stamps, the declarations, the paths (red)

**Files:** `test/common/verify-tests.sps`, `test/common/diagnostic-census-tests.sps`.

Written before `verify.sls` changes, and red for the right reason — an unbound
`diagnostic-path` is an import error, not a failed comparison, so the new cases land
together with Task 3 in one commit and this task's "red" is verified by running the lane
once with the accessors stubbed out of the group under construction, or simply by ordering
Task 3 immediately after and reviewing the diff. What must **not** happen is a green run
that proves nothing.

- [ ] **Step 1 (the invisibility proof, and it runs FIRST).** Run
      `ctest --preset release -R 'verify|census|kind-position'` on the **unmodified** tree.
      Expected: green. This is the "before" half of the oracle; the "after" half is the
      identical command in Task 3 with no case edited.
- [ ] **Step 2.** Severity and machine, one case each:
      - a machine with at least three diagnostics from three different passes — every one
        carries `diagnostic-severity` `error` and `diagnostic-machine` the machine's name,
        asserted with a sentinel over the **observed** diagnostic count;
      - `(verify-machine 'not-a-machine)` — one `invalid-shape` diagnostic, severity
        `error`, machine `#f`. State in the case's comment why `#f` here is not a
        placeholder but the rule (F5), and that `pass-schema`'s version arm is
        unconstructible so the machine-name answer there is proven by construction rather
        than by a fixture.
- [ ] **Step 3.** Declarations, one case per declaration family — callback, span, error,
      field — plus `invalid-span-callback`'s **two-element** list, which is the only site
      whose list has more than one member and therefore the only one that proves the slot
      is a list rather than a name. Each asserts the whole `diagnostic-declarations` value
      by `check-equal`, and each asserts that a *neighbouring* site under the same code
      answers what it should (F12's `duplicate-branch-key` pair is the case that makes the
      per-site policy visible).
- [ ] **Step 4.** For each of the **eight** path-bearing codes, one positive case:
      `diagnostic-path`'s **first** element, **last** element and **membership** of the
      offending node. The first element is the walk's start, and for two kinds that is
      *not* the reporting node — a parked callback starts at its pause continuation and a
      parked counted consume at its eof-target (`parked-eof-start`). Decision 0032's own
      Consequences record that the design's first draft got this wrong; the two cases that
      would have caught it are written here explicitly, one per kind.
- [ ] **Step 5.** For each of the eight, one negative: a fixture one edit away from the
      fault, asserting the code is **absent**. A path assertion on a code no fixture emits
      passes vacuously, and this is what closes that.
- [ ] **Step 6.** The join tie-break fixture (F10): a `t6-join-machine` variant whose two
      EOF successors reach **two distinct stop nodes**, asserting which route the reported
      path names. The distinctness is the whole fixture — one shared stop makes the second
      branch a memo hit and the mutation uncatchable (F10). One case, two directions: the
      path under the shipped `>=`, and the case's comment naming what `>` would report.
- [ ] **Step 7.** The census's path row and per-constructor table (§2). Both derived where
      they can be: the constructor set from every `define` beginning `make-diagnostic`
      (already shipped), the **path-carrying** subset from those whose parameter list
      contains `path`, the site counts from the walk. The path-bearing **code** set is
      declared, because it is the policy of 0032 item 4 and not a property of the source —
      say so in the comment, with the citation.
- [ ] **Step 8.** Assert the sums: the per-constructor site counts total 56, and the
      path-carrying sites total 12. Two totals that can only agree if nothing cancelled.

**Exit:** every new case exists and asserts an observed value; Step 1's run is recorded.

---

## Task 3 — The source change: the record, the constructors, the stamp, the declarations

**Files:** `src/byte-machine/verify.sls`.

- [ ] **Step 1.** The record: `(vector diagnostic-tag code node message edge severity
      machine declarations path)`, slots 0–8. Four accessors at 5–8, added to the `export`
      list beside the four shipped ones.
- [ ] **Step 2.** Four constructors, each building its vector inline (F3):
      `make-diagnostic` (3 args, `#f #f '() #f` in the new slots), `make-diagnostic/edge`
      (5 args — F4), `make-diagnostic/declarations` (4), `make-diagnostic/path` (4). The
      comment above them states the census identity that forbids delegation, so the next
      author does not "simplify" it.
- [ ] **Step 3.** `stamp-diagnostic`, and `verify-machine`'s sibling binding (F8). Confirm
      by diff that the `append` block's indentation is unchanged.
- [ ] **Step 4.** The thirty declaration sites, by code, working the F2 census as a
      checklist. `invalid-span-callback`'s two carry two names; the two span
      `missing-callback-declaration` sites carry two under F12's recommendation; the
      callback node's `duplicate-branch-key` carries none, with its reason at the site.
- [ ] **Step 5.** Run `ctest --preset release -R 'verify|census|kind-position'`. Expected:
      the **129** shipped accessor reads pass with no case edited, the kind × position
      matrix is green (which is the `(cons 'SYM …)` check, F13), and only the new cases of
      Task 2 that depend on paths are red.
- [ ] **Step 6.** Run the census. Expected: thirty codes over fifty-six sites, the
      per-constructor table `14 / 30 / 11 / 1`, and the header count now **4**.

**Exit:** Step 5's two green halves; the census reading exactly the numbers above.

---

## Task 4 — The source change: four walks, four paths

**Files:** `src/byte-machine/verify.sls`. Same commit as Task 3.

- [ ] **Step 1. `eof-terminal`.** Every answer becomes `(list verdict (reverse path))` —
      never `(cons 'verdict …)` (F13). The memo stores the pair unchanged, so
      `((assq name done) => cdr)` keeps its text (F7). `eof-verdict-join` ranks
      `(car a)`/`(car b)` and returns the whole pair, which is what keeps `join-over` and
      the two counted-join pins intact. `dispatch-arm` keeps its signature.
      `pass-eof-execution` binds the answer and `case`s on its car.
- [ ] **Step 2. `self-cycle`** (was `reaches-self?`, F9): the frontier carries
      `(name . route)` and the success arm returns the cycle, from the reporting node back
      to itself. A self-loop is the two-element path `(n n)` — the shortest case and the
      one to write a test for. Correct the three comments and `machine-gen.sls`'s.
- [ ] **Step 3. `reach-from`** returns an alist of `(name . parent)`, `#f` at the entry;
      `byte-reached` becomes `(map car (reach-from m node-out-targets))`; the `:908` block
      binds the alist as a `let*` sibling of `br908` (F7) and builds the path as
      entry → source → the offending edge's target. The zero-hop entry clause carries the
      one-element path. `reach-from`'s header comment says "Returns the reached node
      names" — an instruction, corrected in place.
- [ ] **Step 4. `pass-spans`** binds a parent map from `(span-flow m)`'s edge list before
      the fixpoint (F11); `span-node-diagnostics` gains a third parameter; the `top` arm
      and the six transfer sites carry `(parent-path parents (node-name n))`.
      `span-flow` itself is not edited — check by diff.
- [ ] **Step 5.** `parent-path` and `edge-parents`: one shared walk-back and one BFS, with
      a comment naming which call sites guarantee membership (the `:908` block passes only
      `br908` members; `pass-spans` passes only nodes that received a state, which are the
      closure from the entry). A guard that cannot guard is not added.
- [ ] **Step 6.** Run the whole `release` selection minus the mutation lane. Expected:
      **113/113**, every golden byte-identical, `git diff --stat main..HEAD --
      test/fixtures` empty.

**Exit:** 113 green; design §4.9's gate command prints nothing.

---

## Task 5 — The pins that move

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`. Same commit.

- [ ] **Step 1.** Re-anchor the thirteen emission-site pins of F7 by **LABEL**, reading
      each `FIND` and its `REPLACE` together and stating what single decision separates
      them. Five `REPLACE`s contain a `make-diagnostic` call of their own and move with
      their `FIND`s. Number 4 (`(car re))`) loses a paren on both sides.
- [ ] **Step 2.** Regenerate the eight zero-progress `REPLACE`s from the post-edit source
      (F9), mechanically — take the new block, delete the named disjunct, and diff the
      result against what the `REPLACE` claims to be. Never hand-edited from the old text.
      Number 20 stays in the census lane's pass; a mutation is witnessed only by its own
      SPEC lane's program.
- [ ] **Step 3.** Re-anchor the two `classify` pins (22, 23), each `REPLACE` becoming the
      pair form so the mutant still changes exactly one thing.
- [ ] **Step 4.** Run the mutation lane. Expected: no `CMake Error`, no `wrong reason`, no
      `UNCAUGHT`, exit 0, and `EXPECTED_MUTATIONS` still 525 at this point — this task
      moves no count.
- [ ] **Step 5.** For each of the twenty-three, re-measure the `got` it pins by staging the
      mutant in a scratch copy and running the real launcher. A `got` digest is never
      recomputed by hand.

**Exit:** the lane green with 58 / 525; twenty-three measured `got` values recorded.

---

## Task 6 — The pins this slice adds, and the survivor re-measured

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`. Same commit.

The intended set, each to be measured rather than assumed. Where two mutants nest, the
separating fixture is named beside the pin, in the tree.

- [ ] **Step 1.** *The stamping `map` is dropped* — severity and machine both read `#f`.
- [ ] **Step 2.** *The machine stamp answers a constant* — `(machine-name machine)` →
      a fixed symbol, **not** `#f`, so its `got` differs from Step 1's and it is not
      nested inside it. (Written as `#f` it would be subsumed by construction; this is the
      fixture-side fix AGENTS.md prescribes, applied at the mutation instead.)
- [ ] **Step 3.** *Severity is a warning* — `'error` → `'warning` in `stamp-diagnostic`.
- [ ] **Step 4.** *The EOF path is not reversed* — `(reverse path)` → `path`. A first/last
      element assertion is a comparison catch and this is the pin for 0032 item 5's
      "starting at the walk's start".
- [ ] **Step 5.** *The EOF verdict join keeps the right operand on a tie* — `>=` → `>`,
      on F10's fixture. Measured at plan time: this mutant is **uncaught in all nine**
      verify-driving programs today, so the pin closes a real gap rather than restating a
      catch some other lane already has. Expected after the fixture lands: caught, with the
      `got` naming the route through the *second* stop node.
- [ ] **Step 6.** *The zero-progress cycle path is empty* — `self-cycle`'s success arm
      returns `'()`. Separated from the shipped "zero-progress detection never fires" by
      asserting the finding **count** beside the path.
- [ ] **Step 7.** *A byte parent is not recorded* — `reach-from` stores `#f` as every
      parent, emptying `non-eof-into-finish`'s path.
- [ ] **Step 8.** *A span parent is not recorded* — the same for `edge-parents`, emptying
      the four span codes' paths. Kept separate from Step 7 because they are two maps and
      two decisions; each reddens a family the other does not.
- [ ] **Step 9.** *A declarations list loses its second name* —
      `invalid-span-callback`'s two-element list drops the callback.
- [ ] **Step 10.** *A path-bearing site is relabelled to a non-path code* — the census's
      path row is the unique record that separates this from the shipped "an emission site
      is relabelled with another existing code", whose `REPLACE` relabels within the path
      set and leaves the row green.
- [ ] **Step 11. The declared survivor** (F6). Re-measure "verify: the EOF walk keeps no
      completed-set" against this tree. **Caught** → replace `EXPECT_SURVIVES` with a
      measured pin and replace the reason with a note recording that the reopening
      condition fired and which case separates it. **Still surviving** → the reason gains a
      dated note saying the condition fired, what was tried, and why nothing separated it.
      Either way it is not inherited.
- [ ] **Step 12.** For every new mutation, count how many cases it fails and whether they
      fail identically. A uniform failure across most of the suite is a crash, not a
      discrimination, and is re-shaped before it is pinned.
- [ ] **Step 13.** Re-measure `EXPECTED_MUTATIONS` from the harness. The prediction is
      525 + 10 = **535**, ±1 for Step 11; the tree overrides it. `EXPECTED_PASSES` stays
      58.
- [ ] **Step 14.** Run the two-direction sweep against a control at the slice's base:
      every pin judged against every **other** mutant's captured output, and every **new**
      pin judged against every existing mutant. Collisions at HEAD that are absent at the
      control are this branch's doing; the rest is inherited debt and is recorded as such.
- [ ] **Step 15.** Count each pin's matches in its **own** mutant's `FAIL ` records with a
      DOTALL `findall` and require **1**. A new check label that contains a shipped pin's
      literal core resolves that pin twice, the lane stays green, and only this count sees
      it. The eight new path cases introduce eight new labels; each is checked against
      every pin's literal core before it is committed.

**Exit:** the lane green at 58 / measured; the sweep showing zero introduced collisions;
every pin matching exactly once in its own mutant's output.

---

## Task 7 — Both ends, and the status surfaces

**Files:** `docs/decisions/0032-…md`, `docs/plans/milestone-7-design.md`,
`docs/plans/byte-machine-implementation-plan.md`, `CHANGELOG.md`, `README.org`.

- [ ] **Step 1.** Decision 0032, item 3: correct the `make-diagnostic/edge` arity clause
      in place (F4) and, if the reviewer accepts F12, the two span
      `missing-callback-declaration` sites. Add one dated note at the foot naming both
      corrections and their reasons, a bullet at the header saying a later note reached
      back into the record, and a one-line marker at each corrected item. The pointer
      routes; it does not restate. **The Context is not touched** — its numbers describe
      `50516af` and are evidence.
- [ ] **Step 2.** The design's §6 and its Status header: corrected in place (instructions),
      with the amendment indexed newest-first in the blockquote, naming the sections it
      amends. §4.2's item 3 carries the same `make-diagnostic/edge` clause and is corrected
      with it — the record and the design fail independently, and the design is where the
      record got the sentence.
- [ ] **Step 3.** The parent plan: **append** to `## Dated dispositions`, never insert.
      The file is 2491 lines at this base and is navigated by `§section:line` from dozens
      of citations; an insertion re-numbers all of them and no link check can see it.
      Record what `§25:1616` now has in the tree and what `§25:1625` still owes (the
      negatives for the twenty-two non-path codes are Slice ④'s catalogue).
- [ ] **Step 4.** `CHANGELOG.md`'s `[Unreleased]` preamble and `README.org`'s status
      paragraph. README is the surface no step names and the one whose drift is unbounded.
- [ ] **Step 5.** Re-open every `file:line` this branch's documents cite, **as the last
      step before commit**, including the ones written in Task 1 — a citation into a file
      the same commit also edits is stale on arrival.

**Exit:** five surfaces current; `git diff | rg "^-"` over decision 0032 shows only the two
corrected instruction lines and nothing from its Context.

---

## Task 8 — The whole-branch review, and the close

- [ ] **Step 1.** Run the review in an **isolated worktree** — subagents told they may edit
      to test a hypothesis will edit whatever tree they are given, and a `ctest` run
      alongside such a workflow reports numbers that are not about your tree.
- [ ] **Step 2.** Put `AGENTS.md`'s sentence in the reviewer's prompt **verbatim**: *check
      what this claims the code or the spec DOES against the code and the spec, not against
      the prose.* That sentence is what caught three false supporting reasons in Milestone
      4's Gate 0 and the retirement error in Slice ⓪; the reviews that lacked it caught
      none.
- [ ] **Step 3.** Ask the three questions this slice's shape invites: does any verdict
      move; is every claim in a new comment true of the code beside it; and what did
      decision 0032 decide that this tree does not contain.
- [ ] **Step 4.** Re-run every count the documents quote, from the tree rather than from a
      commit message. A count restated in two places will disagree with itself.
- [ ] **Step 5.** Fold the findings, re-run Tasks 5 and 6's measurements after the fix
      wave — a fix moves counts, and a sweep run once at the end is a sweep that did not
      see the fixes.
- [ ] **Step 6.** Open the PR. Label it `ci` only when the branch is final; a later push
      does not re-run the labelled job. **PR #88's two-run Chez-cache verification is still
      unperformed** — Slice ⓪ merged without the label at the owner's word — so this is the
      first PR that can discharge it, and its body should say whether it did.
- [ ] **Step 7.** The closing ritual on the owner's go-ahead: squash-merge, fast-forward
      local `main`, delete the branch locally and remotely, and reflect — durable facts to
      memory, project standards to `AGENTS.md`, anything the code should say about itself
      into a comment at the site.

---

## Verification

Run at the head of the source commit and again after the review's fix wave.

1. `cmake --preset dev && ctest --preset release` — **114/114**, both Chez modes.
2. `ctest --preset release -E scheme-mutation` — 113/113.
3. The mutation lane — `58` passes, `EXPECTED_MUTATIONS` as measured, filtered for
   `CMake Error`, `wrong reason`, `UNCAUGHT`, `tests passed`, plus the exit status.
4. The diagnostic census — thirty codes over fifty-six sites, `(unreachable-node 1)`, the
   per-constructor table `14 / 30 / 11 / 1`, twelve path-carrying sites, four constructors.
5. The kind × position matrix — green, pruning count **3** (this is the `(cons 'SYM …)`
   check).
6. `git diff --stat 5ac363a..HEAD -- src/ ':!src/byte-machine/verify.sls'` — no output.
7. `git diff --stat main..HEAD -- test/fixtures` — no output.
8. The two-direction pin sweep against a control at the base — zero introduced collisions;
   every pin matching exactly once in its own mutant's `FAIL ` records.

## Exit

- The record carries `§16.4:937-943`'s seven fields in nine slots; `diagnostic-severity`,
  `diagnostic-machine`, `diagnostic-declarations` and `diagnostic-path` are exported from
  `(byte-machine verify)`.
- Every one of the eight path-bearing codes has a positive case asserting its path's first
  element, last element and membership, and a negative case naming the code it must not
  emit.
- The census's path row is total over the fifty-six sites and derived on both halves it can
  derive; a new site under a path-bearing code cannot ship pathless.
- No verdict moved: every fixture's code set and node set is byte-identical to `main`'s,
  and the 129 shipped accessor reads passed before a single new case was written.
- The twenty-three moved pins are re-anchored by LABEL with their `REPLACE`s, the new pins
  are measured, and the declared survivor is disposed rather than inherited.
- Decision 0032's two corrected instructions carry dated notes; the design, the parent
  plan, `CHANGELOG.md` and `README.org` all say what the tree says.
