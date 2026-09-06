# Milestone 6 — Slice ① (the thirteenth kind, end to end) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Authority: [decision 0030](../decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md)
(the executor contract, items 1-4; the verifier's two answers, items 5-7), then
`milestone-6-design.md` §6 (the slice), §4.1-§4.10 (the resolutions §6 builds) and
its Appendix (the per-kind census, an instruction), then the parent plan:
`§25:1597-1603` (scope), `§25:1607-1609` (exit), `§9.1:311` (the constructor),
`§10.6:596-604` (the six sentences of semantics), `§11.4:652-654`, `§12.4:725`,
`§12.7:769-771`, `§15:872`, `§16.2:903`, `§16.2:908-909`, `§16.2:913`, `§19.2:1013`,
`§22.3:1254`, `§22.5:1278-1289`.

This slice adds **one node kind** — counted consume, `(make-counted-consume-node
name field next eof-target source-label)` — to every library, both executors, the
emitter, and every census in the tree. It discharges five of `§25`'s seven scope
bullets (`:1597`, `:1598`, `:1601`, `:1602`, `:1603`), exit criteria `:1607` and
`:1609` whole, and `:1608`'s **field, cursor and offset** clauses; `:1599`,
`:1600`, `:1608`'s **fragment** clause and `:1609`'s span variant are Slice ②'s
(design §7), and this plan says so where each boundary lies.

Everything below was measured at **`e81fdc4`** (`main` after PR #76 = `0247ece`,
Gate 0, and PR #77 = `e81fdc4`, Slice ⓪): `release` **108/108**; Scheme mutation
suite **55 passes / 483 mutations**; the diagnostic census **30 codes over 55
sites**. Every `§N:LINE` was resolved by opening the parent plan at that line.
Every `file:line` names its construct as well, because Task 1 moves every line
below its first edit in `ir.sls` and `verify.sls`, and no tool here notices —
a `file:line` is where to start reading, the construct name is the citation.

---

## 1. Thirteen findings that shape the work

The design was measured at `b470665`; the tree moved twice since (Gate 0 added
records only; Slice ⓪ added `node-source-label`, the names library, and label
checks), and three read-only measurement passes over `e81fdc4`'s predecessor
found the following. Each changes a task below, and where a finding contradicts
the design it is the design that is corrected in place (Task 5), because the
appendix is an instruction.

### F1 — `eof-successors` has no arms to add one to

Design §4.2 item 2 and decision 0030 item 5 say `eof-successors` "answers
`(list next)` for the kind". Measured: `eof-successors` is a one-line alias,
`(define (eof-successors n) (zero-width-successors n))` (`verify.sls:854`), with
no per-kind dispatch. "An arm" means giving it one: a `cond` whose first arm is
the kind and whose `else` is the shipped alias body. Both of its consumers —
`classify`'s zero-width `or` arm (`:883`, the `join-over (eof-successors n)`
call) and pass 7's `eof-step` (`:1542`) — read it unchanged, which is the "one
fact, two consumers" property 0030 item 5 rests on. `eof-step`'s comment
(`:1537-1541`), "`eof-successors` answers `'()` for every input-reading one",
becomes false at this commit and is corrected in place. `join-over` raises on an
**empty** name list (`:878-879`, "empty zero-width join"); the kind's arm always
hands it a one-element list, so the raise is unreachable from this kind, and the
comment at the new `classify` arm says so.

### F2 — where the thirteenth disjunct goes decides how many pins move

`node?`'s closing two lines are the FIND of **six** shipped mutations (by LABEL:
"ir: node? does not admit an integer-accumulate node", "… a field action",
"… a callback node", "… a span-start node", "… a span-end node", and the census
ratchet "ir: node? admits a kind the matrix's table does not cover"), and the
zero-progress REPORT set's predicate list (`verify.sls:745-752`) is inside
**seven** multi-line FINDs ("verify: zero-progress detection never fires",
"… a pause-only zero-progress cycle is not flagged", "… a self-targeting sequence
node is not reported …", "… the zero-progress REPORT set excludes the zero-width
kinds", "… excludes the accumulate kind", "… excludes the callback kind",
"… excludes the span kinds"). The precedent (Milestone 5's three kinds) appended
each new predicate after the last and re-anchored every affected pin **FIND
together with its REPLACE**; this slice does the same, and Task 1 lists the
re-anchors by LABEL. Also moving: `classify`'s accumulate arm pin ("verify:
eof-terminal's classify loses its accumulate arm and raises out of
verification") whose FIND includes the `else` line, so the kind's arm goes
**before** the accumulate arm and that FIND stays at one site;
`parked-eof-start`'s only pin ("verify: a parked callback is classified as if the
walk had flowed through it"), whose FIND is the construct's whole body — it is
re-anchored whatever shape the new arm takes; and the reached-declaration walk's
kind list `'(dispatch accumulate)` in `compile.sls:612`, pinned in the
`differential.field` pass as "compile: only dispatch states are credited with
consuming the default EOF declaration".
Every `SITES` in the suite is 1 and the runner fails a FIND at 0 or 2 occurrences
(`MutationRunner.cmake`, the occurrence check), **inside the mutation lane at that
pass's `_run`** — never at configure.

### F3 — one accumulate constructor line is a duplication trap

`ir.sls:430`, `    (unless (or (eq? eof-target #f) (symbol? eof-target))`, is
pinned ("ir: an accumulate node's eof-target is unchecked") and is the **only**
line in `ir.sls` with that operand order; `make-byte-dispatch-node` and
`make-sequence-dispatch-node` write `(or (symbol? eof-target) (eq? eof-target #f))`.
A counted-consume constructor that copies the accumulate line verbatim takes that
FIND to two occurrences. The new constructor writes the dispatch order; that
line is pinned once too ("ir: make-sequence-dispatch-node accepts a malformed
eof-target"), but by a **two-line** FIND that includes the following
`byte-machine-contract-violation` line naming `make-sequence-dispatch-node`, so a
third copy of the first line alone leaves that FIND at one site.

### F4 — the emitted arm cannot call `render-exhausted-preamble`, and must not re-render its lines

Design §4.5 says so and the measurement confirms the shape: `render-exhausted-preamble`
(`compile.sls:269`) opens with `((id) (if (>= pos end) (if finish? …`, and the
counted arm's zero-count test comes **first** (0030 item 1). The arm is a
`cond` with three clauses — zero count, exhausted, commit — rendered from strings
that share no line with the preamble, with `loop-tail` (`:167`) or with the
accumulate arm's tails (all pinned; `rg -n -F` each emitted line against the
suite before committing). The zero-count clause renders through `zero-width-jump`
(`:240`) — a **call**, so its one line of text stays one site.

### F5 — the runtime's finish arm has no factored EOF-route local yet, and `route-byte-step!` advances one byte

Design §4.5 says the finish arms share the EOF-route body "through a factored
local". Measured: the `(accumulate dispatch)` arm of `parser-finish-op!`
(`runtime.sls:1310-1317`) carries the body **inline** — the `(op 'eof-target node)`
hop, else the default-EOF error result. Task 2 factors it into a local the
`(accumulate dispatch)` arm and the new `((counted-consume) …)` arm both call;
the accumulate/dispatch arm's CALL stays its own line. And `route-byte-step!`
(`:873`) advances exactly one byte — `(+ 1 (parser-offset parser))`, `(loop (+ pos 1)
'boundary)` — so the bulk commit is new code in the feed arm, not a call to it.
Before editing either, `rg -n -F "((accumulate dispatch)"` and `rg -n -F
"route-byte-step!"` against the suite: every FIND that overlaps a moved line is
re-anchored with its REPLACE.

### F6 — the both-lane precedent is `field-access-tests.sps`, not a lane that does not exist

There is no `differential-accumulate-tests.sps`. The accumulate golden lane
(`determinism-accumulate-tests.sps`, spec `determinism.accumulate`) is
generated-lane only, and the both-lane accumulate coverage rides
`field-access-tests.sps` (spec `differential.field`: `emit-and-load` at `:79`,
`acc-mach` at `:612`, `acc-lanes` at `:627`, `feed-split` at `:713`). The newest both-lane
harness shape is `differential-span-tests.sps` (`generated` `:116`, `make-lane`
`:161`, `rfields` `:169`, `run` `:177`, `both` `:204`). The new program,
`test/common/differential-counted-tests.sps`, copies the span lane's shape — one
script runner, both lanes, a tuple projection through `project-error` — and gets
its **own** CTest registration pair and its own mutation pass, because a mutation's
SPEC is a label for the pass's verify command and a mutation filed under another
program's pass reads as UNCAUGHT.

### F7 — the census literals that move, by name

`kind-position-census-tests.sps`: "the same twelve kinds" (S2, `:440`) and "and
there are twelve of them" (S2b, `:494`) become thirteen — **both are pin regexes**
("ir: node? admits a kind the matrix's table does not cover" expects `the same
twelve kinds -- expected`; "ir: node-source-label loses an arm" expects `and there
are twelve of them -- expected 12, got 11`), so both pins re-anchor their
EXPECT_OUTPUT_MATCHES in the same commit; "every mapped position was looked up"
17 → **18** (`next` gains `count-next`); "position-table is exactly 17
role-carrying + 4 unlabelled" 21 → **23** (18 + 5; the unlabelled list gains
`count-eof-target`); "and twenty positions have one, four of them twice" → 22 + 4
(two self rows); "twenty dangling cells driven" → **22**; "thirteen constructor
refusals" → **14** (a `#f` `next`); "three legally-absent EOF routes" → **4**;
"exactly three cells prune the sink" — **re-measured, expected unchanged** (only
terminal kinds at the entry prune the sink). `diagnostic-census-tests.sps`:
`(invalid-field-operand 6)` → **7**, total 55 → **56**. `member3-drift-tests.sps`:
"nine checked" / "all nine emitted" → **ten** (`n`). `position-kind-tests.sps`:
"seven cases ran" / "fourteen drives observed" → **9 / 18**. `verify-tests.sps`:
"all seven kinds driven" (twice) and "seven kinds driven" → **eight**.
`ir-tests.sps`: "twelve kinds driven" and "and the table has twelve rows" →
**thirteen**. `normal-ir-tests.sps`: the
layout-walk fixture list (`:793`) does not include `acc-machine` — accumulate has
its own eleven-slot case — so the counted machine gets its own case on that
precedent.

### F8 — `count-next` is a byte position and not an EOF one; the appendix row says otherwise

Design §6 says "`count-next`: a byte position and **not** an EOF one — the host's
`#f` eof-target keeps a byte-reachable counted consume out of the parked set".
The appendix's test-side row says "`count-next` (byte **and** EOF)". Derived
under 0030 item 6 against the shipped parked set: the cell's host is a dispatch
with a `#f` eof-target, the placed counted consume has a `#f` eof-target and is
not the entry, so it is in neither `§16.2:909` disjunction; the only parked node
is the entry, whose walk takes its own `#f` route to `default-error`. No EOF walk
reaches `next`, so a stop there is **not** `eof-reachable-stop` and `count-next`'s
`eof?` flag is `#f`. §6 is right; the row is corrected in place (Task 5), and the
matrix's derived verdicts follow `expected-codes` unchanged.

### F9 — `t2-kinds` and the edge-role census both admit the kind cleanly

A counted consume at `hop` with `next` = `fin` is byte-reachable, so `§16.2:908`
fires through `node-out-edges` — and nothing else does: with a `#f` eof-target
the node is not parked, and in the `eof-only?` variant the walk from the entry
classifies `hop` as the join of `default-error` (the `#f` route) and `finish`
(over `next`) — `eof-verdict-join` answers its first argument on equal rank, so
`default-error`, tier 0, benign either way. So the row
isolates `:908` exactly as the seven shipped kinds do (design §4.10). The
edge-role census gains `((non-eof-into-finish cc next))` — one edge, one role.

### F10 — Slice ②'s placement oracle is validated here, as one case

`AGENTS.md`: validate the next slice's oracle while this one is in flight. Design
§7's oracle 3 — the completion event lands in the feed that delivered the last
body byte, never in the delimiter's feed — is asserted here as **one** both-lane
case over the span-wrapped body under the byte-at-a-time schedule, in the new
differential program (Task 3), with a **completion callback declared**: the
recorder records `'complete` only through the `ondone` closure
(`differential-span-tests.sps:154-167`), and a span with no completion callback
records nothing a placement can be read from — the data callback receives `c` in
the `c` feed under both readings. It is the third of the three ordering witnesses
§6 names, and it is the one a symmetric wrong reading of 0030 item 2 hides from
lane agreement; taking it now costs one case and tells Slice ② its oracle
discriminates under AOT.

### F11 — the slice lands as three green source commits, not two

Design §9 says "one PR with at most two commits, each green", from the rule that
a census row lands with the library it reads. That rule fixes a **partition**,
not a count: the verifier-side rows (the matrix, `ir-tests`, `verify-tests`, the
diagnostic census) land with the constructor and the verifier (commit A); the
executor-side rows (the fingerprint goldens, `position-kind-tests`,
`member3-drift`) land with the normalizer, both executors and the emitter (commit
B). The differential lane, the committed golden with its determinism lanes and
the two structural witnesses **read** commit B and add lanes only, so they are a
third green commit (C) that keeps B reviewable. Task 5 corrects §9's bullet in
place with this reason.

### F13 — the runtime's counted arms run in the interpreted lane only, so their witnesses are the both-lane programs, and no single-file mutant makes the lanes agree

`parser-feed-op!` and `parser-finish-op!` serve the `op` variant; the generated
`/v2` lane calls the emitted `exec` (`runtime.sls:1052-1065`). Three consequences.
(i) A mutation of the runtime's counted arm is witnessed only by a program that
executes a machine carrying the kind through the interpreter — `differential.position-kind`
(Task 2 adds two rows) or `differential.counted` (Task 3) — never by
`unit.runtime`, whose stubs carry no such kind. (ii) Every `need-input` result
the loop builds carries `#f` as `next` (`:1039`, `:1045`), so "which node the
parser is parked on" is observed through `parser-state-name` or through the
route the next `parser-finish!` takes, never through the result's `next`.
(iii) Design §6's oracle 3 asks for "at least one mutant that makes both lanes
agree on a wrong value"; with one `FILE` per mutation and an interpreter-only
runtime arm, no mutant of this slice's code can make both lanes wrong the same
way. What **is** achievable, and what the design's sentence is for, is the pin
shape: every interpreter/emitter mutant declared in the differential pass is
pinned on the **expected value's** failure record, never on lane disagreement.
Task 5 corrects oracle 3 in place to say that. And the second ordering witness
§6 names — "`parser-finish!` after `0:` reports the `,` dispatch's default EOF
error" — cannot see the order: after `0:` a correct feed arm parks the parser
on `,`, and the wrong-order feed arm parks it on `body` with count zero, where a
correct **finish** arm transitions to `,` and reports the same error. The finish
arm's `(0 . next)` route is reached only from a counted consume with a zero
count that was never fed — the entry of a fresh parser (0030 item 6) — so its
witness is a machine whose **entry** is a counted consume with field initial 0,
`#f` eof-target and an **error node** for `next`: it verifies clean, and
`parser-finish!` on a fresh parser reports that node's code in both lanes, while
a finish arm that asks the EOF route first reports the default-EOF code.

### F12 — two Milestone 6 census comments and one obligation note are this slice's to correct

`normal-ir.sls:218-223` ("Twelve node kinds lower here (§10.6's closed set, less
Milestone 6's counted consume)") and `:621` ("The repertoire is now these TWELVE
kinds"), `compile.sls:537` ("… span-completion (Milestone 5 Slice ③) -- TWELVE"),
`runtime.sls:959` ("Slice ③'s ELEVENTH AND TWELFTH kinds …") are censuses that
enumerate a closed set and go stale in silence; each moves to thirteen in the
commit that adds the arm beside it. `compile.sls:372`, the field-action arm's
note ending "owed also by Milestone 6's counted consume if it can fail a
callback", is discharged by finding (design §4.9: the kind invokes no callback)
and corrected in place by commit B, naming §4.9 — without touching the
field-action arm itself, which `§12.7:770`'s deferral addresses to "whoever next
touches these arms" (design §3.2 item 1).

---

## Global constraints

- **Authority order.** Decision `0030`, then the design's §6 and Appendix, then
  the parent plan. Where an authority is wrong, **stop and say so** in this plan's
  findings and correct the instruction in place; a record gets a dated note.
- **Wire tag 14.** Measured at `e81fdc4`: state-kind tags are 0-7 and 10-13
  (`normal-ir.sls`'s `encode-normal`, `:743-856`); 8 and 9 are the trailing
  section discriminators. **Do not write the tag literal in a comment** in
  `normal-ir.sls` — the file forbids it (`:881-888`) because a pin FINDs the
  one-line `put-u8` form as text.
- **No `(cons 'SYM …)` form enters `verify.sls` except the kind's one edge role.**
  `edge-roles-in-source` collects every quoted-symbol `cons` in the file as an
  edge role; the kind's `node-out-edges` arm contributes `(cons 'next …)`, an
  existing role, and nothing else in this slice may add one — not in code, not in
  a comment.
- **`reserved-drift-tests.sps` stays green untouched.** No runtime export moves;
  `reserved-member-2` is untouched. `reserved-member-3` gains `n` and the drift
  guard for member 3 (`member3-drift-tests.sps`) moves with it, in one commit.
- **Every FIND at one site in both directions**, re-anchored with its REPLACE,
  judged against the other mutants in its lane; the sweep runs once after the
  last source commit with a control on `e81fdc4` (Task 4).
- **A mutant can hang the suite.** The runner has no per-mutant timeout. The
  differential program's scripts are literal lists of at most a few steps; no
  fixture re-enters the runtime under a data-dependent bound.
- **Dates are literal.** Today is 2026-09-06.

---

## Task 1 — The kind and the verifier (commit A)

**Files:** `src/byte-machine/private/ir.sls`, `src/byte-machine/graph.sls`,
`src/byte-machine/verify.sls`, `test/common/ir-tests.sps`,
`test/common/kind-position-census-tests.sps`, `test/common/verify-tests.sps`,
`test/common/diagnostic-census-tests.sps`, `test/common/graph-tests.sps`,
`test/support/cmake/SchemeMutationSuite.cmake`.

**ONE COMMIT.** `node?`'s thirteenth disjunct reddens the census's S2 row and the
S2b row the moment it lands (both read `ir.sls` at run time), and every verifier
arm below is what turns them green; a commit between is red.

- [ ] **Step 1: The constructor, predicate and accessors** — `§9.1:311`,
      `(make-counted-consume-node name field next eof-target source-label)`.
      Block placed after the span-end block and before `;; --- node dispatch ---`
      (`ir.sls:627`), the newest-kind precedent. `require-symbol` for `name`,
      `field` and `next` (a `#f` `next` is refused — the fourteenth constructor
      refusal); `eof-target` checked in the **dispatch** order
      `(or (symbol? eof-target) (eq? eof-target #f))` (F3), `#f` meaning the
      machine default EOF error (`§9.1:318`); `source-label` unchecked, as every
      label is. Vector `(tag name field next eof-target source-label)`; five
      accessors at slots 1-5, `counted-consume-node-source-label` among them.
      Decision 0020's constructor half only: whether `field` is declared is
      `pass-field-operands`' (§4.3). Export the constructor, predicate and five
      accessors from `ir.sls`; `graph.sls` re-exports **the constructor only**
      (design §4.10), on the line the M5 constructors share.
- [ ] **Step 2: `node?`, `node-name`, `node-source-label`.** The disjunct appended
      after `(span-end-node? x)`; an arm in each `cond` above its raising `else`.
      Six `node?` pins re-anchor (F2, by LABEL); the `node-name` pins end at line
      boundaries and do not move when the arm is inserted before the `else`; the
      `node-source-label` pins ("… answers #f for a stop node", "… loses an arm")
      do not move for the same reason.
- [ ] **Step 3: `ir-tests.sps`** — the constructor group on the accumulate
      group's shape (`:714`): five parts read back; `node?`/`node-name`/
      `node-source-label` answer; `#f` `next` refused with
      `(contract-violation? 'make-counted-consume-node 'next)`; a non-symbol
      `eof-target` refused; `#f` `eof-target` accepted; the field reference **not**
      checked here. `node-builders` (`:1033`) gains the kind and both "twelve kinds
      driven" and "and the table has twelve rows" become thirteen. `label-accessor-rows` (`:981`) is **not** touched —
      it is the table of the nine carriers that had no accessor, and this kind is
      born with one.
- [ ] **Step 4: The verifier's per-kind sites, every appendix row, in this order.**
      1. `node-out-edges` (`verify.sls:193`): an arm `(list (cons 'next
         (counted-consume-node-next n)))`, placed after the accumulate arm and
         before `(else '())` — no shipped FIND spans that seam. Through it
         `node-out-targets`, `byte-reached`, `pass-names`' target resolution,
         `pass-reachability` and `§16.2:908`'s derived block all see `next` with
         no further code.
      2. `node-eof-target` (`:232`): an arm answering the kind's eof-target, `#f`
         meaning the default. Through it `all-out-targets`, `pass-eof` (the
         `invalid-eof-target` resolution check) and both `(symbol?
         (node-eof-target n))` parked-set clauses see the route.
      3. `pass-field-operands` (`:454`): a sibling arm on
         `accumulate-operand-diagnostics`' shape (`:448`) — a **separate**
         `counted-operand-diagnostics` reporting `invalid-field-operand` under
         the node's name with the message `"counted consume names no declared
         field"` (§4.3: `§16.2:903` "inherits nothing"; the code is reused, the
         arm is its own). Do not clone `field-operand-diagnostics`' skeleton —
         its `((not width)` line is pinned at one site.
      4. `reexec-targets` (`:622`): an arm answering `(list
         (counted-consume-node-next n))`, after the accumulate arm, before
         `(else '())`; and the REPORT set (`:745-752`) gains
         `(counted-consume-node? n)` **in the same edit** (0030 item 7). Seven
         pins re-anchor (F2).
      5. `eof-successors` (`:854`): becomes `(cond ((counted-consume-node? n)
         (list (counted-consume-node-next n))) (else (zero-width-successors
         n)))` (F1). `eof-step`'s comment corrected in place.
      6. `classify` (`:883`): an arm **before** the accumulate arm —
         `((counted-consume-node? n) (eof-verdict-join (dispatch-arm
         (counted-consume-node-eof-target n) path) (join-over (eof-successors n)
         path)))` — the flow-through join (0030 item 5). Its comment states why
         `join-over`'s empty-list raise is unreachable here (F1) and which
         machine this arm rejects (the zero-count stop at the entry).
      7. `parked-eof-start` (`:974`): a `cond` whose callback arm keeps its
         shipped lines and whose new arm is `((and (counted-consume-node? n)
         (not (eq? (node-name n) (machine-entry m))))
         (counted-consume-node-eof-target n))` (0030 item 6). That eof-target is
         a **symbol whenever the arm is reached**, by construction:
         `pass-eof-execution` calls `parked-eof-start` only for nodes in the
         parked set, and a non-entry counted consume enters that set only
         through the `(symbol? (node-eof-target n))` clause — a `#f` route never
         gets here (`eof-terminal` walks node names, and `#f` is not one). The
         arm's comment states that guarantee and the clause it rests on; the
         entry falls through to `(node-name n)` and takes item 5's join. The
         construct's one pin re-anchors (F2).
      8. Both `§16.2:909` disjunctions (`:1089-1104`, `parked?` at `:1563`):
         **no edit** (0030 item 6). The appendix rows say why; the fixtures in
         Step 6 are what prove the omission right.
      9. `span-transfer`, `span-node-diagnostics`, `pass-declarations`' node
         walk, `pass-names`' error filter, `pass-overlap`,
         `pass-sequence-ambiguity`, `zero-width-edges`: **no edit**, each a
         derivation the appendix states; Step 6's fixtures reach the first two.
- [ ] **Step 5: `kind-position-census-tests.sps`** — the derived censuses, every
      literal in F7: `kind-table` gains `(cons 'counted-consume (lambda (nm)
      (make-counted-consume-node nm 'n 'ee #f #f)))`; `kind-predicates` gains the
      predicate (and the `(only …)` import); `position-table` gains
      `count-next` (byte `#t`, eof `#f` — F8) and `count-eof-target` (byte `#f`,
      eof `#t`), each with a host dispatch into a counted consume on field `n`;
      `role->positions`' `next` entry gains `count-next`; the unlabelled list
      gains `count-eof-target`; `self-expectations` gains `((count-next advance)
      . (zero-progress-cycle))` and `((count-eof-target advance) .
      (eof-zero-progress-cycle))` with two `self-machine` arms (a self-targeting
      `next`; a self-targeting eof-target); `eof-positions` gains
      `count-eof-target`; the absence census gains the `#f`-`next` refusal and
      the fourth legally-absent EOF route; S2's and S2b's labels move to
      thirteen, and the two pins that read them move with them. Verdicts are
      **derived by `expected-codes` before running**; a cell that disagrees is a
      verifier defect or a wrong row, never a literal to adjust.
- [ ] **Step 6: `verify-tests.sps`** — the fixtures 0030's Consequences owe, each
      asserted by code **and** node, in a group "the thirteenth kind in the
      verifier census (Milestone 6 Slice ①)":
      - the flow-through zero-count stop at the **entry** — entry a counted
        consume, field initial `0`, `#f` eof-target, `next` a stop —
        REJECTED with `eof-reachable-stop` at the entry (0030 item 5's hole);
      - the same through a **pause continuation** — REJECTED at the pause;
      - the one-shot "length, body, stop" grammar — `… →(byte) body (eof: an
        error; next: a stop)` — **ACCEPTED**, zero diagnostics (0030 item 6);
      - a self-targeting `next` — `zero-progress-cycle` **alone**; a
        self-targeting eof-target — `eof-zero-progress-cycle`;
      - a byte-reachable `next` into a finish — `non-eof-into-finish`, and the
        `t2-kinds` row (F9; "all seven kinds driven" → eight, both cases);
      - the edge-role census row (`:2159`, "seven kinds driven" → eight);
      - an undeclared field — `invalid-field-operand` under the node's name; a
        declared one — clean;
      - 0030 item 7's priced over-rejection as a **pair**: the value-terminated
        loop `[branch → consume → decrement → branch]` REJECTED
        (`zero-progress-cycle`), the same loop with a byte dispatch in it
        ACCEPTED (`§16.2:913`);
      - a counted consume inside a span verifies clean (`span-transfer` identity,
        `§10.6:604`).
      `diagnostic-census-tests.sps`: `(invalid-field-operand 6)` → `7`; the
      totals check derives 56. `graph-tests.sps`: a machine carrying the kind
      builds through the façade (the field-node precedent at `:128`).
- [ ] **Step 7: Pins, in the passes that own them** (LABELs are the plan's; the
      implementer writes each regex from a measured FAIL tail, and pins on
      `got .[)]` where the record is an empty list):
      - unit.ir: "ir: a counted-consume node's next may be absent"; "ir: a
        counted-consume node's eof-target is unchecked" (REPLACE the `or` with
        `#t`); "ir: node? does not admit a counted-consume node"; "ir: node-name
        does not answer for a counted-consume node"; "ir: node-source-label
        answers #f for a counted-consume node" (comparison-caught in
        `node-builders`).
      - kind-position-census: the two re-anchored ratchets (F7).
      - verify.rejections: "verify: a counted consume's next is not an
        out-edge" (arm → `'()`); "verify: a counted consume's eof-target is read
        as absent"; "verify: a counted consume's field reference is not
        checked"; "verify: a counted consume's next is invisible to the
        zero-progress walk"; "verify: the zero-progress REPORT set excludes the
        counted-consume kind"; "verify: eof-successors answers nothing for a
        counted consume" (arm dropped → the entry zero-count stop verifies
        clean); "verify: classify drops the next half of the counted join"
        (`join-over` half removed → the flow-through stop unreported); "verify:
        classify drops the eof half of the counted join" (`dispatch-arm` half
        removed → truncation-to-stop unreported: fixture with a symbolic
        eof-target reaching a stop); "verify: a parked counted consume is
        classified from its own name" (arm answers `(node-name n)` → the
        one-shot grammar's ACCEPTED fixture goes red with `eof-reachable-stop`).
      Then the seven REPORT-set re-anchors and the six `node?` re-anchors.
      **Fourteen new mutations**; `set(EXPECTED_MUTATIONS 483)` becomes **497 in
      this commit**, with a count-narrative entry beside the others — the
      `release` preset runs the mutation lane, whose totals check is a
      `FATAL_ERROR` on any other number, so a commit that adds pins without
      moving the literal is a red commit.
- [ ] **Step 8: Verify** — `cmake --build --preset dev && ctest --preset release
      --output-on-failure 2>&1 | rg -n 'CMake Error|wrong reason|UNCAUGHT|FAIL
      |tests passed'`: exactly one line, `100% tests passed, 0 tests failed out of
      108`; the mutation lane's own line reads `55 passes, 497 mutations`. `rg -n "\(cons '" src/byte-machine/verify.sls | rg -v ';;' | wc -l`
      prints the pre-edit count **+ 1**. `rg -c -F "<each new or moved FIND>"
      <its FILE>` prints `1` for every pin touched.
- [ ] **Step 9: Commit** — `feat(verify): the thirteenth kind, counted consume,
      and its two answers in the verifier`.

---

## Task 2 — Lowering, encoding, both executors, the emitter (commit B)

**Files:** `src/byte-machine/private/normal-ir.sls`, `src/byte-machine/interpret.sls`,
`src/byte-machine/runtime.sls`, `src/byte-machine/compile.sls`,
`test/common/normal-ir-tests.sps`, `test/common/interpret-tests.sps`,
`test/common/member3-drift-tests.sps`, `test/common/position-kind-tests.sps`,
`test/common/runtime-tests.sps` (a comment only), `test/support/cmake/SchemeMutationSuite.cmake`.

**ONE COMMIT, Slice ②-of-Milestone-5's rule: an emitted arm is a call to
something.** The emitter, the runtime arms it calls, the normalizer that feeds
it and the interpreter the differential compares it with land together, with
the census rows that read them (F11).

- [ ] **Step 1: `normal-ir.sls`** (design §4.4). The `(only …)` import gains the
      predicate and four accessors (not the label). `lower-machine`'s `cond`
      gains an arm **before** the raising `else`: `(vector ns-tag
      'counted-consume i #f #f #f eof (eof-reason-of eof) #f (list field)
      (list next-id))` — `arguments` the field **name**, `targets` the successor
      id, slot 6 the EOF routing through a **fourth** resolver lambda
      `count-eof-of` beside `acc-eof-of` (`:378`), reading
      `counted-consume-node-eof-target` (a shared resolver would be a bare slot
      read from the wrong kind's vector — `acc-eof-of`'s own reason); `selector`
      `#f`. `internal-blocks`' `else` skips it (1:1). `encode-normal` gains an
      arm: tag **14**, then `put-symbol` of the field name, `put-u32be` of the
      successor id, then `put-eof-routing` — every part (decision 0019 item 2).
      The two census comments (F12) move to thirteen; the "TWELVE" wording is in
      the pinned region of neither.
- [ ] **Step 2: `normal-ir-tests.sps`** — an exact-value fingerprint golden for a
      counted-consume machine (`(counted-machine field next eof)` on
      `acc-machine`'s shape at `:802`; the literal is **measured**, never
      predicted); its own eleven-slot layout case (F7); the drift pairs — two
      machines differing only in the field, only in the successor, only in the
      EOF route, each with a different fingerprint; and `"unmoved"` — every
      shipped fingerprint literal in the file is unchanged (design §6 oracle 1).
- [ ] **Step 3: `interpret.sls`** (design §4.1, §4.6). `kind`'s `cond` (`:96`)
      gains `((counted-consume-node? n) 'counted-consume)`; `eof-target-of`
      (`:175`) gains an arm (its `else` is loud, so a parked counted consume
      would raise out of `parser-finish!` without it); the message table (`(case msg …)` at `:362`)
      gains `count-step`, answering `(committed . target-or-#f)` and committing
      the subtraction into the field vector — width from `field-slot-and-width`
      (`:276`), `n = (min v (- end pos))`, `(vector-set! fv slot (- v n))`,
      target `next` when `(= n v)`, `#f` otherwise; a zero `v` answers `(0 .
      next)` **before** looking at `pos`/`end` (0030 item 1). `completion-state`
      needs no new shape (§4.6): a parked counted consume's `current` is its bare
      name. `interpret-tests.sps` drives `count-step` directly through the op
      closure: zero count over an empty slice → `(0 . next)`; positive count
      over an empty slice → `(0 . #f)`; partial, exact, surplus commits with the
      field value after each; a `u64` count above `(greatest-fixnum)` whose
      subtraction is bignum arithmetic (`§15:856`).
- [ ] **Step 4: `runtime.sls`** (0030 items 1-4; design §4.5). In
      `parser-feed-op!`'s wire-kind `case` (`:887`), a `((counted-consume) …)`
      arm: ask `count-step`; on `(0 . next)` with `next` a symbol, `(parser-set-current!
      parser next)` and `(loop pos pk)` — the position kind **carried through**
      (0030 item 3); on `(n . target)` with `n ≥ 1`: offset `+= n`,
      `current` := `target` or the node itself, then `(loop (+ pos n) 'boundary)`
      if `target`, else the `need-input` result at `(+ pos n)` with `current`
      left on the node (observed through `parser-state-name` and through the
      route the next `parser-finish!` takes — never through the result's `next`,
      which is `#f` for every `need-input`, F13); on `(0 . #f)` — positive
      count, no input — the `need-input` result at `pos`. Order in the arm: the
      op decides; the arm never tests `(>= pos end)` before asking. In
      `parser-finish-op!` (`:1186`): factor the `(accumulate dispatch)` arm's
      body into a local `take-eof-route!` (F5), keep that arm as a one-line call,
      and add `((counted-consume) …)`: ask `count-step` over an empty slice;
      `(0 . next)` → `(parser-set-current! parser next)` and `(loop next pk)`;
      `(0 . #f)` → `(take-eof-route!)`. The `:959` census comment moves to
      thirteen (F12). **No export moves**; `reserved-drift-tests.sps` is the gate.
- [ ] **Step 5: `compile.sls`** (design §4.5, §4.9). `reserved-member-3` (`:113`)
      gains `n`; `render-state-arm` (`:298`) gains a `((counted-consume) …)` arm
      before `((dispatch) …)`: a three-clause `cond` over `(let ((v (vector-ref
      fieldv <slot>)))` — `(= v 0)` → `zero-width-jump` to the successor;
      `(>= pos end)` → `(if finish? <render-eof-branch …> <need-input at pos>)`
      with the branch rendered by `render-eof-branch` (`:193`, a call); else
      `(let ((n (min v (- end pos)))) (vector-set! fieldv <slot> (- v n)) (if
      (= n v) (loop (+ pos n) <next-id> (+ off n) (quote boundary))
      (byte-machine-make-feed-outcome/v1 (quote need-input) (+ pos n) #f <id> (+
      off n))))` — F4's textual hazard cleared by `rg -n -F` of every emitted
      line against the suite before committing. The `else` census comment
      (`:537`) moves to thirteen; the reached-declaration walk's list (`:612`)
      becomes `'(dispatch accumulate counted-consume)` and its pin — in the
      `differential.field` pass, F2 — re-anchors; the field-action arm's note (`:372`) is corrected in place per §4.9
      (F12) — the field-action arm's **code** is untouched.
- [ ] **Step 6: `member3-drift-tests.sps`, `position-kind-tests.sps`,
      `runtime-tests.sps`.** The drift fixture (`:49`) gains a counted consume on
      a byte-reachable position (on `sdone`'s byte 1, before `done`, consuming
      `count` — the field the fixture already declares), so the thirteenth arm
      renders and `n` is exercised; the exercised list gains `n` and both
      literals move to ten; the two `reserved-member-3` pins re-anchor onto the
      new list text. `position-kind-tests.sps`' `cases` (`:222`) gains two rows
      (design §4.10), shaped so the runtime's feed-arm decisions are reachable
      from them (F13): truncation at a parked counted consume during finish — a
      partial body fed, then `parser-finish!` — `eof` at the final offset (the
      offset advance and "parked on the node, not the successor" both show
      here: a parser parked on `,` would take `,`'s route and report the
      default-EOF error's node); and a zero-count transition into an error node
      over a **reexecute** edge, the counted consume reached at the **end of the
      slice** — `byte` at the current offset, carried (an arm that tests
      exhaustion first returns `need-input` here and the row reports no error
      at all); "seven cases ran" / "fourteen drives observed" → 9 / 18. `runtime-tests.sps`'s six stub
      tables owe **no arm** — no stub machine carries the kind — and a one-line
      comment at the first table says so, as the appendix row asks.
- [ ] **Step 7: Pins, fifteen, each in the pass whose program reaches the
      decision** (F13). unit.normal-ir, six: "normal-ir: the counted-consume
      encode tag collides with span-completion" (14 → 13, by fingerprint
      golden); "… a counted consume's field name is dropped from the encoding";
      "… successor is dropped"; "… EOF routing is dropped" (each by the golden);
      "… lowers the successor to state zero"; "… a counted consume's EOF edge is
      read as absent" (`count-eof-of` → default). unit.interpret, four, all by
      the direct `count-step` cases: "interpret: count-step tests exhaustion
      before the zero count" (the `(0 . next)` answer moved after the `pos`/`end`
      test — caught by the zero-count-over-empty-slice case); "… commits `(- end
      pos)` instead of the min" (the field goes negative on surplus — a
      comparison catch); "… never subtracts"; "… answers the successor only when
      input is also exhausted" (the `n = v` test mutated to `(>= (+ pos n) end)`
      — the count-completion-wins mutant, caught by the exact case). differential.position-kind,
      three, by the two new rows: "runtime: the counted arm does not advance the
      stream offset" (row 1's offset); "… parks `current` on the successor when
      input runs out" (row 1 reports the default-EOF node instead of the
      truncation); "… asks exhaustion before the op" (row 2 reports no error). A
      mutant that leaves `current` on the counted node after a **completed**
      commit is **not declared**: with the field at zero the node transitions to
      the same successor on re-entry, so the mutant is inert, and a mutant that
      leaves `current` there after a zero-count transition hangs both loops (the
      runner has no timeout) — the comment at the arm says both. unit.compile,
      two: "compile: the emitted counted arm tests exhaustion before the zero
      count" is **not** here — it is witnessed only by an executing lane, so it
      is declared in the position-kind pass beside the runtime's (row 2, the
      generated lane) — and "compile: reserved-member-3 loses the counted arm's
      `n`" (member3-drift) plus the two shipped `reserved-member-3` pins
      re-anchored onto the new list text. So: 6 + 4 + 3 + 1 + 1 (the emitted
      exhaustion-first pin in position-kind) = **fifteen**; `EXPECTED_MUTATIONS`
      **497 → 512 in this commit**, with its narrative entry. The emitter's
      `min`, subtraction and `n = v` decisions are pinned in Task 3's
      differential pass on the expected value, where surplus and exact bodies
      exist.
- [ ] **Step 8: Verify** — the release filter prints exactly `100% tests passed,
      0 tests failed out of 108` and the mutation lane's line reads `55 passes,
      512 mutations`; `git diff --stat e81fdc4..HEAD -- test/fixtures/`
      prints nothing (no golden yet; Task 3 adds one); every fingerprint literal
      in `normal-ir-tests.sps` other than the new one is unchanged (`git diff
      e81fdc4..HEAD -- test/common/normal-ir-tests.sps | rg '^-.*[0-9]{15,}'`
      prints nothing).
- [ ] **Step 9: Commit** — `feat(exec): counted consume lowers, encodes as tag 14,
      and executes in both lanes`.

---

## Task 3 — The differential, the golden, the two structural witnesses (commit C)

**Files:** `test/common/differential-counted-tests.sps` (new),
`test/support/harness/byte-machine/test/counted-machine.sls` (new),
`test/fixtures/generated-counted.golden.sls` (new),
`test/common/determinism-counted-tests.sps` (new), `test/common/compile-tests.sps`,
`test/CMakeLists.txt`, `test/support/cmake/SchemeMutationSuite.cmake`.

- [ ] **Step 1: The proving machine** — design §6's length-prefixed message loop
      **without a span**: `idle` (byte dispatch: a digit reexecutes into `len`,
      `,` is not accepted here, anything else rejects; eof-target the finish, so
      EOF between messages is `finished`) → `len` (accumulate, base 10, field
      `len`; eof-target the truncation error) → `:` → `body` (counted consume on
      `len`; eof-target the truncation error) → `,` → clear `len` → `idle`.
      Declared in `counted-machine.sls` on `accumulate-machine.sls`'s shape, with
      **both** EOF routes present. **The only-consumer variant** for the
      reached-declaration walk (design §6, §3.2 item 5): a machine whose **only**
      default-EOF consumer is the counted consume and which carries **no error
      node naming the default-EOF declaration or sharing its code and reason** —
      verified, rendered, loaded, run, in the differential program.
- [ ] **Step 2: The golden and its lanes** — `generated-counted.golden.sls`
      rendered once from the proving machine and committed; `determinism-counted-tests.sps`
      on `determinism-accumulate-tests.sps`'s shape (byte-identical emission
      against the committed file, then execution walks through the generated
      lane); two CTest lanes `byte-machine.determinism.counted.chez.{source,aot}`
      on the accumulate registration's shape (`test/CMakeLists.txt:1470-1489`),
      `SOURCES` listing `counted-machine.sls`; `BYTE_MACHINE_COUNTED_GOLDEN_FILE`
      added to the mutation lane's `ENVIRONMENT` (`:604`) so the new pass's
      baseline finds it. `git diff --stat e81fdc4..HEAD -- test/fixtures/` lists
      **exactly one** file.
- [ ] **Step 3: The differential program**, both lanes, on the span lane's
      harness shape (F6): the four `§22.3:1254` cases — zero (`0:,`), partial
      (`3:ab` then `c,`), exact (`3:abc` then `,`), surplus (`3:abc,0:,` in one
      feed) — each asserting the **expected** tuple (status, `next`, `consumed`,
      offset, lifecycle) and the field value per lane, and then the lanes against
      each other; every split point of `3:abc,` (`§22.5:1278`); leading, trailing
      and intermediate empty feeds (`:1279`); a nonzero `start`/`end` sub-slice
      and a larger bytevector with unrelated prefix and suffix bytes
      (`:1280-1281`); EOF truncation after `3:ab` — `eof` at offset 4, the
      truncation code, both lanes (`§25:1602`); reset mid-body restoring the
      count (`§12.5:738`); the two-message feed for `§25:1609` — `consumed`
      equal to the whole slice, the field reset action having run between the
      messages, both in one result; a `u64` count above `(greatest-fixnum)`
      (`§15:856`); and the **two ordering witnesses** (0030 item 1, F13): after
      `0:`, `parser-state-name` names the `,` dispatch, not `body`, in both lanes
      (the feed order); and on a second machine whose **entry** is a counted
      consume with field initial 0, `#f` eof-target and an error node for
      `next` — verified clean — `parser-finish!` on a fresh parser reports that
      error node's code in both lanes (the finish order; design §6's
      "`parser-finish!` after `0:`" witness cannot see it, F13).
- [ ] **Step 4: Slice ②'s oracle, one case (F10).** The same body wrapped in a
      span with a data callback **and a completion callback** (the
      with-completion variant design §7 names — the recorder records `'complete`
      only through `ondone`), `3:abc,` fed byte-at-a-time, one recording closure
      **per lane** with its own accumulator: the completion event is recorded
      during the feed that delivered `c`, and the `,` feed records nothing —
      asserted as a value per feed, and only then compared across lanes. If it does not
      discriminate under `.chez.aot`, stop: design §7's oracle needs redesigning
      before Slice ② is planned, and this plan's Task 5 records what was found.
- [ ] **Step 5: The two structural witnesses** (`§25:1607`, design §4.7). In
      `compile-tests.sps`: a datum walk — the rendered library read back with
      `read` (the technique `member3-drift-tests.sps:135-139` ships; no such walk
      exists in `compile-tests.sps` today) — locating the counted state's `case`
      arm by id and asserting **exactly one** `min` application and **no**
      `(+ pos 1)` form inside it. In the differential program: the interpreted
      lane's op wrapped by a counting closure — `(make-compiled-machine (lambda
      (msg . args) (when (eq? msg 'count-step) (set! hits (+ hits 1))) (apply op
      msg args)))`, the op reached through the compiled machine's tagged vector
      (measure the slot `make-compiled-machine` stores it in) — and a body of
      one thousand bytes fed in one slice produces **exactly one** `count-step`.
      A mutant rendering a per-byte self-loop fails the first; a mutant stepping
      one byte per message fails the second; both pass every behavioural lane.
- [ ] **Step 6: Two new mutation passes and their eight pins** — a
      `differential.counted` pass (SPEC `byte-machine.differential.counted.chez.source`),
      seven: "compile: the reached declaration walk ignores counted consume"
      (Task 2's decision, witnessed here by the only-consumer fixture — a raise
      from `render-machine` on a verified machine); "compile: the emitted counted
      arm commits `(- end pos)` instead of the min" (the surplus case's field
      value, generated lane); "compile: the emitted counted arm never subtracts"
      (the exact case's field value); "compile: the emitted counted arm continues
      only when input is also exhausted" (the exact case's `next` and the
      `:1609` two-message feed); "interpret: the counted op steps one byte per
      message" (a per-byte `count-step` — caught by the counting witness, not by
      any tuple); "runtime: the counted finish arm asks the EOF route before the
      zero count" (the entry-zero machine's error code, F13); "compile: the
      emitted counted arm renders a per-byte self-loop" (caught by the datum
      walk in `compile-tests.sps` — declared under unit.compile, counted here).
      Each pin's regex is the **expected value's** FAIL record for one lane, never
      the lanes' disagreement (F13). A `determinism.counted` pass (SPEC
      `byte-machine.determinism.counted.chez.source`), one: an
      **emitted-bytes-only** mutant — two independent bindings of the emitted
      `let*` reordered, behaviour identical, the golden the only thing that
      notices — on Pass 50's precedent. `EXPECTED_PASSES` 55 → **57**;
      `EXPECTED_MUTATIONS` **512 → 520 in this commit**, with its narrative
      entry.
- [ ] **Step 7: Verify** — the release filter prints exactly `100% tests passed,
      0 tests failed out of 112` (two determinism lanes, two differential lanes);
      the mutation lane's totals line prints `57 passes, 520 mutations`; `git diff --stat e81fdc4..HEAD -- test/fixtures/`
      lists exactly `generated-counted.golden.sls`; every shipped golden's last
      line is byte-identical to `e81fdc4`'s (`git diff e81fdc4..HEAD --
      test/fixtures/generated-{one-byte,pause,http-version,accumulate}.golden.sls`
      prints nothing).
- [ ] **Step 8: Commit** — `test(counted): the differential in both lanes, the
      fifth golden, and two structural witnesses for :1607`.

---

## Task 4 — The pin sweep, both directions, once

Re-judge every pin in every touched pass (unit.ir, unit.kind-position-census,
verify.rejections, unit.normal-ir, unit.interpret, unit.compile,
unit.member3-drift, differential.position-kind, differential.field, the two new
passes — `unit.runtime` is untouched: no counted-consume pin can live there,
F13) against every other mutant in its lane, **in both directions**, with a
control run on `e81fdc4`, using the runner's own rule (`byte_machine_mutation_verdict`)
over each mutant's captured output — the Slice ⓪ sweep's method and script, its
report in the ledger's directory. Expected: **0 self-failures**; collisions
involving a pin this slice **added or moved**: **0** after any fix; every
pre-existing collision the control has is re-confirmed and any new one is named
by LABEL in the tree beside the pin whose blast radius grew (Slice ⓪ found nine
such, from one old mutant a fold widened — expect the S2 ratchet and the
REPORT-set pins to be the candidates here). Then the totals:

```bash
rg -n '^set\(EXPECTED_(PASSES|MUTATIONS)' test/support/cmake/SchemeMutationSuite.cmake
```
Expected: `set(EXPECTED_PASSES 57)` and `set(EXPECTED_MUTATIONS 520)` — 483 +
14 (Task 1) + 15 (Task 2) + 8 (Task 3), each literal moved **in its own commit**
(a commit that adds pins without moving it is red, since `release` runs the
mutation lane and its totals check is a `FATAL_ERROR`). If the tree's totals line
disagrees, the arithmetic here is what is wrong and the tree wins — but every
disagreement is named in the sweep report, because a miscount is how a pin goes
undeclared.

---

## Task 5 — Both ends, the design's appendix, and the status surfaces

- [ ] **Step 1: The parent plan — one appended disposition, never an insertion.**
      Under `## Dated dispositions`, a heading `### §25:1597-1603 and
      §25:1607-1609 — Milestone 6 Slice ①, delivered`, dated, stating per scope
      bullet and exit criterion what in the tree meets it (file and case name),
      which clauses of `:1608` and `:1609` are Slice ②'s, and that `§16.2:903`
      reduces to field resolution in v0.1 (design §4.3). Check:
      `git diff -U0 -- docs/plans/byte-machine-implementation-plan.md | rg -c
      '^@@'` prints `1` and its old-side line is ≥ the file's last line before the
      edit.
- [ ] **Step 2: The design, corrected in place** (instructions): the four
      sites still carrying the withdrawn "both" derivation for `count-next` —
      the test-side `position-table` row ("byte **and** EOF"), the
      `expected-codes` row ("`count-next` is both"), the `self-expectations` row
      ("`count-next`: both cycles"), and §6's fixture bullet ("the
      self-targeting `next` (`zero-progress-cycle` and `eof-zero-progress-cycle`,
      both)") — all say what F8 derives: a byte position, `zero-progress-cycle`
      alone; §6's "the third EOF resolver" becomes the fourth (§4.4 and the
      appendix already say so); §6's oracle 3 drops "at least one mutant that
      makes both lanes agree on a wrong value" for F13's reason and keeps the pin
      shape (expected value, never lane agreement); §6's second ordering witness
      ("`parser-finish!` after `0:`") is replaced by the entry-zero machine
      (F13); the `verify.sls` row for `eof-successors` says the construct gains a
      `cond` (F1); §9's "at most two commits" bullet becomes three green source
      commits with F11's reason; §6's "Census rows" bullet gains the literals F7 lists;
      the Appendix gains a row for `pass-eof` (`invalid-eof-target` resolution —
      DERIVED through `node-eof-target`), which the measurement found missing;
      and the Amendments block indexes the correction, each item saying the plan
      measured what the design counted. The Exit table's `:1607` and `:1609`
      rows and `:1608`'s three clauses get their dated dispositions.
- [ ] **Step 3: The status surfaces** — `README.org`'s paragraph, `CHANGELOG.md`'s
      `[Unreleased]`, the parent plan's `Status:` line (one physical line; it
      stays one), the design's `Status:` header; and
      `docs/reference/callback-span-lifetime.md` §6 gains the one sentence design
      §4.10 owes (a bulk-consumed body changes no fragment boundary). Then:

      ```bash
      rg -n "less Milestone 6's|Milestone 6's counted consume|these TWELVE kinds|-- TWELVE\.|Milestone 6's close-out" src/byte-machine/
      ```
      Measured at `e81fdc4` this prints **five** lines (`normal-ir.sls:218`,
      `:621`; `compile.sls:373`, `:537`; `verify.sls:587`). After commit B it
      must print exactly **one** — `verify.sls`'s `pass-reachability` note, which
      Slice ② re-addresses. A pattern that already printed one line before the
      edit would pass whether or not the comments moved; this one cannot.
- [ ] **Step 4: Commit** — `docs: Milestone 6 Slice ① delivered — the disposition,
      the appendix's corrections, four status surfaces`.

Then the whole-branch review (a read-only reviewer in a worktree, checking what
the code does against the code), its fixes, and the PR; `main` is merged only on
the owner's go-ahead.

---

## Verification

`release` green in both lanes at every commit, the mutation suite at its
re-measured totals, and eight things checkable rather than asserted:

1. **No shipped artifact moves**: `git diff --stat e81fdc4..HEAD -- test/fixtures/`
   lists exactly one file; every fingerprint literal pinned in
   `normal-ir-tests.sps` at `e81fdc4` is unchanged (design §6 oracle 1).
2. **The kind is total across the census**: S2 ("the same thirteen kinds"), S2b,
   the diagnostic census (`(invalid-field-operand 7)`, 56 sites),
   `member3-drift`'s exercised-name assertion (ten), and `normal-ir-tests.sps`'s
   layout walk are all green with the thirteenth disjunct present (oracle 2).
3. **The differential asserts values**: every case compares each lane against an
   expected tuple and field value, and every mutant declared in the
   `differential.counted` pass is pinned on one lane's **expected-value** FAIL
   record, never on the lanes' disagreement (oracle 3 as Task 5 corrects it,
   F13).
4. **Both structural witnesses** for `:1607` are red under their mutants and green
   on the tree, and neither is a differential.
5. **The two 0030 machines**: the zero-count stop at the entry REJECTED with
   `eof-reachable-stop`; the one-shot "length, body, stop" grammar ACCEPTED.
6. **The two ordering witnesses** hold in both lanes, and Slice ②'s placement
   case discriminates under `.chez.aot`.
7. **Every FIND resolves to one site** and the suite's failure-signature filter
   returns only the `tests passed` line.
8. **`reserved-drift` is green and untouched**: no runtime export moved.

## Exit

The thirteenth kind exists in every library, both lanes and every census; five
scope bullets and two exit criteria are dispositioned against the tree; Slice ②
starts with its oracle already shown to discriminate, against a machine and a
golden it wraps in a span rather than builds.
