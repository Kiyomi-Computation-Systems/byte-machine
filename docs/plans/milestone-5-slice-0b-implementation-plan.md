# Milestone 5 Slice ⓪b — the EOF walk cluster

**Status:** planned, not started. Depends on Slice ⓪ (the matrix must exist to measure this
slice's blast radius). Written 2026-09-03 against `main` at `d47a12b` plus Slice ⓪'s Tasks 1 and
6; every line citation and count below re-measured against the tree, not carried from the design
pass — **which is how the design pass's own figures were caught** (§7).

## §1 Why these four questions are one slice

Slice ⓪ recorded five open questions. Four of them are the same question asked four ways:
**which nodes start an EOF walk, under what gate, how many findings does one decision emit, and
how many of the six verdicts are real?** Fixing D-1 alone is what *produces* the double-reporting
that OQ-4 is about, so a patch would create the next defect. The fifth (OQ-5) is the verdict
lattice, and it shares the same code.

## §2 What the design pass settled, and how

### OQ-3 — RESOLVED: the byte-reachability-gated reading is correct

The §16.2:908 check exists at three sites under two gating rules — the diagnostic at
`verify.sls:756` is unconditional, those at `:801` and `:821` are gated on byte-reachability.
Six machines whose offending node is EOF-only-reachable measure: pause / field-action /
field-branch **accepted**, dispatch-case / sequence-case / accumulate-digit **rejected**.

**Decisive, in both directions:**

- Applying the **unconditional** reading uniformly breaks **five shipped programs**, and the
  refusal record is `non-eof-into-finish` on `pe` — the shipped pause machine's EOF-only pause
  whose continuation is a finish node. That is **decision 0011's canonical legal shape**, named
  in the fixture's own header. The unconditional rule, applied consistently, rejects the machine
  0011 was written to permit.
- Applying the **gated** reading uniformly leaves the entire positive battery byte-identical —
  every byte-reachable offender of all six kinds is still rejected.

The gate is also *sound*, not merely convenient: once an execution takes an eof-target it can
never feed again (`parser-feed!` prohibits the `finish-ready` row), so feed-reachable ⊆
`byte-reached`, and gating on it cannot miss a real violation.

**Decision 0021 item 5's stated reason is false.** It splits the kinds by "reads input" versus
"zero-width" (`0021:138`), on the theory that an input-reading node is always on the feed path.
A byte-dispatch, a sequence-dispatch and an accumulate node can each be EOF-only-reachable. This
is the project's own *a decision can be right while its stated reason is false* pattern — except
here the decision is **also** wrong.

### OQ-4 — the premise is FALSE, and that changes the task

§16.4:937-943 is a **contents** list — code, severity, machine name, node and edge/source label
"where applicable", message, declaration names, graph path. **There is no cardinality rule in
it.** "One finding per decision" entered at `milestone-3-slice-1-implementation-plan.md:139` and
now sits in fourteen citing sites, including the parent plan's own dated disposition. So the
"double-reporting" objection that kept D-1's fix out of Slice ⓪ **was resting on a rule that does
not exist**.

What *is* true: `make-diagnostic` is `(vector tag code node message)` — three arguments at all
31 call sites — so §16.4:940's **edge/source-label half is implemented nowhere**. The problem is
not too many findings; it is that two findings from one node are **indistinguishable**.

### D-1 / OQ-2 / OQ-5 — see §3

## §3 The recommended shapes, one each

**D-1 — the `:909` start set is the *parked* set, derived.** Replace the two `:909` blocks with
one whose start set is
`{n : name(n) ∈ byte-reached ∧ (name(n) = entry ∨ pause? n ∨ symbol?(node-eof-target n))}`,
classifying **the node itself**. Because it is a set, the entry appears once — **zero duplicate
cells, measured**. The naive entry-walk (shape a) double-reports in 17 of 144 prototype cells,
and the only filter that suppresses it is a per-kind census of the entry — *the construct that
shipped three Slice ③ defects*.

Slice ⓪ Task 1's fixture is **byte-identical** under this shape. The two slices compose.

Record honestly in 0023 that this **narrows** decision 0011 item 4(a)'s literal "reachable from
any state": a graph node no execution can occupy is not a state that originates a traversal.

**OQ-2 — `entry = finish` is illegal, derived rather than special-cased.** Decision 0011 item
4(b) already states the rule over *reaching*; §16.2:908's "control flow into" is the edge-level
implementation of a reachability rule, and the entry is reached by `parser-feed!`. Implement as
one clause in the `:908` block, reusing `non-eof-into-finish` with **no new code** (the Slice ③
`invalid-field-operand` precedent). Multiplicity 1 by construction. Measured: `entry = finish`
→ exactly `((non-eof-into-finish . start))`. The strongest independent witness is the empty
feed: `parser-feed!` on an **empty slice** returns `finished`, and §11.1:638's closed list for
that case is "a callback, stop, or error".

**OQ-3 — collapse the three `:908` sites into one derived block** keyed on
`memq (node-name n) byte-reached`, reporting once per offending byte edge **at its source node**.
This keeps the diagnostic's node slot on the source (§16.4:940's more useful half) and keeps the
per-edge unit. The alternative form — reporting at the finish node — was measured identical on
accept/reject but **merges two findings from two different source nodes into one**, which is
cross-node merging: strictly worse than the problem it set out to fix.

Structural payoff: `pass-eof-execution` goes from **five hand-written filters naming ten kind
predicates to two naming two**. `node-out-targets` becomes the single census, which it already
owns — and that is the direct antidote to the Slice ③ failure mode.

**OQ-4 — keep one finding per edge; implement §16.4:940 instead.** The `:908` unit is the edge;
the EOF-verdict unit is the node, and the recommended `:909` shape makes that true *by
construction* — one start per node, one `case`, one diagnostic — so **no de-duplication pass is
written at all** and the merging trap never arises. Add the edge/source label: `make-diagnostic`
keeps its three-argument form, plus `make-diagnostic/edge` and an exported `diagnostic-edge`,
carrying a **role** symbol (`case`, `fallback`, `alternative`, `mismatch`, `digit`, `nondigit`,
`overflow`, `next`, `error`, `true`, `false`, `continuation`, `entry`). **Roles, not indices** —
`verify.sls:380-386` explicitly declines to promise the order of two diagnostics from one node,
and an index would newly promise it.

**OQ-5 — do not shrink the answer set; shrink the *order* to three tiers.** The observable image
of `eof-terminal` has three values; six of the fifteen verdict pairs are undecidable by any
machine, all six inside `{finish, unresolved, error, default-error}`. Replace the flat ranking at
`verify.sls:658` with three tiers (benign / `eof-reachable-stop` / `cycle`). This makes the
24-permutation survivor **unwritable** rather than an `EXPECT_SURVIVES`, and turns each tier
assignment into a single-token mutation caught by a failed comparison. Keep all six symbols —
M5's span check needs `finish` distinguished from `error` at `classify`.

**This is not cosmetic.** Measured: with `default-error` promoted above `cycle`, a field-branch
machine **verifies `ok=#t` with zero diagnostics and `parser-finish!` never returns**. Four of
those six undecidable relations are acceptance holes of exactly that kind.

## §4 Decision records

**Open `0023-eof-walk-starts-and-finish-reachability.md`** — the four questions need one citable
home, and 0021's items 2, 3 and 4 stand unchanged.

**Annotate 0021; do not correct it in place.** Two sentences were **never true**, and
`AGENTS.md:396-399` sends a never-true load-bearing sentence to *annotation*: item 1's "every
other verdict falls through … regardless of order" (six relations decide accept-versus-reject),
and item 5's "reads input" justification. Put a pointer at the top and at each item, routing
without restating 0023's conclusion.

**0011 needs no amendment** — but 0023 must say explicitly that it reads item 4(a)'s "any state"
as "any state an execution can occupy", or a later slice will re-derive it wrongly.

## §5 Tasks — seven commits, failing tests first

- [ ] **T1 — citations and records (docs only).** *Partly done already:* Slice ⓪'s four stale
  `verify.sls:NNN` citations were corrected when this plan was written. Remaining: annotate the
  parent plan's dated disposition and Slice ⓪ §2/§10 — **the 85/230 figure is
  skeleton-dependent** and must name its skeleton or be dropped (§7).
- [x] **T2 — `:908` becomes one derived block (OQ-3).** Done. Three hand-written sites — one
  unconditional and kind-filtered, two gated — became one block keyed on `byte-reached`.
  `pass-eof-execution`'s `:908` half now names **one** kind predicate (`finish-node?`, the kind
  the rule is *about*) where it named six. Twelve-machine battery: all six EOF-only-reachable
  offenders accepted, all six byte-reachable ones rejected **at the source node**.

  **Costs, all as predicted and each handled rather than absorbed:** `combined6` re-baselined by
  making its `seq` byte-reachable — the case's intent is *two findings from two sources*, so the
  second source was made real rather than the expected count lowered. The census's site table
  moved **31 → 29** (`non-eof-into-finish` 3 → 1) and went red on this commit, which is the
  ratchet working. **Seven mutation anchors** broke; their decisions no longer exist separately,
  so they are removed with residue recorded at the site, and three new pins replace them —
  the gate, the gate's non-vacuity, and the out-target census. Net 372 → 368.

  *The gate-drop mutant is caught by the shipped pause machine's own case*, which is the
  both-directions evidence that the unconditional reading is wrong, wired in as a pin. Fixtures first: the six EOF-only
  offenders must verify clean (fails today for three of them); the six byte-reachable offenders
  must be rejected **at the source node** (the reverse-direction pin); and a named assertion that
  `make-pause-machine` verifies clean *and* that `pe`'s continuation is a finish node.
- [x] **T3 — the entry-is-finish clause (OQ-2).** Done, as its own clause and its own pin so the
  decision stays independently revertible.

  **The runtime evidence had to be captured before the fix.** Measured pre-clause: `entry =
  finish` verified with zero diagnostics and `parser-feed!` returned `finished` for an **empty**
  slice, consuming 0 — which §11.1:638's closed list ("a callback, stop, or error") does not
  permit, and §12.1:671's `ready --feed-->` set does not contain. Once the verifier rejects the
  machine no executor will build it, so that measurement cannot be re-asserted as a live test; it
  is recorded at the fixture as the evidence that justified the rule, and the case asserts what
  stays observable — the verdict, exactly one finding, at the entry.

  A second case pins the shape people actually want (`§12.4:725`: an entry that *routes* EOF to a
  finish), so the clause cannot be widened into `eof-machine.sls` by a later slice. Census moved
  **29 → 30**; second red run, second re-baseline.
- [ ] **T4 — `:909` becomes the parked-set block (D-1).** Failing fixtures for all four D-1
  cells **plus the two already-correct one-hop controls, which must stay at exactly one
  finding** — that is the anti-duplication pin.
- [ ] **T5 — the edge/source label (§16.4:940, OQ-4).** Two isolating fixtures no axis of the
  230-cell matrix builds: `case 65 → stop, case 66 → finish, fallback → stop`, and its sequence
  twin.
- [ ] **T6 — the verdict tiers (OQ-5).** Three failing fixtures, using the **stop** variant not
  the cycle variant: the cycle variant's join is still `cycle` under a tier-1 promotion, so it
  kills only half the mutants.
- [ ] **T7 — records and the whole-branch sweep.** Decision 0023; 0021's annotations; the dated
  disposition appended at `byte-machine-implementation-plan.md:1802` (**file is 1879 lines;
  append, never insert**). Re-run the `verify.sls` sweep in **both** directions and confirm the
  **twelve** `EXPECT_SURVIVES` directives are unchanged.

## §6 Hazards

**H1 — this slice changes verdicts, so everything is a candidate re-baseline.** Measured against
`d47a12b`: **1** of 26 runnable programs differs; **3** failed cases, all in one group; **11 of
the then-81 `verify.sls` mutation anchors go to zero occurrences** — hard `SITES` failures at
declaration — plus 2 that stay caught but lose a FAIL record. *(The tree now carries **84**
`verify.sls` mutations; re-measure before starting.)* The 16 differential lanes, the pause/EOF
lanes and the property lane are **untouched**.

**Three mechanical rules separate a legitimate re-baseline from a regression**, each failing
hard:
1. A cell that **gains** a finding must gain it at a node in `byte-reached`, and the expectation
   must be derived from a cited §16.2 bullet *before* the machine runs. A gain elsewhere is a
   regression.
2. A cell that **loses** a finding must keep its accept/reject verdict, and the lost finding's
   node must **not** be in `byte-reached`.
3. **Verdict flips are a closed list of seven machines** — four ACCEPT→REJECT (`entry = stop |
   finish | field-action→stop | field-branch→stop`) and three REJECT→ACCEPT (EOF-only-reachable
   dispatch / sequence / accumulate with a byte edge into a finish). **Any eighth flip is a
   regression.** Assert the list as data with an observed-value sentinel, never as prose.

**H2 — the ACCEPT set grows, so reject-side fixtures are not enough.** Three machine families
become legal; they need accept-side fixtures *and* runtime assertions (all 256 single-byte feeds
→ never `finished`), because "verifies clean" is what the defect looked like.

**H3 — the matrix will not keep this slice honest.** Measured: the gate decision changes **0 of
144** prototype cells and **0 of 24** EOF-chain cells under either skeleton, and the whole
shipped suite stays green under a false-accepting role-keyed dedup. ⓪b must ship its own
discriminating fixtures. Conversely **Slice ⓪'s census pins the site count at 31, and this slice
moves it to 28** — S3 going red is the ratchet working, not a regression.

**H4 — closing `:908` correctly makes an existing over-approximation visible. Record it; do not
fix it here.** `pass-reachability` walks `all-out-targets`, so a node reachable only through an
untakeable EOF edge counts as reached — and today `:908`'s over-broad filter is answering the
"unreachable nodes" bullet's question by accident. Open it as its own §16.2 question. Do not let
"the census is clean" be read as "this is closed".

**H5 — the deferral trap.** OQ-2 is **not** a by-product of D-1's walk: `classify` maps a finish
node to `'finish` and both `case`s map that to `'()`, so the entry walk leaves `entry = finish`
reporting nothing in every variant built. T3 and T4 must each record at the site that the other
is still open until it lands.

**H6 — a nonzero exit is not proof.** The design pass's own first sweep reported that the suite's
`EXPECT_SURVIVES` mutant "starts being caught"; it does not — the exit code was already nonzero
from the three known-broken cases. **Re-baseline the three fixtures first, then sweep**, and
compare FAIL *sets*, not exit codes.

**H7 — `SITES` fails both directions.** The new `:908` and `:909` blocks both contain
`(memq (node-name n) br)`; they must not share an anchorable line, or a pin on one resolves to
two sites and the suite hard-fails at declaration.

## §7 What the design pass got wrong, and why it is recorded here

Four agents measured this cluster; the synthesis re-measured them and **three of the four were
wrong about something load-bearing**. Recorded because the corrections are the reason the
recommendations above are trustworthy, and because a plan that hides its own disagreements is
the artifact this project keeps getting burned by.

- **The parked set is not a subset of `byte-reached`** — the claimed lemma. Measured false: the
  shipped pause machine parks on `done`, a finish node not in `byte-reached`. The true lemma is
  narrower and is what §3 states.
- **The composite's cost was understated by ~4×** — "exactly 3 broken pins" is 3 broken *cases*
  plus **11 broken mutation anchors**.
- **The "85 of 230" figure is skeleton-dependent and not reproducible.** The identical prototype
  gives **51/144** under one skeleton and **4/144** under another. Slice ⓪'s §2 and §10 and the
  parent plan's disposition must name the skeleton or drop the number. And "most of it
  double-reporting" is not corroborated: 17 of 51 changed cells are duplicates, 34 are new
  coverage.
- **One agent's replacement fixture reused the name `eofcyc2`**, which is already a *different*
  shipped fixture.
- **The "one finding per decision" rule does not exist in §16.4.** Verified by reading. It is a
  gloss that propagated to fourteen sites.
- **`AGENTS.md` sends a never-true sentence to annotation, not in-place correction** — one agent
  instructed the opposite for decision 0021.

And the finding that lands closest to home: **Slice ⓪'s `verify.sls` citations were stale on
arrival**, by four lines, because they were measured against a worktree predating a commit that
expanded a comment in that same file. D-2's site was cited as `:831` — the *live*
`eof-reachable-stop` half; the dead clause was `:834`. Corrected. No grep and no link check can
see that class of error, because every cited line exists and holds plausible code.
