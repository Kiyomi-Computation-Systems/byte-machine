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
the census's arithmetic.

**Proven by construction, not by reading.** Staging exactly that refactor in a scratch copy
— one `make-diagnostic*` builder with `make-diagnostic` and `make-diagnostic/edge` both
delegating to it — and running `diagnostic-census-tests.sps` through the real
`chez-source.ss` launcher gives status 1 on one case, with the record

```
FAIL … every emitted code is a quoted symbol: quoted sites plus one header per constructor
     -- expected 61, got 59
```

off by exactly the two delegating calls. A reviewer who thinks the shared builder is
tidier can re-run that in a minute; the plan's job is to make sure nobody discovers it in
Task 3 with the record already half-written.

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

All thirteen `REPLACE`s are re-read with their `FIND`s, and **five of the thirteen**
(numbers 1, 2, 3, 5 and 13) contain a `make-diagnostic` call of their own, so they move
too. A `REPLACE` left at the pre-slice constructor name still applies, still exits nonzero
and still satisfies its pin — while the mutant now differs from the baseline in two ways,
so the failure it produces isolates nothing. That is the half of re-anchoring the suite
does not report.

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
shapes are Global Constraints below, not suggestions — **and three of them were staged in a
scratch copy and measured** rather than argued.

*The prototype:* `verify-machine`'s machine name bound as a sibling of `ds` with the stamp
at `make-verification-result`; the `:908` gate's parent map bound as a `let*` sibling of
`br908`; and `make-diagnostic/edge`'s call site given a fifth argument. Judging **all 140**
`verify.sls` `FIND`s against the result:

> 140 verify.sls pins judged against the 3-shape prototype; **1** not exactly once:
> `count=0  verify: every :908 finding is labelled \`case\` regardless of which edge produced it`

So the four `verify: pass-X is never run` pins, both `:908` gate pins, the out-targets pin
and the entry pin all still resolve exactly once, and the single casualty is the one F7
predicts. The remaining twenty-two moving pins are the emission-site, zero-progress and
`classify` families, which the prototype does not stage because their shape is the work of
Tasks 3 and 4.

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
preferred, and this sentence is why. Measured on the prototype in F7: all four `FIND`s
still occur exactly once.

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
described this tree. **Design §6 and §4.2 do**, twice, and Task 7 corrects them.

*The boundary this count carries*, because a scope claim inherits the scope of the
measurement behind it: the searches above are over `test/common/*.sps`, which is decision
0032's own scope. Task 1 Step 3 widens them to `src/` and `test/support/` and records the
result — `compile.sls` and `interpret.sls` each pass a `verification-diagnostics` result
through without indexing it, so the widening is expected to hold there too, but "expected"
is not "measured" and the step is what makes it the latter.

---

## 2. What this slice ships

One PR on `feat/m7-slice-1`, **two commits** (design §11): a source commit carrying
`verify.sls`, `verify-tests.sps`, `diagnostic-census-tests.sps` and
`SchemeMutationSuite.cmake` together — the record, the walks, the census row, the
re-anchored pins, the new pins, `EXPECTED_MUTATIONS` — and a documentation commit.

*How much of that partition the tree fixes, stated precisely rather than waved at:* Tasks
2–5 **cannot** be split. A widening that lands without its re-anchored pins fails the
mutation lane at declaration, that lane is in the release selection, and a census row that
lands without the constructors is red. Task 6 is different — adding mutations with their
`EXPECTED_MUTATIONS` bump is green-to-green and *could* be its own commit; it is folded in
by **instruction** (design §11: "① likewise", one source commit and one documentation
commit), not by the tree. Saying "the partition is fixed by the tree" of all four would be
a false supporting argument for a correct decision, which is the shape this project has
shipped before.

- **`verify.sls`** — the nine-slot record; four new accessors exported; four constructors,
  each building its vector inline (F3), with `make-diagnostic/edge` gaining `path` (F4);
  `stamp-diagnostic` and one `map` in `verify-machine` binding the machine name as a
  sibling of `ds` (F5, F8); `declarations` at the thirty sites; paths at the twelve, from
  `eof-terminal`'s `(verdict path)` answer, `self-cycle`'s returned cycle, `reach-from`'s
  parent alist and `pass-spans`'s edge-list parent map; comments corrected in place at
  `reach-from`, `reexec-targets` and `machine-gen.sls` for the rename.
- **`verify-tests.sps`** — one positive and one negative case per path-bearing code,
  driven by **one loop over a table of eight** with a sentinel reading the observed count,
  each positive asserting the path's **first element, last element and membership** through
  a `#f`-tolerant guard (so an absent path fails by comparison, not by a raise in `car`)
  and never the list as text (`§16.4:945`); the **finding-count** assertion beside each
  path, which is what separates an empty-path mutant from the emission-deleting one that
  contains it; the severity and machine cases; the declarations values one per declaration
  family plus the two-element lists; the join tie-break fixture (F10).
- **`diagnostic-census-tests.sps`** — the path row of 0032 item 6, derived on both halves
  it can derive: the path-carrying constructor set from each constructor's own parameter
  list, the code set declared because it *is* the policy; plus a **per-constructor site
  table** (14 / 30 / 11 / 1) whose sum is asserted against the existing 56, which is what
  makes the declarations change census-shaped rather than a case per site somebody thought
  of.
- **`SchemeMutationSuite.cmake`** — twenty-three re-anchored by LABEL, each `FIND` with its
  `REPLACE`; the declared survivor re-measured (F6); the new pins of Task 6;
  `EXPECTED_MUTATIONS` re-measured.
- **Documentation** — decision 0032's items 3 **and 4** corrected with their dated notes
  (F4, F12, and the `reaches-self?` rename); the design's §4.2, §6, Status header and
  **Appendix ledger**, whose "Path (①)" column design §11 hands to this slice as its
  checklist; the parent plan's dispositions section appended, never inserted;
  `CHANGELOG.md`'s preamble **and an `### Added` entry** naming the four accessors, which
  design §6's Oracle asks for by name; `README.org`.

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
  "pattern occurs 2 times" alike. The rule also constrains code this slice writes for its
  **own** pins: `(reverse path)` must occur **once** in `eof-terminal`, which is why all
  six verdict answers go through one helper (Task 4 Step 1) — six copies would make Task 6
  Step 4's mutation a six-site edit, and a six-site mutation is not a pin.
- **Every path assertion is by shape, never by text** (`§16.4:945`, 0032 item 5): first
  element, last element, membership. A test that compares a whole path list is the thing
  `:945` forbids, and it will be re-broken by the next slice that adds a node kind.
- **Sentinels read observed values.** The loop over the eight path codes (Task 2 Step 4)
  asserts the count it actually drove, read from what `verify-machine` returned and never
  from the table's own length. Totality over the **thirty** declaration sites is carried
  by the census's per-constructor site table, not by cases: four representatives check the
  contents, the table proves all thirty call the declarations constructor, and Task 2 Step
  3 says in the file what that leaves unwitnessed. A census-shaped change gets a check
  total over its census; where this plan cannot make one total, it says so instead of
  implying otherwise.
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

**Files:** none modified. Branch `feat/m7-slice-1`, cut from `main`. A detached scratch
worktree for any measurement that stages an edit, removed at the end.

Every number in §1 was measured at `12c03d9`. If the slice's base has moved they are
re-taken **before** anything is edited; if it has not, they are re-taken anyway, because a
census nobody re-ran is a census nobody checked. Each step below names its command and an
expected result that can fail.

- [ ] **Step 1.** `git log --oneline -1` and
      `git diff --stat <base>..12c03d9 -- src/ test/`.
      **Expected:** the log line names the base; the diff prints **nothing**. Any output
      means §1's numbers describe a different tree and every step below re-measures before
      it is trusted.
- [ ] **Step 2.** Census the emission sites: read `verify.sls` with a paren-balanced
      splitter over every `(make-diagnostic…` form (a `rg` cannot do this — 48 of the 56
      forms span more than one line), classify each by decision 0032 items 3 and 4.
      **Expected, as literals:** `30` declaration-gaining, `12` path-bearing, `14`
      unchanged, `56` total; the intersection of the first two sets is **empty**; the
      twelve path sites' codes are exactly `zero-progress-cycle` 1,
      `non-eof-into-finish` 2, `eof-reachable-stop` 1, `eof-zero-progress-cycle` 1,
      `invalid-span-state` 4, `span-active-at-pause` 1, `span-active-at-exit` 1,
      `inconsistent-span-state` 1.
- [ ] **Step 3.** `rg -o -F <accessor> test/common/*.sps | wc -l` for each of the four
      shipped accessors, and the two whole-record searches.
      **Expected, as literals:** `diagnostic-code` **79**, `diagnostic-node` **45**,
      `diagnostic-edge` **5**, `diagnostic-message` **0**, total **129**;
      `rg -n "equal\? diag|#\(diagnostic|vector 'diagnostic" test/common/*.sps` prints
      **nothing**; `rg -n 'vector-length|vector->list' test/common/*.sps | rg -i diag`
      prints exactly the **two** `diagnostic-census-tests.sps` lines. Widen the search to
      `src/` and `test/support/` as well and record what it finds — F14's boundary is
      `test/common/*.sps` and a scope claim inherits the scope of the measurement behind
      it.
- [ ] **Step 4.** Census the pins: lex every `byte_machine_mutation(` block with a single
      left-to-right scanner that skips `#` comments **and** `[[…]]` bracket arguments
      (neither construct is recognisable without lexing the other — balancing parens from
      `byte_machine_mutation(` truncates the body and reports a false *absent*), keep those
      whose `FILE` is `verify.sls`, and locate each `FIND` in the source.
      **Expected, as literals:** **140** blocks, **0** `FIND`-count mismatches against
      declared `SITES`, and the **23** LABELs of F7 — no more, no fewer. A LABEL in the
      tree that is not in F7's list, or the reverse, is a finding: correct this plan before
      Task 2 begins.
- [ ] **Step 5.** Re-run F7's three-shape prototype in the scratch worktree (the
      `verify-machine` sibling binding, the `:908` `let*` sibling, `make-diagnostic/edge`'s
      fifth argument) and judge all 140 `FIND`s against the result.
      **Expected, as a literal:** exactly **1** not-exactly-once, and it is
      `verify: every :908 finding is labelled \`case\` regardless of which edge produced it`
      at count **0**.
- [ ] **Step 6.** Baseline the suite: `cmake --preset dev && ctest --preset release`, then
      the mutation lane's own totals, filtered for `CMake Error`, `wrong reason`,
      `UNCAUGHT` and `tests passed`.
      **Expected, as literals:** `100% tests passed, 0 tests failed out of 114`; the lane's
      declared `58 passes / 525 mutations`; exit **0**.
- [ ] **Step 7.** Reconcile F2's twelve path sites against the design's **Appendix — the
      `§16.2` ledger**, whose "Path (①)" column is handed to this slice as its checklist
      (design §11: *"Slice ① as the path policy's checklist, and a row a slice cannot follow
      is corrected in place"*). Walk the column row by row.
      **Expected, as a literal:** the rows marked with a path name **8** codes over **12**
      sites, identical to Step 2's set; each row's stated shape (`:898` the cycle; `:899`,
      `:900`, `:907` entry → node; `:908` the EOF walk's stack and entry → source → finish;
      `:909` the EOF walk's stack) is one this slice can produce. A row that disagrees is
      recorded now and corrected in Task 7 — it is an instruction.
- [ ] **Step 8 (judgement, kept separate from the mechanical steps above).** Read decision
      0032's items 3 and 4 against the tree and confirm F4 and F12 reproduce.
      **Mechanical half:** `rg -c "\(make-diagnostic/edge" src/byte-machine/verify.sls`
      prints **2**. **Judgement half:** read `pass-declarations`' span block and confirm
      `dn` and `cn` are bound in the same `let*` the two `invalid-span-callback` arms read,
      and say whether F12's recommendation still looks right to you. Report the judgement
      as a judgement.

**Exit:** the seven mechanical expectations met or this plan corrected where they are not;
Step 8's judgement recorded with its reason.

---

## Task 2 — Tests first: the record, the stamps, the declarations, the paths

**Files:** `test/common/verify-tests.sps`, `test/common/diagnostic-census-tests.sps`.

**How "red" is observed here, honestly.** All four accessors are new, so until Task 3
Step 2 lands the program does not *load* and no case is observed red — an import error, not
a failed comparison. The plan therefore does not claim a red run before Task 3; it schedules
the observation **inside** Task 3, between Steps 2 and 3, where the accessors are bound and
no path is passed yet. For that observation to be a comparison rather than a raise, **every
path assertion in this task reads through a guard**:

```scheme
(define (path-first d) (let ((p (diagnostic-path d))) (and (pair? p) (car p))))
(define (path-last  d) (let ((p (diagnostic-path d))) (and (pair? p) (car (reverse p)))))
(define (path-has?  d n) (let ((p (diagnostic-path d))) (and (pair? p) (memq n p) #t)))
```

A `#f` path then fails by `check-equal` with `got #f` instead of raising in `car`. This is
the same rule the mutation discipline states — prefer the mutation form caught by a failed
comparison over one caught by a raise — applied to the fixture side, and it is what makes
Task 6 Steps 6–8's empty-path mutants comparison catches too.

- [ ] **Step 1 (the "before" half of the invisibility oracle).**
      `ctest --preset release -R 'verify|census|kind-position'` on the **unmodified** tree.
      **Expected, as a literal:** `100% tests passed, 0 tests failed out of 8`. The count
      is the check: "green" cannot distinguish eight lanes from six.
- [ ] **Step 2.** Severity and machine, one case each:
      - a machine with at least three diagnostics from three different passes — every one
        carries `diagnostic-severity` `error` and `diagnostic-machine` the machine's name,
        with a sentinel asserting the **observed** diagnostic count (read from
        `verification-diagnostics`, never from the case's own expectation);
      - `(verify-machine 'not-a-machine)` — one `invalid-shape` diagnostic, severity
        `error`, machine `#f`. The case's comment states why `#f` here is the rule and not
        a placeholder (F5), and that `pass-schema`'s version arm is unconstructible so its
        machine-name answer is right by construction rather than by fixture.
- [ ] **Step 3.** Declarations: one case per declaration family — callback, span, error,
      field — each asserting the whole `diagnostic-declarations` value by `check-equal`;
      plus `invalid-span-callback`'s **two-element** list; plus the `duplicate-branch-key`
      pair (the declaration site carries a list, the callback-node site carries `'()`),
      which is the case that makes the per-site policy visible rather than accidental.
      If F12's recommendation is accepted, the two span `missing-callback-declaration`
      sites carry two-element lists as well — **four two-element sites, not one**; if it is
      overturned, one. The case comment states which disposition it was written under.
      *What this leaves unwitnessed, stated rather than glossed:* four representatives
      check the *contents* at four of thirty sites. Totality over the thirty is carried by
      the census's per-constructor site table (Step 7), which proves every one of them
      calls the declarations constructor — not that each passes the right names.
- [ ] **Step 4.** The eight path-bearing codes, as **one `for-each` over a table of
      (code, fixture, expected-first, expected-last, expected-member)**, not eight
      independent cases — a census-shaped change gets a check total over its census. The
      loop carries a `driven` counter read from what the loop observed and asserted
      **8**; the table's own length is asserted against it, so dropping a row cannot
      shrink the group silently.
      The expected **first** element is the walk's start, which for two kinds is *not* the
      reporting node — a parked callback starts at its pause continuation and a parked
      counted consume at its eof-target (`parked-eof-start`). Decision 0032's Consequences
      record that the design's first draft said "the reporting node" until its review found
      it; the two cases that would have caught it are written here, one per kind.
      The expected **last** element differs per code and is stated per row, not assumed:
      the stop terminal for `eof-reachable-stop`; the **repeated node** for
      `eof-zero-progress-cycle` (see Task 4 Step 1); the reporting node itself for
      `zero-progress-cycle` (its walk starts there, so first = last); the offending edge's
      target for `non-eof-into-finish`'s edge site and the entry for its zero-hop site; the
      reporting node for the four span codes.
- [ ] **Step 5.** The **finding-count** assertion, beside the path and in the same case:
      each path fixture carries one finding that survives an empty-path mutation and one
      that does not, and the case asserts the observed **count** of diagnostics as well as
      the path's shape. This is what separates Task 6 Steps 6–8 (the walk computes no path)
      from the shipped emission-deleting mutants (the finding is gone), which contain them
      by construction: the widening mutant reports the same number with `got #f`, the
      deleting mutant reports one fewer.
- [ ] **Step 6.** For each of the eight, one negative: a fixture one edit away from the
      fault, asserting the code is **absent**. A path assertion on a code no fixture emits
      passes vacuously, and this is what closes that.
- [ ] **Step 7.** The join tie-break fixture (F10): a `t6-join-machine` variant whose two
      EOF successors reach **two distinct stop nodes**, asserting which route the reported
      path names. The distinctness is the whole fixture — one shared stop makes the second
      branch a memo hit and the mutation uncatchable (F10). One case, two directions: the
      path under the shipped `>=`, and the case's comment naming what `>` would report.
- [ ] **Step 8.** The census's path row and per-constructor site table. Both derived where
      they can be: the constructor set from every `define` beginning `make-diagnostic`
      (already shipped), the **path-carrying** subset from those whose parameter list
      contains `path`, the per-site constructor from the walk. The path-bearing **code**
      set is declared, because it is the policy of decision 0032 item 4 and not a property
      of the source — the comment says so and cites it.
      **Expected, as literals, inside the test:** the per-constructor site counts
      `make-diagnostic` **14**, `make-diagnostic/declarations` **30**,
      `make-diagnostic/path` **11**, `make-diagnostic/edge` **1**, summing to **56**; the
      path-carrying sites **12**; the constructor count **4**.
- [ ] **Step 9 (before any label is committed).** Every check label this task adds — count
      them; it is roughly **25**, not the eight path cases alone — is embedded in every
      shipped pin's literal core and searched. A new label that *contains* a shipped pin's
      regex makes that pin resolve to two records of its own mutant's output, and the lane,
      the mutation runner and the two-direction sweep are all green while it happens.
      **Expected, as a literal:** **no hit**, for every new label against every pin.

**Exit:** every case exists; every loop asserts an observed count; Step 1's `8/8` and
Step 9's "no hit" recorded.

---

## Task 3 — The source change: the record, the constructors, the stamp, the declarations

**Files:** `src/byte-machine/verify.sls`.

- [ ] **Step 1.** The record: `(vector diagnostic-tag code node message edge severity
      machine declarations path)`, slots 0–8. Four accessors at 5–8, added to the `export`
      list beside the four shipped ones.
- [ ] **Step 2.** Four constructors, each building its vector **inline** (F3):
      `make-diagnostic` (3 args), `make-diagnostic/edge` (5 — F4),
      `make-diagnostic/declarations` (4), `make-diagnostic/path` (4). Unfilled slots are
      `#f` for severity, machine, edge and path, and `'()` for declarations. The comment
      above them states the census identity that forbids delegation and cites F3's measured
      record (`expected 61, got 59`), so the next author does not "simplify" it.
- [ ] **Step 3 (the TDD red, and it is a comparison).** Run
      `ctest --preset release -R 'verify|census|kind-position'`.
      **Expected, as literals:** the severity, machine and declarations cases of Task 2
      Steps 2–3 **pass**; every path case of Steps 4–7 **fails**, each with `got #f` from
      the Step-2 guards; the failing-check count equals the number of path assertions
      written, stated here as a number when Task 2 lands. This is the red that proves the
      cases test something, and it is observed before any path is computed.
- [ ] **Step 4.** `stamp-diagnostic` (a name that does **not** begin `make-diagnostic`, or
      the census counts every call to it as an emission site), and `verify-machine`'s
      sibling binding (F5, F8).
      **Expected, as a literal:**
      `git diff -U0 -- src/byte-machine/verify.sls | rg -c '^[+-] *\(pass-(fields|declarations|spans|sequence-ambiguity) machine\)'`
      prints **0** — the pass list did not move, which is what keeps four pins alive.
- [ ] **Step 5.** The thirty declaration sites, by code, working Task 1 Step 2's census as a
      checklist. `invalid-span-callback`'s two carry two names; the two span
      `missing-callback-declaration` sites carry two under F12's recommendation; the
      callback node's `duplicate-branch-key` carries `'()`, with its reason at the site.
- [ ] **Step 6 (the "after" half of the invisibility oracle).** Run
      `ctest --preset release -R 'verify|census|kind-position'` again, and
      `git diff -U0 -- test/common/verify-tests.sps | rg -c '^-[^-]'`.
      **Expected, as literals:** the diff count is **0** — not one shipped line was
      *removed or altered*, only added, so the 129 accessor reads pass unedited; the
      kind × position lanes are **green**, which is the `(cons 'SYM …)` check (F13); the
      only failing checks are the path assertions of Step 3, unchanged in number.
- [ ] **Step 7.** Run the census.
      **Expected, as literals:** thirty codes over fifty-six sites; `(unreachable-node 1)`;
      the per-constructor table `14 / 30 / 11 / 1`; the derived constructor count **4**.

**Exit:** Step 4's `0`, Step 6's `0` and green matrix, Step 7's four literals.

---

## Task 4 — The source change: four walks, four paths

**Files:** `src/byte-machine/verify.sls`. Same commit as Task 3.

- [ ] **Step 1. `eof-terminal`.** There are **six** verdict-producing sites, not two —
      `walk`'s `'cycle` arm, `dispatch-arm`'s `'default-error`, and `classify`'s
      `'unresolved`, `'finish`, `'error` and `'eof-reachable-stop` — and each is answered
      explicitly, including the ones whose verdict `pass-eof-execution` never reports.
      **Expected, as a literal, before the edit:**
      `rg -c "'cycle|'default-error|'unresolved|'finish\)|'error\)|'eof-reachable-stop" src/byte-machine/verify.sls`
      within `eof-terminal`'s range names all six; a seventh is a finding.
      Three decisions this step makes rather than leaves:
      - **One helper, not six `(reverse path)`s.** All six answers go through a single
        internal `(define (verdict v path) (list v (reverse path)))`. Six copies would put
        six occurrences of `(reverse path)` in the file, and Task 6 Step 4's mutation
        anchors on exactly that text — a six-site pin is not a pin, and the Global
        Constraint asserting `SITES` at 1 is what catches it. The helper's name must not
        begin `make-diagnostic`.
      - **A two-element `list`, never `(cons 'verdict path)`** (F13). Design §6 currently
        says `(verdict . path)`; that sentence is stale and Task 7 corrects it.
      - **The cycle arm carries the repeated node.** `walk`'s `path` does not contain
        `name` at the point `(memq name path)` fires, so the answer is
        `(verdict 'cycle (cons name path))` — first element the walk's start (uniform with
        every other code, decision 0032 item 5), last element the **repeated** node, which
        therefore appears twice. That is "around the cycle" with item 5's start rule kept,
        and it is the expected last element Task 2 Step 4's table states for
        `eof-zero-progress-cycle`.
      The memo stores the pair, so `((assq name done) => cdr)` keeps its text;
      `eof-verdict-join` ranks `(car a)` / `(car b)` and returns the whole pair, which is
      what keeps `join-over`, the two counted-join pins and the memo pin intact;
      `dispatch-arm` keeps its signature. `pass-eof-execution` binds the answer and `case`s
      on its car.
- [ ] **Step 2. `self-cycle`** (was `reaches-self?`, F9): the frontier carries
      `(name . route)` — a variable car, safe under F13 — and the success arm returns the
      cycle from the reporting node back to itself, so first = last. A self-loop is the
      two-element path `(n n)`, the shortest case and the one Task 2 Step 4's table names.
      Correct the three `verify.sls` sites and `machine-gen.sls`'s comment.
      **Expected, as a literal, after the edit:** `rg -c reaches-self src/ test/` prints
      **0**.
- [ ] **Step 3. `reach-from`** returns an alist of `(name . parent)`, `#f` at the entry;
      `byte-reached` becomes `(map car (reach-from m node-out-targets))`; the `:908` block
      binds the alist as a `let*` sibling of `br908` (F7, measured) and builds the path as
      entry → source → the offending edge's target; the zero-hop entry clause carries the
      one-element path. **Two live comments in `reach-from`'s header are now false and are
      corrected in place**: "Returns the reached node names", and "Since decision 0031 it
      has ONE caller, `byte-reached`" — this step gives it a second.
- [ ] **Step 4. `pass-spans`** binds a parent map from `(span-flow m)`'s edge list before
      the fixpoint (F11); `span-node-diagnostics` gains a third parameter; the `top` arm and
      the six transfer sites carry `(parent-path parents (node-name n))`.
      **Expected, as a literal:** `git diff -U0 -- src/byte-machine/verify.sls` contains no
      hunk overlapping `span-flow`'s definition — `span-flow` is not edited at all.
- [ ] **Step 5.** `parent-path` and `edge-parents`: one shared walk-back and one BFS, each
      with a comment naming which call sites guarantee membership (the `:908` block passes
      only `br908` members; `pass-spans` passes only nodes that received a state, which are
      the closure from the entry, F11). A guard that cannot guard is not added.
      **Expected, as a literal:** the mutation lane's `SITES` assertions still pass, i.e.
      no new line duplicates a shipped `FIND` — Task 5 Step 4's run is what reports it,
      in both directions.
- [ ] **Step 6.** `ctest --preset release -E scheme-mutation`.
      **Expected, as literals:** `100% tests passed, 0 tests failed out of 113`;
      `git diff --stat main..HEAD -- test/fixtures` prints **nothing** (no golden moved);
      `git diff --stat 5ac363a..HEAD -- src/ ':!src/byte-machine/verify.sls'` prints
      **nothing** (design §4.9's gate).

**Exit:** Step 2's `0`, Step 4's no-hunk, Step 6's three literals.

---

## Task 5 — The pins that move, and the survivor

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`. Same commit.

**The survivor is re-measured HERE, before this task's lane run, and the reason is a
scheduling fact:** `MutationRunner.cmake` raises `SEND_ERROR` inline for a declared
survivor the specification catches — *"the recorded limitation is stale: remove
EXPECT_SURVIVES and update the decision record that cites it"* — so if F6's reopening
condition has fired, a lane run that still carries `EXPECT_SURVIVES` fails, and an
implementer reading a green expectation would treat a correct signal as breakage.

- [ ] **Step 1.** Re-anchor the thirteen emission-site pins of F7 by **LABEL**, reading
      each `FIND` with its `REPLACE` and stating what single decision separates them. Five
      of the thirteen `REPLACE`s contain a `make-diagnostic` call of their own
      (`the duplicate-field diagnostic…`, `the nonportable-field diagnostic…`,
      `a callback node naming no declaration…`, `an emission site is relabelled…`,
      `a merge disagreement is not reported`) and move with their `FIND`s; a `REPLACE` left
      at the pre-slice constructor name still applies, still exits nonzero, and pins
      nothing.
- [ ] **Step 2.** Re-anchor `verify: every :908 finding is labelled \`case\` regardless of
      which edge produced it`: its `FIND` is `(car re))` — the argument **with the form's
      closing paren** — and the fifth argument moves that paren onto a new line.
      **Expected, as a literal:** `(car re)` occurs **1** time in the post-edit source, so
      the re-anchor is unambiguous; the `REPLACE` loses the same paren.
- [ ] **Step 3.** Regenerate the eight zero-progress `REPLACE`s **from the post-edit
      source** (F9), mechanically: take the new block, delete the named disjunct, and diff
      the generated text against what the `REPLACE` declares.
      **Expected, as a literal:** the diff prints **nothing**, eight times. Never
      hand-edited from the old text, which is how a `REPLACE` silently starts changing two
      things. `verify: the zero-progress REPORT set excludes the callback kind` stays in
      the census lane's pass — a mutation is witnessed only by its own SPEC lane's program.
- [ ] **Step 4.** Re-anchor the two `classify` pins (`an eof-target cycle is classified as
      a finish terminal`, `an EOF-reachable stop terminal is accepted`), each `REPLACE`
      becoming the pair form so the mutant still changes exactly one thing.
- [ ] **Step 5 (the survivor, F6).** Re-measure
      `verify: the EOF walk keeps no completed-set` against this tree by staging its
      `REPLACE` and running `verify-tests.sps` through the real launcher.
      **Two dispositions, both written in advance:**
      - **caught** (exit ≠ 0) — remove `EXPECT_SURVIVES`, add `EXPECT_STATUS` and a pin on
        the measured record, and replace the reason with a note recording that the
        reopening condition fired and which case separates it. `MutationRunner.cmake`'s own
        error says to "update the decision record that cites it": decision 0021 item 2 is
        the record, and Task 7 carries the note.
      - **still surviving** (exit 0) — the reason gains a dated note saying the condition
        fired, what was tried, and why no fixture separated it. It is not inherited
        silently either way.
      **Expected, as a literal:** the staged run's exit status, recorded, and the block
      edited to match it.
- [ ] **Step 6.** Run the mutation lane.
      **Expected, as literals:** no `CMake Error`, no `wrong reason`, no `UNCAUGHT`, no
      stale-survivor `SEND_ERROR`; exit **0**; `58 passes / 525 mutations` — this task adds
      no mutation and moves no count.
- [ ] **Step 7.** For each of the twenty-three, re-measure the `got` it pins by staging the
      mutant in a scratch copy and running the real launcher. A `got` digest is never
      recomputed by hand.
      **Expected, as a literal:** twenty-three measured values, written **into the suite
      file** as the pins themselves — not into a session note, which is git-ignored and is
      therefore not a record.

**Exit:** Step 6's `58 / 525` and exit 0; twenty-three pins carrying measured `got`s;
the survivor's block matching its measured outcome.

---

## Task 6 — The pins this slice adds

**Files:** `test/support/cmake/SchemeMutationSuite.cmake`. Same commit.

Eleven mutations. Each names its **pass**, its **SPEC lane** and its **anchor**; the
`EXPECT_OUTPUT_MATCHES` literal is measured from the staged mutant and is the tree's to
supply. Unless stated otherwise a mutation goes into the existing `verify.rejections`
pass, before its `_run`, with `EXPECT_STATUS 1`.

- [ ] **Step 1.** *The stamping `map` is dropped.* Anchor: `verify-machine`'s
      `(map (lambda (d) (stamp-diagnostic d nm)) ds)` → `ds`. Severity and machine both
      read `#f`. Witness: Task 2 Step 2's two cases.
- [ ] **Step 2.** *The machine stamp answers a constant.* Anchor:
      `(and (machine? machine) (machine-name machine))` → `(and (machine? machine) 'wrong)`
      — **not** `#f`, which would make this mutant's whole record set a subset of Step 1's
      and subsumed by construction. With a wrong *name* its `got` differs from Step 1's
      `got #f`, so one record separates them.
- [ ] **Step 3.** *Severity is a warning.* Anchor: `'error` in `stamp-diagnostic` →
      `'warning`. Separable from Step 1 for the same reason.
- [ ] **Step 4.** *The EOF path is not reversed.* Anchor: `eof-terminal`'s `verdict`
      helper, `(reverse path)` → `path`. Pins decision 0032 item 5's "starting at the
      walk's start" as a first/last comparison. **`SITES` must be 1** — this is why Task 4
      Step 1 routes all six answers through one helper.
- [ ] **Step 5.** *The EOF verdict join keeps the right operand on a tie.* Anchor:
      `eof-verdict-join`'s `>=` → `>`, on Task 2 Step 7's fixture. Measured at plan time:
      this mutant is **uncaught in all nine** verify-driving programs today (F10), so the
      pin closes a real gap rather than restating an existing catch. Expected after the
      fixture lands: caught, with the `got` naming the route through the *second* stop node.
- [ ] **Step 6.** *The zero-progress cycle path is empty.* Anchor: `self-cycle`'s success
      arm → `'()`. Separated from the shipped `verify: zero-progress detection never fires`
      by Task 2 Step 5's finding-count assertion: this mutant reports the same count with
      `got #f`, the deleting mutant reports one fewer.
- [ ] **Step 7.** *A byte parent is not recorded.* Anchor: `reach-from`'s
      `(cons name parent)` → `(cons name #f)`, emptying `non-eof-into-finish`'s path.
- [ ] **Step 8.** *A span parent is not recorded.* Anchor: `edge-parents`' equivalent,
      emptying the four span codes' paths. Kept separate from Step 7 because they are two
      maps and two decisions, and each reddens a family the other does not.
- [ ] **Step 9.** *A declarations list loses its second name.* Anchor:
      `invalid-span-callback`'s `(list (span-declaration-name sd) dn)` → the one-element
      list. Witness: Task 2 Step 3's two-element case.
- [ ] **Step 10.** *A path-bearing site is made pathless.* Anchor: one
      `make-diagnostic/path` call → `make-diagnostic/declarations`. **The two constructors
      have the same arity**, so this compiles and the site's code stays path-bearing while
      its constructor stops carrying a path — which is precisely the half of decision 0032
      item 6 that exists "so a new site under a path-bearing code cannot ship pathless".
      **SPEC: the diagnostic-census lane**, in its existing pass, because the census's path
      row is this mutation's only witness and a mutation is witnessed only by its own SPEC
      lane's program.
- [ ] **Step 11.** *A path-bearing site is relabelled to a non-path code.* Anchor: the
      `eof-reachable-stop` site's code → a non-path code. This reddens the row's other
      half ("no other site passes a path") and is separable from the shipped
      `verify: an emission site is relabelled with another existing code`, whose `REPLACE`
      relabels *within* the path set and leaves the row green. **SPEC: the
      diagnostic-census lane.**
- [ ] **Step 12.** For every new mutation, count how many cases it fails and whether they
      fail identically. **Expected:** a mutation failing most of the suite with the
      identical record is a crash, not a discrimination — re-shape it before pinning it.
      Record the failing-case count beside each pin.
- [ ] **Step 13.** Re-measure `EXPECTED_MUTATIONS` from the harness.
      **Expected, as a literal:** 525 + 11 = **536**; `EXPECTED_PASSES` stays **58**.
      Neither of Step 5-in-Task-5's dispositions moves the count — an `EXPECT_SURVIVES`
      block is an ordinary mutation and is already counted. The arithmetic is a prediction
      the tree overrides.
- [ ] **Step 14.** The two-direction sweep against a control at the slice's base: every pin
      judged against every **other** mutant's captured output, and every **new** pin judged
      against every existing mutant.
      **Expected, as a literal:** **0** collisions at HEAD that are absent at the control.
      Any residue that is genuinely subsumed is recorded **in the suite file beside the
      pin, by mutation LABEL** — the session ledger is git-ignored, so an obligation left
      there has not been recorded.
- [ ] **Step 15.** Count each pin's matches in its **own** mutant's `FAIL ` records with a
      DOTALL `findall`. **Expected, as a literal:** **1**, for every pin.
- [ ] **Step 16.** Commit Tasks 2–6 as one commit:
      `feat(verify): the diagnostic record carries §16.4's seven fields, and eight codes carry a path`.
      The body names the verdict-invariance result, the census totals, the twenty-three
      pins by LABEL, the eleven added, the survivor's disposition and the sweep numbers.

**Exit:** the lane green at `58` passes and the measured mutation count; Step 14's `0`;
Step 15's `1` for every pin; one commit.

---

## Task 7 — Both ends, and the status surfaces

**Files:** `docs/decisions/0032-…md`, `docs/decisions/0021-…md` (only if Task 5 Step 5
caught the survivor), `docs/plans/milestone-7-design.md`,
`docs/plans/byte-machine-implementation-plan.md`, `CHANGELOG.md`, `README.org`.

**The stale instructions, enumerated, because "corrected in place" without a list is how
one gets missed:**

| Where | What it says | Why it is stale |
|---|---|---|
| 0032 item 3 | "`make-diagnostic` and `make-diagnostic/edge` keep their arities" | F4 |
| 0032 item 3 | the two span `missing-callback-declaration` sites' declaration list | F12, if accepted |
| 0032 item 4 | "`reaches-self?` gains parent links" | renamed, F9 |
| design §4.2 item 3 | "`reaches-self?` gains parent links" | renamed |
| design §6 | "`reaches-self?` and `reach-from` gaining parent maps" | renamed |
| design §6 | the walk returns "`(verdict . path)`" | a cons pair is F13's trap; 0032 item 4 says a two-element `list` |
| design §6 and §4.2 | "122 accessor reads" (twice) | 129 at this base, F14 |
| `verify.sls` `reach-from` header | "Returns the reached node names"; "has ONE caller" | Task 4 Step 3 |
| `machine-gen.sls:17` | names `reaches-self?` | renamed |

- [ ] **Step 1.** Decision 0032: correct items 3 and 4 in place per the table. Add one
      dated note at the foot naming every correction and its reason, a bullet at the header
      saying a later note reached back into the record, and a one-line marker at each
      corrected item. The pointer routes; it does not restate the conclusion.
      **The Context is not touched** — its numbers describe `50516af` and are evidence;
      where this slice measured differently (129 vs 122), the note says so and the Context
      stays.
      **Expected, as a literal:** `git diff -- docs/decisions/0032-*.md | rg -c '^-[^-]'`
      prints the number of corrected instruction lines and **no line from the Context**.
- [ ] **Step 2.** The design: §4.2 item 3, §6 and the Status header, corrected in place per
      the table, with the amendment indexed newest-first in the blockquote and naming the
      sections it amends. The record and the design fail independently and the design is
      where the record got two of these sentences.
- [ ] **Step 3.** The design's **Appendix ledger**: correct in place any "Path (①)" row
      Task 1 Step 7 found the slice could not follow. If every row held, say so in the
      amendment — a checklist that was worked and held is a result.
- [ ] **Step 4.** The parent plan: **append** to `## Dated dispositions` (which begins at
      `:1802` and whose own header says it never shifts a line above it), never insert.
      Record what `§25:1616` now has in the tree and what `§25:1625` still owes — the
      negatives for the twenty-two non-path codes are Slice ④'s catalogue.
      **Expected, as literals:**
      `git diff -U0 -- docs/plans/byte-machine-implementation-plan.md | rg -c '^@@'`
      prints **1**, and that hunk's old-side start line is **≥ 2491** (the file's length at
      this base) — an append *inside* the dispositions section still shifts every line
      below it.
- [ ] **Step 5.** `CHANGELOG.md`: the `[Unreleased]` preamble **and** an entry under
      `### Added` (`:102`) naming `diagnostic-severity`, `diagnostic-machine`,
      `diagnostic-declarations` and `diagnostic-path` — the precedent is `diagnostic-edge`'s
      own entry at `:850`, and design §6's Oracle names the CHANGELOG explicitly. Then
      `README.org`'s status paragraph, the surface no step names and the one whose drift is
      unbounded.
- [ ] **Step 6.** Design §6's Oracle, discharged item by item and recorded:
      *Shape only* — Task 3 Step 6's `0`; *Total* — the census's path row green at twelve
      and red under Task 6 Steps 10 and 11 (both halves, not one); *Public* — the four
      accessors exported, the CHANGELOG entry of Step 5, and `reserved-drift-tests.sps`
      green. That last is satisfied by the 114-lane run and by inspection: it compares
      `(byte-machine runtime)`'s export set against `compile.sls`'s reserved member and
      never imports `(byte-machine verify)`. Say that in one line rather than leaving an
      oracle item open.
- [ ] **Step 7.** Commit: `docs: Slice ① — the record widening's records, and the four
      status surfaces`.

**Exit:** the table's nine corrections made; Step 1's and Step 4's literals; the Oracle's
three items each discharged with its evidence.

---

## Task 8 — The whole-branch review, and the close

- [ ] **Step 1.** Run the review in a **detached worktree at the branch head** — never
      `isolation: worktree`, which checks out `main` and would report on a tree without any
      of this slice's work, with plausible line numbers. Subagents told they may edit to
      test a hypothesis will edit whatever tree they are given, and a `ctest` run alongside
      such a workflow reports numbers that are not about your tree.
- [ ] **Step 2.** Put `AGENTS.md`'s sentence in the reviewer's prompt **verbatim**: *check
      what this claims the code or the spec DOES against the code and the spec, not against
      the prose.* That sentence caught three false supporting reasons in Milestone 4's Gate
      0 and the retirement error in Slice ⓪; the reviews that lacked it caught none.
- [ ] **Step 3.** Ask the three questions this slice's shape invites: does any verdict move;
      is every claim in a new comment true of the code beside it; and what did decision
      0032 decide that this tree does not contain.
- [ ] **Step 4.** Re-run every count the documents quote, from the tree rather than from a
      commit message. **Expected, as a literal:** every quoted number reproduced, or a
      correction made — a count restated in two places will disagree with itself.
- [ ] **Step 5.** Fold the findings, then re-run **Tasks 5, 6 and 7's** measurements — a fix
      wave moves counts, a sweep run once at the end is a sweep that did not see the fixes,
      and Step 4 edits documents whose citations Task 7 Step 4 had already resolved.
- [ ] **Step 6.** Re-open every cross-document `file:line` as the **last** step before the
      final commit, after the fix wave. **Expected, as a literal:** N citations re-opened,
      **0** mismatches. A citation into a file the same commit also edits is stale on
      arrival, and this branch edits four such files.
- [ ] **Step 7.** Open the PR. Label it `ci` only when the branch is final; a later push
      does not re-run the labelled job. **PR #88's two-run Chez-cache verification is still
      unperformed** — Slice ⓪ merged without the label at the owner's word — so this is the
      first PR that can discharge it, and its body says whether it did.
- [ ] **Step 8.** The closing ritual on the owner's go-ahead: squash-merge, fast-forward
      local `main`, delete the branch locally and remotely, and reflect — durable facts to
      memory, project standards to `AGENTS.md`, anything the code should say about itself
      into a comment at the site.

---

## Verification

Run at the head of the source commit and **again after the review's fix wave**.

1. `cmake --preset dev && ctest --preset release` — `100% tests passed, 0 tests failed out
   of 114`, both Chez modes.
2. `ctest --preset release -E scheme-mutation` — `0 tests failed out of 113`.
3. The mutation lane — `58` passes and the measured mutation count (predicted **536**),
   filtered for `CMake Error`, `wrong reason`, `UNCAUGHT`, stale-survivor and
   `tests passed`, plus the exit status, which is the only summary a run that then fails
   cannot print.
4. The diagnostic census — thirty codes over fifty-six sites, `(unreachable-node 1)`, the
   per-constructor table `14 / 30 / 11 / 1`, twelve path-carrying sites, four constructors.
5. The kind × position matrix — green, pruning count **3** (this is the `(cons 'SYM …)`
   check).
6. `git diff --stat 5ac363a..HEAD -- src/ ':!src/byte-machine/verify.sls'` — **no output**.
7. `git diff --stat main..HEAD -- test/fixtures` — **no output**.
8. The two-direction pin sweep against a control at the base — **0** introduced collisions;
   every pin matching **exactly once** in its own mutant's `FAIL ` records.
9. Every cross-document `file:line` re-opened — **0** mismatches. This item runs last,
   after items 1–8 and after any fix wave, because the fixes move the lines.

## Exit

- The record carries `§16.4:937-943`'s seven fields in nine slots; `diagnostic-severity`,
  `diagnostic-machine`, `diagnostic-declarations` and `diagnostic-path` are exported from
  `(byte-machine verify)` and named in `CHANGELOG.md`'s `### Added`.
- Each of the eight path-bearing codes has a positive case asserting its path's first
  element, last element and membership — driven by one loop with a sentinel reading the
  observed count — and a negative case naming the code it must not emit.
- The census's path row is total over the fifty-six sites and derived on both halves it can
  derive; **both** its directions are pinned (a path site made pathless, and a path site
  relabelled out of the set), so a new site under a path-bearing code cannot ship pathless.
- No verdict moved: `git diff -U0 -- test/common/verify-tests.sps | rg -c '^-[^-]'` is
  **0**, so the 129 shipped accessor reads passed with nothing edited to accommodate the
  widening.
- The twenty-three moved pins are re-anchored by LABEL with their `REPLACE`s, the eleven
  new pins are measured, and the declared survivor is disposed rather than inherited.
- The design's §16.2 ledger was worked as the path policy's checklist and every row it
  carries is one the tree can follow.
- Decision 0032's corrected instructions carry dated notes; the design, the parent plan,
  `CHANGELOG.md` and `README.org` all say what the tree says.
