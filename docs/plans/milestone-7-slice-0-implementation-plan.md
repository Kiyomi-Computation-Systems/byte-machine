# Milestone 7 — Slice ⓪ (the reachability narrowing, one parked set, and the family pinned) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Authority: [decision 0031](../decisions/0031-reachability-is-the-occupiable-relation.md)
(Gate 0, PR #85), then `milestone-7-design.md` §5 and §4.1, then the parent plan's
appended disposition "§25:1611 — Milestone 6 hands the reachability narrowing to
Milestone 7" and `§16.2:897` / `§16.4:947`.

This is a **hardening slice under `§25:1615`** ("generative and diagnostic hardening of
all mandatory verification passes already introduced"): it discharges the `§25:1611`
hand-off and no `§25` bullet of its own, changes one verdict on one constructible
family, adds no diagnostic code and no emission site, and precedes Slice ① (which
edits the same file at every emission site and must not meet a moving walk).

Everything below was measured at **`ba5c426`** (`docs/m7-gate-0`, the Gate 0 branch;
`src/` and `test/` byte-identical to `5ac363a`, the commit the design's prototype
measured — `git diff --stat 5ac363a..ba5c426 -- src/ test/` prints nothing). Every
`file:line` names its construct as well; the lines move the moment Task 3 lands and
no tool here notices. The slice's own base is `main` after PR #85 merges; Task 1
re-takes the one measurement everything rests on **at that base**, before any edit.

---

## 1. Nine findings that shape the work

### F1 — the verdict change is three cases in one program, and Task 1 re-takes it

Decision 0031 rests on the design's prototype run at `5ac363a` (113 lanes minus the
mutation lane: 111 pass; `byte-machine.verify.rejections.chez.source` and `.aot` fail
at three cases) and on PR #83's review reproducing it. Nothing in `src/` or `test/`
has moved since (the diff guard above). This slice does not *assume* that: its first
task applies design §4.1's two hunks in a scratch worktree at its own base and reads
the FAIL lines, because a pricing written from reading named the wrong fixture once
already (Milestone 6's design §8; 0031's Context).

### F2 — eleven shipped `FIND`s land in the constructs this slice edits; one retires, four re-anchor, one re-shapes its `REPLACE`, five stay

Lexed 2026-09-06 from every `byte_machine_mutation(` block whose `FILE` is
`src/byte-machine/verify.sls` (137 blocks; bracket-aware, the full `FIND` text located in
the source), keeping those whose `FIND` lies in `all-out-targets`/`reach-from`
(`:250-266`), `pass-reachability` (`:600-626`), `pass-eof-execution`'s `§16.2:909`
membership (`:1165-1196`), or `parked?`/`span-flow` (`:1629-1692`). Nine are `SPEC
byte-machine.verify.rejections.chez.source` in Pass 33, whose `_run` is at `:6575`
today; two — "verify: a new diagnostic code appears with no fixture and no pinned
row" and "verify: an emission site is relabelled with another existing code" — are
`SPEC byte-machine.unit.diagnostic-census.chez.source` in the diagnostic-census pass
(`:11133`, `:11150`), and stay:

| LABEL | `FIND` (first line, at `ba5c426`) | after this slice |
| --- | --- | --- |
| "verify: a sequence node's eof-target does not feed reachability (arm 2, all-out-targets)" | `(define (all-out-targets n)` (`:250`) | **retires** — its text is deleted; the decision it named (a sequence node's eof-target feeds reachability) is pinned by the new group's sequence-dispatch pair (Task 4 Step 1) |
| "verify: pass 7's EOF half keeps taking byte edges" | `(map (lambda (t) (cons (node-name n) t)) (eof-step n))` (`:1688`, `span-flow`'s `eof-edges`) — `FIND` survives; its `REPLACE` names `(all-out-targets n)` | **`REPLACE` re-shaped** to the retired walk inlined — an unbound identifier is a raise, not a comparison (Task 4 Step 3) |
| "verify: the :909 walk does not start at the entry (D-1)" | `(or (eq? (node-name n) (machine-entry m))` at 32 spaces (`:1169`, the membership's copy) | **re-anchors** onto the unified `parked?`'s line (13 spaces); `REPLACE` moves with it |
| "verify: the :909 start set is not gated on byte-reachability" | `(if (and (memq (node-name n) br909)` (`:1168`) | **re-anchors** onto `parked?`'s `(and (memq (node-name n) br)` — the gate now lives in one place |
| "verify: the :909 start set enumerates a kind instead of deriving the EOF route" | `(symbol? (node-eof-target n))))` at 36 spaces (`:1183`) | **re-anchors** onto `parked?`'s `(symbol? (node-eof-target n)))))` (13 spaces, five parens) |
| "verify: a span end is not treated as a parked state" | the two lines `(span-end-node? n)` / `(symbol? (node-eof-target n))))` at 36 spaces (`:1182-1183`) | **re-anchors** onto the same two lines in `parked?` |
| "verify: reachability never reports an unreachable node" | `(make-diagnostic 'unreachable-node (node-name n) "node is unreachable")` (`:624`) | stays — the emission line does not move |
| "verify: a new diagnostic code appears with no fixture and no pinned row" | the same line (`:624`) | stays |
| "verify: an EOF cycle through pause continuations is not reported" | `((cycle)` (`:1188`, the membership's `case`) | stays — the `case` survives, only its guard changes |
| "verify: an emission site is relabelled with another existing code" | `(list (make-diagnostic 'eof-reachable-stop (node-name n)` (`:1186`) | stays |
| "verify: pass 7's edge set omits the EOF routes" | `(append byte-edges eof-edges)))` (`:1691`) | stays |

No shipped `FIND` anchors on a comment this slice rewrites (`:600-618`, `:647-650`,
`:256-258`, `:1608-1614`, `:1629-1645`): the lexer found none, and Task 1 Step 3
re-runs it at the base. `SITES` is asserted exactly at 1 in both directions, so a
`FIND` that stops matching fails **inside the mutation lane at Pass 33's `_run`** — a
`SEND_ERROR` from `MutationRunner.cmake`, printed under a "suite complete" line.
Re-anchor a moving `FIND` together with its `REPLACE`, then read the pair and ask what
single decision separates them.

### F3 — two disjuncts of the parked set are unpinned today, and the unification is what makes them pinnable

Measured: every shipped `FIND` containing `(pause-node? n)` or `(callback-node? n)`
sits in `pass-zero-progress`'s REPORT set or walk, `zero-width-edges`,
`node-out-edges`, `parked-eof-start` or `span-transfer` — none in the `§16.2:909`
membership (`:1165-1196`) or in `parked?` (`:1646-1651`); `rg -n
"\(pause-node\? n\)|\(callback-node\? n\)" test/support/cmake/SchemeMutationSuite.cmake`
and read each block. So today a mutant dropping the pause or callback disjunct from
the membership is pinned by nothing, and pass 7's `parked?` copy has **no** pin at all — the "inert
disjunct a mutation cannot catch" Milestone 6's design appendix named. With one
`parked?` read by three consumers, each disjunct has a witness: the entry (D-1,
re-anchored), the pause and the callback (two **new** pins, Task 4 Step 4), the span
end and the derived route (re-anchored). **Where the two new witnesses live was
measured by this plan's review, by staging each mutant on the base tree and on the
unified tree**: the pause disjunct's removal fails Milestone 6 Slice ①'s counted case
"the same through a pause continuation is rejected at the pause" in
`verify-tests.sps` — a case the kind already has, as design §5 says. The callback
disjunct's removal fails **nothing** in `verify-tests.sps` on either tree
(`byte-machine.verify.rejections.chez.source` passes with the disjunct gone), and
fails two checks of `unit.kind-position-census`: the axis-A cell
`(callback-pause-continuation stop)` wants `(eof-reachable-stop)` and gets `()`, and
the axis-B self cell `(callback-pause-continuation advance)` wants
`(eof-zero-progress-cycle zero-progress-cycle)` and gets `(zero-progress-cycle)`. A
mutation is witnessed only by its own SPEC lane's program (`AGENTS.md`), so that pin
is declared in the census lane's pass — SPEC
`byte-machine.unit.kind-position-census.chez.source`, the pass that already holds
"verify: a parked callback is classified as if the walk had flowed through it" —
on the axis-A record. Design §5's "each caught by the case that disjunct's kind
already has" is true of the pause and false of the callback in the verify lane;
Task 5 Step 2 corrects it in place.

### F4 — the family's canonical pair cannot reuse `t2-machine`, and `Z` cannot be a stop in the counted control

`t2-machine`'s EOF-only variant *is* the family's REJECTED shape with `Z = fin` —
which is why that case flips — but its ACCEPTED twin (`(t2-machine k #f)`) puts a
byte-reachable byte edge into the finish, a `§16.2:908` violation, so it cannot
serve as the "same machine, `Z` also byte-reachable" half. The new group therefore
builds its own `Z`: a byte-dispatch node `z` whose case and fallback edges land on
`reject` and whose eof-target is `#f` — no finding of its own under either relation,
`unreachable-node` when only `T`'s dead edge reaches it, nothing when the entry also
reaches it by a byte edge. For the counted-consume control `Z` is visited **on the
EOF walk** through `next` (decision 0030 item 5), so a stop there would be
`eof-reachable-stop` at the entry and the control would stop being about
reachability; `z` as built is a dispatch with a `#f` route, which classifies
`default-error` — tier 0 — and the control stays clean.

### F5 — the retired name's vocabulary is seventeen lines, and a sweep is the exit check

`rg -n all-out-targets src/ test/` at `ba5c426` prints seventeen lines: `verify.sls` six
(definition, one call, four comments — `reach-from`'s header `:256`, `pass-reachability`'s note `:602`,
`pass-zero-progress`'s note `:648`, `eof-step`'s comment `:1613`); `verify-tests.sps`
four comment lines (`:716`, `:776`, `:2716`, `:3094`); `SchemeMutationSuite.cmake` seven — the retiring block's four (`:4841`, `:4842`, `:4847`,
`:4851`), two comments (`:5390`, `:6149`) and the `REPLACE` at `:6160`. Every live comment is an instruction and is corrected in place
(Task 3 Step 4, Task 4); after the slice the name survives only where it is
*history*: the retired block's tombstone and the re-shaped mutation's comment, both
saying so.

### F6 — the parent plan's hand-off is the file's last section, so its annotation is an append

`### §25:1611 — Milestone 6 hands the reachability narrowing to Milestone 7` begins at
`:2483` of 2489 lines. A dated paragraph appended under it shifts nothing above it —
the only edit the parent plan admits (`AGENTS.md`: append, never insert). Task 5
Step 1 asserts one hunk at the foot.

### F7 — the unification changes membership, not where a walk starts

`pass-eof-execution` keeps `(eof-terminal m (parked-eof-start m n))` per parked node;
`parked-eof-start` is untouched, so a parked callback still starts at its pause
continuation and a parked counted consume at its eof-target. 0031 item 4's equality
of the two walks is what lets `occupiable` be seeded from `(eof-step n)` of the parked
node (as `span-flow` already is) while the `§16.2:909` verdicts come from
`parked-eof-start`'s answer; this slice does not touch that procedure, and the
mutation "verify: a parked counted consume is classified from its own name" (its
`FIND` in `parked-eof-start`) is one of the untouched pins.

### F8 — one stale citation is corrected in passing

`reexec-targets`' integer-accumulate arm (inside `pass-zero-progress`, `:742`) cites
`§12.7:772` for the overflow edge being non-consuming; that line is blank and the
sentence is `§12.7:773` (0031's Context; decision 0030's annotation). This slice
edits the file and corrects the comment; it is the only edit outside the constructs
F2 names, and it moves no `FIND` (no shipped `FIND` anchors on that comment — checked
in Task 1 Step 3).

### F9 — three pins whose `FIND` sits elsewhere change their OBSERVATION, and F2's census cannot see them

F2 lists pins by where their `FIND` is. The narrowing also changes what some mutants
*produce*, wherever their text sits, and the re-baseline renames one check label a
pin reads. This plan's review applied Tasks 2-4 in a scratch worktree and ran the
whole mutation lane: totals 58 passes / 524 mutations as predicted, and **three
shipped pins caught for the wrong reason** — none of them in F2's table:

| LABEL (Pass 33) | `FIND` sits in | what changed |
| --- | --- | --- |
| "verify: a zero-width node's targets are not out-targets" | `node-out-edges` | its pin bridges two records with `.*` — "…nothing unreachable" and "…non-eof-into-finish". The first record no longer fails: the fixture's zero-width node `act` **is the entry**, so it is parked and `after`/`oops` are visited by the entry's EOF walk (`eof-step` reads `zero-width-edges` directly), occupiable even when the mutant hides them from `node-out-edges` |
| "verify: the :908 check is not gated on byte-reachability" | the `§16.2:908` block | its pin is the t2 accept case's check label "…: none rejected" (`rg -n "none rejected" test/support/cmake/SchemeMutationSuite.cmake` prints exactly that one line), which Task 2 Step 1 renames |
| "verify: a counted consume's next is not an out-edge" | `node-out-edges` | its pin expects `got ..unreachable-node` on the entry-stop fixture; under the narrowing the entry, a counted consume, is parked and its walk visits `next`'s target through `eof-successors` (0030 item 5), so nothing there is unreachable any more |

Each is re-measured and re-pinned in Task 4 Step 2b — strengthened, never loosened
(`AGENTS.md`: an uncaught or wrongly-caught mutation is a finding about the tests). The
rule this finding adds: **after Task 3 lands, run the whole mutation lane before
writing a new pin**, and read every "wrong reason" as a pin whose observation moved.

---

## 2. What this slice ships

One PR, **two commits** (design §11): a source commit carrying `verify.sls`,
`verify-tests.sps` and `SchemeMutationSuite.cmake` together — tests written first
and red, the walk, the pins, `EXPECTED_MUTATIONS` — and a documentation commit. A
source change that landed without its re-baselined cases is red; a re-baseline that
landed without the walk is red; a walk that landed without its pins fails the mutation
lane at Pass 33's `_run`. So Tasks 2-4 are one commit and the plan says so at each
step.

- `verify.sls`: one `parked?` with the superset membership, read by
  `pass-eof-execution`, `span-flow` and the new `occupiable`; `eof-visited`, the walk
  factored out of `span-flow`; `occupiable` = `byte-reached` ∪ `eof-visited`;
  `pass-reachability` reads it; `all-out-targets` deleted; five comments corrected in
  place.
- `verify-tests.sps`: the three cases re-baselined exactly as 0031 item 5 states; a
  new group, "reachability is the occupiable relation (decision 0031)", with the
  family's REJECTED/ACCEPTED pair for each of the three kinds, one transitive case,
  and the two ACCEPTED controls, the rejected node asserted by name, with a sentinel
  over the kinds.
- `SchemeMutationSuite.cmake`: one retired with its reason in place, four
  re-anchored, one `REPLACE` re-shaped, three re-pinned where the narrowing moved
  their observation (F9), three added — one of them in the census lane's pass (F3);
  `EXPECTED_MUTATIONS` re-measured.
- The parent plan's hand-off annotated (appended); the design's §5 and Status header
  corrected; `CHANGELOG.md` and `README.org`; decision 0031 untouched unless Task 1's
  re-measurement disagrees with its Context.

**Not shipped, on purpose:** any change to `parked-eof-start`, `classify`,
`eof-terminal`, `byte-reached`, `node-out-edges`, the diagnostic record (Slice ①), or
any file under `src/` other than `verify.sls` (design §4.9's gate).

---

## Global Constraints

- **Authority order.** Decision 0031, then design §5/§4.1, then the parent plan. Where
  an authority is wrong, **stop and say so**; the design's pricing hand-off was wrong
  in two of three predictions and the record says so.
- **No new diagnostic code, no new emission site.** The census must read
  `(unreachable-node 1)` and thirty codes over fifty-six sites at the slice's head;
  the kind × position matrix's "exactly three cells prune the sink" must read 3.
- **No `(cons 'SYM …)` form enters `verify.sls`**: `edge-roles-in-source` collects
  every one as an edge role and the matrix goes red on its baseline.
- **`SITES` is asserted exactly at 1 in both directions** (F2). Before adding any line
  to `verify.sls`, check it does not duplicate a pinned line — `eof-visited`
  reproduces `span-flow`'s seed line `(if (parked? m n br) (eof-step n) '())` and
  its walk verbatim, and *no shipped `FIND` anchors on those lines* (F2's table is
  total over the range) — and re-check after the edit with the lane itself.
- **Every new case asserts both directions**: REJECTED under `unreachable-node` with
  the node named, and the same machine ACCEPTED when `Z` gains a byte route; the two
  controls are ACCEPTED and each names the shape it excludes from the family.
- **Sentinels read observed counts**: the group's loop over the three kinds asserts
  it drove 3.
- **Pins go into Pass 33 before its `_run`** (`:6575` today), never in a new pass —
  except the callback-disjunct pin, which goes into the census lane's existing pass
  (F3), before *its* `_run`. `EXPECTED_PASSES` stays 58; `EXPECTED_MUTATIONS` is re-measured from the harness,
  not computed — the arithmetic below (522 − 1 + 3 = **524**) is a prediction the tree
  overrides.
- **Prefer the comparison catch.** Every new mutant is judged by how many cases it
  fails and whether they fail identically: a uniform crash across the suite pins
  nothing. Pin a case-name tail plus a check label, no `.*` between `expected` and
  `got`, the measured `got` spelled in full, `got .[)]` for an empty list, and each pin
  matching **once** among its own mutant's `FAIL ` records.
- **Filter suite output for the failure signatures** — `CMake Error`, `wrong reason`,
  `UNCAUGHT`, `tests passed` — and the exit status. The mutation suite prints "suite
  complete" on the way to failing.
- **Record vs instruction.** Source comments and test comments naming the retired
  walk are instructions, corrected in place; the parent plan's hand-off and decision
  0031 are records — the first is annotated by an appended paragraph, the second is
  not touched unless Task 1 contradicts it, and then by a dated note with a header
  bullet.
- **Both lanes, always.** Every new case runs in `.chez.source` and `.chez.aot`; the
  `release` preset runs both.
- **Design §4.9's gate at every step**: `git diff --stat 5ac363a..HEAD -- src/
  ':!src/byte-machine/verify.sls'` prints nothing; `git diff --stat main..HEAD --
  test/fixtures` prints nothing (no golden moves).

---

## Task 1 — Re-take the measurement at the base, and the pin census

**Files:** none modified. A detached scratch worktree, removed at the end.

- [ ] **Step 1: Confirm the base has not moved under the record**

```bash
git fetch -q origin && git merge-base --is-ancestor 50516af main && echo base-ok
git diff --stat 5ac363a..main -- src/ test/
git log --oneline -1 main
```
Expected: `base-ok`; the diff prints **nothing** (if it prints anything, the
measurement below is the only one that counts and 0031's Context gets a dated note in
Task 5 Step 3); the last line is the merge commit of PR #85 — record its hash, it is
this slice's base and every citation below is against it.

- [ ] **Step 2: Apply the prototype in a scratch worktree and run the selection minus the mutation lane**

```bash
W=$(mktemp -d)/proto && git worktree add --detach "$W" main
```
In `$W/src/byte-machine/verify.sls`, apply design §4.1's two hunks exactly: in
`pass-reachability`, `(reached (reach-from m all-out-targets))` becomes `(reached
(occupiable m))`; beside `byte-reached`, add

```scheme
  (define (occupiable m)
    (let* ((nodes (machine-nodes m)) (br (byte-reached m)))
      (append br
              (let walk ((frontier (apply append
                                          (map (lambda (n) (if (parked? m n br) (eof-step n) '()))
                                               nodes)))
                         (seen '()))
                (cond ((null? frontier) seen)
                      ((memq (car frontier) seen) (walk (cdr frontier) seen))
                      (else
                       (let ((n (lookup nodes (car frontier))))
                         (walk (append (if n (eof-step n) '()) (cdr frontier))
                               (cons (car frontier) seen)))))))))
```
Then:

```bash
cd "$W" && cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null && ctest --preset release -E scheme-mutation 2>&1 | rg "tests passed|Failed|FAIL " 
```
Expected, as literals: the totals line reads **`98% tests passed, 2 tests failed out of
113`** (the two failures are `byte-machine.verify.rejections.chez.source` and `.aot`),
and the `FAIL` lines are exactly these three per lane, no others:

- `§16.2:908 is gated on byte-reachability, for every kind (Slice ⓪b).an EOF-only-reachable byte edge into a finish is accepted: none rejected -- expected (), got ((integer-accumulate unreachable-node) (sequence-dispatch unreachable-node) (byte-dispatch unreachable-node))`
- `a benign EOF verdict never outranks a stop in a join (Slice ⓪b).a `default-error` sibling does not mask the stop: eof-reachable-stop survives the join -- expected ((eof-reachable-stop . s0)), got ((unreachable-node . rj2) (eof-reachable-stop . s0))`
- `the span-state lattice (§16.2:899, :900, :907).a node no execution can occupy contributes no state (0029 item 3): the span end on the untakeable byte edge is not reported -- expected (), got (unreachable-node unreachable-node unreachable-node unreachable-node)`

**If any other case fails, or any of these passes, stop**: decision 0031's Context
and design §3.2 item 1 are wrong about the tree, and the record is annotated before
any code lands. (This plan's review reproduced the three lines verbatim at
`ba5c426`'s tree: 111 of 113, the two lanes, nothing else.) Then `cd - && git worktree remove --force "$W"`.

- [ ] **Step 3: The pin census, total over the constructs this slice edits**

Lex `SchemeMutationSuite.cmake` bracket-aware (split on `byte_machine_mutation(`;
`FILE src/byte-machine/verify.sls`; the **whole** `FIND` text located in `verify.sls`
at the base), and list every block whose `FIND` intersects the line ranges of
`all-out-targets`/`reach-from`, `pass-reachability`, the `§16.2:909` membership,
`parked?`/`span-flow`, or `reexec-targets`' accumulate comment. Expected: **exactly
the eleven LABELs of F2**, each at the line F2 names (re-measured against the base);
**no** block whose `FIND` includes a line of the five comments Task 3 Step 4 rewrites
or the `§12.7:772` comment; and `rg -c "\(symbol\? \(node-eof-target n\)\)" test/support/cmake/SchemeMutationSuite.cmake` prints **4** (one comment, three
`FIND`/`REPLACE` lines). Record the list; Task 4 walks it by LABEL.

---

## Task 2 — Tests first: the three re-baselines and the new group (red)

**Files:**
- Modify: `test/common/verify-tests.sps`

- [ ] **Step 1: Re-baseline the three cases, each keeping the property it tests**

*The `t2-kinds` accept case* ("an EOF-only-reachable byte edge into a finish is
accepted", group "§16.2:908 is gated on byte-reachability, for every kind (Slice
⓪b)"): keep the loop and its `seen` sentinel ("all eight kinds driven" 8). Collect
per kind the whole `(code . node)` list (not just codes), and replace the `"none
rejected"` check with two: the `§16.2:908` property it always tested — no
`non-eof-into-finish` for any kind — and the narrowing's witness, the whole alist:

```scheme
(check-equal "the finish behind a dead byte edge is unreachable for the three input-reading kinds, and nothing else is reported"
             (reverse bad)
             '((byte-dispatch (unreachable-node . fin))
               (sequence-dispatch (unreachable-node . fin))
               (integer-accumulate (unreachable-node . fin))))
```
where `bad` collects `(cons k pairs)` for every kind whose list is non-empty, in
`t2-kinds` order. Pause, field-action, field-branch, callback and counted-consume
keep `fin` occupiable (the walk flows through their zero-width successors, and
through `next`), so they contribute nothing. Update the case's comment: the edge is
untakeable AND, for the three kinds whose byte edges are dead at EOF, the finish
behind it is a dead node under `§16.2:897` (0031 item 2; 0023's second Consequence,
amended). **Renaming "none rejected" moves one pin that reads it** — "verify: the
:908 check is not gated on byte-reachability" (F9); Task 4 Step 2b re-pins it.

*The join case* ("a `default-error` sibling does not mask the stop"): the whole-list
`check-equal` becomes `'((unreachable-node . rj2) (eof-reachable-stop . s0))` — the
order is `verify-machine`'s `append` order, `pass-reachability` before
`pass-eof-execution`. Keep the label; add one line to the comment: `rj2` is reachable
only through `x`'s dead fallback edge.

*The 0029 item 3 case* ("a node no execution can occupy contributes no state (0029
item 3)"): keep the label of its check **verbatim** — "the span end on the
untakeable byte edge is not reported" is the `EXPECT_OUTPUT_MATCHES` of "verify: pass
7's EOF half keeps taking byte edges" — and assert `(code . node)` pairs:
`'((unreachable-node . cl) (unreachable-node . exit) (unreachable-node . done)
(unreachable-node . fin))` (machine-node order: `cl`, then `span-tail/exit`'s three),
plus a second check that no span code is present. Rewrite the comment's sentence
"`pass-reachability` walks `all-out-targets`, so it crosses the eof-target and then
keeps taking byte edges and calls `cl` reached" to what the pass does after 0031:
`cl` and everything behind it are unoccupiable and reported as such, and pass 7 must
still not report the unmatched end.

- [ ] **Step 2: The new group**

After the `§16.2:898` gate group (before "the thirteenth kind in the verifier
census"), add:

```scheme
;; --- reachability is the occupiable relation (decision 0031) -----------------
;;
;; `pass-reachability` walks byte-reached ∪ the EOF walk from the parked set --
;; the relation §16.2:908/:909 and pass 7 already use -- and no longer
;; `all-out-targets`, which crossed an eof-target and then kept taking byte
;; edges. The family whose verdict changes is `E ->(eof) T ->(byte) Z`: T
;; reachable only through an EOF route and one of the three kinds whose byte
;; edges are dead at EOF, Z distinct from T and reachable only through such an
;; edge. Each kind is asserted BOTH ways -- Z dead, rejected by name; the same
;; machine with Z also byte-reachable from the entry, accepted -- and the two
;; shapes a reader will try are ACCEPTED controls: Z = T (a self-loop; T is
;; occupiable through the EOF route) and T a counted consume (its `next` is an
;; EOF successor, decision 0030 item 5).
```
with helpers local to the group: `z` = `(make-byte-dispatch-node 'z (list (case-to
'reject)) (make-edge 'reject 'reexecute) #f #f)`; `T` per kind with its byte edge to
`z`, its fallback/mismatch/nondigit edge to `reject` and eof-target `reject` —
byte-dispatch `(make-byte-dispatch-node 't (list (make-byte-case (make-exact-byte-matcher 1) (make-edge 'z 'advance) #f)) (make-edge 'reject 'reexecute) 'reject #f)`,
sequence-dispatch `(make-sequence-dispatch-node 't (list (make-sequence-case '(1) 'z #f)) (make-edge 'reject 'reexecute) 'reject #f)`,
integer-accumulate `(make-integer-accumulate-node 't 'n 10 'z (make-edge 'reject 'advance) 'reject 'reject #f)`;
the entry `start` a byte-dispatch whose case 0 and fallback land on `reject` and
whose eof-target is `t`, plus — in the ACCEPTED twin only — a second case, byte 1,
`(make-edge 'z 'advance)`; the machine `(make-machine 'occ 'start (list
(make-uint-field 'n 8 0 #f)) '() '() errs (list start t z (make-error-node 'reject
'rejected #f)) 'default-eof #f)`; and a `findings` projection to `(code . node)`
pairs (the join case's inline `map`). Cases:

1. **The pair, per kind** — one `for-each` over `'(byte-dispatch sequence-dispatch
   integer-accumulate)` with a `driven` counter asserted `3` at the end, and per kind:
   `check-equal "<kind>: Z reachable only through T's dead byte edge is unreachable"`
   → `'((unreachable-node . z))`; `check-equal "<kind>: the same machine with Z
   byte-reachable from the entry verifies clean"` → `'()`. Build the labels with
   `string-append` from the kind's name so the three pairs are three distinct
   `(case, check)` records.
2. **Transitively** (byte-dispatch): `z`'s eof-target is a finish `fin` reachable
   through nothing else → `'((unreachable-node . z) (unreachable-node . fin))`, in
   machine-node order.
3. **Control: `Z = T`** — `t`'s case edge is `(make-edge 't 'advance)` and no `z` exists
   → `'()`.
4. **Control: a counted consume as `T`** — `(make-counted-consume-node 't 'n 'z 'reject
   #f)` → `'()`; the comment says why `z` is not a stop (F4).

Before committing a label, check it against every pin in Pass 33: no new check label
may contain a shipped `EXPECT_OUTPUT_MATCHES` as a substring (`rg -o 'EXPECT_OUTPUT_MATCHES.*' test/support/cmake/SchemeMutationSuite.cmake` over the pass's range, each literal core grepped against the new labels). Expected: no hit.

- [ ] **Step 3: Run the verify lane and read the red**

```bash
cmake --preset dev >/dev/null && cmake --build --preset dev >/dev/null && ctest --preset release -R 'verify.rejections' 2>&1 | rg "FAIL |tests passed"
```
Expected: both lanes fail, and the failing checks are exactly: the three re-baselined
checks of Step 1 (each with `got` equal to the *old* verdict), the three per-kind
REJECTED checks (`got ()`), and the transitive check (`got ()`); the three ACCEPTED twins and the two controls **pass already** — they are accepted
under both relations, which is what makes them controls. Measured by this plan's
review: per lane, 171 cases, 5 failed cases, 7 failing checks, exactly these. Any
other failure means a fixture is wrong, not the verifier; fix the fixture. Do not
commit.

---

## Task 3 — The source change: one parked set, `occupiable`, and the retirement

**Files:**
- Modify: `src/byte-machine/verify.sls`

- [ ] **Step 1: One `parked?`, the superset**

Replace pass 7's `parked?` and its "SECOND HAND-WRITTEN COPY" comment with the one
procedure and a comment that says what it is now:

```scheme
  ;; THE parked set: §16.2:909's start set, decision 0023 item 3's "states an
  ;; execution can be PARKED on", in ONE procedure with three consumers --
  ;; `pass-eof-execution` (which nodes start a walk), `span-flow` (which nodes
  ;; seed pass 7's EOF edges) and `occupiable` (decision 0031: which nodes an
  ;; execution can occupy). Byte-reachable, and one of: the entry (a fresh
  ;; parser sits here without having executed it); a pause; a callback (its
  ;; pause outcome parks the parser -- `parked-eof-start` says where its walk
  ;; starts); a span end (its data callback's pause parks the parser on the
  ;; completion substep, Milestone 5 Slice ③); or a node carrying its own EOF
  ;; route — the derived `symbol?` test over `node-eof-target`, which every
  ;; input-reading kind satisfies (written without its parens here, so the count
  ;; 0031 states stays 2: one code site, one comment in `parked-eof-start`). Until decision 0031 this disjunction was
  ;; written twice by hand and the copies differed by `span-end-node?` -- inert
  ;; for pass 7 and for occupiability alike, because a byte-reachable span end's
  ;; `next` is already a byte out-edge (measured either way). The next kind that
  ;; can pause is added HERE and nowhere else.
  (define (parked? m n br)
    (and (memq (node-name n) br)
         (or (eq? (node-name n) (machine-entry m))
             (pause-node? n)
             (callback-node? n)
             (span-end-node? n)
             (symbol? (node-eof-target n)))))
```

In `pass-eof-execution`, the `§16.2:909` membership's inline `(and (memq (node-name
n) br909) (or …))` becomes `(parked? m n br909)`; move its two inline notes (the
Slice ② callback sentence, the Slice ③ span-end sentence) into the comment above,
which already carries their content; the `case` over `(eof-terminal m
(parked-eof-start m n))` and its two `make-diagnostic` sites do not move (F2: three
pins anchor there).

- [ ] **Step 2: `eof-visited` and `occupiable`**

Directly after `parked?`:

```scheme
  ;; The EOF half of decision 0027 item 1's relation as a VISITED SET: a DFS
  ;; over eof routes from the parked set, never taking a byte edge -- once an
  ;; execution takes an eof-target it can never feed again (§12.2's
  ;; finish-ready row). Factored out of `span-flow` by decision 0031 so that
  ;; pass 7 and `pass-reachability` read one walk: one census, two views.
  (define (eof-visited m nodes br)
    (let walk ((frontier (apply append
                                (map (lambda (n) (if (parked? m n br) (eof-step n) '()))
                                     nodes)))
               (seen '()))
      (cond ((null? frontier) seen)
            ((memq (car frontier) seen) (walk (cdr frontier) seen))
            (else
             (let ((n (lookup nodes (car frontier))))
               (walk (append (if n (eof-step n) '()) (cdr frontier))
                     (cons (car frontier) seen)))))))

  ;; Decision 0031: the nodes an execution can OCCUPY -- byte-reached, plus
  ;; every node the EOF walk from the parked set visits. `pass-reachability`
  ;; reads it, and "unreachable" (§16.2:897) means "unoccupiable".
  (define (occupiable m)
    (let* ((nodes (machine-nodes m)) (br (byte-reached m)))
      (append br (eof-visited m nodes br))))
```

In `span-flow`, `(eof-nodes (let walk … ))` becomes `(eof-nodes (eof-visited m nodes
br))`; its comment above the binding moves to `eof-visited`. `eof-edges` and the final
`(append byte-edges eof-edges)` are untouched (two pins anchor there).

- [ ] **Step 3: `pass-reachability` reads it; `all-out-targets` goes**

`(reached (reach-from m all-out-targets))` → `(reached (occupiable m))`. Delete
`all-out-targets` and its two-line comment. `reach-from`'s header loses "(node-out-targets,
all-out-targets, ...)" and "Shared by pass-reachability and byte-reached, which differ
only in which edge function they walk": it now has **one caller**, `byte-reached`,
and the comment says so and why the parameter stays (one DFS, named by its edge
function).

- [ ] **Step 4: Five comments corrected in place, and the citation**

- `pass-reachability`'s note (the `*** THIS PASS OVER-APPROXIMATES` block): replaced by
  what the pass does — walks `occupiable`, decision 0031; the family of 0031 item 2 is
  the verdict change; the four-document history collapses to one sentence naming the
  record and the parent's `§25:1611` disposition **by number, not by its title** (the
  title contains "Milestone 7", and Task 5 Step 4 asserts `rg -n "Milestone 7" src/`
  empty).
- `pass-zero-progress`'s note ("`0027` records that it is not, because
  `pass-reachability` walks `all-out-targets` …"): the machine is still not rejected
  by `unreachable-node`, and the reason is now the true one — `t` is occupiable
  through the entry's EOF route (0031's Context, effect (b)).
- `eof-step`'s comment ("It is deliberately not `all-out-targets` …"): the sentence
  becomes history in one clause ("the walk 0027 rejected by name and 0031 retired").
- `reexec-targets`' accumulate comment: `§12.7:772` → `§12.7:773` (F8).
- `byte-reached`'s comment is already right and stays.

Then the vocabulary check:

```bash
rg -n "all-out-targets" src/
```
Expected: **no output**.

- [ ] **Step 5: Run, and read what did not move**

```bash
cmake --build --preset dev >/dev/null && ctest --preset release -E scheme-mutation 2>&1 | rg "tests passed|FAIL "
git diff --stat 5ac363a..HEAD -- src/ ':!src/byte-machine/verify.sls'; git diff --stat main -- test/fixtures
```
Expected: **`100% tests passed, 0 tests failed out of 113`** (the mutation lane is
excluded here and run in Task 4; this plan's review measured the same line on its
prototype of Tasks 2-3); no `FAIL` line; both diffs print nothing. Then read the census and the matrix rather
than assume them: `unit.diagnostic-census` green with `(unreachable-node 1)` among its
pinned sites and 56 sites in total, `unit.kind-position-census` green with "exactly
three cells prune the sink" — the count 3 is asserted by the lane, so green is the
measurement. Do not commit yet (Task 4 lands in the same commit).

---

## Task 4 — Pins: one retired, four re-anchored, one re-shaped, three added

**Files:**
- Modify: `test/support/cmake/SchemeMutationSuite.cmake` (Pass 33, before its `_run`; the header narrative beside `EXPECTED_MUTATIONS`)

- [ ] **Step 1: Retire "verify: a sequence node's eof-target does not feed reachability (arm 2, all-out-targets)"**

Delete the block and leave a tombstone comment in its place: the `FIND` was
`all-out-targets`' definition, gone with decision 0031; the decision it named — a
sequence node's eof-target feeds reachability — is witnessed by the new group's
sequence-dispatch pair (REJECTED when the node behind the eof-target's dead byte
edge is dead, ACCEPTED when the eof-target itself is the only route to a node the
walk visits — the shipped case "a node reached only through the sequence eof-target
is reachable" still asserts that half and still passes, F1). `AGENTS.md`: a mutation
whose decision a later fix subsumes is retired with the reason, never weakened until
green. Correct the comment at `:5390` ("so that all-out-targets adds it for …") to
name `eof-step`, which is what reads `node-eof-target` for the walk now.

- [ ] **Step 2: Re-anchor four, `FIND` and `REPLACE` together**

| LABEL | new `FIND` (in `parked?`) | new `REPLACE` |
| --- | --- | --- |
| "verify: the :909 walk does not start at the entry (D-1)" | `         (or (eq? (node-name n) (machine-entry m))` | `         (or #f` |
| "verify: the :909 start set is not gated on byte-reachability" | `    (and (memq (node-name n) br)` | `    (and #t` |
| "verify: the :909 start set enumerates a kind instead of deriving the EOF route" | `             (symbol? (node-eof-target n)))))` | `             (byte-dispatch-node? n))))` — **four** closing parens, not five: `(symbol? (node-eof-target n))` closes two of its own and `(byte-dispatch-node? n)` one, as the shipped pair `))))`→`)))` already does; the review's prototype with five broke the build |
| "verify: a span end is not treated as a parked state" | the two lines `             (span-end-node? n)` / `             (symbol? (node-eof-target n)))))` | `             (symbol? (node-eof-target n)))))` |

(indentation as the unified `parked?` has it; `SITES` will say if a `FIND` is not
unique). Each mutant now reaches three consumers, so **re-measure every one of the
four** by staging it and running the lane, and keep the shipped pin only if it still
matches exactly once in the mutant's own output. Measured by this plan's review on
the unified tree: the ungated mutant fails four checks (its two on the base — the
pause-chain cycle and "both EOF terminals reported" — plus the 0029 item 3 case and
the transitive case) and its shipped pin still matches; the enumerated mutant fails
six (its five on the base plus "a counted consume inside a span verifies clean
(§10.6:604): no diagnostics -- expected (), got (unreachable-node)") and its shipped
pin still matches; the D-1 and span-end mutants are caught by their shipped pins.
Re-confirm each count (a different number is a different tree), and add a comment to
each saying it was re-anchored by Milestone 7 Slice ⓪ onto the unified `parked?`
with its decision unchanged.

- [ ] **Step 2b: Re-pin the three pins the narrowing changes without moving their `FIND` (F9)**

For each, stage the mutant on the finished Task 3 tree, run the lane, and pin one
measured `(case, check)` record, no `.*` between `expected` and `got`:

- "verify: a zero-width node's targets are not out-targets" — the reachability half
  of its decision needs a fixture the narrowing cannot rescue: add to the case "a
  zero-width node's targets are out-targets, so they are reachable" a second check
  over a machine whose field-action node is reached by a **byte edge from the entry**
  (not the entry itself, so not parked) and whose continuation is a stop nothing else
  names — under the mutant that stop is `unreachable-node`; pin that check's measured
  record. Strengthened, not loosened: the shipped fixture keeps its entry-node check.
- "verify: the :908 check is not gated on byte-reachability" — re-pin on the renamed
  t2 check ("…the finish behind a dead byte edge is unreachable for the three
  input-reading kinds, and nothing else is reported") with the measured `got`: under
  the mutant every kind gains `non-eof-into-finish` beside the three
  `unreachable-node`s. Read the suite's own comment on "verify: a counted consume's
  next is not an out-edge" first — it records this pin as a coarse case-label prefix
  that three mutants satisfied — and pin the whole `expected … got …` record so it
  stops being one.
- "verify: a counted consume's next is not an out-edge" — its named decision (`next`
  is a byte out-edge) is still observable through the `§16.2:908` block, which reads
  `node-out-edges`: a byte-reachable counted consume whose `next` is a finish stops
  being `non-eof-into-finish` under the mutant. Pin that case's measured record
  ("verify: a counted consume whose next is a finish" is in the Milestone 6 Slice ①
  group; read its label from the file), not the entry-stop record the narrowing
  emptied.

- [ ] **Step 3: Re-shape "verify: pass 7's EOF half keeps taking byte edges"**

`FIND` unchanged (`(map (lambda (t) (cons (node-name n) t)) (eof-step n))`);
`REPLACE` becomes the retired walk inlined:

```
  REPLACE [[                              (map (lambda (t) (cons (node-name n) t))
                                   (append (node-out-targets n)
                                           (let ((t (node-eof-target n)))
                                             (if (symbol? t) (list t) '()))))]]
```
Its pin ("the span end on the untakeable byte edge is not reported") is the label
Task 2 kept verbatim; re-measure: the mutant reports the unmatched end at `cl`
beside the four `unreachable-node`s, so the check fails with a `got` that carries a
span code — pin the measured `got` in full. Correct the comment (`:6149`): the
mutant is the retired walk, reproduced inline because the name is gone.

- [ ] **Step 4: Three new pins**

1. **`occupiable` mutated back to the retired walk** — `FIND [[    (let ((nodes (machine-nodes m)) (reached (occupiable m)))]]`, `REPLACE [[    (let ((nodes (machine-nodes m)) (reached (reach-from m (lambda (n) (append (node-out-targets n) (let ((t (node-eof-target n))) (if (symbol? t) (list t) '())))))))]]` — the whole line, binding list closed (the review's prototype compiled and was caught with exactly this text). Caught by comparison: the mutant verifies the family clean, so the new group's REJECTED checks **fail** (`expected ((unreachable-node . z)), got ()`) and the three re-baselined checks fail with their old verdicts — seven checks, measured. Pin the byte-dispatch pair's REJECTED check with its case-name tail: `"per input-reading kind, both ways: byte-dispatch: Z reachable only through T's dead byte edge is unreachable -- expected ..unreachable-node . z.., got .[)]"`.
2. **`parked?` loses the pause disjunct** — `FIND` the two lines `             (pause-node? n)` / `             (callback-node? n)`, `REPLACE` the second line alone. Measured by the review: caught in Pass 33 by Milestone 6 Slice ①'s counted case — pin `"the same through a pause continuation is rejected at the pause: eof-reachable-stop, at the pause -- expected ..eof-reachable-stop . p.., got .[)]"` (re-confirm the node name `p` from the file).
3. **`parked?` loses the callback disjunct** — `FIND` `             (callback-node? n)` / `             (span-end-node? n)`, `REPLACE` the second line alone. **Declared in the census lane's pass, not Pass 33** (F3: no `verify-tests.sps` case observes it — the lane passes with the disjunct gone — and `unit.kind-position-census` fails two checks). `FILE src/byte-machine/verify.sls SPEC byte-machine.unit.kind-position-census.chez.source`, before that pass's `_run`; pin the axis-A record: `"the product is driven and every cell matches its derived verdict: and every one matches §16.2 -- expected .., got ..callback-pause-continuation stop want .eof-reachable-stop. got ..."` — spelled from the measured output, with the `got ()` list's shape asserted.

For each: count the failing cases and check they are the ones the decision reaches
(not a uniform crash); pin resolves to one `(case, check)` pair; no `.*` bridging.

- [ ] **Step 5: Totals**

`EXPECTED_MUTATIONS`: 522 − 1 + 3 = **524** predicted; write the arithmetic into the
header narrative beside `EXPECTED_MUTATIONS` in the file's own shape ("Milestone 7
Slice ⓪, decision 0031: ONE retired … THREE added …, 522 − 1 + 3 = 524"), then run
and let the tree correct the number. `EXPECTED_PASSES` stays **58**.

- [ ] **Step 6: The mutation lane**

```bash
ctest --preset release -R scheme-mutation --output-on-failure 2>&1 | rg "CMake Error|wrong reason|UNCAUGHT|tests passed"; echo "exit ${PIPESTATUS[0]}"
```
Expected: only the `tests passed` line and exit `0`. Any `CMake Error` is a `FIND`
that stopped matching (F2) or a pin caught for the wrong reason (F9); fix the pin,
never the expectation. The review's prototype, run **without** Step 2b and with the
callback pin in Pass 33, printed exactly three "wrong reason" errors and one
`UNCAUGHT` — that signature means Step 2b was skipped or the callback pin is in the
wrong SPEC.

- [ ] **Step 7: The sweep, both directions, with a control**

Re-judge every pin in Pass 33 — and the two census-pass `verify.sls` pins this slice
touches (F2's diagnostic-census two; F3's callback pin in the kind-position-census
pass) against their own passes — against every other mutant's captured output,
in both directions, with the runner's own rule (`byte_machine_mutation_verdict`,
Python `re` DOTALL), as the Milestone 6 sweeps did (`.superpowers/sdd/m6-slice-*-sweep-report.md`
describe the tool, `sweep.py` — a bracket-aware parse, a staged copy, every mutant
applied with its occurrence count asserted, the exact `chez-source.ss` command with
the lanes' environment; copies live in earlier sessions' scratchpads under
`/private/tmp/claude-501/-Users-yuzu-github-byte-machine/*/scratchpad/sweep.py`, and
a fresh one is written to the same rule if none is reachable). Run the control on the
merge base. Expected: **0** collisions among
the pins this slice added, moved or re-shaped; every pre-existing collision the
control also shows is named; each touched pin matches **exactly once** among its own mutant's `FAIL ` records
(`re.findall`, DOTALL, over the `FAIL ` lines only — the harness prints a
`FAIL-CONTEXT id="<group>.<case>"` line beside every failure, so a case-name pin
counted over the raw output reads 2 and means 1). Write the report to the session ledger's directory (`.superpowers/sdd/`, git-ignored
— it is not in the tree, so a report there is not a record) and state the pair and
collision counts, per pass, in the commit message.

- [ ] **Step 8: Commit — Tasks 2, 3 and 4 together**

`feat(verify): reachability is the occupiable relation — one parked set, `all-out-targets` retired, the family pinned (decision 0031)`. The body states the
verdict change (three cases, by label), the totals (release 113/113 plus the mutation
lane; `EXPECTED_MUTATIONS` as measured), the pins by LABEL (retired / re-anchored /
re-shaped / added), and the sweep's numbers.

---

## Task 5 — Both ends, and the status surfaces

**Files:**
- Modify: `docs/plans/byte-machine-implementation-plan.md` (append only), `docs/plans/milestone-7-design.md`, `CHANGELOG.md`, `README.org`, `docs/decisions/0027-reachable-path-for-callbacks-and-spans.md` (a dated note, header bullet and site marker); `docs/decisions/0031-…` only if Task 1 contradicted it.

- [ ] **Step 1: The parent plan — one appended paragraph, never an insertion**

Under the file's last section, `### §25:1611 — Milestone 6 hands the reachability
narrowing to Milestone 7` (F6), append a dated paragraph, bold-led: *"**<date>,
Milestone 7 Slice ⓪ — narrowed, and the pricing above measured.**"* — `pass-reachability`
walks decision 0031's relation, one procedure shared with pass 7, `all-out-targets`
gone; of the three effects priced above, measured by the design's prototype and
re-taken by this slice at its base `<hash>`: the family gains `unreachable-node` for
`Z` distinct from `T` with `T` byte-dispatch, sequence-dispatch or integer-accumulate;
the `verify-tests.sps` fixture named does **not** flip (its `Z` is `T`, occupiable
through the EOF route); the matrix's pruning count does **not** move (the sink is
byte-reached in every cell that keeps it); the re-baseline is one file, three cases —
named — plus a new group; census row and count unmoved; counted consume's "new
instance class" `CC →(eof) T →(byte) Z` is in the family exactly when `T` is one of
those three kinds and a counted consume as `T` is not (its `next` is an EOF
successor, 0030 item 5); both ends: the note at `pass-reachability` names 0031, and
this paragraph carries the corrected accounting. Then:

```bash
git diff -U0 -- docs/plans/byte-machine-implementation-plan.md | rg -c '^@@'
git diff -U0 -- docs/plans/byte-machine-implementation-plan.md | rg -o '^@@ -[0-9]+'
```
Expected: **`1`**, and the old-side line number is **≥ 2489** (the file's last line at
`ba5c426`; re-read `wc -l` at the base) — one hunk, at the foot.

- [ ] **Step 2: The design — §5, the Status header, and the Amendments block**

`milestone-7-design.md` is an instruction and is corrected in place: §5's first
paragraph gains the landing date and PR; §5's **Pins** paragraph — which names three
mutations by LABEL — is corrected to the measured census of F2 and Task 4 (one
retired, four re-anchored, one re-shaped, five untouched, three added, with
`EXPECTED_MUTATIONS` as measured), because the design named three by LABEL and delegated the rest to `rg -n -F
"(symbol? (node-eof-target n))"`, which finds the enumerated and span-end pins and
misses D-1 and the ungated one (two under-listed), and neither names the three whose
*observation* the narrowing changes (F9) nor the one whose only witness is the census
lane (F3) — so §5's "each caught by the case that disjunct's kind already has" is
corrected to name the pause's case and the callback's census cell; the Status header moves ("Slice ⓪ delivered <date> (PR #N);
Slice ① next"). The Amendments block indexes the §5 correction, newest first, saying
the plan measured what the design derived.

- [ ] **Step 3: Decision 0027's Context sentence gets its marker; decision 0031 only if Task 1 disagreed**

Decision 0027's Context derives the family's machine (`E`, `T`, a distinct `Z` with a
`reexecute` self-loop) and says of it: "Today `pass-zero-progress` reports
`zero-progress-cycle` at `Z` and the machine is rejected; after the gate it verifies
clean, and no other check replaces that finding." Once Task 3 lands, `unreachable-node`
at `Z` replaces it — which the same paragraph foresaw ("narrowing `pass-reachability`
would shrink the family to empty"), and which 0027's Gate 0 note (2026-09-06) says
this slice marks. So 0027 gets: a header bullet `**<date> (Milestone 7 Slice ⓪)** —
**amends the Context's "after the gate it verifies clean"**: … see the foot of this
file`; a one-line site marker directly under that blockquote paragraph at its
indentation, followed by a blank line; and a short foot note headed `## <date>
(Milestone 7 Slice ⓪) — …` naming the commit that landed the walk and the fixture
that asserts the new verdict (the 0029 item 3 case and the new group). Then run
`docs/decisions/README.md`'s invariant loop: silent.

Decision 0031: if Task 1 Step 2 reproduced the three cases and nothing else, it is
untouched — its Context states the measurement with its commit, and this slice's
commit message and the parent's paragraph record the re-take. If Task 1 found a
difference, 0031 gets a dated note headed `## <date> (Milestone 7 Slice ⓪) — …` with
a header bullet, verb **amends** if a sentence of its Context or item 2 became false,
**annotates** otherwise; the site marker where required.

- [ ] **Step 4: The status surfaces the ritual does not sweep**

`CHANGELOG.md`'s `[Unreleased]` preamble: Milestone 7 (verification and generative
hardening) is **in progress** — Gate 0 discharged 2026-09-06 as decisions 0031-0033
(PR #85), Slice ⓪ closed <date>: `pass-reachability` over the occupiable relation, one
parked set, `all-out-targets` retired, the `E →(eof) T →(byte) Z` family rejected and
pinned, no new code, the census unmoved. `README.org`'s status paragraph (its last
sentence today: "Milestone 7 (verification and generative hardening) is next.") says
the same in two sentences. The parent plan's `Status:` line (line 3, **one physical line; it must stay one**)
ends "…handed to Milestone 7 under §25:1611. Milestone 7 (verification and generative
hardening) is next." — stale once this slice lands; correct that last sentence in
place ("is in progress: Gate 0 discharged 2026-09-06 as decisions 0031-0033, Slice
⓪ delivered <date>") without adding a line, so no `§section:line` moves.
The design's Status header is Step 2's. Then:

```bash
rg -n "all-out-targets" src/ test/ ; rg -n "Milestone 7" src/
```
Expected: the first prints only the tombstone (Task 4 Step 1) and the re-shaped
mutation's comment (Task 4 Step 3), each saying the name is retired; the second
prints **nothing** — `pass-reachability`'s note names decision 0031 now, not a
milestone as receiver.

- [ ] **Step 5: Commit** — `docs: Milestone 7 Slice ⓪ — both ends written, the design's §5 measured, and the status surfaces`.

---

## Task 6 — The whole-branch review, and the close

A read-only review in a detached worktree at the branch head (never
`isolation: worktree`, which checks out `main`), whose prompt carries `AGENTS.md`'s
sentence verbatim — *check what this claims the code or the spec DOES against the code
and the spec, not against the prose* — and asks, in this order: does `occupiable`
equal the prototype's set on every fixture (the three cases and the new group are the
witnesses; the review re-runs them); does every pin in F2's table do what its LABEL
says after the move (read `FIND` and `REPLACE` together); does any check label in the
new group contain a shipped pin's literal core; does the parent plan's paragraph state
the measurement Task 1 took, with its hash; and does `verify.sls` still contain no
`(cons 'SYM …)` form beyond the shipped roles (`edge-roles-in-source` green is the
measurement). Fold findings as further commits on the branch; then the closing ritual
on the owner's go-ahead.

---

## Verification

`release` green in both lanes at **113/113 plus the mutation lane**, the mutation
suite at its re-measured totals (58 passes / 524 predicted — the tree wins), and six
things checkable rather than asserted:

1. **The verdict change is exactly the family**: Task 1's re-take at the base fails
   the three named cases and nothing else on the unmodified tests; after the
   re-baseline every lane is green; the new group's REJECTED cases name `z` (and
   `fin`, transitively) and its ACCEPTED twins and controls answer `()`.
2. **Nothing else moved**: census `(unreachable-node 1)`, thirty codes over
   fifty-six sites; matrix pruning count 3; `git diff --stat 5ac363a..HEAD -- src/
   ':!src/byte-machine/verify.sls'` prints nothing; every golden byte-identical.
3. **One parked set**: `rg -c "symbol\? \(node-eof-target n\)" src/byte-machine/verify.sls`
   prints **2** (the one code site and `parked-eof-start`'s comment; it was 3 — and
   Task 3 Step 1's comment is worded without the parens so it does not add a third),
   and `rg -n "^\s+\(span-end-node\? n\)$" src/byte-machine/verify.sls` prints
   **exactly one** line, inside `parked?` (today it is the membership's, `:1182`).
4. **One walk**: `eof-visited` is read by `span-flow` and `occupiable` and by nothing
   else; `span-flow` no longer defines a walk of its own.
5. **Every `FIND` resolves to one site**, the failure-signature filter returns only
   the `tests passed` line (no "wrong reason", no `UNCAUGHT` — the review's
   four-error signature is the shape of an incomplete Task 4), and the sweep
   reports 0 collisions among the touched pins with each matching once in its own
   mutant's output.
6. **Both ends**: `pass-reachability`'s note names decision 0031; the parent's
   hand-off carries the dated paragraph as the file's last hunk; `rg -n
   all-out-targets src/ test/` prints only the two lines that call it retired.

## Exit

The `§25:1611` hand-off is discharged under `§25:1615`; "unreachable" quantifies over
what an execution can occupy, in one procedure with three consumers; Slice ① starts
against a `verify.sls` whose walks are settled and edits only emission sites and the
record.
