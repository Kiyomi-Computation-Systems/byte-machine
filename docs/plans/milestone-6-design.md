# Milestone 6 Design — Counted consumption

**Status: CLOSED 2026-09-06.** Slice ② delivered 2026-09-06 on `feat/m6-slice-2` (three commits: the
counted-span lane with its retention arm, the close-out, and the whole-branch review's fixes;
114/114, 58 passes / 522 mutations)
and closed the milestone; the parent plan's "§25:1593-1609 — Milestone 6 closes, dispositioned
against the tree" records every criterion, and "§25:1611 — Milestone 6 hands the reachability
narrowing to Milestone 7" the one deferral. Before it: Slice ⓪ delivered 2026-09-06 (PR #77: four source commits — the three
planned and one the pin sweep required — and a documentation commit); Gate 0 discharged 2026-09-06 as decision 0030
(PR #76 = `0247ece`; §4's blockquote and §9's first bullet carry the discharge); Slice ① delivered
2026-09-06 on `feat/m6-slice-1` (three planned source commits, a documentation commit and the pin
sweep's commit; 112/112, 57 passes /
520 mutations) — the parent plan's disposition "§25:1597-1603 and §25:1607-1609 — Milestone 6 Slice ①,
delivered" records it. Milestone 5 closed 2026-09-06 with Slice ④ (PR #71 =
`6bfa8ed`); its close-out audit (PR #72 = `6bc1aca`) and completeness check (PR #73 =
`b470665`) followed the same day. This document is written against **`b470665`** on branch
`docs/milestone-6-design`, `main` at the same commit, tree clean. Measured on 2026-09-06 by
running the complete selection and reading the suite's own declared totals: `release`
**108/108**; Scheme mutation suite **55 passes / 476 mutations** (`EXPECTED_PASSES` and
`EXPECTED_MUTATIONS` at `test/support/cmake/SchemeMutationSuite.cmake`, asserted by the lane
against what actually ran), under Chez Scheme 10.4.1 on `tarm64osx`.

**Every citation in this document was measured on 2026-09-06 against `b470665`.** Parent-plan
citations are `§section:line`; source citations name the **construct** and give a line only
where the construct is not `rg`-able by name. Two classes of staleness are known and neither is
caught by any tool in this repository: a `src/` line number moves when a slice edits the file
above it, and a `§section:line` moves if anything is ever *inserted* into the parent plan's
body rather than appended to its dispositions section. Milestone 5 spent a slice correcting
fifty-five `§14` citations that were one line too high, inherited from its own design — so this
document cites `§14` by rule number as well as by line, and every `file:line` here is to be
re-measured at plan-writing time (§9).

> **Amendments.** This document's amendment law, stated before there is anything to amend, is
> `AGENTS.md`'s "Correct a stale instruction in place; annotate a stale record": a **record**
> here — a measurement, a finding, a count taken against the tree — gets a dated note appended
> and is never rewritten, because a record edited to agree with a later decision stops being
> evidence of anything. An **instruction** — a scope allocation, an obligation handed to a
> slice, a resolution a slice must implement — is corrected in place, because leaving a false
> one is a landmine and what it used to say is in git. Later dated notes are indexed here,
> newest first, each naming the section it amends.
>
> **2026-09-06, Slice ② delivered; the milestone closes** — **corrects §7, §4.11 and §8 in
> place**, all instructions, each where the slice measured what this document had derived: §7's
> oracle 4 is not "every hunk in those two files is a comment" but an EMPTY five-library diff
> (the receiver notes it expected the close-out to rewrite were rewritten by ⓪ and ①); §4.11
> item 5's precedent sentence (Milestone 5's Slice ⓪ "handing its generator work to Milestone
> 7") described a scoping record and a delivery, not hand-offs — this milestone's `§25:1611`
> disposition is the first under that heading that hands something over; §8's reachability
> bullet and the Exit table's `:1608` fragment clause and `:1609` span variant get their dates,
> and that bullet's "three test files" becomes the two it can name. The Status header moved with it.
>
> **2026-09-06, Slice ① delivered** — **corrects §4.10, §6, §9 and the appendix in place**, all
> instructions, each where the slice measured what this document had derived: `count-next` is a
> BYTE position and its self row is `zero-progress-cycle` alone (four sites said "both"; under
> decision 0030 item 6 no EOF walk reaches a non-entry counted consume with a `#f` route);
> `eof-successors` was a bare alias and gains a `cond`, not an arm; the normalizer's counted
> resolver is the fourth, not the third; §6's oracle 3 drops "a mutant that makes both lanes
> agree on a wrong value" (one FILE per mutation and a runtime arm that serves the interpreted
> lane alone make it impossible) and keeps its pin shape; §6's second ordering witness could not
> see the finish order and is replaced by the entry-zero machine; `position-kind-tests.sps` gains
> three producer rows, not two; §9's "at most two commits" is three green source commits. The
> Status header moved with it.
>
> **2026-09-06, Slice ⓪ delivered (PR #77)** — **corrects §4.12 item 2, §5 and the appendix in
> place**, all instructions, each where the plan measured what the design had counted: the
> grammar-body mutations the names library touches are **four**, not two (two re-homed, one
> re-anchored in `compile.sls`, one retired); the slice landed as four source commits (the three
> planned and one the pin sweep required) and a documentation commit, not two commits; `kind-position-census-tests.sps` joins §5's file list;
> and the `ir.sls`, `verify.sls` and test-side tables gain the `node-source-label`,
> `node-case-labels` and S2b rows Slice ① now owes. The Status header moved with it.
>
> **2026-09-06, the owner's decision on §4.12** — **annotates §4.12, §5, §2, §4.11 and §9**:
> items 1 and 2 approved and in scope as Slice ⓪. §4.12's heading and preamble, §5's
> allocation and the §4.11 dispositions are corrected in place as instructions; the decision
> and its date are recorded on each item, and §2's conditional-slice paragraph is left standing
> with a settled line under it.
>
> **2026-09-06, the review of the first draft (`c16f44f`).** Four read-only reviewers — spec
> citations, tree claims, semantics, process — audited the draft before it left the branch, and
> no *record* here has been amended; everything they moved was an **instruction** and was
> corrected in place. Kept as a record because a reader should know what the first draft got
> wrong. The one that mattered: **§4.2 item 3 parked the new kind in the `§16.2:909` set by
> kind**, and the semantics reviewer showed that unnecessary (every parked origin whose count
> may be zero already reaches the node through a walk that item 1's join classifies), inert in
> pass 7, and an over-rejection of the ordinary one-shot "length, body, stop" grammar — because
> a parser parked on a counted consume by `need-input` provably holds a positive count. The
> corrected rule is the callback precedent: `parked-eof-start` gains an arm. §3.2, §4.2, §6,
> the appendix, the Exit table and the Gate 0 plan all moved with it, and the four "both" rows
> are four, not six. The rest: a `§11.2:642` citation that named `boundary` where only
> `§12.7:769` does; a "third" resolver lambda that is the fourth; `member3-drift` credited with
> an arm-count assertion it does not have; a receiver sentence attributed to `verify.sls` that
> lives only in the parent plan; `count-next` derived as an EOF position when the host's `#f`
> route keeps it byte-only; a proving machine whose entry could not tell idle EOF from a
> partial length; three quotations that were not verbatim; and two census comments the
> appendix had missed.

**Governing plan.** The parent plan's `§25` "Milestone 6" subsection is authoritative. Its
Scope list is `§25:1597-1603` and its Exit criteria are `§25:1607-1609`. **This document
changes no scope and rewords no criterion**; where it appears to say something the parent does
not, the parent wins and this document is wrong. Two additions this document *proposes* are
collected in §4.12; the owner approved both on 2026-09-06, and they are in scope as Slice ⓪.

---

## 1. Summary

Milestone 5 left a machine that can call out: callbacks fire, spans hand byte ranges to the
application, and the runtime demonstrably keeps none of them. What the machine still cannot do
is consume a *body*. Every byte-reading construct in the tree examines one byte and dispatches
on it — byte dispatch, sequence prefix states, integer accumulate — so a fixed-length body of
`n` bytes costs `n` dispatches and a hand-written decrement loop, and `§21.3:1145`'s fixed body
and chunk payloads cannot yet be written as the plan describes them.

Milestone 6 adds **one node kind**, the thirteenth and last of `§10.6`'s closed set: **counted
consume** (`§10.6:596-604`), which consumes up to the remaining value of one declared field in
bulk and subtracts exactly what it committed (`§15:872`). It adds no declaration family, no
lifecycle state, no ABI member and no `exec` parameter. Measured: `node?` has **twelve**
disjuncts (`src/byte-machine/private/ir.sls`, the `node?` definition), the encoder's wire tags
run **0-13** with 8 and 9 spent on the two trailing section discriminators (the `put-u8`
census in `encode-normal`), and `current-abi-version` is **5** with three payload members.
After this milestone `node?` has thirteen disjuncts, tag **14** exists, and the ABI is
unchanged.

**Small in surface, and the smallness is the trap.** Counted consume is the first kind in the
tree that is **both** input-dependent (`§11.4:652` lists it beside dispatch and accumulate) and
the owner of a **zero-width route**: `§10.6:600` — "A zero count transitions immediately
without consuming input." Every per-kind site in the verifier partitions kinds into "reads
input" and "zero-width" and gives each family a different answer; this kind needs an arm in
*both* families' consumers, and a site that files it under one family alone is silent, in
exactly the way Milestone 4 Slice ③'s three verifier defects were silent. §3.1 measures that
surface: **nineteen** node-kind branch-selection constructs in `verify.sls`, plus the kind
tables in `interpret.sls`, `normal-ir.sls`, `compile.sls`, `runtime.sls` and ten test-side census
files. The appendix walks every one and states the kind's answer at each.

| Phase | Kind | Produces | Discharges |
|---|---|---|---|
| Gate 0 | decisions only | record `0030` | nothing; unblocks Slice ① |
| Slice ⓪ *(§4.12, approved 2026-09-06)* | hardening | the label-grammar totality and a shared name-grammar library | no `§25` bullet; disposes two obligations whose fallback receiver is this milestone's close-out |
| Slice ① | the node kind | constructor, verifier arms, lowering and tag 14, both executors, the emitted arm, the golden, the census rows | `§25:1597`, `:1598`, `:1601`, `:1602`, `:1603`; exit `:1607`, `:1609`, and `:1608`'s field/cursor/offset clauses |
| Slice ② | span interaction + close | the span-enclosed fixtures, the per-feed placement oracle, the close note | `§25:1599`, `:1600`; exit `:1608`'s fragment clause and `:1609`'s span variant; the milestone close note |

**Dependency order.** Gate 0 before ①, because ①'s verifier arms implement `0030` and a slice
that picks the parked-set rule by accident pins the wrong diagnostic in a fixture. ① before
②, because nothing can be enclosed in a span until the kind exists. ⓪ is independent of Gate 0
and precedes ①, because ①'s new label carrier should join a total check rather than
a partial one (§4.12 item 1).

**The oracle every slice runs under is the interpreter ≡ generated differential**, and this
milestone adds a second layer to it that Milestone 5 did not need: **assert the expected value,
not only that the lanes agree.** `§10.6:603`'s "count completion wins" — the field reaches zero
and execution continues through span and message-complete work *in the same feed*, before any
`need-input` — is a sentence whose wrong reading is symmetric: two lanes that both return
`need-input` first and transition on the next feed agree with each other on every schedule and
disagree with the plan. Milestone 5's own Slice ③ found the callback-failure position kind wrong
in *both* lanes for a slice and a half for exactly this reason (`§Dated`, the `§12.7:770`
disposition). §7's oracle therefore pins the per-feed placement of the completion event as a
value derived from `§10.6:603`, and §6's pins field values against expected numbers.

---

## 2. Why this shape

**Why Gate 0 comes first, and why it is one record.** Every prior milestone opened with a
decision gate and the reason is Milestone 4's Gate 0 plan's: a record's Consequences section is
what removes work from the slice that would otherwise re-derive it. Milestone 5 needed six
records because it added two declaration families, a lifecycle vocabulary and an error domain.
Milestone 6 adds one kind, and every design call here descends from one fact — the kind is
input-reading *and* has a zero-count route — so §4.1 and §4.2 are one record, `0030`. The
remaining resolutions (§4.3-§4.9) are internal shapes or derivations from shipped rules and stay
in this document, as Milestone 4's design kept nine in its §4.6.

**Why there is no seam slice.** Milestones 4 and 5 each opened their scope with a seam slice
that moved every committed artifact once — an ABI version bump, an `exec` parameter, a header
slot — so that later slices could assert "no golden moved" as a gate. **Measured, Milestone 6
moves nothing a shipped machine emits.** The counted-consume arm needs the field slot, its
successor and its EOF routing, all rendered as literals into its own `case` arm; it needs no
new `exec` parameter (`fieldv`, `psr`, `cbv` already carry everything it reads), no payload
member (member 0 already maps field slots), and no header byte (tag 14 is written only by a
machine that contains the kind). Decision 0025's execution note states the rule this rests on —
"a change moving a committed artifact is paid once, before any semantics" — and the measurement
that exempts a trailing addition from it: "the trailing slot-table section moves no artifact,
ever." A kind whose encoding is written only for machines that contain it is that case exactly. So the gate every Milestone 6 slice can assert is stronger than a seam
slice's: **every committed golden is byte-identical and every pinned fingerprint unchanged from
`b470665`**, with one new golden added beside them.

**Rejected: folding Slice ② into ①.** ①'s oracle is the shipped differential tuple — status,
`next`, `consumed`, offset, lifecycle, field values (`§22.4:1264-1267`). ②'s oracle is the
**fragment trace** with per-feed event placement (`§22.4:1269`, `§10.6:603`), a different
fixture family with its own schedule sweep, and `§10.6:603` is the one sentence in this
milestone whose misreading is invisible to lane agreement. Two oracles of different shape are
two slices, planned in one pass and executed in order, on the principle Milestone 5 applied
when it kept its retention oracle out of the span slice. The owner may still fold; the cost is
that §7's placement oracle would be a task inside a slice whose other twenty tasks all pass on
lane agreement alone, which is where a symmetric wrong reading survives.

**Rejected: a Slice ⓪ that is not conditional.** Two obligations name "Milestone 6's close-out"
as their fallback receiver (`§9.3:423`'s grammar half at `make-callback-failure`; `§16.2:886`'s
label clause for eight carriers at `pass-declarations`' label arms), and this milestone must
dispose both — but neither is Milestone 6 scope, and inventing scope at a design gate is the
inverse of the failure Milestone 5's close-out recorded. §4.12 prices both and recommends
approval; the slice exists if the owner approves and the close-out defers with a receiver if not.
**Settled 2026-09-06: the owner approved both**, so §5 is unconditional; this paragraph stands
as the reason the slice was proposed conditionally rather than assumed.

**Why the milestone does not open with the verifier.** Tempting again, because §4.2 describes
seven verifier sites that change. But a verifier arm with no construct to reject is
unwitnessable, and this project has established twice that an unwitnessed arm is how a hole
survives. Each arm travels with the constructor in Slice ①, and the kind × position matrix is
what proves the arms are the right arms — it goes red on the thirteenth `node?` disjunct and
stays red until every one of its cells for the new kind matches a verdict derived from `§16.2`.

---

## 3. What the parent plan already settles

These are settled. A slice that re-derives one is doing work the plan already did, and a Gate 0
record that "decides" one is spending a record on a sentence already written.

- **The constructor's shape**: `(make-counted-consume-node name field next eof-target
  source-label)` (`§9.1:311`), five parameters. `#f` as `eof-target` means the machine default
  EOF error, by the sentence that governs *every* input node: `§9.1:318` — "`#f` as an input
  node's `eof-target` means the machine default EOF error."
- **The six sentences of semantics** — `§10.6:598`'s lead and its five bullets `:600-604`,
  paraphrased in §4.1's table and quoted in the Gate 0 plan: consume up
  to the remaining field value in bulk, subtracting exactly the committed count; a zero count
  transitions immediately without consuming input; input ending first consumes what is
  available and returns `need-input`; the count reaching zero first continues at the target
  with any remaining input; when the two coincide, **count completion wins** and execution
  continues through zero-width, span and message-complete work in the same feed; inside a span,
  normal fragment rules apply.
- **It is input-dependent** (`§11.4:652`) and therefore has an EOF route: `§12.4:725` — "Every
  input-dependent state uses either a state-specific EOF edge or the machine's explicitly
  declared default EOF error." A zero-count transition at EOF is not a contradiction of that
  sentence but a consequence of `§10.6:600`, and §4.2 is where the two meet.
- **The arithmetic**: `§15:872` — "Counted consume performs exact subtraction after determining
  the number of bytes it can commit." The committed count never exceeds the field's value, so
  the subtraction cannot underflow and there is nothing for an error edge to carry — an
  inference, consistent with the constructor's shape: `§9.1:311` gives it no `error` slot,
  unlike a field action's.
- **The emitted lowering**: `§19.2:1013` — "Counted consume: bulk cursor movement using
  available/count minimum." That is the whole of the generated arm's arithmetic and §4.1 adds
  nothing to it.
- **The position kind after a commit**: `§11.2:642` — an advance "commits the examined byte,
  increments the cursor by one, increments the stream offset by one" — applied `n` times, and
  `§12.7:769`'s row, "Error edge after an advance | `boundary` after the committed byte": an
  error reached after a nonzero commit is a boundary after the last committed byte. That is the
  half of §4.1's position rule the plan settles; the zero-count half is a tree convention and
  §4.1 item 3 derives it there, saying what it rests on.
- **What `§21` will do with it**, so the fixtures are shaped by the consumer: `§21.3:1145` —
  "Fixed-length body data uses one span with no span-complete callback. Each nonempty chunk
  payload uses a separate body span with no span-complete callback"; `§21.3:1149` —
  `message-complete` fires after the fixed body; `§21.3:1150` — completion resets message
  fields by explicit actions and loops to request start without resetting the stream offset;
  `§21.2:1107` — a request with neither framing header has an empty body, which is the zero
  count. §6's proving machine is a length-prefixed body in a span with a message loop, because
  that is the shape `§21` needs and the one every sentence above constrains.
- **The unit cases**: `§22.3:1254` — "counted consume with zero, partial, exact, and surplus
  input" — four cases, named, and §6 drives every one in both lanes.
- **One field type exists**, `uint` of width 8, 16, 32 or 64 (`§10.2:489`), and `§29:1754`
  defers "additional field types" outside v0.1. §4.3 turns on that.
- **Reset restores fields to their declared initials** (`§12.5:738`), so a count is restored
  by the same write that restores every other field; nothing here is new.
- **The generator is Milestone 7's** by name (`§25:1618-1619`), and `§22.6:1295`'s "as each
  feature becomes available" was not applied by Milestone 5 to callbacks or spans — measured,
  `rg -c -i 'callback|span'` over `test/support/harness/byte-machine/test/machine-gen.sls`
  returns **0**. §8 records the property-lane decision on that precedent.

**Where the parent stops settling.** It does not say what the verifier does with a node whose
EOF behaviour depends on a field value it cannot see (§4.2). It does not say how a verifier
that cannot see the count should treat the successor for `§16.2:898` — `§11.4:654` decides the
*direction* (a zero-count cycle "can run indefinitely without consuming input") and
`§16.2:913` bounds it ("Normal consuming cycles, including the main HTTP message loop, are
valid"), and §4.2 sits between the two. It does not say whether
a counted consume with a `#f` eof-target is a parked state for `§16.2:909` — and the shipped
proxy for "carries its own EOF route" says no, wrongly (§4.2). It does not define
`§16.2:903`'s "incompatible" (§4.3). It does not say how `§25:1607` — a claim about *structure*
— can be witnessed (§4.7). Those are §4's.

### 3.1 The per-kind defect surface, measured

Milestone 4 Slice ③'s three defects were one shape: a new node kind reached the shared
accessors and missed a hand-written per-kind filter. Milestone 5 added three kinds and its
design measured thirteen branch-selection constructs in `verify.sls`. **Measured at `b470665`**
(`rg -n -- '-node\?' src/byte-machine/verify.sls`, excluding comment-only lines and the
predicate definitions themselves, grouped by enclosing construct): **nineteen** —
`zero-width-edges`, `node-out-edges`, `node-eof-target`, `pass-names`' error-reference filter,
`pass-field-operands`, `pass-overlap`, `pass-sequence-ambiguity`, `reexec-targets`, the
zero-progress REPORT set, `classify`, `parked-eof-start`, `§16.2:908`'s zero-hop entry clause,
`§16.2:908`'s per-edge target test, `§16.2:909`'s parked-set membership, `pass-declarations`'
node walk, `span-node-declaration-diagnostics`, pass 7's `parked?`, `span-transfer`, and
`span-node-diagnostics`. Seven of the nineteen did not exist at Milestone 4's close (measured
against `bafdbe1`). Every one gets an appendix row stating this kind's answer, and — because
this kind sits in both families — **the appendix marks the four rows where the answer is
"both"**, since those are the ones a reader filing the kind under "input-reading, like
accumulate" would get wrong; a fifth row, `parked-eof-start`, is where the two families'
answers must be kept apart.

**The two ratchets Slice ⓪ of Milestone 5 built fire automatically here, and that is what they
were for.** `kind-position-census-tests.sps`'s S2 row derives `node?`'s disjunct list from
`ir.sls` at run time and compares it to the matrix's key set ("the same twelve kinds"), so the
moment a thirteenth disjunct lands that assertion goes red and stays red until a kind row exists
with a cell in every position and a verdict derived from `§16.2`. `diagnostic-census-tests.sps`
reads `verify.sls` as a datum and pins every emission site: **measured now, thirty codes over
fifty-five sites** (the `pinned-sites` table, summed), and §4.3 moves one row by one.

**Measured, and worth stating because it is the number that decides §4.7:** the emitted `exec`
template is `(define (exec state offset bv start end finish? fieldv psr cbv)` — nine
parameters, `compile.sls`'s render template — and `reserved-member-3` holds **twenty-one**
symbols. §4.8 adds one.

### 3.2 Where the spec and the tree already disagree, or are about to

Five things a slice would otherwise discover mid-task and report as its own regression.

1. **`§12.7:770`'s zero-width-machine-action half is still wrong in both lanes**, measured and
   deferred by Milestone 5's close-out with its receiver written at `compile.sls`'s
   `field-action` arm and `interpret.sls`'s `field-step`. **Milestone 6 does not touch those
   arms and does not inherit that half.** The `compile.sls` note also says the constant is
   "owed also by Milestone 6's counted consume if it can fail a callback" — §4.9 disposes that
   clause: it cannot. Slice ① adds a *sibling* arm to `render-state-arm`; it edits neither the
   field-action arm nor `field-step`, and its plan must say so, because "whoever next touches
   these arms" is the receiver and a plan that touches the file will be read as that person.
2. **The two hand-written parked-set disjunctions already differ, and this kind joins neither
   by kind.** `pass-eof-execution`'s `§16.2:909` membership lists `span-end-node?`; pass 7's
   `parked?` does not, and its own comment records the difference as inert and warns that "the
   next kind that can pause has to be added to BOTH". Counted consume cannot pause, and
   although a `need-input` **can** leave `current` on it, a parser parked that way always holds
   a positive count (§4.2 item 3), so its EOF behaviour from a parked state is its EOF route
   alone and the existing `(symbol? (node-eof-target n))` clause admits it exactly when that
   route is worth classifying. The first draft of this document put the kind in both sets by
   kind; the review of that draft showed the disjunct unnecessary in one set, inert in the
   other, and a source of over-rejection — §4.2 item 3 records the corrected rule.
3. **The hole is the zero-count route at FLOW-THROUGH, and it is real.** A counted consume
   reached during `parser-finish!` with a zero count — the entry of a fresh parser whose field
   initial is zero, a pause or callback continuation, a node on an EOF chain — transitions to
   `next` (`§10.6:600`), and `next` can be a stop terminal, `§16.2:909`'s exact prohibition. A
   `classify` arm written on the dispatch pattern (hop to the eof-target; `#f` is the benign
   default) never sees `next`, so such a machine verifies clean and `parser-finish!` answers
   `stopped`. The fix is `classify`'s join over both routes (§4.2 item 1), which every parked
   origin's walk reaches; it is **not** a new parked-set member, because the only parked state
   with a possibly-zero count is the entry, which is already in the set. This is not a defect
   in the tree today, because no kind with both properties exists; it becomes one on the
   commit that adds the constructor unless the same commit adds the arm.
4. **Decision 0023 item 3's "with each node classified as itself" has been false since
   Milestone 5 Slice ②** and carries no note: `parked-eof-start` starts a byte-reachable
   callback's walk at its pause continuation, one edge, because "a state an execution can be
   parked on and the name the EOF walk starts at are two different questions" (its own
   comment). §4.2 item 3 makes counted consume the second kind whose walk starts elsewhere,
   and the Gate 0 plan's Task 2 records both deviations in 0023, since the first never was.
5. **`compile.sls`'s reached-declaration walk is a hand-written kind list**, `'(dispatch
   accumulate)`, deciding which default-EOF declaration reaches the emitted `errs` table. It
   is the site of one of Milestone 4 Slice ③'s three defects, by that file's own comment, and a
   counted consume carries an EOF route in the same slot the two listed kinds do. A machine
   whose *only* default-EOF consumer is a counted consume renders through `index-of` with no
   entry and `render-machine` raises on a machine the verifier accepted. The appendix marks the
   row; Slice ①'s plan owes a fixture of exactly that shape — the accumulate precedent found the
   defect only because the property generator drew it.

**And one hazard that is not a divergence but will mislead a slice.** `pass-reachability`
walks `all-out-targets`, which crosses an eof-target and then keeps taking byte edges, so a
node reachable only through an untakeable EOF edge counts as reached. Recorded in decisions
0023 and 0027, design §4.5 of Milestone 5, the parent plan's dispositions, and — since PR #73
— at `pass-reachability` itself, with the receiver "whoever next narrows reachability, and
failing that by Milestone 6's close-out". Counted consume adds a new instance class (a node
reachable only as `CC →(eof) T →(byte) Z`) and does not narrow anything. §8 prices the
narrowing and hands it on with both ends; Slice ①'s matrix rows must derive their verdicts
under the **shipped** relation, because the matrix's own pruning reads the verifier's
`unreachable-node` answer and a narrowed relation moves its "exactly three cells prune the
sink" count.

---

## 4. Gate 0 — design-call resolutions

Decision-only: no product code, no tests, no CMake. **The next free decision number is 0030**
(measured: `docs/decisions/` holds `0001`-`0029`, contiguous, plus `README.md`). §4.1 and §4.2
are one record. §4.3-§4.9 stay in this design with no record; §4.10 is the list of things this
document deliberately does not decide; §4.11 disposes the obligations addressed to this
milestone; §4.12 collects the scope additions the parent plan does not name.

> **Gate 0 discharged 2026-09-06**, as one record, as §9 planned.
>
> | Record | Carries | Shape |
> | --- | --- | --- |
> | [0030](../decisions/0030-counted-consume-is-input-reading-with-a-zero-count-route.md) | §4.1, §4.2 | two numbered groups under one Context — the executor contract (items 1-4) and the verifier's two answers (items 5-7) |
>
> **The gate transcribed a design the review had already corrected**, so unlike Milestone 5's
> it changed no stated reason while writing: §4.2 item 3's rule had been withdrawn and replaced
> before the record was drafted (this document's Amendments block, the review entry). What the
> gate added is the measurement the record's item 6 rests on — that in `runtime.sls` the only
> return leaving `current` on an input-reading node is `need-input`, at `(>= pos end)` — and
> the record's Context carries it.
>
> One record reaches back: `0030` **amends** decision 0023 item 3's closing clause, "with each
> node classified as itself", which had been false for the callback node since Milestone 5
> Slice ② with no note there; the note records both exceptions and leaves the set's definition
> and its enumeration standing.

### 4.1 The executor contract: one order of tests, and the zero-count check comes first

**The call.** `§10.6:598-604` states a lead sentence and five bullets, and no order of
evaluation. Two orders are
plausible for an implementer arriving with the shipped dispatch arm in hand — that arm opens
with `(if (>= pos end) …)`, the exhausted-input test, and every input-reading arm in both lanes
renders the same preamble first. A counted consume that opens the same way returns `need-input`
(or takes its EOF route) on a zero count at the end of a slice, where `§10.6:600` says it
transitions immediately. **The zero-count test precedes the exhausted-input test**, and the
whole contract, both lanes, is this table:

| Field value `v`, cursor `pos`, slice end `end` | Feed | Finish | Position kind carried to the target |
|---|---|---|---|
| `v = 0` | transition to `next`; nothing consumed | transition to `next` | carried through unchanged (a zero-width step; `§10.6:600`) |
| `v > 0`, `pos ≥ end` | return `need-input` at `pos`; `current` stays here | take the EOF route: a named eof-target hops with `eof`; `#f` is the default EOF error at the node, `eof` at the final offset (`§12.7:771`) | — |
| `v > 0`, `pos < end`, `n = min(v, end − pos)` | field `:= v − n`; cursor and offset `+= n`; **if `n = v`** continue at `next` with the remaining input (`§10.6:602`, and the exact case `§10.6:603`); **else** return `need-input` at `pos + n` | (unreachable: finish supplies no input) | `boundary` (`n ≥ 1` advances, `§11.2:642`) |

Three things this table fixes that those sentences leave open, each with its derivation:

1. **Ordering.** The zero-count row is first because `§10.6:600` says "immediately" and
   `§11.1:638` lets an empty feed advance "already-pending zero-width continuations"; a counted
   consume with nothing left to consume is such a continuation. The same order holds during
   `parser-finish!`: a parked counted consume whose count is zero — the entry of a fresh parser
   with a zero initial, a pause continuation, or a node on an EOF chain — takes `next`, and only
   a positive count is a truncation. This is why the arm **cannot open with the shared
   exhausted-input preamble** in either lane, and §6 says what that costs.
2. **Count completion wins by construction, not by a special case.** Row 3's `n = v` test
   continues at `next` whether or not `pos + n = end`; the exact case of `§10.6:603` is the
   ordinary completion case with no input left, and the executor loop then runs the successor's
   zero-width work before any input-dependent node can return `need-input`. An implementation
   that tests `pos + n ≥ end` before `n = v` is the wrong reading, and it is symmetric across
   lanes (§1).
3. **Position kind.** After `n ≥ 1` committed bytes the kind is `boundary` (`§12.7:769`);
   after a zero-count transition the loop's kind is carried through, exactly as the shipped
   zero-width arms carry it (`runtime.sls`'s field-action arm and `compile.sls`'s
   `zero-width-jump`). **The carried-kind half is a tree convention, not a plan sentence**, and
   it is stated with its boundary: `§12.7`'s table has no row for an error node reached through
   a *non-failing* zero-width route — a field branch's target today, a zero-count route here —
   so the convention is what decides it, and the parent plan's `§12.7:770` disposition disputes
   that convention **only for zero-width machine-action FAILURES**, which this kind cannot
   produce (§4.9). The observable consequence is stated so a fixture can pin it: an error node
   reached through a zero-count counted consume entered over a *reexecute* edge reports `byte`
   at the current offset, as an error node reached through a field branch does today; through a
   counted consume that committed anything, `boundary`.

**What the interpreter's op answers.** One message per shape, on `accumulate-step`'s precedent:
`(count-step node field-vector pos end)` answers `(committed . target)` — `committed` the
bytes to advance, `target` the successor when the count reached zero and `#f` when input ran
out first. The op **commits the subtraction into the field vector** — `interpret.sls`'s own
rule for its field messages, verbatim: "The op RECEIVES the parser's field vector and COMMITS
into it; the runtime only routes the target it answers." The
finish path asks the same message over an empty slice and reads only the target: `(0 . next)`
is the zero-count transition and `(0 . #f)` means "take the EOF route", for which the existing
`eof-target` message gains an arm. A dedicated `count-zero?` message was rejected because the
answer shape already carries the distinction.

**Both lanes write the arithmetic twice, on purpose** (`§18:970-972`, decision 0015 point 3):
the interpreter reads the field's width from `machine-fields` and the emitter renders the slot
and the `min` from the normalized table, so a lowering defect in either stays visible to the
differential. The `min` is exact over exact integers, and a `u64` count above
`(greatest-fixnum)` is a bignum on the only supported runtime (`§15:856`, and Milestone 4's
`field-access-tests.sps` asserts the u64 row crosses it); §6 owes a case where the subtraction
itself is bignum arithmetic.

### 4.2 The verifier: a kind in both families, with `next` an EOF successor and a non-progress edge

**The call.** Every per-kind analysis in `verify.sls` divides kinds into input-reading (an EOF
route of their own; byte edges that make progress) and zero-width (successors reached without
input; no EOF route). Counted consume has an EOF route **and** a successor that can be reached
without input, and the verifier cannot know which applies because the count is a run-time
field value. Four sites need an answer the tree has never given, and one existing proxy gives
the wrong one.

**Resolved, as one rule with four consequences.** *A counted consume's `next` is reached at EOF
exactly when its count is zero, and by a feed without progress exactly when its count is zero;
the verifier cannot decide either at a node the EOF walk arrives at, so there it treats `next`
as both an EOF successor and a zero-progress edge, unconditionally — while a node a parser is
PARKED on by `need-input` provably holds a positive count, so its walk starts at its EOF route.*

1. **EOF classification joins over both routes.** `eof-terminal`'s `classify` gives the kind an
   arm that is the join of the input-reading answer and the zero-width answer: `(eof-verdict-join
   (dispatch-arm eof-target) (join-over (list next)))`. A stop reachable through the zero-count
   route is `eof-reachable-stop`; a cycle through `next` is `eof-zero-progress-cycle`; the
   `#f`-route half is `default-error`, benign. Both halves read the same two helpers the
   dispatch and zero-width arms already read, so the kind adds no third mechanism. This arm is
   the **flow-through** answer — the walk *arrived* at the node, so the count is unknown and
   both routes are live; item 3 is the parked answer, and they differ.
2. **`next` is an EOF successor for pass 7.** `eof-successors` — and through it pass 7's
   `eof-step` — answers `(list next)` for the kind, so the span dataflow follows the zero-count
   route at EOF as it follows a field action's `next`. Item 1 and this item read **one fact from
   one helper**: `classify`'s arm is written over `eof-successors` so the two consumers cannot
   disagree, which is the `zero-width-edges` "one census, two views" rule applied a kind later.
3. **The parked set is unchanged, and `parked-eof-start` gains an arm: a parked counted
   consume resumes on its EOF route.** Both `§16.2:909` disjunctions keep their
   `(symbol? (node-eof-target n))` clause and gain no kind of their own. The ground is an
   invariant of §4.1's table: only rows 2 and 3-partial return with `current` on the node, and
   both leave the field **positive** — a zero count transitions away (row 1) and a completing
   commit transitions away (row 3, `n = v`). Fields are written by machine nodes only
   (`§13:801` makes callback access read-only) and `parser-reset!` moves `current` to the
   entry, so a parser parked on a non-entry counted consume by `need-input` holds a positive
   count at `parser-finish!` and takes its EOF route, never `next`. So a parked counted consume
   is classified from its eof-target, exactly as `parked-eof-start` already starts a parked
   callback's walk at its pause continuation — "a state an execution can be parked on and the
   name the EOF walk starts at are two different questions", that construct's own words — with
   the same exception for the **entry**, which a fresh parser is parked on without having
   executed it and whose count is the field's initial, possibly zero: the entry starts at
   itself and takes item 1's join. A `#f` eof-target is then benign for a parked node, exactly
   as it is for a dispatch, so the proxy's exclusion is correct rather than accidental.

   **The first draft of this document parked the kind by kind, and that was wrong in both
   directions.** It caught nothing item 1 does not — every parked origin whose count may be
   zero (the entry, a pause or callback continuation, a chain) already reaches the node through
   a walk that item 1's join classifies — and it rejected legal machines: `… →(byte) body
   (eof: truncation error; next: stop)` is the ordinary one-shot "length, body, stop" grammar,
   and a walk from `body` joining over `next` reports `eof-reachable-stop` for a stop that no
   EOF path reaches. The review of that draft constructed both machines; Slice ① owes both as
   fixtures, the one-shot grammar asserted ACCEPTED.
4. **`next` joins the zero-progress walk, and the kind joins the REPORT set.** `reexec-targets`
   answers `(list next)` for the kind — the same shape as accumulate's overflow edge, which
   that arm's comment admits unconditionally because `§12.7:772` "makes it NON-CONSUMING" — and
   the report set's kind list gains the predicate in the same commit, on the rule
   `pass-zero-progress`'s own comment states: the walk and the report set move together or the
   half-fix Milestone 3 Slice ② shipped returns.

   **This is a known over-rejection, priced.** The verifier already rejects every loop whose
   termination depends on a field value — `branch → decrement → branch` is a zero-progress
   cycle today, though it terminates after finitely many iterations — and `next` inherits that
   conservatism: `read-count → [branch zero? records → done] → consume(record-size) →
   decrement records → branch` is rejected, although it terminates whenever `records` does.
   The alternative — treating `next` as a progress edge because it *usually* follows a commit —
   accepts a machine that hangs both executors the first time its count is zero, and
   `§11.4:654` forbids exactly that: "Any reachable cycle that can run indefinitely without
   consuming input is invalid." The verifier cannot see that `records` decrements, so it
   cannot tell the terminating loop from the one that runs indefinitely, and it rejects both —
   the conservatism it already applies to every value-terminated loop. **The bound on the
   over-rejection is `§16.2:913`**: "Normal consuming cycles, including the main HTTP message
   loop, are valid" — and every loop `§21` needs (the message loop, the chunk loop) carries a
   byte dispatch that advances, so none of them is touched. A grammar author who needs the
   rejected shape puts a byte-consuming node in the loop; the record states the shape and the
   workaround so the first author to hit it finds a sentence rather than a surprise.

**What does not change, and why each is a derivation rather than an omission.** `§16.2:908`'s
derived block reads `node-out-edges`, which gains the kind's `next` as a byte edge with role
`next`; a byte-reachable counted consume whose `next` is a finish terminal is rejected with no
new code. `byte-reached` is `reach-from` over `node-out-targets`, so bytes flow through the kind
to its successor. `span-transfer` is the identity for the kind and `span-node-diagnostics`
answers nothing: a counted consume inside a span is `§10.6:604`'s explicit case. `pass-names`'
error filter, `pass-overlap`, `pass-sequence-ambiguity` and `pass-declarations`' node walk owe
nothing — the kind names no error declaration, has no cases and names no callback or span. The
appendix carries each as a row with the reason, so the checklist pass asks the row's question
rather than trusting this paragraph.

**Externally observable, which is why it is a record.** Which diagnostic a fixture emits for a
stop behind a zero-count route, and whether a self-targeting `next` is a zero-progress cycle,
are both verdicts a slice would pin in `verify-tests.sps` and in the matrix; a slice that picks
the dispatch-shaped arm by accident pins the hole, and one that parks the kind by kind pins an
over-rejection. Decision 0023's sentence transfers unchanged — "a graph node no execution can
occupy is not a state that originates a traversal" — and this record adds the distinction
`parked-eof-start` already carries for callbacks: where a walk *starts* and what a node does
when a walk *arrives* are two questions, and for this kind they have two answers.

### 4.3 `§16.2:903` has no content beyond field resolution in v0.1

**The call.** "counted consume using an incompatible field" is a required check, and the plan
never says what makes a field incompatible with a count.

**Resolved: the check is the kind's own arm in `pass-field-operands`, it tests that `field`
names a declared field and nothing more, and it reuses `invalid-field-operand` with a message
naming counted consume.** `§10.2:489` admits one field type at four widths and `§29:1754`
defers additional types; every declared field is an unsigned exact integer a count can be drawn
from, and a `u8` holding 255 is as valid a count as a `u64`. So in v0.1 "incompatible" reduces
to "undeclared", which is precisely the reading Milestone 4's design gave `§16.2:904`'s
"incompatible field" for accumulate (its §4.6, and its Exit section's third limitation: "a check
with no independent content … If a later milestone adds a second field type, this disposition
is the record of why no separate check exists to extend"). That design also drew one boundary
for this milestone: `§16.2:903` "arrives with its own construct and its own check, and inherits
nothing" — no shared "field compatibility" abstraction spanning `:903` and `:904`. An arm of its
own, beside accumulate's and not folded into it, honours that; reusing the *code* is not an
abstraction, it is the precedent accumulate itself set. The diagnostic census moves one row —
`(invalid-field-operand 6)` becomes 7 — and is re-baselined in the commit that moves it, never
in a tidying commit.

Rejected: a minted `incompatible-count-field` code. It would spend a code on a check whose only
content is resolution, and the census would carry a code with one site and one fixture that
duplicates accumulate's. When `§29:1754` admits a second field type, this arm is where `:903`
gains content, and a new code can be minted then against the content that exists.

### 4.4 The normalized state and wire tag 14

The kind lowers **1:1** — one source node, one normalized state, no internal states — so
`internal-blocks`' `else` skips it and the debug map covers it through `name->id` with no
new walk. Its state rides the shipped eleven-slot vector without widening: kind
`counted-consume`; `arguments` the one-element list holding the field **name** (as
accumulate's does; the emitter resolves name to slot through `field-slot-width`); `targets` the
successor id; slot 6 the EOF routing in the shipped `(node . id)` / `(default . code)`
convention, through a **fourth** resolver lambda beside `eof-of`, `acc-eof-of` and `seq-eof-of`,
for the reason `acc-eof-of`'s comment gives (each reads a kind-specific accessor; a shared one
would be a bare slot read from the wrong kind's vector); slot 7 the reason when the routing is
`default`. `selector` is `#f`.

The encoding writes **every part** — the principle decision 0019 item 2 states for the error
reason and Milestone 5 Slice ①b applied to every declaration part, "a datum the ABI carries must
be in the fingerprint" (`AGENTS.md`): tag **14**, then the field name, the
successor id, and the EOF routing through the shipped `put-eof-routing`. A different field, a
different successor or a different EOF route is a different machine and must be a different
fingerprint. Machines without the kind write no tag-14 record and encode byte-identically to
today; §2's gate rests on that. The tag is 14 and not "the next after 7" because 8 and 9 are the
trailing section discriminators and 10-13 the Milestone 5 kinds — `normal-ir.sls`'s own comment
forbids spelling any state-kind tag as a literal in prose, so a plan author verifies the `put-u8`
census rather than this sentence.

### 4.5 The emitted arm binds one new local, and the arm's shape follows from §4.1

The generated arm renders §4.1's table with the field slot, successor id and EOF branch as
literals. It binds `v` (already reserved) for the field value and **`n`** for the committed
count — one new emitted local, so `reserved-member-3` grows from twenty-one to twenty-two
symbols, `member3-drift-tests.sps`'s exercised-name list grows by one, and a caller-chosen
output binding named `n` becomes an `invalid-output-binding` contract violation. That last is
`§9.2:376-378` working as designed and is the precedent Slice ② of Milestone 5 set when `o`
joined the list; it is stated so the change to a public set is deliberate rather than
discovered.

**A textual hazard the plan must clear before writing the arm.** The shipped exhausted-input
preamble — `render-exhausted-preamble` — opens with `((id) (if (>= pos end) (if finish? …` and
is pinned at one site; the counted-consume arm needs the same exhausted test *after* its
zero-count test, so it cannot call the helper and must not re-render the helper's lines
verbatim either, or a shipped `FIND` goes from one occurrence to two and the mutation suite
fails at configure ("SITES fails in both directions"). A `cond` with three clauses — zero count,
exhausted, commit — renders no line the preamble renders. The same applies in
`runtime.sls`: the finish loop's `(accumulate dispatch)` arm is the EOF-route body the kind
needs after its zero-count test, and the two arms share it through a factored local (the
`route-byte-step!` precedent, factored for exactly this reason) rather than by copying. And in
`verify.sls`: `parked-eof-start`'s callback clause is pinned on its
`(callback-node-pause-continuation n)` line, so the kind's arm is added as a sibling `cond`
arm (or a second `if` clause) that leaves the callback clause's lines as they are.

### 4.6 The interpreter's `current` needs no new shape

`completion-state`/`completion?` in `interpret.sls` is the census of what `current` may be —
a bare node name, a mid-sequence compound with a byte-list cdr, or a span end's substep
compound with a symbol cdr — and `§18:972` makes that representation load-bearing. A counted
consume parked mid-body re-enters **itself** with the remaining count in the field, so `current`
is its bare name and no third compound is needed. Recorded because the appendix row for that
census would otherwise read as owing an arm.

### 4.7 `§25:1607` is a claim about structure, and only a structural witness can see it

**The call.** "counted consume does not dispatch once per body byte" is an exit criterion — the
executable form of `§3.1:56`'s goal, "Support efficient counted consumption for fixed-length
and chunked bodies" — and no behavioural comparison can witness it: an executor that consumed a
body one byte per loop
iteration would return the same `next`, `consumed`, offset and field value as one that
consumed it in bulk, deliver the same fragments at the same boundaries, and agree with the other
lane on every schedule. The differential is blind to this criterion **by construction**, and a
slice that "discharges" it with a differential case has asserted nothing.

**Resolved: two witnesses, one per lane, both structural.**

- *Generated lane*: the emitted library is read back as a datum (the technique
  `member3-drift-tests.sps` ships) and the counted-consume state's arm is located by id; the
  assertion is that the arm contains **exactly one** `min` application and **no** `(+ pos 1)`
  form. A mutant that renders a per-byte self-loop fails it; the same mutant passes every
  differential lane in the tree.
- *Interpreted lane*: the interpreter's op closure is wrapped by a counting closure —
  `(make-compiled-machine (lambda (msg . args) … (apply op msg args)))`, the shape
  `runtime-tests.sps` already uses for hand-built ops — and a body of one thousand bytes fed in
  one slice produces **exactly one** `count-step` message. The wrapper reaches the op through
  the compiled machine's tagged vector, which is the shipped practice for a test that needs an
  internal (`AGENTS.md`, "widen a public surface when a *user* needs it, never when only a test
  does").

Both are Slice ①'s, and the exit disposition names both. The criterion's other reading — that
the *construct* spares the grammar author a per-byte dispatch loop — is discharged by the
construct's existence and by §6's proving machine, which has no dispatch node inside its body.

### 4.8 The span interaction is the runtime's, not the arm's

`§10.6:604` — "When enclosed in a span, normal span fragment rules apply" — asks for no code
in the kind's arm. The boundary flush runs at the `parser-feed!` seam on every `need-input`
(`span-boundary-flush!`, `§19.3:1024`), reading the mark and the result's `next`; a counted
consume that committed `n` bytes and returned `need-input` at `pos + n` is flushed as
`[mark, pos + n)` exactly as a dispatch that advanced `n` times would be, and the mark's
re-anchor on the next feed (`§14` rule 4, `:833`) is unconditional. The exact case takes the
other path by §4.1 row 3: the successor is reached in the same feed, and if it is the span end
it delivers `[mark, pos)` through the span-end substep, then the completion, before any
`need-input` — which is `§10.6:603` in the flush's own vocabulary and the observable §7 pins.

So Slice ② adds fixtures and an oracle, not a mechanism; the design says so because a reader of
`§25:1599` "span interaction" will otherwise look for the arm's span code and, finding none,
suspect a gap.

### 4.9 Two conditional obligations discharge by finding

Milestone 5 wrote two obligations addressed to this kind, both conditional, and both conditions
are false:

- **`compile.sls`, the `field-action` arm's note:** `§12.7:770`'s `boundary` constant is
  "owed also by Milestone 6's counted consume if it can fail a callback." It invokes no
  callback: its only application-facing effect is through the runtime's boundary flush, whose
  error arm already renders the constant. Discharged by finding; the note is corrected in place
  by Slice ① (it is an instruction), naming this section.
- **The parent plan's `§12.7:770` disposition:** "any declaration it names owes a
  `pass-declarations` arm." The kind names a **field**, and a field reference is
  `pass-field-operands`' cross-reference (decision 0020 item 3), which §4.3 gives it. It names
  no callback and no span, so `pass-declarations`' node walk owes it nothing — the appendix row
  says so explicitly rather than leaving the row blank.

### 4.10 Resolutions that stay in this design and get no record

- **The kind is exported constructor-only from `graph.sls`**, on Milestone 4's and 5's
  precedent for node kinds; its predicate and five accessors stay in the private library. The
  matrix and `ir-tests.sps` import them from `(byte-machine private ir)`, as they do for every
  other kind.
- **The constructor checks local shape only** (decision 0020 item 1): `name`, `field` and
  `next` are symbols; `eof-target` a symbol or `#f`; `source-label` unchecked at construction as
  every label is. Whether `field` is declared is the verifier's (§4.3).
- **The kind is not a `zero-width-edges` member.** That census is "the successors of a
  ZERO-WIDTH node" and `node-out-edges` gives the kind its own arm; making it a member would
  put an input-reading kind under a name that says otherwise, and `eof-successors` gets the
  kind's arm directly (§4.2 item 2).
- **The position-kind producer table gains three rows, not one.** `position-kind-tests.sps` is
  keyed by *producer*: truncation at a parked counted consume (`eof` at the final offset) is a
  new producer of an existing kind; a zero-count transition into an error node over a
  reexecute edge (`byte`, carried) is another; and a zero count reached at the END of a slice
  over an advance edge (`boundary`, carried) is the third — the arm's order and its carried
  kind cannot share a row, since a reexecute edge never reaches the node at a slice's end
  (the slice plan's F13). Both lanes, all three rows.
- **`t2-kinds` in `verify-tests.sps` gains the kind**, unlike the span kinds, which that file
  excludes with a stated reason: a counted consume whose `next` is a finish carries no second
  finding — the host's `#f` eof-target keeps the node out of the parked set, and a flow-through
  join over a finish is tier 0, benign — so the row still isolates `§16.2:908`.
- **A body is not a token.** `docs/reference/callback-span-lifetime.md` §6 already says
  fragment boundaries are feed boundaries; a bulk-consumed body changes nothing in that
  contract and the reference gains one sentence naming counted consume as a body's ordinary
  carrier, not a section.

### 4.11 Obligations addressed to this milestone, each disposed

Five obligations name Milestone 6 or its close-out as a receiver. Measured: `rg -n -i 'milestone
6' src/ docs/decisions/ docs/reference/` returns **four** `src/` sites and nothing else —
`compile.sls`'s field-action note, `runtime.sls`'s `make-callback-failure` note, `verify.sls`'s
`pass-reachability` note, and `normal-ir.sls`'s "Twelve node kinds lower here (§10.6's closed
set, less Milestone 6's counted consume)", which is a **census comment** Slice ① corrects rather
than an obligation (the appendix carries it); the fifth obligation, the label clause, names its
receiver **only in the parent plan's Milestone 5 close note** — the `verify.sls` arm records the
gap and points to the plan, and the plan's own claim that the receiver is "written at that arm
in `verify.sls` as well as here" is half true (gap yes, receiver no). Each of the five is
disposed here so the close-out has a sentence to check against, and every disposition below
that defers names both ends.

1. **`compile.sls` `field-action` arm — the `§12.7:770` constant, conditional.** Discharged by
   finding, §4.9. Slice ① corrects the note.
2. **Parent plan `§12.7:770` disposition — a `pass-declarations` arm, conditional.**
   Discharged by finding, §4.9.
3. **`runtime.sls` `make-callback-failure` — `§9.3:423`'s grammar half.** "Owed by whoever
   next gives the runtime a shared portability predicate, and failing that by Milestone 6's
   close-out." **Scheduled in Slice ⓪ as §4.12 item 2, approved 2026-09-06**, priced there.
   The obligation's second end moves from the parent plan to Slice ⓪'s plan, and the source
   note at `make-callback-failure` is corrected by the commit that closes it.
4. **`verify.sls` `pass-declarations` label arms — `§16.2:886`'s label clause for eight
   carriers.** "Owed by whoever next widens `pass-declarations`' label arms, and failing that by
   Milestone 6's close-out." **Scheduled in Slice ⓪ as §4.12 item 1, approved 2026-09-06**,
   priced there; Slice ① then adds this milestone's own kind as the twentieth carrier under a
   check that is already total. The parent plan's Milestone 5 close note gets an appended
   disposition naming the slice that closed the gap, and the `verify.sls` arm comment that
   forbids widening is corrected in place by the commit that widens it.
5. **`verify.sls` `pass-reachability` — the over-approximation.** "Owed by whoever next
   narrows reachability, and failing that by Milestone 6's close-out." This milestone does not
   narrow it; §8 prices the narrowing and **defers it to Milestone 7**, whose scope is
   "generative and diagnostic hardening of all mandatory verification passes" (`§25:1615`),
   with both ends: the source note re-addressed to Milestone 7, and an appended disposition
   under the parent plan's `§25:1611` heading — Milestone 7's own subsection, the place its
   designer reads first (the two Milestone 5 dispositions already there are a scoping record
   and a delivery; neither hands anything over, and this is the first that does). **Deferred 2026-09-06 by Slice ②**, both ends
   written: the note above `pass-reachability` names Milestone 7 and the adjudication, and
   "§25:1611 — Milestone 6 hands the reachability narrowing to Milestone 7" carries §8's pricing.

`§16.2:911` ("backend limits that would make emission incorrect") remains an orphan with no
owner in any milestone, as Milestone 5's §4.11 and close note record. Naming it is not
claiming it; it is listed so it does not read as covered.

### 4.12 Scope additions — settled by the owner 2026-09-06

**Both items are approved and in scope as Slice ⓪** (owner, 2026-09-06). Each was a
demonstrated gap in code this milestone edits or is the named fallback receiver for, stated
with what was measured and what it costs, so the approval was of a fact rather than a feeling.
Each got its slice at the moment it was approved (`AGENTS.md`, "an approval with no receiver
is invisible to every completeness sweep you have"); §5 is that slice, and its plan is the
next artifact this milestone writes.

1. **APPROVED 2026-09-06. `§16.2:886`'s label clause, made total.** Measured: `valid-label?` exists and
   is called at exactly two sites, the callback- and span-declaration arms of
   `pass-declarations`. Nineteen constructors store a `source-label`; **nine have no accessor
   for it** — `make-error-declaration`, `make-byte-case`, `make-sequence-case`,
   `make-byte-dispatch-node`, `make-sequence-dispatch-node`, `make-stop-node`,
   `make-finish-node`, `make-pause-node`, `make-error-node` — and the shipped comment at the
   label arms says, correctly under today's authorisation, "DO NOT EXTEND THESE TWO ARMS TO A
   KIND WHOSE LABEL YOU HAD TO WRITE AN ACCESSOR TO READ." Milestone 6 adds a twentieth.
   **The work:** nine accessors plus a `node-source-label` dispatcher in `ir.sls` (a per-kind
   `cond` with a loud `else`, `node-name`'s shape); `valid-label?` folded into
   `pass-names-valid`'s three arms — the machine and node arms become `and`s, the
   error-declaration arm already is one; the node arm walks the node's case labels too — and
   into `pass-fields`' field-name arm, so the diagnostic census does **not** move
   (`invalid-name` stays at six sites and `invalid-field-declaration` at two, measurements to
   run rather than assume); the five shipped mutation `FIND`s anchored on those arms'
   `valid-name?` calls (three in `pass-names-valid`, two in `pass-fields`, measured in
   `SchemeMutationSuite.cmake`) re-read with their `REPLACE`s, each moving only if its text
   does; one rejection
   case per carrier in `verify-tests.sps`, asserted in both directions with a wrong-*shape*
   label, because every label conjunct nests inside the shipped `reason-char?` mutant unless
   the fixture gives it a value that mutant cannot produce (`AGENTS.md`, "a predicate that
   calls another predicate nests its mutants by construction"); a derived totality check that
   every `node?` disjunct answers `node-source-label` — which sees node kinds only, so the five
   non-node carriers (the machine, the uint field, the error declaration, both case kinds) are
   enumerated by name in the fixture table, whose sentinel reads its own row count.
   **Approved as recommended.** The check is
   one `§16.2` has required since the plan was written, the fallback receiver is this
   milestone, and the cheapest moment to make a per-carrier check total is the commit that adds
   a carrier.
2. **APPROVED 2026-09-06. A shared private name-grammar library, discharging `§9.3:423`.** Measured: the
   portable name grammar `[a-z][a-z0-9-]*` is written **twice** in `src/` — `verify.sls`'s
   `valid-name?` and `compile.sls`'s `valid-binding?`, each with its own `lower-alpha?` and
   `name-char?` — and `runtime.sls`'s `make-callback-failure` checks `symbol?` only, with a
   note that "`valid-name?` lives in verify.sls, which this library does not import and must
   not". A third
   copy in the runtime is the wrong fix and the note says why. **The work:** a new
   `src/byte-machine/private/names.sls` exporting the grammar predicate (grammar only — the
   reserved-set tests stay in `verify.sls` and `compile.sls`, since a callback code is never
   emitted and `reserved-member-1` is about emitted identifiers); both existing copies replaced
   by imports; `make-callback-failure` calling it, with a runtime-lane case and a mutation pin;
   `BYTE_MACHINE_CORE_PRIVATE` and the runtime's own source manifest in `test/CMakeLists.txt`
   gaining the file (the build-time fingerprint manifests then recompute themselves); and the
   grammar-body mutations, which the plan measured as **four** rather than the two first counted
   here (its F8): two **re-homed** to `names.sls` ("a name with a non-lowercase first char is
   accepted" and "any interior character is accepted"), one **re-anchored in `compile.sls`**
   ("the binding grammar check is dropped" — its decision is the call, not the grammar), and one
   **retired** ("compile: any interior binding character is accepted", the same mutant twice once
   the two copies are one body). **Recommended:
   approve.** It closes a `§9.3` sentence that has been false since Milestone 5 Slice ①b, the
   fallback receiver is this milestone, and the library is where the third reader of the grammar
   — the runtime — was always going to have to get it.

---

## 5. Slice ⓪ — Two inherited verifier obligations

**Scope, as an allocation.** Discharges **no `§25` bullet.** It carries §4.12 items 1 and 2,
**both approved by the owner on 2026-09-06** — a hardening slice on the Milestone 5 Slice ⓪/⓪b
precedent, before the milestone's own scope. It is independent of Gate 0; Slice ① depends on
it only in that ①'s new label carrier joins a check that is already total. **Delivered
2026-09-06** on `feat/m6-slice-0` (PR #77), against `d793b73`, with the parent plan's
disposition "§16.2:886 and §9.3:423 — Milestone 6 Slice ⓪, delivered".

**The work** is §4.12's, as three planned source commits that touch disjoint code, a fourth the pin
sweep required (S2b's check label moved off the shipped ratchet pin's substring), and one
documentation commit, each green (§2): the accessors and `node-source-label` edit `ir.sls`, `ir-tests.sps` and
`kind-position-census-tests.sps` (the derived S2b totality row); the label fold edits
`verify.sls`, `verify-tests.sps` and the pins on `pass-names-valid` and `pass-fields`; the names
library adds a file, edits `verify.sls`'s and `compile.sls`'s grammar definitions,
`runtime.sls`'s `make-callback-failure`, `runtime-tests.sps`, two CMake manifests and four
mutation declarations (§4.12 item 2). Three of the four change `verify.sls`, so they land as
**one PR** with one pin sweep after the last planned commit — which is what found the fourth.

**Oracle.** *Label totality:* the diagnostic census does not move (`invalid-name` at six
sites, `verify.sls` read as a datum), and one machine per carrier, nineteen carriers (Slice ① adds the twentieth under the total check), reports
`invalid-name` on a wrong-shape label and nothing on a portable one — driven from a table whose
sentinel reads the observed row count. *Names library:* `reserved-drift-tests.sps` stays green
(the runtime's export set is unchanged — the predicate is imported, not re-exported), the
identifier-repertoire lane reports the same repertoire it reports today, and
`make-callback-failure` refuses `'BadCode` in the runtime lane. *Both:* every existing lane
green with zero semantic re-baseline, and the whole-suite pin sweep run once after both commits,
because each moves `FIND`s in `verify.sls`.

**What it deliberately does not touch.** No node kind, no `graph.sls` export, no executor arm.
The `verify.sls` comment that forbids widening the label arms is an **instruction** and is
corrected in place by the commit that widens them; Milestone 5's design §10, which excluded the
nine shipped kinds, is a closed design and is left as written — the parent plan's Milestone 5
close note is where the gap was adjudicated, and it gets an appended disposition saying which
slice closed it.

---

## 6. Slice ① — The thirteenth kind, end to end

**Scope, as an allocation.** Discharges `§25:1597` (bulk count-driven cursor movement),
`:1598` (partial/exact/surplus feeds), `:1601` (zero count), `:1602` (EOF truncation) and
`:1603` (counter type verification), and exit criteria `§25:1607` (both structural witnesses,
§4.7) and `:1609` (surplus continues into the next node/message). It discharges `:1608`'s
**field, cursor and offset** clauses over the four `§22.3:1254` cases and leaves its
**fragment** clause to Slice ② — saying so here is how the milestone avoids each slice
believing the other covered it, and Milestone 5's Slice ④ recorded that this safeguard fails in
the direction nobody watches, so ②'s plan re-measures what ① actually shipped before claiming
the remainder.

**Citation staleness policy, declared before any `file:line` appears.** Every citation in this
section was measured at `b470665` and names the construct. No tool in this repository catches a
citation this slice's own edit moves.

**The work**, in the dependency order the libraries' imports impose (measured from each
library's `import` form: `conditions` ← `ir` ← `verify` and `normal-ir` ← `compile`; `runtime`
over `conditions` alone; `interpret` over `ir`, `verify` and `runtime`):

- **`ir.sls`**: `make-counted-consume-node` per §4.10's shape; predicate; five accessors;
  `node?`'s thirteenth disjunct; `node-name`'s arm. **`graph.sls`**: the constructor, and
  nothing else.
- **`verify.sls`**, every row of the appendix, in one commit with the constructor and the
  verifier-side census rows — the matrix's S2 row is red between the disjunct and the last arm,
  and a commit that lands in that window is a red intermediate commit, which `AGENTS.md`
  forbids. **Each census row lands with the library it reads**: the matrix, `ir-tests`,
  `verify-tests` and the diagnostic census read the verifier and belong to this commit; the
  fingerprint golden, `position-kind-tests`, `member3-drift` and the differential lower, emit
  or execute, so they belong to the commit that lands the normalizer, both executors and the
  emitter — two commits, each green, or one. The `§16.2:903` arm (§4.3);
  `node-out-edges`' and `node-eof-target`'s arms; `eof-successors`' arm and `classify`'s join
  over it (§4.2 items 1-2); `parked-eof-start`'s arm, with both parked-set disjunctions left as they are (§4.2 item 3);
  `reexec-targets` and the report set (§4.2 item 4). Fixtures in `verify-tests.sps`: the
  zero-count-route stop (`eof-reachable-stop` with a `#f` eof-target — §3.2 item 3's machine,
  asserted REJECTED); the self-targeting `next` (`zero-progress-cycle` **alone** — no EOF walk
  reaches a non-entry counted consume with a `#f` route, decision 0030 item 6) and the
  self-targeting eof-target (`eof-zero-progress-cycle`); the byte-reachable `next` into a finish
  (`non-eof-into-finish`, and the `t2-kinds` row); the undeclared field (`invalid-field-operand`
  under the node's name); and the priced over-rejection of §4.2 item 4 as an accept/reject pair
  — the loop with a consuming node verifies, the loop without one does not.
- **`normal-ir.sls`**: the `lower-machine` arm, the fourth EOF resolver (§4.4), the tag-14 encode arm
  (§4.4), the `(only …)` import. `normal-ir-tests.sps`: an exact-value fingerprint golden for a
  counted-consume machine (the discipline every tag since 5 has followed), the eleven-slot
  layout check over its state, and the drift pair — two machines differing only in the field,
  only in the successor, only in the EOF route, each differing in fingerprint.
- **`interpret.sls`**: `kind`'s arm, `eof-target-of`'s arm (its `else` is loud, so a parked
  counted consume raises out of `parser-finish!` without it), and the `count-step` message
  (§4.1), with the width read from `machine-fields`.
- **`runtime.sls`**: the feed arm and the finish arm, the finish arm sharing the EOF-route body
  with `(accumulate dispatch)` through a factored local (§4.5). No export moves, so
  `reserved-member-2` and `reserved-drift-tests.sps` are untouched — the gate that proves this
  slice changed no public runtime surface.
- **`compile.sls`**: the arm (§4.5, a `cond`), `n` in `reserved-member-3`, and
  `counted-consume` in the reached-declaration walk's kind list (§3.2 item 4) — with the
  fixture that walk's own comment says found the accumulate defect: a machine whose **only**
  default-EOF consumer is the counted consume, verified, rendered, loaded, run.
- **The golden**: `test/support/harness/byte-machine/test/counted-machine.sls` and
  `test/fixtures/generated-counted.golden.sls`, with the determinism pair of lanes and the
  golden-file environment variable in the mutation lane's registration, on the accumulate
  precedent. The proving machine is a length-prefixed message loop **without a span** — `idle`
  (a byte dispatch that reexecutes a digit into `len` and rejects anything else; its eof-target
  is the finish, so EOF **between** messages is `finished`) → `len` (accumulate, base 10;
  eof-target the truncation error, so EOF after a partial length is truncation, which
  `§12.4:725`'s idle-versus-partial distinction requires and a machine whose entry is the
  accumulate node cannot make) → `:` → `body` (counted consume on `len`, eof-target the
  truncation error) → `,` → clear `len` → `idle`. Slice ② wraps the same body in a span.
- **The ordering witness.** §4.1 item 1's order is not visible in the differential tuple for a
  zero-length body: after `0:` both orders return `need-input` with the same `next`, `consumed`
  and offset, one parked on `,` and the other on `body`. It **is** visible three ways, and
  Slice ① asserts the first two in both lanes: `parser-state-name` after `0:` names the `,`
  dispatch, not `body` (the generated lane answers from the state-name table); and — since
  "`parser-finish!` after `0:`" cannot see the finish order (a correct feed arm has already
  parked the parser on `,`, and a wrong-order feed arm leaves it on `body` where a correct
  finish arm answers the same error) — a machine whose **entry** is a counted consume with
  field initial 0 and an error node for `next`: a fresh parser's `parser-finish!` reports that
  node's error, not the default EOF, in both lanes. The third — a completion event in the feed
  that delivered the last body byte — is Slice ②'s, and Slice ① validated it as one case.
- **The only-consumer fixture** for the reached-declaration walk must carry **no error node
  naming the default-EOF declaration or sharing its code and reason** — the walk puts every
  error state's pair into the reached set first, and such a node would keep the declaration in
  the table and mask the raise the fixture exists to witness.
- **Census rows, every one red before green**: the matrix's kind row and its two positions
  (`count-next`: a byte position and **not** an EOF one — the host's `#f` eof-target keeps a
  byte-reachable counted consume out of the parked set, exactly as `callback-continue` is
  byte-only; `count-eof-target`: EOF), with derived verdicts — a finish at `count-next` is
  `non-eof-into-finish`, a stop at `count-eof-target` is `eof-reachable-stop`; the self rows
  (`count-next`: `zero-progress-cycle` alone, since a parser parked there holds a positive
  count; `count-eof-target`: the EOF cycle); the dangling rows; the
  absence census (a fourteenth constructor refusal for `next`, a fourth legally-absent EOF
  route); the A' role map (`next` gains `count-next`; the unlabelled set gains
  `count-eof-target`, so 17 + 4 becomes 18 + 5); `t2-kinds`; the edge-role label census; the
  diagnostic census's `(invalid-field-operand 7)`; `member3-drift`'s fixture rendering the
  thirteenth arm and exercising `n`; `ir-tests.sps`'s constructor group;
  `position-kind-tests.sps`'s three producer rows (§4.10); `graph-tests.sps`'s façade case.
- **The differential**, `test/common/differential-counted-tests.sps`, both lanes: the four
  `§22.3:1254` cases — zero (`0:,`), partial (`3:ab` then `c,`), exact (`3:abc` then `,`),
  surplus (`3:abc,0:,` in one feed) — each asserting the **expected** tuple and field value, not
  only agreement; every split point of `3:abc,` (`§22.5:1278`), leading, trailing and
  intermediate empty feeds (`:1279`), a nonzero `start`/`end` sub-slice and a larger bytevector
  with unrelated prefix and suffix bytes (`:1280-1281`); EOF truncation after `3:ab` (`eof` at
  offset 4, the `truncated` code, both lanes); reset mid-body restoring the count; the
  two-message feed for `:1609`, asserting the second message's completion in the *same*
  result; and a `u64` count above `(greatest-fixnum)` whose subtraction is bignum arithmetic
  (`§15:856`).
- **The structural witnesses** for `:1607` (§4.7): the datum walk over the emitted arm in
  `compile-tests.sps`, and the counting wrapper in the differential program.

**Oracle — three gates, each a command with a falsifiable result.**

1. **No shipped artifact moves.** `git diff --stat b470665..HEAD -- test/fixtures/` lists
   exactly one file, the new golden, and every fingerprint literal pinned at `b470665` —
   `normal-ir-tests.sps`'s and the four goldens' last lines — is unchanged. A moved fingerprint
   means the encoding changed for a machine that contains no counted consume, and §4.4 says it
   cannot.
2. **The kind is total across the census**, mechanically: the matrix's S2 row, the diagnostic
   census, `member3-drift`'s exercised-name assertion (which reddens if `n` joins
   `reserved-member-3` without the fixture rendering the one arm that binds it — the file
   asserts no arm count, only that every listed local is emitted), and `normal-ir-tests.sps`'s
   layout walk are all green at the slice's head with the thirteenth disjunct present. Any one
   of them red at the head is a site the appendix missed, and the appendix gains the row before
   the fix lands.
3. **The differential asserts values.** Every case in `differential-counted-tests.sps`
   compares each lane against an expected tuple and against the other lane, and every mutant
   declared in the slice's differential pass is pinned on one lane's **expected value's**
   failure record, never on lane disagreement. (The first draft also asked for "a mutant that
   makes both lanes agree on a wrong value"; with one `FILE` per mutation and a runtime arm
   that serves the interpreted lane alone, no mutant of this slice's code can — the slice's
   plan, F13. The pin shape is what the sentence was for, and it holds.)

**Mutations this slice owes**, so the plan writes them from a list rather than from memory:
constructor (`next` required, `#f` eof-target accepted); the `:903` arm; `parked-eof-start`'s
arm (mutated to answer the node itself, so the one-shot grammar's ACCEPTED fixture goes red
with `eof-reachable-stop`); `classify`'s join (each half separately — dropping the `next` half
unreports the flow-through zero-count stop, dropping the eof half unreports the
truncation-to-stop); `reexec-targets`'
arm; the report set; `node-out-edges`' arm; `node-eof-target`'s arm; the encode arm's four
parts (by fingerprint golden); `lower-machine`'s successor and EOF resolution; the interpreter's
`min` (mutated to `(- end pos)`, so the field goes negative — a comparison catch, not a crash),
subtraction, zero-count ordering (moved after the exhausted test) and `n = v` test (mutated to
`pos + n ≥ end`, the count-completion-wins mutant); the emitter's same four; the runtime's
offset advance, `current` write and `need-input` `next`; the reached-declaration walk's kind
list. Each pin anchored on a case-name tail plus check label, each judged against the other
mutants in its lane, and the sweep run in both directions.

---

## 7. Slice ② — Span interaction, pause at fragment boundaries, and the close

**Scope, as an allocation.** Discharges `§25:1599` (span interaction) and `:1600` (pause at
body fragment boundaries), exit `:1608`'s **fragment** clause and exit `:1609`'s **span
variant** (two completion events in one feed's trace — ① discharges the criterion itself), and
writes the milestone's close note as an appended disposition. It adds **no mechanism** (§4.8):
every rule it exercises already runs at the `parser-feed!` seam or in the span-end substeps.
**Delivered 2026-09-06** on `feat/m6-slice-2`, against `8ec814f`, as three commits; plan
`docs/plans/milestone-6-slice-2-implementation-plan.md` (PR #80 = `424d318`).

**The work.**

- **The span-enclosed proving machine**: Slice ①'s message loop with `body` wrapped —
  `:` → `open` (span start) → `body` → `close` (span end) → `,` — the span with a data
  callback and no completion callback, exactly `§21.3:1145`'s fixed-body shape, and a second
  variant with a completion callback because the emitter renders two completion arms and only
  one is a call (Milestone 5 Slice ③'s reason for two machines). Neither is a new golden.
- **`differential-counted-span-tests.sps`**, both lanes, one recording closure per lane with
  its own accumulator (the correction Milestone 5 carried from ② to ③): the six span rules
  applied to a body — the fragment at the span end after a bulk commit (`§14` rule 2, `:831`);
  the boundary flush after a partial commit (rule 4, `:833`); suppression of the empty fragment
  on a zero-length body (rule 5, `:834` — `0:,` delivers no data callback and one completion);
  a data-callback pause **during the flush** mid-body, resume, and the remaining count consumed
  on the next feed (rule 8, `:837` — `§25:1600`); a data-callback pause at the span-end
  fragment after an exact commit, resume, completion only (rule 9, `:838`); and EOF truncation
  mid-body with the span open — no final fragment, no completion, the earlier flush observable
  (rule 10, `:839`). Every split point of `3:abc,` and `§22.5:1279-1283`'s empty, sub-slice and
  multi-split schedules; the coalesced trace invariant across schedules and the raw trace not
  (`§22.5:1285-1287`, the shipped span differential's two cases); the error path compared
  exactly between lanes on one schedule only (`§22.5:1289`).
- **The `§10.6:603` placement oracle**, which is this slice's reason to exist. For every
  schedule, the completion event is recorded in the **feed that delivered the last body byte**,
  never in the feed that delivered the delimiter after it — asserted as an expected value per
  feed, not as lane agreement. Under the byte-at-a-time schedule of `3:abc,` that is the `c`
  feed: the count reaches zero, execution continues into the span end, the fragment `c` is
  delivered by the span-end substep and the completion follows, and only then does the next
  dispatch return `need-input` with the span already closed and nothing to flush. The wrong
  reading delivers `c` through the flush and the completion in the `,` feed; both lanes wrong
  the same way agree on every schedule, and the coalesced trace is identical. Only the per-feed
  value sees it.
- **The retention lane** gains a body-shaped arm: a parser held alive across a collection after
  a bulk commit into a span, the fed bytevector dropped, the weak reference reading `bwp` —
  the same three-layer oracle, one more fixture, because a bulk copy is the shape most likely
  to tempt a runtime into holding a range.
- **The close-out.** The `§25:1593-1609` disposition appended to the parent plan, each exit
  criterion against the tree; §4.11's five obligations each dispositioned, with both ends
  written for every deferral; the design's Exit section dispositioned in place; the five status
  surfaces (README, CHANGELOG, the parent plan's Status line, this document's status, and the
  source comments that name Milestone 6 as a receiver — the surface PR #73 found the ritual
  does not sweep); and the closed slice plans' own status lines, the other surface PR #73 found.

**Oracle.**

1. **Same-schedule exactness** (`§22.5:1285`): fragment lists, ranges and content, identical
   across lanes for every schedule, and the count reached zero in the same feed in both.
2. **Cross-schedule invariance** (`§22.5:1287`): coalesced traces identical; raw traces
   provably schedule-dependent (the shipped assertion that the raw set has more than one
   member).
3. **The placement value** (`§10.6:603`): per feed, per schedule, against a table derived from
   the schedule and the body length before the run — the one assertion in this milestone that
   lane agreement cannot stand in for.
4. **No mechanism added**: between ①'s merge and ②'s head, `git diff` over
   `src/byte-machine/runtime.sls`, `compile.sls`, `interpret.sls`, `private/normal-ir.sls` and
   `private/ir.sls` prints **nothing** — the receiver notes at `make-callback-failure` and the
   `field-action` arm this oracle first expected the close-out to rewrite were rewritten by
   Slices ⓪ and ① (§4.11 items 3 and 1), so the slice's only `src/` hunk is the deferral's
   comment at `pass-reachability`. A code hunk means §4.8 was wrong and this document is amended
   before the code lands. *(Corrected in place by Slice ②, which measured the diff empty.)*

---

## Exit (full Milestone 6)

`§25:1607-1609`'s three criteria, allocated to the slices that will discharge them. At close,
each entry gets a **dated disposition** naming the slice, the file and the case in the tree
that meets it — never reworded to match what shipped.

| Criterion | Allocated to | What will meet it |
| --- | --- | --- |
| **:1607** — "counted consume does not dispatch once per body byte" | **①** | §4.7's two structural witnesses: the datum walk over the emitted arm (one `min`, no `(+ pos 1)`) in `compile-tests.sps`, and the op-message count (one `count-step` per feed for a thousand-byte body) in `differential-counted-tests.sps`. Stated at close: the differential lanes are blind to this criterion by construction, and neither witness is a differential. **Disposed 2026-09-06 (Slice ①):** both witnesses ship — `compile-tests.sps` "the counted arm consumes in bulk (§25:1607, a structural witness)" and `differential-counted-tests.sps` "the structural witness: one count-step per feed" — each with a mutant every behavioural lane passes. |
| **:1608** — "field, cursor, fragment, and offset results match the interpreter for every case" | **① and ②**, in clauses | ① discharges *field, cursor and offset* over `§22.3:1254`'s four cases × `§22.5:1278-1283`'s schedules, each lane against an expected value and against the other. ② discharges *fragment* over the span-enclosed machine's schedules, per-feed and coalesced, with the `§10.6:603` placement value. "Every case" is read as the four named cases under every schedule the shipped span differential drives; the property lane is not extended (§8). **Disposed 2026-09-06 (Slice ①), the field, cursor and offset clauses:** every case in `differential-counted-tests.sps` asserts the count, the consumed length and the stream offset per lane against expected values, then across lanes; the fragment clause is Slice ②'s, its oracle validated as one case. **Disposed 2026-09-06 (Slice ②), the fragment clause:** `differential-counted-span-tests.sps` — identical per-feed traces in both lanes under forty-five schedules, coalesced traces invariant, the completion's placement per feed against a table derived from each schedule. |
| **:1609** — "surplus bytes continue immediately into the next node/message" | **①**, with ②'s span variant | ①: one feed carrying `3:abc,0:,` reports `consumed` equal to the whole slice, the second message parsed to completion, both in one result. ②: the same schedule with the span open records two completion events in one feed's trace. **Disposed 2026-09-06 (Slice ①):** "surplus: 3:abc,0:, in one feed reports both messages in one result", consumed 9, the second message parsed to completion; the span variant is Slice ②'s. **Disposed 2026-09-06 (Slice ②), the span variant:** "§25:1609's span variant: two messages in one feed, two completions in one trace" — `((data 3) complete complete)` in both lanes. |

---

## 8. Explicitly out of Milestone 6

- **The property generator is not extended with a counted-consume draw.** `§25:1618-1619`
  gives the bounded generators to Milestone 7 by name; Milestone 5 extended nothing for
  callbacks or spans (§3, measured); and the property lane feeds one byte per trial to a kind
  that never inspects a byte, so a draw would exercise nothing the fixed fixtures do not. When
  Milestone 7 builds the generator it draws every kind, and this is recorded so a reader of
  `§22.6:1295`'s "as each feature becomes available" does not count its absence as a gap.
- **Narrowing `pass-reachability`** to the occupiable relation. Priced, so the deferral is a
  decision: the narrowed set is `byte-reached` ∪ the EOF walk's visited set, which
  `span-flow`'s `eof-nodes` already computes; the verdict changes on constructible machines
  (decision 0027's `E →(eof) T →(byte) Z` family gains `unreachable-node`); the shipped
  `verify-tests.sps` fixture asserting that `unreachable-node` does **not** catch that family
  flips; and the matrix's pruning count ("exactly three cells prune the sink") moves, because a
  sink reached only through a placed node's EOF route stops being reached. That is a verifier
  behaviour change with a re-baseline in `verify-tests.sps` and `kind-position-census-tests.sps` at
  least, in a milestone about a node kind. *(This bullet first said "three test files" and named
  two; the count was not established. Corrected in place by Slice ②; Milestone 7 enumerates it.)*
  **Deferred to Milestone 7** (`§25:1615`), with both ends written by Slice ② on 2026-09-06: the
  note at `pass-reachability` re-addressed, and the appended disposition "§25:1611 — Milestone 6
  hands the reachability narrowing to Milestone 7".
- **`§16.2:911`** — an orphan with no owner in any milestone (§4.11).
- **Additional field types** and any "incompatible field" content beyond resolution —
  `§29:1754` (§4.3).
- **A `count-zero?` op message**, a fused finish-side path, or any interpreter representation
  of a mid-body state other than the node's own name (§4.1, §4.6).
- **The `§12.7:770` zero-width-machine-action half** — its receivers are the field and
  accumulate arms' next editor and, failing that, nobody named; this milestone edits neither
  arm and does not become the receiver by adding a sibling (§3.2 item 1).
- **`§9.3:392-393`'s `parser-result` enforcement** — its receiver is the next slice that
  changes `parser-result`'s shape; nothing here does.
- **A transition/cursor semantics reference** (`§27:1693`). Counted consume is a cursor
  construct and the natural first page of that reference, but `§27` names no milestone and this
  milestone adds no reference document; the lifetime reference gains one sentence (§4.10).

---

## 9. Handed to writing-plans

- **DISCHARGED 2026-09-06. Gate 0 is one record, `0030`** — "Counted consume is
  input-reading with a zero-count route — the executor contract, and the verifier's two
  answers" — carrying §4.1 and §4.2 as two numbered decision groups under one Context, exactly
  as planned; the mapping is the blockquote under §4. Its Consequences name the four "both"
  rows plus `parked-eof-start`'s arm, state §4.2 item 4's over-rejection with the workaround,
  and hand Slice ① both machines §4.2 item 3 names. It amends decision 0023 item 3.
- **§4.12 is settled (owner, 2026-09-06): items 1 and 2 approved.** Slice ⓪'s plan may
  proceed on that basis and is independent of Gate 0. Slice ①'s plan can be written in parallel
  with Gate 0's execution; it must not be *dispatched* before `0030` exists, and it is measured
  against the tree after ⓪ lands, because ⓪ moves lines in `verify.sls` and `ir.sls`.
- **Re-measure every `file:line` and every count in §3.1, §6 and the appendix at plan-writing
  time.** They were measured at `b470665`. Slice ⓪, if it lands first, moves lines in
  `verify.sls` and `ir.sls`; Slice ① moves lines in every library it touches.
- **Re-run the appendix's four recognisers over `src/` and `test/common/`** before writing the
  Slice ① plan and reconcile against the table: a construct the recogniser finds and the table
  lacks is the finding, and the table is corrected in place — it is an instruction.
- **Slice ①'s plan is one PR of three green source commits and a documentation commit.** The
  S2 row forces the constructor, every verifier arm and the verifier-side census rows into one
  commit; the executor-side rows (the fingerprint golden, `position-kind-tests`,
  `member3-drift`) force the normalizer, both executors and the emitter into one commit, because
  each of them lowers, emits or executes a machine that carries the kind; the differential, the
  committed golden with its lanes and the two structural witnesses read that commit and add
  lanes only, so they are a third. That rule fixes a partition, not a count (the slice's plan,
  F11): a census row that lands before the library it reads is a red intermediate commit, and
  so is a commit that adds pins without moving `EXPECTED_MUTATIONS`.
- **Decide whether Slice ② folds into ①**, with §2's cost stated: the `§10.6:603` placement
  oracle would become one task among twenty that pass on lane agreement alone.
- **Slice ②'s plan re-measures what ① shipped before allocating.** Milestone 5's Slice ③
  shipped both legs it disclaimed; §6's fragment clause is disclaimed the same way.
- **The close-out asks three questions**, not two: which exit criteria are met, which
  obligations named this milestone (§4.11), and **what did this milestone approve that the tree
  does not contain** (§4.12).

---

## Appendix — per-kind site census

**This table is an instruction**: a later slice works it as a checklist, and a row a slice
cannot follow is corrected in place. Every row names a **construct** `rg` finds by name, never a
line. Rows are keyed by the question a checklist pass must ask **of this kind**, because
Milestone 5's Slice ③ walked a correct table and shipped two defects by reading rows without
asking their question ("a row is not a check").

**Four recognisers, run over `src/` and `test/common/`:**

```bash
rg -n -- "-node\?" src/byte-machine/ test/common/        # per-kind predicate dispatch
rg -n "normal-state-kind" src/byte-machine/ test/common/  # normalized-kind dispatch
rg -n "\(op 'kind" src/byte-machine/ test/common/         # wire-kind dispatch, caller side
rg -n "\(\(kind\)" test/common/                           # wire-kind dispatch, callee side (stubs)
```

Measured at `b470665`: recogniser 1 finds sites in `ir.sls`, `graph.sls`, `verify.sls`,
`interpret.sls` and `normal-ir.sls` (none in `compile.sls` or `runtime.sls`, which dispatch on
normalized and wire kinds respectively — recognisers 2 and 3), and in three test programs
(`kind-position-census-tests.sps`, `ir-tests.sps`, `verify-tests.sps`); recogniser 2 finds
`compile.sls`, `normal-ir.sls` and `normal-ir-tests.sps`; recogniser 3 finds the two runtime
loops and their loud `else`s; recogniser 4 finds six stub tables in `runtime-tests.sps`. Sites
invisible to all four are listed by the rules below.

**Three rules the table carries, because no recogniser expresses them** (Milestone 5's, kept):
export and import lists are rows; some sites dispatch on a block tag, a slot number or a state's
own field and are invisible to every recogniser; a row may be **DERIVED**, meaning the kind owes
it nothing because it reads a census listed elsewhere.

**And one rule this kind adds:** a row marked **BOTH** is a site that partitions kinds into
input-reading and zero-width and needs this kind in *both* partitions' answer. There are four, all in `verify.sls`; `parked-eof-start` is the fifth site the partition reaches, and there the kind takes the input-reading answer for a stated reason.

### `src/byte-machine/private/ir.sls`

| Construct | This kind's answer |
|---|---|
| the library `export` list | constructor, predicate, five accessors |
| `node?` | the thirteenth disjunct — S2 reads the count |
| `node-name` | one arm above the raising `else` |
| `node-source-label` (Slice ⓪) | one arm above the raising `else`; Slice ① owes it. The census's derived S2b row in `kind-position-census-tests.sps` reddens at "node-source-label's arm predicates equal node?'s disjuncts" until the arm exists; once it does, the literal "and there are twelve of them" reddens until Slice ① moves it to thirteen — the same ratchet S2 carries. Measured by control: a thirteenth `node?` disjunct with no arm fails the set check and leaves the count check green |
| the per-kind tag/constructor/predicate/accessor block | one block, thirteen |
| `make-machine`'s `(for-all node? nodes)` | **DERIVED** from `node?` |
| `matcher?`, `field-operations`, `field-predicates`, `accumulate-bases`, the callback kind set | **NOT node-kind censuses**; no arm |

### `src/byte-machine/graph.sls`

| Construct | This kind's answer |
|---|---|
| the `export` list and the `(only …)` import | the constructor only (§4.10) |

### `src/byte-machine/verify.sls`

| Construct | This kind's answer |
|---|---|
| `zero-width-edges` | **no arm** — an input-reading kind; its zero-count route is `eof-successors`' (§4.10) |
| `node-out-edges` | an arm: `(next . target)` with role `next` — the byte edge taken after a commit |
| `node-eof-target` | an arm: its own eof-target, `#f` meaning the default |
| `pass-eof` (the `invalid-eof-target` resolution check) | **DERIVED** through `node-eof-target`: a dangling counted eof-target reports `invalid-eof-target` with no further code — the census's `count-eof-target` dangling cell (Slice ①) |
| `pass-names`' error-reference filter | no arm — names no error declaration |
| `node-case-labels` (Slice ⓪) | **no arm** — the kind has no cases; the `else` answers `'()` |
| `pass-names-valid`'s node arm (`§16.2:886`, Slice ⓪) | **DERIVED** through `node-source-label` and `node-case-labels`: the kind's label is checked the moment its `node-source-label` arm exists. Until then that dispatcher's loud `else` raises out of this pass for any machine carrying the kind — the verifier raises, it does not verify clean. `pass-fields`' field arm reads `uint-field-source-label` and is no node-kind site |
| `pass-field-operands` | an arm: `§16.2:903`, `invalid-field-operand` under the node's name (§4.3) |
| `pass-overlap`, `pass-sequence-ambiguity` | no arm — no cases, no trie |
| `reexec-targets` | **BOTH**: an arm answering `(list next)` — a route that can be taken without consuming, the shape the arm already gives accumulate's overflow edge (§4.2 item 4) |
| the zero-progress REPORT set | **BOTH**: the predicate joins, in the same commit as the walk |
| `classify` | **BOTH**: an arm joining `dispatch-arm` over the eof-target with `join-over` the `eof-successors` (§4.2 item 1) — the flow-through answer |
| `parked-eof-start` | **an arm**: a non-entry counted consume starts its walk at its eof-target, the callback precedent, because a parser parked on it holds a positive count; the entry starts at itself (§4.2 item 3). The two questions this construct separates come apart for this kind a second time |
| `§16.2:908`'s zero-hop entry clause and per-edge target | **DERIVED** through `node-out-edges` — check both still fire on a finish `next` |
| `pass-eof-execution`'s parked-set membership | **no disjunct** — the existing `(symbol? (node-eof-target n))` clause admits the kind when its EOF route is worth classifying; a `#f` route is benign for a parked node because the count is positive (§4.2 item 3). The first draft added one; it was unnecessary |
| `pass-declarations`' node walk | no arm — names no callback or span (§4.9) |
| `callback-node-diagnostics`, `span-node-declaration-diagnostics` | no arm |
| `eof-successors` / pass 7's `eof-step` | **BOTH**: a `cond` — the shipped construct was a one-line alias of `zero-width-successors` with no arms to add one to — whose counted arm answers `(list next)` and whose `else` is the alias body (§4.2 item 2); the one helper `classify`'s arm also reads. `eof-step`'s comment, "disjoint by construction … `eof-successors` answers `'()` for every input-reading one", becomes false and is corrected in place; the `append` stays correct |
| pass 7's `parked?` | **no disjunct**, as for the `:909` set. Adding one would be inert — a byte-reachable counted consume's `next` is already a byte edge, the span-end derivation in that construct's own comment — and an inert disjunct is a mutation nothing can catch |
| `span-transfer` | **DERIVED**: the `else` is identity, which is `§10.6:604` |
| `span-node-diagnostics` | **DERIVED**: the `else` answers nothing |
| `eof-verdict-tiers` | **NOT a node-kind census** |

### `src/byte-machine/interpret.sls`

| Construct | This kind's answer |
|---|---|
| the `import` | bare, nothing owed |
| `kind` | an arm: `counted-consume` |
| `completion-state` / `completion?` | **no new shape** — `current` is the bare name (§4.6) |
| `dispatch`'s sequence special case | not reached |
| `eof-target-of` | an arm — the `else` is loud and a parked counted consume raises at finish without it |
| the field-action special case in `field-step` | not reached |
| the executor-op message table | one message, `count-step` (§4.1) |

### `src/byte-machine/private/normal-ir.sls`

| Construct | This kind's answer |
|---|---|
| the `export` list | nothing — no new accessor |
| the `(only …)` import | predicate and accessors |
| the normal-MACHINE vector | untouched (append-only; nothing appended) |
| the normal-STATE vector and accessors | fits: `arguments`, `targets`, slot 6, slot 7 (§4.4) |
| `normal-state-kind` | `counted-consume` |
| `internal-blocks` and its consumers | **DERIVED**: the `else` skips a 1:1 kind |
| the `else` guards' census comment above the trie ("Twelve node kinds lower here … less Milestone 6's counted consume") | **a census; it becomes thirteen**, and it names this milestone — corrected in place |
| the EOF resolvers `eof-of` / `acc-eof-of` / `seq-eof-of` | a fourth sibling, not a widening (§4.4) |
| the slot resolvers | none — names no callback or span |
| `lower-machine`'s declared `cond` | an arm above the raising `else`, whose comment — "The repertoire is now these TWELVE kinds" — is a census and becomes thirteen |
| the internal-state builder (phase two) | **invisible to recognisers**; not reached |
| the debug-map walk | **DERIVED** through `name->id` |
| `encode-normal`'s state arms | tag **14**, four parts (§4.4) |

### `src/byte-machine/compile.sls`

| Construct | This kind's answer |
|---|---|
| the `(only …)` import | check — no new IR accessor is read; the normalized table carries everything |
| `reserved-member-2` | untouched — no runtime export moves |
| `reserved-member-3` | gains `n` (§4.5); `member3-drift`'s two assertions move |
| `render-state-arm`'s `case` | an arm above the raising `else`, whose comment enumerates the covered kinds — **that comment is a census; it becomes thirteen** |
| the error reason/code selection on `normal-state-kind` | check — slot 7 carries the default-EOF reason |
| the reached-declaration walk, `'(dispatch accumulate)` | **the Milestone 4 Slice ③ defect site**: gains `counted-consume`, with the only-consumer fixture (§3.2 item 4) |
| `snames` | **DERIVED** — total over declared states |
| `render-exhausted-preamble` | **not called**: the zero-count test precedes the exhausted test (§4.5) |

### `src/byte-machine/runtime.sls`

| Construct | This kind's answer |
|---|---|
| the `export` list | untouched |
| the feed **wire-kind** `case` | an arm (§4.1's table, feed column) |
| the finish **wire-kind** `case` | an arm; the EOF-route body factored and shared with `(accumulate dispatch)` (§4.5) |
| `route-byte-step!` | **not reusable** — single-byte; the arm advances by `n` |
| `callback-failure-position` | not read — the kind fails no callback (§4.9) |
| `span-boundary-flush!` | **DERIVED**: reads the result's `next` and the mark (§4.8) |

### Test-side censuses

| File | Construct | This kind's answer |
|---|---|---|
| `kind-position-census-tests.sps` | `kind-table`, `kind-predicates` | a row — the cell machines already declare field `n` |
| | `position-table`, `role->positions` | `count-next` (a BYTE position and **not** an EOF one — the cell's host has a `#f` eof-target, so the placed node is in neither `§16.2:909` disjunction and no EOF walk reaches `next`; decision 0030 item 6) and `count-eof-target` (EOF); `next`'s mapping gains `count-next`; the unlabelled set gains `count-eof-target` |
| | `expected-codes` | no change to the derivation: a stop at an EOF position is `eof-reachable-stop`, a finish at a byte position `non-eof-into-finish`; a stop at `count-next` is **not** `eof-reachable-stop` |
| | `self-expectations` | `count-next`: `zero-progress-cycle` alone; `count-eof-target`: the EOF cycle |
| | the dangling group, the absence census | `missing-target` / `invalid-eof-target`; refusals 13 → 14, legally-absent routes 3 → 4 |
| | "exactly three cells prune the sink" | re-measured, not assumed |
| | the `node-source-label` totality row (S2b, Slice ⓪) | **DERIVED** — reads the arm predicates out of `ir.sls` as a datum and compares them with `node?`'s disjuncts; red at "node-source-label's arm predicates equal node?'s disjuncts" until the arm exists; with it, the literal "and there are twelve of them" is red until moved to thirteen, as S2's is |
| `verify-tests.sps` | `t2-kinds` / `t2-hop` | a row (§4.10) |
| | the edge-ROLE label census | `next` asserted for the kind |
| `diagnostic-census-tests.sps` | `pinned-sites`, `code-fixtures` | `(invalid-field-operand 7)`; no new code, so no new fixture row |
| `member3-drift-tests.sps` | the fixture machine, the exercised-name list | renders the thirteenth arm; `n` exercised; both literal counts move |
| `ir-tests.sps` | the per-kind constructor group | one group |
| `normal-ir-tests.sps` | the layout walks, the fingerprint goldens | a counted-consume golden and its drift pairs (§6) |
| `position-kind-tests.sps` | the producer table | two rows (§4.10) |
| `runtime-tests.sps` | six stub `((kind) …)` tables | no arm owed — no stub machine carries the kind; say so |
| `graph-tests.sps` | the façade case | the constructor |
| `compile-tests.sps` | emitted-text pins | the `:1607` datum walk (§4.7) |

---

## References

- Parent plan: `docs/plans/byte-machine-implementation-plan.md` — `§25:1597-1603` (scope),
  `§25:1607-1609` (exit), `§9.1:311`, `§10.6:596-604`, `§11`, `§12.4`, `§12.7`, `§14`,
  `§15:872`, `§16.2:903`, `§19.2:1013`, `§21.3`, `§22.3:1254`, `§22.4`, `§22.5`, `§29:1754`,
  and the appended `## Dated dispositions` section.
- `docs/plans/milestone-5-design.md` — the structural template, and its appendix's recognisers.
- `docs/plans/milestone-4-design.md` §4.6 and its Exit section's third limitation — the
  `§16.2:904` precedent §4.3 rests on.
- Decisions 0011 (EOF execution), 0015 (independent interpreter representation), 0019 and 0025
  (the seam bargains this milestone does not need), 0020 (constructor/verifier split), 0022
  (`parser-error`), 0023 and 0027 (the reachability relations), 0029 (the span lattice).
- `AGENTS.md` — testing and mutation discipline, documentation and record discipline.
