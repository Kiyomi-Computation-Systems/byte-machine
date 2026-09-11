# Milestone 7 Design — Verification and generative hardening

**Status: Gate 0 discharged 2026-09-06 as decisions 0031-0033 (PR #85; §4's blockquote and
§11's first bullet carry the discharge); Slice ⓪ delivered 2026-09-07 (PR #89); Slice ① delivered 2026-09-11 (PR #92); Slice ② next (the generator over every construct and the property differential suite).** Before it: the design merged 2026-09-06
as PR #83 = `8edceb1`, and §4.12 was settled by the owner the same day (items 1-3 approved).
Written against **`5ac363a`** (`main` = PR #82, which added only
`AGENTS.md` bullets on top of Milestone 6's close at `0920b13`) on branch
`docs/milestone-7-design`, tree clean. Measured on 2026-09-06 by running the complete selection
and reading the suite's own declared totals: `release` **114/114** (134.71 s); Scheme mutation
suite **58 passes / 522 mutations** (`EXPECTED_PASSES` and `EXPECTED_MUTATIONS` at
`test/support/cmake/SchemeMutationSuite.cmake`, asserted by the lane against what actually ran);
the diagnostic census **30 codes over 56 sites** (`diagnostic-census-tests.sps`'s `pinned-sites`,
summed); under Chez Scheme 10.4.1 on `tarm64osx`.

**Every citation in this document was measured on 2026-09-06 against `5ac363a`.** Parent-plan
citations are `§section:line`; source citations name the **construct** and give a line only where
the construct is not `rg`-able by name. Two classes of staleness are known and neither is caught
by any tool in this repository: a `src/` line number moves when a slice edits the file above it,
and a `§section:line` moves if anything is ever *inserted* into the parent plan's body rather than
appended to its dispositions section. Every `file:line` here is to be re-measured at plan-writing
time (§11).

**One measurement in this document was taken by running a prototype, not by reading.** §3.2
item 1 reports what narrowing `pass-reachability` does to the tree. It was measured by applying
the change §4.1 describes — one line changed and a thirteen-line helper added — to a detached worktree at `5ac363a` and running the
release selection minus the mutation lane (113 lanes): two lanes failed, both modes of one
program, three cases. The prototype is not committed; the diff is reproduced in §4.1 so the
measurement can be re-taken, and Slice ⓪ re-takes it before anything lands.

> **Amendments.** This document's amendment law, stated before there is anything to amend, is
> `AGENTS.md`'s "Correct a stale instruction in place; annotate a stale record": a **record**
> here — a measurement, a finding, a count taken against the tree — gets a dated note appended
> and is never rewritten, because a record edited to agree with a later decision stops being
> evidence of anything. An **instruction** — a scope allocation, an obligation handed to a
> slice, a resolution a slice must implement — is corrected in place, because leaving a false
> one is a landmine and what it used to say is in git. Later dated notes are indexed here,
> newest first, each naming the section it amends.
>
> **2026-09-10, Slice ① implemented** — **corrects §4.2 item 3's table and §6 in place**:
> `reaches-self?` is renamed `self-cycle` (its contract now returns the cycle, F9); §6's
> `eof-terminal` return is a two-element `(verdict path)` list, not the `(verdict . path)`
> pair §6 named (F13); and §6's Oracle "122 accessor reads" is 129 at the slice's base (F14).
> The **Appendix — the `§16.2` ledger**'s "Path (①)" column was worked row by row as the path
> policy's checklist (Task 1 Step 7): every row held — its `8` codes over `12` sites are the
> tree's, and each stated shape (the cycle; entry → node; the EOF walk's stack; entry → source
> → finish) is one the slice produced. A checklist worked and held is a result, so the ledger
> is unedited. §6's measurements are records and untouched; decision 0032's own instruction
> corrections are noted in that record. The plan measured what the design derived.
>
> **2026-09-07, Slice ⓪ delivered (PR #89)** — **corrects §5's Pins paragraph in place and
> annotates §5's scope**: the paragraph named three mutations by LABEL and delegated the rest
> to one `rg` over `(symbol? (node-eof-target n))`, which under-listed the work three ways —
> two pins under the same membership that the search cannot see, three whose `FIND` does not
> move but whose observation the narrowing changes, and one whose only witness is in another
> SPEC lane. The measured census (one retired, four re-anchored, one re-shaped, five `FIND`s
> unchanged, three re-pinned, three added, three incumbents re-anchored by the sweep) replaces
> it — corrected once more the same day, when the whole-branch review measured the retirement's
> stated reason false: nothing retires, and the arm-2 mutation re-anchors onto `eof-step`. §5's "each caught by the case that disjunct's kind already has" is corrected: true of the
> pause, false of the callback, whose witness is `unit.kind-position-census`'s axis-A cell.
> §3.2 item 1's measurement is a record and is untouched — the slice re-took it verbatim at its
> own base. The plan measured what the design derived.
>
> **2026-09-06, Gate 0 discharged** — **annotates §3.2 item 1 and corrects §4.1, §4.2 and §11 in
> place**: the whole-gate review found two stated reasons false against the tree — the
> `§16.2:898` fixture is a collapsed variant of 0027's machine, not that machine "where `Z` is
> `T`"; and the diagnostic widening changes forty-two of fifty-six sites, not "about thirty" —
> both corrected in the records and here; §4's blockquote records all three corrected reasons.
>
> **2026-09-06, the owner's decision on §4.12** — **annotates §4.12, §9 and §11**: items 1, 2
> and 3 approved ("Merge 83, approve all three, and do the Gate 0 plan"). §4.12's heading and
> each item record the decision and its date; the receiving slice on each item was already
> named. Slice ④'s allocation (§9) and §11's bullet stand as written, with the approval noted.

**Governing plan.** The parent plan's `§25` "Milestone 7" subsection is authoritative
(`§25:1611`). Its Scope list is `§25:1615-1621` and its Exit criteria are `§25:1625-1627`.
**This document changes no scope and rewords no criterion**; where it appears to say something
the parent does not, the parent wins and this document is wrong. Additions this document
*proposes* are collected in §4.12 and are the owner's to approve.

**Read first, as the parent instructs.** Three dispositions carry the `§25:1611` heading —
Milestone 5 Slice ⓪'s scoping record ("Milestone 7 keeps its scope unchanged"), Milestone 5
Slice ⓪'s delivery, and **"§25:1611 — Milestone 6 hands the reachability narrowing to
Milestone 7"**, the first that hands something over, carrying Milestone 6's design §8 pricing —
and Milestone 6's Slice ① delivery and close note sit under adjacent `§25` headings. §3.2 item 1 measures that pricing against the
tree and finds two of its three predicted effects do not occur and a third, unnamed one does;
§4.1 is the resolution.

---

## 1. Summary

Six milestones built a machine that reads bytes, keeps fields, calls out, spans, and consumes
bodies, and a verifier of thirty diagnostic codes over twelve pass procedures (thirteen counting the
operand half inside `pass-fields`) that gates every path to
output. What the tree cannot yet do is **prove itself generatively**: every rejection the
verifier makes is witnessed by fixtures written by hand — the census's one per code, the
matrix's cells, the topology table — and no program under `test/` draws an invalid machine
(`rg -il 'corrupt' test/` prints nothing; the phrase "invalid-machine generator" occurs once,
in the topology table's comment deferring it here); the one property lane draws six of
thirteen node kinds, one of four matcher kinds, feeds one byte, and cannot be re-seeded without
editing the test. Milestone 7 adds no node kind,
no lifecycle state, no ABI member and no runtime mechanism. It hardens what exists, along the
seven bullets `§25:1615-1621` name, and it opens by closing the one thing Milestone 6 handed
over.

**The shape of the work, measured (§3):**

- **The verifier's reachability pass over-approximates** and has since Milestone 1
  (`§25:1611`'s hand-off; decisions 0023 and 0027; `pass-reachability`'s own note). Narrowing it
  to decision 0027's *occupiable* relation is a one-line change plus a thirteen-line helper whose measured effect on
  the tree is three cases in one program — none of which Milestone 6's pricing named — and
  whose two named effects do not occur. §4.1 resolves it as decision **0031**.
- **The diagnostic record carries three of `§16.4:937-943`'s seven bullets** — four slots,
  since `:940`'s node and edge/source label are two. Severity, machine name, declaration names
  and the representative graph path are absent; every earlier design
  that noticed said "Milestone 7". §4.2 resolves it as decision **0032**, with a path policy
  that names which codes carry one.
- **The property lane is a bounded valid-machine generator already** (`§25:1618` is not new
  work) and it guarantees validity by hand: two of its five construction constraints are
  verifier rules added after rejections were observed, the other three are coverage pins for a
  lane that feeds one byte. It draws none of the constructs Milestones 3-6 added. §4.3-§4.4
  replace the strategy: draw from every construct, let the verifier decide validity, and make
  every drawn arm prove it ran. That is decision **0033**, with the seed and the failure-fixture
  protocol `§25:1621` and `§25:1627` ask for.
- **No invalid-machine generator exists** (`§25:1619`), and `§25:1625`'s "positive and negative
  tests" for every diagnostic is met on the positive side only — the census ratchets one
  fixture per code, and eighteen absence assertions in one file cover six of thirty codes.
  §4.5-§4.6 build the two tiers Milestone 5 Slice ⓪'s plan named and deferred here by name — a
  **corruption catalogue** total over the source-derived code set, and, widened from that
  plan's "independent acyclicity walk", an **independent oracle** over the graph rules.
- **`§16.2:910` (generated identifier collisions) is discharged by construction and nothing
  witnesses it**; `§16.2:911` (backend limits) has had no owner in any milestone. §4.8 and
  §4.12 put both in front of the owner with a measurement each.

| Phase | Kind | Produces | Discharges |
|---|---|---|---|
| Gate 0 | decisions only | records `0031`, `0032`, `0033`; dated notes on `0023`, `0027` (from `0031`) and `0020`, `0022` (from `0032`) | nothing; unblocks every slice |
| Slice ⓪ | hardening | `pass-reachability` over the occupiable relation; one parked set; `all-out-targets` retired; the three flipped fixtures re-baselined and the family pinned | the `§25:1611` hand-off, under `§25:1615` |
| Slice ① | diagnostics | the seven-field record, severity and machine stamped once, declaration names per site, graph paths on the walk-derived codes | `§25:1616`; `§16.4:938`, `:939`, `:942`, `:943` |
| Slice ② | generation | the generator over every construct, the differential over inputs and schedules, scripted callbacks and span traces, the seed from the environment, anti-vacuity per draw | `§25:1618`, `:1620`, `:1621`; `:1626` re-verified |
| Slice ③ | reproduction | the machine printer, the fixture saver, the minimizer | exit `§25:1627` |
| Slice ④ | rejection + close | the corruption catalogue (positive **and** negative per code, total over the census), the independent oracle over the graph rules, the `§16.2:910` witness, the close note | `§25:1617` (via §4.8's witness), `§25:1619`; exit `§25:1625`; the milestone close |

**Dependency order.** Gate 0 before ⓪, because ⓪ changes a verdict and the record must say
which relation it is (a fixture written against the wrong one defends it — Milestone 5's
lesson, decision 0027). ⓪ before ②, because the generator's validity oracle is the verifier and
the generator will draw the `E →(eof) T →(byte) Z` family constantly; under the shipped relation
such draws verify clean, run, and compare, so ②'s counters would be measured against a verifier
that accepts unoccupiable nodes and re-baselined a slice later. ⓪ before ①, so ①'s pin sweep
is about shape alone (§2). ① is independent of ② and ③ but precedes ④, whose catalogue asserts what a diagnostic *carries* and not only its code. ② before
③ and ④: the minimizer reduces what ② draws, and the catalogue corrupts what ② accepts. ③ and ④
are independent of each other; ④ closes the milestone.

**The oracle every slice runs under changes shape once.** Slices ⓪ and ① run under the shipped
oracles — the kind × position matrix, the diagnostic census, the enumerated fixtures — and each
re-baselines exactly what it changes, named in advance. Slices ②-④ introduce a *generative*
oracle, and the lesson Milestone 6 carried applies with more force here: two lanes that agree
can agree on the wrong value, and a generated machine has no hand-derived expected value. So the
property lane gains a third layer neither lane supplies — **invariants derived from the plan**,
total over every trial (§4.4): `§12.2`'s operation matrix as a table of permitted
(lifecycle, operation) → (status, lifecycle) transitions, `§11`'s cursor arithmetic (`next` in
range, `consumed` ≤ the slice, offset the running sum), field values inside their declared
widths. An agreed-wrong value that violates none of those stays invisible, and §10 says so by
name for the one such value the tree already carries.

---

## 2. Why this shape

**Why Gate 0 is three records and not one.** Milestone 6 needed one because every call
descended from one fact. Milestone 7's three calls are independent and each is externally
observable on its own: 0031 changes which machines verify; 0032 changes what a diagnostic is
(four new public accessors on `(byte-machine verify)`); 0033 fixes a developer-facing contract
(an environment variable, a file written on failure, a seed's meaning) that every later property
fixture and every pin in the property pass will depend on. Deciding any of them inside a slice
puts the decision in a fixture, which then defends it — the pattern this repository has recorded
at every gate since Milestone 4.

**Why the narrowing is Slice ⓪ and not folded into Slice ②.** It is the only piece of this
milestone that changes a shipped verdict, and it is small: one changed line, one helper, three
cases, measured. Landing it first means every generative slice is measured against the verifier the
release will ship, not against one that accepts nodes no execution can occupy. It is also the
one obligation this milestone *inherited* with both ends written; Milestone 6's Slice ⓪ ("two
inherited verifier obligations", its design §5) is the precedent for closing those first, and
Milestone 5's Slices ⓪ and ⓪b for hardening before new scope.

**Why the generator is rewritten rather than extended.** `machine-gen.sls`'s header records
its constraints and where each came from. Two are verifier rules learned from rejections —
a `start`-targeting case is forced to `advance` (a zero-progress cycle otherwise), the first
case is pinned to `stop` (reachability otherwise) — and were added after Step 5 "showed real
`verify-machine` rejections"; a third, adding `pausep` only when a case drew it, is
reachability again. The accumulate constraints — the digit case pinned to `reexecute`, one
case pinned to a digit, the initial fixed at 25, overflow given its own declaration — are
coverage pins for a lane that feeds exactly one byte, not verifier rules. The first three are
a hand-maintained mirror of the verifier's rules, written in the file that exists to test the
verifier's consumers, and extending that mirror to seven more node kinds means encoding pass
7's lattice, decision 0030's join and the EOF walk by hand.
A generator whose validity oracle *is* the verifier mirrors nothing; what it must then prove is
that each construct it draws actually ran, which is what the anti-vacuity counters the current
lane already carries (eight of them) are for. §4.3 states the trade and its one real cost — a
verifier over-rejection now *silently* removes a construct from the property lane — and the
counters are the answer: a construct the verifier never admits is a counter at zero.

**Why the invalid generator is two tiers.** The corruption catalogue is derivable: take a
machine the verifier accepts, apply one named edit, and the code it must produce is written
beside the edit, derived from `§16.2` before any run — the matrix's discipline over a generated
base instead of a fixed skeleton. That discharges `§25:1625` totally and mechanically. The
independent oracle is the verifier's own differential — a second implementation of the graph
rules in the test library, compared on free draws — and it is the only instrument in this
design that can find a verifier defect *nobody has thought of*, which is what "generative
hardening of all mandatory verification passes" (`§25:1615`) asks for. It is scoped (§4.6) to
the rules whose truth a graph walk decides from the plan's sentence alone, because a second
implementation written by reading `verify.sls` would mirror its choices.

**Rejected: folding Slice ③ (reproduction) into Slice ②.** The saver and the minimizer have no
oracle unless something fails, so their test is a *deliberate* failure — a probe that must
produce a fixture which, run on its own through the shipped launcher, reproduces the
disagreement. That is a different shape of test from a differential and it deserves its own
task list and its own mutations (a saver that writes a fixture which does not reproduce is the
defect to pin). The owner may still fold; the cost is that ②'s twenty-odd tasks would carry
two whose green means something else.

**Rejected: a Slice ⓪ that also widens the record.** Tempting, because both touch every
`make-diagnostic` site's neighbourhood. But ⓪ moves a verdict and ① moves a shape, and a pin
sweep after a commit that does both cannot say which change moved which record. Two slices,
two sweeps.

**Why the milestone does not open with the generator.** The generator's oracle is the
verifier, and the verifier as shipped accepts a family of machines no execution can occupy.
Building the generator first would measure its counters against that verifier and then
re-measure them all after ⓪ — the appendix's ledger names the family the generator would draw
most often (any EOF-only-reachable dispatch with a byte edge to anything).

---

## 3. What the parent plan already settles

These are settled. A slice that re-derives one is doing work the plan already did, and a Gate 0
record that "decides" one is spending a record on a sentence already written.

- **The scope is seven bullets and the exit is three** (`§25:1615-1621`, `:1625-1627`), and
  the parent's `§25:1611` disposition reads the first bullet as covering the reachability
  narrowing: "generative and diagnostic hardening of all mandatory verification passes already
  introduced with their owning constructs … already covers narrowing a pass this document
  introduced, so Milestone 7's scope is unchanged under that reading and no bullet is added."
  This design takes that reading and adds no bullet.
- **What a property test is** (`§22.6:1293-1297`): a deterministic in-tree PRNG with the seed
  printed on failure; bounded small *verified* machines and inputs, comparing interpreter and
  generated behaviour, covering "byte dispatches, reexecution, fields, callbacks, pauses, spans,
  EOF, and terminals as each feature becomes available"; and invalid graphs generated
  *separately* to exercise rejection, never handed to an executor. The PRNG exists
  (`(byte-machine test prng)`, a 63-bit LCG threading explicit state) and the second and third
  sentences are this milestone's.
- **What the differential compares** (`§22.4:1262-1272`): nine members, every one of which a
  shipped fixed-machine differential already reads. The property lane reads five of them
  fully today (status; `next` and consumed; offset; the error projection; stop and finish), two
  partly (fields for the accumulate draw only; pause continuations through the resume
  protocol), and none of callback order, span fragments or reset. §4.4 makes it read all nine.
- **What a schedule sweep is** (`§22.5:1276-1289`): every split point, empty feeds, sub-slices,
  padded bytevectors, selected pairs, and "deterministic random multi-split schedules"; exact
  agreement per schedule; coalesced-trace invariance across schedules; malformed inputs
  compared exactly only within a schedule. Three fixed-machine differentials — sequence, sequence-node, http-version — implement the
  sixth bullet as seeded multi-split draws from the PRNG; the span differential writes its
  schedules as literals and says why; the property lane, which alone has a *drawn* machine,
  runs no schedule at all.
- **What a diagnostic is** (`§16.4:935-947`): seven fields, compared by structure and code and
  never by rendered text (`:945`), with "unreachable nodes are errors in v0.1" and warning
  policy deferred (`:947`; `:938` "warnings may be added later").
- **What verification is** (`§16.1:878`, `§16.3:917-931`): a generation gate of independent
  pure passes, followed by normalization and *private invariant validation* whose failures are
  internal, never diagnostics. The last sentence fixes an oracle §4.4 uses: a machine the
  verifier accepts and the normalizer raises on is a finding — Milestone 5 Slice ③ found one
  (a span node naming an undeclared span), and a generator over every construct will look for
  the next.
- **Reachability's meaning is decided, and only its consumer is open.** Decision 0027 item 1
  defines *occupiable* — `byte-reached` or visited by the EOF walk from the parked set — and
  gives it two consumers (the span/callback restrictions, pass 7's domain) while stating in
  Consequences that `pass-reachability` is "handed to nobody". Decision 0023's third
  Consequence raised the over-approximation and forbade reading it as closed. The parent's
  `§25:1611` disposition prices the narrowing as "`byte-reached` ∪ the EOF walk's visited set,
  which `span-flow`'s `eof-nodes` already computes". §4.1 changes the consumer and nothing
  about the relation.
- **The reserved-output-binding set and who checks it** (`§9.2:372-380`, `§20:1040`): three
  members, checked together on the *binding* by `compile.sls`'s `valid-binding?`, raising
  `invalid-output-binding` as an API-contract condition rather than a diagnostic. §4.8 turns on
  the word "binding".
- **The interpreter is the oracle and is independent by construction** (`§18:970-972`,
  decision 0015): no shared prefix walker, no shared lowering. Nothing here changes that, and
  §4.6's independent verifier oracle is built on the same principle one library over.
- **Deferred, and this milestone does not admit them** (`§29`): a serialized IR format
  (`:1761`) — §4.7's printer emits constructor calls for the test tree and is not one; a
  general-purpose CLI (`:1762`) — the fixture saver is a lane's failure path; graph/DOT
  visualization (`:1760`) — `§16.4:943`'s path is a list of names, not a picture; warning
  policies (`:1764`).

**Where the parent stops settling.** It does not say which relation "unreachable" quantifies
over (§4.1). It does not say which diagnostics carry a path, only "when useful" (§4.2). It does
not say whether a generator guarantees validity or asks the verifier (§4.3). It does not say
what a saved failure fixture *is* (§4.7). It does not say what "generated identifier
collisions" means for an emitter that emits every declared name as data (§4.8), and it gives
`§16.2:911` no owner (§4.12). Those are §4's.

### 3.1 The generative and diagnostic surface, measured

**The property lane today** (`test/common/property-differential-tests.sps`,
`test/support/harness/byte-machine/test/machine-gen.sls`): forty machines per seed, the seed a
literal (`(define seed 20260823)`), 256 single-byte trials per machine, each trial a fresh
parser pair driven through feed, the pause protocol and finish; eight anti-vacuity counters
(pause, finish, field, digit, overflow, and interpreter-only twins of three); six mutations in
one pass (Pass 39, `SPEC byte-machine.property.differential.chez.source`); registered in both
the source and AOT lanes (`byte-machine.property.differential.chez.source` and `.aot`,
`test/CMakeLists.txt`), so `§25:1626` is **already true of the tree** and this milestone's job
there is to keep it true. Both lanes run in under a second.

**What the generator draws**, against `§10.6`'s closed set and `§9.1`'s matcher constructors:

| Construct family | Members | Drawn today |
|---|---|---|
| node kinds (`node?`'s disjuncts, thirteen) | byte-dispatch, sequence-dispatch, stop, error, finish, pause, field-action, field-branch, integer-accumulate, callback, span-start, span-end, counted-consume | **six**: byte-dispatch, stop, error, finish (as the entry's eof-target), pause, integer-accumulate |
| matchers (four) | exact, set, range, complement | **one**: exact |
| declarations | uint field, callback, span, error | uint field (one, `u8`, initial 25, accumulate only); error (two or three); **no callback, no span** |
| inputs | `§22.5`'s six schedule shapes | **one byte, one feed**; no split, no empty feed, no sub-slice, no padding, no pair, no multi-split |
| callback outcomes (`§13:803-808`) | continue, branch, pause, failure | none (no callback drawn) |

Seven kinds, three matchers, two declaration families and five of six schedule shapes are
undrawn. Each was deferred to this milestone by name at the time: class matchers and sequence
nodes by Milestone 3's design (§8) and Slice ③'s plan; callbacks and spans by Milestone 5's
design (Milestone 6's design §8: "Milestone 5 extended nothing for callbacks or spans", on its
§3's measurement); counted
consume by Milestone 6's design §8 ("When Milestone 7 builds the generator it draws every
kind").

**The diagnostic surface**: thirty codes over fifty-six emission sites in `verify.sls`, read as
a datum by the census. The record is `(vector tag code node message edge)` — three of
`§16.4:937-943`'s seven bullets in four slots, `edge` being the role `§16.4:940` asks for
(Slice ⓪b) and `#f` at 55 of 56 sites — `make-diagnostic/edge` has one call site, the `:908`
block. What the tests read, counted as `rg -o -F` substring hits over `test/common/*.sps`:
`diagnostic-code` **76** times, `diagnostic-node` **41**, `diagnostic-edge` **5**,
`diagnostic-message` **0**. No test compares a whole record or reads its length — two
searches, both empty: `rg -n 'vector-length|vector->list' test/common/*.sps | rg -i diag` finds
only the census's source-datum walker, and `rg -n "equal\? diag|#\(diagnostic|vector 'diagnostic"
test/common/*.sps` finds nothing — so widening the vector is invisible to every shipped
assertion — the census, which derives the constructor set from every `define` whose
name begins `make-diagnostic`, counts a new constructor automatically.

**What the `node` slot holds**, by the expression at each site (the design's own census of
`verify.sls`, 56 sites): a **node's** name at 34 sites (`(node-name n)` 20, `nm` 6, `name` 5,
`(machine-entry m)` 2, `t` 1 — the last two being targets that may name nothing); a
**declaration's** name at 19 (callback 8, span 6, error 3, field 2); the **machine's** at 1; `#f`
at 2 (`invalid-shape`). So "node … where applicable" (`§16.4:940`) is implemented as "the
subject's name, whichever table it lives in", and `§16.4:942`'s "relevant declaration names"
has been carried in the node slot at nineteen sites since the codes were minted. §4.2 keeps
that slot exactly as it is — 41 assertions read it — and adds the field beside it.

**The negative side of `§25:1625`.** Positive tests: one fixture per code in the census's
`code-fixtures`, looped over the *source-derived* key set, so a new code without a fixture fails
by name. Negative tests — a fixture one edit away from the fault that must **not** emit the code
— exist only ad hoc: in `verify-tests.sps`, eighteen `(not (memq 'CODE …))` assertions over six
codes (`eof-reachable-stop` 4, `unreachable-node` 4, `eof-zero-progress-cycle` 3,
`non-eof-into-finish` 3, `zero-progress-cycle` 3, `invalid-field-operand` 1 — nineteen
`(not (memq '` forms, one of which names the node `start`) and thirteen checks labelled "no
diagnostics" (eighteen whole-result-empty assertions by shape), which are negatives for every
code at once and attribute nothing. Twenty-four codes have no negative that names them.

**The enumerated invalid-machine instruments**, so Slice ④ builds beside them rather than over
them: the kind × position matrix (13 kinds × 23 positions, plus 26 self cells, 22 dangling
cells, an absence census and a 25-cell verdict lattice, all with verdicts derived before the
run — the four counts are the file's own sentinels); the span-topology table in
`differential-span-tests.sps` (eleven rows, `§25:1590`; the file says "The bounded
invalid-machine generator is Milestone 7's, and this must not quietly become it", and
Milestone 5's design §10 says the table was enumerated "so the boundary is not crossed by
drift"); `verify-tests.sps`'s 25 groups and 167 cases; 144 `(verify-machine` call sites across
`test/common` (`rg -o '\(verify-machine\b'`). None generates. Every one stays; the catalogue is total over
the code set where these are total over a skeleton or a table.

### 3.2 Where the spec and the tree already disagree, or where the pricing did

Seven things a slice would otherwise discover mid-task and report as its own regression.

1. **The reachability narrowing does not do what Milestone 6 priced it to do, and it does do
   something Milestone 6 did not name.** The `§25:1611` disposition (and design §8 of
   Milestone 6, which it transcribes) predicted three effects: (a) "decision 0027's `E →(eof)
   T →(byte) Z` family gains `unreachable-node`"; (b) "the shipped `verify-tests.sps` fixture
   asserting that `unreachable-node` does **not** catch that family flips"; (c) "the kind ×
   position matrix's pruning count ('exactly three cells prune the sink') moves". **Measured
   on 2026-09-06** by the prototype the header describes — `pass-reachability` reads
   `byte-reached` ∪ the EOF walk's visited set, verbatim the pricing's relation — over the
   release selection minus the mutation lane:

   | Lane | Result |
   |---|---|
   | 111 of 113 | pass, including `unit.kind-position-census` (both modes), `unit.diagnostic-census` (both), `property.differential` (both), every differential and every determinism lane |
   | `verify.rejections.chez.source` and `.aot` | **three cases fail**, listed below |

   - *"§16.2:908 is gated on byte-reachability, for every kind (Slice ⓪b) / an EOF-only-reachable byte edge into a finish is accepted"* — `expected (), got ((integer-accumulate unreachable-node) (sequence-dispatch unreachable-node) (byte-dispatch unreachable-node))`. `t2-machine`'s `fin` is reachable only through `hop`'s byte edge; for the three input-reading kinds that edge is dead at EOF, so `fin` is unoccupiable. The other five kinds in `t2-kinds` (pause, field-action, field-branch, callback, counted-consume) keep `fin` occupiable because the EOF walk flows through their zero-width successors — and, for counted consume, through `next` (decision 0030 item 5).
   - *"a benign EOF verdict never outranks a stop in a join (Slice ⓪b) / a `default-error` sibling does not mask the stop"* — `got ((unreachable-node . rj2) (eof-reachable-stop . s0))`: `x` is an EOF-only-reachable byte-dispatch whose fallback is the byte edge to `rj2`, and nothing else reaches `rj2`.
   - *"the span-state lattice (§16.2:899, :900, :907) / a node no execution can occupy contributes no state (0029 item 3)"* — `got (unreachable-node unreachable-node unreachable-node unreachable-node)`: decision 0027's own machine with a distinct `Z` — `cl` on `t`'s byte edge, then `exit`, `done` and `fin` behind it. **This is effect (a)**, in a fixture the pricing did not name.

   **Effect (b) does not occur.** The fixture named — `§16.2:898`'s group, "and `unreachable-node`
   does NOT catch it" — builds 0027's Context machine where `Z` *is* `T` (a `reexecute`
   self-loop on `t`), and `t` is occupiable: the entry is parked, its eof-target is `t`, the EOF
   walk visits it. *(Annotated 2026-09-06, Gate 0 discharged — the fixture is a collapsed
   two-node variant of 0027's machine, `t` playing both `T` and `Z`; 0027's machine as written
   has a distinct `Z` and is in the family. Decision 0031's Context states it that way.)* The family the narrowing rejects is `Z` **distinct from** `T` and reachable
   over `all-out-targets` only through a dead byte edge of `T` — transitively, so `fin` behind
   `exit`'s eof-target in the third case is in it — with `T` one of the three kinds whose byte
   edges are dead at EOF. **Effect (c) does not occur** either: no builder in the matrix's `kind-table` gives its
   placed node an EOF route to the sink (`ee`), and every host's fallback is a byte edge to
   `ee`, so `ee` is byte-reached in every cell that keeps it and the pruning count stays 3.
   The pricing's "three test files" that Slice ② of Milestone 6 corrected to "two it can name"
   is, measured, **one file, three cases** — and the census's `(unreachable-node 1)` row does
   not move, because the narrowing changes the walk and not the emission site.

   Both records stand as written; §4.1 carries the corrected accounting and Slice ⓪'s
   disposition annotates the parent's, per the amendment law.

2. **The diagnostic record is three of seven bullets**, and every design that noticed
   deferred here (Milestone 3 design §8, Milestone 4 design §4.6 and §9, decisions 0020 and
   0022). `diagnostic-message` is read by no test, which `§16.4:945` licenses; `diagnostic-edge`
   is read at five sites and is `#f` at 55 of 56 emission sites. Not a defect; a measured
   starting point for §4.2.

3. **`§16.2:910` is discharged by construction and no test says so.** Measured in
   `compile.sls`'s `render-machine`: **no declared name occurs in identifier position.** Every
   declared name that reaches the emitted text does so under `quote` — error codes and reasons
   in `(define errs (quote #(…)))`, field names, callback declarations and source-node names in
   the payload's `(quote #(#(…) #(…) #(…)))`, branch keys in the callback arm's `(quote (…))`,
   span names and node names in `(quote NAME)` — and error-declaration *names* never reach it at
   all (only their codes and reasons do; the goldens contain no `default-eof` or `rejected`).
   State identifiers are numbers. Two caller-chosen symbols sit in identifier position: the
   machine name, as the second element of the library name `(generated NAME)`, where nothing a
   binding could collide with lives; and the output binding, which `valid-binding?` checks
   against all three reserved members. So "generated identifier collisions" has exactly one
   producer and it is already refused — as an API-contract condition (`§9.2:378`), not a
   diagnostic. No assertion total over the declared-name set says so: `compile-tests.sps`'s
   literal checks and the goldens see only the constructs they spell out, so an emitter change
   that rendered a name of some other construct as an identifier would pass them. §4.8; the
   witness is Slice ④'s under `§25:1617`, and its parent-plan disposition is §4.12 item 1.

   **And one shipped check has no warrant.** `pass-names-valid` refuses a declared *name* that
   is an R6RS keyword (`reserved-member-1`: a node named `if` is `invalid-name`). `§16.2:886`
   is about portability and `if` is portable; `§16.2:910` is about generated identifiers and no
   name becomes one. The check dates from Milestone 1, when whether names would be emitted as
   identifiers was open. It rejects nothing a grammar needs and relaxing it would be a verdict
   change with no consumer; §4.12 item 3 recommends keeping it and recording why.

4. **`§16.2:911` has no owner.** Recorded as an orphan by Milestone 5's design §4.11 and §10
   and by Milestone 6's §4.11 and §8. Under decision 0005 there is one backend; §30:1778 asked
   which "identifier length and source-size limits appear in supported compilers" and no
   answer was recorded. Measured: no lane calls `compile-file` on a generated library
   (`rg compile-file test/` prints nothing; the AOT launcher compiles the *program's* imports,
   and a generated library is `load`ed at run time). §4.12 item 2.

5. **The seed cannot be varied without editing the test**, contrary to `§22.6:1293`'s
   intent and to the Milestone 0 harness plan, which wrote that when the PRNG arrived "its seed
   must come from the environment" (`milestone-0-slice-2-test-harness.md`). The seed *is*
   printed — the per-machine agreement label carries `(seed N)` — so the letter of `:1293`
   holds. §4.3.

6. **The two parked-set copies still differ**, and the tree records it: `pass-eof-execution`'s
   `§16.2:909` membership lists `span-end-node?`; pass 7's `parked?` does not, with a comment
   deriving the difference inert and warning that "the next kind that can pause has to be added
   to BOTH". §4.1 gives the narrowed reachability a third consumer of that set, which is one
   too many for two hand-written copies; Slice ⓪ makes it one procedure.

7. **`§22.5:1283` — "deterministic random multi-split schedules" — is implemented for fixed
   machines and not for drawn ones.** Three differentials import the PRNG and draw seeded
   multi-split schedules (`rg -l prng test/common/differential-*.sps`: sequence, sequence-node,
   http-version — each with a case named "a deterministic random multi-split schedule accepts
   and agrees" or its "32 draws" sibling); the span differential writes its schedules out as
   literals and says why ("a literal is the most reproducible form there is"), the counted-span
   differential derives its split and pair schedules and lists the rest. The property lane,
   the one program with a drawn machine, feeds one byte under one schedule. §4.4.

**And one hazard that is not a divergence but will mislead a slice.** The `§12.7:770`
zero-width-machine-action half is still wrong in **both** lanes (measured 2026-09-05, recorded
in the parent's `§12.7:770` disposition with its receivers). A generator that draws a fallible
field action over a reexecute edge into an error node will drive that path thousands of times
and every trial will pass, because the lanes agree. §4.4's invariant layer does not see it
either — `§12.7` is a table of position kinds and no invariant in that layer reads one. This
milestone does not become the receiver by drawing the shape; §10 says so, and the property
lane's header will too.

---

## 4. Gate 0 — design-call resolutions

Decision-only: no product code, no tests, no CMake. **The next free decision number is 0031**
(measured: `docs/decisions/` holds `0001`-`0030`, contiguous, plus `README.md`). §4.1, §4.2 and
§4.3 are one record each. §4.4-§4.8 stay in this design with no record; §4.9 is the gate every
slice asserts; §4.10 is the list of things this document deliberately does not decide; §4.11
disposes the obligations addressed to this milestone; §4.12 collects the scope additions the
parent plan does not name, for the owner.

> **Gate 0 discharged 2026-09-06**, as three records, as §11 planned.
>
> | Record | Carries | Shape |
> | --- | --- | --- |
> | [0031](../decisions/0031-reachability-is-the-occupiable-relation.md) | §4.1, with §3.2 item 1's measurement as its Context | five numbered items — the relation and its one procedure; the family, exactly, with what is not in it; `all-out-targets`' retirement and the three mutations it names by LABEL; one parked set, as a derivation with a measurement; what the three cases assert afterwards |
> | [0032](../decisions/0032-diagnostic-record-seven-fields-and-path-policy.md) | §4.2, with §3.1's slot census as its Context | six numbered items — the shape and the four accessors; the stamping in `verify-machine`; the `declarations` list per site; the path policy as the table, eight codes at twelve sites; the shape rule for tests; the census row |
> | [0033](../decisions/0033-property-suite-contract.md) | §4.3, with §4.4's Layer 3 table and §4.7's fixture shape | five numbered items — validity is the verifier's verdict; the counters and the floor; the seed; the fixture; the three-layer comparison with its qualifiers |
>
> **As performed.** No resolution was split or merged, and no decision changed. Three stated
> reasons were re-checked against the tree and corrected — one while writing, two by the
> whole-gate review. (1) §3.2 item 1 accounts for effect (c) with "no builder in the matrix's
> `kind-table` gives its placed node an EOF route to the sink"; `0031` states it as *no placed
> node names an eof-target — every input-reading builder passes `#f` — and the sink `ee` is
> `byte-reached` in every cell that keeps it*, which is the fact the unmoved count rests on,
> since the zero-width builders' continuations to `ee` are routes the EOF walk takes and "EOF
> route" reads as false for them. (2) §3.2 item 1 and §4.1 said the `§16.2:898` fixture "builds
> 0027's Context machine where `Z` is `T`"; the fixture is a collapsed two-node variant, and
> 0027's machine as written has a distinct `Z` and is in the family — `0031`'s Context and item
> 2 say so, §3.2 is annotated and §4.1 corrected in place. (3) §4.2 item 2 said "the rest keep
> their text and their pins"; the twelve path-bearing sites change too — forty-two of
> fifty-six — and eleven of the 27 pin lines sit at them (`0032` item 3; §4.2 corrected in
> place). One measurement was
> guarded rather than re-taken: `git diff --stat 5ac363a..HEAD -- src/ test/` printed nothing, so
> every record cites the prototype run of §3.2 item 1 and PR #83's reproduction of it. Two
> records carry Context this document left implicit: `0031` reads `pass-eof-execution`'s walk
> (from `parked-eof-start`'s answer) and `span-flow`'s (from `eof-step` of the parked node) as
> two procedures today and states their equality as a derivation the review measured, where
> §4.1 says only that the walk is `span-flow`'s `eof-nodes` verbatim; `0033` counts
> `machine-gen.sls`'s constraints by the file's own bullets — two rejection-driven rules, one
> reachability rule, four accumulate coverage pins — and names all six of Pass 39's mutations,
> which §4.3 does not.
>
> **Five records and one closed design reach back**, under `docs/decisions/README.md`'s
> convention: `0031` **amends** decision 0027's "Handed to nobody: `pass-reachability`" bullet
> and decision 0023's second Consequence (a header bullet, a site marker and a foot note in
> each) and **annotates** 0023's third Consequence (a site marker, the same note); `0032`
> **annotates** decisions 0020 and 0022 at their "Milestone 7" sentences (a header bullet only,
> each); `0031`'s Context **annotates** decision 0030's `§12.7:772` citation (a header bullet
> only, creating that record's Amendments block); and Milestone 6's design §8 pricing bullet, a
> record in a closed design, carries a dated note indexed in that document's Amendments block.
> Nothing above any note is rewritten.

### 4.1 `pass-reachability` walks the occupiable relation — the one hand-off, closed first

**The call.** `§16.2:897` says "unreachable nodes" and `§16.4:947` makes them errors; neither
says over which relation. The tree has two (decision 0027's Consequences table): `all-out-targets`
— byte edges and eof-targets mixed freely, read by `pass-reachability` alone — and the
*occupiable* relation — `byte-reached` plus the EOF walk from the parked set — read by `§16.2:908`,
`:909`, pass 7 and `pass-zero-progress`'s gate. 0027 item 1 defines the second, and the sentence
beneath its Consequences' relations table says it "is the one that means 'an execution can be
here'"; 0023's third Consequence raised the first as an
over-approximation and forbade reading it as closed; Milestone 6 priced narrowing it and handed
it here.

**Resolved: `pass-reachability` reads the occupiable relation, computed once and shared with
pass 7, and `all-out-targets` is retired.** A node no execution can occupy is unreachable in
the only sense the plan uses for the word — 0023 item 3's sentence, "a graph node no execution
can occupy is not a state that originates a traversal", transferred to its third consumer as it
was to its second. The implementation is the prototype the header describes, reproduced so the
measurement can be re-taken:

```scheme
;; pass-reachability, the one changed line:
(let ((nodes (machine-nodes m)) (reached (occupiable m)))
;; beside byte-reached:
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

The walk is `span-flow`'s `eof-nodes` verbatim; Slice ⓪ factors it out so the two read one
procedure (the "one census, two views" rule `node-out-edges`' comment states and
`zero-width-edges`' restates), and `span-flow` keeps
its edge list.

**The family whose verdict changes, stated exactly.** `E →(eof) T →(byte) Z`, where `T` is
reachable only through an EOF route, `T` is one of the three kinds whose byte edges are dead at
EOF — byte-dispatch, sequence-dispatch, integer-accumulate — and `Z` is a node **distinct from
`T`** reachable over `all-out-targets` only through a dead byte edge of `T` — transitively: a node
behind such a `Z`'s own eof-target is in the family too. `Z` gains `unreachable-node`. Not in the family, and
the design says so because each is a shape a reader will try: `Z = T` (a self-loop — `T` is
occupiable through the EOF route, measured on the `§16.2:898` gate fixture, a collapsed
variant of 0027's machine); `T` a counted consume
(`next` is an EOF successor, decision 0030 item 5, so `Z` behind it is visited); `T` any
zero-width kind (the walk flows through it); `Z` reachable by any other route. Measured effect on
the tree: **three cases in `verify-tests.sps`, both modes, nothing else** (§3.2 item 1) — the
census row `(unreachable-node 1)` stays, the matrix's pruning count stays 3, and every
executable lane stays green because no executable fixture holds a dead node.

**What the three fixtures assert afterwards, decided here so Slice ⓪ does not improvise.** Each
is re-baselined to the property it tests and gains the narrowing's witness, never rewritten to
hide it: the `t2-kinds` accept case asserts the whole `(code . node)` set per kind — empty for pause,
field-action, field-branch, callback and counted-consume, exactly `((unreachable-node . fin))`
for byte-dispatch, sequence-dispatch and integer-accumulate — a derived set, three kinds, the
same three §3.2 names, in the shape the shipped case already has (it collects every code per
kind); the join case asserts the whole list `((unreachable-node . rj2) (eof-reachable-stop .
s0))`, the shipped `check-equal`'s shape; the 0029 item 3 case asserts no span code and
`unreachable-node` at each of `cl`, `exit`, `done`, `fin`. Slice ⓪
also adds the family's canonical pair for each of the three kinds — `Z` distinct, REJECTED;
the same machine with `Z` also reachable by a byte edge from the entry, ACCEPTED — and the two
controls the paragraph above names (self-loop; counted consume), ACCEPTED.

**What does not change.** `byte-reached` and every `§16.2:908`/`:909` verdict; pass 7's domain
(0027 item 1 already); `pass-zero-progress`'s gate (0027 item 3, `byte-reached` alone, and the
reason it is not the composite stands); the diagnostic code and its single emission site. And
0023's "three machine families become legal" stands as a `:908` verdict — a byte edge from an
EOF-only node into a finish is still not a `:908` violation — but not as the *clean*
verification its second Consequence promised ("They carry accept-side fixtures, because
'verifies clean' is what the defect looked like"): for the three kinds whose byte edges are
dead at EOF, that finish is a dead node under `:897` unless it has another route. Two rules,
two bullets, both true of the same machine; the accept-side fixture keeps its `:908` half and
gains the `:897` finding, and 0023's second Consequence is **amended** by 0031's note, not
rewritten.

**One parked set.** `occupiable` reads pass 7's `parked?`, `pass-eof-execution` reads its own
disjunction, and the two differ by `span-end-node?` (§3.2 item 6). Slice ⓪ makes them one
procedure with the superset membership; the difference is derived inert for occupiability (a
byte-reachable span end's `next` is a byte out-edge, already in `byte-reached`), and the tree
derives it inert for pass 7 (`parked?`'s own comment; decision 0030 item 6) — re-measured for
this design's review: with the disjunct added to pass 7's copy under the narrowed walk,
`verify-tests.sps`, the matrix and the census answer exactly as without it — so the
unification changes no verdict and removes the second hand-written copy, which is the hazard
Milestone 6's design appendix named ("an inert disjunct is a mutation nothing can catch").

**Externally observable, which is why it is a record.** Which machines verify. Decision 0027's
"Handed to nobody: `pass-reachability`" bullet and 0023's second Consequence become false and
are **amended** by dated notes with site markers; 0023's third Consequence stays true and is
**annotated**; Milestone 6's design §8 bullet — a record in a closed design — gets a dated note
indexed in that document's Amendments block. Nothing is rewritten. Record **0031**.

### 4.2 The diagnostic record carries `§16.4`'s seven fields, and the path has a policy

**The call.** `§16.4:935-943` lists seven fields; the tree carries four
(`(vector tag code node message edge)`). `§25:1616` names "structured graph paths in
diagnostics" as scope, and four earlier artifacts assign the widening here (§3.2 item 2). Three
things are open: how the three fields no site has ever computed get filled without editing
fifty-six sites for two of them; what the `node` slot means once a `declarations` field exists;
and which codes carry a path, since `:943` says "when useful".

**Resolved, as one shape and three rules.** The record becomes
`(vector tag code node message edge severity machine declarations path)` — the four shipped
slots in place, so `diagnostic-code`, `-node`, `-message` and `-edge` are unchanged for their 122
test reads, and four new accessors exported: `diagnostic-severity`, `diagnostic-machine`,
`diagnostic-declarations`, `diagnostic-path`.

1. **Severity and machine name are stamped once, in `verify-machine`.** Severity is the
   constant `error` (`§16.4:938`; warnings deferred, `:947`); the machine name is
   `(machine-name m)` for every diagnostic of a machine and `#f` for `pass-schema`'s
   not-a-machine arm. Both are applied by one `map` over the appended pass results, so no
   emission site changes for them and the diagnostic census does not move. A per-site machine
   argument was rejected: fifty-six edits to thread a value every site would compute the same
   way, and a census move for nothing.
2. **The `node` slot keeps its shipped meaning — the subject's name — and `declarations` is
   added beside it, per site.** §3.1 measured nineteen sites whose subject is a declaration;
   those pass `(list subject)` as declarations too, and the sites that name a declaration
   *beside* a node pass it: `missing-error-declaration` (the error name), five of the seven
   `invalid-field-operand` sites (the field name; the arity and unknown-selector arms fire
   before any operand is read and have none to give), `missing-callback-declaration` and
   `invalid-callback-invocation` at a node (the callback name), `missing-span-declaration` (the
   span name), `invalid-span-callback` (the callback the span names). Every other site is
   untouched: `make-diagnostic` and `make-diagnostic/edge` keep their arities and fill the new
   slots with `'()` and `#f`, and the sites that carry a declaration list or a path call new
   constructors whose names begin `make-diagnostic`, so the census counts them. The slot is a
   list because `invalid-span-callback` can name a span and a callback at once. About thirty
   sites gain a `declarations` argument and the twelve path-bearing sites (item 3) a path —
   forty-two of fifty-six; the fourteen that keep their text keep their pins (of the 27 pin
   lines containing `make-diagnostic '`, eleven are at path-bearing sites, six at
   declaration-gaining sites, ten at unchanged sites — measured); Slice ① lists the moving
   sites by code.
3. **A path is carried by the codes a walk produces, and by no other.** "When useful" is
   read as "when the finding is about a path" — a diagnostic about a *place* (a duplicate, a
   bad name, an overlap, a dangling target, an unreachable node) has no path to give, and a
   list of names that merely leads to the node would be `§29:1760`'s visualization in
   disguise. The policy, total over the census:

   | Code | Path carried | Produced by |
   |---|---|---|
   | `eof-reachable-stop`, `eof-zero-progress-cycle` | the EOF walk's stack from `parked-eof-start`'s answer for the reporting node — the node itself, a parked callback's pause continuation, a parked counted consume's eof-target — to the stop, or around the cycle | `eof-terminal`'s `walk` — `path` already exists as the DFS stack; the walk returns the verdict and its path as a two-element `list` — never a `(cons 'verdict …)`, since the matrix's `edge-roles-in-source` collects every `(cons 'SYM …)` in `verify.sls` as an edge role and would go red — and `eof-verdict-join` keeps the surviving verdict's path, its left operand on a tie |
   | `zero-progress-cycle` | the cycle, from the reporting node back to itself | `self-cycle` returns the cycle *(renamed from `reaches-self?`, Slice ① F9)* |
   | `non-eof-into-finish` | the byte path from the entry to the source node, then the offending edge's target | `reach-from` gains a parent map; the zero-hop entry clause carries the one-element path |
   | `invalid-span-state`, `inconsistent-span-state`, `span-active-at-pause`, `span-active-at-exit` | a path from the entry to the node over `span-flow`'s edge relation | a parent map computed once from the edge list, before the fixpoint |
   | every other code | `#f` | — |

   A path is a list of node names starting at the walk's start — `parked-eof-start`'s answer
   for an EOF verdict, the entry otherwise — deterministic because every walk here visits in
   list order, the memoised `done` table is local to one `eof-terminal` call and records the
   first path that settled a verdict, and a tie in the join keeps its left operand — "a
   representative graph path", not a canonical one, and `§16.4:945` forbids a test from
   comparing it as text. Tests compare a path's *shape*: its first element (the start named
   above), its last, and membership.

**What the census gains.** A derived row: every emission site whose code is in the path-bearing
set passes a path argument, and no other does — read from `verify.sls` as a datum, the way the
constructor set is, so a new site under a path-bearing code cannot ship pathless.

**Externally observable, which is why it is a record.** Four public accessors on
`(byte-machine verify)`, and the content of two of them is a contract the failure-fixture
reports (§4.7) and any future diagnostic renderer will read. Record **0032**.

### 4.3 The property contract: the verifier decides validity, every draw proves it ran, and a failure is a file

**The call.** `§22.6:1295` says "bounded small verified machines"; it does not say who
guarantees *verified*. The shipped generator guarantees it by construction with
hand-written constraints — three verifier rules and four one-byte coverage pins (§2). `§22.6:1293` says print the seed; it
does not say where the seed comes from. `§25:1627` says failure fixtures "can be saved without
external tooling"; it does not say what a fixture is or where it goes. All three are contracts
a developer will rely on and a pin will be measured against.

**Resolved, as one contract in five clauses.**

1. **Validity is `verify-machine`'s verdict, not the generator's promise.** The generator
   draws from every construct (§4.4) with structural steering only where a draw would otherwise
   be *unconstructible* (a target must name something); every draw is verified; only an
   accepted machine reaches an executor. Rejected draws are counted by code and kept — Slice ④'s
   independent oracle reads them as free material — and never fed (`§22.6:1297`), which the lane
   asserts structurally: the count of machines handed to `make-interpreted-machine` equals the
   count the verifier accepted.
2. **Every drawn construct proves it ran, in the interpreter alone and in agreement.** For
   each node kind, each matcher kind, each field operation and predicate, each callback
   outcome, each span event and each schedule shape, a counter reads an *observed* value from
   the trial — a field that changed, a fragment delivered, a pause taken, a state name reached,
   a status returned — never the draw that requested it. Each counter has the two halves the
   shipped lane already has: interpreter-only (attribution: the arm ran) and agreed (the
   property held while it ran). Each is asserted ≥ 1 over the seed set; the shipped lane's
   eight counters are the precedent and stay. Plus one floor on the accepted count — a literal
   the plan fixes by measuring the rate under the committed seed and setting the floor no lower
   than half the machine count; a measured rate below half sends the draw back to §4.4 for
   steering before the lane lands — so a verifier change that starts rejecting most draws is a
   red lane, not a quietly shrunk one: clause 1's one real cost, made visible.
3. **The seed comes from the environment, with the committed default.**
   `BYTE_MACHINE_PROPERTY_SEED`, a decimal exact integer; unset or empty means the literal the
   program declares. The lane registrations pass nothing, so CI and every pin run the default;
   a developer replays a reported seed by setting the variable. The seed is printed once at the
   suite's start and carried in every machine-level check label (the shipped agreement label's
   shape). A mutation pin whose
   witness is a drawn shape names the seed it was measured under, in its comment.
4. **A disagreement writes a fixture and says where.** On the first disagreement for a
   machine, the lane writes a self-contained program (§4.7) to `BYTE_MACHINE_TEST_TMPDIR` —
   the per-lane directory the registration creates and nothing cleans (measured:
   `cmake/ByteMachineTesting.cmake` does `file(MAKE_DIRECTORY)` and no more; the FAIL-CONTEXT line
   already prints it as `artifacts=`) — and the check's detail names the file. Slice ③ adds
   the minimized twin beside it.
5. **The comparison is the nine members of `§22.4:1264-1272` plus the invariant layer**, per
   schedule, with `§22.5:1285-1289`'s across-schedule rules — the shipped fixed-machine
   differentials' oracles, applied to drawn machines (§4.4).

**Rejected: keeping validity by construction and extending the constraints.** Seven more kinds
means the generator encodes pass 7's lattice, decision 0030's join, the parked set and
`§16.2:908`'s gate by hand — a second verifier, in the test tree, that agrees with the first
by construction and can therefore never disagree with it. **Rejected: a generator that
retries until accepted without counting.** A filter with no floor is how a verifier
over-rejection disappears from the property lane without a trace.

**Externally observable, which is why it is a record.** The environment variable, the file,
its location and its shape are developer-facing; the default seed is what every pin in Pass 39
and its successors is measured against. Record **0033**.

### 4.4 The generator over every construct, and the differential's three layers

Design-internal; no record. The shape a plan implements.

**The draw.** A machine is built from the entry outward over a worklist of open target slots,
with a node budget (≤ 8 nodes beyond the fixed terminals), each slot filled by a fresh node of
a drawn kind (opening its own slots), an existing node (a back-edge), or a terminal; budget
exhaustion forces terminals. Kinds are drawn by **round-robin over a single global advancing
cycle** (started at 0, module-level, so the draw is reproducible across processes), not
uniformly [note 2026-09-11 (2)]: at 64 draws under the committed
seed a uniform draw leaves `clear` absent entirely and five more operations at exactly one
machine, and decision 0033 item 2 requires each counter *observed*, which is strictly rarer
than present. The kinds live in a **hand-written draw table in `machine-gen.sls`, exported**
[note 2026-09-11 (3)]; the **totality rows, in the property program**, derive `node?`'s closed
set from `ir.sls` and compare it to that table's keys, so a fourteenth kind reddens a totality
row before any fixture exists for it — and were the generator to draw from a list read out of
`ir.sls` during generation, the row would compare `ir.sls` against `ir.sls` and close nothing.
Declarations are drawn first: one or two uint
fields at drawn widths and initials; one or two callbacks of drawn kind with drawn keys and
`required?`; one or two span declarations (`§10.4:519` limits *active* spans to one, not
declarations, and wrong-end and overlap need two names), each naming a span-data callback and
— on a **single machine-level coin**, so every span in a machine gets a completion callback or
none [note 2026-09-11 (5)] — a completion callback, with span nodes drawn as a matched
start/end pair. The end carries **no** error sink: `make-span-end-node`'s parameter list is
`name span next source-label` (`src/byte-machine/private/ir.sls:620`), with no error slot, so
the pair's private error sink attaches to the **body** [note 2026-09-11 (1)] — start → one
advancing one-case byte dispatch carrying its own private EOF error node → end, the shape
`counted-machine.sls` already ships (measured: 0/0/4 fragment machines, acceptance 1160 vs
1128). An unmatched draw is rejected by pass 7 nearly always, and the shared sink joins `none`
with `(active s)` (decision 0029 item 2; measured during this design's review); the error
declarations every machine needs plus one or two more. Field nodes draw an operation or predicate from `ir.sls`'s closed
lists with operands inside the width; sequence nodes draw one to three alternatives of length
one to three; dispatches draw one to two cases over all four matcher kinds (a **bound**, not a
steering — §4.10's Bounds bullet) [note 2026-09-11 (4)]; every input-reading
node draws its EOF route from `{#f, a finish, an error, an existing node}`; counted consume and
accumulate name a drawn field. Nothing else is forced to be valid: the span steering is
coverage steering, and the verifier still decides.

**The scripted bindings.** Callbacks answer from the seed, not from a policy: for each
declared callback a script of outcomes drawn from `{continue, pause, a declared key, a
failure}` (`§13:803-808`), indexed by invocation, identical in both lanes, each lane recording
into its own accumulator (Milestone 5 Slice ③'s correction). Optional callbacks are bound in
half the draws: an unbound optional decision callback takes its default branch (`§9.3:419`),
an unbound event callback its continue target, and an unbound optional span-data callback
never runs at all — the fragment step short-circuits to continue — so the fragment counters
and Layer 3's span row exclude those draws. Span-data and completion callbacks record
`(start end bytes)` copied inside the dynamic extent, as the shipped span differential does.

**The inputs and schedules.** Per accepted machine: the 256 single-byte trials the shipped lane
runs (§22.7's all-byte coverage of the entry dispatch, kept as is), then eight drawn inputs of
length 0-6 driven under **every split point and every split-point pair**, leading and trailing
empty feeds, one sub-slice, one padded bytevector, and four seeded multi-split schedules —
`§22.5:1278-1283`'s **six** shapes [note 2026-09-11 (6)], the sixth finally random and printed.
After the feeds, `parser-finish!`, and on half the trials a
`parser-reset!` followed by one more feed (`§22.4:1272`).

**Layer 1 — the lanes agree, per schedule** (`§22.4:1264-1272`, `§22.5:1285`): status, `next`,
consumed, offset, fields, the callback trace (name, outcome, order), the fragment trace, the
pause continuation as the next operation's behaviour, the error projection
(`(byte-machine test error-projection)`, unchanged), and stop/finish/reset.

**Layer 2 — across schedules** (`§22.5:1287-1289`): the coalesced fragment trace and the
callback trace are invariant across every schedule of one input; the raw fragment trace is
provably not (the shipped assertion shape); on a malformed input, acceptance, error code and
absolute error offset are invariant and callback prefixes are compared within a schedule only.

**Layer 3 — invariants derived from the plan, per lane, per operation**, the layer neither
lane supplies:

| Invariant | Source |
|---|---|
| after each operation, `(status, lifecycle-after)` is in the row `§12.2:691-699` permits for `(lifecycle-before, operation)`; a contract condition is raised exactly where the row says "Contract condition" (`poisoned` and `busy` are unreachable with scripted callbacks and are not driven; a `stopped` from `parser-finish!`, which no row permits, is a `:909` hole and is reported as one) | `§12.2` |
| for a feed-originated result, `start ≤ next ≤ end`, `0 ≤ consumed ≤ end − start`, and the stream offset after the feed is the offset before plus `consumed`; for a `parser-finish!` result, `next` equals the offset and `consumed` is 0 (`§9.3:392-393` marks both "feed-originated results only"; the `§12.3:711` disposition records the shipped values) | `§11.1`, `§11.5:660`, `§9.3:392-393` |
| in a sticky state a feed returns `consumed` 0 and `next = start`, and the stored offset is unchanged | `§12.2:701` |
| every field value is an exact integer in `[0, 2^width)` | `§15` |
| `finished` is returned only by `parser-finish!` or a sticky feed after it — a verifier-completeness property: both executors carry an unconditional finish arm, and `§16.2:908`'s block over `node-out-edges` is what keeps a feed from reaching it | `§12.4`, decision 0011 item 2, `§16.2:908` |
| for a span that reaches its end with its data callback bound, the concatenation of its fragments in one schedule equals the input bytes between the span's start and end offsets; a span still open at an error delivers no final fragment and the row does not apply | `§14:831-834`, `:839` |

A trial that violates an invariant in one lane fails whether or not the other lane agrees.

**What this lane cannot see, said here so it is not claimed.** An agreed-wrong value that
satisfies every invariant — the position kind of a failed zero-width action reached over a
reexecute edge (`§12.7:770`'s open half) is the one in the tree today — is invisible to all
three layers, and the lane's header will name it.

> **Note 2026-09-11 (Slice ② implementation — six corrections in place above, one a
> tightening).** §4.4 is design-internal; §4.6 makes it the only specification Slice ④ has of
> the free mode, so a sentence the shipped generator contradicts is an instruction, corrected
> here, not a record. (1) The span pairing's "private error sink" is on the **body**, not the
> end: `make-span-end-node` has no error slot, so the pair is start → an advancing one-case
> byte dispatch with its own EOF error node → end. The pairing sentence stands; the sink clause
> already presupposed a node reached with a span open. (2) Kinds draw by **round-robin over a
> single global advancing cycle**, not uniformly: a uniform draw leaves `clear` unobserved at the committed seed,
> and 0033 item 2 needs *observed*. (3) The draw tables are **hand-written, exported tables in
> `machine-gen.sls`**, and the totality rows live in the **property program**, comparing
> `ir.sls`'s set to those keys — a generator that drew from a runtime-read `ir.sls` list would
> close nothing. (4) Dispatches draw **one to two** cases, a **bound** (added to §4.10's Bounds
> bullet), not a steering. (5) The completion callback is a **single machine-level coin** (per
> span it produces `unreferenced-callback-declaration`); the "one or two span declarations"
> count and "optional callbacks bound in half the draws" (below) stand. (6) The schedule set is
> **six** shapes, not five — `§22.5:1282` split-point **pairs** were absent; the sixth's "random
> and printed" deliberately departs from three shipped comments preferring a literal. The
> design Appendix's matching stale draw-tables line is corrected the same way as (3).

### 4.5 The corruption catalogue — positive and negative, total over the code set

Design-internal; no record. `§25:1619`'s bounded invalid-machine generator, first tier, and the
mechanism that discharges `§25:1625`.

**An entry** is `(name applies? corrupt expected)`: a predicate saying whether a base machine
offers a site for the edit; the edit, a pure function from a machine to a machine differing in
exactly one decision; and the diagnostic(s) it must produce, as `(code . node)` pairs *derived
from the `§16.2` bullet* the entry names — written before the run, never observed. The
appendix's ledger is the catalogue's table of contents: one or more entries per bullet, and
for the bullets the constructors enforce, the refusal recorded instead.

**An entry has two edits, not one.** The corruption, and its *near-miss twin* — the closest
legal shape, which must verify without the code: for `:897`, `Z` also reachable by a byte edge
from the entry; for `:908`, the EOF-only byte edge into a finish that has another route; for
`:909`, the one-shot "length, body, stop" grammar. The accepted base is silent trivially and
attributes nothing, being accepted; the twin is the negative `§25:1625` asks for and §3.1
defines, one edit from the fault and silent.

**The drive.** Over every accepted machine of the seed set, every applicable entry: the
corrupted machine's diagnostics **contain** the expected pairs (positive); the twin verifies
and its diagnostics **do not contain** the expected code (negative — the attribution check
`AGENTS.md` names, and the half `§25:1625` lacks); and the corrupted machine is never handed to an executor
(`§22.6:1297`, asserted as the catalogue's driver having no executor in scope). A count per
entry of the machines it applied to, each ≥ 1 — an entry that never applied is a red row. The
span codes apply only to span-bearing bases, which is why §4.4 steers span draws; if a seed set
still offers an entry no base, Slice ④ synthesizes a span-bearing base and says so.

**The totality sentinel**, which is the ratchet in the census's shape: the union of every
entry's expected codes, the constructor-refusal list (`§16.2:895`, `:896`, `:906`, the
width/initial/operation/base halves of `:889` and `:904`), and the unconstructible list
(`invalid-shape`: its not-a-machine half is not an edit of a machine and is driven as the
census drives it; its unsupported-version half is unconstructible through the public API,
`§9.1:320-322`, though `verify-tests.sps` forges one with a test-only vector) **equals** the
code set the census
derives from `verify.sls`. A new code fails here by name until it has an entry or a stated
reason; a code with no entry and no reason is the finding.

**Why it is a generator and not a table.** The base is drawn, so the edit lands in a different
context every time — a duplicate name among two nodes and among eight, a dangling target from a
dispatch and from a counted consume's `next`, a span re-entry inside a loop — and the expected
pair is the same. The enumerated instruments (§3.1) each fix a skeleton; this one fixes the
edit.

### 4.6 The independent oracle — the verifier's own differential, over the graph rules

Design-internal; no record. `§25:1619`'s second tier and the instrument `§25:1615`'s
"generative hardening" asks for.

**The scope** is the rules whose verdict a graph walk decides from the plan's sentence and a
recorded decision — a decision record is a commitment the oracle may read, `verify.sls` is
not:

| Rule | Oracle, written from | Compared code(s) |
|---|---|---|
| `:885` duplicates | equality over each table's names | `duplicate-name`, `duplicate-error-declaration`, `duplicate-callback-declaration`, `duplicate-span-declaration` exactly; `invalid-field-declaration` and `duplicate-branch-key` by containment (the oracle's set ⊆ the verifier's), since each has a non-duplicate arm |
| `:887`, `:905` resolution | every target names a node | `missing-target` |
| `:893` overlap | byte sets computed from the four matcher accessors — exact, set, range, complement — never from `matcher-bytes` | `overlapping-cases` |
| `:894` prefix | one alternative a prefix of another | `ambiguous-sequence-prefix` |
| `:897` unreachable | an independent walk implementing 0027 item 1's sentence | `unreachable-node` |
| `:908` byte edge into a finish | a byte-edge walk from the entry, the entry itself included (0023 item 2), reporting at the source node (0023 item 4) | `non-eof-into-finish` |
| `:909` EOF path to a stop | the EOF walk from 0023 item 3's parked set, each start at `parked-eof-start`'s answer (0023's 2026-09-06 note; 0030 item 6), under 0023 item 5's tiers: a start whose walk reaches a cycle reports the cycle and not the stop | `eof-reachable-stop` and `eof-zero-progress-cycle`, compared jointly per start |
| `:898` zero-progress | the edge rule the tree records as a deliberate over-rejection of `§11.4:654`: a cycle of reexecute edges, pause continuations, zero-width successors, accumulate overflow edges (`§12.7:773`; `reexec-targets`' accumulate comment in `verify.sls` and decision 0030's Context both cite `:772`, a blank line — Slice ⓪ corrects the comment in passing and Gate 0 annotates the record) and counted `next` (0030 item 7), digit edges excluded (`§10.6:566`), reported on byte-reached nodes only (0027 item 3) | `zero-progress-cycle` |

**The drive.** Free draws — §4.4's generator with its structural steering off, plus every draw
the property lane rejected — and per machine, per rule, the oracle's `(code . node)` set equals
the verifier's set for that code. Codes outside the table are not compared. Each rule fires ≥ 1
and stays silent ≥ 1 across the draws, or the row is red.

**Out of its scope, and why.** Pass 7's lattice (decision 0029 is a definition, and a second
implementation of a lattice is the lattice); the EOF verdict tiers (0023 item 5 — a ranking,
not a graph fact); the declaration cross-references of `:890-:892` and `:901-:902` (table
lookups the catalogue covers exactly); the field operand rules (`:889`, `:903`, `:904` —
arithmetic on declared widths, covered by the catalogue and Milestone 4's matrix). For `:898`
the oracle implements the *same* conservative rule the verifier does — a cycle of non-consuming
edges is rejected whether or not a byte can close it — not because `§11.4:654` says so (it
quantifies over cycles that *can run* without consuming, and names no edges) but because the
tree records the edge rule as a deliberate over-rejection of that sentence at two sites; a
difference between the two is therefore a finding, and equality is expected.

**Why it is worth a second implementation.** It is the one instrument here that can find a
defect nobody wrote a fixture for. Milestone 4 Slice ③ shipped three verifier defects past 368
mutations and a clean sweep; the matrix built afterwards catches their *shape*. A differential
over free draws catches shapes not yet named — which is exactly what the interpreter ≡
generated differential is for on the executor side, and this repository's whole method.

### 4.7 The printer, the fixture, and the minimizer

Design-internal; no record beyond 0033's clause 4.

**The printer** (`(byte-machine test machine-print)`, test support) renders a machine as the
`§9.1` constructor calls that rebuild it — a datum, written with the harness's own writer, never
implementation `write` of the tagged vectors. It is **total over the closed sets** and proves
it two ways: a derived row (every `node?` disjunct and every matcher predicate has an arm —
the S2 technique) and a round trip on every accepted machine of the seed set
(`render-machine` of the reprinted machine is byte-identical to `render-machine` of the
original; the IR fingerprint is the proof that the datum rebuilt the same normalized machine).
It is not `§29:1761`'s serialized IR format: it lives in `test/support`, emits Scheme source
against the public API, and has no reader but `load`.

**The fixture** is one R6RS program: the `import` the property lane uses, the machine datum,
the callback script and the schedule as quoted data, one `harness-group` with one case that
runs the same trial through `(byte-machine test property-driver)` — the lane's driver factored
into a library so the fixture and the lane share one body — and `harness-finish`. Run with the
shipped launcher, `chez-source.ss --program <file>`, it exits 1 on the disagreement and 0 when
fixed. "Without external tooling" (`§25:1627`) means exactly that: `chez`, the launcher, the
tree.

**The minimizer** reduces `(machine, script, input, schedule)` by a fixed sequence of
reductions — remove a node (its in-edges retargeted to a fresh error node of its own, never a
shared sink, which would join `none` with `(active s)` inside a span and stop every reduction
there at `inconsistent-span-state`), remove a case or an
alternative, remove an unnamed declaration, drop one input byte, merge two adjacent feeds,
drop a resume or the finish (a dropped resume makes the next operation a contract condition
in both lanes, which is agreement) — accepting a reduction iff the reduced machine **verifies** and the
reduced trial **still disagrees** (any disagreement, not necessarily the same tag), greedily to a
fixpoint, deterministic, bounded to 64 emissions. Its output is the minimized fixture beside the
raw one. Its oracle for validity is the verifier and for failure the lane's own comparison; it
introduces no third notion of either.

**Its test is a deliberate failure.** The lane cannot wait for a real disagreement, so Slice ③
ships a probe: a machine and a *wrong* second lane — a compiled machine whose op is wrapped to
lie about one member — driven through the saver and the minimizer, then the saved fixture
loaded and run in-process and asserted to fail, and the minimized one asserted smaller and
still failing. A saver that writes a fixture which passes is the defect to pin.

### 4.8 `§16.2:910` has one producer, already refused, and the finding needs a witness

Measured in §3.2 item 3: no declared name occurs in identifier position — every one that
reaches the text is under `quote`, and error-declaration names never reach it — the machine
name is half of a library name, states are numbers, and the output binding is the only
caller-chosen identifier a collision could touch — refused by `valid-binding?` against all
three reserved members as `§9.2:372-378` requires. **Resolved: `:910` is discharged by construction, and Slice
④ ships the structural witness that keeps it so** — a test reading an emitted library as a
datum (the `member3-drift` technique) and asserting that the set of symbols in identifier
position, minus the template's own identifiers (`reserved-member-3`, the runtime calls, the
library form), is exactly the binding and the library name's machine-name element — so it
contains no declared name — and, separately, that every declared name occurring anywhere in
the datum occurs under `quote`. An occurrence check over all declared names was the first
draft and is wrong: error-declaration names are never emitted, so it fails on any machine
declaring an error. Total
over a machine that declares every construct — the printer's round-trip fixture — so the claim
is measured against every emitted arm. The witness is `§25:1617`'s discharge and Slice ④'s
work whatever the owner decides; whether the parent plan records the finding as `:910`'s
disposition is §4.12 item 1.

### 4.9 What does not change — the gate every slice asserts

No executor, emitter, normalizer, runtime or ABI change: `git diff 5ac363a..HEAD --stat -- src/ ':!src/byte-machine/verify.sls'` prints nothing across the whole milestone, and every committed golden and every pinned fingerprint literal is byte-identical to `5ac363a`. `verify.sls` changes in Slices ⓪ and ①; `test/` and `docs/` change everywhere. One line of output from that command means this document is wrong and is amended before the code lands.

### 4.10 Resolutions that stay in this design and get no record

- **Bounds.** Sixty-four machines per seed set (forty today), a node budget of eight, inputs of
  at most six bytes, eight inputs per machine, four seeded multi-split schedules, and **one to
  two dispatch cases** (added 2026-09-11 [note (4)] — F3 classifies the case count as a bound,
  not a steering, so it belongs in this list) — chosen so both lanes stay under the shipped
  180 s timeout with margin. Measured 2026-09-11 (Task 8 Step 4, via ctest): the source lane
  ~4 s and the AOT lane ~4 s, both far under the timeout — the earlier "runs in under a second"
  measured no AOT lane, which had no measurement anywhere in the tree, and emission dominates.
- **Lane names.** `byte-machine.property.differential.chez.{source,aot}` keep their names (the
  registrations are cited by the mutation suite's Pass 39); the catalogue and the oracle are
  `byte-machine.property.rejections.chez.{source,aot}`; the reproduction probe is
  `byte-machine.property.fixture.chez.{source,aot}`. All under label `property`, which the
  `pr` preset already selects.
- **The generator's own totality rows** live in the property program: kinds from `node?`,
  matchers from `matcher?`, operations and predicates from `field-operations` and
  `field-predicates`, callback kinds from `make-callback-declaration`'s `memq` — each read from
  `ir.sls` as a datum and compared with the draw tables' keys. (Note 2026-09-11: the callback-kind
  `memq` had **no shipped source reader** — `rg -n "'memq" test/` printed nothing before this
  slice's own extractor added the term — so this slice
  writes the third extractor (F18), a walk to `(define (make-callback-declaration …) …)` finding
  the `(memq VAR '(…))` form; the other four reuse the diagnostic-/kind-census readers' shape.
  §7's registration table places these rows in `machine-gen.sls`; this slice follows §4.10 and
  keeps them in the **property program**, because a row inside a library reads `ir.sls` at run
  time and fails by a raise rather than a comparison, and the S2 operand argument needs the draw
  table declared on the other side of the comparison from `ir.sls`.)
- **`BYTE_MACHINE_PROPERTY_SEED` parsing.** `string->number` on the trimmed value; anything
  that is not an exact non-negative integer is a loud `assertion-violation`, not a fallback to
  the default — a typo that silently ran the default seed would report the wrong seed in every
  label.
- **Test-side censuses this milestone adds are named in the appendix**, so Milestone 8's
  slices find them: the draw tables, the catalogue's entry table, the oracle's rule table, the
  printer's arm table, the path-policy table.
- **The property driver becomes a library**, `(byte-machine test property-driver)`, read by
  the lane, the fixture and the minimizer — one body, three consumers, on the
  `error-projection` precedent ("eight local copies … is eight places for it to drift").

### 4.11 Obligations addressed to this milestone, each disposed

Measured: `rg -n -i 'milestone 7' src/ docs/decisions/ docs/reference/ test/` returns one
`src/` construct (`pass-reachability`'s note, two lines), two decision sites (0020 and 0022,
the record widening), one test site (`differential-span-tests.sps`'s topology table) and
nothing under `docs/reference/`. The same search over `docs/plans/ README.org CHANGELOG.md`
adds the status surfaces (history, not obligations), the deferrals the closed designs and plans
recorded (items 2-4 below), and one obligation in the parent plan's Milestone 5 close note that
the first draft of this list missed (item 6).

1. **`pass-reachability`'s note and the parent's `§25:1611` hand-off.** Closed by Slice ⓪
   under decision 0031; the note is corrected in place (an instruction) to say what the pass
   walks and who decided it, and the parent's disposition gets a dated annotation carrying
   §3.2 item 1's corrected accounting — a record, so annotated and not rewritten. The notes
   into decisions 0023 and 0027 and into Milestone 6's design §8 (the pricing's source) are
   Gate 0's, written with record 0031, so they are in the tree before Slice ⓪ starts.
2. **The diagnostic record's widening**, deferred here by Milestone 3's design §8, Milestone
   4's design §4.6 and §9, and decisions 0020 and 0022. Closed by Slice ① under 0032; the two
   decision records get annotating notes (nothing above them becomes false).
3. **The generator's missing draws**, deferred here by Milestone 3 (class matchers, sequence
   nodes), Milestone 5 (callbacks, spans — "extended nothing"), Milestone 6 §8 (counted
   consume, "draws every kind"). Closed by Slice ②.
4. **The bounded invalid-machine generator**, named this milestone's by Milestone 5 Slice ⓪'s
   plan (Tier 2a, Tier 2b — §10), Milestone 5's design §8 and `differential-span-tests.sps`'s
   topology table ("must not quietly become it"). Closed by Slice ④, in the two tiers that plan
   named, 2b widened from "an independent acyclicity walk" to §4.6's rules.
5. **`§16.2:911`**, an orphan. Priced and put to the owner as §4.12 item 2; if declined it
   stays an orphan and the close note says so again.
6. **`§25:1590`'s universal.** The parent plan's Milestone 5 close note records that "every
   invalid span topology is rejected" is established by an eleven-row table and a lattice
   group, not as a universal, and that "the generator that would make 'every' literal is
   Milestone 7's by name". This milestone makes the rejection *generative by edit* — the
   catalogue's `:899`, `:900` and `:907` entries over drawn span-bearing bases — and does
   **not** make it a universal: §4.6 keeps pass 7's lattice out of the independent oracle for a
   stated reason. Disposed as partly discharged, with the remainder named in §10 and in the
   close note; the adjudication end is that close note, the receiver end the topology table's
   comment, which Slice ④ corrects in place.
7. **Not this milestone's, and not made this milestone's by drawing the shape.** `§12.7:770`'s
   zero-width-machine-action half (receiver: whoever next touches `compile.sls`'s
   `field-action` arm or `interpret.sls`'s `field-step`) and `§9.3:392-393`'s `parser-result`
   enforcement (receiver: the next slice that changes `make-parser-result`'s shape). §4.9's
   gate is what proves this milestone touched neither; the property lane's header names the
   first as the agreed-wrong value it cannot see.

### 4.12 Scope additions — settled by the owner 2026-09-06

**All three items are approved** (owner, 2026-09-06, on merging PR #83). Items 1 and 2 are
dispositions of `§16.2` bullets: the work is a slice's under this
milestone's own scope either way, and what the owner decides is whether the parent plan's
appended dispositions record the finding. Item 3 keeps a shipped over-rejection. Each is
priced, with a recommendation, and names its slice (`AGENTS.md`, "an approval with no receiver
is invisible to every completeness sweep you have").

1. **APPROVED 2026-09-06. Dispose `§16.2:910` as discharged by construction, with Slice ④'s
   structural witness as its pin (Slice ④, under `§25:1617`).** Measured (§3.2 item 3): every declared name is emitted as data; the binding is
   the one caller-chosen identifier and is refused against all three members. The work is one
   test group reading an emitted library as a datum (Slice ④) and one appended parent-plan
   disposition under `§16.2` naming the witness. **Recommended: approve.** Declining leaves a
   `§16.2` bullet with no check and no statement that none is needed.
2. **APPROVED 2026-09-06. Dispose `§16.2:911` for v0.1 under decision 0005, with a witness
   that compiles the largest emittable machine.** No lane compiles a generated library with `compile-file`
   (§3.2 item 4). The work: one lane that renders a machine declaring every construct at the
   generator's bounds and a hand-built maximal dispatch (256 exact cases, and the same over a
   complement matcher) and runs `compile-file` on the result under the AOT launcher's
   conventions, asserting the object loads and one feed agrees with the interpreter; and one
   appended parent-plan disposition saying which limits were looked for — `§30:1778`'s
   identifier length and source size, `case` arity, literal size — and that none is reachable
   by a v0.1 machine. If the witness finds one, `:911` gains a check and a code and this item
   becomes a slice of its own. **Recommended: approve.** Slice ④ carries it; it is one lane.
3. **APPROVED 2026-09-06. Keep `reserved-member-1`'s exclusion on declared names, and record
   that it has no warrant.** Relaxing it is a verdict change (a node may then be named `lambda`) with no
   consumer asking and a pin sweep to pay; keeping it costs nothing and rejects nothing a
   grammar needs. The work is a comment at `valid-name?` and a sentence in the `§16.2:910`
   disposition. **Recommended: keep, and record (Slice ④, beside item 1's disposition).** Approving item 1 without this leaves the
   next reader deriving that the check is `:910`'s, which §3.2 item 3 shows it is not.

---

## 5. Slice ⓪ — The reachability narrowing, one parked set, and the family pinned

**Scope, as an allocation.** Discharges the `§25:1611` hand-off under `§25:1615`'s reading;
no `§25` bullet of its own. Depends on Gate 0 (decision 0031). Everything in it was measured
by the prototype in §3.2 item 1, and the slice's first task is to re-take that measurement at
its own base commit before changing anything.

**Delivered 2026-09-07 as PR #89**, base `733b32e` (`src/` and `test/` byte-identical to
`5ac363a`, so §3.2 item 1's measurement re-took verbatim: 111 of 113 lanes, the same two lanes
and the same three cases, nothing else). `release` **114/114**; mutation suite **58 passes /
525 mutations**; diagnostic census unmoved at **30 codes over 56 sites** with
`(unreachable-node 1)`; matrix pruning count **3**.

**The work**, one source file and one test program, plus pins:

- **`verify.sls`.** `occupiable`, factored out of `span-flow`'s `eof-nodes` so both read one
  procedure; `pass-reachability` reads it; `all-out-targets` deleted (it has no other consumer
  — measured, `rg -n all-out-targets src/` returns its definition, the one call in
  `pass-reachability`, and four comment lines); the two
  parked-set disjunctions become one `parked?` with `pass-eof-execution`'s superset membership,
  read at both sites; `pass-reachability`'s note corrected in place to say what it walks,
  which record decided it, and that the family of §4.1 is the verdict change.
- **`verify-tests.sps`.** The three cases re-baselined exactly as §4.1 states, each keeping
  the property it tested and gaining the narrowing's witness; a new group, "reachability is
  the occupiable relation (decision 0031)", carrying the family's REJECTED/ACCEPTED pair for
  each of byte-dispatch, sequence-dispatch and integer-accumulate — `Z` distinct and dead,
  then `Z` also byte-reachable from the entry — and the two ACCEPTED controls (the self-loop;
  `Z` behind a counted consume's `next`), with the rejected node asserted by name.
- **The census and the matrix** do not move (§3.2 item 1, measured) and the slice asserts
  that by running them rather than assuming it.
- **Pins.** *Corrected in place 2026-09-07 against what the slice measured; the paragraph
  below is the shipped census, and the sentence it replaces under-listed the work three ways.*
  The design named three mutations by LABEL and delegated the rest to
  `rg -n -F "(symbol? (node-eof-target n))"` against the suite — which finds the *enumerated*
  and *span-end* pins and misses the D-1 entry pin and the byte-reachability gate, two under
  the same membership. It also named nothing for the mutations whose `FIND` does **not** move
  but whose OBSERVATION the narrowing changes, and nothing for the disjunct whose only witness
  lives in another SPEC lane. Measured, by lexing every `byte_machine_mutation(` block whose
  `FILE` is `verify.sls` (137 at the base) and locating each whole `FIND` in the source:
  **eleven** land in the constructs this slice edits — **five re-anchor**: four onto the
  unified `parked?` (`FIND` and `REPLACE` together, each re-measured: failing-check counts
  2, 2→4, 5→6, 1) and one, the `all-out-targets` arm-2 mutation, onto **`eof-step`**;
  **one re-shapes its `REPLACE`** (the Slice ③ `span-flow` mutation, whose `REPLACE` named the
  deleted procedure — an unbound identifier is a raise and not a comparison); and **five
  `FIND`s stay**. *Nothing retires.* The slice's first draft retired the arm-2 mutation on
  this section's own reading — that its decision was subsumed by the new group's
  sequence-dispatch pair — and the whole-branch review measured that false: in that pair `T`'s
  eof-target is the error node, already byte-reached, so the walk answers the same with or
  without `node-eof-target`'s sequence arm. The decision was RELOCATED by 0031, not subsumed:
  `eof-step` is the reader now, and the mutation is anchored there, emitting the same
  separating `got 1` it always did. **Three more move without their `FIND` moving** and
  no census by `FIND` location can see them: the zero-width out-targets arm (its fixture's
  zero-width node is the ENTRY, hence parked, so the EOF walk rescues it — a second machine
  was added where the node is byte-reached instead), the `§16.2:908` gate (its pin read a case
  label this slice renames — the CHECK label, not the case name, which is unchanged), and the
  counted consume's `next` (its pin read an entry-stop record the narrowing empties). **Three are added**: `occupiable` mutated back to the retired
  walk, and the unified `parked?` losing each of the two previously unpinned disjuncts.
  "each caught by the case that disjunct's kind already has" is true of the **pause** —
  Milestone 6 Slice ①'s "the same through a pause continuation is rejected at the pause" —
  and **false of the callback**: `verify-tests.sps` passes with that disjunct gone, on the
  pre-0031 tree and on the unified one alike, and its witness is
  `unit.kind-position-census`'s axis-A cell `(callback-pause-continuation stop)`, so that
  mutation is declared in the census lane's pass. A mutation is witnessed only by its own SPEC
  lane's program. Finally, the two-direction sweep found **three shipped incumbents** newly
  satisfied by a changed mutant, all three bare prefixes — two of a case or check label, and
  one of a `got` VALUE in the census — re-anchored on whole measured records.
  `EXPECTED_MUTATIONS` 522 + 3 = **525**, measured; `EXPECTED_PASSES` stays 58.

**Oracle.** *The verdict change is exactly the family:* the release selection minus the
mutation lane fails at the three named cases and nowhere else on the unmodified tests, before
the re-baseline — re-taken, not assumed, because the base commit has moved since the
prototype. *Nothing else moved:* census `(unreachable-node 1)`, matrix pruning count 3,
every executable lane green, every golden byte-identical. *Both ends:* the `verify.sls` note
names 0031; the parent's `§25:1611` hand-off gets its dated annotation with the corrected
accounting; 0023's, 0027's and Milestone 6's design §8's notes are Gate 0's (record 0031) and
are already in the tree, and this slice's plan verifies them rather than writing them.

---

## 6. Slice ① — The seven-field record and the path policy

**Scope, as an allocation.** Discharges `§25:1616` (structured graph paths in diagnostics) and
`§16.4:938`, `:939`, `:942`, `:943`. Depends on Gate 0 (decision 0032) and follows ⓪ so its pin
sweep is about shape alone.

**The work.**

- **`verify.sls`.** The record's four new slots and four accessors, exported; severity and
  machine stamped in `verify-machine`'s one `map`; `declarations` passed at the sites §4.2
  item 2 lists, through constructors named `make-diagnostic…` so the census counts them;
  paths at the sites §4.2 item 3's table names — `eof-terminal`'s `walk` returning
  the verdict and its path as a two-element `(verdict path)` list *(corrected from
  `(verdict . path)`, Slice ① F13: a `(cons 'verdict …)` pair would enter the kind ×
  position matrix's edge-role vocabulary and redden it)* with the join keeping the
  survivor's, `self-cycle` *(renamed from `reaches-self?`, F9)* and `reach-from` gaining
  parent maps, `pass-spans` computing a parent map from its edge list before the
  fixpoint. No pass changes a verdict.
- **`verify-tests.sps`.** For each path-bearing code, one case asserting the path's shape —
  first element, last element, membership of the offending node — on a fixture whose path is
  unambiguous; for each declaration-bearing site, the `declarations` list asserted; for
  severity and machine, one case each over a multi-diagnostic machine (every diagnostic
  stamped, `#f` for the not-a-machine arm).
- **`diagnostic-census-tests.sps`.** The derived row of §4.2: every site under a path-bearing
  code passes a path and no other site does, read from the datum; the constructor set is
  already derived.
- **`kind-position-census-tests.sps`.** No cell moves; asserted by running it.
- **Pins.** Every `FIND` anchored on a `make-diagnostic` call whose site gains an argument
  moves — measured at plan time by `rg -n -F "make-diagnostic '" test/support/cmake/SchemeMutationSuite.cmake`
  and reconciled by LABEL; each re-anchored `FIND` with its `REPLACE` together. New pins: the
  stamping `map` dropped (severity and machine read `#f` — a comparison catch on the stamping
  case); each parent map replaced by an empty path; the join keeping the loser's path.

**Oracle.** *Shape only:* every existing assertion in the tree passes unchanged before the new
cases are added — 129 accessor reads *(corrected from 122, Slice ① F14: Slice ⓪ added cases
between decision 0032's measurement at `50516af` and this slice's base)* and the census's
counts — so the widening is proven invisible to what shipped. *Total:* the census's path row is green with the twelve
path-bearing sites and red when any one is made pathless. *Public:* the four accessors are
exported, the CHANGELOG names them, and `reserved-drift-tests.sps` stays green (the runtime's
export set is untouched).

---

## 7. Slice ② — The generator over every construct, and the property suite

**Scope, as an allocation.** Discharges `§25:1618` (bounded valid-machine generator — as
rebuilt), `§25:1620` (differential property suite), `§25:1621` (deterministic failure seed
reporting), and re-verifies `§25:1626` (both
execution lanes) under the new lane names. Depends on Gate 0 (decision 0033) and on ⓪.

**The work.**

- **`machine-gen.sls`**, rewritten to §4.4's draw: the declaration draws, the worklist over
  open slots, every kind and every matcher, the scripted callbacks, the EOF-route draw, the
  bounds; and its own totality rows against `ir.sls` read as a datum. The hand-written
  constraints go, with their comments — the three verifier rules and the four coverage pins §2
  counts; what replaces the rules is the verifier.
- **`(byte-machine test property-driver)`**, new: the trial — feed, pause protocol, finish,
  optional reset — the three comparison layers, and the counters, as one library the lane
  reads now and the fixture reads in Slice ③.
- **`property-differential-tests.sps`**, rewritten over the driver: the seed from
  `BYTE_MACHINE_PROPERTY_SEED` with the committed default, printed once and in every label;
  the accepted/rejected accounting with the floor; the counters with interpreter-only twins;
  the 256 single-byte trials kept; the drawn inputs under `§22.5`'s schedules; the
  across-schedule invariants; the invariant layer.
- **CMake.** The two registrations keep their names and gain `property-driver.sls` in their
  manifests; the timeout is measured, not guessed. (Note 2026-09-11: both registrations also
  gain `ENVIRONMENT BYTE_MACHINE_SOURCE_ROOT=…/src` (F20), which this bullet did not name — the
  totality rows read `ir.sls` as a datum and a census that silently read the wrong tree would
  report every source-side mutation caught for nothing.)
- **Pins.** Pass 39's six mutations are each a claim about a draw that no longer exists in
  that form ("machine-gen: the pause draw's coin is hard-wired to false", "machine-gen: the
  accumulate field's initial is one below the only workable value"); each is **retired with its reason** or re-anchored on the new draw that carries the
  same decision — decided per mutation at plan time, never loosened until green. New pins,
  from a list: the verifier filter dropped (rejected draws executed — caught by the structural
  count); each kind's draw arm removed (its counter reads zero); each matcher's; the script
  answering `continue` unconditionally (the branch and failure counters); the split-point
  sweep collapsed to one feed (the schedule counter); an invariant's comparison inverted (the
  invariant case); the floor removed (a declared survivor is *not* acceptable here — the
  witness is a mutant that rejects everything). Each judged against the other mutants in its
  lane, the sweep run in both directions, each pin's match count in its own mutant's output
  exactly one.

**Oracle.** *Coverage is observed:* every counter ≥ 1 in both halves under the committed seed,
and the accepted count ≥ the floor. *Both lanes:* the source and AOT registrations green with
identical counters. *Reproducibility:* the same seed yields the same draws in two processes
(the PRNG's existing case, one level up: the generated machines' fingerprints are equal across
two runs). *Nothing agreed-wrong is claimed:* the header names `§12.7:770`'s open half as the
value this lane cannot see. *No mechanism:* §4.9's gate.

---

## 8. Slice ③ — The printer, the fixture, and the minimizer

**Scope, as an allocation.** Discharges exit `§25:1627` (minimized/reproducible failure
fixtures saved without external tooling). Depends on ②.

**The work.**

- **`(byte-machine test machine-print)`**: the printer of §4.7, total over the kinds and
  matchers by a derived row, proved by the round trip on every accepted machine of the seed
  set.
- **The saver**, in the property driver: on the first disagreement per machine, the fixture
  program written to `BYTE_MACHINE_TEST_TMPDIR` and its path in the check detail.
- **The minimizer**, in the driver: §4.7's reductions, oracles and bound; the minimized
  fixture written beside the raw one.
- **`property-fixture-tests.sps`**, new, both lanes: the deliberate-failure probe — a lying
  second lane driven through the saver and the minimizer; the raw fixture loaded in-process
  through `eval` and asserted to fail; the minimized one asserted strictly smaller (fewer
  nodes or a shorter input) and still failing; a passing pair asserted to write nothing.
- **Pins.** The printer's arm for one kind emitting another's constructor (the round trip
  catches it by fingerprint); the saver writing the base machine instead of the corrupted
  trial (the reloaded fixture passes); the minimizer accepting a reduction that no longer
  disagrees (the minimized fixture passes); the bound — pinned only after an attempt: a probe
  whose lying lane disagrees on every reduction reaches it, and if no probe can, the survivor is
  declared with that measured reason, never before the attempt.

**Oracle.** *A fixture reproduces:* the probe's saved program, run through `chez-source.ss`
from the tmp directory with the tree's library roots, exits 1 — asserted in the lane by
`eval`, and once by hand in the plan's verification with the launcher command written out.
*The printer is total:* the derived row and the round trip. *Without external tooling:* the
fixture imports only what the lane imports.

---

## 9. Slice ④ — The corruption catalogue, the independent oracle, and the close

**Scope, as an allocation.** Discharges `§25:1617` (through §4.8's witness), `§25:1619`
(bounded invalid-machine generator, both tiers) and exit `§25:1625` (every required diagnostic has positive and negative tests), plus
the `§16.2:910` witness (§4.8) and, if approved, §4.12 items 1-3; and writes the milestone's
close note. Depends on ① (what a diagnostic carries) and ② (the accepted machines it corrupts).

**The work.**

- **`property-rejections-tests.sps`**, new, both lanes: the catalogue of §4.5 driven over the
  seed set's accepted machines — positive, negative, never executed, per-entry application
  counts, and the totality sentinel against the census's derived code set; the independent
  oracle of §4.6 over the free draws and the rejected draws, per rule, with its own fire/silent
  counters.
- **The `:910` witness** in `compile-tests.sps` (§4.8), and §4.12 item 2's `compile-file` lane
  if approved.
- **The close-out.** The `§25:1615-1627` disposition appended to the parent plan, each bullet
  and criterion against the tree; §4.11's seven obligations each dispositioned with both ends;
  §4.12's items each recorded as approved-and-shipped or declined; the Exit table below
  dispositioned in place; the status surfaces — `README.org`, `CHANGELOG.md`, the parent's
  Status line, this document's header, and every source comment that names Milestone 7 as a
  receiver (`rg -n -i 'milestone 7' src/` prints exactly the lines of `pass-reachability`'s
  corrected note, quoted in the plan, and no line containing `owed` or `failing that`).
- **Pins.** Each catalogue entry's edit made a no-op (its positive fails — a comparison
  catch); the negative check dropped (a twin that is the corruption itself goes green —
  witnessed by swapping one entry's twin for its corruption); the totality sentinel's union
  losing the refusal list; each oracle rule replaced by "never fires" (its fire counter) and by
  "always fires" (its silent counter); the `:910` witness's quote-position walk skipping the
  payload.

**Oracle.** *Total over the code set:* thirty codes today, each with an entry or a stated
reason, derived not declared. *Positive and negative per code:* by construction of the drive.
*The oracle agrees:* zero differences on the committed seed, each rule having fired and stayed
silent. *Three questions at the close* (Milestone 6's §9): which exit criteria are met, which
obligations named this milestone (§4.11), and what this milestone approved that the tree does
not contain (§4.12).

---

## Exit (full Milestone 7)

`§25:1625-1627`'s three criteria, allocated to the slices that will discharge them. At close,
each entry gets a **dated disposition** naming the slice, the file and the case in the tree
that meets it — never reworded to match what shipped.

| Criterion | Allocated to | What will meet it |
| --- | --- | --- |
| **:1625** — "every required diagnostic has positive and negative tests" | **④** | The catalogue's drive: for every code in the census's derived set, an entry whose corrupted machine emits it and whose base does not, with a stated reason for the codes a constructor refuses or the public API cannot construct. "Required" is read as the code set `verify.sls` emits, which is the ratchet's set; the positive half is already the census's, the negative half is new. |
| **:1626** — "property suite runs in both execution lanes" | **②** (already true; re-verified) | The `.chez.source` and `.chez.aot` registrations of every property lane, green with identical counters; stated at close that this criterion held before the milestone and what the milestone added under it. |
| **:1627** — "minimized/reproducible failure fixtures can be saved without external tooling" | **③** | The probe: a saved fixture that reproduces through the shipped launcher and a minimized one that is smaller and still reproduces; the printer's totality and round trip. |

---

## 10. Explicitly out of Milestone 7

- **Any change to an executor, the emitter, the normalizer, the runtime or the ABI** — §4.9's
  gate. This milestone hardens the verifier and the tests.
- **`§12.7:770`'s zero-width-machine-action half** and **`§9.3:392-393`'s `parser-result`
  enforcement** — their receivers are unchanged (§4.11 item 7). The property lane will drive
  the first shape thousands of times and cannot see it (§4.4); its header says so.
- **Relaxing `reserved-member-1`'s exclusion on declared names** — §4.12 item 3 recommends
  keeping it; relaxing is a verdict change with no consumer.
- **A serialized IR format, a CLI, a visualizer** — `§29:1760-1762`. The printer is test
  support emitting constructor calls; the fixture is a lane's failure path; a path is a list.
- **Warning severity** — `§16.4:938` fixes `error`; `§16.4:947` defers policy. The slot exists
  after Slice ① and holds one value.
- **Pass 7's lattice, the EOF verdict tiers, the declaration cross-references and the field
  arithmetic in the independent oracle** — §4.6 says why each is outside a second
  implementation's honest scope; the catalogue covers them by edit.
- **`§25:1590` as a universal** — still enumerated after this milestone (§4.11 item 6): the
  catalogue rejects drawn span faults by edit, and the lattice stays outside the independent
  oracle.
- **A property lane over the HTTP fixture** — Milestone 8's, `§25:1629-1649`.
- **Cross-platform determinism of drawn machines** — Milestone 9's, `§25:1651`; the
  property lane compares two lanes on one cell, and the determinism lanes compare goldens.
- **A transition/cursor semantics reference or a diagnostic catalog** (`§27:1693`,
  `§27:1696`) — `§27` names no milestone; Slice ①'s path policy is the first content a
  diagnostic catalog would carry, and the close note says so without writing one.

---

## 11. Handed to writing-plans

- **Gate 0 is discharged** (2026-09-06; §4's blockquote carries the discharge as performed):
  three records — `0031` "Reachability is the occupiable relation — `pass-reachability` walks
  it, `all-out-targets` retires, and the family whose verdict changes" (§4.1); `0032` "The
  diagnostic record carries `§16.4`'s seven fields, and the path has a policy" (§4.2); `0033`
  "The property suite's contract — the verifier decides validity, every draw proves it ran,
  the seed comes from the environment, and a failure is a file" (§4.3) — with the notes into
  decisions 0027, 0023, 0020, 0022 and 0030 and into Milestone 6's design §8 in the tree.
  Every reason in a record was checked against the code and the spec, not against this
  document — the sentence `AGENTS.md` puts in the reviewer's prompt verbatim.
- **§4.12 is settled (owner, 2026-09-06): items 1-3 approved.** Each lands in Slice ④'s plan;
  the two parent-plan dispositions (items 1 and 2) are appended by Slice ④ with the witnesses'
  measurements, never before them.
- **Re-measure every `file:line`, every count and the prototype in §3.2 item 1 at plan-writing
  time.** They were measured at `5ac363a`. Slice ⓪'s plan re-takes the narrowing measurement
  at its own base before listing the cases it re-baselines; Slice ①'s plan lists by LABEL every
  pin whose `FIND` touches a `make-diagnostic` site it edits; Slice ②'s plan decides each of
  Pass 39's six mutations by name.
- **Re-run the appendix's ledger over `verify.sls` and the census before writing Slice ④'s
  plan**: a code the census derives and the ledger lacks is the finding, and the ledger is
  corrected in place — it is an instruction.
- **Slice ⓪ is one PR of one source commit and one documentation commit**; ① likewise; ③ and ④
  one each plus documentation. ② is **one** source commit unless the plan finds a green
  partition: four of Pass 39's six mutations `FIND` text in `machine-gen.sls` that the rewrite
  deletes, a stale `FIND` fails the mutation lane at declaration, and the mutation lane is in
  the release selection — so the generator, the driver, the rewritten lane program and every
  pin whose `FILE` the commit rewrites land together with `EXPECTED_MUTATIONS`. The rule fixes
  a partition, not a count (Milestone 6's §9): a commit that adds pins without moving
  `EXPECTED_MUTATIONS`, or rewrites a pinned file without its pins, is red by construction and
  is not scheduled.
- **Decide whether ③ folds into ②**, with §2's cost stated.
- **The close-out asks three questions** (§9), and the third — what did this milestone approve
  that the tree does not contain — is asked against §4.12 by item number.

---

## Appendix — the `§16.2` ledger

**This table is an instruction**: Slice ④ works it as the catalogue's table of contents and
Slice ① as the path policy's checklist, and a row a slice cannot follow is corrected in place.
Rows are keyed by the `§16.2` bullet, because the exit criterion is stated over "every required
diagnostic" and the bullets are where "required" is written. Codes and site counts are the
census's (`pinned-sites`, 2026-09-06), and the transcription is checked rather than trusted: the
union of the diagnostic codes the ledger names (the `:910` row names a contract condition, not
a code) equals `(map car pinned-sites)` — thirty — and its site counts sum to 56. The first draft lacked `unreferenced-callback-declaration`; the review found it, which
is what §11's instruction to re-run the ledger is for. *Negative today* counts `(not (memq 'CODE …))`
assertions in `verify-tests.sps`.

| `§16.2` | Bullet (short) | Enforced by | Code(s) (sites) | Positive today | Negative today | Catalogue entry (④) | Path (①) |
|---|---|---|---|---|---|---|---|
| `:884` | invalid descriptor shapes; unsupported IR versions | `pass-schema` | `invalid-shape` (2) | census (`'not-a-machine`) | — | the shape half: `verify-machine` of a non-machine, as the census does; the version half **unconstructible** (`§9.1:320-322`), listed by name | no |
| `:885` | duplicate declaration names | `pass-names`, `pass-fields`, `pass-declarations` | `duplicate-name` (1), `duplicate-error-declaration` (1), `invalid-field-declaration` (dup arm), `duplicate-callback-declaration` (1), `duplicate-span-declaration` (1), `duplicate-branch-key` (2) | census | — | duplicate one node / error / field / callback / span / key | no |
| `:886` | nonportable names, codes, branch keys, labels, reasons | `pass-names-valid`, `pass-fields`, `pass-declarations` | `invalid-name` (6), `invalid-field-declaration` (2) | census, the nineteen-carrier label table | "portable names on their own are clean" | one entry per carrier family: a non-portable name, label, reason, code or key | no |
| `:887` | missing entry or transition targets | `pass-names` | `missing-target` (2) | census | — | retarget one edge, or the entry, to a fresh symbol | no |
| `:888` | missing or invalid machine error declarations and references | `pass-names`, `pass-eof` | `missing-error-declaration` (1), `invalid-eof-target` (default arm) | census | — | drop the declaration an error node names; rename the machine default | no |
| `:889` | invalid field widths, initials, constants, masks, operations | constructor (width, initial, operation); `pass-field-operands` (constant, mask, range) | `invalid-field-operand` (7) | census (`range` past the width) | 1 | widen a constant or mask past the width; `low > high`; the constructor halves recorded as refusals | no |
| `:890` | missing or incompatible callbacks | `pass-declarations` | `missing-callback-declaration` (3), `invalid-span-callback` (2), `invalid-callback-invocation` (3) | census | — | drop the declaration a node or span names; swap a named callback's kind | no |
| `:891` | optional decision callbacks without a valid default | `pass-declarations` | `invalid-callback-declaration` (2) | census | — | clear an optional decision callback's default; give an event callback keys | no |
| `:892` | invalid span callback declarations | `pass-declarations` | `invalid-span-callback` (2) | census | — | as `:890`'s kind swap, on the completion callback too | no |
| beside `:890`, by analogy | a span-kind callback no span names | `pass-declarations` | `unreferenced-callback-declaration` (1) | census | — | declare a span-data or span-complete callback no span names | no |
| `:893` | duplicate or overlapping byte transitions | `pass-overlap` | `overlapping-cases` (1) | census | — | add a case whose canonical set meets an existing case's, for each matcher pairing | no |
| `:894` | sequence ambiguities after prefix analysis | `pass-sequence-ambiguity` | `ambiguous-sequence-prefix` (1) | census | — | add an alternative that is a proper prefix of another; a duplicate alternative | no |
| `:895` | missing explicit fallback | constructor (`make-byte-dispatch-node`, `make-sequence-dispatch-node`) | — | matrix absence census | n/a | recorded as a refusal | no |
| `:896` | invalid transition advancement modes | constructor (`make-edge`) | — | `ir-tests.sps` | n/a | recorded as a refusal | no |
| `:897` | unreachable nodes | `pass-reachability` — the occupiable relation after ⓪ | `unreachable-node` (1) | census | 4 | an orphan node; and ⓪'s family — a node hung off an EOF-only input-reading node's byte edge | no, by definition |
| `:898` | reachable zero-progress cycles | `pass-zero-progress` | `zero-progress-cycle` (1) | census | 3 | flip a byte-reachable case or fallback to `reexecute` at itself; point a zero-width successor at its own node | **the cycle** |
| `:899` | span re-entry, overlap, wrong end, unmatched end, inconsistent exits | `pass-spans` | `invalid-span-state` (4), `inconsistent-span-state` (1) | census, the eleven-row topology table | — | a second start inside the span; an end with none open; an end naming the other span; a second in-edge with the other state | **entry → node** |
| `:900` | pauses or callbacks reachable with a span active | `pass-spans` | `span-active-at-pause` (1) | census | — | insert a pause or a callback node inside a span | **entry → node** |
| `:901` | callback branches missing, duplicated, undeclared | `pass-declarations` (node half) | `invalid-callback-invocation`, `duplicate-branch-key`, `missing-callback-declaration` | census | — | drop / duplicate / rename a branch entry | no |
| beside `:901`, by analogy (the parent's `§16.2:899`/`:901` disposition) | a span node naming an undeclared span | `pass-declarations` | `missing-span-declaration` (1) | census | — | rename a span node's span | no |
| `:902` | keys colliding with reserved outcomes | `pass-declarations` | `reserved-branch-key` (1) | census | — | declare `continue` or `pause` as a key | no |
| `:903` | counted consume using an incompatible field | `pass-field-operands` | `invalid-field-operand` | `verify-tests.sps` | — | rename a counted consume's field | no |
| `:904` | accumulation using an incompatible field or base | `pass-field-operands`; constructor (base) | `invalid-field-operand` | `verify-tests.sps` | — | rename an accumulate's field; the base recorded as a refusal | no |
| `:905` | malformed pause continuations | `pass-names` through `node-out-targets` | `missing-target` | `verify-tests.sps` | — | retarget a continuation to a fresh symbol (`:887`'s entry covers) | no |
| `:906` | terminal nodes with outgoing transitions | by construction (no slot) | — | matrix | n/a | recorded | no |
| `:907` | invalid EOF targets; successful EOF with an active span | `pass-eof`, `pass-spans` | `invalid-eof-target` (2), `span-active-at-exit` (1) | census | — | dangle an eof-target; route a span's interior to a finish or stop | `span-active-at-exit`: **entry → node** |
| `:908` | EOF-only zero-progress cycles; non-EOF control flow into a finish | `pass-eof-execution` | `eof-zero-progress-cycle` (1), `non-eof-into-finish` (2) | census | 3, 3 | point an eof-target at a cycle of eof-targets; point a byte edge at a finish; make the entry a finish | **the EOF walk's stack**; **entry → source → finish** |
| `:909` | EOF-reachable stop terminals | `pass-eof-execution` | `eof-reachable-stop` (1) | census | 4 | point an eof route, a pause continuation, or a zero-count `next` at a stop | **the EOF walk's stack** |
| `:910` | generated identifier collisions | `compile.sls`'s `valid-binding?` on the binding; no declared name in identifier position | — (`invalid-output-binding`, a contract condition) | `compile-tests.sps`, `identifier-repertoire-tests.sps` | n/a | §4.8's structural witness; §4.12 item 1 | n/a |
| `:911` | backend limits that would make emission incorrect | nobody | — | — | — | §4.12 item 2 | n/a |
| `:913` | normal consuming cycles are valid | the accept side of `:898` | — | `verify-tests.sps` (the message loop) | — | the generator's back-edges through an advancing byte edge, ACCEPTED, counted | — |

**Test-side censuses this milestone adds**, so the next kind's slice finds them: the
generator's draw tables (kinds, matchers, operations, predicates, callback kinds — hand-written
and exported in `machine-gen.sls`, with the property program's totality rows comparing them to
`ir.sls`'s closed sets [note 2026-09-11 (3)]); the catalogue's entry table (keyed by `§16.2` bullet, its code union compared
with the census); the oracle's rule table; the printer's arm table (derived from `node?` and
`matcher?`); the census's path-policy row; `role->positions` and `t2-kinds` in the existing
files, unchanged.

---

## References

- Parent plan: `docs/plans/byte-machine-implementation-plan.md` — `§25:1611-1627` (scope and
  exit), `§16.1-16.4` (`:878`, `:884-913`, `:917-931`, `:935-947`), `§22.4-22.7`
  (`:1262-1272`, `:1276-1289`, `:1293-1297`, `:1301`), `§22.9:1315`, `§9.1:278-348`,
  `§9.2:372-380`, `§12.2:687-701`, `§11.4:654`, `§12.7:770`, `§29:1760-1764`, `§30:1778`,
  and the appended `## Dated dispositions` section — the four under `§25:1611` first.
- `docs/plans/milestone-6-design.md` — the structural template; its §8 the pricing §3.2 item 1
  measures.
- `docs/plans/milestone-5-slice-0-implementation-plan.md` §3 and §10 — the matrix's design and
  the two tiers it named for this milestone.
- Decisions 0011 (EOF execution), 0015 (independent interpreter representation), 0020 and 0022
  (the record widening deferred here), 0023 and 0027 (the reachability relations), 0029 (the
  span lattice), 0030 (counted consume's two verifier answers).
- `AGENTS.md` — testing and mutation discipline, documentation and record discipline.
